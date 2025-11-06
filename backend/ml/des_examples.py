"""
Example DES Models for Common Health Economics Scenarios

Pre-built models that can be used as templates:
1. Simple 3-state model (Healthy → Disease → Death)
2. 5-state cancer progression model
3. HIV treatment comparison model
4. Diabetes complication model

Usage:
    from ml.des_examples import get_example_model

    pathway, config = get_example_model("3_state_model")
    sim = DiscreteEventSimulation(config)
    sim.add_pathway(pathway)
    results = sim.run()
"""
from typing import Tuple, Dict, Any
from ml.des_models import (
    PatientState, PatientPathway,
    SimulationConfig
)


def get_3_state_model() -> Tuple[PatientPathway, SimulationConfig]:
    """
    Simple 3-state model: Healthy → Disease → Death

    Use case: Basic disease progression
    Time horizon: 10 years
    States:
      - Healthy (utility=1.0, cost=£100/year)
      - Disease (utility=0.7, cost=£5,000/year)
      - Death (utility=0.0, cost=£0/year)

    Transitions:
      - Healthy → Disease: 5% per year
      - Healthy → Death: 1% per year
      - Disease → Death: 10% per year

    Returns:
        (pathway, config) tuple ready for simulation
    """
    # Create states
    healthy = PatientState(
        state_id="healthy",
        state_name="Healthy",
        utility=1.0,
        cost_per_cycle=100,
        transition_probabilities={
            "disease": 0.05,
            "death": 0.01
        }
    )

    disease = PatientState(
        state_id="disease",
        state_name="Disease",
        utility=0.7,
        cost_per_cycle=5000,
        transition_probabilities={
            "death": 0.10
        }
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
        pathway_id="3_state_model",
        pathway_name="Simple 3-State Model",
        states=[healthy, disease, death],
        initial_state="healthy",
        time_horizon=10.0
    )

    # Create configuration
    config = SimulationConfig(
        time_horizon=10,
        n_patients=1000,
        discount_rate_costs=0.035,
        discount_rate_qalys=0.035,
        willingness_to_pay=30000
    )

    return pathway, config


def get_5_state_cancer_model() -> Tuple[PatientPathway, SimulationConfig]:
    """
    5-state cancer progression model

    Use case: Cancer screening and treatment evaluation
    Time horizon: 20 years
    States:
      - Healthy (no cancer)
      - Local (localized cancer)
      - Regional (regional spread)
      - Metastatic (distant metastases)
      - Death

    Transitions based on cancer natural history:
      - Healthy → Local: 2% per year (screening can detect)
      - Local → Regional: 15% per year (without treatment)
      - Regional → Metastatic: 25% per year
      - Each state has mortality risk

    Returns:
        (pathway, config) tuple ready for simulation
    """
    # Create states with cancer progression
    healthy = PatientState(
        state_id="healthy",
        state_name="Healthy",
        utility=1.0,
        cost_per_cycle=100,
        transition_probabilities={
            "local": 0.02,
            "death": 0.005  # Background mortality
        }
    )

    local = PatientState(
        state_id="local",
        state_name="Local Cancer",
        utility=0.85,
        cost_per_cycle=8000,  # Treatment costs
        transition_probabilities={
            "regional": 0.15,
            "death": 0.02
        }
    )

    regional = PatientState(
        state_id="regional",
        state_name="Regional Cancer",
        utility=0.70,
        cost_per_cycle=15000,
        transition_probabilities={
            "metastatic": 0.25,
            "death": 0.08
        }
    )

    metastatic = PatientState(
        state_id="metastatic",
        state_name="Metastatic Cancer",
        utility=0.50,
        cost_per_cycle=25000,
        transition_probabilities={
            "death": 0.30  # High mortality
        }
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
        pathway_id="5_state_cancer",
        pathway_name="5-State Cancer Progression Model",
        states=[healthy, local, regional, metastatic, death],
        initial_state="healthy",
        time_horizon=20.0
    )

    # Create configuration
    config = SimulationConfig(
        time_horizon=20,
        n_patients=1000,
        discount_rate_costs=0.035,
        discount_rate_qalys=0.035,
        willingness_to_pay=30000
    )

    return pathway, config


def get_hiv_treatment_model() -> Tuple[PatientPathway, SimulationConfig]:
    """
    HIV treatment model based on CD4 count

    Use case: Comparing different ART (antiretroviral therapy) strategies
    Time horizon: 15 years
    States:
      - CD4 > 500 (high immune function)
      - CD4 200-500 (moderate immune function)
      - CD4 < 200 (AIDS)
      - Death

    Note: This is a simplified model. Real HIV models are more complex.

    Returns:
        (pathway, config) tuple ready for simulation
    """
    # Create states based on CD4 count
    cd4_high = PatientState(
        state_id="cd4_high",
        state_name="CD4 > 500",
        utility=0.95,
        cost_per_cycle=3000,  # ART costs
        transition_probabilities={
            "cd4_medium": 0.10,
            "death": 0.005
        }
    )

    cd4_medium = PatientState(
        state_id="cd4_medium",
        state_name="CD4 200-500",
        utility=0.85,
        cost_per_cycle=4000,  # ART + monitoring
        transition_probabilities={
            "cd4_high": 0.05,  # Can improve with treatment
            "cd4_low": 0.15,
            "death": 0.02
        }
    )

    cd4_low = PatientState(
        state_id="cd4_low",
        state_name="CD4 < 200 (AIDS)",
        utility=0.65,
        cost_per_cycle=12000,  # ART + opportunistic infection treatment
        transition_probabilities={
            "cd4_medium": 0.08,  # Can improve with intensive treatment
            "death": 0.10
        }
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
        pathway_id="hiv_treatment",
        pathway_name="HIV Treatment Model",
        states=[cd4_high, cd4_medium, cd4_low, death],
        initial_state="cd4_high",
        time_horizon=15.0
    )

    # Create configuration
    config = SimulationConfig(
        time_horizon=15,
        n_patients=1000,
        discount_rate_costs=0.035,
        discount_rate_qalys=0.035,
        willingness_to_pay=30000
    )

    return pathway, config


def get_diabetes_complications_model() -> Tuple[PatientPathway, SimulationConfig]:
    """
    Diabetes complications model

    Use case: Evaluating diabetes management strategies
    Time horizon: 20 years
    States:
      - No complications
      - Microvascular complications (retinopathy, neuropathy)
      - Macrovascular complications (CVD)
      - Both complications
      - Death

    Transitions based on glycemic control and other risk factors.

    Returns:
        (pathway, config) tuple ready for simulation
    """
    # Create states
    no_complications = PatientState(
        state_id="no_comp",
        state_name="No Complications",
        utility=0.90,
        cost_per_cycle=2000,  # Diabetes management
        transition_probabilities={
            "micro": 0.08,
            "macro": 0.05,
            "death": 0.01
        }
    )

    microvascular = PatientState(
        state_id="micro",
        state_name="Microvascular Complications",
        utility=0.75,
        cost_per_cycle=5000,
        transition_probabilities={
            "both": 0.10,
            "death": 0.03
        }
    )

    macrovascular = PatientState(
        state_id="macro",
        state_name="Macrovascular Complications",
        utility=0.70,
        cost_per_cycle=8000,
        transition_probabilities={
            "both": 0.12,
            "death": 0.08  # Higher mortality with CVD
        }
    )

    both_complications = PatientState(
        state_id="both",
        state_name="Both Complications",
        utility=0.55,
        cost_per_cycle=15000,
        transition_probabilities={
            "death": 0.15
        }
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
        pathway_id="diabetes_complications",
        pathway_name="Diabetes Complications Model",
        states=[no_complications, microvascular, macrovascular, both_complications, death],
        initial_state="no_comp",
        time_horizon=20.0
    )

    # Create configuration
    config = SimulationConfig(
        time_horizon=20,
        n_patients=1000,
        discount_rate_costs=0.035,
        discount_rate_qalys=0.035,
        willingness_to_pay=30000
    )

    return pathway, config


def get_example_model(model_id: str) -> Tuple[PatientPathway, SimulationConfig]:
    """
    Get example model by ID

    Args:
        model_id: Model identifier
            - "3_state_model": Simple 3-state model
            - "5_state_cancer": Cancer progression
            - "hiv_treatment": HIV treatment
            - "diabetes_complications": Diabetes complications

    Returns:
        (pathway, config) tuple

    Raises:
        ValueError: If model_id not recognized

    Example:
        >>> pathway, config = get_example_model("3_state_model")
        >>> sim = DiscreteEventSimulation(config)
        >>> sim.add_pathway(pathway)
        >>> results = sim.run()
    """
    models = {
        "3_state_model": get_3_state_model,
        "5_state_cancer": get_5_state_cancer_model,
        "hiv_treatment": get_hiv_treatment_model,
        "diabetes_complications": get_diabetes_complications_model
    }

    if model_id not in models:
        raise ValueError(
            f"Unknown model_id: {model_id}. "
            f"Available models: {list(models.keys())}"
        )

    return models[model_id]()


def list_example_models() -> Dict[str, Dict[str, Any]]:
    """
    List all available example models

    Returns:
        Dictionary with model metadata

    Example:
        >>> models = list_example_models()
        >>> for model_id, info in models.items():
        ...     print(f"{model_id}: {info['description']}")
    """
    return {
        "3_state_model": {
            "name": "Simple 3-State Model",
            "description": "Healthy → Disease → Death",
            "states": 3,
            "time_horizon": 10,
            "use_case": "Basic disease progression",
            "complexity": "Beginner"
        },
        "5_state_cancer": {
            "name": "5-State Cancer Progression Model",
            "description": "Healthy → Local → Regional → Metastatic → Death",
            "states": 5,
            "time_horizon": 20,
            "use_case": "Cancer screening and treatment evaluation",
            "complexity": "Intermediate"
        },
        "hiv_treatment": {
            "name": "HIV Treatment Model",
            "description": "CD4-based progression with ART",
            "states": 4,
            "time_horizon": 15,
            "use_case": "Comparing ART strategies",
            "complexity": "Intermediate"
        },
        "diabetes_complications": {
            "name": "Diabetes Complications Model",
            "description": "Progression through microvascular and macrovascular complications",
            "states": 5,
            "time_horizon": 20,
            "use_case": "Evaluating diabetes management strategies",
            "complexity": "Intermediate"
        }
    }


# Example usage
if __name__ == "__main__":
    from ml.discrete_event_simulation import DiscreteEventSimulation

    # List available models
    print("Available Example Models:")
    print("=" * 60)
    for model_id, info in list_example_models().items():
        print(f"\n{model_id}:")
        print(f"  Name: {info['name']}")
        print(f"  Description: {info['description']}")
        print(f"  States: {info['states']}")
        print(f"  Time horizon: {info['time_horizon']} years")
        print(f"  Use case: {info['use_case']}")
        print(f"  Complexity: {info['complexity']}")

    print("\n" + "=" * 60)
    print("\nRunning 3-State Model Example...\n")

    # Run example model
    pathway, config = get_example_model("3_state_model")

    # Create and run simulation
    sim = DiscreteEventSimulation(config)
    sim.add_pathway(pathway)

    results = sim.run()

    # Display results
    print(f"✓ Simulation complete!")
    print(f"  Total Cost: £{results.total_costs:,.0f}")
    print(f"  Total QALYs: {results.total_qalys:,.2f}")
    print(f"  Cost per QALY: £{results.total_costs / results.total_qalys:,.0f}")
    print(f"\n  State Occupancy:")
    for state, occupancy in results.state_occupancy.items():
        print(f"    {state}: {occupancy:.1%}")
