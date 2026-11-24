# -*- coding: utf-8 -*-
"""Собирает все разделы руководства в один HTML-файл с встроенными картинками.

Запуск: python build_html.py
Результат: ../index.html (открывается в браузере без интернета; он же — вход сайта
на GitHub Pages).
"""
import base64
import glob
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "_lib"))

import markdown
from markdown.extensions.toc import slugify_unicode


def slug(value, separator):
    """Читаемые якоря: цифры и буквы сохраняются, остальное — дефис."""
    return slugify_unicode(value, separator)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))

ORDER = ["README.md", "00-plan.md"] + sorted(
    os.path.basename(p) for p in glob.glob(os.path.join(ROOT, "[0-9][1-9]-*.md"))
)

md = markdown.Markdown(
    extensions=["tables", "fenced_code", "toc", "sane_lists", "attr_list"],
    extension_configs={"toc": {"permalink": False, "toc_depth": "2-3", "slugify": slug}},
)

parts = []
for name in ORDER:
    path = os.path.join(ROOT, name)
    if not os.path.exists(path):
        print("нет файла:", name)
        continue
    text = open(path, encoding="utf-8").read()
    md.reset()
    parts.append('<section class="chapter">' + md.convert(text) + "</section>")

body = "\n".join(parts)

# картинки -> data URI
def inline_image(match):
    src = match.group(1)
    if src.startswith(("http", "data:")):
        return match.group(0)
    file_path = os.path.normpath(os.path.join(ROOT, src))
    if not os.path.exists(file_path):
        print("нет картинки:", src)
        return match.group(0)
    data = base64.b64encode(open(file_path, "rb").read()).decode("ascii")
    return match.group(0).replace(src, "data:image/png;base64," + data)

body = re.sub(r'<img[^>]+src="([^"]+)"', inline_image, body)

CSS = """
:root { --ink:#111827; --muted:#5b6577; --line:#d7dde5; --acc:#1e40af; --bg:#ffffff; --soft:#f7f9fc; }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink);
       font: 16px/1.62 "Segoe UI", "PT Sans", Roboto, Arial, sans-serif; }
.wrap { display:flex; gap:40px; max-width:1380px; margin:0 auto; padding:32px 24px 96px; }
nav { position:sticky; top:24px; align-self:flex-start; width:290px; flex:0 0 290px;
      max-height:calc(100vh - 48px); overflow:auto; font-size:14px; }
nav h2 { font-size:13px; text-transform:uppercase; letter-spacing:.08em; color:var(--muted);
         margin:0 0 12px; font-weight:600; }
nav a { display:block; padding:4px 8px; color:#334155; text-decoration:none; border-left:2px solid transparent; }
nav a:hover { background:var(--soft); color:var(--acc); }
nav a.lvl2 { padding-left:10px; font-weight:600; margin-top:8px; }
nav a.lvl3 { padding-left:24px; font-size:13px; color:#64748b; }
main { min-width:0; flex:1 1 auto; max-width:980px; }
.chapter { border-top:1px solid var(--line); padding-top:36px; margin-top:36px; }
.chapter:first-child { border-top:0; margin-top:0; padding-top:0; }
h1 { font-size:32px; line-height:1.25; margin:0 0 16px; }
h2 { font-size:23px; margin:36px 0 12px; padding-bottom:6px; border-bottom:1px solid var(--line); }
h3 { font-size:18px; margin:26px 0 8px; }
p, li { color:#1f2937; }
a { color:var(--acc); }
code { font-family: Consolas, "Cascadia Mono", monospace; font-size:.92em;
       background:var(--soft); padding:1px 5px; border-radius:4px; border:1px solid #e6ebf2; }
pre { background:#12161f; color:#e6edf7; padding:16px 18px; border-radius:10px; overflow:auto;
      font-size:14px; line-height:1.5; }
pre code { background:none; border:0; padding:0; color:inherit; font-size:inherit; }
blockquote { margin:16px 0; padding:10px 18px; border-left:3px solid #94a3b8;
             background:var(--soft); color:#334155; }
blockquote p { margin:6px 0; }
table { border-collapse:collapse; width:100%; margin:16px 0; font-size:14.5px; }
th, td { border:1px solid var(--line); padding:8px 10px; vertical-align:top; text-align:left; }
th { background:var(--soft); font-weight:600; }
tr:nth-child(even) td { background:#fcfdff; }
img { max-width:100%; height:auto; display:block; margin:22px auto; border:1px solid var(--line);
      border-radius:10px; }
hr { border:0; border-top:1px solid var(--line); margin:28px 0; }
ul, ol { padding-left:22px; }
li { margin:4px 0; }
@media (max-width: 1100px) {
  nav { display:none; }
  .wrap { display:block; padding:20px; }
}
"""

nav_html = '<nav><h2>Содержание</h2>' + md.toc + "</nav>" if False else ""

# отдельное оглавление по заголовкам h2/h3 всех разделов
toc_items = []
for block in parts:
    for m in re.finditer(r'<h([23]) id="([^"]+)">(.*?)</h\1>', block, re.S):
        lvl, anchor, title = m.group(1), m.group(2), re.sub(r"<[^>]+>", "", m.group(3))
        toc_items.append((int(lvl), anchor, title))
nav_html = '<nav><h2>Содержание</h2>' + "".join(
    f'<a class="lvl{l}" href="#{a}">{t}</a>' for l, a, t in toc_items
) + "</nav>"

html = f"""<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Аддоны World of Warcraft: учебник для стажёра</title>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
{nav_html}
<main>
{body}
</main>
</div>
</body>
</html>
"""

out = os.path.join(ROOT, "index.html")
open(out, "w", encoding="utf-8").write(html)
print("готово:", out, round(len(html) / 1024 / 1024, 2), "МБ")
