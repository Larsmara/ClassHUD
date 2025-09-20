local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")

local ACR = LibStub("AceConfigRegistry-3.0", true)
local LSM = LibStub("LibSharedMedia-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)

local copyTable = CopyTable
if type(copyTable) ~= "function" then
  copyTable = function(tbl)
    local result = {}
    if type(tbl) == "table" then
      for k, v in pairs(tbl) do
        result[k] = v
      end
    end
    return result
  end
end

local optionsState = {
  newCustomBuff = "",
}

local function NotifyOptionsChanged()
  if ACR then
    ACR:NotifyChange("ClassHUD")
  end
end

local function FormatSpellLabel(spellID)
  local info = C_Spell.GetSpellInfo(spellID)
  local icon = info and info.iconID or 134400
  local name = info and info.name or ("Spell " .. spellID)
  return string.format("|T%d:16|t %s (%d)", icon, name, spellID)
end

local function BuildTrackedEntries(addon)
  local entries = {}
  local index = 1
  local seen = {}

  for _, entry in ipairs(addon:BuildTrackedBuffsFromBlizzard()) do
    local copy = copyTable(entry)
    copy.order = index
    copy.category = "Tracked Buff"
    entries[#entries + 1] = copy
    seen[copy.buffID] = copy
    index = index + 1
  end

  for _, entry in ipairs(addon:BuildTrackedBarsAsBuffs()) do
    local existing = seen[entry.buffID]
    if existing then
      existing.isTrackedBar = true
      existing.category = existing.category .. " + Tracked Bar"
      existing.cooldownID = existing.cooldownID or entry.cooldownID
    else
      local copy = copyTable(entry)
      copy.order = index
      copy.category = "Tracked Bar"
      entries[#entries + 1] = copy
      seen[copy.buffID] = copy
      index = index + 1
    end
  end

  table.sort(entries, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return (a.name or "") < (b.name or "")
  end)

  return entries
end

local function BuildBlizzardTrackedArgs(addon)
  local args = {}
  local entries = BuildTrackedEntries(addon)
  local order = 1

  if #entries == 0 then
    args.none = {
      type = "description",
      name = "Blizzard has no tracked buffs for this specialization.",
      order = order,
    }
    return args
  end

  for _, entry in ipairs(entries) do
    local key = "tracked" .. entry.buffID
    local label = FormatSpellLabel(entry.buffID)
    if entry.category then
      label = string.format("%s |cff8080ff[%s]|r", label, entry.category)
    end

    args[key] = {
      type = "toggle",
      name = label,
      desc = entry.snapshot and entry.snapshot.desc or nil,
      width = "full",
      order = order,
      get = function()
        return not addon:IsTrackedBuffHidden(entry.buffID)
      end,
      set = function(_, value)
        addon:SetTrackedBuffHidden(entry.buffID, not value)
        addon:BuildTrackedBuffFrames()
        addon:RefreshRegisteredOptions()
        NotifyOptionsChanged()
      end,
    }

    order = order + 1
  end

  return args
end

local function BuildCustomTrackedArgs(addon)
  local args = {}
  local list = addon:GetCustomTrackedBuffList()
  local order = 1

  if #list == 0 then
    args.none = {
      type = "description",
      name = "No custom buffs configured.",
      order = order,
    }
    return args
  end

  for _, spellID in ipairs(list) do
    local label = FormatSpellLabel(spellID)
    local key = "custom" .. spellID

    args[key] = {
      type = "group",
      name = label,
      inline = true,
      order = order,
      args = {
        enabled = {
          type = "toggle",
          name = "Show Icon",
          order = 1,
          width = "half",
          get = function()
            return not addon:IsTrackedBuffHidden(spellID)
          end,
          set = function(_, value)
            addon:SetTrackedBuffHidden(spellID, not value)
            addon:BuildTrackedBuffFrames()
            addon:RefreshRegisteredOptions()
            NotifyOptionsChanged()
          end,
        },
        remove = {
          type = "execute",
          name = "Remove",
          order = 2,
          func = function()
            addon:RemoveCustomTrackedBuff(spellID)
            addon:SetTrackedBuffHidden(spellID, false)
            addon:BuildTrackedBuffFrames()
            addon:RefreshRegisteredOptions()
            NotifyOptionsChanged()
          end,
        },
      },
    }

    order = order + 1
  end

  return args
end

local function BuildTrackedGroup(addon)
  local db = addon.db.profile
  return {
    type = "group",
    name = "Tracked Buffs",
    order = 2,
    args = {
      enabled = {
        type = "toggle",
        name = "Enable Tracked Buff Icons",
        order = 1,
        width = "full",
        get = function() return db.show.buffs end,
        set = function(_, value)
          db.show.buffs = value
          addon:BuildTrackedBuffFrames()
        end,
      },
      layout = {
        type = "group",
        name = "Layout",
        inline = true,
        order = 2,
        args = {
          perRow = {
            type = "range",
            name = "Icons per Row",
            min = 1,
            max = 12,
            step = 1,
            order = 1,
            get = function() return db.trackedBuffBar.perRow or 8 end,
            set = function(_, value)
              db.trackedBuffBar.perRow = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          spacingX = {
            type = "range",
            name = "Horizontal Spacing",
            min = 0,
            max = 20,
            step = 1,
            order = 2,
            get = function() return db.trackedBuffBar.spacingX or 4 end,
            set = function(_, value)
              db.trackedBuffBar.spacingX = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          spacingY = {
            type = "range",
            name = "Vertical Spacing",
            min = 0,
            max = 20,
            step = 1,
            order = 3,
            get = function() return db.trackedBuffBar.spacingY or 4 end,
            set = function(_, value)
              db.trackedBuffBar.spacingY = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          align = {
            type = "select",
            name = "Row Alignment",
            order = 4,
            values = {
              LEFT = "Left",
              CENTER = "Center",
              RIGHT = "Right",
            },
            style = "dropdown",
            get = function() return db.trackedBuffBar.align or "CENTER" end,
            set = function(_, value)
              db.trackedBuffBar.align = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          offsetX = {
            type = "range",
            name = "Horizontal Offset",
            min = -200,
            max = 200,
            step = 1,
            order = 5,
            get = function() return db.trackedBuffBar.offsetX or 0 end,
            set = function(_, value)
              db.trackedBuffBar.offsetX = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          offsetY = {
            type = "range",
            name = "Vertical Offset",
            min = -200,
            max = 200,
            step = 1,
            order = 6,
            get = function() return db.trackedBuffBar.offsetY or 8 end,
            set = function(_, value)
              db.trackedBuffBar.offsetY = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          fontSize = {
            type = "range",
            name = "Font Size",
            min = 8,
            max = 24,
            step = 1,
            order = 7,
            get = function() return db.buffFontSize or 12 end,
            set = function(_, value)
              db.buffFontSize = value
              addon:BuildTrackedBuffFrames()
            end,
          },
        },
      },
      blizzard = {
        type = "group",
        name = "Blizzard Tracked Buffs",
        order = 3,
        args = BuildBlizzardTrackedArgs(addon),
      },
      custom = {
        type = "group",
        name = "Custom Buffs",
        order = 4,
        args = {
          add = {
            type = "input",
            name = "Add Spell ID",
            order = 1,
            width = "half",
            get = function()
              return optionsState.newCustomBuff
            end,
            set = function(_, value)
              optionsState.newCustomBuff = ""
              local spellID = tonumber(value)
              if not spellID then return end
              local info = C_Spell.GetSpellInfo(spellID)
            if not info then return end
            addon:AddCustomTrackedBuff(spellID)
            addon:SetTrackedBuffHidden(spellID, false)
            addon:BuildTrackedBuffFrames()
            addon:RefreshRegisteredOptions()
            NotifyOptionsChanged()
          end,
          },
          list = {
            type = "group",
            name = "Configured Buffs",
            order = 2,
            inline = false,
            args = BuildCustomTrackedArgs(addon),
          },
        },
      },
    },
  }
end

local function BuildGeneralGroup(addon)
  local db = addon.db.profile
  return {
    type = "group",
    name = "General",
    order = 1,
    args = {
      locked = {
        type = "toggle",
        name = "Lock Position",
        order = 1,
        get = function() return db.locked end,
        set = function(_, value)
          db.locked = value
        end,
      },
      position = {
        type = "group",
        name = "Anchor Offset",
        inline = true,
        order = 2,
        args = {
          posX = {
            type = "range",
            name = "Horizontal",
            min = -400,
            max = 400,
            step = 1,
            order = 1,
            get = function() return db.position.x or 0 end,
            set = function(_, value)
              db.position.x = value
              addon:ApplyAnchorPosition()
            end,
          },
          posY = {
            type = "range",
            name = "Vertical",
            min = -400,
            max = 400,
            step = 1,
            order = 2,
            get = function() return db.position.y or -24 end,
            set = function(_, value)
              db.position.y = value
              addon:ApplyAnchorPosition()
            end,
          },
        },
      },
      layout = {
        type = "group",
        name = "Layout",
        inline = true,
        order = 3,
        args = {
          width = {
            type = "range",
            name = "Bar Width",
            min = 150,
            max = 400,
            step = 1,
            order = 1,
            get = function() return db.width end,
            set = function(_, value)
              db.width = value
              addon:FullUpdate()
            end,
          },
          spacing = {
            type = "range",
            name = "Vertical Spacing",
            min = 0,
            max = 20,
            step = 1,
            order = 2,
            get = function() return db.spacing or 2 end,
            set = function(_, value)
              db.spacing = value
              addon:FullUpdate()
            end,
          },
          powerSpacing = {
            type = "range",
            name = "Power Segment Spacing",
            min = 0,
            max = 12,
            step = 1,
            order = 3,
            get = function() return db.powerSpacing or 2 end,
            set = function(_, value)
              db.powerSpacing = value
              addon:FullUpdate()
            end,
          },
          heightCast = {
            type = "range",
            name = "Cast Bar Height",
            min = 8,
            max = 40,
            step = 1,
            order = 4,
            get = function() return db.height.cast end,
            set = function(_, value)
              db.height.cast = value
              addon:FullUpdate()
            end,
          },
          heightHP = {
            type = "range",
            name = "Health Bar Height",
            min = 8,
            max = 40,
            step = 1,
            order = 5,
            get = function() return db.height.hp end,
            set = function(_, value)
              db.height.hp = value
              addon:FullUpdate()
            end,
          },
          heightResource = {
            type = "range",
            name = "Primary Resource Height",
            min = 8,
            max = 40,
            step = 1,
            order = 6,
            get = function() return db.height.resource end,
            set = function(_, value)
              db.height.resource = value
              addon:FullUpdate()
            end,
          },
          heightPower = {
            type = "range",
            name = "Special Power Height",
            min = 8,
            max = 40,
            step = 1,
            order = 7,
            get = function() return db.height.power end,
            set = function(_, value)
              db.height.power = value
              addon:FullUpdate()
            end,
          },
        },
      },
      bars = {
        type = "group",
        name = "Bars",
        inline = true,
        order = 4,
        args = {
          cast = {
            type = "toggle",
            name = "Show Cast Bar",
            order = 1,
            get = function() return db.show.cast end,
            set = function(_, value)
              db.show.cast = value
              addon:FullUpdate()
            end,
          },
          hp = {
            type = "toggle",
            name = "Show Health Bar",
            order = 2,
            get = function() return db.show.hp end,
            set = function(_, value)
              db.show.hp = value
              addon:FullUpdate()
            end,
          },
          resource = {
            type = "toggle",
            name = "Show Primary Resource",
            order = 3,
            get = function() return db.show.resource end,
            set = function(_, value)
              db.show.resource = value
              addon:FullUpdate()
            end,
          },
          power = {
            type = "toggle",
            name = "Show Class Power",
            order = 4,
            get = function() return db.show.power end,
            set = function(_, value)
              db.show.power = value
              addon:FullUpdate()
            end,
          },
        },
      },
      textures = {
        type = "group",
        name = "Textures & Fonts",
        inline = true,
        order = 5,
        args = {
          bar = {
            type = "select",
            name = "Bar Texture",
            dialogControl = LSM and "LSM30_Statusbar" or nil,
            order = 1,
            values = function()
              return (LSM and LSM:HashTable("statusbar")) or {}
            end,
            get = function() return db.textures.bar end,
            set = function(_, value)
              db.textures.bar = value
              addon:ApplyBarSkins()
            end,
          },
          font = {
            type = "select",
            name = "Font",
            dialogControl = LSM and "LSM30_Font" or nil,
            order = 2,
            values = function()
              return (LSM and LSM:HashTable("font")) or {}
            end,
            get = function() return db.textures.font end,
            set = function(_, value)
              db.textures.font = value
              addon:FullUpdate()
            end,
          },
          spellFontSize = {
            type = "range",
            name = "Cast Bar Font Size",
            min = 8,
            max = 24,
            step = 1,
            order = 3,
            get = function() return db.spellFontSize or 12 end,
            set = function(_, value)
              db.spellFontSize = value
              addon:FullUpdate()
            end,
          },
        },
      },
      colors = {
        type = "group",
        name = "Colors",
        inline = true,
        order = 6,
        args = {
          hp = {
            type = "color",
            name = "Health",
            order = 1,
            get = function()
              local c = db.colors.hp
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.colors.hp = { r = r, g = g, b = b }
              addon:UpdateHP()
            end,
          },
          resourceClass = {
            type = "toggle",
            name = "Use Class Color for Primary Resource",
            order = 2,
            get = function() return db.colors.resourceClass end,
            set = function(_, value)
              db.colors.resourceClass = value
              addon:UpdatePrimaryResource()
            end,
          },
          resource = {
            type = "color",
            name = "Primary Resource",
            order = 3,
            disabled = function() return db.colors.resourceClass end,
            get = function()
              local c = db.colors.resource
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.colors.resource = { r = r, g = g, b = b }
              addon:UpdatePrimaryResource()
            end,
          },
          power = {
            type = "color",
            name = "Class Power",
            order = 4,
            get = function()
              local c = db.colors.power
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.colors.power = { r = r, g = g, b = b }
              addon:UpdateSpecialPower()
            end,
          },
        },
      },
    },
  }
end

function ClassHUD_BuildOptions(addon)
  local options = {
    type = "group",
    name = "ClassHUD",
    childGroups = "tab",
    args = {
      general = BuildGeneralGroup(addon),
      tracked = BuildTrackedGroup(addon),
    },
  }

  if AceDBOptions and addon.db then
    options.args.profiles = AceDBOptions:GetOptionsTable(addon.db)
    options.args.profiles.order = 99
  end

  return options
end
