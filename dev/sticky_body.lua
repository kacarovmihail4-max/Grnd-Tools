-- ---- стенд: антизалипание клавиш (v1.19.20) ----
local D = _G.grndStickyDebug
local S = _G.GRND_STICKY
local function check(c, m) if not c then error("ПРОВАЛ: " .. tostring(m), 2) end end
local function releasesNow() RELEASES = {}; return RELEASES end

check(type(D) == "table", "блок антизалипания не загрузился")
check(type(GRND_STICKY) == "table", "нет таблицы состояния GRND_STICKY")

-- ===== 1. «нажатие или отпускание»: отпускания игре отдаём =====
local P = D.press
check(P(0x0100) == true,  "WM_KEYDOWN должен считаться нажатием")
check(P(0x0104) == true,  "WM_SYSKEYDOWN должен считаться нажатием")
check(P(0x0101) == false, "WM_KEYUP должен уходить игре (иначе клавиша залипает)")
check(P(0x0105) == false, "WM_SYSKEYUP должен уходить игре")
check(P(0x0201) == true,  "WM_LBUTTONDOWN — нажатие")
check(P(0x0202) == false, "WM_LBUTTONUP должен уходить игре")
check(P(0x0204) == true,  "WM_RBUTTONDOWN — нажатие")
check(P(0x0205) == false, "WM_RBUTTONUP должен уходить игре")
check(P(0x0207) == true,  "WM_MBUTTONDOWN — нажатие")
check(P(0x0208) == false, "WM_MBUTTONUP должен уходить игре")
check(P(0x020B) == false, "WM_XBUTTONUP должен уходить игре")
check(P(0x0200) == true,  "WM_MOUSEMOVE при окне игре не отдаём")
check(P(0x020A) == true,  "колесо при окне игре не отдаём")
check(P(0x0102) == true,  "WM_CHAR не отдаём игре")
HPRINT("оконные сообщения: нажатия глушим, отпускания уходят игре")

-- ===== 2. окно владеет вводом, игрок ничего не держит =====
DOWN = {}
NOW = 10.0
GRND_UI_MOUSE.uiGuard = true
local calls = releasesNow()
local clearsBefore = S.clears
D.tick()
check(#calls == #D.game, "отпущены не все игровые клавиши: " .. tostring(#calls) .. " из " .. tostring(#D.game))
local allUp = true
for i = 1, #calls do
    if calls[i].state ~= 0 then allUp = false end
end
check(allUp, "игровые клавиши отпускаются не нулём (state ~= 0)")
check(S.clears == clearsBefore + 1, "счётчик снятых залипаний не увеличился")
check(S.reason == "окно", "причина сброса не «окно»: " .. tostring(S.reason))
HPRINT("окно открыто, рук на клавишах нет: отпущено " .. tostring(#calls) .. " игровых клавиш")

-- ===== 3. игрок что-то нажимает — не вмешиваемся =====
DOWN = { [0x57] = true }            -- держит W
NOW = NOW + 1.0
calls = releasesNow()
D.tick()
check(#calls == 0, "сброс сработал, хотя игрок держит W")
DOWN = { [0x01] = true }            -- держит ЛКМ
NOW = NOW + 1.0
calls = releasesNow()
D.tick()
check(#calls == 0, "сброс сработал, хотя игрок держит ЛКМ")
DOWN = {}
HPRINT("пока игрок держит клавишу или кнопку мыши — игровые клавиши не трогаем")

-- ===== 4. троттлинг: не чаще раза в 0.15 с =====
NOW = NOW + 1.0
calls = releasesNow()
D.tick()
check(#calls > 0, "сброс не сработал после отпускания клавиши")
calls = releasesNow()
NOW = NOW + 0.05
D.tick()
check(#calls == 0, "сброс сработал повторно в том же интервале (нет троттлинга)")
NOW = NOW + 0.25
D.tick()
check(#RELEASES > 0, "сброс не повторился после паузы")
HPRINT("повторный сброс — не чаще раза в 0.15 с")

-- ===== 5. окно закрыли: «хвост» 0.6 с ещё досматривает клавиши =====
GRND_UI_MOUSE.uiGuard = false
GRND_UI_MOUSE.active = false
GRND_UI_MOUSE.blockUntil = 0
NOW = NOW + 5.0                      -- пауза: хвост истёк
calls = releasesNow()
D.tick()
check(#calls == 0, "сброс сработал, когда окно давно закрыто")
GRND_UI_MOUSE.uiGuard = true         -- окно открыли...
NOW = NOW + 1.0
D.tick()
GRND_UI_MOUSE.uiGuard = false        -- ...и сразу закрыли
NOW = NOW + 0.3                      -- ещё внутри «хвоста»
calls = releasesNow()
D.tick()
check(#calls > 0, "в «хвосте» после закрытия окна клавиши не отпустились")
check(S.reason == "хвост", "причина сброса в «хвосте» не «хвост»: " .. tostring(S.reason))
NOW = NOW + 1.0                      -- хвост истёк
calls = releasesNow()
D.tick()
check(#calls == 0, "«хвост» длится дольше заявленного")
HPRINT("«хвост» после закрытия окна: 0.6 с досматривает клавиши, дальше молчит")

-- ===== 6. игра потеряла фокус (alt-tab) =====
GRND_CAM.windowFocused = false
NOW = NOW + 5.0
calls = releasesNow()
D.tick()
check(#calls > 0, "при потере фокуса залипшие клавиши не отпустились")
check(S.reason == "фокус", "причина сброса при потере фокуса не «фокус»: " .. tostring(S.reason))
GRND_CAM.windowFocused = true
HPRINT("потеря фокуса окна игры: сброс клавиш подписан причиной «фокус»")

-- ===== 7. ошибки и отсутствие нативных функций не роняют скрипт =====
NOW = NOW + 5.0
GRND_UI_MOUSE.uiGuard = true
DOWN = {}
KEY_ERROR = true
local okErr = pcall(D.tick)
check(okErr, "падение при ошибке setGameKeyState")
KEY_ERROR = false
local savedKeyDown = isKeyDown
isKeyDown = nil
local okNoKey = pcall(D.tick)
check(okNoKey, "падение, когда isKeyDown недоступен")
calls = releasesNow()
check(#calls == 0, "без isKeyDown игровые клавиши всё равно трогаем")
isKeyDown = savedKeyDown
local savedSet, savedGet = setGameKeyState, grndStickyDebug
setGameKeyState = nil
local okNoSet = pcall(D.tick)
check(okNoSet, "падение, когда setGameKeyState недоступен")
setGameKeyState = savedSet
GRND_UI_MOUSE.uiGuard = false
HPRINT("нет isKeyDown/setGameKeyState или ошибка вызова — тик просто молчит")

-- ===== 8. списки клавиш =====
check(#D.game >= 18, "в списке игровых клавиш меньше 18 записей: " .. tostring(#D.game))
local seen = {}
for i = 1, #D.game do
    local k = D.game[i]
    check(type(k) == "number" and k >= 0 and k <= 21, "подозрительный индекс игровой клавиши: " .. tostring(k))
    check(not seen[k], "игровая клавиша " .. tostring(k) .. " в списке дважды")
    seen[k] = true
end
-- движение (0/1), прыжок (14), спринт (16), огонь (17) — обязательны
for _, must in ipairs({ 0, 1, 14, 16, 17 }) do
    check(seen[must], "в списке нет игровой клавиши " .. tostring(must))
end
local phys = {}
for i = 1, #D.phys do phys[D.phys[i]] = true end
for _, vk in ipairs({ 0x57, 0x41, 0x53, 0x44, 0x20, 0x01, 0x02 }) do
    check(phys[vk], string.format("в списке «физических» клавиш нет 0x%02X", vk))
end
HPRINT("списки клавиш: " .. tostring(#D.game) .. " игровых, " .. tostring(#D.phys) .. " физических")

HPRINT("ALL STICKY SCENARIOS PASSED")
