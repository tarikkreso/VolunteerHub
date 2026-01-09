namespace VolunteerHub.Domain.Entities;

/// <summary>
/// EventCategory entity - reference table for event types
/// </summary>
public class EventCategory : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? IconUrl { get; set; }
    public string? Color { get; set; } // Hex color for UI
    
    // Navigation properties
    public virtual ICollection<Event> Events { get; set; } = new List<Event>();
}
