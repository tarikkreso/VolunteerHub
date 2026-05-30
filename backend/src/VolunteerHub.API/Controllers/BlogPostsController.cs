using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class BlogPostsController : ControllerBase
{
    private readonly IBlogPostService _blogPostService;
    private readonly ICurrentUserService _currentUserService;

    public BlogPostsController(IBlogPostService blogPostService, ICurrentUserService currentUserService)
    {
        _blogPostService = blogPostService;
        _currentUserService = currentUserService;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<BlogPostDto>>> GetAll([FromQuery] SearchRequestDto request)
    {
        var result = await _blogPostService.GetAllAsync(request);
        return Ok(result);
    }

    [HttpGet("all")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<PagedResultDto<BlogPostDto>>> GetAllAdmin([FromQuery] SearchRequestDto request)
    {
        var result = await _blogPostService.GetAllAsync(request, publishedOnly: false);
        return Ok(result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<BlogPostDto>> GetById(int id)
    {
        var result = await _blogPostService.GetByIdAsync(id, incrementViews: true);
        if (result == null) return NotFound(new { message = "Blog post nije pronađen." });
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<BlogPostDto>> Create([FromBody] BlogPostCreateDto dto)
    {
        var userId = _currentUserService.GetRequiredUserId();
        var result = await _blogPostService.CreateAsync(dto, userId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] BlogPostCreateDto dto)
    {
        var success = await _blogPostService.UpdateAsync(id, dto);
        if (!success) return NotFound(new { message = "Blog post nije pronađen." });
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _blogPostService.DeleteAsync(id);
        if (!success) return NotFound(new { message = "Blog post nije pronađen." });
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

        var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "blog");
        Directory.CreateDirectory(uploadsDir);

        var fileName = $"{Guid.NewGuid()}{ext}";
        var filePath = Path.Combine(uploadsDir, fileName);

        await using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        return Ok(new { imageUrl = $"/uploads/blog/{fileName}" });
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
}
