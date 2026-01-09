using VolunteerHub.Domain.Enums;

namespace VolunteerHub.Domain.Entities;

/// <summary>
/// User profile entity used by the business/domain model.
/// Authentication is handled by the linked ASP.NET Identity user.
/// </summary>
public class User : BaseEntity
{
    public int? IdentityUserId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string PasswordSalt { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string? Bio { get; set; }
    public UserRole Role { get; set; } = UserRole.Volunteer;
    public bool IsActive { get; set; } = true;
    public DateTime? LastLoginAt { get; set; }
    public string? ResetPasswordToken { get; set; }
    public DateTime? ResetPasswordTokenExpiry { get; set; }

    public int? CityId { get; set; }
    public City? City { get; set; }

    public virtual ICollection<UserSkill> UserSkills { get; set; } = new List<UserSkill>();
    public virtual ICollection<ShiftRegistration> ShiftRegistrations { get; set; } = new List<ShiftRegistration>();
    public virtual ICollection<EventRegistration> EventRegistrations { get; set; } = new List<EventRegistration>();
    public virtual ICollection<Donation> Donations { get; set; } = new List<Donation>();
    public virtual ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    public virtual ICollection<VolunteerHistory> VolunteerHistories { get; set; } = new List<VolunteerHistory>();
    public virtual LeaderboardEntry? LeaderboardEntry { get; set; }
}
