# SQL Server 2025 Native Vector Search Comparison

Benchmarks comparing **SQL Server 2025 native vector search**, **sfvector (FAISS)**, and **pgvector**.

## Overview

SQL Server 2025 introduces native support for vector data types and vector search operations. This benchmark suite compares:

1. **SQL Server 2025 Native** - Built-in `VECTOR` type with HNSW/DiskANN indexes
2. **sfvector (FAISS)** - Our implementation using FAISS with SQL CLR
3. **pgvector** - PostgreSQL vector extension (for reference)

## Key Features Compared

| Feature | SQL Server 2025 | sfvector (FAISS) | pgvector |
|---------|-----------------|------------------|----------|
| **Vector Type** | Native `VECTOR(n)` | Custom UDT | Native `vector(n)` |
| **Index Types** | HNSW, DiskANN | FLAT, HNSW, IVF, IVF-PQ | IVFFlat, HNSW |
| **Distance Metrics** | L2, Cosine, IP | L2, Cosine, IP, Manhattan | L2, Cosine, IP |
| **Max Dimensions** | 16,000+ | ~1999 (UDT), unlimited (VARBINARY) | 16,000 |
| **GPU Support** | Limited | ✅ Yes (FAISS GPU) | ❌ No |
| **Quantization** | Limited | ✅ Full (PQ, SQ) | ⚠️ Limited |

## Quick Start

### 1. Set Up Test Environment

```bash
# Install dependencies
pip install pyodbc psycopg2-binary pandas matplotlib seaborn

# Ensure SQL Server 2025 is installed
# Ensure PostgreSQL with pgvector is installed (optional)
```

### 2. Deploy Benchmark Schema

```bash
# Deploy SQL Server 2025 benchmark procedures
sqlcmd -S localhost -d VectorSearchDB -i sqlserver2025_comparison.sql

# Deploy pgvector benchmarks (optional)
psql -h localhost -d vectordb -f pgvector_benchmarks.sql
```

### 3. Run Benchmarks

```bash
# Three-way comparison (SQL2025 + sfvector + pgvector)
python run_sql2025_comparison.py \
    --sqlserver-conn "Driver={ODBC Driver 18 for SQL Server};Server=localhost;Database=VectorSearchDB;Trusted_Connection=yes;" \
    --postgres-conn "host=localhost dbname=vectordb user=postgres" \
    --dataset-size 10000 \
    --dimension 1536

# SQL Server only (native vs FAISS)
python run_sql2025_comparison.py \
    --sqlserver-conn "..." \
    --skip-pgvector \
    --dataset-size 100000
```

## Benchmark Categories

### 1. Insert Performance
- **Metric**: Vectors inserted per second
- **Test**: Bulk insert of N vectors
- **Expected**: SQL2025 ≈ sfvector > pgvector

### 2. Index Build Time
- **Metric**: Time to build index (milliseconds)
- **Indexes Tested**: 
  - SQL2025: HNSW, DiskANN
  - sfvector: FAISS HNSW, FAISS IVF
  - pgvector: HNSW, IVFFlat
- **Expected**: pgvector fastest, SQL2025 ≈ sfvector

### 3. Search Performance (QPS)
- **Metric**: Queries per second (K=10)
- **Test**: 100 KNN searches
- **Expected**: sfvector (FAISS) > SQL2025 > pgvector

### 4. Recall Quality
- **Metric**: Recall@K accuracy
- **Test**: Compare approximate vs exact search
- **Expected**: All implementations >95% recall

## Expected Results (10K vectors, 1536 dimensions)

| Metric | SQL Server 2025 | sfvector (FAISS) | pgvector | Winner |
|--------|-----------------|------------------|----------|---------|
| **Insert** | 800 ops/sec | 750 ops/sec | 900 ops/sec | pgvector 🏆 |
| **Index Build (HNSW)** | 18s | 20s | 15s | pgvector 🏆 |
| **Search QPS** | 700 | 850 | 780 | **sfvector** 🏆 |
| **Recall@10** | 96% | 97% | 96% | Tie 🤝 |
| **Memory Usage** | Medium | High | Low | pgvector 🏆 |

### Observations

**SQL Server 2025 Native Vectors:**
- ✅ Native integration with SQL Server
- ✅ No external dependencies
- ✅ Familiar SQL syntax
- ⚠️ Newer technology (less mature)
- ⚠️ Limited index options vs FAISS

**sfvector (FAISS):**
- ✅ Highest search throughput
- ✅ Most index options (FLAT, HNSW, IVF, IVF-PQ)
- ✅ GPU acceleration available
- ✅ Advanced quantization (PQ, SQ)
- ⚠️ Requires CLR and native library
- ⚠️ Higher memory usage

**pgvector:**
- ✅ Fastest index builds
- ✅ Lowest memory usage
- ✅ Mature and stable
- ✅ Large community
- ⚠️ Requires PostgreSQL
- ⚠️ Limited GPU support

## Usage Examples

### SQL Server 2025 Native Syntax

```sql
-- Create table with native VECTOR type
CREATE TABLE Documents (
    id INT PRIMARY KEY,
    embedding VECTOR(1536) NOT NULL,
    content NVARCHAR(MAX)
);

-- Insert vectors
INSERT INTO Documents (id, embedding, content)
VALUES (1, CAST('[0.1, 0.2, ..., 0.n]' AS VECTOR(1536)), 'Sample text');

-- Create HNSW index
CREATE VECTOR INDEX IX_Documents_Vector 
ON Documents(embedding)
WITH (ALGORITHM = HNSW, METRIC = COSINE);

-- KNN search
DECLARE @query VECTOR(1536) = CAST('[...]' AS VECTOR(1536));

SELECT TOP 10 
    id, 
    content,
    VECTOR_DISTANCE('COSINE', embedding, @query) AS distance
FROM Documents
ORDER BY VECTOR_DISTANCE('COSINE', embedding, @query);
```

### sfvector (FAISS) Syntax

```sql
-- Create table with sfvector UDT
CREATE TABLE Documents (
    id INT PRIMARY KEY,
    embedding dbo.VectorType NOT NULL,
    content NVARCHAR(MAX)
);

-- Insert vectors
INSERT INTO Documents (id, embedding, content)
VALUES (1, dbo.VectorType::Parse('[0.1, 0.2, ..., 0.n]'), 'Sample text');

-- Create FAISS index
EXEC dbo.sp_create_vector_index 
    @table_name = 'Documents',
    @column_name = 'embedding',
    @index_name = 'faiss_idx',
    @index_type = 'HNSW',
    @metric = 'COSINE';

-- KNN search
EXEC dbo.sp_search_knn
    @table_name = 'Documents',
    @query_vector = '[0.1, 0.2, ..., 0.n]',
    @k = 10,
    @metric = 'COSINE';
```

## Running Custom Benchmarks

### Test Different Dataset Sizes

```bash
# Small (1K vectors)
python run_sql2025_comparison.py --sqlserver-conn "..." --dataset-size 1000

# Medium (100K vectors)
python run_sql2025_comparison.py --sqlserver-conn "..." --dataset-size 100000

# Large (1M vectors)
python run_sql2025_comparison.py --sqlserver-conn "..." --dataset-size 1000000
```

### Test Different Dimensions

```bash
# OpenAI text-embedding-3-small (1536d)
python run_sql2025_comparison.py --sqlserver-conn "..." --dimension 1536

# OpenAI text-embedding-3-large (3072d)
python run_sql2025_comparison.py --sqlserver-conn "..." --dimension 3072

# Custom dimension
python run_sql2025_comparison.py --sqlserver-conn "..." --dimension 768
```

## Analyzing Results

### View Results in SQL

```sql
-- SQL Server 2025 results
SELECT * FROM BenchmarkResults_2025 
ORDER BY test_date DESC;

-- Performance comparison
SELECT * FROM vw_BenchmarkComparison_2025;

-- Performance ratios
SELECT * FROM vw_PerformanceRatio_2025;
```

### Export Results

```bash
# JSON format
cat results_sql2025/benchmark_results_sql2025_comparison.json

# Markdown report
cat results_sql2025/sql2025_comparison_report.md

# Charts (PNG)
ls results_sql2025/*.png
```

## Performance Tuning

### SQL Server 2025

```sql
-- HNSW parameters
CREATE VECTOR INDEX IX_Vector_HNSW
ON Documents(embedding)
WITH (
    ALGORITHM = HNSW,
    METRIC = COSINE,
    M = 32,              -- Connections per layer
    EF_CONSTRUCTION = 200 -- Build-time candidates
);

-- Search-time tuning
SET VECTOR_SEARCH_EF = 100; -- Search-time candidates
```

### sfvector (FAISS)

```sql
-- HNSW parameters
EXEC dbo.sp_create_vector_index
    @index_type = 'HNSW',
    @parameters = '{"M": 64, "efConstruction": 400}';

-- IVF parameters  
EXEC dbo.sp_create_vector_index
    @index_type = 'IVF',
    @parameters = '{"nlist": 1000, "nprobe": 50}';
```

## Troubleshooting

### SQL Server 2025 Not Detected

```bash
# Check SQL Server version
sqlcmd -Q "SELECT @@VERSION"

# If version < 2025, only sfvector benchmarks will run
# Upgrade to SQL Server 2025 or use sfvector-only mode
```

### Connection Issues

```bash
# Test SQL Server connection
python -c "import pyodbc; conn = pyodbc.connect('...')"

# Test PostgreSQL connection
python -c "import psycopg2; conn = psycopg2.connect('...')"
```

### Memory Issues

```bash
# Reduce dataset size
python run_sql2025_comparison.py --dataset-size 1000

# Skip large index builds
python run_sql2025_comparison.py --no-index

# Increase SQL Server memory
sqlcmd -Q "EXEC sp_configure 'max server memory', 8192; RECONFIGURE;"
```

## Recommendations

### Choose SQL Server 2025 Native If:
- You're already using SQL Server 2025
- You want native integration without external dependencies
- You prefer familiar SQL syntax
- You don't need advanced quantization or GPU support

### Choose sfvector (FAISS) If:
- You need maximum search throughput
- You want advanced index options (PQ, SQ, GPU)
- You can use SQL CLR and native libraries
- You're on SQL Server < 2025 but want vector search

### Choose pgvector If:
- You're using PostgreSQL
- You want the most mature vector extension
- You need fast index builds
- Memory efficiency is critical

## Future Enhancements

- [ ] Test DiskANN index (SQL Server 2025)
- [ ] GPU acceleration benchmarks (FAISS)
- [ ] Hybrid search scenarios
- [ ] Larger datasets (10M+ vectors)
- [ ] Multi-dimensional scaling tests
- [ ] Concurrent query benchmarks
- [ ] Update/delete performance tests

## References

- **SQL Server 2025 Vector Search**: [Microsoft Docs](https://learn.microsoft.com/sql/)
- **sfvector (FAISS)**: [GitHub](https://github.com/facebookresearch/faiss)
- **pgvector**: [GitHub](https://github.com/pgvector/pgvector)

## License

Apache License 2.0 - See [LICENSE](../LICENSE) for details
