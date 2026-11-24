# 02. API клиента: что можно, что нельзя, что изменилось

## Три слоя API

1. **Глобалы старого стиля** — `UnitName`, `GetTime`, `CreateFrame`, `GetLocale`.
   Часть из них в 11+/12.x удалена или переехала в `C_*` (см. ниже).
2. **Неймспейсы `C_*`** — `C_Item`, `C_Map`, `C_MountJournal`, `C_Timer`, `C_EventUtils`...
   Современный путь; именно их использует Blizzard UI в `wow-ui-source`.
3. **`Enum.*`** — числовые константы вместо «магических чисел»:
   `Enum.ItemClass.Armor`, `Enum.ItemQuality.Legendary`, `Enum.InventoryType.IndexHeadType`.

Правило: сначала искать `C_*`/`Enum`, глобал — только если его нет. Если сомневаешься в
сигнатуре — смотри, как это вызывает Blizzard UI в `wow-ui-source`, а не форумы.

## Предметы: главная ловушка 11+/12.x

`GetItemInfo(itemID)` как глобал **удалён**. Теперь:

```lua
local info = C_Item.GetItemInfo(itemID)
-- info == nil        -> данных ещё нет (клиент подгружает предметы лениво)
-- info == table      -> { name=..., itemLink=..., itemQuality=..., itemLevel=...,
--                         itemIcon=..., itemClassID=..., itemSubclassID=...,
--                         itemEquipLoc=..., expansionID=..., sellPrice=... }
```

Практика (обёртка из Drop Ledger переносит оба мира):

```lua
function ns.ItemInfoTuple(id)
    id = tonumber(id); if not id then return nil end
    local C = _G.C_Item
    if C and C.GetItemInfo then
        local a, b, c, d, e, f, g, h, i, j, k, l, m = C.GetItemInfo(id)
        if type(a) ~= "table" then
            if not a then return nil end
            return a, b, c, d, e, f, g, h, i, j, k, l, m   -- старые сборки: кортеж
        end
        local info = a
        return info.name or info.itemName,
               info.itemLink or info.link or info.hyperlink,
               info.itemQuality or info.quality,
               info.itemLevel or info.ilvl,
               nil, nil, nil, nil,
               info.itemEquipLoc or info.equipLoc,
               info.itemIcon or info.icon or info.texture,
               info.sellPrice,
               info.itemClassID or info.classID,
               info.itemSubclassID or info.subclassID
    end
    local native = _G.GetItemInfo                    -- на старом клиенте
    if type(native) == "function" and native ~= ns.ItemInfoTuple then
        return native(id)
    end
    return nil
end
```

Мгновенные данные (не требуют загрузки): `C_Item.GetItemInfoInstant(id)` →
`itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID`;
`C_Item.GetItemQualityByID`, `C_Item.GetItemIconByID`, `C_Item.GetItemNameByID`.

Если данных нет — попросить и подождать:

```lua
C_Item.RequestLoadItemDataByID(itemID)
-- позже придёт GET_ITEM_INFO_RECEIVED(itemID, success)
```

Иконка и имя из ссылки: `GetItemInfoFromHyperlink`, разбор `|Hitem:ID:...|h` регуляркой —
см. `ns.ResolveItemID`.

## Юниты

```lua
UnitExists("target"), UnitIsDead("target"), UnitIsPlayer("target")
UnitName("target"), UnitFullName("target")        -- имя, рилм
UnitGUID("target")                                -- "Creature-0-...-<npcID>"
UnitClass("player")                               -- локальная строка, nil, classFile, classID
UnitLevel("unit"), UnitHealth("unit"), UnitHealthMax("unit")
UnitClassification("target")  -- "worldboss"|"rareelite"|"elite"|"rare"|"normal"|"trivial"
GetRealmName(), GetNormalizedRealmName()
```

**NPC-ID из GUID** (12.x):

```lua
local guid = UnitGUID("target")
local ok, npcID = pcall(C_CreatureInfo.GetCreatureID, guid)
```

**Секретные значения.** В 12.x «личность» чужих NPC и часть чисел здоровья/боя помечены
клиентом как secret: значение читается, но **любое сравнение с ним — ошибка Lua**
(«a secret number value, while execution tainted by ...»). Универсальная защита:

```lua
function ns.Open(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

function ns.Probe(fn, ...)                 -- вызов клиента без падений
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return ns.Open(v)
end
```

Никогда не писать `if UnitHealth("target") > 0` без `ns.Open`: для секретного числа это
ошибка, а не `false`.

## Модели (примерочная)

`PlayerModel` / `DressUpModel` (наследник `PlayerModel`):

| Метод | Что делает | Ограничение |
|---|---|---|
| `SetUnit("player"/"target"/"focus"/"mouseover")` | модель юнита | **только игроки**. На NPC в 12.x `ACCESS_VIOLATION`: `RequiresDeclassifiedUnitIdentity` |
| `SetCreature(creatureID)` | модель существа по npcID | безопасно, но не для игроков |
| `SetDisplayInfo(displayID)` | модель по displayID | так подставляют «чужую расу» |
| `TryOn("item:123")` / `TryOn("set:456")` | надеть предмет/набор | нужен `DressUpModel` |
| `Undress()` | снять всё | |
| `SetRotation(радианы)`, `SetCamDistanceScale(0.6..2.6)` | ракурс/зум | |
| `CanSetUnit(unit)` | можно ли | **возвращает secret value**: не сравнивать с `true`, решение принимать по результату `SetUnit` |

Раса/пол без смены персонажа: `SetDisplayInfo(displayID)` из таблицы
`CreatureDisplayInfoExtra` (см. `06-external-data.md`, `gen_racemodels.py`). API
`SetCustomRace` не существует.

## Коллекции и журналы (аккаунтные данные)

| Что | API | Замечание |
|---|---|---|
| транспорт | `C_MountJournal.GetMountIDs()`, `GetMountInfoByID(mountID)`, `GetMountInfo(index)` | у предмета-маунта `mountID` из DB2 |
| питомцы | `C_PetJournal.GetPetInfoBySpeciesID`, `GetNumPets`, `C_PetJournal.GetPetInfoByIndex` | сверка по `speciesID` |
| игрушки | `C_ToyBox.GetToyInfo`, `PlayerHasToy(itemID)` | |
| трансмог | `C_TransmogCollection.PlayerHasTransmog(itemID)`, `GetItemInfo(itemID)` | в 12.x `GetCategoryAppearances` отдаёт пусто |
| наборы | `C_TransmogSets.GetAllSets`, `GetSetPrimaryAppearances`, `C_Transmog.GetAllSetAppearancesByID(setID)` | последний — рабочий путь в 12.x |
| рецепты | `C_Item.GetItemSpell(itemID)` + `IsPlayerSpell(spellID)` | |
| достижения | `GetAchievementInfo(id)`, `GetAchievementNumCriteria`, `GetAchievementCriteriaInfo` | критерий → предмет ищется по имени/`assetID` |
| сумки/банк | `C_Container.GetContainerNumSlots`, `GetContainerItemID`, `GetContainerItemInfo`, `GetInventoryItemID("player", slot)` | банк отряда — отдельные контейнеры |

Все эти вызовы дешёвые по отдельности и дорогие в цикле на 20 000 предметов: сканировать
порциями по 200–250 за кадр и кэшировать результат в БД (`04-events-data.md`).

## Карта и зоны

```lua
local uiMapID = C_Map.GetBestMapForUnit("player")
local info = C_Map.GetMapInfo(uiMapID)        -- { name, mapType, parentMapID, ... }
-- подъём до континента:
while info and info.parentMapID and info.parentMapID ~= 0 do
    info = C_Map.GetMapInfo(info.parentMapID)
end
```

`Enum.UIMapType` (Continent/Zone/Dungeon/Micro). Имя карты локализовано клиентом —
на русском сервере совпадает с русскими названиями зон Wowhead (это используется при
сборке баз).

## Заклинания и профессии

```lua
C_Spell.GetSpellName(spellID)                  -- в 12.x; GetSpellInfo как глобал убран
local info = C_Spell.GetSpellInfo(spellID)     -- таблица: name, iconID, castTime, ...
```

Номера заклинаний между патчами перенумеровываются. Надёжнее опознавать профессию по
**имени** заклинания плюс по номеру, и обновлять таблицу номеров патчем (в Drop Ledger —
`Professions.lua`, спеллы рыбалки 7620, археологии 80451, сбора 2366/2575/8613).

## Время и таймеры

```lua
GetTime()                    -- секунды с загрузки (дробные), для интервалов
time()                       -- unix-время, для дат
C_Timer.After(0.5, fn)       -- одноразово
C_Timer.NewTimer(5, fn)      -- объект с Cancel()
C_Timer.NewTicker(1, fn, n)  -- повтор
```

Не создавать `OnUpdate` на каждый чих: тикер на 0.1 с на пустом экране — уже просадка.

## События: как слушать правильно

```lua
local f = CreateFrame("Frame")
local function OnEvent(self, event, ...)
    if event == "LOOT_OPENED" then
        local _, lootType = ...
        -- ...
    end
end
f:SetScript("OnEvent", OnEvent)

-- регистрация только того, что есть в этом клиенте
local function RegisterEvent(frame, event)
    if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
        local ok, valid = pcall(C_EventUtils.IsEventValid, event)
        if ok and valid == false then return false end
    end
    return pcall(frame.RegisterEvent, frame, event)
end
```

`pcall` вокруг `RegisterEvent` спасает только от Lua-ошибки, но **не** от запрета клиента
(боевой лог): нарушение всё равно засчитывается.

Полезные события (проверены в 12.x):

```
ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_LOGOUT
ZONE_CHANGED, ZONE_CHANGED_NEW_AREA, ZONE_CHANGED_INDOORS
LOOT_OPENED, LOOT_READY, CHAT_MSG_LOOT, ENCOUNTER_LOOT_RECEIVED
BOSS_KILL, ENCOUNTER_START, ENCOUNTER_END
PLAYER_TARGET_CHANGED, UNIT_HEALTH, UNIT_HEALTH_FREQUENT
UNIT_SPELLCAST_START, UNIT_SPELLCAST_SUCCEEDED, UNIT_SPELLCAST_CHANNEL_START,
UNIT_SPELLCAST_CHANNEL_STOP, SPELLS_CHANGED
BAG_UPDATE, BAG_UPDATE_DELAYED
MERCHANT_SHOW, MERCHANT_CLOSED
TRANSMOG_COLLECTION_UPDATED, NEW_MOUNT_ADDED, NEW_PET_ADDED, NEW_TOY_ADDED
GET_ITEM_INFO_RECEIVED
ADDON_ACTION_FORBIDDEN
```

`BOSS_KILL(encounterID, encounterName, difficultyID, groupSize, ...)` — `encounterID`
это ключ журнала (`DungeonEncounter`), точное попадание без сравнения имён.

`ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)`.

## Боевой лог закрыт (12.x)

`COMBAT_LOG_EVENT_UNFILTERED` и события, живущие только внутри лога (`UNIT_DIED`,
`SWING_DAMAGE`, `SPELL_DAMAGE`...), аддонам в 12.x недоступны. Регистрация = защищённый
вызов → метка `ADDON_ACTION_FORBIDDEN` → аддон блокируется. `pcall` не помогает.

Правильный подход:

```lua
function ns.CombatLogClosed()
    if ns._logClosed ~= nil then return ns._logClosed end
    local closed
    if C_Secrets or C_CombatLog then        -- 12.x: маркеры есть
        closed = true
    else
        local ok, toc = pcall(function() return select(4, GetBuildInfo()) end)
        local num = ok and tonumber(toc) or nil
        closed = (num == nil) or (num >= 120000)
    end
    ns._logClosed = closed
    return closed
end
```

Замена счёта убийств без лога: `PLAYER_TARGET_CHANGED` + `UNIT_HEALTH` (смерть по нулю
здоровья, пока цель удерживается) — оценочно, в подземельях здоровье может быть секретным;
поэтому такой режим по умолчанию выключен.

## Что нельзя ни при каких условиях

* Читать/писать память игры, патчить файлы клиента, инжектить DLL, эмулировать ввод
  (клики/клавиши программно) — блокировки и баны.
* Обходить капчу/Cloudflare при сборе данных «для аддона» (это делает человек в браузере).
* Регистрировать защищённые события и вызывать защищённые функции из taint-контекста
  («попробовать и поймать» — не стратегия).
* Менять защищённые фреймы (`UIParent`-композиция, `CompactRaidFrame*`) в бою:
  `InCombatLockdown()` → отложить до `PLAYER_REGEN_ENABLED`.
* Заменять глобальные функции Blizzard: только `hooksecurefunc` (безопасный хук).

## Различия 11.x → 12.x (то, на чём реально падало)

| Было (11.x) | Стало (12.x) | Симптом |
|---|---|---|
| `GetItemInfo(id)` | `C_Item.GetItemInfo(id)` (таблица) | `attempt to call a nil value` |
| `GetSpellInfo(id)` | `C_Spell.GetSpellInfo`/`GetSpellName` | то же |
| `PlayerModel:SetUnit(npc)` | `SetCreature(npcID)` для NPC | `ACCESS_VIOLATION` |
| `CanSetUnit` сравним с true | secret value | «клиент не отдаёт модель» всегда |
| боевой лог | закрыт | `ADDON_ACTION_FORBIDDEN` |
| `C_CreatureInfo.GetRaceInfo().name` | `.raceName` | «раса 7» вместо «Дворф» |
| `C_TransmogCollection.GetCategoryAppearances` | пусто | скан трансмога «ничего не находит» |
| `GetCategoryInfo`/`GetCategoryList` (коллекции) | часть убрана | nil в скане |
| `GetContainerItemInfo` | `C_Container.*` | nil в сумках |

Проверять на актуальном клиенте **и** держать обёртки-фолбэки на старые сборки: аддон
живёт несколько патчей, и часть игроков сидит на предыдущем.
