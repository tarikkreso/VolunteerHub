using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using VolunteerHub.API.Contracts;
using VolunteerHub.API.Middleware;
using VolunteerHub.API.Security;
using VolunteerHub.Application;
using VolunteerHub.Infrastructure;
using VolunteerHub.Infrastructure.Data;

LoadDotEnv();
var builder = WebApplication.CreateBuilder(args);

// Keep startup logging container- and local-friendly; Windows Event Log can fail
// in non-elevated/dev environments and block the app before migration/seeding.
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

builder.Services.AddControllers();
builder.Services.Configure<ApiBehaviorOptions>(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var errors = context.ModelState
            .Where(x => x.Value?.Errors.Count > 0)
            .ToDictionary(
                kvp => kvp.Key,
                kvp => kvp.Value!.Errors
                    .Select(e => string.IsNullOrWhiteSpace(e.ErrorMessage)
                        ? "Neispravan unos."
                        : e.ErrorMessage)
                    .Distinct()
                    .ToArray());

        return new BadRequestObjectResult(new ValidationErrorResponse
        {
            Message = "Molimo ispravite oznacena polja.",
            Errors = errors
        });
    };
});
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddHttpContextAccessor();

ValidateConfiguration(builder.Configuration);

var jwtKey = builder.Configuration["Jwt:Key"] ?? throw new InvalidOperationException("JWT Key not configured");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
    };
})
.AddScheme<AuthenticationSchemeOptions, StripeWebhookAuthenticationHandler>(
    StripeWebhookAuthenticationDefaults.AuthenticationScheme,
    _ => { });

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "VolunteerHub API",
        Version = "v1",
        Description = "API for VolunteerHub - Volunteer Management Platform",
        Contact = new OpenApiContact
        {
            Name = "Tarik Kreso",
            Email = "tarik@volunteerhub.ba"
        }
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token in the text input below.",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("VolunteerHubClients", policy =>
    {
        var allowedOrigins = builder.Configuration
            .GetSection("Cors:AllowedOrigins")
            .Get<string[]>()
            ?.Where(origin => !string.IsNullOrWhiteSpace(origin))
            .ToArray() ?? Array.Empty<string>();

        if (allowedOrigins.Length == 0)
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must contain at least one allowed client URL.");
        }

        policy.WithOrigins(allowedOrigins)
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});

builder.Services.AddHealthChecks()
    .AddDbContextCheck<ApplicationDbContext>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await context.Database.MigrateAsync();
    await DatabaseSeeder.SeedAsync(scope.ServiceProvider, context);
}

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "VolunteerHub API v1");
    c.RoutePrefix = "swagger";
});

app.UseCors("VolunteerHubClients");
app.UseStaticFiles();
app.UseMiddleware<ExceptionHandlingMiddleware>();

if (builder.Configuration.GetValue("App:UseHttpsRedirection", false))
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");

app.Run();

static void ValidateConfiguration(IConfiguration configuration)
{
    if (string.IsNullOrWhiteSpace(configuration.GetConnectionString("DefaultConnection")))
        throw new InvalidOperationException("ConnectionStrings:DefaultConnection is not configured.");
    if (string.IsNullOrWhiteSpace(configuration["Jwt:Key"]))
        throw new InvalidOperationException("Jwt:Key is not configured.");
    if (string.IsNullOrWhiteSpace(configuration["Jwt:Issuer"]))
        throw new InvalidOperationException("Jwt:Issuer is not configured.");
    if (string.IsNullOrWhiteSpace(configuration["Jwt:Audience"]))
        throw new InvalidOperationException("Jwt:Audience is not configured.");
    if (string.IsNullOrWhiteSpace(configuration["RabbitMQ:Host"]))
        throw new InvalidOperationException("RabbitMQ:Host is not configured.");
    if (string.IsNullOrWhiteSpace(configuration["Smtp:Host"]))
        throw new InvalidOperationException("Smtp:Host is not configured.");
    if (!int.TryParse(configuration["Smtp:Port"], out _))
        throw new InvalidOperationException("Smtp:Port is not configured correctly.");
}

static void LoadDotEnv()
{
    var envPath = FindDotEnv(Directory.GetCurrentDirectory()) ?? FindDotEnv(AppContext.BaseDirectory);
    if (!File.Exists(envPath))
    {
        return;
    }

    foreach (var rawLine in File.ReadAllLines(envPath))
    {
        var line = rawLine.Trim();
        if (line.Length == 0 || line.StartsWith('#'))
        {
            continue;
        }

        var separatorIndex = line.IndexOf('=');
        if (separatorIndex <= 0)
        {
            continue;
        }

        var key = line[..separatorIndex].Trim();
        var value = line[(separatorIndex + 1)..].Trim().Trim('"');
        if (string.IsNullOrWhiteSpace(key) || Environment.GetEnvironmentVariable(key) != null)
        {
            continue;
        }

        Environment.SetEnvironmentVariable(key, value);
    }

    ApplyDerivedConfigurationFromDotEnv();
}

static void ApplyDerivedConfigurationFromDotEnv()
{
    SetFromEnvironment("Jwt__Key", "JWT_KEY");
    SetFromEnvironment("Jwt__Issuer", "JWT_ISSUER");
    SetFromEnvironment("Jwt__Audience", "JWT_AUDIENCE");
    SetFromEnvironment("RabbitMQ__Username", "RABBITMQ_USER");
    SetFromEnvironment("RabbitMQ__Password", "RABBITMQ_PASSWORD");
    SetFromEnvironment("RabbitMQ__Port", "RABBITMQ_PORT");
    SetFromEnvironment("Stripe__SecretKey", "STRIPE_SECRET_KEY");
    SetFromEnvironment("Stripe__PublishableKey", "STRIPE_PUBLISHABLE_KEY");
    SetFromEnvironment("Stripe__WebhookSecret", "STRIPE_WEBHOOK_SECRET");
    SetFromEnvironment("Smtp__Host", "SMTP_HOST");
    SetFromEnvironment("Smtp__Port", "SMTP_PORT");
    SetFromEnvironment("Smtp__Username", "SMTP_USERNAME");
    SetFromEnvironment("Smtp__Password", "SMTP_PASSWORD");
    SetFromEnvironment("Smtp__UseSsl", "SMTP_USE_SSL");
    SetFromEnvironment("Smtp__FromEmail", "SMTP_FROM_EMAIL");
    SetFromEnvironment("Smtp__FromName", "SMTP_FROM_NAME");

    if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")))
    {
        var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD");
        if (!string.IsNullOrWhiteSpace(dbPassword))
        {
            var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "localhost,1433";
            var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "220193";
            var dbUser = Environment.GetEnvironmentVariable("DB_USER") ?? "sa";
            Environment.SetEnvironmentVariable(
                "ConnectionStrings__DefaultConnection",
                $"Server={dbHost};Database={dbName};User Id={dbUser};Password={dbPassword};TrustServerCertificate=True;Encrypt=False;");
        }
    }
}

static void SetFromEnvironment(string targetKey, string sourceKey)
{
    if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(targetKey)))
        return;

    var value = Environment.GetEnvironmentVariable(sourceKey);
    if (!string.IsNullOrWhiteSpace(value))
    {
        Environment.SetEnvironmentVariable(targetKey, value);
    }
}

static string? FindDotEnv(string startDirectory)
{
    var directory = new DirectoryInfo(startDirectory);
    while (directory != null)
    {
        var candidate = Path.Combine(directory.FullName, ".env");
        if (File.Exists(candidate))
        {
            return candidate;
        }

        directory = directory.Parent;
    }

    return null;
}
