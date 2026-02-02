# Performance Benchmark Guide

## SQL Server FAISS vs pgvector Performance Comparison

This guide explains how to run comprehensive performance benchmarks comparing SQL Server with FAISS against PostgreSQL with pgvector.

---

## Quick Start

### 1. Generate Test Data

```bash
cd benchmarks

# Quick test (small datasets)
./generate_test_data.py --preset quick

# Standard benchmarks (recommended)
./generate_test_data.py --preset standard

# Extensive benchmarks (all sizes and dimensions)
./generate_test_data.py --preset extensive
```

This creates test datasets in `benchmarks/data/` with various sizes:
- **tiny**: 1K vectors
- **small**: 10K vectors
- **medium**: 100K vectors
- **large**: 1M vectors

Dimensions: 128, 384, 768, 1536 (OpenAI ada-002)

### 2. Setup Databases

#### SQL Server

```sql
-- Run deployment script
sqlcmd -S localhost -i scripts/deploy.sql

-- Install benchmark suite
sqlcmd -S localhost -i benchmarks/sqlserver_benchmarks.sql

-- Load test data (adjust path)
BULK INSERT VectorsTest_FAISS
FROM 'C:\path\to\data\small_10k_1536d\vectors.csv'
WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', FIRSTROW = 2);
```

#### PostgreSQL

```sql
-- Install pgvector extension
CREATE EXTENSION vector;

-- Install benchmark suite
psql -f benchmarks/pgvector_benchmarks.sql

-- Load test data
\copy vectors_test_pgvector(id, vector) FROM 'data/small_10k_1536d/vectors.csv' WITH CSV HEADER
```

### 3. Run Benchmarks

#### Automated (Python)

```bash
./run_benchmarks.py \
    --sqlserver-conn "Driver={ODBC Driver 17 for SQL Server};Server=localhost;Database=VectorSearchDB;Trusted_Connection=yes" \
    --postgres-conn "host=localhost dbname=postgres user=postgres" \
    --dataset small_10k_1536d \
    --output-dir results
```

#### Manual (SQL Server)

```sql
-- Run full benchmark suite
EXEC dbo.sp_run_benchmark_suite 
    @dataset_name = 'small_10k_1536d',
    @run_insert = 1,
    @run_index_build = 1,
    @run_search = 1;

-- View results
EXEC dbo.sp_benchmark_summary_report;

-- Detailed results
SELECT * FROM dbo.BenchmarkResults
ORDER BY test_date DESC;
```

#### Manual (PostgreSQL)

```sql
-- Run full benchmark suite
SELECT run_benchmark_suite('small_10k_1536d');

-- View summary
SELECT benchmark_summary_report();

-- Detailed results
SELECT * FROM benchmark_results
ORDER BY test_date DESC;
```

---

## Benchmark Categories

### 1. Insert Performance

**What it measures**: Time to bulk load vectors into the database

**Metrics**:
- Total elapsed time
- Throughput (vectors/second)
- Memory usage

**SQL Server**:
```sql
EXEC dbo.sp_benchmark_bulk_insert @dataset_name = 'test_data';
```

**pgvector**:
```sql
SELECT benchmark_bulk_insert('test_data');
```

### 2. Index Build Performance

**What it measures**: Time to create vector indexes

**Index Types Tested**:

| SQL Server FAISS | pgvector | Description |
|-----------------|----------|-------------|
| FLAT | - | Exact search (baseline) |
| HNSW | hnsw | Hierarchical graph index |
| IVF | ivfflat | Inverted file index |

**Parameters**:
- **HNSW**: M (connections), efConstruction, efSearch
- **IVF**: nlist (clusters), nprobe (search clusters)

**SQL Server**:
```sql
EXEC dbo.sp_benchmark_index_build 
    @table_name = 'VectorsTest_FAISS',
    @column_name = 'vector',
    @index_type = 'HNSW',
    @metric = 'L2',
    @dataset_size = 100000,
    @dimension = 1536;
```

**pgvector**:
```sql
SELECT benchmark_index_build(
    'vectors_test_pgvector',
    'vector',
    'hnsw',
    'vector_l2_ops',
    NULL, 32, 200  -- M, efConstruction
);
```

### 3. Search Performance (KNN)

**What it measures**: Query throughput and latency

**Test Scenarios**:
- Sequential scan (no index) - baseline
- Indexed search with different index types
- Varying K values (1, 10, 100)
- Different distance metrics (L2, cosine, inner product)

**Metrics**:
- Queries per second (QPS)
- Average latency per query (ms)
- P50, P95, P99 latencies

**SQL Server**:
```sql
-- Sequential scan
EXEC dbo.sp_benchmark_knn_search
    @table_name = 'VectorsTest_FAISS',
    @k = 10,
    @num_queries = 100,
    @use_index = 0;

-- HNSW indexed
EXEC dbo.sp_benchmark_knn_search
    @table_name = 'VectorsTest_FAISS',
    @k = 10,
    @num_queries = 100,
    @use_index = 1,
    @index_type = 'HNSW';
```

**pgvector**:
```sql
-- Sequential scan
SELECT benchmark_knn_search(
    'vectors_test_pgvector', 'vector',
    10, 100, FALSE
);

-- HNSW indexed
SELECT benchmark_knn_search(
    'vectors_test_pgvector', 'vector',
    10, 100, TRUE, 'hnsw'
);
```

### 4. Recall/Accuracy Tests

**What it measures**: Quality of approximate search results

**Recall@K**: Percentage of true K nearest neighbors found by approximate search

**Formula**: `recall@K = |approximate_results ∩ exact_results| / K`

**Typical Values**:
- **> 0.95**: Excellent
- **0.90-0.95**: Good (acceptable for most use cases)
- **< 0.90**: Poor (needs parameter tuning)

**SQL Server**:
```sql
EXEC dbo.sp_benchmark_recall
    @table_name = 'VectorsTest_FAISS',
    @k = 10,
    @num_queries = 100,
    @index_type = 'HNSW';
```

**pgvector**:
```sql
SELECT benchmark_recall(
    'vectors_test_pgvector', 'vector',
    10, 100, 'hnsw'
);
```

---

## Expected Performance Characteristics

### Dataset Size Impact

| Dataset | Sequential Scan | HNSW (M=32) | IVF (nlist=100) |
|---------|----------------|-------------|-----------------|
| 1K | Fast (~1ms) | Similar | Slower (overhead) |
| 10K | Moderate (~10ms) | Fast (~2ms) | Fast (~3ms) |
| 100K | Slow (~100ms) | Fast (~3ms) | Fast (~5ms) |
| 1M+ | Very Slow (>1s) | Fast (~5ms) | Moderate (~20ms) |

### Index Type Tradeoffs

**FLAT (Exact Search)**
- ✅ 100% recall
- ✅ No training required
- ❌ Slow for large datasets
- **Use case**: Small datasets (<10K), exact results required

**HNSW**
- ✅ High recall (>95%)
- ✅ Fast queries
- ✅ No training required
- ❌ Larger memory footprint
- ❌ Slower index build
- **Use case**: High-quality results, moderate dataset size

**IVF/IVFFlat**
- ✅ Good recall (90-95%)
- ✅ Fast index build
- ✅ Smaller memory footprint
- ❌ Requires training
- ❌ Moderate query speed
- **Use case**: Large datasets, acceptable accuracy

### Dimension Impact

| Dimension | Memory/Vector | Index Build Time | Search Latency |
|-----------|--------------|------------------|----------------|
| 128 | 512 bytes | Baseline | Baseline |
| 384 | 1.5 KB | ~2x | ~1.5x |
| 768 | 3 KB | ~3x | ~2x |
| 1536 | 6 KB | ~5x | ~3x |

---

## Performance Tuning

### SQL Server FAISS

#### HNSW Parameters

```sql
-- High recall (slower build, faster search)
{
    "M": 64,
    "efConstruction": 500,
    "efSearch": 200
}

-- Balanced (default)
{
    "M": 32,
    "efConstruction": 200,
    "efSearch": 100
}

-- Fast build (lower recall)
{
    "M": 16,
    "efConstruction": 100,
    "efSearch": 50
}
```

#### IVF Parameters

```sql
-- nlist: sqrt(N) to N/100
-- nprobe: 1 to nlist/10

-- For 1M vectors:
{
    "nlist": 1000,
    "nprobe": 50
}

-- For 100K vectors:
{
    "nlist": 316,
    "nprobe": 20
}
```

### pgvector

#### HNSW

```sql
-- High quality
WITH (m = 64, ef_construction = 200)

-- Balanced
WITH (m = 16, ef_construction = 64)

-- Fast build
WITH (m = 8, ef_construction = 32)
```

#### IVFFlat

```sql
-- Lists: sqrt(N)
-- For 1M vectors
WITH (lists = 1000)

-- Set probes at query time
SET ivfflat.probes = 50;
```

---

## Interpreting Results

### Index Build Time

**Acceptable**:
- 1K vectors: < 1 second
- 10K vectors: < 10 seconds
- 100K vectors: < 2 minutes
- 1M vectors: < 20 minutes

**Red flags**:
- Linear scaling with dataset size for HNSW (should be N log N)
- IVF slower than HNSW (should be faster to build)

### Search QPS (K=10)

**Good Performance**:
- 1K vectors: > 500 QPS (sequential scan acceptable)
- 10K vectors: > 1000 QPS with index
- 100K vectors: > 500 QPS with index
- 1M vectors: > 200 QPS with index

**Excellent Performance**:
- Any size: > 1000 QPS with HNSW

### Recall

**Target**: > 0.95 for production

**If recall < 0.90**:
1. Increase `efConstruction` (HNSW) or `nprobe` (IVF)
2. Use larger `M` (HNSW) or more `lists` (IVF)
3. Consider switching index type
4. Check data quality (normalization, outliers)

---

## Comparison Metrics

The benchmark suite generates these comparisons:

### 1. Speedup Factor

```
Speedup = Time_Baseline / Time_Indexed

Example:
Sequential: 100ms
HNSW: 5ms
Speedup: 20x
```

### 2. Throughput Ratio

```
Throughput_Ratio = QPS_SystemA / QPS_SystemB

Example:
SQL Server FAISS: 800 QPS
pgvector: 600 QPS
Ratio: 1.33x (SQL Server 33% faster)
```

### 3. Quality-Adjusted Performance

```
QAP = (Recall × QPS) / Build_Time

Higher is better (balances accuracy, speed, build cost)
```

---

## Example Results (Expected)

### Small Dataset (10K vectors, 1536d)

| System | Index Type | Build Time | QPS | Recall@10 |
|--------|-----------|-----------|-----|-----------|
| SQL FAISS | HNSW | 15s | 850 | 0.97 |
| pgvector | hnsw | 12s | 780 | 0.96 |
| SQL FAISS | IVF | 8s | 650 | 0.93 |
| pgvector | ivfflat | 6s | 600 | 0.92 |

### Large Dataset (1M vectors, 1536d)

| System | Index Type | Build Time | QPS | Recall@10 |
|--------|-----------|-----------|-----|-----------|
| SQL FAISS | HNSW | 18m | 320 | 0.96 |
| pgvector | hnsw | 15m | 280 | 0.95 |
| SQL FAISS | IVF | 5m | 180 | 0.91 |
| pgvector | ivfflat | 4m | 150 | 0.90 |

**Note**: Actual results depend on hardware, configuration, and data characteristics.

---

## Troubleshooting

### Benchmark Fails to Run

1. **Check dependencies**: `pip install psycopg2-binary pyodbc pandas matplotlib seaborn`
2. **Verify connections**: Test database connectivity separately
3. **Check data**: Ensure test data is loaded correctly
4. **Review logs**: Check SQL error messages

### Poor Performance

1. **Memory**: Ensure sufficient RAM (2x dataset size recommended)
2. **CPU**: Vector operations are CPU-intensive
3. **Storage**: Use SSD for index files
4. **Concurrency**: Run benchmarks with no other load

### Inconsistent Results

1. **Cache effects**: Clear cache between runs or use larger datasets
2. **Background processes**: Stop other services
3. **Warmup**: Run queries once before timing
4. **Statistics**: Run multiple iterations and average

---

## Automated CI/CD Benchmarks

Create a benchmark pipeline:

```bash
#!/bin/bash
# ci_benchmark.sh

# Generate test data
./generate_test_data.py --preset standard

# Run benchmarks
./run_benchmarks.py \
    --sqlserver-conn "$SQL_CONN_STRING" \
    --postgres-conn "$PG_CONN_STRING" \
    --dataset small_10k_1536d \
    --output-dir results/$(date +%Y%m%d_%H%M%S)

# Check thresholds
python check_performance_regression.py results/latest
```

Add to your CI pipeline to catch performance regressions!

---

## Next Steps

1. **Run baseline benchmarks** with standard dataset
2. **Tune parameters** based on your use case
3. **Test with real data** from your application
4. **Monitor production** metrics and compare
5. **Iterate** on index configuration

For questions or issues, see the main [README.md](../README.md) or open an issue on GitHub.
