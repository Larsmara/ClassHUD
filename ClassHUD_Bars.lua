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

-- Layout (top→bottom): tracked buffs → cast → hp → resource → power
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
  local UI  = self.UI
  local db  = self.db.profile
  local w   = db.width or 250
  local gap = db.spacing or 2

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
  local function layoutStatusBar(frame, containerName, enabled, height)
    local container = containers[containerName]
    if not container then return end

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

  -- Bygg standard bars
  layoutStatusBar(UI.cast, "CAST", db.show.cast, db.height.cast)
  layoutStatusBar(UI.hp, "HP", db.show.hp, db.height.hp)
  layoutStatusBar(UI.resource, "RESOURCE", db.show.resource, db.height.resource)

  -- CLASS bar (special power)
  do
    local container = containers.CLASS
    if container then
      local showPower = db.show.power
      local h = (showPower and db.height.power) or 0
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
  local trackedBars  = UI.attachments.TRACKED_BARS
  local anchor       = UI.anchor
  local y            = 0

  local function place(container)
    if not container or not container:IsShown() then return end
    local h = container._height or 0
    local g = (container._afterGap ~= nil) and container._afterGap or gap
    container:ClearAllPoints()
    container:SetPoint("TOP", anchor, "TOP", 0, -y)
    y = y + h + g
  end

  -- Alltid: Icons først, så Buff bars
  if db.show.buffs then
    place(trackedIcons)
    place(trackedBars)
  end

  -- Sanitér barOrder
  local order = db.barOrder
  if type(order) ~= "table" or #order == 0 then
    order = { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" }
    db.barOrder = order
  end
  local fixed = {}
  for _, key in ipairs(order) do
    if containers[key] then table.insert(fixed, key) end
  end
  if #fixed == 0 then
    fixed = { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" }
  end
  order = fixed
  db.barOrder = fixed

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
