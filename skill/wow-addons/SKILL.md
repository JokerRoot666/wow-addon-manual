---
name: wow-addons
description: Разработка аддонов для World of Warcraft на Lua — структура TOC/XML, SavedVariables, API 11.x/12.x (C_*, Enum, события, secret values, боевой лог), интерфейс (фреймы, вкладки, скролл, миникарта, страница настроек), тесты без игры (fengari + mock, luaparse), внешние данные (Wowhead nether-API, WAF и капча, DB2 wago.tools), локализация на 12 языков, сборка и публикация (CurseForge/Wago), каталог проверенных грабель и готовые сниппеты. Use for any WoW addon task: write, fix, port an addon from 11.x to 12.x, build a UI window, parse SavedVariables, scrape Wowhead/DB2, localize, release.
---

# Аддоны WoW: полный рабочий курс и справочник

Скилл для написания аддонов World of Warcraft «с нуля до релиза». Собран по реальному
проекту **Drop Ledger** (retail 12.1.5/12.1.7, 36 Lua-файлов, 7 827 автотестов без игры,
12 языков, два архива для публикации). Всё ниже либо проверено в клиенте, либо помечено
как «по документации».

Учебник по этим же правилам для человека — <https://jokerroot666.github.io/wow-addon-manual/>
(14 разделов, от `.toc` до релиза). Когда агенту нужен не сниппет, а объяснение «почему так»,
отправляй туда.

Читай в таком порядке:

| Файл | Когда нужен |
|---|---|
| `references/01-anatomy.md` | первый аддон: TOC, XML, загрузка, SavedVariables, слэш-команды, структура проекта |
| `references/02-api.md` | любое обращение к клиенту: `C_*`, `Enum`, события, предметы, секретные значения, 11.x → 12.x |
| `references/03-ui.md` | окна, вкладки, скролл, миникарта, страница настроек, слои, темы |
| `references/04-events-data.md` | коллекции, журналы, трансмог, сумки, сканы порциями, кэш, производительность |
| `references/05-testing.md` | прогон аддона без игры (fengari + mock), синтаксис, отладка в клиенте |
| `references/06-external-data.md` | Wowhead, wago.tools/DB2, WAF и капча, сбор через браузер, кэш ответов |
| `references/07-localization-release.md` | 12 языков, словари, версии, сборка zip, CurseForge/Wago, чеклист релиза |
| `references/08-pitfalls.md` | 50+ грабель: симптом → причина → лечение (читать перед отладкой) |
| `references/09-snippets.md` | готовые куски кода: каркас, событие, L(), миникарта, опции, таблица, кэш |
| `templates/starter/` | скелет аддона, который сразу грузится в игре |
| `templates/uitest/` | минимальный стенд тестов на fengari |

## Железные правила

1. **Не выдумывать API.** Имя функции, событие, поле таблицы проверяй по
   [wow-ui-source](https://github.com/Gethe/wow-ui-source) (ветка `live`), по вики
   [warcraft.wiki.gg](https://warcraft.wiki.gg) или по `/dump`/`/etrace` в игре.
   Если проверить нечем — так и пиши «не проверено».
2. **Только документированный API.** Никакого чтения памяти, патчей клиента,
   автокликов, инъекций в процесс, обхода капчи. За это банят; в WoW нет HTTP —
   аддон в сеть не ходит вообще.
3. **Боевой лог в 12.x закрыт.** `RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` —
   защищённый вызов: `pcall` не спасает, прилетает `ADDON_ACTION_FORBIDDEN`.
   Проверяй `C_Secrets`/`C_CombatLog` и версию TOC до регистрации, а не после.
4. **`secret value` — это «нет данных».** Любое значение из клиента прогоняй через
   `issecretvalue()` перед сравнением/арифметикой; сравнивать секретное нельзя — ошибка Lua.
5. **Все строки интерфейса — через `L("русский исходник")`.** Русский текст — исходник,
   остальные языки — словарь. Непереведённая строка остаётся русской, а не пустой.
6. **Кэшировать обращения к клиенту.** `C_Item.GetItemInfo` отдаёт `nil` до загрузки
   данных; список из 100 строк не должен дёргать клиент на каждую перерисовку.
7. **Ничего тяжёлого в `OnUpdate` и в `OnEvent`.** Порции по 200–250 записей за кадр,
   `C_Timer.After`, ленивые индексы, отписка от событий, когда окно закрыто.
8. **Проверять на стенде, а не в рейде.** Синтаксис — `luaparse`, логика и UI — mock-клиент
   (fengari), потом `/reload` в игре. Ошибка в `OnEvent` выгружает аддон молча.
9. **Версия TOC = версия клиента.** `## Interface: 120105` для 12.1.5; старый номер =
   «устаревший аддон» в списке. Номер версии аддона держать в TOC **и** в `ns.version`.
10. **Релиз — только через скрипт.** Сборка zip: ровно одна корневая папка,
    без `tools/`, без `.git`, без тестов; проверка содержимого архива, а не «на глаз».

## Быстрый старт (10 шагов)

```text
1. mkdir MyAddon && cd MyAddon
2. MyAddon.toc      -> ## Interface, Title, SavedVariables, список .lua
3. Core.lua         -> local ADDON, ns = ...; ns.db по ADDON_LOADED; слэш-команда
4. UI.lua           -> окно CreateFrame("Frame", "MyAddonFrame", UIParent, "BackdropTemplate")
5. Locale.lua       -> L() + словари
6. Bindings.xml     -> клавиша (необязательно)
7. тесты: node run.js на mock-клиенте (см. templates/uitest)
8. выкладка: копия в _retail_/Interface/AddOns/MyAddon
9. в игре: /reload, /console scriptErrors 1, проверка окна и событий
10. релиз: zip с одной корневой папкой MyAddon/
```

Минимальный каркас, который реально грузится:

```lua
-- Core.lua
local ADDON, ns = ...
ns.version = "1.0.0"

local DEFAULTS = { settings = { msg = true }, ui = { pos = nil } }

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    MyAddonDB = MyAddonDB or {}
    for k, v in pairs(DEFAULTS) do
        if MyAddonDB[k] == nil then MyAddonDB[k] = v end
    end
    ns.db = MyAddonDB
    print("|cff6ecbffMyAddon|r: загружен")
end)
```

```toc
## Interface: 120105
## Title: My Addon
## Notes: Что делает аддон
## Version: 1.0.0
## SavedVariables: MyAddonDB
Core.lua
UI.lua
```

## Что чаще всего ломается (топ-12, полный список — в 08-pitfalls)

| Симптом | Причина |
|---|---|
| `attempt to call a nil value (GetItemInfo)` | в 11+/12.x убран: `C_Item.GetItemInfo` (таблица) + `C_Item.RequestLoadItemDataByID` |
| клиент падает `ACCESS_VIOLATION` | `PlayerModel:SetUnit` на NPC (`RequiresDeclassifiedUnitIdentity`) → `SetCreature` |
| «клиент не отдаёт модель» на любом юните | `CanSetUnit` возвращает secret value, сравнивать нельзя |
| пустые «квадратики» вместо знаков | шрифт клиента без `· − ✓ → …` → `• - > ...` |
| `bad argument #1 to 'SetTextColor'` | цвет только числами: `SetTextColor(r, g, b)` |
| аддон пропал из игры без ошибки | `RegisterEvent` на боевой лог / защищённый вызов в taint |
| `C_TransmogCollection.GetCategoryAppearances` пусто | в 12.x не работает; сканировать свою базу предметов |
| список тормозит | обращения к клиенту на каждую перерисовку → кэш + обновление одной строки |
| окно уехало под главное | дочерние окна на `FULLSCREEN_DIALOG` + `Raise()` при показе |
| настройки не появляются в «Аддоны» | `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` (через `pcall`) |
| TOC «устарел» | `## Interface` не равен клиентскому (12.1.5 → `120105`) |
| в чат пишет только один, у других пусто | `ns.Print` должен идти через `DEFAULT_CHAT_FRAME:AddMessage` |

## Где брать истину

* Декомпилированный Blizzard UI: `github.com/Gethe/wow-ui-source` (ветки `live`, `ptr`,
  `classic`, `classic_era`) — надёжный источник имён фреймов, шаблонов, событий и
  `C_*`-вызовов, которые использует сам клиент.
* Вики: `warcraft.wiki.gg` (актуальная, заменила Wowpedia), страницы `API_...`, `C_...`,
  `Events`, `Enum...`.
* Данные игры: `wago.tools` (DB2 → CSV/JSON, все сборки), `wow.tools` (DB2/DBC, файлы).
* Сайты: `wowhead.com` (предметы, NPC, зоны, заклинания), `wago.io` (аддоны/WeakAuras),
  `curseforge.com/wow/addons`, `wowinterface.com`.
* Практика: исходники BigWigs, Details!, Ace3, LibStub — как пишут «взрослые» аддоны.
* Поиск ошибок: `/console scriptErrors 1`, `/dump x`, `/etrace`, `/fstack`, `/tinspect`,
  BugSack + BugGrabber, `taint.log` (`/console taintLog 1`).

## Эталонный проект

Живой пример всего, что описано: `C:\Users\Admin\Documents\deepseek-harness\default-workspace\DropLedger`
(аддон retail 12.1.x, 36 Lua-файлов, 7 827 тестов, 12 языков). Полезные точки входа:

* `README.md` — что умеет и какие грабли уже пройдены (1087 строк);
* `tools/README.md` — конвейер данных и сборка баз;
* `tools/DB.md` — форматы всех `Data*.lua` и SavedVariables;
* `tools/uitest/` — полноценный mock-стенд (эталон к `templates/uitest/`);
* `tools/release.py` + `tools/pack.py` — выкладка и два архива;
* `Core.lua` — обёртки совместимости (`ItemInfoTuple`, `Open`, `Probe`).

## Что этот скилл не покрывает (честно)

* Классические клиенты (`_classic_`, `_classic_era`): API другой, боевой лог доступен,
  TOC `## Interface` другой — подходы те же, детали сверять отдельно.
* WeakAuras/ElvUI/Plater-специфику, написание собственных библиотек (Ace3, LibStub) —
  только базовые упоминания.
* Непроверенные в 12.1.x `C_*`-функции: если в справочнике нет — сверять с
  `wow-ui-source`, а не догадываться.
* Публикация через API CurseForge/Wago (ключи, эндпоинты) — только общая схема.

## Как этой картой пользоваться

1. Прочитать `01-anatomy.md` и `02-api.md` целиком — это фундамент.
2. Взять `templates/starter/` за основу, переименовать `MyAddon` → своё имя.
3. Каждый вызов клиента сверять с `02-api.md` (или с вики, если раздела нет).
4. UI собирать по `03-ui.md` (слои, шаблоны, скролл, миникарта, опции).
5. Данные — по `04-events-data.md`, внешние источники — по `06-external-data.md`.
6. Перед каждым `/reload`: синтаксис всех `.lua` через `luaparse` и `node run.js`
   на mock-клиенте (см. `05-testing.md`).
7. Локализация и релиз — `07-localization-release.md`, чеклист в конце.
8. Если что-то «не работает как в документации» — сначала `08-pitfalls.md`, потом вики.
