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
/// Index management - Create, list, and manage FAISS indexes
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class IndexesController : ControllerBase
{
    private readonly IIndexService _indexService;
    private readonly ILogger<IndexesController> _logger;

    public IndexesController(IIndexService indexService, ILogger<IndexesController> logger)
    {
        _indexService = indexService;
        _logger = logger;
    }

    /// <summary>
    /// Create a new FAISS index
    /// </summary>
    /// <param name="request">Index creation request</param>
    /// <returns>Created index information</returns>
    [HttpPost]
    [ProducesResponseType(typeof(IndexResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<IndexResponse>> CreateIndex([FromBody] IndexCreateRequest request)
    {
        try
        {
            var result = await _indexService.CreateIndexAsync(request);
            return CreatedAtAction(nameof(GetIndex), new { name = result.Name }, result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// List all indexes
    /// </summary>
    /// <returns>List of indexes</returns>
    [HttpGet]
    [ProducesResponseType(typeof(IndexListResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<IndexListResponse>> ListIndexes()
    {
        var indexes = await _indexService.ListIndexesAsync();
        return Ok(new IndexListResponse { Indexes = indexes });
    }

    /// <summary>
    /// Get index by name
    /// </summary>
    /// <param name="name">Index name</param>
    /// <returns>Index information</returns>
    [HttpGet("{name}")]
    [ProducesResponseType(typeof(IndexResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IndexResponse>> GetIndex(string name)
    {
        var result = await _indexService.GetIndexAsync(name);
        
        if (result == null)
            return NotFound(new { error = $"Index '{name}' not found" });

        return Ok(result);
    }

    /// <summary>
    /// Get index statistics
    /// </summary>
    /// <param name="name">Index name</param>
    /// <returns>Detailed index statistics</returns>
    [HttpGet("{name}/stats")]
    [ProducesResponseType(typeof(IndexStatsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IndexStatsResponse>> GetIndexStats(string name)
    {
        var result = await _indexService.GetIndexStatsAsync(name);
        
        if (result == null)
            return NotFound(new { error = $"Index '{name}' not found" });

        return Ok(result);
    }

    /// <summary>
    /// Rebuild an index
    /// </summary>
    /// <param name="name">Index name</param>
    /// <returns>Rebuild operation result</returns>
    [HttpPost("{name}/rebuild")]
    [ProducesResponseType(typeof(IndexRebuildResponse), StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IndexRebuildResponse>> RebuildIndex(string name)
    {
        try
        {
            var result = await _indexService.RebuildIndexAsync(name);
            
            if (result == null)
                return NotFound(new { error = $"Index '{name}' not found" });

            return AcceptedAtAction(nameof(GetIndex), new { name }, result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Delete an index
    /// </summary>
    /// <param name="name">Index name</param>
    /// <returns>No content</returns>
    [HttpDelete("{name}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteIndex(string name)
    {
        var result = await _indexService.DeleteIndexAsync(name);
        
        if (!result)
            return NotFound(new { error = $"Index '{name}' not found" });

        return NoContent();
    }
}
