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
local function wrapW(s) return { tostring(s) } end
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
local grndAnsiText = function(s) return s end
local sampIsPlayerConnected = isConnected
local sampGetPlayerNickname = nickOf
local sampGetLocalPlayerId = myId
local sampSendChat = function(cmd) queued[#queued+1] = "raw:" .. tostring(cmd) end

-- ---------- загрузка блока ----------
local chunk = "return function(QR, GRND_CONFIG, GRND_LOG, _G, os, string, table, math, pcall, print, type, tostring, tonumber,\n"
    .. "  theme, field, button, chip, lineH, fit, wrapW, bufText, utf8Len, clampText, oneLine, utf, trim, byteCut, utf8Cut,\n"
    .. "  grndLowerUtf, grndUtf8Text, grndSessionReady, grndRepQueue, grndAnsiText,\n"
    .. "  sampIsPlayerConnected, sampGetPlayerNickname, sampGetLocalPlayerId, sampSendChat)\n"
    .. block .. "\nend"
-- ВАЖНО: чанк сам ВОЗВРАЩАЕТ тело-функцию, её и надо вызвать.
local makeBody = assert(loadstring(chunk, "@punauto_module"))
local body = makeBody()
body(QR, GRND_CONFIG, GRND_LOG, _G, os, string, table, math, pcall, print, type, tostring, tonumber,
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

-- мелкое окно: страница просто ничего не рисует, но не падает
ctx.w, ctx.h = 200, 100
local okSmall = pcall(QR.punAutoDraw, ctx)
ok("draw.small", okSmall)
ctx.w, ctx.h = 700, 560

print(string.format("--- модуль автопилота: %d/%d ok ---", total - fails, total))
os.exit(fails == 0 and 0 or 1)
