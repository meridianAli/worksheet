"""Write each formula's computed value beside the formula so the file renders
in previewers and Sheets; Excel still recalculates on open."""
import re, zipfile, shutil, json
from openpyxl import load_workbook
XL='/home/user/worksheet/aht/August-AHT-Analysis.xlsx'
SCR='/tmp/claude-0/-home-user-worksheet/968f285e-0587-5207-a956-c384e074891a/scratchpad/'
coh=json.load(open(SCR+'simple_cohort.json')); people=json.load(open(SCR+'simple_people.json'))
wb=load_workbook(XL); vals={}
def put(s,ref,v): vals[(s,ref)]=v
# Read me
wsr=wb['Read me']
for r in range(1,40):
    f=wsr.cell(row=r,column=3).value
    if isinstance(f,str) and f.startswith('='):
        put('Read me',f'C{r}', coh['aht'] if '/C' in f and r%2 else None)
# resolve read-me properly: AHT then cost per task, in order
rm=[r for r in range(1,40) if isinstance(wsr.cell(row=r,column=3).value,str)
    and str(wsr.cell(row=r,column=3).value).startswith('=')]
for i,r in enumerate(rm): put('Read me',f'C{r}', coh['aht'] if i==0 else coh['cpt'])
# contributor rows
first,last=coh['first'],coh['last']
for i,p in enumerate(people):
    r=first+i
    if p['tasks']:
        put('AHT by contributor',f'G{r}', p['hours']/p['tasks'])
        put('AHT by contributor',f'H{r}', p['cost']/p['tasks'])
    if p['infl']:
        put('AHT by contributor',f'J{r}', p['hours']/p['infl'])
tr=last+1
put('AHT by contributor',f'D{tr}',coh['hours']); put('AHT by contributor',f'E{tr}',coh['cost'])
put('AHT by contributor',f'F{tr}',coh['tasks']); put('AHT by contributor',f'G{tr}',coh['aht'])
put('AHT by contributor',f'H{tr}',coh['cpt']);   put('AHT by contributor',f'I{tr}',coh['infl'])
# checks
wsk=wb['Checks']; order=[coh['people'],coh['tasks'],coh['tasks'],coh['hours'],coh['cost'],
                         coh['aht'],coh['cpt'],coh['rate']]
ck=[r for r in range(1,40) if isinstance(wsk.cell(row=r,column=3).value,str)
    and str(wsk.cell(row=r,column=3).value).startswith('=')]
for v,r in zip(order,ck): put('Checks',f'C{r}',v)

name_to_file={nm:f'xl/worksheets/sheet{i}.xml' for i,nm in enumerate(wb.sheetnames,1)}
tmp=XL+'.tmp'; zin=zipfile.ZipFile(XL); zout=zipfile.ZipFile(tmp,'w',zipfile.ZIP_DEFLATED); n=0
for item in zin.infolist():
    data=zin.read(item.filename)
    sheet=next((nm for nm,fn in name_to_file.items() if fn==item.filename),None)
    if sheet:
        xml=data.decode('utf-8').replace('<v />','').replace('<v/>','')
        def repl(m):
            global n
            key=(sheet,m.group(1))
            if key in vals and vals[key] is not None:
                n+=1; return m.group(0).replace('</c>',f'<v>{vals[key]}</v></c>')
            return m.group(0)
        xml=re.sub(r'<c r="([A-Z]+\d+)"[^>]*>(?:(?!</c>|<c ).)*?<f>(?:(?!</c>|<c ).)*?</c>',repl,xml)
        data=xml.encode('utf-8')
    zout.writestr(item,data)
zin.close(); zout.close(); shutil.move(tmp,XL)
print('values written:',n,'of',sum(1 for v in vals.values() if v is not None))
