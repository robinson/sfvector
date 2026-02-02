/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using Sfvector.Api.Models.DTOs;

namespace Sfvector.Api.Services;

/// <summary>
/// Vector service interface
/// </summary>
public interface IVectorService
{
    Task<VectorResponse> CreateVectorAsync(VectorCreateRequest request);
    Task<BatchInsertResponse> BatchInsertAsync(BatchInsertRequest request);
    Task<VectorResponse?> GetVectorAsync(string id);
    Task<VectorListResponse> ListVectorsAsync(int page, int pageSize);
    Task<VectorResponse?> UpdateVectorAsync(string id, VectorUpdateRequest request);
    Task<bool> DeleteVectorAsync(string id);
    Task<long> GetCountAsync();
}

/// <summary>
/// Search service interface
/// </summary>
public interface ISearchService
{
    Task<List<SearchResult>> KnnSearchAsync(KnnSearchRequest request);
    Task<List<SearchResult>> RangeSearchAsync(RangeSearchRequest request);
    Task<List<SearchResult>> HybridSearchAsync(HybridSearchRequest request);
}

/// <summary>
/// Index service interface
/// </summary>
public interface IIndexService
{
    Task<IndexResponse> CreateIndexAsync(IndexCreateRequest request);
    Task<List<IndexResponse>> ListIndexesAsync();
    Task<IndexResponse?> GetIndexAsync(string name);
    Task<IndexStatsResponse?> GetIndexStatsAsync(string name);
    Task<IndexRebuildResponse?> RebuildIndexAsync(string name);
    Task<bool> DeleteIndexAsync(string name);
}

/// <summary>
/// Authentication service interface
/// </summary>
public interface IAuthService
{
    Task<LoginResponse?> LoginAsync(LoginRequest request);
    Task<LoginResponse?> RefreshTokenAsync(RefreshTokenRequest request);
    string GenerateJwtToken(string username);
    string GenerateRefreshToken();
}
