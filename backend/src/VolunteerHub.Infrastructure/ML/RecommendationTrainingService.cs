using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.ML;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.ML;

/// <summary>
/// Background service that trains the ML.NET recommendation model every 24 hours.
/// Uses TF-IDF text featurization + SdcaLogisticRegression for binary classification.
/// Training data: user skill profiles vs event metadata, labelled by actual registrations.
/// </summary>
public class RecommendationTrainingService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<RecommendationTrainingService> _logger;
    private static readonly TimeSpan TrainingInterval = TimeSpan.FromHours(24);

    /// <summary>
    /// Path to the persisted ML model file.
    /// </summary>
    public static string ModelPath => Path.Combine(AppContext.BaseDirectory, "ml_model", "recommendation.zip");

    public RecommendationTrainingService(IServiceProvider serviceProvider, ILogger<RecommendationTrainingService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("RecommendationTrainingService started. Training interval: {Interval}", TrainingInterval);

        // Initial training on startup (short delay to let DB initialize)
        await Task.Delay(TimeSpan.FromSeconds(15), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await TrainModelAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during ML model training");
            }

            await Task.Delay(TrainingInterval, stoppingToken);
        }
    }

    /// <summary>
    /// Trains the ML.NET model using data from the database.
    /// </summary>
    public async Task TrainModelAsync(CancellationToken ct = default)
    {
        _logger.LogInformation("Starting ML recommendation model training...");

        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var mlContext = new MLContext(seed: 42);

        // 1. Collect training data
        var trainingData = await CollectTrainingDataAsync(context, ct);

        if (trainingData.Count < 10)
        {
            _logger.LogWarning("Insufficient training data ({Count} samples). Minimum 10 required. Skipping training.", trainingData.Count);
            return;
        }

        _logger.LogInformation("Collected {Count} training samples ({Pos} positive, {Neg} negative)",
            trainingData.Count,
            trainingData.Count(d => d.Label),
            trainingData.Count(d => !d.Label));

        // 2. Load data into ML.NET
        var dataView = mlContext.Data.LoadFromEnumerable(trainingData);

        // 3. Build the pipeline: TF-IDF on text features -> concatenate -> logistic regression
        var pipeline = mlContext.Transforms.Text
            .FeaturizeText("UserFeaturesVec", nameof(RecommendationInput.UserFeatures))
            .Append(mlContext.Transforms.Text
                .FeaturizeText("EventFeaturesVec", nameof(RecommendationInput.EventFeatures)))
            .Append(mlContext.Transforms.Concatenate("Features", "UserFeaturesVec", "EventFeaturesVec"))
            .Append(mlContext.BinaryClassification.Trainers.SdcaLogisticRegression(
                labelColumnName: "Label",
                featureColumnName: "Features",
                maximumNumberOfIterations: 100));

        // 4. Train the model
        var model = pipeline.Fit(dataView);

        // 5. Evaluate
        var predictions = model.Transform(dataView);
        var metrics = mlContext.BinaryClassification.Evaluate(predictions, "Label");
        _logger.LogInformation(
            "Model trained — Accuracy: {Accuracy:P2}, AUC: {AUC:P2}, F1: {F1:P2}",
            metrics.Accuracy, metrics.AreaUnderRocCurve, metrics.F1Score);

        // 6. Save model to disk
        var modelDir = Path.GetDirectoryName(ModelPath)!;
        Directory.CreateDirectory(modelDir);
        mlContext.Model.Save(model, dataView.Schema, ModelPath);
        _logger.LogInformation("ML model saved to {Path}", ModelPath);

        // 7. Store recommendations in DB for all active users
        await StoreRecommendationsAsync(context, mlContext, model, dataView.Schema, ct);
    }

    /// <summary>
    /// Collects training data from DB: positive samples (user registered for event)
    /// and negative samples (user did NOT register for event).
    /// </summary>
    private async Task<List<RecommendationInput>> CollectTrainingDataAsync(ApplicationDbContext context, CancellationToken ct)
    {
        var data = new List<RecommendationInput>();

        // Get all users with their skills
        var usersWithSkills = await context.UserSkills
            .Include(us => us.Skill)
            .Include(us => us.User)
            .GroupBy(us => us.UserId)
            .Select(g => new
            {
                UserId = g.Key,
                Skills = g.Select(us => us.Skill.Name).ToList()
            })
            .ToListAsync(ct);

        if (!usersWithSkills.Any()) return data;

        // Get all published events with their category
        var events = await context.Events
            .Include(e => e.Category)
            .Where(e => !e.IsDeleted && e.Status == EventStatus.Published)
            .Select(e => new
            {
                e.Id,
                e.Title,
                e.Description,
                CategoryName = e.Category != null ? e.Category.Name : "",
                e.Location
            })
            .ToListAsync(ct);

        if (!events.Any()) return data;

        // Get all registrations (positive samples)
        var registrations = await context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Where(sr => sr.Status != ShiftStatus.Rejected && sr.Status != ShiftStatus.Cancelled)
            .Select(sr => new { sr.UserId, sr.Shift.EventId })
            .Distinct()
            .ToListAsync(ct);

        var registrationSet = registrations
            .Select(r => (r.UserId, r.EventId))
            .ToHashSet();

        // Build training samples
        foreach (var user in usersWithSkills)
        {
            var userFeatures = string.Join(" ", user.Skills);

            foreach (var evt in events)
            {
                var eventFeatures = $"{evt.CategoryName} {evt.Title} {evt.Description} {evt.Location}";
                var isRegistered = registrationSet.Contains((user.UserId, evt.Id));

                // Always add positive samples
                if (isRegistered)
                {
                    data.Add(new RecommendationInput
                    {
                        UserFeatures = userFeatures,
                        EventFeatures = eventFeatures,
                        Label = true
                    });
                }
            }

            // Add negative samples (events user did NOT register for) — sample up to 3x positives
            var positiveCount = data.Count(d => d.Label && d.UserFeatures == userFeatures);
            var negativeEvents = events
                .Where(e => !registrationSet.Contains((user.UserId, e.Id)))
                .OrderBy(_ => Random.Shared.Next())
                .Take(Math.Max(positiveCount * 3, 2));

            foreach (var evt in negativeEvents)
            {
                data.Add(new RecommendationInput
                {
                    UserFeatures = userFeatures,
                    EventFeatures = $"{evt.CategoryName} {evt.Title} {evt.Description} {evt.Location}",
                    Label = false
                });
            }
        }

        return data;
    }

    /// <summary>
    /// Uses the trained model to pre-compute recommendations for all active users
    /// and stores them in the EventRecommendation table.
    /// </summary>
    private async Task StoreRecommendationsAsync(
        ApplicationDbContext context, MLContext mlContext, ITransformer model, DataViewSchema schema, CancellationToken ct)
    {
        try
        {
            var predictionEngine = mlContext.Model.CreatePredictionEngine<RecommendationInput, RecommendationPrediction>(model);

            var users = await context.UserSkills
                .Include(us => us.Skill)
                .GroupBy(us => us.UserId)
                .Select(g => new
                {
                    UserId = g.Key,
                    Skills = g.Select(us => us.Skill.Name).ToList()
                })
                .ToListAsync(ct);

            var events = await context.Events
                .Include(e => e.Category)
                .Where(e => !e.IsDeleted && e.Status == EventStatus.Published && e.EndDate >= DateTime.UtcNow)
                .ToListAsync(ct);

            // Clear old recommendations
            var oldRecs = await context.EventRecommendations.ToListAsync(ct);
            context.EventRecommendations.RemoveRange(oldRecs);

            foreach (var user in users)
            {
                var userFeatures = string.Join(" ", user.Skills);

                foreach (var evt in events)
                {
                    var input = new RecommendationInput
                    {
                        UserFeatures = userFeatures,
                        EventFeatures = $"{evt.Category?.Name} {evt.Title} {evt.Description} {evt.Location}"
                    };

                    var prediction = predictionEngine.Predict(input);

                    if (prediction.Probability > 0.2f)
                    {
                        context.EventRecommendations.Add(new Domain.Entities.EventRecommendation
                        {
                            UserId = user.UserId,
                            EventId = evt.Id,
                            Score = Math.Round(prediction.Probability, 4),
                            ReasonTags = $"Odgovara tvojim vjestinama: {string.Join(", ", user.Skills.Take(3))}",
                            CalculatedAt = DateTime.UtcNow
                        });
                    }
                }
            }

            await context.SaveChangesAsync(ct);
            _logger.LogInformation("Stored ML recommendations for {Count} users", users.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error storing ML recommendations");
        }
    }
}
