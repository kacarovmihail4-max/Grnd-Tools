
-- ---- стенд: шаблоны наказаний (редактор с селектором + полоса в окне репорта) ----
local Q = _G.GRND_QR
local P = Q.pun

function setPunItems()
    P.items = {
        { id = 1, name = "Мут за флуд", text = "Приветствую, мут за флуд", cmd = "mute", time = "60", reason = "флуд в чате" },
        { id = 2, name = "Кик за оскорбления", text = "Кик за оскорбления", cmd = "kick", time = "", reason = "оскорбления" },
    }
    P.nextId = 3
end
setPunItems()
P.loaded = true      -- конфиг прочитан: стенд подставляет шаблоны сам
Q.mode = "test"

-- шаблоны ответов тоже нужны: проверяем, что две полосы не показываются вместе
Q.items = { { id = 1, name = "Ответ 1", text = "Приветствую" } }
Q.nextId = 2
Q.loaded = true

local dl = {}
function dl.AddRectFilled() end
function dl.AddRect() end
function dl.AddTriangleFilled() end
function dl.PushClipRect() return true end
function dl.PopClipRect() end

local CTX   -- один на весь стенд: буферы полей живут в ImGui-контексте окна
local POS = {}
local function makeCtx()
    local im = {}
    function im.ImVec2(x, y) return { x = x, y = y } end
    function im.SetCursorPos() end
    function im.InvisibleButton(id, size)
        BTNS[#BTNS + 1] = tostring(id)
        return CLICK[tostring(id)] and true or false
    end
    function im.IsItemHovered() return false end
    function im.IsItemActive() return false end
    function im.GetWindowPos() return { x = POS.wx or 0, y = POS.wy or 0 } end
    function im.GetWindowDrawList() return dl end
    function im.SetNextWindowPos(p, cond) POS.x, POS.y = p.x, p.y end
    function im.SetNextWindowSize(sz, cond) POS.w, POS.h = sz.x, sz.y end
    function im.SetNextWindowFocus() end
    function im.SetNextItemWidth() end
    function im.SetTooltip(t) TOOLTIP = tostring(t) end
    function im.InputTextMultiline(id, buf, cap, sz, x)
        if TYPE[id] then grndBinderWriteCBuf(buf, cap, TYPE[id]); TYPE[id] = nil end
        return false
    end
    function im.InputTextWithHint(id, hint, buf, cap)
        if TYPE[id] then grndBinderWriteCBuf(buf, cap, TYPE[id]); TYPE[id] = nil end
        return false
    end
    function im.InputText(id, buf, cap)
        if TYPE[id] then grndBinderWriteCBuf(buf, cap, TYPE[id]); TYPE[id] = nil end
        return false
    end
    function im.PushStyleColor() return true end
    function im.PopStyleColor() end
    function im.PushStyleVar() return true end
    function im.PushStyleVarVec2() return true end
    function im.PushStyleVarFloat() return true end
    function im.PopStyleVar() end
    function im.GetIO() return { MousePos = { x = -500, y = -500 }, MouseClicked = { [0] = false } } end
    im.new = { char = setmetatable({}, { __index = function() return function() return {} end end }) }
    im.Col = { FrameBg = 1, FrameBgHovered = 2, FrameBgActive = 3, Text = 4, Border = 5,
               WindowBg = 6, Border2 = 7 }
    im.StyleVar = { FrameBorderSize = 1, FramePadding = 2, WindowPadding = 3, WindowRounding = 4 }
    return {
        im = im, dl = dl,
        at = function(x, y) return im.ImVec2((POS.wx or 0) + x, (POS.wy or 0) + y) end,
        x = 40, y = 40, w = 880, h = 520,
        uiText = function(x, y, str, col, sc)
            TXT[#TXT + 1] = { x = x, y = y, str = tostring(str), sc = sc }
        end,
        roundRect = function() end, col32 = col32, rgba = function() return 0 end,
        c4 = function() return 0 end, gradRect = function() end,
        tsize = function(s) return #tostring(s) * 7, 14 end,
        drawnW = function(s, sc) return #tostring(s) * 7 * (sc or 1) end,
        menuToggle = function() return false end,
        pushCol = function() return true end, popCol = function() end,
        pushVarF = function() return true end, pushVarV2 = function() return true end,
        popVar = function() end,
    }
end
CTX = makeCtx()

local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end
local function texts()
    local out = {}
    for i = 1, #TXT do out[#out + 1] = TXT[i].str end
    return table.concat(out, " | ")
end
local function has(word) return texts():find(word, 1, true) ~= nil end
local function drawSettings()
    TXT, BTNS = {}, {}
    local ok = _G.grndQrPunishDraw(CTX)
    check(ok == true, "раздел «Наказания» не нарисовался")
end
local function drawPicker()
    TXT, BTNS = {}, {}
    CLICK = CLICK or {}
    -- полоса рисуется тем же ctx, но со своим begin/wf (как окно репорта)
    local pc = makePickerCtx(CTX.im, dl, CTX.at)
    pc.uiText = CTX.uiText
    local ok = _G.grndQrPunPickerDraw(pc)
    check(ok == true, "полоса наказаний не нарисовалась")
end

-- ===== 1. редактор наказания: поля как просили =====
CLICK = {}
P.selId, P.isNew, P.formKey = 1, false, nil
P.comboOpen = false
drawSettings()
check(has("Шаблоны наказаний"), "нет заголовка «Шаблоны наказаний»")
check(has("Список наказаний"), "нет списка наказаний")
check(has("Название"), "нет поля «Название»")
check(has("Ответ на репорт"), "нет поля «Ответ на репорт»")
check(has("Команда наказания"), "нет селектора команды наказания")
check(has("Время, минут"), "у /mute нет поля «Время, минут»")
check(has("Причина"), "нет поля «Причина»")
check(has("/mute · 60 мин"), "нет подписи шаблона в списке: " .. texts())
HPRINT("редактор /mute: поля на месте — «" .. texts() .. "»")

-- ===== 2. у команды без срока поля «Время» нет =====
P.selId, P.isNew, P.formKey = 2, false, nil
drawSettings()
check(not has("Время"), "у /kick появилось поле «Время»")
check(has("Причина"), "у /kick пропала «Причина»")
HPRINT("редактор /kick: «Время» не показывается, «Причина» есть")

-- ===== 3. выпадающий список команд =====
P.selId, P.isNew, P.formKey = 1, false, nil
drawSettings()
check(not has("/ban"), "список команд открыт без нажатия")
CLICK["##grnd_qr_pun_cmd"] = true
drawSettings()
CLICK = {}
check(has("/ban") and has("/mute") and has("/rmute") and has("/jail") and has("/kick") and has("/warn"),
    "в выпадающем списке нет всех команд: " .. texts())
check(not has("Время, минут"), "при открытом списке поля «Время» остались под ним")
HPRINT("селектор: открылся список команд /ban … /warn")

-- ===== 4. выбор команды /rmute подставляет «Время, минут» =====
CLICK["##grnd_qr_pun_cmd_rmute"] = true
drawSettings()
CLICK = {}
P.selId, P.isNew, P.formKey = 1, false, nil
drawSettings()
check(not has("/jail"), "список команд не закрылся после выбора")
check(has("/rmute"), "выбранная команда не подставилась в селектор")
check(has("Время, минут"), "после /rmute не появилось поле «Время»")
HPRINT("выбор /rmute: список закрылся, появилось «Время, минут»")

-- ===== 5. сохранение шаблона: команда + время + причина + ответ =====
P.selId, P.isNew, P.formKey = 1, false, nil
TYPE["##grnd_qr_pun_name"] = "Мут 120 за флуд"
TYPE["##grnd_qr_pun_text"] = "Приветствую, мут 120 минут за флуд"
TYPE["##grnd_qr_pun_time"] = "120"
TYPE["##grnd_qr_pun_reason"] = "флуд в общем чате"
CLICK["##grnd_qr_pun_save"] = true
drawSettings()
CLICK = {}
local it = Q.punById(1)
check(it.cmd == "rmute", "команда не сохранилась: " .. tostring(it.cmd))
check(it.time == "120", "время не сохранилось: " .. tostring(it.time))
check(it.reason == "флуд в общем чате", "причина не сохранилась: " .. tostring(it.reason))
check(it.name == "Мут 120 за флуд", "название не сохранилось: " .. tostring(it.name))
check(TOASTS[#TOASTS] == "Наказание сохранено", "нет подтверждения сохранения")
HPRINT("сохранение: «" .. Q.punPreview(it) .. "»")

-- ===== 6. «+ Новый шаблон» без команды не сохраняется =====
P.selId, P.isNew, P.formKey = nil, true, nil
drawSettings()
TYPE["##grnd_qr_pun_name"] = "Черновик"
CLICK["##grnd_qr_pun_save"] = true
drawSettings()
CLICK = {}
check(#P.items == 2, "черновик без команды всё-таки сохранился")
check(TOASTS[#TOASTS] == "Выберите команду наказания", "нет предупреждения про команду")

-- ===== 7. новый шаблон сохраняется целиком =====
CLICK["##grnd_qr_pun_cmd"] = true
drawSettings()
CLICK = {}
CLICK["##grnd_qr_pun_cmd_ban"] = true
drawSettings()
CLICK = {}
P.selId, P.isNew, P.formKey = nil, true, nil     -- редактор всё ещё «новый»
drawSettings()
TYPE["##grnd_qr_pun_time"] = "7"
TYPE["##grnd_qr_pun_reason"] = "читы"
CLICK["##grnd_qr_pun_save"] = true
drawSettings()
CLICK = {}
check(#P.items == 3, "новый шаблон не добавился: " .. tostring(#P.items))
local nw = P.items[3]
check(nw.cmd == "ban" and nw.time == "7" and nw.reason == "читы",
    "новый шаблон сохранён неверно: " .. Q.punPreview(nw))
HPRINT("новый шаблон: «" .. Q.punPreview(nw) .. "»")

-- ===== 8. удаление — подтверждение показывает сама кнопка =====
P.selId, P.isNew, P.formKey = 3, false, nil
drawSettings()
CLICK["##grnd_qr_pun_remove"] = true
drawSettings()
CLICK = {}
check(P.delArm == 3, "первое нажатие «Удалить» не взвело подтверждение")
check(not has("Нажмите"), "появилась строка-подсказка про удаление")
CLICK["##grnd_qr_pun_remove"] = true
drawSettings()
CLICK = {}
check(Q.punById(3) == nil, "шаблон не удалился")
check(TOASTS[#TOASTS] == "Наказание удалено", "нет тоста про удаление")
HPRINT("удаление: подтверждение кнопкой, тост — «" .. TOASTS[#TOASTS] .. "»")

-- ===== 9. конфиг: сохранение и чтение =====
check(Q.punSave() == true, "шаблоны наказаний не сохранились в конфиг")
local body = FILES[Q.punPath()]
check(body and body:find("cmd=rmute", 1, true) ~= nil, "в конфиге нет команды: " .. tostring(body))
check(body:find("reason=флуд в общем чате", 1, true) ~= nil, "в конфиге нет причины")
P.items, P.loaded, P.selId = nil, false, nil
check(Q.punLoad() == true, "конфиг наказаний не прочитался")
local back = Q.punById(1)
check(back and back.cmd == "rmute" and back.time == "120" and back.reason == "флуд в общем чате",
    "шаблон не пережил сохранение/чтение")
HPRINT("конфиг: 2 шаблона наказаний записаны и прочитаны обратно")

-- ===== 10. чужая команда в конфиге отбрасывается =====
P.items = { { id = 1, cmd = "hack", name = "плохое", time = "1", reason = "x" } }
Q.punNormalize()
check(#P.items == 0, "в шаблоны попало постороннее «наказание»: " .. tostring(#P.items))
setPunItems()

-- ===== 11. полоса наказаний в окне репорта: посредине и вровень =====
GRND_REP.winX, GRND_REP.winW, GRND_REP.winY, GRND_REP.winH = 660, 600, 300, 260
GRND_REP.open = true
GRND_REP.playerId, GRND_REP.author = "25", "Тестовый"
Q.mode = "test"
P.pickOpen = true
POS.x, POS.y, POS.w, POS.h = nil, nil, nil, nil
drawPicker()
check(POS.x == 660 + math.floor((600 - POS.w) / 2),
    "полоса наказаний не по центру окна репорта: x=" .. tostring(POS.x) .. " w=" .. tostring(POS.w))
check(POS.x >= 660 and POS.x + POS.w <= 660 + 600,
    "полоса наказаний вылезла за окно репорта")
check(POS.y == 300 + 260 + 10, "полоса не под нижней кромкой окна: " .. tostring(POS.y))
HPRINT(("полоса: окно 660…1260, полоса %s…%s (по центру), y=%s")
    :format(tostring(POS.x), tostring(POS.x + POS.w), tostring(POS.y)))

-- ===== 12. тестовый режим: команда уходит в /n, окно репорта закрывается =====
check(P.pickOpen == true, "полоса закрылась сама")
CLICK = { ["##grnd_qr_pun_q_1"] = true }
drawPicker()
CLICK = {}
check(#CHAT == 1 and CHAT[1] == "/n /mute 25 60 флуд в чате",
    "в /n ушло не то: " .. tostring(CHAT[1]))
check(TOASTS[#TOASTS]:find("/mute 25 60", 1, true) ~= nil, "тост не показал команду")
check(GRND_REP.open == false, "после наказания окно репорта не закрылось")
check(P.pickOpen == false, "полоса наказаний не закрылась")
HPRINT("тестовый режим: «" .. CHAT[1] .. "», окно репорта закрыто")

-- ===== 13. реальный ID: подстановка {ид} в причине =====
P.items[3] = { id = 9, name = "Бан", text = "Бан", cmd = "ban", time = "7", reason = "читы, ID {ид}" }
GRND_REP.open = true
GRND_REP.playerId = "77"
P.pickOpen = true
CLICK = { ["##grnd_qr_pun_q_9"] = true }
drawPicker()
CLICK = {}
check(CHAT[#CHAT] == "/n /ban 77 7 читы, ID 77",
    "подстановки в команде не сработали: " .. tostring(CHAT[#CHAT]))
HPRINT("подстановки: «" .. CHAT[#CHAT] .. "»")
P.items[3] = nil
setPunItems()

-- ===== 14. боевой режим: команда как есть + ответ игроку =====
GRND_REP.open = true
GRND_REP.playerId = "25"
Q.mode = "ans"
P.pickOpen = true
CLICK = { ["##grnd_qr_pun_q_1"] = true }
drawPicker()
CLICK = {}
check(CHAT[#CHAT] == "/mute 25 60 флуд в чате", "боевая команда ушла неверно: " .. tostring(CHAT[#CHAT]))
check(#ANS == 1 and ANS[1] == "25|Приветствую, мут за флуд",
    "игроку ушёл не тот ответ: " .. tostring(ANS[1]))
check(GRND_REP.open == false, "в боевом режиме окно репорта не закрылось")
HPRINT("боевой режим: «" .. CHAT[#CHAT] .. "» + ответ игроку")

-- ===== 15. режим «в поле ответа»: текст в поле, команда в /n, окно открыто =====
GRND_REP.open = true
GRND_REP.answer = { v = "" }
Q.mode = "input"
P.pickOpen = true
CLICK = { ["##grnd_qr_pun_q_1"] = true }
drawPicker()
CLICK = {}
check(GRND_REP.answer.v == "Приветствую, мут за флуд",
    "текст не вставился в поле ответа: " .. tostring(GRND_REP.answer.v))
check(CHAT[#CHAT] == "/n /mute 25 60 флуд в чате", "в режиме «в поле» команда ушла не в /n")
check(GRND_REP.open == true, "в режиме «в поле ответа» окно репорта закрывать нельзя")
HPRINT("режим «в поле ответа»: текст в поле, команда в /n, окно открыто")
GRND_REP.answer = nil
Q.mode = "test"

-- ===== 16. шаблонов нет: полоса не открывается, тост правильный =====
P.items = {}
check(Q.openPunPicker() == false, "полоса открылась без шаблонов")
check(TOASTS[#TOASTS]:find("Наказания", 1, true) ~= nil, "тост не зовёт в раздел «Наказания»")
HPRINT("без шаблонов: «" .. TOASTS[#TOASTS] .. "»")
setPunItems()

-- ===== 17. нет ID игрока: команда не уходит, полоса остаётся =====
GRND_REP.open = true
GRND_REP.playerId = "—"
P.pickOpen = true
local before = #CHAT
CLICK = { ["##grnd_qr_pun_q_1"] = true }
drawPicker()
CLICK = {}
check(#CHAT == before, "команда ушла без ID игрока: " .. tostring(CHAT[#CHAT]))
check(TOASTS[#TOASTS]:find("ID игрока не распознан", 1, true) ~= nil, "нет предупреждения про ID")
check(GRND_REP.open == true, "окно репорта закрылось, хотя наказание не ушло")
HPRINT("без ID: «" .. TOASTS[#TOASTS] .. "», окно осталось открытым")

-- ===== 18. полосы «ответы» и «наказания» не показываются вместе =====
GRND_REP.playerId = "25"
Q.pickOpen = true
check(Q.openPunPicker() == true, "полоса наказаний не открылась")
check(Q.pickOpen == false, "полоса быстрых ответов осталась висеть рядом")
check(Q.openPicker() == true, "полоса быстрых ответов не открылась")
check(P.pickOpen == false, "полоса наказаний осталась висеть рядом")
HPRINT("полосы не дублируются: открыта всегда одна")

-- ===== 19. ESC закрывает сначала список команд, потом полосу =====
P.comboOpen = true
P.pickOpen = true
check(_G.grndQrOnEsc() == true and P.comboOpen == false, "ESC не закрыл список команд")
check(_G.grndQrOnEsc() == true and P.pickOpen == false, "ESC не закрыл полосу наказаний")
HPRINT("ESC: список команд → полоса наказаний")

HPRINT("ALL PUNISH SCENARIOS PASSED")
