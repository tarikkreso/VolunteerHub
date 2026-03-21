using System.Security.Claims;
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

    public BlogPostsController(IBlogPostService blogPostService)
    {
        _blogPostService = blogPostService;
    }

    [HttpGet]
    [AllowAnonymous]
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
    [AllowAnonymous]
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
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
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
}
