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
public class CampaignsController : ControllerBase
{
    private readonly ICampaignService _campaignService;

    public CampaignsController(ICampaignService campaignService)
    {
        _campaignService = campaignService;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<CampaignDto>>> GetAll([FromQuery] SearchRequestDto request)
    {
        var result = await _campaignService.GetAllAsync(request);
        return Ok(result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CampaignDto>> GetById(int id)
    {
        var result = await _campaignService.GetByIdAsync(id);
        if (result == null) return NotFound(new { message = "Kampanja nije pronadjena." });
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<CampaignDto>> Create([FromBody] CampaignCreateDto dto)
    {
        var validation = ValidateCampaign(dto);
        if (validation != null) return validation;

        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        var result = await _campaignService.CreateAsync(dto, userId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] CampaignCreateDto dto)
    {
        var validation = ValidateCampaign(dto);
        if (validation != null) return validation;

        var success = await _campaignService.UpdateAsync(id, dto);
        if (!success) return NotFound(new { message = "Kampanja nije pronadjena." });
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _campaignService.DeleteAsync(id);
        if (!success) return NotFound(new { message = "Kampanja nije pronadjena." });
        return NoContent();
    }

    private static BadRequestObjectResult? ValidateCampaign(CampaignCreateDto dto)
    {
        var errors = new Dictionary<string, string[]>();

        if (dto.EndDate <= dto.StartDate)
        {
            errors["endDate"] = ["Datum zavrsetka mora biti nakon datuma pocetka."];
        }

        if (dto.GoalAmount <= 0)
        {
            errors["goalAmount"] = ["Ciljani iznos mora biti veci od 0."];
        }

        if (errors.Count == 0)
        {
            return null;
        }

        return new BadRequestObjectResult(new ValidationErrorResponse
        {
            Message = "Molimo ispravite oznacena polja.",
            Errors = errors
        });
    }
}
