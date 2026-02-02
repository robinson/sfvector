/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


namespace Sfvector.Api.Models.DTOs;

/// <summary>
/// KNN search request
/// </summary>
public class KnnSearchRequest
{
    public required List<float> Vector { get; set; }
    public int K { get; set; } = 10;
    public string Metric { get; set; } = "cosine";
    public Dictionary<string, object>? Filter { get; set; }
}

/// <summary>
/// Range search request
/// </summary>
public class RangeSearchRequest
{
    public required List<float> Vector { get; set; }
    public float Radius { get; set; }
    public string Metric { get; set; } = "l2";
    public int? MaxResults { get; set; }
}

/// <summary>
/// Hybrid search request (vector + filters)
/// </summary>
public class HybridSearchRequest
{
    public required List<float> Vector { get; set; }
    public int K { get; set; } = 10;
    public string Metric { get; set; } = "cosine";
    public required Dictionary<string, object> Filter { get; set; }
}

/// <summary>
/// Search result item
/// </summary>
public class SearchResult
{
    public required string Id { get; set; }
    public float Distance { get; set; }
    public float Similarity { get; set; }
    public Dictionary<string, object>? Metadata { get; set; }
}

/// <summary>
/// Search response
/// </summary>
public class SearchResponse
{
    public required List<SearchResult> Results { get; set; }
    public int TotalResults { get; set; }
    public double QueryTimeMs { get; set; }
}
