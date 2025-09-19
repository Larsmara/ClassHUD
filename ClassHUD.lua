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
    locked           = false,
    width            = 250,
    spacing          = 2,
    powerSpacing     = 2,
    position         = { x = 0, y = -50 },
    borderColor      = { r = 0, g = 0, b = 0, a = 1 },
    textures         = {
      bar  = "Blizzard",
      font = "Friz Quadrata TT",
    },

    show             = {
      cast     = true,
      hp       = true,
      resource = true, -- primary (mana/rage/energy/etc.)
      power    = true, -- special (combo/chi/shards/etc.)
      buffs    = true,
    },

    height           = {
      cast     = 18,
      hp       = 14,
      resource = 14,
      power    = 14,
    },

    sideBars         = {
      size    = 36,
      spacing = 4,
      offset  = 6,
    },

    topBar           = {
      perRow   = 8,
      spacingX = 4,
      spacingY = 4,
      yOffset  = 0,
      grow     = "UP", -- "UP" eller "DOWN"
    },
    bottomBar        = {
      perRow   = 8,
      spacingX = 4,
      spacingY = 4,
      yOffset  = 0,
    },
    trackedBuffBar   = {
      perRow   = 8,
      spacingX = 4,
      spacingY = 4,
      yOffset  = 4,        -- litt luft over TopBar
      align    = "CENTER", -- "LEFT" | "CENTER" | "RIGHT"
      height   = 16,
    },

    layout           = {
      order = { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" },
    },

    -- =========================
    -- Spell & Buff persistence
    -- =========================

    -- Utility placement per spellID
    utilityPlacement = {
      -- [spellID] = "TOP" | "BOTTOM" | "LEFT" | "RIGHT"
    },

    -- Persistente buff-links (class -> spec -> buffID -> spellID)
    buffLinks        = {},

    -- Brukervalgte tracked buffs (class -> spec -> buffID -> true/false)
    trackedBuffs     = {},

    -- CDM snapshot (slik at vi ikke trenger å spørre CDM hver gang)
    cdmSnapshot      = {
      -- [class] = {
      --   [specID] = {
      --     [category] = {
      --       [spellID] = {
      --         spellID = ...,
      --         iconID  = ...,
      --         name    = ...,
      --         desc    = ...,
      --       }
      --     }
      --   }
      -- }
    },

    colors           = {
      hp            = { r = 0.10, g = 0.80, b = 0.10 },
      resourceClass = true,
      resource      = { r = 0.00, g = 0.55, b = 1.00 },
      power         = { r = 1.00, g = 0.85, b = 0.10 },
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
function ClassHUD:CreateStatusBar(parent, height, withBorder)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetSize(self.db.profile.width or 250, height or 16)

  local edge = (self.db.profile.borderSize and math.max(1, self.db.profile.borderSize)) or 1

  if withBorder then
    holder:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = edge,
      insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local c = self.db.profile.borderColor or { r = 0, g = 0, b = 0, a = 1 }
    holder:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    holder:SetBackdropColor(0, 0, 0, 0.40)
  end

  local bar = CreateFrame("StatusBar", nil, holder)
  bar:SetPoint("TOPLEFT", holder, "TOPLEFT", edge, -edge)
  bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -edge, edge)
  bar:SetStatusBarTexture(self:FetchStatusbar())
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetColorTexture(0, 0, 0, 0.55)

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont(self:FetchFont(12))

  bar._holder = holder
  bar._edge   = edge
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

---Rebuilds the Cooldown Viewer snapshot for the current class/spec.
---The snapshot is the authoritative data source for layout, options and UI.
function ClassHUD:UpdateCDMSnapshot()
  if not self:IsCooldownViewerAvailable() then return end

  local class, specID = self:GetPlayerClassSpec()
  local snapshot = self:GetSnapshotForSpec(class, specID, true)
  if not snapshot then return end

  -- clear old
  for key in pairs(snapshot) do snapshot[key] = nil end

  local categories = {
    [Enum.CooldownViewerCategory.Essential]   = "essential",
    [Enum.CooldownViewerCategory.Utility]     = "utility",
    [Enum.CooldownViewerCategory.TrackedBuff] = "buff",
    [Enum.CooldownViewerCategory.TrackedBar]  = "bar",
  }

  local orderByCategory = {}

  for cat, catName in pairs(categories) do
    local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat)
    if type(ids) == "table" then
      for _, cooldownID in ipairs(ids) do
        local raw = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        local sid = raw and (raw.spellID or raw.overrideSpellID or (raw.linkedSpellIDs and raw.linkedSpellIDs[1]))
        if sid then
          local info = C_Spell.GetSpellInfo(sid)
          local desc = C_Spell.GetSpellDescription(sid)

          local entry = snapshot[sid]
          if not entry then
            entry = {
              spellID     = sid,
              name        = info and info.name or ("Spell " .. sid),
              iconID      = info and info.iconID,
              desc        = desc,
              categories  = {},
              category    = catName,
              lastUpdated = GetServerTime and GetServerTime() or time(),
            }
            snapshot[sid] = entry
          else
            entry.name        = info and info.name or entry.name
            entry.iconID      = info and info.iconID or entry.iconID
            entry.desc        = desc or entry.desc
            entry.category    = entry.category or catName
            entry.lastUpdated = GetServerTime and GetServerTime() or time()
          end

          orderByCategory[catName] = (orderByCategory[catName] or 0) + 1
          entry.categories[catName] = {
            cooldownID      = cooldownID,
            overrideSpellID = raw.overrideSpellID,
            linkedSpellIDs  = raw.linkedSpellIDs and { unpack(raw.linkedSpellIDs) } or nil,
            hasAura         = raw.hasAura,
            order           = orderByCategory[catName],
          }
        end
      end
    end
  end
end

-- ===== Options bootstrap (registers with AceConfigRegistry directly) =====
function ClassHUD:RegisterOptions()
  local ACR = LibStub("AceConfigRegistry-3.0", true)
  local ACD = LibStub("AceConfigDialog-3.0", true)
  if not (ACR and ACD) then
    return false
  end

  -- Try to use the real builder from ClassHUD_Options.lua
  local builder = _G.ClassHUD_BuildOptions
  local opts

  if type(builder) == "function" then
    local ok, res = pcall(builder, self)
    if ok then
      opts = res
    end
  end

  -- If still missing, warn ONCE and install a tiny fallback so /chud works
  if not opts then
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

function ClassHUD:RefreshRegisteredOptions()
  local builder = _G.ClassHUD_BuildOptions
  if type(builder) ~= "function" then return end

  local ok, opts = pcall(builder, self)
  if not ok or not opts then return end

  self._opts = opts

  if self._opts_registered then
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR then
      ACR:RegisterOptionsTable("ClassHUD", opts)
      ACR:NotifyChange("ClassHUD")
    end
  end
end

function ClassHUD:OpenOptions()
  local ACR = LibStub("AceConfigRegistry-3.0", true)
  local ACD = LibStub("AceConfigDialog-3.0", true)
  if not (ACR and ACD) then
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
    local snapshotUpdated = ClassHUD:UpdateCDMSnapshot()
    if ClassHUD.BuildFramesForSpec then ClassHUD:BuildFramesForSpec() end
    if snapshotUpdated or ClassHUD._opts then ClassHUD:RefreshRegisteredOptions() end
    return
  end

  -- Spec change
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
    ClassHUD:UpdateCDMSnapshot()
    if ClassHUD.UpdatePrimaryResource then ClassHUD:UpdatePrimaryResource() end
    if ClassHUD.UpdateSpecialPower then ClassHUD:UpdateSpecialPower() end
    if ClassHUD.BuildFramesForSpec then ClassHUD:BuildFramesForSpec() end
    ClassHUD:RefreshRegisteredOptions()
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
  if (event == "UNIT_AURA" and (unit == "player" or unit == "pet")) or
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

SLASH_CLASSHUDRESET1 = "/classhudreset"
SlashCmdList.CLASSHUDRESET = function()
  if ClassHUD and ClassHUD.db then
    ClassHUD.db:ResetProfile()
    ClassHUD:BuildFramesForSpec()
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR and ClassHUD._opts then ACR:NotifyChange("ClassHUD") end
    print("|cff00ff00ClassHUD: profile reset.|r")
  end
end

-- ==================================================
-- Debug command: /chudlistbuffs
-- ==================================================
SLASH_CHUDLISTBUFFS1 = "/chudlistbuffs"
SlashCmdList.CHUDLISTBUFFS = function()
  local enum = Enum and Enum.CooldownViewerCategory
  if not enum then
    print("|cff00ff88ClassHUD|r Enum.CooldownViewerCategory ikke tilgjengelig.")
    return
  end

  local class, specID = ClassHUD:GetPlayerClassSpec()
  local snapshot = ClassHUD:GetSnapshotForSpec(class, specID, false)
  if not snapshot then
    print("|cff00ff88ClassHUD|r Ingen snapshot tilgjengelig. Bruk /classhudreset eller relogg.")
    return
  end

  print("|cff00ff88ClassHUD|r Liste over Tracked Buffs fra snapshot:")
  for spellID, data in pairs(snapshot) do
    if data.categories and data.categories.buff then
      print(string.format("  SpellID=%d, Name=%s", spellID, data.name or "Unknown"))
    end
  end
end

-- ==================================================
-- Debug command: /chudbuffdesc
-- ==================================================
SLASH_CHUDBUFFDESC1 = "/chudbuffdesc"
SlashCmdList.CHUDBUFFDESC = function()
  local enum = Enum and Enum.CooldownViewerCategory
  if not enum then
    print("|cff00ff88ClassHUD|r Enum.CooldownViewerCategory ikke tilgjengelig.")
    return
  end

  local class, specID = ClassHUD:GetPlayerClassSpec()
  local snapshot = ClassHUD:GetSnapshotForSpec(class, specID, false)
  if not snapshot then
    print("|cff00ff88ClassHUD|r Ingen snapshot tilgjengelig.")
    return
  end

  print("|cff00ff88ClassHUD|r Tracked Buff descriptions:")
  for spellID, entry in pairs(snapshot) do
    if entry.categories and entry.categories.buff then
      local desc = entry.desc or C_Spell.GetSpellDescription(spellID) or "No description"
      print(string.format("  [%d] %s → %s", spellID, entry.name or "Unknown", desc:gsub("\n", " ")))
    end
  end
end

-- /chudmap : vis buff -> spell mapping
SLASH_CHUDMAP1 = "/chudmap"
SlashCmdList.CHUDMAP = function()
  if not ClassHUD.trackedBuffToSpell or next(ClassHUD.trackedBuffToSpell) == nil then
    print("|cff00ff88ClassHUD|r Ingen auto-mapping (buff → spell) er registrert.")
    return
  end
  print("|cff00ff88ClassHUD|r Auto-mapping (buff → spell):")
  for buffID, spellID in pairs(ClassHUD.trackedBuffToSpell) do
    local bName = C_Spell.GetSpellName(buffID) or ("buff " .. buffID)
    local sName = C_Spell.GetSpellName(spellID) or ("spell " .. spellID)
    print(string.format("  %s (%d)  →  %s (%d)", bName, buffID, sName, spellID))
  end
end

-- ==================================================
-- Debug command: /chudtracked
-- Viser snapshot vs. aktive buffs
-- ==================================================
SLASH_CHUDTRACKED1 = "/chudtracked"
SlashCmdList.CHUDTRACKED = function()
  local class, specID = ClassHUD:GetPlayerClassSpec()

  print("|cff00ff88ClassHUD|r Debug: Tracked Buffs for", class, specID)

  local snapshot = ClassHUD:GetSnapshotForSpec(class, specID, false)

  local tracked = ClassHUD.db.profile.trackedBuffs
      and ClassHUD.db.profile.trackedBuffs[class]
      and ClassHUD.db.profile.trackedBuffs[class][specID]

  if not snapshot then
    print("  Ingen snapshot lagret for denne spec.")
    return
  end

  for buffID, data in pairs(snapshot) do
    if data.categories and data.categories.buff then
      local name = data.name or ("Buff " .. buffID)
      local candidates = ClassHUD:GetAuraCandidatesForEntry(data, buffID)
      local aura = select(1, ClassHUD:FindAuraFromCandidates(candidates, { "player", "pet" }))
      local active = aura and true or false

      local config = tracked and ClassHUD.GetTrackedEntryConfig
          and ClassHUD:GetTrackedEntryConfig(class, specID, buffID, false)

      local enabled
      if config and (config.showIcon or config.showBar) then
        local modes = {}
        if config.showIcon then table.insert(modes, "icon") end
        if config.showBar then table.insert(modes, "bar") end
        enabled = string.format("|cff00ff00ON (%s)|r", table.concat(modes, ", "))
      else
        enabled = "|cffff0000OFF|r"
      end

      local status = active and "|cff00ff00ACTIVE|r" or "inactive"

      print(string.format("  [%d] %s → tracked=%s, %s",
        buffID, name, enabled, status))
    end
  end
end
