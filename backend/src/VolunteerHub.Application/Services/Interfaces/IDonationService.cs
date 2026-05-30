using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IDonationService
{
    Task<PagedResultDto<DonationDto>> GetByCampaignAsync(int campaignId, SearchRequestDto request);
    Task<PagedResultDto<DonationDto>> GetByUserAsync(int userId, SearchRequestDto request);
    Task<DonationDto?> GetByIdAsync(int id);
    Task<DonationDto?> GetByIdForUserAsync(int id, int userId, bool includeAll);
    Task<DonationDto?> GetByPaymentIntentForUserAsync(string paymentIntentId, int userId, bool includeAll);
    Task<PaymentIntentResponseDto> CreatePaymentIntentAsync(PaymentIntentRequestDto dto, int? userId);
    Task<DonationDto> SyncStripePaymentAsync(string paymentIntentId, int userId, bool includeAll);
    Task<DonationDto> RecordStripePaymentAsync(StripeDonationCreateDto dto, int? userId);
    Task<DonationDto> RefundAsync(int donationId);
    Task<bool> MarkRefundedAsync(string? paymentIntentId, string? chargeId, decimal refundedAmount);
    Task<bool> MarkRefundFailedAsync(string? paymentIntentId, string? chargeId, decimal refundedAmount);
    Task<List<DonationDto>> GetRecentAsync(int count = 10);
}
