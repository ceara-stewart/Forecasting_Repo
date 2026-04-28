# Conversation Summary — 2026-04-27

## Overview

This session covered three main workstreams:
1. **TPO (Wholesale) param grid testing** — reviewing best params from `param_grid_testing.txt` and interpreting regime structure
2. **Retail Broker (RB) anchor DataFrame builder** — creating `ANCHOR_DEFINITIONS_RB` in `Anchor_DF_Builder.ipynb` using params from `param_grid_testing_RB.txt`, with `forecast_biz_days` computed dynamically
3. **Rolling forecast script update** — updating the anchor table code block in `Rolling_30_TPO_Version12.ipynb` to source params from the SQL table (`FDM_Anchor_Params`) instead of hardcoded definitions

---

## 1. TPO Parameter Grid Search Summary (`param_grid_testing.txt`)

### Param Grid
```python
param_grid = {
    'recency_strength':      [0.20, 0.35, 0.50, 1.0, 3.0],
    'dow_shrinkage':         [0.05, 0.10, 0.15, 0.20, 0.25],
    'interaction_shrinkage': [0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50],
    'seasonal_exponent':     [1.0, 1.025, 1.05],
    'trend_dampening':       [0.70, 0.80, 0.85, 0.90],
    'forward_lift_daily':    [0.0, 0.0025, 0.005],
    'level_lookback_days':   [60, 90],
    'trend_seasonal_tilt':   [0.0, 0.08, 0.15],
}
# Total param combos to test per month: 864
```

### Best Params by Month (Full-Month Tuning)

| Month | Abs Err | recency | dampen | lift | lookback | tilt |
|-------|---------|---------|--------|------|----------|------|
| 2025-01 | 0.00% | 0.20 | 0.70 | 0.000 | 60 | 0.08 |
| 2025-02 | 2.46% | 1.00 | 0.70 | 0.005 | 90 | 0.15 |
| 2025-03 | 0.59% | 1.00 | 0.70 | 0.000 | 90 | 0.00 |
| 2025-04 | 0.32% | 1.00 | 0.70 | 0.005 | 90 | 0.15 |
| 2025-05 | 0.03% | 1.00 | 0.70 | 0.005 | 90 | 0.08 |
| 2025-06 | 3.56% | 1.00 | 0.70 | 0.005 | 90 | 0.15 |
| 2025-07 | 5.78% | 1.00 | 0.70 | 0.005 | 90 | 0.15 |
| 2025-08 | 2.68% | 1.00 | 0.70 | 0.005 | 90 | 0.15 |
| 2025-09 | 4.96% | 1.00 | 0.90 | 0.000 | 60 | 0.00 |
| 2025-10 | 0.03% | 0.35 | 0.83 | 0.000 | 60 | 0.08 |
| 2025-11 | 4.38% | 0.35 | 0.83 | 0.000 | 60 | 0.00 |
| 2025-12 | 14.59% | 1.00 | 0.70 | 0.005 | 60 | 0.15 |
| 2026-01 | 0.01% | 0.20 | 0.70 | 0.005 | 90 | 0.00 |
| 2026-02 | 0.09% | 1.00 | 0.83 | 0.000 | 60 | 0.00 |
| 2026-03 | 0.47% | 1.00 | 0.83 | 0.000 | 60 | 0.08 |

### Regime Structure Observed

```
           recency  dampening  lift    lookback  tilt
           -------  ---------  ------  --------  ----
Jan 25:    0.20     0.70       0.000   60        0.08   ← January override
Feb–Aug 25: 1.00   0.70       0.005   90        0.08–0.15  → Regime 1 "Steady State"
Sep 25:    1.00     0.90       0.000   60        0.00   ← Transition
Oct–Nov 25: 0.35   0.83       0.000   60        0.00–0.08  → Regime 2
Jan 26:    0.20     0.70       0.005   90        0.00   ← January override
Feb–Mar 26: 1.00   0.83       0.000   60        0.00–0.08  → Regime 2 continues
```

### Mid-Month Best Params (Forward-Looking Windows)

| Window | Abs Err | Actual | Forecast |
|--------|---------|--------|----------|
| 2025-01-15 → 2025-02-14 | 0.00% | $184,249,711 | $184,253,377 |
| 2025-02-15 → 2025-03-14 | 0.01% | $168,277,552 | $168,289,937 |
| 2025-03-15 → 2025-04-14 | 0.00% | $177,474,841 | $177,471,559 |
| 2025-04-15 → 2025-05-14 | 0.00% | $201,437,703 | $201,441,672 |
| 2025-05-15 → 2025-06-14 | 0.02% | $164,153,866 | $164,115,192 |
| 2025-06-15 → 2025-07-14 | 0.00% | $179,798,660 | $179,796,389 |
| 2025-07-15 → 2025-08-14 | 1.51% | $201,504,516 | $198,466,257 |
| 2025-08-15 → 2025-09-14 | 0.00% | $198,860,238 | $198,867,205 |
| 2025-09-15 → 2025-10-14 | 0.00% | $221,240,321 | $221,241,033 |
| 2025-10-15 → 2025-11-15 | 2.97% | $232,823,021 | $225,915,762 |
| 2025-11-15 → 2025-12-15 | 0.01% | $220,485,251 | $220,497,065 |
| 2026-01-15 → 2026-02-15 | 0.82% | $208,363,281 | $206,657,688 |
| 2026-02-15 → 2026-03-15 | 0.02% | $201,089,136 | $201,122,472 |
| 2026-03-15 → 2026-04-15 | 0.01% | $269,234,755 | $269,206,579 |
| 2026-03-20 → 2026-04-20 | 0.00% | $257,144,350 | $257,148,013 |

---

## 2. Retail Broker (RB) Parameter Grid Search Summary (`param_grid_testing_RB.txt`)

### Param Grid
```python
# Total param combos to test per month: 4374
# (expanded grid vs TPO — includes recency_strength=[0.35, 0.55, 1.0], etc.)
```

### Best Params by Month

| Month | Abs Err | recency | dow_shrink | int_shrink | seas_exp | dampen | lift | lookback | tilt |
|-------|---------|---------|------------|------------|----------|--------|------|----------|------|
| 2025-01 | 0.01% | 1.00 | 0.25 | 0.35 | 1.02 | 0.75 | 0.0025 | 30 | 0.08 |
| 2025-02 | 0.01% | 0.55 | 0.25 | 0.60 | 1.02 | 0.90 | 0.006 | 30 | 0.08 |
| 2025-03 | 0.00% | 1.00 | 0.25 | 0.35 | 1.02 | 0.83 | 0.006 | 30 | 0.00 |
| 2025-04 | 0.05% | 0.35 | 0.05 | 0.35 | 1.02 | 0.83 | 0.006 | 90 | 0.12 |
| 2025-05 | 0.01% | 1.00 | 0.25 | 0.20 | 1.00 | 0.83 | 0.006 | 30 | 0.12 |
| 2025-06 | 1.77% | 0.35 | 0.05 | 0.60 | 1.02 | 0.83 | 0.006 | 90 | 0.12 |
| 2025-07 | 0.02% | 1.00 | 0.05 | 0.35 | 1.00 | 0.83 | 0.0025 | 60 | 0.08 |
| 2025-08 | 0.00% | 0.55 | 0.15 | 0.35 | 1.00 | 0.83 | 0.006 | 60 | 0.12 |
| 2025-09 | 0.00% | 0.55 | 0.15 | 0.20 | 1.02 | 0.90 | 0.0025 | 30 | 0.08 |
| 2025-10 | 0.01% | 0.35 | 0.15 | 0.60 | 1.02 | 0.90 | 0.006 | 30 | 0.12 |
| 2025-11 | 0.01% | 1.00 | 0.15 | 0.35 | 1.00 | 0.83 | 0.0025 | 30 | 0.00 |
| 2025-12 | 0.00% | 1.00 | 0.15 | 0.60 | 1.02 | 0.75 | 0.0025 | 60 | 0.12 |
| 2026-01 | 0.00% | 1.00 | 0.15 | 0.60 | 1.00 | 0.75 | 0.004 | 30 | 0.00 |
| 2026-02 | 0.00% | 0.55 | 0.25 | 0.35 | 1.00 | 0.90 | 0.0025 | 60 | 0.00 |
| 2026-03 | 0.01% | 0.55 | 0.05 | 0.35 | 1.00 | 0.83 | 0.0025 | 90 | 0.08 |

### Key RB vs TPO Differences
- RB `trend_dampening` uses `0.75` (Jan, Dec) and `0.83`/`0.90` range vs TPO's `0.70`/`0.83`
- RB `interaction_shrinkage` reaches `0.60` (vs TPO max `0.50`)
- RB `forward_lift_daily` uses `0.006` frequently (vs TPO max `0.005`)
- RB `seasonal_exponent` mostly `1.00`–`1.02` (vs TPO which uses `1.05` more often)
- RB `level_lookback_days` tends to be shorter (`30`) vs TPO (`90`)
- **2025-12**: RB `high_error_flag=False` (0.00% abs err) vs TPO `high_error_flag=True` (14.59%)
- **2026-01**: RB is `january_only=True` (same as TPO)

---

## 3. `Anchor_DF_Builder.ipynb` — Key Changes

### Problem Encountered
The first version of the RB anchor cell (Cell `[8]`) called `compute_forecast_biz_days()` before it was defined, producing:

```
NameError: name 'compute_forecast_biz_days' is not defined
```

### Fix Applied
The `compute_forecast_biz_days()` function (and the updated `build_us_holiday_calendar()`) were moved into a dedicated cell (Cell `[28]`) that runs **before** the RB anchor builder cell. This cell also prints a confirmation:

```
✅ Holiday calendar built: 110 holidays flagged (2021-01-01 → 2030-12-31)
✅ compute_forecast_biz_days() ready
```

### `ANCHOR_DEFINITIONS_RB` Structure
- **15 full-month anchors only** (2025-01 through 2026-03)
- No mid-month anchors — no RB mid-month param tests have been run yet
- `forecast_biz_days` computed dynamically via `compute_forecast_biz_days(window_start, window_end, holiday_calendar)` — **no hardcoded values**
- `channel = 'Retail Broker'`
- `high_error_flag = False` for all anchors including 2025-12 (RB had 0.00% abs err)
- `january_only = True` for 2025-01 and 2026-01

### `compute_forecast_biz_days()` Function
```python
def compute_forecast_biz_days(window_start, window_end, holiday_calendar):
    """
    Counts business days (non-weekend, non-holiday) from window_start to
    window_end inclusive, using the holiday calendar built above.
    """
    holiday_dates = set(
        pd.to_datetime(
            holiday_calendar.loc[holiday_calendar['Is_Holiday'] == 1, 'Calendar_Date']
        )
    )
    all_days = pd.date_range(start=window_start, end=window_end, freq='D')
    return sum(
        1 for d in all_days
        if d.dayofweek not in [5, 6] and d not in holiday_dates
    )
```

### Final `anchor_RB_df` Output
```
✅ 15 anchors loaded into anchor_RB_df
   Jan-only        : 2 anchors
   High-error flag : 0 anchors ([])  
   biz day range   : 18 – 22 days across all anchors
   ⚠️  Mid-month anchors not included — no RB mid-month param tests run yet
```

### Stacking Both Channel Tables
After building both `anchor_TPO_df` (32 rows) and `anchor_RB_df` (15 rows), they are combined:

```python
anchor_combined_df = pd.concat([anchor_RB_df, anchor_TPO_df], ignore_index=True)
# Result: 47 total rows (Retail Broker: 15, Wholesale: 32)
```

---

## 4. `Rolling_30_TPO_Version12.ipynb` — Anchor Table Update

### Context
The rolling forecast script (`Rolling_30_TPO_Version12.ipynb`) previously built its anchor table from hardcoded `ANCHOR_DEFINITIONS` within the notebook. The request was to update this to source params from the SQL table `FDM_Anchor_Params` (which stores the output of `Anchor_DF_Builder.ipynb`) rather than maintaining two separate sets of hardcoded definitions.

### Data Loading
A new SQL cell was added to load from the anchor params table:
```python
select_query = """
SELECT * FROM marketing_sandbox.dbo.FDM_Anchor_Params WITH (NOLOCK);
"""
# Result → anchor_df
```

### Channel Splits
```python
anchor_TPO = anchor_df[anchor_df['channel'] == 'Wholesale'].copy()
anchor_RB  = anchor_df[anchor_df['channel'] == 'Retail Broker'].copy()
```

### Key Design Notes
- `anchor_df` from SQL replaces the hardcoded `ANCHOR_DEFINITIONS` list in the anchor table builder cell
- `forecast_biz_days` is now pre-computed in the table (RB) or carried through from the builder (TPO)
- The `FEATURE_COLS`, `compute_volume_features()`, and `build_anchor_table()` functions remain unchanged
- `RollingParamLookup` and `LeadingIndicatorRegimeDetector` classes are unchanged

---

## 5. File Inventory

| File | Purpose |
|------|---------|
| `param_grid_testing.txt` | TPO (Wholesale) grid search results + regime annotations |
| `param_grid_testing_RB.txt` | Retail Broker grid search results (4374 combos/month) |
| `Anchor_DF_Builder.ipynb` | Builds `anchor_TPO_df` and `anchor_RB_df`; stacks into combined table; writes to SQL |
| `Rolling_30_TPO_Version12.ipynb` | Main rolling forecast script — reads from SQL anchor table |

---

## 6. Biz Day Counts by Month (Computed via `compute_forecast_biz_days`)

| Month | Biz Days (RB computed) | Biz Days (TPO hardcoded) |
|-------|------------------------|--------------------------|
| 2025-01 | 21 | 22 |
| 2025-02 | 19 | — (NaN) |
| 2025-03 | 21 | 21 |
| 2025-04 | 22 | 22 |
| 2025-05 | 21 | 21 |
| 2025-06 | 20 | 21 |
| 2025-07 | 22 | 22 |
| 2025-08 | 21 | 21 |
| 2025-09 | 21 | 21 |
| 2025-10 | 22 | 23 |
| 2025-11 | 18 | 19 |
| 2025-12 | 22 | 22 |
| 2026-01 | 20 | 21 |
| 2026-02 | 19 | — (NaN) |
| 2026-03 | 22 | 22 |

> **Note:** Differences between RB computed and TPO hardcoded values reflect the distinction between `compute_forecast_biz_days()` (non-weekend + non-federal-holiday) vs the SQL `Biz_Day` flag (which may include company holidays). January counts differ because RB uses `2026-01-01` (New Year's Day) exclusion.

---

*Generated: 2026-04-27 | Session participants: ceara-stewart*