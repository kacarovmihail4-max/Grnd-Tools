-- Извлекает разбор логики из скрипта по якорям GRND_PUNAUTO_LOGIC_*.
local function loadLogic(path, lower, utf, osmod)
    local file = assert(io.open(path, "rb"))
    local src = file:read("*a")
    file:close()
    local a = src:find(">>> GRND_PUNAUTO_LOGIC_BEGIN", 1, true)
    assert(a, "нет якоря BEGIN")
    local e = src:find("<<< GRND_PUNAUTO_LOGIC_END", a, true)
    assert(e, "нет якоря END")
    local block = src:sub(a, e)
    block = block:gsub("^[^\n]*\n", "", 1)   -- строка с BEGIN
    block = block:gsub("[^\n]*$", "", 1)     -- строка с END
    local chunk = "local grndLowerUtf, grndUtf8Text, os = ...\n" .. block .. "\nreturn PA_FN\n"
    local fn, err = loadstring(chunk, "@punauto_logic")
    assert(fn, err)
    return fn(lower, utf, osmod or os)
end

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

-- Байтовый аналог игрового grndLowerUtf (utf8-библиотеки в LuaJIT нет):
-- 0xD0 0x90..0xAF (А..Я) -> +32, 0xD0 0x81 (Ё) -> 0xD1 0x91 (ё).
local function lowerUtf8(s)
    s = tostring(s or "")
    local out = {}
    local i = 1
    while i <= #s do
        local b = s:byte(i)
        if b == 0xD0 and i < #s then
            local b2 = s:byte(i + 1)
            if b2 >= 0x90 and b2 <= 0xAF then
                out[#out+1] = string.char(0xD0, b2 + 32); i = i + 2
            elseif b2 == 0x81 then
                out[#out+1] = string.char(0xD1, 0x91); i = i + 2
            else
                out[#out+1] = string.char(b); i = i + 1
            end
        else
            out[#out+1] = string.char(b); i = i + 1
        end
    end
    return table.concat(out)
end
local PA_FN = loadLogic(SRC, lowerUtf8, nil, os)

local fails, total = 0, 0
local function eq(name, got, exp)
    total = total + 1
    if tostring(got) ~= tostring(exp) then
        fails = fails + 1
        print(string.format("FAIL %-24s got=[%s] exp=[%s]", name, tostring(got), tostring(exp)))
    end
end
local function parse(text) return PA_FN.parseLine(text) end

do
    local n, p, m, k = parse("{FFFFFF}[12:00:01] {FFAA00}Nik_Name{FFFFFF}: привет всем")
    eq("say.nick", n, "Nik_Name"); eq("say.msg", m, "привет всем"); eq("say.kind", k, "say"); eq("say.pid", p, nil)
end
do
    local n, p, m, k = parse("[12:00:02] Nik_Name крикнул: помогите тут")
    eq("shout.nick", n, "Nik_Name"); eq("shout.msg", m, "помогите тут"); eq("shout.kind", k, "shout")
end
do
    local n, p, m, k = parse("(( Nik_Name: за что меня )))")
    eq("ooc.nick", n, "Nik_Name"); eq("ooc.msg", m, "за что меня"); eq("ooc.kind", k, "ooc")
end
do
    local n, p, m, k = parse("[12:00:03] Nik_Name[7]: dm")
    eq("say.id.nick", n, "Nik_Name"); eq("say.id.pid", p, 7); eq("say.id.msg", m, "dm"); eq("say.id.kind", k, "say")
end
do
    local n, p, m, k = parse("[12:00:04] Nik_Name(9) крикнул: дм")
    eq("shout.paren.pid", p, 9); eq("shout.paren.kind", k, "shout")
end
do
    local n, p, m, k = parse("[12:00:05] [GOV] Mixa: привет")
    eq("tag.nick", n, "Mixa"); eq("tag.msg", m, "привет"); eq("tag.kind", k, "say")
end
eq("no-nick.notice", select(1, parse("Внимание всем: сервер перезагрузится")), nil)
eq("no-nick.admin", select(1, parse("Администратор Mixa: нарушение")), nil)
eq("ooc.broken", select(1, parse("(( Nik_Name: привет )")), nil)

local tab = { trigger = "дм, dm", mode = "word" }
eq("word.dm", PA_FN.matchTab(tab, "это дм!"), "дм")
eq("word.dm2", PA_FN.matchTab(tab, "ДМ!!!"), "дм")
eq("word.latin", PA_FN.matchTab(tab, "go dm now"), "dm")
eq("word.in-word", PA_FN.matchTab(tab, "дмитрий тут"), nil)
eq("word.in-word2", PA_FN.matchTab(tab, "дмх"), nil)
eq("word.none", PA_FN.matchTab(tab, "привет"), nil)
eq("word.glued", PA_FN.matchTab(tab, "надм ничего"), nil)

local tab2 = { trigger = "дм", mode = "exact" }
eq("exact.hit", PA_FN.matchTab(tab2, "дм"), "дм")
eq("exact.miss", PA_FN.matchTab(tab2, "это дм"), nil)

local tab3 = { trigger = "дм{ID}", mode = "exact" }
eq("exact-var.hit", PA_FN.matchTab(tab3, "это дм"), "дм")
eq("exact-var.miss", PA_FN.matchTab(tab3, "дмитрий"), nil)

eq("cmd.autoId", PA_FN.buildCmd("/mute 60 флуд",
    { nick = "Nik_Name", pid = 5, msg = "дм", mynick = "Mixa" }, "дм", true),
    "/mute 5 60 флуд")
eq("cmd.subst", PA_FN.buildCmd("/mute {ID} 60 флуд",
    { nick = "Nik_Name", pid = 5, msg = "дм" }, "дм", true),
    "/mute 5 60 флуд")
eq("cmd.nick", PA_FN.buildCmd("/ban {ник} 3 дм", { nick = "Nik_Name", pid = 5, msg = "дм" }, "дм", true),
    "/ban Nik_Name 3 дм")
eq("cmd.noauto", PA_FN.buildCmd("/mute 60 флуд", { nick = "N", pid = 5, msg = "дм" }, "дм", false),
    "/mute 60 флуд")
-- без тумблера «подставлять ID» команда уходит ровно как написана, даже если
-- внутри есть ник (досочинённый ID испортил бы такую команду)
eq("cmd.verbatim", PA_FN.buildCmd("/ban Nik_Name 3 дм",
    { nick = "Nik_Name", pid = 7, msg = "дм" }, "дм", false), "/ban Nik_Name 3 дм")
eq("cmd.unknown", PA_FN.buildCmd("/mute {ID} {неизв} 60", { nick = "N", pid = 5 }, "дм", true),
    "/mute 5 60")
eq("cmd.trigger", PA_FN.buildCmd("/say Найдено: {триггер}", { nick = "N", pid = 5 }, "дм", true),
    "/say Найдено: дм")
eq("cmd.pidEmpty", PA_FN.buildCmd("/mute {ник} 60", { nick = "", pid = "" }, "дм", true),
    "/mute 60")

print(string.format("--- логика автопилота: %d/%d ok ---", total - fails, total))
os.exit(fails == 0 and 0 or 1)
