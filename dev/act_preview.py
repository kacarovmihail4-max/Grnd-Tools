# -*- coding: utf-8 -*-
"""Превью полосы действий (v1.19.70) без игры.

Значки НЕ переписываются в питоне: из скрипта выделяются настоящие функции
таблицы ACT_ICONS, исполняются в lupa с «записывающей» обвязкой H — и на
экране ровно то, что нарисует игра. Так превью не расходится со скриптом.

  python3 act_preview.py ../grnd_adm_tools.lua /tmp/act_panel.png
"""
import io, os, sys

from PIL import Image, ImageDraw, ImageFont
import lupa

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/act_panel.png'
src = io.open(SRC, encoding='utf-8').read()

# --- настоящие значки + список действий + раскладка из скрипта ---------------
i = src.index('function grndActLower(t)')
j = src.index('function _G.grndDrawActIcon(')
icons_and_keys = src[i:j]
i = src.index('    P.actions = {')
j = src.index('\n    }', i) + len('\n    }')
actions = src[i:j].replace('    P.actions = ', 'ACTIONS = ')

lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
RECORDS = {}
local function mk(kind)
    return function(...)
        local a = { ... }
        RECORDS[#RECORDS + 1] = { kind = kind, a = a }
    end
end
H_RECORD = {
    l = mk("l"), r = mk("r"), ro = mk("ro"),
    rr = mk("rr"), rro = mk("rro"), t = mk("t"),
    c = mk("c"), co = mk("co"),
}
''')
# ACT_ICONS — локальная таблица скрипта: чтобы она была видна снаружи, в том же
# чанке выкладываем её в глобальное имя
lua.execute(icons_and_keys + '\nACT_ICONS_EXPORT = ACT_ICONS\n')
lua.execute(actions)

labels = [str(x) for x in lua.globals().ACTIONS.values()]
keys = [str(lua.globals().grndActIconKey(l)) for l in labels]


def record(key):
    # зовём ТУ ЖЕ функцию значка, что лежит в скрипте, с записывающей обвязкой
    lua.execute('RECORDS = {} ACT_ICONS_EXPORT[%r](H_RECORD)' % key)
    out = []
    for r in lua.globals().RECORDS.values():
        out.append((str(r['kind']), [float(x) for x in r['a'].values()]))
    return out


# --- раскладка: та же функция, что в скрипте --------------------------------
resx = 1920
lo = lua.eval('function(items, maxW) return grndActLayout(items, maxW) end')(
    lua.table(*labels), min(resx - 24, 880))
BTN = int(lo['btn'])
GAP = int(lo['gap'])
PAD = int(lo['pad'])
AW = int(lo['w'])
stripH = int(lo['stripH'])
PILL = BTN + 12
HINT = 22
panel_w = AW + 16
panel_h = HINT + stripH + 2

rows = [dict(x=int(r['x']), y=int(r['y']), w=int(r['w']),
             btn=[dict(i=int(b['i']), x=int(b['x'])) for b in r['btns'].values()],
             div=[float(d) for d in r['divs'].values()])
        for r in lo['rows'].values()]
print('раскладка: значки %d px, панель %dx%d, рядов: %d' % (BTN, panel_w, panel_h, len(rows)))

# --- картинка ---------------------------------------------------------------
SCALE = 3
W, H = panel_w * SCALE, panel_h * SCALE
img = Image.new('RGB', (W, H), (26, 30, 36))
d = ImageDraw.Draw(img, 'RGBA')


def draw_icon(key, cx, cy, size, col):
    s = size / 2.0
    k = s / 10.0            # толщина линий в игре — пиксели при значке 20 px

    def px(u):
        return cx + u * s

    def py(v):
        return cy + v * s

    for kind, a in record(key):
        if kind == 'l':
            d.line([px(a[0]), py(a[1]), px(a[2]), py(a[3])], fill=col,
                   width=max(1, round((a[4] if len(a) > 4 else 1.5) * k)))
        elif kind == 'r':
            d.rectangle([px(a[0]), py(a[1]), px(a[0] + a[2]), py(a[1] + a[3])], fill=col)
        elif kind in ('ro', 'rro'):
            d.rounded_rectangle([px(a[0]), py(a[1]), px(a[0] + a[2]), py(a[1] + a[3])],
                                radius=(a[4] if len(a) > 4 else 0) * s, outline=col,
                                width=max(1, round((a[5] if len(a) > 5 else 1.5) * k)))
        elif kind == 'rr':
            d.rounded_rectangle([px(a[0]), py(a[1]), px(a[0] + a[2]), py(a[1] + a[3])],
                                radius=(a[4] if len(a) > 4 else 0) * s, fill=col)
        elif kind == 't':
            d.polygon([px(a[0]), py(a[1]), px(a[2]), py(a[3]), px(a[4]), py(a[5])], fill=col)
        elif kind == 'c':
            r = a[2] * s
            d.ellipse([px(a[0]) - r, py(a[1]) - r, px(a[0]) + r, py(a[1]) + r], fill=col)
        elif kind == 'co':
            r = a[2] * s
            d.ellipse([px(a[0]) - r, py(a[1]) - r, px(a[0]) + r, py(a[1]) + r],
                      outline=col, width=max(1, round((a[3] if len(a) > 3 else 1.5) * k)))


# подложка-«таблетка» как в скрипте: тень + тёмная плашка + рамка
for row in rows:
    ry = (HINT + row['y']) * SCALE
    d.rounded_rectangle([(row['x'] + 2) * SCALE, ry + 3 * SCALE,
                         (row['x'] + row['w'] + 2) * SCALE, ry + (PILL + 3) * SCALE],
                        radius=12 * SCALE, fill=(0, 0, 0, 65))
    d.rounded_rectangle([row['x'] * SCALE, ry, (row['x'] + row['w']) * SCALE, ry + PILL * SCALE],
                        radius=12 * SCALE, fill=(10, 14, 20, 255), outline=(58, 63, 72), width=2)
    for dx in row['div']:
        d.line([dx * SCALE, ry + 8 * SCALE, dx * SCALE, ry + (PILL - 8) * SCALE],
               fill=(255, 255, 255, 74), width=max(1, round(1.2 * SCALE)))
    for b in row['btn']:
        bx = b['x'] * SCALE
        by = ry + 5 * SCALE
        d.rounded_rectangle([bx, by, bx + BTN * SCALE, by + BTN * SCALE],
                            radius=8 * SCALE, fill=(255, 255, 255, 11),
                            outline=(255, 255, 255, 16), width=1)
        draw_icon(keys[b['i'] - 1], bx + BTN * SCALE / 2, by + BTN * SCALE / 2,
                  (BTN - 10) * SCALE, (206, 214, 228))

try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
    font_small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 12)
except Exception:
    font = ImageFont.load_default()
    font_small = font

d.text((10, 8), 'Полоса действий (v1.19.70) — значки %d px, панель %dx%d: без шапки, ника и крестика'
       % (BTN - 12, panel_w, panel_h), fill=(230, 235, 245), font=font)
d.text((10, 32), 'Разделители групп — светлые черты ровно в зазоре; промежутки между значками одинаковые',
       fill=(150, 160, 175), font=font_small)

# --- легенда ----------------------------------------------------------------
legend_top = H + 12
cols = 3
rows_n = (len(labels) + cols - 1) // cols
LW = max(W, 1060)
img2 = Image.new('RGB', (LW, legend_top + rows_n * 36 + 30), (26, 30, 36))
img2.paste(img, (0, 0))
d2 = ImageDraw.Draw(img2, 'RGBA')
col_w = LW // cols
for i, label in enumerate(labels):
    cx = 20 + (i // rows_n) * col_w
    cy = legend_top + (i % rows_n) * 36 + 18
    draw_icon(keys[i], cx + 12, cy, 24, (206, 214, 228))
    d2.text((cx + 36, cy - 9), label, fill=(220, 226, 236), font=font)

img2.save(OUT)
print('превью: %s (%dx%d)' % (OUT, img2.size[0], img2.size[1]))
