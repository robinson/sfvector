# sfvector

**Open-source vector similarity search for SQL Server**

A high-performance vector similarity search extension for SQL Server, inspired by [pgvector](https://github.com/pgvector/pgvector) and powered by [FAISS](https://github.com/facebookresearch/faiss) (Facebook AI Similarity Search).

> **Project Name**: **sfvector** = **S**QL Server + **F**AISS + **Vector**
> 
> **Version**: 0.1.0  
> **Maintainer**: robinson  
> **License**: PostgreSQL License

## 🎯 Overview

This project brings advanced vector similarity search capabilities to SQL Server, enabling:
- **Semantic search** for AI/ML applications
- **Recommendation systems** using embeddings
- **Image/document similarity** search
- **Anomaly detection** using vector representations

## 🏗️ Architecture

### Design Approaches Considered

1. **SQL CLR (Common Language Runtime)** ✅ Recommended
   - Native integration with SQL Server
   - Can call C++/FAISS via C++/CLI or P/Invoke
   - User-defined types, functions, and stored procedures
   - Security sandbox limitations
   
2. **External Service Architecture**
   - Separate service (Python/C++) communicating via REST/gRPC
   - More flexible but requires external infrastructure
   - Better for heavy GPU workloads

3. **SQL Server External Procedures (sp_execute_external_script)**
   - Limited to Python/R runtimes
   - Good for prototyping

**Chosen Approach**: **Hybrid - SQL CLR + Native C++ Library**
- C# CLR layer for SQL Server integration
- C++ native library wrapping FAISS
- Clean separation of concerns

## 📦 Components

### 1. SqlServer.VectorSearch (C# - SQL CLR)
- User-defined vector type (VECTOR)
- SQL functions for vector operations
- Index management procedures
- Distance/similarity functions

### 2. SqlServer.VectorSearch.Native (C++)
- FAISS library wrapper
- Index serialization/deserialization
- High-performance search operations
- Memory management

### 3. SqlServer.VectorSearch.Tests
- Unit tests
- Integration tests
- Performance benchmarks

## 🚀 Features (Planned)

### Vector Data Type
```sql
CREATE TABLE documents (
    id INT PRIMARY KEY,
    content NVARCHAR(MAX),
    embedding VECTOR(1536)  -- OpenAI ada-002 dimension
);
```

### Index Types (FAISS)
- **FLAT**: Exact search (brute force)
- **IVF**: Inverted file index (clustering-based)
- **HNSW**: Hierarchical Navigable Small World graphs
- **IVF_FLAT**: IVF with flat quantization
- **IVF_PQ**: IVF with product quantization (compression)

### Distance Metrics
- L2 (Euclidean distance)
- Inner Product (dot product)
- Cosine Similarity

### Operations
```sql
-- Insert vectors
INSERT INTO documents (id, content, embedding)
VALUES (1, 'Hello world', VECTOR('[0.1, 0.2, ...]'));

-- Create FAISS index
EXEC sp_create_vector_index 
    @table = 'documents',
    @column = 'embedding',
    @index_type = 'HNSW',
    @metric = 'L2';

-- Similarity search
SELECT TOP 10 id, content, 
    vector_distance(embedding, VECTOR('[0.1, 0.2, ...]'), 'L2') as distance
FROM documents
ORDER BY embedding <-> VECTOR('[0.1, 0.2, ...]');  -- KNN operator

-- Or using function
SELECT * FROM vector_search(
    'documents',
    'embedding', 
    VECTOR('[0.1, 0.2, ...]'),
    10,  -- top k
    'L2'
);
```

## 📋 Comparison with pgvector

| Feature | pgvector | SQL Server FAISS |
|---------|----------|------------------|
| Database | PostgreSQL | SQL Server |
| Backend | Custom C | FAISS (Facebook) |
| Vector Type | ✅ | ✅ (Planned) |
| HNSW Index | ✅ | ✅ (via FAISS) |
| IVF Index | ✅ | ✅ (via FAISS) |
| GPU Support | ❌ | ✅ (FAISS GPU) |
| Compression/PQ | Limited | ✅ (FAISS PQ) |
| Max Dimensions | 16,000 | Limited by FAISS |

## 🛠️ Technology Stack

- **C#**: SQL CLR integration (.NET Framework 4.8 or .NET Core/5+)
- **C++17**: Native FAISS wrapper
- **FAISS**: Vector similarity search library
- **CMake**: Build system for native code
- **MSBuild/dotnet**: Build system for C# code

## 📂 Project Structure

```
sfvector/
├── src/
│   ├── SqlServer.VectorSearch/          # C# SQL CLR project
│   │   ├── Types/
│   │   │   └── VectorType.cs           # UDT for VECTOR
│   │   ├── Functions/
│   │   │   ├── DistanceFunctions.cs
│   │   │   └── VectorOperations.cs
│   │   ├── Procedures/
│   │   │   └── IndexManagement.cs
│   │   └── Native/
│   │       └── FaissInterop.cs         # P/Invoke to native lib
│   ├── SqlServer.VectorSearch.Native/   # C++ FAISS wrapper
│   │   ├── include/
│   │   │   └── faiss_wrapper.h
│   │   ├── src/
│   │   │   └── faiss_wrapper.cpp
│   │   └── CMakeLists.txt
│   └── SqlServer.VectorSearch.Tests/
├── benchmarks/                          # Performance testing suite
│   ├── generate_test_data.py
│   ├── run_benchmarks.py
│   ├── sqlserver_benchmarks.sql
│   ├── pgvector_benchmarks.sql
│   └── BENCHMARK_GUIDE.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── API.md
│   └── DEPLOYMENT.md
├── examples/
│   └── semantic_search_example.sql
├── scripts/
│   ├── build.sh
│   └── deploy.sql
├── LICENSE
└── README.md
```

## 🏁 Getting Started

### Prerequisites
- SQL Server 2019+ (with CLR enabled)
- Visual Studio 2019+ or MSBuild
- CMake 3.15+
- FAISS library
- .NET Framework 4.8 or .NET 6+

### Installation
```bash
# Build native library
cd src/SqlServer.VectorSearch.Native
mkdir build && cd build
cmake ..
cmake --build .

# Build CLR assembly
cd ../../SqlServer.VectorSearch
dotnet build

# Deploy to SQL Server
sqlcmd -S localhost -i scripts/deploy.sql
```

## 🗺️ Roadmap

- [x] Project setup and architecture design
- [x] Implement vector UDT in C#
- [x] Create C++ FAISS wrapper
- [x] Implement distance functions (L2, Cosine, IP)
- [x] Implement vector operations (15+ functions)
- [x] Add FLAT index support
- [x] Add HNSW index support
- [x] Add IVF index support
- [x] Implement KNN search
- [x] Add batch operations
- [x] Performance benchmarking suite
- [x] Documentation and examples
- [ ] Deploy and test with real FAISS library
- [ ] GPU support (optional)
- [ ] Product quantization support
- [ ] Production deployment guide

## 📚 Resources

- [FAISS Documentation](https://github.com/facebookresearch/faiss)
- [pgvector](https://github.com/pgvector/pgvector)
- [SQL Server CLR Integration](https://docs.microsoft.com/en-us/sql/relational-databases/clr-integration/)

## 📄 License

sfvector is inspired by pgvector and uses FAISS, both excellent open-source projects:
- **pgvector**: https://github.com/pgvector/pgvector
- **FAISS**: https://github.com/facebookresearch/faiss

## 🤝 Contributing

Contributions welcome! Please read CONTRIBUTING.md for guidelines.
# sfvector
