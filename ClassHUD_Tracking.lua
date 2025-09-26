-- ClassHUD_Tracking.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

local bit_band = bit and bit.band or (bit32 and bit32.band)
local AFFILIATION_MINE = _G.COMBATLOG_OBJECT_AFFILIATION_MINE or 0

local IMPLOSION_SPELL_ID = 196277
local FEL_FIREBOLT_SPELL_ID = 104318
local WILD_IMP_MAX_CHARGES = 5
local WILD_IMP_AVERAGE_DURATION = 12
local WILD_IMP_DISPLAY_SPELL_ID = 104317
local WILD_IMP_EXPIRY_CHECK_INTERVAL = 0.2
local TOTEM_DURATION_UPDATE_INTERVAL = 0.1

local SUMMON_SPELLS = ClassHUD.SUMMON_SPELLS or {}
local WILD_IMP_SUMMON_IDS = ClassHUD.WILD_IMP_SUMMON_IDS or {}
local WILD_IMP_NPC_IDS = ClassHUD.WILD_IMP_NPC_IDS or {}

ClassHUD.IMPLOSION_SPELL_ID = IMPLOSION_SPELL_ID
ClassHUD.FEL_FIREBOLT_SPELL_ID = FEL_FIREBOLT_SPELL_ID
ClassHUD.WILD_IMP_DISPLAY_SPELL_ID = WILD_IMP_DISPLAY_SPELL_ID

local PopulateBuffIconFrame = ClassHUD.PopulateBuffIconFrame
local CreateBuffFrame = ClassHUD.CreateBuffFrame

local function Contains(list, value)
  if type(list) ~= "table" then return false end
  for i = 1, #list do
    if list[i] == value then
      return true
    end
  end
  return false
end

local function TableCount(tbl)
  local count = 0
  if tbl then
    for _ in pairs(tbl) do
      count = count + 1
    end
  end
  return count
end

local function UpdateWildImpIndicator(self, count)
  if count == nil then
    count = TableCount(self and self._wildImpGuids)
  end

  count = count or 0
  self._wildImpCount = count

  if self and self.GetWildImpTrackingMode and self.UpdateWildImpBuffFrame and self.HideWildImpBuffFrame then
    local mode = self:GetWildImpTrackingMode()
    if mode == "buff" and self:IsWildImpTrackingEnabled() then
      self:UpdateWildImpBuffFrame(count)
    else
      self:HideWildImpBuffFrame()
    end
  end

  if self.UpdateCooldown and self.GetSpellFrameForSpellID then
    local frame = select(1, self:GetSpellFrameForSpellID(IMPLOSION_SPELL_ID))
    if frame then
      self:UpdateCooldown(frame.spellID)
    end
  end
end

local function SyncWildImpCount(self)
  local count = TableCount(self and self._wildImpGuids)
  UpdateWildImpIndicator(self, count)
  return count
end

local function RemoveWildImp(self, guid)
  if not guid then return false end
  local map = self._wildImpGuids
  if not map or not map[guid] then return false end

  map[guid] = nil
  if not next(map) then
    self:CancelWildImpExpiryCheck()
  end
  SyncWildImpCount(self)
  return true
end

function ClassHUD:ScheduleWildImpExpiryCheck()
  if not self or not self.ScheduleRepeatingTimer then return end
  if self._wildImpExpiryTimer then return end

  self._wildImpExpiryTimer = self:ScheduleRepeatingTimer("CheckWildImpExpiration", WILD_IMP_EXPIRY_CHECK_INTERVAL)
end

function ClassHUD:CancelWildImpExpiryCheck()
  local handle = self and self._wildImpExpiryTimer
  if not handle then return end

  self._wildImpExpiryTimer = nil
  if self.CancelTimer then
    self:CancelTimer(handle)
  end
end

function ClassHUD:CheckWildImpExpiration()
  if not self:IsWildImpTrackingEnabled() then
    self:CancelWildImpExpiryCheck()
    return
  end

  local map = self._wildImpGuids
  if not map or not next(map) then
    self:CancelWildImpExpiryCheck()
    return
  end

  local now = GetTime()
  local toRemove = nil

  for guid, entry in pairs(map) do
    if guid and entry then
      if not entry.npcID then
        entry.npcID = self:GetNpcIDFromGUID(guid)
      end

      local npcID = entry.npcID
      local charges = entry.charges or 0
      local spawnTime = entry.spawnTime or now
      if not entry.spawnTime then
        entry.spawnTime = spawnTime
      end

      local shouldRemove = false

      if npcID and not WILD_IMP_NPC_IDS[npcID] then
        shouldRemove = true
      elseif charges <= 0 then
        shouldRemove = true
      elseif (now - spawnTime) > WILD_IMP_AVERAGE_DURATION then
        shouldRemove = true
      end

      if shouldRemove then
        toRemove = toRemove or {}
        toRemove[#toRemove + 1] = guid
      end
    else
      toRemove = toRemove or {}
      toRemove[#toRemove + 1] = guid
    end
  end

  if toRemove then
    for i = 1, #toRemove do
      RemoveWildImp(self, toRemove[i])
    end
  end

  if not self._wildImpGuids or not next(self._wildImpGuids) then
    self:CancelWildImpExpiryCheck()
  end
end

ClassHUD._activeSummonsBySpell = ClassHUD._activeSummonsBySpell or {}
ClassHUD._summonGuidToSpell = ClassHUD._summonGuidToSpell or {}
ClassHUD._wildImpGuids = ClassHUD._wildImpGuids or {}
ClassHUD._wildImpCount = ClassHUD._wildImpCount or 0
ClassHUD._activeTotems = ClassHUD._activeTotems or {}
ClassHUD._pendingTotemFrames = ClassHUD._pendingTotemFrames or {}
ClassHUD._spellNameToID = ClassHUD._spellNameToID or {}
ClassHUD._trackedBuffRegistry = ClassHUD._trackedBuffRegistry or {}
ClassHUD._trackedBuffOrder = ClassHUD._trackedBuffOrder or {}

local function GetPlayerClassToken(self)
  if self and self.GetPlayerClassSpec then
    local class = select(1, self:GetPlayerClassSpec())
    if class and class ~= "" then
      return class
    end
  end
  if UnitClass then
    local _, token = UnitClass("player")
    return token
  end
  return nil
end

function ClassHUD:IsTemporarySummonTrackingEnabled()
  local tracking = self and self.db and self.db.profile and self.db.profile.tracking
  local config = tracking and tracking.summons
  if config and config.enabled ~= nil then
    return not not config.enabled
  end
  return true
end

function ClassHUD:IsSummonSpellEnabled(spellID)
  if not self:IsTemporarySummonTrackingEnabled() then
    return false
  end
  if not spellID then
    return true
  end

  local tracking = self.db and self.db.profile and self.db.profile.tracking
  if not tracking then
    return true
  end

  local class = GetPlayerClassToken(self)
  if not class then
    return true
  end

  local summons = tracking.summons or {}
  local byClass = summons.byClass or {}
  local classConfig = byClass[class]
  if type(classConfig) ~= "table" then
    return true
  end
  local value = classConfig[spellID]
  if value == nil then
    value = classConfig[tostring(spellID)]
  end
  if value == nil then
    return true
  end
  return not not value
end

function ClassHUD:IsWildImpTrackingEnabled()
  if not self:IsTemporarySummonTrackingEnabled() then
    return false
  end
  if not (self and self.db and self.db.profile) then
    return true
  end
  local tracking = self.db.profile.tracking
  local config = tracking and tracking.wildImps
  if config and config.enabled ~= nil then
    return not not config.enabled
  end
  return true
end

function ClassHUD:GetWildImpTrackingMode()
  if not (self and self.db and self.db.profile) then
    return "implosion"
  end
  local tracking = self.db.profile.tracking
  local config = tracking and tracking.wildImps
  if config and config.mode == "buff" then
    return "buff"
  end
  return "implosion"
end

function ClassHUD:IsWildImpBuffMode()
  return self:GetWildImpTrackingMode() == "buff"
end

function ClassHUD:IsTotemTrackingEnabled()
  if not (self and self.db and self.db.profile) then
    return true
  end
  local tracking = self.db.profile.tracking
  local config = tracking and tracking.totems
  if config and config.enabled ~= nil then
    return not not config.enabled
  end
  return true
end

function ClassHUD:GetTotemOverlayStyle()
  if not (self and self.db and self.db.profile) then
    return "SWIPE"
  end
  local tracking = self.db.profile.tracking
  local config = tracking and tracking.totems
  return (config and config.overlayStyle) or "SWIPE"
end

function ClassHUD:GetActiveTotemStateForSpell(spellID)
  if not spellID then return nil end
  local list = self._activeTotems
  if not list then return nil end

  for slot = 1, 4 do
    local state = list[slot]
    if state and state.spellID == spellID then
      return state
    end
  end

  return nil
end

function ClassHUD:IsTotemDurationTextEnabled()
  if not (self and self.db and self.db.profile) then
    return true
  end
  local tracking = self.db.profile.tracking
  local config = tracking and tracking.totems
  if config and config.showDuration ~= nil then
    return not not config.showDuration
  end
  return true
end

function ClassHUD:ClearWildImpTracking()
  if self._wildImpGuids then
    wipe(self._wildImpGuids)
  else
    self._wildImpGuids = {}
  end
  self:CancelWildImpExpiryCheck()
  if self.HideWildImpBuffFrame then
    self:HideWildImpBuffFrame()
  end
  SyncWildImpCount(self)
end

function ClassHUD:RefreshWildImpDisplay()
  SyncWildImpCount(self)
end

local function DetermineSpellDuration(spellID, fallback)
  if C_Spell and C_Spell.GetSpellInfo then
    local normalizedSpellID = ClassHUD:GetActiveSpellID(spellID) or spellID
    local info = C_Spell.GetSpellInfo(normalizedSpellID)
    if info then
      if info.duration and info.duration > 0 then
        return info.duration
      end
      if info.durationMS and info.durationMS > 0 then
        return info.durationMS / 1000
      end
      if info.auraDuration and info.auraDuration > 0 then
        return info.auraDuration
      end
    end
  end
  return fallback
end

local function FinalizeSummonState(active)
  if not active then return end

  local count = 0
  local nextExpiration = nil
  local duration = 0

  if active.guids then
    for _, info in pairs(active.guids) do
      if info and info.expiration and info.expiration > GetTime() then
        count = count + 1
        if not nextExpiration or info.expiration < nextExpiration then
          nextExpiration = info.expiration
        end
        if info.duration and info.duration > duration then
          duration = info.duration
        end
      end
    end
  end

  active.count = count
  active.nextExpiration = nextExpiration
  if duration and duration > 0 then
    active.duration = duration
  end
end

local function RemoveExpiredSummonGUIDs(self, spellID, active, now)
  if not active or not active.guids then return 0 end

  local removed = 0
  for guid, info in pairs(active.guids) do
    if not info or (info.expiration and info.expiration <= now) then
      active.guids[guid] = nil
      if self._summonGuidToSpell then
        self._summonGuidToSpell[guid] = nil
      end
      removed = removed + 1
    end
  end

  if removed > 0 then
    FinalizeSummonState(active)
  end

  return removed
end

function ClassHUD:GetSummonDuration(spellID)
  local def = SUMMON_SPELLS[spellID]
  if not def then return nil end

  if def.duration and def.duration > 0 then
    return def.duration
  end

  local fallback = def.fallbackDuration or def.duration
  local duration = DetermineSpellDuration(def.durationSpellID or spellID, fallback)
  if duration and duration > 0 then
    return duration
  end

  return fallback
end

local function EnsureSummonFrame(self, spellID)
  if not self.trackedBuffFrames then
    self.trackedBuffFrames = {}
  end
  if not self._trackedBuffRegistry then
    self._trackedBuffRegistry = {}
  end
  if not self._trackedBuffOrder then
    self._trackedBuffOrder = {}
  end

  local registry = self._trackedBuffRegistry
  local def = registry[spellID]
  local frame = def and def.iconFrame

  if not frame or not frame._manualSummon then
    frame = CreateBuffFrame(spellID)
    frame.buffID = spellID
    frame._manualSummon = true
    frame._trackedEntry = nil
    frame._trackedAuraCandidates = nil
    frame._auraUnitList = nil
    frame._manualSummonSpellID = spellID
    frame._updateKind = "trackedIcon"
    frame._layoutActive = false
    frame._last = frame._last or {}
    ClassHUD:ClearFrameAuraWatchers(frame)

    def = def or {}
    def.iconFrame = frame
    def.entry = def.entry or nil
    def.iconCandidates = nil
    def.manualSummon = true
    registry[spellID] = def
  end

  if not Contains(self._trackedBuffOrder, spellID) then
    table.insert(self._trackedBuffOrder, spellID)
  end

  if not Contains(self.trackedBuffFrames, frame) then
    table.insert(self.trackedBuffFrames, frame)
  end

  return frame, def
end

local function EnsureWildImpBuffFrame(self)
  local frame = self._wildImpBuffFrame
  if frame and frame._manualWildImp then
    return frame
  end

  frame = CreateBuffFrame(WILD_IMP_DISPLAY_SPELL_ID)
  frame.buffID = WILD_IMP_DISPLAY_SPELL_ID
  frame._manualWildImp = true
  frame._manualSummon = true
  frame._trackedEntry = nil
  frame._trackedAuraCandidates = nil
  frame._auraUnitList = nil
  frame._manualSummonSpellID = WILD_IMP_DISPLAY_SPELL_ID
  frame._layoutActive = false
  frame._updateKind = "trackedIcon"
  frame._last = frame._last or {}
  ClassHUD:ClearFrameAuraWatchers(frame)

  self._wildImpBuffFrame = frame

  if not self.trackedBuffFrames then
    self.trackedBuffFrames = {}
  end

  if not Contains(self.trackedBuffFrames, frame) then
    table.insert(self.trackedBuffFrames, frame)
  end

  if not self._trackedBuffOrder then
    self._trackedBuffOrder = {}
  end

  if not Contains(self._trackedBuffOrder, WILD_IMP_DISPLAY_SPELL_ID) then
    table.insert(self._trackedBuffOrder, WILD_IMP_DISPLAY_SPELL_ID)
  end

  return frame
end

function ClassHUD:UpdateSummonFrame(spellID, suppressLayout)
  local active = self._activeSummonsBySpell and self._activeSummonsBySpell[spellID]
  if not active then return end

  local frame = EnsureSummonFrame(self, spellID)
  if not frame then return end

  local duration = active.duration
  if (not duration or duration <= 0) and active.expiration and active.startTime then
    duration = math.max(0, active.expiration - active.startTime)
  end

  local displayID = active.iconSpellID or spellID

  local aura = nil
  if active.expiration and duration and duration > 0 then
    aura = {
      duration = duration,
      expirationTime = active.expiration,
      modRate = 1,
    }
  end

  local count = active.count or 0
  if count > 0 then
    aura = aura or {}
    aura.applications = count
    aura.charges = count
  end

  frame.buffID = displayID
  PopulateBuffIconFrame(frame, displayID, aura, nil)

  frame._manualSummon = true
  frame._layoutActive = true
  frame:Show()

  if not suppressLayout then
    self:ApplyTrackedBuffLayout()
  end
end

function ClassHUD:ScheduleSummonExpiryCheck(spellID)
  local active = self._activeSummonsBySpell and self._activeSummonsBySpell[spellID]
  if not active then return end

  if active.timer then
    self:CancelTimer(active.timer)
    active.timer = nil
  end

  local nextExpiration = active.nextExpiration or active.expiration
  if not nextExpiration then return end

  local delay = nextExpiration - GetTime()
  if delay and delay > 0 then
    active.timer = self:ScheduleTimer("CheckSummonExpiration", delay + 0.05, spellID)
  else
    self:CheckSummonExpiration(spellID)
  end
end

function ClassHUD:CheckSummonExpiration(spellID)
  local active = self._activeSummonsBySpell and self._activeSummonsBySpell[spellID]
  if not active then return end

  active.timer = nil

  local removed = RemoveExpiredSummonGUIDs(self, spellID, active, GetTime())

  if not active.count or active.count <= 0 then
    self:DeactivateSummonSpell(spellID)
    return
  end

  if removed > 0 then
    self:UpdateSummonFrame(spellID, true)
  end

  self:ScheduleSummonExpiryCheck(spellID)
end

function ClassHUD:DeactivateSummonSpell(spellID)
  local active = self._activeSummonsBySpell and self._activeSummonsBySpell[spellID]
  if not active then return end

  if active.timer then
    self:CancelTimer(active.timer)
    active.timer = nil
  end

  if active.guids then
    for guid in pairs(active.guids) do
      if self._summonGuidToSpell then
        self._summonGuidToSpell[guid] = nil
      end
    end
    wipe(active.guids)
  end

  active.count = 0
  active.expiration = nil
  active.duration = nil
  active.nextExpiration = nil

  local frame = self._trackedBuffRegistry and self._trackedBuffRegistry[spellID]
  frame = frame and frame.iconFrame
  if frame then
    frame._layoutActive = false
    frame:Hide()
  end

  if self._trackedBuffOrder then
    for index = #self._trackedBuffOrder, 1, -1 do
      if self._trackedBuffOrder[index] == spellID then
        table.remove(self._trackedBuffOrder, index)
        break
      end
    end
  end

  if self._activeSummonsBySpell then
    self._activeSummonsBySpell[spellID] = nil
  end

  self:ApplyTrackedBuffLayout()
end

function ClassHUD:HandleTrackedSummon(spellID, destGUID)
  if not self:IsSummonSpellEnabled(spellID) then
    return
  end

  local def = SUMMON_SPELLS[spellID]
  if not def then return end

  local duration = self:GetSummonDuration(spellID)
  if not duration or duration <= 0 then
    duration = def.fallbackDuration or 0
  end

  self._activeSummonsBySpell = self._activeSummonsBySpell or {}
  local active = self._activeSummonsBySpell[spellID]

  local now = GetTime()

  if not active then
    active = {
      spellID = spellID,
      iconSpellID = def.displaySpellID or spellID,
      duration = duration,
      expiration = (duration and duration > 0) and (now + duration) or nil,
      startTime = now,
      guids = {},
      count = 0,
      demon = not not def.demon,
      npcID = def.npcID,
    }
    self._activeSummonsBySpell[spellID] = active
  end

  active.iconSpellID = active.iconSpellID or spellID
  active.guids = active.guids or {}
  local guidKey = destGUID
  if not guidKey then
    active._syntheticIndex = (active._syntheticIndex or 0) + 1
    guidKey = string.format("synthetic:%d:%d:%d", spellID, math.floor(now * 1000), active._syntheticIndex)
  end

  active.guids[guidKey] = {
    guid = destGUID or guidKey,
    startTime = now,
    duration = duration,
    expiration = now + duration,
  }

  if destGUID then
    self._summonGuidToSpell[destGUID] = spellID
  end

  FinalizeSummonState(active)
  self:UpdateSummonFrame(spellID, true)
  self:ScheduleSummonExpiryCheck(spellID)
  if def.tyrant then
    self:ExtendActiveSummonDurations(def.extendDuration or 15, spellID)
  end
  self:ApplyTrackedBuffLayout()
end

function ClassHUD:ExtendActiveSummonDurations(extension, excludeSpellID)
  if not extension or extension <= 0 then return end
  local list = self._activeSummonsBySpell
  if not list then return end

  local now = GetTime()
  for spellID, active in pairs(list) do
    if spellID ~= excludeSpellID and active then
      local def = SUMMON_SPELLS[spellID]
      if def and def.demon then
        if active.guids then
          for _, data in pairs(active.guids) do
            if data then
              local expiration = data.expiration
              if expiration and expiration > now then
                data.expiration = expiration + extension
              else
                data.expiration = now + extension
              end

              if data.startTime then
                data.duration = data.expiration - data.startTime
              else
                data.startTime = now
                data.duration = math.max(data.duration or 0, extension)
              end
            end
          end
        end

        if active.startTime then
          local latestExpire = 0
          for _, data in pairs(active.guids) do
            if data.expiration and data.expiration > latestExpire then
              latestExpire = data.expiration
            end
          end
          if latestExpire > 0 then
            active.expiration = latestExpire
            active.duration   = active.expiration - active.startTime
          end
        end

        FinalizeSummonState(active)
        self:UpdateSummonFrame(spellID, true)
        self:ScheduleSummonExpiryCheck(spellID)
      end
    end
  end
end

function ClassHUD:HandleSummonedUnitDeath(destGUID)
  if not destGUID then return end

  local spellID = self._summonGuidToSpell and self._summonGuidToSpell[destGUID]
  if not spellID then return end

  self._summonGuidToSpell[destGUID] = nil

  local active = self._activeSummonsBySpell and self._activeSummonsBySpell[spellID]
  if not active then return end

  if active.guids then
    active.guids[destGUID] = nil
  end

  FinalizeSummonState(active)

  if not active.count or active.count <= 0 then
    self:DeactivateSummonSpell(spellID)
    return
  end

  self:UpdateSummonFrame(spellID, true)
  self:ScheduleSummonExpiryCheck(spellID)
end

function ClassHUD:RefreshTemporaryBuffs(suppressLayout)
  if not self._activeSummonsBySpell then return end

  if not self:IsTemporarySummonTrackingEnabled() then
    if next(self._activeSummonsBySpell) ~= nil then
      self:ResetSummonTracking()
    end
    return
  end

  local now = GetTime()
  local any = false
  for spellID, active in pairs(self._activeSummonsBySpell) do
    RemoveExpiredSummonGUIDs(self, spellID, active, now)

    if not active.count or active.count <= 0 then
      self:DeactivateSummonSpell(spellID)
    else
      self:UpdateSummonFrame(spellID, true)
      any = true
    end
  end

  local wildImps = self._wildImpGuids
  if wildImps and next(wildImps) then
    local mapChanged = false
    for guid, entry in pairs(wildImps) do
      if entry then
        if not entry.npcID then
          entry.npcID = self:GetNpcIDFromGUID(guid)
        end

        local npcID = entry.npcID
        local remove = false

        if npcID and not WILD_IMP_NPC_IDS[npcID] then
          remove = true
        end

        local charges = entry.charges
        if not remove and charges and charges <= 0 then
          remove = true
        end

        local spawnTime = entry.spawnTime
        if not remove and spawnTime then
          if (now - spawnTime) > WILD_IMP_AVERAGE_DURATION then
            remove = true
          end
        elseif not remove and not spawnTime then
          entry.spawnTime = now
        end

        if remove then
          wildImps[guid] = nil
          mapChanged = true
        end
      else
        wildImps[guid] = nil
        mapChanged = true
      end
    end

    if mapChanged then
      SyncWildImpCount(self)
    end
  end

  if any and not suppressLayout then
    self:ApplyTrackedBuffLayout()
  end
end

function ClassHUD:ResetSummonTracking()
  if self._activeSummonsBySpell then
    local pending = {}
    for spellID in pairs(self._activeSummonsBySpell) do
      pending[#pending + 1] = spellID
    end
    for i = 1, #pending do
      self:DeactivateSummonSpell(pending[i])
    end
    wipe(self._activeSummonsBySpell)
  else
    self._activeSummonsBySpell = {}
  end

  if self._summonGuidToSpell then
    wipe(self._summonGuidToSpell)
  else
    self._summonGuidToSpell = {}
  end

  self:ClearWildImpTracking()
end

function ClassHUD:HideWildImpBuffFrame()
  local frame = self._wildImpBuffFrame
  if not frame then return end

  local wasActive = not not frame._layoutActive

  CooldownFrame_Clear(frame.cooldown)
  frame.cooldown:Hide()

  frame.count:SetText("")
  frame.count:Hide()

  self:ApplyCooldownText(frame, nil)

  frame._layoutActive = false
  frame:Hide()

  if wasActive then
    self:ApplyTrackedBuffLayout()
  end
end

function ClassHUD:UpdateWildImpBuffFrame(count)
  if not self:IsWildImpTrackingEnabled() or not self:IsWildImpBuffMode() then
    self:HideWildImpBuffFrame()
    return
  end

  count = count or (self._wildImpCount or 0)
  if count <= 0 then
    self:HideWildImpBuffFrame()
    return
  end

  local frame = EnsureWildImpBuffFrame(self)
  if not frame then return end

  local aura = {}
  local duration = WILD_IMP_AVERAGE_DURATION
  local now = GetTime()
  local oldestSpawn = nil

  if self._wildImpGuids then
    for _, entry in pairs(self._wildImpGuids) do
      if entry and entry.spawnTime then
        if not oldestSpawn or entry.spawnTime < oldestSpawn then
          oldestSpawn = entry.spawnTime
        end
      end
    end
  end

  if oldestSpawn then
    aura.duration = duration
    aura.expirationTime = oldestSpawn + duration
    aura.modRate = 1
  else
    aura.duration = duration
    aura.expirationTime = now + duration
    aura.modRate = 1
  end

  aura.applications = count
  aura.charges = count

  PopulateBuffIconFrame(frame, WILD_IMP_DISPLAY_SPELL_ID, aura, nil)

  frame._manualWildImp = true
  frame._manualSummon = true
  frame._layoutActive = true
  frame:Show()

  self:ApplyTrackedBuffLayout()
end

function ClassHUD:HandleWildImpSummon(destGUID, npcID)
  if not self:IsWildImpTrackingEnabled() then return end

  if npcID and not WILD_IMP_NPC_IDS[npcID] then
    return
  end

  if not destGUID then return end

  self._wildImpGuids = self._wildImpGuids or {}
  self._wildImpGuids[destGUID] = {
    spawnTime = GetTime(),
    charges = WILD_IMP_MAX_CHARGES,
    npcID = npcID or self:GetNpcIDFromGUID(destGUID),
  }

  SyncWildImpCount(self)
  self:ScheduleWildImpExpiryCheck()
end

function ClassHUD:HandleWildImpDespawn(destGUID, npcID)
  if not destGUID then return end

  local map = self._wildImpGuids
  if not map or not map[destGUID] then return end

  if npcID and not WILD_IMP_NPC_IDS[npcID] then
    return
  end

  RemoveWildImp(self, destGUID)
end

function ClassHUD:HandleWildImpFelFirebolt(destGUID, sourceGUID)
  if not destGUID and not sourceGUID then return end
  if not self:IsWildImpTrackingEnabled() then return end

  local map = self._wildImpGuids
  if not map then return end

  local guid = nil
  if destGUID and map[destGUID] then
    guid = destGUID
  elseif sourceGUID and map[sourceGUID] then
    guid = sourceGUID
  end

  if not guid then return end

  local entry = map[guid]
  if not entry then return end

  if not entry.npcID then
    entry.npcID = self:GetNpcIDFromGUID(guid)
  end

  local npcID = entry.npcID
  if npcID and not WILD_IMP_NPC_IDS[npcID] then
    map[guid] = nil
    SyncWildImpCount(self)
    return
  end

  local remaining = (entry.charges or WILD_IMP_MAX_CHARGES) - 1
  if remaining <= 0 then
    RemoveWildImp(self, guid)
    return
  end

  entry.charges = remaining
  SyncWildImpCount(self)
end

local function FindSpellFrameByName(self, name)
  if not name or not self.spellFrames then return nil end

  local cache = self._spellNameToID
  local cachedID = cache and cache[name]
  if cachedID and self.GetSpellFrameForSpellID then
    local frame, baseID = self:GetSpellFrameForSpellID(cachedID)
    if frame then
      return frame, baseID or frame.spellID
    end
  end

  if not cache then
    cache = {}
    self._spellNameToID = cache
  end

  for spellID, frame in pairs(self.spellFrames) do
    local activeSpellID = self.GetActiveSpellID and self:GetActiveSpellID(spellID) or spellID
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(activeSpellID)
    local spellName = info and info.name
    if spellName == name then
      cache[name] = spellID
      return frame, spellID
    end
  end

  cache[name] = nil
  return nil
end

function ClassHUD:HasTotemDuration(state)
  return state and state.expiration and state.duration and state.duration > 0
end

function ClassHUD:MarkTotemFrameForUpdate(frame)
  if not frame then return end

  local state = frame._activeTotemState
  if not self:IsTotemDurationTextEnabled() or not self:HasTotemDuration(state) then
    self:UnmarkTotemFrame(frame)
    return
  end

  local bucket = self._pendingTotemFrames
  if not bucket then
    bucket = {}
    self._pendingTotemFrames = bucket
  end

  bucket[frame] = true
  frame._nextTotemTimerUpdate = frame._nextTotemTimerUpdate or 0

  if not self._totemFlushTimer then
    self._totemFlushTimer = self:ScheduleTimer("FlushTotemChanges", TOTEM_DURATION_UPDATE_INTERVAL)
  end
end

function ClassHUD:UnmarkTotemFrame(frame)
  local bucket = self._pendingTotemFrames
  if not bucket then return end

  if frame then
    bucket[frame] = nil
    frame._nextTotemTimerUpdate = nil
    frame._totemLastTextValue = nil
  end

  if not next(bucket) and self._totemFlushTimer then
    local handle = self._totemFlushTimer
    self._totemFlushTimer = nil
    self:CancelTimer(handle)
  end
end

function ClassHUD:FlushTotemChanges()
  local handle = self._totemFlushTimer
  self._totemFlushTimer = nil
  if handle then
    self:CancelTimer(handle)
  end

  local bucket = self._pendingTotemFrames
  if not bucket or not next(bucket) then
    return
  end

  if not self:IsTotemDurationTextEnabled() then
    for frame in pairs(bucket) do
      bucket[frame] = nil
      if frame then
        frame._nextTotemTimerUpdate = nil
        frame._totemLastTextValue = nil
        self:ApplyCooldownText(frame, nil)
      end
    end
    return
  end

  local showNumbers = true
  if self.ShouldShowCooldownNumbers then
    showNumbers = self:ShouldShowCooldownNumbers()
  end

  local now = GetTime()
  local keepTicker = false
  for frame in pairs(bucket) do
    local state = frame and frame._activeTotemState
    if frame and self:HasTotemDuration(state) then
      local remaining = state.expiration - now
      if remaining and remaining > 0 then
        keepTicker = true
        local nextUpdate = frame._nextTotemTimerUpdate or 0
        if now >= nextUpdate then
          if showNumbers then
            local formatted = ClassHUD.FormatSeconds(remaining)
            if frame._totemLastTextValue ~= formatted then
              self:ApplyCooldownText(frame, remaining)
              frame._totemLastTextValue = formatted
            end
          else
            if frame._totemLastTextValue ~= nil or (frame._last and (frame._last.cooldownTextShown or frame._last.cooldownTextValue)) then
              self:ApplyCooldownText(frame, nil)
            end
            frame._totemLastTextValue = nil
          end
          frame._nextTotemTimerUpdate = now + TOTEM_DURATION_UPDATE_INTERVAL
        end
      else
        bucket[frame] = nil
        frame._nextTotemTimerUpdate = nil
        frame._totemLastTextValue = nil
        self:ApplyCooldownText(frame, nil)
      end
    else
      bucket[frame] = nil
      if frame then
        frame._nextTotemTimerUpdate = nil
        frame._totemLastTextValue = nil
        self:ApplyCooldownText(frame, nil)
      end
    end
  end

  if keepTicker and next(bucket) then
    self._totemFlushTimer = self:ScheduleTimer("FlushTotemChanges", TOTEM_DURATION_UPDATE_INTERVAL)
  end
end

local function EnsureTotemCooldown(frame)
  if frame.totemCooldown then return frame.totemCooldown end

  local parent = frame.overlay or frame
  local cooldown = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
  cooldown:SetAllPoints(frame.icon)
  cooldown:SetHideCountdownNumbers(true)
  cooldown:SetDrawBling(false)
  cooldown:SetDrawEdge(false)
  cooldown.noCooldownCount = true
  cooldown:SetSwipeColor(0.2, 0.8, 1, 0.55)

  local level = parent:GetFrameLevel() - 1
  if level < 1 then level = 1 end
  cooldown:SetFrameLevel(level)
  cooldown:Hide()

  frame.totemCooldown = cooldown
  return cooldown
end

function ClassHUD:ApplyTotemOverlay(state)
  if not state or not state.frame then return end

  if not self:IsTotemTrackingEnabled() then
    self:ClearTotemOverlay(state)
    return
  end

  local frame = state.frame
  local duration = state.duration or 0
  local startTime = state.startTime or GetTime()
  local style = self:GetTotemOverlayStyle()
  local useSwipe = style ~= "GLOW" and duration and duration > 0

  if useSwipe then
    local cooldown = EnsureTotemCooldown(frame)
    cooldown:SetCooldown(startTime, duration)
    cooldown:Show()
    frame._totemGlowActive = nil
  else
    if frame.totemCooldown then
      CooldownFrame_Clear(frame.totemCooldown)
      frame.totemCooldown:Hide()
    end

    if style == "GLOW" or not duration or duration <= 0 then
      frame._totemGlowActive = true
    else
      frame._totemGlowActive = nil
    end
  end

  frame._totemActive = true
  frame._totemSlot = state.slot
  frame._activeTotemState = state

  if self.UpdateCooldown then
    local updateSpellID = state.spellID or frame.spellID
    if updateSpellID then
      self:UpdateCooldown(updateSpellID)
    end
  end

  if self:IsTotemDurationTextEnabled() and self:HasTotemDuration(state) then
    local now = GetTime()
    local remaining = state.expiration - now
    if remaining and remaining > 0 then
      self:ApplyCooldownText(frame, remaining)
      if self.ShouldShowCooldownNumbers and self:ShouldShowCooldownNumbers() then
        frame._totemLastTextValue = ClassHUD.FormatSeconds(remaining)
      else
        frame._totemLastTextValue = nil
      end
      frame._nextTotemTimerUpdate = now + TOTEM_DURATION_UPDATE_INTERVAL
    else
      self:ApplyCooldownText(frame, nil)
      frame._totemLastTextValue = nil
      frame._nextTotemTimerUpdate = nil
    end
  else
    frame._totemLastTextValue = nil
    frame._nextTotemTimerUpdate = nil
  end

  self:MarkTotemFrameForUpdate(frame)
end

function ClassHUD:ClearTotemOverlay(state)
  if not state or not state.frame then return end

  local frame = state.frame
  self:UnmarkTotemFrame(frame)
  if frame.totemCooldown then
    CooldownFrame_Clear(frame.totemCooldown)
    frame.totemCooldown:Hide()
  end

  frame._totemGlowActive = nil

  frame._totemActive = nil
  frame._totemSlot = nil
  frame._activeTotemState = nil
  frame._nextTotemTimerUpdate = nil
  frame._totemLastTextValue = nil

  if state.spellID and self and self.UpdateCooldown then
    self:UpdateCooldown(state.spellID)
  end
end

function ClassHUD:UpdateTotemSlot(slot)
  if not slot then
    if not self:IsTotemTrackingEnabled() then
      self:ResetTotemTracking()
      return
    end
    for index = 1, 4 do
      self:UpdateTotemSlot(index)
    end
    return
  end

  if not self:IsTotemTrackingEnabled() then
    if self._activeTotems and self._activeTotems[slot] then
      self:ClearTotemOverlay(self._activeTotems[slot])
      self._activeTotems[slot] = nil
    end
    return
  end

  if not GetTotemInfo then return end

  local haveTotem, name, startTime, duration = GetTotemInfo(slot)

  if haveTotem and name and name ~= "" then
    local frame, spellID = FindSpellFrameByName(self, name)
    if frame and spellID then
      local state = self._activeTotems[slot] or {}
      state.slot = slot
      state.name = name
      state.spellID = spellID
      state.frame = frame
      state.startTime = (startTime and startTime > 0) and startTime or GetTime()
      state.duration = duration
      state.expiration = (duration and duration > 0) and (state.startTime + duration) or nil
      self._activeTotems[slot] = state

      self:ApplyTotemOverlay(state)
      if spellID and self.UpdateCooldown then
        self:UpdateCooldown(spellID)
      end
    else
      local previous = self._activeTotems[slot]
      if previous then
        self:ClearTotemOverlay(previous)
        self._activeTotems[slot] = nil
      end
    end
  else
    local previous = self._activeTotems[slot]
    if previous then
      self:ClearTotemOverlay(previous)
      self._activeTotems[slot] = nil
    end
  end
end

function ClassHUD:RefreshAllTotems()
  if not self:IsTotemTrackingEnabled() then
    self:ResetTotemTracking()
    return
  end

  for slot = 1, 4 do
    self:UpdateTotemSlot(slot)
  end
end

function ClassHUD:ResetTotemTracking()
  if not self._activeTotems then
    self._activeTotems = {}
  end

  for slot = 1, 4 do
    local state = self._activeTotems[slot]
    if state then
      self:ClearTotemOverlay(state)
      self._activeTotems[slot] = nil
    end
  end

  if self._pendingTotemFrames then
    wipe(self._pendingTotemFrames)
  end

  if self._totemFlushTimer then
    local handle = self._totemFlushTimer
    self._totemFlushTimer = nil
    self:CancelTimer(handle)
  end
end

local DEBUG_LOG_EVENTS = {
  SPELL_SUMMON = true,
  SPELL_CAST_SUCCESS = true,
  SPELL_CAST_START = true,
  SPELL_DAMAGE = true,
  UNIT_DIED = true,
  UNIT_DESTROYED = true,
  UNIT_DISSIPATES = true,
}

local function IsMine(sourceGUID, sourceFlags)
  local playerGUID = UnitGUID and UnitGUID("player")
  if playerGUID and sourceGUID == playerGUID then
    return true
  end
  if bit_band and sourceFlags and bit_band(sourceFlags, AFFILIATION_MINE) ~= 0 then
    return true
  end
  local petGUID = UnitGUID and UnitGUID("pet")
  if petGUID and sourceGUID == petGUID then
    return true
  end
  return false
end

function ClassHUD:HandleCombatLogEvent()
  if not CombatLogGetCurrentEventInfo then return end

  local _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID, destName, _, _, spellID, spellName =
      CombatLogGetCurrentEventInfo()
  local npcID = destGUID and self:GetNpcIDFromGUID(destGUID)

  if DEBUG_LOG_EVENTS[subevent] and self.LogDebug then
    self:LogDebug(subevent, spellID, spellName, sourceGUID, destGUID, npcID)
  end

  if subevent == "SPELL_SUMMON" then
    if IsMine(sourceGUID, sourceFlags) then
      local handledSummon = false
      if WILD_IMP_SUMMON_IDS[spellID] then
        self:HandleWildImpSummon(destGUID, npcID)
        handledSummon = true
      end

      if SUMMON_SPELLS[spellID] then
        self:HandleTrackedSummon(spellID, destGUID)
        handledSummon = true
      end

      if not handledSummon and npcID and WILD_IMP_NPC_IDS[npcID] then
        self:HandleWildImpSummon(destGUID, npcID)
        handledSummon = true
      end

      if self.debugEnabled and not handledSummon and (not npcID or not WILD_IMP_NPC_IDS[npcID]) and self.LogUntrackedSummon then
        local npcName = destName or spellName
        self:LogUntrackedSummon(npcID, npcName, spellID)
      end
    end
  elseif subevent == "SPELL_CAST_SUCCESS" then
    if spellID == IMPLOSION_SPELL_ID then
      if IsMine(sourceGUID, sourceFlags) then
        self:ClearWildImpTracking()
      end
    end
  elseif subevent == "SPELL_DAMAGE" then
    if spellID == FEL_FIREBOLT_SPELL_ID then
      self:HandleWildImpFelFirebolt(destGUID, sourceGUID)
    end
  elseif subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "UNIT_DISSIPATES" then
    if destGUID then
      self:HandleSummonedUnitDeath(destGUID)
      if npcID and WILD_IMP_NPC_IDS[npcID] then
        self:HandleWildImpDespawn(destGUID, npcID)
      end
    end
  end
end
