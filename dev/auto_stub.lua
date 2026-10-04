-- ==== стенд автопилота ответов на репорт (v1.19.21) ====
-- Грузим настоящий модуль «Быстрые ответы» (там живёт автопилот) и подменяем
-- всё внешнее: чат, очередь репорта, ответ игроку, слежку, ввод текста, время.
HPRINT = print
function print(...) end
CHAT, ANS, TOASTS, TXT, BTNS = {}, {}, {}, {}, {}
INPUTS = {}        -- позиции полей ввода ImGui (id + x/y) для проверок вёрстки
INVIS = {}         -- позиции InvisibleButton (id + x/y): селектор команд, вкладки и т.п.
-- v1.19.35: «сырой» клик мыши, как в игре (grndClickAlive + GRND_MOUSE).
-- Нужен, чтобы проверить поведение списка команд при кликах по селектору.
GRND_UIFRAME = 0
-- по умолчанию «сырого» клика нет (в старых сценариях мышь «в пустоте»);
-- сценарий с миганием селектора «взводит» клик сам (frame = GRND_UIFRAME)
GRND_MOUSE = { x = -500, y = -500, frame = -9999 }
function grndClickAlive()
    return (GRND_MOUSE.frame or -9999) - GRND_UIFRAME <= 0
       and (GRND_MOUSE.frame or -9999) >= GRND_UIFRAME - 1
end
ORDER = {}          -- порядок вызовов: ans (ответ игроку) / chat (команда)
ANSICALLS = {}      -- что уходило через grndAnsiText (UTF-8 → CP1251)
QUEUE = {}          -- очередь репорта: и ответ, и команда
TYPE = {}           -- «набор текста»: id поля -> строка (один раз)
CLICK = {}          -- какие InvisibleButton «нажаты» в этом кадре
FILES = {}          -- фальшивый config.json: путь -> тело файла
NOW = 1000          -- виртуальные часы: os.clock() внутри модуля
SERV = { spec = false, typing = false, failAns = false, failQueue = false }

os = { clock = function() return NOW end, date = os.date }

function grndStoragePath() return "/tmp/harness_auto.json" end
-- Домены конфига — ровно как в GRND_CONFIG.sources игры. Если файла тут нет,
-- open() бросает ошибку: именно так ловится забытая секция (настройки молча
-- не сохраняются).
local SOURCES = {
    grnd_settings = "settings", grnd_ui = "ui", grnd_killlist = "killlist",
    grnd_admins = "admins", grnd_binder = "binder", grnd_ring = "ring",
    grnd_char = "character", grnd_punish = "punishments", grnd_chat = "legacyFont",
    grnd_repquick = "reportTemplates", grnd_reppunish = "reportPunish",
    grnd_repauto = "reportAuto",
}
GRND_CONFIG = {
    sources = SOURCES,
    ensure = function() return {} end,
    warn = function() end,
    setting = nil,
    flush = function() return true end,
    open = function(path, mode)
        local base = tostring(path):match('([^/\\]+)%.cfg$')
        if not SOURCES[base] then
            error('Unknown configuration domain: ' .. tostring(path))
        end
        if mode and mode:sub(1, 1) == "r" then
            local body = FILES[path]
            if not body then return nil, "section not present" end
            local cursor = 1
            local closed = false
            return {
                lines = function()
                    return function()
                        if closed or cursor > #body then return nil end
                        local last = body:find("\n", cursor, true) or (#body + 1)
                        local line = body:sub(cursor, last - 1)
                        cursor = last + 1
                        -- как scalar() в игре: числовые значения — числами,
                        -- кроме name/text (там строки)
                        local k, v = line:match("^([%w_]+)=(.*)$")
                        if k and k ~= "name" and k ~= "text" and v:match("^%-?%d+%.?%d*$") then
                            local n = tonumber(v)
                            if n then line = k .. "=" .. tostring(n) end
                        end
                        return line
                    end
                end,
                close = function() closed = true; return true end,
            }
        end
        local chunks, closed = {}, false
        return {
            write = function(_, ...)
                for i = 1, select("#", ...) do chunks[#chunks + 1] = tostring(select(i, ...)) end
                return true
            end,
            close = function()
                closed = true
                FILES[path] = table.concat(chunks)
                return true
            end,
        }
    end,
}
GRND_UIKIT = { TH = nil }
SWITCHPAINT = {}
function grndUiSwitchPaint(ctx, px, py, on, hov, id, dt)
    SWITCHPAINT[#SWITCHPAINT + 1] = tostring(id)
end
function grndStorageRead() return nil end
function grndToUtf(s) return tostring(s) end
function grndLowerUtf(s) return tostring(s):lower() end
function grndRepToAnsi(s) return tostring(s) end   -- UTF-8 → CP1251 (в стенде — как есть)
function grndRepHudRemove() return true end
function grndUtf8ToCp1251(s) return tostring(s) end
-- Конвертация в CP1251: в игре она отдаёт байты CP1251, здесь просто помечаем
-- сам вызов — по нему видно, что команда ушла в правильной кодировке.
function grndAnsiText(s)
    ANSICALLS[#ANSICALLS + 1] = tostring(s)
    return tostring(s)
end
function grndChatSend(s) CHAT[#CHAT + 1] = tostring(s) ORDER[#ORDER + 1] = "chat" return true end
function sampSendChat(s) CHAT[#CHAT + 1] = tostring(s) ORDER[#ORDER + 1] = "chat" end
function getScreenResolution() return 1920, 1080 end
function grndBinderWriteCBuf(buf, cap, text) buf.v = tostring(text) return true end
function grndBinderReadCBuf(buf) return tostring(buf.v or "") end

-- ---- очередь репорта: как в игре (одна строка за тик) ----
-- В самой игре grndRepQueue принимает только строку, а grndRepAnswer сам
-- переводит текст в CP1251 и кладёт «/ans ID текст». Тут всё так же, поэтому
-- по содержимому очереди видно и текст, и порядок, и кодировку.
function grndRepQueue(cmd)
    if SERV.failQueue then error("очередь репорта недоступна") end
    if type(cmd) ~= "string" or cmd == "" then return nil end
    QUEUE[#QUEUE + 1] = cmd
    return true
end
function grndRepQueueTick()
    while #QUEUE > 0 do
        local item = table.remove(QUEUE, 1)
        if item:sub(1, 5) == "/ans " then
            ANS[#ANS + 1] = item:sub(6)
            ORDER[#ORDER + 1] = "ans"
        else
            CHAT[#CHAT + 1] = item
            ORDER[#ORDER + 1] = "chat"
        end
    end
end
function grndRepAnswer(pid, text)
    if SERV.failAns then return false end
    pid = tostring(pid or "")
    if pid:match("^%d+$") == nil then return false end
    local enc = grndAnsiText(tostring(text))      -- UTF-8 → CP1251, как в игре
    grndRepQueue("/ans " .. pid .. " " .. enc)
    return true
end

-- ---- слежка и ввод текста ----
GRND_SPEC = { active = false }
function setSpec(on)
    SERV.spec = on and true or false
    GRND_SPEC.active = SERV.spec
end
function grndCamSpectating() return SERV.spec end
function grndIsTyping() return SERV.typing end

function isKeyDown() return false end
function isMouseButtonDown() return false end
GRND_REP = { open = true, author = "Тестовый", playerId = "25", question = "дм", focused = false,
    queue = {}, queueAt = 0 }
GRND_UIKIT.TH = { accent = { 164, 112, 224, 255 }, accent2 = { 164, 112, 224, 255 },
       textHi = { 252, 250, 255, 255 }, text = { 234, 230, 244, 255 },
       textDim = { 198, 192, 216, 255 }, textMuted = { 172, 166, 190, 255 },
       bg = { 18, 17, 23, 255 }, line = { 255, 255, 255, 20 } }
TH = GRND_UIKIT.TH
function col32(r, g, b, a) return (r or 0) + (g or 0) * 256 + (b or 0) * 65536 + (a or 255) * 16777216 end
function roundRect() end
function frameRect() end
function mouse(im) return -500, -500 end
function scrollWheel(im, mx, my, x, y, w, h, val) return val end
notify = { add = function(text, kind, life) TOASTS[#TOASTS + 1] = tostring(text) end }

-- ---- контекст отрисовки раздела (как в меню: локальные координаты) ----
local dl = {}
function dl.AddRectFilled() end
function dl.AddRect() end
function dl.AddTriangleFilled() end
function dl.AddCircleFilled() end
function dl.AddLine() end
function dl.PushClipRect() return true end
function dl.PopClipRect() end

local POS = {}
local function makeCtx()
    local im = {}
    function im.ImVec2(x, y) return { x = x, y = y } end
    -- v1.19.34: запоминаем позицию курсора ImGui и позиции полей ввода —
-- тесты проверяют, что подсказка стоит НАД полем «Триггер», а не под ним.
function im.SetCursorPos(p) if type(p) == "table" then POS.cx, POS.cy = p.x, p.y end end
    function im.InvisibleButton(id, size)
        BTNS[#BTNS + 1] = tostring(id)
        INVIS[#INVIS + 1] = { id = tostring(id), x = POS.cx or 0, y = POS.cy or 0 }
        return CLICK[tostring(id)] and true or false
    end
    function im.IsItemHovered() return false end
    function im.IsItemActive() return false end
    function im.GetWindowPos() return { x = POS.wx or 0, y = POS.wy or 0 } end
    function im.GetWindowDrawList() return dl end
    function im.SetNextWindowPos(p, cond) POS.x, POS.y = p.x, p.y end
    function im.SetNextWindowSize(sz, cond) POS.w, POS.h = sz.x, sz.y end
    function im.SetNextWindowFocus() end
    function im.SetNextItemWidth() end
    function im.SetTooltip(t) TOOLTIP = tostring(t) end
    function im.InputTextMultiline(id, buf, cap, sz, x)
        if TYPE[id] then grndBinderWriteCBuf(buf, cap, TYPE[id]); TYPE[id] = nil end
        return false
    end
    function im.InputTextWithHint(id, hint, buf, cap)
        INPUTS[#INPUTS + 1] = { id = tostring(id), x = POS.cx or 0, y = POS.cy or 0 }
        if TYPE[id] then grndBinderWriteCBuf(buf, cap, TYPE[id]); TYPE[id] = nil end
        return false
    end
    function im.InputText(id, buf, cap)
        INPUTS[#INPUTS + 1] = { id = tostring(id), x = POS.cx or 0, y = POS.cy or 0 }
        if TYPE[id] then grndBinderWriteCBuf(buf, cap, TYPE[id]); TYPE[id] = nil end
        return false
    end
    function im.PushStyleColor() return true end
    function im.PopStyleColor() end
    function im.PushStyleVar() return true end
    function im.PushStyleVarVec2() return true end
    function im.PushStyleVarFloat() return true end
    function im.PopStyleVar() end
    function im.GetIO() return { MousePos = { x = -500, y = -500 }, MouseClicked = { [0] = false } } end
    im.new = { char = setmetatable({}, { __index = function() return function() return {} end end }) }
    im.Col = { FrameBg = 1, FrameBgHovered = 2, FrameBgActive = 3, Text = 4, Border = 5 }
    im.StyleVar = { FrameBorderSize = 1, FramePadding = 2 }
    return {
        im = im, dl = dl,
        at = function(x, y) return im.ImVec2((POS.wx or 0) + x, (POS.wy or 0) + y) end,
        x = 40, y = 40, w = 700, h = 420,
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
CTX = makeCtx()
