using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;
using Stripe;

namespace VolunteerHub.API.Security;

public static class StripeWebhookAuthenticationDefaults
{
    public const string AuthenticationScheme = "StripeWebhook";
}

public class StripeWebhookAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<StripeWebhookAuthenticationHandler> _logger;

    public StripeWebhookAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        IConfiguration configuration)
        : base(options, logger, encoder)
    {
        _configuration = configuration;
        _logger = logger.CreateLogger<StripeWebhookAuthenticationHandler>();
    }

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var webhookSecret = GetStripeSetting("WebhookSecret", "STRIPE_WEBHOOK_SECRET");
        if (string.IsNullOrWhiteSpace(webhookSecret))
            return AuthenticateResult.Fail("Stripe webhook secret is not configured.");

        var signature = Request.Headers["Stripe-Signature"].ToString();
        if (string.IsNullOrWhiteSpace(signature))
            return AuthenticateResult.Fail("Missing Stripe-Signature header.");

        Request.EnableBuffering();
        string payload;
        using (var reader = new StreamReader(Request.Body, Encoding.UTF8, leaveOpen: true))
        {
            payload = await reader.ReadToEndAsync();
            Request.Body.Position = 0;
        }

        try
        {
            EventUtility.ConstructEvent(payload, signature, webhookSecret);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Stripe webhook authentication failed.");
            return AuthenticateResult.Fail("Invalid Stripe webhook signature.");
        }

        var identity = new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, "stripe-webhook")],
            StripeWebhookAuthenticationDefaults.AuthenticationScheme);
        var principal = new ClaimsPrincipal(identity);
        return AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name));
    }

    private string? GetStripeSetting(string key, string environmentKey)
    {
        var configuredValue = _configuration[$"Stripe:{key}"];
        return !string.IsNullOrWhiteSpace(configuredValue) && !configuredValue.Contains("your_", StringComparison.OrdinalIgnoreCase)
            ? configuredValue
            : Environment.GetEnvironmentVariable(environmentKey);
    }
}
