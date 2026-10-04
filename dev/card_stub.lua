-- ==== стенд карточки рекона (v1.19.61): раскладка, группы, скролл, сворачивание ====
-- Грузим НАСТОЯЩИЙ кусок отрисовки карточки и подменяем только ImGui: видим,
-- какие строки и кнопки реально нарисованы, какие прямоугольники залиты (по ним
-- проверяем полупрозрачную линию и полосу прокрутки) и какие кнопки ImGui создал.
HPRINT = print
function print(...) end
FAILS = 0
function check(cond, msg)
    if cond then
        HPRINT('ок: ' .. msg)
    else
        FAILS = FAILS + 1
        HPRINT('ПРОВАЛ: ' .. msg)
    end
end

-- ---- что «нарисовано» в этом кадре ----
DRAWN = {}      -- текст: { name, x, y }
FILLS = {}      -- заливки: { x, y, w, h, r, g, b, a }
CIRCLES = {}    -- круги (в карточке v1.19.61 их быть не должно)
BTNS = {}       -- кнопки ImGui в кадре: { id, x, y, w, h }
CLICK = {}      -- какие кнопки «нажаты» в этом кадре
TOASTS = {}
CURSOR = { x = 0, y = 0 }
resX, resY = 1920, 1080
COND_ALWAYS = 0

local function newFrame()
    DRAWN, FILLS, CIRCLES, BTNS = {}, {}, {}, {}
end

-- ---- заглушки ImGui ----
local POS = { x = 0, y = 0, w = 0, h = 0 }
local dl = {}
function dl.AddRectFilled(x1, y1, x2, y2, c, r) FILLS[#FILLS + 1] = { } end
function dl.AddRect() end
function dl.AddCircleFilled() CIRCLES[#CIRCLES + 1] = true end
function dl.AddCircle() CIRCLES[#CIRCLES + 1] = true end
function dl.AddLine() end
function dl.AddTriangleFilled() end
function dl.PushClipRect() return true end
function dl.PopClipRect() end

im = {}
function im.ImVec2(x, y) return { x = x, y = y } end
function im.SetCursorPos(p) CURSOR.x, CURSOR.y = p.x, p.y end
function im.InvisibleButton(id, size)
    BTNS[#BTNS + 1] = { id = tostring(id), x = CURSOR.x, y = CURSOR.y,
                        w = size.x, h = size.y }
    return CLICK[tostring(id)] and true or false
end
function im.IsItemHovered() return false end
function im.IsItemActive() return false end
function im.GetWindowPos() return { x = POS.x, y = POS.y } end
function im.GetWindowDrawList() return dl end
function im.SetNextWindowPos(p, c) POS.x, POS.y = p.x, p.y end
function im.SetNextWindowSize(s, c) POS.w, POS.h = s.x, s.y end
function im.SetNextWindowFocus() end
function im.SetWindowFontScale() end
function im.CalcTextSize(s) return { x = #tostring(s) * 7, y = 14 } end
function im.Begin() return true end
function im.End() end
function im.TextUnformatted() end
function im.Text() end

function grndBegin(name, flags) return true end
function grndPushStyleV2() return true end
function grndPushStyleF() return true end
function grndPushCol() return true end
function grndPopCol() end
function grndPopStyle() end
function wf(...) return 0 end
function wflag(name) return 0 end
function iflag() return 0 end

-- ---- тема и рисование ----
TH = {
    text = { 198, 205, 219, 255 }, textHi = { 233, 237, 246, 255 },
    textMuted = { 140, 149, 168, 255 }, textDim = { 110, 118, 134, 255 },
    accent = { 0, 214, 170, 255 }, accent2 = { 90, 160, 255, 255 },
}
function col32(r, g, b, a)
    return { r = r, g = g, b = b, a = a, [1] = r, [2] = g, [3] = b, [4] = a }
end
function rgba(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function c4(t) return 0 end
-- в карточке заливка идёт как roundRect(drawList, p1, p2, color, radius)
function roundRect(dll, p1, p2, col, rad)
    local cc = (type(col) == 'table') and col or {}
    FILLS[#FILLS + 1] = { x = p1.x, y = p1.y, w = p2.x - p1.x, h = p2.y - p1.y,
                          r = cc[1] or 0, g = cc[2] or 0, b = cc[3] or 0,
                          a = cc[4] or 0 }
end
function uiText(x, y, s, col, scale)
    DRAWN[#DRAWN + 1] = { kind = 'text', name = tostring(s), x = x, y = y }
end
function grndTextW(s) return #tostring(s) * 7 end
function grndUtf8Len(s) return #tostring(s) end
function reconUtf(s) return tostring(s or '') end
function reconCopyNickname(s) return true end
function grndMouseInside(r) return false end
function grndCamCfgSave() end

-- ---- игровые данные цели ----
function getPlayerPing(id) return 30 end
function getPlayerHealth(id) return 100 end
function getPlayerArmor(id) return 80 end
function grndParamNum(id, key, raw) return tonumber(raw) end
function grndParamStr(id, key, raw) return tostring(raw or '') end
function grndParamScale(v) local n = tonumber(v) or 100 if n < 100 then return 100 end return n end
function grndSpeedDisplay(id, raw, bare)
    if bare then return "45" end
    return "45 км/ч"
end
function grndParamLabel(id, key, raw) return tostring(raw or '') end

notify = { add = function(text, kind, sec) TOASTS[#TOASTS + 1] = tostring(text) end }

-- ---- состояние рекона (обычно его держит игра) ----
endDepth = 0
GRND_MOUSE = { x = 0, y = 0, down = false, clicked = false }
-- в игре id цели — локальная переменная кадра рекона
id = 77
RC = {
    show = true, cursor = true, id = 77, nick = "Test_Player",
    live = { hp = "100", arm = "80", ping = "30", speed = "45",
             rc_account = "12345", rc_level = "18" },
}
GRND_PUN = {
    loaded = true, barOn = true,
    list = { { id = "JAIL" }, { id = "BAN" }, { id = "KICK" },
             { id = "MUTE" }, { id = "WARN" }, { id = "SKICK" }, { id = "SBAN" } },
}
function GRND_PUN.load() end

-- ---- удобные разборы кадра ----
local ROW_LABELS = {
    ["Пинг"] = true, ["Здоровье"] = true, ["Броня"] = true, ["Скорость"] = true,
    ["Имя:"] = true, ["Номер аккаунта:"] = true, ["Уровень:"] = true,
}
function drawnRows()
    local out = {}
    for _, d in ipairs(DRAWN) do
        if d.kind == 'text' and ROW_LABELS[d.name] then
            out[#out + 1] = { name = d.name, y = d.y, x = d.x }
        end
    end
    table.sort(out, function(a, b) return a.y < b.y end)
    return out
end
function drawnText(name)
    for _, d in ipairs(DRAWN) do
        if d.kind == 'text' and d.name == name then return d end
    end
    return nil
end
function drawnPunButtons()
    local out = {}
    for _, b in ipairs(BTNS) do
        if b.id:sub(1, 8) == '##rcb_p_' then out[#out + 1] = b end
    end
    return out
end
function drawnButton(id)
    for _, b in ipairs(BTNS) do
        if b.id == id then return b end
    end
    return nil
end
-- полупрозрачные линии (разделитель блоков): высота 1 px и альфа < 255
function drawnLines()
    local out = {}
    for _, f in ipairs(FILLS) do
        if f.h == 1 and f.a > 0 and f.a < 255 then out[#out + 1] = f end
    end
    return out
end
