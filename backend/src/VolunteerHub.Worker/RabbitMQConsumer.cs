using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;
using MailKit.Net.Smtp;
using MimeKit;
using Microsoft.EntityFrameworkCore;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Worker;

public class RabbitMQConsumer : BackgroundService
{
    private const int MaxRetryAttempts = 5;
    private static readonly string[] QueueNames =
    {
        "email_notifications",
        "user_notifications",
        "shift_reminders",
        "donation_notifications"
    };

    private readonly ILogger<RabbitMQConsumer> _logger;
    private readonly IConfiguration _configuration;
    private readonly IDbContextFactory<ApplicationDbContext> _dbContextFactory;
    private IConnection? _connection;
    private IChannel? _channel;

    public RabbitMQConsumer(
        ILogger<RabbitMQConsumer> logger,
        IConfiguration configuration,
        IDbContextFactory<ApplicationDbContext> dbContextFactory)
    {
        _logger = logger;
        _configuration = configuration;
        _dbContextFactory = dbContextFactory;
    }

    public override async Task StartAsync(CancellationToken cancellationToken)
    {
        await InitializeRabbitMQ();
        await base.StartAsync(cancellationToken);
    }

    private async Task InitializeRabbitMQ()
    {
        try
        {
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

            await _channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 10, global: false);

            _logger.LogInformation("RabbitMQ connection established successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to RabbitMQ. Will retry...");
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Wait for RabbitMQ to be ready
        while (_channel == null && !stoppingToken.IsCancellationRequested)
        {
            _logger.LogWarning("Waiting for RabbitMQ connection...");
            await Task.Delay(5000, stoppingToken);
            await InitializeRabbitMQ();
        }

        if (_channel == null) return;

        stoppingToken.ThrowIfCancellationRequested();

        // Set up consumers for each queue
        await SetupEmailConsumer(stoppingToken);
        await SetupUserNotificationConsumer(stoppingToken);
        await SetupShiftReminderConsumer(stoppingToken);
        await SetupDonationConsumer(stoppingToken);

        _logger.LogInformation("Worker started listening to queues");

        // Keep the service running
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(1000, stoppingToken);
        }
    }

    private async Task SetupEmailConsumer(CancellationToken stoppingToken)
    {
        if (_channel == null) return;

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += async (model, ea) =>
        {
            try
            {
                var body = ea.Body.ToArray();
                var message = Encoding.UTF8.GetString(body);
                var emailMessage = JsonSerializer.Deserialize<EmailMessage>(message);

                if (emailMessage == null)
                    throw new InvalidOperationException("Email message payload is invalid.");

                if (emailMessage != null)
                {
                    _logger.LogInformation("Processing email to: {Email}, Subject: {Subject}", 
                        emailMessage.To, emailMessage.Subject);

                    await SendEmailAsync(emailMessage);

                    await _channel.BasicAckAsync(ea.DeliveryTag, false);
                    _logger.LogInformation("Email sent successfully to {Email}", emailMessage.To);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing email message");
                await RetryOrDeadLetterAsync(ea, "email_notifications", ex, stoppingToken);
            }
        };

        await _channel.BasicConsumeAsync("email_notifications", false, consumer);
    }

    private async Task SetupShiftReminderConsumer(CancellationToken stoppingToken)
    {
        if (_channel == null) return;

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += async (model, ea) =>
        {
            try
            {
                var body = ea.Body.ToArray();
                var message = Encoding.UTF8.GetString(body);
                var reminder = JsonSerializer.Deserialize<ShiftReminderMessage>(message);

                if (reminder == null)
                    throw new InvalidOperationException("Shift reminder payload is invalid.");

                if (reminder != null)
                {
                    _logger.LogInformation("Processing shift reminder for user: {UserId}, shift: {ShiftId}", 
                        reminder.UserId, reminder.ShiftId);

                    // Create notification and send email
                    await ProcessShiftReminder(reminder);

                    await _channel.BasicAckAsync(ea.DeliveryTag, false);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing shift reminder");
                await RetryOrDeadLetterAsync(ea, "shift_reminders", ex, stoppingToken);
            }
        };

        await _channel.BasicConsumeAsync("shift_reminders", false, consumer);
    }

    private async Task SetupUserNotificationConsumer(CancellationToken stoppingToken)
    {
        if (_channel == null) return;

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += async (model, ea) =>
        {
            try
            {
                var body = ea.Body.ToArray();
                var message = Encoding.UTF8.GetString(body);
                var notification = JsonSerializer.Deserialize<UserNotificationMessage>(message);

                if (notification == null)
                    throw new InvalidOperationException("User notification payload is invalid.");

                if (notification != null)
                {
                    _logger.LogInformation(
                        "Processing user notification for user {UserId}: {Title}",
                        notification.UserId,
                        notification.Title);

                    if (notification.PersistInAppNotification && notification.UserId > 0)
                    {
                        await SaveNotificationAsync(notification, stoppingToken);
                    }

                    if (notification.SendEmail && !string.IsNullOrWhiteSpace(notification.Email))
                    {
                        await SendEmailAsync(new EmailMessage
                        {
                            To = notification.Email,
                            Subject = notification.EmailSubject ?? notification.Title,
                            Body = notification.EmailBody ?? $"<h2>{notification.Title}</h2><p>{notification.Message}</p>",
                            IsHtml = notification.IsEmailHtml
                        });
                    }

                    await _channel.BasicAckAsync(ea.DeliveryTag, false);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing user notification");
                await RetryOrDeadLetterAsync(ea, "user_notifications", ex, stoppingToken);
            }
        };

        await _channel.BasicConsumeAsync("user_notifications", false, consumer);
    }

    private async Task SetupDonationConsumer(CancellationToken stoppingToken)
    {
        if (_channel == null) return;

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += async (model, ea) =>
        {
            try
            {
                var body = ea.Body.ToArray();
                var message = Encoding.UTF8.GetString(body);
                var donation = JsonSerializer.Deserialize<DonationNotificationMessage>(message);

                if (donation == null)
                    throw new InvalidOperationException("Donation notification payload is invalid.");

                if (donation != null)
                {
                    _logger.LogInformation("Processing donation notification for campaign: {CampaignId}", 
                        donation.CampaignId);

                    // Notify campaign creator
                    await ProcessDonationNotification(donation);

                    await _channel.BasicAckAsync(ea.DeliveryTag, false);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing donation notification");
                await RetryOrDeadLetterAsync(ea, "donation_notifications", ex, stoppingToken);
            }
        };

        await _channel.BasicConsumeAsync("donation_notifications", false, consumer);
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

    private async Task RetryOrDeadLetterAsync(BasicDeliverEventArgs ea, string queue, Exception exception, CancellationToken stoppingToken)
    {
        if (_channel == null) return;

        var retryCount = GetRetryCount(ea.BasicProperties.Headers);
        if (retryCount >= MaxRetryAttempts)
        {
            var dlqProperties = new BasicProperties
            {
                Persistent = true,
                Headers = new Dictionary<string, object?>
                {
                    ["x-retry-count"] = retryCount,
                    ["x-error-message"] = exception.Message
                }
            };

            await _channel.BasicPublishAsync(
                exchange: string.Empty,
                routingKey: $"{queue}.dlq",
                mandatory: false,
                basicProperties: dlqProperties,
                body: ea.Body,
                cancellationToken: stoppingToken);
            await _channel.BasicAckAsync(ea.DeliveryTag, false, stoppingToken);
            _logger.LogError("Message from queue {Queue} moved to DLQ after {RetryCount} retries", queue, retryCount);
            return;
        }

        var nextRetryCount = retryCount + 1;
        var delay = TimeSpan.FromSeconds(Math.Min(60, Math.Pow(2, nextRetryCount)));
        _logger.LogWarning("Retrying message from queue {Queue}. Attempt {Retry}/{MaxRetry} after {DelaySeconds}s",
            queue,
            nextRetryCount,
            MaxRetryAttempts,
            delay.TotalSeconds);

        await Task.Delay(delay, stoppingToken);

        var retryProperties = new BasicProperties
        {
            Persistent = true,
            Headers = new Dictionary<string, object?>
            {
                ["x-retry-count"] = nextRetryCount
            }
        };

        await _channel.BasicPublishAsync(
            exchange: string.Empty,
            routingKey: queue,
            mandatory: false,
            basicProperties: retryProperties,
            body: ea.Body,
            cancellationToken: stoppingToken);
        await _channel.BasicAckAsync(ea.DeliveryTag, false, stoppingToken);
    }

    private static int GetRetryCount(IDictionary<string, object?>? headers)
    {
        if (headers == null || !headers.TryGetValue("x-retry-count", out var value) || value == null)
            return 0;

        return value switch
        {
            int intValue => intValue,
            long longValue => (int)longValue,
            byte[] bytes when int.TryParse(Encoding.UTF8.GetString(bytes), out var parsed) => parsed,
            string stringValue when int.TryParse(stringValue, out var parsed) => parsed,
            _ => 0
        };
    }

    private string GetRequiredConfiguration(string key)
    {
        var value = _configuration[key];
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Missing required configuration value: {key}");

        return value;
    }

    private async Task SendEmailAsync(EmailMessage email)
    {
        try
        {
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(
                _configuration["Smtp:FromName"] ?? "VolunteerHub",
                _configuration["Smtp:FromEmail"] ?? "noreply@volunteerhub.ba"));
            message.To.Add(MailboxAddress.Parse(email.To));
            message.Subject = email.Subject;

            var builder = new BodyBuilder();
            if (email.IsHtml)
                builder.HtmlBody = email.Body;
            else
                builder.TextBody = email.Body;
            message.Body = builder.ToMessageBody();

            using var client = new SmtpClient();
            var host = _configuration["Smtp:Host"] ?? "mailhog";
            var port = int.Parse(_configuration["Smtp:Port"] ?? "1025");
            var useSsl = bool.Parse(_configuration["Smtp:UseSsl"] ?? "false");

            await client.ConnectAsync(host, port, useSsl ? MailKit.Security.SecureSocketOptions.StartTls : MailKit.Security.SecureSocketOptions.None);

            var username = _configuration["Smtp:Username"];
            var password = _configuration["Smtp:Password"];
            if (!string.IsNullOrWhiteSpace(username) && !string.IsNullOrWhiteSpace(password))
                await client.AuthenticateAsync(username, password);

            await client.SendAsync(message);
            await client.DisconnectAsync(true);

            _logger.LogInformation("Email sent to {To}: {Subject}", email.To, email.Subject);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email to {To}", email.To);
            throw;
        }
    }

    private async Task ProcessShiftReminder(ShiftReminderMessage reminder)
    {
        _logger.LogInformation("Processing shift reminder for shift {ShiftId}", reminder.ShiftId);
        await SendEmailAsync(new EmailMessage
        {
            To = reminder.UserEmail,
            Subject = $"Podsjetnik: Smjena '{reminder.ShiftName}' uskoro pocinje",
            Body = $"<h2>Podsjetnik na smjenu</h2><p>Vasa smjena <strong>{reminder.ShiftName}</strong> pocinje u {reminder.ShiftStartTime:dd.MM.yyyy HH:mm}.</p><p>Ne zaboravite se prijaviti (check-in) na vrijeme!</p>",
            IsHtml = true
        });
    }

    private async Task ProcessDonationNotification(DonationNotificationMessage donation)
    {
        _logger.LogInformation("Processing donation notification: {Amount} {Currency}", donation.Amount, donation.Currency);
        var donorDisplay = string.IsNullOrEmpty(donation.DonorName) ? "Anonimni donator" : donation.DonorName;
        await SendEmailAsync(new EmailMessage
        {
            To = _configuration["Smtp:FromEmail"] ?? "noreply@volunteerhub.ba",
            Subject = $"Nova donacija: {donation.Amount} {donation.Currency}",
            Body = $"<h2>Nova donacija primljena</h2><p><strong>{donorDisplay}</strong> je donirao/la {donation.Amount} {donation.Currency} za kampanju #{donation.CampaignId}.</p>" +
                   (string.IsNullOrEmpty(donation.Message) ? "" : $"<p>Poruka: <em>{donation.Message}</em></p>"),
            IsHtml = true
        });
    }

    private async Task SaveNotificationAsync(UserNotificationMessage message, CancellationToken stoppingToken)
    {
        await using var db = await _dbContextFactory.CreateDbContextAsync(stoppingToken);

        var type = Enum.TryParse<NotificationType>(message.Type, out var parsedType)
            ? parsedType
            : NotificationType.General;

        db.Notifications.Add(new Notification
        {
            UserId = message.UserId,
            Title = message.Title,
            Message = message.Message,
            Type = type,
            ActionUrl = message.ActionUrl,
            EventId = message.EventId,
            ShiftId = message.ShiftId,
            CampaignId = message.CampaignId,
            IsRead = false,
            ReadAt = null
        });

        await db.SaveChangesAsync(stoppingToken);
        _logger.LogInformation("Stored in-app notification for user {UserId}: {Title}", message.UserId, message.Title);
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_channel != null)
        {
            await _channel.CloseAsync();
        }
        if (_connection != null)
        {
            await _connection.CloseAsync();
        }
        await base.StopAsync(cancellationToken);
    }
}

// Message DTOs
public class EmailMessage
{
    public string To { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public bool IsHtml { get; set; } = true;
}

public class ShiftReminderMessage
{
    public int UserId { get; set; }
    public int ShiftId { get; set; }
    public string UserEmail { get; set; } = string.Empty;
    public string ShiftName { get; set; } = string.Empty;
    public DateTime ShiftStartTime { get; set; }
}

public class DonationNotificationMessage
{
    public int CampaignId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "BAM";
    public string? DonorName { get; set; }
    public string? Message { get; set; }
}
