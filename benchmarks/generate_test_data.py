#!/usr/bin/env python3
"""
sfvector - SQL Server Vector Search with FAISS
Copyright (c) 2026 sfvector contributors

"""


"""
Generate synthetic test data for vector search benchmarks
Creates datasets of various sizes with different characteristics
"""

import numpy as np
import argparse
import json
import os
from pathlib import Path
from typing import List, Tuple
import time


def generate_random_vectors(
    n_vectors: int,
    dimension: int,
    distribution: str = 'normal',
    seed: int = 42
) -> np.ndarray:
    """
    Generate random vectors with specified distribution
    
    Args:
        n_vectors: Number of vectors to generate
        dimension: Dimension of each vector
        distribution: 'normal', 'uniform', or 'clustered'
        seed: Random seed for reproducibility
    
    Returns:
        Array of shape (n_vectors, dimension)
    """
    np.random.seed(seed)
    
    if distribution == 'normal':
        # Standard normal distribution
        vectors = np.random.randn(n_vectors, dimension).astype(np.float32)
    
    elif distribution == 'uniform':
        # Uniform distribution [0, 1]
        vectors = np.random.rand(n_vectors, dimension).astype(np.float32)
    
    elif distribution == 'clustered':
        # Create clustered data (10 clusters)
        n_clusters = min(10, n_vectors // 100)
        vectors_per_cluster = n_vectors // n_clusters
        
        # Generate cluster centers
        centers = np.random.randn(n_clusters, dimension).astype(np.float32) * 5
        
        vectors = []
        for i in range(n_clusters):
            # Generate vectors around each center
            cluster_vectors = centers[i] + np.random.randn(
                vectors_per_cluster, dimension
            ).astype(np.float32) * 0.5
            vectors.append(cluster_vectors)
        
        # Handle remainder
        remainder = n_vectors - (vectors_per_cluster * n_clusters)
        if remainder > 0:
            extra = centers[0] + np.random.randn(remainder, dimension).astype(np.float32) * 0.5
            vectors.append(extra)
        
        vectors = np.vstack(vectors)
    
    else:
        raise ValueError(f"Unknown distribution: {distribution}")
    
    return vectors


def normalize_vectors(vectors: np.ndarray) -> np.ndarray:
    """Normalize vectors to unit length (L2 norm = 1)"""
    norms = np.linalg.norm(vectors, axis=1, keepdims=True)
    norms[norms == 0] = 1  # Avoid division by zero
    return vectors / norms


def save_vectors_csv(
    vectors: np.ndarray,
    output_path: Path,
    include_ids: bool = True
):
    """Save vectors to CSV format"""
    print(f"Saving {len(vectors)} vectors to {output_path}...")
    
    with open(output_path, 'w') as f:
        # Write header
        dim = vectors.shape[1]
        if include_ids:
            f.write('id,vector\n')
        else:
            f.write('vector\n')
        
        # Write vectors
        for i, vec in enumerate(vectors):
            vec_str = '[' + ','.join(map(str, vec)) + ']'
            if include_ids:
                f.write(f'{i+1},{vec_str}\n')
            else:
                f.write(f'{vec_str}\n')


def save_vectors_npy(vectors: np.ndarray, output_path: Path):
    """Save vectors to NumPy binary format"""
    print(f"Saving {len(vectors)} vectors to {output_path}...")
    np.save(output_path, vectors)


def save_vectors_json(vectors: np.ndarray, output_path: Path):
    """Save vectors to JSON format"""
    print(f"Saving {len(vectors)} vectors to {output_path}...")
    
    data = {
        'dimension': int(vectors.shape[1]),
        'count': int(vectors.shape[0]),
        'vectors': vectors.tolist()
    }
    
    with open(output_path, 'w') as f:
        json.dump(data, f)


def generate_query_vectors(
    base_vectors: np.ndarray,
    n_queries: int,
    strategy: str = 'random'
) -> np.ndarray:
    """
    Generate query vectors for benchmarking
    
    Args:
        base_vectors: Existing vectors to base queries on
        n_queries: Number of query vectors to generate
        strategy: 'random', 'from_data', or 'perturbed'
    
    Returns:
        Query vectors array
    """
    dimension = base_vectors.shape[1]
    
    if strategy == 'random':
        # Completely random queries
        queries = np.random.randn(n_queries, dimension).astype(np.float32)
    
    elif strategy == 'from_data':
        # Sample from existing data (simulates known items)
        indices = np.random.choice(len(base_vectors), n_queries, replace=False)
        queries = base_vectors[indices].copy()
    
    elif strategy == 'perturbed':
        # Take existing vectors and perturb them slightly
        indices = np.random.choice(len(base_vectors), n_queries, replace=False)
        queries = base_vectors[indices].copy()
        noise = np.random.randn(n_queries, dimension).astype(np.float32) * 0.1
        queries += noise
    
    else:
        raise ValueError(f"Unknown strategy: {strategy}")
    
    return queries


def generate_benchmark_dataset(
    output_dir: Path,
    dataset_name: str,
    n_vectors: int,
    dimension: int,
    n_queries: int = 100,
    distribution: str = 'normal',
    normalize: bool = True,
    formats: List[str] = ['csv', 'npy']
):
    """
    Generate a complete benchmark dataset
    
    Creates:
    - Training/database vectors
    - Query vectors
    - Metadata file
    """
    print(f"\n{'='*60}")
    print(f"Generating dataset: {dataset_name}")
    print(f"Vectors: {n_vectors:,}, Dimension: {dimension}, Queries: {n_queries}")
    print(f"Distribution: {distribution}, Normalize: {normalize}")
    print(f"{'='*60}\n")
    
    start_time = time.time()
    
    # Create dataset directory
    dataset_dir = output_dir / dataset_name
    dataset_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate base vectors
    print("Generating base vectors...")
    vectors = generate_random_vectors(n_vectors, dimension, distribution)
    
    if normalize:
        print("Normalizing vectors...")
        vectors = normalize_vectors(vectors)
    
    # Generate query vectors
    print("Generating query vectors...")
    queries_random = generate_query_vectors(vectors, n_queries, 'random')
    queries_perturbed = generate_query_vectors(vectors, n_queries, 'perturbed')
    
    if normalize:
        queries_random = normalize_vectors(queries_random)
        queries_perturbed = normalize_vectors(queries_perturbed)
    
    # Save in requested formats
    if 'csv' in formats:
        save_vectors_csv(vectors, dataset_dir / 'vectors.csv')
        save_vectors_csv(queries_random, dataset_dir / 'queries_random.csv', include_ids=False)
        save_vectors_csv(queries_perturbed, dataset_dir / 'queries_perturbed.csv', include_ids=False)
    
    if 'npy' in formats:
        save_vectors_npy(vectors, dataset_dir / 'vectors.npy')
        save_vectors_npy(queries_random, dataset_dir / 'queries_random.npy')
        save_vectors_npy(queries_perturbed, dataset_dir / 'queries_perturbed.npy')
    
    if 'json' in formats:
        save_vectors_json(vectors, dataset_dir / 'vectors.json')
    
    # Save metadata
    metadata = {
        'dataset_name': dataset_name,
        'n_vectors': int(n_vectors),
        'dimension': int(dimension),
        'n_queries': int(n_queries),
        'distribution': distribution,
        'normalized': normalize,
        'generation_time': time.time() - start_time,
        'vector_stats': {
            'mean': float(np.mean(vectors)),
            'std': float(np.std(vectors)),
            'min': float(np.min(vectors)),
            'max': float(np.max(vectors)),
        }
    }
    
    with open(dataset_dir / 'metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)
    
    elapsed = time.time() - start_time
    print(f"\n✓ Dataset generated in {elapsed:.2f}s")
    print(f"  Output: {dataset_dir}")
    print(f"  Size: {vectors.nbytes / 1024 / 1024:.2f} MB (base vectors)")
    
    return metadata


def main():
    parser = argparse.ArgumentParser(
        description='Generate test data for vector search benchmarks'
    )
    parser.add_argument(
        '--output-dir',
        type=Path,
        default=Path('data'),
        help='Output directory for datasets'
    )
    parser.add_argument(
        '--preset',
        choices=['quick', 'standard', 'extensive', 'all'],
        default='standard',
        help='Preset benchmark configuration'
    )
    parser.add_argument(
        '--formats',
        nargs='+',
        choices=['csv', 'npy', 'json'],
        default=['csv', 'npy'],
        help='Output formats'
    )
    
    args = parser.parse_args()
    
    # Define preset configurations
    presets = {
        'quick': [
            # Small datasets for quick testing
            ('small_1k_128d', 1_000, 128, 100),
            ('small_10k_384d', 10_000, 384, 100),
        ],
        'standard': [
            # Standard benchmarks (OpenAI ada-002 dimension)
            ('tiny_1k_1536d', 1_000, 1536, 100),
            ('small_10k_1536d', 10_000, 1536, 100),
            ('medium_100k_1536d', 100_000, 1536, 100),
            ('large_1m_1536d', 1_000_000, 1536, 100),
        ],
        'extensive': [
            # Comprehensive benchmarks with various dimensions
            ('tiny_1k_128d', 1_000, 128, 100),
            ('tiny_1k_384d', 1_000, 384, 100),
            ('tiny_1k_768d', 1_000, 768, 100),
            ('tiny_1k_1536d', 1_000, 1536, 100),
            
            ('small_10k_128d', 10_000, 128, 100),
            ('small_10k_384d', 10_000, 384, 100),
            ('small_10k_1536d', 10_000, 1536, 100),
            
            ('medium_100k_128d', 100_000, 128, 100),
            ('medium_100k_384d', 100_000, 384, 100),
            ('medium_100k_1536d', 100_000, 1536, 100),
            
            ('large_1m_384d', 1_000_000, 384, 100),
            ('large_1m_1536d', 1_000_000, 1536, 100),
        ]
    }
    
    if args.preset == 'all':
        configs = presets['extensive']
    else:
        configs = presets[args.preset]
    
    # Create output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate all datasets
    all_metadata = []
    total_start = time.time()
    
    for name, n_vectors, dimension, n_queries in configs:
        metadata = generate_benchmark_dataset(
            output_dir=args.output_dir,
            dataset_name=name,
            n_vectors=n_vectors,
            dimension=dimension,
            n_queries=n_queries,
            distribution='normal',
            normalize=True,
            formats=args.formats
        )
        all_metadata.append(metadata)
    
    # Save summary
    summary = {
        'preset': args.preset,
        'total_datasets': len(all_metadata),
        'total_time': time.time() - total_start,
        'datasets': all_metadata
    }
    
    with open(args.output_dir / 'summary.json', 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\n{'='*60}")
    print(f"All datasets generated!")
    print(f"Total time: {summary['total_time']:.2f}s")
    print(f"Output directory: {args.output_dir}")
    print(f"{'='*60}\n")


if __name__ == '__main__':
    main()
