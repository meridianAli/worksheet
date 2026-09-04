import re, base64, subprocess, sys
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"
URL = ("https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Condensed:wght@500;600;700"
       "&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap")
css = subprocess.run(["curl","-sSL","--max-time","30","-A",UA,URL],
                     capture_output=True, text=True, check=True).stdout
# keep only latin subsets to control size
blocks = re.split(r'(?=/\* )', css)
keep = [b for b in blocks if b.strip().startswith('/* latin') or not b.strip().startswith('/*')]
css = "".join(keep)
urls = sorted(set(re.findall(r'url\((https://fonts\.gstatic\.com/[^)]+)\)', css)))
print(len(urls), "font files", file=sys.stderr)
for u in urls:
    data = subprocess.run(["curl","-sSL","--max-time","30","-A",UA,u],
                          capture_output=True, check=True).stdout
    css = css.replace(u, "data:font/woff2;base64," + base64.b64encode(data).decode())
open("fonts-inline.css","w").write(css)
print(len(css), "bytes css", file=sys.stderr)
