#!/usr/bin/env python3
"""
Import real Cochrane data from Pairwise70 repository
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

def extract_cochrane_id(filename):
    """Extract Cochrane review ID from filename"""
    # e.g., CD000028_pub4_data.rda -> CD000028
    parts = filename.replace('.rda', '').split('_')
    return parts[0]

def process_all_pairwise70():
    """Process all Pairwise70 .rda files and combine into unified dataset"""

    print("=" * 80)
    print("IMPORTING REAL COCHRANE DATA FROM PAIRWISE70")
    print("=" * 80)

    data_dir = Path("/home/user/Pairwise70/data")
    rda_files = sorted(data_dir.glob("*.rda"))

    print(f"\nFound {len(rda_files)} .rda files")

    all_studies = []
    ma_summaries = []

    for i, rda_file in enumerate(rda_files, 1):
        if i % 50 == 0:
            print(f"Processing file {i}/{len(rda_files)}...")

        # Extract Cochrane ID
        cochrane_id = extract_cochrane_id(rda_file.name)

        # Read .rda file
        df = read_rda_file(str(rda_file))

        if df is None or len(df) == 0:
            continue

        # Add meta-analysis identifier
        df['cochrane_id'] = cochrane_id
        df['ma_id'] = f"REAL_MA{i:04d}"
        df['source'] = 'Pairwise70'
        df['data_type'] = 'real_cochrane'

        # Standardize column names (handle different possible column names)
        column_mapping = {}

        # Study identifier
        for col in df.columns:
            col_lower = col.lower()
            if 'study' in col_lower and 'id' in col_lower:
                column_mapping[col] = 'study_id'
            elif col_lower in ['year', 'pubyear', 'pub_year']:
                column_mapping[col] = 'year'
            elif col_lower in ['author', 'first_author']:
                column_mapping[col] = 'author'

        df = df.rename(columns=column_mapping)

        # Store individual studies
        all_studies.append(df)

        # Create meta-analysis summary
        # Try to calculate total participants from numeric columns containing 'n'
        total_participants = np.nan
        try:
            n_cols = df.columns[df.columns.str.contains('n', case=False)]
            numeric_n_cols = df[n_cols].select_dtypes(include=[np.number]).columns
            if len(numeric_n_cols) > 0:
                total_participants = df[numeric_n_cols].sum().sum()
        except:
            pass

        ma_summary = {
            'cochrane_id': cochrane_id,
            'ma_id': f"REAL_MA{i:04d}",
            'source': 'Pairwise70',
            'n_studies': len(df),
            'total_participants': total_participants,
            'filename': rda_file.name,
            'data_type': 'real_cochrane'
        }

        # Try to extract outcome information if available
        if 'outcome' in df.columns:
            ma_summary['outcome'] = df['outcome'].iloc[0] if len(df) > 0 else None

        ma_summaries.append(ma_summary)

    print(f"\n✅ Processed {len(ma_summaries)} meta-analyses")

    # Combine all studies
    if all_studies:
        combined_studies = pd.concat(all_studies, ignore_index=True)
        print(f"✅ Combined {len(combined_studies):,} individual RCT records")
    else:
        combined_studies = pd.DataFrame()

    # Create MA summaries dataframe
    ma_summaries_df = pd.DataFrame(ma_summaries)

    return combined_studies, ma_summaries_df

def save_datasets(studies_df, summaries_df):
    """Save converted datasets to CSV"""

    output_dir = Path("/home/user/Metanew/data/validation_datasets")
    output_dir.mkdir(parents=True, exist_ok=True)

    # Save individual study-level data
    studies_file = output_dir / "pairwise70_real_cochrane_studies.csv"
    studies_df.to_csv(studies_file, index=False, encoding='utf-8')

    print(f"\n✅ Saved study-level data: {studies_file}")
    print(f"   Records: {len(studies_df):,}")
    print(f"   Columns: {len(studies_df.columns)}")

    # Save meta-analysis summaries
    summaries_file = output_dir / "pairwise70_real_cochrane_summaries.csv"
    summaries_df.to_csv(summaries_file, index=False, encoding='utf-8')

    print(f"\n✅ Saved MA summaries: {summaries_file}")
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
    print(f"Total meta-analyses: {len(summaries_df):,}")
    print(f"Total RCT records: {len(studies_df):,}")
    print(f"Average studies per MA: {len(studies_df)/len(summaries_df):.1f}")
    print(f"\nStudies distribution:")
    print(summaries_df['n_studies'].describe())

if __name__ == "__main__":
    # Process all Pairwise70 data
    studies_df, summaries_df = process_all_pairwise70()

    # Save datasets
    if len(studies_df) > 0:
        save_datasets(studies_df, summaries_df)
        print("\n✅ IMPORT COMPLETE")
    else:
        print("\n❌ No data extracted")
