using Microsoft.AspNetCore.Identity;

namespace VolunteerHub.Domain.Entities;

public class ApplicationUser : IdentityUser<int>
{
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastLoginAt { get; set; }
    public int? ProfileUserId { get; set; }
}
