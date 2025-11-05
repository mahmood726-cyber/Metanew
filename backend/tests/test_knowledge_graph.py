"""
Comprehensive Unit Tests for Knowledge Graph
Tests study deduplication, similarity search, and evidence synthesis
"""
import pytest
import numpy as np
from typing import List

from ml.knowledge_graph import (
    Study,
    StudyDeduplicator,
    EvidenceKnowledgeGraph,
    study_deduplicator,
    evidence_kg
)


# ============================================================================
# Fixtures
# ============================================================================

@pytest.fixture
def sample_study():
    """Create a sample study"""
    return Study(
        study_id="study_001",
        title="Efficacy of Drug A vs Placebo in Hypertension",
        authors=["Smith J", "Johnson M", "Williams K"],
        year=2020,
        doi="10.1234/test.001",
        pmid="12345678",
        abstract="This study evaluated the efficacy of Drug A...",
        keywords=["hypertension", "randomized", "controlled"],
        outcome_type="binary",
        intervention="Drug A",
        comparator="Placebo",
        population="Adults with hypertension"
    )


@pytest.fixture
def duplicate_study_doi(sample_study):
    """Create a study with same DOI"""
    study = Study(
        study_id="study_002",
        title="Different Title",  # Different title
        authors=["Different A"],  # Different authors
        year=2021,  # Different year
        doi="10.1234/test.001",  # SAME DOI
        pmid="99999999",
        abstract="Different abstract",
        keywords=["different"],
        outcome_type="binary",
        intervention="Drug A",
        comparator="Placebo",
        population="Adults"
    )
    return study


@pytest.fixture
def duplicate_study_title(sample_study):
    """Create a study with same title but no DOI"""
    study = Study(
        study_id="study_003",
        title="Efficacy of Drug A vs Placebo in Hypertension",  # SAME title
        authors=["Smith J", "Johnson M"],  # Similar authors
        year=2020,  # Same year
        doi=None,
        pmid=None,
        abstract="Different abstract",
        keywords=["hypertension"],
        outcome_type="binary",
        intervention="Drug A",
        comparator="Placebo",
        population="Adults"
    )
    return study


@pytest.fixture
def similar_study(sample_study):
    """Create a similar but not duplicate study"""
    study = Study(
        study_id="study_004",
        title="Efficacy of Drug B vs Placebo in Hypertension",  # Similar
        authors=["Brown K", "Davis L"],  # Different authors
        year=2021,  # Close year
        doi="10.1234/test.002",
        pmid="87654321",
        abstract="This study evaluated Drug B...",
        keywords=["hypertension", "trial"],
        outcome_type="binary",
        intervention="Drug B",  # Different drug
        comparator="Placebo",
        population="Adults with hypertension"  # Same population
    )
    return study


@pytest.fixture
def study_list():
    """Create a list of diverse studies"""
    studies = [
        Study(
            study_id=f"study_{i}",
            title=f"Study on {intervention} vs {comparator}",
            authors=[f"Author {i}A", f"Author {i}B"],
            year=2020 + i % 3,
            doi=f"10.1234/test.{i:03d}",
            pmid=f"1234{i:04d}",
            abstract=f"Abstract for study {i}",
            keywords=["keyword1", "keyword2"],
            outcome_type=["binary", "continuous"][i % 2],
            intervention=intervention,
            comparator=comparator,
            population=population
        )
        for i, (intervention, comparator, population) in enumerate([
            ("Drug A", "Placebo", "Adults"),
            ("Drug A", "Drug B", "Adults"),
            ("Drug B", "Placebo", "Adults"),
            ("Drug C", "Placebo", "Children"),
            ("Drug A", "Placebo", "Adults"),  # Duplicate comparison
        ])
    ]
    return studies


# ============================================================================
# Study Dataclass Tests
# ============================================================================

def test_study_creation(sample_study):
    """Test Study dataclass creation"""
    assert sample_study.study_id == "study_001"
    assert sample_study.title is not None
    assert len(sample_study.authors) == 3
    assert sample_study.year == 2020
    assert sample_study.doi == "10.1234/test.001"


def test_study_to_dict(sample_study):
    """Test Study to_dict method"""
    study_dict = sample_study.to_dict()

    assert isinstance(study_dict, dict)
    assert study_dict['study_id'] == "study_001"
    assert study_dict['title'] == sample_study.title
    assert study_dict['authors'] == sample_study.authors
    assert study_dict['year'] == 2020


# ============================================================================
# StudyDeduplicator Initialization Tests
# ============================================================================

def test_study_deduplicator_initialization():
    """Test StudyDeduplicator initialization"""
    deduplicator = StudyDeduplicator()

    assert isinstance(deduplicator.known_studies, dict)
    assert isinstance(deduplicator.title_hashes, dict)
    assert isinstance(deduplicator.doi_index, dict)
    assert isinstance(deduplicator.pmid_index, dict)


# ============================================================================
# Text Normalization Tests
# ============================================================================

def test_normalize_text():
    """Test text normalization"""
    deduplicator = StudyDeduplicator()

    # Test basic normalization
    result = deduplicator.normalize_text("Hello, World!")
    assert result == "hello world"

    # Test multiple spaces
    result = deduplicator.normalize_text("Multiple   Spaces")
    assert result == "multiple spaces"

    # Test special characters
    result = deduplicator.normalize_text("Test-123: Value (ok)")
    assert result == "test123 value ok"

    # Test empty string
    result = deduplicator.normalize_text("")
    assert result == ""

    # Test None
    result = deduplicator.normalize_text(None)
    assert result == ""


def test_normalize_author_name():
    """Test author name normalization"""
    deduplicator = StudyDeduplicator()

    # Test full name
    result = deduplicator.normalize_author_name("John Smith")
    assert result == "smith_j"

    # Test single name
    result = deduplicator.normalize_author_name("Smith")
    assert result == "smith_s"

    # Test multiple names
    result = deduplicator.normalize_author_name("John David Smith")
    assert result == "smith_j"

    # Test empty
    result = deduplicator.normalize_author_name("")
    assert result == ""


def test_compute_title_hash():
    """Test title hash computation"""
    deduplicator = StudyDeduplicator()

    title1 = "Efficacy of Drug A"
    title2 = "Efficacy of Drug A"  # Same
    title3 = "EFFICACY OF DRUG A"  # Same (different case)
    title4 = "Efficacy of Drug B"  # Different

    hash1 = deduplicator.compute_title_hash(title1)
    hash2 = deduplicator.compute_title_hash(title2)
    hash3 = deduplicator.compute_title_hash(title3)
    hash4 = deduplicator.compute_title_hash(title4)

    # Same titles should have same hash
    assert hash1 == hash2
    assert hash1 == hash3  # Case insensitive

    # Different titles should have different hash
    assert hash1 != hash4


def test_compute_author_fingerprint():
    """Test author fingerprint computation"""
    deduplicator = StudyDeduplicator()

    authors1 = ["Smith J", "Johnson M", "Williams K"]
    authors2 = ["Smith J", "Johnson M", "Williams K"]
    authors3 = ["Smith J", "Johnson M", "Brown L", "Davis P"]  # More authors

    fp1 = deduplicator.compute_author_fingerprint(authors1)
    fp2 = deduplicator.compute_author_fingerprint(authors2)
    fp3 = deduplicator.compute_author_fingerprint(authors3)

    # Same authors should have same fingerprint
    assert fp1 == fp2

    # Different author lists should have different fingerprints
    assert fp1 != fp3


# ============================================================================
# Similarity Computation Tests
# ============================================================================

def test_title_similarity():
    """Test title similarity computation"""
    deduplicator = StudyDeduplicator()

    title1 = "Efficacy of Drug A vs Placebo"
    title2 = "Efficacy of Drug A vs Placebo"  # Identical
    title3 = "Efficacy of Drug A versus Placebo"  # Very similar
    title4 = "Completely different study title"

    sim_identical = deduplicator.title_similarity(title1, title2)
    sim_similar = deduplicator.title_similarity(title1, title3)
    sim_different = deduplicator.title_similarity(title1, title4)

    # Identical should be 1.0
    assert sim_identical == 1.0

    # Similar should be high
    assert sim_similar > 0.8

    # Different should be low
    assert sim_different < 0.5


def test_author_overlap():
    """Test author overlap computation"""
    deduplicator = StudyDeduplicator()

    authors1 = ["Smith J", "Johnson M", "Williams K"]
    authors2 = ["Smith J", "Johnson M", "Williams K"]  # Identical
    authors3 = ["Smith J", "Johnson M", "Brown L"]  # 2/4 overlap
    authors4 = ["Davis P", "Miller R"]  # No overlap

    overlap_identical = deduplicator.author_overlap(authors1, authors2)
    overlap_partial = deduplicator.author_overlap(authors1, authors3)
    overlap_none = deduplicator.author_overlap(authors1, authors4)

    # Identical should be 1.0
    assert overlap_identical == 1.0

    # Partial overlap
    assert 0.3 < overlap_partial < 0.7

    # No overlap should be 0.0
    assert overlap_none == 0.0


def test_author_overlap_edge_cases():
    """Test author overlap edge cases"""
    deduplicator = StudyDeduplicator()

    # Empty lists
    assert deduplicator.author_overlap([], []) == 1.0
    assert deduplicator.author_overlap([], ["Smith J"]) == 0.0
    assert deduplicator.author_overlap(["Smith J"], []) == 0.0


# ============================================================================
# Duplicate Detection Tests
# ============================================================================

def test_is_duplicate_doi_match(sample_study, duplicate_study_doi):
    """Test duplicate detection by DOI"""
    deduplicator = StudyDeduplicator()

    is_dup, confidence, reason = deduplicator.is_duplicate(sample_study, duplicate_study_doi)

    assert is_dup is True
    assert confidence == 1.0
    assert "DOI" in reason


def test_is_duplicate_pmid_match():
    """Test duplicate detection by PMID"""
    deduplicator = StudyDeduplicator()

    study1 = Study(
        study_id="s1", title="Title 1", authors=["A"], year=2020,
        doi=None, pmid="12345678", abstract="", keywords=[],
        outcome_type="binary", intervention="A", comparator="B", population="C"
    )

    study2 = Study(
        study_id="s2", title="Title 2", authors=["B"], year=2021,
        doi=None, pmid="12345678", abstract="", keywords=[],
        outcome_type="binary", intervention="A", comparator="B", population="C"
    )

    is_dup, confidence, reason = deduplicator.is_duplicate(study1, study2)

    assert is_dup is True
    assert confidence == 1.0
    assert "PMID" in reason


def test_is_duplicate_title_match(sample_study, duplicate_study_title):
    """Test duplicate detection by title"""
    deduplicator = StudyDeduplicator()

    is_dup, confidence, reason = deduplicator.is_duplicate(sample_study, duplicate_study_title)

    assert is_dup is True
    assert confidence >= 0.9
    assert "title" in reason.lower()


def test_is_duplicate_similarity_scoring(sample_study, similar_study):
    """Test duplicate detection with similarity scoring"""
    deduplicator = StudyDeduplicator()

    is_dup, confidence, reason = deduplicator.is_duplicate(sample_study, similar_study)

    # Similar but not duplicate
    assert is_dup is False or confidence < 0.9


def test_find_duplicates(sample_study, duplicate_study_doi, similar_study):
    """Test finding all duplicates in a list"""
    deduplicator = StudyDeduplicator()

    studies = [sample_study, duplicate_study_doi, similar_study]
    duplicates = deduplicator.find_duplicates(studies)

    # Should find at least the DOI duplicate
    assert len(duplicates) >= 1

    # Check structure
    for dup in duplicates:
        study1, study2, confidence, reason = dup
        assert isinstance(study1, Study)
        assert isinstance(study2, Study)
        assert 0 <= confidence <= 1
        assert isinstance(reason, str)


def test_deduplicate_studies(sample_study, duplicate_study_doi, duplicate_study_title, similar_study):
    """Test deduplication of study list"""
    deduplicator = StudyDeduplicator()

    studies = [sample_study, duplicate_study_doi, duplicate_study_title, similar_study]
    unique_studies, removed = deduplicator.deduplicate_studies(studies)

    # Should remove duplicates
    assert len(unique_studies) < len(studies)
    assert len(unique_studies) + len(removed) <= len(studies)

    # Removed should have structure
    for item in removed:
        study, existing, conf, reason = item
        assert isinstance(study, Study)
        assert isinstance(existing, Study)


# ============================================================================
# EvidenceKnowledgeGraph Tests
# ============================================================================

def test_evidence_kg_initialization():
    """Test EvidenceKnowledgeGraph initialization"""
    kg = EvidenceKnowledgeGraph()

    assert isinstance(kg.studies, dict)
    assert isinstance(kg.interventions, dict)
    assert isinstance(kg.outcomes, dict)
    assert isinstance(kg.populations, dict)
    assert isinstance(kg.comparisons, dict)


def test_add_study_to_kg(sample_study):
    """Test adding study to knowledge graph"""
    kg = EvidenceKnowledgeGraph()
    kg.add_study(sample_study)

    assert sample_study.study_id in kg.studies
    assert kg.studies[sample_study.study_id] == sample_study

    # Check indexing
    assert sample_study.study_id in kg.interventions["drug a"]
    assert sample_study.study_id in kg.outcomes["binary"]
    assert sample_study.study_id in kg.populations["adults with hypertension"]


def test_add_multiple_studies(study_list):
    """Test adding multiple studies"""
    kg = EvidenceKnowledgeGraph()

    for study in study_list:
        kg.add_study(study)

    assert len(kg.studies) == len(study_list)
    assert len(kg.interventions) > 0
    assert len(kg.comparisons) > 0


def test_find_similar_studies(sample_study, similar_study):
    """Test finding similar studies"""
    kg = EvidenceKnowledgeGraph()

    kg.add_study(sample_study)
    kg.add_study(similar_study)

    # Add one more different study
    different = Study(
        study_id="different", title="Unrelated", authors=["X"], year=2015,
        doi="10.9999/different", pmid="99999999", abstract="", keywords=[],
        outcome_type="continuous", intervention="Drug Z", comparator="Control",
        population="Children"
    )
    kg.add_study(different)

    # Find similar to sample_study
    similar = kg.find_similar_studies(sample_study, top_k=2)

    assert len(similar) <= 2
    for study, score, reason in similar:
        assert isinstance(study, Study)
        assert 0 <= score <= 1
        assert isinstance(reason, str)


def test_find_by_intervention(study_list):
    """Test finding studies by intervention"""
    kg = EvidenceKnowledgeGraph()

    for study in study_list:
        kg.add_study(study)

    # Find Drug A studies
    drug_a_studies = kg.find_by_intervention("Drug A")

    assert len(drug_a_studies) > 0
    for study in drug_a_studies:
        assert study.intervention.lower() == "drug a"


def test_find_by_comparison(study_list):
    """Test finding studies by comparison"""
    kg = EvidenceKnowledgeGraph()

    for study in study_list:
        kg.add_study(study)

    # Find Drug A vs Placebo
    comparison_studies = kg.find_by_comparison("Drug A", "Placebo")

    assert len(comparison_studies) > 0
    for study in comparison_studies:
        assert study.intervention.lower() == "drug a"
        assert study.comparator.lower() == "placebo"


def test_get_intervention_network(study_list):
    """Test building intervention network"""
    kg = EvidenceKnowledgeGraph()

    for study in study_list:
        kg.add_study(study)

    network = kg.get_intervention_network()

    assert isinstance(network, dict)
    assert len(network) > 0

    # Check bidirectional connections
    for intervention, comparators in network.items():
        assert isinstance(comparators, list)


def test_compute_study_embeddings(sample_study):
    """Test computing study embeddings"""
    kg = EvidenceKnowledgeGraph()

    embedding = kg.compute_study_embeddings(sample_study)

    assert isinstance(embedding, np.ndarray)
    assert embedding.shape == (100,)  # Fixed size
    assert np.isfinite(embedding).all()

    # Check normalization
    norm = np.linalg.norm(embedding)
    assert 0.9 <= norm <= 1.1  # Should be approximately 1


def test_cosine_similarity():
    """Test cosine similarity computation"""
    kg = EvidenceKnowledgeGraph()

    emb1 = np.array([1, 0, 0])
    emb2 = np.array([1, 0, 0])  # Identical
    emb3 = np.array([0, 1, 0])  # Orthogonal
    emb4 = np.array([-1, 0, 0])  # Opposite

    sim_identical = kg.cosine_similarity(emb1, emb2)
    sim_orthogonal = kg.cosine_similarity(emb1, emb3)
    sim_opposite = kg.cosine_similarity(emb1, emb4)

    assert sim_identical == pytest.approx(1.0)
    assert sim_orthogonal == pytest.approx(0.0)
    assert sim_opposite == pytest.approx(-1.0)


def test_cosine_similarity_edge_cases():
    """Test cosine similarity edge cases"""
    kg = EvidenceKnowledgeGraph()

    zero_vec = np.array([0, 0, 0])
    nonzero_vec = np.array([1, 1, 1])

    # Zero vector should return 0
    assert kg.cosine_similarity(zero_vec, nonzero_vec) == 0.0
    assert kg.cosine_similarity(nonzero_vec, zero_vec) == 0.0


def test_find_similar_by_embedding(sample_study, similar_study):
    """Test finding similar studies by embedding"""
    kg = EvidenceKnowledgeGraph()

    kg.add_study(sample_study)
    kg.add_study(similar_study)

    # Add different study
    different = Study(
        study_id="diff", title="Completely different", authors=["Z"], year=2010,
        doi="10.9999/diff", pmid="99999", abstract="Different topic entirely",
        keywords=["unrelated"], outcome_type="survival",
        intervention="Unrelated", comparator="Control", population="Elderly"
    )
    kg.add_study(different)

    # Find similar by embedding
    similar = kg.find_similar_by_embedding(sample_study, top_k=2)

    assert len(similar) <= 2
    for study, similarity in similar:
        assert isinstance(study, Study)
        assert -1 <= similarity <= 1


def test_get_statistics(study_list):
    """Test getting knowledge graph statistics"""
    kg = EvidenceKnowledgeGraph()

    for study in study_list:
        kg.add_study(study)

    stats = kg.get_statistics()

    assert isinstance(stats, dict)
    assert 'n_studies' in stats
    assert 'n_interventions' in stats
    assert 'n_outcomes' in stats
    assert 'n_populations' in stats
    assert 'n_comparisons' in stats
    assert 'avg_studies_per_intervention' in stats
    assert 'network_density' in stats

    assert stats['n_studies'] == len(study_list)
    assert stats['n_interventions'] > 0


def test_statistics_empty_kg():
    """Test statistics for empty knowledge graph"""
    kg = EvidenceKnowledgeGraph()

    stats = kg.get_statistics()

    assert stats['n_studies'] == 0
    assert stats['n_interventions'] == 0
    assert stats['avg_studies_per_intervention'] == 0
    assert stats['network_density'] == 0


# ============================================================================
# Global Instances Tests
# ============================================================================

def test_global_study_deduplicator():
    """Test global study_deduplicator instance"""
    assert study_deduplicator is not None
    assert isinstance(study_deduplicator, StudyDeduplicator)


def test_global_evidence_kg():
    """Test global evidence_kg instance"""
    assert evidence_kg is not None
    assert isinstance(evidence_kg, EvidenceKnowledgeGraph)


# ============================================================================
# Integration Tests
# ============================================================================

def test_end_to_end_deduplication_and_knowledge_graph(study_list):
    """Test complete workflow: deduplicate and build knowledge graph"""
    # Step 1: Deduplicate
    deduplicator = StudyDeduplicator()
    unique_studies, removed = deduplicator.deduplicate_studies(study_list)

    # Step 2: Build knowledge graph
    kg = EvidenceKnowledgeGraph()
    for study in unique_studies:
        kg.add_study(study)

    # Step 3: Query knowledge graph
    stats = kg.get_statistics()

    assert stats['n_studies'] == len(unique_studies)
    assert stats['n_studies'] <= len(study_list)


def test_similarity_search_workflow(sample_study):
    """Test similarity search workflow"""
    kg = EvidenceKnowledgeGraph()

    # Add 10 related studies
    for i in range(10):
        study = Study(
            study_id=f"study_{i}",
            title=f"Study on Drug {chr(65+i%3)} vs Placebo",
            authors=[f"Author {i}"],
            year=2020 + i % 3,
            doi=f"10.1234/test.{i}",
            pmid=f"1234{i:04d}",
            abstract=f"Abstract {i}",
            keywords=["hypertension", "trial"],
            outcome_type="binary" if i % 2 == 0 else "continuous",
            intervention=f"Drug {chr(65+i%3)}",
            comparator="Placebo",
            population="Adults"
        )
        kg.add_study(study)

    # Find similar by attributes
    similar_attr = kg.find_similar_studies(sample_study, top_k=5)
    assert len(similar_attr) <= 5

    # Find similar by embedding
    similar_emb = kg.find_similar_by_embedding(sample_study, top_k=5)
    assert len(similar_emb) <= 5


def test_intervention_network_analysis(study_list):
    """Test intervention network analysis"""
    kg = EvidenceKnowledgeGraph()

    for study in study_list:
        kg.add_study(study)

    # Get network
    network = kg.get_intervention_network()

    # Check network properties
    assert len(network) > 0

    # Find Drug A studies
    drug_a = kg.find_by_intervention("Drug A")
    assert len(drug_a) > 0

    # Find Drug A vs Placebo
    comparison = kg.find_by_comparison("Drug A", "Placebo")
    assert len(comparison) > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
