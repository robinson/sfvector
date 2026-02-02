/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


namespace Sfvector.Api.Models.DTOs;

/// <summary>
/// Index creation request
/// </summary>
public class IndexCreateRequest
{
    public required string Name { get; set; }
    public required string Table { get; set; }
    public required string Column { get; set; }
    public string IndexType { get; set; } = "hnsw";
    public string Metric { get; set; } = "cosine";
    public Dictionary<string, object>? Parameters { get; set; }
}

/// <summary>
/// Index response
/// </summary>
public class IndexResponse
{
    public required string Name { get; set; }
    public required string Type { get; set; }
    public required string Metric { get; set; }
    public long VectorCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public string Status { get; set; } = "ready";
}

/// <summary>
/// Index statistics response
/// </summary>
public class IndexStatsResponse
{
    public required string Name { get; set; }
    public required string Type { get; set; }
    public long VectorCount { get; set; }
    public int Dimension { get; set; }
    public Dictionary<string, object>? Parameters { get; set; }
    public long SizeBytes { get; set; }
    public DateTime LastUpdated { get; set; }
}

/// <summary>
/// Index rebuild response
/// </summary>
public class IndexRebuildResponse
{
    public required string Name { get; set; }
    public string Status { get; set; } = "rebuilding";
    public int? EstimatedTimeMinutes { get; set; }
}

/// <summary>
/// Index list response
/// </summary>
public class IndexListResponse
{
    public required List<IndexResponse> Indexes { get; set; }
}
