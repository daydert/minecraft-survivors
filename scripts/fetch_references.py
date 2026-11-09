"""Download official Mojang references, excluded from game exports."""
import requests,pathlib,json,concurrent.futures
base='https://raw.githubusercontent.com/Mojang/bedrock-samples/main/'
paths={
'steve':'resource_pack/textures/entity/steve.png',
'zombie':'resource_pack/textures/entity/zombie/zombie.png',
'creeper':'resource_pack/textures/entity/creeper/creeper.png',
'skeleton':'resource_pack/textures/entity/skeleton/skeleton.png',
'spider':'resource_pack/textures/ui/promo_spider.png',
'slime':'resource_pack/textures/entity/slime/slime.png',
'ravager':'resource_pack/textures/entity/illager/ravager.png',
'iron_sword':'resource_pack/textures/items/iron_sword.png',
'bow':'resource_pack/textures/items/bow_standby.png',
'trident':'resource_pack/textures/items/trident.png',
'fire_charge':'resource_pack/textures/items/fireball.png',
'grass':'resource_pack/textures/blocks/grass_top.png',
'chestplate':'resource_pack/textures/items/iron_chestplate.png',
'amethyst':'resource_pack/textures/items/amethyst_shard.png',
'redstone':'resource_pack/textures/items/redstone_dust.png',
'blaze':'resource_pack/textures/items/blaze_powder.png',
'sugar':'resource_pack/textures/items/sugar.png',
'hopper':'resource_pack/textures/items/hopper.png',
'apple':'resource_pack/textures/items/apple.png',
'emerald':'resource_pack/textures/items/emerald.png',
'fangs':'resource_pack/textures/entity/illager/fangs.png',
'potion':'resource_pack/textures/items/potion_bottle_lingering_poison.png'}
out=pathlib.Path('docs/references');out.mkdir(parents=True,exist_ok=True)
def one(kv):
 k,p=kv;u=base+p
 try:
  r=requests.get(u,timeout=20)
  if r.ok:(out/(k+'.png')).write_bytes(r.content)
  return k,{'url':u,'status':r.status_code,'file':k+'.png' if r.ok else None}
 except Exception as e:return k,{'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as e: refs=dict(e.map(one,paths.items()))
(out/'sources.json').write_text(json.dumps(refs,indent=2))
for k,v in refs.items():print(k,v.get('status',v.get('error')),flush=True)
