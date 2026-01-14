using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LeaderboardController : ControllerBase
{
    private readonly ILeaderboardService _leaderboardService;

    public LeaderboardController(ILeaderboardService leaderboardService)
    {
        _leaderboardService = leaderboardService;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<LeaderboardEntryDto>>> GetLeaderboard([FromQuery] int top = 10)
    {
        var result = await _leaderboardService.GetTopAsync(top);
        return Ok(result);
    }

    [HttpGet("paged")]
    [AllowAnonymous]
    public async Task<ActionResult<PagedResultDto<LeaderboardEntryDto>>> GetLeaderboardPaged(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var result = await _leaderboardService.GetPagedAsync(page, pageSize);
        return Ok(result);
    }

    [HttpGet("user/{userId}")]
    [Authorize]
    public async Task<ActionResult<LeaderboardEntryDto>> GetUserRank(int userId)
    {
        var result = await _leaderboardService.GetUserRankAsync(userId);
        if (result == null) return NotFound(new { message = "Korisnik nema unos na ljestvici." });
        return Ok(result);
    }
}
