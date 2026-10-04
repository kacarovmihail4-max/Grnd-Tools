
-- ================= сценарии (2): чекер не виден через окна =================
-- Гейт берётся из живого текста скрипта: если кто-то уберёт условие из
-- drawAll, эти проверки сразу упадут.
local function gateScene(opt)
    GRND_KL = opt.kl or {}
    menu = { open = opt.menu or false, anim = opt.menuAnim or 0 }
    GRND_TAB = { open = opt.tab or false }
    scoreboard = { anim = opt.tabAnim or 0 }
    GRND_REP = opt.rep and { open = true } or nil
    GRND_RC = opt.rc and { show = true } or (opt.rcPop and { statsPop = { id = 7 } } or nil)
    GRND_CATCH = opt.catch and { active = true } or nil
    GRND_INPUT = { wanted = function() return opt.input == true end }
    GRND_LOG = { wanted = function() return opt.log == true end }
    _G.GRND_FORMS = { active = opt.forms == true }
    _G.grndFormsUiWanted = nil
    _G.grndGnewsUiWanted = function() return opt.gnews == true end
    _G.GRND_QR = { pickOpen = opt.pick == true, pun = { pickOpen = opt.pickPun == true } }
    _G.grndDialogActive = function() return opt.dialog == true end
    _G.grndDrawStatsPopup = opt.rcPop and function() return true end or nil
    return grndGate()
end

check(gateScene({}) == false, "окон нет — чекер рисуется")
check(gateScene({menu = true}) == true, "меню: чекер прячется")
check(gateScene({menuAnim = 0.4}) == true, "меню ещё гаснет: чекер не мигает поверх")
check(gateScene({tab = true}) == true, "табло: чекер прячется")
check(gateScene({tabAnim = 0.3}) == true, "табло догорает: чекер прячется")
check(gateScene({rep = true}) == true, "окно репорта: чекер прячется")
-- v1.19.68: карточка рекона и окно статистики НЕ прячут чекер целиком —
-- чекеры уходят ПОД окно (рисуются первыми), но остаются видны рядом
check(gateScene({rc = true}) == false, "в слежке (карточка рекона) чекеры видны")
check(gateScene({rcPop = true}) == false, "окно статистики: чекеры видны (окно их закрывает)")
check(gateScene({catch = true}) == true, "окно перехвата: чекер прячется")
check(gateScene({input = true}) == true, "ввод текста: чекер прячется")
check(gateScene({log = true}) == true, "лог: чекер прячется")
check(gateScene({forms = true}) == true, "окно формы: чекер прячется")
check(gateScene({gnews = true}) == true, "окно гос.волны: чекер прячется")
check(gateScene({pick = true}) == true, "выпадающий список: чекер прячется")
check(gateScene({pickPun = true}) == true, "выпадающий список наказаний: чекер прячется")
check(gateScene({dialog = true}) == true, "диалог сервера: чекер прячется")
check(gateScene({rc = true, dialog = true}) == true,
    "диалог сервера: чекер прячется даже при открытом реконе")

-- ===== сценарии (3): клик по окну НЕ нажимает на игрока (v1.19.68) =====
-- Точка занята окном поверх чекера — строки чекера её не получают.
bump()
GRND_RC = { show = true, windowPos = { x = 300, y = 100 }, windowSize = { w = 460, h = 208 } }
GRND_REPHUD = { enabled = true, rect = { x = 16, y = 400, w = 360, h = 180 } }
GRND_KL = { moving = false }
check(grndCheckerPointTaken(320, 120) == true, "точка на карточке рекона: чекеру не принадлежит")
check(grndCheckerPointTaken(299, 120) == false, "точка слева от карточки: свободна")
check(grndCheckerPointTaken(760, 120) == true,
    "самый правый пиксель карточки ещё занимает точку")
check(grndCheckerPointTaken(761, 120) == false, "точка справа от карточки: свободна")
check(grndCheckerPointTaken(308, 99) == false, "точка выше карточки: свободна")
check(grndCheckerPointTaken(308, 308) == true,
    "самый нижний пиксель карточки ещё занимает точку")
check(grndCheckerPointTaken(300, 309) == false, "точка под карточкой: свободна")
check(grndCheckerPointTaken(20, 420) == true, "точка на оверлее репортов: не принадлежит чекеру")
bump()
GRND_RC.windowPos = nil
GRND_REPHUD = nil
check(grndCheckerPointTaken(320, 120) == false, "окон нет: вся точка у чекера")
bump()
GRND_RC.statsPop = { id = 5 }
GRND_RC.statsPopRect = { x = 400, y = 200, w = 400, h = 414 }
check(grndCheckerPointTaken(500, 300) == true, "точка на окне статистики: не принадлежит чекеру")
check(grndCheckerPointTaken(399, 300) == false, "точка левее окна статистики: свободна")
bump()
GRND_RC = nil
check(grndCheckerPointTaken(500, 300) == false, "рекна нет: точка свободна")
bump()
GRND_RC = { show = true, windowPos = { x = 0, y = 0 }, windowSize = { w = 0, h = 0 } }
check(grndCheckerPointTaken(10, 10) == false, "нулевые габариты окна точку не занимают")

-- ===== сценарии (4): DX-текст и плашки честно режутся по окну =====
-- GDI-текст рисуется ПОВЕРХ окон ImGui, поэтому под окном его надо не
-- закрывать, а не рисовать вовсе.
bump()
GRND_RC = { show = true, windowPos = { x = 300, y = 100 }, windowSize = { w = 200, h = 100 } }
check(grndCheckerBandTaken(280, 120, 340, 140) == true,
    "строка, начавшаяся под окном, DX-текстом не рисуется")
check(grndCheckerBandTaken(295, 120, 305, 140) == true,
    "строка, заезжающая в окно краем, не рисуется")
check(grndCheckerBandTaken(301, 90, 400, 99) == false, "строка выше окна — рисуется")
check(grndCheckerBandTaken(200, 120, 299, 140) == false, "строка слева от окна — рисуется")
local pieces = grndCheckerClipRect(250, 60, 400, 200)
check(type(pieces) == "table" and #pieces > 0, "плашка под окном режется на части")
local covered = 0
for i = 1, #pieces do
    local q = pieces[i]
    local inter = (q.x < 500 and q.x + q.w > 300 and q.y < 160 and q.y + q.h > 100)
    if inter then covered = covered + 1 end
end
check(covered == 0, "ни один кусок плашки не попадает в окно (" .. tostring(#pieces) .. " кусков)")
local area = 0
for i = 1, #pieces do area = area + pieces[i].w * pieces[i].h end
check(area == 400 * 200 - 200 * 100,
    "куски плашки покрывают ровно свободную от окна площадь ("
    .. tostring(area) .. " из " .. tostring(400 * 200) .. ")")
bump()
GRND_RC = nil
check(grndCheckerClipRect(0, 0, 10, 10) == nil, "окон нет — плашка рисуется целой")

-- список окон считается ОДИН раз на кадр: внутри кадра состояние не пересчитывается
bump()
GRND_RC = { show = true, windowPos = { x = 300, y = 100 }, windowSize = { w = 200, h = 100 } }
check(grndCheckerPointTaken(320, 120) == true, "в своём кадре окно занимает точку")
GRND_RC = nil
check(grndCheckerPointTaken(320, 120) == true, "внутри кадра список окон кэширован")
bump()
check(grndCheckerPointTaken(320, 120) == false, "новый кадр — кэш окон сброшен")
check(gateScene({kl = { moving = true }}) == false,
    "чекер тащат мышью — он остаётся видимым (меню закрыто само)")
check(gateScene({kl = { moving = true }, rc = true, menu = true}) == false,
    "режим перемещения чекера сильнее любых окон (иначе панель исчезнет из-под мыши)")
-- при перетаскивании панель видно поверх окна: габариты окна её не режут
bump()
GRND_KL = { moving = true }
GRND_RC = { show = true, windowPos = { x = 300, y = 100 }, windowSize = { w = 200, h = 100 } }
check(grndCheckerPointTaken(320, 120) == false,
    "панель тащат мышью — окно не занимает её точку (панель видно поверх)")
check(grndCheckerClipRect(250, 60, 400, 200) == nil,
    "панель тащат мышью — плашку не режем (панель видно поверх)")
GRND_KL = { moving = false }
bump()
check(grndCheckerPointTaken(320, 120) == true, "перетаскивание кончилось — окно снова закрывает")

-- v1.19.69: компактная полоса действий — тоже окно поверх чекеров
bump()
GRND_RC = { show = true, actionsWinOpen = true,
    actionsWinRect = { x = 400, y = 500, w = 739, h = 66 } }
check(grndCheckerPointTaken(500, 520) == true,
    "клик по полосе действий чекеру не принадлежит (внутри неё)")
check(grndCheckerPointTaken(399, 520) == false, "слева от полосы действий точка свободна")
check(grndCheckerPointTaken(1139, 520) == true, "правый край полосы действий ещё занят окном")
check(grndCheckerPointTaken(1140, 520) == false, "справа от полосы действий точка свободна")
check(grndCheckerPointTaken(500, 566) == true, "низ полосы действий занят окном")
check(grndCheckerPointTaken(500, 567) == false, "под полосой действий точка свободна")
bump()
GRND_RC = { show = true, actionsWinOpen = false,
    actionsWinRect = { x = 400, y = 500, w = 739, h = 66 } }
check(grndCheckerPointTaken(500, 520) == false,
    "полоса действий закрыта — её габариты точку не занимают")
bump()
GRND_RC = { show = true, actionsWinOpen = true }
check(grndCheckerPointTaken(500, 520) == false,
    "полоса действий без габаритов точку не занимает (защита от мусора)")
check(gateScene({kl = { enabled = true }}) == false, "чекер включён — окон нет, он виден")
check(gateScene({menu = true}) == true and gateScene({}) == false,
    "после закрытия окна чекер снова рисуется")

-- ---- сценарии кликов по чекеру ----

-- «сырой» клик живёт ровно один кадр отрисовки
GRND_MOUSE = {}
newFrame(10)
wmButton(1, 11)
check(grndClickAlive() == false, "клик ещё не дошёл до своего кадра")
newFrame(11)
check(grndClickAlive() == true, "клик виден в своём кадре")

-- 1) ЛЕВЫЙ клик — нажатие по игроку разрешено
check(grndLeftClickPending() == true, "левый клик нажимает на игрока")

-- 2) ПКМ не нажимает на игрока
newFrame(12)
GRND_MOUSE = {}
wmButton(2, 13)
newFrame(13)
check(grndLeftClickPending() == false, "правый клик НЕ нажимает на игрока")
check(grndClickAlive() == true, "при этом «сырой» клик живой (кадр тот же)")

-- 3) СКМ (ClickWarp) — тоже не нажимает
newFrame(14)
GRND_MOUSE = {}
wmButton(3, 15)
newFrame(15)
check(grndLeftClickPending() == false, "средний клик НЕ нажимает на игрока")

-- 4) ГЛАВНЫЙ СЛУЧАЙ (жалоба): старый несъеденный ЛЕВЫЙ клик + свежая ПКМ.
--    Раньше флаг не гасился, и правый клик выглядел как левый — по игроку
--    срабатывало нажатие не той кнопкой.
GRND_MOUSE = {}
newFrame(20)
wmButton(1, 21)                 -- левый клик в пустоту (никто не «съел»)
newFrame(21)
check(grndLeftClickPending() == true, "клик работает в своём кадре")
newFrame(22)
grndMouseFrameBegin()           -- начало нового кадра: прошлый клик гаснет
check(GRND_MOUSE.clicked == false, "несъеденный клик больше не «залипает» на след. кадр")
check(GRND_MOUSE.clickedBtn == nil, "источник клика тоже сброшен")
wmButton(2, 23)                 -- теперь правый клик по строке чекера
newFrame(23)
check(grndLeftClickPending() == false, "после сброса правая кнопка НЕ нажимает на игрока")

-- 5) клик, помеченный ТЕКУЩИМ кадром, начало кадра не гасит
GRND_MOUSE = {}
newFrame(30)
wmButton(1, 31)
newFrame(31)
grndMouseFrameBegin()
check(grndLeftClickPending() == true, "клик своего кадра начало кадра не гасит")
newFrame(32)
grndMouseFrameBegin()
check(grndLeftClickPending() == false, "на следующем кадре клик уже не повторяется")

-- 6) до кадра, в котором клик виден, гасить нечего
GRND_MOUSE = {}
newFrame(40)
wmButton(1, 41)
grndMouseFrameBegin()           -- кадр 40 < 41: клик ещё не показывался
check(GRND_MOUSE.clicked == true, "флаги не гасятся до кадра, в котором клик виден")
newFrame(41)
grndMouseFrameBegin()
check(grndLeftClickPending() == true, "и в своём кадре он срабатывает")

-- 7) клик без пометки источника (старые сборки) считается левым
GRND_MOUSE = { clicked = true, frame = 50 }
newFrame(50)
check(grndLeftClickPending() == true, "клик без пометки источника — по-прежнему левый")

-- 8) защита от «чужого» источника: клик помечен не левой кнопкой
GRND_MOUSE = { clicked = true, clickedBtn = 2, frame = 71 }
newFrame(71)
check(grndLeftClickPending() == false,
    "клик с пометкой «не ЛКМ» нажатие по игроку не даёт")

-- 8a) в одном кадре пришла и ЛКМ, и ПКМ — настоящая ЛКМ была, нажатие проходит
GRND_MOUSE = {}
newFrame(72)
wmButton(1, 73)
wmButton(2, 73)
newFrame(73)
check(grndLeftClickPending() == true,
    "свежая ЛКМ в кадре нажатие по игроку даёт (даже если рядом была ПКМ)")

-- 8b) двойной ЛКМ (WM_LBUTTONDBLCLK 0x0203) — это тоже левая кнопка
GRND_MOUSE = {}
newFrame(80)
wmButton(1, 81, 0x0203)
newFrame(81)
check(grndLeftClickPending() == true, "двойной ЛКМ нажимает на игрока (как и одиночный)")

-- 9) во время удержания ПКМ (камера) левое нажатие по игроку работает
GRND_MOUSE = { rdown = true }
newFrame(60)
wmButton(1, 61)
newFrame(61)
check(grndLeftClickPending() == true, "во время удержания ПКМ левый клик работает")

if FAILS == 0 then
    return 'ALL CHECKER CLICK SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
