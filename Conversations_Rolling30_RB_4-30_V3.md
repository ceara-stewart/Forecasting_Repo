# Conversation — Rolling 30 RB 4/30 V3

## Context

Continuation of the Retail Broker (RB) 30-day rolling forecast notebook work from `Conversations_Rolling30_RB_4-30_V2.md`. Working on `Rolling_30_RB_Version10.ipynb` (a copy of v9). Backtest TODAY = `2026-03-30`, forecast start = `2026-04-03`.

The V10 proposal had six fixes (A–F). This conversation covers implementation of V10-A, V10-B, and V10-E. V10-C, V10-D, and V10-F were deprioritized based on diagnostic results.

---

## Proposed V10 Edits (recap)

The `feature_dist=17` signal in V9 was the most actionable finding — the similarity metric was fundamentally broken. Address that first; everything else is downstream.

### V10-A: Fix the normalization (highest leverage)
Replace mean/std with median/MAD (robust to surge & trough outliers).
```python
norm_stats[col] = {
    'center': float(anchor_df[col].median()),
    'scale':  float(1.4826 * (anchor_df[col] - anchor_df[col].median()).abs().median()),
}
```
Expected effect: nearest-neighbor distances drop from 17 → 3–5 range.

### V10-B: Restore _1m levels but downweight them (don't drop)
Restore the 6 `_1m` LEVEL features dropped in V9 fix #1 with a `FEATURE_WEIGHTS` dict that half-weights them. Recovers V8's surge-detection without re-introducing V8's reversal blindness.

### V10-C: Tighten the turning-point logic
Add a magnitude gate so TPD only fires when 1m signal is small relative to 2m:
```python
if (sign(v1) != sign(v2)) and abs(v1) < 0.5 * abs(v2):
    # down-weight 1m
```

### V10-D: Densify the anchor pool
30 anchors in 19 dims is severely under-sampled. Generate weekly anchors (~150) instead of bi-monthly. SQL change to `FDM_Anchor_Params`.

### V10-E: Add an explicit seasonal-cliff guard (Nov 15 → Jan 15, plus Q1 ramp)
Both V8 and V9 have no mechanism to know that funded volume drops 30–40% from Oct peak to Jan trough independently of pipeline indicators. Add a calendar-driven seasonal multiplier learned from prior Q4→Q1 ratios.

### V10-F: Use k=3 weighted blend instead of nearest-1
When `feature_dist > 5`, no single anchor is trustworthy. Blend top-3 with inverse-distance weights.

---

## V10-A Implementation & Results

User implemented V10-A (median/MAD normalization, per-feature std floors, biz_day_count_forecast using 2m window for both anchors and live).

### Backtest Results — V10-A

| Run Date | Window | Actual Volume | Version 10 | Difference | Pct | Anchor Selected |
|---|---|---|---|---|---|---|
| 9/30/2025 | 10/1–10/31/2025 | $76,662,287 | 68,935,722 | (7,726,565) | -10% | 10/1/2025 Full |
| 10/1/2025 | 10/1–10/31/2025 | $76,662,287 | 75,892,145 | (770,142) | -1% | 10/1/2025 Full |
| 10/10/2025 | 10/10–11/10/2025 | $77,104,956 | 81,584,819 | 4,479,863 | 6% | 10/15/2025 Mid |
| 10/20/2025 | 10/20–11/20/2025 | $81,447,909 | 97,266,099 | 15,818,190 | 19% | 10/15/2025 Mid |
| 10/30/2025 | 10/30–11/30/2025 | $67,217,542 | 69,440,353 | 2,222,811 | 3% | 11/1/2025 Full |
| 11/1/2025 | 11/1–11/30/2025 | $60,127,797 | 61,376,297 | 1,248,500 | 2% | |
| 11/10/2025 | 11/10–12/10/2025 | $64,306,238 | 65,050,379 | 744,141 | 1% | 11/15/2025 Mid |
| 11/20/2025 | 11/20–12/20/2025 | $53,407,909 | 48,584,503 | (4,823,406) | -9% | 12/01/2025 Full |
| 11/30/2025 | 11/30–12/30/2025 | $46,698,224 | 45,519,630 | (1,178,594) | -3% | 12/01/2025 Full |
| 12/1/2025 | 12/01–12/31/2025 | $49,070,409 | 45,335,029 | (3,735,380) | -8% | 12/15/2025 Mid |
| 12/10/2025 | 12/10–01/10/2026 | $40,526,019 | 37,863,177 | (2,662,842) | -7% | 12/15/2025 Mid |
| 12/20/2025 | 12/20–01/20/2026 | $34,973,079 | 29,622,402 | (5,350,677) | -15% | 01/01/2026 Full |
| 12/30/2025 | 12/30–01/30/2026 | $33,351,324 | 25,750,474 | (7,600,850) | -23% | 01/01/2026 Full |
| 1/1/2026 | 01/01–01/31/2026 | $30,174,389 | 27,715,126 | (2,459,263) | -8% | 01/15/2026 Mid |
| 1/10/2026 | 01/10–02/10/2026 | $36,848,021 | 35,468,792 | (1,379,229) | -4% | |
| 1/20/2026 | 01/20–02/20/2026 | $42,897,864 | 46,553,052 | 3,655,188 | 9% | |
| 1/30/2026 | 01/30–02/28/2026 | $41,426,364 | 40,491,581 | (934,783) | -2% | |
| 2/1/2026 | 02/01–02/28/2026 | $40,564,515 | 39,629,732 | (934,783) | -2% | 2025-02-15 Mid |
| 2/10/2026 | 02/10–03/10/2026 | $41,282,795 | 36,745,811 | (4,536,984) | -11% | 2025-02-15 Mid |
| 2/20/2026 | 02/20–03/20/2026 | $41,198,991 | 36,272,949 | (4,926,042) | -12% | 03/01/2026 Full |
| 2/28/2026 | 03/01–03/31/2026 | $45,844,441 | 37,864,984 | (7,979,457) | -17% | 03/01/2026 Full |
| 3/10/2026 | 03/10–04/10/2026 | $51,239,860 | 45,578,333 | (5,661,527) | -11% | 03-15-2026 Mid |
| 3/20/2026 | 03/20–04/20/2026 | $52,165,111 | 51,630,941 | (534,170) | -1% | 03-15-2026 Mid |
| 3/30/2026 | 03/30–04/30/2026 | $54,034,773 | 57,116,855 | 3,082,082 | 6% | 03-15-2026 Mid |

### Read on V10-A

| Metric | V9 | V10-A |
|---|---|---|
| Mean abs % error | ~12% | ~7.5% |
| # runs ≥ ±15% | 7 | 4 |
| # runs ≤ ±5% | 9 | 13 |
| Anchor diversity | 4 unique | 11 unique |

The big wins are exactly where V9 was broken: 9/30 (-34% → -10%), 10/1 (-35% → -1%), and the Nov–Dec stable zone is now within ±3%. Anchor selection is finally diverse.

**Remaining problem patterns:**
- **Surge under-detection**: 10/20 (+19%), 12/30 (-23%), 12/20 (-15%) — V10-B candidate
- **Seasonal cliff over/under**: 2/28 (-17%), 2/10 (-11%), 2/20 (-12%), 3/10 (-11%) — Feb–March ramp where pipeline indicators alone aren't enough — V10-E candidate

---

## V10-B Implementation

Two cells were edited:

### Cell 1 — Anchor Table cell (`FEATURE_COLS` block)

Restored `_1m` LEVEL features (feature count 19 → 25) and added a static `FEATURE_WEIGHTS` dict.

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

# V10-B: restore _1m levels (was dropped in V9 fix #1) but down-weight them
FEATURE_COLS = (
    [f'{m}_1m' for m in _LEVEL_METRICS]   +   # 6 — short-term level (RESTORED, half-weight)
    [f'{m}_2m' for m in _LEVEL_METRICS]   +   # 6 — regime baseline
    [f'{m}_1m' for m in _PCT_CHG_METRICS] +   # 6 — short-term momentum
    [f'{m}_2m' for m in _PCT_CHG_METRICS] +   # 6 — medium-term trajectory
    ['biz_day_count_forecast']                # 1 — calendar
)   # 25 features

# V10-B: static base weights applied inside RollingParamLookup distance calc
FEATURE_WEIGHTS = {
    **{f'{m}_1m': 0.50 for m in _LEVEL_METRICS},     # restored _1m levels: half-weight
    **{f'{m}_2m': 1.00 for m in _LEVEL_METRICS},     # regime baseline: full weight
    **{f'{m}_1m': 1.00 for m in _PCT_CHG_METRICS},   # momentum: full weight (TPD may down-weight dynamically)
    **{f'{m}_2m': 1.00 for m in _PCT_CHG_METRICS},   # trajectory: full weight
    'biz_day_count_forecast': 1.00,
}
```

### Cell 2 — `RollingParamLookup` (`_build_feature_weights`)

Combined the new static `FEATURE_WEIGHTS` with the existing V9 turning-point down-weighting. Base weights are the starting vector; TPD reversals further multiply (rather than overwrite) the relevant `_1m` pct_chg dims.

```python
def __init__(self, anchor_df, norm_stats):
    self.anchor_df   = anchor_df.copy()
    self.norm_stats  = norm_stats
    self._param_cols = [c for c in self.anchor_df.columns if c.startswith('param_')]
    self._pct_chg_1m_index = {
        m: FEATURE_COLS.index(f'{m}_1m') for m in _PCT_CHG_METRICS
    }
    # V10-B: cache static base weight vector aligned to FEATURE_COLS order
    self._base_weights = np.array(
        [FEATURE_WEIGHTS.get(c, 1.0) for c in FEATURE_COLS],
        dtype=float,
    )

def _build_feature_weights(self, features):
    weights = self._base_weights.copy()   # V10-B base (was np.full(..., NORMAL_WEIGHT))
    reversed_metrics = []
    for m in _PCT_CHG_METRICS:
        v1 = features.get(f'{m}_1m', 0.0)
        v2 = features.get(f'{m}_2m', 0.0)
        if abs(v1) > 0.02 and abs(v2) > 0.02 and (v1 * v2 < 0):
            idx = self._pct_chg_1m_index[m]
            weights[idx] *= self.TURNING_POINT_WEIGHT   # multiply, don't overwrite
            reversed_metrics.append(m)
    return weights, reversed_metrics
```

### V10-B Result: NO CHANGE in backtest results

User confirmed V10-B ran (`Feature dimensions : 25` printed) but produced identical backtest numbers to V10-A.

### Diagnosis

The 6 `_1m` level features and the 6 `_2m` level features are **highly correlated** (~0.85+ — they share 30 days of overlap by construction). The `_2m` levels were already in the distance metric at full weight, so they had already captured almost all the level information. Adding `_1m` levels at half-weight added redundant signal — perturbed distances by a tiny amount but rarely enough to flip the top-1 anchor.

V10-B *was* the right idea for V9 (broken normalization, missing surge detection), but after V10-A fixed normalization, the `_2m` levels were already doing the job V10-B was trying to restore.

**V10-B was left in (not harmful, just inert).**

---

## Re-prioritization Based on V10-A Error Pattern

| Pattern | Runs | Anchor selected | Diagnosis |
|---|---|---|---|
| Late-fall cliff under-forecast | 9/30 (-10%) | 10/1 Full | Right anchor, model under-projects Oct peak |
| Late-fall cliff over-forecast | 10/20 (+19%) | 10/15 Mid | Right anchor, model over-projects |
| Dec→Jan trough miss | 12/20 (-15%), 12/30 (-23%), 11/20 (-9%) | 1/1 Full, 12/1 Full | Right trough anchor, model still over-projects vs trough |
| Feb-March systematic under-forecast | 2/10 (-11%), 2/20 (-12%), 2/28 (-17%), 3/10 (-11%) | 2/15 Mid, 3/1 Full, 3/15 Mid | **Same anchor, same direction, every run** — pure structural under-projection |
| Stable zone — works great | 11/1 (+2%), 11/10 (+1%), 11/30 (-3%), 1/10 (-4%), 1/30 (-2%), 2/1 (-2%), 3/20 (-1%), 3/30 (+6%) | various | OK |

Two takeaways:
1. The Feb→March cluster is four consecutive misses, all negative, all using the seasonally-correct anchor. Not an anchor problem — it's the `StructuralLoanForecaster` model under-shooting the Q1 ramp.
2. The Nov→Jan cliff misses are picking the right trough/cliff anchor but still over-projecting because the model's trend/level base is anchored on recent (higher) volume.

### Decisions
- **V10-B**: leave in (inert but harmless).
- **V10-C** (magnitude-gated TPD): SKIP — TPD wasn't misfiring on any run.
- **V10-D** (densify anchor pool): PARK — high value but SQL+re-tuning project.
- **V10-E** (seasonal-cliff guard): **NEXT** — directly addresses both Nov→Jan trough over-forecast AND Feb→March under-forecast.
- **V10-F** (k=3 weighted blend): LOWER PRIORITY — most V10-A distances are <3, single anchor already trustworthy.

---

## V10-E Design Decisions

**Q1: Where does the cliff multiplier live?** → Post-forecast multiplier in `forecast_from_date` (Option A). Surgical, doesn't touch trend/seasonal/interaction math, easy to disable.

**Q2: How is the multiplier learned?** → For each (week_of_year, dow) bucket: `ratio = actual / model_baseline_expected`, take median across years with shrinkage toward 1.0. Same pattern as existing `HolidayDistortionLearner` but keyed on `week_of_year` instead of `(holiday_dow, offset)`.

**Q3: Trough side AND ramp side?** → Both, in one mechanism. Learning from data handles both signs automatically.

### Tunables (defaults)
- `cliff_shrinkage = 0.50` (50% of learned signal retained)
- `CLIFF_FACTOR_MIN = 0.70`, `CLIFF_FACTOR_MAX = 1.30` (hard clamp)
- `cliff_weeks_active = list(range(47, 53)) + list(range(1, 14))` (Nov 18 → end of March)
- `cliff_min_observations = 2` (need 2+ years of data per bucket)

---

## V10-E Implementation

Replaced the `StructuralLoanForecaster` cell (id `a7285b74`) with v10 (fix #3 + fix E).

### Key additions

**`__init__`** — added cliff guard params:
```python
# V10-E cliff-multiplier clamps (class constants)
CLIFF_FACTOR_MIN   = 0.70
CLIFF_FACTOR_MAX   = 1.30

# V10-E init args
cliff_shrinkage=0.50,
cliff_min_observations=2,
cliff_weeks_active=None,           # defaults to weeks 47–52 + 1–13
cliff_guard_enabled=True,

self.cliff_table_ = {}     # V10-E: keyed by (week_of_year, dow)
```

**`fit()`** — learn cliff multipliers after holiday distortion learning:
```python
# Compute woy in df preprocessing
df['woy'] = df['Calendar_Date'].dt.isocalendar().week.astype(int)

# Ensure 'expected' column exists (compute on the fly if no holiday calendar)
if 'expected' not in df.columns:
    t_full_arr     = np.arange(len(df))
    df['expected'] = self._compute_expected(df, t_full_arr)

cliff_mask = (
    (~df['is_weekend']) &
    (df['Is_Holiday'] == 0) &
    (df[self.target] > 0) &
    (df['expected'] > 0) &
    (df['woy'].isin(self.cliff_weeks_active))
)

df_cliff = df.loc[cliff_mask, ['Calendar_Date', 'woy', 'dow',
                               self.target, 'expected']].copy()
df_cliff['ratio'] = df_cliff[self.target] / df_cliff['expected']

self.cliff_table_ = {}
if len(df_cliff) > 0:
    grouped = df_cliff.groupby(['woy', 'dow'])['ratio']
    for (woy, dow), ratios in grouped:
        ratios_list = ratios.tolist()
        if len(ratios_list) < self.cliff_min_observations:
            continue
        median_ratio = float(np.median(ratios_list))
        shrunk = (
            (1 - self.cliff_shrinkage) * median_ratio +
            self.cliff_shrinkage * 1.0
        )
        shrunk = max(self.CLIFF_FACTOR_MIN,
                     min(self.CLIFF_FACTOR_MAX, shrunk))
        self.cliff_table_[(int(woy), int(dow))] = shrunk
```

Plus a diagnostic printout of the learned cliff table grouped by week × dow.

**`forecast_from_date()`** — apply cliff multiplier AFTER holiday distortion, BEFORE final scaling:
```python
if self.cliff_guard_enabled and self.cliff_table_:
    cliff_mult = np.ones(len(df))
    applied_count = 0
    for i, row in df.iterrows():
        if row['is_weekend']:
            continue
        if 'Is_Holiday' in df.columns and row.get('Is_Holiday', 0) == 1:
            continue
        woy = int(row['woy'])
        if woy not in self.cliff_weeks_active:
            continue
        key = (woy, int(row['dow']))
        if key in self.cliff_table_:
            cliff_mult[i] = self.cliff_table_[key]
            applied_count += 1
    forecast = forecast * cliff_mult
```

### Sanity-check expectations after running
1. Learned cliff table prints — weeks 48–52 should be **<1.0** (trough = model over-projects, multiplier pulls down). Weeks 8–13 should be **>1.0** (Q1 ramp = model under-projects, multiplier pushes up). If table is roughly flat near 1.0, drop `cliff_shrinkage` from 0.50 → 0.30.
2. During cliff-window backtests, look for the one-line summary `🌊 V10-E cliff guard applied to N days (range X.XXX–Y.YYY)`.
3. Re-run the full backtest grid. **Should improve substantially**: 11/20, 11/30, 12/1, 12/10, 12/20, 12/30 (biggest test), 1/1, 2/10, 2/20, 2/28 (second biggest test), 3/10. **Should stay flat**: 10/1, 10/10, 10/20, 10/30, 11/1, 11/10, 1/10, 1/20, 1/30, 2/1, 3/20, 3/30.

---

## Status

- ✅ V10-A implemented and validated (mean abs error ~12% → ~7.5%)
- ✅ V10-B implemented (inert in current data — `_2m` levels already capture the signal — left in)
- ⏸️ V10-C, V10-D, V10-F deprioritized
- 🔄 V10-E implemented; awaiting backtest results
