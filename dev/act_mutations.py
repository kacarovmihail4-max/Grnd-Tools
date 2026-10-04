# -*- coding: utf-8 -*-
"""Мутационные проверки стенда панели действий (r69).

Каждая мутация ломает ровно одну вещь в настоящем скрипте; стенд обязан это
поймать. Если мутация не поймана — проверка стенда недостаточна, а не «всё ок».
"""
import io, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
base = io.open(SRC, encoding='utf-8').read()

MUTATIONS = [
    ("закрытие по клику в любом месте убрано",
     'and type(grndLeftClickPending) == "function" and grndLeftClickPending() then',
     'and false then'),
    ("задержка «клик открыл — тот же клик закрыл» убрана",
     'and (os.clock() - (RC.actionsWinAt or 0)) > 0.25',
     'and true'),
    ("все значки подменены нейтральной точкой",
     '    if has("хп", "hp", "здоров") then return "hp" end',
     '    if true then return "dot" end\n    if has("хп", "hp", "здоров") then return "hp" end'),
    ("кнопки с подпанелью стали закрывать панель",
     '                                    if not subKey then',
     '                                    if true then'),
    ("нажатие значка не выполняет действие",
     '                                    if _G.grndHandleActionBtn then',
     '                                    if false and _G.grndHandleActionBtn then'),
    ("подсказка показывает не название действия",
     '                                if bHov then\n                                    A.tip = rawLabel:gsub("\\n", " ")',
     '                                if bHov then\n                                    A.tip = "ДЕЙСТВИЕ"'),
    ("перетаскивание панели убрано",
     '                       and (A.inPill or A.inHint) then',
     '                       and false then'),
    ("панель тянется даже за нажатие по значку",
     '                        A.onBtn = false\n                        if A.inPill and A.row then',
     '                        A.onBtn = false\n                        if false then'),
    ("ряды значков не переносятся на узком экране",
     '                if widthFor(BTN, i, k + 1) > maxW then break end',
     '                if false then break end'),
    ("панель не растёт под подпанель",
     'A.ah = A.hintH + A.lo.stripH + ((A.subH > 0) and (A.subH + 4) or 0) + 2',
     'A.ah = A.hintH + A.lo.stripH + 2'),
    ("подпанель не получает минимальную ширину",
     '                    if A.subH > 0 and A.aw < 704 then A.aw = 704 end',
     '                    -- минимум ширины убран'),
    ("после «Выдать» панель остаётся висеть",
     '                            if A.subWas and not RC.actSubPopup',
     '                            if false and A.subWas and not RC.actSubPopup'),
    ("кириллица не переводится в нижний регистр",
     '    s = s:gsub("(\\208)([\\144-\\175])", function(p, b)',
     '    if true then return s end\n    s = s:gsub("(\\208)([\\144-\\175])", function(p, b)'),
    ("повторное нажатие значка не убирает подпанель",
     '        if RC.actSubPopup == "hp" then RC.actSubPopup = nil else RC.actSubPopup = "hp" end',
     '        RC.actSubPopup = "hp"'),
    ("команда действия подменена",
     '    elseif cleanLabel == "Заморозить" then',
     '    elseif cleanLabel == "Заморозить (нет)" then'),
    ("разделители снова тусклые",
     'col32(255, 255, 255, 74), 1.2)', 'col32(255, 255, 255, 20), 1.0)'),
    ("разделитель «съел» промежуток (сетка неровная)",
     '            x = x + BTN + GAP', '            x = x + BTN + GAP + 9'),
    ("полоса снова тонкая",
     'A.pillH = A.lo.btn + 12', 'A.pillH = A.lo.btn + 10'),
    ("значки снова мелкие",
     '    local BTN = 36', '    local BTN = 32'),
    ("значок рисуется заглушкой",
     '    local fn = ACT_ICONS[key] or ACT_ICONS.dot',
     '    local fn = ACT_ICONS.dot'),
    ("подложка-«таблетка» не рисуется",
     '                            afill(row.x, ry, row.w, A.pillH, col32(10, 14, 20, 236), 12)',
     '                            if false then afill(row.x, ry, row.w, A.pillH, col32(10, 14, 20, 236), 12) end'),
    ("панель не закрывается при смене цели слежки",
     '                   and RC.actionsWinRcId ~= nil and tonumber(RC.id) ~= RC.actionsWinRcId then',
     '                   and false then'),
    ("панель не отдаёт габариты чекерам",
     'RC.actionsWinRect = { x = A.ax, y = A.ay, w = A.aw, h = A.ah }',
     'RC.actionsWinRect = nil'),
    ("подсказка затирает ник/ID цели",
     '                                if bHov then\n                                    A.tip = rawLabel:gsub("\\n", " ")',
     '                                if bHov then\n                                    A.tip = "Nick [77]"'),
]


def build_and_run(path):
    subprocess.run([sys.executable, os.path.join(HERE, 'act_harness.py'), path, '/tmp/h_mut.lua'],
                   check=True, capture_output=True)
    out = subprocess.run([sys.executable, os.path.join(HERE, 'run_lua.py'), '/tmp/h_mut.lua'],
                         capture_output=True)
    return out.stdout.decode('utf-8', 'replace') + out.stderr.decode('utf-8', 'replace')


bad = 0
for name, old, new in MUTATIONS:
    if base.count(old) != 1:
        print('ПРОВАЛ СТЕНДА: якорь мутации не найден (%d): %s' % (base.count(old), name))
        bad += 1
        io.open('/tmp/mut.lua', 'w', encoding='utf-8').write(base)
        continue
    io.open('/tmp/mut.lua', 'w', encoding='utf-8').write(base.replace(old, new))
    res = build_and_run('/tmp/mut.lua')
    if 'ALL ACTION PANEL' in res:
        print('НЕ ПОЙМАНА: ' + name)
        bad += 1
    else:
        first = [l for l in res.split('\n') if l.startswith('ПРОВАЛ')]
        print('поймана: %-46s | %s' % (name, (first[0][:70] if first else 'ошибка выполнения')))

print('мутаций: %d, не поймано: %d' % (len(MUTATIONS), bad))
sys.exit(1 if bad else 0)
