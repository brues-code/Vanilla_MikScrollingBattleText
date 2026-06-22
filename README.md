# Mik's Scrolling Battle Text (Vanilla)

A World of Warcraft 1.12 (Vanilla) addon that displays scrolling combat text around the player's character model. Originally by **Mik**, maintained by **Athene**.

**Interface:** 11200 | **Version:** 4.43

## Requirements

- **ClassicAPI** — a client-side DLL that backports modern WoW API calls to the 1.12 client (no companion addon required). MSBT relies on it for `C_Spell.GetSpellName`, `C_Item.GetItemName`/`GetItemIcon`, `ItemLocation`, and `CreateColor`/`GetRGB` — used for spell-name lookups, item-icon resolution, and damage-type text coloring. These are not optional fast paths; the addon expects them to be present.

## Features

- Scrolling combat text across three display areas: **Incoming** (right), **Outgoing** (left), and **Notification** (center)
- Damage, heals, DoTs, HoTs, misses, dodges, parries, blocks, resists, absorbs, reflects, and more
- Buff/debuff gain and fade notifications
- Power gains and losses (mana, rage, energy)
- Combo points, honor, reputation, skill, and experience gains
- Killing blow notifications (PC and NPC)
- Environmental damage (drowning, falling, fire, lava, fatigue, slime)
- Spell icons displayed alongside scrolling text
- Class-colored unit names
- Configurable profiles with 100+ event settings
- Customizable animation styles (Straight, Left Parabola, Right Parabola) and scroll directions (Up, Down)
- Sticky text for crits and important events
- Event merging to reduce clutter in heavy combat
- Event suppression via configurable search patterns
- Health/mana threshold triggers with per-class filtering
- Search pattern triggers for custom event matching
- Four locales: English, French, German, Russian

## Addon Packages

### MikScrollingBattleText (Core)

The main addon. Parses combat log events, formats text, and animates scrolling messages.

### MikScrollingBattleTextOptions (Options UI)

Load-on-demand options panel. Only loaded when the user opens settings via `/msbt`.

## Installation

Copy both `MikScrollingBattleText/` and `MikScrollingBattleTextOptions/` into your `Interface/AddOns/` directory.

```
Interface/
  AddOns/
    MikScrollingBattleText/
    MikScrollingBattleTextOptions/
```

## Slash Commands

`/msbt` — Open the options UI

| Command | Description |
|---|---|
| `/msbt reset` | Reset the current profile to defaults |
| `/msbt disable` | Disable the addon |
| `/msbt enable` | Enable the addon |
| `/msbt version` | Show the current version |
| `/msbt stats` | Report table recycling statistics |
| `/msbt search <filter>` | Set a filter for searching event types |
| `/msbt debug` | Toggle debug mode |
| `/msbt help` | Show command usage |

## Nampower Integration

When Nampower is detected, MSBT automatically switches from string-based combat log parsing to structured event handling for significantly better performance in heavy combat scenarios (raids, AoE, battlegrounds).

### What Changes

- **Nampower**: Registers for structured events (`SPELL_DAMAGE_EVENT_SELF`, `AUTO_ATTACK_SELF`, `SPELL_HEAL_ON_SELF`, etc.) that provide pre-parsed combat data. Redundant `CHAT_MSG_*` events are unregistered to avoid duplicates. Enables `NP_EnableAutoAttackEvents`, `NP_EnableSpellHealEvents`, and `NP_EnableSpellEnergizeEvents` CVars.

### Deprecated: SuperWoW / UnitXP SP3

SuperWoW and UnitXP SP3 integration is being removed in favor of ClassicAPI (for spell/item lookups) and Nampower (for structured combat events). The detection paths (`SuperWoW`: O(1) `UnitExists(name)` lookups and `SpellInfo` icon resolution; `UnitXP SP3`: GUID-based unit resolution) still exist for now but should not be relied on and will be deleted.

### Fallback

When none of these mods are present, the addon falls back to the original string-parsing pipeline with no changes in behavior.

### Verification

```lua
-- Check detection status in-game:
/run MikSBT.Print("NP="..tostring(MikCEH.hasNampower).." SW="..tostring(MikCEH.hasSuperWoW).." UXP="..tostring(MikCEH.hasUnitXP))
```

## Performance Optimizations

- **Upvalue caching**: Frequently called standard library functions (`string.find`, `string.gsub`, `table.insert`, `table.getn`, `GetTime`, etc.) are cached as local variables
- **Dispatch table**: Combat event routing uses O(1) table lookup instead of an if/elseif chain
- **SpellId icon cache**: When spellIds are available (via Nampower/SuperWoW), icons are resolved directly and cached, bypassing Babble-Spell dictionary lookups and tooltip scanning
- **Event throttling**: UNIT_HEALTH and UNIT_MANA trigger checks are throttled to 150ms intervals
- **Table recycling**: `MikTRO` (Table Recycler Object) pools and reuses table allocations to reduce garbage collection pressure

## Architecture

### Global Namespaces

| Namespace | Purpose |
|---|---|
| `MikSBT` | Main addon: display, animation, profiles, event routing, slash commands |
| `MikCEH` | Combat Event Helper: parses combat events into structured data |
| `MikTRO` | Table Recycler Object: memory pool for table reuse |

### Event Processing Pipeline

```
WoW CHAT_MSG_* events (or Nampower structured events)
  -> MikCEH.OnEvent() / MikCEH.OnNampowerEvent()
  -> ParseCombatEvents() dispatch table (or Nampower handler)
  -> Creates CombatEventData tables
  -> MikSBT.CombatEventsHandler()
  -> Formats text with templates (%a=amount, %n=name, %s=spell, %t=type)
  -> Queues animation event
  -> MikSBT.OnUpdateAnimationFrame() renders scrolling text
```

### Bundled Libraries

- **AceLibrary** — Addon framework skeleton
- **AceLocale-2.2** — Localization management
- **Babble-Spell-2.2** — Spell name database for icon lookups (~10K lines)

### Saved Variables

`MikSBT_Save` — Stores named profiles containing event settings, triggers, suppressions, display positions, and font settings. Profiles support versioning and migration between addon versions.

## Development

- No build step — files are loaded directly by the WoW client via TOC manifests
- No test framework — testing is done manually in the WoW client
- The Lua environment is WoW's embedded Lua 5.0/5.1 (not standard Lua 5.4)
- IDE warnings about "undefined globals" (`CreateFrame`, `GetLocale`, `DEFAULT_CHAT_FRAME`, `arg1`, `event`, etc.) are false positives — these are provided by the WoW runtime
- The `wow-api-type-definitions/` submodule provides WoW API type stubs for IDE autocompletion (sumneko.lua language server)

## Optional Dependency

- **SW_FixLogStrings** — Fixes combat log string formatting issues on some server implementations

## License

This addon is distributed for use with World of Warcraft 1.12 private servers. Original work by Mik, community maintained.
