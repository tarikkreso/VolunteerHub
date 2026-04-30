using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IReferenceDataService
{
    Task<List<EventCategoryDto>> GetCategoriesAsync();
    Task<EventCategoryDto> CreateCategoryAsync(EventCategoryDto dto);
    Task<bool> UpdateCategoryAsync(int id, EventCategoryDto dto);
    Task DeleteCategoryAsync(int id);

    Task<List<CityDto>> GetCitiesAsync(int? countryId = null);
    Task<CityDto> CreateCityAsync(CityUpsertDto city);
    Task<bool> UpdateCityAsync(int id, CityUpsertDto city);
    Task DeleteCityAsync(int id);

    Task<List<CountryDto>> GetCountriesAsync();
    Task<CountryDto> CreateCountryAsync(CountryUpsertDto country);
    Task<bool> UpdateCountryAsync(int id, CountryUpsertDto country);
    Task DeleteCountryAsync(int id);

    Task<List<SkillDto>> GetSkillsAsync();
    Task<SkillDto> CreateSkillAsync(SkillUpsertDto skill);
    Task<bool> UpdateSkillAsync(int id, SkillUpsertDto skill);
    Task DeleteSkillAsync(int id);

    Task<List<BlogCategoryDto>> GetBlogCategoriesAsync();
    Task<BlogCategoryDto> CreateBlogCategoryAsync(BlogCategoryUpsertDto dto);
    Task<bool> UpdateBlogCategoryAsync(int id, BlogCategoryUpsertDto dto);
    Task DeleteBlogCategoryAsync(int id);
}
