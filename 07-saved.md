# 7. Сохранение данных: SavedVariables

## 7.1 Зачем это нужно

В Lua внутри WoW нет файлов (`io`, `os` отсутствуют — раздел 2.11). Единственный мост между
сессиями — переменные, которые клиент сам записывает на диск и читает при следующем входе.
Они называются `SavedVariables`.

> «An addon may need to save settings and data between game sessions - that is, some information
> may need to persist through a user log out. … Variables that are saved and restored by the
> client are called SavedVariables.»
> — [Saving variables between game sessions](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions)

## 7.2 Объявление

> «Summary: to save a global variable `FOOBAR`, add `##SavedVariables: FOOBAR` or
> `##SavedVariablesPerCharacter: FOOBAR` to an addon's .toc file.»
> — [Saving variables between game sessions §Specifying which variables to save](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Specifying_which_variables_to_save)

| Директива | Что сохраняется (цитата) |
|---|---|
| `## SavedVariables` | «Variables listed after this directive are saved on a per-account basis: if any of the characters on that account logs in, those variables will be restored.» |
| `## SavedVariablesPerCharacter` | «a separate copy of the variable is stored and restored for each character» |

Обе директивы можно указывать несколько раз — «may be specified multiple times, with later
instances appending to the list» ([TOC format §SavedVariables](https://warcraft.wiki.gg/wiki/TOC_format#SavedVariables)).

Ключевое требование: **переменная должна быть глобальной**. `local MyDB` не сохранится —
клиент ищет имя в глобальной таблице.

## 7.3 Где это лежит на диске

Дословно из [§Storage](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Storage):

```
WTF\Account\ACCOUNTNAME\SavedVariables.lua                                   — служебный файл Blizzard
WTF\Account\ACCOUNTNAME\SavedVariables\AddOnName.lua                         — на аккаунт
WTF\Account\ACCOUNTNAME\RealmName\CharacterName\SavedVariables\AddOnName.lua — на персонажа
```

> «Deleting or renaming the WTF folder will reset the settings of all of your addons.» — там же

Для стажёра это означает: «у меня ничего не сохраняется» чаще всего лечится не кодом, а
проверкой, что файл вообще появился по этому пути после выхода из игры.

## 7.4 Когда читаются и когда пишутся

> «1. WoW FrameXML code is loaded and executed. 2. Addon code is loaded and executed. 3. Saved
> variables for one addon a time are loaded and executed, then ADDON_LOADED event is fired for
> that addon. 4. PLAYER_LOGIN fires once all non-load-on-demand addons have been loaded…»
> — [§The loading process](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#The_loading_process)

> «By default, Saved variables load after the last file listed in the TOC. This can be
> reconfigured by the LoadSavedVariablesFirst directive to instead be loaded before all files in
> an addon.» — [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process)

Отсюда два практических правила:

* **В файлах аддона база ещё `nil`.** Читать — только в `ADDON_LOADED`.
* **Есть `## LoadSavedVariablesFirst`**, если очень нужно видеть базу прямо в файлах
  ([TOC format §LoadSavedVariablesFirst](https://warcraft.wiki.gg/wiki/TOC_format#LoadSavedVariablesFirst)).
  В DropLedger им не пользуемся: лишняя зависимость от порядка.

Запись:

> «The client automatically writes the values of the the variables you list in your .toc file to
> disk when you log out, disconnect, quit the game, or reload your user interface (`/reload`).»
> — [§Saving to disk](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Saving_to_disk)

> «If an addon needs to make last-minute changes before the variables are saved, use the
> PLAYER_LOGOUT event: it fires just before the character logs out, and is the last event before
> your saved variables are written to disk.» — там же

Исключение, о котором надо помнить: при падении клиента `ADDONS_UNLOADING` «does not occur
during a crash or Alt-F4» ([AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process#Events_during_logout)).

## 7.5 Что можно хранить

> «Only some variable types may be saved : Strings, booleans, numbers and tables are the only
> variable types that will be saved (functions, userdata and coroutines will not). Circular
> references in tables may not be preserved.»
> — [§Common pitfalls](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Common_pitfalls)

| Можно | Нельзя |
|---|---|
| строка, число, boolean | функция (потеряется) |
| таблица любой вложенности | userdata (фреймы, текстуры — потеряются) |
| смесь всего вышеперечисленного | корутина |

Ещё две ловушки оттуда же:

> «Multiple saved variables that reference the same table will each create a separate (but
> identical) instance of the table, and as such will no longer point to the same table when they
> are loaded again.»

То есть если две переменные ссылаются на одну таблицу, после перезагрузки это будут **две
разные** таблицы. В DropLedger поэтому из базы не хранят ссылки на фреймы и не держат
`items` в двух местах одновременно.

> «Variables are saved and loaded in the global environment» — значит, локальную переменную
> надо сначала прочитать из глобальной в `ADDON_LOADED`, а перед выходом записать обратно.

## 7.6 Первый запуск: `nil` — это нормально

> «When the addon is loaded for the first time, the `HaveWeMetCount` variable will be `nil` after
> `ADDON_LOADED`… similarly, when a character previously unknown to the addon is encountered,
> `HaveWeMetLastSeen` will be `nil`.» — [§Code example](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Code_example)

Поэтому любая работа с базой начинается с «а если её нет?»:

```lua
HelloWorldDB = ApplyDefaults(DEFAULTS, HelloWorldDB)   -- nil превратится в {}
```

## 7.7 Наш код: `ApplyDefaults` и миграции

`DropLedger/Core.lua:214-227` — та самая функция, которая делает «старую базу новой»:

```lua
--- Дополнить dst значениями из src (src не меняется).
local function ApplyDefaults(src, dst)
    if type(src) ~= "table" then return dst end
    dst = type(dst) == "table" and dst or {}
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

Свойства, ради которых она написана именно так:

| Свойство | Зачем |
|---|---|
| `src` не меняется | в `DEFAULTS` лежат таблицы, которые нельзя портить: иначе следующий персонаж получит уже испорченные значения |
| рекурсия по таблицам | новые поля появляются на любом уровне (`settings.prof.fishing`) |
| `elseif dst[k] == nil` | значение игрока **не перетирается** дефолтом |
| `dst` может быть `nil` | первый запуск |

Вызов при загрузке (`Core.lua:1038-1039`):

```lua
DropLedgerDB     = ApplyDefaults(DEFAULTS, DropLedgerDB)
DropLedgerCharDB = ApplyDefaults({ items = {}, fish = {} }, DropLedgerCharDB)
```

Вторая строка важна: у персонажа своя, **маленькая** база (`items` и `fish`), а не копия
аккаунтной. Аккаунтная `DropLedgerDB` содержит `items` (настройки отслеживания), `acc`
(суммы), `chars` (разбивка по персонажам), `settings`, `ui`.

### Миграции: как менять смысл старых полей

Дефолты не спасают, когда меняется **поведение**. Пример из `Core.lua:1046-1062`:

```lua
-- У тех, кто ставил 1.4.x, в базе остаётся trackMobs = true — сбрасываем
-- один раз, чтобы ненадёжный счёт не включился «сам собой» после обновления.
if not ns.db.settings.npcKillAsked then
    ns.db.settings.npcKillAsked = true
    ns.db.settings.trackMobs = false
end

-- 1.11: «Сообщение в чат при выпадении» — включено по умолчанию.
if not ns.db.settings.msgOnByDefault then
    ns.db.settings.msgOnByDefault = true
    ns.db.settings.msg = true
end
```

Механика «одноразового флага»: в базе лежит служебное поле (`npcKillAsked`,
`msgOnByDefault`), которого раньше не было. Пока его нет — делаем миграцию и ставим флаг.
После этого игрок может менять настройку руками, и аддон больше её не тронет.

Альтернатива — поле `version` в базе (`DEFAULTS.version = 4`) и проверка `if db.version < 4
then ... end`. В DropLedger оно есть, но для точечных правок используются флаги: они точнее
и не требуют переписывать цепочку версий.

## 7.8 Сброс настроек, не данных

`Core.lua:877-890` — как правильно делать «вернуть всё как было»:

```lua
function ns.ResetConfig()
    if not ns.db then return false end
    ns.db.settings = ApplyDefaults(DEFAULTS.settings, {})
    ns.db.ui = ApplyDefaults(DEFAULTS.ui, {})
    local lang = (ns.Locale and ns.Locale.ClientHint()) or "en"
    ns.db.ui.locale = lang
    if ns.Locale then ns.Locale.current = lang end
    if ns.DetectReload then ns.DetectReload() end
    return true, lang
end
```

Обратите внимание: пересоздаются только две ветки — `settings` и `ui`. Счётчики, сканы и
списки предметов остаются. Это то, чего ждёт игрок от кнопки «Сброс настроек»: он не хочет
потерять статистику за полгода.

## 7.9 Сколько можно хранить

Источник описывает последствие переполнения, но не даёт числа:

> «SAVED_VARIABLES_TOO_LARGE: addOnName — Fires when the client runs out of memory while
> attempting to load saved variables, after ADDON_LOADED.» / «SavedVariables will not save on the
> next logout.» — [Event:SAVED_VARIABLES_TOO_LARGE](https://warcraft.wiki.gg/wiki/Event:SAVED_VARIABLES_TOO_LARGE)

Практический вывод для стажёра: не складывать в базу «всё, что видел». В DropLedger тяжёлые
справочники (луты, шансы, модели) лежат **в коде** (`Data*.lua`, ~30 тысяч строк на 11 файлов),
а в `SavedVariables` — только счётчики и настройки.

Подписка на это событие — хороший тон:

```lua
frame:RegisterEvent("SAVED_VARIABLES_TOO_LARGE")
...
elseif event == "SAVED_VARIABLES_TOO_LARGE" then
    ns.Print("база не поместилась в память, часть настроек не сохранится")
```

## 7.10 Частые ошибки новичка

| Симптом | Причина | Источник |
|---|---|---|
| База всегда пустая | переменная `local`, а не глобальная | [§Specifying which variables to save](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Specifying_which_variables_to_save) |
| `attempt to index a nil value` в файле аддона | читаем базу до `ADDON_LOADED` | [§The loading process](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#The_loading_process) |
| Дефолты затирают настройки игрока | `ApplyDefaults` пишет `src` в `dst` без проверки `nil` | наш код, 7.7 |
| После обновления настройка «сама включилась» | новая опция получила дефолт `true` и применилась к старым базам | 7.7, миграции |
| Две таблицы «разъехались» | одна таблица сохранена в двух переменных | [§Common pitfalls](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Common_pitfalls) |
| Функция в базе исчезла | функции не сохраняются | там же |
| Файл базы не появился | игра не вышла штатно (`Alt-F4`), либо `.toc` без директивы | [§Storage](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions#Storage) |
| «сохранилось, но не то» | в `WTF` лежит копия `SavedVariables.lua` из другого места | [SavedVariables](https://warcraft.wiki.gg/wiki/SavedVariables) |

## 7.11 Источники раздела

* [Saving variables between game sessions](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions) — объявление, загрузка, запись, подводные камни, пути.
* [SavedVariables](https://warcraft.wiki.gg/wiki/SavedVariables) — формат файла, копии `SavedVariables.lua`.
* [TOC format §SavedVariables](https://warcraft.wiki.gg/wiki/TOC_format#SavedVariables), [§SavedVariablesPerCharacter](https://warcraft.wiki.gg/wiki/TOC_format#SavedVariablesPerCharacter), [§LoadSavedVariablesFirst](https://warcraft.wiki.gg/wiki/TOC_format#LoadSavedVariablesFirst).
* [Event:SAVED_VARIABLES_TOO_LARGE](https://warcraft.wiki.gg/wiki/Event:SAVED_VARIABLES_TOO_LARGE), [Event:PLAYER_LOGOUT](https://warcraft.wiki.gg/wiki/Event:PLAYER_LOGOUT).
* [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process) — где в последовательности стоят базы.
* `DropLedger/Core.lua:153-227, 1038-1062, 877-890` — дефолты, `ApplyDefaults`, миграции, сброс.
