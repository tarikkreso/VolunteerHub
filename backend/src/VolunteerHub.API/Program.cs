using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using VolunteerHub.API.Contracts;
using VolunteerHub.Application;
using VolunteerHub.Infrastructure;
using VolunteerHub.Infrastructure.Data;

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
});

builder.Services.AddAuthorization();

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
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
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

app.UseCors("AllowAll");
app.UseStaticFiles();

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
    if (string.IsNullOrWhiteSpace(configuration["Stripe:SecretKey"]))
        throw new InvalidOperationException("Stripe:SecretKey is not configured.");
}
