using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IUserService
{
    Task<PagedResultDto<UserDto>> GetAllAsync(SearchRequestDto request);
    Task<UserDto?> GetByIdAsync(int id);
    Task<bool> UpdateAsync(int id, UserUpdateDto dto);
    Task<UserStatsDto> GetStatsAsync(int userId);
}
