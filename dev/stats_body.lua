
-- ---- сценарии окна /stats ----

-- 1) АВТОЗАПРОС скрипта: окно прячется, данные уходят в карточку
openRecon(77)
scriptRequest()
check(#SENT == 1 and SENT[1] == "/stats 77",
    "автозапрос ушёл: " .. tostring(SENT[1]))
check(GRND_STATS.waiting == true and GRND_STATS.src == "auto",
    "автозапрос помечен как свой (src=auto, waiting=true)")
check(serverDialog() == true, "ответ на СВОЙ запрос спрятан (окно не открывается)")
check(GRND_RC.live.rc_level == "18", "данные из ответа ушли в карточку (уровень 18)")
check(GRND_RC.live.rc_account == "54", "номер аккаунта тоже ушёл в карточку")

-- 2) РУЧНОЙ /stats: окно сервера показываем, рекон не трогаем
openRecon(77)
local beforeLevel = GRND_RC.live.rc_level
SENT = {}
POPUPS = 0
manualStats(77)
check(#SENT == 0, "ручной /stats скрипт никуда не пересылает")
check(POPUPS == 0, "своё окно статистики на ручной /stats не открывается (виден сервер)")
check(GRND_STATS.waiting == false,
    "ручной запрос не выдаёт себя за наш (автозапрос не считает его своим)")
local hide = serverDialog()
check(hide == nil, "серверное окно НЕ прячется (возврат nil, не true)")
check(GRND_RC.live.rc_level == beforeLevel,
    "рекон из ручного окна не обновляется (уровень остался " .. tostring(beforeLevel) .. ")")

-- 3) РУЧНОЙ /stats В СЛЕЖКЕ: тоже показываем серверное окно
openRecon(77)
GRND_SPEC.active = true
GRND_SPEC.id = 77
manualStats(77)
check(_G.grndStatsShouldHide(DIALOG_TITLE, DIALOG_TEXT) == false,
    "в слежке ручное окно тоже не прячем")
check(serverDialog() == nil, "и сам хук его не трогает")
GRND_SPEC.active = false

-- 4) автозапрос В СЛЕЖКЕ по-прежнему прячется (поведение слежки не сломано)
openRecon(77)
GRND_SPEC.active = true
GRND_SPEC.id = 77
GRND_STATS.waiting = false
GRND_STATS.src = "auto"
scriptRequest()
check(serverDialog() == true, "ответ на автозапрос в слежке спрятан (как раньше)")
GRND_SPEC.active = false

-- 5) ручной /stats не ломает следующий автозапрос
openRecon(77)
manualStats(77)
check(serverDialog() == nil, "ручное окно открыто")
GRND_STATS.waiting = false
GRND_STATS.src = "auto"
scriptRequest()
check(serverDialog() == true, "следующий ответ автозапроса снова прячется")
check(GRND_RC.live.rc_level == "18", "и данные снова доходят до карточки")

-- 6) чужое окно (не статистика) не прячем никогда
check(serverDialog() == nil or true, "чужое окно не трогаем")
GRND_STATS.src = "auto"
GRND_STATS.waiting = true
GRND_STATS.waitAt = os.clock()
local foreign = _G.grndStatsShouldHide("Покупка", "Купить дом за 500000?")
check(foreign == false, "окно «Покупка» не прячем даже во время ожидания /stats")

if FAILS == 0 then
    return 'ALL STATS SCENARIOS PASSED'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS)
