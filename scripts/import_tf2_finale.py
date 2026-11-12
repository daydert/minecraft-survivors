"""Read the public TF2 dedicated-server VPKs for the local ending scene.
See docs/CHAPTER_FIVE_VISUAL_SOURCES.md for authorization and rights.
"""
from pathlib import Path
import struct
class VPK:
 def __init__(self,path):
  self.path=Path(path);self.raw=self.path.read_bytes();sig,ver,sz=struct.unpack_from('<III',self.raw);p=28 if ver==2 else 12;self.base=p+sz;self.entries={}
  def string():
   nonlocal p
   e=self.raw.index(b'\0',p);s=self.raw[p:e].decode();p=e+1;return s
  while (ext:=string()):
   while (folder:=string()):
    while (name:=string()):
     crc,pre,arch,off,size,term=struct.unpack_from('<IHHIIH',self.raw,p);p+=18
     key=(folder+'/' if folder!=' ' else '')+name+'.'+ext
     self.entries[key.lower()]=(arch,off,size,self.raw[p:p+pre]);p+=pre
 def read(self,key):
  a,o,n,pre=self.entries[key.lower()]
  if not n:return pre
  if a==32767:return pre+self.raw[self.base+o:self.base+o+n]
  p=self.path.with_name(self.path.name.replace('_dir',f'_{a:03d}'))
  with p.open('rb') as f:f.seek(o);return pre+f.read(n)

def mdl_materials(data):
 def i(p):return struct.unpack_from('<I',data,p)[0]
 def z(p):return data[p:data.index(b'\0',p)].decode(errors='replace').replace('\\','/').lower()
 n,off,nd,od=struct.unpack_from('<4I',data,204)
 dirs=[z(i(od+4*k)) for k in range(nd)]
 names=[z(off+k*64+i(off+k*64)) for k in range(n)]
 return [d+name for d in dirs for name in names]

def prepare(vpk_root,out,material_names,model_names):
 import json,re
 misc=VPK(vpk_root/'tf2_misc_dir.vpk');textures=VPK(vpk_root/'tf2_textures_dir.vpk');materials=set(material_names);manifest={};required=set()
 def write(key,data):
  p=out/key;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
 for name in model_names:
  if name not in misc.entries:continue
  data=misc.read(name);materials.update(mdl_materials(data))
  for key in [name,name[:-4]+'.vvd',name[:-4]+'.dx90.vtx']:
   if key in misc.entries:write(key,misc.read(key))
 def material(name):
  if name in manifest:return
  manifest[name]={};key='materials/'+name+'.vmt'
  if key not in misc.entries:return
  data=misc.read(key);write(key,data);text=data.decode(errors='replace').lower()
  inc=re.search(r'"?include"?\s+"([^"]+)"',text)
  if inc:
   parent=inc[1].removeprefix('materials/').removesuffix('.vmt');material(parent);manifest[name].update(manifest[parent])
  for token in ['basetexture','basetexture2']:
   match=re.search(r'"?\$'+token+r'"?\s+"?([^"\s{}]+)',text)
   if match:
    tex=match[1].replace('\\','/').removesuffix('.vtf');key='materials/'+tex+'.vtf'
    if key in textures.entries:manifest[name][token]=tex;required.add(key)
  manifest[name]['alpha']=bool(re.search(r'\$(?:alphatest|translucent)"?\s+"?1',text))
 for name in sorted(materials):material(name)
 for side in ['ft','bk','lf','rt','up','dn']:
  name='skybox/sky_tf2_04'+side;material(name)
 (out/'materials.json').write_text(json.dumps(manifest,indent=2))
 archives=sorted({textures.entries[k][0] for k in required})
 return required,archives

if __name__=='__main__':
 import argparse,json
 ap=argparse.ArgumentParser();ap.add_argument('--vpk-root',type=Path,required=True);ap.add_argument('--materials',type=Path,required=True);ap.add_argument('--models',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--filelist',type=Path,required=True);ap.add_argument('--extract',action='store_true');args=ap.parse_args()
 required,archives=prepare(args.vpk_root,args.out,json.loads(args.materials.read_text()),json.loads(args.models.read_text()))
 args.filelist.write_text('\n'.join('tf/tf2_textures_%03d.vpk'%a for a in archives))
 (args.out/'required_textures.json').write_text(json.dumps(sorted(required)))
 print('TEXTURES',len(required),'ARCHIVES',archives)
 if args.extract:
  v=VPK(args.vpk_root/'tf2_textures_dir.vpk')
  for key in required:
   p=args.out/key;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(v.read(key))
