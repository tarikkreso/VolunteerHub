using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class UserService : IUserService
{
    private readonly ApplicationDbContext _context;

    public UserService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResultDto<UserDto>> GetAllAsync(SearchRequestDto request)
    {
        var query = _context.Volunteers.Include(u => u.City).AsQueryable();

        if (!string.IsNullOrEmpty(request.Query))
        {
            query = query.Where(u => u.FirstName.Contains(request.Query) ||
                                     u.LastName.Contains(request.Query) ||
                                     u.Email.Contains(request.Query));
        }

        var totalCount = await query.CountAsync();

        var pagedUsers = await query
            .OrderBy(u => u.LastName)
            .ThenBy(u => u.FirstName)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync();

        var userIds = pagedUsers.Select(u => u.Id).ToList();
        var leaderboardDict = await _context.LeaderboardEntries
            .Where(l => userIds.Contains(l.UserId))
            .ToDictionaryAsync(l => l.UserId);

        var items = pagedUsers.Select(u =>
        {
            leaderboardDict.TryGetValue(u.Id, out var lb);
            return new UserDto
            {
                Id = u.Id,
                FirstName = u.FirstName,
                LastName = u.LastName,
                Email = u.Email,
                Phone = u.Phone,
                ProfileImageUrl = u.ProfileImageUrl,
                Bio = u.Bio,
                Role = u.Role.ToString(),
                CityName = u.City?.Name,
                CreatedAt = u.CreatedAt,
                TotalHours = lb?.TotalHours ?? 0,
                TotalEvents = lb?.TotalEvents ?? 0
            };
        }).ToList();

        return new PagedResultDto<UserDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = request.Page,
            PageSize = request.PageSize
        };
    }

    public async Task<UserDto?> GetByIdAsync(int id)
    {
        var user = await _context.Volunteers
            .Include(u => u.City)
            .FirstOrDefaultAsync(u => u.Id == id);

        if (user == null) return null;

        return new UserDto
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Email = user.Email,
            Phone = user.Phone,
            ProfileImageUrl = user.ProfileImageUrl,
            Bio = user.Bio,
            Role = user.Role.ToString(),
            CityName = user.City?.Name,
            CreatedAt = user.CreatedAt
        };
    }

    public async Task<bool> UpdateAsync(int id, UserUpdateDto dto)
    {
        var user = await _context.Volunteers.FindAsync(id);
        if (user == null) return false;

        if (dto.FirstName != null) user.FirstName = dto.FirstName;
        if (dto.LastName != null) user.LastName = dto.LastName;
        if (dto.Phone != null) user.Phone = dto.Phone;
        if (dto.ProfileImageUrl != null) user.ProfileImageUrl = dto.ProfileImageUrl;
        if (dto.Bio != null) user.Bio = dto.Bio;
        if (dto.CityId.HasValue) user.CityId = dto.CityId;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<UserStatsDto> GetStatsAsync(int userId)
    {
        var leaderboard = await _context.LeaderboardEntries
            .FirstOrDefaultAsync(l => l.UserId == userId);

        var upcomingShifts = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Where(sr => sr.UserId == userId && sr.Shift.StartTime > DateTime.UtcNow)
            .CountAsync();

        return new UserStatsDto
        {
            TotalHours = leaderboard?.TotalHours ?? 0,
            TotalEvents = leaderboard?.TotalEvents ?? 0,
            UpcomingShifts = upcomingShifts,
            Rank = leaderboard?.Rank ?? 0,
            Points = leaderboard?.Points ?? 0
        };
    }
}
