using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IOrganizationService
{
    Task<PagedResultDto<OrganizationDto>> GetAllAsync(SearchRequestDto request);
    Task<OrganizationDto?> GetByIdAsync(int id);
    Task<OrganizationDto> CreateAsync(OrganizationCreateDto dto, int userId);
    Task<bool> UpdateAsync(int id, OrganizationCreateDto dto);
    Task<bool> DeleteAsync(int id);
}
