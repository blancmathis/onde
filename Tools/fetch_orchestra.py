#!/usr/bin/env python3
"""Fetch pinned, checksum-verified CC0 note recordings; no account or secret."""
import concurrent.futures,hashlib,json,pathlib,time,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 manifest=json.loads((ROOT/'Resources/OrchestraSources.json').read_text())
 out=ROOT/'.build/orchestra-raw';out.mkdir(parents=True,exist_ok=True)
 def get(item):
  destination=out/item['filename']
  for attempt in range(3):
   try:
    if destination.exists():data=destination.read_bytes()
    else:
     with urllib.request.urlopen(urllib.request.Request(item['url'],headers={'User-Agent':'Onde-CC0-orchestra/1.6'}),timeout=60) as r:data=r.read(item['upstream_bytes']+1)
    if len(data)!=item['upstream_bytes'] or hashlib.sha256(data).hexdigest()!=item['sha256']:raise ValueError('Invalid sample checksum: '+item['filename'])
    if not destination.exists():destination.write_bytes(data)
    return len(data)
   except Exception:
    if attempt==2:raise
    time.sleep(1+attempt)
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:sizes=list(pool.map(get,manifest['samples']))
 print(f'Verified {len(sizes)} CC0 recordings ({sum(sizes)/1e6:.1f} MB), upstream commit {manifest["commit"]}.')
if __name__=='__main__':main()
