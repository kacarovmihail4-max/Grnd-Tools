# -*- coding: utf-8 -*-
"""Собирает стенд антизалипания клавиш: настоящий блок из скрипта + заглушки ввода."""
import io, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/sticky_harness.lua'
src = io.open(SRC, encoding='utf-8').read()

START = '-- >>> АНТИЗАЛИПАНИЕ: НАЧАЛО БЛОКА'
END = '-- <<< АНТИЗАЛИПАНИЕ: КОНЕЦ БЛОКА'
start = src.index(START)
end = src.index(END) + len(END)
module_src = src[start:end]

def read(name):
    return io.open(os.path.join(HERE, name), encoding='utf-8').read()

io.open(OUT, 'w', encoding='utf-8').write(
    read('sticky_stub.lua') + '\n'
    + 'local MODULE_SRC = [=====[\n' + module_src + '\n]=====]\n'
    + 'local chunk = assert(load(MODULE_SRC, "sticky_module"))\n'
    + 'chunk()\n'
    + read('sticky_body.lua'))
print('стенд собран: %s' % OUT)
