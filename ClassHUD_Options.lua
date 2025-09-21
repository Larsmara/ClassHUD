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

local optionsState = {
  newLinkBuffID = "",
  newLinkSpellID = "",
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

-- Bygger Top Bar Spells-editoren inline (uten å lage ny venstremeny-node)
local function BuildTopBarSpellsEditor(addon, container)
  for k in pairs(container) do container[k] = nil end

  local class, specID = addon:GetPlayerClassSpec()

  addon.db.profile.utilityPlacement[class] = addon.db.profile.utilityPlacement[class] or {}
  addon.db.profile.utilityPlacement[class][specID] = addon.db.profile.utilityPlacement[class][specID] or {}
  local placements = addon.db.profile.utilityPlacement[class][specID]

  local snapshot = addon:GetSnapshotForSpec(class, specID, false)
  local seen, list = {}, {}

  -- 1) Ta med alle spells manuelt lagt i Top Bar
  for spellID, placement in pairs(placements) do
    if placement == "TOP" then
      table.insert(list, spellID)
      seen[spellID] = true
    end
  end

  -- 2) Ta med alle essential-spells fra snapshot
  if snapshot then
    for spellID, entry in pairs(snapshot) do
      if entry.categories and entry.categories.essential then
        if not seen[spellID] then
          table.insert(list, spellID)
          seen[spellID] = true
        end
      end
    end
  end
  table.sort(list, function(a, b)
    local ia, ib = C_Spell.GetSpellInfo(a), C_Spell.GetSpellInfo(b)
    local na, nb = (ia and ia.name) or tostring(a), (ib and ib.name) or tostring(b)
    if na == nb then return a < b else return na < nb end
  end)

  local order = 1
  if #list == 0 then
    container.empty = {
      type = "description",
      name = "No spells on the Top Bar yet. Use 'Add Spell ID' to add one.",
      order = order,
    }
    return
  end

  -- Build group per spell (inline = true => ingen underkategori i venstremenyen)
  for _, spellID in ipairs(list) do
    local s = C_Spell.GetSpellInfo(spellID)
    local icon = s and s.iconID and ("|T" .. s.iconID .. ":16|t ") or ""
    local name = (s and s.name) or ("Spell " .. spellID)

    -- Linked buffs for denne spellen (vis som klikk-for-å-fjerne)
    local linkedArgs, idx = {}, 1
    local links = addon.db.profile.buffLinks[class] and addon.db.profile.buffLinks[class][specID]
    if links then
      local buffIDs = {}
      for buffID, linkedSpellID in pairs(links) do
        if linkedSpellID == spellID then table.insert(buffIDs, buffID) end
      end
      table.sort(buffIDs)
      for _, buffID in ipairs(buffIDs) do
        local b = C_Spell.GetSpellInfo(buffID)
        local bi = b and b.iconID and ("|T" .. b.iconID .. ":16|t ") or ""
        local bn = (b and b.name) or ("Buff " .. buffID)
        linkedArgs["b" .. buffID] = {
          type  = "execute",
          name  = bi .. bn .. " (" .. buffID .. ")",
          desc  = "Click to remove this link",
          order = idx,
          func  = function()
            addon.db.profile.buffLinks[class][specID][buffID] = nil
            BuildTopBarSpellsEditor(addon, container)
            addon:BuildFramesForSpec()
            local ACR = LibStub("AceConfigRegistry-3.0", true)
            if ACR then ACR:NotifyChange("ClassHUD") end
          end,
        }
        idx = idx + 1
      end
    end
    if idx == 1 then
      linkedArgs.none = { type = "description", name = "No linked buffs yet.", order = 1 }
    end

    container["spell" .. spellID] = {
      type   = "group",
      name   = icon .. name .. " (" .. spellID .. ")",
      inline = true,
      order  = order,
      args   = {
        addBuff = {
          type  = "input",
          name  = "Add Buff ID",
          order = 1,
          width = "half",
          get   = function() return "" end,
          set   = function(_, val)
            local buffID = tonumber(val); if not buffID then return end
            addon.db.profile.buffLinks[class] = addon.db.profile.buffLinks[class] or {}
            addon.db.profile.buffLinks[class][specID] = addon.db.profile.buffLinks[class][specID] or {}
            addon.db.profile.buffLinks[class][specID][buffID] = spellID
            BuildTopBarSpellsEditor(addon, container)
            addon:BuildFramesForSpec()
            local ACR = LibStub("AceConfigRegistry-3.0", true)
            if ACR then ACR:NotifyChange("ClassHUD") end
          end,
        },
        linked = {
          type   = "group",
          name   = "Linked Buffs",
          order  = 2,
          inline = true,
          args   = linkedArgs,
        },
        removeSpell = {
          type    = "execute",
          name    = "Remove Spell",
          confirm = true,
          order   = 99,
          func    = function()
            -- Fjern selve spellen fra Top Bar
            addon.db.profile.utilityPlacement[class][specID][spellID] = nil
            -- Fjern alle buff-links som pekte på den
            local bl = addon.db.profile.buffLinks[class] and addon.db.profile.buffLinks[class][specID]
            if bl then
              for bid, sid in pairs(bl) do
                if sid == spellID then bl[bid] = nil end
              end
            end
            BuildTopBarSpellsEditor(addon, container)
            addon:BuildFramesForSpec()
            local ACR = LibStub("AceConfigRegistry-3.0", true)
            if ACR then ACR:NotifyChange("ClassHUD") end
          end,
        },
      },
    }
    order = order + 1
  end
end


local function BuildPlacementArgs(addon, container, category, defaultPlacement, emptyText)
  for k in pairs(container) do container[k] = nil end

  local class, specID = addon:GetPlayerClassSpec()
  addon.db.profile.utilityPlacement[class] = addon.db.profile.utilityPlacement[class] or {}
  addon.db.profile.utilityPlacement[class][specID] = addon.db.profile.utilityPlacement[class][specID] or {}

  local class, specID = addon:GetPlayerClassSpec()
  addon.db.profile.utilityPlacement[class] = addon.db.profile.utilityPlacement[class] or {}
  addon.db.profile.utilityPlacement[class][specID] = addon.db.profile.utilityPlacement[class][specID] or {}

  local placements = addon.db.profile.utilityPlacement[class][specID]


  local snapshot = addon:GetSnapshotForSpec(nil, nil, false)
  local list = SortEntries(snapshot, category)
  local order = 1
  local added = {}

  local function addOption(spellID, entry)
    added[spellID] = true

    local iconID = entry and entry.iconID
    local name = entry and entry.name

    if not name then
      local info = C_Spell.GetSpellInfo(spellID)
      iconID = iconID or (info and info.iconID)
      name = info and info.name or ("Spell " .. spellID)
    end

    local icon = iconID and ("|T" .. iconID .. ":16|t ") or ""

    -- Sjekk om noen buffLinks peker på denne spellen
    local class, specID = addon:GetPlayerClassSpec()
    local linkedBuffs = {}
    if addon.db.profile.buffLinks[class] and addon.db.profile.buffLinks[class][specID] then
      for buffID, linkedSpellID in pairs(addon.db.profile.buffLinks[class][specID]) do
        if linkedSpellID == spellID then
          local buffInfo = C_Spell.GetSpellInfo(buffID)
          table.insert(linkedBuffs, (buffInfo and buffInfo.name) or ("Buff " .. buffID))
        end
      end
    end

    local linkNote
    if #linkedBuffs > 0 then
      linkNote = "|cff00ff00Linked Buffs:|r " .. table.concat(linkedBuffs, ", ")
    end

    container["spell" .. spellID] = {
      type = "select",
      name = icon .. name .. " (" .. spellID .. ")",
      desc = linkNote, -- 👈 viser link-informasjon i tooltip
      order = order,
      values = PLACEMENTS,
      get = function()
        return placements[spellID] or defaultPlacement
      end,
      set = function(_, value)
        if value == defaultPlacement then
          placements[spellID] = nil
        else
          placements[spellID] = value
        end
        addon:BuildFramesForSpec()
        BuildPlacementArgs(addon, container, category, defaultPlacement, emptyText)
        NotifyOptionsChanged()
      end,
    }


    order = order + 1
  end

  for _, item in ipairs(list) do
    addOption(item.spellID, item.entry)
  end

  if category == "essential" then
    for spellID, placement in pairs(placements) do
      if placement == "TOP" and not added[spellID] then
        local entry = snapshot and snapshot[spellID]
        addOption(spellID, entry)
      end
    end
  end

  if category == "utility" then
    for spellID, _ in pairs(placements) do
      if not added[spellID] then
        local entry = snapshot and snapshot[spellID] -- kan være nil
        addOption(spellID, entry)
      end
    end
  end

  if order == 1 then
    container.empty = {
      type = "description",
      name = emptyText or "No entries available for this category.",
      order = order,
    }
  end
end

local function BuildTrackedBuffArgs(addon, container)
  for k in pairs(container) do container[k] = nil end

  local class, specID = addon:GetPlayerClassSpec()
  local snapshot = addon:GetSnapshotForSpec(class, specID, false)

  addon.db.profile.trackedBuffs[class] = addon.db.profile.trackedBuffs[class] or {}
  addon.db.profile.trackedBuffs[class][specID] = addon.db.profile.trackedBuffs[class][specID] or {}

  local tracked = addon.db.profile.trackedBuffs[class][specID]

  local entries = {}

  if snapshot then
    for spellID, entry in pairs(snapshot) do
      local categories = entry.categories
      local hasBuff = categories and categories.buff
      local hasBar = categories and categories.bar
      if hasBuff or hasBar then
        local order = math.huge
        if hasBuff and hasBuff.order then order = math.min(order, hasBuff.order) end
        if hasBar and hasBar.order then order = math.min(order, hasBar.order) end

        local icon = entry.iconID and ("|T" .. entry.iconID .. ":16|t ") or ""
        local name = entry.name or C_Spell.GetSpellName(spellID) or ("Spell " .. spellID)

        entries[spellID] = {
          buffID = spellID,
          entry = entry,
          icon = icon,
          name = name,
          hasBuff = hasBuff and true or false,
          hasBar = hasBar and true or false,
          order = order,
        }
      end
    end
  end

  for buffID in pairs(tracked) do
    if not entries[buffID] then
      local info = C_Spell.GetSpellInfo(buffID)
      entries[buffID] = {
        buffID = buffID,
        entry = nil,
        icon = info and info.iconID and ("|T" .. info.iconID .. ":16|t ") or "",
        name = info and info.name or ("Spell " .. buffID),
        hasBuff = true,
        hasBar = false,
        order = math.huge,
      }
    end
  end

  local list = {}
  for _, data in pairs(entries) do
    table.insert(list, data)
  end

  table.sort(list, function(a, b)
    if a.order == b.order then
      return a.name < b.name
    end
    return a.order < b.order
  end)

  if #list == 0 then
    container.empty = {
      type = "description",
      name = "No tracked buffs or bars available for this specialization.",
      order = 1,
    }
    return
  end

  local order = 1
  for _, data in ipairs(list) do
    local buffID = data.buffID
    local header = string.format("%s%s (%d)", data.icon or "", data.name or ("Spell " .. buffID), buffID)

    local function getConfig(create)
      return addon:GetTrackedEntryConfig(class, specID, buffID, create)
    end

    container["buff" .. buffID] = {
      type = "group",
      name = header,
      inline = true,
      order = order,
      args = {
        showIcon = {
          type = "toggle",
          name = "Show as Icon",
          order = 1,
          get = function()
            local cfg = getConfig(false)
            return cfg and cfg.showIcon or false
          end,
          set = function(_, value)
            local cfg = getConfig(true)
            cfg.showIcon = not not value
            addon:BuildTrackedBuffFrames()
            BuildTrackedBuffArgs(addon, container)
            NotifyOptionsChanged()
          end,
        },
        barShowIcon = {
          type = "toggle",
          name = "Show Icon",
          order = 3,
          hidden = function()
            local cfg = getConfig(false)
            return not (data.hasBar and cfg and cfg.showBar)
          end,
          get = function()
            local cfg = getConfig(false)
            return not cfg or cfg.barShowIcon ~= false
          end,
          set = function(_, value)
            local cfg = getConfig(true)
            cfg.barShowIcon = not not value
            addon:BuildTrackedBuffFrames()
            NotifyOptionsChanged()
          end,
        },
        barColor = {
          type = "color",
          name = "Bar Color",
          order = 4,
          hasAlpha = true,
          hidden = function()
            local cfg = getConfig(false)
            return not (data.hasBar and cfg and cfg.showBar)
          end,
          get = function()
            local cfg = getConfig(false)
            local color = (cfg and cfg.barColor) or addon:GetDefaultTrackedBarColor()
            return color.r, color.g, color.b, color.a or 1
          end,
          set = function(_, r, g, b, a)
            local cfg = getConfig(true)
            cfg.barColor = { r = r, g = g, b = b, a = a or 1 }
            addon:BuildTrackedBuffFrames()
            NotifyOptionsChanged()
          end,
        },
        barTimer = {
          type = "toggle",
          name = "Show Timer",
          order = 5,
          hidden = function()
            local cfg = getConfig(false)
            return not (data.hasBar and cfg and cfg.showBar)
          end,
          get = function()
            local cfg = getConfig(false)
            return not cfg or cfg.barShowTimer ~= false
          end,
          set = function(_, value)
            local cfg = getConfig(true)
            cfg.barShowTimer = not not value
            addon:BuildTrackedBuffFrames()
            NotifyOptionsChanged()
          end,
        },
      },
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
      name =
      "No manual links stored for this spec. They are created automatically when buffs reference spells in their description.",
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
        buff = {
          type = "input",
          name = "Buff ID",
          width = "half",
          order = 1,
          get = function() return tostring(map.buffID) end,
          set = function(_, value)
            local newID = tonumber(value)
            if newID and newID ~= map.buffID then
              local current = addon.db.profile.buffLinks[class][specID][map.buffID]
              addon.db.profile.buffLinks[class][specID][map.buffID] = nil
              addon.db.profile.buffLinks[class][specID][newID] = current
              addon:BuildFramesForSpec()
              BuildBuffLinkArgs(addon, container)
              NotifyOptionsChanged()
            end
          end,
        },
        spell = {
          type = "input",
          name = "Spell ID",
          width = "half",
          order = 2,
          get = function() return tostring(map.spellID) end,
          set = function(_, value)
            local newID = tonumber(value)
            if newID then
              addon.db.profile.buffLinks[class][specID][map.buffID] = newID
              addon:BuildFramesForSpec()
              BuildBuffLinkArgs(addon, container)
              NotifyOptionsChanged()
            end
          end,
        },
        remove = {
          type = "execute",
          name = "Remove",
          confirm = true,
          order = 3,
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

local function BuildBarOrderEditor(addon, container)
  for k in pairs(container) do container[k] = nil end

  local db = addon.db
  local order = addon.GetBarOrder and addon:GetBarOrder() or { "top", "cast", "health", "resource", "class", "bottom" }
  db.profile.barOrder = { unpack(order) }

  local LABELS = {
    top      = "Top Bar",
    cast     = "Cast Bar",
    health   = "Health Bar",
    resource = "Primary Resource",
    class    = "Class Resource",
    bottom   = "Bottom Bar",
  }

  for index, key in ipairs(db.profile.barOrder) do
    local label = LABELS[key] or key

    container["row" .. index] = {
      type   = "group",
      name   = label,
      inline = true,
      order  = index,
      args   = {
        up = {
          type     = "execute",
          name     = "↑",
          width    = "half",
          disabled = (index == 1),
          func     = function()
            local list = db.profile.barOrder
            list[index], list[index - 1] = list[index - 1], list[index]
            addon:FullUpdate()
            BuildBarOrderEditor(addon, container)
            NotifyOptionsChanged()
          end,
        },
        down = {
          type     = "execute",
          name     = "↓",
          width    = "half",
          disabled = (index == #db.profile.barOrder),
          func     = function()
            local list = db.profile.barOrder
            list[index], list[index + 1] = list[index + 1], list[index]
            addon:FullUpdate()
            BuildBarOrderEditor(addon, container)
            NotifyOptionsChanged()
          end,
        },
      },
    }
  end
end


function ClassHUD_BuildOptions(addon)
  local db = addon.db

  if addon.SanitizeBarProfile then
    addon:SanitizeBarProfile()
  end

  db.profile.textures = db.profile.textures or { bar = "Blizzard", font = "Friz Quadrata TT" }
  db.profile.show = db.profile.show or { cast = true, hp = true, resource = true, power = true, buffs = true }
  if db.profile.show.class == nil and db.profile.show.power ~= nil then
    db.profile.show.class = db.profile.show.power
  end
  db.profile.height = db.profile.height or { cast = 18, hp = 14, resource = 14, class = 14 }
  db.profile.height.class = db.profile.height.class or db.profile.height.power or 14
  db.profile.height.power = nil
  db.profile.colors = db.profile.colors or {
    hp = { r = 0.10, g = 0.80, b = 0.10 },
    resourceClass = true,
    resource = { r = 0.00, g = 0.55, b = 1.00 },
    class = { r = 1.00, g = 0.85, b = 0.10 },
  }
  if db.profile.colors.class == nil and db.profile.colors.power then
    db.profile.colors.class = {
      r = db.profile.colors.power.r,
      g = db.profile.colors.power.g,
      b = db.profile.colors.power.b,
    }
  end
  db.profile.position = db.profile.position or { x = 0, y = -50 }
  db.profile.position.x = db.profile.position.x or 0
  db.profile.position.y = db.profile.position.y or -50
  db.profile.topBar = db.profile.topBar or {}
  db.profile.topBar.perRow = db.profile.topBar.perRow or 8
  db.profile.topBar.spacingX = db.profile.topBar.spacingX or 4
  db.profile.topBar.spacingY = db.profile.topBar.spacingY or 4
  db.profile.topBar.yOffset = db.profile.topBar.yOffset or 0
  db.profile.topBar.grow = db.profile.topBar.grow or "UP"
  db.profile.bottomBar = db.profile.bottomBar or {}
  db.profile.bottomBar.perRow = db.profile.bottomBar.perRow or 8
  db.profile.bottomBar.spacingX = db.profile.bottomBar.spacingX or 4
  db.profile.bottomBar.spacingY = db.profile.bottomBar.spacingY or 4
  db.profile.bottomBar.yOffset = db.profile.bottomBar.yOffset or 0
  db.profile.sideBars = db.profile.sideBars or {}
  db.profile.sideBars.size = db.profile.sideBars.size or 36
  db.profile.sideBars.spacing = db.profile.sideBars.spacing or 4
  db.profile.sideBars.offset = db.profile.sideBars.offset or 6
  db.profile.sideBars.yOffset = db.profile.sideBars.yOffset or 0
  db.profile.trackedBuffBar = db.profile.trackedBuffBar or {}
  db.profile.trackedBuffBar.perRow = db.profile.trackedBuffBar.perRow or 8
  db.profile.trackedBuffBar.spacingX = db.profile.trackedBuffBar.spacingX or 4
  db.profile.trackedBuffBar.spacingY = db.profile.trackedBuffBar.spacingY or 4
  db.profile.trackedBuffBar.yOffset = db.profile.trackedBuffBar.yOffset or 4
  db.profile.trackedBuffBar.align = db.profile.trackedBuffBar.align or "CENTER"
  db.profile.trackedBuffBar.height = db.profile.trackedBuffBar.height or 16
  db.profile.utilityPlacement = db.profile.utilityPlacement or {}
  db.profile.trackedBuffs = db.profile.trackedBuffs or {}
  db.profile.buffLinks = db.profile.buffLinks or {}

  local topBarEditorContainer = {}
  local utilityContainer = {}
  local trackedContainer = {}
  local linkContainer = {}
  local barOrderContainer = {}

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
          positionX = {
            type = "range",
            name = "Position X",
            order = 3,
            min = -1000,
            max = 1000,
            step = 1,
            get = function() return db.profile.position.x or 0 end,
            set = function(_, value)
              db.profile.position.x = value
              addon:ApplyAnchorPosition()
            end,
          },
          positionY = {
            type = "range",
            name = "Position Y",
            order = 4,
            min = -1000,
            max = 1000,
            step = 1,
            get = function() return db.profile.position.y or 0 end,
            set = function(_, value)
              db.profile.position.y = value
              addon:ApplyAnchorPosition()
            end,
          },
          spacing = {
            type = "range",
            name = "Bar Spacing",
            min = 0,
            max = 12,
            step = 1,
            order = 5,
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
            order = 6,
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
            order = 7,
            values = LSM and LSM:HashTable("font") or {},
            get = function() return db.profile.textures.font end,
            set = function(_, value)
              db.profile.textures.font = value
              addon:FullUpdate()
              addon:BuildFramesForSpec()
            end,
          },
          bars = {
            type = "group",
            name = "Bars",
            order = 2,
            inline = true,
            args = {
              order = {
                type   = "group",
                name   = "Bar Order",
                inline = true,
                order  = 30,
                args   = barOrderContainer,
              },
            },
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
            name = "Show Class Resource",
            order = 4,
            get = function()
              if db.profile.show.class ~= nil then
                return db.profile.show.class
              end
              return db.profile.show.power
            end,
            set = function(_, value)
              db.profile.show.power = value
              db.profile.show.class = value
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
          borderColor = {
            type = "color",
            name = "Bar Border Color",
            order = 10,
            hasAlpha = true,
            get = function()
              return db.profile.borderColor.r, db.profile.borderColor.g, db.profile.borderColor.b,
                  db.profile.borderColor.a
            end,
            set = function(_, r, g, b, a)
              db.profile.borderColor = { r = r, g = g, b = b, a = a }
              addon:ApplyBarSkins()
            end,
          },
          spellFontSize = {
            type = "range",
            name = "Spell Text Size",
            min = 8,
            max = 24,
            step = 1,
            order = 8,
            get = function() return db.profile.spellFontSize or 12 end,
            set = function(_, v)
              db.profile.spellFontSize = v
              addon:BuildFramesForSpec()
            end,
          },
          buffFontSize = {
            type = "range",
            name = "Buff Text Size",
            min = 8,
            max = 24,
            step = 1,
            order = 9,
            get = function() return db.profile.buffFontSize or 12 end,
            set = function(_, v)
              db.profile.buffFontSize = v
              addon:BuildFramesForSpec()
            end,
          },
          trackedBarHeight = {
            type = "range",
            name = "Tracked Bar Height",
            order = 6,
            min = 8,
            max = 40,
            step = 1,
            get = function() return db.profile.trackedBuffBar.height or 16 end,
            set = function(_, value)
              db.profile.trackedBuffBar.height = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          spacing = {
            type = "range",
            name = "Vertical Spacing",
            min = 0,
            max = 30,
            step = 1,
            order = 5,
            get = function() return db.profile.spacing or 2 end,
            set = function(_, value)
              db.profile.spacing = value
              addon:FullUpdate()
              addon:BuildFramesForSpec()
            end,
          },

          powerSpacing = {
            type = "range",
            name = "Power Spacing",
            order = 7,
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
            order = 8,
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
            order = 9,
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
            order = 10,
            min = 8,
            max = 40,
            step = 1,
            get = function() return db.profile.height.resource end,
            set = function(_, value)
              db.profile.height.resource = value
              addon:FullUpdate()
            end,
          },
          heightClass = {
            type = "range",
            name = "Class Resource Height",
            order = 11,
            min = 8,
            max = 40,
            step = 1,
            get = function() return db.profile.height.class end,
            set = function(_, value)
              db.profile.height.class = value
              addon:FullUpdate()
            end,
          },
          topLayout = {
            type = "group",
            name = "Top Bar Layout",
            order = 20,
            inline = true,
            args = {
              perRow = {
                type = "range",
                name = "Spells per Row",
                order = 1,
                min = 1,
                max = 12,
                step = 1,
                get = function() return db.profile.topBar.perRow end,
                set = function(_, value)
                  db.profile.topBar.perRow = value
                  addon:BuildFramesForSpec()
                end,
              },
              spacingX = {
                type = "range",
                name = "Horizontal Spacing",
                order = 2,
                min = 0,
                max = 20,
                step = 1,
                get = function() return db.profile.topBar.spacingX end,
                set = function(_, value)
                  db.profile.topBar.spacingX = value
                  addon:BuildFramesForSpec()
                end,
              },
              spacingY = {
                type = "range",
                name = "Vertical Spacing",
                order = 3,
                min = 0,
                max = 20,
                step = 1,
                get = function() return db.profile.topBar.spacingY end,
                set = function(_, value)
                  db.profile.topBar.spacingY = value
                  addon:BuildFramesForSpec()
                end,
              },
              yOffset = {
                type = "range",
                name = "Vertical Offset",
                order = 4,
                min = -100,
                max = 100,
                step = 1,
                get = function() return db.profile.topBar.yOffset end,
                set = function(_, value)
                  db.profile.topBar.yOffset = value
                  addon:BuildFramesForSpec()
                end,
              },
            },
          },
          bottomLayout = {
            type = "group",
            name = "Bottom Bar Layout",
            order = 21,
            inline = true,
            args = {
              perRow = {
                type = "range",
                name = "Spells per Row",
                order = 1,
                min = 1,
                max = 12,
                step = 1,
                get = function() return db.profile.bottomBar.perRow end,
                set = function(_, value)
                  db.profile.bottomBar.perRow = value
                  addon:BuildFramesForSpec()
                end,
              },
              spacingX = {
                type = "range",
                name = "Horizontal Spacing",
                order = 2,
                min = 0,
                max = 20,
                step = 1,
                get = function() return db.profile.bottomBar.spacingX end,
                set = function(_, value)
                  db.profile.bottomBar.spacingX = value
                  addon:BuildFramesForSpec()
                end,
              },
              spacingY = {
                type = "range",
                name = "Vertical Spacing",
                order = 3,
                min = 0,
                max = 20,
                step = 1,
                get = function() return db.profile.bottomBar.spacingY end,
                set = function(_, value)
                  db.profile.bottomBar.spacingY = value
                  addon:BuildFramesForSpec()
                end,
              },
              yOffset = {
                type = "range",
                name = "Vertical Offset",
                order = 4,
                min = -100,
                max = 100,
                step = 1,
                get = function() return db.profile.bottomBar.yOffset end,
                set = function(_, value)
                  db.profile.bottomBar.yOffset = value
                  addon:BuildFramesForSpec()
                end,
              },
            },
          },
          sideLayout = {
            type = "group",
            name = "Side Bars",
            order = 22,
            inline = true,
            args = {
              size = {
                type = "range",
                name = "Icon Size",
                order = 1,
                min = 24,
                max = 80,
                step = 1,
                get = function() return db.profile.sideBars.size end,
                set = function(_, value)
                  db.profile.sideBars.size = value
                  addon:BuildFramesForSpec()
                end,
              },
              spacing = {
                type = "range",
                name = "Spacing",
                order = 2,
                min = 0,
                max = 20,
                step = 1,
                get = function() return db.profile.sideBars.spacing end,
                set = function(_, value)
                  db.profile.sideBars.spacing = value
                  addon:BuildFramesForSpec()
                end,
              },
              offset = {
                type = "range",
                name = "Offset",
                order = 3,
                min = -200,
                max = 200,
                step = 1,
                get = function() return db.profile.sideBars.offset end,
                set = function(_, value)
                  db.profile.sideBars.offset = value
                  addon:BuildFramesForSpec()
                end,
              },
              yOffset = {
                type = "range",
                name = "Sidebar Y-Offset",
                order = 4,
                min = -200,
                max = 200,
                step = 1,
                get = function() return db.profile.sideBars.yOffset or 0 end,
                set = function(_, value)
                  db.profile.sideBars.yOffset = value
                  addon:BuildFramesForSpec()
                end,
              },
            },
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
          classColor = {
            type = "color",
            name = "Class Resource",
            order = 4,
            get = function()
              local c = db.profile.colors.class
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.profile.colors.class = { r = r, g = g, b = b }
              addon:UpdateClassBar()
            end,
          },
        },
      },
      spells = {
        type = "group",
        name = "Spells & Buffs",
        order = 4,
        args = {
          -- topBar = {
          --   type = "group",
          --   name = "Top Bar Spells",
          --   order = 1,
          --   args = {
          --     description = {
          --       type = "description",
          --       name = "Assign essential abilities to HUD positions.",
          --       order = 1,
          --     },
          --     addSpell = {
          --       type = "input",
          --       name = "Add Spell ID",
          --       order = 2,
          --       width = "half",
          --       get = function() return "" end,
          --       set = function(_, value)
          --         local spellID = tonumber(value)
          --         if not spellID then return end
          --         local class, specID = addon:GetPlayerClassSpec()
          --         addon.db.profile.utilityPlacement[class] = addon.db.profile.utilityPlacement[class] or {}
          --         addon.db.profile.utilityPlacement[class][specID] = addon.db.profile.utilityPlacement[class][specID] or
          --             {}
          --         addon.db.profile.utilityPlacement[class][specID][spellID] = "TOP"

          --         addon:BuildFramesForSpec()
          --         BuildPlacementArgs(addon, topBarContainer, "essential", "TOP",
          --           "No essential spells reported for this spec.")
          --         NotifyOptionsChanged()
          --       end,
          --     },
          --     list = {
          --       type = "group",
          --       name = "Assignments",
          --       inline = true,
          --       order = 3,
          --       args = topBarContainer,
          --     },
          --   },
          -- },
          topBar = {
            type  = "group",
            name  = "Top Bar Spells",
            order = 1,
            args  = {
              description = {
                type  = "description",
                name  = "Manage spells that appear on the Top Bar and link buffs directly to them.",
                order = 1,
              },
              addSpell = {
                type  = "input",
                name  = "Add Spell ID",
                order = 2,
                width = "half",
                get   = function() return "" end,
                set   = function(_, value)
                  local spellID = tonumber(value)
                  if not spellID then return end
                  local class, specID = addon:GetPlayerClassSpec()
                  addon.db.profile.utilityPlacement[class] = addon.db.profile.utilityPlacement[class] or {}
                  addon.db.profile.utilityPlacement[class][specID] = addon.db.profile.utilityPlacement[class][specID] or
                      {}
                  addon.db.profile.utilityPlacement[class][specID][spellID] = "TOP"
                  BuildTopBarSpellsEditor(addon, topBarEditorContainer)
                  addon:BuildFramesForSpec()
                  local ACR = LibStub("AceConfigRegistry-3.0", true)
                  if ACR then ACR:NotifyChange("ClassHUD") end
                end,
              },
              editor = {
                type   = "group",
                name   = "",   -- tomt navn = ingen label
                order  = 3,
                inline = true, -- VIKTIG: ingen ny venstremeny-node
                args   = topBarEditorContainer,
              },
            },
          },


          utility = {
            type = "group",
            name = "Utility Placement",
            order = 2,
            args = {
              addSpell = {
                type = "input",
                name = "Add Spell ID",
                order = 1,
                width = "half",
                get = function() return "" end,
                set = function(_, value)
                  local spellID = tonumber(value)
                  if not spellID then return end
                  local class, specID = addon:GetPlayerClassSpec()
                  addon.db.profile.utilityPlacement[class] = addon.db.profile.utilityPlacement[class] or {}
                  addon.db.profile.utilityPlacement[class][specID] = addon.db.profile.utilityPlacement[class][specID] or
                      {}
                  addon.db.profile.utilityPlacement[class][specID][spellID] = "HIDDEN"
                  addon:BuildFramesForSpec()
                  BuildPlacementArgs(addon, utilityContainer, "utility", "HIDDEN",
                    "No utility cooldowns reported by the snapshot for this spec.")
                  NotifyOptionsChanged()
                end,
              },
              list = {
                type = "group",
                name = "Spells",
                inline = true,
                order = 2,
                args = utilityContainer,
              },
            },
          },
          trackedBuffs = {
            type = "group",
            name = "Tracked Buffs & Bars",
            order = 3,
            args = {
              description = {
                type = "description",
                name = "Configure which Blizzard tracked buffs and cooldown bars appear in the HUD.",
                order = 1,
              },
              addBuff = {
                type = "input",
                name = "Add Buff ID",
                order = 2,
                width = "half",
                get = function() return "" end,
                set = function(_, value)
                  local buffID = tonumber(value)
                  if not buffID then return end
                  local class, specID = addon:GetPlayerClassSpec()
                  addon.db.profile.trackedBuffs[class] = addon.db.profile.trackedBuffs[class] or {}
                  addon.db.profile.trackedBuffs[class][specID] = addon.db.profile.trackedBuffs[class][specID] or {}
                  addon.db.profile.trackedBuffs[class][specID][buffID] = true
                  addon:BuildTrackedBuffFrames()
                  BuildTrackedBuffArgs(addon, trackedContainer)
                  NotifyOptionsChanged()
                end,
              },
              list = {
                type = "group",
                name = "Entries",
                inline = true,
                order = 3,
                args = trackedContainer,
              },
            },
          },
          -- buffLinks = {
          --   type = "group",
          --   name = "Buff Links",
          --   order = 4,
          --   args = {
          --     description = {
          --       type = "description",
          --       name = "Manual overrides linking a buff to a spell. These are populated automatically when possible.",
          --       order = 1,
          --     },
          --     list = {
          --       type = "group",
          --       name = "Links",
          --       inline = true,
          --       order = 2,
          --       args = linkContainer,
          --     },
          --     add = {
          --       type = "group",
          --       name = "Add New Link",
          --       inline = true,
          --       order = 3,
          --       args = {
          --         buffID = {
          --           type = "input",
          --           name = "Buff ID",
          --           order = 1,
          --           width = "half",
          --           get = function() return optionsState.newLinkBuffID end,
          --           set = function(_, value)
          --             optionsState.newLinkBuffID = value or ""
          --           end,
          --         },
          --         spellID = {
          --           type = "input",
          --           name = "Spell ID",
          --           order = 2,
          --           width = "half",
          --           get = function() return optionsState.newLinkSpellID end,
          --           set = function(_, value)
          --             optionsState.newLinkSpellID = value or ""
          --           end,
          --         },
          --         addButton = {
          --           type = "execute",
          --           name = "Add Link",
          --           order = 3,
          --           func = function()
          --             local buffID = tonumber(optionsState.newLinkBuffID)
          --             local spellID = tonumber(optionsState.newLinkSpellID)
          --             if not (buffID and spellID) then return end
          --             local class, specID = addon:GetPlayerClassSpec()
          --             addon.db.profile.buffLinks[class] = addon.db.profile.buffLinks[class] or {}
          --             addon.db.profile.buffLinks[class][specID] = addon.db.profile.buffLinks[class][specID] or {}
          --             addon.db.profile.buffLinks[class][specID][buffID] = spellID
          --             addon:BuildFramesForSpec()
          --             BuildBuffLinkArgs(addon, linkContainer)
          --             optionsState.newLinkBuffID = ""
          --             optionsState.newLinkSpellID = ""
          --             NotifyOptionsChanged()
          --           end,
          --         },
          --       },
          --     },
          --   },
          -- },
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
              BuildTopBarSpellsEditor(addon, topBarEditorContainer)
              BuildPlacementArgs(addon, utilityContainer, "utility", "HIDDEN",
                "No utility cooldowns reported by the snapshot for this spec.")
              BuildTrackedBuffArgs(addon, trackedContainer)
              BuildBuffLinkArgs(addon, linkContainer)
              NotifyOptionsChanged()
            end,
          },
          note = {
            type = "description",
            order = 2,
            name =
            "The snapshot is rebuilt automatically on login and specialization changes. Use this button if Blizzard updates the Cooldown Viewer data while you are logged in.",
          },
        },
      },
    },
  }

  BuildTopBarSpellsEditor(addon, topBarEditorContainer)
  BuildPlacementArgs(addon, utilityContainer, "utility", "HIDDEN",
    "No utility cooldowns reported by the snapshot for this spec.")
  BuildTrackedBuffArgs(addon, trackedContainer)
  BuildBuffLinkArgs(addon, linkContainer)
  BuildBarOrderEditor(addon, barOrderContainer)

  return opts
end

function ClassHUD:GetUtilityOptions()
  local container = {}
  BuildPlacementArgs(self, container, "utility", "HIDDEN", "No utility cooldowns reported by the snapshot for this spec.")
  return {
    type = "group",
    name = "Utility Cooldowns",
    args = container,
  }
end
