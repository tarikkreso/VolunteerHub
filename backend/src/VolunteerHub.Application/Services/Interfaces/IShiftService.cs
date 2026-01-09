using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IShiftService
{
    Task<List<ShiftDto>> GetByEventAsync(int eventId);
    Task<ShiftDto?> GetByIdAsync(int id);
    Task<ShiftDto> CreateAsync(ShiftCreateDto dto);
    Task<bool> UpdateAsync(int id, ShiftCreateDto dto);
    Task<bool> DeleteAsync(int id);
}
