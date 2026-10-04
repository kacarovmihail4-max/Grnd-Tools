# -*- coding: utf-8 -*-
"""Собирает стенд модуля слежки: настоящий grndSpecNative + поддельная память."""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/spec_harness.lua'
src = io.open(SRC, encoding='utf-8').read()

start = src.index('grndSpecNative = {')
end = src.index('\nend\n', src.index('function S.getVehicleModel(vehId)', start)) + len('\nend\n')
module_src = src[start:end]


def read(name):
    return io.open(os.path.join(HERE, name), encoding='utf-8').read()


io.open(OUT, 'w', encoding='utf-8').write(
    read('spec_stub.lua') + '\n'
    + 'local MODULE_SRC = [=====[\n' + module_src + '\n]=====]\n'
    + 'local chunk = assert(load(MODULE_SRC, "spec_module"))\n'
    + 'chunk()\n'
    + read('spec_body.lua'))
print('стенд собран: %s' % OUT)
