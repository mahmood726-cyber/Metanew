"""
Knowledge Graph for Evidence Synthesis
Study deduplication, similarity search, and cross-project learning
Uses local embeddings (no external APIs) and graph-based methods
"""
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional, Set
from dataclasses import dataclass
from difflib import SequenceMatcher
import hashlib
import json
import logging
from collections import defaultdict

logger = logging.getLogger(__name__)


@dataclass
class Study:
    """Represents a study in the knowledge graph"""
    study_id: str
    title: str
    authors: List[str]
    year: int
    doi: Optional[str]
    pmid: Optional[str]
    abstract: Optional[str]
    keywords: List[str]
    outcome_type: str
    intervention: str
    comparator: str
    population: str

    def to_dict(self) -> Dict:
        return {
            'study_id': self.study_id,
            'title': self.title,
            'authors': self.authors,
            'year': self.year,
            'doi': self.doi,
            'pmid': self.pmid,
            'abstract': self.abstract,
            'keywords': self.keywords,
            'outcome_type': self.outcome_type,
            'intervention': self.intervention,
            'comparator': self.comparator,
            'population': self.population
        }


class StudyDeduplicator:
    """
    Detect duplicate studies using multiple matching strategies
    No external APIs - all local computation
    """

    def __init__(self):
        self.known_studies: Dict[str, Study] = {}
        self.title_hashes: Dict[str, str] = {}
        self.doi_index: Dict[str, str] = {}
        self.pmid_index: Dict[str, str] = {}

    def normalize_text(self, text: str) -> str:
        """Normalize text for comparison"""
        if not text:
            return ""
        # Convert to lowercase, remove punctuation, extra spaces
        import re
        text = text.lower()
        text = re.sub(r'[^\w\s]', '', text)
        text = re.sub(r'\s+', ' ', text)
        return text.strip()

    def normalize_author_name(self, name: str) -> str:
        """Normalize author name (last name, first initial)"""
        parts = name.strip().split()
        if len(parts) == 0:
            return ""
        last_name = parts[-1].lower()
        first_initial = parts[0][0].lower() if len(parts) > 0 else ""
        return f"{last_name}_{first_initial}"

    def compute_title_hash(self, title: str) -> str:
        """Compute hash of normalized title"""
        normalized = self.normalize_text(title)
        return hashlib.md5(normalized.encode()).hexdigest()

    def compute_author_fingerprint(self, authors: List[str]) -> str:
        """Compute fingerprint from author names"""
        normalized_authors = sorted([self.normalize_author_name(a) for a in authors])
        fingerprint = "_".join(normalized_authors[:3])  # First 3 authors
        return fingerprint

    def title_similarity(self, title1: str, title2: str) -> float:
        """Compute similarity between titles using sequence matcher"""
        norm1 = self.normalize_text(title1)
        norm2 = self.normalize_text(title2)
        return SequenceMatcher(None, norm1, norm2).ratio()

    def author_overlap(self, authors1: List[str], authors2: List[str]) -> float:
        """Compute Jaccard similarity of author sets"""
        norm1 = set([self.normalize_author_name(a) for a in authors1])
        norm2 = set([self.normalize_author_name(a) for a in authors2])

        if len(norm1) == 0 and len(norm2) == 0:
            return 1.0
        if len(norm1) == 0 or len(norm2) == 0:
            return 0.0

        intersection = len(norm1 & norm2)
        union = len(norm1 | norm2)
        return intersection / union if union > 0 else 0.0

    def is_duplicate(self, study1: Study, study2: Study) -> Tuple[bool, float, str]:
        """
        Determine if two studies are duplicates

        Returns:
            (is_duplicate, confidence, reason)
        """
        # Strategy 1: Exact DOI match
        if study1.doi and study2.doi and study1.doi == study2.doi:
            return (True, 1.0, "Identical DOI")

        # Strategy 2: Exact PMID match
        if study1.pmid and study2.pmid and study1.pmid == study2.pmid:
            return (True, 1.0, "Identical PMID")

        # Strategy 3: Exact title hash match
        title_hash1 = self.compute_title_hash(study1.title)
        title_hash2 = self.compute_title_hash(study2.title)
        if title_hash1 == title_hash2:
            return (True, 0.95, "Identical normalized title")

        # Strategy 4: High title similarity + author overlap + same year
        title_sim = self.title_similarity(study1.title, study2.title)
        author_sim = self.author_overlap(study1.authors, study2.authors)
        same_year = (study1.year == study2.year)

        # Scoring system
        score = 0.0
        reasons = []

        if title_sim > 0.9:
            score += 0.5
            reasons.append(f"high title similarity ({title_sim:.2f})")

        if author_sim > 0.5:
            score += 0.3
            reasons.append(f"author overlap ({author_sim:.2f})")

        if same_year:
            score += 0.2
            reasons.append("same year")

        is_dup = score > 0.8
        reason = ", ".join(reasons) if reasons else "low similarity"

        return (is_dup, score, reason)

    def find_duplicates(self, studies: List[Study]) -> List[Tuple[Study, Study, float, str]]:
        """
        Find all duplicate pairs in a list of studies

        Returns:
            List of (study1, study2, confidence, reason) tuples
        """
        duplicates = []
        n = len(studies)

        for i in range(n):
            for j in range(i + 1, n):
                is_dup, confidence, reason = self.is_duplicate(studies[i], studies[j])
                if is_dup:
                    duplicates.append((studies[i], studies[j], confidence, reason))

        return duplicates

    def deduplicate_studies(self, studies: List[Study]) -> Tuple[List[Study], List[Tuple]]:
        """
        Remove duplicates from list of studies

        Returns:
            (unique_studies, removed_duplicates)
        """
        unique_studies = []
        removed = []
        seen_hashes = set()

        for study in studies:
            # Create composite hash
            composite = f"{study.doi}_{study.pmid}_{self.compute_title_hash(study.title)}"

            if composite not in seen_hashes:
                # Check against existing unique studies
                is_duplicate = False
                for existing in unique_studies:
                    is_dup, conf, reason = self.is_duplicate(study, existing)
                    if is_dup:
                        removed.append((study, existing, conf, reason))
                        is_duplicate = True
                        break

                if not is_duplicate:
                    unique_studies.append(study)
                    seen_hashes.add(composite)

        logger.info(f"Deduplication: {len(studies)} studies → {len(unique_studies)} unique ({len(removed)} duplicates removed)")

        return unique_studies, removed


class EvidenceKnowledgeGraph:
    """
    Knowledge graph connecting studies, interventions, outcomes, and populations
    Enables cross-project learning and evidence synthesis
    """

    def __init__(self):
        self.studies: Dict[str, Study] = {}
        self.interventions: Dict[str, Set[str]] = defaultdict(set)  # intervention -> study_ids
        self.outcomes: Dict[str, Set[str]] = defaultdict(set)  # outcome -> study_ids
        self.populations: Dict[str, Set[str]] = defaultdict(set)  # population -> study_ids
        self.comparisons: Dict[Tuple[str, str], Set[str]] = defaultdict(set)  # (intervention, comparator) -> study_ids

    def add_study(self, study: Study):
        """Add study to knowledge graph"""
        self.studies[study.study_id] = study

        # Index by intervention
        if study.intervention:
            self.interventions[study.intervention.lower()].add(study.study_id)

        # Index by outcome
        if study.outcome_type:
            self.outcomes[study.outcome_type.lower()].add(study.study_id)

        # Index by population
        if study.population:
            self.populations[study.population.lower()].add(study.study_id)

        # Index by comparison
        if study.intervention and study.comparator:
            comp_key = (study.intervention.lower(), study.comparator.lower())
            self.comparisons[comp_key].add(study.study_id)

    def find_similar_studies(self, query_study: Study, top_k: int = 10) -> List[Tuple[Study, float, str]]:
        """
        Find studies similar to query study

        Returns:
            List of (study, similarity_score, reason) tuples
        """
        similar = []

        for study_id, study in self.studies.items():
            if study_id == query_study.study_id:
                continue

            # Compute similarity score
            score = 0.0
            reasons = []

            # Same intervention (+0.4)
            if query_study.intervention and study.intervention:
                if query_study.intervention.lower() == study.intervention.lower():
                    score += 0.4
                    reasons.append("same intervention")

            # Same outcome (+0.3)
            if query_study.outcome_type and study.outcome_type:
                if query_study.outcome_type.lower() == study.outcome_type.lower():
                    score += 0.3
                    reasons.append("same outcome")

            # Same population (+0.2)
            if query_study.population and study.population:
                if query_study.population.lower() == study.population.lower():
                    score += 0.2
                    reasons.append("same population")

            # Similar year (+0.1 if within 5 years)
            if abs(query_study.year - study.year) <= 5:
                score += 0.1
                reasons.append("similar time period")

            if score > 0:
                reason = ", ".join(reasons)
                similar.append((study, score, reason))

        # Sort by score and return top k
        similar.sort(key=lambda x: x[1], reverse=True)
        return similar[:top_k]

    def find_by_intervention(self, intervention: str) -> List[Study]:
        """Find all studies with a specific intervention"""
        study_ids = self.interventions.get(intervention.lower(), set())
        return [self.studies[sid] for sid in study_ids]

    def find_by_comparison(self, intervention: str, comparator: str) -> List[Study]:
        """Find all studies comparing specific intervention vs comparator"""
        comp_key = (intervention.lower(), comparator.lower())
        study_ids = self.comparisons.get(comp_key, set())
        return [self.studies[sid] for sid in study_ids]

    def get_intervention_network(self) -> Dict[str, List[str]]:
        """
        Build intervention network (which interventions are compared)

        Returns:
            Dictionary mapping intervention to list of comparators
        """
        network = defaultdict(set)

        for (intervention, comparator), _ in self.comparisons.items():
            network[intervention].add(comparator)
            network[comparator].add(intervention)  # Bidirectional

        return {k: list(v) for k, v in network.items()}

    def compute_study_embeddings(self, study: Study, method: str = "tfidf") -> np.ndarray:
        """
        Compute simple text-based embeddings for study
        Using TF-IDF or count-based methods (no external APIs)

        Args:
            study: Study object
            method: "tfidf" or "count"

        Returns:
            Embedding vector
        """
        # Create document from study text
        document = " ".join([
            study.title or "",
            study.abstract or "",
            " ".join(study.keywords),
            study.intervention or "",
            study.outcome_type or "",
            study.population or ""
        ])

        # Simple word tokenization
        words = document.lower().split()

        # Count-based embedding (bag of words with predefined vocabulary)
        # In production, would use sklearn TfidfVectorizer
        vocab = set(words)
        embedding = np.zeros(100)  # Fixed-size embedding

        # Hash words to indices
        for word in vocab:
            idx = hash(word) % 100
            embedding[idx] += 1

        # Normalize
        norm = np.linalg.norm(embedding)
        if norm > 0:
            embedding = embedding / norm

        return embedding

    def cosine_similarity(self, emb1: np.ndarray, emb2: np.ndarray) -> float:
        """Compute cosine similarity between embeddings"""
        dot = np.dot(emb1, emb2)
        norm1 = np.linalg.norm(emb1)
        norm2 = np.linalg.norm(emb2)

        if norm1 == 0 or norm2 == 0:
            return 0.0

        return dot / (norm1 * norm2)

    def find_similar_by_embedding(self, query_study: Study, top_k: int = 10) -> List[Tuple[Study, float]]:
        """
        Find similar studies using embedding-based similarity

        Returns:
            List of (study, similarity) tuples
        """
        query_embedding = self.compute_study_embeddings(query_study)

        similarities = []
        for study_id, study in self.studies.items():
            if study_id == query_study.study_id:
                continue

            study_embedding = self.compute_study_embeddings(study)
            similarity = self.cosine_similarity(query_embedding, study_embedding)
            similarities.append((study, similarity))

        # Sort and return top k
        similarities.sort(key=lambda x: x[1], reverse=True)
        return similarities[:top_k]

    def get_statistics(self) -> Dict:
        """Get knowledge graph statistics"""
        return {
            'n_studies': len(self.studies),
            'n_interventions': len(self.interventions),
            'n_outcomes': len(self.outcomes),
            'n_populations': len(self.populations),
            'n_comparisons': len(self.comparisons),
            'avg_studies_per_intervention': np.mean([len(s) for s in self.interventions.values()]) if self.interventions else 0,
            'network_density': len(self.comparisons) / (len(self.interventions) * (len(self.interventions) - 1) / 2) if len(self.interventions) > 1 else 0
        }


# Global instances
study_deduplicator = StudyDeduplicator()
evidence_kg = EvidenceKnowledgeGraph()
