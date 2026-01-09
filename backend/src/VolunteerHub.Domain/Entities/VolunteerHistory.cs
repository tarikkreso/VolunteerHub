namespace VolunteerHub.Domain.Entities;

public class VolunteerHistory : BaseEntity
{
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    public int? EventId { get; set; }
    public Event? Event { get; set; }
    public int? ShiftId { get; set; }
    public Shift? Shift { get; set; }
    public int? CampaignId { get; set; }
    public Campaign? Campaign { get; set; }
    public string ActionType { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? Metadata { get; set; }
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
}
