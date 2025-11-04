# evidenceos.utils

> Statistical Utilities for Evidence Synthesis and Meta-Analysis

## Overview

`evidenceos.utils` provides essential statistical methods and quality checks for meta-analysis, extracted and enhanced from Mahmood789's repositories. These utilities fill critical gaps in existing meta-analysis workflows and prevent common methodological errors.

## Key Features

### 🔍 Overfitting Detection
- Detect and quantify overfitting in meta-regression
- Cross-validated R²het calculation
- Bootstrap confidence intervals
- Sample size recommendations

### ✅ Data Validation
- Comprehensive pre-analysis checks
- Enforce minimum quality standards
- Prevent invalid meta-regressions
- Weight diagnostics and inequality metrics

### 🔄 Effect Size Conversions
- Convert between diverse study statistics
- Harmonize data across formats
- Handle incomplete reporting

### 📊 Risk of Bias Tools
- Support for ROB 2.0, ROBINS-I, QUADAS-2
- Professional visualization
- Cluster analysis

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("evidenceos/evidenceos-utils")
```

## Quick Start

```r
library(evidenceos.utils)

# Simulate meta-analysis data
k <- 30
yi <- rnorm(k, 0, 0.3)
vi <- runif(k, 0.01, 0.1)
X <- cbind(1, rnorm(k), rnorm(k))

# Check for overfitting
result <- check_overfitting(yi, vi, X)
print(result)

# Validate data
check_data_validity(yi, vi, X)

# Weight diagnostics
weights <- 1/vi
weight_diagnostics(weights)
```

## Functions

### Overfitting Detection

- `check_overfitting()` - Comprehensive overfitting assessment
- `sample_size_recommendation()` - Minimum k required for target optimism

### Data Validation

- `check_data_validity()` - Pre-analysis data checks
- `weight_diagnostics()` - Weight dispersion and inequality metrics

## Documentation

See function documentation for details:
```r
?check_overfitting
?check_data_validity
?weight_diagnostics
```

## Contributing

This package integrates methods from Mahmood789's repositories. Original code by Mahmood Arai.

Contributions welcome! Please see CONTRIBUTING.md.

## License

MIT License. See LICENSE file.

## Acknowledgments

- **Mahmood Arai** (Mahmood789) - Original methods and code
- **EvidenceOS PRIME Team** - Integration and packaging

## References

1. Harrell FE (2015). Regression Modeling Strategies. Springer.
2. Riley RD et al. (2020). Penalization and shrinkage methods. J Clin Epidemiol.
3. Riley RD et al. (2021). Cross-validation in meta-analysis. Statistics in Medicine.
