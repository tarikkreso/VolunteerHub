using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;

    public UsersController(IUserService userService)
    {
        _userService = userService;
    }

    [HttpGet]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<PagedResultDto<UserDto>>> GetAll([FromQuery] SearchRequestDto request)
    {
        var result = await _userService.GetAllAsync(request);
        return Ok(result);
    }

    [HttpGet("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<UserDto>> GetById(int id)
    {
        var result = await _userService.GetByIdAsync(id);
        if (result == null)
        {
            return NotFound(new { message = "Korisnik nije pronađen." });
        }

        return Ok(result);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] UserUpdateDto dto)
    {
        try
        {
            var success = await _userService.UpdateAsync(id, dto);
            if (!success)
            {
                return NotFound(new { message = "Korisnik nije pronađen." });
            }

            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpGet("{id}/stats")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<UserStatsDto>> GetStats(int id)
    {
        var stats = await _userService.GetStatsAsync(id);
        return Ok(stats);
    }
}
