using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IShiftRegistrationService
{
    Task<ShiftRegistrationDto> RegisterAsync(int shiftId, int userId);
    Task<ShiftRegistrationDto> CheckInAsync(int shiftId, int userId);
    Task<ShiftRegistrationDto> CheckOutAsync(int shiftId, int userId);
    Task<ShiftRegistrationDto> CancelAsync(int registrationId, int userId, string reason);
    Task<List<ShiftRegistrationDto>> GetByShiftAsync(int shiftId);
    Task<PagedResultDto<ShiftRegistrationDto>> GetByUserAsync(int userId, SearchRequestDto request);
    Task<ShiftRegistrationDto> ApproveAsync(int registrationId, double? approvedHours, string? adminNotes, int adminId);
    Task<ShiftRegistrationDto> RejectAsync(int registrationId, string? adminNotes, int adminId);
    Task<bool> FinalApprovalAsync(int shiftId, int adminId);
    Task<List<ShiftRegistrationDto>> ApproveAllAsync(int shiftId, string? adminNotes, int adminId);
}
