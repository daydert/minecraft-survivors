"""Prepare the user-supplied campaign playlist and boss themes."""
import argparse,hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
SOURCES={
 'music_2':Path('/home/daydert/Downloads/Telegram Desktop/Music2.mp3'),
 'music_3':Path('/home/daydert/Downloads/ost3.ogg'),
 'music_wither':ROOT/'builds/audio_2026-10-28_18-28-58.ogg',
 'boss_win':Path('/home/daydert/Downloads/Telegram Desktop/wineffect.ogg'),
 'music_victory':Path('/home/daydert/Downloads/Telegram Desktop/audio_2026-10-29_00-31-58.ogg'),
 'music_dragon':Path('/home/daydert/Downloads/DrAgOn.ogg'),
 'music_endersteve':Path('/home/daydert/Downloads/GlitchFight.ogg')}

def prepare(names=None):
 manifest=json.loads((ROOT/'docs/MUSIC_MANIFEST.json').read_text()) if names else {}
 for name,source in SOURCES.items():
  if names and name not in names:continue
  target=ROOT/'assets/audio'/(name+'.ogg')
  if source.suffix=='.ogg':shutil.copyfile(source,target)
  else:subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-map','0:a:0','-vn','-c:a','libvorbis','-q:a','6','-map_metadata','-1',str(target)],check=True)
  info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,sample_rate,channels','-of','json',str(target)]))
  manifest[name]=dict(source=str(source),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),path=str(target.relative_to(ROOT)),sha256=hashlib.sha256(target.read_bytes()).hexdigest(),byte_identical=source.suffix=='.ogg',duration=float(info['format']['duration']),streams=info['streams'])
  print(name,round(manifest[name]['duration'],3),flush=True)
 (ROOT/'docs/MUSIC_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+',choices=list(SOURCES))
 prepare(parser.parse_args().only)
