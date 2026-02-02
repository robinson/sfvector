# API Reference

## SQL Server Vector Search API Documentation

### Table of Contents
- [Vector Data Type](#vector-data-type)
- [Distance Functions](#distance-functions)
- [Vector Operations](#vector-operations)
- [Index Management](#index-management)
- [Search Operations](#search-operations)

---

## Vector Data Type

### VectorType

User-defined type for storing vector embeddings.

**Storage Format**: Binary (dimension + float array)

**Maximum Size**: ~1999 dimensions (8000 byte SQL Server limit)

#### Constructors

```sql
-- Parse from string
DECLARE @v VectorType = VectorType::Parse('[1.0, 2.0, 3.0]');

-- Parse from comma-separated values
DECLARE @v VectorType = VectorType::Parse('1.0, 2.0, 3.0');
```

#### Methods

```sql
-- Get dimension
@v.GetDimension() -> INT

-- Get element at index (1-based)
@v.GetElement(1) -> FLOAT

-- Calculate L2 norm
@v.L2Norm() -> FLOAT

-- Normalize to unit length
@v.Normalize() -> VectorType

-- Convert to string
@v.ToString() -> NVARCHAR
```

#### Example Usage

```sql
CREATE TABLE Embeddings (
    id INT PRIMARY KEY,
    vector VectorType
);

INSERT INTO Embeddings VALUES (1, VectorType::Parse('[0.1, 0.2, 0.3]'));

SELECT vector.GetDimension() AS dim, 
       vector.L2Norm() AS magnitude
FROM Embeddings WHERE id = 1;
```

---

## Distance Functions

### L2Distance

Calculate Euclidean (L2) distance between two vectors.

**Syntax**:
```sql
dbo.L2Distance(@v1 VectorType, @v2 VectorType) -> FLOAT
```

**Formula**: `sqrt(sum((a[i] - b[i])^2))`

**Returns**: Distance value (0 = identical, higher = more different)

**Example**:
```sql
SELECT dbo.L2Distance(
    VectorType::Parse('[1, 2, 3]'),
    VectorType::Parse('[4, 5, 6]')
) AS distance;
-- Result: 5.196152422706632
```

---

### L2SquaredDistance

Calculate squared L2 distance (faster, no square root).

**Syntax**:
```sql
dbo.L2SquaredDistance(@v1 VectorType, @v2 VectorType) -> FLOAT
```

**Formula**: `sum((a[i] - b[i])^2)`

---

### CosineSimilarity

Calculate cosine similarity between two vectors.

**Syntax**:
```sql
dbo.CosineSimilarity(@v1 VectorType, @v2 VectorType) -> FLOAT
```

**Formula**: `(a · b) / (||a|| * ||b||)`

**Returns**: Similarity value (-1 to 1, where 1 = identical direction)

**Example**:
```sql
SELECT dbo.CosineSimilarity(
    VectorType::Parse('[1, 0, 0]'),
    VectorType::Parse('[1, 0, 0]')
) AS similarity;
-- Result: 1.0 (identical)
```

---

### CosineDistance

Calculate cosine distance (1 - cosine similarity).

**Syntax**:
```sql
dbo.CosineDistance(@v1 VectorType, @v2 VectorType) -> FLOAT
```

**Returns**: Distance value (0 to 2, where 0 = identical)

---

### InnerProduct

Calculate dot product between two vectors.

**Syntax**:
```sql
dbo.InnerProduct(@v1 VectorType, @v2 VectorType) -> FLOAT
```

**Formula**: `sum(a[i] * b[i])`

---

### VectorDistance

Generic distance function with configurable metric.

**Syntax**:
```sql
dbo.VectorDistance(@v1 VectorType, @v2 VectorType, @metric NVARCHAR(50)) -> FLOAT
```

**Supported Metrics**:
- `'L2'` or `'EUCLIDEAN'` - Euclidean distance
- `'COSINE'` or `'COSINE_SIMILARITY'` - Cosine similarity
- `'COSINE_DISTANCE'` - Cosine distance
- `'IP'` or `'INNER_PRODUCT'` or `'DOT'` - Dot product

**Example**:
```sql
SELECT dbo.VectorDistance(@v1, @v2, 'L2') AS l2_dist,
       dbo.VectorDistance(@v1, @v2, 'COSINE') AS cos_sim;
```

---

## Vector Operations

### VectorAdd

Add two vectors element-wise.

**Syntax**:
```sql
dbo.VectorAdd(@v1 VectorType, @v2 VectorType) -> VectorType
```

**Example**:
```sql
SELECT dbo.VectorAdd(
    VectorType::Parse('[1, 2, 3]'),
    VectorType::Parse('[4, 5, 6]')
).ToString();
-- Result: [5,7,9]
```

---

### VectorSubtract

Subtract second vector from first, element-wise.

**Syntax**:
```sql
dbo.VectorSubtract(@v1 VectorType, @v2 VectorType) -> VectorType
```

---

### VectorMultiply

Multiply vector by scalar.

**Syntax**:
```sql
dbo.VectorMultiply(@v VectorType, @scalar FLOAT) -> VectorType
```

**Example**:
```sql
SELECT dbo.VectorMultiply(VectorType::Parse('[1, 2, 3]'), 2.0).ToString();
-- Result: [2,4,6]
```

---

### VectorNormalize

Normalize vector to unit length (L2 norm = 1).

**Syntax**:
```sql
dbo.VectorNormalize(@v VectorType) -> VectorType
```

---

### VectorSum / VectorMean / VectorMin / VectorMax

Aggregate functions for vector elements.

**Syntax**:
```sql
dbo.VectorSum(@v VectorType) -> FLOAT
dbo.VectorMean(@v VectorType) -> FLOAT
dbo.VectorMin(@v VectorType) -> FLOAT
dbo.VectorMax(@v VectorType) -> FLOAT
```

---

## Index Management

### sp_create_vector_index

Create a FAISS index on a vector column.

**Syntax**:
```sql
EXEC dbo.sp_create_vector_index
    @table_schema NVARCHAR(128),
    @table_name NVARCHAR(128),
    @column_name NVARCHAR(128),
    @index_type NVARCHAR(50),
    @metric NVARCHAR(50),
    @index_options NVARCHAR(MAX) = NULL
```

**Parameters**:
- `@table_schema` - Schema name (e.g., 'dbo')
- `@table_name` - Table name
- `@column_name` - Vector column name
- `@index_type` - Index type: 'FLAT', 'HNSW', 'IVF', 'IVFFLAT'
- `@metric` - Metric type: 'L2', 'IP', 'COSINE'
- `@index_options` - JSON with index-specific parameters (optional)

**Index Options (JSON)**:

For HNSW:
```json
{
  "M": 32,                 // Connections per layer (default: 32)
  "efConstruction": 200,   // Build quality (default: 200)
  "efSearch": 100          // Search quality (default: 100)
}
```

For IVF:
```json
{
  "nlist": 100,    // Number of clusters (default: 100)
  "nprobe": 10     // Clusters to search (default: 10)
}
```

**Example**:
```sql
-- Create HNSW index
EXEC dbo.sp_create_vector_index
    @table_schema = 'dbo',
    @table_name = 'Documents',
    @column_name = 'embedding',
    @index_type = 'HNSW',
    @metric = 'COSINE',
    @index_options = N'{"M": 32, "efConstruction": 200}';
```

---

### sp_drop_vector_index

Drop a FAISS index.

**Syntax**:
```sql
EXEC dbo.sp_drop_vector_index
    @table_schema NVARCHAR(128),
    @table_name NVARCHAR(128),
    @column_name NVARCHAR(128)
```

---

### sp_rebuild_vector_index

Rebuild index (useful after bulk inserts).

**Syntax**:
```sql
EXEC dbo.sp_rebuild_vector_index
    @table_schema NVARCHAR(128),
    @table_name NVARCHAR(128),
    @column_name NVARCHAR(128)
```

---

## Search Operations

### sp_vector_search

Perform k-nearest neighbor search using FAISS index.

**Syntax**:
```sql
EXEC dbo.sp_vector_search
    @table_schema NVARCHAR(128),
    @table_name NVARCHAR(128),
    @column_name NVARCHAR(128),
    @query_vector NVARCHAR(MAX),
    @k INT,
    @metric NVARCHAR(50) = NULL
```

**Parameters**:
- `@table_schema` - Schema name
- `@table_name` - Table name
- `@column_name` - Vector column name
- `@query_vector` - Query vector as string '[1.0, 2.0, ...]'
- `@k` - Number of nearest neighbors to return
- `@metric` - Override metric (optional, uses index metric by default)

**Returns**: Result set with columns:
- `id` - Row identifier
- `distance` - Distance to query vector
- Other columns from the original table

**Example**:
```sql
-- Find 5 most similar documents
EXEC dbo.sp_vector_search
    @table_schema = 'dbo',
    @table_name = 'Documents',
    @column_name = 'embedding',
    @query_vector = '[0.1, 0.2, 0.3, ...]',
    @k = 5,
    @metric = 'COSINE';
```

---

### Manual Search (without index)

For small datasets or when index is not available:

```sql
DECLARE @query VectorType = VectorType::Parse('[0.1, 0.2, 0.3]');

SELECT TOP 10
    id,
    title,
    dbo.CosineSimilarity(embedding, @query) AS similarity
FROM Documents
ORDER BY dbo.CosineSimilarity(embedding, @query) DESC;
```

---

## Performance Tips

### Index Selection

| Dataset Size | Accuracy Need | Recommended Index | Parameters |
|-------------|---------------|-------------------|------------|
| < 10K | Exact | FLAT | - |
| 10K - 1M | High | HNSW | M=32, ef=200 |
| 1M - 10M | Medium | IVFFlat | nlist=4096, nprobe=32 |
| 10M+ | Low-Medium | IVFPQ | nlist=16384, PQ compression |

### Metric Selection

- **L2 (Euclidean)**: General purpose, actual distance
- **Cosine**: Direction-based, good for normalized embeddings
- **Inner Product**: When embeddings are already normalized

### Optimization

1. **Batch operations**: Use bulk inserts, rebuild index after
2. **Normalize vectors**: If using cosine/IP, normalize beforehand
3. **Index parameters**: Tune M, ef, nprobe based on accuracy/speed tradeoff
4. **Dimension reduction**: Consider PCA/dimensionality reduction for very high dimensions

---

## Error Handling

Common errors and solutions:

**"Dimension mismatch"**
- Ensure all vectors in a column have the same dimension
- Verify query vector matches table vector dimension

**"Index not trained"**
- IVF indexes require training data
- Ensure table has data before creating IVF index

**"Assembly permission error"**
- Enable CLR in SQL Server: `sp_configure 'clr enabled', 1`
- Set UNSAFE permission or sign assembly

**"Native library not found"**
- Ensure SqlServer.VectorSearch.Native.dll is in same directory as CLR assembly
- Check SQL Server service account has read access to DLL path

---

## System Tables

### sys_vector_indexes

Metadata about created vector indexes.

**Schema**:
```sql
CREATE TABLE dbo.sys_vector_indexes (
    index_id INT IDENTITY PRIMARY KEY,
    table_schema NVARCHAR(128),
    table_name NVARCHAR(128),
    column_name NVARCHAR(128),
    index_type NVARCHAR(50),
    metric_type NVARCHAR(50),
    dimension INT,
    ntotal BIGINT,
    index_path NVARCHAR(512),
    index_options NVARCHAR(MAX),
    created_date DATETIME2,
    last_rebuilt DATETIME2,
    is_active BIT
);
```

**Query Example**:
```sql
SELECT * FROM dbo.sys_vector_indexes
WHERE table_name = 'Documents';
```
