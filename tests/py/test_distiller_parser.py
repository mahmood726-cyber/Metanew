"""
Tests for DistillerSR Export Parser
"""
import pytest
import pandas as pd
import tempfile
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.ingest import parse_distiller_export, _simplify_distiller_column


class TestDistillerSRParser:
    """Test suite for DistillerSR export parsing"""

    @pytest.fixture
    def sample_distiller_csv(self):
        """Create a sample DistillerSR CSV file"""
        content = """DistillerSR Export
Project: Meta-Analysis
Exported: 2024-01-01

RefID,Author,Year,Extraction Form -> Intervention Details -> Drug Name,Extraction Form -> Outcomes -> Primary Outcome,Risk of Bias
1,Smith et al,2020,Drug A,Mortality,Low
2,Jones et al,2019,Drug B,Mortality,Moderate
3,Lee et al,2021,Drug A,Survival,Low
"""
        # Create temporary file
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
            f.write(content)
            return f.name

    @pytest.fixture
    def sample_distiller_with_metadata(self):
        """Create DistillerSR CSV with metadata rows"""
        content = """DistillerSR Export - Data Extraction
Project: Systematic Review
Date: 2024-01-01

Study ID,Reference,Extraction Form -> Population -> Sample Size,Quality Assessment -> Overall ROB
S001,Smith 2020,200,Low Risk
S002,Jones 2019,150,High Risk
"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
            f.write(content)
            return f.name

    def test_basic_parsing(self, sample_distiller_csv):
        """Test basic DistillerSR file parsing"""
        df = parse_distiller_export(sample_distiller_csv)

        # Should have 3 data rows
        assert len(df) == 3

        # Should have standardized column names
        assert 'study_id' in df.columns  # RefID mapped to study_id
        assert 'author' in df.columns
        assert 'year' in df.columns

        # Clean up
        os.unlink(sample_distiller_csv)

    def test_column_simplification(self, sample_distiller_csv):
        """Test that nested column names are simplified"""
        df = parse_distiller_export(sample_distiller_csv)

        # Nested columns should be simplified
        # "Extraction Form -> Intervention Details -> Drug Name" -> "Intervention_Details_Drug_Name"
        simplified_cols = [col for col in df.columns if 'Drug' in col or 'drug' in col.lower()]
        assert len(simplified_cols) > 0

        # Should not contain arrows
        for col in df.columns:
            assert '->' not in col

        os.unlink(sample_distiller_csv)

    def test_metadata_row_detection(self, sample_distiller_with_metadata):
        """Test detection and skipping of metadata rows"""
        df = parse_distiller_export(sample_distiller_with_metadata)

        # Should skip metadata rows and start from actual data
        assert len(df) == 2
        assert 'study_id' in df.columns

        # First row should be S001, not metadata
        assert df.iloc[0]['study_id'] == 'S001'

        os.unlink(sample_distiller_with_metadata)

    def test_column_mapping(self, sample_distiller_with_metadata):
        """Test that common columns are mapped to standard names"""
        df = parse_distiller_export(sample_distiller_with_metadata)

        # Common mappings
        assert 'study_id' in df.columns  # Mapped from "Study ID"
        assert 'risk_of_bias' in df.columns  # Mapped from "Overall ROB"

        os.unlink(sample_distiller_with_metadata)

    def test_empty_row_removal(self):
        """Test that completely empty rows are removed"""
        content = """RefID,Author,Year
1,Smith,2020

2,Jones,2019

"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
            f.write(content)
            temp_file = f.name

        df = parse_distiller_export(temp_file)

        # Should have only 2 data rows (empty rows removed)
        assert len(df) == 2

        os.unlink(temp_file)

    def test_metadata_column_removal(self):
        """Test that metadata columns (starting with _) are removed"""
        content = """RefID,Author,_Level,_Status
1,Smith,2,Complete
2,Jones,1,In Progress
"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
            f.write(content)
            temp_file = f.name

        df = parse_distiller_export(temp_file)

        # Should not contain metadata columns
        assert '_Level' not in df.columns
        assert '_Status' not in df.columns

        # Should still have data columns
        assert 'study_id' in df.columns
        assert 'author' in df.columns

        os.unlink(temp_file)


class TestColumnSimplification:
    """Test suite for DistillerSR column name simplification"""

    def test_simple_column(self):
        """Test that simple columns are unchanged"""
        assert _simplify_distiller_column("Author") == "Author"
        assert _simplify_distiller_column("Year") == "Year"

    def test_nested_column_with_form(self):
        """Test simplification of nested columns with form names"""
        # Should remove generic form name
        result = _simplify_distiller_column("Extraction Form -> Drug Name")
        assert result == "Drug Name"

        result = _simplify_distiller_column("Quality Assessment -> Risk of Bias")
        assert result == "Risk of Bias"

    def test_deeply_nested_column(self):
        """Test simplification of deeply nested columns"""
        result = _simplify_distiller_column("Extraction Form -> Intervention Details -> Drug Name")
        # Should skip "Extraction Form", keep meaningful parts
        assert "Intervention" in result
        assert "Drug_Name" in result or "Drug Name" in result

    def test_multiple_meaningful_parts(self):
        """Test columns with multiple meaningful parts"""
        result = _simplify_distiller_column("Outcomes -> Primary -> Mortality Rate")
        # Should join meaningful parts
        assert "Outcomes" in result or "Primary" in result or "Mortality" in result

    def test_generic_term_removal(self):
        """Test that generic terms are removed"""
        result = _simplify_distiller_column("Form -> Actual Data")
        assert "Form" not in result
        assert "Actual" in result or "Data" in result


class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_file_not_found(self):
        """Test handling of non-existent file"""
        with pytest.raises(FileNotFoundError):
            parse_distiller_export("nonexistent_file.csv")

    def test_empty_file(self):
        """Test handling of empty file"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
            f.write("")
            temp_file = f.name

        # Should handle gracefully (may raise error or return empty df)
        try:
            df = parse_distiller_export(temp_file)
            assert len(df) == 0
        except Exception:
            pass  # Empty file may raise error, which is acceptable

        os.unlink(temp_file)

    def test_non_distiller_csv(self):
        """Test parsing of regular CSV (not DistillerSR format)"""
        content = """study_id,author,year
1,Smith,2020
2,Jones,2019
"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
            f.write(content)
            temp_file = f.name

        df = parse_distiller_export(temp_file)

        # Should still parse successfully
        assert len(df) == 2
        assert 'study_id' in df.columns

        os.unlink(temp_file)

    def test_unicode_handling(self):
        """Test handling of unicode characters"""
        content = """RefID,Author,Year
1,Müller et al,2020
2,José García,2019
3,李明,2021
"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv', encoding='utf-8') as f:
            f.write(content)
            temp_file = f.name

        df = parse_distiller_export(temp_file)

        # Should handle unicode characters
        assert len(df) == 3
        assert 'Müller' in df['author'].values[0]

        os.unlink(temp_file)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
