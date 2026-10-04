-- ==== стенд модуля слежки (grndSpecNative): чтения памяти и порции сканов ====
-- Модуль 13b берётся из настоящего исходника отдельным чанком. Здесь только
-- поддельная память samp.dll с СЧЁТЧИКОМ чтений: стенд проверяет, что один
-- заход калибровки/скана укладывается в бюджет и не может подвесить игру.
HPRINT = print
function print(...) end

PLAYER_PED = 0x0B7449C0            -- «хендл» локального педа (в игре — указатель)

READS = 0                          -- сколько раз модуль прочитал память
function readsReset() READS = 0 end

MEM32, MEM8 = {}, {}
function memSet32(a, v) MEM32[a] = v end
function memSet8(a, v) MEM8[a] = v end

memory = {
    getint32 = function(a) READS = READS + 1; return MEM32[a] or 0 end,
    getint8  = function(a) READS = READS + 1; return MEM8[a] or 0 end,
    getfloat = function(a) READS = READS + 1; return 0 end,
    setint8  = function(a, v) MEM8[a] = v end,
    setint32 = function(a, v) MEM32[a] = v end,
}

function getModuleHandle(name) return 0x10000000 end     -- «база samp.dll»
function doesCharExist(ped) return ped ~= nil and ped > 0 end
function getCharCoordinates(ped) return 1.0, 2.0, 3.0 end
function getActiveCameraCoordinates() return 1.0, 2.0, 3.0 end
function attachCameraToCharLookAtChar() return true end
function getCarCoordinates(car) return 1.0, 2.0, 3.0 end
function doesVehicleExist(car) return true end
function getCarModel(car) return 400 end
function getCarHealth(car) return 1000 end

CONNECTED = {}
NICKS = {}
function sampGetLocalPlayerId() return 0 end
function sampGetMaxPlayerId() return 500 end
function sampIsPlayerConnected(id) return CONNECTED[id] == true end
function sampGetPlayerNickname(id) return NICKS[id] end
function sampGetPlayerIdByCharHandle(ped) return PED2ID[ped] end
function sampGetCharHandleBySampPlayerId(id) return ID2PED[id] end
PED2ID, ID2PED = {}, {}
