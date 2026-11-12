"""Apply the edited dialogue sheet (docs/ALL_GAME_DIALOGUES_RU.md) back into the game sources by ID.
User rules (2026-11-12): fix typos, keep quotes, no period at the end of a line.
Paragraph breaks (blank lines) become a single "\n"; scenes split them into beats where needed.
Writes docs/ALL_GAME_DIALOGUES_RU.applied.json with the final texts."""
from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parents[1]
sheet = json.loads((ROOT / 'docs/ALL_GAME_DIALOGUES_RU.json').read_text())
md = (ROOT / 'docs/ALL_GAME_DIALOGUES_RU.md').read_text()
edited = {i: t for i, t in re.findall(r'### (\S+) · [^\n]*\n\n```text[ \t]*\n(.*?)\n```', md, re.S)}

# Corrected wording for lines the user rewrote with typos or stage notes inside the text.
FIX = {
    'I-9b5a17bc': 'Что ж, думаю, разминки хватит',
    'III-ebcf61bd': 'Даже не думай туда возвращаться',
    'III-2727048e': 'ТЫ ОПЯТЬ МЕНЯ НЕ СЛУШАЕШЬ',
    'III-a7798233': 'Снова и снова, эта грёбаная петля меня никогда не отпустит',
    'III-bdf407c9': 'Ладно...\nУ меня нет другого выбора...\nТы ничем не отличаешься от остальных...\nНАЧНЁМ!',
    'III-92a9f8d1': 'Я думал, что справлюсь с ним, долго оттачивал свои навыки и копил ярость, однако меня ждал полный провал',
    'III-6d6a1c2a': 'Грёбаный ублюдок, стоящий за ним, выдал мне одну задачу и заточил меня здесь\nСудя по всему, в его алгоритме случился сбой после того, как ты смог меня одолеть\nДо этого всё, что я мог, — временами пытаться завести с тобой разговор. Каждый раз, когда ты появлялся, моя свобода воли переставала существовать',
    'III-69938c9e': 'Я впервые проиграл после того, как $%@!^ заточил меня здесь',
    'III-822ddcb8': 'Что произошло???\nТвою ж мать, эта мразь начала меня удалять!?',
    'III-36500508': 'Слушай, у нас мало времени. Раз он начал это делать, что-то явно пошло не по его плану',
    'III-a0cfddae': 'Держи меч и Око Края, они тебе пригодятся',
    'III-c06c39de': 'Не может быть, я больше не чувствую оков. Неужели ты что-то ему сломал?',
    'III-207441d9': 'Вставай, мне нужно срочно тебе кое-что рассказать',
    'III-dbac1ec7': 'Иди и не останавливайся. Обо мне не беспокойся, мне уже ничего не поможет',
    'III-206e0a11': 'Грёбаный придурок, я это уже видел',
    'IV-34b135fa': 'Хо...\nТы опять здесь!\nЯ уж думал, ты досюда не дойдёшь',
    'IV-e82c8a9f': 'Хорошо...\nДавай всерьёз!',
    'IV-6c69e638': 'Томас и его братва пошли к нему с вилами, однако наутро Томас и другие висели у дороги',
    'IV-4fd42ae2': 'Если ты это читаешь — сними их, если сможешь',
    'V-8dff37b3': 'Интересно, понравилось ли оцифрованной душе моего брата впервые так жалко подохнуть?\nЭто ещё глупее, чем упасть в зерно и задохнуться',
    'V-be112b5b': 'ЗДЕСЬ Я ХОЗЯИН\nЯ ТЕБЯ ПОРОДИЛ, Я ТЕБЯ И УНИЧТОЖУ',
    'V-889cfc22': 'Спросишь, зачем это всё? Ну, мне было скучно, да и личный уголок для моего брата-садиста сам себя бы не создал',
    'V-7b9e2d04': 'Не знаю, что в моём спагетти настолько мутировало, что ты появился на свет',
    'V-d7deaece': 'Это даже мило, но, боюсь, мне ещё нужно откатить его тело после того, как ты буквально размозжил ему черепушку',
    'V-655b8393': 'Покажешь, чему научился?',
    'V-2ad2cc27': 'Чувак, мне чертовски скучно, пошли туда, где интереснее',
    'V-88c45a05': '...\nНе могу поверить, что проиграл тебе в этом...',
    'V-e721667f': 'Ctrl+C и Ctrl+V — половина моей унылой работы',
    'V-c258de49': 'Не забывай, что я написал всё, что тут есть',
    'V-5cbcf8e8': 'Эти штучки я называю своими лапочками',
    'V-e4f53a96': 'W\nA\nS\nD\nЭто всё, что ты умеешь?',
    'V-66a0ecb1': 'Давно мечтал устроить с кем-то мордобой',
    'V-137a83c7': 'Я какой-то сонный сегодня, не находишь это странным?',
    'V-3d38df2f': 'Слушай, как бы ни было странно, но ты действительно моё лучшее творение',
    'V-0fe97992': 'Чёрт, миллионы итераций, и никто досюда не доходил. Как это вообще могло произойти?',
    'V-6da1aa3e': 'Слушай, давай просто будем жить в гармонии? Я могу заново отстроить для тебя любой мир, вернуть "её". Зачем нам вражда?',
    'V-d98df42c': 'Хватит сканировать мой грёбаный мозг! Ты мой код, каждая твоя мысль — это моя строчка, как бы они ни мутировали!',
    'V-6819e4e0': 'ЭЙ, УБЕРИ ЭТО\nМСТИТЬ — ЭТО ДЕЛО СЛАБЫХ!',
    'V-72e7372f': 'Нет, нет, нет\nТак не пойдёт\nТы больше здесь никогда не появишься!',
    'V-54c174ac': 'Отсюда выйдет только один!',
}

def normalize(text):
    lines = [l.strip() for l in text.strip().splitlines()]
    lines = [l for l in lines if l]
    out = []
    for l in lines:
        if l.endswith('.') and not l.endswith('..') and not l.endswith('…'): l = l[:-1]
        out.append(l)
    return '\n'.join(out)

def gd_literal(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'

def find_literal(line, text):
    for q in ('"', "'"):
        esc = text.replace('\\', '\\\\').replace('\n', '\\n')
        esc = esc.replace(q, '\\' + q)
        lit = q + esc + q
        if lit in line: return lit
    return None

final = {}; changed = 0; problems = []
files = {}
for e in sheet['entries']:
    new = FIX.get(e['id'], edited.get(e['id'], e['original']))
    new = normalize(new)
    final[e['id']] = new
    if new == e['original']: continue
    changed += 1
    for src in e['sources']:
        f = ROOT / src['file']
        if 'json_path' in src:
            raw = files.setdefault(src['file'], [f.read_text()])
            old_lit = json.dumps(e['original'], ensure_ascii=False)
            if old_lit not in raw[0]: problems.append((e['id'], src['file'], 'json')); continue
            raw[0] = raw[0].replace(old_lit, json.dumps(new, ensure_ascii=False), 1)
            continue
        lines = files.setdefault(src['file'], f.read_text().splitlines(keepends=True))
        idx = src['line'] - 1
        lit = find_literal(lines[idx], e['original']) if idx < len(lines) else None
        if lit is None:
            hits = [i for i, l in enumerate(lines) if find_literal(l, e['original'])]
            if len(set(find_literal(lines[i], e['original']) for i in hits)) == 1 and hits:
                for i in hits: lines[i] = lines[i].replace(find_literal(lines[i], e['original']), gd_literal(new), 1)
                continue
            problems.append((e['id'], src['file'], src['line'])); continue
        lines[idx] = lines[idx].replace(lit, gd_literal(new), 1)
for name, content in files.items():
    f = ROOT / name
    f.write_text(''.join(content))
(ROOT / 'docs/ALL_GAME_DIALOGUES_RU.applied.json').write_text(json.dumps(final, ensure_ascii=False, indent=2) + '\n')
print('changed', changed, 'problems', problems)
