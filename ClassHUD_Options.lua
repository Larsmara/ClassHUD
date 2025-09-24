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

local SUMMON_CLASS_CONFIG = {
  { class = "PRIEST",      label = "Priest Summons",      spells = { 34433, 123040 } },
  { class = "WARLOCK",     label = "Warlock Summons",     spells = { 193332, 264119, 455476, 265187, 111898, 205180 } },
  { class = "DEATHKNIGHT", label = "Death Knight Summons", spells = { 42650, 49206 } },
  { class = "DRUID",       label = "Druid Summons",       spells = { 205636 } },
  { class = "MONK",        label = "Monk Summons",        spells = { 115313 } },
}

local TOTEM_OVERLAY_OPTIONS = {
  SWIPE = "Cooldown swipe",
  GLOW  = "Glow",
}

local WILD_IMP_MODE_OPTIONS = {
  implosion = "Implosion Counter",
  buff = "Buff Icon",
}

local function PlayerMatchesClass(addon, class)
  if not class then return false end
  local playerClass = select(1, addon:GetPlayerClassSpec())
  if not playerClass or playerClass == "" then
    playerClass = UnitClass and select(2, UnitClass("player")) or nil
  end
  return playerClass == class
end

local function PlayerMatchesSpec(addon, class, specID)
  if not class then return false end
  local playerClass, playerSpec = addon:GetPlayerClassSpec()
  if not playerClass or playerClass == "" then
    playerClass = UnitClass and select(2, UnitClass("player")) or nil
  end
  if playerClass ~= class then
    return false
  end
  if specID and specID ~= 0 then
    return playerSpec == specID
  end
  return true
end

local function EnsureSummonConfig(addon, class)
  addon.db.profile.tracking = addon.db.profile.tracking or {}
  addon.db.profile.tracking.summons = addon.db.profile.tracking.summons or {}
  addon.db.profile.tracking.summons.byClass = addon.db.profile.tracking.summons.byClass or {}
  addon.db.profile.tracking.summons.byClass[class] = addon.db.profile.tracking.summons.byClass[class] or {}
  return addon.db.profile.tracking.summons.byClass[class]
end

local function EnsureBuffTracking(addon, class, specID)
  addon.db.profile.tracking = addon.db.profile.tracking or {}
  addon.db.profile.tracking.buffs = addon.db.profile.tracking.buffs or {}
  local buffs = addon.db.profile.tracking.buffs

  buffs.tracked = buffs.tracked or {}
  buffs.links = buffs.links or {}

  buffs.tracked[class] = buffs.tracked[class] or {}
  buffs.tracked[class][specID] = buffs.tracked[class][specID] or {}

  buffs.links[class] = buffs.links[class] or {}
  buffs.links[class][specID] = buffs.links[class][specID] or {}

  return buffs.tracked[class][specID], buffs.links[class][specID]
end

local function EnsureTrackedBuffOrder(addon, class, specID)
  addon.db.profile.layout = addon.db.profile.layout or {}
  addon.db.profile.layout.trackedBuffBar = addon.db.profile.layout.trackedBuffBar or {}
  local trackedBuffBar = addon.db.profile.layout.trackedBuffBar

  trackedBuffBar.buffs = trackedBuffBar.buffs or {}
  trackedBuffBar.buffs[class] = trackedBuffBar.buffs[class] or {}
  trackedBuffBar.buffs[class][specID] = trackedBuffBar.buffs[class][specID] or {}

  return trackedBuffBar.buffs[class][specID]
end

local function GetTrackedBuffOrder(addon, class, specID, buffID)
  local orderList = EnsureTrackedBuffOrder(addon, class, specID)
  for index = 1, #orderList do
    local value = tonumber(orderList[index]) or orderList[index]
    if value == buffID then
      return index, orderList
    end
  end
  return nil, orderList
end

local function SetTrackedBuffOrder(addon, class, specID, buffID, position)
  local orderList = EnsureTrackedBuffOrder(addon, class, specID)
  for index = #orderList, 1, -1 do
    local value = tonumber(orderList[index]) or orderList[index]
    if value == buffID then
      table.remove(orderList, index)
      break
    end
  end

  local target = math.max(1, math.min(position, #orderList + 1))
  table.insert(orderList, target, buffID)
end

local function RemoveTrackedBuff(addon, class, specID, buffID)
  local tracked, links = EnsureBuffTracking(addon, class, specID)
  local orderList = EnsureTrackedBuffOrder(addon, class, specID)
  tracked[buffID] = nil
  links[buffID] = nil
  for index = #orderList, 1, -1 do
    local value = tonumber(orderList[index]) or orderList[index]
    if value == buffID then
      table.remove(orderList, index)
    end
  end
end

local function EnsurePlacementLists(addon, class, specID)
  addon.db.profile.layout = addon.db.profile.layout or {}
  local layout = addon.db.profile.layout
  layout.topBar = layout.topBar or {}
  layout.topBar.spells = layout.topBar.spells or {}
  layout.bottomBar = layout.bottomBar or {}
  layout.bottomBar.spells = layout.bottomBar.spells or {}
  layout.sideBars = layout.sideBars or {}
  layout.sideBars.spells = layout.sideBars.spells or {}
  layout.hiddenSpells = layout.hiddenSpells or {}

  local function ensure(root)
    root[class] = root[class] or {}
    root[class][specID] = root[class][specID] or {}
    return root[class][specID]
  end

  local topList = ensure(layout.topBar.spells)
  local bottomList = ensure(layout.bottomBar.spells)
  local sideSpec = ensure(layout.sideBars.spells)
  sideSpec.left = sideSpec.left or {}
  sideSpec.right = sideSpec.right or {}
  local hiddenList = ensure(layout.hiddenSpells)

  return {
    TOP = topList,
    BOTTOM = bottomList,
    LEFT = sideSpec.left,
    RIGHT = sideSpec.right,
    HIDDEN = hiddenList,
  }
end

local function RemoveSpellFromLists(lists, spellID)
  spellID = tonumber(spellID) or spellID
  for _, list in pairs(lists) do
    if type(list) == "table" then
      for index = #list, 1, -1 do
        if (tonumber(list[index]) or list[index]) == spellID then
          table.remove(list, index)
        end
      end
    end
  end
end

local function GetSpellPlacement(addon, class, specID, spellID)
  spellID = tonumber(spellID) or spellID
  local lists = EnsurePlacementLists(addon, class, specID)
  for name, list in pairs(lists) do
    if type(list) == "table" then
      for index = 1, #list do
        if (tonumber(list[index]) or list[index]) == spellID then
          return name, index, lists
        end
      end
    end
  end
  return nil, nil, lists
end

local function SetSpellPlacement(addon, class, specID, spellID, placement, position)
  spellID = tonumber(spellID) or spellID
  local lists = EnsurePlacementLists(addon, class, specID)
  RemoveSpellFromLists(lists, spellID)
  local target = lists[placement]
  if not target then return end
  local insertIndex = tonumber(position)
  if insertIndex and insertIndex >= 1 and insertIndex <= (#target + 1) then
    table.insert(target, insertIndex, spellID)
  else
    target[#target + 1] = spellID
  end
end

local function SetSpellOrder(addon, class, specID, spellID, order)
  spellID = tonumber(spellID) or spellID
  local placement, _, lists = GetSpellPlacement(addon, class, specID, spellID)
  if not placement then
    placement = "TOP"
    lists = EnsurePlacementLists(addon, class, specID)
  end
  local target = lists[placement]
  if not target then return end
  RemoveSpellFromLists(lists, spellID)
  local index = math.max(1, math.min(tonumber(order) or (#target + 1), #target + 1))
  table.insert(target, index, spellID)
end

local function BuildSummonSpellArgs(addon, classConfig)
  local args = {}
  for index, spellID in ipairs(classConfig.spells) do
    local info = C_Spell.GetSpellInfo(spellID)
    local name = (info and info.name) or ("Spell " .. spellID)
    local icon = info and info.iconID and ("|T" .. info.iconID .. ":16|t ") or ""
    args["spell" .. spellID] = {
      type = "toggle",
      name = icon .. name .. " (" .. spellID .. ")",
      order = index,
      get = function()
        local config = EnsureSummonConfig(addon, classConfig.class)
        local value = config[spellID]
        if value == nil then
          return true
        end
        return value
      end,
      set = function(_, val)
        local config = EnsureSummonConfig(addon, classConfig.class)
        config[spellID] = not not val
        if not val and addon.DeactivateSummonSpell then
          addon:DeactivateSummonSpell(spellID)
        end
        if addon.RefreshTemporaryBuffs then
          addon:RefreshTemporaryBuffs(true)
        end
        NotifyOptionsChanged()
      end,
      disabled = function()
        local tracking = addon.db.profile.tracking
        local summons = tracking and tracking.summons
        return summons and summons.enabled == false
      end,
    }
  end
  return args
end

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
  local snapshot = addon:GetSnapshotForSpec(class, specID, false)

  local lists = EnsurePlacementLists(addon, class, specID)
  local topList = lists.TOP
  local manualIndex = {}
  local ordered = {}

  for idx = #topList, 1, -1 do
    local spellID = tonumber(topList[idx]) or topList[idx]
    if spellID then
      topList[idx] = spellID
      manualIndex[spellID] = idx
      ordered[#ordered + 1] = spellID
    else
      table.remove(topList, idx)
    end
  end

  if snapshot then
    for spellID, entry in pairs(snapshot) do
      if entry.categories and entry.categories.essential then
        if manualIndex[spellID] == nil then
          ordered[#ordered + 1] = spellID
          manualIndex[spellID] = false
        end
      end
    end
  end

  table.sort(ordered, function(a, b)
    local ia = manualIndex[a] or math.huge
    local ib = manualIndex[b] or math.huge
    if ia == ib then
      local sa = snapshot and snapshot[a]
      local sb = snapshot and snapshot[b]
      local oa = sa and sa.categories and sa.categories.essential and sa.categories.essential.order or math.huge
      local ob = sb and sb.categories and sb.categories.essential and sb.categories.essential.order or math.huge
      if oa == ob then
        local na = (sa and sa.name) or (C_Spell.GetSpellInfo(a) and C_Spell.GetSpellInfo(a).name) or tostring(a)
        local nb = (sb and sb.name) or (C_Spell.GetSpellInfo(b) and C_Spell.GetSpellInfo(b).name) or tostring(b)
        return na < nb
      end
      return oa < ob
    end
    return ia < ib
  end)

  local order = 1
  if #ordered == 0 then
    container.empty = {
      type = "description",
      name = "No spells on the Top Bar yet. Use 'Add Spell ID' to add one.",
      order = order,
    }
    return
  end

  -- Bygg options-grupper
  for _, spellID in ipairs(ordered) do
    local s = C_Spell.GetSpellInfo(spellID)
    local icon = s and s.iconID and ("|T" .. s.iconID .. ":16|t ") or ""
    local name = (s and s.name) or ("Spell " .. spellID)
    local entry = snapshot and snapshot[spellID]

    -- Linked buffs
    local _, linkTable = EnsureBuffTracking(addon, class, specID)

    local linkedArgs, idx = {}, 1
    local buffIDs = {}
    for buffID, linkedSpellID in pairs(linkTable) do
      if linkedSpellID == spellID then
        table.insert(buffIDs, buffID)
      end
    end
    table.sort(buffIDs, function(a, b)
      return (tonumber(a) or a) < (tonumber(b) or b)
    end)
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
          linkTable[buffID] = nil
          BuildTopBarSpellsEditor(addon, container)
          addon:BuildFramesForSpec()
          local ACR = LibStub("AceConfigRegistry-3.0", true)
          if ACR then ACR:NotifyChange("ClassHUD") end
        end,
      }
      idx = idx + 1
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
            linkTable[buffID] = spellID
            BuildTopBarSpellsEditor(addon, container)
            addon:BuildFramesForSpec()
            local ACR = LibStub("AceConfigRegistry-3.0", true)
            if ACR then ACR:NotifyChange("ClassHUD") end
          end,
        },
        order = {
          type  = "range",
          name  = "Order",
          min   = 1,
          max   = 50,
          step  = 1,
          order = 3,
          get   = function()
            local placement, index = GetSpellPlacement(addon, class, specID, spellID)
            if placement == "TOP" then
              return index or 1
            end
            return (entry and entry.categories and entry.categories.essential and entry.categories.essential.order) or 1
          end,
          set   = function(_, val)
            SetSpellOrder(addon, class, specID, spellID, val)
            addon:BuildFramesForSpec()
            NotifyOptionsChanged()
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
            local lists = EnsurePlacementLists(addon, class, specID)
            RemoveSpellFromLists(lists, spellID)
            for bid, sid in pairs(linkTable) do
              if sid == spellID then linkTable[bid] = nil end
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
  local lists = EnsurePlacementLists(addon, class, specID)
  local _, linkTable = EnsureBuffTracking(addon, class, specID)

  local snapshot = addon:GetSnapshotForSpec(class, specID, false)
  local entries = SortEntries(snapshot, category)
  local order = 1
  local added = {}

  local function addOption(spellID, entry)
    if added[spellID] then return end
    added[spellID] = true

    local iconID = entry and entry.iconID
    local name = entry and entry.name

    if not name then
      local info = C_Spell.GetSpellInfo(spellID)
      iconID = iconID or (info and info.iconID)
      name = info and info.name or ("Spell " .. spellID)
    end

    local icon = iconID and ("|T" .. iconID .. ":16|t ") or ""

    local linkedBuffs = {}
    for buffID, linkedSpellID in pairs(linkTable) do
      if linkedSpellID == spellID then
        local buffInfo = C_Spell.GetSpellInfo(buffID)
        linkedBuffs[#linkedBuffs + 1] = (buffInfo and buffInfo.name) or ("Buff " .. buffID)
      end
    end

    local linkNote
    if #linkedBuffs > 0 then
      table.sort(linkedBuffs)
      linkNote = "|cff00ff00Linked Buffs:|r " .. table.concat(linkedBuffs, ", ")
    end

    container["spell" .. spellID] = {
      type = "select",
      name = icon .. name .. " (" .. spellID .. ")",
      desc = linkNote,
      order = order,
      values = PLACEMENTS,
      get = function()
        local placement = GetSpellPlacement(addon, class, specID, spellID)
        return placement or defaultPlacement
      end,
      set = function(_, value)
        local placementLists = EnsurePlacementLists(addon, class, specID)
        if value == defaultPlacement then
          RemoveSpellFromLists(placementLists, spellID)
        else
          SetSpellPlacement(addon, class, specID, spellID, value)
        end
        addon:BuildFramesForSpec()
        BuildPlacementArgs(addon, container, category, defaultPlacement, emptyText)
        NotifyOptionsChanged()
      end,
    }

    order = order + 1
  end

  for _, item in ipairs(entries) do
    addOption(item.spellID, item.entry)
  end

  local placementOrder = { "TOP", "BOTTOM", "LEFT", "RIGHT", "HIDDEN" }
  for _, placementName in ipairs(placementOrder) do
    local list = lists[placementName]
    if type(list) == "table" then
      for _, spellID in ipairs(list) do
        local entry = snapshot and snapshot[spellID]
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

  local tracked = EnsureBuffTracking(addon, class, specID)
  local orderList = EnsureTrackedBuffOrder(addon, class, specID)
  local manualIndex = {}
  for index = 1, #orderList do
    local buffID = orderList[index]
    manualIndex[buffID] = index
  end

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

  for _, buffID in ipairs(orderList) do
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
    data.manualOrder = manualIndex[data.buffID]
    table.insert(list, data)
  end

  table.sort(list, function(a, b)
    local ao = a.manualOrder or math.huge
    local bo = b.manualOrder or math.huge
    if ao == bo then
      if a.order == b.order then
        return a.name < b.name
      end
      return a.order < b.order
    end
    return ao < bo
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
        showBar = {
          type = "toggle",
          name = "Show as Bar",
          order = 2,
          hidden = function()
            return not data.hasBar
          end,
          get = function()
            local cfg = getConfig(false)
            return cfg and cfg.showBar or false
          end,
          set = function(_, value)
            local cfg = getConfig(true)
            cfg.showBar = not not value
            addon:BuildTrackedBuffFrames()
            BuildTrackedBuffArgs(addon, container)
            NotifyOptionsChanged()
          end,
        },
        barShowIcon = {
          type = "toggle",
          name = "Show Icon",
          order = 4,
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
          order = 5,
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
          order = 6,
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
        orderControl = {
          type = "range",
          name = "Order",
          order = 7,
          min = 1,
          max = 50,
          step = 1,
          get = function()
            local index = GetTrackedBuffOrder(addon, class, specID, buffID)
            return index or 1
          end,
          set = function(_, value)
            local index = math.floor(value + 0.5)
            SetTrackedBuffOrder(addon, class, specID, buffID, index)
            addon:BuildTrackedBuffFrames()
            BuildTrackedBuffArgs(addon, container)
            NotifyOptionsChanged()
          end,
        },
        remove = {
          type = "execute",
          name = "Remove",
          confirm = true,
          order = 99,
          func = function()
            RemoveTrackedBuff(addon, class, specID, buffID)
            addon:BuildTrackedBuffFrames()
            BuildTrackedBuffArgs(addon, container)
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
  local _, links = EnsureBuffTracking(addon, class, specID)
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
              local current = links[map.buffID]
              links[map.buffID] = nil
              links[newID] = current
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
              links[map.buffID] = newID
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
            links[map.buffID] = nil
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

  local layout = addon.db.profile.layout or {}
  addon.db.profile.layout = layout
  layout.barOrder = layout.barOrder or { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" }
  local barOrder = layout.barOrder

  local LABELS = {
    TOP      = "Top Bar",
    CAST     = "Cast Bar",
    HP       = "Health Bar",
    RESOURCE = "Primary Resource",
    CLASS    = "Class/Special Power",
    BOTTOM   = "Bottom Bar",
  }

  for index, key in ipairs(barOrder) do
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
            barOrder[index], barOrder[index - 1] = barOrder[index - 1], barOrder[index]
            addon:FullUpdate()
            BuildBarOrderEditor(addon, container)
            NotifyOptionsChanged()
          end,
        },
        down = {
          type     = "execute",
          name     = "↓",
          width    = "half",
          disabled = (index == #barOrder),
          func     = function()
            barOrder[index], barOrder[index + 1] = barOrder[index + 1], barOrder[index]
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
  local profile = db.profile

  profile.textures = profile.textures or { bar = "Blizzard", font = "Friz Quadrata TT" }
  profile.colors = profile.colors or {}
  profile.colors.hp = profile.colors.hp or { r = 0.10, g = 0.80, b = 0.10 }
  if profile.colors.resourceClass == nil then profile.colors.resourceClass = true end
  profile.colors.resource = profile.colors.resource or { r = 0.00, g = 0.55, b = 1.00 }
  profile.colors.power = profile.colors.power or { r = 1.00, g = 0.85, b = 0.10 }
  profile.colors.border = profile.colors.border or { r = 0, g = 0, b = 0, a = 1 }

  profile.position = profile.position or { x = 0, y = -50 }
  profile.position.x = profile.position.x or 0
  profile.position.y = profile.position.y or -50
  profile.width = profile.width or 250
  profile.spacing = profile.spacing or 2
  profile.powerSpacing = profile.powerSpacing or 2

  profile.layout = profile.layout or {}
  local layout = profile.layout
  layout.show = layout.show or { cast = true, hp = true, resource = true, power = true, buffs = true }
  layout.height = layout.height or { cast = 18, hp = 14, resource = 14, power = 14 }
  layout.barOrder = layout.barOrder or { "TOP", "CAST", "HP", "RESOURCE", "CLASS", "BOTTOM" }

  layout.topBar = layout.topBar or {}
  layout.topBar.perRow = layout.topBar.perRow or 8
  layout.topBar.spacingX = layout.topBar.spacingX or 4
  layout.topBar.spacingY = layout.topBar.spacingY or 4
  layout.topBar.yOffset = layout.topBar.yOffset or 0
  layout.topBar.grow = layout.topBar.grow or "UP"
  layout.topBar.spells = layout.topBar.spells or {}

  layout.bottomBar = layout.bottomBar or {}
  layout.bottomBar.perRow = layout.bottomBar.perRow or 8
  layout.bottomBar.spacingX = layout.bottomBar.spacingX or 4
  layout.bottomBar.spacingY = layout.bottomBar.spacingY or 4
  layout.bottomBar.yOffset = layout.bottomBar.yOffset or 0
  layout.bottomBar.spells = layout.bottomBar.spells or {}

  layout.sideBars = layout.sideBars or {}
  layout.sideBars.size = layout.sideBars.size or 36
  layout.sideBars.spacing = layout.sideBars.spacing or 4
  layout.sideBars.offset = layout.sideBars.offset or 6
  layout.sideBars.yOffset = layout.sideBars.yOffset or 0
  layout.sideBars.spells = layout.sideBars.spells or {}

  layout.trackedBuffBar = layout.trackedBuffBar or {}
  layout.trackedBuffBar.perRow = layout.trackedBuffBar.perRow or 8
  layout.trackedBuffBar.spacingX = layout.trackedBuffBar.spacingX or 4
  layout.trackedBuffBar.spacingY = layout.trackedBuffBar.spacingY or 4
  layout.trackedBuffBar.yOffset = layout.trackedBuffBar.yOffset or 4
  layout.trackedBuffBar.align = layout.trackedBuffBar.align or "CENTER"
  layout.trackedBuffBar.height = layout.trackedBuffBar.height or 16
  layout.trackedBuffBar.buffs = layout.trackedBuffBar.buffs or {}

  layout.hiddenSpells = layout.hiddenSpells or {}

  profile.tracking = profile.tracking or {}
  local tracking = profile.tracking
  tracking.summons = tracking.summons or { enabled = true, byClass = {} }
  tracking.summons.byClass = tracking.summons.byClass or {}
  tracking.wildImps = tracking.wildImps or { enabled = true, mode = "implosion" }
  tracking.totems = tracking.totems or { enabled = true, overlayStyle = "SWIPE", showDuration = true }
  tracking.buffs = tracking.buffs or {}
  tracking.buffs.links = tracking.buffs.links or {}
  tracking.buffs.tracked = tracking.buffs.tracked or {}

  local topBarEditorContainer = {}
  local utilityContainer = {}
  local trackedContainer = {}
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
            get = function() return layout.show.cast end,
            set = function(_, value)
              layout.show.cast = value
              addon:FullUpdate()
            end,
          },
          showHP = {
            type = "toggle",
            name = "Show Health Bar",
            order = 2,
            get = function() return layout.show.hp end,
            set = function(_, value)
              layout.show.hp = value
              addon:FullUpdate()
            end,
          },
          showResource = {
            type = "toggle",
            name = "Show Primary Resource",
            order = 3,
            get = function() return layout.show.resource end,
            set = function(_, value)
              layout.show.resource = value
              addon:FullUpdate()
            end,
          },
          showBuffs = {
            type = "toggle",
            name = "Show Tracked Buff Bar",
            order = 5,
            get = function() return layout.show.buffs end,
            set = function(_, value)
              layout.show.buffs = value
              addon:BuildTrackedBuffFrames()
            end,
          },
          borderColor = {
            type = "color",
            name = "Bar Border Color",
            order = 10,
            hasAlpha = true,
            get = function()
              local c = profile.colors.border or { r = 0, g = 0, b = 0, a = 1 }
              return c.r, c.g, c.b, c.a or 1
            end,
            set = function(_, r, g, b, a)
              profile.colors.border = { r = r, g = g, b = b, a = a or 1 }
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
            get = function() return layout.trackedBuffBar.height or 16 end,
            set = function(_, value)
              layout.trackedBuffBar.height = value
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

          heightCast = {
            type = "range",
            name = "Cast Height",
            order = 8,
            min = 8,
            max = 40,
            step = 1,
            get = function() return layout.height.cast end,
            set = function(_, value)
              layout.height.cast = value
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
            get = function() return layout.height.hp end,
            set = function(_, value)
              layout.height.hp = value
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
            get = function() return layout.height.resource end,
            set = function(_, value)
              layout.height.resource = value
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
                get = function() return layout.topBar.perRow end,
                set = function(_, value)
                  layout.topBar.perRow = value
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
                get = function() return layout.topBar.spacingX end,
                set = function(_, value)
                  layout.topBar.spacingX = value
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
                get = function() return layout.topBar.spacingY end,
                set = function(_, value)
                  layout.topBar.spacingY = value
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
                get = function() return layout.topBar.yOffset end,
                set = function(_, value)
                  layout.topBar.yOffset = value
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
                get = function() return layout.bottomBar.perRow end,
                set = function(_, value)
                  layout.bottomBar.perRow = value
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
                get = function() return layout.bottomBar.spacingX end,
                set = function(_, value)
                  layout.bottomBar.spacingX = value
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
                get = function() return layout.bottomBar.spacingY end,
                set = function(_, value)
                  layout.bottomBar.spacingY = value
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
                get = function() return layout.bottomBar.yOffset end,
                set = function(_, value)
                  layout.bottomBar.yOffset = value
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
                get = function() return layout.sideBars.size end,
                set = function(_, value)
                  layout.sideBars.size = value
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
                get = function() return layout.sideBars.spacing end,
                set = function(_, value)
                  layout.sideBars.spacing = value
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
                get = function() return layout.sideBars.offset end,
                set = function(_, value)
                  layout.sideBars.offset = value
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
                get = function() return layout.sideBars.yOffset or 0 end,
                set = function(_, value)
                  layout.sideBars.yOffset = value
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
        },
      },
      classbar = {
        type = "group",
        name = "Class Bar",
        order = 3,
        args = {
          general = {
            type = "group",
            name = "General",
            inline = true,
            order = 1,
            args = {
              show = {
                type = "toggle",
                name = "Show Class Bar",
                order = 1,
                get = function() return layout.show.power end,
                set = function(_, value)
                  layout.show.power = value
                  addon:FullUpdate()
                end,
              },
              height = {
                type = "range",
                name = "Bar Height",
                order = 2,
                min = 8,
                max = 40,
                step = 1,
                get = function() return layout.height.power end,
                set = function(_, value)
                  layout.height.power = value
                  addon:FullUpdate()
                end,
                disabled = function() return not layout.show.power end,
              },
              spacing = {
                type = "range",
                name = "Segment Spacing",
                order = 3,
                min = 0,
                max = 12,
                step = 1,
                get = function() return db.profile.powerSpacing or 2 end,
                set = function(_, value)
                  db.profile.powerSpacing = value
                  addon:FullUpdate()
                end,
                disabled = function() return not layout.show.power end,
              },
            },
          },
          colors = {
            type = "group",
            name = "Colors",
            inline = true,
            order = 2,
            args = {
              power = {
                type = "color",
                name = "Special Power",
                order = 1,
                get = function()
                  local c = db.profile.colors.power
                  return c.r, c.g, c.b
                end,
                set = function(_, r, g, b)
                  db.profile.colors.power = { r = r, g = g, b = b }
                  addon:UpdateSpecialPower()
                end,
                disabled = function() return not layout.show.power end,
              },
            },
          },
          druid = {
            type = "group",
            name = "Druid",
            order = 10,
            args = {
              balanceHeader = {
                type = "header",
                name = "Balance",
                order = 1,
              },
              balanceEclipse = {
                type = "toggle",
                name = "Enable Eclipse Bar",
                order = 2,
                get = function()
                  local classbars = db.profile.classbars and db.profile.classbars.DRUID
                  local spec = classbars and classbars[102]
                  if spec and spec.eclipse ~= nil then
                    return spec.eclipse
                  end
                  return true
                end,
                set = function(_, val)
                  db.profile.classbars = db.profile.classbars or {}
                  db.profile.classbars.DRUID = db.profile.classbars.DRUID or {}
                  db.profile.classbars.DRUID[102] = db.profile.classbars.DRUID[102] or {}
                  db.profile.classbars.DRUID[102].eclipse = val
                  addon:FullUpdate()
                end,
              },
              balanceCombo = {
                type = "toggle",
                name = "Enable Combo Points (Balance)",
                order = 3,
                get = function()
                  local classbars = db.profile.classbars and db.profile.classbars.DRUID
                  local spec = classbars and classbars[102]
                  return spec and spec.combo or false
                end,
                set = function(_, val)
                  db.profile.classbars = db.profile.classbars or {}
                  db.profile.classbars.DRUID = db.profile.classbars.DRUID or {}
                  db.profile.classbars.DRUID[102] = db.profile.classbars.DRUID[102] or {}
                  db.profile.classbars.DRUID[102].combo = val
                  addon:FullUpdate()
                end,
              },
              feralHeader = {
                type = "header",
                name = "Feral",
                order = 4,
              },
              feralCombo = {
                type = "toggle",
                name = "Enable Combo Points (Feral)",
                order = 5,
                get = function()
                  local classbars = db.profile.classbars and db.profile.classbars.DRUID
                  local spec = classbars and classbars[103]
                  if spec and spec.combo ~= nil then
                    return spec.combo
                  end
                  return true
                end,
                set = function(_, val)
                  db.profile.classbars = db.profile.classbars or {}
                  db.profile.classbars.DRUID = db.profile.classbars.DRUID or {}
                  db.profile.classbars.DRUID[103] = db.profile.classbars.DRUID[103] or {}
                  db.profile.classbars.DRUID[103].combo = val
                  addon:FullUpdate()
                end,
              },
              guardianHeader = {
                type = "header",
                name = "Guardian",
                order = 6,
              },
              guardianCombo = {
                type = "toggle",
                name = "Enable Combo Points (Guardian)",
                order = 7,
                get = function()
                  local classbars = db.profile.classbars and db.profile.classbars.DRUID
                  local spec = classbars and classbars[104]
                  if spec and spec.combo ~= nil then
                    return spec.combo
                  end
                  return true
                end,
                set = function(_, val)
                  db.profile.classbars = db.profile.classbars or {}
                  db.profile.classbars.DRUID = db.profile.classbars.DRUID or {}
                  db.profile.classbars.DRUID[104] = db.profile.classbars.DRUID[104] or {}
                  db.profile.classbars.DRUID[104].combo = val
                  addon:FullUpdate()
                end,
              },
              restoHeader = {
                type = "header",
                name = "Restoration",
                order = 8,
              },
              restoCombo = {
                type = "toggle",
                name = "Enable Combo Points (Restoration)",
                order = 9,
                get = function()
                  local classbars = db.profile.classbars and db.profile.classbars.DRUID
                  local spec = classbars and classbars[105]
                  return spec and spec.combo or false
                end,
                set = function(_, val)
                  db.profile.classbars = db.profile.classbars or {}
                  db.profile.classbars.DRUID = db.profile.classbars.DRUID or {}
                  db.profile.classbars.DRUID[105] = db.profile.classbars.DRUID[105] or {}
                  db.profile.classbars.DRUID[105].combo = val
                  addon:FullUpdate()
                end,
              },
            },
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
                local lists = EnsurePlacementLists(addon, class, specID)
                SetSpellPlacement(addon, class, specID, spellID, "TOP", #lists.TOP + 1)
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
                local lists = EnsurePlacementLists(addon, class, specID)
                SetSpellPlacement(addon, class, specID, spellID, "HIDDEN", #lists.HIDDEN + 1)
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
                local tracked = EnsureBuffTracking(addon, class, specID)
                local orderList = EnsureTrackedBuffOrder(addon, class, specID)
                tracked[buffID] = tracked[buffID] or true
                local exists = false
                for _, existing in ipairs(orderList) do
                  if (tonumber(existing) or existing) == buffID then
                    exists = true
                    break
                  end
                end
                if not exists then
                  orderList[#orderList + 1] = buffID
                end
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
        },
      },
      summonsTotems = {
        type = "group",
        name = "Summons & Totems",
        order = 5,
        args = {
          description = {
            type = "description",
            name = "Configure tracking for temporary summons, Wild Imps, and totem overlays.",
            order = 1,
          },
          trackSummons = {
            type = "toggle",
            name = "Track temporary summons",
            order = 2,
            get = function()
              return tracking.summons.enabled ~= false
            end,
            set = function(_, val)
              tracking.summons.enabled = not not val
              if not val then
                if addon.ResetSummonTracking then addon:ResetSummonTracking() end
              else
                if addon.RefreshTemporaryBuffs then addon:RefreshTemporaryBuffs(true) end
              end
              NotifyOptionsChanged()
            end,
          },
          trackWildImps = {
            type = "toggle",
            name = "Track Wild Imps as stack counter on Implosion",
            order = 3,
            hidden = function()
              return not PlayerMatchesSpec(addon, "WARLOCK", 266)
            end,
            disabled = function()
              return tracking.summons.enabled == false
            end,
            get = function()
              return tracking.wildImps.enabled ~= false
            end,
            set = function(_, val)
              tracking.wildImps.enabled = not not val
              if addon.ClearWildImpTracking then
                addon:ClearWildImpTracking()
              end
              NotifyOptionsChanged()
            end,
          },
          wildImpMode = {
            type = "select",
            name = "Wild Imp Tracking Mode",
            order = 4,
            values = WILD_IMP_MODE_OPTIONS,
            hidden = function()
              return not PlayerMatchesSpec(addon, "WARLOCK", 266)
            end,
            disabled = function()
              return tracking.summons.enabled == false or tracking.wildImps.enabled == false
            end,
            get = function()
              local mode = tracking.wildImps.mode
              if mode == "buff" then
                return "buff"
              end
              return "implosion"
            end,
            set = function(_, value)
              tracking.wildImps.mode = value
              if addon.RefreshWildImpDisplay then addon:RefreshWildImpDisplay() end
              NotifyOptionsChanged()
            end,
          },
          trackTotems = {
            type = "toggle",
            name = "Track totem uptime",
            order = 5,
            hidden = function()
              return not PlayerMatchesClass(addon, "SHAMAN")
            end,
            get = function()
              return tracking.totems.enabled ~= false
            end,
            set = function(_, val)
              tracking.totems.enabled = not not val
              if not val then
                if addon.ResetTotemTracking then addon:ResetTotemTracking() end
              else
                if addon.RefreshAllTotems then addon:RefreshAllTotems() end
              end
              NotifyOptionsChanged()
            end,
          },
          totemStyle = {
            type = "select",
            name = "Totem overlay style",
            order = 7,
            values = TOTEM_OVERLAY_OPTIONS,
            hidden = function()
              return not PlayerMatchesClass(addon, "SHAMAN") or tracking.totems.enabled == false
            end,
            get = function()
              return tracking.totems.overlayStyle or "SWIPE"
            end,
            set = function(_, value)
              tracking.totems.overlayStyle = value
              if addon.RefreshAllTotems then addon:RefreshAllTotems() end
              NotifyOptionsChanged()
            end,
          },
          totemShowDuration = {
            type = "toggle",
            name = "Show Totem Duration",
            order = 6,
            hidden = function()
              return not PlayerMatchesClass(addon, "SHAMAN")
            end,
            disabled = function()
              return tracking.totems.enabled == false
            end,
            get = function()
              if tracking.totems.showDuration == nil then
                return true
              end
              return tracking.totems.showDuration
            end,
            set = function(_, val)
              tracking.totems.showDuration = not not val
              if addon.RefreshAllTotems then addon:RefreshAllTotems() end
              NotifyOptionsChanged()
            end,
          },
        },
      },
      snapshot = {
        type = "group",
        name = "Snapshot",
        order = 6,
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

  local summonArgs = opts.args.summonsTotems and opts.args.summonsTotems.args
  if summonArgs then
    for index, classConfig in ipairs(SUMMON_CLASS_CONFIG) do
      summonArgs["summons_" .. classConfig.class] = {
        type = "group",
        name = classConfig.label,
        inline = true,
        order = 10 + index,
        hidden = function()
          if tracking.summons.enabled == false then
            return true
          end
          return not PlayerMatchesClass(addon, classConfig.class)
        end,
        args = BuildSummonSpellArgs(addon, classConfig),
      }
    end
  end

  BuildTopBarSpellsEditor(addon, topBarEditorContainer)
  BuildPlacementArgs(addon, utilityContainer, "utility", "HIDDEN",
    "No utility cooldowns reported by the snapshot for this spec.")
  BuildTrackedBuffArgs(addon, trackedContainer)
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
