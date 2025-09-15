local addon = ClassHUD
local UI = addon.UI

function addon:ApplyAnchorPosition()
  if not UI.anchor then return end
  local pos = self.db.profile.position or { x = 0, y = -350 }
  UI.anchor:ClearAllPoints()
  UI.anchor:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end

function addon:CreateAnchor()
  if UI.anchor then return UI.anchor end
  local f = CreateFrame("Frame", "ClassHUDAnchor", UIParent, "BackdropTemplate")
  f:SetSize(self.db and self.db.profile and self.db.profile.width or 250, 1)
  f:SetMovable(false)
  UI.anchor = f
  return f
end

function addon:CreateStatusBar(parent, height)
  local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
  bar:SetStatusBarTexture(self:FetchStatusbar())
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(true)
  bar.bg:SetColorTexture(0, 0, 0, 0.55)

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont(self:FetchFont(12))

  bar:SetHeight(height)
  bar:SetWidth(self.db.profile.width)
  return bar
end

function addon:CreateCastBar()
  if UI.cast then return UI.cast end
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
  return b
end

function addon:CreateHPBar()
  if UI.hp then return UI.hp end
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.height.hp)
  local r, g, bCol = self:GetClassColor()
  b:SetStatusBarColor(r, g, bCol)
  UI.hp = b
  return b
end

function addon:CreateResourceBar()
  if UI.resource then return UI.resource end
  local b = self:CreateStatusBar(UI.anchor, self.db.profile.height.resource)
  if self.db.profile.colors.resourceClass then
    b:SetStatusBarColor(self:GetClassColor())
  else
    local c = self.db.profile.colors.resource
    b:SetStatusBarColor(c.r, c.g, c.b)
  end
  UI.resource = b
  return b
end

function addon:ApplyBarSkins()
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

function addon:LayoutBars()
  local w   = self.db.profile.width
  local gap = self.db.profile.spacing

  UI.anchor:SetWidth(w)

  local y = 0

  if self.db.profile.show.cast then
    UI.cast:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.cast:SetWidth(w)
    UI.cast:SetHeight(self.db.profile.height.cast)
    y = y + UI.cast:GetHeight() + gap
  else
    UI.cast:ClearAllPoints(); UI.cast:Hide()
  end

  if self.db.profile.show.hp then
    UI.hp:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.hp:SetWidth(w)
    UI.hp:SetHeight(self.db.profile.height.hp)
    y = y + UI.hp:GetHeight() + gap
  else
    UI.hp:ClearAllPoints(); UI.hp:Hide()
  end

  if self.db.profile.show.resource then
    UI.resource:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.resource:SetWidth(w)
    UI.resource:SetHeight(self.db.profile.height.resource)
    y = y + UI.resource:GetHeight() + gap
  else
    UI.resource:ClearAllPoints(); UI.resource:Hide()
  end

  if self.db.profile.show.power then
    UI.power:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.power:SetWidth(w)
    UI.power:SetHeight(self.db.profile.height.power)
  else
    UI.power:ClearAllPoints(); UI.power:Hide()
  end

  local function ensure(name)
    if not UI.attachments[name] then
      UI.attachments[name] = CreateFrame("Frame", "ClassHUDAttach" .. name, UI.anchor)
      UI.attachments[name]:SetSize(1, 1)
    end
    return UI.attachments[name]
  end

  local top = ensure("TOP")
  top:ClearAllPoints()
  top:SetPoint("BOTTOMLEFT", UI.cast, "TOPLEFT", 0, 0)
  top:SetPoint("BOTTOMRIGHT", UI.cast, "TOPRIGHT", 0, 0)
  top:SetHeight(1)

  local bottom = ensure("BOTTOM")
  bottom:ClearAllPoints()
  bottom:SetPoint("TOPLEFT", UI.power, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("TOPRIGHT", UI.power, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(1)

  local left = ensure("LEFT")
  left:ClearAllPoints()
  left:SetPoint("RIGHT", UI.anchor, "LEFT", -4, 0)

  local right = ensure("RIGHT")
  right:ClearAllPoints()
  right:SetPoint("LEFT", UI.anchor, "RIGHT", 4, 0)

  self:ApplyBarSkins()
end

function addon:StopCast()
  local casting = UnitCastingInfo("player")
  local channeling = UnitChannelInfo("player")
  if casting or channeling then
    return
  end

  if UI.cast then
    UI.cast:SetScript("OnUpdate", nil)
    UI.cast:Hide()
    UI.cast:SetValue(0)
    UI.cast.time:SetText("")
    UI.cast.spell:SetText("")
    UI.cast.icon:SetTexture(nil)
  end
end

function addon:StartCast(name, icon, startMS, endMS)
  if not self.db.profile.show.cast then return end
  local total = (endMS - startMS) / 1000
  local start = startMS / 1000

  UI.cast:Show()
  UI.cast.spell:SetText(name or "")
  UI.cast.icon:SetTexture(icon or 136243)
  UI.cast:SetStatusBarColor(1, .7, 0)

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

function addon:UNIT_SPELLCAST_START(_, unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitCastingInfo("player")
  if name then
    self:StartCast(name, icon, startMS, endMS)
  end
end

function addon:UNIT_SPELLCAST_CHANNEL_START(_, unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitChannelInfo("player")
  if name then
    self:StartCast(name, icon, startMS, endMS)
  end
end

function addon:UNIT_SPELLCAST_SUCCEEDED(_, unit, spellID)
  if unit ~= "player" then return end
  local name, _, icon = C_Spell.GetSpellInfo(spellID)
  if name and not UnitCastingInfo("player") and not UnitChannelInfo("player") then
    local now = GetTime() * 1000
    self:StartCast(name, icon, now, now + 1000)
  end
end

function addon:UNIT_SPELLCAST_STOP(_, unit)
  if unit == "player" then self:StopCast() end
end

function addon:UNIT_SPELLCAST_CHANNEL_STOP(_, unit)
  if unit == "player" then self:StopCast() end
end

function addon:UNIT_SPELLCAST_INTERRUPTED(_, unit)
  if unit == "player" then self:StopCast() end
end

function addon:UNIT_SPELLCAST_FAILED(_, unit)
  if unit == "player" then self:StopCast() end
end

function addon:UpdateHP()
  if not self.db.profile.show.hp then return end
  local cur, max = UnitHealth("player"), UnitHealthMax("player")
  UI.hp:SetMinMaxValues(0, max)
  UI.hp:SetValue(cur)
  local pct = (max > 0) and (cur / max * 100) or 0
  UI.hp.text:SetFormattedText("%d%%", pct + 0.5)
end

function addon:UpdatePrimaryResource()
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
