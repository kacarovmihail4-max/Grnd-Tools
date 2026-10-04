# -*- coding: utf-8 -*-
"""Собирает стенд чекеров: (1) гейт «чекер под окном» — берётся ЖИВОЙ текст
блока из скрипта; (2) настоящие функции работы с мышью (клик только ЛКМ)."""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/checker_harness.lua'
src = io.open(SRC, encoding='utf-8').read()


def grab(name):
    """Вырезает функцию верхнего уровня: от `function name` до `end` в нулевой колонке."""
    start = src.index('function ' + name)
    stop = src.index('\nend\n', start) + len('\nend\n')
    return src[start:stop]


parts = [grab('grndClickAlive'), grab('grndLeftClickPending'), grab('grndMouseFrameBegin'),
         grab('grndCheckerRectOk'), grab('grndCheckerCovers'), grab('grndCheckerPointTaken'),
         grab('grndCheckerBandTaken'), grab('grndCheckerClipRect')]

# реальная разметка кнопки-источника и кадра из onWindowMessage (WM_*BUTTON*)
start = src.index('    if msgN == 0x0201 then')
stop = src.index('    GRND_MOUSE.at = os.clock()', start)
wm_flags = src[start:stop].rstrip() + '\n'
stamp_start = src.index('    if isMouse and not isDown and not isUp then', stop)
stamp_stop = src.index('\n', src.index('GRND_MOUSE.frame = GRND_UIFRAME + 1', stamp_start)) + 1
stamp_end = src.index('\n    end\n', stamp_stop) + len('\n    end\n')
wm_stamp = src[stamp_start:stamp_end]
assert 'clickedBtn = 1' in wm_flags and 'rclickedBtn = 2' in wm_flags and 'mclickedBtn = 3' in wm_flags
assert 'GRND_MOUSE.frame = GRND_UIFRAME + 1' in wm_stamp
assert '[====[' not in wm_flags + wm_stamp and ']====]' not in wm_flags + wm_stamp
wm_lua = ('function grndWmMouseFlags(msgN, lparam)\n' + wm_flags + 'end\n'
          'function grndWmMouseStamp(isMouse, isDown, isUp, msgN)\n' + wm_stamp + 'end\n')

# гейт «чекер под окном»: от объявления до конца блока (перед отрисовкой килл-листа)
start = src.index('local checkersHidden = false')
stop = src.index('-- МОДУЛЬ 11 (v1.5): килл-лист (чекер №1)')
gate_src = src[start:stop].rstrip() + '\nreturn checkersHidden\n'
assert 'local list = {' in gate_src and 'for i = 1, #list do' in gate_src
assert '[====[' not in gate_src and ']====]' not in gate_src
gate_lua = 'local gateSrc = [====[\n' + gate_src + ']====]\nlocal grndGate = assert(load(gateSrc, "gate"))\n'


def read(name):
    return io.open(os.path.join(HERE, name), encoding='utf-8').read()


io.open(OUT, 'w', encoding='utf-8').write(
    read('checker_stub.lua') + '\n'
    + '\n'.join(parts) + '\n'
    + wm_lua + '\n'
    + gate_lua + '\n'
    + read('checker_body.lua'))
print('стенд собран: %s (%d функций + гейт)' % (OUT, len(parts)))
