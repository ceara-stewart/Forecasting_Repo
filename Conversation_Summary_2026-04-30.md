# Conversation Summary — 2026-04-30
## Retail Broker Switch: TPO Jan/Feb Logic Port and Iteration

---

## 1. Initial Question — Port TPO Jan/Feb Logic to Retail Broker

**User:** can we implement what TPO is doing for Jan/Feb and apply it to Retail Broker?

**Findings:**
RB V7 already implemented the core TPO Jan/Feb pattern (per-month routing fix). One meaningful difference identified:

| | TPO V12 | RB V7 |
|---|---|---|
| January pool | All 29 anchors eligible (Jan included, not exclusive) | Hard-filtered to `january_only==True` only (just 2 anchors) |
| How k-NN decides | Picks closest of all 29 — Jan anchors get fair shot | Forced to pick one of 2 January anchors regardless of fit |

**Proposed change:** Replace the January lookup in `RetailBrokerSwitch.fit()` to mirror TPO (all anchors eligible, `force_forecast_month=1`).

---

## 2. First Backtest — Only 1/10/26 Run Improved

User reported only the 1/10/2026 run improved meaningfully. Other Jan-spanning runs (12/30, 1/1, 1/20) were essentially unchanged at −19%, −26%, −21%.

**Diagnosis:** The TPO-style fix changed which anchor could be picked, but did not change the lookback math that builds the base level. For runs made before or at the very start of January, the model is still extrapolating the December trough.

**Three options proposed:**
1. Override the base level for January forecasts (use prior-year January)
2. Force longer lookback + lower recency for Jan params
3. Add a YoY blend for January only

---

## 3. Key Insight — Link January to November Base

**User:** doesn't TPO link Jan to November base rather than December?

**Finding:** TPO doesn't explicitly do this, but the user's intuition was correct and represents a real improvement. December gets its own model (Model C) because it's structurally unique, but Model A for January was allowed to use that same depressed December data as its base level lookback — logically incoherent.

**Proposed fix:** Exclude December from the Jan base-level lookback by adding `exclude_december` parameter to `_build_model_A()`.

---

## 4. V9 Implementation — Drop-in Replacement

Created V9 of `RetailBrokerSwitch` with:
- New `exclude_december` parameter on `_build_model_A()`
- Jan Model A excludes December from training
- Trend still fit on (December-excluded) full series
- Non-Jan Model A and Model C unchanged
- January pool: TPO-style (all anchors eligible)

---

## 5. V9 Results — 1/20 Still Bad at −18%

User noted 1/20/2026 run was pulling Jan mid-month params and might need same fix.

**Diagnosis:** The 1/20 run forecasts:
- Jan 20–31 → Jan Model A (December excluded — V9 fix working)
- Feb 1–20 → Non-Jan Model A (this is what's hurting)

Same pathology one model and one month over.

---

## 6. V10 — Symmetric Exclusion (Dec + Jan)

Added `exclude_january` parameter. Non-Jan Model A now excludes BOTH December and January from training.

---

## 7. V10 Results — Overshot Badly

| Run | V9 | V10 | Verdict |
|---|---|---|---|
| 1/20 | −18% | +4% | ✓ Big win |
| 1/30 | −8% | +48% | ✗ Bad regression |
| 1/10 | (n/a) | +14% | ✗ Overshoot |

**Cause:** Excluding both Dec and Jan pushed `level_lookback_days` tail() back into November 2025 (the peak month). January data was actually a useful recent trend signal.

---

## 8. V11 — Keep Dec Exclusion, Drop Jan Exclusion

Rolled back January exclusion. Non-Jan Model A excludes only December. January is a real trough-recovery signal that informs early Feb base level.

---

## 9. Adaptive Approach Suggested

**User:** can we just edit the logic so that if the forecast has more Jan dates use the other method but if it has more Feb dates use this current method?

---

## 10. V12 — Adaptive Based on Jan vs Feb Biz Days

Added `_count_biz_days_by_month()` helper. Decision made once per `forecast_from_date()` call:
- If `n_jan > n_feb` → Jan-dominant → exclude Dec + Jan (V10 behavior)
- Else → Feb-dominant → exclude only Dec (V11 behavior)

---

## 11. V12 Results — Solid Improvement

| Run | V9 | V10 | V11 | V12 | Trend |
|---|---|---|---|---|---|
| 1/10 | — | +14% | (~+5% est) | +8% | ✓ Better than V10 |
| 1/20 | −18% | +4% | (~−5% est) | −10% | ⚠ Worse than V11 expected |
| 1/30 | −8% | +48% | (~−5% est) | +8% | ✓ Much better than V10 |
| 2/1 → 2/28 | −7% to −17% | unchanged | unchanged | unchanged | flat |

**Remaining issue:** Every February-dated run consistently negative at −7% to −17%. Adaptive logic only kicks in when forecast window contains January biz days.

---

## 12. Discussion — TPO's Approach to Jan/Feb

**User asked:** doesn't the TPO file link Feb to November base? excluding Dec and Jan in some way?

**Finding:** TPO doesn't exclude Dec or Jan from training. TPO uses param swap (different anchor params for Jan vs non-Jan), not training data swap. RB drifted into training-data filtering because RB's anchor table selects similar params for Jan vs non-Jan pools.

**Two paths suggested:**
1. Short term: Keep filtering training data (V13 with `today_month==2` trigger)
2. Long term: Re-tune `FDM_Anchor_Params` for shorter `level_lookback_days` on Feb/Mar anchors

---

## 13. User Tested Strategic Fix — Failed

User: changing the level lookback days for those 2 months increases the error to 19% for Feb and 10% for march.

**Confirms:** Training-data filtering IS the right strategy for RB. Shorter lookback → tail pulls only the most recent N days, which IS the trough. The fix is to physically remove trough months and keep a long lookback so it reaches pre-trough peak.

---

## 14. V13 — Add `today_in_feb` Trigger

Excludes January from non-Jan Model A when EITHER:
- (a) Forecast window is Jan-dominant (V12 logic)
- (b) TODAY is in February (NEW — Jan trough in recent training tail)

---

## 15. V13 Results — Catastrophic Overshoot

| Run | V11 | V12 | V13 | Direction |
|---|---|---|---|---|
| 1/30 | +8% | +8% | +48% | catastrophic overshoot |
| 2/1 | −7% | −7% | +49% | flipped sign, 7x worse |
| 2/10 | −12% | −12% | +28% | flipped sign, 2x worse |

**Diagnosis:** Excluding Jan entirely doesn't position the tail at "recovering from trough" — it positions it at "pre-trough peak (Oct/Nov)", a regime Feb hasn't returned to yet.

---

## 16. Revert to V12 + Sketch Down-weighting Approach

Provided clean V12 revert. Sketched future improvement: instead of binary include/exclude, multiply Jan rows' regression weights by fractional factor `jan_weight ∈ [0, 1]` so they pull less hard on the trend slope and base level. Requires editing `StructuralLoanForecaster.fit()`.

---

## 17. New Issue Found — Dec Exclusion Bleeding to Mid-Year

**User:** RB-A-NoDec is bleeding into months before December actually happens. Causing higher errors.

**Bug:** V12 always passed `exclude_december=True`. For mid-year runs (Apr–Oct), December is not in the forecast window, not in `level_lookback_days` tail, not in near-future trend extrapolation. Excluding past Decembers throws away legitimate seasonal MOY data.

---

## 18. V12.1 — Adaptive December Exclusion

Added `_DEC_EXCLUSION_MONTHS = {11, 12, 1, 2}`. December exclusion is now conditional on `today.month`:
- Nov/Dec: December is upcoming or current
- Jan/Feb: recent December trough is in 90-day base-level tail
- Mar–Oct: December is too far away — keep prior Decembers

Both `model_jan_A` and `model_nonjan_A` receive dynamic `exclude_dec_from_models` flag. Label suffixes adaptive: `Full`, `NoDec`, `NoJan`, or `NoDecJan`.

---

## 19. Clarification — When Dec Exclusion Applies

**User asked:** the december exclusion only applies to Jan forecasting right?

**Answer:** No — applies to any Model A built when `today.month ∈ {11, 12, 1, 2}`, regardless of which downstream model is using the training set. This is correct because Dec contamination risk is tied to whether Dec is in the recent training tail or upcoming, not to which month is being forecasted.

---

## 20. V12.1 Made Things Worse — User Requested Original V8

User reverted to original V8 baseline:
- January pool HARD-FILTERED to `january_only==True`
- Non-January pool: Jan anchors excluded
- December pool: December anchors only (for Model C)
- Model A trains on FULL training series (no month exclusion)

V8 backtest results (starting point):
| Run | V8 |
|---|---|
| 12/30 | −19% |
| 1/1 | −26% |
| 1/10 | −18% |
| 1/20 | −25% |
| All Feb | −7% to −17% |
| Mar | −11%, −1% |
| Oct–Nov | mostly within ±5% (best regime) |

---

## Key Lessons

1. **Training-data filtering ≠ param swap.** TPO uses param swap (works for shallower seasonal patterns). RB needed training-data filtering due to deep Dec/Jan trough.
2. **Binary exclusion is brittle.** Excluding too much (V13) overshoots; excluding too little (V11) undershoots. Down-weighting may be the right middle ground.
3. **Conditional triggers must be precise.** V12.1's attempt to make Dec exclusion conditional on `today.month` introduced new errors when the trigger set wasn't quite right.
4. **Anchor selection matters as much as training data.** When the param lookup picks a trough-anchor for a recovery month, no amount of training-data manipulation fully fixes it.

---

## Final State

User reverted to V8 baseline. Future iterations should consider:
1. The down-weighting approach in `StructuralLoanForecaster.fit()` (jan_weight parameter)
2. Re-tuning `FDM_Anchor_Params` for RB-specific Feb/Mar anchors
3. Investigating why specific anchors (e.g., `2025-12-15 (mid)`) are being selected for recovery-month forecasts
