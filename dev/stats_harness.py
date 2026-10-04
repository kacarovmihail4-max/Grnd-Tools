# -*- coding: utf-8 -*-
"""Собирает стенд окна /stats: настоящий модуль 14 + заглушки игры."""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/stats_harness.lua'
src = io.open(SRC, encoding='utf-8').read()

start = src.index('function grndStatsCopy(t)')        # утилита прямо перед модулем
end = src.index('--  ТРАССИРОВЩИК', start)
module = src[start:end]
# модуль кончается закрывающим `end` блока do … end — обрезаем хвост
module = module[:module.rindex('\nend') + len('\nend')]


def read(name):
    return io.open(os.path.join(HERE, name), encoding='utf-8').read()


io.open(OUT, 'w', encoding='utf-8').write(
    read('stats_stub.lua') + '\n'
    + 'local MODULE_SRC = [=====[\n' + module + '\n]=====]\n'
    + 'local chunk = assert(load(MODULE_SRC, "stats_module"))\n'
    + 'chunk()\n'
    + read('stats_body.lua'))
print('стенд собран: %s (%d строк модуля)' % (OUT, module.count('\n') + 1))
