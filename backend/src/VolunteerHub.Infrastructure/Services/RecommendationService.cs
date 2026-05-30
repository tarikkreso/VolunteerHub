using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.ML;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;
using VolunteerHub.Infrastructure.ML;

namespace VolunteerHub.Infrastructure.Services;

/// <summary>
/// Content-based event recommendation service.
/// Primary: Uses ML.NET trained model (TF-IDF + logistic regression) stored by RecommendationTrainingService.
/// Fallback: keyword-based scoring when ML model is unavailable.
/// Also checks pre-computed EventRecommendation table.
/// </summary>
public class RecommendationService : IRecommendationService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<RecommendationService> _logger;

    // Cached ML prediction engine
    private static PredictionEngine<RecommendationInput, RecommendationPrediction>? _predictionEngine;
    private static DateTime _modelLoadedAt = DateTime.MinValue;

    // Skill-to-category keyword mappings for content-based matching
    private static readonly Dictionary<string, string[]> SkillCategoryMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Fizicki rad"] = new[] { "okolis", "sport", "ciscenje", "sadnja", "fizick" },
        ["Poducavanje"] = new[] { "edukacija", "radionice", "mentorstvo", "poducavanje", "skol" },
        ["Prva pomoc"] = new[] { "zdravlje", "medicinska", "pomoc", "humanitarno", "prva" },
        ["Voznja"] = new[] { "transport", "dostava", "voznja", "prevoz", "logistika" },
        ["IT vjestine"] = new[] { "edukacija", "it", "racunar", "softver", "web", "dizajn", "digitalno" },
        ["Fotografija"] = new[] { "kultura", "fotografij", "snimanje", "event", "manifestacij" },
        ["Marketing"] = new[] { "marketing", "promocij", "kultura", "event", "organizacij" },
        ["Koordinacija tima"] = new[] { "koordinacija", "tim", "organizacija", "logistika" },
        ["Rad sa djecom"] = new[] { "djeca", "ucenici", "edukacija", "skola", "radionice" },
        ["Administracija"] = new[] { "administracija", "unos", "podaci", "priprema", "paketi" }
    };

    public RecommendationService(ApplicationDbContext context, ILogger<RecommendationService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<List<EventRecommendationDto>> GetRecommendationsAsync(int userId, int top = 5)
    {
        // Strategy 1: Try pre-computed ML recommendations from EventRecommendation table
        var preComputed = await TryGetPreComputedAsync(userId, top);
        if (preComputed != null && preComputed.Count >= top)
        {
            _logger.LogInformation("Returning {Count} pre-computed ML recommendations for user {UserId}", preComputed.Count, userId);
            return preComputed;
        }

        // Strategy 2: Try live ML model prediction
        var mlResults = await TryMLPredictionAsync(userId, top);
        if (mlResults != null && mlResults.Any())
        {
            _logger.LogInformation("Returning {Count} live ML recommendations for user {UserId}", mlResults.Count, userId);
            return mlResults;
        }

        // Strategy 3: Fallback to keyword-based matching
        _logger.LogInformation("Using keyword-based fallback recommendations for user {UserId}", userId);
        return await GetKeywordBasedRecommendationsAsync(userId, top);
    }

    /// <summary>
    /// Try to get pre-computed recommendations from the EventRecommendation table (stored by training service).
    /// </summary>
    private async Task<List<EventRecommendationDto>?> TryGetPreComputedAsync(int userId, int top)
    {
        try
        {
            var recs = await _context.EventRecommendations
                .Include(r => r.Event)
                    .ThenInclude(e => e.Category)
                .Include(r => r.Event)
                    .ThenInclude(e => e.City)
                .Include(r => r.Event)
                    .ThenInclude(e => e.Organization)
                .Include(r => r.Event)
                    .ThenInclude(e => e.Shifts)
                .Where(r => r.UserId == userId
                    && !r.Event.IsDeleted
                    && r.Event.Status == EventStatus.Published
                    && r.Event.EndDate >= DateTime.UtcNow)
                .OrderByDescending(r => r.Score)
                .Take(top)
                .ToListAsync();

            if (!recs.Any()) return null;

            // Filter out events user already registered for
            var registeredEventIds = await _context.ShiftRegistrations
                .Where(sr => sr.UserId == userId)
                .Select(sr => sr.Shift.EventId)
                .Distinct()
                .ToListAsync();

            return recs
                .Where(r => !registeredEventIds.Contains(r.EventId))
                .Select(r => new EventRecommendationDto
                {
                    Event = MapToEventDto(r.Event),
                    Score = Math.Round(r.Score, 2),
                    ReasonTags = r.ReasonTags ?? "ML preporuka"
                })
                .Take(top)
                .ToList();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get pre-computed recommendations");
            return null;
        }
    }

    /// <summary>
    /// Try live ML prediction using the persisted model file.
    /// </summary>
    private async Task<List<EventRecommendationDto>?> TryMLPredictionAsync(int userId, int top)
    {
        try
        {
            if (!File.Exists(RecommendationTrainingService.ModelPath))
                return null;

            // Reload model if it's old or not loaded
            if (_predictionEngine == null || (DateTime.UtcNow - _modelLoadedAt).TotalHours > 1)
            {
                var mlContext = new MLContext(seed: 42);
                var model = mlContext.Model.Load(RecommendationTrainingService.ModelPath, out var schema);
                _predictionEngine = mlContext.Model.CreatePredictionEngine<RecommendationInput, RecommendationPrediction>(model);
                _modelLoadedAt = DateTime.UtcNow;
                _logger.LogInformation("ML model loaded from {Path}", RecommendationTrainingService.ModelPath);
            }

            // Get user skills
            var userSkills = await _context.UserSkills
                .Include(us => us.Skill)
                .Where(us => us.UserId == userId)
                .Select(us => us.Skill.Name)
                .ToListAsync();

            if (!userSkills.Any()) return null;

            var userFeatures = string.Join(" ", userSkills);

            // Get candidate events
            var registeredEventIds = await _context.ShiftRegistrations
                .Where(sr => sr.UserId == userId)
                .Select(sr => sr.Shift.EventId)
                .Distinct()
                .ToListAsync();

            var events = await _context.Events
                .Include(e => e.Category)
                .Include(e => e.City)
                .Include(e => e.Organization)
                .Include(e => e.Shifts)
                .Where(e => !e.IsDeleted
                    && e.Status == EventStatus.Published
                    && e.EndDate >= DateTime.UtcNow
                    && !registeredEventIds.Contains(e.Id))
                .ToListAsync();

            if (!events.Any()) return null;

            // Predict
            var scored = new List<(EventDto Event, double Score, string Reasons)>();
            foreach (var evt in events)
            {
                var input = new RecommendationInput
                {
                    UserFeatures = userFeatures,
                    EventFeatures = $"{evt.Category?.Name} {evt.Organization?.Name} {evt.Title} {evt.Description} {evt.Requirements} {evt.Location}"
                };

                var prediction = _predictionEngine.Predict(input);
                if (prediction.Probability > 0.15f)
                {
                    var matchedSkills = userSkills.Where(s =>
                        (evt.Category?.Name?.Contains(s, StringComparison.OrdinalIgnoreCase) ?? false) ||
                        (evt.Description?.Contains(s, StringComparison.OrdinalIgnoreCase) ?? false) ||
                        (evt.Title?.Contains(s, StringComparison.OrdinalIgnoreCase) ?? false))
                        .ToList();

                    var reasons = matchedSkills.Any()
                        ? $"Odgovara tvojim vjestinama: {string.Join(", ", matchedSkills.Distinct().Take(3))}"
                        : $"ML preporuka ({(prediction.Probability * 100):F0}% relevantnost)";

                    scored.Add((MapToEventDto(evt), prediction.Probability, reasons));
                }
            }

            return scored
                .OrderByDescending(s => s.Score)
                .Take(top)
                .Select(s => new EventRecommendationDto
                {
                    Event = s.Event,
                    Score = Math.Round(s.Score, 2),
                    ReasonTags = s.Reasons
                })
                .ToList();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "ML prediction failed, falling back to keyword matching");
            return null;
        }
    }

    /// <summary>
    /// Original keyword-based recommendation logic as fallback.
    /// </summary>
    private async Task<List<EventRecommendationDto>> GetKeywordBasedRecommendationsAsync(int userId, int top)
    {
        // 1. Get user's skills with skill names
        var userSkills = await _context.UserSkills
            .Include(us => us.Skill)
            .Where(us => us.UserId == userId)
            .ToListAsync();

        if (!userSkills.Any())
        {
            // No skills - return featured/upcoming events as fallback
            return await GetFallbackRecommendationsAsync(top);
        }

        // 2. Get active/upcoming events the user hasn't already registered for
        var registeredEventIds = await _context.ShiftRegistrations
            .Where(sr => sr.UserId == userId)
            .Select(sr => sr.Shift.EventId)
            .Distinct()
            .ToListAsync();

        var events = await _context.Events
            .Include(e => e.Category)
            .Include(e => e.City)
            .Include(e => e.Organization)
            .Include(e => e.Shifts)
            .Where(e => !e.IsDeleted
                && e.Status == EventStatus.Published
                && e.EndDate >= DateTime.UtcNow
                && !registeredEventIds.Contains(e.Id))
            .ToListAsync();

        if (!events.Any())
        {
            return await GetFallbackRecommendationsAsync(top);
        }

        var userCityId = await _context.Volunteers
            .Where(u => u.Id == userId)
            .Select(u => u.CityId)
            .FirstOrDefaultAsync();

        // 3. Score each event based on skill-content matching
        var scored = new List<(EventDto Event, double Score, string Reasons)>();

        foreach (var evt in events)
        {
            double score = 0;
            var matchedSkills = new List<string>();
            var categoryName = evt.Category?.Name?.ToLowerInvariant() ?? "";
            var descLower = evt.Description?.ToLowerInvariant() ?? "";
            var titleLower = evt.Title?.ToLowerInvariant() ?? "";

            foreach (var us in userSkills)
            {
                var skillName = us.Skill?.Name ?? "";
                double skillScore = 0;

                // Direct category name matching
                if (SkillCategoryMap.TryGetValue(skillName, out var keywords))
                {
                    foreach (var kw in keywords)
                    {
                        if (categoryName.Contains(kw, StringComparison.OrdinalIgnoreCase))
                            skillScore += 0.4;
                        if (descLower.Contains(kw))
                            skillScore += 0.15;
                        if (titleLower.Contains(kw))
                            skillScore += 0.2;
                    }
                }

                // Generic skill name in description/title
                var skillLower = skillName.ToLowerInvariant();
                if (descLower.Contains(skillLower) || titleLower.Contains(skillLower))
                    skillScore += 0.3;

                // Weight by proficiency level (1-5 -> 0.6-1.0)
                var profWeight = 0.6 + (us.ProficiencyLevel - 1) * 0.1;
                skillScore *= profWeight;

                if (skillScore > 0)
                {
                    score += skillScore;
                    matchedSkills.Add(skillName);
                }
            }

            // Bonus for featured events
            if (evt.IsFeatured) score += 0.1;

            // Bonus for location proximity (same city)
            if (userCityId != null && evt.CityId == userCityId)
                score += 0.15;

            // Normalize score to 0-1 range
            score = Math.Min(score, 1.0);

            if (score > 0.05)
            {
                var reasons = matchedSkills.Any()
                    ? $"Odgovara tvojim vjestinama: {string.Join(", ", matchedSkills.Distinct())}"
                    : "Preporuceno na osnovu tvojih interesovanja";

                scored.Add((MapToEventDto(evt), score, reasons));
            }
        }

        // 4. Return top N by score
        return scored
            .OrderByDescending(s => s.Score)
            .Take(top)
            .Select(s => new EventRecommendationDto
            {
                Event = s.Event,
                Score = Math.Round(s.Score, 2),
                ReasonTags = s.Reasons
            })
            .ToList();
    }

    private async Task<List<EventRecommendationDto>> GetFallbackRecommendationsAsync(int top)
    {
        var events = await _context.Events
            .Include(e => e.Category)
            .Include(e => e.City)
            .Include(e => e.Organization)
            .Include(e => e.Shifts)
            .Where(e => !e.IsDeleted && e.Status == EventStatus.Published && e.EndDate >= DateTime.UtcNow)
            .OrderByDescending(e => e.IsFeatured)
            .ThenByDescending(e => e.CreatedAt)
            .Take(top)
            .ToListAsync();

        return events.Select((e, i) => new EventRecommendationDto
        {
            Event = MapToEventDto(e),
            Score = Math.Round(0.5 - i * 0.05, 2),
            ReasonTags = e.IsFeatured ? "Istaknuti dogadjaj" : "Popularni dogadjaj"
        }).ToList();
    }

    private static EventDto MapToEventDto(Domain.Entities.Event e) => new()
    {
        Id = e.Id,
        Title = e.Title,
        Description = e.Description,
        ImageUrl = e.ImageUrl,
        StartDate = e.StartDate,
        EndDate = e.EndDate,
        Location = e.Location,
        Latitude = e.Latitude,
        Longitude = e.Longitude,
        Requirements = e.Requirements,
        MaxVolunteers = e.MaxVolunteers,
        Status = e.Status.ToString(),
        IsFeatured = e.IsFeatured,
        CategoryName = e.Category?.Name ?? string.Empty,
        CityName = e.City?.Name,
        OrganizationId = e.OrganizationId,
        OrganizationName = e.Organization?.Name,
        OrganizationDescription = e.Organization?.Description,
        ShiftCount = e.Shifts?.Count ?? 0,
        RegisteredVolunteers = e.Shifts?.Sum(s => s.CurrentVolunteers) ?? 0,
        CreatedAt = e.CreatedAt
    };
}
