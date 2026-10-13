-- Прогон всех стендов разом. Запуск из корня репозитория:
--     luajit tests/run_all.lua
-- или из каталога tests:
--     luajit run_all.lua
-- Проверяет: синтаксис скрипта, логику автопилота, модуль автопилота
-- (вкладки/выдача/предохранители/страница), журнал чата, уровни админов
-- в чекере «Админы в сети», раздел «Выдача в радиусе» (панель МП: скан,
-- радиус, уровень, выдача, настройки, страница).
local self = (arg and arg[0]) or "tests/run_all.lua"
local dir = self:match("^(.*)[/\\][^/\\]*$") or "."
local lua = (arg and arg[-1]) or "luajit"
local fails = 0

-- 1. Синтаксис всего скрипта: loadfile разбирает файл целиком и ничего
--    не выполняет — опечатка в любой из 49 тысяч строк видна сразу.
do
    local ok, err = loadfile(dir .. "/../grnd_adm_tools.lua")
    if ok then
        print("[ok]   синтаксис grnd_adm_tools.lua")
    else
        fails = fails + 1
        print("[FAIL] синтаксис grnd_adm_tools.lua: " .. tostring(err))
    end
end

-- 2. Стенды (каждый печатает свой итог и выходит с кодом 0/1).
-- ВАЖНО: в LuaJIT io.popen():close() возвращает true даже при ненулевом коде
-- выхода, поэтому итог читаем из вывода стенда: он печатает
-- «--- <имя>: N/N ok ---», а провалы — строками «FAIL».
local function runStand(name)
    local cmd = string.format('%s "%s/%s.lua"', lua, dir, name)
    local pipe = io.popen(cmd, "r")
    if not pipe then return false, "не запустить: " .. cmd .. "\n" end
    local out = pipe:read("*a") or ""
    pipe:close()
    local got, all = out:match("(%d+)/(%d+) ok")
    local okRun = (got ~= nil) and (got == all) and (out:find("FAIL ", 1, true) == nil)
    return okRun, out
end

for _, name in ipairs({ "punauto_logic_test", "punauto_module_test",
    "chatlog_test", "ao_level_test", "radtools_test" }) do
    local okRun, out = runStand(name)
    io.write(out)
    if okRun then
        print("[ok]   " .. name)
    else
        fails = fails + 1
        print("[FAIL] " .. name)
    end
end

print(fails == 0 and "=== все стенды пройдены ===" or ("=== провалов: " .. tostring(fails) .. " ==="))
os.exit(fails == 0 and 0 or 1)
