# -*- coding: utf-8 -*-
"""Собирает стенд «новый WH» (v1.19.72): настоящий модуль WH из скрипта
(GRND_WH + do … end) и заглушки игры.

  python3 wh_harness.py ../grnd_adm_tools.lua /tmp/wh_stand.lua
  python3 run_lua.py /tmp/wh_stand.lua
"""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/wh_stand.lua'
src = io.open(SRC, encoding='utf-8').read()

start = src.index('GRND_WH={enabled=false')
end = src.index('-- Batch punishment logic adapted from Turbo Punisher', start)
module = src[start:end]
# модуль закрывается `end` блока do … end — хвост обрезаем
module = module[:module.rindex('\nend') + len('\nend')]

read = lambda n: io.open(os.path.join(HERE, n), encoding='utf-8').read()
io.open(OUT, 'w', encoding='utf-8').write(
    read('wh_stub.lua') + '\n'
    + 'local MODULE_SRC = [=====[\n' + module + '\n]=====]\n'
    + 'local chunk = assert(load(MODULE_SRC, "wh_module"))\n'
    + 'chunk()\n'
    + read('wh_body.lua'))
print('стенд собран: %s (%d строк модуля WH)' % (OUT, module.count('\n') + 1))
