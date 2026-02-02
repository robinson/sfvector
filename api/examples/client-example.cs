/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using System.Net.Http.Json;
using System.Text.Json;

namespace Sfvector.Api.Examples;

/// <summary>
/// C# client example for sfvector API
/// </summary>
public class SfvectorClient
{
    private readonly HttpClient _httpClient;
    private string? _token;

    public SfvectorClient(string baseUrl)
    {
        _httpClient = new HttpClient { BaseAddress = new Uri(baseUrl) };
    }

    /// <summary>
    /// Login and get JWT token
    /// </summary>
    public async Task<bool> LoginAsync(string username, string password)
    {
        var request = new { username, password };
        var response = await _httpClient.PostAsJsonAsync("/api/auth/login", request);

        if (!response.IsSuccessStatusCode)
            return false;

        var result = await response.Content.ReadFromJsonAsync<LoginResponse>();
        _token = result?.Token;

        if (!string.IsNullOrEmpty(_token))
        {
            _httpClient.DefaultRequestHeaders.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _token);
        }

        return !string.IsNullOrEmpty(_token);
    }

    /// <summary>
    /// Insert a vector
    /// </summary>
    public async Task<bool> InsertVectorAsync(string id, float[] vector, Dictionary<string, object>? metadata = null)
    {
        var request = new
        {
            id,
            vector = vector.ToList(),
            metadata
        };

        var response = await _httpClient.PostAsJsonAsync("/api/vectors", request);
        return response.IsSuccessStatusCode;
    }

    /// <summary>
    /// Batch insert vectors
    /// </summary>
    public async Task<int> BatchInsertAsync(List<(string id, float[] vector, Dictionary<string, object>? metadata)> vectors)
    {
        var request = new
        {
            vectors = vectors.Select(v => new
            {
                id = v.id,
                vector = v.vector.ToList(),
                metadata = v.metadata
            }).ToList()
        };

        var response = await _httpClient.PostAsJsonAsync("/api/vectors/batch", request);
        
        if (!response.IsSuccessStatusCode)
            return 0;

        var result = await response.Content.ReadFromJsonAsync<BatchInsertResponse>();
        return result?.Inserted ?? 0;
    }

    /// <summary>
    /// Search for similar vectors (KNN)
    /// </summary>
    public async Task<List<SearchResult>> SearchAsync(float[] queryVector, int k = 10, string metric = "cosine")
    {
        var request = new
        {
            vector = queryVector.ToList(),
            k,
            metric
        };

        var response = await _httpClient.PostAsJsonAsync("/api/search/knn", request);
        
        if (!response.IsSuccessStatusCode)
            return new List<SearchResult>();

        var result = await response.Content.ReadFromJsonAsync<SearchResponse>();
        return result?.Results ?? new List<SearchResult>();
    }

    /// <summary>
    /// Get vector by ID
    /// </summary>
    public async Task<VectorResponse?> GetVectorAsync(string id)
    {
        var response = await _httpClient.GetAsync($"/api/vectors/{id}");
        
        if (!response.IsSuccessStatusCode)
            return null;

        return await response.Content.ReadFromJsonAsync<VectorResponse>();
    }

    /// <summary>
    /// Delete a vector
    /// </summary>
    public async Task<bool> DeleteVectorAsync(string id)
    {
        var response = await _httpClient.DeleteAsync($"/api/vectors/{id}");
        return response.IsSuccessStatusCode;
    }

    /// <summary>
    /// Create an index
    /// </summary>
    public async Task<bool> CreateIndexAsync(string name, string table, string column, 
        string indexType = "hnsw", string metric = "cosine", Dictionary<string, object>? parameters = null)
    {
        var request = new
        {
            name,
            table,
            column,
            indexType,
            metric,
            parameters
        };

        var response = await _httpClient.PostAsJsonAsync("/api/indexes", request);
        return response.IsSuccessStatusCode;
    }

    /// <summary>
    /// List all indexes
    /// </summary>
    public async Task<List<IndexResponse>> ListIndexesAsync()
    {
        var response = await _httpClient.GetAsync("/api/indexes");
        
        if (!response.IsSuccessStatusCode)
            return new List<IndexResponse>();

        var result = await response.Content.ReadFromJsonAsync<IndexListResponse>();
        return result?.Indexes ?? new List<IndexResponse>();
    }
}

// Response models
public record LoginResponse(string Token, string RefreshToken, DateTime ExpiresAt);
public record BatchInsertResponse(int Inserted, string Message);
public record SearchResponse(List<SearchResult> Results, int TotalResults, double QueryTimeMs);
public record SearchResult(string Id, float Distance, float Similarity, Dictionary<string, object>? Metadata);
public record VectorResponse(string Id, List<float> Vector, Dictionary<string, object>? Metadata, DateTime? CreatedAt, DateTime? UpdatedAt);
public record IndexResponse(string Name, string Type, string Metric, long VectorCount, DateTime CreatedAt, string Status);
public record IndexListResponse(List<IndexResponse> Indexes);

/// <summary>
/// Example usage
/// </summary>
public class Program
{
    public static async Task Main(string[] args)
    {
        var client = new SfvectorClient("http://localhost:5000");

        // Login
        Console.WriteLine("Logging in...");
        var loginSuccess = await client.LoginAsync("admin", "password");
        if (!loginSuccess)
        {
            Console.WriteLine("Login failed!");
            return;
        }
        Console.WriteLine("✓ Logged in successfully");

        // Generate random vectors (simulating embeddings)
        var random = new Random();
        float[] GenerateVector(int dim) => 
            Enumerable.Range(0, dim).Select(_ => (float)random.NextDouble()).ToArray();

        // Insert vectors
        Console.WriteLine("\nInserting vectors...");
        await client.InsertVectorAsync("doc1", GenerateVector(1536), new Dictionary<string, object>
        {
            ["title"] = "Introduction to Machine Learning",
            ["category"] = "AI"
        });
        await client.InsertVectorAsync("doc2", GenerateVector(1536), new Dictionary<string, object>
        {
            ["title"] = "Deep Learning Fundamentals",
            ["category"] = "AI"
        });
        await client.InsertVectorAsync("doc3", GenerateVector(1536), new Dictionary<string, object>
        {
            ["title"] = "Database Optimization",
            ["category"] = "Database"
        });
        Console.WriteLine("✓ Inserted 3 vectors");

        // Batch insert
        Console.WriteLine("\nBatch inserting vectors...");
        var batchVectors = Enumerable.Range(4, 10)
            .Select(i => (
                id: $"doc{i}",
                vector: GenerateVector(1536),
                metadata: new Dictionary<string, object> { ["title"] = $"Document {i}", ["category"] = "General" }
            ))
            .ToList();

        var inserted = await client.BatchInsertAsync(batchVectors);
        Console.WriteLine($"✓ Batch inserted {inserted} vectors");

        // Search
        Console.WriteLine("\nSearching for similar vectors...");
        var queryVector = GenerateVector(1536);
        var results = await client.SearchAsync(queryVector, k: 5, metric: "cosine");

        Console.WriteLine($"Found {results.Count} similar vectors:");
        foreach (var result in results)
        {
            Console.WriteLine($"  - {result.Id}: similarity={result.Similarity:F3}, distance={result.Distance:F3}");
        }

        // Get specific vector
        Console.WriteLine("\nRetrieving vector 'doc1'...");
        var vector = await client.GetVectorAsync("doc1");
        if (vector != null)
        {
            Console.WriteLine($"✓ Retrieved vector: {vector.Id}");
            Console.WriteLine($"  Dimension: {vector.Vector.Count}");
            Console.WriteLine($"  Metadata: {JsonSerializer.Serialize(vector.Metadata)}");
        }

        // Create index
        Console.WriteLine("\nCreating HNSW index...");
        var indexCreated = await client.CreateIndexAsync(
            name: "vectors_hnsw",
            table: "VectorsTest_FAISS",
            column: "vector",
            indexType: "hnsw",
            metric: "cosine",
            parameters: new Dictionary<string, object>
            {
                ["M"] = 32,
                ["efConstruction"] = 200
            }
        );
        Console.WriteLine(indexCreated ? "✓ Index created" : "✗ Index creation failed");

        // List indexes
        Console.WriteLine("\nListing indexes...");
        var indexes = await client.ListIndexesAsync();
        Console.WriteLine($"Found {indexes.Count} indexes:");
        foreach (var index in indexes)
        {
            Console.WriteLine($"  - {index.Name}: {index.Type} ({index.VectorCount} vectors)");
        }

        Console.WriteLine("\n✓ All operations completed successfully!");
    }
}
