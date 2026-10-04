
-- ---- сценарии карточки рекона ----

local function render()
    newFrame()
    CARD()
end

-- 1) обычный экран: карточка влезает целиком, прокрутки нет
resX, resY = 1920, 1080
RC.scroll = nil
render()
local rows = drawnRows()
local btns = drawnPunButtons()
check(#rows == 7, "на экране 1080p нарисованы все семь строк (нарисовано " .. tostring(#rows) .. ")")
check(#btns == 4, "кнопок наказаний ровно четыре (нарисовано " .. tostring(#btns) .. ")")
check(#btns == 4 and btns[1].id == "##rcb_p_JAIL" and btns[2].id == "##rcb_p_BAN"
    and btns[3].id == "##rcb_p_KICK" and btns[4].id == "##rcb_p_MUTE",
    "это JAIL, BAN, KICK, MUTE — как в списке настроек")
check((RC.scroll or 0) == 0, "прокрутка на большом экране стоит на нуле")

-- раскладка как в образце: две колонки — кнопки слева, строки справа
check(#btns > 0 and btns[1].x + btns[1].w <= 160,
    "кнопки наказаний стоят в ЛЕВОЙ колонке (x=" .. tostring(#btns > 0 and btns[1].x or -1) .. ")")
local firstRow = nil
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and d.name == 'Пинг' then firstRow = d end
end
check(firstRow ~= nil and firstRow.x > 160,
    "строки начинаются в правой колонке (x=" .. tostring(firstRow and firstRow.x or -1) .. ")")
-- шапка: «Ник [ID]» по центру
local title = nil
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and tostring(d.name):find("%[77%]") then title = d end
end
check(title ~= nil and title.name == "Test_Player [77]",
    "в шапке «Ник [ID]» как в образце (найдено: " .. tostring(title and title.name) .. ")")
check(title ~= nil and title.x > 100 and title.x < 300,
    "шапка по центру карточки, а не у левого края")
-- значения как в образце: ХП/броня с одним знаком, скорость и пинг без единиц
local vals = {}
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' then vals[tostring(d.name)] = true end
end
check(vals["100.0"] == true, "здоровье показано как «100.0» (в образце один знак)")
check(vals["80.0"] == true, "броня показана как «80.0»")
check(vals["45"] == true, "скорость показана числом без «км/ч»")
check(vals["30"] == true, "пинг показан числом без « ms»")
check(vals["45 км/ч"] == nil and vals["30 ms"] == nil, "единиц в карточке нет (как в образце)")
check(vals["Имя:"] == true and vals["Номер аккаунта:"] == true and vals["Уровень:"] == true,
    "подписи «Имя:», «Номер аккаунта:», «Уровень:» — с двоеточием, как в образце")
check(vals["AFK"] == nil and vals["Оружие"] == nil and vals["Патроны"] == nil,
    "«AFK», «Оружие» и «Патроны» в карточку не выводятся")

-- порядок строк — как в образце
local order = {}
for i, r in ipairs(rows) do order[i] = r.name end
check(table.concat(order, ",") == "Пинг,Здоровье,Броня,Скорость,Имя:,Номер аккаунта:,Уровень:",
    "порядок строк: " .. table.concat(order, ","))

-- 2) низкий экран: карточка не влезает — включается прокрутка списка
resX, resY = 1280, 260
RC.scroll = nil
render()
btns = drawnPunButtons()
rows = drawnRows()
check((RC.scroll or 0) == 0, "старт прокрутки — верх списка")
check(#rows < 7, "часть строк ушла в прокрутку (видно " .. tostring(#rows) .. ")")
check(#btns == 4, "кнопки наказаний слева не пропали вместе со строками (их " .. tostring(#btns) .. ")")
local bottom = RC.windowPos.y + RC.windowSize.h
check(RC.scrollRect.y + RC.scrollRect.h <= bottom + 0.5,
    "область прокрутки не вылезает за окно карточки")

-- 3) прокрутили до низа: строки появились, верхние ушли
RC.scroll = 40
render()
btns = drawnPunButtons()
rows = drawnRows()
check(#rows > 0 and rows[#rows].name == "Уровень:",
    "внизу списка видна последняя строка «Уровень:» (видимых строк " .. tostring(#rows) .. ")")
check(#rows > 0 and rows[1].name ~= "Пинг",
    "верхняя строка «Пинг» ушла за окно прокрутки")
local bad = 0
for _, r in ipairs(rows) do
    if r.y < 36 then bad = bad + 1 end
end
check(bad == 0, "ни одна строка не нарисована обрывком над окном прокрутки (" .. tostring(bad) .. ")")
check(#btns == 4, "кнопки наказаний при прокрутке остаются на месте")

-- 4) клик по кнопке внутри карточки даёт тост
resX, resY = 1920, 1080
RC.scroll = nil
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
rows = drawnRows()
check(#rows == 7, "без серверных данных строки всё равно рисуются")
local hasDash = false
local hasZero = false
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and d.name == '—' then hasDash = true end
    if d.kind == 'text' and d.name == '0.0' then hasZero = true end
end
check(hasDash, "пустые значения показаны как «—», а не пустотой")
check(hasZero or vals["100.0"] ~= nil, "числовые поля без данных не падают")

-- 7) треугольник «наверх»: после прокрутки клик возвращает список наверх
resX, resY = 1280, 260
RC.scroll = 12
render()
check((RC.scroll or 0) == 12, "прокрутка не сброшена до клика ("
    .. tostring(RC.scroll) .. ")")
CLICK["##grnd_recon_top"] = true
render()
CLICK["##grnd_recon_top"] = false
check((RC.scroll or 0) == 0, "клик по треугольнику внизу вернул список наверх")

if FAILS == 0 then
    return 'ALL CARD SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
