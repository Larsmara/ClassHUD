-- ClassHUD_Options.lua
-- Rebuilt, snapshot-driven options UI

---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")

local ACR = LibStub("AceConfigRegistry-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

local PLACEMENTS = {
  HIDDEN = "Hidden",
  TOP = "Top Bar",
  BOTTOM = "Bottom Bar",
  LEFT = "Left Side",
  RIGHT = "Right Side",
}

local function NotifyOptionsChanged()
  if ACR then ACR:NotifyChange("ClassHUD") end
end

local function SortEntries(snapshot, category)
  if not snapshot then return {} end
  local list = {}
  for spellID, entry in pairs(snapshot) do
    local cat = entry.categories and entry.categories[category]
    if cat then
      table.insert(list, { spellID = spellID, entry = entry, order = (cat.order or math.huge) })
    end
  end
  table.sort(list, function(a, b)
    if a.order == b.order then
      return (a.entry.name or "") < (b.entry.name or "")
    end
    return a.order < b.order
  end)
  return list
end

local function BuildUtilityArgs(addon)
  local args = {}
  local snapshot = addon:GetSnapshotForSpec(nil, nil, false)
  local list = SortEntries(snapshot, "utility")

  if #list == 0 then
    args.empty = {
      type = "description",
      name = "No utility cooldowns reported by the snapshot for this spec.",
      order = 1,
    }
    return args
  end

  local order = 1
  for _, item in ipairs(list) do
    local spellID = item.spellID
    local info = item.entry
    local icon = info.iconID and ("|T" .. info.iconID .. ":16|t ") or ""
    local name = icon .. (info.name or ("Spell " .. spellID)) .. " (" .. spellID .. ")"

    args["spell" .. spellID] = {
      type = "select",
      name = name,
      order = order,
      values = PLACEMENTS,
      get = function()
        return addon.db.profile.utilityPlacement[spellID] or "HIDDEN"
      end,
      set = function(_, value)
        addon.db.profile.utilityPlacement[spellID] = value
        addon:BuildFramesForSpec()
      end,
    }

    order = order + 1
  end

  return args
end

local function BuildTrackedBuffArgs(addon, container)
  for k in pairs(container) do container[k] = nil end

  local class, specID = addon:GetPlayerClassSpec()
  local snapshot = addon:GetSnapshotForSpec(class, specID, false)

  if not snapshot or next(snapshot) == nil then
    container.empty = {
      type = "description",
      name = "No snapshot data available. Use the Refresh Snapshot button or re-log.",
      order = 1,
    }
    return
  end

  addon.db.profile.trackedBuffs[class] = addon.db.profile.trackedBuffs[class] or {}
  addon.db.profile.trackedBuffs[class][specID] = addon.db.profile.trackedBuffs[class][specID] or {}

  local list = SortEntries(snapshot, "buff")
  if #list == 0 then
    container.empty = {
      type = "description",
      name = "No tracked buffs exposed by the Blizzard cooldown snapshot.",
      order = 1,
    }
    return
  end

  local order = 1
  for _, item in ipairs(list) do
    local buffID = item.spellID
    local entry = item.entry
    local icon = entry.iconID and ("|T" .. entry.iconID .. ":16|t ") or ""
    local name = icon .. (entry.name or ("Buff " .. buffID)) .. " (" .. buffID .. ")"

    container["buff" .. buffID] = {
      type = "toggle",
      name = name,
      desc = entry.desc or "",
      order = order,
      get = function()
        return addon.db.profile.trackedBuffs[class][specID][buffID] or false
      end,
      set = function(_, value)
        addon.db.profile.trackedBuffs[class][specID][buffID] = value or nil
        addon:BuildTrackedBuffFrames()
        NotifyOptionsChanged()
      end,
    }

    order = order + 1
  end
end

local function BuildBuffLinkArgs(addon, container)
  for k in pairs(container) do container[k] = nil end

  local class, specID = addon:GetPlayerClassSpec()
  addon.db.profile.buffLinks[class] = addon.db.profile.buffLinks[class] or {}
  addon.db.profile.buffLinks[class][specID] = addon.db.profile.buffLinks[class][specID] or {}

  local links = addon.db.profile.buffLinks[class][specID]
  local order = 1

  if not next(links) then
    container.empty = {
      type = "description",
      name = "No manual links stored for this spec. They are created automatically when buffs reference spells in their description.",
      order = order,
    }
    return
  end

  local sorted = {}
  for buffID, spellID in pairs(links) do
    table.insert(sorted, { buffID = buffID, spellID = spellID })
  end
  table.sort(sorted, function(a, b) return a.buffID < b.buffID end)

  for _, map in ipairs(sorted) do
    local buffInfo = C_Spell.GetSpellInfo(map.buffID)
    local spellInfo = C_Spell.GetSpellInfo(map.spellID)
    local name = string.format("|T%d:16|t %s (%d) → |T%d:16|t %s (%d)",
      buffInfo and buffInfo.iconID or 134400,
      buffInfo and buffInfo.name or "Buff",
      map.buffID,
      spellInfo and spellInfo.iconID or 134400,
      spellInfo and spellInfo.name or "Spell",
      map.spellID)

    container["link" .. map.buffID] = {
      type = "group",
      name = name,
      inline = true,
      order = order,
      args = {
        spell = {
          type = "input",
          name = "Spell ID",
          width = "half",
          get = function() return tostring(map.spellID) end,
          set = function(_, value)
            local newID = tonumber(value)
            if newID then
              addon.db.profile.buffLinks[class][specID][map.buffID] = newID
              addon:BuildFramesForSpec()
              NotifyOptionsChanged()
            end
          end,
        },
        remove = {
          type = "execute",
          name = "Remove",
          confirm = true,
          func = function()
            addon.db.profile.buffLinks[class][specID][map.buffID] = nil
            addon:BuildFramesForSpec()
            BuildBuffLinkArgs(addon, container)
            NotifyOptionsChanged()
          end,
        },
      },
    }

    order = order + 1
  end
end

function ClassHUD_BuildOptions(addon)
  local db = addon.db

  db.profile.textures = db.profile.textures or { bar = "Blizzard", font = "Friz Quadrata TT" }
  db.profile.show = db.profile.show or { cast = true, hp = true, resource = true, power = true, buffs = true }
  db.profile.height = db.profile.height or { cast = 18, hp = 14, resource = 14, power = 14 }
  db.profile.colors = db.profile.colors or {
    hp = { r = 0.10, g = 0.80, b = 0.10 },
    resourceClass = true,
    resource = { r = 0.00, g = 0.55, b = 1.00 },
    power = { r = 1.00, g = 0.85, b = 0.10 },
  }
  db.profile.utilityPlacement = db.profile.utilityPlacement or {}
  db.profile.trackedBuffs = db.profile.trackedBuffs or {}
  db.profile.buffLinks = db.profile.buffLinks or {}

  local trackedContainer = {}
  local linkContainer = {}

  local opts = {
    type = "group",
    name = "ClassHUD",
    childGroups = "tab",
    args = {
      general = {
        type = "group",
        name = "General",
        order = 1,
        args = {
          locked = {
            type = "toggle",
            name = "Lock Frame",
            order = 1,
            get = function() return db.profile.locked end,
            set = function(_, value)
              db.profile.locked = value
            end,
          },
          width = {
            type = "range",
            name = "Bar Width",
            min = 200,
            max = 600,
            step = 1,
            order = 2,
            get = function() return db.profile.width end,
            set = function(_, value)
              db.profile.width = value
              addon:FullUpdate()
              addon:BuildFramesForSpec()
            end,
          },
          spacing = {
            type = "range",
            name = "Bar Spacing",
            min = 0,
            max = 12,
            step = 1,
            order = 3,
            get = function() return db.profile.spacing or 2 end,
            set = function(_, value)
              db.profile.spacing = value
              addon:FullUpdate()
              addon:BuildFramesForSpec()
            end,
          },
          texture = {
            type = "select",
            name = "Bar Texture",
            dialogControl = "LSM30_Statusbar",
            order = 4,
            values = LSM and LSM:HashTable("statusbar") or {},
            get = function() return db.profile.textures.bar end,
            set = function(_, value)
              db.profile.textures.bar = value
              addon:ApplyBarSkins()
            end,
          },
          font = {
            type = "select",
            name = "Font",
            dialogControl = "LSM30_Font",
            order = 5,
            values = LSM and LSM:HashTable("font") or {},
            get = function() return db.profile.textures.font end,
            set = function(_, value)
              db.profile.textures.font = value
              addon:FullUpdate()
              addon:BuildFramesForSpec()
            end,
          },
        },
      },
      bars = {
        type = "group",
        name = "Bars",
        order = 2,
        inline = false,
        args = {
          showCast = {
            type = "toggle",
            name = "Show Cast Bar",
            order = 1,
            get = function() return db.profile.show.cast end,
            set = function(_, value)
              db.profile.show.cast = value
              addon:FullUpdate()
            end,
          },
          showHP = {
            type = "toggle",
            name = "Show Health Bar",
            order = 2,
            get = function() return db.profile.show.hp end,
            set = function(_, value)
              db.profile.show.hp = value
              addon:FullUpdate()
            end,
          },
          showResource = {
            type = "toggle",
            name = "Show Primary Resource",
            order = 3,
            get = function() return db.profile.show.resource end,
            set = function(_, value)
              db.profile.show.resource = value
              addon:FullUpdate()
            end,
          },
          showPower = {
            type = "toggle",
            name = "Show Special Power",
            order = 4,
            get = function() return db.profile.show.power end,
            set = function(_, value)
              db.profile.show.power = value
              addon:FullUpdate()
            end,
          },
          showBuffs = {
            type = "toggle",
            name = "Show Tracked Buff Bar",
            order = 5,
            get = function() return db.profile.show.buffs end,
            set = function(_, value)
              db.profile.show.buffs = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          powerSpacing = {
            type = "range",
            name = "Segment Spacing",
            order = 6,
            min = 0,
            max = 12,
            step = 1,
            get = function() return db.profile.powerSpacing or 2 end,
            set = function(_, value)
              db.profile.powerSpacing = value
              addon:FullUpdate()
            end,
          },
          heightCast = {
            type = "range",
            name = "Cast Height",
            order = 7,
            min = 8,
            max = 40,
            step = 1,
            get = function() return db.profile.height.cast end,
            set = function(_, value)
              db.profile.height.cast = value
              addon:FullUpdate()
            end,
          },
          heightHP = {
            type = "range",
            name = "Health Height",
            order = 8,
            min = 8,
            max = 40,
            step = 1,
            get = function() return db.profile.height.hp end,
            set = function(_, value)
              db.profile.height.hp = value
              addon:FullUpdate()
            end,
          },
          heightResource = {
            type = "range",
            name = "Resource Height",
            order = 9,
            min = 8,
            max = 40,
            step = 1,
            get = function() return db.profile.height.resource end,
            set = function(_, value)
              db.profile.height.resource = value
              addon:FullUpdate()
            end,
          },
          heightPower = {
            type = "range",
            name = "Special Power Height",
            order = 10,
            min = 8,
            max = 40,
            step = 1,
            get = function() return db.profile.height.power end,
            set = function(_, value)
              db.profile.height.power = value
              addon:FullUpdate()
            end,
          },
        },
      },
      colors = {
        type = "group",
        name = "Colors",
        order = 3,
        args = {
          hp = {
            type = "color",
            name = "Health",
            order = 1,
            get = function()
              local c = db.profile.colors.hp
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.profile.colors.hp = { r = r, g = g, b = b }
              addon:UpdateHP()
            end,
          },
          resourceClass = {
            type = "toggle",
            name = "Use Class Color for Primary Resource",
            order = 2,
            get = function() return db.profile.colors.resourceClass end,
            set = function(_, value)
              db.profile.colors.resourceClass = value
              addon:UpdatePrimaryResource()
            end,
          },
          resource = {
            type = "color",
            name = "Primary Resource",
            order = 3,
            get = function()
              local c = db.profile.colors.resource
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.profile.colors.resource = { r = r, g = g, b = b }
              addon:UpdatePrimaryResource()
            end,
            disabled = function() return db.profile.colors.resourceClass end,
          },
          power = {
            type = "color",
            name = "Special Power",
            order = 4,
            get = function()
              local c = db.profile.colors.power
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.profile.colors.power = { r = r, g = g, b = b }
              addon:UpdateSpecialPower()
            end,
          },
        },
      },
      spells = {
        type = "group",
        name = "Spells & Buffs",
        order = 4,
        args = {
          utility = {
            type = "group",
            name = "Utility Placement",
            order = 1,
            args = BuildUtilityArgs(addon),
          },
          trackedBuffs = {
            type = "group",
            name = "Tracked Buffs",
            order = 2,
            args = {
              description = {
                type = "description",
                name = "Toggle the buffs that should appear in the tracked buff bar above your spells.",
                order = 1,
              },
              list = {
                type = "group",
                name = "Buffs",
                inline = true,
                order = 2,
                args = trackedContainer,
              },
            },
          },
          buffLinks = {
            type = "group",
            name = "Buff Links",
            order = 3,
            args = {
              description = {
                type = "description",
                name = "Manual overrides linking a buff to a spell. These are populated automatically when possible.",
                order = 1,
              },
              list = {
                type = "group",
                name = "Links",
                inline = true,
                order = 2,
                args = linkContainer,
              },
            },
          },
        },
      },
      snapshot = {
        type = "group",
        name = "Snapshot",
        order = 5,
        args = {
          refresh = {
            type = "execute",
            name = "Refresh Snapshot",
            order = 1,
            func = function()
              addon:UpdateCDMSnapshot()
              addon:BuildFramesForSpec()
              BuildTrackedBuffArgs(addon, trackedContainer)
              BuildBuffLinkArgs(addon, linkContainer)
              NotifyOptionsChanged()
            end,
          },
          note = {
            type = "description",
            order = 2,
            name = "The snapshot is rebuilt automatically on login and specialization changes. Use this button if Blizzard updates the Cooldown Viewer data while you are logged in.",
          },
        },
      },
    },
  }

  BuildTrackedBuffArgs(addon, trackedContainer)
  BuildBuffLinkArgs(addon, linkContainer)

  return opts
end

function ClassHUD:GetUtilityOptions()
  return {
    type = "group",
    name = "Utility Cooldowns",
    args = BuildUtilityArgs(self),
  }
end
