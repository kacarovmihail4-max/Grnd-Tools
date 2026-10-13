-- =====================================================================
-- Стенд v1.19.223: АВТООБНОВЛЕНИЕ (GRND_UPDATE).
--
-- Блок между якорями GRND_UPDATE_* грузится как функция; диск, сеть и
-- часы подменяются стабами (U.io / U.download / U.io.clock), поэтому
-- проверяется вся логика без игры и без интернета:
--   * версии сравниваются как числа (1.19.9 < 1.19.10 < 1.20.0);
--   * проверка: тост «Проверяю обновления…», загрузка update.txt,
--     запись last= в grnd_update.cfg;
--   * версия новее — тост ровно «Обновляюсь до версии N» и загрузка
--     файла в .new (рабочий файл до проверки НЕ трогается);
--   * установка атомарна: файл с версией и не меньше 100 КБ → старый в
--     .bak, новый на место, окно со списком изменений открывается;
--     битый/короткий файл или чужая версия → рабочий файл цел, состояние
--     «error», тост с причиной;
--   * та же версия → «Версия N — последняя», файл скрипта не качается;
--   * зеркало: первое зеркало отдало ошибку — пробуем второе;
--   * таймаут: колбэк не пришёл за 25 с — состояние «error»;
--   * разбор списка изменений из шапки нового файла (только версии
--     новее текущей, до своей версии — стоп);
--   * проверка при спавне не чаще period (по умолчанию 3 часа);
--   * окно: заголовок, текст «было/стало», изменения, кнопки
--     «Перезагрузить скрипт» / «Позже» / «Проверить снова».
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
local VER_FILE = "update.txt"
local SCRIPT_FILE = "grnd_adm_tools.lua"

-- ---------- стабы ----------
_G.grndIsSpawnedSafe = function() return _G.__spawned and true or false end
_G.GRND_SCRIPT_VERSION = "1.19.223"
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
    if mode == "rb" or mode == "r" or mode == nil then
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
    local buf = {}
    return {
        write = function(self, ...)
            for i = 1, select("#", ...) do buf[#buf + 1] = tostring(select(i, ...)) end
            return self
        end,
        close = function() FS[path] = table.concat(buf); return true end,
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

local downloads = {}
local mkModule = assert(load("return function()\n" .. block
    .. "\n    return _G.GRND_UPDATE\nend", "@upd_test"))
local U = mkModule()()

-- Модуль определяет U.io/U.download сам — подменяем на стабы.
local function downloadStub(url, path, cb)
    downloads[#downloads + 1] = { url = url, path = path, cb = cb }
    return true
end
U.download = downloadStub
U.io = stubIO

local function resetU()
    FS = {}
    FS[SCRIPT_PATH] = "-- старый скрипт\n"
    _G.__toasts = {}
    _G.__spawned = false
    downloads = {}
    reloaded = 0
    now = 1000
    wallNow = 1700000000
    U.io = stubIO
    U.pend, U.state, U.err = nil, "idle", nil
    U.newVer, U.notes, U.installed, U.window = nil, nil, false, false
    U.lastAt, U.wasSpawn, U.mi = 0, false, 1
    U.reloadPending = false
    U.cfgLoaded, U.auto, U.period = false, true, 0 -- 0 = каждый заход
end
resetU()

local function toasts()
    return _G.__toasts or {}
end
local function lastToast()
    local t = toasts()
    return t[#t] and t[#t].text or ""
end
local function hasToast(fragment)
    for _, t in ipairs(toasts()) do
        if tostring(t.text):find(fragment, 1, true) then return true end
    end
    return false
end
local function succeed(i, body)
    local d = downloads[i]
    assert(d, "нет загрузки #" .. i)
    FS[d.path] = body
    d.cb(i, U.ST_OK)
end
local function failDl(i, status)
    local d = downloads[i]
    assert(d, "нет загрузки #" .. i)
    d.cb(i, status or 4)
end

-- ---------- 1. начальное состояние и версии ----------
check(U.cur == "1.19.223", "старт: текущая версия из шапки")
check(U.state == "idle" and U.window == false, "старт: состояние idle, окно закрыто")
check(type(U.verNum) == "function" and type(U.check) == "function",
    "API: функции на месте")
check(U.verNum("1.19.9") < U.verNum("1.19.10"), "версии: 1.19.9 < 1.19.10")
check(U.verNum("1.19.10") < U.verNum("1.19.100"), "версии: 1.19.10 < 1.19.100")
check(U.verNum("1.9.999") < U.verNum("1.19.0"), "версии: 1.9.999 < 1.19.0")
check(U.verNum(nil) == 0, "версии: мусор → 0")

-- ---------- 2. разбор списка изменений ----------
local head = table.concat({
    'script_name("grnd_adm_tools")',
    'GRND_SCRIPT_VERSION = "1.19.224"',
    "-- v1.19.224 — ТЕСТ: свежая правка:",
    "--   1) первое изменение;",
    "--   2) второе изменение.",
    "-- v1.19.223 — прошлая версия:",
    "--   1) это уже наше, в список попасть не должно.",
    "-- v1.19.222 — старая:",
}, "\n")
local notes = U.changelogOf(head)
check(#notes == 1, "changelog: только версии новее текущей")
check(notes[1] and notes[1].ver == "1.19.224", "changelog: версия в первой записи")
local joined = notes[1] and table.concat(notes[1].lines, "|") or ""
check(joined:find("ТЕСТ: свежая правка", 1, true) ~= nil, "changelog: заголовок")
check(joined:find("первое изменение", 1, true) ~= nil, "changelog: строки 1")
check(joined:find("второе изменение", 1, true) ~= nil, "changelog: строки 2")
check(joined:find("наше", 1, true) == nil, "changelog: своя версия не попала")
check(#U.changelogOf(nil) == 0, "changelog: nil → пусто")

-- ---------- 3. «уже последняя» ----------
resetU()
check(U.check("manual"), "проверка: запустилась")
check(U.state == "checking", "проверка: состояние checking")
check(hasToast("Проверяю обновления"), "проверка: тост «Проверяю обновления…»")
check(#downloads == 1, "проверка: одна загрузка")
check(downloads[1].url:find(VER_FILE, 1, true) ~= nil, "проверка: качаем update.txt")
check(downloads[1].url:find(U.REPO, 1, true) == 1, "проверка: первое зеркало — raw")
-- адрес канала и зеркало должны стоять на ОДНОЙ метке (иначе зеркало
-- отдаст старьё): у raw это /Grnd-Tools/<метка>/, у jsDelivr — @<метка>/
local tagRaw = U.REPO:match("/Grnd%-Tools/([^/]+)/$")
local tagMirror = U.MIRROR:match("@([^/]+)/$")
check(tagRaw ~= nil and tagMirror ~= nil and tagRaw == tagMirror,
    "канал: адрес и зеркало — на одну метку")
check(U.REPO:find("https://", 1, true) == 1 and U.REPO:sub(-1) == "/",
    "канал: адрес полный и со слэшем на конце")
check(U.MIRROR:find("https://", 1, true) == 1 and U.MIRROR:sub(-1) == "/",
    "канал: зеркало полное и со слэшем на конце")
check((U.timeout or 0) > 0 and U.timeout <= 15,
    "канал: таймаут короткий, чтобы заблокированное зеркало не держало тик")
check(FS[CFG_PATH] and FS[CFG_PATH]:find("last=", 1, true) ~= nil,
    "проверка: время проверки ушло в конфиг")
succeed(1, "1.19.223\n")
U.tick()
check(U.state == "uptodate", "та же версия: состояние uptodate")
check(hasToast("Версия 1.19.223 — последняя"), "та же версия: тост про последнюю")
check(#downloads == 1, "та же версия: файл скрипта не качается")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "та же версия: файл цел")
check(U.pend == nil, "та же версия: загрузка закрыта")

-- ---------- 4. версия новее → загрузка файла ----------
resetU()
U.check("manual")
succeed(1, "1.19.224")
U.tick()
check(U.state == "downloading", "новее: состояние downloading")
check(U.newVer == "1.19.224", "новее: версия запомнена")
check(hasToast("Обновляюсь до версии 1.19.224"), "новее: тост ровно про обновление")
check(#downloads == 2, "новее: пошла вторая загрузка — сам скрипт")
check(downloads[2].url:find(SCRIPT_FILE, 1, true) ~= nil, "новее: качаем файл скрипта")
check(downloads[2].path == SCRIPT_PATH .. ".new", "новее: качаем в .new рядом")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "новее: рабочий файл пока не тронут")

local filler = "-- " .. string.rep("f", 400) .. "\n"
local newBody = table.concat({
    'script_name("grnd_adm_tools")',
    'GRND_SCRIPT_VERSION = "1.19.224"',
    "-- v1.19.224 — ТЕСТ: установка прошла:",
    "--   1) проверяемое изменение.",
}, "\n") .. string.rep(filler, 260) -- > 100 000 байт

succeed(2, newBody)
U.tick()
check(U.state == "ready", "установка: состояние ready")
check(U.installed == true, "установка: флаг installed")
check(U.window == true, "установка: окно со списком изменений открыто")
check(hasToast("Обновление 1.19.224 установлено"), "установка: тост об установке")
check(FS[SCRIPT_PATH] == newBody, "установка: новый файл встал на место")
check(FS[SCRIPT_PATH .. ".bak"] == "-- старый скрипт\n", "установка: старый — в .bak")
check(FS[SCRIPT_PATH .. ".new"] == nil, "установка: .new больше нет")
check(#(U.notes or {}) == 1, "установка: список изменений разобран")
check(type(_G.grndUpdWanted) == "function" and _G.grndUpdWanted() == true,
    "установка: grndUpdWanted() = true (кадр держится)")

-- ---------- 5. битый файл: рабочий файл цел ----------
resetU()
U.check("manual")
succeed(1, "1.19.224")
U.tick()
succeed(2, 'GRND_SCRIPT_VERSION = "1.19.224"') -- крошечный: страница ошибки
U.tick()
check(U.state == "error", "битый файл: состояние error")
check(U.installed == false, "битый файл: не установлено")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "битый файл: рабочий файл цел")
check(FS[SCRIPT_PATH .. ".bak"] == nil, "битый файл: бэкап не создавался")
check(FS[SCRIPT_PATH .. ".new"] == nil, "битый файл: мусор убран")
check(hasToast("Обновление проверку не прошло"), "битый файл: тост с причиной")

-- ---------- 6. чужая версия внутри файла ----------
resetU()
U.check("manual")
succeed(1, "1.19.224")
U.tick()
succeed(2, string.rep(filler, 260)) -- большой, но версии внутри нет
U.tick()
check(U.state == "error", "чужая версия: состояние error")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "чужая версия: файл цел")
check(FS[SCRIPT_PATH .. ".new"] == nil, "чужая версия: .new убран")

-- ---------- 7. зеркало: первое упало — пробуем второе ----------
resetU()
U.check("manual")
failDl(1, 4)
U.tick()
check(#downloads == 2, "зеркало: пошла вторая попытка")
check(downloads[2].url:find(U.MIRROR, 1, true) == 1, "зеркало: второе — jsDelivr")
succeed(2, "1.19.223")
U.tick()
check(U.state == "uptodate", "зеркало: версия с зеркала прочитана")

-- ---------- 8. сеть молчит: таймаут ----------
resetU()
U.check("manual")
now = now + U.timeout + 1
U.tick() -- первое зеркало не ответило — уходим на второе
check(U.state == "checking", "таймаут: пробуем второе зеркало")
now = now + U.timeout + 2
U.tick()
check(U.state == "error", "таймаут: состояние error")
check(hasToast("нет связи"), "таймаут: тост про связь")
check(FS[SCRIPT_PATH] == "-- старый скрипт\n", "таймаут: файл цел")

-- ---------- 9. проверка при спавне: по умолчанию — каждый заход ----------
resetU()
_G.__spawned = true
U.tick()
check(U.state == "checking", "спавн: проверка при заходе в игру")
succeed(1, "1.19.223")
U.tick()
check(U.state == "uptodate", "спавн: проверка завершилась")

local before = #downloads
U.tick() -- спавн уже обработан, второй раз подряд не проверяем
check(#downloads == before, "спавн: повторно сразу не проверяем")

-- второй заход в игру: зазор 20 с гасит дребезг флага, потом проверяем снова
_G.__spawned = false
U.tick()
_G.__spawned = true
U.tick()
check(#downloads == before, "спавн: в пределах 20 с — тихо (дребезг флага)")
wallNow = wallNow + 21
_G.__spawned = false
U.tick()
_G.__spawned = true
U.tick()
check(#downloads == before + 1, "спавн: каждый заход в игру — новая проверка")
succeed(#downloads, "1.19.223")
U.tick()
before = #downloads

-- если в конфиге задан period — проверяем реже
FS[CFG_PATH] = "auto=1\nperiod=10800\nlast=0\n"
wallNow = wallNow + 100
_G.__spawned = false
U.tick()
_G.__spawned = true
U.tick()
check(#downloads == before + 1, "period=10800: первый заход проверяет")
succeed(#downloads, "1.19.223")
U.tick()
_G.__spawned = false
U.tick()
_G.__spawned = true
U.tick()
check(#downloads == before + 1, "period=10800: второй заход молчит")
U.pend = nil

wallNow = wallNow + U.period + 1
_G.__spawned = false
U.tick()
_G.__spawned = true
U.tick()
check(#downloads == before + 1, "спавн: после period проверяем снова")
U.pend = nil

-- ---------- 9б. на заходе в игру — без лишних тостов ----------
resetU()
_G.__spawned = true
U.tick()
check(hasToast("Проверяю обновления"), "спавн: тост проверки есть")
succeed(1, "1.19.223") -- та же версия: обновляться не надо
U.tick()
check(U.state == "uptodate", "спавн: проверка завершилась")
check(not hasToast("последняя"), "спавн: «версия — последняя» молчит")
check(#downloads == 1, "спавн: файл не качался (версия та же)")

-- на заходе сеть лежит — тоже молчим, но статус помним
resetU()
_G.__spawned = true
U.tick()
check(hasToast("Проверяю обновления"), "спавн без сети: проверка объявлена")
failDl(1, 4)
U.tick()
failDl(2, 4)
U.tick()
check(U.state == "error", "спавн без сети: состояние error")
check(not hasToast("нет связи"), "спавн без сети: тоста про связь нет")
check(U.err ~= nil, "спавн без сети: причина сохранена для раздела")

-- ручная проверка — тосты на месте
resetU()
U.check("manual")
failDl(1, 4)
U.tick()
failDl(2, 4)
U.tick()
check(hasToast("нет связи"), "ручная проверка: ошибка связи озвучена")
check(U.checkReason == "manual", "проверка: причина запомнена")

-- ---------- 10. авто-проверка выключается ----------
resetU()
FS[CFG_PATH] = "auto=0\nperiod=10800\nlast=0\n"
_G.__spawned = true
wallNow = 9000
U.tick()
check(#downloads == 0, "auto=0: при спавне не проверяем")
check(U.auto == false, "auto=0: настройка прочитана")

-- ---------- 11. окно со списком изменений ----------
resetU()
local function mkIm()
    local im = { texts = {}, buttons = {}, clicked = {} }
    im.ImVec2 = function(x, y) return { x = x, y = y } end
    im.Cond = { FirstUseEver = 4, Appearing = 1 }
    im.Begin = function(name) im.began = name return true end
    im.End = function() im.ended = (im.ended or 0) + 1 end
    im.SetNextWindowSize = function() end
    im.SetNextWindowPos = function() end
    im.Text = function(s) im.texts[#im.texts + 1] = tostring(s) end
    im.TextWrapped = function(s) im.texts[#im.texts + 1] = tostring(s) end
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
    return {
        im = im,
        begin = function(name, flags) return im.Begin(name, flags) end,
        wf = function() return 0 end,
        always = 1,
        endWin = function() im.End() end,
    }
end
local function texts(im)
    return table.concat(im.texts, "\n")
end

check(U.draw(mkCtx(mkIm())) == false, "окно: закрыто — не рисуется")

-- состояние: скачали 1.19.224, окно открылось автоматически
U.check("manual")
succeed(1, "1.19.224")
U.tick()
succeed(2, newBody)
U.tick()
check(U.window == true, "окно: открылось после установки")

local im = mkIm()
check(U.draw(mkCtx(im)) == true, "окно: нарисовалось")
check(im.began and im.began:find("АВТООБНОВЛЕНИЕ", 1, true) ~= nil,
    "окно: заголовок «АВТООБНОВЛЕНИЕ»")
check(im.ended == 1, "окно: End вызван один раз")
local body = texts(im)
check(body:find("Установлена версия 1.19.224", 1, true) ~= nil, "окно: было/стало")
check(body:find("была 1.19.223", 1, true) ~= nil, "окно: показана прежняя версия")
check(body:find("v1.19.224", 1, true) ~= nil, "окно: заголовок новых изменений")
check(body:find("проверяемое изменение", 1, true) ~= nil, "окно: строка изменений")
check(body:find("Канал:", 1, true) ~= nil, "окно: канал обновлений виден")
local labels = table.concat(im.buttons, "|")
check(labels:find("Перезагрузить скрипт", 1, true) ~= nil, "окно: кнопка перезагрузки")
check(labels:find("Позже", 1, true) ~= nil, "окно: кнопка «Позже»")

-- клик «Перезагрузить скрипт»: просьба перезапуска, исполняет тик
im.clicked["Перезагрузить скрипт##grnd_upd_reload"] = true
U.draw(mkCtx(im))
check(U.reloadPending == true, "окно: кнопка перезагрузки ставит просьбу")
check(U.window == false, "окно: после перезагрузки закрывается")
check(reloaded == 0, "окно: в кадре скрипт НЕ перезапускается (не роняем кадр)")
U.tick()
check(reloaded == 1, "тик: перезапуск выполнен из главного цикла")
check(U.reloadPending == false, "тик: просьба снята")

-- клик «Позже» просто закрывает
U.window = true
local im2 = mkIm()
im2.clicked["Позже##grnd_upd_later"] = true
U.draw(mkCtx(im2))
check(U.window == false, "окно: «Позже» закрывает")

-- окно без изменений (проверка вручную) — кнопка «Проверить снова»
resetU()
U.window = true
U.state = "uptodate"
local im3 = mkIm()
check(U.draw(mkCtx(im3)) == true, "окно: рисуется и без изменений")
check(texts(im3):find("Изменений не найдено", 1, true) ~= nil, "окно: текст без изменений")
check(table.concat(im3.buttons, "|"):find("Проверить снова", 1, true) ~= nil,
    "окно: кнопка повторной проверки")

-- мусорный ctx не роняет
check(U.draw(nil) == false, "окно: ctx=nil → false")
check(U.draw({}) == false, "окно: ctx без begin → false")

-- ---------- 12. своё зеркало из конфига ----------
resetU()
FS[CFG_PATH] = "auto=1\nperiod=10800\nrepo=https://example.org/upd/\n"
U.check("manual")
check(downloads[1].url == "https://example.org/upd/" .. VER_FILE,
    "канал из конфига: качаем по своему адресу")
check(downloads[1].url:find(U.REPO, 1, true) == nil, "канал из конфига: основной адрес не тронут")
succeed(1, "1.19.223")
U.tick()
check(U.state == "uptodate", "канал из конфига: проверка дошла до конца")
-- второй адрес — своё зеркало (или, если его нет, адрес по умолчанию)
resetU()
FS[CFG_PATH] = "auto=1\nperiod=10800\nrepo=https://example.org/upd/\nmirror=https://mirror.example.net/g/\n"
U.check("manual")
failDl(1, 4)
U.tick()
check(downloads[2] and downloads[2].url == "https://mirror.example.net/g/" .. VER_FILE,
    "канал из конфига: своё зеркало вторым")
-- своё зеркало не теряется при сохранении конфига
local cfgText = FS[CFG_PATH] or ""
check(cfgText:find("repo=https://example.org/upd/", 1, true) ~= nil,
    "конфиг: своё зеркало сохранено")
check(cfgText:find("last=", 1, true) ~= nil, "конфиг: время проверки рядом")

-- ---------- 13. ручная команда и глобальные обёртки ----------
resetU()
local cmds = {}
_G.sampRegisterChatCommand = function(name, fn)
    cmds[name] = fn
end
-- команда регистрируется при загрузке модуля, поэтому перезагружаем блок
local U2 = mkModule()()
check(type(cmds["grndupdate"]) == "function", "команда: /grndupdate зарегистрирована")
U2.io = stubIO
U2.download = downloadStub
cmds["grndupdate"]()
check(U2.state == "checking", "команда: ручная проверка стартовала")
check(hasToast("Проверяю обновления вручную"), "команда: тост ручной проверки")
check(type(_G.grndUpdTick) == "function", "API: grndUpdTick")
local okTick = pcall(_G.grndUpdTick)
check(okTick, "API: grndUpdTick без ошибок")
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
