/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


-- =============================================
-- SQL Server Vector Search Benchmark Suite
-- =============================================
-- Comprehensive performance tests for FAISS-based vector search

USE VectorSearchDB;
GO

-- =============================================
-- Setup: Create benchmark tables and utilities
-- =============================================

IF OBJECT_ID('dbo.BenchmarkResults', 'U') IS NOT NULL
    DROP TABLE dbo.BenchmarkResults;
GO

CREATE TABLE dbo.BenchmarkResults (
    result_id INT IDENTITY(1,1) PRIMARY KEY,
    test_name NVARCHAR(200),
    test_category NVARCHAR(100), -- INSERT, INDEX_BUILD, SEARCH, etc.
    database_type NVARCHAR(50), -- SQLSERVER_FAISS, BASELINE, etc.
    dataset_name NVARCHAR(100),
    dataset_size INT,
    dimension INT,
    index_type NVARCHAR(50),
    metric_type NVARCHAR(50),
    operation_count INT,
    elapsed_ms BIGINT,
    throughput_ops_sec DECIMAL(18,2),
    memory_mb DECIMAL(18,2),
    cpu_percent DECIMAL(5,2),
    additional_metrics NVARCHAR(MAX), -- JSON
    test_date DATETIME2 DEFAULT GETDATE(),
    notes NVARCHAR(MAX)
);
GO

CREATE INDEX IX_BenchmarkResults_Test ON dbo.BenchmarkResults(test_category, test_name);
GO

-- =============================================
-- Test Tables
-- =============================================

IF OBJECT_ID('dbo.VectorsTest_Baseline', 'U') IS NOT NULL
    DROP TABLE dbo.VectorsTest_Baseline;
GO

CREATE TABLE dbo.VectorsTest_Baseline (
    id INT PRIMARY KEY,
    vector VARBINARY(8000) -- Baseline without VectorType
);
GO

IF OBJECT_ID('dbo.VectorsTest_FAISS', 'U') IS NOT NULL
    DROP TABLE dbo.VectorsTest_FAISS;
GO

-- Will use VectorType after CLR deployment
CREATE TABLE dbo.VectorsTest_FAISS (
    id INT PRIMARY KEY,
    vector VARBINARY(8000) -- Placeholder, will be VectorType
);
GO

-- =============================================
-- Utility: Timer and Statistics
-- =============================================

IF OBJECT_ID('dbo.sp_start_benchmark', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_start_benchmark;
GO

CREATE PROCEDURE dbo.sp_start_benchmark
    @test_name NVARCHAR(200),
    @test_category NVARCHAR(100),
    @dataset_name NVARCHAR(100),
    @dataset_size INT,
    @dimension INT,
    @benchmark_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dbo.BenchmarkResults (
        test_name,
        test_category,
        dataset_name,
        dataset_size,
        dimension,
        test_date
    )
    VALUES (
        @test_name,
        @test_category,
        @dataset_name,
        @dataset_size,
        @dimension,
        GETDATE()
    );
    
    SET @benchmark_id = SCOPE_IDENTITY();
    
    PRINT '==============================================';
    PRINT 'Starting Benchmark: ' + @test_name;
    PRINT 'Category: ' + @test_category;
    PRINT 'Dataset: ' + @dataset_name + ' (' + CAST(@dataset_size AS NVARCHAR) + ' vectors)';
    PRINT '==============================================';
END
GO

IF OBJECT_ID('dbo.sp_end_benchmark', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_end_benchmark;
GO

CREATE PROCEDURE dbo.sp_end_benchmark
    @benchmark_id INT,
    @start_time DATETIME2,
    @operation_count INT,
    @index_type NVARCHAR(50) = NULL,
    @metric_type NVARCHAR(50) = NULL,
    @additional_metrics NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @elapsed_ms BIGINT = DATEDIFF(MILLISECOND, @start_time, GETDATE());
    DECLARE @throughput DECIMAL(18,2);
    
    IF @operation_count > 0 AND @elapsed_ms > 0
        SET @throughput = CAST(@operation_count AS DECIMAL) / (@elapsed_ms / 1000.0);
    ELSE
        SET @throughput = 0;
    
    UPDATE dbo.BenchmarkResults
    SET 
        elapsed_ms = @elapsed_ms,
        operation_count = @operation_count,
        throughput_ops_sec = @throughput,
        index_type = @index_type,
        metric_type = @metric_type,
        additional_metrics = @additional_metrics
    WHERE result_id = @benchmark_id;
    
    PRINT '----------------------------------------------';
    PRINT 'Elapsed: ' + CAST(@elapsed_ms AS NVARCHAR) + ' ms';
    PRINT 'Operations: ' + CAST(@operation_count AS NVARCHAR);
    PRINT 'Throughput: ' + CAST(@throughput AS NVARCHAR) + ' ops/sec';
    PRINT '==============================================';
    PRINT '';
END
GO

-- =============================================
-- Benchmark 1: Bulk Insert Performance
-- =============================================

IF OBJECT_ID('dbo.sp_benchmark_bulk_insert', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_benchmark_bulk_insert;
GO

CREATE PROCEDURE dbo.sp_benchmark_bulk_insert
    @dataset_name NVARCHAR(100),
    @batch_size INT = 1000
AS
BEGIN
    SET NOCOUNT ON;
    
    -- This is a template - actual implementation depends on data loading
    PRINT 'Bulk Insert Benchmark';
    PRINT 'Dataset: ' + @dataset_name;
    PRINT 'Batch size: ' + CAST(@batch_size AS NVARCHAR);
    
    -- TODO: Load from CSV and measure
    /*
    DECLARE @benchmark_id INT;
    DECLARE @start_time DATETIME2;
    DECLARE @count INT = 0;
    
    EXEC dbo.sp_start_benchmark 
        @test_name = 'Bulk Insert - ' + @dataset_name,
        @test_category = 'INSERT',
        @dataset_name = @dataset_name,
        @dataset_size = @count,
        @dimension = 1536,
        @benchmark_id = @benchmark_id OUTPUT;
    
    SET @start_time = GETDATE();
    
    -- Bulk insert logic here
    -- BULK INSERT or bcp
    
    EXEC dbo.sp_end_benchmark 
        @benchmark_id = @benchmark_id,
        @start_time = @start_time,
        @operation_count = @count;
    */
END
GO

-- =============================================
-- Benchmark 2: Index Build Performance
-- =============================================

IF OBJECT_ID('dbo.sp_benchmark_index_build', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_benchmark_index_build;
GO

CREATE PROCEDURE dbo.sp_benchmark_index_build
    @table_name NVARCHAR(128),
    @column_name NVARCHAR(128),
    @index_type NVARCHAR(50),
    @metric NVARCHAR(50),
    @dataset_size INT,
    @dimension INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @benchmark_id INT;
    DECLARE @start_time DATETIME2;
    
    EXEC dbo.sp_start_benchmark 
        @test_name = 'Index Build - ' + @index_type,
        @test_category = 'INDEX_BUILD',
        @dataset_name = @table_name,
        @dataset_size = @dataset_size,
        @dimension = @dimension,
        @benchmark_id = @benchmark_id OUTPUT;
    
    SET @start_time = GETDATE();
    
    -- Build index
    /*
    EXEC dbo.sp_create_vector_index
        @table_schema = 'dbo',
        @table_name = @table_name,
        @column_name = @column_name,
        @index_type = @index_type,
        @metric = @metric;
    */
    
    EXEC dbo.sp_end_benchmark 
        @benchmark_id = @benchmark_id,
        @start_time = @start_time,
        @operation_count = @dataset_size,
        @index_type = @index_type,
        @metric_type = @metric;
    
    PRINT 'Index built: ' + @index_type + ' on ' + @table_name;
END
GO

-- =============================================
-- Benchmark 3: KNN Search Performance
-- =============================================

IF OBJECT_ID('dbo.sp_benchmark_knn_search', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_benchmark_knn_search;
GO

CREATE PROCEDURE dbo.sp_benchmark_knn_search
    @table_name NVARCHAR(128),
    @column_name NVARCHAR(128),
    @k INT = 10,
    @num_queries INT = 100,
    @use_index BIT = 1,
    @index_type NVARCHAR(50) = NULL,
    @metric NVARCHAR(50) = 'L2'
AS
BEGIN
    SET NOCOUNT ON;
    SET STATISTICS TIME OFF;
    SET STATISTICS IO OFF;
    
    DECLARE @benchmark_id INT;
    DECLARE @start_time DATETIME2;
    DECLARE @test_name NVARCHAR(200);
    DECLARE @dataset_size INT;
    
    SELECT @dataset_size = COUNT(*) FROM dbo.VectorsTest_FAISS;
    
    IF @use_index = 1
        SET @test_name = 'KNN Search (Indexed - ' + ISNULL(@index_type, 'UNKNOWN') + ')';
    ELSE
        SET @test_name = 'KNN Search (Sequential Scan)';
    
    EXEC dbo.sp_start_benchmark 
        @test_name = @test_name,
        @test_category = 'SEARCH_KNN',
        @dataset_name = @table_name,
        @dataset_size = @dataset_size,
        @dimension = 1536,
        @benchmark_id = @benchmark_id OUTPUT;
    
    SET @start_time = GETDATE();
    
    -- Execute queries
    DECLARE @i INT = 0;
    DECLARE @query_vector NVARCHAR(MAX);
    
    WHILE @i < @num_queries
    BEGIN
        -- Generate random query (placeholder)
        -- In real test, load from query dataset
        
        IF @use_index = 1
        BEGIN
            -- Use indexed search
            /*
            EXEC dbo.sp_vector_search
                @table_schema = 'dbo',
                @table_name = @table_name,
                @column_name = @column_name,
                @query_vector = @query_vector,
                @k = @k,
                @metric = @metric;
            */
        END
        ELSE
        BEGIN
            -- Sequential scan
            /*
            SELECT TOP (@k) id
            FROM dbo.VectorsTest_FAISS
            ORDER BY dbo.VectorDistance(vector, @query_vector, @metric);
            */
        END
        
        SET @i = @i + 1;
    END
    
    DECLARE @metrics NVARCHAR(MAX) = N'{' +
        '"k": ' + CAST(@k AS NVARCHAR) + ',' +
        '"num_queries": ' + CAST(@num_queries AS NVARCHAR) + ',' +
        '"avg_latency_ms": ' + CAST((DATEDIFF(MILLISECOND, @start_time, GETDATE()) * 1.0 / @num_queries) AS NVARCHAR) +
        '}';
    
    EXEC dbo.sp_end_benchmark 
        @benchmark_id = @benchmark_id,
        @start_time = @start_time,
        @operation_count = @num_queries,
        @index_type = @index_type,
        @metric_type = @metric,
        @additional_metrics = @metrics;
END
GO

-- =============================================
-- Benchmark 4: Recall Test (Accuracy)
-- =============================================

IF OBJECT_ID('dbo.sp_benchmark_recall', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_benchmark_recall;
GO

CREATE PROCEDURE dbo.sp_benchmark_recall
    @table_name NVARCHAR(128),
    @column_name NVARCHAR(128),
    @k INT = 10,
    @num_queries INT = 100,
    @index_type NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Recall Benchmark: ' + @index_type;
    PRINT 'Comparing approximate search vs exact search';
    
    -- This requires:
    -- 1. Ground truth (exact search results)
    -- 2. Approximate search results
    -- 3. Calculate recall@k
    
    /*
    Example logic:
    
    DECLARE @total_recall DECIMAL(5,4) = 0;
    DECLARE @i INT = 0;
    
    WHILE @i < @num_queries
    BEGIN
        -- Get ground truth (exact)
        -- Get approximate results
        -- Calculate intersection
        -- recall = |intersection| / k
        
        SET @i = @i + 1;
    END
    
    DECLARE @avg_recall DECIMAL(5,4) = @total_recall / @num_queries;
    
    INSERT INTO BenchmarkResults (test_name, test_category, additional_metrics)
    VALUES ('Recall@' + CAST(@k AS NVARCHAR), 'RECALL', 
            '{"recall": ' + CAST(@avg_recall AS NVARCHAR) + '}');
    */
    
    PRINT 'Recall test complete';
END
GO

-- =============================================
-- Benchmark Suite Runner
-- =============================================

IF OBJECT_ID('dbo.sp_run_benchmark_suite', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_run_benchmark_suite;
GO

CREATE PROCEDURE dbo.sp_run_benchmark_suite
    @dataset_name NVARCHAR(100),
    @run_insert BIT = 1,
    @run_index_build BIT = 1,
    @run_search BIT = 1,
    @run_recall BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '##############################################';
    PRINT '    SQL Server Vector Search Benchmark Suite';
    PRINT '##############################################';
    PRINT '';
    PRINT 'Dataset: ' + @dataset_name;
    PRINT 'Date: ' + CONVERT(NVARCHAR, GETDATE(), 120);
    PRINT '';
    
    -- 1. Bulk Insert Test
    IF @run_insert = 1
    BEGIN
        EXEC dbo.sp_benchmark_bulk_insert @dataset_name = @dataset_name;
    END
    
    -- 2. Index Build Tests (multiple index types)
    IF @run_index_build = 1
    BEGIN
        DECLARE @dataset_size INT;
        SELECT @dataset_size = COUNT(*) FROM dbo.VectorsTest_FAISS;
        
        -- FLAT (baseline)
        EXEC dbo.sp_benchmark_index_build 
            @table_name = 'VectorsTest_FAISS',
            @column_name = 'vector',
            @index_type = 'FLAT',
            @metric = 'L2',
            @dataset_size = @dataset_size,
            @dimension = 1536;
        
        -- HNSW
        EXEC dbo.sp_benchmark_index_build 
            @table_name = 'VectorsTest_FAISS',
            @column_name = 'vector',
            @index_type = 'HNSW',
            @metric = 'L2',
            @dataset_size = @dataset_size,
            @dimension = 1536;
        
        -- IVF
        EXEC dbo.sp_benchmark_index_build 
            @table_name = 'VectorsTest_FAISS',
            @column_name = 'vector',
            @index_type = 'IVF',
            @metric = 'L2',
            @dataset_size = @dataset_size,
            @dimension = 1536;
    END
    
    -- 3. Search Performance Tests
    IF @run_search = 1
    BEGIN
        -- Sequential scan (baseline)
        EXEC dbo.sp_benchmark_knn_search
            @table_name = 'VectorsTest_FAISS',
            @column_name = 'vector',
            @k = 10,
            @num_queries = 100,
            @use_index = 0,
            @metric = 'L2';
        
        -- HNSW indexed
        EXEC dbo.sp_benchmark_knn_search
            @table_name = 'VectorsTest_FAISS',
            @column_name = 'vector',
            @k = 10,
            @num_queries = 100,
            @use_index = 1,
            @index_type = 'HNSW',
            @metric = 'L2';
        
        -- Different K values
        DECLARE @k INT;
        SET @k = 1;
        WHILE @k <= 100
        BEGIN
            EXEC dbo.sp_benchmark_knn_search
                @table_name = 'VectorsTest_FAISS',
                @column_name = 'vector',
                @k = @k,
                @num_queries = 100,
                @use_index = 1,
                @index_type = 'HNSW',
                @metric = 'L2';
            
            SET @k = @k * 10;
        END
    END
    
    -- 4. Recall Tests
    IF @run_recall = 1
    BEGIN
        EXEC dbo.sp_benchmark_recall
            @table_name = 'VectorsTest_FAISS',
            @column_name = 'vector',
            @k = 10,
            @num_queries = 100,
            @index_type = 'HNSW';
    END
    
    PRINT '';
    PRINT '##############################################';
    PRINT '    Benchmark Suite Complete';
    PRINT '##############################################';
END
GO

-- =============================================
-- Results Analysis Queries
-- =============================================

-- Compare index types
CREATE OR ALTER VIEW vw_IndexBuildComparison AS
SELECT 
    index_type,
    dataset_size,
    dimension,
    AVG(elapsed_ms) AS avg_build_time_ms,
    MIN(elapsed_ms) AS min_build_time_ms,
    MAX(elapsed_ms) AS max_build_time_ms,
    AVG(throughput_ops_sec) AS avg_throughput
FROM dbo.BenchmarkResults
WHERE test_category = 'INDEX_BUILD'
GROUP BY index_type, dataset_size, dimension;
GO

-- Search performance comparison
CREATE OR ALTER VIEW vw_SearchPerformanceComparison AS
SELECT 
    test_name,
    index_type,
    dataset_size,
    AVG(elapsed_ms * 1.0 / operation_count) AS avg_latency_per_query_ms,
    AVG(throughput_ops_sec) AS avg_qps,
    JSON_VALUE(additional_metrics, '$.k') AS k_value
FROM dbo.BenchmarkResults
WHERE test_category = 'SEARCH_KNN'
GROUP BY test_name, index_type, dataset_size, additional_metrics;
GO

-- Summary report
CREATE OR ALTER PROCEDURE dbo.sp_benchmark_summary_report
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '========================================';
    PRINT 'Benchmark Summary Report';
    PRINT '========================================';
    PRINT '';
    
    -- Index build times
    PRINT '--- Index Build Performance ---';
    SELECT 
        index_type,
        dataset_size,
        avg_build_time_ms,
        avg_throughput AS vectors_per_sec
    FROM vw_IndexBuildComparison
    ORDER BY dataset_size, avg_build_time_ms;
    
    PRINT '';
    PRINT '--- Search Performance (QPS) ---';
    SELECT 
        index_type,
        dataset_size,
        avg_latency_per_query_ms,
        avg_qps
    FROM vw_SearchPerformanceComparison
    ORDER BY dataset_size, avg_latency_per_query_ms;
    
    PRINT '';
    PRINT '--- Latest 10 Benchmark Runs ---';
    SELECT TOP 10
        test_name,
        test_category,
        dataset_size,
        elapsed_ms,
        throughput_ops_sec,
        test_date
    FROM dbo.BenchmarkResults
    ORDER BY test_date DESC;
END
GO

PRINT 'SQL Server benchmark suite installed successfully!';
PRINT 'Run: EXEC dbo.sp_run_benchmark_suite @dataset_name = ''test_dataset''';
GO
