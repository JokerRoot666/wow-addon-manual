# 2. Lua 5.1 в контексте WoW

## 2.1 Зачем это нужно

Весь аддон — это Lua. Не «похожий на Lua», а именно Lua 5.1 с несколькими добавками и
несколькими изъятиями:

> «Only a subset of version 5.1 of the official Lua specification is implemented, and should
> suit most addon maker's needs.» — [Lua](https://warcraft.wiki.gg/wiki/Lua)

> «World of Warcraft uses a modified version of Lua 5.1 that supports taint. Notably,
> operating system and file I/O libraries are not present.» —
> [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions)

Практический вывод: **нет `io`, нет `os`, файлов читать и писать нельзя вообще**. Единственный
способ что-то сохранить — `SavedVariables` (раздел 7). Никакого `require` в списке
Lua-функций тоже нет, поэтому «подключить библиотеку» = положить её `.lua` в свою папку и
перечислить в `.toc` (так и делает шаблон FRIKKern: `Libs\LibStub\LibStub.lua`).

Что есть из стандартной библиотеки (полный список — [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions)):
`assert`, `error`, `pcall`, `xpcall`, `select`, `type`, `tonumber`, `tostring`, `pairs`,
`ipairs`, `next`, `unpack`, `setmetatable`, `getmetatable`, `rawget`, `rawset`, `rawequal`,
`loadstring`, `setfenv`, `getfenv`, `collectgarbage`, `print`, плюс таблицы `math`, `string`,
`table`, `coroutine`, `bit`.

## 2.2 Переменные и область видимости

Правило источника звучит коротко:

> «Try to use local variables whenever possible.» / «Ideally an addon should use only a single
> unique global.» / «Use `_G` instead of the deprecated `getglobal()`» —
> [Lua Coding Tips](https://warcraft.wiki.gg/wiki/Lua_Coding_Tips)

Почему это не стилистика, а техника безопасности: глобальная переменная — общая на весь
клиент. Два аддона с одинаковым именем глобала затирают друг друга, и виноват будет тот,
кто загрузился позже.

```lua
-- плохо: имя займёт всю игру, кто-то другой может сделать то же самое
MyAddonItems = {}

-- хорошо: локальная переменная файла
local items = {}

-- хорошо: наружу торчит ровно одна таблица с уникальным именем
MyAddon = { items = items }
```

В DropLedger наружу выставлены только сама таблица-неймспейс и две переменные
`SavedVariables`, которые требует клиент (`DropLedgerDB`, `DropLedgerCharDB`) — они обязаны
быть глобальными, иначе клиент их не найдёт (раздел 7).

`local` живёт до конца файла (или до конца блока `do … end`). Именно поэтому в DropLedger
`local ADDON, ns = ...` в начале каждого файла даёт **новые** локальные переменные, а
`ns` — общая таблица, пришедшая извне.

## 2.3 Таблицы

Единственная структура данных. Массив, словарь, объект, множество — всё это таблица.

```lua
local list = { "a", "b" }                 -- массив: list[1] == "a"
local map  = { tries = 0, wins = 0 }      -- словарь: map.tries == 0
local both = { "a", tries = 0 }           -- можно и так, но не надо

list[#list + 1] = "c"                     -- добавить в конец: #list == 3
for i, v in ipairs(list) do end           -- по порядку, с 1
for k, v in pairs(map) do end             -- в произвольном порядке
```

Что важно помнить:

* индексация с **1**, не с 0;
* `#t` определён только для «последовательной» части таблицы — если внутри дырки, длина
  непредсказуема;
* `pairs` не гарантирует порядок, `ipairs` идёт по 1, 2, 3 и останавливается на первом `nil`;
* ключом может быть строка, число, boolean, таблица; `nil` ключом быть не может.

В DropLedger база предметов — обычная таблица «число → таблица»:

```lua
-- DropLedgerDB
items[itemID] = { chance = 0.5, mode = "npc", src = "Шпиль" }
acc[itemID]   = { tries = 120, wins = 3 }
```

Такой структурой удобно считать шанс: `wins / tries`, и легко достать по `itemID`, который
пришёл из события.

## 2.4 Функции, аргументы, `...`

```lua
local function add(a, b) return a + b end
local f = function(x) return x * 2 end      -- то же самое

-- переменное число аргументов
local function log(fmt, ...)
    if select("#", ...) > 0 then            -- select("#", ...) — сколько аргументов пришло
        fmt = string.format(fmt, ...)
    end
    print(fmt)
end
```

`select("#", ...)` — идиома, без которой не работает «необязательный формат». Из DropLedger
(`Core.lua:250`, `Locale.lua:168`):

```lua
function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff6ecbffDropLedger|r: " .. tostring(msg))
end
```

Функция возвращает несколько значений — это штатно:

```lua
local name, realm = UnitName("player")     -- два возврата
```

Если функция вызывается не последней в списке аргументов, лишние возвраты теряются:
`f(UnitName("player"))` передаст только имя. Лечится скобками `f((UnitName("player")))` —
тогда останется одно значение.

## 2.5 Замыкания

Функция «запоминает» локальные переменные, которые были видны в момент её создания. На этом
держится половина UI-кода: обработчик кнопки помнит, к какому предмету он относится.

```lua
for _, itemID in ipairs(ids) do
    local row = CreateFrame("Button", nil, parent)
    row:SetScript("OnClick", function()
        -- itemID здесь — свой для каждой итерации, потому что local внутри цикла
        print("нажат предмет", itemID)
    end)
end
```

Если убрать `local` и использовать переменную, объявленную снаружи цикла, все кнопки будут
показывать последний предмет — классическая ошибка.

## 2.6 Метатаблицы

`setmetatable`/`getmetatable` в списке разрешённых функций есть
([Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions)), но **отдельной страницы про
метатаблицы на вики нет** (проверено: `Metatable` — 404). Поэтому здесь только минимум,
который реально нужен в аддонах, и с оговоркой: это поведение языка Lua 5.1, а не API игры.

Самый частый случай — таблица с значениями по умолчанию:

```lua
local defaults = { scale = 1, theme = "steel" }

local function withDefaults(t)
    return setmetatable(t or {}, { __index = defaults })
end

local cfg = withDefaults({ scale = 1.5 })
print(cfg.scale)   -- 1.5 — своё значение
print(cfg.theme)   -- "steel" — взялось из defaults через __index
```

Второй частый случай — объект с методами:

```lua
local Widget = {}
Widget.__index = Widget

function Widget.new(parent)
    return setmetatable({ frame = CreateFrame("Frame", nil, parent) }, Widget)
end

function Widget:Show() self.frame:Show() end
```

Осторожно с `__index`-таблицей: запись `cfg.theme = "gold"` создаст поле **в самой** `cfg`,
а не в `defaults`. Это ровно то, что нужно для настроек, и ровно то, что ломает чужие
аддоны, когда `defaults` оказывается общей таблицей модуля.

## 2.7 Модульная схема аддона: `local ADDON, ns = ...`

Клиент выполняет каждый файл из `.toc` как отдельный кусок кода и передаёт ему два
параметра: имя аддона и общую таблицу. Первая строка любого файла DropLedger:

```lua
local ADDON, ns = ...
```

Дальше файлы «видят» друг друга только через `ns`:

```lua
-- Core.lua
ns.name    = ADDON
ns.version = "1.13.6"

-- UI.lua (загружается позже)
local ADDON, ns = ...
local L = ns.L            -- функция перевода из Locale.lua
local C = ns.Theme.colors -- палитра из Theme.lua
```

Почему так, а не через глобалы: порядок загрузки задан `.toc`, и если файл `UI.lua` стоит
ниже `Theme.lua`, то `ns.Theme` уже существует. Обратное неверно, и это самая частая
причина «attempt to index a nil value» при первом запуске.

Шаблон FRIKKern делает то же самое и пишет об этом прямо в `.toc`: «Each file receives
(addonName, namespace) as its ... varargs» —
[MyAddon.toc](https://raw.githubusercontent.com/FRIKKern/WoW-Midnight-Addon-Template/HEAD/template/MyAddon.toc).

## 2.8 Корутины

Список функций есть — `coroutine.create`, `resume`, `running`, `status`, `wrap`, `yield`
([Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions)); отдельной страницы с
объяснениями на вики нет.

В аддонах корутины нужны для одного сценария: длинная работа, которую надо размазать по
кадрам, чтобы игра не замирала. Идея: функция периодически делает `coroutine.yield()`, а
«насос» вызывает `resume` раз в кадр.

```lua
local worker = coroutine.create(function()
    for i = 1, 10000 do
        -- ... обработка одного предмета ...
        if i % 200 == 0 then coroutine.yield() end
    end
end)

local pump = CreateFrame("Frame")
pump:SetScript("OnUpdate", function()
    if coroutine.status(worker) == "dead" then return end
    coroutine.resume(worker)
end)
```

В DropLedger корутин нет: там тяжёлые сканы режутся на порции через `C_Timer.After`
(раздел 9.5). Для стажёра правило простое: **сначала таймер, корутина — если таймера не
хватает**.

## 2.9 `pcall`, `xpcall` и почему ошибка не должна ронять загрузку

```lua
local ok, result = pcall(function() error("бум") end)
print(ok)       -- false
print(result)   -- "бум"
```

`xpcall` дополнительно принимает обработчик — им пользуется игра, чтобы показать окно
ошибки (раздел 10.5).

В DropLedger каждый необязательный шаг загрузки обёрнут, потому что падение одного модуля не
должно убивать весь аддон (`Core.lua:1060-1100`):

```lua
local okSync, errSync = pcall(ns.SyncChar)
if not okSync then ns.Debug("SyncChar: %s", tostring(errSync)) end
```

## 2.10 Taint — то, из-за чего аддон «ломает» чужой интерфейс

> «The User Interface API mandates human decision-making, particularly in combat, by protecting
> many functions from insecure or tainted use.» —
> [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting)

> «Taint remains for the rest of the game until the player relogs or reloads the interface,
> which can be crippling because protected functions will refuse to operate if they detect a
> potentially insecure execution path.» — там же

Простыми словами: код аддона помечен как «недоверенный». Если этот код тронет защищённую
функцию или защищённый фрейм, метка «недоверенного» переедет на них — и дальше Blizzard-код
начнёт отказываться работать. Симптом в игре: «Interface action failed because of an AddOn»
(событие `ADDON_ACTION_BLOCKED`,
[Event:ADDON_ACTION_BLOCKED](https://warcraft.wiki.gg/wiki/Event:ADDON_ACTION_BLOCKED)).

Инструменты, которые источник называет безопасными:

> «`hooksecurefunc(["table"], "name", func)` : Addons can 'post-hook' a secure global function,
> inserting their own custom function to be executed after the original» и
> «`frame:HookScript("scriptTypeName", func)`» —
> [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting)

Правило для стажёра: **не переопределяй чужие функции и не трогай защищённые фреймы**.
Хочешь вмешаться — `hooksecurefunc`/`HookScript`, которые не подменяют оригинал.

## 2.11 Что из Lua нельзя использовать в аддоне

| Чего нет | Почему | Чем заменить |
|---|---|---|
| `io.*`, `os.*` | «operating system and file I/O libraries are not present» — [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) | `SavedVariables` |
| файлы, сеть, процессы | там же | нет замены, это клиент, а не скрипт |
| `require` | в списке Lua-функций отсутствует | файлы в `.toc`, `Libs\…` в своей папке |
| `#` на секретном значении | 12.x, [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values) | `issecretvalue()` и обходные пути (раздел 9.7) |

## 2.12 Частые ошибки новичка

| Симптом | Причина | Источник |
|---|---|---|
| «attempt to index a nil value (global 'MyAddon')» | файл загрузился раньше того, который создаёт таблицу | порядок в `.toc` |
| Все кнопки делают одно и то же | переменная цикла не `local` | замыкания, 2.5 |
| «attempt to compare number with nil» | из таблицы достали `nil` вместо числа | проверять `if v == nil then` |
| Значение «теряется» между вызовами | переменная объявлена внутри функции без `upvalue` | `local` на уровне файла |
| Аддон ломает Blizzard-панель | переопределён защищённый фрейм/функция | taint, 2.10 |
| Ошибка при `#t` | в таблице дырки | считать вручную или хранить `n` |

## 2.13 Источники раздела

* [Lua](https://warcraft.wiki.gg/wiki/Lua) — версия, «subset of 5.1».
* [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) — полный список доступных функций и библиотек; отсутствие `io`/`os`.
* [Lua Coding Tips](https://warcraft.wiki.gg/wiki/Lua_Coding_Tips) — `local`, один глобал, `_G`.
* [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting) — taint, `hooksecurefunc`, `HookScript`.
* [RestrictedEnvironment](https://warcraft.wiki.gg/wiki/RestrictedEnvironment) — что доступно в защищённом окружении.
* `DropLedger/Core.lua`, `DropLedger/Locale.lua` — рабочие примеры `...`, `select("#")`, `pcall`.
