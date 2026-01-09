using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface ICampaignService
{
    Task<PagedResultDto<CampaignDto>> GetAllAsync(SearchRequestDto request);
    Task<CampaignDto?> GetByIdAsync(int id);
    Task<CampaignDto> CreateAsync(CampaignCreateDto dto, int userId);
    Task<bool> UpdateAsync(int id, CampaignCreateDto dto);
    Task<bool> DeleteAsync(int id);
}
