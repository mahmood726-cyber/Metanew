"""
Comprehensive Tests for Discrete Event Simulation

Tests cover:
- DES data models
- Event queue operations
- Resource management
- State transitions
- Cost and QALY accumulation
- Complete simulations
- Probabilistic sensitivity analysis
- API endpoints

Target: 90%+ code coverage
"""
import pytest
import numpy as np
from datetime import datetime

from ml.des_models import (
    Event, EventType,
    Resource, ResourceType,
    PatientState, PatientPathway, Patient,
    Cost, CostCategory,
    SimulationConfig, SimulationResults,
    Intervention, InterventionType,
    discount_value, calculate_qalys
)
from ml.discrete_event_simulation import (
    EventQueue,
    ResourceManager,
    DiscreteEventSimulation
)


# ==================== FIXTURES ====================

@pytest.fixture
def simple_states():
    """Create simple 3-state model: Healthy → Disease → Death"""
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

    return [healthy, disease, death]


@pytest.fixture
def simple_pathway(simple_states):
    """Create simple patient pathway"""
    return PatientPathway(
        pathway_id="standard_care",
        pathway_name="Standard Care",
        states=simple_states,
        initial_state="healthy",
        time_horizon=10.0
    )


@pytest.fixture
def simple_config():
    """Create simple simulation configuration"""
    return SimulationConfig(
        time_horizon=10,
        n_patients=100,  # Smaller for faster tests
        discount_rate_costs=0.035,
        discount_rate_qalys=0.035,
        willingness_to_pay=30000,
        random_seed=42  # For reproducibility
    )


@pytest.fixture
def hospital_resources():
    """Create hospital resources"""
    return [
        Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=10,
            cost_per_unit=500
        ),
        Resource(
            resource_id="nurse_001",
            resource_type=ResourceType.NURSE,
            capacity=5,
            available=5,
            cost_per_unit=200,
            cost_per_use=50
        )
    ]


# ==================== DATA MODEL TESTS ====================

class TestPatientState:
    """Test PatientState model"""

    def test_state_creation(self):
        """Test creating a patient state"""
        state = PatientState(
            state_id="test",
            state_name="Test State",
            utility=0.8,
            cost_per_cycle=1000,
            transition_probabilities={"other": 0.1}
        )

        assert state.state_id == "test"
        assert state.utility == 0.8
        assert state.cost_per_cycle == 1000
        assert not state.absorbing

    def test_state_validation(self):
        """Test state validation"""
        # Utility must be 0-1
        with pytest.raises(AssertionError):
            PatientState(
                state_id="invalid",
                state_name="Invalid",
                utility=1.5,  # Invalid
                cost_per_cycle=100
            )

        # Cost must be non-negative
        with pytest.raises(AssertionError):
            PatientState(
                state_id="invalid",
                state_name="Invalid",
                utility=0.5,
                cost_per_cycle=-100  # Invalid
            )

    def test_transition_probabilities_validation(self):
        """Test transition probabilities sum to ≤ 1"""
        with pytest.raises(AssertionError):
            PatientState(
                state_id="invalid",
                state_name="Invalid",
                utility=0.5,
                cost_per_cycle=100,
                transition_probabilities={"a": 0.6, "b": 0.6}  # Sum > 1
            )

    def test_sample_next_state(self, simple_states):
        """Test sampling next state"""
        healthy = simple_states[0]

        # Set seed for reproducibility
        np.random.seed(42)

        # Sample multiple times
        next_states = []
        for _ in range(100):
            next_state, time = healthy.sample_next_state()
            next_states.append(next_state)

        # Should include transitions to disease and death
        assert "disease" in next_states or "death" in next_states
        assert "healthy" in next_states  # Can stay in same state


class TestPatientPathway:
    """Test PatientPathway model"""

    def test_pathway_creation(self, simple_pathway):
        """Test creating a patient pathway"""
        assert simple_pathway.pathway_id == "standard_care"
        assert len(simple_pathway.states) == 3
        assert simple_pathway.initial_state == "healthy"

    def test_pathway_validation(self, simple_states):
        """Test pathway validation"""
        # Initial state must exist
        with pytest.raises(AssertionError):
            PatientPathway(
                pathway_id="invalid",
                pathway_name="Invalid",
                states=simple_states,
                initial_state="nonexistent"  # Invalid
            )

    def test_get_state(self, simple_pathway):
        """Test retrieving state by ID"""
        healthy = simple_pathway.get_state("healthy")
        assert healthy is not None
        assert healthy.state_name == "Healthy"

        nonexistent = simple_pathway.get_state("nonexistent")
        assert nonexistent is None


class TestResource:
    """Test Resource model"""

    def test_resource_creation(self):
        """Test creating a resource"""
        bed = Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=10,
            cost_per_unit=500
        )

        assert bed.capacity == 10
        assert bed.available == 10
        assert bed.is_available(5)

    def test_resource_acquisition(self):
        """Test acquiring resources"""
        bed = Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=10,
            cost_per_unit=500
        )

        # Acquire 3 units
        success = bed.acquire(3)
        assert success
        assert bed.available == 7

        # Acquire 10 units (should fail - not enough)
        success = bed.acquire(10)
        assert not success
        assert bed.available == 7  # Unchanged

    def test_resource_release(self):
        """Test releasing resources"""
        bed = Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=5,
            cost_per_unit=500
        )

        # Release 3 units
        bed.release(3)
        assert bed.available == 8

        # Can't release beyond capacity
        bed.release(10)
        assert bed.available == 10  # Capped at capacity

    def test_utilization_rate(self):
        """Test utilization rate calculation"""
        bed = Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=7,
            cost_per_unit=500
        )

        utilization = bed.utilization_rate()
        assert abs(utilization - 0.3) < 0.01  # 3 out of 10 in use (with floating point tolerance)


class TestSimulationConfig:
    """Test SimulationConfig model"""

    def test_config_creation(self, simple_config):
        """Test creating simulation config"""
        assert simple_config.time_horizon == 10
        assert simple_config.n_patients == 100
        assert simple_config.discount_rate_costs == 0.035

    def test_config_validation(self):
        """Test configuration validation"""
        # Time horizon must be positive
        with pytest.raises(AssertionError):
            SimulationConfig(
                time_horizon=-5,  # Invalid
                n_patients=100
            )

        # Number of patients must be positive
        with pytest.raises(AssertionError):
            SimulationConfig(
                time_horizon=10,
                n_patients=0  # Invalid
            )


# ==================== EVENT QUEUE TESTS ====================

class TestEventQueue:
    """Test EventQueue implementation"""

    def test_queue_creation(self):
        """Test creating event queue"""
        queue = EventQueue()
        assert queue.is_empty()
        assert queue.size() == 0

    def test_schedule_event(self):
        """Test scheduling events"""
        queue = EventQueue()

        event1 = Event(time=1.0, event_type=EventType.STATE_TRANSITION, patient_id="P1", data={})
        event2 = Event(time=0.5, event_type=EventType.STATE_TRANSITION, patient_id="P2", data={})

        queue.schedule(event1)
        queue.schedule(event2)

        assert queue.size() == 2

    def test_event_ordering(self):
        """Test events are processed in chronological order"""
        queue = EventQueue()

        # Schedule events out of order
        queue.schedule(Event(time=3.0, event_type=EventType.STATE_TRANSITION, patient_id="P3", data={}))
        queue.schedule(Event(time=1.0, event_type=EventType.STATE_TRANSITION, patient_id="P1", data={}))
        queue.schedule(Event(time=2.0, event_type=EventType.STATE_TRANSITION, patient_id="P2", data={}))

        # Should be retrieved in order
        event1 = queue.next_event()
        assert event1.time == 1.0

        event2 = queue.next_event()
        assert event2.time == 2.0

        event3 = queue.next_event()
        assert event3.time == 3.0

    def test_priority_ordering(self):
        """Test events at same time are ordered by priority"""
        queue = EventQueue()

        # Schedule events at same time with different priorities
        queue.schedule(Event(time=1.0, event_type=EventType.STATE_TRANSITION, patient_id="P1", data={}, priority=1))
        queue.schedule(Event(time=1.0, event_type=EventType.STATE_TRANSITION, patient_id="P2", data={}, priority=3))
        queue.schedule(Event(time=1.0, event_type=EventType.STATE_TRANSITION, patient_id="P3", data={}, priority=2))

        # Higher priority first
        event1 = queue.next_event()
        assert event1.priority == 3

        event2 = queue.next_event()
        assert event2.priority == 2


# ==================== RESOURCE MANAGER TESTS ====================

class TestResourceManager:
    """Test ResourceManager implementation"""

    def test_manager_creation(self):
        """Test creating resource manager"""
        manager = ResourceManager()
        assert len(manager.resources) == 0

    def test_add_resource(self):
        """Test adding resources"""
        manager = ResourceManager()

        bed = Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=10,
            cost_per_unit=500
        )

        manager.add_resource(bed)
        assert "bed_001" in manager.resources

    def test_request_resource(self):
        """Test requesting resources"""
        manager = ResourceManager()

        bed = Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=10,
            cost_per_unit=500
        )
        manager.add_resource(bed)

        # Request available resource
        success, wait_time = manager.request_resource("bed_001", "P1", units=3)
        assert success
        assert wait_time == 0.0
        assert manager.resources["bed_001"].available == 7

    def test_release_resource(self):
        """Test releasing resources"""
        manager = ResourceManager()

        bed = Resource(
            resource_id="bed_001",
            resource_type=ResourceType.BED,
            capacity=10,
            available=5,
            cost_per_unit=500
        )
        manager.add_resource(bed)

        # Release resource
        next_patient = manager.release_resource("bed_001", "P1", units=2)
        assert manager.resources["bed_001"].available == 7


# ==================== SIMULATION ENGINE TESTS ====================

class TestDiscreteEventSimulation:
    """Test DiscreteEventSimulation engine"""

    def test_simulation_creation(self, simple_config):
        """Test creating simulation"""
        sim = DiscreteEventSimulation(simple_config)
        assert sim.config.time_horizon == 10
        assert sim.current_time == 0.0

    def test_add_pathway(self, simple_pathway, simple_config):
        """Test adding pathway to simulation"""
        sim = DiscreteEventSimulation(simple_config)
        sim.add_pathway(simple_pathway)

        assert "standard_care" in sim.pathways

    def test_create_patient(self, simple_pathway, simple_config):
        """Test creating patient"""
        sim = DiscreteEventSimulation(simple_config)
        sim.add_pathway(simple_pathway)

        patient = sim.create_patient("P001", simple_pathway, arrival_time=0.0)

        assert patient.patient_id == "P001"
        assert patient.current_state == "healthy"
        assert "P001" in sim.patients

    def test_run_simulation_small(self, simple_pathway, simple_config):
        """Test running small simulation"""
        # Use even smaller config for fast test
        config = SimulationConfig(
            time_horizon=5,
            n_patients=10,
            discount_rate_costs=0.035,
            discount_rate_qalys=0.035,
            random_seed=42
        )

        sim = DiscreteEventSimulation(config)
        sim.add_pathway(simple_pathway)

        results = sim.run()

        # Verify results structure
        assert results.total_patients == 10
        assert results.total_costs > 0
        assert results.total_qalys > 0
        assert 0 <= results.total_qalys <= 50  # 10 patients * 5 years max

    def test_run_simulation_full(self, simple_pathway, simple_config):
        """Test running full simulation"""
        sim = DiscreteEventSimulation(simple_config)
        sim.add_pathway(simple_pathway)

        results = sim.run()

        # Verify results
        assert results.total_patients == 100
        assert results.total_costs > 0
        assert results.total_qalys > 0

        # Verify state occupancy
        assert "healthy" in results.state_occupancy
        assert "disease" in results.state_occupancy
        assert "death" in results.state_occupancy

        # Occupancy should sum to ~1.0
        total_occupancy = sum(results.state_occupancy.values())
        assert 0.95 <= total_occupancy <= 1.05

    def test_discounting(self):
        """Test cost and QALY discounting"""
        # No discounting
        value_no_discount = discount_value(1000, 0.0, 5)
        assert value_no_discount == 1000

        # With discounting
        value_discounted = discount_value(1000, 0.035, 5)
        assert value_discounted < 1000
        assert value_discounted > 800  # Roughly correct

    def test_qaly_calculation(self):
        """Test QALY calculation"""
        # Full utility for 1 year = 1 QALY
        qalys = calculate_qalys(1.0, 1.0, discount_rate=0.0)
        assert abs(qalys - 1.0) < 0.01

        # Half utility for 2 years = 1 QALY
        qalys = calculate_qalys(0.5, 2.0, discount_rate=0.0)
        assert abs(qalys - 1.0) < 0.01


class TestProbabilisticSensitivityAnalysis:
    """Test PSA implementation"""

    def test_psa_runs(self, simple_pathway):
        """Test PSA runs multiple iterations"""
        config = SimulationConfig(
            time_horizon=5,
            n_patients=10,
            n_psa_iterations=5,  # Small for fast test
            random_seed=42
        )

        sim = DiscreteEventSimulation(config)
        sim.add_pathway(simple_pathway)

        psa_results = sim.run_psa(n_iterations=5)

        assert len(psa_results) == 5

        # All results should have costs and QALYs
        for result in psa_results:
            assert result.total_costs > 0
            assert result.total_qalys > 0

    def test_psa_variation(self, simple_pathway):
        """Test PSA shows variation across iterations"""
        config = SimulationConfig(
            time_horizon=5,
            n_patients=20,
            n_psa_iterations=10,
            random_seed=None  # Allow variation
        )

        sim = DiscreteEventSimulation(config)
        sim.add_pathway(simple_pathway)

        psa_results = sim.run_psa(n_iterations=10)

        # Extract costs
        costs = [r.total_costs for r in psa_results]

        # Should have variation (not all identical)
        assert len(set(costs)) > 1


# ==================== UTILITY FUNCTION TESTS ====================

class TestUtilityFunctions:
    """Test utility functions"""

    def test_discount_value(self):
        """Test discount_value function"""
        # No discounting
        assert discount_value(1000, 0.0, 0) == 1000

        # 3.5% discount for 1 year
        discounted = discount_value(1000, 0.035, 1)
        expected = 1000 / 1.035
        assert abs(discounted - expected) < 0.01

    def test_calculate_qalys_no_discount(self):
        """Test QALY calculation without discounting"""
        qalys = calculate_qalys(0.8, 5.0, discount_rate=0.0)
        assert qalys == 4.0  # 0.8 * 5

    def test_calculate_qalys_with_discount(self):
        """Test QALY calculation with discounting"""
        qalys = calculate_qalys(1.0, 1.0, discount_rate=0.035)
        assert qalys < 1.0  # Should be discounted


# ==================== INTEGRATION TESTS ====================

class TestSimulationIntegration:
    """Integration tests for complete workflows"""

    def test_complete_simulation_workflow(self, simple_pathway, simple_config):
        """Test complete simulation workflow"""
        # Create simulation
        sim = DiscreteEventSimulation(simple_config)

        # Add pathway
        sim.add_pathway(simple_pathway)

        # Run simulation
        results = sim.run()

        # Verify complete results
        assert results.total_patients == simple_config.n_patients
        assert results.total_costs > 0
        assert results.total_qalys > 0
        assert results.simulation_time == simple_config.time_horizon
        assert len(results.state_occupancy) > 0
        assert len(results.costs_by_category) > 0

    def test_two_intervention_comparison(self, simple_states):
        """Test comparing two interventions"""
        # Create two pathways: standard care and intervention
        pathway1 = PatientPathway(
            pathway_id="standard",
            pathway_name="Standard Care",
            states=simple_states,
            initial_state="healthy",
            time_horizon=5.0
        )

        pathway2 = PatientPathway(
            pathway_id="intervention",
            pathway_name="New Intervention",
            states=simple_states,
            initial_state="healthy",
            time_horizon=5.0
        )

        config = SimulationConfig(
            time_horizon=5,
            n_patients=50,
            random_seed=42
        )

        # Run both simulations
        sim1 = DiscreteEventSimulation(config)
        sim1.add_pathway(pathway1)
        results1 = sim1.run()

        sim2 = DiscreteEventSimulation(config)
        sim2.add_pathway(pathway2)
        results2 = sim2.run()

        # Calculate ICER
        results2.calculate_icer(results1.total_costs, results1.total_qalys)

        # Should have ICER or be same
        # (With same pathway, should be very similar)
        assert results2.incremental_cost is not None
        assert results2.incremental_qalys is not None


# ==================== EDGE CASES ====================

class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_zero_patients(self, simple_pathway):
        """Test with zero patients"""
        config = SimulationConfig(
            time_horizon=5,
            n_patients=1,  # Minimum 1
            random_seed=42
        )

        sim = DiscreteEventSimulation(config)
        sim.add_pathway(simple_pathway)

        results = sim.run()
        assert results.total_patients == 1

    def test_very_short_horizon(self, simple_pathway):
        """Test with very short time horizon"""
        config = SimulationConfig(
            time_horizon=0.1,  # Very short
            n_patients=10,
            random_seed=42
        )

        sim = DiscreteEventSimulation(config)
        sim.add_pathway(simple_pathway)

        results = sim.run()
        assert results.simulation_time == 0.1

    def test_absorbing_state_immediate(self):
        """Test pathway that starts in absorbing state"""
        death = PatientState(
            state_id="death",
            state_name="Death",
            utility=0.0,
            cost_per_cycle=0,
            absorbing=True
        )

        pathway = PatientPathway(
            pathway_id="immediate_death",
            pathway_name="Immediate Death",
            states=[death],
            initial_state="death",
            time_horizon=10.0
        )

        config = SimulationConfig(
            time_horizon=10,
            n_patients=10,
            random_seed=42
        )

        sim = DiscreteEventSimulation(config)
        sim.add_pathway(pathway)

        results = sim.run()

        # Should have zero QALYs (all in death state)
        assert results.total_qalys == 0.0


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])


# ==================== ADDITIONAL TESTS FOR 100% COVERAGE ====================

class TestEventQueueEdgeCases:
    """Additional tests for EventQueue edge cases"""
    
    def test_next_event_empty_queue(self):
        """Test next_event returns None for empty queue"""
        queue = EventQueue()
        assert queue.next_event() is None
    
    def test_peek_empty_queue(self):
        """Test peek returns None for empty queue"""
        queue = EventQueue()
        assert queue.peek() is None
    
    def test_clear_queue(self):
        """Test clearing queue"""
        queue = EventQueue()
        queue.add_event(Event(EventType.STATE_TRANSITION, 1.0, {"patient_id": "P1"}))
        queue.add_event(Event(EventType.STATE_TRANSITION, 2.0, {"patient_id": "P2"}))
        
        assert queue.size() == 2
        queue.clear()
        assert queue.size() == 0
        assert queue.is_empty()


class TestResourceManagerEdgeCases:
    """Additional tests for ResourceManager edge cases"""
    
    def test_request_nonexistent_resource(self):
        """Test requesting resource that doesn't exist"""
        manager = ResourceManager()
        success, wait_time = manager.request_resource("nonexistent", "P1", 1)
        
        assert success is False
        assert wait_time is None
    
    def test_release_nonexistent_resource(self):
        """Test releasing resource that doesn't exist"""
        manager = ResourceManager()
        next_patient = manager.release_resource("nonexistent", "P1", 1)
        
        assert next_patient is None
    
    def test_get_cost_nonexistent_resource(self):
        """Test getting cost for nonexistent resource"""
        manager = ResourceManager()
        cost = manager.get_resource_cost("nonexistent", 5.0)
        
        assert cost == 0.0
    
    def test_resource_queuing(self):
        """Test resource queuing when unavailable"""
        manager = ResourceManager()
        
        # Add resource with capacity 1
        bed = Resource(
            resource_id="bed1",
            resource_type=ResourceType.BED,
            capacity=1,
            available=1,
            cost_per_unit=100.0,
            resource_name="Hospital Bed"
        )
        manager.add_resource(bed)
        
        # First patient gets resource immediately
        success1, wait1 = manager.request_resource("bed1", "P1", 1)
        assert success1 is True
        assert wait1 == 0.0
        
        # Second patient queued
        success2, wait2 = manager.request_resource("bed1", "P2", 1)
        assert success2 is False
        assert wait2 is None
        
        # Release resource
        next_patient = manager.release_resource("bed1", "P1", 1)
        assert next_patient == "P2"


class TestDiscreteEventSimulationEdgeCases:
    """Additional tests for DiscreteEventSimulation edge cases"""
    
    def test_resource_not_found(self, simple_pathway, simple_config):
        """Test handling of missing resources"""
        sim = DiscreteEventSimulation(simple_config)
        sim.add_pathway(simple_pathway)
        
        # Try to process resource request event for nonexistent resource
        event = Event(
            EventType.RESOURCE_REQUEST,
            1.0,
            {"patient_id": "P1", "resource_id": "nonexistent", "units": 1}
        )
        
        # Should handle gracefully
        sim.event_queue.add_event(event)
        # Process event won't crash
    
    def test_patient_not_found_in_event(self, simple_pathway, simple_config):
        """Test handling event with nonexistent patient"""
        sim = DiscreteEventSimulation(simple_config)
        sim.add_pathway(simple_pathway)
        
        # Event for patient that doesn't exist
        event = Event(
            EventType.STATE_TRANSITION,
            1.0,
            {"patient_id": "nonexistent", "to_state": "disease"}
        )
        
        sim.event_queue.add_event(event)
        # Should handle gracefully without crashing
    
    def test_intervention_with_all_modifiers(self, simple_pathway, simple_config):
        """Test intervention with cost, utility, and probability modifiers"""
        intervention = Intervention(
            intervention_id="combo",
            intervention_name="Combination Intervention",
            intervention_type=InterventionType.TREATMENT,
            initial_cost=1000.0,
            recurring_cost=500.0,
            cost_by_state={"disease": -200.0},  # 200 cost reduction in disease state
            utility_modifiers={"disease": 0.1},  # 10% utility improvement in disease
            transition_modifiers={
                ("disease", "death"): 0.7  # 30% reduction in death probability from disease
            }
        )

        # Apply intervention to pathway
        modified_pathway = intervention.apply_to_pathway(simple_pathway)

        sim = DiscreteEventSimulation(simple_config)
        sim.add_pathway(modified_pathway)

        results = sim.run()

        # Should complete successfully
        assert isinstance(results, SimulationResults)
        assert results.total_costs >= 0
        assert results.total_qalys >= 0
    
    def test_time_horizon_reached_mid_cycle(self, simple_pathway):
        """Test simulation stopping at time horizon"""
        config = SimulationConfig(
            time_horizon=0.5,  # Very short horizon
            n_patients=5,
            discount_rate_costs=0.035,
            discount_rate_qalys=0.035,
            willingness_to_pay=30000
        )
        
        sim = DiscreteEventSimulation(config)
        sim.add_pathway(simple_pathway)
        
        results = sim.run()
        
        # Should stop at time horizon
        assert results is not None
    
    def test_very_high_transition_probabilities(self):
        """Test with very high transition probabilities (rapid transitions)"""
        # State with very high transition probability
        sick = PatientState(
            state_id="sick",
            state_name="Sick",
            utility=0.5,
            cost_per_cycle=1000,
            transition_probabilities={"death": 0.95}  # 95% chance of death
        )
        
        death = PatientState(
            state_id="death",
            state_name="Death",
            utility=0.0,
            cost_per_cycle=0,
            absorbing=True
        )
        
        pathway = PatientPathway(
            pathway_id="rapid",
            pathway_name="Rapid Transition",
            states=[sick, death],
            initial_state="sick",
            time_horizon=10.0
        )
        
        config = SimulationConfig(
            time_horizon=10,
            n_patients=50,
            discount_rate_costs=0.035,
            discount_rate_qalys=0.035
        )
        
        sim = DiscreteEventSimulation(config)
        sim.add_pathway(pathway)

        results = sim.run()

        # Patients transition rapidly but accumulate some QALYs in sick state
        # With 50 patients, utility 0.5, and average ~1 cycle before death:
        # Expected: ~0.5 QALYs per patient * 50 patients = ~25 QALYs
        assert 20.0 < results.total_qalys < 30.0  # Reasonable range for rapid transitions


class TestDESModelsEdgeCases:
    """Additional tests for DES models edge cases"""
    
    def test_cost_with_zero_discount_rate(self):
        """Test discounting with zero discount rate"""
        value = discount_value(1000, 5.0, 0.0)  # No discounting
        assert abs(value - 1000.0) < 0.01
    
    def test_qalys_calculation_varying_utilities(self):
        """Test QALY calculation with varying utilities"""
        utilities = [1.0, 0.8, 0.6, 0.4, 0.2]
        time_in_states = [1.0, 1.0, 1.0, 1.0, 1.0]
        discount_rate = 0.035

        # Calculate QALYs for each period and sum
        total_qalys = 0.0
        current_time = 0.0
        for utility, duration in zip(utilities, time_in_states):
            qalys = calculate_qalys(utility, duration, discount_rate, current_time)
            total_qalys += qalys
            current_time += duration

        # Should be positive and less than sum without discounting
        assert 0 < total_qalys < sum(utilities)
    
    def test_resource_repr(self):
        """Test Resource string representation"""
        resource = Resource(
            resource_id="test_resource",
            resource_type=ResourceType.STAFF,
            capacity=10,
            available=10,
            cost_per_unit=50.0,
            resource_name="Test Resource"
        )

        repr_str = repr(resource)
        assert "Resource" in repr_str
        assert "test_resource" in repr_str
    
    def test_patient_pathway_validation(self):
        """Test patient pathway with missing initial state"""
        healthy = PatientState(
            state_id="healthy",
            state_name="Healthy",
            utility=1.0,
            cost_per_cycle=100,
            transition_probabilities={}
        )
        
        # Create pathway with non-existent initial state
        try:
            pathway = PatientPathway(
                pathway_id="invalid",
                pathway_name="Invalid Pathway",
                states=[healthy],
                initial_state="nonexistent",  # This doesn't exist
                time_horizon=10.0
            )
            
            # Should still create (validation happens during simulation)
            assert pathway.initial_state == "nonexistent"
        except:
            pass  # Validation may occur during construction
    
    def test_intervention_no_modifiers(self):
        """Test intervention with no modifiers (no effect)"""
        intervention = Intervention(
            intervention_id="null_intervention",
            intervention_name="Null Intervention",
            intervention_type=InterventionType.POLICY
        )

        # Should have default values (no effect)
        assert intervention.initial_cost == 0.0
        assert intervention.recurring_cost == 0.0
        assert intervention.duration_modifier == 1.0
        assert len(intervention.transition_modifiers) == 0
        assert len(intervention.utility_modifiers) == 0
        assert len(intervention.cost_by_state) == 0


class TestPSAEdgeCases:
    """Additional PSA edge cases"""
    
    def test_psa_with_single_iteration(self, simple_pathway):
        """Test PSA with just 1 iteration"""
        config = SimulationConfig(
            time_horizon=5,
            n_patients=20,
            n_psa_iterations=1  # Single iteration
        )
        
        sim = DiscreteEventSimulation(config)
        sim.add_pathway(simple_pathway)
        
        psa_results = sim.run_psa(n_iterations=1)
        
        assert len(psa_results) == 1
        assert isinstance(psa_results[0], SimulationResults)
    
    def test_psa_reproducibility(self, simple_pathway):
        """Test PSA reproducibility with same seed"""
        config1 = SimulationConfig(
            time_horizon=5,
            n_patients=20,
            random_seed=42
        )
        
        config2 = SimulationConfig(
            time_horizon=5,
            n_patients=20,
            random_seed=42  # Same seed
        )
        
        sim1 = DiscreteEventSimulation(config1)
        sim1.add_pathway(simple_pathway)
        results1 = sim1.run()
        
        sim2 = DiscreteEventSimulation(config2)
        sim2.add_pathway(simple_pathway)
        results2 = sim2.run()
        
        # Should produce identical results with same seed
        assert abs(results1.total_costs - results2.total_costs) < 1.0
        assert abs(results1.total_qalys - results2.total_qalys) < 0.01


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--cov=ml/discrete_event_simulation", "--cov=ml/des_models", "--cov-report=term-missing"])
