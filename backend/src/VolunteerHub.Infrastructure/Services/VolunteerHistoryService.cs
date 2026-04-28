using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class VolunteerHistoryService : IVolunteerHistoryService
{
    private readonly ApplicationDbContext _context;

    public VolunteerHistoryService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<VolunteerHistoryDto>> GetByUserAsync(int userId)
    {
        return await _context.VolunteerHistories
            .Include(h => h.Event)
            .Include(h => h.Campaign)
            .Include(h => h.Shift)
            .Where(h => h.UserId == userId)
            .OrderByDescending(h => h.OccurredAt)
            .Take(100)
            .Select(h => new VolunteerHistoryDto
            {
                Id = h.Id,
                UserId = h.UserId,
                ActionType = h.ActionType,
                Description = h.Description,
                EventTitle = h.Event != null ? h.Event.Title : null,
                CampaignTitle = h.Campaign != null ? h.Campaign.Title : null,
                ShiftName = h.Shift != null ? h.Shift.Name : null,
                OccurredAt = h.OccurredAt,
                CreatedAt = h.CreatedAt
            })
            .ToListAsync();
    }
}
