using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IBlogPostService
{
    Task<PagedResultDto<BlogPostDto>> GetAllAsync(SearchRequestDto request, bool publishedOnly = true);
    Task<BlogPostDto?> GetByIdAsync(int id, bool incrementViews = false);
    Task<BlogPostDto> CreateAsync(BlogPostCreateDto dto, int authorId);
    Task<bool> UpdateAsync(int id, BlogPostCreateDto dto);
    Task<bool> DeleteAsync(int id);
}
