# Conversation Summary — 2026-04-23 (Version 2)

## Overview

This session extended the work from Version 1 (same date). The core focus was replacing the month-locked, regime-based param selection system with a fully dynamic daily rolling k-NN param lookup system. The new design is implemented in `Rolling_30_TPO_Version6.ipynb`.

---

## 1. Design Evolution — From Regime Detection to k-NN Param Lookup

### Previous Design (Version 5.5)
- Regime detected once on Day 1 using last full calendar month pipeline data
- Regime label (January / Regime1 / Regime2) mapped to a fixed median param set
- Params locked for the entire calendar month

### Proposed Mid-Month Design (discussed but superseded)
- Day 1: detect regime using last full month (current behavior)
- Day 15: re-compute indicators using MTD data, re-run composite
- If regime shifted: re-fit Model A with new regime params for remaining days

### Final Design Adopted — Daily Rolling k-NN (V3.0)
- **Every run (TODAY):** compute volume features over rolling window [same date last month → yesterday]
  - e.g., TODAY = Apr 23 → window = Mar 22 → Apr 22
- Compare feature vector to 20 historical anchor rows via Euclidean distance (k=1)
- Use nearest anchor's exact best params — no regime label, no averaging
- No smoothing on regime flickering (to be revisited if needed)
- January override removed — goes through k-NN lookup like all other months

---

## 2. Rolling Window Definition

| Parameter | Value |
|---|---|
| window_end | TODAY − 1 calendar day |
| window_start | same calendar day last month |
| prior_end | window_start − 1 calendar day |
| prior_start | prior_end − 1 month (for pct_chg features) |

Example: TODAY = Apr 23 → window = Mar 22 → Apr 22, prior = Feb 22 → Mar 21

---

## 3. Feature Vector (13 Volume Features)

All features computed from `pipeline_wholesale` (Wholesale channel only, from `Pipeline_Query.sql`).

| # | Feature | Source Column | Aggregation |
|---|---|---|---|
| 1 | apps_vol_total | application_volume | SUM over window |
| 2 | apps_vol_per_biz_day | application_volume | SUM / biz day count |
| 3 | apps_vol_pct_chg | application_volume | % chg vs prior window per biz day |
| 4 | uw_vol_total | underwriting_submission_event_volume | SUM over window |
| 5 | uw_vol_per_biz_day | underwriting_submission_event_volume | SUM / biz day count |
| 6 | uw_vol_pct_chg | underwriting_submission_event_volume | % chg vs prior window per biz day |
| 7 | appr_vol_total | approval_event_volume | SUM over window |
| 8 | appr_vol_per_biz_day | approval_event_volume | SUM / biz day count |
| 9 | appr_vol_pct_chg | approval_event_volume | % chg vs prior window per biz day |
| 10 | biz_day_count | Biz_Day | COUNT of business days in window |
| 11 | avg_app_loan_size | avg_application_loan_size | MEAN over window |
| 12 | avg_uw_loan_size | avg_underwriting_submission_loan_size | MEAN over window |
| 13 | avg_appr_loan_size | avg_approval_loan_size | MEAN over window |

All features z-score normalized before distance calculation using mean/std fit on the anchor table.

---

## 4. Anchor Table — 20 Historical Windows

Built dynamically each run: params hardcoded from `TPO_Parameter_Testing`, volume features computed live from `pipeline_wholesale`.

### Full Calendar Month Anchors (15)

| Window | high_error_flag | recency | dampen | lift | lookback | tilt | dow_s | int_s | seas |
|---|---|---|---|---|---|---|---|---|---|
| 2025-01 (full) | False | 0.20 | 0.70 | 0.000 | 60 | 0.08 | 0.25 | 0.20 | 1.05 |
| 2025-02 (full) | False | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.35 | 1.05 |
| 2025-03 (full) | False | 1.00 | 0.70 | 0.000 | 90 | 0.00 | 0.10 | 0.20 | 1.05 |
| 2025-04 (full) | False | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.00 |
| 2025-05 (full) | False | 1.00 | 0.70 | 0.005 | 90 | 0.08 | 0.10 | 0.20 | 1.00 |
| 2025-06 (full) | False | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.05 |
| 2025-07 (full) | False | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.50 | 1.05 |
| 2025-08 (full) | False | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.05 |
| 2025-09 (full) | False | 1.00 | 0.90 | 0.000 | 60 | 0.00 | 0.25 | 0.50 | 1.00 |
| 2025-10 (full) | False | 0.35 | 0.83 | 0.000 | 60 | 0.08 | 0.05 | 0.35 | 1.00 |
| 2025-11 (full) | False | 0.35 | 0.83 | 0.000 | 60 | 0.00 | 0.25 | 0.35 | 1.00 |
| 2025-12 (full) | **True ⚠️** | 1.00 | 0.70 | 0.005 | 60 | 0.15 | 0.25 | 0.20 | 1.05 |
| 2026-01 (full) | False | 0.20 | 0.70 | 0.005 | 90 | 0.00 | 0.25 | 0.50 | 1.05 |
| 2026-02 (full) | False | 1.00 | 0.83 | 0.000 | 60 | 0.00 | 0.25 | 0.35 | 1.02 |
| 2026-03 (full) | False | 1.00 | 0.83 | 0.000 | 60 | 0.08 | 0.05 | 0.20 | 1.02 |

2025-12 flagged: 14.59% abs err — included for feature coverage, params unreliable. Warning printed if selected as nearest neighbor.

### Mid-Month Rolling Window Anchors (5)

| Window | recency | dampen | lift | lookback | tilt | dow_s | int_s | seas |
|---|---|---|---|---|---|---|---|---|
| 2025-10-15 → 2025-11-14 | 1.00 | 0.70 | 0.005 | 60 | 0.15 | 0.05 | 0.35 | 1.05 |
| 2025-11-15 → 2025-12-15 | 0.35 | 0.83 | 0.0025 | 90 | 0.00 | 0.10 | 0.50 | 1.00 |
| 2026-01-15 → 2026-02-14 | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.05 | 0.50 | 1.05 |
| 2026-02-15 → 2026-03-14 | 0.20 | 0.83 | 0.005 | 60 | 0.00 | 0.25 | 0.20 | 1.00 |
| 2026-03-15 → 2026-04-14 | 1.00 | 0.83 | 0.005 | 90 | 0.00 | 0.25 | 0.20 | 1.05 |

---

## 5. k-NN Lookup Logic

```
Every run (TODAY):
  Step 1: window_end = TODAY - 1 day; window_start = same date last month
  Step 2: Pull pipeline_wholesale rows for window + prior window
  Step 3: Compute 13 volume features
  Step 4: Z-score normalize using anchor table mean/std
  Step 5: Euclidean distance to all 20 anchor rows
  Step 6: Select nearest (k=1); warn if high_error_flag=True
  Step 7: Load anchor's exact params into StructuralLoanForecaster_A
  Step 8: Fit Model A; forecast [TODAY, TODAY+30]
```

- k=1 ensures params always come from a real tested combination (no out-of-grid values)
- No flickering smoothing for now — revisit if daily results show instability
- Top-5 nearest anchors printed each run for transparency

---

## 6. Notebook Architecture Changes (V3.0 vs V2.1)

| Component | V2.1 | V3.0 |
|---|---|---|
| LeadingIndicatorRegimeDetector | Active — regime composite + threshold | Retained in notebook (optional), no longer called |
| prepare_pipeline_monthly() | Required for regime detection | Retained for diagnostic print only |
| Param source | Regime median table (3 sets) | k-NN nearest anchor (20 anchors, grows over time) |
| Detection window | Last full calendar month | Rolling: same-date-last-month → yesterday |
| Detection frequency | Once on Day 1 | Every daily run |
| December routing | Model C | Model C (unchanged) |
| model_used column output | A(Regime1) / A(Regime2) | A(2025-10 (full)) — shows matched anchor |
| fit() pipeline input | pipeline_monthly_complete | pipeline_wholesale (raw daily) |

---

## 7. New Cells Added to Rolling_30_TPO_Version6.ipynb

### Cell: ANCHOR_DEFINITIONS + build_anchor_table()
- Hardcoded `ANCHOR_DEFINITIONS` list (20 anchors, params from TPO_Parameter_Testing)
- `compute_volume_features()` — slices pipeline_wholesale for any date range, computes 13 features
- `build_anchor_table()` — iterates all 20 anchors, computes features, z-score stats, prints summary table
- Runs once at notebook startup; takes ~1 second

### Cell: RollingParamLookup
- `_normalize()` — z-scores a feature dict using stored anchor table stats
- `_get_anchor_norm_matrix()` — precomputes normalized anchor feature matrix
- `lookup(today, pipeline_wholesale_df)` — main daily method; returns params, anchor label, distance, features
- Prints window definition, top-5 nearest anchors, and selected params every run

### Cell: StructuralLoanForecaster_Switch (V3.0)
- `fit()` now accepts `pipeline_wholesale_df` (raw daily) instead of `pipeline_monthly_df`
- Calls `RollingParamLookup.lookup()` once inside `fit()` — params cached as `self._selected_params`
- `_build_model_a()` uses cached params — no regime branching
- `forecast_from_date()` builds Model A once per run; `model_used` column shows anchor label

---

## 8. Eval Cell Fixes

- **Root cause of missing dates:** `how='inner'` merge dropped all future forecast dates with no matching actuals
- **Fix:** Changed to `how='left'` with forecast as left table — all forecast dates retained
- MAE/MAPE now computed only on rows where actuals exist (`has_actual_mask`)
- Model column width widened to 160px in Plotly table to accommodate anchor label strings
- Chart color logic updated: `'full'` or `'mid'` in label → steelblue; `'C'` → green

---

## 9. Open Items / Future Work

| Item | Status |
|---|---|
| Flickering / smoothing on daily regime | Deferred — revisit if instability observed |
| January override | Removed for now — goes through k-NN; revisit if Jan performance degrades |
| k > 1 (weighted average of nearest anchors) | Deferred until 20+ anchors available |
| Volume-based within-anchor param fine-tuning | Deferred until n ≥ 8 per regime grouping |
| Adding new anchors as months complete | Manual — add row to ANCHOR_DEFINITIONS each month |
| Retail / Retail Broker / Correspondent channels | Not yet implemented — Wholesale only |

---

## Files Referenced

- TPO_Parameter_Testing — Grid search best params per window (Wholesale)
- Pipeline_Query.sql — Source of all volume feature data
- Rolling_30_TPO_Version6.ipynb — Notebook implementing V3.0
- Conversation_Summary_2026-04-23.md — Prior session (V5.5 param corrections)