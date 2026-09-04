# Five banker scenarios

The five tasks exported on 2026-09-04 (`tasksexport20260904.json`) are each an
input workbook, a bare specification, and an output workbook. The specifications
read as build orders — no deal, no client, no reason the work exists. This file
rewrites each one as a scene: who is asking, what deal they are on, what they
are staring at in the input workbook, and what they need back.

**Nothing in the specifications was dropped.** Every rate, day count, balance,
range, font and colour rule from the original prompt survives into the ask
below, because the output workbook only ties out if it does. The scenes add the
motive; they do not change the build.

Each scene stands alone. Read one scene, open its input workbook, and you have
the whole job.

| # | Task id | Input workbook | Deal | The build |
|---|---|---|---|---|
| 1 | `2266fdca` | `GD006_N-4.xlsx` | Sell-side, sponsor-owned distributor | P&L, working capital, debt schedule, EBITDA bridge |
| 2 | `b68326d5` | `FIMR_N-1.xlsx` | Cedarbrook Social IPO | Sources & uses, pro forma balance sheet, valuation, dilution grids |
| 3 | `bb849b91` | `7.27_013_N-2.xlsx` | Four-entity Egyptian real estate portfolio | Annual cashflow statements, four entities |
| 4 | `ef94a62b` | `7.20_016_N-2.xlsx` | SBA-financed owner-user acquisition | Sources & uses, returns, three amortisation tabs |
| 5 | `fbe4760b` | `Model_v4_N-2.xlsx` | Cedarbrook asset-management forecast | AUM rollforward, fee build, five-year revenue forecast |

---

## Scene 1 — Thursday, 7:40pm. The QoE landed and the bridge doesn't exist yet.

*Associate to the analyst, standing at the desk, laptop already open.*

The sponsor sent back the quality-of-earnings deck this afternoon and management
wants the full operating model in the data room Monday. Right now all we have is
the Assumptions sheet — everything else got stripped out when we rebuilt it.
I need four integrated tabs off that sheet, FY2022A through FY2030P: Enterprise
P&L, Working Capital, Debt Schedule, and an FY2024A-to-FY2025B EBITDA bridge.
Use the model structure, units and formatting conventions that are already
there; don't invent a new house style halfway through a live deal.

**The P&L** runs through Net Income. Operating assumptions link to the
Assumptions sheet, debt interest links to the Debt Schedule you're about to
build. Lay in D&A, Operating Income (EBIT), the QoE adjustments, Adjusted
EBITDA, Interest Expense, Other Income/(Expense), Tax Expense, Net Income, and
the margins alongside. Non-operating other income is 4.8, 4.8, 4.7, 4.4, 3.9,
4.2, 4.3, 4.5 and 4.7 for FY2022A–FY2030P in order. Tax only on positive
pre-tax income, at the consolidated effective rate on the Assumptions sheet.

**Working capital**, 365-day basis:

- DSO — 42.7 days FY2022A; 42.5 FY2023A and FY2024A; 42.0 from FY2025B on.
- DIH — 60.0 FY2022A; 52.0 FY2023A; 49.0 FY2024A; 48.0 from FY2025B on.
- DPO — 105.0 FY2022A; 94.0 FY2023A; 110.0 FY2024A; 105.0 from FY2025B on.
- Prepaids 0.0% of operating expenses, accrued liabilities 10.0% of operating
  expenses, deferred revenue 0.0% of revenue.

**Debt schedule**, two tranches, interest on average beginning and ending
balances:

- Term loan — opens at 3.5 in FY2022A, mandatory repayments of 0.5 a year from
  FY2022A until it's gone. 0.0% in FY2022A and FY2023A, 10.0% from FY2024A on
  while a balance is outstanding.
- Line of credit — opens at 1.5 in FY2022A, repayments of 0.5 in FY2023A, 0.5
  in FY2024A, 0.3 in FY2025B. No further draws or repayments, so 0.2 rides
  through FY2030P. 10.0% throughout FY2022A–FY2030P.

**The bridge** is the piece the sponsor will actually turn to first, so make it
formula-driven — a walk from FY2024A EBITDA to FY2025B EBITDA with a separate
variance step for Segment Alpha revenue, Segment Beta revenue, Segment Gamma
revenue, all remaining revenue lines combined as "Other Revenue Lines", COGS,
Customer Acquisition, Postal Charges, Staff Costs, SG&A and Other OpEx. Columns
for component, period-over-period value change, running cumulative EBITDA and
component type. Add a formula-driven waterfall helper block — Base, Increase,
Decrease, Total — ready to plot, plus a short summary showing starting EBITDA,
total change and ending EBITDA.

Link everything back to the Assumptions sheet and to each other. Keep the
colour convention for typed inputs versus formulas versus cross-sheet links, and
tie the schedules out before it comes back to me. If the bridge doesn't foot to
the P&L, we'll find out in front of the sponsor.

---

## Scene 2 — The IPO committee memo is due and the price talk moved.

*VP on Cedarbrook Social, forwarding the working file.*

We're taking Cedarbrook Social out and the committee wants the pricing analysis
in the memo. The shell is in `FIMR` — I need it filled in, and I need the
sensitivity grids because nobody on the committee is going to accept a single
point estimate.

Fees and commissions run at 1.1%. Start with the option holder table: net
shares on the treasury stock method, then total every column.

**Sources and uses**, in both $m and shares. The source is the equity issued;
the uses are primary shares (proceeds raised net of fees), primary shares
underwriting fees, secondary shares (proceeds raised net of fees) and secondary
shares underwriting fees. Give me a check total row — I want to see it foot.

Everything from the Balance Sheet through Pro Forma Ownership gets pre-money,
IPO and post-money columns. Valuation is the exception: pre-money and post-money
only, no IPO column.

**Balance sheet**, simplified. Pre-money cash and equivalents 1,282,
short-term investments 2,628, goodwill 189. Operating assets are receivables
482, inventory 627, prepaid expenses 1,855, other operating assets 121.
Debt 404, capital leases 302. Operating liabilities are payables 1,039, accrued
expenses 144, less 302 of deferred tax asset offsets. Equity 5,597. The IPO
column is net primary proceeds landing in cash and equity; post-money is the sum
of the two. Show total assets and total liabilities and equity.

**Income statement.** Return on cash invested 0%, tax rate 40%. D&A 323, EBIT
1,756, pre-money net interest income −42 − 19, pre-money tax −695, net income
attributable to participating securities −332 in both pre- and post-money,
pre-money EPS 0.4. The IPO column adds return on the new cash at the assumed
rate and its tax effect. Derive PBT, net income, net income attributable to
Class A and Class B common stockholders, WASO and EPS, and give me an EPS
accretion/dilution line.

**Valuation**, pre- and post-money: diluted NoSO, offer price (hardcode 38 in
the post-money column), implied equity value, net debt, implied enterprise
value, pre-deal P/E, post-deal P/E and EV/EBITDA.

**Pro forma ownership**, pre-money / IPO / post-money: pre-deal shareholders
including option holders, new shareholders, total shares, post-money ownership
percentages.

Then the grids, because the price talk is going to move again:

- *Analysis at various prices* — $34.00 to $42.00 in $2.00 steps, showing
  pre-deal P/E, post-deal P/E and EV/EBITDA off the valuation section.
- *Shareholder dilution at different share issuance* — primary 160 to 200 in
  steps of 10, secondary 211.2 to 281.2 in steps of 10, run against the pre-deal
  ownership percentage from the pro forma section.
- *New money raised* — offer prices $34.00 to $42.00 in $2.00 steps against
  primary shares 160 to 200 in steps of 10; each cell the new money raised.
- *Proceeds to existing shareholders* — same offer price range, secondary shares
  211.2 to 281.2 in steps of 10; each cell the proceeds to existing holders.

Hardcodes in #0000FF, calculated values in black, Arial 10pt, number formats and
header fills matching the rest of the model. This goes into the memo as a
screenshot, so it has to look like the rest of the book.

---

## Scene 3 — The lenders want annuals, and we only have 132 months.

*Analyst on the Egyptian portfolio financing, to the modeller.*

The lender's credit team came back this morning: they will not work off the
monthly tabs. They want annual cashflow statements for all four entities —
TIBA, Stone Park, Sahary and El-Rowad — on their respective *CF - Annually*
tabs. The good news is the tabs are already laid out with the right rows and
section labels. The numbers are what's missing, and they have to come from
aggregating each entity's monthly cashflow.

For each tab, build the annual period columns by summing the monthly data in
eleven successive 12-month blocks starting Oct-2020, so the eleven annual
columns cover the whole 132-month monthly grid end to end. Complete the Starting
Balance, Total and Grand Total columns consistently with the layout, and keep
row and section labels matching the corresponding monthly tab — credit will be
reading the two side by side.

Complete every subtotal, total and net cashflow row using the workbook's
standard cashflow section logic, across all column types.

Watch the finance sections, because the entities differ. TIBA and Stone Park
have a Cashflow from Finance section — Facility Drawdown, Facility Repayment,
Interest Expense, Other Fees — sourced from their monthly tabs, and for those
two Periodical Net Cashflows is Net Cash Inflows/Outflows plus Net Cashflows
from Finance. Sahary and El-Rowad have no finance section, so there Periodical
Net Cashflows is Net Cash Inflows/Outflows directly.

Complete the cash balance roll-forward and populate the Minimum Cash END Balance
field at the top of each tab — that figure is the covenant conversation.

Two hardcodes from the client's side:

- On Sahary CF - Annually, enter 0 for Dues To Sister Companies in the 2025 and
  2026 annual columns.
- On both TIBA CF - Annually and Sahary CF - Annually, park a 60,000,000 memo
  figure in cell AU40, outside the reporting columns.

Follow the monthly tabs' colour convention: blue for typed hardcodes, #008000
for links to other tabs, black for same-sheet calculations.

---

## Scene 4 — The SBA structure only works if the year-5 refi works.

*Deal lead on an owner-user acquisition, to the analyst.*

The buyer is funding this with SBA 504 and SBA 7(a) money and taking a refinance
in year 5. The sponsor's question is simple — does the LP get paid — and I can't
answer it until the debt is actually modelled. The Assumptions tab needs wiring
up, and then I need three monthly amortisation tabs: L1, L2, L3.

**Assumptions tab.** Add a year-number header row, 1 through 10, above the Gross
Revenue row, to serve as the period index for the revenue/expense table. Add
formulas for Total Expenses (Salaries/Wages plus Other Expenses), OPEX Expense
Ratio (Total Expenses / Gross Revenue) and NOI. NOI has to respect the
"Use Manual?" switch: if Yes, Gross Revenue × (1 − Manual Expense Ratio); if No,
Gross Revenue less actual Total Expenses.

SBA 504 Loan Amount is SBA 504 % × RE Budget Total. SBA 7(a) Loan Amount is
SBA 7(a) % × Basis for 7a Loan Calc, where the basis is Total Funds less RE
Budget Total. For the REFI scenario, LTV Value looks up NOI at the Refi Period
year — use the year header row as the index — divided by Cap Rate on Refi, and
REFI Amount is LTV × LTV Value. That lookup is the whole point of the year
header row; hardcoding the year-5 NOI defeats the exercise the moment the
sponsor asks for year 6.

Alongside the General Assumptions block, add two sections:

- *Sources* — SBA 504 Loan, SBA 7(a) Loan, Raised Funds, Total, pulling from the
  computed loan amounts and Required Raise.
- *Uses* — Real Estate Purchase Price, Business Purchase Price, Acquisition Fee,
  Gap Funding, Loan Fees (label only, no value yet), Legal (label only, no value
  yet), Cash Reserve as the residual so Sources Total equals Uses Total, and
  Total.

Below the deal terms, add a Returns block with IRR and Equity Multiple for both
LP and GP, plus a Remaining LP Balance After REFI label row in the same area —
value gets linked once the refi tab exists.

**The three tabs.** L1 is the SBA 504 amortisation, L2 the SBA 7(a), L3 the
REFI. All three use the General Loan Amortization layout; L3 also gets labelled
REFI at the top. The parameter block at the top of each pulls from the relevant
Assumptions section: Loan Amount, Start Month of Repayment, I/O Period in months
(Assumptions years × 12), End loan after I/O?, Recast Loan?, I/O Rate,
Amortization Period in years, Term of Loan in years, Interest Rate, Payoff
Early?, Start Date, End Date, and summary totals for Total Interest and Total
Principal Repaid.

Start Month of Repayment is hardcoded 1 on L1 and L2. On L3 derive it from the
REFI section on Assumptions — Refi Period converted to a month number.

Under the parameter block, a 400-row monthly schedule on each tab. Monthly
interest is the annual rate ÷ 12. Use ROUNDUP converting remaining amortisation
years to months. Columns per row: Year #, Date, Model Month #, Borrow Amount,
Beginning Balance, Principal, Balloon Payment, Exit Repayment, Extra Principal,
Interest, Interest Rate, Ending Balance, Repayment Counter, Amortization
Counter, Offset (when extra principal happens), Total Principal, Total Debt
Payment, Amortization Payment (not recast), Other Reduction to Principal, Total
Principal, Total Interest, Amortization Only.

L1 carries two additional period-tracking columns before Date and uses "Original
Loan Month #" in place of "Model Month #". Hardcode 0 in the Extra Principal
input cells for the last four rows of the L1 and L2 schedules, months 397–400.

Hardcoded inputs blue (#0000FF), same-sheet formulas black, cross-sheet links
green (#008000). Aptos Narrow 11 throughout the new sections, number formats and
section header fills consistent with the rest of the workbook.

---

## Scene 5 — Management's fee assumption is a single number, and it shouldn't be.

*Associate on the Cedarbrook asset-management diligence.*

Management's forecast carries one blended fee rate across every product. That
won't survive diligence — open-ended funds and institutional accounts don't earn
the same basis points and never have. I want to build the fee rate up from the
actual history and then forecast off it. Three pieces: extend the
AUM_Rollforward tab, build a Revenue_Build tab, and build a Revenue_Forecast tab.

**AUM_Rollforward.** The (IV) Institutional Accounts section is missing its Key
Memo Item block after the Ending Balance — add it, four rows off the section's
own rollforward data: Inflows % of BoP, Outflows % of BoP, Market Performance %
of BoP, Other % of BoP. Then add a (V) Total section aggregating all four
product categories with the same structure as the individual sections —
Beginning Balance, Inflows, Outflows, Net Flows, Market Performance, Other,
Ending Balance — followed by a Key Memo Item block with the same four % of BoP
metrics.

**Revenue_Build**, new tab. This is the fee analysis that answers the blended-rate
problem. "Fiscal Year Ended," date header covering the available fiscal year
history. One section, "(I) Fees by Avg AUM", with four sub-sections:

- (a) Open-Ended Funds
- (b) Closed-End Funds
- (c) Retail Separate Accounts
- (d) Institutional Accounts

Each shows three rows: Fees (Investment Management Fees from Revenue_Breakdown,
in $'000s), Avg AUM (average of beginning and ending AUM balances from
AUM_Rollforward, in $mm), and Avg Fees % — the derived rate. Only populate
columns where both the beginning and ending AUM are available; a half-year
denominator would flatter the rate and someone will catch it.

**Revenue_Forecast**, new tab. "Fiscal Year Ended," date header and a unit note
reading "(AUM in $mm, Revenue in $'000s)". Four product sections mirroring the
AUM_Rollforward categories: (I) Open-End Funds, (II) Closed-End Funds,
(III) Retail Separate Accounts, (IV) Institutional Accounts.

Each section carries an AUM rollforward (BoP AUM, Net Flows, Market Performance,
Other, EoP AUM); a driver memo block labelled "[Product] AUM Drivers:" with Net
Flows % of BoP, Market Performance % of BoP and Other % of BoP; an Avg Fees row;
and a revenue summary line labelled "[Product] Revenue Inv. Mgmt Fees", driven
by period average AUM and Avg Fees %.

Historical periods source AUM from AUM_Rollforward, link Avg Fees from
Revenue_Build, and compute the % of BoP driver rows from the rollforward
figures. FY2022–FY2024 are history; FY2025–FY2029 are forecast. Forecast periods
drive AUM movements off BoP using a rolling three-year trailing average of each
driver percentage — the window rolls forward and includes prior forecast years —
and Avg Fees carry forward on the same rolling three-year basis.

Calculated values in black, Aptos Narrow 11 in the changed sections, number
formats consistent with the surrounding model, section header fills consistent
with the existing workbook style.
