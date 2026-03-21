using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reportService;

    public ReportsController(IReportService reportService)
    {
        _reportService = reportService;
    }

    [HttpGet("volunteer-participation")]
    public async Task<IActionResult> GetVolunteerParticipation(
        [FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate)
    {
        var data = await _reportService.GetVolunteerParticipationAsync(startDate, endDate);
        return Ok(data);
    }

    [HttpGet("hours-by-volunteer")]
    public async Task<IActionResult> GetHoursByVolunteer(
        [FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate)
    {
        var data = await _reportService.GetHoursByVolunteerAsync(startDate, endDate);
        return Ok(data);
    }

    [HttpGet("event-attendance")]
    public async Task<IActionResult> GetEventAttendance(
        [FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate)
    {
        var data = await _reportService.GetEventAttendanceAsync(startDate, endDate);
        return Ok(data);
    }

    [HttpGet("donations-summary")]
    public async Task<IActionResult> GetDonationsSummary(
        [FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate)
    {
        var data = await _reportService.GetDonationsSummaryAsync(startDate, endDate);
        return Ok(data);
    }
}
