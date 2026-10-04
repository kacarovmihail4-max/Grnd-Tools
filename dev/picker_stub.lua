-- ==== стенд полосы шаблонов («Быстрые ответы») ====
HPRINT = print
function print(...) end
TOASTS, CHAT, ANS = {}, {}, {}
notify = { add = function(text, kind, life) TOASTS[#TOASTS + 1] = tostring(text) end }

local dl = {}
function dl.AddRectFilled() end
function dl.AddRect() end
function dl.PushClipRect() return true end
function dl.PopClipRect() end

function grndStoragePath() return "/tmp/harness_qr.json" end
GRND_CONFIG = { ensure = function() return {} end, warn = function() end, setting = nil }
GRND_UIKIT = { TH = nil }   -- тема: заполняется ниже (theme() в модуле берёт её отсюда)
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
