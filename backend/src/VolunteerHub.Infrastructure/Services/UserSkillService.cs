using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure.Services;

public class UserSkillService : IUserSkillService
{
    private readonly ApplicationDbContext _context;

    public UserSkillService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<UserSkillDto>> GetByUserAsync(int userId)
    {
        return await _context.UserSkills
            .Include(us => us.Skill)
            .Where(us => us.UserId == userId)
            .OrderBy(us => us.Skill.Name)
            .Take(100)
            .Select(us => new UserSkillDto
            {
                Id = us.Id,
                SkillId = us.SkillId,
                SkillName = us.Skill.Name,
                ProficiencyLevel = us.ProficiencyLevel,
                YearsExperience = us.YearsExperience,
                IsVerified = us.IsVerified,
                CreatedAt = us.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<UserSkillDto> AddAsync(int userId, int skillId, int proficiencyLevel = 3, int yearsExperience = 0)
    {
        var existing = await _context.UserSkills
            .FirstOrDefaultAsync(us => us.UserId == userId && us.SkillId == skillId);

        if (existing != null)
            throw new InvalidOperationException("Korisnik već ima ovu vještinu.");

        var userSkill = new UserSkill
        {
            UserId = userId,
            SkillId = skillId,
            ProficiencyLevel = proficiencyLevel,
            YearsExperience = yearsExperience,
            IsVerified = false
        };

        _context.UserSkills.Add(userSkill);
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            ActionType = "SkillAdded",
            Description = "Korisnik je dodao novu vještinu na profil.",
            OccurredAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        return await _context.UserSkills
            .Include(us => us.Skill)
            .Where(us => us.Id == userSkill.Id)
            .Select(us => new UserSkillDto
            {
                Id = us.Id,
                SkillId = us.SkillId,
                SkillName = us.Skill.Name,
                ProficiencyLevel = us.ProficiencyLevel,
                YearsExperience = us.YearsExperience,
                IsVerified = us.IsVerified,
                CreatedAt = us.CreatedAt
            })
            .FirstAsync();
    }

    public async Task<bool> RemoveAsync(int userId, int skillId)
    {
        var userSkill = await _context.UserSkills
            .FirstOrDefaultAsync(us => us.UserId == userId && us.SkillId == skillId);

        if (userSkill == null) return false;

        _context.UserSkills.Remove(userSkill);
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userId,
            ActionType = "SkillRemoved",
            Description = "Korisnik je uklonio vještinu sa profila.",
            OccurredAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ToggleVerifiedAsync(int userSkillId)
    {
        var userSkill = await _context.UserSkills.FindAsync(userSkillId);
        if (userSkill == null) return false;

        userSkill.IsVerified = !userSkill.IsVerified;
        _context.VolunteerHistories.Add(new VolunteerHistory
        {
            UserId = userSkill.UserId,
            ActionType = "SkillVerificationChanged",
            Description = userSkill.IsVerified
                ? "Vještina je označena kao verificirana."
                : "Verifikacija vještine je uklonjena.",
            OccurredAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();
        return true;
    }
}
