using VolunteerHub.Domain.Enums;

namespace VolunteerHub.Domain.Entities;

/// <summary>
/// Notification entity - user notifications
/// </summary>
public class Notification : BaseEntity
{
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public NotificationType Type { get; set; } = NotificationType.General;
    public bool IsRead { get; set; } = false;
    public DateTime? ReadAt { get; set; }
    public string? ActionUrl { get; set; } // Deep link for navigation
    
    // Foreign keys
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    
    // Optional references
    public int? EventId { get; set; }
    public int? ShiftId { get; set; }
    public int? CampaignId { get; set; }
}
