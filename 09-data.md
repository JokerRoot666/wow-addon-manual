# 9. Игровые данные: Unit API, `C_*` неймспейсы, Spell, Item, Map, таймеры

## 9.1 Зачем это нужно

Считать шанс дропа можно и по чату, но настоящие данные приходят из API клиента: кто цель,
сколько у неё здоровья, какой предмет в сумке, на какой карте игрок. Этот раздел — про то,
как устроен API и как не наступить на грабли 12.x.

## 9.2 Как устроен API

> «The WoW API is used by Blizzard's Lua user interface and available to AddOns and macro scripts.
> It's officially documented in Blizzard_APIDocumentation which is accessible via the /api
> command.» — [World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)

Три пространства имён:

| Вид | Пример | Где документация |
|---|---|---|
| глобальная функция | `CreateFrame`, `UnitHealth`, `print` | [Global functions](https://warcraft.wiki.gg/wiki/Global_functions) |
| неймспейс `C_*` | `C_Item.GetItemInfo`, `C_Map.GetMapInfo` | `Category:API_systems/*`, например [Category:API systems/Item](https://warcraft.wiki.gg/wiki/Category:API_systems/Item) |
| перечисление `Enum.*` | `Enum.PowerType`, `Enum.ItemQuality` | [Category:Enums](https://warcraft.wiki.gg/wiki/Category:Enums) |

В игре документация доступна командами:

> «`/api system list` - Prints a list of systems», «`/api _____ list`», «`/api _____ search _____`»
> — [APILink](https://warcraft.wiki.gg/wiki/APILink)

В списках функций вики ставит маркеры; их полезно знать наизусть
([Module:Apitag](https://warcraft.wiki.gg/wiki/Module:Apitag)):

| Маркер | Что значит (цитата) |
|---|---|
| `protected` | «This API can only be called by secure code» |
| `noscript` | «This API cannot be called via /script» |
| `noinstance` | «This API cannot be called within instanced content» |
| `deprecated` | «This API seems no longer functional and will possibly be removed» |
| `obsolete` | «This API is defunct and throws an error» |
| `hwevent` | «Requires a hardware event (keyboard/mouse input)» |
| `framexml` | «This function is defined in Blizzard's FrameXML code» |

## 9.3 Unit API

| Функция | Сигнатура и возврат (цитата) | Ссылка |
|---|---|---|
| `UnitHealth` | `health = UnitHealth(unit [, usePredicted])` — «Returns 0 if the unit is dead or does not exist.» | [API:UnitHealth](https://warcraft.wiki.gg/wiki/API:UnitHealth) |
| `UnitHealthMax` | `maxHealth = UnitHealthMax(unit)` — «Returns 0 if the unit does not exist.» | [API:UnitHealthMax](https://warcraft.wiki.gg/wiki/API:UnitHealthMax) |
| `UnitName` | `name, realm = UnitName(unit)` — «Returns nil if the unit doesn't exist»; «Will return globalstring UNKNOWNOBJECT "Unknown Entity" if called before the unit in question has been fully loaded into the world.» | [API:UnitName](https://warcraft.wiki.gg/wiki/API:UnitName) |
| `UnitGUID` | `guid = UnitGUID(unit)` — «Returns nil if the unit does not exist.» | [API:UnitGUID](https://warcraft.wiki.gg/wiki/API:UnitGUID) |
| `UnitLevel` | `level = UnitLevel(unit)` — «Returns -1 for boss units or hostile units 10 levels above the player (Level ??)» | [API:UnitLevel](https://warcraft.wiki.gg/wiki/API:UnitLevel) |
| `UnitClass` | `className, classFilename, classId = UnitClass(unit)`; первый возврат помечен `secret=ConditionalSecret` | [API:UnitClass](https://warcraft.wiki.gg/wiki/API:UnitClass) |
| `UnitFactionGroup` | `factionGroupTag, localized = UnitFactionGroup(unitName [, checkDisplayRace])` — «may not return correct results until after PLAYER_ENTERING_WORLD event for units other than "player"» | [API:UnitFactionGroup](https://warcraft.wiki.gg/wiki/API:UnitFactionGroup) |
| `UnitIsPlayer` | `isPlayer = UnitIsPlayer(unit)` | [API:UnitIsPlayer](https://warcraft.wiki.gg/wiki/API:UnitIsPlayer) |
| `UnitExists` | `exists = UnitExists(unit)` — «returns false for visible units that are unable to be targeted» | [API:UnitExists](https://warcraft.wiki.gg/wiki/API:UnitExists) |
| `UnitIsDead` | `isDead = UnitIsDead(unit)` | [API:UnitIsDead](https://warcraft.wiki.gg/wiki/API:UnitIsDead) |
| `UnitPower` | `power = UnitPower(unitToken [, powerType [, unmodified]])` — «If no type is specified, UnitPower returns the current primary type» | [API:UnitPower](https://warcraft.wiki.gg/wiki/API:UnitPower) |
| `UnitPowerMax` | `maxPower = UnitPowerMax(unitToken [, powerType [, unmodified]])` | [API:UnitPowerMax](https://warcraft.wiki.gg/wiki/API:UnitPowerMax) |

Юнит-токены: `"player"`, `"target"`, `"focus"`, `"mouseover"`, `"pet"`, `"partyN"`, `"raidN"`,
`"bossN"`, `"nameplateN"`, `"vehicle"`, `"none"`, `"arenaN"`; «Unit tokens are case
insensitive» — [UnitToken](https://warcraft.wiki.gg/wiki/UnitToken).

Первый практический вывод: **проверять `UnitExists` перед работой с юнитом**. Второй: `nil` и
`0` — разные вещи, но для «нет данных» оба означают «ничего не считай»:

```lua
local function HealthPct(unit)
    if not UnitExists(unit) then return nil end
    local hp  = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    if not hp or not max or max == 0 then return nil end
    return hp / max
end
```

## 9.4 Предметы: `C_Item` и исчезновение `GetItemInfo`

Главная ловушка 12.x. Старая глобальная функция удалена:

> `{{deprecatedapi|patch=10.2.6|…|removed=12.1.5}}`
> «Patch 10.2.6: Namespaced to `C_Item.GetItemInfo`.» — [API:GetItemInfo](https://warcraft.wiki.gg/wiki/API:GetItemInfo)

> «The following deprecation fallbacks have been removed… `GetItemInfo` = `C_Item.GetItemInfo`»
> — [Patch 12.1.5/API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes)

Новая функция возвращает **18 значений**:

```lua
itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
expansionID, setID, isCraftingReagent, itemDescription = C_Item.GetItemInfo(itemInfo)
```
— [API:C_Item.GetItemInfo](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemInfo)

И вот главное:

> «Accepts any valid item ID but returns `nil` if the item is not cached yet.» / «Returns `nil`
> if the item is not cached yet or does not exist.» — там же

То есть первый вызов для незнакомого предмета **всегда** `nil`. Это не баг и не «медленный
интернет»: клиент подгружает данные предмета с сервера, и до этого момента он их не знает.

В DropLedger из этого сделана отдельная обёртка (`Core.lua:36-85`), которая переживает и
старый tuple, и новый клиент, и отсутствие данных:

```lua
function ns.ItemInfoTuple(id)
    id = tonumber(id)
    if not id then return nil end

    local C = _G.C_Item
    if C and C.GetItemInfo then
        -- C_Item.GetItemInfo может отдавать таблицу ItemInfo (актуальный клиент) или
        -- тот же tuple, что и раньше (промежуточные сборки) — поддерживаем оба вида.
        local a, b, c, d, e, f, g, h, i, j, k, l, m = C.GetItemInfo(id)
        if type(a) ~= "table" then
            if not a then return nil end
            return a, b, c, d, e, f, g, h, i, j, k, l, m
        end
        local info = a
        local name    = info.name or info.itemName
        ...
    end

    local native = _G.GetItemInfo
    if type(native) == "function" and native ~= ns.ItemInfoTuple then
        return native(id)
    end
    return nil
end
```

**Расхождение источников:** вики описывает 18 отдельных возвращаемых значений, а в коде
DropLedger учтён и вариант «первый возврат — таблица». Поэтому обёртка проверяет `type(a)`.
Для нового аддона правильно писать так, как в вики (18 значений), но проверять `nil`.

Что делать, когда данные ещё не пришли:

* проверить `nil` и не считать предмет «несуществующим»;
* попросить клиент подгрузить данные: `C_Item.RequestLoadItemDataByID(id)` — используется в
  DropLedger (Scan/Info). После подгрузки приходит событие обновления, и функцию можно
  вызвать снова;
* если нужно «прямо сейчас» — брать только то, что есть всегда: `itemID` из ссылки
  (`|Hitem:12345:…`) и иконку через `C_Item.GetItemIconByID` (если доступна в клиенте).

## 9.5 Заклинания: `C_Spell`

| Функция | Сигнатура и замечание | Ссылка |
|---|---|---|
| `C_Spell.GetSpellInfo` | `spellInfo = C_Spell.GetSpellInfo(spellIdentifier)`; `spellInfo: SpellInfo - Returns nil if spell is not found`; поля `name`, `iconID`, `castTime`, `minRange`, `maxRange`, `spellID` | [API:C_Spell.GetSpellInfo](https://warcraft.wiki.gg/wiki/API:C_Spell.GetSpellInfo), [Structure_SpellInfo](https://warcraft.wiki.gg/wiki/Structure_SpellInfo) |
| `C_Spell.GetSpellCooldown` | `spellCooldownInfo = C_Spell.GetSpellCooldown(spellIdentifier)`; структура `SpellCooldownInfo` (`startTime`, `duration`, `isEnabled`, `modRate`…) | [API:C_Spell.GetSpellCooldown](https://warcraft.wiki.gg/wiki/API:C_Spell.GetSpellCooldown), [Structure_SpellCooldownInfo](https://warcraft.wiki.gg/wiki/Structure_SpellCooldownInfo) |
| `C_Spell.GetSpellTexture` | `iconID, originalIconID, conditionalIconID = C_Spell.GetSpellTexture(spellIdentifier)` | [API:C_Spell.GetSpellTexture](https://warcraft.wiki.gg/wiki/API:C_Spell.GetSpellTexture) |

> «`castTime`: Cast time in milliseconds, or 0 for instant spells» — [Structure_SpellInfo](https://warcraft.wiki.gg/wiki/Structure_SpellInfo)

Старые глобальные `GetSpellInfo`, `GetSpellCooldown`, `GetSpellTexture` удалены ещё в 11.0.2:
«Removed, replaced by `C_Spell.GetSpellInfo` and returns a structured table»
([API:GetSpellInfo](https://warcraft.wiki.gg/wiki/API:GetSpellInfo)).

Типичное использование в DropLedger — опознать каст рыбалки:

```lua
local info = C_Spell.GetSpellInfo(spellID)
if info and info.name then
    local name = info.name:lower()
    ...
end
```

`info` может быть `nil` (спелл не найден) — проверка обязательна.

## 9.6 Карта: `C_Map`

| Функция | Сигнатура и замечание | Ссылка |
|---|---|---|
| `C_Map.GetBestMapForUnit` | `uiMapID = C_Map.GetBestMapForUnit(unitToken)`; «Only works for the player and group members»; «Returns the "lowest" map the unit is on» | [API:C_Map.GetBestMapForUnit](https://warcraft.wiki.gg/wiki/API:C_Map.GetBestMapForUnit) |
| `C_Map.GetMapInfo` | `info = C_Map.GetMapInfo(uiMapID)`; `UiMapDetails`: `mapID`, `name`, `mapType`, `parentMapID`, `flags` | [API:C_Map.GetMapInfo](https://warcraft.wiki.gg/wiki/API:C_Map.GetMapInfo), [Structure_UiMapDetails](https://warcraft.wiki.gg/wiki/Structure_UiMapDetails) |

Пример из документации:

```lua
/run local mapID = C_Map.GetBestMapForUnit("player"); print(format("You are in %s (%d)", C_Map.GetMapInfo(mapID).name, mapID))
-- You are in Stormwind City (84)
```

Функции `C_Map.GetMapPOIInfo` **не существует** — в источниках её нет; точки интереса берутся
из другого неймспейса: `C_AreaPoiInfo.GetAreaPOIInfo([uiMapID], areaPoiID)`
([World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)).

## 9.7 Таймеры: `C_Timer`

| Функция | Сигнатура | Ссылка |
|---|---|---|
| `C_Timer.After` | `C_Timer.After(seconds, callback)` — «With a duration of 0 ms, the earliest the callback will be called is on the next frame.» | [API:C_Timer.After](https://warcraft.wiki.gg/wiki/API:C_Timer.After) |
| `C_Timer.NewTimer` | `cbObject = C_Timer.NewTimer(seconds, callback)` — «Schedules a cancelable timer», у handle есть `:Cancel()`, `:IsCancelled()`, `:Invoke()` | [API:C_Timer.NewTimer](https://warcraft.wiki.gg/wiki/API:C_Timer.NewTimer) |
| `C_Timer.NewTicker` | `cbObject = C_Timer.NewTicker(seconds, callback [, iterations])` — «Schedules a cancelable repeating timer»; «Errors thrown inside a callback function will not halt the timer.» | [API:C_Timer.NewTicker](https://warcraft.wiki.gg/wiki/API:C_Timer.NewTicker) |

Почему это важно для производительности:

> «C_Timer.After() is generally more efficient than using an Animation or OnUpdate script.»
> — [API:C_Timer.After](https://warcraft.wiki.gg/wiki/API:C_Timer.After)

И цитата Blizzard оттуда же: «In most cases, initiating a second C_Timer is still going to be
cheaper than using an Animation or OnUpdate… The one case where you're better off not using the
new C_Timer system is when you have a ticker with a very short period».

В DropLedger `C_Timer.After` встречается 11 раз — им разведены загрузка, сканы и «догон»
данных после событий. Ровно один `OnUpdate` — у плавной прокрутки, где он уместен (8.7).

## 9.8 Добыча: `LOOT_OPENED` и `C_Loot`

Когда игрок открывает труп, приходит `LOOT_OPENED: autoLoot, isFromItem`
([Event:LOOT_OPENED](https://warcraft.wiki.gg/wiki/Event:LOOT_OPENED)), после чего слоты
читаются по одному:

```lua
local slot = 1
local info = C_Loot.GetLootSlotInfo(slot)   -- используется в DropLedger/Loot.lua
```

`C_Loot.GetLootSlotInfo` используется в `DropLedger/Loot.lua` — это наш проверенный вызов.
Отдельной страницы с описанием возвращаемой структуры в проверенных источниках нет, поэтому
контракт функции здесь не пересказывается. Практика DropLedger: сначала `LOOT_OPENED`, затем
обход слотов, и **проверка на `nil`** — в 12.x часть полей может отсутствовать.

Закрытие — `LOOT_CLOSED`, причём «this will fire before the last CHAT_MSG_LOOT event for that
loot» ([Event:LOOT_CLOSED](https://warcraft.wiki.gg/wiki/Event:LOOT_CLOSED)). Из-за этого
двойной счёт — классическая беда аддонов про лут: одно и то же выпадение приходит и слотом, и
строкой чата. В DropLedger это гасится окном времени в `HandleDrop`.

## 9.9 `C_AddOns`

| Функция | Сигнатура и замечание | Ссылка |
|---|---|---|
| `C_AddOns.GetAddOnMetadata` | `value = C_AddOns.GetAddOnMetadata(name, variable)`; «May be `Title, Notes, Author, Version`, or anything starting with `X-`»; «will raise an "Invalid AddOn name" error if supplied the name of an addon that does not exist» | [API:C_AddOns.GetAddOnMetadata](https://warcraft.wiki.gg/wiki/API:C_AddOns.GetAddOnMetadata) |
| `C_AddOns.IsAddOnLoaded` | `loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(name)` | [API:C_AddOns.IsAddOnLoaded](https://warcraft.wiki.gg/wiki/API:C_AddOns.IsAddOnLoaded) |
| `C_AddOns.LoadAddOn` | `loaded, value = C_AddOns.LoadAddOn(name)`; «Calling this function inside an ADDON_LOADED event handler may result in the named addon never receiving its own ADDON_LOADED event» | [API:C_AddOns.LoadAddOn](https://warcraft.wiki.gg/wiki/API:C_AddOns.LoadAddOn) |

Старый глобальный `GetAddOnMetadata` удалён в 11.0.2
([API:GetAddOnMetadata](https://warcraft.wiki.gg/wiki/API:GetAddOnMetadata)).

## 9.10 Секретные значения — то, что изменило всё в 12.x

> «Secret values are a new mechanism introduced in Patch 12.0.0 that restrict the ability for
> addons to perform some operations on Lua values on tainted execution paths.»
> — [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values)

Как это объясняет сама Blizzard:

> «The easiest way to think of Secret Values (Secrets) is that they are like black boxes, which
> contain a Lua value of any type… Insecure (tainted) Lua code can receive Secrets from our APIs
> and pass those Secrets into certain APIs, but it cannot actually see the value that is inside
> of that box. Attempting to compare a Secret with another value (Secret or not) will result in a
> Lua error, as will attempting to perform arithmetic on one.»
> — [Patch 12.0.0/API changes/notes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes)

Полный список запретов для tainted-кода (дословно):

> «* Tainted code is not allowed to perform arithmetic on secret values.
> * Tainted code is not allowed to compare or perform boolean tests on secret values.
> * Tainted code is not allowed to use the length operator (`#`) on secret values.
> * Tainted code is not allowed to store secret values as keys in tables.
> * Tainted code is not allowed to perform indexed access or assignment … on secret values.
> * Tainted code is not allowed to call secret values as-if they were functions.
> * Querying the type of a secret value `type(secret)` returns its real type.»
> — [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values)

Разрешено: хранить в переменных, передавать в функции, конкатенировать строки и числа,
вызывать `string.format`/`string.join` с секретами (там же).

Проверки:

| Функция | Что делает | Ссылка |
|---|---|---|
| `issecretvalue(v)` | `true`, если значение секретное | [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values) |
| `canaccessvalue(v)` | можно ли с ним работать | там же |
| `issecrettable(t)` | секретная таблица | там же |
| `canaccesstable(t)` | можно ли индексировать таблицу | там же |

Что секретно и когда (выборка из «Secret predicates», дословно):

| Предикат | Условие |
|---|---|
| `SecretWhenInCombat` | «when combat addon restrictions are in effect» |
| `SecretOnRestrictedMaps` (12.0.5) | «when the player is on an addon-restricted map such as a dungeon or raid» |
| `SecretWhenUnitIdentityRestricted` | «when the unit isn't player-controlled or in the party/raid» |
| `SecretWhenUnitHealthMaxRestricted` | «when the unit isn't player-controlled» |
| `SecretWhenCooldownsRestricted` (12.0.5) | «when combat, encounter, challenge mode, or PvP match addon restrictions are in effect» |
| `SecretWhenUnitAuraRestricted` | «when combat, encounter, challenge mode, or PvP match addon restriction are in effect» |
| `SecretWhenUnitSpellCastRestricted` | «if the unit being queried for cast information is not the player or their pet» |

Наш способ жить с этим (`Core.lua:229-238`):

```lua
--- Значение от клиента, если оно не «секретное».
--  На 12.x часть данных о чужих юнитах приходит как secret value: само
--  значение читается, но любое сравнение с ним — ошибка Lua («a secret number
--  value, while execution tainted by ...»). Для аддона такое значение
--  равносильно отсутствию данных.
function ns.Open(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
```

Правило: **любое значение от клиента, которое будет сравниваться или попадать в арифметику,
прогонять через `Open`**. Иначе в подземелье аддон умрёт с ошибкой на ровном месте.

## 9.11 Производительность: что советует источник

| Совет | Цитата | Ссылка |
|---|---|---|
| таймеры вместо `OnUpdate` | «C_Timer.After() is generally more efficient than using an Animation or OnUpdate script.» | [API:C_Timer.After](https://warcraft.wiki.gg/wiki/API:C_Timer.After) |
| не тейнтить защищённое | «prevent tainting the original» (о `hooksecurefunc`) | [Secure Execution and Tainting](https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting) |
| `local` вместо глобалов | «Try to use local variables whenever possible.» | [Lua Coding Tips](https://warcraft.wiki.gg/wiki/Lua_Coding_Tips) |
| больше 30 значений в `/dump` не выводится | «Tables display up to 30 values, the rest are skipped» | [MACRO dump](https://warcraft.wiki.gg/wiki/MACRO_dump) |
| ошибка в тикере не убивает таймер | «Errors thrown inside a callback function will not halt the timer.» | [API:C_Timer.NewTicker](https://warcraft.wiki.gg/wiki/API:C_Timer.NewTicker) |

## 9.12 Частые ошибки новичка

| Симптом | Причина | Источник |
|---|---|---|
| `attempt to call a nil value (global 'GetItemInfo')` | функция удалена в 12.1.5 | [API:GetItemInfo](https://warcraft.wiki.gg/wiki/API:GetItemInfo) |
| Название предмета пустое при первом входе | «returns nil if the item is not cached yet» | [API:C_Item.GetItemInfo](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemInfo) |
| Ошибка про secret number в подземелье | сравнение/арифметика на секретном значении | [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values) |
| `C_Map.GetMapPOIInfo` — nil | такой функции не существует | [World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API) |
| `UnitLevel` вернул `-1` | босс или враг на 10+ уровней выше | [API:UnitLevel](https://warcraft.wiki.gg/wiki/API:UnitLevel) |
| `UnitName` вернул «Unknown Entity» | юнит ещё не загружен в мир | [API:UnitName](https://warcraft.wiki.gg/wiki/API:UnitName) |
| Спелл не найден | `C_Spell.GetSpellInfo` вернул `nil` | [API:C_Spell.GetSpellInfo](https://warcraft.wiki.gg/wiki/API:C_Spell.GetSpellInfo) |
| Регистрация боевого лога даёт ошибку | закрыт с 12.0.0 | [Event:COMBAT_LOG_EVENT](https://warcraft.wiki.gg/wiki/Event:COMBAT_LOG_EVENT) |

## 9.13 Источники раздела

* [World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API), [Global functions](https://warcraft.wiki.gg/wiki/Global_functions), [APILink](https://warcraft.wiki.gg/wiki/APILink), [Module:Apitag](https://warcraft.wiki.gg/wiki/Module:Apitag).
* Unit: [API:UnitHealth](https://warcraft.wiki.gg/wiki/API:UnitHealth), [API:UnitHealthMax](https://warcraft.wiki.gg/wiki/API:UnitHealthMax), [API:UnitName](https://warcraft.wiki.gg/wiki/API:UnitName), [API:UnitGUID](https://warcraft.wiki.gg/wiki/API:UnitGUID), [API:UnitLevel](https://warcraft.wiki.gg/wiki/API:UnitLevel), [API:UnitClass](https://warcraft.wiki.gg/wiki/API:UnitClass), [API:UnitFactionGroup](https://warcraft.wiki.gg/wiki/API:UnitFactionGroup), [API:UnitPower](https://warcraft.wiki.gg/wiki/API:UnitPower), [UnitToken](https://warcraft.wiki.gg/wiki/UnitToken).
* Item: [API:C_Item.GetItemInfo](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemInfo), [API:GetItemInfo](https://warcraft.wiki.gg/wiki/API:GetItemInfo), [Patch 12.1.5/API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes).
* Spell: [API:C_Spell.GetSpellInfo](https://warcraft.wiki.gg/wiki/API:C_Spell.GetSpellInfo), [Structure_SpellInfo](https://warcraft.wiki.gg/wiki/Structure_SpellInfo), [API:C_Spell.GetSpellCooldown](https://warcraft.wiki.gg/wiki/API:C_Spell.GetSpellCooldown).
* Map: [API:C_Map.GetBestMapForUnit](https://warcraft.wiki.gg/wiki/API:C_Map.GetBestMapForUnit), [API:C_Map.GetMapInfo](https://warcraft.wiki.gg/wiki/API:C_Map.GetMapInfo), [Structure_UiMapDetails](https://warcraft.wiki.gg/wiki/Structure_UiMapDetails).
* Timers: [API:C_Timer.After](https://warcraft.wiki.gg/wiki/API:C_Timer.After), [API:C_Timer.NewTimer](https://warcraft.wiki.gg/wiki/API:C_Timer.NewTimer), [API:C_Timer.NewTicker](https://warcraft.wiki.gg/wiki/API:C_Timer.NewTicker).
* AddOns: [API:C_AddOns.GetAddOnMetadata](https://warcraft.wiki.gg/wiki/API:C_AddOns.GetAddOnMetadata), [API:C_AddOns.IsAddOnLoaded](https://warcraft.wiki.gg/wiki/API:C_AddOns.IsAddOnLoaded), [API:C_AddOns.LoadAddOn](https://warcraft.wiki.gg/wiki/API:C_AddOns.LoadAddOn).
* Loot: [Event:LOOT_OPENED](https://warcraft.wiki.gg/wiki/Event:LOOT_OPENED), [Event:LOOT_CLOSED](https://warcraft.wiki.gg/wiki/Event:LOOT_CLOSED).
* Ограничения: [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values), [Patch 12.0.0/API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes), [Patch 12.0.0/API changes/notes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes).
* `DropLedger/Core.lua:36-85, 229-238`, `DropLedger/Detect.lua`, `DropLedger/Loot.lua` — как это выглядит в рабочем аддоне.
