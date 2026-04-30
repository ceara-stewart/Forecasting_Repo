# Rolling 30 RB — V8 Diagnosis & V9 Fixes Conversation (4/30)

## User
Shared `Rolling_30_RB_Version8.ipynb` along with a backtest comparison table of v7 vs v8 results across 24 run dates (Sep 2025 – Mar 2026).

## Assistant
Asked clarifying question on what direction to take. Flagged that the DISTANCE WARNING firing at ~17 on every run was suspicious and likely indicated train/serve skew or correlated features.

## User
"Diagnose v8's weak spots"

## Assistant — V8 Diagnosis (initial)

### Headline Numbers
| Metric | v7 | v8 |
|---|---|---|
| MAPE (mean abs %) | 13.5% | 11.7% |
| Max error | -44% (Jan 20) | +48% (Oct 30) |
| Bias (mean signed %) | -12% (chronic under) | +1% (centered) |
| Runs within ±10% | 13 / 24 | 17 / 24 |
| Runs >20% error | 7 / 24 | 5 / 24 |

v8 is better on average and fixes the January collapse, but has new failure modes.

### Weak Spot #1 — October Blowout
| Run Date | Actual | v7 Err | v8 Err | v8 Anchor |
|---|---|---|---|---|
| 10/10/25 | $77.1M | -16% | +6% | 2025-10-15 Mid |
| 10/20/25 | $81.4M | -1% | +19% | 2025-10-15 Mid |
| 10/30/25 | $67.2M | +4% | +48% | 2025-10-1 Full |

Root cause: v8 picked peak-period anchors when volume was spiking, then volume mean-reverted but model kept extrapolating peak.

### Weak Spot #2 — DISTANCE WARNING fires every run
Distances of 17 with 25 z-scored features mean live vector is ~3.4 std-devs from every anchor on every dimension. Likely culprits:
- Train/serve skew on pipeline data (anchors built from matured data, live from immature)
- _1m and _2m windows highly correlated, doubling weight of base metrics

### Weak Spot #3 — Anchor pool concentration
Only ~7 of 30 anchors ever selected. Top-5 ranked anchors within 0.5 distance units at base of 17.4 — noise-level separation.

### Weak Spot #4 — Holiday distortion fully disabled
`holiday_shrinkage=1.00` disables learned factors. Contributes to Nov/Dec over-forecasting.

### Weak Spot #5 — January anchor applied to Dec-heavy windows
12/10, 12/20 runs over by +24%, +26% using `2025-01-15 Mid` anchor.

## User
Shared `Rolling_30_RB_Version7.ipynb` so assistant could see exactly what changed.

## Assistant — Revised V8 Diagnosis (grounded in actual diff)

### What Actually Changed in v8
| Component | v7 | v8 |
|---|---|---|
| Feature count | 13 (single 2-mo window) | 25 (1m + 2m windows) |
| Anchor feature window | prior_start → prior_end | run_date - 30d/60d |
| Live feature window | today - 2mo → today - 1d | 1m + 2m windows |
| Distance warning | Already firing at 16.65 | Firing at 17.37 |
| Forecaster class | StructuralLoanForecaster | Identical |
| Anchor data source | SQL FDM_Anchor_Params | Identical |

**Key correction:** DISTANCE WARNING is NOT new in v8 — pre-existing in both versions. Train/serve skew is a pre-existing issue.

### What v8 Actually Fixed
Big January wins:
- Jan 1: -32% → -10% (+22pp)
- Jan 20: -44% → -4% (+40pp)
- Jan 30: -35% → -9% (+26pp)
- Feb 1: -36% → -9% (+27pp)

### What v8 Actually Broke

**Oct 20–30 over-forecasting (NEW):**
- v7's single 2-mo window averaged Oct peak with calmer Sep data → smoother anchor
- v8's 1m window puts heavy weight on most recent 30 days → momentum amplifier when you need a mean-reversion damper

**Dec 10/20 over-forecasting (NEW):**
- v7 picked `11/15 Mid` (Dec-aware seasonality)
- v8 picked `2025-01-15 Mid` because 1m/2m feature design conflates "December slowdown" with "January slowdown"

**Anchor pool concentration:** Only 7 unique anchors ever selected; `2025-01-15 Mid` picked 5 times for non-Jan months.

**Holiday distortion disabled (same in both):** Both have `holiday_shrinkage=1.00` — not a v8 regression but real source of error.

### Recommended V9 Fixes (Prioritized)
1. Drop duplicated base-metric levels — keep `_2m` levels only, keep both `_1m` and `_2m` pct_chgs (19 features instead of 25)
2. Add turning-point dampener — if `pct_chg_1m` and `pct_chg_2m` have opposite signs, down-weight `_1m` features
3. Re-enable holiday distortion with hard clamp `[0.75, 1.25]` and `holiday_shrinkage=0.70`
4. Investigate train/serve skew driving distances to 16+ in both versions

## User
"Can you take the V8 code and begin fixes 1, 2 and 3 by editing the cell blocks that need editing"

## Assistant — V9 Code (Fixes 1, 2, 3)

### Fix #1 — Anchor Table Cell

Dropped 6 redundant `_1m` LEVEL features. Kept `_2m` levels (regime baseline) and BOTH `_1m` + `_2m` pct_chg features (momentum + trajectory). Feature count: 25 → 19.

```python
_LEVEL_METRICS = [
    'apps_count_per_biz_day',
    'uw_count_per_biz_day',
    'appr_count_per_biz_day',
    'apps_vol_per_biz_day',
    'uw_vol_per_biz_day',
    'appr_vol_per_biz_day',
]

_PCT_CHG_METRICS = [
    'apps_count_pct_chg',
    'uw_count_pct_chg',
    'appr_count_pct_chg',
    'apps_vol_pct_chg',
    'uw_vol_pct_chg',
    'appr_vol_pct_chg',
]

_BASE_METRICS = _LEVEL_METRICS + _PCT_CHG_METRICS

FEATURE_COLS = (
    [f'{m}_2m' for m in _LEVEL_METRICS]   +   # 6 — regime baseline (2m only)
    [f'{m}_1m' for m in _PCT_CHG_METRICS] +   # 6 — short-term momentum
    [f'{m}_2m' for m in _PCT_CHG_METRICS] +   # 6 — medium-term trajectory
    ['biz_day_count_forecast']                # 1 — calendar
)
```

`compute_volume_features`, `compute_windowed_features`, `compute_two_window_profile`, and `build_anchor_table` remain structurally identical — they just produce 19 columns now via the trimmed `FEATURE_COLS`.

### Fix #2 — RollingParamLookup Cell

Added per-feature weight vector. When `sign(pct_chg_1m) != sign(pct_chg_2m)` for a metric (regime reversing), the corresponding `_1m` pct_chg dimension is down-weighted to 0.30, so distance metric trusts longer-window trajectory instead of momentum-chasing.

```python
class RollingParamLookup:

    STALENESS_PENALTY_PER_YEAR = 0.40
    STALENESS_PENALTY_CAP      = 0.80
    DISTANCE_WARN_THRESHOLD    = 3.50

    # NEW (fix #2)
    TURNING_POINT_WEIGHT       = 0.30
    NORMAL_WEIGHT              = 1.00

    def __init__(self, anchor_df, norm_stats):
        self.anchor_df   = anchor_df.copy()
        self.norm_stats  = norm_stats
        self._param_cols = [c for c in self.anchor_df.columns if c.startswith('param_')]
        self._pct_chg_1m_index = {
            m: FEATURE_COLS.index(f'{m}_1m') for m in _PCT_CHG_METRICS
        }

    def _build_feature_weights(self, features):
        """Down-weight _1m pct_chg dims when regime is reversing vs the _2m view."""
        weights = np.full(len(FEATURE_COLS), self.NORMAL_WEIGHT)
        reversed_metrics = []

        for m in _PCT_CHG_METRICS:
            v1 = features.get(f'{m}_1m', 0.0)
            v2 = features.get(f'{m}_2m', 0.0)
            if abs(v1) > 0.02 and abs(v2) > 0.02 and (v1 * v2 < 0):
                weights[self._pct_chg_1m_index[m]] = self.TURNING_POINT_WEIGHT
                reversed_metrics.append(m)

        return weights, reversed_metrics

    # In lookup(): after computing diffs
    weights, reversed_metrics = self._build_feature_weights(features)
    feature_distances = np.sqrt(((diffs ** 2) * weights).sum(axis=1))
```

Diagnostic line `TURNING-POINT detected` fires when regime reversal is detected.

### Fix #3 — StructuralLoanForecaster Cell

`holiday_shrinkage=1.00 → 0.70` (re-enables learned factors at 30% strength) AND hard clamp `[0.75, 1.25]` on every learned factor.

```python
class StructuralLoanForecaster:

    # NEW (fix #3) — hard clamp on learned holiday distortion factors
    HOLIDAY_FACTOR_MIN = 0.75
    HOLIDAY_FACTOR_MAX = 1.25

    def __init__(self,
                 ...
                 holiday_shrinkage=0.70):       # FIX #3: was 1.00 (disabled) → 0.70
        ...

    # In fit(), distortion aggregation block:
    for key, ratios in ratio_accumulator.items():
        if len(ratios) < 2:
            continue
        median_ratio = float(np.median(ratios))
        shrunk = (
            (1 - self.holiday_shrinkage) * median_ratio +
            self.holiday_shrinkage * 1.0
        )
        # FIX #3: hard clamp to prevent extreme factors
        shrunk = max(self.HOLIDAY_FACTOR_MIN,
                     min(self.HOLIDAY_FACTOR_MAX, shrunk))
        self.distortion_table_[key] = shrunk
```

### Sanity Checklist
1. Replace cells in order: anchor table → RollingParamLookup → StructuralLoanForecaster
2. MAIN EXECUTION cell, eval cell, and 30-day SQL cell don't need changes
3. Watch for new diagnostic line `TURNING-POINT detected` — should fire on Oct 30 backtest
4. DISTANCE WARNING (threshold 3.50) will likely still trip — that's the train/serve skew issue (separate fix #4)

## Outstanding Items
- Fix #4: investigate train/serve skew on pipeline data (likely cause: late-arriving applications/UW events present for historical anchor windows but not yet present for live 1–2 month lookback)
- Run new backtest with fixes 1, 2, 3 applied to validate Oct/Dec error reduction
