using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/shiftregistrations")]
[Authorize]
public class ShiftRegistrationsController : ControllerBase
{
    private readonly IShiftRegistrationService _service;

    public ShiftRegistrationsController(IShiftRegistrationService service)
    {
        _service = service;
    }

    [HttpPost("register/{shiftId}")]
    public async Task<ActionResult<ShiftRegistrationDto>> Register(int shiftId)
    {
        try
        {
            var userId = GetUserId();
            var result = await _service.RegisterAsync(shiftId, userId);
            return Ok(result);
        }
        catch (Exception ex) when (ex is KeyNotFoundException or InvalidOperationException)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("checkin/{shiftId}")]
    public async Task<ActionResult<ShiftRegistrationDto>> CheckIn(int shiftId)
    {
        try
        {
            var userId = GetUserId();
            var result = await _service.CheckInAsync(shiftId, userId);
            return Ok(result);
        }
        catch (Exception ex) when (ex is KeyNotFoundException or InvalidOperationException)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("checkout/{shiftId}")]
    public async Task<ActionResult<ShiftRegistrationDto>> CheckOut(int shiftId)
    {
        try
        {
            var userId = GetUserId();
            var result = await _service.CheckOutAsync(shiftId, userId);
            return Ok(result);
        }
        catch (Exception ex) when (ex is KeyNotFoundException or InvalidOperationException)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("by-shift/{shiftId}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<List<ShiftRegistrationDto>>> GetByShift(int shiftId)
    {
        var result = await _service.GetByShiftAsync(shiftId);
        return Ok(result);
    }

    [HttpGet("my-shifts")]
    public async Task<ActionResult<List<ShiftRegistrationDto>>> GetMyShifts()
    {
        var userId = GetUserId();
        var result = await _service.GetByUserAsync(userId);
        return Ok(result);
    }

    [HttpGet("by-user/{userId}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<List<ShiftRegistrationDto>>> GetByUser(int userId)
    {
        var result = await _service.GetByUserAsync(userId);
        return Ok(result);
    }

    [HttpPut("{id}/approve")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<ShiftRegistrationDto>> Approve(int id, [FromBody] ApproveDto dto)
    {
        try
        {
            var result = await _service.ApproveAsync(id, dto.ApprovedHours, dto.AdminNotes);
            return Ok(result);
        }
        catch (Exception ex) when (ex is KeyNotFoundException or InvalidOperationException)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}/reject")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<ShiftRegistrationDto>> Reject(int id, [FromBody] RejectDto dto)
    {
        try
        {
            var result = await _service.RejectAsync(id, dto.AdminNotes);
            return Ok(result);
        }
        catch (Exception ex) when (ex is KeyNotFoundException or InvalidOperationException)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("final-approval/{shiftId}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> FinalApproval(int shiftId)
    {
        try
        {
            await _service.FinalApprovalAsync(shiftId);
            return Ok(new { message = "Smjena je uspješno zaključana." });
        }
        catch (Exception ex) when (ex is KeyNotFoundException or InvalidOperationException)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("approve-all/{shiftId}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<List<ShiftRegistrationDto>>> ApproveAll(int shiftId, [FromBody] RejectDto? dto)
    {
        var result = await _service.ApproveAllAsync(shiftId, dto?.AdminNotes);
        return Ok(result);
    }

    private int GetUserId()
    {
        return int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
    }
}

public class ApproveDto
{
    public double? ApprovedHours { get; set; }
    public string? AdminNotes { get; set; }
}

public class RejectDto
{
    public string? AdminNotes { get; set; }
}
