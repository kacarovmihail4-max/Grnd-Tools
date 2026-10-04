# -*- coding: utf-8 -*-
"""Собирает стенд скорости: настоящие хелперы сглаживания + замер по игре."""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/speed_harness.lua'
src = io.open(SRC, encoding='utf-8').read()
start = src.index('GRND_PARAM_CACHE = _G.GRND_PARAM_CACHE or {}')
end = src.index('GRND_WEAPON_NAMES = {', start)


def read(name):
    return io.open(os.path.join(HERE, name), encoding='utf-8').read()


io.open(OUT, 'w', encoding='utf-8').write(
    read('speed_stub.lua') + '\n'
    + 'local MODULE_SRC = [=====[\n' + src[start:end] + '\n]=====]\n'
    + 'local chunk = assert(load(MODULE_SRC, "speed_module"))\n'
    + 'chunk()\n'
    + read('speed_body.lua'))
print('стенд собран: %s' % OUT)
