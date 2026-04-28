using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/userskills")]
[Authorize]
public class UserSkillsController : ControllerBase
{
    private readonly IUserSkillService _userSkillService;

    public UserSkillsController(IUserSkillService userSkillService)
    {
        _userSkillService = userSkillService;
    }

    [HttpGet("{userId:int}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<List<UserSkillDto>>> GetByUser(int userId)
    {
        var result = await _userSkillService.GetByUserAsync(userId);
        return Ok(result);
    }

    [HttpGet("my")]
    public async Task<ActionResult<List<UserSkillDto>>> GetMySkills()
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        var result = await _userSkillService.GetByUserAsync(userId);
        return Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult<UserSkillDto>> Add([FromBody] AddUserSkillDto dto)
    {
        try
        {
            var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
            var result = await _userSkillService.AddAsync(userId, dto.SkillId, dto.ProficiencyLevel, dto.YearsExperience);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{skillId}")]
    public async Task<IActionResult> Remove(int skillId)
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        var success = await _userSkillService.RemoveAsync(userId, skillId);
        if (!success) return NotFound(new { message = "Vještina nije pronađena." });
        return NoContent();
    }

    [HttpPut("{userSkillId}/verify")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> ToggleVerified(int userSkillId)
    {
        var success = await _userSkillService.ToggleVerifiedAsync(userSkillId);
        if (!success) return NotFound();
        return NoContent();
    }
}

public class AddUserSkillDto
{
    public int SkillId { get; set; }
    public int ProficiencyLevel { get; set; } = 3;
    public int YearsExperience { get; set; } = 0;
}
