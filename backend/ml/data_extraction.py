"""
Pattern-Based Data Extraction

Automated extraction of study characteristics using regex patterns:
- Sample size extraction (n= patterns)
- Effect size extraction (OR, RR, HR with regex)
- Confidence interval extraction (95% CI patterns)
- P-value extraction
- Intervention/comparator keyword detection
- Risk of bias domain identification
- Integration with manual review workflow

IMPLEMENTATION: Uses regular expression patterns (regex)
- Fast and deterministic
- Works well for standardized reporting formats
- No ML training required
- Requires manual review for accuracy

LIMITATIONS:
- No semantic understanding (not NLP)
- Cannot handle tables or figures (no OCR/computer vision)
- Sensitive to reporting format variations
- Best used as screening tool, not replacement for manual extraction

FUTURE: Could be extended with spaCy NER or transformer models for better accuracy

Author: EvidenceOS PRIME
License: MIT
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass, field
import re
from collections import defaultdict


@dataclass
class ExtractedStudy:
    """Extracted data from a single study"""
    study_id: str

    # Study characteristics
    author: Optional[str] = None
    year: Optional[int] = None
    journal: Optional[str] = None

    # PICO elements
    population: Optional[str] = None
    intervention: Optional[str] = None
    comparator: Optional[str] = None
    outcomes: List[str] = field(default_factory=list)

    # Sample size
    n_intervention: Optional[int] = None
    n_comparator: Optional[int] = None
    n_total: Optional[int] = None

    # Results
    effect_sizes: Dict[str, float] = field(default_factory=dict)
    confidence_intervals: Dict[str, Tuple[float, float]] = field(default_factory=dict)
    p_values: Dict[str, float] = field(default_factory=dict)

    # Risk of bias
    rob_domains: Dict[str, str] = field(default_factory=dict)

    # Extraction confidence
    confidence: float = 0.0
    needs_review: bool = True


@dataclass
class ExtractionResult:
    """Results from batch extraction"""
    extracted_studies: List[ExtractedStudy]
    n_successful: int
    n_failed: int
    n_needs_review: int

    # Summary
    extraction_quality: Dict[str, float]
    common_issues: List[str]


class DataExtractor:
    """
    Pattern-Based Data Extraction Engine

    Extracts study data from text using regex patterns.

    IMPORTANT: This is a SCREENING TOOL, not a replacement for manual extraction.
    - Can reduce initial extraction time by identifying likely values
    - Requires manual verification of all extracted data
    - Typical accuracy: 40-60% for complete extraction
    - Best for standardized reporting formats

    For production HTA submissions:
    - Use this for initial screening only
    - Always manually verify extracted data
    - Consider double-extraction with reconciliation
    - Use structured data collection forms when possible

    Examples:
        >>> extractor = DataExtractor()
        >>>
        >>> # Extract from PDF text
        >>> result = extractor.extract_from_text(pdf_text, study_id="Smith2023")
        >>>
        >>> # Always verify results
        >>> if result.confidence < 0.8:
        ...     print("Manual review required")
        >>>
        >>> # Extract from batch
        >>> results = extractor.extract_batch(pdf_texts, study_ids)
    """

    def __init__(self):
        self.patterns = self._compile_patterns()

    def extract_from_text(
        self, text: str, study_id: str
    ) -> ExtractedStudy:
        """
        Extract structured data from study text

        Args:
            text: Full text of study (from PDF extraction)
            study_id: Study identifier

        Returns:
            ExtractedStudy object
        """
        study = ExtractedStudy(study_id=study_id)

        # Extract bibliographic info
        study.author = self._extract_author(text)
        study.year = self._extract_year(text)

        # Extract sample sizes
        study.n_total = self._extract_sample_size(text)

        # Extract interventions
        study.intervention = self._extract_intervention(text)
        study.comparator = self._extract_comparator(text)

        # Extract outcomes
        study.outcomes = self._extract_outcomes(text)

        # Extract effect sizes
        study.effect_sizes = self._extract_effect_sizes(text)

        # Extract confidence intervals
        study.confidence_intervals = self._extract_confidence_intervals(text)

        # Extract p-values
        study.p_values = self._extract_p_values(text)

        # Extract risk of bias
        study.rob_domains = self._extract_rob(text)

        # Assess extraction confidence
        study.confidence = self._assess_confidence(study)
        study.needs_review = study.confidence < 0.8

        return study

    def extract_batch(
        self, texts: List[str], study_ids: List[str]
    ) -> ExtractionResult:
        """Extract data from multiple studies"""
        extracted_studies = []
        n_successful = 0
        n_failed = 0
        n_needs_review = 0

        for text, study_id in zip(texts, study_ids):
            try:
                study = self.extract_from_text(text, study_id)
                extracted_studies.append(study)

                if study.confidence >= 0.8:
                    n_successful += 1
                else:
                    n_needs_review += 1

            except Exception as e:
                n_failed += 1
                # Create placeholder
                extracted_studies.append(
                    ExtractedStudy(study_id=study_id, needs_review=True)
                )

        # Quality metrics
        extraction_quality = {
            "avg_confidence": np.mean([s.confidence for s in extracted_studies]),
            "pct_successful": n_successful / len(texts) * 100 if texts else 0
        }

        common_issues = self._identify_common_issues(extracted_studies)

        return ExtractionResult(
            extracted_studies=extracted_studies,
            n_successful=n_successful,
            n_failed=n_failed,
            n_needs_review=n_needs_review,
            extraction_quality=extraction_quality,
            common_issues=common_issues
        )

    def _compile_patterns(self) -> Dict[str, re.Pattern]:
        """Compile regex patterns for extraction"""
        return {
            "sample_size": re.compile(r'n\s*=\s*(\d+)', re.IGNORECASE),
            "p_value": re.compile(r'p\s*[=<>]\s*([\d\.]+)', re.IGNORECASE),
            "ci": re.compile(r'95%\s*ci\s*[:\[]?\s*([\d\.]+)\s*[-–]\s*([\d\.]+)', re.IGNORECASE),
            "or": re.compile(r'or\s*[=:]\s*([\d\.]+)', re.IGNORECASE),
            "rr": re.compile(r'rr\s*[=:]\s*([\d\.]+)', re.IGNORECASE),
            "hr": re.compile(r'hr\s*[=:]\s*([\d\.]+)', re.IGNORECASE),
            "year": re.compile(r'\b(19\d{2}|20\d{2})\b')
        }

    def _extract_author(self, text: str) -> Optional[str]:
        """
        Extract first author using simple heuristics

        LIMITATION: This is a naive approach that assumes first line contains author.
        For real NER, would need spaCy or transformer models.
        """
        lines = text.split('\n')
        if lines:
            return lines[0].split()[0] if lines[0] else None
        return None

    def _extract_year(self, text: str) -> Optional[int]:
        """Extract publication year"""
        matches = self.patterns["year"].findall(text)
        if matches:
            years = [int(y) for y in matches if 1950 <= int(y) <= 2030]
            return years[0] if years else None
        return None

    def _extract_sample_size(self, text: str) -> Optional[int]:
        """Extract total sample size"""
        matches = self.patterns["sample_size"].findall(text)
        if matches:
            # Return largest N (likely total sample size)
            return max([int(n) for n in matches])
        return None

    def _extract_intervention(self, text: str) -> Optional[str]:
        """
        Extract intervention using keyword search

        LIMITATION: Simple string matching, not semantic understanding.
        May return irrelevant text containing keywords.
        For real intervention extraction, would need Named Entity Recognition (NER).
        """
        keywords = ["treatment", "intervention", "drug", "therapy"]
        for keyword in keywords:
            idx = text.lower().find(keyword)
            if idx != -1:
                # Extract surrounding context
                snippet = text[max(0, idx-50):min(len(text), idx+100)]
                return snippet.strip()
        return None

    def _extract_comparator(self, text: str) -> Optional[str]:
        """Extract comparator description"""
        keywords = ["placebo", "control", "standard care"]
        for keyword in keywords:
            if keyword in text.lower():
                return keyword
        return None

    def _extract_outcomes(self, text: str) -> List[str]:
        """Extract outcome measures"""
        outcomes = []
        outcome_keywords = [
            "mortality", "survival", "response rate", "progression",
            "quality of life", "adverse events"
        ]

        for keyword in outcome_keywords:
            if keyword in text.lower():
                outcomes.append(keyword)

        return outcomes

    def _extract_effect_sizes(self, text: str) -> Dict[str, float]:
        """Extract effect size estimates"""
        effect_sizes = {}

        # OR
        or_matches = self.patterns["or"].findall(text)
        if or_matches:
            effect_sizes["OR"] = float(or_matches[0])

        # RR
        rr_matches = self.patterns["rr"].findall(text)
        if rr_matches:
            effect_sizes["RR"] = float(rr_matches[0])

        # HR
        hr_matches = self.patterns["hr"].findall(text)
        if hr_matches:
            effect_sizes["HR"] = float(hr_matches[0])

        return effect_sizes

    def _extract_confidence_intervals(self, text: str) -> Dict[str, Tuple[float, float]]:
        """Extract confidence intervals"""
        cis = {}

        ci_matches = self.patterns["ci"].findall(text)
        if ci_matches:
            # Return first CI found
            lower, upper = ci_matches[0]
            cis["primary"] = (float(lower), float(upper))

        return cis

    def _extract_p_values(self, text: str) -> Dict[str, float]:
        """Extract p-values"""
        p_values = {}

        p_matches = self.patterns["p_value"].findall(text)
        if p_matches:
            p_values["primary"] = float(p_matches[0])

        return p_values

    def _extract_rob(self, text: str) -> Dict[str, str]:
        """Extract risk of bias indicators"""
        rob = {}

        # Randomization
        if any(kw in text.lower() for kw in ["randomized", "randomised", "random allocation"]):
            rob["randomization"] = "low"
        else:
            rob["randomization"] = "unclear"

        # Blinding
        if any(kw in text.lower() for kw in ["double-blind", "double blind"]):
            rob["blinding"] = "low"
        elif "single-blind" in text.lower():
            rob["blinding"] = "some concerns"
        else:
            rob["blinding"] = "unclear"

        return rob

    def _assess_confidence(self, study: ExtractedStudy) -> float:
        """
        Assess extraction confidence score (0-1)

        IMPORTANT: This is NOT a machine learning confidence score.
        It's simply a completeness checklist:
        - 1.0 = All fields extracted
        - 0.0 = No fields extracted

        Does NOT indicate:
        - Accuracy of extracted values
        - Quality of extraction
        - Whether manual review is needed

        ALWAYS manually verify extracted data regardless of confidence score.
        """
        score = 0.0

        # Weighted checklist (completeness only)
        if study.author:
            score += 0.1
        if study.year:
            score += 0.1
        if study.n_total:
            score += 0.2
        if study.intervention:
            score += 0.1
        if study.outcomes:
            score += 0.2
        if study.effect_sizes:
            score += 0.2
        if study.confidence_intervals:
            score += 0.1

        return min(1.0, score)

    def _identify_common_issues(self, studies: List[ExtractedStudy]) -> List[str]:
        """Identify common extraction issues"""
        issues = []

        missing_sample_size = sum(1 for s in studies if s.n_total is None)
        if missing_sample_size > len(studies) * 0.3:
            issues.append("High rate of missing sample sizes")

        missing_effect_sizes = sum(1 for s in studies if not s.effect_sizes)
        if missing_effect_sizes > len(studies) * 0.3:
            issues.append("High rate of missing effect sizes")

        return issues
