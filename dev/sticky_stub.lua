-- ==== стенд антизалипания клавиш и кнопок мыши ====
-- Проверяем ровно ту часть скрипта, которая решает проблему «клавиша залипла,
-- пока открыто окно»: разбор «нажатие или отпускание» и страховочный сброс
-- игровых клавиш (setGameKeyState(..., 0)) по реальной клавиатуре.
HPRINT = print
function print(...) end

NOW = 0                                   -- виртуальные часы: os.clock() в блоке
os = { clock = function() return NOW end }

DOWN = {}                                 -- что физически нажато: VK -> true
RELEASES = {}                             -- вызовы setGameKeyState: { key, state }
KEY_ERROR = false                         -- если true — setGameKeyState падает

function isKeyDown(vk) return DOWN[tonumber(vk) or -1] == true end
function setGameKeyState(key, state)
    RELEASES[#RELEASES + 1] = { key = tonumber(key), state = tonumber(state) }
    if KEY_ERROR then error("setGameKeyState: сбой") end
    return true
end

-- состояние оконного гейта скрипта (GRND_UI_MOUSE) и фокуса окна игры (GRND_CAM)
GRND_UI_MOUSE = { active = false, uiGuard = false, blockUntil = 0 }
GRND_CAM = { windowFocused = true }
