-- =====================================================================
-- Стенд v1.19.249: серверное окно не блокирует окна скрипта.
--
-- Правило скрипта: серверное окно (диалог SA-MP) — это просто окно.
-- Оно не отключает ни клавиши скрипта, ни его окна: скрипт рисует свои
-- окна поверх серверного. Отключать работу скрипта может только
-- собственное окно авторизации (и только пока игрок не в игре).
--
-- Стенд вырезает из скрипта ровно тот код, который уходит в игру
-- (функции grndServerDialogOpen / grndAuthDialogOpen / grndUiBlocked),
-- кормит его заглушками SA-MP и смотрит, что интерфейс скрипта:
--   1) рисуется при обычном серверном окне;
--   2) НЕ прячется при серверном окне, похожем на авторизацию, если
--      игрок уже в игре;
--   3) прячется на экране входа (окно авторизации до спавна);
--   4) отпускается, если подтверждения входа так и не пришло
--      (защёлка не должна блокировать интерфейс навсегда).
--
-- Вторая часть стенда — проверки по исходнику: в скрипте не должно быть
-- отладочных печатей в консоль (они сыпались в лог сами по себе) и
-- ни одна ветка не должна снова гасить окна скрипта по серверному окну.
-- =====================================================================

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

local function cut(a, b)
    local i = src:find(a, 1, true)
    assert(i, "нет якоря: " .. a)
    local j = src:find(b, i, true)
    assert(j, "нет второго якоря: " .. b)
    return src:sub(i, j - 1)
end

local fails, total = 0, 0
local function eq(name, got, exp)
    total = total + 1
    if tostring(got) ~= tostring(exp) then
        fails = fails + 1
        print(string.format("FAIL %-28s got=[%s] exp=[%s]", name, tostring(got), tostring(exp)))
    end
end
local function ok(name, cond)
    total = total + 1
    if not cond then
        fails = fails + 1
        print("FAIL " .. name)
    end
end

-- =====================================================================
--  Часть 1. Поведение интерфейса при серверном окне
-- =====================================================================
local chunk = "return function()\n"
    .. "local GRND_GATE = { blockedFrames = 0, suppressed = 0, why = '', unblockAt = 0 }\n"
    .. "GRND_GATE.authSeen = false\n"
    .. "GRND_GATE.authGrace = 6\n"
    .. cut("local function grndU8Put(cp)", "local function grndCp1251ToUtf8(s)")
    .. cut("function grndLowerUtf(s)", "function grndWeaponFold(s)")
    .. cut("function grndServerDialogOpen()", "GRND_GATE = GRND_GATE or {")
    .. cut("local GRND_AUTH_TITLE_MARKERS = {", "function grndUiWantsToShow()")
    .. "\nreturn { server = grndServerDialogOpen, auth = grndAuthDialogOpen,"
    .. " blocked = grndUiBlocked, expired = grndAuthWaitExpired, gate = GRND_GATE }\n"
    .. "end"

local D = assert(loadstring(chunk, "@dlgpolicy"))()()

-- Заглушки SA-MP: их состоянием управляет стенд.
local state = {
    dialog = false, caption = "", text = "", spawned = false,
}
_G.sampIsDialogActive = function() return state.dialog end
_G.sampGetDialogCaption = function() return state.caption end
_G.sampGetDialogText = function() return state.text end
_G.sampIsLocalPlayerSpawned = function() return state.spawned end
_G.GRND_AUTH_STATE = { showedAuthOk = false, windowSeen = false }

-- Свои часы: защёлка авторизации живёт по os.clock().
local clock = 100
local realClock = os.clock
os.clock = function() return clock end

local function reset(over)
    state.dialog = false
    state.caption = ""
    state.text = ""
    state.spawned = false
    _G.GRND_AUTH_STATE = { showedAuthOk = false, windowSeen = false }
    D.gate.authSeen = false
    D.gate.unblockAt = 0
    D.gate.why = ""
    if over then for k, v in pairs(over) do state[k] = v end end
end

-- 1) обычное серверное окно (магазин) при игроке в игре:
--    интерфейс скрипта показывается, окно авторизации не считается.
reset({ dialog = true, caption = "Магазин", text = "Купить что-нибудь", spawned = true })
eq("srv.open", D.server(), true)
eq("srv.notAuth", D.auth(), false)
eq("srv.uiShown", D.blocked(), false)

-- 2) серверное окно без спавна (экран входа) — интерфейс скрыт,
--    но это «не в игре», а не серверное окно.
reset({ dialog = true, caption = "Магазин", text = "Купить", spawned = false })
eq("preSpawn.uiHidden", D.blocked(), true)
eq("preSpawn.why", D.gate.why, "не в игре")

-- 3) окно авторизации до спавна — интерфейс скрыт, это наше окно.
reset({ dialog = true, caption = "Вход", text = "Введите пароль", spawned = false })
eq("auth.open", D.auth(), true)
eq("auth.uiHidden", D.blocked(), true)
eq("auth.why", D.gate.why, "окно авторизации")

-- 4) то же окно, но игрок уже в игре: это обычное серверное окно,
--    интерфейс скрипта не прячется.
reset({ dialog = true, caption = "Вход", text = "Введите пароль", spawned = true })
eq("authAfterSpawn.notAuth", D.auth(), false)
eq("authAfterSpawn.uiShown", D.blocked(), false)

-- 5) защёлка: окно авторизации видели, потом сервер его закрыл, а
--    подтверждения входа нет. Сначала ждём (окно авторизации ждёт
--    подтверждения), потом защёлка снимается и интерфейс возвращается.
reset({ dialog = true, caption = "Вход", text = "Введите пароль", spawned = false })
eq("latch.firstHidden", D.blocked(), true)
state.dialog = false
state.spawned = true
clock = 200
eq("latch.waitHidden", D.blocked(), true)
eq("latch.why", D.gate.why, "ожидание подтверждения авторизации")
clock = 203
eq("latch.stillHidden", D.blocked(), true)
clock = 210
eq("latch.released", D.blocked(), false)
eq("latch.whyAfter", D.gate.why, "")

-- 6) подтверждение входа снимает ожидание сразу.
reset({ dialog = true, caption = "Вход", text = "Введите пароль", spawned = false })
eq("latch.okHidden", D.blocked(), true)
state.dialog = false
state.spawned = true
_G.GRND_AUTH_STATE.showedAuthOk = true
clock = 220
eq("latch.okShown", D.blocked(), false)

os.clock = realClock

-- =====================================================================
--  Часть 2. Проверки по исходнику: лог чистый, окна не гасятся
-- =====================================================================

-- 2.1 Отладочных печатей в консоль быть не должно: раньше скрипт
--     печатал состояние в лог каждый кадр — данные сыпались сами.
--     Проверяем слово целиком: в скрипте его быть не должно вовсе.
eq("log.noDebugPrints", select(2, src:gsub("DEBUG", "")), 0)

-- 2.2 Блокировка клавиш не должна зависеть от серверного окна:
--     блокирует только окно авторизации.
local keysChunk = cut("local function grndKeysTick()", "GRND_ONTERM = GRND_ONTERM or {}")
ok("keys.noServerDialog", keysChunk:find("sampIsDialogActive", 1, true) == nil)
ok("keys.usesAuthWindow", keysChunk:find("grndAuthDialogOpen()", 1, true) ~= nil)

-- 2.3 Таблица скрипта (Tab) открывается поверх серверного окна.
local tabChunk = cut("\n    if wp == 0x09 then", "\n    if wp == GRND_MENU_HOTKEY then")
ok("tab.noServerDialog", tabChunk:find("sampIsDialogActive", 1, true) == nil)

-- 2.4 Формы (Y/N) принимаются и при открытом серверном окне.
local formsChunk = cut("function grndFormsKeyTick()", "function grndFormAdminLine(")
ok("forms.noServerDialog", formsChunk:find("sampIsDialogActive", 1, true) == nil)

-- 2.5 Окно новостей (Y/N) — то же самое.
local gnewsChunk = cut("local wantAccept, wantReject = false, false",
    "local resX, resY = getScreenResolution()")
ok("gnews.noServerDialog", gnewsChunk:find("sampIsDialogActive", 1, true) == nil)

-- 2.6 Окно статистики рисуется поверх серверного окна.
local statsChunk = cut("_G.grndDrawStatsPopup = function()", "local RC = GRND_RC")
ok("stats.noServerDialog", statsChunk:find("sampIsDialogActive", 1, true) == nil)

-- 2.7 Серверное окно не считается «печатью» (иначе хоткеи уступают).
local typingChunk = cut("function grndIsTyping()", "function grndCamWindowsRaw()")
ok("typing.noServerDialog", typingChunk:find("sampIsDialogActive", 1, true) == nil)

-- 2.8 В интерфейсе скрипта не осталось мёртвого кода про диалоги.
ok("dead.noNativeDialogInput", src:find("nativeDialogInput", 1, true) == nil)

-- =====================================================================
--  Часть 2. Skip ZZ: скрытие серверного диалога «Зеленая зона»
-- =====================================================================
do
    local zzChunk = "return function()\n"
        .. "GRND_SKIPZZ = { on = true }\n"
        .. "local function grndToUtf(s) return s end\n"  -- титулы в стенде уже в UTF-8
        .. cut("local function grndU8Put(cp)", "local function grndCp1251ToUtf8(s)")
        .. cut("function grndLowerUtf(s)", "function grndWeaponFold(s)")
        .. cut("function grndSkipZZMatch(title, text)", "_G.grndStatsOnDialog = function(")
        .. "\nreturn grndSkipZZMatch end"
    local zz = assert(loadstring(zzChunk, "@skipzz"))()()
    ok("zz.title.zelenaya", zz("Зеленая зона", "") == true)
    ok("zz.title.yo", zz("Зелёная зона", "") == true)
    ok("zz.title.caps", zz("ЗЕЛЕНАЯ ЗОНА", "") == true)
    ok("zz.title.spaces", zz("  Зеленая зона ", "") == true)
    ok("zz.title.other", zz("Статистика игрока", "пусто") == false)
    ok("zz.title.nil", zz(nil, nil) == false)
    -- заголовок другой, но текст серверного окна узнаётся (цветовые коды не мешают)
    ok("zz.text.byBody", zz("", "\n\nВ этом месте запрещено {48EF95}драться/стрелять.{ffffff}\n") == true)
    ok("zz.text.onScreen", zz("", "Вы находитесь в зелёной зоне!\nВ данном месте наносить какие-либо удары запрещено!") == true)
    ok("zz.text.onScreen2", zz("", "Вы находитесь в зеленой зоне") == true)
    ok("zz.text.other", zz("", "Вы купили машину") == false)

    -- текстдравы: окно из скриншота (заголовок, текст, фон и кнопка без текста)
    local tdClock = 200
    local realClockTd = os.clock
    os.clock = function() return tdClock end
    local _, tdFn, forget = assert(loadstring(zzChunk:gsub("return grndSkipZZMatch end",
        "return grndSkipZZMatch, grndSkipZZTextDraw, grndSkipZZForget end"), "@skipzz2"))()()
    tdClock = 200
    ok("td.title.hidden", tdFn(12, "Зеленая зона") == true)
    ok("td.body.hidden", tdFn(13, "Вы находитесь в зелёной зоне!") == true)
    ok("td.bg.neighbour", tdFn(9, nil) == true)              -- фон, id рядом, в ту же секунду
    ok("td.button.neighbour", tdFn(16, "Принять") == true)  -- кнопка рядом с текстом окна
    ok("td.far.visible", tdFn(80, "Магазин") == false)      -- чужой текст, далёкий id
    ok("td.far.nil", tdFn(80, nil) == false)
    tdClock = 205                                            -- прошло больше секунды
    ok("td.expired", tdFn(40, nil) == false)
    -- скрытый текстдрав забыт: id, который переиспользовали, не скрывается по старой памяти
    forget(12)
    tdClock = 205
    ok("td.forget.reuse", tdFn(12, "Магазин") == false)
    -- выключенный чит ничего не трогает
    GRND_SKIPZZ = { on = false }
    ok("td.off", tdFn(13, "Вы находитесь в зелёной зоне!") == false)
    os.clock = realClockTd
    -- в конфиге читов есть ключ и загрузка, и сохранение
    ok("zz.cfg.save", src:find('f:write("skipZZOn="', 1, true) ~= nil)
    ok("zz.cfg.load", src:find('k == "skipZZOn"', 1, true) ~= nil)
    -- в обработчике диалогов скрытие стоит до любых других разборов окна
    local hookAt = src:find("function sampev.onShowDialog(", 1, true)
    local zzAt = src:find("pcall(grndSkipZZMatch", 1, true)
    ok("zz.hook.present", hookAt ~= nil and zzAt ~= nil and zzAt > hookAt)
    local gateAt = src:find("if not grndSessionReady() then return end", hookAt, true)
    ok("zz.hook.before.gate", zzAt ~= nil and gateAt ~= nil and zzAt < gateAt)
    local statsAt = src:find("pcall(grndStatsOnDialog, dialogId", 1, true)
    ok("zz.hook.before.stats", zzAt ~= nil and statsAt ~= nil and zzAt < statsAt)
    ok("zz.card", src:find('tag = "skipzz"', 1, true) ~= nil)
    local tdHookAt = src:find("local function rcTdEvent(id, data, extra)", 1, true)
    local tdZzAt = src:find("pcall(grndSkipZZTextDraw, id", 1, true)
    local tdGateAt = src:find("local function rcTdEvent(id, data, extra)", 1, true)
    ok("zz.td.hook", tdHookAt ~= nil and tdZzAt ~= nil and tdZzAt > tdHookAt)
    ok("zz.td.forget", src:find("pcall(grndSkipZZForget, id)", 1, true) ~= nil)
end

-- =====================================================================
--  Часть 3. GM запоминается: активация при заходе и после обновления
-- =====================================================================
-- автоактивация не ждёт окна входа (после обновления его не бывает)
ok("gm.auto.noAuthGate", src:find("elseif AUTH.showedAuthOk and not GRND_GM.autoFired", 1, true) == nil)
ok("gm.auto.sessionGate", src:find("elseif not GRND_GM.autoFired and grndSessionReady() then", 1, true) ~= nil)
-- серверный GM, который уже включён с прошлого захода, не переключается /gm-ом
ok("gm.srv.noBlindToggle", src:find("and _G.GRND_GM_SRV == true then", 1, true) ~= nil)
ok("gm.srv.saved", src:find('f:write("gmSrv="', 1, true) ~= nil and src:find('k == "gmSrv"', 1, true) ~= nil)

-- автоматика при заходе не пишет в чат: grndGMSrvSet(true) (он шлёт /gm) в ней не вызывается
ok("gm.auto.noChat", src:find("grndGMSrvSet(true)", 1, true) == nil)

-- автоактивация при заходе молчит: тост grndGMToast(true) (дублируется в чат) не вызывается
ok("gm.auto.silent", src:find("grndGMToast(true)", 1, true) == nil)

-- Бесконечный бег: натив MoonLoader, карточка, сохранение в конфиг
ok("run.native", src:find("setPlayerNeverGetsTired", 1, true) ~= nil)
ok("run.card", src:find('tag = "run"', 1, true) ~= nil)
ok("run.cfg", src:find('f:write("runOn="', 1, true) ~= nil and src:find('k == "runOn"', 1, true) ~= nil)
ok("run.frame", src:find("pcall(grndRunFrame)", 1, true) ~= nil)
-- шрифт подписей чата увеличен
ok("font.meta", src:find("metaScale=2.90", 1, true) ~= nil)
ok("font.hint", src:find("fit(hint,r.w-28,measure,1.8)", 1, true) ~= nil)

-- Бесконечный кислород и сбив анимации после падения: натив MoonLoader, карточка, конфиг
ok("oxy.native", src:find("pcall(setCharDrownsInWater, PLAYER_PED, false)", 1, true) ~= nil)
ok("oxy.card", src:find('tag = "oxy"', 1, true) ~= nil and src:find('f:write("oxyOn="', 1, true) ~= nil)
ok("getup.natives", src:find("pcall(clearCharTasksImmediately, PLAYER_PED)", 1, true) ~= nil and src:find("pcall(isCharPlayingAnim, PLAYER_PED, anim)", 1, true) ~= nil)
ok("getup.everyFrame", src:find("if now - (G.at or 0) < 0.25 then return end", 1, true) == nil)
ok("getup.fallAnims", src:find('"FALL_FRONT", "FALL_BACK"', 1, true) ~= nil)
ok("getup.card", src:find('tag = "getup"', 1, true) ~= nil and src:find('f:write("getupOn="', 1, true) ~= nil)
ok("cheats.frames", src:find("pcall(grndOxyFrame)", 1, true) ~= nil and src:find("pcall(grndGetupFrame)", 1, true) ~= nil)

-- крупные подписи чата: лестница шрифтов доходит до размера, нужного для metaScale
ok("font.ladder.46", src:find("38, 40, 42, 44, 46, 48, 52 }", 1, true) ~= nil)
ok("font.meta.reachable", 2.90 * 16 <= 52)

print(string.format("--- серверное окно и окна скрипта: %d/%d ok ---", total - fails, total))
if fails > 0 then os.exit(1) end
os.exit(0)
