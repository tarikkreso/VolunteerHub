using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class LeaderboardService : ILeaderboardService
{
    private readonly ApplicationDbContext _context;

    public LeaderboardService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<LeaderboardEntryDto>> GetTopAsync(int count = 10)
    {
        count = Math.Clamp(count, 1, 100);

        return await _context.LeaderboardEntries
            .Include(e => e.User)
            .Where(e => e.User.Role == UserRole.Volunteer)
            .OrderByDescending(e => e.TotalHours)
            .Take(count)
            .Select(e => new LeaderboardEntryDto
            {
                UserId = e.UserId,
                UserName = e.User.FirstName + " " + e.User.LastName,
                ProfileImageUrl = e.User.ProfileImageUrl,
                TotalHours = e.TotalHours,
                TotalEvents = e.TotalEvents,
                Rank = e.Rank,
                Points = e.Points
            })
            .ToListAsync();
    }

    public async Task<PagedResultDto<LeaderboardEntryDto>> GetPagedAsync(int page = 1, int pageSize = 20)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _context.LeaderboardEntries
            .Include(e => e.User)
            .Where(e => e.User.Role == UserRole.Volunteer)
            .OrderByDescending(e => e.TotalHours)
            .AsQueryable();

        var totalCount = await query.CountAsync();
        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(e => new LeaderboardEntryDto
            {
                UserId = e.UserId,
                UserName = e.User.FirstName + " " + e.User.LastName,
                ProfileImageUrl = e.User.ProfileImageUrl,
                TotalHours = e.TotalHours,
                TotalEvents = e.TotalEvents,
                Rank = e.Rank,
                Points = e.Points
            })
            .ToListAsync();

        return new PagedResultDto<LeaderboardEntryDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<LeaderboardEntryDto?> GetUserRankAsync(int userId)
    {
        var entry = await _context.LeaderboardEntries
            .Include(e => e.User)
            .FirstOrDefaultAsync(e => e.UserId == userId && e.User.Role == UserRole.Volunteer);

        if (entry == null) return null;

        return new LeaderboardEntryDto
        {
            UserId = entry.UserId,
            UserName = entry.User.FirstName + " " + entry.User.LastName,
            ProfileImageUrl = entry.User.ProfileImageUrl,
            TotalHours = entry.TotalHours,
            TotalEvents = entry.TotalEvents,
            Rank = entry.Rank,
            Points = entry.Points
        };
    }
}
