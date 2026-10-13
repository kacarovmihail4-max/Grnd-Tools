-- =====================================================================
-- Стенд v1.19.221: раздел «ВЫДАЧА В РАДИУСЕ» (GRND_RT).
--
-- Загружает блок do...end между якорями GRND_RADTOOLS_* как функцию
-- (то же, что для автопилота): игровые функции и конфиг — аргументы,
-- _G.GRND_QR / _G.PLAYER_PED / _G.GRND_AO — глобальные стабы. Гоняем:
--   * чистую логику RT.fn (дистанция, скан: сортировка/граница/интерьер,
--     заполнение шаблона {id}/{ник}/{дист}, % без поломок);
--   * живой скан по стабам MoonLoader (включая игрока вне стрима);
--   * радиус: смена ±, клип 1..200, сохранение/загрузка конфига;
--   * команды v1.19.220: /spawn, /freeze, /unfreeze, /gun, /setskin,
--     /hpall, /arm, /spcars — точный текст команды;
--   * уровень из списка чекера «Админы в сети» (GRND_AO.list): «нужен
--     N-й уровень» = N и ВЫШЕ, ниже — тост «Нет доступа к данной
--     команде, нужен N-й уровень»; себя ищем по ID, затем по нику,
--     затем берём первую строку списка, и помним уровень сессии;
--     уровень не определён — тост про чекер и перезапрос /admins;
--   * очередь выдачи: по одной команде за 150 мс (RT.tick);
--   * настройки шестерёнок (панель вместо сетки): оружие (ползунок по
--     именам + патроны), скин (поле ввода), броня (1..100), транспорт
--     (3 кнопки) + сохранение в конфиг;
--   * страницу RT.page на стаб-рендерере (кнопки, шестерёнки, радиус,
--     статус, «−»/«+» по клику, «Было: …», y растёт);
--   * стиль ползунка grndUiSlider: полустеклянная дорожка + светлая
--     «пилюля», зелёного нет (v1.19.218/220).
-- =====================================================================

local results = { pass = 0, fail = 0 }
local function check(cond, label)
    if cond then
        results.pass = results.pass + 1
    else
        results.fail = results.fail + 1
        print("FAIL " .. label) -- формат run_all.lua ищет именно "FAIL "
    end
end

-- ---------- загрузка модуля ----------
local src = assert(io.open("grnd_adm_tools.lua")):read("*a")
local a1 = assert(src:find("-- >>> GRND_RADTOOLS_BEGIN"))
local a2 = assert(src:find("-- <<< GRND_RADTOOLS_END"))
local block = src:sub(a1, a2 - 1) -- до первой «-» маркера END
local WRAP_ARGS = [[
QR_PATH, GRND_CONFIG, ffi,
sampIsPlayerConnected, sampGetCharHandleBySampPlayerId,
sampGetPlayerIdByCharHandle, sampGetPlayerNickname,
getCharCoordinates, getActiveInterior, sampGetStreamedOutPlayerPos
]]
local function mkModule()
    local fn = assert(load("return function(" .. WRAP_ARGS .. ")\n"
        .. block .. "\n    return _G.GRND_RT\nend", "@radtools_test"))()
    return fn
end

-- ---------- общие перехватчики ----------
local sent, toasts = {}, {}
local qr = {
    path = function() return "/cfg/grnd.cfg" end,
    sendChat = function(t) table.insert(sent, t) return true end,
    toast = function(t, k) table.insert(toasts, { text = t, kind = k }) end,
}
_G.GRND_QR = qr
_G.PLAYER_PED = "PED"

local cfgfile = {}
local function resetCfg(content)
    cfgfile = { content = content, reads = 0, writes = 0 }
end
local function fakeOpen(path, mode)
    if mode == "w" then
        cfgfile.writes = cfgfile.writes + 1
        return {
            write = function(_, s)
                cfgfile.content = (cfgfile.content or "") .. s
            end,
            close = function() end,
        }
    end
    cfgfile.reads = cfgfile.reads + 1
    local lines = {}
    for line in (cfgfile.content or ""):gmatch("[^\n]+") do
        lines[#lines + 1] = line
    end
    return {
        lines = function()
            local i = 0
            return function() i = i + 1 return lines[i] end
        end,
        close = function() end,
    }
end

-- id 1 — «я», 2/3 — рядом, 4 — вне стрима, 7 — рядом (10 м).
-- ВАЖНО: возвращаем МАССИВ в порядке WRAP_ARGS (unpack).
local function mkStubs()
    local coords = {
        [1] = { 100, 100, 25 },
        [2] = { 120, 100, 25 },
        [3] = { 130, 100, 25 },
        [4] = { 110, 110, 25 },
        [7] = { 110, 100, 25 },
    }
    local peds = { [1] = "PED", [2] = "P2", [3] = "P3", [7] = "P7" }
    local nicks = { [1] = "Self", [2] = "Nick2", [3] = "Nick3",
        [4] = "Nick4", [7] = "Nick7" }

    local QR_PATH = function() return "/cfg/grnd.cfg" end
    local GRND_CONFIG = { open = fakeOpen }
    local ffi = { cast = function() error("ffi недоступен в стенде") end }
    local sampIsPlayerConnected = function(id) return coords[id] ~= nil end
    local sampGetCharHandleBySampPlayerId = function(id)
        local p = peds[id]
        if p then return true, p end
        return false
    end
    local sampGetPlayerIdByCharHandle = function(ped)
        if ped == "PED" then return 1 end
        for id, p in pairs(peds) do
            if p == ped then return id end
        end
        return -1
    end
    local sampGetPlayerNickname = function(id) return nicks[id] end
    local getCharCoordinates = function(ped)
        if ped == "PED" then
            return coords[1][1], coords[1][2], coords[1][3]
        end
        for id, p in pairs(peds) do
            if p == ped then
                return coords[id][1], coords[id][2], coords[id][3]
            end
        end
        return nil
    end
    local getActiveInterior = function() return 0 end
    local sampGetStreamedOutPlayerPos = function(id)
        if id == 4 then
            return coords[4][1], coords[4][2], coords[4][3]
        end
        return nil
    end

    return {
        QR_PATH, GRND_CONFIG, ffi,
        sampIsPlayerConnected, sampGetCharHandleBySampPlayerId,
        sampGetPlayerIdByCharHandle, sampGetPlayerNickname,
        getCharCoordinates, getActiveInterior, sampGetStreamedOutPlayerPos,
    }
end

resetCfg()
local RT = assert(mkModule()(unpack(mkStubs())))

-- виртуальные часы очереди (150 мс): шаг кадра — 50 мс
local tq = 0
RT.clock = function() return tq end
local function pump(step)
    local ticks = 0
    for _ = 1, 400 do
        if not RT.queue then return ticks end
        tq = tq + (step or 0.05)
        RT.tick()
        ticks = ticks + 1
    end
    return ticks
end

-- ---------- чистая логика RT.fn ----------
check(RT.fn ~= nil, "RT.fn есть")
check(RT.fn.dist(0, 0, 0, 3, 4, 0) == 5, "dist 3-4-0 = 5")
check(math.abs(RT.fn.dist(0, 0, 0, 0, 0, -7) - 7) < 1e-9, "dist по z")

local my = { x = 0, y = 0, z = 0, interior = 0, zd = 0 }
local raw = {
    { id = 1, nick = "Self", x = 0, y = 0, z = 0, self = true },
    { id = 2, nick = "A", x = 20, y = 0, z = 0 },
    { id = 3, nick = "B", x = 25, y = 0, z = 0 }, -- ровно на границе
    { id = 4, nick = "C", x = 26, y = 0, z = 0 }, -- за границей
    { id = 5, nick = "D", x = 10, y = 0, z = 0, interior = 7 },
    { id = 6, nick = "E", x = 10, y = 0, z = 0, zd = 3 },
    { id = 7, nick = "F", x = 12, y = 0, z = 0, interior = nil },
}
local got = RT.fn.scan(raw, my, 25)
local ids = {}
for i = 1, #got do ids[i] = got[i].id end
check(#got == 3, "scan: 3 игрока (self/вне/чужой интерьер/zd — нет)")
check(table.concat(ids, ",") == "7,2,3",
    "scan: сортировка + граница входит: " .. table.concat(ids, ","))
check(got[3] and got[3].id == 3 and got[3].dist == 25,
    "scan: d == radius входит")
check(RT.fn.fill("/give {id} {ник} {дист}",
    { id = 42, nick = "Bob", dist = 12.4 }) == "/give 42 Bob 12",
    "fill {id}/{ник}/{дист}")
check(RT.fn.fill("{nick} {dist}", { nick = "Андрей", dist = 3.2 })
    == "Андрей 3", "fill латинские плейсхолдеры")
check(RT.fn.fill("/freeze", { id = 1 }) == "/freeze",
    "fill без плейсхолдеров")
check(RT.fn.fill("{ник}", { nick = "50%off" }) == "50%off",
    "fill: % в нике не ломает gsub")
check(RT.fn.scan(nil, my, 25) and #RT.fn.scan(nil, my, 25) == 0,
    "scan(nil) → пусто, без ошибки")

-- ---------- живой скан по стабам ----------
check(_G.GRND_RT == RT, "глобальный _G.GRND_RT")
check(type(_G.grndRadTick) == "function", "глобальный _G.grndRadTick")
check(RT.radius == 25, "радиус по умолчанию 25")

local list = RT.scan()
local scanIds = {}
for i = 1, #list do scanIds[i] = list[i].id end
check(#list == 3, "скан: 3 игрока (30 м за границей, себя не берём)")
check(table.concat(scanIds, ",") == "7,4,2",
    "скан: порядок " .. table.concat(scanIds, ","))
check(math.abs(list[1].dist - 10) < 1e-6, "скан: 10 м")
check(math.abs(list[2].dist - math.sqrt(200)) < 1e-6,
    "скан: выстримившийся — последние координаты")
check(RT.err == nil, "скан: ошибок нет")

-- радиус: смена, границы, конфиг
RT.setRadius(RT.radius + 1)
check(RT.radius == 26, "setRadius +1")
RT.setRadius(9999)
check(RT.radius == 200, "setRadius клип 200")
RT.setRadius(0)
check(RT.radius == 1, "setRadius клип 1")
RT.setRadius("не число")
check(RT.radius == 1, "setRadius мусор → без ошибки")
RT.setRadius(77)
check(cfgfile.writes >= 1
    and tostring(cfgfile.content):find("radius=77", 1, true),
    "конфиг: radius=77 записан")

-- ---------- уровни: список чекера «Админы в сети» ----------
check(RT.myLevel() == nil, "уровень: чекера нет → nil")
_G.GRND_AO = { list = { { nick = "Self", id = 1, lvl = 2 },
    { nick = "Other", id = 9, lvl = 8 } } }
check(RT.myLevel() == 2, "уровень: свой из списка чекера (по ID)")
_G.GRND_AO.list[1] = { nick = "  sELf ", lvl = 4 }
check(RT.myLevel() == 4,
    "уровень: поиск по нику (регистр/пробелы) — если ID не совпал")
_G.GRND_AO.list[1] = { nick = "Self", id = 1, lvl = 2 }
-- источники уровня (v1.19.221): по ID, по нику, первая строка, память
do
    local lv, src = RT.myLevel()
    check(lv == 2 and src == "id", "уровень: найден по ID: "
        .. tostring(lv) .. "/" .. tostring(src))
    _G.GRND_AO.list = { { nick = "Другой_Ник", id = 77, lvl = 9 },
        { nick = "{FFCC66}Self{FFFFFF}", lvl = 6 } }
    lv, src = RT.myLevel()
    check(lv == 6 and src == "nick",
        "уровень: найден по нику в цвете: " .. tostring(lv) .. "/"
        .. tostring(src))
    _G.GRND_AO.list = { { nick = "Starshij_Admin", id = 70, lvl = 8 } }
    lv, src = RT.myLevel()
    check(lv == 8 and src == "first",
        "уровень: себя нет — берём первую строку: " .. tostring(lv) .. "/"
        .. tostring(src))
    _G.GRND_AO.list = {}
    lv, src = RT.myLevel()
    check(lv == 8 and src == "stale",
        "уровень: список пуст — помним прошлый: " .. tostring(lv) .. "/"
        .. tostring(src))
    _G.GRND_AO.list = { { nick = "Self", id = 1, lvl = 2 } }
    RT.lvlSeen = nil
    _G.GRND_AO = nil
    lv, src = RT.myLevel()
    check(lv == nil and src == "off",
        "уровень: чекера нет → off (не «ноль-уровень»)")
    _G.GRND_AO = { enabled = false, list = {} }
    lv, src = RT.myLevel()
    check(lv == nil and src == "off", "уровень: чекер выключен → off")
    _G.GRND_AO = { enabled = true, list = { { nick = "Self", id = 1, lvl = 5 } } }
    check(RT.checker() == "on", "чекер: включён")
end
-- требования уровня по кнопкам (v1.19.220)
local lvMap = {}
for i = 1, #RT.actions do
    lvMap[RT.actions[i].id] = RT.actions[i].level or 0
end
check(lvMap.spawn == 2 and lvMap.freeze == 2 and lvMap.unfreeze == 2,
    "уровни: спавн/заморозка/разморозка — 2-й")
check(lvMap.weapon == 5, "уровни: оружие — 5-й")
check(lvMap.skin == 4 and lvMap.hp == 4 and lvMap.armor == 4,
    "уровни: скин/хп/броня — 4-й")
check(lvMap.vehicle == 0 and lvMap.takeoff == 0,
    "уровни: транспорт и «отобрать оружие» — без требования")
check(RT.actById("hp") ~= nil and RT.actById("xp") == nil,
    "кнопка «Выдать XP» переименована в «Выдать HP»")
check(RT.actById("hp").label == "Выдать HP", "подпись «Выдать HP»")

-- ---------- команды: точный текст ----------
RT.setRadius(25) -- в радиусе: 7, 4, 2
local p7 = { id = 7, nick = "Nick7", dist = 10 }
check(RT.cmdFor("spawn", p7) == "/spawn 7", "команда: /spawn ID")
check(RT.cmdFor("freeze", p7) == "/freeze 7", "команда: /freeze ID")
check(RT.cmdFor("unfreeze", p7) == "/unfreeze 7", "команда: /unfreeze ID")
check(RT.cmdFor("weapon", p7) == "/gun 7 22 30",
    "команда: /gun ID {ид оружия} {патроны} (по умолчанию)")
check(RT.weapons[1].id == 22 and RT.weapons[1].name == "Пистолет",
    "оружие: первый — Пистолет (22)")
check(RT.weapons[3].id == 24 and RT.weapons[3].name == "Дезерт Игл",
    "оружие: третий — Дезерт Игл (24)")
RT.settings.weapon.sel = 3
RT.settings.weapon.ammo = 150
check(RT.cmdFor("weapon", p7) == "/gun 7 24 150",
    "команда: /gun — ID оружия из ползунка: " .. tostring(RT.cmdFor("weapon", p7)))
RT.settings.skin.num = ""
check(RT.cmdFor("skin", p7) == nil,
    "команда: скин без номера → nil")
RT.settings.skin.num = "1540"
check(RT.cmdFor("skin", p7) == "/setskin 7 1540",
    "команда: /setskin ID {ид скина}")
RT.settings.armor.amount = 100
check(RT.cmdFor("armor", p7) == "/arm 7 100", "команда: /arm ID {броня}")
check(RT.cmdFor("hp", nil) == "/hpall", "команда: /hpall (одна на всех)")
check(RT.cmdFor("hp", p7) == "/hpall", "команда: /hpall не зависит от игрока")
RT.settings.vehicle.mode = 2
check(RT.cmdFor("vehicle", nil) == "/spcars 2",
    "команда: /spcars {режим}")
check(RT.cmdFor("takeoff", p7) == "/weapall",
    "команда: «Отобрать оружие» → /weapall (одна на всех)")
check(RT.cmdFor("tpself", p7) == "/gethere 7",
    "команда: «Телепорт всех к себе» → /gethere ID")
check(RT.actById("tpself") ~= nil and RT.actById("tpself").level == 3
    and RT.actById("tpself").per == true,
    "«Телепорт всех»: 3-й уровень и выдача по игрокам")
check(RT.actById("takeoff").solo == true,
    "«Отобрать оружие»: одна команда на всех")

-- ---------- гейт по уровню ----------
-- «нужен N-й уровень» = N и ВЫШЕ: проверяем отказ ниже и проход на N и выше
_G.GRND_AO.list[1] = { nick = "Self", id = 1, lvl = 2 }
_G.GRND_AO.enabled = true
RT.lvlSeen = nil
RT.settings.weapon.sel = 1
RT.settings.weapon.ammo = 30
local before = #sent
RT.doAction("weapon") -- уровень 2 < 5
check(#sent == before, "уровень 2: /gun не отправлен")
local lastToast = toasts[#toasts]
check(lastToast and lastToast.text
    == "Нет доступа к данной команде, нужен 5-й уровень",
    "уровень 2: тост про 5-й уровень: " .. tostring(lastToast and lastToast.text))
check(lastToast and lastToast.kind == "warn", "уровень: тост warn")
check(RT.lastAct and RT.lastAct:find("нет доступа", 1, true),
    "уровень: «Было:» — нет доступа")
RT.doAction("skin") -- уровень 2 < 4
lastToast = toasts[#toasts]
check(lastToast and lastToast.text
    == "Нет доступа к данной команде, нужен 4-й уровень",
    "уровень 2: тост про 4-й уровень (скин)")
RT.doAction("armor")
check(toasts[#toasts].text == "Нет доступа к данной команде, нужен 4-й уровень",
    "уровень 2: тост про 4-й уровень (броня)")
RT.doAction("hp")
check(toasts[#toasts].text == "Нет доступа к данной команде, нужен 4-й уровень",
    "уровень 2: тост про 4-й уровень (хп)")

-- уровень определить не вышло: честный тост + перезапрос чекера
do
    _G.GRND_AO.list = {}
    RT.lvlSeen = nil
    _G.GRND_AO.nextAt = os.clock() + 60
    before = #sent
    RT.doAction("weapon")
    check(#sent == before, "уровень неизвестен: чат не трогаем")
    check(toasts[#toasts].text:find("Уровень не определён", 1, true) ~= nil
        and toasts[#toasts].text:find("5-й уровень", 1, true) ~= nil,
        "уровень неизвестен: тост «Уровень не определён (…) — нужен 5-й»: "
        .. tostring(toasts[#toasts].text))
    check(_G.GRND_AO.nextAt == 0,
        "уровень неизвестен: чекеру заказан перезапрос (nextAt=0)")
    check(RT.lastAct and RT.lastAct:find("уровень не определён", 1, true),
        "уровень неизвестен: «Было:» — уровень не определён")
    -- повторное нажатие в пределах 4 с: не долбим чекер запросами
    _G.GRND_AO.nextAt = os.clock() + 60
    RT.doAction("weapon")
    check(toasts[#toasts].text:find("уже запрашиваю", 1, true) ~= nil
        and _G.GRND_AO.nextAt ~= 0,
        "уровень неизвестен: перезапрос не чаще раза в 4 с")
    -- кнопка «Обновить» — запрос принудительный (force)
    check(RT.refreshLevels(true) == true and _G.GRND_AO.nextAt == 0,
        "кнопка «Обновить»: перезапрос даже в пределах 4 с")
    -- чекер выключен — говорим об этом прямо
    _G.GRND_AO = { enabled = false, list = {} }
    local okAsk, why = RT.refreshLevels(true)
    check(okAsk == false and tostring(why):find("включите чекер", 1, true),
        "чекер выключен: понятная причина: " .. tostring(why))
    RT.doAction("weapon")
    check(toasts[#toasts].text:find("включите чекер", 1, true) ~= nil,
        "чекер выключен: тост про включение чекера: "
        .. tostring(toasts[#toasts].text))
    _G.GRND_AO = { enabled = true, list = { { nick = "Self", id = 1, lvl = 5 } } }
end

-- уровень поднят: команды доступны
_G.GRND_AO.list[1].lvl = 5
check(RT.myLevel() == 5, "уровень: поднят до 5")
before = #sent
check(RT.doAction("spawn") == true, "уровень 5: /spawn разрешён")
check(#sent == before, "уровень 5: /spawn ушёл в очередь (пока тик не звал)")
check(RT.queue ~= nil and #RT.queue.cmds == 3,
    "очередь: 3 команды (7, 4, 2)")
-- первый тик: ровно одна команда (не пачка) + интервал ровно 150 мс
tq = tq + 0.05
RT.tick()
check(#sent - before == 1, "очередь: за тик — одна команда (не пачка)")
check(RT.queue and math.abs((RT.queue.at - tq) - 0.15) < 1e-6,
    "очередь: интервал между командами 150 мс")
tq = tq + 0.05
RT.tick()
tq = tq + 0.05
RT.tick()
check(#sent - before == 1, "очередь: раньше 150 мс второй команды нет")
tq = tq + 0.05
RT.tick()
tq = tq + 0.05
RT.tick()
check(#sent - before == 2, "очередь: вторая команда — в пределах 150–250 мс")
local ticks = pump(0.05)
check(#sent - before == 3, "очередь: 3 команды отправлены")
check(ticks <= 3, "очередь: хвост добирается за пару тиков: "
    .. tostring(ticks))
check(sent[#sent - 2] == "/spawn 7" and sent[#sent - 1] == "/spawn 4"
    and sent[#sent] == "/spawn 2",
    "очередь: порядок и текст: " .. table.concat(sent, " | "))
check(RT.queue == nil, "очередь: закрыта после выдачи")
check(RT.lastAct and RT.lastAct:find("3/3", 1, true), "«Было:» 3/3")
lastToast = toasts[#toasts]
check(lastToast and lastToast.kind == "ok"
    and lastToast.text:find("3 игрокам", 1, true), "очередь: тост ok")

-- остальные команды — по игрокам
before = #sent
RT.doAction("freeze")
pump(0.05)
check(#sent - before == 3 and sent[#sent - 1] == "/freeze 4"
    and sent[#sent] == "/freeze 2", "выдача: /freeze по игрокам")
before = #sent
RT.doAction("unfreeze")
pump(0.05)
check(#sent - before == 3 and sent[#sent] == "/unfreeze 2",
    "выдача: /unfreeze по игрокам")
RT.settings.weapon.sel = 3
RT.settings.weapon.ammo = 150
before = #sent
RT.doAction("weapon") -- уровень 5 = ровно требуемый
pump(0.05)
check(#sent - before == 3 and sent[#sent] == "/gun 2 24 150",
    "выдача: оружие с ползунка: " .. tostring(sent[#sent]))
RT.settings.skin.num = ""
before = #sent
RT.doAction("skin")
check(#sent == before and toasts[#toasts].text
    :find("настройки", 1, true) ~= nil,
    "выдача: скин без номера — просит настройку, чат молчит")
RT.settings.skin.num = "1540"
before = #sent
RT.doAction("skin")
pump(0.05)
check(#sent - before == 3 and sent[#sent] == "/setskin 2 1540",
    "выдача: скин по игрокам")
RT.settings.armor.amount = 100
before = #sent
RT.doAction("armor")
pump(0.05)
check(#sent - before == 3 and sent[#sent] == "/arm 2 100",
    "выдача: броня по игрокам")

-- одиночные команды: игроки в радиусе не нужны (/hpall — радиус вшит)
RT.setRadius(1)
before = #sent
check(RT.doAction("hp") == true and #sent - before == 1
    and sent[#sent] == "/hpall",
    "выдача: /hpall — одна команда, радиус не нужен")
RT.settings.vehicle.mode = 3
before = #sent
check(RT.doAction("vehicle") == true and #sent - before == 1
    and sent[#sent] == "/spcars 3",
    "выдача: /spcars 3 «все»")
RT.settings.vehicle.mode = 1
before = #sent
RT.doAction("vehicle")
check(sent[#sent] == "/spcars 1", "выдача: /spcars 1 «админские»")
check(#sent - before == 1, "выдача: /spcars — одна команда на всех")

-- пустой радиус у команд по игрокам
before = #sent
RT.doAction("spawn")
check(#sent == before, "пустой радиус: чат не трогаем")
check(toasts[#toasts].text:find("никого", 1, true),
    "пустой радиус: тост «никого»")
RT.setRadius(25)

-- «Отобрать оружие» (/weapall) и «Телепорт всех» (/gethere ID)
before = #sent
check(RT.doAction("takeoff") == true and #sent - before == 1
    and sent[#sent] == "/weapall",
    "takeoff: /weapall — одна команда на всех")
_G.GRND_AO.list[1].lvl = 2
before = #sent
RT.doAction("tpself")
check(#sent == before, "tpself на 2-м уровне: чат не трогаем")
check(toasts[#toasts].text
    == "Нет доступа к данной команде, нужен 3-й уровень",
    "tpself на 2-м уровне: тост про 3-й уровень")
_G.GRND_AO.list[1].lvl = 3
before = #sent
check(RT.doAction("tpself") == true, "tpself на 3-м уровне: разрешён")
pump(0.05)  -- 3 игрока в радиусе: 3 команды
check(#sent - before == 3 and sent[#sent - 2] == "/gethere 7"
    and sent[#sent] == "/gethere 2",
    "tpself: /gethere по игрокам: " .. table.concat(sent, " | "))
_G.GRND_AO.list[1].lvl = 5

-- падение отправки
qr.sendChat = function() return false end
RT.doAction("spawn")
pump(0.05)
check(RT.lastAct and RT.lastAct:find("0/3", 1, true),
    "«Было:» 0/3 при падении")
check(toasts[#toasts].kind == "warn", "падение: тост warn")
qr.sendChat = function(t) table.insert(sent, t) return true end

-- нет подключения: sampIsPlayerConnected не функция (4-й аргумент = nil)
local stubs3 = mkStubs()
stubs3[4] = nil
local RT3 = assert(mkModule()(unpack(stubs3, 1, 10)))
RT3.clock = function() return 0 end
check(RT3.scan() == nil and tostring(RT3.err):find("SAMP", 1, true),
    "нет подключения: scan nil + err")
check(RT3.myLevel() == 5, "уровень: RT3 видит тот же список чекера")
before = #sent
RT3.doAction("spawn")
check(#sent == before, "нет подключения: чат не трогаем")

-- ---------- настройки: сохранение/загрузка ----------
RT.settings.weapon.sel = 5
RT.settings.weapon.ammo = 42
RT.settings.skin.num = "777"
RT.settings.armor.amount = 33
RT.settings.vehicle.mode = 2
RT.save()
local cfgTxt = tostring(cfgfile.content or "")
check(cfgTxt:find("wsel=5", 1, true) and cfgTxt:find("wammo=42", 1, true)
    and cfgTxt:find("skin=777", 1, true)
    and cfgTxt:find("armor=33", 1, true)
    and cfgTxt:find("vmode=2", 1, true),
    "конфиг: настройки записаны")
check(cfgTxt:find("radius=25", 1, true), "конфиг: радиус рядом")
resetCfg("radius=63\nwsel=999\nwammo=5000\nskin=99\narmor=0\nvmode=9\n")
local RT2 = assert(mkModule()(unpack(mkStubs())))
RT2.load()
check(RT2.radius == 63, "конфиг: radius=63 загружен")
check(RT2.settings.weapon.sel == #RT2.weapons,
    "конфиг: выбор оружия клип по списку")
check(RT2.settings.weapon.ammo == 999, "конфиг: патроны клип 999")
check(RT2.settings.skin.num == "99", "конфиг: скин загружен")
check(RT2.settings.armor.amount == 1, "конфиг: броня клип 1..100")
check(RT2.settings.vehicle.mode == 3, "конфиг: режим транспорта клип 3")

-- ---------- стиль ползунка (grndUiSlider): полустеклянный, наш ----------
do
    local s0 = src:find("function grndUiSlider(ctx, id, x, y, w, h, ratio)",
        1, true) -- plain: скобки в сигнатуре — не шаблон
    local s1 = s0 and src:find("\nend\n", s0)
    check(s0 ~= nil and s1 ~= nil, "grndUiSlider: функция найдена в файле")
    if s0 and s1 then
        local fnText = src:sub(s0, s1 + 4)
        local slOk, slFn = pcall(function()
            return assert(load("return (function()\n" .. fnText
                .. "\n    return grndUiSlider\nend)()", "@slider"))()
        end)
        check(slOk, "grndUiSlider: загружена: " .. tostring(slFn))
        if slOk then
            local function pack(r, g, b, a)
                return r * 16777216 + g * 65536 + b * 256 + (a or 255)
            end
            _G.grndUiTheme = function()
                return { accent = { 164, 112, 224, 255 },
                    accent2 = { 196, 156, 255, 255 } }
            end
            local draws = {}
            local fctx = {
                im = {
                    SetCursorPos = function() end,
                    ImVec2 = function(x, y) return { x = x, y = y } end,
                    InvisibleButton = function() end,
                    IsItemActive = function() return false end,
                },
                dl = {
                    -- как в панели: AddRect(dl, p1, p2, col, r, flags, th)
                    AddRect = function(_, p1, p2, col, r, flags, th)
                        table.insert(draws, { t = "rect", a = p1, b = p2,
                            col = col, r = r, th = th })
                    end,
                },
                at = function(x, y) return { x = x, y = y } end,
                col32 = pack,
                roundRect = function(_, a, b, col, r)
                    table.insert(draws, { t = "rr", a = a, b = b, col = col,
                        r = r })
                end,
                gradRect = function(_, a, b, c1, c2, r)
                    table.insert(draws, { t = "grad", a = a, b = b,
                        c1 = c1, c2 = c2, r = r })
                end,
            }
            local w, h, ratio, x0, y0s = 100, 26, 0.5, 0, 0
            slFn(fctx, "##bench_sl", x0, y0s, w, h, ratio)
            local ty = y0s + h / 2
            local kx = x0 + w * ratio
            -- 1) дорожка + кромка + «пилюля» (заливки нет — макет)
            check(#draws == 3,
                "ползунок: дорожка, кромка и «пилюля» (без заливки): "
                .. #draws)
            local track = draws[1]
            check(track and track.t == "rr"
                and track.a.x == x0 and track.a.y == ty - 8
                and track.b.x == x0 + w and track.b.y == ty + 8
                and track.col == pack(255, 255, 255, 42),
                "ползунок: дорожка 16 px полустеклянная (42)")
            -- 2) кромка: тонкая светлая рамка по дорожке (как на макете)
            local edge = draws[2]
            check(edge and edge.t == "rect"
                and edge.col == pack(255, 255, 255, 52)
                and edge.th == 1
                and math.abs(edge.a.y - (ty - 8)) < 0.01
                and math.abs(edge.b.y - (ty + 8)) < 0.01,
                "ползунок: светлая кромка дорожки")
            -- 3) «пилюля»: светлая, вертикальная, чуть короче дорожки
            local pill = draws[3]
            check(pill and pill.t == "rr"
                and math.abs(pill.a.x - (kx - 5)) < 0.01
                and math.abs(pill.b.x - (kx + 5)) < 0.01
                and math.abs(pill.a.y - (ty - 6)) < 0.01
                and math.abs(pill.b.y - (ty + 6)) < 0.01
                and pill.col == pack(232, 234, 244, 245)
                and (pill.b.y - pill.a.y) < (track.b.y - track.a.y),
                "ползунок: светлая «пилюля» 10×12 в центре по ratio")
            -- 4) ratio 0 и 1 — у краёв
            local function knobX(rratio)
                draws = {}
                slFn(fctx, "##bench_sl_k", x0, y0s, w, h, rratio)
                return draws[3] and draws[3].a.x, draws[3] and draws[3].b.x
            end
            local l0, r0 = knobX(0)
            check(l0 ~= nil and math.abs(l0 - (x0 - 5)) < 0.01
                and math.abs(r0 - (x0 + 5)) < 0.01,
                "ползунок: ratio 0 — «пилюля» у левого края")
            local l1, r1 = knobX(1)
            check(l1 ~= nil and math.abs(l1 - (x0 + w - 5)) < 0.01
                and math.abs(r1 - (x0 + w + 5)) < 0.01,
                "ползунок: ratio 1 — «пилюля» у правого края")
            -- 5) зелёного нигде
            local noGreen = true
            for i = 1, #draws do
                if draws[i].col == pack(0, 214, 170, 255) then
                    noGreen = false
                end
            end
            check(noGreen, "ползунок: зелёного фолбэка нет")
            _G.grndUiTheme = nil
        end
    end
end

-- ---------- страница RT.page на стаб-рендерере ----------
local drawn, clicks, gears, sliders, inputs, frames = {}, {}, {}, {}, {}, {}
local function mkR(allow)
    allow = allow or {}
    return {
        uiText = function(x, y, t) table.insert(drawn, { x = x, y = y, t = t }) end,
        tsize = function(t) return #tostring(t) * 7 end,
        col32 = function(r, g, b, a) return { r, g, b, a } end,
        c4 = function(c) return c end,
        roundRect = function() end,
        dl = {},
        at = function(x, y) return x, y end,
        theme = function()
            return {
                textDim = { 185, 185, 190, 255 },
                textMuted = { 140, 140, 150, 255 },
                textHi = { 240, 240, 245, 255 },
                accent = { 164, 112, 224, 255 },
            }
        end,
        button = function(key, x, y, w, h, label, opts)
            table.insert(clicks, { key = key, x = x, y = y,
                w = w, h = h, label = label, opts = opts })
            return allow[key] == true
        end,
        slider = function(id, x, y, w, h, ratio)
            table.insert(sliders, { id = id, x = x, y = y, w = w,
                ratio = ratio })
            return allow[id] or allow.slider or nil
        end,
        gearButton = function(key, x, y, active)
            table.insert(gears, { key = key, x = x, y = y })
            return allow[key] == true
        end,
        gear = function(x, y, col)
            table.insert(gears, { key = "static", x = x, y = y })
        end,
        textInput = function(key, id, cap, value, x, y, w, h, hint, cb)
            table.insert(inputs, { key = key, id = id, cap = cap,
                value = value, x = x, y = y, w = w, h = h, hint = hint })
            if allow.textInputValue ~= nil and type(cb) == "function" then
                cb(allow.textInputValue)
            end
            return value
        end,
        frameRect = function(x1, y1, x2, y2, col, rad, th)
            table.insert(frames, { x1 = x1, y1 = y1, x2 = x2, y2 = y2 })
        end,
    }
end
local function resetDrawn()
    drawn, clicks, gears, sliders, inputs, frames = {}, {}, {}, {}, {}, {}
end
local function keys(list_)
    local out = {}
    for i = 1, #list_ do out[i] = list_[i].key end
    return table.concat(out, ",")
end

local cw, y0 = 320, 40
RT.setRadius(25)
RT.settingsOpen = nil
RT.lastAct = "Заспавнить: 3/3 (Nick7, Nick4, Nick2)"
resetDrawn()
local y1 = RT.page(mkR(), 10, y0, cw)
check(type(y1) == "number" and y1 > y0, "page: y растёт")
-- кнопки ищем по ключу: список ниже задаёт и состав, и порядок страницы
local function clickOf(key)
    for i = 1, #clicks do
        if clicks[i].key == key then return clicks[i], i end
    end
    return nil
end
local function clickOrder()
    local out = {}
    for i = 1, #clicks do out[i] = clicks[i].key end
    return table.concat(out, ",")
end
check(#clicks == 13,
    "page: 13 кнопок (радиус, уровень, 9 сетки, tp): " .. #clicks)
check(clickOrder() == "rt_minus,rt_plus,rt_lvl_refresh,"
    .. "rt_act_spawn,rt_act_freeze,rt_act_unfreeze,"
    .. "rt_act_weapon,rt_act_skin,rt_act_hp,"
    .. "rt_act_armor,rt_act_vehicle,rt_act_takeoff,rt_tp",
    "page: порядок кнопок, сетка 3×3 по макету: " .. clickOrder())
local minus, plus = clickOf("rt_minus"), clickOf("rt_plus")
check(minus and minus.w == 26, "page: «−» слева 26×26")
check(plus and plus.w == 26, "page: «+» справа 26×26")
local tp = clickOf("rt_tp")
check(tp and tp.w == cw and tp.label == "Телепорт всех к себе",
    "page: широкая «Телепорт всех к себе» на всю ширину")
-- отступ: широкая кнопка чётко НИЖЕ сетки (между ними — строка уровня)
local gridEnd = y0 + 4 + 26 + 10 + 18 + 3 * (26 + 8) - 8
check(tp and tp.y >= gridEnd + 12 - 0.01 and tp.y <= gridEnd + 20,
    "page: «Телепорт» сдвинут ниже сетки (y=" .. tostring(tp and tp.y) .. ")")
-- ровная сетка: все 9 кнопок одной ширины
local actKeys = { "spawn", "freeze", "unfreeze", "weapon", "skin", "hp",
    "armor", "vehicle", "takeoff" }
local bw0, evenOk = nil, true
for i = 1, #actKeys do
    local c = clickOf("rt_act_" .. actKeys[i])
    if c == nil then
        evenOk = false
    else
        if not bw0 then bw0 = c.w end
        if math.abs(c.w - bw0) > 0.01 then evenOk = false end
    end
end
check(evenOk and bw0 ~= nil and bw0 > 40, "page: все 9 кнопок одной ширины")
-- шестерёнки: БЕЗ подложки (не в списке кнопок), значок вплотную
-- за краем кнопки (зона 30×30 начинается от края: +15 до центра)
local gearKeys = {}
for i = 1, #gears do gearKeys[i] = gears[i].key end
check(table.concat(gearKeys, ",")
    == "rt_gear_weapon,rt_gear_skin,rt_gear_armor,rt_gear_vehicle",
    "page: 4 шестерёнки без подложки: " .. table.concat(gearKeys, ","))
local gearIds = { "weapon", "skin", "armor", "vehicle" }
local gearOut = true
for i = 1, 4 do
    local btn, ic = clickOf("rt_act_" .. gearIds[i]), gears[i]
    if btn == nil or ic == nil
        or math.abs(ic.x - (btn.x + btn.w + 15)) > 0.01
        or math.abs(ic.y - (btn.y + 13)) > 0.01 then
        gearOut = false
    end
end
check(gearOut, "page: значок вплотную за краем кнопки (без налёта)")
-- строка уровня (v1.19.221): видно уровень и источник + кнопка «Обновить»
local lvlRow = nil
for i = 1, #drawn do
    if tostring(drawn[i].t):find("Уровень:", 1, true) then lvlRow = drawn[i] end
end
check(lvlRow ~= nil and lvlRow.t:find("5", 1, true) ~= nil,
    "page: строка «Уровень: N» есть: " .. tostring(lvlRow and lvlRow.t))
local lvlBtn = clickOf("rt_lvl_refresh")
check(lvlBtn ~= nil and lvlBtn.w == 84 and lvlBtn.label == "Обновить",
    "page: кнопка «Обновить» у строки уровня")
local joined = {}
for i = 1, #drawn do joined[i] = drawn[i].t end
joined = table.concat(joined, "\n")
check(joined:find("Радиус: 25", 1, true), "page: строка «Радиус: 25»")
-- v1.19.219: текст — ПО ЦЕНТРУ ДОРОЖКИ (дорожка от «−» до «+»)
local slX0 = 10 + 26 + 8 -- cx + bh + 8
local slW0 = cw - 2 * 26 - 16
local lw0 = #("Радиус: 25") * 7 * 0.8
local labRow = nil
for i = 1, #drawn do
    if drawn[i].t == "Радиус: 25" then labRow = drawn[i] end
end
check(labRow ~= nil
    and math.abs(labRow.x - (slX0 + (slW0 - lw0) / 2)) < 0.01
    and math.abs(labRow.y - (y0 + 4 + (26 - 12) / 2)) < 0.01,
    "page: «Радиус: N» по центру дорожки (x="
    .. tostring(labRow and labRow.x) .. ")")
check(joined:find("В радиусе", 1, true) == nil,
    "page: строка «В радиусе…» убрана")
check(joined:find("Было:", 1, true), "page: строка «Было:»")

-- клики: «+» / «−»
RT.setRadius(50)
RT.page(mkR({ rt_plus = true }), 10, y0, cw)
check(RT.radius == 51, "page: клик «+» → +1")
RT.page(mkR({ rt_minus = true }), 10, y0, cw)
check(RT.radius == 50, "page: клик «−» → −1")

-- drag ползунка: ratio 0.5 → radius = 1 + 0.5*199 + 0.5 = 101
RT.setRadius(50)
RT.page(mkR({ slider = 0.5 }), 10, y0, cw)
check(RT.radius == 101, "page: drag ползунка → радиус по позиции: " .. RT.radius)
check(#sliders >= 1 and sliders[#sliders].id == "rt_radius_sl",
    "page: ползунок — общий слайдер меню (id rt_radius_sl)")

-- ---------- клик по кнопке действия (уровень из чекера) ----------
RT.setRadius(25)
_G.GRND_AO.list[1].lvl = 2
resetDrawn()
RT.lastAct = nil
local sentBefore = #sent
RT.page(mkR({ rt_act_weapon = true }), 10, y0, cw)
check(#sent == sentBefore and toasts[#toasts].text
    == "Нет доступа к данной команде, нужен 5-й уровень",
    "page: кнопка «Выдать оружие» на 2-м уровне — тост про доступ")
_G.GRND_AO.list[1].lvl = 5
RT.page(mkR({ rt_act_spawn = true }), 10, y0, cw)
check(RT.queue ~= nil, "page: кнопка «Заспавнить» на 5-м уровне — очередь")
pump(0.05)
check(#sent - sentBefore == 3 and sent[#sent] == "/spawn 2",
    "page: кнопка отправила /spawn по игрокам")

-- ---------- шестерёнка → настройка вместо сетки ----------
_G.GRND_AO.list[1].lvl = 8
RT.settingsOpen = nil
resetDrawn()
RT.page(mkR({ rt_gear_weapon = true }), 10, y0, cw)
check(RT.settingsOpen == "weapon",
    "шестерёнка: открывает настройку (а не «появится позже»)")
check(#toasts == 0 or toasts[#toasts].text:find("настройка появится", 1, true)
    == nil, "шестерёнка: тоста «появится вместе с командой» больше нет")
check(RT.lastAct and RT.lastAct:find("настройки", 1, true),
    "шестерёнка: «Было:» — настройки")

-- настройка «Выдать оружие»: ползунок имён + ползунок патронов
RT.settings.weapon.sel = 1
RT.settings.weapon.ammo = 30
for _, k in ipairs({ "weapon", "skin", "armor", "vehicle" }) do
    RT.settingsOpen = k
    resetDrawn()
    local ys = RT.page(mkR(), 10, y0, cw)
    check(type(ys) == "number" and ys > y0,
        "настройка " .. k .. ": y растёт")
    local txt = {}
    for i = 1, #drawn do txt[i] = drawn[i].t end
    txt = table.concat(txt, "\n")
    local hasAct = false
    for i = 1, #clicks do
        if clicks[i].key:find("rt_act_", 1, true) then hasAct = true end
    end
    check(txt:find("НАСТРОЙКА", 1, true) ~= nil and not hasAct,
        "настройка " .. k .. ": панель вместо сетки (кнопок действий нет)")
    check(#frames >= 1, "настройка " .. k .. ": рамка карточки")
end

RT.settingsOpen = "weapon"
resetDrawn()
RT.page(mkR(), 10, y0, cw)
check(keys(clicks) == "rt_minus,rt_plus,rt_lvl_refresh,rt_set_close,"
    .. "rt_set_wminus,rt_set_wplus,rt_set_aminus,rt_set_aplus",
    "настройка оружия: закрытие и ± ползунков (радиус сверху): "
    .. keys(clicks))
check(#sliders == 3 and sliders[1].id == "rt_radius_sl"
    and sliders[2].id == "rt_set_wsl" and sliders[3].id == "rt_set_asl",
    "настройка оружия: ползунки оружия и патронов (радиус рядом)")
local wtxt = {}
for i = 1, #drawn do wtxt[i] = drawn[i].t end
wtxt = table.concat(wtxt, "\n")
check(wtxt:find("Пистолет (22)", 1, true) ~= nil
    and wtxt:find("Патроны: 30", 1, true) ~= nil,
    "настройка оружия: имя+ID оружия и патроны — в тексте ползунков")
-- «+» оружия: следующий ID (Пистолет → Дробовик)
resetDrawn()
RT.page(mkR({ rt_set_wplus = true }), 10, y0, cw)
check(RT.settings.weapon.sel == 2, "настройка оружия: «+» → следующее: "
    .. tostring(RT.settings.weapon.sel))
resetDrawn()
RT.page(mkR({ rt_set_wsl = 1 }), 10, y0, cw)
check(RT.settings.weapon.sel == #RT.weapons,
    "настройка оружия: drag → последнее оружие: "
    .. tostring(RT.settings.weapon.sel))
check(RT.cmdFor("weapon", { id = 7 }) == "/gun 7 46 30",
    "настройка оружия: ID из ползунка идёт в команду")
RT.settings.weapon.sel = 1
-- патроны: drag и «−»
resetDrawn()
RT.page(mkR({ rt_set_asl = 0.5 }), 10, y0, cw)
check(RT.settings.weapon.ammo == 500,
    "настройка патронов: drag 0.5 → 500 (диапазон 1..999): "
    .. tostring(RT.settings.weapon.ammo))
resetDrawn()
RT.page(mkR({ rt_set_aminus = true }), 10, y0, cw)
check(RT.settings.weapon.ammo == 499, "настройка патронов: «−» → 499")
resetDrawn()
RT.page(mkR({ rt_set_asl = 1 }), 10, y0, cw)
check(RT.settings.weapon.ammo == 999, "настройка патронов: клип 999")

-- настройка «Выдать броню»: 1..100
RT.settingsOpen = "armor"
RT.settings.armor.amount = 50
resetDrawn()
RT.page(mkR({ rt_set_bplus = true }), 10, y0, cw)
check(RT.settings.armor.amount == 51, "настройка брони: «+» → 51: "
    .. tostring(RT.settings.armor.amount))
resetDrawn()
RT.page(mkR({ rt_set_bsl = 1 }), 10, y0, cw)
check(RT.settings.armor.amount == 100, "настройка брони: ползунок → 100")
RT.page(mkR({ rt_set_bsl = 1 }), 10, y0, cw)
check(RT.settings.armor.amount == 100, "настройка брони: клип 100")
RT.page(mkR({ rt_set_bminus = true }), 10, y0, cw)
check(RT.settings.armor.amount == 99, "настройка брони: «−» → 99")

-- настройка «Выдать скин»: номер вручную (поле ввода)
RT.settingsOpen = "skin"
RT.settings.skin.num = ""
resetDrawn()
RT.page(mkR({ textInputValue = "1540" }), 10, y0, cw)
check(#inputs == 1 and inputs[1].key == "rt_set_skin"
    and inputs[1].cap == 8,
    "настройка скина: поле ввода (до 8 знаков)")
check(RT.settings.skin.num == "1540",
    "настройка скина: номер сохранён: " .. tostring(RT.settings.skin.num))
check(RT.cmdFor("skin", { id = 4 }) == "/setskin 4 1540",
    "настройка скина: номер идёт в команду")

-- настройка «Заспавнить транспорт»: 3 кнопки
RT.settingsOpen = "vehicle"
RT.settings.vehicle.mode = 1
resetDrawn()
RT.page(mkR({ rt_set_veh2 = true }), 10, y0, cw)
check(RT.settings.vehicle.mode == 2, "настройка транспорта: выбор «Незанятые»")
local vtxt = {}
for i = 1, #drawn do vtxt[i] = drawn[i].t end
vtxt = table.concat(vtxt, "\n")
check(vtxt:find("НАСТРОЙКА: ТРАНСПОРТ", 1, true) ~= nil,
    "настройка транспорта: заголовок панели")
check(clicks[5] and clicks[5].key == "rt_set_veh1"
    and clicks[5].label == "Админские"
    and clicks[6] and clicks[6].label == "Незанятые"
    and clicks[7] and clicks[7].label == "Все",
    "настройка транспорта: 3 кнопки: " .. keys(clicks))
check(clicks[5] and clicks[5].opts and clicks[5].opts.selected == true
    and clicks[6] and clicks[6].opts and clicks[6].opts.selected == false
    and clicks[7] and clicks[7].opts and clicks[7].opts.selected == false,
    "настройка транспорта: подсвечен текущий режим («Админские»)")
resetDrawn()
RT.page(mkR(), 10, y0, cw)
check(clicks[6] and clicks[6].opts and clicks[6].opts.selected == true
    and clicks[5] and clicks[5].opts.selected == false,
    "настройка транспорта: подсветка перешла на «Незанятые»")
check(RT.cmdFor("vehicle", nil) == "/spcars 2",
    "настройка транспорта: режим идёт в /spcars")
resetDrawn()
RT.page(mkR({ rt_set_veh3 = true }), 10, y0, cw)
check(RT.settings.vehicle.mode == 3
    and RT.cmdFor("vehicle", nil) == "/spcars 3", "настройка транспорта: «Все»")

-- «Закрыть» → назад к сетке
resetDrawn()
RT.page(mkR({ rt_set_close = true }), 10, y0, cw)
check(RT.settingsOpen == nil, "настройка: «Закрыть» → назад к сетке")
resetDrawn()
RT.page(mkR(), 10, y0, cw)
check(#clicks == 13,
    "настройка: после закрытия — снова сетка (радиус, уровень, 9, tp)")
-- настройки без textInput/frameRect (старый рендерер) — не падает
RT.settingsOpen = "skin"
resetDrawn()
local stubNo = mkR()
stubNo.textInput, stubNo.frameRect = nil, nil
local okNoInput = pcall(RT.page, stubNo, 10, y0, cw)
check(okNoInput, "настройка скина: рендерер без поля ввода — без ошибки")
RT.settingsOpen = nil

-- кнопка «Обновить» у строки уровня: перезапрос чекера прямо из раздела
do
    _G.GRND_AO = { enabled = true, list = { { nick = "Self", id = 1, lvl = 5 } } }
    RT.lvlSeen = nil
    _G.GRND_AO.nextAt = os.clock() + 60
    RT.lvlAskAt = nil
    local beforeT2 = #toasts
    resetDrawn()
    RT.page(mkR({ rt_lvl_refresh = true }), 10, y0, cw)
    check(_G.GRND_AO.nextAt == 0, "page: «Обновить» → чекер перезапросит /admins")
    check(#toasts == beforeT2 + 1 and toasts[#toasts].text
        :find("Обновляю список админов", 1, true) ~= nil,
        "page: «Обновить» → тост: " .. tostring(toasts[#toasts].text))
end

-- защита: мусорный рендерер не роняет страницу
check(RT.page(nil, 0, 0, 100) == 0, "page: R=nil → y")
check(RT.page({}, 0, 0, 100) == 0, "page: R без button → y")

-- тик
RT.visible = true
check(pcall(RT.tick), "tick: без ошибок при visible")
RT.visible = false
check(pcall(RT.tick), "tick: без ошибок при visible=false")
RT.queue = nil
check(pcall(_G.grndRadTick), "tick: глобальная обёртка grndRadTick")

if results.fail > 0 then
    print(("--- выдача в радиусе: %d passed, %d failed ---")
        :format(results.pass, results.fail))
    os.exit(1)
end
print(("--- выдача в радиусе: %d/%d ok ---")
    :format(results.pass, results.pass + results.fail))
