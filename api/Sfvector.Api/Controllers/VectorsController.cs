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
/// Vector operations - CRUD endpoints for vector management
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class VectorsController : ControllerBase
{
    private readonly IVectorService _vectorService;
    private readonly ILogger<VectorsController> _logger;

    public VectorsController(IVectorService vectorService, ILogger<VectorsController> logger)
    {
        _vectorService = vectorService;
        _logger = logger;
    }

    /// <summary>
    /// Create a new vector
    /// </summary>
    /// <param name="request">Vector creation request</param>
    /// <returns>Created vector information</returns>
    [HttpPost]
    [ProducesResponseType(typeof(VectorResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<VectorResponse>> CreateVector([FromBody] VectorCreateRequest request)
    {
        try
        {
            var result = await _vectorService.CreateVectorAsync(request);
            return CreatedAtAction(nameof(GetVector), new { id = result.Id }, result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Batch insert multiple vectors
    /// </summary>
    /// <param name="request">Batch insert request</param>
    /// <returns>Batch insert result</returns>
    [HttpPost("batch")]
    [ProducesResponseType(typeof(BatchInsertResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<BatchInsertResponse>> BatchInsert([FromBody] BatchInsertRequest request)
    {
        try
        {
            var result = await _vectorService.BatchInsertAsync(request);
            return CreatedAtAction(nameof(BatchInsert), result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Get a vector by ID
    /// </summary>
    /// <param name="id">Vector ID</param>
    /// <returns>Vector data</returns>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(VectorResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VectorResponse>> GetVector(string id)
    {
        var result = await _vectorService.GetVectorAsync(id);
        
        if (result == null)
            return NotFound(new { error = $"Vector with ID '{id}' not found" });

        return Ok(result);
    }

    /// <summary>
    /// List vectors with pagination
    /// </summary>
    /// <param name="page">Page number (1-based)</param>
    /// <param name="pageSize">Items per page</param>
    /// <returns>Paginated vector list</returns>
    [HttpGet]
    [ProducesResponseType(typeof(VectorListResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<VectorListResponse>> ListVectors(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 1000) pageSize = 50;

        var result = await _vectorService.ListVectorsAsync(page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// Update a vector
    /// </summary>
    /// <param name="id">Vector ID</param>
    /// <param name="request">Update request</param>
    /// <returns>Updated vector</returns>
    [HttpPut("{id}")]
    [ProducesResponseType(typeof(VectorResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VectorResponse>> UpdateVector(
        string id,
        [FromBody] VectorUpdateRequest request)
    {
        try
        {
            var result = await _vectorService.UpdateVectorAsync(id, request);
            
            if (result == null)
                return NotFound(new { error = $"Vector with ID '{id}' not found" });

            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Delete a vector
    /// </summary>
    /// <param name="id">Vector ID</param>
    /// <returns>No content</returns>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteVector(string id)
    {
        var result = await _vectorService.DeleteVectorAsync(id);
        
        if (!result)
            return NotFound(new { error = $"Vector with ID '{id}' not found" });

        return NoContent();
    }

    /// <summary>
    /// Get vector count
    /// </summary>
    /// <returns>Total vector count</returns>
    [HttpGet("count")]
    [ProducesResponseType(typeof(CountResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<CountResponse>> GetCount()
    {
        var count = await _vectorService.GetCountAsync();
        return Ok(new CountResponse { Count = count });
    }
}
