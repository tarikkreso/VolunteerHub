using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IVolunteerHistoryService
{
    Task<List<VolunteerHistoryDto>> GetByUserAsync(int userId);
}
