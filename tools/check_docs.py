# -*- coding: utf-8 -*-
"""Проверки готовности руководства: битые локальные ссылки, картинки,
запрещённые формулировки, структура разделов.
"""
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))

MD = sorted(f for f in os.listdir(ROOT) if f.endswith(".md"))
problems = []

link_re = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
bad_phrases = ["как известно", "в большинстве случаев", "обычно"]

for name in MD:
    path = os.path.join(ROOT, name)
    text = open(path, encoding="utf-8").read()
    for target in link_re.findall(text):
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue
        anchor = target.split("#")[0]
        if not anchor:
            continue
        full = os.path.normpath(os.path.join(ROOT, anchor))
        if not os.path.exists(full):
            problems.append(f"{name}: ссылка ведёт в никуда → {target}")
    for i, line in enumerate(text.splitlines(), 1):
        low = line.lower()
        # цитаты из источников идут в кавычках-ёлочках, их не проверяем
        if line.strip().startswith(">") or '"' in line or "«" in line:
            continue
        for phrase in bad_phrases:
            if phrase in low:
                problems.append(f"{name}:{i}: формулировка без источника → «{phrase}»")

# у каждого раздела должны быть блоки «частые ошибки» и «источники»
for name in MD:
    if not re.match(r"^\d\d-", name) or name.startswith("00"):
        continue
    text = open(os.path.join(ROOT, name), encoding="utf-8").read()
    if "Частые ошибки" not in text:
        problems.append(f"{name}: нет блока «Частые ошибки новичка»")
    if "Источники раздела" not in text:
        problems.append(f"{name}: нет блока «Источники раздела»")

imgs = os.path.join(ROOT, "img")
print("Разделов:", len([n for n in MD if re.match(r"^\d\d-", n)]))
print("Картинок:", len([f for f in os.listdir(imgs) if f.endswith(".png")]))
print("Строк всего:", sum(len(open(os.path.join(ROOT, n), encoding="utf-8").read().splitlines()) for n in MD))

if problems:
    print("\nПРОБЛЕМЫ:")
    for p in problems:
        print(" -", p)
    sys.exit(1)
print("\nПроверки пройдены")
