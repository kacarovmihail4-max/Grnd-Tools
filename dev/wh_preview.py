# -*- coding: utf-8 -*-
"""Превью табличек нового WH (v1.19.72) без игры.

Раскладку считает НАСТОЯЩАЯ функция скрипта (`W.drawLabel`): мы лишь
подсовываем ей измеритель текста на шрифте DejaVuSans (как это делает
DX-шрифт в игре) и записываем всё, что она отправила бы в renderDrawBox /
renderFontDrawText. На экране — ровно то, что нарисует игра.

  python3 wh_preview.py ../grnd_adm_tools.lua /tmp/wh_preview.png
"""
import io, os, re, sys

from PIL import Image, ImageDraw, ImageFont
import lupa

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'grnd_adm_tools.lua')
OUT = sys.argv[2] if len(sys.argv) > 2 else '/tmp/wh_preview.png'
src = io.open(SRC, encoding='utf-8').read()
read = lambda n: io.open(os.path.join(HERE, n), encoding='utf-8').read()

# --- настоящий модуль WH ----------------------------------------------------
start = src.index('GRND_WH={enabled=false')
end = src.index('-- Batch punishment logic adapted from Turbo Punisher', start)
module = src[start:end]
module = module[:module.rindex('\nend') + len('\nend')]

FONT_PATH = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
_fonts = {}


def pil_font(px):
    px = max(6, int(round(px)))
    f = _fonts.get(px)
    if f is None:
        try:
            f = ImageFont.truetype(FONT_PATH, px)
        except Exception:
            f = ImageFont.load_default()
        _fonts[px] = f
    return f


def measure(text, px):
    """Ширина строки — как её измерит DX-шрифт того же кегля."""
    try:
        return float(pil_font(px).getlength(str(text)))
    except Exception:
        return len(str(text)) * px * 0.55


lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.globals().PYMEASURE = measure
lua.execute(read('wh_stub.lua'))
# в стенде ширину мерил грубый «#str * px * 0.55»; для превью берём метрики
# настоящего шрифта — и для раскладки, и для отрисовки
lua.execute('''
function renderGetFontDrawTextLength(font, str)
    return PYMEASURE(tostring(str), (font and font.px) or 13)
end
''')
lua.execute('local MODULE_SRC = [=====[\n' + module + '\n]=====]\nload(MODULE_SRC, "wh_module")()')
W = lua.globals().GRND_WH

# --- сцена: несколько игроков, табличка — над головой -----------------------
CASES = [
    dict(nick='Greshnik_delaet', family='[SB] STRELKI', lvl=5, id=57,
         hp=100, armor=0, known=True, scale=1, ground=700, cap='Семья и LVL из окна статистики'),
    dict(nick='Kolya_Petrov', family='[TM] TAMBOV', lvl=12, id=88,
         hp=62, armor=47, known=True, scale=1, ground=620, cap='HP 62%, броня 47% — полосы сжимаются'),
    dict(nick='Vasya_Pupkin', family=None, lvl=None, id=99,
         hp=100, armor=0, known=True, scale=1, ground=540, cap='Статистика есть, семьи нет'),
    dict(nick='Novichok', family=None, lvl=None, id=45,
         hp=100, armor=0, known=False, scale=1, ground=460, cap='Статистику ещё не запрашивали'),
]

lua.execute('T.resetCalls()')
shots = []
for case in CASES:
    d = {k: case[k] for k in ('nick', 'family', 'lvl', 'id', 'hp', 'armor', 'known', 'scale')}
    h = float(lua.eval('function(dd) return GRND_WH.labelHeight(dd) end')(lua.table_from(d)))
    lua.execute('T.resetCalls()')
    lua.eval('function(dd, top) return GRND_WH.drawLabel(%d, top, dd, {}) end'
             % 0)(lua.table_from(d), 0)  # прогреваем шрифты/кэш
    lua.execute('T.resetCalls()')
    lua.eval('function(dd, top) return GRND_WH.drawLabel(%d, top, dd, {}) end'
             % 0)(lua.table_from(d), 0)
    calls = []
    for r in lua.globals().T.calls.values():
        args = [x for x in r['a'].values()]
        calls.append((str(r['kind']), args))
    shots.append((case, h, calls))

print('табличек: %d; высоты: %s' % (len(shots), ', '.join('%.0f' % s[1] for s in shots)))

# --- картинка ---------------------------------------------------------------
SCALE = 1
SW, SH = 1920, 1080
img = Image.new('RGB', (SW, SH), (24, 26, 30))
d = ImageDraw.Draw(img, 'RGBA')

# фон — ночная улица: асфальт, бордюр, фонарь
d.rectangle([0, 0, SW, SH], fill=(22, 26, 32))
d.rectangle([0, 620, SW, SH], fill=(31, 33, 37))
d.rectangle([0, 612, SW, 622], fill=(52, 54, 58))
for x in range(0, SW, 160):
    d.rectangle([x + 60, 850, x + 130, 862], fill=(66, 68, 72))
d.ellipse([-260, 40, 620, 560], fill=(58, 62, 72))
d.text((SW - 520, 26), 'новый WH v1.19.72 — таблички над игроками',
       fill=(226, 232, 242), font=pil_font(24))
d.text((SW - 520, 60), 'слева направо: как выглядит в игре (1:1), ниже — увеличение 2x',
       fill=(150, 160, 175), font=pil_font(15))


def argb_to_rgba(c):
    c = int(c) & 0xFFFFFFFF
    a = (c >> 24) & 0xFF
    r = (c >> 16) & 0xFF
    g = (c >> 8) & 0xFF
    b = c & 0xFF
    return (r, g, b, a)


def figure(cx, ground, h=250):
    """Простая фигурка игрока, чтобы табличка стояла над головой."""
    dk = (38, 40, 46, 255)
    head = h * 0.16
    d.ellipse([cx - head * 0.42, ground - h, cx + head * 0.42, ground - h + head * 0.86], fill=(52, 54, 60, 255))
    d.rounded_rectangle([cx - h * 0.13, ground - h + head * 0.86, cx + h * 0.13, ground - h * 0.42],
                        radius=8, fill=dk)
    d.rounded_rectangle([cx - h * 0.17, ground - h + head * 0.92, cx - h * 0.12, ground - h * 0.42],
                        radius=6, fill=dk)
    d.rounded_rectangle([cx + h * 0.12, ground - h + head * 0.92, cx + h * 0.17, ground - h * 0.42],
                        radius=6, fill=dk)
    d.rounded_rectangle([cx - h * 0.10, ground - h * 0.44, cx - h * 0.02, ground],
                        radius=6, fill=(30, 32, 38, 255))
    d.rounded_rectangle([cx + h * 0.02, ground - h * 0.44, cx + h * 0.10, ground],
                        radius=6, fill=(30, 32, 38, 255))
    return ground - h + head * 0.86 - 16        # «верх головы»


def replay(calls, ox, oy, k=1.0):
    for kind, a in calls:
        if kind == 'box':
            x, y, w, h, col = a
            d.rectangle([ox + x * k, oy + y * k, ox + (x + w) * k - 1, oy + (y + h) * k - 1],
                        fill=argb_to_rgba(col))
        elif kind == 'text':
            s, x, y, col = a[0], a[1], a[2], a[3]
            px = a[4] if len(a) > 4 else 13
            f = pil_font(px * (k if k < 3 else 3))
            d.text((ox + x * k, oy + y * k), str(s), fill=argb_to_rgba(col), font=f, anchor='la')


for (case, h, calls), cx in zip(shots, (260, 700, 1180, 1620)):
    head_top = figure(cx, case['ground'])
    top = head_top - h - 6
    replay(calls, cx, top, 1.0)
    d.text((cx - 130, case['ground'] + 14), case['cap'], fill=(160, 170, 185), font=pil_font(15))

# --- увеличение 2x двух самых важных табличек -------------------------------
panel_x, panel_y, panel_w = 60, 780, 1800
d.rounded_rectangle([panel_x - 16, panel_y - 46, panel_x + panel_w, panel_y + 250],
                    radius=10, fill=(14, 16, 20, 235), outline=(60, 66, 76), width=2)
d.text((panel_x, panel_y - 36), 'увеличение 2x: ник → семья → HP → ID + LVL',
       fill=(226, 232, 242), font=pil_font(17))
for idx, cx0 in ((0, panel_x + 150), (1, panel_x + 620)):
    case, h, calls = shots[idx]
    replay(calls, cx0, panel_y + 8, 2.0)
    d.text((cx0 + 230, panel_y + 8), case['cap'], fill=(160, 170, 185), font=pil_font(15))
    d.text((cx0 + 230, panel_y + 30), 'высота таблички — %.0f px' % h,
           fill=(130, 140, 155), font=pil_font(14))

_ver = re.search(r'GRND_SCRIPT_VERSION = "([\d.]+)"', src)
d.text((panel_x + panel_w - 220, panel_y + 226), 'версия скрипта %s' % (_ver.group(1) if _ver else '?'),
       fill=(140, 150, 165), font=pil_font(14))

img.save(OUT)
print('превью: %s (%dx%d)' % (OUT, img.size[0], img.size[1]))
