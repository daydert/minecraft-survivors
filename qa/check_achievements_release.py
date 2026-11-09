"""Real exported Linux processes, isolated user data and native screen captures."""
import json,os,re,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
results=[]
with tempfile.TemporaryDirectory(prefix='survivors_achievement_release_') as temp:
 env=os.environ.copy();env['XDG_DATA_HOME']=temp
 for mode in ['achievements','achievement_toast','end_survival','end_dragon','end_last_duel','end_victory','end_overworld']:
  launcher=mode=='achievements'
  command=[str(ROOT/'run.sh')] if launcher else [str(ROOT/'builds/linux/MinecraftSurvivors.x86_64'),'--display-driver','wayland']
  attempts=[]
  for attempt in range(2):
   try:
    run=subprocess.run(command+['--','--capture='+mode],cwd='/tmp',env=env,capture_output=True,text=True,timeout=30)
    attempts.append({'exit_code':run.returncode});break
   except subprocess.TimeoutExpired as error:
    output=(error.stdout or b'').decode(errors='replace') if isinstance(error.stdout,bytes) else (error.stdout or '')
    diagnostic=(error.stderr or b'').decode(errors='replace') if isinstance(error.stderr,bytes) else (error.stderr or '')
    (ROOT/f'qa/achievement_release_{mode}_timeout_{attempt}.log').write_text(output+diagnostic)
    attempts.append({'timeout':True,'seconds':30,'capture_reached':'CAPTURE ' in output})
    print(mode,'display/exit timeout, retrying' if attempt==0 else 'timeout',flush=True)
    if attempt:raise

  log=run.stdout+run.stderr;(ROOT/f'qa/achievement_release_{mode}.log').write_text(log)
  match=re.search(r'CAPTURE (.+)',log);image=Path(match.group(1).strip()) if match else None
  errors=[line for line in log.splitlines() if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
  success=run.returncode==0 and not errors and image is not None and image.exists()
  if image is not None and image.exists():shutil.copy2(image,ROOT/f'qa/achievement_release_{mode}.png')
  results.append(dict(mode=mode,launcher='run.sh' if launcher else 'Linux binary',exit_code=run.returncode,success=success,errors=errors,attempts=attempts))
  print(mode,success,flush=True)
(ROOT/'qa/achievements_release_results.json').write_text(json.dumps(results,indent=2)+'\n')
assert all(r['success'] for r in results)
