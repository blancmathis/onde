#!/usr/bin/env python3
"""Test the real native app + CLI in an isolated disposable profile, with audio muted."""
import json,os,pathlib,shutil,socket,stat,subprocess,sys,tempfile,time
app=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'dist/Onde.app').resolve()
cli=app/'Contents/MacOS/ondectl'; profile=pathlib.Path(tempfile.mkdtemp(prefix='onde-qa-',dir='/tmp')); env=dict(os.environ,ONDE_HOME=str(profile)); checks=[]; process=None; log=(profile/'application.log').open('w')
def check(value,text):
 if not value:raise AssertionError(text)
 checks.append(text);print('PASS',text,flush=True)
def call(*args,expected=0):
 p=subprocess.run([str(cli),*args],env=env,capture_output=True,text=True,timeout=45)
 if p.returncode!=expected:raise AssertionError(f'{args}: exit {p.returncode}; {p.stdout}; {p.stderr}')
 o=json.loads(p.stdout)
 if o.get('ok') != (expected==0):raise AssertionError(o)
 return o['result'] if expected==0 else o['error']
def wait_audio(sound_id,seconds=30):
 deadline=time.monotonic()+seconds
 while time.monotonic()<deadline:
  if process.poll() is not None:raise AssertionError('App exited while preparing audio')
  s=call('status')
  if s['last_error'] is not None:raise AssertionError(s['last_error'])
  if sound_id in s['audio_playing_ids']:return s
  time.sleep(.1)
 raise AssertionError(('Audio never became ready',sound_id,s))
def launch():
 global process
 process=subprocess.Popen([str(app/'Contents/MacOS/Onde')],env=env,stdout=log,stderr=log)
 for i in range(100):
  if process.poll()!=None:raise AssertionError('App exited: '+(profile/'application.log').read_text())
  try:return call('status')
  except Exception:time.sleep(.1)
 raise AssertionError('App not ready')
try:
 check(call('status',expected=3)['code']=='not_running','Not-running response exit 3')
 check(len(call('schema')['commands'])>=25,'Full offline command schema')
 s=launch();check(s['status']=='stopped','No autoplay on launch');check(s['preferences']['markers']==[600,1200,1800],'Default markers 10/20/30 minutes')
 check(stat.S_IMODE((profile/'control.sock').stat().st_mode)==0o600,'Socket owner-only');check(stat.S_IMODE(profile.stat().st_mode)==0o700,'Profile owner-only')
 call('volume','0');call('settings','fadeSeconds','0');call('settings','reducedMotion','true')
 sounds=call('sounds');check(len(sounds)>=7,'Sound library available')
 for sound in sounds:
  call('solo',sound['id']);call('play');s=wait_audio(sound['id']);check(sound['id'] in s['audio_playing_ids'] and s['last_error']==None,'Playback '+sound['id'])
 call('stop');call('timer','markers','2,4,6','--seconds');call('meditate','--reset');time.sleep(8.1)
 s=call('status');check(s['status']=='playing' and s['elapsed_seconds']>8,'Timer continues after final chime');check(s['next_chime_seconds']==None,'No next chime')
 check([e['marker_seconds'] for e in call('events') if e['type']=='chime']==[2,4,6],'Exactly three real chimes')
 time.sleep(1.2);check(len([e for e in call('events') if e['type']=='chime'])==3,'No repeated chime')
 paused=call('pause')['elapsed_seconds'];time.sleep(.8);check(abs(call('status')['elapsed_seconds']-paused)<.04,'Pause excludes time')
 call('play');time.sleep(.5);check(call('status')['elapsed_seconds']>paused+.4,'Resume preserves time')
 call('timer','markers','30,10,10,20');check(call('status')['preferences']['markers']==[600,1200,1800],'Sort and deduplicate markers')
 call('timer','markers','');check(call('status')['next_chime_seconds']==None,'No-marker meditation')
 call('timer','reset');check(call('status')['elapsed_seconds']<.5,'Reset timer')
 s=call('silence');check(s['active_sound_ids']==[] and s['status']=='playing','Silent meditation preserves timer')
 call('focus');call('sound','rain','on','--volume','.27');call('mix','save','QA ambiance');check(any(m['name']=='QA ambiance' for m in call('mixes')),'Save mix')
 call('solo','piano');call('mix','load','QA ambiance');check(abs(call('status')['layers']['rain']['volume']-.27)<.0001,'Load mix gain')
 call('relax');call('focus');check(call('status')['layers']['rain']['enabled'],'Remember mode mix')
 original=profile/'original.m4a';shutil.copyfile(app/'Contents/Resources/Sounds/chime.m4a',original);imported=call('import',str(original),'--title','QA import');check(imported['imported'],'Private import')
 call('solo',imported['id']);call('play');check(imported['id'] in call('status')['audio_playing_ids'],'Import playback')
 call('sound','remove',imported['id']);check(original.exists() and not(profile/'Imports'/imported['filename']).exists(),'Preserve original when removing import')
 check(call('volume','2',expected=2)['code']=='invalid_argument','Reject volume out of range')
 check(call('timer','markers','-1',expected=2)['code']=='invalid_markers','Reject negative marker')
 check(call('solo','unknown',expected=2)['code']=='not_found','Reject unknown sound')
 check(call('call','{"command":"volume","value":true}',expected=2)['code']=='invalid_argument','Reject boolean numeric volume')
 with socket.socket(socket.AF_UNIX) as sock:
  sock.settimeout(5);sock.connect(str(profile/'control.sock'));sock.sendall(b'not valid json\n');check(json.loads(sock.recv(65536))['ok']==False,'Malformed IPC does not crash')
 for page in ['studio','library','mixes','settings','cli','history','credits']:check(call('ui','page',page)['page']==page,'CLI page '+page)
 check(call('ui','quiet','on')['quiet_view'],'Quiet view on');check(not call('ui','quiet','off')['quiet_view'],'Quiet view off')
 call('chime','preview');check(call('status')['last_error']==None,'No audio errors')
 call('stop');check(len(call('history'))>0,'History recorded');call('timer','markers','10,20,30');print('PRE_QUIT',json.dumps(call('status')['preferences']),flush=True);call('quit');process.wait(timeout=10);print('DISK_AFTER_QUIT',json.dumps(json.loads((profile/'state.json').read_text())['preferences']),flush=True)
 s=launch();print('RESTART',json.dumps(s['preferences']),flush=True);check(s['status']=='stopped','Restart without autoplay');check(s['preferences']['markers']==[600,1200,1800] and s['preferences']['masterVolume']==0,'Settings survive restart');check(len(call('mixes'))==1,'Mix survives restart')
 call('mix','delete','QA ambiance');check(call('mixes')==[],'Delete mix');call('history','clear');check(call('history')==[],'Clear history');call('quit');process.wait(timeout=10)
 print(json.dumps({'ok':True,'passed':len(checks),'checks':checks},indent=2),flush=True)
finally:
 if process and process.poll()==None:
  process.terminate()
  try:process.wait(timeout=5)
  except subprocess.TimeoutExpired:process.kill()
 log.close()
 if sys.exc_info()[0]==None:shutil.rmtree(profile)
 else:print('Retained QA profile',profile,file=sys.stderr)
