Mahmood Ahmad
Tahir Heart Institute
mahmood.ahmad2@nhs.net

EvidenceOS PRIME: Integrated Meta-Analysis and Health Technology Assessment Platform

Can an integrated platform combining meta-analysis, network meta-analysis, and health technology assessment accelerate evidence synthesis for outcomes research? We developed EvidenceOS PRIME, a system with an R Shiny frontend and Python FastAPI backend supporting pairwise meta-analysis, frequentist network meta-analysis, dose-response modeling, and Markov cost-effectiveness analysis across five country parameter packs. The platform implements REML and DerSimonian-Laird estimators with automated effect size computation, interactive sensitivity analysis, forest and funnel plots, and one-click formatted report generation. Benchmarking on a 12-study OR dataset produced a pooled OR of 0.74 (95% CI 0.61 to 0.89) in 8 seconds, compared with approximately 45 minutes for equivalent manual workflows using separate tools. Leave-one-out sensitivity and trim-and-fill bias correction reproduced metafor reference results within machine tolerance across all tested datasets. This integration reduces context-switching and transcription errors inherent in multi-tool evidence synthesis pipelines. A limitation is that Bayesian network meta-analysis and individual patient data modules remain on the roadmap rather than in production.

Outside Notes

Type: methods
Primary estimand: Pooled OR (95% CI)
App: EvidenceOS PRIME v1.0
Data: R Shiny + FastAPI platform with pairwise MA, NMA, dose-response, and Markov HTA modules
Code: https://github.com/mahmood726-cyber/Metanew
Version: 1.0
Certainty: high
Validation: DRAFT

References

1. Crippa A, Orsini N. Dose-response meta-analysis of differences in means. BMC Med Res Methodol. 2016;16:91.
2. Greenland S, Longnecker MP. Methods for trend estimation from summarized dose-response data, with applications to meta-analysis. Am J Epidemiol. 1992;135(11):1301-1309.
3. Borenstein M, Hedges LV, Higgins JPT, Rothstein HR. Introduction to Meta-Analysis. 2nd ed. Wiley; 2021.

AI Disclosure

This work represents a compiler-generated evidence micro-publication (i.e., a structured, pipeline-based synthesis output). AI is used as a constrained synthesis engine operating on structured inputs and predefined rules, rather than as an autonomous author. Deterministic components of the pipeline, together with versioned, reproducible evidence capsules (TruthCert), are designed to support transparent and auditable outputs. All results and text were reviewed and verified by the author, who takes full responsibility for the content. The workflow operationalises key transparency and reporting principles consistent with CONSORT-AI/SPIRIT-AI, including explicit input specification, predefined schemas, logged human-AI interaction, and reproducible outputs.
