
<!-- badges: start -->

[![R-CMD-check](https://github.com/adibender/pammtools/workflows/R-CMD-check/badge.svg)](https://github.com/adibender/pammtools/actions)
[![cran
checks](https://badges.cranchecks.info/worst/pammtools.svg)](https://cran.r-project.org/web/checks/check_results_pammtools.html)
[![lifecycle](https://lifecycle.r-lib.org/articles/figures/lifecycle-stable.svg)](https://lifecycle.r-lib.org/articles/stages.html)
[![Build
Status](https://travis-ci.org/adibender/pammtools.svg?branch=master)](https://travis-ci.org/adibender/pammtools)
[![Build
Status](https://ci.appveyor.com/api/projects/status/github/adibender/pammtools?branch=master&svg=true)](https://ci.appveyor.com/project/adibender/pammtools/branch/master)
[![codecov.io](https://codecov.io/github/adibender/pammtools/coverage.svg?branch=master)](https://codecov.io/github/adibender/pammtools/branch/master)
[![CRAN_Status_Badge](https://www.r-pkg.org/badges/version-ago/pammtools)](https://cran.r-project.org/package=pammtools)
[![CRAN_Download_Badge](https://cranlogs.r-pkg.org/badges/pammtools)](https://cran.r-project.org/package=pammtools)
[![MIT
license](http://img.shields.io/badge/license-MIT-brightgreen.svg)]( https://opensource.org/licenses/MIT)
<!-- badges: end -->

# **`pammtools`**: Piece-Wise Exponential Additive Mixed Modeling Tools

### Installation

Install from CRAN or GitHub using:

``` r
# CRAN
install.packages("pammtools")
```

### Overview

**`pammtools`** facilitates the estimation of Piece-wise exponential
Additive Mixed Models (PAMMs) for time-to-event data. PAMMs can be
represented as generalized additive models and can therefore be
estimated using GAM software (e.g. **`mgcv`**), which, compared to other
packages for survival analysis, often offers more flexibility w.r.t. to
the specification of covariate effects (e.g. non-linear, time-varying
effects, cumulative effects, etc.).

To get started, see the
[Articles](https://adibender.github.io/pammtools/articles/) section.

<!-- An overview over the packages functionality is given in

- Andreas Bender and Fabian Scheipl, "pammtools: Piece-wise exponential
Additive Mixed Modeling tools", arXiv eprint, 2018, https://arxiv.org/abs/1806.01042


For a tutorial-like introduction to PAMMs see:

  - Andreas Bender, Andreas Groll, and Fabian Scheipl, “A Generalized Additive Model Approach to Time-to-Event Analysis.” Statistical Modelling. https://doi.org/10.1177/1471082X17748083.


A general framework for the representation and estimation of cumulative effects
(or exposure-lag-response associations) is described in:

- Andreas Bender, Fabian Scheipl, Wolfgang Hartl, Andrew G Day, Helmut Küchenhoff, "Penalized estimation of complex, non-linear exposure-lag-response associations", Biostatistics, , kxy003, 2018, https://doi.org/10.1093/biostatistics/kxy003
 -->
