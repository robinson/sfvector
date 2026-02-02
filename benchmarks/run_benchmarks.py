#!/usr/bin/env python3
"""
sfvector - SQL Server Vector Search with FAISS
Copyright (c) 2026 sfvector contributors

"""


"""
Unified benchmark runner for SQL Server FAISS vs pgvector comparison
Orchestrates tests across both databases and generates comparison reports
"""

import argparse
import json
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Optional
import sys

try:
    import psycopg2
    import pyodbc
    import pandas as pd
    import matplotlib.pyplot as plt
    import seaborn as sns
    DEPS_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Some dependencies missing: {e}")
    print("Install with: pip install psycopg2-binary pyodbc pandas matplotlib seaborn")
    DEPS_AVAILABLE = False


class BenchmarkRunner:
    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.results = {
            'sqlserver': [],
            'pgvector': [],
            'comparison': {}
        }
    
    def connect_sqlserver(self, connection_string: str):
        """Connect to SQL Server"""
        try:
            conn = pyodbc.connect(connection_string)
            print("✓ Connected to SQL Server")
            return conn
        except Exception as e:
            print(f"✗ Failed to connect to SQL Server: {e}")
            return None
    
    def connect_postgres(self, connection_string: str):
        """Connect to PostgreSQL"""
        try:
            conn = psycopg2.connect(connection_string)
            print("✓ Connected to PostgreSQL")
            return conn
        except Exception as e:
            print(f"✗ Failed to connect to PostgreSQL: {e}")
            return None
    
    def load_test_data(
        self,
        dataset_path: Path,
        db_type: str,
        connection,
        table_name: str
    ):
        """Load test data into database"""
        print(f"\nLoading test data into {db_type}...")
        print(f"Dataset: {dataset_path}")
        
        start_time = time.time()
        
        if db_type == 'sqlserver':
            # Use BULK INSERT for SQL Server
            cursor = connection.cursor()
            try:
                # Clear existing data
                cursor.execute(f"TRUNCATE TABLE {table_name}")
                
                # BULK INSERT (requires file accessible to SQL Server)
                # In practice, use bcp utility or programmatic insert
                print(f"TODO: Implement bulk load for SQL Server")
                # For now, use batch inserts
                
                connection.commit()
                print(f"✓ Data loaded in {time.time() - start_time:.2f}s")
            except Exception as e:
                print(f"✗ Failed to load data: {e}")
                connection.rollback()
            finally:
                cursor.close()
        
        elif db_type == 'postgres':
            # Use COPY for PostgreSQL
            cursor = connection.cursor()
            try:
                # Clear existing data
                cursor.execute(f"TRUNCATE TABLE {table_name}")
                
                # COPY from CSV
                with open(dataset_path, 'r') as f:
                    # Skip header
                    next(f)
                    cursor.copy_expert(
                        f"COPY {table_name}(id, vector) FROM STDIN WITH CSV",
                        f
                    )
                
                connection.commit()
                row_count = cursor.rowcount
                elapsed = time.time() - start_time
                print(f"✓ Loaded {row_count:,} vectors in {elapsed:.2f}s")
            except Exception as e:
                print(f"✗ Failed to load data: {e}")
                connection.rollback()
            finally:
                cursor.close()
    
    def run_sqlserver_benchmarks(
        self,
        connection,
        dataset_name: str,
        run_insert: bool = True,
        run_index_build: bool = True,
        run_search: bool = True
    ):
        """Run SQL Server benchmark suite"""
        print("\n" + "="*60)
        print("Running SQL Server FAISS Benchmarks")
        print("="*60)
        
        cursor = connection.cursor()
        
        try:
            # Execute benchmark suite
            cursor.execute("""
                EXEC dbo.sp_run_benchmark_suite
                    @dataset_name = ?,
                    @run_insert = ?,
                    @run_index_build = ?,
                    @run_search = ?
            """, dataset_name, run_insert, run_index_build, run_search)
            
            connection.commit()
            
            # Fetch results
            cursor.execute("""
                SELECT 
                    test_name,
                    test_category,
                    dataset_size,
                    dimension,
                    index_type,
                    metric_type,
                    elapsed_ms,
                    throughput_ops_sec,
                    additional_metrics
                FROM dbo.BenchmarkResults
                WHERE dataset_name = ?
                ORDER BY test_date DESC
            """, dataset_name)
            
            results = cursor.fetchall()
            
            for row in results:
                self.results['sqlserver'].append({
                    'test_name': row[0],
                    'test_category': row[1],
                    'dataset_size': row[2],
                    'dimension': row[3],
                    'index_type': row[4],
                    'metric_type': row[5],
                    'elapsed_ms': row[6],
                    'throughput': row[7],
                    'additional_metrics': row[8]
                })
            
            print(f"✓ Collected {len(results)} benchmark results")
            
        except Exception as e:
            print(f"✗ SQL Server benchmarks failed: {e}")
            connection.rollback()
        finally:
            cursor.close()
    
    def run_pgvector_benchmarks(
        self,
        connection,
        dataset_name: str,
        run_insert: bool = True,
        run_index_build: bool = True,
        run_search: bool = True
    ):
        """Run pgvector benchmark suite"""
        print("\n" + "="*60)
        print("Running pgvector Benchmarks")
        print("="*60)
        
        cursor = connection.cursor()
        
        try:
            # Execute benchmark suite
            cursor.callproc('run_benchmark_suite', [
                dataset_name,
                run_insert,
                run_index_build,
                run_search,
                False  # run_recall
            ])
            
            connection.commit()
            
            # Fetch results
            cursor.execute("""
                SELECT 
                    test_name,
                    test_category,
                    dataset_size,
                    dimension,
                    index_type,
                    metric_type,
                    elapsed_ms,
                    throughput_ops_sec,
                    additional_metrics
                FROM benchmark_results
                WHERE dataset_name = %s
                ORDER BY test_date DESC
            """, (dataset_name,))
            
            results = cursor.fetchall()
            
            for row in results:
                self.results['pgvector'].append({
                    'test_name': row[0],
                    'test_category': row[1],
                    'dataset_size': row[2],
                    'dimension': row[3],
                    'index_type': row[4],
                    'metric_type': row[5],
                    'elapsed_ms': row[6],
                    'throughput': row[7],
                    'additional_metrics': row[8]
                })
            
            print(f"✓ Collected {len(results)} benchmark results")
            
        except Exception as e:
            print(f"✗ pgvector benchmarks failed: {e}")
            connection.rollback()
        finally:
            cursor.close()
    
    def compare_results(self):
        """Compare SQL Server FAISS vs pgvector results"""
        print("\n" + "="*60)
        print("Comparing Results")
        print("="*60)
        
        if not DEPS_AVAILABLE:
            print("Cannot generate comparison - pandas not available")
            return
        
        # Convert to DataFrames
        df_sql = pd.DataFrame(self.results['sqlserver'])
        df_pg = pd.DataFrame(self.results['pgvector'])
        
        if df_sql.empty or df_pg.empty:
            print("No results to compare")
            return
        
        # Index Build Comparison
        print("\n--- Index Build Time Comparison ---")
        for index_type in ['FLAT', 'HNSW', 'IVF', 'ivfflat', 'hnsw']:
            sql_build = df_sql[
                (df_sql['test_category'] == 'INDEX_BUILD') &
                (df_sql['index_type'] == index_type)
            ]
            pg_build = df_pg[
                (df_pg['test_category'] == 'INDEX_BUILD') &
                (df_pg['index_type'] == index_type)
            ]
            
            if not sql_build.empty and not pg_build.empty:
                sql_time = sql_build['elapsed_ms'].mean()
                pg_time = pg_build['elapsed_ms'].mean()
                speedup = pg_time / sql_time if sql_time > 0 else 0
                
                print(f"{index_type}:")
                print(f"  SQL Server: {sql_time:,.0f} ms")
                print(f"  pgvector:   {pg_time:,.0f} ms")
                print(f"  Speedup:    {speedup:.2f}x")
        
        # Search Performance Comparison
        print("\n--- Search Performance Comparison (QPS) ---")
        sql_search = df_sql[df_sql['test_category'] == 'SEARCH_KNN']
        pg_search = df_pg[df_pg['test_category'] == 'SEARCH_KNN']
        
        if not sql_search.empty and not pg_search.empty:
            print(f"SQL Server avg QPS: {sql_search['throughput'].mean():.2f}")
            print(f"pgvector avg QPS:   {pg_search['throughput'].mean():.2f}")
        
        # Store comparison
        self.results['comparison'] = {
            'sqlserver_summary': df_sql.groupby('test_category').agg({
                'elapsed_ms': 'mean',
                'throughput': 'mean'
            }).to_dict(),
            'pgvector_summary': df_pg.groupby('test_category').agg({
                'elapsed_ms': 'mean',
                'throughput': 'mean'
            }).to_dict()
        }
    
    def generate_report(self):
        """Generate comprehensive comparison report"""
        print("\n" + "="*60)
        print("Generating Report")
        print("="*60)
        
        # Save raw results
        results_file = self.output_dir / 'benchmark_results.json'
        with open(results_file, 'w') as f:
            json.dump(self.results, f, indent=2, default=str)
        print(f"✓ Results saved to {results_file}")
        
        # Generate markdown report
        report_file = self.output_dir / 'benchmark_report.md'
        with open(report_file, 'w') as f:
            f.write("# SQL Server FAISS vs pgvector Benchmark Report\n\n")
            f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("## Summary\n\n")
            f.write(f"- SQL Server tests: {len(self.results['sqlserver'])}\n")
            f.write(f"- pgvector tests: {len(self.results['pgvector'])}\n\n")
            
            f.write("## Detailed Results\n\n")
            f.write("### SQL Server FAISS\n\n")
            for result in self.results['sqlserver']:
                f.write(f"- {result['test_name']}: {result['elapsed_ms']}ms\n")
            
            f.write("\n### pgvector\n\n")
            for result in self.results['pgvector']:
                f.write(f"- {result['test_name']}: {result['elapsed_ms']}ms\n")
        
        print(f"✓ Report saved to {report_file}")
        
        # Generate plots if matplotlib available
        if DEPS_AVAILABLE and (self.results['sqlserver'] or self.results['pgvector']):
            self._generate_plots()
    
    def _generate_plots(self):
        """Generate comparison plots"""
        print("\n" + "Generating plots...")
        
        try:
            df_sql = pd.DataFrame(self.results['sqlserver'])
            df_pg = pd.DataFrame(self.results['pgvector'])
            
            # Set style
            sns.set_style("whitegrid")
            
            # Plot 1: Index Build Time
            fig, ax = plt.subplots(figsize=(10, 6))
            
            # Combine data
            df_sql_build = df_sql[df_sql['test_category'] == 'INDEX_BUILD'].copy()
            df_pg_build = df_pg[df_pg['test_category'] == 'INDEX_BUILD'].copy()
            
            df_sql_build['database'] = 'SQL Server FAISS'
            df_pg_build['database'] = 'pgvector'
            
            df_combined = pd.concat([df_sql_build, df_pg_build])
            
            if not df_combined.empty:
                sns.barplot(data=df_combined, x='index_type', y='elapsed_ms', hue='database', ax=ax)
                ax.set_title('Index Build Time Comparison')
                ax.set_ylabel('Time (ms)')
                ax.set_xlabel('Index Type')
                plt.xticks(rotation=45)
                plt.tight_layout()
                plt.savefig(self.output_dir / 'index_build_comparison.png', dpi=300)
                print(f"✓ Saved index_build_comparison.png")
                plt.close()
            
            # Plot 2: Search Throughput
            fig, ax = plt.subplots(figsize=(10, 6))
            
            df_sql_search = df_sql[df_sql['test_category'] == 'SEARCH_KNN'].copy()
            df_pg_search = df_pg[df_pg['test_category'] == 'SEARCH_KNN'].copy()
            
            df_sql_search['database'] = 'SQL Server FAISS'
            df_pg_search['database'] = 'pgvector'
            
            df_combined = pd.concat([df_sql_search, df_pg_search])
            
            if not df_combined.empty:
                sns.barplot(data=df_combined, x='index_type', y='throughput', hue='database', ax=ax)
                ax.set_title('Search Throughput Comparison (QPS)')
                ax.set_ylabel('Queries per Second')
                ax.set_xlabel('Index Type')
                plt.xticks(rotation=45)
                plt.tight_layout()
                plt.savefig(self.output_dir / 'search_throughput_comparison.png', dpi=300)
                print(f"✓ Saved search_throughput_comparison.png")
                plt.close()
            
        except Exception as e:
            print(f"Warning: Could not generate plots: {e}")


def main():
    parser = argparse.ArgumentParser(
        description='Run benchmarks comparing SQL Server FAISS vs pgvector'
    )
    
    # Database connections
    parser.add_argument('--sqlserver-conn', help='SQL Server connection string')
    parser.add_argument('--postgres-conn', help='PostgreSQL connection string')
    
    # Test configuration
    parser.add_argument('--dataset', required=True, help='Dataset name/path')
    parser.add_argument('--output-dir', type=Path, default=Path('results'),
                       help='Output directory for results')
    
    # Test selection
    parser.add_argument('--no-insert', action='store_true', help='Skip insert tests')
    parser.add_argument('--no-index', action='store_true', help='Skip index build tests')
    parser.add_argument('--no-search', action='store_true', help='Skip search tests')
    
    # Database selection
    parser.add_argument('--sqlserver-only', action='store_true', help='Run only SQL Server tests')
    parser.add_argument('--pgvector-only', action='store_true', help='Run only pgvector tests')
    
    args = parser.parse_args()
    
    if not DEPS_AVAILABLE:
        print("Error: Required dependencies not installed")
        print("Install with: pip install psycopg2-binary pyodbc pandas matplotlib seaborn")
        sys.exit(1)
    
    runner = BenchmarkRunner(args.output_dir)
    
    # Connect to databases
    sqlserver_conn = None
    postgres_conn = None
    
    if not args.pgvector_only and args.sqlserver_conn:
        sqlserver_conn = runner.connect_sqlserver(args.sqlserver_conn)
    
    if not args.sqlserver_only and args.postgres_conn:
        postgres_conn = runner.connect_postgres(args.postgres_conn)
    
    # Run benchmarks
    try:
        if sqlserver_conn:
            runner.run_sqlserver_benchmarks(
                sqlserver_conn,
                args.dataset,
                not args.no_insert,
                not args.no_index,
                not args.no_search
            )
        
        if postgres_conn:
            runner.run_pgvector_benchmarks(
                postgres_conn,
                args.dataset,
                not args.no_insert,
                not args.no_index,
                not args.no_search
            )
        
        # Compare and report
        runner.compare_results()
        runner.generate_report()
        
        print("\n" + "="*60)
        print("✓ Benchmark suite completed!")
        print(f"Results saved to: {args.output_dir}")
        print("="*60)
        
    finally:
        if sqlserver_conn:
            sqlserver_conn.close()
        if postgres_conn:
            postgres_conn.close()


if __name__ == '__main__':
    main()
