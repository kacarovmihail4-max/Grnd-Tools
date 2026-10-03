# -*- coding: utf-8 -*-
"""Прогон Lua-стенда (lupa)."""
import sys, lupa
path = sys.argv[1]
src = open(path, encoding='utf-8').read()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
try:
    print('RESULT: %s' % lua.execute(src))
except Exception as e:
    print('RESULT: False')
    print('ERROR: %s' % e)
