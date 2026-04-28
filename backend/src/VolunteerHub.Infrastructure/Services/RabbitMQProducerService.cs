using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.Infrastructure.Services;

public class RabbitMQProducerService : IRabbitMQProducerService, IDisposable
{
    private static readonly string[] QueueNames =
    {
        "email_notifications",
        "user_notifications",
        "shift_reminders",
        "donation_notifications"
    };

    private readonly ILogger<RabbitMQProducerService> _logger;
    private readonly IConfiguration _configuration;
    private readonly SemaphoreSlim _channelLock = new(1, 1);
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

        await _channelLock.WaitAsync();
        try
        {
            if (_initialized && _channel != null) return;

            var factory = new ConnectionFactory
            {
                HostName = _configuration["RabbitMQ:Host"] ?? "localhost",
                Port = int.Parse(_configuration["RabbitMQ:Port"] ?? "5672"),
                UserName = GetRequiredConfiguration("RabbitMQ:Username"),
                Password = GetRequiredConfiguration("RabbitMQ:Password"),
                AutomaticRecoveryEnabled = true,
                NetworkRecoveryInterval = TimeSpan.FromSeconds(10)
            };

            _connection = await factory.CreateConnectionAsync();
            _channel = await _connection.CreateChannelAsync();

            foreach (var queue in QueueNames)
            {
                await DeclareQueueWithDeadLetterAsync(queue);
            }

            _initialized = true;
            _logger.LogInformation("RabbitMQ producer connection established");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to connect to RabbitMQ producer. Messages will be logged only.");
        }
        finally
        {
            _channelLock.Release();
        }
    }

    private async Task PublishAsync(string queue, object message)
    {
        await EnsureInitializedAsync();

        var json = JsonSerializer.Serialize(message);
        var body = Encoding.UTF8.GetBytes(json);

        if (_channel != null)
        {
            await _channelLock.WaitAsync();
            try
            {
                var properties = new BasicProperties { Persistent = true };
                await _channel.BasicPublishAsync("", queue, false, properties, body);
                _logger.LogInformation("Published message to queue {Queue}: {Message}", queue, json);
            }
            finally
            {
                _channelLock.Release();
            }
        }
        else
        {
            _logger.LogWarning("RabbitMQ not available. Would publish to {Queue}: {Message}", queue, json);
        }
    }

    private async Task DeclareQueueWithDeadLetterAsync(string queue)
    {
        if (_channel == null) return;

        await _channel.QueueDeclareAsync(
            queue: $"{queue}.dlq",
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: null);

        await _channel.QueueDeclareAsync(
            queue: queue,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: new Dictionary<string, object?>
            {
                ["x-dead-letter-exchange"] = string.Empty,
                ["x-dead-letter-routing-key"] = $"{queue}.dlq"
            });
    }

    private string GetRequiredConfiguration(string key)
    {
        var value = _configuration[key];
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Missing required configuration value: {key}");

        return value;
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

    public async Task PublishUserNotificationAsync(UserNotificationMessage message)
    {
        await PublishAsync("user_notifications", message);
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
        _channelLock.Dispose();
        _channel?.Dispose();
        _connection?.Dispose();
    }
}
