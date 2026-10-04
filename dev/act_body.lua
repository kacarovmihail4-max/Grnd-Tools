
-- ======================== сценарии панели действий =========================
-- Все проверки идут через НАСТОЯЩИЙ код панели (runPanelFn) — тот самый,
-- который лежит в grnd_adm_tools.lua. Ничего не «переписываем под тест».

-- Настоящий диспетчер действий оборачиваем только ради записи вызовов:
-- дальше работает он сам (никакой подделки команд).
do
    local realHandle = grndHandleActionBtn
    function grndHandleActionBtn(label, tid, nick, ped)
        HANDLED[#HANDLED + 1] = { label = label, tid = tid, nick = nick, ped = ped }
        return realHandle(label, tid, nick, ped)
    end
    local realSub = grndDrawActSubPopup
    function grndDrawActSubPopup(RC_, TH_, tid, nick, ped, apos, adl, aat, afill, aframe,
                                 AW, AH_PAD, subY, subH, H)
        SUBP[#SUBP + 1] = { tid = tid, nick = nick, AW = AW, pad = AH_PAD,
                            subY = subY, subH = subH }
        return realSub(RC_, TH_, tid, nick, ped, apos, adl, aat, afill, aframe,
                       AW, AH_PAD, subY, subH, H)
    end
end

local function resetPanel(extra)
    RC = {
        actionsWinOpen = true, show = true, cursor = true,
        actTargetId = 77, actTargetNick = 'Nick', actTargetPed = 5,
        actionsWinAt = CLOCK.now - 1,
        actionsWinAnchorX = 960, actionsWinAnchorY = 600, actionsWinCircleY = 520,
        actSubPopup = nil,
    }
    for k, v in pairs(extra or {}) do RC[k] = v end
    _G.GRND_RC = RC                      -- диспетчер берёт состояние отсюда
    GRND_MOUSE.x, GRND_MOUSE.y, GRND_MOUSE.down = -500, -500, false
    PENDING_CLICK, SCRIPT.clickId, SCRIPT.subApply = false, nil, false
end

-- значки панели в порядке отрисовки: 1-й = первое действие списка
local function icons()
    local out = {}
    for _, b in ipairs(BUTTONS) do
        if tostring(b.id):find('##act_', 1, true) then out[#out + 1] = b end
    end
    return out
end
local function center(b) return b.x + b.w / 2, b.y + b.h / 2 end

-- ============ 0) каждое действие — своя настоящая команда =================
-- Кликаем ПО ЗНАЧКУ в панели и смотрим, что реально ушло на сервер: так
-- проверяется вся цепочка «значок -> панель -> настоящий диспетчер действий».
local EXPECT = {
    ['Выдать ХП'] = { sub = 'hp' },
    ['Выдать броню'] = { sub = 'arm' },
    ['Подбросить'] = { chat = { '/slap 77' } },
    ['Заспавнить'] = { chat = { '/spawn 77' } },
    ['Заморозить'] = { chat = { '/freeze 77' } },
    ['Разморозить'] = { chat = { '/unfreeze 77' } },
    ['Починить т/с'] = { chat = { '/fixcar 77' } },
    ['Перевернуть т/с'] = { chat = { '/flip 77' } },
    ['Заправить т/с'] = { sub = 'fuel' },
    ['Заспавнить т/с'] = { chat = { '/spcar 123' } },
    ['ТП на дорогу'] = { chat = {} },            -- команда на сервере ещё не подключена
    ['ТП к игроку'] = { chat = { '/spoff', '/goto 77' } },
    ['ТП игрока к себе'] = { chat = { '/gethere 77' } },
    ['Оружие'] = { chat = { '/weap 77' } },
    ['Отобрать все оружие'] = { chat = { '/rgun 77' } },
    ['Статистика'] = { stats = '77/button' },
    ['Активные наказания'] = { chat = { '/getinfo 77' } },
    ['Лицензии'] = { chat = { '/alic 77' } },
    ['Сообщить в /a'] = { sub = 'report_a' },
}

local function probe()
    SCRIPT.clickId = nil
    frame()
    return icons()
end
local function clickIcon(i)
    resetPanel()
    local b = probe()[i]
    if not b then return nil end
    GRND_MOUSE.x, GRND_MOUSE.y = center(b)
    SCRIPT.clickId = b.id
    frame()
    SCRIPT.clickId = nil
    return b
end

-- открыть подпанель действия: клик по значку, затем кадр, в котором панель
-- уже знает про подпанель (её рисует СЛЕДУЮЩИЙ кадр)
local function openSub(label)
    resetPanel()
    local idx = nil
    for i, l in ipairs(ACTIONS_LIST) do if l == label then idx = i end end
    local b = probe()[idx]
    GRND_MOUSE.x, GRND_MOUSE.y = center(b)
    SCRIPT.clickId = b.id
    frame()
    SCRIPT.clickId = nil
    frame()
end

local wrong = {}
for i, label in ipairs(ACTIONS_LIST) do
    local exp = EXPECT[label]
    if not exp then
        wrong[#wrong + 1] = label .. ' (нет ожидания в стенде)'
    else
        clickIcon(i)
        local got = table.concat(CHAT, '|')
        if exp.chat then
            if got ~= table.concat(exp.chat, '|') then
                wrong[#wrong + 1] = label .. ' -> «' .. got .. '»'
            end
        elseif exp.sub then
            if RC.actSubPopup ~= exp.sub then
                wrong[#wrong + 1] = label .. ' -> подпанель ' .. tostring(RC.actSubPopup)
            end
        elseif exp.stats then
            if (STATS_REQ[1] or '') ~= exp.stats then
                wrong[#wrong + 1] = label .. ' -> запрос ' .. tostring(STATS_REQ[1])
            end
        end
    end
end
check(#wrong == 0, 'все 19 действий выполняют свою команду: ' .. table.concat(wrong, '; '))

-- «Сообщить в /a» внутри подпанели отправляет текст в админ-чат
openSub('Сообщить в /a')
check(RC.actSubPopup == 'report_a', '«Сообщить в /a» открывает свою подпанель')
local aHelp = findBtn('##act_a_help')
check(aHelp ~= nil, 'в подпанели /a есть кнопка «Запросить помощь»')
if aHelp then
    GRND_MOUSE.x, GRND_MOUSE.y = center(aHelp)
    SCRIPT.clickId = aHelp.id
    frame()
    SCRIPT.clickId = nil
    check(CHAT[1] and CHAT[1]:find('/a Игрок Nick %[77%] нуждается в помощи!') == 1,
        'подпанель /a отправляет сообщение в админ-чат: ' .. tostring(CHAT[1]))
end

-- ------------------------- 1) раскладка и вид -----------------------------
resetPanel()
local ok, err = frame()
check(ok, 'кадр панели проходит без ошибок' .. (ok and '' or (': ' .. tostring(err))))
check(BEGIN_ID == '##grnd_recon_actions', 'рисуется окно панели действий')
check(countBtns('##act_') == 19, 'все 19 действий нарисованы (по значку на действие)')
check(#ACTIONS_LIST == 19, 'в списке действий ровно 19 пунктов')

local all = icons()
check(#all == 19, 'значков нарисовано столько же, сколько действий')

local total = 0
for _, v in pairs(DRAWS) do total = total + v end
check(total >= 38, 'у каждого значка есть графика (примитивов: ' .. total .. ')')
check(ROUNDRECTS >= 2, 'полоса рисуется «таблеткой» (скруглённые плашки)')
-- подложка под значками: тёмная «таблетка» на всю ширину полосы
local pill = nil
for _, q in ipairs(RECTS) do
    local c = q.c
    if type(c) == 'table' and c[1] == 10 and c[2] == 14 and c[3] == 20 and (tonumber(c[4]) or 0) >= 200 then
        pill = q
    end
end
check(pill ~= nil, 'значки лежат на тёмной подложке-«таблетке»')
check(pill ~= nil and math.abs((pill.p2.y - pill.p1.y) - (32 + 10)) <= 12,
    'высота «таблетки» обнимает значки: ' ..
    tostring(pill and (pill.p2.y - pill.p1.y) or '—'))
check(pill ~= nil and (pill.p2.x - pill.p1.x) >= 500,
    '«таблетка» на всю ширину полосы: ' .. tostring(pill and (pill.p2.x - pill.p1.x) or '—'))

-- Компактность: без подписей панель в разы меньше прежнего окна на 6 колонок
check(WIN.w <= 760, 'панель компактная по ширине: ' .. WIN.w .. ' px')
check(WIN.h <= 70, 'панель компактная по высоте: ' .. WIN.h .. ' px')
check(WIN.w > 300, 'панель не «схлопнулась» в точку')
check(WIN.w * WIN.h < 960 * 218 / 3,
    'панель втрое меньше прежнего окна действий (' .. (WIN.w * WIN.h) .. ' px²)')

-- Заголовка «Действия», ника и крестика больше нет
local bad = nil
for _, t in ipairs(TEXTS) do
    if t.t:find('Действия', 1, true) or t.t:find('Nick', 1, true)
       or t.t:find('[77]', 1, true) or t.t:find('×', 1, true) then bad = t.t end
end
check(bad == nil, 'на панели нет ни «Действия», ни ника, ни крестика' .. (bad and (': ' .. bad) or ''))
check(#TEXTS == 0, 'без наведения панель вообще ничего не пишет текстом (только значки)')

-- Все кнопки внутри окна — ничего не обрезается краем
local inside = true
for _, b in ipairs(all) do
    if b.x < WIN.x - 0.5 or b.x + b.w > WIN.x + WIN.w + 0.5
       or b.y < WIN.y - 0.5 or b.y + b.h > WIN.y + WIN.h + 0.5 then inside = false end
end
check(inside, 'значки не выходят за пределы панели')

-- ------------------------ 2) наведение и подсказка ------------------------
local third = all[3]
GRND_MOUSE.x, GRND_MOUSE.y = center(third)
frame()
check(#TEXTS >= 1 and TEXTS[1].t == ACTIONS_LIST[3],
    'над значком показывается название действия («' .. tostring(ACTIONS_LIST[3]) .. '»)')

-- «крестик» и ник не появляются даже при наведении
local bad2 = nil
for _, t in ipairs(TEXTS) do
    if t.t:find('Nick', 1, true) or t.t:find('[77]', 1, true) or t.t:find('×', 1, true) then bad2 = t.t end
end
check(bad2 == nil, 'в подсказке нет ни ника, ни ID, ни крестика')

-- ------------------------ 3) нажатие действия -----------------------------
-- probe/clickIcon определены выше: «разведка» даёт координаты значков, затем
-- отдельный кадр с нажатием (клик всегда сбрасывается — иначе он «залипнет»).

clickIcon(3)
check(#HANDLED == 1 and HANDLED[1].label == ACTIONS_LIST[3],
    'нажатие значка выполняет своё действие («' .. tostring(ACTIONS_LIST[3]) .. '»)')
check(HANDLED[1] and HANDLED[1].tid == 77, 'действие уходит на игрока из рекона (ID 77)')
check(HANDLED[1] and HANDLED[1].ped == 5, 'в действие передаётся пед цели')
check(HANDLED[1] and HANDLED[1].nick == 'Nick', 'в действие передаётся ник цели')
check(RC.actionsWinOpen == false, 'нажатие кнопки закрывает панель')

clickIcon(7)
check(#HANDLED == 1 and HANDLED[1].label == ACTIONS_LIST[7],
    'нажатие седьмого значка выполняет седьмое действие')
check(RC.actionsWinOpen == false, 'обычное действие закрывает панель')

-- -------------------------- 4) кнопки с подпанелью ------------------------
local subBtn = nil
for i, label in ipairs(ACTIONS_LIST) do
    if label == 'Выдать ХП' then subBtn = i end
end
check(subBtn ~= nil, 'действие «Выдать ХП» есть в списке (кнопка с подпанелью)')

clickIcon(subBtn)
check(#HANDLED == 1 and HANDLED[1].label == 'Выдать ХП', '«Выдать ХП» — действие вызвано')
check(RC.actionsWinOpen == true, 'кнопка с подпанелью панель НЕ закрывает (нужен ползунок)')
check(RC.actSubPopup == 'hp', 'открылась подпанель выдачи ХП')

frame()
check(#SUBP == 1, 'подпанель рисуется под полосой значков')
check(SUBP[1] and SUBP[1].subH == 76, 'высота подпанели ХП — 76 px')
check(SUBP[1] and SUBP[1].AW >= 704, 'подпанель получает достаточно ширины (AW=' ..
    tostring(SUBP[1] and SUBP[1].AW) .. ')')
check(SUBP[1] and SUBP[1].subY >= 20, 'подпанель стоит ПОД полосой значков, не поверх')
check(WIN.h >= 46 + 76, 'окно панели растёт под подпанель (h=' .. WIN.h .. ')')

-- повторное нажатие того же значка убирает подпанель, панель остаётся
local again = probe()[subBtn]
GRND_MOUSE.x, GRND_MOUSE.y = center(again)
SCRIPT.clickId = again.id
frame()
SCRIPT.clickId = nil
check(RC.actSubPopup == nil, 'повторное нажатие значка закрывает подпанель')
check(RC.actionsWinOpen == true, 'при этом сама панель остаётся открытой')

-- кнопка «Выдать» (внутри подпанели) реально отправляет команду и закрывает панель
resetPanel({ actSubPopup = 'arm' })
SCRIPT.clickId = nil
frame()
check(RC.actSubPopup == 'arm', 'подпанель брони открыта')
local armApply = findBtn('##act_arm_apply')
check(armApply ~= nil, 'в подпанели брони есть кнопка «Выдать»')
if armApply then
    GRND_MOUSE.x, GRND_MOUSE.y = center(armApply)
    SCRIPT.clickId = armApply.id
    frame()
    SCRIPT.clickId = nil
    check(CHAT[1] == '/arm 77 100', 'кнопка «Выдать» отправляет /arm 77 100, а не ' .. tostring(CHAT[1]))
    check(RC.actionsWinOpen == false, 'кнопка «Выдать» внутри подпанели закрывает панель')
end

-- ползунки и кнопки-«быстрые значения» настоящих подпанелей
openSub('Выдать ХП')
local q50 = findBtn('##act_hp_q_50')
check(q50 ~= nil, 'в подпанели ХП есть быстрое значение 50')
if q50 then
    GRND_MOUSE.x, GRND_MOUSE.y = center(q50)
    SCRIPT.clickId = q50.id
    frame()
    SCRIPT.clickId = nil
    check(RC.actHpVal == 50, 'быстрое значение ставит 50 ХП (actHpVal=' .. tostring(RC.actHpVal) .. ')')
end
local hpApply = findBtn('##act_hp_apply')
if hpApply then
    GRND_MOUSE.x, GRND_MOUSE.y = center(hpApply)
    SCRIPT.clickId = hpApply.id
    frame()
    SCRIPT.clickId = nil
    check(CHAT[1] == '/hp 77 50', 'подпанель ХП выдаёт /hp 77 50, а не ' .. tostring(CHAT[1]))
end

openSub('Заправить т/с')
local fuelApply = findBtn('##act_fuel_apply')
check(fuelApply ~= nil, 'в подпанели топлива есть кнопка «Заправить»')
if fuelApply then
    GRND_MOUSE.x, GRND_MOUSE.y = center(fuelApply)
    SCRIPT.clickId = fuelApply.id
    frame()
    SCRIPT.clickId = nil
    check(CHAT[1] and CHAT[1]:find('/setfuel 123', 1, true) == 1,
        'подпанель топлива заправляет /setfuel 123 …, а не ' .. tostring(CHAT[1]))
end

-- ------------------- 5) закрытие кликом по любому месту -------------------
resetPanel()
SCRIPT.clickId = nil
frame()
GRND_MOUSE.x, GRND_MOUSE.y = 20, 900            -- курсор далеко от панели
PENDING_CLICK = true
frame()
check(RC.actionsWinOpen == false, 'клик по любому месту экрана вне панели закрывает её')
PENDING_CLICK = false

resetPanel()
SCRIPT.clickId = nil
frame()
GRND_MOUSE.x, GRND_MOUSE.y = 20, 900
PENDING_CLICK = true
CLOCK.now = RC.actionsWinAt + 0.10              -- панель только что открыли
frame()
PENDING_CLICK = false
check(RC.actionsWinOpen == true,
    'клик, которым панель открыли, не закрывает её в тот же момент')
CLOCK.now = RC.actionsWinAt + 1.0

resetPanel()
frame()
GRND_MOUSE.x, GRND_MOUSE.y = 20, 900
PENDING_CLICK = false                           -- ПКМ/СКМ: не наша забота
frame()
check(RC.actionsWinOpen == true, 'правая/средняя кнопка панель не закрывают')

resetPanel()
frame()
local lb = icons()[5]
GRND_MOUSE.x, GRND_MOUSE.y = center(lb)         -- курсор на самой панели
PENDING_CLICK = true
frame()
check(RC.actionsWinOpen == true, 'клик ПО панели её не закрывает')

-- --------------------------- 6) перетаскивание ----------------------------
resetPanel()
frame()
local yHint = WIN.y + 4                          -- пустая строка под подсказку
GRND_MOUSE.x, GRND_MOUSE.y, GRND_MOUSE.down = WIN.x + WIN.w / 2, yHint, true
frame()
check(RC.actDragging == true, 'панель можно взять и перетащить (за верхнюю полосу)')
local wx0 = WIN.x
GRND_MOUSE.x, GRND_MOUSE.y = GRND_MOUSE.x + 70, GRND_MOUSE.y + 25
frame()
check(math.abs(WIN.x - (wx0 + 70)) < 1.5, 'панель двигается за мышью (x)')
GRND_MOUSE.down = false
frame()
check(RC.actDragging == false, 'отпустили мышь — перетаскивание закончилось')
check(RC.actionsWinUser == true, 'положение панели запомнено как «пользовательское»')
check(math.abs(RC.savedActionsWinX - WIN.x) < 1, 'сохранённая позиция = текущая (x)')
check(math.abs(RC.savedActionsWinY - WIN.y) < 1, 'сохранённая позиция = текущая (y)')

-- новое открытие — на том же месте
local keepX, keepY = RC.savedActionsWinX, RC.savedActionsWinY
resetPanel({ actionsWinUser = true, savedActionsWinX = keepX, savedActionsWinY = keepY })
SCRIPT.clickId = nil
frame()
check(tonumber(keepX) and math.abs(WIN.x - keepX) < 0.5,
    'панель открывается там, где её оставили (x=' .. tostring(keepX) .. ')')
check(tonumber(keepY) and math.abs(WIN.y - keepY) < 0.5,
    'панель открывается там, где её оставили (y=' .. tostring(keepY) .. ')')
RC.actionsWinUser = false

-- нажатие ПО значку не превращается в перетаскивание
resetPanel()
frame()
local ib = icons()[4]
local ibx, iby = center(ib)
GRND_MOUSE.x, GRND_MOUSE.y, GRND_MOUSE.down = ibx, iby, true
frame()
check(RC.actDragging ~= true, 'нажатие по значку не хватает панель за собой')

-- ------------------- 7) узкий экран: ничего не обрезается -----------------
resX = 560
resetPanel({ actionsWinUser = false })
SCRIPT.clickId = nil
frame()
check(countBtns('##act_') == 19, 'на узком экране все 19 значков на месте')
check(WIN.w <= resX - 8, 'панель влезает по ширине (w=' .. WIN.w .. ' при 560)')
local insideN = true
for _, b in ipairs(icons()) do
    if b.x < WIN.x - 0.5 or b.x + b.w > WIN.x + WIN.w + 0.5
       or b.y < WIN.y - 0.5 or b.y + b.h > WIN.y + WIN.h + 0.5 then insideN = false end
end
check(insideN, 'на узком экране значки не вылезают за панель')
local rowsY = {}
for _, b in ipairs(icons()) do rowsY[math.floor(b.y / 10)] = true end
local nRows = 0
for _ in pairs(rowsY) do nRows = nRows + 1 end
check(nRows >= 2, 'на узком экране значки переносятся во второй ряд (' .. nRows .. ')')
resX = 1920

-- на очень узком экране подпанель всё равно получает рабочую ширину
resX = 700
resetPanel({ actSubPopup = 'hp', actionsWinUser = false })
SCRIPT.clickId = nil
frame()
check(SUBP[1] and SUBP[1].AW >= 704,
    'на узком экране подпанель не сжимается (AW=' .. tostring(SUBP[1] and SUBP[1].AW) .. ')')
check(WIN.w >= 704, 'окно панели расширяется под подпанель (w=' .. WIN.w .. ')')
resX = 1920

-- ----------------------- 7б) смена цели слежки ----------------------------
-- Пока панель открыта для одного игрока, администратор может кликнуть по
-- чекеру и перейти на другого: панель обязана закрыться, а не «переехать».
resetPanel()
SCRIPT.clickId = nil
frame()
check(RC.actionsWinRcId == nil or RC.actionsWinRcId == tonumber(RC.id),
    'при открытии панель запоминает цель слежки')
RC.actionsWinRcId = 77
RC.id = 88
frame()
check(RC.actionsWinOpen == false, 'цель слежки сменилась — панель закрывается')
resetPanel()
RC.actionsWinRcId = 77
RC.id = 77
frame()
check(RC.actionsWinOpen == true, 'та же цель слежки — панель остаётся открытой')
resetPanel()
RC.actionsWinRcId = nil
RC.id = 88
frame()
check(RC.actionsWinOpen == true, 'цель слежки неизвестна — панель не закрываем наугад')

-- габариты окна панели запоминаются: по ним чекеры не принимают клики
resetPanel()
SCRIPT.clickId = nil
frame()
check(type(RC.actionsWinRect) == 'table' and RC.actionsWinRect.w == WIN.w
    and RC.actionsWinRect.h == WIN.h,
    'панель запоминает свои габариты для гейта чекеров')
check(RC.actionsWinRect.x == WIN.x and RC.actionsWinRect.y == WIN.y,
    'габариты панели совпадают с её положением на экране')

-- ------------------ 8) панель закрыта — ничего не рисуем ------------------
resetPanel({ actionsWinOpen = false })
GRND_MOUSE.x, GRND_MOUSE.y = 100, 100
SCRIPT.clickId = nil
frame()
check(#BUTTONS == 0, 'при закрытой панели не рисуется ни одного значка')

-- ----------------- 9) значки: у каждого действия свой ---------------------
local dotLabels = {}
for _, label in ipairs(ACTIONS_LIST) do
    local k = grndActIconKey(label)
    if k == 'dot' then dotLabels[#dotLabels + 1] = label end
end
check(#dotLabels == 0, 'у каждого действия есть свой значок (без «заглушек»): ' ..
    table.concat(dotLabels, ', '))

local keys = {}
for _, label in ipairs(ACTIONS_LIST) do keys[grndActIconKey(label)] = true end
local nKeys = 0
for _ in pairs(keys) do nKeys = nKeys + 1 end
check(nKeys >= 15, 'значки разные, а не один на всех (различных: ' .. nKeys .. ')')

-- разные действия должны быть РАЗНЫМИ и по графике, а не только по ключу
local sigs, sigList = {}, {}
for _, label in ipairs(ACTIONS_LIST) do
    for kk in pairs(DRAWS) do DRAWS[kk] = 0 end
    grndDrawActIcon(DL, function(x, y) return { x = x, y = y } end,
        grndActIconKey(label), 50, 50, 22, 0)
    local sig = ''
    for kk, vv in pairs(DRAWS) do sig = sig .. kk .. '=' .. vv .. ';' end
    if not sigs[sig] then sigs[sig] = true; sigList[#sigList + 1] = sig end
end
check(#sigList >= 15, 'значки различаются графикой, а не только подписью (вариантов: '
    .. #sigList .. ')')

local emptyIcons = {}
for _, label in ipairs(ACTIONS_LIST) do
    local k = grndActIconKey(label)
    for kk in pairs(DRAWS) do DRAWS[kk] = 0 end
    grndDrawActIcon(DL, function(x, y) return { x = x, y = y } end, k, 50, 50, 22, 0)
    local n = 0
    for _, v in pairs(DRAWS) do n = n + v end
    if n < 2 then emptyIcons[#emptyIcons + 1] = label end
end
check(#emptyIcons == 0, 'каждый значок реально рисуется: ' .. table.concat(emptyIcons, ', '))

-- ---------------------- 10) кнопки с ползунком ----------------------------
local subs, plain = {}, 0
for _, label in ipairs(ACTIONS_LIST) do
    local k = grndActSubKey(label)
    if k then subs[k] = label else plain = plain + 1 end
end
check(subs['hp'] == 'Выдать ХП', 'подпанель ХП привязана к «Выдать ХП»')
check(subs['arm'] == 'Выдать броню', 'подпанель брони привязана к «Выдать броню»')
check(subs['fuel'] == 'Заправить т/с', 'подпанель топлива привязана к «Заправить т/с»')
check(subs['report_a'] == 'Сообщить в /a', 'подпанель /a привязана к «Сообщить в /a»')
check(plain == 15, 'остальные 15 действий панель закрывают (их: ' .. plain .. ')')

-- --------------------- 11) кадр без курсора -------------------------------
resetPanel({ cursor = false })
SCRIPT.clickId = nil
FLAGS = {}
frame()
local hasNoInputs = false
for _, f in ipairs(FLAGS) do if f == 'NoInputs' then hasNoInputs = true end end
check(hasNoInputs, 'без курсора панель не перехватывает ввод (NoInputs)')
check(#TEXTS == 0, 'без курсора текст панели не рисуется')

if FAILS == 0 then
    return 'ALL ACTION PANEL SCENARIOS PASSED (' .. tostring(TOT) .. ')'
end
return 'ПРОВАЛОВ: ' .. tostring(FAILS) .. ' из ' .. tostring(TOT)
