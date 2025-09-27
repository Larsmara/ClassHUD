---@type ClassHUD
local ClassHUD = _G.ClassHUD

ClassHUD.Cooldowns = ClassHUD.Cooldowns or {}

local Cooldowns = ClassHUD.Cooldowns

local LIST_KEYS = {
  "listID",
  "listId",
  "categoryID",
  "categoryId",
  "name",
  "listName",
  "id",
  "ID",
}

local ID_LIST_KEYS = {
  "cooldownIDs",
  "cooldownIdList",
  "cooldownIDsByIndex",
  "cooldowns",
  "entries",
  "ids",
}

local function appendNumericIDs(target, seen, source)
  if type(source) ~= "table" then
    return
  end

  for _, value in ipairs(source) do
    if type(value) == "number" and not seen[value] then
      target[#target + 1] = value
      seen[value] = true
    end
  end

  for key, value in pairs(source) do
    local id
    if type(value) == "number" then
      id = value
    elseif type(key) == "number" and value then
      id = key
    end

    if id and not seen[id] then
      target[#target + 1] = id
      seen[id] = true
    end
  end
end

local function copyAuraInfo(aura)
  if type(aura) ~= "table" then
    return nil
  end

  return {
    spellID = aura.spellID or aura.spellId,
    name = aura.name,
    icon = aura.icon,
    applications = aura.applications or aura.stackCount,
    duration = aura.duration,
    expirationTime = aura.expirationTime,
    sourceUnit = aura.sourceUnit,
    isHelpful = aura.isHelpful,
    isHarmful = aura.isHarmful,
  }
end

local function buildCooldownPayload(spellID)
  if not spellID then
    return nil
  end

  local start, duration, enabled, modRate
  if C_Spell and C_Spell.GetSpellCooldown then
    start, duration, enabled, modRate = C_Spell.GetSpellCooldown(spellID)
  elseif GetSpellCooldown then
    start, duration, enabled = GetSpellCooldown(spellID)
  end

  if start == nil then
    return nil
  end

  return {
    start = start,
    duration = duration,
    enabled = enabled,
    modRate = modRate,
  }
end

local function buildChargePayload(spellID)
  if not spellID then
    return nil
  end

  local charges, maxCharges, start, duration
  if C_Spell and C_Spell.GetSpellCharges then
    charges, maxCharges, start, duration = C_Spell.GetSpellCharges(spellID)
  elseif GetSpellCharges then
    charges, maxCharges, start, duration = GetSpellCharges(spellID)
  end

  if charges == nil then
    return nil
  end

  return {
    count = charges,
    max = maxCharges,
    start = start,
    duration = duration,
  }
end

local function getAuraPayload(spellID)
  if not spellID then
    return nil
  end

  local aura
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
  elseif AuraUtil and AuraUtil.FindAuraBySpellID then
    local filterUsed = "HELPFUL"
    local name, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = AuraUtil.FindAuraBySpellID(spellID, "player", filterUsed)
    if not name then
      filterUsed = "HARMFUL"
      name, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = AuraUtil.FindAuraBySpellID(spellID, "player", filterUsed)
    end

    if name then
      aura = {
        name = name,
        icon = icon,
        applications = count,
        duration = duration,
        expirationTime = expirationTime,
        sourceUnit = source,
        spellID = spellId or spellID,
        isHelpful = filterUsed == "HELPFUL" or nil,
        isHarmful = filterUsed == "HARMFUL" or nil,
      }
    end
  end

  return copyAuraInfo(aura)
end

function Cooldowns:IsAPIAvailable()
  return type(C_CooldownViewer) == "table"
    and type(C_CooldownViewer.GetCooldownViewerCategorySet) == "function"
    and type(C_CooldownViewer.GetCooldownViewerCooldownInfo) == "function"
end

function Cooldowns:GetListIdentifier(categorySet, fallbackIndex)
  if type(categorySet) ~= "table" then
    return fallbackIndex
  end

  for _, key in ipairs(LIST_KEYS) do
    local value = categorySet[key]
    if value ~= nil then
      return value
    end
  end

  return fallbackIndex
end

function Cooldowns:CollectCooldownIDs(categorySet)
  local ids = {}
  local seen = {}

  if type(categorySet) ~= "table" then
    return ids
  end

  for _, key in ipairs(ID_LIST_KEYS) do
    appendNumericIDs(ids, seen, categorySet[key])
  end

  -- Some category sets may expose numeric indices directly.
  for _, value in pairs(categorySet) do
    if type(value) == "number" and not seen[value] then
      ids[#ids + 1] = value
      seen[value] = true
    end
  end

  table.sort(ids)

  return ids
end

function Cooldowns:NormalizeEntry(listID, info)
  if type(info) ~= "table" then
    return nil
  end

  local spellID = info.spellID or info.spellId
  if not spellID then
    return nil
  end

  local entry = {
    list = listID or info.listID or info.categoryID,
    kind = info.kind or info.cooldownType or info.type,
    spellID = spellID,
    cooldown = buildCooldownPayload(spellID),
    charges = buildChargePayload(spellID),
    aura = getAuraPayload(spellID),
  }

  return entry
end

function Cooldowns:BuildEntries()
  if not self:IsAPIAvailable() then
    return nil
  end

  local entries = {}
  local index = 1
  while true do
    local categorySet = C_CooldownViewer.GetCooldownViewerCategorySet(index)
    if not categorySet then
      break
    end

    local listID = self:GetListIdentifier(categorySet, index)
    local cooldownIDs = self:CollectCooldownIDs(categorySet)
    for _, cooldownID in ipairs(cooldownIDs) do
      local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
      local normalized = self:NormalizeEntry(listID, info)
      if normalized then
        entries[#entries + 1] = normalized
      end
    end

    index = index + 1
  end

  return entries
end

function Cooldowns:HandleEvent(event)
  if not self:IsAPIAvailable() then
    if self._reportedUnavailable then
      return
    end

    self._reportedUnavailable = true
    ClassHUD:Debug("Cooldown Manager API unavailable; skipping updates.")
    return
  end

  self._reportedUnavailable = nil

  local entries = self:BuildEntries()
  if not entries then
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    local message = string.format("Cooldown Manager loaded %d entries.", #entries)
    if type(ClassHUD.Msg) == "function" then
      ClassHUD:Msg(message)
    else
      ClassHUD:Debug(message)
    end
  end

  if type(ClassHUD.UpdateFromCM) ~= "function" then
    return
  end

  for _, entry in ipairs(entries) do
    ClassHUD:UpdateFromCM(entry)
  end
end

function Cooldowns:Initialize()
  if self.initialized then
    return
  end

  self.initialized = true

  if not self:IsAPIAvailable() then
    ClassHUD:Debug("Cooldown Manager API unavailable; integration disabled.")
    return
  end
end
