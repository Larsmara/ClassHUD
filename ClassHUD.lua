-- ClassHUD.lua
local ADDON_NAME = ...
local AceAddon   = LibStub("AceAddon-3.0")
local AceEvent   = LibStub("AceEvent-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceTimer   = LibStub("AceTimer-3.0")
local AceDB      = LibStub("AceDB-3.0")
local LSM        = LibStub("LibSharedMedia-3.0")

---@class ClassHUD : AceAddon, AceEvent, AceConsole, AceTimer
---@field BuildFramesForSpec fun(self:ClassHUD)  -- defined in Spells.lua
---@field UpdateAllFrames fun(self:ClassHUD)     -- defined in Spells.lua
---@field UpdateAllSpellFrames fun(self:ClassHUD)
---@field RebuildTrackedBuffFrames fun(self:ClassHUD)
---@field Layout fun(self:ClassHUD)              -- defined in Bars.lua
---@field ApplyBarSkins fun(self:ClassHUD)       -- defined in Bars.lua
---@field UpdateHP fun(self:ClassHUD)            -- defined in Bars.lua
---@field UpdatePrimaryResource fun(self:ClassHUD) -- defined in Bars.lua
---@field UpdateSpecialPower fun(self:ClassHUD)  -- defined in Classbar.lua
---@field UpdateSegmentsAdvanced fun(self:ClassHUD, ptype:number, max:number, partial:boolean)|nil
---@field UpdateEssenceSegments fun(self:ClassHUD, ptype:number)|nil
---@field UpdateRunes fun(self:ClassHUD)|nil

local ClassHUD   = AceAddon:NewAddon("ClassHUD", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
ClassHUD:SetDefaultModuleState(true)
_G.ClassHUD = ClassHUD -- explicit global bridge so split files can always find it

ClassHUDDebugLog = ClassHUDDebugLog or {}
ClassHUD.debugEnabled = ClassHUD.debugEnabled or false
ClassHUD._loggedUntrackedSummons = ClassHUD._loggedUntrackedSummons or {}
ClassHUD._pendingProfileSeeds = ClassHUD._pendingProfileSeeds or {}

local MAX_DEBUG_LOG_ENTRIES = 2000

local function GetNpcIDFromGUID(guid)
  if not guid then return nil end
  local _, _, _, _, _, npcID = strsplit("-", guid)
  if npcID then
    return tonumber(npcID)
  end
  return nil
end

function ClassHUD:GetNpcIDFromGUID(guid)
  return GetNpcIDFromGUID(guid)
end

---Resolves the active spellID for the provided spell by checking base and override mappings.
---@param spellID number|string|nil
---@return number|nil
function ClassHUD:GetActiveSpellID(spellID)
  if spellID == nil then
    return nil
  end

  local numericID = tonumber(spellID) or spellID
  if not numericID then
    return nil
  end

  if FindBaseSpellByID then
    local ok, baseID = pcall(FindBaseSpellByID, numericID)
    if ok and baseID and baseID > 0 then
      numericID = baseID
    end
  end

  if FindSpellOverrideByID then
    local ok, overrideID = pcall(FindSpellOverrideByID, numericID)
    if ok and overrideID and overrideID > 0 then
      numericID = overrideID
    end
  end

  if C_Spell and C_Spell.GetOverrideSpell then
    local ok, overrideID = pcall(C_Spell.GetOverrideSpell, numericID)
    if ok and overrideID and overrideID > 0 and overrideID ~= numericID then
      numericID = overrideID
    end
  end

  return numericID
end

---@param baseID number|nil
---@return number|nil
function ClassHUD:GetPermanentOverrideID(baseID)
  local resolvedBase = tonumber(baseID)
  if not resolvedBase or resolvedBase <= 0 then
    return nil
  end

  if not FindSpellOverrideByID then
    return nil
  end

  local ok, overrideID = pcall(FindSpellOverrideByID, resolvedBase)
  if ok and overrideID and overrideID > 0 and overrideID ~= resolvedBase then
    return overrideID
  end

  return nil
end

---@param baseID number|nil
---@return boolean
function ClassHUD:HasTemporaryOverride(baseID)
  local resolvedBase = tonumber(baseID)
  if not resolvedBase or resolvedBase <= 0 then
    return false
  end

  local permanent = self:GetPermanentOverrideID(resolvedBase)
  if C_Spell and C_Spell.GetOverrideSpell then
    local ok, overrideID = pcall(C_Spell.GetOverrideSpell, resolvedBase)
    if ok and overrideID and overrideID > 0 and overrideID ~= resolvedBase and overrideID ~= permanent then
      return true
    end
  end

  return false
end

local function FormatLogValue(value)
  if value == nil or value == "" then
    return "-"
  end
  return tostring(value)
end

function ClassHUD:LogDebug(subevent, spellID, spellName, sourceGUID, destGUID, npcID)
  if not self.debugEnabled then
    return
  end

  if not ClassHUDDebugLog then
    ClassHUDDebugLog = {}
  end

  local line = string.format(
    "%s %s spellID=%s name=%s src=%s dst=%s npc=%s",
    date("%H:%M:%S"),
    FormatLogValue(subevent),
    FormatLogValue(spellID),
    FormatLogValue(spellName),
    FormatLogValue(sourceGUID),
    FormatLogValue(destGUID),
    FormatLogValue(npcID)
  )

  ClassHUDDebugLog[#ClassHUDDebugLog + 1] = line

  local overflow = #ClassHUDDebugLog - MAX_DEBUG_LOG_ENTRIES
  if overflow > 0 then
    for _ = 1, overflow do
      table.remove(ClassHUDDebugLog, 1)
    end
  end
end

function ClassHUD:LogUntrackedSummon(npcID, npcName, spellID)
  if not self.debugEnabled then
    return
  end

  self._loggedUntrackedSummons = self._loggedUntrackedSummons or {}

  local key = string.format("%s:%s", FormatLogValue(npcID), FormatLogValue(npcName))
  if self._loggedUntrackedSummons[key] then
    return
  end
  self._loggedUntrackedSummons[key] = true

  local message = string.format(
    "[ClassHUD Debug] Untracked summon: npcID=%s, name=%s, spellID=%s",
    FormatLogValue(npcID),
    FormatLogValue(npcName),
    FormatLogValue(spellID)
  )

  if self.Print then
    self:Print(message)
  else
    print(message)
  end

  self:LogDebug("UNTRACKED_SUMMON", spellID, npcName, nil, nil, npcID)
end

-- Make shared libs available to submodules
ClassHUD.LSM = LSM
ClassHUD._flushTimer = nil
ClassHUD._pending = {
  any = false,
  aura = false,
  cooldown = false,
  resource = false,
  target = false,
}
ClassHUD._framesByConcern = ClassHUD._framesByConcern or {
  aura = ClassHUD._framesByConcern and ClassHUD._framesByConcern.aura or {},
  cooldown = ClassHUD._framesByConcern and ClassHUD._framesByConcern.cooldown or {},
  range = ClassHUD._framesByConcern and ClassHUD._framesByConcern.range or {},
  resource = ClassHUD._framesByConcern and ClassHUD._framesByConcern.resource or {},
}
ClassHUD._framesByConcern.cooldown = ClassHUD._framesByConcern.cooldown or {}
ClassHUD._framesByConcern.range = ClassHUD._framesByConcern.range or {}
ClassHUD._framesByConcern.resource = ClassHUD._framesByConcern.resource or {}
ClassHUD._framesByConcern.aura = ClassHUD._framesByConcern.aura or {}
ClassHUD._trackedAuraIDs = ClassHUD._trackedAuraIDs or {}
ClassHUD._trackedLayoutSnapshot = ClassHUD._trackedLayoutSnapshot or nil
ClassHUD._barTickerToken = ClassHUD._barTickerToken or nil
ClassHUD._cooldownTextFrames = ClassHUD._cooldownTextFrames or {}
ClassHUD._cooldownTickerToken = ClassHUD._cooldownTickerToken or nil
ClassHUD._auraWatchersBySpellID = ClassHUD._auraWatchersBySpellID or {}
ClassHUD._auraWatchersByUnit = ClassHUD._auraWatchersByUnit or {
  player = {},
  target = {},
  focus = {},
  pet = {},
}
ClassHUD._pendingAuraFrames = ClassHUD._pendingAuraFrames or {}
ClassHUD._auraFlushTimer = ClassHUD._auraFlushTimer or nil

local BUFF_LINK_HELPFUL_UNITS = { "player", "pet" }
local BUFF_LINK_HARMFUL_UNITS = { "target", "focus", "mouseover" }

---Normalizes a spec's buff link table so each buff maps to spell metadata.
---@param specLinks table|nil
---@return table|nil
function ClassHUD:NormalizeBuffLinkTable(specLinks)
  if type(specLinks) ~= "table" then
    return nil
  end

  local normalized = {}

  for buffKey, value in pairs(specLinks) do
    local buffID = tonumber(buffKey) or buffKey
    if buffID then
      local entry = normalized[buffID]
      if not entry then
        entry = { spells = {}, perSpell = {} }
        normalized[buffID] = entry
      end

      local spells = entry.spells
      local perSpell = entry.perSpell

      if type(value) == "table" then
        local sourceSpells = value.spells
        local sourcePerSpell = value.perSpell

        if type(sourceSpells) == "table" then
          for spellKey, enabled in pairs(sourceSpells) do
            if enabled then
              local spellID = tonumber(spellKey) or spellKey
              if spellID then
                spells[spellID] = true
              end
            end
          end
        end

        if type(sourcePerSpell) == "table" then
          for spellKey, config in pairs(sourcePerSpell) do
            local spellID = tonumber(spellKey) or spellKey
            if spellID then
              local target = perSpell[spellID]
              if type(config) == "table" then
                target = target or {}
                if type(config.order) == "number" then
                  target.order = math.floor(config.order + 0.5)
                end
                if config.swapIcon ~= nil then
                  target.swapIcon = config.swapIcon == true
                end
                perSpell[spellID] = target
              elseif config == true then
                target = target or {}
                perSpell[spellID] = target
              end
            end
          end
        end

        for spellKey, enabled in pairs(value) do
          if spellKey ~= "spells" and spellKey ~= "perSpell" and enabled then
            local spellID = tonumber(spellKey) or spellKey
            if spellID then
              spells[spellID] = true
            end
          end
        end
      else
        local spellID = tonumber(value) or value
        if spellID then
          spells[spellID] = true
        end
      end
    end
  end

  wipe(specLinks)

  for buffID, entry in pairs(normalized) do
    local spells = entry.spells
    if type(spells) == "table" then
      for spellID in pairs(entry.perSpell) do
        if not spells[spellID] then
          entry.perSpell[spellID] = nil
        end
      end
      if next(spells) then
        specLinks[buffID] = entry
      end
    end
  end

  return specLinks
end

---Collects all buff spell IDs linked to the provided spell for the current spec.
---@param spellID number
---@param reuse table|nil Optional table to reuse for output
---@param reuseMeta table|nil Optional table to reuse for metadata output
---@return table list, table meta
function ClassHUD:GetLinkedBuffIDsForSpell(spellID, reuse, reuseMeta)
  local list = reuse
  if type(list) ~= "table" then
    list = {}
  else
    wipe(list)
  end

  local meta = reuseMeta
  if type(meta) ~= "table" then
    meta = { _ordered = {} }
  else
    for key in pairs(meta) do
      if key ~= "_ordered" then
        meta[key] = nil
      end
    end
    if type(meta._ordered) == "table" then
      wipe(meta._ordered)
    else
      meta._ordered = {}
    end
  end

  if not spellID then
    return list, meta
  end

  local db = self.db
  local profile = db and db.profile
  if not profile then
    return list, meta
  end

  local class, specID = self:GetPlayerClassSpec()
  if not class or not specID or specID == 0 then
    return list, meta
  end

  local tracking = profile.tracking
  local linkRoot = tracking and tracking.buffs and tracking.buffs.links
  local specLinks = linkRoot and linkRoot[class] and linkRoot[class][specID]
  if type(specLinks) ~= "table" then
    return list, meta
  end

  self:NormalizeBuffLinkTable(specLinks)

  local normalizedSpellID = tonumber(spellID) or spellID
  if not normalizedSpellID then
    return list, meta
  end

  local ordered = meta._ordered

  for buffID, entry in pairs(specLinks) do
    if type(entry) == "table" then
      local spells = entry.spells
      if type(spells) == "table" then
        local hasLink = spells[normalizedSpellID]
        if not hasLink and spells[tostring(normalizedSpellID)] then
          spells[normalizedSpellID] = true
          spells[tostring(normalizedSpellID)] = nil
          hasLink = true
        end

        if hasLink then
          local config = nil
          if type(entry.perSpell) == "table" then
            config = entry.perSpell[normalizedSpellID] or entry.perSpell[tostring(normalizedSpellID)]
          end

          local item = ordered[#ordered + 1]
          if not item then
            item = {}
            ordered[#ordered + 1] = item
          end

          item.buffID = buffID
          local orderValue = config and tonumber(config.order)
          if orderValue then
            orderValue = math.max(1, math.min(50, math.floor(orderValue + 0.5)))
          else
            orderValue = 0
          end
          item.order = orderValue
          item.swapIcon = config and config.swapIcon == true
        end
      end
    end
  end

  table.sort(ordered, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    local aID = tonumber(a.buffID) or a.buffID
    local bID = tonumber(b.buffID) or b.buffID
    return aID < bID
  end)

  for index = 1, #ordered do
    local item = ordered[index]
    list[index] = item.buffID
    meta[item.buffID] = item
  end

  return list, meta
end

local function RestoreBuffLinkCount(frame)
  if not frame then return end

  if frame._linkedBuffCountActive then
    local cache = frame._last
    local restoreText = frame._linkedBuffRestoreText
    local restoreShown = frame._linkedBuffRestoreShown

    if frame.count then
      if restoreShown then
        frame.count:SetText(restoreText or "")
        frame.count:Show()
      else
        frame.count:SetText(restoreText or "")
        frame.count:Hide()
      end
    elseif frame.cooldownText then
      if restoreShown then
        frame.cooldownText:SetText(restoreText or "")
        frame.cooldownText:Show()
      else
        frame.cooldownText:SetText("")
        frame.cooldownText:Hide()
      end
    end

    if cache then
      cache.countText = restoreText
      cache.countShown = restoreShown or false
    end

    frame._linkedBuffCountActive = false
    frame._linkedBuffRestoreText = nil
    frame._linkedBuffRestoreShown = nil
  end
end

---Evaluates linked buff state for a spell and applies any visual overlays/counts.
---@param frame table
---@param spellID number
---@return boolean active, number|nil charges, table linkedBuffIDs
function ClassHUD:EvaluateBuffLinks(frame, spellID)
  local list, meta = self:GetLinkedBuffIDsForSpell(spellID, frame and frame._linkedBuffIDs, frame and frame._linkedBuffMeta)
  if frame then
    frame._linkedBuffIDs = list
    frame._linkedBuffMeta = meta
    frame._linkedBuffSwapIconID = nil
  end

  local cache
  if frame then
    cache = frame._last or {}
    frame._last = cache
    frame._linkedBuffRestoreText = cache.countText
    frame._linkedBuffRestoreShown = cache.countShown
  else
    cache = {}
  end

  if not frame or not spellID or #list == 0 then
    if frame then
      frame._linkedBuffActive = false
      frame._linkedBuffCount = nil
      RestoreBuffLinkCount(frame)
      frame._linkedBuffRestoreText = cache.countText
      frame._linkedBuffRestoreShown = cache.countShown
    end
    return false, nil, list
  end

  local anyActive = false
  local highestCount = nil

  local swapIconID = nil

  for i = 1, #list do
    local buffID = list[i]
    local normalizedBuffID = self:GetActiveSpellID(buffID) or buffID
    local isHarmful = false
    if C_Spell and C_Spell.IsSpellHarmful then
      local ok, harmfulFlag = pcall(C_Spell.IsSpellHarmful, normalizedBuffID)
      if ok and harmfulFlag then
        isHarmful = true
      end
    end
    local units = isHarmful and BUFF_LINK_HARMFUL_UNITS or BUFF_LINK_HELPFUL_UNITS
    local aura = self:GetAuraForSpell(normalizedBuffID, units)
    if not aura and isHarmful then
      aura = self:FindAuraByName(normalizedBuffID, BUFF_LINK_HARMFUL_UNITS)
    end

    if aura then
      anyActive = true
      local stackCount = aura.charges or aura.applications or aura.stackCount or aura.points or aura.comboPoints
      if stackCount and stackCount > 0 then
        if not highestCount or stackCount > highestCount then
          highestCount = stackCount
        end
      end

      if not swapIconID then
        local info = meta and meta[buffID]
        if info and info.swapIcon then
          swapIconID = aura.icon
          if not swapIconID and C_Spell and C_Spell.GetSpellInfo then
            local spellInfo = C_Spell.GetSpellInfo(normalizedBuffID)
            swapIconID = spellInfo and spellInfo.iconID or swapIconID
          end
        end
      end
    end
  end

  frame._linkedBuffActive = anyActive
  frame._linkedBuffCount = highestCount

  if not anyActive then
    RestoreBuffLinkCount(frame)
  end

  if anyActive and highestCount and highestCount > 0 then
    local countText = tostring(highestCount)
    if frame.count then
      frame.count:SetText(countText)
      frame.count:Show()
    elseif frame.cooldownText then
      frame.cooldownText:SetText(countText)
      frame.cooldownText:Show()
    end

    cache.countText = countText
    cache.countShown = true
    frame._linkedBuffCountActive = true
  elseif anyActive then
    -- Buff active but no stack information; preserve previous count state.
    frame._linkedBuffCountActive = false
  else
    frame._linkedBuffCountActive = false
  end

  if not anyActive then
    frame._linkedBuffRestoreText = nil
    frame._linkedBuffRestoreShown = nil
  end

  if frame then
    frame._linkedBuffSwapIconID = swapIconID
  end

  return anyActive, highestCount, list
end

function ClassHUD:RequestUpdate(kind)
  kind = kind or "any"
  if not self._pending then
    self._pending = {
      any = false,
      aura = false,
      cooldown = false,
      resource = false,
      target = false,
    }
  end

  self._pending[kind] = true

  if not self._flushTimer then
    self._flushTimer = self:ScheduleTimer("FlushUpdates", 0.05)
  end
end

function ClassHUD:FlushUpdates()
  local handle = self._flushTimer
  self._flushTimer = nil
  if handle then
    self:CancelTimer(handle)
  end

  local pending = self._pending
  if not pending then return end

  local runSpellUpdate = pending.any or pending.cooldown or pending.resource or pending.target or pending.aura
  local runBuffRebuild = pending.any or pending.aura

  local spellHandled = false
  local buffHandled = false

  if runSpellUpdate and self.UpdateAllSpellFrames then
    if pending.any then
      self:UpdateAllSpellFrames()
    else
      local concernFlags = {}
      if pending.cooldown then concernFlags.cooldown = true end
      if pending.resource then concernFlags.resource = true end
      if pending.target then
        concernFlags.range = true
        concernFlags.aura = true
      end
      if pending.aura then
        concernFlags.aura = true
      end

      local ordered = { "cooldown", "resource", "aura", "range" }
      local list = {}
      for _, key in ipairs(ordered) do
        if concernFlags[key] then
          list[#list + 1] = key
        end
      end

      if #list == 1 then
        self:UpdateAllSpellFrames(list[1])
      elseif #list > 1 then
        self:UpdateAllSpellFrames(list)
      end
    end
    spellHandled = true
  end

  if runBuffRebuild and self.RebuildTrackedBuffFrames then
    self:RebuildTrackedBuffFrames()
    buffHandled = true
  end

  if self.UpdateAllFrames then
    if (runSpellUpdate and not spellHandled) or (runBuffRebuild and not buffHandled) then
      self:UpdateAllFrames()
    end
  end

  wipe(pending)
  pending.any = false
  pending.aura = false
  pending.cooldown = false
  pending.resource = false
  pending.target = false
end

local function ExtractSpellIDFromAuraPayload(auraInfo)
  if type(auraInfo) == "number" then
    return auraInfo
  end
  if type(auraInfo) == "table" then
    local spellID = auraInfo.spellId or auraInfo.spellID or auraInfo.spell or auraInfo.id
    if type(spellID) == "number" then
      return spellID
    end
  end
  return nil
end

local function PayloadContainsTrackedAura(self, unit, list)
  if type(list) ~= "table" then
    return false
  end

  local spellWatchers = self._auraWatchersBySpellID
  local unitWatchers = self._auraWatchersByUnit and self._auraWatchersByUnit[unit]
  if not spellWatchers or not unitWatchers or not next(unitWatchers) then
    return false
  end

  local function HasRelevantWatchers(spellID)
    local watchers = spellWatchers[spellID]
    if not watchers then return false end
    for frame in pairs(watchers) do
      if unitWatchers[frame] then
        return true
      end
    end
    return false
  end

  local iterated = false
  for _, auraInfo in ipairs(list) do
    iterated = true
    local spellID = ExtractSpellIDFromAuraPayload(auraInfo)
    if spellID and HasRelevantWatchers(spellID) then
      return true
    end
  end

  if iterated then
    return false
  end

  for _, auraInfo in pairs(list) do
    local spellID = ExtractSpellIDFromAuraPayload(auraInfo)
    if spellID and HasRelevantWatchers(spellID) then
      return true
    end
  end

  return false
end

local function AuraUpdateListHasEntries(list)
  if type(list) ~= "table" then
    return false
  end

  return next(list) ~= nil
end

function ClassHUD:ShouldProcessAuraUpdate(unit, updateInfo)
  local unitWatchers = self._auraWatchersByUnit and self._auraWatchersByUnit[unit]
  if not unitWatchers or not next(unitWatchers) then
    return false
  end

  if type(updateInfo) ~= "table" then
    return true -- legacy payload, always rebuild
  end

  if updateInfo.isFullUpdate then
    return true
  end

  if PayloadContainsTrackedAura(self, unit, updateInfo.addedAuras)
      or PayloadContainsTrackedAura(self, unit, updateInfo.addedAuraSpellIDs) then
    return true
  end

  if PayloadContainsTrackedAura(self, unit, updateInfo.updatedAuras)
      or PayloadContainsTrackedAura(self, unit, updateInfo.updatedAuraSpellIDs) then
    return true
  end

  local removedList = updateInfo.removedAuras
      or updateInfo.removedAuraSpellIDs
      or updateInfo.removedSpellIDs

  if PayloadContainsTrackedAura(self, unit, removedList) then
    return true
  end

  if AuraUpdateListHasEntries(updateInfo.removedAuraInstanceIDs)
      or AuraUpdateListHasEntries(updateInfo.updatedAuraInstanceIDs) then
    return true
  end

  return false
end

local BAR_TICK_INTERVAL = 0.10
local COOLDOWN_TICK_INTERVAL = 0.10

local function CancelTicker(self, field)
  local token = self[field]
  if token then
    self:CancelTimer(token)
    self[field] = nil
  end
end

local function EnsureTicker(self, field, method, interval, registry)
  if not next(registry) then
    CancelTicker(self, field)
    return
  end

  if not self[field] then
    self[field] = self:ScheduleRepeatingTimer(method, interval)
  end
end

function ClassHUD:RegisterCooldownTextFrame(frame)
  if not frame or not frame.cooldownText then return end

  self._cooldownTextFrames = self._cooldownTextFrames or {}
  self._cooldownTextFrames[frame] = true

  EnsureTicker(self, "_cooldownTickerToken", "TickCooldownText", COOLDOWN_TICK_INTERVAL, self._cooldownTextFrames)
end

function ClassHUD:UnregisterCooldownTextFrame(frame)
  local frames = self._cooldownTextFrames
  if not frames then return end

  frames[frame] = nil

  EnsureTicker(self, "_cooldownTickerToken", "TickCooldownText", COOLDOWN_TICK_INTERVAL, frames)
end

function ClassHUD:ApplyCooldownText(frame, remaining)
  if not frame or not frame.cooldownText then return end

  local cache = frame._last
  if not cache then
    cache = {}
    frame._last = cache
  end

  local showNumbers = true
  if self.ShouldShowCooldownNumbers then
    showNumbers = self:ShouldShowCooldownNumbers()
  end

  if frame._gcdActive then
    if cache.cooldownTextShown then
      frame.cooldownText:Hide()
      cache.cooldownTextShown = false
    end
    if cache.cooldownTextValue then
      frame.cooldownText:SetText("")
      cache.cooldownTextValue = nil
    end
    self:UnregisterCooldownTextFrame(frame)
    return
  end

  if not showNumbers then
    if cache.cooldownTextShown then
      frame.cooldownText:Hide()
      cache.cooldownTextShown = false
    end
    if cache.cooldownTextValue then
      frame.cooldownText:SetText("")
      cache.cooldownTextValue = nil
    end
    self:UnregisterCooldownTextFrame(frame)
    return
  end

  if remaining and remaining > 0 then
    local formatted = ClassHUD.FormatSeconds(remaining)
    if cache.cooldownTextValue ~= formatted then
      frame.cooldownText:SetText(formatted or "")
      cache.cooldownTextValue = formatted
    end
    if not cache.cooldownTextShown then
      frame.cooldownText:Show()
      cache.cooldownTextShown = true
    end
    self:RegisterCooldownTextFrame(frame)
  else
    if cache.cooldownTextShown then
      frame.cooldownText:Hide()
      cache.cooldownTextShown = false
    end
    if cache.cooldownTextValue then
      frame.cooldownText:SetText("")
      cache.cooldownTextValue = nil
    end
    self:UnregisterCooldownTextFrame(frame)
  end
end

function ClassHUD:TickCooldownText()
  local frames = self._cooldownTextFrames
  if not frames or not next(frames) then
    EnsureTicker(self, "_cooldownTickerToken", "TickCooldownText", COOLDOWN_TICK_INTERVAL, frames or {})
    return
  end

  local showNumbers = true
  if self.ShouldShowCooldownNumbers then
    showNumbers = self:ShouldShowCooldownNumbers()
  end

  if not showNumbers then
    for frame in pairs(frames) do
      frames[frame] = nil
      if frame and frame.cooldownText then
        frame.cooldownText:SetText("")
        frame.cooldownText:Hide()
        if frame._last then
          frame._last.cooldownTextShown = false
          frame._last.cooldownTextValue = nil
        end
      end
    end
    EnsureTicker(self, "_cooldownTickerToken", "TickCooldownText", COOLDOWN_TICK_INTERVAL, frames)
    return
  end

  local now = GetTime()

  for frame in pairs(frames) do
    local keep = false

    if frame and frame.cooldownText then
      local cache = frame._last
      if cache and cache.hasCooldown and cache.cooldownEnd then
        local remaining = cache.cooldownEnd - now
        if remaining > 0 then
          local formatted = ClassHUD.FormatSeconds(remaining)
          if cache.cooldownTextValue ~= formatted then
            frame.cooldownText:SetText(formatted or "")
            cache.cooldownTextValue = formatted
          end
          if not cache.cooldownTextShown then
            frame.cooldownText:Show()
            cache.cooldownTextShown = true
          end
          keep = true
        end
      end

      if not keep then
        if frame.cooldownText:GetText() ~= "" then
          frame.cooldownText:SetText("")
        end
        frame.cooldownText:Hide()
        if frame._last then
          frame._last.cooldownTextValue = nil
          frame._last.cooldownTextShown = false
        end
      end
    end

    if not keep then
      frames[frame] = nil
    end
  end

  EnsureTicker(self, "_cooldownTickerToken", "TickCooldownText", COOLDOWN_TICK_INTERVAL, frames)
end

---@class ClassHUDUI
---@field anchor Frame|nil
---@field cast StatusBar|nil
---@field hp StatusBar|nil
---@field resource StatusBar|nil
---@field power Frame|nil
---@field powerSegments StatusBar[]
---@field runeBars StatusBar[]
---@field icons Frame|nil
---@field iconFrames Frame[]
---@field attachments table<string, Frame>
ClassHUD.UI = {
  anchor        = nil,
  cast          = nil,
  hp            = nil,
  resource      = nil,
  power         = nil,
  powerSegments = {},
  runeBars      = {},
  icons         = nil,
  iconFrames    = {},
  attachments   = {},
}

-- Class color (for HP)
function ClassHUD:GetClassColor()
  local _, class = UnitClass("player")
  local c = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
  return c.r, c.g, c.b
end

-- Blizzard power colors
local TOKEN_BY_ID = {
  [Enum.PowerType.Mana]          = "MANA",
  [Enum.PowerType.Rage]          = "RAGE",
  [Enum.PowerType.Focus]         = "FOCUS",
  [Enum.PowerType.Energy]        = "ENERGY",
  [Enum.PowerType.ComboPoints]   = "COMBO_POINTS",
  [Enum.PowerType.Runes]         = "RUNES",
  [Enum.PowerType.RunicPower]    = "RUNIC_POWER",
  [Enum.PowerType.SoulShards]    = "SOUL_SHARDS",
  [Enum.PowerType.LunarPower]    = "LUNAR_POWER",
  [Enum.PowerType.HolyPower]     = "HOLY_POWER",
  [Enum.PowerType.Maelstrom]     = "MAELSTROM",
  [Enum.PowerType.Chi]           = "CHI",
  [Enum.PowerType.Insanity]      = "INSANITY",
  [Enum.PowerType.ArcaneCharges] = "ARCANE_CHARGES",
  [Enum.PowerType.Fury]          = "FURY",
  [Enum.PowerType.Pain]          = "PAIN",
  [Enum.PowerType.Essence]       = "ESSENCE",
}

function ClassHUD:PowerColorBy(id, token)
  token = token or TOKEN_BY_ID[id]
  local c = (token and PowerBarColor[token]) or PowerBarColor[id]
  if c then return c.r, c.g, c.b end
  return 0.2, 0.6, 1.0 -- sensible fallback
end

-- ---------------------------------------------------------------------------
-- Defaults & DB
-- ---------------------------------------------------------------------------
local defaults = {
  profile = {
    locked        = false,
    position      = { x = 0, y = -50 },
    width         = 250,
    spacing       = 2,
    powerSpacing  = 2,
    textures      = {
      bar  = "Blizzard",
      font = "Friz Quadrata TT",
    },
    colors        = {
      border        = { r = 0, g = 0, b = 0, a = 1 },
      hp            = { r = 0.10, g = 0.80, b = 0.10 },
      resourceClass = true,
      resource      = { r = 0.00, g = 0.55, b = 1.00 },
      power         = { r = 1.00, g = 0.85, b = 0.10 },
    },
    layout        = {
      barOrder = { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" },
      show = {
        cast     = true,
        hp       = true,
        resource = true,
        power    = true,
        buffs    = true,
      },
      height = {
        cast     = 18,
        hp       = 14,
        resource = 14,
        power    = 14,
      },
      sideBars = {
        size    = 36,
        spacing = 4,
        offset  = 6,
        spells  = {},
      },
      utility = {
        spells = {},
      },
      classbars = {
        DRUID = {
          [102] = { eclipse = true, combo = false },
          [103] = { combo = true },
          [104] = { combo = true },
          [105] = { combo = true },
        },
        ROGUE = {
          [259] = { combo = true },
          [260] = { combo = true },
          [261] = { combo = true },
        },
      },
      topBar = {
        perRow            = 8,
        spacingX          = 4,
        spacingY          = 4,
        yOffset           = 0,
        grow              = "UP",
        pandemicHighlight = true,
        spells            = {},
        flags             = {},
      },
      bottomBar = {
        perRow   = 8,
        spacingX = 4,
        spacingY = 4,
        yOffset  = 0,
        spells   = {},
      },
      trackedBuffBar = {
        perRow   = 8,
        spacingX = 4,
        spacingY = 4,
        yOffset  = 4,
        align    = "CENTER",
        height   = 16,
        buffs    = {},
      },
      hiddenSpells = {},
    },
    tracking      = {
      summons = {
        enabled = true,
        byClass = {
          PRIEST = {
            [34433]  = true,
            [123040] = true,
          },
          WARLOCK = {
            [193332] = true,
            [264119] = true,
            [455476] = true,
            [265187] = true,
            [111898] = true,
            [205180] = true,
          },
          DEATHKNIGHT = {
            [42650] = true,
            [49206] = true,
          },
          DRUID = {
            [205636] = true,
          },
          MONK = {
            [115313] = true,
          },
        },
      },
      wildImps = {
        enabled = true,
        mode    = "implosion",
      },
      totems = {
        enabled      = true,
        overlayStyle = "SWIPE",
        showDuration = true,
      },
      buffs = {
        links   = {},
        tracked = {},
      },
    },
    cooldowns     = {
      showSwipe   = true,
      showCharges = true,
      showText    = true,
      showGCD     = false,
      timerStyle  = "Blizzard",
    },
    fontSize      = 12,
    soundAlerts   = {
      enabled = false,
    },
  },
}

local function CopyTableRecursive(tbl)
  if type(tbl) ~= "table" then return tbl end

  local copy = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      copy[k] = CopyTableRecursive(v)
    else
      copy[k] = v
    end
  end
  return copy
end

local SERIAL_PREFIX = "CHUD1"
local TYPE_ORDER = {
  boolean = 1,
  number  = 2,
  string  = 3,
}

local function SortKeys(tbl)
  local keys = {}
  for k in pairs(tbl) do
    keys[#keys + 1] = k
  end

  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta == tb then
      if ta == "number" or ta == "string" then
        return a < b
      end
      if ta == "boolean" then
        return (a and 1 or 0) < (b and 1 or 0)
      end
      return tostring(a) < tostring(b)
    end

    local wa = TYPE_ORDER[ta] or 10
    local wb = TYPE_ORDER[tb] or 10
    if wa ~= wb then
      return wa < wb
    end
    return tostring(ta) < tostring(tb)
  end)

  return keys
end

local function EscapeString(value)
  value = tostring(value or "")
  value = value:gsub("~", "~~")
  value = value:gsub("%^", "~^")
  return value
end

local function SerializeValue(value, buffer, visited)
  local t = type(value)

  if t == "table" then
    if visited[value] then
      error("Cannot serialize profile table with recursive references", 0)
    end
    visited[value] = true
    buffer[#buffer + 1] = "^T"
    local keys = SortKeys(value)
    for _, key in ipairs(keys) do
      SerializeValue(key, buffer, visited)
      SerializeValue(value[key], buffer, visited)
    end
    buffer[#buffer + 1] = "^t"
    visited[value] = nil
  elseif t == "string" then
    buffer[#buffer + 1] = "^S"
    buffer[#buffer + 1] = EscapeString(value)
    buffer[#buffer + 1] = "^s"
  elseif t == "number" then
    buffer[#buffer + 1] = "^N"
    buffer[#buffer + 1] = string.format("%.17g", value)
    buffer[#buffer + 1] = "^n"
  elseif t == "boolean" then
    buffer[#buffer + 1] = value and "^B" or "^b"
  elseif t == "nil" then
    buffer[#buffer + 1] = "^Z"
  else
    error("Unsupported value type in profile: " .. t, 0)
  end
end

local function DeserializeValue(data, index)
  if index > #data then
    return nil, index, "Unexpected end of data"
  end

  if data:sub(index, index) ~= "^" then
    return nil, index, "Invalid control sequence"
  end

  local code = data:sub(index + 1, index + 1)
  index = index + 2

  if code == "T" then
    local tbl = {}
    while index <= #data do
      if data:sub(index, index) == "^" and data:sub(index + 1, index + 1) == "t" then
        index = index + 2
        break
      end

      local key, err
      key, index, err = DeserializeValue(data, index)
      if err then
        return nil, index, err
      end

      local value
      value, index, err = DeserializeValue(data, index)
      if err then
        return nil, index, err
      end

      tbl[key] = value
    end
    return tbl, index
  elseif code == "S" then
    local buffer = {}
    while true do
      if index > #data then
        return nil, index, "Unterminated string value"
      end
      local ch = data:sub(index, index)
      if ch == "~" then
        local nextChar = data:sub(index + 1, index + 1)
        if nextChar == "" then
          return nil, index, "Bad escape sequence"
        end
        buffer[#buffer + 1] = nextChar
        index = index + 2
      elseif ch == "^" and data:sub(index + 1, index + 1) == "s" then
        index = index + 2
        break
      else
        buffer[#buffer + 1] = ch
        index = index + 1
      end
    end
    return table.concat(buffer), index
  elseif code == "N" then
    local endPos = data:find("%^n", index, true)
    if not endPos then
      return nil, index, "Unterminated number value"
    end
    local numStr = data:sub(index, endPos - 1)
    local value = tonumber(numStr)
    if not value then
      return nil, endPos + 2, "Invalid number value"
    end
    index = endPos + 2
    return value, index
  elseif code == "B" then
    return true, index
  elseif code == "b" then
    return false, index
  elseif code == "Z" then
    return nil, index
  elseif code == "t" then
    return nil, index, "Unexpected table terminator"
  else
    return nil, index, "Unknown control code '" .. tostring(code) .. "'"
  end
end

local function OverwriteTable(target, source)
  for k in pairs(target) do
    target[k] = nil
  end
  for k, v in pairs(source) do
    if type(v) == "table" then
      target[k] = CopyTableRecursive(v)
    else
      target[k] = v
    end
  end
end

function ClassHUD:SerializeCurrentProfile()
  if not (self.db and self.db.profile) then
    return nil, "No active profile"
  end

  local buffer = { SERIAL_PREFIX }
  local visited = {}
  local ok, err = pcall(SerializeValue, self.db.profile, buffer, visited)
  if not ok then
    return nil, err or "Failed to serialize profile"
  end

  return table.concat(buffer)
end

function ClassHUD:DeserializeProfileString(serialized)
  if type(serialized) ~= "string" or serialized == "" then
    return false, "Invalid profile string"
  end

  if serialized:sub(1, #SERIAL_PREFIX) ~= SERIAL_PREFIX then
    return false, "Unrecognized profile format"
  end

  local payload = serialized:sub(#SERIAL_PREFIX + 1)
  local profileTable, index, err = DeserializeValue(payload, 1)
  if err then
    return false, err
  end

  if index <= #payload then
    local remainder = payload:sub(index)
    if remainder:match("%S") then
      return false, "Extra data at end of profile string"
    end
  end

  if type(profileTable) ~= "table" then
    return false, "Profile payload is not a table"
  end

  if not (self.db and self.db.GetCurrentProfile) then
    return false, "Database not initialized"
  end

  local currentProfile = self.db:GetCurrentProfile()
  if not currentProfile or currentProfile == "" then
    return false, "No active profile"
  end

  self.db.profiles = self.db.profiles or {}
  local storage = self.db.profiles[currentProfile]
  if type(storage) ~= "table" then
    storage = {}
    self.db.profiles[currentProfile] = storage
  end

  OverwriteTable(storage, profileTable)
  self.db.profile = storage

  if self.ApplyAnchorPosition then self:ApplyAnchorPosition() end
  if self.FullUpdate then self:FullUpdate() end
  if self.BuildFramesForSpec then self:BuildFramesForSpec() end
  if self.EvaluateClassBarVisibility then self:EvaluateClassBarVisibility() end

  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then
    registry:NotifyChange("ClassHUD")
  end

  return true
end


function ClassHUD:SeedProfileFromCooldownManager()
  if not (self.db and self.db.profile) then return false end
  if not (self.IsCooldownViewerAvailable and self:IsCooldownViewerAvailable()) then return false end

  local class, specID = self:GetPlayerClassSpec()
  if not class or not specID or specID == 0 then return false end

  self:UpdateCDMSnapshot()
  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  if not snapshot or next(snapshot) == nil then return false end

  local seeded = false

  local layout = self.db.profile.layout or {}
  self.db.profile.layout = layout

  layout.topBar = layout.topBar or {}
  layout.topBar.spells = layout.topBar.spells or {}
  layout.topBar.flags = layout.topBar.flags or {}

  layout.utility = layout.utility or {}
  layout.utility.spells = layout.utility.spells or {}

  layout.bottomBar = layout.bottomBar or {}
  layout.bottomBar.spells = layout.bottomBar.spells or {}

  layout.trackedBuffBar = layout.trackedBuffBar or {}
  layout.trackedBuffBar.buffs = layout.trackedBuffBar.buffs or {}

  local function ensureSpecList(root)
    root[class] = root[class] or {}
    root[class][specID] = root[class][specID] or {}
    return root[class][specID]
  end

  local topList = ensureSpecList(layout.topBar.spells)
  local utilityList = ensureSpecList(layout.utility.spells)
  local trackedOrder = ensureSpecList(layout.trackedBuffBar.buffs)

  local function scrubList(target)
    local lookup = {}
    if type(target) ~= "table" then
      return lookup
    end

    for index = #target, 1, -1 do
      local value = tonumber(target[index]) or target[index]
      if value then
        target[index] = value
        lookup[value] = true
      else
        table.remove(target, index)
      end
    end

    return lookup
  end

  local topLookup = scrubList(topList)
  local utilityLookup = scrubList(utilityList)
  local trackedLookup = scrubList(trackedOrder)

  local function buildEntries(category)
    local entries = {}
    for spellID, entry in pairs(snapshot) do
      local cat = entry.categories and entry.categories[category]
      if cat then
        entries[#entries + 1] = {
          id    = tonumber(spellID) or spellID,
          order = tonumber(cat.order) or math.huge,
          name  = entry.name or tostring(spellID),
        }
      end
    end

    table.sort(entries, function(a, b)
      if a.order == b.order then
        return a.name < b.name
      end
      return a.order < b.order
    end)

    return entries
  end

  local function appendEntries(target, lookup, entries)
    local changed = false
    if type(target) ~= "table" then
      return changed
    end

    for _, info in ipairs(entries) do
      local id = tonumber(info.id) or info.id
      if id and not lookup[id] then
        table.insert(target, id)
        lookup[id] = true
        changed = true
      end
    end

    return changed
  end

  if appendEntries(topList, topLookup, buildEntries("essential")) then
    seeded = true
  end

  if appendEntries(utilityList, utilityLookup, buildEntries("utility")) then
    seeded = true
  end

  local trackedEntries = buildEntries("buff")

  if (#trackedEntries > 0) then
    self.db.profile.tracking = self.db.profile.tracking or {}
    local tracking = self.db.profile.tracking
    tracking.buffs = tracking.buffs or {}
    tracking.buffs.tracked = tracking.buffs.tracked or {}
    tracking.buffs.tracked[class] = tracking.buffs.tracked[class] or {}
    tracking.buffs.tracked[class][specID] = tracking.buffs.tracked[class][specID] or {}
    local trackedConfigs = tracking.buffs.tracked[class][specID]

    local function appendTracked(entries)
      local changed = false
      for _, info in ipairs(entries) do
        local id = tonumber(info.id) or info.id
        if id then
          if not trackedLookup[id] then
            table.insert(trackedOrder, id)
            trackedLookup[id] = true
            changed = true
          end
          if trackedConfigs[id] == nil then
            trackedConfigs[id] = true
            changed = true
          end
        end
      end
      return changed
    end

    local trackedChanged = appendTracked(trackedEntries)

    if trackedChanged then
      seeded = true
    end
  end

  return seeded
end

---Ensures new snapshot spells are added to DB without overwriting user choices.
function ClassHUD:SyncSnapshotToDB()
  if not self:IsCooldownViewerAvailable() then return false end

  local class, specID = self:GetPlayerClassSpec()
  if not class or not specID or specID == 0 then return false end

  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  if not snapshot or next(snapshot) == nil then return false end

  local layout = self.db.profile.layout or {}
  self.db.profile.layout = layout

  layout.topBar = layout.topBar or {}
  layout.topBar.spells = layout.topBar.spells or {}
  layout.topBar.flags = layout.topBar.flags or {}

  layout.utility = layout.utility or {}
  layout.utility.spells = layout.utility.spells or {}

  layout.trackedBuffBar = layout.trackedBuffBar or {}
  layout.trackedBuffBar.buffs = layout.trackedBuffBar.buffs or {}

  local function ensureSpecList(root)
    root[class] = root[class] or {}
    root[class][specID] = root[class][specID] or {}
    return root[class][specID]
  end

  local topList = ensureSpecList(layout.topBar.spells)
  local utilityList = ensureSpecList(layout.utility.spells)
  local trackedOrder = ensureSpecList(layout.trackedBuffBar.buffs)

  -- Hidden lookup
  local hidden = layout.hiddenSpells
      and layout.hiddenSpells[class]
      and layout.hiddenSpells[class][specID]
  local hiddenLookup = {}
  if type(hidden) == "table" then
    for _, id in ipairs(hidden) do
      hiddenLookup[id] = true
    end
  end

  -- Convert list -> lookup
  local function makeLookup(list)
    local lookup = {}
    if type(list) == "table" then
      for _, id in ipairs(list) do
        local normalized = tonumber(id) or id
        if normalized ~= nil then
          lookup[normalized] = true
        end
      end
    end
    return lookup
  end

  local topLookup = makeLookup(topList)
  local utilityLookup = makeLookup(utilityList)
  local trackedLookup = makeLookup(trackedOrder)

  local function appendEntries(target, lookup, entries)
    local changed = false
    for _, info in ipairs(entries) do
      local id = tonumber(info.id) or info.id
      if id and not lookup[id] and not hiddenLookup[id] then
        table.insert(target, id)
        lookup[id] = true
        changed = true
      end
    end
    return changed
  end

  -- Build snapshot category lists
  local function buildCategorizedEntries()
    local categorized = {
      essential = {},
      utility = {},
      buff = {},
    }

    local relevant = { essential = true, utility = true, buff = true }

    for spellID, entry in pairs(snapshot) do
      if entry and entry.categories then
        for category, catData in pairs(entry.categories) do
          if relevant[category] then
            local normalizedID = tonumber(spellID) or spellID
            if normalizedID then
              local orderValue = math.huge
              if type(catData) == "table" and catData.order ~= nil then
                orderValue = tonumber(catData.order) or math.huge
              end

              local bucket = categorized[category]
              bucket[#bucket + 1] = {
                id = normalizedID,
                order = orderValue,
                name = entry.name or tostring(normalizedID),
              }
            end
          end
        end
      end
    end

    local function sortEntries(list)
      table.sort(list, function(a, b)
        if a.order == b.order then
          return a.name < b.name
        end
        return a.order < b.order
      end)
    end

    for _, list in pairs(categorized) do
      sortEntries(list)
    end

    return categorized
  end

  local categorized = buildCategorizedEntries()

  local changed = false
  if appendEntries(topList, topLookup, categorized.essential) then
    changed = true
  end
  if appendEntries(utilityList, utilityLookup, categorized.utility) then
    changed = true
  end

  -- Tracked buffs
  local trackedEntries = categorized.buff or {}
  if #trackedEntries > 0 then
    self.db.profile.tracking = self.db.profile.tracking or {}
    local tracking = self.db.profile.tracking
    tracking.buffs = tracking.buffs or {}
    tracking.buffs.tracked = tracking.buffs.tracked or {}
    tracking.buffs.tracked[class] = tracking.buffs.tracked[class] or {}
    tracking.buffs.tracked[class][specID] = tracking.buffs.tracked[class][specID] or {}
    local trackedConfigs = tracking.buffs.tracked[class][specID]

    for _, info in ipairs(trackedEntries) do
      local id = tonumber(info.id) or info.id
      if id and not trackedLookup[id] and not hiddenLookup[id] then
        table.insert(trackedOrder, id)
        trackedLookup[id] = true
        if trackedConfigs[id] == nil then
          trackedConfigs[id] = true
        end
        changed = true
      end
    end
  end

  return changed
end

---Manually updates the snapshot from Cooldown Manager and merges new entries into the DB.
---@return boolean changed True if new spells or buffs were added to the profile.
function ClassHUD:RescanFromCDM()
  if not (self.IsCooldownViewerAvailable and self:IsCooldownViewerAvailable()) then
    print("|cff00ff88ClassHUD|r Cooldown Manager is not available on this client.")
    return false
  end

  self:UpdateCDMSnapshot()

  local changed = self:SyncSnapshotToDB()
  if not changed then
    print("|cff00ff88ClassHUD|r No new spells were found in the Cooldown Manager snapshot.")
    return false
  end

  if self.BuildFramesForSpec then self:BuildFramesForSpec() end
  if self.BuildTrackedBuffFrames then self:BuildTrackedBuffFrames() end
  if self.RefreshRegisteredOptions then self:RefreshRegisteredOptions() end
  if self.UpdateAllFrames then self:UpdateAllFrames() end
  if self.RefreshSpellFrameVisibility then self:RefreshSpellFrameVisibility() end
  if self.RefreshAllTotems then self:RefreshAllTotems() end

  print("|cff00ff88ClassHUD|r Imported new spells from the Cooldown Manager snapshot.")
  return true
end

function ClassHUD:TrySeedPendingProfile()
  if not (self.db and self.db.GetCurrentProfile) then return false end

  local profileName = self.db:GetCurrentProfile()
  if not profileName then return false end

  if not (self._pendingProfileSeeds and self._pendingProfileSeeds[profileName]) then
    return false
  end

  local seeded = self:SeedProfileFromCooldownManager()
  if seeded then
    self._pendingProfileSeeds[profileName] = nil
  end

  return seeded
end

function ClassHUD:FetchStatusbar()
  return self.LSM:Fetch("statusbar", self.db.profile.textures.bar)
      or "Interface\\TargetingFrame\\UI-StatusBar"
end

function ClassHUD:FetchFont(size, flags)
  local path = self.LSM:Fetch("font", self.db.profile.textures.font) or STANDARD_TEXT_FONT
  local resolvedSize = size or (self.db and self.db.profile and self.db.profile.fontSize) or 12
  return path, resolvedSize, flags or "OUTLINE"
end

function ClassHUD:GetActiveSpecProfileName()
  local specIndex = GetSpecialization and GetSpecialization()
  if specIndex and specIndex > 0 and GetSpecializationInfo then
    local _, specName = GetSpecializationInfo(specIndex)
    if specName and specName ~= "" then
      return string.format("ClassHUD-%s", specName)
    end
  end

  local _, className = UnitClass and UnitClass("player") or nil
  className = className or "Default"
  return string.format("ClassHUD-%s", className)
end

function ClassHUD:EnsureActiveSpecProfile()
  if not (self.db and self.db.GetCurrentProfile) then return end

  local desiredProfile = self:GetActiveSpecProfileName()
  if not desiredProfile then return end

  self.db.profiles = self.db.profiles or {}
  self._pendingProfileSeeds = self._pendingProfileSeeds or {}

  if not self.db.profiles[desiredProfile] then
    self.db.profiles[desiredProfile] = CopyTableRecursive(defaults.profile)
    self._pendingProfileSeeds[desiredProfile] = true
  end

  local currentProfile = self.db:GetCurrentProfile()
  if currentProfile ~= desiredProfile then
    self.db:SetProfile(desiredProfile)
  end

  self:TrySeedPendingProfile()
end

function ClassHUD:OnProfileChanged()
  self:TrySeedPendingProfile()
  if self.ResetSummonTracking then self:ResetSummonTracking() end
  if self.ResetTotemTracking then self:ResetTotemTracking() end
  if self.BuildFramesForSpec then self:BuildFramesForSpec() end
  self:FullUpdate()
  self:RefreshRegisteredOptions()
end

-- ---------------------------------------------------------------------------
-- Public helpers used by modules
-- ---------------------------------------------------------------------------
function ClassHUD:ApplyAnchorPosition()
  local UI = self.UI
  if not UI.anchor then return end
  local pos = (self.db and self.db.profile and self.db.profile.position) or { x = 0, y = -350 }
  UI.anchor:ClearAllPoints()
  UI.anchor:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end

-- Exposed so Classbar can create uniform bars
function ClassHUD:CreateStatusBar(parent, height, withBorder)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetSize(self.db.profile.width or 250, height or 16)

  local edge = (self.db.profile.borderSize and math.max(1, self.db.profile.borderSize)) or 1

  if withBorder then
    holder:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = edge,
      insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local colors = self.db.profile.colors or {}
    local c = colors.border or { r = 0, g = 0, b = 0, a = 1 }
    holder:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    holder:SetBackdropColor(0, 0, 0, 0.40)
  end

  local bar = CreateFrame("StatusBar", nil, holder)
  bar:SetPoint("TOPLEFT", holder, "TOPLEFT", edge, -edge)
  bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -edge, edge)
  bar:SetStatusBarTexture(self:FetchStatusbar())
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetColorTexture(0, 0, 0, 0.55)

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont(self:FetchFont())

  bar._holder = holder
  bar._edge   = edge
  return bar
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
function ClassHUD:OnInitialize()
  self.db = AceDB:New("ClassHUDDB2", defaults, true)
  self.db.RegisterCallback(self, "OnProfileChanged")
  self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
  self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

  self:EnsureActiveSpecProfile()
end

-- Called by PLAYER_ENTERING_WORLD or when user changes options
function ClassHUD:FullUpdate()
  if self.Layout then self:Layout() end
  if self.UpdateHP then self:UpdateHP() end
  if self.UpdatePrimaryResource then self:UpdatePrimaryResource() end
  if self.EvaluateClassBarVisibility then
    self:EvaluateClassBarVisibility()
  elseif self.UpdateSpecialPower then
    self:UpdateSpecialPower()
  end
end

---Rebuilds the Cooldown Viewer snapshot for the current class/spec.
---The snapshot is the authoritative data source for layout, options and UI.
function ClassHUD:UpdateCDMSnapshot()
  if not self:IsCooldownViewerAvailable() then return end

  local class, specID = self:GetPlayerClassSpec()
  local snapshot = self:GetSnapshotForSpec(class, specID, true)
  if not snapshot then return end

  -- clear old
  for key in pairs(snapshot) do snapshot[key] = nil end

  local categories = {
    [Enum.CooldownViewerCategory.Essential]   = "essential",
    [Enum.CooldownViewerCategory.Utility]     = "utility",
    [Enum.CooldownViewerCategory.TrackedBuff] = "buff",
  }

  local orderByCategory = {}

  for cat, catName in pairs(categories) do
    local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat)
    if type(ids) == "table" then
      for _, cooldownID in ipairs(ids) do
        local raw = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        local sid = raw and (raw.spellID or raw.overrideSpellID or (raw.linkedSpellIDs and raw.linkedSpellIDs[1]))
        if sid then
          local normalizedSid = self:GetActiveSpellID(sid) or sid
          local info = C_Spell.GetSpellInfo(normalizedSid)
          local desc = C_Spell.GetSpellDescription(normalizedSid)

          local entry = snapshot[sid]
          if not entry then
            entry = {
              spellID     = sid,
              name        = info and info.name or ("Spell " .. sid),
              iconID      = info and info.iconID,
              desc        = desc,
              categories  = {},
              category    = catName,
              lastUpdated = GetServerTime and GetServerTime() or time(),
            }
            snapshot[sid] = entry
          else
            entry.name        = info and info.name or entry.name
            entry.iconID      = info and info.iconID or entry.iconID
            entry.desc        = desc or entry.desc
            entry.category    = entry.category or catName
            entry.lastUpdated = GetServerTime and GetServerTime() or time()
          end

          orderByCategory[catName] = (orderByCategory[catName] or 0) + 1
          entry.categories[catName] = {
            cooldownID      = cooldownID,
            overrideSpellID = raw.overrideSpellID,
            linkedSpellIDs  = raw.linkedSpellIDs and { unpack(raw.linkedSpellIDs) } or nil,
            hasAura         = raw.hasAura,
            order           = orderByCategory[catName],
          }
        end
      end
    end
  end

  for sid, entry in pairs(snapshot) do
    if entry then
      self:_AssembleAuraCandidates(entry, sid)
    end
  end
end

-- ===== Options bootstrap (registers with AceConfigRegistry directly) =====
function ClassHUD:RegisterOptions()
  local ACR = LibStub("AceConfigRegistry-3.0", true)
  local ACD = LibStub("AceConfigDialog-3.0", true)
  if not (ACR and ACD) then
    return false
  end

  -- Try to use the real builder from ClassHUD_Options.lua
  local builder = _G.ClassHUD_BuildOptions
  local opts

  if type(builder) == "function" then
    local ok, res = pcall(builder, self)
    if ok then
      opts = res
    end
  end

  -- If still missing, warn ONCE and install a tiny fallback so /chud works
  if not opts then
    opts = {
      type = "group",
      name = "ClassHUD (fallback)",
      args = {
        note = {
          type = "description",
          order = 1,
          name =
          "Options file not loaded.\nCheck TOC path/name and that ClassHUD_Options.lua defines:\n\nfunction ClassHUD_BuildOptions(addon) ... return opts end\n"
        },
      },
    }
  end

  self._opts = opts
  ACR:RegisterOptionsTable("ClassHUD", opts)
  ACD:AddToBlizOptions("ClassHUD", "ClassHUD")

  self._opts_registered = true
  return true
end

function ClassHUD:RefreshRegisteredOptions()
  local builder = _G.ClassHUD_BuildOptions
  if type(builder) ~= "function" then return end

  local ok, opts = pcall(builder, self)
  if not ok or not opts then return end

  self._opts = opts

  if self._opts_registered then
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR then
      ACR:RegisterOptionsTable("ClassHUD", opts)
      ACR:NotifyChange("ClassHUD")
    end
  end
end

function ClassHUD:OpenOptions()
  local ACR = LibStub("AceConfigRegistry-3.0", true)
  local ACD = LibStub("AceConfigDialog-3.0", true)
  if not (ACR and ACD) then
    return
  end
  if not ACR:GetOptionsTable("ClassHUD") then
    if not self:RegisterOptions() then return end
  end
  ACR:NotifyChange("ClassHUD")
  ACD:Open("ClassHUD")
end

-- ========= Bars/Spells bootstrap on enable =========
function ClassHUD:OnEnable()
  local UI = self.UI
  -- Create base frames
  if not UI.anchor and self.CreateAnchor then self:CreateAnchor() end
  if not UI.cast and self.CreateCastBar then self:CreateCastBar() end
  if not UI.hp and self.CreateHPBar then self:CreateHPBar() end
  if not UI.resource and self.CreateResourceBar then self:CreateResourceBar() end
  if not UI.power and self.CreatePowerContainer and self.PlayerHasClassBarSupport and self:PlayerHasClassBarSupport() then
    self:CreatePowerContainer()
  end

  if self.Layout then self:Layout() end
  if self.ApplyBarSkins then self:ApplyBarSkins() end

  -- Rebuild spells after DB exists & layout is ready
  if self.BuildFramesForSpec then
    self:BuildFramesForSpec()
  end
end

-- ========= Event wiring =========
local eventFrame = CreateFrame("Frame")

for _, ev in pairs({
  -- World/spec
  "PLAYER_ENTERING_WORLD",
  "PLAYER_SPECIALIZATION_CHANGED",
  "PLAYER_TALENT_UPDATE",
  "TRAIT_CONFIG_UPDATED",

  -- Health
  "UNIT_HEALTH", "UNIT_MAXHEALTH",

  -- Resource
  "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER", "UPDATE_SHAPESHIFT_FORM", "UNIT_POWER_POINT_CHARGE",

  -- DK runes
  "RUNE_POWER_UPDATE", "RUNE_TYPE_UPDATE",

  -- Castbar
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",

  -- Spells
  "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE", "UNIT_SPELLCAST_SUCCEEDED",
  "COMBAT_LOG_EVENT_UNFILTERED",

  -- Target
  "PLAYER_TARGET_CHANGED",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "SPELL_RANGE_CHECK_UPDATE",

  -- Totems
  "PLAYER_TOTEM_UPDATE",
}) do
  eventFrame:RegisterEvent(ev)
end

eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
  -- Full refresh after world load
  if event == "PLAYER_ENTERING_WORLD" then
    ClassHUD:EnsureActiveSpecProfile()
    if ClassHUD.ResetSummonTracking then ClassHUD:ResetSummonTracking() end
    if ClassHUD.ResetTotemTracking then ClassHUD:ResetTotemTracking() end
    ClassHUD:FullUpdate()
    ClassHUD:ApplyAnchorPosition()
    local snapshotUpdated = ClassHUD:UpdateCDMSnapshot()
    if ClassHUD.BuildFramesForSpec then ClassHUD:BuildFramesForSpec() end
    if ClassHUD.RefreshActiveSpellMap then ClassHUD:RefreshActiveSpellMap() end
    if snapshotUpdated or ClassHUD._opts then ClassHUD:RefreshRegisteredOptions() end
    if ClassHUD.RefreshAllTotems then ClassHUD:RefreshAllTotems() end
    return
  end

  -- Spec change
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
    ClassHUD:EnsureActiveSpecProfile()
    if ClassHUD.ResetSummonTracking then ClassHUD:ResetSummonTracking() end
    if ClassHUD.ResetTotemTracking then ClassHUD:ResetTotemTracking() end
    ClassHUD:UpdateCDMSnapshot()
    if ClassHUD.BuildFramesForSpec then ClassHUD:BuildFramesForSpec() end
    if ClassHUD.BuildTrackedBuffFrames then ClassHUD:BuildTrackedBuffFrames() end
    if ClassHUD.RefreshRegisteredOptions then ClassHUD:RefreshRegisteredOptions() end
    if ClassHUD.UpdatePrimaryResource then ClassHUD:UpdatePrimaryResource() end
    if ClassHUD.EvaluateClassBarVisibility then
      ClassHUD:EvaluateClassBarVisibility()
    elseif ClassHUD.UpdateSpecialPower then
      ClassHUD:UpdateSpecialPower()
    end
    if ClassHUD.UpdateAllFrames then ClassHUD:UpdateAllFrames() end
    if ClassHUD.RefreshSpellFrameVisibility then ClassHUD:RefreshSpellFrameVisibility() end
    if ClassHUD.RefreshActiveSpellMap then ClassHUD:RefreshActiveSpellMap() end
    if ClassHUD.RefreshAllTotems then ClassHUD:RefreshAllTotems() end
    return
  end

  if (event == "PLAYER_TALENT_UPDATE" and (unit == nil or unit == "player"))
      or event == "TRAIT_CONFIG_UPDATED" then
    if ClassHUD.RefreshActiveSpellMap then
      ClassHUD:RefreshActiveSpellMap()
    end
    if ClassHUD.UpdateAllFrames then
      ClassHUD:UpdateAllFrames()
    end
    if ClassHUD.RefreshSpellFrameVisibility then
      ClassHUD:RefreshSpellFrameVisibility()
    end
    if ClassHUD.EvaluateClassBarVisibility then
      ClassHUD:EvaluateClassBarVisibility()
    elseif ClassHUD.UpdateSpecialPower then
      ClassHUD:UpdateSpecialPower()
    end
    return
  end

  -- Health
  if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit == "player" then
    if ClassHUD.UpdateHP then ClassHUD:UpdateHP() end
    return
  end

  -- Resources
  if event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
    if unit == "player" then
      if ClassHUD.UpdatePrimaryResource then ClassHUD:UpdatePrimaryResource() end
      if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
      if ClassHUD.UpdateAllSpellFrames then
        ClassHUD:RequestUpdate("resource")
      end
    end
    return
  end

  if event == "UPDATE_SHAPESHIFT_FORM" then
    if ClassHUD.UpdatePrimaryResource then ClassHUD:UpdatePrimaryResource() end
    if ClassHUD.EvaluateClassBarVisibility then
      ClassHUD:EvaluateClassBarVisibility()
    elseif ClassHUD.UpdateSpecialPower then
      ClassHUD:UpdateSpecialPower()
    end
    if ClassHUD.UpdateAllSpellFrames then
      ClassHUD:RequestUpdate("resource")
    end
    return
  end

  if event == "UNIT_POWER_POINT_CHARGE" and unit == "player" then
    if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    if ClassHUD.UpdateAllSpellFrames then
      ClassHUD:RequestUpdate("resource")
    end
    return
  end

  if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
    if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    if ClassHUD.UpdateAllSpellFrames then
      ClassHUD:RequestUpdate("resource")
    end
    return
  end

  -- Castbar events are handled as methods on ClassHUD (in Bars module)
  if event == "UNIT_SPELLCAST_START" and ClassHUD.UNIT_SPELLCAST_START then
    ClassHUD:UNIT_SPELLCAST_START(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_STOP" and ClassHUD.UNIT_SPELLCAST_STOP then
    ClassHUD:UNIT_SPELLCAST_STOP(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_START" and ClassHUD.UNIT_SPELLCAST_CHANNEL_START then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_START(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_STOP" and ClassHUD.UNIT_SPELLCAST_CHANNEL_STOP then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_INTERRUPTED" and ClassHUD.UNIT_SPELLCAST_INTERRUPTED then
    ClassHUD:UNIT_SPELLCAST_INTERRUPTED(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_FAILED" and ClassHUD.UNIT_SPELLCAST_FAILED then
    ClassHUD:UNIT_SPELLCAST_FAILED(unit, ...); return
  end

  if event == "UNIT_AURA" and (unit == "player" or unit == "pet" or unit == "target" or unit == "focus") then
    local updateInfo = ...
    local shouldUpdate = true
    if ClassHUD.ShouldProcessAuraUpdate then
      shouldUpdate = ClassHUD:ShouldProcessAuraUpdate(unit, updateInfo)
    end

    if shouldUpdate then
      if ClassHUD.HandleUnitAuraUpdate then
        ClassHUD:HandleUnitAuraUpdate(unit, updateInfo)
      elseif ClassHUD.UpdateAllFrames then
        ClassHUD:RequestUpdate("aura")
      end
    end

    if ClassHUD.HandleEclipseEvent and unit == "player" then
      ClassHUD:HandleEclipseEvent(event, unit, nil)
    end

    return
  end

  if event == "SPELL_UPDATE_COOLDOWN" then
    if ClassHUD.UpdateCooldown then
      ClassHUD:UpdateCooldown(nil)
    elseif ClassHUD.UpdateAllFrames then
      ClassHUD:RequestUpdate("cooldown")
    end
    return
  end

  if event == "SPELL_UPDATE_CHARGES" or event == "SPELL_UPDATE_USABLE" then
    local spellID = unit
    if ClassHUD.UpdateCooldown then
      ClassHUD:UpdateCooldown(spellID)
    elseif ClassHUD.UpdateAllFrames then
      ClassHUD:RequestUpdate("cooldown")
    end
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local spellID = select(2, ...)
    if ClassHUD.UpdateCooldown then
      ClassHUD:UpdateCooldown(spellID)
    elseif ClassHUD.UpdateAllFrames then
      ClassHUD:RequestUpdate("cooldown")
    end

    if ClassHUD.HandleEclipseEvent and unit == "player" then
      ClassHUD:HandleEclipseEvent(event, unit, spellID)
    end

    return
  end

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if ClassHUD.HandleCombatLogEvent then
      ClassHUD:HandleCombatLogEvent()
    end
    return
  end

  if event == "PLAYER_TOTEM_UPDATE" then
    local slot = tonumber(unit)
    if ClassHUD.UpdateTotemSlot then
      ClassHUD:UpdateTotemSlot(slot)
    elseif ClassHUD.RefreshAllTotems then
      ClassHUD:RefreshAllTotems()
    end
    return
  end

  if event == "PLAYER_REGEN_ENABLED" and ClassHUD.EvaluateClassBarVisibility then
    ClassHUD:EvaluateClassBarVisibility()
  end

  -- Target
  if event == "PLAYER_TARGET_CHANGED"
      or event == "PLAYER_REGEN_DISABLED"
      or event == "PLAYER_REGEN_ENABLED"
      or event == "SPELL_RANGE_CHECK_UPDATE"
  then
    if ClassHUD.UpdateAllFrames then
      ClassHUD:RequestUpdate("target")
    end
    return
  end
end)


-- Replace your slash handler with this
SLASH_CLASSHUD1 = "/chud"
SLASH_CLASSHUD2 = "/classhud"
SlashCmdList["CLASSHUD"] = function(msg)
  msg = msg or ""
  if strtrim then
    msg = strtrim(msg)
  else
    msg = msg:match("^%s*(.-)%s*$")
  end

  local command, rest = msg:match("^(%S+)%s*(.*)$")
  if command and command:lower() == "debug" then
    local sub = rest and rest:lower() or ""
    if sub == "on" then
      ClassHUD.debugEnabled = true
      print("Debug logging enabled.")
    elseif sub == "off" then
      ClassHUD.debugEnabled = false
      print("Debug logging disabled.")
    elseif sub == "clear" then
      if ClassHUDDebugLog then
        if wipe then
          wipe(ClassHUDDebugLog)
        else
          for key in pairs(ClassHUDDebugLog) do
            ClassHUDDebugLog[key] = nil
          end
        end
      else
        ClassHUDDebugLog = {}
      end
      print("Debug log cleared.")
    elseif sub == "" then
      local ACR = LibStub("AceConfigRegistry-3.0", true)
      local ACD = LibStub("AceConfigDialog-3.0", true)
      print("|cff00ff88ClassHUD Debug|r",
        "ACR=", ACR and "ok" or "nil",
        "ACD=", ACD and "ok" or "nil",
        "registered=", (ACR and ACR:GetOptionsTable("ClassHUD")) and "yes" or "no")
    else
      print("Usage: /classhud debug on|off|clear")
    end
    return
  end

  if command and command ~= "" then
    -- Any other sub-commands fall through to the options window for now
    ClassHUD:OpenOptions()
    return
  end

  ClassHUD:OpenOptions()
end

SLASH_CLASSHUDRESET1 = "/classhudreset"
SlashCmdList.CLASSHUDRESET = function()
  if ClassHUD and ClassHUD.db then
    ClassHUD.db:ResetProfile()
    ClassHUD:BuildFramesForSpec()
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR and ClassHUD._opts then ACR:NotifyChange("ClassHUD") end
    print("|cff00ff00ClassHUD: profile reset.|r")
  end
end

-- ==================================================
-- Debug command: /classhudwipe
-- Nukes the entire DB and restores defaults
-- ==================================================
SLASH_CLASSHUDWIPE1 = "/classhudwipe"
SlashCmdList.CLASSHUDWIPE = function()
  if ClassHUD and ClassHUD.db then
    ClassHUD.db:ResetDB()
    -- Rebuild frames and options after nuke
    ClassHUD:BuildFramesForSpec()
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR and ClassHUD._opts then ACR:NotifyChange("ClassHUD") end
    print("|cffff0000ClassHUD: full database wiped. All profiles reset to defaults.|r")
  end
end
