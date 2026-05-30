using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EventRegistrationsController : ControllerBase
{
    private readonly IEventRegistrationService _eventRegistrationService;
    private readonly ICurrentUserService _currentUserService;

    public EventRegistrationsController(
        IEventRegistrationService eventRegistrationService,
        ICurrentUserService currentUserService)
    {
        _eventRegistrationService = eventRegistrationService;
        _currentUserService = currentUserService;
    }

    [HttpGet("me")]
    public async Task<ActionResult<List<EventRegistrationDto>>> GetMine()
    {
        var userId = _currentUserService.GetRequiredUserId();
        return Ok(await _eventRegistrationService.GetByUserAsync(userId));
    }

    [HttpGet("event/{eventId}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<List<EventRegistrationDto>>> GetByEvent(int eventId)
    {
        return Ok(await _eventRegistrationService.GetByEventAsync(eventId));
    }

    [HttpPost]
    public async Task<ActionResult<EventRegistrationDto>> Register([FromBody] EventRegistrationCreateDto dto)
    {
        try
        {
            var userId = _currentUserService.GetRequiredUserId();
            var result = await _eventRegistrationService.RegisterAsync(userId, dto);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpDelete("{registrationId}")]
    public async Task<IActionResult> Cancel(int registrationId, [FromQuery] string reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
            return BadRequest(new { message = "Razlog otkazivanja je obavezan." });

        var userId = _currentUserService.GetRequiredUserId();
        var success = await _eventRegistrationService.CancelAsync(registrationId, userId, reason);
        if (!success)
            return NotFound(new { message = "Prijava na događaj nije pronađena." });
        return NoContent();
    }
}
