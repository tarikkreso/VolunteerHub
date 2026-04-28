using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CategoriesController : ControllerBase
{
    private readonly IReferenceDataService _referenceData;

    public CategoriesController(IReferenceDataService referenceData)
    {
        _referenceData = referenceData;
    }

    [HttpGet]
    public async Task<ActionResult<List<EventCategoryDto>>> GetAll()
    {
        return Ok(await _referenceData.GetCategoriesAsync());
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<EventCategoryDto>> Create([FromBody] EventCategoryDto dto)
    {
        var category = await _referenceData.CreateCategoryAsync(dto);
        return CreatedAtAction(nameof(GetAll), new { id = category.Id }, category);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] EventCategoryDto dto)
    {
        var success = await _referenceData.UpdateCategoryAsync(id, dto);
        return success ? NoContent() : NotFound();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        try
        {
            await _referenceData.DeleteCategoryAsync(id);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CitiesController : ControllerBase
{
    private readonly IReferenceDataService _referenceData;

    public CitiesController(IReferenceDataService referenceData)
    {
        _referenceData = referenceData;
    }

    [HttpGet]
    public async Task<ActionResult<List<CityDto>>> GetAll([FromQuery] int? countryId = null)
    {
        return Ok(await _referenceData.GetCitiesAsync(countryId));
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<CityDto>> Create([FromBody] City city)
    {
        var created = await _referenceData.CreateCityAsync(city);
        return CreatedAtAction(nameof(GetAll), new { id = created.Id }, created);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] City dto)
    {
        var success = await _referenceData.UpdateCityAsync(id, dto);
        return success ? NoContent() : NotFound();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        try
        {
            await _referenceData.DeleteCityAsync(id);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CountriesController : ControllerBase
{
    private readonly IReferenceDataService _referenceData;

    public CountriesController(IReferenceDataService referenceData)
    {
        _referenceData = referenceData;
    }

    [HttpGet]
    public async Task<ActionResult<List<CountryDto>>> GetAll()
    {
        return Ok(await _referenceData.GetCountriesAsync());
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<CountryDto>> Create([FromBody] Country country)
    {
        var created = await _referenceData.CreateCountryAsync(country);
        return CreatedAtAction(nameof(GetAll), new { id = created.Id }, created);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] Country dto)
    {
        var success = await _referenceData.UpdateCountryAsync(id, dto);
        return success ? NoContent() : NotFound();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        try
        {
            await _referenceData.DeleteCountryAsync(id);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SkillsController : ControllerBase
{
    private readonly IReferenceDataService _referenceData;

    public SkillsController(IReferenceDataService referenceData)
    {
        _referenceData = referenceData;
    }

    [HttpGet]
    public async Task<ActionResult<List<SkillDto>>> GetAll()
    {
        return Ok(await _referenceData.GetSkillsAsync());
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<SkillDto>> Create([FromBody] Skill skill)
    {
        var created = await _referenceData.CreateSkillAsync(skill);
        return CreatedAtAction(nameof(GetAll), new { id = created.Id }, created);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] Skill dto)
    {
        var success = await _referenceData.UpdateSkillAsync(id, dto);
        return success ? NoContent() : NotFound();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        try
        {
            await _referenceData.DeleteSkillAsync(id);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
