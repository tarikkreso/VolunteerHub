using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly ApplicationDbContext _context;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IRabbitMQProducerService _rabbitMqProducerService;
    private readonly IConfiguration _configuration;

    public AuthService(
        ApplicationDbContext context,
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        IJwtTokenService jwtTokenService,
        IRabbitMQProducerService rabbitMqProducerService,
        IConfiguration configuration)
    {
        _context = context;
        _userManager = userManager;
        _signInManager = signInManager;
        _jwtTokenService = jwtTokenService;
        _rabbitMqProducerService = rabbitMqProducerService;
        _configuration = configuration;
    }

    public async Task<LoginResponseDto> LoginAsync(LoginDto dto)
    {
        var identifier = dto.Email.Trim();

        var identityUser = await _userManager.Users
            .FirstOrDefaultAsync(u =>
                (u.UserName != null && u.UserName == identifier) ||
                (u.Email != null && u.Email == identifier));

        if (identityUser == null || !identityUser.IsActive)
            throw new UnauthorizedAccessException("Pogrešno korisničko ime ili lozinka.");

        var signInResult = await _signInManager.CheckPasswordSignInAsync(identityUser, dto.Password, false);
        if (!signInResult.Succeeded)
            throw new UnauthorizedAccessException("Pogrešno korisničko ime ili lozinka.");

        var user = await _context.Volunteers
            .Include(u => u.City)
            .FirstOrDefaultAsync(u => u.IdentityUserId == identityUser.Id && u.IsActive);

        if (user == null)
            throw new UnauthorizedAccessException("Korisnički profil nije pronađen.");

        user.LastLoginAt = DateTime.UtcNow;
        identityUser.LastLoginAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        await _userManager.UpdateAsync(identityUser);

        var roles = await _userManager.GetRolesAsync(identityUser);
        var token = _jwtTokenService.GenerateToken(user, identityUser, roles);

        return new LoginResponseDto
        {
            Token = token,
            User = MapUserToDto(user)
        };
    }

    public async Task<LoginResponseDto> RegisterAsync(UserCreateDto dto)
    {
        var normalizedEmail = dto.Email.Trim();

        var existingUser = await _context.Volunteers.FirstOrDefaultAsync(u => u.Email == normalizedEmail);
        if (existingUser != null)
            throw new InvalidOperationException("Korisnik sa ovim emailom već postoji.");

        var identityUser = new ApplicationUser
        {
            UserName = normalizedEmail,
            Email = normalizedEmail,
            IsActive = true
        };

        var createResult = await _userManager.CreateAsync(identityUser, dto.Password);
        if (!createResult.Succeeded)
            throw new InvalidOperationException(string.Join(" ", createResult.Errors.Select(e => e.Description)));

        await _userManager.AddToRoleAsync(identityUser, "Volunteer");

        var user = new User
        {
            IdentityUserId = identityUser.Id,
            FirstName = dto.FirstName,
            LastName = dto.LastName,
            Email = normalizedEmail,
            Phone = dto.Phone,
            CityId = dto.CityId,
            Role = UserRole.Volunteer,
            IsActive = true
        };

        _context.Volunteers.Add(user);
        await _context.SaveChangesAsync();

        identityUser.ProfileUserId = user.Id;
        await _userManager.UpdateAsync(identityUser);

        _context.LeaderboardEntries.Add(new LeaderboardEntry
        {
            UserId = user.Id,
            TotalHours = 0,
            TotalEvents = 0,
            TotalShifts = 0,
            Rank = 0,
            Points = 0
        });

        await _context.SaveChangesAsync();

        var roles = await _userManager.GetRolesAsync(identityUser);
        var token = _jwtTokenService.GenerateToken(user, identityUser, roles);

        return new LoginResponseDto
        {
            Token = token,
            User = MapUserToDto(user)
        };
    }

    public async Task<UserDto> GetCurrentUserAsync(int userId)
    {
        var user = await _context.Volunteers
            .Include(u => u.City)
            .FirstOrDefaultAsync(u => u.Id == userId);

        if (user == null)
            throw new KeyNotFoundException("Korisnik nije pronađen.");

        return MapUserToDto(user);
    }

    public async Task<UserStatsDto> GetUserStatsAsync(int userId)
    {
        var leaderboard = await _context.LeaderboardEntries
            .FirstOrDefaultAsync(l => l.UserId == userId);

        var upcomingShifts = await _context.ShiftRegistrations
            .Include(sr => sr.Shift)
            .Where(sr => sr.UserId == userId && sr.Shift.StartTime > DateTime.UtcNow)
            .CountAsync();

        return new UserStatsDto
        {
            TotalHours = leaderboard?.TotalHours ?? 0,
            TotalEvents = leaderboard?.TotalEvents ?? 0,
            UpcomingShifts = upcomingShifts,
            Rank = leaderboard?.Rank ?? 0,
            Points = leaderboard?.Points ?? 0
        };
    }

    public async Task<UserDto> UpdateProfileAsync(int userId, UserUpdateDto dto, string? oldPassword = null, string? newPassword = null)
    {
        var user = await _context.Volunteers.Include(u => u.City).FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null)
            throw new KeyNotFoundException("Korisnik nije pronađen.");

        var identityUser = user.IdentityUserId.HasValue
            ? await _userManager.FindByIdAsync(user.IdentityUserId.Value.ToString())
            : null;

        if (!string.IsNullOrWhiteSpace(dto.FirstName))
            user.FirstName = dto.FirstName;
        if (!string.IsNullOrWhiteSpace(dto.LastName))
            user.LastName = dto.LastName;
        if (dto.Phone != null)
            user.Phone = dto.Phone;
        if (dto.ProfileImageUrl != null)
            user.ProfileImageUrl = dto.ProfileImageUrl;
        if (dto.Bio != null)
            user.Bio = dto.Bio;
        if (dto.CityId.HasValue)
            user.CityId = dto.CityId;

        if (!string.IsNullOrWhiteSpace(dto.Email) && dto.Email != user.Email)
        {
            var normalizedEmail = dto.Email.Trim();
            var emailTaken = await _context.Volunteers.AnyAsync(u => u.Email == normalizedEmail && u.Id != userId);
            if (emailTaken)
                throw new InvalidOperationException("Email adresa je već u upotrebi.");

            user.Email = normalizedEmail;

            if (identityUser != null)
            {
                identityUser.Email = normalizedEmail;
                identityUser.UserName = normalizedEmail;
                var emailResult = await _userManager.UpdateAsync(identityUser);
                if (!emailResult.Succeeded)
                    throw new InvalidOperationException(string.Join(" ", emailResult.Errors.Select(e => e.Description)));
            }
        }

        if (!string.IsNullOrWhiteSpace(oldPassword) && !string.IsNullOrWhiteSpace(newPassword))
        {
            if (identityUser == null)
                throw new InvalidOperationException("Identity korisnik nije pronađen.");

            var passwordResult = await _userManager.ChangePasswordAsync(identityUser, oldPassword, newPassword);
            if (!passwordResult.Succeeded)
                throw new UnauthorizedAccessException(string.Join(" ", passwordResult.Errors.Select(e => e.Description)));
        }

        await _context.SaveChangesAsync();
        return MapUserToDto(user);
    }

    public async Task ForgotPasswordAsync(ForgotPasswordRequestDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Email))
            return;

        var email = dto.Email.Trim();
        var identityUser = await _userManager.FindByEmailAsync(email);
        if (identityUser == null || !identityUser.IsActive)
            return;

        var token = await _userManager.GeneratePasswordResetTokenAsync(identityUser);
        var expirationMinutes = int.Parse(_configuration["Auth:PasswordResetExpirationMinutes"] ?? "30");
        var encodedEmail = Uri.EscapeDataString(email);
        var encodedToken = Uri.EscapeDataString(token);
        var resetUrl = _configuration["App:MobileResetPasswordUrl"]
                       ?? $"volunteerhub://reset-password?email={encodedEmail}&token={encodedToken}";

        var subject = "Reset lozinke - VolunteerHub";
        var body =
            $"<h2>Zahtjev za reset lozinke</h2>" +
            $"<p>Kliknite na link ispod kako biste postavili novu lozinku:</p>" +
            $"<p><a href=\"{resetUrl}\">Resetuj lozinku</a></p>" +
            $"<p>Ako link ne radi, kopirajte ovaj token u aplikaciju:</p>" +
            $"<p><code>{System.Net.WebUtility.HtmlEncode(token)}</code></p>" +
            $"<p>Token istiće za približno {expirationMinutes} minuta.</p>";

        await _rabbitMqProducerService.PublishEmailNotificationAsync(email, subject, body, true);
    }

    public async Task ResetPasswordAsync(ResetPasswordRequestDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Token))
            throw new InvalidOperationException("Email i token su obavezni.");

        if (string.IsNullOrWhiteSpace(dto.NewPassword) || dto.NewPassword.Length < 6)
            throw new InvalidOperationException("Nova lozinka mora imati najmanje 6 karaktera.");

        if (dto.NewPassword != dto.ConfirmPassword)
            throw new InvalidOperationException("Potvrda lozinke se ne podudara.");

        var identityUser = await _userManager.FindByEmailAsync(dto.Email.Trim());
        if (identityUser == null || !identityUser.IsActive)
            throw new InvalidOperationException("Neispravan ili istekao token za reset lozinke.");

        var result = await _userManager.ResetPasswordAsync(identityUser, dto.Token.Trim(), dto.NewPassword);
        if (!result.Succeeded)
            throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));
    }

    private static UserDto MapUserToDto(User user) => new()
    {
        Id = user.Id,
        FirstName = user.FirstName,
        LastName = user.LastName,
        Email = user.Email,
        Phone = user.Phone,
        ProfileImageUrl = user.ProfileImageUrl,
        Bio = user.Bio,
        Role = user.Role.ToString(),
        CityName = user.City?.Name,
        CreatedAt = user.CreatedAt
    };
}
