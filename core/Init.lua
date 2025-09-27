local ADDON_NAME = ...
local AceAddon = LibStub("AceAddon-3.0")

---@class ClassHUD : AceAddon-3.0, AceEvent-3.0, AceConsole-3.0
local ClassHUD = AceAddon:NewAddon("ClassHUD", "AceEvent-3.0", "AceConsole-3.0")
ClassHUD:SetDefaultModuleState(true)

_G.ClassHUD = ClassHUD

local function trim(input)
  if not input then return "" end
  return input:match("^%s*(.-)%s*$") or ""
end

local function printMessage(addon, text)
  if type(addon.Msg) == "function" then
    addon:Msg(text)
  else
    print(text)
  end
end

local function ensureBars()
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

function ClassHUD:OnInitialize()
  if type(self.InitializeDatabase) == "function" then
    self:InitializeDatabase()
  end

  self:RegisterChatCommand("chud", "HandleSlashCommand")
end

function ClassHUD:OnEnable()
  printMessage(self, "ClassHUD enabled. Use /chud for options.")

  ensureBars()

  self:RegisterUnitEvent("UNIT_HEALTH", "player")
  self:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
  self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
  self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function ClassHUD:OnDisable()
  printMessage(self, "ClassHUD disabled.")
  self:UnregisterAllEvents()

  if self.Castbar and self.Castbar.StopCast then
    self.Castbar:StopCast()
  end
end

local function setDebugState(addon, enabled)
  if not addon.db or not addon.db.profile then
    return nil
  end

  addon.db.profile.debug = enabled and true or false
  return addon.db.profile.debug
end

function ClassHUD:HandleSlashCommand(input)
  local cleaned = trim(input)
  if cleaned == "" then
    printMessage(self, "Usage: /chud debug on|off|toggle")
    return
  end

  local command, rest = self:GetArgs(cleaned, 2)
  command = command and command:lower() or ""

  if command == "debug" then
    local argument = trim(rest):lower()
    if argument == "on" or argument == "enable" then
      local state = setDebugState(self, true)
      if state == nil then
        printMessage(self, "Unable to enable debug logging (database not ready).")
      else
        printMessage(self, "Debug logging enabled.")
      end
    elseif argument == "off" or argument == "disable" then
      local state = setDebugState(self, false)
      if state == nil then
        printMessage(self, "Unable to disable debug logging (database not ready).")
      else
        printMessage(self, "Debug logging disabled.")
      end
    elseif argument == "toggle" or argument == "" then
      local current = (self.db and self.db.profile and self.db.profile.debug) or false
      local state = setDebugState(self, not current)
      if state == nil then
        printMessage(self, "Unable to toggle debug logging (database not ready).")
      elseif state then
        printMessage(self, "Debug logging enabled.")
      else
        printMessage(self, "Debug logging disabled.")
      end
    else
      printMessage(self, "Usage: /chud debug on|off|toggle")
    end
  else
    printMessage(self, "Unknown command. Usage: /chud debug on|off|toggle")
  end
end

function ClassHUD:PLAYER_ENTERING_WORLD()
  ensureBars()
end

function ClassHUD:UNIT_HEALTH(_, unit)
  if unit ~= "player" then
    return
  end

  if self.HPBar and self.HPBar.UpdateHP then
    self.HPBar:UpdateHP()
  end
end

function ClassHUD:UNIT_MAXHEALTH(event, unit)
  self:UNIT_HEALTH(event, unit)
end

function ClassHUD:UNIT_POWER_UPDATE(_, unit)
  if unit ~= "player" then
    return
  end

  if self.ResourceBar and self.ResourceBar.UpdatePrimaryResource then
    self.ResourceBar:UpdatePrimaryResource()
  end
end

function ClassHUD:UNIT_MAXPOWER(event, unit)
  self:UNIT_POWER_UPDATE(event, unit)
end

function ClassHUD:UNIT_DISPLAYPOWER(_, unit)
  if unit ~= "player" then
    return
  end

  ensureBars()
end

function ClassHUD:UNIT_SPELLCAST_START(_, unit, castGUID)
  if unit ~= "player" then
    return
  end

  if self.Castbar and self.Castbar.HandleSpellcastStart then
    self.Castbar:HandleSpellcastStart(unit, castGUID)
  end
end

function ClassHUD:UNIT_SPELLCAST_STOP(_, unit)
  if unit ~= "player" then
    return
  end

  if self.Castbar and self.Castbar.HandleSpellcastStop then
    self.Castbar:HandleSpellcastStop(unit)
  end
end

function ClassHUD:UNIT_SPELLCAST_INTERRUPTED(_, unit)
  if unit ~= "player" then
    return
  end

  if self.Castbar and self.Castbar.HandleSpellcastStop then
    self.Castbar:HandleSpellcastStop(unit)
  end
end

function ClassHUD:UNIT_SPELLCAST_FAILED(_, unit)
  if unit ~= "player" then
    return
  end

  if self.Castbar and self.Castbar.HandleSpellcastStop then
    self.Castbar:HandleSpellcastStop(unit)
  end
end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_START(_, unit)
  if unit ~= "player" then
    return
  end

  if self.Castbar and self.Castbar.HandleChannelStart then
    self.Castbar:HandleChannelStart(unit)
  end
end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(_, unit)
  if unit ~= "player" then
    return
  end

  if self.Castbar and self.Castbar.HandleSpellcastStop then
    self.Castbar:HandleSpellcastStop(unit)
  end
end

return ClassHUD
