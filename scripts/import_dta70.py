#!/usr/bin/env python3
"""
Import real Diagnostic Test Accuracy data from DTA70 repository
Convert .rda files to CSV format for validation
"""

import pyreadr
import pandas as pd
import os
from pathlib import Path
import numpy as np

def read_rda_file(filepath):
    """Read single .rda file and return dataframe"""
    try:
        result = pyreadr.read_r(filepath)
        # Get first (and usually only) dataframe from the result
        df_name = list(result.keys())[0]
        df = result[df_name]
        return df
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return None

def extract_dta_id(filename):
    """Extract DTA ID from filename"""
    # e.g., COVID_AntigenTests_Cochrane2021.rda -> COVID_AntigenTests_Cochrane2021
    return filename.replace('.rda', '')

def calculate_diagnostic_metrics(df):
    """Calculate sensitivity, specificity, and other diagnostic metrics"""

    # Standard DTA columns are: TP, FP, FN, TN
    required_cols = ['TP', 'FP', 'FN', 'TN']

    # Check if all required columns exist (case-insensitive)
    df_cols_lower = {col.lower(): col for col in df.columns}

    tp_col = df_cols_lower.get('tp')
    fp_col = df_cols_lower.get('fp')
    fn_col = df_cols_lower.get('fn')
    tn_col = df_cols_lower.get('tn')

    if all([tp_col, fp_col, fn_col, tn_col]):
        # Calculate metrics
        df['sensitivity'] = df[tp_col] / (df[tp_col] + df[fn_col])
        df['specificity'] = df[tn_col] / (df[tn_col] + df[fp_col])
        df['ppv'] = df[tp_col] / (df[tp_col] + df[fp_col])
        df['npv'] = df[tn_col] / (df[tn_col] + df[fn_col])

        # Likelihood ratios
        df['lr_positive'] = df['sensitivity'] / (1 - df['specificity'])
        df['lr_negative'] = (1 - df['sensitivity']) / df['specificity']

        # Diagnostic odds ratio
        df['dor'] = (df[tp_col] * df[tn_col]) / (df[fp_col] * df[fn_col])

        # Replace inf with NaN
        df = df.replace([np.inf, -np.inf], np.nan)

    return df

def process_all_dta70():
    """Process all DTA70 .rda files and combine into unified dataset"""

    print("=" * 80)
    print("IMPORTING REAL DIAGNOSTIC TEST ACCURACY DATA FROM DTA70")
    print("=" * 80)

    data_dir = Path("/home/user/DTA70/data")
    rda_files = sorted(data_dir.glob("*.rda"))

    print(f"\nFound {len(rda_files)} .rda files")

    all_studies = []
    dta_summaries = []

    for i, rda_file in enumerate(rda_files, 1):
        print(f"Processing {i}/{len(rda_files)}: {rda_file.name}")

        # Extract DTA ID
        dta_id = extract_dta_id(rda_file.name)

        # Read .rda file
        df = read_rda_file(str(rda_file))

        if df is None or len(df) == 0:
            print(f"  ⚠️  Skipped (empty or error)")
            continue

        # Add identifiers
        df['dta_id'] = dta_id
        df['dta_ma_id'] = f"DTA{i:03d}"
        df['source'] = 'DTA70'
        df['data_type'] = 'real_dta'

        # Calculate diagnostic metrics
        df = calculate_diagnostic_metrics(df)

        # Store individual studies
        all_studies.append(df)

        # Create DTA meta-analysis summary
        # Check for TP/FP/FN/TN columns
        df_cols_lower = {col.lower(): col for col in df.columns}
        tp_col = df_cols_lower.get('tp')
        fp_col = df_cols_lower.get('fp')
        fn_col = df_cols_lower.get('fn')
        tn_col = df_cols_lower.get('tn')

        if all([tp_col, fp_col, fn_col, tn_col]):
            total_diseased = df[tp_col].sum() + df[fn_col].sum()
            total_non_diseased = df[fp_col].sum() + df[tn_col].sum()
            total_participants = total_diseased + total_non_diseased
        else:
            total_diseased = np.nan
            total_non_diseased = np.nan
            total_participants = np.nan

        # Calculate pooled sensitivity and specificity if available
        if 'sensitivity' in df.columns and 'specificity' in df.columns:
            pooled_sens = df['sensitivity'].mean()
            pooled_spec = df['specificity'].mean()
        else:
            pooled_sens = np.nan
            pooled_spec = np.nan

        dta_summary = {
            'dta_id': dta_id,
            'dta_ma_id': f"DTA{i:03d}",
            'source': 'DTA70',
            'n_studies': len(df),
            'total_diseased': total_diseased,
            'total_non_diseased': total_non_diseased,
            'total_participants': total_participants,
            'pooled_sensitivity': pooled_sens,
            'pooled_specificity': pooled_spec,
            'filename': rda_file.name,
            'data_type': 'real_dta'
        }

        dta_summaries.append(dta_summary)

        if pd.notna(total_participants):
            print(f"  ✅ {len(df)} studies, {total_participants:.0f} participants")
        else:
            print(f"  ✅ {len(df)} studies, N/A participants")

    print(f"\n✅ Processed {len(dta_summaries)} DTA meta-analyses")

    # Combine all studies
    if all_studies:
        combined_studies = pd.concat(all_studies, ignore_index=True)
        print(f"✅ Combined {len(combined_studies):,} individual DTA study records")
    else:
        combined_studies = pd.DataFrame()

    # Create DTA summaries dataframe
    dta_summaries_df = pd.DataFrame(dta_summaries)

    return combined_studies, dta_summaries_df

def save_datasets(studies_df, summaries_df):
    """Save converted datasets to CSV"""

    output_dir = Path("/home/user/Metanew/data/validation_datasets")
    output_dir.mkdir(parents=True, exist_ok=True)

    # Save individual study-level data
    studies_file = output_dir / "dta70_real_diagnostic_studies.csv"
    studies_df.to_csv(studies_file, index=False, encoding='utf-8')

    print(f"\n✅ Saved DTA study-level data: {studies_file}")
    print(f"   Records: {len(studies_df):,}")
    print(f"   Columns: {len(studies_df.columns)}")

    # Save DTA meta-analysis summaries
    summaries_file = output_dir / "dta70_real_diagnostic_summaries.csv"
    summaries_df.to_csv(summaries_file, index=False, encoding='utf-8')

    print(f"\n✅ Saved DTA MA summaries: {summaries_file}")
    print(f"   Records: {len(summaries_df):,}")

    # Display sample data
    print("\n" + "=" * 80)
    print("SAMPLE DATA (First 5 studies)")
    print("=" * 80)
    print(studies_df.head())

    print("\n" + "=" * 80)
    print("COLUMN NAMES")
    print("=" * 80)
    print(studies_df.columns.tolist())

    print("\n" + "=" * 80)
    print("DATA SUMMARY")
    print("=" * 80)
    print(f"Total DTA meta-analyses: {len(summaries_df):,}")
    print(f"Total DTA study records: {len(studies_df):,}")
    print(f"Average studies per DTA MA: {len(studies_df)/len(summaries_df):.1f}")

    # Diagnostic accuracy summary
    if 'sensitivity' in studies_df.columns:
        print(f"\nSensitivity: Mean={studies_df['sensitivity'].mean():.3f}, Median={studies_df['sensitivity'].median():.3f}")
    if 'specificity' in studies_df.columns:
        print(f"Specificity: Mean={studies_df['specificity'].mean():.3f}, Median={studies_df['specificity'].median():.3f}")

    print(f"\nStudies per MA distribution:")
    print(summaries_df['n_studies'].describe())

if __name__ == "__main__":
    # Process all DTA70 data
    studies_df, summaries_df = process_all_dta70()

    # Save datasets
    if len(studies_df) > 0:
        save_datasets(studies_df, summaries_df)
        print("\n✅ DTA IMPORT COMPLETE")
    else:
        print("\n❌ No DTA data extracted")
