using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class CampaignService : ICampaignService
{
    private readonly ApplicationDbContext _context;

    public CampaignService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResultDto<CampaignDto>> GetAllAsync(SearchRequestDto request)
    {
        var query = _context.Campaigns
            .Include(c => c.Donations)
            .Include(c => c.Organization)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.Query))
            query = query.Where(c => c.Title.Contains(request.Query) || c.Description.Contains(request.Query));

        var totalCount = await query.CountAsync();
        var entities = await query
            .OrderByDescending(c => c.IsFeatured)
            .ThenByDescending(c => c.CreatedAt)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync();

        var items = entities.Select(MapCampaign).ToList();

        return new PagedResultDto<CampaignDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = request.Page,
            PageSize = request.PageSize
        };
    }

    public async Task<CampaignDto?> GetByIdAsync(int id)
    {
        var entity = await _context.Campaigns
            .Include(c => c.Donations)
            .Include(c => c.Organization)
            .FirstOrDefaultAsync(c => c.Id == id);

        return entity == null ? null : MapCampaign(entity);
    }

    public async Task<CampaignDto> CreateAsync(CampaignCreateDto dto, int userId)
    {
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

        return (await GetByIdAsync(campaign.Id))!;
    }

    public async Task<bool> UpdateAsync(int id, CampaignCreateDto dto)
    {
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

    private static CampaignDto MapCampaign(Campaign c) => new()
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
        DonationCount = c.Donations.Count,
        OrganizationName = c.Organization != null ? c.Organization.Name : null,
        CreatedAt = c.CreatedAt
    };
}
