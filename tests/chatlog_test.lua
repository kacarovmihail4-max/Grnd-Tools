-- Стенд журнала чата: проверяет две правки v1.19.202 в модуле GRND_LOG —
--   1) строки, которые скрипт спрятал от игрока (ответ сервера на /admins
--      фонового чекера «Админы в сети»), больше НЕ попадают в «Общий чат»;
--   2) строки, пришедшие до спавна/во время авторизации, наоборот, пишутся.
-- Гоняется без MoonLoader: куски кода вырезаются из скрипта по якорям.
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

-- =====================================================================
--  Часть 1. Метки «строка скрыта от игрока» (L.muteText / L.isMuted)
-- =====================================================================
do
    local chunk = "return function(grndUtf8Text)\n local GRND_LOG={}\n local L=GRND_LOG\n"
        .. " function L.utf(s) return grndUtf8Text and grndUtf8Text(s) or tostring(s or '') end\n"
        .. cut("    function L.clean(s)", "    function L.lower(s)")
        .. cut("    L.muted={}", "    function L.capture(text,source)")   -- v1.19.233: якорь кодовой
        .. "\n return L\nend"
    local L = assert(loadstring(chunk, "@logmute"))()(function(s) return s end)

    eq("mute.empty", L.muteText("", 3), false)
    eq("mute.ok", L.muteText("Всего администраторов: 3", 3), true)
    eq("isMuted.same", L.isMuted("Всего администраторов: 3"), true)
    -- метка времени чата и коды цвета не мешают опознанию строки
    eq("isMuted.stamp", L.isMuted("{FFFFFF}[12:30:01] Всего администраторов: 3"), true)
    eq("isMuted.other", L.isMuted("Всего администраторов: 4"), false)
    eq("isMuted.plain", L.isMuted("Привет"), false)
    -- жизнь метки ограничена: просроченная не глушит журнал
    L.muted[1].until_ = os.clock() - 1
    eq("mute.expired", L.isMuted("Всего администраторов: 3"), false)
    eq("mute.header", L.muteText("Администраторы в сети (online):", 3), true)
    -- список меток не растёт бесконечно
    for i = 1, 100 do L.muteText("строка " .. i, 5) end
    eq("mute.cap", #L.muted <= 64, true)
end

-- =====================================================================
--  Часть 2. Конвейер capture: скрытое — мимо, дубли — один раз, категории
-- =====================================================================
do
    local chunk = [[
return function(grndUtf8Text, grndLowerUtf, grndFormAdminLine)
    local GRND_LOG = {queue={},seen={},flags={}}
    local L = GRND_LOG
    L.logged = {}
    function L.append(kind, text, stamp)
        L.logged[#L.logged+1] = kind .. "|" .. tostring(text)
    end
    function L.utf(s) return grndUtf8Text and grndUtf8Text(s) or tostring(s or '') end
]]
        .. cut("    function L.clean(s)", "    function L.lower(s)")
        .. cut("    function L.warn(s,kind)", "    function L.validDate(")
        .. cut("    function L.response(text)", "    function L.resolve(text)")
        .. cut("    function L.resolve(text)", "    function L.duplicate(")
        .. cut("    function L.duplicate(text,source)", "    L.muted={}")
        .. cut("    L.muted={}", "    function L.capture(text,source)")   -- v1.19.233: якорь кодовой
        .. cut("    function L.capture(text,source)", "    function L.nick(id)")
        .. "\n    return L\nend"
    local L = assert(loadstring(chunk, "@logcapture"))()(function(s) return s end, nil, nil)
    local function last() return L.logged[#L.logged] end

    -- 1. обычная строка: пишется в «Общий чат» (в том числе до спавна —
    --    гейт сессии на журнал больше не влияет)
    L.capture("Привет, мир", "server")
    eq("plain.logged", last(), "chat|Привет, мир")
    -- 2. та же строка из второго хука — дубль не пишется
    local n = #L.logged
    L.capture("Привет, мир", "player")
    eq("dup.other-source", #L.logged, n)
    -- 3. скрытая строка чекера «Админы в сети» — мимо журнала
    L.muteText("Всего администраторов: 3", 3)
    n = #L.logged
    L.capture("Всего администраторов: 3", "server")
    eq("muted.skip", #L.logged, n)
    L.capture("{FFFFFF}[12:00:01] Всего администраторов: 3", "server")
    eq("muted.skip.stamp", #L.logged, n)
    -- 4. строка администрации — в «Общий чат» и в «Действия администрации»
    L.capture("Администратор Mixa выдал наказание", "server")
    eq("admin.chat", L.logged[#L.logged-1], "chat|Администратор Mixa выдал наказание")
    eq("admin.action", last(), "action_admins|Администратор Mixa выдал наказание")
    -- 5. строка репорта — в «Репорты и ответы»
    L.capture("[К-во репорта: 2] Игрок дм", "server")
    eq("report.cat", last(), "report|[К-во репорта: 2] Игрок дм")
    -- 6. пустая строка и мусор не пишутся
    n = #L.logged
    L.capture("", "server")
    L.capture(nil, "server")
    eq("empty.skip", #L.logged, n)
end

print(string.format("--- журнал чата: %d/%d ok ---", total - fails, total))
os.exit(fails == 0 and 0 or 1)
