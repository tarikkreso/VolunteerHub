using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Infrastructure.Data;
using VolunteerHub.Domain.Entities;

namespace VolunteerHub.Infrastructure.Services;

public class UserService : IUserService
{
    private readonly ApplicationDbContext _context;
    private readonly UserManager<ApplicationUser> _userManager;

    public UserService(ApplicationDbContext context, UserManager<ApplicationUser> userManager)
    {
        _context = context;
        _userManager = userManager;
    }

    public async Task<PagedResultDto<UserDto>> GetAllAsync(SearchRequestDto request)
    {
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 100);

        var query = _context.Volunteers
            .Include(u => u.City)
            .Where(u => !u.IsDeleted)
            .AsQueryable();

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
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
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
                CityId = u.CityId,
                CityName = u.City?.Name,
                IsActive = u.IsActive,
                CreatedAt = u.CreatedAt,
                TotalHours = lb?.TotalHours ?? 0,
                TotalEvents = lb?.TotalEvents ?? 0
            };
        }).ToList();

        return new PagedResultDto<UserDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<UserDto?> GetByIdAsync(int id)
    {
        var user = await _context.Volunteers
            .Include(u => u.City)
            .FirstOrDefaultAsync(u => u.Id == id && !u.IsDeleted);

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
            CityId = user.CityId,
            CityName = user.City?.Name,
            IsActive = user.IsActive,
            CreatedAt = user.CreatedAt
        };
    }

    public async Task<bool> UpdateAsync(int id, UserUpdateDto dto)
    {
        var user = await _context.Volunteers.FirstOrDefaultAsync(u => u.Id == id);
        if (user == null) return false;

        var identityUser = user.IdentityUserId.HasValue
            ? await _userManager.FindByIdAsync(user.IdentityUserId.Value.ToString())
            : null;

        if (dto.FirstName != null) user.FirstName = dto.FirstName.Trim();
        if (dto.LastName != null) user.LastName = dto.LastName.Trim();
        if (dto.Phone != null) user.Phone = string.IsNullOrWhiteSpace(dto.Phone) ? null : dto.Phone.Trim();
        if (dto.ProfileImageUrl != null) user.ProfileImageUrl = string.IsNullOrWhiteSpace(dto.ProfileImageUrl) ? null : dto.ProfileImageUrl.Trim();
        if (dto.Bio != null) user.Bio = string.IsNullOrWhiteSpace(dto.Bio) ? null : dto.Bio.Trim();
        if (dto.CityId.HasValue) user.CityId = dto.CityId;
        if (dto.IsActive.HasValue) user.IsActive = dto.IsActive.Value;

        if (!string.IsNullOrWhiteSpace(dto.Email))
        {
            var normalizedEmail = dto.Email.Trim();
            var emailTaken = await _context.Volunteers.AnyAsync(u => u.Email == normalizedEmail && u.Id != id);
            var identityEmailTaken = await _userManager.FindByEmailAsync(normalizedEmail);
            if (identityEmailTaken != null && (!user.IdentityUserId.HasValue || identityEmailTaken.Id != user.IdentityUserId.Value))
            {
                emailTaken = true;
            }
            if (emailTaken)
            {
                throw new InvalidOperationException("Email adresa je već u upotrebi.");
            }

            user.Email = normalizedEmail;

            if (identityUser != null)
            {
                identityUser.Email = normalizedEmail;
                identityUser.UserName = normalizedEmail;
                identityUser.IsActive = user.IsActive;

                var identityResult = await _userManager.UpdateAsync(identityUser);
                if (!identityResult.Succeeded)
                {
                    throw new InvalidOperationException(string.Join(" ", identityResult.Errors.Select(e => e.Description)));
                }
            }
        }
        else if (identityUser != null)
        {
            identityUser.IsActive = user.IsActive;
            var identityResult = await _userManager.UpdateAsync(identityUser);
            if (!identityResult.Succeeded)
            {
                throw new InvalidOperationException(string.Join(" ", identityResult.Errors.Select(e => e.Description)));
            }
        }

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
