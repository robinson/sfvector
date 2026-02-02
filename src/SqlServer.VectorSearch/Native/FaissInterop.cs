/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


using System;
using System.Runtime.InteropServices;

namespace SqlServer.VectorSearch.Native
{
    /// <summary>
    /// P/Invoke interop layer for calling native FAISS library
    /// </summary>
    public static class FaissInterop
    {
        // Platform-specific library names
        private const string LibraryName = "SqlServer.VectorSearch.Native";

        #region Index Creation and Destruction

        /// <summary>
        /// Create a new FAISS index
        /// </summary>
        /// <param name="indexType">Index type (e.g., "Flat", "HNSW", "IVF")</param>
        /// <param name="dimension">Vector dimension</param>
        /// <param name="metric">Metric type (L2, IP, COSINE)</param>
        /// <returns>Pointer to index handle</returns>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr faiss_create_index(
            [MarshalAs(UnmanagedType.LPStr)] string indexType,
            int dimension,
            [MarshalAs(UnmanagedType.LPStr)] string metric);

        /// <summary>
        /// Create an HNSW index with specific parameters
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr faiss_create_hnsw_index(
            int dimension,
            int M,
            [MarshalAs(UnmanagedType.LPStr)] string metric);

        /// <summary>
        /// Create an IVF index with specific parameters
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr faiss_create_ivf_index(
            int dimension,
            int nlist,
            [MarshalAs(UnmanagedType.LPStr)] string metric);

        /// <summary>
        /// Destroy a FAISS index and free memory
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void faiss_destroy_index(IntPtr index);

        #endregion

        #region Vector Operations

        /// <summary>
        /// Add vectors to the index
        /// </summary>
        /// <param name="index">Index handle</param>
        /// <param name="vectors">Flat array of vectors (dimension * count)</param>
        /// <param name="count">Number of vectors</param>
        /// <returns>0 on success, error code otherwise</returns>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_add_vectors(
            IntPtr index,
            float[] vectors,
            long count);

        /// <summary>
        /// Add vectors with explicit IDs
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_add_vectors_with_ids(
            IntPtr index,
            float[] vectors,
            long[] ids,
            long count);

        /// <summary>
        /// Remove vectors by ID
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_remove_ids(
            IntPtr index,
            long[] ids,
            long count);

        #endregion

        #region Search Operations

        /// <summary>
        /// Search for k nearest neighbors
        /// </summary>
        /// <param name="index">Index handle</param>
        /// <param name="query">Query vector</param>
        /// <param name="k">Number of neighbors to find</param>
        /// <param name="resultIds">Output: IDs of nearest neighbors</param>
        /// <param name="resultDistances">Output: Distances to neighbors</param>
        /// <returns>0 on success, error code otherwise</returns>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_search(
            IntPtr index,
            float[] query,
            int k,
            [Out] long[] resultIds,
            [Out] float[] resultDistances);

        /// <summary>
        /// Batch search for multiple query vectors
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_search_batch(
            IntPtr index,
            float[] queries,
            int queryCount,
            int k,
            [Out] long[] resultIds,
            [Out] float[] resultDistances);

        /// <summary>
        /// Range search: find all neighbors within radius
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_range_search(
            IntPtr index,
            float[] query,
            float radius,
            out IntPtr resultIds,
            out IntPtr resultDistances,
            out long resultCount);

        #endregion

        #region Index Persistence

        /// <summary>
        /// Save index to disk
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_save_index(
            IntPtr index,
            [MarshalAs(UnmanagedType.LPStr)] string filePath);

        /// <summary>
        /// Load index from disk
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr faiss_load_index(
            [MarshalAs(UnmanagedType.LPStr)] string filePath);

        #endregion

        #region Index Information

        /// <summary>
        /// Get total number of vectors in index
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern long faiss_get_ntotal(IntPtr index);

        /// <summary>
        /// Get dimension of vectors in index
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_get_dimension(IntPtr index);

        /// <summary>
        /// Check if index is trained
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool faiss_is_trained(IntPtr index);

        #endregion

        #region Training (for IVF and other indexes that require it)

        /// <summary>
        /// Train index on sample vectors
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_train(
            IntPtr index,
            float[] vectors,
            long count);

        #endregion

        #region HNSW Specific Parameters

        /// <summary>
        /// Set HNSW efSearch parameter (search time quality/speed tradeoff)
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_hnsw_set_ef_search(IntPtr index, int efSearch);

        /// <summary>
        /// Set HNSW efConstruction parameter (index build quality)
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_hnsw_set_ef_construction(IntPtr index, int efConstruction);

        #endregion

        #region IVF Specific Parameters

        /// <summary>
        /// Set IVF nprobe parameter (number of clusters to search)
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int faiss_ivf_set_nprobe(IntPtr index, int nprobe);

        #endregion

        #region Error Handling

        /// <summary>
        /// Get last error message from native library
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr faiss_get_last_error();

        /// <summary>
        /// Helper to get error message as managed string
        /// </summary>
        public static string GetLastErrorMessage()
        {
            IntPtr errorPtr = faiss_get_last_error();
            if (errorPtr == IntPtr.Zero)
                return null;
            
            return Marshal.PtrToStringAnsi(errorPtr);
        }

        #endregion

        #region Memory Management Helpers

        /// <summary>
        /// Free memory allocated by native library
        /// </summary>
        [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
        public static extern void faiss_free(IntPtr ptr);

        #endregion
    }

    /// <summary>
    /// Supported FAISS index types
    /// </summary>
    public enum FaissIndexType
    {
        Flat,
        HNSW,
        IVF,
        IVFPQ,
        IVFFlat
    }

    /// <summary>
    /// Supported distance metrics
    /// </summary>
    public enum FaissMetric
    {
        L2,           // Euclidean distance
        IP,           // Inner product
        Cosine        // Cosine similarity
    }

    /// <summary>
    /// FAISS error codes
    /// </summary>
    public enum FaissErrorCode
    {
        Success = 0,
        InvalidParameter = -1,
        OutOfMemory = -2,
        IndexNotTrained = -3,
        DimensionMismatch = -4,
        IOError = -5,
        UnknownError = -999
    }
}
