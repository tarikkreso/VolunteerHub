using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class ReportService : IReportService
{
    private readonly ApplicationDbContext _context;

    public ReportService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<VolunteerParticipationReportDto>> GetVolunteerParticipationAsync(DateTime? from, DateTime? to)
    {
        var query = _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
                .ThenInclude(s => s.Event)
            .Where(sr => sr.User.Role == UserRole.Volunteer)
            .AsQueryable();

        if (from.HasValue)
            query = query.Where(sr => sr.Shift.StartTime >= from.Value);
        if (to.HasValue)
            query = query.Where(sr => sr.Shift.EndTime <= to.Value);

        var grouped = await query
            .GroupBy(sr => new { sr.UserId, UserName = sr.User.FirstName + " " + sr.User.LastName })
            .Select(g => new VolunteerParticipationReportDto
            {
                UserId = g.Key.UserId,
                UserName = g.Key.UserName,
                EventCount = g.Select(sr => sr.Shift.EventId).Distinct().Count(),
                ShiftCount = g.Count(),
                TotalHours = g.Sum(sr => sr.HoursWorked ?? 0),
                ApprovedShifts = g.Count(sr => sr.Status == ShiftStatus.Approved || sr.Status == ShiftStatus.Completed),
                RejectedShifts = g.Count(sr => sr.Status == ShiftStatus.Rejected)
            })
            .OrderByDescending(r => r.TotalHours)
            .ToListAsync();

        return grouped;
    }

    public async Task<List<HoursByVolunteerReportDto>> GetHoursByVolunteerAsync(DateTime? from, DateTime? to)
    {
        var query = _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
            .Where(sr => sr.Status == ShiftStatus.Approved || sr.Status == ShiftStatus.Completed)
            .Where(sr => sr.User.Role == UserRole.Volunteer)
            .AsQueryable();

        if (from.HasValue)
            query = query.Where(sr => sr.Shift.StartTime >= from.Value);
        if (to.HasValue)
            query = query.Where(sr => sr.Shift.EndTime <= to.Value);

        var grouped = await query
            .GroupBy(sr => new { sr.UserId, UserName = sr.User.FirstName + " " + sr.User.LastName })
            .Select(g => new HoursByVolunteerReportDto
            {
                UserId = g.Key.UserId,
                UserName = g.Key.UserName,
                TotalApprovedHours = g.Sum(sr => sr.HoursWorked ?? 0),
                TotalShifts = g.Count(),
                AverageHoursPerShift = g.Count() > 0 ? g.Sum(sr => sr.HoursWorked ?? 0) / g.Count() : 0
            })
            .OrderByDescending(r => r.TotalApprovedHours)
            .ToListAsync();

        return grouped;
    }

    public async Task<List<EventAttendanceReportDto>> GetEventAttendanceAsync(DateTime? from, DateTime? to)
    {
        var query = _context.Events
            .Include(e => e.Shifts)
                .ThenInclude(s => s.Registrations)
            .Where(e => !e.IsDeleted)
            .AsQueryable();

        if (from.HasValue)
            query = query.Where(e => e.StartDate >= from.Value);
        if (to.HasValue)
            query = query.Where(e => e.EndDate <= to.Value);

        var events = await query
            .Select(e => new EventAttendanceReportDto
            {
                EventId = e.Id,
                EventTitle = e.Title,
                StartDate = e.StartDate,
                EndDate = e.EndDate,
                ShiftCount = e.Shifts.Count,
                TotalRegistrations = e.Shifts.SelectMany(s => s.Registrations).Count(),
                ApprovedRegistrations = e.Shifts
                    .SelectMany(s => s.Registrations)
                    .Count(sr => sr.Status == ShiftStatus.Approved || sr.Status == ShiftStatus.Completed),
                TotalHours = e.Shifts
                    .SelectMany(s => s.Registrations)
                    .Where(sr => sr.Status == ShiftStatus.Approved || sr.Status == ShiftStatus.Completed)
                    .Sum(sr => sr.HoursWorked ?? 0)
            })
            .OrderByDescending(r => r.TotalRegistrations)
            .ToListAsync();

        return events;
    }

    public async Task<List<DonationSummaryReportDto>> GetDonationsSummaryAsync(DateTime? from, DateTime? to)
    {
        var query = _context.Campaigns
            .Include(c => c.Donations)
            .AsQueryable();

        var campaigns = await query.ToListAsync();

        return campaigns.Select(c =>
        {
            var filteredDonations = c.Donations
                .Where(d => d.Status == DonationStatus.Completed);

            if (from.HasValue)
                filteredDonations = filteredDonations.Where(d => d.CreatedAt >= from.Value);
            if (to.HasValue)
                filteredDonations = filteredDonations.Where(d => d.CreatedAt <= to.Value);

            var donationList = filteredDonations.ToList();
            var totalRaised = donationList.Sum(d => d.Amount);
            var donationCount = donationList.Count;

            return new DonationSummaryReportDto
            {
                CampaignId = c.Id,
                CampaignTitle = c.Title,
                GoalAmount = c.GoalAmount,
                RaisedAmount = totalRaised,
                DonationCount = donationCount,
                IsActive = c.IsActive,
                AverageDonation = donationCount > 0 ? totalRaised / donationCount : 0
            };
        })
        .OrderByDescending(r => r.RaisedAmount)
        .ToList();
    }
}
