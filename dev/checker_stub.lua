-- ==== стенд кликов по чекеру (v1.19.67): нажать на игрока — только ЛКМ ====
-- Грузим НАСТОЯЩИЕ функции работы с мышью из скрипта и играем за игру:
-- ставятся те же флаги, что и в обработчике сообщений окна.
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

function grndMouseXY(lparam) return 0, 0 end
-- так игра выставляет флаги: идём ЧЕРЕЗ ЖИВОЙ код onWindowMessage (разметка
-- кнопки-источника и кадра отрисовки взяты из скрипта, не переписаны в стенде)
function wmButton(btn, frame, msgN)
    local msg = msgN or ((btn == 1) and 0x0201 or ((btn == 2) and 0x0204 or 0x0207))
    grndWmMouseFlags(msg, 0)
    GRND_UIFRAME = (frame or 0) - 1
    grndWmMouseStamp(true, false, false, msg)
end
function newFrame(n) GRND_UIFRAME = n end
