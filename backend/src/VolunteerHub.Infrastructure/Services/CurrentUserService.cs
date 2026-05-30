using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.Infrastructure.Services;

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public int? UserId
    {
        get
        {
            var claim = _httpContextAccessor.HttpContext?.User.FindFirst(ClaimTypes.NameIdentifier);
            return claim != null && int.TryParse(claim.Value, out var userId) ? userId : null;
        }
    }

    public bool IsAdmin =>
        _httpContextAccessor.HttpContext?.User.IsInRole("Admin") == true ||
        _httpContextAccessor.HttpContext?.User.IsInRole("SuperAdmin") == true;

    public int GetRequiredUserId()
    {
        return UserId ?? throw new UnauthorizedAccessException("Nevazeci identifikator korisnika.");
    }
}
