# 01. Анатомия аддона

## Что такое аддон технически

Папка `Interface/AddOns/<Имя>/` внутри каталога игры (`_retail_`, `_ptr_`, `_classic_`),
внутри — файл `<Имя>.toc` со списком файлов и метаданными. Клиент читает TOC, грузит
указанные файлы по порядку в **общее окружение аддона** (`local ADDON, ns = ...` получает
имя папки и одну общую таблицу). Больше ничего автоматически не происходит.

Песочница: Lua 5.1 (bit-операции через `bit`/`bit32`), доступны `string`, `table`, `math`,
`os.time`/`date`, `C_*`-неймспейсы. Нет `io`, `os`-файлов, `package`, `require`, сокетов.
Сеть недоступна принципиально — любые данные «из интернета» попадают в аддон только через
сгенерированные Lua-таблицы (см. `06-external-data.md`).

Состояние между сессиями — только `SavedVariables` (сериализуются клиентом на выходе).
Память между сессиями не переживает: всё, что нужно помнить, кладётся в БД аддона.

## Файл TOC

Пример, который реально работает (retail 12.1.5):

```toc
## Interface: 120105
## Title: Drop Ledger
## Title-ruRU: Счётчик дропа
## Notes: Отслеживание редкого дропа: попытки, шанс, статистика по персонажу и аккаунту
## Notes-ruRU: Статистика выпадения редких вещей
## Author: lead
## Version: 1.13.6
## SavedVariables: DropLedgerDB
## SavedVariablesPerCharacter: DropLedgerCharDB
## IconTexture: Interface\Icons\INV_Misc_Coin_01
## X-Curse-Project-ID: 000000

Locale.lua
Theme.lua
Core.lua
Data.lua
UI.lua
```

Поля:

| Поле | Обязательно | Смысл |
|---|---|---|
| `## Interface: 120105` | да | версия клиента: `major*10000 + minor*100 + patch` (12.1.5 → `120105`, 11.0.2 → `110002`). Несовпадение = «устаревший аддон» и выключение по умолчанию |
| `## Title` | да | имя в списке аддонов; `## Title-ruRU` и т.п. — локализованные варианты |
| `## Notes` | желательно | описание, видно в списке и в `## Notes-<locale>` на своём клиенте |
| `## Version` | да | версия аддона (своя, не клиентская) |
| `## Author` | желательно | автор |
| `## SavedVariables` | если нужна БД | имена глобалов через запятую, аккаунтные |
| `## SavedVariablesPerCharacter` | если нужна БД персонажа | то же, но на персонажа |
| `## IconTexture` | желательно | иконка аддона в списке, **без** расширения |
| `## Dependencies` | по нужде | жёсткие зависимости (без них аддон не грузится) |
| `## OptionalDeps` | по нужде | порядок загрузки, если есть |
| `## LoadOnDemand: 1` | редко | грузить по `C_AddOns.LoadAddOn` |
| `## Category` | опционально | раздел в списке аддонов |
| `## X-Curse-Project-ID`, `## X-Wago-ID` | для релиза | связь с сайтами публикации |

Правила: кодировка UTF-8 (в старых клиентах — без BOM), переносы строк любые, комментарии
в TOC — только строки, начинающиеся с `#`. Файлы перечисляются относительно TOC; подпапки
**не грузятся автоматически** — если хочется разложить по каталогам, каждый файл пишется
полным путём (`Libs/LibStub.lua`).

Имя TOC не обязано совпадать с папкой, но должно — иначе путаница при обновлениях;
`local ADDON` = имя **папки**.

## XML (опционально)

`Bindings.xml` описывает привязки клавиш:

```xml
<Bindings>
    <Binding name="DROPLEDGER_TOGGLE" header="DROPLEDGER">
        MyAddon_Toggle()
    </Binding>
</Bindings>
```

`header` — ключ глобала `BINDING_HEADER_<header>` для подписи группы в «Назначениях
клавиш»; без него группа будет без названия. Функция в теле — глобальная.

В `## Interface`-времена XML-шаблоны тоже живы (`<Ui><Frame name="...">`), но современный
путь — создавать фреймы кодом через шаблоны Blizzard (`CreateFrame(..., "UIPanelButtonTemplate")`).

## Загрузка: порядок и жизненный цикл

1. Клиент загружает `Dependencies` → файлы TOC **в порядке перечисления** → `ADDON_LOADED`
   для этого аддона (глобалы SavedVariables уже заполнены).
2. `PLAYER_LOGIN` — персонаж вошёл, `UnitName("player")` и прочее доступны.
3. `PLAYER_ENTERING_WORLD` — мир/инстанс готов, приходит и при каждом входе/зоне.

Каркас:

```lua
local ADDON, ns = ...

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")

    MyAddonDB = MyAddonDB or {}
    ns.db = MyAddonDB
    if not ns.db.settings then ns.db.settings = {} end

    -- тяжёлую инициализацию и регистрацию событий лучше отложить:
    -- внутри ADDON_LOADED защищённые вызовы иногда помечаются taint
    C_Timer.After(0, function()
        ns.RegisterEvents()
    end)
end)
```

Почему `C_Timer.After(0, ...)`: в 12.x регистрация части событий и работа с защищёнными
фреймами внутри `ADDON_LOADED` иногда считается taint-нарушением, и клиент блокирует
аддон. Отложенный на один кадр старт это лечит. Это проверено на Drop Ledger
(см. `08-pitfalls.md`).

## SavedVariables

```lua
-- объявлено в TOC: ## SavedVariables: MyAddonDB
MyAddonDB = {
    version = 1,                       -- своя схема, для миграций
    settings = { msg = true },
    ui = { tab = "list", pos = { x = 100, y = -200 } },
    items = { [50818] = { tries = 3 } },
}
```

Что важно:

* Сохраняются только `nil`/`boolean`/`number`/`string`/таблицы с ключами-числами/строками;
  функции и userdata **теряются молча**, циклы в таблицах = ошибка сериализации.
* Пишется на logout / `/reload` / выходе из игры (не мгновенно при изменении).
* Файл: `_retail_/WTF/Account/<АККАУНТ>/SavedVariables/<Аддон>.lua` (аккаунтные) и
  `.../WTF/<Персонаж-Рилм>/SavedVariables/<Аддон>.lua` (персонажные). Формат — обычный
  Lua-код, который можно читать скриптом вне игры (так делают сборщики шансов и синхронизация).
* Не хранить секундные счётчики «на будущее»: файл читается клиентом при входе, лишние
  мегабайты замедляют логин. Большие справочники — в `Data*.lua`, а не в SavedVariables.

Миграция схемы:

```lua
-- db = ApplyDefaults(DEFAULTS, db): значения по умолчанию первым аргументом
local function ApplyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = ApplyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
```

Так новые ключи появляются у старых пользователей, а их значения не затираются. Для
переименований — разовая миграция по `db.version` + запись новой версии.

## Слэш-команды

```lua
SLASH_MYADDON1 = "/ma"
SLASH_MYADDON2 = "/myaddon"
SlashCmdList["MYADDON"] = function(input)
    local cmd, rest = (input or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then ns.UI.Toggle(); return end
    if cmd == "help" then ns.Print(ns.Help); return end
    if cmd == "lang" then
        ns.Locale.Set(rest)
        return
    end
end
```

Регистрировать в `ADDON_LOADED` (глобалы `SLASH_*`), а не в момент загрузки файла — так
безопаснее для taint. Не забыть `"|cffffff00/ma help|r"` в подсказке.

## Структура проекта, которая выдержала 13 версий

```
MyAddon/
    MyAddon.toc
    Locale.lua            -- L(), выбор языка, словари подгружаются файлами
    Locale_en.lua ...     -- по одному файлу на язык (см. 07)
    Theme.lua             -- палитры/геометрия (если свой дизайн)
    Trace.lua             -- живой лог событий для диагностики
    Core.lua              -- БД, настройки, слэш, API-обёртки
    Data.lua              -- ручной справочник
    DataBuiltin.lua       -- СГЕНЕРИРОВАННЫЕ базы (руками не править!)
    Stats.lua             -- математика, тексты, имена/иконки
    Detect.lua            -- события клиента и их разбор
    UI.lua                -- окно, вкладки, страницы, миникарта, опции
    Popup.lua             -- плашка уведомлений
    Bindings.xml
    tools/                -- скрипты сборки баз; в игру не грузится (нет в TOC)
        uitest/           -- тесты на mock-клиенте (node + fengari)
```

Правила именования: имя папки = TOC = `ADDON`; модули складываются в `ns` (`ns.Loot`,
`ns.UI`); `Data*.lua` — только генераторы; у каждого файла шапка-комментарий «что здесь».

## Практика: пустой аддон за 5 минут

1. Папка `Interface/AddOns/Hello/`, файл `Hello.toc`:
   ```toc
   ## Interface: 120105
   ## Title: Hello
   ## Notes: минимальный аддон
   ## Version: 1.0.0
   Hello.lua
   ```
2. `Hello.lua`:
   ```lua
   local ADDON, ns = ...
   print(("|cff6ecbff%s|r: загружен"):format(ADDON))
   ```
3. `/reload` — в чате строка. Дальше наращивать по `09-snippets.md`.

## Частые ошибки на этом слое

* Файл по TOC не найден → аддон не грузится, в `taint.log`/ошибках «Failed to load».
  Проверять пути и регистр (Windows прощает, клиент — нет).
* Забыт `## SavedVariables` → БД `nil` каждый вход, «настройки не сохраняются».
* `local ADDON, ns = ...` забыт → `ADDON` = nil, все события-фильтры по имени аддона
  проходят мимо.
* Регистрация событий в момент загрузки файла (не в `ADDON_LOADED`) → гонка с клиентом.
* `## Interface` от прошлого патча → «устарел» и выключен, даже если всё грузится.
* Хранение в БД функций/фреймов → при следующем входе молча `nil`.
