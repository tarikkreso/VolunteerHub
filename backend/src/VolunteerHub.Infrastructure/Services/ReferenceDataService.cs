using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class ReferenceDataService : IReferenceDataService
{
    private readonly ApplicationDbContext _context;

    public ReferenceDataService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<EventCategoryDto>> GetCategoriesAsync()
    {
        return await _context.EventCategories
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
    }

    public async Task<EventCategoryDto> CreateCategoryAsync(EventCategoryDto dto)
    {
        var category = new EventCategory
        {
            Name = dto.Name,
            Description = dto.Description,
            IconUrl = dto.IconUrl,
            Color = dto.Color
        };
        _context.EventCategories.Add(category);
        await _context.SaveChangesAsync();
        return (await GetCategoriesAsync()).First(c => c.Id == category.Id);
    }

    public async Task<bool> UpdateCategoryAsync(int id, EventCategoryDto dto)
    {
        var category = await _context.EventCategories.FindAsync(id);
        if (category == null) return false;

        category.Name = dto.Name;
        category.Description = dto.Description;
        category.IconUrl = dto.IconUrl;
        category.Color = dto.Color;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task DeleteCategoryAsync(int id)
    {
        var category = await _context.EventCategories.FindAsync(id)
            ?? throw new KeyNotFoundException("Kategorija nije pronadjena.");
        if (await _context.Events.AnyAsync(e => e.CategoryId == id))
            throw new InvalidOperationException("Kategorija se koristi na dogadjajima i ne moze se obrisati.");

        _context.EventCategories.Remove(category);
        await _context.SaveChangesAsync();
    }

    public async Task<List<CityDto>> GetCitiesAsync(int? countryId = null)
    {
        var query = _context.Cities.Include(c => c.Country).AsQueryable();
        if (countryId.HasValue)
            query = query.Where(c => c.CountryId == countryId.Value);

        return await query
            .Select(c => new CityDto
            {
                Id = c.Id,
                Name = c.Name,
                PostalCode = c.PostalCode,
                CountryName = c.Country.Name,
                CreatedAt = c.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<CityDto> CreateCityAsync(City city)
    {
        _context.Cities.Add(city);
        await _context.SaveChangesAsync();
        return (await GetCitiesAsync()).First(c => c.Id == city.Id);
    }

    public async Task<bool> UpdateCityAsync(int id, City dto)
    {
        var city = await _context.Cities.FindAsync(id);
        if (city == null) return false;

        city.Name = dto.Name;
        city.PostalCode = dto.PostalCode;
        city.CountryId = dto.CountryId;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task DeleteCityAsync(int id)
    {
        var city = await _context.Cities.FindAsync(id)
            ?? throw new KeyNotFoundException("Grad nije pronadjen.");
        if (await _context.Events.AnyAsync(e => e.CityId == id) ||
            await _context.Volunteers.AnyAsync(u => u.CityId == id) ||
            await _context.Organizations.AnyAsync(o => o.CityId == id))
            throw new InvalidOperationException("Grad se koristi u sistemu i ne moze se obrisati.");

        _context.Cities.Remove(city);
        await _context.SaveChangesAsync();
    }

    public async Task<List<CountryDto>> GetCountriesAsync()
    {
        return await _context.Countries
            .Select(c => new CountryDto { Id = c.Id, Name = c.Name, Code = c.Code, CreatedAt = c.CreatedAt })
            .ToListAsync();
    }

    public async Task<CountryDto> CreateCountryAsync(Country country)
    {
        _context.Countries.Add(country);
        await _context.SaveChangesAsync();
        return (await GetCountriesAsync()).First(c => c.Id == country.Id);
    }

    public async Task<bool> UpdateCountryAsync(int id, Country dto)
    {
        var country = await _context.Countries.FindAsync(id);
        if (country == null) return false;

        country.Name = dto.Name;
        country.Code = dto.Code;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task DeleteCountryAsync(int id)
    {
        var country = await _context.Countries.FindAsync(id)
            ?? throw new KeyNotFoundException("Drzava nije pronadjena.");
        if (await _context.Cities.AnyAsync(c => c.CountryId == id))
            throw new InvalidOperationException("Drzava ima povezane gradove i ne moze se obrisati.");

        _context.Countries.Remove(country);
        await _context.SaveChangesAsync();
    }

    public async Task<List<SkillDto>> GetSkillsAsync()
    {
        return await _context.Skills
            .Select(s => new SkillDto
            {
                Id = s.Id,
                Name = s.Name,
                Description = s.Description,
                IconUrl = s.IconUrl,
                Color = s.Color,
                CreatedAt = s.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<SkillDto> CreateSkillAsync(Skill skill)
    {
        _context.Skills.Add(skill);
        await _context.SaveChangesAsync();
        return (await GetSkillsAsync()).First(s => s.Id == skill.Id);
    }

    public async Task<bool> UpdateSkillAsync(int id, Skill dto)
    {
        var skill = await _context.Skills.FindAsync(id);
        if (skill == null) return false;

        skill.Name = dto.Name;
        skill.Description = dto.Description;
        skill.IconUrl = dto.IconUrl;
        skill.Color = dto.Color;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task DeleteSkillAsync(int id)
    {
        var skill = await _context.Skills.FindAsync(id)
            ?? throw new KeyNotFoundException("Vjestina nije pronadjena.");
        if (await _context.UserSkills.AnyAsync(us => us.SkillId == id))
            throw new InvalidOperationException("Vjestina je dodijeljena korisnicima i ne moze se obrisati.");

        _context.Skills.Remove(skill);
        await _context.SaveChangesAsync();
    }
}
