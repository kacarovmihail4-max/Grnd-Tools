-- ==== стенд движка настроек GRND_CONFIG (v1.19.27) ====
-- Подменяем только внешний мир MoonLoader: каталог, создание папок, io.
HPRINT = print
function print(...) end
WARNS = {}
LOGDIR = "/tmp/grnd_cfg_test"

function getWorkingDirectory() return LOGDIR end
function thisScript() return { path = LOGDIR .. "/grnd_adm_tools.lua" } end
function createDirectory(path) os.execute("mkdir -p '" .. tostring(path) .. "' >/dev/null 2>&1") end
libs = { lfs = { mkdir = function(path) createDirectory(path) end } }
function grndTrace() end

-- чистая песочница: каждый прогон начинает с нуля
os.execute("rm -rf '" .. LOGDIR .. "'")
os.execute("mkdir -p '" .. LOGDIR .. "'")
