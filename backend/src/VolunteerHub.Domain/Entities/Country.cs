namespace VolunteerHub.Domain.Entities;

/// <summary>
/// Country entity - reference table
/// </summary>
public class Country : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty; // ISO 3166-1 alpha-2
    
    // Navigation properties
    public virtual ICollection<City> Cities { get; set; } = new List<City>();
}
