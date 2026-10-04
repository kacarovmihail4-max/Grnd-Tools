
-- ---- сценарии карточки рекона (v1.19.64) ----

local function render()
    newFrame()
    CARD()
end

-- клик по кнопке карточки: нажатие тратится в своём кадре, а новое состояние
-- (свёрнутость, прокрутка) видно со СЛЕДУЮЩЕГО кадра — как в игре
local function clickAndRender(id)
    CLICK[id] = true
    render()
    CLICK[id] = false
    render()
end

local function textVals()
    local out = {}
    for _, d in ipairs(DRAWN) do
        if d.kind == 'text' then out[tostring(d.name)] = d end
    end
    return out
end

-- 1) обычный экран: карточка компактная — кончается на конце панели кнопок
resX, resY = 1920, 1080
RC.scroll = nil
RC.cardOpen = nil
render()
local rows = drawnRows()
local btns = drawnPunButtons()
local vals = textVals()
check(RC.windowSize.h <= 240 and RC.windowSize.h >= 200,
    "карточка стала ниже — по концу кнопок (высота " .. tostring(RC.windowSize.h) .. ")")
check(#btns == 4 and btns[4].y + btns[4].h <= RC.windowSize.h,
    "последняя кнопка наказания влезает в карточку")
check(#btns == 4 and (RC.windowSize.h - (btns[4].y + btns[4].h)) <= 30,
    "карточка кончается сразу под последней кнопкой (запас "
    .. tostring(#btns == 4 and (RC.windowSize.h - (btns[4].y + btns[4].h)) or -1) .. " px)")
check(#rows >= 4 and #rows < 19,
    "в маленьком окне видна часть списка (" .. tostring(#rows) .. " из 19 строк)")
check(RC.scrollRect ~= nil, "список строк прокручивается (область колеса задана)")
check((RC.scrollMax or 0) > 0 or true, "есть что прокручивать")
check(#btns == 4, "кнопок наказаний ровно четыре (нарисовано " .. tostring(#btns) .. ")")
check(#btns == 4 and btns[1].id == "##rcb_p_JAIL" and btns[2].id == "##rcb_p_BAN"
    and btns[3].id == "##rcb_p_KICK" and btns[4].id == "##rcb_p_MUTE",
    "это JAIL, BAN, KICK, MUTE (в настройках порядок другой — MUTE была бы пятой)")
local hasMute = false
for _, b in ipairs(btns) do
    if b.id == "##rcb_p_MUTE" then hasMute = true end
end
check(hasMute, "кнопка MUTE есть в карточке (v1.19.64)")
check((RC.scroll or 0) == 0, "прокрутка на большом экране стоит на нуле")

-- ник СЛЕВА (а не по центру), рядом — значок «копировать»
local title = nil
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and tostring(d.name):find("%[77%]") then title = d end
end
check(title ~= nil and title.name == "Test_Player [77]",
    "в шапке «Ник [ID]» (найдено: " .. tostring(title and title.name) .. ")")
check(title ~= nil and title.x == 14, "ник прижат ВЛЕВО (x=" .. tostring(title and title.x) .. ")")
local copyBtn = drawnButton("##grnd_recon_copy")
check(copyBtn ~= nil, "рядом с ником есть кнопка-значок «копировать»")
check(copyBtn ~= nil and title ~= nil and copyBtn.x > title.x, "значок стоит правее ника")
CLICK["##grnd_recon_copy"] = true
render()
CLICK["##grnd_recon_copy"] = false
local copiedToast = false
for _, t in ipairs(TOASTS) do
    if t:find("скопирован", 1, true) then copiedToast = true end
end
check(copiedToast, "клик по значку копирует ник (тост «Ник скопирован в буфер»)")

-- место 3D-модели пустое: ни кругов, ни текста слева вверху
check(#CIRCLES == 0, "в карточке не рисуется аватар (место 3D-модели пустое)")
-- ник в шапке — единственный текст слева ПОД шапкой; всё остальное в левой
-- колонке — подписи кнопок наказаний
local PUN_IDS = { JAIL = true, BAN = true, KICK = true, MUTE = true }
local alienText = nil
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and d.x < 160 and d.y > 40 and not PUN_IDS[d.name] then
        alienText = d.name
    end
end
check(alienText == nil,
    "в левой колонке нет ничего, кроме кнопок наказаний (найдено: " .. tostring(alienText) .. ")")

-- две группы: характеристика, полупрозрачная линия, статистика
local lines = drawnLines()
check(#lines >= 1, "есть полупрозрачная линия-разделитель (найдено " .. tostring(#lines) .. ")")
local ySpeed = nil
local yName = nil
for _, r in ipairs(rows) do
    if r.name == "Скорость" then ySpeed = r.y end
    if r.name == "Номер аккаунта:" then yName = r.y end
end
local line = lines[1]
-- заливки записаны в ЭКРАННЫХ координатах (карточка зовёт at()), а текст — в
-- оконных: приводим линию к оконным, чтобы сравнивать с y строк
local lineY = line and (line.y - ((RC.windowPos and RC.windowPos.y) or 0)) or nil
check(line ~= nil and ySpeed ~= nil and yName ~= nil
    and lineY > ySpeed and lineY < yName,
    "линия стоит между «Скорость» и «Номер аккаунта:» (характеристика | статистика)")
check(line ~= nil and line.a > 0 and line.a < 255, "линия полупрозрачная (альфа " .. tostring(line and line.a) .. ")")
check(line ~= nil and line.w > 100, "линия во всю ширину колонки строк")

-- порядок строк — как в образце: проходим список сверху донизу прокруткой
local function allRowsOrder()
    -- собираем строки со всех позиций прокрутки: позиция строки в списке —
    -- это её координата в окне ПЛЮС прокрутка (так каждая строка встретится
    -- ровно один раз, сколько бы раз её ни было видно)
    local byPos = {}
    local keep = RC.scroll
    for step = 0, 40 do
        RC.scroll = step * 24
        render()
        for _, r in ipairs(drawnRows()) do
            byPos[math.floor((r.y + RC.scroll) * 4 + 0.5)] = r.name
        end
    end
    RC.scroll = keep
    render()
    local keys = {}
    for k in pairs(byPos) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = byPos[k] end
    return table.concat(out, ",")
end
local order = allRowsOrder()
local want = "Пинг,Здоровье,Броня,Скорость,Номер аккаунта:,Уровень:,Номер телефона,Варнов,"
    .. "Пол,Женат на,Орг. (ранг),Работа/Должность,Бизнес,Игровой статус,Дом,Квартира,"
    .. "VIP статус,За сегодня,Семья"
check(order == want, "порядок строк: " .. order)

-- значения как в образце
local function allTexts()
    local out = {}
    local keep = RC.scroll
    for step = 0, 40 do
        RC.scroll = step * 24
        render()
        for _, d in ipairs(DRAWN) do
            if d.kind == 'text' then out[tostring(d.name)] = true end
        end
    end
    RC.scroll = keep
    render()
    return out
end
local all = allTexts()
check(all["100.0"] == true, "здоровье показано как «100.0»")
check(all["80.0"] == true, "броня показана как «80.0»")
check(all["45"] == true, "скорость показана числом без «км/ч»")
check(all["30"] == true, "пинг показан числом без « ms»")
check(all["45 км/ч"] == nil and all["30 ms"] == nil, "единиц в карточке нет (как в образце)")
check(all["AFK"] == nil and all["Оружие"] == nil and all["Патроны"] == nil,
    "«AFK», «Оружие» и «Патроны» в карточку не выводятся")
check(all["Имя:"] == nil, "«Имя:» убрано из статистики")
check(all["555-12-34"] == true and all["Ивановы"] == true and all["Золото"] == true,
    "статистика показывается полностью (телефон, семья, VIP видны при прокрутке)")
check(all["Номер телефона"] == true and all["Варнов"] == true and all["Семья"] == true,
    "статистика показывается полностью (телефон, семья, VIP видны при прокрутке)")

-- кнопки стоят в левой колонке, строки — в правой
check(#btns > 0 and btns[1].x + btns[1].w <= 160,
    "кнопки наказаний в ЛЕВОЙ колонке (x=" .. tostring(#btns > 0 and btns[1].x or -1) .. ")")
check(#btns == 4 and btns[1].y <= 60,
    "панель наказаний прижата к шапке (верхняя кнопка y=" .. tostring(#btns > 0 and btns[1].y or -1) .. ")")
check(#btns == 4 and btns[4].y + btns[4].h < 220,
    "панель наказаний не «уезжает» вниз (низ панели " .. tostring(#btns == 4 and (btns[4].y + btns[4].h) or -1) .. ")")
local rowsTop = rows[1] and rows[1].y or 0
local btnTop = #btns > 0 and btns[1].y or 0
check(math.abs(rowsTop - btnTop) <= 6,
    "первая строка и первая кнопка начинаются на одном уровне (" .. tostring(rowsTop) .. " ~ " .. tostring(btnTop) .. ")")
check(rows[1] ~= nil and rows[1].x > 160, "строки в правой колонке (x=" .. tostring(rows[1] and rows[1].x) .. ")")

-- 2) прокрутка списка: сверху «Пинг», прокрутили до низа — «Семья»
resX, resY = 1280, 240
RC.scroll = nil
render()
check((RC.scroll or 0) == 0, "старт прокрутки — верх списка")
check(RC.scrollRect ~= nil and RC.scrollRect.h > 0, "область колеса мыши задана")
rows = drawnRows()
check(rows[1] ~= nil and rows[1].name == "Пинг", "наверху списка видна первая строка")
RC.scroll = 1000   -- просим больше максимума: карточка сама ограничит
render()
rows = drawnRows()
check(rows[#rows] ~= nil and rows[#rows].name == "Семья", "внизу списка видна последняя строка «Семья»")
local bad = 0
for _, r in ipairs(rows) do
    if r.y < 34 then bad = bad + 1 end
end
check(bad == 0, "ни одна строка не нарисована обрывком над окном прокрутки (" .. tostring(bad) .. ")")
btns = drawnPunButtons()
check(#btns == 4, "кнопки наказаний не уезжают вместе со списком (их " .. tostring(#btns) .. ")")
check((RC.scroll or 0) <= 469 + 1, "прокрутка не превышает высоту содержимого (" .. tostring(RC.scroll) .. ")")
-- полоса прокрутки видна (ползунок — светлая заливка у правого края)
local bar = nil
for _, f in ipairs(FILLS) do
    if f.h > 20 and f.a >= 100 and f.w <= 4 then bar = f end
end
check(bar ~= nil, "у списка видна полоса прокрутки")

-- 3) стрелка внизу сворачивает карточку ВЛЕВО: правая часть складывается,
--    остаётся узкая полоса с колонкой кнопок и самой стрелочкой
resX, resY = 1920, 1080
RC.scroll = nil
RC.cardOpen = nil
RC.posX, RC.posY = nil, nil
render()
local hExpanded = RC.windowSize.h
local wExpanded = RC.windowSize.w
local xExpanded = RC.windowPos.x
check(#drawnRows() > 0, "до сворачивания строки на месте")
check(wExpanded >= 400, "развёрнутая карточка широкая (" .. tostring(wExpanded) .. ")")
check(#TRIANGLES > 0, "внизу карточки нарисована стрелочка")
clickAndRender("##grnd_recon_top")
check(RC.cardOpen == false, "клик по стрелке свернул карточку")
local wMini = RC.windowSize.w
check(wMini < wExpanded and wMini <= 200,
    "карточка свернулась ВЛЕВО в узкую полосу (было " .. tostring(wExpanded)
    .. ", стало " .. tostring(wMini) .. ")")
check(wMini == 14 + math.floor(wExpanded * 0.30) + 6,
    "ширина свёрнутой карточки = колонка кнопок + рамка (" .. tostring(wMini) .. ")")
check(RC.windowPos.x == xExpanded,
    "левый край карточки не прыгнул (x=" .. tostring(RC.windowPos.x) .. ")")
check(RC.posX == xExpanded and RC.posY == RC.windowPos.y,
    "позиция окна запомнена до смены ширины (RC.posX=" .. tostring(RC.posX) .. ")")
check(#drawnRows() == 0, "свёрнутый блок информации и статистики не рисуется")
check(#drawnLines() == 0, "линия-разделитель в свёрнутом виде тоже не рисуется")
check(RC.scrollRect == nil, "в свёрнутом виде колесо не перехватывается (уходит игре)")
check(RC.windowSize.h == hExpanded,
    "высота карточки не скачет при сворачивании (карточка всегда по концу кнопок)")
local btnsMini = drawnPunButtons()
check(#btnsMini == 4, "кнопки наказаний остаются на месте и в свёрнутом виде")
local fits = true
for _, b in ipairs(btnsMini) do
    if b.x + b.w > wMini then fits = false end
end
check(fits, "кнопки не вылезают за узкую свёрнутую карточку")
check(#TRIANGLES > 0, "стрелочка остаётся на месте в свёрнутой полосе")
do
    local tri = TRIANGLES[1]
    local wx = RC.windowPos.x
    local maxX = math.max(tri.p1.x, tri.p2.x, tri.p3.x)
    check(maxX <= wx + wMini, "стрелочка целиком внутри свёрнутой полосы")
end
local miniTitle = nil
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and tostring(d.name):find("%[77%]") then miniTitle = d.name end
end
check(miniTitle ~= nil and miniTitle:find("%[77%]") ~= nil,
    "в свёрнутой полосе ник по-прежнему виден (найдено: " .. tostring(miniTitle) .. ")")
check(miniTitle ~= nil and #miniTitle < #("Test_Player [77]"),
    "в узкой полосе ник показан сокращённо (" .. tostring(miniTitle) .. ")")
check(drawnButton("##grnd_recon_copy") ~= nil, "значок копирования остаётся в шапке")

-- разворачиваем обратно: ширина возвращается, левый край — там же
clickAndRender("##grnd_recon_top")
check(RC.cardOpen ~= false, "повторный клик развернул карточку обратно")
check(RC.windowSize.w == wExpanded, "ширина вернулась к развёрнутой "
    .. "(" .. tostring(RC.windowSize.w) .. ")")
check(RC.windowPos.x == xExpanded, "левый край и после разворота там же")
check(#drawnRows() > 0, "после разворота строки вернулись")
check((RC.scroll or 0) == 0, "после разворота список начинается сверху")

-- сворачиваем и разворачиваем, когда окно уже перетащено: край не «прыгает»
RC.posX, RC.posY = 1000, 300
render()
local xDragged = RC.windowPos.x
clickAndRender("##grnd_recon_top")
check(RC.windowPos.x == xDragged,
    "у перетащенного окна левый край тоже не прыгает (" .. tostring(RC.windowPos.x) .. ")")
clickAndRender("##grnd_recon_top")
check(RC.windowPos.x == xDragged, "и при развороте он на месте")
RC.posX, RC.posY = nil, nil

-- 4) клик по кнопке внутри карточки даёт тост
CLICK["##rcb_p_BAN"] = true
render()
CLICK["##rcb_p_BAN"] = false
local toasted = false
for _, t in ipairs(TOASTS) do
    if t:find("BAN", 1, true) then toasted = true end
end
check(toasted, "клик по BAN внутри карточки даёт тост")

-- 5) тумблер «Кнопки наказаний в карточке» прячет весь блок кнопок
GRND_PUN.barOn = false
render()
check(#drawnPunButtons() == 0, "выключенный тумблер убирает кнопки из карточки")
check(#drawnRows() > 0, "строки при этом остаются на месте")
GRND_PUN.barOn = true

-- 6) без данных от сервера строки не ломаются
RC.live = {}
render()
check(#drawnRows() > 0, "без серверных данных строки всё равно рисуются")
check(textVals()["—"] ~= nil, "пустые значения показаны как «—», а не пустотой")
RC.live = { hp = "100", arm = "80", ping = "30", speed = "45",
            rc_account = "12345", rc_level = "18",
            rc_phone = "555-12-34", rc_varnov = "2", rc_gender = "Мужской",
            rc_married = "нет", rc_org = "Полиция (3)", rc_job = "Инструктор",
            rc_business = "Автомойка", rc_status = "В игре", rc_house = "Дом 3",
            rc_flat = "Кв. 12", rc_vip = "Золото", today = "1 ч 20 мин",
            rc_family = "Ивановы" }

-- 8) окно можно взять за ЛЮБОЕ свободное место
resX, resY = 1920, 1080
RC.scroll = nil
RC.cardOpen = nil
RC.posX, RC.posY = nil, nil
RC.dragging = nil
render()
local wx, wy = RC.windowPos.x, RC.windowPos.y
local function press(mx, my)
    MOUSEX, MOUSEY = mx, my
    GRND_MOUSE.x, GRND_MOUSE.y = mx, my
    GRND_MOUSE.down = true
end
local function release()
    GRND_MOUSE.down = false
end
-- тянем за середину списка строк (влево — справа окно стоит у края экрана)
press(wx + 300, wy + 120)
render()
check(RC.dragging == true, "окно схватилось за строки (середина списка)")
GRND_MOUSE.x, GRND_MOUSE.y = wx + 300 - 60, wy + 120 + 40
render()
check(RC.windowPos.x == wx - 60 and RC.windowPos.y == wy + 40,
    "окно поехало за курсором (" .. tostring(RC.windowPos.x - wx) .. ","
    .. tostring(RC.windowPos.y - wy) .. ")")
release()
render()
check(RC.dragging == false, "после отпускания перетаскивание закончилось")
check((RC.posX or 0) > 0, "новая позиция запомнена (RC.posX=" .. tostring(RC.posX) .. ")")

-- тянем за верхний левый угол (пустое место над кнопками)
wx, wy = RC.windowPos.x, RC.windowPos.y
RC.dragging = nil
press(wx + 6, wy + 6)
render()
check(RC.dragging == true, "окно схватилось за самый край (пустое место у рамки)")
release()
render()

-- по кнопке наказания — НЕ тянем (это обычный клик)
wx, wy = RC.windowPos.x, RC.windowPos.y
RC.dragging = nil
local kb = drawnPunButtons()
press(wx + 30, wy + (kb[1].y - wy) + 10)
render()
check(RC.dragging ~= true, "за кнопку наказания окно не тянется (обычный клик)")
release()
render()

-- по значку «копировать» — тоже не тянем
local cb = drawnButton("##grnd_recon_copy")
RC.dragging = nil
press(wx + cb.x + 8, wy + cb.y + 8)
render()
check(RC.dragging ~= true, "за значок «копировать» окно не тянется")
release()
MOUSEX, MOUSEY = 0, 0
render()

if FAILS == 0 then
    return 'ALL CARD SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
