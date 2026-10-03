# -*- coding: utf-8 -*-
"""Стенд движка настроек GRND_CONFIG: домены, запись, чтение, числа, кириллица.

Грузит НАСТОЯЩИЙ блок GRND_CONFIG из скрипта (строки 75…519) и работает с ним
как игра: пишет секции, делает flush в файл, читает обратно, проверяет
«Unknown configuration domain» для незаявленного файла.
"""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/cfg_harness.lua'
src = io.open(SRC, encoding='utf-8').read()
start = src.index('GRND_CONFIG = {schema=1, sources={')
end = src.index('\nend\n', src.index('function C.flush()')) + len('\nend\n')
block = src[start:end]
def read(name): return io.open(os.path.join(HERE, name), encoding='utf-8').read()
io.open(OUT, 'w', encoding='utf-8').write(
    read('cfg_stub.lua') + '\n'
    + 'local CFG_SRC = [=====[\n' + block + '\n]=====]\n'
    + 'local chunk = assert(load(CFG_SRC, "grnd_config"))\n'
    + 'chunk()\n'
    + read('cfg_body.lua'))
print('стенд собран: %s' % OUT)
