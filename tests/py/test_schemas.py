"""
Comprehensive tests for Pydantic schemas
Target: 100% coverage of schemas/evidence_object.py
"""
import pytest
from datetime import datetime
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from schemas.evidence_object import (
    ValidationProblem,
    ValidationResult,
    EvidenceRow,
    EvidenceTable,
    MetaAnalysisResult,
    HealthEconomicsResult
)


class TestValidationProblem:
    """Test ValidationProblem schema"""

    def test_validation_problem_creation(self):
        """Test creating validation problem"""
        problem = ValidationProblem(
            row=1,
            column='mean',
            problem_type='missing_value',
            message='Mean value is missing'
        )

        assert problem.row == 1
        assert problem.column == 'mean'
        assert problem.problem_type == 'missing_value'
        assert problem.message == 'Mean value is missing'

    def test_validation_problem_optional_fields(self):
        """Test validation problem with optional fields"""
        problem = ValidationProblem(
            row=None,
            column='sd',
            problem_type='negative_value',
            message='SD cannot be negative'
        )

        assert problem.row is None
        assert problem.column == 'sd'

    def test_validation_problem_serialization(self):
        """Test JSON serialization"""
        problem = ValidationProblem(
            row=5,
            column='n',
            problem_type='invalid_type',
            message='Sample size must be integer'
        )

        json_data = problem.model_dump()
        assert json_data['row'] == 5
        assert json_data['column'] == 'n'


class TestValidationResult:
    """Test ValidationResult schema"""

    def test_validation_result_valid(self):
        """Test valid validation result"""
        result = ValidationResult(
            is_valid=True,
            problems=[],
            row_count=10,
            column_count=5
        )

        assert result.is_valid is True
        assert len(result.problems) == 0
        assert result.row_count == 10
        assert result.column_count == 5

    def test_validation_result_invalid(self):
        """Test invalid validation result"""
        problems = [
            ValidationProblem(
                row=1,
                column='mean',
                problem_type='missing',
                message='Missing value'
            ),
            ValidationProblem(
                row=2,
                column='sd',
                problem_type='negative',
                message='Negative SD'
            )
        ]

        result = ValidationResult(
            is_valid=False,
            problems=problems,
            row_count=10,
            column_count=5
        )

        assert result.is_valid is False
        assert len(result.problems) == 2

    def test_validation_result_serialization(self):
        """Test JSON serialization of validation result"""
        result = ValidationResult(
            is_valid=True,
            problems=[],
            row_count=5,
            column_count=3
        )

        json_data = result.model_dump()
        assert json_data['is_valid'] is True
        assert isinstance(json_data['problems'], list)


class TestEvidenceRow:
    """Test EvidenceRow schema"""

    def test_evidence_row_continuous(self):
        """Test evidence row for continuous outcome"""
        row = EvidenceRow(
            study_id='Study1',
            treatment='DrugA',
            outcome_type='continuous',
            mean=5.2,
            sd=1.1,
            n=50
        )

        assert row.study_id == 'Study1'
        assert row.treatment == 'DrugA'
        assert row.outcome_type == 'continuous'
        assert row.mean == 5.2
        assert row.sd == 1.1
        assert row.n == 50

    def test_evidence_row_binary(self):
        """Test evidence row for binary outcome"""
        row = EvidenceRow(
            study_id='Study2',
            treatment='DrugB',
            outcome_type='binary',
            events=15,
            n=50
        )

        assert row.study_id == 'Study2'
        assert row.outcome_type == 'binary'
        assert row.events == 15
        assert row.n == 50

    def test_evidence_row_optional_fields(self):
        """Test evidence row with optional fields"""
        row = EvidenceRow(
            study_id='Study3',
            treatment='DrugC',
            outcome_type='continuous',
            mean=6.0,
            sd=1.5,
            n=45,
            year=2023,
            risk_of_bias='low',
            notes='Important study'
        )

        assert row.year == 2023
        assert row.risk_of_bias == 'low'
        assert row.notes == 'Important study'

    def test_evidence_row_validation(self):
        """Test validation in evidence row"""
        # Test that n must be positive
        with pytest.raises(Exception):  # Pydantic ValidationError
            EvidenceRow(
                study_id='Study4',
                treatment='DrugD',
                outcome_type='continuous',
                mean=5.0,
                sd=1.0,
                n=-10  # Invalid
            )


class TestEvidenceTable:
    """Test EvidenceTable schema"""

    def test_evidence_table_creation(self):
        """Test creating evidence table"""
        rows = [
            EvidenceRow(
                study_id='Study1',
                treatment='DrugA',
                outcome_type='continuous',
                mean=5.2,
                sd=1.1,
                n=50
            ),
            EvidenceRow(
                study_id='Study2',
                treatment='DrugB',
                outcome_type='continuous',
                mean=6.1,
                sd=1.3,
                n=45
            )
        ]

        table = EvidenceTable(
            rows=rows,
            outcome_type='continuous',
            outcome_name='Pain Score',
            metadata={'version': '1.0'}
        )

        assert len(table.rows) == 2
        assert table.outcome_type == 'continuous'
        assert table.outcome_name == 'Pain Score'
        assert table.metadata['version'] == '1.0'

    def test_evidence_table_with_timestamp(self):
        """Test evidence table includes timestamp"""
        table = EvidenceTable(
            rows=[],
            outcome_type='binary',
            outcome_name='Mortality'
        )

        assert table.created_at is not None
        assert isinstance(table.created_at, datetime)

    def test_evidence_table_serialization(self):
        """Test JSON serialization of evidence table"""
        rows = [
            EvidenceRow(
                study_id='Study1',
                treatment='DrugA',
                outcome_type='continuous',
                mean=5.0,
                sd=1.0,
                n=50
            )
        ]

        table = EvidenceTable(
            rows=rows,
            outcome_type='continuous',
            outcome_name='Test Outcome'
        )

        json_data = table.model_dump()
        assert 'rows' in json_data
        assert 'outcome_type' in json_data
        assert 'created_at' in json_data


class TestMetaAnalysisResult:
    """Test MetaAnalysisResult schema"""

    def test_meta_analysis_result_creation(self):
        """Test creating meta-analysis result"""
        result = MetaAnalysisResult(
            pooled_effect=0.5,
            ci_lower=0.2,
            ci_upper=0.8,
            p_value=0.001,
            i2=25.5,
            tau2=0.05,
            model='random_effects',
            n_studies=10
        )

        assert result.pooled_effect == 0.5
        assert result.ci_lower == 0.2
        assert result.ci_upper == 0.8
        assert result.p_value == 0.001
        assert result.i2 == 25.5
        assert result.tau2 == 0.05
        assert result.model == 'random_effects'
        assert result.n_studies == 10

    def test_meta_analysis_result_optional_fields(self):
        """Test meta-analysis result with optional fields"""
        result = MetaAnalysisResult(
            pooled_effect=0.3,
            ci_lower=0.1,
            ci_upper=0.5,
            p_value=0.05,
            i2=0.0,
            tau2=0.0,
            model='fixed_effects',
            n_studies=5,
            eggers_test_p=0.45,
            begg_test_p=0.50
        )

        assert result.eggers_test_p == 0.45
        assert result.begg_test_p == 0.50

    def test_meta_analysis_result_serialization(self):
        """Test JSON serialization"""
        result = MetaAnalysisResult(
            pooled_effect=0.4,
            ci_lower=0.2,
            ci_upper=0.6,
            p_value=0.01,
            i2=15.0,
            tau2=0.02,
            model='random_effects',
            n_studies=8
        )

        json_data = result.model_dump()
        assert json_data['pooled_effect'] == 0.4
        assert json_data['model'] == 'random_effects'


class TestHealthEconomicsResult:
    """Test HealthEconomicsResult schema"""

    def test_health_economics_result_creation(self):
        """Test creating health economics result"""
        result = HealthEconomicsResult(
            icer=25000.0,
            nmb=15000.0,
            total_cost_treatment=50000.0,
            total_cost_comparator=45000.0,
            total_qaly_treatment=5.5,
            total_qaly_comparator=5.0,
            probability_cost_effective=0.75
        )

        assert result.icer == 25000.0
        assert result.nmb == 15000.0
        assert result.total_cost_treatment == 50000.0
        assert result.total_qaly_treatment == 5.5
        assert result.probability_cost_effective == 0.75

    def test_health_economics_result_optional_fields(self):
        """Test health economics with optional fields"""
        result = HealthEconomicsResult(
            icer=30000.0,
            nmb=10000.0,
            total_cost_treatment=60000.0,
            total_cost_comparator=55000.0,
            total_qaly_treatment=6.0,
            total_qaly_comparator=5.5,
            probability_cost_effective=0.60,
            willingness_to_pay=50000.0,
            currency='GBP'
        )

        assert result.willingness_to_pay == 50000.0
        assert result.currency == 'GBP'

    def test_health_economics_result_serialization(self):
        """Test JSON serialization"""
        result = HealthEconomicsResult(
            icer=20000.0,
            nmb=20000.0,
            total_cost_treatment=40000.0,
            total_cost_comparator=38000.0,
            total_qaly_treatment=5.0,
            total_qaly_comparator=4.9,
            probability_cost_effective=0.85
        )

        json_data = result.model_dump()
        assert json_data['icer'] == 20000.0
        assert json_data['nmb'] == 20000.0


class TestSchemaIntegration:
    """Test schema integration and relationships"""

    def test_complete_evidence_workflow(self):
        """Test complete workflow using schemas"""
        # Create evidence rows
        rows = [
            EvidenceRow(
                study_id=f'Study{i}',
                treatment='DrugA' if i % 2 == 0 else 'DrugB',
                outcome_type='continuous',
                mean=5.0 + i * 0.1,
                sd=1.0 + i * 0.05,
                n=50 + i * 5
            )
            for i in range(1, 11)
        ]

        # Create evidence table
        table = EvidenceTable(
            rows=rows,
            outcome_type='continuous',
            outcome_name='Pain Score',
            metadata={
                'source': 'Clinical Trial Database',
                'extraction_date': '2024-01-01'
            }
        )

        assert len(table.rows) == 10
        assert table.outcome_type == 'continuous'

        # Create validation result
        validation = ValidationResult(
            is_valid=True,
            problems=[],
            row_count=10,
            column_count=7
        )

        assert validation.is_valid

        # Create meta-analysis result
        ma_result = MetaAnalysisResult(
            pooled_effect=0.45,
            ci_lower=0.25,
            ci_upper=0.65,
            p_value=0.001,
            i2=35.0,
            tau2=0.08,
            model='random_effects',
            n_studies=10
        )

        assert ma_result.pooled_effect > 0
        assert ma_result.n_studies == len(rows)

    def test_schema_json_roundtrip(self):
        """Test JSON serialization roundtrip"""
        original = EvidenceRow(
            study_id='TestStudy',
            treatment='TestDrug',
            outcome_type='continuous',
            mean=5.5,
            sd=1.2,
            n=100
        )

        # Serialize
        json_data = original.model_dump()

        # Deserialize
        restored = EvidenceRow(**json_data)

        assert restored.study_id == original.study_id
        assert restored.mean == original.mean
        assert restored.sd == original.sd


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/schemas', '--cov-report=term-missing'])
