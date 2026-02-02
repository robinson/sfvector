/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using Microsoft.Data.SqlClient;
using Sfvector.Api.Models.DTOs;
using System.Text.Json;

namespace Sfvector.Api.Services;

public class IndexService : IIndexService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<IndexService> _logger;
    private readonly string _connectionString;

    public IndexService(IConfiguration configuration, ILogger<IndexService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new InvalidOperationException("Connection string not configured");
    }

    public async Task<IndexResponse> CreateIndexAsync(IndexCreateRequest request)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var parametersJson = request.Parameters != null 
            ? JsonSerializer.Serialize(request.Parameters) : null;

        var sql = @"
            EXEC dbo.sp_create_vector_index 
                @table_schema = 'dbo',
                @table_name = @table,
                @column_name = @column,
                @index_type = @indexType,
                @metric = @metric,
                @index_options = @parameters";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@table", request.Table);
        command.Parameters.AddWithValue("@column", request.Column);
        command.Parameters.AddWithValue("@indexType", request.IndexType.ToUpper());
        command.Parameters.AddWithValue("@metric", request.Metric.ToUpper());
        command.Parameters.AddWithValue("@parameters", (object?)parametersJson ?? DBNull.Value);

        await command.ExecuteNonQueryAsync();

        return new IndexResponse
        {
            Name = request.Name,
            Type = request.IndexType,
            Metric = request.Metric,
            VectorCount = 0,
            CreatedAt = DateTime.UtcNow,
            Status = "building"
        };
    }

    public async Task<List<IndexResponse>> ListIndexesAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = @"
            SELECT 
                table_name + '_' + column_name + '_' + index_type as name,
                index_type,
                metric_type,
                ntotal,
                created_date
            FROM dbo.sys_vector_indexes
            WHERE is_active = 1";

        using var command = new SqlCommand(sql, connection);
        
        var indexes = new List<IndexResponse>();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            indexes.Add(new IndexResponse
            {
                Name = reader.GetString(0),
                Type = reader.GetString(1),
                Metric = reader.GetString(2),
                VectorCount = reader.GetInt64(3),
                CreatedAt = reader.GetDateTime(4),
                Status = "ready"
            });
        }

        return indexes;
    }

    public async Task<IndexResponse?> GetIndexAsync(string name)
    {
        var indexes = await ListIndexesAsync();
        return indexes.FirstOrDefault(i => i.Name == name);
    }

    public async Task<IndexStatsResponse?> GetIndexStatsAsync(string name)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = @"
            SELECT 
                index_type,
                metric_type,
                ntotal,
                dimension,
                index_options,
                last_rebuilt
            FROM dbo.sys_vector_indexes
            WHERE table_name + '_' + column_name + '_' + index_type = @name
                AND is_active = 1";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@name", name);

        using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;

        var optionsStr = reader.IsDBNull(4) ? null : reader.GetString(4);
        var parameters = optionsStr != null 
            ? JsonSerializer.Deserialize<Dictionary<string, object>>(optionsStr) : null;

        return new IndexStatsResponse
        {
            Name = name,
            Type = reader.GetString(0),
            VectorCount = reader.GetInt64(2),
            Dimension = reader.GetInt32(3),
            Parameters = parameters,
            SizeBytes = 0, // TODO: Calculate from file size
            LastUpdated = reader.GetDateTime(5)
        };
    }

    public async Task<IndexRebuildResponse?> RebuildIndexAsync(string name)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = @"
            EXEC dbo.sp_rebuild_vector_index
                @table_schema = 'dbo',
                @table_name = @table,
                @column_name = @column";

        // Parse index name to get table and column
        // Simplified - in production, query sys_vector_indexes
        using var command = new SqlCommand(sql, connection);
        // TODO: Implement proper parsing
        
        return new IndexRebuildResponse
        {
            Name = name,
            Status = "rebuilding",
            EstimatedTimeMinutes = 10
        };
    }

    public async Task<bool> DeleteIndexAsync(string name)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = @"
            UPDATE dbo.sys_vector_indexes
            SET is_active = 0
            WHERE table_name + '_' + column_name + '_' + index_type = @name";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@name", name);

        var rowsAffected = await command.ExecuteNonQueryAsync();
        return rowsAffected > 0;
    }
}
