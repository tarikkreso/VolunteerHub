namespace VolunteerHub.Application.Services.Interfaces;

public interface ICurrentUserService
{
    int? UserId { get; }
    bool IsAdmin { get; }
    int GetRequiredUserId();
}
