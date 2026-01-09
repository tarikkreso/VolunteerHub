using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IUserSkillService
{
    Task<List<UserSkillDto>> GetByUserAsync(int userId);
    Task<UserSkillDto> AddAsync(int userId, int skillId, int proficiencyLevel = 3, int yearsExperience = 0);
    Task<bool> RemoveAsync(int userId, int skillId);
    Task<bool> ToggleVerifiedAsync(int userSkillId);
}
