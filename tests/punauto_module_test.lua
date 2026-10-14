-- Интеграционный стенд модуля автопилота наказаний («Наказания» →
-- «Автопилот»): вырезает do-блок из grnd_adm_tools.lua и гоняет его с
-- заглушками (GRND_CONFIG, QR.toast, samp*, GRND_LOG, ImGui) — без
-- MoonLoader. Проверяет вкладки/конфиг, выдачу по трём видам строк, ОТСУТСТВИЕ
-- задержек (v1.19.211: ни пауз, ни кулдаунов), предохранители
-- (себя/админов/каналы), автоскриншот выдачи и отрисовку страницы (буферы
-- полей, кнопки, тумблеры, плюс/крестик). v1.19.212: режима проверки, «Команды
-- после», ленты срабатываний и переменных команды больше нет, а триггер в
-- кавычках не срабатывает.
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
local toastKinds = {}      -- вид уведомления (ok/warn/info) — цвет на экране
local bufs = {}            -- QR.bufs

local queueCalls = 0       -- сколько раз команда ушла через МЕДЛЕННУЮ очередь
local QR = { bufs = bufs,
    toast = function(t, kind) toasts[#toasts+1] = t toastKinds[#toastKinds+1] = tostring(kind or "") end,
    path = function() return "C:\\samp\\grnd_repquick.cfg" end,
    myNick = function() return "Mixa" end,
    queueCmd = function(cmd) queueCalls = queueCalls + 1 queued[#queued+1] = cmd return true end }
-- v1.19.211: в игре grndChatSend сам переводит строку в CP1251 и отдаёт её в
-- sampSendChat. В стенде — просто запись команды: проверки читают ТЕКСТ команды,
-- а не транспорт, и отдельно следят, что медленная очередь не задействована.
local grndChatSend = function(cmd) queued[#queued+1] = tostring(cmd) return true end
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

-- ---------- lfs (минимум для поиска свежего кадра в папке) ----------
-- Настоящий LuaFileSystem в стенде не поднять, а скрипту нужны только две
-- функции: перебор файлов папки и время правки. Делаем их через оболочку.
_G.libs = _G.libs or {}
_G.libs.lfs = {
    dir = function(path)
        local p = io.popen("ls -1a '" .. tostring(path) .. "' 2>/dev/null")
        if not p then return nil end
        local files = {}
        for line in p:lines() do files[#files + 1] = line end
        p:close()
        if #files == 0 then return nil end
        local i = 0
        return function() i = i + 1 return files[i] end
    end,
    attributes = function(path, what)
        if what ~= "modification" then return nil end
        local p = io.popen("stat -c %Y '" .. tostring(path) .. "' 2>/dev/null")
        if not p then return nil end
        local v = p:read("*l")
        p:close()
        return tonumber(v)
    end,
}

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
local function grndAnsiTextImpl(s)
    s = tostring(s)
    -- как в игре: ASCII остаётся как есть, кириллица переводится в CP1251
    if not s:find("[\128-\255]") then return s end
    return "[ANSI]" .. s
end
local grndAnsiText = grndAnsiTextImpl
_G.grndAnsiText = grndAnsiTextImpl
local sampIsPlayerConnected = isConnected
local sampGetPlayerNickname = nickOf
local sampGetLocalPlayerId = myId
local sampSendChat = function(cmd) queued[#queued+1] = "raw:" .. tostring(cmd) end

-- ---------- вывод в moonloader.log ----------
-- Перехватываем print: MoonLoader пишет его в moonloader.log. Стенд проверяет,
-- что скриншот НЕ оставляет там строк (v1.19.210 диагностику убрали).
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
    .. "  grndLowerUtf, grndUtf8Text, grndSessionReady, grndRepQueue, grndAnsiText, grndChatSend,\n"
    .. "  sampIsPlayerConnected, sampGetPlayerNickname, sampGetLocalPlayerId, sampSendChat)\n"
    .. block .. "\nend"
-- ВАЖНО: чанк сам ВОЗВРАЩАЕТ тело-функцию, её и надо вызвать.
local makeBody = assert(loadstring(chunk, "@punauto_module"))
local body = makeBody()
body(QR, GRND_CONFIG, GRND_LOG, _G, os, string, table, math, pcall, logPrint, type, tostring, tonumber,
   theme, field, button, chip, lineH, fit, wrapW, bufText, utf8Len, clampText, oneLine, utf, trim, byteCut, utf8Cut,
   grndLowerUtf, grndUtf8Text, grndSessionReady, grndRepQueue, grndAnsiText, grndChatSend,
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
-- v1.19.211: настройки задержек убраны вместе с самой задержкой
eq("nodelay.pause", PA.pause, nil)
eq("nodelay.cd", PA.cd, nil)
eq("nodelay.cduntil", PA.cdUntil, nil)
eq("no.test.mode", PA.test, nil)          -- режима проверки больше нет
eq("no.autoId", PA.autoId, nil)           -- ID подставляется всегда, тумблера нет
eq("no.feed", PA.feed, nil)               -- ленты срабатываний больше нет
-- v1.19.213: галочек нет — каналы чата, уведомления и журнал включены всегда,
-- а предохранители «не трогать себя/админов» пока выключены
eq("fixed.watchSay", PA.watchSay, true)
eq("fixed.watchShout", PA.watchShout, true)
eq("fixed.watchOoc", PA.watchOoc, true)
eq("fixed.notify", PA.notify, true)
eq("fixed.logOn", PA.logOn, true)
eq("fixed.skipSelf", PA.skipSelf, false)
eq("fixed.skipAdmins", PA.skipAdmins, true)   -- v1.19.214: админов не трогаем
eq("shot.default", PA.shot, true)         -- автоскриншот после выдачи включён
ok("shotDir.default", type(PA.shotDirDefault()) == "string" and #PA.shotDirDefault() > 0)

-- ---------- сохранение/загрузка ----------
PA.tabs[1].trigger = "дм, dm"
PA.tabs[1].cmd = "/mute 60 2.1 ОП"      -- v1.19.212: без переменных
PA.tabs[1].mode = "word"
PA.save()
ok("saved.domain", CONFIG["grnd_punauto"] ~= nil)
eq("saved.trigger", tostring(CONFIG["grnd_punauto"]["t1_trigger"]), "дм, dm")
eq("saved.cmd", tostring(CONFIG["grnd_punauto"]["t1_cmd"]), "/mute 60 2.1 ОП")
-- настроек, которых больше нет, в конфиг не пишем
eq("saved.no.test", tostring(CONFIG["grnd_punauto"]["test"]), "nil")
eq("saved.no.autoId", tostring(CONFIG["grnd_punauto"]["autoId"]), "nil")
eq("saved.no.after", tostring(CONFIG["grnd_punauto"]["t1_after"]), "nil")
eq("saved.no.tabon", tostring(CONFIG["grnd_punauto"]["t1_on"]), "nil")

-- вторая вкладка
eq("tab.add", type(PA.tabAdd()), "number")
eq("tab.count", #PA.tabs, 2)
PA.tabs[2].trigger = "аа"
PA.tabs[2].cmd = "/jail 10 афк"
PA.tabs[2].mode = "exact"
PA.save()

-- старый конфиг (с переменными, «Командой после» и выключенной вкладкой)
-- читается без ошибок, а лишние ключи просто игнорируются
CONFIG["grnd_punauto"]["t1_cmd"] = "/mute {ID} 60 флуд"
CONFIG["grnd_punauto"]["t1_after"] = "/sp {ID}"
CONFIG["grnd_punauto"]["t1_on"] = "0"
CONFIG["grnd_punauto"]["autoId"] = "1"
CONFIG["grnd_punauto"]["pause"] = "1.00"
CONFIG["grnd_punauto"]["test"] = "1"
CONFIG["grnd_punauto"]["watchShout"] = "0"     -- галочки больше нет
CONFIG["grnd_punauto"]["watchOoc"] = "0"
CONFIG["grnd_punauto"]["notify"] = "0"
CONFIG["grnd_punauto"]["logOn"] = "0"
CONFIG["grnd_punauto"]["skipSelf"] = "1"       -- и предохранители тоже
CONFIG["grnd_punauto"]["skipAdmins"] = "1"

-- перезагрузка: новая сессия модуля читает то же
QR.punAuto = {}
PA.loaded = false
PA.load()
eq("reload.tabs", #PA.tabs, 2)
eq("reload.trigger1", PA.tabs[1].trigger, "дм, dm")
eq("reload.mode2", PA.tabs[2].mode, "exact")
eq("reload.after1", PA.tabs[1].after, nil)     -- «Команды после» больше нет
eq("reload.tabon", PA.tabs[1].on, nil)         -- тумблера вкладки больше нет
eq("reload.test", PA.test, nil)                -- режима проверки больше нет
eq("reload.oldcmd", PA.tabs[1].cmd, "/mute {ID} 60 флуд")   -- прочиталось как есть
-- v1.19.213: значения галочек из старого конфига игнорируются
eq("reload.watchShout", PA.watchShout, true)
eq("reload.watchOoc", PA.watchOoc, true)
eq("reload.notify", PA.notify, true)
eq("reload.logOn", PA.logOn, true)
eq("reload.skipSelf", PA.skipSelf, false)
eq("reload.skipAdmins", PA.skipAdmins, true)

-- ---------- выдача ----------
PA.on = true
PA.tabs[1].cmd = "/mute 60 2.1 ОП"          -- команда без переменных
PA.save()
queued = {}
PA.onChat("Nik_Name[7]: это дм!")
eq("fire.count", #queued, 1)                 -- «Команды после» больше нет
eq("fire.cmd", queued[1], "/mute 7 60 2.1 ОП")   -- ID подставлен сам
eq("fired.counter", PA.fired, 1)
ok("logged", tostring(logged[#logged]):find("выдано", 1, true) ~= nil)
ok("toast", toasts[#toasts] ~= nil)

-- v1.19.211: ЗАДЕРЖЕК НЕТ. Раньше здесь стоял кулдаун и повтор молчал до
-- «Повтора игроку»; теперь та же строка от того же игрока выдаёт сразу.
queued = {}
PA.onChat("Nik_Name[7]: дм снова")
eq("nodelay.repeat", #queued, 1)
eq("nodelay.repeat.cmd", queued[1], "/mute 7 60 2.1 ОП")

-- и вторая строка подряд тоже выдаёт (никакой «паузы между выдачами»)
queued = {}
PA.onChat("Nik_Name[7]: и ещё дм")
eq("nodelay.next.line", #queued, 1)

-- и уходит она НАПРЯМУЮ: медленная очередь репорта (0.35 с на строку) не
-- трогается вовсе — иначе команда ждала бы своей очереди
eq("nodelay.direct.queue", queueCalls, 0)

-- другой игрок — срабатывает
PA.lastAt = os.clock() - 5
connected[9] = "Vasya_Pupkin"
_G.grndRosterSync()
queued = {}
PA.onChat("[12:00:05] Vasya_Pupkin крикнул: помогите дм")
eq("shout.fire", #queued, 1)
eq("shout.cmd", queued[1], "/mute 9 60 2.1 ОП")

-- v1.19.213: каналы чата включены всегда (галочки «крик»/«ООС» больше нет) —
-- даже если кто-то выставит флаг вручную, normalize вернёт его на место
PA.watchShout = false
PA.normalize()
eq("fixed.watchShout.back", PA.watchShout, true)
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Vasya_Pupkin крикнул: дм")
eq("shout.always", #queued, 1)

-- ООС
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("(( Vasya_Pupkin: dm please ))")
eq("ooc.fire", #queued, 1)
eq("ooc.cmd", queued[1], "/mute 9 60 2.1 ОП")
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("(( Vasya_Pupkin: dm please ))!!")   -- уже не ООС-обёртка
ok("ooc.broken.parsed", PA.lastCheck ~= nil)

-- v1.19.212: ТРИГГЕР В КАВЫЧКАХ НЕ СРАБАТЫВАЕТ — «он сказал "дм"» это цитата
do
    local variants = {
        {"q.double", 'он сказал "дм" и всё'},
        {"q.single", "он сказал 'дм'"},
        {"q.guillemet", "он сказал «дм»"},
        {"q.curly", "он сказал “дм”"},
        {"q.only", "«дм»"},
    }
    for i = 1, #variants do
        PA.lastAt = os.clock() - 5
        queued = {}
        PA.onChat("Nik_Name[7]: " .. variants[i][2])
        eq(variants[i][1], #queued, 0)
    end
    -- тот же триггер ВНЕ кавычек в той же строке — работает
    PA.lastAt = os.clock() - 5
    queued = {}
    PA.onChat('Nik_Name[7]: он сказал "привет" а это дм')
    eq("q.outside", #queued, 1)
    eq("q.outside.cmd", queued[1], "/mute 7 60 2.1 ОП")
end

-- выключено — не реагирует вовсе
PA.on = false
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Nik_Name[7]: дм")
eq("off.no.send", #queued, 0)
PA.on = true

-- v1.19.232 — Оптимизация всех систем: выключенный автопилот вообще НЕ
-- разбирает строку: ни разбор «Ник: текст», ни ключ защиты от дублей, ни
-- PA.lastLine. Раньше строка гонялась через полный разбор ещё дважды.
PA.on = false
PA.lastCheck = nil
PA.lastLine = "sentinel"
PA.seenKey, PA.seenAt = "sentinel", os.clock()
queued = {}
PA.onChat("Nik_Name[7]: дм")
eq("off.no.send2", #queued, 0)
eq("off.no.parse", PA.lastLine, "sentinel")
eq("off.no.dedupe", PA.seenKey, "sentinel")
ok("off.reason", tostring(PA.lastCheck):find("выключен", 1, true) ~= nil)
PA.on = true
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Nik_Name[7]: дм")   -- после включения та же строка доходит
eq("off.then.on.fires", #queued, 1)

-- v1.19.214: «не трогать админов» ВКЛЮЧЁН по умолчанию — администратору
-- наказания нет, а себе (предохранитель пока выключен) — есть
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Admin_One[400]: дм")
eq("skipAdmin.on", #queued, 0)
ok("skipAdmin.on.text", tostring(PA.lastCheck):find("администратор", 1, true) ~= nil)

PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Mixa[5]: дм")
eq("skipSelf.off", #queued, 1)
eq("skipSelf.off.cmd", queued[1], "/mute 5 60 2.1 ОП")

-- а если «не трогать админов» снять вручную — наказание опять уйдёт,
-- и normalize вернёт фиксированное значение обратно
PA.skipAdmins = false
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Admin_One[400]: дм")
eq("skipAdmin.off.manual", #queued, 1)
eq("skipAdmin.off.manual.cmd", queued[1], "/mute 400 60 2.1 ОП")
PA.normalize()          -- фиксированные значения возвращаются
eq("skipAdmin.again", PA.skipAdmins, true)
eq("skipSelf.still.off", PA.skipSelf, false)

-- защита от двойного хука: та же строка дважды подряд — один разбор
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Nik_Name[7]: дм дубль")
local n1 = #queued
PA.onChat("Nik_Name[7]: дм дубль")
ok("hook.dedupe", #queued == n1 and n1 > 0)

-- сообщение без триггера иголку не ловит
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Nik_Name[7]: дмитрий привет")
eq("no.trigger", #queued, 0)
ok("no.trigger.text", tostring(PA.lastCheck):find("не найден", 1, true) ~= nil)

-- точное совпадение (режим exact у второй вкладки «аа»)
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Nik_Name[7]: аа")
eq("exact.fire", #queued, 1)
eq("exact.cmd", queued[1], "/jail 7 10 афк")

-- серверные строки не трогаем
PA.lastAt = os.clock() - 5
queued = {}
PA.onChat("Администратор Mixa: нарушение")
eq("server.line.no", #queued, 0)

-- v1.19.212: «Проверки строки» (dryRun) на странице больше нет — функции тоже
eq("no.dryrun", type(PA.dryRun), "nil")

-- пустая команда — строка разобрана, но выдачи нет
PA.lastAt = os.clock() - 5
queued = {}
PA.tabs[1].cmd = ""
PA.onChat("Nik_Name[7]: дм пустая")
eq("empty.cmd.no.send", #queued, 0)
ok("empty.cmd.text", tostring(PA.lastCheck):find("Команда", 1, true) ~= nil)
PA.save()

-- v1.19.212: ПЕРЕМЕННЫХ НЕТ — что написали, то и уходит, а ID встаёт сразу
-- после имени команды (тумблер «ID без переменных» больше не нужен)
PA.lastAt = os.clock() - 5
queued = {}
PA.tabs[1].cmd = "/ban Nik_Name 3 дм"
PA.onChat("Nik_Name[7]: дм наконец")
eq("cmd.with.nick", queued[1], "/ban 7 Nik_Name 3 дм")

-- команда из старого конфига с {ID}: скобки в чат не уходят, ID встаёт на место
PA.lastAt = os.clock() - 5
queued = {}
PA.tabs[1].cmd = "/mute {ID} 60 флуд"
PA.onChat("Nik_Name[7]: дм из старого конфига")
eq("cmd.old.var", queued[1], "/mute 7 60 флуд")

PA.tabs[1].cmd = "/mute 60 2.1 ОП"
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
    -- v1.19.211: тост короткий и ровно про файл — подробности в журнале
    eq("self.saved.toast", tostring(toasts[#toasts]), "Скриншот сохранен")
    eq("self.saved.toast.kind", toastKinds[#toastKinds], "ok")
    -- в moonloader.log по-прежнему ничего не пишем (v1.19.210: заказчик просил
    -- убрать диагностику из лога — итог виден в чате и в журнале скрипта)
    eq("log.quiet.after.save", #shotLog, 0)

    -- съёмка «удалась», но файла нет — в чат тоже не уходит «сохранён»
    PA.shotGrab = function() return true end                  -- врём: файл не пишем
    shotStub.makeFile = false
    PA.shotDir = shotDir("e2")
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    PA.tick()
    PA.shotAt = os.clock() - 1
    PA.tick()
    PA.shotRender()
    PA.tick()
    -- «файла нет после записи» — не приговор: кадр мог лечь чуть позже, поэтому
    -- скрипт ещё раз проверяет папку и молчит, пока не вышли сроки
    eq("self.liar.waits", type(PA.shotWait), "table")
    eq("self.liar.not.yet", PA.shotFail, nil)
    PA.shotWait.untilAt, PA.shotWait.selfAt = os.clock() - 1, os.clock() - 1
    PA.shotWait.altTried = true          -- запасной путь уже пробовали
    PA.tick()
    eq("self.liar.flag", PA.shotFail, true)
    ok("self.liar.log", tostring(logged[#logged]):find("не сохранён", 1, true) ~= nil)
    eq("self.liar.toast", tostring(toasts[#toasts]), "Скриншот не сохранён")
    eq("self.liar.toast.kind", toastKinds[#toastKinds], "warn")
    -- ошибку внутри кадра тик больше НЕ глушит молча (раньше из-за nil в
    -- table.concat кадр просто ничего не делал, а причины не было видно)
    eq("self.liar.no.err", PA.err, nil)
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
    eq("self.fb.toast", tostring(toasts[#toasts]), "Скриншот сохранен")
    -- причина отказа своего кадра — в журнале скрипта, а не в тосте
    ok("self.fb.reason", tostring(logged[#logged]):find("не вышел", 1, true) ~= nil)
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
    eq("self.both.toast", tostring(toasts[#toasts]), "Скриншот не сохранён")
    ok("self.both.log", tostring(logged[#logged]):find("не сохранён", 1, true) ~= nil)
    ok("self.both.path", tostring(PA.shotLast):find(PA.shotDir, 1, true) ~= nil)
    eq("log.quiet.after.fail", #shotLog, 0)

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
    -- свой кадр ждём до selfAt, потом уходим на запасной путь
    PA.shotWait.untilAt = os.clock() - 1
    PA.tick()
    eq("self.t.still.waits", PA.shotWait and PA.shotWait.job or nil, true)
    PA.shotWait.untilAt, PA.shotWait.selfAt = os.clock() - 1, os.clock() - 1
    PA.tick()                                    -- не дождались -> запасной путь
    eq("self.t.job.cleared", PA.shotJob, nil)
    eq("self.t.job.flag", PA.shotWait and PA.shotWait.job or nil, nil)
    PA.tick()                                    -- плагин уже положил файл
    eq("self.t.saved", PA.shotFail, nil)
    eq("self.t.toast", tostring(toasts[#toasts]), "Скриншот сохранен")
    ok("self.t.note", tostring(logged[#logged]):find("не ответил", 1, true) ~= nil)
    shotStub.makeFile = false

    -- ФАЙЛ ЕСТЬ, А ИМЯ ДРУГОЕ. Ровно жалоба заказчика: кадр на диске, а в чат
    -- уходило «не сохранён». Проверяем, что перед отказом папка проверяется ещё
    -- раз и найденный файл идёт в отчёт как «сохранён».
    do
        PA.shotGrab = function() return true end         -- по нужному пути файла нет
        PA.shotDir = shotDir("j")
        local dirJ = PA.shotDir
        PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
        PA.tick()
        PA.shotAt = os.clock() - 1
        PA.tick()
        PA.shotRender()
        -- «свой» кадр лёг в папку другим файлом (другое написание пути/имя)
        local alien = dirJ .. "/grnd_2026-10-12_12-00-00_Nik_Name.png"
        local fA = io.open(alien, "wb")
        if fA then fA:write("png") fA:close() end
        PA.tick()
        eq("find.alien.saved", PA.shotFail, nil)
        eq("find.alien.path", PA.shotLast, alien)
        ok("find.alien.log", tostring(logged[#logged]):find("сохранён", 1, true) ~= nil)
        eq("find.alien.toast", tostring(toasts[#toasts]), "Скриншот сохранен")
        os.execute("rm -rf " .. dirJ)
    end

    -- СЛУЧАЙ ЗАКАЗЧИКА (v1.19.211). Поток отрисовки записал файл ПОЗЖЕ срока
    -- ожидания (низкий FPS, свёрнутая игра, поздний монтаж хука). Раньше заявка к
    -- этому моменту уже уходила на запасной путь, а свой путь из проверки
    -- пропадал — и в чат шло «не сохранён», хотя кадр лежал в указанной папке.
    -- Теперь перед отказом путь и папка проверяются ещё раз: «сохранён».
    do
        PA.shotGrab = function(path)
            local f = io.open(path, "wb")
            if f then f:write("png") f:close() end
            return true
        end
        shotStub.makeFile = false
        PA.shotDir = shotDir("m")
        PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
        PA.tick()
        PA.shotAt = os.clock() - 1
        PA.tick()
        ok("slow.plan", PA.shotJob ~= nil and PA.shotWait ~= nil)
        -- сроки вышли, а поток отрисовки ещё молчит: заявка уходит на запасной путь
        PA.shotWait.untilAt, PA.shotWait.selfAt = os.clock() - 1, os.clock() - 1
        PA.tick()
        eq("slow.job.dropped", PA.shotJob, nil)
        -- ...и только теперь обработчик кадра успел записать свой файл
        local latePath = tostring(PA.shotWait and PA.shotWait.self or "")
        local fL = io.open(latePath, "wb")
        if fL then fL:write("png") fL:close() end
        PA.tick()
        eq("slow.saved", PA.shotFail, nil)
        eq("slow.saved.path", PA.shotLast, latePath)
        eq("slow.saved.toast", tostring(toasts[#toasts]), "Скриншот сохранен")
        os.execute("rm -rf /tmp/grnd_shot_m")
        shotStub.makeFile = true
    end

    -- РЕЗУЛЬТАТ ЧУЖОГО КАДРА. Раньше заявки перекрывались в одном слоте, и отчёт
    -- прошлого кадра выдавался за текущий. Теперь результат принимается только
    -- по своему номеру: чужой просто забирается и ни на что не влияет.
    do
        PA.shotGrab = function(path)
            local f = io.open(path, "wb")
            if f then f:write("png") f:close() end
            return true
        end
        PA.shotDir = shotDir("k")
        PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
        PA.tick()
        PA.shotAt = os.clock() - 1
        PA.tick()
        ok("stale.plan", PA.shotJob ~= nil and PA.shotWait ~= nil)
        PA.shotJobResult = { id = (tonumber(PA.shotWait.id) or 0) + 77, ok = true,
            path = "/tmp/grnd_never.png" }
        PA.tick()
        eq("stale.result.dropped", PA.shotJobResult, nil)
        eq("stale.result.waiting", type(PA.shotWait), "table")
        eq("stale.result.no.report", PA.shotFail, nil)
        eq("stale.result.no.last", PA.shotLast, nil)
        -- и настоящий результат той же заявки по-прежнему принимается
        PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
        PA.shotAt = os.clock() - 1
        PA.tick()
        PA.shotRender()
        PA.tick()
        eq("stale.then.real", PA.shotFail, nil)
        ok("stale.then.real.path", tostring(PA.shotLast):find("/tmp/grnd_shot_k/", 1, true) ~= nil)
        os.execute("rm -rf /tmp/grnd_shot_k")
    end

    -- своя папка не пишется: свой кадр уступает запасному пути (плагин или
    -- «App screens\grnd»), а причина видна в подписи способа
    PA.shotGrab = function() return true end
    PA.shotDir = "/proc/grnd_no_such_dir"
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    local tookOk, tookPlan = PA.shotTake("Nik_Name")
    eq("self.nowrite.take", tookOk, true)
    ok("self.nowrite.reason", tostring(tookPlan and tookPlan.note):find("не вышел", 1, true) ~= nil)
    ok("self.nowrite.note", tostring(tookPlan and tookPlan.note):find("записи", 1, true) ~= nil)
    shotStub.makeFile = false

    PA.shotDir = ""
    PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
    os.execute("rm -rf /tmp/grnd_shot_e /tmp/grnd_shot_f /tmp/grnd_shot_g /tmp/grnd_shot_h")
end

-- ======== свой PNG вместо D3DX (v1.19.209) ========
-- D3DXSaveSurfaceToFile на сборке игрока отвечал D3DXERR_INVALIDDATA
-- (0x88760B59) и на заднем, и на переднем буфере. Теперь PNG собирает сам
-- скрипт: пиксели читаются через LockRect, файл пишется обычным Lua-выводом.
do
    local PNG = PA.pngUtil
    -- эталонные значения: проверены внешним zlib (crc32("123456789"),
    -- adler32("Wikipedia")) — так проверка не сверяется сама с собой
    eq("png.crc.known", PNG.crc32("123456789"), 0xCBF43926)
    eq("png.adler.known", PNG.adler32("Wikipedia"), 300286872)

    local function px(r, g, b) return string.char(r, g, b) end
    local rows = { px(255, 0, 0) .. px(0, 255, 0) .. px(0, 0, 255),
                   px(255, 255, 255) .. px(128, 128, 128) .. px(0, 0, 0) }
    local parts = {}
    for i = 1, #rows do parts[#parts + 1] = "\0" parts[#parts + 1] = rows[i] end
    local raw = table.concat(parts)
    local png = PNG.bytes(raw, 3, 2)
    eq("png.sign", png:sub(1, 8), "\137PNG\r\n\26\n")

    local function u32(s, i)
        local a, b, c, d = s:byte(i, i + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    local pos, kinds, ihdr, idat = 9, {}, nil, {}
    while pos <= #png do
        local ln = u32(png, pos)
        local kind = png:sub(pos + 4, pos + 7)
        local data = png:sub(pos + 8, pos + 8 + ln - 1)
        eq("png.crc." .. kind, u32(png, pos + 8 + ln), PNG.crc32(kind .. data))
        kinds[#kinds + 1] = kind
        if kind == "IHDR" then ihdr = data end
        if kind == "IDAT" then idat[#idat + 1] = data end
        pos = pos + 12 + ln
    end
    eq("png.chunks", table.concat(kinds, ","), "IHDR,IDAT,IEND")
    eq("png.width", u32(ihdr, 1), 3)
    eq("png.height", u32(ihdr, 5), 2)
    eq("png.depth", ihdr:byte(9), 8)
    eq("png.colortype", ihdr:byte(10), 2)   -- 2 = RGB

    -- поток zlib: если он несжатый (zlib в системе нет), проверяем пиксели
    -- ровно теми байтами, что подали
    local z = table.concat(idat)
    local function inflateStored(x)
        if x:byte(1) ~= 0x78 then return nil end
        local i, out = 3, {}
        while i <= #x do
            local hdr = x:byte(i) i = i + 1
            if math.floor(hdr / 2) % 4 ~= 0 then return nil end
            local len = x:byte(i) + x:byte(i + 1) * 256
            i = i + 4
            out[#out + 1] = x:sub(i, i + len - 1)
            i = i + len
            if hdr % 2 == 1 then break end
        end
        return table.concat(out)
    end
    local back = inflateStored(z)
    if back then eq("png.pixels", back, raw) else ok("png.pixels", true) end

    -- ЧТЕНИЕ ПИКСЕЛЕЙ. Настоящий D3D в стенде не поднять, поэтому собираем
    -- поддельную поверхность: указатель на таблицу методов, в ней LockRect
    -- (13-й метод) отдаёт буфер пикселей, UnlockRect (14-й) считает вызовы.
    local ffi = require("ffi")
    pcall(ffi.cdef, [[typedef struct { int Pitch; void* pBits; } grnd_shot_locked_rect;]])
    local keep, unlocks = {}, 0
    local function fakeSurface(buf, pitch)
        local data = ffi.new("uint8_t[?]", #buf)
        ffi.copy(data, buf, #buf)
        local vtable = ffi.new("void*[16]")
        local lock = ffi.cast("int(__stdcall*)(void*, void*, const void*, unsigned long)",
            function(_self, rect)
                -- та же структура, что в скрипте: Pitch + указатель
                local p = ffi.cast("grnd_shot_locked_rect*", rect)
                p.Pitch = pitch
                p.pBits = ffi.cast("void*", data)
                return 0
            end)
        local unlock = ffi.cast("int(__stdcall*)(void*)", function() unlocks = unlocks + 1 return 0 end)
        vtable[13] = ffi.cast("void*", lock)
        vtable[14] = ffi.cast("void*", unlock)
        local holder = ffi.new("void*[1]")
        holder[0] = ffi.cast("void*", vtable)
        keep[#keep + 1] = { lock = lock, unlock = unlock, data = data, vtable = vtable, holder = holder }
        return ffi.cast("void*", holder)
    end

    -- A8R8G8B8 (21): в памяти B,G,R,A -> на выходе R,G,B
    local surf = fakeSurface(string.char(1, 2, 3, 4, 5, 6, 7, 8), 8)
    local out, wOut = PA.pngRows(surf, 21, 2, 1, nil)
    eq("pix.bgra.w", wOut, 2)
    eq("pix.bgra", tostring(out and out[1]), string.char(3, 2, 1, 7, 6, 5))
    eq("pix.unlock", unlocks, 1)

    -- R8G8B8 (20): байты идут как есть
    local surf2 = fakeSurface(string.char(9, 8, 7, 6, 5, 4), 6)
    local out2 = PA.pngRows(surf2, 20, 2, 1, nil)
    eq("pix.rgb", tostring(out2 and out2[1]), string.char(9, 8, 7, 6, 5, 4))

    -- 16-битный R5G6B5 (23): белый (0xFFFF) и красный (0xF800)
    local surf3 = fakeSurface(string.char(0xFF, 0xFF, 0x00, 0xF8), 4)
    local out3 = PA.pngRows(surf3, 23, 2, 1, nil)
    eq("pix.565", tostring(out3 and out3[1]), string.char(255, 255, 255, 255, 0, 0))

    -- обрезка кадра (передний буфер — весь экран, а нужен только окно игры)
    local surf4 = fakeSurface(string.char(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12), 12)
    local out4 = PA.pngRows(surf4, 21, 3, 1, { left = 1, top = 0, right = 3, bottom = 1 })
    eq("pix.crop", tostring(out4 and out4[1]), string.char(7, 6, 5, 11, 10, 9))

    -- «перевёрнутый» кадр (pitch < 0): в памяти строки лежат снизу вверх, то
    -- есть первый пиксель буфера — НИЖНЯЯ строка кадра (1,2,3,4 -> 3,2,1), а
    -- верхняя строка кадра (5,6,7,8 -> 7,6,5) идёт в файл первой
    local surf5 = fakeSurface(string.char(1, 2, 3, 4, 5, 6, 7, 8), -4)
    local out5 = PA.pngRows(surf5, 21, 1, 2, nil)
    eq("pix.flip.first", tostring(out5 and out5[1]), string.char(7, 6, 5))
    eq("pix.flip.second", tostring(out5 and out5[2]), string.char(3, 2, 1))

    -- неизвестный формат — понятная причина, а не падение
    local bad, badErr = PA.pngRows(surf, 99, 2, 1, nil)
    eq("pix.badfmt", bad, nil)
    ok("pix.badfmt.why", tostring(badErr):find("не поддержан", 1, true) ~= nil)

    -- и в самой съёмке свой PNG идёт ПЕРВЫМ, а D3DX — только запасным
    local function cnt(needle)
        local n, i = 0, 1
        while true do
            local a, b = src:find(needle, i, true)
            if not a then break end
            n = n + 1
            i = b + 1
        end
        return n
    end
    -- сквозная проверка: поверхность -> PNG -> файл на диске
    local surfW = fakeSurface(string.char(1, 2, 3, 4, 5, 6, 7, 8), 8)
    local file = "/tmp/grnd_png_write_test.png"
    local okW, note = PA.pngWrite(surfW, 21, 2, 1, nil, file)
    eq("png.write.ok", okW, true)
    ok("png.write.note", tostring(note):find("2x1", 1, true) ~= nil)
    local fW = io.open(file, "rb")
    local body = fW and fW:read("*a") or ""
    if fW then fW:close() end
    eq("png.write.sign", body:sub(1, 8), "\137PNG\r\n\26\n")
    ok("png.write.bytes", #body > 40)
    os.remove(file)

    ok("png.used.back", cnt("paShotSelfWrite(dst[0], fmt, w, h, nil, path)") == 1)
    ok("png.used.front", cnt("paShotSelfWrite(dst[0], D3D_A8R8G8B8,") == 1)
end

-- ======== путь для кадров (v1.19.210) ========
-- Жалоба: «указываю путь, а файлов там нет». Причины были две:
--   1) относительный путь уходил в «Документы\GTA San Andreas User Files\App
--      screens» вместо папки игры — его там никто не искал;
--   2) путь с русскими буквами (а у заказчика и логин «Я») в UTF-8 не открывался
--      файловыми функциями Windows, которым нужна системная кодировка (CP1251).
do
    local shots = shotStub.shots
    PA.shotSelfReady = function() return true end
    PA.shotRenderReady = true
    PA.shot = true
        PA.lastAt = os.clock() - 5
    PA.tabs[1].cmd = "/mute {ID} 60 флуд"

    -- папка игры: относительный путь должен разрешаться от неё
    local GAME = "/tmp/grnd_shot_game"
    os.execute("rm -rf " .. GAME .. "; mkdir -p " .. GAME)
    _G.getWorkingDirectory = function() return GAME end

    local function targetFor(dir)
        PA.shotDir = dir
        PA.shotWait, PA.shotFail, PA.shotLast, PA.shotJob, PA.shotJobResult = nil, nil, nil, nil, nil
        local okTake, plan = PA.shotTake("Mik")
        return okTake, plan
    end

    -- 1. пусто: папка рядом со скриптом (в стенде это «resource/grnd/screenshots»)
    -- в игре папку создаёт createDirectory, в стенде — mkdir оболочки
    PA.shotDir = ""
    PA.shotDirShownRaw, PA.shotDirShownVal = nil, nil
    os.execute("mkdir -p '" .. PA.shotDirShow() .. "'")
    local okEmpty, planEmpty = targetFor("")
    eq("dir.empty.take", okEmpty, true)
    ok("dir.empty.self", tostring(planEmpty and planEmpty.self):find("resource" .. "/" .. "grnd", 1, true) ~= nil)
    os.execute("rm -rf " .. GAME .. "/\\.*resource*")

    -- 2. относительный путь: от ПАПКИ ИГРЫ, а не от «Документов»
    os.execute("mkdir -p " .. GAME .. "/Скрины")
    local okRel, planRel = targetFor("Скрины")
    eq("dir.rel.take", okRel, true)
    eq("dir.rel.path", tostring(planRel and planRel.self),
        GAME .. "/Скрины/" .. tostring(planRel and planRel.self):match("([^/]+)$"))
    ok("dir.rel.not.documents", tostring(planRel and planRel.self):find("App screens", 1, true) == nil)

    -- 3. кавычки по краям (частая вставка из проводника) снимаются
    os.execute("mkdir -p " .. GAME .. "/quoted")
    local okQuote, planQuote = targetFor('"' .. GAME .. '/quoted"')
    eq("dir.quotes.take", okQuote, true)
    eq("dir.quotes.path", tostring(planQuote and planQuote.self):match("^(.*)/[^/]+$"), GAME .. "/quoted")

    -- 4. полный путь берётся как есть (тот же каталог, что и указан)
    os.execute("mkdir -p " .. GAME .. "/abs")
    local okAbs, planAbs = targetFor(GAME .. "/abs")
    eq("dir.abs.take", okAbs, true)
    eq("dir.abs.path", tostring(planAbs and planAbs.self):match("^(.*)/[^/]+$"), GAME .. "/abs")

    -- 5. два написания пути: как в настройке и в системной кодировке
    local many = PA.shotPathList(GAME .. "/Скрины")
    eq("dir.variants.count", #many, 2)
    eq("dir.variants.first", many[1], GAME .. "/Скрины")
    ok("dir.variants.second", tostring(many[2]) ~= tostring(many[1]))
    eq("dir.variants.ascii", #PA.shotPathList(GAME .. "/screens"), 1)

    -- 6. недоступная папка — честный отказ с причиной (никакой тихой подмены)
    local okBad, planBad = targetFor("/proc/grnd_no_such_dir")
    eq("dir.bad.take", okBad, true)                       -- кадр всё равно будет
    ok("dir.bad.reason", tostring(planBad and planBad.note):find("записи", 1, true) ~= nil)
    ok("dir.bad.keeps.path", tostring(planBad and planBad.self) == "" or planBad.self == nil)

    -- 7. на странице показан тот путь, куда файл реально ляжет
    PA.shotDir = "Скрины"
    PA.shotDirShownRaw, PA.shotDirShownVal = nil, nil
    eq("dir.shown", PA.shotDirShow(), GAME .. "/Скрины")
    PA.shotDir = ""
    PA.shotDirShownRaw, PA.shotDirShownVal = nil, nil
    ok("dir.shown.empty", tostring(PA.shotDirShow()):find("resource", 1, true) ~= nil)

    _G.getWorkingDirectory = nil
    PA.shotDir = ""
    PA.shotSelfReady = function() return false end
    os.execute("rm -rf " .. GAME)
end

-- удаление вкладки
eq("tab.del", PA.tabDel(2) and "yes" or "no", "yes")
eq("tab.del.count", #PA.tabs, 1)
eq("tab.del.save", tostring(CONFIG["grnd_punauto"]["t2_trigger"]), "nil")
eq("tab.del.keys", tostring(CONFIG["grnd_punauto"]["t1_trigger"]), "дм, dm")
-- v1.19.211: настройки задержек в конфиг не возвращаются (и старые значения
-- из чужого конфига игнорируются при загрузке)
eq("nodelay.not.saved.pause", tostring(CONFIG["grnd_punauto"]["pause"]), "nil")
eq("nodelay.not.saved.cd", tostring(CONFIG["grnd_punauto"]["cd"]), "nil")


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
bufs["paCmd1"] = "/mute 60 2.1 ОП"
bufs["paAfter1"] = "/sp {ID}"          -- «Команды после» больше нет: буфер лишний
pcall(QR.punAutoDraw, ctx)
eq("draw.trig.sync", PA.tabs[1].trigger, "дм, dm, помогите")
eq("draw.cmd.sync", PA.tabs[1].cmd, "/mute 60 2.1 ОП")
eq("draw.after.gone", PA.tabs[1].after, nil)

-- режим word/exact кнопками
click["##grnd_pa_mode_exact"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_mode_exact"] = nil
eq("draw.mode.sync", PA.tabs[1].mode, "exact")
click["##grnd_pa_mode_word"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_mode_word"] = nil
eq("draw.mode.back", PA.tabs[1].mode, "word")

-- v1.19.212: выбора «Проверка» на странице больше нет — клик по нему ничего не
-- делает (и самого элемента нет)
click["##grnd_pa_test"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_test"] = nil
eq("draw.test.gone", PA.test, nil)

-- общий тумблер автопилота в шапке
local wasOn = PA.on
click["##grnd_pa_switch"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_switch"] = nil
eq("draw.switch", PA.on ~= wasOn, true)
PA.on = true

-- v1.19.213: галочек на странице нет — клик по их именам ничего не меняет
for _, key in ipairs({ "notify", "logOn", "watchSay", "watchShout", "watchOoc",
                       "skipSelf", "skipAdmins" }) do
    click["##grnd_pa_tg_" .. key] = true
    pcall(QR.punAutoDraw, ctx)
    click["##grnd_pa_tg_" .. key] = nil
end
eq("draw.toggles.gone.notify", PA.notify, true)
eq("draw.toggles.gone.logOn", PA.logOn, true)
eq("draw.toggles.gone.watchSay", PA.watchSay, true)
eq("draw.toggles.gone.watchShout", PA.watchShout, true)
eq("draw.toggles.gone.watchOoc", PA.watchOoc, true)
eq("draw.toggles.gone.skipSelf", PA.skipSelf, false)
eq("draw.toggles.gone.skipAdmins", PA.skipAdmins, true)

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

-- «Проверка строки (образец строки чата)» убрана: её элементов на странице нет
bufs["paTestLine"] = "Nik_Name[7]: дм"
queued = {}
click["##grnd_pa_tbtn"] = true
pcall(QR.punAutoDraw, ctx)
click["##grnd_pa_tbtn"] = nil
eq("draw.testline.no.send", #queued, 0)
eq("draw.testline.gone", PA.testOut, nil)

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
ok("drawfit.cmd", drawSeen("Команда наказания"))
ok("drawfit.id.hint", drawSeen("ID игрока подставляется сам"))
ok("drawfit.shot.toggle", drawSeen("скриншот после выдачи"))
ok("drawfit.shot.dir", drawSeen("Папка для скриншотов"))
-- подсказок под папкой больше нет (v1.19.213)
eq("drawfit.no.files.hint", drawSeen("Файлы:") and "есть" or "нет", "нет")
eq("drawfit.no.empty.hint", drawSeen("Пусто —") and "есть" or "нет", "нет")
-- правая колонка (v1.19.212): режим поиска переехал сюда, дальше тумблеры
ok("drawfit.mode", drawSeen("Режим поиска"))
ok("drawfit.nodelay", drawSeen("Задержек нет"))
eq("drawfit.no.toggles", drawSeen("не трогать себя") and "есть" or "нет", "нет")
eq("drawfit.no.chat.toggles", drawSeen("обычный чат") and "есть" or "нет", "нет")
eq("drawfit.no.notify.toggle", drawSeen("уведомления") and "есть" or "нет", "нет")
-- убранное со страницы (чтобы не вернулось правкой)
eq("drawfit.no.after", drawSeen("Команда после") and "есть" or "нет", "нет")
eq("drawfit.no.testline", drawSeen("Проверка строки") and "есть" or "нет", "нет")
eq("drawfit.no.test.toggle", drawSeen("Проверка") and "есть" or "нет", "нет")
eq("drawfit.no.tabon", drawSeen("вкладка включена") and "есть" or "нет", "нет")
eq("drawfit.no.autopilot.line", drawSeen("автопилот включ") and "есть" or "нет", "нет")
eq("drawfit.no.feed", drawSeen("Последние срабатывания") and "есть" or "нет", "нет")
eq("drawfit.no.vars", drawSeen("подстановки") and "есть" or "нет", "нет")
eq("drawfit.no.trig.hint", drawSeen("Ищем в тексте") and "есть" or "нет", "нет")
eq("drawfit.no.autoId.toggle", drawSeen("ID без переменных") and "есть" or "нет", "нет")
eq("drawfit.no.pause.field", drawSeen("Пауза между выдачами") and "есть" or "нет", "нет")
eq("drawfit.no.cd.field", drawSeen("Повтор игроку") and "есть" or "нет", "нет")

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
        grndLowerUtf, grndUtf8Text, grndSessionReady, grndRepQueue, grndAnsiText, grndChatSend,
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
    eq("log.quiet.no.plugin", #shotLog, 0)   -- и без плагина в лог ничего не идёт

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
    -- ЗАДЕРЖЕК НЕТ (v1.19.211): ни констант паузы/кулдауна, ни их полей —
    -- чтобы «пауза между выдачами» не вернулась правкой.
    eq("nodelay.no.gap.const", count("GAP_DEF") + count("CD_DEF"), 0)
    eq("nodelay.no.cduntil", count("cdUntil"), 0)
    eq("nodelay.no.pause.field", count("PA.pause"), 0)
    -- команда уходит ПРЯМОЙ отправкой, а очередь репорта (0.35 с на строку) —
    -- только последний запас
    eq("nodelay.direct", count("if type(QR.sendChat) == \"function\" then"), 1)
    eq("nodelay.queue.last", count("последний запас: очередь репорта"), 1)
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
