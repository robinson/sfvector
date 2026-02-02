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
/// Search operations - KNN and range search endpoints
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SearchController : ControllerBase
{
    private readonly ISearchService _searchService;
    private readonly ILogger<SearchController> _logger;

    public SearchController(ISearchService searchService, ILogger<SearchController> logger)
    {
        _searchService = searchService;
        _logger = logger;
    }

    /// <summary>
    /// K-Nearest Neighbors search
    /// </summary>
    /// <param name="request">KNN search request</param>
    /// <returns>Search results with distances</returns>
    [HttpPost("knn")]
    [ProducesResponseType(typeof(SearchResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SearchResponse>> KnnSearch([FromBody] KnnSearchRequest request)
    {
        try
        {
            var startTime = DateTime.UtcNow;
            var results = await _searchService.KnnSearchAsync(request);
            var queryTime = (DateTime.UtcNow - startTime).TotalMilliseconds;

            return Ok(new SearchResponse
            {
                Results = results,
                TotalResults = results.Count,
                QueryTimeMs = queryTime
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Range search - find all vectors within distance threshold
    /// </summary>
    /// <param name="request">Range search request</param>
    /// <returns>All vectors within range</returns>
    [HttpPost("range")]
    [ProducesResponseType(typeof(SearchResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SearchResponse>> RangeSearch([FromBody] RangeSearchRequest request)
    {
        try
        {
            var startTime = DateTime.UtcNow;
            var results = await _searchService.RangeSearchAsync(request);
            var queryTime = (DateTime.UtcNow - startTime).TotalMilliseconds;

            return Ok(new SearchResponse
            {
                Results = results,
                TotalResults = results.Count,
                QueryTimeMs = queryTime
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Hybrid search - combine vector similarity with filters
    /// </summary>
    /// <param name="request">Hybrid search request</param>
    /// <returns>Filtered search results</returns>
    [HttpPost("hybrid")]
    [ProducesResponseType(typeof(SearchResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SearchResponse>> HybridSearch([FromBody] HybridSearchRequest request)
    {
        try
        {
            var startTime = DateTime.UtcNow;
            var results = await _searchService.HybridSearchAsync(request);
            var queryTime = (DateTime.UtcNow - startTime).TotalMilliseconds;

            return Ok(new SearchResponse
            {
                Results = results,
                TotalResults = results.Count,
                QueryTimeMs = queryTime
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }
}
