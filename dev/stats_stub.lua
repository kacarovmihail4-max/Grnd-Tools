-- ==== стенд окна /stats (v1.19.64): ручной запрос администратора неприкосновенен ====
-- Грузим НАСТОЯЩИЙ модуль 14 (статистика игрока) и проверяем главное правило:
--   • /stats, который отправил САМ СКРИПТ (автозапрос для карточки слежки) —
--     окно сервера прячется, поля уходят в рекон;
--   • /stats, который администратор ВВЁЛ РУКАМИ — серверное окно открывается
--     как обычно (не прячем ни в слежке, ни вне неё), рекон не обновляется,
--     своих окон скрипт не открывает.
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

SENT = {}          -- что скрипт отправил в чат
POPUPS = 0         -- сколько раз скрипт открыл СВОЁ окно статистики
CHAT = {}

sampSendChat = function(cmd) SENT[#SENT + 1] = tostring(cmd) end
sampAddChatMessage = function(text) CHAT[#CHAT + 1] = tostring(text) end
sampRegisterChatCommand = function() end
grndToUtf = function(s) return tostring(s or "") end
-- string.lower() в Lua не трогает кириллицу — повторяем настоящий grndLowerUtf
grndLowerUtf = function(s)
    s = tostring(s or "")
    local out, i, n = {}, 1, #s
    while i <= n do
        local b = s:byte(i)
        if b < 0x80 then
            out[#out + 1] = (b >= 0x41 and b <= 0x5A) and string.char(b + 0x20) or string.char(b)
            i = i + 1
        elseif b >= 0xC2 and b <= 0xDF then
            local b2 = s:byte(i + 1) or 0
            local cp = (b % 0x20) * 0x40 + (b2 % 0x40)
            if cp >= 0x0410 and cp <= 0x042F then cp = 0x0430 + (cp - 0x0410)
            elseif cp == 0x0401 then cp = 0x0451
            elseif cp >= 0x00C0 and cp <= 0x00DE and cp ~= 0x00D7 then cp = cp + 0x20 end
            out[#out + 1] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40))
            i = i + 2
        else
            out[#out + 1] = s:sub(i, i + 2)
            i = i + 3
        end
    end
    return table.concat(out)
end
grndToAnsi = function(s) return tostring(s or "") end
grndIsSpawnedSafe = function() return true end
grndIsTyping = function() return false end
grndStatsPopup = function() POPUPS = POPUPS + 1 end

GRND_RC = { show = false, id = nil, live = {} }
GRND_SPEC = { active = false, id = nil, confirmT = nil }

-- «серверное» окно ответа на /stats
local DIALOG_TITLE = "Статистика игрока"
local DIALOG_TEXT = "Уровень: 18\nНомер аккаунта: 54\nВарнов: 2\nСтатистика игрока Test_Player[77]"

local function openRecon(id)
    GRND_RC.show = true
    GRND_RC.id = id
    GRND_RC.live = {}
end

local function scriptRequest()
    -- тик сам отправляет /stats, когда открыт рекон и есть цель
    GRND_STATS.reqAt = -999
    _G.grndStatsTick()
end

local function manualStats(id)
    -- администратор печатает /stats руками: ownSentAt давно старый
    GRND_STATS.ownSentAt = -999
    _G.grndStatsOnSendChat("/stats " .. tostring(id))
end

local function serverDialog()
    return _G.grndStatsOnDialog(1, 0, DIALOG_TITLE, "Ок", "", DIALOG_TEXT)
end
