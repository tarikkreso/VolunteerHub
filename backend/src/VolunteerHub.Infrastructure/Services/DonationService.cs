using Microsoft.EntityFrameworkCore;
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

    public DonationService(ApplicationDbContext context, IRabbitMQProducerService rabbitMQProducer)
    {
        _context = context;
        _rabbitMQProducer = rabbitMQProducer;
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

    public async Task<DonationDto> CreateAsync(DonationCreateDto dto, int? userId)
    {
        var isStripeBacked = !string.IsNullOrWhiteSpace(dto.StripePaymentIntentId);

        var existingDonation = isStripeBacked
            ? await _context.Donations
                .Include(d => d.Campaign)
                .FirstOrDefaultAsync(d => d.StripePaymentIntentId == dto.StripePaymentIntentId)
            : null;

        if (existingDonation != null)
        {
            existingDonation.Amount = dto.Amount;
            existingDonation.Currency = "BAM";
            existingDonation.Status = DonationStatus.Completed;
            existingDonation.IsAnonymous = dto.IsAnonymous;
            if (!string.IsNullOrWhiteSpace(dto.DonorName))
                existingDonation.DonorName = dto.DonorName;
            if (!string.IsNullOrWhiteSpace(dto.Message))
                existingDonation.Message = dto.Message;
            existingDonation.StripePaymentIntentId = dto.StripePaymentIntentId;
            existingDonation.UserId = userId ?? existingDonation.UserId;
            existingDonation.CampaignId = dto.CampaignId;

            await _context.SaveChangesAsync();
            return (await GetByIdAsync(existingDonation.Id))!;
        }

        var campaign = await _context.Campaigns.FindAsync(dto.CampaignId);
        if (campaign == null)
            throw new KeyNotFoundException("Kampanja nije pronađena.");

        if (!isStripeBacked && !campaign.IsActive)
            throw new InvalidOperationException("Donacija nije moguća jer je kampanja zatvorena.");

        var donation = new Donation
        {
            Amount = dto.Amount,
            Currency = "BAM",
            Status = isStripeBacked ? DonationStatus.Completed : DonationStatus.Pending,
            IsAnonymous = dto.IsAnonymous,
            DonorName = dto.DonorName,
            Message = dto.Message,
            StripePaymentIntentId = dto.StripePaymentIntentId,
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

        await _rabbitMQProducer.PublishDonationNotificationAsync(
            dto.CampaignId,
            dto.Amount,
            "BAM",
            dto.IsAnonymous ? null : dto.DonorName,
            dto.Message);

        return (await GetByIdAsync(donation.Id))!;
    }

    public async Task<List<DonationDto>> GetRecentAsync(int count = 10)
    {
        var donations = await _context.Donations
            .Include(d => d.Campaign)
            .OrderByDescending(d => d.CreatedAt)
            .Take(count)
            .ToListAsync();

        return donations.Select(MapDonation).ToList();
    }

    private async Task<PagedResultDto<DonationDto>> ToPagedResultAsync(IQueryable<Donation> query, SearchRequestDto request)
    {
        var totalCount = await query.CountAsync();
        var entities = await query
            .OrderByDescending(d => d.CreatedAt)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync();

        var items = entities.Select(MapDonation).ToList();

        return new PagedResultDto<DonationDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = request.Page,
            PageSize = request.PageSize
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
}
