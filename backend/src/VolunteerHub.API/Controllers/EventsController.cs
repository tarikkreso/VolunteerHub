using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.API.Contracts;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EventsController : ControllerBase
{
    private readonly IEventService _eventService;
    private readonly IRecommendationService _recommendationService;

    public EventsController(IEventService eventService, IRecommendationService recommendationService)
    {
        _eventService = eventService;
        _recommendationService = recommendationService;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<PagedResultDto<EventDto>>> GetAll([FromQuery] EventSearchDto request)
    {
        var result = await _eventService.GetAllAsync(request);
        return Ok(result);
    }

    [HttpGet("recommended")]
    public async Task<ActionResult<List<EventRecommendationDto>>> GetRecommended([FromQuery] int top = 5)
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        var result = await _recommendationService.GetRecommendationsAsync(userId, top);
        return Ok(result);
    }

    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<ActionResult<EventDto>> GetById(int id)
    {
        var result = await _eventService.GetByIdAsync(id);
        if (result == null) return NotFound(new { message = "Dogadjaj nije pronadjen." });
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<EventDto>> Create([FromBody] EventCreateDto dto)
    {
        var validation = ValidateEventDates(dto.StartDate, dto.EndDate);
        if (validation != null) return validation;

        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        var result = await _eventService.CreateAsync(dto, userId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] EventUpdateDto dto)
    {
        var validation = ValidateEventDates(dto.StartDate, dto.EndDate);
        if (validation != null) return validation;

        var success = await _eventService.UpdateAsync(id, dto);
        if (!success) return NotFound(new { message = "Dogadjaj nije pronadjen." });
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _eventService.DeleteAsync(id);
        if (!success) return NotFound(new { message = "Dogadjaj nije pronadjen." });
        return NoContent();
    }

    [HttpPost("upload-image")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<object>> UploadImage(IFormFile file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { message = "Datoteka nije prilozena." });

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedExtensions.Contains(ext))
            return BadRequest(new { message = "Dozvoljeni formati: jpg, jpeg, png, webp, gif." });

        var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "events");
        Directory.CreateDirectory(uploadsDir);

        var fileName = $"{Guid.NewGuid()}{ext}";
        var filePath = Path.Combine(uploadsDir, fileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var url = $"/uploads/events/{fileName}";
        return Ok(new { imageUrl = url });
    }

    private static BadRequestObjectResult? ValidateEventDates(DateTime startDate, DateTime endDate)
    {
        if (endDate <= startDate)
        {
            return new BadRequestObjectResult(new ValidationErrorResponse
            {
                Message = "Molimo ispravite oznacena polja.",
                Errors = new Dictionary<string, string[]>
                {
                    ["endDate"] = ["Datum kraja mora biti nakon datuma pocetka."]
                }
            });
        }

        return null;
    }
}
