
-- ---- стенд: автопилот ответов на репорт (v1.19.21) ----
local Q = _G.GRND_QR
local A = Q.auto
local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end
local function texts()
    local out = {}
    for i = 1, #TXT do out[#out + 1] = TXT[i].str end
    return table.concat(out, " | ")
end
local function has(word) return texts():find(word, 1, true) ~= nil end
local function drawAuto()
    TXT, BTNS = {}, {}
    local ok = _G.grndQrAutoDraw(CTX)
    check(ok == true, "раздел «Автопилот» не нарисовался")
end

check(type(A) == "table", "состояние автопилота не создано")
check(type(_G.grndQrAutoDraw) == "function", "нет отрисовки раздела")
check(type(_G.grndQrAutoOnReport) == "function", "нет хука на репорт")
check(type(_G.grndQrAutoTick) == "function", "нет тика автопилота")

-- ===== 1. конфиг: файл и стартовые значения =====
check(tostring(Q.autoPath()):find("grnd_repauto.cfg", 1, true) ~= nil,
    "файл настроек не grnd_repauto.cfg: " .. tostring(Q.autoPath()))
Q.autoEnsure()
check(A.on == false, "по умолчанию автопилот должен быть выключен")
check(A.command == "sp", "команда по умолчанию не /sp: " .. tostring(A.command))
check(#Q.autoCmds == 3, "в списке команд не три записи")
HPRINT("конфиг: файл grnd_repauto.cfg, по умолчанию выключен, команда /sp")

-- ===== 2. вкладка рисуется целиком =====
drawAuto()
check(has("Автопилот"), "нет заголовка «Автопилот»: " .. texts())
check(has("Триггер"), "нет поля «Триггер»")
check(has("Ответ игроку"), "нет поля «Ответ игроку»")
check(has("Команда после ответа"), "нет селектора команды")
check(has("Слежка"), "нет карточки «Слежка»")
check(has("Срабатывания"), "нет истории срабатываний")
check(has("Автопилот выключен"), "нет строки состояния")
HPRINT("вкладка: заголовок, триггер, ответ, команда, слежка, история")

-- ===== 3. тумблер =====
CLICK = { ["##grnd_qr_auto_on"] = true }
drawAuto()
CLICK = {}
check(A.on == true, "тумблер не включил автопилот")
check(TOASTS[#TOASTS] == "Автопилот включён", "нет тоста о включении: " .. tostring(TOASTS[#TOASTS]))
drawAuto()
check(has("Автопилот включён"), "строка состояния не переключилась")
check(#SWITCHPAINT > 0 and SWITCHPAINT[#SWITCHPAINT] == "##grnd_qr_auto_on",
    "тумблер нарисован не родной «пилюлей» скрипта")
SWITCHPAINT = {}
local savedPaint = grndUiSwitchPaint
grndUiSwitchPaint = nil
CLICK = { ["##grnd_qr_auto_on"] = true }
drawAuto()
CLICK = {}
check(A.on == false, "запасной тумблер не выключил автопилот")
grndUiSwitchPaint = savedPaint
A.on = true
HPRINT("тумблер: родная «пилюля» скрипта, запасной вариант тоже работает")

-- ===== 4. триггеры, ответ, подстановки =====
TYPE["##grnd_qr_auto_trigger"] = "Помогите, help"
drawAuto()
check(A.trigger == "Помогите, help", "триггер не записался: " .. tostring(A.trigger))
local trg = Q.autoTriggers()
check(#trg == 2 and trg[1] == "помогите" and trg[2] == "help",
    "триггеры разобраны неверно: " .. table.concat(trg, ","))
check(Q.autoMatch("ПОМОГИТЕ!!!") == "помогите", "кириллица в верхнем регистре не найдена")
check(Q.autoMatch("{FF0000}Help me please") == "help", "код цвета мешает поиску триггера")
check(Q.autoMatch("обычная болтовня") == nil, "ложное срабатывание триггера")
check(Q.autoShortTrigger() == nil, "нормальный триггер помечен «коротким»")
A.trigger = "я, помощь"
check(Q.autoShortTrigger() == "я", "короткий триггер не замечен")
A.trigger = "Помогите, help"
TYPE["##grnd_qr_auto_answer"] = "Приветствую, {ник}! Уже смотрю. {ид}"
drawAuto()
check(A.answer == "Приветствую, {ник}! Уже смотрю. {ид}",
    "ответ не записался: " .. tostring(A.answer))
HPRINT("поля: «Помогите, help» → два триггера, ответ с {ник}/{ид}")

-- ===== 5. селектор команды и предпросмотр =====
CLICK = { ["##grnd_qr_auto_cmd"] = true }
drawAuto()
CLICK = {}
check(A.listOpen == true, "список команд не открылся")
drawAuto()
check(has("/goto") and has("слежка за игроком"), "в списке нет команд: " .. texts())
CLICK = { ["##grnd_qr_auto_cmd_goto"] = true }
drawAuto()
CLICK = {}
check(A.command == "goto", "команда не переключилась: " .. tostring(A.command))
check(A.listOpen == false, "список не закрылся после выбора")
check(Q.autoCmdFor(25) == "/goto 25", "команда для ID не собралась")
check(Q.autoCmdFor("—") == nil, "команда собралась без числового ID")
check(Q.autoCmdLabel(A.command) == "/goto", "подпись селектора неверная")
drawAuto()
check(has("/ans 25"), "в предпросмотре нет ответа: " .. texts())
check(has("затем /goto 25"), "в предпросмотре нет команды")
HPRINT("селектор: /goto, список закрывается, предпросмотр «/ans 25 … → /goto 25»")

-- ===== 6. выключенный автопилот репорты не трогает =====
NOW = NOW + 10
A.perPid, A.rate = {}, {}
Q.autoSet(false)
QUEUE, ANS, CHAT, ORDER = {}, {}, {}, {}
local okOff, whyOff = Q.autoOnReport("Mixa_Grozz", 25, "Помогите!!!")
check(okOff == false and whyOff == "выключен", "выключенный автопилот сработал: " .. tostring(whyOff))
check(#QUEUE == 0, "выключенный автопилот что-то отправил")
check(Q.autoSet(true) == true, "автопилот не включился")
HPRINT("выключен: репорты проходят мимо, в чат ничего не уходит")

-- ===== 7. репорт с триггером: ответ игроку, затем команда =====
NOW = NOW + 10
A.perPid, A.rate = {}, {}
QUEUE, ANS, CHAT, ORDER, ANSICALLS = {}, {}, {}, {}, {}
local fired, hit = Q.autoOnReport("Mixa_Grozz", 25, "Помогите, дм!!!")
check(fired == true, "репорт с триггером не обработан")
check(hit == "помогите", "сработал не тот триггер: " .. tostring(hit))
check(#QUEUE == 2, "в очередь встало не две строки: " .. tostring(#QUEUE))
check(QUEUE[1] == "/ans 25 Приветствую, Mixa_Grozz! Уже смотрю. 25",
    "первым в очереди не ответ игроку: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/goto 25", "второй в очереди не команда: " .. tostring(QUEUE[2]))
check(#ANSICALLS == 2 and ANSICALLS[1] == "Приветствую, Mixa_Grozz! Уже смотрю. 25",
    "ответ игроку ушёл без конвертации в CP1251: " .. tostring(ANSICALLS[1]))
check(ANSICALLS[2] == "/goto 25",
    "команда ушла без конвертации в CP1251: " .. tostring(ANSICALLS[2]))
grndRepQueueTick()
check(#ORDER == 2 and ORDER[1] == "ans" and ORDER[2] == "chat",
    "порядок неверный: " .. table.concat(ORDER, ","))
check(ANS[1] == "25 Приветствую, Mixa_Grozz! Уже смотрю. 25",
    "игроку ушёл не тот ответ: " .. tostring(ANS[1]))
check(CHAT[1] == "/goto 25", "команда в чат ушла неверно: " .. tostring(CHAT[1]))
check(TOASTS[#TOASTS]:find("Автопилот: /ans 25", 1, true) ~= nil,
    "нет тоста о срабатывании: " .. tostring(TOASTS[#TOASTS]))
check(A.fired == 1, "счётчик срабатываний не вырос: " .. tostring(A.fired))
check(#A.history == 1 and tostring(A.history[1].pid) == "25", "история не записалась")
HPRINT("репорт: ответ игроку /ans 25, затем команда /goto 25 (в таком порядке)")

-- ===== 8. репорт без триггера / без ID / без ответа =====
NOW = NOW + 10
A.perPid, A.rate = {}, {}
QUEUE = {}
local okNo, whyNo = Q.autoOnReport("Mixa_Grozz", 26, "как дела?")
check(okNo == false and whyNo == "нет триггера", "репорт без триггера обработан: " .. tostring(whyNo))
check(A.lastCheck:find("не найден", 1, true) ~= nil, "нет пояснения: " .. tostring(A.lastCheck))
local okId, whyId = Q.autoOnReport("Без_ид", "—", "помогите")
check(okId == false and whyId == "нет ID", "репорт без ID обработан: " .. tostring(whyId))
check(#QUEUE == 0, "что-то ушло в чат на репорт без ID")
HPRINT("пропуски: нет триггера и нет ID — в чат ничего не уходит")

-- ===== 9. антидубль, пауза и предохранитель =====
NOW = NOW + 10
A.perPid, A.rate = {}, {}
Q.autoOnReport("Mixa_Grozz", 25, "Помогите")
QUEUE = {}
local okGap, whyGap = Q.autoOnReport("Другой", 77, "Помогите")
check(okGap == false and whyGap == "слишком часто", "нет паузы между срабатываниями: " .. tostring(whyGap))
NOW = NOW + 3
local okDup, whyDup = Q.autoOnReport("Mixa_Grozz", 25, "помогите ещё раз")
check(okDup == false and whyDup == "этому игроку уже отвечали", "нет антидубля: " .. tostring(whyDup))
check(#QUEUE == 0, "пропущенные репорты всё равно ушли")
NOW = NOW + 3
local okNext = Q.autoOnReport("Другой", 77, "Help!")
check(okNext == true, "после паузы не сработало")
check(#QUEUE == 2, "после паузы ушло не две строки: " .. tostring(#QUEUE))
HPRINT("антидубль: тому же игроку — раз в минуту, между срабатываниями пауза")

A.perPid, A.rate = {}, {}
QUEUE = {}
local sentN, blockN = 0, 0
for i = 1, 15 do
    NOW = NOW + 3
    local okF, whyF = Q.autoOnReport("Игрок" .. i, 100 + i, "помогите")
    if okF then sentN = sentN + 1
    elseif whyF == "лимит 12 в минуту" then blockN = blockN + 1 end
end
check(sentN == 12, "предохранитель: ушло " .. tostring(sentN) .. " вместо 12")
check(blockN == 3, "предохранитель не заблокировал поток: " .. tostring(blockN))
HPRINT("предохранитель: 12 автоответов в минуту, дальше — стоп")

-- ===== 10. слежка: автопилот выключается сам и не отвечает =====
NOW = NOW + 100
A.perPid, A.rate = {}, {}
check(A.on == true, "перед проверкой слежки автопилот должен быть включён")
setSpec(true)
QUEUE = {}
local okSpec, whySpec = Q.autoOnReport("Наблюдаемый", 200, "помогите")
check(okSpec == false and whySpec == "слежка", "в слежке автопилот сработал: " .. tostring(whySpec))
check(A.on == false, "автопилот не выключился при входе в слежку")
check(A.offReason == "слежка", "причина выключения не записана: " .. tostring(A.offReason))
check(#QUEUE == 0, "в слежке ответ всё равно ушёл")
check(TOASTS[#TOASTS] == "Автопилот выключен: слежка",
    "нет тоста про слежку: " .. tostring(TOASTS[#TOASTS]))
check(Q.autoSet(true) == false, "автопилот включился прямо в слежке")
check(A.on == false, "состояние в слежке переключилось")
setSpec(false)
check(Q.autoSet(true) == true, "вне слежки не включился")
setSpec(true)
NOW = NOW + 5
Q.autoTick()
check(A.on == false, "тик не выключил автопилот при входе в слежку")
setSpec(false)
HPRINT("слежка: срабатываний нет, автопилот выключается сам (тумблер и тик)")

-- ===== 11. идёт ввод текста — пропуск =====
NOW = NOW + 100
check(Q.autoSet(true) == true, "не включился")
A.perPid, A.rate = {}, {}
SERV.typing = true
QUEUE = {}
local okTyp, whyTyp = Q.autoOnReport("Печатающий", 300, "помогите")
check(okTyp == false and whyTyp == "ввод", "при вводе текста автопилот сработал: " .. tostring(whyTyp))
check(#QUEUE == 0, "при вводе текста ответ всё равно ушёл")
SERV.typing = false
HPRINT("идёт ввод текста: репорт пропущен, в чат ничего не уходит")

-- ===== 12. режим «без команды» =====
NOW = NOW + 100
A.perPid, A.rate = {}, {}
A.command = "none"
CHAT, QUEUE = {}, {}
check(Q.autoCmdFor(25) == nil, "команда «без команды» всё равно собирается")
local okNone = Q.autoOnReport("Тихий", 500, "помогите")
check(okNone == true, "с режимом «без команды» ответ не ушёл")
check(#QUEUE == 1, "в очереди лишние строки: " .. tostring(#QUEUE))
grndRepQueueTick()
check(#CHAT == 0, "при «без команды» в чат всё равно ушла команда")
A.command = "goto"
HPRINT("«без команды»: уходит только ответ игроку")

-- ===== 13. конфиг: запись и чтение =====
Q.autoSave()
local body = FILES[Q.autoPath()] or ""
check(body:find("trigger=Помогите, help", 1, true) ~= nil, "в файле нет триггеров: " .. body)
check(body:find("command=goto", 1, true) ~= nil, "в файле нет команды: " .. body)
check(body:find("answer=Приветствую", 1, true) ~= nil, "в файле нет ответа")
check(body:find("on=1", 1, true) ~= nil, "в файле нет on=1")
A.on, A.trigger, A.answer, A.command, A.loaded = false, "", "", "sp", false
A.perPid, A.rate, A.history = {}, {}, {}
check(Q.autoLoad() == true, "конфиг не прочитался")
check(A.on == true, "on не восстановился")
check(A.trigger == "Помогите, help", "триггеры не восстановились: " .. tostring(A.trigger))
check(A.answer == "Приветствую, {ник}! Уже смотрю. {ид}", "ответ не восстановился")
check(A.command == "goto", "команда не восстановилась: " .. tostring(A.command))
HPRINT("конфиг: on / trigger / answer / command записаны и прочитаны обратно")

-- ===== 14. задержанное сохранение тиком =====
A.trigger = "помоги"
A.dirtyAt = NOW
NOW = NOW + 1
Q.autoTick()
check((FILES[Q.autoPath()] or ""):find("trigger=помоги", 1, true) ~= nil,
    "тик не сохранил правки из полей")
HPRINT("тик: правки из полей сохраняются с задержкой")

-- ===== 15. очередь репорта недоступна — команда уходит напрямую =====
NOW = NOW + 100
A.on, A.perPid, A.rate = true, {}, {}
CHAT, ANS, QUEUE, ORDER, ANSICALLS = {}, {}, {}, {}, {}
SERV.failQueue = true
local okFb = Q.autoOnReport("Фолбэк", 400, "помогите")
check(okFb == true, "при недоступной очереди автопилот не сработал")
check(#CHAT == 1 and CHAT[1] == "/goto 400", "команда не ушла напрямую: " .. tostring(CHAT[1]))
SERV.failQueue = false
HPRINT("очередь недоступна: команда уходит напрямую в чат")

-- ===== 16. QR.queueCmd: русский текст конвертируется =====
ANSICALLS = {}
check(Q.queueCmd("/mute 25 60 флуд в чате") == true, "queueCmd не отправил команду")
check(#ANSICALLS == 1 and ANSICALLS[1] == "/mute 25 60 флуд в чате",
    "русский текст не прошёл конвертацию: " .. tostring(ANSICALLS[1]))
check(Q.queueCmd("") == false, "пустая команда ушла")
HPRINT("queueCmd: русская причина наказания уходит через CP1251")

-- ===== 17. ошибки наружу не выходят =====
NOW = NOW + 100
A.perPid, A.rate = {}, {}
local savedAns = grndRepAnswer
grndRepAnswer = function() error("тест: сбой ответа") end
local okBoom = Q.autoOnReport("Сбой", 600, "помогите")
check(okBoom == true, "сбой ответа сломал срабатывание (команда не ушла)")
grndRepAnswer = savedAns
local savedFn = Q.autoOnReport
Q.autoOnReport = function() error("тест: падение разбора") end
local okWrap = _G.grndQrAutoOnReport("Ник", 700, "помогите")
check(okWrap == false, "обёртка не вернула false при падении")
check(type(Q.auto.err) == "string", "ошибка не записана в Q.auto.err")
Q.autoOnReport = savedFn
HPRINT("сбой внутри: команда всё равно уходит, обёртка не роняет скрипт")

-- ===== 18. ESC закрывает список команд =====
A.listOpen = true
check(_G.grndQrOnEsc() == true, "ESC не обработал список команд")
check(A.listOpen == false, "ESC не закрыл список команд")
HPRINT("ESC: список команд автопилота закрывается")

-- ===== 19. маленькая область и мусор на входе =====
local small = makeCtx()
small.w, small.h = 200, 120
check(_G.grndQrAutoDraw(small) == false, "раздел нарисовался в слишком маленькой области")
check(_G.grndQrAutoDraw(nil) == false, "отрисовка упала на пустом контексте")
HPRINT("маленькая область: раздел честно не рисуется, ошибок нет")

HPRINT("ALL AUTO SCENARIOS PASSED")
