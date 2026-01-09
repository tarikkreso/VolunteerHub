using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IAuthService
{
    Task<LoginResponseDto> LoginAsync(LoginDto dto);
    Task<LoginResponseDto> RegisterAsync(UserCreateDto dto);
    Task<UserDto> GetCurrentUserAsync(int userId);
    Task<UserStatsDto> GetUserStatsAsync(int userId);
    Task<UserDto> UpdateProfileAsync(int userId, UserUpdateDto dto, string? oldPassword = null, string? newPassword = null);
    Task ForgotPasswordAsync(ForgotPasswordRequestDto dto);
    Task ResetPasswordAsync(ResetPasswordRequestDto dto);
}
