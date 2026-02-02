/*
 * sfvector - SQL Server Vector Search with FAISS
 * Copyright (c) 2026 sfvector contributors
 * 
 */


-- =============================================
-- Example: Semantic Search with OpenAI Embeddings
-- =============================================
-- This example demonstrates how to use SQL Server Vector Search
-- for semantic similarity search using OpenAI ada-002 embeddings

USE VectorSearchDB;
GO

-- =============================================
-- 1. Create table with vector column
-- =============================================

IF OBJECT_ID('dbo.Documents', 'U') IS NOT NULL
    DROP TABLE dbo.Documents;
GO

CREATE TABLE dbo.Documents (
    id INT IDENTITY(1,1) PRIMARY KEY,
    title NVARCHAR(500),
    content NVARCHAR(MAX),
    -- Using VARBINARY to store vector until VectorType UDT is deployed
    -- In production, this would be: embedding VectorType
    embedding VARBINARY(8000), -- Temporary placeholder
    created_date DATETIME2 DEFAULT GETDATE(),
    INDEX IX_Documents_Id (id)
);
GO

-- =============================================
-- 2. Insert sample documents
-- =============================================
-- Note: In production, embeddings would come from OpenAI API
-- Here we show the structure with placeholder data

-- Example with VectorType (after deployment):
/*
INSERT INTO dbo.Documents (title, content, embedding)
VALUES 
    ('Machine Learning Basics', 
     'Machine learning is a subset of artificial intelligence...', 
     dbo.VectorType::Parse('[0.1, 0.2, 0.3, ...]')), -- 1536 dimensions for ada-002
    
    ('Neural Networks Guide',
     'Neural networks are computing systems inspired by biological neural networks...',
     dbo.VectorType::Parse('[0.15, 0.25, 0.28, ...]')),
    
    ('Database Indexing',
     'Database indexing is a data structure technique to efficiently retrieve records...',
     dbo.VectorType::Parse('[0.5, 0.1, 0.05, ...]'));
*/

-- =============================================
-- 3. Create FAISS index
-- =============================================

/*
-- Create HNSW index for fast approximate nearest neighbor search
EXEC dbo.sp_create_vector_index 
    @table_schema = 'dbo',
    @table_name = 'Documents',
    @column_name = 'embedding',
    @index_type = 'HNSW',
    @metric = 'COSINE',
    @index_options = N'{
        "M": 32,
        "efConstruction": 200,
        "efSearch": 100
    }';
GO
*/

-- =============================================
-- 4. Semantic search queries
-- =============================================

-- Example 1: Find similar documents using vector distance
/*
DECLARE @query_embedding VectorType;
SET @query_embedding = dbo.VectorType::Parse('[0.12, 0.22, 0.31, ...]'); -- Query vector

-- Top 5 most similar documents
SELECT TOP 5
    id,
    title,
    content,
    dbo.CosineDistance(embedding, @query_embedding) AS distance,
    1.0 - dbo.CosineDistance(embedding, @query_embedding) AS similarity_score
FROM dbo.Documents
ORDER BY dbo.CosineDistance(embedding, @query_embedding) ASC;
*/

-- Example 2: Using KNN search stored procedure (faster with FAISS index)
/*
EXEC dbo.sp_vector_search
    @table_schema = 'dbo',
    @table_name = 'Documents',
    @column_name = 'embedding',
    @query_vector = '[0.12, 0.22, 0.31, ...]',
    @k = 5,
    @metric = 'COSINE';
*/

-- Example 3: Hybrid search (keyword + semantic)
/*
DECLARE @query_text NVARCHAR(500) = 'machine learning algorithms';
DECLARE @query_embedding VectorType = dbo.VectorType::Parse('[0.12, 0.22, ...]');

SELECT TOP 10
    d.id,
    d.title,
    d.content,
    dbo.CosineDistance(d.embedding, @query_embedding) AS semantic_distance,
    -- Combine with full-text search score
    CASE 
        WHEN d.content LIKE '%' + @query_text + '%' THEN 0.5 
        ELSE 1.0 
    END AS keyword_penalty
FROM dbo.Documents d
ORDER BY 
    dbo.CosineDistance(d.embedding, @query_embedding) * keyword_penalty ASC;
*/

-- =============================================
-- 5. Batch operations
-- =============================================

-- Rebuild index after bulk inserts
/*
EXEC dbo.sp_rebuild_vector_index
    @table_schema = 'dbo',
    @table_name = 'Documents',
    @column_name = 'embedding';
*/

-- Check index statistics
/*
SELECT 
    index_id,
    table_schema,
    table_name,
    column_name,
    index_type,
    metric_type,
    dimension,
    ntotal AS vector_count,
    created_date,
    last_rebuilt,
    index_options
FROM dbo.sys_vector_indexes
WHERE table_name = 'Documents';
*/

-- =============================================
-- 6. Vector operations
-- =============================================

-- Calculate average embedding for a category
/*
DECLARE @category NVARCHAR(100) = 'AI/ML';

SELECT 
    @category AS category,
    dbo.VectorAverage(
        (SELECT embedding FROM Documents WHERE id = 1),
        (SELECT embedding FROM Documents WHERE id = 2)
    ) AS avg_embedding;
*/

-- Normalize vectors
/*
UPDATE Documents
SET embedding = dbo.VectorNormalize(embedding)
WHERE id = 1;
*/

-- Vector arithmetic (e.g., "king - man + woman = queen" analogy)
/*
DECLARE @king VectorType = (SELECT embedding FROM Documents WHERE title = 'King');
DECLARE @man VectorType = (SELECT embedding FROM Documents WHERE title = 'Man');
DECLARE @woman VectorType = (SELECT embedding FROM Documents WHERE title = 'Woman');

DECLARE @result VectorType = dbo.VectorAdd(
    dbo.VectorSubtract(@king, @man),
    @woman
);

-- Find closest match
SELECT TOP 1
    title,
    dbo.CosineDistance(embedding, @result) AS distance
FROM Documents
WHERE title NOT IN ('King', 'Man', 'Woman')
ORDER BY dbo.CosineDistance(embedding, @result) ASC;
*/

-- =============================================
-- 7. Performance comparison
-- =============================================

-- Compare FAISS index vs. sequential scan
/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

DECLARE @query VectorType = dbo.VectorType::Parse('[0.1, 0.2, ...]');

-- Sequential scan (slow for large datasets)
SELECT TOP 10 id, title,
    dbo.CosineSimilarity(embedding, @query) AS similarity
FROM Documents
ORDER BY dbo.CosineSimilarity(embedding, @query) DESC;

-- FAISS index search (fast)
EXEC dbo.sp_vector_search
    @table_schema = 'dbo',
    @table_name = 'Documents',
    @column_name = 'embedding',
    @query_vector = '[0.1, 0.2, ...]',
    @k = 10,
    @metric = 'COSINE';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
*/

-- =============================================
-- 8. Integration with application code
-- =============================================

-- C# Example:
/*
using System.Data.SqlClient;

class SemanticSearch
{
    static void Main()
    {
        string connStr = "Server=localhost;Database=VectorSearchDB;Integrated Security=true;";
        
        using (var conn = new SqlConnection(connStr))
        {
            conn.Open();
            
            // Get embedding from OpenAI (pseudo-code)
            float[] queryEmbedding = await OpenAI.GetEmbedding("What is machine learning?");
            string vectorStr = "[" + string.Join(",", queryEmbedding) + "]";
            
            // Search similar documents
            using (var cmd = new SqlCommand(@"
                SELECT TOP 5 id, title, content,
                    dbo.CosineDistance(embedding, dbo.VectorType::Parse(@query)) AS distance
                FROM Documents
                ORDER BY distance ASC", conn))
            {
                cmd.Parameters.AddWithValue("@query", vectorStr);
                
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        Console.WriteLine($"{reader["title"]}: {reader["distance"]}");
                    }
                }
            }
        }
    }
}
*/

-- Python Example:
/*
import pyodbc
import openai

def semantic_search(query_text, top_k=5):
    # Get embedding from OpenAI
    response = openai.Embedding.create(
        input=query_text,
        model="text-embedding-ada-002"
    )
    embedding = response['data'][0]['embedding']
    vector_str = '[' + ','.join(map(str, embedding)) + ']'
    
    # Connect to SQL Server
    conn = pyodbc.connect('DRIVER={SQL Server};SERVER=localhost;DATABASE=VectorSearchDB;Trusted_Connection=yes')
    cursor = conn.cursor()
    
    # Search
    cursor.execute(f"""
        SELECT TOP {top_k} id, title, content,
            dbo.CosineDistance(embedding, dbo.VectorType::Parse(?)) AS distance
        FROM Documents
        ORDER BY distance ASC
    """, vector_str)
    
    results = cursor.fetchall()
    for row in results:
        print(f"{row.title}: {row.distance}")
    
    conn.close()

semantic_search("What is machine learning?")
*/

PRINT 'Semantic search example ready!';
PRINT 'After deploying the CLR assembly, uncomment and run the examples above.';
GO
