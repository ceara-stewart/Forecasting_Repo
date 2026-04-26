# Conversation Summary — 2026-04-26

## Overview
This session focused on implementing and debugging a series of changes to `Rolling_30_TPO_Version9.ipynb` — specifically around the k-NN anchor selection logic in `RollingParamLookup` and `StructuralLoanForecaster_Switch`.

---

## Changes Implemented

### Change 2 — `january_only` Flag on January Anchors
Added `'january_only': True` to all four January anchors in `ANCHOR_DEFINITIONS`:
- `2025-01 (full)`
- `2026-01 (full)`
- `2025-01-15 (mid)`
- `2026-01-15 (mid)`

Also updated `build_anchor_table()` to propagate the flag into the DataFrame:
```python
'january_only': anchor.get('january_only', False),
```

---

### Change 3 — `RollingParamLookup.lookup()` — January Pool Filtering
Updated `lookup()` to filter out `january_only` anchors for non-January forecasts.
- Eligible pool built before computing distances
- All distance math and Top-5 display operate on the eligible pool only
- Logging prints pool size and whether Jan anchors were excluded

---

### Change 4 — `_lookup_far_month_anchor()` — January Pool Filtering for Far Months
Added `target_month` parameter so Jan anchors are excluded for non-January far-month lookups.

---

### Change 5 — `forecast_from_date()` — Pass `target_month` to Far Month Lookup
`forecast_from_date()` now passes `target_month=month` when calling `_lookup_far_month_anchor()`.

---

### Change: `StructuralLoanForecaster_Switch` — V4.1 Dual Param Lookup
Upgraded from V3.0 to V4.1:
- `lookup()` now called **twice** in `fit()`:
  - `force_forecast_month=1` → January param set
  - `force_forecast_month=2` → Non-January param set
- Both param sets cached: `_selected_params_jan` / `_selected_params_nonjan`
- `forecast_from_date()` routes each forecast month to the correct Model A
- Fixes: Jan 20 FORECAST_START was applying January anchor params to February forecast dates

---

### Change: `RollingParamLookup.lookup()` — `force_forecast_month` Parameter
Added `force_forecast_month=None` parameter to `lookup()`:
```python
def lookup(self, today, pipeline_wholesale_df, force_forecast_month=None):
    if force_forecast_month is not None:
        effective_month = force_forecast_month
    else:
        window_start_month = pd.to_datetime(window_start).month
        window_end_month   = pd.to_datetime(window_end).month
        effective_month    = 1 if (window_start_month == 1 or window_end_month == 1) else today.month

    include_jan_pool = (effective_month == 1)
```
This fixed the Jan 20 → Feb 20 issue where `today.month == 1` was selecting a January anchor and applying those params to February forecast dates.

---

## Bugs Identified & Root Causes

### Bug 1 — Jan 20 → Feb 20: -14% error (FIXED)
**Root cause:** `lookup()` was called once with `today.month` logic. When `FORECAST_START` was in January, the January anchor was selected and its params were used for **all** forecast months including February.

**Fix:** Dual lookup in `fit()` — one forced January pool, one forced non-January pool. `forecast_from_date()` routes January months to Jan params and all other months to non-Jan params.

**Result:** ✅ Fixed after implementing `force_forecast_month` + dual lookup in Switch.

---

### Bug 2 — Mar 10 → Apr 10: -13% error (IN PROGRESS)
**Root cause:** For `FORECAST_START ~Mar 10`:
- Rolling window = Feb 9 → Mar 9 (mostly February data)
- `2026-02-15 (mid)` wins k-NN at dist=0.11 (near-exact feature match)
- But its params (`recency_strength=0.20`, `level_lookback_days=60`) were tuned for forecasting Feb/Mar, not Mar/Apr
- `2026-03 (full)` anchor only starts winning once `FORECAST_START >= ~Mar 20` (window shifts enough into March)

**Why `2026-03 (full)` is not selected until Mar 20:**
- `FORECAST_START = Mar 10` → window = Feb 9 → Mar 9 → mostly Feb data → `2026-02-15 (mid)` wins
- `FORECAST_START = Mar 20` → window = Feb 19 → Mar 19 → mostly March data → `2026-03 (full)` wins

**Planned fix:** Add a new dedicated anchor `2026-03-10 (mid)` with:
- `window_start = 2026-02-09`
- `window_end = 2026-03-09`
- Params to be confirmed by running param tester for `2025-03-10 → 2025-04-10` (train cutoff: 2025-03-09)

---

## Next Steps

1. **Run param tester for the Mar 10 window:**
   ```
   Period        : 2025-03-10 → 2025-04-10
   Train cutoff  : 2025-03-09
   ```
   This gives grid-search-confirmed best params for the transitional Feb/Mar feature window.

2. **Add `2026-03-10 (mid)` anchor** to `ANCHOR_DEFINITIONS` using those confirmed params.

3. **Backtest Mar 10 → Apr 10 in V9** to confirm error drops after new anchor is added.

4. **Revisit March 10–16 zone** — there may be additional transitional windows (Mar 10, Mar 13, Mar 16) that each need their own anchor if errors persist.

5. **Do not touch `2026-02-15 (mid)` params** — they are working correctly for other time frames.

6. **Do not add April 2026 anchors yet** — April 2026 is not complete; wait for full month actuals before running param tester and adding anchors.

---

## Key Design Decisions Confirmed

| Decision | Rationale |
|---|---|
| `january_only` anchors excluded for non-Jan months | January seasonality is atypical; letting Jan anchors compete for non-Jan forecasts caused param mismatch |
| Dual lookup (Jan + non-Jan) in `fit()` | Single lookup was causing Jan params to bleed into Feb forecast dates when FORECAST_START was in January |
| Do not modify existing working anchor params | `2026-02-15 (mid)` params work correctly for their intended zone — changing them would break other date ranges |
| New anchor per transitional zone | The correct fix for coverage gaps is adding targeted anchors, not modifying existing ones |
| `force_forecast_month` override in `lookup()` | Allows `fit()` to explicitly request Jan or non-Jan pool without relying on window-month heuristics |

---

## Files Modified
- `Rolling_30_TPO_Version9.ipynb` — all changes above applied inline to notebook cells
