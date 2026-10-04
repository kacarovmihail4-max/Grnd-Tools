# -*- coding: utf-8 -*-
"""Собирает стенд карточки рекона: настоящая отрисовка карточки + заглушки ImGui."""
import io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/card_harness.lua'
src = io.open(SRC, encoding='utf-8').read()

start = src.index('            local W = math.floor(math.max(400, math.min(460, resX * 0.28)))')
endmark = '            grndPopCol(colorN)'
end = src.index(endmark, start) + len(endmark)
card = src[start:end]
# кусок начинается с отступа в 12 пробелов: убираем его, чтобы чанк читался
card = '\n'.join(line[12:] if line.startswith(' ' * 12) else line for line in card.split('\n'))

def read(name):
    return io.open(os.path.join(HERE, name), encoding='utf-8').read()


io.open(OUT, 'w', encoding='utf-8').write(
    read('card_stub.lua') + '\n'
    + 'local CARD_SRC = [=====[\n' + card + '\n]=====]\n'
    + 'local cardDraw = assert(load(CARD_SRC, "card_chunk"))\n'
    + 'CARD = cardDraw\n'
    + read('card_body.lua'))
print('стенд собран: %s (%d строк карточки)' % (OUT, card.count('\n') + 1))
