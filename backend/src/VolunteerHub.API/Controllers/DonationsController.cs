using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Stripe;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DonationsController : ControllerBase
{
    private readonly IDonationService _donationService;
    private readonly IConfiguration _configuration;

    public DonationsController(IDonationService donationService, IConfiguration configuration)
    {
        _donationService = donationService;
        _configuration = configuration;
    }

    [HttpGet("by-campaign/{campaignId}")]
    [AllowAnonymous]
    public async Task<ActionResult<PagedResultDto<DonationDto>>> GetByCampaign(int campaignId, [FromQuery] SearchRequestDto request)
    {
        var result = await _donationService.GetByCampaignAsync(campaignId, request);
        return Ok(result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<DonationDto>> GetById(int id)
    {
        var result = await _donationService.GetByIdAsync(id);
        if (result == null) return NotFound(new { message = "Donacija nije pronađena." });
        return Ok(result);
    }

    [HttpGet("recent")]
    [AllowAnonymous]
    public async Task<ActionResult<List<DonationDto>>> GetRecent([FromQuery] int count = 10)
    {
        var result = await _donationService.GetRecentAsync(count);
        return Ok(result);
    }

    [HttpGet("me")]
    public async Task<ActionResult<PagedResultDto<DonationDto>>> GetMine([FromQuery] SearchRequestDto request)
    {
        int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var userId);
        var result = await _donationService.GetByUserAsync(userId, request);
        return Ok(result);
    }

    [HttpPost("create-payment-intent")]
    public async Task<ActionResult> CreatePaymentIntent([FromBody] PaymentIntentRequestDto request)
    {
        try
        {
            var stripeKey = _configuration["Stripe:SecretKey"];
            if (string.IsNullOrEmpty(stripeKey) || stripeKey.Contains("your_stripe"))
            {
                // Stripe not configured - return mock for demo
                return Ok(new
                {
                    clientSecret = "demo_mode",
                    paymentIntentId = $"pi_demo_{Guid.NewGuid():N}",
                    publishableKey = _configuration["Stripe:PublishableKey"] ?? "",
                    demoMode = true
                });
            }

            StripeConfiguration.ApiKey = stripeKey;
            var options = new PaymentIntentCreateOptions
            {
                Amount = (long)(request.Amount * 100), // Amount in cents
                Currency = "bam",
                Metadata = new Dictionary<string, string>
                {
                    { "campaignId", request.CampaignId.ToString() },
                    { "donorName", request.DonorName ?? "" },
                    { "isAnonymous", request.IsAnonymous.ToString() }
                }
            };

            var service = new PaymentIntentService();
            var paymentIntent = await service.CreateAsync(options);

            return Ok(new
            {
                clientSecret = paymentIntent.ClientSecret,
                paymentIntentId = paymentIntent.Id,
                publishableKey = _configuration["Stripe:PublishableKey"] ?? "",
                demoMode = false
            });
        }
        catch (StripeException ex)
        {
            // Log full error server-side; return generic message to client
            Console.Error.WriteLine($"Stripe error: {ex.StripeError?.Code} – {ex.Message}");
            return BadRequest(new { message = "Greška pri obradi plaćanja. Pokušajte ponovo ili kontaktirajte podršku." });
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Payment intent error: {ex}");
            return BadRequest(new { message = "Greška pri kreiranju plaćanja. Pokušajte ponovo." });
        }
    }

    [HttpGet("stripe-config")]
    [AllowAnonymous]
    public ActionResult GetStripeConfig()
    {
        var publishableKey = _configuration["Stripe:PublishableKey"] ?? "";
        var isDemoMode = string.IsNullOrEmpty(publishableKey) || publishableKey.Contains("your_stripe");
        return Ok(new { publishableKey, demoMode = isDemoMode });
    }

    [HttpPost]
    public async Task<ActionResult<DonationDto>> Create([FromBody] DonationCreateDto dto)
    {
        try
        {
            int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var userId);
            var result = await _donationService.CreateAsync(dto, userId);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
