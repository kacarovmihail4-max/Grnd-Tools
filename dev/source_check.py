# -*- coding: utf-8 -*-
"""Проверка исходника: кнопки видны без наведения, наведение из одного источника,
снятие стилей один-в-один, «песочница» панели, диагностика, отсутствие голых im."""
import io, sys, re
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
need('GRND_SCRIPT_VERSION = "1.19.16"' in s, 'версия не 1.19.16')

# верхняя акцентная полоска убрана во ВСЕХ окнах (v1.19.09)
top_strips = []
for m in re.finditer(r'(?:gradRect|AddRectFilled)\s*\(\s*(?:at|eat|bat|aat)\(\s*[^,]+,\s*([0-9.]+)\s*\)\s*,\s*(?:at|eat|bat|aat)\(\s*[^,]+,\s*([0-9.]+)\s*\)', s):
    y1, y2 = float(m.group(1)), float(m.group(2))
    if y1 <= 4.5 and y2 <= 4.5 and y2 > y1:
        top_strips.append(s[:m.start()].count('\n') + 1)
need(not top_strips, 'вернулась акцентная полоска сверху (строки: %s)' % top_strips)
need('box(0, 0, W, 3, 0xFF00D6AA)' not in s, 'вернулась полоска сверху в аварийной отрисовке рекона')
# оверлей «РЕПОРТЫ» на экране: полоса рисовалась градиент-хелперами, а не gradRect
need('H.dxHGrad(px + accentX' not in s, 'вернулась полоска сверху в оверлее «РЕПОРТЫ» (DX-путь)')
need('at(accentX, sh), at(accentX + accentW, sh + accentH)' not in s,
     'вернулась полоска сверху в оверлее «РЕПОРТЫ» (ImGui-путь)')
need('local accentH = math.max(2, S(3))' not in s, 'вернулся расчёт полоски оверлея «РЕПОРТЫ»')
need('script_version(GRND_SCRIPT_VERSION)' in s, 'script_version не из переменной')

# v1.19.10: полоса шаблонов вровень с левым краем окна репорта + окно закрывается
need('GRND_REP.winX, GRND_REP.winW = winX, W' in s, 'окно репорта не запоминает левый край')
need('if not repX then repX = math.floor((resX - repW) / 2) end' in s,
     'нет фолбэка позиции полосы шаблонов')
need('math.min(math.max(10, resX - W - 10), repX)' in s,
     'полоса шаблонов не выравнивается по левому краю окна репорта')
need('function QR.closeReport()' in s, 'нет функции закрытия окна репорта из полосы шаблонов')
choose_start = s.index('function QR.choose(it)')
choose = s[choose_start:s.index('function QR.openPicker()', choose_start)]
need(choose.count('QR.closeReport()') == 2, 'окно репорта закрывается не после каждой отправки шаблона')
need('R.open = false' in choose or 'R.open = false' in s, 'окно репорта не закрывается')

# v1.19.11: полоса шаблонов приклеена под нижнюю кромку окна репорта
need('GRND_REP.winY, GRND_REP.winH = winY, H' in s, 'окно репорта не запоминает верх и высоту')
need('local PICK_ATTACH = 10' in s, 'нет зазора до нижней кромки окна репорта')
need('local repY, repH = tonumber(R.winY), tonumber(R.winH)' in s,
     'полоса не читает вертикальные габариты окна репорта')
need('y = repBottom + PICK_ATTACH' in s, 'полоса не встаёт под нижнюю кромку окна репорта')
# v1.19.12: строки-подсказки нет, полоса растёт вниз рядами кнопок до края экрана
absent('клик — отправить · ESC — закрыть', 'вернулась строка-подсказка под кнопками')
absent('PICK_HINT_H', 'осталась высота строки-подсказки')
need('local PICK_SCREEN_GAP = 10' in s, 'нет зазора до нижнего края экрана')
need('math.floor(resY - y - PICK_SCREEN_GAP) - PICK_PADY * 2' in s,
     'высота полосы не растёт до нижнего края экрана')
absent('math.min(maxViewH, room)', 'высота полосы всё ещё режется по окну репорта')
absent('math.floor(resY * 0.40)', 'остался старый потолок в 40% высоты экрана')
need('pcall(im.SetTooltip, oneLine(hoverIt.text or ""))' in s,
     'полный текст шаблона не показывается подсказкой')
# v1.19.13: полоса не шире окна репорта — лишние кнопки уходят на новый ряд
need('repW = tonumber(R.winW)' in s, 'полоса не читает ширину окна репорта')
need('local maxW = math.min(920, math.max(240, resX - 80), repW)' in s,
     'полоса не ограничена шириной окна репорта')

# v1.19.14: в редакторе шаблона нет нижних строк — «Переменные» и заметки-подсказки
absent('Переменные: {ник} · {ид} · {время} · {мой_ник}', 'вернулась строка «Переменные» в редакторе')
absent('Нажмите «Точно удалить?» для удаления', 'вернулась строка-подсказка при нажатии «Удалить»')
need('if QR.note and (os.clock() - (QR.noteAt or 0)) < 6 then' not in s,
     'вернулась отрисовка внутренней заметки в редакторе')
need('local btnH, footH = 32, 12' in s, 'место нижних строк не отдано полю «Текст ответа»')
need('QR.toast("Шаблон удалён", "ok", 2.2)' in s, 'удаление шаблона не сообщается тостом')
need("QR.toast(\"Введите текст ответа\", \"warn\", 2.6)" in s, 'предупреждение редактора не ушло в тост')

# v1.19.15: в разделе «Репорт» четыре под-вкладки, две из них — заготовки
need('{ id = "punish",  label = "Наказания" }' in s, 'нет под-вкладки «Наказания» в разделе «Репорт»')
need('{ id = "auto",    label = "Автопилот" }' in s, 'нет под-вкладки «Автопилот» в разделе «Репорт»')
need('"##grnd_rep_tab_" .. tb.id' in s, 'под-вкладки раздела «Репорт» не рисуются общим рядом')
need('if menu.reportTab == "tools" then' in s, 'ветка «Инструменты» раздела «Репорт» пропала')
need('elseif menu.reportTab == "answers" then' in s, 'ветка «Ответы на репорт» раздела «Репорт» пропала')
need('soonCard("Автопилот",' in s, 'раздел «Автопилот» ничего не рисует')
need('local bl = "в разработке"' in s, 'раздел «Автопилот» не помечен «в разработке»')
absent('local isTools', 'осталась старая логика двух под-вкладок «Репорт»')

# v1.19.16: шаблоны наказаний — как ответы, но с командой, сроком и причиной
need('grnd_reppunish="reportPunish"' in s, 'нет секции конфига для шаблонов наказаний')
need("section=='reportTemplates' or section=='reportPunish'" in s, 'читалка конфига не знает reportPunish')
need('local punCmds = {' in s, 'нет списка команд наказаний')
for c in ('{ id = "ban"', '{ id = "mute"', '{ id = "rmute"', '{ id = "jail"', '{ id = "kick"', '{ id = "warn"'):
    need(c in s, 'в селекторе нет команды ' + c)
need('function QR.punDef(id)' in s, 'нет разбора команды наказания')
need('function QR.punCommand(it, rep)' in s, 'нет сборки команды наказания')
need('QR.sendChat("/n " .. cmd)' in s, 'наказание не проверяется через /n (тестовый режим)')
need('ID игрока не распознан — наказание не отправлено' in s, 'наказание уходит без проверки ID')
need('ctx.uiText(ix, yy, "Время, " .. tostring(def.unit or ""), dim, 0.82)' in s,
     'в редакторе наказания нет поля «Время» с единицами')
need('"Причина", dim, 0.82' in s, 'в редакторе наказания нет поля «Причина»')
need('if P.comboOpen and QR.punCmds then' in s, 'нет выпадающего списка команд')
need('"##grnd_qr_pun_cmd_" .. d.id' in s, 'строки выпадающего списка команд не нажимаются')
need('"##grnd_qr_pun_text", "punText", 2048' in s, 'нет поля «Ответ на репорт» в наказании')
need('local PUN_TEXT_H = 68' in s, 'поле «Ответ на репорт» в наказании не компактнее ответов')
need('pcall(_G.grndQrPunishDraw, {' in s, 'под-вкладка «Наказания» не рисует редактор шаблонов')
absent('soonCard("Наказания",', 'раздел «Наказания» всё ещё заглушка')

# полоса наказаний: как «быстрые ответы», только по центру окна репорта
need('_G.grndQrPunPickerDraw = function(ctx)' in s, 'нет своей полосы наказаний')
need('ctx.begin("##grnd_qr_pun_picker", flags)' in s, 'полоса наказаний не рисуется окном')
need('local x = repX + math.floor((repW - W) / 2)' in s, 'полоса наказаний не по центру окна репорта')
need('_G.GRND_QR.togglePunPicker' in s and 'grnd_rep_punish_btn' in s,
     'кнопка «Наказание» не открывает полосу шаблонов')
need('pcall(_G.grndQrPunPickerDraw, qrCtx)' in s, 'полоса наказаний не рисуется в кадре')
need('if type(P) == "table" and P.comboOpen then' in s or 'if P.comboOpen then' in s,
     'ESC не закрывает список команд')
absent('local rows, contentW = pickerLayout(ctx, math.min(920, math.max(240, resX - 80)) - PICK_PADX * 2)',
       'раскладка полосы считается по старой ширине')
absent('local y = math.max(16, math.min(resY - H - 40, math.floor((resY - H) * 0.72)))',
       'осталась старая «оторванная» позиция полосы')

if fails:
    for f in fails:
        print('ПРОВАЛ: ' + f)
    sys.exit(1)
print('ALL SOURCE CHECKS PASSED')
