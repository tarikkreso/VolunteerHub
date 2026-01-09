using VolunteerHub.Domain.Enums;

namespace VolunteerHub.Domain.Entities;

/// <summary>
/// Event entity - represents volunteer events/activities
/// </summary>
public class Event : BaseEntity
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public string Location { get; set; } = string.Empty;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? Requirements { get; set; }
    public int MaxVolunteers { get; set; }
    public EventStatus Status { get; set; } = EventStatus.Draft;
    public bool IsFeatured { get; set; }

    public int CategoryId { get; set; }
    public EventCategory Category { get; set; } = null!;

    public int? CityId { get; set; }
    public City? City { get; set; }

    public int? OrganizationId { get; set; }
    public Organization? Organization { get; set; }

    public int CreatedByUserId { get; set; }
    public User CreatedByUser { get; set; } = null!;

    public virtual ICollection<Shift> Shifts { get; set; } = new List<Shift>();
    public virtual ICollection<EventRegistration> EventRegistrations { get; set; } = new List<EventRegistration>();
    public virtual ICollection<EventRecommendation> Recommendations { get; set; } = new List<EventRecommendation>();
}
