---@type ClassHUD
local ClassHUD = _G.ClassHUD

ClassHUD.HPBar = ClassHUD.HPBar or {}

local HPBar = ClassHUD.HPBar

local function isEnabled()
  local profile = ClassHUD.db and ClassHUD.db.profile
  if not profile then
    return true
  end

  local layout = profile.layout
  if layout and layout.show and layout.show.hp == false then
    return false
  end

  return true
end

local function formatPercent(value, maxValue)
  if not maxValue or maxValue == 0 then
    return "0%"
  end

  local percent = (value / maxValue) * 100
  return string.format("%d%%", math.floor(percent + 0.5))
end

local function formatHealthString(value, maxValue)
  local formattedValue = BreakUpLargeNumbers(value or 0)
  local percentText = formatPercent(value or 0, maxValue or 0)
  return string.format("%s (%s)", formattedValue, percentText)
end

function HPBar:CreateHPBar()
  if not ClassHUD.UI or not ClassHUD.UI.EnsureAnchor then
    return nil
  end

  local anchor = ClassHUD.UI:EnsureAnchor()

  local height = (ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.layout and ClassHUD.db.profile.layout.height and ClassHUD.db.profile.layout.height.hp) or 14
  local bar = self.bar

  if not bar or not bar._holder or not bar._holder:IsObjectType("Frame") then
    bar = ClassHUD.UI:CreateStatusBar(anchor, height, true)
    self.bar = bar
  else
    local width = (ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.width) or bar._holder:GetWidth()
    bar._holder:SetSize(width, height)
  end

  local r, g, b = ClassHUD:GetClassColor()
  bar:SetStatusBarColor(r, g, b)

  if bar.bg then
    bar.bg:SetColorTexture(r * 0.2, g * 0.2, b * 0.2, 0.75)
  end

  if bar._holder then
    if isEnabled() then
      bar._holder:Show()
    else
      bar._holder:Hide()
    end
  end

  if isEnabled() then
    bar:Show()
  else
    bar:Hide()
  end

  if ClassHUD.Layout and ClassHUD.Layout.RequestLayoutUpdate then
    ClassHUD.Layout:RequestLayoutUpdate()
  end

  return bar
end

function HPBar:UpdateHP()
  local bar = self.bar or self:CreateHPBar()
  if not bar then
    return
  end

  local current = UnitHealth("player") or 0
  local maxValue = UnitHealthMax("player") or 0

  bar:SetMinMaxValues(0, math.max(maxValue, 1))
  bar:SetValue(current)

  local r, g, b = ClassHUD:GetClassColor()
  bar:SetStatusBarColor(r, g, b)
  if bar.bg then
    bar.bg:SetColorTexture(r * 0.2, g * 0.2, b * 0.2, 0.75)
  end

  if bar.text then
    bar.text:SetText(formatHealthString(current, maxValue))
  end

  if not isEnabled() then
    if bar._holder then
      bar._holder:Hide()
    end
    bar:Hide()
  end

  if ClassHUD.Layout and ClassHUD.Layout.RequestLayoutUpdate then
    ClassHUD.Layout:RequestLayoutUpdate()
  end
end

function HPBar:ShouldLayout()
  return isEnabled()
end

return HPBar
