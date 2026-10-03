-- ==== стенд шаблонов наказаний (вкладка «Репорт → Наказания» и полоса) ====
HPRINT = print
function print(...) end
CHAT, ANS, TOASTS, TXT, BTNS = {}, {}, {}, {}, {}
TYPE = {}                        -- «набор текста»: id поля -> строка (один раз)
CLICK = {}                       -- какие InvisibleButton «нажаты» в этом кадре
FILES = {}                       -- фальшивый config.json: путь -> тело файла

function grndStoragePath() return "/tmp/harness_punish.json" end
GRND_CONFIG = {
    ensure = function() return {} end,
    warn = function() end,
    setting = nil,
    flush = function() return true end,
    open = function(path, mode)
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
                        return line
                    end
                end,
                read = function(_, format)
                    local out = body:sub(cursor)
                    cursor = #body + 1
                    return out
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
function grndStorageRead() return nil end
function grndToUtf(s) return tostring(s) end
function grndUtf8ToCp1251(s) return tostring(s) end
function grndChatSend(s) CHAT[#CHAT + 1] = tostring(s) return true end
function sampSendChat(s) CHAT[#CHAT + 1] = tostring(s) end
function getScreenResolution() return 1920, 1080 end
function grndBinderWriteCBuf(buf, cap, text) buf.v = tostring(text) return true end
function grndBinderReadCBuf(buf) return tostring(buf.v or "") end
function grndRepAnswer(pid, text) ANS[#ANS + 1] = tostring(pid) .. "|" .. tostring(text) return true end
function isKeyDown() return false end
function isMouseButtonDown() return false end
GRND_REP = { open = true, author = "Тестовый", playerId = "25", question = "дм", focused = false }
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

-- окно полосы наказаний: begin/wf/always нужны её отрисовке (см. pickerDraw)
PICKER = {}
function makePickerCtx(im, dl, at)
    return {
        im = im, dl = dl, at = at,
        always = 2,
        wf = function(...) return 0 end,
        begin = function(id, flags) PICKER.win = tostring(id); return true end,
        uiText = function() end, roundRect = function() end,
        col32 = col32, rgba = function() return 0 end, c4 = function() return 0 end,
        gradRect = function() end, drawnW = function(s, sc) return #tostring(s) * 7 * (sc or 1) end,
        pushCol = function() return true end, popCol = function() end,
        pushVarF = function() return true end, pushVarV2 = function() return true end,
        popVar = function() end,
    }
end
