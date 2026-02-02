/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


#include "faiss_wrapper.h"
#include <faiss/IndexFlat.h>
#include <faiss/IndexHNSW.h>
#include <faiss/IndexIVFFlat.h>
#include <faiss/IndexIVFPQ.h>
#include <faiss/index_io.h>
#include <faiss/MetricType.h>
#include <string>
#include <cstring>
#include <exception>
#include <memory>

// Thread-local error storage
static thread_local std::string g_lastError;

// Helper to set error message
static void SetError(const std::string& message) {
    g_lastError = message;
}

// Helper to clear error
static void ClearError() {
    g_lastError.clear();
}

// Helper to convert metric string to FAISS MetricType
static faiss::MetricType ParseMetric(const char* metric) {
    if (metric == nullptr) {
        return faiss::METRIC_L2;
    }
    
    std::string metricStr(metric);
    if (metricStr == "L2" || metricStr == "EUCLIDEAN") {
        return faiss::METRIC_L2;
    } else if (metricStr == "IP" || metricStr == "INNER_PRODUCT" || metricStr == "DOT") {
        return faiss::METRIC_INNER_PRODUCT;
    } else if (metricStr == "COSINE") {
        // FAISS doesn't have native cosine, but we can normalize vectors
        // and use inner product
        return faiss::METRIC_INNER_PRODUCT;
    }
    
    return faiss::METRIC_L2; // default
}

// =============================================================================
// Index Creation and Destruction
// =============================================================================

FAISS_API FaissIndexHandle faiss_create_index(
    const char* indexType,
    int dimension,
    const char* metric)
{
    try {
        ClearError();
        
        if (dimension <= 0) {
            SetError("Invalid dimension");
            return nullptr;
        }
        
        faiss::MetricType metricType = ParseMetric(metric);
        std::string typeStr(indexType);
        
        faiss::Index* index = nullptr;
        
        if (typeStr == "Flat" || typeStr == "FLAT") {
            if (metricType == faiss::METRIC_L2) {
                index = new faiss::IndexFlatL2(dimension);
            } else {
                index = new faiss::IndexFlatIP(dimension);
            }
        } else if (typeStr == "HNSW") {
            // Default HNSW parameters: M=32
            index = new faiss::IndexHNSWFlat(dimension, 32, metricType);
        } else if (typeStr == "IVF" || typeStr == "IVFFlat") {
            // Default: 100 clusters
            faiss::IndexFlat* quantizer;
            if (metricType == faiss::METRIC_L2) {
                quantizer = new faiss::IndexFlatL2(dimension);
            } else {
                quantizer = new faiss::IndexFlatIP(dimension);
            }
            index = new faiss::IndexIVFFlat(quantizer, dimension, 100, metricType);
        } else {
            SetError("Unsupported index type: " + typeStr);
            return nullptr;
        }
        
        return static_cast<FaissIndexHandle>(index);
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return nullptr;
    }
}

FAISS_API FaissIndexHandle faiss_create_hnsw_index(
    int dimension,
    int M,
    const char* metric)
{
    try {
        ClearError();
        
        if (dimension <= 0 || M <= 0) {
            SetError("Invalid parameters");
            return nullptr;
        }
        
        faiss::MetricType metricType = ParseMetric(metric);
        faiss::IndexHNSWFlat* index = new faiss::IndexHNSWFlat(dimension, M, metricType);
        
        return static_cast<FaissIndexHandle>(index);
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return nullptr;
    }
}

FAISS_API FaissIndexHandle faiss_create_ivf_index(
    int dimension,
    int nlist,
    const char* metric)
{
    try {
        ClearError();
        
        if (dimension <= 0 || nlist <= 0) {
            SetError("Invalid parameters");
            return nullptr;
        }
        
        faiss::MetricType metricType = ParseMetric(metric);
        
        faiss::IndexFlat* quantizer;
        if (metricType == faiss::METRIC_L2) {
            quantizer = new faiss::IndexFlatL2(dimension);
        } else {
            quantizer = new faiss::IndexFlatIP(dimension);
        }
        
        faiss::IndexIVFFlat* index = new faiss::IndexIVFFlat(
            quantizer, dimension, nlist, metricType);
        
        return static_cast<FaissIndexHandle>(index);
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return nullptr;
    }
}

FAISS_API void faiss_destroy_index(FaissIndexHandle handle)
{
    if (handle != nullptr) {
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        delete index;
    }
}

// =============================================================================
// Vector Operations
// =============================================================================

FAISS_API int faiss_add_vectors(
    FaissIndexHandle handle,
    const float* vectors,
    long long count)
{
    try {
        ClearError();
        
        if (handle == nullptr || vectors == nullptr || count <= 0) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        
        // Check if index needs training
        if (!index->is_trained) {
            SetError("Index is not trained");
            return FAISS_ERROR_NOT_TRAINED;
        }
        
        index->add(count, vectors);
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

FAISS_API int faiss_add_vectors_with_ids(
    FaissIndexHandle handle,
    const float* vectors,
    const long long* ids,
    long long count)
{
    try {
        ClearError();
        
        if (handle == nullptr || vectors == nullptr || ids == nullptr || count <= 0) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        
        if (!index->is_trained) {
            SetError("Index is not trained");
            return FAISS_ERROR_NOT_TRAINED;
        }
        
        index->add_with_ids(count, vectors, ids);
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

FAISS_API int faiss_remove_ids(
    FaissIndexHandle handle,
    const long long* ids,
    long long count)
{
    try {
        ClearError();
        
        if (handle == nullptr || ids == nullptr || count <= 0) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        
        // Create IDSelector for the IDs to remove
        faiss::IDSelectorBatch selector(count, ids);
        size_t removed = index->remove_ids(selector);
        
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

// =============================================================================
// Search Operations
// =============================================================================

FAISS_API int faiss_search(
    FaissIndexHandle handle,
    const float* query,
    int k,
    long long* resultIds,
    float* resultDistances)
{
    try {
        ClearError();
        
        if (handle == nullptr || query == nullptr || k <= 0 || 
            resultIds == nullptr || resultDistances == nullptr) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        
        // Search for single query
        index->search(1, query, k, resultDistances, resultIds);
        
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

FAISS_API int faiss_search_batch(
    FaissIndexHandle handle,
    const float* queries,
    int queryCount,
    int k,
    long long* resultIds,
    float* resultDistances)
{
    try {
        ClearError();
        
        if (handle == nullptr || queries == nullptr || queryCount <= 0 || k <= 0 ||
            resultIds == nullptr || resultDistances == nullptr) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        
        index->search(queryCount, queries, k, resultDistances, resultIds);
        
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

FAISS_API int faiss_range_search(
    FaissIndexHandle handle,
    const float* query,
    float radius,
    long long** resultIds,
    float** resultDistances,
    long long* resultCount)
{
    try {
        ClearError();
        
        if (handle == nullptr || query == nullptr || 
            resultIds == nullptr || resultDistances == nullptr || resultCount == nullptr) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        
        faiss::RangeSearchResult result(1);
        index->range_search(1, query, radius, &result);
        
        *resultCount = result.lims[1] - result.lims[0];
        
        if (*resultCount > 0) {
            *resultIds = new long long[*resultCount];
            *resultDistances = new float[*resultCount];
            
            std::memcpy(*resultIds, result.labels + result.lims[0], 
                       *resultCount * sizeof(long long));
            std::memcpy(*resultDistances, result.distances + result.lims[0], 
                       *resultCount * sizeof(float));
        } else {
            *resultIds = nullptr;
            *resultDistances = nullptr;
        }
        
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

// =============================================================================
// Index Persistence
// =============================================================================

FAISS_API int faiss_save_index(
    FaissIndexHandle handle,
    const char* filePath)
{
    try {
        ClearError();
        
        if (handle == nullptr || filePath == nullptr) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        faiss::write_index(index, filePath);
        
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_IO;
    }
}

FAISS_API FaissIndexHandle faiss_load_index(const char* filePath)
{
    try {
        ClearError();
        
        if (filePath == nullptr) {
            SetError("Invalid file path");
            return nullptr;
        }
        
        faiss::Index* index = faiss::read_index(filePath);
        return static_cast<FaissIndexHandle>(index);
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return nullptr;
    }
}

// =============================================================================
// Index Information
// =============================================================================

FAISS_API long long faiss_get_ntotal(FaissIndexHandle handle)
{
    if (handle == nullptr) {
        return -1;
    }
    
    faiss::Index* index = static_cast<faiss::Index*>(handle);
    return index->ntotal;
}

FAISS_API int faiss_get_dimension(FaissIndexHandle handle)
{
    if (handle == nullptr) {
        return -1;
    }
    
    faiss::Index* index = static_cast<faiss::Index*>(handle);
    return index->d;
}

FAISS_API int faiss_is_trained(FaissIndexHandle handle)
{
    if (handle == nullptr) {
        return -1;
    }
    
    faiss::Index* index = static_cast<faiss::Index*>(handle);
    return index->is_trained ? 1 : 0;
}

// =============================================================================
// Training
// =============================================================================

FAISS_API int faiss_train(
    FaissIndexHandle handle,
    const float* vectors,
    long long count)
{
    try {
        ClearError();
        
        if (handle == nullptr || vectors == nullptr || count <= 0) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        index->train(count, vectors);
        
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

// =============================================================================
// HNSW Specific Parameters
// =============================================================================

FAISS_API int faiss_hnsw_set_ef_search(FaissIndexHandle handle, int efSearch)
{
    try {
        ClearError();
        
        if (handle == nullptr || efSearch <= 0) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        faiss::IndexHNSW* hnsw = dynamic_cast<faiss::IndexHNSW*>(index);
        
        if (hnsw == nullptr) {
            SetError("Index is not HNSW type");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        hnsw->hnsw.efSearch = efSearch;
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

FAISS_API int faiss_hnsw_set_ef_construction(FaissIndexHandle handle, int efConstruction)
{
    try {
        ClearError();
        
        if (handle == nullptr || efConstruction <= 0) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        faiss::IndexHNSW* hnsw = dynamic_cast<faiss::IndexHNSW*>(index);
        
        if (hnsw == nullptr) {
            SetError("Index is not HNSW type");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        hnsw->hnsw.efConstruction = efConstruction;
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

// =============================================================================
// IVF Specific Parameters
// =============================================================================

FAISS_API int faiss_ivf_set_nprobe(FaissIndexHandle handle, int nprobe)
{
    try {
        ClearError();
        
        if (handle == nullptr || nprobe <= 0) {
            SetError("Invalid parameters");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        faiss::Index* index = static_cast<faiss::Index*>(handle);
        faiss::IndexIVF* ivf = dynamic_cast<faiss::IndexIVF*>(index);
        
        if (ivf == nullptr) {
            SetError("Index is not IVF type");
            return FAISS_ERROR_INVALID_PARAM;
        }
        
        ivf->nprobe = nprobe;
        return FAISS_SUCCESS;
        
    } catch (const std::exception& e) {
        SetError(std::string("Exception: ") + e.what());
        return FAISS_ERROR_UNKNOWN;
    }
}

// =============================================================================
// Error Handling
// =============================================================================

FAISS_API const char* faiss_get_last_error()
{
    if (g_lastError.empty()) {
        return nullptr;
    }
    return g_lastError.c_str();
}

FAISS_API void faiss_clear_error()
{
    ClearError();
}

// =============================================================================
// Memory Management
// =============================================================================

FAISS_API void faiss_free(void* ptr)
{
    if (ptr != nullptr) {
        delete[] static_cast<char*>(ptr);
    }
}
