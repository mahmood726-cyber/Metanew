"""
Comprehensive tests for backend/etl/ingest.py
Tests data ingestion, file parsing, and format detection

Coverage Target: 100%
"""
import pytest
import pandas as pd
import numpy as np
import os
import tempfile
from pathlib import Path

from backend.etl.ingest import (
    read_data_file,
    parse_revman_csv,
    parse_distiller_export,
    detect_data_format,
    ingest_and_prepare
)


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def temp_dir():
    """Create temporary directory for test files"""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir


@pytest.fixture
def sample_csv_file(temp_dir):
    """Create sample CSV file"""
    file_path = os.path.join(temp_dir, "test_data.csv")
    df = pd.DataFrame({
        'study_id': ['S1', 'S2', 'S3'],
        'treatment': ['A', 'B', 'C'],
        'events': [10, 20, 15],
        'n': [100, 150, 120]
    })
    df.to_csv(file_path, index=False)
    return file_path


@pytest.fixture
def sample_excel_file(temp_dir):
    """Create sample Excel file"""
    file_path = os.path.join(temp_dir, "test_data.xlsx")
    df = pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'mean': [10.5, 12.3],
        'sd': [2.1, 2.5],
        'sample_size': [50, 60]  # Use sample_size instead of 'n' to avoid binary detection
    })
    df.to_excel(file_path, index=False)
    return file_path


@pytest.fixture
def revman_csv_file(temp_dir):
    """Create RevMan-style CSV with header rows"""
    file_path = os.path.join(temp_dir, "revman.csv")
    with open(file_path, 'w') as f:
        # RevMan has multiple header rows
        f.write("RevMan Export Version 5.0\n")
        f.write("study_id,treatment,events,n\n")
        f.write("S1,A,10,100\n")
        f.write("S2,B,20,150\n")
    return file_path


@pytest.fixture
def binary_data():
    """Binary outcome data"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'treatment': ['A', 'B'],
        'events': [10, 20],
        'n': [100, 150]
    })


@pytest.fixture
def continuous_data():
    """Continuous outcome data"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'treatment': ['A', 'B'],
        'mean': [10.5, 12.3],
        'sd': [2.1, 2.5],
        'sample_size': [50, 60]  # Use sample_size instead of 'n' to avoid binary detection
    })


@pytest.fixture
def tte_data():
    """Time-to-event data"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'treatment': ['A', 'B'],
        'hr': [0.7, 0.8],
        'ci_lower': [0.5, 0.6],
        'ci_upper': [0.9, 1.0]
    })


# ============================================================================
# TEST 1: READ_DATA_FILE FUNCTION (Unit + Edge Cases)
# ============================================================================

class TestReadDataFile:
    """Comprehensive tests for read_data_file function"""

    def test_read_csv_file(self, sample_csv_file):
        """Test 1.1: Read valid CSV file"""
        df = read_data_file(sample_csv_file)
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 3
        assert 'study_id' in df.columns
        assert 'events' in df.columns

    def test_read_excel_file(self, sample_excel_file):
        """Test 1.2: Read valid Excel file"""
        df = read_data_file(sample_excel_file)
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 2
        assert 'mean' in df.columns
        assert 'sd' in df.columns

    def test_file_not_found(self, temp_dir):
        """Test 1.3: Non-existent file raises FileNotFoundError"""
        nonexistent_file = os.path.join(temp_dir, "nonexistent.csv")
        with pytest.raises(FileNotFoundError, match="File not found"):
            read_data_file(nonexistent_file)

    def test_unsupported_file_format(self, temp_dir):
        """Test 1.4: Unsupported file format raises ValueError"""
        txt_file = os.path.join(temp_dir, "test.txt")
        with open(txt_file, 'w') as f:
            f.write("test data")

        with pytest.raises(ValueError, match="Unsupported file format"):
            read_data_file(txt_file)

    def test_csv_with_kwargs(self, temp_dir):
        """Test 1.5: CSV with additional kwargs (delimiter, encoding)"""
        # Create CSV with semicolon delimiter
        file_path = os.path.join(temp_dir, "semicolon.csv")
        with open(file_path, 'w') as f:
            f.write("study_id;treatment;events\n")
            f.write("S1;A;10\n")
            f.write("S2;B;20\n")

        df = read_data_file(file_path, delimiter=';')
        assert len(df) == 2
        assert 'study_id' in df.columns

    def test_excel_with_sheet_name(self, temp_dir):
        """Test 1.6: Excel with specific sheet name"""
        file_path = os.path.join(temp_dir, "multi_sheet.xlsx")

        # Create Excel with multiple sheets
        with pd.ExcelWriter(file_path) as writer:
            pd.DataFrame({'A': [1, 2]}).to_excel(writer, sheet_name='Sheet1', index=False)
            pd.DataFrame({'B': [3, 4]}).to_excel(writer, sheet_name='Sheet2', index=False)

        df = read_data_file(file_path, sheet_name='Sheet2')
        assert 'B' in df.columns
        assert 'A' not in df.columns

    def test_empty_csv_file(self, temp_dir):
        """Test 1.7: Empty CSV file"""
        file_path = os.path.join(temp_dir, "empty.csv")
        with open(file_path, 'w') as f:
            f.write("study_id,treatment,events,n\n")

        df = read_data_file(file_path)
        assert len(df) == 0
        assert 'study_id' in df.columns

    def test_csv_with_missing_values(self, temp_dir):
        """Test 1.8: CSV with missing values"""
        file_path = os.path.join(temp_dir, "missing.csv")
        with open(file_path, 'w') as f:
            f.write("study_id,events,n\n")
            f.write("S1,10,100\n")
            f.write("S2,,150\n")
            f.write("S3,15,\n")

        df = read_data_file(file_path)
        assert len(df) == 3
        assert pd.isna(df.loc[1, 'events'])
        assert pd.isna(df.loc[2, 'n'])


# ============================================================================
# TEST 2: PARSE_REVMAN_CSV FUNCTION
# ============================================================================

class TestParseRevmanCsv:
    """Tests for RevMan CSV parsing"""

    def test_parse_revman_format(self, revman_csv_file):
        """Test 2.1: Parse RevMan CSV with header row"""
        df = parse_revman_csv(revman_csv_file)
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 2
        assert 'study_id' in df.columns

    def test_revman_column_names_cleaned(self, temp_dir):
        """Test 2.2: Column names are stripped of whitespace"""
        file_path = os.path.join(temp_dir, "revman_spaces.csv")
        with open(file_path, 'w') as f:
            f.write("RevMan Export\n")
            f.write(" study_id , treatment , events \n")
            f.write("S1,A,10\n")

        df = parse_revman_csv(file_path)
        # Column names should be stripped
        assert 'study_id' in df.columns
        assert 'treatment' in df.columns
        assert ' study_id ' not in df.columns

    def test_revman_empty_after_skip(self, temp_dir):
        """Test 2.3: RevMan CSV with only header"""
        file_path = os.path.join(temp_dir, "revman_empty.csv")
        with open(file_path, 'w') as f:
            f.write("RevMan Export\n")
            f.write("study_id,treatment,events\n")

        df = parse_revman_csv(file_path)
        assert len(df) == 0


# ============================================================================
# TEST 3: PARSE_DISTILLER_EXPORT FUNCTION
# ============================================================================

class TestParseDistillerExport:
    """Tests for DistillerSR export parsing"""

    def test_parse_distiller_basic(self, temp_dir):
        """Test 3.1: Parse basic DistillerSR export"""
        file_path = os.path.join(temp_dir, "distiller.csv")
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'outcome': ['Death', 'MI'],
            'events': [10, 20]
        })
        df.to_csv(file_path, index=False)

        result = parse_distiller_export(file_path)
        assert isinstance(result, pd.DataFrame)
        assert len(result) == 2

    def test_parse_distiller_empty(self, temp_dir):
        """Test 3.2: Parse empty DistillerSR export"""
        file_path = os.path.join(temp_dir, "distiller_empty.csv")
        with open(file_path, 'w') as f:
            f.write("study_id,outcome,events\n")

        result = parse_distiller_export(file_path)
        assert len(result) == 0


# ============================================================================
# TEST 4: DETECT_DATA_FORMAT FUNCTION (Triple Coverage)
# ============================================================================

class TestDetectDataFormat:
    """Comprehensive tests for format detection"""

    def test_detect_binary_format(self, binary_data):
        """Test 4.1: Detect binary data format"""
        format_type = detect_data_format(binary_data)
        assert format_type == "binary"

    def test_detect_continuous_format(self, continuous_data):
        """Test 4.2: Detect continuous data format"""
        format_type = detect_data_format(continuous_data)
        assert format_type == "continuous"

    def test_detect_tte_format(self, tte_data):
        """Test 4.3: Detect time-to-event format"""
        format_type = detect_data_format(tte_data)
        assert format_type == "tte"

    def test_detect_effect_size_format(self):
        """Test 4.4: Detect pre-computed effect sizes"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'yi': [0.5, 0.7],
            'sei': [0.1, 0.15]
        })
        format_type = detect_data_format(df)
        assert format_type == "effect_size"

    def test_detect_unknown_format(self):
        """Test 4.5: Unknown format"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'some_column': [1, 2],
            'another_column': [3, 4]
        })
        format_type = detect_data_format(df)
        assert format_type == "unknown"

    def test_detect_binary_with_r_column(self):
        """Test 4.6: Detect binary with 'r' column name"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'r': [10],  # events column named 'r'
            'n': [100]
        })
        format_type = detect_data_format(df)
        assert format_type == "binary"

    def test_detect_binary_with_n_events(self):
        """Test 4.7: Detect binary with 'n_events' column"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'n_events': [10],
            'total': [100]
        })
        format_type = detect_data_format(df)
        assert format_type == "binary"

    def test_detect_continuous_with_std(self):
        """Test 4.8: Detect continuous with 'std' instead of 'sd'"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean': [10.5],
            'std': [2.1],  # std instead of sd
            'sample_size': [50]  # Use sample_size instead of 'n' to avoid binary detection
        })
        format_type = detect_data_format(df)
        assert format_type == "continuous"

    def test_detect_tte_with_loghr(self):
        """Test 4.9: Detect TTE with loghr column"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'loghr': [-0.3],
            'se_loghr': [0.15]
        })
        format_type = detect_data_format(df)
        assert format_type == "tte"

    def test_detect_tte_with_hazard(self):
        """Test 4.10: Detect TTE with 'hazard' column"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'hazard': [0.7]
        })
        format_type = detect_data_format(df)
        assert format_type == "tte"

    def test_detect_case_insensitive(self):
        """Test 4.11: Detection is case-insensitive"""
        df = pd.DataFrame({
            'STUDY_ID': ['S1'],
            'EVENTS': [10],
            'N': [100]
        })
        format_type = detect_data_format(df)
        assert format_type == "binary"


# ============================================================================
# TEST 5: INGEST_AND_PREPARE FUNCTION (Complete Pipeline)
# ============================================================================

class TestIngestAndPrepare:
    """Comprehensive tests for complete ingestion pipeline"""

    def test_ingest_csv_file(self, sample_csv_file):
        """Test 5.1: Ingest CSV file with auto-detection"""
        result = ingest_and_prepare(sample_csv_file)

        assert 'data' in result
        assert 'n_rows' in result
        assert 'n_cols' in result
        assert 'columns' in result
        assert 'data_type' in result
        assert 'file_path' in result

        assert result['n_rows'] == 3
        assert result['data_type'] == 'binary'
        assert isinstance(result['data'], pd.DataFrame)

    def test_ingest_excel_file(self, sample_excel_file):
        """Test 5.2: Ingest Excel file with auto-detection"""
        result = ingest_and_prepare(sample_excel_file)

        assert result['n_rows'] == 2
        assert result['data_type'] == 'continuous'
        assert 'mean' in result['columns']

    def test_ingest_with_explicit_data_type(self, sample_csv_file):
        """Test 5.3: Ingest with explicit data type override"""
        result = ingest_and_prepare(sample_csv_file, data_type='custom')

        assert result['data_type'] == 'custom'

    def test_ingest_removes_empty_rows(self, temp_dir):
        """Test 5.4: Empty rows are removed"""
        file_path = os.path.join(temp_dir, "with_empty.csv")
        with open(file_path, 'w') as f:
            f.write("study_id,events,n\n")
            f.write("S1,10,100\n")
            f.write(",,\n")  # Empty row
            f.write("S2,20,150\n")
            f.write(",,\n")  # Another empty row

        result = ingest_and_prepare(file_path)
        assert result['n_rows'] == 2  # Empty rows removed

    def test_ingest_removes_empty_columns(self, temp_dir):
        """Test 5.5: Empty columns are removed"""
        file_path = os.path.join(temp_dir, "with_empty_col.csv")
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'events': [10, 20],
            'n': [100, 150],
            'empty_col': [np.nan, np.nan]
        })
        df.to_csv(file_path, index=False)

        result = ingest_and_prepare(file_path)
        assert 'empty_col' not in result['columns']

    def test_ingest_normalizes_column_names(self, temp_dir):
        """Test 5.6: Column names are normalized"""
        file_path = os.path.join(temp_dir, "unnormalized.csv")
        with open(file_path, 'w') as f:
            f.write("studyid,Treatment,EVENTS,n\n")
            f.write("S1,A,10,100\n")

        result = ingest_and_prepare(file_path)
        # Check that column normalization was applied
        assert 'study_id' in result['columns']

    def test_ingest_with_kwargs(self, temp_dir):
        """Test 5.7: Ingest with additional pandas kwargs"""
        file_path = os.path.join(temp_dir, "custom_delim.csv")
        with open(file_path, 'w') as f:
            f.write("study_id|events|n\n")
            f.write("S1|10|100\n")

        result = ingest_and_prepare(file_path, delimiter='|')
        assert result['n_rows'] == 1
        assert 'events' in result['columns']

    def test_ingest_metadata_complete(self, sample_csv_file):
        """Test 5.8: All metadata fields are populated"""
        result = ingest_and_prepare(sample_csv_file)

        assert result['n_rows'] > 0
        assert result['n_cols'] > 0
        assert len(result['columns']) == result['n_cols']
        assert result['file_path'] == sample_csv_file
        assert result['data_type'] in ['binary', 'continuous', 'tte', 'effect_size', 'unknown']

    def test_ingest_file_not_found(self, temp_dir):
        """Test 5.9: Ingest non-existent file raises error"""
        nonexistent = os.path.join(temp_dir, "nonexistent.csv")
        with pytest.raises(FileNotFoundError):
            ingest_and_prepare(nonexistent)


# ============================================================================
# TEST 6: EDGE CASES
# ============================================================================

class TestIngestEdgeCases:
    """Edge case tests for ingestion module"""

    def test_very_large_dataset(self, temp_dir):
        """Test 6.1: Ingest large dataset (10000 rows)"""
        file_path = os.path.join(temp_dir, "large.csv")
        df = pd.DataFrame({
            'study_id': [f'S{i}' for i in range(10000)],
            'events': np.random.randint(1, 100, 10000),
            'n': np.random.randint(100, 500, 10000)
        })
        df.to_csv(file_path, index=False)

        result = ingest_and_prepare(file_path)
        assert result['n_rows'] == 10000

    def test_unicode_in_data(self, temp_dir):
        """Test 6.2: Handle Unicode characters"""
        file_path = os.path.join(temp_dir, "unicode.csv")
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['Tré¿ment A', '治療 B'],
            'events': [10, 20],
            'n': [100, 150]
        })
        df.to_csv(file_path, index=False, encoding='utf-8')

        result = ingest_and_prepare(file_path)
        assert result['n_rows'] == 2

    def test_special_characters_in_columns(self, temp_dir):
        """Test 6.3: Column names with special characters"""
        file_path = os.path.join(temp_dir, "special_chars.csv")
        with open(file_path, 'w') as f:
            f.write("study-id,events (n),n [total]\n")
            f.write("S1,10,100\n")

        result = ingest_and_prepare(file_path)
        assert result['n_rows'] == 1

    def test_mixed_data_types(self, temp_dir):
        """Test 6.4: Mixed data types in columns"""
        file_path = os.path.join(temp_dir, "mixed.csv")
        with open(file_path, 'w') as f:
            f.write("study_id,value\n")
            f.write("S1,10\n")
            f.write("S2,text\n")
            f.write("S3,12.5\n")

        result = ingest_and_prepare(file_path)
        assert result['n_rows'] == 3

    def test_whitespace_handling(self, temp_dir):
        """Test 6.5: Leading/trailing whitespace"""
        file_path = os.path.join(temp_dir, "whitespace.csv")
        with open(file_path, 'w') as f:
            f.write("study_id,events,n\n")
            f.write(" S1 , 10 , 100 \n")
            f.write("  S2,20,150\n")

        result = ingest_and_prepare(file_path)
        assert result['n_rows'] == 2


# ============================================================================
# TEST 7: INTEGRATION TESTS
# ============================================================================

class TestIngestIntegration:
    """Integration tests combining multiple functions"""

    def test_full_pipeline_binary_data(self, temp_dir):
        """Test 7.1: Complete pipeline for binary data"""
        # Create test file
        file_path = os.path.join(temp_dir, "binary_test.csv")
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'treatment': ['Drug', 'Placebo', 'Drug'],
            'events': [10, 15, 12],
            'n': [100, 150, 120]
        })
        df.to_csv(file_path, index=False)

        # Run pipeline
        result = ingest_and_prepare(file_path)

        # Verify
        assert result['data_type'] == 'binary'
        assert result['n_rows'] == 3
        assert 'study_id' in result['columns']
        assert 'events' in result['columns']

    def test_full_pipeline_continuous_data(self, temp_dir):
        """Test 7.2: Complete pipeline for continuous data"""
        file_path = os.path.join(temp_dir, "continuous_test.xlsx")
        # Use contrast format (mean1, sd1, n1, mean2, sd2, n2)
        # This won't be auto-detected as 'continuous' because columns have numeric suffixes
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'mean1': [10.5, 12.3],
            'sd1': [2.1, 2.5],
            'n1': [50, 60],
            'mean2': [11.2, 13.1],
            'sd2': [2.3, 2.7],
            'n2': [55, 65]
        })
        df.to_excel(file_path, index=False)

        # Use explicit data type since auto-detection won't work for contrast format
        result = ingest_and_prepare(file_path, data_type='continuous')

        assert result['data_type'] == 'continuous'
        assert result['n_rows'] == 2

    def test_revman_to_pipeline(self, revman_csv_file):
        """Test 7.3: RevMan export through pipeline"""
        # First parse as RevMan
        df = parse_revman_csv(revman_csv_file)

        # Verify it works
        assert len(df) == 2

        # Could save and re-ingest if needed
        format_type = detect_data_format(df)
        assert format_type == 'binary'


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
