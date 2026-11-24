# План руководства и карта источников

Составлен до написания текста. В колонке «Покрытие» три состояния:

* **полное** — в источниках есть всё, что нужно разделу;
* **частичное** — есть основа, но часть фактов в источниках отсутствует (перечислено, чего нет);
* **нет** — источниками не покрыто; в тексте это будет честно помечено, а не додумано.

Источники: **W** — warcraft.wiki.gg, **S** — Gethe/wow-ui-source, **T** — шаблон
FRIKKern, **D** — наш DropLedger.

---

## 1. Введение: что такое аддон, как грузится, структура папок, `.toc`

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Что такое `.toc` и какую роль играет при загрузке | полное | W: [TOC format](https://warcraft.wiki.gg/wiki/TOC_format), [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process) |
| Путь установки (`Interface/AddOns`), требование совпадения имён папки и `.toc` | полное | W: [AddOn §Installing](https://warcraft.wiki.gg/wiki/AddOn#Installing_an_addon), [TOC format §Rules](https://warcraft.wiki.gg/wiki/TOC_format#Rules) |
| Синтаксис: `## Директива: Значение`, `#` — комментарий, строки-файлы, порядок | полное | W: [TOC format §Rules](https://warcraft.wiki.gg/wiki/TOC_format#Rules) |
| Полный список директив с описанием каждой | полное | W: [TOC format §Addon directives](https://warcraft.wiki.gg/wiki/TOC_format#Addon_directives) |
| `## Interface`, что означает число, таблица версий | полное | W: [TOC format §Interface](https://warcraft.wiki.gg/wiki/TOC_format#Interface), [Getting the current interface number](https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number), S: `version.txt` |
| Порядок загрузки аддонов и файлов, `LoadOnDemand`, `LoadWith`, зависимости | полное | W: [AddOn loading process §order](https://warcraft.wiki.gg/wiki/AddOn_loading_process#AddOn_loading_order) |
| Суффиксы имён `.toc` (`_Mainline`, `_Classic`…), `[Family]` в путях | полное | W: [TOC format §Naming](https://warcraft.wiki.gg/wiki/TOC_format#Naming), [TOC format §Variables](https://warcraft.wiki.gg/wiki/TOC_format#Variables) |
| Живые примеры `.toc` из клиента | полное | S: `Interface/AddOns/*/*.toc` |
| Настоящий `.toc` нашего аддона | полное | D: `DropLedger.toc` |
| Кодировка `.toc`, перенос строки, вложенные `.toc` | **нет** | ни W, ни T этого не описывают |

## 2. Lua 5.1 в контексте WoW

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Версия языка и что за библиотеки есть | полное | W: [Lua](https://warcraft.wiki.gg/wiki/Lua), [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) |
| Нет `io`/`os` — файловой системы и ОС нет | полное | W: [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) |
| `local`, область видимости, `_G`, «один глобал на аддон» | полное | W: [Lua Coding Tips](https://warcraft.wiki.gg/wiki/Lua_Coding_Tips) |
| Таблицы, `pairs`/`ipairs`, `#`, вложенные таблицы | полное | W: [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) |
| Функции, vararg `...`, замыкания | полное | W: [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions), [Handling events](https://warcraft.wiki.gg/wiki/Handling_events) |
| `setmetatable`/`getmetatable`, `__index` | частичное | W: [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) — только упоминание функций; отдельной страницы про метатаблицы **нет**, поведение `__index` описываем по DropLedger |
| Корутины (`coroutine.*`) | частичное | W: [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) — только список функций; страницы `Coroutine` **нет** |
| Модульная схема `local ADDON, ns = ...` и таблица-неймспейс | частичное | T: `Init.lua` / README шаблона описывает namespace; поведение vararg — W: [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process). Формальной страницы про `...` в аддоне **нет** |
| `pcall`/`xpcall`, `error`, `select`, `string.format` | полное | W: [Lua functions](https://warcraft.wiki.gg/wiki/Lua_functions) |
| Taint — что это и почему нельзя трогать чужое | полное | W: [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting) |
| Лимиты (размер строки, объём кода) | **нет** | в источниках не найдено |

## 3. Жизненный цикл: `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Последовательность при входе: `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` → `PLAYER_REGEN_DISABLED` → `SPELLS_CHANGED` | полное | W: [AddOn loading process §Events during login](https://warcraft.wiki.gg/wiki/AddOn_loading_process#Events_during_login) |
| Последовательность при выходе: `PLAYER_LEAVING_WORLD` → `PLAYER_LOGOUT` → `ADDONS_UNLOADING` | полное | W: [AddOn loading process §Events during logout](https://warcraft.wiki.gg/wiki/AddOn_loading_process#Events_during_logout) |
| Аргументы каждого события | полное | W: `Event:ADDON_LOADED`, `Event:PLAYER_LOGIN`, `Event:PLAYER_ENTERING_WORLD`, `Event:PLAYER_LOGOUT`, `Event:VARIABLES_LOADED`, `Event:SAVED_VARIABLES_TOO_LARGE` |
| Где доступны SavedVariables | полное | W: [Event:ADDON_LOADED](https://warcraft.wiki.gg/wiki/Event:ADDON_LOADED) |
| Где создавать фреймы и размещать окна | полное | W: [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process) |
| `VARIABLES_LOADED` — почему не использовать | полное | W: [Event:VARIABLES_LOADED](https://warcraft.wiki.gg/wiki/Event:VARIABLES_LOADED) |
| Практика: один стартовый фрейм, отписка после первого вызова | полное | W + D: `Core.lua:1031-1180` |
| «Событие приходит ровно один раз на аддон» | **частичное** | W говорит «fires when each AddOn finishes loading» и советует отписаться; слова «ровно один раз» в источниках нет |

## 4. Фреймы

| Пункт плана | Покрытие | Источники |
|---|---|---|
| `CreateFrame(frameType, name, parent, template, id)` | полное | W: [API:CreateFrame](https://warcraft.wiki.gg/wiki/API:CreateFrame) |
| Полный список типов фреймов | полное | там же (24 объектных + 12 intrinsic) |
| `SetPoint` — все перегрузки, смысл `offsetX/offsetY` | полное | W: [API:ScriptRegionResizing_SetPoint](https://warcraft.wiki.gg/wiki/API:ScriptRegionResizing_SetPoint) |
| Девять точек (`FramePoint`) | полное | W: [FramePoint](https://warcraft.wiki.gg/wiki/FramePoint), [Anchors](https://warcraft.wiki.gg/wiki/Anchors) |
| `SetSize`, `SetAllPoints`, `ClearAllPoints`, `GetSize` | полное | W: `API:ScriptRegionResizing_SetSize`, `..._SetAllPoints`, `..._ClearAllPoints`, `API:ScriptRegion_GetWidth` |
| Ошибка «anchor family connection» | полное | W: [SetPoint §Anchor family](https://warcraft.wiki.gg/wiki/API:ScriptRegionResizing_SetPoint) |
| `SetParent`, наследование alpha/scale | полное | W: [API:ScriptRegion_SetParent](https://warcraft.wiki.gg/wiki/API:ScriptRegion_SetParent) |
| `FrameStrata` (9/10 значений) и `frame level` 0–10000 | полное (с расхождением) | W: [Frame Strata](https://warcraft.wiki.gg/wiki/Frame_Strata), [API types](https://warcraft.wiki.gg/wiki/API_types) |
| `DrawLayer` — 5 слоёв, подуровни −8…7 | полное | W: [Layer](https://warcraft.wiki.gg/wiki/Layer), [SetDrawLayer](https://warcraft.wiki.gg/wiki/SetDrawLayer) |
| Шаблоны, `BackdropTemplate`, `SetBackdrop` удалён в 9.0.1 | полное | W: [BackdropTemplate](https://warcraft.wiki.gg/wiki/BackdropTemplate), [API:Frame_SetBackdrop](https://warcraft.wiki.gg/wiki/API:Frame_SetBackdrop), [Virtual XML template](https://warcraft.wiki.gg/wiki/Virtual_XML_template) |
| Перетаскивание окна: `SetMovable`, `RegisterForDrag`, `OnDragStart` | полное | W: `API:Frame_SetMovable`, `API:Frame_RegisterForDrag`, `UIHANDLER_OnDragStart`, [Making draggable frames](https://warcraft.wiki.gg/wiki/Making_draggable_frames) |
| Закрытие по Esc: `UISpecialFrames` | полное | W: [Make frames closable with the Escape key](https://warcraft.wiki.gg/wiki/Make_frames_closable_with_the_Escape_key) |
| Полный список шаблонов | **нет** | вики отсылает к внешнему `Templates.lua` (Ketho); своего перечня нет |
| Примеры из нашего аддона | полное | D: `UI.lua:145-200`, `UI.lua:483-560` |

## 5. События

| Пункт плана | Покрытие | Источники |
|---|---|---|
| `RegisterEvent` / `UnregisterEvent` / `UnregisterAllEvents` | полное | W: `API:Frame_RegisterEvent`, `API:Frame_UnregisterEvent`, `API:Frame_UnregisterAllEvents` |
| Ошибка при несуществующем событии, `false` при повторе | полное | W: `API:Frame_RegisterEvent` |
| `RegisterUnitEvent`, максимум 4 юнита, перезапись фильтра | полное | W: [API:Frame_RegisterUnitEvent](https://warcraft.wiki.gg/wiki/API:Frame_RegisterUnitEvent) |
| Сигнатура `OnEvent(self, event, ...)` | полное | W: [Handling events](https://warcraft.wiki.gg/wiki/Handling_events), [UIHANDLER_OnEvent](https://warcraft.wiki.gg/wiki/UIHANDLER_OnEvent) |
| Порядок вызова у разных фреймов | полное (с оговоркой источника) | W: `API:Frame_RegisterEvent` §In-Depth |
| `RegisterAllEvents` и почему нельзя | полное | W: [API:Frame_RegisterAllEvents](https://warcraft.wiki.gg/wiki/API:Frame_RegisterAllEvents) |
| Новое в 12.0.0: `RegisterEventCallback`, `EventRegistry` | полное | W: `API:Frame_RegisterEventCallback`, [EventRegistry](https://warcraft.wiki.gg/wiki/EventRegistry) |
| `COMBAT_LOG_EVENT_UNFILTERED` закрыт для аддонов | полное | W: [Event:COMBAT_LOG_EVENT](https://warcraft.wiki.gg/wiki/Event:COMBAT_LOG_EVENT), [Patch 12.0.0/API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes) |
| Максимум событий на фрейм, текст ошибки при превышении | **нет** | в источниках численного лимита нет |
| Состав аргументов `FrameEventCallbackType` | **нет** | таблица в источнике пустая |

## 6. Слэш-команды

| Пункт плана | Покрытие | Источники |
|---|---|---|
| `SLASH_<ИМЯ><N>` + `SlashCmdList[<ИМЯ>]` | полное | W: [Creating a slash command](https://warcraft.wiki.gg/wiki/Creating_a_slash_command) |
| Аргумент `msg`, второй аргумент — edit box | полное | там же |
| Разбор аргументов паттерном | полное | там же |
| Приоритеты и конфликты между аддонами | полное | там же |
| Локализация самих команд | полное | там же |
| Метод объекта вместо функции — обёртка | полное | там же |
| Длина имени, максимум алиасов | **нет** | в источниках не найдено |

## 7. SavedVariables

| Пункт плана | Покрытие | Источники |
|---|---|---|
| `## SavedVariables` vs `## SavedVariablesPerCharacter` | полное | W: [Saving variables between game sessions](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions) |
| Файлы на диске (`WTF/Account/...`) | полное | там же §Storage |
| Когда читаются (после последнего файла `.toc`, до `ADDON_LOADED`) | полное | там же §The loading process |
| `## LoadSavedVariablesFirst` | полное | W: [TOC format §LoadSavedVariablesFirst](https://warcraft.wiki.gg/wiki/TOC_format#LoadSavedVariablesFirst) |
| Когда пишутся на диск | полное | там же §Saving to disk |
| Какие типы сохраняются, circular references, две ссылки на одну таблицу | полное | там же §Common pitfalls |
| Первый запуск: переменная `nil` | полное | там же §Code example |
| `SAVED_VARIABLES_TOO_LARGE` | полное | W: [Event:SAVED_VARIABLES_TOO_LARGE](https://warcraft.wiki.gg/wiki/Event:SAVED_VARIABLES_TOO_LARGE) |
| Миграции и `ApplyDefaults` | частичное | механизм — W; конкретная реализация — D: `Core.lua` |
| `SavedVariablesMachine` (машинные, не для сторонних аддонов) | полное | W: [TOC format §Restricted](https://warcraft.wiki.gg/wiki/TOC_format#Restricted) |
| Как сохранять «на лету» (принудительная запись) | **нет** | в источниках только запись при выходе/reload |

## 8. UI: окна, кнопки, текстуры, шрифты, скроллы

| Пункт плана | Покрытие | Источники |
|---|---|---|
| `CreateTexture`, `CreateFontString`, слои и подуровни | полное | W: `API:Frame_CreateTexture`, `API:Frame_CreateFontString`, [Layer](https://warcraft.wiki.gg/wiki/Layer) |
| `SetTexture`, `SetColorTexture`, PNG-расширение | полное | W: [API:TextureBase_SetTexture](https://warcraft.wiki.gg/wiki/API:TextureBase_SetTexture) |
| `SetText`, лимит 30 000 символов, `SetFont`, флаги | полное | W: `API:FontString_SetText`, `API:FontInstance_SetFont` |
| Кнопка: `SetText`, `RegisterForClicks`, `OnClick` | полное | W: [API:CreateFrame](https://warcraft.wiki.gg/wiki/API:CreateFrame) (пример кнопки), `UIOBJECT_Button` |
| Фон и рамка: `BackdropTemplate` | полное | W: [BackdropTemplate](https://warcraft.wiki.gg/wiki/BackdropTemplate) |
| Прокрутка: `ScrollFrame`, `SetScrollChild`, `OnVerticalScroll`, `EnableMouseWheel` | частичное | W: `API:ScrollFrame` (редирект), `UIOBJECT_ScrollFrame`; метод `EnableMouseWheel` — на `UIOBJECT_Frame`. Готового рецепта «своя прокрутка» в источниках **нет** — берём код D: `UI.lua:473-560` |
| Тултипы: `SetOwner`, `AddLine`, `AddDoubleLine`, `GameTooltipTemplate` | полное | W: `API:GameTooltip_SetOwner`, `API:GameTooltip_AddLine`, `API:GameTooltip_AddDoubleLine`, [GameTooltipTemplate](https://warcraft.wiki.gg/wiki/GameTooltipTemplate) |
| Страница в настройках: `Settings.RegisterCanvasLayoutCategory` и др. | полное | W: [Settings API](https://warcraft.wiki.gg/wiki/Settings_API), [Creating a settings menu](https://warcraft.wiki.gg/wiki/Creating_a_settings_menu) |
| Модель: `DressUpModel`, `SetUnit` | частичное | W: [API:CreateFrame](https://warcraft.wiki.gg/wiki/API:CreateFrame) (тип есть), [Widget API](https://warcraft.wiki.gg/wiki/Widget_API); конкретные методы модели в источниках не разобраны — берём D: `UI.lua:3972-4030` |
| Кнопка у миникарты | частичное | W: `Minimap` в [Widget API](https://warcraft.wiki.gg/wiki/Widget_API); готового рецепта нет — берём D |
| Масштаб интерфейса и `UIParent` | полное | W: [UIParent](https://warcraft.wiki.gg/wiki/UIParent) |

## 9. Игровые данные

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Устройство API: глобальные функции, `C_*`, `Enum.*` | полное | W: [World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API), [Global functions](https://warcraft.wiki.gg/wiki/Global_functions) |
| Маркеры `protected`, `noscript`, `noinstance`, `deprecated`, `obsolete`, `hwevent` | полное | W: [Module:Apitag](https://warcraft.wiki.gg/wiki/Module:Apitag) |
| Unit API: точные сигнатуры | полное | W: `API:UnitHealth`, `UnitHealthMax`, `UnitName`, `UnitGUID`, `UnitLevel`, `UnitClass`, `UnitFactionGroup`, `UnitIsPlayer`, `UnitExists`, `UnitIsDead`, `UnitPower`, `UnitPowerMax` |
| Unit-токены | полное | W: [UnitToken](https://warcraft.wiki.gg/wiki/UnitToken) |
| `C_Item.GetItemInfo` и исчезновение `GetItemInfo` | полное | W: `API:C_Item.GetItemInfo`, `API:GetItemInfo`, [Patch 12.1.5/API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes) |
| `C_Spell.GetSpellInfo`, `GetSpellCooldown`, `GetSpellTexture` | полное | W: `API:C_Spell.GetSpellInfo`, `Structure_SpellInfo`, `API:C_Spell.GetSpellCooldown` |
| `C_Map.GetBestMapForUnit`, `GetMapInfo` | полное | W: `API:C_Map.GetBestMapForUnit`, `API:C_Map.GetMapInfo` |
| `C_Timer.After/NewTimer/NewTicker` | полное | W: `API:C_Timer.After`, `API:C_Timer.NewTimer`, `API:C_Timer.NewTicker` |
| `C_AddOns.GetAddOnMetadata/IsAddOnLoaded/LoadAddOn` | полное | W: `API:C_AddOns.GetAddOnMetadata`, `API:C_AddOns.IsAddOnLoaded`, `API:C_AddOns.LoadAddOn` |
| Secret values: что можно и нельзя | полное | W: [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values) |
| Тег `nocombat` — расшифровка | **нет** | в `Module:Apitag` ключа нет |

## 10. Отладка

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Окно `Lua Error`, `scriptErrors` (0/1, как включить) | полное | W: [Lua Error](https://warcraft.wiki.gg/wiki/Lua_Error), [CVar scriptErrors](https://warcraft.wiki.gg/wiki/CVar_scriptErrors) |
| `/dump`, `/run`, `/fstack`, `/etrace`, `/tinspect`, `/console`, `/reload` | полное | W: `MACRO_dump`, `MACRO script`, `MACRO_framestack`, `MACRO_eventtrace`, `MACRO_tableinspect`, `MACRO console`, `MACRO reload` |
| `DevTools_Dump`, `print`, `DEFAULT_CHAT_FRAME:AddMessage` | полное | W: [API DevTools Dump](https://warcraft.wiki.gg/wiki/API_DevTools_Dump), [API:print](https://warcraft.wiki.gg/wiki/API:print) |
| `geterrorhandler`/`seterrorhandler`, `pcall`, стек | полное | W: [API:geterrorhandler](https://warcraft.wiki.gg/wiki/API:geterrorhandler) |
| Логи клиента (`taint.log`, `FrameXML.log`), `taintLog` | уточняется | W: `CVar taintLog`, `Taint`; окончательный список — по отчёту `src-debug` |
| Почему secret values ломают отладку | полное | W: [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values), [Patch 12.0.0/API changes/notes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes) |

## 11. Публикация и упаковка

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Interface-номер и что будет при несовпадении | полное | W: `TOC_format#Interface`, `Getting_the_current_interface_number` |
| Версионирование (`## Version`, `X-` поля) | полное | W: `TOC_format#Version`, `#X-___` |
| Структура zip (папка внутри архива) | полное | T: `.pkgmeta` (`package-as`), W: [AddOn §Installing](https://warcraft.wiki.gg/wiki/AddOn#Installing_an_addon) |
| BigWigs packager, `X-Curse-Project-ID`, `X-Wago-ID` | полное | T: `MyAddon.toc`, `.pkgmeta` |
| CI (GitHub Actions) в шаблоне | полное | T: `.github/workflows/` |
| Правила CurseForge | **нет** | в трёх источниках не описаны; пишем только то, что есть в T и W |
| Категории аддонов (`## Category`) | полное | W: `TOC_format#Category` |

## 12. Полные примеры

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Hello World: `.toc` + `.lua`, каждая строка | полное | наш код `examples/hello/`, проверен на заглушке; API — W |
| Средний аддон: DropLedger, архитектура и разбор кода | полное | D (38 файлов), API — W |
| Построчный разбор загрузки, БД, событий, слэша, UI | полное | D: `Core.lua`, `UI.lua`, `Locale.lua`, `Theme.lua`, `Stats.lua` |

## 13. Процесс разработки человеком (по просьбе заказчика)

| Пункт плана | Покрытие | Источники |
|---|---|---|
| Где ставить аддон, как включить, «Load out of date AddOns» | полное | W: [AddOn](https://warcraft.wiki.gg/wiki/AddOn) |
| Редактор и подсветка (VS Code + WoW API) | полное | W: [Lua editors](https://warcraft.wiki.gg/wiki/Lua_editors) |
| Линтер `.luacheckrc` | полное | T: `template/.luacheckrc` |
| Цикл правка → `/reload` → проверка | полное | W: `MACRO reload`, [TOC format §Rules](https://warcraft.wiki.gg/wiki/TOC_format#Rules) (новые файлы подхватываются на `/reload`) |
| Где смотреть ошибки и логи | уточняется | по отчёту `src-debug` |
| Проверка без игры (заглушка) | частичное | источниками не покрыто; это наш приём, `tools/miniclient/` |
| Приёмка перед релизом (чек-лист) | частичное | собирается из W (события, ограничения) + D (наш опыт) |
| Тестовый клиент / PTR | полное | W: `TOC_format#OnlyBetaAndPTR`, `AllowLoadGameType`; S: ветки `live`/`ptr`/`beta` |

---

## Что источниками НЕ покрыто (сводка)

1. Кодировка `.toc`, перенос строк, вложенные `.toc`.
2. Лимиты Lua (длина строки, объём кода, sandbox).
3. Метатаблицы и корутины — только списки функций, без теории.
4. Численный лимит событий на фрейм и текст ошибки при превышении.
5. Состав аргументов `FrameEventCallbackType`.
6. Полный список XML-шаблонов.
7. Расшифровка тега `nocombat`.
8. Правила CurseForge.
9. Принудительная запись SavedVariables «на лету».
10. Готовые рецепты «своя прокрутка», «кнопка у миникарты», «примерочная» — в вики их нет,
    поэтому соответствующие подразделы 8 опираются на код DropLedger, и это указано в тексте.
