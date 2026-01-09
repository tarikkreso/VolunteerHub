using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IDonationService
{
    Task<PagedResultDto<DonationDto>> GetByCampaignAsync(int campaignId, SearchRequestDto request);
    Task<PagedResultDto<DonationDto>> GetByUserAsync(int userId, SearchRequestDto request);
    Task<DonationDto?> GetByIdAsync(int id);
    Task<DonationDto> CreateAsync(DonationCreateDto dto, int? userId);
    Task<List<DonationDto>> GetRecentAsync(int count = 10);
}
