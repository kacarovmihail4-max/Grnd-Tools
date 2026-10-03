
-- ---- стенд: проверяем левый край и закрытие окна репорта ----
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
    local W, H
    function im.ImVec2(x, y) return { x = x, y = y } end
    function im.SetNextWindowPos(p, cond) POS.x, POS.y = p.x, p.y end
    function im.SetNextWindowSize(sz, cond) W, H = sz.x, sz.y end
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

-- 1. полоса открывается вровень с ЛЕВЫМ краем окна репорта
GRND_REP.winX, GRND_REP.winW = 660, 600
Q.pickOpen = true
POS.x, POS.y = nil, nil
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась")
HPRINT(("левый край окна репорта: %s | левый край полосы: %s")
    :format(tostring(GRND_REP.winX), tostring(POS.x)))
check(POS.x == GRND_REP.winX, "полоса не выровнена по левому краю окна репорта")

-- 2. окно репорта переехало (сохранённая позиция) — полоса едет за ним
GRND_REP.winX = 400
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (2)")
check(POS.x == 400, "полоса не следует за левым краем окна репорта")

-- 3. окно репорта ещё не рисовалось: считаем по его формуле (по центру)
GRND_REP.winX = nil
Q.pickOpen = true
check(_G.grndQrPickerDraw(makeCtx()) == true, "полоса не нарисовалась (3)")
check(POS.x == math.floor((1920 - 600) / 2), "фолбэк позиции полосы неверный: " .. tostring(POS.x))

-- 4. клик по шаблону в тестовом режиме: уходит в чат И окно репорта закрывается
GRND_REP.open = true
Q.pickOpen = true
Q.mode = "test"
check(Q.choose(Q.items[1]) == true, "шаблон не отправился")
check(#CHAT == 1, "в чат ушло не одно сообщение: " .. tostring(#CHAT))
check(GRND_REP.open == false, "окно репорта НЕ закрылось после отправки шаблона")
check(Q.pickOpen == false, "полоса шаблонов не закрылась")
HPRINT("тестовый режим: отправлено «" .. CHAT[1] .. "», окно репорта закрыто")

-- 5. режим «в поле ответа»: окно НЕ закрываем (там ещё правят текст)
GRND_REP.open = true
GRND_REP.answer = { v = "" }
Q.mode = "input"
Q.pickOpen = true
check(Q.choose(Q.items[2]) == true, "шаблон не вставился в поле")
check(GRND_REP.open == true, "в режиме «в поле ответа» окно репорта закрывать нельзя")
HPRINT("режим «в поле ответа»: окно репорта осталось открытым")

-- 6. режим «ans»: ответ ушёл — окно закрывается
GRND_REP.open = true
Q.mode = "ans"
Q.pickOpen = true
check(Q.choose(Q.items[1]) == true, "ответ не ушёл")
check(#ANS == 1, "grndRepAnswer не вызван")
check(GRND_REP.open == false, "после ответа игроку окно репорта не закрылось")
HPRINT("режим ответа игроку: ответ отправлен, окно репорта закрыто")

HPRINT("ALL PICKER SCENARIOS PASSED")
