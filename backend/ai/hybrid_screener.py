"""
Hybrid Citation Screener: Rule-Based NLP + Ollama AI
Minimizes hallucinations through multi-layer validation

Architecture:
1. Rule-based extraction (PICO elements, deterministic)
2. AI semantic understanding (handles nuance and synonyms)
3. Decision combination (weighted ensemble)
4. Validation layer (sanity checks, constraint enforcement)
5. Human-in-the-loop triggers (flag risky decisions)

Performance Targets:
- Sensitivity: 97%+ (don't miss relevant studies)
- Specificity: 75%+ (reduce workload)
- Explainability: 100% (every decision auditable)
"""

import re
from typing import Dict, List, Any, Optional, Tuple
import json
from dataclasses import dataclass, asdict
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class Decision(str, Enum):
    """Screening decision types"""
    INCLUDE = "include"
    EXCLUDE = "exclude"
    UNCERTAIN = "uncertain"


@dataclass
class PICOCriteria:
    """Structured PICO inclusion criteria"""
    population: List[str]
    population_synonyms: Dict[str, List[str]]
    intervention: List[str]
    intervention_synonyms: Dict[str, List[str]]
    comparator: List[str]
    outcome: List[str]
    outcome_synonyms: Dict[str, List[str]]
    study_design: List[str]
    study_design_patterns: List[str]

    exclusion_keywords: List[str] = None

    def __post_init__(self):
        if self.exclusion_keywords is None:
            self.exclusion_keywords = [
                'animal', 'rat', 'mouse', 'mice', 'in vitro',
                'review article', 'systematic review', 'meta-analysis',
                'case report', 'editorial', 'letter to editor'
            ]


@dataclass
class Citation:
    """Citation to be screened"""
    id: str
    title: str
    abstract: str
    authors: Optional[str] = None
    year: Optional[int] = None
    journal: Optional[str] = None


@dataclass
class RuleBasedMatch:
    """Result of rule-based matching"""
    population_match: bool
    intervention_match: bool
    comparator_match: bool
    outcome_match: bool
    study_design_match: bool
    exclusion_keyword_found: Optional[str]

    matched_terms: Dict[str, List[str]]
    score: float  # 0-100

    def to_dict(self):
        return asdict(self)


@dataclass
class AIScreeningResult:
    """Result of AI semantic screening"""
    decision: Decision
    confidence: float  # 0-100
    reasoning: str
    population_match: bool
    intervention_match: bool
    study_design_match: bool


@dataclass
class ScreeningResult:
    """Final combined screening result"""
    decision: Decision
    confidence: float
    method: str  # 'rule_based', 'ai', 'hybrid', 'rule_override'

    rule_matches: RuleBasedMatch
    ai_result: Optional[AIScreeningResult]

    needs_review: bool
    review_triggers: List[str]

    explanation: str
    validation_passed: bool

    def to_dict(self):
        return {
            'decision': self.decision.value,
            'confidence': self.confidence,
            'method': self.method,
            'rule_matches': self.rule_matches.to_dict(),
            'ai_result': asdict(self.ai_result) if self.ai_result else None,
            'needs_review': self.needs_review,
            'review_triggers': self.review_triggers,
            'explanation': self.explanation,
            'validation_passed': self.validation_passed
        }


class RuleBasedExtractor:
    """
    Rule-based extraction of PICO elements
    Deterministic, explainable, fast
    """

    def __init__(self, pico: PICOCriteria):
        self.pico = pico

        # Pre-compile regex patterns for efficiency
        self._compile_patterns()

    def _compile_patterns(self):
        """Compile regex patterns for matching"""
        # Study design patterns
        self.rct_patterns = [
            r'\brandomized\b',
            r'\brandomised\b',
            r'\bRCT\b',
            r'\bcontrolled trial\b',
            r'\bdouble[- ]blind\b',
            r'\bsingle[- ]blind\b',
            r'\bplacebo[- ]controlled\b'
        ]

        # Population age patterns
        self.age_patterns = [
            r'adults?',
            r'children',
            r'pediatric',
            r'elderly',
            r'age[ds]?\s*[>≥]\s*\d+',
            r'\d+\s*years?\s*old',
        ]

    def match(self, citation: Citation) -> RuleBasedMatch:
        """
        Match citation against PICO criteria using rules

        Returns:
            RuleBasedMatch with all matching results
        """
        text_lower = (citation.title + ' ' + citation.abstract).lower()

        # 1. Check exclusion keywords first (fast rejection)
        exclusion_found = self._check_exclusions(text_lower)

        if exclusion_found:
            return RuleBasedMatch(
                population_match=False,
                intervention_match=False,
                comparator_match=False,
                outcome_match=False,
                study_design_match=False,
                exclusion_keyword_found=exclusion_found,
                matched_terms={},
                score=0.0
            )

        # 2. Match each PICO component
        pop_match, pop_terms = self._match_population(text_lower)
        int_match, int_terms = self._match_intervention(text_lower)
        comp_match, comp_terms = self._match_comparator(text_lower)
        out_match, out_terms = self._match_outcome(text_lower)
        design_match, design_terms = self._match_study_design(text_lower)

        # 3. Calculate overall score
        matches = [pop_match, int_match, out_match, design_match]
        score = (sum(matches) / len(matches)) * 100

        return RuleBasedMatch(
            population_match=pop_match,
            intervention_match=int_match,
            comparator_match=comp_match,
            outcome_match=out_match,
            study_design_match=design_match,
            exclusion_keyword_found=None,
            matched_terms={
                'population': pop_terms,
                'intervention': int_terms,
                'comparator': comp_terms,
                'outcome': out_terms,
                'study_design': design_terms
            },
            score=score
        )

    def _check_exclusions(self, text_lower: str) -> Optional[str]:
        """Check for exclusion keywords"""
        for keyword in self.pico.exclusion_keywords:
            if re.search(r'\b' + keyword + r'\b', text_lower):
                return keyword
        return None

    def _match_population(self, text_lower: str) -> Tuple[bool, List[str]]:
        """Match population criteria"""
        matched_terms = []

        for term in self.pico.population:
            term_lower = term.lower()
            if term_lower in text_lower:
                matched_terms.append(term)

            # Check synonyms
            if term in self.pico.population_synonyms:
                for synonym in self.pico.population_synonyms[term]:
                    if synonym.lower() in text_lower:
                        matched_terms.append(f"{term} (as {synonym})")

        return len(matched_terms) > 0, matched_terms

    def _match_intervention(self, text_lower: str) -> Tuple[bool, List[str]]:
        """Match intervention criteria"""
        matched_terms = []

        for term in self.pico.intervention:
            term_lower = term.lower()

            # Exact match or with dosing
            if term_lower in text_lower:
                matched_terms.append(term)

            # Check synonyms (e.g., brand names)
            if term in self.pico.intervention_synonyms:
                for synonym in self.pico.intervention_synonyms[term]:
                    if synonym.lower() in text_lower:
                        matched_terms.append(f"{term} (as {synonym})")

        return len(matched_terms) > 0, matched_terms

    def _match_comparator(self, text_lower: str) -> Tuple[bool, List[str]]:
        """Match comparator criteria"""
        matched_terms = []

        for term in self.pico.comparator:
            term_lower = term.lower()
            if term_lower in text_lower:
                matched_terms.append(term)

        # Comparator is less critical - return True if not specified
        if len(self.pico.comparator) == 0:
            return True, ['not specified']

        return len(matched_terms) > 0, matched_terms

    def _match_outcome(self, text_lower: str) -> Tuple[bool, List[str]]:
        """Match outcome criteria"""
        matched_terms = []

        for term in self.pico.outcome:
            term_lower = term.lower()
            if term_lower in text_lower:
                matched_terms.append(term)

            # Check synonyms
            if term in self.pico.outcome_synonyms:
                for synonym in self.pico.outcome_synonyms[term]:
                    if synonym.lower() in text_lower:
                        matched_terms.append(f"{term} (as {synonym})")

        return len(matched_terms) > 0, matched_terms

    def _match_study_design(self, text_lower: str) -> Tuple[bool, List[str]]:
        """Match study design criteria"""
        matched_terms = []

        # Check explicit study design terms
        for term in self.pico.study_design:
            term_lower = term.lower()
            if term_lower in text_lower:
                matched_terms.append(term)

        # Check study design patterns (RCT variations)
        for pattern in self.pico.study_design_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                matched_terms.append(f"RCT (pattern: {pattern})")

        return len(matched_terms) > 0, matched_terms


class HybridCitationScreener:
    """
    Hybrid screener combining rule-based and AI approaches
    """

    def __init__(self, ollama_client, pico: PICOCriteria, confidence_threshold: float = 70):
        self.ai = ollama_client
        self.rule_engine = RuleBasedExtractor(pico)
        self.pico = pico
        self.confidence_threshold = confidence_threshold

    def screen(self, citation: Citation) -> ScreeningResult:
        """
        Screen a single citation using hybrid approach

        Flow:
        1. Rule-based matching (fast, deterministic)
        2. If rules confident → accept
        3. If rules uncertain → ask AI
        4. Combine results with validation
        5. Flag for human review if needed
        """

        # Step 1: Rule-based matching
        rule_result = self.rule_engine.match(citation)

        # Step 2: Check if rules give definitive answer
        if rule_result.score >= 90:
            # Strong rule match - trust it
            return self._create_result_from_rules(rule_result, "rule_based_strong")

        elif rule_result.score == 0 or rule_result.exclusion_keyword_found:
            # Definite exclusion - no need for AI
            return self._create_result_from_rules(rule_result, "rule_based_exclusion")

        # Step 3: Rules uncertain - consult AI
        ai_result = self._ai_screen(citation)

        # Step 4: Combine results
        combined_result = self._combine_results(rule_result, ai_result, citation)

        # Step 5: Validate and flag for review if needed
        validated_result = self._validate_and_flag(combined_result, citation)

        return validated_result

    def _ai_screen(self, citation: Citation) -> AIScreeningResult:
        """Use AI for semantic understanding"""

        system_prompt = """You are an expert systematic reviewer.
Screen citations conservatively - when uncertain, lean towards INCLUSION.
Provide structured answers to each question."""

        prompt = f"""
Inclusion Criteria:
Population: {', '.join(self.pico.population)}
Intervention: {', '.join(self.pico.intervention)}
Outcome: {', '.join(self.pico.outcome)}
Study Design: {', '.join(self.pico.study_design)}

Study to Screen:
Title: {citation.title}
Abstract: {citation.abstract}

Answer these questions:
1. Does the POPULATION match? Consider synonyms and related conditions. (YES/NO)
2. Does the INTERVENTION match? Consider dosing variations. (YES/NO)
3. Is the STUDY DESIGN appropriate? (YES/NO)
4. Overall decision: INCLUDE, EXCLUDE, or UNCERTAIN
5. Confidence (0-100):
6. Brief reasoning (1 sentence):

Format as:
POPULATION: YES/NO
INTERVENTION: YES/NO
STUDY_DESIGN: YES/NO
DECISION: INCLUDE/EXCLUDE/UNCERTAIN
CONFIDENCE: <number>
REASONING: <text>
"""

        try:
            response = self.ai.generate(
                model="llama3",
                prompt=prompt,
                system=system_prompt,
                temperature=0.3  # Low temperature for consistency
            )

            # Parse AI response
            parsed = self._parse_ai_response(response.get('response', ''))

            return parsed

        except Exception as e:
            logger.error(f"AI screening error: {e}")

            # Fallback to uncertain
            return AIScreeningResult(
                decision=Decision.UNCERTAIN,
                confidence=50,
                reasoning=f"AI error: {str(e)}",
                population_match=False,
                intervention_match=False,
                study_design_match=False
            )

    def _parse_ai_response(self, response_text: str) -> AIScreeningResult:
        """Parse structured AI response"""

        # Extract fields using regex
        pop_match = re.search(r'POPULATION:\s*(YES|NO)', response_text, re.IGNORECASE)
        int_match = re.search(r'INTERVENTION:\s*(YES|NO)', response_text, re.IGNORECASE)
        design_match = re.search(r'STUDY_DESIGN:\s*(YES|NO)', response_text, re.IGNORECASE)
        decision_match = re.search(r'DECISION:\s*(INCLUDE|EXCLUDE|UNCERTAIN)', response_text, re.IGNORECASE)
        confidence_match = re.search(r'CONFIDENCE:\s*(\d+)', response_text)
        reasoning_match = re.search(r'REASONING:\s*(.+?)(?:\n|$)', response_text, re.IGNORECASE)

        # Parse with defaults
        population_yes = pop_match and pop_match.group(1).upper() == 'YES' if pop_match else False
        intervention_yes = int_match and int_match.group(1).upper() == 'YES' if int_match else False
        study_design_yes = design_match and design_match.group(1).upper() == 'YES' if design_match else False

        decision_str = decision_match.group(1).upper() if decision_match else 'UNCERTAIN'
        decision = Decision(decision_str.lower()) if decision_str.lower() in ['include', 'exclude', 'uncertain'] else Decision.UNCERTAIN

        confidence = int(confidence_match.group(1)) if confidence_match else 50
        reasoning = reasoning_match.group(1).strip() if reasoning_match else "No reasoning provided"

        return AIScreeningResult(
            decision=decision,
            confidence=confidence,
            reasoning=reasoning,
            population_match=population_yes,
            intervention_match=intervention_yes,
            study_design_match=study_design_yes
        )

    def _create_result_from_rules(self, rule_result: RuleBasedMatch, method: str) -> ScreeningResult:
        """Create screening result from rules only"""

        if rule_result.exclusion_keyword_found:
            decision = Decision.EXCLUDE
            confidence = 95
            explanation = f"Excluded by keyword: {rule_result.exclusion_keyword_found}"
        elif rule_result.score >= 90:
            decision = Decision.INCLUDE
            confidence = 90
            explanation = f"Strong rule match: {rule_result.score:.0f}% criteria met"
        else:
            decision = Decision.EXCLUDE
            confidence = 85
            explanation = f"Low rule match: {rule_result.score:.0f}% criteria met"

        return ScreeningResult(
            decision=decision,
            confidence=confidence,
            method=method,
            rule_matches=rule_result,
            ai_result=None,
            needs_review=False,
            review_triggers=[],
            explanation=explanation,
            validation_passed=True
        )

    def _combine_results(self, rule_result: RuleBasedMatch, ai_result: AIScreeningResult, citation: Citation) -> ScreeningResult:
        """Combine rule-based and AI results"""

        # Strategy: Rules can override AI, but AI can supplement rules

        # Case 1: Study design doesn't match - always exclude
        if not rule_result.study_design_match and not ai_result.study_design_match:
            return ScreeningResult(
                decision=Decision.EXCLUDE,
                confidence=90,
                method="hybrid_study_design_mismatch",
                rule_matches=rule_result,
                ai_result=ai_result,
                needs_review=False,
                review_triggers=[],
                explanation="Study design does not match inclusion criteria (rule + AI agreement)",
                validation_passed=True
            )

        # Case 2: Rule and AI agree
        if self._rule_ai_agree(rule_result, ai_result):
            decision = ai_result.decision
            # Boost confidence when they agree
            confidence = min(95, (rule_result.score * 0.3 + ai_result.confidence * 0.7) + 10)
            method = "hybrid_agreement"
            explanation = f"Rule and AI agree: {ai_result.reasoning}"

            return ScreeningResult(
                decision=decision,
                confidence=confidence,
                method=method,
                rule_matches=rule_result,
                ai_result=ai_result,
                needs_review=False,
                review_triggers=[],
                explanation=explanation,
                validation_passed=True
            )

        # Case 3: Rule and AI disagree - use rules to override risky AI decisions
        if rule_result.score > 70 and ai_result.decision == Decision.EXCLUDE:
            # Rules suggest include but AI says exclude - risky false negative
            return ScreeningResult(
                decision=Decision.UNCERTAIN,
                confidence=60,
                method="hybrid_disagreement_flag",
                rule_matches=rule_result,
                ai_result=ai_result,
                needs_review=True,
                review_triggers=["Rule-AI disagreement", "Potential false negative"],
                explanation=f"Rules suggest match ({rule_result.score:.0f}%) but AI says exclude. Needs review.",
                validation_passed=True
            )

        # Case 4: General combination
        combined_confidence = rule_result.score * 0.4 + ai_result.confidence * 0.6

        return ScreeningResult(
            decision=ai_result.decision,
            confidence=combined_confidence,
            method="hybrid",
            rule_matches=rule_result,
            ai_result=ai_result,
            needs_review=combined_confidence < self.confidence_threshold,
            review_triggers=["Moderate confidence"] if combined_confidence < self.confidence_threshold else [],
            explanation=ai_result.reasoning,
            validation_passed=True
        )

    def _rule_ai_agree(self, rule_result: RuleBasedMatch, ai_result: AIScreeningResult) -> bool:
        """Check if rule and AI results agree"""

        # They agree if:
        # 1. Both suggest include (high rule score + AI include)
        if rule_result.score > 70 and ai_result.decision == Decision.INCLUDE:
            return True

        # 2. Both suggest exclude (low rule score + AI exclude)
        if rule_result.score < 40 and ai_result.decision == Decision.EXCLUDE:
            return True

        return False

    def _validate_and_flag(self, result: ScreeningResult, citation: Citation) -> ScreeningResult:
        """Final validation and human review flagging"""

        triggers = list(result.review_triggers)

        # Validation 1: Low confidence
        if result.confidence < self.confidence_threshold:
            if "Low confidence" not in triggers:
                triggers.append("Low confidence")

        # Validation 2: Critical inclusion (intervention matches but excluded)
        if (result.decision == Decision.EXCLUDE and
            result.rule_matches.intervention_match and
            result.rule_matches.population_match):
            triggers.append("Critical exclusion - intervention + population match")

        # Validation 3: Method is override or disagreement
        if "override" in result.method or "disagreement" in result.method:
            if "Rule-AI conflict" not in triggers:
                triggers.append("Rule-AI conflict")

        # Validation 4: AI hallucination check
        if result.ai_result and result.ai_result.confidence > 90 and result.rule_matches.score < 30:
            # AI very confident but rules don't match - potential hallucination
            triggers.append("Potential AI hallucination")

        result.needs_review = len(triggers) > 0
        result.review_triggers = triggers

        return result

    def batch_screen(self, citations: List[Citation], progress_callback=None) -> Dict[str, List[ScreeningResult]]:
        """
        Screen multiple citations

        Returns:
            Dict with auto_include, auto_exclude, needs_review lists
        """

        results = {
            'auto_include': [],
            'auto_exclude': [],
            'needs_review': []
        }

        for i, citation in enumerate(citations):
            if progress_callback:
                progress_callback(i + 1, len(citations))

            result = self.screen(citation)

            if result.needs_review:
                results['needs_review'].append(result)
            elif result.decision == Decision.INCLUDE:
                results['auto_include'].append(result)
            elif result.decision == Decision.EXCLUDE:
                results['auto_exclude'].append(result)
            else:
                results['needs_review'].append(result)

        return results


# Example usage and validation
if __name__ == "__main__":
    from ai.ollama_client import OllamaClient

    # Example PICO
    pico = PICOCriteria(
        population=["adults", "type 2 diabetes"],
        population_synonyms={
            "type 2 diabetes": ["T2D", "T2DM", "diabetes mellitus type 2", "non-insulin-dependent diabetes"]
        },
        intervention=["metformin"],
        intervention_synonyms={
            "metformin": ["glucophage", "fortamet", "glumetza"]
        },
        comparator=["placebo", "usual care"],
        outcome=["cardiovascular events", "mortality", "HbA1c"],
        outcome_synonyms={
            "cardiovascular events": ["CV events", "MACE", "myocardial infarction", "stroke", "cardiovascular death"]
        },
        study_design=["RCT", "randomized controlled trial"],
        study_design_patterns=[
            r'\brandomized\b',
            r'\brandomised\b',
            r'\bRCT\b',
            r'\bcontrolled trial\b'
        ]
    )

    # Initialize screener
    ollama_client = OllamaClient()
    screener = HybridCitationScreener(ollama_client, pico)

    # Example citation
    citation = Citation(
        id="12345",
        title="Effect of metformin on cardiovascular outcomes in type 2 diabetes",
        abstract="This randomized controlled trial evaluated metformin 1000mg daily vs placebo in 1000 adults with type 2 diabetes. Primary outcome was major adverse cardiovascular events (MACE) over 5 years. Results showed 25% reduction in MACE with metformin (HR 0.75, 95% CI 0.62-0.91, p=0.003)."
    )

    # Screen
    result = screener.screen(citation)

    print(json.dumps(result.to_dict(), indent=2))
