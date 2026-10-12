-- =====================================================================
-- Стенд v1.19.215: раздел «ВЫДАЧА В РАДИУСЕ» (GRND_RT).
--
-- Загружает блок do...end между якорями GRND_RADTOOLS_* как функцию
-- (то же, что для автопилота): игровые функции и конфиг — аргументы,
-- _G.GRND_QR / _G.PLAYER_PED — глобальные стабы. Гоняем:
--   * чистую логику RT.fn (дистанция, скан: сортировка/граница/интерьер,
--     заполнение шаблона {id}/{ник}/{дист}, % без поломок);
--   * живой скан по стабам MoonLoader (включая игрока вне стрима);
--   * радиус: смена ±, клип 1..200, сохранение/загрузка конфига;
--   * выдачу: «команда ещё не назначена» (честно, без выдуманных команд),
--     шаблон с {id} — по игроку, без {id} — одна строка на всех,
--     пустой радиус, падение отправки, нет подключения;
--   * страницу RT.page на стаб-рендерере (кнопки, шестерёнки, радиус,
--     статус, «−»/«+» по клику, «Было: …», y растёт).
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
local ids = {}
for i = 1, #list do ids[i] = list[i].id end
check(#list == 3, "скан: 3 игрока (30 м за границей, себя не берём)")
check(table.concat(ids, ",") == "7,4,2",
    "скан: порядок " .. table.concat(ids, ","))
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

-- новый экземпляр читает конфиг
resetCfg("radius=63\n")
local RT2 = assert(mkModule()(unpack(mkStubs())))
RT2.load()
check(RT2.radius == 63, "конфиг: radius=63 загружен")

-- ---------- выдача ----------
RT.setRadius(25) -- в радиусе: 7, 4, 2
local before = #sent
check(RT.doAction("weapon") == false and #sent == before,
    "выдача без команды: чат не трогаем")
local lastToast = toasts[#toasts]
check(lastToast and lastToast.text:find("ещё не назначена", 1, true),
    "выдача без команды: тост «ещё не назначена»")
check(RT.lastAct and RT.lastAct:find("команда не назначена", 1, true),
    "«Было:» — команда не назначена")
check(RT.lastAct:find("в радиусе 3", 1, true),
    "«Было:» видно, сколько было в радиусе")

RT.cmds.spawn = "/spawn {id} {ник}"
before = #sent
check(RT.doAction("spawn") == true and #sent - before == 3,
    "шаблон {id}: 3 команды по игрокам")
check(sent[#sent - 2] == "/spawn 7 Nick7"
    and sent[#sent - 1] == "/spawn 4 Nick4"
    and sent[#sent] == "/spawn 2 Nick2",
    "шаблон {id}: порядок и подстановки: " .. table.concat(sent, " | "))
check(RT.lastAct and RT.lastAct:find("3/3", 1, true), "«Было:» 3/3")
lastToast = toasts[#toasts]
check(lastToast and lastToast.kind == "ok", "успех: тост ok")

RT.cmds.freeze = "/freezeall"
before = #sent
RT.doAction("freeze")
check(#sent - before == 1 and sent[#sent] == "/freezeall",
    "без {id}: одна команда на всех")

RT.cmds.tpself = "/tp {id} {дист}"
before = #sent
RT.doAction("tpself")
check(#sent - before == 3, "tpself: на всех в радиусе")
check(sent[#sent] == "/tp 2 20", "tpself: {дист} целыми метрами")

RT.setRadius(1)
RT.doAction("spawn")
check(RT.lastAct and RT.lastAct:find("в радиусе никого", 1, true),
    "пустой радиус: «никого»")
lastToast = toasts[#toasts]
check(lastToast and lastToast.text:find("никого", 1, true),
    "пустой радиус: тост «никого»")

RT.setRadius(25)
qr.sendChat = function() return false end
check(RT.doAction("spawn") == false, "отправка упала: false")
check(RT.lastAct and RT.lastAct:find("0/3", 1, true),
    "«Было:» 0/3 при падении")
lastToast = toasts[#toasts]
check(lastToast and lastToast.kind == "warn", "падение: тост warn")
qr.sendChat = function(t) table.insert(sent, t) return true end

-- нет подключения: sampIsPlayerConnected не функция (4-й аргумент = nil)
local stubs3 = mkStubs()
stubs3[4] = nil
local RT3 = assert(mkModule()(unpack(stubs3, 1, 10)))
check(RT3.scan() == nil and tostring(RT3.err):find("SAMP", 1, true),
    "нет подключения: scan nil + err")
before = #sent
RT3.doAction("spawn")
check(#sent == before, "нет подключения: чат не трогаем")

-- ---------- страница RT.page на стаб-рендерере ----------
local drawn, clicks, gears, sliders = {}, {}, {}, {}
local function mkR(allow)
    allow = allow or {}
    return {
        uiText = function(x, y, t) table.insert(drawn, { x = x, t = t }) end,
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
        button = function(key, x, y, w, h, label)
            table.insert(clicks, { key = key, x = x, y = y,
                w = w, h = h, label = label })
            return allow[key] == true
        end,
        slider = function(id, x, y, w, h, ratio)
            table.insert(sliders, { id = id, ratio = ratio })
            return allow.slider or nil
        end,
        gearButton = function(key, x, y, active)
            table.insert(gears, { key = key, x = x, y = y })
            return allow[key] == true
        end,
        gear = function(x, y, col)
            table.insert(gears, { key = "static", x = x, y = y })
        end,
    }
end

local cw, y0 = 320, 40
RT.setRadius(25)
RT.lastAct = "spawn: 3/3 (Nick7, Nick4, Nick2)"
drawn, clicks, gears = {}, {}, {}
local y1 = RT.page(mkR(), 10, y0, cw)
check(type(y1) == "number" and y1 > y0, "page: y растёт")
check(#clicks == 12,
    "page: 12 кнопок (−, +, 9 сетки, tp; шестерёнки — без подложки): "
    .. #clicks)
check(clicks[1] and clicks[1].key == "rt_minus" and clicks[1].w == 26,
    "page: «−» слева 26×26")
check(clicks[2] and clicks[2].key == "rt_plus", "page: «+»")
-- порядок сетки 3×3 (шестерёнки — не кнопки, а значки кликовой зоны)
local expect = {
    "rt_act_spawn", "rt_act_freeze", "rt_act_unfreeze",
    "rt_act_weapon", "rt_act_skin", "rt_act_xp",
    "rt_act_armor", "rt_act_vehicle", "rt_act_takeoff",
}
local orderOk = true
for i = 1, #expect do
    if clicks[2 + i] == nil or clicks[2 + i].key ~= expect[i] then
        orderOk = false
    end
end
check(orderOk, "page: сетка 3×3 в порядке макета")
check(clicks[12] and clicks[12].key == "rt_tp" and clicks[12].w == cw
    and clicks[12].label == "Телепорт всех к себе",
    "page: широкая «Телепорт всех к себе» на всю ширину")
-- отступ: широкая кнопка чётко НИЖЕ сетки (последний ряд кончается на
-- y0+4+26+10+94; кнопка — ещё через 12 px)
local gridEnd = y0 + 4 + 26 + 10 + 3 * (26 + 8) - 8
check(clicks[12] and clicks[12].y >= gridEnd + 12 - 0.01
    and clicks[12].y <= gridEnd + 20,
    "page: «Телепорт» сдвинут ниже сетки (y="
    .. tostring(clicks[12] and clicks[12].y) .. ")")
-- ровная сетка: все 9 кнопок одной ширины
local actIdx = {}
for i = 3, 11 do actIdx[#actIdx + 1] = i end
local bw0 = clicks[actIdx[1]] and clicks[actIdx[1]].w
local evenOk = bw0 and bw0 > 40
for i = 1, #actIdx do
    if clicks[actIdx[i]] == nil
        or math.abs(clicks[actIdx[i]].w - bw0) > 0.01 then
        evenOk = false
    end
end
check(evenOk, "page: все 9 кнопок одной ширины")
-- шестерёнки: БЕЗ подложки (не в списке кнопок), значок за краем кнопки
local gearKeys = {}
for i = 1, #gears do gearKeys[i] = gears[i].key end
check(table.concat(gearKeys, ",")
    == "rt_gear_weapon,rt_gear_skin,rt_gear_armor,rt_gear_vehicle",
    "page: 4 шестерёнки без подложки: " .. table.concat(gearKeys, ","))
local gearBtnIdx = { 6, 7, 9, 10 } -- weapon, skin, armor, vehicle
local gearOut = true
for i = 1, 4 do
    local btn, ic = clicks[gearBtnIdx[i]], gears[i]
    if btn == nil or ic == nil
        or math.abs(ic.x - (btn.x + btn.w + 23)) > 0.01
        or math.abs(ic.y - (btn.y + 13)) > 0.01 then
        gearOut = false
    end
end
check(gearOut, "page: значок шестерёнки за краем своей кнопки")
local joined = {}
for i = 1, #drawn do joined[i] = drawn[i].t end
joined = table.concat(joined, "\n")
check(joined:find("Радиус: 25", 1, true), "page: строка «Радиус: 25»")
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

-- клик по шестерёнке: честно — настройка появится вместе с командой
local beforeT = #toasts
RT.page(mkR({ rt_gear_weapon = true }), 10, y0, cw)
lastToast = toasts[#toasts]
check(#toasts == beforeT + 1
    and lastToast.text:find("настройка появится вместе с командой", 1, true),
    "page: клик шестерёнки → честный тост")
check(RT.lastAct and RT.lastAct:find("Выдать оружие", 1, true),
    "page: «Было:» — клик по шестерёнке")

-- защита: мусорный рендерер не роняет страницу
check(RT.page(nil, 0, 0, 100) == 0, "page: R=nil → y")
check(RT.page({}, 0, 0, 100) == 0, "page: R без button → y")

-- тик
RT.visible = true
check(pcall(_G.grndRadTick), "tick: без ошибок при visible")
RT.visible = false
check(pcall(_G.grndRadTick), "tick: без ошибок при visible=false")

if results.fail > 0 then
    print(("--- выдача в радиусе: %d passed, %d failed ---")
        :format(results.pass, results.fail))
    os.exit(1)
end
print(("--- выдача в радиусе: %d/%d ok ---")
    :format(results.pass, results.pass + results.fail))
