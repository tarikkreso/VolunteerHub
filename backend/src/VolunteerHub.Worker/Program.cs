using VolunteerHub.Worker;

var builder = Host.CreateApplicationBuilder(args);

ValidateConfiguration(builder.Configuration);

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

	if (string.IsNullOrWhiteSpace(configuration["Smtp:Host"]))
		throw new InvalidOperationException("Smtp:Host is not configured.");
	if (!int.TryParse(configuration["Smtp:Port"], out _))
		throw new InvalidOperationException("Smtp:Port is not configured correctly.");
	if (string.IsNullOrWhiteSpace(configuration["Smtp:FromEmail"]))
		throw new InvalidOperationException("Smtp:FromEmail is not configured.");
	if (string.IsNullOrWhiteSpace(configuration["Smtp:FromName"]))
		throw new InvalidOperationException("Smtp:FromName is not configured.");
}
