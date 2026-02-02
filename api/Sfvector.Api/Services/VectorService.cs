/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using Microsoft.Data.SqlClient;
using Sfvector.Api.Models.DTOs;
using System.Text.Json;

namespace Sfvector.Api.Services;

public class VectorService : IVectorService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<VectorService> _logger;
    private readonly string _connectionString;

    public VectorService(IConfiguration configuration, ILogger<VectorService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new InvalidOperationException("Connection string not configured");
    }

    public async Task<VectorResponse> CreateVectorAsync(VectorCreateRequest request)
    {
        if (request.Vector.Count == 0 || request.Vector.Count > 4096)
            throw new ArgumentException("Vector dimension must be between 1 and 4096");

        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var vectorStr = $"[{string.Join(",", request.Vector)}]";
        var metadataJson = request.Metadata != null ? JsonSerializer.Serialize(request.Metadata) : null;

        var sql = @"
            INSERT INTO VectorsTest_FAISS (id, vector, metadata, created_at)
            VALUES (@id, dbo.VectorType::Parse(@vector), @metadata, GETUTCDATE())";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@id", request.Id);
        command.Parameters.AddWithValue("@vector", vectorStr);
        command.Parameters.AddWithValue("@metadata", (object?)metadataJson ?? DBNull.Value);

        await command.ExecuteNonQueryAsync();

        return new VectorResponse
        {
            Id = request.Id,
            Vector = request.Vector,
            Metadata = request.Metadata,
            CreatedAt = DateTime.UtcNow
        };
    }

    public async Task<BatchInsertResponse> BatchInsertAsync(BatchInsertRequest request)
    {
        if (request.Vectors.Count > 1000)
            throw new ArgumentException("Batch size exceeds maximum of 1000");

        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        using var transaction = connection.BeginTransaction();
        try
        {
            var sql = @"
                INSERT INTO VectorsTest_FAISS (id, vector, metadata, created_at)
                VALUES (@id, dbo.VectorType::Parse(@vector), @metadata, GETUTCDATE())";

            using var command = new SqlCommand(sql, connection, transaction);
            
            foreach (var vectorRequest in request.Vectors)
            {
                var vectorStr = $"[{string.Join(",", vectorRequest.Vector)}]";
                var metadataJson = vectorRequest.Metadata != null 
                    ? JsonSerializer.Serialize(vectorRequest.Metadata) : null;

                command.Parameters.Clear();
                command.Parameters.AddWithValue("@id", vectorRequest.Id);
                command.Parameters.AddWithValue("@vector", vectorStr);
                command.Parameters.AddWithValue("@metadata", (object?)metadataJson ?? DBNull.Value);

                await command.ExecuteNonQueryAsync();
            }

            transaction.Commit();

            return new BatchInsertResponse
            {
                Inserted = request.Vectors.Count,
                Message = "Batch insert successful"
            };
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    public async Task<VectorResponse?> GetVectorAsync(string id)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = @"
            SELECT id, vector.ToString() as vector_str, metadata, created_at, updated_at
            FROM VectorsTest_FAISS
            WHERE id = @id";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@id", id);

        using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;

        var vectorStr = reader.GetString(1).Trim('[', ']');
        var vector = vectorStr.Split(',').Select(float.Parse).ToList();
        
        var metadataStr = reader.IsDBNull(2) ? null : reader.GetString(2);
        var metadata = metadataStr != null 
            ? JsonSerializer.Deserialize<Dictionary<string, object>>(metadataStr) : null;

        return new VectorResponse
        {
            Id = reader.GetString(0),
            Vector = vector,
            Metadata = metadata,
            CreatedAt = reader.GetDateTime(3),
            UpdatedAt = reader.IsDBNull(4) ? null : reader.GetDateTime(4)
        };
    }

    public async Task<VectorListResponse> ListVectorsAsync(int page, int pageSize)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        // Get total count
        var countSql = "SELECT COUNT(*) FROM VectorsTest_FAISS";
        using var countCommand = new SqlCommand(countSql, connection);
        var total = (int)await countCommand.ExecuteScalarAsync();

        // Get paginated results
        var sql = @"
            SELECT id, vector.ToString() as vector_str, metadata, created_at, updated_at
            FROM VectorsTest_FAISS
            ORDER BY created_at DESC
            OFFSET @offset ROWS
            FETCH NEXT @pageSize ROWS ONLY";

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
        command.Parameters.AddWithValue("@pageSize", pageSize);

        var vectors = new List<VectorResponse>();
        using var reader = await command.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            var vectorStr = reader.GetString(1).Trim('[', ']');
            var vector = vectorStr.Split(',').Select(float.Parse).ToList();
            
            var metadataStr = reader.IsDBNull(2) ? null : reader.GetString(2);
            var metadata = metadataStr != null 
                ? JsonSerializer.Deserialize<Dictionary<string, object>>(metadataStr) : null;

            vectors.Add(new VectorResponse
            {
                Id = reader.GetString(0),
                Vector = vector,
                Metadata = metadata,
                CreatedAt = reader.GetDateTime(3),
                UpdatedAt = reader.IsDBNull(4) ? null : reader.GetDateTime(4)
            });
        }

        return new VectorListResponse
        {
            Vectors = vectors,
            Total = total,
            Page = page,
            PageSize = pageSize,
            TotalPages = (int)Math.Ceiling(total / (double)pageSize)
        };
    }

    public async Task<VectorResponse?> UpdateVectorAsync(string id, VectorUpdateRequest request)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var setClauses = new List<string>();
        var command = new SqlCommand { Connection = connection };

        if (request.Vector != null)
        {
            var vectorStr = $"[{string.Join(",", request.Vector)}]";
            setClauses.Add("vector = dbo.VectorType::Parse(@vector)");
            command.Parameters.AddWithValue("@vector", vectorStr);
        }

        if (request.Metadata != null)
        {
            setClauses.Add("metadata = @metadata");
            command.Parameters.AddWithValue("@metadata", JsonSerializer.Serialize(request.Metadata));
        }

        if (setClauses.Count == 0)
            throw new ArgumentException("No fields to update");

        setClauses.Add("updated_at = GETUTCDATE()");

        var sql = $@"
            UPDATE VectorsTest_FAISS
            SET {string.Join(", ", setClauses)}
            WHERE id = @id";

        command.CommandText = sql;
        command.Parameters.AddWithValue("@id", id);

        var rowsAffected = await command.ExecuteNonQueryAsync();
        
        if (rowsAffected == 0)
            return null;

        return await GetVectorAsync(id);
    }

    public async Task<bool> DeleteVectorAsync(string id)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = "DELETE FROM VectorsTest_FAISS WHERE id = @id";
        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@id", id);

        var rowsAffected = await command.ExecuteNonQueryAsync();
        return rowsAffected > 0;
    }

    public async Task<long> GetCountAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = "SELECT COUNT(*) FROM VectorsTest_FAISS";
        using var command = new SqlCommand(sql, connection);

        return (int)await command.ExecuteScalarAsync();
    }
}
