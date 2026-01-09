namespace VolunteerHub.Domain.Entities;

/// <summary>
/// City entity - reference table
/// </summary>
public class City : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? PostalCode { get; set; }
    
    // Foreign keys
    public int CountryId { get; set; }
    public Country Country { get; set; } = null!;
    
    // Navigation properties
    public virtual ICollection<User> Users { get; set; } = new List<User>();
    public virtual ICollection<Event> Events { get; set; } = new List<Event>();
}
