-- ClassHUD_Utils.lua
-- Shared helper utilities used across the addon.

---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")

ClassHUD._lastSpecID = ClassHUD._lastSpecID or 0
ClassHUD._snapshotStore = ClassHUD._snapshotStore or {}

local C_Spell, C_UnitAuras, GetTime, floor, tostring, ipairs, pairs = C_Spell, C_UnitAuras, GetTime, floor, tostring,
    ipairs, pairs

local DEFAULT_TRACKED_BAR_COLOR = { r = 0.25, g = 0.65, b = 1.00, a = 1 }

local TMP = {}

local function CopyColorTemplate(template)
  return {
    r = template.r or 1,
    g = template.g or 1,
    b = template.b or 1,
    a = template.a or 1,
  }
end

-- ---------------------------------------------------------------------------
-- Profile helpers
-- ---------------------------------------------------------------------------

---Returns the player's class token ("MAGE", "PRIEST" ...) and specialization ID.
---@return string classToken, number specID
function ClassHUD:GetPlayerClassSpec()
  local _, class = UnitClass("player")
  local specIndex = GetSpecialization()
  local specID = 0

  if specIndex then
    specID = GetSpecializationInfo(specIndex) or 0
  end

  if specID and specID > 0 then
    self._lastSpecID = specID
  elseif self._lastSpecID and self._lastSpecID > 0 then
    specID = self._lastSpecID
  end

  return class, specID
end

---Internal helper to walk the saved variables profile tree.
---@param create boolean|nil If true, missing tables are created on the way.
---@param ... string Path within profile.
---@return table|nil
function ClassHUD:GetProfileTable(create, ...)
  if not (self.db and self.db.profile) then return nil end

  local node = self.db.profile
  local path = { ... }

  for i = 1, #path do
    local key = path[i]
    if type(node[key]) ~= "table" then
      if not create then return nil end
      node[key] = {}
    end
    node = node[key]
  end

  return node
end

---Convenience wrapper for accessing the cooldown snapshot storage.
---@param create boolean|nil If true, the snapshot root is created if needed.
---@return table|nil
function ClassHUD:GetSnapshotRoot(create)
  if not self._snapshotStore and not create then
    return nil
  end

  self._snapshotStore = self._snapshotStore or {}
  local profileName = (self.db and self.db.GetCurrentProfile and self.db:GetCurrentProfile()) or "Default"
  local root = self._snapshotStore[profileName]
  if not root and create then
    root = {}
    self._snapshotStore[profileName] = root
  end
  return root
end

---Returns the snapshot table for a given class/spec combination.
---@param class string|nil Defaults to the player's class.
---@param specID number|nil Defaults to the player's current spec.
---@param create boolean|nil Create the table if it does not exist.
---@return table|nil
function ClassHUD:GetSnapshotForSpec(class, specID, create)
  local playerClass, playerSpec = self:GetPlayerClassSpec()
  class = class or playerClass
  specID = specID or playerSpec

  local root = self:GetSnapshotRoot(create)
  if not root then return nil end

  if type(root[class]) ~= "table" then
    if not create then return nil end
    root[class] = {}
  end

  if type(root[class][specID]) ~= "table" then
    if not create then return nil end
    root[class][specID] = {}
  end

  return root[class][specID]
end

---Resets the snapshot table for the given class/spec.
---@param class string|nil
---@param specID number|nil
function ClassHUD:ResetSnapshotFor(class, specID)
  local snapshot = self:GetSnapshotForSpec(class, specID, true)
  if not snapshot then return end
  for k in pairs(snapshot) do
    snapshot[k] = nil
  end
end

---Returns the stored snapshot entry for a spell/buff ID.
---@param spellID number
---@param class string|nil
---@param specID number|nil
---@return table|nil
function ClassHUD:GetSnapshotEntry(spellID, class, specID)
  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  if not snapshot then return nil end
  return snapshot[spellID]
end

local function NormalizeTrackedConfigTable(config)
  config.showIcon = not not config.showIcon
  config.showBar = not not config.showBar

  if config.barShowIcon == nil then
    config.barShowIcon = true
  else
    config.barShowIcon = not not config.barShowIcon
  end

  if config.barShowTimer == nil then
    config.barShowTimer = true
  else
    config.barShowTimer = not not config.barShowTimer
  end

  local color = config.barColor
  if type(color) ~= "table" then
    config.barColor = CopyColorTemplate(DEFAULT_TRACKED_BAR_COLOR)
  else
    config.barColor = {
      r = color.r or DEFAULT_TRACKED_BAR_COLOR.r,
      g = color.g or DEFAULT_TRACKED_BAR_COLOR.g,
      b = color.b or DEFAULT_TRACKED_BAR_COLOR.b,
      a = color.a or DEFAULT_TRACKED_BAR_COLOR.a,
    }
  end

  return config
end

local function NormalizeTrackedConfig(value)
  if type(value) == "table" then
    return NormalizeTrackedConfigTable(value)
  elseif type(value) == "boolean" then
    return NormalizeTrackedConfigTable({
      showIcon = value,
      showBar = false,
      barShowIcon = true,
      barShowTimer = true,
      barColor = CopyColorTemplate(DEFAULT_TRACKED_BAR_COLOR),
    })
  end

  return nil
end

---Returns (and optionally creates) the configuration block for a tracked buff/bar entry.
---@param class string|nil
---@param specID number|nil
---@param buffID number
---@param create boolean|nil
---@return table|nil
function ClassHUD:GetTrackedEntryConfig(class, specID, buffID, create)
  local playerClass, playerSpec = self:GetPlayerClassSpec()
  class = class or playerClass
  specID = specID or playerSpec

  local tracked = self:GetProfileTable(create, "tracking", "buffs", "tracked", class, specID)
  if not tracked then return nil end

  local value = tracked[buffID]
  local normalized = NormalizeTrackedConfig(value)

  if normalized then
    if normalized ~= value then
      tracked[buffID] = normalized
    end
    return normalized
  end

  if create then
    local fresh = NormalizeTrackedConfig(false)
    tracked[buffID] = fresh
    return fresh
  end

  return nil
end

---Iterates over snapshot entries for a given category and calls the handler.
---@param category string One of "essential", "utility", "buff", "bar".
---@param handler fun(spellID:number, entry:table, categoryData:table)
---@param class string|nil
---@param specID number|nil
function ClassHUD:ForEachSnapshotEntry(category, handler, class, specID)
  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  if not snapshot then return end

  for spellID, entry in pairs(snapshot) do
    local categories = entry.categories
    local categoryData = categories and categories[category]
    if categoryData then
      handler(spellID, entry, categoryData)
    end
  end
end

---Checks if the Blizzard Cooldown Viewer API is currently available.
---@return boolean
function ClassHUD:IsCooldownViewerAvailable()
  return C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable
      and C_CooldownViewer.IsCooldownViewerAvailable()
end

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------

---Formats a duration in seconds for compact cooldown text.
---@param seconds number
---@return string
function ClassHUD.FormatSeconds(seconds)
  if seconds >= 60 then
    local mins = floor(seconds / 60)
    local secs = floor(seconds % 60)
    if secs < 10 then
      return mins .. ":0" .. secs
    end
    return mins .. ":" .. secs
  elseif seconds >= 10 then
    return tostring(floor(seconds + 0.5))
  else
    return tostring(floor(seconds)) -- alltid heltall, ingen desimal
  end
end

local PET_UNITS = (ClassHUD and ClassHUD.PET_UNIT_TOKENS) or { "pet" }
local DEFAULT_AURA_UNITS = { "player" }
for i = 1, #PET_UNITS do
  DEFAULT_AURA_UNITS[#DEFAULT_AURA_UNITS + 1] = PET_UNITS[i]
end
DEFAULT_AURA_UNITS[#DEFAULT_AURA_UNITS + 1] = "target"
DEFAULT_AURA_UNITS[#DEFAULT_AURA_UNITS + 1] = "focus"
DEFAULT_AURA_UNITS[#DEFAULT_AURA_UNITS + 1] = "mouseover"
local CATEGORY_PRIORITY = { "bar", "buff", "essential", "utility" }

local function AppendCandidate(self, list, seen, spellID)
  if not spellID then return end

  local numericID = tonumber(spellID) or spellID
  if type(numericID) ~= "number" or numericID <= 0 then
    return
  end

  if not seen[numericID] then
    list[#list + 1] = numericID
    seen[numericID] = true
  end

  local activeID = self and self.GetActiveSpellID and self:GetActiveSpellID(numericID)
  if activeID and type(activeID) == "number" and activeID > 0 and not seen[activeID] then
    list[#list + 1] = activeID
    seen[activeID] = true
  end

  if self and self.GetLinkedAuraSpellIDs then
    local linked = self:GetLinkedAuraSpellIDs(numericID)
    if type(linked) == "table" then
      for auraID in pairs(linked) do
        if type(auraID) == "number" and auraID > 0 and not seen[auraID] then
          list[#list + 1] = auraID
          seen[auraID] = true
        end
      end
    end

    if activeID and type(activeID) == "number" and activeID > 0 then
      local activeLinked = self:GetLinkedAuraSpellIDs(activeID)
      if type(activeLinked) == "table" then
        for auraID in pairs(activeLinked) do
          if type(auraID) == "number" and auraID > 0 and not seen[auraID] then
            list[#list + 1] = auraID
            seen[auraID] = true
          end
        end
      end
    end
  end
end

---Finds the first relevant aura for the given spell ID across a list of units.
---@param spellID number
---@param units string[]|nil
---@return table|nil auraData, string|nil unit
function ClassHUD:GetAuraForSpell(spellID, units)
  if not C_UnitAuras then return nil end

  local numericSpellID = tonumber(spellID) or spellID
  if type(numericSpellID) ~= "number" or numericSpellID <= 0 then
    return nil
  end

  local normalizedSpellID = self:GetActiveSpellID(numericSpellID) or numericSpellID

  local candidates = {}
  local candidateSeen = {}
  local function addCandidate(id)
    if type(id) == "number" and id > 0 and not candidateSeen[id] then
      candidates[#candidates + 1] = id
      candidateSeen[id] = true
    end
  end

  addCandidate(normalizedSpellID)
  addCandidate(numericSpellID)

  local unitList = units or DEFAULT_AURA_UNITS
  if ClassHUD and ClassHUD.GetExpandedAuraUnitList then
    unitList = ClassHUD:GetExpandedAuraUnitList(unitList) or unitList
  end

  if C_UnitAuras.GetPlayerAuraBySpellID then
    for i = 1, #candidates do
      local queryID = candidates[i]
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(queryID)
      if aura then
        if self.LogAuraMatch then
          self:LogAuraMatch("player", queryID, aura)
        end
        return aura, "player"
      end
    end
  end

  if C_UnitAuras.GetAuraDataBySpellID then
    for i = 1, #unitList do
      local unit = unitList[i]
      if type(unit) == "string" and unit ~= "player" then
        local isPetUnit = self.IsPetUnit and self:IsPetUnit(unit)
        if isPetUnit or UnitExists(unit) then
          local attempts = isPetUnit and #candidates or (#candidates > 0 and 1 or 0)
          for attempt = 1, attempts do
            local queryID = candidates[attempt]
            if queryID then
              local aura = C_UnitAuras.GetAuraDataBySpellID(unit, queryID)
              if aura then
                local sourceUnit = aura.sourceUnit
                local sourceIsPlayer = aura.isFromPlayer or sourceUnit == "player"
                local sourceIsPet = sourceUnit and self.IsPetUnit and self:IsPetUnit(sourceUnit)
                local allowPetAura = isPetUnit and (sourceIsPlayer or sourceIsPet or sourceUnit == nil)
                if sourceIsPlayer or sourceIsPet or allowPetAura then
                  if self.LogAuraMatch then
                    self:LogAuraMatch(unit, queryID, aura)
                  end
                  return aura, unit
                end
              end
            end
          end
        end
      end
    end
  end

  return nil
end

---Collect possible aura spellIDs for a snapshot entry.
---@param entry table|nil
---@param spellID number
---@return number[] candidates
function ClassHUD:_AssembleAuraCandidates(entry, spellID)
  if not entry then return nil end

  local candidates = entry._candidates
  if type(candidates) ~= "table" then
    candidates = {}
    entry._candidates = candidates
  else
    for i = #candidates, 1, -1 do
      candidates[i] = nil
    end
  end

  local seen = {}

  if entry.categories then
    for _, catData in pairs(entry.categories) do
      AppendCandidate(self, candidates, seen, catData.overrideSpellID)

      local linked = catData.linkedSpellIDs
      if linked then
        for i = 1, #linked do
          AppendCandidate(self, candidates, seen, linked[i])
        end
      end

      AppendCandidate(self, candidates, seen, catData.spellID)
    end
  end

  AppendCandidate(self, candidates, seen, spellID)

  return candidates
end

function ClassHUD:GetAuraCandidatesForEntry(entry, spellID)
  if entry then
    local cached = entry._candidates
    if type(cached) == "table" then
      local baseSpellID = entry.spellID or spellID
      if spellID and baseSpellID and spellID ~= baseSpellID then
        for i = #TMP, 1, -1 do
          TMP[i] = nil
        end

        local count = #cached
        for i = 1, count do
          TMP[i] = cached[i]
        end

        local seen = {}
        for i = 1, count do
          seen[TMP[i]] = true
        end

        AppendCandidate(self, TMP, seen, spellID)

        return TMP
      end

      return cached
    end
    local baseSpellID = entry.spellID or spellID
    return self:_AssembleAuraCandidates(entry, baseSpellID)
  end

  if not spellID then
    return nil
  end

  for i = #TMP, 1, -1 do
    TMP[i] = nil
  end

  local seen = {}
  AppendCandidate(self, TMP, seen, spellID)
  return TMP
end

---Finds an active aura from a list of candidate spellIDs.
---@param candidates number[]|nil
---@param units string[]|nil Optional unit list override.
---@return table|nil auraData, number|nil auraSpellID, string|nil unit
function ClassHUD:FindAuraFromCandidates(candidates, units)
  if not candidates then return nil end

  for i = 1, #candidates do
    local auraID = candidates[i]
    local aura, unit = self:GetAuraForSpell(auraID, units)
    if aura then
      return aura, auraID, unit
    end
  end

  return nil
end

---Determines if a spell should be treated as a harmful aura tracker.
---@param spellID number
---@param entry table|nil Snapshot entry
---@return boolean tracksAura, boolean auraActive
function ClassHUD:IsHarmfulAuraSpell(spellID, entry)
  if not (C_Spell and C_Spell.IsSpellHarmful) then return false, false end
  local normalizedSpellID = self:GetActiveSpellID(spellID) or spellID
  local ok, harmful = pcall(C_Spell.IsSpellHarmful, normalizedSpellID)
  if not ok or not harmful then return false, false end

  -- Case 1: snapshot sier dette er en buff/debuff (klassisk DoT)
  if entry and entry.categories and entry.categories.buff then
    local candidates = self:GetAuraCandidatesForEntry(entry, normalizedSpellID)
    local aura = self:FindAuraFromCandidates(candidates, { "target", "focus" })
    if aura and aura.expirationTime and aura.expirationTime > 0 then
      return true, true
    else
      return true, false
    end
  end

  -- Case 2: spell er lagt inn manuelt (ingen snapshot-entry)
  -- Her antar vi at brukeren vil tracke det som en aura på target
  if not entry then
    local info = C_Spell.GetSpellInfo(normalizedSpellID)
    if info then
      local aura = C_UnitAuras.GetAuraDataBySpellName("target", info.name, "HARMFUL")
          or C_UnitAuras.GetAuraDataBySpellName("focus", info.name, "HARMFUL")
      if aura and aura.expirationTime and aura.expirationTime > 0 then
        return true, true
      else
        return true, false
      end
    end
  end

  return false, false
end

function ClassHUD:FindAuraByName(castSpellID, units)
  local normalizedSpellID = self:GetActiveSpellID(castSpellID) or castSpellID
  local info = C_Spell.GetSpellInfo(normalizedSpellID)
  if not info or not info.name then return nil end
  local spellName = info.name

  units = units or { "target" }
  for idx = 1, #units do
    local unit = units[idx]
    local i = 1
    while true do
      local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
      if not aura then break end
      if aura.name == spellName and aura.sourceUnit == "player" then
        return aura
      end
      i = i + 1
    end
  end
  return nil
end

function ClassHUD:LacksResources(spellID)
  -- Både gamle og nye API-navn støttes
  local normalizedSpellID = self:GetActiveSpellID(spellID) or spellID
  local costs = (C_Spell and C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(normalizedSpellID))
      or (GetSpellPowerCost and GetSpellPowerCost(normalizedSpellID))

  if type(costs) ~= "table" then return false end

  for i = 1, #costs do
    local c     = costs[i]
    -- Feltnavn varierer litt mellom patches
    local ptype = c.type or c.powerType
    local cost  = c.cost or c.minCost or 0

    if ptype ~= nil and cost and cost > 0 then
      -- Noen kostnader er “per sec” ved channeling – de ignorerer vi her
      local cur = UnitPower("player", ptype) or 0
      if cur < cost then
        return true
      end
    end
  end

  return false
end
