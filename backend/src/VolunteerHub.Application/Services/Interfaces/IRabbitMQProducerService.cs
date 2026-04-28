using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IRabbitMQProducerService
{
    Task PublishEmailNotificationAsync(string to, string subject, string body, bool isHtml = true);
    Task PublishUserNotificationAsync(UserNotificationMessage message);
    Task PublishShiftReminderAsync(int userId, int shiftId, string userEmail, string shiftName, DateTime shiftStartTime);
    Task PublishDonationNotificationAsync(int campaignId, decimal amount, string currency, string? donorName, string? message);
}
