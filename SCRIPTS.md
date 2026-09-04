# Five briefing scripts

Training data. Each of the five tasks exported on 2026-09-04
(`tasksexport20260904.json`) is an input workbook, a build specification and an
output workbook. Below, each specification is spoken — one senior banker
briefing an analyst on the work, start to finish, uninterrupted.

Every script is checked two ways. It has to **cover the work**: the input and
output workbooks are diffed cell by cell, and anything the analyst could not
have derived on their own — a given figure, a new tab, a stated range, a metric
the model did not previously carry — has to be in the speech. And it has to
**be English**: every sentence carries a verb, which the first draft of these
did not.

| # | Task | Input | Output | Cell changes | Enforced |
|---|---|---|---|---:|---:|
| 1 | `2266fdca` | `GD006_N-4.xlsx` | `GD006_N-3.xlsx` | 816 | 45 |
| 2 | `b68326d5` | `FIMR_N-1.xlsx` | `FIMR.xlsx` | 329 | 57 |
| 3 | `bb849b91` | `7.27_013_N-2.xlsx` | `OUTPUT_WORKBOOK_-_TIBA.xlsx` | 2,310 | 2 |
| 4 | `ef94a62b` | `7.20_016_N-2.xlsx` | `7.20_016_N-1.xlsx` | 27,450 | 52 |
| 5 | `fbe4760b` | `Model_v4_N-2.xlsx` | `Model_v4_N-1__v2_.xlsx` | 1,198 | 24 |

---

## 1 — Operating model off the assumptions sheet

`2266fdca` · in `GD006_N-4.xlsx` · out `GD006_N-3.xlsx`

---

Let me walk you through what I need on the distributor model, because it's a
lot and I'd rather you heard all of it before you start.

The quality-of-earnings report came back this afternoon, and the sponsor wants
the full operating model in the data room by Monday morning. That means we're on
this tonight and probably most of tomorrow.

Right now the only thing in that workbook is the Assumptions sheet. Everything
underneath it was stripped out when we rebuilt the file last week and nobody put
it back, so you're building it again from scratch. I need four tabs off that
sheet: an Enterprise P&L, a Working Capital schedule, a Debt Schedule, and an
EBITDA Bridge that walks FY2024A into FY2025B. All four should run the full
period, FY2022A through FY2030P.

Please use the conventions that are already in the book — the same units, the
same formatting, the same way it lays out a schedule. This is a live process and
nobody has the time to learn a new house style tonight.

I'd start with the P&L, because everything else hangs off it. Run it down to net
income. The operating assumptions should link back to the Assumptions sheet, and
the interest should link forward to the Debt Schedule. That tab won't exist when
you begin, so just point the formula at where it's going to sit and it will fill
in when you get there.

The lines I want to see are depreciation and amortization, operating income,
which is your EBIT line, then the QoE adjustments, adjusted EBITDA, interest
expense, other income and expense, tax expense and net income, with the margins
running down the side.

There are two things in there you can't work out for yourself, so let me give
them to you. The first is non-operating other income, which the company handed
us, so it gets typed in. The nine numbers are 4.8, 4.8, 4.7, 4.4, 3.9, 4.2, 4.3,
4.5 and 4.7, and they run FY2022A through FY2030P in that order. The second is
tax: only tax positive pre-tax income, so a loss year doesn't get taxed, and use
the consolidated effective rate that's already sitting on the Assumptions sheet.
Link to it rather than typing it in again.

The working capital schedule runs on a 365-day basis, and I'll give you the day
counts now. Days sales outstanding is 42.7 in FY2022A, then 42.5 in both FY2023A
and FY2024A, then 42.0 from FY2025B onward, and it stays flat from there. Days
inventory on hand steps down through the actuals: it's 60.0, then 52.0, then
49.0, and it settles at 48.0 from FY2025B. Days payable outstanding is 105.0,
then 94.0, then 110.0 in FY2024A, and then it comes back to 105.0 from FY2025B.

I want to flag that 110 in FY2024A, because it looks like an error and it isn't.
That's the year they stretched their payables, it's a real part of the cash
story, and it should not be smoothed out. The rest of the schedule is
straightforward: prepaids are nothing against operating expenses, accrued
liabilities are 10.0% of operating expenses, and deferred revenue is nothing
against revenue.

On the debt schedule there are two tranches, and I want the interest calculated
on the average of the beginning and ending balances rather than on the opening
balance. That applies to both tranches in every year, and it's the first thing
the other side will check.

The term loan opens at 3.5 in FY2022A and amortizes at 0.5 a year from FY2022A
until it's fully repaid. The rate is 0.0% in FY2022A and FY2023A — that really
is zero, it isn't an input somebody forgot — and then it's 10.0% from FY2024A
onward for as long as there's a balance outstanding.

The line of credit opens at 1.5 in FY2022A. They repay 0.5 in FY2023A, another
0.5 in FY2024A, and 0.3 in FY2025B. After that you should assume there are no
further draws and no further repayments, which leaves 0.2 sitting there
outstanding all the way through FY2030P. The rate on it is 10.0% for the whole
period.

That brings me to the bridge, which walks FY2024A EBITDA into FY2025B EBITDA. I
want to be clear that this is the page the sponsor turns to before he looks at
anything else, so every step of it has to be formula-driven. If I click into one
of those steps and find a number somebody typed, we'll be rebuilding it.

Give me a separate variance step for Segment Alpha revenue, Segment Beta revenue
and Segment Gamma revenue, and then combine everything else on the revenue side
into a single line called "Other Revenue Lines". After that, step through the
cost side: COGS, Customer Acquisition, Postal Charges, Staff Costs, SG&A and
Other OpEx.

The columns I want are the component itself, the change in value period over
period, the running cumulative EBITDA as you walk down, and the component type.

Underneath that, please build a chart helper block with Base, Increase, Decrease
and Total columns, all formula-driven and ready to plot as a waterfall. Somebody
is going to ask for that chart in a deck this weekend and I don't want it built
twice. Then close the tab with a short summary block on the FY2024A to FY2025B
walk, showing starting EBITDA, the total change and ending EBITDA.

Everything should link back to the Assumptions sheet and to the other schedules.
Keep the color convention the book already uses, so typed inputs, formulas and
cross-sheet links each stay in their own color. And please make sure it ties out
before it comes back to me, because if the bridge doesn't foot to the P&L, I'm
not the one who's going to find it. The sponsor is.

---

## 2 — Cedarbrook Social IPO analysis

`b68326d5` · in `FIMR_N-1.xlsx` · out `FIMR.xlsx`

---

I want to take you through the pricing analysis for Cedarbrook Social, because
this one goes in front of the IPO committee and they won't accept a single
number on anything. Everything we show them needs a range around it.

The shell is already built in the FIMR file, so you're filling it in rather than
starting from nothing. Use 1.1% as the fees and commissions rate everywhere it
comes up.

Start in the option holder table. I need the net shares calculated on the
treasury stock method, and then every column totalled. Please don't leave one
without a total, because that's the first thing somebody points at.

Next is the sources and uses of funds, and I'd like it shown both in dollars in
millions and in shares. The source of funds is the equity issued. The uses of
funds are the primary shares, which is the proceeds raised net of fees, the
primary shares underwriting fees, the secondary shares, again net of fees, and
the secondary shares underwriting fees. Put a check total row in as well,
because I want to see it foot on the page rather than take it on trust.

From the balance sheet all the way down through the proforma ownership section,
every section gets three columns: pre money, IPO and post money. Valuation is
the one exception. That gets pre money and post money only, because an IPO
column there doesn't mean anything.

The balance sheet is a simplified one and I'll give you the pre-money figures
now. Cash and cash equivalents are 1,282 and short-term investments are 2,628.
Goodwill is 189. The operating assets are accounts receivable of 482, inventory
of 627, prepaid expenses of 1,855 and other operating assets of 121. On the
other side, debt is 404 and capital leases are 302. The operating liabilities
are accounts payable of 1,039 and accrued expenses of 144, and then you deduct
302 of deferred tax asset offsets. Equity is 5,597.

The IPO column on that section is just the net primary proceeds landing in cash
and in equity, and post money is the two columns added together. Please show
total assets, and total liabilities and equity.

The income statement is simplified in the same way. Assume the return on cash
invested is 0% and the tax rate is 40%. Depreciation and amortization is 323 and
EBIT is 1,756. Pre-money net interest income is negative 42 minus 19, and
pre-money tax is negative 695. Net income attributable to participating
securities is negative 332, and that figure is the same pre money and post
money. Pre-money EPS is 0.4.

In the IPO column you're adding the return on the new cash at the rate we
assumed, along with the tax effect of it. From there, derive profit before tax,
net income, net income attributable to Class A and Class B common stockholders,
WASO — the weighted average shares outstanding — and EPS. I'd also like an EPS accretion
and dilution line at the bottom of that section.

The valuation section runs pre money and post money, and I want to see the diluted
NoSO, the offer price, which you should hardcode at 38 in the post
money column, the implied equity value, net debt, the implied enterprise value,
the pre-deal and post-deal price-earnings multiples, and EV to EBITDA.

Proforma ownership runs across all three columns and should show the pre-deal
shareholders including the option holders, the new shareholders, the total
shares, and the post-money ownership percentages.

Then there are four sensitivity grids, and this is the part the committee
actually reads, so let me give you each range in full.

The first is the analysis at various prices. Run the offer price from $34.00 to
$42.00 in $2.00 increments, and for each price show the pre-deal
price-earnings, the post-deal price-earnings and EV to EBITDA. Drive all of that
off the valuation section rather than retyping any of it.

The second is shareholder dilution at different issuance of shares. Run the
primary shares from 160 to 200 in increments of 10 and the secondary shares from
211.2 to 281.2 in steps of 10, and run it against the pre-deal ownership
percentage out of the proforma section.

The third is the new money raised. Put the offer price from $34.00 to $42.00 in
$2.00 increments across the top and the primary shares from 160 to 200 in
increments of 10 down the side, and have every cell calculate the new money
raised.

The fourth is the proceeds to existing shareholders. Use that same $34.00 to
$42.00 range in $2.00 increments across the top, with the secondary shares from 211.2 to 281.2 in steps of
10 down the side, and every cell should calculate the proceeds going to the
existing holders.

On formatting, please put the hardcodes in blue, #0000FF, and leave the
calculated values in black, all in Arial 10 point. Keep the number formats and
the header fills consistent with the rest of the model, because this gets
screenshotted straight into the memo and it needs to look like it belongs there.

---

## 3 — Annual cashflows, four entities

`bb849b91` · in `7.27_013_N-2.xlsx` · out `OUTPUT_WORKBOOK_-_TIBA.xlsx`

---

The lender's credit team came back to us this morning and told us they won't
work off the monthly tabs, so I need annual cashflow statements for all four
entities. That's TIBA, Stone Park, Sahary and El-Rowad, each one on its own
CF - Annually tab.

The good news is that those tabs already exist with the right row structure and
all the section labels in place. What's missing is the numbers, and the numbers
come out of aggregating each entity's monthly cashflow data, so you're
summarizing what's already there rather than building anything new.

On each tab, the annual period columns are eleven successive twelve-month blocks
starting in October 2020. Eleven blocks of twelve months covers the full
132-month monthly grid end to end, so nothing gets dropped and nothing gets
counted twice. Once those are in, complete the Starting Balance, Total and Grand
Total columns in the way the layout already sets up.

Please keep the row and section labels consistent with the corresponding monthly
tab. Credit is going to read the annual and the monthly side by side, and
anything that doesn't line up between them turns into a phone call we don't
need. Complete all the subtotal, total and net cashflow rows using the
workbook's standard cashflow section logic, and do that across every column
type, not only the annual ones.

There's one difference between the entities that I want to make sure you catch,
because the four tabs are not the same. TIBA and Stone Park both have a cashflow
from finance section, which covers the facility drawdown, the facility
repayment, interest expense and other fees, and that comes off their monthly
tabs. For those two entities, the periodical net cashflows line is the net cash
inflows and outflows plus the net cashflows from finance. Sahary and El-Rowad
don't have a finance section at all, so for those two the periodical net
cashflows is simply the net cash inflows and outflows. Please don't build a
finance block where there isn't one.

After that, complete the cash balance roll-forward on each tab and populate the
Minimum Cash END Balance field at the top. That figure is the one the covenant
conversation turns on, so it needs to be right and it needs to sit where they
expect to find it.

There are a couple of hardcodes coming from the client that you'd have no way of
knowing. On the Sahary tab, enter a zero for the Dues To Sister Companies line
in both the 2025 and the 2026 annual columns. And on the TIBA tab and the Sahary
tab, park a 60,000,000 memo figure in cell AU40. That's out past the reporting
columns on purpose. It's a memo, it shouldn't feed anything, they just want it
visible.

For the colors, follow the monthly tabs: blue for anything you type in, #008000
green for links to other tabs, and black for calculations on the same sheet.

---

## 4 — SBA acquisition model and loan tabs

`ef94a62b` · in `7.20_016_N-2.xlsx` · out `7.20_016_N-1.xlsx`

---

I need you to build out the debt side of the real estate acquisition model. The
buyer is funding this with SBA 504 and SBA 7(a) money and taking a refinance in
year five, and the sponsor's question is really just whether the LP gets paid.
We can't answer that until the debt is properly modelled, so there are two
pieces of work here: wiring up the Assumptions tab, and then building three new
loan amortization tabs, L1, L2 and L3.

Let's start with the Assumptions tab. The first thing it needs is a year-number
header row running 1 through 10, sitting above the Gross Revenue row. That's the
period index for the revenue and expense table, and you'll need it again later,
so please don't skip it.

Then there are a few formulas to add. Total expenses is the salaries and wages
line plus other expenses. The OPEX expense ratio is total expenses over gross
revenue. NOI is a little more involved, because it has to respect the "Use
Manual?" switch: if that switch is set to yes, NOI is gross revenue multiplied
by one minus the manual expense ratio, and if it's set to no, NOI is gross
revenue less the actual total expenses. Please build both paths and drive them
off the switch.

Next is the loan sizing. The SBA 504 loan amount is the SBA 504 percentage
multiplied by the RE budget total. The SBA 7(a) loan amount is the SBA 7(a)
percentage multiplied by the basis for the 7a loan calculation, and that basis
is the total funds less the RE budget total.

For the refinance, the LTV value comes from looking up NOI at the refi period
year, using that year header row as your index, and dividing it by the cap rate
on refi. The REFI amount is then the LTV multiplied by the LTV value. Please
make that a genuine lookup rather than pointing at the year-five cell, because
the moment the sponsor asks what year six looks like, a hardcoded NOI falls over
and we end up rebuilding it in front of him.

Alongside the general assumptions block I'd like two more sections. The sources
section should show the SBA 504 loan, the SBA 7(a) loan, the raised funds and a
total, pulling the amounts from the loan amounts you've just built and from the
required raise. The uses section should show the real estate purchase price, the
business purchase price, the acquisition fee, the gap funding, loan fees, legal,
the cash reserve and a total. We don't have numbers for the loan fees or the
legal yet, so leave those as labels with no values for now, and make the cash
reserve the residual so that the sources total equals the uses total.

Below the deal terms, please add a returns block showing the IRR and the equity
multiple for both the LP and the GP, and put in a row labelled remaining LP
balance after REFI as well. There's no value for that yet — we'll link it once
the refi tab exists.

Now let's turn to the three new tabs. L1 holds the SBA 504 amortization, L2 holds the SBA
7(a), and L3 holds the refinance. All three follow the general loan amortization
layout, and please label L3 as REFI at the top so that nobody mistakes it for a
third original loan.

Each tab needs a parameter block at the top, pulling from the relevant section
on Assumptions. In that block I want the loan amount, the start month of
repayment, the I/O period in months, which is the years on Assumptions
multiplied by twelve, whether we end the loan after I/O, whether we recast the
loan, the I/O rate, the amortization period in years, the term of the loan in
years, the interest rate, the payoff early flag, the start date and the end date, and then summary totals for total interest and total principal repaid.

The start month of repayment is hardcoded as 1 on both L1 and L2. On L3 you
should derive it from the REFI section on the Assumptions tab, by taking the
refi period and converting it into a month number.

Below the parameter block, each tab needs a 400-row monthly schedule. Use the
annual rate divided by twelve for the monthly interest, and use ROUNDUP wherever
you're converting remaining amortization years into months.

There are quite a few columns, so let me read them out in order: the year
number, the date, the model month number, the borrow amount, the beginning
balance, principal, the balloon payment, the exit repayment, extra principal,
interest, the interest rate, the ending balance, the repayment counter, the
amortization counter, the offset for when extra principal happens, total
principal, the total debt payment, the amortization payment when it isn't
recast, other reduction to principal, total principal again, total interest, and
amortization only.

L1 is slightly different from the other two. It carries two additional
period-tracking columns ahead of the date column, and it uses "Original Loan
Month #" in place of "Model Month #". On both L1 and L2, please hardcode a zero
into the extra principal input cells for the last four rows of the schedule,
which is months 397 through 400.

On formatting, put the hardcoded input values in blue, #0000FF, leave the
same-sheet formula outputs in black, and put the cross-sheet links in green,
#008000. Use Aptos Narrow at size 11 throughout the new sections, and keep the
number formats and the section header fills consistent with the rest of the
workbook.

---

## 5 — Cedarbrook AUM and revenue forecast

`fbe4760b` · in `Model_v4_N-2.xlsx` · out `Model_v4_N-1__v2_.xlsx`

---

I'd like you to build out the AUM and revenue forecast infrastructure for
Cedarbrook, and it's worth understanding why before you start. Management's
forecast runs a single blended fee rate across every product, and that is not
going to survive diligence, because open-ended funds and institutional accounts
have never earned the same basis points and everybody in that room knows it. So
we're going to build the fee rate up from the actual history and then forecast
off it.

There are three pieces of work. We're extending the AUM_Rollforward tab, and
then creating two new tabs, Revenue_Build and Revenue_Forecast.

On the AUM_Rollforward tab, section four, the institutional accounts section, is
missing its key memo item block after the ending balance. Please add it, with
four rows calculated off that section's own rollforward data: inflows as a percent of
BoP, outflows as a percent of BoP, market performance as a percent of BoP, and
other as a percent of BoP.

Then add a fifth section, the total, which aggregates all four product
categories. It should have the same structure as the individual sections, so
beginning balance, inflows, outflows, net flows, market performance, other and
ending balance, and then a key memo item block underneath it carrying those same
four percent of BoP metrics.

Revenue_Build is a new tab, and it's the fee analysis schedule that answers the
blended rate problem. Give it a date header reading "Fiscal Year Ended," across
whatever fiscal year history we have. The body has one section, titled "(I) Fees
by Avg AUM", and underneath it four sub-sections: open-ended funds, closed-end
funds, retail separate accounts and institutional accounts.

Each of those sub-sections has three rows. The first is fees, which is the
investment management fees out of the Revenue_Breakdown tab, in thousands. The
second is average AUM, which is the average of the beginning and ending AUM
balances from AUM_Rollforward, in millions. The third is the derived rate
itself, which the tab labels Avg Fees %.

One rule on that tab: only populate a column where you have both the beginning
and the ending AUM. If you only have one end of it, please leave the column
empty, because a half-year denominator flatters the fee rate and somebody on the
other side will find it.

Revenue_Forecast is also new. It takes the same "Fiscal Year Ended," date
header, along with a unit note reading "(AUM in $mm, Revenue in $'000s)". Build
four product sections that mirror the rollforward categories: open-end funds,
closed-end funds, retail separate accounts and institutional accounts.

Each section has the same shape. It starts with an AUM rollforward showing BoP
AUM, net flows, market performance, other and EoP AUM. Below that there's a
driver memo block, labelled with the product name and "AUM Drivers:", which
carries net flows as a percent of BoP, market performance as a percent of BoP,
and other as a percent of BoP. Then there's an average fees row, and
finally a revenue line labelled with the product name and "Revenue Inv. Mgmt
Fees", which is driven by the period average AUM and the average fees
percentage.

For the historical periods, source the AUM from AUM_Rollforward, link the
average fees from Revenue_Build, and compute the percent of BoP driver rows off
the rollforward figures. FY2022 through FY2024 are the historical periods,
and FY2025 through FY2029 are the forecast.

For the forecast periods, drive the AUM movements off BoP using a rolling
three-year trailing average of each driver percentage. I want that window to
roll forward, so once you're into the forecast it starts picking up the prior
forecast years rather than staying frozen on the last three actuals. Carry the
average fees forward on the same rolling three-year basis.

For formatting, leave the calculated values in black and use Aptos Narrow at
size 11 in the sections you change. Keep the number formats consistent with the
model around them and the section header fills consistent with the existing
workbook style.
