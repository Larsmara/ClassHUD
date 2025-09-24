-- ClassHUD_Bars.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

-- Anchor
function ClassHUD:CreateAnchor()
  local f = CreateFrame("Frame", "ClassHUDAnchor", UIParent, "BackdropTemplate")
  f:SetSize(250, 1)
  f:SetMovable(false) -- position controlled via options
  UI.anchor = f
end

-- Bars
function ClassHUD:CreateCastBar()
  local h = self.db.profile.layout.height.cast
  local b = self:CreateStatusBar(UI.anchor, h, false) -- castbar starter uten border

  b:Hide()
  b._holder:Hide()
  b.bg:Hide()

  local holder = b._holder
  local edge   = b._edge or 1
  local pad    = 4

  -- IKON PÅ HOLDER (fast lomme til venstre)
  b.icon       = holder:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(h, h)
  b.icon:SetPoint("LEFT", holder, "LEFT", 0, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  -- SELVE STATUSBAREN STARTER ETTER IKON + PADDING
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", holder, "TOPLEFT", edge + h + pad, -edge)
  b:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -edge, edge)

  -- Bakgrunn følger baren (dekker ikke ikon-lommen)
  b.bg:ClearAllPoints()
  b.bg:SetAllPoints(b)

  -- Tekster på selve baren
  b.spell = b:CreateFontString(nil, "OVERLAY")
  b.spell:SetFont(self:FetchFont(12))
  b.spell:SetPoint("LEFT", b, "LEFT", 4, 0)

  b.time = b:CreateFontString(nil, "OVERLAY")
  b.time:SetFont(self:FetchFont(12))
  b.time:SetPoint("RIGHT", b, "RIGHT", -3, 0)

  UI.cast = b
end

-- Lettvekts OnUpdate som støtter både cast og channel
-- Lett og throttle'a OnUpdate for cast/channel
local function CastOnUpdate(self, elapsed)
  local isChan = self._isChannel or false
  local dur    = self._duration or 0
  if dur <= 0 then
    self:SetScript("OnUpdate", nil)
    self:Hide()
    return
  end

  -- Oppdater tidsakkumulatorer
  if isChan then
    self._remaining = (self._remaining or dur) - elapsed
    if self._remaining <= 0 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      return
    end
  else
    self._t = (self._t or 0) + elapsed
    if self._t >= dur then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      return
    end
  end

  -- Throttle: barverdi (60 Hz)
  self._accum = (self._accum or 0) + elapsed
  local barTick = self._barTick or (1 / 60)
  if self._accum >= barTick then
    self._accum = 0
    if isChan then
      -- teller ned (verdi = gjenstående)
      local v = self._remaining
      if v ~= self._lastBarValue then
        self:SetValue(v)
        self._lastBarValue = v
      end
    else
      -- teller opp (verdi = brukt tid)
      local v = self._t
      if v ~= self._lastBarValue then
        self:SetValue(v)
        self._lastBarValue = v
      end
    end
  end

  -- Throttle: tekst (10 Hz)
  self._textAccum = (self._textAccum or 0) + elapsed
  local txtTick = self._txtTick or 0.10
  if self._textAccum >= txtTick then
    self._textAccum = 0
    local remaining = isChan and (self._remaining or 0) or (dur - (self._t or 0))
    if remaining < 0 then remaining = 0 end

    -- Kompakt format uten unødige string-builds
    local shown
    if remaining >= 10 then
      shown = tostring(math.floor(remaining + 0.5))
    else
      shown = string.format("%.1f", math.floor(remaining * 10 + 0.5) / 10)
    end

    if shown ~= self._lastText then
      self.time:SetText(shown)
      self._lastText = shown
    end
  end
end


function ClassHUD:CreateHPBar()
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.layout.height.hp, true) -- 👈 withBorder = true
  local r, g, bCol = self:GetClassColor()
  b:SetStatusBarColor(r, g, bCol)
  UI.hp = b
end

function ClassHUD:CreateResourceBar()
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.layout.height.resource, true) -- 👈 withBorder = true
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

-- Layout (top→bottom): tracked buffs → cast → hp → resource → power
function ClassHUD:ApplyBarSkins()
  local tex    = self:FetchStatusbar()
  local colors = self.db.profile.colors or {}
  local c      = colors.border or { r = 0, g = 0, b = 0, a = 1 }
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

  local c = colors.border or { r = 0, g = 0, b = 0, a = 1 }
  for _, sb in pairs({ UI.cast, UI.hp, UI.resource }) do
    if sb and sb.SetBackdropBorderColor then
      sb:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end
  end
end

function ClassHUD:Layout()
  local UI      = self.UI
  local profile = self.db.profile
  local layout  = profile.layout or {}
  layout.show   = layout.show or {}
  layout.height = layout.height or {}
  local w       = profile.width or 250
  local gap     = profile.spacing or 2

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

  -- Opprett containere
  local containers = {
    TOP      = ensure("TOP"),
    CAST     = ensure("CAST"),
    HP       = ensure("HP"),
    RESOURCE = ensure("RESOURCE"),
    CLASS    = ensure("CLASS"),
    BOTTOM   = ensure("BOTTOM"),
  }

  -- Helper for statusbars
  -- Helper for statusbars: ankrer og størrelsesetter HOLDER hvis den finnes
  local function layoutStatusBar(frame, containerName, enabled, height)
    local container = containers[containerName]
    if not container then return end

    -- Viktig: bruk holder hvis den finnes (for å beholde ikon-lommen)
    local anchorFrame = frame and (frame._holder or frame)

    local h = (enabled and height) or 0
    container._height = h
    container:SetHeight(math.max(h, 1))

    if not frame then return end

    -- Forankre og størrelse HOLDEREN (ikke selve statusbaren)
    anchorFrame:SetParent(container)
    anchorFrame:ClearAllPoints()
    anchorFrame:SetWidth(w)
    anchorFrame:SetHeight(h)

    if enabled and h > 0 then
      anchorFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
      anchorFrame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
      anchorFrame:Show()
      frame:Show() -- selve baren vises når aktiv, men det er OK å la den være synlig her
    else
      frame:Hide()
      anchorFrame:Hide()
    end
  end


  -- Bygg standard bars
  layoutStatusBar(UI.cast, "CAST", layout.show.cast, layout.height.cast)
  layoutStatusBar(UI.hp, "HP", layout.show.hp, layout.height.hp)
  layoutStatusBar(UI.resource, "RESOURCE", layout.show.resource, layout.height.resource)

  -- CLASS bar (special power)
  do
    local container = containers.CLASS
    if container then
      local showPower = layout.show.power
      local h = (showPower and layout.height.power) or 0
      container._height = h
      container:SetHeight(math.max(h, 1))

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

  -- BOTTOM container
  do
    local container = containers.BOTTOM
    if container then
      local h = container._height or 0
      container:SetHeight(math.max(h, 1))
    end
  end

  -- Buff containers
  local trackedIcons = UI.attachments.TRACKED_ICONS
  local anchor       = UI.anchor
  local y            = 0

  local function place(container)
    if not container then return end
    local h = container._height or 0
    local g = (container._afterGap ~= nil) and container._afterGap or gap
    container:ClearAllPoints()
    container:SetPoint("TOP", anchor, "TOP", 0, -y)
    if container:IsShown() then
      y = y + h + g
    end
  end

  -- Alltid: Icons først, så Buff bars
  place(trackedIcons)

  -- Sanitér barOrder
  local order = layout.barOrder
  if type(order) ~= "table" or #order == 0 then
    order = { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" }
    layout.barOrder = order
  end
  local fixed = {}
  for _, key in ipairs(order) do
    if containers[key] then table.insert(fixed, key) end
  end
  if #fixed == 0 then
    fixed = { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" }
  end
  order = fixed
  layout.barOrder = fixed

  -- Legg ut i valgt rekkefølge
  for _, key in ipairs(order) do
    place(containers[key])
  end

  -- Side-ankere
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
  if UnitCastingInfo("player") or UnitChannelInfo("player") then return end
  if not UI.cast then return end

  UI.cast:SetScript("OnUpdate", nil)

  UI.cast._duration, UI.cast._isChannel = nil, nil
  UI.cast._t, UI.cast._remaining = nil, nil
  UI.cast._accum, UI.cast._textAccum = nil, nil
  UI.cast._lastText, UI.cast._lastBarValue = nil, nil

  UI.cast:SetMinMaxValues(0, 1)
  UI.cast:SetValue(0)
  UI.cast.time:SetText("")
  UI.cast.spell:SetText("")
  UI.cast.icon:SetTexture(nil)

  if UI.cast._holder then
    UI.cast._holder:SetBackdrop(nil)
    UI.cast._holder:Hide()
  end
  UI.cast.bg:Hide()
  UI.cast:Hide()
end

function ClassHUD:StartCast(name, icon, startMS, endMS, isChannel)
  if not self.db.profile.layout.show.cast or not UI.cast then return end

  local holder = UI.cast._holder
  local edge   = UI.cast._edge or 1

  local start  = (startMS or 0) / 1000
  local finish = (endMS or 0) / 1000
  if finish <= start then finish = start + 0.10 end
  local duration = finish - start

  -- Vis + border/plate
  UI.cast:Show()
  holder:Show()
  UI.cast.bg:Show()
  holder:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = edge,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  local colors = self.db.profile.colors or {}
  local c = colors.border or { r = 0, g = 0, b = 0, a = 1 }
  holder:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
  holder:SetBackdropColor(0, 0, 0, 0.40)

  -- Tekst/ikon
  UI.cast.spell:SetText(name or "")
  UI.cast.icon:SetTexture(icon or 136243)

  -- Sett statiske grenser én gang
  UI.cast:SetMinMaxValues(0, duration)

  -- Init interne felter (brukes av OnUpdate)
  UI.cast._duration     = duration
  UI.cast._isChannel    = isChannel and true or false
  UI.cast._t            = 0
  UI.cast._remaining    = duration
  UI.cast._accum        = 0
  UI.cast._textAccum    = 0
  UI.cast._lastText     = nil
  UI.cast._lastBarValue = nil

  -- Farge + startverdi
  if UI.cast._isChannel then
    UI.cast:SetStatusBarColor(0.30, 0.70, 1.00)
    UI.cast:SetValue(duration) -- start på gjenstående tid
    UI.cast._lastBarValue = duration
  else
    UI.cast:SetStatusBarColor(1.00, 0.70, 0.00)
    UI.cast:SetValue(0) -- start på 0 (teller opp)
    UI.cast._lastBarValue = 0
  end

  -- Lettvektsoppdaterer (bruker elapsed)
  UI.cast:SetScript("OnUpdate", CastOnUpdate)
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

function ClassHUD:UNIT_SPELLCAST_STOP(unit) if unit == "player" then self:StopCast() end end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(unit) if unit == "player" then self:StopCast() end end

function ClassHUD:UNIT_SPELLCAST_INTERRUPTED(unit) if unit == "player" then self:StopCast() end end

function ClassHUD:UNIT_SPELLCAST_FAILED(unit) if unit == "player" then self:StopCast() end end

-- HP/Primary updates
function ClassHUD:UpdateHP()
  if not self.db.profile.layout.show.hp then return end
  local cur, max = UnitHealth("player"), UnitHealthMax("player")
  UI.hp:SetMinMaxValues(0, max)
  UI.hp:SetValue(cur)
  local pct = (max > 0) and (cur / max * 100) or 0
  UI.hp.text:SetFormattedText("%d%%", pct + 0.5)
  UI.hp:Show()
end

function ClassHUD:UpdatePrimaryResource()
  if not self.db.profile.layout.show.resource then return end

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
