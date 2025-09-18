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
  local b = self:CreateStatusBar(UI.anchor, h)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(h, h)
  b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  b.spell = b:CreateFontString(nil, "OVERLAY")
  b.spell:SetFont(self:FetchFont(12))
  b.spell:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
  b.spell:SetJustifyH("LEFT")

  b.time = b:CreateFontString(nil, "OVERLAY")
  b.time:SetFont(self:FetchFont(12))
  b.time:SetPoint("RIGHT", b, "RIGHT", -3, 0)
  b.time:SetJustifyH("RIGHT")

  b:SetStatusBarColor(1, .7, 0)
  b:Hide()
  UI.cast = b
end

function ClassHUD:CreateHPBar()
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.height.hp)
  local r, g, bCol = self:GetClassColor()
  b:SetStatusBarColor(r, g, bCol)
  UI.hp = b
end

function ClassHUD:CreateResourceBar()
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.height.resource)
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
  for _, sb in pairs({ UI.cast, UI.hp, UI.resource }) do
    if sb and sb.SetStatusBarTexture then
      sb:SetStatusBarTexture(tex)
    end
  end
  if UI.cast then
    UI.cast.spell:SetFont(self:FetchFont(12))
    UI.cast.time:SetFont(self:FetchFont(12))
  end
  if UI.hp then UI.hp.text:SetFont(self:FetchFont(12)) end
  if UI.resource then UI.resource.text:SetFont(self:FetchFont(12)) end
end

function ClassHUD:Layout()
  local w   = self.db.profile.width
  local gap = self.db.profile.spacing

  if UI.anchor then UI.anchor:SetWidth(w) end

  -- helper for attachments
  local function ensure(name)
    if not UI.attachments[name] then
      UI.attachments[name] = CreateFrame("Frame", "ClassHUDAttach" .. name, UI.anchor)
      UI.attachments[name]:SetSize(1, 1)
    end
    return UI.attachments[name]
  end

  if not UI.trackedContainer then
    UI.trackedContainer = CreateFrame("Frame", "ClassHUDTrackedContainer", UI.anchor, "BackdropTemplate")
    UI.trackedContainer:SetSize(w, 0)
  end

  local trackedContainer = UI.trackedContainer
  UI.tracked = trackedContainer
  trackedContainer:SetParent(UI.anchor)
  trackedContainer:ClearAllPoints()
  trackedContainer:SetPoint("TOPLEFT", UI.anchor, "TOPLEFT", 0, 0)
  trackedContainer:SetPoint("TOPRIGHT", UI.anchor, "TOPRIGHT", 0, 0)
  trackedContainer:SetWidth(w)

  if not self.db.profile.show.buffs then
    trackedContainer:SetHeight(0)
    trackedContainer:Hide()
  else
    trackedContainer:Show()
  end

  local trackedHeight = trackedContainer:GetHeight() or 0
  if trackedHeight < 0 then trackedHeight = 0 end

  local previous = trackedContainer
  local offset = (trackedHeight > 0 and gap) or 0

  local function anchorBar(frame, enabled, height)
    if not frame then return end

    frame:ClearAllPoints()
    if enabled then
      frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -offset)
      frame:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -offset)
      frame:SetWidth(w)
      frame:SetHeight(height)
      frame:Show()
      previous = frame
      offset = gap
    else
      frame:Hide()
    end
  end

  anchorBar(UI.cast, self.db.profile.show.cast, self.db.profile.height.cast)
  anchorBar(UI.hp, self.db.profile.show.hp, self.db.profile.height.hp)
  anchorBar(UI.resource, self.db.profile.show.resource, self.db.profile.height.resource)
  anchorBar(UI.power, self.db.profile.show.power, self.db.profile.height.power)

  -- Update attachment points for spell icon layout
  local top = ensure("TOP")
  top:ClearAllPoints()
  top:SetPoint("BOTTOMLEFT", trackedContainer, "TOPLEFT", 0, 0)
  top:SetPoint("BOTTOMRIGHT", trackedContainer, "TOPRIGHT", 0, 0)
  top:SetHeight(1)

  -- BOTTOM: 1px strip aligned to bottom of power
  local bottom = ensure("BOTTOM")
  bottom:ClearAllPoints()
  bottom:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(1)

  -- LEFT/RIGHT
  local left = ensure("LEFT")
  left:ClearAllPoints()
  left:SetPoint("RIGHT", UI.anchor, "LEFT", -4, 0)

  local right = ensure("RIGHT")
  right:ClearAllPoints()
  right:SetPoint("LEFT", UI.anchor, "RIGHT", 4, 0)

  self:ApplyBarSkins()
end

-- Updates
function ClassHUD:StopCast()
  local casting = UnitCastingInfo("player")
  local channeling = UnitChannelInfo("player")
  if casting or channeling then return end

  if UI.cast then
    UI.cast:SetScript("OnUpdate", nil)
    UI.cast:Hide()
    UI.cast:SetValue(0)
    UI.cast.time:SetText("")
    UI.cast.spell:SetText("")
    UI.cast.icon:SetTexture(nil)
  end
end

function ClassHUD:StartCast(name, icon, startMS, endMS, isChannel)
  if not self.db.profile.show.cast then return end
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
end
