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
need('GRND_SCRIPT_VERSION = "1.19.26"' in s, 'версия не 1.19.26')

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
# ---- v1.19.21: раздел «Автопилот» («Репорт» → «Автопилот») ----
# настройки: триггер, ответ игроку, команда после ответа, тумблер вкл/выкл
need('_G.grndQrAutoDraw = function(ctx)' in s, 'нет отрисовки раздела «Автопилот»')
need('elseif rt == "auto" then' in s, 'вкладка «Автопилот» ничего не рисует')
need('pcall(_G.grndQrAutoDraw, {' in s, 'раздел «Автопилот» не вызывается из меню «Репорт»')
absent('soonCard("Автопилот",', 'раздел «Автопилот» всё ещё заглушка')
need('"##grnd_qr_auto_on"' in s, 'нет тумблера включения автопилота')
need('"##grnd_qr_auto_trigger"' in s and '"autoTrigger" .. A.sel' in s, 'нет поля «Триггер»')
need('"##grnd_qr_auto_answer"' in s and '"autoAnswer" .. A.sel' in s, 'нет поля «Ответ игроку»')
# v1.19.22: во вкладках — свой триггер, ответ и команда
need('function QR.autoNewTab()' in s, 'нет пустой вкладки автопилота')
need('function QR.autoTabs()' in s, 'нет списка вкладок автопилота')
need('function QR.autoLabel(i)' in s, 'вкладка не подписана своим триггером')
need('function QR.autoAdd()' in s, 'нет добавления вкладки')
need('function QR.autoDel(i)' in s, 'вкладка не удаляется')
need('local MAX_TABS = 15' in s, 'предел вкладок не 15')
need('"##grnd_qr_auto_tab_" .. i' in s, 'вкладки не нажимаются')
need('"##grnd_qr_auto_tabc_" .. i' in s, 'у вкладки нет крестика удаления')
need('"##grnd_qr_auto_add"' in s, 'нет кнопки-плюса добавления вкладки')
absent('"##grnd_qr_auto_del"', 'вернулась кнопка «Удалить вкладку»')
absent('Добавить вкладку', 'вернулась кнопка «Добавить вкладку»')
auto_draw = s[s.index('_G.grndQrAutoDraw = function(ctx)'):s.index('_G.grndQrAutoOnReport = function')]
absent_in_draw = lambda c, w: need(c not in auto_draw, w)
absent_in_draw('Точно удалить?', 'вернулось подтверждение удаления вкладки')
absent_in_draw('Добавить вкладку', 'вернулась кнопка «Добавить вкладку»')
absent('A.delArm', 'в состоянии остался delArm (старое подтверждение)')
need('if plusClick then QR.autoAdd() end' in s, 'плюс не добавляет вкладку')
need('if pendingDel then QR.autoDel(pendingDel) end' in s, 'крестик не удаляет вкладку')
need('local function autoCross(cx, cy, r, col)' in s, 'крестик не рисуется линиями')
need('local function autoPlus(cx, cy, r, col)' in s, 'плюс не рисуется линиями')
need('tabs[1] = QR.autoNewTab()' in s, 'последняя вкладка удаляется вместо очистки')
# подписи раздела — без лишнего (v1.19.23)
absent('"вкладок: " .. tostring(#tabs)', 'вернулся счётчик вкладок в шапке')
absent('срабатываний: ', 'вернулся счётчик срабатываний в шапке')
absent('репорты проходят мимо', 'вернулась подпись «репорты проходят мимо»')
absent('пусто — вкладка молчит', 'вернулась подпись «пусто — вкладка молчит»')
absent('подставятся сами', 'вернулась подпись про {ник}/{ид}')
# триггер ищем по вкладкам, первая подошедшая — её ответ и её команда
need('function QR.autoMatchTab(text)' in s, 'нет поиска триггера по вкладкам')
# v1.19.25: срабатывают ВСЕ вкладки с совпавшим триггером, по порядку
need('function QR.autoMatchAll(text)' in s, 'нет сбора всех совпавших вкладок')
need('local hits = QR.autoMatchAll(text)' in s, 'срабатывание ищет только первую вкладку')
need('for k = 1, #hits do' in s, 'по совпавшим вкладкам нет прохода')
need('for k = 1, #plan do' in s, 'отправка идёт не по всем совпавшим вкладкам')
need('planTabsTxt' in s, 'в подсказке нет списка сработавших вкладок')
# у включённого автопилота нет подписи «при репорте: …»
auto_draw_src2 = s[s.index('_G.grndQrAutoDraw = function(ctx)'):s.index('_G.grndQrAutoOnReport = function')]
need('при репорте' not in auto_draw_src2, 'вернулась строка «при репорте: …» под тумблером')
need('на паузе — слежка, вернётся сам' in auto_draw_src2, 'пропало состояние паузы в слежке')
need('на паузе — идёт мероприятие, вернётся сам' in auto_draw_src2,
     'пропало состояние паузы на мероприятии')
need('if low == list[k] then' in s and 'out[#out + 1] = { idx = i, trig = list[k] }' in s,
     'триггер снова ищется как подстрока — репорт с лишними словами сработает')
absent('low:find(list[k], 1, true)', 'вернулся поиск триггера подстрокой')
need('local low = trim(autoLower(autoPlain(text)))' in s,
     'текст репорта не нормализуется (пробелы/регистр) перед сравнением')
# v1.19.24: у полей ввода нет своей рамки — при наведении не появляется «квадратик»
field_src = s[s.index('local function field(ctx, id, key, cap'):s.index('-- Треугольник средствами draw-list')]
need('AddRect' not in field_src,
     'у полей ввода снова своя рамка (при наведении появлялся «квадратик»)')
# v1.19.24: подсказка поля ответа — без {ник}
need('"Приветствую, уже смотрю…", true, sel2.answer' in s,
     'подсказка поля «Ответ игроку» снова с {ник}')
auto_draw_src = s[s.index('_G.grndQrAutoDraw = function(ctx)'):s.index('_G.grndQrAutoOnReport = function')]
need('{ник}' not in auto_draw_src, 'в разделе «Автопилот» снова подсказка с {ник}')
need('репорт целиком' not in auto_draw_src,
     'вернулась подсказка «репорт целиком» (v1.19.26 убрал её по просьбе)')
need('local tab = QR.autoTab(hits[k].idx)' in s, 'срабатывание не привязано к вкладке')
need('local cmd = QR.autoCmdFor(id, tab)' in s, 'команда берётся не из вкладки')
need('local line = oneLine(QR.apply(tab.answer, rep))' in s, 'ответ берётся не из вкладки')
need('planTabsTxt' in s, 'в подсказке нет списка сработавших вкладок')
# конфиг: вкладки как t<N>_trigger / t<N>_answer / t<N>_command
need('"t" .. i .. "_trigger="' in s and '"t" .. i .. "_answer="' in s and '"t" .. i .. "_command="' in s,
     'вкладки не пишутся в конфиг')
need('tostring(k or ""):match("^t(%d+)_(%a+)$")' in s, 'вкладки не читаются из конфига')
need('legacy' in s and 'файл старого формата' in s,
     'нет чтения файла старого формата (один триггер)')
need('"##grnd_qr_auto_cmd"' in s and '"##grnd_qr_auto_cmd_" .. d.id' in s,
     'нет выпадающего списка команд автопилота')
need('QR.autoCmds = AUTO_CMDS' in s, 'нет списка команд для селектора')
need('{ id = "sp",' in s and '{ id = "goto",' in s and '{ id = "none",' in s,
     'в селекторе нет /sp, /goto и «без команды»')
# триггер: несколько слов, регистр не важен, коды цвета не мешают
need('function QR.autoTriggers(tab)' in s, 'нет разбора триггера вкладки')
need('return "/" .. id .. " " .. pid' in s, 'команда после ответа не собирается')
# срабатывание: ответ игроку, затем команда, и всё — через очередь репорта
auto_part = s[s.index('function QR.autoOnReport(nick, pid, msg)'):s.index('function QR.autoTick()')]
need('pcall(grndRepAnswer, id, it.line)' in auto_part, 'автопилот не отвечает игроку через /ans')
need(auto_part.index('pcall(grndRepAnswer, id, it.line)') < auto_part.index('QR.queueCmd(it.cmd)'),
     'команда вкладки уходит раньше её ответа игроку')
need('if not A.on then' in auto_part, 'автопилот срабатывает при выключенном тумблере')
need('local guard = QR.autoGuard(id, os.clock())' in auto_part, 'нет предохранителей автопилота')
# слежка: не отвечает и выключается сам
need('function QR.autoSpectating()' in auto_part or 'function QR.autoSpectating()' in s,
     'нет проверки слежки')
need('function QR.autoSet(on)' in s, 'нет включения/выключения автопилота')
absent('QR.autoSet(false, "слежка")', 'в слежке автопилот всё ещё выключается')
absent('A.offReason', 'осталась старая причина выключения (offReason)')
need('function QR.autoPauseReason()' in s, 'нет проверки причин паузы')
need('if QR.autoSpectating() then return "слежка" end' in s, 'слежка не ставит на паузу')
need('if type(M) == "table" and M.active then return "мероприятие" end' in s,
     'мероприятие (панель МП) не ставит автопилот на паузу')
need('local pause = QR.autoPauseTick()' in auto_part, 'репорт не проверяет паузу')
need('A.lastCheck = "пауза: " .. pause' in auto_part, 'нет пометки паузы в подсказке')
need('local reason = QR.autoPauseTick()' in s, 'тик не следит за паузой')
need('A.paused = on and QR.autoPauseReason() or nil' in s, 'тумблер не помечает паузу')
# состояние на вкладке говорит про паузу, а не про выключение
need('на паузе — слежка, вернётся сам' in s, 'на вкладке нет состояния паузы (слежка)')
need('на паузе — идёт мероприятие, вернётся сам' in s,
     'на вкладке нет состояния паузы (мероприятие)')
# v1.19.26: подсказок у поля «Триггер» нет, короткий триггер разрешён
trigger_src = s[s.index('ctx.uiText(x, yy, "Триггер", dim, 0.84)'):s.index('Команда после ответа')]
need('слишком короткий' not in trigger_src, 'вернулась подпись про короткий триггер')
need('репорт целиком' not in trigger_src, 'вернулась подпись «репорт целиком»')
absent('function QR.autoShortTrigger', 'осталась проверка «слишком короткий триггер»')
need('if low == list[k] then' in s, 'полное совпадение триггера пропало')
# идёт ввод текста — пропуск, чтобы не мешать набору
need('A.lastCheck = "идёт ввод текста — пропуск"' in auto_part,
     'автопилот не пропускает репорты во время ввода текста')
need('QR.toast("Автопилот: пропуск — открыт чат или ввод"' in auto_part,
     'нет предупреждения о пропуске')
# предохранители: пауза, антидубль по ID, лимит в минуту
need('local AUTO_GAP = 2.5' in s and 'local AUTO_PER_PID = 60' in s and 'local AUTO_PER_MIN = 12' in s,
     'нет настроек предохранителей автопилота')
need('return "этому игроку уже отвечали"' in s, 'нет антидубля по ID игрока')
need('return "лимит " .. tostring(AUTO_PER_MIN) .. " в минуту"' in s, 'нет лимита срабатываний')
# конфиг автопилота — отдельный файл, правки пишутся с задержкой
need('function QR.autoPath()' in s and 'grnd_repauto.cfg' in s, 'нет своего файла настроек автопилота')
need('function QR.autoLoad()' in s and 'function QR.autoSave()' in s, 'настройки автопилота не сохраняются')
need('function QR.autoTick()' in s, 'нет тика автопилота')
need('pcall(_G.grndQrAutoTick)' in s, 'тик автопилота не вызывается из цикла')
need('_G.grndQrAutoOnReport = function(nick, pid, msg)' in s, 'нет хука автопилота на репорт')
need('pcall(_G.grndQrAutoOnReport, nick, pid, msg)' in s, 'репорты не доходят до автопилота')
# репорт ловим ДО проверки оверлея «Репорты»: автопилот работает и с выключенным оверлеем
rephud = s[s.index('local function grndRepHudOnChat(text)'):s.index('local function grndRepHudOpenItem(')]
need(rephud.index('pcall(_G.grndQrAutoOnReport, nick, pid, msg)') < rephud.index('if not GRND_REPHUD.enabled then return end'),
     'автопилот видит репорты только при включённом оверлее «Репорты»')
need('pcall(_G.grndQrAutoOnReport, nick, pid, msg)' in s[:s.index('local function grndRepHudOnChat(text)')],
     'репорты админ-бота не доходят до автопилота')
# команда уходит в чат в CP1251 (русская причина наказания не «закорючками»)
need('function QR.queueCmd(cmd)' in s, 'нет общей отправки команд через очередь репорта')
need('pcall(grndAnsiText, cmd)' in s, 'команда уходит в чат без перевода в CP1251')
need('Q.auto.listOpen = false' in s and 'Q.auto.listOpen then' in s, 'ESC не закрывает список команд автопилота')
# v1.19.21: все под-вкладки «Репорта» готовы — заготовок «в разработке» нет
absent('local bl = "в разработке"', 'вернулась заготовка «в разработке» в разделе «Репорт»')
absent('soonCard(', 'вернулись окна-заготовки разделов')
absent('local isTools', 'осталась старая логика двух под-вкладок «Репорт»')

# v1.19.16: шаблоны наказаний — как ответы, но с командой, сроком и причиной
need('grnd_reppunish="reportPunish"' in s, 'нет секции конфига для шаблонов наказаний')
need("section=='reportTemplates' or section=='reportPunish'" in s, 'читалка конфига не знает reportPunish')
need('local punCmds = {' in s, 'нет списка команд наказаний')
for c in ('{ id = "ban"', '{ id = "mute"', '{ id = "rmute"'):
    need(c in s, 'в селекторе нет команды ' + c)
# v1.19.17: /jail, /kick и /warn из селектора убраны
for c in ('{ id = "jail"', '{ id = "kick"', '{ id = "warn"'):
    absent(c, 'в селекторе осталась убранная команда ' + c)
need('function QR.punDef(id)' in s, 'нет разбора команды наказания')
need('function QR.punCommand(it, rep)' in s, 'нет сборки команды наказания')
# v1.19.17: в тестовом режиме в /n уходит и ответ на репорт
need('QR.sendChat("/n " .. line)' in s, 'ответ на репорт не уходит в /n вместе с командой')
need('и ответ игроку' in s, 'тост не сообщает про оба сообщения в /n')
# v1.19.19: ответ игроку — штатной /ans ID текст, наказание — без /n
need('pcall(grndRepAnswer, pid, line)' in s, 'ответ игроку не уходит командой /ans')
pun_choose = s[s.index('function QR.punChoose(it)'):s.index('function QR.openPunPicker()')]
tail_part = pun_choose[pun_choose.index('-- v1.19.19: сначала игроку уходит ОТВЕТ'):]
need(tail_part.index('pcall(grndRepAnswer, pid, line)') < tail_part.index('QR.queueCmd(cmd)'),
     'наказание встаёт в очередь раньше ответа игроку')
need('local sent = QR.queueCmd(cmd)' in pun_choose,
     'наказание не идёт через очередь репорта (обгонит ответ игроку)')
absent('QR.sendChat("/n " .. cmd)', 'перед командой наказания остался /n')
need('QR.queueCmd(cmd)' in pun_choose, 'команда наказания не отправляется')
# быстрые ответы: ответ тоже через /ans, /n остаётся только как путь без ID
need('QR.toast("Ответ игроку /ans " .. pid' in s, 'быстрые ответы не отвечают через /ans')
choose = s[s.index('function QR.choose(it)'):s.index('function QR.openPicker()')]
need(choose.index('pcall(grndRepAnswer, pid, text)') < choose.index('QR.sendChat("/n " .. line)'),
     'в быстрых ответах /ans должен идти раньше резервного /n')
need('Нет ID игрока (ответить некому)' in s, 'пропал резервный путь /n для репорта без ID')
# v1.19.20: клавиши и кнопки мыши не залипают, пока окно владеет вводом
need('function grndMsgIsPress(msgN)' in s, 'нет разбора «нажатие или отпускание»')
need('local pressMsg=grndMsgIsPress(msgN)' in s, 'гейт UI не различает нажатие и отпускание')
need('if uiGate and isMouseInput and not nativeChatWheel and pressMsg then' in s,
     'мышь при открытом окне отдаёт игре не только нажатия')
need('and not spectatorExitKey and pressMsg then' in s,
     'клавиши при открытом окне отдают игре и опускания')
absent('if uiGate and isMouseInput and not nativeChatWheel then',
       'старый гейт съедает WM_*BUTTONUP (кнопки мыши залипают)')
absent('''if uiGate and isKeyInput and not nativeChatInput
            and not nativeChatOpeningKey and not spectatorExitKey then''',
       'старый гейт съедает WM_KEYUP (клавиши залипают)')
msgpress = s[s.index('function grndMsgIsPress(msgN)'):s.index('local function grndStickyNothingPressed()')]
for line in ('msgN == 0x0100', 'msgN == 0x0101' if False else 'msgN == 0x0102'):
    need(line in msgpress, 'в grndMsgIsPress нет условия ' + line)
need('msgN == 0x0202 or msgN == 0x0205 or msgN == 0x0208 or msgN == 0x020B' in msgpress,
     'button-up сообщения снова считаются нажатием')
need('function grndStickyKeysTick()' in s, 'нет страховочного сброса игровых клавиш')
need('pcall(grndStickyKeysTick)' in s, 'сброс игровых клавиш не вызывается из цикла')
need('pcall(setGameKeyState, GRND_STICKY_GAME_KEYS[i], 0)' in s,
     'игровые клавиши не отпускаются')
need('if not grndStickyNothingPressed() then return end' in s,
     'сброс клавиш не сверяется с реальной клавиатурой')
need('GRND_STICKY.tailUntil = now + 0.6' in s, 'нет «хвоста» после закрытия окна')
need('GRND_CAM.windowFocused == false' in s, 'нет сброса клавиш при потере фокуса')
need('stick=%d/%s' in s, 'в диагностике нет счётчика снятых залипаний')

# баг первой строки списка наказаний
need('local fully = (iy >= listY - 0.5) and (iy + rowH <= listY + listH + 0.5)' in s,
     'первая строка списка наказаний снова считается невидимой (мёртвые стрелки)')
need('local canUp = (pidx or 1) > 1' in s and 'local canDn = pidx ~= nil and pidx < QR.punCount()' in s,
     'стрелки на краях списка наказаний не отключаются')
# полоса обжимает кнопки: минимум ширины снижен, пустоты справа нет
absent('local W = math.max(184, math.min(maxW, contentW + PICK_PADX * 2))',
       'вернулась полоса шириной минимум 184 px (пустота справа)')
need(s.count('local W = math.max(96, math.min(maxW, contentW + PICK_PADX * 2))') == 2,
     'полоса не обжимает кнопки')
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
