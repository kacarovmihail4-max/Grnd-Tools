
-- ---- сценарии окна /stats ----

-- 1) АВТОЗАПРОС скрипта (карточка слежки): окно прячется, данные идут в рекон
openRecon(77)
gameFrame()
check(#SENT == 1 and SENT[1] == "/stats 77",
    "автозапрос ушёл от карточки: " .. tostring(SENT[1]))
check(GRND_STATS.waiting == true and GRND_STATS.src == "auto",
    "автозапрос помечен как свой (src=auto, waiting=true)")
check(serverDialog() == true, "ответ на СВОЙ запрос спрятан (окно не показываем)")
check(GRND_RC.live.rc_level == "18", "данные из ответа ушли в карточку (уровень 18)")
check(GRND_RC.live.rc_account == "54", "номер аккаунта тоже ушёл в карточку")

-- 2) РУЧНОЙ /stats сразу после нашего автозапроса (раньше он считался «нашим»)
advance(2)
SENT = {}
userStats("/stats 77")
check(_G.grndStatsIsManual() == true, "ручной /stats помечен как ручной")
check(GRND_STATS.waiting == false,
    "ручной запрос не выдаёт себя за наш (автозапрос не считает его своим)")
check(#SENT == 1 and SENT[1] == "/stats 77", "ручная команда ушла на сервер как есть")
local before = GRND_RC.live.rc_level
check(serverDialog() == nil, "серверное окно НЕ прячется (виден ответ сервера)")
check(GRND_RC.live.rc_level == before,
    "рекон из ручного окна не обновляется (уровень остался " .. tostring(before) .. ")")
check(POPUPS == 0, "своё окно статистики на ручной /stats не открывается")

-- 3) пока идёт ручное окно, СВОЙ автозапрос молчит (иначе перебил бы ответ)
local sentBefore = #SENT
gameFrame()
gameFrame()
check(#SENT == sentBefore,
    "свой автозапрос на время ручного окна не отправляется")
check(serverDialog() == nil, "второе окно администратора тоже показываем")

-- 4) в слежке ручной /stats — тоже показываем окно сервера
advance(2)
GRND_SPEC.active = true
GRND_SPEC.id = 77
userStats("/stats 77")
check(_G.grndStatsShouldHide(DIALOG_TITLE, DIALOG_TEXT) == false,
    "в слежке ручное окно тоже не прячем")
check(serverDialog() == nil, "и сам хук его не трогает")
check(GRND_RC.live.rc_level == before, "в слежке рекон из ручного окна тоже не обновляется")
GRND_SPEC.active = false

-- 4b) v1.19.66: в слежке ЧУЖИЕ окна не прячем — в том числе похожие на
--     статистику, если их открыл сам администратор (например, через меню
--     сервера, без команды в чате). Прячем только ответ на свой запрос.
GRND_SPEC.active = true
GRND_SPEC.id = 77
GRND_STATS.waiting = false
GRND_STATS.awaitAt, GRND_STATS.awaitHave = nil, true
GRND_STATS.manualAt = -999
local liveBefore = GRND_RC.live.rc_level
check(serverDialog() == nil, "окно статистики, открытое вручную, не прячем (v1.19.66)")
check(GRND_RC.live.rc_level == liveBefore, "и рекон из него не обновляется")
check(_G.grndStatsShouldHide("Покупка", "Купить дом за 500000?") == false,
    "обычное окно в слежке не прячем")
-- а страница ПРОДОЛЖЕНИЯ нашего ответа (встык, со своей целью) — по-прежнему
-- прячется и разбирается
GRND_STATS.waiting = true
GRND_STATS.waitAt = os.clock()
GRND_STATS.lastIngestAt = os.clock()
GRND_STATS.targetId = 77
check(_G.grndStatsOnDialog(1, 0, DIALOG_TITLE, "Ок", "",
    "Статистика игрока Test_Player[77]\nУровень: 19\nНомер аккаунта: 54") == true,
    "страница продолжения своего ответа не спрятана")
check(GRND_RC.live.rc_level == "19", "данные страницы продолжения не дошли до рекона")
GRND_SPEC.active = false

-- 4c) медленный сервер: ответ на НАШ автозапрос пришёл позже 6 с — окно
--     показываем игроку (прятать так поздно нельзя), но данные всё равно
--     разбираем: ответ помечен нашей целью «[77]»
closeRecon()
advance(30)
GRND_STATS.doneKey, GRND_STATS.curKey, GRND_STATS.tries = nil, nil, 0
GRND_STATS.pendingOpen, GRND_STATS.lastTarget = false, 0
GRND_STATS.manualAt, GRND_STATS.manualHold = -999, false
GRND_STATS.waiting, GRND_STATS.reqAt = false, -999
GRND_STATS.awaitAt, GRND_STATS.awaitHave = nil, false
GRND_RC.live = {}
openRecon(77)
gameFrame()
check(GRND_STATS.waiting == true, "автозапрос ушёл (медленный сервер)")
advance(9)
check(_G.grndStatsOnDialog(1, 0, DIALOG_TITLE, "Ок", "",
    "Статистика игрока Test_Player[77]\nУровень: 21") == nil,
    "поздний ответ показываем (прятать после 6 с нельзя)")
check(GRND_RC.live.rc_level == "21", "но данные позднего ответа дошли до карточки")

-- 4d) окно ПО ДРУГОМУ игроку в слежке: показываем и в рекон не берём
GRND_RC.live = {}
GRND_STATS.waitAt = os.clock()
check(_G.grndStatsOnDialog(1, 0, DIALOG_TITLE, "Ок", "",
    "Статистика игрока Other_Player[88]\nУровень: 5") == nil,
    "окно по другому игроку показываем")
check(GRND_RC.live.rc_level == nil, "и в рекон его не берём (другая цель)")

-- 5) запасной канал (textdraw) во время ручного окна тоже молчит
_G.grndStatsOnTextDraw(DIALOG_TEXT)
check(GRND_RC.live.rc_level == before, "textdraw-канал ручное окно в рекон не тянет")

-- 6) окно, которого мы НЕ запрашивали, не прячем и не разбираем — даже если
--    признак ручного ввода потерялся (страховка stOurs)
GRND_STATS.manualAt = -999
GRND_STATS.src = "auto"
GRND_STATS.waiting = false
GRND_STATS.reqAt = -999
GRND_RC.live = {}
check(serverDialog() == nil, "ответ без нашего запроса НЕ прячем (чужое окно)")
check(GRND_RC.live.rc_level == nil, "и в рекон его не разбираем")

-- 7) свежая сессия: ручной /stats сразу после открытия рекона. Пока идёт
--    пауза, свой автозапрос молчит; через 6 с он уходит, прячется и наполняет
--    карточку (окно администратора при этом уже открыто и не трогается)
closeRecon()
advance(20)
GRND_STATS.doneKey, GRND_STATS.curKey, GRND_STATS.tries = nil, nil, 0
GRND_STATS.pendingOpen, GRND_STATS.lastTarget = false, 0
GRND_STATS.manualAt, GRND_STATS.manualHold = -999, false
GRND_STATS.waiting, GRND_STATS.reqAt = false, -999
GRND_RC.live = {}
openRecon(77)
SENT = {}
userStats("/stats 77")          -- администратор ввёл команду первым
gameFrame()
check(#SENT == 1, "на паузе свой автозапрос молчит (" .. tostring(#SENT) .. " отправок)")
local ingestBefore = GRND_STATS.lastIngestAt
check(serverDialog() == nil, "окно администратора открыто")
check(GRND_STATS.lastIngestAt == ingestBefore,
    "окно администратора не разбирается (время последнего разбора не сдвинулось)")
advance(7)                       -- пауза кончилась
SENT = {}
gameFrame()
check(#SENT == 1 and SENT[1] == "/stats 77",
    "после паузы карточка просит статистику заново: " .. tostring(SENT[1]))
check(serverDialog() == true, "ответ на НАШ запрос снова прячется")
check(GRND_RC.live.rc_level == "18", "и данные доходят до карточки")

-- 8) ручной /stats без ID (другой текст, чем у скрипта) — всегда ручной
advance(1)
SENT = {}
userStats("/stats")
check(_G.grndStatsIsManual() == true, "ручной /stats без ID распознан")
check(serverDialog() == nil, "его окно показываем")

-- 9) чужое окно (не статистика) не трогаем никогда
GRND_STATS.manualAt = -999
GRND_STATS.waiting = true
GRND_STATS.waitAt = os.clock()
GRND_STATS.reqAt = os.clock()
local foreign = _G.grndStatsShouldHide("Покупка", "Купить дом за 500000?")
check(foreign == false, "окно «Покупка» не прячем даже во время ожидания /stats")

-- 10) АВТОЗАПРОС ломается, если игра НЕ шлёт событие на наши отправки
--     (тогда метка своей отправки истекает сама): ответ всё равно наш
HOOK_FOR_SCRIPT_SENDS = false
GRND_STATS.manualAt = -999
GRND_STATS.manualHold = false
GRND_STATS.waiting = false
GRND_STATS.reqAt = -999
GRND_STATS.doneKey = nil
GRND_STATS.lastTarget = 0
GRND_STATS.pendingOpen = true
GRND_STATS.tries = 0
openRecon(77)
advance(10)
SENT = {}
gameFrame()
check(#SENT == 1 and SENT[1] == "/stats 77", "автозапрос ушёл и без события ("
    .. tostring(SENT[1]) .. ")")
check(serverDialog() == true, "и его ответ по-прежнему прячется")
check(GRND_RC.live.rc_level == "18", "и данные по-прежнему доходят")
-- ...а ручной /stats через пару секунд после этого — снова ручной
advance(2)
gameFrame()
SENT = {}
userStats("/stats 77")
check(_G.grndStatsIsManual() == true, "ручной /stats без события на наши отправки распознан")
check(serverDialog() == nil, "и его окно показываем")
HOOK_FOR_SCRIPT_SENDS = true

-- 11) после выхода из слежки автозапрос не дёргается
closeRecon()
GRND_STATS.manualAt = -999
GRND_STATS.manualHold = false
GRND_STATS.waiting = false
advance(20)
SENT = {}
gameFrame()
check(#SENT == 0, "вне рекона скрипт статистику не запрашивает")

-- 12) v1.19.72: дозапрос статистики для табличек нового WH
-- Такой /stats отправляет сам скрипт (src=wh), его окно тоже прячется, но
-- данные идут ТОЛЬКО в кэш по ID игрока — карточка слежки не наполняется.
advance(30)
GRND_STATS.waiting = false
GRND_STATS.ownPending = false
GRND_STATS.manualHold = false
GRND_STATS.manualAt = -999
openRecon(77)
GRND_RC.statsCache = nil
GRND_RC.live = { rc_level = "18", rc_account = "54" }
SENT = {}
check(_G.grndStatsBusy() == false, "статистика свободна — очередь WH может спросить")
check(_G.grndStatsRequest(88, "wh") == true, "WH отправляет свой /stats 88")
check(SENT[1] == "/stats 88", "команда ушла: " .. tostring(SENT[1]))
check(GRND_STATS.src == "wh", "запрос помечен как WH (src=wh)")
check(_G.grndStatsBusy() == true, "пока ждём ответ — статистика занята")
check(serverDialogText("Уровень: 5\nСемья: [SB] STRELKI\nСтатистика игрока Greshnik[88]") == true,
    "ответ на WH-запрос скрывается (это окно нашего запроса)")
local cell = GRND_RC.statsCache and GRND_RC.statsCache[88]
check(type(cell) == "table", "данные WH легли в кэш по ID игрока")
check(cell and cell.rc_family == "[SB] STRELKI", "семья из окна попала в кэш WH")
check(cell and tostring(cell.rc_level):find("5") ~= nil, "уровень из окна попал в кэш WH")
check(GRND_RC.live.rc_family == nil, "карточка слежки чужой статистикой НЕ наполняется")
check(GRND_RC.live.rc_level == "18", "карточка слежки осталась со своими данными")
check(GRND_STATS.targetId == 88 or GRND_STATS.lastTarget == 88,
    "цель разбора — тот, кого спросил WH")

-- WH-запрос по игроку, за которым СЛЕДИМ: данные идут и в карточку
advance(30)
SENT = {}
GRND_STATS.waiting = false
GRND_STATS.ownPending = false
check(_G.grndStatsRequest(77, "wh") == true, "WH спрашивает того же игрока, что и слежка")
check(serverDialogText("Уровень: 20\nСемья: [TM] TAMBOV\nСтатистика игрока Test_Player[77]") == true,
    "окно такого ответа тоже прячется")
check(GRND_RC.live.rc_family == "[TM] TAMBOV",
    "карточка слежки получила данные по СВОЕЙ цели")

-- 13) чужие/ручные окна WH не разбирает
advance(30)
SENT = {}
userStats("/stats 91")
check(serverDialogText("Уровень: 5\nСемья: [SB] STRELKI\nСтатистика игрока Greshnik[91]") == nil,
    "ручное окно администратора по-прежнему не прячется")
check(GRND_RC.statsCache and GRND_RC.statsCache[91] == nil,
    "ручное окно в кэш WH не попадает")

if FAILS == 0 then
    return 'ALL STATS SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
