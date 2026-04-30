using System.Security.Claims;
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
    public async Task<ActionResult<List<LeaderboardEntryDto>>> GetLeaderboard([FromQuery] int top = 10)
    {
        var result = await _leaderboardService.GetTopAsync(top);
        return Ok(result);
    }

    [HttpGet("paged")]
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
        var currentUserId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        var isAdmin = User.IsInRole("Admin") || User.IsInRole("SuperAdmin");
        if (!isAdmin && currentUserId != userId)
            return Forbid();

        var result = await _leaderboardService.GetUserRankAsync(userId);
        if (result == null) return NotFound(new { message = "Korisnik nema unos na ljestvici." });
        return Ok(result);
    }
}
