-- ClassHUD_Bars.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

local DEFAULT_BAR_ORDER = { "top", "cast", "health", "resource", "class", "bottom" }

local ORDER_KEY_MAP = {
  cast        = "cast",
  CAST        = "cast",
  health      = "health",
  HEALTH      = "health",
  hp          = "health",
  HP          = "health",
  resource    = "resource",
  RESOURCE    = "resource",
  power       = "class",
  POWER       = "class",
  class       = "class",
  CLASS       = "class",
  top         = "top",
  TOP         = "top",
  topbar      = "top",
  TOPBAR      = "top",
  ["top-bar"]    = "top",
  ["TOP_BAR"]    = "top",
  bottom      = "bottom",
  BOTTOM      = "bottom",
  bottombar   = "bottom",
  BOTTOMBAR   = "bottom",
  ["bottom-bar"] = "bottom",
  ["BOTTOM_BAR"] = "bottom",
}

local ZERO_PADDING = { left = 0, right = 0, top = 0, bottom = 0 }

local RESOURCE_BACKDROP = {
  bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile     = true,
  tileSize = 16,
  edgeSize = 8,
  insets   = { left = 2, right = 2, top = 2, bottom = 2 },
}

local HEIGHT_KEY_MAP = {
  cast     = "cast",
  health   = "hp",
  resource = "resource",
  class    = "class",
}

local SHOW_KEY_MAP = {
  cast     = "cast",
  health   = "hp",
  resource = "resource",
  class    = "power",
}

local function contains(list, value)
  for _, entry in ipairs(list) do
    if entry == value then
      return true
    end
  end
  return false
end

local function applyFont(addon, fontString, size)
  if not fontString or not addon.FetchFont then
    return
  end
  local path, actualSize, flags = addon:FetchFont(size)
  fontString:SetFont(path, actualSize or size, flags)
  fontString:SetShadowOffset(0, 0)
end

local function textSizeFromHeight(height)
  if not height or height <= 0 then
    return 12
  end
  return math.max(8, math.floor(height * 0.75 + 0.5))
end

function ClassHUD:SanitizeBarProfile()
  if not (self.db and self.db.profile) then return end

  local profile = self.db.profile
  profile.height = profile.height or {}
  profile.height.cast = profile.height.cast or 18
  profile.height.hp = profile.height.hp or profile.height.health or 14
  profile.height.resource = profile.height.resource or 14

  if profile.height.class == nil then
    profile.height.class = profile.height.power or profile.height.resource or 14
  end
  profile.height.health = nil
  profile.height.power = nil

  profile.colors = profile.colors or {}
  if profile.colors.class == nil and profile.colors.power ~= nil then
    profile.colors.class = {
      r = profile.colors.power.r,
      g = profile.colors.power.g,
      b = profile.colors.power.b,
    }
  end

  local rawOrder = profile.barOrder
  local normalized = {}
  if type(rawOrder) == "table" then
    for _, key in ipairs(rawOrder) do
      local normalizedKey = ORDER_KEY_MAP[key] or ORDER_KEY_MAP[string.upper(tostring(key))]
      if normalizedKey and not contains(normalized, normalizedKey) then
        table.insert(normalized, normalizedKey)
      end
    end
  end

  for _, key in ipairs(DEFAULT_BAR_ORDER) do
    if not contains(normalized, key) then
      if key == "top" then
        table.insert(normalized, 1, key)
      else
        table.insert(normalized, key)
      end
    end
  end

  profile.barOrder = normalized
end

function ClassHUD:GetBarOrder()
  if not (self.db and self.db.profile) then
    return { unpack(DEFAULT_BAR_ORDER) }
  end
  self:SanitizeBarProfile()
  return self.db.profile.barOrder
end

local function getBarHeight(profile, key)
  local dbKey = HEIGHT_KEY_MAP[key]
  if not dbKey then return 0 end
  return profile.height and profile.height[dbKey] or 0
end

function ClassHUD:IsBarEnabled(key)
  if not (self.db and self.db.profile) then return true end
  local show = self.db.profile.show or {}
  if show[key] ~= nil then
    return show[key]
  end
  local mapped = SHOW_KEY_MAP[key]
  if mapped == "power" and show.class ~= nil then
    return show.class
  end
  if mapped and show[mapped] ~= nil then
    return show[mapped]
  end
  return true
end

function ClassHUD:CreateAnchor()
  if UI.anchor then
    UI.anchor:SetWidth(self.db and self.db.profile and self.db.profile.width or 250)
    return UI.anchor
  end

  local anchor = CreateFrame("Frame", "ClassHUDAnchor", UIParent, "BackdropTemplate")
  anchor:SetSize(self.db and self.db.profile and self.db.profile.width or 250, 1)
  anchor:SetMovable(false)
  UI.anchor = anchor
  UI.attachments = UI.attachments or {}
  return anchor
end

local function ensureBarContainer(key)
  ClassHUD.barContainers = ClassHUD.barContainers or {}
  local container = ClassHUD.barContainers[key]
  if container and container:GetParent() ~= UI.anchor then
    container:SetParent(UI.anchor)
  end
  if not container then
    container = CreateFrame("Frame", "ClassHUDBarContainer_" .. key, UI.anchor, "BackdropTemplate")
    container:SetClipsChildren(false)
    container._height = 0
    container._afterGap = 0
    container._padding = { left = 0, right = 0, top = 0, bottom = 0 }
    ClassHUD.barContainers[key] = container
  elseif not container._padding then
    container._padding = { left = 0, right = 0, top = 0, bottom = 0 }
  end
  return container
end

local function positionCastBar(addon, bar, height)
  if not bar then return end
  local container = bar._container
  local spacing = addon.db and addon.db.profile and addon.db.profile.spacing or 0
  local pad = container and container._padding or ZERO_PADDING
  local leftPad = pad.left or 0
  local rightPad = pad.right or 0
  local topPad = pad.top or 0
  local bottomPad = pad.bottom or 0
  local iconSize = math.max(1, height - topPad - bottomPad)

  if bar.icon then
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPLEFT", container, "TOPLEFT", leftPad, -topPad)
    bar.icon:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", leftPad, bottomPad)
    bar.icon:SetWidth(iconSize)
    bar.icon:Show()
  end

  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", container, "TOPLEFT", leftPad + iconSize + spacing, -topPad)
  bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -rightPad, bottomPad)

  if bar.bg then
    bar.bg:ClearAllPoints()
    bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  end

  if bar.spell then
    bar.spell:ClearAllPoints()
    bar.spell:SetPoint("LEFT", container, "LEFT", leftPad + iconSize + spacing + 4, 0)
    if bar.time then
      bar.spell:SetPoint("RIGHT", bar.time, "LEFT", -4, 0)
    else
      bar.spell:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    end
  end

  if bar.time then
    bar.time:ClearAllPoints()
    bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  end
end

local function anchorBarToContainer(bar, container)
  if not (bar and container) then return end
  local pad = container._padding or ZERO_PADDING
  local left = pad.left or 0
  local right = pad.right or 0
  local top = pad.top or 0
  local bottom = pad.bottom or 0

  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", container, "TOPLEFT", left, -top)
  bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -right, bottom)
end

function ClassHUD:EnsureBars()
  self:SanitizeBarProfile()
  local anchor = self:CreateAnchor()
  local width = self.db and self.db.profile and self.db.profile.width or 250

  self.bars = self.bars or {}

  -- Cast bar -------------------------------------------------------------
  do
    local container = ensureBarContainer("cast")
    container:SetParent(anchor)
    container:SetWidth(width)

    if not self.bars.cast then
      local bar = CreateFrame("StatusBar", "ClassHUDCastBar", container, "BackdropTemplate")
      bar:SetMinMaxValues(0, 1)
      bar:SetValue(0)
      bar:SetStatusBarTexture(self:FetchStatusbar())
      bar.bg = bar:CreateTexture(nil, "BACKGROUND")
      bar.bg:SetColorTexture(0, 0, 0, 0.6)
      bar.spell = bar:CreateFontString(nil, "OVERLAY")
      bar.spell:SetJustifyH("LEFT")
      bar.spell:SetTextColor(1, 1, 1)
      bar.time = bar:CreateFontString(nil, "OVERLAY")
      bar.time:SetJustifyH("RIGHT")
      bar.time:SetTextColor(1, 1, 1)
      bar.icon = container:CreateTexture(nil, "ARTWORK")
      bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      bar:SetAlpha(0)

      bar._container = container
      self.bars.cast = bar
      UI.cast = bar
    end
  end

  -- Health bar -----------------------------------------------------------
  do
    local container = ensureBarContainer("health")
    container:SetParent(anchor)
    container:SetWidth(width)

    if not self.bars.health then
      local bar = CreateFrame("StatusBar", "ClassHUDHealthBar", container, "BackdropTemplate")
      bar:SetMinMaxValues(0, 1)
      bar:SetValue(0)
      bar:SetStatusBarTexture(self:FetchStatusbar())
      bar.bg = bar:CreateTexture(nil, "BACKGROUND")
      bar.bg:SetColorTexture(0, 0, 0, 0.55)
      bar.value = bar:CreateFontString(nil, "OVERLAY")
      bar.value:SetJustifyH("CENTER")
      bar.value:SetPoint("CENTER")

      bar._container = container
      self.bars.health = bar
      UI.hp = bar
    end
  end

  -- Primary resource bar -------------------------------------------------
  do
    local container = ensureBarContainer("resource")
    container:SetParent(anchor)
    container:SetWidth(width)
    local insets = RESOURCE_BACKDROP.insets
    container._padding = container._padding or {}
    container._padding.left = insets.left
    container._padding.right = insets.right
    container._padding.top = insets.top
    container._padding.bottom = insets.bottom
    if container.SetBackdrop then
      container:SetBackdrop(RESOURCE_BACKDROP)
    end

    if not self.bars.resource then
      local bar = CreateFrame("StatusBar", "ClassHUDResourceBar", container, "BackdropTemplate")
      bar:SetMinMaxValues(0, 1)
      bar:SetValue(0)
      bar:SetStatusBarTexture(self:FetchStatusbar())
      bar.bg = bar:CreateTexture(nil, "BACKGROUND")
      bar.bg:SetColorTexture(0, 0, 0, 0.55)
      bar.value = bar:CreateFontString(nil, "OVERLAY")
      bar.value:SetJustifyH("CENTER")
      bar.value:SetPoint("CENTER")

      bar._container = container
      self.bars.resource = bar
      UI.resource = bar
    end
  end

  -- Class resource bar container ----------------------------------------
  do
    local container = ensureBarContainer("class")
    container:SetParent(anchor)
    container:SetWidth(width)

    if not self.bars.class then
      local frame = CreateFrame("Frame", "ClassHUDClassBar", container, "BackdropTemplate")
      frame:SetClipsChildren(true)
      frame.segments = frame.segments or {}
      frame.cooldowns = frame.cooldowns or {}

      frame._container = container
      self.bars.class = frame
      UI.power = frame
    end
  end

  self:ApplyBarSkins()
end

function ClassHUD:ApplyBarSkins()
  if not self.bars then return end
  local texture = self:FetchStatusbar()
  local profile = self.db and self.db.profile
  if not profile then return end

  local cast = self.bars.cast
  if cast then
    cast:SetStatusBarTexture(texture)
    if cast.bg then cast.bg:SetColorTexture(0, 0, 0, 0.6) end
    local size = textSizeFromHeight(getBarHeight(profile, "cast"))
    applyFont(self, cast.spell, size)
    applyFont(self, cast.time, size)
  end

  local health = self.bars.health
  if health then
    health:SetStatusBarTexture(texture)
    if health.bg then health.bg:SetColorTexture(0, 0, 0, 0.55) end
    applyFont(self, health.value, textSizeFromHeight(getBarHeight(profile, "health")))
  end

  local resource = self.bars.resource
  if resource then
    resource:SetStatusBarTexture(texture)
    if resource.bg then resource.bg:SetColorTexture(0, 0, 0, 0.55) end
    applyFont(self, resource.value, textSizeFromHeight(getBarHeight(profile, "resource")))
    local container = resource._container
    if container and container.SetBackdrop then
      container:SetBackdrop(RESOURCE_BACKDROP)
      local border = profile.borderColor or { r = 0, g = 0, b = 0, a = 1 }
      container:SetBackdropBorderColor(border.r or 0, border.g or 0, border.b or 0, border.a or 1)
      container:SetBackdropColor(0, 0, 0, 0.7)
    end
  end
end

local function addEntry(entries, frame, key, height, gap)
  if not frame then return end
  height = height or frame._height or frame:GetHeight() or 0
  if height <= 0 then
    return
  end
  table.insert(entries, { key = key, frame = frame, height = height, gap = gap })
end

function ClassHUD:LayoutBars(order)
  if not (self.bars and self.db and self.db.profile) then return {} end

  local entries = {}
  order = order or self:GetBarOrder()
  local profile = self.db.profile
  local width = profile.width or 250
  local spacing = profile.spacing or 0

  for _, key in ipairs(order) do
    local bar = self.bars[key]
    local container = bar and bar._container
    if container then
      container:SetParent(UI.anchor)
      container:SetWidth(width)
      container._afterGap = spacing

      local height = getBarHeight(profile, key)
      local enabled = (height or 0) > 0 and self:IsBarEnabled(key)

      if enabled then
        container._height = height
        container:SetHeight(height)
        container:Show()

        if key == "cast" then
          positionCastBar(self, bar, height)
        else
          anchorBarToContainer(bar, container)
        end
        bar:Show()

        addEntry(entries, container, key, height, spacing)
      else
        container._height = 0
        container:SetHeight(0)
        container:Hide()
        if bar then bar:Hide() end
      end
    end
  end

  return entries
end

function ClassHUD:LayoutSideAttachments(width)
  UI.attachments = UI.attachments or {}
  local anchor = UI.anchor
  if not anchor then return end

  local left = UI.attachments.LEFT
  if not left then
    left = CreateFrame("Frame", "ClassHUDAttachLEFT", anchor)
    UI.attachments.LEFT = left
  end
  left:SetParent(anchor)
  left:ClearAllPoints()
  left:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
  left:SetSize(1, math.max(1, anchor:GetHeight()))

  local right = UI.attachments.RIGHT
  if not right then
    right = CreateFrame("Frame", "ClassHUDAttachRIGHT", anchor)
    UI.attachments.RIGHT = right
  end
  right:SetParent(anchor)
  right:ClearAllPoints()
  right:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
  right:SetSize(1, math.max(1, anchor:GetHeight()))
end

function ClassHUD:Layout()
  if not (self.db and self.db.profile) then return end

  self:EnsureBars()

  local anchor = self:CreateAnchor()
  local profile = self.db.profile
  local width = profile.width or 250
  local spacing = profile.spacing or 0
  anchor:SetWidth(width)

  UI.attachments = UI.attachments or {}

  local order = self:GetBarOrder()
  local barEntries = self:LayoutBars(order)
  local entriesByKey = {}
  for _, entry in ipairs(barEntries) do
    if entry.key then
      entriesByKey[entry.key] = entry
    end
  end

  local entries = {}

  local function appendEntry(entry)
    if not entry then return end
    local frame = entry.frame
    if not frame then return end
    frame:SetParent(anchor)
    frame:SetWidth(width)
    entry.height = entry.height or frame._height or frame:GetHeight() or 0
    table.insert(entries, entry)
  end

  local function buildAttachmentEntry(name)
    local frame = UI.attachments[name]
    if not frame then return nil end
    frame:SetParent(anchor)
    frame:SetWidth(width)
    local height = frame._height or frame:GetHeight() or 0
    if height <= 0 then
      frame:SetHeight(height)
      frame:Hide()
      return nil
    end
    local gap = frame._afterGap
    if gap == nil then gap = spacing end
    return { key = name, frame = frame, height = height, gap = gap }
  end

  appendEntry(buildAttachmentEntry("TRACKED_ICONS"))
  appendEntry(buildAttachmentEntry("TRACKED_BARS"))

  for _, key in ipairs(order) do
    if key == "top" then
      appendEntry(buildAttachmentEntry("TOP"))
    elseif key == "bottom" then
      appendEntry(buildAttachmentEntry("BOTTOM"))
    else
      local entry = entriesByKey[key]
      appendEntry(entry)
      entriesByKey[key] = nil
    end
  end

  local offset = 0
  for index, entry in ipairs(entries) do
    local frame = entry.frame
    local height = entry.height or frame._height or frame:GetHeight() or 0
    if height < 0 then height = 0 end
    local gap = entry.gap
    if gap == nil then gap = spacing end

    frame:ClearAllPoints()
    frame:SetPoint("TOP", anchor, "TOP", 0, -offset)
    if frame.SetHeight then frame:SetHeight(height) end
    frame:SetWidth(width)
    frame:Show()

    offset = offset + height
    if index < #entries then
      offset = offset + gap
    end
  end

  anchor:SetHeight(math.max(1, offset))
  self:LayoutSideAttachments(width)
  self:ApplyBarSkins()
end

-- Cast handling ------------------------------------------------------------
local function CastOnUpdate(bar)
  if not (bar.startTime and bar.endTime) then
    ClassHUD:StopCast()
    return
  end

  local now = GetTime()
  local duration = bar.endTime - bar.startTime
  if duration <= 0 then duration = 0.001 end

  if bar.isChannel then
    local remaining = bar.endTime - now
    if remaining <= 0 then
      ClassHUD:StopCast()
      return
    end
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(math.max(0, remaining))
    if bar.time then
      bar.time:SetFormattedText("%.1f", math.max(0, remaining))
    end
  else
    local elapsed = now - bar.startTime
    if elapsed >= duration then
      ClassHUD:StopCast()
      return
    end
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(elapsed)
    if bar.time then
      bar.time:SetFormattedText("%.1f", math.max(0, duration - elapsed))
    end
  end
end

function ClassHUD:StopCast()
  if not (self.bars and self.bars.cast) then return end
  local cast = self.bars.cast
  cast:SetScript("OnUpdate", nil)
  cast.startTime = nil
  cast.endTime = nil
  cast.isChannel = nil
  cast:SetMinMaxValues(0, 1)
  cast:SetValue(0)
  cast:SetAlpha(0)
  if cast.spell then cast.spell:SetText("") end
  if cast.time then cast.time:SetText("") end
  if cast.icon then cast.icon:SetTexture(nil) end
end

function ClassHUD:StartCast(name, icon, startMS, endMS, isChannel)
  if not self:IsBarEnabled("cast") then return end
  if not (self.bars and self.bars.cast) then return end

  local cast = self.bars.cast
  cast:SetAlpha(1)
  cast:Show()

  local startTime = (startMS or 0) / 1000
  local endTime = (endMS or 0) / 1000
  if endTime <= startTime then
    endTime = startTime + 0.1
  end

  cast.startTime = startTime
  cast.endTime = endTime
  cast.isChannel = isChannel and true or false

  if cast.spell then cast.spell:SetText(name or "") end
  if cast.icon then cast.icon:SetTexture(icon or 136243) end
  if cast.time then cast.time:SetText("") end

  cast:SetMinMaxValues(0, endTime - startTime)
  if isChannel then
    cast:SetValue(math.max(0, endTime - GetTime()))
  else
    cast:SetValue(0)
  end
  cast:SetScript("OnUpdate", CastOnUpdate)
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

-- Health bar ---------------------------------------------------------------
function ClassHUD:UpdateHP()
  if not self:IsBarEnabled("health") then
    if self.bars and self.bars.health then
      self.bars.health:Hide()
    end
    return
  end

  if not (self.bars and self.bars.health) then return end
  local bar = self.bars.health
  local cur = UnitHealth("player") or 0
  local max = UnitHealthMax("player") or 1
  if max <= 0 then max = 1 end

  bar:SetMinMaxValues(0, max)
  bar:SetValue(cur)

  local color = self.db.profile.colors and self.db.profile.colors.hp
  if color then
    bar:SetStatusBarColor(color.r, color.g, color.b)
  else
    local r, g, b = self:GetClassColor()
    bar:SetStatusBarColor(r, g, b)
  end

  local percent = (cur / max) * 100
  if BreakUpLargeNumbers then
    bar.value:SetFormattedText("%s / %s (%.0f%%)",
      BreakUpLargeNumbers(cur), BreakUpLargeNumbers(max), percent + 0.5)
  else
    bar.value:SetFormattedText("%d / %d (%.0f%%)", cur, max, percent + 0.5)
  end
  bar:Show()
end

-- Primary resource --------------------------------------------------------
function ClassHUD:UpdatePrimaryResource()
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
  if not max or max <= 0 then max = 1 end

  resource:SetMinMaxValues(0, max)
  resource:SetValue(cur)

  local useClass = self.db.profile.colors and self.db.profile.colors.resourceClass
  if useClass then
    resource:SetStatusBarColor(self:GetClassColor())
  else
    local color = self.db.profile.colors and self.db.profile.colors.resource
    if color then
      resource:SetStatusBarColor(color.r, color.g, color.b)
    else
      local r, g, b = self:PowerColorBy(id, token)
      resource:SetStatusBarColor(r, g, b)
    end
  end

  if token == "MANA" then
    local pct = (cur / max) * 100
    resource.value:SetFormattedText("%d%%", pct + 0.5)
  else
    resource.value:SetText(cur)
  end
  resource:Show()
end

-- Compatibility helpers ---------------------------------------------------
function ClassHUD:CreateCastBar()
  self:EnsureBars()
  return self.bars.cast
end

function ClassHUD:CreateHPBar()
  self:EnsureBars()
  return self.bars.health
end

function ClassHUD:CreateResourceBar()
  self:EnsureBars()
  return self.bars.resource
end

function ClassHUD:CreatePowerContainer()
  self:EnsureBars()
  return self.bars.class
end

function ClassHUD:ApplyBarVisuals()
  self:ApplyBarSkins()
end
