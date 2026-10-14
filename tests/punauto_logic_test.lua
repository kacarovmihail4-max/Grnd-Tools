-- Извлекает разбор логики из скрипта по якорям GRND_PUNAUTO_LOGIC_*.
local function loadLogic(path, lower, utf, osmod)
    local file = assert(io.open(path, "rb"))
    local src = file:read("*a")
    file:close()
    -- v1.19.233: якоря КОДОВЫЕ — комментариев-маркеров в файле больше нет
    local a = src:find("\n    local PA_FN = {}", 1, true)
    assert(a, "нет якоря BEGIN")
    local e = src:find("\n    PA_FN.one = paOne", a, true)
    assert(e, "нет якоря END")
    local block = src:sub(a + 1, e + #"\n    PA_FN.one = paOne")
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

-- слово в кавычках не срабатывает и в режиме «в любом месте» среди нескольких
-- триггеров: цитата не должна «подставить» соседний триггер
eq("q.list.first", PA_FN.matchTab(tab, '«дм», dm'), "dm")

-- v1.19.212: ПЕРЕМЕННЫХ БОЛЬШЕ НЕТ. Команда уходит ровно как написана, а ID
-- игрока подставляется САМ сразу после имени команды.
eq("cmd.id", PA_FN.buildCmd("/mute 60 2.1 ОП", { nick = "Nik_Name", pid = 5 }),
    "/mute 5 60 2.1 ОП")
eq("cmd.id.only", PA_FN.buildCmd("/ban", { pid = 7 }), "/ban 7")
eq("cmd.id.spaces", PA_FN.buildCmd("  /jail   10   афк  ", { pid = 9 }), "/jail 9 10 афк")
eq("cmd.verbatim", PA_FN.buildCmd("/ban Nik_Name 3 дм", { nick = "Nik_Name", pid = 7 }),
    "/ban 7 Nik_Name 3 дм")
-- {…} из настроек прошлых версий в чат не уходят (переменных больше нет)
eq("cmd.oldvar", PA_FN.buildCmd("/mute {ID} 60 флуд", { nick = "N", pid = 5 }),
    "/mute 5 60 флуд")
eq("cmd.oldvar2", PA_FN.buildCmd("/mute {ник} 60", { nick = "N", pid = 5 }), "/mute 5 60")
eq("cmd.oldvar.only", PA_FN.buildCmd("{ID}", { pid = 5 }), "")
eq("cmd.pidEmpty", PA_FN.buildCmd("/mute 60", { nick = "", pid = "" }), "/mute 60")
eq("cmd.empty", PA_FN.buildCmd("", { pid = 5 }), "")
eq("cmd.spaces", PA_FN.buildCmd("   ", { pid = 5 }), "")

-- ---------- триггер В КАВЫЧКАХ не считается (v1.19.212) ----------
-- «он сказал "дм"» — цитата, а не нарушение; кавычки любые, апостроф внутри
-- слова («don't») кавычкой не считается.
eq("q.double", PA_FN.matchTab(tab, 'он сказал "дм" и всё'), nil)
eq("q.single", PA_FN.matchTab(tab, "он сказал 'дм'"), nil)
eq("q.guillemet", PA_FN.matchTab(tab, "он сказал «дм»"), nil)
eq("q.curly", PA_FN.matchTab(tab, "он сказал “дм”"), nil)
eq("q.curly.low", PA_FN.matchTab(tab, "он сказал „дм”"), nil)
eq("q.awt", PA_FN.matchTab(tab, "он сказал ❝дм❞"), nil)
eq("q.only", PA_FN.matchTab(tab, "«дм»"), nil)
eq("q.latin", PA_FN.matchTab(tab, 'he said "dm"'), nil)
eq("q.outside", PA_FN.matchTab(tab, 'он сказал "привет" а это дм'), "дм")
eq("q.before", PA_FN.matchTab(tab, 'дм — а он "не дм"'), "дм")
eq("q.apostrophe", PA_FN.matchTab(tab, "don't dm me"), "dm")
eq("q.unpaired", PA_FN.matchTab(tab, 'он сказал "дм'), "дм")
eq("q.exact", PA_FN.matchTab(tab2, "«дм»"), nil)

print(string.format("--- логика автопилота: %d/%d ok ---", total - fails, total))
os.exit(fails == 0 and 0 or 1)
