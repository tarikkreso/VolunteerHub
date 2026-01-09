namespace VolunteerHub.Domain.Entities;

public class EventRegistration : BaseEntity
{
    public int EventId { get; set; }
    public Event Event { get; set; } = null!;
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;
    public DateTime? CancelledAt { get; set; }
    public string Status { get; set; } = "Registered";
    public string? Notes { get; set; }
}
