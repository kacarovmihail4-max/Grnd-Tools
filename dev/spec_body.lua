local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end

-- ==== тело стенда модуля слежки: бюджет чтений и порции сканов ====
-- Собираем «клиент R3»: калибровка проходит, а указатель CLocalPlayer лежит
-- в самом конце длинного диапазона (0x1800 из 0x1900) — раньше такой заход
-- делал больше 6000 чтений памяти в одном тике и подвешивал игру.
local S = _G.grndSpecNative

local BASE = 0x10000000
-- 0.3.7-R3 из таблицы версий модуля
local GAME_OFF, NET_OFF, POOLS_OFF, CPLAYER_OFF = 0x26E8F4, 0x26E8DC, 0x3DE, 0x08
local DIN_OFF = 0x04
local LP_OFF  = 0x1800                    -- далеко: срез за срезом

-- все адреса держим ниже 0x78000000: модуль считает такие указатели валидными
local P_GAME  = 0x20000000
local P_NET   = 0x21000000
local P_POOLS = 0x22000000
local P_PP    = 0x23000000
local P_INFO  = 0x24000000
local P_RP    = 0x25000000
local P_LP    = 0x30000000                -- искомый CLocalPlayer

memSet32(BASE + GAME_OFF, P_GAME)
memSet32(BASE + NET_OFF,  P_NET)
memSet32(P_GAME + 0x08, PLAYER_PED)
memSet32(P_NET + POOLS_OFF, P_POOLS)
memSet32(P_POOLS + CPLAYER_OFF, P_PP)
memSet32(P_PP + LP_OFF, P_LP)
memSet32(P_LP, PLAYER_PED)

-- три живых игрока: у каждого свой CPlayerInfo -> CRemotePlayer -> ped,
-- и обратный перевод педа в id сходится (это и есть верификация версии)
for id = 0, 2 do
    CONNECTED[id] = true
    NICKS[id] = "Игрок" .. id
    local ped = 0x40000000 + id * 0x1000
    local rp  = 0x35000000 + id * 0x1000
    memSet32(P_PP + DIN_OFF + id * 4, P_INFO + id * 0x100)
    memSet32(P_INFO + id * 0x100, rp)
    memSet32(rp, ped)                 -- R3: rpPed = 0x00
    PED2ID[ped] = id
    ID2PED[id] = ped
end

check(S.ok == false, "стенд должен начинать с некалиброванного модуля")

-- 1. калибровка: каждый заход ограничен бюджетом, но рано или поздно проходит
readsReset()
local maxCall = 0
local calls = 0
for i = 1, 16 do
    if S.ok then break end
    readsReset()
    pcall(S.tryInit)
    calls = calls + 1
    if READS > maxCall then maxCall = READS end
    check(READS <= 1400, "заход калибровки сделал " .. tostring(READS)
        .. " чтений памяти — это рывок в игре (бюджет 1200)")
end
check(S.ok == true, "калибровка так и не прошла за " .. tostring(calls) .. " заходов")
check(S.lp == P_LP, "найден не тот CLocalPlayer: " .. tostring(S.lp))
check(S.ver == "0.3.7-R3", "версия определена неверно: " .. tostring(S.ver))
check(maxCall > 0, "стенд не увидел ни одного чтения памяти")
HPRINT("калибровка: " .. tostring(calls) .. " заходов, максимум "
    .. tostring(maxCall) .. " чтений за заход (было бы 6200+)")

-- 2. spectScan: скан идёт срезами по 128 смещений, а не всем диапазоном
S.clock = function() CLOCK = (CLOCK or 0) + 1; return CLOCK end
local SCAN_HIT = 0x150                    -- попадание в третьем срезе
memSet8(P_LP + SCAN_HIT, 15)              -- MODE_OK
memSet8(P_LP + SCAN_HIT + 1, 1)           -- тип 1 = игрок
memSet32(P_LP + SCAN_HIT + 2, 5)          -- цель №5

local foundAt, maxScan = nil, 0
for i = 1, 6 do
    readsReset()
    local on, tid = S.spectScan()
    if READS > maxScan then maxScan = READS end
    check(READS <= 400, "заход скана слежки сделал " .. tostring(READS)
        .. " чтений — это рывок (срез 128 смещений)")
    if on and not foundAt then foundAt, SCAN_ID = i, tid end
end
check(foundAt ~= nil, "скан слежки не нашёл структуру за шесть заходов")
check(foundAt >= 3, "скан нашёл структуру за " .. tostring(foundAt)
    .. " заход — значит диапазон всё ещё перебирается целиком")
check(tonumber(SCAN_ID) == 5, "скан вернул не тот id: " .. tostring(SCAN_ID))
HPRINT("скан слежки: найдено на заходе " .. tostring(foundAt)
    .. ", максимум " .. tostring(maxScan) .. " чтений за заход")

HPRINT("SPEC PERF SCENARIOS PASSED")
