using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.API.Contracts;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ShiftsController : ControllerBase
{
    private readonly IShiftService _shiftService;

    public ShiftsController(IShiftService shiftService)
    {
        _shiftService = shiftService;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<ShiftDto>>> GetByEvent([FromQuery] int eventId)
    {
        var result = await _shiftService.GetByEventAsync(eventId);
        return Ok(result);
    }

    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<ActionResult<ShiftDto>> GetById(int id)
    {
        var result = await _shiftService.GetByIdAsync(id);
        if (result == null) return NotFound(new { message = "Smjena nije pronadjena." });
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<ShiftDto>> Create([FromBody] ShiftCreateDto dto)
    {
        var validation = ValidateShift(dto);
        if (validation != null) return validation;

        var result = await _shiftService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] ShiftCreateDto dto)
    {
        var validation = ValidateShift(dto);
        if (validation != null) return validation;

        var success = await _shiftService.UpdateAsync(id, dto);
        if (!success) return NotFound(new { message = "Smjena nije pronadjena ili je zakljucana." });
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _shiftService.DeleteAsync(id);
        if (!success) return NotFound(new { message = "Smjena nije pronadjena." });
        return NoContent();
    }

    private static BadRequestObjectResult? ValidateShift(ShiftCreateDto dto)
    {
        if (dto.EndTime <= dto.StartTime)
        {
            return new BadRequestObjectResult(new ValidationErrorResponse
            {
                Message = "Molimo ispravite oznacena polja.",
                Errors = new Dictionary<string, string[]>
                {
                    ["endTime"] = ["Vrijeme zavrsetka mora biti nakon vremena pocetka."]
                }
            });
        }

        return null;
    }
}
