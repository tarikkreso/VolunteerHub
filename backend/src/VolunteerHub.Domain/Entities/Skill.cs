namespace VolunteerHub.Domain.Entities;

/// <summary>
/// Skill entity - volunteer skills/competencies
/// </summary>
public class Skill : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? IconUrl { get; set; }
    public string? Color { get; set; }

    // Navigation properties
    public virtual ICollection<UserSkill> UserSkills { get; set; } = new List<UserSkill>();
}
