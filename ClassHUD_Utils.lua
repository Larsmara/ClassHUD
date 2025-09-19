-- ClassHUD_Utils.lua
-- Shared helper utilities used across the addon.

---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")

ClassHUD._lastSpecID = ClassHUD._lastSpecID or 0

local DEFAULT_TRACKED_BAR_COLOR = { r = 0.25, g = 0.65, b = 1.00, a = 1 }

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
  return self:GetProfileTable(create, "cdmSnapshot")
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

---Returns a fresh copy of the default tracked-bar color settings.
---@return table
function ClassHUD:GetDefaultTrackedBarColor()
  return CopyColorTemplate(DEFAULT_TRACKED_BAR_COLOR)
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

  local tracked = self:GetProfileTable(create, "trackedBuffs", class, specID)
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

---Determines the best spell information to represent a tracked bar entry.
---@param entry table|nil Cooldown snapshot entry.
---@param primaryID number|nil Fallback spellID if no better match is found.
---@param candidates number[]|nil Pre-computed aura candidate list.
---@return number|nil displaySpellID
---@return string displayName
---@return number|nil iconID
---@return number[]|nil candidateList
function ClassHUD:ResolveTrackedBarDisplay(entry, primaryID, candidates)
  candidates = candidates or self:GetAuraCandidatesForEntry(entry, primaryID)

  local displaySpellID, displayName, iconID

  if candidates then
    for _, spellID in ipairs(candidates) do
      if type(spellID) == "number" and spellID > 0 then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then
          displaySpellID = spellID
          displayName = info.name
          iconID = info.iconID
          break
        end
      end
    end
  end

  if not displaySpellID and primaryID then
    local info = C_Spell.GetSpellInfo(primaryID)
    if info and info.name then
      displaySpellID = primaryID
      displayName = displayName or info.name
      iconID = iconID or info.iconID
    end
  end

  if entry then
    displayName = displayName or entry.name
    iconID = iconID or entry.iconID
  end

  if not displayName then
    if displaySpellID then
      displayName = C_Spell.GetSpellName(displaySpellID)
    elseif primaryID then
      displayName = C_Spell.GetSpellName(primaryID)
    end
  end

  displayName = displayName or (primaryID and ("Spell " .. primaryID)) or "Unknown"

  return displaySpellID, displayName, iconID, candidates
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
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
  elseif seconds >= 10 then
    return tostring(math.floor(seconds + 0.5))
  else
    return tostring(math.floor(seconds)) -- alltid heltall, ingen desimal
  end
end

local DEFAULT_AURA_UNITS = { "player", "pet", "target", "focus", "mouseover" }
local CATEGORY_PRIORITY = { "bar", "buff", "essential", "utility" }

---Finds the first relevant aura for the given spell ID across a list of units.
---@param spellID number
---@param units string[]|nil
---@return table|nil auraData, string|nil unit
function ClassHUD:GetAuraForSpell(spellID, units)
  if not C_UnitAuras then return nil end

  units = units or DEFAULT_AURA_UNITS

  if C_UnitAuras.GetPlayerAuraBySpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if aura then return aura, "player" end
  end

  if C_UnitAuras.GetAuraDataBySpellID then
    for _, unit in ipairs(units) do
      if unit ~= "player" and UnitExists(unit) then
        local aura = C_UnitAuras.GetAuraDataBySpellID(unit, spellID)
        if aura and (aura.isFromPlayer or aura.sourceUnit == "player" or aura.sourceUnit == "pet") then
          return aura, unit
        end
      end
    end
  end

  return nil
end

---Collects aura spellIDs associated with a snapshot entry.
---@param entry table|nil Snapshot entry from the Cooldown Viewer.
---@param primaryID number|nil Optional fallback spellID.
---@return number[]
function ClassHUD:GetAuraCandidatesForEntry(entry, primaryID)
  local results, seen = {}, {}

  local function add(id)
    if type(id) == "number" and id > 0 and not seen[id] then
      seen[id] = true
      table.insert(results, id)
    end
  end

  add(primaryID)

  if entry then
    add(entry.spellID)

    local categories = entry.categories
    if categories then
      for _, key in ipairs(CATEGORY_PRIORITY) do
        local category = categories[key]
        if category then
          add(category.spellID)
          add(category.overrideSpellID)
          if category.linkedSpellIDs then
            for _, linked in ipairs(category.linkedSpellIDs) do
              add(linked)
            end
          end
        end
      end
    end
  end

  return results
end

---Finds an active aura from a list of candidate spellIDs.
---@param candidates number[]|nil
---@param units string[]|nil Optional unit list override.
---@return table|nil auraData, number|nil auraSpellID, string|nil unit
function ClassHUD:FindAuraFromCandidates(candidates, units)
  if not candidates then return nil end

  for _, auraID in ipairs(candidates) do
    local aura, unit = self:GetAuraForSpell(auraID, units)
    if aura then
      return aura, auraID, unit
    end
  end

  return nil
end
