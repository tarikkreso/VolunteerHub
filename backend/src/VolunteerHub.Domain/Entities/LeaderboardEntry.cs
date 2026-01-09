namespace VolunteerHub.Domain.Entities;

/// <summary>
/// LeaderboardEntry entity - volunteer rankings based on hours
/// </summary>
public class LeaderboardEntry : BaseEntity
{
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    
    public double TotalHours { get; set; } = 0;
    public int TotalEvents { get; set; } = 0;
    public int TotalShifts { get; set; } = 0;
    public int Rank { get; set; } = 0;
    public int Points { get; set; } = 0; // Gamification points
    public DateTime LastUpdated { get; set; } = DateTime.UtcNow;
    
    // Monthly/yearly stats
    public double MonthlyHours { get; set; } = 0;
    public double YearlyHours { get; set; } = 0;
}
