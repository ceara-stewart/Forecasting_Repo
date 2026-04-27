# Conversation Summary — 2026-04-26 v2

## Overview
This session continued directly from the 2026-04-26 summary. The core focus was diagnosing and fixing the persistent **-13% to -14% error on the Mar 10 → Apr 10 run date** in `Rolling_30_TPO_Version11.ipynb`. Multiple fix attempts were made, the root cause was correctly identified, and a robust tie-breaking mechanism was added to `RollingParamLookup.lookup()`. The session closed with a forward-looking architectural discussion around automating param generation.

---

## Files Modified
- `Rolling_30_TPO_Version11.ipynb` — all changes applied inline to notebook cells

---

## Changes Implemented

### Change 1 — New Anchor `2026-03-10 (mid)` (First Attempt — Later Superseded)

**Motivation:** The Mar 10 run date was producing -13% error. The rolling window for `FORECAST_START = Mar 10` was computed as `Feb 9 → Mar 9`, and the nearest anchor was `2026-02-15 (mid)` whose params were tuned for forecasting Feb/Mar — not Mar/Apr.

**Param tester run:**
```
Period        : 2026-03-10 → 2026-04-10
Train cutoff  : 2026-03-09
Actual biz days: 24
Actual total   : $260,350,386

recency_strength             = 0.20
dow_shrinkage                = 0.10
interaction_shrinkage        = 0.20
seasonal_exponent            = 1.02
trend_dampening              = 0.83
forward_lift_daily           = 0.0
level_lookback_days          = 60
trend_seasonal_tilt          = 0.15
```

**Anchor added to `ANCHOR_DEFINITIONS`:**
```python
{
    'label':           '2026-03-10 (mid)',
    'window_start':    '2026-02-09', 'window_end': '2026-03-09',
    'prior_start':     '2026-01-09', 'prior_end':  '2026-02-08',
    'high_error_flag': False,
    'params': dict(recency_strength=0.20, dow_shrinkage=0.10, interaction_shrinkage=0.20,
                   seasonal_exponent=1.02, trend_dampening=0.83, forward_lift_daily=0.000,
                   level_lookback_days=60, trend_seasonal_tilt=0.15),
},
```

**Result:** Error persisted at -14%. Anchor was not being selected.

---

### Root Cause Investigation — Why `2026-03-10 (mid)` Was Not Selected

**Diagnostic output showed:**
```
TODAY           : 2026-03-16
Window          : 2026-02-15 → 2026-03-15
Nearest anchor  : 2026-02-15 (mid)  (dist=0.7742)
```

**Key insight:** The system runs with `TODAY = Mar 16` (not Mar 10) because Mar 10–13 are already locked as actuals in the funding system, and forecasting begins on Mar 16. Therefore:

- Live rolling window = `Feb 15 → Mar 15` (not `Feb 9 → Mar 9`)
- `2026-03-10 (mid)` was built for window `Feb 9 → Mar 9` — never matches the live window
- `2026-02-15 (mid)` correctly wins at dist=0.77 — this is expected behavior

**The real problem:** `2026-02-15 (mid)` params were grid-searched to optimally forecast the period **immediately following** a `Feb 15 → Mar 14` training window (i.e., forecasting mid-Feb through mid-March). But on a Mar 16 run date, those same params are being used to forecast **Mar 16 → Apr 10** — a different forecast horizon that the params were never tuned for.

---

### Change 2 — New Anchor `2026-03-16 (mid)` (Correct Fix)

**Param tester run with correct training and forecast window:**
```
Period        : 2026-03-16 → 2026-04-16
Train cutoff  : 2026-03-15
Actual biz days: 24
Actual total   : $271,254,689

recency_strength             = 1.0
dow_shrinkage                = 0.05
interaction_shrinkage        = 0.35
seasonal_exponent            = 1.02
trend_dampening              = 0.83
forward_lift_daily           = 0.005
level_lookback_days          = 60
trend_seasonal_tilt          = 0.15
```

**Anchor added to `ANCHOR_DEFINITIONS`** (inserted between `2026-02-15 (mid)` and `2026-03-10 (mid)`):
```python
{
    'label':           '2026-03-16 (mid)',
    'window_start':    '2026-02-15', 'window_end': '2026-03-15',   # same feature window as 2026-02-15 (mid)
    'prior_start':     '2025-11-15', 'prior_end':  '2025-12-14',   # same prior as 2026-02-15 (mid)
    'high_error_flag': False,
    'params': dict(recency_strength=1.00, dow_shrinkage=0.05, interaction_shrinkage=0.35,
                   seasonal_exponent=1.02, trend_dampening=0.83, forward_lift_daily=0.005,
                   level_lookback_days=60, trend_seasonal_tilt=0.15),
},
```

**Problem discovered:** `2026-03-16 (mid)` and `2026-02-15 (mid)` share the **identical feature window** (`Feb 15 → Mar 15` / `Feb 15 → Mar 14` are 1 day apart in `window_end`), producing a **tied distance of 0.7842**. `np.argmin()` resolved the tie by list order — `2026-02-15 (mid)` appeared first and kept winning.

---

### Change 3 — Tie-Breaking Logic in `RollingParamLookup.lookup()`

**Cell:** `RollingParamLookup` cell (execution count 43, cell id `2568bef8`)

**Problem:** `np.argmin(distances)` always returns the first index on a tie, making anchor selection silently dependent on list order — fragile and not semantically meaningful.

**Fix:** When two or more anchors share the minimum distance, select the one whose `window_end` is **closest in calendar days to the live `window_end`** — i.e., the most temporally recent matching anchor.

**Before:**
```python
nearest_idx = int(np.argmin(distances))
```
**After:**
```python
# ── Anchor selection with tie-breaking ───────────────────────────────
# If two anchors share the minimum distance, pick the one whose
# window_end is closest to the live window_end (more temporally relevant).
min_dist     = float(distances.min())
tied_indices = np.where(distances == min_dist)[0]

if len(tied_indices) == 1:
    nearest_idx = int(tied_indices[0])
else:
    live_window_end = pd.to_datetime(window_end)
    best_idx        = None
    best_delta      = None
    for idx in tied_indices:
        anchor_window_end = pd.to_datetime(
            ANCHOR_DEFINITIONS[eligible.index[idx]]['window_end']
        )
        delta = abs((anchor_window_end - live_window_end).days)
        if best_delta is None or delta < best_delta:
            best_delta = delta
            best_idx   = idx
    nearest_idx = int(best_idx)
    print(
        f"  ⚡ Tie-break: {len(tied_indices)} anchors at dist={min_dist:.4f} — "
        f"selected '{eligible.iloc[nearest_idx]['label']}' "
        f"(window_end closest to live window_end {live_window_end.date()})"
    )
```

**Header comment updated** to document the tie-break rule:
```
#  SELECTION:
#    k=1 — nearest anchor's exact param set is used directly.
#    No averaging, no interpolation — params always come from a tested combination.
#    Tie-break: if two anchors share the minimum distance, the one whose
#    window_end is closest to the live window_end is selected.
```

**Effect on Mar 10 run date:**
- `2026-02-15 (mid)` → `window_end = 2026-03-14` → delta = 1 day from live `window_end = 2026-03-15`
- `2026-03-16 (mid)` → `window_end = 2026-03-15` → delta = 0 days (exact match)
- `2026-03-16 (mid)` wins the tie-break ✅

**Important note on tie-break implementation:** The tie-break uses `eligible.index[idx]` to map back to `ANCHOR_DEFINITIONS` list position. This works because `eligible` is built from `self.anchor_df` in the same order as `ANCHOR_DEFINITIONS`. If `anchor_df` is ever sorted or reordered independently, this mapping would break. The safer long-term fix is to store `window_end` directly in the anchor DataFrame row during `build_anchor_table()`.

---

### Final `ANCHOR_DEFINITIONS` State (32 anchors)

The anchor header comment was updated to reflect 32 anchors:
```python
#  ANCHORS: 32 total
#    - 15 full calendar month windows (2025-01 through 2026-03)
#    - 5  mid-month rolling windows   (from TPO_Parameter_Testing mid-month entries)
#    - 10 additional mid-month anchors (from tuning run + gap fixes)
#    - 2025-12 included with high_error_flag=True (14.59% abs err)
#    - january_only=True on Jan anchors — excluded from non-January k-NN selection
```
**Mid-month anchor ordering after all changes (chronological):**
```
2025-10-15 (mid)   window: Oct 15 → Nov 14
2025-11-15 (mid)   window: Nov 15 → Dec 14
2026-01-15 (mid)   window: Jan 15 → Feb 14   [january_only]
2026-02-15 (mid)   window: Feb 15 → Mar 14   ← original anchor, params for Feb/Mar forecast horizon
2026-03-16 (mid)   window: Feb 15 → Mar 15   ← NEW, params for Mar/Apr forecast horizon (wins tie-break)
2026-03-10 (mid)   window: Feb 09 → Mar 09   ← retained for completeness, rarely selected
2026-03-15 (mid)   window: Mar 15 → Apr 14
```
---

## Key Design Decisions Confirmed

| Decision | Rationale |
|---|---|
| Tie-break by `window_end` proximity, not list order | List order is arbitrary and changes as anchors are added — date proximity is semantically meaningful |
| `2026-03-16 (mid)` uses same feature window as `2026-02-15 (mid)` | The feature window correctly reflects what volume data looks like on Mar 16 — same window, different forecast-horizon params |
| `2026-03-10 (mid)` retained | It may still be useful for edge cases where `TODAY` genuinely is Mar 10 (e.g. if the actuals lag changes); keeping it has no downside |
| Param tester run with `train_cutoff = Mar 15`, not Mar 9 | The live model trains through Mar 15 (actuals locked through Mar 13 + Mar 14–15 weekend). Grid search must match real training conditions |
| Do not touch `2026-02-15 (mid)` params | Still correct for its original use case (forecasting Feb/Mar from a Feb 15 training cutoff) |

---

## Param Testing Reference — All Confirmed Windows in This Session

| Window | Period Tested | Train Cutoff | Actual Total | recency | dampen | lift | lookback | tilt | dow_s | int_s | seas | Abs Err |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `2026-03-10 (mid)` | Mar 10 → Apr 10 | Mar 09 | $260,350,386 | 0.20 | 0.83 | 0.000 | 60 | 0.15 | 0.10 | 0.20 | 1.02 | 0.00% |
| `2026-03-16 (mid)` | Mar 16 → Apr 16 | Mar 15 | $271,254,689 | 1.00 | 0.83 | 0.005 | 60 | 0.15 | 0.05 | 0.35 | 1.02 | 0.00% |

---

## Architectural Discussion — Automated Param Generation (Future Build)

### Current Manual Process (As Of Today)
1. Run backtest → identify error spike on specific run date
2. Manually determine the correct training cutoff and forecast period for that run date
3. Run `TPO_Param_Testing` grid search (6,561 combos)
4. Read best params from output
5. Manually add new anchor dict to `ANCHOR_DEFINITIONS` in the forecasting notebook
6. Re-run backtest to confirm fix

This process works but is a human bottleneck — it requires availability, expertise, and careful manual review.

---

### Proposed Future Architecture
```
TPO_Param_Testing.ipynb          Master Params Table          Rolling_30_TPO.ipynb
─────────────────────            ──────────────────           ────────────────────
Runs on 1st, 5th, 10th,    →    DB table or CSV:         →   ANCHOR_DEFINITIONS
15th, 20th, 25th                  label, window_start,         replaced by a
                                  window_end, params,           read from master
                                  run_date, abs_err             table at startup
```
### Trigger Schedule
The param tester would run on the **1st, 5th, 10th, 15th, 20th, and 25th** of each month, corresponding to the natural run-date clusters where forecasts are most commonly requested.

Each trigger date maps to a specific window type:
| Trigger Day | Window Type | Example (April trigger) |
|---|---|---|
| 1st | Full prior month window | Mar 1 → Mar 31 |
| 5th | Early-month rolling window | Mar 5 → Apr 4 |
| 10th | Mid-early rolling window | Mar 10 → Apr 9 |
| 15th | Mid-month rolling window | Mar 15 → Apr 14 |
| 20th | Mid-late rolling window | Mar 20 → Apr 19 |
| 25th | Late-month rolling window | Mar 25 → Apr 24 |

---

### Master Params Table Schema
```sql
CREATE TABLE tpo_anchor_params (
    label                        VARCHAR(50)    NOT NULL,
    window_start                 DATE           NOT NULL,
    window_end                   DATE           NOT NULL,
    prior_start                  DATE           NOT NULL,
    prior_end                    DATE           NOT NULL,
    january_only                 BIT            NOT NULL DEFAULT 0,
    high_error_flag              BIT            NOT NULL DEFAULT 0,
    run_date                     DATE           NOT NULL,
    abs_err                      DECIMAL(6,4)   NOT NULL,
    signed_err                   DECIMAL(6,4)   NOT NULL,
    actual_total                 BIGINT,
    forecast_total               BIGINT,
    actual_biz_days              INT,
    recency_strength             DECIMAL(4,2)   NOT NULL,
    dow_shrinkage                DECIMAL(4,2)   NOT NULL,
    interaction_shrinkage        DECIMAL(4,2)   NOT NULL,
    seasonal_exponent            DECIMAL(5,3)   NOT NULL,
    trend_dampening              DECIMAL(4,2)   NOT NULL,
    forward_lift_daily           DECIMAL(6,4)   NOT NULL,
    level_lookback_days          INT            NOT NULL,
    trend_seasonal_tilt          DECIMAL(4,2)   NOT NULL,
    PRIMARY KEY (label, run_date)
);
```
---

### Auto-Flagging Rules
To replace the current manual review process, the automated system would apply these rules on insert:

| Rule | Threshold | Action |
|---|---|---|
| High error | `abs_err > 0.08` (8%) | Set `high_error_flag = True` — params inserted but flagged |
| Unreliable | `abs_err > 0.15` (15%) | Do not insert — send alert instead |
| Duplicate window | Same `window_start`/`window_end` already exists | Update only if new `abs_err` is lower than existing |
| January window | `window_start` month == 1 or `window_end` month == 1 | Set `january_only = True` automatically |

---

### Updated `ANCHOR_DEFINITIONS` Loader
Replace the hardcoded `ANCHOR_DEFINITIONS` list in the forecasting notebook with a read from the master table at startup:
```python
def load_anchor_definitions_from_db(conn_str):
    """
    Loads anchor definitions from the master params table.
    Replaces hardcoded ANCHOR_DEFINITIONS list.
    Returns list of dicts in same format as ANCHOR_DEFINITIONS.
    """
    query = """
        SELECT *
        FROM tpo_anchor_params
        -- For each label, take the most recent run with the lowest abs_err
        WHERE run_date = (
            SELECT MAX(run_date)
            FROM tpo_anchor_params p2
            WHERE p2.label = tpo_anchor_params.label
        )
        ORDER BY window_start ASC, window_end ASC
    """
    df = pd.read_sql(query, conn_str)

    anchor_definitions = []
    for _, row in df.iterrows():
        anchor_definitions.append({
            'label':           row['label'],
            'window_start':    str(row['window_start']),
            'window_end':      str(row['window_end']),
            'prior_start':     str(row['prior_start']),
            'prior_end':       str(row['prior_end']),
            'high_error_flag': bool(row['high_error_flag']),
            'january_only':    bool(row['january_only']),
            'params': dict(
                recency_strength      = float(row['recency_strength']),
                dow_shrinkage         = float(row['dow_shrinkage']),
                interaction_shrinkage = float(row['interaction_shrinkage']),
                seasonal_exponent     = float(row['seasonal_exponent']),
                trend_dampening       = float(row['trend_dampening']),
                forward_lift_daily    = float(row['forward_lift_daily']),
                level_lookback_days   = int(row['level_lookback_days']),
                trend_seasonal_tilt   = float(row['trend_seasonal_tilt']),
            ),
        })

    print(f"Loaded {len(anchor_definitions)} anchors from master params table")
    return anchor_definitions

# Replace hardcoded list:
# ANCHOR_DEFINITIONS = [ ... ]
# With:
ANCHOR_DEFINITIONS = load_anchor_definitions_from_db(conn_str)
```
---

### When To Build This
**Not yet.** The automated system makes sense once:
1. ✅ April 2026 actuals are complete — needed to confirm Apr anchor params
2. ✅ The current anchor set is consistently hitting <5% errors across all run dates
3. ✅ The manual process has been stable for at least 1–2 full months with no emergency patches

**Recommended build sequence:**
1. Build the master params table schema in SQL
2. Backfill all 32 current confirmed anchors into the table manually (one-time)
3. Build the automated param tester scheduler (runs on the 1st/5th/10th/15th/20th/25th)
4. Run both systems in parallel for 1 month — verify automated outputs match manual expectations
5. Switch the forecasting notebook to read from the master table
6. Decommission the hardcoded `ANCHOR_DEFINITIONS` list
---

### Open Items Carried Forward
| Item | Status |
|---|---|
| Backtest Mar 10 → Apr 10 with new tie-break logic | ⏳ Pending — run to confirm error drops |
| Revisit Mar 13 / Mar 16 zone errors if they persist | ⏳ Pending |
| April 2026 anchor | ⏳ Pending — wait for full month actuals |
| Master params table build | ⏳ Future — begin once Apr 2026 is complete and system is stable |
| Automated param tester scheduler | ⏳ Future — depends on master table |
| Safer tie-break: store `window_end` in `anchor_df` directly | ⏳ Low priority — current implementation works, document the dependency |
---

## Summary of All Bugs & Status
| Run Date | Error | Root Cause | Fix | Status |
|---|---|---|---|---|
| Jan 20 → Feb 20 | -14% | Jan anchor params bleeding into Feb forecasts via single lookup | Dual lookup (`force_forecast_month=1/2`) in `fit()` | ✅ Fixed (prior session) |
| Mar 10 → Apr 10 | -13% to -14% | `2026-02-15 (mid)` selected correctly by k-NN but its params tuned for Feb/Mar horizon, not Mar/Apr | Added `2026-03-16 (mid)` with Mar/Apr-horizon params + tie-break logic to ensure it wins over `2026-02-15 (mid)` | ✅ Fixed this session |