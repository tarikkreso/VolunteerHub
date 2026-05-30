using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class CampaignService : ICampaignService
{
    private readonly ApplicationDbContext _context;

    public CampaignService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResultDto<CampaignDto>> GetAllAsync(SearchRequestDto request, int? userId = null)
    {
        var query = _context.Campaigns
            .Include(c => c.Donations)
            .Include(c => c.Organization)
            .Where(c => !c.IsDeleted)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.Query))
            query = query.Where(c => c.Title.Contains(request.Query) || c.Description.Contains(request.Query));

        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 100);
        var totalCount = await query.CountAsync();
        var entities = await query
            .OrderByDescending(c => c.IsFeatured)
            .ThenByDescending(c => c.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var items = entities.Select(c => MapCampaign(c, userId)).ToList();

        return new PagedResultDto<CampaignDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<CampaignDto?> GetByIdAsync(int id, int? userId = null)
    {
        var entity = await _context.Campaigns
            .Include(c => c.Donations)
            .Include(c => c.Organization)
            .FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted);

        return entity == null ? null : MapCampaign(entity, userId);
    }

    public async Task<CampaignDto> CreateAsync(CampaignCreateDto dto, int userId)
    {
        ValidateCampaignDates(dto);

        var campaign = new Campaign
        {
            Title = dto.Title,
            Description = dto.Description,
            ImageUrl = dto.ImageUrl,
            GoalAmount = dto.GoalAmount,
            StartDate = dto.StartDate,
            EndDate = dto.EndDate,
            IsActive = dto.IsActive,
            IsFeatured = dto.IsFeatured,
            OrganizationId = dto.OrganizationId,
            CreatedByUserId = userId
        };

        _context.Campaigns.Add(campaign);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(campaign.Id, userId))!;
    }

    public async Task<bool> UpdateAsync(int id, CampaignCreateDto dto)
    {
        ValidateCampaignDates(dto);

        var campaign = await _context.Campaigns.FindAsync(id);
        if (campaign == null)
            return false;

        campaign.Title = dto.Title;
        campaign.Description = dto.Description;
        campaign.ImageUrl = dto.ImageUrl;
        campaign.GoalAmount = dto.GoalAmount;
        campaign.StartDate = dto.StartDate;
        campaign.EndDate = dto.EndDate;
        campaign.IsActive = dto.IsActive;
        campaign.IsFeatured = dto.IsFeatured;
        campaign.OrganizationId = dto.OrganizationId;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var campaign = await _context.Campaigns.FindAsync(id);
        if (campaign == null)
            return false;

        campaign.IsDeleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    private static CampaignDto MapCampaign(Campaign c, int? userId = null) => new()
    {
        Id = c.Id,
        Title = c.Title,
        Description = c.Description,
        ImageUrl = c.ImageUrl,
        GoalAmount = c.GoalAmount,
        CurrentAmount = c.CurrentAmount,
        StartDate = c.StartDate,
        EndDate = c.EndDate,
        IsActive = c.IsActive,
        IsFeatured = c.IsFeatured,
        DonationCount = c.Donations.Count(d => d.Status == DonationStatus.Completed),
        OrganizationName = c.Organization != null ? c.Organization.Name : null,
        IsPaid = userId.HasValue && c.Donations.Any(d =>
            d.UserId == userId.Value && d.Status == DonationStatus.Completed),
        CreatedAt = c.CreatedAt
    };

    private static void ValidateCampaignDates(CampaignCreateDto dto)
    {
        if (dto.EndDate <= dto.StartDate)
            throw new InvalidOperationException("Zavrsni datum kampanje mora biti nakon pocetnog datuma.");
    }
}
