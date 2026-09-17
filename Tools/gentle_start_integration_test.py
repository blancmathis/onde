#!/usr/bin/env python3
"""Native playback/CLI regression; isolated profile, physically muted master volume."""
import json, os, pathlib, shutil, socket, subprocess, sys, tempfile, time
app=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'dist/Onde.app').resolve()
cli=app/'Contents/MacOS/ondectl'; profile=pathlib.Path(tempfile.mkdtemp(prefix='onde-start-',dir='/tmp'))
env=dict(os.environ,ONDE_HOME=str(profile)); checks=[]; process=None; log=(profile/'application.log').open('w')
def check(ok,label):
    if not ok: raise AssertionError(label)
    checks.append(label);print('PASS',label,flush=True)
def call(*args,expected=0):
    p=subprocess.run([str(cli),*args],env=env,capture_output=True,text=True,timeout=45)
    if p.returncode!=expected: raise AssertionError((args,p.returncode,p.stdout,p.stderr))
    data=json.loads(p.stdout); return data['result'] if expected==0 else data['error']
def launch():
    global process
    process=subprocess.Popen([str(app/'Contents/MacOS/Onde')],env=env,stdout=log,stderr=log)
    until=time.monotonic()+40
    while time.monotonic()<until:
        try:return call('status')
        except Exception:
            if process.poll() is not None:raise AssertionError('App exited')
            time.sleep(.2)
    raise AssertionError('App not ready')
def observed_status():
    # Inspect the same private IPC protocol without spawning a CLI executable for
    # each audio observation. Slow process launches can miss a two-second fade.
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
        client.settimeout(5);client.connect(str(profile/'control.sock'))
        client.sendall(b'{"command":"status"}\n');data=bytearray()
        while b'\n' not in data:
            block=client.recv(65536)
            if not block:raise AssertionError('Incomplete status response')
            data.extend(block)
            if len(data)>2_000_000:raise AssertionError('Oversized status response')
    response=json.loads(data.split(b'\n',1)[0])
    if not response.get('ok'):raise AssertionError(response)
    return response['result']
def envelope(source):
    s=observed_status()
    if source=='living':
        g=s['generator'];e=g['entrance'];return s,e['gain'],e['progress'],e['seconds'],g['actual_gain']
    e=s['playback']['recorded_layers'][source]
    return s,e['entrance_gain'],e['entrance_progress'],e['entrance_seconds'],e['output_gain']
def observe(source,seconds,label,edit=False):
    values=[];edited=False;deadline=time.monotonic()+seconds+35
    while time.monotonic()<deadline:
        s,g,p,d,out=envelope(source)
        # A paused envelope may be published until the render thread consumes
        # Play. Wait for an actual entrance observation, never fabricate one.
        if g==0 and p==1 and not values:
            time.sleep(.02);continue
        values.append((g,p,d))
        check(out==0 and s['preferences']['masterVolume']==0,label+' remains muted') if len(values)==1 else None
        if out!=0: raise AssertionError('Test must not emit audio')
        if .04<p<.55 and edit and not edited:
            if source=='living':call('generate','set','brightness','.22')
            else:call('sound',source,'on','--volume','.43')
            edited=True
        if p>=1 and g==1:break
        time.sleep(.08)
    check(values[-1][0]==1 and values[-1][1]==1,label+' reaches full envelope')
    check(any(0<g<.15 for g,p,d in values),label+' begins quietly')
    check(len([p for g,p,d in values if 0<p<1])>=3,label+' progresses through intermediate levels')
    check(all(b[0]+.00001>=a[0] and b[1]+.00001>=a[1] for a,b in zip(values,values[1:])),label+' never restarts or jumps backward')
    check(all(abs(g-(p*p*(3-2*p))**2)<.0001 for g,p,d in values),label+' follows the shared smooth curve')
    check(all(abs(d-seconds)<.001 for g,p,d in values),label+' reports the intended duration')
    if edit:check(edited,label+' parameters can change during the entrance')
try:
    s=launch();check(s['status']=='stopped','No autoplay')
    check(s['preferences']['startFadeSeconds']==8,'Default gentle start is eight seconds')
    call('volume','0');call('settings','reducedMotion','true');call('timer','markers','10,20,30,40')
    call('generate','profile','sillage');observe('living',8,'Generator start',edit=True)
    call('pause');time.sleep(1.3);s,g,p,d,out=envelope('living')
    check(g==0 and out==0 and not s['generator']['running'],'Pause reaches silence')
    elapsed=s['elapsed_seconds'];time.sleep(.2);check(abs(call('status')['elapsed_seconds']-elapsed)<.01,'Pause still freezes stopwatch')
    call('play');observe('living',2,'Generator resume')
    before=call('status')['elapsed_seconds'];call('generate','transition','2');call('generate','profile','meridien')
    end=time.monotonic()+25
    while time.monotonic()<end:
        s,g,p,d,out=envelope('living')
        if g<.9999:raise AssertionError('Crossfade must not re-enter from silence')
        if s['generator']['composition_id']==7 and s['generator']['transition']['state']=='idle' and not s['generator']['loading']:break
        time.sleep(.15)
    check(s['generator']['composition_id']==7 and g==1,'Scene handover preserves full transport envelope')
    check(s['elapsed_seconds']>=before,'Crossfade preserves stopwatch')
    call('stop');time.sleep(1.3);call('play');observe('living',8,'New session after stop')
    call('stop');time.sleep(1.3);call('silence');call('sound','rain','on');call('play')
    observe('rain',8,'Recorded layer start',edit=True)
    call('pause');time.sleep(1.3);s,g,p,d,out=envelope('rain')
    check(g==0 and out==0 and not s['playback']['recorded_layers']['rain']['playing'],'Recorded pause reaches silence')
    call('play');observe('rain',2,'Recorded layer resume')
    call('stop');time.sleep(1.3);call('settings','startFadeSeconds','0');call('play');time.sleep(.5)
    s,g,p,d,out=envelope('rain');check(g==1 and d==0,'Gentle start can be disabled explicitly')
    call('pause');call('settings','startFadeSeconds','12')
    for value in ['-1','21']:
        check(call('settings','startFadeSeconds',value,expected=2)['code']=='invalid_argument','Reject startFadeSeconds '+value)
    check(call('call','{"command":"settings","key":"startFadeSeconds","value":true}',expected=2)['code']=='invalid_argument','Reject boolean fade duration')
    saved=call('status');call('quit');process.wait(timeout=20);s=launch()
    check(s['status']=='stopped','Restart never autoplays')
    check(s['preferences']['startFadeSeconds']==12,'Gentle-start duration persists')
    check(s['preferences']['markers']==[600,1200,1800,2400] and s['preferences']['masterVolume']==0,'Chimes and user volume remain unchanged')
    check(abs(s['today_seconds']-saved['today_seconds'])<.1,'Playback fade does not corrupt daily accounting')
    call('quit');process.wait(timeout=20)
    print(json.dumps({'ok':True,'passed':len(checks),'muted':True,'checks':checks},indent=2),flush=True)
finally:
    if process and process.poll() is None:
        process.terminate()
        try:process.wait(timeout=10)
        except subprocess.TimeoutExpired:process.kill()
    log.close()
    if sys.exc_info()[0] is None:shutil.rmtree(profile)
    else:print('Isolated test profile retained:',profile,file=sys.stderr)
