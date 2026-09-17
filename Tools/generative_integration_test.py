#!/usr/bin/env python3
"""Real native app + CLI; temporary profile, intentionally muted output."""
import json,os,pathlib,subprocess,sys,tempfile,time,shutil,wave,hashlib
app=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'dist/Onde.app').resolve()
cli=app/'Contents/MacOS/ondectl'; profile=pathlib.Path(tempfile.mkdtemp(prefix='onde-living-',dir='/tmp')); env=dict(os.environ,ONDE_HOME=str(profile)); checks=[]; process=None
log=(profile/'app.log').open('w')
def check(value,label):
 if not value:raise AssertionError(label)
 checks.append(label);print('PASS',label,flush=True)
def call(*args,expected=0):
 p=subprocess.run([str(cli),*args],env=env,capture_output=True,text=True,timeout=45)
 if p.returncode!=expected:raise AssertionError(f'{args}: {p.returncode} {p.stdout} {p.stderr}')
 o=json.loads(p.stdout);check_ok=o.get('ok')
 if check_ok!=(expected==0):raise AssertionError(o)
 return o['result'] if expected==0 else o['error']
def launch():
 global process
 process=subprocess.Popen([str(app/'Contents/MacOS/Onde')],env=env,stdout=log,stderr=log)
 for _ in range(60):
  if process.poll()!=None:raise AssertionError('App exited')
  try:s=call('status');time.sleep(10);return call('status')
  except Exception:time.sleep(.2)
 raise AssertionError('App not ready')
try:
 check(len(call('generate','presets'))==3,'Three offline generative presets')
 s=launch();check(s['status']=='stopped','No automatic playback after migration')
 call('generate','transition','2');call('volume','0');call('settings','fadeSeconds','0');call('settings','reducedMotion','true');call('timer','markers','10,20,30,40')
 for mode,seed in [('focus','42'),('relax','314'),('meditation','2718')]:
  call('generate','play',mode,'--seed',seed)
  # Core Audio may reconfigure its device asynchronously on a heavily loaded Mac.
  # Observe successful rendering instead of assuming it within a fixed 1.3s sleep.
  # No playback command is retried and the original assertions remain mandatory.
  deadline=time.monotonic()+35;g=call('generate','status')
  while not (g['running'] and g['rendered_seconds']>0 and not g.get('loading') and g.get('transition',{}).get('state')=='idle' and not g.get('transition',{}).get('queued')) and time.monotonic()<deadline:
   time.sleep(.25);g=call('generate','status')
  s=call('status')
  if not (g['running'] and g['rendered_seconds']>0):print('AUDIO_DIAGNOSTIC',json.dumps(g),flush=True)
  check(s['mode']==mode and s['active_sound_ids']==['living'],'Solo real generator '+mode)
  check(g['running'] and g['rendered_seconds']>0,'Core Audio render callback '+mode)
  check(s['preferences']['markers']==[600,1200,1800,2400],'Custom chimes preserved '+mode)
 for key,value in [('density','.3'),('brightness','.19'),('movement','.26'),('space','.81'),('texture','.11'),('pulse','.1'),('evolution','.22'),('settleMinutes','35')]:
  g=call('generate','set',key,value);check(abs(g['configuration'][key]-float(value))<1e-9,'Persisted parameter '+key)
 call('generate','seed','2026');check(call('generate','status')['configuration']['seed']==2026,'Seed update')
 call('mix','save','QA living mix');mix=call('mixes')[0];check(mix['generatorSettings']['seed']==2026,'Mix stores generator configuration')
 call('generate','defaults');call('mix','load','QA living mix');check(call('generate','status')['configuration']['seed']==2026,'Mix restores generator configuration')
 p=call('pause')['elapsed_seconds'];time.sleep(1.3);check(abs(call('status')['elapsed_seconds']-p)<.05,'Pause stops stopwatch')
 check(not call('generate','status')['running'],'Pause stops live audio rendering')
 call('play');time.sleep(.4);check(call('status')['elapsed_seconds']>p,'Resume stopwatch')
 call('silence');time.sleep(1.3);s=call('status');check(s['active_sound_ids']==[] and s['status']=='playing','Silence retains meditation timer')
 check(not call('generate','status')['running'],'Silence stops generator audio')
 check(call('generate','set','density','2',expected=2)['code']=='invalid_argument','Reject out-of-range control')
 check(call('generate','set','unknown','.2',expected=2)['code']=='invalid_key','Reject unknown control')
 check(call('generate','seed','1.5',expected=2)['code']=='invalid_seed','Reject fractional seed')
 check(call('call','{"command":"generate.set","key":"density","value":true}',expected=2)['code']=='invalid_argument','Reject boolean control')
 call('ui','page','generative');check(call('status')['page']=='generative','Generator navigation via CLI')
 call('stop');call('quit');process.wait(timeout=15)
 s=launch();check(s['status']=='stopped','Restart without automatic generator audio');g=call('generate','status')
 check(g['configuration']['seed']==2026 and abs(g['configuration']['space']-.81)<1e-9,'Generator config survives restart')
 check(s['preferences']['markers']==[600,1200,1800,2400],'Custom markers survive restart')
 call('quit');process.wait(timeout=15)
 a=profile/'first.wav';b=profile/'second.wav'
 ra=call('generate','render','focus',str(a),'--seconds','2','--seed','77')
 rb=call('generate','render','focus',str(b),'--seconds','2','--seed','77')
 with wave.open(str(a)) as w:check(w.getnframes()==88200 and w.getnchannels()==2 and w.getsampwidth()==2,'WAV PCM format and duration');pcmA=w.readframes(w.getnframes())
 with wave.open(str(b)) as w:pcmB=w.readframes(w.getnframes())
 check(pcmA==pcmB,'CLI deterministic PCM export')
 check(ra['peak']>.001 and ra['audio_origin']=='local_generation','Original non-silent export reports local origin')
 before=hashlib.sha256(a.read_bytes()).hexdigest();check(call('generate','render','focus',str(a),'--seconds','2',expected=2)['code']=='file_exists','Export refuses overwrite');check(before==hashlib.sha256(a.read_bytes()).hexdigest(),'Existing export untouched')
 check(a.with_suffix('.wav.json').exists(),'Export provenance sidecar')
 check(call('generate','render','focus',str(profile/'bad.wav'),'--seconds','0',expected=2)['code']=='invalid_duration','Reject invalid duration')
 print(json.dumps({'ok':True,'passed':len(checks),'audio_muted':True,'checks':checks},indent=2),flush=True)
finally:
 if process and process.poll()==None:
  process.terminate()
  try:process.wait(timeout=10)
  except subprocess.TimeoutExpired:process.kill()
 log.close()
 if sys.exc_info()[0]==None:shutil.rmtree(profile)
 else:print('Retained isolated test profile',profile,file=sys.stderr)
