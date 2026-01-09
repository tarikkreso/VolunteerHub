using Microsoft.Extensions.DependencyInjection;

namespace VolunteerHub.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        return services;
    }
}
