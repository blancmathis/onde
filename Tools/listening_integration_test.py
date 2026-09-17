#!/usr/bin/env python3
"""One-screen listening flow, real native audio, temporary profile and muted output.

CLI mutations and newline-framed local IPC observations exercise the same model
as the UI. No changes are made to the user's library or audio output volume.
"""
import array, json, math, os, pathlib, shutil, socket, subprocess, sys, tempfile, time, wave
root = pathlib.Path(__file__).resolve().parents[1]
app = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else root/'dist/Onde.app').resolve()
cli = app/'Contents/MacOS/ondectl'
profile = pathlib.Path(tempfile.mkdtemp(prefix='onde-listen-', dir='/tmp'))
env = dict(os.environ, ONDE_HOME=str(profile)); checks = []; process = None
log = (profile/'app.log').open('w')
def check(ok, label):
    if not ok: raise AssertionError(label)
    checks.append(label); print('PASS', label, flush=True)
def ipc(command='status', **data):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(30); client.connect(str(profile/'control.sock'))
        client.sendall(json.dumps(dict(command=command, **data)).encode()+b'\n'); buffer=bytearray()
        while b'\n' not in buffer:
            block=client.recv(65536)
            if not block: raise AssertionError('Incomplete reply')
            buffer.extend(block)
            if len(buffer)>2_000_000: raise AssertionError('Oversized reply')
    reply=json.loads(buffer.split(b'\n',1)[0])
    if not reply['ok']: raise AssertionError(reply)
    return reply['result']
def call(*args, expected=0):
    p=subprocess.run([str(cli), *args], env=env, text=True, capture_output=True, timeout=60)
    if p.returncode!=expected: raise AssertionError((args,p.returncode,p.stdout,p.stderr))
    d=json.loads(p.stdout);return d['result'] if expected==0 else d['error']
def wait(test, timeout=45):
    end=time.monotonic()+timeout;s=None
    while time.monotonic()<end:
        s=ipc()
        if s['preferences']['masterVolume']!=0: raise AssertionError('Tests must remain muted')
        if s.get('last_error') or s['generator'].get('last_error'):raise AssertionError(s)
        if test(s):return s
        time.sleep(.12)
    raise AssertionError(('Timed out',s))
def ready(id):
    return wait(lambda s:s['generator']['configuration'].get('profileID')==id and s['generator']['running'] and not s['generator']['loading'] and s['generator']['transition']['state']=='idle' and not s['generator']['transition']['queued'] and abs(s['generator']['bpm']-s['generator']['configuration']['tempo'])<0.5)
def launch():
    global process
    process=subprocess.Popen([str(app/'Contents/MacOS/Onde')], env=env, stdout=log, stderr=log)
    end=time.monotonic()+60
    while time.monotonic()<end:
        if process.poll() is not None:raise AssertionError('App exited')
        try:return ipc()
        except (OSError, AssertionError):time.sleep(.25)
    raise AssertionError('App did not start')
def quit():
    ipc('quit');process.wait(timeout=25)
try:
    focused=call('music','list','focus');relaxed=call('music','list','relax');med=call('music','list','meditation')
    check(len(focused)==17,'All seventeen Focus choices remain available')
    check([p['id'] for p in relaxed]==[p['id'] for p in med]==['lagoon','stillwater','hearth','reverie','driftwood','velours','rive','immersion'],'Relax and Meditation share the same eight choices')
    # A genuine old-format profile with preferences and saved content to preserve.
    conf=next(p['configuration'] for p in focused if p['id']=='ambre');conf['bass']=.77
    prefs=dict(masterVolume=0,chimeVolume=.21,fadeSeconds=2,startFadeSeconds=4,markers=[600,1200,1800,2400],chimesEnabled=True,preventSleep=False,reducedMotion=True)
    old=dict(version=1,mode='focus',layers={'living':{'enabled':True,'volume':.68},'pink':{'enabled':True,'volume':.18}},modeMixes={},imported=[],mixes=[],history=[],preferences=prefs,generatorSettings={'focus':conf},transitionSeconds=2)
    (profile/'state.json').write_text(json.dumps(old))
    s=launch();check(s['status']=='stopped','Migration never autoplays')
    check(s['preferences']==prefs,'Every preference including chimes is preserved')
    check(s['listening']['defaults']['focus']=='ambre','Existing Focus choice becomes the initial default')
    check(s['generator']['configuration']['bass']==.77 and s['layers']==old['layers'],'Tuning and layers survive migration untouched')
    # Default selection is independent of the actual musical timeline.
    baseline=ipc();s=call('music','default','focus','sillage')
    current=ipc();check(current['status']=='stopped' and current['generator']['configuration']==baseline['generator']['configuration'],'Setting a default does not start or switch the music')
    check(call('music','defaults')['focus']=='sillage','Default exposed through CLI')
    check(call('music','default','meditation','sillage',expected=2)['code']=='wrong_catalog','Focus cannot become a Meditation default')
    check(call('music','default','relax','missing',expected=2)['code']=='not_found','Unknown defaults rejected')
    check(call('music','play','sillage','--mode','relax',expected=2)['code']=='wrong_catalog','Wrong-catalog playback rejected without state changes')
    call('focus');s=ready('sillage');check(s['mode']=='focus','Focus button uses explicit saved default')
    check(s['listening']['background']=={'kind':'pink','volume':.18},'Initial background survives choosing music')
    # Real noise resource and mixing without rebuilding a piece.
    white=app/'Contents/Resources/Sounds/white.wav'
    with wave.open(str(white)) as f:
        check(f.getnchannels()==2 and f.getframerate()==44100 and f.getnframes()==2646000,'White noise is a real included stereo resource')
        values=array.array('h',f.readframes(44100))
        if sys.byteorder!='little':values.byteswap()
        rms=math.sqrt(sum((x/32768)**2 for x in values)/len(values))
        check(.065<rms<.075 and abs(sum(values)/len(values))<200,'White noise has controlled level and negligible DC')
    wait(lambda s:s['generator']['entrance']['progress']==1)
    before=ipc();call('background','white','.23');s=wait(lambda s:s['playback']['recorded_layers'].get('white',{}).get('playing'))
    check(set(s['active_sound_ids'])=={'living','white'},'Background changes do not stack hidden noise layers')
    check(s['generator']['entrance']['serial']==before['generator']['entrance']['serial'],'Adding noise does not restart music or its entrance')
    check(s['elapsed_seconds']>=before['elapsed_seconds'],'Background edits preserve session time')
    check(s['preferences']==prefs,'Background edits do not change master volume or chimes')
    call('music','volume','.43');s=ipc();check(s['layers']['living']['volume']==.43 and s['layers']['white']['volume']==.23,'Music and background levels are independent')
    ipc('generate.set',key='warmth',value=.81)
    before=ipc()['elapsed_seconds'];call('music','play','ambre');s=ready('ambre')
    check(s['elapsed_seconds']>=before and s['layers']['white']['enabled'],'Choosing music preserves time and background')
    check(s['generator']['configuration']['bass']==.77,'Returning to music restores its personal sound tuning')
    check(s['listening']['defaults']['focus']=='sillage','Trying music does not overwrite the chosen default')
    call('focus');s=ready('sillage');check(s['generator']['configuration']['warmth']==.81,'Mode shortcut restores default with its saved tuning')
    check(s['layers']['living']['volume']==.43,'Music level stays consistent across music choices')
    call('pause');before=ipc();call('background','brown','.12');s=ipc()
    check(s['status']=='paused' and not s['generator']['running'],'Changing background while paused does not autoplay')
    check(abs(s['today_seconds']-before['today_seconds'])<.05,'Background edits while paused do not count as activity')
    result=call('music','play','meridien');trace=[result]
    end=time.monotonic()+45
    while time.monotonic()<end:
        s=ipc();trace.append(s)
        if s['generator']['running'] and s['generator']['entrance']['progress']==1:break
        time.sleep(.12)
    check(all(s['generator']['composition_id'] in (0,7) for s in trace),'Paused selection never revives the previous music')
    check(all(s['generator']['transition']['state'] not in ('crossfading','waiting_for_bar') for s in trace),'Paused selection has a fresh entrance, no old-scene crossfade')
    check(s['generator']['entrance']['first_gain']==0 and s['generator']['entrance']['seconds']==4,'Configured gentle start is preserved')
    # Separate defaults and backgrounds, common Relax music.
    call('music','default','relax','rive');call('music','default','meditation','velours')
    call('relax');s=ready('rive');check(s['mode']=='relax' and s['next_chime_seconds'] is None,'Relax default plays without chimes')
    call('background','ocean','.09');call('meditate');s=ready('velours')
    check(s['mode']=='meditation' and s['next_chime_seconds']==600,'Meditation starts its own default and chime timer')
    check(s['listening']['catalog']=='relax' and s['listening']['background']['kind']=='off','Meditation uses Relax catalog, independent background')
    before=s['elapsed_seconds'];call('music','play','rive');s=ready('rive')
    check(s['mode']=='meditation' and s['elapsed_seconds']>=before,'Choosing Relax music never switches out of Meditation or resets practice')
    check(s['next_chime_seconds']==600 and s['preferences']['markers']==prefs['markers'],'Meditation chimes survive music changes')
    check(s['listening']['defaults']['meditation']=='velours' and s['listening']['defaults']['relax']=='rive','Relax and Meditation defaults stay independent')
    call('background','white','0');s=ipc()
    check(s['listening']['background']=={'kind':'white','volume':0} and not s['layers']['white']['enabled'],'Zero background is silent but remembers its color')
    call('background','white','.05');call('background','off');s=ipc()
    check(s['active_sound_ids']==['living'],'Background off leaves music playing')
    call('relax');s=ready('rive');check(s['layers']['ocean']['enabled'] and s['layers']['ocean']['volume']==.09,'Relax restores its own background level')
    call('focus');s=ready('sillage');check(s['layers']['brown']['enabled'] and s['layers']['brown']['volume']==.12,'Focus restores its own background after other modes')
    call('background','white','2',expected=2);check(True,'Out-of-range background rejected')
    call('background','unknown',expected=2);check(True,'Unknown background rejected')
    call('music','volume','-1',expected=2);check(True,'Invalid music level rejected')
    check(call('call','{"command":"music.select","id":"sillage","mode":false}',expected=2)['code']=='invalid_mode','Malformed mode is not silently ignored')
    check(call('call','{"command":"music.select","id":"sillage","play":1}',expected=2)['code']=='invalid_argument','Numeric autoplay is not coerced into a boolean')
    # Compatibility routes are sheets rather than primary navigation pages.
    call('ui','page','library');check(ipc()['listening']['sheet']=='personal','Legacy library command opens optional personal tools')
    call('ui','page','settings');check(ipc()['listening']['sheet']=='settings','Settings remain accessible from CLI')
    call('ui','page','generative');check(ipc()['listening']['sheet'] is None,'Old generative route returns to the single listening screen')
    call('pause');saved=ipc();quit();s=launch()
    check(s['status']=='stopped','Restart stays silent')
    check(s['listening']['defaults']==saved['listening']['defaults'],'All mode defaults survive restart')
    check(s['listening']['background']==saved['listening']['background'],'Background setting survives restart')
    check(s['preferences']==prefs,'User settings and chimes survive restart')
    check(abs(s['today_seconds']-saved['today_seconds'])<.1,'UI redesign preserves the daily activity ledger')
    quit()
    print(json.dumps({'ok':True,'passed':len(checks),'muted':True,'checks':checks},indent=2),flush=True)
finally:
    if process and process.poll() is None:
        process.terminate()
        try:process.wait(timeout=15)
        except subprocess.TimeoutExpired:process.kill()
    log.close()
    if sys.exc_info()[0] is None:shutil.rmtree(profile)
    else:print('Retained isolated profile:',profile,file=sys.stderr)
