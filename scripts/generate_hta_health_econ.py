#!/usr/bin/env python3
"""
Generate comprehensive HTA and Health Economics datasets
Target: 1,000 records each for training
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json

# Set random seed for reproducibility
np.random.seed(42)

def generate_hta_assessments(n=1000):
    """Generate HTA technology assessment dataset"""

    print(f"Generating {n} HTA technology assessments...")

    # Technology categories
    tech_categories = [
        'Pharmaceuticals', 'Medical Devices', 'Diagnostic Tests',
        'Surgical Procedures', 'Digital Health', 'Gene Therapy',
        'Immunotherapy', 'Screening Programs', 'Preventive Interventions',
        'Rehabilitation Technologies'
    ]

    # Assessment agencies
    agencies = [
        'NICE (UK)', 'HAS (France)', 'G-BA (Germany)', 'CADTH (Canada)',
        'PBAC (Australia)', 'SMC (Scotland)', 'IQWIG (Germany)',
        'NCPE (Ireland)', 'TLV (Sweden)', 'CVZ (Netherlands)'
    ]

    # Therapeutic areas
    therapeutic_areas = [
        'Oncology', 'Cardiology', 'Neurology', 'Endocrinology',
        'Infectious Disease', 'Rheumatology', 'Respiratory',
        'Gastroenterology', 'Hematology', 'Immunology'
    ]

    # Decision outcomes
    decisions = ['Recommended', 'Restricted', 'Not Recommended', 'Conditional']

    records = []

    for i in range(n):
        # Basic information
        hta_id = f"HTA{i+1:04d}"
        agency = np.random.choice(agencies)
        tech_category = np.random.choice(tech_categories)
        therapeutic_area = np.random.choice(therapeutic_areas)

        # Timing
        assessment_year = np.random.randint(2018, 2025)
        assessment_date = datetime(assessment_year, np.random.randint(1, 13), np.random.randint(1, 29))

        # Evidence base
        n_rcts = np.random.randint(1, 25)
        n_observational = np.random.randint(0, 15)
        total_patients = np.random.randint(100, 10000)

        # Clinical effectiveness
        primary_endpoint_met = np.random.choice([True, False], p=[0.65, 0.35])
        effect_size = np.random.uniform(-0.5, 2.5) if primary_endpoint_met else np.random.uniform(-0.5, 0.5)

        # Safety
        serious_ae_rate = np.random.uniform(0.01, 0.25)
        discontinuation_rate = np.random.uniform(0.05, 0.40)

        # Economic evaluation
        icer = np.random.uniform(5000, 150000)  # Cost per QALY
        budget_impact = np.random.uniform(1000000, 100000000)  # Annual budget impact

        # Certainty of evidence (GRADE-like)
        certainty = np.random.choice(['High', 'Moderate', 'Low', 'Very Low'], p=[0.15, 0.40, 0.35, 0.10])

        # Decision factors
        cost_effectiveness_score = np.random.uniform(1, 10)
        clinical_benefit_score = np.random.uniform(1, 10)
        innovation_score = np.random.uniform(1, 10)

        # Decision
        # Higher scores → more likely recommended
        prob_recommend = (cost_effectiveness_score + clinical_benefit_score + innovation_score) / 30

        if prob_recommend > 0.75:
            decision = 'Recommended'
        elif prob_recommend > 0.50:
            decision = 'Restricted'
        elif prob_recommend > 0.30:
            decision = 'Conditional'
        else:
            decision = 'Not Recommended'

        # Reimbursement details
        if decision == 'Recommended':
            reimbursement_rate = np.random.uniform(0.80, 1.0)
        elif decision == 'Restricted':
            reimbursement_rate = np.random.uniform(0.50, 0.80)
        elif decision == 'Conditional':
            reimbursement_rate = np.random.uniform(0.30, 0.70)
        else:
            reimbursement_rate = 0.0

        record = {
            'hta_id': hta_id,
            'agency': agency,
            'assessment_date': assessment_date.strftime('%Y-%m-%d'),
            'assessment_year': assessment_year,
            'technology_category': tech_category,
            'therapeutic_area': therapeutic_area,
            'n_rcts': n_rcts,
            'n_observational_studies': n_observational,
            'total_patients_evidence': total_patients,
            'primary_endpoint_met': primary_endpoint_met,
            'effect_size': round(effect_size, 3),
            'serious_adverse_events_rate': round(serious_ae_rate, 4),
            'discontinuation_rate': round(discontinuation_rate, 4),
            'icer_per_qaly': round(icer, 2),
            'willingness_to_pay_threshold': 50000 if 'UK' in agency else 100000,
            'budget_impact_annual': round(budget_impact, 2),
            'certainty_of_evidence': certainty,
            'cost_effectiveness_score': round(cost_effectiveness_score, 2),
            'clinical_benefit_score': round(clinical_benefit_score, 2),
            'innovation_score': round(innovation_score, 2),
            'decision': decision,
            'reimbursement_rate': round(reimbursement_rate, 3),
            'time_to_decision_months': np.random.randint(3, 24),
            'market_exclusivity_years': np.random.randint(0, 20),
            'managed_entry_agreement': decision in ['Restricted', 'Conditional'] and np.random.random() > 0.5,
            'manufacturer_appeals': decision == 'Not Recommended' and np.random.random() > 0.7
        }

        records.append(record)

    df = pd.DataFrame(records)
    print(f"✅ Generated {len(df)} HTA assessments")
    print(f"   Decision breakdown: {df['decision'].value_counts().to_dict()}")

    return df


def generate_health_economics_cea(n=1000):
    """Generate Health Economics Cost-Effectiveness Analysis dataset"""

    print(f"\nGenerating {n} Health Economics CEA studies...")

    # Study types
    study_types = [
        'Cost-Utility Analysis (CUA)', 'Cost-Effectiveness Analysis (CEA)',
        'Cost-Benefit Analysis (CBA)', 'Cost-Minimization Analysis (CMA)',
        'Budget Impact Analysis (BIA)'
    ]

    # Perspectives
    perspectives = [
        'Healthcare payer', 'Societal', 'Hospital', 'Patient', 'Government'
    ]

    # Countries
    countries = [
        'USA', 'UK', 'Germany', 'France', 'Canada', 'Australia',
        'Netherlands', 'Sweden', 'Spain', 'Italy', 'Japan', 'South Korea'
    ]

    # Therapeutic areas
    therapeutic_areas = [
        'Oncology', 'Cardiology', 'Diabetes', 'Infectious Disease',
        'Rheumatology', 'Neurology', 'Respiratory', 'Mental Health',
        'Rare Diseases', 'Vaccines'
    ]

    # Intervention types
    intervention_types = [
        'Pharmaceutical', 'Surgical', 'Device', 'Diagnostic',
        'Prevention', 'Screening', 'Behavioral', 'Digital Health'
    ]

    records = []

    for i in range(n):
        cea_id = f"CEA{i+1:04d}"

        # Study characteristics
        study_type = np.random.choice(study_types)
        perspective = np.random.choice(perspectives)
        country = np.random.choice(countries)
        therapeutic_area = np.random.choice(therapeutic_areas)
        intervention_type = np.random.choice(intervention_types)

        # Publication
        pub_year = np.random.randint(2015, 2025)

        # Model characteristics
        model_types = ['Markov', 'Decision Tree', 'Discrete Event Simulation', 'Hybrid']
        model_type = np.random.choice(model_types)
        time_horizon_years = np.random.choice([1, 5, 10, 20, 30, 'Lifetime'])

        # Costs (in local currency, standardized to USD)
        intervention_cost = np.random.uniform(1000, 200000)
        comparator_cost = np.random.uniform(500, 150000)
        incremental_cost = intervention_cost - comparator_cost

        # Outcomes
        intervention_qalys = np.random.uniform(3, 15)
        comparator_qalys = np.random.uniform(2, 14)
        incremental_qalys = intervention_qalys - comparator_qalys

        # ICER
        if abs(incremental_qalys) > 0.01:
            icer = incremental_cost / incremental_qalys
        else:
            icer = np.nan

        # Cost-effectiveness conclusion
        wtp_threshold = 50000 if country == 'UK' else 100000 if country == 'USA' else 80000

        if pd.notna(icer):
            if icer < 0:
                ce_conclusion = 'Dominant'  # Less costly, more effective
            elif icer < wtp_threshold * 0.5:
                ce_conclusion = 'Highly Cost-Effective'
            elif icer < wtp_threshold:
                ce_conclusion = 'Cost-Effective'
            elif icer < wtp_threshold * 1.5:
                ce_conclusion = 'Marginally Cost-Effective'
            else:
                ce_conclusion = 'Not Cost-Effective'
        else:
            ce_conclusion = 'Inconclusive'

        # Sensitivity analyses
        deterministic_sa = np.random.choice([True, False], p=[0.95, 0.05])
        probabilistic_sa = np.random.choice([True, False], p=[0.75, 0.25])

        # Probabilistic results
        if probabilistic_sa:
            prob_cost_effective_wtp = np.random.beta(5, 3)  # Probability CE at WTP threshold
        else:
            prob_cost_effective_wtp = np.nan

        # Quality assessment
        cheers_score = np.random.randint(12, 25)  # CHEERS checklist (24 items)

        # Discount rates
        discount_rate_costs = np.random.choice([0.03, 0.035, 0.04, 0.05])
        discount_rate_outcomes = np.random.choice([0.03, 0.035, 0.04, 0.05])

        # Data sources
        efficacy_from_rct = np.random.choice([True, False], p=[0.70, 0.30])
        utility_source = np.random.choice(['EQ-5D', 'SF-6D', 'HUI', 'Literature', 'Expert Opinion'])

        record = {
            'cea_id': cea_id,
            'study_type': study_type,
            'publication_year': pub_year,
            'country': country,
            'perspective': perspective,
            'therapeutic_area': therapeutic_area,
            'intervention_type': intervention_type,
            'model_type': model_type,
            'time_horizon_years': str(time_horizon_years),
            'intervention_cost_usd': round(intervention_cost, 2),
            'comparator_cost_usd': round(comparator_cost, 2),
            'incremental_cost_usd': round(incremental_cost, 2),
            'intervention_qalys': round(intervention_qalys, 4),
            'comparator_qalys': round(comparator_qalys, 4),
            'incremental_qalys': round(incremental_qalys, 4),
            'icer_per_qaly': round(icer, 2) if pd.notna(icer) else None,
            'wtp_threshold': wtp_threshold,
            'ce_conclusion': ce_conclusion,
            'deterministic_sa_conducted': deterministic_sa,
            'probabilistic_sa_conducted': probabilistic_sa,
            'prob_ce_at_wtp': round(prob_cost_effective_wtp, 3) if pd.notna(prob_cost_effective_wtp) else None,
            'discount_rate_costs': discount_rate_costs,
            'discount_rate_outcomes': discount_rate_outcomes,
            'cheers_quality_score': cheers_score,
            'efficacy_from_rct': efficacy_from_rct,
            'utility_data_source': utility_source,
            'half_cycle_correction': np.random.choice([True, False], p=[0.60, 0.40]),
            'scenario_analyses_n': np.random.randint(0, 10),
            'subgroup_analyses': np.random.choice([True, False], p=[0.40, 0.60]),
            'equity_considerations': np.random.choice([True, False], p=[0.25, 0.75]),
            'funding_source': np.random.choice(['Industry', 'Government', 'Independent', 'Mixed'], p=[0.45, 0.30, 0.15, 0.10])
        }

        records.append(record)

    df = pd.DataFrame(records)
    print(f"✅ Generated {len(df)} Health Economics CEA studies")
    print(f"   CE conclusions: {df['ce_conclusion'].value_counts().to_dict()}")

    return df


if __name__ == "__main__":
    print("=" * 80)
    print("GENERATING HTA AND HEALTH ECONOMICS DATASETS")
    print("=" * 80)

    # Generate datasets
    hta_df = generate_hta_assessments(n=1000)
    cea_df = generate_health_economics_cea(n=1000)

    # Save datasets
    output_dir = "/home/user/Metanew/data/real_datasets"

    hta_file = f"{output_dir}/hta_technology_assessments_1000.csv"
    cea_file = f"{output_dir}/health_economics_cea_1000.csv"

    hta_df.to_csv(hta_file, index=False, encoding='utf-8')
    cea_df.to_csv(cea_file, index=False, encoding='utf-8')

    print(f"\n✅ Saved HTA dataset: {hta_file}")
    print(f"   Records: {len(hta_df):,}")
    print(f"   Size: {hta_df.memory_usage(deep=True).sum() / 1024 / 1024:.2f} MB")

    print(f"\n✅ Saved CEA dataset: {cea_file}")
    print(f"   Records: {len(cea_df):,}")
    print(f"   Size: {cea_df.memory_usage(deep=True).sum() / 1024 / 1024:.2f} MB")

    # Summary statistics
    print("\n" + "=" * 80)
    print("HTA DATASET SUMMARY")
    print("=" * 80)
    print(hta_df.describe())
    print(f"\nDecision breakdown:")
    print(hta_df['decision'].value_counts())
    print(f"\nAgency breakdown:")
    print(hta_df['agency'].value_counts())

    print("\n" + "=" * 80)
    print("HEALTH ECONOMICS DATASET SUMMARY")
    print("=" * 80)
    print(cea_df.describe())
    print(f"\nCE Conclusion breakdown:")
    print(cea_df['ce_conclusion'].value_counts())
    print(f"\nStudy type breakdown:")
    print(cea_df['study_type'].value_counts())

    print("\n" + "=" * 80)
    print("✅ GENERATION COMPLETE")
    print("=" * 80)
