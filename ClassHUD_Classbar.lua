local addon = ClassHUD
local UI = addon.UI

function addon:CreatePowerContainer()
  if UI.power then return UI.power end
  local f = CreateFrame("Frame", nil, UI.anchor, "BackdropTemplate")
  f:SetSize(self.db.profile.width, self.db.profile.height.power)
  UI.power = f
  return f
end

local function EnsureSegment(i)
  if not UI.powerSegments[i] then
    local sb = addon:CreateStatusBar(UI.power, addon.db.profile.height.power)
    sb.text:Hide()
    UI.powerSegments[i] = sb
  end
  return UI.powerSegments[i]
end

local function HideAllSegments(from)
  for i = from, #UI.powerSegments do
    if UI.powerSegments[i] then UI.powerSegments[i]:Hide() end
  end
end

local CLASS_POWER_ID = {
  MONK        = Enum.PowerType.Chi,
  PALADIN     = Enum.PowerType.HolyPower,
  WARLOCK     = Enum.PowerType.SoulShards,
  ROGUE       = Enum.PowerType.ComboPoints,
  DRUID       = Enum.PowerType.ComboPoints,
  MAGE        = Enum.PowerType.ArcaneCharges,
  EVOKER      = Enum.PowerType.Essence,
  DEATHKNIGHT = Enum.PowerType.Runes,
}

local REQUIRED_SPEC = {
  MONK = 269,
  MAGE = 62,
}

local USES_PARTIAL_BY_SPEC = {
  [267] = true,
}

local CHARGED_CP_COLOR = { 1.0, 0.95, 0.35 }

local RESOURCE_BASE_COLORS = {
  [Enum.PowerType.HolyPower]     = { 1.00, 0.88, 0.25 },
  [Enum.PowerType.SoulShards]    = { 0.60, 0.22, 1.00 },
  [Enum.PowerType.ArcaneCharges] = { 0.25, 0.60, 1.00 },
  [Enum.PowerType.Essence]       = { 0.50, 1.00, 0.90 },
}

local function RuneSpecColor(specID)
  if specID == 250 then return 0.75, 0.10, 0.10 end
  if specID == 251 then return 0.35, 0.70, 1.00 end
  if specID == 252 then return 0.20, 0.95, 0.35 end
  return 0.7, 0.7, 0.7
end

local function IndexedColor(i, max)
  if max <= 1 then return 1, 1, 1 end
  local t = (i - 1) / (max - 1)
  local r = 1.0
  local g = math.min(1, 0.1 + 0.9 * t)
  local b = math.max(0, 0.05 + 0.25 * (1 - t))
  return r, g, b
end

local function GetChargedPoints()
  if not GetUnitChargedPowerPoints then return nil end
  return GetUnitChargedPowerPoints("player")
end

local function SegmentColor(i, max, ptype, class, specID, chargedPoints)
  if ptype == Enum.PowerType.Runes then
    return RuneSpecColor(specID)
  end
  if ptype == Enum.PowerType.ComboPoints or ptype == Enum.PowerType.Chi or ptype == Enum.PowerType.ArcaneCharges then
    if ptype == Enum.PowerType.ComboPoints and chargedPoints then
      for _, idx in ipairs(chargedPoints) do
        if idx == i then return unpack(CHARGED_CP_COLOR) end
      end
    end
    return IndexedColor(i, max)
  end
  local base = RESOURCE_BASE_COLORS[ptype]
  if base then return unpack(base) end
  return addon:PowerColorBy(ptype)
end

local function UpdateSegmentsAdvanced(ptype, max, partial)
  if not max or max <= 0 then
    HideAllSegments(1)
    UI.power:Hide()
    return
  end

  local w = addon.db.profile.width
  local gap = addon.db.profile.powerSpacing or 1
  local segW = (w - gap * (max - 1)) / max

  local _, class = UnitClass("player")
  local spec = GetSpecialization()
  local specID = spec and GetSpecializationInfo(spec) or 0
  local charged = (ptype == Enum.PowerType.ComboPoints and class == "ROGUE") and GetChargedPoints() or nil
  local cur = UnitPower("player", ptype, partial and true or false)

  local whole, frac = 0, 0
  if partial then
    local mod   = UnitPowerDisplayMod(ptype) or 1
    local exact = cur / mod
    whole       = math.floor(exact)
    frac        = exact - whole
  end

  for i = 1, max do
    local sb = EnsureSegment(i)
    sb:SetStatusBarTexture(addon:FetchStatusbar())
    sb:SetSize(segW, addon.db.profile.height.power)
    sb:ClearAllPoints()
    if i == 1 then
      sb:SetPoint("LEFT", UI.power, "LEFT", 0, 0)
    else
      sb:SetPoint("LEFT", UI.powerSegments[i - 1], "RIGHT", gap, 0)
    end
    local r, g, b = SegmentColor(i, max, ptype, class, specID, charged)
    sb:SetStatusBarColor(r, g, b)
    sb:SetMinMaxValues(0, 1)
    sb:Show()

    if partial then
      if i <= whole then
        sb:SetValue(1)
      elseif i == whole + 1 then
        sb:SetValue(frac)
      else
        sb:SetValue(0)
      end
    else
      sb:SetValue(cur >= i and 1 or 0)
    end
  end
  HideAllSegments(max + 1)
end

local function UpdateEssenceSegments(ptype)
  local max = UnitPowerMax("player", ptype)
  if not max or max <= 0 then
    HideAllSegments(1)
    UI.power:Hide()
    return
  end
  local w = addon.db.profile.width
  local gap = addon.db.profile.powerSpacing or 1
  local segW = (w - gap * (max - 1)) / max
  local cur = UnitPower("player", ptype)
  local partial = UnitPartialPower and (UnitPartialPower("player", ptype) or 0) or 0
  local nextFrac = partial / 1000.0
  local base = RESOURCE_BASE_COLORS[ptype] or { 0.5, 1, 0.9 }
  local r, g, b = base[1], base[2], base[3]
  for i = 1, max do
    local sb = EnsureSegment(i)
    sb:SetStatusBarTexture(addon:FetchStatusbar())
    sb:SetSize(segW, addon.db.profile.height.power)
    sb:ClearAllPoints()
    if i == 1 then
      sb:SetPoint("LEFT", UI.power, "LEFT", 0, 0)
    else
      sb:SetPoint("LEFT", UI.powerSegments[i - 1], "RIGHT", gap, 0)
    end
    sb:SetMinMaxValues(0, 1)
    sb:SetStatusBarColor(r, g, b)
    sb:Show()
    if i <= cur then
      sb:SetValue(1)
    elseif i == cur + 1 and cur < max then
      sb:SetValue(nextFrac)
    else
      sb:SetValue(0)
    end
  end
  HideAllSegments(max + 1)
end

local function UpdateRunes()
  local spec = GetSpecialization()
  local specID = spec and GetSpecializationInfo(spec) or 0
  local rr, rg, rb = RuneSpecColor(specID)
  local gap = 2
  local max = 6
  local w = addon.db.profile.width
  local segW = (w - gap * (max - 1)) / max
  for i = 1, max do
    local sb = EnsureSegment(i)
    sb:SetStatusBarTexture(addon:FetchStatusbar())
    sb:SetSize(segW, addon.db.profile.height.power)
    sb:ClearAllPoints()
    if i == 1 then
      sb:SetPoint("LEFT", UI.power, "LEFT", 0, 0)
    else
      sb:SetPoint("LEFT", UI.powerSegments[i - 1], "RIGHT", gap, 0)
    end
    local start, duration, ready = GetRuneCooldown(i)
    sb:SetMinMaxValues(0, 1)
    if ready then
      sb:SetValue(1)
      sb:SetStatusBarColor(rr, rg, rb)
    elseif start and duration and duration > 0 then
      local elapsed = GetTime() - start
      sb:SetValue(math.min(elapsed / duration, 1))
      sb:SetStatusBarColor(rr * 0.5, rg * 0.5, rb * 0.5)
    else
      sb:SetValue(1)
      sb:SetStatusBarColor(rr, rg, rb)
    end
    sb:Show()
  end
  HideAllSegments(max + 1)
end

local function ResolveSpecialPower()
  local _, class = UnitClass("player")
  local spec = GetSpecialization()
  local specID = spec and GetSpecializationInfo(spec) or 0
  local ptype = CLASS_POWER_ID[class]
  if not ptype then return nil end
  if REQUIRED_SPEC[class] and specID ~= REQUIRED_SPEC[class] then return nil end
  if class == "DRUID" and select(1, UnitPowerType("player")) ~= Enum.PowerType.Energy then
    return nil
  end
  return ptype, specID
end

function addon:UpdateSpecialPower()
  if not self.db.profile.show.power then return end
  local ptype, specID = ResolveSpecialPower()
  if not ptype then
    HideAllSegments(1)
    UI.power:Hide()
    return
  end
  UI.power:Show()
  if ptype == Enum.PowerType.Runes then
    UpdateRunes()
    return
  elseif ptype == Enum.PowerType.Essence then
    UpdateEssenceSegments(ptype)
    return
  end
  local max = UnitPowerMax("player", ptype) or 0
  local usePartial = USES_PARTIAL_BY_SPEC[specID] or false
  UpdateSegmentsAdvanced(ptype, max, usePartial)
end
