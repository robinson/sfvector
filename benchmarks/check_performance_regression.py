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
Performance regression checker
Compares benchmark results against baseline/thresholds
"""

import json
import sys
from pathlib import Path
from typing import Dict, List

class RegressionChecker:
    def __init__(self, results_path: Path):
        self.results_path = results_path
        self.thresholds = {
            'index_build': {
                'max_time_ms': {
                    '1k': 5000,      # 5 seconds
                    '10k': 30000,    # 30 seconds
                    '100k': 180000,  # 3 minutes
                    '1m': 1200000    # 20 minutes
                },
                'min_throughput': 100  # vectors/sec
            },
            'search': {
                'min_qps': {
                    '1k': 100,
                    '10k': 200,
                    '100k': 100,
                    '1m': 50
                },
                'max_latency_ms': 100
            },
            'recall': {
                'min_recall': 0.90  # 90% minimum
            }
        }
        self.failures = []
    
    def load_results(self) -> Dict:
        """Load benchmark results"""
        results_file = self.results_path / 'benchmark_results.json'
        if not results_file.exists():
            print(f"Error: Results file not found: {results_file}")
            sys.exit(1)
        
        with open(results_file, 'r') as f:
            return json.load(f)
    
    def get_dataset_size_category(self, size: int) -> str:
        """Categorize dataset size"""
        if size <= 1000:
            return '1k'
        elif size <= 10000:
            return '10k'
        elif size <= 100000:
            return '100k'
        else:
            return '1m'
    
    def check_index_build(self, results: List[Dict]) -> bool:
        """Check index build performance"""
        print("\n--- Index Build Performance ---")
        passed = True
        
        for result in results:
            if result.get('test_category') != 'INDEX_BUILD':
                continue
            
            dataset_size = result.get('dataset_size', 0)
            size_cat = self.get_dataset_size_category(dataset_size)
            
            elapsed_ms = result.get('elapsed_ms', 0)
            max_time = self.thresholds['index_build']['max_time_ms'].get(size_cat, float('inf'))
            
            test_name = result.get('test_name', 'Unknown')
            index_type = result.get('index_type', 'Unknown')
            
            if elapsed_ms > max_time:
                print(f"❌ FAIL: {test_name}")
                print(f"   Index: {index_type}, Size: {dataset_size}")
                print(f"   Time: {elapsed_ms}ms (max: {max_time}ms)")
                self.failures.append({
                    'test': test_name,
                    'reason': f'Build time {elapsed_ms}ms exceeds threshold {max_time}ms'
                })
                passed = False
            else:
                print(f"✓ PASS: {test_name} ({elapsed_ms}ms)")
        
        return passed
    
    def check_search_performance(self, results: List[Dict]) -> bool:
        """Check search performance"""
        print("\n--- Search Performance ---")
        passed = True
        
        for result in results:
            if result.get('test_category') != 'SEARCH_KNN':
                continue
            
            dataset_size = result.get('dataset_size', 0)
            size_cat = self.get_dataset_size_category(dataset_size)
            
            qps = result.get('throughput', 0)
            min_qps = self.thresholds['search']['min_qps'].get(size_cat, 0)
            
            test_name = result.get('test_name', 'Unknown')
            index_type = result.get('index_type', 'Unknown')
            
            if qps < min_qps:
                print(f"❌ FAIL: {test_name}")
                print(f"   Index: {index_type}, Size: {dataset_size}")
                print(f"   QPS: {qps:.2f} (min: {min_qps})")
                self.failures.append({
                    'test': test_name,
                    'reason': f'QPS {qps:.2f} below threshold {min_qps}'
                })
                passed = False
            else:
                print(f"✓ PASS: {test_name} ({qps:.2f} QPS)")
        
        return passed
    
    def check_recall(self, results: List[Dict]) -> bool:
        """Check recall/accuracy"""
        print("\n--- Recall/Accuracy ---")
        passed = True
        
        for result in results:
            if result.get('test_category') != 'RECALL':
                continue
            
            additional = result.get('additional_metrics', {})
            if isinstance(additional, str):
                try:
                    import json
                    additional = json.loads(additional)
                except:
                    continue
            
            recall = additional.get('recall', 0)
            min_recall = self.thresholds['recall']['min_recall']
            
            test_name = result.get('test_name', 'Unknown')
            
            if recall < min_recall:
                print(f"❌ FAIL: {test_name}")
                print(f"   Recall: {recall:.4f} (min: {min_recall})")
                self.failures.append({
                    'test': test_name,
                    'reason': f'Recall {recall:.4f} below threshold {min_recall}'
                })
                passed = False
            else:
                print(f"✓ PASS: {test_name} (recall: {recall:.4f})")
        
        return passed
    
    def run(self) -> bool:
        """Run all checks"""
        print("="*60)
        print("Performance Regression Check")
        print("="*60)
        print(f"Results: {self.results_path}")
        
        results = self.load_results()
        
        # Check both SQL Server and pgvector results
        all_passed = True
        
        for db_type in ['sqlserver', 'pgvector']:
            db_results = results.get(db_type, [])
            if not db_results:
                continue
            
            print(f"\n{'='*60}")
            print(f"{db_type.upper()} Results")
            print(f"{'='*60}")
            
            passed = self.check_index_build(db_results)
            all_passed = all_passed and passed
            
            passed = self.check_search_performance(db_results)
            all_passed = all_passed and passed
            
            passed = self.check_recall(db_results)
            all_passed = all_passed and passed
        
        # Summary
        print("\n" + "="*60)
        print("Summary")
        print("="*60)
        
        if all_passed:
            print("✓ All checks PASSED")
            return True
        else:
            print(f"❌ {len(self.failures)} checks FAILED:")
            for failure in self.failures:
                print(f"  - {failure['test']}: {failure['reason']}")
            return False


def main():
    if len(sys.argv) < 2:
        print("Usage: check_performance_regression.py <results_directory>")
        sys.exit(1)
    
    results_path = Path(sys.argv[1])
    
    checker = RegressionChecker(results_path)
    success = checker.run()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
