
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
check(RC.scrollRect ~= nil and RC.scrollRect.h > 0, "область колеса мыши задана")

-- порядок строк — как в образце
local order = {}
for i, r in ipairs(rows) do order[i] = r.name end
check(table.concat(order, ",") == "Пинг,Здоровье,Броня,Скорость,Имя,Номер аккаунта,Уровень",
    "порядок строк: " .. table.concat(order, ","))

-- 2) маленькое окно игры: карточка не влезает — включается прокрутка
resX, resY = 1280, 420
RC.scroll = nil
render()
btns = drawnPunButtons()
check((RC.scroll or 0) == 0, "старт прокрутки — верх списка")
check(#btns < 4, "нижние кнопки за окном не рисуются (нарисовано " .. tostring(#btns) .. ")")
local bottom = RC.windowPos.y + RC.windowSize.h
check(RC.scrollRect.y + RC.scrollRect.h <= bottom + 0.5,
    "область прокрутки не вылезает за окно карточки")

-- 3) прокрутили до низа: кнопки появились, верхние строки ушли
RC.scroll = 400
render()
btns = drawnPunButtons()
rows = drawnRows()
check(#btns == 4, "после прокрутки до низа видны все четыре кнопки (" .. tostring(#btns) .. ")")
check(#rows < 7, "верхние строки ушли за окно прокрутки (видно " .. tostring(#rows) .. ")")
local bad = 0
for _, r in ipairs(rows) do
    if r.y < 74 then bad = bad + 1 end
end
check(bad == 0, "ни одна строка не нарисована обрывком над окном прокрутки (" .. tostring(bad) .. ")")

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
for _, d in ipairs(DRAWN) do
    if d.kind == 'text' and d.name == '—' then hasDash = true end
end
check(hasDash, "пустые значения показаны как «—», а не пустотой")

if FAILS == 0 then
    return 'ALL CARD SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
