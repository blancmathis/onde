#!/usr/bin/env python3
"""Selection != resume. Real native app, isolated profile, output always muted."""
import array,json,math,os,pathlib,shutil,subprocess,sys,tempfile,time,wave
root=pathlib.Path(__file__).resolve().parents[1]
app=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else root/'dist/Onde.app').resolve()
cli=app/'Contents/MacOS/ondectl'
profile=pathlib.Path(tempfile.mkdtemp(prefix='onde-select-',dir='/tmp'))
env=dict(os.environ,ONDE_HOME=str(profile));checks=[];process=None
log=(profile/'app.log').open('w')
def check(ok,label):
    if not ok: raise AssertionError(label)
    checks.append(label);print('PASS',label,flush=True)
def call(*args):
    p=subprocess.run([str(cli),*args],env=env,capture_output=True,text=True,timeout=45)
    if p.returncode:raise AssertionError((args,p.returncode,p.stdout,p.stderr))
    obj=json.loads(p.stdout)
    if not obj.get('ok'):raise AssertionError(obj)
    return obj['result']
def until(predicate,timeout=30):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        s=call('status')
        if predicate(s):return s
        time.sleep(.12)
    raise AssertionError(('Timeout',s))
def last_play():return next(e for e in reversed(call('events')) if e['type']=='play')
def ready(score):
    return until(lambda s:s['generator']['running'] and not s['generator']['loading'] and s['generator']['composition_id']==score and s['generator']['transition']['state']=='idle')
def assert_fresh(id,score,label):
    old=call('status');before=old['elapsed_seconds'];assert old['status']!='playing'
    result=call('generate','profile',id)
    trace=[result];end=time.monotonic()+30
    while time.monotonic()<end:
        s=call('status');g=s['generator'];trace.append(g)
        if g['running'] and not g['loading'] and g['entrance']['progress']>=1:break
        time.sleep(.15)
    else:raise AssertionError(('Selection did not become ready',trace[-1]))
    check(all(g['composition_id'] in (0,score) for g in trace),label+': no old scene becomes audible')
    check(all(g['transition']['state'] not in ('waiting_for_bar','crossfading') for g in trace),label+': no crossfade from paused scene')
    check(all(g['transition']['from']=='' for g in trace),label+': previous transition endpoints cleared')
    check(s['generator']['composition_id']==score,label+': requested composition playing')
    check(s['generator']['entrance']['seconds']==4,label+': full configured entrance, not resume fade')
    gains=[g['entrance']['gain'] for g in trace if g['running']]
    check(any(0<g<.95 for g in gains),label+': progressive entrance observed')
    check(last_play()['music_restarted'] is True,label+': explicit selection is a restart')
    check(s['elapsed_seconds']>=before,label+': session stopwatch not reset')
    check(s['generator']['rendered_seconds']<16,label+': new musical timeline')
    return s
try:
    process=subprocess.Popen([str(app/'Contents/MacOS/Onde')],env=env,stdout=log,stderr=log)
    # Process creation does not imply that the native IPC socket is ready.
    startup_deadline=time.monotonic()+45
    while time.monotonic()<startup_deadline:
        if process.poll() is not None:raise AssertionError('App exited during launch')
        response=subprocess.run([str(cli),'status'],env=env,capture_output=True,text=True,timeout=15)
        if response.returncode==0:
            s=json.loads(response.stdout)['result'];break
        if response.returncode!=3:raise AssertionError(('Startup failed',response.stdout,response.stderr))
        time.sleep(.2)
    else:raise AssertionError('App socket did not become ready')
    check(s['status']=='stopped','Launch does not autoplay')
    check(s['preferences']['startFadeSeconds']==8,'Existing eight-second default retained')
    call('volume','0');call('settings','preventSleep','false');call('settings','reducedMotion','true');call('settings','startFadeSeconds','4')
    prefs=call('status')['preferences']
    call('generate','profile','sillage');ready(1)
    until(lambda s:s['generator']['rendered_seconds']>16)
    call('pause');assert_fresh('ambre',5,'Different card after pause')
    until(lambda s:s['generator']['rendered_seconds']>15)
    call('pause');assert_fresh('ambre',5,'Same card after pause')
    # A genuine Play is still Resume, including retained generation state.
    old=call('pause');frames=old['generator']['rendered_seconds'];time.sleep(1.3)
    call('play');s=ready(5)
    check(not last_play()['music_restarted'],'Plain Play resumes rather than restarts')
    check(s['generator']['entrance']['seconds']==2,'Plain resume uses the short fade')
    check(s['generator']['rendered_seconds']>=frames,'Plain resume retains musical position')
    # Pause in the middle of a transition, then choose a third track immediately.
    call('generate','transition','10');call('generate','profile','meridien')
    until(lambda s:s['generator']['transition']['state']=='crossfading')
    check(True,'Live selection still crossfades normally')
    call('pause');assert_fresh('canopee',6,'Selection during a paused crossfade')
    # Preserve an explicitly prepared, not-yet-playing choice until Play.
    call('mix','save','Selection QA')
    call('generate','profile','sillage');ready(1);call('pause')
    pending=call('call',json.dumps({'command':'mix.load','id':'Selection QA','play':False}))
    check(pending['status']=='paused','Loading a mix without autoplay stays paused')
    call('play');s=ready(6)
    check(last_play()['music_restarted'],'Deferred saved mix selection restarts on Play')
    check(s['generator']['transition']['state']=='idle' and s['generator']['entrance']['seconds']==4,'Deferred selection has its own entrance only')
    # Use a long local recording to prove AVAudioPlayer rewinds instead of retaining its offset.
    original=profile/'test-recording.wav';sr=8000
    samples=array.array('h',(int(1200*math.sin(2*math.pi*220*i/sr)) for i in range(sr*30)))
    if sys.byteorder!='little':samples.byteswap()
    with wave.open(str(original),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(samples.tobytes())
    item=call('import',str(original),'--title','Selection test recording');id=item['id']
    call('pause');call('solo',id);call('play')
    until(lambda s:s['playback']['recorded_layers'].get(id,{}).get('position_seconds',0)>4)
    call('pause');time.sleep(.35);offset=call('status')['playback']['recorded_layers'][id]['position_seconds']
    call('solo',id);s=call('play');rec=s['playback']['recorded_layers'][id]
    check(offset>4 and rec['position_seconds']<1,'Re-selecting a recorded sound rewinds to its beginning')
    check(rec['entrance_seconds']==4,'Recorded selection receives full gentle entrance')
    check(not s['generator']['running'] and s['generator']['composition_id']==0,'Selecting recording discards cached synthesis')
    until(lambda s:s['playback']['recorded_layers'][id]['position_seconds']>3)
    call('pause');time.sleep(.35);offset=call('status')['playback']['recorded_layers'][id]['position_seconds']
    # play() starts AVAudioPlayer asynchronously. Validate actual continuation,
    # not the first timestamp read in the same command response. A one-second
    # readiness budget with an offset above three seconds cannot let a player
    # that incorrectly restarted at zero catch up and pass this assertion.
    resume_started=time.monotonic()
    s=call('play');first=dict(s['playback']['recorded_layers'][id])
    trace=[{'wall_seconds':time.monotonic()-resume_started,'recorded':first}]
    while s['playback']['recorded_layers'][id]['position_seconds']<offset and time.monotonic()-resume_started<1:
        time.sleep(.025);s=call('status')
        trace.append({'wall_seconds':time.monotonic()-resume_started,'recorded':s['playback']['recorded_layers'][id]})
    rec=s['playback']['recorded_layers'][id];observed=time.monotonic()-resume_started
    print('RECORDED_RESUME '+json.dumps({'paused_position':offset,'observed_seconds':observed,'trace':trace}),flush=True)
    check(not last_play()['music_restarted'],'Recorded Play is a resume, not an explicit selection')
    check(offset>3 and observed<min(2,offset/2) and rec['position_seconds']>=offset and rec['position_seconds']<offset+2 and first['entrance_seconds']==2 and rec['entrance_seconds']==2,'Recorded Play resumes position with short fade')
    call('pause');call('solo','piano');s=call('play')
    check(not s['playback']['recorded_layers'][id]['playing'],'Previously selected recording never restarts')
    check(s['playback']['recorded_layers']['piano']['position_seconds']<1,'Different recorded sound starts from beginning')
    call('stop');s=call('play')
    check(last_play()['music_restarted'] and s['playback']['recorded_layers']['piano']['entrance_seconds']==4,'Stop then Play starts fresh')
    check(s['preferences']==prefs,'Selections preserve every user preference and chime time')
    check(s['today_seconds']>0,'Daily activity survives musical restarts')
    call('pause');s=call('status');before=s['today_seconds'];time.sleep(.6)
    check(abs(call('status')['today_seconds']-before)<.05,'Paused activity remains excluded')
    check(s['preferences']['masterVolume']==0,'All tests stay muted')
    call('quit');process.wait(timeout=20)
    print(json.dumps({'ok':True,'passed':len(checks),'muted':True,'checks':checks},indent=2),flush=True)
finally:
    if process and process.poll() is None:
        process.terminate()
        try:process.wait(timeout=10)
        except subprocess.TimeoutExpired:process.kill()
    log.close()
    if sys.exc_info()[0] is None:shutil.rmtree(profile)
    else:print('Retained test profile',profile,file=sys.stderr)
