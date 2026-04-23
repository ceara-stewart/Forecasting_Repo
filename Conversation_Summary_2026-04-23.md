# Conversation Summary — 2026-04-23

## 1. Pipeline Volume vs Count Indicator Analysis

### Key Finding: Count-Based Indicators Dominate Regime Detection

From threshold_v2.txt:
- Count-only composite correlation with regime: r=0.876
- All (count + volume) composite: r=0.713
- Volume-only composite: r=0.324

Conclusion: Adding volume indicators dilutes regime detection. Count-based signals do the heavy lifting.

### Threshold Search Results

Best threshold = 0.00 with 83.3% accuracy. At full 14-month eval: 11/14 = 78.6%.

Misclassifications at threshold=0.00:
- 2025-02 (Regime1 predicted Regime2): composite=+0.227
- 2025-07 (Regime1 predicted Regime2): composite=+0.737
- 2025-09 (Transition predicted Regime2): expected

### Volume Indicators — Better for Param Fine-Tuning, Not Regime Detection

From step_6.txt, volume indicators correlate with individual hyperparameters but only on n=3-5 observations. Future use: within-regime parameter adjustment once more data accumulates.

---

## 2. Notebook Review — Rolling_30_TPO_Version5.5.ipynb

### Issues Identified and Corrected

1. Threshold: 0.25 changed to 0.00 (from threshold_v2.txt)
2. Regime2 interaction_shrinkage: 0.28 changed to 0.35 (median of grid search)
3. Regime2 seasonal_exponent: 1.02 changed to 1.01 (median of grid search)
4. January level_lookback_days: 60 changed to 75 (avg of Jan 25 and Jan 26)
5. Added full param provenance table from param_grid_testing.txt
6. Added inline citations to threshold_v2.txt, step_10.txt, step_6.txt
7. Documented volume exclusion rationale

### Cells Modified

- Cell 42: LeadingIndicatorRegimeDetector — full rewrite with corrected params, provenance, citations
- Cell 45: StructuralLoanForecaster_Switch — threshold 0.25 changed to 0.00

### Regime Parameter Provenance (from param_grid_testing.txt)

| Month | Regime | recency | dampen | lift | look | tilt | dow_s | int_s | seas |
|---|---|---|---|---|---|---|---|---|---|
| 2025-01 | January | 0.20 | 0.70 | 0.000 | 60 | 0.08 | 0.25 | 0.20 | 1.05 |
| 2025-02 | Regime1 | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.35 | 1.05 |
| 2025-03 | Regime1 | 1.00 | 0.70 | 0.000 | 90 | 0.00 | 0.10 | 0.20 | 1.05 |
| 2025-04 | Regime1 | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.00 |
| 2025-05 | Regime1 | 1.00 | 0.70 | 0.005 | 90 | 0.08 | 0.10 | 0.20 | 1.00 |
| 2025-06 | Regime1 | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.05 |
| 2025-07 | Regime1 | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.50 | 1.05 |
| 2025-08 | Regime1 | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.05 |
| 2025-09 | Transition | 1.00 | 0.90 | 0.000 | 60 | 0.00 | 0.25 | 0.50 | 1.00 |
| 2025-10 | Regime2 | 0.35 | 0.83 | 0.000 | 60 | 0.08 | 0.05 | 0.35 | 1.00 |
| 2025-11 | Regime2 | 0.35 | 0.83 | 0.000 | 60 | 0.00 | 0.25 | 0.35 | 1.00 |
| 2026-01 | January | 0.20 | 0.70 | 0.005 | 90 | 0.00 | 0.25 | 0.50 | 1.05 |
| 2026-02 | Regime2 | 1.00 | 0.83 | 0.000 | 60 | 0.00 | 0.25 | 0.35 | 1.02 |
| 2026-03 | Regime2 | 1.00 | 0.83 | 0.000 | 60 | 0.08 | 0.05 | 0.20 | 1.02 |

### Final Regime Params in Notebook

| Param | January | Regime1 | Regime2 |
|---|---|---|---|
| recency_strength | 0.20 | 1.00 | 0.68 |
| dow_shrinkage | 0.25 | 0.10 | 0.15 |
| interaction_shrinkage | 0.35 | 0.20 | 0.35 |
| seasonal_exponent | 1.05 | 1.05 | 1.01 |
| trend_dampening | 0.70 | 0.70 | 0.83 |
| forward_lift_daily | 0.0025 | 0.005 | 0.0 |
| level_lookback_days | 75 | 90 | 60 |
| trend_seasonal_tilt | 0.04 | 0.15 | 0.04 |

---

## 3. Next Steps — Mid-Month Regime Re-Evaluation

### Problem

Current model locks in a regime on day 1 for 30 days. But step_4.txt shows mid-month windows use different params:

| Window | Regime | recency | dampen | lift | lookback |
|---|---|---|---|---|---|
| 2025-10 full | Regime2 | 0.35 | 0.83 | 0.000 | 60 |
| 2025-10-15 mid | Regime1 | 1.00 | 0.70 | 0.005 | 60 |
| 2025-11 full | Regime2 | 0.35 | 0.83 | 0.000 | 60 |

### Proposed Design

1. Day 1: Detect regime using last full month pipeline data (current behavior)
2. Day 15: Re-compute pipeline indicators using MTD data, re-run composite
3. If regime shifted: Re-fit Model A with new regime params for remaining days

### Design Decision Pending

- Hard switch: Days 1-15 use Regime1, days 16-31 use Regime2
- Blend: Linearly interpolate params over days 12-18
- Third option: Treat mid-month as its own param set

Status: Design discussed, implementation pending next session.

---

## Files Referenced

- threshold_v2.txt — Composite score analysis and threshold search
- step_10.txt — Per-biz-day normalized indicator correlations with regime
- step_6.txt — Pipeline and calendar indicator correlations with optimal params
- step_5.txt — Lead time matching counts
- Step_4.txt — Full-month vs mid-month parameter comparison
- param_grid_testing.txt — Grid search results (864 combos per month)
- Rolling_30_TPO_Version5.5.ipynb — Main forecasting notebook