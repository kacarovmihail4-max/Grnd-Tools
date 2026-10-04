
-- ---- сценарии карточки рекона (v1.19.61) ----

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

-- 1) обычный экран: карточка влезает целиком, прокрутки нет
resX, resY = 1920, 1080
RC.scroll = nil
RC.statsOpen = nil
render()
local rows = drawnRows()
local btns = drawnPunButtons()
local vals = textVals()
check(#rows == 7, "нарисованы все семь строк (нарисовано " .. tostring(#rows) .. ")")
check(#btns == 4, "кнопок наказаний ровно четыре (нарисовано " .. tostring(#btns) .. ")")
check(#btns == 4 and btns[1].id == "##rcb_p_JAIL" and btns[2].id == "##rcb_p_BAN"
    and btns[3].id == "##rcb_p_KICK" and btns[4].id == "##rcb_p_MUTE",
    "это JAIL, BAN, KICK, MUTE — как в списке настроек")
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
local leftTopText = false
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and d.x < 160 and d.y > 34 and d.y < 120 then leftTopText = true end
end
check(not leftTopText, "в зоне 3D-модели ничего не нарисовано")

-- две группы: характеристика, полупрозрачная линия, статистика
local lines = drawnLines()
check(#lines >= 1, "есть полупрозрачная линия-разделитель (найдено " .. tostring(#lines) .. ")")
local ySpeed = nil
local yName = nil
for _, r in ipairs(rows) do
    if r.name == "Скорость" then ySpeed = r.y end
    if r.name == "Имя:" then yName = r.y end
end
local line = lines[1]
-- заливки записаны в ЭКРАННЫХ координатах (карточка зовёт at()), а текст — в
-- оконных: приводим линию к оконным, чтобы сравнивать с y строк
local lineY = line and (line.y - ((RC.windowPos and RC.windowPos.y) or 0)) or nil
check(line ~= nil and ySpeed ~= nil and yName ~= nil
    and lineY > ySpeed and lineY < yName,
    "линия стоит между «Скорость» и «Имя:» (характеристика | статистика)")
check(line ~= nil and line.a > 0 and line.a < 255, "линия полупрозрачная (альфа " .. tostring(line and line.a) .. ")")
check(line ~= nil and line.w > 100, "линия во всю ширину колонки строк")

-- порядок строк — как в образце
local order = {}
for i, r in ipairs(rows) do order[i] = r.name end
check(table.concat(order, ",") == "Пинг,Здоровье,Броня,Скорость,Имя:,Номер аккаунта:,Уровень:",
    "порядок строк: " .. table.concat(order, ","))

-- значения как в образце
check(vals["100.0"] ~= nil, "здоровье показано как «100.0»")
check(vals["80.0"] ~= nil, "броня показана как «80.0»")
check(vals["45"] ~= nil, "скорость показана числом без «км/ч»")
check(vals["30"] ~= nil, "пинг показан числом без « ms»")
check(vals["45 км/ч"] == nil and vals["30 ms"] == nil, "единиц в карточке нет (как в образце)")
check(vals["AFK"] == nil and vals["Оружие"] == nil and vals["Патроны"] == nil,
    "«AFK», «Оружие» и «Патроны» в карточку не выводятся")

-- кнопки стоят в левой колонке, строки — в правой
check(#btns > 0 and btns[1].x + btns[1].w <= 160,
    "кнопки наказаний в ЛЕВОЙ колонке (x=" .. tostring(#btns > 0 and btns[1].x or -1) .. ")")
check(rows[1] ~= nil and rows[1].x > 160, "строки в правой колонке (x=" .. tostring(rows[1] and rows[1].x) .. ")")

-- 2) низкий экран: весь блок (характеристика + статистика) прокручивается
resX, resY = 1280, 240
RC.scroll = nil
render()
local hOpen = RC.windowSize.h
check((RC.scroll or 0) == 0, "старт прокрутки — верх списка")
check(RC.scrollRect ~= nil and RC.scrollRect.h > 0, "область колеса мыши задана")
rows = drawnRows()
check(rows[1] ~= nil and rows[1].name == "Пинг", "наверху списка видна первая строка")
RC.scroll = 300
render()
rows = drawnRows()
check(rows[#rows] ~= nil and rows[#rows].name == "Уровень:", "внизу списка видна последняя строка «Уровень:»")
local bad = 0
for _, r in ipairs(rows) do
    if r.y < 34 then bad = bad + 1 end
end
check(bad == 0, "ни одна строка не нарисована обрывком над окном прокрутки (" .. tostring(bad) .. ")")
btns = drawnPunButtons()
check(#btns == 4, "кнопки наказаний не уезжают вместе со списком (их " .. tostring(#btns) .. ")")
check(RC.scroll <= math.max(0, RC.windowSize.h), "прокрутка ограничена содержимым")

-- 3) стрелка внизу сворачивает весь блок информации и статистики
resX, resY = 1920, 1080
RC.scroll = nil
RC.statsOpen = nil
render()
local hExpanded = RC.windowSize.h
check(#drawnRows() == 7, "до сворачивания строки на месте")
clickAndRender("##grnd_recon_top")
check(RC.statsOpen == false, "клик по стрелке свернул блок")
check(#drawnRows() == 0, "свёрнутый блок информации и статистики не рисуется")
check(#drawnLines() == 0, "линия-разделитель в свёрнутом виде тоже не рисуется")
check(RC.scrollRect == nil, "в свёрнутом виде колесо не перехватывается (уходит игре)")
check(RC.windowSize.h < hExpanded,
    "свёрнутая карточка ниже развёрнутой (" .. tostring(RC.windowSize.h) .. " < " .. tostring(hExpanded) .. ")")
check(#drawnPunButtons() == 4, "кнопки наказаний остаются на месте и в свёрнутом виде")
check(drawnButton("##grnd_recon_copy") ~= nil, "значок копирования остаётся в шапке")

-- разворачиваем обратно
clickAndRender("##grnd_recon_top")
check(RC.statsOpen ~= false, "повторный клик развернул блок обратно")
check(#drawnRows() == 7, "после разворота строки вернулись")
check((RC.scroll or 0) == 0, "после разворота список начинается сверху")

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
check(#drawnRows() == 7, "строки при этом остаются на месте")
GRND_PUN.barOn = true

-- 6) без данных от сервера строки не ломаются
RC.live = {}
render()
check(#drawnRows() == 7, "без серверных данных строки всё равно рисуются")
check(textVals()["—"] ~= nil, "пустые значения показаны как «—», а не пустотой")
RC.live = { hp = "100", arm = "80", ping = "30", speed = "45",
            rc_account = "12345", rc_level = "18" }

if FAILS == 0 then
    return 'ALL CARD SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
