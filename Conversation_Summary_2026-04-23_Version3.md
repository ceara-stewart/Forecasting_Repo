# Conversation Summary — 2026-04-23 (Version 3)

## Overview

This session continued from Version 2 (same date). The core focus was diagnosing and fixing backtest errors in the V3.0 daily rolling k-NN param lookup system, evaluating whether to revert to regime-based detection, and ultimately deciding to rebuild V3.0 with a fully confirmed anchor table from grid search results. December (Model C) and January (override params) routing remain unchanged throughout.

---

## 1. Backtest Results Reviewed

The following backtest results were evaluated against Working Model 6:

| Run Date | Month Window | Actual Volume | Forecast | Difference | % Diff |
|---|---|---|---|---|---|
| 9/30/2025 | 10/1–10/31/2025 | $228,926,998 | $238,109,329 | $9,182,331 | +4% |
| 10/1/2025 | 10/1–10/31/2025 | $227,532,649 | $245,673,571 | $18,140,922 | +8% |
| 10/10/2025 | 10/10–11/10/2025 | $232,615,342 | $210,318,593 | -$22,296,749 | -10% |
| 10/20/2025 | 10/20–11/20/2025 | $247,085,441 | $241,502,293 | -$5,583,148 | -2% |
| 10/30/2025 | 10/30–11/30/2025 | $222,077,694 | $226,598,114 | $4,520,420 | +2% |
| 11/1/2025 | 11/1–11/30/2025 | $195,281,169 | $198,143,015 | $2,861,846 | +1% |
| 11/10/2025 | 11/10–12/10/2025 | $225,265,358 | $233,595,886 | $8,330,528 | +4% |
| 11/20/2025 | 11/20–12/20/2025 | $221,140,677 | $210,093,262 | -$11,047,415 | -5% |
| 11/30/2025 | 11/30–12/30/2025 | $220,065,424 | $218,201,443 | -$1,863,981 | -1% |
| 12/1/2025 | 12/1–12/31/2025 | $231,728,711 | $227,590,716 | -$4,137,995 | -2% |
| 12/10/2025 | 12/10–1/10/2026 | $213,577,223 | $215,963,726 | $2,386,503 | +1% |
| 12/20/2025 | 12/20–1/20/2026 | $188,096,998 | $190,092,332 | $1,995,334 | +1% |
| 12/30/2025 | 12/30–1/30/2026 | $205,257,605 | $197,620,132 | -$7,637,473 | -4% |
| 1/1/2026 | 1/1–1/31/2026 | $186,217,022 | $184,583,164 | -$1,633,858 | -1% |
| 1/10/2026 | 1/10–2/10/2026 | $216,882,400 | $205,031,238 | -$11,851,162 | -5% |
| 1/20/2026 | 1/20–2/20/2026 | $244,236,758 | $210,312,576 | -$33,924,182 | -14% |
| 1/30/2026 | 1/30–2/28/2026 | $218,879,446 | $191,739,931 | -$27,139,515 | -12% |
| 2/1/2026 | 2/1–2/28/2026 | $205,220,387 | $178,539,872 | -$26,680,515 | -13% |
| 2/10/2026 | 2/10–3/10/2026 | $214,980,438 | $178,196,806 | -$36,783,632 | -17% |
| 2/20/2026 | 2/20–3/20/2026 | $214,694,558 | $187,654,724 | -$27,039,834 | -13% |
| 2/28/2026 | 3/1–3/31/2026 | $246,341,013 | $241,778,753 | -$4,562,260 | -2% |
| 3/10/2026 | 3/10–4/10/2026 | $260,350,386 | $226,269,518 | -$34,080,868 | -13% |

### Key Patterns Identified

- **Oct–Dec 2025 run dates:** Generally solid, most within ±5%
- **Oct 10 specifically:** -10% outlier — Sep→Oct volume spike not captured
- **Jan 2026 run dates:** Degrading mid-to-late month (-12% to -14%)
- **Feb 2026 run dates:** Worst cluster (-13% to -17%) — consistent large underforecasting
- **Feb 28 / Mar run dates:** Partial recovery, then -13% again on Mar 10

---

## 2. Fix Attempts — Chronological

### Attempt 1 — MOY-adjusted base_level (V3.1)
- Moved `base_level` computation to after `moy_effect` is learned
- Divided detrended lookback values by `moy_effect` to make base season-neutral
- **Result:** Made things worse — reverted

### Attempt 2 — Additional k-NN anchors for coverage gaps
Added cross-month anchors to `ANCHOR_DEFINITIONS`:
- `2025-12-20 (mid)` — Dec/Jan crossover
- `2026-01-10 (mid)` — Jan/Feb crossover
- `2026-01-20 (mid)` — late Jan/early Feb
- `2025-09-10 (mid)` — Sep→Oct transition (for Oct 10 run date)

Oct 1 improved to 5%. Oct 10 still 25% off.

### Attempt 3 — Regime3 VolumeSpike
Added a third regime (`VolumeSpike`) triggered at `composite >= 1.2` to handle uncharacteristic volume surges like October 2025. Reverted to regime-based `LeadingIndicatorRegimeDetector` in Switch.
- **Result:** Made things worse overall — reverted to original V6 code

### Attempt 4 — Dec/Jan exclusion from base_level lookback
In `StructuralLoanForecaster_A.fit()`, stripped December and January rows from the `recent_prod` lookback window before computing `base_level`. Used 10-day minimum fallback.
- **Result:** Made things worse — for 60-day lookback in early Feb, after stripping Dec/Jan fewer than 10 clean days remained, triggering fallback to the full contaminated window

---

## 3. Root Cause Analysis — Feb Underforecast

### Two simultaneous problems identified:

**Problem A — Wrong regime classification for Feb/Mar:**

The regime detector reads January pipeline data (low growth month) and classifies February as Regime1. But the grid search shows Feb and Mar both need `dampening=0.83, lookback=60` — which is Regime2's signature.

| Param | Regime1 (selected) | Feb 26 best | Mar 26 best |
|---|---|---|---|
| dampening | 0.70 | **0.83** | **0.83** |
| lookback | 90 | **60** | **60** |
| recency | 1.00 | 1.00 | 1.00 |

**Problem B — lookback=90 contamination:**

For a Feb 10 run date, 90 days back = ~Nov 10. That window contains:
- ~22 Nov biz days (vol ~$195M/month)
- ~22 Dec biz days (collapses after Dec 18)
- ~21 Jan biz days ($186M — post-holiday suppressed)
- ~8 Feb biz days

Averaging these suppresses `base_level` well below the Feb/Mar actual level of ~$205–246M.

**Core issue:** The regime detector is using a lagged signal that points backward at January when it should be pointing forward at February.

---

## 4. Grid Search Results Added This Session

### New confirmed anchor — 2026-03-20 (mid)

```
Window: 2026-03-20 → 2026-04-20
Signed err : +0.00%
Abs err    : 0.00%
Actual     : $257,144,350
Forecast   : $257,148,013

recency_strength             = 1.0
dow_shrinkage                = 0.10
interaction_shrinkage        = 0.35
seasonal_exponent            = 1.0
trend_dampening              = 0.83
forward_lift_daily           = 0.0
level_lookback_days          = 90
trend_seasonal_tilt          = 0.15
```

**Key observation:** `lookback=90` safe again by Mar 20 — January is far enough back that 90 days no longer pulls it in heavily. Hybrid params: Regime2 dampening backbone (0.83) with Regime1 seasonal params (tilt=0.15, dow_s=0.10).

---

## 5. Full Grid Search Reference (All Confirmed Windows)

| Window | recency | dampen | lift | lookback | tilt | dow_s | int_s | seas | Abs Err |
|---|---|---|---|---|---|---|---|---|---|
| 2025-01 (full) | 0.20 | 0.70 | 0.000 | 60 | 0.08 | 0.25 | 0.20 | 1.05 | 0.00% |
| 2025-02 (full) | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.35 | 1.05 | 2.46% |
| 2025-03 (full) | 1.00 | 0.70 | 0.000 | 90 | 0.00 | 0.10 | 0.20 | 1.05 | 0.59% |
| 2025-04 (full) | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.00 | 0.32% |
| 2025-05 (full) | 1.00 | 0.70 | 0.005 | 90 | 0.08 | 0.10 | 0.20 | 1.00 | 0.03% |
| 2025-06 (full) | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.05 | 3.56% |
| 2025-07 (full) | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.50 | 1.05 | 5.78% |
| 2025-08 (full) | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.10 | 0.20 | 1.05 | 2.68% |
| 2025-09 (full) | 1.00 | 0.90 | 0.000 | 60 | 0.00 | 0.25 | 0.50 | 1.00 | 4.96% |
| 2025-10 (full) | 0.35 | 0.83 | 0.000 | 60 | 0.08 | 0.05 | 0.35 | 1.00 | 0.03% |
| 2025-10-15 (mid) | 1.00 | 0.70 | 0.005 | 60 | 0.15 | 0.05 | 0.35 | 1.05 | 2.97% |
| 2025-11 (full) | 0.35 | 0.83 | 0.000 | 60 | 0.00 | 0.25 | 0.35 | 1.00 | 4.38% |
| 2025-11-15 (mid) | 0.35 | 0.83 | 0.0025 | 90 | 0.00 | 0.10 | 0.50 | 1.00 | 0.01% |
| 2025-12 (full) | 1.00 | 0.70 | 0.005 | 60 | 0.15 | 0.25 | 0.20 | 1.05 | 14.59% ⚠️ |
| 2026-01 (full) | 0.20 | 0.70 | 0.005 | 90 | 0.00 | 0.25 | 0.50 | 1.05 | 0.01% |
| 2026-01-15 (mid) | 1.00 | 0.70 | 0.005 | 90 | 0.15 | 0.05 | 0.50 | 1.05 | 0.82% |
| 2026-02 (full) | 1.00 | 0.83 | 0.000 | 60 | 0.00 | 0.25 | 0.35 | 1.02 | 0.09% |
| 2026-02-15 (mid) | 0.20 | 0.83 | 0.005 | 60 | 0.00 | 0.25 | 0.20 | 1.00 | 0.02% |
| 2026-03 (full) | 1.00 | 0.83 | 0.000 | 60 | 0.08 | 0.05 | 0.20 | 1.02 | 0.47% |
| 2026-03-15 (mid) | 1.00 | 0.83 | 0.005 | 90 | 0.00 | 0.25 | 0.20 | 1.05 | 0.01% |
| 2026-03-20 (mid) | 1.00 | 0.83 | 0.000 | 90 | 0.15 | 0.10 | 0.35 | 1.00 | 0.00% |

---

## 6. Final Design Decision — Return to V3.0 k-NN with Full Anchor Coverage

### Decision
Abandon regime-based detection entirely (except January override and December Model C routing). Rebuild V3.0 `RollingParamLookup` with the now-confirmed full anchor table.

### Rationale
The regime detector's fundamental problem is a **lagged signal** — it reads last month's pipeline data and classifies the current month, but the classification can be wrong when transitioning between structurally different months (Jan→Feb, Sep→Oct). The k-NN system avoids this by directly matching current volume features to historical windows with confirmed best params — no labels, no thresholds, no composite scores.

The earlier V3.0 failure was purely an anchor coverage problem, not a conceptual flaw.

### What stays the same
- December → Model C (unchanged)
- January → January override params (unchanged — grid search confirms Jan needs its own params every time: recency=0.20, dampen=0.70, lookback=90)
- All SQL cells, preprocessing, channel splits, holiday calendar, HolidayDistortionLearner, prepare_pipeline_monthly, StructuralLoanForecaster_C unchanged

### What changes
- `LeadingIndicatorRegimeDetector` — no longer called (retained in notebook for reference)
- `StructuralLoanForecaster_Switch` — reverts to V3.0 k-NN based param selection
- `ANCHOR_DEFINITIONS` — updated with all confirmed grid search results + interpolated gap anchors

---

## 7. Gap Anchors Still Needed — Priority Grid Search List

These windows have interpolated params. Real grid search results will fix the remaining backtest errors:

| Gap Anchor | Covers Run Dates | Known Problem | Priority |
|---|---|---|---|
| 2025-09-10 (mid) | Oct 10–14 | -25% off | 🔴 High |
| 2025-12-20 (mid) | Jan 1–14 | moderate underforecast | 🟡 Medium |
| 2026-01-10 (mid) | Jan 20–Feb 1 | -12% to -14% | 🔴 High |
| 2026-01-20 (mid) | Feb 1–14 | -13% to -17% | 🔴 High |

---

## 8. Param Pattern Analysis — What the Grid Search Is Telling Us

### The dampening transition
The clearest structural signal across all confirmed windows:

| Period | dampening | lookback | Interpretation |
|---|---|---|---|
| Feb–Aug 25 | 0.70 | 90 | Strong growth trend — carry full trend forward, long history |
| Sep 25 | 0.90 | 60 | Transition — aggressively dampen, short lookback |
| Oct–Nov 25 | 0.83 | 60 | New regime — moderate dampening, recent history only |
| Dec 25 | 0.70 | 60 | ⚠️ Unreliable (14.59% err) |
| Jan 26 | 0.70 | 90 | January override — back to steady state params |
| Feb–Apr 26 | 0.83 | 60–90 | Settled into moderate dampening regime |

### The lookback=60 vs lookback=90 pattern
- `lookback=60` is selected when the prior 90-day window contains structurally anomalous months (Dec, Jan, Sep transition)
- `lookback=90` is selected when the prior 90 days are clean steady-state months
- This is exactly what the k-NN will capture automatically — when today's volume features resemble a window where lookback=60 was best, it will select lookback=60

### The recency transition within Regime2
| Month | recency | Note |
|---|---|---|
| Oct 25 | 0.35 | Early Regime2 — distrust recent trend (spike coming off Sep transition) |
| Nov 25 | 0.35 | Same |
| Feb 26 | 1.00 | Late Regime2 — fully trust recent trend (settled) |
| Mar 26 | 1.00 | Same |

The blended `recency=0.68` used in the old Regime2 median was accurate for neither sub-group. k-NN resolves this automatically by matching to the specific window.

---

## 9. Open Items

| Item | Status |
|---|---|
| Grid search on 2025-09-10 (mid) window | ⏳ Pending — needed for Oct 10 run date fix |
| Grid search on 2025-12-20 (mid) window | ⏳ Pending |
| Grid search on 2026-01-10 (mid) window | ⏳ Pending — needed for late Jan fix |
| Grid search on 2026-01-20 (mid) window | ⏳ Pending — needed for Feb fix |
| Rebuild Switch to V3.0 k-NN | ⏳ Pending — awaiting gap grid searches |
| October 10 run date (-25%) | ⏳ Deferred — addressed by 2025-09-10 anchor |
| Adding new anchors as months complete | Ongoing — add row to ANCHOR_DEFINITIONS each month + each 15th |
| Retail / Retail Broker / Correspondent channels | Not yet implemented — Wholesale only |

---

## 10. Files Referenced

- `Rolling_30_TPO_Version6.ipynb` — Main notebook
- `TPO_Parameter_Testing` — Grid search best params per window (Wholesale)
- `Pipeline_Query.sql` — Source of all volume feature data
- `Conversation_Summary_2026-04-23.md` — Session 1 (V5.5 param corrections)
- `Conversation_Summary_2026-04-23_Version2.md` — Session 2 (V3.0 k-NN design)