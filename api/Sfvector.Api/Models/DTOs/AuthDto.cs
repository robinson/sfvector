/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


namespace Sfvector.Api.Models.DTOs;

/// <summary>
/// Login request
/// </summary>
public class LoginRequest
{
    public required string Username { get; set; }
    public required string Password { get; set; }
}

/// <summary>
/// Login response with JWT token
/// </summary>
public class LoginResponse
{
    public required string Token { get; set; }
    public required string RefreshToken { get; set; }
    public required DateTime ExpiresAt { get; set; }
    public string TokenType { get; set; } = "Bearer";
}

/// <summary>
/// Refresh token request
/// </summary>
public class RefreshTokenRequest
{
    public required string RefreshToken { get; set; }
}

/// <summary>
/// Token validation response
/// </summary>
public class TokenValidationResponse
{
    public bool IsValid { get; set; }
    public string? Username { get; set; }
    public string? ExpiresAt { get; set; }
}
