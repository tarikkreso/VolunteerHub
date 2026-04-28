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
            throw new KeyNotFoundException("Smjena nije pronadjena.");

        if (shift.IsLocked)
            throw new InvalidOperationException("Smjena je zakljucana i ne prima nove registracije.");

        var existing = await _context.ShiftRegistrations
            .FirstOrDefaultAsync(sr => sr.ShiftId == shiftId && sr.UserId == userId);
        if (existing != null)
        {
            if (existing.Status == ShiftStatus.Cancelled)
            {
                existing.Status = ShiftStatus.Pending;
                existing.CheckInTime = null;
                existing.CheckOutTime = null;
                existing.HoursWorked = null;
                existing.IsSuspicious = false;
                existing.IsApproved = false;
                existing.AdminNotes = null;
                shift.CurrentVolunteers++;
                await _context.SaveChangesAsync();
                return await MapToDto(existing.Id);
            }

            throw new InvalidOperationException("Vec ste registrovani za ovu smjenu.");
        }

        if (shift.CurrentVolunteers >= shift.MaxVolunteers)
            throw new InvalidOperationException("Smjena je popunjena.");

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

        var user = await _context.Volunteers.FindAsync(userId);
        if (user != null)
        {
            await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
            {
                UserId = userId,
                Email = user.Email,
                Title = "Registracija na smjenu",
                Message = $"Uspješno ste se registrovali za smjenu {shift.Name} na događaju {shift.Event.Title}.",
                Type = NotificationType.ShiftRegistration.ToString(),
                ShiftId = shift.Id,
                EventId = shift.EventId,
                ActionUrl = $"/shifts/{shift.Id}",
                PersistInAppNotification = true,
                SendEmail = true,
                EmailSubject = "Registracija na smjenu - VolunteerHub",
                EmailBody = $"<h2>Uspjesna registracija</h2><p>Uspjesno ste se registrovali za smjenu <strong>{shift.Name}</strong> na dogadjaju <strong>{shift.Event.Title}</strong>.</p><p>Pocetak: {shift.StartTime:dd.MM.yyyy HH:mm}</p>"
            });
        }

        return await MapToDto(registration.Id);
    }

    public async Task<ShiftRegistrationDto> CheckInAsync(int shiftId, int userId)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
            .FirstOrDefaultAsync(sr => sr.ShiftId == shiftId && sr.UserId == userId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronadjena.");

        if (registration.Shift.IsLocked)
            throw new InvalidOperationException("Smjena je zakljucana.");

        if (registration.Status != ShiftStatus.Registered)
            throw new InvalidOperationException("Admin mora odobriti prijavu prije check-in-a.");

        if (registration.CheckInTime.HasValue)
            throw new InvalidOperationException("Vec ste se prijavili.");

        var now = DateTime.UtcNow;
        var activeRegistration = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .FirstOrDefaultAsync(sr => sr.UserId == userId &&
                                       sr.Id != registration.Id &&
                                       sr.CheckInTime.HasValue &&
                                       !sr.CheckOutTime.HasValue &&
                                       !sr.Shift.IsLocked);
        if (activeRegistration != null)
            throw new InvalidOperationException("Vec imate aktivnu smjenu. Prvo uradite check-out.");

        registration.CheckInTime = now;
        registration.Status = ShiftStatus.Registered;
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "CheckIn",
            Description = "Korisnik je izvrsio check-in na smjenu.",
            OccurredAt = now
        });
        await _context.SaveChangesAsync();

        if (registration.User != null)
        {
            await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
            {
                UserId = userId,
                Email = registration.User.Email,
                Title = "Check-in evidentiran",
                Message = $"Evidentiran je vaš check-in za smjenu {registration.Shift.Name}.",
                Type = NotificationType.ShiftCheckIn.ToString(),
                ShiftId = registration.ShiftId,
                EventId = registration.Shift.EventId,
                ActionUrl = $"/shifts/{registration.ShiftId}",
                PersistInAppNotification = true,
                SendEmail = true,
                EmailSubject = "Check-in evidentiran - VolunteerHub",
                EmailBody = $"<h2>Check-in evidentiran</h2><p>Evidentiran je vaš check-in za smjenu <strong>{registration.Shift.Name}</strong>.</p>"
            });
        }

        return await MapToDto(registration.Id);
    }

    public async Task<ShiftRegistrationDto> CheckOutAsync(int shiftId, int userId)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
            .FirstOrDefaultAsync(sr => sr.ShiftId == shiftId && sr.UserId == userId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronadjena.");

        if (!registration.CheckInTime.HasValue)
            throw new InvalidOperationException("Morate se prvo prijaviti prije odjave.");

        if (registration.CheckOutTime.HasValue)
            throw new InvalidOperationException("Vec ste se odjavili.");

        registration.CheckOutTime = DateTime.UtcNow;
        registration.HoursWorked = Math.Round((registration.CheckOutTime.Value - registration.CheckInTime.Value).TotalHours, 2);
        registration.Status = ShiftStatus.Pending;
        registration.IsApproved = false;
        ApplyAnomalyDetection(registration);

        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "CheckOut",
            Description = "Korisnik je izvrsio check-out sa smjene.",
            OccurredAt = registration.CheckOutTime.Value
        });

        await _context.SaveChangesAsync();

        if (registration.User != null)
        {
            await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
            {
                UserId = userId,
                Email = registration.User.Email,
                Title = "Check-out evidentiran",
                Message = $"Evidentiran je vaš check-out za smjenu {registration.Shift.Name}.",
                Type = NotificationType.ShiftCheckOut.ToString(),
                ShiftId = registration.ShiftId,
                EventId = registration.Shift.EventId,
                ActionUrl = $"/shifts/{registration.ShiftId}",
                PersistInAppNotification = true,
                SendEmail = true,
                EmailSubject = "Check-out evidentiran - VolunteerHub",
                EmailBody = $"<h2>Check-out evidentiran</h2><p>Evidentiran je vaš check-out za smjenu <strong>{registration.Shift.Name}</strong>.</p><p>Ukupno sati: {registration.HoursWorked:F2}</p>"
            });
        }

        return await MapToDto(registration.Id);
    }

    public async Task<ShiftRegistrationDto> CancelAsync(int registrationId, int userId, string reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new InvalidOperationException("Razlog otkazivanja je obavezan.");

        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
            .FirstOrDefaultAsync(sr => sr.Id == registrationId && sr.UserId == userId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronadjena.");

        if (registration.Shift.IsLocked)
            throw new InvalidOperationException("Smjena je zakljucana.");

        if (registration.CheckInTime.HasValue)
            throw new InvalidOperationException("Nije moguce otkazati smjenu nakon check-in-a.");

        if (DateTime.UtcNow > registration.Shift.StartTime.AddDays(-1))
            throw new InvalidOperationException("Smjenu je moguce otkazati najkasnije jedan dan prije pocetka.");

        if (registration.Status != ShiftStatus.Pending && registration.Status != ShiftStatus.Registered)
            throw new InvalidOperationException("Ovu registraciju nije moguce otkazati.");

        registration.Status = ShiftStatus.Cancelled;
        registration.AdminNotes = $"Otkazano od strane volontera. Razlog: {reason.Trim()}";
        if (registration.Shift.CurrentVolunteers > 0)
            registration.Shift.CurrentVolunteers--;

        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "ShiftRegistrationCancelled",
            Description = $"Korisnik je otkazao prijavu na smjenu. Razlog: {reason.Trim()}",
            OccurredAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();

        if (registration.User != null)
        {
            await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
            {
                UserId = userId,
                Email = registration.User.Email,
                Title = "Smjena otkazana",
                Message = $"Otkazali ste prijavu na smjenu {registration.Shift.Name}.",
                Type = NotificationType.ShiftRegistration.ToString(),
                ShiftId = registration.ShiftId,
                EventId = registration.Shift.EventId,
                ActionUrl = $"/shifts/{registration.ShiftId}",
                PersistInAppNotification = true,
                SendEmail = true,
                EmailSubject = "Smjena otkazana - VolunteerHub",
                EmailBody = $"<h2>Smjena otkazana</h2><p>Otkazali ste prijavu na smjenu <strong>{registration.Shift.Name}</strong>.</p><p>Razlog: {System.Net.WebUtility.HtmlEncode(reason.Trim())}</p>"
            });
        }

        return await MapToDto(registration.Id);
    }

    public async Task<List<ShiftRegistrationDto>> GetByShiftAsync(int shiftId)
    {
        var registrations = await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
            .Where(sr => sr.ShiftId == shiftId)
            .OrderBy(sr => sr.User.LastName)
            .ThenBy(sr => sr.User.FirstName)
            .Take(100)
            .ToListAsync();

        AutoCloseExpiredActiveRegistrations(registrations);

        foreach (var registration in registrations)
        {
            ApplyAnomalyDetection(registration);
        }

        await _context.SaveChangesAsync();

        return registrations.Select(MapRegistration).ToList();
    }

    public async Task<PagedResultDto<ShiftRegistrationDto>> GetByUserAsync(int userId, SearchRequestDto request)
    {
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 100);

        var query = _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
                .ThenInclude(s => s.Event)
            .Where(sr => sr.UserId == userId)
            .OrderByDescending(sr => sr.Shift.StartTime);

        var totalCount = await query.CountAsync();
        var registrations = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        AutoCloseExpiredActiveRegistrations(registrations);

        foreach (var registration in registrations)
        {
            ApplyAnomalyDetection(registration);
        }

        await _context.SaveChangesAsync();

        return new PagedResultDto<ShiftRegistrationDto>
        {
            Items = registrations.Select(MapRegistration).ToList(),
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<ShiftRegistrationDto> ApproveAsync(int registrationId, double? approvedHours, string? adminNotes, int adminId)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Include(sr => sr.User)
            .FirstOrDefaultAsync(sr => sr.Id == registrationId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronadjena.");

        if (registration.Shift.IsLocked)
            throw new InvalidOperationException("Smjena je zakljucana, nije moguce mijenjati status.");

        ApplyAnomalyDetection(registration);

        var isParticipationApproval = !registration.CheckInTime.HasValue &&
                                      !registration.CheckOutTime.HasValue &&
                                      !registration.HoursWorked.HasValue &&
                                      (!approvedHours.HasValue || Math.Abs(approvedHours.Value) < 0.001);
        if (isParticipationApproval)
        {
            registration.Status = ShiftStatus.Registered;
            registration.AdminNotes = adminNotes ?? "Prijava odobrena od strane admina.";
            registration.IsApproved = false;
            registration.ApprovedByUserId = adminId;
            registration.ApprovedAt = DateTime.UtcNow;
            registration.RejectedByUserId = null;
            registration.RejectedAt = null;
            _context.VolunteerHistories.Add(new VolunteerHistory
            {
                UserId = registration.UserId,
                EventId = registration.Shift.EventId,
                ShiftId = registration.ShiftId,
                ActionType = "ShiftRegistrationApproved",
                Description = $"Administrator #{adminId} je odobrio prijavu na smjenu.",
                OccurredAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            if (registration.User != null)
            {
                await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
                {
                    UserId = registration.UserId,
                    Email = registration.User.Email,
                    Title = "Prijava na smjenu odobrena",
                    Message = $"Vaša prijava na smjenu {registration.Shift.Name} je odobrena.",
                    Type = NotificationType.ShiftApproved.ToString(),
                    ShiftId = registration.ShiftId,
                    EventId = registration.Shift.EventId,
                    ActionUrl = $"/shifts/{registration.ShiftId}",
                    PersistInAppNotification = true,
                    SendEmail = true,
                    EmailSubject = "Prijava na smjenu odobrena - VolunteerHub",
                    EmailBody = $"<h2>Prijava odobrena</h2><p>Vaša prijava na smjenu <strong>{registration.Shift.Name}</strong> je odobrena.</p>"
                });
            }

            return await MapToDto(registrationId);
        }

        var shiftDuration = (registration.Shift.EndTime - registration.Shift.StartTime).TotalHours;
        var maxAllowedHours = shiftDuration + 0.5;
        var hours = Math.Round(approvedHours ?? registration.HoursWorked ?? 0, 2);

        if (hours < 0)
            throw new InvalidOperationException("Odobreni sati ne mogu biti negativni.");
        if (hours > maxAllowedHours)
            throw new InvalidOperationException($"Odobreni sati ({hours:F1}h) premasuju maksimalno dozvoljeno ({maxAllowedHours:F1}h za ovu smjenu).");

        var approvedHourFlags = GetApprovedHourFlags(registration, hours);
        var requiresReviewNote = registration.IsSuspicious || approvedHourFlags.Count > 0;
        if (approvedHourFlags.Count > 0)
        {
            registration.IsSuspicious = true;
            if (string.IsNullOrWhiteSpace(registration.AdminNotes) ||
                registration.AdminNotes.StartsWith("Sumnjivi sati:", StringComparison.OrdinalIgnoreCase))
            {
                registration.AdminNotes = "Sumnjivi sati: " + string.Join(", ", approvedHourFlags);
            }
        }

        if (requiresReviewNote && string.IsNullOrWhiteSpace(adminNotes))
            throw new InvalidOperationException("Registracija ima sumnjive sate. Unesite admin napomenu prije odobravanja.");

        var previousApprovedHours = registration.IsApproved ? registration.HoursWorked ?? 0 : 0;
        registration.Status = ShiftStatus.Approved;
        registration.HoursWorked = hours;
        registration.AdminNotes = adminNotes;
        registration.IsApproved = true;
        registration.ApprovedByUserId = adminId;
        registration.ApprovedAt = DateTime.UtcNow;
        registration.RejectedByUserId = null;
        registration.RejectedAt = null;

        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = registration.UserId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "HoursApproved",
            Description = $"Administrator #{adminId} je odobrio {hours:F1} sati za smjenu.",
            OccurredAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        await UpdateLeaderboardAsync(registration.UserId, hours - previousApprovedHours);

        await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
        {
            UserId = registration.UserId,
            Email = registration.User.Email,
            Title = "Sati odobreni",
            Message = $"Vaši sati za smjenu {registration.Shift.Name} su odobreni.",
            Type = NotificationType.ShiftApproved.ToString(),
            ShiftId = registration.ShiftId,
            EventId = registration.Shift.EventId,
            ActionUrl = $"/shifts/{registration.ShiftId}",
            PersistInAppNotification = true,
            SendEmail = true,
            EmailSubject = "Sati odobreni - VolunteerHub",
            EmailBody = $"<h2>Sati odobreni</h2><p>Vasi sati za smjenu <strong>{registration.Shift.Name}</strong> su odobreni.</p><p>Odobreno sati: {hours:F1}</p>"
        });

        return await MapToDto(registrationId);
    }

    public async Task<ShiftRegistrationDto> RejectAsync(int registrationId, string? adminNotes, int adminId)
    {
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Include(sr => sr.User)
            .FirstOrDefaultAsync(sr => sr.Id == registrationId);

        if (registration == null)
            throw new KeyNotFoundException("Registracija nije pronadjena.");

        if (registration.Shift.IsLocked)
            throw new InvalidOperationException("Smjena je zakljucana, nije moguce mijenjati status.");

        var approvedHoursToRemove = registration.IsApproved ? registration.HoursWorked ?? 0 : 0;
        registration.Status = ShiftStatus.Rejected;
        registration.AdminNotes = adminNotes;
        registration.IsApproved = false;
        registration.RejectedByUserId = adminId;
        registration.RejectedAt = DateTime.UtcNow;
        registration.ApprovedByUserId = null;
        registration.ApprovedAt = null;

        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = registration.UserId,
            EventId = registration.Shift.EventId,
            ShiftId = registration.ShiftId,
            ActionType = "HoursRejected",
            Description = $"Administrator #{adminId} je odbio prijavljene sate za smjenu.",
            OccurredAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        if (approvedHoursToRemove > 0)
        {
            await UpdateLeaderboardAsync(registration.UserId, -approvedHoursToRemove);
        }

        await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
        {
            UserId = registration.UserId,
            Email = registration.User.Email,
            Title = "Sati odbijeni",
            Message = $"Vaši sati za smjenu {registration.Shift.Name} su odbijeni.",
            Type = NotificationType.ShiftRejected.ToString(),
            ShiftId = registration.ShiftId,
            EventId = registration.Shift.EventId,
            ActionUrl = $"/shifts/{registration.ShiftId}",
            PersistInAppNotification = true,
            SendEmail = true,
            EmailSubject = "Sati odbijeni - VolunteerHub",
            EmailBody = $"<h2>Sati odbijeni</h2><p>Vasi sati za smjenu <strong>{registration.Shift.Name}</strong> su odbijeni.</p><p>Napomena: {adminNotes ?? "Nema napomene"}</p>"
        });

        return await MapToDto(registrationId);
    }

    public async Task<bool> FinalApprovalAsync(int shiftId, int adminId)
    {
        var shift = await _context.Shifts
            .Include(s => s.Registrations)
            .FirstOrDefaultAsync(s => s.Id == shiftId);

        if (shift == null)
            throw new KeyNotFoundException("Smjena nije pronadjena.");

        if (shift.IsLocked)
            throw new InvalidOperationException("Smjena je vec zakljucana.");

        foreach (var registration in shift.Registrations)
        {
            registration.Shift = shift;
            ApplyAnomalyDetection(registration);
        }

        AutoCloseExpiredActiveRegistrations(shift.Registrations);

        var pendingWithHours = shift.Registrations
            .Where(r => r.Status == ShiftStatus.Pending && r.HoursWorked.HasValue)
            .ToList();
        if (pendingWithHours.Any())
            throw new InvalidOperationException($"Nije moguce finalno odobriti smjenu. Postoji {pendingWithHours.Count} registracija sa nepotvrdjenim satima. Prvo odobrite ili odbijte sve sate.");

        var unresolvedSuspicious = shift.Registrations
            .Where(r => r.IsSuspicious && r.Status != ShiftStatus.Approved && r.Status != ShiftStatus.Rejected && r.Status != ShiftStatus.Completed)
            .ToList();
        if (unresolvedSuspicious.Any())
            throw new InvalidOperationException($"Nije moguce finalno odobriti smjenu. Postoji {unresolvedSuspicious.Count} sumnjivih registracija koje nisu odobrene ili odbijene.");

        shift.IsLocked = true;

        foreach (var reg in shift.Registrations.Where(r => r.Status == ShiftStatus.Approved))
        {
            reg.Status = ShiftStatus.Completed;
            reg.FinalApprovedByUserId = adminId;
            reg.FinalApprovedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        await RecalculateRanksAsync();

        return true;
    }

    public async Task<List<ShiftRegistrationDto>> ApproveAllAsync(int shiftId, string? adminNotes, int adminId)
    {
        var registrations = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Include(sr => sr.User)
            .Where(sr => sr.ShiftId == shiftId && sr.Status == ShiftStatus.Pending && sr.HoursWorked.HasValue)
            .ToListAsync();

        AutoCloseExpiredActiveRegistrations(registrations);

        var results = new List<ShiftRegistrationDto>();
        foreach (var reg in registrations)
        {
            ApplyAnomalyDetection(reg);
            if (reg.IsSuspicious)
            {
                continue;
            }

            var shiftDuration = (reg.Shift.EndTime - reg.Shift.StartTime).TotalHours;
            var maxAllowedHours = shiftDuration + 0.5;
            if ((reg.HoursWorked ?? 0) > maxAllowedHours)
            {
                continue;
            }

            var previousApprovedHours = reg.IsApproved ? reg.HoursWorked ?? 0 : 0;
            reg.Status = ShiftStatus.Approved;
            reg.AdminNotes = adminNotes ?? "Grupno odobrenje";
            reg.IsApproved = true;
            reg.ApprovedByUserId = adminId;
            reg.ApprovedAt = DateTime.UtcNow;
            reg.RejectedByUserId = null;
            reg.RejectedAt = null;
            await UpdateLeaderboardAsync(reg.UserId, (reg.HoursWorked ?? 0) - previousApprovedHours);
            results.Add(await MapToDto(reg.Id));
        }

        await _context.SaveChangesAsync();
        return results;
    }

    private async Task UpdateLeaderboardAsync(int userId, double hours)
    {
        if (Math.Abs(hours) < 0.001)
            return;

        var entry = await _context.LeaderboardEntries.FirstOrDefaultAsync(l => l.UserId == userId);
        if (entry == null)
        {
            entry = new LeaderboardEntry
            {
                UserId = userId,
                TotalHours = Math.Max(0, hours),
                TotalEvents = hours > 0 ? 1 : 0,
                TotalShifts = hours > 0 ? 1 : 0,
                Points = Math.Max(0, (int)(hours * 10)),
                MonthlyHours = Math.Max(0, hours),
                YearlyHours = Math.Max(0, hours),
                LastUpdated = DateTime.UtcNow
            };
            _context.LeaderboardEntries.Add(entry);
        }
        else
        {
            entry.TotalHours = Math.Max(0, entry.TotalHours + hours);
            if (hours > 0)
                entry.TotalShifts++;
            else if (hours < 0 && entry.TotalShifts > 0)
                entry.TotalShifts--;
            entry.Points = Math.Max(0, entry.Points + (int)(hours * 10));
            entry.MonthlyHours = Math.Max(0, entry.MonthlyHours + hours);
            entry.YearlyHours = Math.Max(0, entry.YearlyHours + hours);
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
        var registration = await _context.ShiftRegistrations
            .Include(sr => sr.User)
            .Include(sr => sr.Shift)
                .ThenInclude(s => s.Event)
            .FirstAsync(sr => sr.Id == registrationId);

        ApplyAnomalyDetection(registration);
        return MapRegistration(registration);
    }

    private static ShiftRegistrationDto MapRegistration(ShiftRegistration registration)
    {
        return new ShiftRegistrationDto
        {
            Id = registration.Id,
            UserId = registration.UserId,
            UserName = registration.User.FirstName + " " + registration.User.LastName,
            ShiftId = registration.ShiftId,
            ShiftName = registration.Shift.Name,
            EventTitle = registration.Shift.Event?.Title ?? string.Empty,
            ShiftStartTime = registration.Shift.StartTime,
            ShiftEndTime = registration.Shift.EndTime,
            Status = registration.Status.ToString(),
            CheckInTime = registration.CheckInTime,
            CheckOutTime = registration.CheckOutTime,
            HoursWorked = registration.HoursWorked,
            IsSuspicious = registration.IsSuspicious,
            AdminNotes = registration.AdminNotes,
            ApprovedByUserId = registration.ApprovedByUserId,
            ApprovedAt = registration.ApprovedAt,
            RejectedByUserId = registration.RejectedByUserId,
            RejectedAt = registration.RejectedAt,
            FinalApprovedByUserId = registration.FinalApprovedByUserId,
            FinalApprovedAt = registration.FinalApprovedAt,
            CreatedAt = registration.CreatedAt
        };
    }

    private static void AutoCloseExpiredActiveRegistrations(IEnumerable<ShiftRegistration> registrations)
    {
        var now = DateTime.UtcNow;
        foreach (var registration in registrations)
        {
            if (!registration.CheckInTime.HasValue || registration.CheckOutTime.HasValue || registration.Shift.IsLocked)
                continue;

            var endOfShiftDay = registration.Shift.EndTime.Date.AddDays(1).AddTicks(-1);
            if (now <= endOfShiftDay)
                continue;

            registration.CheckOutTime = endOfShiftDay;
            registration.HoursWorked = Math.Round((registration.CheckOutTime.Value - registration.CheckInTime.Value).TotalHours, 2);
            registration.Status = ShiftStatus.Pending;
            registration.IsApproved = false;
            registration.IsSuspicious = true;
            registration.AdminNotes = "Sumnjivi sati: sistem je automatski zatvorio smjenu na kraju dana jer korisnik nije uradio check-out.";
        }
    }

    private static void ApplyAnomalyDetection(ShiftRegistration registration)
    {
        var flags = GetAnomalyFlags(registration);
        registration.IsSuspicious = flags.Count > 0;

        if (registration.IsSuspicious)
        {
            var generatedNote = "Sumnjivi sati: " + string.Join(", ", flags);
            if (string.IsNullOrWhiteSpace(registration.AdminNotes) ||
                registration.AdminNotes.StartsWith("Sumnjivi sati:", StringComparison.OrdinalIgnoreCase))
            {
                registration.AdminNotes = generatedNote;
            }
        }
        else if (registration.AdminNotes != null &&
                 registration.AdminNotes.StartsWith("Sumnjivi sati:", StringComparison.OrdinalIgnoreCase))
        {
            registration.AdminNotes = null;
        }
    }

    private static List<string> GetAnomalyFlags(ShiftRegistration registration)
    {
        var flags = new List<string>();
        var shiftDuration = (registration.Shift.EndTime - registration.Shift.StartTime).TotalHours;

        if (registration.CheckInTime.HasValue && registration.CheckInTime.Value < registration.Shift.StartTime.AddMinutes(-15))
            flags.Add("check-in prije dozvoljenog vremena");

        if (registration.CheckOutTime.HasValue && registration.CheckOutTime.Value > registration.Shift.EndTime.AddMinutes(30))
            flags.Add("check-out znatno nakon kraja smjene");

        if (registration.CheckInTime.HasValue && registration.CheckOutTime.HasValue)
        {
            if (registration.CheckOutTime.Value < registration.CheckInTime.Value)
                flags.Add("check-out je prije check-in vremena");

            var actualHours = (registration.CheckOutTime.Value - registration.CheckInTime.Value).TotalHours;
            if (registration.HoursWorked.HasValue && Math.Abs(actualHours - registration.HoursWorked.Value) > 0.25)
                flags.Add("prijavljeni sati se ne poklapaju sa check-in/out vremenom");
        }

        if (registration.HoursWorked.HasValue)
        {
            if (registration.HoursWorked.Value < 0)
                flags.Add("negativan broj sati");
            if (registration.HoursWorked.Value > shiftDuration + 0.5)
                flags.Add($"previse sati ({registration.HoursWorked.Value:F1}h / smjena {shiftDuration:F1}h)");
            if (registration.HoursWorked.Value > 0 && registration.HoursWorked.Value < shiftDuration * 0.25)
                flags.Add($"premalo sati ({registration.HoursWorked.Value:F1}h / smjena {shiftDuration:F1}h)");
        }

        return flags;
    }

    private static List<string> GetApprovedHourFlags(ShiftRegistration registration, double approvedHours)
    {
        var flags = new List<string>();
        var shiftDuration = (registration.Shift.EndTime - registration.Shift.StartTime).TotalHours;

        if (approvedHours > 0 && approvedHours < shiftDuration * 0.25)
            flags.Add($"odobreno premalo sati ({approvedHours:F1}h / smjena {shiftDuration:F1}h)");

        if (registration.CheckInTime.HasValue && registration.CheckOutTime.HasValue)
        {
            var actualHours = (registration.CheckOutTime.Value - registration.CheckInTime.Value).TotalHours;
            if (Math.Abs(actualHours - approvedHours) > 0.25)
                flags.Add("odobreni sati se ne poklapaju sa check-in/out vremenom");
        }

        return flags;
    }
}
