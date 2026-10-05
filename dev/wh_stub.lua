-- -*- coding: utf-8 -*-
-- Окружение стенда «новый WH» (v1.19.72). Игра подменяется заглушками,
-- сам модуль WH берётся из скрипта целиком (см. wh_harness.py).

-- ---------- служебное -------------------------------------------------------
T = { at = 0, calls = {} }              -- «время» и журнал вызовов
function T.resetCalls() T.calls = {} end
function T.log(kind, ...) T.calls[#T.calls + 1] = { kind = kind, a = { ... } } end
function T.count(kind)
    local n = 0
    for i = 1, #T.calls do if T.calls[i].kind == kind then n = n + 1 end end
    return n
end

PLAYER_PED = 1
SAMP_PTR = 0x10000000

-- ---------- время и экран ---------------------------------------------------
function getGameTimer() return T.at * 1000 end
SCR = { x = 1920, y = 1080 }
function getScreenResolution() return SCR.x, SCR.y end

-- ---------- память (CNetGame::Settings) ------------------------------------
local MEM = { [SAMP_PTR + 39] = 300.0, [SAMP_PTR + 47] = 0, [SAMP_PTR + 56] = 1 }
memory = {
    getfloat = function(addr) return MEM[addr] or 0 end,
    setfloat = function(addr, v) T.log('setfloat', addr - SAMP_PTR, v) MEM[addr] = v return true end,
    getint8 = function(addr) return MEM[addr] or 0 end,
    setint8 = function(addr, v) T.log('setint8', addr - SAMP_PTR, v) MEM[addr] = v return true end,
}
function sampGetServerSettingsPtr() return SAMP_PTR end
function T.memSet(off, v) MEM[SAMP_PTR + off] = v end
function T.memGet(off) return MEM[SAMP_PTR + off] end
function isSampAvailable() return true end

-- ---------- игроки ----------------------------------------------------------
PEDS = {}                    -- id -> ped
COORDS = {}                  -- ped -> {x,y,z}
function sampGetCharHandleBySampPlayerId(id) return PEDS[id] or 0 end
function sampGetPlayerIdByCharHandle(ped)
    if ped == PLAYER_PED then return true, 0 end
    for id, p in pairs(PEDS) do if p == ped then return true, id end end
    return true, 0
end
function doesCharExist(ped) return ped ~= nil and ped ~= 0 end
function getCharCoordinates(ped) local c = COORDS[ped]; return c[1], c[2], c[3] end
function sampGetPlayerNickname(id) return NICK[id] or ('player' .. tostring(id)) end
NICK = {}
function getCharHealth(ped) return HP[ped] or 100 end
function getCharArmor(ped) return ARM[ped] or 0 end
HP, ARM = {}, {}

CAM = { 0, 0, 0 }
function getActiveCameraCoordinates() return CAM[1], CAM[2], CAM[3] end
function isPauseMenuActive() return false end

-- Экранная проекция: пишем в журнал, чтобы проверить, какую точку просили.
PROJ = { sx = 500, sy = 300, depth = 5, hide = false }
function convert3DCoordsToScreenEx(x, y, z)
    T.log('project', x, y, z)
    if PROJ.hide then return false, 0, 0, -1 end
    return true, PROJ.sx, PROJ.sy, PROJ.depth
end

-- ---------- рисование (DX) --------------------------------------------------
DL = {}
function renderCreateFont(name, px, flags, charset)
    T.log('createFont', name, px, flags, charset)
    return { name = name, px = px, flags = flags, charset = charset }
end
function renderGetFontDrawTextLength(font, str)
    local k = (font and font.px) or 13
    return #tostring(str) * k * 0.55
end
function renderDrawBox(x, y, w, h, col) T.log('box', x, y, w, h, col) end
function renderFontDrawText(font, str, x, y, col) T.log('text', str, x, y, col, font and font.px) end
function renderDrawLine(x1, y1, x2, y2, w, col) T.log('line', x1, y1, x2, y2, w, col) end
function renderReleaseFont() end

-- ---------- текст и окна ----------------------------------------------------
function grndAnsiText(str) return tostring(str) end
GRND_COVERS = {}
function grndCheckerCovers() return GRND_COVERS end

-- ---------- модуль статистики (заглушка) -----------------------------------
STATS = { requests = {}, busy = false, manual = false }
function grndStatsRequest(id, src)
    STATS.requests[#STATS.requests + 1] = { id = id, src = src, at = T.at }
    return true
end
function grndStatsBusy() return STATS.busy end
function grndStatsIsManual() return STATS.manual end

-- ---------- прочее ----------------------------------------------------------
TYPING, SPAWNED = false, true
function grndIsSpawnedSafe() return SPAWNED end
function grndIsTyping() return TYPING end
SAVED_CFG = 0
function grndCamCfgSave() SAVED_CFG = SAVED_CFG + 1 end
function grndStoragePath(...) return '/tmp/grnd_wh_stand.log' end

-- ---------- карточка рекона -------------------------------------------------
GRND_RC = { id = nil, live = {}, statsCache = {} }
