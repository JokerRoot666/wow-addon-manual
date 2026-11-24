# 10. Отладка: команды, окно ошибок, перехват, taint

## 10.1 Зачем это нужно

По умолчанию аддон **не показывает** свои ошибки. Он молча не работает, а игрок видит «ничего
не произошло». Первое, что делает стажёр в новой установке, — включает показ ошибок и учится
ими пользоваться.

## 10.2 Включить ошибки: `scriptErrors`

> «Lua Error is a popup window that appears when an addon or the base game interface encounters a
> coding error. It helps to identify the addon that failed, where in the code that it failed, and
> a brief description of the error.» — [Lua Error](https://warcraft.wiki.gg/wiki/Lua_Error)

> «Enables a popup for Lua errors.» Default Setting: `0`; Possible Settings: `0 :Off`, `1 :On`
> «In-game, type the following: `/console scriptErrors setting`»
> «Alternatively, you can exit wow, open the Config-cache.wtf file, and add the following line:
> `SET scriptErrors setting`» — [CVar scriptErrors](https://warcraft.wiki.gg/wiki/CVar_scriptErrors)

Порядок для стажёра:

1. В игре: `/console scriptErrors 1`.
2. Перезайти или `/reload`.
3. Сломать что-нибудь намеренно (например, вызвать несуществующую функцию) и убедиться, что
   окно появилось.

Есть ещё текстовые логи ошибок:

> «Enables the generation of textual error logs for Lua errors in secure execution paths.» —
> `0` выключает, `1` (по умолчанию) включает.
> — [CVar luaErrorExceptions](https://warcraft.wiki.gg/wiki/CVar_luaErrorExceptions)

> Внимание: имя файла этих логов в источниках **не указано**. Часто упоминаемый `FrameXML.log`
> на вики отсутствует как страница, а в `Blizzard_DebugTools` из wow-ui-source подстроки «log»
> нет вообще. Поэтому в учебнике мы не делаем вид, что знаем путь.

## 10.3 Ошибку можно поймать и обработать

| Функция | Что делает (цитата) | Ссылка |
|---|---|---|
| `geterrorhandler()` | «Returns the currently set error handler.» / «Receives a message as an argument, normally a string that is the second return value from `pcall()`» | [API:geterrorhandler](https://warcraft.wiki.gg/wiki/API:geterrorhandler) |
| `seterrorhandler(func)` | «Sets the error handler to the given function.» | [API:seterrorhandler](https://warcraft.wiki.gg/wiki/API:seterrorhandler) |
| `debugstack(...)` | «Returns a string representation of the current calling stack.» / «This is a modified version of Lua's debug.traceback() function.» | [API:debugstack](https://warcraft.wiki.gg/wiki/API:debugstack) |

Стандартный рецепт «ошибка + стек» выглядит так (источник помечает страницу как устаревшую,
потому что современный обработчик FrameXML уже пишет стек сам, но приём рабочий):

```lua
function ErrorWithStack(msg)
    msg = msg .. "\n" .. debugstack()
    _ERRORMESSAGE(msg)
end
seterrorhandler(ErrorWithStack)
```
— [Getting more useful errors](https://warcraft.wiki.gg/wiki/Getting_more_useful_errors)

Что важно понимать: `seterrorhandler` **переопределяет** обработчик для всего клиента. Если
ваш обработчик упадёт, ошибки перестанут показываться вовсе. Поэтому в аддонах чаще делают
наоборот: не трогают глобальный обработчик, а оборачивают свои рискованные вызовы в `pcall`
и печатают сами.

## 10.4 Инструменты в игре

> «The Blizzard DebugTools appeared in Patch 3.2 and added a set of new slash commands to assist
> with addon development and UI tweaking. Inspired/derived from Iriel's DevTools addon.»
> Список: `tableinspect`, `framestack`, `eventtrace`, `dump`.
> — [Blizzard DebugTools](https://warcraft.wiki.gg/wiki/Blizzard_DebugTools)

| Команда | Что делает | Ссылка |
|---|---|---|
| `/dump выражение` | «prints variable or expression results to the chat frame… Tables display up to 30 values, the rest are skipped and a message is shown.» | [MACRO dump](https://warcraft.wiki.gg/wiki/MACRO_dump) |
| `/run код` (`/script`) | «Executes Lua code.» / «The execution of the code is tainted.» / «The code may not contain any line breaks» | [MACRO script](https://warcraft.wiki.gg/wiki/MACRO_script) |
| `/fstack` (`/framestack`) | «shows all frames under the mouse cursor»; `Shift` — текстуры, `Ctrl` — инспектор таблицы, `Alt` — перебор | [MACRO framestack](https://warcraft.wiki.gg/wiki/MACRO_framestack) |
| `/etrace` (`/eventtrace`) | «tracks events using the EventTraceFrame… assists addon developers in figuring out what events fire in certain circumstances» | [MACRO eventtrace](https://warcraft.wiki.gg/wiki/MACRO_eventtrace) |
| `/tinspect` (`/tableinspect`) | «Opens the table inspector»; без аргумента — виджет под курсором | [MACRO tableinspect](https://warcraft.wiki.gg/wiki/MACRO_tableinspect) |
| `/reload` | «Reloads the user interface»; «Equivalent to typing /console reloadUI or /run ReloadUI()» | [MACRO reload](https://warcraft.wiki.gg/wiki/MACRO_reload) |
| `/console cvar value` | «Allows the user to view/change global client side options»; «You cannot use this command to display the current value of a cvar.» | [MACRO console](https://warcraft.wiki.gg/wiki/MACRO_console) |

Из Lua то же самое:

```lua
DevTools_Dump(myTable)      -- то же, что /dump myTable
print("значение:", value)   -- безопасно печатает nil
```
— [API DevTools Dump](https://warcraft.wiki.gg/wiki/API_DevTools_Dump), [API:print](https://warcraft.wiki.gg/wiki/API:print)

`print` лучше `DEFAULT_CHAT_FRAME:AddMessage`, потому что «it can safely be used to output nil
values» ([API:print](https://warcraft.wiki.gg/wiki/API:print)); `AddMessage` с `nil` упадёт.

## 10.5 Taint: почему «ломается не мой аддон, а игра»

> «When the UI first loads, all code and data from Blizzard signed FrameXML and AddOns (plus their
> saved variables) is secure, and all code and data from third-party AddOns (plus their saved
> variables) is tainted.» — [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting)

> «think of taint as sticky honey. Addon code is always tainted/sticky, and anything you touch
> also becomes sticky.» — там же

Диагностика описана прямо в вики:

> «if you get a message "Interface action failed because of an AddOn", this means that an AddOn
> interfered with the Blizzard UI in some way. To diagnose this, enter the following into chat
> "`/console taintLog 1`" and restart the game and try to reproduce it.»
> «you can quit the game and search through the file `Logs\taint.log` for the word "`blocked`"»
> «you can turn off logging by entering the following into chat "`/console taintLog 0`"»
> — [AddOn](https://warcraft.wiki.gg/wiki/AddOn)

Значения `taintLog` ([CVar taintLog](https://warcraft.wiki.gg/wiki/CVar_taintLog)):

| Значение | Что пишет |
|---|---|
| `0` | всё выключено (по умолчанию) |
| `1` | «Log blocked action errors and taint events leading up to them» |
| `2` | «tainted reads/writes of global variables» |
| `3` | upvalues |
| `4` | table fields |
| `5` | «writes of secret values to globals/upvalues/table fields» (добавлено в 12.0.1) |

И главное про файл:

> «Enables logging of UI taint messages to `World of Warcraft\Logs\taint.log`. Like all logs in
> WoW, this file is written periodically and once at logout.» — [CVar taintLog](https://warcraft.wiki.gg/wiki/CVar_taintLog)

То есть лог появляется **не сразу**: надо выйти из игры (или `/reload`), потом смотреть файл.

## 10.6 Секретные значения ломают привычную отладку

`print(secretValue)` в 12.x ведёт себя не так, как раньше: сравнение и арифметика запрещены, а
`/dump` научился печатать содержимое секретов:

> «`/dump` will now print the contents of secret values to the chat frame.»
> — [Patch 12.0.0/API changes/notes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes)

Проверки, которые надо ставить в отладочный код:

```lua
if issecretvalue and issecretvalue(v) then
    print("значение секретное, сравнивать нельзя")
else
    print("значение:", v)
end
```

Источник предикатов и списка запретов — [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values)
(подробно в 9.10). Там же — CVar'ы, которыми можно **симулировать** ограничения без похода в
подземелье: `addonCombatRestrictionsForced`, `addonEncounterRestrictionsForced`,
`addonChallengeModeRestrictionsForced`, `addonPvPMatchRestrictionsForced`,
`addonMapRestrictionsForced`, `addonChatRestrictionsForced`; «They will not be saved across game
restarts».

## 10.7 Свой отладочный канал

Главный приём: **не `print` в бою, а свой флаг**. В DropLedger это `ns.Debug`:

```lua
function ns.Debug(msg, ...)
    if ns.db and ns.db.settings.verbose then ns.Print(msg, ...) end
end
```

Включается командой `/dl debug`. Почему так:

* в релизе ничего не печатается, но код остаётся;
* одна команда включает всё сразу, не надо искать 40 `print`;
* сообщения идут через `ns.Print`, то есть с префиксом аддона и локализованным текстом.

Второй уровень — живой лог событий (`/dl events`, `Trace.lua`): аддон печатает, какие события
к нему пришли и что он с ними сделал. Это дешевле, чем `/etrace`, потому что показывает уже
**свой** разбор:

```lua
-- Trace.lua, упрощённо
function Trace.Mark(fmt, ...)
    if not Trace.enabled then return end
    local line = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    DEFAULT_CHAT_FRAME:AddMessage("|cff808080trace|r " .. line)
end
```

## 10.8 Производительность: измерить, а не угадать

| Инструмент | Что даёт | Ссылка |
|---|---|---|
| `debugprofilestop()` | «Returns the time in milliseconds since the last debugprofilestart call»; «Calling this function, despite its name, does NOT stop the timer» | [API:debugprofilestop](https://warcraft.wiki.gg/wiki/API:debugprofilestop) |
| `UpdateAddOnMemoryUsage()` | «Scans through memory profiling data and updates the per-addon statistics.» | [API:UpdateAddOnMemoryUsage](https://warcraft.wiki.gg/wiki/API:UpdateAddOnMemoryUsage) |
| CVar `scriptProfile` | профилировщик CPU; проверить, что не остался включён: `/script ChatFrame1:AddMessage(tostring(GetCVar("scriptProfile")))` | [Useful AddOns for debugging/profiling](https://warcraft.wiki.gg/wiki/Useful_AddOns_for_debugging/profiling) |

Паттерн замера:

```lua
local t0 = debugprofilestop()
RefreshList(items)
local ms = debugprofilestop() - t0
if ms > 50 then ns.Debug("RefreshList: %.1f мс на %d строк", ms, #items) end
```

В DropLedger этот же замер выведен в команду `/dl perf` — так нашли, что перерисовка 300 строк
занимает больше кадра, и переделали на пул.

## 10.9 Как читать ошибку

Типичная строка в окне ошибок:

```
1x [ADDON_LOADED] DropLedger\Core.lua:1044: attempt to index a nil value (global 'DropLedgerDB')
```

| Часть | Что значит |
|---|---|
| `[ADDON_LOADED]` | в каком событии/обработчике |
| `DropLedger\Core.lua:1044` | файл и **строка** |
| `attempt to index a nil value (global 'DropLedgerDB')` | что именно не так |

Читать надо снизу вверх: сначала «что», потом «где». Если в тексте есть `secret`, ищите
сравнение или арифметику на значении от клиента (9.10). Если `blocked`/`forbidden` — ищите
защищённый вызов (10.5).

## 10.10 Частые ошибки новичка

| Симптом | Причина | Источник |
|---|---|---|
| «Ошибок нет», но аддон не работает | `scriptErrors` выключен | [CVar scriptErrors](https://warcraft.wiki.gg/wiki/CVar_scriptErrors) |
| `taint.log` пустой | лог пишется «periodically and once at logout», игра не закрыта | [CVar taintLog](https://warcraft.wiki.gg/wiki/CVar_taintLog) |
| Ошибка исчезла после установки своего обработчика | переопределили `seterrorhandler` и внутри упали | [API:seterrorhandler](https://warcraft.wiki.gg/wiki/API:seterrorhandler) |
| `/dump` показывает не всё | «Tables display up to 30 values» | [MACRO dump](https://warcraft.wiki.gg/wiki/MACRO_dump) |
| `/run` не сработал | многострочный код | [MACRO script](https://warcraft.wiki.gg/wiki/MACRO_script) |
| Не видно, какой фрейм перехватывает клик | не использовали `/fstack` | [MACRO framestack](https://warcraft.wiki.gg/wiki/MACRO_framestack) |
| Не понятно, какие события вообще идут | не использовали `/etrace` | [MACRO eventtrace](https://warcraft.wiki.gg/wiki/MACRO_eventtrace) |
| `print` падает на `nil` | `AddMessage` вместо `print` | [API:print](https://warcraft.wiki.gg/wiki/API:print) |

## 10.11 Источники раздела

* [Lua Error](https://warcraft.wiki.gg/wiki/Lua_Error), [CVar scriptErrors](https://warcraft.wiki.gg/wiki/CVar_scriptErrors), [CVar luaErrorExceptions](https://warcraft.wiki.gg/wiki/CVar_luaErrorExceptions) — окно ошибок и логи.
* [API:geterrorhandler](https://warcraft.wiki.gg/wiki/API:geterrorhandler), [API:seterrorhandler](https://warcraft.wiki.gg/wiki/API:seterrorhandler), [API:debugstack](https://warcraft.wiki.gg/wiki/API:debugstack), [Getting more useful errors](https://warcraft.wiki.gg/wiki/Getting_more_useful_errors).
* [Blizzard DebugTools](https://warcraft.wiki.gg/wiki/Blizzard_DebugTools), [MACRO dump](https://warcraft.wiki.gg/wiki/MACRO_dump), [MACRO framestack](https://warcraft.wiki.gg/wiki/MACRO_framestack), [MACRO eventtrace](https://warcraft.wiki.gg/wiki/MACRO_eventtrace), [MACRO tableinspect](https://warcraft.wiki.gg/wiki/MACRO_tableinspect), [MACRO script](https://warcraft.wiki.gg/wiki/MACRO_script), [MACRO console](https://warcraft.wiki.gg/wiki/MACRO_console), [MACRO reload](https://warcraft.wiki.gg/wiki/MACRO_reload).
* [API DevTools Dump](https://warcraft.wiki.gg/wiki/API_DevTools_Dump), [API:print](https://warcraft.wiki.gg/wiki/API:print).
* [CVar taintLog](https://warcraft.wiki.gg/wiki/CVar_taintLog), [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting), [AddOn](https://warcraft.wiki.gg/wiki/AddOn) (процедура диагностики).
* [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values), [Patch 12.0.0/API changes/notes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes).
* [API:debugprofilestop](https://warcraft.wiki.gg/wiki/API:debugprofilestop), [API:UpdateAddOnMemoryUsage](https://warcraft.wiki.gg/wiki/API:UpdateAddOnMemoryUsage), [Useful AddOns for debugging/profiling](https://warcraft.wiki.gg/wiki/Useful_AddOns_for_debugging/profiling).
* `DropLedger/Trace.lua`, `DropLedger/Core.lua` (`ns.Debug`, `/dl debug`, `/dl perf`) — как это делается в рабочем аддоне.
