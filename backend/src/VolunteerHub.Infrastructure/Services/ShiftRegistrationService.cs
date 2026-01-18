using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class ShiftRegistrationService : IShiftRegistrationService
{
    private readonly ApplicationDbContext _context;
    private readonly IRabbitMQProducerService _rabbitMQProducer;

    public ShiftRegistrationService(ApplicationDbContext context, IRabbitMQProducerService rabbitMQProducer)
    {
        _context = context;
        _rabbitMQProducer = rabbitMQProducer;
    }

    public async Task<ShiftRegistrationDto> RegisterAsync(int shiftId, int userId)
    {
        var shift = await _context.Shifts.Include(s => s.Event).FirstOrDefaultAsync(s => s.Id == shiftId);
        if (shift == null)
            throw new KeyNotFoundException("Smjena nije pronađena.");

        if (shift.IsLocked)
            throw new InvalidOperationException("Smjena je zaključana i ne prima nove registracije.");

        var existing = await _context.ShiftRegistrations
            .FirstOrDefaultAsync(sr => sr.ShiftId == shiftId && sr.UserId == userId);
        if (existing != null)
            throw new InvalidOperationException("Već ste registrirani za ovu smjenu.");

        if (shift.CurrentVolunteers >= shift.MaxVolunteers)
            throw new InvalidOperationException("Smjena je popunjena.");

        // Check for overlapping shift registrations
        var overlapping = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Where(sr => sr.UserId == userId &&
                         sr.Status != ShiftStatus.Rejected &&
                         sr.Shift.StartTime < shift.EndTime &&
                         sr.Shift.EndTime > shift.StartTime)
            .AnyAsync();
        if (overlapping)
            throw new InvalidOperationException("Imate drugu smjenu koja se vremenski preklapa s ovom.");

        var registration = new ShiftRegistration
        {
            ShiftId = shiftId,
            UserId = userId,
            Status = ShiftStatus.Pending
        };

        _context.ShiftRegistrations.Add(registration);
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = shift.EventId,
            ShiftId = shift.Id,
            ActionType = "ShiftRegistration",
            Description = $"Korisnik se prijavio na smjenu {shift.Name}.",
            OccurredAt = DateTime.UtcNow
        });
        shift.CurrentVolunteers++;
        await _context.SaveChangesAsync();

        // Send notification via RabbitMQ
        var user = await _context.Volunteers.FindAsync(userId);
        if (user != null)
        {
            await _rabbitMQProducer.PublishEmailNotificationAsync(
                user.Email,
                "Registracija na smjenu - VolunteerHub",
                $"<h2>Uspješna registracija</h2><p>Uspješno ste se registrirali za smjenu <strong>{shift.Name}</strong> na događaju <strong>{shift.Event.Title}</strong>.</p><p>Početak: {shift.StartTime:dd.MM.yyyy HH:mm}</p>");
        }

        return await MapToDto(registration.Id);
    }

    public async Task<ShiftRegistrationDto> CheckInAsync(int shiftId, int userId)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .FirstOrDefaultAsync(sr => sr.ShiftId == shiftId && sr.UserId == userId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronađena.");

        if (registration.Shift.IsLocked)
            throw new InvalidOperationException("Smjena je zaključana.");

        if (registration.CheckInTime.HasValue)
            throw new InvalidOperationException("Već ste se prijavili.");

        // Validate check-in time: not earlier than 15 minutes before shift start
        var now = DateTime.UtcNow;
        if (now < registration.Shift.StartTime.AddMinutes(-15))
            throw new InvalidOperationException($"Check-in nije moguć prije početka smjene. Najraniji check-in: {registration.Shift.StartTime.AddMinutes(-15):dd.MM.yyyy HH:mm}");

        registration.CheckInTime = now;
        registration.Status = ShiftStatus.Pending;
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "CheckIn",
            Description = "Korisnik je izvršio check-in na smjenu.",
            OccurredAt = now
        });
        await _context.SaveChangesAsync();

        return await MapToDto(registration.Id);
    }

    public async Task<ShiftRegistrationDto> CheckOutAsync(int shiftId, int userId)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .FirstOrDefaultAsync(sr => sr.ShiftId == shiftId && sr.UserId == userId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronađena.");

        if (!registration.CheckInTime.HasValue)
            throw new InvalidOperationException("Morate se prvo prijaviti prije odjave.");

        if (registration.CheckOutTime.HasValue)
            throw new InvalidOperationException("Već ste se odjavili.");

        registration.CheckOutTime = DateTime.UtcNow;
        registration.HoursWorked = (registration.CheckOutTime.Value - registration.CheckInTime.Value).TotalHours;

        // Pattern detection for suspicious hours (bidirectional: too long or impossibly short)
        var shiftDuration = (registration.Shift.EndTime - registration.Shift.StartTime).TotalHours;
        if (registration.HoursWorked > shiftDuration + 1 || registration.HoursWorked < shiftDuration * 0.25)
        {
            registration.IsSuspicious = true;
            registration.AdminNotes = $"Sumnjivi sati: prijavljeno {registration.HoursWorked:F1}h, trajanje smjene {shiftDuration:F1}h";
        }

        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "CheckOut",
            Description = "Korisnik je izvršio check-out sa smjene.",
            OccurredAt = registration.CheckOutTime.Value
        });

        await _context.SaveChangesAsync();
        return await MapToDto(registration.Id);
    }

    public async Task<List<ShiftRegistrationDto>> GetByShiftAsync(int shiftId)
    {
        return await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
            .Where(sr => sr.ShiftId == shiftId)
            .Select(sr => new ShiftRegistrationDto
            {
                Id = sr.Id,
                UserId = sr.UserId,
                UserName = sr.User.FirstName + " " + sr.User.LastName,
                ShiftId = sr.ShiftId,
                ShiftName = sr.Shift.Name,
                Status = sr.Status.ToString(),
                CheckInTime = sr.CheckInTime,
                CheckOutTime = sr.CheckOutTime,
                HoursWorked = sr.HoursWorked,
                IsSuspicious = sr.IsSuspicious,
                AdminNotes = sr.AdminNotes,
                CreatedAt = sr.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<List<ShiftRegistrationDto>> GetByUserAsync(int userId)
    {
        return await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
                .ThenInclude(s => s.Event)
            .Where(sr => sr.UserId == userId)
            .OrderByDescending(sr => sr.Shift.StartTime)
            .Select(sr => new ShiftRegistrationDto
            {
                Id = sr.Id,
                UserId = sr.UserId,
                UserName = sr.User.FirstName + " " + sr.User.LastName,
                ShiftId = sr.ShiftId,
                ShiftName = sr.Shift.Name,
                EventTitle = sr.Shift.Event.Title,
                ShiftStartTime = sr.Shift.StartTime,
                ShiftEndTime = sr.Shift.EndTime,
                Status = sr.Status.ToString(),
                CheckInTime = sr.CheckInTime,
                CheckOutTime = sr.CheckOutTime,
                HoursWorked = sr.HoursWorked,
                IsSuspicious = sr.IsSuspicious,
                AdminNotes = sr.AdminNotes,
                CreatedAt = sr.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<ShiftRegistrationDto> ApproveAsync(int registrationId, double? approvedHours, string? adminNotes)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Include(sr => sr.User)
            .FirstOrDefaultAsync(sr => sr.Id == registrationId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronađena.");

        if (registration.Shift.IsLocked)
            throw new InvalidOperationException("Smjena je zaključana, nije moguće mijenjati status.");

        var shiftDuration = (registration.Shift.EndTime - registration.Shift.StartTime).TotalHours;
        var maxAllowedHours = shiftDuration + 0.5;
        var hours = approvedHours ?? registration.HoursWorked ?? 0;
        if (hours > maxAllowedHours)
            throw new InvalidOperationException($"Odobreni sati ({hours:F1}h) premašuju maksimalno dozvoljeno ({maxAllowedHours:F1}h za ovu smjenu).");

        registration.Status = ShiftStatus.Approved;
        registration.HoursWorked = hours;
        registration.AdminNotes = adminNotes;
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = registration.UserId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "HoursApproved",
            Description = $"Administrator je odobrio {hours:F1} sati za smjenu.",
            OccurredAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        // Update leaderboard
        await UpdateLeaderboardAsync(registration.UserId, hours);

        // Send notification
        await _rabbitMQProducer.PublishEmailNotificationAsync(
            registration.User.Email,
            "Sati odobreni - VolunteerHub",
            $"<h2>Sati odobreni</h2><p>Vaši sati za smjenu <strong>{registration.Shift.Name}</strong> su odobreni.</p><p>Odobreno sati: {hours:F1}</p>");

        return await MapToDto(registrationId);
    }

    public async Task<ShiftRegistrationDto> RejectAsync(int registrationId, string? adminNotes)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Include(sr => sr.User)
            .FirstOrDefaultAsync(sr => sr.Id == registrationId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronađena.");

        if (registration.Shift.IsLocked)
            throw new InvalidOperationException("Smjena je zaključana, nije moguće mijenjati status.");

        registration.Status = ShiftStatus.Rejected;
        registration.AdminNotes = adminNotes;
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = registration.UserId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "HoursRejected",
            Description = "Administrator je odbio prijavljene sate za smjenu.",
            OccurredAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        await _rabbitMQProducer.PublishEmailNotificationAsync(
            registration.User.Email,
            "Sati odbijeni - VolunteerHub",
            $"<h2>Sati odbijeni</h2><p>Vaši sati za smjenu <strong>{registration.Shift.Name}</strong> su odbijeni.</p><p>Napomena: {adminNotes ?? "Nema napomene"}</p>");

        return await MapToDto(registrationId);
    }

    public async Task<bool> FinalApprovalAsync(int shiftId)
    {
        var shift = await _context.Shifts
            .Include(s => s.Registrations)
            .FirstOrDefaultAsync(s => s.Id == shiftId);

        if (shift == null)
            throw new KeyNotFoundException("Smjena nije pronađena.");

        if (shift.IsLocked)
            throw new InvalidOperationException("Smjena je već zaključana.");

        // Block final approval if there are unconfirmed (Pending) registrations with hours
        var pendingWithHours = shift.Registrations
            .Where(r => r.Status == ShiftStatus.Pending && r.HoursWorked.HasValue)
            .ToList();
        if (pendingWithHours.Any())
            throw new InvalidOperationException($"Nije moguće finalno odobriti smjenu. Postoji {pendingWithHours.Count} registracija sa nepotvrđenim satima. Prvo odobrite ili odbijte sve sate.");

        shift.IsLocked = true;

        // Mark all approved registrations as completed
        foreach (var reg in shift.Registrations.Where(r => r.Status == ShiftStatus.Approved))
        {
            reg.Status = ShiftStatus.Completed;
        }

        await _context.SaveChangesAsync();

        // Recalculate leaderboard ranks
        await RecalculateRanksAsync();

        return true;
    }

    public async Task<List<ShiftRegistrationDto>> ApproveAllAsync(int shiftId, string? adminNotes)
    {
        var registrations = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Include(sr => sr.User)
            .Where(sr => sr.ShiftId == shiftId && sr.Status == ShiftStatus.Pending && sr.HoursWorked.HasValue)
            .ToListAsync();

        var results = new List<ShiftRegistrationDto>();
        foreach (var reg in registrations)
        {
            reg.Status = ShiftStatus.Approved;
            reg.AdminNotes = adminNotes ?? "Grupno odobrenje";
            await UpdateLeaderboardAsync(reg.UserId, reg.HoursWorked ?? 0);
            results.Add(await MapToDto(reg.Id));
        }

        await _context.SaveChangesAsync();
        return results;
    }

    private async Task UpdateLeaderboardAsync(int userId, double hours)
    {
        var entry = await _context.LeaderboardEntries.FirstOrDefaultAsync(l => l.UserId == userId);
        if (entry == null)
        {
            entry = new LeaderboardEntry
            {
                UserId = userId,
                TotalHours = hours,
                TotalEvents = 1,
                TotalShifts = 1,
                Points = (int)(hours * 10)
            };
            _context.LeaderboardEntries.Add(entry);
        }
        else
        {
            entry.TotalHours += hours;
            entry.TotalShifts++;
            entry.Points += (int)(hours * 10);
            entry.MonthlyHours += hours;
            entry.YearlyHours += hours;
            entry.LastUpdated = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
    }

    private async Task RecalculateRanksAsync()
    {
        var entries = await _context.LeaderboardEntries
            .OrderByDescending(e => e.TotalHours)
            .ToListAsync();

        for (int i = 0; i < entries.Count; i++)
        {
            entries[i].Rank = i + 1;
        }

        await _context.SaveChangesAsync();
    }

    private async Task<ShiftRegistrationDto> MapToDto(int registrationId)
    {
        return await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
                .ThenInclude(s => s.Event)
            .Where(sr => sr.Id == registrationId)
            .Select(sr => new ShiftRegistrationDto
            {
                Id = sr.Id,
                UserId = sr.UserId,
                UserName = sr.User.FirstName + " " + sr.User.LastName,
                ShiftId = sr.ShiftId,
                ShiftName = sr.Shift.Name,
                EventTitle = sr.Shift.Event.Title,
                ShiftStartTime = sr.Shift.StartTime,
                ShiftEndTime = sr.Shift.EndTime,
                Status = sr.Status.ToString(),
                CheckInTime = sr.CheckInTime,
                CheckOutTime = sr.CheckOutTime,
                HoursWorked = sr.HoursWorked,
                IsSuspicious = sr.IsSuspicious,
                AdminNotes = sr.AdminNotes,
                CreatedAt = sr.CreatedAt
            })
            .FirstAsync();
    }
}
