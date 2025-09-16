-- ClassHUD_Classbar.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

-- ========= Advanced Class Resource System =========

-- Map classes → special resource power types
local CLASS_POWER_ID = {
  MONK        = Enum.PowerType.Chi,
  PALADIN     = Enum.PowerType.HolyPower,
  WARLOCK     = Enum.PowerType.SoulShards,
  ROGUE       = Enum.PowerType.ComboPoints,
  DRUID       = Enum.PowerType.ComboPoints,   -- (cat form only)
  MAGE        = Enum.PowerType.ArcaneCharges, -- (Arcane only)
  EVOKER      = Enum.PowerType.Essence,
  DEATHKNIGHT = Enum.PowerType.Runes,
}

-- Specs that “unlock” the resource
local REQUIRED_SPEC = {
  MONK = 269, -- Windwalker
  MAGE = 62,  -- Arcane
}

-- Specs that use partial resource (e.g., Destruction shards)
local USES_PARTIAL_BY_SPEC = {
  [267] = true, -- Warlock Destruction
}

-- Charged Combo Points highlight color (Rogue)
local CHARGED_CP_COLOR = { 1.0, 0.95, 0.35 }

-- Base resource colors
local RESOURCE_BASE_COLORS = {
  [Enum.PowerType.HolyPower]     = { 1.00, 0.88, 0.25 },
  [Enum.PowerType.SoulShards]    = { 0.60, 0.22, 1.00 },
  [Enum.PowerType.ArcaneCharges] = { 0.25, 0.60, 1.00 },
  [Enum.PowerType.Essence]       = { 0.50, 1.00, 0.90 },
}

-- DK rune colors by spec
local function RuneSpecColor(specID)
  if specID == 250 then return 0.75, 0.10, 0.10 end -- Blood
  if specID == 251 then return 0.35, 0.70, 1.00 end -- Frost
  if specID == 252 then return 0.20, 0.95, 0.35 end -- Unholy
  return 0.7, 0.7, 0.7
end

-- Per-index color for CP/Chi/Arcane
local function IndexedColor(i, max)
  if max <= 1 then return 1, 1, 1 end
  local t = (i - 1) / (max - 1)
  local r = 1.0
  local g = math.min(1, 0.1 + 0.9 * t)
  local b = math.max(0, 0.05 + 0.25 * (1 - t))
  return r, g, b
end

-- Get charged CP indices (Rogue)
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
  return ClassHUD:PowerColorBy(ptype)
end

local function EnsureSegment(i)
  if not UI.powerSegments[i] then
    local sb = ClassHUD:CreateStatusBar(UI.power, ClassHUD.db.profile.height.power)
    sb.text:Hide() -- segments don’t need text
    UI.powerSegments[i] = sb
  end
  return UI.powerSegments[i]
end

local function HideAllSegments(from)
  for i = from, #UI.powerSegments do
    if UI.powerSegments[i] then UI.powerSegments[i]:Hide() end
  end
end

-- Advanced segment updater
function ClassHUD:UpdateSegmentsAdvanced(ptype, max, partial)
  local w = self.db.profile.width
  local gap = self.db.profile.powerSpacing or 1
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
    sb:SetStatusBarTexture(self:FetchStatusbar())
    sb:SetSize(segW, self.db.profile.height.power)
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

-- Essence updater (with fractional preview)
function ClassHUD:UpdateEssenceSegments(ptype)
  local max = UnitPowerMax("player", ptype)
  if not max or max <= 0 then
    HideAllSegments(1); UI.power:Hide(); return
  end
  local w = self.db.profile.width
  local gap = self.db.profile.powerSpacing or 1
  local segW = (w - gap * (max - 1)) / max
  local cur = UnitPower("player", ptype)
  local partial = UnitPartialPower and (UnitPartialPower("player", ptype) or 0) or 0
  local nextFrac = partial / 1000.0
  local base = RESOURCE_BASE_COLORS[ptype] or { 0.5, 1, 0.9 }
  local r, g, b = base[1], base[2], base[3]
  for i = 1, max do
    local sb = EnsureSegment(i)
    sb:SetStatusBarTexture(self:FetchStatusbar())
    sb:SetSize(segW, self.db.profile.height.power)
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

-- Resolve which special power to show
local function ResolveSpecialPower()
  local _, class = UnitClass("player")
  local spec = GetSpecialization()
  local specID = spec and GetSpecializationInfo(spec) or 0
  local ptype = CLASS_POWER_ID[class]
  if REQUIRED_SPEC[class] and specID ~= REQUIRED_SPEC[class] then return nil end
  if class == "DRUID" and select(1, UnitPowerType("player")) ~= Enum.PowerType.Energy then
    return nil
  end
  return ptype, specID
end

-- Main update entry
function ClassHUD:UpdateSpecialPower()
  if not self.db.profile.show.power then return end
  local ptype, specID = ResolveSpecialPower()
  if not ptype then
    HideAllSegments(1); UI.power:Hide(); return
  end
  UI.power:Show()
  if ptype == Enum.PowerType.Runes then
    self:UpdateRunes()
    return
  elseif ptype == Enum.PowerType.Essence then
    self:UpdateEssenceSegments(ptype)
    return
  end
  local max = UnitPowerMax("player", ptype) or 0
  local usePartial = USES_PARTIAL_BY_SPEC[specID] or false
  self:UpdateSegmentsAdvanced(ptype, max, usePartial)
end

function ClassHUD:UpdateRunes()
  -- 6 runes; each rune shows its cooldown fill
  local w = 250
  local spec = GetSpecialization()
  local specID = spec and GetSpecializationInfo(spec) or 0
  local rr, rg, rb = RuneSpecColor and RuneSpecColor(specID) or 0.7, 0.7, 0.7
  local gap = 2
  local max = 6
  local segW = (w - gap * (max - 1)) / max
  for i = 1, max do
    local sb = EnsureSegment(i)
    sb:SetStatusBarTexture(self:FetchStatusbar())
    sb:SetSize(segW, 16)
    sb:ClearAllPoints()
    if i == 1 then
      sb:SetPoint("LEFT", UI.power, "LEFT", 0, 0)
    else
      sb:SetPoint("LEFT", UI.powerSegments[i - 1], "RIGHT", gap, 0)
    end
    local start, duration, ready = GetRuneCooldown(i)
    sb:SetMinMaxValues(0, 1)
    if ready then
      sb:SetValue(1); sb:SetStatusBarColor(rr, rg, rb)
    elseif start and duration and duration > 0 then
      local elapsed = GetTime() - start
      sb:SetValue(math.min(elapsed / duration, 1))
      sb:SetStatusBarColor(rr * 0.5, rg * 0.5, rb * 0.5)
    else
      sb:SetValue(1); sb:SetStatusBarColor(rr, rg, rb)
    end
    sb:Show()
  end
  HideAllSegments(max + 1)
end
