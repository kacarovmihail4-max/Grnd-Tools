# -*- coding: utf-8 -*-
"""Собирает стенд панели: настоящий модуль МП + настоящая кнопка окна + заглушки ImGui."""
import io, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/panel_harness.lua'
src = io.open(SRC, encoding='utf-8').read()

start = src.index('_G.MP = (function()')
end = src.index('-- <<< ПАНЕЛЬ МП: КОНЕЦ БЛОКА')
end = src.index('end)()', end) + len('end)()')

# настоящая кнопка окна (grndUiButton) — панель вызывает её через _G
bstart = src.index('function grndUiButton(ctx, id, x, y, w, h, label, opts)')
bend = src.index('\nend\n', bstart) + len('\nend\n')
module_src = src[bstart:bend] + '\n' + src[start:end]

def read(name):
    return io.open(os.path.join(HERE, name), encoding='utf-8').read()

io.open(OUT, 'w', encoding='utf-8').write(
    read('panel_stub.lua') + '\n'
    + 'local MODULE_SRC = [=====[\n' + module_src + '\n]=====]\n'
    + 'local chunk = assert(load(MODULE_SRC, "panel_module"))\n'
    + 'chunk()\n'
    + read('panel_body.lua'))
print('стенд собран: %s' % OUT)
