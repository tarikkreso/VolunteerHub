using System.ComponentModel.DataAnnotations;

namespace VolunteerHub.Application.DTOs;

public class BaseDto
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UserDto : BaseDto
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string? Bio { get; set; }
    public string Role { get; set; } = string.Empty;
    public string? CityName { get; set; }
    public double TotalHours { get; set; }
    public int TotalEvents { get; set; }
}

public class UserCreateDto
{
    [Required, MaxLength(100)]
    public string FirstName { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string LastName { get; set; } = string.Empty;

    [Required, EmailAddress, MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(6), MaxLength(128)]
    public string Password { get; set; } = string.Empty;

    [Phone, MaxLength(30)]
    public string? Phone { get; set; }

    public int? CityId { get; set; }
}

public class UserUpdateDto
{
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string? Bio { get; set; }
    public int? CityId { get; set; }
}

public class UpdateProfileRequestDto
{
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Email { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string? Bio { get; set; }
    public string? OldPassword { get; set; }
    public string? NewPassword { get; set; }
}

public class LoginDto
{
    [Required, MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(4), MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

public class ForgotPasswordRequestDto
{
    [Required, EmailAddress, MaxLength(256)]
    public string Email { get; set; } = string.Empty;
}

public class ResetPasswordRequestDto
{
    [Required, EmailAddress, MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Token { get; set; } = string.Empty;

    [Required, MinLength(6), MaxLength(128)]
    public string NewPassword { get; set; } = string.Empty;

    [Required, MinLength(6), MaxLength(128)]
    public string ConfirmPassword { get; set; } = string.Empty;
}

public class LoginResponseDto
{
    public string Token { get; set; } = string.Empty;
    public UserDto User { get; set; } = null!;
}

public class OrganizationDto : BaseDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Website { get; set; }
    public string? LogoUrl { get; set; }
    public string? Address { get; set; }
    public string? CityName { get; set; }
    public int ActiveEvents { get; set; }
}

public class OrganizationCreateDto
{
    [Required, MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(2000)]
    public string? Description { get; set; }

    [EmailAddress, MaxLength(256)]
    public string? Email { get; set; }

    [Phone, MaxLength(30)]
    public string? Phone { get; set; }

    [MaxLength(500)]
    public string? Website { get; set; }

    [MaxLength(500)]
    public string? LogoUrl { get; set; }

    [MaxLength(500)]
    public string? Address { get; set; }

    public int? CityId { get; set; }
}

public class EventDto : BaseDto
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public string Location { get; set; } = string.Empty;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? Requirements { get; set; }
    public int MaxVolunteers { get; set; }
    public string Status { get; set; } = string.Empty;
    public bool IsFeatured { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CityName { get; set; }
    public int? OrganizationId { get; set; }
    public string? OrganizationName { get; set; }
    public string? OrganizationDescription { get; set; }
    public int ShiftCount { get; set; }
    public int RegisteredVolunteers { get; set; }
}

public class EventCreateDto
{
    [Required, MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [Required]
    public string Description { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? ImageUrl { get; set; }

    [Required]
    public DateTime StartDate { get; set; }

    [Required]
    public DateTime EndDate { get; set; }

    [Required, MaxLength(300)]
    public string Location { get; set; } = string.Empty;

    [Range(-90, 90)]
    public double? Latitude { get; set; }

    [Range(-180, 180)]
    public double? Longitude { get; set; }

    [MaxLength(2000)]
    public string? Requirements { get; set; }

    [Range(1, 10000)]
    public int MaxVolunteers { get; set; }

    [Required]
    public int CategoryId { get; set; }

    public int? CityId { get; set; }
    public int? OrganizationId { get; set; }
    public bool IsFeatured { get; set; }
}

public class EventUpdateDto : EventCreateDto
{
    public string? Status { get; set; }
}

public class ShiftDto : BaseDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public int MaxVolunteers { get; set; }
    public int CurrentVolunteers { get; set; }
    public bool IsLocked { get; set; }
    public int EventId { get; set; }
    public string EventTitle { get; set; } = string.Empty;
}

public class ShiftCreateDto
{
    [Required, MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Description { get; set; }

    [Required]
    public DateTime StartTime { get; set; }

    [Required]
    public DateTime EndTime { get; set; }

    [Range(1, 1000)]
    public int MaxVolunteers { get; set; }

    [Required]
    public int EventId { get; set; }
}

public class ShiftRegistrationDto : BaseDto
{
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public int ShiftId { get; set; }
    public string ShiftName { get; set; } = string.Empty;
    public string EventTitle { get; set; } = string.Empty;
    public DateTime ShiftStartTime { get; set; }
    public DateTime ShiftEndTime { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime? CheckInTime { get; set; }
    public DateTime? CheckOutTime { get; set; }
    public double? HoursWorked { get; set; }
    public bool IsSuspicious { get; set; }
    public string? AdminNotes { get; set; }
}

public class ShiftRegistrationCreateDto
{
    public int ShiftId { get; set; }
}

public class ShiftRegistrationUpdateDto
{
    public string? Status { get; set; }
    public DateTime? CheckInTime { get; set; }
    public DateTime? CheckOutTime { get; set; }
    public string? AdminNotes { get; set; }
}

public class EventRegistrationDto : BaseDto
{
    public int EventId { get; set; }
    public string EventTitle { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime RegisteredAt { get; set; }
    public DateTime? CancelledAt { get; set; }
    public string? Notes { get; set; }
}

public class EventRegistrationCreateDto
{
    [Required]
    public int EventId { get; set; }

    [MaxLength(1000)]
    public string? Notes { get; set; }
}

public class CampaignDto : BaseDto
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public decimal GoalAmount { get; set; }
    public decimal CurrentAmount { get; set; }
    public double ProgressPercentage => GoalAmount > 0 ? Math.Min((double)(CurrentAmount / GoalAmount) * 100, 100) : 0;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public bool IsActive { get; set; }
    public bool IsFeatured { get; set; }
    public int DonationCount { get; set; }
    public string? OrganizationName { get; set; }
}

public class CampaignCreateDto
{
    [Required, MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [Required]
    public string Description { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? ImageUrl { get; set; }

    [Range(1, 10000000)]
    public decimal GoalAmount { get; set; }

    [Required]
    public DateTime StartDate { get; set; }

    [Required]
    public DateTime EndDate { get; set; }

    public bool IsActive { get; set; } = true;
    public bool IsFeatured { get; set; }
    public int? OrganizationId { get; set; }
}

public class DonationDto : BaseDto
{
    public decimal Amount { get; set; }
    public string Currency { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public bool IsAnonymous { get; set; }
    public string? DonorName { get; set; }
    public string? Message { get; set; }
    public string CampaignTitle { get; set; } = string.Empty;
}

public class DonationCreateDto
{
    [Range(0.5, 1000000)]
    public decimal Amount { get; set; }

    [Required]
    public int CampaignId { get; set; }

    public bool IsAnonymous { get; set; }

    [MaxLength(200)]
    public string? DonorName { get; set; }

    [MaxLength(500)]
    public string? Message { get; set; }

    [MaxLength(200)]
    public string? StripePaymentIntentId { get; set; }
}

public class PaymentIntentRequestDto
{
    public decimal Amount { get; set; }
    public int CampaignId { get; set; }
    public bool IsAnonymous { get; set; }
    public string? DonorName { get; set; }
}

public class SkillDto : BaseDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? IconUrl { get; set; }
    public string? Color { get; set; }
}

public class UserSkillDto : BaseDto
{
    public int SkillId { get; set; }
    public string SkillName { get; set; } = string.Empty;
    public int ProficiencyLevel { get; set; }
    public int YearsExperience { get; set; }
    public bool IsVerified { get; set; }
}

public class LeaderboardEntryDto
{
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string? ProfileImageUrl { get; set; }
    public double TotalHours { get; set; }
    public int TotalEvents { get; set; }
    public int Rank { get; set; }
    public int Points { get; set; }
}

public class NotificationDto : BaseDto
{
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public string? ActionUrl { get; set; }
}

public class CountryDto : BaseDto
{
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
}

public class CityDto : BaseDto
{
    public string Name { get; set; } = string.Empty;
    public string? PostalCode { get; set; }
    public string CountryName { get; set; } = string.Empty;
}

public class EventCategoryDto : BaseDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? IconUrl { get; set; }
    public string? Color { get; set; }
}

public class BlogCategoryDto : BaseDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Color { get; set; }
}

public class BlogPostDto : BaseDto
{
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string? Summary { get; set; }
    public string? ImageUrl { get; set; }
    public string? Tags { get; set; }
    public bool IsPublished { get; set; }
    public DateTime? PublishedAt { get; set; }
    public DateTime? ScheduledPublishAt { get; set; }
    public int ViewCount { get; set; }
    public string AuthorName { get; set; } = string.Empty;
    public string? CategoryName { get; set; }
    public string? OrganizationName { get; set; }
    public int ReadingTime => (int)Math.Max(1, Math.Ceiling(Content.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length / 200.0));
}

public class BlogPostCreateDto
{
    [Required, MaxLength(300)]
    public string Title { get; set; } = string.Empty;

    [Required]
    public string Content { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Summary { get; set; }

    [MaxLength(500)]
    public string? ImageUrl { get; set; }

    [MaxLength(500)]
    public string? Tags { get; set; }

    public bool IsPublished { get; set; } = true;
    public DateTime? ScheduledPublishAt { get; set; }
    public int? BlogCategoryId { get; set; }
    public int? OrganizationId { get; set; }
}

public class EventRecommendationDto
{
    public EventDto Event { get; set; } = null!;
    public double Score { get; set; }
    public string? ReasonTags { get; set; }
}

public class VolunteerHistoryDto : BaseDto
{
    public int UserId { get; set; }
    public string ActionType { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? EventTitle { get; set; }
    public string? CampaignTitle { get; set; }
    public string? ShiftName { get; set; }
    public DateTime OccurredAt { get; set; }
}

public class SearchRequestDto
{
    [MaxLength(200)]
    public string? Query { get; set; }

    [Range(1, int.MaxValue)]
    public int Page { get; set; } = 1;

    [Range(1, 100)]
    public int PageSize { get; set; } = 10;
}

public class EventSearchDto : SearchRequestDto
{
    public int? CategoryId { get; set; }
    public int? CityId { get; set; }
    public int? OrganizationId { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? Status { get; set; }
    public bool? FeaturedOnly { get; set; }
    public bool PopularFirst { get; set; }
}

public class PagedResultDto<T>
{
    public List<T> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
}

public class DashboardStatsDto
{
    public int TotalEvents { get; set; }
    public int TotalShifts { get; set; }
    public int TotalVolunteers { get; set; }
    public double TotalHours { get; set; }
    public int ActiveCampaigns { get; set; }
    public decimal TotalDonations { get; set; }
    public int PendingApprovals { get; set; }
    public int UpcomingShiftsCount { get; set; }
    public List<VolunteerHistoryDto> RecentActivity { get; set; } = new();
}

public class UserStatsDto
{
    public double TotalHours { get; set; }
    public int TotalEvents { get; set; }
    public int UpcomingShifts { get; set; }
    public int Rank { get; set; }
    public int Points { get; set; }
}

// ── Report DTOs ──

public class VolunteerParticipationReportDto
{
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public int EventCount { get; set; }
    public int ShiftCount { get; set; }
    public double TotalHours { get; set; }
    public int ApprovedShifts { get; set; }
    public int RejectedShifts { get; set; }
}

public class HoursByVolunteerReportDto
{
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public double TotalApprovedHours { get; set; }
    public int TotalShifts { get; set; }
    public double AverageHoursPerShift { get; set; }
}

public class EventAttendanceReportDto
{
    public int EventId { get; set; }
    public string EventTitle { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public int ShiftCount { get; set; }
    public int TotalRegistrations { get; set; }
    public int ApprovedRegistrations { get; set; }
    public double TotalHours { get; set; }
}

public class DonationSummaryReportDto
{
    public int CampaignId { get; set; }
    public string CampaignTitle { get; set; } = string.Empty;
    public decimal GoalAmount { get; set; }
    public decimal RaisedAmount { get; set; }
    public int DonationCount { get; set; }
    public bool IsActive { get; set; }
    public decimal AverageDonation { get; set; }
}
