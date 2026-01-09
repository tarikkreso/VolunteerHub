using VolunteerHub.Application.DTOs;

namespace VolunteerHub.Application.Services.Interfaces;

public interface IReportService
{
    Task<List<VolunteerParticipationReportDto>> GetVolunteerParticipationAsync(DateTime? from, DateTime? to);
    Task<List<HoursByVolunteerReportDto>> GetHoursByVolunteerAsync(DateTime? from, DateTime? to);
    Task<List<EventAttendanceReportDto>> GetEventAttendanceAsync(DateTime? from, DateTime? to);
    Task<List<DonationSummaryReportDto>> GetDonationsSummaryAsync(DateTime? from, DateTime? to);
}
