using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.Infrastructure.Services;

public class RabbitMQProducerService : IRabbitMQProducerService, IDisposable
{
    private readonly ILogger<RabbitMQProducerService> _logger;
    private readonly IConfiguration _configuration;
    private IConnection? _connection;
    private IChannel? _channel;
    private bool _initialized;

    public RabbitMQProducerService(ILogger<RabbitMQProducerService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    private async Task EnsureInitializedAsync()
    {
        if (_initialized && _channel != null) return;

        try
        {
            var factory = new ConnectionFactory
            {
                HostName = _configuration["RabbitMQ:Host"] ?? "localhost",
                Port = int.Parse(_configuration["RabbitMQ:Port"] ?? "5672"),
                UserName = _configuration["RabbitMQ:Username"] ?? "guest",
                Password = _configuration["RabbitMQ:Password"] ?? "guest"
            };

            _connection = await factory.CreateConnectionAsync();
            _channel = await _connection.CreateChannelAsync();

            await _channel.QueueDeclareAsync("email_notifications", durable: true, exclusive: false, autoDelete: false);
            await _channel.QueueDeclareAsync("shift_reminders", durable: true, exclusive: false, autoDelete: false);
            await _channel.QueueDeclareAsync("donation_notifications", durable: true, exclusive: false, autoDelete: false);

            _initialized = true;
            _logger.LogInformation("RabbitMQ producer connection established");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to connect to RabbitMQ producer. Messages will be logged only.");
        }
    }

    private async Task PublishAsync(string queue, object message)
    {
        await EnsureInitializedAsync();

        var json = JsonSerializer.Serialize(message);
        var body = Encoding.UTF8.GetBytes(json);

        if (_channel != null)
        {
            var properties = new BasicProperties { Persistent = true };
            await _channel.BasicPublishAsync("", queue, false, properties, body);
            _logger.LogInformation("Published message to queue {Queue}: {Message}", queue, json);
        }
        else
        {
            _logger.LogWarning("RabbitMQ not available. Would publish to {Queue}: {Message}", queue, json);
        }
    }

    public async Task PublishEmailNotificationAsync(string to, string subject, string body, bool isHtml = true)
    {
        await PublishAsync("email_notifications", new
        {
            To = to,
            Subject = subject,
            Body = body,
            IsHtml = isHtml
        });
    }

    public async Task PublishShiftReminderAsync(int userId, int shiftId, string userEmail, string shiftName, DateTime shiftStartTime)
    {
        await PublishAsync("shift_reminders", new
        {
            UserId = userId,
            ShiftId = shiftId,
            UserEmail = userEmail,
            ShiftName = shiftName,
            ShiftStartTime = shiftStartTime
        });
    }

    public async Task PublishDonationNotificationAsync(int campaignId, decimal amount, string currency, string? donorName, string? message)
    {
        await PublishAsync("donation_notifications", new
        {
            CampaignId = campaignId,
            Amount = amount,
            Currency = currency,
            DonorName = donorName,
            Message = message
        });
    }

    public void Dispose()
    {
        _channel?.Dispose();
        _connection?.Dispose();
    }
}
