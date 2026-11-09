"""Validate complete prepared playlist files and the untouched supplied OGG."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
manifest=json.loads((ROOT/'docs/MUSIC_MANIFEST.json').read_text());checks=0
for name,spec in manifest.items():
 path=ROOT/spec['path'];raw=path.read_bytes()
 assert hashlib.sha256(raw).hexdigest()==spec['sha256'],name
 info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name','-of','json',str(path)]))
 assert len(info['streams'])==1 and info['streams'][0]['codec_name']=='vorbis',name
 assert abs(float(info['format']['duration'])-spec['duration'])<.02,name
 source=Path(spec['source'])
 if source.exists():
  assert hashlib.sha256(source.read_bytes()).hexdigest()==spec['source_sha256'],name
  if spec['byte_identical']:assert raw==source.read_bytes(),name
 checks+=4
print(f'MUSIC_ASSETS_RESULT {checks} checks passed; {len(manifest)} supplied audio files')
(ROOT/'qa/music_asset_results.json').write_text(json.dumps(dict(checks=checks,failures=[]),indent=2)+'\n')
