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
        .. "local function grndToUtf(s) return s end\n"  -- титулы в стенде уже в UTF-8
        .. cut("local function grndU8Put(cp)", "local function grndCp1251ToUtf8(s)")
        .. cut("function grndLowerUtf(s)", "function grndWeaponFold(s)")
        .. cut("function grndSkipZZTitle(title)", "_G.grndStatsOnDialog = function(")
        .. "\nreturn grndSkipZZTitle end"
    local zz = assert(loadstring(zzChunk, "@skipzz"))()()
    ok("zz.title.zelenaya", zz("Зеленая зона") == true)
    ok("zz.title.yo", zz("Зелёная зона") == true)
    ok("zz.title.caps", zz("ЗЕЛЕНАЯ ЗОНА") == true)
    ok("zz.title.spaces", zz("  Зеленая зона ") == true)
    ok("zz.title.other", zz("Статистика игрока") == false)
    ok("zz.title.nil", zz(nil) == false)
    -- в конфиге читов есть ключ и загрузка, и сохранение
    ok("zz.cfg.save", src:find('f:write("skipZZOn="', 1, true) ~= nil)
    ok("zz.cfg.load", src:find('k == "skipZZOn"', 1, true) ~= nil)
    -- в обработчике диалогов скрытие стоит до любых других разборов окна
    local hookAt = src:find("function sampev.onShowDialog(", 1, true)
    local zzAt = src:find("GRND_SKIPZZ and GRND_SKIPZZ.on and grndSkipZZTitle(title)", 1, true)
    ok("zz.hook.present", hookAt ~= nil and zzAt ~= nil and zzAt > hookAt)
    local statsAt = src:find("pcall(grndStatsOnDialog, dialogId", 1, true)
    ok("zz.hook.before.stats", zzAt ~= nil and statsAt ~= nil and zzAt < statsAt)
    ok("zz.card", src:find('tag = "skipzz"', 1, true) ~= nil)
end

print(string.format("--- серверное окно и окна скрипта: %d/%d ok ---", total - fails, total))
if fails > 0 then os.exit(1) end
os.exit(0)
