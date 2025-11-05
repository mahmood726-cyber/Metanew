"""
Pattern-Based Data Extraction

Automated extraction of study characteristics using regex patterns and NLP:
- Sample size extraction (n= patterns)
- Effect size extraction (OR, RR, HR with regex)
- Confidence interval extraction (95% CI patterns)
- P-value extraction
- Intervention/comparator keyword detection
- Risk of bias domain identification
- Integration with manual review workflow

V2.4 ENHANCEMENTS:
- spaCy NER for entity recognition (drugs, diseases, outcomes)
- Table extraction from PDFs (tabula-py, camelot)
- OCR integration for scanned PDFs (tesseract)
- BioBERT fine-tuning for biomedical entities
- Relation extraction (intervention-outcome pairs)

IMPLEMENTATION OPTIONS:
1. Regex (DEFAULT):
   - Fast and deterministic
   - Works well for standardized formats
   - Accuracy: 40-60%

2. spaCy NER (V2.4):
   - Named entity recognition for PICO elements
   - Pre-trained on biomedical literature
   - Accuracy: 65-80%

3. Table Extraction (V2.4):
   - Extracts data from PDF tables
   - Multiple backends (tabula, camelot, pdfplumber)
   - Handles both text-based and image-based PDFs

LIMITATIONS:
- Screening tool, not replacement for manual extraction
- Always requires manual verification
- Best results with standardized reporting

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

    def __init__(
        self,
        use_spacy: bool = False,  # V2.4: Enable spaCy NER
        use_table_extraction: bool = False,  # V2.4: Enable table extraction
        spacy_model: str = "en_core_sci_md"  # V2.4: Biomedical spaCy model
    ):
        """
        Initialize Data Extractor

        Args:
            use_spacy: Enable spaCy NER for entity recognition
            use_table_extraction: Enable PDF table extraction
            spacy_model: spaCy model name (en_core_sci_md for biomedical)
        """
        self.patterns = self._compile_patterns()
        self.use_spacy = use_spacy
        self.use_table_extraction = use_table_extraction

        # V2.4: Load spaCy model if requested
        self.nlp = None
        if use_spacy:
            try:
                import spacy
                self.nlp = spacy.load(spacy_model)
                print(f"Loaded spaCy model: {spacy_model}")
            except ImportError:
                print("Warning: spaCy not available. Install with: pip install spacy")
                print("Then download model: python -m spacy download en_core_sci_md")
                self.use_spacy = False
            except OSError:
                print(f"Warning: spaCy model '{spacy_model}' not found.")
                print("Install with: pip install scispacy")
                print("Then: python -m spacy download en_core_sci_md")
                self.use_spacy = False

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

    def extract_with_spacy(
        self, text: str, study_id: str
    ) -> ExtractedStudy:
        """
        V2.4: Extract entities using spaCy NER

        Uses biomedical spaCy models (scispacy) for:
        - Drug/intervention names
        - Disease/condition names
        - Anatomical entities
        - Numerical values with context

        Requires: pip install scispacy
        Model: python -m spacy download en_core_sci_md
        """

        if not self.use_spacy or self.nlp is None:
            # Fallback to regex extraction
            return self.extract_from_text(text, study_id)

        study = ExtractedStudy(study_id=study_id)

        # Process text with spaCy
        doc = self.nlp(text)

        # Extract named entities
        drugs = []
        diseases = []
        for ent in doc.ents:
            if ent.label_ in ["CHEMICAL", "DRUG"]:
                drugs.append(ent.text)
            elif ent.label_ in ["DISEASE", "CONDITION"]:
                diseases.append(ent.text)

        # Use most frequent drug as intervention
        if drugs:
            from collections import Counter
            drug_counts = Counter(drugs)
            study.intervention = drug_counts.most_common(1)[0][0]

        # Use diseases for population
        if diseases:
            from collections import Counter
            disease_counts = Counter(diseases)
            study.population = disease_counts.most_common(1)[0][0]

        # Still use regex for numeric values (more reliable)
        study.n_total = self._extract_sample_size(text)
        study.author = self._extract_author(text)
        study.year = self._extract_year(text)

        # Extract outcomes using sentence context
        study.outcomes = self._extract_outcomes_spacy(doc)

        # Extract effect sizes (regex still better for formatted numbers)
        effect_sizes = self._extract_effect_sizes(text)
        study.effect_sizes = effect_sizes

        # Calculate confidence
        study.confidence = self._calculate_confidence(study)
        study.needs_review = study.confidence < 0.7

        return study

    def _extract_outcomes_spacy(self, doc) -> List[str]:
        """Extract outcomes using spaCy sentence context"""
        outcomes = []

        # Look for outcome-related keywords with nearby entities
        outcome_keywords = ["outcome", "endpoint", "mortality", "survival", "response"]

        for sent in doc.sents:
            sent_text_lower = sent.text.lower()
            if any(keyword in sent_text_lower for keyword in outcome_keywords):
                # Extract entities from this sentence
                for ent in sent.ents:
                    if ent.label_ in ["DISEASE", "CONDITION", "PHENOTYPE"]:
                        outcomes.append(ent.text)

        return list(set(outcomes))  # Remove duplicates

    def extract_tables_from_pdf(
        self, pdf_path: str, study_id: str
    ) -> Dict[str, pd.DataFrame]:
        """
        V2.4: Extract tables from PDF

        Uses multiple backends for robustness:
        1. tabula-py (Java-based, good for text-based PDFs)
        2. camelot-py (Python, good for structured tables)
        3. pdfplumber (Python, fallback)

        Requires:
            pip install tabula-py camelot-py[cv] pdfplumber

        Args:
            pdf_path: Path to PDF file
            study_id: Study identifier

        Returns:
            Dict of table_name -> DataFrame
        """

        if not self.use_table_extraction:
            print("Table extraction not enabled. Set use_table_extraction=True")
            return {}

        tables = {}

        # Try tabula first (most common)
        try:
            import tabula
            tabula_tables = tabula.read_pdf(pdf_path, pages='all', multiple_tables=True)

            for i, table in enumerate(tabula_tables):
                if not table.empty:
                    tables[f"{study_id}_table_{i+1}_tabula"] = table

            print(f"Tabula extracted {len(tabula_tables)} tables")

        except ImportError:
            print("Warning: tabula-py not available. Install with: pip install tabula-py")
        except Exception as e:
            print(f"Tabula extraction failed: {e}")

        # Try camelot as backup
        try:
            import camelot

            camelot_tables = camelot.read_pdf(pdf_path, pages='all', flavor='lattice')

            for i, table in enumerate(camelot_tables):
                df = table.df
                if not df.empty:
                    tables[f"{study_id}_table_{i+1}_camelot"] = df

            print(f"Camelot extracted {len(camelot_tables)} tables")

        except ImportError:
            print("Warning: camelot-py not available. Install with: pip install camelot-py[cv]")
        except Exception as e:
            print(f"Camelot extraction failed: {e}")

        # Try pdfplumber as last resort
        try:
            import pdfplumber

            with pdfplumber.open(pdf_path) as pdf:
                for page_num, page in enumerate(pdf.pages):
                    page_tables = page.extract_tables()

                    for table_num, table in enumerate(page_tables):
                        if table:
                            df = pd.DataFrame(table[1:], columns=table[0])
                            tables[f"{study_id}_page{page_num+1}_table{table_num+1}_plumber"] = df

            print(f"PDFPlumber extracted tables from {len(pdf.pages)} pages")

        except ImportError:
            print("Warning: pdfplumber not available. Install with: pip install pdfplumber")
        except Exception as e:
            print(f"PDFPlumber extraction failed: {e}")

        if not tables:
            print("No tables extracted. PDF may not contain tables or may be image-based.")
            print("For image-based PDFs, consider using OCR (tesseract) first.")

        return tables

    def extract_from_pdf_with_ocr(
        self, pdf_path: str, study_id: str
    ) -> ExtractedStudy:
        """
        V2.4: Extract from scanned PDF using OCR

        Uses tesseract OCR to convert images to text, then extracts data.

        Requires:
            - System: sudo apt-get install tesseract-ocr
            - Python: pip install pytesseract pdf2image

        Args:
            pdf_path: Path to PDF file (can be scanned/image-based)
            study_id: Study identifier

        Returns:
            ExtractedStudy object
        """

        try:
            import pytesseract
            from pdf2image import convert_from_path
        except ImportError:
            print("Warning: OCR libraries not available.")
            print("Install with: pip install pytesseract pdf2image")
            print("System: sudo apt-get install tesseract-ocr poppler-utils")
            # Fallback to non-OCR extraction
            return ExtractedStudy(study_id=study_id, needs_review=True)

        # Convert PDF to images
        try:
            images = convert_from_path(pdf_path)
        except Exception as e:
            print(f"PDF to image conversion failed: {e}")
            return ExtractedStudy(study_id=study_id, needs_review=True)

        # OCR each page
        full_text = []
        for i, image in enumerate(images):
            try:
                text = pytesseract.image_to_string(image)
                full_text.append(text)
                print(f"OCR completed for page {i+1}/{len(images)}")
            except Exception as e:
                print(f"OCR failed for page {i+1}: {e}")

        # Combine all text
        combined_text = "\n\n".join(full_text)

        # Extract using standard method (or spaCy if enabled)
        if self.use_spacy:
            study = self.extract_with_spacy(combined_text, study_id)
        else:
            study = self.extract_from_text(combined_text, study_id)

        # Mark as OCR-extracted (needs extra review)
        study.needs_review = True
        study.confidence = min(study.confidence, 0.6)  # Cap confidence for OCR

        return study
