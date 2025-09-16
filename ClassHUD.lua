-- ClassHUD.lua
local ADDON_NAME = ...
local AceAddon   = LibStub("AceAddon-3.0")
local AceEvent   = LibStub("AceEvent-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceDB      = LibStub("AceDB-3.0")
local LSM        = LibStub("LibSharedMedia-3.0")

---@class ClassHUD : AceAddon, AceEvent, AceConsole
---@field BuildFramesForSpec fun(self:ClassHUD)  -- defined in Spells.lua
---@field UpdateAllFrames fun(self:ClassHUD)     -- defined in Spells.lua
---@field Layout fun(self:ClassHUD)              -- defined in Bars.lua
---@field ApplyBarSkins fun(self:ClassHUD)       -- defined in Bars.lua
---@field UpdateHP fun(self:ClassHUD)            -- defined in Bars.lua
---@field UpdatePrimaryResource fun(self:ClassHUD) -- defined in Bars.lua
---@field UpdateSpecialPower fun(self:ClassHUD)  -- defined in Classbar.lua
---@field UpdateSegmentsAdvanced fun(self:ClassHUD, ptype:number, max:number, partial:boolean)|nil
---@field UpdateEssenceSegments fun(self:ClassHUD, ptype:number)|nil
---@field UpdateRunes fun(self:ClassHUD)|nil

local ClassHUD   = AceAddon:NewAddon("ClassHUD", "AceEvent-3.0", "AceConsole-3.0")
ClassHUD:SetDefaultModuleState(true)
_G.ClassHUD = ClassHUD -- explicit global bridge so split files can always find it

-- Make shared libs available to submodules
ClassHUD.LSM = LSM

---@class ClassHUDUI
---@field anchor Frame|nil
---@field cast StatusBar|nil
---@field hp StatusBar|nil
---@field resource StatusBar|nil
---@field power Frame|nil
---@field powerSegments StatusBar[]
---@field runeBars StatusBar[]
---@field icons Frame|nil
---@field iconFrames Frame[]
---@field attachments table<string, Frame>
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

-- Class color (for HP)
function ClassHUD:GetClassColor()
  local _, class = UnitClass("player")
  local c = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
  return c.r, c.g, c.b
end

-- Blizzard power colors
local TOKEN_BY_ID = {
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

function ClassHUD:PowerColorBy(id, token)
  token = token or TOKEN_BY_ID[id]
  local c = (token and PowerBarColor[token]) or PowerBarColor[id]
  if c then return c.r, c.g, c.b end
  return 0.2, 0.6, 1.0 -- sensible fallback
end

-- ---------------------------------------------------------------------------
-- Defaults & DB
-- ---------------------------------------------------------------------------
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
      resource = true, -- primary (mana/rage/energy/etc., form/spec aware)
      power    = true, -- special (CP/Chi/HolyPower/Shards/ArcaneCharges/Runes)
    },

    height          = {
      cast     = 18,
      hp       = 14,
      resource = 14,
      power    = 14, -- per-segment height for runes/segments
    },

    icons           = {
      perRow = 8,  -- how many icons per row
      spacing = 4, -- spacing in pixels
    },

    sideBars        = {
      size = 36,
      spacing = 4,
      offset = 6,
    },
    topBar          = {
      perRow   = 8,
      spacingX = 4, -- horizontal spacing between icons
      spacingY = 4, -- vertical spacing between rows
      yOffset  = 0,
    },
    topBarSpells    = {},
    leftBarSpells   = {},
    rightBarSpells  = {},
    bottomBarSpells = {},
    bottomBar       = {
      perRow   = 8,
      spacingX = 4, -- horizontal spacing
      spacingY = 4, -- vertical spacing
      yOffset  = 0,
    },

    colors          = {
      hp = { r = 0.10, g = 0.80, b = 0.10 },
      resourceClass = true,                     -- use class color for primary resource
      resource = { r = 0.00, g = 0.55, b = 1.00 },
      power = { r = 1.00, g = 0.85, b = 0.10 }, -- fallback for special segments
    },
  }
}

function ClassHUD:FetchStatusbar()
  return self.LSM:Fetch("statusbar", self.db.profile.textures.bar)
      or "Interface\\TargetingFrame\\UI-StatusBar"
end

function ClassHUD:FetchFont(size, flags)
  local path = self.LSM:Fetch("font", self.db.profile.textures.font) or STANDARD_TEXT_FONT
  return path, size, flags or "OUTLINE"
end

-- ---------------------------------------------------------------------------
-- Public helpers used by modules
-- ---------------------------------------------------------------------------
function ClassHUD:ApplyAnchorPosition()
  local UI = self.UI
  if not UI.anchor then return end
  local pos = (self.db and self.db.profile and self.db.profile.position) or { x = 0, y = -350 }
  UI.anchor:ClearAllPoints()
  UI.anchor:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end

-- Exposed so Classbar can create uniform bars
function ClassHUD:CreateStatusBar(parent, height)
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
  bar:SetHeight(height or 16)
  bar:SetWidth(250)
  return bar
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
function ClassHUD:OnInitialize()
  -- IMPORTANT: Ensure your TOC has "## SavedVariables: ClassHUDDB"
  self.db = AceDB:New("ClassHUDDB", defaults, true)
end

-- Called by PLAYER_ENTERING_WORLD or when user changes options
function ClassHUD:FullUpdate()
  if self.Layout then self:Layout() end
  if self.UpdateHP then self:UpdateHP() end
  if self.UpdatePrimaryResource then self:UpdatePrimaryResource() end
  if self.UpdateSpecialPower then self:UpdateSpecialPower() end
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
      print(
        "|cff00ff88ClassHUD|r: Make sure ClassHUD_Options.lua is in the TOC, loads, and defines *global* function ClassHUD_BuildOptions(addon).")
    end
    opts = {
      type = "group",
      name = "ClassHUD (fallback)",
      args = {
        note = {
          type = "description",
          order = 1,
          name =
          "Options file not loaded.\nCheck TOC path/name and that ClassHUD_Options.lua defines:\n\nfunction ClassHUD_BuildOptions(addon) ... return opts end\n"
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

-- ========= Bars/Spells bootstrap on enable =========
function ClassHUD:OnEnable()
  local UI = self.UI
  -- Create base frames
  if not UI.anchor and self.CreateAnchor then self:CreateAnchor() end
  if not UI.cast and self.CreateCastBar then self:CreateCastBar() end
  if not UI.hp and self.CreateHPBar then self:CreateHPBar() end
  if not UI.resource and self.CreateResourceBar then self:CreateResourceBar() end
  if not UI.power and self.CreatePowerContainer then self:CreatePowerContainer() end

  if self.Layout then self:Layout() end
  if self.ApplyBarSkins then self:ApplyBarSkins() end

  -- Rebuild spells after DB exists & layout is ready
  if self.BuildFramesForSpec then
    self:BuildFramesForSpec()
  end
end

-- ========= Event wiring =========
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
  -- Full refresh after world load
  if event == "PLAYER_ENTERING_WORLD" then
    ClassHUD:FullUpdate()
    ClassHUD:ApplyAnchorPosition()
    if ClassHUD.BuildFramesForSpec then ClassHUD:BuildFramesForSpec() end
    return
  end

  -- Spec change
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
    if ClassHUD.UpdatePrimaryResource then ClassHUD:UpdatePrimaryResource() end
    if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    if ClassHUD.BuildFramesForSpec then ClassHUD:BuildFramesForSpec() end
    -- 👇 legg til dette
    if ClassHUD._opts then
      local builder = _G.ClassHUD_BuildOptions
      if builder then
        local ok, opts = pcall(builder, ClassHUD)
        if ok and opts then
          ClassHUD._opts = opts
          LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
        end
      end
    end
    return
  end

  -- Health
  if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit == "player" then
    if ClassHUD.UpdateHP then ClassHUD:UpdateHP() end
    return
  end

  -- Resources
  if event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
    if unit == "player" then
      if ClassHUD.UpdatePrimaryResource then ClassHUD:UpdatePrimaryResource() end
      if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    end
    return
  end

  if event == "UPDATE_SHAPESHIFT_FORM" then
    if ClassHUD.UpdatePrimaryResource then ClassHUD:UpdatePrimaryResource() end
    if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    return
  end

  if event == "UNIT_POWER_POINT_CHARGE" and unit == "player" then
    if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    return
  end

  if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
    if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    return
  end

  -- Castbar events are handled as methods on ClassHUD (in Bars module)
  if event == "UNIT_SPELLCAST_START" and ClassHUD.UNIT_SPELLCAST_START then
    ClassHUD:UNIT_SPELLCAST_START(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_STOP" and ClassHUD.UNIT_SPELLCAST_STOP then
    ClassHUD:UNIT_SPELLCAST_STOP(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_START" and ClassHUD.UNIT_SPELLCAST_CHANNEL_START then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_START(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_STOP" and ClassHUD.UNIT_SPELLCAST_CHANNEL_STOP then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_INTERRUPTED" and ClassHUD.UNIT_SPELLCAST_INTERRUPTED then
    ClassHUD:UNIT_SPELLCAST_INTERRUPTED(unit, ...); return
  end
  if event == "UNIT_SPELLCAST_FAILED" and ClassHUD.UNIT_SPELLCAST_FAILED then
    ClassHUD:UNIT_SPELLCAST_FAILED(unit, ...); return
  end

  -- Spells (auras + cooldowns)
  if (event == "UNIT_AURA" and unit == "player") or
      event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "UNIT_SPELLCAST_SUCCEEDED" then
    if ClassHUD.UpdateAllFrames then ClassHUD:UpdateAllFrames() end
    -- Also show instant-cast fake bar if bars module hooked SUCCEEDED
    if event == "UNIT_SPELLCAST_SUCCEEDED" and ClassHUD.UNIT_SPELLCAST_SUCCEEDED then
      ClassHUD:UNIT_SPELLCAST_SUCCEEDED(unit, ...)
    end
    return
  end
end)

-- Replace your slash handler with this
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
