# Statistical Methods — Room Acoustic Comparison

Technical reference for the statistical methodology used in the cross-room comparison and ranking analysis (`analyze_comparison.m`, `plot_comparison.m`). This document covers the rationale behind each methodological choice, the mathematical formulation, its impact on uncertainty, and known limitations.

## 1. Experimental Design

### 1.1 Structure

The measurement campaign uses a **balanced factorial design**: 9 rooms x 2 source positions x 3 receiver distances = 54 total measurements. Each room has the same 6 source-receiver configurations (src1_front, src1_mid, src1_back, src2_front, src2_mid, src2_back), making this a **complete block design** where source-receiver configuration is the blocking factor.

### 1.2 Why Blocking Matters

Within-room variance has two components:

1. **Systematic position effects** — D50 decreases with distance from the source, Ts increases, etc. These effects are consistent across rooms because the same 6 configurations were used everywhere.
2. **Residual noise** — genuine measurement variability (mic placement error, ambient noise fluctuations, room state differences between measurements).

A one-way ANOVA (room as the sole factor) lumps both components into the error term. A two-way ANOVA (room + position) partitions out the systematic component, leaving only the residual as the error term. This directly increases the F-statistic for the room effect and tightens confidence intervals.

**Impact:** The error degrees of freedom increase from 5 (within-room, n-1) to 40 ((9-1)(6-1)), and the mean squared error decreases because position variance is removed. Both effects improve statistical power.

## 2. Two-Way ANOVA (Blocked Design)

### 2.1 Model

For each acoustic parameter Y, the additive model is:

    Y_ij = mu + alpha_i + beta_j + epsilon_ij

where:
- `mu` is the grand mean
- `alpha_i` is the effect of room i (i = 1, ..., 9)
- `beta_j` is the effect of position j (j = 1, ..., 6)
- `epsilon_ij` is the residual error

The model is additive (no interaction term) because there is only one observation per cell. This is a standard **randomized complete block design** (RCBD) where position is the blocking factor.

### 2.2 Implementation

MATLAB's `anovan` is used with two grouping variables (room and position) and `'model', 'linear'` to fit the additive model. The F-test for the room effect uses the residual mean square as the denominator:

    F_room = MS_room / MS_error

where `MS_error` has df = (9-1)(6-1) = 40.

### 2.3 Assumptions

- **Normality of residuals.** Assumed based on the Central Limit Theorem and the continuous nature of acoustic parameters. Not formally tested (n per cell = 1 precludes within-cell normality checks), but ANOVA is robust to mild non-normality at these sample sizes.
- **Homoscedasticity.** Equal error variance across rooms. Plausible given identical equipment and protocol, but rooms with very different reverberation characteristics may have different measurement variability.
- **Additivity.** No room-by-position interaction. This means position effects are assumed to be the same in every room (e.g., D50 drops by the same amount from front to back in all rooms). This is approximate — rooms with different geometries will have different spatial gradients — but the additive model is the only option with one observation per cell.
- **Independence.** Residuals are independent across cells. Satisfied by the measurement protocol (separate recordings, different rooms, no shared noise sources).

### 2.4 Limitations

- The no-interaction assumption is the strongest. In rooms where the spatial gradient is unusually steep or flat, the residuals will be larger, inflating the pooled error. This is conservative (reduces power) rather than anti-conservative (does not inflate Type I error).
- With only 6 positions per room, the position effect has 5 df, leaving 40 df for error. This is adequate but not generous.

## 3. Tukey HSD Post-Hoc Comparisons

### 3.1 Purpose

The ANOVA F-test determines whether at least one room differs. Tukey's Honestly Significant Difference (HSD) test identifies which specific room pairs differ, controlling the family-wise error rate at alpha = 0.05 across all 36 pairwise comparisons (9 choose 2).

### 3.2 Implementation

`multcompare(stats, 'Dimension', 1)` is called on the `anovan` stats structure, comparing levels of the room factor. This uses the Tukey-Kramer method (which handles balanced designs correctly and reduces to Tukey HSD).

### 3.3 Interpretation

A pair of rooms is declared significantly different if the adjusted p-value < 0.05. The adjustment accounts for all 36 simultaneous comparisons. Output includes the mean difference and its 95% simultaneous confidence interval.

## 4. Composite Speech-Quality Score

### 4.1 Parameter Selection

Three acoustic dimensions are relevant to speech intelligibility in lecture halls:

| Dimension | Candidate parameters | Selected | Reason |
|---|---|---|---|
| Early clarity | D50, C50 | **D50** | D50 and C50 are monotonically related (C50 = 10 log10(D50/(1-D50))); D50 is more intuitive (proportion of early energy) |
| Reverberation | T20, T30 | **T20** | T20 uses the -5 to -25 dB range of the EDC, which is less affected by noise floor limitations of the uncalibrated USB microphone. T30 (-5 to -35 dB) requires 10 dB more dynamic range. |
| Centre time | Ts | **Dropped** | Ts is highly correlated with D50 (both measure early-vs-late energy balance). Including both would double-count the clarity dimension and add an extra source of uncertainty. |

Using one representative per independent dimension avoids redundancy and keeps the composite interpretable.

### 4.2 Weighting

| Parameter | Weight | Justification |
|---|---|---|
| D50 | 60% | Primary speech intelligibility metric per ISO 3382. Directly measures the fraction of energy arriving within the first 50 ms. |
| T20 | 40% | Reverberation affects speech clarity but is secondary to early energy balance. The penalty formulation (below) ensures both too-short and too-long reverberation are penalized. |

The 60/40 split is approximately proportional to the original 3-parameter weights (D50: 50%, T30: 30%, Ts: 20%) after removing Ts and renormalizing (50/(50+30) = 62.5%, 30/(50+30) = 37.5%), rounded for simplicity.

### 4.3 Z-Score Normalization

Each parameter is converted to a z-score so that higher values always indicate better speech quality:

**D50** (higher is better):

    z_D50_i = (D50_i - mean(D50)) / std(D50)

where the mean and std are computed across the 9 room means.

**T20** (optimal target, deviation penalized):

    z_T20_i = (s_i - mean(s)) / std(s)
    where s_i = -|T20_i - 0.7|

The absolute deviation from 0.7 s is negated so that rooms closer to the optimal have higher z-scores. The 0.7 s target is based on ISO 3382 and speech acoustics literature recommending 0.4-0.8 s for lecture halls, with 0.7 s as a central value.

**Composite:**

    C_i = 0.60 * z_D50_i + 0.40 * z_T20_i

### 4.4 Interpretation

The composite score is **relative to the measured population** of 9 rooms. A score of 0 means the room is average across the group. Positive scores indicate better-than-average speech quality; negative scores indicate worse. The score has no absolute meaning — it would change if different rooms were measured.

### 4.5 Limitations

- **Weight sensitivity.** The ranking may change under different weight choices. Sensitivity analysis (varying weights) was not performed but could identify rooms whose ranking is robust vs. fragile.
- **Two-parameter composite.** Omitting Ts means spatial information (energy arrival pattern) is only captured through D50's 50 ms boundary. A room with unusual reflection timing might be misjudged.
- **Z-score normalization.** With only 9 rooms, the mean and std used for normalization are estimated from a small sample. Adding or removing a room changes all z-scores.

## 5. Composite Score Uncertainty

### 5.1 Approach: Linear Error Propagation

The composite score is a linear function of the room means D50_i and T20_i (after fixing the z-score normalization constants as population parameters). The variance of the composite is computed by propagating the estimation uncertainty of the room means through the composite formula.

### 5.2 Covariance Matrix from Blocked Model

The additive-model residuals are:

    e_ij = Y_ij - Y_i. - Y_.j + Y_..

where Y_i. is the room mean, Y_.j is the position mean, and Y_.. is the grand mean. These residuals are computed separately for D50 and T20.

The error mean squares and cross-product:

    MSE_D50   = sum(e^D50_ij ^ 2) / df_error
    MSE_T20   = sum(e^T20_ij ^ 2) / df_error
    cross_MSE = sum(e^D50_ij * e^T20_ij) / df_error

where df_error = (9 - 1)(6 - 1) = 40.

The 2x2 covariance matrix of the room mean estimates:

    Sigma_mean = [[MSE_D50, cross_MSE], [cross_MSE, MSE_T20]] / n_pos

This matrix is **shared across all rooms** because the error is pooled under the additive model. It accounts for the correlation between D50 and T20 estimation errors.

### 5.3 Jacobian

The partial derivatives of the composite with respect to the room means (treating z-score normalization constants as fixed):

    J = [dC/dD50, dC/dT20]

where:

    dC/dD50 = w_D50 / sigma_D50
    dC/dT20 = -w_T20 * sign(T20_i - 0.7) / sigma_dev

Here sigma_D50 = std(D50 room means) and sigma_dev = std(-|T20 room means - 0.7|).

The sign term means the Jacobian **differs between rooms above and below the 0.7 s optimal**. This is correct: the derivative of |x - 0.7| changes direction at x = 0.7.

### 5.4 Confidence Interval

    Var(C_i) = J_i * Sigma_mean * J_i'
    CI_i = t(0.975, 40) * sqrt(Var(C_i))

The t-critical value uses df = 40 (from the blocked ANOVA), not df = 5 (from within-room). This is a substantial improvement: t(0.975, 40) = 2.021 vs t(0.975, 5) = 2.571.

### 5.5 Why CIs Differ Between Rooms

Because the Jacobian contains sign(T20_i - 0.7), rooms on opposite sides of 0.7 s have different J(2) signs. The cross-covariance term 2 * J(1) * J(2) * S_12 flips accordingly:

- D50 and T20 are negatively correlated in the residuals (S_12 < 0), because measurement noise that increases apparent reverberation tends to decrease apparent early energy.
- For rooms **below** 0.7 s: the cross term reduces composite variance (the correlation partially cancels errors).
- For rooms **above** 0.7 s: the cross term increases composite variance (errors reinforce).

This is physically meaningful, not an artifact.

### 5.6 Assumptions and Limitations

- **Fixed normalization constants.** The z-score means and stds are treated as known population values when computing the Jacobian. In reality, they are estimated from the same 9 rooms and carry their own uncertainty. This is a standard simplification when the number of groups is moderate.
- **Linearity.** The absolute-value function in the T20 penalty is non-differentiable at T20 = 0.7 s. The sign() function in the Jacobian is the subgradient. For rooms with T20 very close to 0.7 s, the linear approximation may be poor.
- **Normality.** The CI assumes the composite is approximately normally distributed, which follows from the room means being approximately normal (by averaging 6 measurements under the blocked model).

## 6. Regression Fit Quality (R-Squared)

### 6.1 Purpose

T20 is extracted by fitting a straight line to the energy decay curve (EDC) between -5 dB and -25 dB. If the decay is not linear in this range — due to double-slope decays, strong early reflections, or noise contamination — the linear fit is poor and the extracted T20 does not represent the room's true reverberant decay.

The coefficient of determination R-squared quantifies the linearity:

    R2 = 1 - SS_res / SS_tot

where SS_res = sum of squared residuals from the linear fit and SS_tot = total sum of squares about the mean.

### 6.2 Computation

In `rt_from_edc` (within `deconvolve.m`):

1. Select EDC samples in the -5 to -25 dB range
2. Fit a first-degree polynomial via `polyfit`
3. Compute predicted values via `polyval`
4. Calculate R-squared from the residual and total sums of squares

R-squared is computed for both T20 (-5 to -25 dB) and T30 (-5 to -35 dB).

### 6.3 Threshold

A threshold of R2 = 0.99 is used to flag measurements with poor decay linearity. This threshold is based on:

- ISO 3382-1 Section 5.4 requires verification that the decay curve is "sufficiently linear" for the regression to be valid.
- An R-squared of 0.99 means the linear model explains 99% of the variance in the EDC within the evaluation range. Values below this indicate the decay shape deviates meaningfully from a single exponential.
- Literature precedent: Lundeby et al. (1995) use comparable thresholds for decay curve quality.

### 6.4 Visual Indication

In the per-room summary plots (T20 vs. position panel):

- **Filled markers**: R-squared >= 0.99 (good fit, T20 is reliable)
- **Open markers**: R-squared < 0.99 (poor fit, T20 may not represent the room's reverberant decay)
- Each marker is annotated with its exact R-squared value.

### 6.5 Sources of Poor Fit

- **Direct sound dominance** at close receiver positions — the initial steep drop from the direct sound leaks into the -5 to -25 dB evaluation range, steepening the apparent slope and underestimating T20.
- **Double-slope decays** — common in coupled-volume rooms or rooms with a mix of absorptive and reflective surfaces. The EDC shows a knee between two linear regions.
- **Low SNR** at distant positions — noise floor encroaches on the -25 dB level, contaminating the lower end of the regression range.
- **Cardioid microphone directivity** — attenuates late-arriving reflections from behind, which can distort the decay shape compared to an omnidirectional measurement.

### 6.6 Limitations

- R-squared indicates linearity of the decay curve, not accuracy of the T20 value. A perfectly linear but biased decay (e.g., systematically steepened by direct-sound contamination) would show R-squared near 1.0 while still yielding a biased T20.
- The threshold of 0.99 is a guideline, not a hard physical limit. The appropriate threshold depends on the application and acceptable uncertainty.

## 7. Literature Target Ranges

The following target ranges are shown as shaded bands on the parameter comparison plots. They represent values associated with good speech intelligibility in lecture halls.

| Parameter | Target | Source | Notes |
|---|---|---|---|
| T20 | 0.4 - 0.8 s | ISO 3382-1, Rakerd et al. (2018) | Optimal for speech; too short feels dead, too long reduces clarity |
| T30 | 0.4 - 0.8 s | ISO 3382-1 | Same target as T20; T30 >= T20 by definition |
| D50 | > 50% | ISO 3382-1 | Majority of energy in first 50 ms indicates good speech clarity |
| C50 | > 0 dB | ISO 3382-1 | Equivalent to D50 > 50% (more early than late energy) |
| C80 | -2 to 5 dB | ISO 3382-1 | Preferred range for music; included for completeness |
| D80 | — | — | No established single-number target in the literature |
| Ts | — | — | Target not shown; Ts < 100 ms is a rough guideline but parameter was excluded from composite |

These ranges are **absolute** benchmarks, unlike the composite score which is relative. They allow readers to judge whether rooms meet established standards, independent of how they compare to each other.

## 8. Summary of Key Parameters

| Parameter | Value | Justification |
|---|---|---|
| Significance level (alpha) | 0.05 | Standard for scientific hypothesis testing |
| ANOVA model | Two-way additive (room + position) | Exploits the blocked design; removes systematic position variance from error |
| Error df | 40 | (9 rooms - 1) x (6 positions - 1) |
| Post-hoc method | Tukey HSD (via Tukey-Kramer) | Controls family-wise error across all 36 room pairs |
| Composite parameters | D50 (60%), T20 penalty from 0.7 s (40%) | One representative per independent acoustic dimension |
| T20 optimal target | 0.7 s | Central value of 0.4-0.8 s range for speech in lecture halls |
| CI method | Linear error propagation with cross-covariance from blocked-model residuals | Accounts for D50-T20 correlation; uses pooled error with df = 40 |
| R-squared threshold | 0.99 | Flags T20 measurements where the EDC is not well-approximated by a single exponential decay |

## References

- ISO 3382-1:2009, Acoustics — Measurement of room acoustic parameters — Part 1: Performance spaces.
- ISO 3382-2:2008, Acoustics — Measurement of room acoustic parameters — Part 2: Reverberation time in ordinary rooms.
- Lundeby, Vigran, Bietz & Vorlaender (1995). "Uncertainties of measurements in room acoustics." Acustica 81, 344-355.
- Chu, W.T. (1978). "Comparison of reverberation measurements using Schroeder's impulse method and decay-curve averaging method." JASA 63(5).
- Farina, A. (2000). "Simultaneous measurement of impulse response and distortion with a swept-sine technique." 108th AES Convention.
- Rakerd, B. et al. (2018). "Assessing the Acoustic Characteristics of Rooms: A Tutorial With Examples." Perspectives of the ASHA Special Interest Groups 3(19), 8-24.
