using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Infrastructure.Data;
using VolunteerHub.Domain.Entities;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public CategoriesController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<EventCategoryDto>>> GetAll()
    {
        var categories = await _context.EventCategories
            .Select(c => new EventCategoryDto
            {
                Id = c.Id,
                Name = c.Name,
                Description = c.Description,
                IconUrl = c.IconUrl,
                Color = c.Color,
                CreatedAt = c.CreatedAt
            })
            .ToListAsync();
        return Ok(categories);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<EventCategoryDto>> Create([FromBody] EventCategoryDto dto)
    {
        var category = new EventCategory { Name = dto.Name, Description = dto.Description, IconUrl = dto.IconUrl, Color = dto.Color };
        _context.EventCategories.Add(category);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetAll), new { id = category.Id }, category);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] EventCategoryDto dto)
    {
        var category = await _context.EventCategories.FindAsync(id);
        if (category == null) return NotFound();
        category.Name = dto.Name;
        category.Description = dto.Description;
        category.IconUrl = dto.IconUrl;
        category.Color = dto.Color;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var category = await _context.EventCategories.FindAsync(id);
        if (category == null) return NotFound();
        _context.EventCategories.Remove(category);
        await _context.SaveChangesAsync();
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
public class CitiesController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public CitiesController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<CityDto>>> GetAll([FromQuery] int? countryId = null)
    {
        var query = _context.Cities.Include(c => c.Country).AsQueryable();
        if (countryId.HasValue)
            query = query.Where(c => c.CountryId == countryId.Value);

        var cities = await query
            .Select(c => new CityDto
            {
                Id = c.Id,
                Name = c.Name,
                PostalCode = c.PostalCode,
                CountryName = c.Country.Name,
                CreatedAt = c.CreatedAt
            })
            .ToListAsync();
        return Ok(cities);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<CityDto>> Create([FromBody] City city)
    {
        _context.Cities.Add(city);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetAll), new { id = city.Id }, city);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] City dto)
    {
        var city = await _context.Cities.FindAsync(id);
        if (city == null) return NotFound();
        city.Name = dto.Name;
        city.PostalCode = dto.PostalCode;
        city.CountryId = dto.CountryId;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var city = await _context.Cities.FindAsync(id);
        if (city == null) return NotFound();
        _context.Cities.Remove(city);
        await _context.SaveChangesAsync();
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
public class CountriesController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public CountriesController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<CountryDto>>> GetAll()
    {
        var countries = await _context.Countries
            .Select(c => new CountryDto { Id = c.Id, Name = c.Name, Code = c.Code, CreatedAt = c.CreatedAt })
            .ToListAsync();
        return Ok(countries);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<CountryDto>> Create([FromBody] Country country)
    {
        _context.Countries.Add(country);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetAll), new { id = country.Id }, country);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] Country dto)
    {
        var country = await _context.Countries.FindAsync(id);
        if (country == null) return NotFound();
        country.Name = dto.Name;
        country.Code = dto.Code;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var country = await _context.Countries.FindAsync(id);
        if (country == null) return NotFound();
        _context.Countries.Remove(country);
        await _context.SaveChangesAsync();
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
public class SkillsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public SkillsController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<SkillDto>>> GetAll()
    {
        var skills = await _context.Skills
            .Select(s => new SkillDto { Id = s.Id, Name = s.Name, Description = s.Description, IconUrl = s.IconUrl, Color = s.Color, CreatedAt = s.CreatedAt })
            .ToListAsync();
        return Ok(skills);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<SkillDto>> Create([FromBody] Skill skill)
    {
        _context.Skills.Add(skill);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetAll), new { id = skill.Id }, skill);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Update(int id, [FromBody] Skill dto)
    {
        var skill = await _context.Skills.FindAsync(id);
        if (skill == null) return NotFound();
        skill.Name = dto.Name;
        skill.Description = dto.Description;
        skill.IconUrl = dto.IconUrl;
        skill.Color = dto.Color;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<IActionResult> Delete(int id)
    {
        var skill = await _context.Skills.FindAsync(id);
        if (skill == null) return NotFound();
        _context.Skills.Remove(skill);
        await _context.SaveChangesAsync();
        return NoContent();
    }
}
