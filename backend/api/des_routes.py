"""
Discrete Event Simulation (DES) API Endpoints

Provides endpoints for health economics discrete event simulation:
- Create and configure simulations
- Run simulations (deterministic and PSA)
- Compare interventions
- Retrieve results and statistics

Value: Enables HTA submissions, cost-effectiveness analysis, and pharmaceutical consultancy
Competitive: Free vs TreeAge ($1,495/year), Integrated vs R (heemod)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Dict, List, Any, Optional
import logging
from datetime import datetime

from auth import get_current_user, User
from ml.discrete_event_simulation import DiscreteEventSimulation
from ml.des_models import (
    PatientState, PatientPathway, Patient,
    Resource, ResourceType,
    SimulationConfig, SimulationResults,
    Intervention, InterventionType,
    CostCategory, EventType
)

# Configure logging
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/des", tags=["discrete-event-simulation"])


# ==================== REQUEST/RESPONSE MODELS ====================

class PatientStateRequest(BaseModel):
    """Request model for creating patient state"""
    state_id: str = Field(..., description="Unique state identifier")
    state_name: str = Field(..., description="Human-readable state name")
    utility: float = Field(..., ge=0.0, le=1.0, description="Quality of life (0-1)")
    cost_per_cycle: float = Field(..., ge=0, description="Cost per time period in this state")
    transition_probabilities: Dict[str, float] = Field(default_factory=dict, description="Probabilities to other states")
    absorbing: bool = Field(default=False, description="Cannot leave this state (e.g., Death)")
    duration_mean: Optional[float] = Field(default=None, description="Average duration in state")
    duration_sd: Optional[float] = Field(default=None, description="Standard deviation of duration")


class PatientPathwayRequest(BaseModel):
    """Request model for creating patient pathway"""
    pathway_id: str = Field(..., description="Unique pathway identifier")
    pathway_name: str = Field(..., description="Human-readable pathway name")
    states: List[PatientStateRequest] = Field(..., description="List of patient states")
    initial_state: str = Field(..., description="Starting state ID")
    intervention: Optional[str] = Field(default=None, description="Intervention name")
    cycle_length: float = Field(default=1.0, description="Years per cycle")
    time_horizon: float = Field(default=10.0, description="Total simulation time (years)")


class ResourceRequest(BaseModel):
    """Request model for creating resource"""
    resource_id: str = Field(..., description="Unique resource identifier")
    resource_type: str = Field(..., description="Type: bed, icu_bed, nurse, doctor, etc.")
    capacity: int = Field(..., ge=1, description="Total capacity")
    cost_per_unit: float = Field(..., ge=0, description="Cost per unit per time period")
    cost_per_use: float = Field(default=0.0, ge=0, description="One-time cost per use")


class SimulationConfigRequest(BaseModel):
    """Request model for simulation configuration"""
    time_horizon: float = Field(default=10.0, ge=0, description="Simulation time horizon (years)")
    cycle_length: float = Field(default=1.0, gt=0, description="Years per cycle")
    n_patients: int = Field(default=1000, ge=1, le=100000, description="Number of patients to simulate")
    discount_rate_costs: float = Field(default=0.035, ge=0, le=1, description="Annual discount rate for costs")
    discount_rate_qalys: float = Field(default=0.035, ge=0, le=1, description="Annual discount rate for QALYs")
    willingness_to_pay: float = Field(default=30000.0, ge=0, description="Willingness-to-pay threshold (£ per QALY)")
    run_psa: bool = Field(default=False, description="Run probabilistic sensitivity analysis")
    n_psa_iterations: int = Field(default=1000, ge=1, le=10000, description="Number of PSA iterations")
    random_seed: Optional[int] = Field(default=None, description="Random seed for reproducibility")


class SimulationRequest(BaseModel):
    """Complete simulation request"""
    pathway: PatientPathwayRequest = Field(..., description="Patient pathway to simulate")
    config: SimulationConfigRequest = Field(..., description="Simulation configuration")
    resources: Optional[List[ResourceRequest]] = Field(default=None, description="Healthcare resources")


class CompareInterventionsRequest(BaseModel):
    """Request to compare multiple interventions"""
    pathways: List[PatientPathwayRequest] = Field(..., min_items=2, description="Pathways to compare (2+)")
    config: SimulationConfigRequest = Field(..., description="Simulation configuration")
    comparator_index: int = Field(default=0, description="Index of comparator pathway")


class SimulationResponse(BaseModel):
    """Simulation results response"""
    simulation_id: str
    total_costs: float
    total_qalys: float
    total_patients: int
    simulation_time: float
    state_occupancy: Dict[str, float]
    costs_by_category: Dict[str, float]
    icer: Optional[float] = None
    nmb: Optional[float] = None
    cost_effective: Optional[bool] = None
    created_at: str


class PSAResultsResponse(BaseModel):
    """PSA results response"""
    n_iterations: int
    mean_cost: float
    mean_qalys: float
    cost_95ci_lower: float
    cost_95ci_upper: float
    qalys_95ci_lower: float
    qalys_95ci_upper: float
    probability_cost_effective: float
    iterations: List[Dict[str, float]]


# ==================== UTILITY FUNCTIONS ====================

def _convert_state_request_to_model(state_req: PatientStateRequest) -> PatientState:
    """Convert API request model to internal PatientState"""
    return PatientState(
        state_id=state_req.state_id,
        state_name=state_req.state_name,
        utility=state_req.utility,
        cost_per_cycle=state_req.cost_per_cycle,
        transition_probabilities=state_req.transition_probabilities,
        absorbing=state_req.absorbing,
        duration_mean=state_req.duration_mean,
        duration_sd=state_req.duration_sd
    )


def _convert_pathway_request_to_model(pathway_req: PatientPathwayRequest) -> PatientPathway:
    """Convert API request model to internal PatientPathway"""
    states = [_convert_state_request_to_model(s) for s in pathway_req.states]

    return PatientPathway(
        pathway_id=pathway_req.pathway_id,
        pathway_name=pathway_req.pathway_name,
        states=states,
        initial_state=pathway_req.initial_state,
        intervention=pathway_req.intervention,
        cycle_length=pathway_req.cycle_length,
        time_horizon=pathway_req.time_horizon
    )


def _convert_config_request_to_model(config_req: SimulationConfigRequest) -> SimulationConfig:
    """Convert API request model to internal SimulationConfig"""
    return SimulationConfig(
        time_horizon=config_req.time_horizon,
        cycle_length=config_req.cycle_length,
        n_patients=config_req.n_patients,
        discount_rate_costs=config_req.discount_rate_costs,
        discount_rate_qalys=config_req.discount_rate_qalys,
        willingness_to_pay=config_req.willingness_to_pay,
        run_psa=config_req.run_psa,
        n_psa_iterations=config_req.n_psa_iterations,
        random_seed=config_req.random_seed
    )


def _generate_simulation_id() -> str:
    """Generate unique simulation ID"""
    from uuid import uuid4
    return f"sim_{uuid4().hex[:12]}"


# ==================== API ENDPOINTS ====================

@router.post("/run", response_model=SimulationResponse)
async def run_simulation(
    request: SimulationRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Run discrete event simulation

    Simulates patient cohort through health states, accumulating costs and QALYs.

    Features:
    - Markov state transitions
    - Resource constraints
    - Cost and QALY discounting (NICE-compliant)
    - State occupancy tracking

    Returns:
        Simulation results with costs, QALYs, and statistics

    Example:
        ```python
        {
            "pathway": {
                "pathway_id": "standard_care",
                "pathway_name": "Standard Care",
                "states": [
                    {
                        "state_id": "healthy",
                        "state_name": "Healthy",
                        "utility": 1.0,
                        "cost_per_cycle": 100,
                        "transition_probabilities": {"disease": 0.05, "death": 0.01}
                    },
                    ...
                ],
                "initial_state": "healthy"
            },
            "config": {
                "time_horizon": 10,
                "n_patients": 1000,
                "discount_rate_costs": 0.035
            }
        }
        ```
    """
    try:
        logger.info(f"Running DES simulation for user: {current_user.username}")

        # Convert request models to internal models
        pathway = _convert_pathway_request_to_model(request.pathway)
        config = _convert_config_request_to_model(request.config)

        # Create simulation
        sim = DiscreteEventSimulation(config)
        sim.add_pathway(pathway)

        # Add resources if provided
        if request.resources:
            for res_req in request.resources:
                resource = Resource(
                    resource_id=res_req.resource_id,
                    resource_type=ResourceType[res_req.resource_type.upper()],
                    capacity=res_req.capacity,
                    available=res_req.capacity,
                    cost_per_unit=res_req.cost_per_unit,
                    cost_per_use=res_req.cost_per_use
                )
                sim.add_resource(resource)

        # Run simulation
        results = sim.run()

        # Generate response
        simulation_id = _generate_simulation_id()

        # Calculate cost-effectiveness
        cost_effective = None
        if results.icer is not None:
            cost_effective = results.is_cost_effective(config.willingness_to_pay)

        response = SimulationResponse(
            simulation_id=simulation_id,
            total_costs=results.total_costs,
            total_qalys=results.total_qalys,
            total_patients=results.total_patients,
            simulation_time=results.simulation_time,
            state_occupancy=results.state_occupancy,
            costs_by_category={k.value: v for k, v in results.costs_by_category.items()},
            icer=results.icer,
            nmb=results.nmb,
            cost_effective=cost_effective,
            created_at=datetime.utcnow().isoformat()
        )

        logger.info(f"✓ Simulation complete: £{results.total_costs:,.0f}, {results.total_qalys:.2f} QALYs")

        return response

    except Exception as e:
        logger.error(f"Simulation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Simulation failed: {str(e)}"
        )


@router.post("/run-psa", response_model=PSAResultsResponse)
async def run_psa(
    request: SimulationRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Run Probabilistic Sensitivity Analysis (PSA)

    Runs simulation multiple times with sampled parameter values to assess uncertainty.

    Features:
    - Monte Carlo simulation
    - Parameter sampling from distributions
    - Confidence intervals
    - Probability of cost-effectiveness

    Returns:
        PSA results with mean, CI, and individual iterations

    Note: Can be computationally expensive for large n_psa_iterations
    """
    try:
        logger.info(f"Running PSA for user: {current_user.username}")

        # Convert request models
        pathway = _convert_pathway_request_to_model(request.pathway)
        config = _convert_config_request_to_model(request.config)

        # Force PSA mode
        config.run_psa = True

        # Create simulation
        sim = DiscreteEventSimulation(config)
        sim.add_pathway(pathway)

        # Run PSA
        psa_results = sim.run_psa(config.n_psa_iterations)

        # Calculate statistics
        import numpy as np

        costs = [r.total_costs for r in psa_results]
        qalys = [r.total_qalys for r in psa_results]

        mean_cost = np.mean(costs)
        mean_qalys = np.mean(qalys)

        cost_95ci = np.percentile(costs, [2.5, 97.5])
        qalys_95ci = np.percentile(qalys, [2.5, 97.5])

        # Calculate probability of cost-effectiveness
        nmbs = [
            (r.total_qalys * config.willingness_to_pay) - r.total_costs
            for r in psa_results
        ]
        prob_cost_effective = sum(1 for nmb in nmbs if nmb > 0) / len(nmbs)

        # Prepare iterations data
        iterations = [
            {
                "iteration": i,
                "cost": r.total_costs,
                "qalys": r.total_qalys,
                "nmb": (r.total_qalys * config.willingness_to_pay) - r.total_costs
            }
            for i, r in enumerate(psa_results)
        ]

        response = PSAResultsResponse(
            n_iterations=config.n_psa_iterations,
            mean_cost=mean_cost,
            mean_qalys=mean_qalys,
            cost_95ci_lower=cost_95ci[0],
            cost_95ci_upper=cost_95ci[1],
            qalys_95ci_lower=qalys_95ci[0],
            qalys_95ci_upper=qalys_95ci[1],
            probability_cost_effective=prob_cost_effective,
            iterations=iterations
        )

        logger.info(f"✓ PSA complete: {config.n_psa_iterations} iterations, P(CE)={prob_cost_effective:.2%}")

        return response

    except Exception as e:
        logger.error(f"PSA error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"PSA failed: {str(e)}"
        )


@router.post("/compare-interventions")
async def compare_interventions(
    request: CompareInterventionsRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Compare multiple interventions

    Runs simulations for multiple pathways (interventions) and compares:
    - Incremental costs
    - Incremental QALYs
    - ICER (Incremental Cost-Effectiveness Ratio)
    - Net Monetary Benefit

    Returns:
        Comparison table with ICERs and cost-effectiveness decisions

    Example:
        ```python
        {
            "pathways": [
                {...},  # Standard care
                {...},  # Intervention A
                {...}   # Intervention B
            ],
            "comparator_index": 0,  # Standard care is comparator
            "config": {...}
        }
        ```
    """
    try:
        logger.info(f"Comparing {len(request.pathways)} interventions for user: {current_user.username}")

        # Convert config
        config = _convert_config_request_to_model(request.config)

        # Run simulations for all pathways
        results = []
        for pathway_req in request.pathways:
            pathway = _convert_pathway_request_to_model(pathway_req)

            sim = DiscreteEventSimulation(config)
            sim.add_pathway(pathway)

            sim_results = sim.run()
            results.append({
                "pathway_id": pathway.pathway_id,
                "pathway_name": pathway.pathway_name,
                "total_costs": sim_results.total_costs,
                "total_qalys": sim_results.total_qalys,
                "state_occupancy": sim_results.state_occupancy
            })

        # Get comparator
        comparator = results[request.comparator_index]

        # Calculate incremental analysis
        comparisons = []
        for i, result in enumerate(results):
            if i == request.comparator_index:
                # This is the comparator
                comparisons.append({
                    "pathway_name": result["pathway_name"],
                    "total_costs": result["total_costs"],
                    "total_qalys": result["total_qalys"],
                    "incremental_costs": 0.0,
                    "incremental_qalys": 0.0,
                    "icer": None,
                    "nmb": (result["total_qalys"] * config.willingness_to_pay) - result["total_costs"],
                    "cost_effective": "Comparator",
                    "decision": "Comparator"
                })
            else:
                # Calculate vs comparator
                inc_cost = result["total_costs"] - comparator["total_costs"]
                inc_qalys = result["total_qalys"] - comparator["total_qalys"]

                # Calculate ICER
                if abs(inc_qalys) < 0.0001:
                    icer = None
                    decision = "Same effectiveness"
                else:
                    icer = inc_cost / inc_qalys

                    if icer < 0:
                        decision = "Dominant (cheaper and more effective)"
                    elif icer < config.willingness_to_pay:
                        decision = f"Cost-effective (ICER < £{config.willingness_to_pay:,.0f})"
                    else:
                        decision = f"Not cost-effective (ICER > £{config.willingness_to_pay:,.0f})"

                # Calculate NMB
                nmb = (result["total_qalys"] * config.willingness_to_pay) - result["total_costs"]
                cost_effective = nmb > 0

                comparisons.append({
                    "pathway_name": result["pathway_name"],
                    "total_costs": result["total_costs"],
                    "total_qalys": result["total_qalys"],
                    "incremental_costs": inc_cost,
                    "incremental_qalys": inc_qalys,
                    "icer": icer,
                    "nmb": nmb,
                    "cost_effective": cost_effective,
                    "decision": decision
                })

        logger.info(f"✓ Comparison complete for {len(request.pathways)} interventions")

        return {
            "comparator": comparator["pathway_name"],
            "willingness_to_pay": config.willingness_to_pay,
            "comparisons": comparisons,
            "n_patients": config.n_patients,
            "time_horizon": config.time_horizon
        }

    except Exception as e:
        logger.error(f"Comparison error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Comparison failed: {str(e)}"
        )


@router.get("/status")
async def des_status():
    """
    Get DES system status

    Returns:
        System information and capabilities
    """
    return {
        "status": "operational",
        "version": "1.0.0",
        "capabilities": {
            "markov_models": True,
            "patient_level_simulation": True,
            "resource_constraints": True,
            "psa": True,
            "intervention_comparison": True,
            "nice_compliant": True
        },
        "defaults": {
            "discount_rate_costs": 0.035,
            "discount_rate_qalys": 0.035,
            "willingness_to_pay": 30000,
            "cycle_length": 1.0
        },
        "limits": {
            "max_patients": 100000,
            "max_psa_iterations": 10000,
            "max_time_horizon": 100
        },
        "competitive_position": {
            "vs_treeage": "Free (TreeAge: $1,495/year)",
            "vs_r_heemod": "Integrated platform with UI",
            "vs_excel": "Reproducible, scalable, validated"
        }
    }


# Example endpoints for pre-built models

@router.get("/examples")
async def get_example_models():
    """
    Get example DES models

    Returns:
        List of pre-built example models for common scenarios
    """
    return {
        "examples": [
            {
                "id": "3_state_model",
                "name": "Simple 3-State Model",
                "description": "Healthy → Disease → Death",
                "use_case": "Basic disease progression"
            },
            {
                "id": "5_state_cancer",
                "name": "5-State Cancer Model",
                "description": "Healthy → Local → Regional → Metastatic → Death",
                "use_case": "Cancer progression analysis"
            },
            {
                "id": "hiv_treatment",
                "name": "HIV Treatment Model",
                "description": "CD4 count-based progression",
                "use_case": "HIV intervention comparison"
            }
        ]
    }
