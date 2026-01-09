namespace VolunteerHub.Domain.Entities;

/// <summary>
/// EventRecommendation entity - stores ML recommendation scores for content-based filtering
/// </summary>
public class EventRecommendation : BaseEntity
{
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    
    public int EventId { get; set; }
    public Event Event { get; set; } = null!;
    
    public double Score { get; set; } // Recommendation score (0-1)
    public string? ReasonTags { get; set; } // Why this was recommended (skills, interests, location)
    public DateTime CalculatedAt { get; set; } = DateTime.UtcNow;
    public bool IsViewed { get; set; } = false;
    public bool IsClicked { get; set; } = false;
}
