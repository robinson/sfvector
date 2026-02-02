/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


-- =============================================
-- PostgreSQL/pgvector Benchmark Suite
-- Comparison benchmarks for pgvector
-- =============================================

-- Create extension
CREATE EXTENSION IF NOT EXISTS vector;

-- =============================================
-- Setup: Create benchmark tables
-- =============================================

DROP TABLE IF EXISTS benchmark_results;

CREATE TABLE benchmark_results (
    result_id SERIAL PRIMARY KEY,
    test_name VARCHAR(200),
    test_category VARCHAR(100),
    database_type VARCHAR(50) DEFAULT 'PGVECTOR',
    dataset_name VARCHAR(100),
    dataset_size INT,
    dimension INT,
    index_type VARCHAR(50),
    metric_type VARCHAR(50),
    operation_count INT,
    elapsed_ms BIGINT,
    throughput_ops_sec DECIMAL(18,2),
    memory_mb DECIMAL(18,2),
    additional_metrics JSONB,
    test_date TIMESTAMP DEFAULT NOW(),
    notes TEXT
);

CREATE INDEX idx_benchmark_results_test ON benchmark_results(test_category, test_name);

-- =============================================
-- Test Tables
-- =============================================

DROP TABLE IF EXISTS vectors_test_pgvector;

CREATE TABLE vectors_test_pgvector (
    id INT PRIMARY KEY,
    vector vector(1536)  -- OpenAI ada-002 dimension
);

-- =============================================
-- Utility Functions
-- =============================================

CREATE OR REPLACE FUNCTION start_benchmark(
    p_test_name VARCHAR,
    p_test_category VARCHAR,
    p_dataset_name VARCHAR,
    p_dataset_size INT,
    p_dimension INT
) RETURNS INT AS $$
DECLARE
    v_benchmark_id INT;
BEGIN
    INSERT INTO benchmark_results (
        test_name,
        test_category,
        dataset_name,
        dataset_size,
        dimension,
        test_date
    ) VALUES (
        p_test_name,
        p_test_category,
        p_dataset_name,
        p_dataset_size,
        p_dimension,
        NOW()
    ) RETURNING result_id INTO v_benchmark_id;
    
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Starting Benchmark: %', p_test_name;
    RAISE NOTICE 'Category: %', p_test_category;
    RAISE NOTICE 'Dataset: % (% vectors)', p_dataset_name, p_dataset_size;
    RAISE NOTICE '==============================================';
    
    RETURN v_benchmark_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION end_benchmark(
    p_benchmark_id INT,
    p_start_time TIMESTAMP,
    p_operation_count INT,
    p_index_type VARCHAR DEFAULT NULL,
    p_metric_type VARCHAR DEFAULT NULL,
    p_additional_metrics JSONB DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_elapsed_ms BIGINT;
    v_throughput DECIMAL(18,2);
BEGIN
    v_elapsed_ms := EXTRACT(EPOCH FROM (NOW() - p_start_time)) * 1000;
    
    IF p_operation_count > 0 AND v_elapsed_ms > 0 THEN
        v_throughput := p_operation_count::DECIMAL / (v_elapsed_ms / 1000.0);
    ELSE
        v_throughput := 0;
    END IF;
    
    UPDATE benchmark_results SET
        elapsed_ms = v_elapsed_ms,
        operation_count = p_operation_count,
        throughput_ops_sec = v_throughput,
        index_type = p_index_type,
        metric_type = p_metric_type,
        additional_metrics = p_additional_metrics
    WHERE result_id = p_benchmark_id;
    
    RAISE NOTICE '----------------------------------------------';
    RAISE NOTICE 'Elapsed: % ms', v_elapsed_ms;
    RAISE NOTICE 'Operations: %', p_operation_count;
    RAISE NOTICE 'Throughput: % ops/sec', v_throughput;
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Benchmark 1: Bulk Insert Performance
-- =============================================

CREATE OR REPLACE FUNCTION benchmark_bulk_insert(
    p_dataset_name VARCHAR,
    p_batch_size INT DEFAULT 1000
) RETURNS VOID AS $$
DECLARE
    v_benchmark_id INT;
    v_start_time TIMESTAMP;
    v_count INT := 0;
BEGIN
    RAISE NOTICE 'Bulk Insert Benchmark';
    RAISE NOTICE 'Dataset: %', p_dataset_name;
    RAISE NOTICE 'Batch size: %', p_batch_size;
    
    -- This is a template - load from CSV in practice
    -- COPY vectors_test_pgvector FROM 'path/to/data.csv' WITH CSV;
    
    SELECT COUNT(*) INTO v_count FROM vectors_test_pgvector;
    
    v_benchmark_id := start_benchmark(
        'Bulk Insert - ' || p_dataset_name,
        'INSERT',
        p_dataset_name,
        v_count,
        1536
    );
    
    -- Actual bulk load would happen here
    
    PERFORM end_benchmark(
        v_benchmark_id,
        v_start_time,
        v_count
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Benchmark 2: Index Build Performance
-- =============================================

CREATE OR REPLACE FUNCTION benchmark_index_build(
    p_table_name VARCHAR,
    p_column_name VARCHAR,
    p_index_type VARCHAR,  -- ivfflat or hnsw
    p_metric VARCHAR,      -- vector_l2_ops, vector_ip_ops, vector_cosine_ops
    p_lists INT DEFAULT NULL,  -- For IVF
    p_m INT DEFAULT NULL,      -- For HNSW
    p_ef_construction INT DEFAULT NULL  -- For HNSW
) RETURNS VOID AS $$
DECLARE
    v_benchmark_id INT;
    v_start_time TIMESTAMP;
    v_dataset_size INT;
    v_index_name VARCHAR;
    v_create_sql TEXT;
BEGIN
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table_name) INTO v_dataset_size;
    
    v_benchmark_id := start_benchmark(
        'Index Build - ' || p_index_type,
        'INDEX_BUILD',
        p_table_name,
        v_dataset_size,
        1536
    );
    
    v_index_name := 'idx_' || p_table_name || '_' || p_index_type;
    
    -- Drop existing index if exists
    EXECUTE format('DROP INDEX IF EXISTS %I', v_index_name);
    
    v_start_time := clock_timestamp();
    
    IF p_index_type = 'ivfflat' THEN
        -- IVF index
        v_create_sql := format(
            'CREATE INDEX %I ON %I USING ivfflat (%I %s) WITH (lists = %s)',
            v_index_name,
            p_table_name,
            p_column_name,
            p_metric,
            COALESCE(p_lists::TEXT, '100')
        );
    ELSIF p_index_type = 'hnsw' THEN
        -- HNSW index
        v_create_sql := format(
            'CREATE INDEX %I ON %I USING hnsw (%I %s) WITH (m = %s, ef_construction = %s)',
            v_index_name,
            p_table_name,
            p_column_name,
            p_metric,
            COALESCE(p_m::TEXT, '16'),
            COALESCE(p_ef_construction::TEXT, '64')
        );
    ELSE
        RAISE EXCEPTION 'Unknown index type: %', p_index_type;
    END IF;
    
    RAISE NOTICE 'Creating index: %', v_create_sql;
    EXECUTE v_create_sql;
    
    PERFORM end_benchmark(
        v_benchmark_id,
        v_start_time,
        v_dataset_size,
        p_index_type,
        p_metric
    );
    
    RAISE NOTICE 'Index built: % on %', p_index_type, p_table_name;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Benchmark 3: KNN Search Performance
-- =============================================

CREATE OR REPLACE FUNCTION benchmark_knn_search(
    p_table_name VARCHAR,
    p_column_name VARCHAR,
    p_k INT DEFAULT 10,
    p_num_queries INT DEFAULT 100,
    p_use_index BOOLEAN DEFAULT TRUE,
    p_index_type VARCHAR DEFAULT NULL,
    p_metric VARCHAR DEFAULT 'vector_l2_ops'
) RETURNS VOID AS $$
DECLARE
    v_benchmark_id INT;
    v_start_time TIMESTAMP;
    v_test_name VARCHAR;
    v_dataset_size INT;
    v_query_vector vector(1536);
    v_i INT := 0;
    v_operator TEXT;
    v_avg_latency DECIMAL(18,2);
BEGIN
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table_name) INTO v_dataset_size;
    
    IF p_use_index THEN
        v_test_name := 'KNN Search (Indexed - ' || COALESCE(p_index_type, 'UNKNOWN') || ')';
    ELSE
        v_test_name := 'KNN Search (Sequential Scan)';
    END IF;
    
    v_benchmark_id := start_benchmark(
        v_test_name,
        'SEARCH_KNN',
        p_table_name,
        v_dataset_size,
        1536
    );
    
    -- Determine operator based on metric
    IF p_metric = 'vector_l2_ops' THEN
        v_operator := '<->';
    ELSIF p_metric = 'vector_ip_ops' THEN
        v_operator := '<#>';
    ELSIF p_metric = 'vector_cosine_ops' THEN
        v_operator := '<=>';
    ELSE
        v_operator := '<->';
    END IF;
    
    -- Force index usage or sequential scan
    IF NOT p_use_index THEN
        SET enable_indexscan = OFF;
        SET enable_bitmapscan = OFF;
    ELSE
        SET enable_indexscan = ON;
        SET enable_bitmapscan = ON;
    END IF;
    
    v_start_time := clock_timestamp();
    
    -- Execute queries
    WHILE v_i < p_num_queries LOOP
        -- Generate random query (in practice, load from query dataset)
        -- For now, select a random vector from the table
        EXECUTE format(
            'SELECT %I FROM %I ORDER BY random() LIMIT 1',
            p_column_name,
            p_table_name
        ) INTO v_query_vector;
        
        -- Execute KNN query
        EXECUTE format(
            'SELECT id FROM %I ORDER BY %I %s $1 LIMIT %s',
            p_table_name,
            p_column_name,
            v_operator,
            p_k
        ) USING v_query_vector;
        
        v_i := v_i + 1;
    END LOOP;
    
    v_avg_latency := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000 / p_num_queries;
    
    -- Reset settings
    RESET enable_indexscan;
    RESET enable_bitmapscan;
    
    PERFORM end_benchmark(
        v_benchmark_id,
        v_start_time,
        p_num_queries,
        p_index_type,
        p_metric,
        jsonb_build_object(
            'k', p_k,
            'num_queries', p_num_queries,
            'avg_latency_ms', v_avg_latency
        )
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Benchmark 4: Recall Test
-- =============================================

CREATE OR REPLACE FUNCTION benchmark_recall(
    p_table_name VARCHAR,
    p_column_name VARCHAR,
    p_k INT DEFAULT 10,
    p_num_queries INT DEFAULT 100,
    p_index_type VARCHAR DEFAULT 'hnsw'
) RETURNS DECIMAL AS $$
DECLARE
    v_query_vector vector(1536);
    v_exact_results INT[];
    v_approx_results INT[];
    v_intersection INT;
    v_total_recall DECIMAL := 0;
    v_avg_recall DECIMAL;
    v_i INT := 0;
BEGIN
    RAISE NOTICE 'Recall Benchmark: %', p_index_type;
    RAISE NOTICE 'Comparing approximate search vs exact search';
    
    -- Disable index for exact search
    SET enable_indexscan = OFF;
    SET enable_bitmapscan = OFF;
    
    WHILE v_i < p_num_queries LOOP
        -- Get random query vector
        EXECUTE format(
            'SELECT %I FROM %I ORDER BY random() LIMIT 1',
            p_column_name,
            p_table_name
        ) INTO v_query_vector;
        
        -- Get exact results (brute force)
        EXECUTE format(
            'SELECT array_agg(id ORDER BY %I <-> $1) FROM (
                SELECT id FROM %I ORDER BY %I <-> $1 LIMIT %s
            ) t',
            p_column_name,
            p_table_name,
            p_column_name,
            p_k
        ) INTO v_exact_results USING v_query_vector;
        
        -- Enable index for approximate search
        SET enable_indexscan = ON;
        SET enable_bitmapscan = ON;
        
        -- Get approximate results
        EXECUTE format(
            'SELECT array_agg(id ORDER BY %I <-> $1) FROM (
                SELECT id FROM %I ORDER BY %I <-> $1 LIMIT %s
            ) t',
            p_column_name,
            p_table_name,
            p_column_name,
            p_k
        ) INTO v_approx_results USING v_query_vector;
        
        -- Calculate intersection
        SELECT COUNT(*) INTO v_intersection
        FROM unnest(v_exact_results) e
        WHERE e = ANY(v_approx_results);
        
        v_total_recall := v_total_recall + (v_intersection::DECIMAL / p_k);
        
        -- Disable index again for next exact search
        SET enable_indexscan = OFF;
        SET enable_bitmapscan = OFF;
        
        v_i := v_i + 1;
    END LOOP;
    
    v_avg_recall := v_total_recall / p_num_queries;
    
    -- Reset settings
    RESET enable_indexscan;
    RESET enable_bitmapscan;
    
    INSERT INTO benchmark_results (test_name, test_category, index_type, additional_metrics)
    VALUES (
        'Recall@' || p_k,
        'RECALL',
        p_index_type,
        jsonb_build_object('recall', v_avg_recall, 'k', p_k, 'num_queries', p_num_queries)
    );
    
    RAISE NOTICE 'Average Recall@%: %', p_k, v_avg_recall;
    
    RETURN v_avg_recall;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Benchmark Suite Runner
-- =============================================

CREATE OR REPLACE FUNCTION run_benchmark_suite(
    p_dataset_name VARCHAR,
    p_run_insert BOOLEAN DEFAULT TRUE,
    p_run_index_build BOOLEAN DEFAULT TRUE,
    p_run_search BOOLEAN DEFAULT TRUE,
    p_run_recall BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
DECLARE
    v_dataset_size INT;
    v_k INT;
BEGIN
    RAISE NOTICE '##############################################';
    RAISE NOTICE '    pgvector Benchmark Suite';
    RAISE NOTICE '##############################################';
    RAISE NOTICE '';
    RAISE NOTICE 'Dataset: %', p_dataset_name;
    RAISE NOTICE 'Date: %', NOW();
    RAISE NOTICE '';
    
    -- 1. Bulk Insert Test
    IF p_run_insert THEN
        PERFORM benchmark_bulk_insert(p_dataset_name);
    END IF;
    
    SELECT COUNT(*) INTO v_dataset_size FROM vectors_test_pgvector;
    
    -- 2. Index Build Tests
    IF p_run_index_build THEN
        -- IVFFlat with different list sizes
        PERFORM benchmark_index_build(
            'vectors_test_pgvector',
            'vector',
            'ivfflat',
            'vector_l2_ops',
            LEAST(v_dataset_size / 1000, 1000)  -- lists = sqrt(n) approximation
        );
        
        -- HNSW with default parameters
        PERFORM benchmark_index_build(
            'vectors_test_pgvector',
            'vector',
            'hnsw',
            'vector_l2_ops',
            NULL,
            16,   -- m
            64    -- ef_construction
        );
        
        -- HNSW with higher quality
        PERFORM benchmark_index_build(
            'vectors_test_pgvector',
            'vector',
            'hnsw',
            'vector_l2_ops',
            NULL,
            32,   -- m
            200   -- ef_construction
        );
    END IF;
    
    -- 3. Search Performance Tests
    IF p_run_search THEN
        -- Sequential scan (baseline)
        PERFORM benchmark_knn_search(
            'vectors_test_pgvector',
            'vector',
            10,
            100,
            FALSE,
            NULL,
            'vector_l2_ops'
        );
        
        -- IVFFlat indexed
        PERFORM benchmark_knn_search(
            'vectors_test_pgvector',
            'vector',
            10,
            100,
            TRUE,
            'ivfflat',
            'vector_l2_ops'
        );
        
        -- HNSW indexed
        PERFORM benchmark_knn_search(
            'vectors_test_pgvector',
            'vector',
            10,
            100,
            TRUE,
            'hnsw',
            'vector_l2_ops'
        );
        
        -- Different K values
        v_k := 1;
        WHILE v_k <= 100 LOOP
            PERFORM benchmark_knn_search(
                'vectors_test_pgvector',
                'vector',
                v_k,
                100,
                TRUE,
                'hnsw',
                'vector_l2_ops'
            );
            
            v_k := v_k * 10;
        END LOOP;
    END IF;
    
    -- 4. Recall Tests
    IF p_run_recall THEN
        PERFORM benchmark_recall(
            'vectors_test_pgvector',
            'vector',
            10,
            100,
            'hnsw'
        );
        
        PERFORM benchmark_recall(
            'vectors_test_pgvector',
            'vector',
            10,
            100,
            'ivfflat'
        );
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '##############################################';
    RAISE NOTICE '    Benchmark Suite Complete';
    RAISE NOTICE '##############################################';
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Results Analysis Views
-- =============================================

CREATE OR REPLACE VIEW vw_index_build_comparison AS
SELECT 
    index_type,
    dataset_size,
    dimension,
    AVG(elapsed_ms) AS avg_build_time_ms,
    MIN(elapsed_ms) AS min_build_time_ms,
    MAX(elapsed_ms) AS max_build_time_ms,
    AVG(throughput_ops_sec) AS avg_throughput
FROM benchmark_results
WHERE test_category = 'INDEX_BUILD'
GROUP BY index_type, dataset_size, dimension;

CREATE OR REPLACE VIEW vw_search_performance_comparison AS
SELECT 
    test_name,
    index_type,
    dataset_size,
    AVG(elapsed_ms::DECIMAL / operation_count) AS avg_latency_per_query_ms,
    AVG(throughput_ops_sec) AS avg_qps,
    (additional_metrics->>'k')::INT AS k_value
FROM benchmark_results
WHERE test_category = 'SEARCH_KNN'
GROUP BY test_name, index_type, dataset_size, additional_metrics;

-- =============================================
-- Summary Report
-- =============================================

CREATE OR REPLACE FUNCTION benchmark_summary_report() RETURNS VOID AS $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'pgvector Benchmark Summary Report';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    RAISE NOTICE '--- Index Build Performance ---';
    RAISE NOTICE '';
    
    FOR r IN (
        SELECT index_type, dataset_size, avg_build_time_ms, avg_throughput
        FROM vw_index_build_comparison
        ORDER BY dataset_size, avg_build_time_ms
    ) LOOP
        RAISE NOTICE '% (% vectors): % ms (% vec/sec)',
            r.index_type, r.dataset_size, r.avg_build_time_ms, r.avg_throughput;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '--- Search Performance (QPS) ---';
    RAISE NOTICE '';
    
    FOR r IN (
        SELECT index_type, dataset_size, avg_latency_per_query_ms, avg_qps
        FROM vw_search_performance_comparison
        ORDER BY dataset_size, avg_latency_per_query_ms
    ) LOOP
        RAISE NOTICE '% (% vectors): % ms/query (% QPS)',
            r.index_type, r.dataset_size, r.avg_latency_per_query_ms, r.avg_qps;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Print success message
DO $$
BEGIN
    RAISE NOTICE 'pgvector benchmark suite installed successfully!';
    RAISE NOTICE 'Run: SELECT run_benchmark_suite(''test_dataset'');';
END $$;
