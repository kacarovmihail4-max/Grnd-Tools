
-- ---- стенд: автопилот ответов на репорт (v1.19.22, вкладки) ----
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
-- v1.19.32: строки подсказки внизу раздела (в них фраза «репорт целиком» —
-- это законно; у поля «Триггер» такой подписи быть не должно)
local HINT_LINES = {
    'Репорт, который начинается с триггера "помогите", сработает целиком:',
    "«помогите, дм!!!» — обработается, даже если дальше есть текст",
    "Только для «помогите»: остальным триггерам — репорт целиком",
}
local function isHintLine(str)
    for i = 1, #HINT_LINES do
        if str == HINT_LINES[i] or str:sub(1, #HINT_LINES[i]) == HINT_LINES[i] then return true end
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
-- v1.19.32: внизу раздела — постоянная подсказка про «помогите» (правило
-- «по началу репорта» действует только для него)
check(has('Репорт, который начинается с триггера "помогите", сработает целиком:'),
    "нет подсказки про триггер «помогите»: " .. texts())
check(has("«помогите, дм!!!» — обработается, даже если дальше есть текст"),
    "нет примера «помогите, дм!!!» в подсказке")
check(has("Только для «помогите»: остальным триггерам — репорт целиком"),
    "нет строки о том, что правило действует только для «помогите»")
-- v1.19.33: под полем «Триггер» — подсказка про синонимы через запятую, фраза
-- переносится по словам и должна помещаться ЦЕЛИКОМ (без «…»)
check(has("Можно ввести триггер и похожие слова к триггеру, на которые скрипт тоже"),
    "нет подсказки про похожие слова у поля «Триггер»: " .. texts())
local hintTail = "так реагировать"
local hintFull = false
for i = 1, #TXT do
    local str = tostring(TXT[i].str)
    if str:sub(-#hintTail) == hintTail then hintFull = true end
end
check(hintFull, "подсказка про похожие слова обрезана: " .. texts())
check(not has("напр. помогите"), "вернулся прежний placeholder «напр. помогите»")
-- лишние подписи и кнопки убраны (v1.19.23)
local goneList = { "вкладок:", "срабатываний", "Добавить вкладку", "Удалить (",
                   "пусто — вкладка молчит", "подставятся сами", "Срабатывания",
                   "Проверка триггера", "репорты проходят мимо",
                   "слишком короткий" }
for _, gone in ipairs(goneList) do
    check(not has(gone), "вернулась лишняя надпись «" .. gone .. "»: " .. texts())
end
check(not has("Удалить"), "вернулась кнопка удаления вкладки")
-- фраза «репорт целиком» живёт только в подсказке внизу, у поля «Триггер» её нет
local foreignRep = foreignWith("репорт целиком")
check(foreignRep == nil, "фраза «репорт целиком» снова у поля «Триггер»: " .. tostring(foreignRep))
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
check(Q.autoMatchTab("ПОМОГИТЕ!!!") == 1, "знак пунктуации после слова сбивает совпадение")
check(Q.autoMatchTab("помогите плиз") == 1, "лишнее слово после триггера сбивает совпадение")
check(Q.autoMatchTab("помогите, дм") == 1, "второе слово после триггера сбивает совпадение")
check(Q.autoMatchTab("помогитеплиз") == nil, "склейка слов не должна считаться триггером")
check(Q.autoMatchTab("помогитеее") == nil, "удлинение слова не должно считаться триггером")
check(Q.autoMatchTab("плиз, помогите") == nil, "триггер не в начале репорта не должен срабатывать")
check(Q.autoMatchTab("Help me") == nil, "найдено лишнее совпадение")
TYPE["##grnd_qr_auto_answer"] = "Приветствую, {ник}! Уже смотрю. {ид}"
drawAuto()
check(t1.answer == "Приветствую, {ник}! Уже смотрю. {ид}",
    "ответ не записался: " .. tostring(t1.answer))
check(not texts():find("{ник}", 1, true), "в разделе осталась подсказка с {ник}")
-- подсказка внизу — постоянный текст про «помогите», от полей вкладки не зависит
local hint1 = HINT_LINES[1]
local hint2 = HINT_LINES[2]
local hint3 = HINT_LINES[3]
check(has(hint1), "подсказка изменилась при введённом триггере: " .. texts())
check(has(hint2), "вторая строка подсказки пропала: " .. texts())
check(has(hint3), "третья строка (правило только для «помогите») пропала")
HPRINT("вкладка 1: триггер «Помогите», ответ с {ник}/{ид}, подпись = триггер, подсказка про «помогите»")

-- короткий триггер разрешён: без предупреждений и работает
TYPE["##grnd_qr_auto_trigger"] = "я"
drawAuto()
check(t1.trigger == "я", "короткий триггер не записался: " .. tostring(t1.trigger))
for _, gone in ipairs({ "слишком короткий" }) do
    check(not has(gone), "у поля «Триггер» вернулась подпись «" .. gone .. "»")
end
foreignRep = foreignWith("репорт целиком")
check(foreignRep == nil, "у поля «Триггер» вернулась подпись «репорт целиком»: " .. tostring(foreignRep))
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE = {}
check(Q.autoOnReport("Короткий", 210, "я") == true, "короткий триггер не сработал")
check(#QUEUE == 2 and QUEUE[1] == "/ans 210 Приветствую, Короткий! Уже смотрю. 210"
    and QUEUE[2] == "/sp 210", "короткий триггер отправил не то: " .. tostring(QUEUE[1]))
-- подсказка не зависит от длины триггера и всегда помещается целиком
TYPE["##grnd_qr_auto_trigger"] = "помогите пожалуйста очень нужно прямо сейчас"
drawAuto()
check(has(hint1), "подсказка срезалась при длинном триггере: " .. texts())
check(has(hint2), "вторая строка подсказки срезалась при длинном триггере")
check(has(hint3), "третья строка подсказки срезалась при длинном триггере")
TYPE["##grnd_qr_auto_trigger"] = "Помогите"
drawAuto()
-- и после удаления поля триггера тоже на месте
drawAuto()
check(has(hint1) and has(hint2) and has(hint3), "подсказка пропала после сброса триггера")
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
A.perPid, A.rate = {}, {}
Q.autoSet(false)
QUEUE, ANS, CHAT, ORDER = {}, {}, {}, {}
local okOff, whyOff = Q.autoOnReport("Mixa_Grozz", 25, "Помогите")
check(okOff == false and whyOff == "выключен", "выключенный автопилот сработал: " .. tostring(whyOff))
check(#QUEUE == 0, "выключенный автопилот что-то отправил")
check(Q.autoSet(true) == true, "автопилот не включился")
HPRINT("выключен: репорты проходят мимо, в чат ничего не уходит")

-- ===== 9. репорт попадает в нужную вкладку =====
NOW = NOW + 10
A.perPid, A.rate = {}, {}
QUEUE, ANS, CHAT, ORDER, ANSICALLS = {}, {}, {}, {}, {}
local fired, hit = Q.autoOnReport("Mixa_Grozz", 25, "Помогите")
check(fired == true, "репорт с триггером не обработан")
check(hit == "помогите", "сработал не тот триггер: " .. tostring(hit))
check(#QUEUE == 2, "в очередь встало не две строки: " .. tostring(#QUEUE))
check(QUEUE[1] == "/ans 25 Приветствую, Mixa_Grozz! Уже смотрю. 25",
    "первым в очереди не ответ первой вкладки: " .. tostring(QUEUE[1]))
check(QUEUE[2] == "/goto 25", "второй в очереди не команда первой вкладки: " .. tostring(QUEUE[2]))
check(#ANSICALLS == 2 and ANSICALLS[1] == "Приветствую, Mixa_Grozz! Уже смотрю. 25"
    and ANSICALLS[2] == "/goto 25", "текст ушёл без перевода в CP1251")
grndRepQueueTick()
check(#ORDER == 2 and ORDER[1] == "ans" and ORDER[2] == "chat",
    "порядок неверный: " .. table.concat(ORDER, ","))
check(ANS[1] == "25 Приветствую, Mixa_Grozz! Уже смотрю. 25",
    "игроку ушёл не тот ответ: " .. tostring(ANS[1]))
check(A.lastCheck:find("вкладки 1", 1, true) ~= nil, "нет пометки вкладки: " .. tostring(A.lastCheck))

-- та же ситуация, но триггер второй вкладки
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE, ANS, CHAT, ORDER, ANSICALLS = {}, {}, {}, {}, {}
local fired2, hit2 = Q.autoOnReport("Другой", 77, "дм")
check(fired2 == true and hit2 == "дм", "вторая вкладка не сработала: " .. tostring(hit2))
check(#QUEUE == 2 and QUEUE[1] == "/ans 77 Не пишите в личку, отвечу в репорте"
    and QUEUE[2] == "/sp 77", "вторая вкладка отправила не то: " .. tostring(QUEUE[1]))
check(A.lastCheck:find("вкладки 2", 1, true) ~= nil, "нет пометки второй вкладки")
-- лишние слова после триггера не мешают: репорт начинается со слова «помогите»
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE, ANS, ANSICALLS = {}, {}, {}
check(Q.autoOnReport("Третий", 88, "помогите, дм") == true,
    "репорт «помогите, дм» не сработал")
check(#QUEUE == 2 and QUEUE[1] == "/ans 88 Приветствую, Третий! Уже смотрю. 88"
    and QUEUE[2] == "/goto 88", "первая вкладка отправила не то: " .. tostring(QUEUE[1]))
-- а приклеенное слово или триггер не в начале репорта — уже не совпадение
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE = {}
local okExtra, whyExtra = Q.autoOnReport("Пятый", 89, "дмитрий, помогите")
check(okExtra == false and whyExtra == "нет триггера",
    "репорт «дмитрий, помогите» всё равно сработал: " .. tostring(whyExtra))
check(#QUEUE == 0, "на репорт «дмитрий, помогите» что-то ушло")
-- одинаковый триггер в двух вкладках: срабатывают ОБЕ, по порядку вкладок
Q.autoTabs()[2].trigger = "Помогите"
Q.autoTabs()[2].command = "sp"
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE, ANSICALLS = {}, {}
check(Q.autoOnReport("Четвёртый", 99, "помогите") == true, "совпадение по двум вкладкам не сработало")
check(#QUEUE == 4, "с двух вкладок встало не 4 строки: " .. tostring(#QUEUE))
check(QUEUE[1] == "/ans 99 Приветствую, Четвёртый! Уже смотрю. 99"
    and QUEUE[2] == "/goto 99", "первая вкладка отправила не своё: " .. tostring(QUEUE[1]))
check(QUEUE[3] == "/ans 99 Не пишите в личку, отвечу в репорте"
    and QUEUE[4] == "/sp 99", "вторая вкладка отправила не своё: " .. tostring(QUEUE[3]))
check(A.lastCheck:find("вкладки 1, 2", 1, true) ~= nil,
    "в подсказке нет обеих вкладок: " .. tostring(A.lastCheck))
check(TOASTS[#TOASTS]:find("вкладок 2", 1, true) ~= nil,
    "тост не сообщает про две вкладки: " .. tostring(TOASTS[#TOASTS]))
Q.autoTabs()[2].trigger = "дм"
HPRINT("срабатывание: триггер = весь репорт; совпавшие вкладки срабатывают все, по порядку")

-- ===== 9b. «по началу репорта» — ТОЛЬКО для «помогите» (v1.19.32) =====
-- Вкладка 1 — «дм», вкладка 2 — «помогите». «Помогите» срабатывает, если репорт
-- с него начинается; «дм» и любые другие триггеры — только при полном
-- совпадении репорта.
Q.autoTabs()[1].trigger = "дм"
Q.autoTabs()[1].answer = "ответ первой вкладки"
Q.autoTabs()[1].command = "goto"
Q.autoTabs()[2].trigger = "помогите"
Q.autoTabs()[2].answer = "ответ второй вкладки"
Q.autoTabs()[2].command = "sp"
Q.autoEnsure()
local starts = {
    { "помогите дм", 2 }, { "помогите, дм", 2 }, { "помогите, дм!!!", 2 },
    { "ПОМОГИТЕ ПЛИЗ", 2 }, { "  Помогите   ДМ  ", 2 },
    { "{FF0000}помогите{FFFFFF} дм", 2 },
    { "дм", 1 },
}
for _, case in ipairs(starts) do
    local hits = Q.autoMatchAll(case[1])
    check(#hits == 1 and hits[1].idx == case[2],
        "репорт «" .. case[1] .. "» совпал не с той вкладкой: " .. tostring(#hits))
end
-- склейки, «помогите» не в начале и лишний текст у ДРУГИХ триггеров — нет
local noHit = { "помогитеплиз", "помогитеее", "плиз, помогите",
                "дм, помогите", "дм помогите!", "дмитрий, помогите" }
for _, rep in ipairs(noHit) do
    check(#Q.autoMatchAll(rep) == 0, "«" .. rep .. "» не должно совпадать ни с чем")
end
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE, ANSICALLS = {}, {}
check(Q.autoOnReport("Склейка", 150, "помогите, дм!") == true,
    "репорт «помогите, дм!» не сработал")
check(#QUEUE == 2 and QUEUE[1]:find("ответ второй вкладки", 1, true) ~= nil,
    "сработала не та вкладка: " .. tostring(QUEUE[1]))
-- а каждый триггер по отдельности работает на своём полном совпадении
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE = {}
check(Q.autoOnReport("Первый", 151, "дм") == true, "чистый «дм» не сработал")
check(#QUEUE == 2 and QUEUE[1]:find("ответ первой вкладки", 1, true) ~= nil,
    "сработала не та вкладка: " .. tostring(QUEUE[1]))
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE = {}
check(Q.autoOnReport("Второй", 152, "Помогите") == true, "чистое «Помогите» не сработало")
check(#QUEUE == 2 and QUEUE[1]:find("ответ второй вкладки", 1, true) ~= nil,
    "сработала не та вкладка: " .. tostring(QUEUE[1]))
-- возвращаем вкладки к состоянию до этой проверки (дальше идут их сценарии)
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[1].answer = "Приветствую, {ник}! Уже смотрю. {ид}"
Q.autoTabs()[1].command = "goto"
Q.autoTabs()[2].trigger = "дм"
Q.autoTabs()[2].answer = "Не пишите в личку, отвечу в репорте"
Q.autoTabs()[2].command = "sp"
Q.autoEnsure()
HPRINT("«помогите» — по началу репорта («помогите, дм!» — да), «дм» — только целиком («дм, помогите!» — нет)")

-- ===== 9c. остальные триггеры — только полное совпадение =====
-- Синонимы через запятую, кириллица и латиница: слово «помогите» работает по
-- началу репорта, а его соседи по списку (help) и прочие триггеры (спавн, я) —
-- строго целиком.
Q.autoTabs()[1].trigger = "спавн"
Q.autoTabs()[2].trigger = "помогите, help, хелп"
Q.autoEnsure()
local anyTrigger = {
    { "Спавн", 1 }, { "{FF0000}СПАВН{FFFFFF}", 1 },
    { "помогите!!!", 2 }, { "Помогите, дм", 2 },
    { "help", 2 }, { "HELP", 2 },
    { "хелп", 2 }, { "ХЕЛП", 2 },
}
for _, case in ipairs(anyTrigger) do
    local idx = Q.autoMatchTab(case[1])
    check(idx == case[2], "«" .. case[1] .. "» совпало не с той вкладкой: " .. tostring(idx))
end
-- у других триггеров лишний текст не допускается: только полное совпадение
local anyNo = { "спавн, машина исчезла", "СПАВН рядом", "спавнx",
                "help me please", "HELP, пропал", "не help", "не спавн",
                "хелп, дм", "хелп пожалуйста" }
for _, rep in ipairs(anyNo) do
    check(Q.autoMatchTab(rep) == nil, "ложное совпадение на «" .. rep .. "»")
end
-- короткий триггер «я» — тоже строго целиком
Q.autoTabs()[2].trigger = "я"
Q.autoEnsure()
check(Q.autoMatchTab("я") == 2, "короткий триггер «я» не сработал")
check(Q.autoMatchTab("Я") == 2, "«Я» не сработало")
check(Q.autoMatchTab("я тут") == nil, "«я тут» не должно срабатывать (только полное совпадение)")
check(Q.autoMatchTab("ясно, спасибо") == nil, "«ясно» ложно совпало с «я»")
-- возвращаем вкладки к состоянию до этой проверки
Q.autoTabs()[1].trigger = "Помогите"
Q.autoTabs()[2].trigger = "дм"
Q.autoEnsure()
HPRINT("синонимы через запятую («помогите, help, хелп»): каждое слово — свой триггер; «помогите» — по началу, остальные — целиком")


-- ===== 10. репорт без триггера / без ID =====
NOW = NOW + 100
A.perPid, A.rate = {}, {}
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

-- ===== 11. антидубль, пауза и предохранитель =====
NOW = NOW + 10
A.perPid, A.rate = {}, {}
Q.autoOnReport("Mixa_Grozz", 25, "Помогите")
QUEUE = {}
local okGap, whyGap = Q.autoOnReport("Другой", 77, "помогите")
check(okGap == false and whyGap == "слишком часто", "нет паузы между срабатываниями: " .. tostring(whyGap))
NOW = NOW + 3
local okDup, whyDup = Q.autoOnReport("Mixa_Grozz", 25, " Помогите " )
check(okDup == false and whyDup == "этому игроку уже отвечали", "нет антидубля: " .. tostring(whyDup))
check(#QUEUE == 0, "пропущенные репорты всё равно ушли")
NOW = NOW + 3
check(Q.autoOnReport("Другой", 77, "помогите") == true, "после паузы не сработало")
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

-- ===== 12. слежка: автопилот на паузе, настройка не выключается =====
NOW = NOW + 100
A.perPid, A.rate = {}, {}
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
A.perPid, A.rate = {}, {}
QUEUE = {}
check(Q.autoOnReport("После слежки", 201, "помогите") == true, "после слежки автопилот не отвечает")
HPRINT("слежка: пауза вместо выключения, после выхода работает сам")

-- ===== 12b. мероприятие (панель МП) — тоже пауза =====
NOW = NOW + 100
A.perPid, A.rate = {}, {}
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
GRND_MP.active = false
NOW = NOW + 5
Q.autoTick()
check(A.paused == nil and A.on == true, "после мероприятия автопилот не вернулся сам")
NOW = NOW + 100
A.perPid, A.rate = {}, {}
QUEUE = {}
check(Q.autoOnReport("После МП", 203, "помогите") == true, "после мероприятия автопилот не отвечает")
GRND_MP = nil
HPRINT("мероприятие: пауза вместо выключения, после окончания работает сам")

-- ===== 13. идёт ввод текста — пропуск =====
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

-- ===== 14. режим «без команды» во второй вкладке =====
NOW = NOW + 100
A.perPid, A.rate = {}, {}
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
A.on, A.perPid, A.rate = true, {}, {}
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
A.perPid, A.rate = {}, {}
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
