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
need('GRND_SCRIPT_VERSION = "1.19.41"' in s, 'версия не 1.19.41')

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
need('QR.toast("Введите текст ответа", "warn", 2.6)' in s, 'предупреждение редактора не ушло в тост')

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
# v1.19.36: внизу раздела — подсказки про переменные {ID} и {all}
need('"{ID} — найдёт ID в репорте («дм 234», «234 дм») и подставит его в ответ"' in auto_draw_src2,
     'пропала подсказка про {ID}')
need('"После ответа автопилот сам зайдёт в слежку за этим игроком — даже если выбрана команда /goto"'
     in auto_draw_src2, 'пропала подсказка про автослежку за найденным ID')
need('"{all} — триггер сработает, даже если репорт состоит из нескольких слов"' in auto_draw_src2,
     'пропала подсказка про {all}')
need('"{punishments} — активные наказания игрока (как кнопка «Наказания игрока»)"'
     in auto_draw_src2, 'пропала подсказка про {punishments}')
need('"Переменные {ID}, {all}, {punishments} пишутся в ответе — или прямо в триггере («дм{ID}»)"'
     in auto_draw_src2, 'нет подсказки, что переменные можно писать в триггере')
absent("начинается с триггера", 'вернулась подсказка про систему «помогите»')
# v1.19.33: вместо placeholder «напр. помогите» — подсказка про синонимы; её
# длинная фраза переносится по словам (wrapW), чтобы помещалась целиком
need('local function wrapW(s, maxW, measure, scale)' in s,
     'нет переноса длинной подсказки по словам')
# v1.19.35: клик по селектору не считается «кликом мимо» — иначе список
# команд «мигал» (закрывался на нажатии и открывался на отпускании)
need('local function autoMouseOver(im, x, y, w, h)' in s,
     'нет проверки «мышь над прямоугольником»')
need('and not autoMouseOver(im, x, selY, selW, selH) then' in s,
     'клик по селектору снова закрывает список (мигание)')
need('return not autoMouseOver(im, x, y, w, h)' in s,
     'клик «мимо» списка перестал закрывать его')
# v1.19.35: вкладка «без команды» отвечает даже в слежке; мероприятие — пауза
need('if pause == "слежка" then' in s,
     'нет исключения для слежки (вкладки без команды)')
need('if not QR.autoTabCmd(id, tab, foundId) then' in s,
     'исключение в слежке не проверяет итоговую команду вкладки (свою или автослежку по {ID})')
need('local cmdHintLines = wrapW(' in s and
     '"Если триггер будет без команды, автопилот будет работать даже в слежке"' in s,
     'нет оранжевой подсказки про «без команды» у селектора')
need('ctx.uiText(cmdHintX, cmdHintTop + (li - 1) * cmdHintStep,' in s and
     'cmdHintLines[li], warnC, cmdHintSc)' in s,
     'подсказка про «без команды» рисуется не оранжевым (warnC)')
# пауза решается ПОСЛЕ поиска триггера — иначе вкладку без команды не отличить
onrep = s[s.index('function QR.autoOnReport(nick, pid, msg)'):]
pause_idx = onrep.index('local pause = QR.autoPauseTick()')
hits_idx = onrep.index('local hits = QR.autoMatchAll(text)')
need(pause_idx < hits_idx, 'порядок «пауза → триггер» сломан')
need('A.lastCheck = "пауза: " .. pause' in s, 'нет пометки паузы в подсказке')
need('"Можно ввести триггер и похожие слова к триггеру (через запятую), "' in s,
     'пропала подсказка про похожие слова у поля «Триггер»')
need('"на которые скрипт тоже так будет реагировать"' in s,
     'у подсказки про похожие слова пропал хвост')
# подсказка рисуется ДО поля: в куске кода между названием «Триггер» и полем
trig_src = s[s.index('ctx.uiText(x, yy, "Триггер", dim, 0.84)'):s.index('"##grnd_qr_auto_trigger"')]
need('wrapW(' in trig_src, 'подсказка рисуется не сразу после названия «Триггер»')
need('local tHintLines = wrapW(' in s, 'подсказка у поля «Триггер» не переносится')
absent('"напр. помогите"', 'вернулся прежний placeholder «напр. помогите» у поля «Триггер»')
absent('hintFit', 'подсказка снова подставляет имя триггера вместо слова «помогите»')
# v1.19.40: факт слежки спрашиваем у игры (sampIsPlayerSpectating и родня):
# «игра говорит, что не в слежке» — паузы нет; иначе — пауза
need('_G.grndSpecProbeState = specProbeState' in s,
     'фактическая проверка слежки не отдана наружу')
need('local P = _G.grndSpecProbeState' in s and 'if ok and st == false then return false end' in s,
     'автопилот не считает факт слежки от игры')
# v1.19.36: {ID}/{all} — триггер словом в любом месте; обычный ответ — целиком
absent('AUTO_PREFIX_TRIG', 'осталась система «помогите» (AUTO_PREFIX_TRIG)')
# v1.19.40: переменные читаются и из триггера, и из ответа; сами {…} из
# триггера вычищаются — «дм{ID}», «спек{all}», «наказ{punishments}»
need('function QR.autoVarFlags(tab)' in s and
     'local low = autoLower(tostring((tab and tab.trigger) or "")) .. " "' in s and
     'low:find("{id}", 1, true) ~= nil, low:find("{all}", 1, true) ~= nil,' in s and
     'low:find("{punishments}", 1, true) ~= nil' in s,
     'переменные вкладки читаются не из триггера и ответа')
need('(piece:gsub("%b{}", " "))' in s,
     'служебные {…} не вычищаются из триггера («дм{ID}» не сработает)')
need('function QR.autoTabCmd(pid, tab, foundId)' in s and
     'return "/sp " .. tostring(foundId)' in s,
     'нет общей «итоговой команды» вкладки (умный {ID} + своя команда)')
need('function QR.autoFindReportId(text)' in s,
     'нет поиска ID в тексте репорта')
need('local function autoWordHit(low, trig)' in s,
     'нет поиска триггера целым словом в любом месте репорта')
need('local function autoLastChar(t)' in s,
     'нет проверки границы слова слева')
need('local hit = anywhere and autoWordHit(low, trig) or (low == trig)' in s,
     'режим сопоставления выбирается не из ответа вкладки')
need('local hasID, hasAll, hasPun = QR.autoVarFlags(tabs[i])' in s,
     'вкладки не проверяются на {ID}/{all}/{punishments} при сопоставлении')
need('local cmd = QR.autoTabCmd(id, tab, foundId)' in s and
     'if not QR.autoTabCmd(id, tab, foundId) then' in s,
     'итоговая команда вкладки не используется в плане и в паузе')
need('out[#out + 1] = { idx = i, trig = trig }' in s,
     'совпадение триггера потерялось')
absent('low:find(list[k], 1, true)', 'вернулся поиск триггера подстрокой')
need('local low = trim(autoLower(autoPlain(text)))' in s,
     'текст репорта не нормализуется (пробелы/регистр) перед сравнением')
# v1.19.36: автослежка и умный {ID} в плане отправки
onrep2 = s[s.index('function QR.autoOnReport(nick, pid, msg)'):]
need('local foundId = QR.autoFindReportId(text)' in onrep2,
     'autoOnReport не ищет ID в тексте репорта')
need('local cmd = QR.autoTabCmd(id, tab, foundId)' in onrep2 and
     'return "/sp " .. tostring(foundId)' in s,
     'нет автослежки за найденным ID (даже вместо /goto)')
need('line = trim((line:gsub("{all}", "", 1)))' in onrep2,
     'служебное {all} не убирается из текста ответа')
# QR.apply: {ID} — найденный в репорте ID, иначе штатный
need('tostring(rep.foundId or "") ~= "" and tostring(rep.foundId) or pid' in s,
     '{ID} не подставляет найденный в репорте ID')
# v1.19.37: {punishments} — окно /getinfo читается, список уходит в ответ
need('QR.punBegin = function(pid, nick, mode)' in s and
     'QR.punBeginManual = function(pid, nick)' in s,
     'нет запуска ожидания окна /getinfo')
need('QR.punFinish = function(raw)' in s and 'QR.punPoll = function()' in s,
     'нет чтения окна /getinfo (хук и запасной опрос)')
need('QR.punParse = function(raw)' in s and 'QR.punChunks = function(text, limit)' in s,
     'нет разбора и нарезки списка наказаний')
need('_G.grndQrPunOnDialog = function(dialogId, style, title, b1, b2, text)' in s and
     'type(_G.grndQrPunOnDialog) == "function"' in s,
     'окно /getinfo не перехватывается (хук sampev.onShowDialog)')
need('if _G.GRND_QR and type(_G.GRND_QR.punPoll) == "function" then pcall(_G.GRND_QR.punPoll) end' in s,
     'запасной опрос окна /getinfo не вызывается из цикла')
need('function QR.autoDeliver(id, hit, tabsTxt, plan)' in s,
     'нет общей отправки плана вкладок')
need('local function autoChunks(line)' in s and 'pcall(QR.punChunks, line, 100)' in s,
     'длинный ответ не режется на сообщения')
# v1.19.38-39: проверка — ВСЕ строки автопилота уходят в /n (/n текст,
# /n /sp ID, /n /getinfo ID): ничего не выполняется, видно ровно то, что ушло бы
need('QR.autoTest = true' in s, 'нет переключателя проверки QR.autoTest')
need('local test = (QR.autoTest ~= false)' in s, 'отправка не смотрит на режим проверки')
need('if QR.queueCmd(QR.answerCmd(id, chunks[ci])) then' in s,
     'в режиме проверки ответ не уходит в /n')
# v1.19.41: ручной ответ из окна репорта — той же строкой и тоже под /n
need('_G.grndQrAnswerCmd = QR.answerCmd' in s and
     'grndRepQueue(_G.grndQrAnswerCmd(pid, enc))' in s,
     'ручной ответ из окна репорта не уходит под проверкой «/n /ans ID текст»')
need('(test and "проверка /n: " or "")' in s, 'в состоянии нет пометки проверки')
need('"Автопилот (проверка /n): игроку "' in s, 'тост не сообщает про проверку')
deliver = s[s.index('-- Отправка готового плана'):s.index('-- Тик из основного цикла')]
need('local sent = test and ("/n " .. it.cmd) or it.cmd' in deliver,
     'команда вкладки в проверке не получает префикс /n')
need('if QR.queueCmd(sent) then sentCmd = sentCmd + 1 end' in deliver,
     'команда вкладки в проверке не уходит')
need('QR.queueCmd("/n /getinfo " .. id)' in s,
     'запрос /getinfo в проверке не уходит строкой «/n /getinfo ID»')
# v1.19.41: строка ответа в проверке — целиком, вместе с командой и ID
need('function QR.autoAnsCmd(pid, text)' in s and
     'QR.queueCmd(QR.answerCmd(id, chunks[ci]))' in s and
     'function QR.answerCmd(pid, text)' in s,
     'ответ в проверке не уходит строкой «/n /ans ID текст»')
# v1.19.40: сам запрос остаётся настоящим — иначе {punishments} нечего показать
need('QR.queueCmd("/getinfo " .. id)' in s and 'local txt = lines and QR.autoPunText(lines)' in s,
     'запрос наказаний перестал быть настоящим — список не получить')
need('if QR.autoTest ~= false then' in s,
     'ветка проверки не проверяет QR.autoTest (в autOnReport нет локальной test)')
need('QR.autoPunFill(it.line, txt)' in s and '"нет активных наказаний"' in s and
     '"нет данных о наказаниях"' in s,
     'нет подстановки списка наказаний вместо {punishments}')
need('if QR.punBegin(id, nick, "auto") then' in s and 'QR.queueCmd("/getinfo " .. id)' in s,
     'автопилот не запрашивает наказания через /getinfo')
# v1.19.41: {punishments} в ТРИГГЕРЕ — ответ только про наказания
need('function QR.autoPunInTrigger(tab)' in s and
     'QR.autoPunWrap = function(txt)' in s,
     'нет режима «{punishments} в триггере — ответ про наказания»')
need('local punOnly = QR.autoPunInTrigger(tab)' in s and 'line = "{punishments}"' in s,
     'план не переключается на автоответ про наказания')
need('if trim(str) == "{punishments}" then return QR.autoPunWrap(txt) end' in s,
     'маркер автоответа не разворачивается в текст кнопки «Наказания игрока»')
# поле ответа в этом режиме прячется, вместо него — пояснение
need('local selPun = QR.autoPunInTrigger(sel2)' in s and 'if selPun then' in s and
     '"Соберётся сам:' in s,
     'поле «Ответ игроку» не скрывается при {punishments} в триггере')
# вкладка без слов (только переменные) отвечает на любой репорт
need('function QR.autoVarsOnly(tab)' in s and 'function QR.autoTrigLabel(tab)' in s and
     'if QR.autoVarsOnly(tabs[i]) then' in s,
     'вкладка с одним {punishments}/{ID} без слова не срабатывает')
# диагностика «почему не сработал» прямо в окне
need('A.lastReport = utf8Cut(tostring(nick) .. ": " .. text, 60)' in s and
     '"Репорт: " .. utf8Cut(dbgTxt, 44)' in s,
     'в окне автопилота нет строки «последний репорт и что с ним стало»')
# v1.19.41: строка репорта распознаётся и без «К-во репорта», и в вариантах
need('function QR.repCountOf(msg)' in s and 'function QR.repLaxParse(text)' in s and
     '_G.grndRepCountOf = QR.repCountOf' in s and '_G.grndRepLaxParse = QR.repLaxParse' in s,
     'нет разбора строки репорта без маркера «К-во репорта»')
need('local cnt = _G.grndRepCountOf(msg)' in s and
     'msg = msg:gsub("%[[^%]]*[Рр]епорта%s*:%s*%d*%s*%]", "")' in s,
     'маркер репорта ищется только в одном написании')
need('local lNick, lId, lMsg = _G.grndRepLaxParse(text)' in s and
     'pcall(_G.grndQrAutoOnReport, lNick, lId, lMsg)' in s,
     'строка «Ник[ID]: текст» без маркера не доходит до автопилота')
need('A.pend = { on = true, at = os.clock(), id = id, hit = hit,' in s,
     'нет ожидания окна наказаний в автопилоте')
need('pcall(QR.autoPunAbsorb, lines)' in s,
     'список наказаний не доходит до ответа автопилота')
need('if QR.punBeginManual(pid, author) then pendingClose = true end' in s,
     'кнопка «Наказания игрока» не использует общую механику')
# механика переехала из grndMainBody в модуль — старых имён быть не должно
absent('GRND_REP.punNorm', 'вернулась старая копия механики окна /getinfo')
absent('GRND_REP.punPoll', 'старый опрос окна /getinfo остался в grndMainBody')
absent('grndRepPunOnDialog', 'вернулся старый хук окна /getinfo')
# v1.19.24: у полей ввода нет своей рамки — при наведении не появляется «квадратик»
field_src = s[s.index('local function field(ctx, id, key, cap'):s.index('-- Треугольник средствами draw-list')]
need('AddRect' not in field_src,
     'у полей ввода снова своя рамка (при наведении появлялся «квадратик»)')
# v1.19.24: подсказка поля ответа — без {ник}
need('"Приветствую, уже смотрю…", true, sel2.answer' in s,
     'подсказка поля «Ответ игроку» снова с {ник}')
auto_draw_src = s[s.index('_G.grndQrAutoDraw = function(ctx)'):s.index('_G.grndQrAutoOnReport = function')]
need('{ник}' not in auto_draw_src, 'в разделе «Автопилот» снова подсказка с {ник}')
# v1.19.36: подсказки про {ID}/{all} живут только внизу раздела
need(auto_draw_src.count('{ID} — найдёт ID в репорте') == 1,
     'подсказка про {ID} должна быть ровно одна (внизу раздела)')
need('local tab = QR.autoTab(hits[k].idx)' in s, 'срабатывание не привязано к вкладке')
need('return QR.autoCmdFor(pid, tab)' in s, 'команда берётся не из вкладки')
need('line = oneLine(QR.apply(tab.answer, rep))' in s, 'ответ берётся не из вкладки')
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
# v1.19.37: ответ уходит кусками (длинный список наказаний не влезает в чат)
need('pcall(grndRepAnswer, id, chunks[ci])' in auto_part,
     'автопилот не отвечает игроку через /ans')
need(auto_part.index('pcall(grndRepAnswer, id, chunks[ci])') < auto_part.index('if it.cmd then'),
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
absent('function QR.autoShortTrigger', 'осталась проверка «слишком короткий триггер»')
# v1.19.36: границы слова нужны для режима {ID}/{all}
need('local function autoWordStart(rest)' in s,
     'нет проверки границы слова справа')
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
# v1.19.27: секция автопилота объявлена в доменах конфига — иначе open() падает
# («Unknown configuration domain») и настройки вообще не сохраняются
need('grnd_repauto="reportAuto"' in s, 'секция reportAuto не объявлена в GRND_CONFIG.sources')
# аудит: КАЖДЫЙ файл настроек обязан быть доменом конфига (иначе open() падает
# и раздел молча ничего не сохраняет — так и потерялся reportAuto)
sources_block = s[s.index('GRND_CONFIG = {schema=1, sources={'):s.index('}}', s.index('GRND_CONFIG = {schema=1, sources={'))]
declared_domains = set(re.findall(r'(grnd_[a-z_]+)="', sources_block))
own_io = {'grnd_mp.cfg'}          # панель МП пишет своим io.open (свой формат CP1251)
used_cfg = set(re.findall(r'(grnd_[a-z_]+)\.cfg', s))   # базовые имена без .cfg
missing_domains = sorted(b + '.cfg' for b in used_cfg
                         if b not in declared_domains and b + '.cfg' not in own_io)
need(not missing_domains,
     'файлы настроек без домена в GRND_CONFIG.sources: %s' % missing_domains)
# и наоборот: объявленный домен должен где-то использоваться
unused_domains = sorted(b for b in declared_domains if b not in used_cfg)
need(not unused_domains, 'объявленные, но неиспользуемые домены: %s' % unused_domains)
need('if v ~= nil then v = tostring(v) end' in s,
     'значения из config.json не приводятся к строке (числа ломают on/sel)')
absent('"count=" .. tostring(#A.tabs)', 'в файл снова пишется лишний счётчик вкладок')
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
