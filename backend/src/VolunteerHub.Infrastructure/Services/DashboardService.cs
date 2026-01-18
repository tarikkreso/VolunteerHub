using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class DashboardService : IDashboardService
{
    private readonly ApplicationDbContext _context;

    public DashboardService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<DashboardStatsDto> GetStatsAsync(DateTime? startDate = null, DateTime? endDate = null)
    {
        var eventsQuery = _context.Events.AsQueryable();
        var shiftsQuery = _context.Shifts.AsQueryable();
        var approvedRegistrationsQuery = _context.ShiftRegistrations
            .Where(r => r.IsApproved && r.HoursWorked.HasValue);
        var donationsQuery = _context.Donations
            .Where(d => d.Status == DonationStatus.Completed);
        var campaignsQuery = _context.Campaigns.AsQueryable();
        var pendingRegistrationsQuery = _context.ShiftRegistrations
            .Where(r => r.Status == ShiftStatus.Pending || r.Status == ShiftStatus.Registered);

        if (startDate.HasValue)
        {
            eventsQuery = eventsQuery.Where(e => e.StartDate >= startDate.Value);
            shiftsQuery = shiftsQuery.Where(s => s.StartTime >= startDate.Value);
            approvedRegistrationsQuery = approvedRegistrationsQuery.Where(r =>
                (r.CheckOutTime ?? r.CreatedAt) >= startDate.Value);
            donationsQuery = donationsQuery.Where(d => d.CreatedAt >= startDate.Value);
            campaignsQuery = campaignsQuery.Where(c => c.EndDate >= startDate.Value);
            pendingRegistrationsQuery = pendingRegistrationsQuery.Where(r => r.Shift.StartTime >= startDate.Value);
        }

        if (endDate.HasValue)
        {
            eventsQuery = eventsQuery.Where(e => e.StartDate <= endDate.Value);
            shiftsQuery = shiftsQuery.Where(s => s.StartTime <= endDate.Value);
            approvedRegistrationsQuery = approvedRegistrationsQuery.Where(r =>
                (r.CheckOutTime ?? r.CreatedAt) <= endDate.Value);
            donationsQuery = donationsQuery.Where(d => d.CreatedAt <= endDate.Value);
            campaignsQuery = campaignsQuery.Where(c => c.StartDate <= endDate.Value);
            pendingRegistrationsQuery = pendingRegistrationsQuery.Where(r => r.Shift.StartTime <= endDate.Value);
        }

        var recentActivityQuery = _context.VolunteerHistories
            .Include(v => v.Event)
            .Include(v => v.Shift)
            .Include(v => v.Campaign)
            .OrderByDescending(v => v.OccurredAt)
            .AsQueryable();

        if (startDate.HasValue)
            recentActivityQuery = recentActivityQuery.Where(v => v.OccurredAt >= startDate.Value);
        if (endDate.HasValue)
            recentActivityQuery = recentActivityQuery.Where(v => v.OccurredAt <= endDate.Value);

        var recentActivity = await recentActivityQuery
            .Take(10)
            .Select(v => new VolunteerHistoryDto
            {
                Id = v.Id,
                UserId = v.UserId,
                ActionType = v.ActionType,
                Description = v.Description,
                EventTitle = v.Event != null ? v.Event.Title : null,
                ShiftName = v.Shift != null ? v.Shift.Name : null,
                CampaignTitle = v.Campaign != null ? v.Campaign.Title : null,
                OccurredAt = v.OccurredAt,
                CreatedAt = v.CreatedAt
            })
            .ToListAsync();

        var totalHours = await approvedRegistrationsQuery.SumAsync(r => r.HoursWorked ?? 0);

        return new DashboardStatsDto
        {
            TotalEvents = await eventsQuery.CountAsync(),
            TotalShifts = await shiftsQuery.CountAsync(),
            TotalVolunteers = await _context.Volunteers.CountAsync(u => u.Role == UserRole.Volunteer),
            TotalHours = totalHours,
            ActiveCampaigns = await campaignsQuery.CountAsync(c => c.IsActive),
            TotalDonations = await donationsQuery.SumAsync(d => d.Amount),
            PendingApprovals = await pendingRegistrationsQuery.CountAsync(),
            UpcomingShiftsCount = await shiftsQuery.CountAsync(s => s.StartTime > DateTime.UtcNow),
            RecentActivity = recentActivity
        };
    }
}
