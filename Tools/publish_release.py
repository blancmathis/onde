#!/usr/bin/env python3
"""Publish a complete current-main draft with bounded, verified asset uploads.

Network retries apply only to assets of this run's unpublished draft. Existing
published releases are never overwritten. Credentials stay in gh's environment.
"""
import hashlib,json,os,pathlib,re,subprocess,time
from urllib.parse import urlsplit, urlencode

def gh(*args,timeout=60):
    p=subprocess.run(['gh',*args],capture_output=True,text=True,timeout=timeout)
    if p.returncode:raise RuntimeError(p.stderr.strip() or p.stdout.strip())
    return p.stdout

def api(path):return json.loads(gh('api',path))

def main():
    root=pathlib.Path(__file__).resolve().parents[1];os.chdir(root)
    repo=os.environ['GITHUB_REPOSITORY'];commit=os.environ['GITHUB_SHA']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',repo):raise ValueError('Invalid repository')
    if not re.fullmatch(r'[0-9a-f]{40}',commit):raise ValueError('Invalid commit')
    info=dict(line.split('=',1) for line in (root/'dist/release.env').read_text().splitlines() if '=' in line)
    tag=info['TAG'];assert re.fullmatch(r'build-[0-9]{14}-[0-9a-f]{8}',tag) and tag.endswith(commit[:8])
    def current():return api(f'repos/{repo}/commits/main')['sha']==commit
    if not current():print('Superseded build: not published.');return
    names=['Onde-macOS-universal.zip','Onde-macOS-universal.zip.sha256',*[f'{p}-12min.m4a' for p in ['sillage','filigrane','confluence','sanctuaire','ambre','canopee','meridien']],'transition-ambre-sanctuaire.m4a']
    local={name:root/'dist'/name for name in names}
    metadata={name:(p.stat().st_size,'sha256:'+hashlib.sha256(p.read_bytes()).hexdigest()) for name,p in local.items()}
    gh('release','create',tag,'-R',repo,'--target',commit,'--draft','--title',f'Onde {info["VERSION"]} · {info["ONDE_BUILD"]}','--notes-file','dist/release-notes.md',timeout=90)
    # A draft need not have a published tag yet. Resolve its release ID, then
    # inspect that exact draft throughout the transaction.
    release_id=None
    for _ in range(10):
        created=next((r for r in api(f'repos/{repo}/releases?per_page=100') if r['tag_name']==tag),None)
        if created:
            release_id=created['id'];break
        time.sleep(2)
    if release_id is None:raise RuntimeError('Created draft was not visible')
    def draft():
        release=api(f'repos/{repo}/releases/{release_id}')
        if not release['draft'] or release['target_commitish']!=commit:raise RuntimeError('Refusing to change a published or unrelated release')
        return release
    for name,path in local.items():
        size,digest=metadata[name]
        for attempt in range(3):
            r=draft();existing=next((a for a in r['assets'] if a['name']==name),None)
            if existing and existing['state']=='uploaded' and existing['size']==size and existing.get('digest')==digest:break
            try:
                # Sequential transfer avoids saturating the archive upload while
                # seven large previews compete. Timeout instead of hanging a job.
                # Upload to this numeric release ID directly. CLI tag resolution
                # can stall for a draft whose tag does not exist yet.
                endpoint = r['upload_url'].split('{', 1)[0]
                parsed = urlsplit(endpoint)
                expected_path = f'/repos/{repo}/releases/{release_id}/assets'
                if (parsed.scheme != 'https' or parsed.netloc != 'uploads.github.com'
                        or parsed.path != expected_path or parsed.query or parsed.fragment):
                    raise RuntimeError('Unexpected release upload endpoint')
                if existing:
                    draft()  # Never delete assets from a published release.
                    gh('api', '--method', 'DELETE', f'repos/{repo}/releases/assets/{existing["id"]}')
                media = 'application/zip' if name.endswith('.zip') else 'audio/mp4' if name.endswith('.m4a') else 'text/plain'
                gh('api', '--method', 'POST', endpoint + '?' + urlencode({'name': name}),
                   '-H', 'Content-Type: ' + media, '--input', str(path), timeout=300)
                for _ in range(12):
                    a=next((a for a in draft()['assets'] if a['name']==name),None)
                    if a and a['state']=='uploaded' and a['size']==size and a.get('digest')==digest:break
                    time.sleep(2)
                else:raise RuntimeError('Uploaded asset has no matching digest')
                print(f'Verified {name}: {size} bytes',flush=True);break
            except (RuntimeError,subprocess.TimeoutExpired) as error:
                print(f'Upload attempt {attempt+1}/3 for {name}: {type(error).__name__}',flush=True)
                if attempt==2:raise
                time.sleep(3*(attempt+1))
        else:raise RuntimeError('Upload attempts exhausted')
    r=draft()
    for name,(size,digest) in metadata.items():
        a=next((a for a in r['assets'] if a['name']==name),None)
        if not a or a['state']!='uploaded' or a['size']!=size or a.get('digest')!=digest:raise RuntimeError('Incomplete release: '+name)
    if not current():print('Superseded during upload: left as an unpublished draft.');return
    gh('release','edit',tag,'-R',repo,'--draft=false','--latest',timeout=90)
    print('Published complete, verified release:',tag,flush=True)

if __name__=='__main__':main()
