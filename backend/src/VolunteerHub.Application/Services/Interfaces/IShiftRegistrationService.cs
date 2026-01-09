using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IShiftRegistrationService
{
    Task<ShiftRegistrationDto> RegisterAsync(int shiftId, int userId);
    Task<ShiftRegistrationDto> CheckInAsync(int shiftId, int userId);
    Task<ShiftRegistrationDto> CheckOutAsync(int shiftId, int userId);
    Task<List<ShiftRegistrationDto>> GetByShiftAsync(int shiftId);
    Task<List<ShiftRegistrationDto>> GetByUserAsync(int userId);
    Task<ShiftRegistrationDto> ApproveAsync(int registrationId, double? approvedHours, string? adminNotes);
    Task<ShiftRegistrationDto> RejectAsync(int registrationId, string? adminNotes);
    Task<bool> FinalApprovalAsync(int shiftId);
    Task<List<ShiftRegistrationDto>> ApproveAllAsync(int shiftId, string? adminNotes);
}
