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
need('GRND_SCRIPT_VERSION = "1.19.66"' in s, 'версия не 1.19.66')

# v1.19.57: производительность слежки — «зашёл в слежку и всё зависло»
# 1) бюджет чтений памяти: любой проход по структурам samp.dll ограничен
#    и по числу чтений, и по времени — продолжение следующим тиком
need('local BUDGET_MAX = 3000' in s and 'local function budgetStart(limit, ms)' in s and
     'local function budgetSpend()' in s,
     'нет бюджета чтений памяти (проходы снова могут делать тысячи чтений за тик)')
need('budgetStart(1200, 20)' in s, 'калибровка версии SAMP идёт без бюджета')
need('budgetStart(700, 8)' in s, 'скан структуры слежки идёт без бюджета')
need('if budget.deadline and (budget.n % 64 == 0)' in s and
     'os.clock() > budget.deadline' in s,
     'бюджет не следит за временем — рывок всё равно возможен')
# 2) указатель CLocalPlayer ищется срезами, курсор продолжается следующим тиком
need('local LP_SLICE = 0x200' in s and 'S.lpAt = to + 1' in s and
     'S.lpAtKey, S.lpAt = tostring(pPP) .. ":" .. tostring(di), 0' in s,
     'поиск CLocalPlayer снова перебирает весь диапазон за один тик')
need('findLocalPlayer(pPP, vt.lpScanMax, di)' in s,
     'поиск CLocalPlayer не получает номер кандидата (курсор срезов собьётся)')
# 3) скан структуры слежки — срезами
need('local SCAN_STEP = 0x80' in s and 'S.scanAt = to + 1' in s and 'S.scanAt = nil' in s,
     'скан структуры слежки снова перебирает все смещения за один заход')
# 4) текстдрауы рекона — порциями
need('local RC_TD_CHUNK = 256' in s and 'RC.tdSweep = sweep' in s and
     'sweep.at <= 2304' in s,
     'перебор текстдрауов снова идёт целиком за один заход')
need('if (now - (RC.scanAt or 0)) > 0.12 then' in s,
     'порции текстдрауов вызываются редко (круг станет дольше секунды)')
# 5) лучи камеры слежки: поиск стены короче, плечевые лучи — не каждый тик
need('for _ = 1, 6 do' in s, 'бинарный поиск стены снова делает десять вызовов')
need('local rays = { 0 }' in s and 'S.camRayPhase == 0 or S.camWallHit == true' in s,
     'плечевые лучи снова пускаются каждый тик')
# 6) круг цели: полный перебор пула — не чаще 4 раз в секунду
need('R.cacheTgt' in s and 'R.cacheAt' in s and '(nowR - (R.cacheAt or 0)) < 0.25' in s,
     'круг цели снова перебирает весь пул каждый кадр')
# 7) авто-перебор памяти килл-листа ограничен объёмом и временем
need('function klScanCandidates(limit, maxBytes, timeLimit)' in s and
     'klScanCandidates, 1024, 524288, 0.04' in s and
     'KL.scanStat = "перебор прерван по времени — продолжаю позже"' in s,
     'авто-перебор памяти килл-листа снова читает мегабайты в одном тике')

# v1.19.61: карточка рекона — по образцу заказчика:
#   • ник слева + ЗНАЧОК «копировать» (символа в шрифте нет — две рамки);
#   • место 3D-модели ПУСТОЕ (модель ImGui нарисовать не может);
#   • справа один прокручиваемый список: характеристика игрока, затем
#     полупрозрачная линия и статистика;
#   • стрелка внизу сворачивает и разворачивает блок информации и статистики.
card_start = s.index('if grndBegin("##grnd_recon_card", flags) then')
card_end = s.index('if endDepth > 0 then endDepth = endDepth - 1', card_start)
card = s[card_start:card_end]
need(len(card) > 4000, 'не найти блок отрисовки карточки рекона')
need('local Wfull = math.floor(math.max(400, math.min(460, resX * 0.28)))' in s,
     'карточка рекона снова узкая (в образце две колонки, ~430 px)')
need('local LW = math.floor(Wfull * 0.30)' in s and 'local RX = pad + LW + 12' in s,
     'в карточке нет левой колонки под кнопки наказаний')
# ник слева и значок «копировать» рядом с ним
need('local title = shortValue(nick, nickShort) .. " [" .. tostring(id) .. "]"' in s and
     'put(pad, 9, title, c4(TH.textHi), 1.0)' in s,
     'ник в шапке не прижат влево')
absent('math.floor((W - titleW) / 2)', 'ник в шапке снова по центру')
need('im.InvisibleButton("##grnd_recon_copy"' in s and
     'pcall(dl.AddRect, dl, at(icX + 5, icY + 4), at(icX + 13, icY + 12),' in s and
     'pcall(dl.AddRect, dl, at(icX + 8, icY + 7), at(icX + 16, icY + 15),' in s and
     'local copied = reconCopyNickname(nick)' in s,
     'рядом с ником нет значка «копировать»')
# место 3D-модели пустое: ни аватара, ни кругов
absent('string.upper(nick:match', 'в карточку вернулся аватар-буква (место 3D-модели)')
need('local leftTop = TOP_Y + 2' in s,
     'панель наказаний снова сдвинута вниз (должна быть прижата к шапке)')
absent('local MODEL_H', 'в карточке снова резервируется место под 3D-модель')
need('AddCircleFilled' not in card, 'в карточке что-то рисуется в зоне 3D-модели (круг)')
# две группы строк и полупрозрачная линия между ними
need('local ROWS_A = 4' in s and 'local ROWS_B = 15' in s and 'local DIV_H = 13' in s,
     'блоки «характеристика» и «статистика» не разделены')
need('local function divider()' in s and
     'fill(RX, dy, W - pad - RX - 12, 1, col32(255, 255, 255, 38), 0)' in s,
     'нет полупрозрачной линии между характеристикой и статистикой')
need('local rowsH = ROWS_A * ROW_H + DIV_H + ROWS_B * ROW_H' in s,
     'высота прокручиваемого блока считается не по обеим группам')
for _row in ('row("Пинг", ping, c4(TH.text), nil, nil, ROW_H)',
             'row("Здоровье", hpText, c4(TH.accent), hpNum, grndParamScale(hpNum), ROW_H)',
             'row("Броня", armText, c4(TH.accent2), armNum, grndParamScale(armNum), ROW_H)',
             'row("Скорость", speed, c4(TH.text), nil, nil, ROW_H)',
             'row("Номер аккаунта:", textValue("rc_account", "—"), c4(TH.text), nil, nil, ROW_H)',
             'row("Уровень:", lvlRaw, c4(TH.text), nil, nil, ROW_H)'):
    need(_row in s, 'в карточке нет строки образца: ' + _row)
# v1.19.62: статистика — ВСЕ поля ответа /stats, «Имя» из неё убрано
absent('row("Имя:"', '«Имя» вернулось в статистику (ник и так есть в шапке)')
for _row in ('row("Номер телефона", textValue("rc_phone", "—")',
             'row("Варнов", textValue("rc_varnov", "—")',
             'row("Пол", textValue("rc_gender", "—")',
             'row("Женат на", textValue("rc_married", "—")',
             'row("Орг. (ранг)", textValue("rc_org", "—")',
             'row("Работа/Должность", textValue("rc_job", "—")',
             'row("Бизнес", textValue("rc_business", "—")',
             'row("Игровой статус", textValue("rc_status", "—")',
             'row("Дом", textValue("rc_house", "—")',
             'row("Квартира", textValue("rc_flat", "—")',
             'row("VIP статус", textValue("rc_vip", "—")',
             'row("За сегодня", textValue("today", "—")',
             'row("Семья", textValue("rc_family", "—")'):
    need(_row in s, 'в статистике нет поля /stats: ' + _row)
absent('row("AFK"', '«AFK» вернулся в карточку рекона')
absent('row("Оружие"', '«Оружие» вернулось в карточку рекона')
absent('row("Патроны"', '«Патроны» вернулись в карточку рекона')
absent('local function section(title, open, key)',
       'в карточке снова сворачиваемые разделы')
absent('"##grnd_recon_section_"', 'вернулись заголовки-кнопки сворачиваемых разделов')
# значения как в образце
need('local ping = pingStable and tostring(math.floor(pingStable + 0.5))' in s,
     'пинг снова с « ms» (в образце просто число)')
need('local hpText = hpNum and string.format("%.1f", hpNum) or "—"' in s and
     'local armText = armNum and string.format("%.1f", armNum) or "—"' in s,
     'ХП/броня не с одним знаком после запятой (в образце «100.0», «40.0»)')
need('local speed = grndSpeedDisplay(id, textValue("speed", ""), true)' in s,
     'скорость в карточке снова с единицами (в образце — просто число)')
need('local lvlRaw = textValue("rc_level", "")' in s and 'gsub("%s*%b()", "")' in s,
     '«Уровень» снова показывает «18 (12345)» вместо числа')
# кнопки наказаний — в левой колонке, четыре (v1.19.64: MUTE обязана быть)
need('local PUN_TOP = 4' in s,
     'в карточке снова не четыре кнопки наказаний')
need('local punOrder = { "JAIL", "BAN", "KICK", "MUTE", "WARN", "SKICK", "SBAN" }' in s and
     'if it and not used[j] and tostring(it.id) == punOrder[i] then' in s,
     'кнопки снова берутся в порядке настроек — MUTE выпадет из карточки')
need('if #punItems >= PUN_TOP then break end' in s,
     'набор кнопок карточки не ограничен четырьмя')
need('local byy = leftTop + (i - 1) * (PUN_BH + PUN_BG)' in s and
     'im.InvisibleButton("##rcb_p_" .. btnLabel' in s,
     'кнопки наказаний не в левой колонке карточки')
need('if GRND_PUN and not GRND_PUN.loaded then pcall(GRND_PUN.load) end' in s,
     'карточка не подгружает настройки наказаний (кнопки исчезнут)')
absent('"##grnd_recon_bar"', 'вернулось отдельное окно панели наказаний')
need('"Кнопки наказаний в карточке"' in s and
     'JAIL · BAN · KICK · MUTE — столбиком под аватаром · курсор — ПКМ' in s,
     'описание тумблера наказаний не соответствует карточке')
# прокрутка: листается весь блок (характеристика + статистика)
# v1.19.63: карточка компактная — кончается на конце панели кнопок, а весь
# список строк живёт в окне прокрутки («сделай меньше и добавь скролл»)
need('local contentH = leftBottom + BOT + 6' in s,
     'высота карточки снова тянется по строкам (должна кончаться на конце кнопок)')
absent('local contentH = math.max(openState and (TOP_Y + rowsH) or 0',
       'вернулась высота карточки по строкам (карточка снова длинная)')
# v1.19.63: окно тянется за ЛЮБОЕ свободное место (не только за шапку)
need('local winRect = { x = px, y = py, w = W, h = H }' in s and
     'local function onWidget(mx, my)' in s and
     'and not onWidget(GRND_MOUSE.x, GRND_MOUSE.y) then' in s,
     'окно снова тянется не за любое место')
absent('local headRect = { x = px, y = py, w = W, h = HEAD }',
       'вернулось перетаскивание только за шапку')
need('local titleW = grndTextW(title)' in s and
     'local icRect = { x = px + pad + titleW + 10, y = py + 6, w = 22, h = 22 }' in s,
     'значок «копировать» не исключён из «ручек» перетаскивания')
need('icRect.x, icRect.y = px + pad + titleW + 10, py + 6' in s,
     'при перетаскивании не обновляются рамки окна (значок «отстаёт»)')
need('local SCROLL_STEP = ROW_H' in s and 'local H_MIN = 180' in s,
     'у карточки нет прокрутки (окно снова режет низ карточки)')
need("local scrollMax = openState and math.max(0, rowsH - listH) or 0" in s and
     'local function inList(y0, h0)' in s and 'local y = listTop - scroll' in s and
     'if not inList(ry, height) then return end' in s,
     'высота карточки снова считается только по содержимому')
need('if openState and scrollMax > 0 then' in s and
     'local barH = math.max(26, listH * (listH / rowsH))' in s and
     'roundRect(dl, at(trX, barY), at(trX + 3, barY + barH),' in s,
     'нет полосы прокрутки у списка карточки')
need('RC.scrollRect = { x = px + RX - 8, y = py + listTop,' in s and
     'and GRND_RC.scrollRect and grndMouseInside(GRND_RC.scrollRect) then' in s and
     '(GRND_RC.scroll or 0) - notch * step' in s and
     'local step = tonumber(GRND_RC.scrollStep) or 26' in s,
     'колесо мыши над карточкой не листает её список')
need('"NoScrollWithMouse"' in s,
     'ImGui снова может крутить содержимое карточки своим колесом')
# стрелка внизу: сворачивает и разворачивает блок информации и статистики
need('im.InvisibleButton("##grnd_recon_top"' in s and
     'if topClick then' in s and 'RC.cardOpen = not openState' in s and
     'RC.posX, RC.posY = px, py' in s and
     'RC.scroll = 0          -- развернём — список с начала' in s,
     'стрелка внизу не сворачивает карточку (или теряет левый край)')
# v1.19.64: карточка складывается ВЛЕВО — остаётся узкая полоса с кнопками
# наказаний и стрелочкой; левый край окна при этом не прыгает
need('local openState = (RC.cardOpen ~= false)' in s,
     'состояние «свёрнуто/развёрнуто» снова живёт не в RC.cardOpen')
need('local Wmini = pad + LW + 6' in s and
     'local W = openState and Wfull or Wmini' in s,
     'карточка не складывается влево в узкую полосу')
need('local RW = Wfull - pad - 12 - RX' in s,
     'ширина колонки строк считается от свёрнутой карточки (строки сломаются)')
need('local nickShort = openState and 18 or 8' in s,
     'в свёрнутой полосе ник не укорачивается (не влезет)')
need('pcall(dl.AddTriangleFilled, dl,\n                            at(cx2 - 5, cy2 + 3), at(cx2, cy2 - 3), at(cx2 + 5, cy2 + 3),' in s and
     'at(cx2 - 5, cy2 - 3), at(cx2 + 5, cy2 - 3), at(cx2, cy2 + 3),' in s,
     'стрелка не меняет направление при сворачивании/разворачивании')

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
# v1.19.56: окно закрывается после ответа игроку, а когда отвечать некому —
# остаётся открытым: текст шаблона кладётся в поле ответа
need(choose.count('QR.closeReport()') == 1,
     'окно репорта закрывается не после отправки ответа игроку')
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
# v1.19.50: внизу раздела — короткая подсказка ТОЛЬКО про переменные (лишние
# строки про автослежку и «первое слово» убраны) и она не должна накладываться
need('"Переменные — в ответе или на слове триггера: «дм{ID}», «спек{all}»"'
     in auto_draw_src2, 'нет подсказки, что переменные можно писать на слове в триггере')
need('"{ID} — игрок из репорта: номер из жалобы или ник из текста"' in auto_draw_src2 and
     '"{all} — слово сработает, даже если репорт из нескольких слов"' in auto_draw_src2 and
     '"{punishments} — вместо ответа придёт список наказаний игрока (команда не выполнится)"'
     in auto_draw_src2, 'нет подсказок про {ID}/{all}/{punishments}')
absent('После ответа автопилот сам зайдёт в слежку за игроком',
       'вернулась строка про автослежку в подсказках внизу')
absent('Несколько слов-триггеров в репорте — отвечает то, что раньше',
       'вернулась строка про «первое слово» в подсказках внизу')
# блок подсказок рисуется только если помещается целиком (иначе — не рисуется):
# строки не накладываются друг на друга и не вылезают за кромку
need('local step = lineH(ctx, sc) + 3' in auto_draw_src2,
     'шаг строк подсказок без запаса — строки могут налипнуть друг на друга')
need('if hintY + blockH <= bottomY then' in auto_draw_src2 and 'if hintLines then' in auto_draw_src2,
     'подсказки рисуются, даже когда не помещаются в окно')
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
need('local wouldCmd = (not hits[k].pun) and QR.autoTabCmd(id, tab, foundId)' in s,
     'исключение в слежке не проверяет итоговую команду вкладки (свою или автослежку по {ID})')
need('local cmdHintLines = wrapW(' in s and
     '"«Без команды»: вкладка ответит даже в слежке"' in s,
     'нет подсказки про «без команды» у селектора')
need('ctx.uiText(cmdHintX, cmdHintTop + (li - 1) * cmdHintStep,' in s and
     'cmdHintLines[li], cmdHintNone and warnC or mut, cmdHintSc)' in s,
     'подсказка про «без команды» рисуется не оранжевым (warnC)')
# пауза решается ПОСЛЕ поиска триггера — иначе вкладку без команды не отличить
onrep = s[s.index('function QR.autoOnReport(nick, pid, msg)'):]
pause_idx = onrep.index('local pause = QR.autoPauseTick()')
hits_idx = onrep.index('local hits, droppedTrig = QR.autoMatchAll(text)')
need(pause_idx < hits_idx, 'порядок «пауза → триггер» сломан')
need('A.lastCheck = "пауза: " .. pause' in s, 'нет пометки паузы в подсказке')
need('"Можно ввести триггер и похожие слова к триггеру (через запятую), "' in s,
     'пропала подсказка про похожие слова у поля «Триггер»')
need('"на которые скрипт тоже так будет реагировать"' in s,
     'у подсказки про похожие слова пропал хвост')
# подсказка рисуется ДО поля: в куске кода между названием «Триггер» и полем
trig_src = s[s.index('ctx.uiText(x, yy, "Триггер", dim, 0.84)'):s.index('"##grnd_qr_auto_trigger"')]
need('wrapW(' in trig_src, 'подсказка рисуется не сразу после названия «Триггер»')
need('local trigHint2 = wrapW(' in s and 'local tHintStep = lineH(ctx, tHintSc) + 2' in s,
     'подсказка у поля «Триггер» не переносится')
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
# v1.19.46: (1) без номера и имени в репорте уходит СВОЙ текст без ника и ID;
#          (2) подошло несколько разных слов-триггеров — отвечает первое
need('local function autoWordAt(low, trig)' in s and 'pos = autoWordAt(low, it.word)' in s and
     'if found[k].pos == best then' in s,
     'нет выбора «первое слово репорта» среди подошедших триггеров')
need('local hasTarget = (foundId ~= nil and foundId ~= "") or (tNick ~= nil and tNick ~= "")' in s and
     'local repNone = { nick = "", author = nick, id = "", foundId = "" }' in s and
     'elseif idAuto then' in s and
     'line = QR.autoWhoStrip(oneLine(QR.apply(tab.answer, repNone)))' in s,
     'нет ответа своим текстом (без ника и ID), когда в репорте нет номера и имени')
need('QR.autoGreet = function(rep)' in s or 'function QR.autoGreet(rep)' in s,
     'нет сборки приветствия из частей (без пустых «[]»)')
need('A.lastDropped' in s and ' · позже «' in s,
     'в диагностике нет пометки про слова, которые промолчали')
need('A.lastDropped' in s and 'lastDropped = droppedTrig' in s,
     'нет пометки о словах, которые промолчали')

# v1.19.45: {ник}/{ID} — тот, НА КОГО пожаловались, а не автор строки репорта
need('function QR.autoNickById(id)' in s and 'function QR.autoNickInText(text)' in s and
     'function QR.autoTargetOf(text, foundId)' in s,
     'нет поиска «того, на кого пожаловались» (ник по ID или по нику в тексте)')
need('local tNick, tId = QR.autoTargetOf(text, foundId)' in s and
     'if tId and not foundId then foundId = tId end' in s,
     'цель жалобы не ищется в autoOnReport')
need('local rep = { nick = tNick or "", author = nick, id = id, foundId = foundId }' in s,
     '{ник} в отчёте по-прежнему берётся у автора репорта')
need('["{автор}"] = author, ["{reporter}"] = author' in s and
     'local target = tostring(rep.foundId or "") ~= "" and tostring(rep.foundId) or pid' in s,
     'нет {автор} (автор строки) и {ID}/{ид} как цели жалобы')

# v1.19.44: {ID} на слове в триггере — ответ собирается САМ, поле ответа не нужно
need('QR.AUTO_GREET = "Приветствую, слежу за игроком {ник}[{ID}]"' in s and
     'function QR.autoIDInTrigger(tab)' in s and 'function QR.autoGreet(rep)' in s,
     'нет автоответа для вкладки с {ID} на слове в триггере')
need('local idAuto = (not punOnly) and (hits[k].idv and true or false)' in s and
     'line = QR.autoGreet(rep)' in s,
     'план не собирает ответ сам при {ID} на слове триггера')
# v1.19.46–53: у вкладки с {ID} поле ответа ВИДНО — оно уходит, когда в репорте
# нет ни номера, ни имени; при {punishments} поле тоже НЕ пропадает, только
# помечается, что текст не используется
need('local selID = QR.autoIDInTrigger(sel2)' in s and
     '"Ответ собирается сам: «Приветствую, слежу за игроком Ник[234]» — "' in s and
     'elseif selID then' in s,
     'поле «Ответ игроку» у вкладки с {ID} пропало или нет пояснения, когда уходит свой текст')

# v1.19.43: широкий поиск — только у слова, НА КОТОРОМ написана переменная
need('if it.wide then' in s and 'pos = autoWordAt(low, it.word)' in s,
     'режим сопоставления не привязан к слову с переменной')
need('if not punOnly then cmd = QR.autoTabCmd(id, tab, foundId) end' in s and
     'local wouldCmd = (not hits[k].pun) and QR.autoTabCmd(id, tab, foundId)' in s,
     'итоговая команда вкладки не используется в плане и в паузе')
need('out[#out + 1] = { idx = found[k].idx, trig = found[k].trig,' in s and
     'pun = found[k].pun, idv = found[k].idv }' in s,
     'совпадение триггера потерялось (или потерялись пометки переменных)')
absent('low:find(list[k], 1, true)', 'вернулся поиск триггера подстрокой')
need('local low = trim(autoLower(autoPlain(text)))' in s,
     'текст репорта не нормализуется (пробелы/регистр) перед сравнением')
# v1.19.36: автослежка и умный {ID} в плане отправки
onrep2 = s[s.index('function QR.autoOnReport(nick, pid, msg)'):]
need('local foundId = QR.autoFindReportId(text)' in onrep2,
     'autoOnReport не ищет ID в тексте репорта')
need('cmd = QR.autoTabCmd(id, tab, foundId)' in onrep2 and
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
# v1.19.56: БОЕВОЙ РЕЖИМ — служебного канала /n в автопилоте больше нет
absent('QR.autoTest', 'вернулся слой проверки /n (QR.autoTest)')
deliver = s[s.index('-- Отправка готового плана'):s.index('-- Тик из основного цикла')]
absent('"/n "', 'в отправке плана автопилота остался служебный /n')
need('if QR.queueCmd(it.cmd) then sentCmd = sentCmd + 1 end' in deliver,
     'команда вкладки не уходит')
need('local sent = false' in deliver and
     'local okA, res = pcall(grndRepAnswer, id, chunks[ci])' in deliver and
     'if not sent and QR.queueCmd(QR.autoAnsCmd(id, chunks[ci])) then' in deliver,
     'ответ игроку уходит не боевой строкой (нет /ans и запасного пути)')
need('and ("отправлено (вкладки " .. planTabsTxt' in deliver,
     'в состоянии осталась пометка проверки /n')
# v1.19.41/1.19.56: ручной ответ из окна репорта — той же боевой строкой
need('_G.grndQrAnswerCmd = QR.answerCmd' in s and
     'grndRepQueue(_G.grndQrAnswerCmd(pid, enc))' in s,
     'ручной ответ из окна репорта не уходит боевой строкой «/ans ID текст»')
anscmd = s[s.index('function QR.answerCmd(pid, text)'):s.index('-- Итоговая команда вкладки')]
absent('"/n "', 'служебный /n остался в сборке строки ответа')
need('return QR.autoAnsCmd(pid, text)' in anscmd,
     'строка ответа собирается не как «/ans ID текст» / «/pm ID текст»')
# тост всегда обычный («Автопилот: /ans 25 + /sp 25 · «дм»»)
absent('Автопилот (проверка /n)', 'вернулся тестовый тост с пометкой «проверка /n»')
need('cmdTxt[#cmdTxt + 1] = it.cmd' in s, 'в тост попадает не та команда вкладки')
# запрос наказаний — один настоящий /getinfo
need('QR.queueCmd("/getinfo " .. id)' in s and
     'QR.queueCmd("/n /getinfo " .. id)' not in s,
     'запрос /getinfo уходит не один раз (или со служебным /n)')
# v1.19.40: сам запрос остаётся настоящим — иначе {punishments} нечего показать
need('QR.queueCmd("/getinfo " .. id)' in s and 'local txt = lines and QR.autoPunText(lines)' in s,
     'запрос наказаний перестал быть настоящим — список не получить')
need('QR.autoPunFill(it.line, txt)' in s and '"нет активных наказаний"' in s and
     '"нет данных о наказаниях"' in s,
     'нет подстановки списка наказаний вместо {punishments}')
need('if QR.punBegin(id, nick, "auto") then' in s and 'QR.queueCmd("/getinfo " .. id)' in s,
     'автопилот не запрашивает наказания через /getinfo')
# v1.19.41: {punishments} в ТРИГГЕРЕ — ответ только про наказания
need('function QR.autoPunInTrigger(tab)' in s and
     'QR.autoPunWrap = function(txt)' in s,
     'нет режима «{punishments} в триггере — ответ про наказания»')
need('local punOnly = hits[k].pun and true or false' in s and 'line = "{punishments}"' in s,
     'план не переключается на автоответ про наказания')
need('if trim(str) == "{punishments}" then return QR.autoPunWrap(txt) end' in s,
     'маркер автоответа не разворачивается в текст кнопки «Наказания игрока»')
# v1.19.53: поле «Ответ игроку» НЕ скрывается даже при {punishments} в
# триггере — вместо этого под полем оранжевое пояснение, что текст не пойдёт
need('local selPun = QR.autoPunInTrigger(sel2)' in s and
     '"Этот текст не используется: в триггере {punishments} — игрок получит "' in s and
     'local ansNoteLines = ansNote and wrapW(ansNote, iw, ctx.drawnW, tHintSc) or nil' in s,
     'поле «Ответ игроку» снова прячется при {punishments} (или нет пояснения)')
need('local ansCap = punHard and 64 or 92' in s,
     'у вкладки с {punishments} поле ответа снова занимает всю высоту')
# вкладка без слов (только переменные) отвечает на любой репорт
need('function QR.autoBarePun(tab)' in s and 'function QR.autoTrigLabel(tab)' in s and
     'if QR.autoBarePun(tabs[i]) then' in s and 'function QR.autoVarsOnly(tab)' in s,
     'голая {punishments} без слова не отвечает на любой репорт')
# диагностика «почему не сработал» прямо в окне
# v1.19.53: строки диагностики в окне автопилота нет вообще, состояние
# остаётся в QR.auto.lastReport/lastCheck (тосты и /mp diag)
need('A.lastReport = utf8Cut(tostring(nick) .. ": " .. text, 60)' in s,
     'автопилот не запоминает последний репорт (диагностика и тосты)')
absent('dbgLine', 'вернулась строка диагностики «последний репорт → что стало»')
# v1.19.52–55: команда не выполняется, когда сработало слово с {punishments}
need('if not punOnly then cmd = QR.autoTabCmd(id, tab, foundId) end' in s,
     'слово с {punishments} снова выполняет команду')
need('local punNoCmd = punHard' in s and '" · команды не будет"' in s,
     'предпросмотр не предупреждает, что команда не уйдёт при {punishments}')
# v1.19.55: переменные действуют на СВОЁ слово — «…{punishments}, помогите»
# должен отвечать своим текстом и командой
need('local pun = lowPiece:find("{punishments}", 1, true) ~= nil' in s and
     'local idv = lowPiece:find("{id}", 1, true) ~= nil' in s,
     'у слов триггера снова нет собственных пометок переменных')
need('local punOnly = hits[k].pun and true or false' in s,
     'решение о наказаниях принимается по всей строке триггеров, а не по слову')
need('local idAuto = (not punOnly) and (hits[k].idv and true or false)' in s,
     'решение об авто-ответе {ID} принимается по всей строке, а не по слову')
need('function QR.autoPlainWords(tab)' in s and 'local selFree = QR.autoPlainWords(sel2) > 0' in s,
     'в подсказках не учитываются слова без переменных')
need('local ansHasPun = autoLower(tostring(tab.answer or "")):find("{punishments}", 1, true) ~= nil' in s,
     '{punishments} в ОТВЕТЕ снова определяется по триггеру')
need('"Слова с {punishments} отвечают списком наказаний (без команды); "' in s,
     'нет пояснения для смешанного триггера')
# v1.19.55: надписи «включён/выключен» в шапке раздела больше нет —
# состояние показывает тумблер, текст остаётся только для паузы
absent('stateTxt = "включён"', 'вернулась надпись «включён» в шапке автопилота')
absent('stateTxt = "выключен"', 'вернулась надпись «выключен» в шапке автопилота')
need('local tabsTop = y + 30' in s and 'if stateTxt then' in s and 'tabsTop = y + 62' in s,
     'вкладки не поднимаются на место убранной строки состояния')
# v1.19.47: репорт — ТОЛЬКО строка с маркером «[К-во репорта: N]». Разбор строки
# без маркера (послабление v1.19.41) убран: обычный чат «Ник[ID]: текст» не
# должен ни открывать окно «Репорты», ни доходить до автопилота
need('function QR.repCountOf(msg)' in s and '_G.grndRepCountOf = QR.repCountOf' in s and
     'local pat = "%[[^%]]*[Рр]епорта%s*:%s*(%d*)%s*%]"' in s,
     'нет поиска маркера «[К-во репорта: N]» (единственного признака репорта)')
absent('grndRepLaxParse', 'вернулся разбор строки репорта БЕЗ маркера «К-во репорта»')
absent('function QR.repLaxParse', 'вернулась функция разбора строки без маркера')
need('local cnt = _G.grndRepCountOf(msg)' in s and
     'if not cnt then return nil end -- не репорт, а обычная реплика' in s,
     'строка без маркера «К-во репорта» снова считается репортом')
need('if not _G.grndRepCountOf or not _G.grndRepCountOf(msg) then return end' in s,
     'текст жалобы копится из обычных реплик игрока (без маркера)')
# панель МП считает репортом только строку с маркером «[К-во репорта: N]»
need('local cnt = msg:match("%[К%-во репорта:%s*(%d*)%]")' in s and
     'if not cnt then return nil end' in s,
     'панель МП принимает за репорт строку без маркера «К-во репорта»')
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
need(auto_draw_src.count('{ID} — игрок из репорта') == 2,
     'подсказка про {ID} должна быть в двух вариантах (полном и коротком)')
# v1.19.54: строка триггеров — во всю ширину раздела, слов в ней сколько
# угодно (лимит чисто технический), буфер поля — с запасом на кириллицу
need('local MAX_ATRIG = 2048' in s and 'local TRIG_CAP = MAX_ATRIG * 2 + 1' in s,
     'строка триггеров снова с прежним лимитом в 128 символов')
need('field(ctx, tid, tkey, TRIG_CAP, x, yy, trigW, 28, "", false, sel2.trigger)' in s and
     'local trigW = iw' in s,
     'поле «Триггер» снова узкое (не во всю ширину раздела)')
absent('math.min(360, iw)', 'вернулась прежняя ширина поля «Триггер» (360 px)')
# v1.19.53: понятные подсказки для тех, кто открыл раздел впервые
need('"Вкладка — это слово из репорта: нашлось в жалобе — игроку уходит ответ, затем команда."'
     in s, 'нет расшифровки, что делает вкладка')
need('"Слово, по которому вкладка узнаёт свой репорт."' in s,
     'у поля «Триггер» нет понятного объяснения')
# подсказка у селектора команды говорит о ВЫБРАННОМ варианте
need('local cmdHintNone = (QR.autoCmdId(sel2.command) == "none")' in s and
     '"«Без команды»: вкладка ответит даже в слежке"' in s and
     '"Выполнится сразу после ответа"' in s,
     'подсказка у селектора команды снова одна на все варианты')
# каждая переменная объяснена своей строкой
need('"{ID} — игрок из репорта: номер из жалобы или ник из текста"' in s and
     '"{all} — слово сработает, даже если репорт из нескольких слов"' in s and
     '"{punishments} — вместо ответа придёт список наказаний игрока (команда не выполнится)"' in s,
     'нет понятных подсказок про переменные (по строке на каждую)')
# v1.19.53: строки диагностики внизу раздела нет целиком — состояние остаётся
# в QR.auto.lastReport/lastCheck (тосты и /mp diag)
absent('dbgLine', 'вернулась строка диагностики «последний репорт → что стало»')
absent('репортов ещё не было', 'вернулся текст «репортов ещё не было» в разделе')
# v1.19.51: низ раздела — это y + h (y — абсолютная координата, h — высота),
# иначе блок внизу «не помещался» и подсказки про переменные пропадали
need('local bottomY = y + h - 6' in auto_draw_src,
     'низ раздела снова считается от одной h (подсказки пропадут)')
need('if hintY + blockH <= bottomY then' in auto_draw_src,
     'подсказки не сверяются с настоящим низом раздела')
# высота поля «Ответ игроку» подбирается так, чтобы низ поместился целиком
need('local ansCap = punHard and 64 or 92' in auto_draw_src and
     'reserve' in auto_draw_src and 'local ansNoteLines' in auto_draw_src,
     'высота поля «Ответ игроку» больше не считается от свободного места')
# запасные варианты, когда места мало: без предпросмотра, без пояснения
need('local dropPreview = false' in auto_draw_src, 'нет запаса «без строки-предпросмотра»')
need('local hideAnsNote = false' in auto_draw_src, 'нет запаса «без пояснения под полем»')
need('local varHintsShort = {' in auto_draw_src,
     'нет короткой подсказки про переменные на тесное окно')
# узкая колонка справа от селектора команды растягивала подсказку в столбик
need('local cmdHintText = cmdHintNone' in auto_draw_src and
     'or #wrapW(cmdHintText, cmdHintW, ctx.drawnW, cmdHintSc) > 2 then' in auto_draw_src,
     'подсказка про работу без команды снова верстается в узкую колонку')
need('local tab = QR.autoTab(hits[k].idx)' in s, 'срабатывание не привязано к вкладке')
need('return QR.autoCmdFor(pid, tab)' in s, 'команда берётся не из вкладки')
need('line = QR.autoWhoStrip(oneLine(QR.apply(tab.answer, repAns)))' in s, 'ответ берётся не из вкладки')
# v1.19.46: нет номера и имени — {ник}/{ID}/{ид} не подставляются и у обычных
# вкладок (иначе в ответе оказывались ник автора и его же ID)
need('local repAns = hasTarget and rep or repNone' in s and
     'line = QR.autoWhoStrip(oneLine(QR.apply(tab.answer, repAns)))' in s and
     'function QR.autoWhoStrip(line)' in s,
     'без номера и имени ник и ID всё ещё подставляются в ответ обычной вкладки')
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
need('local guard = QR.autoGuard(os.clock())' in auto_part, 'нет предохранителей автопилота')
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
# темп: только пауза между срабатываниями.
# v1.19.42: антидубля по игроку НЕТ — ответ не повод пропускать его
# следующий репорт, сколько раз написал, столько раз и отвечаем.
# v1.19.49: пауза 0.5 с, лимита «12 ответов в минуту» больше нет.
need('local AUTO_GAP = 0.5' in s, 'пауза между срабатываниями не 0.5 с')
need('if now - (A.lastAt or 0) < AUTO_GAP then return "слишком часто" end' in s,
     'пауза между срабатываниями не применяется')
need('AUTO_PER_PID' not in s and 'A.perPid' not in s
     and 'return "этому игроку уже отвечали"' not in s,
     'вернулся антидубль «этому игроку уже отвечали»')
absent('AUTO_PER_MIN', 'вернулся лимит «12 ответов в минуту»')
absent('rate = {},', 'вернулся счётчик срабатываний A.rate')
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
# v1.19.56: ответ игроку — штатной /ans ID текст, служебного /n нет нигде
absent('QR.sendChat("/n "', 'вернулся служебный канал /n')
# v1.19.19: игроку уходит /ans ID текст, следом — команда наказания как есть
need('pcall(grndRepAnswer, pid, line)' in s, 'ответ игроку не уходит командой /ans')
pun_choose = s[s.index('function QR.punChoose(it)'):s.index('function QR.openPunPicker()')]
tail_part = pun_choose[pun_choose.index('-- v1.19.19: сначала игроку уходит ОТВЕТ'):]
need(tail_part.index('pcall(grndRepAnswer, pid, line)') < tail_part.index('QR.queueCmd(cmd)'),
     'наказание встаёт в очередь раньше ответа игроку')
need('local sent = QR.queueCmd(cmd)' in pun_choose,
     'наказание не идёт через очередь репорта (обгонит ответ игроку)')
absent('QR.sendChat("/n " .. cmd)', 'перед командой наказания остался /n')
need('QR.queueCmd(cmd)' in pun_choose, 'команда наказания не отправляется')
# быстрые ответы: ответ игроку через /ans, без ID — текст в поле ответа
need('QR.toast("Ответ игроку /ans " .. pid' in s, 'быстрые ответы не отвечают через /ans')
choose = s[s.index('function QR.choose(it)'):s.index('function QR.openPicker()')]
absent('"/n "', 'в быстрых ответах остался служебный /n')
need('pcall(grndRepAnswer, pid, text)' in choose,
     'быстрые ответы не отвечают игроку командой /ans')
need('В репорте нет ID игрока — текст шаблона вставлен в поле ответа' in s and
     'В репорте нет ID игрока — отвечать некому' in s,
     'нет боевого поведения для репорта без ID (текст в поле ответа)')
# старое значение режима «test» (/n) читается как боевой ответ игроку
need('if v == "input" then return "input" end' in s and 'return "ans"' in s,
     'режим «test» (/n) не сведён к боевому ответу')
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

# v1.19.64: /stats, который администратор ввёл РУКАМИ, не трогаем: серверное
# окно открывается как обычно, рекон не обновляется. Прячем ТОЛЬКО ответ на
# автозапрос карточки слежки.
need('local function stIsManual()' in s and
     'return os.clock() - (ST.manualAt or -999) < MANUAL_SHOW' in s and
     'local MANUAL_SHOW, MANUAL_HOLD = 15, 6' in s and
     '_G.grndStatsIsManual = stIsManual' in s,
     'нет признака «ручной /stats» (окна MANUAL_SHOW/MANUAL_HOLD)')
# v1.19.65: прятать и разбирать можно ТОЛЬКО ответ на СВОЙ запрос
need('local function stOurs()' in s and
     'if ST.ownPending then return true end' in s and
     'return os.clock() - (ST.reqAt or -999) <= 15' in s,
     'нет признака «ответ на наш запрос» (stOurs)')
need('local function stOursIngest(full)' in s and
     'if not stOursIngest(full) then return nil end' in s and
     'return ST.waiting and stTargetIn(full)' in s,
     'окно без нашего запроса снова разбирается и прячется')
need('if stSpecActive() then return stOursAwaiting() or stOurPage(full) end' in s,
     'в слежке прячется и ручное окно (должно прятаться только своё)')
need('if stIsManual() then return end' in s and
     'if not stOursIngest(full) then return end' in s,
     'запасной канал (textdraw) наполняет рекон без нашего запроса')
need('ST.ownPending, ST.ownId = true, tonumber(id)' in s,
     'своя отправка /stats не помечается точно (текст + id)')
need('and m == ("/stats " .. tostring(ST.ownId or ""))' in s and
     'and now - (ST.ownSentAt or -999) <= 1.0' in s,
     'свой /stats определяется по старой неточной метке (ручной ввод спрячется)')
need('ST.manualHold = true       -- v1.19.65: свой автозапрос — на паузу' in s and
     'ST.manualDialog = 0' in s,
     'ручной /stats не ставит свой автозапрос на паузу')
need('local manualHold = (os.clock() - (ST.manualAt or -999)) < MANUAL_HOLD' in s and
     'and not manualHold' in s,
     'свой автозапрос не замолкает на время ручного окна')
need('ST.pendingOpen = true' in s and 'ST.manualHold = false' in s,
     'после паузы карточка не просит статистику заново')
need('local function stOursAwaiting()' in s and
     'return ST.awaitAt ~= nil and not ST.awaitHave' in s and
     'local AWAIT_MAX = 6' in s,
     'нет состояния «ждём первую страницу своего ответа» (stOursAwaiting)')
need('local function stOurPage(full)' in s and
     "return tostring(full or \"\"):find(\"[\" .. tid .. \"]\", 1, true) ~= nil" in s and
     'local PAGE_GAP = 3.5' in s,
     'нет проверки «страница продолжения нашего ответа» (stOurPage)')
need('if stSpecActive() then return stOursAwaiting() or stOurPage(full) end' in s and
     'return stOursAwaiting() or stOurPage(full)' in s,
     'окно сервера прячется не только «пока ждём свой ответ»')
need('if not stOursIngest(full) then return nil end' in s,
     'окно без нашего запроса снова разбирается (данные утекут в рекон)')
need('local hideNow = _G.grndStatsShouldHide(title, text)' in s and
     'if hideNow then' in s,
     'решение «прятать ли» принимается после разбора (окно спрячется всегда)')
need('ST.awaitAt, ST.awaitHave = os.clock(), false   -- v1.19.66: ждём ответ' in s,
     'своя отправка не помечает ожидание первой страницы')
need('ST.awaitAt, ST.awaitHave = nil, true' in s,
     'ручной /stats не снимает ожидание своего ответа (окно администратора спрячется)')
need('if not relB then return nil end' in s and
     'if P.pid and lowB:find(tostring(P.pid), 1, true) then relB = true end' in s,
     'окно /getinfo принимается даже без связи с запрошенным игроком (чужое окно проглотится)')
hide_start = s.index('_G.grndStatsShouldHide = function(title, text)')
hide_end = s.index('_G.grndStatsOnDialog = function', hide_start)
hide_src = s[hide_start:hide_end]
_manual_guard = 'if stIsManual() then return false end' in hide_src
_spec_guard = 'if stSpecActive() then return stOursAwaiting() or stOurPage(full) end' in hide_src
need(_manual_guard and _spec_guard and
     hide_src.index('if stIsManual() then return false end') if _manual_guard and _spec_guard else False,
     'ручное окно /stats всё ещё прячется в слежке')
if _manual_guard and _spec_guard:
    need(hide_src.index('if stIsManual() then return false end')
         < hide_src.index('if stSpecActive() then return stOursAwaiting() or stOurPage(full) end'),
         'порядок проверок: ручное окно должно проверяться раньше слежки')
dlg_start = s.index('_G.grndStatsOnDialog = function')
dlg_src = s[dlg_start:dlg_start + 3000]
need('if _G.grndStatsIsManual and _G.grndStatsIsManual() then' in dlg_src and
     'ST.manualDialog = (ST.manualDialog or 0) + 1' in dlg_src and
     'return nil' in dlg_src,
     'окно ручного /stats разбирается в рекон (должно остаться нетронутым)')
chat_start = s.index('_G.grndStatsOnSendChat = function')
chat_src = s[chat_start:s.index('return nil\n    end', chat_start)]
need('ST.manualAt = now' in chat_src and 'ST.waiting = false' in chat_src,
     'ручной /stats становится «нашей» сессией (автозапрос спрячет чужое окно)')
need('grndStatsPopup' not in chat_src,
     'на ручной /stats снова открывается своё окно статистики')
need('return nil' in chat_src, 'ручной /stats не выходит из обработчика сразу (сессия заведётся)')
need('МОДУЛЬ 14 (v1.11.71) загружен — /stats встроен; прячем только ответ на '
     'СВОЙ запрос, окна администратора не трогаем' in s,
     'строка загрузки модуля 14 не отражает новое правило')

if fails:
    for f in fails:
        print('ПРОВАЛ: ' + f)
    sys.exit(1)
print('ALL SOURCE CHECKS PASSED')
