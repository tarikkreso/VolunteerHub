using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VolunteerHub.Application.DTOs;
using VolunteerHub.Application.Services.Interfaces;

namespace VolunteerHub.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DonationsController : ControllerBase
{
    private readonly IDonationService _donationService;
    private readonly ILogger<DonationsController> _logger;

    public DonationsController(IDonationService donationService, ILogger<DonationsController> logger)
    {
        _donationService = donationService;
        _logger = logger;
    }

    [HttpGet("by-campaign/{campaignId}")]
    public async Task<ActionResult<PagedResultDto<DonationDto>>> GetByCampaign(int campaignId, [FromQuery] SearchRequestDto request)
    {
        var result = await _donationService.GetByCampaignAsync(campaignId, request);
        return Ok(result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<DonationDto>> GetById(int id)
    {
        int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var userId);
        var includeAll = User.IsInRole("Admin") || User.IsInRole("SuperAdmin");
        var result = await _donationService.GetByIdForUserAsync(id, userId, includeAll);
        if (result == null) return NotFound(new { message = "Donacija nije pronadjena." });
        return Ok(result);
    }

    [HttpGet("recent")]
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

    [HttpGet("payment-intent/{paymentIntentId}")]
    public async Task<ActionResult<DonationDto>> GetByPaymentIntent(string paymentIntentId)
    {
        int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var userId);
        var includeAll = User.IsInRole("Admin") || User.IsInRole("SuperAdmin");
        var result = await _donationService.GetByPaymentIntentForUserAsync(paymentIntentId, userId, includeAll);
        if (result == null) return NotFound(new { message = "Donacija jos nije evidentirana." });
        return Ok(result);
    }

    [HttpPost("create-payment-intent")]
    public async Task<ActionResult<PaymentIntentResponseDto>> CreatePaymentIntent([FromBody] PaymentIntentRequestDto request)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.IdempotencyKey) &&
                Request.Headers.TryGetValue("Idempotency-Key", out var idempotencyHeader))
            {
                request.IdempotencyKey = idempotencyHeader.FirstOrDefault();
            }

            int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var userId);
            var result = await _donationService.CreatePaymentIntentAsync(request, userId);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Payment intent creation failed.");
            return BadRequest(new { message = "Greska pri kreiranju placanja. Pokusajte ponovo." });
        }
    }

    [HttpPost("{id}/refund")]
    [Authorize(Roles = "Admin,SuperAdmin")]
    public async Task<ActionResult<DonationDto>> Refund(int id)
    {
        try
        {
            var result = await _donationService.RefundAsync(id);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Refund failed for donation {DonationId}.", id);
            return BadRequest(new { message = "Greska pri refundaciji. Pokusajte ponovo." });
        }
    }

    // Donations are finalized exclusively by the Stripe webhook after server-side verification.
}
