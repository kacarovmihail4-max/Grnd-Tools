
-- ======================= прогон настоящей панели =======================
CX, CY = WIN.x, WIN.y   -- ctx.x/ctx.y панели = ЭКРАННАЯ позиция окна
local function frame(mx, my, clicked)
    FRAME = FRAME + 1
    GRND_UIFRAME = FRAME
    MOUSE.x, MOUSE.y, MOUSE.clicked = mx, my, clicked or false
    GRND_MOUSE.x, GRND_MOUSE.y, GRND_MOUSE.clicked = mx, my, clicked or false
    HOVERED_ID, HOVER_ID = nil, nil
    BUTTONS = {}
    OUT, ERRORS = {}, {}
    for k in pairs(DRAWS) do DRAWS[k] = 0 end
    _G.MP.drawError = nil
    local ok, err = pcall(_G.MP.drawInner, { x = 200, y = 100, w = 600, h = 480 })
    return ok, err, BUTTONS
end

local function findButton(list, needle)
    for _, b in ipairs(list) do
        if b.id:find(needle, 1, true) then return b end
    end
    return nil
end

local function center(b) return b.x + b.w / 2, b.y + b.h / 2 end

local ok1, err1, list1 = frame(-500, -500)
HPRINT("кадр без курсора: ok=" .. tostring(ok1) .. (ok1 and "" or (" ОШИБКА: " .. tostring(err1))))
if _G.MP.blockError then HPRINT("ошибка блока: " .. tostring(_G.MP.blockError)) end
local startBtn = findButton(list1, "start_mp")
HPRINT("кнопок нарисовано: " .. tostring(#list1) .. ", «Начать»: " .. tostring(startBtn and "найдена" or "НЕТ"))

local problems, frames = 0, 0

local function checkFrame(where, mx, my, clicked)
    frames = frames + 1
    local ok, err = frame(mx, my, clicked)
    if _G.MP.blockError then
        problems = problems + 1
        HPRINT(where .. " -> ошибка внутри панели: " .. tostring(_G.MP.blockError))
        _G.MP.blockError = nil
    end
    if not ok then
        problems = problems + 1
        HPRINT(where .. " -> ОШИБКА: " .. tostring(err))
    elseif #ERRORS > 0 then
        problems = problems + 1
        HPRINT(where .. " -> " .. table.concat(ERRORS, " / "))
    end
end

-- курсор над каждой кнопкой: и в «экранных» координатах кнопки, и чуть в стороне
for _, b in ipairs(list1) do
    local mx, my = CX + b.x + b.w / 2, CY + b.y + b.h / 2
    checkFrame("наведение на " .. b.id, mx, my, false)
    checkFrame("наведение (2-й кадр) на " .. b.id, mx, my, false)
    checkFrame("нажатие " .. b.id, mx, my, true)
    checkFrame("курсор рядом с " .. b.id, mx + b.w + 5, my, false)
end

-- створка «наведение/нажатие» на кнопке «Начать» отдельно (жалоба заказчика)
if startBtn then
    local mx, my = CX + startBtn.x + startBtn.w / 2, CY + startBtn.y + startBtn.h / 2
    checkFrame("«Начать»: наведение", mx, my, false)
    checkFrame("«Начать»: нажатие", mx, my, true)
    -- и в локальных координатах (курсор «на месте» при окне в нуле)
    checkFrame("«Начать»: локальные координаты", startBtn.x + startBtn.w / 2,
        startBtn.y + startBtn.h / 2, false)
end

HPRINT(("кадров прогнано: %d, проблемных: %d, голых глобальных имён: %d")
    :format(frames, problems, #BARE))
if problems == 0 and #BARE == 0 then
    HPRINT("PANEL HARNESS PASSED")
else
    HPRINT("PANEL HARNESS FAILED")
end
