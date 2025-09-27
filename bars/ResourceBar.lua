---@type ClassHUD
local ClassHUD = _G.ClassHUD

ClassHUD.ResourceBar = ClassHUD.ResourceBar or {}

local ResourceBar = ClassHUD.ResourceBar

local function isEnabled()
  local profile = ClassHUD.db and ClassHUD.db.profile
  if not profile then
    return true
  end

  local layout = profile.layout
  if layout and layout.show and layout.show.resource == false then
    return false
  end

  return true
end

local function formatResourceText(value, maxValue)
  local formattedValue = BreakUpLargeNumbers(value or 0)
  local formattedMax = BreakUpLargeNumbers(maxValue or 0)
  return string.format("%s / %s", formattedValue, formattedMax)
end

local function getPlayerPowerType()
  local id, token = UnitPowerType("player")
  return id or 0, token
end

local function applyColor(bar, id, token)
  if not id then
    id, token = getPlayerPowerType()
  end

  local r, g, b = ClassHUD:PowerColorBy(id, token)
  bar:SetStatusBarColor(r, g, b)
  if bar.bg then
    bar.bg:SetColorTexture(r * 0.2, g * 0.2, b * 0.2, 0.75)
  end
end

function ResourceBar:CreateResourceBar()
  if not ClassHUD.UI or not ClassHUD.UI.EnsureAnchor then
    return nil
  end

  local anchor = ClassHUD.UI:EnsureAnchor()

  local height = (ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.layout and ClassHUD.db.profile.layout.height and ClassHUD.db.profile.layout.height.resource) or 14
  local bar = self.bar

  if not bar or not bar._holder or not bar._holder:IsObjectType("Frame") then
    bar = ClassHUD.UI:CreateStatusBar(anchor, height, true)
    self.bar = bar
  else
    local width = (ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.width) or bar._holder:GetWidth()
    bar._holder:SetSize(width, height)
  end

  applyColor(bar)

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

function ResourceBar:UpdatePrimaryResource()
  local bar = self.bar or self:CreateResourceBar()
  if not bar then
    return
  end

  local id, powerType = getPlayerPowerType()

  local current = UnitPower("player", id) or 0
  local maxValue = UnitPowerMax("player", id) or 0

  bar:SetMinMaxValues(0, math.max(maxValue, 1))
  bar:SetValue(current)

  applyColor(bar, id, powerType)

  if bar.text then
    bar.text:SetText(formatResourceText(current, maxValue))
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

function ResourceBar:ShouldLayout()
  return isEnabled()
end

return ResourceBar
