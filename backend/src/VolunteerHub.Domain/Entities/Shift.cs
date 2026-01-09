using VolunteerHub.Domain.Enums;

namespace VolunteerHub.Domain.Entities;

/// <summary>
/// Shift entity - represents time slots within events
/// </summary>
public class Shift : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public int MaxVolunteers { get; set; }
    public int CurrentVolunteers { get; set; } = 0;
    public bool IsLocked { get; set; } = false; // When admin finalizes, no more changes allowed
    
    // Foreign keys
    public int EventId { get; set; }
    public Event Event { get; set; } = null!;
    
    // Navigation properties
    public virtual ICollection<ShiftRegistration> Registrations { get; set; } = new List<ShiftRegistration>();
}
