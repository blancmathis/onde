#!/usr/bin/env python3
"""Download two CC BY 4.0 recordings from the composer's official website.
No scraping of paid libraries or DRM, and no account credentials.
License evidence and SHA256 provenance are stored with each successful download.
"""
import hashlib, json, pathlib, sys, urllib.request, urllib.parse
root = pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'Assets')
root.mkdir(parents=True, exist_ok=True)
base = 'https://incompetech.com/music/royalty-free/'
manifest = []
for title, filename in [('Almost in F','almost.mp3'),('Dreams Become Real','dreams.mp3')]:
    url = base + 'mp3-royaltyfree/' + urllib.parse.quote(title + '.mp3')
    path = root / filename
    try:
        if not path.exists():
            request = urllib.request.Request(url, headers={'User-Agent':'Onde-local-build/1.0'})
            with urllib.request.urlopen(request, timeout=90) as response:
                payload = response.read(90_000_000)
            if len(payload)<10000 or payload[:20].lower().startswith(b'<!doctype'):
                raise ValueError('Not an MP3 response')
            path.write_bytes(payload)
        manifest.append({'title':title,'author':'Kevin MacLeod (incompetech.com)', 'license':'CC BY 4.0','license_url':'https://creativecommons.org/licenses/by/4.0/','source_url':url,'filename':filename,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'modifications':'None','retrieved_on':'2026-09-13'})
        print(f'Included: {title}, {path.stat().st_size} bytes')
    except Exception as exc:
        print(f'Optional music unavailable: {title}: {exc}', file=sys.stderr)
(root / 'music-provenance.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
try:
    with urllib.request.urlopen(base+'faq.html',timeout=20) as response:
        (root/'incompetech-license-evidence.html').write_bytes(response.read())
except Exception:
    pass
