"""
Natural Language Report Generation for Meta-Analysis
Generates human-readable, publication-quality reports using LLM or template-based approach
"""
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


class ReportSection:
    """Single section of a report"""
    def __init__(self, title: str, content: str, subsections: Optional[List['ReportSection']] = None):
        self.title = title
        self.content = content
        self.subsections = subsections or []

    def to_markdown(self, level: int = 1) -> str:
        """Convert to markdown format"""
        md = f"{'#' * level} {self.title}\n\n{self.content}\n\n"
        for subsection in self.subsections:
            md += subsection.to_markdown(level + 1)
        return md

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            'title': self.title,
            'content': self.content,
            'subsections': [s.to_dict() for s in self.subsections]
        }


class NaturalLanguageReportGenerator:
    """
    Generate natural language reports from meta-analysis results
    Uses LLM when available, falls back to advanced templates
    """

    def __init__(self, llm_manager=None):
        """
        Initialize report generator

        Args:
            llm_manager: Optional LLM manager for natural language generation
        """
        self.llm_manager = llm_manager
        logger.info(f"✓ Report generator initialized (LLM: {'available' if llm_manager else 'unavailable'})")

    def generate_full_report(
        self,
        meta_analysis_results: Dict[str, Any],
        study_data: pd.DataFrame,
        analysis_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Generate complete meta-analysis report

        Args:
            meta_analysis_results: Results from meta-analysis (effect sizes, heterogeneity, etc.)
            study_data: DataFrame with study information
            analysis_config: Configuration and metadata

        Returns:
            Dictionary with report sections and metadata
        """
        logger.info("Generating comprehensive meta-analysis report...")

        # Generate each section
        sections = []

        # 1. Executive Summary
        sections.append(self._generate_executive_summary(meta_analysis_results, study_data))

        # 2. Methods
        sections.append(self._generate_methods_section(analysis_config, study_data))

        # 3. Results
        sections.append(self._generate_results_section(meta_analysis_results, study_data))

        # 4. Discussion
        sections.append(self._generate_discussion(meta_analysis_results))

        # 5. Conclusion
        sections.append(self._generate_conclusion(meta_analysis_results))

        report = {
            'title': analysis_config.get('title', 'Meta-Analysis Report'),
            'generated_at': datetime.utcnow().isoformat(),
            'sections': [s.to_dict() for s in sections],
            'metadata': {
                'n_studies': len(study_data),
                'generation_method': 'llm' if (self.llm_manager and self.llm_manager.is_loaded) else 'template',
                'version': '1.0.0'
            }
        }

        logger.info(f"✓ Report generated ({len(sections)} sections)")
        return report

    def _generate_executive_summary(
        self,
        results: Dict[str, Any],
        study_data: pd.DataFrame
    ) -> ReportSection:
        """Generate executive summary"""

        if self.llm_manager and self.llm_manager.is_loaded:
            # Use LLM for natural language generation
            prompt = f"""Generate an executive summary for a meta-analysis with these results:
- Number of studies: {len(study_data)}
- Pooled effect size: {results.get('pooled_effect', 'N/A')}
- 95% CI: [{results.get('ci_lower', 'N/A')}, {results.get('ci_upper', 'N/A')}]
- I² heterogeneity: {results.get('i_squared', 'N/A')}%
- P-value: {results.get('p_value', 'N/A')}

Write a clear, concise executive summary (3-4 sentences) for a clinical audience."""

            try:
                content = self.llm_manager.generate(prompt, max_tokens=200)
            except Exception as e:
                logger.warning(f"LLM generation failed, using template: {str(e)}")
                content = self._template_executive_summary(results, study_data)
        else:
            content = self._template_executive_summary(results, study_data)

        return ReportSection("Executive Summary", content)

    def _template_executive_summary(
        self,
        results: Dict[str, Any],
        study_data: pd.DataFrame
    ) -> str:
        """Template-based executive summary"""
        n_studies = len(study_data)
        pooled = results.get('pooled_effect', 0)
        ci_lower = results.get('ci_lower', 0)
        ci_upper = results.get('ci_upper', 0)
        i2 = results.get('i_squared', 0)
        p_value = results.get('p_value', 1)

        # Interpret results
        significant = p_value < 0.05
        heterogeneity_level = "low" if i2 < 25 else "moderate" if i2 < 75 else "high"

        summary = f"""This meta-analysis synthesizes evidence from {n_studies} studies examining the intervention effect. """

        summary += f"""The pooled effect estimate was {pooled:.2f} (95% CI: {ci_lower:.2f} to {ci_upper:.2f})"""

        if significant:
            summary += f""", indicating a statistically significant effect (p = {p_value:.3f}). """
        else:
            summary += f""", which was not statistically significant (p = {p_value:.3f}). """

        summary += f"""Between-study heterogeneity was {heterogeneity_level} (I² = {i2:.1f}%)"""

        if i2 > 50:
            summary += f""", suggesting considerable variability in effect sizes across studies."""
        else:
            summary += f""", indicating relatively consistent effects across studies."""

        return summary

    def _generate_methods_section(
        self,
        config: Dict[str, Any],
        study_data: pd.DataFrame
    ) -> ReportSection:
        """Generate methods section"""

        subsections = []

        # Search strategy
        search_content = f"""A systematic literature search was conducted"""
        if 'search_dates' in config:
            search_content += f""" from {config['search_dates']['start']} to {config['search_dates']['end']}"""
        search_content += f""". {len(study_data)} studies met the inclusion criteria."""

        subsections.append(ReportSection("Search Strategy", search_content))

        # Statistical analysis
        model_type = config.get('model', 'random-effects')
        stat_content = f"""Meta-analysis was performed using a {model_type} model. """
        stat_content += f"""Effect sizes were calculated as {config.get('measure', 'standardized mean differences')}. """
        stat_content += f"""Heterogeneity was assessed using I² statistic and tau². """
        stat_content += f"""Publication bias was evaluated using funnel plots and Egger's test."""

        subsections.append(ReportSection("Statistical Analysis", stat_content))

        return ReportSection("Methods", "", subsections)

    def _generate_results_section(
        self,
        results: Dict[str, Any],
        study_data: pd.DataFrame
    ) -> ReportSection:
        """Generate results section"""

        subsections = []

        # Study characteristics
        char_content = f"""A total of {len(study_data)} studies were included, """
        if 'total_participants' in results:
            char_content += f"""comprising {results['total_participants']:,} participants. """

        if 'publication_years' in results:
            years = results['publication_years']
            char_content += f"""Studies were published between {min(years)} and {max(years)}. """

        subsections.append(ReportSection("Study Characteristics", char_content))

        # Main analysis
        pooled = results.get('pooled_effect', 0)
        ci_lower = results.get('ci_lower', 0)
        ci_upper = results.get('ci_upper', 0)
        p_value = results.get('p_value', 1)

        main_content = f"""The pooled effect estimate was {pooled:.2f} """
        main_content += f"""(95% CI: {ci_lower:.2f} to {ci_upper:.2f}, p = {p_value:.3f}). """

        if results.get('prediction_interval'):
            pi = results['prediction_interval']
            main_content += f"""The 95% prediction interval was {pi[0]:.2f} to {pi[1]:.2f}, """
            main_content += f"""indicating the expected range of effects in future studies. """

        subsections.append(ReportSection("Main Analysis", main_content))

        # Heterogeneity
        i2 = results.get('i_squared', 0)
        tau2 = results.get('tau_squared', 0)
        q_p = results.get('q_p_value', 1)

        het_content = f"""Heterogeneity analysis revealed I² = {i2:.1f}%, """
        het_content += f"""τ² = {tau2:.3f}, and Q-test p-value = {q_p:.3f}. """

        if i2 < 25:
            het_content += f"""This suggests low heterogeneity and relatively consistent effects across studies."""
        elif i2 < 75:
            het_content += f"""This indicates moderate heterogeneity, suggesting some variability in effects."""
        else:
            het_content += f"""This indicates high heterogeneity, suggesting substantial variability across studies."""

        subsections.append(ReportSection("Heterogeneity Assessment", het_content))

        # Publication bias
        if 'egger_p' in results:
            egger_p = results['egger_p']
            pub_content = f"""Publication bias assessment using Egger's test """

            if egger_p < 0.05:
                pub_content += f"""revealed potential evidence of bias (p = {egger_p:.3f}). """
                pub_content += f"""Caution is warranted in interpreting the pooled estimate."""
            else:
                pub_content += f"""showed no significant evidence of bias (p = {egger_p:.3f})."""

            subsections.append(ReportSection("Publication Bias", pub_content))

        return ReportSection("Results", "", subsections)

    def _generate_discussion(self, results: Dict[str, Any]) -> ReportSection:
        """Generate discussion section"""

        pooled = results.get('pooled_effect', 0)
        p_value = results.get('p_value', 1)
        i2 = results.get('i_squared', 0)

        content = f"""The present meta-analysis provides """

        if p_value < 0.05:
            content += f"""strong evidence for an effect (pooled estimate = {pooled:.2f}, p = {p_value:.3f}). """
        else:
            content += f"""insufficient evidence for an effect (pooled estimate = {pooled:.2f}, p = {p_value:.3f}). """

        if i2 > 50:
            content += f"""However, the high heterogeneity (I² = {i2:.1f}%) suggests """
            content += f"""that effect sizes vary considerably across studies. """
            content += f"""Future research should investigate potential moderators of this variability. """
        else:
            content += f"""The low heterogeneity (I² = {i2:.1f}%) suggests """
            content += f"""relatively consistent effects across different study contexts. """

        content += f"""\n\n**Limitations:** """
        content += f"""This analysis has several limitations including potential publication bias, """
        content += f"""heterogeneity across study designs, and limitations inherent to the included studies. """
        content += f"""Results should be interpreted considering these factors."""

        return ReportSection("Discussion", content)

    def _generate_conclusion(self, results: Dict[str, Any]) -> ReportSection:
        """Generate conclusion section"""

        pooled = results.get('pooled_effect', 0)
        p_value = results.get('p_value', 1)

        if p_value < 0.001:
            strength = "strong"
        elif p_value < 0.05:
            strength = "moderate"
        else:
            strength = "insufficient"

        content = f"""This meta-analysis provides {strength} evidence """

        if p_value < 0.05:
            if pooled > 0:
                content += f"""for a positive effect of the intervention. """
            else:
                content += f"""for a negative effect of the intervention. """

            content += f"""These findings support the use of this intervention """
            content += f"""in the target population, though individual patient factors should be considered."""
        else:
            content += f"""for an intervention effect. """
            content += f"""Additional high-quality studies are needed to clarify the intervention's efficacy."""

        return ReportSection("Conclusion", content)

    def export_to_markdown(self, report: Dict[str, Any]) -> str:
        """Export report to markdown format"""
        md = f"# {report['title']}\n\n"
        md += f"*Generated: {report['generated_at']}*\n\n"
        md += f"*Method: {report['metadata']['generation_method'].upper()}*\n\n"
        md += "---\n\n"

        for section_dict in report['sections']:
            section = self._dict_to_section(section_dict)
            md += section.to_markdown()

        return md

    def export_to_html(self, report: Dict[str, Any]) -> str:
        """Export report to HTML format"""
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>{report['title']}</title>
    <style>
        body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; line-height: 1.6; }}
        h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; }}
        h2 {{ color: #34495e; margin-top: 30px; }}
        h3 {{ color: #7f8c8d; }}
        .metadata {{ color: #95a5a6; font-size: 0.9em; }}
    </style>
</head>
<body>
    <h1>{report['title']}</h1>
    <p class="metadata">Generated: {report['generated_at']} | Method: {report['metadata']['generation_method'].upper()}</p>
    <hr>
"""

        for section_dict in report['sections']:
            html += self._section_to_html(section_dict, level=2)

        html += """
</body>
</html>"""

        return html

    def _dict_to_section(self, section_dict: Dict[str, Any]) -> ReportSection:
        """Convert dictionary back to ReportSection"""
        subsections = [self._dict_to_section(s) for s in section_dict.get('subsections', [])]
        return ReportSection(section_dict['title'], section_dict['content'], subsections)

    def _section_to_html(self, section_dict: Dict[str, Any], level: int = 2) -> str:
        """Convert section to HTML"""
        html = f"<h{level}>{section_dict['title']}</h{level}>\n"
        if section_dict['content']:
            html += f"<p>{section_dict['content']}</p>\n"

        for subsection in section_dict.get('subsections', []):
            html += self._section_to_html(subsection, level + 1)

        return html


# Example usage
if __name__ == "__main__":
    # Test report generation
    generator = NaturalLanguageReportGenerator()

    # Mock data
    results = {
        'pooled_effect': 0.45,
        'ci_lower': 0.32,
        'ci_upper': 0.58,
        'p_value': 0.001,
        'i_squared': 45.2,
        'tau_squared': 0.08,
        'q_p_value': 0.03,
        'egger_p': 0.15,
        'total_participants': 5420,
        'publication_years': [2015, 2016, 2018, 2019, 2020, 2021, 2022]
    }

    study_data = pd.DataFrame({
        'study': ['Study1', 'Study2', 'Study3', 'Study4', 'Study5'],
        'year': [2018, 2019, 2020, 2021, 2022]
    })

    config = {
        'title': 'Effect of Intervention X on Outcome Y: A Meta-Analysis',
        'model': 'random-effects',
        'measure': 'standardized mean differences',
        'search_dates': {'start': '2015', 'end': '2023'}
    }

    report = generator.generate_full_report(results, study_data, config)

    # Export
    md = generator.export_to_markdown(report)
    print(md)
