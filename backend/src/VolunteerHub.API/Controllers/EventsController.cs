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
    private readonly ICurrentUserService _currentUserService;

    public EventsController(
        IEventService eventService,
        IRecommendationService recommendationService,
        ICurrentUserService currentUserService)
    {
        _eventService = eventService;
        _recommendationService = recommendationService;
        _currentUserService = currentUserService;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<EventDto>>> GetAll([FromQuery] EventSearchDto request)
    {
        var result = await _eventService.GetAllAsync(request);
        return Ok(result);
    }

    [HttpGet("recommended")]
    public async Task<ActionResult<List<EventRecommendationDto>>> GetRecommended([FromQuery] int top = 5)
    {
        var userId = _currentUserService.GetRequiredUserId();
        var result = await _recommendationService.GetRecommendationsAsync(userId, top);
        return Ok(result);
    }

    [HttpGet("{id}")]
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

        var userId = _currentUserService.GetRequiredUserId();
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

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { message = "Slika ne smije biti veca od 5 MB." });

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedExtensions.Contains(ext) || !HasAllowedImageContentType(file.ContentType))
            return BadRequest(new { message = "Dozvoljeni formati: jpg, jpeg, png, webp, gif." });

        if (!await HasAllowedImageSignatureAsync(file, ext))
            return BadRequest(new { message = "Sadrzaj datoteke ne odgovara dozvoljenom formatu slike." });

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

    private static async Task<bool> HasAllowedImageSignatureAsync(IFormFile file, string ext)
    {
        var header = new byte[12];
        await using var stream = file.OpenReadStream();
        var read = await stream.ReadAsync(header);
        if (read < 4) return false;

        return ext switch
        {
            ".jpg" or ".jpeg" => header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF,
            ".png" => read >= 8 &&
                      header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 &&
                      header[4] == 0x0D && header[5] == 0x0A && header[6] == 0x1A && header[7] == 0x0A,
            ".gif" => header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x38,
            ".webp" => read >= 12 &&
                       header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 &&
                       header[8] == 0x57 && header[9] == 0x45 && header[10] == 0x42 && header[11] == 0x50,
            _ => false
        };
    }

    private static bool HasAllowedImageContentType(string? contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType) ||
            contentType.Equals("application/octet-stream", StringComparison.OrdinalIgnoreCase))
            return true;

        var allowedMimeTypes = new[] { "image/jpeg", "image/png", "image/webp", "image/gif" };
        return allowedMimeTypes.Contains(contentType.ToLowerInvariant());
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
