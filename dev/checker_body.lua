
-- ================= сценарии (2): чекер не виден через окна =================
-- Гейт берётся из живого текста скрипта: если кто-то уберёт условие из
-- drawAll, эти проверки сразу упадут.
local function gateScene(opt)
    GRND_KL = opt.kl or {}
    menu = { open = opt.menu or false, anim = opt.menuAnim or 0 }
    GRND_TAB = { open = opt.tab or false }
    scoreboard = { anim = opt.tabAnim or 0 }
    GRND_REP = opt.rep and { open = true } or nil
    GRND_RC = opt.rc and { show = true } or nil
    GRND_CATCH = opt.catch and { active = true } or nil
    GRND_INPUT = { wanted = function() return opt.input == true end }
    GRND_LOG = { wanted = function() return opt.log == true end }
    _G.GRND_FORMS = { active = opt.forms == true }
    _G.grndFormsUiWanted = nil
    _G.grndGnewsUiWanted = function() return opt.gnews == true end
    _G.GRND_QR = { pickOpen = opt.pick == true, pun = { pickOpen = opt.pickPun == true } }
    _G.grndDialogActive = function() return opt.dialog == true end
    return grndGate()
end

check(gateScene({}) == false, "окон нет — чекер рисуется")
check(gateScene({menu = true}) == true, "меню: чекер прячется")
check(gateScene({menuAnim = 0.4}) == true, "меню ещё гаснет: чекер не мигает поверх")
check(gateScene({tab = true}) == true, "табло: чекер прячется")
check(gateScene({tabAnim = 0.3}) == true, "табло догорает: чекер прячется")
check(gateScene({rep = true}) == true, "окно репорта: чекер прячется")
check(gateScene({rc = true}) == true, "окно рекона: чекер прячется")
check(gateScene({catch = true}) == true, "окно перехвата: чекер прячется")
check(gateScene({input = true}) == true, "ввод текста: чекер прячется")
check(gateScene({log = true}) == true, "лог: чекер прячется")
check(gateScene({forms = true}) == true, "окно формы: чекер прячется")
check(gateScene({gnews = true}) == true, "окно гос.волны: чекер прячется")
check(gateScene({pick = true}) == true, "выпадающий список: чекер прячется")
check(gateScene({pickPun = true}) == true, "выпадающий список наказаний: чекер прячется")
check(gateScene({dialog = true}) == true, "диалог сервера: чекер прячется")
check(gateScene({kl = { moving = true }}) == false,
    "чекер тащат мышью — он остаётся видимым (меню закрыто само)")
check(gateScene({kl = { moving = true }, rc = true, menu = true}) == false,
    "режим перемещения чекера сильнее любых окон (иначе панель исчезнет из-под мыши)")
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
