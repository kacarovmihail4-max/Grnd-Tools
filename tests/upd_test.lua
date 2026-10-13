-- =====================================================================
--  Стенд автообновления GRND_UPDATE (v1.19.227)
--  Проверяем без игры и без интернета: каналы (api.github.com без кэша и
--  четыре зеркала), сброс кэша зеркал меткой времени, лечение «зеркало
--  отдало прошлую версию», две дороги загрузки (downloadUrlToFile и
--  WinINet), разбор ответа api.github.com (JSON, base64, git/blobs),
--  проверку при заходе в игру, окно изменений и команду /grndupdate.
--  Запуск: luajit tests/run_all.lua (или luajit tests/upd_test.lua).
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
local a1 = assert(src:find("-- >>> GRND_UPDATE_BEGIN"))
local a2 = assert(src:find("-- <<< GRND_UPDATE_END"))
local block = src:sub(a1, a2 - 1)

local V = "1.19.227"       -- текущая версия скрипта
local NEW = "1.19.228"     -- версия в канале
local OLD = "1.19.226"     -- что отдаёт зеркало из кэша

local SCRIPT_PATH = "/game/moonloader/grnd_adm_tools.lua"
local CFG_PATH = "/game/moonloader/grnd_update.cfg"
local LOG_PATH = "/game/moonloader/grnd_update.log"

-- ---------- стабы ----------
_G.grndIsSpawnedSafe = function() return _G.__spawned and true or false end
_G.GRND_SCRIPT_VERSION = V
_G.GRND_QR = { toast = function(text, kind, life)
    table.insert(_G.__toasts, { text = text, kind = kind, life = life })
end }
local reloaded = 0
_G.thisScript = function()
    return {
        path = SCRIPT_PATH,
        reload = function() reloaded = reloaded + 1 return true end,
    }
end
_G.getWorkingDirectory = function() return "/game/moonloader/" end

-- Виртуальная файловая система: стенд подсовывает её модулю через U.io.
local FS = {}
local function stubOpen(path, mode)
    mode = tostring(mode or "r")
    if mode:find("r") then
        local data = FS[path]
        if not data then return nil, tostring(path) .. ": нет файла" end
        local pos = 1
        return {
            read = function(_, how)
                if how == "*a" then
                    local out = data:sub(pos)
                    pos = #data + 1
                    return out
                end
                return nil
            end,
            close = function() return true end,
        }
    end
    local buf = {}
    return {
        write = function(_, ...)
            for i = 1, select("#", ...) do
                buf[#buf + 1] = tostring((select(i, ...)))
            end
            FS[path] = table.concat(buf)
            return true
        end,
        close = function() FS[path] = table.concat(buf) return true end,
    }
end
local logs = {} -- строки, реально попавшие в grnd_update.log
local now = 1000           -- секунды процесса (таймауты загрузки)
local wallNow = 1700000000 -- настенные часы, как os.time() (cfg: last=)
local stubIO = {
    clock  = function() return now end,
    time   = function() return wallNow end,
    open   = function(path, mode)
        if tostring(mode or "r"):find("a") then
            -- диагностика пишется в файл: запоминаем строку
            local pos = #logs
            return {
                write = function(_, ...)
                    for i = 1, select("#", ...) do
                        logs[#logs + 1] = tostring((select(i, ...)))
                    end
                    return true
                end,
                close = function() return true end,
            }
        end
        local f, err = stubOpen(path, mode)
        -- дописывание поверх существующего файла
        if f and tostring(mode or ""):find("a") and FS[path] then
            local base = FS[path]
            local inner = f
            f = {
                write = function(_, ...)
                    for i = 1, select("#", ...) do
                        base = base .. tostring((select(i, ...)))
                    end
                    FS[path] = base
                    return true
                end,
                close = function() FS[path] = base return true end,
            }
        end
        return f, err
    end,
    remove = function(path) FS[path] = nil return true end,
    rename = function(from, to)
        if not FS[from] then return nil, "нет файла" end
        FS[to], FS[from] = FS[from], nil
        return true
    end,
    exists = function(path) return FS[path] ~= nil end,
}

-- Загрузка по-мунлоадерски: пишем в очередь и отдаём колбэк наружу.
local downloads = {}
local function downloadStub(url, path, cb)
    downloads[#downloads + 1] = { url = url, path = path, cb = cb }
    return #downloads
end

-- Запасная дорога: поддельный wininet. Тело задаётся планом (url → строка).
local plan, inetLog = nil, nil
local function inetBackend()
    local ffi = require("ffi")
    local w = {}
    w.InternetOpenA = function() inetLog.open = (inetLog.open or 0) + 1
        return {} end
    w.InternetSetOptionA = function() return 1 end
    w.InternetOpenUrlA = function(_, url, hdr, hlen)
        inetLog.urls[#inetLog.urls + 1] = url
        inetLog.headers = tostring(hdr or "")
        local body = plan and plan[url]
        if type(body) == "function" then body = body(hdr) end
        if not body then return nil end
        return { url = url, body = body, pos = 1 }
    end
    w.HttpQueryInfoA = function(req, _, buf)
        buf[0] = tonumber(req.http) or 200
        return 1
    end
    w.InternetReadFile = function(req, buf, want, got)
        local left = #req.body - (req.pos - 1)
        local n = math.min(left, 4096, want)
        if n > 0 then
            ffi.copy(buf, req.body:sub(req.pos, req.pos + n - 1), n)
            req.pos = req.pos + n
        else
            inetLog.eof = (inetLog.eof or 0) + 1
        end
        got[0] = n
        return 1
    end
    w.InternetCloseHandle = function() inetLog.closed = (inetLog.closed or 0) + 1
        return 1 end
    return { w = w, ffi = ffi }
end

local mkModule = assert(load("return function()\n" .. block
    .. "\n    return _G.GRND_UPDATE\nend", "@upd_test"))
local U = mkModule()()
local realSpawned = U.spawned -- стенд подменяет его в одном сценарии

-- Модуль определяет транспорт сам — подменяем на стабы.
U.moonDl = downloadStub
U.inetLoad = function() return nil end -- WinINet «недоступен» по умолчанию
U.io = stubIO

-- В стенде свои каналы: настоящие адреса и порядок проверяются по тексту
-- скрипта отдельно.
local CHA  = { id = "api", kind = "api", base = "https://api.test/" }
local CH1  = { id = "raw", base = "https://raw.test/" }
local CH2  = { id = "statically", base = "https://statically.test/" }
local CH3  = { id = "jsdelivr", base = "https://jsdelivr.test/" }

local function resetU()
    FS = {}
    FS[SCRIPT_PATH] = "-- старый скрипт\n"
    _G.__toasts = {}
    _G.__spawned = false
    downloads = {}
    logs = {}
    reloaded = 0
    now = 1000
    wallNow = 1700000000
    plan, inetLog = {}, { urls = {} }
    U.io = stubIO
    U.CHANNELS = { CHA, CH1, CH2, CH3 }
    U.moonDl = downloadStub
    U.inet, U.inetErr = nil, nil
    U.inetLoad = function() return nil end -- WinINet «недоступен» по умолчанию
    U.state, U.err = "idle", nil
    U.job, U.newVer, U.notes, U.installed = nil, nil, nil, false
    U.window, U.probeLines, U.probing = false, nil, false
    U.staleSeen = nil
    U.lastAt, U.wasSpawn = 0, false
    U.cfgLoaded, U.auto, U.period = false, true, 0
    U.reloadPending, U.failOnceShown = false, false
    U.activeId, U.order, U.orderPos, U.phase = nil, nil, 0, nil
    U.checkReason, U.sessionAt, U.didSessionCheck = nil, 0, false
    U.logs = {}
end
resetU()

-- ---------- помощники стенда ----------
local function toasts() return _G.__toasts or {} end
local function hasToast(fragment)
    for _, t in ipairs(toasts()) do
        if tostring(t.text):find(fragment, 1, true) then return true end
    end
    return false
end
local function countToasts(fragment)
    local n = 0
    for _, t in ipairs(toasts()) do
        if tostring(t.text):find(fragment, 1, true) then n = n + 1 end
    end
    return n
end
local function dl(i) assert(downloads[i], "нет загрузки #" .. i) return downloads[i] end
local function succeed(i, body)
    local d = dl(i)
    FS[d.path] = body
    d.cb(i, U.ST_OK)
end
local function failDl(i, status) dl(i).cb(i, status or 4) end
local function logText() return table.concat(logs, "\n") end
local function newBody(ver, mark, big)
    local filler = "-- " .. string.rep("f", 400) .. "\n"
    local body = table.concat({
        'script_name("grnd_adm_tools")',
        'GRND_SCRIPT_VERSION = "' .. ver .. '"',
        "-- v" .. ver .. " — ТЕСТ: " .. mark .. ":",
        "--   1) проверяемое изменение.",
    }, "\n") .. "\n"
    if big == nil or big then body = body .. string.rep(filler, 260) end
    return body
end
local function b64(s)
    local abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local out = {}
    local i = 1
    while i <= #s do
        local a, b, c = s:byte(i), s:byte(i + 1), s:byte(i + 2)
        local n1, n2, n3, n4 = math.floor((a or 0) / 4), nil, nil, nil
        local rest = (a or 0) % 4
        local b1 = b or 0
        local c1 = c or 0
        n2 = rest * 16 + math.floor(b1 / 16)
        n3 = (b1 % 16) * 4 + math.floor(c1 / 64)
        n4 = c1 % 64
        out[#out + 1] = abc:sub(n1 + 1, n1 + 1)
        out[#out + 1] = abc:sub(n2 + 1, n2 + 1)
        out[#out + 1] = b and abc:sub(n3 + 1, n3 + 1) or "="
        out[#out + 1] = c and abc:sub(n4 + 1, n4 + 1) or "="
        i = i + 3
    end
    return table.concat(out)
end
-- Ответ api.github.com: файл маленький — содержимое внутри JSON
-- (перевод строки в base64 GitHub отдаёт экранированным, как \n)
local function apiJson(body, sha)
    return '{"name":"x","path":"x","sha":"' .. (sha or "deadbeef")
        .. '","encoding":"base64","content":"' .. b64(body):gsub("\n", "\\n")
        .. '"}'
end
-- то же самое, но как настоящий ответ GitHub: base64 разбит на строки по 60
local function apiJsonBrokenLines(body)
    local one = b64(body)
    local lines = {}
    for i = 1, #one, 60 do lines[#lines + 1] = one:sub(i, i + 59) end
    return '{"sha":"deadbeef","encoding":"base64","content":"'
        .. table.concat(lines, "\\n") .. '"}'
end
-- Тот же ответ, но для файла больше мегабайта: содержимого нет, только sha
local function apiJsonBig(sha)
    return '{"name":"x","path":"x","size":2778297,"sha":"' .. sha
        .. '","encoding":"none"}'
end
-- git/blobs: содержимое в base64, разбитое на строки по 60 (как у GitHub)
local function blobJson(body)
    local one = b64(body)
    local lines = {}
    for i = 1, #one, 60 do lines[#lines + 1] = one:sub(i, i + 59) end
    return '{"sha":"x","encoding":"base64","content":"'
        .. table.concat(lines, "\\n") .. '"}'
end

-- ---------- 1. начальное состояние ----------
check(U.cur == V, "старт: текущая версия из шапки")
check(U.state == "idle" and U.window == false, "старт: состояние idle, окно закрыто")
check(#U.CHANNELS == 4, "канал: четыре канала в стабе")
-- боевой порядок каналов из самого скрипта (стаб подменяет список, поэтому
-- смотрим на текст блока): первым — api.github.com (без кэша), последним —
-- jsDelivr (он держит файл в кэше до 12 часов)
local startAt = block:find("U.CHANNELS = {", 1, true)
local orderRaw = ""
if startAt then
    orderRaw = block:sub(startAt, startAt + 1500)
    local stop = orderRaw:find("\n    }", 1, true)
    if stop then orderRaw = orderRaw:sub(1, stop) end
end
check(startAt ~= nil, "канал: список каналов найден в тексте")
if startAt then
    local ids = {}
    for id in orderRaw:gmatch('id = "([%w%-]+)"') do ids[#ids + 1] = id end
    check(#ids == 5, "канал: пять каналов")
    check(ids[1] == "api", "канал: первым — api.github.com (без кэша)")
    check(ids[2] == "statically" and ids[3] == "githack",
        "канал: потом зеркала на Cloudflare")
    check(ids[4] == "raw", "канал: канонический raw после зеркал")
    check(table.concat(ids, ",") == "api,statically,githack,raw,jsdelivr",
        "канал: порядок api, statically, githack, raw, jsdelivr")
end
check(block:find("application/vnd.github.raw", 1, true) ~= nil,
    "канал: api запрашивает сам файл (Accept: raw)")
check(type(U.b64decode) == "function" and type(U.jsonField) == "function",
    "канал: есть разбор ответа api (JSON и base64)")
check(type(U.spawned) == "function" and type(U.probe) == "function",
    "модуль: API на месте")

-- версии сравниваются как числа
check(U.verNum("1.19.9") < U.verNum("1.19.10"), "версии: 1.19.9 < 1.19.10")
check(U.verNum("1.19.10") < U.verNum("1.19.100"), "версии: 1.19.10 < 1.19.100")
check(U.verNum("1.9.999") < U.verNum("1.19.0"), "версии: 1.9.999 < 1.19.0")
check(U.verNum(nil) == 0, "версии: мусор → 0")

-- base64: маленькое и с «хвостом» (проверяем на своём же кодировщике стенда)
local samples = { "", "a", "ab", "abc", "abcd", "версия 1.19.228", newBody("1.19.228", "b64") }
local b64ok = true
for i = 1, #samples do
    if U.b64decode(b64(samples[i])) ~= samples[i] then b64ok = false end
end
check(b64ok, "base64: декодер совпадает с кодировщиком (в т.ч. кириллица)")
check(U.jsonField('{"sha":"abc123","content":"Zm9v"}', "content") == "Zm9v",
    "JSON: поле content вынимается")
check(U.jsonField('{"sha":"abc123"}', "content") == nil,
    "JSON: нет поля — nil")
-- base64 с экранированными переводами строк (как отдаёт GitHub) и «хвостом»
local nb = newBody(NEW, "многострочный ответ")
local oneLine = apiJsonBrokenLines(nb)
check(U.b64decode(U.jsonField(oneLine, "content")) == nb,
    "JSON: содержимое со строками по 60 расшифровывается верно")
check(U.b64decode("MS4xOS4yMjc=\\n") == "1.19.227",
    "JSON: экранированный хвост не добавляет мусорных байтов")

-- метка времени в адресе зеркала: кэш CDN считает строку запроса
local q1 = U.bustQ()
check(type(q1) == "string" and q1:find("?v=", 1, true) == 1,
    "кэш: к адресу зеркала добавляется метка времени")
wallNow = wallNow + 120
check(U.bustQ() ~= q1, "кэш: метка меняется со временем")
wallNow = 1700000000

-- ---------- 2. разбор списка изменений ----------
local head = table.concat({
    'script_name("grnd_adm_tools")',
    'GRND_SCRIPT_VERSION = "' .. NEW .. '"',
    "-- v" .. NEW .. " — ТЕСТ: свежая правка:",
    "--   1) первое изменение;",
    "--   2) второе изменение.",
    "-- v" .. V .. " — прошлая версия:",
    "--   1) это уже наше, в список попасть не должно.",
}, "\n")
local notes = U.changelogOf(head)
check(#notes == 1, "changelog: только версии новее текущей")
check(notes[1] and notes[1].ver == NEW, "changelog: версия в первой записи")
local joined = notes[1] and table.concat(notes[1].lines, "|") or ""
check(joined:find("ТЕСТ: свежая правка", 1, true) ~= nil, "changelog: заголовок")
check(joined:find("первое изменение", 1, true) ~= nil, "changelog: строки 1")
check(joined:find("второе изменение", 1, true) ~= nil, "changelog: строки 2")
check(joined:find("наше", 1, true) == nil, "changelog: своя версия не попала")
check(#U.changelogOf(nil) == 0, "changelog: nil → пусто")

-- ---------- 3. источники спавна ----------
resetU()
_G.grndIsSpawnedSafe = nil
_G.sampIsLocalPlayerSpawned = function() return true end
check(U.spawned() == true, "спавн: sampIsLocalPlayerSpawned, если основной нет")
_G.sampIsLocalPlayerSpawned = function() error("сломана") end
_G.GRND_KEYS = { spawnedNow = true }
check(U.spawned() == true, "спавн: GRND_KEYS.spawnedNow как последний источник")
_G.GRND_KEYS = nil
_G.sampIsLocalPlayerSpawned = nil
_G.grndIsSpawnedSafe = function() return _G.__spawned and true or false end
check(U.spawned() == false, "спавн: ничего не работает → false")

-- ---------- 4. первый канал — api.github.com ----------
resetU()
check(U.check("manual"), "проверка: запустилась")
check(U.state == "checking", "проверка: состояние checking")
check(hasToast("Проверяю обновления"), "проверка: тост «Проверяю обновления…»")
check(#downloads == 1, "проверка: одна загрузка")
check(dl(1).url:find("https://api.test/contents/update.txt?ref=grnd-latest", 1, true) ~= nil,
    "api: файл версии берётся из Contents API по метке")
succeed(1, apiJson(V .. "\n"))
U.tick()
check(U.state == "uptodate", "та же версия: состояние uptodate")
check(hasToast("Версия " .. V .. " — последняя"), "та же версия: тост про последнюю")
check(#downloads == 1, "та же версия: файл скрипта не качается")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "та же версия: файл цел")
check(U.activeId == "api", "та же версия: канал запомнен")
check((FS[CFG_PATH] or ""):find("channel=api", 1, true) ~= nil,
    "конфиг: канал сохранён")
check(U.window == true, "ручная проверка: окно открыто")
check(logText():find("api: версия " .. V, 1, true) ~= nil,
    "диагностика: пишется в файл (в окне её нет)")

-- ---------- 5. новая версия через api: JSON → git/blobs ----------
resetU()
U.check("manual")
succeed(1, apiJson(NEW))
U.tick()
check(U.state == "downloading", "новее: состояние downloading")
check(U.newVer == NEW, "новее: версия запомнена")
check(hasToast("Обновляюсь до версии " .. NEW), "новее: тост про обновление")
check(#downloads == 2, "новее: пошла загрузка самого скрипта")
check(dl(2).url:find("contents/grnd_adm_tools.lua?ref=grnd-latest", 1, true) ~= nil,
    "новее: файл скрипта берётся из Contents API")
check(dl(2).path == SCRIPT_PATH .. ".new", "новее: качаем в .new рядом")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "новее: рабочий файл пока не тронут")

-- у файла больше мегабайта содержимого в JSON нет — только sha
succeed(2, apiJsonBig("cafe1234"))
U.tick()
check(#downloads == 3, "большой файл: идём за git/blobs по sha")
check(dl(3).url:find("git/blobs/cafe1234", 1, true) ~= nil,
    "большой файл: адрес git/blobs с sha")
succeed(3, blobJson(newBody(NEW, "установка прошла")))
U.tick()
check(U.state == "ready", "установка: состояние ready")
check(U.installed == true, "установка: флаг installed")
check(U.window == true, "установка: окно со списком изменений открыто")
check(hasToast("Обновление " .. NEW .. " установлено"), "установка: тост об установке")
check(FS[SCRIPT_PATH]:find('GRND_SCRIPT_VERSION = "' .. NEW .. '"', 1, true) ~= nil,
    "установка: новый файл встал на место")
check(FS[SCRIPT_PATH .. ".bak"] == "-- старый скрипт\n", "установка: старый — в .bak")
check(FS[SCRIPT_PATH .. ".new"] == nil, "установка: .new больше нет")
check(#(U.notes or {}) == 1, "установка: список изменений разобран")

-- ---------- 6. исполнение по тексту: адреса зеркал ----------
resetU()
U.CHANNELS = { CH2, CH3 }
U.check("manual")
check(dl(1).url:find("https://statically.test/update.txt?v=", 1, true) ~= nil,
    "зеркало: к адресу добавлена метка времени (кэш не подсовывается)")
succeed(1, V .. "\n")
U.tick()
check((FS[CFG_PATH] or ""):find("channel=statically", 1, true) ~= nil,
    "зеркало: ответившее запоминается в конфиге")

-- ---------- 7. зеркало отдало прошлую версию ----------
-- только зеркала, все со старым файлом из кэша → это НЕ «нет связи»
resetU()
U.CHANNELS = { CH2, CH3 }
U.check("manual")
succeed(1, OLD)          -- statically: файл из кэша
U.tick()
check(#downloads == 2, "кэш: после старой версии идём к следующему каналу")
succeed(2, OLD)          -- jsdelivr: тоже старый (кэш 12 часов)
U.tick()
check(U.state == "uptodate", "кэш: всех обошли — считаем, что версия свежая")
check(hasToast("Версия " .. V .. " — последняя"), "кэш: говорим «последняя»")
check(not hasToast("нет связи"), "кэш: про «нет связи» не пугаем")
check(logText():find("файл из кэша", 1, true) ~= nil,
    "кэш: причина видна в диагностике (файл)")

-- зеркало старое, а api отвечает свежим — обновление всё равно пошло
resetU()
U.CHANNELS = { CH2, CHA }
U.check("manual")
succeed(1, OLD)
U.tick()
check(#downloads == 2, "кэш: зеркало со старым файлом не ломает проверку")
succeed(2, apiJson(NEW))
U.tick()
check(U.newVer == NEW and U.state == "downloading",
    "кэш: свежий номер с api — обновляемся")
check(hasToast("Обновляюсь до версии " .. NEW), "кэш: тост про обновление")

-- ---------- 8. сеть пропала ----------
resetU()
U.check("manual")
failDl(1, 4) U.tick()
check(#downloads == 2, "обрыв: пробуем следующий канал")
failDl(2, 4) U.tick()
failDl(3, 4) U.tick()
failDl(4, 4) U.tick()
check(U.state == "error", "обрыв: состояние error")
check(hasToast("нет связи"), "обрыв: ручная проверка говорит всегда")

-- на заходе про обрыв — один тост за сессию
resetU()
U.check("spawn")
failDl(1, 4) U.tick() failDl(2, 4) U.tick()
failDl(3, 4) U.tick() failDl(4, 4) U.tick()
check(U.state == "error", "спавн без сети: состояние error")
check(countToasts("сервер не отвечает") == 1, "спавн без сети: один тост за сессию")
_G.__spawned = false U.tick() _G.__spawned = true U.tick()
failDl(1, 4) U.tick() failDl(2, 4) U.tick()
failDl(3, 4) U.tick() failDl(4, 4) U.tick()
check(countToasts("сервер не отвечает") == 1, "спавн без сети: второй раз молчим")
check(U.err ~= nil, "спавн без сети: причина сохранена для раздела")

-- таймаут (загрузчик молчит) — сообщаем и идём дальше
resetU()
U.check("manual")
now = now + 20
U.tick()
check(#downloads == 2, "таймаут: молчащий загрузчик — следующий канал")

-- ---------- 9. вторая дорога: WinINet ----------
-- штатный загрузчик молчит → та же ссылка идёт через WinINet
resetU()
U.inetLoad = inetBackend
plan["https://api.test/contents/update.txt?ref=grnd-latest"] = V .. "\n"
U.check("manual")
now = now + 20
U.tick()
check(#inetLog.urls >= 1, "мост: молчащий MoonLoader → WinINet")
local guard = 0
while U.state == "checking" and guard < 200 do U.tick() guard = guard + 1 end
check(U.state == "uptodate", "мост: WinINet дочитал версию")
check(inetLog.eof and inetLog.eof >= 1, "мост: поток дочитан до конца")
check(inetLog.closed and inetLog.closed >= 1, "мост: соединение закрыто")

-- WinINet как единственная дорога (downloadUrlToFile в сборке нет)
resetU()
U.inetLoad = inetBackend
U.moonDl = nil
plan["https://api.test/contents/update.txt?ref=grnd-latest"] = V .. "\n"
U.check("manual")
check(U.state == "checking", "WinINet: проверка идёт без штатного загрузчика")
guard = 0
while U.state ~= "uptodate" and guard < 300 do U.tick() guard = guard + 1 end
check(U.state == "uptodate", "WinINet: версия прочитана")
check(inetLog.headers ~= nil, "WinINet: заголовки запроса передаются")

-- WinINet забирает и сам файл скрипта (JSON → git/blobs → установка)
resetU()
U.inetLoad = inetBackend
U.moonDl = nil
plan["https://api.test/contents/update.txt?ref=grnd-latest"] = apiJson(NEW)
plan["https://api.test/contents/grnd_adm_tools.lua?ref=grnd-latest"] = apiJsonBig("beef")
plan["https://api.test/git/blobs/beef"] = blobJson(newBody(NEW, "через WinINet"))
U.check("manual")
guard = 0
while U.state ~= "ready" and guard < 800 do U.tick() guard = guard + 1 end
check(U.state == "ready", "WinINet: файл скачан и установлен")
check(FS[SCRIPT_PATH]:find('GRND_SCRIPT_VERSION = "' .. NEW .. '"', 1, true) ~= nil,
    "WinINet: новый файл на месте")
check(FS[SCRIPT_PATH .. ".bak"] ~= nil, "WinINet: бэкап сделан")

-- ---------- 10. проверка содержимого ----------
-- короткий ответ, не наша версия, битый файл — рабочий файл ЦЕЛ
resetU()
U.CHANNELS = { CH1 }
U.check("manual")
succeed(1, NEW)
U.tick()
succeed(2, "короткий ответ, это не скрипт")
U.tick()
check(U.state == "error", "битый файл: состояние error")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "битый файл: рабочий файл цел")
check(FS[SCRIPT_PATH .. ".new"] == nil, "битый файл: .new убран")
check(not hasToast("установлено"), "битый файл: про установку не сообщаем")

-- файл с ДРУГОЙ версией внутри — тоже не ставим
resetU()
U.CHANNELS = { CH1 }
U.check("manual")
succeed(1, NEW)
U.tick()
succeed(2, newBody("1.19.200", "чужой файл"))
U.tick()
check(U.state == "error", "чужая версия: не ставим")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "чужая версия: файл цел")

-- штатная установка (не api, зеркало) — для полноты
resetU()
U.CHANNELS = { CH1 }
U.check("manual")
succeed(1, NEW)
U.tick()
succeed(2, newBody(NEW, "обычная установка"))
U.tick()
check(U.state == "ready" and U.installed, "зеркало: обычная установка прошла")
check(#(U.notes or {}) == 1, "зеркало: изменения разобраны")

-- ---------- 11. заход в игру ----------
-- проверка при КАЖДОМ заходе + тост
resetU()
_G.__spawned = true
U.tick()
check(U.state == "checking", "спавн: проверка запустилась")
check(hasToast("Проверяю обновления"), "спавн: тост «Проверяю обновления…»")
succeed(1, V .. "\n")
U.tick()
check(U.state == "uptodate", "спавн: проверка завершилась")
check(not hasToast("последняя"), "спавн: про «последнюю версию» молчим")

-- следующий заход (через полминуты) — проверяем снова
wallNow = wallNow + 30
_G.__spawned = false U.tick() _G.__spawned = true U.tick()
check(#downloads == 2, "спавн: следующий заход снова проверяет")
succeed(2, V .. "\n")
U.tick()
-- а дребезг флага спавна (в пределах 20 с) второй раз не дёргает
_G.__spawned = false U.tick() _G.__spawned = true U.tick()
check(#downloads == 2, "спавн: в пределах 20 с второй раз не дёргаем")
wallNow = wallNow + 30
_G.__spawned = false U.tick() _G.__spawned = true U.tick()
check(#downloads == 3, "спавн: через полминуты — снова проверка")

-- period: реже, если задан
resetU()
FS[CFG_PATH] = "auto=1\nperiod=10800\nlast=0\n"
_G.__spawned = true
U.tick()
check(U.state == "checking", "period=10800: первый заход проверяет")
succeed(1, V .. "\n")
U.tick()
_G.__spawned = false U.tick() _G.__spawned = true U.tick()
check(U.state == "uptodate", "period=10800: второй заход молчит")

-- страховка: спавн не определяется — проверяем через 25 с после запуска
resetU()
U.didSessionCheck, U.sessionAt = false, wallNow
U.spawned = function() return false end
now = now + 5
U.tick()
check(U.state == "idle", "страховка: раньше 25 с не проверяем")
wallNow = wallNow + 26
U.tick()
check(U.state == "checking", "страховка: через 25 с проверка всё равно идёт")
check(U.didSessionCheck == true, "страховка: второй раз не повторяем")
U.spawned = realSpawned -- возвращаем настоящий определитель спавна
U.job = nil

-- авто-проверка выключается
resetU()
FS[CFG_PATH] = "auto=0\nperiod=0\nlast=0\n"
_G.__spawned = true
U.tick()
check(#downloads == 0, "auto=0: при заходе не проверяем")
check(U.auto == false, "auto=0: настройка прочитана")

-- ---------- 12. обход каналов («/grndupdate test») ----------
resetU()
U.probe()
check(U.probing == true, "проба: режим включён")
check(hasToast("Проверяю каналы"), "проба: тост")
succeed(1, V .. "\n")
U.tick()
check(#downloads == 2, "проба: после первого канала идём ко второму")
succeed(2, V .. "\n")
U.tick()
failDl(3, 4)
U.tick()
failDl(4, 4)
U.tick()
check(U.probing == false, "проба: закончилась")
check(U.window == true, "проба: окно открыто")
check(#U.probeLines == 8, "проба: по строке на канал (пробую + ответ)")
check(table.concat(U.probeLines, "|"):find("api: версия " .. V, 1, true) ~= nil,
    "проба: у ответившего канала видна версия")
check(table.concat(U.probeLines, "|"):find("jsdelivr: статус 4", 1, true) ~= nil,
    "проба: у упавшего канала видна причина")

-- ---------- 13. окно ----------
resetU()
local function mkIm()
    local im = { texts = {}, buttons = {}, clicked = {}, children = 0 }
    im.ImVec2 = function(x, y) return { x = x, y = y } end
    im.ImVec4 = function(a, b, c, d) return { a, b, c, d } end
    im.Cond = { FirstUseEver = 4, Appearing = 1 }
    im.Begin = function(name) im.began = name return true end
    im.End = function() im.ended = (im.ended or 0) + 1 end
    im.SetNextWindowSize = function() end
    im.SetNextWindowPos = function() end
    im.Text = function(s) im.texts[#im.texts + 1] = tostring(s) end
    im.TextWrapped = im.Text
    im.TextColored = function(c, s) im.texts[#im.texts + 1] = tostring(s) end
    im.Separator = function() end
    im.BeginChild = function() im.children = im.children + 1 return true end
    im.EndChild = function() im.children = im.children - 1 end
    im.Button = function(label)
        im.buttons[#im.buttons + 1] = label
        return im.clicked[label] and true or false
    end
    return im
end
local function mkCtx(im)
    return { im = im, begin = function(name) return im.Begin(name) end,
        wf = function() return 0 end, always = 1,
        endWin = function() im.End() end }
end
check(U.draw(mkCtx(mkIm())) == false, "окно: закрыто — не рисуется")

U.check("manual")
succeed(1, apiJson(NEW))
U.tick()
succeed(2, blobJson(newBody(NEW, "в окне видно")))
U.tick()
check(U.window == true, "окно: открылось после установки")
local im = mkIm()
check(U.draw(mkCtx(im)) == true, "окно: нарисовалось")
check(im.began and im.began:find("АВТООБНОВЛЕНИЕ", 1, true) ~= nil,
    "окно: заголовок «АВТООБНОВЛЕНИЕ»")
check(im.ended == 1, "окно: End вызван один раз")
check(im.children == 0, "окно: все блоки закрыты (EndChild парный)")
local body = table.concat(im.texts, "\n")
check(body:find("ОБНОВЛЕНИЕ СКРИПТА", 1, true) ~= nil, "окно: наш заголовок")
check(body:find("Установлена версия " .. NEW, 1, true) ~= nil, "окно: было/стало")
check(body:find("ЧТО ИЗМЕНИЛОСЬ", 1, true) ~= nil, "окно: подзаголовок изменений")
check(body:find("в окне видно", 1, true) ~= nil, "окно: строка изменений")
check(body:find("v" .. NEW, 1, true) ~= nil, "окно: номер версии в списке")
check(body:find("Диагностика", 1, true) == nil, "окно: диагностики нет")
check(body:find("Канал:", 1, true) == nil, "окно: служебного «Канал:» нет")
check(body:find("grnd_update.log", 1, true) == nil, "окно: про лог не пишем")
local labels = table.concat(im.buttons, "|")
check(labels:find("Перезагрузить скрипт", 1, true) ~= nil, "окно: кнопка перезагрузки")
check(labels:find("Позже", 1, true) ~= nil, "окно: кнопка «Позже»")

im.clicked["Перезагрузить скрипт##grnd_upd_reload"] = true
U.draw(mkCtx(im))
check(U.reloadPending == true, "окно: кнопка перезагрузки ставит просьбу")
check(reloaded == 0, "окно: в кадре скрипт НЕ перезапускается")
U.tick()
check(reloaded == 1, "тик: перезапуск выполнен из главного цикла")
check(U.reloadPending == false, "тик: просьба снята")
check(U.window == false, "окно: после перезагрузки окно закрыто")

-- «уже самая свежая» — окно ручной проверки, кнопки повторной проверки
resetU()
U.window, U.state = true, "uptodate"
local im3 = mkIm()
check(U.draw(mkCtx(im3)) == true, "окно: рисуется и без изменений")
check(table.concat(im3.texts, " "):find("самая свежая версия", 1, true) ~= nil,
    "окно: текст «самая свежая версия»")
local labels3 = table.concat(im3.buttons, "|")
check(labels3:find("Проверить снова", 1, true) ~= nil,
    "окно: кнопка повторной проверки")
check(labels3:find("Проверить каналы", 1, true) ~= nil,
    "окно: кнопка обхода каналов")
check(table.concat(im3.texts, " "):find("Диагностика", 1, true) == nil,
    "окно: служебных логов тут тоже нет")

-- ошибка: короткий текст и никаких логов
resetU()
U.window, U.state, U.err = true, "error", "нет связи ни с одним каналом (4 шт.)"
local im5 = mkIm()
U.draw(mkCtx(im5))
local body5 = table.concat(im5.texts, " ")
check(body5:find("Не удалось проверить", 1, true) ~= nil, "окно: заголовок ошибки")
check(body5:find("проверка идёт", 1, true) ~= nil, "окно: успокоили про заход")
check(body5:find("нет связи ни с одним каналом", 1, true) == nil,
    "окно: техническая причина не показана")

-- режим обхода каналов показывает ответы
resetU()
U.window, U.probeLines = true, { "api: версия " .. V, "statically: статус 4" }
local im4 = mkIm()
U.draw(mkCtx(im4))
check(table.concat(im4.texts, " "):find("statically: статус 4", 1, true) ~= nil,
    "окно: ответы каналов в режиме обхода")
check(table.concat(im4.texts, " "):find("ОТВЕТЫ КАНАЛОВ", 1, true) ~= nil,
    "окно: подзаголовок ответов каналов")

check(U.draw(nil) == false, "окно: ctx=nil → false")
check(U.draw({}) == false, "окно: ctx без begin → false")

-- окно рисуется и без цветов в im (запасной путь)
local plain = { texts = {} }
plain.Begin = function() return true end
plain.Text = function(s) plain.texts[#plain.texts + 1] = tostring(s) end
plain.Separator = function() end
plain.Button = function() return false end
U.window = true
check(U.draw({ im = plain, begin = function() return plain.Begin() end,
    endWin = function() end }) == true, "окно: рисуется и без TextColored")

-- ---------- 14. команда и глобальные обёртки ----------
resetU()
local cmds = {}
_G.sampRegisterChatCommand = function(name, fn) cmds[name] = fn end
local U2 = mkModule()()
check(type(cmds["grndupdate"]) == "function", "команда: /grndupdate есть")
U2.io = stubIO
U2.moonDl = downloadStub
U2.CHANNELS = { CHA, CH1, CH2, CH3 }
U2.inetLoad = function() return nil end
U2.probing, U2.job, U2.cfgLoaded = false, nil, false
U2.window, U2.state = false, "idle"
U2.activeId, U2.order, U2.logs = nil, nil, {}
cmds["grndupdate"]("")
check(U2.state == "checking", "команда: обычный вызов — проверка")
check(hasToast("Проверяю обновления вручную"), "команда: тост ручной проверки")
cmds["grndupdate"]("test")
check(U2.probing == true, "команда: «test» — обход каналов (текущая загрузка отменена)")
check(type(_G.grndUpdTick) == "function", "API: grndUpdTick")
check(pcall(_G.grndUpdTick), "API: grndUpdTick без ошибок")
_G.grndIsSpawnedSafe = function() error("нет функции в игре") end
check(pcall(_G.grndUpdTick), "тик: падение проверки спавна не роняет цикл")
_G.grndIsSpawnedSafe = function() return _G.__spawned and true or false end

if results.fail > 0 then
    print(("--- автообновление: %d passed, %d failed ---")
        :format(results.pass, results.fail))
    os.exit(1)
end
print(("--- автообновление: %d/%d ok ---")
    :format(results.pass, results.pass + results.fail))
