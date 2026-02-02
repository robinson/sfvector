/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


namespace Sfvector.Api.Models.DTOs;

/// <summary>
/// Request to create a new vector
/// </summary>
public class VectorCreateRequest
{
    public required string Id { get; set; }
    public required List<float> Vector { get; set; }
    public Dictionary<string, object>? Metadata { get; set; }
}

/// <summary>
/// Request to update a vector
/// </summary>
public class VectorUpdateRequest
{
    public List<float>? Vector { get; set; }
    public Dictionary<string, object>? Metadata { get; set; }
}

/// <summary>
/// Request for batch insert
/// </summary>
public class BatchInsertRequest
{
    public required List<VectorCreateRequest> Vectors { get; set; }
}

/// <summary>
/// Vector response
/// </summary>
public class VectorResponse
{
    public required string Id { get; set; }
    public required List<float> Vector { get; set; }
    public Dictionary<string, object>? Metadata { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>
/// Batch insert response
/// </summary>
public class BatchInsertResponse
{
    public int Inserted { get; set; }
    public string Message { get; set; } = "Batch insert successful";
}

/// <summary>
/// Paginated vector list response
/// </summary>
public class VectorListResponse
{
    public required List<VectorResponse> Vectors { get; set; }
    public int Total { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages { get; set; }
}

/// <summary>
/// Count response
/// </summary>
public class CountResponse
{
    public long Count { get; set; }
}
