local ADDON_NAME = ...
local AceAddon   = LibStub("AceAddon-3.0")
local AceEvent   = LibStub("AceEvent-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceDB      = LibStub("AceDB-3.0")
local LSM        = LibStub("LibSharedMedia-3.0")

local ClassHUD   = AceAddon:NewAddon("ClassHUD", "AceEvent-3.0", "AceConsole-3.0")
ClassHUD:SetDefaultModuleState(true)
ClassHUD.ADDON_NAME = ADDON_NAME

-- Global UI state for this addon (must exist before any function references it)
ClassHUD.UI = {
  anchor        = nil,
  cast          = nil,
  hp            = nil,
  resource      = nil,
  power         = nil,
  powerSegments = {},
  runeBars      = {},
  icons         = nil,
  iconFrames    = {},
  attachments   = {},
}

-- Blizzard power colors
ClassHUD.TOKEN_BY_ID = {
  [Enum.PowerType.Mana]          = "MANA",
  [Enum.PowerType.Rage]          = "RAGE",
  [Enum.PowerType.Focus]         = "FOCUS",
  [Enum.PowerType.Energy]        = "ENERGY",
  [Enum.PowerType.ComboPoints]   = "COMBO_POINTS",
  [Enum.PowerType.Runes]         = "RUNES",
  [Enum.PowerType.RunicPower]    = "RUNIC_POWER",
  [Enum.PowerType.SoulShards]    = "SOUL_SHARDS",
  [Enum.PowerType.LunarPower]    = "LUNAR_POWER",
  [Enum.PowerType.HolyPower]     = "HOLY_POWER",
  [Enum.PowerType.Maelstrom]     = "MAELSTROM",
  [Enum.PowerType.Chi]           = "CHI",
  [Enum.PowerType.Insanity]      = "INSANITY",
  [Enum.PowerType.ArcaneCharges] = "ARCANE_CHARGES",
  [Enum.PowerType.Fury]          = "FURY",
  [Enum.PowerType.Pain]          = "PAIN",
  [Enum.PowerType.Essence]       = "ESSENCE",
}

local defaults = {
  profile = {
    locked          = false,
    width           = 250,
    spacing         = 2,
    powerSpacing    = 2,
    position        = { x = 0, y = -50 },

    textures        = {
      bar = "Blizzard",
      font = "Friz Quadrata TT",
    },

    show            = {
      cast     = true,
      hp       = true,
      resource = true,
      power    = true,
    },

    height          = {
      cast     = 18,
      hp       = 14,
      resource = 14,
      power    = 14,
    },

    icons           = {
      perRow = 8,
      spacing = 4,
    },

    sideBars        = {
      size = 36,
      spacing = 4,
      offset = 6,
    },
    topBar          = {
      perRow   = 8,
      spacingX = 4,
      spacingY = 4,
      yOffset  = 0,
    },
    topBarSpells    = {},
    leftBarSpells   = {},
    rightBarSpells  = {},
    bottomBarSpells = {},
    bottomBar       = {
      perRow   = 8,
      spacingX = 4,
      spacingY = 4,
      yOffset  = 0,
    },

    colors = {
      hp = { r = 0.10, g = 0.80, b = 0.10 },
      resourceClass = true,
      resource = { r = 0.00, g = 0.55, b = 1.00 },
      power = { r = 1.00, g = 0.85, b = 0.10 },
    },
  }
}

ClassHUD.defaults = defaults

function ClassHUD:GetClassColor()
  local _, class = UnitClass("player")
  local c = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
  return c.r, c.g, c.b
end

function ClassHUD:PowerColorBy(id, token)
  token = token or self.TOKEN_BY_ID[id]
  local c = (token and PowerBarColor[token]) or PowerBarColor[id]
  if c then return c.r, c.g, c.b end
  return 0.2, 0.6, 1.0
end

function ClassHUD:FetchStatusbar()
  return LSM:Fetch("statusbar", self.db.profile.textures.bar)
      or "Interface\\TargetingFrame\\UI-StatusBar"
end

function ClassHUD:FetchFont(size, flags)
  local path = LSM:Fetch("font", self.db.profile.textures.font) or STANDARD_TEXT_FONT
  return path, size, flags or "OUTLINE"
end

function ClassHUD:FullUpdate()
  self:LayoutBars()
  self:UpdateHP()
  self:UpdatePrimaryResource()
  self:UpdateSpecialPower()
end

function ClassHUD:OnInitialize()
  self.db = AceDB:New("ClassHUDDB", defaults, true)
end

-- ===== Options bootstrap (registers with AceConfigRegistry directly) =====
function ClassHUD:RegisterOptions()
  local ACR = LibStub("AceConfigRegistry-3.0", true)
  local ACD = LibStub("AceConfigDialog-3.0", true)
  if not (ACR and ACD) then
    print("|cff00ff88ClassHUD|r: AceConfig libs missing.")
    return false
  end

  -- Try to use the real builder from ClassHUD_Options.lua
  local builder = _G.ClassHUD_BuildOptions
  local opts

  if type(builder) == "function" then
    local ok, res = pcall(builder, self)
    if not ok then
      print("|cff00ff88ClassHUD|r: BuildOptions error:", res)
    else
      opts = res
    end
  end

  -- If still missing, warn ONCE and install a tiny fallback so /chud works
  if not opts then
    if not self._opts_missing_warned then
      self._opts_missing_warned = true
      print("|cff00ff88ClassHUD|r: ClassHUD_BuildOptions is missing. Using fallback options panel.")
      print("|cff00ff88ClassHUD|r: Make sure ClassHUD_Options.lua is in the TOC, loads, and defines *global* function ClassHUD_BuildOptions(addon).")
    end
    opts = {
      type = "group",
      name = "ClassHUD (fallback)",
      args = {
        note = {
          type = "description",
          order = 1,
          name = "Options file not loaded.\nCheck TOC path/name and that ClassHUD_Options.lua defines:\n\nfunction ClassHUD_BuildOptions(addon) ... return opts end\n",
        },
      },
    }
  end

  self._opts = opts
  ACR:RegisterOptionsTable("ClassHUD", opts)
  ACD:AddToBlizOptions("ClassHUD", "ClassHUD")

  self._opts_registered = true
  return true
end

-- helper for /chud
function ClassHUD:OpenOptions()
  local ACR = LibStub("AceConfigRegistry-3.0", true)
  local ACD = LibStub("AceConfigDialog-3.0", true)
  if not (ACR and ACD) then
    print("|cff00ff88ClassHUD|r: AceConfig libs missing.")
    return
  end
  if not ACR:GetOptionsTable("ClassHUD") then
    if not self:RegisterOptions() then return end
  end
  ACR:NotifyChange("ClassHUD")
  ACD:Open("ClassHUD")
end

function ClassHUD:OnEnable()
  self:CreateAnchor()
  self:CreateCastBar()
  self:CreateHPBar()
  self:CreateResourceBar()
  self:CreatePowerContainer()
  self:LayoutBars()
  self:ApplyBarSkins()
end

local eventFrame = CreateFrame("Frame")

for _, ev in pairs({
  -- World/spec
  "PLAYER_ENTERING_WORLD",
  "PLAYER_SPECIALIZATION_CHANGED",

  -- Health
  "UNIT_HEALTH", "UNIT_MAXHEALTH",

  -- Resource
  "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER", "UPDATE_SHAPESHIFT_FORM", "UNIT_POWER_POINT_CHARGE",

  -- DK runes
  "RUNE_POWER_UPDATE", "RUNE_TYPE_UPDATE",

  -- Castbar
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",

  -- Spells
  "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "UNIT_SPELLCAST_SUCCEEDED",
}) do
  eventFrame:RegisterEvent(ev)
end


eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    ClassHUD:FullUpdate()
    ClassHUD:ApplyAnchorPosition()
    ClassHUD:BuildFramesForSpec()
    return
  end

  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
    ClassHUD:UpdatePrimaryResource()
    ClassHUD:UpdateSpecialPower()
    ClassHUD:BuildFramesForSpec()
    return
  end

  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    if unit == "player" then ClassHUD:UpdateHP() end
    return
  end

  if event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
    if unit == "player" then
      ClassHUD:UpdatePrimaryResource()
      ClassHUD:UpdateSpecialPower()
    end
    return
  end

  if event == "UPDATE_SHAPESHIFT_FORM" then
    ClassHUD:UpdatePrimaryResource()
    ClassHUD:UpdateSpecialPower()
    return
  end

  if event == "UNIT_POWER_POINT_CHARGE" and unit == "player" then
    ClassHUD:UpdateSpecialPower()
    return
  end

  if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
    ClassHUD:UpdateSpecialPower()
    return
  end

  if event == "UNIT_SPELLCAST_START" then
    ClassHUD:UNIT_SPELLCAST_START(event, unit, ...)
    return
  end
  if event == "UNIT_SPELLCAST_STOP" then
    ClassHUD:UNIT_SPELLCAST_STOP(event, unit, ...)
    return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_START" then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_START(event, unit, ...)
    return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(event, unit, ...)
    return
  end
  if event == "UNIT_SPELLCAST_INTERRUPTED" then
    ClassHUD:UNIT_SPELLCAST_INTERRUPTED(event, unit, ...)
    return
  end
  if event == "UNIT_SPELLCAST_FAILED" then
    ClassHUD:UNIT_SPELLCAST_FAILED(event, unit, ...)
    return
  end

  if event == "UNIT_AURA" and unit == "player" then
    ClassHUD:UpdateAllFrames()
    return
  end
  if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "UNIT_SPELLCAST_SUCCEEDED" then
    ClassHUD:UpdateAllFrames()
    return
  end
end)

SLASH_CLASSHUD1 = "/chud"
SlashCmdList["CLASSHUD"] = function(msg)
  if msg == "debug" then
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    local ACD = LibStub("AceConfigDialog-3.0", true)
    print("|cff00ff88ClassHUD Debug|r",
      "ACR=", ACR and "ok" or "nil",
      "ACD=", ACD and "ok" or "nil",
      "registered=", (ACR and ACR:GetOptionsTable("ClassHUD")) and "yes" or "no")
    return
  end
  ClassHUD:OpenOptions()
end
