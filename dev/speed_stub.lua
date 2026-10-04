-- ==== стенд строки «Скорость» в карточке рекона (v1.19.59) ====
-- Проверяем только замер и формат показа: сырые серверные строки в карточку
-- попадать не должны, а число должно идти из игры (getCarSpeed/getCharSpeed).
HPRINT = print
function print(...) end
FAILS = 0
function check(cond, msg)
    if cond then
        HPRINT('ок: ' .. msg)
    else
        FAILS = FAILS + 1
        HPRINT('ПРОВАЛ: ' .. msg)
    end
end

-- поддельный модуль слежки (память samp.dll): id машины цели и её пед
SPEC = { car = nil, ped = nil }
_G.grndSpecNative = {
    getVehicleId = function(id) return SPEC.car end,
    pedOf = function(id) return SPEC.ped end,
}

-- хендл машины из SA-MP и скорости, которые «видит игра»
SAMP_CAR, CARSPEED, CHARSPEED, IN_CAR = nil, nil, nil, false
function sampGetCarHandleBySampVehicleId(vehId) return SAMP_CAR end
function getCarSpeed(car) return CARSPEED end
function getCharSpeed(ped) return CHARSPEED end
function isCharInAnyCar(ped) return IN_CAR and true or false end
function storeCarCharIsInNoSave(ped) return SAMP_CAR end
