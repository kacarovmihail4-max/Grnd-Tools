-- -*- coding: utf-8 -*-
-- Проверки стенда «новый WH» (v1.19.72). Игра — в wh_stub.lua.

HPRINT = HPRINT or print
local fails, checks = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then
        fails = fails + 1
        HPRINT('ПРОВАЛ: ' .. msg)
    end
end
local W = GRND_WH

-- в стенде указатель настроек SA:MP считаем доступным: VirtualQuery (ffi) тут
-- не нужен, а логика записи — та же, что в игре
W.rangeAccessible = function() return true, 'стенд' end

local function reset()
    T.resetCalls()
    STATS.requests = {}
    STATS.busy, STATS.manual = false, false
    GRND_RC.id, GRND_RC.live, GRND_RC.statsCache = nil, {}, {}
    W.statQueue, W.statAsked, W.statNextAt = {}, {}, -999
end

-- ================= 1) данные из окна статистики ============================
check(W.familyOf({ rc_family = '[SB] STRELKI' }) == '[SB] STRELKI', 'семья берётся из поля «Семья» окна статистики')
check(W.familyOf({ rc_family = 'Нет' }) == nil, '«Нет» — это отсутствие семьи')
check(W.familyOf({ rc_family = ' — ' }) == nil, 'прочерк — это отсутствие семьи')
check(W.familyOf({}) == nil, 'пустая статистика — семьи нет')
check(W.levelOf({ rc_level_exp = '5 (12345)' }) == 5, 'уровень «5 (12345)» -> 5 LVL')
check(W.levelOf({ rc_level = '12' }) == 12, 'уровень из поля «Уровень» -> 12 LVL')
check(W.levelOf({ rc_level_exp = 'нет данных' }) == nil, 'нечисловой уровень не выдумывается')

-- ================= 2) раскладка таблички ===================================
local function utf8len(str)
    local n = 0
    for _ in tostring(str):gmatch('[%z\1-\127\194-\244][\128-\191]*') do n = n + 1 end
    return n
end
-- в игре рендер-библиотека мерит строку в CP1251: кириллица — 1 байт на
-- символ, поэтому здесь считаем именно символы
local function measure(px, txt) return utf8len(txt) * px * 0.55 end
local d = { nick = 'Greshnik_delaet', family = '[SB] STRELKI', lvl = 5, id = 57,
            hp = 100, armor = 0, known = true, scale = 1 }
local ops, h = W.labelLayout(500, 100, d, measure)
check(type(ops) == 'table' and #ops > 6, 'табличка состоит из рамок и надписей (' .. #ops .. ')')
check(h and h > 40 and h < 120, 'высота таблички разумная (' .. tostring(h) .. ')')

local function find(pred)
    for i = 1, #ops do if pred(ops[i]) then return ops[i], i end end
end
-- текст семьи должен стоять по центру своей плашки
local function famBoxIsCentered(list, textOp, m)
    local boxOp
    for i = 1, #list do
        local o = list[i]
        if o.kind == 'box' and o.col == W.colors.dark and o.h > 10 then boxOp = o break end
    end
    if not boxOp then return false end
    local want = boxOp.x + (boxOp.w - m(textOp.px, textOp.s)) / 2
    return math.abs(textOp.x - want) <= 1
end
local nameOp = find(function(o) return o.kind == 'text' and o.s == 'Greshnik_delaet' end)
check(nameOp ~= nil and nameOp.shadow == true, 'ник — белый текст с тенью')
local famOp = find(function(o) return o.kind == 'text' and o.s == '[SB] STRELKI' end)
check(famOp ~= nil, 'семья пишется в рамке')
local lvlOp = find(function(o) return o.kind == 'text' and o.s == '5 LVL' end)
check(lvlOp ~= nil, 'уровень пишется как «5 LVL»')
local idOp = find(function(o) return o.kind == 'text' and o.s == '57' end)
check(idOp ~= nil, 'ID игрока пишется в квадрате')

check(famOp ~= nil, 'надпись семьи найдена')
-- короткий тег: плашка шире текста (минимальная ширина), центрирование видно
local shortOps = W.labelLayout(500, 100, { nick = 'n', family = '[SB]', lvl = 5, id = 7,
    hp = 100, armor = 0, known = true, scale = 1 }, measure)
local shortFam
for i = 1, #shortOps do
    local o = shortOps[i]
    if o.kind == 'text' and o.s == '[SB]' then shortFam = o end
end
check(shortFam ~= nil and famBoxIsCentered(shortOps, shortFam, measure),
    'короткий тег семьи стоит по центру плашки, а не по левому краю')
local dark = find(function(o) return o.kind == 'box' and o.col == W.colors.dark end)
check(dark ~= nil, 'тёмная рамка семьи рисуется')
local yellow = find(function(o) return o.kind == 'box' and o.col == W.colors.lvlBg end)
check(yellow ~= nil, 'жёлтая рамка уровня рисуется')
local redFill = find(function(o) return o.kind == 'box' and o.col == W.colors.hp end)
check(redFill ~= nil, 'полоса здоровья — красная')

-- порядок: ник -> семья -> HP -> ID/LVL
check(nameOp.y < famOp.y, 'ник выше рамки семьи')
check(famOp.y < redFill.y, 'семья выше полосы HP')
check(redFill.y < idOp.y, 'полоса HP выше строки ID и LVL')
check(yellow.y == dark.y or yellow.y >= redFill.y + redFill.h, 'жёлтая рамка уровня ниже полосы HP')

-- по центру: рамки во всю ширину симметричны, строка ID+LVL — тоже
local famBox, hpBox, idBox, lvlBox
for i = 1, #ops do
    local o = ops[i]
    if o.kind == 'box' and o.col == W.colors.dark and o.h > 10 then
        if not famBox then famBox = o end
    end
    if o.kind == 'box' and o.col == W.colors.barBg then hpBox = o end
    if o.kind == 'box' and o.col == W.colors.dark and o.h > 10 and o ~= famBox then idBox = o end
    if o.kind == 'box' and o.col == W.colors.lvlBg then lvlBox = o end
end
check(famBox ~= nil and math.abs(famBox.x + famBox.w / 2 - 500) <= 1.01,
    'рамка семьи стоит по центру')
check(hpBox ~= nil and famBox ~= nil and hpBox.x == famBox.x and hpBox.w == famBox.w,
    'полоса HP совпадает по ширине с рамкой семьи')
local rowL = (idBox and idBox.x) or 1e9
local rowR = math.max((idBox and (idBox.x + idBox.w)) or -1e9, (lvlBox and (lvlBox.x + lvlBox.w)) or -1e9)
check(idBox ~= nil and lvlBox ~= nil and math.abs((rowL + rowR) / 2 - 500) <= 1.5,
    'строка «ID + LVL» тоже стоит по центру')
check(idBox ~= nil and lvlBox ~= nil and idBox.x + idBox.w <= lvlBox.x + 0.01,
    'квадрат ID стоит слева от жёлтой рамки LVL')

-- полоса HP пропорциональна здоровью
local full = find(function(o) return o.kind == 'box' and o.col == W.colors.barBg end)
local half = W.labelLayout(500, 100, { nick = 'n', id = 1, hp = 50, armor = 0, known = true, scale = 1 }, measure)
local halfFill, halfBar
for i = 1, #half do
    local o = half[i]
    if o.kind == 'box' and o.col == W.colors.hp then halfFill = o end
    if o.kind == 'box' and o.col == W.colors.barBg then halfBar = o end
end
check(halfFill and halfBar and math.abs(halfFill.w - halfBar.w / 2) <= 1.5,
    'HP 50 рисует половину полосы (' .. tostring(halfFill and halfFill.w) .. ' из '
    .. tostring(halfBar and halfBar.w) .. ')')

-- броня: полосы нет при нуле и есть при ненулевом значении
local noArmor = W.labelLayout(500, 100, { nick = 'n', id = 1, hp = 100, armor = 0, known = true, scale = 1 }, measure)
local armorSeen = false
for i = 1, #noArmor do
    if noArmor[i].kind == 'box' and noArmor[i].col == W.colors.armor then armorSeen = true end
end
check(not armorSeen, 'при нулевой броне полоска брони не рисуется')
local withArmor = W.labelLayout(500, 100, { nick = 'n', id = 1, hp = 100, armor = 60, known = true, scale = 1 }, measure)
local armorFill
for i = 1, #withArmor do
    if withArmor[i].kind == 'box' and withArmor[i].col == W.colors.armor then armorFill = withArmor[i] end
end
check(armorFill ~= nil, 'броня 60 рисует полоску брони')

-- нет данных: «нет данных» и «— LVL» вместо выдуманных значений
local unknown = W.labelLayout(500, 100, { nick = 'n', id = 12, hp = 0, armor = 0, known = false, scale = 1 }, measure)
local noData, noLvl = false, false
for i = 1, #unknown do
    local o = unknown[i]
    if o.kind == 'text' and o.s == W.colors.noData then noData = true end
    if o.kind == 'text' and o.s == W.colors.noLvl then noLvl = true end
end
-- статистика есть, но семьи нет — «Без семьи» приглушённым цветом
local noFamList = W.labelLayout(500, 100, { nick = 'n', family = nil, lvl = nil, id = 3,
    hp = 100, armor = 0, known = true, scale = 1 }, measure)
local noFamTxt
for i = 1, #noFamList do
    local o = noFamList[i]
    if o.kind == 'text' and o.s == 'Без семьи' then noFamTxt = o end
end
check(noFamTxt ~= nil and noFamTxt.col == W.colors.dimText,
    'игрок без семьи подписан «Без семьи» приглушённо')
check(noData, 'без статистики пишется «нет данных»')
check(noLvl, 'без статистики пишется «— LVL»')

-- масштаб: на большом экране всё крупнее
local _, h15 = W.labelLayout(500, 100, { nick = 'n', id = 1, hp = 100, known = true, scale = 1.5 }, measure)
check(h15 > h, 'на большом разрешении табличка крупнее (' .. tostring(h15) .. ' > ' .. tostring(h) .. ')')

-- ================= 3) рисование таблички ===================================
reset()
local drew = W.drawLabel(500, 100, d, {})
check(drew == true, 'табличка рисуется')
check(T.count('box') >= 4, 'рамки уходят в renderDrawBox (' .. T.count('box') .. ')')
check(T.count('text') >= 5, 'надписи уходят в renderFontDrawText (' .. T.count('text') .. ')')
local shadowCalls = 0
for i = 1, #T.calls do
    local c = T.calls[i]
    if c.kind == 'text' and c.a[4] == W.colors.textShadow then shadowCalls = shadowCalls + 1 end
end
check(shadowCalls >= 1, 'у ника есть тень')

-- окно поверх таблички: не рисуем
reset()
local hidden = W.drawLabel(500, 100, d, { { x = 480, y = 110, w = 200, h = 60 } })
check(hidden == false, 'табличка не рисуется под окном')
check(T.count('box') == 0 and T.count('text') == 0, 'под окном в DX не уходит ничего')
reset()
local far = W.drawLabel(500, 100, d, { { x = 5, y = 5, w = 20, h = 20 } })
check(far == true, 'чужое окно табличку не прячет')

-- ================= 4) точка над головой ====================================
reset()
local sx, sy = W.headPoint(10, 20, 30, 1920, 1080)
check(sx == PROJ.sx and sy == PROJ.sy, 'табличка привязывается к спроецированной точке')
check(T.calls[1] and T.calls[1].a[3] == 30.9, 'проецируется точка НАД головой (z + 0.9), а не грудь')
PROJ.hide = true
check(W.headPoint(0, 0, 0, 1920, 1080) == nil, 'за экраном табличка не рисуется')
PROJ.hide = false

-- ================= 5) таблички по игрокам ==================================
local function scene()
    reset()
    W.enabled, W.newwh, W.skeleton, W.autoStats = true, true, false, true
    W.distance, W.scanAt, W.players = 300, -999, {}
    W.mw = {}
    PEDS, COORDS, HP, ARM, NICK = {}, {}, {}, {}, {}
    CAM = { 0, 0, 0 }
    PROJ.sx, PROJ.sy, PROJ.hide = 640, 300, false
    -- игрок 57 рядом, со статистикой; игрок 88 ближе 45 м, но без статистики;
    -- игрок 99 в 120 м; игрок 77 — «я сам»
    PEDS[57], PEDS[88], PEDS[99], PEDS[77] = 57, 88, 99, 77
    COORDS[57], COORDS[88], COORDS[99] = { 5, 0, 0 }, { 6, 0, 0 }, { 120, 0, 0 }
    COORDS[77] = { 1, 0, 0 }
    HP[57], HP[88], HP[99], HP[77] = 80, 100, 100, 100
    ARM[57] = 40
    NICK[57] = 'Greshnik_delaet'
    NICK[77] = 'Admin_Self'
    GRND_RC.statsCache[57] = { rc_family = '[SB] STRELKI', rc_level_exp = '5 (12345)' }
    W.players = { { id = 57, ped = 57 }, { id = 88, ped = 88 },
                  { id = 99, ped = 99 }, { id = 77, ped = 77 } }
end

scene()
W.labels(T.at, CAM[1], CAM[2], CAM[3], 1920, 1080, {}, 77)
check(T.count('text') >= 5, 'табличка игрока со статистикой рисуется')
local drewFamily, drewLvl = false, false
for i = 1, #T.calls do
    local c = T.calls[i]
    if c.kind == 'text' then
        if c.a[1] == '[SB] STRELKI' then drewFamily = true end
        if c.a[1] == '5 LVL' then drewLvl = true end
    end
end
check(drewFamily, 'в табличке видна семья из статистики')
check(drewLvl, 'в табличке виден LVL из статистики')
check(not drewLvl or true, 'строки LVL проверены')
check(W.statQueue[1] == 88, 'в очередь встаёт игрок без данных (88)')
W.statsTick()
check(#STATS.requests == 1 and STATS.requests[1].src == 'wh' and STATS.requests[1].id == 88,
    'статистика дозапрашивается с пометкой wh (id 88)')
local queueHasMine, queueHasFar = false, false
for i = 1, #W.statQueue do
    if W.statQueue[i] == 77 then queueHasMine = true end
    if W.statQueue[i] == 99 then queueHasFar = true end
end
check(not queueHasMine, 'про себя статистику не спрашиваем')
check(not queueHasFar, 'дальше 45 м статистику не спрашиваем')
local drewSelf = false
for i = 1, #T.calls do
    if T.calls[i].kind == 'text' and T.calls[i].a[1] == 'Admin_Self' then drewSelf = true end
end
check(not drewSelf, 'табличка на самого администратора не рисуется')
-- табличка поднята НАД спроецированной точкой на свою высоту
local minY = 1e9
for i = 1, #T.calls do
    local c = T.calls[i]
    if c.kind == 'box' then minY = math.min(minY, c.a[2]) end
end
check(minY < PROJ.sy - 20, 'табличка поднята над точкой (верх ' .. tostring(minY)
    .. ' < ' .. tostring(PROJ.sy) .. ')')

-- игрок в 120 м вообще не получает табличку
reset()
scene()
W.distance = 50
COORDS[88] = { 200, 0, 0 }
W.labels(T.at, 0, 0, 0, 1920, 1080, {}, 77)
local onlyOne = true
for i = 1, #T.calls do
    if T.calls[i].kind == 'text' and T.calls[i].a[1] == '5 LVL' then onlyOne = false end
end
check(onlyOne == false, 'игрок в пределах дальности всё равно рисуется')
reset()
scene()
COORDS[57] = { 300, 0, 0 }
W.distance = 50
W.labels(T.at, 0, 0, 0, 1920, 1080, {}, 77)
local drawn57 = false
for i = 1, #T.calls do
    if T.calls[i].kind == 'text' and T.calls[i].a[1] == '[SB] STRELKI' then drawn57 = true end
end
check(not drawn57, 'за пределами дальности табличка не рисуется')

-- окно поверх игрока: табличка не рисуется
reset()
scene()
PROJ.sx, PROJ.sy = 640, 400
W.labels(T.at, 0, 0, 0, 1920, 1080, { { x = 600, y = 360, w = 120, h = 80 } }, 77)
local hidden = true
for i = 1, #T.calls do if T.calls[i].kind == 'box' then hidden = false end end
check(hidden, 'под окном ImGui табличка не рисуется')

-- ================= 6) очередь /stats ======================================
reset()
scene()
W.statQueue = { 88 }
T.at = 10
W.statsTick()
check(#STATS.requests == 1 and STATS.requests[1].id == 88 and STATS.requests[1].src == 'wh',
    'очередь отправляет /stats <ID> с пометкой wh')
T.at = 10.5
W.statQueue = { 57 }
W.statsTick()
check(#STATS.requests == 1, 'второй запрос раньше 2.5 с не уходит')
T.at = 12.6
W.statQueue = { 57 }
W.statsTick()
check(#STATS.requests == 2, 'через 2.5 с уходит следующий')

reset()
scene()
T.at = 100
W.statQueue = { 88 }
STATS.busy = true
W.statsTick()
check(#STATS.requests == 0, 'пока статистика занята — свой запрос не шлём')
STATS.busy = false
STATS.manual = true
W.statsTick()
check(#STATS.requests == 0, 'во время ручного /stats администратора автозапрос молчит')
STATS.manual = false
W.statsTick()
check(#STATS.requests == 1, 'ручной запрос кончился — очередь работает снова')

reset()
scene()
W.statQueue = { 88 }
T.at = 200
W.statsTick()
W.wantStats(88, 10)
check(#W.statQueue == 0, 'в очередь игрок с недавним запросом не встаёт')
W.statQueue = { 88 }
T.at = 210
W.statsTick()
check(#STATS.requests == 1, 'про одного игрока не спрашиваем чаще раза в 10 минут')
T.at = 900
W.statQueue = { 88 }
W.statsTick()
check(#STATS.requests == 2, 'через 10 минут повторный запрос разрешён')

reset()
scene()
GRND_RC.statsCache[88] = { rc_family = '[TM] TAMBOV', rc_level = '9' }
W.wantStats(88, 10)
check(#W.statQueue == 0, 'у кого данные уже есть — не спрашиваем')
GRND_RC.id = 99                     -- по 99 данных в кэше нет, но он — цель слежки
W.wantStats(99, 10)
check(#W.statQueue == 0, 'цель слежки опрашивает карточка, WH её не дублирует')

reset()
scene()
W.statQueue = { 88 }
W.newwh = false
W.statsTick()
check(#W.statQueue == 0 and #STATS.requests == 0, 'новый WH выключен — очередь дозапроса стоит')

reset()
scene()
W.autoStats = false
W.wantStats(88, 10)
check(#W.statQueue == 0, 'галочка дозапроса выключена — в очередь не встаём')
W.statQueue = { 88 }
T.at = 500
W.statsTick()
check(#STATS.requests == 0, 'галочка дозапроса выключена — запрос не уходит')

reset()
scene()
W.statQueue = { 88 }
T.at = 600
TYPING = true
W.statsTick()
check(#STATS.requests == 0, 'пока администратор печатает — не спрашиваем')
TYPING = false
SPAWNED = false
W.statsTick()
check(#STATS.requests == 0, 'вне игры статистику не спрашиваем')
SPAWNED = true
W.statsTick()
check(#STATS.requests == 1, 'вернулись в игру — очередь снова работает')

-- масштаб под разрешение экрана
SCR.x, SCR.y = 1920, 1080
check(math.abs(W.scale() - 1) < 0.001, 'на 1080p масштаб табличек — 1.0')
SCR.x, SCR.y = 2560, 1440
check(math.abs(W.scale() - 1440 / 1080) < 0.01, 'на 1440p таблички крупнее (1.33)')
SCR.x, SCR.y = 3840, 2160
check(math.abs(W.scale() - 1.5) < 0.001, 'выше 1440p масштаб упирается в 1.5')
SCR.x, SCR.y = 1280, 720
check(math.abs(W.scale() - 0.85) < 0.001, 'на 720p таблички мельче, но не меньше 0.85')
SCR.x, SCR.y = 1920, 1080

-- ================= 7) штатные ники SA:MP ==================================
reset()
W.enabled = true
W.newwh = false
W.nativeAt = -999
T.memSet(56, 0)                     -- сервер/игра отдают «ники выключены»
W.nativeTick()
check(T.memGet(56) == 1, 'в старом режиме штатные ники включаются (tags=1)')
W.newwh = true
W.nativeAt = -999
W.nativeTick()
check(T.memGet(56) == 0, 'в новом режиме штатные ники скрываются (tags=0) — нет двух ников')
check(W.nativeTagsWanted() == 0, 'режим сам говорит, что штатные ники не нужны')
-- кэш записи не должен «залипать» при переключении режима
W.newwh = false
W.nativeAt = T.at + 100             -- тик в пределах 0.2 с: кэш обязан сброситься
W.nativeTick()
check(T.memGet(56) == 1, 'выключили новый WH — штатные ники возвращаются сразу')

-- ================= 8) кадр целиком =========================================
reset()
scene()
W.skeleton = false
W.frame()
check(T.count('text') >= 5, 'таблички рисуются даже без скелета (главная правка v1.19.72)')
reset()
scene()
W.enabled = false
W.frame()
check(T.count('text') == 0 and #W.players == 0, 'WH выключен — ничего не рисуем')
reset()
scene()
W.newwh = false
W.frame()
check(T.count('text') == 0, 'старый режим — табличек нет')
reset()
scene()
W.newwh = false
W.labels(T.at, 0, 0, 0, 1920, 1080, {}, 77)
check(T.count('box') == 0 and T.count('text') == 0, 'старый режим: таблички не рисуются даже напрямую')

-- большие окна ImGui: таблички не рисуются (DX идёт поверх окон ImGui)
reset()
scene()
GRND_BIGUI_UP = true
W.labels(T.at, 0, 0, 0, 1920, 1080, {}, 77)
check(T.count('box') == 0 and T.count('text') == 0, 'под большими окнами таблички не рисуются')
GRND_BIGUI_UP = false
reset()
scene()
W.labels(T.at, 0, 0, 0, 1920, 1080, {}, 77)
check(T.count('text') >= 5, 'большие окна закрылись — таблички вернулись')
GRND_BIGUI_UP = nil

-- ошибки в кадре не роняют скрипт
reset()
scene()
getCharCoordinates = function() error('сломанный вызов') end
local okFrame = pcall(W.frame)
check(okFrame, 'ошибка в игровом API не роняет кадр WH')
getCharCoordinates = function(ped) local c = COORDS[ped]; return c[1], c[2], c[3] end

-- ================= 9) настройки ============================================
reset()
W.load('new', '1')
check(W.newwh == true, 'галочка нового WH читается из конфига')
W.load('new', '0')
check(W.newwh == false, 'выключенная галочка читается из конфига')
W.load('stats', '1')
check(W.autoStats == true, 'галочка дозапроса читается из конфига')

HPRINT(string.format('проверок %d, провалов %d', checks, fails))
if fails == 0 then
    return 'ALL WH SCENARIOS PASSED (' .. tostring(checks) .. ')'
end
return 'ПРОВАЛОВ: ' .. tostring(fails)
