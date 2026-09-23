#!/usr/bin/env python3
"""Real app/IPC regression. Owned temporary profiles, muted output, no user data.

Timing assertions concern the app's transport, not audible perception or CPU energy.
The missing-bank fixture is a private copy; the supplied bundle is never changed.
"""
import json, os, pathlib, shutil, socket, subprocess, sys, tempfile, time, wave
from qa_diagnostics import capture

root = pathlib.Path(__file__).resolve().parents[1]
app = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else root/'dist/Onde.app').resolve()
checks = []
def check(ok, label):
    if not ok: raise AssertionError(label)
    checks.append(label); print('PASS', label, flush=True)

class Fixture:
    def __init__(self, bundle):
        self.app = bundle
        self.home = pathlib.Path(tempfile.mkdtemp(prefix='onde-transport-', dir='/tmp'))
        self.env = dict(os.environ, ONDE_HOME=str(self.home))
        self.process = None
        self.log = (self.home/'app.log').open('w')
        self.preferences = dict(masterVolume=0, chimeVolume=.21, fadeSeconds=0,
                                startFadeSeconds=.5, markers=[600,1200,1800,2400],
                                chimesEnabled=True, preventSleep=False, reducedMotion=True)
        state = dict(version=1, mode='focus', layers={}, modeMixes={}, imported=[],
                     mixes=[], history=[], preferences=self.preferences)
        (self.home/'state.json').write_text(json.dumps(state))
    def call(self, command='status', **data):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(15); client.connect(str(self.home/'control.sock'))
            client.sendall(json.dumps(dict(command=command, **data)).encode()+b'\n')
            buffer=bytearray()
            while b'\n' not in buffer:
                block=client.recv(65536)
                if not block: raise AssertionError('Incomplete IPC reply')
                buffer.extend(block)
                if len(buffer)>2_000_000: raise AssertionError('Oversized IPC reply')
        reply=json.loads(buffer.split(b'\n',1)[0])
        if not reply['ok']: raise AssertionError(reply)
        result=reply['result']
        if isinstance(result,dict) and 'preferences' in result:
            assert result['preferences']['masterVolume']==0, 'Test output must stay muted'
        return result
    def launch(self):
        self.process=subprocess.Popen([str(self.app/'Contents/MacOS/Onde')],env=self.env,cwd=self.home,stdout=self.log,stderr=self.log)
        deadline=time.monotonic()+40
        while time.monotonic()<deadline:
            if self.process.poll() is not None: raise AssertionError('Fixture app exited')
            try: return self.call()
            except OSError: time.sleep(.1)
        raise AssertionError('Fixture did not start')
    def wait(self, predicate, seconds=35):
        deadline=time.monotonic()+seconds; state=None
        while time.monotonic()<deadline:
            state=self.call()
            if predicate(state): return state
            time.sleep(.08)
        raise AssertionError(('Condition not reached',state))
    def ready(self, mode='focus', id='sillage'):
        self.call('music.select', mode=mode, id=id)
        return self.wait(lambda s:s['timer_running'] and s['audio_playing_ids'] and not s['generator']['loading'])
    def frozen(self, label):
        a=self.call(); time.sleep(.75); b=self.call()
        check(not b['timer_running'] and abs(b['elapsed_seconds']-a['elapsed_seconds'])<.002 and abs(b['today_seconds']-a['today_seconds'])<.002, label)
        return b
    def advances(self, label):
        a=self.call(); time.sleep(.8); b=self.call()
        check(b['timer_running'] and b['elapsed_seconds']-a['elapsed_seconds']>.55 and b['today_seconds']-a['today_seconds']>.55, label)
        return b
    def quit(self):
        if self.process and self.process.poll() is None:
            # Dismiss the error alert deliberately produced by failure fixtures.
            # AppKit can defer termination while an alert is presented.
            self.call('errors.clear'); time.sleep(.3)
            self.call('quit'); self.process.wait(timeout=15)
    def close(self):
        if sys.exc_info()[0] is not None: capture(self.process, self.home, "transport")
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:self.process.kill(); self.process.wait()
        self.log.close()
        if sys.exc_info()[0] is None:shutil.rmtree(self.home)
        else:print('Retained isolated fixture:',self.home,file=sys.stderr)

f=Fixture(app)
try:
    s=f.launch(); check(s['status']=='stopped' and not s['timer_running'], 'Launch never starts a session clock')
    f.call('play'); f.frozen('Play with no Focus source cannot invent listening time')
    f.ready(); f.advances('Real generated playback advances session and daily clocks (output muted)')
    s=f.call('pause'); check(s['status']=='paused', 'Pause immediately changes transport state')
    a=f.frozen('Pause freezes both clocks without requiring app shutdown')
    f.call('play'); f.wait(lambda s:s['timer_running']); b=f.advances('Resume restarts timing only when audio is running')
    check(b['elapsed_seconds']>=a['elapsed_seconds'], 'Resume preserves the accumulated session')
    s=f.call('stop'); check(s['elapsed_seconds']==0 and s['status']=='stopped','End session immediately resets the current clock')
    a=f.frozen('Ended session does not count idle wall time')
    s=f.call('stop'); check(s['today_seconds']==a['today_seconds'],'Repeated Stop does not alter the daily total')
    for mode,id in [('focus','sillage'),('relax','rive')]:
        f.ready(mode,id); f.advances(mode+' playback counts')
        f.call('sound',id='living',enabled=False)
        f.frozen(mode+' automatically pauses when the last source is switched off')
        f.call('sound',id='living',enabled=True)
        f.frozen(mode+' re-enabling a source does not silently resume')
        f.call('play'); f.wait(lambda s:s['timer_running']); f.advances(mode+' resumes on explicit Play')
    f.call('silence'); s=f.frozen('Silence in Relax freezes timing and daily accounting')
    check(not s['playback_requested'] and not s['active_sound_ids'],'Silence clears transport intent outside Meditation')
    f.ready(); f.call('background',kind='rain',volume=.2)
    f.call('sound',id='living',enabled=False)
    f.advances('A remaining recorded background legitimately keeps the session active')
    f.call('background',kind='off'); f.frozen('Switching off the final background pauses the session')
    f.ready(); f.call('ui',quiet=True); f.advances('Quiet view does not stop active music or its clock')
    f.call('ui',quiet=False)
    for _ in range(4): f.call('pause'); f.call('play')
    f.call('pause'); f.frozen('Rapid pause/resume followed by pause cannot restart timing later')
    f.call('stop'); f.ready('meditation','immersion'); f.call('silence')
    f.advances('Deliberate silent Meditation remains available')
    f.call('timer.markers',seconds=[1,2]); f.call('timer.reset')
    f.wait(lambda s:s['elapsed_seconds']>2.7)
    s=f.call(); check(s['fired_markers']==[1,2] and s['timer_running'],'Silent Meditation keeps configured chimes and continues after the last one')
    f.call('pause'); f.frozen('Pause also freezes silent Meditation')
    f.call('timer.markers',seconds=[600,1200,1800,2400])
    f.call('stop'); f.frozen('Stop also ends silent Meditation')
    # A missing recorded file fails synchronously, after it was initially available.
    audio=f.home/'fixture.wav'
    with wave.open(str(audio),'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(44100); wav.writeframes(b'\0\0'*44100)
    imported=f.call('import',path=str(audio))
    (f.home/'Imports'/imported['filename']).unlink()
    f.call('solo',id=imported['id']); f.call('play')
    s=f.call(); check(bool(s['last_error']) and not s['playback_requested'],'A synchronous audio failure cancels Play intent')
    f.frozen('A failed recorded playback cannot run either clock')
    f.call('stop'); s=f.call(); total=s['today_seconds']
    check(s['preferences']==f.preferences,'Playback fixes preserve all volume and personalised chime settings')
    f.quit(); f.launch(); s=f.frozen('Restart does not resume or accrue offline time')
    check(abs(s['today_seconds']-total)<.01,'Daily total survives restart independently of the reset session')
    f.quit()
finally:f.close()

with tempfile.TemporaryDirectory(prefix='onde-no-bank-',dir='/tmp') as folder:
    private=pathlib.Path(folder)/'Onde.app';shutil.copytree(app,private)
    shutil.rmtree(private/'Contents/Resources/Orchestra')
    f=Fixture(private)
    try:
        f.launch(); f.call('music.select',id='filigrane',mode='focus')
        s=f.wait(lambda s:bool(s['last_error']) and not s['playback_requested'])
        check(s['elapsed_seconds']==0 and not s['timer_running'],'Failed asynchronous preparation never starts the listening clock')
        f.frozen('Missing-bank failure cannot leave a ghost session running')
        f.call('stop'); f.call('pause'); f.frozen('Late preparation/error callbacks cannot resume stopped playback')
        f.quit()
    finally:f.close()
print(json.dumps(dict(ok=True,passed=len(checks),muted=True,checks=checks),indent=2))
