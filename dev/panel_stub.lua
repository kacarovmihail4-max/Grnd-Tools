-- ===========================================================================
--  Стенд панели МП: подменяет только ImGui и мелочи окружения.
--  Модуль панели берётся из настоящего исходника как есть (отдельным чанком),
--  поэтому все «голые» глобальные имена внутри него видны так же, как в игре:
--  в скрипте нет глобальной im (есть только _G.GRND_IM), и обращение к ней
--  раньше давало «attempt to index a nil value (global 'im')» при наведении
--  на кнопку панели.
-- ===========================================================================
HPRINT = print                     -- настоящий print для стенда
function print(...) end            -- глушим вывод самого скрипта
OUT, ERRORS, BARE = {}, {}, {}
function say(text, kind) OUT[#OUT + 1] = tostring(text) end
function flash(text) OUT[#OUT + 1] = tostring(text) end
function logIt() end
function now() return 100 + FRAME * 0.05 end
function grndStoragePath(kind, name) return "/tmp/harness_" .. tostring(name) end
function grndUiErrLog(where, err) ERRORS[#ERRORS + 1] = tostring(where) .. ": " .. tostring(err) end
function grndTrace() end
function utfCut(s, n) return tostring(s or ""):sub(1, n) end
function cleanText(s) return tostring(s or "") end
function getScreenResolution() return 1920, 1080 end
function isKeyDown() return false end
function isMouseButtonDown() return false end
function sampSendChat() end
function sampRegisterChatCommand() end
function grndChatSend() end
function grndBinderFit(s) return tostring(s) end
function grndToUtf(s) return tostring(s) end
function grndUtf8ToCp1251(s) return tostring(s) end
function grndUtf8Len(s) return #tostring(s) end
function grndUiErrLogPath() return "/tmp/harness_err.log" end
function grndUiBlocked() return false end
function grndUiTheme() return TH end
function grndUiText() return 0, 14 end
function grndUiSwitchPaint() end
notify = { say = function() end, add = function() end }
MENU_TABS = { { id = "mppanel", name = "Панель МП" }, { id = "settings", name = "Настройки" } }
GRND_MENU_TABS = MENU_TABS
GRND_CONFIG = { ensure = function() return { layout = {} } end, warn = function() end }
M_ROW, M_GAP, BIG_ROW, MAX_MSG, MP_FIELD_MAX_W = 26, 8, 30, 4, 420
M_LBL, MAX_ROWS = 18, 3
TH = { accent = { 164, 112, 224, 255 }, accent2 = { 164, 112, 224, 255 },
       textHi = { 252, 250, 255, 255 }, text = { 234, 230, 244, 255 },
       textDim = { 198, 192, 216, 255 }, textMuted = { 172, 166, 190, 255 },
       bg = { 18, 17, 23, 255 }, line = { 255, 255, 255, 20 } }
function col32(r, g, b, a)
    a = a or 255
    return math.floor(tonumber(r) or 0) % 256 + (math.floor(tonumber(g) or 0) % 256) * 0x100
        + (math.floor(tonumber(b) or 0) % 256) * 0x10000 + (math.floor(tonumber(a) or 0) % 256) * 0x1000000
end
function rgba(r, g, b, a) return col32(r, g, b, a) end
DRAWS = { filled = 0, frames = 0, grad = 0, text = 0, lines = 0, clip = 0 }
function roundRect(dl, p1, p2, col, rounding, flags) DRAWS.filled = DRAWS.filled + 1 end
function frameRect(dl, p1, p2, col, rounding, thickness) DRAWS.frames = DRAWS.frames + 1 end
function gradRect(dl, p1, p2, c1, c2, rounding) DRAWS.grad = DRAWS.grad + 1 end
function tsizeOf(im, s) return #tostring(s or "") * 7, 14 end

FRAME, HOVER_ID, HOVERED_ID, BUTTONS = 1, nil, nil, {}
CURSOR = { x = 0, y = 0 }
MOUSE = { x = -500, y = -500, clicked = false }
GRND_UIFRAME = 1
GRND_MOUSE = { x = -500, y = -500, clicked = false }
WIN = { x = 300, y = 150, w = 640, h = 520 }
local dl = {}
function dl.AddRectFilled(...) DRAWS.filled = DRAWS.filled + 1 end
function dl.AddRect(...) DRAWS.frames = DRAWS.frames + 1 end
function dl.AddLine(...) DRAWS.lines = DRAWS.lines + 1 end
function dl.AddRectFilledMultiColor(...) DRAWS.grad = DRAWS.grad + 1 end
function dl.AddCircle(...) end
function dl.AddCircleFilled(...) end
function dl.PushClipRect(...) DRAWS.clip = DRAWS.clip + 1 return true end
function dl.PopClipRect(...) end

local im = {}   -- локальная: у модуля панели глобальной im быть не должно
function im.ImVec2(x, y) return { x = x, y = y } end
function im.ImVec4(r, g, b, a) return { x = r, y = g, z = b, w = a } end
function im.GetWindowPos() return { x = WIN.x, y = WIN.y } end
function im.GetWindowDrawList() return dl end
function im.SetCursorPos(p)
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then
        HPRINT("ПЛОХОЙ КУРСОР: " .. tostring(p))
        HPRINT(debug.traceback("", 2))
    end
    CURSOR.x, CURSOR.y = p.x, p.y
end
function im.InvisibleButton(id, size)
    HOVER_ID = id
    if type(size) ~= "table" or type(size.x) ~= "number" or type(size.y) ~= "number" then
        HPRINT("ПЛОХОЙ РАЗМЕР у '" .. tostring(id) .. "': " .. tostring(size))
    end
    local x, y, w, h = CURSOR.x, CURSOR.y, size.x, size.y
    BUTTONS[#BUTTONS + 1] = { id = tostring(id), x = x, y = y, w = w, h = h }
    local inside = MOUSE.x >= x and MOUSE.x <= x + w and MOUSE.y >= y and MOUSE.y <= y + h
    if inside then HOVERED_ID = tostring(id) end
    return inside and MOUSE.clicked or false
end
function im.IsItemHovered() return HOVERED_ID == tostring(HOVER_ID) end
function im.IsItemActive() return false end
function im.IsWindowHovered() return true end
function im.CalcTextSize(s) return { x = #tostring(s or "") * 7, y = 14 } end
function im.SetWindowFontScale() end
function im.GetIO() return { MousePos = { x = MOUSE.x, y = MOUSE.y },
    MouseClicked = { [0] = MOUSE.clicked }, MouseWheel = 0 } end
function im.SetNextItemWidth() end
function im.PushItemWidth() return true end
function im.PopItemWidth() end
function im.PushStyleColor() return true end
function im.PopStyleColor() end
function im.PushStyleVar() return true end
function im.PopStyleVar() end
function im.PushStyleVarVec2() return true end
function im.PushStyleVarFloat() return true end
function im.InputText() return false end
function im.InputTextWithHint() return false end
function im.InputTextMultiline() return false end
function im.ImBuffer(cap) return { v = "" } end
function im.GetItemRectMin() return CURSOR end
function im.GetItemRectMax() return { x = CURSOR.x + 100, y = CURSOR.y + 24 } end
im.Col = { FrameBg = 1, FrameBgHovered = 2, FrameBgActive = 3, Text = 4, Border = 5 }
im.StyleVar = { FramePadding = 11, FrameBorderSize = 12 }
im.FontSize = 14
GRND_IM = im   -- движок сам берёт обёртку отсюда (глобальной im в скрипте нет)

-- ловим «голые» глобальные имена внутри модуля панели
setmetatable(_G, { __index = function(t, k)
    if k == "im" or k == "dl" or k == "at" or k == "TH" or k == "ctx" then
        BARE[#BARE + 1] = tostring(k)
        HPRINT("ГОЛОЕ ГЛОБАЛЬНОЕ ИМЯ: " .. tostring(k))
        HPRINT(debug.traceback("", 2))
    end
    return nil
end })
