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
    return string.format("%dm", math.ceil(seconds / 60))
  elseif seconds >= 10 then
    return tostring(math.floor(seconds + 0.5))
  else
    return string.format("%.1f", seconds)
  end
end

local DEFAULT_AURA_UNITS = { "player", "pet", "target", "focus", "mouseover" }

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

