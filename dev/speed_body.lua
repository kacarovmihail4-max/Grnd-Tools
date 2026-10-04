
-- ---- стенд: строка «Скорость» карточки рекона ----
-- Каждый сценарий — свой id цели: сглаживание у каждого игрока своё.

local function call(id, raw, times)
    local s = nil
    for _ = 1, (times or 1) do s = grndSpeedDisplay(id, raw) end
    return s
end

-- 1) цель едет в машине: игра даёт 12.5 м/с -> 45 км/ч
SPEC.car, SAMP_CAR, CARSPEED, CHARSPEED, IN_CAR = 42, 7, 12.5, 0, false
check(call(101, "", 3) == "45 км/ч", "машина 12.5 м/с -> «45 км/ч»" )

-- 2) серверная строка с мусором не попадает в карточку
local s2 = call(102, "|||| 45 | 0", 3)
check(s2:match("^%d+ км/ч$") ~= nil, "мусорная серверная строка -> только «N км/ч» (получено: " .. tostring(s2) .. ")")
check(s2:find("|", 1, true) == nil, "в строке скорости нет серверных полосок")

-- 3) цель идёт пешком: 5 м/с -> 18 км/ч
SPEC.car, SAMP_CAR, SPEC.ped, CHARSPEED, IN_CAR = nil, nil, 12, 5, false
check(call(103, "", 3) == "18 км/ч", "пеший 5 м/с -> «18 км/ч»")

-- 4) цель стоит: игра и сервер говорят 0
SPEC.ped, CHARSPEED = 12, 0
check(call(104, "0", 3) == "0 км/ч", "стоит на месте -> «0 км/ч»")

-- 5) игра педа не видит (цель далеко), а сервер видит движение
SPEC.car, SAMP_CAR, SPEC.ped = nil, nil, nil
check(call(105, "40 км/ч", 3) == "40 км/ч", "сервер видит движение -> «40 км/ч»")

-- 5b) карточка просит значение без единиц (как в образце: просто «40»)
SPEC.car, SAMP_CAR, CARSPEED, IN_CAR = 42, 7, 12.5, false
local bare = nil
for _ = 1, 3 do bare = grndSpeedDisplay(109, "", true) end
check(bare == "45", "bare-режим для карточки -> «45» без единиц")
SPEC.car, SAMP_CAR = nil, nil

-- 6) вместо замера пришёл мусор (выброс) — показываем «—», а не ерунду
SPEC.car, SAMP_CAR, CARSPEED = 42, 7, 4000
check(call(106, "", 3) == "—", "выброс замера (4000 м/с) -> «—»")

-- 7) дрожание замера (12.2 … 12.5 м/с) не должно дёргать цифру
SPEC.car, SAMP_CAR, CARSPEED = 42, 7, 12.5
local seen = {}
for i = 1, 30 do
    CARSPEED = (i % 2 == 0) and 12.2 or 12.5
    seen[call(107, "", 1)] = true
end
check(seen["45 км/ч"] == true, "дрожание 12.2/12.5 м/с -> цифра не пляшет (45 км/ч)")
check(next(seen) == "45 км/ч" and seen["45 км/ч"] == true, "в дрожании не появилось лишних значений")
local n = 0
for _ in pairs(seen) do n = n + 1 end
check(n == 1, "за 30 кадров дрожания показано ровно одно значение (а не " .. tostring(n) .. ")")

-- 8) без данных вообще — честное «—», никаких сырых строк
SPEC.car, SAMP_CAR, SPEC.ped, CARSPEED, CHARSPEED = nil, nil, nil, nil, nil
check(call(108, "нет данных", 3) == "—", "нет ни игры, ни числа сервера -> «—»")

if FAILS == 0 then
    return 'ALL SPEED SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
