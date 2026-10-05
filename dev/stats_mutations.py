# -*- coding: utf-8 -*-
"""Мутационные проверки стенда статистики (r72: путь src == "wh").

Каждая мутация ломает ровно одну вещь в модуле статистики; стенд обязан
это поймать.
"""
import io, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
base = io.open(SRC, encoding='utf-8').read()

MUTATIONS = [
    ("ответ на WH-запрос наполняет карточку слежки вместо кэша",
     'if ST.src == "wh" and pid > 0 and pid ~= tonumber(RC.id or 0) then', 'if false then'),
    ("WH-ответ по цели слежки больше не идёт в карточку",
     'if ST.src == "wh" and pid > 0 and pid ~= tonumber(RC.id or 0) then',
     'if ST.src == "wh" and pid > 0 then'),
    ("данные WH не докладываются в кэш (ячейка подменяется локально)",
     'for k, v in pairs(pack) do cell[k] = v end\n            return true',
     'cell = pack\n            return true'),
    ("пометка src у запроса теряется (всё выглядит как автозапрос)",
     'ST.src = src or "auto"', 'ST.src = "auto"'),
    ("модуль статистики всегда считает себя свободным",
     '_G.grndStatsBusy = function()\n        return stOursAwaiting() and true or false\n    end',
     '_G.grndStatsBusy = function()\n        return false\n    end'),
    ("ответ на свой запрос больше не прячется",
     'local hideNow = _G.grndStatsShouldHide(title, text)',
     'local hideNow = false'),
    ("чужое окно разбирается как наше",
     'if not stOursIngest(full) then return nil end', 'if false then return nil end'),
]


def build_and_run(path):
    subprocess.run([sys.executable, os.path.join(HERE, 'stats_harness.py'), path, '/tmp/h_st_mut.lua'],
                   check=True, capture_output=True)
    out = subprocess.run([sys.executable, os.path.join(HERE, 'run_lua.py'), '/tmp/h_st_mut.lua'],
                         capture_output=True)
    return out.stdout.decode('utf-8', 'replace') + out.stderr.decode('utf-8', 'replace')


bad = 0
for name, old, new in MUTATIONS:
    if base.count(old) != 1:
        print('ПРОВАЛ СТЕНДА: якорь мутации не найден (%d): %s' % (base.count(old), name))
        bad += 1
        continue
    io.open('/tmp/st_mut.lua', 'w', encoding='utf-8').write(base.replace(old, new))
    res = build_and_run('/tmp/st_mut.lua')
    if 'ALL STATS SCENARIOS' in res:
        print('НЕ ПОЙМАНА: ' + name)
        bad += 1
    else:
        first = [l for l in res.split('\n') if l.startswith('ПРОВАЛ')]
        print('поймана: %-52s | %s' % (name, (first[0][:60] if first else 'ошибка выполнения')))

print('мутаций: %d, не поймано: %d' % (len(MUTATIONS), bad))
sys.exit(1 if bad else 0)
