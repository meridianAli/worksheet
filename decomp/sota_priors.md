# Empirical priors: what predicts a sheets task being cancelled as too easy after SOTA eval

Source: tsip_prd, sheets project, tasks that reached needs_sota_eval in the last 45-60 days.

## How the SOTA gate works
- After decomp_review APPROVE the task goes generating_prompt -> generating_rubric -> needs_sota_eval.
- External SOTA evaluation writes `sota_bucket` in {Foundational, Intermediate, Challenging, Difficult}.
- Operators then release by hand. Disposition of the last 45 days:
  - Foundational: 30 scored -> 30 cancelled (100%)
  - Intermediate: 57 scored -> 20 cancelled, 24 audit, 7 redo (coin flip)
  - Challenging: 320 -> essentially all proceed
  - Difficult: 97 -> essentially all proceed
- "Too easy" below = Foundational or Intermediate. Baseline rate across all scored tasks: 87/504 = 17.3%.
- 458 tasks in 30 days were cancelled from needs_sota_eval. Each had already consumed prompt generation, rubric generation and a SOTA sweep.

## Decomper track record (60 days, sheets). This is the strongest single predictor.
| decomper | SOTA-scored | Foundational | Intermediate | Challenging | Difficult | too-easy |
|---|---:|---:|---:|---:|---:|---:|
| wangche2532@gmail.com | 28 | 15 | 9 | 4 | 0 | 85.7% |
| infinitearbitrage@gmail.com | 16 | 9 | 5 | 1 | 1 | 87.5% |
| apathy@uchicago.edu | 9 | 4 | 1 | 3 | 1 | 55.6% |
| mshuriah2702@gmail.com | 4 | 1 | 3 | 0 | 0 | 100% (n=4) |
| nimisha.mekala2021@gmail.com | 2 | 1 | 1 | 0 | 0 | 100% (n=2) |
| andrew.holliday@toptal.com | 3 | 0 | 1 | 2 | 0 | 33% (n=3) |
| sophie.xiao@toptal.com | 8 | 0 | 0 | 7 | 1 | 0% |
| alec.tseung@toptal.com | 0 | - | - | - | - | no data |
| every other decomper with >=5 scored (23 people) | 5-61 each | **0 Foundational for all of them** | | | | 0-42%, median ~7% |

Only three people in the whole project have ever produced a Foundational-bucket task. Two of them wrote 87 of the 133 tasks under review. Treat the decomper prior as strong but NOT decisive: judge the content, then say whether the content supports or contradicts the prior.

## Content signals in the stored outline (504 scored tasks)
| signal | too-easy with | too-easy without |
|---|---:|---:|
| mentions DCF / discount / terminal value / WACC / IRR / NPV / valuation | 8.8% | 25.7% |
| mentions circular / iterative / revolver / debt schedule / average-balance interest / cash sweep / waterfall | 8.7% | 22.2% |
| mentions scenario / toggle / switch / CHOOSE / OFFSET / INDEX | 14.7% | 20.3% |
| "as a copy of" / "mirror" / "identical to" / "same structure as" a sibling tab | 14.8% | 18.4% |
| extend/roll/carry ... across/forward (pattern extension) | 13.7% | 19.1% |
| outline length < 3,000 chars | 70% (n=10) | - |
| outline length 3,000-6,000 | 22.2% | - |
| outline length 6,000-10,000 | 13.7% | - |
| outline length > 10,000 | 9.4% | - |
| fewer than 9 bullets | ~26% | - |
| 14+ bullets | 15.0% | - |
| unique formulas 50-149 | 41.7% | - |
| unique formulas 150-299 | 25.6% | - |
| unique formulas 300+ | 14-18% | - |

## Things that do NOT matter downstream (tested; do not flag them as blockers)
- Cell references in the outline (spec says none; 59% of outlines have them anyway): too-easy 15.7% vs 20.5% without, failed-generation 3.2% vs 3.4%. No effect.
- Literal formulas in the outline: same, no effect.
- Whether the task is a clone: clones fail slightly LESS often.
- Input/output workbook being identical: never happens (0 of 1,602).

## What "too easy" outlines have looked like (Foundational bucket, real examples)
- Rebuild a BASE-case tab "as a copy of" the INT-case tab that is still present in the input, relabel, re-anchor dates, carry growth forward.
- Extend header date rows across projection columns; project a driver as prior x (1+growth) with growth seeded at 0%.
- Add a valuation-metrics block that is pure arithmetic on a handful of hardcoded inputs (EBITDA, lease expense, EPS -> EV/EBITDAR, P/E).
- Repeat trailing-twelve-month driver rows indefinitely across the forecast.
The common thread: the work is reconstructible from structure still visible in the input workbook, or is pattern-fill, or is arithmetic on stated inputs. Little to invent.

## What "Difficult" outlines have looked like
- Build a CapEx & Depreciation schedule for two cases with a waterfall of per-facility lines, useful-life drivers and a depreciation roll.
- Complete forecast columns for a model where drivers exist but every linkage (revenue roll, margins, debt schedule, working capital, cash flow, sources & uses, leverage) is missing, plus a PF capitalization table.
- Stub-period assumptions with YEARFRAC, ownership pulls, facility operating earnings, NCI, then a $000s output block.
- A DCF block with entry metrics blended by stub fraction, EDATE-stepped timeline, terminal column, and P&L pulls.
The common thread: genuine new logic with cross-tab dependencies and methodology choices a model has to get right, not reconstructible from a sibling.
