using System.Globalization;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Stripe;
using VolunteerHub.API.Security;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/webhooks/stripe")]
[Authorize(AuthenticationSchemes = StripeWebhookAuthenticationDefaults.AuthenticationScheme)]
public class StripeWebhooksController : ControllerBase
{
    private readonly IDonationService _donationService;
    private readonly IConfiguration _configuration;
    private readonly ILogger<StripeWebhooksController> _logger;

    public StripeWebhooksController(
        IDonationService donationService,
        IConfiguration configuration,
        ILogger<StripeWebhooksController> logger)
    {
        _donationService = donationService;
        _configuration = configuration;
        _logger = logger;
    }

    [HttpPost]
    public async Task<IActionResult> Receive()
    {
        var webhookSecret = GetStripeSetting("WebhookSecret", "STRIPE_WEBHOOK_SECRET");
        var signature = Request.Headers["Stripe-Signature"].ToString();

        string payload;
        using (var reader = new StreamReader(Request.Body, Encoding.UTF8))
        {
            payload = await reader.ReadToEndAsync();
        }

        Event stripeEvent;
        try
        {
            stripeEvent = EventUtility.ConstructEvent(payload, signature, webhookSecret);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Stripe webhook payload could not be parsed after authentication.");
            return BadRequest(new { message = "Neispravan Stripe webhook payload." });
        }

        switch (stripeEvent.Type)
        {
            case "payment_intent.succeeded":
                await HandlePaymentIntentSucceededAsync(stripeEvent);
                break;
            case "refund.created":
            case "refund.updated":
                await HandleRefundEventAsync(stripeEvent);
                break;
            case "refund.failed":
                await HandleRefundFailedEventAsync(stripeEvent);
                break;
            default:
                _logger.LogInformation("Ignoring Stripe webhook event type {EventType}", stripeEvent.Type);
                break;
        }

        return Ok(new { received = true });
    }

    private async Task HandlePaymentIntentSucceededAsync(Event stripeEvent)
    {
        if (stripeEvent.Data.Object is not PaymentIntent paymentIntent)
        {
            _logger.LogWarning("Webhook event {EventId} did not contain a PaymentIntent object.", stripeEvent.Id);
            return;
        }

        if (!TryGetCampaignId(paymentIntent, out var campaignId))
        {
            _logger.LogWarning("PaymentIntent {PaymentIntentId} is missing campaign metadata.", paymentIntent.Id);
            return;
        }

        var amount = paymentIntent.AmountReceived > 0
            ? paymentIntent.AmountReceived / 100m
            : paymentIntent.Amount / 100m;
        var expectedAmount = TryGetMetadataDecimal(paymentIntent, "amountBam");
        if (expectedAmount.HasValue && expectedAmount.Value != amount)
        {
            _logger.LogWarning(
                "PaymentIntent {PaymentIntentId} amount mismatch. Expected {Expected}, got {Actual}.",
                paymentIntent.Id,
                expectedAmount.Value,
                amount);
            return;
        }

        var currency = paymentIntent.Currency?.ToUpperInvariant() ?? "BAM";
        if (!string.Equals(currency, "BAM", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("PaymentIntent {PaymentIntentId} had unexpected currency {Currency}.", paymentIntent.Id, currency);
            return;
        }

        int? userId = TryGetMetadataInt(paymentIntent, "userId");
        var dto = new StripeDonationCreateDto
        {
            Amount = amount,
            CampaignId = campaignId,
            IsAnonymous = TryGetMetadataBool(paymentIntent, "isAnonymous"),
            DonorName = TryGetMetadataString(paymentIntent, "donorName"),
            Message = TryGetMetadataString(paymentIntent, "message"),
            PaymentIntentId = paymentIntent.Id,
            ChargeId = paymentIntent.LatestChargeId,
            Currency = currency
        };

        await _donationService.RecordStripePaymentAsync(dto, userId);
        _logger.LogInformation(
            "Recorded Stripe payment intent {PaymentIntentId} for campaign {CampaignId}.",
            paymentIntent.Id,
            campaignId);
    }

    private async Task HandleRefundEventAsync(Event stripeEvent)
    {
        if (stripeEvent.Data.Object is not Refund refund || refund.Amount <= 0)
            return;

        var amount = refund.Amount / 100m;
        var handled = await _donationService.MarkRefundedAsync(refund.PaymentIntentId, refund.ChargeId, amount);
        if (!handled)
            _logger.LogInformation("Refund {RefundId} did not match an eligible donation.", refund.Id);
    }

    private async Task HandleRefundFailedEventAsync(Event stripeEvent)
    {
        if (stripeEvent.Data.Object is not Refund refund || refund.Amount <= 0)
            return;

        var amount = refund.Amount / 100m;
        var handled = await _donationService.MarkRefundFailedAsync(refund.PaymentIntentId, refund.ChargeId, amount);
        if (!handled)
            _logger.LogInformation("Refund failure {RefundId} did not match a processed donation.", refund.Id);
    }

    private static bool TryGetCampaignId(PaymentIntent paymentIntent, out int campaignId)
    {
        campaignId = 0;
        var metadataValue = TryGetMetadataString(paymentIntent, "campaignId");
        return !string.IsNullOrWhiteSpace(metadataValue) && int.TryParse(metadataValue, out campaignId);
    }

    private static bool TryGetMetadataBool(PaymentIntent paymentIntent, string key)
    {
        var value = TryGetMetadataString(paymentIntent, key);
        return !string.IsNullOrWhiteSpace(value) && bool.TryParse(value, out var parsed) && parsed;
    }

    private static int? TryGetMetadataInt(PaymentIntent paymentIntent, string key)
    {
        var value = TryGetMetadataString(paymentIntent, key);
        return int.TryParse(value, out var parsed) ? parsed : null;
    }

    private static decimal? TryGetMetadataDecimal(PaymentIntent paymentIntent, string key)
    {
        var value = TryGetMetadataString(paymentIntent, key);
        return decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed) ? parsed : null;
    }

    private static string? TryGetMetadataString(PaymentIntent paymentIntent, string key)
    {
        return paymentIntent.Metadata != null && paymentIntent.Metadata.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value
            : null;
    }

    private string GetStripeSetting(string key, string environmentKey)
    {
        var configuredValue = _configuration[$"Stripe:{key}"];
        var value = !string.IsNullOrWhiteSpace(configuredValue) && !configuredValue.Contains("your_", StringComparison.OrdinalIgnoreCase)
            ? configuredValue
            : Environment.GetEnvironmentVariable(environmentKey);

        return !string.IsNullOrWhiteSpace(value)
            ? value
            : throw new InvalidOperationException($"Stripe:{key} is not configured.");
    }
}
