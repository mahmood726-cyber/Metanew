"""
Comprehensive Test Runner for EvidenceOS PRIME
===============================================

This script runs all test suites in the correct order and generates comprehensive coverage reports.

Test Suites:
1. Backend Unit Tests (pytest)
2. R Frontend Tests (testthat)
3. End-to-End GUI Tests (Selenium)
4. Integration Tests (pytest)

Usage:
    python tests/run_all_tests.py [options]

Options:
    --quick         Run quick tests only (skip E2E and integration)
    --backend-only  Run backend tests only
    --coverage      Generate coverage report (default: True)
    --verbose       Verbose output
    --parallel      Run tests in parallel where possible
"""

import argparse
import subprocess
import sys
import os
from pathlib import Path
from typing import List, Tuple
import time

# Colors for terminal output
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[0;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color


def print_header(message: str):
    """Print a formatted header"""
    print(f"\n{Colors.BLUE}{'='*80}{Colors.NC}")
    print(f"{Colors.BLUE}{message.center(80)}{Colors.NC}")
    print(f"{Colors.BLUE}{'='*80}{Colors.NC}\n")


def print_success(message: str):
    """Print success message"""
    print(f"{Colors.GREEN}✓ {message}{Colors.NC}")


def print_warning(message: str):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠ {message}{Colors.NC}")


def print_error(message: str):
    """Print error message"""
    print(f"{Colors.RED}✗ {message}{Colors.NC}")


def run_command(cmd: List[str], description: str, optional: bool = False) -> Tuple[bool, float]:
    """
    Run a command and return success status and execution time

    Args:
        cmd: Command to run as list
        description: Description for logging
        optional: If True, failure won't stop execution

    Returns:
        Tuple of (success, execution_time)
    """
    print(f"\n{Colors.BLUE}Running: {description}{Colors.NC}")
    print(f"Command: {' '.join(cmd)}\n")

    start_time = time.time()
    try:
        result = subprocess.run(cmd, check=True, cwd=str(Path(__file__).parent.parent))
        execution_time = time.time() - start_time
        print_success(f"{description} completed in {execution_time:.2f}s")
        return True, execution_time
    except subprocess.CalledProcessError as e:
        execution_time = time.time() - start_time
        if optional:
            print_warning(f"{description} failed (optional test suite)")
            return False, execution_time
        else:
            print_error(f"{description} failed with exit code {e.returncode}")
            return False, execution_time
    except FileNotFoundError as e:
        print_error(f"Command not found: {e}")
        if optional:
            return False, 0
        else:
            return False, 0


def check_dependencies() -> bool:
    """Check if required dependencies are installed"""
    print_header("Checking Dependencies")

    dependencies = {
        'pytest': ['pytest', '--version'],
        'coverage': ['pytest', '--version'],
        'selenium': [sys.executable, '-c', 'import selenium'],
        'R': ['Rscript', '--version'],
    }

    all_ok = True
    for name, cmd in dependencies.items():
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            print_success(f"{name} is installed")
        except (subprocess.CalledProcessError, FileNotFoundError):
            print_error(f"{name} is NOT installed")
            all_ok = False

    return all_ok


def run_backend_unit_tests(verbose: bool = False, coverage: bool = True) -> Tuple[bool, float]:
    """Run backend unit tests with pytest"""
    cmd = [sys.executable, '-m', 'pytest', 'tests/py/', '-v']

    if coverage:
        cmd.extend([
            '--cov=backend',
            '--cov-report=html:htmlcov',
            '--cov-report=term-missing',
            '--cov-report=xml'
        ])

    if verbose:
        cmd.append('-vv')
    else:
        cmd.append('--tb=short')

    return run_command(cmd, "Backend Unit Tests")


def run_r_frontend_tests() -> Tuple[bool, float]:
    """Run R frontend tests with testthat"""
    cmd = [
        'Rscript',
        '-e',
        "testthat::test_dir('tests/r', reporter = testthat::ProgressReporter)"
    ]

    return run_command(cmd, "R Frontend Tests", optional=True)


def run_e2e_gui_tests(verbose: bool = False) -> Tuple[bool, float]:
    """Run end-to-end GUI tests with Selenium"""
    cmd = [sys.executable, '-m', 'pytest', 'tests/e2e/', '-v']

    if verbose:
        cmd.append('-vv')
    else:
        cmd.append('--tb=short')

    return run_command(cmd, "End-to-End GUI Tests (Selenium)", optional=True)


def run_integration_tests(verbose: bool = False) -> Tuple[bool, float]:
    """Run integration tests"""
    cmd = [sys.executable, '-m', 'pytest', 'tests/integration/', '-v']

    if verbose:
        cmd.append('-vv')
    else:
        cmd.append('--tb=short')

    return run_command(cmd, "Integration Tests", optional=True)


def run_api_tests(verbose: bool = False) -> Tuple[bool, float]:
    """Run API-specific tests"""
    cmd = [sys.executable, '-m', 'pytest', 'tests/py/test_api_comprehensive.py', '-v']

    if verbose:
        cmd.append('-vv')

    return run_command(cmd, "API Comprehensive Tests")


def generate_coverage_report():
    """Generate final coverage report"""
    print_header("Coverage Report")

    try:
        subprocess.run(
            [sys.executable, '-m', 'coverage', 'report', '--skip-empty'],
            check=False
        )
        print_success("Coverage report generated: htmlcov/index.html")
    except Exception as e:
        print_warning(f"Could not generate coverage report: {e}")


def main():
    """Main test runner"""
    parser = argparse.ArgumentParser(
        description='Run comprehensive test suite for EvidenceOS PRIME'
    )
    parser.add_argument(
        '--quick',
        action='store_true',
        help='Run quick tests only (skip E2E and integration)'
    )
    parser.add_argument(
        '--backend-only',
        action='store_true',
        help='Run backend tests only'
    )
    parser.add_argument(
        '--no-coverage',
        action='store_true',
        help='Disable coverage reporting'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Verbose output'
    )
    parser.add_argument(
        '--skip-deps-check',
        action='store_true',
        help='Skip dependency checking'
    )

    args = parser.parse_args()

    print_header("EvidenceOS PRIME - Comprehensive Test Suite")

    # Check dependencies
    if not args.skip_deps_check:
        if not check_dependencies():
            print_warning("Some dependencies are missing, but continuing anyway...")
            time.sleep(2)

    # Track results
    results = {}
    total_time = 0

    # Run backend unit tests
    success, exec_time = run_backend_unit_tests(
        verbose=args.verbose,
        coverage=not args.no_coverage
    )
    results['Backend Unit Tests'] = success
    total_time += exec_time

    if not args.backend_only:
        # Run R frontend tests
        success, exec_time = run_r_frontend_tests()
        results['R Frontend Tests'] = success
        total_time += exec_time

        # Run API tests
        success, exec_time = run_api_tests(verbose=args.verbose)
        results['API Tests'] = success
        total_time += exec_time

        if not args.quick:
            # Run E2E GUI tests
            success, exec_time = run_e2e_gui_tests(verbose=args.verbose)
            results['E2E GUI Tests'] = success
            total_time += exec_time

            # Run integration tests
            success, exec_time = run_integration_tests(verbose=args.verbose)
            results['Integration Tests'] = success
            total_time += exec_time

    # Generate coverage report
    if not args.no_coverage:
        generate_coverage_report()

    # Print summary
    print_header("Test Summary")

    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for test_suite, success in results.items():
        if success:
            print_success(f"{test_suite}")
        else:
            print_error(f"{test_suite}")

    print(f"\n{Colors.BLUE}Total Time: {total_time:.2f}s{Colors.NC}")
    print(f"{Colors.BLUE}Tests Passed: {passed}/{total}{Colors.NC}\n")

    if passed == total:
        print_success("All test suites passed!")
        return 0
    else:
        print_error(f"{total - passed} test suite(s) failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
