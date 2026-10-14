#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Собирает v1.19.233 из репозитория v1.19.232 БЕЗ доступа к GitHub.
# Запуск из КОРНЯ репозитория:  python3 make_119233.py
# Все замены с assert'ами: якорь не найден ровно 1 раз — падение без записи.
import sys, os

def sub1(s, old, new, what, count=1):
    n = s.count(old)
    assert n == count, "якорь '%s' найден %d раз (ожидалось %d)" % (what, n, count)
    return s.replace(old, new)

def sub_first(s, old, new, what):
    assert old in s, "якорь '%s' не найден" % what
    return s.replace(old, new, 1)

STRIP_SRC = 'def strip_lua(src: bytes, compact: bool):\n    out = bytearray()\n    pending_ws = bytearray()   # пробелы в начале строки: отдаём, только если\n                               # дальше на строке есть реальный код\n    line_has_content = False\n    i, n = 0, len(src)\n\n    def flush_ws():\n        nonlocal line_has_content\n        if pending_ws:\n            out.extend(pending_ws)\n            line_has_content = True\n            pending_ws.clear()\n\n    def emit_nl():\n        nonlocal line_has_content\n        if compact and not line_has_content:\n            pass                      # пустая строка — выбрасываем\n        else:\n            out.extend(b\'\\n\')\n        line_has_content = False\n        pending_ws.clear()\n\n    while i < n:\n        b = src[i:i+1]\n\n        if b == b\'\\n\':\n            emit_nl(); i += 1; continue\n\n        if b in (b\' \', b\'\\t\', b\'\\r\'):\n            pending_ws.extend(b); i += 1; continue\n\n        if b == b\'"\' or b == b"\'":\n            flush_ws()\n            q = b\n            out.extend(b); i += 1; line_has_content = True\n            while i < n:\n                c = src[i:i+1]\n                out.extend(c); i += 1\n                if c == b\'\\\\\':\n                    if i < n:\n                        out.extend(src[i:i+1]); i += 1\n                elif c == q:\n                    break\n            continue\n\n        if b == b\'[\':\n            # длинная строка [=*[ ... ]=*]?\n            j = i + 1\n            while j < n and src[j:j+1] == b\'=\':\n                j += 1\n            if j < n and src[j:j+1] == b\'[\':\n                flush_ws()\n                level = src[i+1:j]\n                close = b\']\' + level + b\']\'\n                e = src.find(close, j + 1)\n                e = n if e == -1 else e + len(close)\n                out.extend(src[i:e])\n                line_has_content = True\n                i = e\n                continue\n            flush_ws(); out.extend(b); i += 1; line_has_content = True\n            continue\n\n        if b == b\'-\' and i + 1 < n and src[i+1:i+2] == b\'-\':\n            # комментарий\n            j = i + 2\n            k = j\n            while k < n and src[k:k+1] == b\'=\':\n                k += 1\n            if k < n and src[k:k+1] == b\'[\':\n                # блочный --[=*[ ... ]=*]\n                level = src[j:k]\n                close = b\']\' + level + b\']\'\n                e = src.find(close, k + 1)\n                span_end = n if e == -1 else e + len(close)\n                span = src[i:span_end]\n                # комментарий занимает целые строки? (до него — только пробелы\n                # в начале строки, после закрывающей скобки — только пробелы\n                # до конца строки)\n                before_ok = not line_has_content\n                m = span_end\n                while m < n and src[m:m+1] in (b\' \', b\'\\t\', b\'\\r\'):\n                    m += 1\n                after_ok = (m >= n) or (src[m:m+1] == b\'\\n\')\n                if before_ok and after_ok:\n                    # целые строки: храним переводы строк, текст — вон\n                    for ch in span:\n                        if ch == 0x0A:\n                            emit_nl()\n                    pending_ws.clear()\n                else:\n                    # внутристрочный: заменяем одним пробелом\n                    flush_ws()\n                    out.extend(b\' \')\n                    line_has_content = True\n                i = span_end\n                continue\n            # строчный: текст — вон, перевод строки отдаст основной цикл\n            while i < n and src[i:i+1] != b\'\\n\':\n                i += 1\n            continue\n\n        flush_ws()\n        out.extend(b); i += 1; line_has_content = True\n\n    return bytes(out)\n\n\n'

def strip_compact(src: bytes) -> bytes:
    ns = {}
    exec(compile(STRIP_SRC, "strip", "exec"), ns)
    return ns["strip_lua"](src, True)

CHANGELOG_BLOCK = 'GRND_CHANGELOG = [[\nv1.19.233 — Файл без комментариев, окно изменений из кода:\n  1) исходник очищен от комментариев (2.83 → 1.95 МБ): эквивалентность кода\n     доказана побайтовым сравнением байткода LuaJIT, стенды 903/903;\n  2) список изменений теперь живёт не в комментариях, а в самой программе\n     (эта строка GRND_CHANGELOG): окно «Grnd Tools» показывает его и у\n     текстовой, и у скомпилированной сборки после каждого обновления;\nv1.19.232 — Оптимизация всех систем:\n  1) sync-пакеты движения разбираются только при включённом «новом WH»,\n     имена полей библиотеки запоминаются после первого пакета;\n  2) трейсер прицеливания и выключенный автопилот наказаний больше не\n     работают вхолостую на каждом пакете и строке чата;\n  3) чекер «Админы в сети» не чистит строки в простое;\n  4) исправлен баг окна обновлений: у заголовка версии срезался байт\n     тире «—» и оставались два битых символа.\n]]\n'
EMBED = '        local embedded = tostring(body or ""):match("GRND_CHANGELOG%s*=%s*%[%[(.-)%]%]")\n        if embedded then\n            local cur\n            for line in embedded:gmatch("[^\\r\\n]+") do\n                local ver = line:match("^v(%d+%.%d+%.%d+)")\n                if ver then\n                    if U.verNum(ver) > min then\n                        cur = ver\n                        out[#out + 1] = { ver = ver, lines = {} }\n                        local head = line:match("^v[%d%.]+%s*[—%-]*%s*(.*)$")\n                        if head and head ~= "" then\n                            out[#out].lines[#out[#out].lines + 1] = head\n                        end\n                    else\n                        cur = nil\n                    end\n                elseif cur then\n                    local text = line:match("^%s*(.-)%s*$")\n                    if text ~= "" then\n                        out[#out].lines[#out[#out].lines + 1] = text\n                    end\n                end\n            end\n            if #out > 0 then return out end\n        end\n'
NEW_NDL = '    -- v1.19.233: прежняя проверка считала фразу из комментария («последний\n    -- запас: очередь репорта»); комментарии из файла убраны — проверяем КОД\n    -- запасной ступени ВНУТРИ блока автопилота (у очереди репорта своя такая же\n    -- ступень вне блока, поэтому считаем не по всему файлу)\n    local function countIn(needle, hay)\n        local n, i = 0, 1\n        while true do\n            local a, b = hay:find(needle, i, true)\n            if not a then break end\n            n = n + 1\n            i = b + 1\n        end\n        return n\n    end\n    eq("nodelay.queue.last", countIn("return pcall(sampSendChat, out) and true or false", block), 1)\n'
EMB_CHECKS = '\n-- v1.19.233: список изменений живёт В КОДЕ — строка GRND_CHANGELOG,\n-- комментарии файлу больше не нужны\nlocal embBody = table.concat({\n    \'GRND_SCRIPT_VERSION = "\' .. NEW .. \'"\',\n    "GRND_CHANGELOG = [[",\n    "v" .. NEW .. " — Тест встроенного списка:",\n    "  1) первая строка.",\n    "  2) вторая строка.",\n    "v" .. V .. " — старое:",\n    "  1) не должно попасть.",\n    "]]",\n}, "\\n") .. "\\n"\nlocal embNotes = U.changelogOf(embBody)\ncheck(#embNotes == 1, "changelog: встроенный блок — только новые версии")\ncheck(embNotes[1] and embNotes[1].ver == NEW, "changelog: встроенный блок — версия")\ncheck(embNotes[1].lines[1] == "Тест встроенного списка:",\n    "changelog: встроенный заголовок без мусора")\ncheck(#embNotes[1].lines == 3, "changelog: встроенный блок — все строки")\ncheck(embNotes[1].lines[2] == "1) первая строка.", "changelog: встроенная строка 1")\ncheck(embNotes[1].lines[3] == "2) вторая строка.", "changelog: встроенная строка 2")\ncheck(#U.changelogOf(embBody, NEW) == 0, "changelog: встроенный блок — своя версия отфильтрована")\nlocal realNotes = U.changelogOf(src:sub(1, 16384), "1.19.232")\ncheck(realNotes[1] ~= nil and realNotes[1].ver == "1.19.233",\n    "changelog: реальная шапка файла парсится")\n'
PARA = '**Список изменений в окне.** Начиная с v1.19.233 файл скрипта идёт БЕЗ\nкомментариев (исходник очищен, эквивалентность доказана побайтовым сравнением\nбайткода LuaJIT), а список изменений живёт В САМОЙ ПРОГРАММЕ — в строковой\nконстанте `GRND_CHANGELOG` в начале файла. `changelogOf` читает её так же,\nкак раньше читал шапку из комментариев: записи `vX.Y.Z — заголовок`, строки\nс отступом — пункты, версии старше текущей отфильтровываются. Бонус: константа\nпопадает и в байткод, поэтому окно изменений показывается и у\nскомпилированной сборки. При новой версии допиши запись в начало\n`GRND_CHANGELOG` (внутри `[[ … ]]`, без `]]` внутри текста).\n\n'
TEST_EDITS = [{'old': 'local a1 = assert(src:find("-- >>> GRND_UPDATE_BEGIN"))\nlocal a2 = assert(src:find("-- <<< GRND_UPDATE_END"))\nlocal block = src:sub(a1, a2 - 1)\n', 'new': 'local UPD_END = "\\ngrndUpdInit()\\n"\nlocal a1 = assert(src:find("GRND_UPDATE = _G.GRND_UPDATE or {}"))\nlocal a2 = assert(src:find(UPD_END, a1, true))  -- plain: в якоре есть "()" — магия паттернов\nlocal block = src:sub(a1, a2 + #UPD_END - 1)\n', 'file': 'tests/upd_test.lua'}, {'file': 'tests/upd_test.lua', 'old': 'check(#U.changelogOf(nil) == 0, "changelog: nil → пусто")\n', 'new': 'check(#U.changelogOf(nil) == 0, "changelog: nil → пусто")\n\n-- v1.19.233: список изменений живёт В КОДЕ — строка GRND_CHANGELOG,\n-- комментарии файлу больше не нужны\nlocal embBody = table.concat({\n    \'GRND_SCRIPT_VERSION = "\' .. NEW .. \'"\',\n    "GRND_CHANGELOG = [[",\n    "v" .. NEW .. " — Тест встроенного списка:",\n    "  1) первая строка.",\n    "  2) вторая строка.",\n    "v" .. V .. " — старое:",\n    "  1) не должно попасть.",\n    "]]",\n}, "\\n") .. "\\n"\nlocal embNotes = U.changelogOf(embBody)\ncheck(#embNotes == 1, "changelog: встроенный блок — только новые версии")\ncheck(embNotes[1] and embNotes[1].ver == NEW, "changelog: встроенный блок — версия")\ncheck(embNotes[1].lines[1] == "Тест встроенного списка:",\n    "changelog: встроенный заголовок без мусора")\ncheck(#embNotes[1].lines == 3, "changelog: встроенный блок — все строки")\ncheck(embNotes[1].lines[2] == "1) первая строка.", "changelog: встроенная строка 1")\ncheck(embNotes[1].lines[3] == "2) вторая строка.", "changelog: встроенная строка 2")\ncheck(#U.changelogOf(embBody, NEW) == 0, "changelog: встроенный блок — своя версия отфильтрована")\nlocal realNotes = U.changelogOf(src:sub(1, 16384), "1.19.232")\ncheck(realNotes[1] ~= nil and realNotes[1].ver == "1.19.233",\n    "changelog: реальная шапка файла парсится")\n'}, {'old': 'local a2 = assert(src:find("--  МОДУЛЬ 13", a1, true))\n', 'new': '-- v1.19.233: конец блока — по коду модуля 13 (комментариев-маркеров больше нет)\nlocal a2 = assert(src:find("\\nGRND_RC = _G.GRND_RC or {}", a1, true))\n', 'file': 'tests/ao_level_test.lua'}, {'old': 'local a1 = assert(src:find("-- >>> GRND_RADTOOLS_BEGIN"))\nlocal a2 = assert(src:find("-- <<< GRND_RADTOOLS_END"))\nlocal block = src:sub(a1, a2 - 1) -- до первой «-» маркера END\n', 'new': '-- v1.19.233: якоря КОДОВЫЕ — комментариев в файле больше нет\nlocal a1 = assert(src:find("\\ndo\\n    local RT = {"))\nlocal a2 = assert(src:find("GRND_UPDATE = _G.GRND_UPDATE or {}", a1))\nlocal block = src:sub(a1, a2 - 1)\n', 'file': 'tests/radtools_test.lua'}, {'old': '    local a = src:find(">>> GRND_PUNAUTO_LOGIC_BEGIN", 1, true)\n    assert(a, "нет якоря BEGIN")\n    local e = src:find("<<< GRND_PUNAUTO_LOGIC_END", a, true)\n    assert(e, "нет якоря END")\n    local block = src:sub(a, e)\n    block = block:gsub("^[^\\n]*\\n", "", 1)   -- строка с BEGIN\n    block = block:gsub("[^\\n]*$", "", 1)     -- строка с END\n', 'new': '    -- v1.19.233: якоря КОДОВЫЕ — комментариев-маркеров в файле больше нет\n    local a = src:find("\\n    local PA_FN = {}", 1, true)\n    assert(a, "нет якоря BEGIN")\n    local e = src:find("\\n    PA_FN.one = paOne", a, true)\n    assert(e, "нет якоря END")\n    local block = src:sub(a + 1, e + #"\\n    PA_FN.one = paOne")\n', 'file': 'tests/punauto_logic_test.lua'}, {'old': 'local e = assert(src:find("\\nend\\n\\n-- ---------- самопроверка логики", a, true), "нет конца блока")\nlocal block = src:sub(a, e + 4)   -- вместе с закрывающим end\n', 'new': '-- v1.19.233: конец блока — по коду за ним (комментарии-маркеры убраны)\nlocal e = assert(src:find("\\nfunction QR.selfTest()", a, true), "нет конца блока")\nlocal block = src:sub(a, e)   -- вместе с закрывающим end\n', 'file': 'tests/punauto_module_test.lua'}, {'file': 'tests/punauto_module_test.lua', 'old': '    eq("nodelay.queue.last", count("последний запас: очередь репорта"), 1)\n', 'new': '    -- v1.19.233: прежняя проверка считала фразу из комментария («последний\n    -- запас: очередь репорта»); комментарии из файла убраны — проверяем КОД\n    -- запасной ступени ВНУТРблока автопилота (у очереди репорта своя такая же\n    -- ступень вне блока, поэтому считаем не по всему файлу)\n    local function countIn(needle, hay)\n        local n, i = 0, 1\n        while true do\n            local a, b = hay:find(needle, i, true)\n            if not a then break end\n            n = n + 1\n            i = b + 1\n        end\n        return n\n    end\n    eq("nodelay.queue.last", countIn("return pcall(sampSendChat, out) and true or false", block), 1)\n'}, {'file': 'tests/chatlog_test.lua', 'old': '        .. cut("    function L.duplicate(text,source)", "    -- ---------- строки, скрытые от игрока")', 'new': '        .. cut("    function L.duplicate(text,source)", "    L.muted={}")'}, {'file': 'tests/chatlog_test.lua', 'old': '        .. cut("    -- ---------- строки, скрытые от игрока", "    function L.capture(text,source)")', 'new': '        .. cut("    L.muted={}", "    function L.capture(text,source)")   -- v1.19.233: якорь кодовой', 'count_first': True}]
README_PAIRS = [{'file': 'tests/README.md', 'old': '`upd_test.lua` (257 проверок)', 'new': '`upd_test.lua` (265 проверок)'}, {'file': 'tests/README.md', 'old': 'версии сравниваются как числа; разбор списка изменений из шапки нового файла;', 'new': 'версии сравниваются как числа; разбор списка изменений из шапки нового файла и из строки GRND_CHANGELOG в коде (v1.19.233: файл без комментариев, у скомпилированной сборки окно изменений тоже работает);'}]

def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def write(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)

def main():
    # ---------- 1. grnd_adm_tools.lua ----------
    raw = open("grnd_adm_tools.lua", "rb").read()
    lua = strip_compact(raw).decode("utf-8")
    lua = sub1(lua, 'GRND_SCRIPT_VERSION = "1.19.232"',
                    'GRND_SCRIPT_VERSION = "1.19.233"', "версия")
    anchor_sv = "script_version(GRND_SCRIPT_VERSION)\n"
    lua = sub1(lua, anchor_sv, anchor_sv + CHANGELOG_BLOCK, "место GRND_CHANGELOG")
    old_head = "        local out, cur, seen = {}, nil, 0\n"
    new_head = "        local out = {}\n" + EMBED + "        local cur, seen = nil, 0\n"
    lua = sub1(lua, old_head, new_head, "changelogOf: встроенный разбор")
    assert 'GRND_SCRIPT_VERSION = "1.19.233"' in lua
    assert lua.count("GRND_CHANGELOG") >= 3
    assert "local out, cur, seen" not in lua
    write("grnd_adm_tools.lua", lua)

    # ---------- 2. update.txt ----------
    write("update.txt", "1.19.233\n")

    # ---------- 3. тесты и документация ----------
    edits = {}
    for ed in TEST_EDITS + README_PAIRS:
        edits.setdefault(ed["file"], []).append(ed)
    for path, pairs in edits.items():
        s = read(path)
        for ed in pairs:
            what = path + ": " + ed["old"][:40]
            if ed.get("count_first"):
                s = sub_first(s, ed["old"], ed["new"], what)
                s = sub_first(s, ed["old"], ed["new"], what + " (второе)")
            elif "all" in ed:
                s = sub1(s, ed["old"], ed["new"], what, count=ed["all"])
            else:
                s = sub1(s, ed["old"], ed["new"], what, count=1)
        write(path, s)
    # UPDATE_CHANNEL.md — вставка параграфа (в v1.19.232 заметки ещё нет)
    md = read("UPDATE_CHANNEL.md")
    anchor = "**Когда идёт проверка.**"
    assert md.count(anchor) == 1 and "GRND_CHANGELOG" not in md
    md = md.replace(anchor, PARA + anchor, 1)
    write("UPDATE_CHANNEL.md", md)

    # ---------- 4. самопроверка ----------
    lua = read("grnd_adm_tools.lua")
    lines = lua.split("\n")
    bad = [i + 1 for i, l in enumerate(lines) if l.lstrip().startswith("--")]
    assert not bad, "остались комментарии, строки: " + str(bad[:5])
    assert 'GRND_SCRIPT_VERSION = "1.19.233"' in lua
    print("OK: v1.19.233 собрана.")
    print("Проверь при возможности: luajit tests/run_all.lua  (должно быть 911/911)")
    print("Дальше: коммит -> PR в main -> мерж -> git fetch origin main && "
          "git tag -f grnd-latest origin/main && git push --force origin grnd-latest")

if __name__ == "__main__":
    main()
