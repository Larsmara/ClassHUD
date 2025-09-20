-- ClassHUD_Bars.lua
-- Cast, primary resource and class resource bars.

---@type ClassHUDAddon
local ClassHUD = _G.ClassHUD

local barsDefaults = {
  texture = "Interface\\TargetingFrame\\UI-StatusBar",
  font = "Fonts\\FRIZQT__.TTF",
}

local function GetBarTexture()
  local cfg = ClassHUD:GetBarsConfig()
  return cfg.texture or barsDefaults.texture
end

local function GetFontPath()
  local cfg = ClassHUD:GetBarsConfig()
  return cfg.font or barsDefaults.font
end

local function CreateStatusBar(name)
  local bar = CreateFrame("StatusBar", name, UIParent, "BackdropTemplate")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar.bg:SetColorTexture(0, 0, 0, 0.6)
  bar:SetStatusBarTexture(GetBarTexture())
  return bar
end

local function SetFont(fs, size)
  if not fs then return end
  fs:SetFont(GetFontPath(), size or 12, "OUTLINE")
  fs:SetShadowOffset(0, 0)
end

function ClassHUD:CreateBars()
  if self.bars then
    return
  end

  self.bars = {}
  local cfg = self:GetBarsConfig()

  -- Cast bar ---------------------------------------------------------------
  local cast = CreateStatusBar("ClassHUDCastBar")
  cast.icon = cast:CreateTexture(nil, "OVERLAY")
  cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  cast.spell = cast:CreateFontString(nil, "OVERLAY")
  cast.spell:SetJustifyH("LEFT")
  cast.time = cast:CreateFontString(nil, "OVERLAY")
  cast.time:SetJustifyH("RIGHT")
  cast:Hide()
  self.bars.cast = cast

  -- Health bar ------------------------------------------------------------
  local health = CreateStatusBar("ClassHUDHealthBar")
  health.value = health:CreateFontString(nil, "OVERLAY")
  health.value:SetJustifyH("CENTER")
  health.value:SetPoint("CENTER")
  self.bars.health = health

  -- Primary resource ------------------------------------------------------
  local resource = CreateStatusBar("ClassHUDResourceBar")
  resource.value = resource:CreateFontString(nil, "OVERLAY")
  resource.value:SetJustifyH("CENTER")
  resource.value:SetPoint("CENTER")
  self.bars.resource = resource

  -- Class resource --------------------------------------------------------
  local class = CreateFrame("Frame", "ClassHUDClassBar", UIParent, "BackdropTemplate")
  class:SetClipsChildren(true)
  class.segments = {}
  class.cooldowns = {}
  self.bars.class = class

  self:ApplyBarVisuals()
end

function ClassHUD:ApplyBarVisuals()
  if not self.bars then return end
  local cfg = self:GetBarsConfig()
  local castCfg = cfg.cast or {}
  local resourceCfg = cfg.resource or {}

  local texture = GetBarTexture()

  local cast = self.bars.cast
  if cast then
    cast:SetStatusBarTexture(texture)
    local tex = cast:GetStatusBarTexture()
    if tex then
      tex:ClearAllPoints()
      tex:SetPoint("TOPLEFT", cast, "TOPLEFT", castCfg.height or 0, 0)
      tex:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", 0, 0)
    end
    cast.bg:ClearAllPoints()
    cast.bg:SetPoint("TOPLEFT", cast, "TOPLEFT", castCfg.height or 0, 0)
    cast.bg:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", 0, 0)
    cast.icon:SetSize(castCfg.height or 16, castCfg.height or 16)
    cast.icon:ClearAllPoints()
    cast.icon:SetPoint("LEFT", cast, "LEFT", 0, 0)
    cast.spell:ClearAllPoints()
    cast.spell:SetPoint("LEFT", cast.icon, "RIGHT", 4, 0)
    cast.spell:SetPoint("RIGHT", cast.time, "LEFT", -4, 0)
    cast.spell:SetTextColor(1, 1, 1)
    cast.time:ClearAllPoints()
    cast.time:SetPoint("RIGHT", cast, "RIGHT", -4, 0)
    cast.time:SetTextColor(1, 1, 1)
    SetFont(cast.spell, castCfg.textSize or 12)
    SetFont(cast.time, castCfg.textSize or 12)
  end

  local resource = self.bars.resource
  if resource then
    resource:SetStatusBarTexture(texture)
    resource.bg:ClearAllPoints()
    resource.bg:SetAllPoints(resource)
    SetFont(resource.value, resourceCfg.textSize or 12)
    resource.value:SetTextColor(1, 1, 1)
  end

  local health = self.bars.health
  if health then
    health:SetStatusBarTexture(texture)
    health.bg:ClearAllPoints()
    health.bg:SetAllPoints(health)
    local healthCfg = cfg.health or {}
    SetFont(health.value, healthCfg.textSize or 12)
    health.value:SetTextColor(1, 1, 1)
  end
end

-- Cast bar updates ---------------------------------------------------------
local function CastOnUpdate(self)
  if not self.startTime or not self.endTime then
    self:SetScript("OnUpdate", nil)
    self:Hide()
    return
  end

  local now = GetTime()
  local duration = self.endTime - self.startTime
  if self.isChannel then
    local remaining = self.endTime - now
    if remaining <= 0 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      return
    end
    self:SetMinMaxValues(0, duration)
    self:SetValue(remaining)
    self.time:SetFormattedText("%.1f", math.max(0, remaining))
  else
    local elapsed = now - self.startTime
    if elapsed >= duration then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      return
    end
    self:SetMinMaxValues(0, duration)
    self:SetValue(elapsed)
    self.time:SetFormattedText("%.1f", math.max(0, duration - elapsed))
  end
end

function ClassHUD:StopCast()
  if self._barsPreviewing then return end
  if not (self.bars and self.bars.cast) then return end
  local cast = self.bars.cast
  cast:SetScript("OnUpdate", nil)
  cast:Hide()
  cast.spell:SetText("")
  cast.time:SetText("")
  cast.startTime = nil
  cast.endTime = nil
end

function ClassHUD:StartCast(name, icon, startMS, endMS, isChannel)
  if not self:IsBarEnabled("cast") then return end
  if self._barsPreviewing then return end
  if not (self.bars and self.bars.cast) then return end

  local cast = self.bars.cast
  local start = (startMS or 0) / 1000
  local finish = (endMS or 0) / 1000
  if finish <= start then
    finish = start + 0.1
  end

  cast.startTime = start
  cast.endTime = finish
  cast.isChannel = isChannel and true or false
  cast.spell:SetText(name or "")
  cast.icon:SetTexture(icon or 136243)
  cast.time:SetText("")

  if cast.isChannel then
    local remaining = finish - GetTime()
    cast:SetMinMaxValues(0, finish - start)
    cast:SetValue(math.max(0, remaining))
  else
    cast:SetMinMaxValues(0, finish - start)
    cast:SetValue(0)
  end

  cast:SetScript("OnUpdate", CastOnUpdate)
  cast:Show()
end

function ClassHUD:UNIT_SPELLCAST_START(unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitCastingInfo("player")
  if name then
    self:StartCast(name, icon, startMS, endMS, false)
  end
end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_START(unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitChannelInfo("player")
  if name then
    self:StartCast(name, icon, startMS, endMS, true)
  end
end

function ClassHUD:UNIT_SPELLCAST_STOP(unit)
  if unit == "player" then
    self:StopCast()
  end
end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(unit)
  if unit == "player" then
    self:StopCast()
  end
end

function ClassHUD:UNIT_SPELLCAST_INTERRUPTED(unit)
  if unit == "player" then
    self:StopCast()
  end
end

function ClassHUD:UNIT_SPELLCAST_FAILED(unit)
  if unit == "player" then
    self:StopCast()
  end
end

function ClassHUD:UNIT_SPELLCAST_EMPOWER_START(unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitChannelInfo("player")
  if name then
    self:StartCast(name, icon, startMS, endMS, true)
  end
end

function ClassHUD:UNIT_SPELLCAST_EMPOWER_STOP(unit)
  if unit == "player" then
    self:StopCast()
  end
end

function ClassHUD:UNIT_SPELLCAST_EMPOWER_INTERRUPTED(unit)
  if unit == "player" then
    self:StopCast()
  end
end

-- Health bar ----------------------------------------------------------------
local function GetClassColor()
  if not UnitClass then
    return 0.8, 0.2, 0.2
  end
  local _, class = UnitClass("player")
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if color then
    return color.r, color.g, color.b
  end
  return 0.8, 0.2, 0.2
end

function ClassHUD:UpdateHealthBar()
  if self._barsPreviewing then return end
  if not self:IsBarEnabled("health") then
    if self.bars and self.bars.health then
      self.bars.health:Hide()
    end
    return
  end

  if not (self.bars and self.bars.health) then return end
  local bar = self.bars.health
  local cur = UnitHealth("player") or 0
  local max = UnitHealthMax("player") or 0
  if max <= 0 then max = 1 end

  bar:SetMinMaxValues(0, max)
  bar:SetValue(cur)

  local r, g, b = GetClassColor()
  bar:SetStatusBarColor(r, g, b)

  local percent = (cur / max) * 100
  percent = percent >= 0 and percent or 0
  if BreakUpLargeNumbers then
    bar.value:SetFormattedText("%s / %s (%.0f%%)", BreakUpLargeNumbers(cur), BreakUpLargeNumbers(max), percent + 0.5)
  else
    bar.value:SetFormattedText("%d / %d (%.0f%%)", cur, max, percent + 0.5)
  end
  bar:Show()
end

-- Primary resource ---------------------------------------------------------
function ClassHUD:UpdateResourceBar()
  if self._barsPreviewing then return end
  if not self:IsBarEnabled("resource") then
    if self.bars and self.bars.resource then
      self.bars.resource:Hide()
    end
    return
  end

  if not (self.bars and self.bars.resource) then return end
  local resource = self.bars.resource
  local id, token = UnitPowerType("player")
  local cur = UnitPower("player", id)
  local max = UnitPowerMax("player", id)
  max = max > 0 and max or 1
  resource:SetMinMaxValues(0, max)
  resource:SetValue(cur)

  local color = (token and PowerBarColor[token]) or PowerBarColor[id]
  if color then
    resource:SetStatusBarColor(color.r, color.g, color.b)
  end

  if token == "MANA" then
    local pct = (cur / max) * 100
    resource.value:SetFormattedText("%d%%", pct + 0.5)
  else
    resource.value:SetText(cur)
  end
  resource:Show()
end

-- Class resource -----------------------------------------------------------
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
  MONK = 269, -- Windwalker
  MAGE = 62,  -- Arcane
}

local USES_PARTIAL_BY_SPEC = {
  [267] = true, -- Destruction Warlock shards
}

local function GetChargedPoints()
  if GetUnitChargedPowerPoints then
    return GetUnitChargedPowerPoints("player")
  end
end

local function ResolveSpecialPower()
  local _, class = UnitClass("player")
  local specIndex = GetSpecialization()
  local specID = specIndex and GetSpecializationInfo(specIndex) or 0
  local ptype = CLASS_POWER_ID[class]
  if REQUIRED_SPEC[class] and specID ~= REQUIRED_SPEC[class] then
    return nil
  end
  if class == "DRUID" then
    local current = select(1, UnitPowerType("player"))
    if current ~= Enum.PowerType.Energy then
      return nil
    end
  end
  return ptype, specID
end

local function EnsureSegment(bar, index)
  if not bar.segments[index] then
    local segment = CreateStatusBar(nil)
    segment:SetParent(bar)
    segment:SetMinMaxValues(0, 1)
    segment.bg:SetColorTexture(0, 0, 0, 0.7)
    bar.segments[index] = segment
  end
  local segment = bar.segments[index]
  segment:SetStatusBarTexture(GetBarTexture())
  return segment
end

local function HideSegments(bar, from)
  if not bar.segments then return end
  for i = from, #bar.segments do
    if bar.segments[i] then
      bar.segments[i]:Hide()
    end
  end
end

local function LayoutSegments(bar, count)
  local cfg = ClassHUD:GetBarsConfig()
  local spacing = (cfg.class and cfg.class.segmentSpacing) or 0
  local width = bar:GetWidth()
  if width <= 0 then width = cfg.width or 250 end
  local height = (cfg.class and cfg.class.height) or 16
  if count <= 0 then return end
  local segWidth = (width - spacing * (count - 1)) / count
  for i = 1, count do
    local segment = EnsureSegment(bar, i)
    segment:ClearAllPoints()
    segment:SetSize(segWidth, height)
    if i == 1 then
      segment:SetPoint("LEFT", bar, "LEFT", 0, 0)
    else
      segment:SetPoint("LEFT", bar.segments[i - 1], "RIGHT", spacing, 0)
    end
    segment:Show()
  end
  HideSegments(bar, count + 1)
end

local function IndexedColor(i, max)
  if max <= 1 then return 1, 1, 1 end
  local t = (i - 1) / (max - 1)
  local r = 1.0
  local g = math.min(1, 0.2 + 0.8 * t)
  local b = math.max(0.1, 0.3 - 0.2 * t)
  return r, g, b
end

local function RuneSpecColor(specID)
  if specID == 250 then return 0.75, 0.10, 0.10 end -- Blood
  if specID == 251 then return 0.35, 0.70, 1.00 end -- Frost
  if specID == 252 then return 0.20, 0.95, 0.35 end -- Unholy
  return 0.7, 0.7, 0.7
end

local function UpdateSegments(ptype, max, specID)
  local bar = ClassHUD.bars.class
  if not bar then return end
  if max <= 0 then
    bar:Hide()
    return
  end
  LayoutSegments(bar, max)
  local charged = (ptype == Enum.PowerType.ComboPoints) and GetChargedPoints()
  local chargedLookup
  if charged then
    chargedLookup = {}
    for _, index in ipairs(charged) do
      chargedLookup[index] = true
    end
  end
  local current = UnitPower("player", ptype, USES_PARTIAL_BY_SPEC[specID] and true or false)
  local mod = UnitPowerDisplayMod and UnitPowerDisplayMod(ptype) or 1
  local exact = USES_PARTIAL_BY_SPEC[specID] and (current / mod) or current
  for i = 1, max do
    local segment = EnsureSegment(bar, i)
    segment:SetMinMaxValues(0, 1)
    local r, g, b
    if ptype == Enum.PowerType.HolyPower then
      r, g, b = 1.0, 0.9, 0.3
    elseif ptype == Enum.PowerType.SoulShards then
      r, g, b = 0.6, 0.2, 1.0
    elseif ptype == Enum.PowerType.ArcaneCharges then
      r, g, b = 0.25, 0.6, 1.0
    else
      r, g, b = IndexedColor(i, max)
    end
    if chargedLookup and chargedLookup[i] then
      r, g, b = 1.0, 0.95, 0.35
    end
    segment:SetStatusBarColor(r, g, b)
    if USES_PARTIAL_BY_SPEC[specID] then
      if i <= math.floor(exact) then
        segment:SetValue(1)
      elseif i == math.floor(exact) + 1 then
        segment:SetValue(exact % 1)
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

local function UpdateRunes(specID)
  local bar = ClassHUD.bars.class
  if not bar then return end
  local max = 6
  LayoutSegments(bar, max)
  local r, g, b = RuneSpecColor(specID)
  for i = 1, max do
    local segment = EnsureSegment(bar, i)
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

local function UpdateEssence(ptype)
  local bar = ClassHUD.bars.class
  if not bar then return end
  local max = UnitPowerMax("player", ptype)
  if not max or max <= 0 then
    bar:Hide()
    return
  end
  LayoutSegments(bar, max)
  local current = UnitPower("player", ptype)
  local partial = UnitPartialPower and UnitPartialPower("player", ptype) or 0
  local nextFrac = partial / 1000
  for i = 1, max do
    local segment = EnsureSegment(bar, i)
    segment:SetStatusBarColor(0.5, 1.0, 0.9)
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

function ClassHUD:UpdateClassBar()
  if self._barsPreviewing then return end
  if not self:IsBarEnabled("class") then
    if self.bars and self.bars.class then
      self.bars.class:Hide()
    end
    return
  end

  if not self.bars or not self.bars.class then return end

  local ptype, specID = ResolveSpecialPower()
  if not ptype then
    self.bars.class:Hide()
    return
  end

  if ptype == Enum.PowerType.Runes then
    UpdateRunes(specID)
    return
  end

  if ptype == Enum.PowerType.Essence then
    UpdateEssence(ptype)
    return
  end

  local max = UnitPowerMax("player", ptype) or 0
  if max <= 0 then
    self.bars.class:Hide()
    return
  end

  UpdateSegments(ptype, max, specID)
end

local PREVIEW_CAST_ICON = 136150

function ClassHUD:ShowBarsPreview()
  if not self.bars then return end
  self._barsPreviewing = true

  local bars = self.bars

  if self:IsBarEnabled("cast") and bars.cast then
    local cast = bars.cast
    cast:SetScript("OnUpdate", nil)
    cast.startTime = nil
    cast.endTime = nil
    cast:SetMinMaxValues(0, 2.5)
    cast:SetValue(1.5)
    cast.icon:SetTexture(PREVIEW_CAST_ICON)
    cast.spell:SetText("Preview Cast")
    cast.time:SetText("1.0")
    cast:Show()
  elseif bars.cast then
    bars.cast:Hide()
  end

  if self:IsBarEnabled("health") and bars.health then
    local health = bars.health
    health:SetMinMaxValues(0, 100)
    health:SetValue(75)
    local r, g, b = GetClassColor()
    health:SetStatusBarColor(r, g, b)
    health.value:SetText("75 / 100 (75%)")
    health:Show()
  elseif bars.health then
    bars.health:Hide()
  end

  if self:IsBarEnabled("resource") and bars.resource then
    local resource = bars.resource
    resource:SetMinMaxValues(0, 100)
    resource:SetValue(60)
    resource:SetStatusBarColor(0.25, 0.6, 1.0)
    resource.value:SetText("60")
    resource:Show()
  elseif bars.resource then
    bars.resource:Hide()
  end

  if self:IsBarEnabled("class") and bars.class then
    local class = bars.class
    LayoutSegments(class, 5)
    for i = 1, 5 do
      local segment = EnsureSegment(class, i)
      segment:SetMinMaxValues(0, 1)
      segment:SetStatusBarTexture(GetBarTexture())
      local value = (i <= 3) and 1 or (i == 4 and 0.5 or 0)
      segment:SetValue(value)
      local r, g, b = IndexedColor(i, 5)
      segment:SetStatusBarColor(r, g, b)
      segment:Show()
    end
    class:Show()
  elseif bars.class then
    bars.class:Hide()
  end
end

function ClassHUD:HideBarsPreview()
  if not self.bars then return end
  if not self._barsPreviewing then
    self:RefreshBars()
    return
  end

  self._barsPreviewing = false

  if self.bars.cast then
    self:StopCast()
  end
  self:RefreshBars()
end

