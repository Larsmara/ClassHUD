---@type ClassHUD
local ClassHUD = _G.ClassHUD

ClassHUD.Layout = ClassHUD.Layout or {}

local Layout = ClassHUD.Layout

local orderedBars = {
  { key = "cast", module = "Castbar" },
  { key = "hp", module = "HPBar" },
  { key = "resource", module = "ResourceBar" },
  { key = "power", module = "ClassBar" },
}

local function isBarEnabled(key)
  if not key then
    return true
  end

  local profile = ClassHUD.db and ClassHUD.db.profile
  if not profile then
    return true
  end

  local layout = profile.layout
  if layout and layout.show and layout.show[key] == false then
    return false
  end

  return true
end

local function resolveHolder(entry)
  local module = ClassHUD[entry.module]
  if not module then
    return nil, nil, nil
  end

  if type(module.GetLayoutFrame) == "function" then
    local frame = module:GetLayoutFrame()
    if frame and frame.IsObjectType and frame:IsObjectType("Frame") then
      return frame, frame, module
    end
  end

  if module.bar and module.bar._holder and module.bar._holder.IsObjectType and module.bar._holder:IsObjectType("Frame") then
    return module.bar._holder, module.bar, module
  end

  if module.holder and module.holder.IsObjectType and module.holder:IsObjectType("Frame") then
    return module.holder, module.bar or module.holder, module
  end

  if module.frame and module.frame.IsObjectType and module.frame:IsObjectType("Frame") then
    return module.frame, module.bar or module.frame, module
  end

  return nil, nil, module
end

local function collectStatusBars()
  local bars = {}

  for _, entry in ipairs(orderedBars) do
    local holder, bar, module = resolveHolder(entry)
    if holder then
      local shouldInclude = true

      if module and type(module.ShouldLayout) == "function" then
        shouldInclude = module:ShouldLayout() and true or false
      end

      if shouldInclude then
        shouldInclude = isBarEnabled(entry.key)
      end

      if shouldInclude then
        table.insert(bars, {
          holder = holder,
          bar = bar,
          heightKey = entry.key,
          module = module,
        })
      else
        if holder.Hide then
          holder:Hide()
        end
        if bar and bar.Hide then
          bar:Hide()
        end
      end
    end
  end

  return bars
end

local function getAnchor()
  if not ClassHUD.UI or not ClassHUD.UI.EnsureAnchor then
    return nil
  end

  return ClassHUD.UI:EnsureAnchor()
end

local function getSpacing()
  if ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.powerSpacing then
    return ClassHUD.db.profile.powerSpacing
  end

  return 0
end

local function getProfileSize(heightKey)
  if not ClassHUD.db or not ClassHUD.db.profile then
    return nil, nil
  end

  local width = ClassHUD.db.profile.width
  local layout = ClassHUD.db.profile.layout
  local height

  if layout and layout.height and heightKey then
    height = layout.height[heightKey]
  end

  return width, height
end

function Layout:Layout()
  local anchor = getAnchor()
  if not anchor then
    return
  end

  local bars = collectStatusBars()
  local spacing = getSpacing()
  local previous = anchor

  for _, info in ipairs(bars) do
    local holder = info.holder
    local bar = info.bar
    local width, height = getProfileSize(info.heightKey)

    if width or height then
      holder:SetSize(width or holder:GetWidth(), height or holder:GetHeight())
      if info.module and type(info.module.OnSizeChanged) == "function" then
        info.module:OnSizeChanged(width or holder:GetWidth(), height or holder:GetHeight())
      end
    end

    holder:ClearAllPoints()
    holder:SetPoint("TOP", previous, "BOTTOM", 0, -spacing)
    holder:Show()

    if bar and bar.Show then
      bar:Show()
    end

    previous = holder
  end

  ClassHUD:Debug("Layout applied.")
end

function Layout:RequestLayoutUpdate()
  self:Layout()
end

return Layout
