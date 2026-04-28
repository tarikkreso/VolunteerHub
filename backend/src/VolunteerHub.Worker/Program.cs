using Microsoft.EntityFrameworkCore;
using VolunteerHub.Infrastructure.Data;
using VolunteerHub.Worker;

LoadDotEnv();
var builder = Host.CreateApplicationBuilder(args);

ValidateConfiguration(builder.Configuration);

builder.Services.AddDbContextFactory<ApplicationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        b => b.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName)));

// Add RabbitMQ Consumer as hosted service
builder.Services.AddHostedService<RabbitMQConsumer>();

var host = builder.Build();
host.Run();

static void ValidateConfiguration(IConfiguration configuration)
{
	if (string.IsNullOrWhiteSpace(configuration["RabbitMQ:Host"]))
		throw new InvalidOperationException("RabbitMQ:Host is not configured.");
	if (!int.TryParse(configuration["RabbitMQ:Port"], out _))
		throw new InvalidOperationException("RabbitMQ:Port is not configured correctly.");
	if (string.IsNullOrWhiteSpace(configuration["RabbitMQ:Username"]))
		throw new InvalidOperationException("RabbitMQ:Username is not configured.");
	if (string.IsNullOrWhiteSpace(configuration["RabbitMQ:Password"]))
		throw new InvalidOperationException("RabbitMQ:Password is not configured.");
	if (string.IsNullOrWhiteSpace(configuration.GetConnectionString("DefaultConnection")))
		throw new InvalidOperationException("ConnectionStrings:DefaultConnection is not configured.");

	if (string.IsNullOrWhiteSpace(configuration["Smtp:Host"]))
		throw new InvalidOperationException("Smtp:Host is not configured.");
	if (!int.TryParse(configuration["Smtp:Port"], out _))
		throw new InvalidOperationException("Smtp:Port is not configured correctly.");
	if (string.IsNullOrWhiteSpace(configuration["Smtp:FromEmail"]))
		throw new InvalidOperationException("Smtp:FromEmail is not configured.");
	if (string.IsNullOrWhiteSpace(configuration["Smtp:FromName"]))
		throw new InvalidOperationException("Smtp:FromName is not configured.");
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
	SetFromEnvironment("RabbitMQ__Username", "RABBITMQ_USER");
	SetFromEnvironment("RabbitMQ__Password", "RABBITMQ_PASSWORD");
	SetFromEnvironment("RabbitMQ__Port", "RABBITMQ_PORT");
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
