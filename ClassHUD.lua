local ADDON_NAME = ...
local AceAddon   = LibStub("AceAddon-3.0")
local AceEvent   = LibStub("AceEvent-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceDB      = LibStub("AceDB-3.0")
local LSM        = LibStub("LibSharedMedia-3.0")

local ClassHUD   = AceAddon:NewAddon("ClassHUD", "AceEvent-3.0", "AceConsole-3.0")
ClassHUD:SetDefaultModuleState(true)

-- Global UI state for this addon (must exist before any function references it)
-- Must exist before any function references it
-- Global UI state
local UI = {
  anchor        = nil,
  cast          = nil,
  hp            = nil,
  resource      = nil,
  power         = nil,
  powerSegments = {},
  runeBars      = {},
  icons         = nil,
  iconFrames    = {},
  attachments   = {}, -- << NEW
}


-- Class color (for HP)
local function GetClassColor()
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

local function PowerColorBy(id, token)
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


    colors = {
      hp = { r = 0.10, g = 0.80, b = 0.10 },
      resourceClass = true,                     -- use class color for primary resource
      resource = { r = 0.00, g = 0.55, b = 1.00 },
      power = { r = 1.00, g = 0.85, b = 0.10 }, -- fallback for special segments
    },
  }
}




-- Handy
local function FetchStatusbar()
  return LSM:Fetch("statusbar", ClassHUD.db.profile.textures.bar)
      or "Interface\\TargetingFrame\\UI-StatusBar"
end

local function FetchFont(size, flags)
  local path = LSM:Fetch("font", ClassHUD.db.profile.textures.font) or STANDARD_TEXT_FONT
  return path, size, flags or "OUTLINE"
end

-- ---------------------------------------------------------------------------
-- Primary/Secondary power picking (form/spec aware)
-- ---------------------------------------------------------------------------

-- Special segmented power (or runes). Returns a table descriptor or nil.
local function SpecialPowerInfo()
  local _, class = UnitClass("player")
  local spec = GetSpecialization()
  local specID = spec and GetSpecializationInfo(spec) or 0
  local ptype = select(1, UnitPowerType("player"))

  -- DRUID: Cat form (Energy) => show Combo Points for any spec
  if class == "DRUID" and ptype == Enum.PowerType.Energy then
    return {
      kind = "SEGMENTS",
      power = Enum.PowerType.ComboPoints,
      max = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
    }
  end

  -- ROGUE: Combo Points
  if class == "ROGUE" then
    return {
      kind = "SEGMENTS",
      power = Enum.PowerType.ComboPoints,
      max = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
    }
  end

  -- MONK (Windwalker): Chi
  if class == "MONK" and specID == 269 then
    return {
      kind = "SEGMENTS",
      power = Enum.PowerType.Chi,
      max = UnitPowerMax("player", Enum.PowerType.Chi) or 5
    }
  end

  -- PALADIN: Holy Power
  if class == "PALADIN" then
    return {
      kind = "SEGMENTS",
      power = Enum.PowerType.HolyPower,
      max = UnitPowerMax("player", Enum.PowerType.HolyPower) or 5
    }
  end

  -- WARLOCK: Soul Shards
  if class == "WARLOCK" then
    return {
      kind = "SEGMENTS",
      power = Enum.PowerType.SoulShards,
      max = UnitPowerMax("player", Enum.PowerType.SoulShards) or 5
    }
  end

  -- MAGE (Arcane): Arcane Charges
  if class == "MAGE" and specID == 62 then
    return {
      kind = "SEGMENTS",
      power = Enum.PowerType.ArcaneCharges,
      max = UnitPowerMax("player", Enum.PowerType.ArcaneCharges) or 4
    }
  end

  -- DEATH KNIGHT: Runes
  if class == "DEATHKNIGHT" then
    return { kind = "RUNES" }
  end

  return nil
end


-- ---------------------------------------------------------------------------
-- Frames
-- ---------------------------------------------------------------------------

function ClassHUD:ApplyAnchorPosition()
  if not UI.anchor then return end
  local pos = self.db.profile.position or { x = 0, y = -350 }
  UI.anchor:ClearAllPoints()
  UI.anchor:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end

local function CreateAnchor()
  local f = CreateFrame("Frame", "ClassHUDAnchor", UIParent, "BackdropTemplate")
  f:SetSize(250, 1)
  f:SetMovable(false) -- no drag; we control via offsets
  UI.anchor = f
end

local function CreateStatusBar(parent, height)
  local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
  bar:SetStatusBarTexture(FetchStatusbar())
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(true)
  bar.bg:SetColorTexture(0, 0, 0, 0.55)

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont(FetchFont(12))

  bar:SetHeight(height)
  bar:SetWidth(250)
  return bar
end

local function CreateCastBar()
  local h = ClassHUD.db.profile.height.cast
  local b = CreateStatusBar(UI.anchor, h)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(h, h)
  b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  b.spell = b:CreateFontString(nil, "OVERLAY")
  b.spell:SetFont(FetchFont(12))
  b.spell:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
  b.spell:SetJustifyH("LEFT")

  b.time = b:CreateFontString(nil, "OVERLAY")
  b.time:SetFont(FetchFont(12))
  b.time:SetPoint("RIGHT", b, "RIGHT", -3, 0)
  b.time:SetJustifyH("RIGHT")

  b:SetStatusBarColor(1, .7, 0)
  b:Hide()
  UI.cast = b
end

local function CreateHPBar()
  local b = CreateStatusBar(UI.anchor, ClassHUD.db.profile.height.hp)
  local r, g, bCol = GetClassColor()
  b:SetStatusBarColor(r, g, bCol)
  UI.hp = b
end


local function CreateResourceBar()
  local b = CreateStatusBar(UI.anchor, ClassHUD.db.profile.height.resource)
  if ClassHUD.db.profile.colors.resourceClass then
    b:SetStatusBarColor(GetClassColor())
  else
    local c = ClassHUD.db.profile.colors.resource
    b:SetStatusBarColor(c.r, c.g, c.b)
  end
  UI.resource = b
end

local function CreatePowerContainer()
  local f = CreateFrame("Frame", nil, UI.anchor, "BackdropTemplate")
  f:SetSize(250, 16)
  UI.power = f
end

-- ---------------------------------------------------------------------------
-- Layout (top→bottom): cast → hp → resource → power
-- ---------------------------------------------------------------------------
local function ApplyBarSkins()
  local tex = FetchStatusbar()
  for _, sb in pairs({ UI.cast, UI.hp, UI.resource }) do
    if sb and sb.SetStatusBarTexture then
      sb:SetStatusBarTexture(tex)
    end
  end
  if UI.cast then
    UI.cast.spell:SetFont(FetchFont(12))
    UI.cast.time:SetFont(FetchFont(12))
  end
  if UI.hp then UI.hp.text:SetFont(FetchFont(12)) end
  if UI.resource then UI.resource.text:SetFont(FetchFont(12)) end
end

local function Layout()
  local w   = ClassHUD.db.profile.width
  local gap = ClassHUD.db.profile.spacing

  UI.anchor:SetWidth(w)

  local y = 0

  -- Cast (top)
  if ClassHUD.db.profile.show.cast then
    UI.cast:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.cast:SetWidth(w)
    UI.cast:SetHeight(ClassHUD.db.profile.height.cast)
    y = y + UI.cast:GetHeight() + gap
  else
    UI.cast:ClearAllPoints(); UI.cast:Hide()
  end

  -- HP
  if ClassHUD.db.profile.show.hp then
    UI.hp:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.hp:SetWidth(w)
    UI.hp:SetHeight(ClassHUD.db.profile.height.hp)
    y = y + UI.hp:GetHeight() + gap
  else
    UI.hp:ClearAllPoints(); UI.hp:Hide()
  end

  -- Primary resource
  if ClassHUD.db.profile.show.resource then
    UI.resource:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.resource:SetWidth(w)
    UI.resource:SetHeight(ClassHUD.db.profile.height.resource)
    y = y + UI.resource:GetHeight() + gap
  else
    UI.resource:ClearAllPoints(); UI.resource:Hide()
  end

  -- Special power container
  if ClassHUD.db.profile.show.power then
    UI.power:SetPoint("TOP", UI.anchor, "TOP", 0, -y)
    UI.power:SetWidth(w)
    UI.power:SetHeight(ClassHUD.db.profile.height.power)
  else
    UI.power:ClearAllPoints(); UI.power:Hide()
  end

  -- Update attachment points
  local function ensure(name)
    if not UI.attachments[name] then
      UI.attachments[name] = CreateFrame("Frame", "ClassHUDAttach" .. name, UI.anchor)
      UI.attachments[name]:SetSize(1, 1)
    end
    return UI.attachments[name]
  end

  -- Top (above castbar, shifted by castbar height)
  -- Top (a 1px-tall strip directly above the cast bar, stretched to its width)
  local top = ensure("TOP")
  top:ClearAllPoints()
  top:SetPoint("BOTTOMLEFT", UI.cast, "TOPLEFT", 0, 0)
  top:SetPoint("BOTTOMRIGHT", UI.cast, "TOPRIGHT", 0, 0)
  top:SetHeight(1)


  -- Bottom (a 1px-tall strip directly below the power bar, stretched to its width)
  local bottom = ensure("BOTTOM")
  bottom:ClearAllPoints()
  bottom:SetPoint("TOPLEFT", UI.power, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("TOPRIGHT", UI.power, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(1)


  -- Left
  local left = ensure("LEFT")
  left:ClearAllPoints()
  left:SetPoint("RIGHT", UI.anchor, "LEFT", -4, 0)

  -- Right
  local right = ensure("RIGHT")
  right:ClearAllPoints()
  right:SetPoint("LEFT", UI.anchor, "RIGHT", 4, 0)


  ApplyBarSkins()
end

-- ---------------------------------------------------------------------------
-- Updates
-- ---------------------------------------------------------------------------
local castTicker

local function StopCast()
  -- Don’t stop if player is still casting or channeling something
  local casting = UnitCastingInfo("player")
  local channeling = UnitChannelInfo("player")
  if casting or channeling then
    return
  end

  if UI.cast then
    UI.cast:SetScript("OnUpdate", nil)
    UI.cast:Hide()
    UI.cast:SetValue(0)
    UI.cast.time:SetText("")
    UI.cast.spell:SetText("")
    UI.cast.icon:SetTexture(nil)
  end
end


local function StartCast(name, icon, startMS, endMS)
  if not ClassHUD.db.profile.show.cast then return end
  local total = (endMS - startMS) / 1000
  local start = startMS / 1000

  UI.cast:Show()
  UI.cast.spell:SetText(name or "")
  UI.cast.icon:SetTexture(icon or 136243) -- generic
  UI.cast:SetStatusBarColor(1, .7, 0)

  UI.cast:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local elapsed = now - start
    self:SetMinMaxValues(0, total)
    self:SetValue(elapsed)
    self.time:SetFormattedText("%.1f / %.1f", math.max(0, elapsed), total)

    if elapsed >= total then
      self:SetScript("OnUpdate", nil)
      self:Hide()
    end
  end)
end


function ClassHUD:UNIT_SPELLCAST_START(_, unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitCastingInfo("player")
  if name then
    StartCast(name, icon, startMS, endMS)
  end
end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_START(_, unit)
  if unit ~= "player" then return end
  local name, _, icon, startMS, endMS = UnitChannelInfo("player")
  if name then
    StartCast(name, icon, startMS, endMS)
  end
end

function ClassHUD:UNIT_SPELLCAST_SUCCEEDED(_, unit, spellID)
  if unit ~= "player" then return end
  local name, _, icon = C_Spell.GetSpellInfo(spellID)
  -- Only show if the spell is instant (no cast/channel active)
  if name and not UnitCastingInfo("player") and not UnitChannelInfo("player") then
    StartCast(name, icon, GetTime() * 1000, (GetTime() + 1) * 1000) -- show 1s fake bar
  end
end

function ClassHUD:UNIT_SPELLCAST_STOP(_, unit)
  if unit == "player" then StopCast() end
end

function ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(_, unit)
  if unit == "player" then StopCast() end
end

function ClassHUD:UNIT_SPELLCAST_INTERRUPTED(_, unit)
  if unit == "player" then StopCast() end
end

function ClassHUD:UNIT_SPELLCAST_FAILED(_, unit)
  if unit == "player" then StopCast() end
end

local function UpdateHP()
  if not ClassHUD.db.profile.show.hp then return end
  local cur, max = UnitHealth("player"), UnitHealthMax("player")
  UI.hp:SetMinMaxValues(0, max)
  UI.hp:SetValue(cur)
  local pct = (max > 0) and (cur / max * 100) or 0
  UI.hp.text:SetFormattedText("%d%%", pct + 0.5)
end

local function UpdatePrimaryResource()
  if not ClassHUD.db.profile.show.resource then return end

  local id, token = UnitPowerType("player")
  local cur, max = UnitPower("player", id), UnitPowerMax("player", id)
  UI.resource:SetMinMaxValues(0, max > 0 and max or 1)
  UI.resource:SetValue(cur)

  -- color straight from Blizzard’s table
  local r, g, b = PowerColorBy(id, token)
  UI.resource:SetStatusBarColor(r, g, b)

  if id == Enum.PowerType.Mana then
    local pct = (max > 0) and (cur / max * 100) or 0
    UI.resource.text:SetFormattedText("%d%%", pct + 0.5)
  else
    UI.resource.text:SetText(cur)
  end
end


local function EnsureSegment(i)
  if not UI.powerSegments[i] then
    local sb = CreateStatusBar(UI.power, 16)
    sb.text:Hide() -- segments don’t need text
    UI.powerSegments[i] = sb
  end
  return UI.powerSegments[i]
end

local function HideAllSegments(from)
  for i = from, #UI.powerSegments do
    if UI.powerSegments[i] then UI.powerSegments[i]:Hide() end
  end
end

local function UpdateSegments(kind, ptype, max)
  local w = ClassHUD.db.profile.width
  local gap = ClassHUD.db.profile.powerSpacing or 1
  local segW = (w - gap * (max - 1)) / max
  local r, g, b = PowerColorBy(ptype) -- e.g. COMBO_POINTS/CHI/HOLY_POWER/SHARDS/CHARGES

  for i = 1, max do
    local sb = EnsureSegment(i)
    sb:SetStatusBarTexture(FetchStatusbar())
    sb:SetSize(segW, ClassHUD.db.profile.height.power)
    sb:ClearAllPoints()
    if i == 1 then
      sb:SetPoint("LEFT", UI.power, "LEFT", 0, 0)
    else
      sb:SetPoint("LEFT", UI.powerSegments[i - 1], "RIGHT", gap, 0)
    end
    sb:Show()
    if ptype then
      local cur = UnitPower("player", ptype)
      local filled = (cur >= i) and 1 or 0
      sb:SetMinMaxValues(0, 1)
      sb:SetValue(filled)
      if filled == 1 then sb:SetStatusBarColor(r, g, b) else sb:SetStatusBarColor(.2, .2, .2) end
    end
  end
  HideAllSegments(max + 1)
end

local function UpdateRunes()
  -- 6 runes; each rune shows its cooldown fill
  local w = 250
  local gap = 2
  local max = 6
  local segW = (w - gap * (max - 1)) / max
  for i = 1, max do
    local sb = EnsureSegment(i)
    sb:SetStatusBarTexture(FetchStatusbar())
    sb:SetSize(segW, 16)
    sb:ClearAllPoints()
    if i == 1 then
      sb:SetPoint("LEFT", UI.power, "LEFT", 0, 0)
    else
      sb:SetPoint("LEFT", UI.powerSegments[i - 1], "RIGHT", gap, 0)
    end
    local start, duration, ready = GetRuneCooldown(i)
    sb:SetMinMaxValues(0, 1)
    if ready then
      sb:SetValue(1); sb:SetStatusBarColor(.7, .7, .7)
    elseif start and duration and duration > 0 then
      local elapsed = GetTime() - start
      sb:SetValue(math.min(elapsed / duration, 1))
      sb:SetStatusBarColor(.35, .35, .35)
    else
      sb:SetValue(1); sb:SetStatusBarColor(.7, .7, .7)
    end
    sb:Show()
  end
  HideAllSegments(max + 1)
end

local function UpdateSpecialPower()
  if not ClassHUD.db.profile.show.power then return end
  local info = SpecialPowerInfo()
  if not info then
    HideAllSegments(1)
    UI.power:Hide()
    return
  end
  UI.power:Show()
  if info.kind == "SEGMENTS" then
    UpdateSegments("SEGMENTS", info.power, info.max or 5)
  elseif info.kind == "RUNES" then
    UpdateRunes()
  end
end

-- ---------------------------------------------------------------------------
-- Events wiring
-- ---------------------------------------------------------------------------
function ClassHUD:FullUpdate()
  Layout()
  UpdateHP()
  UpdatePrimaryResource()
  UpdateSpecialPower()
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

-- ===================================
-- Spell Tracking Module for ClassHUD
-- ===================================

-- Module
local activeFrames = {}

-- Helpers (same as before)
local function GetSpellIcon(spellID)
  local info = C_Spell.GetSpellInfo(spellID)
  return info and info.iconID or 134400
end

local function FormatSeconds(s)
  if s >= 60 then
    return string.format("%dm", math.ceil(s / 60))
  elseif s >= 10 then
    return tostring(math.floor(s + 0.5))
  else
    return string.format("%.1f", s)
  end
end

local function CreateSpellFrame(data, index)
  local frame = CreateFrame("Frame", ADDON_NAME .. "Spell" .. index, UIParent)

  -- Default size (will be resized by layout)
  frame:SetSize(40, 40)

  -- Anchor placeholder (layout will override)
  frame:SetPoint("CENTER", UIParent, "CENTER")

  -- === ICON ===
  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetAllPoints(frame)

  -- === STACK COUNT (aura stacks) ===
  frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.count:SetFont(GameFontNormalLarge:GetFont(), 14, "OUTLINE")
  frame.count:SetDrawLayer("OVERLAY", 7)
  frame.count:Hide()

  -- === COOLDOWN SPIRAL ===
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame)
  frame.cooldown:SetHideCountdownNumbers(true) -- hide Blizzard numbers
  frame.cooldown.noCooldownCount = true        -- prevent OmniCC from adding numbers
  frame.cooldown:SetDrawEdge(false)

  -- Raise spiral just above base, texts even higher
  local lvl = frame:GetFrameLevel()
  frame.cooldown:SetFrameLevel(lvl + 1)

  -- === COOLDOWN TEXT (centered numeric countdown) ===
  frame.cooldownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  frame.cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.cooldownText:SetFont(GameFontHighlightLarge:GetFont(), 16, "OUTLINE")
  frame.cooldownText:SetDrawLayer("OVERLAY", 8)
  frame.cooldownText:Hide()

  -- === STATE ===
  frame._cooldownEnd = nil
  frame.isGlowing = false
  frame.data = data

  -- === ONUPDATE: drive cooldown text ===
  frame:SetScript("OnUpdate", function(self)
    if self._cooldownEnd then
      local remain = self._cooldownEnd - GetTime()
      if remain <= 0 then
        self._cooldownEnd = nil
        self.cooldownText:Hide()
        self.icon:SetDesaturated(false)
      else
        self.cooldownText:SetText(FormatSeconds(remain))
        self.cooldownText:Show()
      end
    end
  end)


  return frame
end



local function LayoutTopBarSpells(frames)
  if not UI.attachments or not UI.attachments.TOP then return end

  local width    = ClassHUD.db.profile.width
  local perRow   = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.perRow) or 8
  local spacingX = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.spacingX) or 4
  local spacingY = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.spacingY) or 4
  local yOffset  = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.yOffset) or 0

  local size     = (width - (perRow - 1) * spacingX) / perRow

  local row, col = 0, 0
  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local rowCount = math.min(perRow, #frames - row * perRow)
    local rowWidth = rowCount * size + (rowCount - 1) * spacingX
    local startX   = (width - rowWidth) / 2

    frame:SetPoint("BOTTOMLEFT",
      UI.attachments.TOP, "TOPLEFT",
      startX + col * (size + spacingX),
      row * (size + spacingY) + spacingY + yOffset)

    col = col + 1
    if col >= perRow then
      col = 0
      row = row + 1
    end
  end
end

local function LayoutSideBarSpells(frames, side)
  if not UI.attachments or not UI.attachments[side] then return end

  local size    = (ClassHUD.db.profile.sideBars and ClassHUD.db.profile.sideBars.size) or 36
  local spacing = (ClassHUD.db.profile.sideBars and ClassHUD.db.profile.sideBars.spacing) or 4
  local offset  = (ClassHUD.db.profile.sideBars and ClassHUD.db.profile.sideBars.offset) or 6

  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    if side == "LEFT" then
      frame:SetPoint("TOPRIGHT",
        UI.attachments.LEFT, "TOPLEFT",
        -offset, -(i - 1) * (size + spacing))
    elseif side == "RIGHT" then
      frame:SetPoint("TOPLEFT",
        UI.attachments.RIGHT, "TOPRIGHT",
        offset, -(i - 1) * (size + spacing))
    end
  end
end

local function LayoutBottomBarSpells(frames)
  if not UI.attachments or not UI.attachments.BOTTOM then return end

  local width    = ClassHUD.db.profile.width
  local perRow   = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.perRow) or 8
  local spacingX = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.spacingX) or 4
  local spacingY = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.spacingY) or 4
  local yOffset  = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.yOffset) or 0

  local size     = (width - (perRow - 1) * spacingX) / perRow

  local row, col = 0, 0
  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local rowCount = math.min(perRow, #frames - row * perRow)
    local rowWidth = rowCount * size + (rowCount - 1) * spacingX
    local startX   = (width - rowWidth) / 2

    frame:SetPoint("TOPLEFT",
      UI.attachments.BOTTOM, "BOTTOMLEFT",
      startX + col * (size + spacingX),
      -(row * (size + spacingY) + spacingY + yOffset))

    col = col + 1
    if col >= perRow then
      col = 0
      row = row + 1
    end
  end
end

-- Return start, duration, enabled(1/0), modRate for a spellID.
local function ReadCooldown(spellID)
  if not spellID or not C_Spell then return 0, 0, 0, 1, nil end

  local start, duration, enabled, modRate, charges

  -- Primary cooldown info
  local cd = C_Spell.GetSpellCooldown(spellID)
  if type(cd) == "table" then
    start    = cd.startTime or 0
    duration = cd.duration or 0
    enabled  = cd.isEnabled and 1 or 0
    modRate  = cd.modRate or 1
  end

  -- Charges override
  if C_Spell.GetSpellCharges then
    local ch = C_Spell.GetSpellCharges(spellID)
    if type(ch) == "table" and ch.maxCharges and ch.currentCharges then
      charges = ch
      if ch.currentCharges < ch.maxCharges then
        start    = ch.cooldownStartTime or start
        duration = ch.cooldownDuration or duration
        enabled  = 1
        modRate  = ch.chargeModRate or modRate or 1
      end
    end
  end

  return start or 0, duration or 0, enabled or 0, modRate or 1, charges
end


local function UpdateSpellFrame(frame)
  local data = frame.data
  if not data or not data.spellID then return end

  -- === ICON ===
  local iconID = GetSpellIcon(data.spellID)
  frame.icon:SetTexture(iconID)
  frame.icon:SetDesaturated(false)

  -- === COOLDOWN TRACKING ===
  if data.trackCooldown then
    local start, duration, enabled, modRate = ReadCooldown(data.spellID)

    if enabled == 1 and start > 0 and duration > 1.45 then
      -- Spiral
      CooldownFrame_Set(frame.cooldown, start, duration, true)
      -- Numeric countdown
      frame._cooldownEnd = start + (duration / (modRate or 1))
      frame.cooldownText:Show()
      -- Desaturate while on cooldown
      frame.icon:SetDesaturated(true)
    else
      CooldownFrame_Clear(frame.cooldown)
      frame._cooldownEnd = nil
      frame.cooldownText:Hide()
      frame.icon:SetDesaturated(false)
    end
  else
    CooldownFrame_Clear(frame.cooldown)
    frame._cooldownEnd = nil
    frame.cooldownText:Hide()
    frame.icon:SetDesaturated(false)
  end

  -- === AURA STACK COUNT ===
  if data.countFromAura and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(data.countFromAura)
    local stacks = (aura and aura.applications) or 0
    if stacks > 0 then
      frame.count:SetText(stacks)
      frame.count:Show()
    else
      frame.count:SetText("")
      frame.count:Hide()
    end
  else
    frame.count:SetText("")
    frame.count:Hide()
  end

  -- === AURA GLOW ===
  -- === AURA GLOW ===
  if data.auraGlow and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(data.auraGlow)
    if aura then
      ActionButtonSpellAlertManager:ShowAlert(frame)
      frame.isGlowing = true
      -- ICON SWAP
      if aura.icon then
        frame.icon:SetTexture(aura.icon)
      end
    elseif frame.isGlowing then
      ActionButtonSpellAlertManager:HideAlert(frame)
      frame.isGlowing = false
      -- Restore normal icon
      frame.icon:SetTexture(GetSpellIcon(data.spellID))
    end
  end
end



function ClassHUD:UpdateAllFrames()
  for _, f in ipairs(activeFrames) do UpdateSpellFrame(f) end
end

function ClassHUD:BuildFramesForSpec()
  for _, f in ipairs(activeFrames) do f:Hide() end
  wipe(activeFrames)

  local specIndex = GetSpecialization()
  local specID = specIndex and GetSpecializationInfo(specIndex) or 0
  -- Top bar
  local top = self.db.profile.topBarSpells[specID]
  if top then
    local frames = {}
    for i, data in ipairs(top) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutTopBarSpells(frames)
  end

  -- Left bar
  local left = self.db.profile.leftBarSpells[specID]
  if left then
    local frames = {}
    for i, data in ipairs(left) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutSideBarSpells(frames, "LEFT")
  end

  -- Right bar
  local right = self.db.profile.rightBarSpells[specID]
  if right then
    local frames = {}
    for i, data in ipairs(right) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutSideBarSpells(frames, "RIGHT")
  end

  -- Bottom bar
  local bottom = self.db.profile.bottomBarSpells[specID]
  if bottom then
    local frames = {}
    for i, data in ipairs(bottom) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutBottomBarSpells(frames)
  end


  self:UpdateAllFrames()
end

-- Module enable
function ClassHUD:OnEnable()
  -- ============= Bars ============
  if not UI.anchor then
    CreateAnchor()
  end

  if not UI.cast then CreateCastBar() end
  if not UI.hp then CreateHPBar() end
  if not UI.resource then CreateResourceBar() end
  if not UI.power then CreatePowerContainer() end
  Layout()
  ApplyBarSkins()
end

-- EVENT HANDLER ------------------
local eventFrame = CreateFrame("Frame")

for _, ev in pairs({
  -- World/spec
  "PLAYER_ENTERING_WORLD",
  "PLAYER_SPECIALIZATION_CHANGED",

  -- Health
  "UNIT_HEALTH", "UNIT_MAXHEALTH",

  -- Resource
  "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER", "UPDATE_SHAPESHIFT_FORM",

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
  -- Debug (optional)
  -- print("Event fired:", event, unit)

  -- Full refresh after world load
  if event == "PLAYER_ENTERING_WORLD" then
    ClassHUD:FullUpdate()
    ClassHUD:ApplyAnchorPosition()
    ClassHUD:BuildFramesForSpec()
    return
  end

  -- Spec change
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
    UpdatePrimaryResource()
    UpdateSpecialPower()
    ClassHUD:BuildFramesForSpec()
    return
  end

  -- Health
  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    if unit == "player" then UpdateHP() end
    return
  end

  -- Resources
  if event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
    if unit == "player" then
      UpdatePrimaryResource()
      UpdateSpecialPower()
    end
    return
  end

  if event == "UPDATE_SHAPESHIFT_FORM" then
    UpdatePrimaryResource()
    UpdateSpecialPower()
    return
  end

  if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
    UpdateSpecialPower()
    return
  end

  -- Castbar
  if event == "UNIT_SPELLCAST_START" then
    ClassHUD:UNIT_SPELLCAST_START(_, unit)
    return
  end
  if event == "UNIT_SPELLCAST_STOP" then
    ClassHUD:UNIT_SPELLCAST_STOP(_, unit)
    return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_START" then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_START(_, unit)
    return
  end
  if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    ClassHUD:UNIT_SPELLCAST_CHANNEL_STOP(_, unit)
    return
  end
  if event == "UNIT_SPELLCAST_INTERRUPTED" then
    ClassHUD:UNIT_SPELLCAST_INTERRUPTED(_, unit)
    return
  end
  if event == "UNIT_SPELLCAST_FAILED" then
    ClassHUD:UNIT_SPELLCAST_FAILED(_, unit)
    return
  end

  -- Spells (auras + cooldowns)
  if event == "UNIT_AURA" and unit == "player" then
    ClassHUD:UpdateAllFrames()
    return
  end
  if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "UNIT_SPELLCAST_SUCCEEDED" then
    ClassHUD:UpdateAllFrames()
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
