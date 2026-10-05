-- ==== стенд окна /stats (v1.19.65): ручной запрос администратора неприкосновенен ====
-- Грузим НАСТОЯЩИЙ модуль 14 (статистика игрока) и играем за игру: часы
-- виртуальные (os.clock подменён), поэтому «через 6 секунд» проверяется мгновенно.
-- Главное правило:
--   • /stats, который отправил САМ СКРИПТ (автозапрос для карточки слежки) —
--     окно сервера прячется, поля уходят в рекон;
--   • /stats, который администратор ВВЁЛ РУКАМИ — серверное окно открывается
--     как обычно (в том числе в слежке), рекон не обновляется, своих окон
--     скрипт не открывает, а его собственный автозапрос на это время молчит.
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

-- ---- виртуальные часы ----
VNOW = 1000
os.clock = function() return VNOW end
function advance(dt) VNOW = VNOW + dt end

SENT = {}          -- что ушло в чат (и от скрипта, и от администратора)
CHAT = {}
POPUPS = 0         -- сколько раз скрипт открыл СВОЁ окно статистики
HOOK_FOR_SCRIPT_SENDS = true   -- в игре samp.events.onSendChat ловит и наши отправки

-- отправка команд скриптом: в игре sampSendChat поднимает событие onSendChat
sampSendChat = function(cmd)
    SENT[#SENT + 1] = tostring(cmd)
    if HOOK_FOR_SCRIPT_SENDS and _G.grndStatsOnSendChat then
        pcall(_G.grndStatsOnSendChat, tostring(cmd))
    end
end
sampAddChatMessage = function(text) CHAT[#CHAT + 1] = tostring(text) end
sampRegisterChatCommand = function() end
grndToUtf = function(s) return tostring(s or "") end
grndIsSpawnedSafe = function() return true end
grndIsTyping = function() return false end
grndStatsPopup = function() POPUPS = POPUPS + 1 end

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

GRND_RC = { show = false, id = nil, live = {} }
GRND_SPEC = { active = false, id = nil, confirmT = nil }

-- «серверное» окно ответа на /stats
local DIALOG_TITLE = "Статистика игрока"
local DIALOG_TEXT = "Уровень: 18\nНомер аккаунта: 54\nВарнов: 2\nСтатистика игрока Test_Player[77]"

function openRecon(id)
    GRND_RC.show = true
    GRND_RC.id = id
    GRND_RC.live = {}
end
function closeRecon()
    GRND_RC.show = false
    GRND_RC.id = nil
end

-- кадр игры: модуль 14 тикает из главного цикла
function gameFrame()
    local ok, err = pcall(_G.grndStatsTick)
    if not ok then HPRINT('ОШИБКА тика: ' .. tostring(err)) end
end
-- администратор печатает /stats руками (команда уходит серверу как есть)
function userStats(cmd)
    SENT[#SENT + 1] = tostring(cmd)
    pcall(_G.grndStatsOnSendChat, tostring(cmd))
end
function serverDialog()
    return _G.grndStatsOnDialog(1, 0, DIALOG_TITLE, "Ок", "", DIALOG_TEXT)
end
function serverDialogText(text)
    return _G.grndStatsOnDialog(1, 0, DIALOG_TITLE, "Ок", "", tostring(text))
end
