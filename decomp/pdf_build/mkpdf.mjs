import pkg from '/opt/node22/lib/node_modules/playwright/index.js'; const { chromium } = pkg;
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args:['--no-sandbox'] });
const p = await b.newPage();
await p.goto('file://' + process.cwd() + '/banker-scenarios-print.html', { waitUntil: 'networkidle' });
await p.emulateMedia({ media: 'print' });
await p.waitForTimeout(600);
await p.pdf({
  path: '../Banker-Scenarios.pdf',
  format: 'Letter',
  printBackground: true,
  margin: { top: '14mm', right: '12mm', bottom: '16mm', left: '12mm' },
  displayHeaderFooter: true,
  headerTemplate: '<div></div>',
  footerTemplate:
    '<div style="width:100%;font-size:7.5pt;font-family:system-ui,sans-serif;color:#778896;padding:0 12mm;">' +
    '<span style="float:left">Five banker scenarios &middot; tasksexport20260904.json</span>' +
    '<span style="float:right">Page <span class="pageNumber"></span> of <span class="totalPages"></span></span></div>',
});
await b.close();
