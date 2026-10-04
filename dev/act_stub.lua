
-- ============================================================================
--  СТЕНД КОМПАКТНОЙ ПАНЕЛИ ДЕЙСТВИЙ (r69 / v1.19.69)
--  ---------------------------------------------------------------------------
--  Проверяем НАСТОЯЩИЙ код панели (вырезан из скрипта харнессом) вместе с
--  настоящими хелперами значков и раскладки. ImGui, рисование, мышь, чат и
--  «сервер» — заглушки: без игры видно, что панель рисуется, нажимается,
--  перетаскивается и закрывается там, где должна.
-- ============================================================================

FAILS, TOT = 0, 0
function check(c, m)
    TOT = TOT + 1
    if c then print('ок: ' .. m)
    else FAILS = FAILS + 1; print('ПРОВАЛ: ' .. m) end
end

-- управляемые часы: панель сверяет время открытия (защита от «клик открыл —
-- тот же клик закрыл»), поэтому время в стенде должно быть подконтрольным
CLOCK = { now = 100.0 }
os = { clock = function() return CLOCK.now end }

-- ------------------------------ состояние -----------------------------------
resX, resY = 1920, 1080
menu = { open = false, anim = 0 }
endDepth = 0
TH = { accent = { 60, 160, 255 }, text = 't', textHi = 'th', textMuted = 'tm' }
GRND_SPEC = { id = 77, nick = 'Nick' }
GRND_MOUSE = { x = -500, y = -500, down = false, clicked = false, clickedBtn = nil }
RC = {}
GRND_PUN = { actions = ACTIONS_LIST }
PENDING_CLICK, SCRIPT = false, { clickId = nil, activeId = nil, subApply = false }
ERRS, TEXTS, HANDLED, SUBP, FLAGS, BUTTONS = {}, {}, {}, {}, {}, {}
ROUNDRECTS = 0

DRAWS = { AddLine = 0, AddRectFilled = 0, AddRect = 0, AddTriangleFilled = 0,
          AddCircle = 0, AddCircleFilled = 0 }
DL = {}
for k in pairs(DRAWS) do
    DL[k] = function() DRAWS[k] = DRAWS[k] + 1 end
end

RECTS = {}
function roundRect(dl, p1, p2, c, r)
    ROUNDRECTS = ROUNDRECTS + 1
    RECTS[#RECTS + 1] = { p1 = p1, p2 = p2, c = c, r = r }
end
function uiText(x, y, t, col, sc) TEXTS[#TEXTS + 1] = { x = x, y = y, t = tostring(t) } end
function drawnWb(t, sc) return #tostring(t) * 6 * (sc or 1) end
function c4(v) return v end
function col32(...) return { ... } end
function rgba(...) return { ... } end
function logRenderErr(a, b) ERRS[#ERRS + 1] = tostring(a) .. ': ' .. tostring(b) end
notify = { add = function() end }

-- ------------------------------- ImGui --------------------------------------
WIN = { x = 0, y = 0, w = 0, h = 0 }
local cur = { x = 0, y = 0 }
BTN_LAST, HOVERED, FOCUSED = nil, {}, false
im = {}
im.ImVec2 = function(x, y) return { x = x or 0, y = y or 0 } end
im.StyleVar = { WindowPadding = 1, WindowRounding = 2 }
im.Col = { WindowBg = 3, Border = 4 }
COND_ALWAYS = 0
function wf(...) FLAGS[#FLAGS + 1] = 'wf'; return 0 end
function wflag(n) FLAGS[#FLAGS + 1] = tostring(n); return 0 end
function grndBegin(id, flags) BEGIN_ID = id; return true end
function grndPushStyleV2() return true end
function grndPushStyleF() return true end
function grndPushCol() return true end
function grndPopCol(n) POPPED_COL = n end
function grndPopStyle(n) POPPED_STY = n end
function im.SetNextWindowPos(p) WIN.x, WIN.y = p.x, p.y end
function im.SetNextWindowSize(s) WIN.w, WIN.h = s.x, s.y end
function im.SetNextWindowFocus() FOCUSED = true end
function im.SetWindowFocus() end
function im.BringWindowToDisplayFront() end
function im.GetCurrentWindow() return { id = 'win' } end
function im.GetWindowPos() return { x = WIN.x, y = WIN.y } end
function im.GetWindowDrawList() return DL end
function im.SetCursorPos(p) cur = { x = p.x, y = p.y } end
function im.InvisibleButton(id, sz)
    local r = { id = id, x = WIN.x + cur.x, y = WIN.y + cur.y, w = sz.x, h = sz.y }
    r.lx, r.ly = cur.x, cur.y
    BUTTONS[#BUTTONS + 1] = r
    BTN_LAST = r
    local mx, my = GRND_MOUSE.x, GRND_MOUSE.y
    local hov = mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
    HOVERED[id] = hov
    if SCRIPT.clickId == id and hov then return true end
    return false
end
function im.IsItemHovered() return BTN_LAST and HOVERED[BTN_LAST.id] or false end
function im.IsItemActive() return BTN_LAST and SCRIPT.activeId == BTN_LAST.id or false end

function grndLeftClickPending() return PENDING_CLICK == true end
-- Диспетчер действий НЕ подделываем: в стенд врезается настоящий
-- _G.grndHandleActionBtn из скрипта (см. act_harness.py). Здесь только
-- «сервер» и «чат», которые он дёргает.
CHAT, NOTIF, STATS_REQ, STATS_POP = {}, {}, {}, {}
function sampSendChat(cmd) CHAT[#CHAT + 1] = tostring(cmd) end
function grndChatSend(txt) CHAT[#CHAT + 1] = tostring(txt) end
function grndUtf8Text(t) return tostring(t or '') end
function wait(ms) WAITED = (WAITED or 0) + (tonumber(ms) or 0) end
lua_thread = { create = function(fn) fn() end }
notify = { add = function(t, kind, sec) NOTIF[#NOTIF + 1] = tostring(t) end }
_G.grndSpecNative = { getVehicleId = function() return 123 end }
_G.grndStatsRequest = function(id, how) STATS_REQ[#STATS_REQ + 1] = tostring(id) .. '/' .. tostring(how) end
_G.grndStatsPopup = function(id, nick) STATS_POP[#STATS_POP + 1] = tostring(id) .. '/' .. tostring(nick) end

-- Настоящая отрисовка подпанелей врезается из скрипта (act_harness.py),
-- поэтому здесь только её «окружение»: ширина текста и загрузка SAMP.
function grndTextW(t, sc) return #tostring(t) * 6 * (sc or 1) end
function isSampLoaded() return true end

-- найденная на экране кнопка по части id
function findBtn(needle)
    for _, b in ipairs(BUTTONS) do
        if tostring(b.id):find(needle, 1, true) then return b end
    end
    return nil
end
function countBtns(needle)
    local n = 0
    for _, b in ipairs(BUTTONS) do
        if tostring(b.id):find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- кадр: чистим счётчики и рисуем панель
function frame()
    ERRS, TEXTS, HANDLED, SUBP, FLAGS, BUTTONS = {}, {}, {}, {}, {}, {}
    CHAT, NOTIF, STATS_REQ, STATS_POP = {}, {}, {}, {}
    ROUNDRECTS = 0
    RECTS = {}
    BTN_LAST = nil
    for k in pairs(DRAWS) do DRAWS[k] = 0 end
    local ok, err = pcall(runPanelFn)
    if not ok then
        -- молчаливых падений кадра быть не должно: любая ошибка — провал стенда
        FAILS, TOT = FAILS + 1, TOT + 1
        print('ПРОВАЛ: кадр панели упал: ' .. tostring(err))
    end
    return ok, err
end
