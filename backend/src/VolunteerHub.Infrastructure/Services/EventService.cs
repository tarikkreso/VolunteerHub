using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class EventService : IEventService
{
    private readonly ApplicationDbContext _context;

    public EventService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResultDto<EventDto>> GetAllAsync(EventSearchDto request)
    {
        var query = _context.Events
            .Include(e => e.Category)
            .Include(e => e.City)
            .Include(e => e.Organization)
            .Include(e => e.Shifts)
            .Include(e => e.EventRegistrations)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.Query))
        {
            query = query.Where(e =>
                e.Title.Contains(request.Query) ||
                e.Description.Contains(request.Query) ||
                (e.Requirements != null && e.Requirements.Contains(request.Query)) ||
                (e.Organization != null && e.Organization.Name.Contains(request.Query)));
        }

        if (request.CategoryId.HasValue)
            query = query.Where(e => e.CategoryId == request.CategoryId.Value);

        if (request.CityId.HasValue)
            query = query.Where(e => e.CityId == request.CityId.Value);

        if (request.OrganizationId.HasValue)
            query = query.Where(e => e.OrganizationId == request.OrganizationId.Value);

        if (request.StartDate.HasValue)
            query = query.Where(e => e.StartDate >= request.StartDate.Value);

        if (request.EndDate.HasValue)
            query = query.Where(e => e.EndDate <= request.EndDate.Value);

        if (request.FeaturedOnly == true)
            query = query.Where(e => e.IsFeatured);

        if (!string.IsNullOrWhiteSpace(request.Status) && Enum.TryParse<EventStatus>(request.Status, out var status))
            query = query.Where(e => e.Status == status);

        var totalCount = await query.CountAsync();

        var orderedQuery = request.PopularFirst
            ? query.OrderByDescending(e => e.EventRegistrations.Count).ThenByDescending(e => e.IsFeatured).ThenBy(e => e.StartDate)
            : query.OrderByDescending(e => e.IsFeatured).ThenBy(e => e.StartDate);

        var entities = await orderedQuery
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync();

        var items = entities.Select(MapEvent).ToList();

        return new PagedResultDto<EventDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = request.Page,
            PageSize = request.PageSize
        };
    }

    public async Task<EventDto?> GetByIdAsync(int id)
    {
        var entity = await _context.Events
            .Include(e => e.Category)
            .Include(e => e.City)
            .Include(e => e.Organization)
            .Include(e => e.Shifts)
            .Include(e => e.EventRegistrations)
            .FirstOrDefaultAsync(e => e.Id == id);

        return entity == null ? null : MapEvent(entity);
    }

    public async Task<EventDto> CreateAsync(EventCreateDto dto, int userId)
    {
        var evt = new Event
        {
            Title = dto.Title,
            Description = dto.Description,
            ImageUrl = dto.ImageUrl,
            StartDate = dto.StartDate,
            EndDate = dto.EndDate,
            Location = dto.Location,
            Latitude = dto.Latitude,
            Longitude = dto.Longitude,
            Requirements = dto.Requirements,
            MaxVolunteers = dto.MaxVolunteers,
            CategoryId = dto.CategoryId,
            CityId = dto.CityId,
            OrganizationId = dto.OrganizationId,
            IsFeatured = dto.IsFeatured,
            CreatedByUserId = userId,
            Status = EventStatus.Published
        };

        _context.Events.Add(evt);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(evt.Id))!;
    }

    public async Task<bool> UpdateAsync(int id, EventUpdateDto dto)
    {
        var evt = await _context.Events.FindAsync(id);
        if (evt == null)
            return false;

        evt.Title = dto.Title;
        evt.Description = dto.Description;
        evt.ImageUrl = dto.ImageUrl;
        evt.StartDate = dto.StartDate;
        evt.EndDate = dto.EndDate;
        evt.Location = dto.Location;
        evt.Latitude = dto.Latitude;
        evt.Longitude = dto.Longitude;
        evt.Requirements = dto.Requirements;
        evt.MaxVolunteers = dto.MaxVolunteers;
        evt.CategoryId = dto.CategoryId;
        evt.CityId = dto.CityId;
        evt.OrganizationId = dto.OrganizationId;
        evt.IsFeatured = dto.IsFeatured;

        if (!string.IsNullOrWhiteSpace(dto.Status) && Enum.TryParse<EventStatus>(dto.Status, out var status))
            evt.Status = status;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var evt = await _context.Events.FindAsync(id);
        if (evt == null)
            return false;

        evt.IsDeleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    private static EventDto MapEvent(Event e) => new()
    {
        Id = e.Id,
        Title = e.Title,
        Description = e.Description,
        ImageUrl = e.ImageUrl,
        StartDate = e.StartDate,
        EndDate = e.EndDate,
        Location = e.Location,
        Latitude = e.Latitude,
        Longitude = e.Longitude,
        Requirements = e.Requirements,
        MaxVolunteers = e.MaxVolunteers,
        Status = e.Status.ToString(),
        IsFeatured = e.IsFeatured,
        CategoryName = e.Category.Name,
        CityName = e.City != null ? e.City.Name : null,
        OrganizationId = e.OrganizationId,
        OrganizationName = e.Organization != null ? e.Organization.Name : null,
        OrganizationDescription = e.Organization != null ? e.Organization.Description : null,
        ShiftCount = e.Shifts.Count,
        RegisteredVolunteers = e.EventRegistrations.Count,
        CreatedAt = e.CreatedAt
    };
}
