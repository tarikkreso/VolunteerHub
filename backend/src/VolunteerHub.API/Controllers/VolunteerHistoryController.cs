using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class VolunteerHistoryController : ControllerBase
{
    private readonly IVolunteerHistoryService _volunteerHistoryService;
    private readonly ICurrentUserService _currentUserService;

    public VolunteerHistoryController(
        IVolunteerHistoryService volunteerHistoryService,
        ICurrentUserService currentUserService)
    {
        _volunteerHistoryService = volunteerHistoryService;
        _currentUserService = currentUserService;
    }

    [HttpGet("me")]
    public async Task<ActionResult<List<VolunteerHistoryDto>>> GetMine()
    {
        var userId = _currentUserService.GetRequiredUserId();
        return Ok(await _volunteerHistoryService.GetByUserAsync(userId));
    }

    [HttpGet("user/{userId}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<List<VolunteerHistoryDto>>> GetByUser(int userId)
    {
        return Ok(await _volunteerHistoryService.GetByUserAsync(userId));
    }
}
