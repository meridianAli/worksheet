# Five monologues

Training data. Each of the five tasks exported on 2026-09-04
(`tasksexport20260904.json`) is an input workbook, a build specification and an
output workbook. Below, each specification is spoken — one senior banker
briefing an analyst on the work, start to finish, uninterrupted.

No staging, no character names, no back-and-forth. Just what gets said.

Every figure, rate, day count, range, font and color rule from the original
specification is in the speech. The output workbook only ties out if they all
survive, so none of them were dropped or rounded off.

| # | Task id | Input workbook | The build |
|---|---|---|---|
| 1 | `2266fdca` | `GD006_N-4.xlsx` | P&L, working capital, debt schedule, EBITDA bridge |
| 2 | `b68326d5` | `FIMR_N-1.xlsx` | IPO sources & uses, pro forma balance sheet, valuation, dilution grids |
| 3 | `bb849b91` | `7.27_013_N-2.xlsx` | Annual cashflow statements, four entities |
| 4 | `ef94a62b` | `7.20_016_N-2.xlsx` | SBA sources & uses, returns, three amortization tabs |
| 5 | `fbe4760b` | `Model_v4_N-2.xlsx` | AUM rollforward, fee build, five-year revenue forecast |

---

## 1 — Operating model off the assumptions sheet

`2266fdca` · in `GD006_N-4.xlsx` · out `GD006_N-3.xlsx`

---

The QoE came back this afternoon and management wants the full operating model
in the data room Monday, so this is tonight and probably tomorrow.

What you've got is the Assumptions sheet. That's it — everything downstream got
stripped when we rebuilt the file, so you're building it back. Four tabs off
that sheet, FY2022A through FY2030P, every one of them running the full nine
years. Enterprise P&L, Working Capital, Debt Schedule, and an EBITDA bridge from
FY2024A to FY2025B.

Use the structure that's already in the book. Same units, same formatting
conventions. Don't reinvent the house style in the middle of a live process —
whatever the Assumptions sheet does, you do.

Start with the P&L, because everything else hangs off it. Run it through Net
Income. Operating assumptions link back to the Assumptions sheet. Debt interest
links forward to the Debt Schedule — build the shell, point at it, it'll fill in
when you get there.

Lines you need, in order: Depreciation and Amortization, Operating Income —
that's your EBIT line — then the QoE adjustments, Adjusted EBITDA, Interest
Expense, Other Income and Expense, Tax Expense, Net Income. Margins alongside
all the way down.

Non-operating other income is given to us, so hardcode it: 4.8, 4.8, 4.7, 4.4,
3.9, 4.2, 4.3, 4.5, 4.7. That's FY2022A through FY2030P in order, nine numbers,
nine years.

Tax on positive pre-tax income only — don't tax a loss year — and use the
consolidated effective rate that's sitting on the Assumptions sheet. Don't type
the rate in again somewhere else, link it.

Working capital next. 365-day basis throughout.

DSO is 42.7 days in FY2022A, 42.5 in FY2023A and again in FY2024A, then 42.0
from FY2025B onward and it holds flat out to FY2030P.

DIH is 60.0 in FY2022A, 52.0 in FY2023A, 49.0 in FY2024A, then 48.0 from FY2025B
onward.

DPO is 105.0 in FY2022A, 94.0 in FY2023A, 110.0 in FY2024A, then back to 105.0
from FY2025B onward. The 110 in FY2024A is real — that's the year they stretched
payables. Don't smooth it, it's part of the story we're telling on cash.

Prepaids are 0.0% of operating expenses. Accrued liabilities, 10.0% of operating
expenses. Deferred revenue, 0.0% of revenue.

Debt schedule. Two tranches, and interest is calculated on the average of the
beginning and ending balances. Average, both tranches, every year — not on the
opening balance. That gets checked.

Term loan opens at 3.5 in FY2022A. Mandatory repayments of 0.5 a year starting
in FY2022A, and they run until it's fully repaid. Rate is 0.0% in FY2022A and
FY2023A — that's actually zero, it's not a missing input — then 10.0% from
FY2024A onward for as long as there's a balance outstanding.

Line of credit opens at 1.5 in FY2022A. Repayments of 0.5 in FY2023A, 0.5 in
FY2024A, 0.3 in FY2025B. After that, assume no further draws and no further
repayments, so 0.2 stays outstanding all the way through FY2030P. 10.0% on it
throughout, FY2022A to FY2030P, the whole period.

Then the bridge, FY2024A EBITDA to FY2025B EBITDA. This is the page the sponsor
turns to first, ahead of the P&L, so it needs to be formula-driven the whole
way. If I click into a step of that walk and find a typed number, we're doing it
again.

Separate variance step for each of these: Segment Alpha revenue, Segment Beta
revenue, Segment Gamma revenue, then everything else on the revenue side
combined into a single line called "Other Revenue Lines" — use those words. Then
COGS, Customer Acquisition, Postal Charges, Staff Costs, SG&A, and Other OpEx.

Columns are the component, the period-over-period change in value, the running
cumulative EBITDA as you walk down, and the component type.

Under that, put in a helper block for the waterfall chart — Base, Increase,
Decrease, Total — formula-driven as well, ready to plot. Somebody's going to
want that chart in a deck this weekend and I don't want it built twice.

And close it out with three lines: starting EBITDA, total change, ending EBITDA.

Everything links — to the Assumptions sheet and to each other. Keep the color
convention the book already uses: typed inputs one color, formulas another,
cross-sheet links a third. And tie it out before it comes back to me. If the
bridge doesn't foot to the P&L, I'm not the one who finds that out, the sponsor
is.

---

## 2 — Cedarbrook Social IPO analysis

`b68326d5` · in `FIMR_N-1.xlsx` · out `FIMR.xlsx`

---

I'm building out the IPO analysis for Cedarbrook Social and I need the pricing
work done properly, because this goes in front of committee and they are not
going to accept a single point estimate on anything.

The shell's in the FIMR file. Fees and commissions run at 1.1% — that's your
rate everywhere fees come up.

Start in the option holder table. Calculate net shares using the treasury stock
method, then total every column. Don't leave a column untotalled, they'll ask.

Then build the sections out.

Sources and uses of funds, shown in both dollars in millions and in shares. The
source is the equity issued. The uses are primary shares — that's proceeds
raised net of fees — primary shares underwriting fees, secondary shares again
net of fees, and secondary shares underwriting fees. Put a check total row in.
I want to see it foot on the page, not take it on faith.

Everything from the Balance Sheet through Pro Forma Ownership gets three
columns: pre-money, IPO, post-money. The one exception is Valuation — that gets
pre-money and post-money only, no IPO column.

Balance sheet, simplified. Pre-money cash and cash equivalents is 1,282,
short-term investments 2,628. Goodwill 189. Operating assets are accounts
receivable of 482, inventory 627, prepaid expenses 1,855, and other operating
assets 121. On the other side, debt is 404 and capital leases 302. Operating
liabilities are accounts payable 1,039, accrued expenses 144, and then deduct
302 of deferred tax asset offsets. Equity 5,597. The IPO column is the net
primary proceeds landing in cash and in equity, and post-money is just the two
columns added. Show total assets, and show total liabilities and equity.

Income statement, also simplified. Return on cash invested is 0%. Tax rate 40%.
D&A 323, EBIT 1,756. Pre-money net interest income is negative 42 minus 19.
Pre-money tax is negative 695. Net income attributable to participating
securities is negative 332 in both pre-money and post-money. Pre-money EPS 0.4.
The IPO column adds the return on the new cash at the assumed rate, and the tax
effect of it. From there derive PBT, net income, net income attributable to
Class A and Class B common stockholders, WASO, and EPS. And give me an EPS
accretion-dilution line at the bottom.

Valuation, pre-money and post-money. Diluted NoSO, offer price — hardcode 38 in
the post-money column — implied equity value, net debt, implied enterprise
value, pre-deal P/E, post-deal P/E, and EV over EBITDA.

Pro forma ownership across pre-money, IPO and post-money. Pre-deal shareholders
including the option holders, new shareholders, total shares, and the post-money
ownership percentages.

Now the sensitivities, and this is the part committee actually reads.

Analysis at various prices. Offer price range from $34.00 to $42.00 in $2.00
increments. For each price show pre-deal P/E, post-deal P/E and EV/EBITDA,
driven off the valuation section — not retyped.

Shareholder dilution at different share issuance. Primary shares from 160 to 200
in increments of 10. Secondary shares from 211.2 to 281.2 in steps of 10. Run it
against the pre-deal ownership percentage from the pro forma section.

New money raised. Offer prices $34.00 to $42.00 in $2.00 increments across the
top, primary shares 160 to 200 in increments of 10 down the side. Every cell
calculates the new money raised.

Proceeds to existing shareholders. Same offer price range. Secondary shares
211.2 to 281.2 in steps of 10. Every cell calculates the proceeds to the
existing holders.

On formatting — hardcoded inputs in blue, #0000FF. Calculated values in black.
Arial 10 point. Number formats and header fills consistent with the surrounding
model. This gets screenshotted straight into the committee memo, so it has to
look like the rest of the book.

---

## 3 — Annual cashflows, four entities

`bb849b91` · in `7.27_013_N-2.xlsx` · out `OUTPUT_WORKBOOK_-_TIBA.xlsx`

---

The lender's credit team came back this morning and they won't work off the
monthly tabs. They want annuals. So I need the annual cashflow statements built
out for all four entities — TIBA, Stone Park, Sahary and El-Rowad — each on its
own CF - Annually tab.

The good news is the tabs are already there with the right row structure and the
section labels in place. What's missing is the numbers, and those come from
aggregating each entity's monthly cashflow data into annual period columns.

For each tab, populate the annual period columns by summing the monthly data in
eleven successive 12-month blocks starting October 2020. Eleven blocks of twelve
— that covers the full 132-month monthly grid end to end, with nothing left over
and nothing double-counted. Then complete the Starting Balance, Total and Grand
Total columns consistently with the layout that's already there. Keep the row
and section labels matching the corresponding monthly tab, because credit is
going to read the two side by side and anything that doesn't line up becomes a
question.

Complete every subtotal, total and net cashflow row using the workbook's
standard cashflow section logic, and do it across all the column types, not just
the annual ones.

Watch the finance sections, because the entities aren't the same. TIBA and Stone
Park both have a Cashflow from Finance section — Facility Drawdown, Facility
Repayment, Interest Expense and Other Fees — sourced off their monthly tabs. For
those two, Periodical Net Cashflows is Net Cash Inflows and Outflows plus Net
Cashflows from Finance. Sahary and El-Rowad have no finance section at all, so
for those two Periodical Net Cashflows is just Net Cash Inflows and Outflows
directly. Don't build a finance block where there isn't one.

Complete the cash balance roll-forward on each tab, and populate the Minimum
Cash END Balance field at the top. That figure is the covenant conversation, so
it needs to be right and it needs to be visible where they expect it.

Two hardcodes coming from the client side. On the Sahary CF - Annually tab,
enter 0 for the Dues To Sister Companies line in the 2025 and 2026 annual
columns. And on both the TIBA and the Sahary annual tabs, park a 60,000,000 memo
figure in cell AU40 — that's outside the reporting columns, it's a memo, it
shouldn't feed anything.

Formatting follows the monthly tabs. Blue for typed hardcodes, #008000 green for
links to other tabs, black for same-sheet calculations.

---

## 4 — SBA acquisition model and loan tabs

`ef94a62b` · in `7.20_016_N-2.xlsx` · out `7.20_016_N-1.xlsx`

---

I'm building out a real estate acquisition model — SBA 504 and SBA 7(a)
financing, plus a refinance in year 5. The sponsor's question is whether the LP
gets paid, and I can't answer that until the debt is actually modelled. So I
need the Assumptions tab wired up and three new monthly loan amortization tabs
built: L1, L2 and L3.

Assumptions tab first, a few things to wire.

Add a year-number header row, 1 through 10, above the Gross Revenue row. That's
the period index for the revenue and expense table, and you'll use it again
later so don't skip it.

Then formulas for Total Expenses, which is Salaries and Wages plus Other
Expenses; OPEX Expense Ratio, which is Total Expenses over Gross Revenue; and
NOI. NOI has to respect the "Use Manual?" switch — if it's Yes, NOI is Gross
Revenue times one minus the Manual Expense Ratio; if it's No, it's Gross Revenue
less the actual Total Expenses. Both paths, driven off the switch.

SBA 504 Loan Amount is the SBA 504 percentage times RE Budget Total. SBA 7(a)
Loan Amount is the SBA 7(a) percentage times the Basis for 7a Loan Calc, and
that basis is Total Funds minus RE Budget Total.

For the REFI scenario, compute LTV Value by looking up NOI at the Refi Period
year — use that year header row as the index — and dividing by the Cap Rate on
Refi. Then REFI Amount is LTV times LTV Value. Look it up properly. The moment
the sponsor asks what year 6 looks like instead of year 5, a hardcoded NOI
falls over.

Alongside the General Assumptions block, add two sections.

Sources: SBA 504 Loan, SBA 7(a) Loan, Raised Funds, and Total. Pull the amounts
from the loan amounts you just computed and from Required Raise.

Uses: Real Estate Purchase Price, Business Purchase Price, Acquisition Fee, Gap
Funding, Loan Fees, Legal, Cash Reserve, and Total. Loan Fees and Legal are
label only for now, no values — leave the rows in, we'll get numbers later. Cash
Reserve is the residual, so that Sources Total equals Uses Total.

Below the deal terms section, add a Returns block — IRR and Equity Multiple for
both LP and GP. And put a Remaining LP Balance After REFI label row in that same
area. No value on it yet, that gets linked once the refi tab exists.

Now the three tabs. L1 is the SBA 504 amortization, L2 is the SBA 7(a), L3 is
the REFI. All three follow the General Loan Amortization layout, and L3
additionally gets labeled REFI at the top so nobody mistakes it for a third
original loan.

Parameter block at the top of each tab, pulling from the relevant Assumptions
section: Loan Amount, Start Month of Repayment, I/O Period in months — that's
the Assumptions years times 12 — End loan after I/O?, Recast Loan?, I/O Rate,
Amortization Period in years, Term of Loan in years, Interest Rate, Payoff
Early?, Start Date, End Date, and then summary totals for Total Interest and
Total Principal Repaid.

Start Month of Repayment is hardcoded as 1 on L1 and on L2. On L3 you derive it
from the REFI section on Assumptions — take the Refi Period and convert it to a
month number.

Below the parameter block, build a 400-row monthly schedule on each tab. Monthly
interest is the annual rate divided by 12. Use ROUNDUP when you're converting
remaining amortization years into months.

Columns per row: Year number, Date, Model Month number, Borrow Amount, Beginning
Balance, Principal, Balloon Payment, Exit Repayment, Extra Principal, Interest,
Interest Rate, Ending Balance, Repayment Counter, Amortization Counter, Offset —
that's when extra principal happens — Total Principal, Total Debt Payment,
Amortization Payment not recast, Other Reduction to Principal, Total Principal
again, Total Interest, and Amortization Only.

L1 is slightly different. It carries two additional period-tracking columns
before Date, and it uses "Original Loan Month #" instead of "Model Month #".
And on both L1 and L2, hardcode 0 in the Extra Principal input cells for the
last four rows of the schedule — months 397 through 400.

Formatting. Hardcoded input values in blue, #0000FF. Same-sheet formula outputs
in black. Cross-sheet formula links in green, #008000. Aptos Narrow size 11
throughout the new sections, with number formats and section header fills
consistent with the rest of the workbook.

---

## 5 — Cedarbrook AUM and revenue forecast

`fbe4760b` · in `Model_v4_N-2.xlsx` · out `Model_v4_N-1__v2_.xlsx`

---

I'm building out the AUM and revenue forecast infrastructure for Cedarbrook.
Management's forecast runs one blended fee rate across every product, and that
is not going to survive diligence — open-ended funds and institutional accounts
have never earned the same basis points. So we build the fee rate up from the
actual history and forecast off that.

Three areas. Extend the AUM_Rollforward tab, create a Revenue_Build tab, create
a Revenue_Forecast tab.

On AUM_Rollforward: the section (IV) Institutional Accounts is missing its Key
Memo Item block after the Ending Balance. Add it — four rows, calculated off
that section's own rollforward data: Inflows as a percent of BoP, Outflows
percent of BoP, Market Performance percent of BoP, and Other percent of BoP.

Then add a (V) Total section that aggregates all four product categories, same
structure as the individual sections — Beginning Balance, Inflows, Outflows, Net
Flows, Market Performance, Other, Ending Balance — and give it a Key Memo Item
block underneath with the same four percent-of-BoP metrics.

Revenue_Build is a new tab. It's a fee analysis schedule. Date header reading
"Fiscal Year Ended," covering the fiscal year history we have. One section in
the body, titled "(I) Fees by Avg AUM", with four sub-sections: (a) Open-Ended
Funds, (b) Closed-End Funds, (c) Retail Separate Accounts, (d) Institutional
Accounts.

Each sub-section is three rows. Fees — that's Investment Management Fees pulled
from Revenue_Breakdown, in thousands. Avg AUM — the average of the beginning and
ending AUM balances from AUM_Rollforward, in millions. And Avg Fees percent,
which is the derived average fee rate. Only populate a column where you have
both the beginning and the ending AUM. If you only have one end of it, leave the
column empty — a half-year denominator flatters the fee rate and somebody will
catch it.

Revenue_Forecast, also a new tab. Same "Fiscal Year Ended," date header, and a
unit note reading "(AUM in $mm, Revenue in $'000s)". Four product sections
mirroring the AUM_Rollforward categories: (I) Open-End Funds, (II) Closed-End
Funds, (III) Retail Separate Accounts, (IV) Institutional Accounts.

Each section holds an AUM rollforward — BoP AUM, Net Flows, Market Performance,
Other, EoP AUM. Then a driver memo block labeled with the product name and "AUM
Drivers:" carrying Net Flows percent of BoP, Market Performance percent of BoP,
and Other percent of BoP. Then an Avg Fees row. Then a revenue summary line
labeled with the product name and "Revenue Inv. Mgmt Fees", driven off the
period average AUM and the Avg Fees percent.

For the historical periods, source AUM from AUM_Rollforward, link Avg Fees from
Revenue_Build, and compute the percent-of-BoP driver rows off the rollforward
figures. FY2022 through FY2024 are the historical periods. FY2025 through FY2029
are forecast.

For the forecast periods, drive the AUM movements off BoP using a rolling
three-year trailing average of each driver percentage. The window rolls
forward, so once you're into the forecast it starts including prior forecast
years — it isn't frozen on the last three actuals. Carry Avg Fees forward on
that same rolling three-year basis.

Formatting: calculated values in black, Aptos Narrow size 11 in the sections you
change, number formats consistent with the surrounding model, and section header
fills consistent with the existing workbook style.
