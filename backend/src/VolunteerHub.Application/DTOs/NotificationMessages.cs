namespace VolunteerHub.Application.DTOs;

public class UserNotificationMessage
{
    public int UserId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string? ActionUrl { get; set; }
    public int? EventId { get; set; }
    public int? ShiftId { get; set; }
    public int? CampaignId { get; set; }
    public bool PersistInAppNotification { get; set; } = true;
    public bool SendEmail { get; set; } = true;
    public string? EmailSubject { get; set; }
    public string? EmailBody { get; set; }
    public bool IsEmailHtml { get; set; } = true;
}
