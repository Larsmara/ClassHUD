-- ClassHUD_Classbar.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

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
  [267] = true, -- Destruction Warlock shards
}

-- Charged Combo Points highlight color (Rogue)
local CHARGED_CP_COLOR = { 1.0, 0.95, 0.35 }

-- Base resource colors for themed powers
local RESOURCE_BASE_COLORS = {
  [Enum.PowerType.HolyPower]     = { 1.00, 0.88, 0.25 },
  [Enum.PowerType.SoulShards]    = { 0.60, 0.22, 1.00 },
  [Enum.PowerType.ArcaneCharges] = { 0.25, 0.60, 1.00 },
  [Enum.PowerType.Essence]       = { 0.50, 1.00, 0.90 },
}

local function RuneSpecColor(specID)
  if specID == 250 then return 0.75, 0.10, 0.10 end -- Blood
  if specID == 251 then return 0.35, 0.70, 1.00 end -- Frost
  if specID == 252 then return 0.20, 0.95, 0.35 end -- Unholy
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

local function EnsureSegment(addon, index)
  local bar = addon.bars and addon.bars.class
  if not bar then return nil end
  bar.segments = bar.segments or {}
  local segment = bar.segments[index]
  if not segment then
    segment = CreateFrame("StatusBar", nil, bar)
    segment:SetMinMaxValues(0, 1)
    segment.bg = segment:CreateTexture(nil, "BACKGROUND")
    segment.bg:SetAllPoints(segment)
    segment.bg:SetColorTexture(0, 0, 0, 0.6)
    bar.segments[index] = segment
  end
  segment:SetStatusBarTexture(addon:FetchStatusbar())
  segment.bg:SetAllPoints(segment)
  return segment
end

local function HideSegments(addon, from)
  local bar = addon.bars and addon.bars.class
  if not bar or not bar.segments then return end
  for i = from, #bar.segments do
    if bar.segments[i] then bar.segments[i]:Hide() end
  end
end

local function LayoutSegments(addon, count)
  local bar = addon.bars and addon.bars.class
  if not bar then return end
  if count <= 0 then
    HideSegments(addon, 1)
    bar:Hide()
    return
  end

  local profile = addon.db and addon.db.profile or {}
  local width = profile.width or 250
  local spacing = profile.powerSpacing
  if spacing == nil then spacing = profile.spacing or 0 end
  local height = (profile.height and profile.height.class) or 14
  local segWidth = (width - spacing * (count - 1)) / count
  if segWidth < 1 then segWidth = 1 end

  for i = 1, count do
    local segment = EnsureSegment(addon, i)
    segment:SetSize(segWidth, height)
    segment:ClearAllPoints()
    if i == 1 then
      segment:SetPoint("LEFT", bar, "LEFT", 0, 0)
    else
      segment:SetPoint("LEFT", bar.segments[i - 1], "RIGHT", spacing, 0)
    end
    segment:SetMinMaxValues(0, 1)
    segment:Show()
  end

  HideSegments(addon, count + 1)
  bar:Show()
end

local function SegmentColor(ptype, index, max, chargedLookup)
  if ptype == Enum.PowerType.ComboPoints and chargedLookup and chargedLookup[index] then
    return unpack(CHARGED_CP_COLOR)
  end

  if RESOURCE_BASE_COLORS[ptype] then
    local color = RESOURCE_BASE_COLORS[ptype]
    return color[1], color[2], color[3]
  end

  return IndexedColor(index, max)
end

local function UpdateSegments(addon, ptype, max, specID)
  if max <= 0 then
    HideSegments(addon, 1)
    if addon.bars and addon.bars.class then addon.bars.class:Hide() end
    return
  end

  LayoutSegments(addon, max)

  local bar = addon.bars and addon.bars.class
  if not bar then return end

  local charged = (ptype == Enum.PowerType.ComboPoints) and GetChargedPoints() or nil
  local chargedLookup
  if charged then
    chargedLookup = {}
    for _, idx in ipairs(charged) do
      chargedLookup[idx] = true
    end
  end

  local usesPartial = USES_PARTIAL_BY_SPEC[specID] or false
  local current = UnitPower("player", ptype, usesPartial and true or false)
  local mod = UnitPowerDisplayMod and UnitPowerDisplayMod(ptype) or 1
  local exact = usesPartial and (current / mod) or current
  local whole = usesPartial and math.floor(exact) or exact
  local frac = usesPartial and (exact - whole) or 0

  for i = 1, max do
    local segment = EnsureSegment(addon, i)
    local r, g, b = SegmentColor(ptype, i, max, chargedLookup)
    segment:SetStatusBarColor(r, g, b)

    if usesPartial then
      if i <= whole then
        segment:SetValue(1)
      elseif i == whole + 1 then
        segment:SetValue(frac)
      else
        segment:SetValue(0)
      end
    else
      segment:SetValue(exact >= i and 1 or 0)
    end
    segment:Show()
  end

  bar:Show()
end

local function UpdateRunes(addon, specID)
  local bar = addon.bars and addon.bars.class
  if not bar then return end
  LayoutSegments(addon, 6)

  local r, g, b = RuneSpecColor(specID)
  for i = 1, 6 do
    local segment = EnsureSegment(addon, i)
    local start, duration, ready = GetRuneCooldown(i)
    if ready or not start or duration == 0 then
      segment:SetValue(1)
      segment:SetStatusBarColor(r, g, b)
    else
      local progress = (GetTime() - start) / duration
      segment:SetValue(math.min(progress, 1))
      segment:SetStatusBarColor(r * 0.6, g * 0.6, b * 0.6)
    end
    segment:Show()
  end

  bar:Show()
end

local function UpdateEssence(addon, ptype)
  local bar = addon.bars and addon.bars.class
  if not bar then return end
  local max = UnitPowerMax("player", ptype)
  if not max or max <= 0 then
    HideSegments(addon, 1)
    bar:Hide()
    return
  end

  LayoutSegments(addon, max)

  local current = UnitPower("player", ptype)
  local partial = UnitPartialPower and (UnitPartialPower("player", ptype) or 0) or 0
  local nextFrac = partial / 1000
  local base = RESOURCE_BASE_COLORS[ptype] or { 0.5, 1.0, 0.9 }

  for i = 1, max do
    local segment = EnsureSegment(addon, i)
    segment:SetStatusBarColor(base[1], base[2], base[3])
    if i <= current then
      segment:SetValue(1)
    elseif i == current + 1 then
      segment:SetValue(math.min(nextFrac, 1))
    else
      segment:SetValue(0)
    end
    segment:Show()
  end

  bar:Show()
end

local function ResolveSpecialPower()
  local _, class = UnitClass("player")
  local spec = GetSpecialization()
  local specID = spec and GetSpecializationInfo(spec) or 0
  local ptype = CLASS_POWER_ID[class]
  if not ptype then return nil end

  if REQUIRED_SPEC[class] and specID ~= REQUIRED_SPEC[class] then
    return nil
  end

  if class == "DRUID" and select(1, UnitPowerType("player")) ~= Enum.PowerType.Energy then
    return nil
  end

  return ptype, specID
end

function ClassHUD:UpdateClassBar()
  if not self:IsBarEnabled("class") then
    if self.bars and self.bars.class then
      self.bars.class:Hide()
      HideSegments(self, 1)
    end
    return
  end

  self:EnsureBars()

  local bar = self.bars and self.bars.class
  if not bar then return end

  local ptype, specID = ResolveSpecialPower()
  if not ptype then
    HideSegments(self, 1)
    bar:Hide()
    return
  end

  bar:Show()
  UI.power = bar

  if ptype == Enum.PowerType.Runes then
    UpdateRunes(self, specID)
    return
  end

  if ptype == Enum.PowerType.Essence then
    UpdateEssence(self, ptype)
    return
  end

  local max = UnitPowerMax("player", ptype) or 0
  UpdateSegments(self, ptype, max, specID)
end

-- Backwards compatibility for callers still using the old name
function ClassHUD:UpdateSpecialPower()
  self:UpdateClassBar()
end

