using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IEventService
{
    Task<PagedResultDto<EventDto>> GetAllAsync(EventSearchDto request);
    Task<EventDto?> GetByIdAsync(int id);
    Task<EventDto> CreateAsync(EventCreateDto dto, int userId);
    Task<bool> UpdateAsync(int id, EventUpdateDto dto);
    Task<bool> DeleteAsync(int id);
}
