using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.API.Contracts;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ICurrentUserService _currentUserService;

    public AuthController(IAuthService authService, ICurrentUserService currentUserService)
    {
        _authService = authService;
        _currentUserService = currentUserService;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<LoginResponseDto>> Login([FromBody] LoginDto dto)
    {
        try
        {
            var result = await _authService.LoginAsync(dto);
            return Ok(result);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<ActionResult<LoginResponseDto>> Register([FromBody] UserCreateDto dto)
    {
        try
        {
            var result = await _authService.RegisterAsync(dto);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("forgot-password")]
    [AllowAnonymous]
    public async Task<ActionResult> ForgotPassword([FromBody] ForgotPasswordRequestDto dto)
    {
        await _authService.ForgotPasswordAsync(dto);
        return Ok(new
        {
            message = "Ako korisnik sa unesenim emailom postoji, poslali smo upute za reset lozinke."
        });
    }

    [HttpPost("reset-password")]
    [AllowAnonymous]
    public async Task<ActionResult> ResetPassword([FromBody] ResetPasswordRequestDto dto)
    {
        if (!string.Equals(dto.NewPassword, dto.ConfirmPassword, StringComparison.Ordinal))
        {
            return BadRequest(new ValidationErrorResponse
            {
                Message = "Molimo ispravite oznacena polja.",
                Errors = new Dictionary<string, string[]>
                {
                    ["confirmPassword"] = ["Potvrda lozinke se ne podudara sa novom lozinkom."]
                }
            });
        }

        try
        {
            await _authService.ResetPasswordAsync(dto);
            return Ok(new { message = "Lozinka je uspjesno resetovana." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<UserDto>> GetCurrentUser()
    {
        var userId = _currentUserService.GetRequiredUserId();
        var user = await _authService.GetCurrentUserAsync(userId);
        return Ok(user);
    }

    [HttpGet("stats")]
    [Authorize]
    public async Task<ActionResult<UserStatsDto>> GetMyStats()
    {
        var userId = _currentUserService.GetRequiredUserId();
        var stats = await _authService.GetUserStatsAsync(userId);
        return Ok(stats);
    }

    [HttpPut("profile")]
    [Authorize]
    public async Task<ActionResult<UserDto>> UpdateProfile([FromBody] UpdateProfileRequestDto dto)
    {
        if (!string.IsNullOrWhiteSpace(dto.NewPassword) && string.IsNullOrWhiteSpace(dto.OldPassword))
        {
            return BadRequest(new ValidationErrorResponse
            {
                Message = "Molimo ispravite oznacena polja.",
                Errors = new Dictionary<string, string[]>
                {
                    ["oldPassword"] = ["Za promjenu lozinke potrebno je unijeti trenutnu lozinku."]
                }
            });
        }

        try
        {
            var userId = _currentUserService.GetRequiredUserId();
            var updateDto = new UserUpdateDto
            {
                FirstName = dto.FirstName,
                LastName = dto.LastName,
                Phone = dto.PhoneNumber,
                Email = dto.Email,
                ProfileImageUrl = dto.ProfileImageUrl,
                Bio = dto.Bio,
            };
            var result = await _authService.UpdateProfileAsync(userId, updateDto, dto.OldPassword, dto.NewPassword);
            return Ok(result);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
