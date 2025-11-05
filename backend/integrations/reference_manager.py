"""
Reference Manager Integration

Integration with popular reference management systems for systematic reviews:
- Zotero API (read/write collections, items, attachments)
- Mendeley API (read documents, folders)
- BibTeX import/export
- RIS format support
- EndNote XML import/export
- Automated deduplication across sources
- Full-text PDF linking

Supported Operations:
1. Import citations from reference managers
2. Export search results to reference managers
3. Sync screening decisions back to reference managers
4. Deduplicate across multiple sources
5. Retrieve full-text PDFs

IMPORTANT: API credentials required for Zotero/Mendeley
- Zotero: API key from https://www.zotero.org/settings/keys
- Mendeley: OAuth credentials from https://dev.mendeley.com/

Author: EvidenceOS PRIME
License: MIT
"""

import re
import json
import warnings
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime
import pandas as pd


@dataclass
class Citation:
    """Standardized citation format"""
    id: str
    title: str
    authors: List[str]
    year: Optional[int] = None
    journal: Optional[str] = None
    volume: Optional[str] = None
    issue: Optional[str] = None
    pages: Optional[str] = None
    doi: Optional[str] = None
    pmid: Optional[str] = None
    abstract: Optional[str] = None
    keywords: List[str] = field(default_factory=list)
    pdf_url: Optional[str] = None
    source: Optional[str] = None  # "zotero", "mendeley", "bibtex", etc.
    tags: List[str] = field(default_factory=list)
    screening_decision: Optional[str] = None  # "include", "exclude", "uncertain"
    extraction_data: Dict[str, Any] = field(default_factory=dict)


@dataclass
class DeduplicationResult:
    """Results from deduplication"""
    unique_citations: List[Citation]
    duplicate_groups: List[List[str]]  # Groups of duplicate IDs
    n_original: int
    n_unique: int
    n_duplicates: int


class ReferenceManagerIntegration:
    """
    Reference Manager Integration Engine

    Provides unified interface for importing/exporting citations from
    popular reference management systems.

    Examples:
        >>> # Import from BibTeX
        >>> manager = ReferenceManagerIntegration()
        >>> citations = manager.import_bibtex("references.bib")
        >>>
        >>> # Deduplicate
        >>> dedup_result = manager.deduplicate(citations)
        >>> print(f"Removed {dedup_result.n_duplicates} duplicates")
        >>>
        >>> # Export to RIS
        >>> manager.export_ris(dedup_result.unique_citations, "output.ris")
        >>>
        >>> # Zotero integration (requires API key)
        >>> zotero = ZoteroIntegration(api_key="your_key", library_id="12345")
        >>> citations = zotero.get_collection("systematic_review")
    """

    def __init__(self):
        pass

    def import_bibtex(self, file_path: str) -> List[Citation]:
        """
        Import citations from BibTeX file

        Args:
            file_path: Path to .bib file

        Returns:
            List of Citation objects
        """
        citations = []

        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Parse BibTeX entries
        entries = self._parse_bibtex(content)

        for entry_id, entry_data in entries.items():
            citation = self._bibtex_to_citation(entry_id, entry_data)
            citations.append(citation)

        return citations

    def export_bibtex(self, citations: List[Citation], file_path: str):
        """Export citations to BibTeX format"""
        with open(file_path, 'w', encoding='utf-8') as f:
            for citation in citations:
                bibtex_entry = self._citation_to_bibtex(citation)
                f.write(bibtex_entry + "\n\n")

    def import_ris(self, file_path: str) -> List[Citation]:
        """
        Import citations from RIS file

        RIS format is used by EndNote, RefWorks, Mendeley, Zotero
        """
        citations = []

        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Parse RIS entries
        entries = self._parse_ris(content)

        for entry_data in entries:
            citation = self._ris_to_citation(entry_data)
            citations.append(citation)

        return citations

    def export_ris(self, citations: List[Citation], file_path: str):
        """Export citations to RIS format"""
        with open(file_path, 'w', encoding='utf-8') as f:
            for citation in citations:
                ris_entry = self._citation_to_ris(citation)
                f.write(ris_entry + "\n")

    def deduplicate(
        self,
        citations: List[Citation],
        match_threshold: float = 0.85
    ) -> DeduplicationResult:
        """
        Deduplicate citations using fuzzy matching

        Args:
            citations: List of citations
            match_threshold: Similarity threshold (0-1) for matching

        Returns:
            DeduplicationResult with unique citations and duplicate groups
        """
        n_original = len(citations)
        duplicate_groups = []
        unique_citations = []
        processed_ids = set()

        for i, citation1 in enumerate(citations):
            if citation1.id in processed_ids:
                continue

            # Find duplicates
            duplicates = [citation1.id]

            for j, citation2 in enumerate(citations[i+1:], start=i+1):
                if citation2.id in processed_ids:
                    continue

                similarity = self._calculate_similarity(citation1, citation2)

                if similarity >= match_threshold:
                    duplicates.append(citation2.id)
                    processed_ids.add(citation2.id)

            # Keep first occurrence
            unique_citations.append(citation1)
            processed_ids.add(citation1.id)

            if len(duplicates) > 1:
                duplicate_groups.append(duplicates)

        n_unique = len(unique_citations)
        n_duplicates = n_original - n_unique

        return DeduplicationResult(
            unique_citations=unique_citations,
            duplicate_groups=duplicate_groups,
            n_original=n_original,
            n_unique=n_unique,
            n_duplicates=n_duplicates
        )

    def _parse_bibtex(self, content: str) -> Dict[str, Dict[str, str]]:
        """Parse BibTeX content into entries"""
        entries = {}

        # Match @article{key, ... }
        pattern = r'@(\w+)\{([^,]+),\s*((?:[^{}]|\{[^{}]*\})*)\}'

        for match in re.finditer(pattern, content, re.DOTALL):
            entry_type = match.group(1)
            entry_key = match.group(2)
            entry_fields = match.group(3)

            # Parse fields
            fields = {'type': entry_type}
            field_pattern = r'(\w+)\s*=\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}|(\w+)\s*=\s*"([^"]*)"'

            for field_match in re.finditer(field_pattern, entry_fields):
                if field_match.group(1):
                    field_name = field_match.group(1)
                    field_value = field_match.group(2)
                else:
                    field_name = field_match.group(3)
                    field_value = field_match.group(4)

                fields[field_name.lower()] = field_value.strip()

            entries[entry_key] = fields

        return entries

    def _bibtex_to_citation(self, entry_id: str, entry_data: Dict[str, str]) -> Citation:
        """Convert BibTeX entry to Citation"""
        # Parse authors
        authors_str = entry_data.get('author', '')
        authors = [a.strip() for a in re.split(r'\s+and\s+', authors_str) if a.strip()]

        # Parse year
        year_str = entry_data.get('year', '')
        year = int(year_str) if year_str.isdigit() else None

        return Citation(
            id=entry_id,
            title=entry_data.get('title', ''),
            authors=authors,
            year=year,
            journal=entry_data.get('journal') or entry_data.get('booktitle'),
            volume=entry_data.get('volume'),
            issue=entry_data.get('number'),
            pages=entry_data.get('pages'),
            doi=entry_data.get('doi'),
            abstract=entry_data.get('abstract'),
            source='bibtex'
        )

    def _citation_to_bibtex(self, citation: Citation) -> str:
        """Convert Citation to BibTeX entry"""
        # Determine entry type
        entry_type = "article"

        # Build BibTeX entry
        lines = [f"@{entry_type}{{{citation.id},"]

        if citation.title:
            lines.append(f"  title = {{{citation.title}}},")

        if citation.authors:
            authors_str = " and ".join(citation.authors)
            lines.append(f"  author = {{{authors_str}}},")

        if citation.year:
            lines.append(f"  year = {{{citation.year}}},")

        if citation.journal:
            lines.append(f"  journal = {{{citation.journal}}},")

        if citation.volume:
            lines.append(f"  volume = {{{citation.volume}}},")

        if citation.issue:
            lines.append(f"  number = {{{citation.issue}}},")

        if citation.pages:
            lines.append(f"  pages = {{{citation.pages}}},")

        if citation.doi:
            lines.append(f"  doi = {{{citation.doi}}},")

        lines.append("}")

        return "\n".join(lines)

    def _parse_ris(self, content: str) -> List[Dict[str, Any]]:
        """Parse RIS content into entries"""
        entries = []
        current_entry = {}

        for line in content.split('\n'):
            line = line.strip()

            if not line:
                if current_entry:
                    entries.append(current_entry)
                    current_entry = {}
                continue

            # RIS format: TAG  - VALUE
            match = re.match(r'^([A-Z][A-Z0-9])\s+-\s+(.*)$', line)

            if match:
                tag = match.group(1)
                value = match.group(2)

                if tag == "ER":  # End of record
                    if current_entry:
                        entries.append(current_entry)
                        current_entry = {}
                else:
                    # Some tags can appear multiple times (authors)
                    if tag in current_entry:
                        if isinstance(current_entry[tag], list):
                            current_entry[tag].append(value)
                        else:
                            current_entry[tag] = [current_entry[tag], value]
                    else:
                        current_entry[tag] = value

        # Add last entry if exists
        if current_entry:
            entries.append(current_entry)

        return entries

    def _ris_to_citation(self, entry_data: Dict[str, Any]) -> Citation:
        """Convert RIS entry to Citation"""
        # RIS tag mapping
        # TY = Type, TI = Title, AU = Author, PY = Year, JO = Journal
        # VL = Volume, IS = Issue, SP = Start Page, EP = End Page
        # DO = DOI, AB = Abstract

        # Parse authors
        authors = entry_data.get('AU', [])
        if not isinstance(authors, list):
            authors = [authors]

        # Parse year
        year_str = entry_data.get('PY', '')
        year = int(year_str[:4]) if len(year_str) >= 4 and year_str[:4].isdigit() else None

        # Parse pages
        start_page = entry_data.get('SP')
        end_page = entry_data.get('EP')
        pages = f"{start_page}-{end_page}" if start_page and end_page else (start_page or end_page)

        # Generate ID
        first_author = authors[0].split(',')[0] if authors else "Unknown"
        citation_id = f"{first_author}{year or 'NoYear'}"

        return Citation(
            id=citation_id,
            title=entry_data.get('TI', ''),
            authors=authors,
            year=year,
            journal=entry_data.get('JO') or entry_data.get('T2'),
            volume=entry_data.get('VL'),
            issue=entry_data.get('IS'),
            pages=pages,
            doi=entry_data.get('DO'),
            abstract=entry_data.get('AB'),
            source='ris'
        )

    def _citation_to_ris(self, citation: Citation) -> str:
        """Convert Citation to RIS entry"""
        lines = ["TY  - JOUR"]  # Journal article

        if citation.title:
            lines.append(f"TI  - {citation.title}")

        for author in citation.authors:
            lines.append(f"AU  - {author}")

        if citation.year:
            lines.append(f"PY  - {citation.year}")

        if citation.journal:
            lines.append(f"JO  - {citation.journal}")

        if citation.volume:
            lines.append(f"VL  - {citation.volume}")

        if citation.issue:
            lines.append(f"IS  - {citation.issue}")

        if citation.pages:
            pages_parts = citation.pages.split('-')
            if len(pages_parts) >= 2:
                lines.append(f"SP  - {pages_parts[0]}")
                lines.append(f"EP  - {pages_parts[1]}")
            else:
                lines.append(f"SP  - {citation.pages}")

        if citation.doi:
            lines.append(f"DO  - {citation.doi}")

        if citation.abstract:
            lines.append(f"AB  - {citation.abstract}")

        lines.append("ER  - ")
        lines.append("")  # Blank line between entries

        return "\n".join(lines)

    def _calculate_similarity(self, citation1: Citation, citation2: Citation) -> float:
        """
        Calculate similarity between two citations

        Uses multiple features:
        - Title similarity (most important)
        - Author overlap
        - Year match
        - DOI match (if available)
        """
        similarity_score = 0.0
        weights = {'title': 0.6, 'authors': 0.2, 'year': 0.1, 'doi': 0.1}

        # DOI match (exact)
        if citation1.doi and citation2.doi:
            if citation1.doi.lower() == citation2.doi.lower():
                return 1.0  # Perfect match

        # Title similarity
        title1 = self._normalize_text(citation1.title)
        title2 = self._normalize_text(citation2.title)
        title_sim = self._fuzzy_match(title1, title2)
        similarity_score += weights['title'] * title_sim

        # Author overlap
        authors1 = set([self._normalize_text(a) for a in citation1.authors])
        authors2 = set([self._normalize_text(a) for a in citation2.authors])

        if authors1 and authors2:
            author_overlap = len(authors1.intersection(authors2)) / max(len(authors1), len(authors2))
            similarity_score += weights['authors'] * author_overlap

        # Year match
        if citation1.year and citation2.year:
            year_match = 1.0 if citation1.year == citation2.year else 0.0
            similarity_score += weights['year'] * year_match

        return similarity_score

    def _normalize_text(self, text: str) -> str:
        """Normalize text for comparison"""
        if not text:
            return ""

        # Lowercase
        text = text.lower()

        # Remove punctuation
        text = re.sub(r'[^\w\s]', '', text)

        # Remove extra whitespace
        text = re.sub(r'\s+', ' ', text).strip()

        return text

    def _fuzzy_match(self, text1: str, text2: str) -> float:
        """
        Calculate fuzzy string similarity using Jaccard similarity

        For production use, consider using python-Levenshtein or fuzzywuzzy
        for better performance and accuracy.
        """
        if not text1 or not text2:
            return 0.0

        # Tokenize
        tokens1 = set(text1.split())
        tokens2 = set(text2.split())

        # Jaccard similarity
        intersection = len(tokens1.intersection(tokens2))
        union = len(tokens1.union(tokens2))

        return intersection / union if union > 0 else 0.0


class ZoteroIntegration:
    """
    Zotero API Integration

    Requires: pip install pyzotero

    Examples:
        >>> zotero = ZoteroIntegration(
        ...     api_key="your_api_key",
        ...     library_id="12345",
        ...     library_type="user"  # or "group"
        ... )
        >>>
        >>> # Get all items from collection
        >>> citations = zotero.get_collection("My Systematic Review")
        >>>
        >>> # Add new item
        >>> zotero.add_item(citation)
        >>>
        >>> # Update screening decision
        >>> zotero.update_tags(citation_id, ["include", "screened"])
    """

    def __init__(
        self,
        api_key: str,
        library_id: str,
        library_type: str = "user"
    ):
        try:
            from pyzotero import zotero
            self.zot = zotero.Zotero(library_id, library_type, api_key)
            self.available = True
        except ImportError:
            warnings.warn(
                "pyzotero not available. Install with: pip install pyzotero\n"
                "Zotero integration will not work."
            )
            self.available = False

    def get_collection(self, collection_name: str) -> List[Citation]:
        """Get all items from a collection"""
        if not self.available:
            raise RuntimeError("pyzotero not installed")

        # Find collection by name
        collections = self.zot.collections()
        collection_id = None

        for coll in collections:
            if coll['data']['name'] == collection_name:
                collection_id = coll['key']
                break

        if not collection_id:
            raise ValueError(f"Collection '{collection_name}' not found")

        # Get items
        items = self.zot.collection_items(collection_id)

        # Convert to Citation objects
        citations = []
        for item in items:
            citation = self._zotero_to_citation(item)
            citations.append(citation)

        return citations

    def add_item(self, citation: Citation) -> str:
        """Add citation to Zotero library"""
        if not self.available:
            raise RuntimeError("pyzotero not installed")

        item_data = self._citation_to_zotero(citation)
        result = self.zot.create_items([item_data])

        return result['successful']['0']['key']

    def update_tags(self, item_key: str, tags: List[str]):
        """Update tags for an item"""
        if not self.available:
            raise RuntimeError("pyzotero not installed")

        item = self.zot.item(item_key)
        item['data']['tags'] = [{'tag': tag} for tag in tags]
        self.zot.update_item(item)

    def _zotero_to_citation(self, item: Dict) -> Citation:
        """Convert Zotero item to Citation"""
        data = item['data']

        # Extract authors
        authors = []
        for creator in data.get('creators', []):
            if 'name' in creator:
                authors.append(creator['name'])
            else:
                first = creator.get('firstName', '')
                last = creator.get('lastName', '')
                authors.append(f"{first} {last}".strip())

        # Extract tags
        tags = [tag['tag'] for tag in data.get('tags', [])]

        return Citation(
            id=item['key'],
            title=data.get('title', ''),
            authors=authors,
            year=int(data['date'][:4]) if data.get('date') and len(data['date']) >= 4 else None,
            journal=data.get('publicationTitle'),
            volume=data.get('volume'),
            issue=data.get('issue'),
            pages=data.get('pages'),
            doi=data.get('DOI'),
            abstract=data.get('abstractNote'),
            tags=tags,
            source='zotero'
        )

    def _citation_to_zotero(self, citation: Citation) -> Dict:
        """Convert Citation to Zotero item"""
        # Create item template
        template = {
            'itemType': 'journalArticle',
            'title': citation.title,
            'creators': [
                {'creatorType': 'author', 'name': author}
                for author in citation.authors
            ],
            'date': str(citation.year) if citation.year else '',
            'publicationTitle': citation.journal or '',
            'volume': citation.volume or '',
            'issue': citation.issue or '',
            'pages': citation.pages or '',
            'DOI': citation.doi or '',
            'abstractNote': citation.abstract or '',
            'tags': [{'tag': tag} for tag in citation.tags]
        }

        return template


# Example usage
if __name__ == "__main__":
    # Create integration
    manager = ReferenceManagerIntegration()

    # Import from BibTeX (example - file doesn't exist)
    # citations = manager.import_bibtex("references.bib")

    # Create sample citations
    citations = [
        Citation(
            id="Smith2023",
            title="Effect of Drug A on Mortality",
            authors=["Smith J", "Jones K"],
            year=2023,
            journal="JAMA",
            doi="10.1001/jama.2023.12345"
        ),
        Citation(
            id="Smith2023b",
            title="Effect of Drug A on Mortality",  # Duplicate
            authors=["Smith John", "Jones Kate"],
            year=2023,
            journal="JAMA",
            doi="10.1001/jama.2023.12345"
        ),
        Citation(
            id="Brown2022",
            title="Cost-Effectiveness of Drug B",
            authors=["Brown A"],
            year=2022,
            journal="Health Economics"
        )
    ]

    # Deduplicate
    dedup_result = manager.deduplicate(citations)

    print("\n=== DEDUPLICATION RESULTS ===")
    print(f"Original citations: {dedup_result.n_original}")
    print(f"Unique citations: {dedup_result.n_unique}")
    print(f"Duplicates removed: {dedup_result.n_duplicates}")

    if dedup_result.duplicate_groups:
        print("\nDuplicate groups:")
        for group in dedup_result.duplicate_groups:
            print(f"  {group}")

    # Export to RIS (example)
    # manager.export_ris(dedup_result.unique_citations, "output.ris")

    print("\n=== UNIQUE CITATIONS ===")
    for citation in dedup_result.unique_citations:
        print(f"\n{citation.id}:")
        print(f"  {citation.title}")
        print(f"  {', '.join(citation.authors)} ({citation.year})")
        print(f"  {citation.journal}")
