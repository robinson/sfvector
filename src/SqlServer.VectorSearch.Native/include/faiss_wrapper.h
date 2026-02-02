/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


#ifndef FAISS_WRAPPER_H
#define FAISS_WRAPPER_H

#ifdef _WIN32
    #ifdef FAISS_WRAPPER_EXPORTS
        #define FAISS_API __declspec(dllexport)
    #else
        #define FAISS_API __declspec(dllimport)
    #endif
#else
    #define FAISS_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle for FAISS index
typedef void* FaissIndexHandle;

// Error codes
typedef enum {
    FAISS_SUCCESS = 0,
    FAISS_ERROR_INVALID_PARAM = -1,
    FAISS_ERROR_OUT_OF_MEMORY = -2,
    FAISS_ERROR_NOT_TRAINED = -3,
    FAISS_ERROR_DIMENSION_MISMATCH = -4,
    FAISS_ERROR_IO = -5,
    FAISS_ERROR_UNKNOWN = -999
} FaissErrorCode;

// Metric types
typedef enum {
    FAISS_METRIC_L2 = 0,
    FAISS_METRIC_INNER_PRODUCT = 1,
    FAISS_METRIC_COSINE = 2
} FaissMetricType;

// Index types
typedef enum {
    FAISS_INDEX_FLAT = 0,
    FAISS_INDEX_HNSW = 1,
    FAISS_INDEX_IVF = 2,
    FAISS_INDEX_IVFPQ = 3,
    FAISS_INDEX_IVFFLAT = 4
} FaissIndexTypeEnum;

// =============================================================================
// Index Creation and Destruction
// =============================================================================

/**
 * Create a new FAISS index
 * @param indexType Index type string (e.g., "Flat", "HNSW", "IVF")
 * @param dimension Vector dimension
 * @param metric Metric type string (e.g., "L2", "IP", "COSINE")
 * @return Handle to the created index, or NULL on error
 */
FAISS_API FaissIndexHandle faiss_create_index(
    const char* indexType,
    int dimension,
    const char* metric);

/**
 * Create an HNSW index with specific parameters
 * @param dimension Vector dimension
 * @param M Number of connections per layer (typical: 16-64)
 * @param metric Metric type string
 * @return Handle to the created index, or NULL on error
 */
FAISS_API FaissIndexHandle faiss_create_hnsw_index(
    int dimension,
    int M,
    const char* metric);

/**
 * Create an IVF index with specific parameters
 * @param dimension Vector dimension
 * @param nlist Number of clusters (typical: sqrt(N) where N is dataset size)
 * @param metric Metric type string
 * @return Handle to the created index, or NULL on error
 */
FAISS_API FaissIndexHandle faiss_create_ivf_index(
    int dimension,
    int nlist,
    const char* metric);

/**
 * Destroy a FAISS index and free memory
 * @param index Index handle to destroy
 */
FAISS_API void faiss_destroy_index(FaissIndexHandle index);

// =============================================================================
// Vector Operations
// =============================================================================

/**
 * Add vectors to the index (auto-assigned IDs)
 * @param index Index handle
 * @param vectors Flat array of vectors (dimension * count floats)
 * @param count Number of vectors to add
 * @return Error code (0 = success)
 */
FAISS_API int faiss_add_vectors(
    FaissIndexHandle index,
    const float* vectors,
    long long count);

/**
 * Add vectors with explicit IDs
 * @param index Index handle
 * @param vectors Flat array of vectors
 * @param ids Array of IDs (must be same length as count)
 * @param count Number of vectors to add
 * @return Error code (0 = success)
 */
FAISS_API int faiss_add_vectors_with_ids(
    FaissIndexHandle index,
    const float* vectors,
    const long long* ids,
    long long count);

/**
 * Remove vectors by ID
 * @param index Index handle
 * @param ids Array of IDs to remove
 * @param count Number of IDs
 * @return Error code (0 = success)
 */
FAISS_API int faiss_remove_ids(
    FaissIndexHandle index,
    const long long* ids,
    long long count);

// =============================================================================
// Search Operations
// =============================================================================

/**
 * Search for k nearest neighbors
 * @param index Index handle
 * @param query Query vector (dimension floats)
 * @param k Number of neighbors to find
 * @param resultIds Output array for neighbor IDs (size k)
 * @param resultDistances Output array for distances (size k)
 * @return Error code (0 = success)
 */
FAISS_API int faiss_search(
    FaissIndexHandle index,
    const float* query,
    int k,
    long long* resultIds,
    float* resultDistances);

/**
 * Batch search for multiple query vectors
 * @param index Index handle
 * @param queries Query vectors (dimension * queryCount floats)
 * @param queryCount Number of queries
 * @param k Number of neighbors per query
 * @param resultIds Output array (size queryCount * k)
 * @param resultDistances Output array (size queryCount * k)
 * @return Error code (0 = success)
 */
FAISS_API int faiss_search_batch(
    FaissIndexHandle index,
    const float* queries,
    int queryCount,
    int k,
    long long* resultIds,
    float* resultDistances);

/**
 * Range search: find all neighbors within radius
 * @param index Index handle
 * @param query Query vector
 * @param radius Search radius
 * @param resultIds Output pointer to IDs array (caller must free)
 * @param resultDistances Output pointer to distances array (caller must free)
 * @param resultCount Output: number of results found
 * @return Error code (0 = success)
 */
FAISS_API int faiss_range_search(
    FaissIndexHandle index,
    const float* query,
    float radius,
    long long** resultIds,
    float** resultDistances,
    long long* resultCount);

// =============================================================================
// Index Persistence
// =============================================================================

/**
 * Save index to disk
 * @param index Index handle
 * @param filePath Path to save file
 * @return Error code (0 = success)
 */
FAISS_API int faiss_save_index(
    FaissIndexHandle index,
    const char* filePath);

/**
 * Load index from disk
 * @param filePath Path to index file
 * @return Handle to loaded index, or NULL on error
 */
FAISS_API FaissIndexHandle faiss_load_index(const char* filePath);

// =============================================================================
// Index Information
// =============================================================================

/**
 * Get total number of vectors in index
 * @param index Index handle
 * @return Number of vectors, or -1 on error
 */
FAISS_API long long faiss_get_ntotal(FaissIndexHandle index);

/**
 * Get dimension of vectors in index
 * @param index Index handle
 * @return Dimension, or -1 on error
 */
FAISS_API int faiss_get_dimension(FaissIndexHandle index);

/**
 * Check if index is trained
 * @param index Index handle
 * @return 1 if trained, 0 if not, -1 on error
 */
FAISS_API int faiss_is_trained(FaissIndexHandle index);

// =============================================================================
// Training (for IVF and other indexes)
// =============================================================================

/**
 * Train index on sample vectors
 * @param index Index handle
 * @param vectors Training vectors (dimension * count floats)
 * @param count Number of training vectors
 * @return Error code (0 = success)
 */
FAISS_API int faiss_train(
    FaissIndexHandle index,
    const float* vectors,
    long long count);

// =============================================================================
// HNSW Specific Parameters
// =============================================================================

/**
 * Set HNSW efSearch parameter (controls search quality/speed)
 * Higher = more accurate but slower (typical: 16-512)
 * @param index Index handle
 * @param efSearch Parameter value
 * @return Error code (0 = success)
 */
FAISS_API int faiss_hnsw_set_ef_search(FaissIndexHandle index, int efSearch);

/**
 * Set HNSW efConstruction parameter (controls index build quality)
 * Higher = better quality but slower build (typical: 40-500)
 * @param index Index handle
 * @param efConstruction Parameter value
 * @return Error code (0 = success)
 */
FAISS_API int faiss_hnsw_set_ef_construction(FaissIndexHandle index, int efConstruction);

// =============================================================================
// IVF Specific Parameters
// =============================================================================

/**
 * Set IVF nprobe parameter (number of clusters to search)
 * Higher = more accurate but slower (typical: 1-nlist/10)
 * @param index Index handle
 * @param nprobe Number of probes
 * @return Error code (0 = success)
 */
FAISS_API int faiss_ivf_set_nprobe(FaissIndexHandle index, int nprobe);

// =============================================================================
// Error Handling
// =============================================================================

/**
 * Get last error message
 * @return Pointer to error string, or NULL if no error
 */
FAISS_API const char* faiss_get_last_error();

/**
 * Clear the last error
 */
FAISS_API void faiss_clear_error();

// =============================================================================
// Memory Management
// =============================================================================

/**
 * Free memory allocated by the library
 * @param ptr Pointer to free
 */
FAISS_API void faiss_free(void* ptr);

#ifdef __cplusplus
}
#endif

#endif // FAISS_WRAPPER_H
