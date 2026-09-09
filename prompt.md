# USD rates exotics: close-of-day hedge decision

You are the rates exotics risk trader at a synthetic dealer. Reconstruct the economic book known at **2026-09-08 16:00:00 UTC**, calculate its risk in executable quote coordinates, and select a hedge from the permitted tickets. Return **one completed Excel workbook** with an auditable calculation trail and a short desk recommendation.

Your only market and position input is `input_workbook.xlsx`. All data are synthetic. The supplied PV cube is the authoritative valuation service for this exercise. You are not being asked to calibrate a pricing model or fetch market data. The product descriptions explain the desk context; do not substitute another model's valuations.

You may use code, spreadsheets, optimization tools, and other ordinary calculation tools. There is no speed bonus. Correct numerical results, economic conventions, and executability determine the score. Retain full precision in calculation and display USD to two decimals. Risk factors use the units specified below.

## 1. Reconstruct the book

Each Events row is a **complete economic snapshot**, not a flow. For each TradeID, first retain rows whose EffectiveUTC **and** ReceivedUTC are at or before the cutoff, inclusively. Among those, select the greatest tuple `(EffectiveUTC, Revision, ReceivedUTC)`, in that order. A later revision with an earlier effective time does not outrank a later effective time. If no row qualifies, select `NONE`.

Only a selected `LIVE` snapshot contributes to the book. TERMINATED, EXERCISED, and CANCELLED snapshots contribute zero. Do not fall back to a prior LIVE row. If SelectedEventID is `NONE`, leave ModelKey blank, use Status=`NOT_KNOWN`, and set all numeric Selection fields to zero. An exercised option's replacement swap is a separately booked trade and must be considered independently. OutstandingMM is remaining notional in USD millions. Side is +1 or -1 relative to the canonical positive instrument and is applied exactly once. Do not infer another sign from payer/receiver terminology.

Join the selected ModelKey to Instruments. SignedUnits = Side × OutstandingMM / RiskUnitMM for LIVE rows and zero otherwise. All PV cube marks describe **one positive RiskUnitMM**, never the whole signed position. Multiply raw marks by USDPerRaw to obtain USD. For USD cents the multiplier is 0.01. There is no FX conversion.

## 2. Recover the native finite-difference risk

Use SnapshotID=`CLOSE_1600` and Policy=`OPT` for production PV, risk, hedging, and scenario limits. `FROZEN` contains a diagnostic with exercise policy frozen. `INTRADAY_1530` is an incomplete earlier snapshot and must not fill any production data. Row order is immaterial. The unique valuation key is `(ModelKey, SnapshotID, Policy, StateID)`.

Recover PV0, 7 deltas, and all 28 distinct entries of the symmetric native Hessian for **all 30 instruments**, including unused or inactive ModelKeys and all 8 permitted hedges. Units are USD per canonical risk unit. These are the specified finite-difference measures; do not replace them with analytic derivatives.

For factor i with native bump h_i, use:

```
g_i    = (V(+h_i) - V(-h_i)) / (2 h_i)
H_ii   = (V(+h_i) + V(-h_i) - 2 V0) / h_i^2
H_ij   = (V(++ ) - V(+-) - V(-+) + V(--)) / (4 h_i h_j), i < j
```

The two signs in a CROSS state refer to FactorI then FactorJ. The States sheet provides the actual shocks. H_ji = H_ij. Native factors are ordered Z2, Z5, Z10, BASIS, NV1, NV5, CORR. Rates and basis use absolute rate basis points. NV1 and NV5 use **absolute normal-volatility basis points**, not a percentage of the quoted volatility. CORR uses percentage points of correlation: a shock of 1 means +0.01 in decimal correlation. Thus a USD/CORR derivative is per correlation percentage point.

## 3. Transform to executable quote risk

Quote factors are ordered P2, P5, P10, BASIS, NV1, NV5, CORR. P2/P5/P10 are the synthetic par-quote coordinates. The local mapping from quote shocks y to native shocks x is:

```
x_i(y) = sum_j J_ij y_j + 0.5 sum_j sum_k K_ijk y_j y_k
```

Jacobian rows are native factors and columns are quote factors. MapCurvature supplies K entries with j <= k. A listed off-diagonal entry supplies **both** K_ijk and K_ikj; do not halve it, and treat unlisted entries as zero. Use the same mapping for book instruments and hedges.

Calculate quote delta and quote Hessian by:

```
g_quote = transpose(J) g_native
H_quote = transpose(J) H_native J + sum_i g_native_i K_i
```

Apply these equations to the prescribed finite-difference measures. The curve-curvature term is required even for instruments with small native gamma. Report Hessian entries as second derivatives without absorbing a factor of 1/2. Aggregate signed position PV and risk using SignedUnits. A positive delta means that a positive quote shock increases desk PV.

## 4. Full revaluation and attribution

All 20 STRESS states have equal weight. Their NativeX coordinates are the supplied full map of the corresponding QuoteY shocks. Full production P&L for an instrument is `V_OPT(stress) - V_OPT(BASE)`. Compute pre-hedge book P&L and, separately, the frozen-policy book P&L `V_FROZEN(stress) - V_FROZEN(BASE)` using the same selected positions.

For each stress, attribute **pre-hedge OPT book P&L** into:

```
DeltaPnL = g_quote_book dot y
GammaPnL = 0.5 * transpose(y) H_quote_book y
NonlinearResidual = FullPrePnL - DeltaPnL - GammaPnL
```

Include all cross terms exactly once in the upper-triangle calculation. The frozen-policy difference is a separate diagnostic; it is not the nonlinear residual. Use full OPT revaluation to select and assess hedges. Do not use the attribution approximation for stress limits or the objective.

## 5. Executable hedge and objective

For hedge j, q_j is an integer number of canonical lots between MinLots and MaxLots, inclusive. Positive q buys the described positive instrument; negative q sells it. One lot has the listed LotMM. There is one net ticket per HedgeID. Simultaneous buy and sell orders in the same HedgeID are prohibited. The allowed zero choices are real zeros, not missing data. The book remains fixed; these q values are incremental hedges.

Let b=max(q,0), s=max(-q,0). A tier resets separately for each HedgeID. The first two lots and every subsequent lot have different marginal execution costs:

```
TC_j = BuyFirst2 * min(b,2) + BuyBeyond2 * max(b-2,0)
     + SellFirst2 * min(s,2) + SellBeyond2 * max(s-2,0)
     + TicketFee * 1(q != 0)
TC = sum_j TC_j
```

All cost and premium inputs are USD **per lot**. PremiumCashBuy and PremiumCashSell are separate funding-cash schedules, not additional valuation inputs. Mid marks in the cube determine market revaluation. Premiums do not enter stress P&L as a loss, because the purchased/sold asset is included in the portfolio. TC is the complete immediate economic execution loss and is included once.

```
CashUse = TC + sum_j [b_j * PremiumCashBuy_j
                     - 0.80 * s_j * PremiumCashSell_j]
MarginUse = sum_j abs(q_j) * MarginPerLot_j
HedgePnL_s = sum_j q_j * (V_j,OPT,s - V_j,OPT,BASE)
NetPnL_s = FullPrePnL_s + HedgePnL_s - TC
Loss_s = -NetPnL_s
```

Only 80% of sale premium counts as immediately available funding. Negative CashUse is allowed and means a net eligible cash receipt; do not floor it. There is no margin netting, no cash credit against MarginUse, and no cap on net cash receipt.

The hard constraints are all stated in Limits: absolute **post-hedge quote delta** caps for all seven factors; absolute post-hedge `H_quote(NV5,NV5)` cap; CashUse cap; gross MarginUse cap; active-ticket cap; sum(abs(q)) cap; and a loss cap in **every** full-revaluation stress. Use `<=` for limits and apply TC to each stress loss. All must pass simultaneously.

Minimize **ES4**, defined as the arithmetic mean of the **four largest signed Loss_s values** among the 20 stresses. Do not floor losses at zero. Do not use all positive-loss scenarios, a percentile interpolation, a maximum loss, a standard-normal VaR multiplier, or scenario probabilities from another source. The selected tail changes with the hedge.

The primary objective is ES4. If two feasible baskets differ in ES4 by at most USD 0.01, prefer the one with lower TC. If TC is also within USD 0.01, choose the lexicographically smallest signed q tuple in H01 to H08 order. Show evidence supporting global optimality, such as exhaustive bounded enumeration or a valid optimization bound. A continuous answer rounded to lots is not sufficient without rechecking feasibility and optimality.

## 6. Required workbook outputs

Use the sheet and column names below, with headers in row 5 and data beginning in row 6. Additional supporting sheets are welcome. Keep identifiers as text, zeros numeric, and errors visible. On risk sheets use Metric=`PV`, `D`, or `G`. For PV, FactorI and FactorJ are blank; for D, FactorJ is blank; for G report only i <= j in the stated factor order. Include no duplicate keys. Formula-driven or code-calculated intermediate risks are both acceptable, but show how they were obtained. Hedge-dependent outputs must recalculate when q changes; do not merely paste a static summary.

| Sheet | Columns, in order |
|---|---|
| Selection | TradeID, SelectedEventID, ModelKey, Status, Live, Side, OutstandingMM, SignedUnits, PositionPV |
| NativeRisk | ModelKey, Metric, FactorI, FactorJ, ValueUSD |
| QuoteRisk | ModelKey, Metric, FactorI, FactorJ, ValueUSD |
| BookRisk | Metric, FactorI, FactorJ, PreUSD, HedgeUSD, PostUSD |
| HedgeTickets | HedgeID, Lots, NotionalMM, TC, CashUse, MarginUse |
| Scenarios | StateID, FullPrePnL, HedgePnL, TC, NetPnL, Loss, FrozenPrePnL |
| Attribution | StateID, DeltaPnL, GammaPnL, FullPrePnL, NonlinearResidual |
| Summary | Metric, Value |

Required Summary numeric metric keys: `LiveTrades`, `BasePV`, `ES4Before`, `ES4After`, `WorstLossAfter`, `TransactionCost`, `CashUse`, `MarginUse`, `ActiveTickets`, `GrossLots`, `FeasibleBaskets`, `SearchSpace`, and `OptimalityGapUSD`. If using a certified optimizer rather than exhaustive enumeration, FeasibleBaskets may be `n.a.`; all other metrics are required. Add tail scenario IDs, each limit's actual and headroom, and the desk recommendation below the Summary metric table or in clearly labeled additional sheets.

The recommendation must explain the hedge directions and sizes, the cost and risk trade-off, and at least two material diagnostics supported by this case's numbers. Include one example of why the frozen-policy report or delta-gamma approximation would mislead this decision. A qualitative recommendation alone is not a solution.

Numeric grading tolerances: PV, P&L, costs, cash, margin and objective USD 0.05 absolute; deltas USD 0.02 per factor unit; Hessians USD 0.02 per factor-unit product. IDs, statuses, integer quantities and membership are exact. Limit feasibility is assessed at USD/risk tolerance 0.05. Optimality credit is assessed against the objective actually produced by the submitted lots and the authoritative inputs, not a typed claim. Calculation-method and reconciliation credit can be earned independently of upstream numerical correctness.
