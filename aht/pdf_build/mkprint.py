import re
src = open('aug-working-paper.html').read()
fonts = open('fonts-inline.css').read()

# strip the remote font links; the faces are inlined instead
src = re.sub(r'<link rel="preconnect"[^>]*>\n?', '', src)
src = re.sub(r'<link rel="stylesheet" href="https://fonts\.googleapis[^"]*">\n?', '', src)

title = re.search(r'<title>(.*?)</title>', src).group(1)
src = re.sub(r'<title>.*?</title>\n?', '', src)

PRINT_CSS = """
  /* ---------- standalone / print ---------- */
  html{-webkit-print-color-adjust:exact; print-color-adjust:exact}
  body{margin:0}
  img{max-width:100%}
  [hidden]{display:none!important}

  @page{ size:Letter portrait; margin:14mm 12mm 16mm; }

  @media print{
    .wrap{max-width:none;padding:0}
    .scroll{overflow:visible!important}
    /* the roster is 12 columns wide; tighten it so it fits the page box */
    table.dense{min-width:0!important;width:100%;font-size:.60rem;table-layout:auto}
    table.dense th,table.dense td{padding:2.4px 3.5px}
    table{width:100%}
    thead{display:table-header-group}
    tfoot{display:table-footer-group}
    tr,li{break-inside:avoid;page-break-inside:avoid}
    h1,h2,h3{break-after:avoid;page-break-after:avoid}
    /* keep a heading with its first lines, but don't burn a page on every section */
    h2{margin-top:34px}
    .fig,.flag,.verdict,figure,pre,.kpi{break-inside:avoid;page-break-inside:avoid}
    section{break-inside:auto;page-break-inside:auto}
    pre{white-space:pre-wrap;word-break:break-word;font-size:.66rem}
    a{color:inherit;text-decoration:none}
    .foot{break-inside:avoid}
    /* the roster alone is long: let it flow across pages, rows kept whole */
    #list + * , .scroll{break-inside:auto;page-break-inside:auto}
  }
"""

# force the light palette for print, drop the dark-mode overrides
src = src.replace('@media (prefers-color-scheme: dark)', '@media (prefers-color-scheme: dark) and (min-width:99999px)')

# inject print css at the end of the first <style> block
i = src.index('</style>')
src = src[:i] + PRINT_CSS + src[i:]

doc = ("<!doctype html>\n<html lang=\"en\" data-theme=\"light\">\n<head>\n"
       "<meta charset=\"utf-8\">\n"
       "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
       f"<title>{title}</title>\n"
       "<style>\n" + fonts + "\n</style>\n"
       + src.split('<style>',1)[0] + "<style>" + src.split('<style>',1)[1].split('</style>',1)[0]
       + "</style>\n</head>\n<body>\n"
       + src.split('</style>',1)[1] + "\n</body>\n</html>\n")
open('aug-working-paper-print.html','w').write(doc)
print(len(doc), 'bytes')
