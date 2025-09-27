---@type ClassHUD
local ClassHUD = _G.ClassHUD

ClassHUD.Castbar = ClassHUD.Castbar or {}

local Castbar = ClassHUD.Castbar

local UPDATE_THROTTLE = 0.1

local function formatTime(seconds)
  if not seconds or seconds < 0 then
    seconds = 0
  end

  return string.format("%.1f", seconds)
end

local function applyBarColor(bar)
  if not bar then
    return
  end

  local r, g, b = ClassHUD:GetClassColor()
  bar:SetStatusBarColor(r, g, b)

  if bar.bg then
    bar.bg:SetColorTexture(r * 0.2, g * 0.2, b * 0.2, 0.75)
  end
end

local function handleSizeChanged(self, width, height)
  local icon = self.icon
  local status = self.bar
  local nameText = self.nameText
  local timeText = self.timeText

  local iconSize = height or (icon and icon:GetHeight()) or 16

  if icon then
    icon:SetSize(iconSize, iconSize)
  end

  if status and icon then
    status:ClearAllPoints()
    status:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 0)
    status:SetPoint("BOTTOMRIGHT", self.holder, "BOTTOMRIGHT", 0, 0)
  elseif status then
    status:SetAllPoints(self.holder)
  end

  local fontSize = math.max(10, (height or 0) - 2)

  if nameText then
    nameText:SetFont(ClassHUD:FetchFont(), fontSize, "OUTLINE")
  end

  if timeText then
    timeText:SetFont(ClassHUD:FetchFont(), fontSize, "OUTLINE")
  end
end

local function ensureOnUpdate(self)
  if not self.holder then
    return
  end

  self.holder:SetScript("OnUpdate", function(_, elapsed)
    Castbar:OnUpdate(elapsed)
  end)
end

function Castbar:CreateCastbar()
  if self.holder and self.holder:IsObjectType("Frame") then
    return self.holder
  end

  if not ClassHUD.UI or not ClassHUD.UI.EnsureAnchor then
    return nil
  end

  local anchor = ClassHUD.UI:EnsureAnchor()
  local profile = (ClassHUD.db and ClassHUD.db.profile) or {}
  local width = profile.width or 250
  local layout = profile.layout or {}
  local heights = layout.height or {}
  local height = heights.cast or 18

  local holder = CreateFrame("Frame", nil, anchor)
  holder:SetSize(width, height)
  holder:Hide()

  local icon = holder:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("LEFT", holder, "LEFT", 0, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetSize(height, height)

  local iconBG = holder:CreateTexture(nil, "BACKGROUND")
  iconBG:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
  iconBG:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
  iconBG:SetColorTexture(0, 0, 0, 0.6)

  local status = CreateFrame("StatusBar", nil, holder)
  status:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 0)
  status:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
  status:SetStatusBarTexture(ClassHUD:FetchStatusbar())
  status:SetMinMaxValues(0, 1)
  status:SetValue(0)

  local bg = status:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.6)
  status.bg = bg

  local nameText = status:CreateFontString(nil, "OVERLAY")
  nameText:SetPoint("LEFT", status, "LEFT", 4, 0)
  nameText:SetJustifyH("LEFT")
  nameText:SetTextColor(1, 1, 1)
  nameText:SetText("")

  local timeText = status:CreateFontString(nil, "OVERLAY")
  timeText:SetPoint("RIGHT", status, "RIGHT", -4, 0)
  timeText:SetJustifyH("RIGHT")
  timeText:SetTextColor(1, 1, 1)
  timeText:SetText("")

  holder:SetScript("OnSizeChanged", function(_, w, h)
    handleSizeChanged(Castbar, w, h)
  end)

  self.holder = holder
  self.bar = status
  self.icon = icon
  self.iconBG = iconBG
  self.nameText = nameText
  self.timeText = timeText
  self.updateElapsed = 0
  self.active = false

  status._holder = holder

  handleSizeChanged(self, width, height)
  applyBarColor(status)

  return holder
end

function Castbar:GetLayoutFrame()
  return self.holder
end

function Castbar:ShouldLayout()
  return self.active == true
end

function Castbar:OnSizeChanged(width, height)
  handleSizeChanged(self, width, height)
end

function Castbar:RefreshActiveCast()
  local holder = self:CreateCastbar()
  if not holder then
    return
  end

  local name, _, texture, startMS, endMS, _, castGUID = UnitCastingInfo("player")
  if name and startMS and endMS then
    self:StartCast(name, texture, startMS, endMS, false, castGUID)
    return
  end

  local chanName, _, chanTexture, chanStartMS, chanEndMS = UnitChannelInfo("player")
  if chanName and chanStartMS and chanEndMS then
    self:StartCast(chanName, chanTexture, chanStartMS, chanEndMS, true)
    return
  end

  self:StopCast()
end

function Castbar:StartCast(name, iconTexture, startMS, endMS, isChannel, castGUID)
  local holder = self:CreateCastbar()
  local bar = self.bar

  if not holder or not bar or not startMS or not endMS then
    return
  end

  self.startTime = startMS / 1000
  self.endTime = endMS / 1000
  self.duration = math.max(0.001, self.endTime - self.startTime)
  self.isChannel = isChannel or false
  self.castGUID = castGUID
  self.active = true
  self.updateElapsed = 0

  if self.icon then
    self.icon:SetTexture(iconTexture or "Interface/ICONS/INV_Misc_QuestionMark")
    self.icon:Show()
  end

  if self.nameText then
    self.nameText:SetText(name or "")
  end

  if self.timeText then
    local now = GetTime()
    local remaining = self.isChannel and (self.endTime - now) or (self.endTime - now)
    self.timeText:SetText(formatTime(remaining))
  end

  bar:SetMinMaxValues(0, self.duration)
  bar:SetReverseFill(self.isChannel and true or false)
  applyBarColor(bar)

  local now = GetTime()
  if self.isChannel then
    bar:SetValue(math.max(0, self.endTime - now))
  else
    bar:SetValue(math.max(0, now - self.startTime))
  end

  holder:Show()
  bar:Show()

  ensureOnUpdate(self)

  if ClassHUD.Layout and ClassHUD.Layout.RequestLayoutUpdate then
    ClassHUD.Layout:RequestLayoutUpdate()
  end
end

function Castbar:StopCast()
  if not self.active then
    return
  end

  self.active = false
  self.startTime = nil
  self.endTime = nil
  self.duration = nil
  self.isChannel = nil
  self.castGUID = nil

  if self.holder then
    self.holder:SetScript("OnUpdate", nil)
    self.holder:Hide()
  end

  if self.bar then
    self.bar:Hide()
    self.bar:SetValue(0)
    self.bar:SetReverseFill(false)
  end

  if self.icon then
    self.icon:SetTexture(nil)
  end

  if self.nameText then
    self.nameText:SetText("")
  end

  if self.timeText then
    self.timeText:SetText("")
  end

  if ClassHUD.Layout and ClassHUD.Layout.RequestLayoutUpdate then
    ClassHUD.Layout:RequestLayoutUpdate()
  end
end

function Castbar:OnUpdate(elapsed)
  if not self.active or not self.bar then
    return
  end

  self.updateElapsed = (self.updateElapsed or 0) + elapsed
  if self.updateElapsed < UPDATE_THROTTLE then
    return
  end

  self.updateElapsed = 0

  local startTime = self.startTime
  local endTime = self.endTime

  if not startTime or not endTime then
    self:StopCast()
    return
  end

  local now = GetTime()
  local duration = endTime - startTime

  if not self.isChannel then
    local elapsedTime = now - startTime
    if elapsedTime >= duration then
      self:StopCast()
      return
    end

    self.bar:SetValue(math.max(0, elapsedTime))
    if self.timeText then
      self.timeText:SetText(formatTime(endTime - now))
    end
  else
    local remaining = endTime - now
    if remaining <= 0 then
      self:StopCast()
      return
    end

    self.bar:SetValue(math.max(0, remaining))
    if self.timeText then
      self.timeText:SetText(formatTime(remaining))
    end
  end
end

function Castbar:HandleSpellcastStart(unit, castGUID)
  if unit ~= "player" then
    return
  end

  local name, _, texture, startMS, endMS, _, castID = UnitCastingInfo(unit)
  if not name then
    return
  end

  self:StartCast(name, texture, startMS, endMS, false, castGUID or castID)
end

function Castbar:HandleChannelStart(unit)
  if unit ~= "player" then
    return
  end

  local name, _, texture, startMS, endMS = UnitChannelInfo(unit)
  if not name then
    return
  end

  self:StartCast(name, texture, startMS, endMS, true)
end

function Castbar:HandleSpellcastStop(unit)
  if unit ~= "player" then
    return
  end

  self:StopCast()
end

return Castbar
