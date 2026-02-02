# Architecture Design

## System Overview

SQL Server Vector Search with FAISS is designed as a hybrid system combining SQL Server's CLR integration with native FAISS performance.

```
┌─────────────────────────────────────────────────────────┐
│                    SQL Server                            │
│  ┌───────────────────────────────────────────────────┐  │
│  │         SQL CLR Assembly (.NET/C#)                │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  User-Defined Types (UDT)                   │  │  │
│  │  │  - VectorType (stores float[])              │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  User-Defined Functions (UDF)               │  │  │
│  │  │  - vector_distance()                        │  │  │
│  │  │  - vector_norm()                            │  │  │
│  │  │  - cosine_similarity()                      │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Stored Procedures                          │  │  │
│  │  │  - sp_create_vector_index                   │  │  │
│  │  │  - sp_drop_vector_index                     │  │  │
│  │  │  - sp_vector_search (KNN)                   │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                      ↕                             │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  P/Invoke Interop Layer                     │  │  │
│  │  │  - FaissInterop.cs                          │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                         ↕ (DLL calls)
┌─────────────────────────────────────────────────────────┐
│         Native C++ Library (FAISS Wrapper)               │
│  ┌───────────────────────────────────────────────────┐  │
│  │  C API Export Layer                              │  │
│  │  - create_index(), add_vectors(), search()       │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Index Management                                │  │
│  │  - IndexFactory, IndexSerializer                 │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  FAISS Integration                               │  │
│  │  - IndexFlatL2, IndexHNSWFlat, IndexIVFFlat      │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Component Details

### 1. SQL CLR Assembly (C#)

#### VectorType (UDT)
- **Purpose**: Store and serialize vector data
- **Storage**: Binary format (header + float array)
- **Methods**:
  - `Parse()`: Convert string representation to vector
  - `ToString()`: Convert vector to string
  - `Read(BinaryReader)`: Deserialize from SQL
  - `Write(BinaryWriter)`: Serialize to SQL
  - Indexable: Yes (byte comparison for exact match only)

#### User-Defined Functions
- **vector_distance(v1, v2, metric)**: Calculate distance between vectors
- **vector_norm(v)**: Calculate L2 norm
- **cosine_similarity(v1, v2)**: Cosine similarity
- **vector_add(v1, v2)**: Element-wise addition
- **vector_subtract(v1, v2)**: Element-wise subtraction
- **vector_multiply(v, scalar)**: Scalar multiplication

#### Stored Procedures
- **sp_create_vector_index**: Create FAISS index
  - Parameters: table, column, index_type, metric, options
  - Stores metadata in system table
  - Builds index using native library
  
- **sp_drop_vector_index**: Drop FAISS index
  
- **sp_vector_search**: KNN search
  - Parameters: query_vector, k, table, column, metric
  - Returns: TOP k results with distances
  
- **sp_rebuild_vector_index**: Rebuild index (after bulk inserts)

### 2. Native C++ Library

#### C API Layer
```cpp
extern "C" {
    // Index creation
    EXPORT void* faiss_create_index(const char* index_type, int dimension, const char* metric);
    
    // Vector operations
    EXPORT int faiss_add_vectors(void* index, float* vectors, int64_t* ids, int count);
    EXPORT int faiss_search(void* index, float* query, int k, int64_t* ids, float* distances);
    
    // Index management
    EXPORT int faiss_save_index(void* index, const char* path);
    EXPORT void* faiss_load_index(const char* path);
    EXPORT void faiss_destroy_index(void* index);
    
    // Index info
    EXPORT int64_t faiss_get_ntotal(void* index);
    EXPORT int faiss_get_dimension(void* index);
}
```

#### Index Types Supported

1. **IndexFlatL2** / **IndexFlatIP**
   - Brute force exact search
   - No training required
   - Best for: Small datasets (<100k), exact results

2. **IndexHNSWFlat**
   - Hierarchical Navigable Small World
   - No training required
   - Best for: High recall, moderate dataset size
   - Parameters: M (connections), efConstruction, efSearch

3. **IndexIVFFlat**
   - Inverted file with flat encoding
   - Requires training
   - Best for: Large datasets, speed over accuracy
   - Parameters: nlist (clusters), nprobe (search clusters)

4. **IndexIVFPQ**
   - Inverted file with product quantization
   - Compression for memory efficiency
   - Requires training
   - Best for: Very large datasets, memory constrained

### 3. Data Flow

#### Index Creation
```
SQL: EXEC sp_create_vector_index @table='docs', @column='embedding', @type='HNSW'
  ↓
CLR: IndexManagement.CreateVectorIndex()
  ↓
CLR: Read vectors from table into memory
  ↓
P/Invoke: faiss_create_index("HNSW", 1536, "L2")
  ↓
Native: Create faiss::IndexHNSWFlat
  ↓
P/Invoke: faiss_add_vectors(index, vectors, ids, count)
  ↓
Native: index->add_with_ids()
  ↓
P/Invoke: faiss_save_index(index, "C:\\VectorIndexes\\docs_embedding.idx")
  ↓
CLR: Store metadata in [sys_vector_indexes] table
  ↓
SQL: Index created successfully
```

#### KNN Search
```
SQL: SELECT * FROM vector_search('docs', 'embedding', @query, 10, 'L2')
  ↓
CLR: VectorSearch.Execute()
  ↓
CLR: Load index metadata, get index path
  ↓
P/Invoke: faiss_load_index("C:\\VectorIndexes\\docs_embedding.idx")
  ↓
P/Invoke: faiss_search(index, query_vector, 10, result_ids, distances)
  ↓
Native: index->search()
  ↓
CLR: Join result IDs with original table
  ↓
SQL: Return result set with distances
```

## Storage Strategy

### Vector Storage
- **Table Column**: VECTOR UDT (binary format)
- **Format**: [dimension:int32][values:float32[]]
- **Max Size**: 8000 bytes (SQL Server limit) = ~2000 dimensions
- **For larger vectors**: Use VARBINARY(MAX)

### Index Storage
- **Location**: File system (accessible by SQL Server service account)
- **Path**: Configurable, default: SQL Server data directory + "VectorIndexes"
- **Format**: FAISS binary format (.idx files)
- **Metadata**: SQL Server table [sys_vector_indexes]

```sql
CREATE TABLE sys_vector_indexes (
    index_id INT IDENTITY PRIMARY KEY,
    table_name NVARCHAR(256),
    column_name NVARCHAR(256),
    index_type NVARCHAR(50),
    metric_type NVARCHAR(50),
    dimension INT,
    ntotal BIGINT,
    index_path NVARCHAR(512),
    created_date DATETIME,
    last_rebuilt DATETIME,
    options NVARCHAR(MAX)  -- JSON parameters
);
```

## Performance Considerations

### Memory Management
- **CLR**: Keep index handles in static cache (LRU eviction)
- **Native**: Use FAISS's own memory management
- **Limit**: Configure max indexes in memory

### Concurrency
- **Read-Heavy**: Multiple concurrent searches (thread-safe FAISS operations)
- **Writes**: Lock during index rebuild
- **Strategy**: Periodic batch rebuilds vs. incremental updates

### Scalability
- **Horizontal**: Partition tables, separate indexes per partition
- **Vertical**: Use GPU for large-scale operations (FAISS GPU)
- **Caching**: Cache frequently accessed indexes

## Security Considerations

- **CLR Permission Set**: UNSAFE (required for P/Invoke to native DLL)
- **File Access**: SQL Server service account needs read/write to index directory
- **SQL Injection**: Parameterized queries in all procedures
- **DLL Trust**: Sign assemblies, verify native library integrity

## Alternative Architectures Considered

### 1. Pure Python Service
- **Pros**: Easier FAISS integration, rich ecosystem
- **Cons**: External dependency, network latency, serialization overhead
- **Use Case**: If GPU support is primary requirement

### 2. SQL Server External Scripts (sp_execute_external_script)
- **Pros**: Built-in Python/R integration
- **Cons**: Limited to bundled packages, performance overhead
- **Use Case**: Prototyping only

### 3. C++/CLI Mixed Mode
- **Pros**: Direct C++ to C# interop, no P/Invoke
- **Cons**: Complexity, .NET Framework only
- **Use Case**: If targeting .NET Framework exclusively

## Next Steps

1. Prototype VectorType UDT
2. Create basic C++ wrapper with Flat index
3. Implement P/Invoke layer
4. Test round-trip: SQL → CLR → Native → FAISS → Native → CLR → SQL
5. Add HNSW index support
6. Benchmark performance vs. pure T-SQL solutions
