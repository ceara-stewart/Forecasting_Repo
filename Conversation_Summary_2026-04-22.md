# Conversation Summary — 2026-04-22

## 1. Updated Pipeline SQL Query in Cell 10 of `Rolling_30_TPO_Pipeline_Comp.ipynb`

### Task
Replace the SQL query in **cell 10** (the `pipeline_df` query) of `Rolling_30_TPO_Pipeline_Comp.ipynb` with the contents of `Pipeline_Query.sql`.

### Key Changes in the New Query

#### CTEs (`app_counts`, `uw_event_counts`, `approval_event_counts`)
- **Before:** Used simple `COUNT(*)` directly against `marketing_sandbox.dbo.SDS`.
- **After:** Now use `COUNT(DISTINCT loan_number)` and `SUM(loan_amount)` via a subquery that `JOIN`s `skinny_core` for `loan_amount`.

#### New Volume Columns Added
- `application_volume`
- `underwriting_submission_event_volume`
- `approval_event_volume`

#### New Average Loan Size Metrics
- `avg_application_loan_size`
- `avg_underwriting_submission_loan_size`
- `avg_approval_loan_size`

#### Updated `GROUP BY`
Now includes the new volume fields:
- `ac.application_volume`
- `uw.underwriting_submission_event_volume`
- `ap.approval_event_volume`

#### `ORDER BY` Simplified
- **Before:** `ORDER BY b.channel, b.filedt`
- **After:** `ORDER BY b.filedt`

#### Pull-Through Fix
- `pull_through_pct_count` now uses `NULLIF(COUNT(DISTINCT ...), 0)` to prevent divide-by-zero (previously used bare `COUNT(DISTINCT ...)`).

### Impact on Output
- Old query produced shape `(1596, 19)`.
- New query will produce **~25 columns** (old 19 + 6 new columns).
- Downstream cells referencing `pipeline_df` (`filedt`, `channel`, `fillna`) remain compatible.

---

## 2. Parameter Testing Results Review (`Testing_Files/TPO_Parameter_Testing`)

### File Contents
A text file (not a directory) containing hyperparameter tuning results for `StructuralLoanForecaster_A`:

- **Param grid:** 864 combinations per month across 8 hyperparameters:
  - `recency_strength`, `dow_shrinkage`, `interaction_shrinkage`, `seasonal_exponent`
  - `trend_dampening`, `forward_lift_daily`, `level_lookback_days`, `trend_seasonal_tilt`

- **Monthly tuning results:** Jan 2025 → Mar 2026
- **Rolling 30-day window results** (e.g., `2025-10-15 → 2025-11-15`)

### Two Regime Patterns Identified

| Regime | recency | dampening | lift | lookback | tilt |
|--------|---------|-----------|------|----------|------|
| **January Override** | 0.20 | 0.70 | 0.000–0.005 | 60–90 | 0.00–0.08 |
| **Regime 1 ("Steady State")** | 1.00 | 0.70 | 0.005 | 90 | 0.08–0.15 |
| **Regime 2** | 0.35–1.00 | 0.83 | 0.000 | 60 | 0.00–0.08 |

### Monthly Assignments
- **Jan 25, Jan 26:** January override
- **Feb–Aug 25:** Regime 1
- **Sep 25:** Transition month
- **Oct–Nov 25, Feb–Mar 26:** Regime 2

### Notable Errors
- Most months achieved <3% absolute error.
- **Dec 2025** was the worst at **-14.59%** — the model significantly underforecast.
- **Sep 2025** had +4.96% error.

---

## 3. Pipeline Comparisons Against Parameters — Code Locations

### `Rolling_30_TPO_Month_Start.ipynb` — `LeadingIndicatorRegimeDetector` class
This is where `pipeline_df` data drives parameter selection. It uses **three leading indicators** from `pipeline_monthly_df`:

1. `application_count_per_bizday`
2. `approval_events_per_bizday_growth_1m`
3. `underwriting_submission_events_per_bizday_growth_1m`

These feed a **composite score** that classifies each forecast month into:
- `'January'` → January override params
- `'Regime1'` → Steady-state params (higher recency, lower dampening)
- `'Regime2'` → Conservative params (lower recency, higher dampening)

### `Rolling_30_TPO_Param_Testing.ipynb` — Grid Search Tuning
Exhaustively tests the param grid against actuals for each calendar month.

### Current Gap
The updated `Pipeline_Query.sql` now returns **new volume-based columns** (`application_volume`, `approval_event_volume`, `underwriting_submission_event_volume`, `avg_*_loan_size`), but the `LeadingIndicatorRegimeDetector` currently only uses **count-based** indicators. The new columns are available in `pipeline_df` but **not yet wired into** the regime detection logic.

---

## Commits Made During This Session

1. **`a1723ceb`** — Initial attempt to update cell 10 SQL query (file was truncated due to notebook JSON complexity).
2. **`1a2e037a`** — Second attempt to restore notebook (still truncated).
3. **`88781422`** — User manually updated the notebook with the correct full content + new SQL query from `Pipeline_Query.sql`. This is the **current correct state** on `main`.