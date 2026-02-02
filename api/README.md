# sfvector REST API

ASP.NET Core REST API for sfvector, providing HTTP endpoints for vector similarity search operations.

## 🎯 Overview

The sfvector REST API provides a modern, scalable HTTP interface to SQL Server vector search capabilities:

- **ASP.NET Core 8.0** - Modern, high-performance web framework
- **Minimal APIs** - Fast, lightweight endpoints
- **JWT Authentication** - Secure API access
- **Swagger/OpenAPI** - Automatic API documentation
- **Rate Limiting** - Built-in protection
- **Docker Ready** - Containerized deployment
- **Health Checks** - Built-in monitoring

## 🚀 Quick Start

### Using Docker (Recommended)

```bash
# Build and run
docker-compose up -d

# API available at http://localhost:5000
curl http://localhost:5000/health
```

### Manual Setup

```bash
# Build the API
cd api/Sfvector.Api
dotnet restore
dotnet build

# Configure appsettings.json with your SQL Server connection

# Run
dotnet run
```

## 📚 API Documentation

Once running, visit:
- **Swagger UI**: http://localhost:5000/swagger
- **OpenAPI Spec**: http://localhost:5000/swagger/v1/swagger.json

## 🔑 Authentication

All endpoints (except /health) require a JWT bearer token:

```bash
# Login to get token
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}'

# Use token in requests
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:5000/api/vectors
```

## 📖 API Endpoints

### Authentication

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "password"
}

Response: {
  "token": "eyJhbGciOiJIUzI1...",
  "expiresAt": "2026-02-03T17:14:00Z"
}
```

### Vectors

#### Create Vector
```http
POST /api/vectors
Authorization: Bearer {token}
Content-Type: application/json

{
  "id": "doc123",
  "vector": [0.1, 0.2, 0.3, ...],
  "metadata": {
    "title": "Sample Document",
    "category": "tech"
  }
}

Response: 201 Created
{
  "id": "doc123",
  "message": "Vector created successfully"
}
```

#### Batch Insert
```http
POST /api/vectors/batch
Authorization: Bearer {token}
Content-Type: application/json

{
  "vectors": [
    {
      "id": "doc1",
      "vector": [0.1, 0.2, ...],
      "metadata": {"title": "Doc 1"}
    },
    {
      "id": "doc2",
      "vector": [0.3, 0.4, ...],
      "metadata": {"title": "Doc 2"}
    }
  ]
}

Response: 201 Created
{
  "inserted": 2,
  "message": "Batch insert successful"
}
```

#### Get Vector
```http
GET /api/vectors/{id}
Authorization: Bearer {token}

Response: 200 OK
{
  "id": "doc123",
  "vector": [0.1, 0.2, 0.3, ...],
  "metadata": {
    "title": "Sample Document"
  }
}
```

#### Update Vector
```http
PUT /api/vectors/{id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "vector": [0.15, 0.25, 0.35, ...],
  "metadata": {
    "title": "Updated Document"
  }
}
```

#### Delete Vector
```http
DELETE /api/vectors/{id}
Authorization: Bearer {token}

Response: 204 No Content
```

#### List Vectors (Paginated)
```http
GET /api/vectors?page=1&pageSize=50
Authorization: Bearer {token}

Response: 200 OK
{
  "vectors": [...],
  "total": 1500,
  "page": 1,
  "pageSize": 50,
  "totalPages": 30
}
```

### Search

#### KNN Search
```http
POST /api/search/knn
Authorization: Bearer {token}
Content-Type: application/json

{
  "vector": [0.1, 0.2, 0.3, ...],
  "k": 10,
  "metric": "cosine"
}

Response: 200 OK
{
  "results": [
    {
      "id": "doc123",
      "distance": 0.12,
      "similarity": 0.88,
      "metadata": {
        "title": "Sample Document"
      }
    }
  ],
  "queryTimeMs": 5.2,
  "totalResults": 10
}
```

#### Filtered KNN Search
```http
POST /api/search/knn
Authorization: Bearer {token}
Content-Type: application/json

{
  "vector": [0.1, 0.2, ...],
  "k": 10,
  "metric": "cosine",
  "filter": {
    "category": "technology",
    "published": true
  }
}
```

#### Range Search
```http
POST /api/search/range
Authorization: Bearer {token}
Content-Type: application/json

{
  "vector": [0.1, 0.2, 0.3, ...],
  "radius": 0.5,
  "metric": "l2",
  "maxResults": 100
}

Response: 200 OK
{
  "results": [
    {
      "id": "doc456",
      "distance": 0.23,
      "metadata": {...}
    }
  ],
  "totalResults": 45
}
```

### Index Management

#### Create Index
```http
POST /api/indexes
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "documents_hnsw",
  "table": "Documents",
  "column": "Embedding",
  "indexType": "hnsw",
  "metric": "cosine",
  "parameters": {
    "M": 32,
    "efConstruction": 200
  }
}

Response: 201 Created
{
  "name": "documents_hnsw",
  "status": "building",
  "message": "Index creation started"
}
```

#### List Indexes
```http
GET /api/indexes
Authorization: Bearer {token}

Response: 200 OK
{
  "indexes": [
    {
      "name": "documents_hnsw",
      "type": "hnsw",
      "metric": "cosine",
      "vectorCount": 150000,
      "createdAt": "2026-02-01T10:00:00Z",
      "status": "ready"
    }
  ]
}
```

#### Get Index Statistics
```http
GET /api/indexes/{name}/stats
Authorization: Bearer {token}

Response: 200 OK
{
  "name": "documents_hnsw",
  "type": "hnsw",
  "vectorCount": 150000,
  "dimension": 1536,
  "parameters": {
    "M": 32,
    "efConstruction": 200
  },
  "sizeBytes": 524288000,
  "lastUpdated": "2026-02-02T17:00:00Z"
}
```

#### Rebuild Index
```http
POST /api/indexes/{name}/rebuild
Authorization: Bearer {token}

Response: 202 Accepted
{
  "name": "documents_hnsw",
  "status": "rebuilding",
  "estimatedTimeMinutes": 15
}
```

#### Delete Index
```http
DELETE /api/indexes/{name}
Authorization: Bearer {token}

Response: 204 No Content
```

### Health & Monitoring

#### Health Check
```http
GET /health

Response: 200 OK
{
  "status": "Healthy",
  "database": "Connected",
  "version": "1.0.0",
  "timestamp": "2026-02-02T17:14:00Z"
}
```

#### Readiness Check
```http
GET /health/ready

Response: 200 OK
{
  "status": "Ready",
  "checks": {
    "database": "Healthy",
    "vectorSearch": "Healthy"
  }
}
```

#### Liveness Check
```http
GET /health/live

Response: 200 OK
{
  "status": "Alive"
}
```

## 💻 C# Client Example

```csharp
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;

var client = new HttpClient 
{ 
    BaseAddress = new Uri("http://localhost:5000") 
};

// Login
var loginRequest = new { username = "admin", password = "password" };
var loginResponse = await client.PostAsJsonAsync("/api/auth/login", loginRequest);
var loginResult = await loginResponse.Content.ReadFromJsonAsync<LoginResponse>();
client.DefaultRequestHeaders.Authorization = 
    new AuthenticationHeaderValue("Bearer", loginResult.Token);

// Insert vector
var vectorRequest = new 
{
    id = "doc123",
    vector = Enumerable.Range(0, 1536).Select(i => (float)Random.Shared.NextDouble()).ToArray(),
    metadata = new { title = "Example Document", category = "tech" }
};
await client.PostAsJsonAsync("/api/vectors", vectorRequest);

// Search
var searchRequest = new 
{
    vector = Enumerable.Range(0, 1536).Select(i => (float)Random.Shared.NextDouble()).ToArray(),
    k = 10,
    metric = "cosine"
};
var searchResponse = await client.PostAsJsonAsync("/api/search/knn", searchRequest);
var results = await searchResponse.Content.ReadFromJsonAsync<SearchResponse>();

foreach (var result in results.Results)
{
    Console.WriteLine($"{result.Id}: {result.Similarity:F3}");
}
```

## 🌐 JavaScript/TypeScript Client

```typescript
const API_URL = 'http://localhost:5000/api';
let token: string;

// Login
const loginResponse = await fetch(`${API_URL}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'admin', password: 'password' })
});
const loginData = await loginResponse.json();
token = loginData.token;

// Search
const searchResponse = await fetch(`${API_URL}/search/knn`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    vector: Array(1536).fill(0).map(() => Math.random()),
    k: 10,
    metric: 'cosine'
  })
});

const searchData = await searchResponse.json();
console.log(searchData.results);
```

## 🐳 Docker Deployment

### Dockerfile
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 5000

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["Sfvector.Api/Sfvector.Api.csproj", "Sfvector.Api/"]
RUN dotnet restore "Sfvector.Api/Sfvector.Api.csproj"
COPY . .
WORKDIR "/src/Sfvector.Api"
RUN dotnet build -c Release -o /app/build

FROM build AS publish
RUN dotnet publish -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Sfvector.Api.dll"]
```

### Docker Compose
```yaml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "5000:5000"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=VectorDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True
      - Jwt__Secret=your-secret-key-min-32-chars
      - Jwt__Issuer=sfvector-api
      - Jwt__Audience=sfvector-clients
    depends_on:
      - sqlserver
    
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=YourStrong@Passw0rd
    ports:
      - "1433:1433"
    volumes:
      - sqldata:/var/opt/mssql

volumes:
  sqldata:
```

## ⚙️ Configuration

**appsettings.json:**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=VectorDB;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "Jwt": {
    "Secret": "your-secret-key-at-least-32-characters-long",
    "Issuer": "sfvector-api",
    "Audience": "sfvector-clients",
    "ExpirationMinutes": 60
  },
  "RateLimit": {
    "PermitLimit": 100,
    "Window": 60,
    "QueueLimit": 10
  },
  "VectorSettings": {
    "DefaultDimension": 1536,
    "MaxDimension": 4096,
    "MaxBatchSize": 1000
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

## 📊 Performance

Expected performance (with proper indexing):

| Operation | Throughput | Latency (p95) |
|-----------|-----------|---------------|
| Insert (single) | ~800 ops/sec | 3ms |
| Insert (batch 100) | ~8000 vectors/sec | 30ms |
| KNN Search (k=10) | ~1200 queries/sec | 8ms |
| KNN Search (k=100) | ~600 queries/sec | 15ms |

## 🔒 Security Features

- ✅ **JWT Authentication** - Industry-standard tokens
- ✅ **Rate Limiting** - Built-in ASP.NET Core rate limiting
- ✅ **CORS** - Configurable allowed origins
- ✅ **HTTPS** - TLS/SSL support
- ✅ **Input Validation** - FluentValidation
- ✅ **SQL Injection Protection** - Parameterized queries
- ✅ **API Key Support** - Optional API key middleware

## 🧪 Testing

```bash
# Run tests
cd Sfvector.Api.Tests
dotnet test

# Run with coverage
dotnet test /p:CollectCoverage=true

# Load testing with k6
k6 run examples/load-test.js
```

## 📁 Project Structure

```
api/
├── Sfvector.Api/                    # Main API project
│   ├── Controllers/
│   │   ├── AuthController.cs       # Authentication
│   │   ├── VectorsController.cs    # Vector CRUD
│   │   ├── SearchController.cs     # Search operations
│   │   └── IndexesController.cs    # Index management
│   ├── Services/
│   │   ├── IVectorService.cs
│   │   ├── VectorService.cs
│   │   ├── ISearchService.cs
│   │   ├── SearchService.cs
│   │   ├── IIndexService.cs
│   │   └── IndexService.cs
│   ├── Models/
│   │   ├── DTOs/
│   │   │   ├── VectorDto.cs
│   │   │   ├── SearchDto.cs
│   │   │   └── IndexDto.cs
│   │   └── Entities/
│   │       └── Vector.cs
│   ├── Middleware/
│   │   ├── ExceptionMiddleware.cs
│   │   └── RequestLoggingMiddleware.cs
│   ├── Data/
│   │   └── VectorDbContext.cs
│   ├── Extensions/
│   │   └── ServiceExtensions.cs
│   ├── Validators/
│   │   └── VectorValidator.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   ├── Program.cs
│   └── Sfvector.Api.csproj
├── Sfvector.Api.Tests/              # Unit tests
│   ├── Controllers/
│   ├── Services/
│   └── Sfvector.Api.Tests.csproj
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── examples/
│   ├── client-example.cs
│   ├── client-example.js
│   └── load-test.js
└── README.md
```

## 🚀 Getting Started

```bash
# 1. Create the project structure
cd api
dotnet new webapi -n Sfvector.Api
dotnet new xunit -n Sfvector.Api.Tests

# 2. Add packages
cd Sfvector.Api
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Swashbuckle.AspNetCore
dotnet add package FluentValidation.AspNetCore
dotnet add package Serilog.AspNetCore

# 3. Build and run
dotnet build
dotnet run
```

## 📝 License

Same PostgreSQL License as sfvector core. See [LICENSE](../LICENSE).

## 🔗 Links

- **Main Project**: [sfvector](../)
- **pgvector**: https://github.com/pgvector/pgvector
- **FAISS**: https://github.com/facebookresearch/faiss
- **ASP.NET Core**: https://docs.microsoft.com/aspnet/core
