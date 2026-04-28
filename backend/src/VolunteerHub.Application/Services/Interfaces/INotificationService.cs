using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface INotificationService
{
    Task<List<NotificationDto>> GetByUserAsync(int userId);
    Task<bool> MarkAsReadAsync(int notificationId, int userId);
    Task<bool> MarkAllAsReadAsync(int userId);
    Task CreateAsync(int userId, string title, string message, string type, string? actionUrl = null, int? eventId = null, int? shiftId = null);
}
