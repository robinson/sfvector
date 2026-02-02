/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using Microsoft.Data.SqlClient;
using Sfvector.Api.Models.DTOs;

namespace Sfvector.Api.Services;

public class SearchService : ISearchService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SearchService> _logger;
    private readonly string _connectionString;

    public SearchService(IConfiguration configuration, ILogger<SearchService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new InvalidOperationException("Connection string not configured");
    }

    public async Task<List<SearchResult>> KnnSearchAsync(KnnSearchRequest request)
    {
        if (request.K <= 0 || request.K > 1000)
            throw new ArgumentException("K must be between 1 and 1000");

        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var vectorStr = $"[{string.Join(",", request.Vector)}]";

        // Use indexed search if available, otherwise sequential scan
        var sql = $@"
            SELECT TOP (@k) 
                id,
                dbo.VectorDistance(vector, dbo.VectorType::Parse(@query), @metric) as distance,
                metadata
            FROM VectorsTest_FAISS
            ORDER BY dbo.VectorDistance(vector, dbo.VectorType::Parse(@query), @metric) ASC";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@k", request.K);
        command.Parameters.AddWithValue("@query", vectorStr);
        command.Parameters.AddWithValue("@metric", request.Metric.ToUpper());

        var results = new List<SearchResult>();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var distance = (double)reader.GetDouble(1);
            var similarity = request.Metric.ToLower() == "cosine" ? 1.0 - distance : distance;

            results.Add(new SearchResult
            {
                Id = reader.GetString(0),
                Distance = (float)distance,
                Similarity = (float)similarity,
                Metadata = null // TODO: Parse metadata if needed
            });
        }

        return results;
    }

    public async Task<List<SearchResult>> RangeSearchAsync(RangeSearchRequest request)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var vectorStr = $"[{string.Join(",", request.Vector)}]";
        var maxResults = request.MaxResults ?? 1000;

        var sql = $@"
            SELECT TOP (@maxResults)
                id,
                dbo.VectorDistance(vector, dbo.VectorType::Parse(@query), @metric) as distance,
                metadata
            FROM VectorsTest_FAISS
            WHERE dbo.VectorDistance(vector, dbo.VectorType::Parse(@query), @metric) <= @radius
            ORDER BY distance ASC";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@query", vectorStr);
        command.Parameters.AddWithValue("@metric", request.Metric.ToUpper());
        command.Parameters.AddWithValue("@radius", request.Radius);
        command.Parameters.AddWithValue("@maxResults", maxResults);

        var results = new List<SearchResult>();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var distance = (double)reader.GetDouble(1);

            results.Add(new SearchResult
            {
                Id = reader.GetString(0),
                Distance = (float)distance,
                Similarity = (float)(1.0 - distance),
                Metadata = null
            });
        }

        return results;
    }

    public async Task<List<SearchResult>> HybridSearchAsync(HybridSearchRequest request)
    {
        if (request.K <= 0 || request.K > 1000)
            throw new ArgumentException("K must be between 1 and 1000");

        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var vectorStr = $"[{string.Join(",", request.Vector)}]";

        // Build WHERE clause from filters
        var whereClauses = new List<string>();
        var parameters = new List<SqlParameter>
        {
            new("@k", request.K),
            new("@query", vectorStr),
            new("@metric", request.Metric.ToUpper())
        };

        // Simple filter support (extend as needed)
        int paramIndex = 0;
        foreach (var filter in request.Filter)
        {
            var paramName = $"@filter{paramIndex++}";
            whereClauses.Add($"JSON_VALUE(metadata, '$.{filter.Key}') = {paramName}");
            parameters.Add(new SqlParameter(paramName, filter.Value));
        }

        var whereClause = whereClauses.Any() ? $"WHERE {string.Join(" AND ", whereClauses)}" : "";

        var sql = $@"
            SELECT TOP (@k) 
                id,
                dbo.VectorDistance(vector, dbo.VectorType::Parse(@query), @metric) as distance,
                metadata
            FROM VectorsTest_FAISS
            {whereClause}
            ORDER BY dbo.VectorDistance(vector, dbo.VectorType::Parse(@query), @metric) ASC";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddRange(parameters.ToArray());

        var results = new List<SearchResult>();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var distance = (double)reader.GetDouble(1);
            var similarity = request.Metric.ToLower() == "cosine" ? 1.0 - distance : distance;

            results.Add(new SearchResult
            {
                Id = reader.GetString(0),
                Distance = (float)distance,
                Similarity = (float)similarity,
                Metadata = null
            });
        }

        return results;
    }
}
