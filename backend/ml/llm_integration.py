"""
Local LLM Integration for EvidenceOS PRIME
Uses local Llama 3 models via llama-cpp-python
NO external APIs (ChatGPT, Gemini, Claude, etc.)
"""
import os
import logging
from typing import Optional, Dict, Any, List
from dataclasses import dataclass

logger = logging.getLogger(__name__)

# Check if llama-cpp-python is available
try:
    from llama_cpp import Llama
    LLAMA_AVAILABLE = True
except ImportError:
    LLAMA_AVAILABLE = False
    logger.warning("llama-cpp-python not installed. LLM features will use rule-based fallback.")


@dataclass
class LLMConfig:
    """Configuration for local LLM"""
    model_path: str
    n_ctx: int = 4096  # Context window
    n_threads: int = 4  # CPU threads
    n_gpu_layers: int = 0  # GPU layers (0 = CPU only)
    temperature: float = 0.7
    max_tokens: int = 512
    top_p: float = 0.95
    repeat_penalty: float = 1.1


class LocalLlamaManager:
    """
    Manager for local Llama 3 models
    Handles model loading, inference, and prompt engineering
    """

    def __init__(self, config: Optional[LLMConfig] = None):
        self.config = config or self._default_config()
        self.model: Optional[Llama] = None
        self.is_loaded = False

        # Try to load model if available
        if LLAMA_AVAILABLE and self.config.model_path and os.path.exists(self.config.model_path):
            self.load_model()

    def _default_config(self) -> LLMConfig:
        """Get default configuration from environment"""
        return LLMConfig(
            model_path=os.getenv("LLM_MODEL_PATH", "/models/llama-3-8b-instruct-q4.gguf"),
            n_ctx=int(os.getenv("LLM_CONTEXT_SIZE", "4096")),
            n_threads=int(os.getenv("LLM_THREADS", "4")),
            n_gpu_layers=int(os.getenv("LLM_GPU_LAYERS", "0")),
            temperature=float(os.getenv("LLM_TEMPERATURE", "0.7")),
            max_tokens=int(os.getenv("LLM_MAX_TOKENS", "512"))
        )

    def load_model(self) -> bool:
        """Load Llama model into memory"""
        if not LLAMA_AVAILABLE:
            logger.warning("Cannot load model: llama-cpp-python not installed")
            return False

        if not os.path.exists(self.config.model_path):
            logger.warning(f"Model file not found: {self.config.model_path}")
            return False

        try:
            logger.info(f"Loading Llama model from {self.config.model_path}...")
            self.model = Llama(
                model_path=self.config.model_path,
                n_ctx=self.config.n_ctx,
                n_threads=self.config.n_threads,
                n_gpu_layers=self.config.n_gpu_layers,
                verbose=False
            )
            self.is_loaded = True
            logger.info("Llama model loaded successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to load Llama model: {str(e)}")
            self.is_loaded = False
            return False

    def create_meta_analysis_prompt(self, query: str, context: Dict[str, Any]) -> str:
        """
        Create prompt for meta-analysis questions
        Includes context about the analysis and instructions
        """
        system_prompt = """You are an expert biostatistician and systematic reviewer assistant.
You help researchers interpret meta-analysis results and make analysis decisions.
You provide concise, accurate, evidence-based responses.
You cite specific statistics when available."""

        # Build context section
        context_parts = []

        if 'n_studies' in context:
            context_parts.append(f"Number of studies: {context['n_studies']}")

        if 'pooled_effect' in context:
            context_parts.append(f"Pooled effect: {context['pooled_effect']:.3f} (95% CI: [{context.get('ci_lower', 0):.3f}, {context.get('ci_upper', 0):.3f}])")

        if 'i_squared' in context:
            context_parts.append(f"I² statistic: {context['i_squared']:.1f}%")

        if 'p_value' in context:
            context_parts.append(f"P-value: {context['p_value']:.4f}")

        context_text = "\n".join(context_parts) if context_parts else "No analysis results available yet."

        # Construct full prompt
        prompt = f"""<|begin_of_text|><|start_header_id|>system<|end_header_id|>

{system_prompt}<|eot_id|><|start_header_id|>user<|end_header_id|>

CONTEXT:
{context_text}

QUESTION:
{query}<|eot_id|><|start_header_id|>assistant<|end_header_id|>

"""

        return prompt

    def create_interpretation_prompt(self, metric: str, value: float, context: Dict) -> str:
        """Create prompt for interpreting statistical metrics"""
        system_prompt = """You are an expert in meta-analysis interpretation.
Explain statistical metrics in clear, actionable language for researchers.
Provide practical implications and recommendations."""

        metric_explanations = {
            'i_squared': "I² (I-squared) measures heterogeneity between studies",
            'tau_squared': "τ² (tau-squared) estimates between-study variance",
            'icer': "ICER (Incremental Cost-Effectiveness Ratio) is cost per QALY gained",
            'p_value': "P-value indicates statistical significance"
        }

        metric_desc = metric_explanations.get(metric, metric)

        prompt = f"""<|begin_of_text|><|start_header_id|>system<|end_header_id|>

{system_prompt}<|eot_id|><|start_header_id|>user<|end_header_id|>

Interpret this meta-analysis result:

Metric: {metric_desc}
Value: {value}

Provide:
1. What this value means
2. Clinical/practical interpretation
3. Recommended actions

Be concise (2-3 sentences).<|eot_id|><|start_header_id|>assistant<|end_header_id|>

"""

        return prompt

    def generate(self, prompt: str, **kwargs) -> str:
        """
        Generate text using local Llama model

        Args:
            prompt: Input prompt
            **kwargs: Override generation parameters

        Returns:
            Generated text
        """
        if not self.is_loaded:
            logger.warning("Model not loaded, attempting to load...")
            if not self.load_model():
                return self._fallback_generation(prompt)

        try:
            # Override default parameters with kwargs
            params = {
                'max_tokens': kwargs.get('max_tokens', self.config.max_tokens),
                'temperature': kwargs.get('temperature', self.config.temperature),
                'top_p': kwargs.get('top_p', self.config.top_p),
                'repeat_penalty': kwargs.get('repeat_penalty', self.config.repeat_penalty),
                'stop': kwargs.get('stop', ["<|eot_id|>", "<|end_of_text|>"])
            }

            # Generate
            response = self.model(prompt, **params)

            # Extract generated text
            generated_text = response['choices'][0]['text'].strip()

            return generated_text

        except Exception as e:
            logger.error(f"Generation failed: {str(e)}")
            return self._fallback_generation(prompt)

    def _fallback_generation(self, prompt: str) -> str:
        """Fallback when LLM is unavailable"""
        return "LLM not available. Using rule-based interpretation."

    def answer_meta_analysis_question(self, query: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Answer meta-analysis question using local LLM

        Args:
            query: User question
            context: Analysis context (results, parameters, etc.)

        Returns:
            Dictionary with answer and metadata
        """
        # Create prompt
        prompt = self.create_meta_analysis_prompt(query, context)

        # Generate answer
        answer = self.generate(prompt, max_tokens=256, temperature=0.7)

        return {
            'query': query,
            'answer': answer,
            'model': 'local-llama-3' if self.is_loaded else 'rule-based-fallback',
            'context_provided': bool(context)
        }

    def interpret_heterogeneity(self, i_squared: float, tau_squared: float,
                                 n_studies: int) -> str:
        """Interpret heterogeneity using LLM"""
        context = {
            'i_squared': i_squared,
            'tau_squared': tau_squared,
            'n_studies': n_studies
        }

        prompt = self.create_interpretation_prompt('i_squared', i_squared, context)
        return self.generate(prompt, max_tokens=200, temperature=0.5)

    def interpret_icer(self, icer: float, wtp_threshold: float, currency: str = "£") -> str:
        """Interpret ICER using LLM"""
        context = {
            'icer': icer,
            'wtp': wtp_threshold,
            'currency': currency
        }

        prompt = f"""<|begin_of_text|><|start_header_id|>user<|end_header_id|>

Interpret this cost-effectiveness result:

ICER: {currency}{icer:,.0f} per QALY
Willingness-to-Pay Threshold: {currency}{wtp_threshold:,.0f} per QALY

Is the intervention cost-effective? Explain concisely.<|eot_id|><|start_header_id|>assistant<|end_header_id|>

"""
        return self.generate(prompt, max_tokens=150, temperature=0.5)

    def suggest_sensitivity_analyses(self, context: Dict[str, Any]) -> List[str]:
        """Suggest sensitivity analyses using LLM"""
        prompt = f"""<|begin_of_text|><|start_header_id|>user<|end_header_id|>

Given this meta-analysis context:
- Number of studies: {context.get('n_studies', 0)}
- I² = {context.get('i_squared', 0):.1f}%
- Risk of bias distribution: {context.get('rob_distribution', 'unknown')}

Suggest 3-5 sensitivity analyses to test robustness. List only the analyses, one per line.<|eot_id|><|start_header_id|>assistant<|end_header_id|>

"""
        response = self.generate(prompt, max_tokens=200, temperature=0.7)

        # Parse response into list
        suggestions = [line.strip() for line in response.split('\n') if line.strip() and not line.strip().startswith('```')]
        return suggestions[:5]  # Limit to 5

    def generate_analysis_narrative(self, results: Dict[str, Any],
                                      style: str = "academic") -> str:
        """
        Generate narrative text for analysis results
        For automated report generation

        Args:
            results: Analysis results dictionary
            style: "academic", "plain", or "clinical"

        Returns:
            Generated narrative text
        """
        style_prompts = {
            'academic': "Write in formal academic style suitable for publication",
            'plain': "Write in clear, plain language for general audience",
            'clinical': "Write for clinical practitioners, focus on practical implications"
        }

        style_instruction = style_prompts.get(style, style_prompts['academic'])

        prompt = f"""<|begin_of_text|><|start_header_id|>user<|end_header_id|>

{style_instruction}.

Write a 2-3 paragraph narrative summarizing these meta-analysis results:

- Included studies: {results.get('n_studies', 0)}
- Pooled effect: {results.get('pooled_effect', 0):.3f} (95% CI: [{results.get('ci_lower', 0):.3f}, {results.get('ci_upper', 0):.3f}])
- I² = {results.get('i_squared', 0):.1f}%
- P-value: {results.get('p_value', 1):.4f}

Include:
1. Main finding
2. Heterogeneity assessment
3. Clinical/practical interpretation

Do not include headings or bullet points.<|eot_id|><|start_header_id|>assistant<|end_header_id|>

"""

        return self.generate(prompt, max_tokens=500, temperature=0.6)


# Global instance
llm_manager = LocalLlamaManager()
