# Conversation — Rolling 30 RB 4/30 V2

## Context

Working on Retail Broker (RB) 30-day rolling forecast notebooks. Three notebook versions were shared:

- `Rolling_30_RB_Version8.ipynb`
- `Rolling_30_RB_Version9.ipynb`
- `Rolling_30_RB_Version10.ipynb` (copy of v9, target for edits)

TODAY in backtest = `2026-03-30`, forecast start = `2026-04-03`.

## Backtest Comparison Table (V8 vs V9)

| Run Date | Window | Actual Volume | V8 Forecast | V8 Diff | V8 % | V8 Anchor | V9 Forecast | V9 Diff | V9 % | V9 Anchor |
|---|---|---|---|---|---|---|---|---|---|---|
| 9/30/2025 | 10/1–10/31/2025 | $76,662,287 | 67,742,886 | (8,919,401) | -12% | 2025-10-1 Full | 50,636,702 | (26,025,585) | -34% | 7/15/2025 Mid |
| 10/1/2025 | 10/1–10/31/2025 | $76,662,287 | 68,631,925 | (8,030,362) | -10% | 2025-10-15 Mid | 49,639,086 | (27,023,201) | -35% | 7/15/2025 Mid |
| 10/10/2025 | 10/10–11/10/2025 | $77,104,956 | 81,584,819 | 4,479,863 | 6% | 2025-10-15 Mid | 81,584,819 | 4,479,863 | 6% | 2025-10-15 Mid |
| 10/20/2025 | 10/20–11/20/2025 | $81,447,909 | 97,266,099 | 15,818,190 | 19% | 2025-10-15 Mid | 97,266,099 | 15,818,190 | 19% | 2025-10-15 Mid |
| 10/30/2025 | 10/30–11/30/2025 | $67,217,542 | 99,281,071 | 32,063,529 | 48% | 2025-10-1 Full | 65,699,381 | (1,518,161) | -2% | 2025-07-15 Mid |
| 11/1/2025 | 11/1–11/30/2025 | $60,127,797 | 58,540,763 | (1,587,034) | -3% | 2025-07-15 Mid | 58,609,636 | (1,518,161) | -3% | 2025-07-15 Mid |
| 11/10/2025 | 11/10–12/10/2025 | $64,306,238 | 64,695,752 | 389,514 | 1% | 2025-07-15 Mid | 64,497,372 | 191,134 | 0% | 2025-07-15 Mid |
| 11/20/2025 | 11/20–12/20/2025 | $53,407,909 | 58,168,017 | 4,760,108 | 9% | 2025-07-15 Mid | 57,975,474 | 4,567,565 | 9% | 2025-07-15 Mid |
| 11/30/2025 | 11/30–12/30/2025 | $46,698,224 | 56,110,998 | 9,412,774 | 20% | 2025-07-15 Mid | 55,690,597 | 8,992,373 | 19% | 2025-07-15 Mid |
| 12/1/2025 | 12/1–12/31/2025 | $49,070,409 | 56,391,026 | 7,320,617 | 15% | 2025-07-15 Mid | 56,090,307 | 7,019,898 | 14% | 2025-07-15 Mid |
| 12/10/2025 | 12/10–1/10/2026 | $40,526,019 | 50,077,497 | 9,551,478 | 24% | 2025-01-15 Mid | 46,414,133 | 5,888,114 | 15% | 2025-07-15 Mid |
| 12/20/2025 | 12/20–1/20/2026 | $34,973,079 | 43,911,324 | 8,938,245 | 26% | 2025-01-15 Mid | 45,736,582 | 10,763,503 | 31% | 2025-01-15 Mid |
| 12/30/2025 | 12/30–1/30/2026 | $33,351,324 | 32,536,538 | (814,786) | -2% | 2025-01-15 Mid | 41,537,472 | 8,186,148 | 25% | 2025-01-15 Mid |
| 1/1/2026 | 1/1–1/31/2026 | $30,174,389 | 27,070,723 | (3,103,666) | -10% | 2025-01-15 Mid | 33,539,778 | 3,365,389 | 11% | 2025-01-15 Mid |
| 1/10/2026 | 1/10–2/10/2026 | $36,848,021 | 34,907,201 | (1,940,820) | -5% | 2025-01-15 Mid | 35,468,792 | (1,379,229) | -4% | 2025-01-15 Mid |
| 1/20/2026 | 1/20–2/20/2026 | $42,897,864 | 41,333,444 | (1,564,420) | -4% | 2026-03-01 Full | 43,616,945 | 719,081 | 2% | |
| 1/30/2026 | 1/30–2/28/2026 | $41,426,364 | 37,619,935 | (3,806,429) | -9% | 2026-03-01 Full | 38,820,810 | (2,605,554) | -6% | |
| 2/1/2026 | 2/1–2/28/2026 | $40,564,515 | 36,758,086 | (3,806,429) | -9% | 2026-03-01 Full | 37,958,961 | (2,605,554) | -6% | |
| 2/10/2026 | 2/10–3/10/2026 | $41,282,795 | 34,919,588 | (6,363,207) | -15% | 2026-03-01 Full | 35,485,151 | (5,797,644) | -14% | |
| 2/20/2026 | 2/20–3/20/2026 | $41,198,991 | 36,272,949 | (4,926,042) | -12% | 2026-03-01 Full | 36,272,949 | (4,926,042) | -12% | |
| 2/28/2026 | 3/1–3/31/2026 | $45,844,441 | 37,864,984 | (7,979,457) | -17% | 2026-03-01 Full | 37,864,984 | (7,979,457) | -17% | |
| 3/10/2026 | 3/10–4/10/2026 | $51,239,860 | 45,578,333 | (5,661,527) | -11% | 2026-03-15 Mid | 45,578,333 | (5,661,527) | -11% | 03-15-2026 Mid |
| 3/20/2026 | 3/20–4/20/2026 | $52,165,111 | 51,630,941 | (534,170) | -1% | 2026-03-15 Mid | 51,630,941 | (534,170) | -1% | 03-15-2026 Mid |
| 3/30/2026 | 3/30–4/30/2026 | $54,034,773 | 57,116,855 | 3,082,082 | 6% | 2026-03-15 Mid | 57,116,855 | 3,082,082 | 6% | 03-15-2026 Mid |

## V9 Run Output (TODAY = 2026-03-30)

```
TODAY          : 2026-03-30
Actuals through: 2026-04-02
Forecast start : 2026-04-03
Output through : 2026-05-08

🚨 DISTANCE WARNING: nearest anchor '2026-03-15 (mid)' has feature_dist=17.3488 (threshold=3.5).

[RollingParamLookup — Retail Broker — v9 (fix #1+#2)]
  Pool                : (non-January pool)
  Eligible anchors    : 28 of 30
  Feature dimensions  : 19  (was 25 in v8)
  Nearest anchor      : 2026-03-15 (mid)
    feature_distance  : 17.3488
    adjusted_distance : 17.3488
  Anchor biz days     : 22
  ── LIVE features (key signals) ──
    apps_count_per_biz_day_2m :       62.0
    uw_count_per_biz_day_2m   :       33.8
    apps_count_pct_chg_1m     : +5.5%   (2m: +21.6%)
    uw_count_pct_chg_1m       : +9.9%   (2m: +17.1%)

  Top-5 nearest anchors:
    1  2026-03-15 (mid)   17.3488
    2  2025-07-15 (mid)   17.4189
    3  2026-03 (full)     17.7863
    4  2025-04-15 (mid)   17.9523
    5  2025-04 (full)     17.9719

TOTAL (actuals + forecast) for 30-day window: 75,036,520
Apr 30 month total: $48,173,335 forecast vs $45,091,253 actual (MAE 455,294, MAPE +25.4%)
``` 

## User Request Sequence

1. User shared V8, V9, V10 notebooks plus a V8-vs-V9 backtest comparison table.
2. User said: *"here is v10 which is a copy of v9, pull the cell needing the edit for step A and make the edits and then give me the cell block back"* — this referenced an earlier "Step A" instruction not contained in this conversation transcript, so the assistant did not have enough context to perform the edit.
3. User then asked to save the conversation as a markdown file:
   *"great, can you now save this conversation as a markdown file in repo @ceara-stewart/Forecasting_Repo and call it Conversations_Rolling30_RB_4-30_V2"*

## Notes / Open Items

- "Step A" edits to V10 were not specified in this transcript. To proceed, the specific Step A change description (which cell, what edit) is needed.
- V9 currently shows a feature_distance of 17.35 — well above the warning threshold of 3.5 — indicating no close regime match for the live 2026-03-30 profile. This is consistent across the top-5 anchors (all > 17).
- V9 vs V8 comparison shows V9 generally improves forecasts during regime transitions (e.g., 10/30, 12/10, 1/1) but can introduce errors in stable regimes where V8 was already close.