-- ClassHUD.lua
-- Minimal bootstrap + Cooldown Viewer integration.

local ADDON_NAME = ...

---@class ClassHUDAddon
local ClassHUD = _G.ClassHUD or {}
_G.ClassHUD = ClassHUD
ClassHUD.name = ADDON_NAME

-- -----------------------------------------------------------------------------
-- Saved variables & defaults
-- -----------------------------------------------------------------------------
local defaults = {
  bars = {
    width = 280,
    spacing = 0,
    texture = "Interface\\TargetingFrame\\UI-StatusBar",
    font = "Fonts\\FRIZQT__.TTF",
    cast = { enabled = true, height = 18, textSize = 12 },
    health = { enabled = true, height = 18, textSize = 12 },
    resource = { enabled = true, height = 14, textSize = 12 },
    class = { enabled = true, height = 16, segmentSpacing = 2 },
  },
  buffs = {
    enabled = true,
    iconSize = 32,
    spacing = 4,
    rows = 2,
    perRow = 10,
    customSpellIDs = {},
    hiddenSpellIDs = {},
  },
}

local function copyTable(src)
  local tbl = {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      tbl[k] = copyTable(v)
    else
      tbl[k] = v
    end
  end
  return tbl
end

local function applyDefaults(target, template)
  for key, value in pairs(template) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = copyTable(value)
      else
        applyDefaults(target[key], value)
      end
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

ClassHUDDB = ClassHUDDB or {}
applyDefaults(ClassHUDDB, defaults)
if ClassHUDDB.bars and ClassHUDDB.bars.spacing == 6 then
  ClassHUDDB.bars.spacing = 0
end
ClassHUD.db = ClassHUDDB

-- Provide lightweight accessors for modules
function ClassHUD:GetBarsConfig()
  return self.db and self.db.bars or defaults.bars
end

function ClassHUD:GetBuffConfig()
  return self.db and self.db.buffs or defaults.buffs
end

function ClassHUD:IsBarEnabled(name)
  local cfg = self:GetBarsConfig()
  local block = cfg and cfg[name]
  return block and block.enabled
end

-- -----------------------------------------------------------------------------
-- Cooldown Viewer safety helpers
-- -----------------------------------------------------------------------------
local FALLBACK_COOLDOWN_ENUM = {
  Essential = 0,
  Utility = 1,
  TrackedBuff = 2,
  TrackedBar = 3,
}

function ClassHUD:GetCooldownCategory(category)
  local enum = Enum and Enum.CooldownViewerCategory
  if enum and enum[category] then
    return enum[category]
  end
  return FALLBACK_COOLDOWN_ENUM[category]
end

local function safeCategorySet(category)
  if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then
    return nil
  end
  local ok, result = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category)
  if ok then
    return result
  end
end

local function safeCooldownInfo(cooldownID)
  if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
    return nil
  end
  local ok, result = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
  if ok then
    return result
  end
end

local function extractSpellID(info)
  if type(info) ~= "table" then
    return nil
  end
  if type(info.spellID) == "number" then
    return info.spellID
  end
  if type(info.overrideSpellID) == "number" then
    return info.overrideSpellID
  end
  if type(info.auraSpellID) == "number" then
    return info.auraSpellID
  end
  if type(info.linkedSpellIDs) == "table" then
    for _, linked in ipairs(info.linkedSpellIDs) do
      if type(linked) == "number" then
        return linked
      end
    end
  end
end

-- -----------------------------------------------------------------------------
-- Core helpers
-- -----------------------------------------------------------------------------
function ClassHUD:EnableCooldownViewer()
  if type(SetCVar) == "function" then
    SetCVar("cooldownViewerEnabled", "1")
  end
end

function ClassHUD:GetEssentialFrame()
  return _G.EssentialCooldownViewer
end

function ClassHUD:EnsureModules()
  if not self.bars then
    self:CreateBars()
  end
  if not self.buffBar then
    self:CreateBuffBar()
  end
end

function ClassHUD:AnchorFrames()
  self:EnsureModules()

  local bars = self.bars
  local buffs = self.buffBar
  if not bars then
    return
  end

  local cfg = self:GetBarsConfig()
  local spacing = cfg.spacing or 0
  local width = cfg.width or 280

  local anchor = self:GetEssentialFrame() or UIParent
  if not anchor then
    return
  end

  local prev = anchor
  local function anchorBar(frame, enabled, height)
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetWidth(width)
    if enabled and height and height > 0 then
      frame:SetHeight(height)
      frame:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
      frame:SetPoint("BOTTOMRIGHT", prev, "TOPRIGHT", 0, spacing)
      frame:Show()
      prev = frame
    else
      frame:Hide()
    end
  end

  anchorBar(bars.cast, self:IsBarEnabled("cast"), cfg.cast and cfg.cast.height)
  anchorBar(bars.health, self:IsBarEnabled("health"), cfg.health and cfg.health.height)
  anchorBar(bars.resource, self:IsBarEnabled("resource"), cfg.resource and cfg.resource.height)
  anchorBar(bars.class, self:IsBarEnabled("class"), cfg.class and cfg.class.height)

  if buffs and buffs.anchor then
    buffs.anchor:ClearAllPoints()
    buffs.anchor:SetWidth(width)
    if buffs.previewing or buffs:IsEnabled() then
      buffs.anchor:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
      buffs.anchor:SetPoint("BOTTOMRIGHT", prev, "TOPRIGHT", 0, spacing)
      prev = buffs.anchor
    end
  end

  if self.ApplyBarVisuals then
    self:ApplyBarVisuals()
  end
  if buffs and buffs.ApplyLayout then
    buffs:ApplyLayout()
  end
end

function ClassHUD:ShowEditModePreview()
  if self._inEditModePreview then
    return
  end
  self:EnsureModules()
  self._inEditModePreview = true

  if self.buffBar and self.buffBar.ShowPreview then
    self.buffBar:ShowPreview()
  end
  self:AnchorFrames()
  if self.ShowBarsPreview then
    self:ShowBarsPreview()
  end
end

function ClassHUD:HideEditModePreview()
  if not self._inEditModePreview then
    return
  end
  self._inEditModePreview = false

  if self.HideBarsPreview then
    self:HideBarsPreview()
  end
  if self.buffBar and self.buffBar.HidePreview then
    self.buffBar:HidePreview()
  end

  self:AnchorFrames()
  self:RefreshBars()
  self:UpdateBuffBar()
end

function ClassHUD:SetupEditModeIntegration()
  if self._editModeSetup then
    return
  end
  if not EditModeManagerFrame or not hooksecurefunc then
    return
  end

  self._editModeSetup = true
  local addon = self
  hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
    addon:ShowEditModePreview()
  end)
  hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
    addon:HideEditModePreview()
  end)

  if EditModeManagerFrame:IsEditModeActive() then
    self:ShowEditModePreview()
  end
end

function ClassHUD:UpdateFromCooldownViewer()
  self:EnsureModules()
  if not self.buffBar then
    return
  end

  local hidden = self:GetBuffConfig().hiddenSpellIDs or {}
  local entries = {}
  local order = {}

  local function includeSpell(spellID, source, cooldownID, info)
    if not spellID or hidden[spellID] then
      return
    end
    local key = tostring(spellID)
    if not entries[key] then
      entries[key] = {
        key = key,
        source = source,
        spellID = spellID,
        cooldownID = cooldownID,
        cooldownInfo = info,
      }
      table.insert(order, key)
    end
  end

  local function includeEntry(key, data)
    if not entries[key] then
      data.key = key
      entries[key] = data
      table.insert(order, key)
    end
  end

  if Enum and Enum.CooldownViewerCategory then
    local trackedBuffCat = self:GetCooldownCategory("TrackedBuff")
    if trackedBuffCat then
      local ids = safeCategorySet(trackedBuffCat)
      if type(ids) == "table" then
        for _, cooldownID in ipairs(ids) do
          local info = safeCooldownInfo(cooldownID)
          includeSpell(extractSpellID(info), "trackedBuff", cooldownID, info)
        end
      end
    end

    local trackedBarCat = self:GetCooldownCategory("TrackedBar")
    if trackedBarCat then
      local ids = safeCategorySet(trackedBarCat)
      if type(ids) == "table" then
        for _, cooldownID in ipairs(ids) do
          local info = safeCooldownInfo(cooldownID)
          includeSpell(extractSpellID(info), "trackedBar", cooldownID, info)
        end
      end
    end
  end

  local custom = self:GetBuffConfig().customSpellIDs
  if type(custom) == "table" then
    for spellID, enabled in pairs(custom) do
      if enabled and type(spellID) == "number" then
        includeSpell(spellID, "custom", nil, nil)
      end
    end
  end

  local maxTotems = MAX_TOTEMS or 4
  for slot = 1, maxTotems do
    includeEntry("totem" .. slot, {
      source = "totem",
      totemSlot = slot,
    })
  end

  self.buffBar:SetEntries(entries, order, hidden)
  self:UpdateBuffBar()
end

function ClassHUD:RefreshBars()
  if not self.bars then return end
  if self.UpdateHealthBar then self:UpdateHealthBar() end
  if self.UpdateResourceBar then self:UpdateResourceBar() end
  if self.UpdateClassBar then self:UpdateClassBar() end
end

function ClassHUD:UpdateBuffBar()
  if self.buffBar and self.buffBar.UpdateBuffs then
    self.buffBar:UpdateBuffs()
  end
end

-- -----------------------------------------------------------------------------
-- Event handling
-- -----------------------------------------------------------------------------
local events = CreateFrame("Frame")

local registered = {
  "PLAYER_LOGIN",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_SPECIALIZATION_CHANGED",
  "UNIT_POWER_FREQUENT",
  "UNIT_DISPLAYPOWER",
  "UNIT_POWER_POINT_CHARGE",
  "RUNE_POWER_UPDATE",
  "RUNE_TYPE_UPDATE",
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_EMPOWER_START",
  "UNIT_SPELLCAST_EMPOWER_STOP",
  "UNIT_SPELLCAST_EMPOWER_INTERRUPTED",
  "UNIT_HEALTH",
  "UNIT_MAXHEALTH",
  "UNIT_AURA",
  "SPELL_UPDATE_COOLDOWN",
  "SPELL_UPDATE_CHARGES",
  "PLAYER_TOTEM_UPDATE",
}

for _, event in ipairs(registered) do
  events:RegisterEvent(event)
end

local function handleCast(event, unit, ...)
  if unit ~= "player" then return end
  if not ClassHUD[event] then return end
  ClassHUD[event](ClassHUD, unit, ...)
end

events:SetScript("OnEvent", function(_, event, arg1, ...)
  if event == "PLAYER_LOGIN" then
    ClassHUD:EnableCooldownViewer()
    ClassHUD:EnsureModules()
    ClassHUD:AnchorFrames()
    ClassHUD:UpdateFromCooldownViewer()
    ClassHUD:RefreshBars()
    ClassHUD:UpdateBuffBar()
    ClassHUD:SetupEditModeIntegration()
    if ClassHUD.InitializeBuffOptions then
      ClassHUD:InitializeBuffOptions()
    end
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    ClassHUD:SetupEditModeIntegration()
    ClassHUD:AnchorFrames()
    ClassHUD:UpdateFromCooldownViewer()
    ClassHUD:RefreshBars()
    ClassHUD:UpdateBuffBar()
    return
  end

  if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
    ClassHUD:UpdateFromCooldownViewer()
    ClassHUD:RefreshBars()
    ClassHUD:UpdateBuffBar()
    return
  end

  if event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
    if arg1 == "player" and ClassHUD.UpdateResourceBar then
      ClassHUD:UpdateResourceBar()
    end
    if arg1 == "player" and ClassHUD.UpdateClassBar then
      ClassHUD:UpdateClassBar()
    end
    return
  end

  if event == "UNIT_POWER_POINT_CHARGE" and arg1 == "player" then
    if ClassHUD.UpdateClassBar then
      ClassHUD:UpdateClassBar()
    end
    return
  end

  if (event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE") and ClassHUD.UpdateClassBar then
    ClassHUD:UpdateClassBar()
    return
  end

  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    if arg1 == "player" and ClassHUD.UpdateHealthBar then
      ClassHUD:UpdateHealthBar()
    end
    if arg1 == "player" and ClassHUD.UpdateResourceBar then
      ClassHUD:UpdateResourceBar()
    end
    return
  end

  if event == "UNIT_AURA" then
    if arg1 == "player" or arg1 == "pet" then
      ClassHUD:UpdateBuffBar()
    end
    return
  end

  if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
    ClassHUD:UpdateBuffBar()
    return
  end

  if event == "PLAYER_TOTEM_UPDATE" then
    ClassHUD:UpdateBuffBar()
    return
  end

  if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" or
     event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or
     event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or
     event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_STOP" or
     event == "UNIT_SPELLCAST_EMPOWER_INTERRUPTED" then
    handleCast(event, arg1, ...)
    return
  end
end)

-- Convenience hook for modules to trigger a full refresh when options change
function ClassHUD:NotifyConfigChanged()
  self:AnchorFrames()
  self:RefreshBars()
  self:UpdateBuffBar()
end

