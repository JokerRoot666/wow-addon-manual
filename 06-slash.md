# 6. Слэш-команды

## 6.1 Зачем это нужно

Пока нет окна, единственный способ что-то сделать — команда в чате. Даже когда окно есть,
`/аддон` — самый быстрый путь: он работает в бою, в инстансе и в момент, когда интерфейс
сломался.

## 6.2 Механика

> «Summary: assign a handler function to SlashCmdList[key], and create SLASH_key1, ...,
> SLASH_keyn global constants containing the desired command names, where key is some unique
> command-specific string.» — [Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command)

Четыре шага из источника:

> 1. «Pick a unique identifier for the slash command: e.g. MYFANCYADDON»
> 2. «Decide which slash commands you want to respond to: i.e. /myadd.»
> 3. «Assign your selected slash commands to SLASH_MYFANCYADDON1, SLASH_MYFANCYADDON2, etc global variables.»
> 4. «Write a slash command handler function (taking (msg, editBox) as arguments), and place assign it to SlashCmdList["MYFANCYADDON"].»

Пример дословно из источника:

```lua
SLASH_HELLOWORLD1, SLASH_HELLOWORLD2 = '/hiw', '/hellow';
function SlashCmdList.HELLOWORLD(msg, editBox)
    print("Hello, World!");
end
```

| Элемент | Роль | Ссылка |
|---|---|---|
| `SLASH_<ID><N>` | глобальная строка с текстом команды, включая `/`; `N` = 1, 2, 3… | [Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command) |
| `SlashCmdList[<ID>]` | функция-обработчик | там же |
| `msg` | всё, что игрок набрал после команды, одной строкой | там же |
| `editBox` | «the chat frame edit box frame that the slash command originated from» | там же |

## 6.3 Разбор аргументов

> «If the user types /yourcmd someargs into chat, the function handling /yourcmd is passed
> "someargs" as the first argument» — [Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command)

Источник предлагает простой паттерн:

```lua
local command, rest = msg:match("^(%S*)%s*(.-)$")
```

Дальше — своя логика. В DropLedger разбор двухступенчатый: сначала режем на слова, потом
сравниваем первое слово (`Core.lua:1183-1200`):

```lua
local function Split(input)
    local out = {}
    for word in tostring(input or ""):gmatch("%S+") do table.insert(out, word) end
    return out
end

function ns:RegisterSlash()
    SLASH_DROPLEDGER1 = "/dl"
    SLASH_DROPLEDGER2 = "/dropledger"

    SlashCmdList["DROPLEDGER"] = function(input)
        local argv = Split(input)
        local cmd = (argv[1] or ""):lower()

        if cmd == "" then
            if ns.UI then ns.UI.Toggle() end

        elseif cmd == "kills" then
            local sub = (argv[2] or ""):lower()
            ...
        elseif cmd == "track" then
            ...
        end
    end
end
```

Почему `Split`, а не один `match`: у команд есть второй уровень (`/dl prof fishing 20`,
`/dl reset all confirm`), и массив слов читается проще, чем вложенные паттерны.

Почему `:lower()` на команде: игрок напишет `/dl KILLS`, `/dl Kills` и `/dl kills`. Регистр
команды при этом значения не имеет — источник говорит об этом для макрокоманд: «The command
names are not case sensitive» ([Macro commands](https://warcraft.wiki.gg/wiki/Macro_commands)) —
но собственный обработчик получает `msg` как есть, поэтому нормализация на нас.

## 6.4 Правила и ограничения

| Правило | Цитата | Ссылка |
|---|---|---|
| Идентификатор обычно капсом | «Command identifiers are generally all caps, with underscores if necessary. These can also contain lowercase characters.» | [Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command) |
| Приоритет у Blizzard | «Default UI commands often have precedence over addon-created slash commands.» | там же |
| Конфликт между аддонами | «There is no defined precedence order for addon-created commands, so conflicts caused by multiple addons attempting to use the same slash command will resolve non-deterministically.» | там же |
| Кто владеет командой при совпадении ID | «the addon that executes the assignment last will own the slash command» | там же |
| Локализация текста команды | «The actual SLASH_<CommandId><Number> values should be localizable if you plan on your addon being translated, but the command ID will remain the same.» | там же |
| Метод объекта как обработчик | «If you want to set your slash command handler function to a method of an object, you will need to encapsulate the call to it inside a dummy function.» | там же |

Ограничений на длину имени и число алиасов в источниках нет — это отмечено в плане.

## 6.5 Полный рабочий пример: справка, подкоманды, защита от опечаток

Из `HelloWorld.lua` (файл проверен прогоном, см. 13.6):

```lua
SLASH_HELLOWORLD1 = "/hello"
SLASH_HELLOWORLD2 = "/hw"

SlashCmdList["HELLOWORLD"] = function(msg)
    local cmd, rest = tostring(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "help" then
        print("|cff33ff99HelloWorld|r: /hello help | count | reset")
    elseif cmd == "count" then
        HelloWorldDB.count = HelloWorldDB.count + 1
        print(string.format("|cff33ff99HelloWorld|r: счётчик = %d", HelloWorldDB.count))
    elseif cmd == "reset" then
        HelloWorldDB.count = 0
        print("|cff33ff99HelloWorld|r: счётчик обнулён")
    else
        print("|cff33ff99HelloWorld|r: неизвестная команда '" .. tostring(cmd) .. "'")
        _ = rest
    end
end
```

Три решения, которые стоит копировать:

1. **Пустой ввод = действие по умолчанию.** В DropLedger `/dl` без аргументов открывает
   окно; в HelloWorld — печатает справку. Игрок не должен гадать, что делать.
2. **Неизвестная подкоманда ругается, а не молчит.** Молчание игрок читает как «аддон
   сломался».
3. **Цвет через `|cffRRGGBB` и `|r`.** Это escape-последовательности клиента, а не теги;
   закрывающий `|r` обязателен, иначе весь чат ниже станет зелёным.

## 6.6 Справка: как не утонуть в 40 командах

В DropLedger справка — обычная таблица строк, которую склеивают один раз при загрузке
(`Core.lua:1136-1180`):

```lua
local HELP = table.concat({
    "|cff6ecbffDropLedger|r " .. ns.version,
    L("  |cffffff00/dl|r — открыть окно (вкладки: Список, Добавить, Профессии, ...)"),
    L("  |cffffff00/dl help|r — эта справка"),
    ...
}, "\n")

-- вывод построчно
for line in HELP:gmatch("[^\n]+") do print(line) end
```

Построчный вывод вместо одного `print(HELP)`: чат клиента обрезает длинные сообщения, а
`gmatch("[^\n]+")` отдаёт по строке на вызов.

## 6.7 Частые ошибки новичка

| Симптом | Причина | Источник |
|---|---|---|
| Команда не работает | нет `SLASH_<ID>1` — только `SlashCmdList[<ID>]` | [Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command) |
| Команда работает, но не та | конфликт ID с другим аддоном, «last assignment wins» | там же |
| `/мойаддон` не находится | в `SLASH_*` нет ведущего `/` | там же (пример с `'/hiw'`) |
| Аргументы приходят пустыми | обработчик объявлен как `function()` без `msg` | там же |
| Команда не работает в бою | обработчик трогает защищённый фрейм | [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting) |
| Регистр «не работает» | сравнение с `"Help"` без `:lower()` | наш код, 6.5 |

## 6.8 Источники раздела

* [Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command) — механика, пример, правила, конфликты.
* [Macro commands](https://warcraft.wiki.gg/wiki/Macro_commands) — регистр имён команд.
* [MACRO script](https://warcraft.wiki.gg/wiki/MACRO_script) — чем `/run` отличается от слэш-команды аддона (см. 10.3).
* `DropLedger/Core.lua:1136-1200` — рабочие команды и справка.
* `examples/hello/HelloWorld.lua` — минимальный рабочий обработчик.
