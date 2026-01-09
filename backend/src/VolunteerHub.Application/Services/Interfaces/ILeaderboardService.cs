using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface ILeaderboardService
{
    Task<List<LeaderboardEntryDto>> GetTopAsync(int count = 10);
    Task<PagedResultDto<LeaderboardEntryDto>> GetPagedAsync(int page = 1, int pageSize = 20);
    Task<LeaderboardEntryDto?> GetUserRankAsync(int userId);
}
