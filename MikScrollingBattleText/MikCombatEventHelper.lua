-------------------------------------------------------------------------------------
-- Title: Mik's Combat Event Helper
-- Author: Mik
-- Maintainer: Athene
-------------------------------------------------------------------------------------

-- Create "namespace."
MikCEH = {};

-- Upvalue caches for frequently called functions.
local string_find, string_gsub = string.find, string.gsub
local string_len, string_sub, string_gfind = string.len, string.sub, string.gfind
local table_insert, table_getn, table_setn = table.insert, table.getn, table.setn
local GetTime, UnitHealth, UnitHealthMax = GetTime, UnitHealth, UnitHealthMax
local UnitMana, UnitManaMax, UnitName = UnitMana, UnitManaMax, UnitName
local UnitIsPlayer, UnitIsFriend, UnitExists = UnitIsPlayer, UnitIsFriend, UnitExists
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local pairs, tonumber, type, pcall = pairs, tonumber, type, pcall

-------------------------------------------------------------------------------------
-- Public constants.
-------------------------------------------------------------------------------------

-- Event types.
MikCEH.EVENTTYPE_DAMAGE		= 1;
MikCEH.EVENTTYPE_HEAL		= 2;
MikCEH.EVENTTYPE_NOTIFICATION	= 3;

-- Direction types.
MikCEH.DIRECTIONTYPE_PLAYER_INCOMING	= 1;
MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING	= 2;
MikCEH.DIRECTIONTYPE_PET_OUTGOING		= 3;
MikCEH.DIRECTIONTYPE_PET_INCOMING		= 4;

-- Action types.
MikCEH.ACTIONTYPE_HIT		= 1;
MikCEH.ACTIONTYPE_MISS		= 2;
MikCEH.ACTIONTYPE_DODGE		= 3;
MikCEH.ACTIONTYPE_PARRY		= 4;
MikCEH.ACTIONTYPE_BLOCK		= 5;
MikCEH.ACTIONTYPE_RESIST	= 6;
MikCEH.ACTIONTYPE_ABSORB	= 7;
MikCEH.ACTIONTYPE_IMMUNE	= 8;
MikCEH.ACTIONTYPE_EVADE		= 9;
MikCEH.ACTIONTYPE_REFLECT	= 10;
MikCEH.ACTIONTYPE_DROWNING	= 11;
MikCEH.ACTIONTYPE_FALLING	= 12;
MikCEH.ACTIONTYPE_FATIGUE	= 13;
MikCEH.ACTIONTYPE_FIRE		= 14;
MikCEH.ACTIONTYPE_LAVA		= 15;
MikCEH.ACTIONTYPE_SLIME		= 16;


-- Hit types.
MikCEH.HITTYPE_NORMAL		= 1;
MikCEH.HITTYPE_CRIT		= 2;
MikCEH.HITTYPE_OVER_TIME	= 3;

-- Damage types.
MikCEH.DAMAGETYPE_PHYSICAL	= 1;
MikCEH.DAMAGETYPE_HOLY		= 2;
MikCEH.DAMAGETYPE_NATURE	= 3;
MikCEH.DAMAGETYPE_FIRE		= 4;
MikCEH.DAMAGETYPE_FROST		= 5;
MikCEH.DAMAGETYPE_SHADOW	= 6;
MikCEH.DAMAGETYPE_ARCANE	= 7;
MikCEH.DAMAGETYPE_UNKNOWN	= 999;

-- Partial action types.
MikCEH.PARTIALACTIONTYPE_ABSORB	= 1;
MikCEH.PARTIALACTIONTYPE_BLOCK	= 2;
MikCEH.PARTIALACTIONTYPE_RESIST	= 3;
MikCEH.PARTIALACTIONTYPE_VULNERABLE	= 4;
MikCEH.PARTIALACTIONTYPE_CRUSHING	= 5;
MikCEH.PARTIALACTIONTYPE_GLANCING	= 6;
MikCEH.PARTIALACTIONTYPE_OVERHEAL	= 7;

-- Heal types.
MikCEH.HEALTYPE_NORMAL		= 1;
MikCEH.HEALTYPE_CRIT		= 2;
MikCEH.HEALTYPE_OVER_TIME	= 3;

-- Notification types.
MikCEH.NOTIFICATIONTYPE_DEBUFF		= 1;
MikCEH.NOTIFICATIONTYPE_BUFF			= 2;
MikCEH.NOTIFICATIONTYPE_ITEM_BUFF		= 3;
MikCEH.NOTIFICATIONTYPE_BUFF_FADE		= 4;
MikCEH.NOTIFICATIONTYPE_COMBAT_ENTER	= 5;
MikCEH.NOTIFICATIONTYPE_COMBAT_LEAVE	= 6;
MikCEH.NOTIFICATIONTYPE_POWER_GAIN		= 7;
MikCEH.NOTIFICATIONTYPE_POWER_LOSS		= 8;
MikCEH.NOTIFICATIONTYPE_CP_GAIN		= 9;
MikCEH.NOTIFICATIONTYPE_HONOR_GAIN		= 10;
MikCEH.NOTIFICATIONTYPE_REP_GAIN		= 11;
MikCEH.NOTIFICATIONTYPE_REP_LOSS		= 12;
MikCEH.NOTIFICATIONTYPE_SKILL_GAIN		= 13;
MikCEH.NOTIFICATIONTYPE_EXPERIENCE_GAIN	= 14;
MikCEH.NOTIFICATIONTYPE_PC_KILLING_BLOW	= 15;
MikCEH.NOTIFICATIONTYPE_NPC_KILLING_BLOW	= 16;


-- Trigger types.
MikCEH.TRIGGERTYPE_SELF_HEALTH	= 1;
MikCEH.TRIGGERTYPE_SELF_MANA		= 2;
MikCEH.TRIGGERTYPE_PET_HEALTH		= 3;
MikCEH.TRIGGERTYPE_ENEMY_HEALTH	= 4;
MikCEH.TRIGGERTYPE_FRIENDLY_HEALTH	= 5;
MikCEH.TRIGGERTYPE_SEARCH_PATTERN	= 6;


-------------------------------------------------------------------------------------
-- Public variables.
-------------------------------------------------------------------------------------

-- Hold combat event data.
MikCEH.CombatEventData = {};

-- Hold trigger event data.
MikCEH.TriggerEventData = {};

-------------------------------------------------------------------------------------
-- Private constants.
-------------------------------------------------------------------------------------

-- Amount of time to delay between selected player list updates and how long
-- to hold a recently selected player in cache.
local RECENTLY_SELECTED_PLAYERS_UPDATE_INTERVAL = 1;
local RECENTLY_SELECTED_PLAYERS_HOLD_TIME = 45;


-------------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------------

-- Holds the events the helper is interested in receiving.
local listenEvents = {};

-- Holds formatted global strings.
local globalStringInfoArray = {};

-- Holds the name and class of the player.
local playerName;
local playerClass;

-- Cached pet name, updated once per event dispatch.
local cachedPetName;

-- Tables to hold ordered/unordered captured data.
local orderedCaptureData = {};
local unorderedCaptureData = {};


-- Holds whether or not event searching mode is active and the pattern for it.
local searchMode = false;
local searchModePattern;

-- Tables to hold the triggers in a format optimized for searching.
local selfHealthTriggers = {};
local selfManaTriggers =  {};
local petHealthTriggers = {};
local enemyHealthTriggers =  {};
local friendlyHealthTriggers =  {};
local searchPatternTriggers = {};

-- Holds previous health and mana values.
local lastSelfHealthPercentage = 0;
local lastSelfManaPercentage = 0;
local lastSelfManaAmount = UnitMana("player");
local lastPetHealthPercentage = 0;
local lastEnemyHealthPercentage = 0;
local lastFriendlyHealthPercentage = 0;

-- Holds a list of recently selected hostile players.
local recentlySelectedPlayers = {};
local elapsedTime = 0;

-- Feature detection flag for Nampower structured combat events.
local hasNampower = false

-- Runtime detection flags for Nampower events.
-- These start false and flip true on first invocation of the corresponding handler,
-- so CHAT_MSG parsing remains active until the Nampower events actually fire.
local nampowerHealsActive = false
local nampowerAutoAttackActive = false
local nampowerEnergizeActive = false
local nampowerSpellDamageActive = false
local nampowerBuffsActive = false
local nampowerPetAutoAttackActive = false
local nampowerPetSpellDamageActive = false

-- Cached player GUID for Nampower event handlers (set in Init when Nampower is present).
local playerGUID = nil

-- Event throttling for trigger checks.
local TRIGGER_THROTTLE_INTERVAL = 0.15
local lastTriggerCheckTime = 0

-- Nampower event frame and dispatch table (initialized in SetupNampowerEvents).
local nampowerEventFrame = nil
local nampowerHandlers = {}

-- Spell name cache for spellId lookups.
local spellNameCache = {}

-- Name→unitID cache for avoiding O(n) raid/party iteration.
local nameToUnitIDCache = {}
local nameToUnitIDCacheDirty = true

local function RebuildNameToUnitIDCache()
 nameToUnitIDCache = {}
 local numRaid = GetNumRaidMembers()
 if numRaid > 0 then
  for i = 1, numRaid do
   local ruid = "raid" .. i
   local rname = UnitName(ruid)
   if rname then nameToUnitIDCache[rname] = ruid end
   local rpuid = "raidpet" .. i
   local rpname = UnitName(rpuid)
   if rpname then nameToUnitIDCache[rpname] = rpuid end
  end
 else
  local numParty = GetNumPartyMembers()
  for i = 1, numParty do
   local puid = "party" .. i
   local pname = UnitName(puid)
   if pname then nameToUnitIDCache[pname] = puid end
   local ppuid = "partypet" .. i
   local ppname = UnitName(ppuid)
   if ppname then nameToUnitIDCache[ppname] = ppuid end
  end
 end
 nameToUnitIDCacheDirty = false
end


-------------------------------------------------------------------------------------
-- Core event handlers.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Registers all of the events the helper is interested in.
-- **********************************************************************************
function MikCEH.RegisterEvents()
 -- Register the events we are interested in receiving.
 for k, v in listenEvents do
  MCEHEventFrame:RegisterEvent(v);
 end 
end


-- **********************************************************************************
-- Unregisters all of the event the helper registered for.
-- **********************************************************************************
function MikCEH.UnregisterEvents()
 -- Register the events we are interested in receiving.
 for k, v in listenEvents do
  MCEHEventFrame:UnregisterEvent(v);
 end 
end


-- **********************************************************************************
-- Called when the helper's event frame is loaded.
-- **********************************************************************************
function MikCEH.OnLoad()
 -- Load up the listen events table with the events the helper is interested in.
 table_insert(listenEvents, "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS");		-- Incoming Melee Hits/Crits
 table_insert(listenEvents, "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS");		-- Incoming Melee Hits/Crits
 table_insert(listenEvents, "CHAT_MSG_COMBAT_PARTY_HITS");				-- Incoming Melee Hits/Crits 
 table_insert(listenEvents, "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES"); 	-- Incoming Melee Misses, Dodges, Parries, Blocks, Absorbs, Immunes
 table_insert(listenEvents, "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES");		-- Incoming Melee Misses, Dodges, Parries, Blocks, Absorbs, Immunes
 table_insert(listenEvents, "CHAT_MSG_COMBAT_PARTY_MISSES");			-- Incoming Melee Misses, Dodges, Parries, Blocks, Absorbs, Immunes
 table_insert(listenEvents, "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE");		-- Incoming Spell/Ability Damage, Misses, Dodges, Parries, Blocks, Absorbs, Resists, Immunes, Power Losses
 table_insert(listenEvents, "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE");		-- Incoming Spell/Ability Damage, Misses, Dodges, Parries, Blocks, Absorbs, Resists, Immunes, Power Losses -- athenne add
 table_insert(listenEvents, "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE");		-- Incoming Spell/Ability Damage, Misses, Dodges, Parries, Blocks, Absorbs, Resists, Immunes, Power Losses
 table_insert(listenEvents, "CHAT_MSG_SPELL_PARTY_DAMAGE");				-- Incoming Spell/Ability Damage, Misses, Dodges, Parries, Blocks, Absorbs, Resists, Immunes, Power Losses
 table_insert(listenEvents, "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS");		-- Incoming damage from shields
 table_insert(listenEvents, "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF");			-- Incoming Heals
 table_insert(listenEvents, "CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF");		-- Incoming Heals
 table_insert(listenEvents, "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE");		-- Incoming Debuffs, DoTs, Power Gains
 table_insert(listenEvents, "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS");		-- Incoming Buffs, HoTs, Power Gains

 table_insert(listenEvents, "CHAT_MSG_COMBAT_SELF_HITS");				-- Outgoing Melee Hits/Crits, Environmental Damage
 table_insert(listenEvents, "CHAT_MSG_COMBAT_SELF_MISSES");  			-- Outgoing Melee Misses, Dodges, Parries, Blocks, Absorbs, Immunes, Evades
 table_insert(listenEvents, "CHAT_MSG_SPELL_SELF_DAMAGE");				-- Outgoing Spell/Ability Damage, Misses, Dodges, Parries, Blocks, Absorbs, Resists, Immunes, Evades
 table_insert(listenEvents, "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF");		-- Outgoing damage from shields
 table_insert(listenEvents, "CHAT_MSG_SPELL_SELF_BUFF");				-- Outgoing Heals, Power Gains, Dispel/Purge Resists
 table_insert(listenEvents, "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS");	-- Outgoing HoTs
 table_insert(listenEvents, "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS");		-- Outgoing HoTs
 table_insert(listenEvents, "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS");
 table_insert(listenEvents, "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE");		-- Outgoing DoTs
 table_insert(listenEvents, "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE");	-- Outgoing DoTs, Power Losses
 table_insert(listenEvents, "CHAT_MSG_COMBAT_PET_HITS");				-- Outgoing Pet Melee Hits/Crits
 table_insert(listenEvents, "CHAT_MSG_COMBAT_PET_MISSES");				-- Outgoing Pet Melee Misses
 table_insert(listenEvents, "CHAT_MSG_SPELL_PET_DAMAGE");				-- Outgoing Pet Spell/Ability Damage, Misses, Dodges, Parries, Blocks, Absorbs, Resists, Immunes, Evades

 table_insert(listenEvents, "CHAT_MSG_SPELL_ITEM_ENCHANTMENTS");			-- Item Buffs
 table_insert(listenEvents, "CHAT_MSG_SPELL_AURA_GONE_SELF");			-- Buff Fades
 table_insert(listenEvents, "CHAT_MSG_COMBAT_HONOR_GAIN");				-- Honor Gains
 table_insert(listenEvents, "CHAT_MSG_COMBAT_FACTION_CHANGE");			-- Reputation Gains/Losses
 table_insert(listenEvents, "CHAT_MSG_SKILL");						-- Skill Gains
 table_insert(listenEvents, "CHAT_MSG_COMBAT_XP_GAIN");				-- Experience Gains
 table_insert(listenEvents, "CHAT_MSG_COMBAT_HOSTILE_DEATH");			-- Killing Blows
-- table_insert(listenEvents, "CHAT_MSG_SYSTEM");					-- Created Items

 table_insert(listenEvents, "PLAYER_REGEN_ENABLED");					-- Leave Combat
 table_insert(listenEvents, "PLAYER_REGEN_DISABLED");					-- Enter Combat
 table_insert(listenEvents, "PLAYER_COMBO_POINTS");					-- Combo Point Gains
 table_insert(listenEvents, "UNIT_HEALTH");						-- Health changes.
 table_insert(listenEvents, "UNIT_MANA");							-- Mana changes.

 table_insert(listenEvents, "PLAYER_TARGET_CHANGED");					-- Target changes.
 table_insert(listenEvents, "RAID_ROSTER_UPDATE");					-- Roster cache invalidation.
 table_insert(listenEvents, "PARTY_MEMBERS_CHANGED");					-- Roster cache invalidation.

 -- If Nampower is available, set up Nampower events and filter redundant CHAT_MSG events.
 if (GetNampowerVersion ~= nil) then
  MikCEH.SetupNampowerEvents();
 end

 -- Register for the ADDON_LOADED and PLAYER_ENTERING_WORLD events.
 MCEHEventFrame:RegisterEvent("ADDON_LOADED");
 MCEHEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
end


-- **********************************************************************************
-- Called when the events the helper registered for occur.
-- **********************************************************************************
function MikCEH.OnEvent()
 -- When an addon is loaded.
 if (event == "ADDON_LOADED") then
  -- Make sure it's the right addon.
  if (arg1 == MikSBT.MOD_NAME) then

   -- Don't get notification for other addons being loaded.
   this:UnregisterEvent("ADDON_LOADED");

   -- Register for the events the helper is interested in receiving.
   MikCEH.RegisterEvents();

   -- Initialize the helper object.
   MikCEH.Init();
  end

 -- Retry playerGUID initialization when the player fully enters the world.
 elseif (event == "PLAYER_ENTERING_WORLD") then
  this:UnregisterEvent("PLAYER_ENTERING_WORLD");
  if not playerGUID then
   if hasNampower and UnitGUID then
    local ok, guid = pcall(UnitGUID, "player")
    if ok and guid then playerGUID = guid end
   end
  end

 -- Leave Combat
 elseif (event == "PLAYER_REGEN_ENABLED") then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_COMBAT_LEAVE, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

 -- Enter Combat
 elseif (event == "PLAYER_REGEN_DISABLED") then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_COMBAT_ENTER, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

 -- Combo Point Gains
 elseif (event == "PLAYER_COMBO_POINTS") then
  local numCP = GetComboPoints();

  -- Make sure the number of combo points is more than one.
  if (numCP ~= 0) then
   local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_CP_GAIN, numCP, nil);

   -- Send the event.
   MikCEH.SendEvent(eventData);
  end

 -- Health changes (throttled to reduce CPU in heavy combat)
 elseif (event == "UNIT_HEALTH") then
  local now = GetTime()
  if (now - lastTriggerCheckTime >= TRIGGER_THROTTLE_INTERVAL) then
   lastTriggerCheckTime = now
   if (arg1 == "player") then
    MikCEH.ParseSelfHealthTriggers();
   elseif (arg1 == "target") then
    if (not UnitIsFriend("player", "target")) then
     MikCEH.ParseEnemyHealthTriggers();
    else
     MikCEH.ParseFriendlyHealthTriggers();
    end
   elseif (arg1 == "pet") then
    MikCEH.ParsePetHealthTriggers();
   end
  end

 -- Mana changes (throttled)
 elseif (event == "UNIT_MANA") then
  local now = GetTime()
  if (now - lastTriggerCheckTime >= TRIGGER_THROTTLE_INTERVAL) then
   lastTriggerCheckTime = now
   if (arg1 == "player") then
    MikCEH.ParseSelfManaTriggers();
   end
  end

 -- Roster changes — invalidate name→unitID cache.
 elseif (event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED") then
  nameToUnitIDCacheDirty = true

 -- Target changes
 elseif (event == "PLAYER_TARGET_CHANGED") then
  -- Make sure a unit is selected, is a player and is hostile.
  if (UnitExists("target") and UnitIsPlayer("target") and not UnitIsFriend("player", "target")) then
   -- Get the unit's name and make sure it's valid before adding it to the recently selected player's list.
   local targetName = UnitName("target");
   if (targetName) then
    recentlySelectedPlayers[targetName] = 0;
   end
  end

 -- Chat message combat events.
 else
  MikCEH.ParseSearchPatternTriggers(event, arg1);
  MikCEH.ParseCombatEvents(event, arg1);

 end
end


-- **********************************************************************************
-- This function parses the chat message combat events.
-- **********************************************************************************
function MikCEH.OnUpdate()
 -- Increment the amount of time passed since the last update.
 elapsedTime = elapsedTime + arg1;

 -- Check if it's time for an update.
 if (elapsedTime >= RECENTLY_SELECTED_PLAYERS_UPDATE_INTERVAL) then
  -- Loop through all of the recently selected players.
  for playerName, lastSeen in recentlySelectedPlayers do
   -- Increment the amount of time since the player was last seen.
   recentlySelectedPlayers[playerName] = lastSeen + elapsedTime;

   -- Check if enough time has passed and remove the player from the list.
   if (lastSeen + elapsedTime >= RECENTLY_SELECTED_PLAYERS_HOLD_TIME) then
    recentlySelectedPlayers[playerName] = nil;
   end
  end

  -- Reset the elapsed time.
  elapsedTime = 0;
 end
end


-- **********************************************************************************
-- Combat event dispatch table. Maps event names to handler functions.
-- Replaces the if/elseif chain for O(1) dispatch.
-- **********************************************************************************
local combatEventDispatch = {}

-- Incoming Melee Hits/Crits (CVar-gated: AUTO_ATTACK_OTHER)
local function handleIncomingMeleeHits(msg)
 if nampowerAutoAttackActive then return end
 MikCEH.ParseForIncomingHits(msg)
end
combatEventDispatch["CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"] = handleIncomingMeleeHits
combatEventDispatch["CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS"] = handleIncomingMeleeHits
combatEventDispatch["CHAT_MSG_COMBAT_PARTY_HITS"] = handleIncomingMeleeHits

-- Incoming Melee Misses, Dodges, Parries, Blocks, Absorbs, Immunes (CVar-gated: AUTO_ATTACK_OTHER)
local function handleIncomingMeleeMisses(msg)
 if nampowerAutoAttackActive then return end
 MikCEH.ParseForIncomingMisses(msg)
end
combatEventDispatch["CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES"] = handleIncomingMeleeMisses
combatEventDispatch["CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES"] = handleIncomingMeleeMisses
combatEventDispatch["CHAT_MSG_COMBAT_PARTY_MISSES"] = handleIncomingMeleeMisses

-- Incoming Spell/Ability Damage + Power Losses (Nampower: SPELL_DAMAGE_EVENT_OTHER)
local function handleIncomingSpellDamage(msg)
 if not nampowerSpellDamageActive then
  MikCEH.ParseForIncomingSpellHitsAndMisses(msg)
 end
 MikCEH.ParseForPowerLosses(msg)
end
combatEventDispatch["CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"] = handleIncomingSpellDamage
combatEventDispatch["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE"] = handleIncomingSpellDamage
combatEventDispatch["CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE"] = handleIncomingSpellDamage
combatEventDispatch["CHAT_MSG_SPELL_PARTY_DAMAGE"] = handleIncomingSpellDamage

-- Incoming damage from shields (Nampower: SPELL_DAMAGE_EVENT_OTHER)
combatEventDispatch["CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS"] = function(msg)
 if nampowerSpellDamageActive then return end
 MikCEH.ParseForIncomingDamageShieldDamage(msg)
end

-- Incoming Heals (CVar-gated: SPELL_HEAL_ON_SELF)
local function handleIncomingSpellHeals(msg)
 if nampowerHealsActive then return end
 MikCEH.ParseForIncomingSpellHeals(msg)
end
combatEventDispatch["CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF"] = handleIncomingSpellHeals
combatEventDispatch["CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF"] = handleIncomingSpellHeals

-- Incoming Debuffs, DoTs, Power Gains
combatEventDispatch["CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"] = function(msg)
 if not nampowerBuffsActive and not nampowerSpellDamageActive then
  MikCEH.ParseForIncomingDebuffs(msg)
 end
 if not nampowerEnergizeActive then
  MikCEH.ParseForPowerGains(msg)
 end
end

-- Incoming Buffs, HoTs, Power Gains
combatEventDispatch["CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS"] = function(msg)
 if not nampowerHealsActive then
  if not MikCEH.ParseForIncomingSpellHeals(msg) then
   if not nampowerBuffsActive and not nampowerSpellDamageActive then
    MikCEH.ParseForIncomingBuffs(msg)
   end
   MikCEH.ParseForOutgoingHoTs(msg)
  end
 end
end

-- Outgoing Melee Hits/Crits, Environmental Damage (CVar-gated: AUTO_ATTACK_SELF)
combatEventDispatch["CHAT_MSG_COMBAT_SELF_HITS"] = function(msg)
 if not MikCEH.ParseForEnvironmentalDamage(msg) then
  if not nampowerAutoAttackActive then
   MikCEH.ParseForOutgoingHits(msg)
  end
 end
end

-- Outgoing Melee Misses (CVar-gated: AUTO_ATTACK_SELF)
combatEventDispatch["CHAT_MSG_COMBAT_SELF_MISSES"] = function(msg)
 if nampowerAutoAttackActive then return end
 MikCEH.ParseForOutgoingMisses(msg)
end

-- Outgoing Spell/Ability Damage (Nampower: SPELL_DAMAGE_EVENT_SELF)
combatEventDispatch["CHAT_MSG_SPELL_SELF_DAMAGE"] = function(msg)
 if nampowerSpellDamageActive then return end
 MikCEH.ParseForOutgoingSpellHitsAndMisses(msg)
end

-- Outgoing damage from shields (Nampower: SPELL_DAMAGE_EVENT_SELF)
combatEventDispatch["CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF"] = function(msg)
 if nampowerSpellDamageActive then return end
 MikCEH.ParseForOutgoingDamageShieldDamage(msg)
end

-- Outgoing Heals, Power Gains, Dispel/Purge Resists (CVar-gated: SPELL_HEAL_BY_SELF, SPELL_ENERGIZE_ON_SELF)
combatEventDispatch["CHAT_MSG_SPELL_SELF_BUFF"] = function(msg)
 if not nampowerEnergizeActive then
  if MikCEH.ParseForPowerGains(msg) then return end
 end
 if not nampowerHealsActive then
  MikCEH.ParseForOutgoingSpellHeals(msg)
  MikCEH.ParseForOutgoingDispelResists(msg)
 end
end

-- Outgoing HoTs (CVar-gated: SPELL_HEAL_BY_SELF)
local function handleOutgoingHoTs(msg)
 if nampowerHealsActive then return end
 MikCEH.ParseForOutgoingHoTs(msg)
end
combatEventDispatch["CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS"] = handleOutgoingHoTs
combatEventDispatch["CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS"] = handleOutgoingHoTs
combatEventDispatch["CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS"] = handleOutgoingHoTs

-- Outgoing DoTs, Power Losses (Nampower: SPELL_DAMAGE_EVENT_SELF with DoT flag)
local function handleOutgoingDoTs(msg)
 if not nampowerSpellDamageActive then
  MikCEH.ParseForOutgoingDoTs(msg)
 end
 MikCEH.ParseForPowerLosses(msg)
end
combatEventDispatch["CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"] = handleOutgoingDoTs
combatEventDispatch["CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"] = handleOutgoingDoTs

-- Outgoing Pet Hits/Crits (CVar-gated: AUTO_ATTACK_SELF with pet GUID)
combatEventDispatch["CHAT_MSG_COMBAT_PET_HITS"] = function(msg)
 if nampowerPetAutoAttackActive then return end
 MikCEH.ParseForOutgoingPetHits(msg)
end

-- Outgoing Pet Melee Misses (CVar-gated: AUTO_ATTACK_SELF with pet GUID)
combatEventDispatch["CHAT_MSG_COMBAT_PET_MISSES"] = function(msg)
 if nampowerPetAutoAttackActive then return end
 MikCEH.ParseForOutgoingPetMisses(msg)
end

-- Outgoing Pet Spell/Ability Damage (Nampower: SPELL_DAMAGE_EVENT_SELF with pet GUID)
combatEventDispatch["CHAT_MSG_SPELL_PET_DAMAGE"] = function(msg)
 if nampowerPetSpellDamageActive then return end
 MikCEH.ParseForOutgoingPetSpellHitsAndMisses(msg)
end

-- Item Buffs
combatEventDispatch["CHAT_MSG_SPELL_ITEM_ENCHANTMENTS"] = function(msg)
 MikCEH.ParseForIncomingItemBuffs(msg)
end

-- Buff Fades
combatEventDispatch["CHAT_MSG_SPELL_AURA_GONE_SELF"] = function(msg)
 MikCEH.ParseForBuffFades(msg)
end

-- Honor Gains
combatEventDispatch["CHAT_MSG_COMBAT_HONOR_GAIN"] = function(msg)
 MikCEH.ParseForHonorGains(msg)
end

-- Reputation Gains/Losses
combatEventDispatch["CHAT_MSG_COMBAT_FACTION_CHANGE"] = function(msg)
 MikCEH.ParseForReputationGainsAndLosses(msg)
end

-- Skill Gains
combatEventDispatch["CHAT_MSG_SKILL"] = function(msg)
 MikCEH.ParseForSkillGains(msg)
end

-- Experience Gains
combatEventDispatch["CHAT_MSG_COMBAT_XP_GAIN"] = function(msg)
 MikCEH.ParseForExperienceGains(msg)
end

-- Killing Blows
combatEventDispatch["CHAT_MSG_COMBAT_HOSTILE_DEATH"] = function(msg)
 MikCEH.ParseForKillingBlows(msg)
end


-- **********************************************************************************
-- This function parses the chat message combat events using the dispatch table.
-- **********************************************************************************
function MikCEH.ParseCombatEvents(event, combatMessage)
 cachedPetName = UnitName("pet");
 local handler = combatEventDispatch[event]
 if handler then handler(combatMessage) end
end


-- **********************************************************************************
-- Called when the helper is fully loaded.
-- **********************************************************************************
function MikCEH.Init()
 -- Get the name of the player and the player's class.
 playerName = UnitName("player");
 _, playerClass = UnitClass("player");

 -- Detect Nampower structured combat event support.
 hasNampower = (GetNampowerVersion ~= nil)
 MikCEH.hasNampower = hasNampower
 MikCEH.nampowerHealsActive = false
 MikCEH.nampowerAutoAttackActive = false
 MikCEH.nampowerEnergizeActive = false
 MikCEH.nampowerSpellDamageActive = false
 MikCEH.nampowerBuffsActive = false
 MikCEH.nampowerPetAutoAttackActive = false
 MikCEH.nampowerPetSpellDamageActive = false

 -- Check Nampower version — v2.33.0+ required for correct event support.
 if not hasNampower then
  MikSBT.Print("Nampower not detected. Please install Nampower v2.33.0+ for full combat text support.", 1, 0.5, 0)
 else
  local ok, major, minor, patch = pcall(GetNampowerVersion)
  if ok and major and minor then
   if major < 2 or (major == 2 and minor < 33) then
    MikSBT.Print("Nampower v" .. major .. "." .. minor .. "." .. (patch or 0) .. " detected. Please update to v2.33.0+ for full combat text support.", 1, 0.5, 0)
   end
  end
 end

 -- Cache the player GUID when Nampower is available.
 if hasNampower and UnitGUID then
  local ok, guid = pcall(UnitGUID, "player")
  if ok and guid then playerGUID = guid end
 end
end


-------------------------------------------------------------------------------------
-- Nampower Infrastructure.
-------------------------------------------------------------------------------------

-- Spell school index (Nampower) to MikCEH damage type mapping.
-- Nampower reports the school as a sequential index (0 = Physical, 1 = Holy,
-- 2 = Fire, ...), not the power-of-two bitmask the comment previously assumed.
local nampowerSchoolToType = {
 [0] = MikCEH.DAMAGETYPE_PHYSICAL,
 MikCEH.DAMAGETYPE_HOLY,
 MikCEH.DAMAGETYPE_FIRE,
 MikCEH.DAMAGETYPE_NATURE,
 MikCEH.DAMAGETYPE_FROST,
 MikCEH.DAMAGETYPE_SHADOW,
 MikCEH.DAMAGETYPE_ARCANE,
}

-- Nampower SpellMissInfo to MikCEH action type mapping.
local nampowerMissToAction = {
 -- [0] = SPELL_MISS_NONE (should not appear)
 [1]  = MikCEH.ACTIONTYPE_MISS,     -- SPELL_MISS_MISS
 [2]  = MikCEH.ACTIONTYPE_RESIST,   -- SPELL_MISS_RESIST
 [3]  = MikCEH.ACTIONTYPE_DODGE,    -- SPELL_MISS_DODGE
 [4]  = MikCEH.ACTIONTYPE_PARRY,    -- SPELL_MISS_PARRY
 [5]  = MikCEH.ACTIONTYPE_BLOCK,    -- SPELL_MISS_BLOCK
 [6]  = MikCEH.ACTIONTYPE_EVADE,    -- SPELL_MISS_EVADE
 [7]  = MikCEH.ACTIONTYPE_IMMUNE,   -- SPELL_MISS_IMMUNE
 [8]  = MikCEH.ACTIONTYPE_IMMUNE,   -- SPELL_MISS_IMMUNE2
 -- [9] = SPELL_MISS_DEFLECT (no equivalent)
 [10] = MikCEH.ACTIONTYPE_ABSORB,   -- SPELL_MISS_ABSORB
 [11] = MikCEH.ACTIONTYPE_REFLECT,  -- SPELL_MISS_REFLECT
}

-- Nampower victimState to MikCEH action type mapping (for auto attacks).
local nampowerVictimStateToAction = {
 [0] = MikCEH.ACTIONTYPE_MISS,    -- VICTIMSTATE_UNAFFECTED (seen with HITINFO_MISS)
 [1] = MikCEH.ACTIONTYPE_HIT,     -- VICTIMSTATE_NORMAL
 [2] = MikCEH.ACTIONTYPE_DODGE,   -- VICTIMSTATE_DODGE
 [3] = MikCEH.ACTIONTYPE_PARRY,   -- VICTIMSTATE_PARRY
 [4] = MikCEH.ACTIONTYPE_HIT,     -- VICTIMSTATE_INTERRUPT (treat as hit)
 [5] = MikCEH.ACTIONTYPE_BLOCK,   -- VICTIMSTATE_BLOCKS
 [6] = MikCEH.ACTIONTYPE_EVADE,   -- VICTIMSTATE_EVADES
 [7] = MikCEH.ACTIONTYPE_IMMUNE,  -- VICTIMSTATE_IS_IMMUNE
 [8] = MikCEH.ACTIONTYPE_HIT,     -- VICTIMSTATE_DEFLECTS (treat as hit)
}

-- HitInfo bitmask constants.
local HITINFO_MISS        = 16
local HITINFO_CRITICALHIT = 128
local HITINFO_GLANCING    = 16384
local HITINFO_CRUSHING    = 32768

-- Nampower power type to localized string mapping.
local nampowerPowerTypeToString = {
 [0] = MANA,
 [1] = RAGE,
 [3] = ENERGY,
}


-- **********************************************************************************
-- Resolves a name from a GUID using Nampower APIs.
-- **********************************************************************************
local function GetNameFromGUID(guid)
 if not guid then return nil end
 if hasNampower and GetUnitField then
  local ok, name = pcall(GetUnitField, guid, "name")
  if ok and name then return name end
 end
 return nil
end


-- **********************************************************************************
-- Checks if the given GUID belongs to the player.
-- **********************************************************************************
local function IsPlayerGUID(guid)
 return playerGUID and guid == playerGUID
end


-- **********************************************************************************
-- Checks if the given GUID belongs to the player's pet.
-- **********************************************************************************
local function IsPetGUID(guid)
 if not guid or not UnitExists("pet") then return false end
 if hasNampower and UnitGUID then
  local ok, petGuid = pcall(UnitGUID, "pet")
  if ok and petGuid then return guid == petGuid end
 end
 return false
end


-- **********************************************************************************
-- Converts a Nampower spell school index to a MikCEH damage type.
-- **********************************************************************************
local function SchoolToDamageType(school)
 if not school then return MikCEH.DAMAGETYPE_PHYSICAL end
 return nampowerSchoolToType[school] or MikCEH.DAMAGETYPE_PHYSICAL
end


-- **********************************************************************************
-- Gets a spell name from a spellId via ClassicAPI (C_Spell), with caching.
-- **********************************************************************************
local function GetSpellNameFromId(spellId)
 if not spellId or spellId == 0 then return nil end
 if spellNameCache[spellId] then return spellNameCache[spellId] end

 local name = C_Spell.GetSpellName(spellId)

 if name then spellNameCache[spellId] = name end
 return name
end


-- **********************************************************************************
-- Parses Nampower mitigation string ("absorb,block,resist") into partial actions.
-- **********************************************************************************
local function ParseNampowerMitigation(mitigationStr, eventData)
 if not mitigationStr or mitigationStr == "" then return end
 -- Format: "absorbAmount,blockAmount,resistAmount"
 local _, _, a, b, r = string_find(mitigationStr, "^([^,]*),([^,]*),([^,]*)$")
 local absorb = tonumber(a)
 local block = tonumber(b)
 local resist = tonumber(r)

 -- Set the first non-zero mitigation as the partial action.
 if absorb and absorb > 0 then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_ABSORB
  eventData.PartialAmount = absorb
 elseif block and block > 0 then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_BLOCK
  eventData.PartialAmount = block
 elseif resist and resist > 0 then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_RESIST
  eventData.PartialAmount = resist
 end
end


-- **********************************************************************************
-- Ensures playerGUID is set. Called lazily by Nampower event handlers since
-- UnitGUID may not be available during ADDON_LOADED for some users.
-- **********************************************************************************
local function EnsurePlayerGUID()
 if playerGUID then return true end
 if hasNampower and UnitGUID then
  local ok, guid = pcall(UnitGUID, "player")
  if ok and guid then playerGUID = guid; return true end
 end
 return false
end


-- **********************************************************************************
-- Nampower event dispatcher — called by the Nampower event frame's OnEvent.
-- **********************************************************************************
function MikCEH.OnNampowerEvent()
 EnsurePlayerGUID()
 local handler = nampowerHandlers[event]
 if handler then handler() end
end


-------------------------------------------------------------------------------------
-- Nampower Event Handlers.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- SPELL_DAMAGE_EVENT_SELF: Outgoing spell damage (player and pet).
-- Args: targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr
-- **********************************************************************************
nampowerHandlers["SPELL_DAMAGE_EVENT_SELF"] = function()
 local targetGuid, casterGuid = arg1, arg2
 local spellId = arg3
 local damage = arg4
 local mitigationStr = arg5
 local hitInfo = arg6
 local spellSchool = arg7
 local effectAuraStr = arg8

 -- Determine direction: player outgoing, or pet outgoing.
 -- Special case: if the player is both caster and target (e.g. Hellfire self-damage,
 -- spell reflects), route as incoming since the player is taking damage.
 local directionType
 if IsPlayerGUID(casterGuid) then
  if IsPlayerGUID(targetGuid) then
   directionType = MikCEH.DIRECTIONTYPE_PLAYER_INCOMING
  else
   directionType = MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING
  end
  nampowerSpellDamageActive = true
 elseif IsPetGUID(casterGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PET_OUTGOING
  nampowerPetSpellDamageActive = true
 else
  return -- Not from player or pet, ignore.
 end

 local spellName = GetSpellNameFromId(spellId)
 local damageType = SchoolToDamageType(spellSchool)
 local targetName = GetNameFromGUID(targetGuid)

 -- Check if this is a DoT (periodic aura effect).
 -- effectAuraStr format: "effect1,effect2,effect3,auraType"
 local isDoT = false
 if effectAuraStr then
  local _, _, auraTypeStr = string_find(effectAuraStr, "%d+,%d+,%d+,(%d+)")
  local auraType = tonumber(auraTypeStr)
  if auraType == 3 or auraType == 89 then isDoT = true end
 end

 local hitType
 if isDoT then
  hitType = MikCEH.HITTYPE_OVER_TIME
 elseif hitInfo and hitInfo ~= 0 then
  hitType = MikCEH.HITTYPE_CRIT
 else
  hitType = MikCEH.HITTYPE_NORMAL
 end

 local eventData = MikCEH.GetDamageEventData(directionType, MikCEH.ACTIONTYPE_HIT, hitType, damageType, damage, spellName, targetName)
 eventData.SpellId = spellId

 -- Parse mitigation string for partial actions.
 ParseNampowerMitigation(mitigationStr, eventData)

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- SPELL_DAMAGE_EVENT_OTHER: Incoming spell damage (to player or pet).
-- Args: targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr
-- **********************************************************************************
nampowerHandlers["SPELL_DAMAGE_EVENT_OTHER"] = function()
 local targetGuid, casterGuid = arg1, arg2
 local spellId = arg3
 local damage = arg4
 local mitigationStr = arg5
 local hitInfo = arg6
 local spellSchool = arg7
 local effectAuraStr = arg8

 -- Only process if target is player or pet.
 local directionType
 if IsPlayerGUID(targetGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PLAYER_INCOMING
 elseif IsPetGUID(targetGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PET_INCOMING
 else
  return
 end

 local spellName = GetSpellNameFromId(spellId)
 local damageType = SchoolToDamageType(spellSchool)
 local casterName = GetNameFromGUID(casterGuid)

 -- effectAuraStr format: "effect1,effect2,effect3,auraType"
 local isDoT = false
 if effectAuraStr then
  local _, _, auraTypeStr = string_find(effectAuraStr, "%d+,%d+,%d+,(%d+)")
  local auraType = tonumber(auraTypeStr)
  if auraType == 3 or auraType == 89 then isDoT = true end
 end

 local hitType
 if isDoT then
  hitType = MikCEH.HITTYPE_OVER_TIME
 elseif hitInfo and hitInfo ~= 0 then
  hitType = MikCEH.HITTYPE_CRIT
 else
  hitType = MikCEH.HITTYPE_NORMAL
 end

 local eventData = MikCEH.GetDamageEventData(directionType, MikCEH.ACTIONTYPE_HIT, hitType, damageType, damage, spellName, casterName)
 eventData.SpellId = spellId

 ParseNampowerMitigation(mitigationStr, eventData)

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- AUTO_ATTACK_SELF: Outgoing melee auto-attacks.
-- Args: attackerGuid, targetGuid, totalDamage, hitInfo, victimState, subDamageCount, blockedAmount, totalAbsorb, totalResist
-- **********************************************************************************
nampowerHandlers["AUTO_ATTACK_SELF"] = function()
 local casterGuid, targetGuid = arg1, arg2
 local damage = arg3
 local hitInfo = arg4
 local victimState = arg5
 -- arg6 = subDamageCount (not needed)
 local blockedDmg = arg7 or 0
 local absorbedDmg = arg8 or 0
 local resistedDmg = arg9 or 0

 local directionType
 if IsPlayerGUID(casterGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING
  nampowerAutoAttackActive = true
 elseif IsPetGUID(casterGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PET_OUTGOING
  nampowerPetAutoAttackActive = true
 else
  return
 end

 local targetName = GetNameFromGUID(targetGuid)
 local actionType = nampowerVictimStateToAction[victimState] or MikCEH.ACTIONTYPE_HIT

 -- If victimState indicates a full miss/dodge/parry/etc with no damage, send as miss event.
 if actionType ~= MikCEH.ACTIONTYPE_HIT then
  local eventData = MikCEH.GetDamageEventData(directionType, actionType, nil, nil, nil, nil, targetName)
  MikCEH.SendEvent(eventData)
  return
 end

 -- Determine hit type from hitInfo bitmask.
 local hitType = MikCEH.HITTYPE_NORMAL
 if hitInfo and bit and bit.band then
  if bit.band(hitInfo, HITINFO_CRITICALHIT) ~= 0 then
   hitType = MikCEH.HITTYPE_CRIT
  end
 end

 local eventData = MikCEH.GetDamageEventData(directionType, MikCEH.ACTIONTYPE_HIT, hitType, MikCEH.DAMAGETYPE_PHYSICAL, damage, nil, targetName)

 -- Set partial actions from hitInfo and mitigation values.
 if hitInfo and bit and bit.band then
  if bit.band(hitInfo, HITINFO_CRUSHING) ~= 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_CRUSHING
  elseif bit.band(hitInfo, HITINFO_GLANCING) ~= 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_GLANCING
  end
 end

 -- If no crushing/glancing, check mitigation values.
 if not eventData.PartialActionType then
  if absorbedDmg > 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_ABSORB
   eventData.PartialAmount = absorbedDmg
  elseif blockedDmg > 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_BLOCK
   eventData.PartialAmount = blockedDmg
  elseif resistedDmg > 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_RESIST
   eventData.PartialAmount = resistedDmg
  end
 end

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- AUTO_ATTACK_OTHER: Incoming melee auto-attacks (to player or pet).
-- Args: attackerGuid, targetGuid, totalDamage, hitInfo, victimState, subDamageCount, blockedAmount, totalAbsorb, totalResist
-- **********************************************************************************
nampowerHandlers["AUTO_ATTACK_OTHER"] = function()
 local casterGuid, targetGuid = arg1, arg2
 local damage = arg3
 local hitInfo = arg4
 local victimState = arg5
 -- arg6 = subDamageCount (not needed)
 local blockedDmg = arg7 or 0
 local absorbedDmg = arg8 or 0
 local resistedDmg = arg9 or 0

 local directionType
 if IsPlayerGUID(targetGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PLAYER_INCOMING
  nampowerAutoAttackActive = true
 elseif IsPetGUID(targetGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PET_INCOMING
 else
  return
 end

 local casterName = GetNameFromGUID(casterGuid)
 local actionType = nampowerVictimStateToAction[victimState] or MikCEH.ACTIONTYPE_HIT

 if actionType ~= MikCEH.ACTIONTYPE_HIT then
  local eventData = MikCEH.GetDamageEventData(directionType, actionType, nil, nil, nil, nil, casterName)
  MikCEH.SendEvent(eventData)
  return
 end

 local hitType = MikCEH.HITTYPE_NORMAL
 if hitInfo and bit and bit.band then
  if bit.band(hitInfo, HITINFO_CRITICALHIT) ~= 0 then
   hitType = MikCEH.HITTYPE_CRIT
  end
 end

 local eventData = MikCEH.GetDamageEventData(directionType, MikCEH.ACTIONTYPE_HIT, hitType, MikCEH.DAMAGETYPE_PHYSICAL, damage, nil, casterName)

 if hitInfo and bit and bit.band then
  if bit.band(hitInfo, HITINFO_CRUSHING) ~= 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_CRUSHING
  elseif bit.band(hitInfo, HITINFO_GLANCING) ~= 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_GLANCING
  end
 end

 if not eventData.PartialActionType then
  if absorbedDmg > 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_ABSORB
   eventData.PartialAmount = absorbedDmg
  elseif blockedDmg > 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_BLOCK
   eventData.PartialAmount = blockedDmg
  elseif resistedDmg > 0 then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_RESIST
   eventData.PartialAmount = resistedDmg
  end
 end

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- SPELL_HEAL_ON_SELF: Incoming heals (heals landing on the player).
-- Args: targetGuid, casterGuid, spellId, amount, critical, periodic
-- **********************************************************************************
nampowerHandlers["SPELL_HEAL_ON_SELF"] = function()
 local targetGuid, casterGuid = arg1, arg2
 local spellId = arg3
 local healAmount = arg4
 local isCrit = arg5
 local isHot = arg6

 -- Only for player.
 if not IsPlayerGUID(targetGuid) then return end

 -- Only disable CHAT_MSG fallback after we've confirmed playerGUID works.
 nampowerHealsActive = true

 local spellName = GetSpellNameFromId(spellId)
 local casterName = GetNameFromGUID(casterGuid)

 local healType
 if isHot and isHot ~= 0 then
  healType = MikCEH.HEALTYPE_OVER_TIME
 elseif isCrit and isCrit ~= 0 then
  healType = MikCEH.HEALTYPE_CRIT
 else
  healType = MikCEH.HEALTYPE_NORMAL
 end

 local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, healType, healAmount, spellName, casterName)
 eventData.SpellId = spellId

 -- Populate overheal data.
 eventData.Name = playerName
 MikCEH.PopulateOverhealData(eventData)
 eventData.Name = casterName
 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- SPELL_HEAL_BY_SELF: Outgoing heals (heals cast by the player).
-- Args: targetGuid, casterGuid, spellId, amount, critical, periodic
-- **********************************************************************************
nampowerHandlers["SPELL_HEAL_BY_SELF"] = function()
 local targetGuid, casterGuid = arg1, arg2
 local spellId = arg3
 local healAmount = arg4
 local isCrit = arg5
 local isHot = arg6

 -- Skip self-heals (handled by SPELL_HEAL_ON_SELF).
 -- When playerGUID is nil, we can't identify self-heals, so bail out
 -- and let the CHAT_MSG fallback handle it.
 if not playerGUID then return end
 if IsPlayerGUID(targetGuid) then return end

 -- Only disable CHAT_MSG fallback after we've confirmed playerGUID works.
 nampowerHealsActive = true

 local spellName = GetSpellNameFromId(spellId)
 local targetName = GetNameFromGUID(targetGuid)

 local healType
 if isHot and isHot ~= 0 then
  healType = MikCEH.HEALTYPE_OVER_TIME
 elseif isCrit and isCrit ~= 0 then
  healType = MikCEH.HEALTYPE_CRIT
 else
  healType = MikCEH.HEALTYPE_NORMAL
 end

 local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, healType, healAmount, spellName, targetName)
 eventData.SpellId = spellId

 -- Populate overheal data.
 MikCEH.PopulateOverhealData(eventData)

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- SPELL_ENERGIZE_ON_SELF: Power gains on the player (mana, rage, energy).
-- Args: targetGuid, casterGuid, spellId, powerType, amount, periodic
-- **********************************************************************************
nampowerHandlers["SPELL_ENERGIZE_ON_SELF"] = function()
 local spellId = arg3
 local powerType = arg4
 local amount = arg5

 local powerTypeStr = nampowerPowerTypeToString[powerType]
 if not powerTypeStr then return end

 -- Only disable CHAT_MSG fallback after we've confirmed this handler works.
 nampowerEnergizeActive = true

 local spellName = GetSpellNameFromId(spellId)

 local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_GAIN, amount, powerTypeStr, spellName)
 eventData.SpellId = spellId

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- SPELL_MISS_SELF: Outgoing spell misses (player's spell missed).
-- Args: casterGuid, targetGuid, spellId, missInfo
-- **********************************************************************************
nampowerHandlers["SPELL_MISS_SELF"] = function()
 local casterGuid, targetGuid = arg1, arg2
 local spellId = arg3
 local missInfo = arg4

 local directionType
 if IsPlayerGUID(casterGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING
  nampowerSpellDamageActive = true
 elseif IsPetGUID(casterGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PET_OUTGOING
  nampowerPetSpellDamageActive = true
 else
  return
 end

 local spellName = GetSpellNameFromId(spellId)
 local targetName = GetNameFromGUID(targetGuid)
 local actionType = nampowerMissToAction[missInfo] or MikCEH.ACTIONTYPE_MISS

 local eventData = MikCEH.GetDamageEventData(directionType, actionType, nil, nil, nil, spellName, targetName)
 eventData.SpellId = spellId

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- SPELL_MISS_OTHER: Incoming spell misses (enemy's spell missed the player).
-- Args: casterGuid, targetGuid, spellId, missInfo
-- **********************************************************************************
nampowerHandlers["SPELL_MISS_OTHER"] = function()
 local casterGuid, targetGuid = arg1, arg2
 local spellId = arg3
 local missInfo = arg4

 -- Only process if target is player or pet.
 local directionType
 if IsPlayerGUID(targetGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PLAYER_INCOMING
 elseif IsPetGUID(targetGuid) then
  directionType = MikCEH.DIRECTIONTYPE_PET_INCOMING
 else
  return
 end

 local spellName = GetSpellNameFromId(spellId)
 local casterName = GetNameFromGUID(casterGuid)
 local actionType = nampowerMissToAction[missInfo] or MikCEH.ACTIONTYPE_MISS

 local eventData = MikCEH.GetDamageEventData(directionType, actionType, nil, nil, nil, spellName, casterName)
 eventData.SpellId = spellId

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- BUFF_ADDED_SELF: Buff gained by the player.
-- Args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
-- **********************************************************************************
nampowerHandlers["BUFF_ADDED_SELF"] = function()
 local unitGuid = arg1
 local spellId = arg3
 local state = arg7

 -- Only for player.
 if not IsPlayerGUID(unitGuid) then return end

 nampowerBuffsActive = true

 -- Only notify for newly added buffs (state 0), not stack changes (state 2).
 if state ~= 0 then return end

 local spellName = GetSpellNameFromId(spellId)
 if not spellName then return end

 local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_BUFF, nil, spellName)
 eventData.SpellId = spellId

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- DEBUFF_ADDED_SELF: Debuff gained by the player.
-- Args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
-- **********************************************************************************
nampowerHandlers["DEBUFF_ADDED_SELF"] = function()
 local unitGuid = arg1
 local spellId = arg3
 local state = arg7

 -- Only for player.
 if not IsPlayerGUID(unitGuid) then return end

 nampowerBuffsActive = true

 -- Only notify for newly added debuffs (state 0), not stack changes (state 2).
 if state ~= 0 then return end

 local spellName = GetSpellNameFromId(spellId)
 if not spellName then return end

 local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_DEBUFF, nil, spellName)
 eventData.SpellId = spellId

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- BUFF_REMOVED_SELF: Buff faded from the player.
-- Args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
-- **********************************************************************************
nampowerHandlers["BUFF_REMOVED_SELF"] = function()
 local unitGuid = arg1
 local spellId = arg3

 -- Only for player.
 if not IsPlayerGUID(unitGuid) then return end

 local spellName = GetSpellNameFromId(spellId)
 if not spellName then return end

 local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_BUFF_FADE, nil, spellName)
 eventData.SpellId = spellId

 MikCEH.SendEvent(eventData)
end


-- **********************************************************************************
-- DEBUFF_REMOVED_SELF: Debuff faded from the player.
-- Args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
-- **********************************************************************************
nampowerHandlers["DEBUFF_REMOVED_SELF"] = function()
 local unitGuid = arg1
 local spellId = arg3

 -- Only for player.
 if not IsPlayerGUID(unitGuid) then return end

 local spellName = GetSpellNameFromId(spellId)
 if not spellName then return end

 local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_BUFF_FADE, nil, spellName)
 eventData.SpellId = spellId

 MikCEH.SendEvent(eventData)
end


-------------------------------------------------------------------------------------
-- Nampower Event Setup.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Sets up Nampower event listeners and removes redundant CHAT_MSG events.
-- Called from OnLoad when Nampower is detected.
-- **********************************************************************************
function MikCEH.SetupNampowerEvents()
 -- Enable Nampower CVars required for the events we depend on.
 -- These are disabled by default but we suppress CHAT_MSG events they replace.
 if SetCVar then
  SetCVar("NP_EnableAutoAttackEvents", "1")
  SetCVar("NP_EnableSpellHealEvents", "1")
  SetCVar("NP_EnableSpellEnergizeEvents", "1")
 end

 -- All Nampower event equivalents now use runtime detection flags
 -- (nampowerSpellDamageActive, nampowerAutoAttackActive, etc.) instead of
 -- permanently unregistering CHAT_MSG events. This ensures fallback to CHAT_MSG
 -- parsing if a Nampower event doesn't fire for certain targets (e.g. NPCs).
 -- Only CHAT_MSG_SPELL_AURA_GONE_SELF is safe to remove (covered by BUFF/DEBUFF_REMOVED_SELF).
 local nampowerCoveredEvents = {
  ["CHAT_MSG_SPELL_AURA_GONE_SELF"] = true,
 }

 -- Events to keep despite Nampower — these have partial or no Nampower equivalent.
 -- CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE: Keep for power gains (no Nampower equivalent for all gain types)
 -- CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS: Keep for power gains (buff parsing gated by nampowerBuffsActive)
 -- CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE: Keep for power losses (ParseForPowerLosses)
 -- CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE: Keep for power losses
 -- CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE: Keep for power losses
 -- CHAT_MSG_SPELL_PARTY_DAMAGE: Keep for power losses
 -- CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE: Keep for power losses
 -- CHAT_MSG_COMBAT_SELF_HITS: Keep for environmental damage only
 -- CHAT_MSG_SPELL_ITEM_ENCHANTMENTS, CHAT_MSG_COMBAT_HONOR_GAIN, etc.: No Nampower equivalent

 -- Filter out covered events from listenEvents.
 local filteredEvents = {}
 for _, eventName in listenEvents do
  if not nampowerCoveredEvents[eventName] then
   table_insert(filteredEvents, eventName)
  end
 end

 -- Replace listenEvents with filtered list.
 -- Clear and repopulate to maintain the same table reference.
 for i = table_getn(listenEvents), 1, -1 do
  listenEvents[i] = nil
 end
 table_setn(listenEvents, 0)
 for _, eventName in filteredEvents do
  table_insert(listenEvents, eventName)
 end

 -- Create the Nampower event frame and register for Nampower events.
 nampowerEventFrame = CreateFrame("Frame")
 nampowerEventFrame:SetScript("OnEvent", MikCEH.OnNampowerEvent)
 nampowerEventFrame:RegisterEvent("SPELL_DAMAGE_EVENT_SELF")
 nampowerEventFrame:RegisterEvent("SPELL_DAMAGE_EVENT_OTHER")
 nampowerEventFrame:RegisterEvent("AUTO_ATTACK_SELF")
 nampowerEventFrame:RegisterEvent("AUTO_ATTACK_OTHER")
 nampowerEventFrame:RegisterEvent("SPELL_HEAL_BY_SELF")
 nampowerEventFrame:RegisterEvent("SPELL_HEAL_ON_SELF")
 nampowerEventFrame:RegisterEvent("SPELL_ENERGIZE_ON_SELF")
 nampowerEventFrame:RegisterEvent("SPELL_MISS_SELF")
 nampowerEventFrame:RegisterEvent("SPELL_MISS_OTHER")
 nampowerEventFrame:RegisterEvent("BUFF_ADDED_SELF")
 nampowerEventFrame:RegisterEvent("BUFF_REMOVED_SELF")
 nampowerEventFrame:RegisterEvent("DEBUFF_ADDED_SELF")
 nampowerEventFrame:RegisterEvent("DEBUFF_REMOVED_SELF")
end


-------------------------------------------------------------------------------------
-- Combat Parse Functions.
-------------------------------------------------------------------------------------


-- **********************************************************************************
-- Parses the passed combat message for an incoming hit message.
-- **********************************************************************************
function MikCEH.ParseForIncomingHits(combatMessage)
 -- Look for a normal hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITOTHERSELF", {"%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITCRITOTHERSELF", {"%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a normal hit from an elemental.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITSCHOOLOTHERSELF", {"%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a crit from an elemental.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITCRITSCHOOLOTHERSELF", {"%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, capturedData.DamageType, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 
 -- Look for a normal hit on your pet
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITOTHEROTHER", {"%n", "%s", "%a"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 -- Look for a crit on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITCRITOTHEROTHER", {"%n", "%s", "%a"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for an incoming miss message.
-- **********************************************************************************
function MikCEH.ParseForIncomingMisses(combatMessage)
 -- Look for a normal miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "MISSEDOTHERSELF", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSDODGEOTHERSELF", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSPARRYOTHERSELF", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSBLOCKOTHERSELF", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for an absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSABSORBOTHERSELF", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSIMMUNEOTHERSELF", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 -- Look for a normal Pet miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "MISSEDOTHEROTHER", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a Pet dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSDODGEOTHEROTHER", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a Pet parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSPARRYOTHEROTHER", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a Pet block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSBLOCKOTHEROTHER", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for an Pet absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSABSORBOTHEROTHER", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for an Pet immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSIMMUNEOTHEROTHER", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

  -- Return the parse was NOT successful.
 return false; 
end


-- **********************************************************************************
-- Parses the passed combat message for an incoming spell hit/miss message.
-- **********************************************************************************
function MikCEH.ParseForIncomingSpellHitsAndMisses(combatMessage)
 -- Look for an ability hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGOTHERSELF", {"%n", "%s", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an ability crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITOTHERSELF", {"%n", "%s", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a spell hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGSCHOOLOTHERSELF", {"%n", "%s", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 
 -- Look for a spell crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITSCHOOLOTHERSELF", {"%n", "%s", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLMISSOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLDODGEDOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPARRIEDOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLBLOCKEDOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a resist.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLRESISTOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_RESIST, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLIMMUNEOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a reflect.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLREFLECTOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_REFLECT, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for an ability hit on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGOTHEROTHER", {"%n", "%s", "%c", "%a"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an ability crit on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITOTHEROTHER", {"%n", "%s", "%a"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a spell hit on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGSCHOOLOTHEROTHER", {"%n", "%s", "%c", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 
 -- Look for a spell crit on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITSCHOOLOTHEROTHER", {"%n", "%s", "%c", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a miss on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLMISSOTHEROTHER", {"%n", "%s", "%c"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a dodge on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLDODGEDOTHEROTHER", {"%c", "%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPARRIEDOTHEROTHER", {"%c", "%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLBLOCKEDOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a resist on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLRESISTOTHEROTHER", {"%n", "%s", "%c"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_RESIST, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an absorb on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBOTHEROTHER", {"%n", "%s", "%c"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an immune on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLIMMUNEOTHEROTHER", {"%n", "%s", "%c"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for incoming damage shield damage.
-- **********************************************************************************
function MikCEH.ParseForIncomingDamageShieldDamage(combatMessage)
 local capturedData = MikCEH.GetCapturedData(combatMessage, "DAMAGESHIELDOTHERSELF", {"%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for a resist.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLRESISTOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_RESIST, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for a miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLMISSOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLDODGEDOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPARRIEDOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLBLOCKEDOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLIMMUNEOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a reflect.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLREFLECTOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_REFLECT, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for incoming heal info.
-- **********************************************************************************
function MikCEH.ParseForIncomingSpellHeals(combatMessage)
 -- Look for a critical heal from another player / creature.
	 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDCRITOTHERSELF", {"%n", "%s", "%a"});

	 -- If a match was found.
	 if (capturedData ~= nil) then
	  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.HEALTYPE_CRIT, capturedData.Amount, capturedData.SpellName, capturedData.Name);

	  -- Get overheal info.
	  eventData.Name = playerName
	  MikCEH.PopulateOverhealData(eventData); --athenne add
	  eventData.Name = capturedData.Name
	  
	  -- Send the event.
	  MikCEH.SendEvent(eventData);

	  -- Return the parse was successful.
	  return true;
	 end

	 -- Look for a heal from another player / creature.
	 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDOTHERSELF", {"%n", "%s", "%a"});

	 -- If a match was found.
	 if (capturedData ~= nil) then
	  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.HEALTYPE_NORMAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

	  -- Get overheal info.
	  eventData.Name = playerName
	  MikCEH.PopulateOverhealData(eventData); --athenne add
	  eventData.Name = capturedData.Name
	  
	  -- Send the event.
	  MikCEH.SendEvent(eventData);

	  -- Return the parse was successful.
	  return true;
	 end


	 -- Look for a HoT from someone else.
	 local capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURAHEALOTHERSELF", {"%a", "%n", "%s"});

	 -- If a match was found.
	 if (capturedData ~= nil) then
	  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.HEALTYPE_OVER_TIME, capturedData.Amount, capturedData.SpellName, capturedData.Name);

	  -- Get overheal info.
	  eventData.Name = playerName
    if GetLocale() ~= "zhCN" then -- edge case for chinese client (unable to show overheal amount for hot casted on self by other)
	   MikCEH.PopulateOverhealData(eventData); -- athenne add
    end
	  eventData.Name = capturedData.Name
	  
	  -- Send the event.
	  MikCEH.SendEvent(eventData);

	  -- Return the parse was successful.
	  return true;
	 end
  
 -- Look for a HoT from yourself.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURAHEALSELFSELF", {"%a", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.HEALTYPE_OVER_TIME, capturedData.Amount, capturedData.SpellName, playerName);

  -- Get overheal info.
  MikCEH.PopulateOverhealData(eventData); --athenne add
  
  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 -- Look for a critical heal from another player / creature on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDCRITOTHEROTHER", {"%n", "%s", "%c", "%a"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.HEALTYPE_CRIT, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Get overheal info.
  eventData.Name = cachedPetName
  MikCEH.PopulateOverhealData(eventData); -- athenne add
  eventData.Name = capturedData.Name

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a heal from another player / creature on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDOTHEROTHER", {"%n", "%s", "%c", "%a"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.HEALTYPE_NORMAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Get overheal info.
  eventData.Name = cachedPetName
  MikCEH.PopulateOverhealData(eventData); -- athenne add
  eventData.Name = capturedData.Name

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a HoT from someone else on your pet.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURAHEALOTHEROTHER", {"%c", "%a", "%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil and cachedPetName and string_find(combatMessage, cachedPetName)) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PET_INCOMING, MikCEH.HEALTYPE_OVER_TIME, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Get overheal info.
  eventData.Name = cachedPetName
  if GetLocale() ~= "zhCN" then -- edge case for chinese client (unable to show overheal amount for hot casted on your pet by other)
    MikCEH.PopulateOverhealData(eventData); -- athenne add
  end
  eventData.Name = capturedData.Name
  
  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for incoming debuff info.
-- **********************************************************************************
function MikCEH.ParseForIncomingDebuffs(combatMessage)
 -- Look for a debuff.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "AURAADDEDSELFHARMFUL", {"%b"});
 
 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_DEBUFF, capturedData.Amount, capturedData.BuffName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 -- Look for damage from a debuff.
 if (GetLocale() == "frFR") then
	capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURADAMAGEOTHERSELF", {"%t", "%a", "%s", "%n"}); 
 else
	capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURADAMAGEOTHERSELF", {"%a", "%t", "%n", "%s"});
end

 -- If a match was found.
 if (capturedData ~= nil) then
	
	local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_OVER_TIME, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 
 
  -- Look for damage from a self debuff.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURADAMAGESELFSELF", {"%a", "%t", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_OVER_TIME, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 -- Look for absorbed damage from a self debuff.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBSELFSELF", {"%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for absorbed damage from a debuff.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBOTHERSELF", {"%n", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses for power gains.
-- **********************************************************************************
function MikCEH.ParseForPowerGains(combatMessage)
	local capturedData = nil

  -- Look for power gains from others.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "POWERGAINOTHERSELF", {"%p", "%a", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  -- Make sure it's mana, rage, or energy.
  if (capturedData.PowerType == MANA or capturedData.PowerType == RAGE or capturedData.PowerType == ENERGY) then 
   local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_GAIN, capturedData.Amount, capturedData.PowerType, capturedData.SpellName);

   -- Send the event.
   MikCEH.SendEvent(eventData);

   -- Return the parse was successful.
   return true;
  end
 end
	
  -- Look for self power gains.
if (GetLocale() == "frFR") then
	capturedData = MikCEH.GetCapturedData(combatMessage, "POWERGAINSELFSELF", {"%p", "%s", "%a"});
else
	capturedData = MikCEH.GetCapturedData(combatMessage, "POWERGAINSELFSELF", {"%a", "%p", "%s"});
end

 -- If a match was found.
 if (capturedData ~= nil) then
  -- Make sure it's mana, rage, or energy.
  if (capturedData.PowerType == MANA or capturedData.PowerType == RAGE or capturedData.PowerType == ENERGY) then 
   local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_GAIN, capturedData.Amount, capturedData.PowerType, capturedData.SpellName);

   -- Send the event.
   MikCEH.SendEvent(eventData);

   -- Return the parse was successful.
   return true;
  end
 end

 -- Look for power gains from draining others.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPOWERLEECHSELFOTHER", {"%s", "%a", "%p", "%n", "", "", ""});

 -- If a match was found.
 if (capturedData ~= nil) then
  -- Make sure it's mana, rage, or energy.
  if (capturedData.PowerType == MANA or capturedData.PowerType == RAGE or capturedData.PowerType == ENERGY) then 
   local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_GAIN, capturedData.Amount, capturedData.PowerType, capturedData.SpellName);

   -- Send the event.
   MikCEH.SendEvent(eventData);

   -- Return the parse was successful.
   return true;
  end
 end

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses for power losses.
-- **********************************************************************************
function MikCEH.ParseForPowerLosses(combatMessage)
 -- Look for a power leech.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPOWERLEECHOTHERSELF", {"%n", "%s", "%a", "%p", "", "", ""});

 -- If a match was found.
 if (capturedData ~= nil) then
   local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_LOSS, capturedData.Amount, capturedData.PowerType, capturedData.SpellName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a power drain.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPOWERDRAINOTHERSELF", {"%n", "%s", "%a", "%p"});

 -- If a match was found.
 if (capturedData ~= nil) then
   local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_LOSS, capturedData.Amount, capturedData.PowerType, capturedData.SpellName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for incoming buff and power gain info.
-- **********************************************************************************
function MikCEH.ParseForIncomingBuffs(combatMessage)
 -- Parse for power gains.
 if (MikCEH.ParseForPowerGains(combatMessage)) then
  -- Return the parse was successful.
  return true;
 end

 -- Look for a buff.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "AURAADDEDSELFHELPFUL", {"%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_BUFF, nil, capturedData.SpellName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for a self mana drain.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPOWERDRAINSELFSELF", {"%s", "%a", "%p"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_LOSS, capturedData.Amount, capturedData.PowerType, capturedData.SpellName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for environmental damage.
-- **********************************************************************************
function MikCEH.ParseForEnvironmentalDamage(combatMessage)
 -- Look for drowning damage.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSENVIRONMENTALDAMAGE_DROWNING_SELF", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_DROWNING, nil, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for falling damage.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSENVIRONMENTALDAMAGE_FALLING_SELF", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_FALLING, nil, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for fatigue damage.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSENVIRONMENTALDAMAGE_FATIGUE_SELF", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_FATIGUE, nil, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for fire damage.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSENVIRONMENTALDAMAGE_FIRE_SELF", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_FIRE, nil, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for lava damage.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSENVIRONMENTALDAMAGE_LAVA_SELF", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_LAVA, nil, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for slime damage.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSENVIRONMENTALDAMAGE_SLIME_SELF", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_SLIME, nil, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for outgoing hits.
-- **********************************************************************************
function MikCEH.ParseForOutgoingHits(combatMessage)
 -- Look for a normal hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITSELFOTHER", {"%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITCRITSELFOTHER", {"%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for outgoing hits.
-- **********************************************************************************
function MikCEL_ParseForOutgoingHits(combatMessage)
 -- Look for a normal hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITSELFOTHER", {"%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITCRITSELFOTHER", {"%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for an outgoing miss message.
-- **********************************************************************************
function MikCEH.ParseForOutgoingMisses(combatMessage)
 -- Look for a normal miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "MISSEDSELFOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSDODGESELFOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSPARRYSELFOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSBLOCKSELFOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSABSORBSELFOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSIMMUNESELFOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an evade.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSEVADESELFOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_EVADE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for outgoing spell/ability hits and misses.
-- **********************************************************************************
function MikCEH.ParseForOutgoingSpellHitsAndMisses(combatMessage)
 -- Look for an ability crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITSELFOTHER", {"%s", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an ability hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGSELFOTHER", {"%s", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a spell crit to yourself.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITSCHOOLSELFSELF", {"%s", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, playerName);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a spell hit to yourself.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGSCHOOLSELFSELF", {"%s", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, playerName);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for spell crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITSCHOOLSELFOTHER", {"%s", "%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a spell hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGSCHOOLSELFOTHER", {"%s", "%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLMISSSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLDODGEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPARRIEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLBLOCKEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a resist.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLRESISTSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_RESIST, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLIMMUNESELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a reflect.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLREFLECTSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_REFLECT, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an evade
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLEVADEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_EVADE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for outgoing damage shield damage.
-- **********************************************************************************
function MikCEH.ParseForOutgoingDamageShieldDamage(combatMessage)
 local capturedData = MikCEH.GetCapturedData(combatMessage, "DAMAGESHIELDSELFOTHER", {"%a", "%t", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData
  if capturedData.DamageType == 2 and capturedData.Amount == "20" then
	eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, "Aura de vindicte", capturedData.Name);
  else
	eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, nil, capturedData.Name);
  end
  
  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for a resist.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLRESISTSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_RESIST, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLIMMUNESELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for an evade
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLEVADEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_EVADE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
 -- Look for a miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLMISSSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLDODGEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPARRIEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLBLOCKEDSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 

 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for outgoing heal info.
-- **********************************************************************************
function MikCEH.ParseForOutgoingSpellHeals(combatMessage)
 -- Look for a critical heal to yourself.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDCRITSELFSELF", {"%s", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.HEALTYPE_CRIT, capturedData.Amount, capturedData.SpellName, playerName);

  -- Get overheal info.
  MikCEH.PopulateOverhealData(eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a heal to yourself.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDSELFSELF", {"%s", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_INCOMING, MikCEH.HEALTYPE_NORMAL, capturedData.Amount, capturedData.SpellName, playerName);

  -- Get overheal info.
  MikCEH.PopulateOverhealData(eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a critical heal to someone else.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDCRITSELFOTHER", {"%s", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.HEALTYPE_CRIT, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Get overheal info.
  MikCEH.PopulateOverhealData(eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a heal to someone else.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "HEALEDSELFOTHER", {"%s", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.HEALTYPE_NORMAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Get overheal info.
  MikCEH.PopulateOverhealData(eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for outgoing dispel/purge resists.
-- **********************************************************************************
function MikCEH.ParseForOutgoingDispelResists(combatMessage)
 -- Look for a resist.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLRESISTSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_RESIST, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 
 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for outgoing Heals over time.
-- **********************************************************************************
function MikCEH.ParseForOutgoingHoTs(combatMessage)
 -- Look for a HoT to someone else.

 local capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURAHEALSELFOTHER", {"%n", "%a", "%s"});
 
 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetHealEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.HEALTYPE_OVER_TIME, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Get overheal info.
  MikCEH.PopulateOverhealData(eventData); --athenne add
  
  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for outgoing DoTs.
-- **********************************************************************************
function MikCEH.ParseForOutgoingDoTs(combatMessage)
 -- Look for damage from a DoT.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "PERIODICAURADAMAGESELFOTHER", {"%n", "%a", "%t", "%s"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_OVER_TIME, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for absorbed damage from a DoT.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBSELFOTHER", {"%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PLAYER_OUTGOING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for outgoing pet hits.
-- **********************************************************************************
function MikCEH.ParseForOutgoingPetHits(combatMessage)
 -- Look for a normal pet hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITOTHEROTHER", {"%c", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a pet crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITCRITOTHEROTHER", {"%c", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for a pet elemental hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITSCHOOLOTHEROTHER", {"%c", "%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 
  -- Look for a pet elemental crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATHITCRITSCHOOLOTHEROTHER", {"%c", "%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, capturedData.DamageType, capturedData.Amount, nil, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);
  
  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for outgoing pet misses.
-- **********************************************************************************
function MikCEH.ParseForOutgoingPetMisses(combatMessage)
 -- Look for a normal miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "MISSEDOTHEROTHER", {"%c", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 

 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSDODGEOTHEROTHER", {"%c", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSPARRYOTHEROTHER", {"%c", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSBLOCKOTHEROTHER", {"%c", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSABSORBOTHEROTHER", {"%c", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSIMMUNEOTHEROTHER", {"%c", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an evade.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VSEVADEOTHEROTHER", {"%c", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_EVADE, nil, nil, nil, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for outgoing pet spell hits and misses.
-- **********************************************************************************
function MikCEH.ParseForOutgoingPetSpellHitsAndMisses(combatMessage)
 -- Look for an ability hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGOTHEROTHER", {"%c", "%s", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an ability crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITOTHEROTHER", {"%c", "%s", "%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, MikCEH.DAMAGETYPE_PHYSICAL, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a spell hit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGSCHOOLOTHEROTHER", {"%c", "%s", "%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_NORMAL, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for spell crit.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGCRITSCHOOLOTHEROTHER", {"%c", "%s", "%n", "%a", "%t"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_HIT, MikCEH.HITTYPE_CRIT, capturedData.DamageType, capturedData.Amount, capturedData.SpellName, capturedData.Name);

  -- Look for any partial actions and populate them into the event data.
  MikCEH.ParseForPartialActions(combatMessage, eventData);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a miss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLMISSOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_MISS, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a dodge.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLDODGEDOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_DODGE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a parry.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLPARRIEDOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_PARRY, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLBLOCKEDOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_BLOCK, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for a resist.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLRESISTOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_RESIST, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLLOGABSORBOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_ABSORB, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an immune.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLIMMUNEOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_IMMUNE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Look for an evade
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SPELLEVADEDOTHEROTHER", {"%c", "%s", "%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetDamageEventData(MikCEH.DIRECTIONTYPE_PET_OUTGOING, MikCEH.ACTIONTYPE_EVADE, nil, nil, nil, capturedData.SpellName, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for incoming item buff info.
-- **********************************************************************************
function MikCEH.ParseForIncomingItemBuffs(combatMessage)
 -- Look for an item buff from yourself.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "ITEMENCHANTMENTADDSELFSELF", {"%b"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_ITEM_BUFF, nil, capturedData.BuffName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end
 

 -- Look for an item buff from someone else.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "ITEMENCHANTMENTADDOTHERSELF", {"%n", "%b"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_ITEM_BUFF, nil, capturedData.BuffName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for buff fades.
-- **********************************************************************************
function MikCEH.ParseForBuffFades(combatMessage)
 -- Look for a buff fade due to wearing off.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "AURAREMOVEDSELF", {"%b"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_BUFF_FADE, nil, capturedData.BuffName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for honor gains.
-- **********************************************************************************
function MikCEH.ParseForHonorGains(combatMessage)
 -- Look for an estimated honor gain from a kill.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATLOG_HONORGAIN", {"%n", "", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_HONOR_GAIN, capturedData.Amount, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for awarded honor.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATLOG_HONORAWARD", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_HONOR_GAIN, capturedData.Amount, nil);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for reputation gains/losses.
-- **********************************************************************************
function MikCEH.ParseForReputationGainsAndLosses(combatMessage)
 -- Look for a rep increase.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "FACTION_STANDING_INCREASED", {"%f", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_REP_GAIN, capturedData.Amount, capturedData.FactionName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end

 -- Look for a rep loss.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "FACTION_STANDING_DECREASED", {"%f", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_REP_LOSS, capturedData.Amount, capturedData.FactionName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for skill gains.
-- **********************************************************************************
function MikCEH.ParseForSkillGains(combatMessage)
 -- Look for a skill gain.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SKILL_RANK_UP", {"%k", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_SKILL_GAIN, capturedData.Amount, capturedData.SkillName);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for experience gains.
-- **********************************************************************************
function MikCEH.ParseForExperienceGains(combatMessage)
 -- Look for an experience gain.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "COMBATLOG_XPGAIN_FIRSTPERSON", {"%n", "%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_EXPERIENCE_GAIN, capturedData.Amount, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parses the passed combat message for killing blows.
-- **********************************************************************************
function MikCEH.ParseForKillingBlows(combatMessage)
 -- Look for a killing blow.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "SELFKILLOTHER", {"%n"});

 -- If a match was found.
 if (capturedData ~= nil) then
  -- Hold the notification type.
  local notificationType = MikCEH.NOTIFICATIONTYPE_NPC_KILLING_BLOW;

  -- Check if the current target is the slain enemy and is a player, or the slain target is on the recently
  -- selected players list.
  if ((UnitExists("target") and (UnitName("target") == capturedData.Name) and UnitIsPlayer("target")) or
      (recentlySelectedPlayers[capturedData.Name] ~= nil)) then
   notificationType = MikCEH.NOTIFICATIONTYPE_PC_KILLING_BLOW;
  end

  -- Create the event.
  local eventData = MikCEH.GetNotificationEventData(notificationType, nil, capturedData.Name);

  -- Send the event.
  MikCEH.SendEvent(eventData);

  -- Return the parse was successful.
  return true;
 end


 -- Return the parse was NOT successful.
 return false;
end


-- **********************************************************************************
-- Parse the passed combat message for partial actions and populate the info
-- from any actions found into the passed event data.
-- **********************************************************************************
function MikCEH.ParseForPartialActions(combatMessage, eventData)
 -- Look for a partial absorb.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "ABSORB_TRAILER", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_ABSORB;
  eventData.PartialAmount = capturedData.Amount;

  -- Return that partial action information was found.
  return true;  
 end


 -- Look for a partial block.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "BLOCK_TRAILER", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_BLOCK;
  eventData.PartialAmount = capturedData.Amount;

  -- Return that partial effect information was found.
  return true;  
 end


 -- Look for a partial resist.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "RESIST_TRAILER", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_RESIST;
  eventData.PartialAmount = capturedData.Amount;

  -- Return that partial action information was found.
  return true;  
 end


 -- Look for a vulnerability bonus.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "VULNERABLE_TRAILER", {"%a"});

 -- If a match was found.
 if (capturedData ~= nil) then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_VULNERABLE;
  eventData.PartialAmount = capturedData.Amount;

  -- Return that partial action information was found.
  return true;  
 end


 -- Look for a crushing blow.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "CRUSHING_TRAILER", {});
 -- If a match was found.
 if (capturedData ~= nil) then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_CRUSHING;

  -- Return that partial action information was found.
  return true;  
 end


 -- Look for a glancing blow.
 local capturedData = MikCEH.GetCapturedData(combatMessage, "GLANCING_TRAILER", {});
 -- If a match was found.
 if (capturedData ~= nil) then
  eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_GLANCING;

  -- Return that partial action information was found.
  return true;  
 end


 -- Return that no partial action information was found.
 return false;
end


-------------------------------------------------------------------------------------
-- Utility functions.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Get a lua compatible search string and the argument order from a global string
-- provided by blizzard.
-- **********************************************************************************
function MikCEH.GetGlobalStringInfo(globalStringName)

 -- Check if the passed global string does not exist.
 local globalString = getglobal(globalStringName);
 if (globalString == nil) then
  return;
 end

 -- Check if the global string info doesn't already exist for the passed global string name.
 if (globalStringInfoArray[globalStringName] == nil) then
  local searchString = "";
  local currentChar;
  local formatCode;
  local argumentNumber = 0;
  local argumentOrder = {};

  -- Loop through all of the characters in the passed string.
  local stringLength = string_len(globalString);
  for index = 0, stringLength do
   -- Get the current character.
   currentChar = string_sub(globalString, index, index);

   -- Check if we aren't in a formatting code.
   if (formatCode == nil) then
    -- Check if the current character is the start of a formatting code.
    if (currentChar == "%") then
     formatCode = currentChar;
    else
     -- Check if the character is one of the magic characters and escape it.
     if (string_find(currentChar, "[%^%$%(%)%.%[%]%*%-%+%?]")) then
	searchString = searchString .. "%" .. currentChar;
     -- Normal character so just add it to the formatted string.
     else
	searchString = searchString .. currentChar;
     end
    end

   -- We are in a formatting code.
   else
    -- Add the current character to the format code.
    formatCode = formatCode .. currentChar;

    -- Check if the % character is being escaped.
    if (formatCode == "%%") then
     -- Add the % to the search string.
     searchString = searchString .. "%%";

     -- Clear the format code.
     formatCode = nil;

    -- Check if it's a digit, a period, or a $ and do nothing so we loop to the next character in the format code.
    elseif (string_find(currentChar, "[%$%.%d]")) then
     -- Do nothing.

    -- Check for one of the types that need a string.
    elseif (string_find(currentChar, "[cEefgGiouXxqs]")) then
     -- Replace the format code with lua capture string syntax.
     if GetLocale() == "zhCN" and globalStringName == "HEALEDSELFOTHER" then -- edge for outgoing heals on others case for zhCN client
      searchString = searchString .. "([^0-9.]+)"
     else
      searchString = searchString .. "(.+)";
     end

     -- Increment the argument number.
     argumentNumber = argumentNumber + 1;

     -- Check if there is an argument position specified.
     local _, _, argumentPosition = string_find(formatCode, "(%d+)%$");
     if (argumentPosition) then
      argumentOrder[argumentNumber] = tonumber(argumentPosition);
     else
      argumentOrder[argumentNumber] = argumentNumber;
     end

     -- Clear the format code.
     formatCode = nil;

    -- Check if it's the type that needs a number.
    elseif (currentChar == "d") then
     -- Replace the format code with lua capture digits syntax.
     searchString = searchString .. "(%d+)";

     -- Increment the argument number.
     argumentNumber = argumentNumber + 1;

     -- Check if there is an argument position specified.
     local _, _, argumentPosition = string_find(formatCode, "(%d+)%$");
     if (argumentPosition) then
      argumentOrder[argumentNumber] = tonumber(argumentPosition);
     else
      argumentOrder[argumentNumber] = argumentNumber;
     end

     -- Clear the format code.
     formatCode = nil;

    else
     -- Clear the format code.
     formatCode = nil;
    end
   end
  end

  -- Cache the global string info for later retrieval.
  globalStringInfoArray[globalStringName] = {Search=searchString, ArgumentOrder=argumentOrder};
 end

 -- Return the format info for the global string.
 return globalStringInfoArray[globalStringName];
end


-- **********************************************************************************
-- This function returns the captured data table with all the captured data in fields.
-- If the pattern wasn't found then nil is returned.
-- Capture order keys.
-- %a = amount
-- %b = name of a buff/debuff
-- %c = name of creature (pet)
-- %f = name of the faction
-- %k = name of the skill
-- %n = name of enemy/player
-- %p = power type (mana, rage, energy)
-- %s = name of the ability/spell
-- %t = damage type
-- **********************************************************************************
function MikCEH.GetCapturedData(combatMessage, globalStringName, captureOrder)
 -- Check if the passed global string does not exist.
 if (getglobal(globalStringName) == nil) then
  -- Print out a debug message.
  MikSBT.PrintDebug("Unable to find global string: " .. globalStringName, 1, 0, 0);
  return;
 end

 -- Format the global string into a lua compatible search string.
 local globalStringInfo = MikCEH.GetGlobalStringInfo(globalStringName);

 -- Whether or not the search pattern was found.
 local stringFound = false;

 -- Erase old captured data.
 MikCEH.EraseTable(orderedCaptureData);

 -- Get the unordered capture data.
 local tempCapturedData = MikCEH.GetUnorderedCaptureDataTable(string_gfind(combatMessage, globalStringInfo.Search)());

 -- If a match was found.
 if (table_getn(tempCapturedData) ~= 0) then
  -- Loop through all of the values in the passed capture order table.
  for argNum, substituteValue in captureOrder do
   local captureString = tempCapturedData[globalStringInfo.ArgumentOrder[argNum]];
   if (substituteValue == "%a") then
    orderedCaptureData.Amount = captureString;
   elseif (substituteValue == "%b") then
    orderedCaptureData.BuffName = captureString;
   elseif (substituteValue == "%c") then
    orderedCaptureData.PetName = captureString;
   elseif (substituteValue == "%f") then
    orderedCaptureData.FactionName = captureString;
   elseif (substituteValue == "%k") then
    orderedCaptureData.SkillName = captureString;
   elseif (substituteValue == "%n") then
    orderedCaptureData.Name = captureString;
   elseif (substituteValue == "%p") then
    orderedCaptureData.PowerType = captureString;
   elseif (substituteValue == "%s") then
    orderedCaptureData.SpellName = captureString;
   elseif (substituteValue == "%t") then
    orderedCaptureData.DamageType = MikCEH.GetDamageTypeNumber(captureString);
   end
  end

  -- Return the captured data.
  return orderedCaptureData;
 end

 -- Return nil value.
 return nil;
end


-- **********************************************************************************
-- This function populates the unordered capture data table with all of the
-- parameters passed.
-- **********************************************************************************
function MikCEH.GetUnorderedCaptureDataTable(c1, c2, c3, c4, c5, c6, c7, c8, c9)
 -- Assign directly by index instead of EraseTable + table_insert.
 unorderedCaptureData[1] = c1;
 unorderedCaptureData[2] = c2;
 unorderedCaptureData[3] = c3;
 unorderedCaptureData[4] = c4;
 unorderedCaptureData[5] = c5;
 unorderedCaptureData[6] = c6;
 unorderedCaptureData[7] = c7;
 unorderedCaptureData[8] = c8;
 unorderedCaptureData[9] = c9;

 -- Clear any leftover slots beyond 9.
 local i = 10;
 while unorderedCaptureData[i] do unorderedCaptureData[i] = nil; i = i + 1; end

 -- Return the populated unordered capture data table.
 return unorderedCaptureData;
end


-- **********************************************************************************
-- Gets the damage type number for the given string.
-- **********************************************************************************
function MikCEH.GetDamageTypeNumber(damageTypeString)
 -- Return the correct damage type number for the passed string.
 if (damageTypeString == SPELL_SCHOOL0_CAP) then
  return MikCEH.DAMAGETYPE_PHYSICAL;
 elseif (damageTypeString == SPELL_SCHOOL1_CAP) then
  return MikCEH.DAMAGETYPE_HOLY;
 elseif (damageTypeString == SPELL_SCHOOL2_CAP) then
  return MikCEH.DAMAGETYPE_FIRE;
 elseif (damageTypeString == SPELL_SCHOOL3_CAP) then
  return MikCEH.DAMAGETYPE_NATURE;
 elseif (damageTypeString == SPELL_SCHOOL4_CAP) then
  return MikCEH.DAMAGETYPE_FROST;
 elseif (damageTypeString == SPELL_SCHOOL5_CAP) then
  return MikCEH.DAMAGETYPE_SHADOW;
 elseif (damageTypeString == SPELL_SCHOOL6_CAP) then
  return MikCEH.DAMAGETYPE_ARCANE;
 elseif (damageTypeString == "Arcane") then
  return MikCEH.DAMAGETYPE_ARCANE;
 end

 -- Return the unknown damage type.
 return MikCEH.DAMAGETYPE_UNKNOWN;
end


-- **********************************************************************************
-- Get a string for the passed damage type.
-- **********************************************************************************
function MikCEH.GetDamageTypeString(damageType)
 -- Return the correct damage type string for the passed number.
 if (damageType == MikCEH.DAMAGETYPE_PHYSICAL) then
  return SPELL_SCHOOL0_CAP;
 elseif (damageType == MikCEH.DAMAGETYPE_HOLY) then
  return SPELL_SCHOOL1_CAP;
 elseif (damageType == MikCEH.DAMAGETYPE_FIRE) then
  return SPELL_SCHOOL2_CAP;
 elseif (damageType == MikCEH.DAMAGETYPE_NATURE) then
  return SPELL_SCHOOL3_CAP;
 elseif (damageType == MikCEH.DAMAGETYPE_FROST) then
  return SPELL_SCHOOL4_CAP;
 elseif (damageType == MikCEH.DAMAGETYPE_SHADOW) then
  return SPELL_SCHOOL5_CAP;
 elseif (damageType == MikCEH.DAMAGETYPE_ARCANE) then
  return SPELL_SCHOOL6_CAP;
 end

 -- Return the unknown damage type string.
 return UNKNOWN;
end


-- **********************************************************************************
-- Populates the combat event data table for a damage event with the passed info.
-- **********************************************************************************
function MikCEH.GetDamageEventData(directionType, actionType, hitType, damageType, amount, effectName, name)
 -- Get the global combat event data table.
 local eventData = MikCEH.CombatEventData;

 -- Erase the combat event data table.
 MikCEH.EraseTable(eventData);


 -- Populate the event data fields.
 eventData.EventType = MikCEH.EVENTTYPE_DAMAGE;
 eventData.DirectionType = directionType;
 eventData.ActionType = actionType;
 eventData.HitType = hitType;
 eventData.DamageType = damageType;
 eventData.Amount = amount;
 eventData.EffectName = effectName;
 eventData.Name = name;

 -- Return the event data.
 return eventData;
end


-- **********************************************************************************
-- Populates the combat event data table for a heal event with the passed info.
-- **********************************************************************************
function MikCEH.GetHealEventData(directionType, healType, amount, effectName, name)
 -- Get the global combat event data table.
 local eventData = MikCEH.CombatEventData;

 -- Erase the combat event data table.
 MikCEH.EraseTable(eventData);

  -- Populate the event data fields.
 eventData.EventType = MikCEH.EVENTTYPE_HEAL;
 eventData.DirectionType = directionType;
 eventData.HealType = healType;
 eventData.Amount = amount;
 eventData.EffectName = effectName;
 eventData.Name = name;

 -- Return the event data.
 return eventData;
end


-- **********************************************************************************
-- Populates the combat event data table for a notification event with the passed
-- info.
-- **********************************************************************************
function MikCEH.GetNotificationEventData(notificationType, amount, effectName, SpellName)
 -- Get the global combat event data table.
 local eventData = MikCEH.CombatEventData;

 -- Erase the combat event data table.
 MikCEH.EraseTable(eventData);

 -- Populate the event data fields.
 eventData.EventType = MikCEH.EVENTTYPE_NOTIFICATION;
 eventData.NotificationType = notificationType;
 eventData.Amount = amount;
 if effectName == MANA or effectName == RAGE or effectName == ENERGY then
	eventData.Amount = amount.." "..effectName;
	eventData.EffectName = SpellName;	
 else
	eventData.EffectName = effectName;
 end

 -- Return the event data.
 return eventData;
end


-- **********************************************************************************
-- Gets a unit id for the name.
-- **********************************************************************************
function MikCEH.GetUnitIDFromName(uName)
 local unitID, unitName;

 -- Fast path when raw combat logging is enabled: O(1) unit lookup by name.
 if LoggingCombat and LoggingCombat("RAW") == 1 then
  local _, exist, uid = pcall(UnitExists, uName)
  if _ and exist then
   unitName = UnitName(uid)
   return uid, unitName
  end
 end

 -- Check if the name is the player.
 if (uName == playerName) then
  unitID = "player";

 -- Check if the name is the pet.
 elseif (uName == UnitName("pet")) then
 unitID = "pet";
 
 -- Check if the name is one of the player's raid or party members (cached).
 else
  if nameToUnitIDCacheDirty then RebuildNameToUnitIDCache() end
  unitID = nameToUnitIDCache[uName]
 end
 if unitID then
  unitName = UnitName(unitID)
  -- Return the unit id.
   return unitID, unitName
 else
    return nil, nil
 end
end


-- **********************************************************************************
-- Populates the passed event data with overheal info.
-- **********************************************************************************
function MikCEH.PopulateOverhealData(eventData)
 -- Get the appropriate unit id for the unit being checked for overheals.

 local unitID, uName = MikCEH.GetUnitIDFromName(eventData.Name);
 
 if not unitID then
	if UnitName("target") == eventData.Name then
		unitID = "target";
	end
 end

 -- Make sure it's a valid unit id. 
 if (unitID) then
  local healthMissing = UnitHealthMax(unitID) - UnitHealth(unitID);
  local overhealAmount = eventData.Amount - healthMissing;

  -- Check if any overhealing occured （note threshold is 100 because heals on non-group members
  -- will show show max health 100 instead of the proper maximum health of the target)
  if (overhealAmount > 0 and UnitHealthMax(unitID) ~= 100) then
   eventData.PartialActionType = MikCEH.PARTIALACTIONTYPE_OVERHEAL;
   eventData.PartialAmount = overhealAmount;
  end
 end
end


-- **********************************************************************************
-- Sends the event to MSBT's combat events handler function.
-- **********************************************************************************
function MikCEH.SendEvent(eventData)
 -- Make sure MSBT's combat events handler function is defined.
 if (MikSBT.CombatEventsHandler ~= nil) then
  MikSBT.CombatEventsHandler(eventData);
 end
end


-- **********************************************************************************
-- Erases the passed table without losing the reference to the original memory.
-- This helps prevent GC churn.
-- **********************************************************************************
function MikCEH.EraseTable(t)
 -- Loop through all the keys in the table and clear it.
 for key in pairs(t) do
  t[key] = nil;
 end

 -- Set the length of the table to 0.
 table_setn(t, 0);
end


-------------------------------------------------------------------------------------
-- Trigger utility functions.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Enables event searching mode.  The passed pattern will be used to only show event
-- types where the combat message contains the pattern.
-- **********************************************************************************
function MikCEH.EnableEventSearching(pattern)
 -- Enable the event searching mode flag and set the search pattern
 -- to the passed pattern.
 searchMode = true;
 searchModePattern = pattern;
end


-- **********************************************************************************
-- Disables event searching mode.
-- **********************************************************************************
function MikCEH.DisableEventSearching()
 -- Clear the event searching mode flag and search pattern.
 searchMode = false;
 searchModePattern = nil;
end


-- **********************************************************************************
-- Sends the trigger to MSBT's trigger events handler function.
-- **********************************************************************************
function MikCEH.SendTriggerEvent(eventData)
 -- Make sure MSBT's trigger handler function is defined.
 if (MikSBT.TriggerHandler ~= nil) then
  MikSBT.TriggerHandler(eventData);
 end
end


-- **********************************************************************************
-- Populates the trigger event data table using the passed info
-- **********************************************************************************
function MikCEH.GetSearchTriggerEventData(triggerKey, capturedData)
 -- Get the common trigger event data table.
 local eventData = MikCEH.TriggerEventData;

 -- Erase the trigger event data table.
 MikCEH.EraseTable(eventData);

 -- Populate the trigger event data fields.
 eventData.TriggerKey = triggerKey;
 eventData.NumCaptures = table_getn(capturedData);

 -- Loop through each captured data entry and set a corresponding field in
 -- the trigger event.
 for i = 1, eventData.NumCaptures do
  eventData["CapturedData" .. i] = capturedData[i];
 end

 -- Return the event data.
 return eventData;
end


-- **********************************************************************************
-- Populates the trigger event data table using the passed info
-- **********************************************************************************
function MikCEH.GetThresholdTriggerEventData(triggerKey, triggerAmount)
 -- Get the common trigger event data table.
 local eventData = MikCEH.TriggerEventData;

 -- Erase the trigger event data table.
 MikCEH.EraseTable(eventData);

 -- Populate the trigger event data fields.
 eventData.TriggerKey = triggerKey;
 eventData.NumCaptures = 1;
 eventData.CapturedData1 = triggerAmount;

 -- Return the event data.
 return eventData;
end


-------------------------------------------------------------------------------------
-- Trigger functions.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Registers the passed trigger key with the passed trigger settings.
-- **********************************************************************************
function MikCEH.RegisterTrigger(triggerKey, triggerSettings)
 -- Check if the trigger is for the player's class.
 if (not triggerSettings.Classes or triggerSettings.Classes[playerClass]) then
  -- Add to various arrays of triggers to check.  This is done so time is not wasted on
  -- checking for triggers that don't apply.

  -- Self Health.
  if (triggerSettings.TriggerType == MikCEH.TRIGGERTYPE_SELF_HEALTH) then
   selfHealthTriggers[triggerKey] = triggerSettings;

  -- Self Mana.
  elseif (triggerSettings.TriggerType == MikCEH.TRIGGERTYPE_SELF_MANA) then
   selfManaTriggers[triggerKey] = triggerSettings;

  -- Pet Health.
  elseif (triggerSettings.TriggerType == MikCEH.TRIGGERTYPE_PET_HEALTH) then
   petHealthTriggers[triggerKey] = triggerSettings;

  -- Enemy Health.
  elseif (triggerSettings.TriggerType == MikCEH.TRIGGERTYPE_ENEMY_HEALTH) then
   enemyHealthTriggers[triggerKey] = triggerSettings;

  -- Friendly Health.
  elseif (triggerSettings.TriggerType == MikCEH.TRIGGERTYPE_FRIENDLY_HEALTH) then
   friendlyHealthTriggers[triggerKey] = triggerSettings;

  -- Search Pattern.
  elseif (triggerSettings.TriggerType == MikCEH.TRIGGERTYPE_SEARCH_PATTERN) then
   -- Loop through all of the trigger events.
   for _, triggerEvent in triggerSettings.TriggerEvents do
    -- Check if there is not already a table for the trigger event and create one.
    if (not searchPatternTriggers[triggerEvent]) then
     searchPatternTriggers[triggerEvent] = {};
    end

    -- Add the trigger to the search pattern array for the event.
    searchPatternTriggers[triggerEvent][triggerKey] = triggerSettings;
   end
  end

 end   -- Is trigger for class?
end


-- **********************************************************************************
-- Unregisters all of the triggers.
-- **********************************************************************************
function MikCEH.UnregisterAllTriggers()
 -- Erase the trigger arrays.
 MikCEH.EraseTable(selfHealthTriggers);
 MikCEH.EraseTable(selfManaTriggers);
 MikCEH.EraseTable(petHealthTriggers);
 MikCEH.EraseTable(enemyHealthTriggers);
 MikCEH.EraseTable(friendlyHealthTriggers);
 MikCEH.EraseTable(searchPatternTriggers);
end


-- **********************************************************************************
-- Parses the self health triggers.
-- **********************************************************************************
function MikCEH.ParseSelfHealthTriggers()
 local healthAmount = UnitHealth("player");
 local healthPercentage = healthAmount / UnitHealthMax("player");

 -- Loop through self health triggers.
 for triggerKey, triggerSettings in selfHealthTriggers do
  -- Check if we just crossed the trigger's threshold.
  if (healthPercentage < triggerSettings.Threshold/100 and lastSelfHealthPercentage >= triggerSettings.Threshold/100) then
   -- Get trigger event data and call the trigger handler.
   local eventData = MikCEH.GetThresholdTriggerEventData(triggerKey, healthAmount);
   MikCEH.SendTriggerEvent(eventData);
   if MikSBT.CurrentProfile.LowHealthSound then
	PlaySoundFile("Interface\\AddOns\\MikScrollingBattleText\\sounds\\LowHealth.mp3");
   end
  end
 end

 -- Update the last health percentage.
 lastSelfHealthPercentage = healthPercentage;
end


-- **********************************************************************************
-- Parses the self mana triggers.
-- **********************************************************************************
function MikCEH.ParseSelfManaTriggers()
 -- Make sure we're dealing with mana.
 if (UnitPowerType("player") == 0) then
  local manaAmount = UnitMana("player");
  local manaPercentage = manaAmount / UnitManaMax("player");
  
  -- Mana per Five Ticks
  local manaDiff = manaAmount - lastSelfManaAmount;
	if ( manaDiff > 0 and MikSBT.CurrentProfile.ShowAllManaGains) then
		local eventData = MikCEH.GetNotificationEventData(MikCEH.NOTIFICATIONTYPE_POWER_GAIN, manaDiff.." "..MANA, 0);
		MikCEH.SendEvent(eventData);
	end
  
  -- Loop through self mana triggers.
  for triggerKey, triggerSettings in selfManaTriggers do
   -- Check if we just crossed the trigger's threshold.
   if (manaPercentage < triggerSettings.Threshold/100 and lastSelfManaPercentage >= triggerSettings.Threshold/100) then
    -- Get trigger event data and call the trigger handler.
    local eventData = MikCEH.GetThresholdTriggerEventData(triggerKey, manaAmount);
    MikCEH.SendTriggerEvent(eventData);
	if MikSBT.CurrentProfile.LowManaSound then
	   PlaySoundFile("Interface\\AddOns\\MikScrollingBattleText\\sounds\\LowMana.mp3");
	end
   end
  end

  -- Update the last mana percentage.
  lastSelfManaPercentage = manaPercentage;
  lastSelfManaAmount = manaAmount;
 end
end


-- **********************************************************************************
-- Parses the pet health triggers.
-- **********************************************************************************
function MikCEH.ParsePetHealthTriggers()
 local healthAmount = UnitHealth("pet");
 local maxHealth = UnitHealthMax("pet");
 if (not maxHealth or maxHealth == 0) then return end
 local healthPercentage = healthAmount / maxHealth;

 -- Loop through pet health triggers.
 for triggerKey, triggerSettings in petHealthTriggers do
  -- Check if we just crossed the trigger's threshold.
  if (healthPercentage < triggerSettings.Threshold/100 and lastPetHealthPercentage >= triggerSettings.Threshold/100) then
   -- Get trigger event data and call the trigger handler.
   local eventData = MikCEH.GetThresholdTriggerEventData(triggerKey, healthAmount);
   MikCEH.SendTriggerEvent(eventData)
  end
 end

 -- Update the last health percentage.
 lastPetHealthPercentage = healthPercentage;
end


-- **********************************************************************************
-- Parses the enemy health triggers.
-- **********************************************************************************
function MikCEH.ParseEnemyHealthTriggers()
 local healthAmount = UnitHealth("target");
 local maxHealth = UnitHealthMax("target");
 if (not maxHealth or maxHealth == 0) then return end
 local healthPercentage = healthAmount / maxHealth;

 -- Loop through self health triggers.
 for triggerKey, triggerSettings in enemyHealthTriggers do
  -- Check if we just crossed the trigger's threshold.
  if (healthPercentage < triggerSettings.Threshold/100 and lastEnemyHealthPercentage >= triggerSettings.Threshold/100) then
   -- Get trigger event data and call the trigger handler.
   local eventData = MikCEH.GetThresholdTriggerEventData(triggerKey, healthAmount);
   MikCEH.SendTriggerEvent(eventData)
  end
 end

 -- Update the last health percentage.
 lastEnemyHealthPercentage = healthPercentage;
end


-- **********************************************************************************
-- Parses the friendly health triggers.
-- **********************************************************************************
function MikCEH.ParseFriendlyHealthTriggers()
 local healthAmount = UnitHealth("target");
 local maxHealth = UnitHealthMax("target");
 if (not maxHealth or maxHealth == 0) then return end
 local healthPercentage = healthAmount / maxHealth;

 -- Loop through self health triggers.
 for triggerKey, triggerSettings in friendlyHealthTriggers do
  -- Check if we just crossed the trigger's threshold.
  if (healthPercentage < triggerSettings.Threshold/100 and lastFriendlyHealthPercentage >= triggerSettings.Threshold/100) then
   -- Get trigger event data and call the trigger handler.
   local eventData = MikCEH.GetThresholdTriggerEventData(triggerKey, healthAmount);
   MikCEH.SendTriggerEvent(eventData)
  end
 end

 -- Update the last health percentage.
 lastFriendlyHealthPercentage = healthPercentage;
end



-- **********************************************************************************
-- Parses the search pattern triggers for a match with the passed combat message
-- and event.
-- **********************************************************************************
function MikCEH.ParseSearchPatternTriggers(event, combatMessage)
 -- Check if event search mode is enabled.
 if (searchMode) then
  -- Check if the pattern is in the combat message.
  if (string_find(combatMessage, searchModePattern)) then
   -- Print out the event type and the combat message.
   MikSBT.Print(event .. " - " .. combatMessage, 0, 1, 0);
  end
 end

 -- Check if there are no triggers for the event type and bail.
 if (not searchPatternTriggers[event]) then
  return;
 end

 -- Loop through all triggers for the event.
 for triggerKey, triggerSettings in searchPatternTriggers[event] do
  -- Loop through all of the search patterns for the trigger.
  for _, searchPattern in triggerSettings.SearchPatterns do

   -- Check if the search pattern is a global string.
   if (getglobal(searchPattern) ~= nil) then
    -- Format the global string into a lua compatible search string.
    local globalStringInfo = MikCEH.GetGlobalStringInfo(searchPattern);

    -- Replace the search pattern with the lua compatible search string.
    searchPattern = globalStringInfo.Search;
   end

   -- Get capture data.
   local capturedData = MikCEH.GetUnorderedCaptureDataTable(string_gfind(combatMessage, searchPattern)());

   -- Check if a match was found. 
   if (table_getn(capturedData) ~= 0) then
    -- Get trigger event data and call the trigger handler.
    local eventData = MikCEH.GetSearchTriggerEventData(triggerKey, capturedData);
    MikCEH.SendTriggerEvent(eventData);
    break;
   end
  end -- Loop through search patterns. 
 end -- Loop through triggers.
end
