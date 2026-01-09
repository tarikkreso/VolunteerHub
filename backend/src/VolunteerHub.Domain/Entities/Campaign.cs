namespace VolunteerHub.Domain.Entities;

/// <summary>
/// Campaign entity - represents donation campaigns
/// </summary>
public class Campaign : BaseEntity
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public decimal GoalAmount { get; set; }
    public decimal CurrentAmount { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsFeatured { get; set; }

    public int? OrganizationId { get; set; }
    public Organization? Organization { get; set; }

    public int CreatedByUserId { get; set; }
    public User CreatedByUser { get; set; } = null!;

    public virtual ICollection<Donation> Donations { get; set; } = new List<Donation>();
}
