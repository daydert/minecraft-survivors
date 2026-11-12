"""Rebuild the editable dialogue sheet from the shipped story sources.
No runtime strings or timings are mutated. JSON retains every source occurrence.
"""
from pathlib import Path
import re,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
STRING=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
CYR=re.compile('[А-Яа-яЁё]')
entries=[]
def add(ch,who,scene,text,file,line,locator=None,kind='dialogue'):
 if not text:return
 ident=f'{ch}-{hashlib.sha1((str(file)+"|"+text).encode()).hexdigest()[:8]}'
 prior=next((e for e in entries if e['id']==ident),None)
 source={'file':str(file),'line':line,'context':scene}
 if locator is not None:source['json_path']=locator
 if prior:prior['sources'].append(source);return
 entries.append({'id':ident,'chapter':ch,'speaker':who,'scene':scene,'kind':kind,'original':text,'text':text,'sources':[source]})
def source(file,ch,who):
 context='';phase=''
 for number,line in enumerate((ROOT/file).read_text().splitlines(),1):
  # Strip comments only outside literals, leaving quoted speech intact.
  occupied=[(m.start(),m.end()) for m in STRING.finditer(line)]
  comments=[i for i,c in enumerate(line) if c=='#' and not any(a<=i<b for a,b in occupied)]
  if comments:line=line[:comments[0]]
  m=re.match(r'(?:const|var)\s+(\w+)|func\s+(\w+)',line)
  if m:context=m.group(1) or m.group(2)
  m=re.match(r'\s*"([a-z_]+)":\s*$',line)
  if m:phase=m.group(1)
  scene=context+(' / '+phase if phase and context in ['step','story'] else '')
  for m in STRING.finditer(line):
   lit=m.group();text=bytes(lit[1:-1],'utf-8').decode('utf-8')
   text=text.replace('\\n','\n').replace('\\"','"').replace("\\'", "'").replace('\\t','\t').replace('\\\\','\\')
   if not CYR.search(text):continue
   if text in ['Пирамида','Город Края']:continue
   if context=='submit':who_here='Терминал сортировки'
   else:who_here=who
   if file.endswith('chapter_five_finale.gd') and context in ['LANG_NAMES','CREDITS']:continue
   speaker=who_here
   kind='dialogue'
   if text=='Квиты.':speaker='Стив'
   if context in ['FLAVOR'] or text.startswith('* '):speaker='Рассказчик / окно Undertale';kind='battle_text'
   if text.startswith('На крышке выцарапано:'):speaker='Надпись на сундуке';kind='note'
   if context in ['start_fists','fists']:scene+=' (сохранённая резервная ветка)';kind='legacy'
   add(ch,speaker,scene,text,file,number,kind=kind)
for file,ch,who in [('scripts/herobrine_encounter.gd','I','Херобрин'),('scripts/end_world.gd','III','ЭндерСтив'),('scripts/end_encounter.gd','III','ЭндерСтив'),('scripts/chapter_four_finale.gd','IV','Херобрин'),('scripts/chapter_five_notch.gd','V','Нотч'),('scripts/chapter_five_finale.gd','V','Нотч')]:source(file,ch,who)
# IV's authored, timed final speech and the villager's letter live in data.
file='data/chapter_four_finale.json';raw=(ROOT/file).read_text();data=json.loads(raw)
for i,row in enumerate(data['death']['lines']):
 line=raw[:raw.index(json.dumps(row['text'],ensure_ascii=False))].count('\n')+1
 add('IV','Херобрин','death',row['text'],file,line,['death','lines',i,'text'])
file='data/chapter_four_balance.json';raw=(ROOT/file).read_text();data=json.loads(raw)
for key,value in [('title',data['note']['title'])]+[(i,t) for i,t in enumerate(data['note']['lines'])]:
 path=['note','title'] if key=='title' else ['note','lines',key]
 add('IV','Житель (записка)','note',value,file,raw[:raw.index(json.dumps(value,ensure_ascii=False))].count('\n')+1,path,'note')
# Announcer text is editable separately from character speech. Keep %d intact.
file='scripts/chapter_five_fighter.gd'
for i,line in enumerate((ROOT/file).read_text().splitlines(),1):
 if 'say(' not in line:continue
 for m in STRING.finditer(line):
  text=m.group()[1:-1]
  if text!='РАУНД' and (CYR.search(text) or text in ['K.O.','FATALITY','Ctrl+Z']):add('V','Диктор файтинга','fighter',text,file,i,kind='announcer')
file='scripts/chapter_five_finale.gd';raw=(ROOT/file).read_text();a=raw.index('const CREDITS :=');b=raw.index('const CREDITS_LENGTH',a)
for m in STRING.finditer(raw[a:b]):
 text=m.group()[1:-1]
 if text:add('V','Титры','credits',text,file,raw[:a+m.start()].count('\n')+1,kind='credits')
entries.sort(key=lambda e:({'I':1,'III':3,'IV':4,'V':5}[e['chapter']],e['kind'] in ['announcer','credits','legacy']))
out={'schema':1,'instructions':'Меняйте text; сохраняйте id и original. Можно редактировать и Markdown по тем же ID. Тексты ещё не применены к игре.','entries':entries}
(ROOT/'docs/ALL_GAME_DIALOGUES_RU.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
md=['# Все реплики игры для редактирования','', 'Меняйте текст под нужным ID и пришлите этот файл обратно. ID оставляйте: по ним реплики можно точно сопоставить с исходниками. Многострочные реплики сохраняйте одним блоком. В шаблонах оставьте `%d` и `%s` — это места для чисел и результатов.','', 'Здесь собраны разговоры, шёпот, боевые реплики, записки, текст окна Undertale, диктор и финальные титры. Кнопки, названия предметов и подсказки управления сюда не входят. В главе II словесных реплик персонажей сейчас нет. Резервные старые ветки отмечены отдельно.','', f'Всего {len(entries)} уникальных текстов; повторяющиеся места использования объединены. Исходники и все места использования записаны в `ALL_GAME_DIALOGUES_RU.json`.','']
for ch in ['I','II','III','IV','V']:
 md+=['## Глава '+ch,'']
 if ch=='II':md+=['Реплик персонажей нет.',''];continue
 for e in [x for x in entries if x['chapter']==ch]:
  md += [f'### {e["id"]} · {e["speaker"]} · {e["scene"]}', '', '```text', e['text'], '```', '',f'Источник: `{e["sources"][0]["file"]}:{e["sources"][0]["line"]}`.', '']
(ROOT/'docs/ALL_GAME_DIALOGUES_RU.md').write_text('\n'.join(md))
print(len(entries),'unique dialogue/story texts;',sum(len(x['sources']) for x in entries),'source occurrences')
