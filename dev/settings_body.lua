
-- ---- стенд: редактор шаблона без нижних строк («Переменные» и заметки) ----
local Q = _G.GRND_QR
Q.items = {
    { id = 1, name = "Первая", text = "Привет, {ник}!" },
    { id = 2, name = "Вторая", text = "Второй шаблон" },
}
Q.nextId = 3
Q.mode = "test"
Q.loaded = true

local dl = {}
function dl.AddRectFilled() end
function dl.AddRect() end
function dl.AddTriangleFilled() end
function dl.PushClipRect() return true end
function dl.PopClipRect() end

local function makeCtx()
    local im = {}
    function im.ImVec2(x, y) return { x = x, y = y } end
    function im.SetCursorPos() end
    function im.InvisibleButton(id, size)
        BTNS[#BTNS + 1] = tostring(id)
        return CLICK[tostring(id)] and true or false
    end
    function im.IsItemHovered() return false end
    function im.IsItemActive() return false end
    function im.GetWindowPos() return { x = 0, y = 0 } end
    function im.GetWindowDrawList() return dl end
    function im.SetNextWindowPos() end
    function im.SetNextWindowSize() end
    function im.SetNextWindowFocus() end
    function im.SetNextItemWidth() end
    function im.SetTooltip(t) TOOLTIP = tostring(t) end
    function im.InputTextMultiline(...) return false end
    function im.InputTextWithHint(id, hint, buf, cap) return false end
    function im.InputText(id, buf, cap) return false end
    function im.PushStyleColor() return true end
    function im.PopStyleColor() end
    function im.PushStyleVar() return true end
    function im.PushStyleVarVec2() return true end
    function im.PushStyleVarFloat() return true end
    function im.PopStyleVar() end
    function im.GetIO() return { MousePos = { x = -500, y = -500 }, MouseClicked = { [0] = false } } end
    im.new = { char = setmetatable({}, { __index = function() return function() return {} end end }) }
    im.Col = { FrameBg = 1, FrameBgHovered = 2, FrameBgActive = 3, Text = 4, Border = 5 }
    im.StyleVar = { FrameBorderSize = 1, FramePadding = 2, WindowPadding = 3, WindowRounding = 4 }
    return {
        im = im, dl = dl,
        at = function(x, y) return im.ImVec2(x, y) end,
        x = 40, y = 40, w = 860, h = 470,
        uiText = function(x, y, str, col, sc)
            TXT[#TXT + 1] = { x = x, y = y, str = tostring(str), sc = sc }
        end,
        roundRect = function() end, col32 = col32, rgba = function() return 0 end,
        c4 = function() return 0 end, gradRect = function() end,
        tsize = function(s) return #tostring(s) * 7, 14 end,
        drawnW = function(s, sc) return #tostring(s) * 7 * (sc or 1) end,
        menuToggle = function() return false end,
        pushCol = function() return true end, popCol = function() end,
        pushVarF = function() return true end, pushVarV2 = function() return true end,
        popVar = function() end,
    }
end

local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end
local function draw()
    TXT, BTNS = {}, {}
    CLICK = CLICK or {}
    local ok = _G.grndQrSettingsDraw(makeCtx())
    check(ok == true, "окно шаблонов не нарисовалось")
    return TXT
end
local function texts()
    local out = {}
    for i = 1, #TXT do out[#out + 1] = TXT[i].str end
    return table.concat(out, " | ")
end

-- 1. шаблон выбран: в редакторе НЕТ строки «Переменные» и НЕТ мелких заметок
CLICK = {}
Q.selId, Q.isNew = 1, false
draw()
check(not texts():find("Переменные", 1, true), "осталась строка «Переменные»: " .. texts())
check(not texts():find("Нажмите", 1, true), "в окне есть строка-подсказка про удаление")
-- между полем «Текст ответа» и кнопками в редакторе не должно быть НИ ОДНОЙ
-- строки: именно там жили «Переменные» и заметка при нажатии «Удалить»
local ctxW, ctxX, ctxY, ctxH = 860, 40, 40, 470
local gap = 14
local listW = math.floor((ctxW - gap) * 0.36)
if listW < 200 then listW = 200 end
if listW > 300 then listW = 300 end
local editorX = ctxX + listW + gap
-- полоса от старого низа поля текста (footH=40) до ряда кнопок: здесь жили
-- «Переменные» (433) и заметка при нажатии «Удалить» (449). Кнопки начинаются
-- ниже (подписи ~481), поэтому они под проверку не попадают.
local bandTop = (ctxY + ctxH) - 120
local bandBottom = (ctxY + ctxH) - 40
local footer = {}
for i = 1, #TXT do
    local t = TXT[i]
    if t.x >= editorX and t.y >= bandTop and t.y <= bandBottom then
        footer[#footer + 1] = ("%.0f:«%s»"):format(t.y, t.str)
    end
end
check(#footer == 0, "в редакторе остались нижние строки: " .. table.concat(footer, " | "))
HPRINT("выбран шаблон: между полем текста и кнопками — ни одной строки (было «Переменные» и заметки)")
HPRINT("  что рисуется в редакторе: " .. texts())

-- 2. нажали «Удалить»: кнопка сама становится «Точно удалить?», строки в окне нет
CLICK["##grnd_qr_remove"] = true
Q.delArm = nil
draw()
check(Q.delArm == 1, "первое нажатие «Удалить» не взвело подтверждение")
check(not texts():find("Нажмите", 1, true), "появилась строка-подсказка про удаление")
check(texts():find("Удалить", 1, true) ~= nil, "подписи кнопки удаления нет вовсе")
check(texts():find("Удалить", 1, true) ~= nil, "подписи кнопки удаления нет вовсе")
HPRINT("нажали «Удалить»: подтверждение взведено, лишней строки в окне нет")

-- 3. второе нажатие: шаблон удалён, сообщение — тостом, а не строкой в окне
CLICK["##grnd_qr_remove"] = true
draw()
check(#Q.items == 1, "шаблон не удалился: " .. tostring(#Q.items))
check(#TOASTS >= 1 and TOASTS[#TOASTS]:find("удалён", 1, true) ~= nil,
    "удаление не сообщено тостом")
check(not texts():find("Нажмите", 1, true), "после удаления осталась строка-подсказка в окне")
local armed = 0
for i = 1, #TXT do
    if TXT[i].str == "Точно удалить?" then armed = armed + 1 end
end
check(armed <= 1, "подпись подтверждения задвоилась: " .. tostring(armed))
HPRINT("второе нажатие: шаблон удалён, сообщение тостом — «" .. TOASTS[#TOASTS] .. "»")

-- 4. «+ Новый шаблон»: редактор открыт, строки в окне нет
CLICK = { ["##grnd_qr_new"] = true }
draw()
CLICK = {}
check(Q.isNew == true, "«+ Новый шаблон» не открыл редактор")
draw()
check(texts():find("Новый шаблон", 1, true) ~= nil, "редактор нового шаблона не отрисовался")
check(not texts():find("Переменные", 1, true), "в новом шаблоне есть строка «Переменные»")
HPRINT("«+ Новый шаблон»: редактор открылся, лишних строк нет")

-- 5. поле «Текст ответа» стало выше: место нижних строк отдано ему
Q.items = {
    { id = 1, name = "Первая", text = "Привет, {ник}!" },
    { id = 2, name = "Вторая", text = "Второй шаблон" },
}
Q.nextId = 3
Q.selId, Q.isNew, Q.delArm, Q.formKey = 1, false, nil, nil
local ctx = makeCtx()
local hField = 0
ctx.im.InputTextMultiline = function(id, buf, cap, sz, x)
    if sz and sz.y and sz.y > hField then hField = sz.y end
    return false
end
check(_G.grndQrSettingsDraw(ctx) == true, "окно не нарисовалось при замере поля")
check(hField > 240, "поле «Текст ответа» не выросло: " .. tostring(hField))
HPRINT(("поле «Текст ответа»: высота %s px (место нижних строк отдано ему)")
    :format(tostring(hField)))

HPRINT("ALL SETTINGS SCENARIOS PASSED")
