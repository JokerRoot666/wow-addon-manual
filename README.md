# Аддоны World of Warcraft: учебник для стажёра

**Читать онлайн:** <https://jokerroot666.github.io/wow-addon-manual/> ·
**Скилл для ИИ-агента:** [`skill/wow-addons/`](skill/wow-addons/SKILL.md)

Учебник написан под актуальный клиент **Midnight 12.x** (на дату сборки материалов —
12.1.5, Interface-номер `120105`). Всё, что здесь есть, опирается на три источника и на
исходники нашего аддона **DropLedger**:

| Сокращение | Источник | Что берём |
|---|---|---|
| **W** | <https://warcraft.wiki.gg> | справочник API, событий, формата `.toc`, ограничений 12.x |
| **S** | <https://github.com/Gethe/wow-ui-source> | реальный код Blizzard, `version.txt`, 374 живых `.toc` |
| **T** | <https://github.com/FRIKKern/WoW-Midnight-Addon-Template> | шаблон аддона под 12.x, `.pkgmeta`, CI |
| **D** | `DropLedger/` (наш аддон, 38 файлов) | рабочий пример: код, решения, грабли |

Правила учебника:

1. **Ни одной функции, события или поля, которых нет в источниках.** Если чего-то в
   источниках нет — это написано словами «в источниках не найдено», а не додумано.
2. У каждого API-элемента в таблицах стоит ссылка на страницу-источник.
3. Если источники расходятся — показаны оба варианта и помечено расхождение.
4. Код из DropLedger приводится **как есть**, с номерами строк: это единственное
   исключение из правила 1 — он написан нами и проверен в игре.

## Как читать

Стажёр идёт по порядку: 1 → 13. Первые семь разделов — минимум, без которого ничего не
запустится. Разделы 8–9 — то, ради чего аддоны вообще пишут. 10 и 13 — отладка и рабочий
процесс (их читают до того, как код перестанет работать). 11–12 — упаковка и полный разбор
настоящего аддона.

## Как посмотреть

* **Онлайн:** <https://jokerroot666.github.io/wow-addon-manual/> — тот же текст одним файлом,
  слева оглавление, картинки встроены.
* **Одним файлом локально:** открыть `index.html` в браузере — все разделы, картинки
  встроены, слева оглавление, интернет не нужен.
* **По разделам:** читать `.md` по порядку; ссылки между файлами и на `img/` работают в любом
  Markdown-просмотрщике.
* **Пересобрать HTML** после правок: `python tools/build_html.py` → `index.html`
  (нужен модуль `markdown`; если его нет в системе, используется копия из `tools/_lib`).
  Если вместо Python открывается Microsoft Store — звать `py tools/build_html.py`.
* **Перегенерировать схемы:** `python tools/make_diagrams.py`.
* **Проверить целостность** (битые ссылки, отсутствующие картинки, забытые блоки):
  `python tools/check_docs.py`.

## Скилл «wow-addons» для ИИ-агента

В [`skill/wow-addons/`](skill/wow-addons/) лежит готовый скилл: `SKILL.md` + 9 справочников
в `references/` + шаблоны в `templates/` (стартовый аддон и стенд тестов на `fengari`).
Он даёт агенту тот же набор правил, что и учебник, но в виде «симптом → причина → лечение»
и готовых сниппетов.

Установка в DeepSeek Harness (Windows, из корня репозитория):

```bash
node tools/install-skill.mjs
```

Скрипт копирует папку в `~/.dsh/skills/wow-addons`. Проверить установку — `/skills` в DSH
или наличие файла `~/.dsh/skills/wow-addons/SKILL.md`.

## Оглавление

| № | Раздел | Файл |
|---|---|---|
| — | План руководства и карта источников | [00-plan.md](00-plan.md) |
| 1 | Что такое аддон, как игра его грузит, `.toc` | [01-intro.md](01-intro.md) |
| 2 | Lua 5.1 в контексте WoW | [02-lua.md](02-lua.md) |
| 3 | Жизненный цикл аддона и события загрузки | [03-lifecycle.md](03-lifecycle.md) |
| 4 | Фреймы: создание, якоря, слои, шаблоны | [04-frames.md](04-frames.md) |
| 5 | События: регистрация, обработчик, аргументы | [05-events.md](05-events.md) |
| 6 | Слэш-команды | [06-slash.md](06-slash.md) |
| 7 | Сохранение данных: SavedVariables | [07-saved.md](07-saved.md) |
| 8 | Работа с UI: окна, текстуры, шрифты, скроллы | [08-ui.md](08-ui.md) |
| 9 | Игровые данные: Unit, C_Item, C_Spell, C_Map, C_Timer | [09-data.md](09-data.md) |
| 10 | Отладка: команды, окно ошибок, перехват | [10-debug.md](10-debug.md) |
| 11 | Публикация, упаковка, версионирование | [11-release.md](11-release.md) |
| 12 | Hello World построчно и разбор DropLedger | [12-walkthrough.md](12-walkthrough.md) |
| 13 | Процесс разработки человеком: среда, цикл, приёмка | [13-workflow.md](13-workflow.md) |

Приложения:

* `examples/hello/` — рабочий минимальный аддон (проверен на заглушке, см. 13.6).
* `tools/miniclient/` — заглушка клиента на `fengari`: прогоняет аддон без игры.
* `tools/make_diagrams.py` — генератор всех схем в `img/`.

## Схемы

| Файл | О чём |
|---|---|
| `img/01-load.png` | путь аддона от папки до `ADDON_LOADED` |
| `img/02-lifecycle.png` | порядок событий при входе и выходе |
| `img/03-frame-tree.png` | дерево фреймов и наследование |
| `img/04-anchors.png` | девять точек привязки, `SetPoint` |
| `img/05-layers.png` | `FrameStrata` и `DrawLayer` |
| `img/06-events.png` | путь события до твоего кода |
| `img/07-dropledger.png` | архитектура DropLedger |
| `img/08-release.png` | сборка и публикация |
| `img/09-devcycle.png` | цикл разработки: правка → `/reload` → проверка |
| `img/10-db.png` | три уровня базы DropLedger |

## Расхождения в источниках (сведены здесь)

1. **Interface-номер.** Вики и Gethe дают `120105` (12.1.5) —
   [TOC format §Interface](https://warcraft.wiki.gg/wiki/TOC_format#Interface),
   [version.txt](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/version.txt).
   Шаблон FRIKKern в `MyAddon.toc` и в своей документации пишет `120001` (12.0.1) —
   [MyAddon.toc](https://raw.githubusercontent.com/FRIKKern/WoW-Midnight-Addon-Template/HEAD/template/MyAddon.toc).
   Оба варианта существуют; для текущего клиента верен `120105`.
2. **Список `FrameStrata`.** Страница
   [Frame Strata](https://warcraft.wiki.gg/wiki/Frame_Strata) перечисляет 9 значений
   (`WORLD` … `TOOLTIP`), а [API types](https://warcraft.wiki.gg/wiki/API_types) — 10,
   включая `PARENT` и `BLIZZARD`. Единого списка в источниках нет.
3. **Что происходит с устаревшим аддоном.** «Клиент пропускает аддон с несовпадающим
   Interface» — [Getting the current interface number](https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number);
   «помечается как out of date и грузится только с галочкой Load out of date AddOns» —
   [AddOn §Loading out-of-date addons](https://warcraft.wiki.gg/wiki/AddOn#Loading_out-of-date_addons).
   Формулировки разные: первая строже, вторая описывает фактическое поведение.
4. **`ENCOUNTER_LOOT_RECEIVED`.** Список событий даёт `encounterID, itemID, itemLink,
   quantity, itemName, fileName`, а страница события — `playerName, classFileName` —
   [Events](https://warcraft.wiki.gg/wiki/Events) против
   [Event:ENCOUNTER_LOOT_RECEIVED](https://warcraft.wiki.gg/wiki/Event:ENCOUNTER_LOOT_RECEIVED).
5. **`CHAT_MSG_*`.** В сигнатуре события 17 аргументов, в шаблоне `CHAT_MSG` — 18
   (18-й `discordInfo`) — [Event:CHAT_MSG_LOOT](https://warcraft.wiki.gg/wiki/Event:CHAT_MSG_LOOT)
   против [CHAT_MSG](https://warcraft.wiki.gg/wiki/CHAT_MSG).
6. **`C_Item.GetItemInfo`.** Вики описывает 18 возвращаемых значений
   ([API:C_Item.GetItemInfo](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemInfo)), а
   старый `GetItemInfo` в 12.1.5 удалён
   ([API:GetItemInfo](https://warcraft.wiki.gg/wiki/API:GetItemInfo)). DropLedger
   поддерживает и tuple, и таблицу — см. 9.2.
7. **`## Interface` «обязателен»?** В документации шаблона — да
   ([docs-site/toc-format.md](https://raw.githubusercontent.com/FRIKKern/WoW-Midnight-Addon-Template/HEAD/docs-site/docs/toc-format.md)),
   на вики такого требования нет, а в 374 `.toc` самого клиента директива есть ровно в
   одном (`Blizzard_ReforgingUI_Classic.toc`, значение `0`). Для стороннего аддона
   практический вывод один: ставить.
