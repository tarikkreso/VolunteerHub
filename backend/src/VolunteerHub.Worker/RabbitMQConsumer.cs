using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;
using MailKit.Net.Smtp;
using MimeKit;

namespace VolunteerHub.Worker;

public class RabbitMQConsumer : BackgroundService
{
    private readonly ILogger<RabbitMQConsumer> _logger;
    private readonly IConfiguration _configuration;
    private IConnection? _connection;
    private IChannel? _channel;

    public RabbitMQConsumer(ILogger<RabbitMQConsumer> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
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
                UserName = _configuration["RabbitMQ:Username"] ?? "guest",
                Password = _configuration["RabbitMQ:Password"] ?? "guest"
            };

            _connection = await factory.CreateConnectionAsync();
            _channel = await _connection.CreateChannelAsync();

            // Declare queues
            await _channel.QueueDeclareAsync(
                queue: "email_notifications",
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null);

            await _channel.QueueDeclareAsync(
                queue: "shift_reminders",
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null);

            await _channel.QueueDeclareAsync(
                queue: "donation_notifications",
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null);

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
                await _channel.BasicNackAsync(ea.DeliveryTag, false, true);
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
                await _channel.BasicNackAsync(ea.DeliveryTag, false, true);
            }
        };

        await _channel.BasicConsumeAsync("shift_reminders", false, consumer);
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
                await _channel.BasicNackAsync(ea.DeliveryTag, false, true);
            }
        };

        await _channel.BasicConsumeAsync("donation_notifications", false, consumer);
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
        }
    }

    private async Task ProcessShiftReminder(ShiftReminderMessage reminder)
    {
        _logger.LogInformation("Processing shift reminder for shift {ShiftId}", reminder.ShiftId);
        await SendEmailAsync(new EmailMessage
        {
            To = reminder.UserEmail,
            Subject = $"Podsjetnik: Smjena '{reminder.ShiftName}' uskoro počinje",
            Body = $"<h2>Podsjetnik na smjenu</h2><p>Vaša smjena <strong>{reminder.ShiftName}</strong> počinje u {reminder.ShiftStartTime:dd.MM.yyyy HH:mm}.</p><p>Ne zaboravite se prijaviti (check-in) na vrijeme!</p>",
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
