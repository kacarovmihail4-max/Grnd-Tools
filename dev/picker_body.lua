
-- ---- стенд: левый край полосы, «приклейка» под окно репорта и закрытие окна ----
local Q = _G.GRND_QR
Q.items = {
    { id = 1, name = "Первая", text = "Привет, {ник}!" },
    { id = 2, name = "Вторая", text = "Второй шаблон" },
}
Q.nextId = 3
Q.mode = "test"
Q.loaded = true   -- конфиг уже прочитан: стенд подставляет шаблоны сам

local POS = {}
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
        uiText = function() end, tsize = function(s) return #tostring(s) * 7, 14 end,
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
HPRINT(("окно репорта: x=%s низ=%s | полоса: x=%s y=%s")
    :format(tostring(GRND_REP.winX), tostring(GRND_REP.winY + GRND_REP.winH),
        tostring(POS.x), tostring(POS.y)))
check(POS.x == GRND_REP.winX, "полоса не выровнена по левому краю окна репорта")
check(POS.y == GRND_REP.winY + GRND_REP.winH + 10,
    "полоса не приклеена под нижнюю кромку окна репорта: " .. tostring(POS.y))

-- 2. окно репорта «переехало» (сохранённая позиция) — полоса едет за ним
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = 400, 100, 300
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (2)")
check(POS.x == 400 and POS.y == 410,
    "полоса не следует за окном репорта: " .. tostring(POS.x) .. "," .. tostring(POS.y))

-- 3. много шаблонов: полоса всё равно начинается под окном и влезает в экран
Q.items = {}
for i = 1, 40 do Q.items[i] = { id = i, name = "Шаблон быстрого ответа " .. i, text = "текст " .. i } end
Q.nextId = 41
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = 660, 300, 400
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (3)")
check(POS.y == 710, "полоса уехала от окна репорта при большом списке: " .. tostring(POS.y))
check(POS.y + POS.h <= RESY - 10,
    "полоса не влезла в экран: " .. tostring(POS.y + POS.h))
check(POS.h >= 9 + 30 + 18 + 9, "полоса сжалась меньше одной строки: " .. tostring(POS.h))
HPRINT(("40 шаблонов: y=%s, высота полосы=%s (низ %s при экране %s)")
    :format(tostring(POS.y), tostring(POS.h), tostring(POS.y + POS.h), tostring(RESY)))

-- 3b. окно репорта у самого низа: полоса всё равно остаётся в экране
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = 660, 600, 400
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (3b)")
check(POS.y + POS.h <= RESY - 10, "полоса ушла за нижний край экрана: "
    .. tostring(POS.y + POS.h))
check(POS.y + POS.h <= 600, "полоса накрыла окно репорта, а должна встать над ним: "
    .. tostring(POS.y + POS.h))
check(POS.y >= 16, "полоса уехала за верхний край экрана: " .. tostring(POS.y))
HPRINT(("окно у нижнего края (низ 1000): полоса y=%s высота=%s (низ %s — над окном)")
    :format(tostring(POS.y), tostring(POS.h), tostring(POS.y + POS.h)))
Q.items = {
    { id = 1, name = "Первая", text = "Привет, {ник}!" },
    { id = 2, name = "Вторая", text = "Второй шаблон" },
}
Q.nextId = 3

-- 4. окно репорта ещё не рисовалось: считаем по его формулам (центр по X, 72% по Y)
GRND_REP.winX, GRND_REP.winY, GRND_REP.winH = nil, nil, nil
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (4)")
check(POS.x == math.floor((1920 - 600) / 2), "фолбэк позиции полосы неверный: " .. tostring(POS.x))
check(POS.y > RESY / 2, "фолбэк позиции полосы по Y неверный: " .. tostring(POS.y))
HPRINT(("окно репорта ещё не рисовалось: x=%s y=%s")
    :format(tostring(POS.x), tostring(POS.y)))

-- 5. клик по шаблону в тестовом режиме: уходит в чат И окно репорта закрывается
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
