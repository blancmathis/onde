#!/usr/bin/env python3
"""Five relaxation worlds: packaged native app, private test profile, muted output."""
import json,os,pathlib,re,shutil,socket,subprocess,sys,tempfile,time
root=pathlib.Path(__file__).resolve().parents[1]
app=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else root/'dist/Onde.app').resolve()
cli=app/'Contents/MacOS/ondectl';profile=pathlib.Path(tempfile.mkdtemp(prefix='onde-relax-',dir='/tmp'))
env=dict(os.environ,ONDE_HOME=str(profile));checks=[];process=None;log=(profile/'app.log').open('w')
ids=['lagoon','stillwater','hearth','reverie','driftwood']
def check(ok,label):
    if not ok:raise AssertionError(label)
    checks.append(label);print('PASS',label,flush=True)
def call(*args):
    p=subprocess.run([str(cli),*args],env=env,capture_output=True,text=True,timeout=60)
    if p.returncode:raise AssertionError((args,p.returncode,p.stdout,p.stderr))
    return json.loads(p.stdout)['result']
def ipc(command='status',**args):
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as s:
        s.settimeout(30);s.connect(str(profile/'control.sock'))
        s.sendall(json.dumps(dict(command=command,**args)).encode()+b'\n');buf=bytearray()
        while b'\n' not in buf:
            part=s.recv(65536)
            if not part:raise AssertionError('Incomplete JSON reply')
            buf.extend(part)
            if len(buf)>2_000_000:raise AssertionError('Oversized JSON reply')
    d=json.loads(buf.split(b'\n',1)[0])
    if not d.get('ok'):raise AssertionError(d)
    return d['result']
def wait(test,timeout=50):
    end=time.monotonic()+timeout;s=None
    while time.monotonic()<end:
        s=ipc()
        if s['preferences']['masterVolume']!=0:raise AssertionError('Test must stay muted')
        if s.get('last_error') or s['generator'].get('last_error'):raise AssertionError(s)
        if test(s):return s
        time.sleep(.12)
    raise AssertionError(('Timeout',s))
def ready(id):
    score=ids.index(id)+8
    return wait(lambda s:s['generator']['running'] and not s['generator']['loading'] and s['generator']['composition_id']==score and s['generator']['transition']['state']=='idle' and not s['generator']['transition']['queued'])
def launch():
    global process
    process=subprocess.Popen([str(app/'Contents/MacOS/Onde')],env=env,stdout=log,stderr=log)
    end=time.monotonic()+60
    while time.monotonic()<end:
        if process.poll() is not None:raise AssertionError('App exited')
        try:return ipc()
        except OSError:time.sleep(.2)
    raise AssertionError('App not ready')
try:
    relax=call('music','list','relax');med=call('music','list','meditation')
    check([p['id'] for p in relax]==ids+['velours','rive','immersion'],'Five new scores plus all existing relaxation music')
    check(relax==med,'Meditation and Relax have identical catalogs and scores')
    check(len(call('music','list','focus'))==17,'All seventeen Focus choices unchanged')
    s=launch();check(s['status']=='stopped','No autoplay')
    call('volume','0');call('settings','preventSleep','false');call('settings','reducedMotion','true')
    call('settings','startFadeSeconds','2');call('generate','transition','2');call('timer','markers','10,20,30,40')
    prefs=ipc()['preferences'];defaults=call('music','defaults')
    for id in ids:
        call('pause');call('music','play',id,'--mode','relax');s=ready(id)
        s=wait(lambda s:s['generator']['entrance']['progress']==1)
        g=s['generator']
        check(s['mode']=='relax' and s['listening']['selected_music_id']==id,'Actual native playback '+id)
        check(g['chapter_bars']==96 and g['phrase_bars']==8,'Long-form arrangement '+id)
        check(g['transition']['from']=='' and g['transition']['state']=='idle','No cached-track revival '+id)
        check(g['entrance']['first_gain']==0 and g['entrance']['intermediate_frames']>0,'Fresh gentle entrance '+id)
        check(g['configuration']['punch']==0 and g['configuration']['drive']==0,'No energetic percussion rack '+id)
        check(g['grain_events']==0 and not g['noise_layer_enabled'],'No forced digital noise '+id)
        if id!='lagoon':check(g['orchestra_samples']==76 and g['orchestra_events']>0,'Actual acoustic source events '+id)
        if id=='reverie':check(g['choir_voices']>0 and g['vocal_source']=='original_synthesized_vowels','Wordless choir is correctly identified')
        check(s['preferences']==prefs and s['listening']['defaults']==defaults,'Personal defaults, volume and chimes unchanged '+id)
    # Every new target participates in a real live crossfade, without resetting time.
    for id in ids:
        before=ipc()['elapsed_seconds'];call('music','play',id,'--mode','relax');trace=[]
        end=time.monotonic()+50
        while time.monotonic()<end:
            s=ipc();g=s['generator'];trace.append(g['transition']['state'])
            if g['composition_id']==ids.index(id)+8 and g['transition']['state']=='idle' and not g['loading'] and not g['transition']['queued']:break
            time.sleep(.10)
        else:raise AssertionError('Transition stalled '+id)
        check('crossfading' in trace,'Live crossfade observed '+id)
        check(s['elapsed_seconds']>=before and s['generator']['entrance']['gain']==1,'Crossfade preserves time and transport '+id)
    call('music','default','meditation','reverie');call('meditate');s=ready('reverie')
    call('background','pink','.11');before=ipc()['elapsed_seconds']
    call('music','play','hearth');s=ready('hearth')
    check(s['mode']=='meditation' and s['elapsed_seconds']>=before,'Relax selection preserves active meditation')
    check(s['next_chime_seconds']==600 and s['preferences']['markers']==prefs['markers'],'Meditation chimes remain independent')
    check(s['listening']['background']=={'kind':'pink','volume':.11},'Background stays in place across music')
    check(s['listening']['defaults']['relax']==defaults['relax'],'New meditation default does not change Relax default')
    call('music','play','reverie');s=ready('reverie');before=s['generator']['rendered_seconds']
    call('generate','set','vocals','0');s=ipc()
    check(s['generator']['configuration']['vocals']==0 and s['generator']['rendered_seconds']>=before,'Removing voices retains the accompaniment timeline')
    call('pause');s=ipc();daily=s['today_seconds'];time.sleep(.5)
    check(abs(ipc()['today_seconds']-daily)<.05,'Paused listening is not counted as activity')
    call('quit');process.wait(timeout=20);s=launch()
    check(s['status']=='stopped','Restart is silent')
    check(s['listening']['defaults']['meditation']=='reverie','New default persists')
    check(s['preferences']==prefs,'Existing preferences preserved on restart')
    check(s['generator']['configuration']['vocals']==0,'Customized new music persists')
    check(abs(s['today_seconds']-daily)<.1,'Daily ledger survives the new collection')
    call('quit');process.wait(timeout=20)
    print(json.dumps({'ok':True,'passed':len(checks),'muted':True,'checks':checks},indent=2),flush=True)
finally:
    if process and process.poll() is None:
        process.terminate()
        try:process.wait(timeout=15)
        except subprocess.TimeoutExpired:process.kill()
    log.close()
    if sys.exc_info()[0] is None:shutil.rmtree(profile)
    else:print('Retained profile',profile,file=sys.stderr)
