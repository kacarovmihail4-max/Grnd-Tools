# -*- coding: utf-8 -*-
"""Проверка исходника: кнопки видны без наведения, наведение из одного источника,
снятие стилей один-в-один, «песочница» панели, диагностика, отсутствие голых im."""
import io, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else '/home/user/Grnd-Tools/grnd_adm_tools.lua'
s = io.open(SRC, encoding='utf-8').read()
fails = []

def need(c, m):
    if not c: fails.append(m)
def absent(n, m):
    if n in s: fails.append(m)

# кнопки видны без наведения
need('bg = col32(255, 255, 255, 22)\n        border = col32(255, 255, 255, 40)' in s, 'спокойная кнопка окна не видна')
need('bg = col32(255, 255, 255, 34)\n        border = col32(255, 255, 255, 66)' in s, 'наведение не ярче спокойного')
need('bg = col32(255, 255, 255, 44)\n        border = col32(255, 255, 255, 78)' in s, 'нажатие не ярче наведения')
need('        bg = col32(255, 255, 255, 22)\n        bd = col32(255, 255, 255, 40)' in s, 'спокойная кнопка панели МП не видна')
need('bg, bd = ctx.col32(255, 255, 255, 22), ctx.col32(255, 255, 255, 40)' in s, 'спокойная кнопка шаблона не видна')
need('col32(255, 255, 255, 24)' in s, 'спокойная кнопка полосы быстрых ответов не видна')
need('hovered and 48 or 26' in s, 'спокойная заливка шестерёнки не видна')

# наведение из одного источника
need('if opts.hover == true then hov = true end' in s, 'grndUiButton не принимает opts.hover')
need('local MP_HOVER = { id = nil, frame = -99 }' in s, 'нет состояния MP_HOVER')
need('local function mpWindowHovered(im)' in s, 'нет mpWindowHovered')
need('args.hover = true' in s, 'панель не передаёт наведение в заливку')
need('settle(hov)' in s, 'нет гашения мигания')
need('local function onClickReady()' in s, 'нет гейта готовности ввода')
need('if not onClickReady() then return false end' in s, 'onClickReady не используется')

# НЕТ голых глобальных имён в модуле панели (регрессия «global im»)
mod_start = s.index('_G.MP = (function()')
mod_end = s.index('-- <<< ПАНЕЛЬ МП: КОНЕЦ БЛОКА')
module = s[mod_start:mod_end]
absent('\n    local function ownMouseClick()\n        if not ownMouseInside() then return false end\n        if im.IsWindowHovered then',
       'ownMouseClick всё ещё обращается к глобальной im')
need('    local im = ctx.im\n    -- id всегда со «##»' in s, 'в button() нет local im = ctx.im')
need('        if im.IsWindowHovered then' in s, 'проверка окна под курсором пропала')

# снятие стилей один-в-один
need('local function mpPopCols(im, n)' in s, 'нет mpPopCols')
need('local function mpPopVars(im, n)' in s, 'нет mpPopVars')
need('mpPopCols(im, nCol)' in s, 'textInput не снимает цвета через mpPopCols')
need('mpPopVars(im, padN + borderN)' in s, 'textInput не снимает переменные через mpPopVars')
absent('PopStyleColor, nCol', 'осталась счётная форма PopStyleColor(nCol)')
absent('PopStyleVar, padN + borderN', 'осталась счётная форма PopStyleVar')

# «песочница» панели
need('local function drawTopButtons(y)' in s, 'верхние кнопки не в песочнице')
need('local function drawContent(y)' in s, 'содержимое панели не в песочнице')
need('pcall(drawContent, y)' in s, 'содержимое панели не под pcall')
need('local frameErr = nil' in s, 'нет кадрового слота ошибки')
need('pcall(drawStartStop, y)' in s, 'кнопка «Начать» не в песочнице')
need('MP.contentH = tonumber(resC) - contentStart' in s, 'нет запоминания высоты содержимого')

# устойчивость к «побитому» конфигу
need('if type(MP.form) ~= "table" then MP.form = {} end' in s, 'нет защиты MP.form')
need('if type(MP.form.messages) ~= "table" then MP.form.messages = { "" } end' in s, 'нет защиты messages')
need('if type(MP.give) ~= "table" then MP.give = {} end' in s, 'нет защиты give')
need('if type(MP.presets) ~= "table" then MP.presets = {} end' in s, 'нет защиты presets')
need('tabs[i].draw = function(ctx) pcall(MP.draw, ctx) end' in s, 'вкладка панели без pcall')

# диагностика
need('a == "diag"' in s and 'pcall(mpDiag)' in s, 'нет ветки /mp diag')
need('local function mpDiag()' in s, 'нет функции mpDiag')
need('grnd_diag.log' in s, 'диагностика не пишет отчёт в файл')
need('MP.blockError' in s, 'диагностика не сообщает о сбоях блоков')
need('MP.drawFrames = (MP.drawFrames or 0) + 1' in s, 'drawInner не считает кадры')
need('GRND_SCRIPT_VERSION = "1.19.08"' in s, 'версия не 1.19.08')
need('script_version(GRND_SCRIPT_VERSION)' in s, 'script_version не из переменной')

if fails:
    for f in fails:
        print('ПРОВАЛ: ' + f)
    sys.exit(1)
print('ALL SOURCE CHECKS PASSED')
