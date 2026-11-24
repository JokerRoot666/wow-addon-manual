# -*- coding: utf-8 -*-
"""Генератор схем для руководства по аддонам WoW.

Запуск:
    python make_diagrams.py

Кладёт PNG в ../img/.
"""

import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "img"))
os.makedirs(OUT, exist_ok=True)

S = 2  # суперсэмплинг: рисуем в 2x, потом уменьшаем

INK = (17, 24, 39)
MUTED = (100, 116, 139)
LINE = (148, 163, 184)
BOX_BG = (248, 250, 252)
BOX_BD = (203, 213, 225)
ACC_BG = (238, 244, 255)
ACC_BD = (46, 107, 230)
ACC_TX = (30, 64, 175)
WARN_BG = (255, 247, 237)
WARN_BD = (217, 119, 6)
WARN_TX = (154, 52, 18)
OK_BG = (236, 253, 245)
OK_BD = (5, 150, 105)
OK_TX = (6, 95, 70)
CODE_BG = (17, 24, 39)
CODE_TX = (226, 232, 240)

FONT = "C:/Windows/Fonts/segoeui.ttf"
FONT_B = "C:/Windows/Fonts/segoeuib.ttf"
MONO = "C:/Windows/Fonts/consola.ttf"

_cache = {}


def f(size, bold=False, mono=False):
    key = (size, bold, mono)
    if key not in _cache:
        path = MONO if mono else (FONT_B if bold else FONT)
        _cache[key] = ImageFont.truetype(path, size * S)
    return _cache[key]


class Canvas:
    def __init__(self, w, h, bg=(255, 255, 255)):
        self.w, self.h = w, h
        self.im = Image.new("RGB", (w * S, h * S), bg)
        self.d = ImageDraw.Draw(self.im)

    # --- текст -----------------------------------------------------------
    def tw(self, text, font):
        box = self.d.textbbox((0, 0), text, font=font)
        return box[2] - box[0]

    def text(self, xy, text, size=22, bold=False, mono=False, color=INK, anchor="la"):
        self.d.text((xy[0] * S, xy[1] * S), text, font=f(size, bold, mono),
                    fill=color, anchor=anchor)

    def wrap(self, text, max_w, size=20, bold=False, mono=False):
        font = f(size, bold, mono)
        out, cur = [], ""
        for word in text.split():
            probe = (cur + " " + word).strip()
            if self.tw(probe, font) <= max_w * S or not cur:
                cur = probe
            else:
                out.append(cur)
                cur = word
        if cur:
            out.append(cur)
        return out

    def para(self, xy, text, max_w, size=20, color=MUTED, lh=1.45, bold=False, mono=False):
        x, y = xy
        for line in self.wrap(text, max_w, size, bold, mono):
            self.text((x, y), line, size, bold, mono, color)
            y += int(size * lh)
        return y

    def title(self, text, sub=None):
        self.text((50, 44), text, 34, True)
        if sub:
            self.text((50, 92), sub, 20, False, False, MUTED)

    # --- фигуры ----------------------------------------------------------
    def box(self, x, y, w, h, fill=BOX_BG, outline=BOX_BD, r=12, width=2, dash=False):
        if dash:
            self._dash_rect(x, y, w, h, outline)
            self.d.rounded_rectangle([x * S + 2, y * S + 2, (x + w) * S - 2, (y + h) * S - 2],
                                     radius=r * S, fill=fill)
        else:
            self.d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S],
                                     radius=r * S, fill=fill, outline=outline, width=width)

    def _dash_rect(self, x, y, w, h, color):
        step, seg = 16, 9
        for i in range(0, w, step):
            x2 = min(i + seg, w)
            self.d.line([(x + i) * S, y * S, (x + x2) * S, y * S], fill=color, width=2)
            self.d.line([(x + i) * S, (y + h) * S, (x + x2) * S, (y + h) * S], fill=color, width=2)
        for i in range(0, h, step):
            y2 = min(i + seg, h)
            self.d.line([x * S, (y + i) * S, x * S, (y + y2) * S], fill=color, width=2)
            self.d.line([(x + w) * S, (y + i) * S, (x + w) * S, (y + y2) * S], fill=color, width=2)

    def arrow(self, p1, p2, color=LINE, width=3, head=13):
        x1, y1 = p1
        x2, y2 = p2
        self.d.line([x1 * S, y1 * S, x2 * S, y2 * S], fill=color, width=width)
        import math
        ang = math.atan2(y2 - y1, x2 - x1)
        hx, hy = x2 * S, y2 * S
        pts = [
            (hx, hy),
            (hx - head * S * math.cos(ang - 0.42), hy - head * S * math.sin(ang - 0.42)),
            (hx - head * S * math.cos(ang + 0.42), hy - head * S * math.sin(ang + 0.42)),
        ]
        self.d.polygon(pts, fill=color)

    def code(self, x, y, lines, size=18, pad=16, title=None):
        w = max(self.tw(l, f(size, False, True)) for l in lines) / S + pad * 2
        h = len(lines) * size * 1.5 + pad * 2 + (26 if title else 0)
        self.d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S],
                                 radius=10 * S, fill=CODE_BG)
        yy = y + pad
        if title:
            self.text((x + pad, yy), title, 15, False, True, (148, 163, 184))
            yy += 26
        for l in lines:
            self.text((x + pad, yy), l, size, False, True, CODE_TX)
            yy += size * 1.5
        return w, h

    def codeblock(self, x, y, lines, size=16, color=INK, lh=1.55):
        for i, line in enumerate(lines):
            self.text((x, y + i * size * lh), line, size, False, True, color)
        return y + len(lines) * size * lh

    def save(self, name):
        im = self.im.resize((self.w, self.h), Image.LANCZOS)
        path = os.path.join(OUT, name)
        im.save(path, optimize=True)
        print("saved", path)


# ---------------------------------------------------------------------------
# 1. Папка аддона и порядок загрузки
# ---------------------------------------------------------------------------
def d_load():
    c = Canvas(1720, 700)
    c.title("Путь аддона: от папки до ADDON_LOADED",
            "Игра читает только то, что перечислено в .toc, — и строго сверху вниз")

    steps = [
        ("World of Warcraft", "_retail_", "папка установки\nклиента"),
        ("Interface", "AddOns", "сюда кладут\nаддоны"),
        ("МойАддон", "", "папка аддона:\nимя = имя аддона"),
        ("МойАддон.toc", "", "имя файла .toc\nсовпадает с папкой"),
        ("список файлов", "Core.lua, UI.lua …", "порядок строк\n= порядок загрузки"),
        ("ADDON_LOADED", "addonName", "файлы выполнены,\nаддон работает"),
    ]
    x, y, w, h, gap = 50, 200, 240, 130, 42
    for i, (t1, t2, cap) in enumerate(steps):
        accent = i in (2, 3, 5)
        fill, bd = (ACC_BG, ACC_BD) if accent else (BOX_BG, BOX_BD)
        tx = ACC_TX if accent else INK
        c.box(x, y, w, h, fill, bd)
        c.text((x + w / 2, y + 40), t1, 21, True, True, tx, "mm")
        if t2:
            c.text((x + w / 2, y + 70), t2, 17, False, True, MUTED, "mm")
        yy = y + h + 18
        for line in cap.split("\n"):
            c.text((x + w / 2, yy), line, 17, False, False, MUTED, "ma")
            yy += 24
        if i < len(steps) - 1:
            c.arrow((x + w + 6, y + h / 2), (x + w + gap - 6, y + h / 2))
        x += w + gap

    c.box(50, 470, 1620, 180, (255, 255, 255), BOX_BD)
    c.text((76, 496), "Что происходит внутри", 20, True)
    c.para((76, 528),
           "Клиент находит папку в AddOns, читает одноимённый .toc, выполняет перечисленные в нём "
           "файлы по порядку — каждый целиком, до следующего. Никакого автоматического поиска .lua по папке нет: "
           "файл, не упомянутый в .toc, не загрузится вообще. После выполнения всех файлов аддон получает событие "
           "ADDON_LOADED с собственным именем.", 1560, 20)
    c.save("01-load.png")


# ---------------------------------------------------------------------------
# 2. Жизненный цикл
# ---------------------------------------------------------------------------
def d_lifecycle():
    c = Canvas(1780, 820)
    c.title("Жизненный цикл аддона",
            "Порядок событий при входе в мир и при выходе; от него зависит, что где инициализировать")

    nodes = [
        ("файлы .toc", "выполняются\nодним проходом"),
        ("ADDON_LOADED", "arg1 = имя аддона;\nпо одному на аддон"),
        ("PLAYER_LOGIN", "персонаж вошёл"),
        ("PLAYER_ENTERING_WORLD", "isInitialLogin,\nisReloadingUi"),
        ("игра", "события, таймеры,\nобновление данных"),
        ("PLAYER_LOGOUT", "сохранение\nSavedVariables"),
    ]
    n = len(nodes)
    y_axis = 300
    x0, x1 = 90, 1690
    step = (x1 - x0) / (n - 1)
    c.d.line([x0 * S, y_axis * S, (x1 + 20) * S, y_axis * S], fill=LINE, width=3)
    c.arrow((x1 + 8, y_axis), (x1 + 40, y_axis))

    for i, (name, cap) in enumerate(nodes):
        x = x0 + i * step
        c.d.ellipse([(x - 9) * S, (y_axis - 9) * S, (x + 9) * S, (y_axis + 9) * S],
                    fill=ACC_BD, outline=(255, 255, 255), width=3)
        lines = name.split()
        yy = y_axis - 40 - 26 * len(lines)
        for l in lines:
            c.text((x, yy), l, 21, True, True, ACC_TX, "ma")
            yy += 26
        yy = y_axis + 26
        for l in cap.split("\n"):
            c.text((x, yy), l, 17, False, False, MUTED, "ma")
            yy += 23

    def bracket(x_from, x_to, y, label, color=ACC_BD, fill=ACC_BG, tx=ACC_TX):
        c.d.line([x_from * S, y * S, x_to * S, y * S], fill=color, width=3)
        for xx in (x_from, x_to):
            c.d.line([xx * S, y * S, xx * S, (y - 18) * S], fill=color, width=3)
        bw = c.tw(label, f(18)) / S + 34
        cx_ = (x_from + x_to) / 2
        c.d.rounded_rectangle([(cx_ - bw / 2) * S, (y + 14) * S, (cx_ + bw / 2) * S, (y + 60) * S],
                              radius=8 * S, fill=fill, outline=color, width=2)
        c.text((cx_, y + 37), label, 18, False, False, tx, "mm")

    bracket(x0 + step * 0.55, x0 + step * 1.9, 460,
            "SavedVariables уже на диске — доступны в ADDON_LOADED")
    bracket(x0 + step * 2.1, x0 + step * 3.6, 580,
            "игровой мир готов, юниты и карта читаются")
    bracket(x0 + step * 4.0, x0 + step * 4.9, 460,
            "запись базы на диск при выходе", OK_BD, OK_BG, OK_TX)

    c.box(50, 690, 1680, 100, WARN_BG, WARN_BD)
    c.text((76, 706), "Правило для стажёра", 19, True, False, WARN_TX)
    c.para((76, 736), "В ADDON_LOADED создавай своё (БД, окна, слэш-команды). В PLAYER_ENTERING_WORLD — то, "
                      "что требует готового игрового мира. Тяжёлые сканы не делай в обоих: сначала покажи окно.", 1620, 19, WARN_TX)
    c.save("02-lifecycle.png")


# ---------------------------------------------------------------------------
# 3. Дерево фреймов
# ---------------------------------------------------------------------------
def d_tree():
    c = Canvas(1500, 780)
    c.title("Дерево фреймов", "Фрейм — контейнер: у него есть родитель, дети, текстуры и шрифтстринги")

    c.box(50, 160, 660, 540, (255, 255, 255), LINE, dash=True)
    c.text((70, 176), "UIParent", 18, True, True, MUTED)

    c.box(80, 220, 600, 450, ACC_BG, ACC_BD)
    c.text((106, 240), "DropLedgerFrame", 22, True, True, ACC_TX)
    c.text((106, 272), "Frame, родитель — UIParent", 16, False, False, MUTED)

    kids = [
        ("Фон", "Texture, слой BACKGROUND"),
        ("Заголовок", "FontString, слой OVERLAY"),
        ("Кнопка", "Button + своя FontString"),
    ]
    y = 314
    for name, kind in kids:
        c.box(110, y, 540, 92)
        c.text((134, y + 18), name, 20, True)
        c.text((134, y + 50), kind, 16, False, False, MUTED)
        y += 112

    c.text((770, 200), "Три факта, которые экономят часы", 22, True)
    notes = [
        ("Родитель задаёт систему координат",
         "SetPoint считает смещение от родителя, а не от края экрана. Сдвинул окно — дети поехали вместе с ним."),
        ("Скрыл родителя — скрылись дети",
         "Show и Hide действуют на всё поддерево. Прятать каждую текстуру отдельно не нужно."),
        ("Имя фрейма — глобальная переменная",
         "Это второй аргумент CreateFrame. Давай имена только окнам и якорям для других аддонов, остальное — в локальные переменные."),
    ]
    y = 252
    for t, d in notes:
        c.text((770, y), t, 19, True)
        y = c.para((770, y + 32), d, 680, 17)
        y += 40

    c.box(50, 720, 1400, 44, WARN_BG, WARN_BD)
    c.text((70, 733), "Чем меньше глобальных имён, тем меньше шансов сломать чужой аддон и получить конфликт при загрузке.",
           16, False, False, WARN_TX)
    c.save("03-frame-tree.png")


# ---------------------------------------------------------------------------
# 4. Якоря
# ---------------------------------------------------------------------------
def d_anchors():
    c = Canvas(1560, 920)
    c.title("Якоря: SetPoint", "Позиция задаётся парой точек — своей и родительской — плюс смещением")

    px, py, pw, ph = 90, 230, 880, 400
    c.box(px, py, pw, ph, (252, 252, 253), BOX_BD)
    c.text((px + pw - 16, py + 14), "родитель", 18, False, False, MUTED, "ra")

    cx, cy, cw, ch = px + 70, py + 60, 300, 110
    c.box(cx, cy, cw, ch, ACC_BG, ACC_BD)
    c.text((cx + cw / 2, cy + ch / 2 - 10), "дочерний фрейм", 19, True, False, ACC_TX, "mm")
    c.text((cx + cw / 2, cy + ch / 2 + 16), "SetSize(300, 110)", 15, False, True, ACC_TX, "mm")

    pts = [
        ("TOPLEFT", px, py, 14, -30, "la"),
        ("TOP", px + pw / 2, py, 0, 28, "ma"),
        ("TOPRIGHT", px + pw, py, -14, -30, "ra"),
        ("LEFT", px, py + ph / 2, 14, -10, "la"),
        ("CENTER", px + pw / 2, py + ph / 2, 14, 22, "la"),
        ("RIGHT", px + pw, py + ph / 2, -14, -10, "ra"),
        ("BOTTOMLEFT", px, py + ph, 14, 26, "la"),
        ("BOTTOM", px + pw / 2, py + ph, 0, -28, "ma"),
        ("BOTTOMRIGHT", px + pw, py + ph, -14, 26, "ra"),
    ]
    for name, x, y, dx, dy, anchor in pts:
        c.d.ellipse([(x - 7) * S, (y - 7) * S, (x + 7) * S, (y + 7) * S], fill=ACC_BD)
        c.text((x + dx, y + dy), name, 17, True, True, ACC_TX, anchor)

    # выноски смещения
    c.d.line([px * S, (py + 60) * S, (px + 70) * S, (py + 60) * S], fill=(217, 119, 6), width=2)
    c.text((px + 35, py + 40), "x = +70", 16, False, True, (154, 52, 18), "ma")
    c.d.line([px * S, py * S, px * S, (py + 60) * S], fill=(217, 119, 6), width=2)
    c.text((px - 6, py + 24), "y = -60", 16, False, True, (154, 52, 18), "ra")
    c.d.line([(px + 1) * S, (py + 1) * S, (px + 69) * S, (py + 59) * S], fill=(253, 230, 200), width=2)

    c.text((1030, 210), "Как читать вызов", 22, True)
    c.code(1030, 250, [
        'f:SetPoint("TOPLEFT",',
        '           parent,',
        '           "TOPLEFT",',
        '           70, -60)',
    ], 17)

    c.para((1030, 410), "Первая строка — к какой точке самого фрейма привязываемся. Вторая — "
                        "к какому объекту. Третья — к какой точке этого объекта. Числа — смещение в пикселях: "
                        "X вправо, Y вверх, поэтому «ниже на 60» — это -60.", 480, 18)

    c.para((1030, 600), "Один SetPoint — один якорь. Якоря TOPLEFT и BOTTOMRIGHT одновременно задают "
                        "и положение, и размер: фрейм растягивается между ними вместо SetSize.", 480, 18)

    c.box(90, 690, 880, 150, WARN_BG, WARN_BD)
    c.text((112, 708), "Частая ошибка", 18, True, False, WARN_TX)
    c.para((112, 740), "Привязать фрейм к двум независимым деревьям якорей: SetPoint(\"TOPLEFT\", UIParent) "
                       "и следом SetPoint(\"BOTTOMRIGHT\") без родителя. Клиент отказывается и пишет "
                       "«SetPoint would result in anchor family connection».", 840, 18, WARN_TX)
    c.save("04-anchors.png")


# ---------------------------------------------------------------------------
# 5. Слои
# ---------------------------------------------------------------------------
def d_layers():
    c = Canvas(1560, 860)
    c.title("Два независимых порядка наложения",
            "FrameStrata — между фреймами, DrawLayer — внутри одного фрейма")

    # слева: страты
    c.text((90, 180), "FrameStrata (SetFrameStrata)", 20, True)
    strata = ["WORLD", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
              "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"]
    y = 232
    for i, s in enumerate(strata):
        fill = ACC_BG if s in ("MEDIUM", "DIALOG") else BOX_BG
        bd = ACC_BD if s in ("MEDIUM", "DIALOG") else BOX_BD
        c.box(90 + i * 7, y, 490 - i * 14, 48, fill, bd)
        c.text((335, y + 24), s, 18, True, True, ACC_TX if bd == ACC_BD else INK, "mm")
        y += 52

    # справа: слои отрисовки
    c.text((780, 180), "DrawLayer (внутри фрейма)", 20, True)
    layers = ["BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT"]
    y = 232
    for i, s in enumerate(layers):
        fill = ACC_BG if s == "OVERLAY" else BOX_BG
        bd = ACC_BD if s == "OVERLAY" else BOX_BD
        c.box(780 + i * 12, y, 620 - i * 24, 48, fill, bd)
        c.text((1090, y + 24), s, 18, True, True, ACC_TX if bd == ACC_BD else INK, "mm")
        y += 52

    c.para((90, 712), "Девять страт, сзади вперёд. WORLD зарезервирована под мир и аддону недоступна. "
                      "Внутри страты порядок задаёт frame level (0–10000).",
           640, 17)
    c.para((790, 712), "Пять слоёв отрисовки внутри фрейма. FontString всегда выше текстур того же слоя, "
                       "а подписи на одном слое не имеют подуровней.",
           700, 17)
    c.save("05-layers.png")


# ---------------------------------------------------------------------------
# 6. Поток событий
# ---------------------------------------------------------------------------
def d_events():
    c = Canvas(1700, 800)
    c.title("Как событие доходит до твоего кода",
            "Регистрация — на фрейме; обработчик — один на фрейм, разбор внутри")

    boxes = [
        ("Клиент игры", "что-то произошло\n(вход, лут, каст)", 0),
        ("Фрейм", "зарегистрирован через\nRegisterEvent", 1),
        ("OnEvent", "SetScript(\"OnEvent\", f)\nself, event, ...", 2),
        ("Твой разбор", "if event == \"...\"\nthen обработчик end", 3),
    ]
    x, w, h = 60, 360, 120
    gap = (1700 - 120 - 4 * w) / 3
    for name, cap, i in boxes:
        accent = i in (1, 2)
        c.box(x, 200, w, h, ACC_BG if accent else BOX_BG, ACC_BD if accent else BOX_BD)
        c.text((x + 24, 216), name, 22, True, False, ACC_TX if accent else INK)
        yy = 250
        for l in cap.split("\n"):
            c.text((x + 24, yy), l, 17, False, True, MUTED)
            yy += 24
        if i < 3:
            c.arrow((x + w + 8, 260), (x + w + gap - 8, 260))
        x += w + gap

    c.box(60, 380, 780, 210)
    c.text((84, 400), "Несколько фреймов — одно событие", 20, True)
    c.para((84, 436), "Одно и то же событие может слушать сколько угодно фреймов: каждый получит свой вызов. "
                      "Порядок между аддонами не гарантирован, поэтому нельзя строить логику на том, "
                      "что чужой обработчик уже отработал.", 740, 18)

    c.box(880, 380, 760, 210, WARN_BG, WARN_BD)
    c.text((904, 400), "Чего нельзя делать в OnEvent", 20, True, False, WARN_TX)
    c.para((904, 436), "Долгих циклов и тяжёлых сканов: обработчик выполняется в главном потоке, "
                       "игра на это время замирает. Тяжёлое — откладывай таймером на следующий кадр.",
           720, 18, WARN_TX)
    c.save("06-events.png")


# ---------------------------------------------------------------------------
# 7. Архитектура DropLedger
# ---------------------------------------------------------------------------
def d_dropledger():
    c = Canvas(1800, 990)
    c.title("DropLedger: как устроен настоящий аддон",
            "38 файлов в одном .toc; каждый слой знает только про соседа")

    def mod(x, y, w, h, name, desc, accent=False, tsize=18, dsize=15):
        c.box(x, y, w, h, ACC_BG if accent else BOX_BG, ACC_BD if accent else BOX_BD)
        c.text((x + 16, y + 13), name, tsize, True, False, ACC_TX if accent else INK)
        c.para((x + 16, y + 13 + tsize + 10), desc, w - 32, dsize, MUTED, 1.35)

    mod(50, 150, 1700, 76, "DropLedger.toc",
        "Interface 120105 · Title и Notes-* на 12 языках · Author · Version 1.13.6 · SavedVariables DropLedgerDB · "
        "SavedVariablesPerCharacter DropLedgerCharDB · IconTexture · дальше — список 38 файлов в порядке загрузки", True, 18, 15)

    mod(50, 260, 340, 110, "Locale*.lua · Theme.lua", "12 языков, словарь L(); палитры и раскладки окна")
    mod(410, 260, 340, 110, "Data*.lua", "встроенные базы: луты, шансы, модели, рыба, трансмог")
    mod(770, 260, 340, 110, "Stats · Scan · TMog", "математика шансов, разовые сканы коллекций")

    mod(50, 410, 1060, 130, "Core.lua", "БД и миграции схемы, счёт попыток, слэш-команды, стартовый фрейм "
                                       "ADDON_LOADED, обёртки над C_Item и другими C_* неймспейсами", True, 19, 16)
    mod(50, 580, 1060, 120, "Detect · Kills · Loot · Fishing",
        "разбор событий игры: что выпало, с кого, за сколько попыток", False, 18, 16)

    mod(1170, 260, 580, 280, "UI.lua",
        "окно и вкладки, строки списка, кнопки, своя прокрутка, страница настроек, кнопка у миникарты, "
        "тултипы, примерочная на DressUpModel", True, 19, 16)
    mod(1170, 570, 580, 100, "DropLedgerDB", "SavedVariables: настройки и общая база items / acc / chars")
    mod(1170, 690, 580, 100, "DropLedgerCharDB", "SavedVariablesPerCharacter: счётчики этого персонажа")
    mod(1170, 810, 580, 100, "Popup · Import · Info", "всплывающие карточки, импорт шансов, отчёты в чат")

    for x in (220, 580, 940):
        c.arrow((x, 370), (x, 410))
    c.arrow((580, 540), (580, 580))
    c.arrow((1110, 470), (1170, 400))
    c.arrow((1110, 640), (1170, 625))
    c.arrow((1400, 540), (1400, 570))
    c.arrow((1470, 570), (1470, 540))
    c.text((1388, 546), "чтение", 13, False, False, MUTED, "ra")
    c.text((1484, 546), "запись", 13, False, False, MUTED, "la")

    c.box(50, 750, 1060, 160, OK_BG, OK_BD)
    c.text((72, 766), "Поток данных", 18, True, False, OK_TX)
    c.para((72, 796), "событие игры → модуль разбора увеличивает счётчик → запись в DropLedgerCharDB (истина по персонажу) "
                      "→ SyncChar зеркалит в DropLedgerDB.chars → пересчёт аккаунтной суммы → UI читает готовые числа. "
                      "Окно ничего не считает само, поэтому его можно открыть и закрыть в любой момент.", 1020, 17, OK_TX)
    c.save("07-dropledger.png")


# ---------------------------------------------------------------------------
# 8. Релиз
# ---------------------------------------------------------------------------
def d_release():
    c = Canvas(1700, 760)
    c.title("Сборка и публикация", "Один и тот же zip нужен и для проверки, и для CurseForge")

    steps = [
        ("Папка аддона", "toc + lua + xml\nбез лишних файлов"),
        ("Проверка .toc", "Interface = версия\nклиента; имя файла\n= имя папки"),
        ("zip", "внутри архива\nровно одна папка\nDropLedger/"),
        ("CurseForge", "загрузка файла,\nверсия, changelog"),
        ("Игрок", "распаковал в\nInterface/AddOns"),
    ]
    x, y, w, h = 60, 210, 300, 155
    gap = (1700 - 120 - len(steps) * w) / (len(steps) - 1)
    for i, (name, cap) in enumerate(steps):
        c.box(x, y, w, h, ACC_BG if i in (1, 2) else BOX_BG, ACC_BD if i in (1, 2) else BOX_BD)
        c.text((x + w / 2, y + 32), name, 22, True, False, ACC_TX if i in (1, 2) else INK, "ma")
        yy = y + 66
        for l in cap.split("\n"):
            c.text((x + w / 2, yy), l, 15, False, False, MUTED, "ma")
            yy += 24
        if i < len(steps) - 1:
            c.arrow((x + w + 8, y + h / 2), (x + w + gap - 8, y + h / 2))
        x += w + gap

    c.box(60, 420, 800, 260, WARN_BG, WARN_BD)
    c.text((84, 442), "Три ошибки упаковки", 20, True, False, WARN_TX)
    for i, t in enumerate([
        "zip содержит файлы в корне, а не папку — аддон не появится в списке;",
        "внутри архива вложенная папка DropLedger/DropLedger/ — двойная вложенность;",
        "Interface меньше версии клиента — аддон помечается устаревшим.",
    ]):
        c.para((84, 486 + i * 54), "•  " + t, 750, 18, WARN_TX)

    c.box(900, 420, 740, 260)
    c.text((924, 442), "Что проверить перед выкладкой", 20, True)
    for i, t in enumerate([
        "версия в .toc и в changelog совпадают;",
        "чистый клиент без других аддонов: ошибок нет;",
        "перезагрузка интерфейса не плодит дубли в базе.",
    ]):
        c.para((924, 486 + i * 54), "•  " + t, 690, 18)
    c.save("08-release.png")


def d_devcycle():
    c = Canvas(1760, 900)
    c.title("Цикл разработки аддона",
            "Один оборот — от правки до проверки; всё, что можно проверить без игры, проверяется без игры")

    steps = [
        ("Править", "редактор, Lua 5.1"),
        ("Проверить", "luacheck, заглушка"),
        ("/reload", "в игре, на хоткее"),
        ("Смотреть", "scriptErrors, /etrace"),
        ("Починить", "и снова по кругу"),
    ]
    x, y, w, h = 60, 200, 300, 130
    gap = 50
    for i, (name, cap) in enumerate(steps):
        c.box(x, y, w, h, ACC_BG if i in (0, 2) else BOX_BG, ACC_BD if i in (0, 2) else BOX_BD)
        c.text((x + w / 2, y + 36), name, 23, True, False, ACC_TX if i in (0, 2) else INK, "ma")
        c.text((x + w / 2, y + 72), cap, 17, False, False, MUTED, "ma")
        if i < len(steps) - 1:
            c.arrow((x + w + 8, y + h / 2), (x + w + gap - 8, y + h / 2))
        x += w + gap

    # петля назад
    c.d.line([(60 + 4 * (w + gap) + w / 2) * S, (y + h) * S,
              (60 + 4 * (w + gap) + w / 2) * S, (y + h + 60) * S], fill=LINE, width=3)
    c.d.line([(60 + 4 * (w + gap) + w / 2) * S, (y + h + 60) * S,
              (60 + w / 2) * S, (y + h + 60) * S], fill=LINE, width=3)
    c.arrow((60 + w / 2, y + h + 60), (60 + w / 2, y + h + 6))
    c.text((60 + 2 * (w + gap), y + h + 36), "правка занимает минуту, проверка — десять секунд",
           18, False, False, MUTED, "ma")

    c.text((60, 480), "Что делается без игры", 22, True)
    tools = [
        ("luacheck .", "опечатки в именах, мёртвый код, недостижимые ветки"),
        ("node run.js <аддон>", "загрузка, события, слэш-команды на настоящем Lua 5.1"),
        ("/dump", "посмотреть значение до того, как писать код"),
        ("/fstack", "найти, кто перекрывает клик и в каком слое текст"),
    ]
    yy = 530
    for name, desc in tools:
        c.box(60, yy, 1640, 58)
        c.text((84, yy + 18), name, 18, True, True, ACC_TX)
        c.text((420, yy + 18), desc, 18, False, False, MUTED)
        yy += 70

    c.box(60, 820, 1640, 56, WARN_BG, WARN_BD)
    c.text((84, 836), "Нельзя: править пять мест сразу и потом искать, что помогло. Одна правка — одна проверка.",
           17, False, False, WARN_TX)
    c.save("09-devcycle.png")


def d_db():
    c = Canvas(1720, 800)
    c.title("Три уровня базы DropLedger",
            "Персонаж — источник истины, аккаунт — сумма, справочники — в коде")

    c.box(60, 190, 480, 290, ACC_BG, ACC_BD)
    c.text((84, 208), "DropLedgerCharDB", 20, True, True, ACC_TX)
    c.text((84, 240), "SavedVariablesPerCharacter", 15, False, False, MUTED)
    c.codeblock(84, 276, [
        "items[itemID] = { tries, wins }",
        "fish[itemID]  = { tries, wins }",
    ], 15, INK)
    c.para((84, 350), "Счётчики этого персонажа. Пишутся сразу, как только произошло событие.",
           430, 16, MUTED)
    c.para((84, 420), "Каждый персонаж — свой файл в WTF.", 430, 16, MUTED)

    c.box(620, 190, 500, 290)
    c.text((644, 208), "DropLedgerDB", 20, True, True)
    c.text((644, 240), "SavedVariables", 15, False, False, MUTED)
    c.codeblock(644, 276, [
        "items[itemID] = { chance, mode, src }",
        "acc[itemID]   = { tries, wins }",
        "chars[key]    = { [itemID] = ... }",
    ], 15, INK)
    c.para((644, 372), "Что отслеживаем, сумма по аккаунту и разбивка по персонажам.",
           450, 16, MUTED)

    c.box(1200, 190, 460, 290)
    c.text((1224, 208), "Data*.lua", 20, True, True)
    c.text((1224, 240), "в коде аддона, не в базе", 15, False, False, MUTED)
    c.codeblock(1224, 276, ["NS.Items[itemID] = { chance, ... }"], 15, INK)
    c.para((1224, 320), "Справочники лута, шансов, моделей и рыбы: ~30 тысяч строк. В SavedVariables не попадают, поэтому база остаётся маленькой.",
           420, 16, MUTED)

    c.arrow((540, 320), (620, 320))
    c.text((580, 292), "SyncChar", 15, False, False, ACC_TX, "ma")
    c.arrow((1120, 320), (1200, 320))
    c.text((1160, 292), "ChanceOf", 15, False, False, ACC_TX, "ma")

    c.box(60, 510, 1600, 56, BOX_BG, BOX_BD)
    c.text((84, 524), "UI не читает базу напрямую: он берёт Compute(id) — тот складывает справочник, acc и счётчики персонажа.",
           18, False, False, INK)

    c.box(60, 600, 1600, 170, OK_BG, OK_BD)
    c.text((84, 618), "Почему не одна таблица", 19, True, False, OK_TX)
    for i, line in enumerate([
        "• счётчик персонажа принадлежит персонажу: игра сама хранит его в папке персонажа;",
        "• сумма по аккаунту нужна, чтобы не обходить всех персонажей при каждом открытии окна;",
        "• справочники одинаковы для всех и меняются только с новой версией аддона — им место в коде.",
    ]):
        c.para((84, 652 + i * 40), line, 1540, 17, OK_TX)
    c.save("10-db.png")


if __name__ == "__main__":
    d_load()
    d_lifecycle()
    d_tree()
    d_anchors()
    d_layers()
    d_events()
    d_dropledger()
    d_release()
    d_devcycle()
    d_db()
