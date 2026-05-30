using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using VolunteerHub.Application.Services.Interfaces;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Interfaces;
using VolunteerHub.Infrastructure.Data;
using VolunteerHub.Infrastructure.Repositories;
using VolunteerHub.Infrastructure.Services;

namespace VolunteerHub.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseSqlServer(
                configuration.GetConnectionString("DefaultConnection"),
                b => b.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName)));

        services.AddIdentityCore<ApplicationUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                // Course demo credentials use password "test"; DTO validation is aligned to the same minimum.
                options.Password.RequiredLength = 4;
                options.Password.RequireDigit = false;
                options.Password.RequireLowercase = false;
                options.Password.RequireUppercase = false;
                options.Password.RequireNonAlphanumeric = false;
            })
            .AddRoles<IdentityRole<int>>()
            .AddSignInManager<SignInManager<ApplicationUser>>()
            .AddEntityFrameworkStores<ApplicationDbContext>()
            .AddDefaultTokenProviders();

        services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
        services.AddScoped<IUnitOfWork, UnitOfWork>();

        services.AddSingleton<IRabbitMQProducerService, RabbitMQProducerService>();

        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IEventService, EventService>();
        services.AddScoped<IOrganizationService, OrganizationService>();
        services.AddScoped<IEventRegistrationService, EventRegistrationService>();
        services.AddScoped<IVolunteerHistoryService, VolunteerHistoryService>();
        services.AddScoped<IShiftService, ShiftService>();
        services.AddScoped<IShiftRegistrationService, ShiftRegistrationService>();
        services.AddScoped<IUserService, UserService>();
        services.AddScoped<ICampaignService, CampaignService>();
        services.AddScoped<IDonationService, DonationService>();
        services.AddScoped<IBlogPostService, BlogPostService>();
        services.AddScoped<ILeaderboardService, LeaderboardService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IUserSkillService, UserSkillService>();
        services.AddScoped<IReferenceDataService, ReferenceDataService>();
        services.AddScoped<IDashboardService, DashboardService>();
        services.AddScoped<IReportService, ReportService>();
        services.AddScoped<IRecommendationService, RecommendationService>();

        return services;
    }
}
