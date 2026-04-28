using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IEventRegistrationService
{
    Task<EventRegistrationDto> RegisterAsync(int userId, EventRegistrationCreateDto dto);
    Task<List<EventRegistrationDto>> GetByUserAsync(int userId);
    Task<List<EventRegistrationDto>> GetByEventAsync(int eventId);
    Task<bool> CancelAsync(int registrationId, int userId, string reason);
}
