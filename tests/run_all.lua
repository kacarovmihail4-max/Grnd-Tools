-- Прогон всех стендов разом. Запуск из корня репозитория:
--     luajit tests/run_all.lua
-- или из каталога tests:
--     luajit run_all.lua
-- Проверяет: синтаксис скрипта, логику автопилота, модуль автопилота
-- (вкладки/выдача/предохранители/страница), журнал чата.
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
for _, name in ipairs({ "punauto_logic_test", "punauto_module_test", "chatlog_test" }) do
    local cmd = string.format('%s "%s/%s.lua"', lua, dir, name)
    local pipe = io.popen(cmd, "r")
    local out = pipe and pipe:read("*a") or ""
    local okRun = pipe and pipe:close() or false
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
