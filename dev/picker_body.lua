
-- ---- стенд: левый край полосы, рост вниз рядами кнопок, закрытие окна ----
local Q = _G.GRND_QR
function setItems(n, name)
    Q.items = {}
    for i = 1, n do
        Q.items[i] = { id = i, name = (name or "Шаблон") .. " " .. i, text = "текст " .. i }
    end
    Q.nextId = n + 1
end
setItems(2, "Шаблон")
Q.mode = "test"
Q.loaded = true   -- конфиг уже прочитан: стенд подставляет шаблоны сам

local POS, TXT = {}, {}
function makeCtx()
    local im = {}
    function im.ImVec2(x, y) return { x = x, y = y } end
    function im.SetNextWindowPos(p, cond) POS.x, POS.y = p.x, p.y end
    function im.SetNextWindowSize(sz, cond) POS.w, POS.h = sz.x, sz.y end
    function im.SetNextWindowFocus() end
    function im.GetWindowPos() return { x = POS.x or 0, y = POS.y or 0 } end
    function im.GetWindowDrawList() return dl end
    function im.SetCursorPos() end
    function im.InvisibleButton() return false end
    function im.IsItemHovered() return false end
    function im.IsItemActive() return false end
    function im.SetTooltip(t) TOOLTIP = tostring(t) end
    function im.GetIO() return { MousePos = { x = -500, y = -500 }, MouseClicked = { [0] = false } } end
    function im.PushStyleColor() return true end
    function im.PopStyleColor() end
    function im.PushStyleVar() return true end
    function im.PushStyleVarVec2() return true end
    function im.PushStyleVarFloat() return true end
    function im.PopStyleVar() end
    return {
        im = im, always = 2,
        wf = function(...) return 0 end,
        begin = function(id, flags) return true end,
        uiText = function(x, y, str, col, sc)
            TXT[#TXT + 1] = { x = x, y = y, str = tostring(str), sc = sc }
        end,
        tsize = function(s) return #tostring(s) * 7, 14 end,
        drawnW = function(s, sc) return #tostring(s) * 7 * (sc or 1) end,
        roundRect = function() end, col32 = col32, rgba = function() return 0 end,
        c4 = function() return 0 end,
        pushCol = function() return true end, popCol = function() end,
        pushVarF = function() return true end, pushVarV2 = function() return true end,
        popVar = function() end,
    }
end
local dl = {}
function dl.AddRectFilled() end
function dl.AddRect() end
function dl.PushClipRect() return true end
function dl.PopClipRect() end

local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end
local RESY = 1080

-- 1. полоса открывается вровень с ЛЕВЫМ краем окна репорта и сразу ПОД его
--    нижней кромкой (окно: 660, 400, 600x260 → низ 660, полоса с 670)
GRND_REP.winX, GRND_REP.winW, GRND_REP.winY, GRND_REP.winH = 660, 600, 400, 260
Q.pickOpen = true
POS.x, POS.y = nil, nil
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась")
HPRINT(("окно репорта: x=%s низ=%s | полоса: x=%s y=%s высота=%s")
    :format(tostring(GRND_REP.winX), tostring(GRND_REP.winY + GRND_REP.winH),
        tostring(POS.x), tostring(POS.y), tostring(POS.h)))
check(POS.x == GRND_REP.winX, "полоса не выровнена по левому краю окна репорта")
check(POS.y == GRND_REP.winY + GRND_REP.winH + 10,
    "полоса не приклеена под нижнюю кромку окна репорта: " .. tostring(POS.y))
local hTwo = POS.h

-- 2. окно репорта «переехало» (сохранённая позиция) — полоса едет за ним
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = 400, 100, 300
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (2)")
check(POS.x == 400 and POS.y == 410,
    "полоса не следует за окном репорта: " .. tostring(POS.x) .. "," .. tostring(POS.y))

-- 2b. семь кнопок, как в скрине с игры: полоса НЕ разъезжается шире окна репорта,
--     лишние кнопки уходят на второй ряд (полоса растёт вниз)
setItems(7, "тест")
GRND_REP.winX, GRND_REP.winW, GRND_REP.winY, GRND_REP.winH = 120, 600, 340, 300
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (2b)")
check(POS.w <= 600, "полоса шире окна репорта: " .. tostring(POS.w))
check(POS.h > 9 * 2 + 30, "семь кнопок не перенеслись на второй ряд: " .. tostring(POS.h))
HPRINT(("7 кнопок при окне 600: ширина полосы=%s (<=600), высота=%s — второй ряд есть")
    :format(tostring(POS.w), tostring(POS.h)))

-- 2c. один шаблон: полоса обжимает кнопку, справа пустого места нет
setItems(1, "Тест")                       -- кнопка выйдет минимальной (108 px)
local function benchW(name)
    -- ровно та же формула, что в модуле: ширина подписи + 28, но не меньше 108
    return math.max(108, math.floor(#name * 7 * 0.94 + 28))
end
GRND_REP.winX, GRND_REP.winW, GRND_REP.winY, GRND_REP.winH = 660, 600, 400, 260
Q.pickOpen = true
POS.x, POS.y, POS.w, POS.h = nil, nil, nil, nil
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (2c)")
check(POS.w == benchW("Тест 1") + 20,
    "у полосы с одним шаблоном осталась лишняя ширина: " .. tostring(POS.w))
check(POS.x == GRND_REP.winX, "полоса с одним шаблоном потеряла левый край окна: " .. tostring(POS.x))
HPRINT(("один шаблон: ширина полосы %s px (кнопка %s + поля карточки), по левому краю окна")
    :format(tostring(POS.w), tostring(benchW("Тест 1"))))

-- 2d. длинное название: полоса тоже ровно по кнопке (кнопка упирается в предел 240)
setItems(1, "Очень длинное название шаблона")
Q.pickOpen = true
POS.x, POS.y, POS.w, POS.h = nil, nil, nil, nil
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (2d)")
check(POS.w == 240 + 20, "длинное название не обжато до предела: " .. tostring(POS.w))
check(POS.x == GRND_REP.winX, "полоса потеряла левый край окна (2d): " .. tostring(POS.x))
HPRINT(("одно длинное название: ширина полосы %s px (кнопка 240 + поля), пустоты справа нет")
    :format(tostring(POS.w)))
setItems(2, "Шаблон")

-- 3. много шаблонов: полоса растёт ВНИЗ новыми рядами, а не режется по окну репорта
setItems(40, "Шаблон быстрого ответа")
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = 660, 300, 400
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (3)")
check(POS.y == 710, "полоса уехала от окна репорта: " .. tostring(POS.y))
check(POS.w <= GRND_REP.winW, "полоса шире окна репорта: " .. tostring(POS.w))
check(POS.y + POS.h <= RESY - 10, "полоса не влезла в экран: " .. tostring(POS.y + POS.h))
check(POS.h > hTwo, "при большом списке полоса не выросла: " .. tostring(POS.h))
HPRINT(("40 шаблонов: y=%s высота=%s ширина=%s (низ %s при экране %s)")
    :format(tostring(POS.y), tostring(POS.h), tostring(POS.w),
        tostring(POS.y + POS.h), tostring(RESY)))

-- 3b. шаблонов столько, что не влезает даже до низа экрана: остальное — прокрутка
setItems(80, "Очень длинное название шаблона для ответа игроку номер")
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = 660, 300, 400
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (3b)")
check(POS.y == 710, "полоса уехала от окна репорта (3b): " .. tostring(POS.y))
check(POS.y + POS.h <= RESY - 10,
    "полоса ушла за нижний край экрана: " .. tostring(POS.y + POS.h))
check(POS.y + POS.h >= RESY - 60, "полоса не доросла до нижнего края экрана: "
    .. tostring(POS.y + POS.h))
HPRINT(("80 длинных шаблонов: y=%s высота=%s (низ %s — вплотную к краю экрана)")
    :format(tostring(POS.y), tostring(POS.h), tostring(POS.y + POS.h)))

-- 3c. окно репорта у нижнего края экрана: полоса всё равно остаётся в экране
setItems(12, "Шаблон")
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = 660, 600, 400
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (3c)")
check(POS.y + POS.h <= RESY - 10, "полоса ушла за нижний край экрана (3c): "
    .. tostring(POS.y + POS.h))
HPRINT(("окно у нижнего края (низ 1000): полоса y=%s высота=%s (низ %s)")
    :format(tostring(POS.y), tostring(POS.h), tostring(POS.y + POS.h)))

-- 3d. строки-подсказки под кнопками больше нет: всё, что рисуется, — это подписи
--     кнопок (масштаб 0.94); текста под кнопками (0.82) и слов «клик/ESC» нет
local below, hints = 0, 0
for i = 1, #TXT do
    if TXT[i].sc ~= nil and math.abs(TXT[i].sc - 0.82) < 0.001 then below = below + 1 end
    local t = TXT[i].str:lower()
    if t:find("клик", 1, true) or t:find("esc", 1, true) then hints = hints + 1 end
end
check(below == 0, "под кнопками всё ещё рисуется строка текста: " .. tostring(below))
check(hints == 0, "осталась подсказка «клик — отправить / ESC — закрыть»")
check(#TXT > 0, "полоса не нарисовала ни одной подписи кнопки")
HPRINT(("подписей кнопок: %s | строк-подсказок: %s | упоминаний «клик/ESC»: %s")
    :format(tostring(#TXT), tostring(below), tostring(hints)))

-- 4. окно репорта ещё не рисовалось: считаем по его формулам (центр по X, чуть ниже центра)
setItems(2, "Шаблон")
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = nil, nil, nil
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (4)")
check(POS.x == math.floor((1920 - 600) / 2), "фолбэк позиции полосы неверный: " .. tostring(POS.x))
check(POS.y > RESY / 2, "фолбэк позиции полосы по Y неверный: " .. tostring(POS.y))
HPRINT(("окно репорта ещё не рисовалось: x=%s y=%s")
    :format(tostring(POS.x), tostring(POS.y)))

-- 5. клик по шаблону в тестовом режиме: уходит в чат И окно репорта закрывается
TOOLTIP = nil
GRND_REP.open = true
Q.pickOpen = true
Q.mode = "test"
check(Q.choose(Q.items[1]) == true, "шаблон не отправился")
check(#CHAT == 1, "в чат ушло не одно сообщение: " .. tostring(#CHAT))
check(GRND_REP.open == false, "окно репорта НЕ закрылось после отправки шаблона")
check(Q.pickOpen == false, "полоса шаблонов не закрылась")
HPRINT("тестовый режим: отправлено «" .. CHAT[1] .. "», окно репорта закрыто")

-- 6. режим «в поле ответа»: окно НЕ закрываем (там ещё правят текст)
GRND_REP.open = true
GRND_REP.answer = { v = "" }
Q.mode = "input"
Q.pickOpen = true
check(Q.choose(Q.items[2]) == true, "шаблон не вставился в поле")
check(GRND_REP.open == true, "в режиме «в поле ответа» окно репорта закрывать нельзя")
HPRINT("режим «в поле ответа»: окно репорта осталось открытым")

-- 7. режим «ans»: ответ ушёл — окно закрывается
GRND_REP.open = true
Q.mode = "ans"
Q.pickOpen = true
check(Q.choose(Q.items[1]) == true, "ответ не ушёл")
check(#ANS == 1, "grndRepAnswer не вызван")
check(GRND_REP.open == false, "после ответа игроку окно репорта не закрылось")
HPRINT("режим ответа игроку: ответ отправлен, окно репорта закрыто")

HPRINT("ALL PICKER SCENARIOS PASSED")
