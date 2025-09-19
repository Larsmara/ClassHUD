-- ClassHUD_Bars.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

local VALID_LAYOUT_ENTRIES = {
  TOP      = true,
  CAST     = true,
  HP       = true,
  RESOURCE = true,
  CLASS    = true,
  BOTTOM   = true,
}

local DEFAULT_LAYOUT_ORDER = { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" }

local function sanitizeLayoutOrder(order)
  local sanitized = {}
  local seen = {}

  if type(order) == "table" then
    for _, name in ipairs(order) do
      if VALID_LAYOUT_ENTRIES[name] and not seen[name] then
        table.insert(sanitized, name)
        seen[name] = true
      end
    end
  end

  for _, name in ipairs(DEFAULT_LAYOUT_ORDER) do
    if not seen[name] then
      table.insert(sanitized, name)
      seen[name] = true
    end
  end

  return sanitized
end

local function ensureLayoutProfile(addon)
  if not (addon and addon.db and addon.db.profile) then
    return nil
  end
  addon.db.profile.layout = addon.db.profile.layout or {}
  return addon.db.profile.layout
end

function ClassHUD:GetLayoutOrder()
  local layout = ensureLayoutProfile(self)
  if not layout then
    local copy = {}
    for i, name in ipairs(DEFAULT_LAYOUT_ORDER) do
      copy[i] = name
    end
    return copy
  end

  layout.order = sanitizeLayoutOrder(layout.order)
  return layout.order
end

function ClassHUD:SetLayoutOrder(newOrder)
  local layout = ensureLayoutProfile(self)
  if not layout then return end

  layout.order = sanitizeLayoutOrder(newOrder)

  if self.Layout then
    self:Layout()
  end
end

function ClassHUD:SetLayoutLeader(name)
  if not VALID_LAYOUT_ENTRIES[name] then return end

  local current = self:GetLayoutOrder()
  local reordered = { name }
  for _, entry in ipairs(current) do
    if entry ~= name then
      table.insert(reordered, entry)
    end
  end

  self:SetLayoutOrder(reordered)
end

function ClassHUD:MoveLayoutEntry(name, delta)
  if not VALID_LAYOUT_ENTRIES[name] then return end

  local current = self:GetLayoutOrder()
  local order = {}
  for i, entry in ipairs(current) do
    order[i] = entry
  end

  local index
  for i, entry in ipairs(order) do
    if entry == name then
      index = i
      break
    end
  end

  if not index then return end

  local target = index + (delta or 0)
  if target < 1 or target > #order or target == index then return end

  order[index], order[target] = order[target], order[index]

  self:SetLayoutOrder(order)
end

-- Anchor
function ClassHUD:CreateAnchor()
  local f = CreateFrame("Frame", "ClassHUDAnchor", UIParent, "BackdropTemplate")
  f:SetSize(250, 1)
  f:SetMovable(false) -- position controlled via options
  UI.anchor = f
end

-- Bars
function ClassHUD:CreateCastBar()
  local h = self.db.profile.height.cast
  local b = self:CreateStatusBar(UI.anchor, h, false) -- castbar starter uten border

  b:Hide()
  b._holder:Hide() -- 👈 skjul holder også
  b.bg:Hide()

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(h, h)
  b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  b.spell = b:CreateFontString(nil, "OVERLAY")
  b.spell:SetFont(self:FetchFont(12))
  b.spell:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)

  b.time = b:CreateFontString(nil, "OVERLAY")
  b.time:SetFont(self:FetchFont(12))
  b.time:SetPoint("RIGHT", b, "RIGHT", -3, 0)

  UI.cast = b
end

function ClassHUD:CreateHPBar()
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.height.hp, true) -- 👈 withBorder = true
  local r, g, bCol = self:GetClassColor()
  b:SetStatusBarColor(r, g, bCol)
  UI.hp = b
end

function ClassHUD:CreateResourceBar()
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.height.resource, true) -- 👈 withBorder = true
  if self.db.profile.colors.resourceClass then
    b:SetStatusBarColor(self:GetClassColor())
  else
    local c = self.db.profile.colors.resource
    b:SetStatusBarColor(c.r, c.g, c.b)
  end
  UI.resource = b
end

function ClassHUD:CreatePowerContainer()
  local f = CreateFrame("Frame", nil, UI.anchor, "BackdropTemplate")
  f:SetSize(250, 16)
  UI.power = f
end

-- Layout helpers
function ClassHUD:ApplyBarSkins()
  local tex = self:FetchStatusbar()
  local c   = self.db.profile.borderColor or { r = 0, g = 0, b = 0, a = 1 }
  for _, sb in pairs({ UI.cast, UI.hp, UI.resource }) do
    if sb and sb.SetStatusBarTexture then
      sb:SetStatusBarTexture(tex)
    end
    if sb and sb.SetBackdropBorderColor then
      sb:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end
  end
  if UI.cast then
    UI.cast.spell:SetFont(self:FetchFont(12))
    UI.cast.time:SetFont(self:FetchFont(12))
  end
  if UI.hp then UI.hp.text:SetFont(self:FetchFont(12)) end
  if UI.resource then UI.resource.text:SetFont(self:FetchFont(12)) end

  local c = self.db.profile.borderColor or { r = 0, g = 0, b = 0, a = 1 }
  for _, sb in pairs({ UI.cast, UI.hp, UI.resource }) do
    if sb and sb.SetBackdropBorderColor then
      sb:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end
  end
end

function ClassHUD:Layout()
  local w   = self.db.profile.width
  local gap = self.db.profile.spacing or 0
  local db  = self.db.profile

  if UI.anchor then UI.anchor:SetWidth(w) end
  UI.attachments = UI.attachments or {}

  local function ensure(name)
    if not UI.attachments[name] then
      UI.attachments[name] = CreateFrame("Frame", "ClassHUDAttach" .. name, UI.anchor)
      UI.attachments[name]._height = 0
    end
    local f = UI.attachments[name]
    f:SetParent(UI.anchor)
    f:SetWidth(w)
    f._height = f._height or 0
    f:SetHeight(f._height)
    f:Show()
    return f
  end

  -- Opprett/finn containere (ALLTID – kjeden må bestå)
  local containers = {
    TRACKED_BARS = ensure("TRACKED_BARS"),
    TOP          = ensure("TOP"),
    CAST         = ensure("CAST"),
    HP           = ensure("HP"),
    RESOURCE     = ensure("RESOURCE"),
    CLASS        = ensure("CLASS"),
    BOTTOM       = ensure("BOTTOM"),
  }

  local function layoutStatusBar(frame, containerName, enabled, height)
    local container = containers[containerName]
    if not container then return end

    -- behold containeren i layouten: minst 1px høyde
    local h = (enabled and height) or 0
    container._height = h
    container:SetHeight(math.max(h, 1))

    if frame then
      frame:SetParent(container)
      frame:ClearAllPoints()
      frame:SetWidth(w)
      frame:SetHeight(h)

      if enabled and h > 0 then
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        frame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        frame:Show()
      else
        frame:Hide()
      end
    end
  end


  -- Viktig: bruk samme layoutfunksjon også for CAST og sørg for at den får 0-høyde når av
  layoutStatusBar(UI.cast, "CAST", db.show.cast, db.height.cast)
  layoutStatusBar(UI.hp, "HP", db.show.hp, db.height.hp)
  layoutStatusBar(UI.resource, "RESOURCE", db.show.resource, db.height.resource)

  -- CLASS (special power) container
  do
    local container = containers.CLASS
    if container then
      local showPower = db.show.power
      local h = (showPower and db.height.power) or 0
      container._height = h
      container:SetHeight(math.max(h, 1)) -- 👈 alltid minst 1px høy

      if UI.power then
        UI.power:SetParent(container)
        UI.power:ClearAllPoints()
        UI.power:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        UI.power:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        UI.power:SetWidth(w)
        UI.power:SetHeight(h)
        if showPower and h > 0 then
          UI.power:Show()
        else
          UI.power:Hide()
        end
      end
    end
  end

  -- BOTTOM container (always keep at least 1px so it doesn't collapse)
  do
    local container = containers.BOTTOM
    if container then
      local h = container._height or 0
      container:SetHeight(math.max(h, 1))
    end
  end

  -- Kjederekkefølge – ALDRI hopp over containere selv om høyden er 0
  local configuredOrder = self:GetLayoutOrder()
  local order = { "TRACKED_BARS" }
  for _, name in ipairs(configuredOrder) do
    if containers[name] then
      table.insert(order, name)
    end
  end

  local previous   = UI.anchor
  local prevHeight = 0
  for _, name in ipairs(order) do
    local container = containers[name]
    container:SetWidth(w)
    container:ClearAllPoints()

    if previous == UI.anchor then
      container:SetPoint("TOPLEFT", previous, "TOPLEFT", 0, 0)
      container:SetPoint("TOPRIGHT", previous, "TOPRIGHT", 0, 0)
    else
      -- kun legg inn gap hvis forrige faktisk hadde høyde
      local offset = (prevHeight > 0) and gap or 0
      if previous._afterGap ~= nil then
        offset = previous._afterGap
        previous._afterGap = nil
      end
      container:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -offset)
      container:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -offset)
    end

    previous   = container
    prevHeight = container._height or 0
  end

  -- Side-ankere (for ikonkolonner). Må alltid eksistere.
  local left = UI.attachments.LEFT
  if not left then
    UI.attachments.LEFT = CreateFrame("Frame", "ClassHUDAttachLEFT", UI.anchor)
    left = UI.attachments.LEFT
  end
  left:ClearAllPoints()
  left:SetPoint("RIGHT", UI.anchor, "LEFT", -4, 0)
  left:SetSize(1, 1)

  local right = UI.attachments.RIGHT
  if not right then
    UI.attachments.RIGHT = CreateFrame("Frame", "ClassHUDAttachRIGHT", UI.anchor)
    right = UI.attachments.RIGHT
  end
  right:ClearAllPoints()
  right:SetPoint("LEFT", UI.anchor, "RIGHT", 4, 0)
  right:SetSize(1, 1)

  self:ApplyBarSkins()
end

-- Updates
function ClassHUD:StopCast()
  local casting = UnitCastingInfo("player")
  local channeling = UnitChannelInfo("player")
  if casting or channeling then return end

  if UI.cast then
    local holder = UI.cast._holder
    holder:SetBackdrop(nil) -- 👈 fjern backdrop
    holder:Hide()           -- skjul helt
    UI.cast:Hide()          -- skjul bar
    UI.cast.bg:Hide()

    UI.cast:SetScript("OnUpdate", nil)
    UI.cast:SetValue(0)
    UI.cast.time:SetText("")
    UI.cast.spell:SetText("")
    UI.cast.icon:SetTexture(nil)
  end
end

function ClassHUD:StartCast(name, icon, startMS, endMS, isChannel)
  if not self.db.profile.show.cast then return end
  -- Aktiver border på holder
  local edge   = UI.cast._edge or 1
  local holder = UI.cast._holder

  UI.cast:Show()
  holder:Show()
  UI.cast.bg:Show()

  -- sett border dynamisk
  holder:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8", -- 👈 nå med bakgrunn
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = edge,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  local c = self.db.profile.borderColor or { r = 0, g = 0, b = 0, a = 1 }
  holder:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
  holder:SetBackdropColor(0, 0, 0, 0.4) -- 👈 mørk bakplate (juster alpha som du liker)

  local total = (endMS - startMS) / 1000
  local start = startMS / 1000

  UI.cast:Show()
  UI.cast.spell:SetText(name or "")
  UI.cast.icon:SetTexture(icon or 136243) -- generic
  UI.cast:SetStatusBarColor(isChannel and 0.3 or 1, isChannel and 0.7 or .7, isChannel and 1 or 0)

  UI.cast:SetScript("OnUpdate", function(selfBar)
    local now = GetTime()
    local elapsed = now - start
    selfBar:SetMinMaxValues(0, total)
    selfBar:SetValue(elapsed)
    selfBar.time:SetFormattedText("%.1f / %.1f", math.max(0, elapsed), total)

    if elapsed >= total then
      selfBar:SetScript("OnUpdate", nil)
      selfBar:Hide()
    end
  end)
end

-- Cast event methods
function ClassHUD:UNIT_SPELLCAST_START(unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitCastingInfo("player")
  if name then self:StartCast(name, icon, startMS, endMS, false) end
end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_START(unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitChannelInfo("player")
  if name then self:StartCast(name, icon, startMS, endMS, true) end
end

function ClassHUD:UNIT_SPELLCAST_SUCCEEDED(unit, spellID)
  if unit ~= "player" then return end
  local name, _, icon = C_Spell.GetSpellInfo(spellID)
  if name and not UnitCastingInfo("player") and not UnitChannelInfo("player") then
    self:StartCast(name, icon, GetTime() * 1000, (GetTime() + 1) * 1000, false)
  end
end

function ClassHUD:UNIT_SPELLCAST_STOP(unit) if unit == "player" then self:StopCast() end end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(unit) if unit == "player" then self:StopCast() end end

function ClassHUD:UNIT_SPELLCAST_INTERRUPTED(unit) if unit == "player" then self:StopCast() end end

function ClassHUD:UNIT_SPELLCAST_FAILED(unit) if unit == "player" then self:StopCast() end end

-- HP/Primary updates
function ClassHUD:UpdateHP()
  if not self.db.profile.show.hp then return end
  local cur, max = UnitHealth("player"), UnitHealthMax("player")
  UI.hp:SetMinMaxValues(0, max)
  UI.hp:SetValue(cur)
  local pct = (max > 0) and (cur / max * 100) or 0
  UI.hp.text:SetFormattedText("%d%%", pct + 0.5)
  UI.hp:Show()
end

function ClassHUD:UpdatePrimaryResource()
  if not self.db.profile.show.resource then return end

  local id, token = UnitPowerType("player")
  local cur, max = UnitPower("player", id), UnitPowerMax("player", id)
  UI.resource:SetMinMaxValues(0, max > 0 and max or 1)
  UI.resource:SetValue(cur)

  local r, g, b = self:PowerColorBy(id, token)
  UI.resource:SetStatusBarColor(r, g, b)

  if id == Enum.PowerType.Mana then
    local pct = (max > 0) and (cur / max * 100) or 0
    UI.resource.text:SetFormattedText("%d%%", pct + 0.5)
  else
    UI.resource.text:SetText(cur)
  end
  UI.resource:Show()
end
