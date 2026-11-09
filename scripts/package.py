"""Package release executables and a clean, self-contained source project."""
from pathlib import Path
import zipfile,hashlib,json,stat
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'builds'
readme='''Minecraft Survivors · V2 · Главы I–III + мир IV · Кооп

Играть → выбор главы: Верхний мир, Незер или Край. Оружие атакует автоматически.
Достижения: кнопка в выборе главы и в одиночной паузе. Всего 18 достижений.
Прогресс сохраняется на этом компьютере. В коопе достижения не выдаются.
Забег начинается с мечом. Для «Только стрелы» его нельзя улучшать;
найдя лук, уберите меч через I за 3 секунды. Сам лук можно развивать.
Ненужную награду уровня можно пропустить. Кооп сохраняет прежний выбор.
Глава I на 12:00: бой с первой стадией Херобрина, затем сюжетный переход в Незер.
Поражение в этом бою тоже ведёт в Незер. Победа открывает особую сцену.
Глава II: 12 минут выживания, отдельная арена, победа и портал в Край.
Глава III: остров с пропастями, кристаллы на обсидиане, дракон и последний ЭндерСтив.
Глава IV: доступен первый этап — разрушенный мир, записка и неподвижные угрозы.
Враги, новый арсенал и финальный бой IV ещё в разработке.
Элитры: Пробел. Жемчуг: E. Эволюция копья с элитрами: Shift.
Золотых ботинок и сгустка магмы в наградах Края нет.
В Незере портал зажигается Оком Эндера при подходе. Вход — движением в портал.
После последнего ЭндерСтива подойдите за рукой и вернитесь к порталу.
Герой зажигает его при подходе. Прыжок начинается только при входе движением.
Шесть слотов оружия и восемь усилений. I — инвентарь, удаление и рецепты.
Половина тыкв и кувшинов содержит лечение. Магма и некоторые враги поджигают.
Золотые ботинки сохраняют нейтралитет пиглинов и уменьшают штраф песка душ.
Сгусток магмы уменьшает урон огня и иссушения. Удочка притягивает и оглушает.
ТНТ ставится по очереди; движение задаёт разлёт. Эволюция даёт кассетные заряды.
Громкость музыки и эффектов: 0–100%, шаг 10%.
Движение: WASD / стрелки. Улучшения: 1–5, мышь или Enter.
Пауза: Esc. Полный экран: F11. Настройки — в меню.
Характеристики: L. Закрыть характеристики: L / Esc.
Яблоки лечат. Зелёные сферы дают опыт. Элиты оставляют сундуки.
Для одиночной игры интернет, редактор Godot и установленный Minecraft не нужны.
Кооп на 2–4 игроков: все должны войти в одну сеть ZeroTier и быть авторизованы.
Ведущий: Мультиплеер → ник → Создать.
Друг: Мультиплеер → ник → IP ZeroTier ведущего → Подключиться.
Когда нужные игроки вошли, ведущий нажимает Начать. UDP-порт игры: 24567.
Если подключение блокируется, разрешите игре этот порт в локальном брандмауэре.
Мобов вдвое больше. Одна жизнь каждому; погибший наблюдает за выжившим.
Esc, L и выбор улучшений останавливают бой у всех. Финал главы прежний.
Новый забег запускает ведущий. Если ведущий закроет игру, сеанс закончится.
Логи коопа пишутся автоматически. При рывке нажмите F8, чтобы поставить метку.
После игры: Настройки → Папка логов. Передайте ZIP папок ведущего и проблемного клиента.
Оригинальные текстуры Minecraft Java 1.21.11 из локального Prism Launcher.
Оригинальные звуки и шрифт Minecraft. Музыка предоставлена пользователем.
Поборник, оригинальные образы персонажей, финал с Херобрином и переход в Незер.

Windows: запустите MinecraftSurvivors.exe.
Linux: chmod +x MinecraftSurvivors.x86_64 && ./MinecraftSurvivors.x86_64
При необходимости Wayland: ./MinecraftSurvivors.x86_64 --display-driver wayland

Это неофициальная фан-демка. Происхождение ресурсов — в licenses/.
'''
outputs=[]
for label,folder,filename in [('Windows-x64','windows','MinecraftSurvivors.exe'),('Linux-x64','linux','MinecraftSurvivors.x86_64')]:
 p=ROOT/'builds'/folder/filename
 assert p.exists(),p
 with p.open('rb') as f:
  f.seek(-4,2);assert f.read()==b'GDPC','Missing embedded PCK in '+str(p)
 archive=OUT/f'MinecraftSurvivors-{label}.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  z.write(p,filename)
  z.writestr('README.txt',readme)
  for license in sorted((ROOT/'licenses').glob('*')):z.write(license,'licenses/'+license.name)
  z.write(ROOT/'docs/MINECRAFT_ASSET_MANIFEST.json','licenses/MINECRAFT_ASSET_MANIFEST.json')
  z.write(ROOT/'docs/MINECRAFT_PRESENTATION_MANIFEST.json','licenses/MINECRAFT_PRESENTATION_MANIFEST.json')
  z.write(ROOT/'docs/MINECRAFT_CHARACTER_MANIFEST.json','licenses/MINECRAFT_CHARACTER_MANIFEST.json')
  z.write(ROOT/'docs/MINECRAFT_NETHER_MANIFEST.json','licenses/MINECRAFT_NETHER_MANIFEST.json')
  z.write(ROOT/'docs/MINECRAFT_DUEL_MANIFEST.json','licenses/MINECRAFT_DUEL_MANIFEST.json')
  z.write(ROOT/'docs/MINECRAFT_GHAST_MANIFEST.json','licenses/MINECRAFT_GHAST_MANIFEST.json')
  z.write(ROOT/'docs/MINECRAFT_END_MANIFEST.json','licenses/MINECRAFT_END_MANIFEST.json')
  z.write(ROOT/'docs/MUSIC_MANIFEST.json','licenses/MUSIC_MANIFEST.json')
  z.write(ROOT/'docs/MINECRAFT_ACHIEVEMENTS_MANIFEST.json','licenses/MINECRAFT_ACHIEVEMENTS_MANIFEST.json')
  for manifest in ['V2_ASSET_MANIFEST','CHAPTER_FOUR_ASSET_MANIFEST','CHAPTER_FOUR_AUDIO_MANIFEST']:
   z.write(ROOT/f'docs/{manifest}.json',f'licenses/{manifest}.json')
 outputs.append(archive)
source=OUT/'MinecraftSurvivors-Source.zip'
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(ROOT.rglob('*')):
  if not p.is_file():continue
  rel=p.relative_to(ROOT)
  if any(part in ['.godot','.tools','builds','.git','__pycache__'] for part in rel.parts):continue
  if p.name.startswith('.~lock.'):continue
  if p.suffix in ['.import','.avi']:continue
  if p.suffix=='.log' and not p.name.startswith(('minecraft_','presentation_','chapter_','boss_revision_','boss_polish_','ghast_update_')) and p.name not in ['verification.log','ui.log','native_release.log','build.log','performance.log','trident_run.log','animation_verification_final.log','animation_build.log','animation_performance.log','animation_full_runs.log','combat_parity.log','animation_native_release.log','animation_native_capture.log','animations_after.log','animations_before.log','animation_comparison.log']:continue
  if str(rel) in ['qa/directions.png','qa/record_frame.png']:continue
  z.write(p,str(Path('MinecraftSurvivors')/rel))
outputs.append(source)
checksums={p.name:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in outputs}
(OUT/'SHA256SUMS.txt').write_text(''.join(v['sha256']+'  '+k+'\n' for k,v in checksums.items()))
(OUT/'packages.json').write_text(json.dumps(checksums,indent=2))
for k,v in checksums.items():print(k,round(v['bytes']/1024/1024,2),'MiB')
