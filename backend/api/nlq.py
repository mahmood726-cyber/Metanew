"""
AI Copilot - Natural Language Query Endpoint
Interprets user questions about meta-analysis and generates responses
Uses local LLM (llama.cpp) to ensure no data leaves container
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from typing import Optional, Dict, Any, List
import json
import re
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Initialize rate limiter
limiter = Limiter(key_func=get_remote_address)

# Initialize FastAPI app
app = FastAPI(title="EvidenceOS AI Copilot", version="4.0.0")

# Add rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware - allow requests from Shiny frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================

class NLQRequest(BaseModel):
    """Natural language query request with input validation"""
    query: str
    context: Optional[Dict[str, Any]] = None  # Current analysis context
    user_id: Optional[str] = None
    session_id: Optional[str] = None

    @field_validator('query')
    @classmethod
    def validate_query(cls, v: str) -> str:
        """Validate query input"""
        if not v or not v.strip():
            raise ValueError("Query cannot be empty")
        if len(v) > 1000:
            raise ValueError("Query too long (max 1000 characters)")
        # Remove potentially dangerous characters
        if any(char in v for char in ['<', '>', '{', '}']):
            raise ValueError("Query contains invalid characters")
        return v.strip()


class NLQResponse(BaseModel):
    """Natural language query response"""
    action: str  # e.g., "run_meta", "show_forest", "interpret_heterogeneity"
    parameters: Dict[str, Any]  # Parameters for the action
    explanation: str  # Plain English explanation
    code_snippet: Optional[str] = None  # R code to execute
    confidence: float  # 0.0-1.0 confidence score
    reasoning: Optional[str] = None  # Why this interpretation was chosen


# ============================================================================
# RULE-BASED NLQ PARSER (Fallback)
# ============================================================================

class RuleBasedNLQParser:
    """
    Rule-based natural language parser as fallback when LLM unavailable
    Matches patterns to actions
    """

    def __init__(self):
        self.patterns = {
            # Meta-analysis patterns
            r"(run|perform|execute|do)\s+(meta[\s-]?analysis|ma)": {
                "action": "run_meta",
                "explanation": "Running meta-analysis with current data"
            },
            r"(show|display|plot|generate).*?(forest\s+plot|forest)": {
                "action": "show_forest",
                "explanation": "Generating forest plot"
            },
            r"(show|display|plot|generate).*?(funnel\s+plot|funnel)": {
                "action": "show_funnel",
                "explanation": "Generating funnel plot for publication bias assessment"
            },

            # Heterogeneity patterns
            r"(is\s+there|check|assess|test).*heterogeneity": {
                "action": "interpret_heterogeneity",
                "explanation": "Interpreting heterogeneity statistics"
            },
            r"what.*(i[\s-]?squared|i2|heterogeneity)": {
                "action": "interpret_heterogeneity",
                "explanation": "Explaining I² statistic"
            },

            # Cost-effectiveness patterns
            r"(calculate|compute|show|what).*(icer|cost[\s-]?effectiveness)": {
                "action": "run_icer",
                "explanation": "Calculating Incremental Cost-Effectiveness Ratio"
            },
            r"(probability|chance|likelihood).*cost[\s-]?effective": {
                "action": "show_ceac",
                "explanation": "Showing Cost-Effectiveness Acceptability Curve"
            },
            r"cost[\s-]?effective.*at\s+£?(\d+[,\d]*k?)": {
                "action": "check_cost_effective_at_threshold",
                "explanation": "Checking cost-effectiveness at specified threshold"
            },
            r"at\s+£?(\d+[,\d]*k?).*cost[\s-]?effective": {
                "action": "check_cost_effective_at_threshold",
                "explanation": "Checking cost-effectiveness at specified threshold"
            },

            # Scenario comparison patterns
            r"compare.*?(scenarios?|analyses?)": {
                "action": "compare_scenarios",
                "explanation": "Comparing saved scenarios"
            },
            r"(show|display).*scenario.*diff": {
                "action": "show_scenario_diff",
                "explanation": "Showing scenario differences"
            },

            # Study patterns
            r"(how\s+many|count|number\s+of)\s+studies": {
                "action": "count_studies",
                "explanation": "Counting included studies"
            },
            r"(list|show|display)\s+studies": {
                "action": "list_studies",
                "explanation": "Listing included studies"
            },

            # Risk of bias patterns
            r"(assess|show|check).*risk\s+of\s+bias": {
                "action": "assess_rob",
                "explanation": "Assessing risk of bias across studies"
            },
        }

    def parse(self, query: str, context: Optional[Dict] = None) -> NLQResponse:
        """Parse query using pattern matching"""
        query_lower = query.lower()

        for pattern, config in self.patterns.items():
            match = re.search(pattern, query_lower)
            if match:
                # Extract parameters from match groups
                parameters = {}

                # Extract threshold if present (e.g., "£30,000")
                threshold_match = re.search(r'£?(\d+[,\d]*k?)', query)
                if threshold_match and "threshold" in config.get("action", ""):
                    threshold_str = threshold_match.group(1).replace(',', '')
                    if 'k' in threshold_str.lower():
                        threshold = float(threshold_str.lower().replace('k', '')) * 1000
                    else:
                        threshold = float(threshold_str)
                    parameters["wtp_threshold"] = threshold

                # Extract outcome name if present
                if context and "current_outcome" in context:
                    parameters["outcome"] = context["current_outcome"]

                # Extract estimator if specified
                estimator_match = re.search(r'(reml|dl|fe|fixed|random)', query_lower)
                if estimator_match:
                    parameters["estimator"] = estimator_match.group(1).upper()

                return NLQResponse(
                    action=config["action"],
                    parameters=parameters,
                    explanation=config["explanation"],
                    confidence=0.85,  # High confidence for pattern match
                    reasoning="Matched pattern: " + pattern
                )

        # No pattern matched
        return NLQResponse(
            action="unknown",
            parameters={},
            explanation=f"I don't understand the query: '{query}'. Try asking about running meta-analysis, showing plots, or interpreting results.",
            confidence=0.0,
            reasoning="No pattern matched"
        )


# ============================================================================
# STATISTICAL INTERPRETATION ENGINE
# ============================================================================

class StatisticalInterpreter:
    """Interprets statistical results in plain English"""

    @staticmethod
    def interpret_i2(i2: float) -> str:
        """Interpret I² heterogeneity statistic"""
        if i2 < 25:
            level = "low"
            implication = "Treatment effects are consistent across studies."
        elif i2 < 50:
            level = "moderate"
            implication = "There is some variation in treatment effects between studies."
        elif i2 < 75:
            level = "substantial"
            implication = "Treatment effects vary considerably between studies. Consider subgroup analysis."
        else:
            level = "considerable"
            implication = "Treatment effects are highly inconsistent. Pooling may not be appropriate."

        return (
            f"I² = {i2:.1f}% indicates {level} heterogeneity. "
            f"{implication}\n\n"
            f"Reference: Higgins & Thompson (2002) Stat Med - I² thresholds of 25%, 50%, 75%."
        )

    @staticmethod
    def interpret_icer(icer: float, wtp: float = 30000) -> str:
        """Interpret ICER result"""
        if icer < 0:
            return (
                f"ICER = £{icer:,.0f}/QALY (negative ICER). The intervention is DOMINANT "
                f"(cheaper and more effective than comparator)."
            )
        elif icer == 0:
            return (
                f"ICER = £0/QALY. The intervention is DOMINANT "
                f"(equal cost with better outcomes, or better outcomes at no additional cost)."
            )
        elif icer < wtp:
            pct_below = ((wtp - icer) / wtp) * 100
            return (
                f"ICER = £{icer:,.0f}/QALY is {pct_below:.0f}% below the £{wtp:,.0f}/QALY "
                f"threshold. The intervention is likely cost-effective at this threshold.\n\n"
                f"Reference: NICE uses £20,000-£30,000/QALY thresholds (NICE Methods Guide 2013)."
            )
        else:
            pct_above = ((icer - wtp) / wtp) * 100
            return (
                f"ICER = £{icer:,.0f}/QALY exceeds the £{wtp:,.0f}/QALY threshold by {pct_above:.0f}%. "
                f"The intervention is unlikely to be cost-effective at this threshold."
            )

    @staticmethod
    def interpret_p_value(p: float) -> str:
        """Interpret p-value"""
        if p < 0.001:
            return f"p < 0.001 (highly statistically significant)"
        elif p < 0.01:
            return f"p = {p:.3f} (statistically significant at α=0.01)"
        elif p < 0.05:
            return f"p = {p:.3f} (statistically significant at α=0.05)"
        elif p < 0.10:
            return f"p = {p:.3f} (marginally significant)"
        else:
            return f"p = {p:.3f} (not statistically significant)"

    @staticmethod
    def suggest_sensitivity_analysis(i2: float, n_studies: int, has_high_rob: bool) -> List[str]:
        """Suggest sensitivity analyses based on data characteristics"""
        suggestions = []

        if i2 > 50:
            suggestions.append(
                "High heterogeneity detected (I² > 50%). Consider subgroup analysis "
                "by study characteristics (e.g., risk of bias, population, dose)."
            )

        if n_studies >= 10:
            suggestions.append(
                f"With {n_studies} studies, consider meta-regression to explore "
                "sources of heterogeneity (e.g., year, sample size, baseline risk)."
            )

        if has_high_rob:
            suggestions.append(
                "Studies with high risk of bias detected. Run sensitivity analysis "
                "excluding high ROB studies to assess robustness."
            )

        if n_studies >= 10:
            suggestions.append(
                "Sufficient studies for publication bias assessment. Run Egger's test "
                "and trim-and-fill analysis."
            )

        return suggestions if suggestions else ["No specific sensitivity analyses recommended based on current data."]


# ============================================================================
# LLM INTEGRATION (OPTIONAL)
# ============================================================================

class LLMHandler:
    """
    Handler for local LLM (llama.cpp)
    Falls back to rule-based parser if LLM unavailable
    """

    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path
        self.llm = None
        self.use_llm = False

        if model_path:
            try:
                from llama_cpp import Llama
                self.llm = Llama(
                    model_path=model_path,
                    n_ctx=2048,  # Context window
                    n_threads=4,  # CPU threads
                    n_gpu_layers=0  # CPU-only for now
                )
                self.use_llm = True
                print(f"✓ LLM loaded from {model_path}")
            except ImportError:
                print("⚠ llama-cpp-python not installed. Using rule-based fallback.")
            except Exception as e:
                print(f"⚠ LLM loading failed: {e}. Using rule-based fallback.")

    def query_llm(self, prompt: str, max_tokens: int = 256) -> str:
        """Query LLM with prompt"""
        if not self.use_llm:
            return None

        try:
            response = self.llm(
                prompt,
                max_tokens=max_tokens,
                temperature=0.1,  # Low temperature for consistency
                top_p=0.95,
                stop=["</response>", "\n\n\n"]
            )
            return response["choices"][0]["text"].strip()
        except Exception as e:
            print(f"⚠ LLM query failed: {e}")
            return None

    def build_meta_analysis_prompt(self, query: str, context: Optional[Dict] = None) -> str:
        """Build prompt for meta-analysis queries"""
        ctx_str = ""
        if context:
            ctx_str = f"\n\nCurrent analysis context:\n{json.dumps(context, indent=2)}"

        prompt = f"""You are an expert meta-analysis assistant. Parse the user's query and respond with a JSON action.

Available actions:
- run_meta: Run meta-analysis
- show_forest: Generate forest plot
- show_funnel: Generate funnel plot
- interpret_heterogeneity: Explain I² statistic
- run_icer: Calculate cost-effectiveness
- show_ceac: Show cost-effectiveness acceptability curve
- compare_scenarios: Compare saved scenarios

User query: "{query}"{ctx_str}

Respond with JSON in this format:
{{
  "action": "...",
  "parameters": {{}},
  "explanation": "...",
  "confidence": 0.0-1.0
}}

Response:"""

        return prompt


# ============================================================================
# MAIN NLQ ENDPOINT
# ============================================================================

# Initialize handlers
rule_parser = RuleBasedNLQParser()
stat_interpreter = StatisticalInterpreter()

# Try to load LLM (set path to None to skip)
LLM_MODEL_PATH = None  # Set to "/models/llama-7b-q4.gguf" if available
llm_handler = LLMHandler(model_path=LLM_MODEL_PATH)


@app.post("/nlq", response_model=NLQResponse)
@limiter.limit("10/minute")  # Max 10 queries per minute per IP
async def natural_language_query(request: Request, nlq_request: NLQRequest):
    """
    Process natural language query about meta-analysis

    Examples:
    - "Is there significant heterogeneity in the mortality outcome?"
    - "Show me the forest plot"
    - "What's the ICER at £30,000/QALY?"
    - "Compare base case vs high ROB excluded"
    """

    # Try LLM first if available
    if llm_handler.use_llm:
        prompt = llm_handler.build_meta_analysis_prompt(nlq_request.query, nlq_request.context)
        llm_response = llm_handler.query_llm(prompt)

        if llm_response:
            try:
                # BUG FIX #5: Better LLM JSON parsing with error logging
                llm_data = json.loads(llm_response)
                return NLQResponse(
                    action=llm_data.get("action", "unknown"),
                    parameters=llm_data.get("parameters", {}),
                    explanation=llm_data.get("explanation", ""),
                    confidence=llm_data.get("confidence", 0.7),
                    reasoning="LLM-generated response"
                )
            except json.JSONDecodeError as e:
                # Log the error and fall back to rule-based
                print(f"⚠ LLM JSON parsing failed: {e}")
                print(f"  Raw LLM response: {llm_response[:200]}...")
                # Continue to rule-based parser

    # Fallback to rule-based parser
    return rule_parser.parse(nlq_request.query, nlq_request.context)


@app.post("/interpret/heterogeneity")
@limiter.limit("30/minute")  # More lenient for interpretation endpoints
async def interpret_heterogeneity(request: Request, i2: float, tau2: float, q_stat: float, q_pval: float, n_studies: int):
    """Interpret heterogeneity statistics"""
    interpretation = stat_interpreter.interpret_i2(i2)

    # Q test interpretation
    q_result = (
        f"Cochran's Q = {q_stat:.2f} (df = {n_studies - 1}, "
        f"{stat_interpreter.interpret_p_value(q_pval)}). "
    )

    if q_pval < 0.10:
        q_result += "Significant heterogeneity detected."
    else:
        q_result += "No significant heterogeneity detected (but Q test has low power with few studies)."

    # Suggestions
    suggestions = stat_interpreter.suggest_sensitivity_analysis(
        i2=i2,
        n_studies=n_studies,
        has_high_rob=False  # Would need to pass this from context
    )

    return {
        "interpretation": interpretation,
        "q_test": q_result,
        "tau2_interpretation": f"τ² = {tau2:.4f} represents absolute between-study variance.",
        "suggestions": suggestions
    }


@app.post("/interpret/icer")
@limiter.limit("30/minute")  # More lenient for interpretation endpoints
async def interpret_icer(request: Request, icer: float, ci_lower: float, ci_upper: float, wtp: float = 30000):
    """Interpret ICER result"""
    interpretation = stat_interpreter.interpret_icer(icer, wtp)

    ci_interpretation = (
        f"95% CI: £{ci_lower:,.0f} to £{ci_upper:,.0f}/QALY. "
    )

    if ci_lower < wtp < ci_upper:
        ci_interpretation += "Confidence interval crosses the threshold, indicating uncertainty."
    elif ci_upper < wtp:
        ci_interpretation += "Upper CI bound below threshold, strongly suggesting cost-effectiveness."
    else:
        ci_interpretation += "Lower CI bound above threshold, strongly suggesting not cost-effective."

    return {
        "interpretation": interpretation,
        "confidence_interval": ci_interpretation
    }


@app.get("/health")
@limiter.limit("60/minute")  # Very lenient for health checks
async def health_check(request: Request):
    """Health check endpoint"""
    return {
        "status": "healthy",
        "llm_available": llm_handler.use_llm,
        "llm_model": llm_handler.model_path if llm_handler.use_llm else None,
        "version": "4.0.0"
    }


@app.get("/")
@limiter.limit("60/minute")  # Very lenient for root endpoint
async def root(request: Request):
    """API root"""
    return {
        "message": "EvidenceOS AI Copilot",
        "version": "4.0.0",
        "endpoints": {
            "POST /nlq": "Natural language query",
            "POST /interpret/heterogeneity": "Interpret heterogeneity statistics",
            "POST /interpret/icer": "Interpret ICER result",
            "GET /health": "Health check"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
