namespace VolunteerHub.Domain.Entities;

/// <summary>
/// UserSkill entity - Many-to-Many with proficiency level (NOT a simple M2M)
/// </summary>
public class UserSkill : BaseEntity
{
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    
    public int SkillId { get; set; }
    public Skill Skill { get; set; } = null!;
    
    public int ProficiencyLevel { get; set; } = 1; // 1-5 proficiency level
    public int YearsExperience { get; set; } = 0;
    public bool IsVerified { get; set; } = false;
}
