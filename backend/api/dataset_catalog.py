"""
Dataset Catalog API
Provides discovery and access to integrated meta-analysis datasets
from Pairwise70, NMA51, NMArepo, and DTA70
"""

from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field
import os
import json
import glob

router = APIRouter(prefix="/datasets", tags=["datasets"])


# ===== SCHEMAS =====

class Dataset(BaseModel):
    """Dataset metadata schema"""
    id: str = Field(..., description="Unique dataset identifier")
    name: str = Field(..., description="Dataset display name")
    source: str = Field(..., description="Source repository (Pairwise70, NMA51, NMArepo, DTA70)")
    type: str = Field(..., description="Dataset type (pairwise, nma, dta)")
    n_studies: Optional[int] = Field(None, description="Number of studies in dataset")
    outcome_type: Optional[str] = Field(None, description="Outcome type (binary, continuous, mixed)")
    review_doi: Optional[str] = Field(None, description="DOI of source systematic review")
    review_title: Optional[str] = Field(None, description="Title of source review")
    description: Optional[str] = Field(None, description="Dataset description")
    interventions: Optional[List[str]] = Field(None, description="List of interventions")
    comparisons: Optional[str] = Field(None, description="Comparison description")
    outcomes: Optional[List[str]] = Field(None, description="List of outcomes")
    file_path: Optional[str] = Field(None, description="Path to dataset file")
    file_size: Optional[int] = Field(None, description="File size in bytes")
    created_at: Optional[datetime] = Field(None, description="Dataset creation timestamp")


class DatasetSummary(BaseModel):
    """Summary statistics for datasets"""
    total_datasets: int
    by_source: Dict[str, int]
    by_type: Dict[str, int]
    total_studies: int


class AppRecommendation(BaseModel):
    """Recommended apps for a dataset"""
    app_id: str
    app_name: str
    compatibility: str  # "perfect", "good", "possible"
    reason: str


# ===== DATASET REGISTRY =====

DATASETS_DIR = "/home/user/Metanew/external_integrations"

# App-to-dataset type mapping
APP_DATASET_MAPPING = {
    # Pairwise apps
    "pairwise-or-rr": {"types": ["pairwise"], "outcome_types": ["binary"]},
    "pairwise-smd": {"types": ["pairwise"], "outcome_types": ["continuous"]},
    "pairwise-hr": {"types": ["pairwise"], "outcome_types": ["time-to-event"]},
    "pairwise-prop": {"types": ["pairwise"], "outcome_types": ["proportion"]},

    # NMA apps
    "nma-ror": {"types": ["nma"], "outcome_types": ["binary"]},
    "nma-hr": {"types": ["nma"], "outcome_types": ["time-to-event"]},
    "nma-metaregression": {"types": ["nma"], "outcome_types": ["binary", "continuous"]},
    "nma-bayesian-smd": {"types": ["nma"], "outcome_types": ["continuous"]},
    "nma-freq-smd": {"types": ["nma"], "outcome_types": ["continuous"]},

    # Specialized apps
    "dta-meta": {"types": ["dta"], "outcome_types": ["diagnostic"]},
    "dose-response": {"types": ["pairwise"], "outcome_types": ["dose-response"]},
    "multilevel-meta": {"types": ["pairwise", "nma"], "outcome_types": ["binary", "continuous"]},

    # AI apps (work with all)
    "ai-bayesian": {"types": ["pairwise", "nma"], "outcome_types": ["binary", "continuous"]},
    "ai-smd-results": {"types": ["pairwise", "nma"], "outcome_types": ["continuous"]},
    "ai-or-rr-results": {"types": ["pairwise"], "outcome_types": ["binary"]},
    "ai-nma-results": {"types": ["nma"], "outcome_types": ["binary", "continuous"]},
}


# ===== HELPER FUNCTIONS =====

def scan_pairwise70_datasets() -> List[Dataset]:
    """Scan Pairwise70 datasets"""
    datasets = []
    pairwise70_path = os.path.join(DATASETS_DIR, "786-MIII-Meta-analysis/external_integrations/Pairwise70/data")

    if not os.path.exists(pairwise70_path):
        return datasets

    # List all .rda files
    rda_files = glob.glob(os.path.join(pairwise70_path, "*.rda"))

    for rda_file in rda_files[:100]:  # Limit to first 100 for performance
        file_name = os.path.basename(rda_file)
        dataset_id = file_name.replace(".rda", "")

        # Extract Cochrane ID from filename (e.g., CD002042_pub6_data -> CD002042)
        cochrane_id = dataset_id.split("_")[0] if dataset_id.startswith("CD") else dataset_id

        datasets.append(Dataset(
            id=dataset_id,
            name=dataset_id.replace("_", " ").title(),
            source="Pairwise70",
            type="pairwise",
            outcome_type="binary",  # Most Cochrane reviews are binary outcomes
            review_doi=f"10.1002/14651858.{cochrane_id}" if cochrane_id.startswith("CD") else None,
            file_path=rda_file,
            file_size=os.path.getsize(rda_file),
            description=f"Cochrane review {cochrane_id} pairwise meta-analysis data"
        ))

    return datasets


def scan_nma51_datasets() -> List[Dataset]:
    """Scan NMA51 datasets"""
    datasets = []
    nma51_path = os.path.join(DATASETS_DIR, "NMA51/data-raw")

    if not os.path.exists(nma51_path):
        # Try alternative path
        nma51_path = os.path.join(DATASETS_DIR, "786-MIII-Meta-analysis/external_integrations/NMA51/data-raw")

    if not os.path.exists(nma51_path):
        return datasets

    # List all files in data-raw
    data_files = glob.glob(os.path.join(nma51_path, "*"))

    for data_file in data_files:
        if os.path.isfile(data_file):
            file_name = os.path.basename(data_file)
            dataset_id = f"nma51_{file_name.replace('.', '_')}"

            datasets.append(Dataset(
                id=dataset_id,
                name=file_name.replace("_", " ").replace("-", " ").title(),
                source="NMA51",
                type="nma",
                outcome_type="mixed",
                file_path=data_file,
                file_size=os.path.getsize(data_file),
                description=f"Network meta-analysis dataset from NMA51 collection"
            ))

    return datasets


def scan_nma_repo_datasets() -> List[Dataset]:
    """Scan NMArepo datasets"""
    datasets = []
    nma_repo_path = os.path.join(DATASETS_DIR, "NMArepo")

    if not os.path.exists(nma_repo_path):
        # Try alternative path
        nma_repo_path = os.path.join(DATASETS_DIR, "786-MIII-Meta-analysis/external_integrations/NMArepo")

    if not os.path.exists(nma_repo_path):
        return datasets

    # Check for data directory
    data_dirs = [
        os.path.join(nma_repo_path, "data"),
        os.path.join(nma_repo_path, "inst/extdata")
    ]

    for data_dir in data_dirs:
        if os.path.exists(data_dir):
            data_files = glob.glob(os.path.join(data_dir, "*"))

            for data_file in data_files:
                if os.path.isfile(data_file):
                    file_name = os.path.basename(data_file)
                    dataset_id = f"nmarepo_{file_name.replace('.', '_')}"

                    datasets.append(Dataset(
                        id=dataset_id,
                        name=file_name.replace("_", " ").replace("-", " ").title(),
                        source="NMArepo",
                        type="nma",
                        outcome_type="mixed",
                        file_path=data_file,
                        file_size=os.path.getsize(data_file),
                        description=f"Network meta-analysis dataset from NMArepo collection"
                    ))

    return datasets


def scan_dta70_datasets() -> List[Dataset]:
    """Scan DTA70 datasets"""
    datasets = []
    dta70_path = os.path.join(DATASETS_DIR, "786-MIII-Meta-analysis/external_integrations/DTA70")

    if not os.path.exists(dta70_path):
        return datasets

    # Check for data directory
    data_dirs = [
        os.path.join(dta70_path, "data"),
        os.path.join(dta70_path, "inst/extdata")
    ]

    for data_dir in data_dirs:
        if os.path.exists(data_dir):
            data_files = glob.glob(os.path.join(data_dir, "*"))

            for data_file in data_files:
                if os.path.isfile(data_file):
                    file_name = os.path.basename(data_file)
                    dataset_id = f"dta70_{file_name.replace('.', '_')}"

                    datasets.append(Dataset(
                        id=dataset_id,
                        name=file_name.replace("_", " ").replace("-", " ").title(),
                        source="DTA70",
                        type="dta",
                        outcome_type="diagnostic",
                        file_path=data_file,
                        file_size=os.path.getsize(data_file),
                        description=f"Diagnostic test accuracy meta-analysis dataset"
                    ))

    return datasets


def get_all_datasets_cached() -> List[Dataset]:
    """Get all datasets (with caching in production)"""
    all_datasets = []
    all_datasets.extend(scan_pairwise70_datasets())
    all_datasets.extend(scan_nma51_datasets())
    all_datasets.extend(scan_nma_repo_datasets())
    all_datasets.extend(scan_dta70_datasets())
    return all_datasets


def recommend_apps_for_dataset(dataset: Dataset) -> List[AppRecommendation]:
    """Recommend compatible apps for a dataset"""
    recommendations = []

    for app_id, criteria in APP_DATASET_MAPPING.items():
        compatibility = "possible"
        reason = ""

        # Check type compatibility
        if dataset.type in criteria["types"]:
            if dataset.outcome_type in criteria["outcome_types"]:
                compatibility = "perfect"
                reason = f"Perfect match for {dataset.type} meta-analysis with {dataset.outcome_type} outcomes"
            else:
                compatibility = "good"
                reason = f"Good match for {dataset.type} meta-analysis"
        else:
            continue  # Skip incompatible apps

        recommendations.append(AppRecommendation(
            app_id=app_id,
            app_name=app_id.replace("-", " ").title(),
            compatibility=compatibility,
            reason=reason
        ))

    # Sort by compatibility
    recommendations.sort(key=lambda x: {"perfect": 0, "good": 1, "possible": 2}[x.compatibility])

    return recommendations


# ===== API ENDPOINTS =====

@router.get("/", response_model=List[Dataset])
async def list_datasets(
    source: Optional[str] = Query(None, description="Filter by source (Pairwise70, NMA51, NMArepo, DTA70)"),
    type: Optional[str] = Query(None, description="Filter by type (pairwise, nma, dta)"),
    outcome_type: Optional[str] = Query(None, description="Filter by outcome type"),
    limit: int = Query(100, le=500, description="Maximum number of datasets to return"),
    offset: int = Query(0, ge=0, description="Offset for pagination")
):
    """
    List all available datasets with optional filtering
    """
    all_datasets = get_all_datasets_cached()

    # Apply filters
    filtered_datasets = all_datasets

    if source:
        filtered_datasets = [d for d in filtered_datasets if d.source == source]

    if type:
        filtered_datasets = [d for d in filtered_datasets if d.type == type]

    if outcome_type:
        filtered_datasets = [d for d in filtered_datasets if d.outcome_type == outcome_type]

    # Apply pagination
    paginated_datasets = filtered_datasets[offset:offset + limit]

    return paginated_datasets


@router.get("/summary", response_model=DatasetSummary)
async def get_dataset_summary():
    """
    Get summary statistics for all datasets
    """
    all_datasets = get_all_datasets_cached()

    by_source = {}
    by_type = {}
    total_studies = 0

    for dataset in all_datasets:
        # Count by source
        by_source[dataset.source] = by_source.get(dataset.source, 0) + 1

        # Count by type
        by_type[dataset.type] = by_type.get(dataset.type, 0) + 1

        # Sum studies
        if dataset.n_studies:
            total_studies += dataset.n_studies

    return DatasetSummary(
        total_datasets=len(all_datasets),
        by_source=by_source,
        by_type=by_type,
        total_studies=total_studies
    )


@router.get("/{dataset_id}", response_model=Dataset)
async def get_dataset(dataset_id: str):
    """
    Get detailed information about a specific dataset
    """
    all_datasets = get_all_datasets_cached()

    dataset = next((d for d in all_datasets if d.id == dataset_id), None)

    if not dataset:
        raise HTTPException(status_code=404, detail=f"Dataset {dataset_id} not found")

    return dataset


@router.get("/{dataset_id}/apps", response_model=List[AppRecommendation])
async def get_recommended_apps(dataset_id: str):
    """
    Get recommended apps for a specific dataset
    """
    all_datasets = get_all_datasets_cached()

    dataset = next((d for d in all_datasets if d.id == dataset_id), None)

    if not dataset:
        raise HTTPException(status_code=404, detail=f"Dataset {dataset_id} not found")

    recommendations = recommend_apps_for_dataset(dataset)

    return recommendations


@router.post("/{dataset_id}/load")
async def load_dataset(dataset_id: str):
    """
    Load a dataset (prepare it for use in an app)
    This endpoint returns instructions for loading the dataset in R/Python
    """
    all_datasets = get_all_datasets_cached()

    dataset = next((d for d in all_datasets if d.id == dataset_id), None)

    if not dataset:
        raise HTTPException(status_code=404, detail=f"Dataset {dataset_id} not found")

    # Generate R code to load the dataset
    r_code = ""
    if dataset.source == "Pairwise70":
        r_code = f"""
# Load Pairwise70 dataset
library(Pairwise70)
data({dataset_id})
dataset <- {dataset_id}
"""
    elif dataset.source == "NMA51":
        r_code = f"""
# Load NMA51 dataset
library(nmadatasets)
# Load specific dataset based on file
dataset <- readRDS("{dataset.file_path}")
"""
    elif dataset.source == "NMArepo":
        r_code = f"""
# Load NMArepo dataset
library(netmetaDatasets)
# Load specific dataset
dataset <- readRDS("{dataset.file_path}")
"""
    elif dataset.source == "DTA70":
        r_code = f"""
# Load DTA70 dataset
# Load specific dataset
dataset <- readRDS("{dataset.file_path}")
"""

    return {
        "dataset_id": dataset_id,
        "source": dataset.source,
        "file_path": dataset.file_path,
        "r_code": r_code.strip(),
        "status": "ready"
    }


@router.get("/search/{query}")
async def search_datasets(
    query: str,
    limit: int = Query(50, le=200, description="Maximum number of results")
):
    """
    Search datasets by name, description, or DOI
    """
    all_datasets = get_all_datasets_cached()

    query_lower = query.lower()

    # Simple text search
    matching_datasets = [
        d for d in all_datasets
        if (query_lower in d.name.lower()) or
           (d.description and query_lower in d.description.lower()) or
           (d.review_doi and query_lower in d.review_doi.lower()) or
           (query_lower in d.id.lower())
    ]

    return matching_datasets[:limit]
