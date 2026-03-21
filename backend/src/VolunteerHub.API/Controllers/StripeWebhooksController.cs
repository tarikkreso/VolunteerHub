using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Stripe;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/webhooks/stripe")]
[AllowAnonymous]
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
        var webhookSecret = _configuration["Stripe:WebhookSecret"];
        if (string.IsNullOrWhiteSpace(webhookSecret) || webhookSecret.Contains("your_webhook", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("Stripe webhook secret is not configured.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "Stripe webhook secret nije konfigurisan."
            });
        }

        var signature = Request.Headers["Stripe-Signature"].ToString();
        if (string.IsNullOrWhiteSpace(signature))
        {
            return BadRequest(new { message = "Nedostaje Stripe-Signature zaglavlje." });
        }

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
        catch (StripeException ex)
        {
            _logger.LogWarning(ex, "Stripe webhook signature verification failed.");
            return BadRequest(new { message = "Neispravan Stripe webhook potpis." });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Stripe webhook payload could not be parsed.");
            return BadRequest(new { message = "Neispravan Stripe webhook payload." });
        }

        switch (stripeEvent.Type)
        {
            case "payment_intent.succeeded":
                await HandlePaymentIntentSucceededAsync(stripeEvent);
                break;

            case "payment_intent.payment_failed":
                _logger.LogInformation("Stripe payment intent failed: {EventId}", stripeEvent.Id);
                break;

            default:
                _logger.LogInformation("Ignoring Stripe webhook event type {EventType}", stripeEvent.Type);
                break;
        }

        return Ok(new { received = true });
    }

    private async Task HandlePaymentIntentSucceededAsync(Event stripeEvent)
    {
        var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
        if (paymentIntent == null)
        {
            _logger.LogWarning("Webhook event {EventId} did not contain a PaymentIntent object.", stripeEvent.Id);
            return;
        }

        if (!TryGetCampaignId(paymentIntent, out var campaignId))
        {
            _logger.LogWarning("PaymentIntent {PaymentIntentId} is missing campaign metadata.", paymentIntent.Id);
            return;
        }

        var isAnonymous = TryGetMetadataBool(paymentIntent, "isAnonymous");
        var donorName = TryGetMetadataString(paymentIntent, "donorName");
        var amount = paymentIntent.AmountReceived > 0
            ? paymentIntent.AmountReceived / 100m
            : paymentIntent.Amount / 100m;

        var dto = new DonationCreateDto
        {
            Amount = amount,
            CampaignId = campaignId,
            IsAnonymous = isAnonymous,
            DonorName = donorName,
            Message = null,
            StripePaymentIntentId = paymentIntent.Id
        };

        await _donationService.CreateAsync(dto, null);
        _logger.LogInformation(
            "Recorded Stripe payment intent {PaymentIntentId} for campaign {CampaignId}.",
            paymentIntent.Id,
            campaignId);
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

    private static string? TryGetMetadataString(PaymentIntent paymentIntent, string key)
    {
        if (paymentIntent.Metadata != null && paymentIntent.Metadata.TryGetValue(key, out var value))
        {
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }

        return null;
    }
}
