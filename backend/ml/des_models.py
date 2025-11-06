"""
Discrete Event Simulation (DES) Data Models

Core data structures for health economics discrete event simulation.

Models:
- Event: Individual simulation events
- Resource: Healthcare resources (beds, staff, equipment)
- PatientState: Health states in Markov models
- PatientPathway: Complete patient journey through states
- Cost: Direct, indirect, and opportunity costs
- QALY: Quality-adjusted life years
- SimulationConfig: Simulation parameters
- SimulationResults: Complete simulation outputs

Architecture:
    Event Queue → DES Engine → State Manager → Cost/QALY Accumulator → Results

Usage:
    # Create simulation configuration
    config = SimulationConfig(
        time_horizon=10,  # years
        n_patients=1000,
        discount_rate=0.035
    )

    # Define patient states
    states = [
        PatientState("Healthy", utility=1.0, cost_per_cycle=100),
        PatientState("Disease", utility=0.7, cost_per_cycle=5000),
        PatientState("Death", utility=0.0, cost_per_cycle=0, absorbing=True)
    ]

    # Define transitions
    pathway = PatientPathway(states=states, initial_state="Healthy")
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
import numpy as np


# ==================== ENUMS ====================

class EventType(Enum):
    """Types of events in the simulation"""
    PATIENT_ARRIVAL = "patient_arrival"
    TREATMENT_START = "treatment_start"
    TREATMENT_END = "treatment_end"
    STATE_TRANSITION = "state_transition"
    RESOURCE_AVAILABLE = "resource_available"
    RESOURCE_UNAVAILABLE = "resource_unavailable"
    RESOURCE_REQUEST = "resource_request"
    ADVERSE_EVENT = "adverse_event"
    DEATH = "death"
    CYCLE_END = "cycle_end"
    SIMULATION_END = "simulation_end"


class ResourceType(Enum):
    """Types of healthcare resources"""
    BED = "bed"
    ICU_BED = "icu_bed"
    NURSE = "nurse"
    DOCTOR = "doctor"
    SPECIALIST = "specialist"
    STAFF = "staff"
    EQUIPMENT = "equipment"
    MEDICATION = "medication"
    SURGERY_ROOM = "surgery_room"


class CostCategory(Enum):
    """Categories of costs"""
    DIRECT_MEDICAL = "direct_medical"  # Healthcare costs
    DIRECT_NON_MEDICAL = "direct_non_medical"  # Transport, accommodation
    INDIRECT = "indirect"  # Productivity loss
    OPPORTUNITY = "opportunity"  # Foregone alternatives
    CAPITAL = "capital"  # Equipment, buildings
    OPERATIONAL = "operational"  # Staff, utilities


class InterventionType(Enum):
    """Types of interventions"""
    DRUG = "drug"
    SURGERY = "surgery"
    DEVICE = "device"
    PROCEDURE = "procedure"
    BEHAVIORAL = "behavioral"
    SCREENING = "screening"
    PREVENTION = "prevention"
    TREATMENT = "treatment"
    POLICY = "policy"


# ==================== CORE DATA STRUCTURES ====================

@dataclass
class Event:
    """
    Single discrete event in the simulation

    Events are processed in chronological order from the event queue.
    Each event triggers state changes and potentially generates new events.
    """
    time: float  # Simulation time (years, days, or cycles)
    event_type: EventType
    patient_id: str
    data: Dict[str, Any] = field(default_factory=dict)
    priority: int = 0  # Higher priority processed first (if same time)

    def __lt__(self, other):
        """Compare events for priority queue ordering"""
        if self.time != other.time:
            return self.time < other.time
        return self.priority > other.priority  # Higher priority first

    def __repr__(self):
        return f"Event(t={self.time:.2f}, type={self.event_type.value}, patient={self.patient_id})"


@dataclass
class Resource:
    """
    Healthcare resource with capacity and costs

    Resources can be consumed, released, and have associated costs.
    """
    resource_id: str
    resource_type: ResourceType
    capacity: int  # Total capacity
    available: int  # Currently available
    cost_per_unit: float  # Cost per unit per time period
    cost_per_use: float = 0.0  # One-time cost per use
    resource_name: Optional[str] = None  # Optional human-readable name

    # Utilization tracking
    total_uses: int = 0
    total_time_used: float = 0.0
    queue_length: int = 0  # Number waiting for resource

    def is_available(self, units: int = 1) -> bool:
        """Check if resource is available"""
        return self.available >= units

    def acquire(self, units: int = 1) -> bool:
        """Acquire resource units"""
        if self.is_available(units):
            self.available -= units
            self.total_uses += 1
            return True
        return False

    def release(self, units: int = 1):
        """Release resource units"""
        self.available = min(self.available + units, self.capacity)

    def utilization_rate(self) -> float:
        """Calculate resource utilization rate"""
        if self.capacity == 0:
            return 0.0
        return 1.0 - (self.available / self.capacity)

    def get_cost(self, duration: float = 0.0, uses: int = 0) -> float:
        """Calculate total cost for duration and/or uses"""
        return (self.cost_per_unit * duration) + (self.cost_per_use * uses)


@dataclass
class PatientState:
    """
    Health state in a Markov model

    Represents a discrete health state with associated utility and costs.
    Patients transition between states based on transition probabilities.
    """
    state_id: str
    state_name: str
    utility: float  # Quality of life (0-1)
    cost_per_cycle: float  # Cost per time period in this state

    # Transition probabilities to other states
    transition_probabilities: Dict[str, float] = field(default_factory=dict)

    # State characteristics
    absorbing: bool = False  # Can't leave this state (e.g., Death)
    tunnel: bool = False  # Must leave after one cycle
    duration_mean: Optional[float] = None  # Average duration in state
    duration_sd: Optional[float] = None  # Standard deviation of duration

    # Resources required while in state
    required_resources: Dict[ResourceType, int] = field(default_factory=dict)

    def __post_init__(self):
        """Validate state configuration"""
        assert 0.0 <= self.utility <= 1.0, "Utility must be between 0 and 1"
        assert self.cost_per_cycle >= 0, "Cost must be non-negative"

        # Validate transition probabilities sum to ≤ 1
        if self.transition_probabilities:
            total_prob = sum(self.transition_probabilities.values())
            assert total_prob <= 1.0, f"Transition probabilities sum to {total_prob} > 1.0"

    def sample_next_state(self, current_time: float = 0.0) -> Tuple[str, float]:
        """
        Sample next state based on transition probabilities

        Returns:
            (next_state_id, time_to_transition)
        """
        if self.absorbing:
            return self.state_id, float('inf')

        # Sample next state
        states = list(self.transition_probabilities.keys())
        probs = list(self.transition_probabilities.values())

        # Add "stay in current state" probability
        stay_prob = 1.0 - sum(probs)
        if stay_prob > 0:
            states.append(self.state_id)
            probs.append(stay_prob)

        next_state = np.random.choice(states, p=probs)

        # Sample time to transition
        if self.duration_mean:
            # Use specified duration distribution
            time_to_transition = max(0.0, np.random.normal(self.duration_mean, self.duration_sd or 0.1))
        else:
            # Default: one cycle
            time_to_transition = 1.0

        return next_state, time_to_transition


@dataclass
class PatientPathway:
    """
    Complete patient journey through health states

    Defines the structure of possible states and transitions.
    """
    pathway_id: str
    pathway_name: str
    states: List[PatientState]
    initial_state: str  # Starting state ID
    intervention: Optional[str] = None  # Treatment applied

    # Pathway characteristics
    cycle_length: float = 1.0  # Years per cycle
    time_horizon: float = 10.0  # Total simulation time (years)

    def __post_init__(self):
        """Validate pathway configuration"""
        state_ids = [s.state_id for s in self.states]
        assert self.initial_state in state_ids, f"Initial state {self.initial_state} not in states"

        # Validate all transition targets exist
        for state in self.states:
            for target in state.transition_probabilities.keys():
                assert target in state_ids, f"Transition target {target} not in states"

    def get_state(self, state_id: str) -> Optional[PatientState]:
        """Get state by ID"""
        for state in self.states:
            if state.state_id == state_id:
                return state
        return None


@dataclass
class Patient:
    """
    Individual patient in the simulation

    Tracks patient state, history, costs, and QALYs.
    """
    patient_id: str
    current_state: str
    pathway: PatientPathway

    # Time tracking
    current_time: float = 0.0
    time_in_current_state: float = 0.0
    time_of_death: Optional[float] = None

    # State history
    state_history: List[Tuple[float, str]] = field(default_factory=list)

    # Cost accumulation
    total_cost: float = 0.0
    costs_by_category: Dict[CostCategory, float] = field(default_factory=dict)

    # QALY accumulation
    total_qalys: float = 0.0

    # Characteristics
    age: float = 50.0
    sex: str = "M"
    baseline_risk: float = 0.0
    comorbidities: List[str] = field(default_factory=list)

    def __post_init__(self):
        """Initialize patient"""
        # Record initial state
        self.state_history.append((0.0, self.current_state))

    def transition_to(self, new_state: str, current_time: float):
        """Transition patient to new state"""
        self.current_state = new_state
        self.time_in_current_state = 0.0
        self.current_time = current_time
        self.state_history.append((current_time, new_state))

    def accumulate_cost(self, cost: float, category: CostCategory):
        """Add cost to patient total"""
        self.total_cost += cost
        if category not in self.costs_by_category:
            self.costs_by_category[category] = 0.0
        self.costs_by_category[category] += cost

    def accumulate_qalys(self, utility: float, duration: float):
        """Add QALYs to patient total"""
        self.total_qalys += utility * duration

    def is_alive(self) -> bool:
        """Check if patient is alive"""
        return self.time_of_death is None


@dataclass
class Cost:
    """
    Cost item with category and timing

    Used to track all costs in the simulation.
    """
    amount: float
    category: CostCategory
    time: float  # When cost was incurred
    patient_id: str
    description: str = ""
    discounted_amount: Optional[float] = None

    def discount(self, discount_rate: float, base_time: float = 0.0):
        """Apply discount rate to cost"""
        years = self.time - base_time
        self.discounted_amount = self.amount / ((1 + discount_rate) ** years)


@dataclass
class SimulationConfig:
    """
    Configuration for discrete event simulation

    Defines simulation parameters, discounting, and analysis settings.
    """
    # Time parameters
    time_horizon: float = 10.0  # Years
    cycle_length: float = 1.0  # Years per cycle
    n_patients: int = 1000

    # Economic parameters
    discount_rate_costs: float = 0.035  # 3.5% per year (NICE guideline)
    discount_rate_qalys: float = 0.035  # 3.5% per year (NICE guideline)
    willingness_to_pay: float = 30000.0  # £30,000 per QALY (NICE threshold)

    # Analysis parameters
    run_psa: bool = True  # Probabilistic sensitivity analysis
    n_psa_iterations: int = 1000
    run_scenario_analysis: bool = True

    # Interventions to compare
    interventions: List[str] = field(default_factory=list)

    # Random seed for reproducibility
    random_seed: Optional[int] = None

    # Resource constraints
    resource_constraints: Dict[ResourceType, int] = field(default_factory=dict)

    def __post_init__(self):
        """Validate configuration"""
        assert self.time_horizon > 0, "Time horizon must be positive"
        assert self.n_patients > 0, "Number of patients must be positive"
        assert 0 <= self.discount_rate_costs <= 1, "Discount rate must be 0-1"
        assert 0 <= self.discount_rate_qalys <= 1, "Discount rate must be 0-1"


@dataclass
class SimulationResults:
    """
    Complete results from simulation run

    Contains costs, QALYs, ICERs, and detailed pathway statistics.
    """
    # Overall results
    total_costs: float
    total_qalys: float
    total_patients: int
    simulation_time: float  # Simulation clock time

    # Per-intervention results
    costs_by_intervention: Dict[str, float] = field(default_factory=dict)
    qalys_by_intervention: Dict[str, float] = field(default_factory=dict)

    # Incremental analysis
    incremental_cost: Optional[float] = None
    incremental_qalys: Optional[float] = None
    icer: Optional[float] = None  # Incremental cost-effectiveness ratio
    nmb: Optional[float] = None  # Net monetary benefit

    # State occupancy
    state_occupancy: Dict[str, float] = field(default_factory=dict)  # % time in each state

    # Resource utilization
    resource_utilization: Dict[ResourceType, float] = field(default_factory=dict)

    # Cost breakdown
    costs_by_category: Dict[CostCategory, float] = field(default_factory=dict)

    # PSA results (if run)
    psa_results: Optional[List[Dict]] = None

    # Convergence statistics
    converged: bool = False
    convergence_iteration: Optional[int] = None

    def calculate_icer(self, comparator_costs: float, comparator_qalys: float):
        """
        Calculate ICER vs comparator

        ICER = (Cost_intervention - Cost_comparator) / (QALY_intervention - QALY_comparator)
        """
        self.incremental_cost = self.total_costs - comparator_costs
        self.incremental_qalys = self.total_qalys - comparator_qalys

        if abs(self.incremental_qalys) < 0.0001:
            self.icer = None  # Same effectiveness
        else:
            self.icer = self.incremental_cost / self.incremental_qalys

    def calculate_nmb(self, willingness_to_pay: float):
        """
        Calculate Net Monetary Benefit

        NMB = (QALY * WTP) - Cost
        """
        self.nmb = (self.total_qalys * willingness_to_pay) - self.total_costs

    def is_cost_effective(self, willingness_to_pay: float) -> bool:
        """Check if intervention is cost-effective"""
        if self.icer is None:
            return self.incremental_cost < 0  # Dominant (cheaper and at least as effective)

        return self.icer < willingness_to_pay


@dataclass
class Intervention:
    """
    Healthcare intervention with costs and effects

    Defines how an intervention modifies the base pathway.
    """
    intervention_id: str
    intervention_name: str
    intervention_type: InterventionType

    # Cost parameters
    initial_cost: float = 0.0  # One-time cost (e.g., surgery)
    recurring_cost: float = 0.0  # Per-cycle cost (e.g., medication)
    cost_by_state: Dict[str, float] = field(default_factory=dict)  # State-specific costs

    # Effect modifiers
    transition_modifiers: Dict[Tuple[str, str], float] = field(default_factory=dict)  # Modify transition probabilities
    utility_modifiers: Dict[str, float] = field(default_factory=dict)  # Modify state utilities
    duration_modifier: float = 1.0  # Modify state durations

    # Adverse events
    adverse_event_rate: float = 0.0
    adverse_event_cost: float = 0.0
    adverse_event_utility_decrement: float = 0.0

    # Resource requirements
    required_resources: Dict[ResourceType, int] = field(default_factory=dict)

    # Discontinuation
    discontinuation_rate: float = 0.0  # Rate per cycle

    def apply_to_pathway(self, pathway: PatientPathway) -> PatientPathway:
        """
        Apply intervention to pathway

        Returns modified pathway with intervention effects
        """
        # Create deep copy of pathway
        import copy
        modified_pathway = copy.deepcopy(pathway)
        modified_pathway.intervention = self.intervention_name

        # Apply transition modifiers
        for state in modified_pathway.states:
            for (from_state, to_state), modifier in self.transition_modifiers.items():
                if state.state_id == from_state and to_state in state.transition_probabilities:
                    state.transition_probabilities[to_state] *= modifier

            # Apply utility modifiers
            if state.state_id in self.utility_modifiers:
                state.utility += self.utility_modifiers[state.state_id]
                state.utility = max(0.0, min(1.0, state.utility))

            # Apply cost modifiers
            if state.state_id in self.cost_by_state:
                state.cost_per_cycle += self.cost_by_state[state.state_id]

        return modified_pathway


# ==================== UTILITY FUNCTIONS ====================

def discount_value(value: float, rate: float, time: float) -> float:
    """
    Apply discount rate to a value

    Args:
        value: Undiscounted value
        rate: Annual discount rate (e.g., 0.035 for 3.5%)
        time: Time in years

    Returns:
        Discounted value
    """
    return value / ((1 + rate) ** time)


def calculate_qalys(utility: float, duration: float, discount_rate: float = 0.0, start_time: float = 0.0) -> float:
    """
    Calculate discounted QALYs

    Args:
        utility: Quality of life (0-1)
        duration: Time period (years)
        discount_rate: Annual discount rate
        start_time: Time when period starts

    Returns:
        Discounted QALYs
    """
    if discount_rate == 0:
        return utility * duration

    # Integrate discounted utility over time
    # QALY = ∫[start_time, start_time+duration] utility * e^(-r*t) dt
    # For constant utility: QALY = utility * (e^(-r*start) - e^(-r*end)) / r

    import math
    start = start_time
    end = start_time + duration
    discounted_qalys = utility * (math.exp(-discount_rate * start) - math.exp(-discount_rate * end)) / discount_rate

    return discounted_qalys


# Example usage
if __name__ == "__main__":
    # Create patient states
    healthy = PatientState(
        state_id="healthy",
        state_name="Healthy",
        utility=1.0,
        cost_per_cycle=100,
        transition_probabilities={"disease": 0.05, "death": 0.01}
    )

    disease = PatientState(
        state_id="disease",
        state_name="Disease",
        utility=0.7,
        cost_per_cycle=5000,
        transition_probabilities={"death": 0.10}
    )

    death = PatientState(
        state_id="death",
        state_name="Death",
        utility=0.0,
        cost_per_cycle=0,
        absorbing=True
    )

    # Create pathway
    pathway = PatientPathway(
        pathway_id="standard_care",
        pathway_name="Standard Care",
        states=[healthy, disease, death],
        initial_state="healthy",
        time_horizon=10.0
    )

    # Create patient
    patient = Patient(
        patient_id="P001",
        current_state="healthy",
        pathway=pathway
    )

    # Sample next state
    next_state, time_to_transition = healthy.sample_next_state()
    print(f"Patient transitions to: {next_state} in {time_to_transition:.2f} years")

    # Create resource
    bed = Resource(
        resource_id="bed_001",
        resource_type=ResourceType.BED,
        capacity=10,
        available=10,
        cost_per_unit=500  # £500 per day
    )

    # Acquire resource
    if bed.acquire(units=1):
        print(f"✓ Bed acquired. Utilization: {bed.utilization_rate():.1%}")

    # Create simulation config
    config = SimulationConfig(
        time_horizon=10,
        n_patients=1000,
        discount_rate_costs=0.035,
        discount_rate_qalys=0.035,
        willingness_to_pay=30000
    )

    print(f"\n✓ DES models initialized successfully")
    print(f"   States: {len(pathway.states)}")
    print(f"   Time horizon: {config.time_horizon} years")
    print(f"   Discount rate: {config.discount_rate_costs:.1%}")
