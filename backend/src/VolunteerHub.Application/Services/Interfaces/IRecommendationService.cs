using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IRecommendationService
{
    Task<List<EventRecommendationDto>> GetRecommendationsAsync(int userId, int top = 5);
}
