"""
Comprehensive tests for Pydantic schemas - 100% Coverage
Target: 100% coverage of schemas/evidence_object.py
"""
import pytest
from datetime import datetime
import sys
from pathlib import Path
import tempfile
import json

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from schemas.evidence_object import (
    ValidationProblem,
    ValidationResult,
    Study,
    Observation,
    PairwiseSpec,
    NMASpec,
    DoseResponseSpec,
    PairwiseResult,
    NMAResult,
    DoseResponseResult,
    EconomicParameters,
    EconomicResult,
    Artifact,
    AuditEntry,
    Protocol,
    EvidenceObject
)


class TestValidationProblem:
    """Test ValidationProblem schema"""

    def test_validation_problem_creation(self):
        """Test creating validation problem"""
        problem = ValidationProblem(
            severity='error',
            field='mean',
            message='Mean value is missing'
        )
        assert problem.severity == 'error'
        assert problem.field == 'mean'
        assert problem.message == 'Mean value is missing'

    def test_validation_problem_with_study_id(self):
        """Test validation problem with study ID"""
        problem = ValidationProblem(
            severity='warning',
            field='sd',
            message='SD is negative',
            study_id='Study1'
        )
        assert problem.study_id == 'Study1'


class TestValidationResult:
    """Test ValidationResult schema"""

    def test_validation_result_valid(self):
        """Test valid validation result"""
        result = ValidationResult(
            is_valid=True,
            problems=[],
            summary={'errors': 0, 'warnings': 0}
        )
        assert result.is_valid is True
        assert len(result.problems) == 0

    def test_validation_result_invalid(self):
        """Test invalid validation result"""
        problems = [
            ValidationProblem(severity='error', field='mean', message='Missing'),
            ValidationProblem(severity='warning', field='sd', message='Large value')
        ]
        result = ValidationResult(
            is_valid=False,
            problems=problems,
            summary={'errors': 1, 'warnings': 1}
        )
        assert result.is_valid is False
        assert len(result.problems) == 2


class TestStudy:
    """Test Study schema"""

    def test_study_minimal(self):
        """Test Study with minimal fields"""
        study = Study(study_id='S1')
        assert study.study_id == 'S1'

    def test_study_full(self):
        """Test Study with all fields"""
        study = Study(
            study_id='S1',
            author='Smith et al',
            year=2023,
            design='RCT',
            risk_of_bias='low',
            country='UK',
            population='Adults',
            intervention='DrugA',
            comparator='Placebo',
            metadata={'notes': 'Important study'}
        )
        assert study.author == 'Smith et al'
        assert study.year == 2023
        assert study.metadata['notes'] == 'Important study'


class TestObservation:
    """Test Observation schema"""

    def test_observation_effect_size(self):
        """Test Observation with effect size"""
        obs = Observation(
            obs_id='obs1',
            study_id='S1',
            outcome='mortality',
            treatment='DrugA',
            effect_measure='RR',
            yi=0.5,
            sei=0.1
        )
        assert obs.yi == 0.5
        assert obs.sei == 0.1

    def test_observation_raw_binary(self):
        """Test Observation with raw binary data"""
        obs = Observation(
            obs_id='obs1',
            study_id='S1',
            outcome='events',
            treatment='DrugA',
            effect_measure='RR',
            events=10,
            n=50
        )
        assert obs.events == 10
        assert obs.n == 50

    def test_observation_raw_continuous(self):
        """Test Observation with continuous data"""
        obs = Observation(
            obs_id='obs1',
            study_id='S1',
            outcome='pain_score',
            treatment='DrugA',
            effect_measure='MD',
            mean=5.2,
            sd=1.1
        )
        assert obs.mean == 5.2
        assert obs.sd == 1.1


class TestPairwiseSpec:
    """Test PairwiseSpec schema"""

    def test_pairwise_spec(self):
        """Test pairwise specification"""
        spec = PairwiseSpec(
            outcome='mortality',
            method='REML',
            measure='RR',
            interventions=['DrugA', 'Placebo']
        )
        assert spec.outcome == 'mortality'
        assert spec.method == 'REML'


class TestNMASpec:
    """Test NMASpec schema"""

    def test_nma_spec(self):
        """Test NMA specification"""
        spec = NMASpec(
            outcome='mortality',
            reference_treatment='Placebo',
            method='frequentist',
            model='random'
        )
        assert spec.reference_treatment == 'Placebo'
        assert spec.inconsistency_check is True


class TestDoseResponseSpec:
    """Test DoseResponseSpec schema"""

    def test_dose_response_spec(self):
        """Test dose-response specification"""
        spec = DoseResponseSpec(
            outcome='mortality',
            dose_var='dose_mg',
            dose_unit='mg',
            knots=3,
            method='rcs'
        )
        assert spec.dose_var == 'dose_mg'
        assert spec.knots == 3


class TestPairwiseResult:
    """Test PairwiseResult schema"""

    def test_pairwise_result(self):
        """Test pairwise result"""
        result = PairwiseResult(
            pooled_effect=0.5,
            ci_lower=0.3,
            ci_upper=0.7,
            se=0.1,
            p_value=0.001,
            i_squared=25.0,
            tau_squared=0.05,
            q_statistic=15.5,
            n_studies=10
        )
        assert result.pooled_effect == 0.5
        assert result.n_studies == 10


class TestNMAResult:
    """Test NMAResult schema"""

    def test_nma_result(self):
        """Test NMA result"""
        result = NMAResult(
            league_table={'DrugA_vs_Placebo': 0.8},
            rankings={'DrugA': 1, 'DrugB': 2}
        )
        assert 'DrugA' in result.rankings


class TestDoseResponseResult:
    """Test DoseResponseResult schema"""

    def test_dose_response_result(self):
        """Test dose-response result"""
        result = DoseResponseResult(
            spline_data={'x': [1, 2], 'y': [0.5, 0.6]},
            prediction_intervals={'lower': [0.4], 'upper': [0.7]},
            n_studies=5
        )
        assert result.n_studies == 5


class TestEconomicParameters:
    """Test EconomicParameters schema"""

    def test_economic_parameters_defaults(self):
        """Test economic parameters with defaults"""
        params = EconomicParameters()
        assert params.country == 'UK'
        assert params.wtp_threshold == 20000.0

    def test_economic_parameters_custom(self):
        """Test custom economic parameters"""
        params = EconomicParameters(
            country='US',
            currency='USD',
            wtp_threshold=50000.0,
            discount_rate=0.03
        )
        assert params.country == 'US'
        assert params.currency == 'USD'


class TestEconomicResult:
    """Test EconomicResult schema"""

    def test_economic_result(self):
        """Test economic result"""
        result = EconomicResult(
            icer=25000.0,
            incremental_costs=5000.0,
            incremental_qalys=0.2
        )
        assert result.icer == 25000.0


class TestArtifact:
    """Test Artifact schema"""

    def test_artifact(self):
        """Test artifact creation"""
        artifact = Artifact(
            artifact_id='art1',
            type='pdf',
            path='/path/to/report.pdf'
        )
        assert artifact.type == 'pdf'
        assert isinstance(artifact.created_at, datetime)


class TestAuditEntry:
    """Test AuditEntry schema"""

    def test_audit_entry(self):
        """Test audit entry"""
        entry = AuditEntry(
            action='data_upload',
            user='user1',
            details={'file': 'data.csv'}
        )
        assert entry.action == 'data_upload'
        assert isinstance(entry.timestamp, datetime)


class TestProtocol:
    """Test Protocol schema"""

    def test_protocol(self):
        """Test protocol creation"""
        protocol = Protocol(
            protocol_id='prot1',
            title='Meta-analysis of Drug A',
            population='Adults',
            intervention='Drug A',
            comparator='Placebo',
            outcomes=['mortality', 'adverse_events']
        )
        assert protocol.protocol_id == 'prot1'
        assert len(protocol.outcomes) == 2


class TestEvidenceObject:
    """Test EvidenceObject schema"""

    def test_evidence_object_minimal(self):
        """Test evidence object with minimal fields"""
        evo = EvidenceObject(
            evidence_id='evo1',
            version='1.0.0'
        )
        assert evo.evidence_id == 'evo1'
        assert isinstance(evo.created_at, datetime)

    def test_evidence_object_with_studies(self):
        """Test evidence object with studies"""
        studies = [
            Study(study_id='S1', author='Smith'),
            Study(study_id='S2', author='Jones')
        ]
        evo = EvidenceObject(
            evidence_id='evo1',
            studies=studies
        )
        assert len(evo.studies) == 2

    def test_compute_hash(self):
        """Test hash computation"""
        evo = EvidenceObject(evidence_id='evo1')
        hash_value = evo.compute_hash()
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64  # SHA-256 hex

    def test_update_hash(self):
        """Test hash update"""
        evo = EvidenceObject(evidence_id='evo1')
        evo.update_hash()
        assert evo.content_hash is not None

    def test_add_audit_entry(self):
        """Test adding audit entry"""
        evo = EvidenceObject(evidence_id='evo1')
        evo.update_hash()
        initial_hash = evo.content_hash

        evo.add_audit_entry('data_update', user='user1', details={'action': 'upload'})

        assert len(evo.audit_trail) == 1
        assert evo.audit_trail[0].action == 'data_update'
        assert evo.audit_trail[0].hash_before == initial_hash
        assert evo.content_hash != initial_hash  # Hash should change

    def test_to_json(self):
        """Test saving to JSON"""
        evo = EvidenceObject(evidence_id='evo1')
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
        temp_file.close()

        try:
            evo.to_json(temp_file.name)
            assert Path(temp_file.name).exists()

            with open(temp_file.name) as f:
                data = json.load(f)
                assert data['evidence_id'] == 'evo1'
        finally:
            Path(temp_file.name).unlink()

    def test_from_json(self):
        """Test loading from JSON"""
        evo = EvidenceObject(evidence_id='evo1', version='2.0.0')
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
        temp_file.close()

        try:
            evo.to_json(temp_file.name)
            loaded = EvidenceObject.from_json(temp_file.name)
            assert loaded.evidence_id == 'evo1'
            assert loaded.version == '2.0.0'
        finally:
            Path(temp_file.name).unlink()

    def test_complete_evidence_workflow(self):
        """Test complete evidence object workflow"""
        # Create protocol
        protocol = Protocol(
            protocol_id='prot1',
            title='Test MA',
            population='Adults',
            intervention='DrugA',
            comparator='Placebo',
            outcomes=['mortality']
        )

        # Create studies
        studies = [
            Study(study_id='S1', author='Smith', year=2020),
            Study(study_id='S2', author='Jones', year=2021)
        ]

        # Create observations
        observations = [
            Observation(
                obs_id='obs1',
                study_id='S1',
                outcome='mortality',
                treatment='DrugA',
                effect_measure='RR',
                yi=0.5,
                sei=0.1
            )
        ]

        # Create evidence object
        evo = EvidenceObject(
            evidence_id='evo1',
            protocol=protocol,
            studies=studies,
            observations=observations
        )

        # Update hash
        evo.update_hash()

        # Add audit entry
        evo.add_audit_entry('created', user='researcher1')

        assert evo.protocol.protocol_id == 'prot1'
        assert len(evo.studies) == 2
        assert len(evo.observations) == 1
        assert evo.content_hash is not None
        assert len(evo.audit_trail) == 1


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/schemas', '--cov-report=term-missing'])
