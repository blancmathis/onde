#!/usr/bin/env python3
"""Muted real native app, isolated profile. No writes to the user's preferences."""
import json,os,pathlib,subprocess,time,tempfile,shutil,sys
app=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'dist/Onde.app').resolve();cli=app/'Contents/MacOS/ondectl'
profile=pathlib.Path(tempfile.mkdtemp(prefix='onde-xfade-',dir='/tmp'));env=dict(os.environ,ONDE_HOME=str(profile));checks=[];process=None
log=(profile/'app.log').open('w')
def call(*args,expected=0):
 p=subprocess.run([str(cli),*args],env=env,capture_output=True,text=True,timeout=45)
 if p.returncode!=expected:raise AssertionError((args,p.returncode,p.stdout,p.stderr))
 data=json.loads(p.stdout)
 return data['result'] if expected==0 else data['error']
def check(ok,description):
 if not ok:raise AssertionError(description)
 checks.append(description);print('PASS',description,flush=True)
def launch():
 global process
 process=subprocess.Popen([str(app/'Contents/MacOS/Onde')],env=env,stdout=log,stderr=log)
 for _ in range(70):
  if process.poll()!=None:raise AssertionError('Native app exited')
  try:return call('status')
  except Exception:time.sleep(.3)
 raise AssertionError('App not ready')
def wait_profile(id,seconds=50):
 deadline=time.monotonic()+seconds;seen=[]
 while time.monotonic()<deadline:
  g=call('generate','status');t=g.get('transition',{});seen.append(t.get('state'))
  if g.get('last_error'):raise AssertionError(g)
  if not g.get('loading') and t.get('state')=='idle' and not t.get('queued') and g['configuration'].get('profileID')==id and g['composition_id']==scores[id] and g['running']:return g,seen
  time.sleep(.2)
 raise AssertionError(('Transition timeout',g,seen))
try:
 scores={p['id']:int(p['configuration']['composition']) for p in call('generate','profiles')}
 s=launch();check(s['status']=='stopped','Startup does not autoplay')
 call('volume','0');call('settings','reducedMotion','true');call('generate','transition','4')
 call('timer','markers','10,20,30,40');prefs=call('status')['preferences']
 call('generate','profile','sillage');g,seen=wait_profile('sillage')
 check(g['orchestra_samples']==76,'Verified bank preloaded before transition')
 check(g['running'] and g['rendered_seconds']>0,'Actual initial audio callback observed')
 start=call('status')['elapsed_seconds'];call('generate','profile','ambre');g,seen=wait_profile('ambre')
 check('crossfading' in seen,'Crossfade state observed in real audio engine')
 check(call('status')['elapsed_seconds']>=start+3,'Switching focus composition preserves session stopwatch')
 check(g['composition_id']==5,'New acoustic/electric scene is active after handover')
 call('generate','profile','canopee');call('generate','profile','sanctuaire');call('generate','profile','meridien')
 g,seen=wait_profile('meridien',75)
 check(g['composition_id']==7 and not g['transition']['queued'],'Rapid selections finish on last requested scene')
 check(g['output_peak']==0,'Muted test never raises audio output')
 call('generate','profile','sanctuaire');time.sleep(.5);p=call('pause')['elapsed_seconds'];time.sleep(1.5)
 check(abs(call('status')['elapsed_seconds']-p)<.05,'Pause during preparation/transition freezes stopwatch')
 check(not call('generate','status')['running'],'Pause during transition stops playback')
 call('play');g,seen=wait_profile('sanctuaire')
 check(g['choir_voices']>0,'Resume finishes transition into the wordless choir')
 call('silence');time.sleep(1.4);s=call('status')
 check(s['status']=='playing' and s['active_sound_ids']==[],'Silence retains the session timer')
 check(not call('generate','status')['running'],'Silence stops all crossfading scenes')
 check(s['preferences']==prefs,'Transitions preserve master volume and chimes')
 check(call('generate','transition','31',expected=2)['code']=='invalid_argument','Reject unsafe/out-of-range transition duration')
 check(call('call','{"command":"generate.transition","seconds":true}',expected=2)['code']=='invalid_argument','Reject boolean transition duration')
 call('generate','transition','7');call('stop');call('quit');process.wait(timeout=15)
 s=launch();check(s['status']=='stopped','Restart after a transition stays silent')
 g=call('generate','status');check(g['transition']['seconds']==7,'Transition duration persists across restart')
 check(s['preferences']==prefs,'Personal chime configuration survives restart')
 call('quit');process.wait(timeout=15)
 print(json.dumps({'ok':True,'passed':len(checks),'audio_muted':True,'checks':checks},indent=2),flush=True)
finally:
 if process and process.poll() is None:
  process.terminate()
  try:process.wait(timeout=10)
  except subprocess.TimeoutExpired:process.kill()
 log.close()
 if sys.exc_info()[0] is None:shutil.rmtree(profile)
 else:print('Retained isolated test profile:',profile,file=sys.stderr)
