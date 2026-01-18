using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class BlogPostService : IBlogPostService
{
    private readonly ApplicationDbContext _context;

    public BlogPostService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResultDto<BlogPostDto>> GetAllAsync(SearchRequestDto request, bool publishedOnly = true)
    {
        var query = _context.BlogPosts
            .Include(b => b.Author)
            .Include(b => b.BlogCategory)
            .Include(b => b.Organization)
            .AsQueryable();

        if (publishedOnly)
            query = query.Where(b => b.IsPublished);

        if (!string.IsNullOrWhiteSpace(request.Query))
        {
            query = query.Where(b =>
                b.Title.Contains(request.Query) ||
                (b.Tags != null && b.Tags.Contains(request.Query)) ||
                (b.BlogCategory != null && b.BlogCategory.Name.Contains(request.Query)));
        }

        var totalCount = await query.CountAsync();
        var entities = await query
            .OrderByDescending(b => b.PublishedAt ?? b.ScheduledPublishAt ?? b.CreatedAt)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync();

        var items = entities.Select(MapBlogPost).ToList();

        return new PagedResultDto<BlogPostDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = request.Page,
            PageSize = request.PageSize
        };
    }

    public async Task<BlogPostDto?> GetByIdAsync(int id, bool incrementViews = false)
    {
        var post = await _context.BlogPosts
            .Include(b => b.Author)
            .Include(b => b.BlogCategory)
            .Include(b => b.Organization)
            .FirstOrDefaultAsync(b => b.Id == id);

        if (post == null)
            return null;

        if (incrementViews)
        {
            post.ViewCount++;
            await _context.SaveChangesAsync();
        }

        return MapBlogPost(post);
    }

    public async Task<BlogPostDto> CreateAsync(BlogPostCreateDto dto, int authorId)
    {
        var post = new BlogPost
        {
            Title = dto.Title,
            Content = dto.Content,
            Summary = dto.Summary,
            ImageUrl = dto.ImageUrl,
            Tags = dto.Tags,
            AuthorId = authorId,
            IsPublished = dto.IsPublished,
            PublishedAt = dto.IsPublished ? DateTime.UtcNow : null,
            ScheduledPublishAt = dto.ScheduledPublishAt,
            BlogCategoryId = dto.BlogCategoryId,
            OrganizationId = dto.OrganizationId
        };

        _context.BlogPosts.Add(post);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(post.Id))!;
    }

    public async Task<bool> UpdateAsync(int id, BlogPostCreateDto dto)
    {
        var post = await _context.BlogPosts.FindAsync(id);
        if (post == null)
            return false;

        post.Title = dto.Title;
        post.Content = dto.Content;
        post.Summary = dto.Summary;
        post.ImageUrl = dto.ImageUrl;
        post.Tags = dto.Tags;
        post.IsPublished = dto.IsPublished;
        post.ScheduledPublishAt = dto.ScheduledPublishAt;
        post.BlogCategoryId = dto.BlogCategoryId;
        post.OrganizationId = dto.OrganizationId;

        if (dto.IsPublished && post.PublishedAt == null)
            post.PublishedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var post = await _context.BlogPosts.FindAsync(id);
        if (post == null)
            return false;

        post.IsDeleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    private static BlogPostDto MapBlogPost(BlogPost b) => new()
    {
        Id = b.Id,
        Title = b.Title,
        Content = b.Content,
        Summary = b.Summary,
        ImageUrl = b.ImageUrl,
        Tags = b.Tags,
        IsPublished = b.IsPublished,
        PublishedAt = b.PublishedAt,
        ScheduledPublishAt = b.ScheduledPublishAt,
        ViewCount = b.ViewCount,
        AuthorName = $"{b.Author.FirstName} {b.Author.LastName}".Trim(),
        CategoryName = b.BlogCategory != null ? b.BlogCategory.Name : null,
        OrganizationName = b.Organization != null ? b.Organization.Name : null,
        CreatedAt = b.CreatedAt
    };
}
