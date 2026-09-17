#!/usr/bin/env python3
"""Native app/CLI regression for Living III. Isolated profile and muted output."""
import json,os,pathlib,subprocess,sys,tempfile,time,shutil,wave
app=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'dist/Onde.app').resolve()
cli=app/'Contents/MacOS/ondectl';profile=pathlib.Path(tempfile.mkdtemp(prefix='onde-profiles-',dir='/tmp'))
env=dict(os.environ,ONDE_HOME=str(profile));checks=[];process=None;log=(profile/'application.log').open('w')
def check(ok,title):
 if not ok:raise AssertionError(title)
 checks.append(title);print('PASS',title,flush=True)
def call(*args,expected=0):
 p=subprocess.run([str(cli),*args],env=env,capture_output=True,text=True,timeout=45)
 if p.returncode!=expected:raise AssertionError(f'{args}: {p.returncode}: {p.stdout} {p.stderr}')
 data=json.loads(p.stdout)
 return data['result'] if expected==0 else data['error']
def launch():
 global process
 process=subprocess.Popen([str(app/'Contents/MacOS/Onde')],env=env,stdout=log,stderr=log)
 time.sleep(10)
 for _ in range(20):
  if process.poll()!=None:raise AssertionError('App exited')
  try:return call('status')
  except Exception:time.sleep(.5)
 raise AssertionError('App not ready')
try:
 profiles=call('generate','profiles');check(len(profiles)==25,'Twenty-five profiles listed without running app')
 check(len([p for p in profiles if p['mode']=='focus'])==17,'Seventeen distinct focus profiles')
 s=launch();check(s['status']=='stopped','No playback at launch')
 call('generate','transition','2');call('volume','0');call('settings','fadeSeconds','0');call('settings','reducedMotion','true');call('timer','markers','10,20,30,40')
 prefs=call('status')['preferences']
 for p in profiles:
  g=call('generate','profile',p['id']);check(g['configuration']==p['configuration'],'Exact configuration '+p['id'])
  check(g['title']==p['title'],'Profile display name '+p['id'])
  time.sleep(1.0);g=call('generate','status')
  # The engine smooths tempo on its audio clock. Wait for the observable state,
  # not a fixed wall-clock delay that fails when the machine is temporarily busy.
  deadline=time.monotonic()+35
  while (abs(g['bpm']-p['configuration']['tempo'])>=1.0 or g.get('loading') or g.get('transition',{}).get('state')!='idle' or g.get('transition',{}).get('queued')) and time.monotonic()<deadline:
   time.sleep(.25);g=call('generate','status')
  s=call('status')
  if p['configuration']['orchestra']>0:
   # Some authored scores deliberately introduce an acoustic answer after four
   # bars. Test the actual entrance, rather than requiring piano on the first beat.
   deadline=time.monotonic()+35
   while not (g['orchestra_events']>0 and g['orchestra_voices']>0) and time.monotonic()<deadline:
    time.sleep(.2);g=call('generate','status')
   check(g['sample_based'] and g['orchestra_samples']==76,'Verified acoustic bank '+p['id'])
   check(g['orchestra_events']>0 and g['orchestra_voices']>0,'Real acoustic note playback '+p['id'])
  check(g['engine']=='onde-living-7' and g['running'] and g['rendered_seconds']>0,'Native live audio '+p['id'])
  check(abs(g['bpm']-p['configuration']['tempo'])<1.0,'Tempo converges '+p['id'])
  check(not g['noise_layer_enabled'] and not g['granular_layer_enabled'] and g['grain_events']==0,'No noise/granular layer '+p['id'])
  check(s['preferences']==prefs,'Global volume and chimes unchanged '+p['id'])
 call('generate','set','bass','.83');call('generate','set','tempo','69');call('generate','set','warmth','.91')
 call('mix','save','QA profile');g=call('generate','status');check(g['configuration']['bass']==.83 and g['configuration']['tempo']==69,'New controls saved')
 call('generate','profile','courant');call('mix','load','QA profile');g=call('generate','status')
 check(g['configuration']['profileID']=='immersion' and g['configuration']['tempo']==69 and g['configuration']['warmth']==.91,'Mix restores profile and controls')
 check(call('generate','profile','nonexistent',expected=2)['code']=='not_found','Unknown profile rejected')
 check(call('generate','set','bass','2',expected=2)['code']=='invalid_argument','Invalid bass rejected')
 check(call('generate','set','tempo','0',expected=2)['code']=='invalid_argument','Invalid tempo rejected')
 check(call('call','{"command":"generate.set","key":"bass","value":true}',expected=2)['code']=='invalid_argument','Boolean bass rejected')
 call('pause');call('quit');process.wait(timeout=20)
 s=launch();g=call('generate','status');check(s['status']=='stopped','Restart without autoplay')
 check(g['configuration']['tempo']==69 and g['configuration']['bass']==.83 and g['configuration']['profileID']=='immersion','New settings survive restart')
 check(s['preferences']==prefs,'Original chime settings survive restart')
 call('quit');process.wait(timeout=20)
 wav=profile/'abysses.wav';r=call('generate','render','abysses',str(wav),'--seconds','2')
 check(r['configuration']['profileID']=='abysses' and r['configuration']['tempo']==64 and r['engine']=='onde-living-7','Offline named-profile render')
 with wave.open(str(wav)) as f:check(f.getnframes()==88200 and f.getnchannels()==2,'Rendered WAV duration and channels')
 check(r['peak']>0 and r['audio_origin']=='local_generation','Original audible PCM with local generation provenance')
 print(json.dumps({'ok':True,'passed':len(checks),'audio_muted':True,'checks':checks},indent=2),flush=True)
finally:
 if process and process.poll()==None:
  process.terminate()
  try:process.wait(timeout=10)
  except subprocess.TimeoutExpired:process.kill()
 log.close()
 if sys.exc_info()[0] is None:shutil.rmtree(profile)
 else:print('Retained test profile',profile,file=sys.stderr)
