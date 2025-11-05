"""
Machine Learning Package for Systematic Reviews

AI-powered citation screening and data extraction.
"""

from .citation_screening import CitationScreener, ScreeningResult
from .data_extraction import DataExtractor, ExtractedStudy, ExtractionResult

__all__ = [
    "CitationScreener",
    "ScreeningResult",
    "DataExtractor",
    "ExtractedStudy",
    "ExtractionResult",
]
