"""Read only Windows/Linux release templates from the official 1.28 GB ZIP.
Byte ranges avoid downloading unrelated Android, macOS and debug templates.
"""
import io,zipfile,requests,pathlib,os
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
TOTAL=1281349702
class RemoteZip(io.RawIOBase):
 def __init__(self):self.pos=0;self.session=requests.Session();self.tail=pathlib.Path('.tools/template_tail').read_bytes()
 def seekable(self):return True
 def readable(self):return True
 def tell(self):return self.pos
 def seek(self,off,whence=0):
  self.pos=off if whence==0 else (self.pos+off if whence==1 else TOTAL+off);return self.pos
 def read(self,n=-1):
  n=TOTAL-self.pos if n<0 else min(n,TOTAL-self.pos)
  if n<=0:return b''
  if self.pos>=TOTAL-len(self.tail):b=self.tail[self.pos-(TOTAL-len(self.tail)):self.pos-(TOTAL-len(self.tail))+n]
  else:
   r=self.session.get(URL,headers={'Range':f'bytes={self.pos}-{self.pos+n-1}'},timeout=120);r.raise_for_status()
   if r.status_code!=206:raise RuntimeError(f'Expected byte-range response, got {r.status_code}')
   b=r.content
  self.pos+=len(b);return b
z=zipfile.ZipFile(RemoteZip())
out=pathlib.Path.home()/'.local/share/godot/export_templates/4.7.2.stable';out.mkdir(parents=True,exist_ok=True)
for info in z.infolist():
 if info.filename.rsplit('/',1)[-1] in ['linux_release.x86_64','windows_release_x86_64.exe','version.txt']:
  print('Downloading',info.filename,info.compress_size,flush=True)
  b=z.read(info)
  path=out/info.filename.rsplit('/',1)[-1];path.write_bytes(b);path.chmod(0o755)
  print('Saved',path,len(b),flush=True)
