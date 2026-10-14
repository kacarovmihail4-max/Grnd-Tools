-- =====================================================================
-- Стенд v1.19.221: уровни админов в чекере «Админы в сети» (GRND_AO).
--
-- Уровни в «Выдаче в радиусе» берутся из списка этого чекера, поэтому
-- разбор ответа сервера на /admins должен понимать форматы разных
-- серверов. Стенд вырезает модуль GRND_AO из скрипта, кормит его
-- строками чата (grndAoOnChat) и сверяет, какой уровень попал в
-- AO.list: «Уровень: 5», «5 уровня», «5-й ур.», «lvl 5», «| 5 |»,
-- «Админ 5 ур.», «[5]» и AFK-строки (время не должно становиться
-- уровнем). Ничего не выдумываем: проверяем ровно то, что увидит
-- раздел «Выдача в радиусе».
-- =====================================================================

local results = { pass = 0, fail = 0 }
local function check(cond, label)
    if cond then
        results.pass = results.pass + 1
    else
        results.fail = results.fail + 1
        print("FAIL " .. label)
    end
end

-- ---------- вырезаем модуль GRND_AO ----------
local src = assert(io.open("grnd_adm_tools.lua")):read("*a")
local a1 = assert(src:find("GRND_AO = _G.GRND_AO or {}", 1, true))
local a2 = assert(src:find("--  МОДУЛЬ 13", a1, true))
-- отступаем к началу комментария-разделителя перед модулем 13
local block = src:sub(a1, a2 - 1)

local function loadAO()
    local env = {}
    local fn = assert(load(
        "return function()\n" .. block .. "\n    return _G.GRND_AO\nend",
        "@ao_level_test"))
    return fn()()  -- load → функция модуля → _G.GRND_AO
end

-- минимум внешнего мира: /admins уходит в sampSendChat, всё остальное
-- чекер и сам проверяет через type(...) или pcall
local sentAdmins = 0
_G.sampSendChat = function(cmd) sentAdmins = sentAdmins + 1 return true end
_G.isSampAvailable = function() return true end
_G.sampIsLocalPlayerSpawned = function() return true end
_G.grndIsTyping = function() return false end
_G.grndUiBlocked = function() return false end
local AO = assert(loadAO())

-- ---------- прогон ответа сервера ----------
-- Формат: header (заголовок), затем строки админов, затем footer (итог).
-- Уровни должны попасть в AO.list с правильными никами.
local HEADER = "Администраторы в сети:"
local FOOTER = "Всего администраторов: 9"

local function feed(lines, header, footer)
    AO.list = {}
    AO.waiting = true
    AO.hide = true     -- как у фонового чекера: строки не показываем
    AO.ours = true
    AO.gotHeader = false
    AO.gotLine = false
    AO.collect = {}
    _G.grndAoOnChat(0, header or HEADER)
    for i = 1, #lines do
        _G.grndAoOnChat(0, lines[i])
    end
    _G.grndAoOnChat(0, footer or FOOTER)
    return AO.list
end

local function lvlOf(list, nick)
    for i = 1, #list do
        if list[i].nick == nick then return list[i].lvl end
    end
    return nil
end

check(AO ~= nil and type(_G.grndAoOnChat) == "function",
    "модуль чекера загружен, grndAoOnChat есть")

-- Каждый сервер пишет по-своему — проверяем все ходовые варианты.
local CASES = {
    { line = "Andrey_Volkov [12] | Уровень: 5",        want = 5,  name = "«Уровень: 5»" },
    { line = "Andrey_Volkov [12] | Уровень 5",         want = 5,  name = "«Уровень 5»" },
    { line = "Andrey_Volkov [12] | уровень = 5",       want = 5,  name = "«уровень = 5»" },
    { line = "Andrey_Volkov [12] | 5 уровня",          want = 5,  name = "«5 уровня»" },
    { line = "Andrey_Volkov [12] | 5-й уровень",       want = 5,  name = "«5-й уровень»" },
    { line = "Andrey_Volkov [12] | Администратор 5 ур.", want = 5, name = "«Администратор 5 ур.»" },
    { line = "Andrey_Volkov [12] | Админ 5 ур.",       want = 5,  name = "«Админ 5 ур.»" },
    { line = "Andrey_Volkov [12] | lvl 5",             want = 5,  name = "«lvl 5»" },
    { line = "Andrey_Volkov [12] | 5 lvl",             want = 5,  name = "«5 lvl»" },
    { line = "Andrey_Volkov [12] | LEVEL=5",           want = 5,  name = "«LEVEL=5»" },
    { line = "Andrey_Volkov [12] | лвл 5",             want = 5,  name = "«лвл 5»" },
    { line = "Andrey_Volkov [12] | 5 лвл",             want = 5,  name = "«5 лвл»" },
    { line = "Andrey_Volkov [12] | 5 | 3 мин",         want = 5,  name = "«| 5 | 3 мин»" },
    { line = "Andrey_Volkov [12] | 5 | 12:30",         want = 5,  name = "«| 5 | 12:30»" },
    { line = "Andrey_Volkov [12] | 5 |",               want = 5,  name = "«| 5 |»" },
    { line = "Andrey_Volkov [12] [5]",                 want = 5,  name = "«[5]»" },
    { line = "Andrey_Volkov [12] Главный администратор 9", want = 9, name = "главный админ 9" },
    { line = "Andrey_Volkov [12] | Заместитель 7 ур.", want = 7,  name = "заместитель 7" },
}
for i = 1, #CASES do
    local c = CASES[i]
    local list = feed({ c.line })
    check(lvlOf(list, "Andrey_Volkov") == c.want,
        "уровень " .. c.name .. " → " .. tostring(c.want)
        .. " (получили " .. tostring(lvlOf(list, "Andrey_Volkov")) .. ")")
end

-- AFK-время уровнем быть не должно (иначе 15 минут = «15-й уровень»)
do
    local list = feed({ "Andrey_Volkov [12] | 15 мин" })
    local got = lvlOf(list, "Andrey_Volkov")
    check(got == nil, "AFK «15 мин» уровнем не стал (got " .. tostring(got) .. ")")
end
do
    local list = feed({ "Andrey_Volkov [12] | АФК 12:30" })
    local got = lvlOf(list, "Andrey_Volkov")
    check(got == nil, "AFK «12:30» уровнем не стал (got " .. tostring(got) .. ")")
end
do
    local list = feed({ "Andrey_Volkov [12] | АФК | 5", })
    check(lvlOf(list, "Andrey_Volkov") == 5,
        "«АФК | 5»: уровень всё равно найден")
end

-- Мусор уровнем не считается
do
    local list = feed({ "Andrey_Volkov [12] | Уровень: нет" })
    check(lvlOf(list, "Andrey_Volkov") == nil, "«Уровень: нет» → не уровень")
end
do
    local list = feed({ "Andrey_Volkov [12] | Уровень: 123" })
    check(lvlOf(list, "Andrey_Volkov") == nil, "уровень 123 (мусор) отброшен")
end

-- Обычный чат и болтовня админов в список не попадают
do
    local list = feed({ "Andrey_Volkov [12]: привет всем" })
    check(#list == 0, "чат игрока в список чекера не попал")
end
do
    local list = feed({ "Andrey_Volkov [12] | кинул бан 5 игрокам" })
    check(#list == 0, "болтовня админа в список не попала")
end

-- Сортировка: старший админ первым (раздел берёт первую строку как «мою»)
do
    local list = feed({
        "Nikita_Orlov [3] | Уровень: 2",
        "Andrey_Volkov [12] | Уровень: 9",
        "Igor_Smirnov [7] | Уровень: 5",
    })
    check(#list == 3, "три админа в списке")
    check(list[1] and list[1].nick == "Andrey_Volkov" and list[1].lvl == 9,
        "первым — старший админ (уровень 9): " .. tostring(list[1] and list[1].nick))
    check(list[3] and list[3].lvl == 2, "последним — младший (уровень 2)")
end

-- Уровень из строки с id в другом месте и с цветовыми кодами
do
    local list = feed({ "{FFCC66}Andrey_Volkov{FFFFFF} [12] | Администратор 4 уровня" })
    local got = lvlOf(list, "Andrey_Volkov")
    check(got == 4, "цветовые коды не мешают: «4 уровня» → " .. tostring(got))
end

-- ---------- запрос обновления из раздела ----------
do
    AO.enabled = true
    AO.nextAt = os.clock() + 60
    _G.GRND_AO = AO
    sentAdmins = 0
    AO.waiting = false
    AO.hide = false
    _G.grndAoTick()
    check(sentAdmins == 0, "без принудительного обновления /admins не шлётся")
    -- так делает раздел «Выдача в радиусе» кнопкой «Обновить»
    AO.nextAt = 0
    _G.grndAoTick()
    check(sentAdmins == 1 and AO.waiting == true,
        "после nextAt=0 чекер просит /admins: " .. tostring(sentAdmins))
end

if results.fail > 0 then
    print(("--- уровни чекера «Админы в сети»: %d passed, %d failed ---")
        :format(results.pass, results.fail))
    os.exit(1)
end
print(("--- уровни чекера «Админы в сети»: %d/%d ok ---")
    :format(results.pass, results.pass + results.fail))
