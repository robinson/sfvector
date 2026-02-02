// JavaScript/TypeScript client example for sfvector API

class SfvectorClient {
    constructor(baseUrl) {
        this.baseUrl = baseUrl;
        this.token = null;
    }

    /**
     * Login and get JWT token
     */
    async login(username, password) {
        const response = await fetch(`${this.baseUrl}/api/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });

        if (!response.ok) {
            throw new Error('Login failed');
        }

        const data = await response.json();
        this.token = data.token;
        return data;
    }

    /**
     * Get authorization headers
     */
    getHeaders() {
        return {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.token}`
        };
    }

    /**
     * Insert a vector
     */
    async insertVector(id, vector, metadata = null) {
        const response = await fetch(`${this.baseUrl}/api/vectors`, {
            method: 'POST',
            headers: this.getHeaders(),
            body: JSON.stringify({ id, vector, metadata })
        });

        if (!response.ok) {
            throw new Error(`Insert failed: ${response.statusText}`);
        }

        return await response.json();
    }

    /**
     * Batch insert vectors
     */
    async batchInsert(vectors) {
        const response = await fetch(`${this.baseUrl}/api/vectors/batch`, {
            method: 'POST',
            headers: this.getHeaders(),
            body: JSON.stringify({ vectors })
        });

        if (!response.ok) {
            throw new Error(`Batch insert failed: ${response.statusText}`);
        }

        return await response.json();
    }

    /**
     * Search for similar vectors (KNN)
     */
    async search(queryVector, k = 10, metric = 'cosine') {
        const response = await fetch(`${this.baseUrl}/api/search/knn`, {
            method: 'POST',
            headers: this.getHeaders(),
            body: JSON.stringify({ vector: queryVector, k, metric })
        });

        if (!response.ok) {
            throw new Error(`Search failed: ${response.statusText}`);
        }

        return await response.json();
    }

    /**
     * Get vector by ID
     */
    async getVector(id) {
        const response = await fetch(`${this.baseUrl}/api/vectors/${id}`, {
            method: 'GET',
            headers: this.getHeaders()
        });

        if (!response.ok) {
            if (response.status === 404) return null;
            throw new Error(`Get vector failed: ${response.statusText}`);
        }

        return await response.json();
    }

    /**
     * Delete a vector
     */
    async deleteVector(id) {
        const response = await fetch(`${this.baseUrl}/api/vectors/${id}`, {
            method: 'DELETE',
            headers: this.getHeaders()
        });

        return response.ok;
    }

    /**
     * List vectors with pagination
     */
    async listVectors(page = 1, pageSize = 50) {
        const response = await fetch(
            `${this.baseUrl}/api/vectors?page=${page}&pageSize=${pageSize}`,
            {
                method: 'GET',
                headers: this.getHeaders()
            }
        );

        if (!response.ok) {
            throw new Error(`List vectors failed: ${response.statusText}`);
        }

        return await response.json();
    }

    /**
     * Create an index
     */
    async createIndex(name, table, column, indexType = 'hnsw', metric = 'cosine', parameters = null) {
        const response = await fetch(`${this.baseUrl}/api/indexes`, {
            method: 'POST',
            headers: this.getHeaders(),
            body: JSON.stringify({ name, table, column, indexType, metric, parameters })
        });

        if (!response.ok) {
            throw new Error(`Create index failed: ${response.statusText}`);
        }

        return await response.json();
    }

    /**
     * List all indexes
     */
    async listIndexes() {
        const response = await fetch(`${this.baseUrl}/api/indexes`, {
            method: 'GET',
            headers: this.getHeaders()
        });

        if (!response.ok) {
            throw new Error(`List indexes failed: ${response.statusText}`);
        }

        return await response.json();
    }

    /**
     * Get index statistics
     */
    async getIndexStats(name) {
        const response = await fetch(`${this.baseUrl}/api/indexes/${name}/stats`, {
            method: 'GET',
            headers: this.getHeaders()
        });

        if (!response.ok) {
            if (response.status === 404) return null;
            throw new Error(`Get index stats failed: ${response.statusText}`);
        }

        return await response.json();
    }
}

// Example usage
async function main() {
    const client = new SfvectorClient('http://localhost:5000');

    try {
        // Login
        console.log('Logging in...');
        await client.login('admin', 'password');
        console.log('✓ Logged in successfully');

        // Helper function to generate random vectors
        const generateVector = (dim) => 
            Array(dim).fill(0).map(() => Math.random());

        // Insert vectors
        console.log('\nInserting vectors...');
        await client.insertVector('doc1', generateVector(1536), {
            title: 'Introduction to Machine Learning',
            category: 'AI'
        });
        await client.insertVector('doc2', generateVector(1536), {
            title: 'Deep Learning Fundamentals',
            category: 'AI'
        });
        console.log('✓ Inserted 2 vectors');

        // Batch insert
        console.log('\nBatch inserting vectors...');
        const batchVectors = Array.from({ length: 10 }, (_, i) => ({
            id: `doc${i + 3}`,
            vector: generateVector(1536),
            metadata: {
                title: `Document ${i + 3}`,
                category: 'General'
            }
        }));

        const batchResult = await client.batchInsert(batchVectors);
        console.log(`✓ Batch inserted ${batchResult.inserted} vectors`);

        // Search
        console.log('\nSearching for similar vectors...');
        const queryVector = generateVector(1536);
        const searchResult = await client.search(queryVector, 5, 'cosine');

        console.log(`Found ${searchResult.totalResults} similar vectors (${searchResult.queryTimeMs.toFixed(2)}ms):`);
        searchResult.results.forEach(result => {
            console.log(`  - ${result.id}: similarity=${result.similarity.toFixed(3)}, distance=${result.distance.toFixed(3)}`);
        });

        // Get specific vector
        console.log('\nRetrieving vector "doc1"...');
        const vector = await client.getVector('doc1');
        if (vector) {
            console.log(`✓ Retrieved vector: ${vector.id}`);
            console.log(`  Dimension: ${vector.vector.length}`);
            console.log(`  Metadata:`, vector.metadata);
        }

        // List vectors
        console.log('\nListing first page of vectors...');
        const vectorList = await client.listVectors(1, 10);
        console.log(`Total vectors: ${vectorList.total}, Page: ${vectorList.page}/${vectorList.totalPages}`);
        vectorList.vectors.forEach(v => {
            console.log(`  - ${v.id}`);
        });

        // Create index
        console.log('\nCreating HNSW index...');
        const indexResult = await client.createIndex(
            'vectors_hnsw',
            'VectorsTest_FAISS',
            'vector',
            'hnsw',
            'cosine',
            { M: 32, efConstruction: 200 }
        );
        console.log('✓ Index created:', indexResult.name);

        // List indexes
        console.log('\nListing indexes...');
        const indexes = await client.listIndexes();
        console.log(`Found ${indexes.indexes.length} indexes:`);
        indexes.indexes.forEach(index => {
            console.log(`  - ${index.name}: ${index.type} (${index.vectorCount} vectors)`);
        });

        console.log('\n✓ All operations completed successfully!');

    } catch (error) {
        console.error('Error:', error.message);
    }
}

// Run in Node.js
if (typeof module !== 'undefined' && module.exports) {
    // For Node.js, you'll need to install 'node-fetch':
    // npm install node-fetch
    const fetch = require('node-fetch');
    main();
}

// Export for browser use
if (typeof window !== 'undefined') {
    window.SfvectorClient = SfvectorClient;
}
