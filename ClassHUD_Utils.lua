-- ClassHUD_Utils.lua
-- Shared helper utilities used across the addon.

---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")

ClassHUD._lastSpecID = ClassHUD._lastSpecID or 0


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

function ClassHUD:GetHiddenTrackedBuffs(class, specID, create)
  local playerClass, playerSpec = self:GetPlayerClassSpec()
  class = class or playerClass
  specID = specID or playerSpec
  return self:GetProfileTable(create, "trackedBuffsHidden", class, specID)
end

function ClassHUD:IsTrackedBuffHidden(spellID, class, specID)
  local tbl = self:GetHiddenTrackedBuffs(class, specID, false)
  return tbl and tbl[spellID] and true or false
end

function ClassHUD:SetTrackedBuffHidden(spellID, hidden, class, specID)
  local tbl = self:GetHiddenTrackedBuffs(class, specID, hidden)
  if not tbl then return end
  if hidden then
    tbl[spellID] = true
  else
    tbl[spellID] = nil
  end
end

function ClassHUD:GetCustomTrackedBuffs(class, specID, create)
  local playerClass, playerSpec = self:GetPlayerClassSpec()
  class = class or playerClass
  specID = specID or playerSpec
  return self:GetProfileTable(create, "trackedBuffsCustom", class, specID)
end

function ClassHUD:AddCustomTrackedBuff(spellID, class, specID)
  if not spellID then return end
  local tbl = self:GetCustomTrackedBuffs(class, specID, true)
  if tbl then
    tbl[spellID] = true
  end
end

function ClassHUD:RemoveCustomTrackedBuff(spellID, class, specID)
  if not spellID then return end
  local tbl = self:GetCustomTrackedBuffs(class, specID, false)
  if tbl then
    tbl[spellID] = nil
  end
end

function ClassHUD:GetCustomTrackedBuffList(class, specID)
  local custom = self:GetCustomTrackedBuffs(class, specID, false)
  local list = {}
  if not custom then return list end
  for spellID in pairs(custom) do
    table.insert(list, spellID)
  end
  table.sort(list)
  return list
end

---Returns a fresh copy of the default tracked-bar color settings.
---@return table
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
function ClassHUD:IsCooldownViewerAvailable(categoryID)
  if not (C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable) then
    return false
  end

  if categoryID then
    return C_CooldownViewer.IsCooldownViewerAvailable(categoryID)
  end

  local enum = Enum and Enum.CooldownViewerCategory
  if not enum then return false end

  local categories = {
    enum.Essential,
    enum.Utility,
    enum.TrackedBuffs,
    enum.TrackedBars,
  }

  for _, cat in ipairs(categories) do
    if cat and C_CooldownViewer.IsCooldownViewerAvailable(cat) then
      return true
    end
  end

  return false
end

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------

---Formats a duration in seconds for compact cooldown text.
---@param seconds number
---@return string
function ClassHUD.FormatSeconds(seconds)
  if seconds >= 60 then
    local minutes = math.max(1, math.floor(seconds / 60 + 0.5))
    return string.format("%dm", minutes)
  elseif seconds >= 10 then
    return string.format("%d", math.floor(seconds))
  else
    return string.format("%.1f", seconds)
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

