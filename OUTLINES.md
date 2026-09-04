# Five briefing outlines

Five investment-banking model builds. Each one is what a senior banker needs to
cover when handing the work to an analyst — the points to make, not the words to
say. The wording is yours; the specifics that can't be invented (given figures,
tab names, stated ranges) are listed because they have to be transferred exactly.

Each outline is tested against the real workbooks: the input and output files
are compared cell by cell, and anything the analyst couldn't have derived on
their own has to appear here. See [`tests/README.md`](tests/README.md).

| # | Task | Input | Output | Cell changes | Enforced |
|---|---|---|---|---:|---:|
| 1 | `2266fdca` | `GD006_N-4.xlsx` | `GD006_N-3.xlsx` | 816 | 45 |
| 2 | `b68326d5` | `FIMR_N-1.xlsx` | `FIMR.xlsx` | 329 | 57 |
| 3 | `bb849b91` | `7.27_013_N-2.xlsx` | `OUTPUT_WORKBOOK_-_TIBA.xlsx` | 2,310 | 2 |
| 4 | `ef94a62b` | `7.20_016_N-2.xlsx` | `7.20_016_N-1.xlsx` | 27,450 | 52 |
| 5 | `fbe4760b` | `Model_v4_N-2.xlsx` | `Model_v4_N-1__v2_.xlsx` | 1,198 | 24 |

---

## 1 — Operating model off the assumptions sheet

**Situation.** Sell-side process for a sponsor-owned distributor. The
quality-of-earnings report has just come back, and the full operating model is
due in the data room Monday. The workbook currently contains only the
Assumptions sheet — the rest was stripped out in a rebuild and never replaced.

**Input:** `GD006_N-4.xlsx` · **Output:** `GD006_N-3.xlsx`

### What to ask for

- Four new tabs built off the Assumptions sheet, covering FY2022A through
  FY2030P: **Enterprise P&L**, **Working Capital**, **Debt Schedule**, and an
  **EBITDA Bridge** from FY2024A to FY2025B.
- Everything links — to the Assumptions sheet and to each other.
- Match the model's existing structure, units and formatting conventions.

### Enterprise P&L

- Run it through net income.
- Operating assumptions link to the Assumptions sheet; debt interest links to
  the Debt Schedule.
- Include D&A, operating income (EBIT), the QoE adjustments, adjusted EBITDA,
  interest expense, other income and expense, tax expense, net income, and
  margins.
- **Non-operating other income is given, so it has to be read out** — FY2022A
  through FY2030P in order: 4.8, 4.8, 4.7, 4.4, 3.9, 4.2, 4.3, 4.5, 4.7.
- Tax applies only to positive pre-tax income, at the consolidated effective
  rate held on the Assumptions sheet (link it rather than retyping it).

### Working capital

- 365-day basis.
- The day counts have to be given:

  | | FY2022A | FY2023A | FY2024A | FY2025B onward |
  |---|---|---|---|---|
  | DSO | 42.7 | 42.5 | 42.5 | 42.0 |
  | DIH | 60.0 | 52.0 | 49.0 | 48.0 |
  | DPO | 105.0 | 94.0 | 110.0 | 105.0 |

- Worth flagging: the FY2024A DPO spike is real — that's the year they stretched
  payables — so it shouldn't be smoothed.
- Prepaids 0.0% of operating expenses; accrued liabilities 10.0% of operating
  expenses; deferred revenue 0.0% of revenue.

### Debt schedule

- Two tranches. Interest calculated on the **average of beginning and ending
  balances**, not the opening balance — worth saying explicitly.
- **Term loan:** opens at 3.5 in FY2022A, repays 0.5 a year from FY2022A until
  fully repaid. Rate is 0.0% in FY2022A and FY2023A — worth confirming that is
  genuinely zero, not a missing input — then 10.0% from FY2024A while a balance
  is outstanding.
- **Line of credit:** opens at 1.5 in FY2022A. Repayments of 0.5 in FY2023A, 0.5
  in FY2024A, 0.3 in FY2025B. No further draws or repayments, leaving 0.2
  outstanding through FY2030P. 10.0% throughout.

### EBITDA bridge

- A formula-driven walk from FY2024A EBITDA to FY2025B EBITDA. Worth stressing
  that it's formula-driven — this is the page the sponsor turns to first.
- Separate variance steps for: Segment Alpha revenue, Segment Beta revenue,
  Segment Gamma revenue, all other revenue lines combined as **"Other Revenue
  Lines"**, COGS, Customer Acquisition, Postal Charges, Staff Costs, SG&A, Other
  OpEx.
- Columns: component, period-over-period **value** change, running cumulative
  EBITDA, component type.
- A chart helper block underneath — **Base, Increase, Decrease, Total** —
  formula-driven and ready to plot as a waterfall.
- A short **summary** block on the FY2024A-to-FY2025B walk: starting EBITDA,
  total change, ending EBITDA.

### Ground rules to close on

- Keep the model's color convention: typed inputs, formulas, and cross-sheet
  links each in their existing color.
- The schedules tie out before it comes back.

---

## 2 — Cedarbrook Social IPO analysis

**Situation.** Cedarbrook Social is going public. The pricing analysis is needed
for the IPO committee memo, and committee won't accept a single point estimate —
everything needs a range around it. The shell is already in the workbook.

**Input:** `FIMR_N-1.xlsx` · **Output:** `FIMR.xlsx`

### Set-up

- Fees and commissions rate: **1.1%**, used throughout.
- In the option holder table: net shares on the **treasury stock method**, then
  total every column.
- From the balance sheet through proforma ownership, every section gets
  **pre-money / IPO / post-money** columns. Valuation is the exception — pre and
  post only, no IPO column.

### Sources and uses of funds

- Shown in both **$m and shares**.
- Source of funds is the equity issued. Uses of funds are: primary shares
  (proceeds raised net of fees), primary shares underwriting fees, secondary
  shares (proceeds raised net of fees), secondary shares underwriting fees.
- Include a **check total row**.

### Balance sheet (simplified)

All pre-money figures have to be given:

| | |
|---|---|
| Cash and cash equivalents | 1,282 |
| Short-term investments | 2,628 |
| Goodwill | 189 |
| Operating assets | receivables 482, inventory 627, prepaid expenses 1,855, other 121 |
| Debt / capital leases | 404 / 302 |
| Operating liabilities | payables 1,039, accrued expenses 144, less 302 deferred tax asset offsets |
| Equity | 5,597 |

- The IPO column is net primary proceeds into cash and equity; post-money is the
  two added.
- Show total assets, and total liabilities and equity.

### Income statement (simplified)

- Return on cash invested 0%; tax rate 40%.
- D&A 323; EBIT 1,756; pre-money net interest income −42 − 19; pre-money tax
  −695; net income attributable to participating securities −332 (same pre and
  post); pre-money EPS 0.4.
- The IPO column adds return on the new cash at the assumed rate, plus its tax
  effect.
- Derive PBT, net income, **net income attributable to Class A and Class B
  common stockholders**, WASO and EPS, and include an **EPS accretion /
  dilution** line.

### Valuation, and ownership

- Valuation (pre / post): diluted NoSO, offer price — **hardcode 38** in the
  post-money column — implied equity value, net debt, implied enterprise value,
  pre-deal P/E, post-deal P/E, EV/EBITDA.
- Proforma ownership (all three columns): pre-deal shareholders including option
  holders, new shareholders, total shares, post-money ownership percentages.

### The four sensitivity grids

Each range has to be stated in full — the ends and the increment:

- **Analysis at various prices** — $34.00 to $42.00 in $2.00 increments, showing
  pre-deal P/E, post-deal P/E and EV/EBITDA, driven off the valuation section.
- **Shareholder dilution at different issuance of shares** — primary 160 to 200
  in increments of 10, secondary 211.2 to 281.2 in steps of 10, run against the
  pre-deal ownership percentage.
- **New money raised** — offer price $34.00 to $42.00 by $2.00 across, primary
  shares 160 to 200 by 10 down.
- **Proceeds to existing shareholders** — same price range across, secondary
  shares 211.2 to 281.2 by 10 down.

### Ground rules to close on

- Hardcodes in **#0000FF**, calculated values in black, **Arial 10pt**.
- Number formats and header fills consistent with the surrounding model — it
  gets screenshotted into the memo.

---

## 3 — Annual cashflows, four entities

**Situation.** A financing on a four-entity Egyptian real estate portfolio. The
lender's credit team won't work off the monthly tabs and has asked for annual
cashflow statements. The annual tabs already exist with the correct row
structure and section labels — only the numbers are missing, and they come from
aggregating the monthly data.

**Input:** `7.27_013_N-2.xlsx` · **Output:** `OUTPUT_WORKBOOK_-_TIBA.xlsx`

### What to ask for

- Annual cashflow statements for all four entities — **TIBA, Stone Park, Sahary
  and El-Rowad** — each on its own `CF - Annually` tab.
- Annual columns built by summing the monthly data in **eleven successive
  12-month blocks starting October 2020**, which covers the full 132-month grid
  end to end.
- Starting Balance, Total and Grand Total columns completed consistently with
  the existing layout.
- Row and section labels kept matching the monthly tabs — worth explaining why:
  credit will read the two side by side.
- All subtotal, total and net cashflow rows completed with the workbook's
  standard section logic, across every column type.

### The difference between the entities

This is the part that needs saying explicitly, because the four tabs are not
identical:

- **TIBA and Stone Park** have a cashflow from finance section — facility
  drawdown, facility repayment, interest expense, other fees — sourced from
  their monthly tabs. For these two, periodical net cashflows = net cash
  inflows/outflows **plus** net cashflows from finance.
- **Sahary and El-Rowad** have no finance section. For these two, periodical net
  cashflows = net cash inflows/outflows directly.

### Cash balance

- Complete the cash balance roll-forward on each tab.
- Populate the **Minimum Cash END Balance** field at the top of each tab — worth
  noting this is the covenant conversation.

### Client hardcodes — these can only come from you

- On **Sahary**: enter **0** for the Dues To Sister Companies line in the 2025
  and 2026 annual columns.
- On **TIBA and Sahary**: park a **60,000,000** memo figure in cell **AU40** —
  outside the reporting columns, and it shouldn't feed anything.

### Ground rules to close on

- Colors follow the monthly tabs: blue for typed hardcodes, **#008000** for
  links to other tabs, black for same-sheet calculations.

---

## 4 — SBA acquisition model and loan tabs

**Situation.** A real estate acquisition funded with SBA 504 and SBA 7(a)
financing, plus a refinance in year 5. The sponsor wants to know whether the LP
gets paid, which can't be answered until the debt is modelled.

**Input:** `7.20_016_N-2.xlsx` · **Output:** `7.20_016_N-1.xlsx`

### Assumptions tab

- Add a **year-number header row, 1 through 10**, above the Gross Revenue row,
  as the period index for the revenue/expense table.
- Add formulas for **Total Expenses** (salaries/wages plus other expenses),
  **OPEX Expense Ratio** (total expenses / gross revenue), and **NOI**.
- NOI must respect the **"Use Manual?"** switch: if yes, gross revenue × (1 −
  manual expense ratio); if no, gross revenue less actual total expenses.
- Loan sizing:
  - SBA 504 loan amount = SBA 504 % × RE Budget Total.
  - SBA 7(a) loan amount = SBA 7(a) % × Basis for 7a Loan Calc, where that basis
    = Total Funds − RE Budget Total.
  - REFI: **LTV Value** looks up NOI at the Refi Period year (using the year
    header row as the index) ÷ Cap Rate on Refi; **REFI Amount** = LTV × LTV
    Value. Worth explaining why it must be a lookup: the refi year will change.

### Sources and uses, and returns

- **Sources:** SBA 504 loan, SBA 7(a) loan, raised funds, total — pulled from
  the computed loan amounts and Required Raise.
- **Uses:** real estate purchase price, business purchase price, acquisition
  fee, gap funding, loan fees, legal, cash reserve, total. Loan fees and legal
  are label-only for now (no values yet); cash reserve is the residual so
  sources total equals uses total.
- **Returns block** below the deal terms: IRR and equity multiple for both LP
  and GP, plus a **Remaining LP Balance After REFI** label row (value linked
  later).

### Three new tabs

- **L1** = SBA 504 amortization, **L2** = SBA 7(a), **L3** = REFI. All on the
  General Loan Amortization layout; L3 additionally labelled **REFI** at the top.
- Parameter block at the top of each, pulling from the relevant Assumptions
  section: loan amount, start month of repayment, I/O period in months
  (Assumptions years × 12), end loan after I/O?, recast loan?, I/O rate,
  amortization period in years, term of loan in years, interest rate, payoff
  early?, start date, end date, and totals for **total interest** and **total
  principal repaid**.
- **Start month of repayment is hardcoded 1 on L1 and L2**; on L3 it's derived
  from the REFI section (refi period converted to a month number).

### The monthly schedules

- **400 rows** on each tab. Monthly interest = annual rate ÷ 12. Use **ROUNDUP**
  when converting remaining amortization years to months.
- Columns, in order — this list has to be given: year #, date, model month #,
  borrow amount, beginning balance, principal, balloon payment, exit repayment,
  extra principal, interest, interest rate, ending balance, repayment counter,
  amortization counter, offset (when extra principal happens), total principal,
  total debt payment, amortization payment (not recast), other reduction to
  principal, total principal, total interest, amortization only.
- **L1 differs:** two additional period-tracking columns before Date, and
  "Original Loan Month #" in place of "Model Month #".
- On **L1 and L2**: hardcode **0** in the extra principal input cells for the
  last four rows, months **397–400**.

### Ground rules to close on

- Hardcoded inputs **#0000FF**, same-sheet formulas black, cross-sheet links
  **#008000**.
- **Aptos Narrow 11** throughout the new sections; number formats and header
  fills consistent with the rest of the workbook.

---

## 5 — Cedarbrook AUM and revenue forecast

**Situation.** Diligence on Cedarbrook, an asset manager. Management's forecast
runs a single blended fee rate across every product, which won't survive
diligence — open-ended funds and institutional accounts don't earn the same
basis points. The fee rate needs building up from actual history, and the
forecast driven off that.

**Input:** `Model_v4_N-2.xlsx` · **Output:** `Model_v4_N-1__v2_.xlsx`

### AUM_Rollforward — extend it

- Section **(IV) Institutional Accounts** is missing its **Key Memo Item** block
  after the ending balance. Add it: four rows off that section's own rollforward
  — inflows % of BoP, outflows % of BoP, market performance % of BoP, other % of
  BoP.
- Add a **(V) Total** section aggregating all four product categories, with the
  same structure as the individual sections (beginning balance, inflows,
  outflows, net flows, market performance, other, ending balance), followed by
  the same four-metric Key Memo Item block.

### Revenue_Build — new tab

- A fee analysis schedule with a **"Fiscal Year Ended,"** date header covering
  the available fiscal year history.
- One section, **"(I) Fees by Avg AUM"**, with four sub-sections: (a) Open-Ended
  Funds, (b) Closed-End Funds, (c) Retail Separate Accounts, (d) Institutional
  Accounts.
- Three rows each: **Fees** (investment management fees from Revenue_Breakdown,
  in $'000s), **Avg AUM** (average of beginning and ending balances from
  AUM_Rollforward, in $mm), and **Avg Fees %** (the derived rate).
- Only populate columns where **both** beginning and ending AUM are available —
  worth explaining: a half-year denominator flatters the fee rate.

### Revenue_Forecast — new tab

- Same **"Fiscal Year Ended,"** header, plus a unit note reading **"(AUM in
  $mm, Revenue in $'000s)"**.
- Four product sections mirroring the rollforward categories: (I) Open-End
  Funds, (II) Closed-End Funds, (III) Retail Separate Accounts, (IV)
  Institutional Accounts.
- Each section contains:
  - an AUM rollforward — BoP AUM, net flows, market performance, other, EoP AUM;
  - a driver memo block labelled *[Product]* **AUM Drivers:** — net flows % of
    BoP, market performance % of BoP, other % of BoP;
  - an **Avg Fees** row;
  - a revenue line labelled *[Product]* **Revenue Inv. Mgmt Fees**, driven by
    period average AUM × avg fees %.
- **Historicals:** AUM from AUM_Rollforward, Avg Fees linked from Revenue_Build,
  driver percentages computed off the rollforward. **FY2022–FY2024** historical,
  **FY2025–FY2029** forecast.
- **Forecast:** drive AUM movements off BoP using a **rolling three-year
  trailing average** of each driver percentage — the window rolls forward and
  picks up prior forecast years, rather than freezing on the last three actuals.
  Carry Avg Fees forward on the same rolling basis.

### Ground rules to close on

- Calculated values in black, **Aptos Narrow 11** in the changed sections.
- Number formats and section header fills consistent with the existing workbook.
