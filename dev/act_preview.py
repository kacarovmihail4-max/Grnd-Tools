# -*- coding: utf-8 -*-
"""Рисует превью полосы действий (v1.19.69) без игры.

Значки берутся ИЗ САМОГО СКРИПТА: парсим таблицу ACT_ICONS и повторяем те же
примитивы (линия, прямоугольник, круг, треугольник) в картинке. Нужно, чтобы
посмотреть на панель глазами до запуска игры.

  python3 act_preview.py ../grnd_adm_tools.lua /tmp/act_panel.png
"""
import io, os, re, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/act_panel.png'
src = io.open(SRC, encoding='utf-8').read()

# --- список действий -------------------------------------------------------
i = src.index('    P.actions = {')
j = src.index('\n    }', i)
labels = re.findall(r'"([^"]+)"', src[i:j])

# --- значки из скрипта -----------------------------------------------------
i = src.index('local ACT_ICONS = {')
j = src.index('\n}\n', i)
icons_src = src[i:j]
icons = {}
for m in re.finditer(r'\n\s*(\w+) = function\(H\)(.*?)\n    end,', icons_src, re.S):
    name, body = m.group(1), m.group(2)
    shapes = []
    for call in re.finditer(r'H\.(l|r|ro|t|c|co)\(([^)]*)\)', body):
        kind, args = call.group(1), [a.strip() for a in call.group(2).split(',')]
        nums = []
        for a in args:
            try:
                nums.append(float(a))
            except ValueError:
                nums.append(None)
        shapes.append((kind, nums))
    icons[name] = shapes

# --- порядок значков как в скрипте (по смыслу названия) --------------------
def icon_key(label):
    """Повторяет grndActIconKey для наших 19 названий."""
    order = [('хп', 'hp'), ('брон', 'arm'), ('подброс', 'slap')]
    s = label.lower()
    for need, key in order:
        if need in s:
            return key
    if 'т/с' in s:
        if 'почин' in s:
            return 'fixcar'
        if 'перевер' in s:
            return 'flipcar'
        if 'заправ' in s:
            return 'fuel'
        if 'спавн' in s:
            return 'spawncar'
        return 'car'
    if 'размороз' in s:
        return 'unfreeze'
    if 'замороз' in s:
        return 'freeze'
    if 'спавн' in s:
        return 'spawn'
    if 'тп' in s or 'дорог' in s:
        if 'дорог' in s:
            return 'tproad'
        if 'к себе' in s:
            return 'tphere'
        return 'tpgo'
    if 'отобрать' in s:
        return 'rgun'
    if 'оруж' in s:
        return 'weap'
    if 'стат' in s:
        return 'stats'
    if 'наказ' in s:
        return 'punish'
    if 'лиценз' in s:
        return 'lic'
    if 'сообщ' in s:
        return 'admin'
    return 'dot'


def group_of(label):
    k = icon_key(label)
    if k in ('hp', 'arm'):
        return 1
    if k in ('slap', 'spawn', 'freeze', 'unfreeze'):
        return 2
    if k in ('fixcar', 'flipcar', 'fuel', 'spawncar', 'car'):
        return 3
    if k in ('tproad', 'tpgo', 'tphere'):
        return 4
    if k in ('weap', 'rgun'):
        return 5
    return 6


BTN, GAP, PAD, DIV = 32, 3, 8, 9
SCALE = 3          # превью в 3 раза крупнее панели в игре
W, H = 739 * SCALE, 66 * SCALE
img = Image.new('RGB', (W, H), (26, 30, 36))
d = ImageDraw.Draw(img, 'RGBA')


def pill(x, y, w, h, fill, radius, outline=None):
    d.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=fill, outline=outline, width=1)


def draw_icon(key, cx, cy, size, col):
    """Повторяет отрисовку значка из скрипта.

    Толщина линий в игре задаётся в пикселях ImGui (1.4–2.2 px) при значке 20 px,
    поэтому в превью она масштабируется вместе с размером (s/10 — «полраза» значка).
    """
    sh = icons.get(key) or icons.get('dot') or []
    s = size / 2.0
    k = s / 10.0

    def px(u):
        return cx + u * s

    def py(v):
        return cy + v * s

    for kind, a in sh:
        if kind == 'l':
            d.line([px(a[0]), py(a[1]), px(a[2]), py(a[3])], fill=col,
                   width=max(1, round((a[4] or 1.5) * k)))
        elif kind == 'r':
            d.rectangle([px(a[0]), py(a[1]), px(a[0] + a[2]), py(a[1] + a[3])], fill=col)
        elif kind == 'ro':
            d.rounded_rectangle([px(a[0]), py(a[1]), px(a[0] + a[2]), py(a[1] + a[3])],
                                radius=(a[4] or 0) * s, outline=col,
                                width=max(1, round((a[5] or 1.5) * k)))
        elif kind == 't':
            d.polygon([px(a[0]), py(a[1]), px(a[2]), py(a[3]), px(a[4]), py(a[5])], fill=col)
        elif kind == 'c':
            r = a[2] * s
            d.ellipse([px(a[0]) - r, py(a[1]) - r, px(a[0]) + r, py(a[1]) + r], fill=col)
        elif kind == 'co':
            r = a[2] * s
            d.ellipse([px(a[0]) - r, py(a[1]) - r, px(a[0]) + r, py(a[1]) + r],
                      outline=col, width=max(1, round((a[3] or 1.5) * k)))


# --- сама панель -----------------------------------------------------------
row_w = PAD * 2 + len(labels) * BTN + (len(labels) - 1) * GAP
for k in range(2, len(labels) + 1):
    if group_of(labels[k - 1]) != group_of(labels[k - 2]):
        row_w += DIV
row_w *= 1
x0 = (W - row_w * SCALE) // 2
y0 = 22 * SCALE

pill(x0 + 2 * SCALE, y0 + 3 * SCALE, row_w * SCALE, (BTN + 10) * SCALE, (0, 0, 0, 65), 12 * SCALE)
pill(x0, y0, row_w * SCALE, (BTN + 10) * SCALE, (10, 14, 20, 255), 12 * SCALE, (58, 63, 72))

x = x0 + PAD * SCALE
for k, label in enumerate(labels):
    if k > 0 and group_of(label) != group_of(labels[k - 1]):
        d.line([x + DIV * SCALE // 2, y0 + 9 * SCALE, x + DIV * SCALE // 2,
                y0 + (BTN + 1) * SCALE], fill=(58, 63, 72), width=2)
        x += DIV * SCALE
    draw_icon(icon_key(label), x + BTN * SCALE / 2, y0 + 5 * SCALE + BTN * SCALE / 2,
              (BTN - 12) * SCALE, (206, 214, 228))
    x += (BTN + GAP) * SCALE

try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
    font_small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 12)
except Exception:
    font = ImageFont.load_default()
    font_small = font

d.text((10, 8), 'Полоса действий (v1.19.69) — как это выглядит в игре: 739x66 px, '
                'без шапки, ника и крестика', fill=(230, 235, 245), font=font)
d.text((10, 30), 'Название действия всплывает подсказкой над значком при наведении',
       fill=(150, 160, 175), font=font_small)

# --- легенда: значок + название -------------------------------------------
legend_top = H + 10
cols = 3
rows = (len(labels) + cols - 1) // cols
LW = max(W, 1060)
img2 = Image.new('RGB', (LW, legend_top + rows * 34 + 16), (26, 30, 36))
img2.paste(img, (0, 0))
d2 = ImageDraw.Draw(img2, 'RGBA')
col_w = LW // cols
for k, label in enumerate(labels):
    cx = 20 + (k // rows) * col_w
    cy = legend_top + (k % rows) * 34 + 16
    draw_icon(icon_key(label), cx + 12, cy, 22, (206, 214, 228))
    d2.text((cx + 34, cy - 8), label, fill=(220, 226, 236), font=font)

img2.save(OUT)
print('превью: %s (%dx%d, значков: %d)' % (OUT, img2.size[0], img2.size[1], len(labels)))
