---@type ClassHUD
local ClassHUD = _G.ClassHUD

ClassHUD.Options = ClassHUD.Options or {}

local Options = ClassHUD.Options

local AceConfig = LibStub and LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)

local OPTIONS_APP_NAME = "ClassHUD"

local function getProfile()
  return ClassHUD.db and ClassHUD.db.profile or nil
end

local function ensureLayout(profile)
  profile.layout = profile.layout or {}
  profile.layout.height = profile.layout.height or {}
  profile.layout.show = profile.layout.show or {}
  return profile.layout
end

local function notifyOptionsChanged()
  if AceConfigRegistry then
    AceConfigRegistry:NotifyChange(OPTIONS_APP_NAME)
  end
end

local function ensureFrames()
  if ClassHUD.UI and ClassHUD.UI.EnsureAnchor then
    ClassHUD.UI:EnsureAnchor()
  end

  if ClassHUD.Castbar and ClassHUD.Castbar.CreateCastbar then
    ClassHUD.Castbar:CreateCastbar()
    if ClassHUD.Castbar.RefreshActiveCast then
      ClassHUD.Castbar:RefreshActiveCast()
    end
  end

  if ClassHUD.HPBar and ClassHUD.HPBar.CreateHPBar then
    ClassHUD.HPBar:CreateHPBar()
    if ClassHUD.HPBar.UpdateHP then
      ClassHUD.HPBar:UpdateHP()
    end
  end

  if ClassHUD.ResourceBar and ClassHUD.ResourceBar.CreateResourceBar then
    ClassHUD.ResourceBar:CreateResourceBar()
    if ClassHUD.ResourceBar.UpdatePrimaryResource then
      ClassHUD.ResourceBar:UpdatePrimaryResource()
    end
  end
end

function Options:ApplyLayoutChanges()
  ensureFrames()

  if ClassHUD.Layout and ClassHUD.Layout.RequestLayoutUpdate then
    ClassHUD.Layout:RequestLayoutUpdate()
  end
end

local function setWidth(_, value)
  local profile = getProfile()
  if not profile then
    return
  end

  profile.width = value
  Options:ApplyLayoutChanges()
  notifyOptionsChanged()
end

local function getWidth()
  local profile = getProfile()
  return profile and profile.width or 250
end

local function setSpacing(_, value)
  local profile = getProfile()
  if not profile then
    return
  end

  profile.powerSpacing = value
  Options:ApplyLayoutChanges()
  notifyOptionsChanged()
end

local function getSpacing()
  local profile = getProfile()
  return profile and profile.powerSpacing or 0
end

local function setBarHeight(info, value)
  local profile = getProfile()
  if not profile then
    return
  end

  local layout = ensureLayout(profile)
  local key = info[#info]
  layout.height[key] = value

  Options:ApplyLayoutChanges()
  notifyOptionsChanged()
end

local function getBarHeight(info)
  local profile = getProfile()
  if not profile then
    return 14
  end

  local layout = ensureLayout(profile)
  local key = info[#info]
  return layout.height[key] or 14
end

local function setShowToggle(info, value)
  local profile = getProfile()
  if not profile then
    return
  end

  local layout = ensureLayout(profile)
  local key = info[#info]
  layout.show[key] = value and true or false

  Options:ApplyLayoutChanges()
  notifyOptionsChanged()
end

local function getShowToggle(info)
  local profile = getProfile()
  if not profile then
    return true
  end

  local layout = ensureLayout(profile)
  local key = info[#info]

  if layout.show[key] == nil then
    return true
  end

  return layout.show[key]
end

local function setDebug(_, value)
  local profile = getProfile()
  if not profile then
    return
  end

  profile.debug = value and true or false
  notifyOptionsChanged()
end

local function getDebug()
  local profile = getProfile()
  return profile and profile.debug or false
end

local function buildOptionsTable()
  return {
    type = "group",
    name = "ClassHUD",
    args = {
      general = {
        type = "group",
        name = "General",
        order = 1,
        args = {
          width = {
            type = "range",
            name = "HUD Width",
            desc = "Set the width of the ClassHUD bars.",
            min = 150,
            max = 600,
            step = 1,
            get = getWidth,
            set = setWidth,
            order = 1,
          },
          spacing = {
            type = "range",
            name = "Bar Spacing",
            desc = "Spacing between stacked bars.",
            min = 0,
            max = 20,
            step = 1,
            get = getSpacing,
            set = setSpacing,
            order = 2,
          },
          debug = {
            type = "toggle",
            name = "Enable Debug Logging",
            desc = "Show verbose debug output in chat.",
            get = getDebug,
            set = setDebug,
            order = 3,
          },
        },
      },
      bars = {
        type = "group",
        name = "Bars",
        order = 2,
        args = {
          heights = {
            type = "group",
            name = "Heights",
            inline = true,
            order = 1,
            args = {
              cast = {
                type = "range",
                name = "Cast Bar Height",
                min = 10,
                max = 40,
                step = 1,
                get = getBarHeight,
                set = setBarHeight,
                order = 1,
              },
              hp = {
                type = "range",
                name = "Health Bar Height",
                min = 10,
                max = 40,
                step = 1,
                get = getBarHeight,
                set = setBarHeight,
                order = 2,
              },
              resource = {
                type = "range",
                name = "Resource Bar Height",
                min = 10,
                max = 40,
                step = 1,
                get = getBarHeight,
                set = setBarHeight,
                order = 3,
              },
              power = {
                type = "range",
                name = "Class Power Height",
                min = 10,
                max = 40,
                step = 1,
                get = getBarHeight,
                set = setBarHeight,
                order = 4,
              },
            },
          },
          visibility = {
            type = "group",
            name = "Visibility",
            inline = true,
            order = 2,
            args = {
              cast = {
                type = "toggle",
                name = "Show Cast Bar",
                get = getShowToggle,
                set = setShowToggle,
                order = 1,
              },
              hp = {
                type = "toggle",
                name = "Show Health Bar",
                get = getShowToggle,
                set = setShowToggle,
                order = 2,
              },
              resource = {
                type = "toggle",
                name = "Show Resource Bar",
                get = getShowToggle,
                set = setShowToggle,
                order = 3,
              },
              power = {
                type = "toggle",
                name = "Show Class Power",
                get = getShowToggle,
                set = setShowToggle,
                order = 4,
              },
              buffs = {
                type = "toggle",
                name = "Show Buffs",
                get = getShowToggle,
                set = setShowToggle,
                order = 5,
              },
            },
          },
        },
      },
    },
  }
end

local isRegistered = false

function Options:Register()
  if isRegistered or not AceConfig or not AceConfigDialog then
    return isRegistered
  end

  AceConfig:RegisterOptionsTable(OPTIONS_APP_NAME, buildOptionsTable)
  AceConfigDialog:AddToBlizOptions(OPTIONS_APP_NAME, OPTIONS_APP_NAME)
  isRegistered = true
  return true
end

function Options:Open()
  if not AceConfig or not AceConfigDialog then
    ClassHUD:Msg("AceConfig is not available.")
    return
  end

  if not isRegistered then
    self:Register()
  end

  AceConfigDialog:Open(OPTIONS_APP_NAME)
end

return Options

