using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class EventRegistrationService : IEventRegistrationService
{
    private readonly ApplicationDbContext _context;
    private readonly IRabbitMQProducerService _rabbitMQProducer;

    public EventRegistrationService(ApplicationDbContext context, IRabbitMQProducerService rabbitMQProducer)
    {
        _context = context;
        _rabbitMQProducer = rabbitMQProducer;
    }

    public async Task<EventRegistrationDto> RegisterAsync(int userId, EventRegistrationCreateDto dto)
    {
        var evt = await _context.Events.FirstOrDefaultAsync(e => e.Id == dto.EventId);
        if (evt == null)
            throw new KeyNotFoundException("Događaj nije pronađen.");

        var exists = await _context.EventRegistrations.AnyAsync(r => r.EventId == dto.EventId && r.UserId == userId);
        if (exists)
            throw new InvalidOperationException("Već ste prijavljeni na ovaj događaj.");

        var registration = new EventRegistration
        {
            EventId = dto.EventId,
            UserId = userId,
            Notes = dto.Notes,
            Status = "Registered",
            RegisteredAt = DateTime.UtcNow
        };

        _context.EventRegistrations.Add(registration);
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = dto.EventId,
            ActionType = "EventRegistration",
            Description = $"Korisnik se prijavio na događaj {evt.Title}.",
            OccurredAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();

        var user = await _context.Volunteers.FindAsync(userId);
        if (user != null)
        {
            await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
            {
                UserId = userId,
                Email = user.Email,
                Title = "Prijava na događaj",
                Message = $"Uspješno ste se prijavili na događaj {evt.Title}.",
                Type = NotificationType.EventRegistration.ToString(),
                EventId = dto.EventId,
                ActionUrl = $"/events/{dto.EventId}",
                PersistInAppNotification = true,
                SendEmail = true,
                EmailSubject = "Prijava na događaj - VolunteerHub",
                EmailBody = $"<h2>Prijava uspješna</h2><p>Uspješno ste se prijavili na događaj <strong>{evt.Title}</strong>.</p>"
            });
        }

        return await MapToDto(registration.Id);
    }

    public async Task<List<EventRegistrationDto>> GetByUserAsync(int userId)
    {
        return await _context.EventRegistrations
            .Include(r => r.Event)
            .Include(r => r.User)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.RegisteredAt)
            .Take(100)
            .Select(r => new EventRegistrationDto
            {
                Id = r.Id,
                EventId = r.EventId,
                EventTitle = r.Event.Title,
                UserId = r.UserId,
                UserName = $"{r.User.FirstName} {r.User.LastName}".Trim(),
                Status = r.Status,
                RegisteredAt = r.RegisteredAt,
                CancelledAt = r.CancelledAt,
                Notes = r.Notes,
                CreatedAt = r.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<List<EventRegistrationDto>> GetByEventAsync(int eventId)
    {
        return await _context.EventRegistrations
            .Include(r => r.Event)
            .Include(r => r.User)
            .Where(r => r.EventId == eventId)
            .OrderByDescending(r => r.RegisteredAt)
            .Take(100)
            .Select(r => new EventRegistrationDto
            {
                Id = r.Id,
                EventId = r.EventId,
                EventTitle = r.Event.Title,
                UserId = r.UserId,
                UserName = $"{r.User.FirstName} {r.User.LastName}".Trim(),
                Status = r.Status,
                RegisteredAt = r.RegisteredAt,
                CancelledAt = r.CancelledAt,
                Notes = r.Notes,
                CreatedAt = r.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<bool> CancelAsync(int registrationId, int userId, string reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new InvalidOperationException("Razlog otkazivanja je obavezan.");

        var registration = await _context.EventRegistrations
            .Include(r => r.Event)
            .FirstOrDefaultAsync(r => r.Id == registrationId && r.UserId == userId);

        if (registration == null)
            return false;

        registration.Status = "Cancelled";
        registration.CancelledAt = DateTime.UtcNow;

        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            EventId = registration.EventId,
            ActionType = "EventRegistrationCancelled",
            Description = $"Korisnik je otkazao prijavu na dogadjaj {registration.Event.Title}. Razlog: {reason.Trim()}",
            OccurredAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();

        var user = await _context.Volunteers.FindAsync(userId);
        if (user != null)
        {
            await _rabbitMQProducer.PublishUserNotificationAsync(new UserNotificationMessage
            {
                UserId = userId,
                Email = user.Email,
                Title = "Prijava na događaj otkazana",
                Message = $"Otkazali ste prijavu na događaj {registration.Event.Title}.",
                Type = NotificationType.EventRegistrationCancelled.ToString(),
                EventId = registration.EventId,
                ActionUrl = $"/events/{registration.EventId}",
                PersistInAppNotification = true,
                SendEmail = true,
                EmailSubject = "Prijava otkazana - VolunteerHub",
                EmailBody = $"<h2>Prijava otkazana</h2><p>Otkazali ste prijavu na dogadjaj <strong>{registration.Event.Title}</strong>.</p><p>Razlog: {System.Net.WebUtility.HtmlEncode(reason.Trim())}</p>"
            });
        }

        return true;
    }

    private async Task<EventRegistrationDto> MapToDto(int id)
    {
        return await _context.EventRegistrations
            .Include(r => r.Event)
            .Include(r => r.User)
            .Where(r => r.Id == id)
            .Select(r => new EventRegistrationDto
            {
                Id = r.Id,
                EventId = r.EventId,
                EventTitle = r.Event.Title,
                UserId = r.UserId,
                UserName = $"{r.User.FirstName} {r.User.LastName}".Trim(),
                Status = r.Status,
                RegisteredAt = r.RegisteredAt,
                CancelledAt = r.CancelledAt,
                Notes = r.Notes,
                CreatedAt = r.CreatedAt
            })
            .FirstAsync();
    }
}
