# -*- coding: utf-8 -*-
"""Мутации скрипта для source_check (r69): каждая ломает одну вещь из r69,
source_check обязан это заметить. Молчаливый проход = слабая проверка.
"""
import io, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
base = io.open(SRC, encoding='utf-8').read()

MUTATIONS = [
    ("версия осталась прежней",
     'GRND_SCRIPT_VERSION = "1.19.71"', 'GRND_SCRIPT_VERSION = "1.19.69"'),
    ("в панель вернули крестик",
     '                        -- Подсказка над наведённым значком',
     '                        im.InvisibleButton("##act_close_btn", im.ImVec2(1, 1))\n'
     '                        -- Подсказка над наведённым значком'),
    ("в панель вернули ник/заголовок",
     '                    A.tip = nil\n',
     '                    local targetTitle = "Действия"\n                    A.tip = nil\n'),
    ("в панель вернули шапку прежнего окна",
     '                    A.pillH = A.lo.btn + 14',
     '                    local AH_HEAD = 34\n                    A.pillH = A.lo.btn + 14'),
    ("кнопки с подпанелью снова закрывают панель",
     '                                    -- Без подпанели нажатие закрывает панель\n'
     '                                    if not subKey then',
     '                                    if true then'),
    ("панель закрывается по любому клику мыши (и по ПКМ)",
     'and type(grndLeftClickPending) == "function" and grndLeftClickPending() then',
     'and GRND_MOUSE.clicked then'),
    ("клик мимо панели больше её не закрывает",
     '                    if RC.cursor and not RC.actDragging and not A.inPanel',
     '                    if false and RC.cursor and not RC.actDragging and not A.inPanel'),
    ("сняли защиту от закрытия тем же кликом",
     'and (os.clock() - (RC.actionsWinAt or 0)) > 0.25',
     'and true'),
    ("без курсора панель перехватывает ввод",
     'flagsA = flagsA + wflag("NoInputs")',
     'flagsA = flagsA'),
    ("подпанель обрезается по ширине",
     '                    if A.subH > 0 and A.aw < 704 then A.aw = 704 end',
     '                    -- без минимальной ширины'),
    ("панель не растёт под подпанель",
     'A.ah = A.hintH + A.lo.stripH + ((A.subH > 0) and (A.subH + 4) or 0) + 2',
     'A.ah = A.hintH + A.lo.stripH + 2'),
    ("панель не за что ухватить (нет зон перетаскивания)",
     '                       and (A.inPill or A.inHint) then',
     '                       and A.inPill and false then'),
    ("нажатие по значку больше не вызывает действие",
     '                                    if _G.grndHandleActionBtn then',
     '                                    if false then'),
    ("значок рисуется не по названию действия",
     '_G.grndDrawActIcon(adl, aat, grndActIconKey(rawLabel),',
     '_G.grndDrawActIcon(adl, aat, "dot",'),
    ("подсказка над значком пропала",
     '                                    A.tip = rawLabel:gsub("\\n", " ")',
     '                                    A.tip = nil'),
    ("кнопка взаимодействия не закрывает панель",
     '                        if btnClicked and RC.actionsWinOpen then',
     '                        if false and btnClicked and RC.actionsWinOpen then'),
    ("панель открывается не у кнопки",
     'RC.actionsWinAnchorX = csx', 'RC.actionsWinAnchorX = 0'),
    ("позиция панели не сохраняется",
     'f:write("actUser=1\\n")', 'f:write("actX=1\\n")'),
    ("перетаскивание не помечает позицию как пользовательскую",
     '                            RC.actionsWinUser = true\n', ''),
    ("панель не закрывается при смене цели слежки",
     '                if RC.actionsWinOpen and RC.id ~= nil\n'
     '                   and RC.actionsWinRcId ~= nil and tonumber(RC.id) ~= RC.actionsWinRcId then',
     '                if false then'),
    ("клик по полосе действий достаётся чекерам",
     '        if RC.actionsWinOpen and grndCheckerRectOk(RC.actionsWinRect) then',
     '        if false then'),
    ("полоса снова тонкая",
     'A.pillH = A.lo.btn + 14', 'A.pillH = A.lo.btn + 10'),
    ("на границе групп снова нет отступа",
     '                local step = boundary and BOUND or GAP',
     '                local step = GAP'),
    ("кнопки снова бледные",
     'or col32(255, 255, 255, 18))), 9)', 'or col32(255, 255, 255, 6))), 9)'),
    ("у кнопок пропал блик",
     'col32(255, 255, 255, hot and 46 or 20), 1.0)', 'col32(0, 0, 0, 0), 1.0)'),
    ("щит снова ступеньками",
     'H.t(ax, ay, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])',
     'H.r(pts[i][1], pts[i][2], 0.05, 0.05)'),
    ("«Починить т/с» снова не гаечный ключ",
     'grndActArc(H, cx, cy, r, -0.12, 5.10, 16, 2.7)', 'H.c(cx, cy, r)'),
    ("значки снова мелкие",
     '    local BTN = 36', '    local BTN = 32'),
    ("разделитель снова тусклый",
     'col32(255, 255, 255, 74), 1.2)', 'col32(255, 255, 255, 22), 1.0)'),
    ("разделитель «съел» промежуток",
     '            x = x + BTN\n            if i < row.i2 then',
     '            x = x + BTN + 9\n            if i < row.i2 then'),
    ("«Заморозить» снова снежинка, а не пауза",
     'H.co(0, 0, 0.82, 1.7)\n        H.rr(-0.31, -0.36, 0.22, 0.72, 0.08)\n'
     '        H.rr(0.09, -0.36, 0.22, 0.72, 0.08)',
     'H.l(0, -0.86, 0, 0.86, 1.6)'),
    ("щит брони снова полосами-ступеньками",
     'H.t(ax, ay, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])',
     'H.r(pts[i][1], pts[i][2], 0.05, 0.05)'),
    ("повторное нажатие значка не убирает подпанель",
     '        if RC.actSubPopup == "hp" then RC.actSubPopup = nil else RC.actSubPopup = "hp" end',
     '        RC.actSubPopup = (RC.actSubPopup == "hp") and nil or "hp"'),
]

bad = 0
for name, old, new in MUTATIONS:
    if base.count(old) != 1:
        print('ПРОВАЛ ТЕСТА: якорь мутации не найден (%d): %s' % (base.count(old), name))
        bad += 1
        continue
    io.open('/tmp/srcmut.lua', 'w', encoding='utf-8').write(base.replace(old, new))
    out = subprocess.run([sys.executable, os.path.join(HERE, 'source_check.py'), '/tmp/srcmut.lua'],
                         capture_output=True)
    text = out.stdout.decode('utf-8', 'replace')
    if out.returncode == 0 and 'ALL SOURCE CHECKS PASSED' in text:
        print('НЕ ПОЙМАНА: ' + name)
        bad += 1
    else:
        first = [l for l in text.split('\n') if l.startswith('ПРОВАЛ')]
        print('поймана: %-52s | %s' % (name, first[0][:60] if first else 'ошибка'))

print('мутаций: %d, не поймано: %d' % (len(MUTATIONS), bad))
sys.exit(1 if bad else 0)
