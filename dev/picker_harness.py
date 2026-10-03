# -*- coding: utf-8 -*-
"""Собирает стенд полосы шаблонов: настоящий модуль «Быстрые ответы» + заглушки ImGui."""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/picker_harness.lua'
src = io.open(SRC, encoding='utf-8').read()
start = src.index('_G.GRND_QR = (function()')
end = src.index('return QR\nend)()', start) + len('return QR\nend)()')
def read(name): return io.open(os.path.join(HERE, name), encoding='utf-8').read()
io.open(OUT, 'w', encoding='utf-8').write(
    read('picker_stub.lua') + '\n'
    + 'local MODULE_SRC = [=====[\n' + src[start:end] + '\n]=====]\n'
    + 'local chunk = assert(load(MODULE_SRC, "qr_module"))\n'
    + 'chunk()\n'
    + read('picker_body.lua'))
print('стенд собран: %s' % OUT)
