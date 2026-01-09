using VolunteerHub.Domain.Enums;

namespace VolunteerHub.Domain.Entities;

/// <summary>
/// ShiftRegistration entity - represents volunteer registration for shifts
/// </summary>
public class ShiftRegistration : BaseEntity
{
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    
    public int ShiftId { get; set; }
    public Shift Shift { get; set; } = null!;
    
    public ShiftStatus Status { get; set; } = ShiftStatus.Pending;
    public DateTime? CheckInTime { get; set; }
    public DateTime? CheckOutTime { get; set; }
    public double? HoursWorked { get; set; }
    public string? Notes { get; set; }
    public bool IsSuspicious { get; set; } = false; // Pattern recognition for suspicious hours
    public bool IsApproved { get; set; } = false; // Admin-approved hours
    public string? AdminNotes { get; set; } // Admin comments on the registration
}
