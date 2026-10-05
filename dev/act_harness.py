# -*- coding: utf-8 -*-
"""Собирает стенд компактной панели действий (r69/v1.19.69).

Берём из скрипта ЖИВОЙ код: список действий P.actions, хелперы значков и
раскладки (grndActIconKey/grndActGroupOf/grndActLayout/грндDrawActIcon),
настоящий grndMouseInside и сам блок отрисовки панели. Остальное — заглушки
ImGui/мыши/чата из act_stub.lua, сценарии — act_body.lua.
"""
import io, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/h_act.lua'
src = io.open(SRC, encoding='utf-8').read()


def block_end(src, start, what=''):
    """Возвращает позицию конца Lua-блока (первый `end` на нулевой глубине)."""
    i, n, depth = start, len(src), 0
    line_start = True
    first = True
    while i < n:
        c = src[i]
        if c == '\n':
            i += 1
            line_start = True
            continue
        if c == '-' and src[i:i + 2] == '--':
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '"' or c == chr(39):
            q = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if c.isalpha() or c == '_':
            j = i
            while j < n and (src[j].isalnum() or src[j] == '_'):
                j += 1
            w = src[i:j]
            indented = not line_start
            if w in ('if', 'for', 'while', 'function'):
                depth += 1
            elif w == 'do':
                if depth > 0 or True:
                    # `for/while ... do`: do не добавляет уровень
                    prev = src[max(0, i - 240):i]
                    if not ('for' in prev.split('\n')[-1] or 'while' in prev.split('\n')[-1]):
                        depth += 1
            elif w == 'end':
                depth -= 1
                if depth == 0 and not indented and not first:
                    return j
            first = False
            i = j
            continue
        line_start = line_start and c in ' \t'
        i += 1
    raise ValueError('не найден конец блока ' + what)


def cut(a, b, what):
    i = src.index(a)
    j = src.index(b, i) + len(b)
    return src[i:j]


# 1) настоящий список действий
i = src.index('    P.actions = {')
j = src.index('\n    }', i) + len('\n    }')
actions = src[i + len('    P.actions = '):j]

# 2) настоящие хелперы значков/раскладки
_h1 = src.index('function grndActLower(t)')
_g1 = src.index('function _G.grndDrawActIcon(')
helpers = src[_h1:block_end(src, _g1, 'grndDrawActIcon')] + '\n'

# 3) настоящий grndMouseInside
_m1 = src.index('function grndMouseInside(r)')
_m2 = src.index('\nend\n', _m1) + len('\nend\n')
mouse = src[_m1:_m2]

# 4) настоящие помощники и диспетчер действий (никаких «подделок» логики)
c1 = src.index('function grndRcClampHp(value)')
c2 = src.index('\nend\n', c1) + len('\nend\n')
clamp = src[c1:c2]

v1 = src.index('function _G.grndGetTargetVehId(tid, ped)')
veh = src[v1:block_end(src, v1, 'grndGetTargetVehId')] + '\n'

d1 = src.index('function _G.grndHandleActionBtn(cleanLabel, tid, tNick, targetPed)')
handle = src[d1:block_end(src, d1, 'grndHandleActionBtn')] + '\n'

# настоящая отрисовка подпанелей (ползунки ХП/брони/топлива, /a) — целиком
s1 = src.index('function _G.grndDrawActSubPopup(RC, TH,')
subpopup = src[s1:block_end(src, s1, 'grndDrawActSubPopup')] + '\n'

# 5) сам блок отрисовки панели
# охватываем и «предохранители» панели, стоящие прямо перед её отрисовкой
# якорь без номера версии: комментарий «если цель слежки сменилась» стоит
# прямо перед «предохранителями» панели — берём с начала этой строки
_mi = src.index('если цель слежки сменилась')
p1 = src.rindex('\n', 0, _mi) + 1
p2 = src.index('            return (RC.cursor or RC.actionsWinOpen) and true or false')
panel = src[p1:p2]

read = lambda n: io.open(os.path.join(HERE, n), encoding='utf-8').read()
io.open(OUT, 'w', encoding='utf-8').write(
    'ACTIONS_LIST = ' + actions + '\n'
    + read('act_stub.lua') + '\n'
    + mouse + '\n'
    + clamp + '\n'
    + veh + '\n'
    + handle + '\n'
    + subpopup + '\n'
    + helpers + '\n'
    # блок панели в скрипте живёт внутри более широкой конструкции —
    # его последний `end` принадлежит ей; в стенде её роль играет `if RC.cursor then`
    + 'function runPanelFn()\n    if true then -- блок, в который панель вложена в drawRecon\n'
      + panel + 'end\n'
+ read('act_body.lua'))
print('стенд собран: %s (%d байт панели)' % (OUT, len(panel)))
