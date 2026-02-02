#!/bin/bash
#
# sfvector - SQL Server Vector Search with FAISS
# Copyright (c) 2026 sfvector contributors
#
#


# sfvector REST API - Example curl commands

API_URL="http://localhost:5000"
TOKEN=""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== sfvector REST API Examples ===${NC}\n"

# 1. Login
echo -e "${GREEN}1. Login${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "${API_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "password"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "Login failed!"
    exit 1
fi

echo "✓ Logged in successfully"
echo "Token: ${TOKEN:0:50}..."
echo ""

# 2. Health Check
echo -e "${GREEN}2. Health Check${NC}"
curl -s "${API_URL}/health" | jq '.'
echo ""

# 3. Insert a vector
echo -e "${GREEN}3. Insert Vector${NC}"
curl -s -X POST "${API_URL}/api/vectors" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "doc123",
    "vector": [0.1, 0.2, 0.3, 0.4, 0.5],
    "metadata": {
      "title": "Sample Document",
      "category": "technology"
    }
  }' | jq '.'
echo ""

# 4. Batch insert
echo -e "${GREEN}4. Batch Insert${NC}"
curl -s -X POST "${API_URL}/api/vectors/batch" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": [
      {
        "id": "doc456",
        "vector": [0.2, 0.3, 0.4, 0.5, 0.6],
        "metadata": {"title": "Document 2"}
      },
      {
        "id": "doc789",
        "vector": [0.3, 0.4, 0.5, 0.6, 0.7],
        "metadata": {"title": "Document 3"}
      }
    ]
  }' | jq '.'
echo ""

# 5. Get a vector
echo -e "${GREEN}5. Get Vector${NC}"
curl -s -X GET "${API_URL}/api/vectors/doc123" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 6. List vectors
echo -e "${GREEN}6. List Vectors (Paginated)${NC}"
curl -s -X GET "${API_URL}/api/vectors?page=1&pageSize=10" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 7. KNN Search
echo -e "${GREEN}7. KNN Search${NC}"
curl -s -X POST "${API_URL}/api/search/knn" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.15, 0.25, 0.35, 0.45, 0.55],
    "k": 5,
    "metric": "cosine"
  }' | jq '.'
echo ""

# 8. Range Search
echo -e "${GREEN}8. Range Search${NC}"
curl -s -X POST "${API_URL}/api/search/range" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.15, 0.25, 0.35, 0.45, 0.55],
    "radius": 0.5,
    "metric": "l2",
    "maxResults": 10
  }' | jq '.'
echo ""

# 9. Hybrid Search (with filters)
echo -e "${GREEN}9. Hybrid Search${NC}"
curl -s -X POST "${API_URL}/api/search/hybrid" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.15, 0.25, 0.35, 0.45, 0.55],
    "k": 5,
    "metric": "cosine",
    "filter": {
      "category": "technology"
    }
  }' | jq '.'
echo ""

# 10. Create Index
echo -e "${GREEN}10. Create Index${NC}"
curl -s -X POST "${API_URL}/api/indexes" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "vectors_hnsw",
    "table": "VectorsTest_FAISS",
    "column": "vector",
    "indexType": "hnsw",
    "metric": "cosine",
    "parameters": {
      "M": 32,
      "efConstruction": 200
    }
  }' | jq '.'
echo ""

# 11. List Indexes
echo -e "${GREEN}11. List Indexes${NC}"
curl -s -X GET "${API_URL}/api/indexes" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 12. Get Index Stats
echo -e "${GREEN}12. Get Index Stats${NC}"
curl -s -X GET "${API_URL}/api/indexes/vectors_hnsw/stats" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 13. Update Vector
echo -e "${GREEN}13. Update Vector${NC}"
curl -s -X PUT "${API_URL}/api/vectors/doc123" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.11, 0.21, 0.31, 0.41, 0.51],
    "metadata": {
      "title": "Updated Sample Document",
      "category": "technology",
      "updated": true
    }
  }' | jq '.'
echo ""

# 14. Get Vector Count
echo -e "${GREEN}14. Get Vector Count${NC}"
curl -s -X GET "${API_URL}/api/vectors/count" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 15. Validate Token
echo -e "${GREEN}15. Validate Token${NC}"
curl -s -X GET "${API_URL}/api/auth/validate" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 16. Delete Vector
echo -e "${GREEN}16. Delete Vector${NC}"
curl -s -X DELETE "${API_URL}/api/vectors/doc789" \
  -H "Authorization: Bearer ${TOKEN}"
echo "✓ Vector deleted"
echo ""

# 17. Rebuild Index
echo -e "${GREEN}17. Rebuild Index${NC}"
curl -s -X POST "${API_URL}/api/indexes/vectors_hnsw/rebuild" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 18. Error Handling Example
echo -e "${GREEN}18. Error Handling (Get non-existent vector)${NC}"
curl -s -X GET "${API_URL}/api/vectors/nonexistent" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.'
echo ""

# 19. Unauthorized Request Example
echo -e "${GREEN}19. Unauthorized Request (no token)${NC}"
curl -s -X GET "${API_URL}/api/vectors/doc123" | jq '.'
echo ""

echo -e "${BLUE}=== All examples completed ===${NC}"
