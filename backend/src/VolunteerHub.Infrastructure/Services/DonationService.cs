using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Stripe;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class DonationService : IDonationService
{
    private readonly ApplicationDbContext _context;
    private readonly IRabbitMQProducerService _rabbitMQProducer;
    private readonly IConfiguration _configuration;

    public DonationService(
        ApplicationDbContext context,
        IRabbitMQProducerService rabbitMQProducer,
        IConfiguration configuration)
    {
        _context = context;
        _rabbitMQProducer = rabbitMQProducer;
        _configuration = configuration;
    }

    public async Task<PagedResultDto<DonationDto>> GetByCampaignAsync(int campaignId, SearchRequestDto request)
    {
        var query = _context.Donations
            .Include(d => d.Campaign)
            .Where(d => d.CampaignId == campaignId);

        return await ToPagedResultAsync(query, request);
    }

    public async Task<PagedResultDto<DonationDto>> GetByUserAsync(int userId, SearchRequestDto request)
    {
        var query = _context.Donations
            .Include(d => d.Campaign)
            .Where(d => d.UserId == userId);

        return await ToPagedResultAsync(query, request);
    }

    public async Task<DonationDto?> GetByIdAsync(int id)
    {
        var entity = await _context.Donations
            .Include(d => d.Campaign)
            .FirstOrDefaultAsync(d => d.Id == id);

        return entity == null ? null : MapDonation(entity);
    }

    public async Task<DonationDto?> GetByIdForUserAsync(int id, int userId, bool includeAll)
    {
        var query = _context.Donations
            .Include(d => d.Campaign)
            .AsQueryable();

        if (!includeAll)
        {
            query = query.Where(d => d.UserId == userId);
        }

        var entity = await query.FirstOrDefaultAsync(d => d.Id == id);
        return entity == null ? null : MapDonation(entity);
    }

    public async Task<DonationDto?> GetByPaymentIntentForUserAsync(string paymentIntentId, int userId, bool includeAll)
    {
        if (string.IsNullOrWhiteSpace(paymentIntentId))
            return null;

        var query = _context.Donations
            .Include(d => d.Campaign)
            .Where(d => d.StripePaymentIntentId == paymentIntentId)
            .AsQueryable();

        if (!includeAll)
        {
            query = query.Where(d => d.UserId == userId);
        }

        var entity = await query.FirstOrDefaultAsync();
        return entity == null ? null : MapDonation(entity);
    }

    public async Task<PaymentIntentResponseDto> CreatePaymentIntentAsync(PaymentIntentRequestDto dto, int? userId)
    {
        if (dto.Amount < 0.5m)
            throw new InvalidOperationException("Iznos donacije mora biti najmanje 0.50 BAM.");

        var campaign = await _context.Campaigns.FirstOrDefaultAsync(c => c.Id == dto.CampaignId);
        if (campaign == null)
            throw new KeyNotFoundException("Kampanja nije pronadjena.");

        if (!campaign.IsActive || campaign.EndDate < DateTime.UtcNow)
            throw new InvalidOperationException("Donacija nije moguca jer kampanja nije aktivna.");

        if (string.IsNullOrWhiteSpace(dto.IdempotencyKey))
            throw new InvalidOperationException("Idempotency kljuc je obavezan za sigurnu obradu donacije.");

        var stripeKey = GetStripeSetting("SecretKey", "STRIPE_SECRET_KEY");
        var publishableKey = GetStripeSetting("PublishableKey", "STRIPE_PUBLISHABLE_KEY");
        if (string.IsNullOrWhiteSpace(stripeKey) || string.IsNullOrWhiteSpace(publishableKey))
            throw new InvalidOperationException("Stripe nije konfigurisan.");

        StripeConfiguration.ApiKey = stripeKey;
        var service = new PaymentIntentService();
        var paymentIntent = await service.CreateAsync(
            new PaymentIntentCreateOptions
            {
                Amount = decimal.ToInt64(decimal.Round(dto.Amount * 100m, 0)),
                Currency = "bam",
                Metadata = new Dictionary<string, string>
                {
                    ["campaignId"] = dto.CampaignId.ToString(),
                    ["amountBam"] = dto.Amount.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
                    ["isAnonymous"] = dto.IsAnonymous.ToString(),
                    ["donorName"] = dto.DonorName ?? string.Empty,
                    ["message"] = dto.Message ?? string.Empty,
                    ["userId"] = userId?.ToString() ?? string.Empty
                }
            },
            new RequestOptions
            {
                IdempotencyKey = BuildPaymentIntentIdempotencyKey(dto, userId)
            });

        return new PaymentIntentResponseDto
        {
            ClientSecret = paymentIntent.ClientSecret,
            PaymentIntentId = paymentIntent.Id,
            PublishableKey = publishableKey,
            PaymentStatus = paymentIntent.Status ?? "requires_payment_method"
        };
    }

    public async Task<DonationDto> RecordStripePaymentAsync(StripeDonationCreateDto dto, int? userId)
    {
        if (string.IsNullOrWhiteSpace(dto.PaymentIntentId))
            throw new InvalidOperationException("Stripe PaymentIntent identifikator je obavezan.");

        var existingDonation = await _context.Donations
            .Include(d => d.Campaign)
            .FirstOrDefaultAsync(d => d.StripePaymentIntentId == dto.PaymentIntentId);
        if (existingDonation != null)
            return MapDonation(existingDonation);

        var campaign = await _context.Campaigns
            .Include(c => c.Organization)
            .FirstOrDefaultAsync(c => c.Id == dto.CampaignId);
        if (campaign == null)
            throw new KeyNotFoundException("Kampanja nije pronadjena.");

        if (!campaign.IsActive)
            throw new InvalidOperationException("Donacija nije moguca jer je kampanja zatvorena.");

        var donation = new Donation
        {
            Amount = dto.Amount,
            Currency = string.IsNullOrWhiteSpace(dto.Currency) ? "BAM" : dto.Currency.ToUpperInvariant(),
            Status = DonationStatus.Completed,
            IsAnonymous = dto.IsAnonymous,
            DonorName = dto.DonorName,
            Message = dto.Message,
            StripePaymentIntentId = dto.PaymentIntentId,
            StripeChargeId = dto.ChargeId,
            CampaignId = dto.CampaignId,
            UserId = userId
        };

        _context.Donations.Add(donation);
        campaign.CurrentAmount += dto.Amount;

        if (userId.HasValue)
        {
            _context.VolunteerHistories.Add(new VolunteerHistory
            {
                UserId = userId.Value,
                CampaignId = dto.CampaignId,
                ActionType = "Donation",
                Description = $"Korisnik je donirao {dto.Amount:F2} BAM kampanji.",
                OccurredAt = DateTime.UtcNow
            });
        }

        await _context.SaveChangesAsync();
        await PublishDonationNotificationAsync(campaign, donation);

        return (await GetByIdAsync(donation.Id))!;
    }

    public async Task<DonationDto> RefundAsync(int donationId)
    {
        var donation = await _context.Donations
            .Include(d => d.Campaign)
            .FirstOrDefaultAsync(d => d.Id == donationId);

        if (donation == null)
            throw new KeyNotFoundException("Donacija nije pronadjena.");

        if (donation.Status == DonationStatus.Refunded)
            throw new InvalidOperationException("Donacija je vec refundirana.");

        if (donation.Status != DonationStatus.Completed)
            throw new InvalidOperationException("Samo uspjesne donacije se mogu refundirati.");

        if (string.IsNullOrWhiteSpace(donation.StripePaymentIntentId) && string.IsNullOrWhiteSpace(donation.StripeChargeId))
            throw new InvalidOperationException("Stripe identifikator donacije nije pronadjen.");

        var stripeKey = GetStripeSetting("SecretKey", "STRIPE_SECRET_KEY");
        if (string.IsNullOrWhiteSpace(stripeKey))
            throw new InvalidOperationException("Stripe nije konfigurisan za refundacije.");

        StripeConfiguration.ApiKey = stripeKey;
        var refundService = new RefundService();
        var refund = await refundService.CreateAsync(new RefundCreateOptions
        {
            PaymentIntent = donation.StripePaymentIntentId,
            Charge = string.IsNullOrWhiteSpace(donation.StripePaymentIntentId) ? donation.StripeChargeId : null
        });

        if (refund.Status == "failed")
            throw new InvalidOperationException("Stripe refund nije uspio.");

        await MarkRefundedInternalAsync(donation, donation.Amount);
        return (await GetByIdAsync(donation.Id))!;
    }

    public async Task<bool> MarkRefundedAsync(string? paymentIntentId, string? chargeId, decimal refundedAmount)
    {
        var donation = await FindDonationByStripeIdentifiersAsync(paymentIntentId, chargeId);
        if (donation == null)
            return false;

        if (refundedAmount < donation.Amount)
            return false;

        if (donation.Status == DonationStatus.Refunded)
            return true;

        await MarkRefundedInternalAsync(donation, refundedAmount);
        return true;
    }

    public async Task<bool> MarkRefundFailedAsync(string? paymentIntentId, string? chargeId, decimal refundedAmount)
    {
        var donation = await FindDonationByStripeIdentifiersAsync(paymentIntentId, chargeId);
        if (donation == null)
            return false;

        if (donation.Status != DonationStatus.Refunded)
            return true;

        await MarkRefundFailedInternalAsync(donation, refundedAmount);
        return true;
    }

    public async Task<List<DonationDto>> GetRecentAsync(int count = 10)
    {
        var donations = await _context.Donations
            .Include(d => d.Campaign)
            .OrderByDescending(d => d.CreatedAt)
            .Take(Math.Clamp(count, 1, 50))
            .ToListAsync();

        return donations.Select(MapDonation).ToList();
    }

    private async Task<PagedResultDto<DonationDto>> ToPagedResultAsync(IQueryable<Donation> query, SearchRequestDto request)
    {
        var pageSize = Math.Clamp(request.PageSize, 1, 100);
        var page = Math.Max(1, request.Page);
        var totalCount = await query.CountAsync();
        var entities = await query
            .OrderByDescending(d => d.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new PagedResultDto<DonationDto>
        {
            Items = entities.Select(MapDonation).ToList(),
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    private static DonationDto MapDonation(Donation d) => new()
    {
        Id = d.Id,
        Amount = d.Amount,
        Currency = d.Currency,
        Status = d.Status.ToString(),
        IsAnonymous = d.IsAnonymous,
        DonorName = d.IsAnonymous ? "Anonimno" : d.DonorName,
        Message = d.Message,
        CampaignTitle = d.Campaign.Title,
        CreatedAt = d.CreatedAt
    };

    private async Task<Donation?> FindDonationByStripeIdentifiersAsync(string? paymentIntentId, string? chargeId)
    {
        var query = _context.Donations
            .Include(d => d.Campaign)
            .AsQueryable();

        Donation? donation = null;
        if (!string.IsNullOrWhiteSpace(chargeId))
            donation = await query.FirstOrDefaultAsync(d => d.StripeChargeId == chargeId);

        if (donation == null && !string.IsNullOrWhiteSpace(paymentIntentId))
            donation = await query.FirstOrDefaultAsync(d => d.StripePaymentIntentId == paymentIntentId);

        return donation;
    }

    private async Task MarkRefundedInternalAsync(Donation donation, decimal refundedAmount)
    {
        donation.Status = DonationStatus.Refunded;
        if (donation.Campaign != null)
            donation.Campaign.CurrentAmount = Math.Max(0m, donation.Campaign.CurrentAmount - refundedAmount);

        if (donation.UserId.HasValue)
        {
            _context.VolunteerHistories.Add(new VolunteerHistory
            {
                UserId = donation.UserId.Value,
                CampaignId = donation.CampaignId,
                ActionType = "DonationRefund",
                Description = $"Donacija u iznosu {refundedAmount:F2} BAM je refundirana.",
                OccurredAt = DateTime.UtcNow
            });
        }

        await _context.SaveChangesAsync();
    }

    private async Task MarkRefundFailedInternalAsync(Donation donation, decimal refundedAmount)
    {
        donation.Status = DonationStatus.Completed;
        if (donation.Campaign != null)
            donation.Campaign.CurrentAmount += refundedAmount;

        await _context.SaveChangesAsync();
    }

    private async Task PublishDonationNotificationAsync(Campaign campaign, Donation donation)
    {
        var donorDisplayName = donation.IsAnonymous ? "Anonimni donator" : donation.DonorName ?? "Donator";
        var sentTo = new HashSet<int>();

        if (donation.UserId.HasValue)
        {
            var donorUser = await _context.Volunteers.FindAsync(donation.UserId.Value);
            if (donorUser != null)
            {
                sentTo.Add(donorUser.Id);
                await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
                {
                    UserId = donorUser.Id,
                    Email = donorUser.Email,
                    Title = "Donacija uspjesna",
                    Message = $"Vasa donacija za kampanju {campaign.Title} je evidentirana.",
                    Type = NotificationType.DonationReceived.ToString(),
                    CampaignId = campaign.Id,
                    ActionUrl = $"/campaigns/{campaign.Id}",
                    PersistInAppNotification = true,
                    SendEmail = true,
                    EmailSubject = $"Donacija uspjesna: {donation.Amount:F2} BAM",
                    EmailBody = $"<h2>Donacija uspjesna</h2><p>Hvala vam na donaciji od <strong>{donation.Amount:F2} BAM</strong> za kampanju <strong>{campaign.Title}</strong>.</p>" +
                                (string.IsNullOrWhiteSpace(donation.Message) ? string.Empty : $"<p>Poruka: <em>{System.Net.WebUtility.HtmlEncode(donation.Message)}</em></p>")
                });
            }
        }

        var recipientUserId = campaign.Organization?.OwnerUserId ?? campaign.CreatedByUserId;
        if (!sentTo.Contains(recipientUserId))
        {
            var recipientUser = await _context.Volunteers.FindAsync(recipientUserId);
            if (recipientUser != null)
            {
                await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
                {
                    UserId = recipientUser.Id,
                    Email = recipientUser.Email,
                    Title = "Nova donacija",
                    Message = $"Primljena je donacija za kampanju {campaign.Title}.",
                    Type = NotificationType.DonationReceived.ToString(),
                    CampaignId = campaign.Id,
                    ActionUrl = $"/campaigns/{campaign.Id}",
                    PersistInAppNotification = true,
                    SendEmail = true,
                    EmailSubject = $"Nova donacija: {donation.Amount:F2} BAM",
                    EmailBody = $"<h2>Nova donacija primljena</h2><p><strong>{donorDisplayName}</strong> je donirao/la {donation.Amount:F2} BAM za kampanju <strong>{campaign.Title}</strong>.</p>" +
                                (string.IsNullOrWhiteSpace(donation.Message) ? string.Empty : $"<p>Poruka: <em>{System.Net.WebUtility.HtmlEncode(donation.Message)}</em></p>")
                });
            }
        }
    }

    private string? GetStripeSetting(string key, string environmentKey)
    {
        var configuredValue = _configuration[$"Stripe:{key}"];
        return !string.IsNullOrWhiteSpace(configuredValue) && !configuredValue.Contains("your_", StringComparison.OrdinalIgnoreCase)
            ? configuredValue
            : Environment.GetEnvironmentVariable(environmentKey);
    }

    private static string BuildPaymentIntentIdempotencyKey(PaymentIntentRequestDto dto, int? userId)
    {
        var supplied = dto.IdempotencyKey?.Trim();
        if (!string.IsNullOrWhiteSpace(supplied))
            return $"donation:{userId ?? 0}:{dto.CampaignId}:{supplied}";

        throw new InvalidOperationException("Idempotency kljuc je obavezan za sigurnu obradu donacije.");
    }
}
