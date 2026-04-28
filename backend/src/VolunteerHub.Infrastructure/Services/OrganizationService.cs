using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class OrganizationService : IOrganizationService
{
    private readonly ApplicationDbContext _context;

    public OrganizationService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResultDto<OrganizationDto>> GetAllAsync(SearchRequestDto request)
    {
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 100);

        var query = _context.Organizations
            .Include(o => o.City)
            .Include(o => o.Events)
            .Where(o => !o.IsDeleted)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.Query))
            query = query.Where(o => o.Name.Contains(request.Query) || (o.Description != null && o.Description.Contains(request.Query)));

        var totalCount = await query.CountAsync();
        var entities = await query
            .OrderBy(o => o.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var items = entities.Select(Map).ToList();

        return new PagedResultDto<OrganizationDto>
        {
            Items = items,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<OrganizationDto?> GetByIdAsync(int id)
    {
        var entity = await _context.Organizations
            .Include(o => o.City)
            .Include(o => o.Events)
            .FirstOrDefaultAsync(o => o.Id == id && !o.IsDeleted);

        return entity == null ? null : Map(entity);
    }

    public async Task<OrganizationDto> CreateAsync(OrganizationCreateDto dto, int userId)
    {
        var organization = new Organization
        {
            Name = dto.Name,
            Description = dto.Description,
            Email = dto.Email,
            Phone = dto.Phone,
            Website = dto.Website,
            LogoUrl = dto.LogoUrl,
            Address = dto.Address,
            CityId = dto.CityId,
            OwnerUserId = userId
        };

        _context.Organizations.Add(organization);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(organization.Id))!;
    }

    public async Task<bool> UpdateAsync(int id, OrganizationCreateDto dto)
    {
        var organization = await _context.Organizations.FindAsync(id);
        if (organization == null)
            return false;

        organization.Name = dto.Name;
        organization.Description = dto.Description;
        organization.Email = dto.Email;
        organization.Phone = dto.Phone;
        organization.Website = dto.Website;
        organization.LogoUrl = dto.LogoUrl;
        organization.Address = dto.Address;
        organization.CityId = dto.CityId;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var organization = await _context.Organizations.FindAsync(id);
        if (organization == null)
            return false;

        organization.IsDeleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    private static OrganizationDto Map(Organization o) => new()
    {
        Id = o.Id,
        Name = o.Name,
        Description = o.Description,
        Email = o.Email,
        Phone = o.Phone,
        Website = o.Website,
        LogoUrl = o.LogoUrl,
        Address = o.Address,
        CityName = o.City != null ? o.City.Name : null,
        ActiveEvents = o.Events.Count(e => !e.IsDeleted && e.EndDate >= DateTime.UtcNow),
        CreatedAt = o.CreatedAt
    };
}
