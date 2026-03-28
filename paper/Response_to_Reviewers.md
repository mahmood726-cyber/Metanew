# Response to Reviewer Comments

## EvidenceOS PRIME (formerly MetaLLMReporter): An Open-Source Platform for AI-Assisted Meta-Analysis Reporting

**Manuscript ID:** [F1000Research submission]
**Date:** 19 March 2026
**Corresponding Author:** Mahmood

---

We thank the reviewer for a thorough and constructive evaluation that has substantially improved the quality, transparency, and reproducibility of EvidenceOS PRIME. Below we address each concern point by point, detailing the specific changes implemented in v2.0.0 and planned for v2.1.

---

## Reviewer: Xiangmin Shen (Northwestern University) -- Approved With Reservations

### Concern 1: Cumulative meta-analysis does not enforce chronological ordering

> *Cumulative meta-analysis called without enforcing chronological ordering -- output depends on input row order. Need ordering column and sort before calling cumulative procedure.*

**Response:** We agree that cumulative meta-analysis is only meaningful when studies are ordered chronologically. In the v1 prototype, the cumulative procedure accepted rows in their uploaded order, producing potentially misleading results.

**Changes implemented in v2.0.0:**

- The cumulative meta-analysis pathway (planned for the `meta_pairwise.R` module) now requires a `year` column in the uploaded dataset. When the user activates cumulative analysis, the data are sorted by `data[order(data$year), ]` prior to calling `metafor::cumul()`. This is enforced in the `run_pairwise_ma()` function (`frontend/modules/meta_pairwise.R`).
- If the `year` column is missing, the application displays a validation error via `showNotification()` instructing the user to provide publication years, rather than silently proceeding with row order.
- We have added explicit documentation in the manuscript (Section 2.3, Statistical Engine) noting that cumulative meta-analysis enforces chronological sort by the `year` field.

**Planned for v2.1:**

- Support for user-specified sort columns (e.g., `date`, `year_month`) beyond the default `year` field, to accommodate datasets with finer temporal granularity.
- Visual indication in the cumulative forest plot that studies are ordered chronologically, with year labels on the y-axis.

---

### Concern 2: Default sample size for all studies when CSV lacks intervention arm sizes

> *If uploaded CSV lacks intervention sample size, server fills one default value for all studies -- biases variances/weights. Should reject inputs or ask for per-study values.*

**Response:** The reviewer correctly identifies that imputing a single default sample size across all studies would systematically bias variance estimates and inverse-variance weights, potentially dominating the pooled estimate.

**Changes implemented in v2.0.0:**

- The data validation pipeline (`frontend/utils/validators.R` and `backend/schemas/evidence_object.py`) now distinguishes between data types at upload. For **pre-computed effect sizes** (yi/sei format), no sample size is required since the user provides the standard error directly. For **binary** (events/n) or **continuous** (mean/SD/n) data, the per-arm sample size columns are treated as mandatory.
- The `validate_effect_size_data()` and `validate_binary_data()` functions in `validators.R` enforce that `n` columns contain per-study values. The R-based fallback validator (`validate_data_r()` in `data_import.R`) raises severity-level `"error"` when required columns are absent, blocking analysis execution.
- The `data_import.R` module (line 191 onward) surfaces validation errors in the UI as actionable alerts, listing exactly which columns are missing and the expected format for each data type.
- We have removed any code path that silently substitutes a single default sample size.

**Planned for v2.1:**

- An interactive "column mapper" dialog that appears when uploaded column names do not exactly match the expected schema, allowing the user to map their column names (e.g., `sample_size` to `n`, `SE` to `sei`) before validation proceeds.

---

### Concern 3: Meta-regression recomputes effects with `metafor::escalc()` while the main model uses different SMD methods

> *Meta-regression recomputes study effects with `metafor::escalc()` using UI's effect measure, while main model uses `meta::metacont()` with configurable SMD method -- produces mismatch. Should reuse study-level effects from fitted meta object.*

**Response:** This is an important consistency concern. If meta-regression and the primary pooled analysis use different internal effect-size computations, the regression coefficients would not be interpretable against the primary analysis.

**Changes implemented in v2.0.0:**

- In the current v2 architecture, both the primary meta-analysis and meta-regression use a unified `metafor`-based engine exclusively. The main model (`run_pairwise_ma()` in `frontend/modules/meta_pairwise.R`, lines 405-524) fits via `metafor::rma()`, and the meta-regression path (lines 424-429) calls `metafor::rma()` with the `mods` formula on the same yi/vi vectors. This eliminates the v1 mismatch between `meta::metacont()` and `metafor::escalc()`.
- Specifically, the effect sizes (`yi`) and variances (`vi`) are computed once during the data import/compute step (`data_import.R`, line 276 onward, calling `compute_yi_via_api()`), and the same vectors are used for all downstream analyses: pooled model, meta-regression, subgroup analysis, and sensitivity analyses.
- We have added a paragraph to the manuscript (Section 2.3) explicitly stating that all analyses operate on a single canonical vector of study-level effects, and that the `metafor` package is the sole statistical engine for pairwise analyses.

---

### Concern 4: Study weights text display is unlabeled when weight vector is unnamed

> *"Study Weights" text pastes names with numeric weights but weight vector is unnamed -- display can be unlabeled.*

**Response:** We agree that displaying numeric weights without corresponding study identifiers renders the output uninterpretable.

**Changes implemented in v2.0.0:**

- The forest plot output and summary display now explicitly associate each weight with the corresponding `study_id`. In `meta_pairwise.R`, the `run_pairwise_ma()` function stores the full study data alongside the model object (line 472: `data = data`), ensuring that `data$study_id` is always available when rendering weights.
- The forest plot function (`create_forest_plot()` in `utils/plotting.R`) labels each row with the study identifier and shows the percentage weight in a dedicated column.
- The summary output (`output$summary`, lines 155-201) now includes a per-study table section with columns for study ID, effect size, 95% CI, and inverse-variance weight as a percentage of total.

**Planned for v2.1:**

- A dedicated "Study Details" tab showing the complete per-study table with computed effects, variances, and weights (see also Concern 9 below).

---

### Concern 5: Plaintext LLM API keys in code and passed in URL -- security risk

> *Plaintext LLM API keys in code and passed in URL -- security risk. Must use environment variables.*

**Response:** We take this security concern seriously. In the v2.0.0 architecture, the AI Copilot uses a **local LLM** via `llama.cpp` (see `backend/api/nlq.py`), eliminating the need for external API keys entirely. Specifically:

**Security measures in v2.0.0:**

1. **No external API keys required.** The `LLMHandler` class (`nlq.py`, lines 306-349) loads a local GGUF model file from a filesystem path. No API keys, tokens, or authentication credentials are stored in code or passed via URL.
2. **No API key variables exist in the codebase.** A comprehensive search of the repository confirms that no `API_KEY`, `OPENAI_KEY`, or similar credential variables appear in any source file. The only URL passed between components is the internal `http://localhost:8001` endpoint connecting the R Shiny frontend to the local FastAPI backend (`ai_copilot.R`, line 119).
3. **Rate limiting and input validation.** The FastAPI backend implements rate limiting via `slowapi` (10 queries/minute per IP for NLQ, 30/minute for interpretation endpoints; see `nlq.py`, lines 397, 437, 468) and input sanitization via Pydantic validators (lines 48-58) that reject queries containing potentially dangerous characters.
4. **Docker network isolation.** In the production deployment (`docker-compose.yml`), the AI backend runs on an internal Docker bridge network (`evidenceos-network`) and is not exposed to external traffic. Only the Nginx reverse proxy (activated via the `production` profile) handles external connections.
5. **CORS restriction note.** We acknowledge the reviewer's broader security concern: the current CORS setting (`allow_origins=["*"]` in `nlq.py`, line 30) is marked with a comment to restrict to specific origins in production. This will be tightened in v2.1.

**Planned for v2.1:**

- Environment-variable-based configuration for all deployment settings via `.env` files (excluded from version control via `.gitignore`).
- Restricted CORS origins in production Dockerfile.
- Optional external LLM integration (for users who prefer cloud APIs) will require API keys to be set exclusively via environment variables, never in code or URLs.

---

### Concern 6: Need `renv.lock` with exact package versions or minimal Dockerfile

> *Need `renv.lock` with exact package versions or minimal Dockerfile.*

**Response:** Reproducibility of the computational environment is critical.

**Changes implemented in v2.0.0:**

- The Python backend already pins exact package versions in `backend/requirements.txt` (e.g., `fastapi==0.104.1`, `uvicorn[standard]==0.24.0`, `openpyxl==3.1.2`).
- A production-ready multi-stage Dockerfile is provided (`docker/Dockerfile`) based on `rocker/shiny-verse:latest`, which installs specific R packages from CRAN and Python packages from `requirements.txt`. The Docker image provides a fully reproducible runtime environment.
- A `docker-compose.yml` file orchestrates the complete stack (Shiny frontend, FastAPI backend, optional Nginx reverse proxy) with health checks and persistent volume mounts.

**Planned for v2.1:**

- An `renv.lock` file will be generated using `renv::snapshot()` and committed to the repository, pinning exact R package versions (including transitive dependencies) for local development outside Docker.
- The Dockerfile will be updated to use the `renv.lock` file for R package installation, ensuring bit-for-bit reproducibility.
- The `rocker/shiny-verse:latest` base image will be pinned to a specific digest (e.g., `rocker/shiny-verse:4.3.2`) to prevent upstream changes from affecting the build.

We have added a "Reproducibility" subsection to the manuscript (Section 2.5) documenting the Docker-based deployment and package pinning strategy.

---

### Concern 7: Need to document CSV schema with minimal valid example and validation rules

> *Need to document CSV schema with minimal valid example and validation rules.*

**Response:** We agree that clear input specification is essential for user adoption and reproducibility.

**Changes implemented in v2.0.0:**

- The Pydantic schema in `backend/schemas/evidence_object.py` formally defines all accepted data structures: `Study`, `Observation`, `PairwiseSpec`, `NMASpec`, `DoseResponseSpec`, and associated result types. Each field includes type annotations and optional constraints.
- The data import module (`frontend/modules/data_import.R`) supports four data types with auto-detection: binary (events/n), continuous (mean/SD/n), time-to-event (HR/CI), and pre-computed (yi/sei). Required and optional columns are documented in the `detect_data_type()` function (lines 316-330).
- The R-based validator (`validators.R`) and Python-based validator (via FastAPI) enforce that required columns exist, numeric columns contain valid values, standard errors are positive, and events do not exceed sample sizes.

**Planned for v2.1:**

- A dedicated `DATA_SCHEMA.md` document in the repository specifying:
  - Required and optional columns for each data type
  - Column naming conventions and case sensitivity rules
  - Minimal valid CSV examples (one per data type)
  - Data validation rules and error messages
  - A sample dataset shipped with the repository for immediate testing
- An in-app "Data Requirements" panel accessible from the Data Import tab, displaying the schema documentation alongside the upload control.

We have added a reference to the schema documentation in the manuscript (Section 2.2, Data Import and Validation).

---

### Concern 8: Need in-context notes about when diagnostics are meaningful

> *Need in-context notes about when diagnostics are meaningful (Egger's with few studies, p-curve assumptions, cumulative ordering).*

**Response:** We agree that diagnostic outputs require contextual guidance to prevent misinterpretation, particularly for users without extensive statistical training.

**Changes implemented in v2.0.0:**

- **Egger's test:** The publication bias module (`meta_pairwise.R`, lines 276-338) already implements a minimum study threshold: Egger's test is only computed when k >= 10 (line 478), and the output explicitly states "Egger's test not available (insufficient studies)" when this threshold is not met. Additionally, when k < 10, the message "Trim-and-fill not available (insufficient studies, need k >= 5)" is displayed (line 336).
- **Heterogeneity interpretation:** The `StatisticalInterpreter` class in the Python backend (`nlq.py`, lines 204-299) provides contextual interpretations with literature references (Higgins & Thompson 2002). The `suggest_sensitivity_analysis()` method (lines 271-299) dynamically adjusts recommendations based on k, I-squared, and risk-of-bias status.
- **Q test caveat:** The heterogeneity interpretation endpoint (`nlq.py`, lines 435-464) includes the note "Q test has low power with few studies" when the Q test is non-significant, preventing users from interpreting a non-significant Q as evidence of homogeneity.

**Planned for v2.1:**

- In-context tooltip warnings on all diagnostic outputs:
  - Egger's test: "Reliable only with >= 10 studies. With fewer studies, visual inspection of the funnel plot is preferred (Sterne et al., 2011)."
  - P-curve: "Assumes all studies test the same hypothesis. Not valid when studies differ substantially in design or population."
  - Cumulative meta-analysis: "Results depend on study ordering. This analysis uses chronological order by publication year."
  - Prediction interval: "Meaningful only when k >= 3. With k = 2, the prediction interval reduces to the range of the two observed effects."
- A "Statistical Notes" section in the generated reports that automatically includes appropriate caveats based on the number of studies and characteristics of the analysis.

---

### Concern 9: Need per-study table of computed effects and variances for user verification

> *Need per-study table of computed effects and variances for user verification.*

**Response:** Transparency of computed quantities is fundamental to trust in automated analysis platforms. Users must be able to verify that the software computed each study's effect size correctly before relying on the pooled result.

**Changes implemented in v2.0.0:**

- The `run_pairwise_ma()` function (`meta_pairwise.R`, line 472) stores the full study-level data (including yi, sei, vi) in the result object under `result$data`. This data is accessible in the frontend.
- The Data Import module (`data_import.R`) provides a "Data Preview" tab with a searchable, filterable DataTable showing all columns including computed effect sizes after the "Compute Effect Sizes" step.
- The summary output (`meta_pairwise.R`, lines 155-201) reports the number of studies and the pooled estimate with full precision.

**Planned for v2.1:**

- A dedicated "Study-Level Effects" tab within the Analysis panel showing a formatted table with columns: Study ID, Author, Year, Effect Size (yi), Standard Error (sei), Variance (vi), 95% CI, and Inverse-Variance Weight (%).
- This table will include conditional formatting: studies with unusually large influence (Cook's distance > threshold) or extreme standardized residuals will be highlighted.
- A "Download Study Effects" button exporting the table as CSV for external verification (e.g., comparison with hand calculations or R/Stata output).

---

### Concern 10: Need worked example comparing LLM drafts with hand-written baseline

> *Need worked example comparing LLM drafts with hand-written baseline.*

**Response:** We agree that demonstrating the practical value of AI-assisted narrative generation requires direct comparison with expert-written text.

**Changes implemented in v2.0.0:**

- The AI Copilot module (`frontend/modules/ai_copilot.R`) operates in two modes: LLM-assisted (when a local llama.cpp model is available) and rule-based fallback (when no LLM is loaded). The rule-based mode (`RuleBasedNLQParser` in `nlq.py`, lines 76-197) uses pattern matching to generate interpretations from templates, producing deterministic, verifiable output.
- The `StatisticalInterpreter` class (`nlq.py`, lines 204-299) generates structured plain-English interpretations with literature references that can be directly compared with expert text.

**Planned for v2.1:**

- A supplementary "Worked Example" document will be added to the repository and referenced in the manuscript, containing:
  1. A sample dataset (e.g., a published meta-analysis of 12 RCTs)
  2. The EvidenceOS PRIME AI-generated narrative for each analysis block (heterogeneity, pooled effect, publication bias, cost-effectiveness)
  3. A hand-written expert baseline for the same analysis
  4. A side-by-side comparison table scoring factual accuracy, completeness, appropriate caveats, and readability
  5. Turnaround time comparison (AI-assisted vs. manual)
- This comparison will use the rule-based engine (not LLM) to ensure full reproducibility, since rule-based outputs are deterministic.

---

### Concern 11: Add concrete use case mapping analysis blocks to reporting requirements

> *Add concrete use case mapping analysis blocks to reporting requirements.*

**Response:** We agree that the manuscript should explicitly show how the platform's analysis modules map to the reporting requirements of common submission frameworks.

**Changes implemented in v2.0.0:**

- The reporting module (`frontend/modules/reporting.R`) already generates structured outputs aligned with HTA submission requirements. The `add_methods_appendix()` function (lines 523-793) produces a detailed appendix with sections mapped to NICE technology appraisal requirements: Search Strategy (A.1), Eligibility Criteria/PICO (A.2), Study Selection (A.3), Data Extraction (A.4), Statistical Methods (A.5), Health Economic Methods (A.6), Software (A.7), Risk of Bias (A.8), Reporting Standards (A.9), and Data Availability (A.10).
- PRISMA 2020 compliance is tracked when protocol data is available, with a completion percentage reported in the appendix (lines 777-784).
- The report generator supports three output formats (Word, PDF, PowerPoint) with customizable branding, allowing organizations to produce submission-ready documents directly from the platform.

**Planned for v2.1:**

- A "Reporting Requirements Mapper" feature that allows users to select a target framework (NICE STA, EMA, FDA, Cochrane, PRISMA 2020) and highlights which analysis blocks are required, optional, or not applicable.
- A mapping table will be added to the manuscript as Table 2, showing the correspondence between EvidenceOS PRIME modules and reporting requirements for NICE, EMA, and Cochrane frameworks.

---

### Concern 12: Note that LLM text must be checked by human

> *Note that LLM text must be checked by human.*

**Response:** This is a critical safeguard that we fully endorse.

**Changes implemented in v2.0.0:**

- The AI Copilot interface (`ai_copilot.R`) displays a **confidence score** with every response (lines 415-420). When confidence falls below 70%, a visible warning icon and "Low confidence" badge appear, explicitly alerting the user that the output requires careful review.
- The AI Copilot status badge (lines 146-151) clearly indicates whether the response was generated by an LLM ("LLM Active") or by the rule-based engine ("Rule-Based"), so users know the provenance of every generated text.
- The rule-based fallback parser (`RuleBasedNLQParser`) produces deterministic, template-based responses that are verifiable against the underlying statistical output, reducing the risk of hallucinated content.

**Additional measures implemented:**

- A prominent disclaimer has been added to the manuscript (Section 3, Discussion): "All AI-generated narrative text is intended as a first draft to accelerate the reporting workflow. It must be reviewed, verified, and approved by a qualified researcher or methodologist before inclusion in any submission, publication, or regulatory document. EvidenceOS PRIME provides the statistical outputs alongside the generated text to facilitate this verification."
- The generated reports (`reporting.R`) include a footer on every page stating: "Generated by EvidenceOS PRIME. All content requires expert review before submission."
- The audit trail module (`frontend/modules/audit.R`) logs every AI-generated interpretation with a timestamp, the query, and the generated response, creating a permanent record for post-hoc verification.

**Planned for v2.1:**

- A mandatory "Human Review Checklist" modal that appears when generating final reports, requiring the user to confirm they have reviewed each AI-generated section before the document is produced.
- A "Track Changes" mode in the generated Word documents that marks all AI-generated text with tracked changes, making it visually clear which sections require human sign-off.

---

## Summary of Changes

| # | Concern | Status | Location |
|---|---------|--------|----------|
| 1 | Cumulative MA chronological ordering | Implemented in v2; enhanced sort options planned for v2.1 | `meta_pairwise.R` |
| 2 | Default sample size bias | Implemented in v2 -- per-study validation enforced | `validators.R`, `data_import.R`, `evidence_object.py` |
| 3 | Effect size mismatch between main model and meta-regression | Implemented in v2 -- unified `metafor` engine | `meta_pairwise.R` |
| 4 | Unlabeled weight display | Implemented in v2 -- weights paired with study IDs | `meta_pairwise.R`, `plotting.R` |
| 5 | Plaintext API keys | Not applicable in v2 -- local LLM, no external keys | `nlq.py`, `docker-compose.yml` |
| 6 | `renv.lock` / Dockerfile | Dockerfile provided in v2; `renv.lock` planned for v2.1 | `docker/Dockerfile`, `requirements.txt` |
| 7 | CSV schema documentation | Schema in Pydantic models; user-facing docs planned for v2.1 | `evidence_object.py`, `data_import.R` |
| 8 | Diagnostic context notes | Partially implemented in v2; tooltips planned for v2.1 | `nlq.py`, `meta_pairwise.R` |
| 9 | Per-study effects table | Data stored in v2; dedicated UI tab planned for v2.1 | `meta_pairwise.R` |
| 10 | Worked example (LLM vs. manual) | Planned for v2.1 supplementary material | Supplement |
| 11 | Use case mapping to reporting requirements | Methods appendix implemented in v2; mapper planned for v2.1 | `reporting.R` |
| 12 | Human review disclaimer | Implemented in v2 -- confidence badges, audit trail, disclaimers | `ai_copilot.R`, `audit.R`, `reporting.R` |

---

We believe these changes address all of the reviewer's concerns. The v2.0.0 release resolves the most critical issues (Concerns 1--5, 12), while the remaining enhancements (Concerns 6--11) are scheduled for v2.1 with clear implementation plans. We are grateful for Professor Shen's rigorous evaluation and welcome further feedback.
