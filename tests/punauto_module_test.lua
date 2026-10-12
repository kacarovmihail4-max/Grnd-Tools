-- Интеграционный стенд модуля автопилота наказаний («Наказания» →
-- «Автопилот»): вырезает do-блок из grnd_adm_tools.lua и гоняет его с
-- заглушками (GRND_CONFIG, QR.toast, samp*, GRND_LOG, ImGui) — без
-- MoonLoader. Проверяет вкладки/конфиг, выдачу по трём видам строк, паузу и
-- кулдаун, предохранители (себя/админов/каналы), режим проверки, dryRun и
-- отрисовку страницы (буферы полей, кнопки, тумблеры, плюс/крестик).
-- Путь к проверяемому скрипту: GRND_SCRIPT / рядом с тестом / текущий каталог.
local function findScript()
    local cands = {}
    local env = os.getenv and os.getenv("GRND_SCRIPT")
    if env and env ~= "" then cands[#cands + 1] = env end
    local self = (arg and arg[0]) or ""
    local dir = self:match("^(.*)[/\\][^/\\]*$")
    if dir then
        cands[#cands + 1] = dir .. "/../grnd_adm_tools.lua"
        cands[#cands + 1] = dir .. "/grnd_adm_tools.lua"
    end
    cands[#cands + 1] = "grnd_adm_tools.lua"
    cands[#cands + 1] = "../grnd_adm_tools.lua"
    for i = 1, #cands do
        local f = io.open(cands[i], "rb")
        if f then f:close() return cands[i] end
    end
    return nil
end
local SRC = assert(findScript(), "не нашёл grnd_adm_tools.lua (задайте GRND_SCRIPT)")

local src = assert(io.open(SRC, "rb")):read("*a")
local a = assert(src:find("do\n    local PA = QR.punAuto", 1, true), "нет начала блока")
local e = assert(src:find("\nend\n\n-- ---------- самопроверка логики", a, true), "нет конца блока")
local block = src:sub(a, e + 4)   -- вместе с закрывающим end

-- в самой игре конвертер — глобальная функция (function grndAnsiText), поэтому
-- кладём заглушку и в _G: модуль ищет её именно там
local grndAnsiTextLocal = nil
-- ---------- заглушки окружения ----------
local CONFIG = {}          -- domain -> {key=value}
local files = {}           -- открытые "файлы"
local queued = {}          -- отправленные команды
local click = {}           -- id -> true: «нажатие» кнопки в текущем кадре
local logged = {}          -- записи журнала
local toasts = {}          -- уведомления
local bufs = {}            -- QR.bufs

local QR = { bufs = bufs, toast = function(t) toasts[#toasts+1] = t end,
    path = function() return "C:\\samp\\grnd_repquick.cfg" end,
    myNick = function() return "Mixa" end,
    queueCmd = function(cmd) queued[#queued+1] = cmd return true end }
QR.punAuto = {}

local GRND_CONFIG = {}
function GRND_CONFIG.open(path, mode)
    local base = tostring(path):match("([^/\\]+)%.cfg$")
    CONFIG[base] = CONFIG[base] or {}
    if mode == "r" then
        local keys = {}
        for k in pairs(CONFIG[base]) do keys[#keys+1] = k end
        table.sort(keys)
        local body = {}
        for _, k in ipairs(keys) do body[#body+1] = k .. "=" .. tostring(CONFIG[base][k]) end
        local text = table.concat(body, "\n") .. "\n"
        local cursor = 1
        return { lines = function()
                return function()
                    if cursor > #text then return nil end
                    local nl = text:find("\n", cursor, true)
                    local line = text:sub(cursor, nl - 1)
                    cursor = nl + 1
                    return line
                end
            end,
            read = function() return "" end,
            close = function() return true end }
    end
    local chunks = {}
    return { write = function(self, ...)
                for i = 1, select("#", ...) do chunks[#chunks+1] = tostring(select(i, ...)) end
                return self
            end,
            close = function()
                local body = table.concat(chunks)
                local target = {}
                for k, v in body:gmatch("([%w_]+)=(.-)\n") do target[k] = v end
                CONFIG[base] = target
                return true
            end }
end
GRND_CONFIG.flush = function() return true end

local GRND_LOG = { append = function(kind, text) logged[#logged+1] = kind .. ": " .. (text or "") end }
local AO = { list = { { nick = "Admin_One", id = 400 } } }
_G.GRND_LOG = GRND_LOG
_G.GRND_AO = AO

local connected = { [7] = "Nik_Name", [400] = "Admin_One", [5] = "Mixa" }
-- реестр «чат-ID»: в игре его наполняет GRND_CHATID.refresh()
_G.GRND_CHATID = { refresh = function() end, roster = {} }
do
    local function syncRoster()
        local r = {}
        for id, nick in pairs(connected) do r[#r+1] = { nick = nick, id = id } end
        table.sort(r, function(a, b) return a.id < b.id end)
        _G.GRND_CHATID.roster = r
    end
    syncRoster()
    _G.grndRosterSync = syncRoster
end
local function isConnected(id) return connected[id] ~= nil end
local function nickOf(id) return connected[id] end
local function myId() return 5 end

-- ---------- заглушка Screenshot.asi ----------
-- Скрипт берёт модуль только через require, а модуль этот ничего не
-- возвращает; поэтому подменяем его один раз на весь стенд и по-настоящему
-- пишем файл, когда это нужно проверке.
local shotStub = { shots = {}, makeFile = false, dupExt = false, msg = nil }
_G.GRND_SCRIPT_VERSION = "1.19.206"   -- как в шапке скрипта
do
    local origRequire = require
    require = function(name)
        if name == "lib.screenshot" then
            if shotStub.broken then
                error(shotStub.msg or "module 'lib.screenshot' not found", 2)
            end
            return {
                getUserDirectoryPath = function() return "/tmp/grnd_user_files" end,
                requestEx = function(dir, file)
                    shotStub.shots[#shotStub.shots + 1] = { dir = dir, file = file }
                    if shotStub.makeFile then
                        local ext = shotStub.dupExt and ".png.png" or ".png"
                        local f = io.open(dir .. "/" .. file .. ext, "wb")
                        if f then f:write("png") f:close() end
                    end
                    return true
                end,
                request = function() end,
            }
        end
        return origRequire(name)
    end
end

-- ---------- локальные имена, которые в файле живут в объёмлющем closure ----------
local function theme()
    return { textHi = { 240, 238, 246 }, textDim = { 170, 164, 188 },
        textMuted = { 128, 124, 146 }, accent = { 164, 112, 224 } }
end
-- Поле ввода. В игре поле создаёт буфер и СПЕРВА кладёт в него значение
-- модели (initial); после PA.tabDel буферы «pa*» удаляются — значит при
-- следующем кадре поле обязано снова засеять их из модели. Без этого
-- «выключение» поля затирало бы данные вкладки (стенд ловил именно это).
local function field(_c, id, key, cap, x, y, w, h, hint, multiline, initial)
    if bufs[key] == nil then bufs[key] = tostring(initial or "") end
    return false
end
-- Кнопка в кадре: в игре это im.InvisibleButton; на стенде — карта click.
local function button(_ctx, id) return click[id] == true end
local function chip() end
local function lineH() return 14 end
local function fit(s) return tostring(s) end
-- Перенос строки — как в скрипте (wrapW там настоящий, по замеру ширины).
-- Простая заглушка «одна строка» ломала проверку «ничего не вылезает».
local function wrapW(s, maxW, measure, scale)
    scale = tonumber(scale) or 1
    local function width(t)
        local w = (type(measure) == "function") and measure(t, scale) or (#tostring(t) * 7 * scale)
        return tonumber(w) or 0
    end
    local out, line = {}, ""
    for word in tostring(s or ""):gmatch("%S+") do
        if line == "" then
            line = word
        else
            local cand = line .. " " .. word
            if width(cand) <= maxW then line = cand else out[#out + 1] = line line = word end
        end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
end
local function bufText(k) return bufs[k] or "" end
local function utf8Len(s) return #tostring(s) end
local function clampText(s) return tostring(s) end
local function oneLine(s) return tostring(s) end
local function utf(s) return tostring(s) end
local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
local function byteCut(s, n) return tostring(s):sub(1, n) end
local function utf8Cut(s, n) return tostring(s):sub(1, n) end
local grndLowerUtf, grndUtf8Text = nil, nil
local grndSessionReady = function() return true end
local grndRepQueue = function(cmd) queued[#queued+1] = "rep:" .. tostring(cmd) end
-- заглушка конвертера UTF-8 -> CP1251: помечает строку, чтобы стенд видел,
-- что диагностика лога идёт через конвертер (без него в moonloader.log
-- получались «закорючки»)
local function grndAnsiTextImpl(s) return "[ANSI]" .. tostring(s) end
local grndAnsiText = grndAnsiTextImpl
_G.grndAnsiText = grndAnsiTextImpl
local sampIsPlayerConnected = isConnected
local sampGetPlayerNickname = nickOf
local sampGetLocalPlayerId = myId
local sampSendChat = function(cmd) queued[#queued+1] = "raw:" .. tostring(cmd) end

-- ---------- вывод в moonloader.log ----------
-- Модуль печатает диагностику скриншота обычным print — MoonLoader пишет его
-- в moonloader.log. Перехватываем, чтобы проверить строки стендом.
local shotLog = {}
local function logPrint(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    shotLog[#shotLog + 1] = table.concat(parts, " ")
end
local function lastLog()
    return tostring(shotLog[#shotLog] or "")
end
local function logHas(needle)
    for i = #shotLog, math.max(1, #shotLog - 40), -1 do
        if tostring(shotLog[i]):find(needle, 1, true) then return shotLog[i] end
    end
    return nil
end

-- ---------- загрузка блока ----------
local chunk = "return function(QR, GRND_CONFIG, GRND_LOG, _G, os, string, table, math, pcall, print, type, tostring, tonumber,\n"
    .. "  theme, field, button, chip, lineH, fit, wrapW, bufText, utf8Len, clampText, oneLine, utf, trim, byteCut, utf8Cut,\n"
    .. "  grndLowerUtf, grndUtf8Text, grndSessionReady, grndRepQueue, grndAnsiText,\n"
    .. "  sampIsPlayerConnected, sampGetPlayerNickname, sampGetLocalPlayerId, sampSendChat)\n"
    .. block .. "\nend"
-- ВАЖНО: чанк сам ВОЗВРАЩАЕТ тело-функцию, её и надо вызвать.
local makeBody = assert(loadstring(chunk, "@punauto_module"))
local body = makeBody()
body(QR, GRND_CONFIG, GRND_LOG, _G, os, string, table, math, pcall, logPrint, type, tostring, tonumber,
   theme, field, button, chip, lineH, fit, wrapW, bufText, utf8Len, clampText, oneLine, utf, trim, byteCut, utf8Cut,
   grndLowerUtf, grndUtf8Text, grndSessionReady, grndRepQueue, grndAnsiText,
   sampIsPlayerConnected, sampGetPlayerNickname, sampGetLocalPlayerId, sampSendChat)

local PA = QR.punAuto
local fails, total = 0, 0
local function eq(name, got, exp)
    total = total + 1
    if tostring(got) ~= tostring(exp) then
        fails = fails + 1
        print(string.format("FAIL %-26s got=[%s] exp=[%s]", name, tostring(got), tostring(exp)))
    end
end
local function ok(name, cond) eq(name, cond and "yes" or "no", "yes") end

-- ---------- конфиг: вкладки по умолчанию ----------
PA.ensure()
eq("tabs.default", #PA.tabs, 1)
eq("on.default", PA.on, false)
eq("pause.default", PA.pause, 1.0)
eq("cd.default", PA.cd, 10)
eq("autoId.default", PA.autoId, false)   -- команда уходит ровно как написана
eq("shot.default", PA.shot, true)         -- автоскриншот после выдачи включён
ok("shotDir.default", type(PA.shotDirDefault()) == "string" and #PA.shotDirDefault() > 0)

-- ---------- сохранение/загрузка ----------
PA.tabs[1].trigger = "дм, dm"
PA.tabs[1].cmd = "/mute {ID} 60 флуд"   -- {ID} — документированный способ
PA.tabs[1].mode = "word"
PA.tabs[1].after = "/sp {ID}"
PA.save()
ok("saved.domain", CONFIG["grnd_punauto"] ~= nil)
eq("saved.trigger", tostring(CONFIG["grnd_punauto"]["t1_trigger"]), "дм, dm")
eq("saved.cmd", tostring(CONFIG["grnd_punauto"]["t1_cmd"]), "/mute {ID} 60 флуд")
eq("saved.after", tostring(CONFIG["grnd_punauto"]["t1_after"]), "/sp {ID}")

-- вторая вкладка
eq("tab.add", type(PA.tabAdd()), "number")
eq("tab.count", #PA.tabs, 2)
PA.tabs[2].trigger = "аа"
PA.tabs[2].cmd = "/jail {ID} 10 афк"
PA.tabs[2].mode = "exact"
PA.save()

-- перезагрузка: новая сессия модуля читает то же
QR.punAuto = {}
PA.loaded = false
PA.load()
eq("reload.tabs", #PA.tabs, 2)
eq("reload.trigger1", PA.tabs[1].trigger, "дм, dm")
eq("reload.mode2", PA.tabs[2].mode, "exact")
eq("reload.after1", PA.tabs[1].after, "/sp {ID}")

-- ---------- выдача ----------
PA.on = true
PA.test = false
queued = {}
PA.onChat("Nik_Name[7]: это дм!")
eq("fire.count", #queued, 2)
eq("fire.cmd", queued[1], "/mute 7 60 флуд")
eq("fire.after", queued[2], "/sp 7")
eq("fired.counter", PA.fired, 1)
ok("logged", tostring(logged[#logged]):find("выдано", 1, true) ~= nil)
ok("toast", toasts[#toasts] ~= nil)

-- кулдаун: тот же игрок сразу — повтор не уходит
queued = {}
PA.onChat("Nik_Name[7]: дм снова")
eq("cooldown", #queued, 0)

-- другой игрок — срабатывает (пауза между выдачами вышла по времени)
PA.lastAt = os.clock() - 5
connected[9] = "Vasya_Pupkin"
_G.grndRosterSync()
queued = {}
PA.onChat("[12:00:05] Vasya_Pupkin крикнул: помогите дм")
eq("shout.fire", #queued, 2)
eq("shout.cmd", queued[1], "/mute 9 60 флуд")

-- крик не отслеживается
PA.watchShout = false
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Vasya_Pupkin крикнул: дм")
eq("watchShout.off", #queued, 0)
PA.watchShout = true

-- ООС
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("(( Vasya_Pupkin: dm please ))")
eq("ooc.fire", #queued, 2)
eq("ooc.cmd", queued[1], "/mute 9 60 флуд")
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("(( Vasya_Pupkin: dm please ))!!")   -- уже не ООС-обёртка
ok("ooc.broken.parsed", PA.lastCheck ~= nil)

-- режим проверки: строки разбираются, но НЕ отправляются
PA.test = true
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
local firedBefore = PA.fired
PA.onChat("Nik_Name[7]: дм")
eq("test.no.send", #queued, 0)
eq("test.not.counted", PA.fired, firedBefore)
ok("test.log", tostring(logged[#logged]):find("проверка", 1, true) ~= nil)
PA.test = false

-- выключено — не реагирует вовсе
PA.on = false
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Nik_Name[7]: дм")
eq("off.no.send", #queued, 0)
PA.on = true

-- админ из списка чекера не наказывается
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Admin_One[400]: дм")
eq("skipAdmin", #queued, 0)
ok("skipAdmin.text", tostring(PA.lastCheck):find("администратор", 1, true) ~= nil)

-- себя не наказываем
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Mixa[5]: дм")
eq("skipSelf", #queued, 0)

-- защита от двойного хука: та же строка дважды подряд — один разбор
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Nik_Name[7]: дм дубль")
local n1 = #queued
PA.onChat("Nik_Name[7]: дм дубль")
ok("hook.dedupe", #queued == n1 and n1 > 0)

-- сообщение без триггера иголку не ловит
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Nik_Name[7]: дмитрий привет")
eq("no.trigger", #queued, 0)
ok("no.trigger.text", tostring(PA.lastCheck):find("не найден", 1, true) ~= nil)

-- точное совпадение (режим exact у второй вкладки «аа»)
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Nik_Name[7]: аа")
eq("exact.fire", #queued, 1)
eq("exact.cmd", queued[1], "/jail 7 10 афк")

-- серверные строки не трогаем
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Администратор Mixa: нарушение")
eq("server.line.no", #queued, 0)

-- проверка строки со страницы (dryRun) ничего не отправляет
queued = {}
local out = PA.dryRun("Nik_Name[7]: дм")
ok("dry.run.text", out:find("вкладка 1", 1, true) ~= nil and out:find("/mute 7 60", 1, true) ~= nil)
eq("dry.run.no.send", #queued, 0)

-- вкладка выключена тумблером — молчит
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.tabs[1].on = false
PA.onChat("Nik_Name[7]: дм")
eq("tab.off", #queued, 0)
PA.tabs[1].on = true

-- пустая команда — строка разобрана, но выдачи нет
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.tabs[1].cmd = ""
PA.onChat("Nik_Name[7]: дм пустая")
eq("empty.cmd.no.send", #queued, 0)
ok("empty.cmd.text", tostring(PA.lastCheck):find("Команда", 1, true) ~= nil)
PA.tabs[1].cmd = "/mute {ID} 60 флуд"
PA.save()

-- команда БЕЗ переменных: по умолчанию уходит ровно так, как написана
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.tabs[1].cmd = "/ban Nik_Name 3 дм"
PA.onChat("Nik_Name[7]: дм наконец")
eq("verbatim.send", queued[1], "/ban Nik_Name 3 дм")
-- тумблер «подставлять ID» — только тогда ID встаёт после имени команды
PA.autoId = true
PA.lastAt = os.clock() - 5
PA.cdUntil = {}
queued = {}
PA.onChat("Nik_Name[7]: дм опять")
eq("autoId.send", queued[1], "/ban 7 Nik_Name 3 дм")
PA.autoId = false
PA.tabs[1].cmd = "/mute {ID} 60 флуд"
PA.save()

-- ---------- автоскриншот после выдачи (v1.19.204) ----------
-- Главное отличие от прошлой версии: скрипт не верит вызову плагина (модуль
-- lib.screenshot ничего не возвращает), а ЖДЁТ появления файла и пишет в чат
-- только то, что нашёл. Проверяем оба исхода. У каждого случая своя пустая
-- папка: имя кадра содержит секунды, и файл из прошлой проверки не должен
-- «находиться» в следующей.
local function shotDir(tag)
    local d = "/tmp/grnd_shot_" .. tostring(tag)
    os.execute("rm -rf " .. d .. "; mkdir -p " .. d)
    return d
end

do
    local shots = shotStub.shots
    PA.shotAt, PA.shotWait, PA.shotFail, PA.shotLast = nil, nil, nil, nil
    PA.shot = true
    PA.cdUntil = {}

    -- ---- 1. плагин сохранил файл: успех подтверждается проверкой ----
    shotStub.makeFile, shotStub.dupExt = true, false
    PA.shotDir = shotDir("a")
    local dirA = PA.shotDir
    local before = #shots
    PA.lastAt = os.clock() - 5
    queued = {}
    PA.tabs[1].cmd = "/mute {ID} 60 флуд"
    PA.onChat("Nik_Name[7]: дм для скриншота")
    eq("shot.queued", type(PA.shotAt), "number")          -- задача поставлена
    eq("shot.no.instant", #shots, before)                 -- но кадр ещё не снят
    PA.shotAt = os.clock() - 1                             -- «промотали» задержку
    PA.tick()
    eq("shot.taken", #shots, before + 1)
    eq("shot.dir", shots[#shots].dir, dirA)
    -- плагину имя отдаётся БЕЗ расширения: «.png» он добавляет сам
    ok("shot.name", tostring(shots[#shots].file):match("^grnd_%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d_Nik_Name$") ~= nil)
    ok("shot.name.ext", tostring(shots[#shots].file):find("%.png") == nil)
    eq("shot.saved", PA.shotFail, nil)
    ok("shot.saved.path", tostring(PA.shotLast):match("^" .. dirA .. "/grnd_.+Nik_Name%.png$") ~= nil)
    ok("shot.saved.log", tostring(logged[#logged]):find("сохранён", 1, true) ~= nil)

    -- ---- 2. старая версия плагина дописала «.png» к имени ----
    -- скрипт сам приводит файл к нормальному имени и всё равно подтверждает
    shotStub.dupExt = true
    PA.shotDir = shotDir("b")
    local dirB = PA.shotDir
    PA.shotWait, PA.shotFail, PA.shotLast = nil, nil, nil
    PA.lastAt = os.clock() - 5
    PA.tick()
    PA.shotAt = os.clock() - 1
    PA.tick()
    eq("shot.dup.taken", #shots, before + 2)
    eq("shot.dup.saved", PA.shotFail, nil)
    ok("shot.dup.renamed", tostring(PA.shotLast):match("%.png%.png$") == nil)
    eq("shot.dup.path", tostring(PA.shotLast), dirB .. "/" .. shots[#shots].file .. ".png")
    ok("shot.dup.file", io.open(tostring(PA.shotLast), "rb") ~= nil)
    shotStub.dupExt = false

    -- ---- 3. плагин промолчал: честный провал, а не «сохранено» ----
    shotStub.makeFile = false
    PA.shotDir = shotDir("c")
    PA.shotWait, PA.shotFail, PA.shotLast = nil, nil, nil
    local nf = #shots
    PA.lastAt = os.clock() - 5
    PA.tick()
    PA.shotAt = os.clock() - 1
    PA.tick()
    eq("shot.fail.requested", #shots, nf + 1)              -- запрос ушёл
    eq("shot.fail.not.yet", PA.shotFail, nil)              -- но файла ещё нет
    ok("shot.fail.waiting", type(PA.shotWait) == "table")
    PA.shotWait.untilAt = os.clock() - 1                   -- «прошло 5 секунд»
    PA.tick()
    eq("shot.fail.flag", PA.shotFail, true)
    ok("shot.fail.path", tostring(PA.shotLast):find(PA.shotDir, 1, true) ~= nil)
    ok("shot.fail.log", tostring(logged[#logged]):find("не сохранён", 1, true) ~= nil)
    ok("shot.fail.version", tostring(logged[#logged]):find("(v1.19.", 1, true) ~= nil)
    ok("shot.fail.oneline", tostring(logged[#logged]):find("\n", 1, true) == nil)

    -- ---- 4. своя папка уходит в плагин как есть ----
    shotStub.makeFile = true
    PA.shotDir = shotDir("d")
    PA.shotWait, PA.shotFail = nil, nil
    local n2 = #shots
    PA.lastAt = os.clock() - 5
    PA.tick()
    PA.shotAt = os.clock() - 1
    PA.tick()
    eq("shot.dir.again", shots[n2 + 1].dir, PA.shotDir)
    eq("shot.dir.saved", PA.shotFail, nil)

    -- ---- 5. выключенный тумблер: кадр не делается ----
    PA.shot = false
    PA.shotWait = nil
    eq("shot.off.queue", PA.shotQueue("X"), false)
    PA.shotAt = os.clock() - 1
    PA.tick()
    eq("shot.off.taken", #shots, n2 + 1)
    eq("shot.off.cleared", PA.shotAt, nil)

    PA.shot = true
    PA.shotDir = ""
    PA.shotWait, PA.shotFail, PA.shotLast = nil, nil, nil
    os.execute("rm -rf /tmp/grnd_shot_a /tmp/grnd_shot_b /tmp/grnd_shot_c /tmp/grnd_shot_d")
end

-- ---------- свой кадр через D3D9 (v1.19.205) ----------
-- Сам D3D в стенде не поднять, поэтому проверяем всё вокруг съёмки: задачу
-- ставит тик, кадр снимает обработчик кадра (PA.shotRender), а в чат уходит
-- только то, что получилось. Съёмку и «готовность» подменяем.
do
    -- настоящая съёмка на этой машине невозможна (нет Windows-библиотек), но
    -- она обязана вернуть причину, а не упасть
    local okG, gRes, gWhy = pcall(PA.shotGrab, "/tmp/grnd_shot_x.png")
    ok("self.grab.safe", okG and gRes == false and type(gWhy) == "string")
    -- отдельно про тип методов: этой ошибки быть не должно ни при каком раскладе
    ok("self.grab.no.invalid", tostring(gWhy):find("invalid C type", 1, true) == nil)

    -- без обработчика кадра (нет addEventHandler) свой кадр не предлагается:
    -- иначе задача уходила бы в никуда
    eq("self.off.no.hook", PA.shotSelfReady(), false)

    -- преобразование пути в UTF-16: русские папки («C:\Users\Михаил\...»)
    local wide = PA.shotWide("C:\\Игра\\кадр.png")
    ok("self.wide", wide ~= nil)
    eq("self.wide.c", tonumber(wide[0]), 67)      -- C
    eq("self.wide.cyr", tonumber(wide[3]), 0x418) -- И
    eq("self.wide.cyr2", tonumber(wide[4]), 0x433) -- г
    eq("self.wide.nul", tonumber(wide[16]), 0)    -- терминатор на месте
    eq("self.wide.back", PA.shotUtf8(wide), "C:\\Игра\\кадр.png")   -- и обратно

    -- дальше работаем с подменённой съёмкой
    PA.shotSelfReady = function() return true end
    PA.shotRenderReady = true
    PA.shot = true
    PA.cdUntil = {}
    PA.shotDir = shotDir("e")
    local dirE = PA.shotDir
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    local grabbed = {}
    PA.shotGrab = function(path)
        grabbed[#grabbed + 1] = path
        local f = io.open(path, "wb")
        if not f then return false, "не записалось" end
        f:write("png") f:close()
        return true
    end
    PA.lastAt = os.clock() - 5
    PA.tabs[1].cmd = "/mute {ID} 60 флуд"
    PA.onChat("Nik_Name[7]: дм для своего кадра")
    eq("self.queued", type(PA.shotAt), "number")
    PA.shotAt = os.clock() - 1
    PA.tick()
    eq("self.plan", type(PA.shotJob), "table")
    ok("self.path", tostring(PA.shotJob.path):sub(1, #dirE) == dirE)
    ok("self.path.png", tostring(PA.shotJob.path):match("%.png$") ~= nil)
    eq("self.not.grabbed", #grabbed, 0)          -- кадр снимает поток отрисовки
    PA.shotRender()                              -- ...вот он
    eq("self.grabbed", #grabbed, 1)
    eq("self.result.ok", PA.shotJobResult and PA.shotJobResult.ok or nil, true)
    PA.tick()
    eq("self.saved", PA.shotFail, nil)
    eq("self.saved.path", PA.shotLast, grabbed[1])
    ok("self.saved.log", tostring(logged[#logged]):find("сохранён", 1, true) ~= nil)
    ok("self.saved.toast", tostring(toasts[#toasts]):find("свой кадр", 1, true) ~= nil)
    -- то же самое уходит в moonloader.log
    ok("log.way", logHas("способ: свой кадр (D3D9)") ~= nil)
    ok("log.grab", logHas("снимаю кадр:") ~= nil)
    ok("log.saved", logHas("СОХРАНЕНО:") ~= nil)
    -- перевод в CP1251: в заглушке grndAnsiText мечает строку, поэтому видим,
    -- что лог идёт через конвертер, а не сырым UTF-8
    ok("log.ansi.called", logHas("[ANSI]") ~= nil)
    ok("log.saved.path", logHas(grabbed[1]) ~= nil)

    -- съёмка «удалась», но файла нет — в чат тоже не уходит «сохранён»
    PA.shotGrab = function() return true end                  -- врём: файл не пишем
    shotStub.makeFile = false
    PA.shotDir = shotDir("e2")
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    PA.lastAt = os.clock() - 5
    PA.tick()
    PA.shotAt = os.clock() - 1
    PA.tick()
    PA.shotRender()
    PA.tick()
    eq("self.liar.flag", PA.shotFail, true)
    ok("self.liar.log", tostring(logged[#logged]):find("не сохранён", 1, true) ~= nil)
    os.execute("rm -rf /tmp/grnd_shot_e2")

    -- свой кадр не вышел: сразу подхватывает запасной путь (плагин), и в чат
    -- уходит «сохранён» только по появлению файла, вместе с причиной
    shotStub.makeFile = true
    PA.shotGrab = function() return false, "GetBackBuffer 0x8007000E" end
    PA.shotDir = shotDir("f")
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    PA.lastAt = os.clock() - 5
    PA.tick()                                    -- постановка задачи
    PA.shotAt = os.clock() - 1
    PA.tick()
    PA.shotRender()                              -- съёмка не удалась -> плагин
    ok("self.fb.fallback", PA.shotJobResult and PA.shotJobResult.fallback or false)
    PA.tick()                                    -- замечаем запасной путь
    eq("self.fb.cleared", PA.shotWait and PA.shotWait.job or nil, nil)
    PA.tick()                                    -- плагин уже положил файл
    eq("self.fb.saved", PA.shotFail, nil)
    ok("self.fb.reason", tostring(toasts[#toasts]):find("не вышел", 1, true) ~= nil)
    ok("self.fb.path", tostring(PA.shotLast):find(PA.shotDir, 1, true) ~= nil)
    shotStub.makeFile = false

    -- свой кадр не вышел и запасной путь не дал файла — честный провал
    PA.shotDir = shotDir("g")
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    PA.lastAt = os.clock() - 5
    PA.tick()
    PA.shotAt = os.clock() - 1
    PA.tick()
    PA.shotRender()
    PA.tick()                                    -- просьба к плагину/F8
    ok("self.both.waits", PA.shotWait ~= nil and PA.shotWait.job == nil)
    PA.shotWait.untilAt = os.clock() - 1         -- «прошло 5 секунд»
    PA.tick()                                    -- срок вышел: честный провал
    eq("self.both.fail", PA.shotFail, true)
    ok("self.both.toast", tostring(toasts[#toasts]):find("не появился", 1, true) ~= nil)
    ok("self.both.log", tostring(logged[#logged]):find("не сохранён", 1, true) ~= nil)
    ok("log.fail", logHas("НЕ СОХРАНЕНО:") ~= nil)
    ok("log.fail.reason", logHas("причина:") ~= nil)
    ok("log.self.fail", logHas("свой кадр не вышел:") ~= nil)

    -- обработчик кадра не ответил (свёрнутая игра, чужая сборка MoonLoader):
    -- тик не висит, а просит запасной путь и ждёт файл ещё раз
    shotStub.makeFile = true
    PA.shotDir = shotDir("h")
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    PA.lastAt = os.clock() - 5
    PA.tick()
    PA.shotAt = os.clock() - 1
    PA.tick()                                    -- задача ждёт обработчик
    ok("self.t.waits", PA.shotJob ~= nil and PA.shotWait ~= nil and PA.shotWait.job ~= nil)
    PA.shotWait.untilAt = os.clock() - 1
    PA.tick()                                    -- не дождались -> запасной путь
    eq("self.t.job.cleared", PA.shotJob, nil)
    eq("self.t.job.flag", PA.shotWait and PA.shotWait.job or nil, nil)
    PA.tick()                                    -- плагин уже положил файл
    eq("self.t.saved", PA.shotFail, nil)
    ok("self.t.note", tostring(toasts[#toasts]):find("не ответил", 1, true) ~= nil)
    shotStub.makeFile = false

    -- своя папка не пишется: свой кадр уступает запасному пути (плагин или
    -- «App screens\grnd»), а причина видна в подписи способа
    PA.shotGrab = function() return true end
    PA.shotDir = "/proc/grnd_no_such_dir"
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    local tookOk, tookPlan = PA.shotTake("Nik_Name")
    eq("self.nowrite.take", tookOk, true)
    ok("self.nowrite.reason", tostring(tookPlan and tookPlan.note):find("не вышел", 1, true) ~= nil)
    ok("self.nowrite.note", tostring(tookPlan and tookPlan.note):find("записи", 1, true) ~= nil)
    ok("log.nowrite", logHas("свой кадр не готов:") ~= nil)
    shotStub.makeFile = false

    PA.shotDir = ""
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    os.execute("rm -rf /tmp/grnd_shot_e /tmp/grnd_shot_f /tmp/grnd_shot_g /tmp/grnd_shot_h")
end

-- удаление вкладки
eq("tab.del", PA.tabDel(2) and "yes" or "no", "yes")
eq("tab.del.count", #PA.tabs, 1)
eq("tab.del.save", tostring(CONFIG["grnd_punauto"]["t2_trigger"]), "nil")
eq("tab.del.keys", tostring(CONFIG["grnd_punauto"]["t1_trigger"]), "дм, dm")


-- ================= СМОУК-ТЕСТ СТРАНИЦЫ (заглушка ctx) =================
-- Проверяем, что отрисовщик не падает, читает буферы полей и слушает
-- кнопки вкладок/крестики/плюс. ImGui здесь — таблица-заглушка.
local ctx
do
    local im = {}
    function im.ImVec2(x, y) return { x = x, y = y } end
    function im.SetCursorPos() end
    function im.InvisibleButton(id) return click[id] == true end
    function im.IsItemHovered() return false end
    local dl = {}
    function dl.AddLine() end
    function dl.AddRect() end
    function dl.AddRectFilled() end
    function dl.AddCircleFilled() end
    function dl.AddCircle() end
    ctx = {
        im = im, dl = dl,
        uiText = function() end,
        roundRect = function() end,
        col32 = function(r, g, b, a) return (r or 0) + (g or 0) * 256 end,
        rgba = function(r, g, b, a) return { r, g, b, a } end,
        at = function(x, y) return { x = x, y = y } end,
        drawnW = function(t2) return #tostring(t2) * 7 end,
        tsize = function() return 7, 14 end,
        x = 100, y = 100, w = 700, h = 560,
    }
end

-- вкладка «аа» (exact) удалена в предыдущем тесте, у нас одна вкладка с «дм»
local tabsBefore = #PA.tabs
local okDraw, drawRes = pcall(QR.punAutoDraw, ctx)
ok("draw.ok", okDraw)
eq("draw.res", drawRes, true)

-- буферы полей пишутся в модель
bufs["paTrig1"] = "дм, dm, помогите"
bufs["paCmd1"] = "/mute {ID} 60 флуд"
bufs["paAfter1"] = "/sp {ID}"
pcall(QR.punAutoDraw, ctx)
eq("draw.trig.sync", PA.tabs[1].trigger, "дм, dm, помогите")
eq("draw.cmd.sync", PA.tabs[1].cmd, "/mute {ID} 60 флуд")
eq("draw.after.sync", PA.tabs[1].after, "/sp {ID}")

-- режим word/exact кнопками
click["##grnd_pa_mode_exact"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_mode_exact"] = nil
eq("draw.mode.sync", PA.tabs[1].mode, "exact")
click["##grnd_pa_mode_word"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_mode_word"] = nil
eq("draw.mode.back", PA.tabs[1].mode, "word")

-- тумблер «Проверка» и общий тумблер
PA.test = false
click["##grnd_pa_test"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_test"] = nil
eq("draw.test.toggle", PA.test, true)
PA.test = false
local wasOn = PA.on
click["##grnd_pa_switch"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_switch"] = nil
eq("draw.switch", PA.on ~= wasOn, true)
PA.on = true

-- тумблеры параметров
click["##grnd_pa_tg_notify"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_tg_notify"] = nil
eq("draw.notify.toggle", PA.notify, false)
click["##grnd_pa_tg_notify"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_tg_notify"] = nil
eq("draw.notify.back", PA.notify, true)

-- скриншот: тумблер и поле папки на странице
pcall(QR.punAutoDraw, ctx)
ok("draw.shotdir.seeded", bufs["paShotDir"] ~= nil)
bufs["paShotDir"] = "E:\\shots"
pcall(QR.punAutoDraw, ctx)
eq("draw.shotdir.sync", PA.shotDir, "E:\\shots")
click["##grnd_pa_shot"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_shot"] = nil
eq("draw.shot.toggle", PA.shot, false)
click["##grnd_pa_shot"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_shot"] = nil
eq("draw.shot.back", PA.shot, true)
PA.shotDir = ""
bufs["paShotDir"] = nil

-- «+» добавляет вкладку, крестик удаляет
click["##grnd_pa_add"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_add"] = nil
eq("draw.tab.add", #PA.tabs, tabsBefore + 1)

click["##grnd_pa_tabc_" .. #PA.tabs] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_tabc_" .. #PA.tabs] = nil
eq("draw.tab.del", #PA.tabs, tabsBefore)

-- выбор вкладки
local savedSel = PA.sel
PA.sel = 1
bufs["paTrig2"] = nil
if #PA.tabs >= 2 then
    click["##grnd_pa_tab_2"] = true
    pcall(QR.punAutoDraw, ctx)
    click["##grnd_pa_tab_2"] = nil
    eq("draw.tab.select", PA.sel, 2)
else
    eq("draw.tab.select", PA.sel, 1)
end
PA.sel = savedSel

-- «Разобрать» — dryRun со страницы, ничего не отправляет
bufs["paTestLine"] = "Nik_Name[7]: дм"
queued = {}
click["##grnd_pa_tbtn"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_tbtn"] = nil
eq("draw.testline.no.send", #queued, 0)
ok("draw.testline.out", tostring(PA.testOut):find("вкладка 1", 1, true) ~= nil)

-- ================== ВИДИМОСТЬ СТРАНИЦЫ В РЕАЛЬНОМ ОКНЕ ==================
-- v1.19.203: страница рисуется в ДВЕ КОЛОНКИ и обязана помещаться в
-- настоящую карточку меню целиком. Геометрия под 1920x1080:
--   W=980, SB=224 → cardX=250, cardW=980-26-250=704;
--   cardY=26+19+44=89, cardH=720-26-89=605;
--   кнопки-страницы (16+34+12) и разделитель (14) отнимают 76 px →
--   странице остаётся w=672, h=605-88=517.
-- Раньше (одна колонка) низ страницы — параметры, тумблеры и лента — не
-- влезал: именно эту поломку стенд и ловит.
local seen = {}
-- ширина строки «по-человечески»: считаем символы UTF-8, а не байты, иначе
-- кириллица даёт завышенную оценку и проверка на вылезание врёт
local function utf8chars(text)
    local _, n = tostring(text):gsub("[^\128-\191]", "")
    return n
end
do
    local im = {}
    function im.ImVec2(x2, y2) return { x = x2, y = y2 } end
    function im.SetCursorPos() end
    function im.InvisibleButton() return false end
    function im.IsItemHovered() return false end
    local dl = {}
    function dl.AddLine() end
    function dl.AddRect() end
    function dl.AddRectFilled() end
    function dl.AddCircleFilled() end
    function dl.AddCircle() end
    local ctxFit = {
        im = im, dl = dl,
        uiText = function(x2, y2, t2, _col, scale) seen[#seen + 1] = { x = x2, y = y2, t = tostring(t2), s = tonumber(scale) or 1 } end,
        roundRect = function() end,
        col32 = function(r, g, b, a) return (r or 0) + (g or 0) * 256 end,
        rgba = function(r, g, b, a) return { r, g, b, a } end,
        at = function(x2, y2) return { x = x2, y = y2 } end,
        -- замер как в меню: tsize возвращает ширину строки шрифтом игры
        drawnW = function(t2) return utf8chars(t2) * 6.5 end,
        tsize = function() return 6.5, 14 end,
        x = 100, y = 100, w = 672, h = 514,
    }
    local okFit, errFit = pcall(QR.punAutoDraw, ctxFit)
    ok("drawfit.ok", okFit and "да" or tostring(errFit))
end

local function drawSeen(pat)
    for i = 1, #seen do
        if seen[i].t:find(pat, 1, true) then return true end
    end
    return false
end

-- левая колонка: данные вкладки и скриншот
ok("drawfit.triggers", drawSeen("Триггеры"))
ok("drawfit.mode", drawSeen("Режим поиска"))
ok("drawfit.cmd", drawSeen("Команда (уйдёт"))
ok("drawfit.after", drawSeen("Команда после"))
ok("drawfit.shot.toggle", drawSeen("скриншот после выдачи"))
ok("drawfit.shot.dir", drawSeen("Папка для скриншотов"))
-- правая колонка: проверка строки, параметры, тумблеры, лента
ok("drawfit.testline", drawSeen("Проверка строки"))
ok("drawfit.pause", drawSeen("Пауза между выдачами"))
ok("drawfit.cd", drawSeen("Повтор игроку"))
ok("drawfit.toggles", drawSeen("не трогать себя"))
ok("drawfit.tabon", drawSeen("вкладка включена"))
ok("drawfit.feed", drawSeen("Последние срабатывания"))

-- ничего не нарисовано ниже карточки (y + h - 4 = 610)
local lowest, lowTxt = 0, ""
for i = 1, #seen do
    if seen[i].y > lowest then lowest, lowTxt = seen[i].y, seen[i].t end
end
eq("drawfit.fits", lowest <= 606 and "да" or ("ниже карточки: " .. lowest .. " " .. lowTxt), "да")

-- ни одна надпись не вылезает за правый край карточки (x0 + w = 772)
local overX, overTxt = 0, ""
for i = 1, #seen do
    local e = seen[i]
    local right = (tonumber(e.x) or 0) + utf8chars(e.t) * 6.5 * (e.s or 1)
    if right > overX then overX, overTxt = right, e.t end
end
eq("drawfit.width", overX <= 778 and "да" or (math.floor(overX) .. "px: " .. overTxt), "да")

-- мелкое окно: страница просто ничего не рисует, но не падает
ctx.w, ctx.h = 200, 100
local okSmall = pcall(QR.punAutoDraw, ctx)
ok("draw.small", okSmall)
ctx.w, ctx.h = 700, 560

-- ======== нет Screenshot.asi: скрипт не должен врать про «сохранено» ========
-- Отдельная копия модуля с падающим require и без рабочего ffi.load("user32"):
-- ровно та ситуация, из-за которой в чат уходило «сохранено», а файла не было.
do
    shotStub.broken = true
    -- ровно то, что видно в журнале игрока: require отдаёт три строки с путями
    shotStub.msg = "module 'lib.screenshot' not found:\n"
        .. "\tno file 'C:\\Users\\?\\Desktop\\moonloader\\lib\\lib\\screenshot.lua'\n"
        .. "\tno file 'C:\\Users\\?\\Desktop\\moonloader\\lib\\lib\\screenshot\\init.lua'"
    local QR2 = { bufs = {}, toast = function() end,
        path = function() return "C:\\x.cfg" end,
        myNick = function() return "Mixa" end,
        queueCmd = function() return true end }
    QR2.punAuto = {}
    local body2 = assert(loadstring(chunk, "@punauto_module2"))()
    body2(QR2, GRND_CONFIG, GRND_LOG, _G, os, string, table, math, pcall, logPrint, type, tostring, tonumber,
        theme, field, button, chip, lineH, fit, wrapW, bufText, utf8Len, clampText, oneLine, utf, trim, byteCut, utf8Cut,
        grndLowerUtf, grndUtf8Text, grndSessionReady, grndRepQueue, grndAnsiText,
        sampIsPlayerConnected, sampGetPlayerNickname, sampGetLocalPlayerId, sampSendChat)
    local P2 = QR2.punAuto
    P2.ensure()
    -- 1. плагина нет и F8 нажать нечем — честный провал
    P2.shotDir = ""
    P2.shotQueue("Nik_Name")
    P2.shotAt = os.clock() - 1
    P2.tick()
    -- причина неудачи видна в тексте: почему модуль не загрузился
    ok("shot2.why", tostring(P2.shotWhy):find("lib.screenshot", 1, true) ~= nil)
    ok("shot2.why.oneline", tostring(P2.shotWhy):find("\n", 1, true) == nil)
    ok("shot2.why.short", #tostring(P2.shotWhy) <= 121)
    ok("shot2.report.oneline", tostring(logged[#logged]):find("\n", 1, true) == nil)
    eq("shot2.fail", P2.shotFail, true)
    ok("shot2.reason", tostring(P2.shotLast):find("нет Screenshot.asi", 1, true) ~= nil)
    ok("shot2.no.claim", tostring(logged[#logged]):find("не сохранён", 1, true) ~= nil)
    ok("log.shot2.fail", logHas("НЕ СОХРАНЕНО:") ~= nil)
    ok("log.shot2.fallback", logHas("запасной путь не сработал:") ~= nil)
    -- в логе не должно быть многострочной «простыни» require
    for i = 1, #shotLog do
        if tostring(shotLog[i]):find("init.lua", 1, true) then
            ok("log.shot2.nostack", false)
            break
        end
    end
    ok("log.shot2.nostack", true)

    -- 2. F8 нажали, но проверить негде — тоже без «сохранено»
    _G.setVirtualKeyDown = function() return true end
    P2.shotWait, P2.shotFail, P2.shotLast = nil, nil, nil
    P2.shotQueue("Nik_Name")
    P2.shotAt = os.clock() - 1
    P2.tick()
    eq("shot2.f8.fail", P2.shotFail, true)
    eq("shot2.f8.nowait", P2.shotWait, nil)
    ok("shot2.f8.text", tostring(P2.shotLast):find("F8", 1, true) ~= nil)
    _G.setVirtualKeyDown = nil

    -- 3. ни один вход не должен звать необъявленную функцию: в Lua это
    --    «attempt to call global '...' (a nil value)» — такую правку стенд
    --    обязан ловить (уже ловил: paShotLibs объявлялся позже первого вызова)
    local function noLuaError(fn, ...)
        local pack = { pcall(fn, ...) }
        for i = 1, #pack do
            local v = tostring(pack[i] or "")
            if v:find("attempt to call", 1, true) or v:find("nil value", 1, true)
                or v:find("attempt to index", 1, true) then
                return false, v
            end
        end
        return pack[1] == true, tostring(pack[2] or "")
    end
    local okPath, pathErr = noLuaError(P2.shotTake, "Nik_Name")
    eq("shot2.take.clean", okPath and "да" or pathErr, "да")
    local okDir = noLuaError(P2.shotDirDefault)
    ok("shot2.dir.clean", okDir)
    ok("shot2.dirpath.clean", (noLuaError(P2.shotDirPath)))
    ok("shot2.take.empty", (noLuaError(P2.shotTake, "")))

    -- 4. выключенный тумблер — запроса нет вообще
    P2.shot = false
    eq("shot2.off", P2.shotQueue("X"), false)
    P2.shot = true
    shotStub.broken = false
    shotStub.msg = nil
end

-- ======== хук кадра: кадр снимается в потоке отрисовки ========
-- Без него устройство D3D9 трогать нельзя, а событие onD3DPresent есть не во
-- всех сборках MoonLoader — поэтому кадр привязан к кадру ImGui (меню рисуется
-- всегда). Проверяем, что проводка на месте и её не выкинут правкой.
do
    local function count(needle)
        local n, i = 0, 1
        while true do
            local a, b = src:find(needle, i, true)
            if not a then break end
            n = n + 1
            i = b + 1
        end
        return n
    end
    ok("hook.set", count("_G.grndShotFrame = shotPA.shotRender") == 1)
    ok("hook.want", count("_G.grndShotWant = function() return shotPA.shotJob ~= nil end") == 1)
    ok("hook.flag", count("shotPA.shotFrameHook = true") == 1)
    ok("hook.install", count("_G.grndShotHookInstall = installShotHook") == 1)
    ok("hook.reverse", count("_G.grndShotHookInstall") >= 2)      -- и обратный вызов
    eq("hook.calls", count("pcall(_G.grndShotFrame)"), 3)         -- две обёртки + служебный кадр
    ok("hook.reason", count("нет хука кадра") == 1)
    -- ТИПЫ МЕТОДОВ D3D9. Из-за записи без «(*)» в игре было
    -- «bad argument #1 to 'bind' (invalid C type)»: LuaJIT такие типы не
    -- принимает, и съёмка падала ещё до первого вызова D3D. Проверяем, что в
    -- скрипте нет формы без звёздочки, а все привязки идут через bind().
    do
        local bad = 0
        for line in src:gmatch("[^\n]+") do
            local code = line:gsub("%-%-.*$", "")          -- комментарии не считаем
            if code:find("__stdcall", 1, true) and code:find("bind(", 1, true) then
                if not code:find("(__stdcall*)", 1, true) then bad = bad + 1 end
            end
        end
        eq("d3d.sig.star", bad, 0)
        ok("d3d.bind.count", count("bind(vtbl,") + count("bind(svtbl,") == 6)
        ok("d3d.bind.guard", count("тип метода D3D9 не принят") == 1)
        ok("d3d.front", count("GetFrontBufferData") > 0)   -- запасной путь съёмки
        ok("d3d.iconic", count("передний буфер: окно игры свёрнуто") == 1)   -- не снимаем свёрнутую
    end

    -- paShotLibs должен быть объявлен до первого использования, иначе в игре
    -- это «attempt to call global 'paShotLibs' (a nil value)»
    local declPos = src:find("local function paShotLibs()", 1, true)
    local firstUse = src:find("paShotLibs()", 1, true)
    ok("hook.libs.order", declPos ~= nil and firstUse ~= nil and declPos < firstUse)
    -- готовность кадра проверяет и хук, и устройство, и d3dx9
    ok("hook.ready.self", count("PA.shotSelfWhy = \"не найдено устройство D3D9") == 1)
end

print(string.format("--- модуль автопилота: %d/%d ok ---", total - fails, total))
os.exit(fails == 0 and 0 or 1)
