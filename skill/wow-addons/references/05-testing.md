# 05. Тесты без игры: fengari + mock-клиент

## Зачем это нужно

Ошибка в `OnEvent` в WoW не показывает стек, а тихо выгружает аддон («Interface action
failed»). Живой `/reload` на каждую правку — минута; прогон на заглушке — 200 мс.
В Drop Ledger **7 827 проверок** на mock-клиенте нашли десятки реальных багов
(опечатки в полях, `nil`-глобалы, выезд элементов за окно, расхождение словарей).

Работает так: исполняем **настоящий код аддона** в Lua 5.1 (движок `fengari` под Node),
подсовывая вместо WoW API таблицу-заглушку `MOCK` (тоже Lua). Ничего не рисуется, но
повторяются сигнатуры, хранится состояние (текст, видимость, обработчики, события).

## Стенд из трёх файлов

```
tools/uitest/
    package.json       -- fengari + luaparse
    mock.lua           -- заглушка WoW API (~800 строк в реальном проекте)
    run.js             -- загрузка файлов аддона и прогон test*.lua
    test.lua, test2.lua ...
```

`package.json`:

```json
{ "name": "addon-uitest", "private": true, "dependencies": { "fengari": "^0.1.4", "luaparse": "^0.3.1" } }
```

Установка один раз: `npm install --cache ./.npmcache` (в архив/релиз не входит).

## run.js: загрузка кода аддона

```js
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const dir = path.join(__dirname, '..', '..');       // папка аддона
const files = {};
for (const f of fs.readdirSync(dir).filter(x => x.endsWith('.lua'))) {
  files[f] = fs.readFileSync(path.join(dir, f), 'utf8');
}
lua.lua_newtable(L);
for (const [name, src] of Object.entries(files)) {
  const b = to_luastring(src);
  lua.lua_pushlstring(L, b, b.length);
  lua.lua_setfield(L, -2, to_luastring(name));
}
lua.lua_setglobal(L, to_luastring('FILES'));         // Lua видит исходники
```

`test.lua` грузит их как клиент: `load(src, "@"..f, "t", MOCK)(ADDON, ns)`. Четвёртый
аргумент `load` — окружение, поэтому глобалы аддона попадают в `MOCK`, а не в системные.
`local ADDON, ns = ...` получает имя папки и общую таблицу — как в игре.

```lua
local function loadAddon()
    local ns = {}
    for _, f in ipairs(MOCK.addonFiles({ "Theme.lua", "Core.lua", "UI.lua" })) do
        local chunk, err = load(FILES[f], "@" .. f, "t", MOCK)
        if not chunk then error("не загрузился " .. f .. ": " .. tostring(err)) end
        chunk("MyAddon", ns)
    end
    return ns
end
local ns = loadAddon()
MOCK.event("ADDON_LOADED", "MyAddon")
```

## Что мокать в MOCK

Минимум для любого аддона:

* `CreateFrame(kind, name, parent, template)` → объект с `__scripts`, `__events`,
  `__text`, `__shown`, `__point`, `__w`, `__h`;
* метатаблица: неизвестный метод объекта → `noop` (клиент имеет сотни методов); но
  **критичные сеттеры должны быть строгими**:

```lua
local function checkColors(fname, minArgs, ...)
    local n = select("#", ...)
    if n < minArgs then error(fname .. ": мало аргументов", 2) end
    for i = 1, n do
        if type((select(i, ...))) ~= "number" then
            error(fname .. ": аргумент #" .. i .. " должен быть number", 2)
        end
    end
end
methods.SetTextColor = function(self, ...) checkColors("SetTextColor", 1, ...) end
methods.SetColorTexture = function(self, ...) checkColors("SetColorTexture", 3, ...) end
```

Именно эта строгость поймала `SetTextColor(таблица)` — в игре падало
`bad argument #1 to 'SetTextColor'`, а на «мягкой» заглушке проходило.

* `MOCK.event(name, ...)` — доставляет событие во все фреймы, где оно
  `RegisterEvent`-нуто (включая проверку «запрещённых» событий);
* `MOCK.fire(obj, "OnClick")` — вызвать обработчик виджета;
* `MOCK.find("текст")` — найти кнопку по подписи;
* `MOCK.print` собирает вывод в `MOCK.out` (тест читает и печатает);
* запрещённые события: `RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` в mock **бросает**
  `ADDON_ACTION_FORBIDDEN` — тест ловит попытку и падает, как упал бы клиент;
* таймеры: `C_Timer.After(delay, fn)` можно исполнять синхронно (проще) или складывать
  в очередь и «прокручивать» вручную (точнее);
* `StaticPopup_Show` — заглушка, запоминающая запрос (проверить, что «сброс» спрашивает
  подтверждение);
* `C_*`-неймспейсы — по мере надобности: `C_Item`, `C_Map`, `C_Container`,
  `C_MountJournal`, `C_PetJournal`, `C_ToyBox`, `C_TransmogCollection`, `C_TransmogSets`,
  `C_Transmog`, `C_Spell`, `C_EventUtils`, `C_MerchantFrame`, `C_Secrets`, `C_Cursor`.

## Как писать проверки

```lua
local fails = 0
local function check(cond, msg)
    if cond then print("  ok    " .. msg)
    else fails = fails + 1; print("  FAIL  " .. msg) end
end

print("-- окно")
ns.UI.Toggle()
check(ns.UI.frame ~= nil and ns.UI.frame:IsShown(), "окно открылось")
check(ns.UI.frame.footer:GetText():find("предметов: 1") ~= nil, "футер посчитал предметы")
```

Что покрывать (порядок полезности):

1. загрузка: БД создана, настройки по умолчанию, приветствие в чат, миграция версии;
2. основной сценарий: добавить запись, посчитать попытку, поймать выпадение, сообщение;
3. все вкладки/страницы — каждая открывается, пул строк не пуст, ничего не `nil`;
4. каждое событие из `Detect.lua` — доставить и проверить побочный эффект;
5. все слэш-команды, включая мусорный ввод (`/ma ыыы`, `/ma track abc`);
6. словари: одинаковый набор ключей во всех языках, нет дублей, `%s`/`%d` совпадают
   с русским исходником;
7. UI-геометрия: координаты/размеры элементов не выходят за окно;
8. персистентность: записал в БД → перезагрузка (новый прогон) → прочиталось.

Для сценариев «сломай клиент» — подменять мок-ответы: `C_Item.GetItemInfo = function() return nil end`
(неизвестный предмет), `C_TransmogCollection.PlayerHasTransmog = function() return false end`
(пустая коллекция), запрещённое событие (см. выше).

## Грабли самого стенда

**`attempt to index a nil value (global 'table')` на первом же файле.** Файлы аддона
грузятся с `env = MOCK`, и это окружение подменяет **все** глобалы, включая `table`,
`string`, `math`, `pairs`, `type`. → либо прокинуть стандартные библиотеки в MOCK явно
(`MOCK.table = table`, `MOCK.string = string`, ...), либо в конце `mock.lua` скопировать
все глобалы стенда:

```lua
for k, v in pairs(_G) do
    if MOCK[k] == nil then MOCK[k] = v end
end
```

**`UIParent`/`SlashCmdList`/`GameFontNormal` не видны из аддона.** Тот же корень: они
созданы как глобалы в окружении стенда, а аддон смотрит в MOCK. → копирование `_G` выше.

**Новый фрейм «уже показан».** В клиенте `CreateFrame` даёт **скрытый** фрейм; если заглушка
делает `__shown = true`, `UI.Toggle()` сразу его прячет, и тест «окно открылось» падает.
→ `__shown = false` по умолчанию (как в игре).

**`GetBuildInfo()` перепутан.** Порядок клиента: `version, build, date, tocversion`
(`"12.1.5", "70961", "date", 120105`). Если в заглушке toc стоит третьим, проверка
«боевой лог закрыт» получает не то число. → toc — **четвёртый** элемент.

**Глобал `L()` не виден в тесте.** `L` определяется внутри окружения аддона (MOCK), а
`test_*.lua` исполняется в обычном. → после загрузки аддона брать `local L = MOCK.L`
(или обращаться `ns.L`).



Два независимых дешёвых чека:

```bash
node check.js ../..          # luaparse, luaVersion 5.1 — синтаксис всех .lua
python tools/lua_check.py DataLoot.lua DataBuiltin.lua   # баланс function/if/for/end, скобок, строк
```

`luaparse` ловит опечатки в синтаксисе (лишняя запятая, незакрытая строка), но не
семантику. `lua_check.py` — грубая структурная проверка для **сгенерированных** файлов
(там сотни таблиц и легко потерять `end`).

## Ограничения стенда

* Ничего не рисует: «красиво/не наезжает» ловится только в игре (скриншот) или отдельными
  HTML-макетами (`gen_*_preview.py`).
* Не проверяет taint и защищённые вызовы — только моделирует их запрет.
* Не знает реальных сигнатур: если ошибся в моке, тест «зелёный», а игра падает.
  Поэтому реальные вызовы сверять с `wow-ui-source`.
* `GetStringHeight` на заглушке `nil` — в тестах подменять
  `MOCK.__stringHeight = function(fs) ... end`, иначе расчёт высот строк не проверить.

## Отладка в настоящем клиенте

```
/console scriptErrors 1        # показывать ошибки Lua
/reload                        # перезагрузить UI
/dump x                        # распечатать значение
/etrace                        # какие события приходят (включить/выключить)
/fstack                        # фрейм под курсором
/tinspect x                    # тип/значение
/console taintLog 1            # писать taint.log (потом выключить!)
```

Ошибки: `_retail_/Logs/` нет — смотреть BugSack/BugGrabber или чат при `scriptErrors 1`.
Если аддон «исчез из списка» или перестал реагировать — это не Lua-ошибка, а
`ADDON_ACTION_FORBIDDEN` из-за защищённого вызова (см. `08-pitfalls.md`).

Проверка SavedVariables вне игры: файл
`_retail_/WTF/Account/<АККАУНТ>/SavedVariables/<Аддон>.lua` — обычный Lua-код, его читают
скриптами (`loadfile`, `dofile` в отдельной песочнице) для синхронизации и сборки баз.

## Как автоматизировать прогон

* `node run.js` возвращает код 1 при любом FAIL — годится для хука перед сборкой.
* `PROBEFILE=probe.lua node run.js` (переменные окружения) — прогнать один отладочный
  сценарий, не весь набор.
* В CI/локально: `node check.js` → `node run.js` → `python tools/release.py`.
