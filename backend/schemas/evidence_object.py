"""
EvidenceObject Schema - Core data structure for EvidenceOS PRIME
Handles meta-analysis, NMA, dose-response, and health economics data
"""
from typing import List, Dict, Optional, Any, Literal
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
import hashlib
import json


class Study(BaseModel):
    """Individual study data"""
    study_id: str
    author: Optional[str] = None
    year: Optional[int] = None
    design: Optional[str] = None
    risk_of_bias: Optional[str] = None
    country: Optional[str] = None
    population: Optional[str] = None
    intervention: Optional[str] = None
    comparator: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class Observation(BaseModel):
    """Individual observation/arm data"""
    obs_id: str
    study_id: str
    outcome: str
    treatment: str
    effect_measure: str  # "OR", "RR", "HR", "MD", "SMD"

    # Effect size data
    yi: Optional[float] = None  # Effect size
    sei: Optional[float] = None  # Standard error
    vi: Optional[float] = None  # Variance

    # Raw data for effect size calculation
    events: Optional[int] = None
    n: Optional[int] = None
    mean: Optional[float] = None
    sd: Optional[float] = None

    # Dose-response
    dose: Optional[float] = None
    dose_unit: Optional[str] = None

    # Time-to-event
    hr: Optional[float] = None
    ci_lower: Optional[float] = None
    ci_upper: Optional[float] = None

    metadata: Dict[str, Any] = Field(default_factory=dict)


class PairwiseSpec(BaseModel):
    """Specification for pairwise meta-analysis"""
    outcome: str
    method: str = "REML"  # REML, DL, ML, EB
    measure: str  # OR, RR, HR, MD, SMD
    interventions: List[str]
    subgroup_var: Optional[str] = None
    moderators: List[str] = Field(default_factory=list)


class NMASpec(BaseModel):
    """Specification for network meta-analysis"""
    outcome: str
    reference_treatment: str
    method: str = "frequentist"  # frequentist, bayesian
    model: str = "random"  # fixed, random
    inconsistency_check: bool = True


class DoseResponseSpec(BaseModel):
    """Specification for dose-response meta-analysis"""
    outcome: str
    dose_var: str
    dose_unit: str
    knots: int = 3
    method: str = "rcs"  # restricted cubic spline


class PairwiseResult(BaseModel):
    """Results from pairwise meta-analysis"""
    pooled_effect: float
    ci_lower: float
    ci_upper: float
    se: float
    p_value: float
    i_squared: float
    tau_squared: float
    q_statistic: float
    n_studies: int
    forest_data: Dict[str, Any] = Field(default_factory=dict)
    funnel_data: Dict[str, Any] = Field(default_factory=dict)
    egger_test: Optional[Dict[str, float]] = None


class NMAResult(BaseModel):
    """Results from network meta-analysis"""
    league_table: Dict[str, Any]
    rankings: Dict[str, Any]
    tau_squared: Optional[float] = None
    i_squared: Optional[float] = None
    inconsistency: Optional[Dict[str, Any]] = None
    network_plot: Dict[str, Any] = Field(default_factory=dict)


class DoseResponseResult(BaseModel):
    """Results from dose-response meta-analysis"""
    spline_data: Dict[str, Any]
    prediction_intervals: Dict[str, Any]
    n_studies: int
    p_nonlinearity: Optional[float] = None


class EconomicParameters(BaseModel):
    """Health economic parameters"""
    country: str = "UK"
    currency: str = "GBP"
    wtp_threshold: float = 20000.0
    wtp_range: List[float] = Field(default=[0, 50000])
    discount_rate: float = 0.035
    time_horizon: int = 10  # years

    # Markov state utilities
    utility_stable: float = 0.8
    utility_progressed: float = 0.5
    utility_dead: float = 0.0

    # Costs
    cost_stable: float = 1000.0
    cost_progressed: float = 5000.0
    cost_treatment: float = 10000.0
    cost_comparator: float = 2000.0

    # Transition probabilities from MA
    hr_progression: Optional[float] = None
    hr_death: Optional[float] = None

    # PSA parameters
    n_iterations: int = 1000
    seed: Optional[int] = 42


class EconomicResult(BaseModel):
    """Health economic analysis results"""
    # Deterministic results
    icer: float
    incremental_costs: float
    incremental_qalys: float

    # PSA results
    ce_plane: Dict[str, Any] = Field(default_factory=dict)
    ceac: Dict[str, Any] = Field(default_factory=dict)  # Cost-effectiveness acceptability curve
    ceaf: Optional[Dict[str, Any]] = None  # Frontier
    evpi: Dict[str, Any] = Field(default_factory=dict)  # Expected value of perfect information
    evppi: Optional[Dict[str, Any]] = None  # Partial EVPI

    # Budget impact
    budget_impact: Optional[Dict[str, Any]] = None

    # Sensitivity
    tornado: Optional[Dict[str, Any]] = None


class Artifact(BaseModel):
    """Generated artifact (report, plot, etc.)"""
    artifact_id: str
    type: str  # "word", "pdf", "pptx", "plot", "table", "json"
    path: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    metadata: Dict[str, Any] = Field(default_factory=dict)


class AuditEntry(BaseModel):
    """Audit trail entry"""
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    action: str
    user: Optional[str] = None
    details: Dict[str, Any] = Field(default_factory=dict)
    hash_before: Optional[str] = None
    hash_after: Optional[str] = None


class Protocol(BaseModel):
    """Research protocol (PICO)"""
    protocol_id: str
    title: str
    population: str
    intervention: str
    comparator: str
    outcomes: List[str]
    study_design: Optional[str] = None
    search_strategy: Optional[str] = None
    inclusion_criteria: List[str] = Field(default_factory=list)
    exclusion_criteria: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    version: str = "1.0"


class EvidenceObject(BaseModel):
    """
    Complete evidence package for a meta-analysis run
    Includes all inputs, specifications, results, and audit trail
    """
    # Metadata
    evidence_id: str
    version: str = "1.0.0"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # Protocol
    protocol: Optional[Protocol] = None

    # Input data
    studies: List[Study] = Field(default_factory=list)
    observations: List[Observation] = Field(default_factory=list)

    # Analysis specifications
    pairwise_specs: List[PairwiseSpec] = Field(default_factory=list)
    nma_specs: List[NMASpec] = Field(default_factory=list)
    dose_response_specs: List[DoseResponseSpec] = Field(default_factory=list)

    # Results
    pairwise_results: Dict[str, PairwiseResult] = Field(default_factory=dict)
    nma_results: Dict[str, NMAResult] = Field(default_factory=dict)
    dose_response_results: Dict[str, DoseResponseResult] = Field(default_factory=dict)

    # Economics
    economic_params: Optional[EconomicParameters] = None
    economic_results: Optional[EconomicResult] = None

    # Artifacts and audit
    artifacts: List[Artifact] = Field(default_factory=list)
    audit_trail: List[AuditEntry] = Field(default_factory=list)

    # Content hash for integrity
    content_hash: Optional[str] = None

    def compute_hash(self) -> str:
        """Compute content hash for reproducibility"""
        # Exclude hash and timestamps from hash computation
        content = self.model_dump(exclude={'content_hash', 'created_at', 'updated_at', 'audit_trail'})
        content_str = json.dumps(content, sort_keys=True, default=str)
        return hashlib.sha256(content_str.encode()).hexdigest()

    def update_hash(self):
        """Update the content hash"""
        self.content_hash = self.compute_hash()
        self.updated_at = datetime.utcnow()

    def add_audit_entry(self, action: str, user: Optional[str] = None, details: Dict[str, Any] = None):
        """Add an audit trail entry"""
        hash_before = self.content_hash
        entry = AuditEntry(
            action=action,
            user=user,
            details=details or {},
            hash_before=hash_before
        )
        self.audit_trail.append(entry)
        self.update_hash()
        entry.hash_after = self.content_hash

    def to_json(self, path: str):
        """Save to JSON file"""
        with open(path, 'w') as f:
            json.dump(self.model_dump(), f, indent=2, default=str)

    @classmethod
    def from_json(cls, path: str) -> "EvidenceObject":
        """Load from JSON file"""
        with open(path, 'r') as f:
            data = json.load(f)
        return cls(**data)


class ValidationProblem(BaseModel):
    """Data validation problem"""
    severity: Literal["error", "warning", "info"]
    field: str
    message: str
    study_id: Optional[str] = None
    obs_id: Optional[str] = None


class ValidationResult(BaseModel):
    """Result of data validation"""
    is_valid: bool
    problems: List[ValidationProblem] = Field(default_factory=list)
    summary: Dict[str, int] = Field(default_factory=dict)
