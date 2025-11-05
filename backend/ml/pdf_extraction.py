"""
Automated PDF Data Extraction for Meta-Analysis
Extracts study characteristics and numerical data from PDF files
"""
import logging
from typing import Dict, List, Any, Optional
import re

logger = logging.getLogger(__name__)


class PDFDataExtractor:
    """Extract meta-analysis data from PDF files"""

    def __init__(self):
        """Initialize PDF extractor"""
        self.table_patterns = self._compile_table_patterns()
        logger.info("✓ PDF data extractor initialized")

    def _compile_table_patterns(self) -> Dict[str, re.Pattern]:
        """Compile regex patterns for common data formats"""
        return {
            'n_value': re.compile(r'[Nn]\s*=\s*(\d+)'),
            'mean_sd': re.compile(r'(\d+\.?\d*)\s*[\(±]\s*(\d+\.?\d*)'),
            'ci': re.compile(r'95%?\s*CI[:\s]*(\d+\.?\d*)\s*[-–to]\s*(\d+\.?\d*)'),
            'p_value': re.compile(r'[Pp]\s*<?=?\s*(0?\.\d+|<?\s*0\.001)'),
            'or_rr': re.compile(r'(OR|RR|HR)[:\s]*(\d+\.?\d*)'),
        }

    def extract_from_text(self, pdf_text: str) -> Dict[str, Any]:
        """
        Extract data from PDF text

        Args:
            pdf_text: Extracted PDF text

        Returns:
            Extracted data dictionary
        """
        logger.info("Extracting data from PDF text...")

        extracted = {
            'sample_sizes': self._extract_sample_sizes(pdf_text),
            'effect_sizes': self._extract_effect_sizes(pdf_text),
            'statistics': self._extract_statistics(pdf_text),
            'tables': self._extract_tables(pdf_text),
            'metadata': self._extract_metadata(pdf_text)
        }

        logger.info(f"✓ Extracted data from PDF")
        return extracted

    def _extract_sample_sizes(self, text: str) -> List[int]:
        """Extract sample sizes"""
        matches = self.table_patterns['n_value'].findall(text)
        return [int(m) for m in matches]

    def _extract_effect_sizes(self, text: str) -> List[Dict[str, float]]:
        """Extract effect sizes with CIs"""
        results = []
        for match in self.table_patterns['or_rr'].finditer(text):
            measure, value = match.groups()
            results.append({
                'measure': measure,
                'value': float(value),
                'text_position': match.start()
            })
        return results

    def _extract_statistics(self, text: str) -> List[Dict[str, Any]]:
        """Extract statistical values"""
        stats = []

        # P-values
        for match in self.table_patterns['p_value'].finditer(text):
            p_str = match.group(1)
            if '<' in p_str:
                p_value = 0.001
            else:
                p_value = float(p_str)
            stats.append({'type': 'p_value', 'value': p_value})

        # CIs
        for match in self.table_patterns['ci'].finditer(text):
            lower, upper = match.groups()
            stats.append({
                'type': 'ci',
                'lower': float(lower),
                'upper': float(upper)
            })

        return stats

    def _extract_tables(self, text: str) -> List[str]:
        """Extract table content (simple heuristic)"""
        # Look for table sections
        table_sections = []
        lines = text.split('\n')

        in_table = False
        current_table = []

        for line in lines:
            # Detect table start (multiple numbers/columns)
            if len(re.findall(r'\d+\.?\d*', line)) >= 3 and '\t' in line or '  ' * 3 in line:
                in_table = True
                current_table.append(line)
            elif in_table:
                if line.strip():
                    current_table.append(line)
                else:
                    if current_table:
                        table_sections.append('\n'.join(current_table))
                        current_table = []
                    in_table = False

        return table_sections

    def _extract_metadata(self, text: str) -> Dict[str, Any]:
        """Extract study metadata"""
        metadata = {}

        # Authors (first line often)
        lines = [l.strip() for l in text.split('\n') if l.strip()]
        if lines:
            metadata['title'] = lines[0][:200]

        # Year
        year_match = re.search(r'(19|20)\d{2}', text[:500])
        if year_match:
            metadata['year'] = int(year_match.group(0))

        # Keywords
        kw_match = re.search(r'Keywords?[:\s]+(.*)', text, re.IGNORECASE)
        if kw_match:
            keywords = [kw.strip() for kw in kw_match.group(1).split(',')[:5]]
            metadata['keywords'] = keywords

        return metadata

    def batch_extract(self, pdf_files: List[str]) -> List[Dict[str, Any]]:
        """
        Extract data from multiple PDFs

        Args:
            pdf_files: List of PDF file paths

        Returns:
            List of extracted data dictionaries
        """
        logger.info(f"Extracting data from {len(pdf_files)} PDF files...")

        results = []
        for pdf_path in pdf_files:
            try:
                # In production, use PyPDF2 or pdfplumber
                text = self._read_pdf(pdf_path)
                extracted = self.extract_from_text(text)
                extracted['source_file'] = pdf_path
                results.append(extracted)
            except Exception as e:
                logger.error(f"Failed to extract from {pdf_path}: {str(e)}")
                results.append({'error': str(e), 'source_file': pdf_path})

        logger.info(f"✓ Extracted data from {len(results)} PDFs")
        return results

    def _read_pdf(self, pdf_path: str) -> str:
        """
        Read PDF file (placeholder - requires PyPDF2/pdfplumber)

        NOTE: In production, install: pip install pypdf2 pdfplumber
        """
        try:
            import PyPDF2
            with open(pdf_path, 'rb') as file:
                reader = PyPDF2.PdfReader(file)
                text = ""
                for page in reader.pages:
                    text += page.extract_text()
                return text
        except ImportError:
            logger.warning("PyPDF2 not installed. Install with: pip install PyPDF2")
            return ""
        except Exception as e:
            logger.error(f"Error reading PDF: {str(e)}")
            return ""
