# -*- coding: utf-8 -*-
"""Мутационные проверки стенда нового WH (r72).

Каждая мутация ломает ровно одну вещь в новом WH; стенд обязан это поймать.
Если мутация не поймана — проверка стенда недостаточна, а не «всё ок».
"""
import io, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
base = io.open(SRC, encoding='utf-8').read()

MUTATIONS = [
    ("табличка не поднимается над головой на свою высоту",
     'if W.drawLabel(sx, sy - W.labelHeight(d), d, covers) then',
     'if W.drawLabel(sx, sy, d, covers) then'),
    ("табличка рисуется даже под окном ImGui",
     'if whCovered(covers, minX - 2, minY - 2, (maxX - minX) + 4, (maxY - minY) + 4) then',
     'if false then'),
    ("текст семьи прижат к левому краю плашки",
     "txt(famTxt, famX + (famW - m(pxF, famTxt)) / 2, y + (famH - pxF) / 2 - 1, pxF,",
     "txt(famTxt, famX + padX, y + (famH - pxF) / 2 - 1, pxF,"),
    ("плашка семьи теряет тёмный цвет",
     'box(famX, y, famW, famH, WH_C.dark)', 'box(famX, y, famW, famH, WH_C.barBg)'),
    ("жёлтая плашка уровня становится тёмной",
     'box(lx, y, lvlW, boxH, WH_C.lvlBg)', 'box(lx, y, lvlW, boxH, WH_C.dark)'),
    ("квадрат ID становится жёлтым",
     'box(rx, y, idW, boxH, WH_C.dark)', 'box(rx, y, idW, boxH, WH_C.lvlBg)'),
    ("полоса HP не сжимается по здоровью",
     'if hpFrac > 0 then box(famX, y, math.max(1, math.floor(famW * hpFrac + 0.5)), barH, WH_C.hp) end',
     'if hpFrac > 0 then box(famX, y, famW, barH, WH_C.hp) end'),
    ("броня рисуется даже при нуле",
     'if armor > 0 then', 'if true then'),
    ("ник не получает тень",
     'txt(nick, cx - nw / 2, y, pxN, WH_C.nick, true)',
     'txt(nick, cx - nw / 2, y, pxN, WH_C.nick, false)'),
    ("вместо «нет данных» рисуется пустая плашка",
     "local famTxt = fam or (d.known and WH_C.noFam or WH_C.noData)",
     "local famTxt = fam or (d.known and WH_C.noFam or ' ')"),
    ("вместо «Без семьи» рисуется что-то другое",
     "noFam     = 'Без семьи',", "noFam     = '?' ,"),
    ("уровень без данных рисуется нулём",
     "local lvlTxt = lvl and (tostring(lvl) .. ' LVL') or WH_C.noLvl",
     "local lvlTxt = lvl and (tostring(lvl) .. ' LVL') or '0 LVL'"),
    ("уровень берётся не из того же поля, что в карточке",
     "local raw = cell and (cell.rc_level_exp or cell.rc_level) or nil",
     "local raw = cell and cell.rc_level or nil"),
    ("масштаб табличек не растёт с разрешением",
     'local k = sh / 1080', 'local k = 1'),
    ("таблички рисуются и в старом режиме",
     'if not W.newwh then return end', 'if false then return end'),
    ("таблички рисуются поверх больших окон ImGui",
     '        if _G.GRND_BIGUI_UP then W.labelsDrawn = false return end',
     '        if false then W.labelsDrawn = false return end'),
    ("табличка рисуется на самого администратора",
     'if e.id ~= selfId and pedFor(e.id) == e.ped then',
     'if pedFor(e.id) == e.ped then'),
    ("галочка дозапроса статистики игнорируется (в очередь)",
     'if not id or not W.autoStats then return end', 'if not id then return end'),
    ("галочка дозапроса статистики игнорируется (отправка)",
     'if not W.enabled or not W.newwh or not W.autoStats then',
     'if not W.enabled or not W.newwh then'),
    ("у кого данные уже есть — спрашиваем повторно",
     'if cell and (whFamily(cell) or whLevel(cell)) then return end', 'if false then return end'),
    ("WH дублирует опрос цели слежки",
     "if type(RC) == 'table' and tonumber(RC.id) == id then return end", 'if false then return end'),
    ("спрашиваем и дальше 45 м",
     'if dist and dist > WH_STAT_RANGE then return end', 'if false then return end'),
    ("порог дистанции дозапроса сдвинут (450 вместо 45)",
     'local WH_STAT_RANGE = 45', 'local WH_STAT_RANGE = 450'),
    ("в очередь встаёт игрок с недавним запросом",
     'if at and now - at < WH_STAT_RETRY then return end', 'if false then return end'),
    ("пауза 2.5 с между запросами убрана",
     'if now - W.statNextAt < WH_STAT_GAP then return end', 'if false then return end'),
    ("значение паузы между запросами уменьшено",
     'local WH_STAT_GAP   = 2.5', 'local WH_STAT_GAP   = 0.1'),
    ("повторный запрос про игрока идёт раньше 10 минут",
     'if was and now - was < WH_STAT_RETRY then return end', 'if false then return end'),
    ("запрос уходит во время ручного /stats",
     "if type(_G.grndStatsIsManual) == 'function' and _G.grndStatsIsManual() then return end",
     'if false then return end'),
    ("запрос уходит, пока статистика занята",
     "if type(_G.grndStatsBusy) == 'function' and _G.grndStatsBusy() then return end",
     'if false then return end'),
    ("запрос уходит, пока администратор печатает",
     "if type(grndIsTyping) == 'function' and grndIsTyping() then return end",
     'if false then return end'),
    ("запрос уходит вне игры",
     "if type(grndIsSpawnedSafe) == 'function' and not grndIsSpawnedSafe() then return end",
     'if false then return end'),
    ("WH-запрос уходит с чужой пометкой",
     "pcall(_G.grndStatsRequest, id, 'wh')", "pcall(_G.grndStatsRequest, id, 'auto')"),
    ("новый режим не скрывает штатные ники",
     'function W.nativeTagsWanted() return W.newwh and 0 or 1 end',
     'function W.nativeTagsWanted() return 1 end'),
    ("штатный nametag вообще не переключается",
     'if current.tags~=tags then okT=pcall(w8,ptr+56,tags,false) end',
     'if false then okT=pcall(w8,ptr+56,tags,false) end'),
]


def build_and_run(path):
    subprocess.run([sys.executable, os.path.join(HERE, 'wh_harness.py'), path, '/tmp/h_wh_mut.lua'],
                   check=True, capture_output=True)
    out = subprocess.run([sys.executable, os.path.join(HERE, 'run_lua.py'), '/tmp/h_wh_mut.lua'],
                         capture_output=True)
    return out.stdout.decode('utf-8', 'replace') + out.stderr.decode('utf-8', 'replace')


bad = 0
for name, old, new in MUTATIONS:
    if base.count(old) != 1:
        print('ПРОВАЛ СТЕНДА: якорь мутации не найден (%d): %s' % (base.count(old), name))
        bad += 1
        continue
    io.open('/tmp/wh_mut.lua', 'w', encoding='utf-8').write(base.replace(old, new))
    res = build_and_run('/tmp/wh_mut.lua')
    if 'ALL WH SCENARIOS' in res:
        print('НЕ ПОЙМАНА: ' + name)
        bad += 1
    else:
        first = [l for l in res.split('\n') if l.startswith('ПРОВАЛ')]
        print('поймана: %-52s | %s' % (name, (first[0][:60] if first else 'ошибка выполнения')))

print('мутаций: %d, не поймано: %d' % (len(MUTATIONS), bad))
sys.exit(1 if bad else 0)
