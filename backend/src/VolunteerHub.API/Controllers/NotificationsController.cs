using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;
    private readonly ICurrentUserService _currentUserService;

    public NotificationsController(INotificationService notificationService, ICurrentUserService currentUserService)
    {
        _notificationService = notificationService;
        _currentUserService = currentUserService;
    }

    [HttpGet]
    public async Task<ActionResult<List<NotificationDto>>> GetMyNotifications()
    {
        var userId = _currentUserService.GetRequiredUserId();
        var result = await _notificationService.GetByUserAsync(userId);
        return Ok(result);
    }

    [HttpPut("{id}/read")]
    public async Task<IActionResult> MarkAsRead(int id)
    {
        var userId = _currentUserService.GetRequiredUserId();
        var success = await _notificationService.MarkAsReadAsync(id, userId);
        if (!success) return NotFound();
        return NoContent();
    }

    [HttpPut("read-all")]
    public async Task<IActionResult> MarkAllAsRead()
    {
        var userId = _currentUserService.GetRequiredUserId();
        await _notificationService.MarkAllAsReadAsync(userId);
        return NoContent();
    }
}
