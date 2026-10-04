
-- ---- стенд: автопилот ответов на репорт (v1.19.22, вкладки) ----
local Q = _G.GRND_QR
local A = Q.auto
-- v1.19.38: ответы автопилота по умолчанию уходят в /n (проверка). Сценарии
-- ниже проверяют БОЕВОЙ путь (/ans), поэтому здесь режим проверки выключен;
-- свой сценарий для /n — секция 9e.
Q.autoTest = false
local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end
local function texts()
    local out = {}
    for i = 1, #TXT do out[#out + 1] = TXT[i].str end
    return table.concat(out, " | ")
end
local function has(word) return texts():find(word, 1, true) ~= nil end
-- v1.19.35: строки подсказок могут переноситься по словам — ищем фразу в тексте,
-- склеенном пробелами (для «однострочных» подсказок это ничего не меняет)
local function textsOne()
    local out = {}
    for i = 1, #TXT do out[#out + 1] = tostring(TXT[i].str) end
    return table.concat(out, " ")
end
local function hasOne(word) return textsOne():find(word, 1, true) ~= nil end
local function drawAuto()
    TXT, BTNS, INVIS, MULTI = {}, {}, {}, {}
    local ok = _G.grndQrAutoDraw(CTX)
    check(ok == true, "раздел «Автопилот» не нарисовался")
end
-- v1.19.32: строки подсказки внизу раздела (в них фраза «репорт целиком» —
-- это законно; у поля «Триггер» такой подписи быть не должно)
local HINT_LINES = {
    "Переменные {ID}, {all}, {punishments} — в ответе или на слове в триггере («дм{ID}»)",
    "{ID} — тот, на кого пожаловались (номер или написанный ник); без них уходит ваш текст из «Ответ игроку»",
    "После ответа автопилот сам зайдёт в слежку за игроком — даже при команде /goto",
    "{all} — на слове в триггере («спек{all}»): репорт может быть из нескольких слов",
    "{punishments} — активные наказания игрока (как кнопка «Наказания игрока»)",
    "Несколько слов-триггеров в репорте — отвечает то, что раньше",
}
local function isHintLine(str)
    for i = 1, #HINT_LINES do
        local h = HINT_LINES[i]
        if str == h or str:sub(1, #h) == h or h:sub(1, #str) == str then return true end
    end
    return false
end
-- первая нарисованная строка с этим словом, которая НЕ подсказка внизу
local function foreignWith(word)
    for i = 1, #TXT do
        local str = TXT[i].str
        if str:find(word, 1, true) and not isHintLine(str) then return str end
    end
    return nil
end

check(type(A) == "table", "состояние автопилота не создано")
check(type(_G.grndQrAutoDraw) == "function", "нет отрисовки раздела")
check(type(_G.grndQrAutoOnReport) == "function", "нет хука на репорт")
check(type(_G.grndQrAutoTick) == "function", "нет тика автопилота")

-- ===== 1. конфиг: файл, стартовые значения, одна вкладка =====
check(tostring(Q.autoPath()):find("grnd_repauto.cfg", 1, true) ~= nil,
    "файл настроек не grnd_repauto.cfg: " .. tostring(Q.autoPath()))
Q.autoEnsure()
check(A.on == false, "по умолчанию автопилот должен быть выключен")
check(#Q.autoTabs() == 1, "по умолчанию должна быть одна вкладка")
check(Q.autoTabs()[1].command == "sp", "команда по умолчанию не /sp")
check(#Q.autoCmds == 3, "в списке команд не три записи")
check(Q.autoLabel(1) == "Вкладка 1", "пустая вкладка подписана не «Вкладка 1»")
HPRINT("конфиг: grnd_repauto.cfg, выключен, одна вкладка «Вкладка 1»")

-- ===== 2. вкладка рисуется: шапка, тумблер, вкладки, три поля =====
drawAuto()
check(has("Автопилот"), "нет заголовка «Автопилот»: " .. texts())
check(has("Триггер"), "нет поля «Триггер»")
check(has("Ответ игроку"), "нет поля «Ответ игроку»")
check(has("Команда после ответа"), "нет селектора команды")
check(has("Вкладка 1"), "нет самой вкладки")
check(has("выключен"), "нет строки состояния")
-- v1.19.36: внизу раздела — постоянные подсказки про переменные {ID} и {all}
check(hasOne("{ID} — тот, на кого пожаловались (номер или написанный ник)"),
    "нет подсказки про {ID}: " .. textsOne())
check(hasOne("После ответа автопилот сам зайдёт в слежку за игроком"),
    "нет подсказки про автослежку")
check(hasOne("{all} — на слове в триггере («спек{all}»): репорт может быть из нескольких слов"),
    "нет подсказки про {all}")
check(hasOne("{punishments} — активные наказания игрока (как кнопка «Наказания игрока»)"),
    "нет подсказки про {punishments}: " .. textsOne())
check(not has("помогите"), "осталась подсказка про систему «помогите»")
-- v1.19.34: подсказка про синонимы — СРАЗУ ПОСЛЕ названия «Триггер» (над
-- полем ввода); фраза переносится по словам и должна помещаться ЦЕЛИКОМ
check(has("Можно ввести триггер и похожие слова к триггеру (через запятую),"),
    "нет подсказки про похожие слова у поля «Триггер»: " .. texts())
local hintTail = "так будет реагировать"
local hintFull, hintY, hintY2 = false, nil, nil
for i = 1, #TXT do
    local str = tostring(TXT[i].str)
    if str:find("Можно ввести триггер", 1, true) then
        hintY = TXT[i].y
        if str:sub(-#hintTail) == hintTail then hintFull = true end
    end
    if str:sub(-#hintTail) == hintTail then hintY2 = TXT[i].y end
end
check(hintFull or hintY2 ~= nil, "подсказка про похожие слова обрезана: " .. texts())
check(not has("напр. помогите"), "вернулся прежний placeholder «напр. помогите»")
-- подсказка стоит НАД полем «Триггер» и ПОД названием «Триггер»
local labelY = nil
for i = 1, #TXT do
    if TXT[i].str == "Триггер" then labelY = TXT[i].y end
end
local fieldY = nil
for i = 1, #INPUTS do
    if INPUTS[i].id == "##grnd_qr_auto_trigger" then fieldY = INPUTS[i].y end
end
check(labelY ~= nil, "не найдено название «Триггер»")
check(fieldY ~= nil, "не найдено поле «Триггер»")
check(hintY ~= nil, "не найдена первая строка подсказки")
check(hintY > labelY, "подсказка стоит выше названия «Триггер»: " .. tostring(hintY))
check(hintY < fieldY, "подсказка должна быть НАД полем «Триггер», а она под ним")
check(hintY - labelY < 30, "подсказка оторвалась от названия «Триггер»: " .. tostring(hintY - labelY))
-- лишние подписи и кнопки убраны (v1.19.23)
local goneList = { "вкладок:", "срабатываний", "Добавить вкладку", "Удалить (",
                   "пусто — вкладка молчит", "подставятся сами", "Срабатывания",
                   "Проверка триггера", "репорты проходят мимо",
                   "слишком короткий" }
for _, gone in ipairs(goneList) do
    check(not has(gone), "вернулась лишняя надпись «" .. gone .. "»: " .. texts())
end
check(not has("Удалить"), "вернулась кнопка удаления вкладки")
-- подсказки про {ID}/{all} живут только внизу раздела
check(foreignWith("найдёт ID в репорте") == nil,
    "подсказка про {ID} попала не только вниз раздела")
-- вкладки нажимаются, у каждой есть крестик, добавление — плюс
local names = table.concat(BTNS, " ")
check(names:find("##grnd_qr_auto_tab_1", 1, true) ~= nil, "вкладка не нажимается")
check(names:find("##grnd_qr_auto_tabc_1", 1, true) ~= nil, "у вкладки нет крестика")
check(names:find("##grnd_qr_auto_add", 1, true) ~= nil, "нет кнопки-плюса")
check(names:find("##grnd_qr_auto_del", 1, true) == nil, "осталась кнопка «Удалить»")
HPRINT("вкладка: шапка, вкладки с крестиками, плюс, три поля — без лишних надписей")

-- ===== 3. тумблер =====
CLICK = { ["##grnd_qr_auto_on"] = true }
drawAuto()
CLICK = {}
check(A.on == true, "тумблер не включил автопилот")
check(TOASTS[#TOASTS] == "Автопилот включён", "нет тоста о включении")
check(not has("при репорте"), "под тумблером осталась строка «при репорте: …»")
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
Q.autoSet(true)
HPRINT("тумблер: родная «пилюля» скрипта, запасной вариант тоже работает")

-- ===== 4. поля первой вкладки: один триггер, ответ, подстановки =====
TYPE["##grnd_qr_auto_trigger"] = "Помогите"
drawAuto()
local t1 = Q.autoTabs()[1]
check(t1.trigger == "Помогите", "триггер не записался: " .. tostring(t1.trigger))
check(Q.autoLabel(1) == "Помогите", "подпись вкладки не стала триггером: " .. Q.autoLabel(1))
check(Q.autoTriggers(t1)[1] == "помогите", "триггер не приводится к нижнему регистру")
check(Q.autoMatchTab("ПОМОГИТЕ") == 1, "кириллица в верхнем регистре не найдена")
check(Q.autoMatchTab("  помогите  ") == 1, "лишние пробелы вокруг сбивают совпадение")
check(Q.autoMatchTab("{FF0000}помогите") == 1, "код цвета мешает совпадению")
check(Q.autoMatchTab("ПОМОГИТЕ!!!") == nil, "с пунктуацией не должно совпадать")
check(Q.autoMatchTab("помогите плиз") == nil, "лишнее слово не должно совпадать")
check(Q.autoMatchTab("помогите, дм") == nil, "второй триггер в репорте не нужен")
check(Q.autoMatchTab("помогитеплиз") == nil, "склейка слов не должна считаться триггером")
check(Q.autoMatchTab("помогитеее") == nil, "удлинение слова не должно считаться триггером")
check(Q.autoMatchTab("плиз, помогите") == nil, "триггер не в начале репорта не должен срабатывать")
check(Q.autoMatchTab("Help me") == nil, "найдено лишнее совпадение")
TYPE["##grnd_qr_auto_answer"] = "Приветствую, {ник}! Уже смотрю. {ид}"
drawAuto()
check(t1.answer == "Приветствую, {ник}! Уже смотрю. {ид}",
    "ответ не записался: " .. tostring(t1.answer))
check(not texts():find("{ник}", 1, true), "в разделе осталась подсказка с {ник}")
-- подсказки внизу — постоянный текст про {ID}/{all}, от полей вкладки не зависят
local hint1 = HINT_LINES[1]
local hint2 = HINT_LINES[2]
local hint3 = HINT_LINES[3]
local hint4 = HINT_LINES[4]
local hint5 = HINT_LINES[5]
check(hasOne(hint1), "подсказка про {ID} изменилась при введённом триггере: " .. textsOne())
check(hasOne(hint2), "вторая строка подсказки пропала: " .. textsOne())
check(hasOne(hint3), "третья строка ({all}) пропала")
check(hasOne(hint4) and hasOne(hint5), "строки про {ID}/{punishments} пропали: " .. textsOne())
HPRINT("вкладка 1: триггер «Помогите», ответ с {ник}/{ид}, подпись = триггер, подсказки про {ID}/{all}")

-- короткий триггер разрешён: без предупреждений и работает
TYPE["##grnd_qr_auto_trigger"] = "я"
drawAuto()
check(t1.trigger == "я", "короткий триггер не записался: " .. tostring(t1.trigger))
for _, gone in ipairs({ "слишком короткий" }) do
    check(not has(gone), "у поля «Триггер» вернулась подпись «" .. gone .. "»")
end
check(foreignWith("найдёт ID в репорте") == nil,
    "подсказка про {ID} вернулась к полю «Триггер»")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Короткий", 210, "я") == true, "короткий триггер не сработал")
-- v1.19.46: в репорте нет ни номера, ни имени — ник и ID не подставляются,
-- остаётся свой текст из «Ответ игроку» (без лишних запятых)
check(#QUEUE == 2 and QUEUE[1] == "/ans 210 Приветствую! Уже смотрю."
    and QUEUE[2] == "/sp 210", "короткий триггер отправил не то: " .. tostring(QUEUE[1]))
-- подсказка не зависит от длины триггера и всегда помещается целиком
TYPE["##grnd_qr_auto_trigger"] = "помогите пожалуйста очень нужно прямо сейчас"
drawAuto()
check(hasOne(hint1), "подсказка срезалась при длинном триггере: " .. textsOne())
check(hasOne(hint2), "вторая строка подсказки срезалась при длинном триггере")
check(hasOne(hint3), "третья строка подсказки срезалась при длинном триггере")
check(hasOne(hint4) and hasOne(hint5), "подсказки срезались при длинном триггере")
TYPE["##grnd_qr_auto_trigger"] = "Помогите"
drawAuto()
-- и после удаления поля триггера тоже на месте
drawAuto()
check(hasOne(hint1) and hasOne(hint2) and hasOne(hint3) and hasOne(hint4) and hasOne(hint5),
    "подсказка пропала после сброса триггера")
HPRINT("короткий триггер: ставится и срабатывает, предупреждений нет; подсказка постоянная")

-- ===== 5. селектор команды и строка-предпросмотр =====
CLICK = { ["##grnd_qr_auto_cmd"] = true }
drawAuto()
CLICK = {}
check(A.listOpen == true, "список команд не открылся")
drawAuto()
check(has("/goto") and has("слежка за игроком"), "в списке нет команд: " .. texts())
CLICK = { ["##grnd_qr_auto_cmd_goto"] = true }
drawAuto()
CLICK = {}
check(t1.command == "goto", "команда не переключилась: " .. tostring(t1.command))
check(A.listOpen == false, "список не закрылся после выбора")
check(Q.autoCmdFor(25, t1) == "/goto 25", "команда для ID не собралась")
check(Q.autoCmdFor("—", t1) == nil, "команда собралась без числового ID")
drawAuto()
check(has("/ans 25"), "в предпросмотре нет ответа: " .. texts())
check(has("затем /goto 25"), "в предпросмотре нет команды")
HPRINT("селектор: /goto, предпросмотр «/ans 25 … затем /goto 25» одной строкой")

-- ===== 5b. селектор команд не «мигает» при повторном клике (v1.19.35) =====
-- Раньше: нажатие закрывало список (клик «мимо» списка), а отпускание тут же
-- открывало его снова — список уходил и появлялся обратно.
CLICK = {}
GRND_MOUSE.x, GRND_MOUSE.y, GRND_MOUSE.frame = -500, -500, -9999
A.listOpen = false
drawAuto()
check(A.listOpen == false, "перед проверкой список команд должен быть закрыт")
-- 1) открываем список: кадр отпускания кнопки по селектору
CLICK = { ["##grnd_qr_auto_cmd"] = true }
drawAuto()
CLICK = {}
check(A.listOpen == true, "первый клик не открыл список команд")
-- 2) кадр НАЖАТИЯ второго клика: мышь над селектором, кнопка ещё не отпущена.
--    Список закрывать нельзя, иначе он «мигнёт».
local selRect = nil
for i = 1, #INVIS do
    if INVIS[i].id == "##grnd_qr_auto_cmd" then selRect = INVIS[i] end
end
check(selRect ~= nil, "селектор не найден среди кнопок")
GRND_UIFRAME = GRND_UIFRAME + 1
GRND_MOUSE.x, GRND_MOUSE.y = selRect.x + 12, selRect.y + 12
GRND_MOUSE.frame = GRND_UIFRAME
drawAuto()
check(A.listOpen == true, "нажатие на селектор закрыло список — будет «мигание»")
-- 3) кадр отпускания: список закрывается и больше не открывается
CLICK = { ["##grnd_qr_auto_cmd"] = true }
GRND_MOUSE.frame = -9999
drawAuto()
CLICK = {}
check(A.listOpen == false, "повторный клик по селектору не закрыл список")
-- 4) клик мимо списка по-прежнему закрывает его
CLICK = { ["##grnd_qr_auto_cmd"] = true }
drawAuto()
CLICK = {}
check(A.listOpen == true, "список не открылся снова")
GRND_UIFRAME = GRND_UIFRAME + 1
GRND_MOUSE.x, GRND_MOUSE.y = 5000, 5000
GRND_MOUSE.frame = GRND_UIFRAME
drawAuto()
check(A.listOpen == false, "клик мимо списка не закрыл его")
GRND_MOUSE.x, GRND_MOUSE.y, GRND_MOUSE.frame = -500, -500, -9999
HPRINT("селектор: первый клик открывает, второй закрывает — без «мигания»; клик мимо закрывает")

-- ===== 6. добавление вкладок =====
CLICK = { ["##grnd_qr_auto_add"] = true }
drawAuto()
CLICK = {}
check(#Q.autoTabs() == 2, "вкладка не добавилась: " .. tostring(#Q.autoTabs()))
check(A.sel == 2, "после добавления не выбрана новая вкладка")
check(Q.autoLabel(2) == "Вкладка 2", "новая вкладка подписана неверно")
TYPE["##grnd_qr_auto_trigger"] = "дм"
TYPE["##grnd_qr_auto_answer"] = "Не пишите в личку, отвечу в репорте"
drawAuto()
local t2 = Q.autoTabs()[2]
check(t2.trigger == "дм" and t2.answer == "Не пишите в личку, отвечу в репорте",
    "поля второй вкладки не записались")
check(Q.autoTabs()[1].trigger == "Помогите", "поля первой вкладки испортились")
drawAuto()
check(has("Помогите") and has("дм"), "обе вкладки не показаны: " .. texts())
HPRINT("вкладки: «Добавить вкладку» → вторая вкладка со своим триггером и ответом")

-- ===== 7. у каждой вкладки своя команда: /sp, /goto, «без команды» =====
CLICK = { ["##grnd_qr_auto_cmd"] = true }
drawAuto()
CLICK = {}
CLICK = { ["##grnd_qr_auto_cmd_sp"] = true }
drawAuto()
CLICK = {}
check(Q.autoTabs()[2].command == "sp", "команда второй вкладки не /sp")
check(Q.autoTabs()[1].command == "goto", "команда первой вкладки испортилась")
check(Q.autoCmdFor(77, Q.autoTabs()[1]) == "/goto 77", "первая вкладка шлёт не /goto")
check(Q.autoCmdFor(77, Q.autoTabs()[2]) == "/sp 77", "вторая вкладка шлёт не /sp")
Q.autoTabs()[2].command = "none"
check(Q.autoCmdFor(77, Q.autoTabs()[2]) == nil, "«без команды» всё равно собирает команду")
Q.autoTabs()[2].command = "sp"
HPRINT("команды вкладок независимы: /goto у первой, /sp у второй")

-- ===== 8. выключенный автопилот репорты не трогает =====
NOW = NOW + 10
A.rate = {}
Q.autoSet(false)
QUEUE, ANS, CHAT, ORDER = {}, {}, {}, {}
local okOff, whyOff = Q.autoOnReport("Mixa_Grozz", 25, "Помогите")
check(okOff == false and whyOff == "выключен", "выключенный автопилот сработал: " .. tostring(whyOff))
check(#QUEUE == 0, "выключенный автопилот что-то отправил")
check(Q.autoSet(true) == true, "автопилот не включился")
HPRINT("выключен: репорты проходят мимо, в чат ничего не уходит")

-- ===== 9. репорт попадает в нужную вкладку =====
NOW = NOW + 10
A.rate = {}
QUEUE, ANS, CHAT, ORDER, ANSICALLS = {}, {}, {}, {}, {}
local fired, hit = Q.autoOnReport("Mixa_Grozz", 25, "Помогите")
check(fired == true, "репорт с триггером не обработан")
check(hit == "помогите", "сработал не тот триггер: " .. tostring(hit))
check(#QUEUE == 2, "в очередь встало не две строки: " .. tostring(#QUEUE))
-- v1.19.46: ни номера, ни имени в репорте — ник и ID не подставляются
check(QUEUE[1] == "/ans 25 Приветствую! Уже смотрю.",
    "первым в очереди не ответ первой вкладки: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/goto 25", "второй в очереди не команда первой вкладки: " .. tostring(QUEUE[2]))
check(#ANSICALLS == 2 and ANSICALLS[1] == "Приветствую! Уже смотрю."
    and ANSICALLS[2] == "/goto 25", "текст ушёл без перевода в CP1251")
grndRepQueueTick()
check(#ORDER == 2 and ORDER[1] == "ans" and ORDER[2] == "chat",
    "порядок неверный: " .. table.concat(ORDER, ","))
check(ANS[1] == "25 Приветствую! Уже смотрю.",
    "игроку ушёл не тот ответ: " .. tostring(ANS[1]))
check(A.lastCheck:find("вкладки 1", 1, true) ~= nil, "нет пометки вкладки: " .. tostring(A.lastCheck))

-- та же ситуация, но триггер второй вкладки
NOW = NOW + 100
A.rate = {}
QUEUE, ANS, CHAT, ORDER, ANSICALLS = {}, {}, {}, {}, {}
local fired2, hit2 = Q.autoOnReport("Другой", 77, "дм")
check(fired2 == true and hit2 == "дм", "вторая вкладка не сработала: " .. tostring(hit2))
check(#QUEUE == 2 and QUEUE[1] == "/ans 77 Не пишите в личку, отвечу в репорте"
    and QUEUE[2] == "/sp 77", "вторая вкладка отправила не то: " .. tostring(QUEUE[1]))
check(A.lastCheck:find("вкладки 2", 1, true) ~= nil, "нет пометки второй вкладки")
-- обычная вкладка (без {ID}/{all}) требует полного совпадения репорта
NOW = NOW + 100
A.rate = {}
QUEUE, ANS, ANSICALLS = {}, {}, {}
local okExtra, whyExtra = Q.autoOnReport("Третий", 88, "помогите, дм")
check(okExtra == false and whyExtra == "нет триггера",
    "обычная вкладка сработала на репорт с лишними словами: " .. tostring(whyExtra))
check(#QUEUE == 0, "на репорт с лишними словами что-то ушло")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
local okGlue, whyGlue = Q.autoOnReport("Пятый", 89, "помогитеплиз")
check(okGlue == false and whyGlue == "нет триггера",
    "склейка «помогитеплиз» сработала: " .. tostring(whyGlue))
check(#QUEUE == 0, "на склейку что-то ушло")
-- одинаковый триггер в двух вкладках: срабатывают ОБЕ, по порядку вкладок
Q.autoTabs()[2].trigger = "Помогите"
Q.autoTabs()[2].command = "sp"
NOW = NOW + 100
A.rate = {}
QUEUE, ANSICALLS = {}, {}
check(Q.autoOnReport("Четвёртый", 99, "помогите") == true, "совпадение по двум вкладкам не сработало")
check(#QUEUE == 4, "с двух вкладок встало не 4 строки: " .. tostring(#QUEUE))
check(QUEUE[1] == "/ans 99 Приветствую! Уже смотрю."
    and QUEUE[2] == "/goto 99", "первая вкладка отправила не своё: " .. tostring(QUEUE[1]))
check(QUEUE[3] == "/ans 99 Не пишите в личку, отвечу в репорте"
    and QUEUE[4] == "/sp 99", "вторая вкладка отправила не своё: " .. tostring(QUEUE[3]))
check(A.lastCheck:find("вкладки 1, 2", 1, true) ~= nil,
    "в подсказке нет обеих вкладок: " .. tostring(A.lastCheck))
check(TOASTS[#TOASTS]:find("вкладок 2", 1, true) ~= nil,
    "тост не сообщает про две вкладки: " .. tostring(TOASTS[#TOASTS]))
Q.autoTabs()[2].trigger = "дм"
HPRINT("срабатывание: триггер = весь репорт; совпавшие вкладки срабатывают все, по порядку")

-- ===== 9b. переменная {ID}: ID из репорта + автослежка (v1.19.36) =====
-- Вкладка 1 отвечает «…игроком {ник}[{ID}]» и имеет команду /goto, но при
-- найденном в репорте ID автопилот идёт в СЛЕЖКУ (/sp ID), а не телепортируется.
-- v1.19.43: переменная действует только на то слово, на которое написана,
-- поэтому {ID} вешаем на САМО слово в триггере — «дм{ID}».
Q.autoTabs()[1].trigger = "дм{ID}"
Q.autoTabs()[1].answer = "Приветствую, слежу за игроком {ник}[{ID}]"
Q.autoTabs()[1].command = "goto"
Q.autoTabs()[2].trigger = "спек{all}"
Q.autoTabs()[2].answer = "Уже разбираюсь"
Q.autoTabs()[2].command = "sp"
Q.autoEnsure()
-- v1.19.46: ник берём у того, на кого пожаловались (по ID из игры)
NICK_BY_ID = { [234] = "Mixa_Grozz", [1] = "Mixa_Grozz", [77] = "Mixa_Grozz",
    [12] = "Mixa_Grozz" }
check(Q.autoFindReportId("дм 234 — он стреляет") == "234", "ID из репорта не найден")
check(Q.autoFindReportId("234 дм") == "234", "ID в начале репорта не найден")
check(Q.autoFindReportId("спек 7") == "7", "короткий ID не найден")
check(Q.autoFindReportId("дм") == nil, "в репорте без чисел ID не должен находиться")
check(Q.autoFindReportId("дм 2345abc") == nil, "число, приклеенное к буквам, не ID")
local idCases = {
    { "дм 234", "234" }, { "234 дм", "234" }, { "ДМ 1", "1" },
    { "  дм   77  ", "77" }, { "{FF0000}дм{FFFFFF} 12", "12" },
}
for _, case in ipairs(idCases) do
    NOW = NOW + 100
    A.rate = {}
    QUEUE, ANSICALLS = {}, {}
    local ok = Q.autoOnReport("Жалобщик", 25, case[1])
    check(ok == true, "репорт «" .. case[1] .. "» не сработал")
    check(#QUEUE == 2, "по «" .. case[1] .. "» встало не 2 строки: " .. tostring(#QUEUE))
    check(QUEUE[1] == "/ans 25 Приветствую, слежу за игроком Mixa_Grozz[" .. case[2] .. "]",
        "подстановка {ID} не сработала: " .. tostring(QUEUE[1]))
    check(QUEUE[2] == "/sp " .. case[2],
        "автопилот не ушёл в слежку за найденным ID: " .. tostring(QUEUE[2]))
end
-- v1.19.46: без номера и имени в репорте ник и ID не подставляются — уходит
-- СВОЙ текст из «Ответ игроку», а команда вкладки остаётся
Q.autoTabs()[1].answer = "Уже разбираюсь"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Mixa_Grozz", 25, "дм") == true, "«дм» без числа не сработал")
check(QUEUE[1] == "/ans 25 Уже разбираюсь" and QUEUE[2] == "/goto 25",
    "свой текст без ника и ID не ушёл: " .. tostring(QUEUE[1]) .. " | " .. tostring(QUEUE[2]))
Q.autoTabs()[1].answer = "Приветствую, слежу за игроком {ник}[{ID}]"
Q.autoEnsure()
-- приклеенное слово — не совпадение даже в режиме {ID}
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Mixa_Grozz", 25, "дмх 234") == false, "«дмх 234» не должен срабатывать")
check(#QUEUE == 0, "на «дмх 234» что-то ушло")
-- v1.19.43: переменная в поле «Ответ» поиск НЕ расширяет — слово ищется как
-- обычно, а переменная только подставляет значение
Q.autoTabs()[1].trigger = "дм"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Mixa_Grozz", 25, "дм 234") == false,
    "переменная в ответе всё ещё расширяет поиск")
check(#QUEUE == 0, "на «дм 234» с обычным триггером что-то ушло")
check(Q.autoOnReport("Mixa_Grozz", 25, "дм") == true, "точное «дм» с ответом {ID} не сработало")
-- v1.19.46: номера и имени в репорте нет — {ник}/{ID} не подставляются
check(QUEUE[1] == "/ans 25 Приветствую, слежу за игроком",
    "без номера ник и ID подставляться не должны: " .. tostring(QUEUE[1]))
Q.autoTabs()[1].trigger = "дм{ID}"
Q.autoEnsure()

-- ===== 9c. переменная {all}: триггер словом в любом месте репорта =====
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Другой", 26, "спек 77") == true, "«спек 77» не сработал")
check(QUEUE[1] == "/ans 26 Уже разбираюсь", "{all} не убрался из ответа: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/sp 26", "команда вкладки со {all} не ушла: " .. tostring(QUEUE[2]))
for _, rep in ipairs({ "четверо спек", "надо спек", "СПЕК!" }) do
    NOW = NOW + 100
    A.rate = {}
    QUEUE = {}
    check(Q.autoOnReport("Третий", 27, rep) == true, "«" .. rep .. "» не сработал")
    check(QUEUE[1] == "/ans 27 Уже разбираюсь", "«" .. rep .. "»: не тот ответ")
end
for _, rep in ipairs({ "спектр", "спек77", "не спек77" }) do
    check(#Q.autoMatchAll(rep) == 0,
        "«" .. rep .. "» не должно совпадать (слово приклеено)")
end
-- возвращаем вкладки к состоянию до этих проверок (дальше идут их сценарии)
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoTabs()[2].trigger = "дм"
Q.autoTabs()[2].answer = "Не пишите в личку, отвечу в репорте"
Q.autoTabs()[2].command = "sp"
Q.autoEnsure()
HPRINT("{ID}: ID из репорта → ответ + слежка /sp; {all}: триггер словом в любом месте, служебное слово убрано")

-- ===== 9d. переменная {punishments}: наказания игрока из окна /getinfo (v1.19.37) =====
-- Автопилот шлёт /getinfo ID, окно сервера перехватывается и прячется, список
-- наказаний подставляется вместо {punishments}, и уже потом уходит команда.
Q.autoTabs()[3] = Q.autoNewTab()
Q.autoTabs()[3].trigger = "проверь"
Q.autoTabs()[3].answer = "Приветствую, ваши наказания: {punishments}"
Q.autoTabs()[3].command = "sp"
Q.autoEnsure()
local PBODY = "Аккаунт Test_User[30]\nМут 60 минут\nБан 3 дня"
check(Q.punLooksDialog("Активные наказания игрока", PBODY), "окно /getinfo не распознано")
check(not Q.punLooksDialog("Обычное окно", "просто текст"), "чужое окно принято за наказания")
check(#Q.punParse(PBODY) == 2, "разбор окна: строк должно быть 2, а не " .. #Q.punParse(PBODY))
check(Q.punParse(PBODY)[1] == "Мут 60 минут", "разбор окна: первая строка не та")
check(#Q.punParse("Аккаунт Ник[5]") == 0, "строка «Аккаунт …» должна отбрасываться")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 30, "проверь") == true, "репорт с {punishments} не принят")
check(#QUEUE == 1 and QUEUE[1] == "/getinfo 30",
    "автопилот не запросил наказания: " .. tostring(QUEUE[1]))
check(#ANS == 0, "ответ ушёл до окна наказаний")
check(A.pend and A.pend.on, "нет ожидания окна наказаний")
local okWait, whyWait = Q.autoOnReport("Другой", 31, "проверь")
check(okWait == false and whyWait == "ждём ответ на /getinfo",
    "второй репорт не подождал окно: " .. tostring(whyWait))
-- окно пришло: хук прячет его, ответ уходит со списком, следом команда вкладки
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "", PBODY) == true,
    "окно наказаний не спрятано")
check(A.pend == nil, "ожидание окна не снято")
check(QUEUE[1] == "/ans 30 Приветствую, ваши наказания: Мут 60 минут | Бан 3 дня",
    "наказания не подставились: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/sp 30", "после ответа не ушла команда вкладки: " .. tostring(QUEUE[2]))
-- наказаний нет: окно из одной строки «Аккаунт …»
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Чистый", 32, "проверь") == true, "репорт не принят")
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "", "Аккаунт Чистый[32]") == true,
    "окно без наказаний не спрятано")
check(QUEUE[1] == "/ans 32 Приветствую, ваши наказания: нет активных наказаний",
    "нет ответа про отсутствие наказаний: " .. tostring(QUEUE[1]))
-- окно не пришло: отвечаем без списка (и не молчим)
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Молчун", 33, "проверь") == true, "репорт не принят")
QUEUE = {}
NOW = NOW + 6
Q.punPoll()
check(QUEUE[1] == "/ans 33 Приветствую, ваши наказания: нет данных о наказаниях",
    "таймаут окна: не тот ответ: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/sp 33", "таймаут окна: команда не ушла")
check(A.pend == nil, "таймаут окна: ожидание не снято")
-- длинный список уходит несколькими сообщениями (у чата есть лимит длины)
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Долгий", 34, "проверь") == true, "репорт не принят")
local LBODY = "Аккаунт Долгий[34]\n" .. string.rep("Очень длинное наказание ", 12)
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "", LBODY) == true,
    "длинное окно не спрятано")
local ansCount = 0
for qi = 1, #QUEUE do
    if QUEUE[qi]:sub(1, 5) == "/ans " then ansCount = ansCount + 1 end
end
check(ansCount >= 2, "длинный список не порезан на сообщения: " .. tostring(#QUEUE))
check(QUEUE[#QUEUE] == "/sp 34", "длинный список: команда не последняя: " .. tostring(QUEUE[#QUEUE]))
-- кнопка «Наказания игрока» (ручной режим) работает как раньше
CHAT, ANS, QUEUE = {}, {}, {}
check(Q.punBegin(40, "Ручной", "manual") == true, "ручное ожидание не началось")
check(Q.punBegin(41, "Второй", "manual") == false, "второе окно перебило первое")
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "", PBODY) == true,
    "ручное окно не спрятано")
check(CHAT[1] == "/ans 40 Приветствую, ваши активные наказания >> Мут 60 минут | Бан 3 дня",
    "ручной режим: не тот ответ: " .. tostring(CHAT[1]) .. " | " .. tostring(QUEUE[1]))
-- убираем третью вкладку: дальше идут сценарии с двумя
Q.autoDel(3)
Q.autoEnsure()
HPRINT("{punishments}: /getinfo → список в ответ + команда; таймаут, пусто, длинный список и ручной режим")

-- ===== 9e. канал проверки: ответы автопилота уходят в /n (v1.19.38) =====
-- Пока включена проверка (QR.autoTest), тексты ответов уходят в локальный /n
-- вместо /ans: игроки ничего не получают, админ видит ровно тот текст, который
-- ушёл бы. Команды вкладок и /getinfo при {punishments} остаются боевыми.
Q.autoTest = true
Q.autoTabs()[1].trigger = "проверка"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Проверка ответа"
Q.autoTabs()[1].command = "sp"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE, ANS, CHAT = {}, {}, {}
check(Q.autoOnReport("Mixa_Grozz", 55, "проверка") == true, "репорт не принят в режиме проверки")
check(QUEUE[1] == "/n /ans 55 Приветствую! Проверка ответа",
    "строка ответа не ушла в /n целиком: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/n /sp 55", "команда вкладки не ушла в /n: " .. tostring(QUEUE[2]))
for qi = 1, #QUEUE do
    check(QUEUE[qi]:sub(1, 5) ~= "/ans ", "в режиме проверки ушёл настоящий /ans: " .. tostring(QUEUE[qi]))
end
check(#ANS == 0, "в режиме проверки игроку всё равно ушёл ответ")
check(A.lastCheck:find("проверка /n", 1, true) ~= nil,
    "в состоянии нет пометки проверки: " .. tostring(A.lastCheck))
check(TOASTS[#TOASTS]:find("проверка /n", 1, true) ~= nil,
    "тост не сообщает про проверку: " .. tostring(TOASTS[#TOASTS]))
-- {punishments} в режиме проверки: сам запрос настоящий (иначе списка не
-- получить — окно перехватывается и игроку не показывается), а в чате видна
-- та же строка с «/n»
Q.autoTabs()[2] = Q.autoNewTab()
Q.autoTabs()[2].trigger = "чек"
Q.autoTabs()[2].answer = "Ваши наказания: {punishments}"
Q.autoTabs()[2].command = "none"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE, ANS = {}, {}
check(Q.autoOnReport("Чек", 56, "чек") == true, "репорт с {punishments} не принят")
check(QUEUE[1] == "/getinfo 56", "настоящий запрос не ушёл: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/n /getinfo 56",
    "строка проверки не ушла в /n: " .. tostring(QUEUE[2]))
check(QUEUE[3] == nil, "ответ ушёл до окна наказаний: " .. tostring(QUEUE[3]))
check(A.pend ~= nil and A.pend.on == true, "автопилот не ждёт окно наказаний")
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "",
    "Аккаунт Чек[56]\nМут 60 минут") == true, "окно наказаний не спрятано")
check(A.pend == nil, "ожидание окна не снято")
check(QUEUE[1] == "/n /ans 56 Ваши наказания: Мут 60 минут",
    "настоящий список не ушёл в /n: " .. tostring(QUEUE[1]))
-- возвращаем боевой режим, первую и вторую вкладки к прежнему виду
QUEUE = {}
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoTabs()[2].trigger = "дм"
Q.autoTabs()[2].answer = "Не пишите в личку, отвечу в репорте"
Q.autoTabs()[2].command = "sp"
Q.autoEnsure()
Q.autoTest = false
HPRINT("проверка /n: и ответы, и команды, и /getinfo уходят строками «/n …»")

-- ===== 9f. переменные можно писать в ТРИГГЕРЕ (v1.19.40) =====
-- «дм{ID}», «спек{all}», «наказ{punishments}»: служебные {…} вычищаются при
-- разборе (в репорте такого слова нет), а переменная включает режим вкладки.
Q.autoTabs()[1].trigger = "дм{ID}"
Q.autoTabs()[1].answer = "Приветствую, слежу за игроком {ник}[{ID}]"
Q.autoTabs()[1].command = "goto"
Q.autoEnsure()
check(#Q.autoTriggers(Q.autoTabs()[1]) == 1 and Q.autoTriggers(Q.autoTabs()[1])[1] == "дм",
    "переменная в триггере не вычищена: " .. table.concat(Q.autoTriggers(Q.autoTabs()[1]), "|"))
local hID, hAll, hPun = Q.autoVarFlags(Q.autoTabs()[1])
check(hID == true and hAll == false and hPun == false,
    "переменная в триггере не включила режим {ID}")
for _, rep in ipairs({ "дм 234", "234 дм" }) do
    NOW = NOW + 100
    A.rate = {}
    QUEUE = {}
    check(Q.autoOnReport("Mixa_Grozz", 25, rep) == true, "«" .. rep .. "» не сработал на «дм{ID}»")
    check(QUEUE[1] == "/ans 25 Приветствую, слежу за игроком Mixa_Grozz[234]"
        and QUEUE[2] == "/sp 234",
        "«" .. rep .. "»: не то отправлено: " .. tostring(QUEUE[1]) .. " | " .. tostring(QUEUE[2]))
end
-- v1.19.46: репорт БЕЗ номера и имени — вкладка срабатывает, но ник и ID не
-- подставляются: уходит свой текст из «Ответ игроку», команда вкладки остаётся
Q.autoTabs()[1].answer = "Уже разбираюсь"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Без_ид", 26, "дм") == true, "репорт без ID не сработал")
check(QUEUE[1] == "/ans 26 Уже разбираюсь" and QUEUE[2] == "/goto 26",
    "без ID должен уходить свой текст и своя команда: "
        .. tostring(QUEUE[1]) .. " | " .. tostring(QUEUE[2]))
Q.autoTabs()[1].answer = "Приветствую, слежу за игроком {ник}[{ID}]"
Q.autoEnsure()
-- {all} в триггере: слово ищется в любом месте репорта
Q.autoTabs()[1].trigger = "спек{all}"
Q.autoTabs()[1].answer = "Уже разбираюсь"
Q.autoTabs()[1].command = "none"
Q.autoEnsure()
check(#Q.autoTriggers(Q.autoTabs()[1]) == 1 and Q.autoTriggers(Q.autoTabs()[1])[1] == "спек",
    "«спек{all}» не разобран")
for _, rep in ipairs({ "спек 77", "четверо спек", "СПЕК!" }) do
    NOW = NOW + 100
    A.rate = {}
    QUEUE = {}
    check(Q.autoOnReport("Третий", 27, rep) == true, "«" .. rep .. "» не сработал на «спек{all}»")
    check(QUEUE[1] == "/ans 27 Уже разбираюсь", "«" .. rep .. "»: не тот ответ: " .. tostring(QUEUE[1]))
end
check(#Q.autoMatchAll("спектр") == 0, "«спектр» не должно совпадать")
-- {punishments} в ОТВЕТЕ: список запрашивается и подставляется в свой текст.
-- v1.19.43: переменная в ответе поиск не расширяет — слово ищется как обычно,
-- поэтому репорт должен совпасть с триггером целиком («наказ», а не «мои наказ»)
Q.autoTabs()[1].trigger = "наказ"
Q.autoTabs()[1].answer = "Приветствую, ваши наказания: {punishments}"
Q.autoTabs()[1].command = "none"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 28, "мои наказ плиз") == false,
    "переменная в ответе всё ещё расширяет поиск")
check(#QUEUE == 0, "на неточный репорт что-то ушло")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 28, "наказ") == true, "точный «наказ» не сработал")
check(QUEUE[1] == "/getinfo 28", "запрос наказаний не ушёл: " .. tostring(QUEUE[1]))
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "",
    "Аккаунт Жалобщик[28]\nМут 60 минут") == true, "окно наказаний не спрятано")
check(QUEUE[1] == "/ans 28 Приветствую, ваши наказания: Мут 60 минут",
    "список не подставился: " .. tostring(QUEUE[1]))

-- ===== 9g. {punishments} в триггере: ответ только про наказания (v1.19.41) =====
Q.autoTest = false
Q.autoTabs()[1].trigger = "наказ{punishments}"
Q.autoTabs()[1].answer = "этот текст не должен использоваться"
Q.autoTabs()[1].command = "none"
Q.autoEnsure()
check(Q.autoPunInTrigger(Q.autoTabs()[1]) == true, "{punishments} в триггере не распознан")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "наказ") == true, "триггер «наказ{punishments}» не сработал")
check(QUEUE[1] == "/getinfo 70", "запрос наказаний не ушёл: " .. tostring(QUEUE[1]))
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "",
    "Аккаунт Жалобщик[70]\nМут 60 минут\nБан 3 дня") == true, "окно не спрятано")
check(QUEUE[1] == "/ans 70 Приветствую, ваши активные наказания >> Мут 60 минут | Бан 3 дня",
    "ответ не про наказания: " .. tostring(QUEUE[1]))
-- ничего не найдено: фраза как у кнопки «Наказания игрока»
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Чистый", 71, "наказ") == true, "репорт не принят")
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "", "Аккаунт Чистый[71]") == true,
    "окно не спрятано")
check(QUEUE[1] == "/ans 71 Приветствую, активных наказаний у вас нет.",
    "нет ответа про отсутствие наказаний: " .. tostring(QUEUE[1]))
-- окно не пришло: отвечаем, не молчим
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Молчун", 72, "наказ") == true, "репорт не принят")
QUEUE = {}
NOW = NOW + 6
Q.punPoll()
check(QUEUE[1] == "/ans 72 Приветствую, ваши активные наказания >> нет данных о наказаниях",
    "таймаут окна: не тот ответ: " .. tostring(QUEUE[1]))
-- вкладка, где в триггере ТОЛЬКО переменная, отвечает на любой репорт
Q.autoTabs()[1].trigger = "{punishments}"
Q.autoTabs()[1].command = "none"
Q.autoEnsure()
check(Q.autoVarsOnly(Q.autoTabs()[1]) == true, "вкладка без слов не распознана")
check(#Q.autoMatchAll("совершенно любой текст репорта") == 1,
    "вкладка с одним {punishments} не отвечает на любой репорт")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Любой", 73, "абсолютно любой текст") == true,
    "репорт с вкладкой «{punishments}» не обработан")
check(QUEUE[1] == "/getinfo 73", "не запросил наказания: " .. tostring(QUEUE[1]))
QUEUE = {}
check(_G.grndQrPunOnDialog(10, 0, "Активные наказания игрока", "OK", "",
    "Аккаунт Любой[73]\nМут 60 минут") == true, "окно не спрятано")
check(QUEUE[1] == "/ans 73 Приветствую, ваши активные наказания >> Мут 60 минут",
    "не тот ответ: " .. tostring(QUEUE[1]))
-- и поле ответа в интерфейсе для такой вкладки не рисуется
A.sel = 1                       -- ввод эмулируем в поле ПЕРВОЙ вкладки
TYPE["##grnd_qr_auto_trigger"] = "{punishments}"
drawAuto()
check(Q.autoPunInTrigger(Q.autoTabs()[1]) == true, "поле не синхронизировалось с состоянием")
local hasAnsField = false
for i = 1, #MULTI do
    if MULTI[i].id == "##grnd_qr_auto_answer" then hasAnsField = true end
end
check(hasAnsField == false, "поле «Ответ игроку» не спряталось при {punishments} в триггере: " .. texts())
check(hasOne("Соберётся сам"), "нет пояснения вместо поля ответа: " .. textsOne())
-- возвращаем вкладку 1 к обычному виду
TYPE["##grnd_qr_auto_trigger"] = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoEnsure()
drawAuto()
local ansBack = false
for i = 1, #MULTI do
    if MULTI[i].id == "##grnd_qr_auto_answer" then ansBack = true end
end
check(ansBack == true, "поле «Ответ игроку» не вернулось после смены триггера")
check(not hasOne("Соберётся сам"), "пояснение про автоответ осталось на обычной вкладке")
-- вкладка 2 возвращается к «дм»: ввод идёт буфером поля, поэтому через TYPE
A.sel = 2
TYPE["##grnd_qr_auto_trigger"] = "дм"
Q.autoTabs()[2].trigger = "дм"
drawAuto()
check(Q.autoTabs()[2].trigger == "дм", "вкладка 2 не вернулась к «дм»")
A.sel = 1
drawAuto()
HPRINT("{punishments} в триггере: ответ только про наказания, поле ответа скрыто, вкладка без слов отвечает на всё")

-- ===== 9h. распознавание строки репорта (v1.19.41) =====
-- В игре репорт приходил, а автопилот молчал: маркер «[К-во репорта: N]»
-- искался только в одном написании, а где его нет вовсе — строка не доходила
-- до автопилота. Теперь маркер понимается в любом виде, а строка
-- «Ник[ID]: текст» отдаётся автопилоту и без маркера.
check(_G.grndRepCountOf("Artyr[261]: помогите [К-во репорта: 25]") == 25,
    "классический маркер не разобран")
check(_G.grndRepCountOf("Artyr[261]: помогите [Кол-во репорта: 25]") == 25,
    "маркер «Кол-во» не разобран")
check(_G.grndRepCountOf("Artyr[261]: помогите [К-во репорта:25]") == 25,
    "маркер без пробела не разобран")
check(_G.grndRepCountOf("Artyr[261]: помогите [К-во репорта: ]") == 1,
    "пустой номер репорта не разобран")
check(_G.grndRepCountOf("Artyr[261]: привет") == nil, "болтовня принята за репорт")
local lNick, lId, lMsg = _G.grndRepLaxParse("[ADM] Mixa_Grozz[25]: дм")
check(lNick == "Mixa_Grozz" and tostring(lId) == "25" and lMsg == "дм",
    "строка без маркера не разобрана: " .. tostring(lNick) .. " | " .. tostring(lId) .. " | " .. tostring(lMsg))
check(_G.grndRepLaxParse("<ADM> (7) Nik_Name[261]: >>> Mixa_Grozz(25): дм") == nil,
    "строка админ-бота попала в обычный разбор")
check(_G.grndRepLaxParse("Admin[287] ответил Player[113]: текст") == nil,
    "служебная строка «ответил» попала в разбор")
check(_G.grndRepLaxParse("Admin[287] взял репорт Player[113]") == nil,
    "служебная строка «взял репорт» попала в разбор")
check(_G.grndRepLaxParse("просто текст без ника") == nil, "мусор попал в разбор")
-- строки от отключённых игроков не считаем репортом
_G.specConnected = function(id) return tonumber(id) ~= 999 end
check(_G.grndRepLaxParse("Ghost[999]: дм") == nil, "строка от отключённого ID попала в разбор")
check(_G.grndRepLaxParse("Alive[25]: дм") ~= nil, "живой игрок отсечён вместе с отключённым")
_G.specConnected = nil
-- такой репорт доходит до автопилота целиком
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Ответ"
Q.autoTabs()[1].command = "none"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
local rN, rP, rM = _G.grndRepLaxParse("Mixa_Grozz[88]: помогите")
check(Q.autoOnReport(rN, rP, rM) == true, "репорт без маркера не сработал")
check(QUEUE[1] == "/ans 88 Ответ", "не тот ответ: " .. tostring(QUEUE[1]))
-- и репорт с маркером «Кол-во» — тоже
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Artyr", 89, "помогите") == true, "репорт не принят")
check(QUEUE[1] == "/ans 89 Ответ", "не тот ответ: " .. tostring(QUEUE[1]))
-- вкладка 1 возвращается к обычному виду
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoEnsure()
HPRINT("распознавание репорта: маркер в любом написании, строка без маркера доходит до автопилота")

-- ===== 9i. ручной ответ из окна репорта под проверкой тоже уходит в /n (v1.19.41) =====
Q.autoTest = true
QUEUE = {}
check(grndRepAnswer(66, "Держитесь") == true, "ручной ответ не ушёл")
check(QUEUE[1] == "/n /ans 66 Держитесь",
    "ручной ответ не ушёл в /n: " .. tostring(QUEUE[1]))
-- репорт от бота: ответ команда /pm — и она тоже под проверкой
GRND_REP.replyCmd, GRND_REP.replyPid = "/pm 25", "25"
QUEUE = {}
check(grndRepAnswer(25, "текст") == true, "ответ по команде бота не ушёл")
check(QUEUE[1] == "/n /pm 25 текст",
    "ответ боту не ушёл в /n: " .. tostring(QUEUE[1]))
GRND_REP.replyCmd, GRND_REP.replyPid = nil, nil
-- боевой режим не испорчен
Q.autoTest = false
QUEUE = {}
check(grndRepAnswer(66, "Держитесь") == true, "боевой ручной ответ не ушёл")
check(QUEUE[1] == "/ans 66 Держитесь",
    "боевой ручной ответ испорчен: " .. tostring(QUEUE[1]))
HPRINT("ручной ответ из окна репорта: под проверкой «/n /ans ID текст»")

-- ===== 9j. переменная действует ровно на одно слово (v1.19.43) =====
-- «дм{ID}, dm»: широко ищется только «дм» (переменная на нём), а «dm» — как
-- обычное слово, точным совпадением. Переменная в ОТВЕТЕ поиск не расширяет.
Q.autoTabs()[1].trigger = "дм{ID}, dm"
Q.autoTabs()[1].answer = "Приветствую, слежу за игроком {ник}[{ID}]"
Q.autoTabs()[1].command = "none"
Q.autoEnsure()
local tl9 = Q.autoTrigList(Q.autoTabs()[1])
check(#tl9 == 2 and tl9[1].word == "дм" and tl9[1].wide == true,
    "«дм{ID}» не помечено широким: " .. tostring(tl9[1] and tl9[1].word) .. "/" .. tostring(tl9[1] and tl9[1].wide))
check(tl9[2].word == "dm" and tl9[2].wide == false,
    "«dm» без переменной должно искаться точным совпадением")
check(#Q.autoMatchAll("дм 234") == 1, "«дм 234» не подошло к «дм{ID}»")
check(#Q.autoMatchAll("абракадабра дм тут") == 1, "«дм» не ищется как слово в любом месте")
check(#Q.autoMatchAll("dm") == 1, "точное «dm» не подошло")
check(#Q.autoMatchAll("напиши dm в чат") == 0,
    "«dm» без переменной сработало не по полному совпадению")
-- переменная в ответе режим вкладки не включает: слово ищется как обычно
Q.autoTabs()[1].trigger = "дм"
Q.autoTabs()[1].answer = "Приветствую, {ID}"
Q.autoEnsure()
local function tab1In(list)
    for i = 1, #list do
        if list[i].idx == 1 then return true end
    end
    return false
end
check(not tab1In(Q.autoMatchAll("дм 234")), "переменная в ответе расширила поиск")
check(tab1In(Q.autoMatchAll("дм")), "обычное «дм» перестало срабатывать")
-- голая переменная: «{punishments}» работает, «{ID}»/«{all}» — нет
Q.autoTabs()[1].trigger = "{ID}"
Q.autoEnsure()
check(#Q.autoMatchAll("совсем другой текст") == 0, "голая {ID} отвечает на любой репорт")
Q.autoTabs()[1].trigger = "{all}"
Q.autoEnsure()
check(#Q.autoMatchAll("совсем другой текст") == 0, "голая {all} отвечает на любой репорт")
Q.autoTabs()[1].trigger = "{punishments}"
Q.autoEnsure()
check(#Q.autoMatchAll("совсем другой текст") == 1, "голая {punishments} не сработала")
check(Q.autoBarePun(Q.autoTabs()[1]) == true, "голая {punishments} не распознана")
-- возвращаем первую вкладку к обычному виду
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoEnsure()
HPRINT("переменная действует на одно слово: широко ищется только оно, остальные — точным совпадением")

-- ===== 9k. {ID} на слове в триггере — ответ собирается сам (v1.19.44) =====
-- Что бы ни лежало в поле «Ответ игроку», вкладка с «дм{ID}» отвечает
-- «Приветствую, слежу за игроком Ник[ID]» (ID из репорта, иначе штатный)
-- и уходит в /sp с этим ID. v1.19.46: поле ответа у такой вкладки ВИДНО —
-- оно уходит, когда в репорте нет ни номера, ни имени.
Q.autoTabs()[1].trigger = "дм{ID}"
Q.autoTabs()[1].answer = "ЭТОТ ТЕКСТ НЕ ДОЛЖЕН УЙТИ"
Q.autoTabs()[1].command = "sp"
Q.autoEnsure()
check(Q.autoIDInTrigger(Q.autoTabs()[1]) == true, "{ID} в триггере не распознан")
check(Q.autoTrigList(Q.autoTabs()[1])[1].wide == true, "слово с {ID} не помечено широким")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Mixa_Grozz", 25, "дм 234") == true, "«дм 234» не сработал")
check(QUEUE[1] == "/ans 25 Приветствую, слежу за игроком Mixa_Grozz[234]",
    "ответ не собрался сам: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/sp 234", "не ушёл в слежку за найденным ID: " .. tostring(QUEUE[2]))
-- v1.19.46: без числа и имени — уходит СВОЙ текст из «Ответ игроку», без
-- ника и ID (поле тут намеренно «чужое», чтобы видно было: ушёл именно он)
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Без_ид", 26, "дм") == true, "«дм» без числа не сработал")
check(QUEUE[1] == "/ans 26 ЭТОТ ТЕКСТ НЕ ДОЛЖЕН УЙТИ"
    and QUEUE[2] == "/sp 26",
    "без номера должен уйти свой текст: " .. tostring(QUEUE[1]) .. " | " .. tostring(QUEUE[2]))
-- поле ответа остаётся на месте, но с пояснением: для репорта с номером или
-- именем ответ собирается сам, а без них уходит этот текст (v1.19.46)
A.sel = 1
TYPE["##grnd_qr_auto_trigger"] = "дм{ID}"
drawAuto()
local idAnsField = false
for i = 1, #MULTI do
    if MULTI[i].id == "##grnd_qr_auto_answer" then idAnsField = true end
end
check(idAnsField == true, "поле «Ответ игроку» пропало у вкладки с {ID}: " .. texts())
check(hasOne("ответ собирается сам"), "нет пояснения про автоответ при {ID}: " .. textsOne())
-- обычная вкладка (переменной на слове нет) — поле ответа на месте.
-- Триггер пишем и в буфер поля (TYPE), иначе буфер вернёт своё значение
TYPE["##grnd_qr_auto_trigger"] = "Помогите"
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoEnsure()
drawAuto()
local backField = false
for i = 1, #MULTI do
    if MULTI[i].id == "##grnd_qr_auto_answer" then backField = true end
end
check(backField == true, "поле «Ответ игроку» не вернулось на обычной вкладке")
HPRINT("{ID} на слове в триггере: ответ собирается сам, поле ответа остаётся с пояснением")

-- ===== 9l. {ник}/{ID} — тот, на кого пожаловались (v1.19.45) =====
-- В строке репорта «Автор[ID]: текст» автор — тот, кому отвечает /ans, а в
-- тексте назван нарушитель. Ник в ответе должен быть нарушителя: раньше было
-- «слежу за игроком <автор>[<ID нарушителя>]» — ник одного, ID другого.
Q.autoTest = false
NICK_BY_ID = { [234] = "Nik_Name", [26] = "Mixa_Grozz" }
Q.autoTabs()[1].trigger = "дм{ID}"
Q.autoTabs()[1].answer = "не используется"
Q.autoTabs()[1].command = "sp"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "дм 234") == true, "«дм 234» не сработал")
check(QUEUE[1] == "/ans 70 Приветствую, слежу за игроком Nik_Name[234]",
    "ник взят не у нарушителя: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/sp 234", "не ушёл в слежку за нарушителем: " .. tostring(QUEUE[2]))
-- ник написан в репорте, числа нет: ID берём у этого игрока
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "Mixa_Grozz дм") == true, "репорт с ником не сработал")
check(QUEUE[1] == "/ans 70 Приветствую, слежу за игроком Mixa_Grozz[26]",
    "ник из текста не найден: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/sp 26", "ID из ника не подставлен: " .. tostring(QUEUE[2]))
-- переменная {ник} в своём шаблоне тоже цель жалобы, а {автор} — автор строки.
-- Триггер «дм{all}» — со словом, поэтому ответ берётся из поля ответа (у «дм{ID}»
-- он собирается сам и поле не используется).
Q.autoTabs()[1].trigger = "дм{all}"
Q.autoTabs()[1].answer = "Жалоба от {автор} на {ник}[{ID}]"
Q.autoTabs()[1].command = "none"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "дм 234") == true, "«дм{all}» не сработал")
check(QUEUE[1] == "/ans 70 Жалоба от Жалобщик на Nik_Name[234]",
    "{автор}/{ник} подставились не так: " .. tostring(QUEUE[1]))
-- номер в репорте есть, но игрока с ним на сервере нет: ник неизвестен —
-- в ответе остаётся только ID, чужой ник не подставляем (v1.19.46)
NICK_BY_ID = {}
Q.autoTabs()[1].trigger = "дм{ID}"
Q.autoTabs()[1].answer = "Уже разбираюсь"
Q.autoTabs()[1].command = "sp"
Q.autoEnsure()
for _, num in ipairs({ "500", "999" }) do
    NOW = NOW + 100
    A.rate = {}
    QUEUE = {}
    check(Q.autoOnReport("Жалобщик", 70, "дм " .. num) == true, "«дм " .. num .. "» не сработал")
    check(QUEUE[1] == "/ans 70 Приветствую, слежу за игроком [" .. num .. "]"
        and QUEUE[2] == "/sp " .. num,
        "без ника должен подставиться только ID: " .. tostring(QUEUE[1]) .. " | " .. tostring(QUEUE[2]))
end
-- возвращаем первую вкладку к обычному виду
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoEnsure()
HPRINT("{ник}/{ID}: ник — у того, на кого пожаловались (по ID из репорта или по нику в тексте), {автор} — у автора строки")

-- ===== 9m. нет ни номера, ни имени — уходит мой текст (v1.19.46) =====
Q.autoTest = false
NICK_BY_ID = { [234] = "Nik_Name" }
Q.autoTabs()[1].trigger = "дм{ID}"
Q.autoTabs()[1].answer = "Уже разбираюсь, ожидайте"
Q.autoTabs()[1].command = "none"
Q.autoTabs()[2].trigger = "спек"      -- чтобы «дм» во второй вкладке не мешал
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "дм") == true, "репорт без номера не сработал")
check(QUEUE[1] == "/ans 70 Уже разбираюсь, ожидайте",
    "у безномерного репорта ушёл не свой текст: " .. tostring(QUEUE[1]))
check(QUEUE[2] == nil, "ушла лишняя строка: " .. tostring(QUEUE[2]))
-- переменные {ник}/{ID} в своём тексте не подставляются и вычищаются
Q.autoTabs()[1].answer = "{ник} {ID} — уже разбираюсь"
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "дм") == true, "репорт не сработал")
check(QUEUE[1] == "/ans 70 — уже разбираюсь",
    "{ник}/{ID} не вычищены: " .. tostring(QUEUE[1]))
-- а с номером — по-прежнему автоответ с ником нарушителя
Q.autoTabs()[1].answer = "Уже разбираюсь, ожидайте"
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "дм 234") == true, "репорт с номером не сработал")
check(QUEUE[1] == "/ans 70 Приветствую, слежу за игроком Nik_Name[234]",
    "автоответ сломался: " .. tostring(QUEUE[1]))
-- имя в тексте тоже считается: ник нарушителя, а не автора
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "Nik_Name дм") == true, "репорт с ником не сработал")
check(QUEUE[1] == "/ans 70 Приветствую, слежу за игроком Nik_Name[26]"
    or QUEUE[1] == "/ans 70 Приветствую, слежу за игроком Nik_Name[234]",
    "и́мя из текста не сработало: " .. tostring(QUEUE[1]))
-- возвращаем вкладки к обычному виду
NICK_BY_ID = {}
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoTabs()[2].trigger = "дм"
Q.autoEnsure()
HPRINT("без номера и имени в репорте: уходит свой текст без ника и ID")

-- ===== 9n. несколько слов-триггеров — отвечает первое (v1.19.46) =====
Q.autoTabs()[1].trigger = "спек{ID}"
Q.autoTabs()[1].answer = "спек-ответ"
Q.autoTabs()[1].command = "none"
Q.autoTabs()[2].trigger = "дм{ID}"
Q.autoTabs()[2].answer = "дм-ответ"
Q.autoTabs()[2].command = "none"
Q.autoEnsure()
NICK_BY_ID = { [234] = "Nik_Name" }
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "дм спек 234") == true, "«дм спек 234» не сработал")
-- отвечает только «дм» (вкладка 2): автоответ + /sp по найденному ID
check(A.lastCheck:find("вкладки 2", 1, true) ~= nil,
    "ответило не первое слово: " .. tostring(A.lastCheck))
check(A.lastCheck:find("позже «спек»", 1, true) ~= nil,
    "нет пометки о пропущенном слове: " .. tostring(A.lastCheck))
check(#QUEUE == 2 and QUEUE[1] == "/ans 70 Приветствую, слежу за игроком Nik_Name[234]"
    and QUEUE[2] == "/sp 234",
    "не то отправлено: " .. tostring(QUEUE[1]) .. " | " .. tostring(QUEUE[2]))
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "спек дм 234") == true, "«спек дм 234» не сработал")
check(A.lastCheck:find("вкладки 1", 1, true) ~= nil and #QUEUE == 2,
    "в обратном порядке ответило не первое слово: " .. tostring(A.lastCheck) .. " / " .. tostring(#QUEUE))
-- одно и то же слово в двух вкладках — срабатывают обе (как и раньше)
Q.autoTabs()[2].trigger = "спек{ID}"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("Жалобщик", 70, "спек 234") == true, "«спек 234» не сработал")
check(#QUEUE == 4 and A.lastCheck:find("вкладки 1, 2", 1, true) ~= nil,
    "одно слово в двух вкладках должно срабатывать обеими: " .. tostring(A.lastCheck) .. " / " .. tostring(#QUEUE))
NICK_BY_ID = {}
-- возвращаем вкладки к обычному виду
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoTabs()[2].trigger = "дм"
Q.autoTabs()[2].answer = "Не пишите в личку, отвечу в репорте"
Q.autoTabs()[2].command = "sp"
Q.autoEnsure()
HPRINT("несколько слов-триггеров: отвечает то, что раньше в репорте; одно слово в двух вкладках — обе")

-- ===== 12c. слежка определяется ПО ФАКТУ (v1.19.40) =====
-- вкладка с командой: именно её слежка и должна останавливать
Q.autoTabs()[1].trigger = "факт"
Q.autoTabs()[1].answer = "Приветствую"
Q.autoTabs()[1].command = "sp"
Q.autoEnsure()
A.on = true
-- отметки слежки протухли (active = true), но игра говорит: слежки нет
GRND_SPEC.active, GRND_SPEC.id = true, 77
SERV.spec = false
grndSpecProbeState = function() return false end
NOW = NOW + 100
A.rate = {}
QUEUE, ANS = {}, {}
local okStale, whyStale = Q.autoOnReport("Свежий", 60, "факт")
check(okStale == true, "старая отметка слежки держит автопилот на паузе: " .. tostring(whyStale))
check(#QUEUE == 2 and QUEUE[1] == "/ans 60 Приветствую" and QUEUE[2] == "/sp 60",
    "ответ не ушёл: " .. tostring(QUEUE[1]) .. " | " .. tostring(QUEUE[2]))
-- игра подтверждает слежку — пауза, даже если свои отметки пусты
GRND_SPEC.active, GRND_SPEC.id = false, nil
SERV.spec = false
grndSpecProbeState = function() return true end
NOW = NOW + 100
A.rate = {}
QUEUE = {}
local okFact, whyFact = Q.autoOnReport("Наблюдаемый", 61, "факт")
check(okFact == false and whyFact == "слежка",
    "факт слежки не поставил на паузу: " .. tostring(whyFact))
check(#QUEUE == 0, "в слежке что-то ушло: " .. tostring(QUEUE[1]))
grndSpecProbeState = nil
GRND_SPEC.active, GRND_SPEC.id = false, nil
HPRINT("факт слежки: игра решает, а не старые отметки")

-- возвращаем первую вкладку к прежнему виду
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoEnsure()

-- ===== 10. репорт без триггера / без ID =====
NOW = NOW + 100
A.rate = {}
QUEUE = {}
local okNo, whyNo = Q.autoOnReport("Mixa_Grozz", 26, "как дела?")
check(okNo == false and whyNo == "нет триггера", "репорт без триггера обработан: " .. tostring(whyNo))
check(A.lastCheck:find("не найден", 1, true) ~= nil, "нет пояснения: " .. tostring(A.lastCheck))
local okId, whyId = Q.autoOnReport("Без_ид", "—", "помогите")
check(okId == false and whyId == "нет ID", "репорт без ID обработан: " .. tostring(whyId))
check(#QUEUE == 0, "что-то ушло в чат на репорт без ID")

-- пустая вкладка молчит
Q.autoTabs()[1].trigger = ""
local okEmpty, whyEmpty = Q.autoOnReport("Mixa_Grozz", 26, "помогите")
check(okEmpty == false and whyEmpty == "нет триггера", "пустая вкладка сработала: " .. tostring(whyEmpty))
Q.autoTabs()[1].trigger = "Помогите"
HPRINT("пропуски: нет триггера, нет ID, пустая вкладка — в чат ничего не уходит")

-- ===== 11. темп, предохранитель и повторный репорт того же игрока =====
-- v1.19.42: «этому игроку уже отвечали» больше нет. Ответ игроку — не повод
-- пропускать его следующий репорт: написал ещё раз — отвечаем ещё раз. Темп
-- держат только пауза 2.5 с между срабатываниями и лимит 12 ответов в минуту.
NOW = NOW + 10
A.rate = {}
Q.autoOnReport("Mixa_Grozz", 25, "Помогите")
QUEUE = {}
local okGap, whyGap = Q.autoOnReport("Mixa_Grozz", 25, " Помогите ")
check(okGap == false and whyGap == "слишком часто",
    "нет паузы между срабатываниями: " .. tostring(whyGap))
check(#QUEUE == 0, "пропущенный репорт всё равно ушёл")
NOW = NOW + 3
QUEUE = {}
local okAgain, whyAgain = Q.autoOnReport("Mixa_Grozz", 25, " Помогите ")
check(okAgain == true, "повторный репорт того же игрока пропущен: " .. tostring(whyAgain))
check(QUEUE[1] == "/ans 25 Приветствую! Уже смотрю.",
    "повторный ответ не ушёл: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/goto 25", "команда повторного ответа не ушла: " .. tostring(QUEUE[2]))
NOW = NOW + 3
check(Q.autoOnReport("Другой", 77, "помогите") == true, "после паузы не сработало")
HPRINT("повторный репорт того же игрока: ответили — значит не пропускать; темп держат пауза и лимит")

A.rate = {}
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

-- ===== 12. слежка: автопилот на паузе, настройка не выключается =====
NOW = NOW + 100
A.rate = {}
check(A.on == true, "перед проверкой слежки автопилот должен быть включён")
setSpec(true)
QUEUE = {}
local okSpec, whySpec = Q.autoOnReport("Наблюдаемый", 200, "помогите")
check(okSpec == false and whySpec == "слежка", "в слежке автопилот сработал: " .. tostring(whySpec))
check(A.on == true, "в слежке автопилот выключился — должен быть только на паузе")
check(A.paused == "слежка", "нет пометки паузы: " .. tostring(A.paused))
check(#QUEUE == 0, "в слежке ответ всё равно ушёл")
check(TOASTS[#TOASTS] == "Автопилот на паузе: слежка", "нет тоста про паузу")
drawAuto()
check(has("на паузе — слежка, вернётся сам"), "на вкладке нет состояния паузы: " .. texts())
check(has("включён") == false or has("на паузе"), "состояние показано неверно")
-- v1.19.35: вкладка «без команды» отвечает даже в слежке —
-- /ans наблюдению не мешает, а телепорт сломал бы слежку
local savedCmd1 = Q.autoTabs()[1].command
Q.autoTabs()[1].command = "none"
NOW = NOW + 100
A.rate = {}
QUEUE, ANSICALLS = {}, {}
local okNoCmd, whyNoCmd = Q.autoOnReport("Без команды", 205, "помогите")
check(okNoCmd == true, "вкладка без команды в слежке не сработала: " .. tostring(whyNoCmd))
check(#QUEUE == 1, "в слежке ушло не одно сообщение: " .. tostring(#QUEUE))
check(QUEUE[1] == "/ans 205 Приветствую! Уже смотрю.",
    "в слежке игроку ушло не то: " .. tostring(QUEUE[1]))
-- v1.19.36: вкладка «без команды», но с {ID} в ответе, сама уходит в слежку
-- (/sp по найденному ID) — значит в слежке она теперь тоже молчит
local savedAns1, savedTrig1 = Q.autoTabs()[1].answer, Q.autoTabs()[1].trigger
Q.autoTabs()[1].command = "none"
Q.autoTabs()[1].trigger = "чит"
Q.autoTabs()[1].answer = "Приветствую, слежу за игроком {ник}[{ID}]"
Q.autoEnsure()
NOW = NOW + 100
A.rate = {}
QUEUE = {}
local okIdSpec, whyIdSpec = Q.autoOnReport("С {ID}", 207, "чит 234")
check(okIdSpec == false and whyIdSpec == "слежка",
    "вкладка с {ID} в слежке всё же сработала: " .. tostring(whyIdSpec))
check(#QUEUE == 0, "в слежке ушла автослежка по {ID}")
Q.autoTabs()[1].trigger, Q.autoTabs()[1].answer = savedTrig1, savedAns1
-- а вкладка с командой в слежке по-прежнему молчит
Q.autoTabs()[1].command = savedCmd1
NOW = NOW + 100
A.rate = {}
QUEUE = {}
local okCmdSpec, whyCmdSpec = Q.autoOnReport("С командой", 206, "помогите")
check(okCmdSpec == false and whyCmdSpec == "слежка",
    "вкладка с командой в слежке всё же сработала: " .. tostring(whyCmdSpec))
check(#QUEUE == 0, "в слежке ушла команда")
-- и в подсказке внизу раздела об этом сказано оранжевым
drawAuto()
check(hasOne("Если триггер будет без команды, автопилот будет работать даже в слежке"),
    "нет оранжевой подсказки про «без команды»: " .. texts())
-- тумблер по-прежнему включён: повторное нажатие его выключает, и это видно
CLICK = { ["##grnd_qr_auto_on"] = true }
drawAuto()
CLICK = {}
check(A.on == false and A.paused == nil, "тумблер в паузе повёл себя странно")
check(Q.autoSet(true) == true, "автопилот не включился обратно (пауза не мешает тумблеру)")
check(A.paused == "слежка", "после включения в слежке пауза не отмечена")
-- выходим из слежки: автопилот сам продолжает работать
setSpec(false)
NOW = NOW + 5
Q.autoTick()
check(A.paused == nil, "после выхода из слежки пауза не снялась: " .. tostring(A.paused))
check(A.on == true, "автопилот не вернулся к работе")
check(TOASTS[#TOASTS] == "Автопилот снова работает", "нет тоста о возврате: " .. tostring(TOASTS[#TOASTS]))
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("После слежки", 201, "помогите") == true, "после слежки автопилот не отвечает")
HPRINT("слежка: пауза вместо выключения, после выхода работает сам")

-- ===== 12b. мероприятие (панель МП) — тоже пауза =====
NOW = NOW + 100
A.rate = {}
GRND_MP = { active = true }
QUEUE = {}
local okEv, whyEv = Q.autoOnReport("На мероприятии", 202, "помогите")
check(okEv == false and whyEv == "мероприятие",
    "на мероприятии автопилот сработал: " .. tostring(whyEv))
check(A.on == true and A.paused == "мероприятие",
    "мероприятие должно ставить на паузу, а не выключать")
check(#QUEUE == 0, "на мероприятии ответ всё равно ушёл")
drawAuto()
check(has("на паузе — идёт мероприятие, вернётся сам"), "на вкладке нет паузы мероприятия")
-- на мероприятии пауза полная: даже вкладка «без команды» молчит
local savedCmd2 = Q.autoTabs()[1].command
Q.autoTabs()[1].command = "none"
NOW = NOW + 100
A.rate = {}
QUEUE = {}
local okEvNo, whyEvNo = Q.autoOnReport("МП без команды", 207, "помогите")
check(okEvNo == false and whyEvNo == "мероприятие",
    "на мероприятии вкладка без команды всё же сработала: " .. tostring(whyEvNo))
check(#QUEUE == 0, "на мероприятии ответ всё равно ушёл")
Q.autoTabs()[1].command = savedCmd2
GRND_MP.active = false
NOW = NOW + 5
Q.autoTick()
check(A.paused == nil and A.on == true, "после мероприятия автопилот не вернулся сам")
NOW = NOW + 100
A.rate = {}
QUEUE = {}
check(Q.autoOnReport("После МП", 203, "помогите") == true, "после мероприятия автопилот не отвечает")
GRND_MP = nil
HPRINT("мероприятие: пауза вместо выключения, после окончания работает сам")

-- ===== 13. идёт ввод текста — пропуск =====
NOW = NOW + 100
check(Q.autoSet(true) == true, "не включился")
A.rate = {}
SERV.typing = true
QUEUE = {}
local okTyp, whyTyp = Q.autoOnReport("Печатающий", 300, "помогите")
check(okTyp == false and whyTyp == "ввод", "при вводе текста автопилот сработал: " .. tostring(whyTyp))
check(#QUEUE == 0, "при вводе текста ответ всё равно ушёл")
SERV.typing = false
HPRINT("идёт ввод текста: репорт пропущен, в чат ничего не уходит")

-- ===== 14. режим «без команды» во второй вкладке =====
NOW = NOW + 100
A.rate = {}
Q.autoTabs()[2].command = "none"
CHAT, QUEUE = {}, {}
check(Q.autoCmdFor(500, Q.autoTabs()[2]) == nil, "команда «без команды» всё равно собирается")
check(Q.autoOnReport("Тихий", 500, "дм") == true, "вторая вкладка не сработала")
check(#QUEUE == 1, "в очереди лишние строки: " .. tostring(#QUEUE))
grndRepQueueTick()
check(#CHAT == 0, "при «без команды» в чат всё равно ушла команда")
Q.autoTabs()[2].command = "sp"
HPRINT("«без команды»: уходит только ответ игроку")

-- ===== 15. конфиг: вкладки записаны и прочитаны =====
check(Q.autoSave() == true, "сохранение не прошло (домен конфига не объявлен?)")
local body = FILES[Q.autoPath()] or ""
check(body:find("count=", 1, true) == nil, "в файле лишний счётчик вкладок: " .. body)
check(body:find("sel=", 1, true) ~= nil, "в файле нет выбранной вкладки: " .. body)
check(body:find("t1_trigger=Помогите", 1, true) ~= nil, "в файле нет триггера 1-й вкладки")
check(body:find("t2_trigger=дм", 1, true) ~= nil, "в файле нет триггера 2-й вкладки")
check(body:find("t1_command=goto", 1, true) ~= nil, "в файле нет команды 1-й вкладки")
check(body:find("t2_command=sp", 1, true) ~= nil, "в файле нет команды 2-й вкладки")
check(body:find("on=1", 1, true) ~= nil, "в файле нет on=1")
A.on, A.sel, A.loaded = false, 1, false
A.tabs = nil
check(Q.autoLoad() == true, "конфиг не прочитался")
check(#Q.autoTabs() == 2, "вкладки не восстановились: " .. tostring(#Q.autoTabs()))
check(Q.autoTabs()[1].trigger == "Помогите" and Q.autoTabs()[1].command == "goto",
    "первая вкладка восстановилась неверно")
check(Q.autoTabs()[2].trigger == "дм" and Q.autoTabs()[2].answer == "Не пишите в личку, отвечу в репорте",
    "вторая вкладка восстановилась неверно")
check(A.on == true, "on не восстановился")
HPRINT("конфиг: две вкладки со своими триггерами/ответами/командами пережили перезапуск")

-- ===== 16. файл старого формата читается как первая вкладка =====
FILES[Q.autoPath()] = "on=1\ntrigger=старый\nanswer=старый ответ\ncommand=sp\n"
A.loaded, A.tabs, A.sel, A.on = false, nil, 1, false
check(Q.autoLoad() == true, "старый конфиг не прочитался")
check(#Q.autoTabs() == 1 and Q.autoTabs()[1].trigger == "старый"
    and Q.autoTabs()[1].answer == "старый ответ", "старый формат потерялся")
HPRINT("совместимость: файл прошлой версии читается как первая вкладка")

-- ===== 17. задержанное сохранение тиком =====
Q.autoTabs()[1].trigger = "помоги"
A.dirtyAt = NOW
NOW = NOW + 1
Q.autoTick()
check((FILES[Q.autoPath()] or ""):find("t1_trigger=помоги", 1, true) ~= nil,
    "тик не сохранил правки из полей")
HPRINT("тик: правки из полей сохраняются с задержкой")

-- ===== 18. удаление вкладки: крестик у самой вкладки =====
Q.autoEnsure()
Q.autoAdd()                     -- вторая вкладка: есть что удалять
Q.autoTabs()[2].trigger = "дм"
A.sel = 1
CLICK = { ["##grnd_qr_auto_tabc_2"] = true }
drawAuto()
CLICK = {}
check(#Q.autoTabs() == 1, "крестик не удалил вкладку: " .. tostring(#Q.autoTabs()))
check(Q.autoLabel(1) == "помоги", "после удаления осталась не та вкладка: " .. Q.autoLabel(1))
check(A.sel == 1, "удаление крестиком переключило выбранную вкладку")
check(pcall(_G.grndQrAutoDraw, CTX), "после удаления раздел не рисуется")
-- клик по самой вкладке не удаляет её
Q.autoAdd()
A.sel = 1
CLICK = { ["##grnd_qr_auto_tab_2"] = true }
drawAuto()
CLICK = {}
check(#Q.autoTabs() == 2 and A.sel == 2, "клик по вкладке не выбрал её")
-- последняя вкладка не исчезает, а очищается: пустая вкладка честно молчит
CLICK = { ["##grnd_qr_auto_tabc_2"] = true }
drawAuto()
CLICK = {}
check(#Q.autoTabs() == 1, "вкладка не удалилась крестиком")
CLICK = { ["##grnd_qr_auto_tabc_1"] = true }
drawAuto()
CLICK = {}
check(#Q.autoTabs() == 1 and Q.autoTabs()[1].trigger == "" and Q.autoTabs()[1].answer == "",
    "последняя вкладка должна очищаться, а не исчезать")
HPRINT("удаление: крестик на вкладке удаляет её, последняя вкладка очищается")

-- ===== 19. предел вкладок =====
for i = 2, 15 do Q.autoAdd() end
check(#Q.autoTabs() == 15, "не набралось 15 вкладок: " .. tostring(#Q.autoTabs()))
check(Q.autoAdd() == nil, "появилась 16-я вкладка")
check(#Q.autoTabs() == 15, "вкладок стало больше предела")
check(TOASTS[#TOASTS]:find("Больше 15 вкладок", 1, true) ~= nil,
    "нет тоста про предел: " .. tostring(TOASTS[#TOASTS]))
HPRINT("предел: 15 вкладок, дальше отказ с тостом")

-- ===== 20. очередь репорта недоступна — команда уходит напрямую =====
NOW = NOW + 100
while #Q.autoTabs() > 2 do Q.autoDel(#Q.autoTabs()) end
Q.autoEnsure()
A.on, A.rate = true, {}
Q.autoTabs()[1].trigger = "помогите"
Q.autoTabs()[1].answer = "уже смотрю"
Q.autoTabs()[1].command = "goto"
CHAT, ANS, QUEUE, ORDER, ANSICALLS = {}, {}, {}, {}, {}
SERV.failQueue = true
check(Q.autoOnReport("Фолбэк", 400, "помогите") == true, "при недоступной очереди не сработало")
check(#CHAT == 1 and CHAT[1] == "/goto 400", "команда не ушла напрямую: " .. tostring(CHAT[1]))
SERV.failQueue = false
HPRINT("очередь недоступна: команда уходит напрямую в чат")

-- ===== 21. QR.queueCmd: русский текст конвертируется =====
ANSICALLS = {}
check(Q.queueCmd("/mute 25 60 флуд в чате") == true, "queueCmd не отправил команду")
check(#ANSICALLS == 1 and ANSICALLS[1] == "/mute 25 60 флуд в чате",
    "русский текст не прошёл конвертацию: " .. tostring(ANSICALLS[1]))
check(Q.queueCmd("") == false, "пустая команда ушла")
HPRINT("queueCmd: русская причина наказания уходит через CP1251")

-- ===== 22. ошибки наружу не выходят =====
NOW = NOW + 100
A.rate = {}
Q.autoTabs()[1].trigger = "помогите"
local savedAns = grndRepAnswer
grndRepAnswer = function() error("тест: сбой ответа") end
check(Q.autoOnReport("Сбой", 600, "помогите") == true, "сбой ответа сломал срабатывание")
grndRepAnswer = savedAns
local savedFn = Q.autoOnReport
Q.autoOnReport = function() error("тест: падение разбора") end
check(_G.grndQrAutoOnReport("Ник", 700, "помогите") == false, "обёртка не вернула false при падении")
check(type(Q.auto.err) == "string", "ошибка не записана в Q.auto.err")
Q.autoOnReport = savedFn
HPRINT("сбой внутри: команда всё равно уходит, обёртка не роняет скрипт")

-- ===== 23. ESC закрывает список команд =====
A.listOpen = true
check(_G.grndQrOnEsc() == true, "ESC не обработал список команд")
check(A.listOpen == false, "ESC не закрыл список команд")
check(_G.grndQrOnEsc() == false, "ESC на закрытом списке вернул true")
HPRINT("ESC: список команд автопилота закрывается")

-- ===== 24. маленькая область и мусор на входе =====
local small = makeCtx()
small.w, small.h = 200, 120
check(_G.grndQrAutoDraw(small) == false, "раздел нарисовался в слишком маленькой области")
check(_G.grndQrAutoDraw(nil) == false, "отрисовка упала на пустом контексте")
HPRINT("маленькая область: раздел честно не рисуется, ошибок нет")

HPRINT("ALL AUTO SCENARIOS PASSED")
