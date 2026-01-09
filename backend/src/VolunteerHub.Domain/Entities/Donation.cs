using VolunteerHub.Domain.Enums;

namespace VolunteerHub.Domain.Entities;

/// <summary>
/// Donation entity - represents individual donations
/// </summary>
public class Donation : BaseEntity
{
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "BAM";
    public DonationStatus Status { get; set; } = DonationStatus.Pending;
    public bool IsAnonymous { get; set; } = false;
    public string? DonorName { get; set; }
    public string? Message { get; set; }
    public string? StripePaymentIntentId { get; set; }
    public string? StripeChargeId { get; set; }
    
    // Foreign keys
    public int? UserId { get; set; } // Nullable for anonymous donations
    public User? User { get; set; }
    
    public int CampaignId { get; set; }
    public Campaign Campaign { get; set; } = null!;
}
