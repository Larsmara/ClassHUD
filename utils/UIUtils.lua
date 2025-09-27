---@type ClassHUD
local ClassHUD = _G.ClassHUD

ClassHUD.UI = ClassHUD.UI or {}

local LibSharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"

function ClassHUD.UI:CreateHolder(name, parent)
  local frame = CreateFrame("Frame", name, parent)
  frame:Hide()
  return frame
end

function ClassHUD.UI:ApplyBackdrop(frame)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.75)
end

function ClassHUD.UI:EnsureAnchor()
  if self.anchor and self.anchor:IsObjectType("Frame") then
    local width = (ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.width) or 250
    self.anchor:SetSize(width, 20)
    if not self.anchor:IsShown() then
      self.anchor:Show()
    end
    return self.anchor
  end

  local anchor = CreateFrame("Frame", "ClassHUDAnchor", UIParent, "BackdropTemplate")
  anchor:SetSize((ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.width) or 250, 20)
  anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  anchor:SetFrameStrata("LOW")
  anchor:SetClampedToScreen(true)
  anchor:SetMovable(true)
  anchor:EnableMouse(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", function(frame)
    frame:StartMoving()
  end)
  anchor:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
  end)

  local background = anchor:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0, 1, 0, 0.15)
  anchor.background = background

  local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("CENTER")
  label:SetText("ClassHUD Anchor")
  anchor.label = label

  anchor:Show()

  self.anchor = anchor
  return anchor
end

function ClassHUD.UI:CreateStatusBar(parent, height, withBG)
  local anchor = self:EnsureAnchor()
  parent = parent or anchor

  local profile = (ClassHUD.db and ClassHUD.db.profile) or {}
  local width = profile.width or 250
  local barHeight = height or 14

  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width, barHeight)

  local status = CreateFrame("StatusBar", nil, holder)
  status:SetAllPoints(holder)
  status:SetStatusBarTexture(ClassHUD:FetchStatusbar())
  status:SetMinMaxValues(0, 1)
  status:SetValue(0)

  if withBG then
    local bg = status:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local r, g, b = ClassHUD:GetClassColor()
    bg:SetColorTexture(r * 0.2, g * 0.2, b * 0.2, 0.75)
    status.bg = bg
  end

  local text = status:CreateFontString(nil, "OVERLAY")
  text:SetFont(ClassHUD:FetchFont(), math.max(10, barHeight - 2), "OUTLINE")
  text:SetPoint("CENTER", status, "CENTER", 0, 0)
  text:SetText("")
  status.text = text

  status._holder = holder

  return status
end

function ClassHUD:GetClassColor(classToken)
  local token = classToken or select(2, UnitClass("player"))
  if token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then
    local color = RAID_CLASS_COLORS[token]
    return color.r, color.g, color.b
  end

  return 1, 1, 1
end

function ClassHUD:PowerColorBy(id, token)
  local lookupKey = token or id
  local color

  if lookupKey ~= nil then
    if type(lookupKey) == "string" and PowerBarColor and PowerBarColor[lookupKey] then
      color = PowerBarColor[lookupKey]
    elseif type(lookupKey) == "number" and PowerBarColor and PowerBarColor[lookupKey] then
      color = PowerBarColor[lookupKey]
    end
  end

  if not color and token and GetPowerBarColor then
    local r, g, b = GetPowerBarColor(token)
    if r then
      return r, g, b
    end
  elseif not color and id and GetPowerBarColor then
    local r, g, b = GetPowerBarColor(id)
    if r then
      return r, g, b
    end
  end

  if color then
    return color.r, color.g, color.b
  end

  return 0.8, 0.8, 0.8
end

function ClassHUD:FetchFont()
  if LibSharedMedia then
    local font = LibSharedMedia:Fetch("font", "Friz Quadrata TT")
    if font then
      return font
    end
  end

  return DEFAULT_FONT
end

function ClassHUD:FetchStatusbar()
  if LibSharedMedia then
    local texture = LibSharedMedia:Fetch("statusbar", "Blizzard")
    if texture then
      return texture
    end
  end

  return DEFAULT_STATUSBAR
end

function ClassHUD:GetPlayerClassSpec()
  local classToken = select(2, UnitClass("player"))
  local specIndex = GetSpecialization()
  local specID

  if specIndex then
    specID = select(1, GetSpecializationInfo(specIndex))
  end

  return classToken, specID
end
