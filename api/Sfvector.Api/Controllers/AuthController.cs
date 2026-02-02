/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Sfvector.Api.Models.DTOs;
using Sfvector.Api.Services;

namespace Sfvector.Api.Controllers;

/// <summary>
/// Authentication endpoints
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(IAuthService authService, ILogger<AuthController> logger)
    {
        _authService = authService;
        _logger = logger;
    }

    /// <summary>
    /// Login and get JWT token
    /// </summary>
    /// <param name="request">Login credentials</param>
    /// <returns>JWT token and expiration</returns>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest request)
    {
        var result = await _authService.LoginAsync(request);
        
        if (result == null)
            return Unauthorized(new { error = "Invalid username or password" });

        return Ok(result);
    }

    /// <summary>
    /// Refresh JWT token
    /// </summary>
    /// <param name="request">Refresh token request</param>
    /// <returns>New JWT token</returns>
    [HttpPost("refresh")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<LoginResponse>> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        var result = await _authService.RefreshTokenAsync(request);
        
        if (result == null)
            return Unauthorized(new { error = "Invalid or expired refresh token" });

        return Ok(result);
    }

    /// <summary>
    /// Validate current token
    /// </summary>
    /// <returns>Token validation result</returns>
    [HttpGet("validate")]
    [Authorize]
    [ProducesResponseType(typeof(TokenValidationResponse), StatusCodes.Status200OK)]
    public IActionResult ValidateToken()
    {
        return Ok(new TokenValidationResponse
        {
            IsValid = true,
            Username = User.Identity?.Name,
            ExpiresAt = User.Claims.FirstOrDefault(c => c.Type == "exp")?.Value
        });
    }
}
