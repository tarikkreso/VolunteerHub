using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class ShiftService : IShiftService
{
    private readonly ApplicationDbContext _context;

    public ShiftService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<ShiftDto>> GetByEventAsync(int eventId)
    {
        return await _context.Shifts
            .Include(s => s.Event)
            .Include(s => s.Registrations)
            .Where(s => s.EventId == eventId && !s.IsDeleted)
            .OrderBy(s => s.StartTime)
            .Take(100)
            .Select(s => new ShiftDto
            {
                Id = s.Id,
                Name = s.Name,
                Description = s.Description,
                StartTime = s.StartTime,
                EndTime = s.EndTime,
                MaxVolunteers = s.MaxVolunteers,
                CurrentVolunteers = s.Registrations.Count,
                IsLocked = s.IsLocked,
                EventId = s.EventId,
                EventTitle = s.Event.Title,
                CreatedAt = s.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<ShiftDto?> GetByIdAsync(int id)
    {
        var shift = await _context.Shifts
            .Include(s => s.Event)
            .Include(s => s.Registrations)
            .FirstOrDefaultAsync(s => s.Id == id && !s.IsDeleted);

        if (shift == null) return null;

        return new ShiftDto
        {
            Id = shift.Id,
            Name = shift.Name,
            Description = shift.Description,
            StartTime = shift.StartTime,
            EndTime = shift.EndTime,
            MaxVolunteers = shift.MaxVolunteers,
            CurrentVolunteers = shift.Registrations.Count,
            IsLocked = shift.IsLocked,
            EventId = shift.EventId,
            EventTitle = shift.Event.Title,
            CreatedAt = shift.CreatedAt
        };
    }

    public async Task<ShiftDto> CreateAsync(ShiftCreateDto dto)
    {
        var shift = new Shift
        {
            Name = dto.Name,
            Description = dto.Description,
            StartTime = dto.StartTime,
            EndTime = dto.EndTime,
            MaxVolunteers = dto.MaxVolunteers,
            EventId = dto.EventId
        };

        _context.Shifts.Add(shift);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(shift.Id))!;
    }

    public async Task<bool> UpdateAsync(int id, ShiftCreateDto dto)
    {
        var shift = await _context.Shifts.FindAsync(id);
        if (shift == null) return false;
        if (shift.IsLocked) return false;

        shift.Name = dto.Name;
        shift.Description = dto.Description;
        shift.StartTime = dto.StartTime;
        shift.EndTime = dto.EndTime;
        shift.MaxVolunteers = dto.MaxVolunteers;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var shift = await _context.Shifts.FindAsync(id);
        if (shift == null) return false;

        shift.IsDeleted = true;
        await _context.SaveChangesAsync();
        return true;
    }
}
