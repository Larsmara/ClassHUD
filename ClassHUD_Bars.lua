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

  local y = 0

  -- Cast (top)
  if self.db.profile.show.cast then
    UI.cast:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.cast:SetWidth(w)
    UI.cast:SetHeight(self.db.profile.height.cast)
    y = y + UI.cast:GetHeight() + gap
  else
    UI.cast:ClearAllPoints(); UI.cast:Hide()
  end

  -- HP
  if self.db.profile.show.hp then
    UI.hp:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.hp:SetWidth(w)
    UI.hp:SetHeight(self.db.profile.height.hp)
    y = y + UI.hp:GetHeight() + gap
  else
    UI.hp:ClearAllPoints(); UI.hp:Hide()
  end

  -- Primary resource
  if self.db.profile.show.resource then
    UI.resource:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.resource:SetWidth(w)
    UI.resource:SetHeight(self.db.profile.height.resource)
    y = y + UI.resource:GetHeight() + gap
  else
    UI.resource:ClearAllPoints(); UI.resource:Hide()
  end

  -- Special power container
  if self.db.profile.show.power then
    UI.power:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.power:SetWidth(w)
    UI.power:SetHeight(self.db.profile.height.power)
  else
    UI.power:ClearAllPoints(); UI.power:Hide()
  end

  -- Update attachment points for spell icon layout
  local top = ensure("TOP")
  top:ClearAllPoints()
  top:SetPoint("BOTTOMLEFT", UI.cast, "TOPLEFT", 0, 0)
  top:SetPoint("BOTTOMRIGHT", UI.cast, "TOPRIGHT", 0, 0)
  top:SetHeight(1)

  -- BOTTOM: 1px strip aligned to bottom of power
  local bottom = ensure("BOTTOM")
  bottom:ClearAllPoints()
  bottom:SetPoint("TOPLEFT", UI.power, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("TOPRIGHT", UI.power, "BOTTOMRIGHT", 0, 0)
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
