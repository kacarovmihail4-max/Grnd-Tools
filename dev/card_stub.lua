-- ==== стенд карточки рекона (v1.19.59): раскладка, прокрутка, кнопки ====
-- Грузим НАСТОЯЩИЙ кусок отрисовки карточки (строки «Пинг…Уровень» и кнопки
-- наказаний) и подменяем только ImGui: видим, какие строки и кнопки реально
-- нарисованы и какие кнопки ImGui создал (по ним и клики).
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
DRAWN = {}      -- { kind = "row"/"button"/"label", name = ..., y = ... }
BTNS = {}       -- id кнопок ImGui в кадре
CLICK = {}      -- какие кнопки «нажаты» в этом кадре
TOASTS = {}
CURSOR = { x = 0, y = 0 }
resX, resY = 1920, 1080
COND_ALWAYS = 0

local function newFrame()
    DRAWN, BTNS = {}, {}
    TOASTS = TOASTS or {}
end

-- ---- заглушки ImGui ----
local POS = { x = 0, y = 0, w = 0, h = 0 }
local dl = {}
function dl.AddRectFilled() end
function dl.AddRect() end
function dl.AddCircleFilled() end
function dl.AddCircle() end
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
function col32(r, g, b, a) return 0 end
function rgba(r, g, b, a) return 0 end
function c4(t) return 0 end
function roundRect(a, b, c, d, e, f) end
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
-- в игре id цели — локальная переменная кадра рекона
id = 77
RC = {
    show = true, cursor = true, id = 77, nick = "Test_Player",
    live = { hp = "100", arm = "80", ping = "30", speed = "45",
             rc_account = "12345", rc_level = "18" },
}
-- в игре endDepth — локальная переменная кадра ImGui (в стенде просто счётчик)
endDepth = 0
GRND_MOUSE = { x = 0, y = 0, down = false, clicked = false }

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
    -- порядок как на экране: сверху вниз
    table.sort(out, function(a, b) return a.y < b.y end)
    return out
end
function drawnPunButtons()
    local out = {}
    for _, b in ipairs(BTNS) do
        if b.id:sub(1, 8) == '##rcb_p_' then out[#out + 1] = b end
    end
    return out
end
