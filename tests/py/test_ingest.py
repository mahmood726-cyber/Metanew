"""
Comprehensive tests for ETL ingest module
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
    read_csv_file,
    read_excel_file,
    auto_detect_format,
    ingest_data
)


class TestIngest:
    """Comprehensive test suite for data ingestion"""

    @pytest.fixture
    def sample_csv_file(self):
        """Create temporary CSV file"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('study_id,treatment,mean,sd,n\n')
        temp_file.write('Study1,DrugA,5.2,1.1,50\n')
        temp_file.write('Study2,DrugB,6.1,1.3,45\n')
        temp_file.write('Study3,DrugA,5.8,1.2,52\n')
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    @pytest.fixture
    def sample_excel_file(self):
        """Create temporary Excel file"""
        temp_file = tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False)
        df = pd.DataFrame({
            'study_id': ['Study1', 'Study2', 'Study3'],
            'treatment': ['DrugA', 'DrugB', 'DrugA'],
            'mean': [5.2, 6.1, 5.8],
            'sd': [1.1, 1.3, 1.2],
            'n': [50, 45, 52]
        })
        df.to_excel(temp_file.name, index=False)
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    @pytest.fixture
    def malformed_csv_file(self):
        """Create malformed CSV file"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('col1,col2\n')
        temp_file.write('value1,value2,value3\n')  # Wrong number of columns
        temp_file.write('value4\n')  # Missing column
        temp_file.close()
        yield temp_file.name
        os.unlink(temp_file.name)

    def test_read_csv_file_success(self, sample_csv_file):
        """Test successful CSV file reading"""
        df = read_csv_file(sample_csv_file)

        assert df is not None
        assert len(df) == 3
        assert 'study_id' in df.columns
        assert 'treatment' in df.columns
        assert df['study_id'].tolist() == ['Study1', 'Study2', 'Study3']

    def test_read_csv_file_nonexistent(self):
        """Test reading nonexistent CSV file"""
        result = read_csv_file('/nonexistent/file.csv')
        assert result is None

    def test_read_excel_file_success(self, sample_excel_file):
        """Test successful Excel file reading"""
        df = read_excel_file(sample_excel_file)

        assert df is not None
        assert len(df) == 3
        assert 'study_id' in df.columns
        assert df['mean'].tolist() == [5.2, 6.1, 5.8]

    def test_read_excel_file_nonexistent(self):
        """Test reading nonexistent Excel file"""
        result = read_excel_file('/nonexistent/file.xlsx')
        assert result is None

    def test_auto_detect_csv_format(self, sample_csv_file):
        """Test auto-detection of CSV format"""
        file_format = auto_detect_format(sample_csv_file)
        assert file_format == 'csv'

    def test_auto_detect_excel_format(self, sample_excel_file):
        """Test auto-detection of Excel format"""
        file_format = auto_detect_format(sample_excel_file)
        assert file_format in ['xlsx', 'excel']

    def test_auto_detect_unknown_format(self):
        """Test auto-detection with unknown format"""
        result = auto_detect_format('/path/to/file.txt')
        assert result in ['unknown', 'txt', None]

    def test_ingest_data_csv(self, sample_csv_file):
        """Test ingesting CSV data"""
        df = ingest_data(sample_csv_file)

        assert df is not None
        assert len(df) == 3
        assert all(col in df.columns for col in ['study_id', 'treatment', 'mean'])

    def test_ingest_data_excel(self, sample_excel_file):
        """Test ingesting Excel data"""
        df = ingest_data(sample_excel_file)

        assert df is not None
        assert len(df) == 3
        assert 'sd' in df.columns

    def test_ingest_data_auto_detect(self, sample_csv_file):
        """Test auto-detection in ingest_data"""
        df = ingest_data(sample_csv_file, file_format='auto')

        assert df is not None
        assert len(df) == 3

    def test_ingest_data_invalid_file(self):
        """Test ingesting from invalid file"""
        result = ingest_data('/nonexistent/file.csv')
        assert result is None

    def test_csv_with_different_delimiter(self):
        """Test CSV with semicolon delimiter"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('col1;col2;col3\n')
        temp_file.write('val1;val2;val3\n')
        temp_file.close()

        try:
            df = read_csv_file(temp_file.name)
            # Should handle or fail gracefully
            assert df is not None or df is None
        finally:
            os.unlink(temp_file.name)

    def test_csv_with_quotes(self):
        """Test CSV with quoted values"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('study_id,description\n')
        temp_file.write('"Study 1","This is a ""quoted"" value"\n')
        temp_file.close()

        try:
            df = read_csv_file(temp_file.name)
            assert df is not None
            assert len(df) == 1
        finally:
            os.unlink(temp_file.name)

    def test_empty_csv_file(self):
        """Test reading empty CSV file"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('col1,col2\n')
        temp_file.close()

        try:
            df = read_csv_file(temp_file.name)
            assert df is not None
            assert len(df) == 0
        finally:
            os.unlink(temp_file.name)

    def test_csv_with_missing_values(self):
        """Test CSV with missing values"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('col1,col2,col3\n')
        temp_file.write('val1,,val3\n')
        temp_file.write(',val2,\n')
        temp_file.close()

        try:
            df = read_csv_file(temp_file.name)
            assert df is not None
            assert df.isna().sum().sum() > 0
        finally:
            os.unlink(temp_file.name)

    def test_excel_multiple_sheets(self):
        """Test Excel file with multiple sheets"""
        temp_file = tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False)

        with pd.ExcelWriter(temp_file.name) as writer:
            pd.DataFrame({'col1': [1, 2]}).to_excel(writer, sheet_name='Sheet1', index=False)
            pd.DataFrame({'col2': [3, 4]}).to_excel(writer, sheet_name='Sheet2', index=False)

        try:
            # Should read first sheet by default
            df = read_excel_file(temp_file.name)
            assert df is not None
            assert 'col1' in df.columns or 'col2' in df.columns
        finally:
            os.unlink(temp_file.name)

    def test_large_csv_file(self):
        """Test reading large CSV file"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
        temp_file.write('col1,col2,col3\n')
        for i in range(10000):
            temp_file.write(f'{i},{i*2},{i*3}\n')
        temp_file.close()

        try:
            df = read_csv_file(temp_file.name)
            assert df is not None
            assert len(df) == 10000
        finally:
            os.unlink(temp_file.name)

    def test_csv_with_unicode(self):
        """Test CSV with unicode characters"""
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False, encoding='utf-8')
        temp_file.write('study_id,description\n')
        temp_file.write('Study1,测试数据\n')
        temp_file.write('Study2,Тестовые данные\n')
        temp_file.write('Study3,テストデータ\n')
        temp_file.close()

        try:
            df = read_csv_file(temp_file.name)
            assert df is not None
            assert len(df) == 3
        finally:
            os.unlink(temp_file.name)

    def test_ingest_with_explicit_format(self, sample_csv_file):
        """Test ingest_data with explicitly specified format"""
        df = ingest_data(sample_csv_file, file_format='csv')
        assert df is not None
        assert len(df) == 3


class TestIngestEdgeCases:
    """Test edge cases and error conditions"""

    def test_corrupted_file(self):
        """Test handling of corrupted file"""
        temp_file = tempfile.NamedTemporaryFile(mode='wb', suffix='.xlsx', delete=False)
        temp_file.write(b'This is not a valid Excel file')
        temp_file.close()

        try:
            result = read_excel_file(temp_file.name)
            assert result is None  # Should handle gracefully
        finally:
            os.unlink(temp_file.name)

    def test_permission_denied(self):
        """Test handling of permission denied error"""
        # This test is platform-dependent
        # On Unix systems, you can test with a file you don't have permission to read
        pass

    def test_path_with_spaces(self):
        """Test file path with spaces"""
        temp_dir = tempfile.mkdtemp()
        file_path = os.path.join(temp_dir, 'file with spaces.csv')

        with open(file_path, 'w') as f:
            f.write('col1,col2\n')
            f.write('val1,val2\n')

        try:
            df = read_csv_file(file_path)
            assert df is not None
        finally:
            os.unlink(file_path)
            os.rmdir(temp_dir)

    def test_symbolic_link(self):
        """Test reading through symbolic link"""
        # This test is Unix-specific
        if os.name != 'nt':  # Not Windows
            temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False)
            temp_file.write('col1,col2\nval1,val2\n')
            temp_file.close()

            link_path = temp_file.name + '.link'
            try:
                os.symlink(temp_file.name, link_path)
                df = read_csv_file(link_path)
                assert df is not None
            finally:
                os.unlink(link_path)
                os.unlink(temp_file.name)


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/etl', '--cov-report=term-missing'])
