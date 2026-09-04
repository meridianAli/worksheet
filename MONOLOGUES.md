# Five monologues

Training data. Each of the five tasks exported on 2026-09-04
(`tasksexport20260904.json`) is an input workbook, a build specification and an
output workbook. Below, each specification is spoken — one senior banker
briefing an analyst on the work, start to finish, uninterrupted.

Every script here passes [`run_tests.py`](README_TESTS.md): the input and output
workbooks are diffed cell by cell, and every change the analyst could not have
derived on their own — a typed value, a new tab, a metric the model did not
previously carry, a grid the senior chose the shape of — has to be in the
speech. Standard line items and the formulas behind a named deliverable are not
enforced, because no senior dictates those.

| # | Task | Input | Output | Cell changes | Enforced |
|---|---|---|---|---:|---:|
| 1 | `2266fdca` | `GD006_N-4.xlsx` | `GD006_N-3.xlsx` | 816 | 45 |
| 2 | `b68326d5` | `FIMR_N-1.xlsx` | `FIMR.xlsx` | 329 | 56 |
| 3 | `bb849b91` | `7.27_013_N-2.xlsx` | `OUTPUT_WORKBOOK_-_TIBA.xlsx` | 2,310 | 2 |
| 4 | `ef94a62b` | `7.20_016_N-2.xlsx` | `7.20_016_N-1.xlsx` | 27,450 | 52 |
| 5 | `fbe4760b` | `Model_v4_N-2.xlsx` | `Model_v4_N-1__v2_.xlsx` | 1,198 | 24 |

---

## 1 — Operating model off the assumptions sheet

`2266fdca` · in `GD006_N-4.xlsx` · out `GD006_N-3.xlsx`

---

Okay. QoE came in about four o'clock, which means the model goes in the data
room Monday morning. So — tonight, and probably most of tomorrow. Sorry.

Here's where we are. All you've got is the Assumptions sheet. Everything under
it got stripped out when we rebuilt the file last week and nobody put it back.
So you're building it back. Four tabs off that sheet — Enterprise P&L, Working
Capital, Debt Schedule, and an EBITDA Bridge, FY2024A into FY2025B. Full period on all
of them, FY2022A out to FY2030P.

And use what's in the book. Same units, same conventions, same look. Don't get
creative with the formatting at eight o'clock on a Thursday, it's a live
process.

Start with the P&L, everything else hangs off it. Run it down to net income.
Operating lines come off Assumptions, interest comes off the debt tab — which
won't exist yet, so just point at where it's going to be and it'll fill in.

Standard build. D&A, EBIT, then the QoE adjustments, adjusted EBITDA, interest,
other income and expense, tax, net income, margins down the side.

Two things you can't guess. First, non-operating other income — they gave it to
us, so it's typed. Write these down: 4.8, 4.8, 4.7, then 4.4, 3.9, 4.2, 4.3,
4.5, 4.7. FY2022A straight through FY2030P, nine years, in that order. Second,
tax only on positive pre-tax income — don't tax a loss year — and pull the
consolidated effective rate off Assumptions. Link it, don't retype it.

Working capital. 365-day basis.

DSO — 42.7 in FY2022A, 42.5 the next two years, then 42.0 from FY2025B and it's
flat the rest of the way. DIH steps down: 60.0, 52.0, 49.0, then 48.0 from
FY2025B on. DPO is 105.0, then 94.0, then 110.0 in FY2024A — leave that spike
alone, that's the year they stretched payables and it's half the cash story —
then back to 105.0 from FY2025B.

Rest of it's simple. Prepaids nil against opex. Accrued liabilities 10.0% of
opex. Deferred revenue nil.

Debt. Two tranches, and interest goes on the average of opening and closing
balance. Average, both of them, every year. Not the opening balance — that's the
first thing they check.

Term loan starts at 3.5 in FY2022A, amortizes 0.5 a year from FY2022A until it's
gone. Rate's zero in FY2022A and FY2023A — that is genuinely zero, it's not a
missing input, don't go looking for it — then 10.0% from FY2024A while there's
anything outstanding.

Revolver opens at 1.5. They pay down 0.5, 0.5, then 0.3 in FY2025B. Nothing
after that, no draws, no repayments, so you're left with 0.2 riding all the way
out to FY2030P. 10.0% on it the whole period.

Then the bridge. FY2024A EBITDA to FY2025B EBITDA — and understand, this is the
page the sponsor turns to first. Before the P&L. So it's formula-driven, all of
it. If I click into a step and find a hardcode we're doing it again.

Break out the three segments separately — Alpha, Beta, Gamma, revenue variance
on each. Everything else on the revenue side goes into one line, call it Other
Revenue Lines. Then the cost side: COGS, Customer Acquisition, Postal Charges,
Staff Costs, SG&A, Other OpEx.

Four columns — the component, the change in value period over period, the
running cumulative EBITDA as you walk down, and the component type.

Put a chart helper block underneath it. Base, increase, decrease, total, all
formula-driven, ready to plot. Someone's going to want that waterfall in a deck
by Sunday and I'm not building it twice.

And close it with a short summary block on the FY2024A to FY2025B walk — three
lines, starting EBITDA, total change, ending EBITDA.

Everything links back to Assumptions and to each other. Keep the color
convention — inputs, formulas, cross-sheet links, however the book already does
it. And tie it out before it comes to me. If the bridge doesn't foot to the
P&L, I'm not the one who finds out. The sponsor is.

---

## 2 — Cedarbrook Social IPO analysis

`b68326d5` · in `FIMR_N-1.xlsx` · out `FIMR.xlsx`

---

Cedarbrook Social — we're taking them out, and I need the pricing work in the
committee memo. Fair warning, committee will not take a single number on
anything, so everything gets a range around it.

Shell's already in the FIMR file. Fees and commissions, use 1.1% everywhere.

Start in the option holder table. Net shares on treasury stock method, then
total every column across. Don't leave one untotalled — that's the first thing
someone points at.

Sources and uses of funds next, and show it both ways, dollars in millions and
shares. Source of funds is the equity issued. Uses of funds are the primary shares — proceeds raised net
of fees — the primary underwriting fees, then the secondary shares, again
proceeds net of fees, and the secondary underwriting fees. Put a check total row
on it. I want to see it foot on the page.

From the balance sheet down through proforma ownership, everything's three
columns: pre money, IPO, post money. One exception, valuation — that's pre and
post only, no IPO column, it doesn't mean anything there.

Balance sheet, keep it simple. Cash 1,282, short-term investments 2,628,
goodwill 189. Operating assets are receivables 482, inventory 627, prepaids
1,855, other 121. Other side — debt 404, capital leases 302. Payables 1,039,
accrued 144, and then take out 302 of deferred tax asset offsets. Equity 5,597.
All of that's pre money. Your IPO column is just the net primary proceeds
landing in cash and in equity, and post money is the two added. Show total
assets, and total liabilities and equity.

Income statement, same idea. Return on cash invested is zero. Tax rate 40%. D&A
323, EBIT 1,756. Pre-money net interest income is negative 42 minus 19. Tax is
negative 695. Net income attributable to participating securities, negative 332
— and that one's the same pre and post, don't flex it. Pre-money EPS 0.4. In the
IPO column you're adding the return on the new cash at that rate, plus the tax
effect of it. Then derive down: PBT, net income, net income attributable to Class A and
Class B common stockholders, WASO, EPS. And give me an accretion-dilution line on the EPS at the
bottom.

Valuation, pre and post. Diluted NoSO, offer price — hardcode 38 in the post
column — implied equity value, net debt, implied enterprise value, pre-deal P/E,
post-deal P/E, EV/EBITDA.

Proforma ownership across all three columns. Pre-deal shareholders including the
option holders, new shareholders, total shares, and the post-money ownership
percentages.

Now the sensitivities. This is the part they actually read.

Analysis at various prices — run $34.00 to $42.00 in $2.00 steps, and off each
price show pre-deal P/E, post-deal P/E and EV/EBITDA. Drive it off the valuation
section, don't retype anything.

Shareholder dilution at different issuance of shares. Primary 160 to 200 by 10,
secondary 211.2 to 281.2 by 10, run against the pre-deal ownership percentage
out of the proforma section.

Then two more grids. New money raised — offer price $34.00 to $42.00 by $2.00
across the top, primary shares 160 to 200 by 10 down the side, every cell the
new money raised. And proceeds to existing shareholders, same prices across,
secondary 211.2 to 281.2 by 10 down, every cell the proceeds out to the existing
holders.

Formatting — hardcodes blue, #0000FF, calcs in black, Arial 10. Number formats
and header fills matching the rest of the book. This gets screenshotted straight
into the memo, so it has to look like it belongs.

---

## 3 — Annual cashflows, four entities

`bb849b91` · in `7.27_013_N-2.xlsx` · out `OUTPUT_WORKBOOK_-_TIBA.xlsx`

---

Lender's credit team came back this morning. They won't work off the monthly
tabs — they want annuals, all four entities. TIBA, Stone Park, Sahary,
El-Rowad, each on its own CF - Annually tab.

Good news is the tabs are already sitting there with the right rows and all the
section labels. What's missing is numbers, and the numbers come out of the
monthly cashflow data — you're aggregating, not rebuilding.

So on each tab, the annual columns are eleven blocks of twelve months, starting
October 2020. Eleven twelves — that's your full 132-month grid, covered end to
end, nothing dropped and nothing counted twice. Then the Starting Balance
column, the Total, the Grand Total, consistent with how the layout's already
set up. And keep the row and section labels matching the monthly tab, because
credit is going to sit these two side by side and anything that doesn't line up
becomes a phone call.

Subtotals, totals, net cashflow rows — all of them, standard section logic, and
across every column type, not just the annual ones.

Now, the entities aren't identical, so watch this. TIBA and Stone Park both
have a cashflow from finance section — drawdown, repayment, interest expense,
other fees — and that comes off their monthly tabs. For those two, periodical
net cashflows is net cash inflows and outflows plus the net cashflows from
finance. Sahary and El-Rowad have no finance section at all. For those two it's
just the net cash inflows and outflows, straight. Don't go building a finance
block where there isn't one.

Then the cash balance roll-forward on each tab, and fill in the minimum cash end
balance at the top. That number is the covenant conversation, so it needs to be
right and it needs to be where they expect to find it.

Couple of things coming from the client that you'd never guess. On Sahary, the
Dues To Sister Companies line — put a zero in the 2025 and the 2026 annual
columns. And on TIBA and on Sahary, park a 60,000,000 memo figure in AU40. Cell
AU40 specifically, both tabs, out past the reporting columns. It's a memo, it
shouldn't feed anything, they just want it visible.

Colors follow the monthly tabs. Blue for anything you type, green — #008000 —
for links to other tabs, black for same-sheet math.

---

## 4 — SBA acquisition model and loan tabs

`ef94a62b` · in `7.20_016_N-2.xlsx` · out `7.20_016_N-1.xlsx`

---

Real estate acquisition, SBA money — 504 and a 7(a) — plus a refi in year five.
The sponsor's question is just whether the LP gets paid, and I can't answer that
until the debt's actually modelled. So: wire up the Assumptions tab, then build
three loan tabs. L1, L2, L3.

Assumptions first, few things.

Put a year-number header row in, 1 through 10, above gross revenue. That's the
period index for the revenue and expense table — and you'll want it again in a
minute, so don't skip it.

Then the calcs. Total expenses is salaries and wages plus other expenses. OPEX
expense ratio is total expenses over gross revenue. NOI has to respect the "Use
Manual?" switch — if it's yes, gross revenue times one minus the manual expense
ratio; if no, gross revenue less the actual total expenses. Build both sides of
it, driven off the switch.

Loan sizing. SBA 504 amount is the 504 percentage times RE budget total. The
7(a) is the 7(a) percentage times the basis for 7a loan calc, and that basis is
total funds minus RE budget total. For the refi — LTV value, you look up NOI at
the refi period year using that year header row as your index, divided by the
cap rate on refi. Refi amount is LTV times LTV value. Look it up properly.
Second the sponsor asks what year six looks like, a hardcoded NOI falls over and
we're rebuilding it in front of him.

Next to the general assumptions block, two sections. Sources — 504 loan, 7(a)
loan, raised funds, total, pulled off the loan amounts you just built and off
required raise. Uses — real estate purchase price, business purchase price,
acquisition fee, gap funding, loan fees, legal, cash reserve, total. Loan fees
and legal are label only for now, we don't have numbers, leave the rows in. Cash
reserve is your plug so sources total equals uses total.

Under the deal terms, a returns block — IRR and equity multiple, LP and GP both.
And put a remaining LP balance after refi row in there. No value yet, we link
that once the refi tab exists.

Now the tabs. L1 is the 504, L2 is the 7(a), L3 is the refi. All three on the
general loan amortization layout, and put REFI at the top of L3 so nobody
mistakes it for a third original loan.

Parameter block at the top of each, pulling from the relevant assumptions
section — loan amount, start month of repayment, I/O period in months, which is
the assumptions years times twelve, end loan after I/O, recast loan, I/O rate,
amortization period in years, term of loan in years, interest rate, payoff
early, start date, end date. And totals for total interest and total principal
repaid.

Start month of repayment is a hardcoded 1 on L1 and L2. On L3 you derive it —
take the refi period off the assumptions section and convert it to a month
number.

Under that, four hundred rows of monthly schedule on each tab. Monthly interest
is the annual rate over twelve. And use ROUNDUP anywhere you're taking remaining
amortization years into months.

Columns, and there are a lot of them, so take this down. Year number. Date.
Model month number. Borrow amount. Beginning balance. Principal. Balloon
payment. Exit repayment. Extra principal. Interest. Interest rate. Ending
balance. Repayment counter. Amortization counter. Offset — that's when extra
principal happens. Total principal. Total debt payment. Amortization payment,
not recast. Other reduction to principal. Total principal again. Total interest.
Amortization only.

L1's the odd one. It carries two extra period-tracking columns ahead of the date
column, and it says original loan month number instead of model month number.
And on L1 and L2 both, hardcode a zero into the extra principal input for the
last four rows — months 397 through 400.

Formatting. Typed inputs blue, #0000FF. Same-sheet formulas black. Cross-sheet
links green, #008000. Aptos Narrow 11 through the new sections, number formats
and header fills consistent with the rest of the book.

---

## 5 — Cedarbrook AUM and revenue forecast

`fbe4760b` · in `Model_v4_N-2.xlsx` · out `Model_v4_N-1__v2_.xlsx`

---

Cedarbrook. I need the AUM and revenue forecast infrastructure built out, and
the reason is management's running one blended fee rate across every product,
which is not going to survive diligence — open-ended funds and institutional
money have never earned the same basis points and everyone in that room knows
it. So we build the rate up off actual history and forecast from there.

Three pieces. Extend AUM_Rollforward, then two new tabs, Revenue_Build and
Revenue_Forecast.

On AUM_Rollforward — section four, institutional accounts, is missing its key
memo item block under the ending balance. Add it. Four rows off that section's
own rollforward: inflows as a percent of BoP, outflows percent of BoP, market
performance percent of BoP, other percent of BoP.

Then add a section five, total, aggregating all four product categories. Same
structure as the individual sections — beginning balance, inflows, outflows, net
flows, market performance, other, ending balance — and give it the same key memo
item block underneath with those same four percent of BoP metrics.

Revenue_Build is new. It's the fee analysis, and it's the piece that answers the
blended-rate problem. Date header, "Fiscal Year Ended," across whatever fiscal
year history we've got. One section in the body, call it "(I) Fees by Avg AUM",
and under it four sub-sections — open-ended funds, closed-end funds, retail
separate accounts, institutional accounts.

Three rows each. Fees, which is investment management fees out of
Revenue_Breakdown, in thousands. Avg AUM, which is the average of beginning and
ending balances off AUM_Rollforward, in millions. And avg fees percent, the
derived rate. One rule — only populate a column where you've got both the
beginning and the ending AUM. If you've only got one end of it, leave the column
alone. A half-year denominator flatters the fee rate and somebody on the other
side will find it.

Revenue_Forecast, also new. Same "Fiscal Year Ended," header, and a unit note on
it reading "(AUM in $mm, Revenue in $'000s)". Four product sections mirroring
the rollforward categories — open-end funds, closed-end funds, retail separate
accounts, institutional accounts.

Each section, same shape. AUM rollforward first: BoP AUM, net flows, market
performance, other, EoP AUM. Then a driver memo block, labeled with the product
name and "AUM Drivers:" — net flows percent of BoP, market performance percent
of BoP, other percent of BoP. Then an avg fees row. Then the revenue line,
labeled with the product name and "Revenue Inv. Mgmt Fees", driven off period
average AUM times avg fees percent.

Historicals: AUM comes off AUM_Rollforward, avg fees link from Revenue_Build,
and the percent of BoP drivers you compute off the rollforward figures. FY2022
through FY2024 is history, FY2025 through FY2029 is forecast.

Forecast periods — drive the AUM movements off BoP on a rolling three-year
trailing average of each driver percentage. Rolling, so once you're into the
forecast the window picks up the prior forecast years. Don't freeze it on the
last three actuals, that's a different model and it'll drift. Avg fees carry
forward on the same rolling three-year basis.

Calcs in black, Aptos Narrow 11 in whatever you touch, number formats consistent
with the model around it, header fills consistent with the existing style.
