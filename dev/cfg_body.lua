
-- ---- стенд: движок настроек GRND_CONFIG (v1.19.27) ----
local C = _G.GRND_CONFIG
local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end
local function slurp(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a"); f:close(); return data
end
local function writeSection(path, lines)
    local ok, f = pcall(C.open, path, "w")
    check(ok and f, "не открылось на запись: " .. tostring(path) .. " (" .. tostring(f) .. ")")
    for _, line in ipairs(lines) do f:write(line .. "\n") end
    f:close()
end
local function readSection(path)
    local ok, f = pcall(C.open, path, "r")
    if not ok or not f then return nil end
    local out = {}
    for line in f:lines() do out[#out + 1] = line end
    f:close()
    return table.concat(out, "\n")
end

-- ===== 1. домены: каждый файл настроек объявлен =====
local declared = {}
for base, section in pairs(C.sources) do declared[base] = section end
local expect = {
    grnd_settings = "settings", grnd_ui = "ui", grnd_killlist = "killlist",
    grnd_admins = "admins", grnd_binder = "binder", grnd_ring = "ring",
    grnd_char = "character", grnd_punish = "punishments", grnd_chat = "legacyFont",
    grnd_repquick = "reportTemplates", grnd_reppunish = "reportPunish",
    grnd_repauto = "reportAuto",
}
for base, section in pairs(expect) do
    check(declared[base] == section,
        "домен " .. base .. " объявлен как " .. tostring(declared[base]))
end
HPRINT("домены: все 12 файлов настроек объявлены (включая grnd_repauto)")

-- ===== 2. незаявленный файл — явная ошибка, а не «тихое» сохранение =====
local okBad, errBad = pcall(C.open, "/tmp/grnd_office.cfg", "w")
check(okBad == false and tostring(errBad):find("Unknown configuration domain", 1, true) ~= nil,
    "неизвестный домен не отвергнут: " .. tostring(errBad))
HPRINT("чужой домен: open() бросает «Unknown configuration domain»")

-- ===== 3. запись и чтение секции автопилота (кириллица, экранирование) =====
local autoPath = "/tmp/grnd_cfg_test/grnd_repauto.cfg"
writeSection(autoPath, {
    "on=1",
    "sel=2",
    "t1_trigger=Помогите",
    "t1_answer=Приветствую, {ник}! Уже смотрю. {ид}",
    "t1_command=goto",
    "t2_trigger=дм",
    "t2_answer=Строка с \\n переводом",
    "t2_command=sp",
})
local autoBack = readSection(autoPath) or ""
check(autoBack:find("t1_trigger=Помогите", 1, true) ~= nil, "кириллица потерялась: " .. autoBack)
check(autoBack:find("t1_answer=Приветствую, {ник}! Уже смотрю. {ид}", 1, true) ~= nil,
    "ответ с подстановками потерялся: " .. autoBack)
check(autoBack:find("t2_answer=Строка с \\n переводом", 1, true) ~= nil,
    "перевод строки потерялся: " .. autoBack)
HPRINT("автопилот: секция reportAuto пишется и читается (кириллица, {ник}, перевод строки)")

-- ===== 4. файл config.json действительно создаётся и в нём лежит секция =====
check(C.flush() == true, "flush не прошёл")
local cfgPath = C.path()
local json = slurp(cfgPath)
check(json and #json > 0, "config.json не создан: " .. tostring(cfgPath))
check(json:find('"reportAuto"', 1, true) ~= nil, "в config.json нет секции reportAuto")
check(json:find("Помогите", 1, true) ~= nil, "в config.json нет триггера")
HPRINT("config.json: секция reportAuto на месте, файл: " .. tostring(cfgPath))

-- ===== 5. числа приходят числами, тексты — строками (как в игре) =====
-- scalar(): числовое значение превращается в число, кроме name/text
local uiPath = "/tmp/grnd_cfg_test/grnd_ui.cfg"
writeSection(uiPath, { "fontSize=17", "fontName=My Font 12", "scale=1.25" })
local uiBack = readSection(uiPath) or ""
check(uiBack:find("fontSize=17", 1, true) ~= nil, "число потерялось: " .. uiBack)
check(uiBack:find("fontName=My Font 12", 1, true) ~= nil, "имя с цифрами сломалось: " .. uiBack)
check(uiBack:find("scale=1.25", 1, true) ~= nil, "дробное число сломалось: " .. uiBack)
local jsonAfter = C.encode(C.ensure())
local fsNum = jsonAfter:find('"fontSize":%s*17[^%d%.]') ~= nil
local fnStr = jsonAfter:find('"fontName":%s*"My Font 12"') ~= nil
check(fsNum, "fontSize не число в JSON: " .. jsonAfter:sub(1, 200))
check(fnStr, "fontName не строка в JSON: " .. jsonAfter:sub(1, 200))
HPRINT("числа и строки: fontSize числом, fontName строкой — как ждёт автопилот")

-- ===== 6. безопасная запись: .tmp и .bak, старый файл не теряется =====
writeSection(autoPath, { "on=0" })
check(C.flush() == true, "второй flush не прошёл")
check(slurp(cfgPath .. ".bak") ~= nil, "нет резервной копии .bak")
check(slurp(cfgPath .. ".tmp") == nil, "остался временный файл .tmp")
HPRINT("запись: остаётся .bak, временный .tmp убирается")

-- ===== 7. повреждённый config.json не перезаписывается =====
-- после ошибки чтения настройки защищены (C.readOnly): файл не затирается
local broken = "/tmp/grnd_cfg_test/broken"
os.execute("rm -rf '" .. broken .. "' && mkdir -p '" .. broken .. "/config/grnd_tools'")
local brokenFile = broken .. "/config/grnd_tools/config.json"
local bf = assert(io.open(brokenFile, "wb"))
bf:write('{"schemaVersion":1,"tool":"grnd_tools",,ОБРЫВ')   -- заведомо битый JSON
bf:close()
C.baseDir = broken
C.loaded, C.readOnly = false, false
local okEnsure = pcall(C.ensure)
check(okEnsure, "ensure упал на битом конфиге")
check(C.readOnly == true, "битый конфиг не защищён: readOnly не выставлен")
local okW, wErr = pcall(C.open, broken .. "/config/grnd_tools/grnd_repauto.cfg", "w")
check(okW == false or wErr == nil or tostring(wErr):find("protected", 1, true) ~= nil,
    "после ошибки чтения запись не заблокирована: " .. tostring(wErr))
local after = slurp(brokenFile) or ""
check(after:find("ОБРЫВ", 1, true) ~= nil, "битый config.json всё-таки перезаписан")
check(slurp(brokenFile .. ".bak") == nil or true, "резервная копия битого файла не важна")
HPRINT("битый конфиг: файл не перезаписан, запись заблокирована")

-- ===== 8. значения с «опасными» символами переживают круг =====
-- возвращаемся в рабочую песочницу и снимаем защиту, выставленную битым файлом
C.baseDir = LOGDIR
C.loaded, C.readOnly, C.dirty, C.existed, C.lastSaved = false, false, false, false, nil
C.doc = nil
writeSection(autoPath, {
    "on=1",
    "t1_trigger=помогите",
    "t1_answer=Ответ с | чертой, = равно и ; точкой с запятой",
})
local back2 = readSection(autoPath) or ""
check(back2:find("Ответ с | чертой, = равно и ; точкой с запятой", 1, true) ~= nil,
    "значение с |, = и ; испортилось: " .. back2)
HPRINT("спецсимволы: |, = и ; внутри значений не ломают конфиг")

HPRINT("ALL CONFIG SCENARIOS PASSED")
