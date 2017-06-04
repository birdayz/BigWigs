------------------------------
--      Are you local?      --
------------------------------

local eyeofcthun = AceLibrary("Babble-Boss-2.2")["Eye of C'Thun"]
local cthun = AceLibrary("Babble-Boss-2.2")["C'Thun"]
local L = AceLibrary("AceLocale-2.2"):new("BigWigs" .. cthun)

local gianteye = "Giant Eye Tentacle"

local timeP1Tentacle = 45      -- tentacle timers for phase 1
local timeP1TentacleStart = 45 -- delay for first tentacles from engage onwards

local timeP1GreenBeam = 45+3         -- 45s + 3sec dark glare cast
local timeP1GlareDuration = 38+1	 -- 38s+1s cd

local timeP2Offset = 4        -- delay for all timers to restart after the Eye dies
local timeP2Tentacle = 30      -- tentacle timers for phase 2
local timeP2ETentacle = 60     -- Eye tentacle timers for phase 2
local timeP2CTentacle = 60     -- Eye tentacle timers for phase 2
local timeReschedule = 50      -- delay from the moment of weakening for timers to restart
local timeTarget = 10          -- delay for target change checking on Eye of C'Thun
local timeWeakened = 45        -- duration of a weaken

local cthunstarted = nil
local phase2started = nil
local firstWarning = nil
local target = nil
local tentacletime = timeP1Tentacle
local targetCheckDelay = 0.2


----------------------------
--      Localization      --
----------------------------


L:RegisterTranslations("enUS", function() return {
  cmd = "Cthun",

  tentacle_cmd = "tentacle",
  tentacle_name = "Tentacle Alert",
  tentacle_desc = "Warn for Tentacles",

  glare_cmd = "glare",
  glare_name = "Dark Glare Alert",
  glare_desc = "Warn for Dark Glare",

  group_cmd = "group",
  group_name = "Dark Glare Group Warning",
  group_desc = "Warn for Dark Glare on Group X",

  giant_cmd = "giant",
  giant_name = "Giant Eye Alert",
  giant_desc = "Warn for Giant Eyes",

  weakened_cmd = "weakened",
  weakened_name = "Weakened Alert",
  weakened_desc = "Warn for Weakened State",

  rape_cmd = "rape",
  rape_name = "Rape jokes are funny",
  rape_desc = "Some people like hentai jokes.",

  weakenedtrigger = "is weakened!",
  tentacle	= "Tentacle Rape Party - 5 sec",

  norape		= "Tentacles in 5sec!",

  testbar		= "time",
  say		= "say",

  weakened	= "C'Thun is weakened for 45 sec",
  invulnerable2	= "Party ends in 5 seconds",
  invulnerable1	= "Party over - C'Thun invulnerable",

  GNPPtrigger	= "Nature Protection",
  GSPPtrigger	= "Shadow Protection",
  Sundertrigger	= "Sunder Armor",
  CoEtrigger	= "Curse of the Elements",
  CoStrigger	= "Curse of Shadow",
  CoRtrigger	= "Curse of Recklessness",

  startwarn	= "C'Thun engaged! - 45 sec until Dark Glare and Eyes",

  glare		= "Dark glare!",

  bar_tentacle_rape	= "Tentacle rape party!",
  barWeakened	= "C'Thun is weakened!",
  barGlare	= "Dark glare!",
  bar_giant_eye	= "Giant Eye!",
  bar_giant_claw	= "Giant Claw!",
  barGreenBeam	= "Eye tentacle spawn!",
  gedownwarn	= "Giant Eye down!",
  eye_cast_bar_on = "Eye Beam: %s",

  barNextGlare = "Next Dark Glare",
  barGlare = "Dark Glare",

  darkglare_soon_message = "Dark Glare in 5 seconds!",

  eyebeam_cast = "Eye of C'Thun begins to cast Eye Beam",

  eyebeam		= "Eye Beam",
  next_eyebeam = "Next Eye Beam",
  glarewarning	= "DARK GLARE ON YOU!",
  groupwarning	= "Dark Glare on group %s (%s)",
  positions2	= "Dark Glare ends in 5 sec",
  phase2starting	= "The Eye is dead! Body incoming!",
} end )

----------------------------------
--      Module Declaration      --
----------------------------------

BigWigsCThun = BigWigs:NewModule(cthun)
BigWigsCThun.zonename = AceLibrary("Babble-Zone-2.2")["Ahn'Qiraj"]
BigWigsCThun.enabletrigger = { eyeofcthun, cthun }
BigWigsCThun.bossSync = "CThun"
BigWigsCThun.toggleoptions = { "rape", -1, "tentacle", "glare", "group", -1, "giant", "weakened", "bosskill" }
BigWigsCThun.revision = tonumber(string.sub("$Revision: 15989 $", 12, -3))

function BigWigsCThun:OnEnable()
  self.started = nil
  self.tentaclesKilled = 0
  target = nil
  cthunstarted = nil
  firstWarning = nil
  phase2started = nil

  tentacletime = timeP1Tentacle

  -- register events
  --self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
  --self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
  --self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
  --self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
  self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
  self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
  self:RegisterEvent("CHAT_MSG_MONSTER_EMOTE", "Emote")		-- weakened triggering
  self:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE", "Emote")		-- weakened triggering
  self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE") -- engage of Eye of C'Thun
  --TODOself:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE") -- engage of Eye of C'Thun
  -- Not sure about this, since we get out of combat between the phases.
  -- self:RegisterEvent("PLAYER_REGEN_ENABLED", "CheckForWipe")

  self:RegisterEvent("BigWigs_RecvSync")

  self:TriggerEvent("BigWigs_ThrottleSync", "CThunStart", 20)
  self:TriggerEvent("BigWigs_ThrottleSync", "CThunP2StartDS", 20)
  self:TriggerEvent("BigWigs_ThrottleSync", "CThunWeakenedDS", 20)
  self:TriggerEvent("BigWigs_ThrottleSync", "CThunGEdownDS", 3)
end

----------------------
--  Event Handlers  --
----------------------

function BigWigsCThun:Emote( msg )
  if string.find(msg, L["weakenedtrigger"]) then self:TriggerEvent("BigWigs_SendSync", "CThunWeakenedDS") end
end

function BigWigsCThun:CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE( arg1 )

end

function BigWigsCThun:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  if ((msg == string.format(UNITDIESOTHER, eyeofcthun))) then
    self:TriggerEvent("BigWigs_SendSync", "CThunP2StartDS")
  elseif (msg == string.format(UNITDIESOTHER, gianteye)) then
    self:TriggerEvent("BigWigs_SendSync", "CThunGEdownDS")
  elseif (msg == string.format(UNITDIESOTHER, cthun)) then
    if self.db.profile.bosskill then self:TriggerEvent("BigWigs_Message", string.format(AceLibrary("AceLocale-2.2"):new("BigWigs")["%s has been defeated"], cthun), "Bosskill", nil, "Victory") end
    self.core:ToggleModuleActive(self, false)
  elseif (msg == string.format(UNITDIESOTHER, "Eye Tentacle")) then
    self.tentaclesKilled = self.tentaclesKilled + 1
    self:TriggerEvent("BigWigs_SetCounterBar", self, "Eye Tentacles alive", self.tentaclesKilled)
  end
end

-- CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF = Birth
function BigWigsCThun:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE(msg)
  if not cthunstarted and arg1 and string.find(arg1, L["eyebeam"]) then
    self:TriggerEvent("BigWigs_SendSync", "CThunStart")
  end
  if string.find(msg, "begins to cast Eye") then
    self:ScheduleEvent("CThunDelayedEyeBeamCheck", self.DelayedEyeBeamCheck, targetCheckDelay, self) -- has to be done delayed since the target change is delayed
  end
end

function BigWigsCThun:DelayedEyeBeamCheck()
  local name = "<unknown>"
  if phase2started then
    self:CheckTargetP2()
  else
    self:CheckTarget()
  end

  if target then
    name = target
    --TODO self:Icon(name)
    if name == UnitName("player") then
      self:TriggerEvent("BigWigs_ShowIcon", "Interface\\Icons\\Ability_creature_poison_05", 2 - targetCheckDelay)
      self:TriggerEvent("BigWigs_Message", "Eye Beam, on YOU!", "Urgent", true, "Alarm", 2 - targetCheckDelay)
    end
  end
  self:TriggerEvent("BigWigs_StartBar", self, string.format(L["eye_cast_bar_on"], name), 2 - targetCheckDelay, "Interface\\Icons\\Spell_Nature_CallStorm")

  --self:Bar(string.format(L["eyebeam"], name), timer.eyeBeam - 0.1, icon.giantEye, true, "green")
end

function BigWigsCThun:BigWigs_RecvSync(sync, rest, nick)
  if not self.started and ((sync == "BossEngaged" and rest == self.bossSync) or (sync == "CThunStart")) then
    self:StartFight()
    self:CThunStart()
  elseif sync == "CThunP2StartDS" then
    self:CThunP2StartDS()
  elseif sync == "CThunWeakenedDS" then
    self:CThunWeakenedDS()
  elseif sync == "CThunGEdownDS" then
    self:TriggerEvent("BigWigs_Message", L["gedownwarn"], "Positive")
  end
end

-----------------------
--   Sync Handlers   --
-----------------------

function BigWigsCThun:CThunStart()
  if not cthunstarted then
    cthunstarted = true

    if self.db.profile.tentacle then
      self:TriggerEvent("BigWigs_StartBar", self, self.db.profile.rape and L["bar_tentacle_rape"], timeP1TentacleStart, "Interface\\Icons\\Spell_Nature_CallStorm")
      self:ScheduleEvent("bwcthuntentacle", "BigWigs_Message", timeP1TentacleStart - 5, self.db.profile.rape and L["tentacle"] or L["norape"], "Urgent", true, "Alert")
    end

    if self.db.profile.glare then
      self.StartGreenBeamPhase(self)
    end

    firstWarning = true

    self:ScheduleEvent("bw_repeating_tentacle_rape_partystart", self.StartTentacleRape, timeP1TentacleStart, self )
    self:ScheduleRepeatingEvent("bwcthuntarget", self.CheckTarget, timeTarget, self )
  end
end

function BigWigsCThun:CThunP2StartDS()
  if not phase2started then
    phase2started = true
    tentacletime = timeP2Tentacle
    target = nil

    self:StopTentacleRape() -- stop p1 tentacle rape
    self:CancelScheduledEvent("bw_repeating_tentacle_rape_partystart")
    self:CancelScheduledEvent("bwstartgreenbeamphase")
    self:CancelScheduledEvent("bwstartdarkglarephase")
    self:CancelScheduledEvent("bwshowdarkglarewarning")
    -- TODO avoid msgs

    self:TriggerEvent("BigWigs_Message", L["phase2starting"], "Bosskill")

    self:TriggerEvent("BigWigs_StopBar", self, L["barGlare"] )
    self:TriggerEvent("BigWigs_StopBar", self, L["barNextGlare"] )
    self:TriggerEvent("BigWigs_StopBar", self, L["bar_tentacle_rape"] )
    self:TriggerEvent("BigWigs_StopBar", self, L["barGreenBeam"] )

    self:CancelScheduledEvent("bwcthuntentacle")
    self:CancelScheduledEvent("bwcthunglarecooldown")
    self:CancelScheduledEvent("bwcthunglare")
    self:CancelScheduledEvent("bwcthunpositions2")

    -- cancel the repeaters
    self:CancelScheduledEvent("bw_repeating_tentacle_rape_party")
    self:CancelScheduledEvent("bwcthundarkglare")
    self:CancelScheduledEvent("bwcthungroupwarning")
    self:CancelScheduledEvent("bwcthuntarget")
    self:CancelScheduledEvent("bwctea1")
    self:CancelScheduledEvent("bwctea2")
    self:CancelScheduledEvent("bwctga")

    if self.db.profile.tentacle then
      self:TriggerEvent("BigWigs_StartBar", self, L["bar_tentacle_rape"], 38+timeP2Offset, "Interface\\Icons\\Spell_Nature_CallStorm")
    end

    if self.db.profile.giant then
      self:TriggerEvent("BigWigs_StartBar", self, L["bar_giant_eye"], 38+timeP2Offset, "Interface\\Icons\\Ability_EyeOfTheOwl")
      self:TriggerEvent("BigWigs_StartBar", self, L["bar_giant_claw"], 8+timeP2Offset, "Interface\\Icons\\Spell_Nature_Earthquake")
    end

    self:ScheduleEvent("bwcthunstarttentacles", self.StartTentacleRape, 38 + timeP2Offset, self )
    self:ScheduleEvent("bwcthunstartgiant", self.StartGiantEyeRape, 38+timeP2Offset, self )
    self:ScheduleEvent("bwcthunstartgiantc", self.StartGiantClawRape, 8+timeP2Offset, self )
    --self:ScheduleRepeatingEvent("bwcthuntargetp2", self.CheckTargetP2, timeTarget, self )
  end

end

function BigWigsCThun:CThunWeakenedDS()
  if self.db.profile.weakened then
    self:TriggerEvent("BigWigs_Message", L["weakened"], "Positive" )
    self:TriggerEvent("BigWigs_StartBar", self, L["barWeakened"], timeWeakened, "Interface\\Icons\\INV_ValentinesCandy")
    self:ScheduleEvent("bwcthunweaken2", "BigWigs_Message", timeWeakened - 5, L["invulnerable2"], "Urgent")
    self:ScheduleEvent("bwcthunweaken1", "BigWigs_Message", timeWeakened, L["invulnerable1"], "Important" )
  end

  -- cancel tentacle timers - OK
  self:StopTentacleRape()
  self:StopGiantEyeRape()
  self:StopGiantClawRape()


  -- Schedule timers for invuln phase
  self:ScheduleEvent("bw_restart_p2", self.RescheduleInvulnPhase, 45, self )
end

function BigWigsCThun:RescheduleInvulnPhase()
  if self.db.profile.tentacle then
    self:TriggerEvent("BigWigs_StartBar", self, L["bar_tentacle_rape"], 38, "Interface\\Icons\\Spell_Nature_CallStorm")
  end

  if self.db.profile.giant then
    self:TriggerEvent("BigWigs_StartBar", self, L["bar_giant_eye"], 38, "Interface\\Icons\\Ability_EyeOfTheOwl")
    self:TriggerEvent("BigWigs_StartBar", self, L["bar_giant_claw"], 8, "Interface\\Icons\\Spell_Nature_Earthquake")
  end


  self:ScheduleEvent("bwcthunstarttentacles", self.StartTentacleRape, 38, self )
  self:ScheduleEvent("bwcthunstartgiant", self.StartGiantEyeRape, 38, self )
  self:ScheduleEvent("bwcthunstartgiantc", self.StartGiantClawRape, 8, self )
end

-----------------------
-- Utility Functions --
-----------------------

function BigWigsCThun:StartTentacleRape()
  self:TentacleRape()
  self:ScheduleRepeatingEvent("bw_repeating_tentacle_rape_party", self.TentacleRape, tentacletime, self )
end

function BigWigsCThun:StopTentacleRape()
  self:TriggerEvent("BigWigs_StopCounterBar", self, "Eye Tentacles alive")
  self:CancelScheduledEvent("bw_repeating_tentacle_rape_party")
  self:TriggerEvent("BigWigs_StopBar", self, L["bar_tentacle_rape"])
end

function BigWigsCThun:StartGiantEyeRape()
  self:GTentacleRape()
  self:ScheduleRepeatingEvent("bw_repeating_giant_eye", self.GTentacleRape, 60, self )
end

function BigWigsCThun:StopGiantEyeRape()
  self:CancelScheduledEvent("bw_repeating_giant_eye")
  self:TriggerEvent("BigWigs_StopBar", self, L["bar_giant_eye"])
end

function BigWigsCThun:StartGiantClawRape()
  self:GCTentacleRape()
  self:ScheduleRepeatingEvent("bw_repeating_giant_claw", self.GCTentacleRape, 60, self )
end

function BigWigsCThun:StopGiantClawRape()
  self:CancelScheduledEvent("bw_repeating_giant_claw")
  self:TriggerEvent("BigWigs_StopBar", self, L["bar_giant_claw"])
end


function BigWigsCThun:CheckTarget()
  local i
  local newtarget = nil
  if( UnitName("playertarget") == eyeofcthun ) then
    newtarget = UnitName("playertargettarget")
  else
    for i = 1, GetNumRaidMembers(), 1 do
      if UnitName("Raid"..i.."target") == eyeofcthun then
        newtarget = UnitName("Raid"..i.."targettarget")
        break
      end
    end
  end
  if( newtarget ) then
    target = newtarget
  end
end

function BigWigsCThun:CheckTargetP2()
  local i
  local newtarget = nil

  if( UnitName("playertarget") == gianteye ) then
    newtarget = UnitName("playertargettarget")
  else
    for i = 1, GetNumRaidMembers(), 1 do
      if UnitName("Raid"..i.."target") == gianteye then
        newtarget = UnitName("Raid"..i.."targettarget")
        break
      end
    end
  end
  if( newtarget ) then
    target = newtarget
  end
end


function BigWigsCThun:GTentacleRape()
  if self.db.profile.giant then
    self:TriggerEvent("BigWigs_StartBar", self, L["bar_giant_eye"], timeP2ETentacle, "Interface\\Icons\\Ability_EyeOfTheOwl")
  end
end

function BigWigsCThun:GCTentacleRape()
  if self.db.profile.giant then
    self:TriggerEvent("BigWigs_StartBar", self, L["bar_giant_claw"], timeP2CTentacle, "Interface\\Icons\\Spell_Nature_Earthquake")
  end
end

function BigWigsCThun:TentacleRape()
  if self.db.profile.tentacle then

    self.tentaclesKilled = 0
    self:TriggerEvent("BigWigs_StartCounterBar", self, "Eye Tentacles alive", 8, "Interface\\Icons\\Spell_Nature_CallStorm")
    self:TriggerEvent("BigWigs_SetCounterBar", self, "Eye Tentacles alive", 0)

    self:TriggerEvent("BigWigs_StartBar", self, self.db.profile.rape and L["bar_tentacle_rape"], tentacletime, "Interface\\Icons\\Spell_Nature_CallStorm")
    self:ScheduleEvent("bwcthuntentacle", "BigWigs_Message", tentacletime - 5, self.db.profile.rape and L["tentacle"] or L["norape"], "Urgent", true, "Alert")
  end
end

function BigWigsCThun:StartDarkGlarePhase()
  self:TriggerEvent("BigWigs_StartBar", self, L["barGlare"], timeP1GlareDuration, "Interface\\Icons\\Spell_Nature_CallStorm")
  self:ScheduleEvent("bwstartgreenbeamphase", self.StartGreenBeamPhase, timeP1GlareDuration, self )
end

function BigWigsCThun:GroupWarning()
  if target then
    local i, name, group
    for i = 1, GetNumRaidMembers(), 1 do
      name, _, group, _, _, _, _, _ = GetRaidRosterInfo(i)
      if name == target then break end
    end
    if self.db.profile.group then
      self:TriggerEvent("BigWigs_Message", string.format( L["groupwarning"], group, target), "Important", true, "Alarm")
      self:TriggerEvent("BigWigs_SendTell", target, L["glarewarning"])
    end
  end
  if firstWarning then
    self:CancelScheduledEvent("bwcthungroupwarning")
    self:ScheduleRepeatingEvent("bwcthungroupwarning", self.GroupWarning, timeP1Glare, self )
    firstWarning = nil
  end
end

function BigWigsCThun:WarnDarkGlare()
  self:TriggerEvent("BigWigs_ShowIcon", "Interface\\Icons\\Ability_Rogue_Sprint", 5)
  self:TriggerEvent("BigWigs_Message", L["darkglare_soon_message"], "Urgent", true, "Alarm")
end

function BigWigsCThun:StartGreenBeamPhase()
  self:TriggerEvent("BigWigs_StartBar", self, L["barNextGlare"], timeP1GreenBeam, "Interface\\Icons\\Spell_Shadow_ShadowBolt")
  self:ScheduleEvent("bwstartdarkglarephase", self.StartDarkGlarePhase, timeP1GreenBeam, self )
  self:ScheduleEvent("bwshowdarkglarewarning", self.WarnDarkGlare, timeP1GreenBeam-5, self )
end
