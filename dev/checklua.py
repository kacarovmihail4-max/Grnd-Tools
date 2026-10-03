# -*- coding: utf-8 -*-
"""Синтаксическая проверка Lua-файла (Lua 5.4 через lupa)."""
import sys, lupa
path = sys.argv[1]
src = open(path, encoding='utf-8').read()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
res = lua.eval('function(src, name) local f, err = load(src, name); '
               'if f == nil then return false, tostring(err) end return true, "" end')(src, path)
if not res[0]:
    print('SYNTAX ERROR: %s' % res[1])
    sys.exit(1)
print('OK: compiles cleanly')
