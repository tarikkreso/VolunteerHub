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
    private readonly ICurrentUserService _currentUserService;
    private readonly ILogger<DonationsController> _logger;

    public DonationsController(
        IDonationService donationService,
        ICurrentUserService currentUserService,
        ILogger<DonationsController> logger)
    {
        _donationService = donationService;
        _currentUserService = currentUserService;
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
        var userId = _currentUserService.UserId ?? 0;
        var includeAll = _currentUserService.IsAdmin;
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
        var userId = _currentUserService.GetRequiredUserId();
        var result = await _donationService.GetByUserAsync(userId, request);
        return Ok(result);
    }

    [HttpGet("payment-intent/{paymentIntentId}")]
    public async Task<ActionResult<DonationDto>> GetByPaymentIntent(string paymentIntentId)
    {
        var userId = _currentUserService.UserId ?? 0;
        var includeAll = _currentUserService.IsAdmin;
        var result = await _donationService.GetByPaymentIntentForUserAsync(paymentIntentId, userId, includeAll);
        if (result == null) return NotFound(new { message = "Donacija jos nije evidentirana." });
        return Ok(result);
    }

    [HttpPost("payment-intent/{paymentIntentId}/sync")]
    public async Task<ActionResult<DonationDto>> SyncPaymentIntent(string paymentIntentId)
    {
        try
        {
            var userId = _currentUserService.UserId ?? 0;
            var includeAll = _currentUserService.IsAdmin;
            var result = await _donationService.SyncStripePaymentAsync(paymentIntentId, userId, includeAll);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Payment intent sync failed for {PaymentIntentId}.", paymentIntentId);
            return BadRequest(new { message = "Placanje je obradjeno, ali donacija trenutno nije evidentirana. Pokusajte osvjeziti kampanju." });
        }
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

            var userId = _currentUserService.UserId ?? 0;
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
