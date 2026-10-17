local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local src = assert(io.open(dir .. "/../grnd_adm_tools.lua", "rb")):read("*a")
local a = assert(src:find("local GRND_AUTH_TITLE_MARKERS", 1, true), "нет якоря начала")
local b = assert(src:find("GRND_PUN = _G.GRND_PUN", 1, true), "нет якоря конца")
local clock = 0
os.clock = function() return clock end
local env = setmetatable({}, { __index = _G })
env.GRND_GATE = { authSeen = false, unblockAt = 0, authGrace = 6 }
env.sampIsLocalPlayerSpawned = function() return true end
env.sampGetGamestate = function() return 3 end
env.isPlayerPlaying = function() return true end
env.PLAYER_HANDLE = 0
env.sampIsDialogActive = function() return false end
env.sampIsPlayerSpectating = function() return false end
env.sampGetDialogCaption = function() return "" end
env.sampGetDialogText = function() return "" end
local api = assert(load(src:sub(a, b - 1)
    .. "\nreturn { ready = grndSessionReady, auth = grndAuthDialogOpen }", "chunk", "t", env))()
local fails, total = 0, 0
local function check(cond, msg)
    total = total + 1
    print((cond and "[ok]   " or "FAIL ") .. msg)
    if not cond then fails = fails + 1 end
end
local ok0, r0 = pcall(api.ready)
check(ok0 and r0 == false, "до 3 с после входа сессия не готова")
clock = 10
local ok1, r1 = pcall(api.ready)
check(ok1, "через 10 с проверка готовности не падает (нет рекурсии)")
check(ok1 and r1 == true, "заспавненный персонаж при Ctrl+R в игре: сессия готова")
local okA, rA = pcall(api.auth)
check(okA and rA == false, "без окна авторизации диалога нет")
print(("--- латч сессии: %d/%d ok ---"):format(total - fails, total))
if fails > 0 then os.exit(1) end
