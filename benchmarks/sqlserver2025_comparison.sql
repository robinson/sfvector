/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright 2026 sfvector contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

-- SQL Server 2025 Native Vector Search Benchmarks
-- Compares built-in VECTOR type vs sfvector (FAISS)

USE VectorSearchDB;
GO

-- Create benchmark results table if not exists
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BenchmarkResults_2025')
BEGIN
    CREATE TABLE BenchmarkResults_2025 (
        benchmark_id INT IDENTITY(1,1) PRIMARY KEY,
        test_date DATETIME2 DEFAULT GETUTCDATE(),
        test_name NVARCHAR(200) NOT NULL,
        test_category NVARCHAR(50) NOT NULL, -- INSERT, INDEX_BUILD, SEARCH_KNN, RECALL
        implementation NVARCHAR(50) NOT NULL, -- SQL2025_NATIVE, SFVECTOR_FAISS
        dataset_name NVARCHAR(100),
        dataset_size INT,
        dimension INT,
        index_type NVARCHAR(50), -- HNSW, IVF, DISKANN (SQL2025), FAISS_HNSW, FAISS_IVF
        metric_type NVARCHAR(20), -- L2, COSINE, IP
        elapsed_ms BIGINT,
        throughput_ops_sec DECIMAL(18,2),
        memory_mb DECIMAL(18,2),
        additional_metrics NVARCHAR(MAX), -- JSON
        CONSTRAINT CHK_Implementation CHECK (implementation IN ('SQL2025_NATIVE', 'SFVECTOR_FAISS'))
    );

    CREATE INDEX IX_BenchmarkResults_2025_TestDate ON BenchmarkResults_2025(test_date DESC);
    CREATE INDEX IX_BenchmarkResults_2025_Implementation ON BenchmarkResults_2025(implementation, test_category);
END
GO

-- =====================================================================
-- SQL Server 2025 Native Vector Implementation Tests
-- =====================================================================

-- Table for SQL Server 2025 native VECTOR type
IF OBJECT_ID('dbo.Vectors_SQL2025', 'U') IS NOT NULL
    DROP TABLE dbo.Vectors_SQL2025;
GO

CREATE TABLE dbo.Vectors_SQL2025 (
    id INT PRIMARY KEY,
    vector VECTOR(1536) NOT NULL, -- SQL Server 2025 native VECTOR type
    metadata NVARCHAR(MAX)
);
GO

-- Table for sfvector (FAISS-based)
IF OBJECT_ID('dbo.Vectors_SFVECTOR', 'U') IS NOT NULL
    DROP TABLE dbo.Vectors_SFVECTOR;
GO

CREATE TABLE dbo.Vectors_SFVECTOR (
    id INT PRIMARY KEY,
    vector dbo.VectorType NOT NULL, -- sfvector UDT with FAISS
    metadata NVARCHAR(MAX)
);
GO

-- =====================================================================
-- Benchmark: Bulk Insert Performance
-- =====================================================================

CREATE OR ALTER PROCEDURE dbo.sp_benchmark_insert_sql2025
    @dataset_size INT,
    @dimension INT,
    @dataset_name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = SYSUTCDATETIME();
    DECLARE @elapsed_ms BIGINT;
    DECLARE @throughput DECIMAL(18,2);
    
    -- Generate random vectors and insert (simplified - in practice load from file)
    TRUNCATE TABLE dbo.Vectors_SQL2025;
    
    DECLARE @i INT = 1;
    DECLARE @vector_str NVARCHAR(MAX);
    
    -- Batch insert
    WHILE @i <= @dataset_size
    BEGIN
        -- Generate random vector string: [0.1, 0.2, ..., 0.n]
        -- In real scenario, load from pre-generated test data
        SET @vector_str = '[' + REPLICATE('0.5,', @dimension - 1) + '0.5]';
        
        INSERT INTO dbo.Vectors_SQL2025 (id, vector, metadata)
        VALUES (@i, CAST(@vector_str AS VECTOR(@dimension)), N'{"test": "data"}');
        
        SET @i = @i + 1;
        
        -- Commit every 1000 rows
        IF @i % 1000 = 0
        BEGIN
            -- Progress indicator
            RAISERROR('Inserted %d rows', 0, 1, @i) WITH NOWAIT;
        END
    END
    
    SET @elapsed_ms = DATEDIFF(MILLISECOND, @start_time, SYSUTCDATETIME());
    SET @throughput = CAST(@dataset_size AS DECIMAL(18,2)) / (CAST(@elapsed_ms AS DECIMAL(18,2)) / 1000.0);
    
    -- Record results
    INSERT INTO dbo.BenchmarkResults_2025 
        (test_name, test_category, implementation, dataset_name, dataset_size, dimension, 
         elapsed_ms, throughput_ops_sec)
    VALUES 
        ('Bulk Insert - SQL2025', 'INSERT', 'SQL2025_NATIVE', @dataset_name, @dataset_size, 
         @dimension, @elapsed_ms, @throughput);
    
    PRINT 'SQL Server 2025 Insert: ' + CAST(@dataset_size AS VARCHAR) + ' vectors in ' + 
          CAST(@elapsed_ms AS VARCHAR) + 'ms (' + CAST(@throughput AS VARCHAR) + ' ops/sec)';
END
GO

-- Same for sfvector
CREATE OR ALTER PROCEDURE dbo.sp_benchmark_insert_sfvector
    @dataset_size INT,
    @dimension INT,
    @dataset_name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = SYSUTCDATETIME();
    DECLARE @elapsed_ms BIGINT;
    DECLARE @throughput DECIMAL(18,2);
    
    TRUNCATE TABLE dbo.Vectors_SFVECTOR;
    
    DECLARE @i INT = 1;
    DECLARE @vector_str NVARCHAR(MAX);
    
    WHILE @i <= @dataset_size
    BEGIN
        SET @vector_str = '[' + REPLICATE('0.5,', @dimension - 1) + '0.5]';
        
        INSERT INTO dbo.Vectors_SFVECTOR (id, vector, metadata)
        VALUES (@i, dbo.VectorType::Parse(@vector_str), N'{"test": "data"}');
        
        SET @i = @i + 1;
        
        IF @i % 1000 = 0
        BEGIN
            RAISERROR('Inserted %d rows', 0, 1, @i) WITH NOWAIT;
        END
    END
    
    SET @elapsed_ms = DATEDIFF(MILLISECOND, @start_time, SYSUTCDATETIME());
    SET @throughput = CAST(@dataset_size AS DECIMAL(18,2)) / (CAST(@elapsed_ms AS DECIMAL(18,2)) / 1000.0);
    
    INSERT INTO dbo.BenchmarkResults_2025 
        (test_name, test_category, implementation, dataset_name, dataset_size, dimension, 
         elapsed_ms, throughput_ops_sec)
    VALUES 
        ('Bulk Insert - sfvector', 'INSERT', 'SFVECTOR_FAISS', @dataset_name, @dataset_size, 
         @dimension, @elapsed_ms, @throughput);
    
    PRINT 'sfvector Insert: ' + CAST(@dataset_size AS VARCHAR) + ' vectors in ' + 
          CAST(@elapsed_ms AS VARCHAR) + 'ms (' + CAST(@throughput AS VARCHAR) + ' ops/sec)';
END
GO

-- =====================================================================
-- Benchmark: Index Build Performance
-- =====================================================================

CREATE OR ALTER PROCEDURE dbo.sp_benchmark_index_build_sql2025
    @index_type NVARCHAR(50), -- HNSW, DISKANN
    @metric NVARCHAR(20), -- COSINE, L2, IP
    @dataset_name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2;
    DECLARE @elapsed_ms BIGINT;
    DECLARE @dataset_size INT;
    DECLARE @dimension INT;
    DECLARE @index_name NVARCHAR(200);
    DECLARE @sql NVARCHAR(MAX);
    
    -- Get dataset info
    SELECT @dataset_size = COUNT(*), 
           @dimension = 1536 -- Fixed for now
    FROM dbo.Vectors_SQL2025;
    
    SET @index_name = 'IX_Vector_SQL2025_' + @index_type + '_' + @metric;
    
    -- Drop existing index if exists
    IF EXISTS (SELECT * FROM sys.indexes WHERE name = @index_name)
    BEGIN
        SET @sql = 'DROP INDEX ' + @index_name + ' ON dbo.Vectors_SQL2025';
        EXEC sp_executesql @sql;
    END
    
    -- Build index with appropriate type and metric
    SET @start_time = SYSUTCDATETIME();
    
    IF @index_type = 'HNSW'
    BEGIN
        -- SQL Server 2025 HNSW index syntax
        SET @sql = N'CREATE VECTOR INDEX ' + @index_name + 
                   N' ON dbo.Vectors_SQL2025(vector) ' +
                   N'WITH (ALGORITHM = HNSW, METRIC = ' + @metric + ')';
    END
    ELSE IF @index_type = 'DISKANN'
    BEGIN
        -- SQL Server 2025 DiskANN index syntax (if available)
        SET @sql = N'CREATE VECTOR INDEX ' + @index_name + 
                   N' ON dbo.Vectors_SQL2025(vector) ' +
                   N'WITH (ALGORITHM = DISKANN, METRIC = ' + @metric + ')';
    END
    
    EXEC sp_executesql @sql;
    
    SET @elapsed_ms = DATEDIFF(MILLISECOND, @start_time, SYSUTCDATETIME());
    
    -- Record results
    INSERT INTO dbo.BenchmarkResults_2025 
        (test_name, test_category, implementation, dataset_name, dataset_size, dimension,
         index_type, metric_type, elapsed_ms)
    VALUES 
        ('Index Build - SQL2025 ' + @index_type, 'INDEX_BUILD', 'SQL2025_NATIVE', 
         @dataset_name, @dataset_size, @dimension, @index_type, @metric, @elapsed_ms);
    
    PRINT 'SQL Server 2025 ' + @index_type + ' index built in ' + CAST(@elapsed_ms AS VARCHAR) + 'ms';
END
GO

-- sfvector index build (uses existing FAISS procedures)
CREATE OR ALTER PROCEDURE dbo.sp_benchmark_index_build_sfvector
    @index_type NVARCHAR(50), -- FAISS_HNSW, FAISS_IVF
    @metric NVARCHAR(20),
    @dataset_name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2;
    DECLARE @elapsed_ms BIGINT;
    DECLARE @dataset_size INT;
    DECLARE @dimension INT;
    
    SELECT @dataset_size = COUNT(*), @dimension = 1536 FROM dbo.Vectors_SFVECTOR;
    
    SET @start_time = SYSUTCDATETIME();
    
    -- Call sfvector's FAISS index creation
    EXEC dbo.sp_create_vector_index 
        @table_name = 'Vectors_SFVECTOR',
        @column_name = 'vector',
        @index_name = 'FAISS_bench_idx',
        @index_type = @index_type,
        @metric = @metric;
    
    SET @elapsed_ms = DATEDIFF(MILLISECOND, @start_time, SYSUTCDATETIME());
    
    INSERT INTO dbo.BenchmarkResults_2025 
        (test_name, test_category, implementation, dataset_name, dataset_size, dimension,
         index_type, metric_type, elapsed_ms)
    VALUES 
        ('Index Build - sfvector ' + @index_type, 'INDEX_BUILD', 'SFVECTOR_FAISS', 
         @dataset_name, @dataset_size, @dimension, @index_type, @metric, @elapsed_ms);
    
    PRINT 'sfvector ' + @index_type + ' index built in ' + CAST(@elapsed_ms AS VARCHAR) + 'ms';
END
GO

-- =====================================================================
-- Benchmark: KNN Search Performance
-- =====================================================================

CREATE OR ALTER PROCEDURE dbo.sp_benchmark_knn_search_sql2025
    @k INT,
    @num_queries INT,
    @dataset_name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2;
    DECLARE @elapsed_ms BIGINT;
    DECLARE @qps DECIMAL(18,2);
    DECLARE @i INT = 1;
    DECLARE @query_vector NVARCHAR(MAX) = '[' + REPLICATE('0.5,', 1535) + '0.5]';
    
    SET @start_time = SYSUTCDATETIME();
    
    -- Run KNN queries
    WHILE @i <= @num_queries
    BEGIN
        -- SQL Server 2025 vector search syntax
        SELECT TOP (@k) id, 
               VECTOR_DISTANCE('COSINE', vector, CAST(@query_vector AS VECTOR(1536))) AS distance
        FROM dbo.Vectors_SQL2025
        ORDER BY VECTOR_DISTANCE('COSINE', vector, CAST(@query_vector AS VECTOR(1536)));
        
        SET @i = @i + 1;
    END
    
    SET @elapsed_ms = DATEDIFF(MILLISECOND, @start_time, SYSUTCDATETIME());
    SET @qps = (CAST(@num_queries AS DECIMAL(18,2)) / CAST(@elapsed_ms AS DECIMAL(18,2))) * 1000.0;
    
    INSERT INTO dbo.BenchmarkResults_2025 
        (test_name, test_category, implementation, dataset_name, elapsed_ms, throughput_ops_sec,
         additional_metrics)
    VALUES 
        ('KNN Search - SQL2025', 'SEARCH_KNN', 'SQL2025_NATIVE', @dataset_name, 
         @elapsed_ms, @qps, 
         N'{"k": ' + CAST(@k AS NVARCHAR) + ', "queries": ' + CAST(@num_queries AS NVARCHAR) + '}');
    
    PRINT 'SQL Server 2025 KNN: ' + CAST(@num_queries AS VARCHAR) + ' queries in ' + 
          CAST(@elapsed_ms AS VARCHAR) + 'ms (' + CAST(@qps AS VARCHAR) + ' QPS)';
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_benchmark_knn_search_sfvector
    @k INT,
    @num_queries INT,
    @dataset_name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2;
    DECLARE @elapsed_ms BIGINT;
    DECLARE @qps DECIMAL(18,2);
    DECLARE @i INT = 1;
    DECLARE @query_vector NVARCHAR(MAX) = '[' + REPLICATE('0.5,', 1535) + '0.5]';
    
    SET @start_time = SYSUTCDATETIME();
    
    WHILE @i <= @num_queries
    BEGIN
        -- sfvector FAISS search
        EXEC dbo.sp_search_knn
            @table_name = 'Vectors_SFVECTOR',
            @query_vector = @query_vector,
            @k = @k,
            @metric = 'COSINE';
        
        SET @i = @i + 1;
    END
    
    SET @elapsed_ms = DATEDIFF(MILLISECOND, @start_time, SYSUTCDATETIME());
    SET @qps = (CAST(@num_queries AS DECIMAL(18,2)) / CAST(@elapsed_ms AS DECIMAL(18,2))) * 1000.0;
    
    INSERT INTO dbo.BenchmarkResults_2025 
        (test_name, test_category, implementation, dataset_name, elapsed_ms, throughput_ops_sec,
         additional_metrics)
    VALUES 
        ('KNN Search - sfvector', 'SEARCH_KNN', 'SFVECTOR_FAISS', @dataset_name, 
         @elapsed_ms, @qps,
         N'{"k": ' + CAST(@k AS NVARCHAR) + ', "queries": ' + CAST(@num_queries AS NVARCHAR) + '}');
    
    PRINT 'sfvector FAISS KNN: ' + CAST(@num_queries AS VARCHAR) + ' queries in ' + 
          CAST(@elapsed_ms AS VARCHAR) + 'ms (' + CAST(@qps AS VARCHAR) + ' QPS)';
END
GO

-- =====================================================================
-- Comprehensive Benchmark Suite Runner
-- =====================================================================

CREATE OR ALTER PROCEDURE dbo.sp_run_benchmark_suite_2025
    @dataset_name NVARCHAR(100) = 'test_10k_1536d',
    @dataset_size INT = 10000,
    @dimension INT = 1536,
    @run_insert BIT = 1,
    @run_index_build BIT = 1,
    @run_search BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '========================================';
    PRINT 'SQL Server 2025 vs sfvector Benchmarks';
    PRINT 'Dataset: ' + @dataset_name;
    PRINT 'Size: ' + CAST(@dataset_size AS VARCHAR) + ' vectors';
    PRINT 'Dimension: ' + CAST(@dimension AS VARCHAR);
    PRINT '========================================';
    PRINT '';
    
    -- 1. INSERT BENCHMARKS
    IF @run_insert = 1
    BEGIN
        PRINT '--- INSERT BENCHMARKS ---';
        EXEC dbo.sp_benchmark_insert_sql2025 @dataset_size, @dimension, @dataset_name;
        EXEC dbo.sp_benchmark_insert_sfvector @dataset_size, @dimension, @dataset_name;
        PRINT '';
    END
    
    -- 2. INDEX BUILD BENCHMARKS
    IF @run_index_build = 1
    BEGIN
        PRINT '--- INDEX BUILD BENCHMARKS ---';
        
        -- SQL Server 2025 HNSW
        EXEC dbo.sp_benchmark_index_build_sql2025 'HNSW', 'COSINE', @dataset_name;
        
        -- sfvector FAISS HNSW
        EXEC dbo.sp_benchmark_index_build_sfvector 'FAISS_HNSW', 'COSINE', @dataset_name;
        
        PRINT '';
    END
    
    -- 3. SEARCH BENCHMARKS
    IF @run_search = 1
    BEGIN
        PRINT '--- SEARCH BENCHMARKS (K=10, 100 queries) ---';
        
        EXEC dbo.sp_benchmark_knn_search_sql2025 10, 100, @dataset_name;
        EXEC dbo.sp_benchmark_knn_search_sfvector 10, 100, @dataset_name;
        
        PRINT '';
    END
    
    PRINT '========================================';
    PRINT 'Benchmark Suite Complete!';
    PRINT 'View results: SELECT * FROM BenchmarkResults_2025 ORDER BY test_date DESC';
    PRINT '========================================';
END
GO

-- =====================================================================
-- Results Analysis Views
-- =====================================================================

CREATE OR ALTER VIEW vw_BenchmarkComparison_2025
AS
SELECT 
    test_category,
    implementation,
    AVG(elapsed_ms) AS avg_elapsed_ms,
    AVG(throughput_ops_sec) AS avg_throughput,
    MIN(elapsed_ms) AS min_elapsed_ms,
    MAX(elapsed_ms) AS max_elapsed_ms,
    COUNT(*) AS test_count
FROM dbo.BenchmarkResults_2025
GROUP BY test_category, implementation;
GO

CREATE OR ALTER VIEW vw_PerformanceRatio_2025
AS
WITH SQL2025_Stats AS (
    SELECT 
        test_category,
        AVG(elapsed_ms) AS sql2025_ms,
        AVG(throughput_ops_sec) AS sql2025_qps
    FROM dbo.BenchmarkResults_2025
    WHERE implementation = 'SQL2025_NATIVE'
    GROUP BY test_category
),
SFVECTOR_Stats AS (
    SELECT 
        test_category,
        AVG(elapsed_ms) AS sfvector_ms,
        AVG(throughput_ops_sec) AS sfvector_qps
    FROM dbo.BenchmarkResults_2025
    WHERE implementation = 'SFVECTOR_FAISS'
    GROUP BY test_category
)
SELECT 
    s.test_category,
    s.sql2025_ms,
    f.sfvector_ms,
    CAST(f.sfvector_ms AS FLOAT) / NULLIF(s.sql2025_ms, 0) AS time_ratio,
    s.sql2025_qps,
    f.sfvector_qps,
    CAST(f.sfvector_qps AS FLOAT) / NULLIF(s.sql2025_qps, 0) AS throughput_ratio,
    CASE 
        WHEN CAST(f.sfvector_ms AS FLOAT) / NULLIF(s.sql2025_ms, 0) < 1.0 THEN 'sfvector faster'
        WHEN CAST(f.sfvector_ms AS FLOAT) / NULLIF(s.sql2025_ms, 0) > 1.0 THEN 'SQL2025 faster'
        ELSE 'Equal'
    END AS winner
FROM SQL2025_Stats s
LEFT JOIN SFVECTOR_Stats f ON s.test_category = f.test_category;
GO

-- =====================================================================
-- Quick Start Commands
-- =====================================================================

/*
-- Run complete benchmark suite:
EXEC dbo.sp_run_benchmark_suite_2025 
    @dataset_name = 'test_10k_1536d',
    @dataset_size = 10000,
    @dimension = 1536,
    @run_insert = 1,
    @run_index_build = 1,
    @run_search = 1;

-- View comparison results:
SELECT * FROM vw_BenchmarkComparison_2025;
SELECT * FROM vw_PerformanceRatio_2025;

-- View detailed results:
SELECT 
    test_date,
    test_name,
    implementation,
    elapsed_ms,
    throughput_ops_sec,
    additional_metrics
FROM dbo.BenchmarkResults_2025
ORDER BY test_date DESC;

-- Export to CSV:
SELECT * FROM vw_PerformanceRatio_2025;
*/
