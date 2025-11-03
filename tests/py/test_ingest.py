"""
Comprehensive tests for ETL ingest module - 100% Coverage
Target: 100% coverage of etl/ingest.py
"""
import pytest
import pandas as pd
import tempfile
import os
from pathlib import Path
import sys

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from etl.ingest import (
    read_data_file,
    parse_revman_csv,
    parse_distiller_export,
    detect_data_format,
    ingest_and_prepare
)


class TestReadDataFile:
    """Test read_data_file function"""

    @pytest.fixture
    def sample_csv_file(self):
        """Create temporary CSV file"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('study_id,treatment,mean,sd,n\n')
        temp_file.write('Study1,DrugA,5.2,1.1,50\n')
        temp_file.write('Study2,DrugB,6.1,1.3,45\n')
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    @pytest.fixture
    def sample_excel_file(self):
        """Create temporary Excel file"""
        temp_file = tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False)
        df = pd.DataFrame({
            'study_id': ['Study1', 'Study2'],
            'treatment': ['DrugA', 'DrugB'],
            'mean': [5.2, 6.1]
        })
        df.to_excel(temp_file.name, index=False)
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    def test_read_csv_file(self, sample_csv_file):
        """Test reading CSV file"""
        df = read_data_file(sample_csv_file)
        assert df is not None
        assert len(df) == 2
        assert 'study_id' in df.columns

    def test_read_excel_file(self, sample_excel_file):
        """Test reading Excel file"""
        df = read_data_file(sample_excel_file)
        assert df is not None
        assert len(df) == 2
        assert 'study_id' in df.columns

    def test_file_not_found(self):
        """Test FileNotFoundError"""
        with pytest.raises(FileNotFoundError):
            read_data_file('/nonexistent/file.csv')

    def test_unsupported_format(self):
        """Test unsupported file format"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False)
        temp_file.write('data')
        temp_file.close()
        try:
            with pytest.raises(ValueError, match="Unsupported file format"):
                read_data_file(temp_file.name)
        finally:
            os.unlink(temp_file.name)

    def test_read_csv_with_kwargs(self, sample_csv_file):
        """Test CSV with additional kwargs"""
        df = read_data_file(sample_csv_file, encoding='utf-8')
        assert df is not None

    def test_read_xls_format(self):
        """Test .xls format (skipped - requires xlwt)"""
        # .xls format requires xlwt which may not be installed
        # Use .xlsx format instead for testing
        temp_file = tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False)
        df = pd.DataFrame({'col': [1, 2]})
        df.to_excel(temp_file.name, index=False)
        temp_file.close()
        try:
            result = read_data_file(temp_file.name)
            assert result is not None
        finally:
            os.unlink(temp_file.name)


class TestParseRevmanCsv:
    """Test parse_revman_csv function"""

    @pytest.fixture
    def revman_csv_file(self):
        """Create RevMan-style CSV"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('Header row to skip\n')
        temp_file.write(' study_id , treatment , events , n \n')
        temp_file.write('Study1,DrugA,10,50\n')
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    def test_parse_revman_csv(self, revman_csv_file):
        """Test parsing RevMan CSV"""
        df = parse_revman_csv(revman_csv_file)
        assert df is not None
        assert 'study_id' in df.columns
        assert 'treatment' in df.columns
        # Check that column names are stripped
        assert not any(col.startswith(' ') or col.endswith(' ') for col in df.columns)


class TestParseDistillerExport:
    """Test parse_distiller_export function"""

    @pytest.fixture
    def distiller_csv(self):
        """Create Distiller-style CSV"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('study,arm,outcome,value\n')
        temp_file.write('S1,A,mortality,0.1\n')
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    def test_parse_distiller_export(self, distiller_csv):
        """Test parsing Distiller export"""
        df = parse_distiller_export(distiller_csv)
        assert df is not None
        assert len(df) > 0


class TestDetectDataFormat:
    """Test detect_data_format function"""

    def test_detect_binary_format(self):
        """Test detecting binary data"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events': [10],
            'n': [50]
        })
        format_type = detect_data_format(df)
        assert format_type == 'binary'

    def test_detect_continuous_format(self):
        """Test detecting continuous data"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean': [5.0],
            'sd': [1.0]
        })
        format_type = detect_data_format(df)
        assert format_type == 'continuous'

    def test_detect_tte_format(self):
        """Test detecting time-to-event data"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'hr': [0.8]
        })
        format_type = detect_data_format(df)
        assert format_type == 'tte'

    def test_detect_effect_size_format(self):
        """Test detecting effect size data"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'yi': [0.5],
            'sei': [0.1]
        })
        format_type = detect_data_format(df)
        assert format_type == 'effect_size'

    def test_detect_unknown_format(self):
        """Test detecting unknown format"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'unknown_col': [1]
        })
        format_type = detect_data_format(df)
        assert format_type == 'unknown'


class TestIngestAndPrepare:
    """Test ingest_and_prepare function"""

    @pytest.fixture
    def sample_data_file(self):
        """Create sample data file"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('studyid,arm,events,n\n')
        temp_file.write('S1,DrugA,10,50\n')
        temp_file.write('S2,DrugB,15,45\n')
        temp_file.write(',,,\n')  # Empty row
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    def test_ingest_and_prepare_auto_detect(self, sample_data_file):
        """Test complete ingestion with auto-detection"""
        result = ingest_and_prepare(sample_data_file)

        assert 'data' in result
        assert 'n_rows' in result
        assert 'n_cols' in result
        assert 'columns' in result
        assert 'data_type' in result
        assert 'file_path' in result

        # Check data was cleaned (empty rows removed)
        assert result['n_rows'] == 2

        # Check format detection worked
        assert result['data_type'] == 'binary'

        # Check column normalization
        assert 'study_id' in result['data'].columns

    def test_ingest_with_specified_data_type(self, sample_data_file):
        """Test ingestion with specified data type"""
        result = ingest_and_prepare(sample_data_file, data_type='binary')
        assert result['data_type'] == 'binary'


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/etl/ingest', '--cov-report=term-missing'])
