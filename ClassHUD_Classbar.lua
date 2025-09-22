-- ClassHUD_Classbar.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI
UI.attachments = UI.attachments or {}

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

-- ========= BALANCE DRUID: ECLIPSE =========
local specID_BALANCE       = 102
local ECLIPSE_SOLAR        = 48517
local ECLIPSE_LUNAR        = 48518
local LUNAR_CALLING_TALENT = 429523

-- Wrath / Starfire IDs (kan variere, vi tar begge)
local WRATH_IDS            = { [5176] = true, [190984] = true }
local STARFIRE_IDS         = { [194153] = true, [197628] = true }

local function HasLunarCalling()
  return C_Spell.IsPlayerSpell and C_Spell.IsPlayerSpell(LUNAR_CALLING_TALENT) or false
end

-- Aura sjekk (returner type og remaining)
local function QueryEclipseAuras()
  local solar = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(ECLIPSE_SOLAR)
  local lunar = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(ECLIPSE_LUNAR)
  if solar and lunar then
    local remain = math.max((solar.expirationTime or 0), (lunar.expirationTime or 0)) - GetTime()
    return "BOTH", remain
  elseif solar then
    return "SOLAR", (solar.expirationTime or 0) - GetTime()
  elseif lunar then
    return "LUNAR", (lunar.expirationTime or 0) - GetTime()
  end
  return nil
end

-- Reset til idle state (ingen aura aktiv)
local function ResetEclipseBar(f)
  f.activeType, f.remaining = nil, nil
  f:SetScript("OnUpdate", nil)

  -- Skjul store aktive bars
  f.activeBars.SOLAR:Hide()
  f.activeBars.LUNAR:Hide()

  for i, seg in ipairs(f.segments) do
    seg:Hide()
    seg:SetValue(0)
    if seg.text then seg.text:SetText("") end
  end

  -- Wrath (Solar side)
  local wrathCount = C_Spell.GetSpellCastCount and C_Spell.GetSpellCastCount(190984) or 2
  if wrathCount then
    for i = 1, 2 do
      local seg = f.segments[i]
      seg:Show()
      if i <= wrathCount then
        seg:SetValue(1)
        seg:SetStatusBarColor(1.0, 0.9, 0.3)
      else
        seg:SetValue(0)
        seg:SetStatusBarColor(0.2, 0.2, 0.2)
      end
      seg.text:SetText("") -- fjern alltid tekst
    end
    -- alltid tekst på ytterste
    f.segments[1].text:SetText(wrathCount)
  end

  -- Starfire (Lunar side)
  if not HasLunarCalling() then
    local starfireCount = C_Spell.GetSpellCastCount and C_Spell.GetSpellCastCount(194153) or 2
    if starfireCount then
      for i = 3, 4 do
        local seg = f.segments[i]
        seg:Show()
        if (i - 2) <= starfireCount then
          seg:SetValue(1)
          seg:SetStatusBarColor(0.6, 0.4, 1.0)
        else
          seg:SetValue(0)
          seg:SetStatusBarColor(0.2, 0.2, 0.2)
        end
        seg.text:SetText("")
      end
      -- alltid tekst på ytterste
      f.segments[4].text:SetText(starfireCount)
    end
  else
    for i = 3, 4 do
      local seg = f.segments[i]
      seg:Show()
      seg:SetValue(0)
      seg:SetStatusBarColor(0.2, 0.2, 0.2)
      seg.text:SetText("")
    end
  end

  f.cooldownText:SetText("")
end



-- Oppdater countdown mens Eclipse er aktiv
local function OnUpdateEclipse(self, elapsed)
  if not self.remaining or not self.activeType then return end
  self.remaining = self.remaining - elapsed
  if self.remaining <= 0 then
    ResetEclipseBar(self)
    return
  end

  local frac = math.max(0, math.min(1, self.remaining / 15))
  self.cooldownText:SetText(math.ceil(self.remaining))

  if self.activeType == "SOLAR" then
    self.activeBars.SOLAR:SetValue(frac)
  elseif self.activeType == "LUNAR" then
    self.activeBars.LUNAR:SetValue(frac)
  elseif self.activeType == "BOTH" then
    self.activeBars.SOLAR:SetValue(frac)
    self.activeBars.LUNAR:SetValue(frac)
  end
end


-- Start Eclipse state (active)
local function TriggerEclipse(f, eclipseType, remain)
  f.activeType = eclipseType
  f.remaining  = remain or 15
  f:SetScript("OnUpdate", OnUpdateEclipse)

  -- Skjul idle-segmentene
  for i, seg in ipairs(f.segments) do
    seg:Hide()
    if seg.text then seg.text:SetText("") end
  end

  -- Skjul aktive bars først
  f.activeBars.SOLAR:Hide()
  f.activeBars.LUNAR:Hide()

  local frac = math.max(0, math.min(1, (remain or 15) / 15))

  if eclipseType == "SOLAR" then
    f.activeBars.SOLAR:SetValue(frac)
    f.activeBars.SOLAR:Show()
  elseif eclipseType == "LUNAR" then
    f.activeBars.LUNAR:SetValue(frac)
    f.activeBars.LUNAR:Show()
  elseif eclipseType == "BOTH" then
    f.activeBars.SOLAR:SetValue(frac)
    f.activeBars.LUNAR:SetValue(frac)
    f.activeBars.SOLAR:Show()
    f.activeBars.LUNAR:Show()
  end
end


-- Create container
local function CreateEclipseBar(parent)
  local f = CreateFrame("Frame", "ClassHUD_EclipseBar", parent, "BackdropTemplate")
  local width = ClassHUD.db and ClassHUD.db.profile.width or 250
  f:SetSize(width, 20)
  f:Hide()

  -- Backdrop for hele containeren
  f:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  f:SetBackdropColor(0, 0, 0, 0.6)     -- mørk bakgrunn
  f:SetBackdropBorderColor(0, 0, 0, 1) -- sort ramme

  f.segments = {}
  f.activeBars = {}

  local segW = width / 4

  -- Idle-segmenter (2 per side)
  for i = 1, 4 do
    local seg = CreateFrame("StatusBar", nil, f)
    seg:SetStatusBarTexture(ClassHUD:FetchStatusbar())
    seg:SetMinMaxValues(0, 1)
    seg:SetValue(1)
    seg:SetSize(segW - 1, f:GetHeight())
    seg:SetPoint("LEFT", f, "LEFT", (i - 1) * segW, 0)

    if i <= 2 then
      seg:SetStatusBarColor(0.3, 0.3, 0.3) -- idle grå
    else
      seg:SetStatusBarColor(0.3, 0.3, 0.3)
    end

    seg.text = seg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    seg.text:SetPoint("CENTER")

    f.segments[i] = seg
  end

  -- Store aktive bars (halv side hver)
  f.activeBars.SOLAR = CreateFrame("StatusBar", nil, f)
  f.activeBars.SOLAR:SetStatusBarTexture(ClassHUD:FetchStatusbar())
  f.activeBars.SOLAR:SetMinMaxValues(0, 1)
  f.activeBars.SOLAR:SetSize(width / 2, f:GetHeight())
  f.activeBars.SOLAR:SetPoint("LEFT", f, "LEFT", 0, 0)
  f.activeBars.SOLAR:SetStatusBarColor(1.0, 0.9, 0.3)
  f.activeBars.SOLAR:SetOrientation("HORIZONTAL")
  f.activeBars.SOLAR:SetReverseFill(true) -- 👈 endringen
  f.activeBars.SOLAR:Hide()

  f.activeBars.LUNAR = CreateFrame("StatusBar", nil, f)
  f.activeBars.LUNAR:SetStatusBarTexture(ClassHUD:FetchStatusbar())
  f.activeBars.LUNAR:SetMinMaxValues(0, 1)
  f.activeBars.LUNAR:SetSize(width / 2, f:GetHeight())
  f.activeBars.LUNAR:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  f.activeBars.LUNAR:SetStatusBarColor(0.6, 0.4, 1.0)
  f.activeBars.LUNAR:Hide()

  -- Etter at du har laget segmentene og activeBars:
  local overlay = CreateFrame("Frame", nil, f)
  overlay:SetAllPoints(f)
  overlay:SetFrameLevel(f:GetFrameLevel() + 10)

  f.cooldownText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.cooldownText:SetPoint("CENTER", overlay, "CENTER")



  ResetEclipseBar(f)
  return f
end

-- Init
function ClassHUD:InitBalanceEclipse()
  if select(2, UnitClass("player")) ~= "DRUID" then return end
  local spec = GetSpecialization()
  if (spec and GetSpecializationInfo(spec) or 0) ~= specID_BALANCE then return end

  if not UI.eclipseBar then
    UI.eclipseBar = CreateEclipseBar(UI.anchor or UIParent)
    UI.eclipseBar:SetPoint("TOP", UI.resource or UI.anchor or UIParent, "BOTTOM", 0, -4)
    UI.eclipseBar:Show()
  end

  ResetEclipseBar(UI.eclipseBar)

  -- Sync ved innlasting
  local etype, remain = QueryEclipseAuras()
  if etype then TriggerEclipse(UI.eclipseBar, etype, remain) end
end

-- Event handler
function ClassHUD:HandleEclipseEvent(event, unit, spellID)
  local f = UI.eclipseBar
  if not f or unit ~= "player" then return end

  if event == "UNIT_AURA" then
    local etype, remain = QueryEclipseAuras()
    if etype then
      TriggerEclipse(f, etype, remain)
    else
      ResetEclipseBar(f)
    end
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- hopp helt over hvis aura er aktiv
    local etype = QueryEclipseAuras()
    if etype then return end

    -- ellers idle-state precast refresh
    if WRATH_IDS[spellID] then
      ResetEclipseBar(f)
    elseif STARFIRE_IDS[spellID] and not HasLunarCalling() then
      ResetEclipseBar(f)
    end
  end
end
