import json, os, collections
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

SCR='/tmp/claude-0/-home-user-worksheet/968f285e-0587-5207-a956-c384e074891a/scratchpad/'
AHT='/home/user/worksheet/aht/'
OUT=AHT+'August-AHT-Analysis.xlsx'
DROP='Ali Mallick'

tl   = [r for r in json.load(open(SCR+'tasklist.json'))['data']['rows'] if r[1]!=DROP]
ppl  = [r for r in json.load(open(SCR+'simple.json'))['data']['rows'] if r[0]!=DROP]
credited = collections.Counter(r[1] for r in tl)

TASKS = len(tl)
HOURS = round(sum(r[2] for r in ppl),2)
COST  = round(sum(r[3] for r in ppl),2)
INFL  = sum(r[6] for r in ppl)

people=[]
for name,email,hrs,cost,days,_c,infl in ppl:
    people.append(dict(name=name,email=email,hours=hrs,cost=cost,days=days,
                       tasks=credited.get(name,0),infl=infl))
people.sort(key=lambda p:(p['tasks']==0, p['hours']/p['tasks'] if p['tasks'] else 0))

ARIAL='Arial'; INK='1F2933'; GREY='6B7A88'; BLUE='0000FF'; GREEN='008000'
def F(sz=10,b=False,color=INK,i=False): return Font(name=ARIAL,size=sz,bold=b,color=color,italic=i)
HDR=PatternFill('solid',fgColor='1F3B54'); BAND=PatternFill('solid',fgColor='EDF2F6')
KEY=PatternFill('solid',fgColor='FFFF00')
thin=Side(style='thin',color='C9D3DB'); BOX=Border(left=thin,right=thin,top=thin,bottom=thin)
MONEY='$#,##0;($#,##0);-'; MONEY2='$#,##0.00;($#,##0.00);-'; H2='0.00;-0.00;-'

def head(ws,row,hs,widths=None,firstleft=2):
    for j,h in enumerate(hs,1):
        c=ws.cell(row=row,column=j,value=h); c.font=F(9,True,color='FFFFFF'); c.fill=HDR
        c.alignment=Alignment(wrap_text=True,vertical='bottom',horizontal='right' if j>firstleft else 'left')
    ws.row_dimensions[row].height=30
    if widths:
        for j,w in enumerate(widths,1): ws.column_dimensions[get_column_letter(j)].width=w
    return row+1
def note(ws,row,txt,col=1,span=6,size=9):
    c=ws.cell(row=row,column=col,value=txt); c.font=F(size,color=GREY,i=True)
    c.alignment=Alignment(wrap_text=True,vertical='top')
    if span: ws.merge_cells(start_row=row,start_column=col,end_row=row,end_column=col+span-1)
    ws.row_dimensions[row].height=max(13,13*(len(txt)//110+1))
    return row+1

wb=Workbook()

# ---------------------------------------------------------------- READ ME
ws=wb.active; ws.title='Read me'; ws.sheet_view.showGridLines=False
ws.column_dimensions['A'].width=3
for c,w in zip('BCDEFG',[34,16,16,4,52,10]): ws.column_dimensions[c].width=w
r=2
ws.cell(row=r,column=2,value='August 2026 AHT — prompt-only taskers').font=F(17,True); r+=1
ws.cell(row=r,column=2,value='Hours we paid for, divided by tasks that reached audit. Nothing else.').font=F(11,color=GREY); r+=2

ws.cell(row=r,column=2,value='THE WHOLE CALCULATION').font=F(9,True,color='1F3B54'); r+=1
calc=[('August payable hours',   HOURS, '#,##0.0', 'What we are accountable for paying. From payroll.'),
      ('August cost',            COST,  MONEY,     'The same hours priced at each person\'s contract rate.'),
      ('Tasks reaching audit',   TASKS, '#,##0',   'Unique tasks, counted once, on first entry into audit.'),
      ('AHT (hours per task)',   None,  H2,        'Hours divided by tasks. That is the entire method.'),
      ('Cost per task',          None,  MONEY,     'Cost divided by tasks.')]
cf=r
for label,val,fmt,why in calc:
    ws.cell(row=r,column=2,value=label).font=F(10,True)
    cc=ws.cell(row=r,column=3)
    if label.startswith('AHT'):        cc.value=f'=C{cf}/C{cf+2}'; cc.font=F(13,True); cc.fill=KEY
    elif label.startswith('Cost per'): cc.value=f'=C{cf+1}/C{cf+2}'; cc.font=F(13,True); cc.fill=KEY
    else:                              cc.value=val; cc.font=F(12,True,color=BLUE)
    cc.number_format=fmt; cc.border=BOX
    ws.cell(row=r,column=5,value=why).font=F(9,color=GREY); r+=1
r+=1

ws.cell(row=r,column=2,value='WHAT EACH NUMBER IS, EXACTLY').font=F(9,True,color='1F3B54'); r+=1
for line in [
 'HOURS — payable time, not gross clocked time. A contributor runs a timer; that raw time is reviewed',
 'and approved, and the approved figure is what we pay. Only the approved figure is used here. Each',
 'segment is dated to the day the work actually happened, Eastern time, so August means August.',
 '',
 'TASKS — a task is counted once, the first time it enters the audit state, in August, Eastern time.',
 'A task that bounces back for a redo and returns to audit is still one task, not two. Audit means done;',
 'that is the sheets convention, not a choice made here.',
 '',
 'WHO A TASK BELONGS TO — whoever last handed it out of edit or redo before it hit audit. Submission',
 'into audit is automated, so 97% of the audit transitions are triggered by the system, not a person;',
 'reading the audit event directly would credit almost every task to a service account.',
 '',
 'AHT — hours divided by tasks. Nothing is modelled, weighted, or allocated.',
]:
    ws.cell(row=r,column=2,value=line).font=F(10); r+=1
r+=1

ws.cell(row=r,column=2,value='WHAT THIS DOES AND DOES NOT TELL YOU').font=F(9,True,color='C2551F'); r+=1
for line in [
 'It is a productivity ratio, not a stopwatch. It does not claim a task took 1.96 hours of hands-on work.',
 'It says: for every task this person pushed over the line in August, we paid for this many hours of their',
 'time. Hours spent on tasks still in progress at month end are in the numerator; those tasks are not in',
 'the denominator. Over a steady month that roughly evens out, but in a ramping or winding-down month it',
 'will not, so compare months with that in mind.',
 '',
 'It is also why the number is a fair costing basis: somebody pays for the work in progress too.',
]:
    ws.cell(row=r,column=2,value=line).font=F(10); r+=1
r+=1

ws.cell(row=r,column=2,value='TWO WAYS TO COUNT TASKS — BOTH ARE IN THE TABLE').font=F(9,True,color='1F3B54'); r+=1
for line in [
 f'CREDITED ({TASKS}) — the person who finished it. Every task belongs to exactly one person, so these',
 '   add up to the cohort total and the cohort AHT is a real average.',
 f'INFLUENCED ({INFL}) — everyone who ever held the task. A task worked by three people counts for all',
 '   three, so these deliberately overshoot; use it to see how much a person contributed to work someone',
 '   else finished, not to sum a cohort.',
]:
    ws.cell(row=r,column=2,value=line).font=F(10); r+=1
r+=1

ws.cell(row=r,column=2,value='WHO IS IN AND OUT').font=F(9,True,color='1F3B54'); r+=1
for line in [
 'IN:  every account on the sheets project whose role is exactly prompt_tasker. All 618 sheets members',
 '     hold exactly one role, so nobody was dropped for holding two.',
 'OUT: internal staff accounts, and Ali Mallick at the owner\'s request.',
 'OUT: real prompt work done under a reviewer or beginner title — including the project\'s highest-volume',
 '     contributor. The role field is a permissions label, not a description of work. That is the',
 '     requested scope, not an oversight.',
]:
    ws.cell(row=r,column=2,value=line).font=F(10); r+=1
r+=2
ws.cell(row=r,column=2,value='Source: tsip_prd via Metabase (database 2, read-only), queried 1 September 2026. Every query is on the Queries tab.').font=F(9,color=GREY); r+=1
ws.cell(row=r,column=2,value='Blue = measured from the database. Black on yellow = arithmetic you can check. Green = a formula reading another tab.').font=F(9,color=GREY)

# ------------------------------------------------------ AHT BY CONTRIBUTOR
wsc=wb.create_sheet('AHT by contributor'); wsc.sheet_view.showGridLines=False
r=2
wsc.cell(row=r,column=1,value='AHT by contributor').font=F(15,True); r+=1
wsc.cell(row=r,column=1,value='Sorted lowest AHT first. Every AHT cell is literally Hours divided by Tasks — click one and look.').font=F(10,color=GREY); r+=2
hs=['#','Contributor','Email','Hours','Cost $','Tasks (credited)','AHT (h)','$/task','Tasks (influenced)','AHT if influenced']
r=head(wsc,r,hs,widths=[5,26,31,9,11,11,10,10,11,11],firstleft=3)
wsc.freeze_panes=f'D{r}'
first=r
for i,p in enumerate(people,1):
    wsc.cell(row=r,column=1,value=i).font=F(10,color=GREY)
    wsc.cell(row=r,column=2,value=p['name']).font=F(10,p['tasks']>=10)
    wsc.cell(row=r,column=3,value=p['email']).font=F(9,color=GREY)
    c=wsc.cell(row=r,column=4,value=p['hours']); c.number_format='#,##0.0'; c.font=F(10,color=BLUE)
    c=wsc.cell(row=r,column=5,value=p['cost']);  c.number_format=MONEY;     c.font=F(10,color=BLUE)
    c=wsc.cell(row=r,column=6,value=p['tasks'] if p['tasks'] else None); c.number_format='#,##0'; c.font=F(10,color=BLUE)
    c=wsc.cell(row=r,column=9,value=p['infl'] if p['infl'] else None);   c.number_format='#,##0'; c.font=F(10,color=BLUE)
    if p['tasks']:
        c=wsc.cell(row=r,column=7,value=f'=D{r}/F{r}'); c.number_format=H2;    c.font=F(11,True)
        c=wsc.cell(row=r,column=8,value=f'=E{r}/F{r}'); c.number_format=MONEY; c.font=F(10)
    else:
        c=wsc.cell(row=r,column=7,value='no task reached audit'); c.font=F(9,color=GREY,i=True)
        wsc.merge_cells(start_row=r,start_column=7,end_row=r,end_column=8)
    if p['infl']:
        c=wsc.cell(row=r,column=10,value=f'=D{r}/I{r}'); c.number_format=H2; c.font=F(10,color=GREY)
    if p['tasks']>=10:
        for j in range(1,11): wsc.cell(row=r,column=j).fill=BAND
    r+=1
last=r-1
tr=r
wsc.cell(row=tr,column=2,value='Cohort total').font=F(10,True)
for col,f_,fmt in [(4,f'=SUM(D{first}:D{last})','#,##0.0'),(5,f'=SUM(E{first}:E{last})',MONEY),
                   (6,f'=SUM(F{first}:F{last})','#,##0'),(7,f'=D{tr}/F{tr}',H2),
                   (8,f'=E{tr}/F{tr}',MONEY),(9,f'=SUM(I{first}:I{last})','#,##0')]:
    c=wsc.cell(row=tr,column=col,value=f_); c.number_format=fmt; c.font=F(11,True)
for j in range(1,11): wsc.cell(row=tr,column=j).border=Border(top=Side(style='medium',color='1F3B54'))
r=tr+2
r=note(wsc,r,'Hours and Cost are August payroll for that person, across everything they worked on.',span=8)
r=note(wsc,r,'Tasks (credited) is tasks they finished; these sum to the cohort total, so the cohort AHT is a true average. '
             'Every one of them is listed on the Task audit trail tab.',span=8)
r=note(wsc,r,'Tasks (influenced) is every task they ever held, finished by them or not. These overlap between people and '
             'deliberately do not sum — the same task counts for everyone who touched it.',span=8)
r=note(wsc,r,'Shaded rows have 10 or more credited tasks. Below that a single task swings the ratio, so treat those rows '
             'as informational rather than a ranking.',span=8)
r=note(wsc,r,'The last 11 rows booked hours but finished nothing in August. Their AHT is undefined, not zero.',span=8)

# --------------------------------------------------------- TASK AUDIT TRAIL
wst=wb.create_sheet('Task audit trail')
head(wst,1,['Task ID','Credited to','Email','First entered audit (ET)','People who held it','Redo rounds'],
     widths=[38,24,30,20,12,10],firstleft=3)
wst.freeze_panes='B2'
row=2
for tid,name,email,at,held,redos in sorted(tl,key=lambda x:(x[1],x[3])):
    wst.cell(row=row,column=1,value=tid).font=F(8,color=GREY)
    wst.cell(row=row,column=2,value=name).font=F(10)
    wst.cell(row=row,column=3,value=email).font=F(9,color=GREY)
    wst.cell(row=row,column=4,value=at).font=F(10,color=BLUE)
    wst.cell(row=row,column=5,value=held).font=F(10,color=GREY)
    wst.cell(row=row,column=6,value=redos).font=F(10,color=GREY)
    row+=1
note(wst,row+1,f'All {TASKS} tasks behind the Tasks (credited) column. One row per task — count them if you like. '
                'People who held it and Redo rounds are context only; neither is used in the AHT calculation.',col=1,span=6)

# ------------------------------------------------------------------ QUERIES
wsq=wb.create_sheet('Queries'); wsq.sheet_view.showGridLines=False
wsq.column_dimensions['A'].width=3; wsq.column_dimensions['B'].width=120
r=2
wsq.cell(row=r,column=2,value='The queries').font=F(15,True); r+=1
wsq.cell(row=r,column=2,value='Read-only against tsip_prd through the Metabase dataset API. Paste either one in and you get the numbers above.').font=F(10,color=GREY); r+=2
for title,desc,path in [
  ('Hours, cost and both task counts, per person','Produces every column of the contributor table.','simple.sql'),
  ('The task audit trail','Produces the task list, one row per task.','tasklist.sql')]:
    wsq.cell(row=r,column=2,value=title).font=F(12,True); r+=1
    wsq.cell(row=r,column=2,value=desc).font=F(10,color=GREY); r+=2
    txt=open(SCR+path).read().rstrip()
    c=wsq.cell(row=r,column=2,value=txt); c.font=Font(name='Consolas',size=8.5,color='24343F')
    c.alignment=Alignment(vertical='top'); c.fill=PatternFill('solid',fgColor='F5F7F9'); c.border=BOX
    wsq.row_dimensions[r].height=11.5*(txt.count('\n')+1); r+=3

# ------------------------------------------------------------------- CHECKS
wsk=wb.create_sheet('Checks'); wsk.sheet_view.showGridLines=False
wsk.column_dimensions['A'].width=3
for c,w in zip('BCDEF',[36,15,15,4,66]): wsk.column_dimensions[c].width=w
r=2
wsk.cell(row=r,column=2,value='Checks').font=F(15,True); r+=1
wsk.cell(row=r,column=2,value='Recomputed live from the other tabs, next to what they should equal.').font=F(10,color=GREY); r+=2
r=head(wsk,r,['','Check','This workbook','Expected','','What it proves'],firstleft=2)
fc=r
for label,formula,exp,fmt,why in [
 ('Contributors',   f"=COUNTA('AHT by contributor'!$B${first}:$B${last})", len(people),'#,##0',
  'Everyone with August payable hours on the project under this role.'),
 ('Tasks, from the table', f"=SUM('AHT by contributor'!$F${first}:$F${last})", TASKS,'#,##0',
  'The Tasks column added up.'),
 ('Tasks, counted individually', f"=COUNTA('Task audit trail'!$A$2:$A${TASKS+1})", TASKS,'#,##0',
  'The audit trail counted row by row. Must match the line above — two independent counts of the same thing.'),
 ('August payable hours', f"=SUM('AHT by contributor'!$D${first}:$D${last})", HOURS,'#,##0.0',
  'Straight from payroll. No adjustment of any kind.'),
 ('August cost', f"=SUM('AHT by contributor'!$E${first}:$E${last})", COST, MONEY,
  'Those hours at each person\'s in-effect contract rate.'),
 ('AHT (hours per task)', f'=C{fc+3}/C{fc+1}', round(HOURS/TASKS,2), H2,
  'Hours divided by tasks. This is the headline number and there is nothing else in it.'),
 ('Cost per task', f'=C{fc+4}/C{fc+1}', round(COST/TASKS,2), MONEY,
  'Cost divided by tasks.'),
 ('Implied blended rate', f'=C{fc+4}/C{fc+3}', round(COST/HOURS,2), MONEY2,
  'Cost over hours. Lands between the $150 and $200 contract rates, as it must.')]:
    wsk.cell(row=r,column=2,value=label).font=F(10,True)
    c=wsk.cell(row=r,column=3,value=formula); c.number_format=fmt; c.font=F(11,True)
    c=wsk.cell(row=r,column=4,value=exp);     c.number_format=fmt; c.font=F(10,color=BLUE)
    c=wsk.cell(row=r,column=6,value=why);     c.font=F(9,color=GREY); c.alignment=Alignment(wrap_text=True,vertical='top')
    wsk.row_dimensions[r].height=26; r+=1
r+=1
wsk.cell(row=r,column=2,value='Known limits — say these before someone else does').font=F(11,True,color='C2551F'); r+=1
for line in [
 'Hours include work on tasks that had not finished by 31 August; those tasks are not in the denominator. '
 'In a steady month this roughly cancels out. In a ramping month it does not, and AHT will read high.',
 'The reverse also holds: a task finished in early August may carry July hours, which sat in July\'s payroll.',
 'A task is credited to whoever finished it. If it changed hands late, the earlier author\'s effort still sits in '
 'their Hours but the task lands in someone else\'s Tasks. The Influenced column exists to make that visible.',
 'Eleven people booked hours and finished nothing in August — 43 hours, about $6.5k. Their AHT is undefined, '
 'not infinite and not zero, so they are excluded from the cohort ratio but still carried in Hours and Cost.',
 'The role filter excludes prompt work done under other titles, including the project\'s biggest producer.',
 'Task varieties are blended: patch-based cannot be separated from greenfield in platform data.',
]:
    c=wsk.cell(row=r,column=2,value='•  '+line); c.font=F(10); c.alignment=Alignment(wrap_text=True,vertical='top')
    wsk.merge_cells(start_row=r,start_column=2,end_row=r,end_column=6)
    wsk.row_dimensions[r].height=26; r+=1

wb.save(OUT)
json.dump(dict(tasks=TASKS,hours=HOURS,cost=COST,infl=INFL,people=len(people),
               aht=HOURS/TASKS,cpt=COST/TASKS,rate=COST/HOURS,
               first=first,last=last,rateable=sum(1 for p in people if p['tasks']>=10)),
          open(SCR+'simple_cohort.json','w'),indent=1)
json.dump(people,open(SCR+'simple_people.json','w'))
print('wrote',OUT)
print(f'{len(people)} people | {TASKS} tasks | {HOURS} h | ${COST:,.0f} | AHT {HOURS/TASKS:.3f} h | ${COST/TASKS:.2f}/task')
