#!/usr/bin/env python3
"""
sfvector - SQL Server Vector Search with FAISS
Copyright 2026 sfvector contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

"""
Run benchmarks comparing SQL Server 2025 native vectors, sfvector (FAISS), and pgvector
Extended from run_benchmarks.py to support SQL Server 2025
"""

import argparse
import json
import time
from pathlib import Path
from typing import Dict, List
import sys

try:
    import pyodbc
    import psycopg2
    import pandas as pd
    import matplotlib.pyplot as plt
    import seaborn as sns
    DEPS_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Some dependencies missing: {e}")
    print("Install with: pip install psycopg2-binary pyodbc pandas matplotlib seaborn")
    DEPS_AVAILABLE = False


class SQL2025BenchmarkRunner:
    """Extended benchmark runner supporting SQL Server 2025 native vectors"""
    
    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.results = {
            'sql2025_native': [],
            'sfvector_faiss': [],
            'pgvector': [],
            'comparison': {}
        }
    
    def connect_sqlserver(self, connection_string: str):
        """Connect to SQL Server (2025 or earlier)"""
        try:
            conn = pyodbc.connect(connection_string)
            cursor = conn.cursor()
            # Check SQL Server version
            cursor.execute("SELECT @@VERSION")
            version = cursor.fetchone()[0]
            print(f"✓ Connected to SQL Server")
            print(f"  Version: {version[:80]}...")
            
            # Check if SQL Server 2025 with native vector support
            if '2025' in version or 'Vector' in version:
                print("  ✓ SQL Server 2025 detected - native vector support available")
                self.has_native_vectors = True
            else:
                print("  ℹ SQL Server < 2025 - using sfvector (FAISS) only")
                self.has_native_vectors = False
            
            cursor.close()
            return conn
        except Exception as e:
            print(f"✗ Failed to connect to SQL Server: {e}")
            return None
    
    def connect_postgres(self, connection_string: str):
        """Connect to PostgreSQL with pgvector"""
        try:
            conn = psycopg2.connect(connection_string)
            cursor = conn.cursor()
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            print(f"✓ Connected to PostgreSQL")
            print(f"  Version: {version[:80]}...")
            cursor.close()
            return conn
        except Exception as e:
            print(f"✗ Failed to connect to PostgreSQL: {e}")
            return None
    
    def run_sql2025_benchmarks(
        self,
        connection,
        dataset_name: str,
        dataset_size: int = 10000,
        dimension: int = 1536,
        run_insert: bool = True,
        run_index: bool = True,
        run_search: bool = True
    ):
        """Run SQL Server 2025 native vector benchmarks"""
        if not self.has_native_vectors:
            print("\n⚠ Skipping SQL Server 2025 native benchmarks - not supported on this version")
            return
        
        print("\n" + "="*60)
        print("Running SQL Server 2025 Native Vector Benchmarks")
        print("="*60)
        
        cursor = connection.cursor()
        
        try:
            # Execute benchmark suite for SQL Server 2025
            cursor.execute("""
                EXEC dbo.sp_run_benchmark_suite_2025
                    @dataset_name = ?,
                    @dataset_size = ?,
                    @dimension = ?,
                    @run_insert = ?,
                    @run_index_build = ?,
                    @run_search = ?
            """, dataset_name, dataset_size, dimension, 
                 run_insert, run_index, run_search)
            
            connection.commit()
            
            # Fetch SQL Server 2025 native results
            cursor.execute("""
                SELECT 
                    test_name,
                    test_category,
                    implementation,
                    dataset_size,
                    dimension,
                    index_type,
                    metric_type,
                    elapsed_ms,
                    throughput_ops_sec,
                    additional_metrics
                FROM dbo.BenchmarkResults_2025
                WHERE implementation = 'SQL2025_NATIVE'
                  AND dataset_name = ?
                ORDER BY test_date DESC
            """, dataset_name)
            
            results = cursor.fetchall()
            
            for row in results:
                self.results['sql2025_native'].append({
                    'test_name': row[0],
                    'test_category': row[1],
                    'implementation': row[2],
                    'dataset_size': row[3],
                    'dimension': row[4],
                    'index_type': row[5],
                    'metric_type': row[6],
                    'elapsed_ms': row[7],
                    'throughput': row[8],
                    'additional_metrics': row[9]
                })
            
            print(f"✓ Collected {len(results)} SQL Server 2025 benchmark results")
            
            # Also fetch sfvector results from same benchmark run
            cursor.execute("""
                SELECT 
                    test_name, test_category, implementation, dataset_size, dimension,
                    index_type, metric_type, elapsed_ms, throughput_ops_sec, additional_metrics
                FROM dbo.BenchmarkResults_2025
                WHERE implementation = 'SFVECTOR_FAISS'
                  AND dataset_name = ?
                ORDER BY test_date DESC
            """, dataset_name)
            
            sfvector_results = cursor.fetchall()
            
            for row in sfvector_results:
                self.results['sfvector_faiss'].append({
                    'test_name': row[0],
                    'test_category': row[1],
                    'implementation': row[2],
                    'dataset_size': row[3],
                    'dimension': row[4],
                    'index_type': row[5],
                    'metric_type': row[6],
                    'elapsed_ms': row[7],
                    'throughput': row[8],
                    'additional_metrics': row[9]
                })
            
            print(f"✓ Collected {len(sfvector_results)} sfvector benchmark results")
            
        except Exception as e:
            print(f"✗ SQL Server 2025 benchmarks failed: {e}")
            import traceback
            traceback.print_exc()
            connection.rollback()
        finally:
            cursor.close()
    
    def run_pgvector_benchmarks(
        self,
        connection,
        dataset_name: str,
        run_insert: bool = True,
        run_index: bool = True,
        run_search: bool = True
    ):
        """Run pgvector benchmarks (from existing benchmark suite)"""
        print("\n" + "="*60)
        print("Running pgvector Benchmarks")
        print("="*60)
        
        cursor = connection.cursor()
        
        try:
            # Execute pgvector benchmark suite
            cursor.callproc('run_benchmark_suite', [
                dataset_name,
                run_insert,
                run_index,
                run_search,
                False  # run_recall
            ])
            
            connection.commit()
            
            # Fetch results
            cursor.execute("""
                SELECT 
                    test_name, test_category, dataset_size, dimension,
                    index_type, metric_type, elapsed_ms, throughput_ops_sec,
                    additional_metrics
                FROM benchmark_results
                WHERE dataset_name = %s
                ORDER BY test_date DESC
                LIMIT 100
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
            
            print(f"✓ Collected {len(results)} pgvector benchmark results")
            
        except Exception as e:
            print(f"✗ pgvector benchmarks failed: {e}")
            connection.rollback()
        finally:
            cursor.close()
    
    def compare_all_implementations(self):
        """Compare SQL Server 2025, sfvector, and pgvector"""
        print("\n" + "="*60)
        print("Three-Way Comparison: SQL2025 vs sfvector vs pgvector")
        print("="*60)
        
        if not DEPS_AVAILABLE:
            print("Cannot generate comparison - pandas not available")
            return
        
        df_sql2025 = pd.DataFrame(self.results['sql2025_native'])
        df_sfvector = pd.DataFrame(self.results['sfvector_faiss'])
        df_pg = pd.DataFrame(self.results['pgvector'])
        
        print(f"\nResults collected:")
        print(f"  SQL Server 2025 Native: {len(df_sql2025)} tests")
        print(f"  sfvector (FAISS):       {len(df_sfvector)} tests")
        print(f"  pgvector:               {len(df_pg)} tests")
        
        if df_sql2025.empty and df_sfvector.empty and df_pg.empty:
            print("No results to compare")
            return
        
        # Index Build Comparison
        print("\n--- Index Build Time Comparison ---")
        print(f"{'Implementation':<25} {'Index Type':<15} {'Time (ms)':<12} {'Relative':<10}")
        print("-" * 70)
        
        for impl_name, df, prefix in [
            ('SQL Server 2025', df_sql2025, 'SQL2025'),
            ('sfvector FAISS', df_sfvector, 'sfvector'),
            ('pgvector', df_pg, 'pgvector')
        ]:
            if not df.empty:
                build_results = df[df['test_category'] == 'INDEX_BUILD']
                if not build_results.empty:
                    for _, row in build_results.iterrows():
                        idx_type = row.get('index_type', 'N/A')
                        elapsed = row.get('elapsed_ms', 0)
                        print(f"{impl_name:<25} {idx_type:<15} {elapsed:<12.0f}")
        
        # Search Performance Comparison
        print("\n--- Search Performance (QPS) ---")
        print(f"{'Implementation':<25} {'QPS':<12} {'Relative':<10}")
        print("-" * 50)
        
        sql2025_qps = df_sql2025[df_sql2025['test_category'] == 'SEARCH_KNN']['throughput'].mean() if not df_sql2025.empty else 0
        sfvector_qps = df_sfvector[df_sfvector['test_category'] == 'SEARCH_KNN']['throughput'].mean() if not df_sfvector.empty else 0
        pg_qps = df_pg[df_pg['test_category'] == 'SEARCH_KNN']['throughput'].mean() if not df_pg.empty else 0
        
        baseline = max(sql2025_qps, sfvector_qps, pg_qps) or 1
        
        if sql2025_qps > 0:
            print(f"{'SQL Server 2025':<25} {sql2025_qps:<12.2f} {(sql2025_qps/baseline)*100:<10.1f}%")
        if sfvector_qps > 0:
            print(f"{'sfvector FAISS':<25} {sfvector_qps:<12.2f} {(sfvector_qps/baseline)*100:<10.1f}%")
        if pg_qps > 0:
            print(f"{'pgvector':<25} {pg_qps:<12.2f} {(pg_qps/baseline)*100:<10.1f}%")
        
        # Determine winner
        print("\n--- Overall Performance Summary ---")
        if sql2025_qps > sfvector_qps and sql2025_qps > pg_qps:
            print("🏆 Winner: SQL Server 2025 Native Vectors")
        elif sfvector_qps > sql2025_qps and sfvector_qps > pg_qps:
            print("🏆 Winner: sfvector (FAISS)")
        elif pg_qps > sql2025_qps and pg_qps > sfvector_qps:
            print("🏆 Winner: pgvector")
        else:
            print("🤝 Performance is comparable across implementations")
    
    def generate_comparison_report(self):
        """Generate comprehensive three-way comparison report"""
        print("\n" + "="*60)
        print("Generating Comparison Report")
        print("="*60)
        
        # Save raw results
        results_file = self.output_dir / 'benchmark_results_sql2025_comparison.json'
        with open(results_file, 'w') as f:
            json.dump(self.results, f, indent=2, default=str)
        print(f"✓ Results saved to {results_file}")
        
        # Generate markdown report
        report_file = self.output_dir / 'sql2025_comparison_report.md'
        with open(report_file, 'w') as f:
            f.write("# SQL Server 2025 vs sfvector vs pgvector Comparison\n\n")
            f.write(f"**Generated**: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("## Summary\n\n")
            f.write(f"- SQL Server 2025 Native: {len(self.results['sql2025_native'])} tests\n")
            f.write(f"- sfvector (FAISS): {len(self.results['sfvector_faiss'])} tests\n")
            f.write(f"- pgvector: {len(self.results['pgvector'])} tests\n\n")
            
            # Performance tables
            if DEPS_AVAILABLE:
                df_sql2025 = pd.DataFrame(self.results['sql2025_native'])
                df_sfvector = pd.DataFrame(self.results['sfvector_faiss'])
                df_pg = pd.DataFrame(self.results['pgvector'])
                
                f.write("## Performance Comparison\n\n")
                f.write("### Search QPS (Higher is Better)\n\n")
                f.write("| Implementation | Average QPS | Relative |\n")
                f.write("|----------------|-------------|----------|\n")
                
                for name, df in [
                    ('SQL Server 2025', df_sql2025),
                    ('sfvector FAISS', df_sfvector),
                    ('pgvector', df_pg)
                ]:
                    if not df.empty:
                        qps = df[df['test_category'] == 'SEARCH_KNN']['throughput'].mean()
                        if pd.notna(qps):
                            f.write(f"| {name} | {qps:.2f} | 100% |\n")
                
                f.write("\n")
        
        print(f"✓ Report saved to {report_file}")
        
        # Generate comparison charts
        if DEPS_AVAILABLE and (self.results['sql2025_native'] or 
                               self.results['sfvector_faiss'] or 
                               self.results['pgvector']):
            self._generate_comparison_charts()
    
    def _generate_comparison_charts(self):
        """Generate three-way comparison charts"""
        print("\nGenerating comparison charts...")
        
        try:
            df_sql2025 = pd.DataFrame(self.results['sql2025_native'])
            df_sfvector = pd.DataFrame(self.results['sfvector_faiss'])
            df_pg = pd.DataFrame(self.results['pgvector'])
            
            # Combine all data
            if not df_sql2025.empty:
                df_sql2025['database'] = 'SQL Server 2025'
            if not df_sfvector.empty:
                df_sfvector['database'] = 'sfvector (FAISS)'
            if not df_pg.empty:
                df_pg['database'] = 'pgvector'
            
            df_combined = pd.concat([df_sql2025, df_sfvector, df_pg], ignore_index=True)
            
            if df_combined.empty:
                print("No data to plot")
                return
            
            sns.set_style("whitegrid")
            
            # Chart 1: Search Throughput Comparison
            fig, ax = plt.subplots(figsize=(12, 6))
            
            search_data = df_combined[df_combined['test_category'] == 'SEARCH_KNN']
            if not search_data.empty:
                sns.barplot(data=search_data, x='database', y='throughput', ax=ax)
                ax.set_title('Search Throughput Comparison (QPS)', fontsize=14, fontweight='bold')
                ax.set_ylabel('Queries per Second', fontsize=12)
                ax.set_xlabel('Implementation', fontsize=12)
                plt.xticks(rotation=15, ha='right')
                plt.tight_layout()
                plt.savefig(self.output_dir / 'sql2025_search_comparison.png', dpi=300)
                print(f"✓ Saved sql2025_search_comparison.png")
                plt.close()
            
            # Chart 2: Index Build Time Comparison
            fig, ax = plt.subplots(figsize=(12, 6))
            
            index_data = df_combined[df_combined['test_category'] == 'INDEX_BUILD']
            if not index_data.empty:
                sns.barplot(data=index_data, x='database', y='elapsed_ms', 
                           hue='index_type', ax=ax)
                ax.set_title('Index Build Time Comparison', fontsize=14, fontweight='bold')
                ax.set_ylabel('Time (milliseconds)', fontsize=12)
                ax.set_xlabel('Implementation', fontsize=12)
                plt.xticks(rotation=15, ha='right')
                plt.legend(title='Index Type', bbox_to_anchor=(1.05, 1), loc='upper left')
                plt.tight_layout()
                plt.savefig(self.output_dir / 'sql2025_index_comparison.png', dpi=300)
                print(f"✓ Saved sql2025_index_comparison.png")
                plt.close()
            
        except Exception as e:
            print(f"Warning: Could not generate charts: {e}")


def main():
    parser = argparse.ArgumentParser(
        description='Compare SQL Server 2025 native vectors, sfvector (FAISS), and pgvector'
    )
    
    # Database connections
    parser.add_argument('--sqlserver-conn', required=True, 
                       help='SQL Server connection string (2025 or earlier)')
    parser.add_argument('--postgres-conn', 
                       help='PostgreSQL connection string (optional)')
    
    # Test configuration
    parser.add_argument('--dataset', default='sql2025_bench_10k',
                       help='Dataset name')
    parser.add_argument('--dataset-size', type=int, default=10000,
                       help='Number of vectors to test')
    parser.add_argument('--dimension', type=int, default=1536,
                       help='Vector dimension')
    parser.add_argument('--output-dir', type=Path, default=Path('results_sql2025'),
                       help='Output directory for results')
    
    # Test selection
    parser.add_argument('--no-insert', action='store_true', help='Skip insert tests')
    parser.add_argument('--no-index', action='store_true', help='Skip index build tests')
    parser.add_argument('--no-search', action='store_true', help='Skip search tests')
    parser.add_argument('--skip-pgvector', action='store_true', 
                       help='Skip pgvector comparison')
    
    args = parser.parse_args()
    
    if not DEPS_AVAILABLE:
        print("Error: Required dependencies not installed")
        print("Install with: pip install psycopg2-binary pyodbc pandas matplotlib seaborn")
        sys.exit(1)
    
    runner = SQL2025BenchmarkRunner(args.output_dir)
    
    # Connect to SQL Server
    sqlserver_conn = runner.connect_sqlserver(args.sqlserver_conn)
    if not sqlserver_conn:
        print("Error: Could not connect to SQL Server")
        sys.exit(1)
    
    # Connect to PostgreSQL (optional)
    postgres_conn = None
    if args.postgres_conn and not args.skip_pgvector:
        postgres_conn = runner.connect_postgres(args.postgres_conn)
    
    # Run benchmarks
    try:
        # SQL Server 2025 benchmarks (includes both native and sfvector)
        runner.run_sql2025_benchmarks(
            sqlserver_conn,
            args.dataset,
            args.dataset_size,
            args.dimension,
            not args.no_insert,
            not args.no_index,
            not args.no_search
        )
        
        # pgvector benchmarks
        if postgres_conn:
            runner.run_pgvector_benchmarks(
                postgres_conn,
                args.dataset,
                not args.no_insert,
                not args.no_index,
                not args.no_search
            )
        
        # Compare all results
        runner.compare_all_implementations()
        runner.generate_comparison_report()
        
        print("\n" + "="*60)
        print("✓ SQL Server 2025 Comparison Complete!")
        print(f"Results saved to: {args.output_dir}")
        print("="*60)
        
    finally:
        if sqlserver_conn:
            sqlserver_conn.close()
        if postgres_conn:
            postgres_conn.close()


if __name__ == '__main__':
    main()
