import csv, io, sys, urllib.request
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
SID='1hgSc4wg00QQhS-qJt7qhRSU5kuShRwj9UZXt9vjFyOE'
tsvdir = Path(sys.argv[1])
for tab in sys.argv[2:]:
    url = f'https://docs.google.com/spreadsheets/d/{SID}/gviz/tq?tqx=out:csv&sheet={tab}&headers=0'
    remote = list(csv.reader(io.StringIO(urllib.request.urlopen(url).read().decode('utf-8'))))
    local = []
    for r in csv.reader(io.StringIO((tsvdir / f'{tab}.tsv').read_text(encoding='utf-8')), delimiter='\t'):
        local.append([c[1:] if c.startswith("'") else c for c in r])
    w = max(len(r) for r in local)
    local = [r + [''] * (w - len(r)) for r in local]
    remote = [(r + [''] * (w - len(r)))[:w] for r in remote]
    while remote and not any(remote[-1]): remote.pop()
    diffs = [(i, j, a, b) for i, (ra, rb) in enumerate(zip(local, remote)) for j, (a, b) in enumerate(zip(ra, rb)) if a != b]
    print(f'{tab}: local {len(local)} rows, remote {len(remote)} rows, cell diffs {len(diffs)}')
    for d in diffs[:5]: print('   ', d)
