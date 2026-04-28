using VolunteerHub.Application.DTOs;
using VolunteerHub.Domain.Entities;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IReferenceDataService
{
    Task<List<EventCategoryDto>> GetCategoriesAsync();
    Task<EventCategoryDto> CreateCategoryAsync(EventCategoryDto dto);
    Task<bool> UpdateCategoryAsync(int id, EventCategoryDto dto);
    Task DeleteCategoryAsync(int id);

    Task<List<CityDto>> GetCitiesAsync(int? countryId = null);
    Task<CityDto> CreateCityAsync(City city);
    Task<bool> UpdateCityAsync(int id, City city);
    Task DeleteCityAsync(int id);

    Task<List<CountryDto>> GetCountriesAsync();
    Task<CountryDto> CreateCountryAsync(Country country);
    Task<bool> UpdateCountryAsync(int id, Country country);
    Task DeleteCountryAsync(int id);

    Task<List<SkillDto>> GetSkillsAsync();
    Task<SkillDto> CreateSkillAsync(Skill skill);
    Task<bool> UpdateSkillAsync(int id, Skill skill);
    Task DeleteSkillAsync(int id);
}
