using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OrganizationsController : ControllerBase
{
    private readonly IOrganizationService _organizationService;

    public OrganizationsController(IOrganizationService organizationService)
    {
        _organizationService = organizationService;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<OrganizationDto>>> GetAll([FromQuery] SearchRequestDto request)
    {
        return Ok(await _organizationService.GetAllAsync(request));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<OrganizationDto>> GetById(int id)
    {
        var result = await _organizationService.GetByIdAsync(id);
        if (result == null)
            return NotFound(new { message = "Organizacija nije pronađena." });
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<OrganizationDto>> Create([FromBody] OrganizationCreateDto dto)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _organizationService.CreateAsync(dto, userId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] OrganizationCreateDto dto)
    {
        var success = await _organizationService.UpdateAsync(id, dto);
        if (!success)
            return NotFound(new { message = "Organizacija nije pronađena." });
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _organizationService.DeleteAsync(id);
        if (!success)
            return NotFound(new { message = "Organizacija nije pronađena." });
        return NoContent();
    }
}
