-- =====================================================================
-- Стенд v1.19.226: АВТООБНОВЛЕНИЕ (GRND_UPDATE).
--
-- Блок между якорями GRND_UPDATE_* грузится как функция; диск, сеть и
-- часы подменяются стабами (U.io / U.moonDl / U.inetLoad / U.io.clock),
-- поэтому проверяется вся логика без игры и без интернета:
--   * версии сравниваются как числа (1.19.9 < 1.19.10 < 1.20.0);
--   * заход в игру: несколько источников спавна (grndIsSpawnedSafe,
--     sampIsLocalPlayerSpawned, GRND_KEYS.spawnedNow), а если ни один не
--     работает — проверка через 25 с после запуска скрипта;
--   * зеркала перебираются по очереди, ответившее запоминается в
--     grnd_update.cfg (channel=) и пробуется первым в следующий раз;
--   * две дороги загрузки: штатный downloadUrlToFile и запасной WinINet
--     (в стенде — поддельный wininet, считаем прочитанные куски);
--     молчащий MoonLoader-загрузчик переводит ТУ ЖЕ ссылку на WinINet;
--   * установка атомарна: файл с версией и не меньше 100 КБ → старый в
--     .bak, новый на место; битый/чужой/короткий файл → рабочая версия
--     цела, а зеркало пробуется следующее;
--   * та же версия → «Версия N — последняя», файл скрипта не качается;
--   * таймаут, HTTP-ошибка и обрыв связи — не тупик, а следующий шаг;
--   * диагностика: строки в U.logs и файл grnd_update.log;
--   * про сбой связи — один тост за сессию, ручная проверка говорит всегда;
--   * /grndupdate test обходит все зеркала и открывает окно с ответами;
--   * окно: «было/стало», изменения, диагностика, кнопки.
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

local SCRIPT_PATH = "/game/moonloader/grnd_adm_tools.lua"
local CFG_PATH = "/game/moonloader/grnd_update.cfg"
local LOG_PATH = "/game/moonloader/grnd_update.log"

-- ---------- стабы ----------
_G.grndIsSpawnedSafe = function() return _G.__spawned and true or false end
_G.GRND_SCRIPT_VERSION = "1.19.226"
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

local now = 1000        -- секунды процесса (таймауты загрузки)
local wallNow = 1700000000 -- настенные часы, как os.time() (cfg: last=)
local FS = {}
local function stubOpen(path, mode)
    mode = mode or "r"
    if mode:sub(1, 1) == "r" then
        local data = FS[path]
        if not data then return nil end
        local pos = 1
        return {
            read = function(self, fmt)
                if fmt == "*a" then
                    local d = data:sub(pos); pos = #data + 1; return d
                end
                return nil
            end,
            close = function() return true end,
        }
    end
    local add = (mode:sub(1, 1) == "a")
    local buf = {}
    if add and FS[path] then buf[1] = FS[path] end
    return {
        write = function(self, ...)
            for i = 1, select("#", ...) do
                buf[#buf + 1] = tostring(select(i, ...))
            end
            return self
        end,
        close = function() FS[path] = table.concat(buf) return true end,
    }
end
local stubIO = {
    clock = function() return now end,
    time = function() return wallNow end,
    open = stubOpen,
    remove = function(path) FS[path] = nil return true end,
    rename = function(from, to)
        if not FS[from] then return false end
        FS[to] = FS[from]
        FS[from] = nil
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
    w.InternetOpenUrlA = function(_, url)
        inetLog.urls[#inetLog.urls + 1] = url
        local body = plan and plan[url]
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
U.inetLoad = function() return { w = nil, ffi = nil } and nil or nil end
U.io = stubIO

local CH1 = { id = "raw", base = "https://raw.test/" }
local CH2 = { id = "statically", base = "https://statically.test/" }
local CH3 = { id = "jsdelivr", base = "https://jsdelivr.test/" }

local function resetU()
    FS = {}
    FS[SCRIPT_PATH] = "-- старый скрипт\n"
    _G.__toasts = {}
    _G.__spawned = false
    downloads = {}
    reloaded = 0
    now = 1000
    wallNow = 1700000000
    plan, inetLog = {}, { urls = {} }
    U.io = stubIO
    U.CHANNELS = { CH1, CH2, CH3 }
    U.moonDl = downloadStub
    U.inet, U.inetErr = nil, nil
    U.inetLoad = function() return nil end -- WinINet «недоступен» по умолчанию
    U.state, U.err = "idle", nil
    U.job, U.newVer, U.notes, U.installed = nil, nil, nil, false
    U.window, U.probeLines, U.probing = false, nil, false
    U.lastAt, U.wasSpawn, U.mi = 0, false, 1
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
local function logs() return table.concat(U.logs or {}, "\n") end
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

-- ---------- 1. начальное состояние ----------
check(U.cur == "1.19.226", "старт: текущая версия из шапки")
check(U.state == "idle" and U.window == false, "старт: состояние idle, окно закрыто")
check(#U.CHANNELS == 3, "канал: три зеркала в стабе")
-- боевой порядок зеркал из самого скрипта (стаб подменяет список, поэтому
-- смотрим на текст блока): первым — доступное в РФ, последним — кэширующее
local startAt = block:find("U.CHANNELS = {", 1, true)
local orderRaw = ""
if startAt then
    orderRaw = block:sub(startAt, startAt + 1500)
    local stop = orderRaw:find("\n    }", 1, true)
    if stop then orderRaw = orderRaw:sub(1, stop) end
end
check(startAt ~= nil, "канал: список зеркал найден в тексте")
if startAt then
    local ids = {}
    for id in orderRaw:gmatch('id = "([%w%-]+)"') do ids[#ids + 1] = id end
    check(#ids == 4, "канал: четыре зеркала")
    check(ids[1] == "statically", "канал: первым — cdn.statically.io")
    check(ids[#ids] == "jsdelivr", "канал: последним — jsDelivr (кэш 12 ч)")
    check(ids[2] == "githack" and ids[3] == "raw",
        "канал: githack перед каноническим raw")
end
check(type(U.spawned) == "function" and type(U.probe) == "function",
    "API: функции на месте")
check(U.verNum("1.19.9") < U.verNum("1.19.10"), "версии: 1.19.9 < 1.19.10")
check(U.verNum("1.19.10") < U.verNum("1.19.100"), "версии: 1.19.10 < 1.19.100")
check(U.verNum("1.9.999") < U.verNum("1.19.0"), "версии: 1.9.999 < 1.19.0")
check(U.verNum(nil) == 0, "версии: мусор → 0")

-- ---------- 2. разбор списка изменений ----------
local head = table.concat({
    'script_name("grnd_adm_tools")',
    'GRND_SCRIPT_VERSION = "1.19.227"',
    "-- v1.19.227 — ТЕСТ: свежая правка:",
    "--   1) первое изменение;",
    "--   2) второе изменение.",
    "-- v1.19.226 — прошлая версия:",
    "--   1) это уже наше, в список попасть не должно.",
}, "\n")
local notes = U.changelogOf(head)
check(#notes == 1, "changelog: только версии новее текущей")
check(notes[1] and notes[1].ver == "1.19.227", "changelog: версия в первой записи")
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

-- ---------- 4. «уже последняя» через первое зеркало ----------
resetU()
check(U.check("manual"), "проверка: запустилась")
check(U.state == "checking", "проверка: состояние checking")
check(hasToast("Проверяю обновления"), "проверка: тост «Проверяю обновления…»")
check(#downloads == 1, "проверка: одна загрузка")
check(dl(1).url == CH1.base .. U.VER_FILE, "проверка: первое зеркало — raw")
succeed(1, "1.19.226\n")
U.tick()
check(U.state == "uptodate", "та же версия: состояние uptodate")
check(hasToast("Версия 1.19.226 — последняя"), "та же версия: тост про последнюю")
check(#downloads == 1, "та же версия: файл скрипта не качается")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "та же версия: файл цел")
check(U.activeId == "raw", "та же версия: зеркало запомнено")
check((FS[CFG_PATH] or ""):find("channel=raw", 1, true) ~= nil,
    "конфиг: зеркало сохранено")
check(U.window == true, "ручная проверка: окно открыто")

-- ---------- 5. версия новее → загрузка файла ----------
resetU()
U.check("manual")
succeed(1, "1.19.227")
U.tick()
check(U.state == "downloading", "новее: состояние downloading")
check(U.newVer == "1.19.227", "новее: версия запомнена")
check(hasToast("Обновляюсь до версии 1.19.227"), "новее: тост про обновление")
check(#downloads == 2, "новее: пошла вторая загрузка — сам скрипт")
check(dl(2).url == CH1.base .. U.SCRIPT_FILE, "новее: качаем файл скрипта")
check(dl(2).path == SCRIPT_PATH .. ".new", "новее: качаем в .new рядом")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "новее: рабочий файл пока не тронут")

succeed(2, newBody("1.19.227", "установка прошла"))
U.tick()
check(U.state == "ready", "установка: состояние ready")
check(U.installed == true, "установка: флаг installed")
check(U.window == true, "установка: окно со списком изменений открыто")
check(hasToast("Обновление 1.19.227 установлено"), "установка: тост об установке")
check(FS[SCRIPT_PATH]:find('GRND_SCRIPT_VERSION = "1.19.227"', 1, true) ~= nil,
    "установка: новый файл встал на место")
check(FS[SCRIPT_PATH .. ".bak"] == "-- старый скрипт\n", "установка: старый — в .bak")
check(FS[SCRIPT_PATH .. ".new"] == nil, "установка: .new больше нет")
check(#(U.notes or {}) == 1, "установка: список изменений разобран")
check(logs():find("установлено: 1.19.227", 1, true) ~= nil, "диагностика: установка")
check((FS[LOG_PATH] or ""):find("установлено", 1, true) ~= nil,
    "диагностика: пишется и в файл grnd_update.log")

-- ---------- 6. зеркала перебираются ----------
resetU()
U.check("manual")
failDl(1, 4)
U.tick()
check(#downloads == 2, "зеркала: первое упало — пробуем второе")
check(dl(2).url == CH2.base .. U.VER_FILE, "зеркала: второе — statically")
check(logs():find("raw: статус 4", 1, true) ~= nil, "диагностика: причина отказа")
succeed(2, "1.19.226")
U.tick()
check(U.state == "uptodate", "зеркала: второе ответило — проверка дошла до конца")
check(U.activeId == "statically", "зеркала: рабочее запомнено")
check((FS[CFG_PATH] or ""):find("channel=statically", 1, true) ~= nil,
    "конфиг: в файле второе зеркало")

-- следующая проверка начинается с запомненного зеркала
resetU()
FS[CFG_PATH] = "auto=1\nperiod=0\nlast=0\nchannel=statically\n"
U.check("manual")
check(dl(1).url == CH2.base .. U.VER_FILE,
    "зеркала: запомненное пробуется первым")
succeed(1, "1.19.226")
U.tick()

-- все зеркала молчат — честная ошибка и один тост
resetU()
U.check("manual")
failDl(1, 4) U.tick()
failDl(2, 4) U.tick()
failDl(3, 4) U.tick()
check(U.state == "error", "зеркала: все упали — состояние error")
check(tostring(U.err):find("нет связи", 1, true) ~= nil, "зеркала: причина в err")
check(hasToast("нет связи ни с одним зеркалом"), "зеркала: тост про все зеркала")
check(#downloads == 3, "зеркала: попыток ровно три")
check(U.window == true, "зеркала: ручная проверка открывает окно с диагностикой")

-- ---------- 7. вторая дорога: WinINet, когда штатного загрузчика нет ----------
resetU()
U.moonDl = nil
U.inetLoad = function() return inetBackend() end
plan = {}
plan[CH1.base .. U.VER_FILE] = "1.19.227\n"
plan[CH1.base .. U.SCRIPT_FILE] = newBody("1.19.227", "WinINet качает")
check(U.check("manual"), "WinINet: проверка стартовала без штатного загрузчика")
check(U.job and U.job.backend == "inet", "WinINet: загрузка идёт через WinINet")
check(#downloads == 0, "WinINet: штатный загрузчик не задействован")
check(inetLog.urls[1] == CH1.base .. U.VER_FILE, "WinINet: адрес версии")
-- тело больше одного куска (4096): читаем несколькими тиками
local guard = 0
while U.state == "checking" and guard < 200 do
    U.tick()
    guard = guard + 1
end
check(inetLog.eof and inetLog.eof >= 1, "WinINet: дошли до конца потока")
check(U.state == "downloading", "WinINet: версия прочитана, идёт файл скрипта")
check(logs():find("качаю сам скрипт", 1, true) ~= nil, "диагностика: фаза файла")
guard = 0
while U.state ~= "ready" and guard < 500 do
    U.tick()
    guard = guard + 1
end
check(U.state == "ready", "WinINet: файл скачан и установлен")
check(FS[SCRIPT_PATH]:find('"1.19.227"', 1, true) ~= nil, "WinINet: новый файл на месте")
check(FS[SCRIPT_PATH .. ".bak"] ~= nil, "WinINet: бэкап сделан")
check(inetLog.closed and inetLog.closed > 0, "WinINet: соединения закрыты")

-- ---------- 8. молчащий MoonLoader-загрузчик → та же ссылка через WinINet ----------
resetU()
U.inetLoad = function() return inetBackend() end
plan = {}
plan[CH1.base .. U.VER_FILE] = "1.19.226\n"
U.check("manual")
check(U.job.backend == "moon", "мост: сначала штатный загрузчик")
now = now + U.timeout + 1 -- штатный не ответил
U.tick()
check(U.job and U.job.backend == "inet", "мост: та же ссылка ушла в WinINet")
check(#inetLog.urls == 1 and inetLog.urls[1] == CH1.base .. U.VER_FILE,
    "мост: адрес не менялся — зеркало то же")
check(#downloads == 1, "мост: новое зеркало не подключалось")
local guard2 = 0
while U.state == "checking" and guard2 < 50 do
    U.tick()
    guard2 = guard2 + 1
end
check(U.state == "uptodate", "мост: WinINet дочитал версию")
check(logs():find("та же ссылка через WinINet", 1, true) ~= nil,
    "диагностика: смена дороги записана")

-- ---------- 9. HTTP-ошибка не ставится, зеркало пробуется дальше ----------
resetU()
U.moonDl = nil
U.inetLoad = function() return inetBackend() end
plan = {}
plan[CH2.base .. U.VER_FILE] = "1.19.226\n"
U.check("manual")
U.tick()
check(U.state == "error" or U.job ~= nil, "нет ответа у raw: не зависаем")
check(logs():find("raw", 1, true) ~= nil, "диагностика: первое зеркало отмечено")

-- ---------- 10. битый файл: рабочая версия цела ----------
resetU()
U.check("manual")
succeed(1, "1.19.227")
U.tick()
succeed(2, 'GRND_SCRIPT_VERSION = "1.19.227"') -- крошечный
U.tick()
check(#downloads == 3, "битый файл: пробуем следующее зеркало")
failDl(3, 4)
U.tick()
check(#downloads == 4, "битый файл: и третье зеркало")
failDl(4, 4)
U.tick()
check(U.state == "error", "битый файл: состояние error")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "битый файл: рабочий файл цел")
check(FS[SCRIPT_PATH .. ".bak"] == nil, "битый файл: бэкап не создавался")
check(logs():find("не прошёл проверку", 1, true) ~= nil, "диагностика: причина")

-- ---------- 11. заход в игру ----------
resetU()
_G.__spawned = true
U.tick()
check(U.state == "checking", "спавн: проверка при заходе в игру")
check(hasToast("Проверяю обновления"), "спавн: тост проверки есть")
succeed(1, "1.19.226")
U.tick()
check(U.state == "uptodate", "спавн: проверка завершилась")
check(not hasToast("последняя"), "спавн: «версия — последняя» молчит")
check(U.window == false, "спавн: окно само не открывается")

-- сбой на заходе: один тост за сессию, дальше тихо
resetU()
_G.__spawned = true
U.tick()
failDl(1, 4) U.tick()
failDl(2, 4) U.tick()
failDl(3, 4) U.tick()
check(U.state == "error", "спавн без сети: состояние error")
check(countToasts("сервер не отвечает") == 1, "спавн без сети: один тост за сессию")
_G.__spawned = false U.tick() _G.__spawned = true U.tick()
failDl(1, 4) U.tick() failDl(2, 4) U.tick() failDl(3, 4) U.tick()
check(countToasts("сервер не отвечает") == 1, "спавн без сети: второй раз молчим")
check(U.err ~= nil, "спавн без сети: причина сохранена для раздела")

-- period: реже, если задан
resetU()
FS[CFG_PATH] = "auto=1\nperiod=10800\nlast=0\n"
_G.__spawned = true
U.tick()
check(U.state == "checking", "period=10800: первый заход проверяет")
succeed(1, "1.19.226")
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

-- ---------- 12. обход зеркал («/grndupdate test») ----------
resetU()
U.probe()
check(U.probing == true, "проба: режим включён")
check(hasToast("Проверяю каналы"), "проба: тост")
succeed(1, "1.19.226")
U.tick()
check(#downloads == 2, "проба: после первого зеркала идём ко второму")
succeed(2, "1.19.226")
U.tick()
failDl(3, 4)
U.tick()
check(U.probing == false, "проба: закончилась")
check(U.window == true, "проба: окно открыто")
check(#U.probeLines == 6, "проба: по строке на зеркало (пробую + ответ)")
check(table.concat(U.probeLines, "|"):find("statically: версия 1.19.226", 1, true) ~= nil,
    "проба: у ответившего зеркала видна версия")
check(table.concat(U.probeLines, "|"):find("jsdelivr: статус 4", 1, true) ~= nil,
    "проба: у упавшего зеркала видна причина")

-- ---------- 13. окно ----------
resetU()
local function mkIm()
    local im = { texts = {}, buttons = {}, clicked = {} }
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
    im.BeginChild = function() return true end
    im.EndChild = function() end
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
succeed(1, "1.19.227")
U.tick()
succeed(2, newBody("1.19.227", "в окне видно"))
U.tick()
check(U.window == true, "окно: открылось после установки")
local im = mkIm()
check(U.draw(mkCtx(im)) == true, "окно: нарисовалось")
check(im.began and im.began:find("АВТООБНОВЛЕНИЕ", 1, true) ~= nil,
    "окно: заголовок «АВТООБНОВЛЕНИЕ»")
check(im.ended == 1, "окно: End вызван один раз")
local body = table.concat(im.texts, "\n")
check(body:find("Установлена версия 1.19.227", 1, true) ~= nil, "окно: было/стало")
check(body:find("в окне видно", 1, true) ~= nil, "окно: строка изменений")
check(body:find("Диагностика", 1, true) ~= nil, "окно: раздел диагностики")
check(body:find("raw: версия", 1, true) ~= nil, "окно: строки диагностики")
check(body:find("Канал:", 1, true) ~= nil, "окно: рабочее зеркало видно")
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

-- без изменений: кнопки проверки и обхода зеркал
resetU()
U.window, U.state = true, "uptodate"
local im3 = mkIm()
check(U.draw(mkCtx(im3)) == true, "окно: рисуется и без изменений")
check(table.concat(im3.texts, " "):find("Изменений не найдено", 1, true) ~= nil,
    "окно: текст без изменений")
check(table.concat(im3.buttons, "|"):find("Проверить снова", 1, true) ~= nil,
    "окно: кнопка повторной проверки")
check(table.concat(im3.buttons, "|"):find("Каналы", 1, true) ~= nil,
    "окно: кнопка обхода зеркал")

-- режим пробы показывает ответы зеркал
resetU()
U.window, U.probeLines = true, { "raw: версия 1.19.226", "statically: статус 4" }
local im4 = mkIm()
U.draw(mkCtx(im4))
check(table.concat(im4.texts, " "):find("statically: статус 4", 1, true) ~= nil,
    "окно: ответы зеркал в режиме пробы")

check(U.draw(nil) == false, "окно: ctx=nil → false")
check(U.draw({}) == false, "окно: ctx без begin → false")

-- ---------- 14. команда и глобальные обёртки ----------
resetU()
local cmds = {}
_G.sampRegisterChatCommand = function(name, fn) cmds[name] = fn end
local U2 = mkModule()()
check(type(cmds["grndupdate"]) == "function", "команда: /grndupdate есть")
U2.io = stubIO
U2.moonDl = downloadStub
U2.CHANNELS = { CH1, CH2, CH3 }
U2.inetLoad = function() return nil end
U2.probing, U2.job, U2.cfgLoaded = false, nil, false
U2.window, U2.state = false, "idle"
U2.activeId, U2.order, U2.logs = nil, nil, {}
cmds["grndupdate"]("")
check(U2.state == "checking", "команда: обычный вызов — проверка")
check(hasToast("Проверяю обновления вручную"), "команда: тост ручной проверки")
cmds["grndupdate"]("test")
check(U2.probing == true, "команда: «test» — обход зеркал (текущая загрузка отменена)")
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
