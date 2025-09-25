-- ClassHUD_Options.lua
-- Rebuilt, snapshot-driven options UI

---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")

local ACR = LibStub("AceConfigRegistry-3.0", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

local function GetSpellInfoSafe(spellID)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if info then
      return info
    end
  end

  if type(GetSpellInfo) == "function" then
    local name, _, icon = GetSpellInfo(spellID)
    if name or icon then
      return { name = name, iconID = icon }
    end
  end

  return nil
end

local function GetSpellDisplayName(spellID)
  local info = GetSpellInfoSafe(spellID)
  if info and info.name and info.name ~= "" then
    return info.name
  end
  local idText = spellID ~= nil and tostring(spellID) or "?"
  return "Spell " .. idText
end

local TrimString do
  if type(strtrim) == "function" then
    TrimString = function(value)
      return strtrim(value or "")
    end
  else
    TrimString = function(value)
      value = value or ""
      local trimmed = value:match("^%s*(.-)%s*$")
      if trimmed == nil then
        return ""
      end
      return trimmed
    end
  end
end

local PLACEMENTS = {
  HIDDEN = "Hidden",
  TOP = "Top Bar",
  BOTTOM = "Bottom Bar",
  LEFT = "Left Side",
  RIGHT = "Right Side",
}

local SUMMON_CLASS_CONFIG = {
  { class = "PRIEST",      label = "Priest Summons",       spells = { 34433, 123040 } },
  { class = "WARLOCK",     label = "Warlock Summons",      spells = { 193332, 264119, 455476, 265187, 111898, 205180 } },
  { class = "DEATHKNIGHT", label = "Death Knight Summons", spells = { 42650, 49206 } },
  { class = "DRUID",       label = "Druid Summons",        spells = { 205636 } },
  { class = "MONK",        label = "Monk Summons",         spells = { 115313 } },
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

local function PlayerHasClassbar(addon)
  if addon and addon.PlayerHasClassBarSupport then
    return addon:PlayerHasClassBarSupport()
  end

  if not addon or not addon.db then return false end

  local class = select(1, addon:GetPlayerClassSpec())
  if not class or class == "" then
    class = UnitClass and select(2, UnitClass("player")) or nil
  end
  if not class then return false end

  local profileLayout = addon.db.profile and addon.db.profile.layout
  if profileLayout and profileLayout.classbars and profileLayout.classbars[class] then
    return true
  end

  local defaults = addon.db.defaults
  local defaultLayout = defaults and defaults.profile and defaults.profile.layout
  if defaultLayout and defaultLayout.classbars and defaultLayout.classbars[class] then
    return true
  end

  return false
end

local function SpecSupportsClassbar(addon)
  if addon and addon.IsClassBarSpecSupported then
    return addon:IsClassBarSpecSupported()
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

  local specLinks = buffs.links[class][specID]
  if addon and addon.NormalizeBuffLinkTable then
    addon:NormalizeBuffLinkTable(specLinks)
  end

  return buffs.tracked[class][specID], specLinks
end

local function EnsureSoundConfig(addon, class, specID)
  addon.db.profile.soundAlerts = addon.db.profile.soundAlerts or { enabled = false }
  local root = addon.db.profile.soundAlerts
  root[class] = root[class] or {}
  root[class][specID] = root[class][specID] or {}
  return root[class][specID]
end

local SOUND_NONE = "None"

local function BuildSoundDropdownValues()
  local values = { [SOUND_NONE] = SOUND_NONE }
  if LSM then
    local media = LSM:HashTable("sound")
    if type(media) == "table" then
      for key in pairs(media) do
        if key and key ~= "" then
          values[key] = key
        end
      end
    end
  end
  return values
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

local function EnsureUtilitySpellList(addon, class, specID)
  addon.db.profile.layout = addon.db.profile.layout or {}
  local layout = addon.db.profile.layout
  layout.utility = layout.utility or {}
  layout.utility.spells = layout.utility.spells or {}
  layout.utility.spells[class] = layout.utility.spells[class] or {}
  layout.utility.spells[class][specID] = layout.utility.spells[class][specID] or {}
  return layout.utility.spells[class][specID]
end

local function EnsureTopBarFlags(addon, class, specID)
  addon.db.profile.layout = addon.db.profile.layout or {}
  local layout = addon.db.profile.layout
  layout.topBar = layout.topBar or {}
  layout.topBar.flags = layout.topBar.flags or {}
  layout.topBar.flags[class] = layout.topBar.flags[class] or {}
  layout.topBar.flags[class][specID] = layout.topBar.flags[class][specID] or {}
  return layout.topBar.flags[class][specID]
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

local function MergeArgs(target, staticArgs, dynamicArgs)
  for k in pairs(target) do
    target[k] = nil
  end

  if staticArgs then
    for key, value in pairs(staticArgs) do
      target[key] = value
    end
  end

  if dynamicArgs then
    for key, value in pairs(dynamicArgs) do
      target[key] = value
    end
  end
end

local function CreateSpellOptionGroup(addon, state, class, specID, spellID, placementKey, snapshot, lists, linkTable,
  soundValues, refreshFn)
  local entry = snapshot and snapshot[spellID]
  local info = GetSpellInfoSafe(spellID)
  local icon = (entry and entry.iconID) or (info and info.iconID)
  local name = (entry and entry.name) or (info and info.name) or GetSpellDisplayName(spellID)
  local displayID = type(spellID) == "number" and spellID or tostring(spellID)
  local iconPrefix = icon and ("|T" .. icon .. ":16|t ") or ""

  local group = {
    type = "group",
    name = string.format("%s%s (%s)", iconPrefix, name, tostring(displayID)),
    args = {},
  }

  local args = group.args
  local spellKey = tostring(displayID)
  local placementMemory = state.spellPlacementMemory

  local function rebuild()
    if type(refreshFn) == "function" then
      refreshFn()
    end
  end

  local function GetMutableOrderList()
    if placementKey == "UTILITY" then
      local list = EnsureUtilitySpellList(addon, class, specID)
      local normalized = tonumber(spellID) or spellID
      local index
      for i = 1, #list do
        if (tonumber(list[i]) or list[i]) == normalized then
          index = i
          break
        end
      end
      return list, index, "UTILITY"
    end

    local placement, index, lists = GetSpellPlacement(addon, class, specID, spellID)
    if not placement or placement == "HIDDEN" then
      return nil, nil, placement
    end

    local list = lists and lists[placement]
    return list, index, placement
  end

  local function CanMove(delta)
    local list, index = GetMutableOrderList()
    if type(list) ~= "table" or not index then return false end
    local target = index + delta
    return target >= 1 and target <= #list
  end

  local function Move(delta)
    local list, index = GetMutableOrderList()
    if type(list) ~= "table" or not index then return end
    local target = index + delta
    if target < 1 or target > #list then return end

    list[index], list[target] = list[target], list[index]

    addon:BuildFramesForSpec()
    rebuild()
    NotifyOptionsChanged()
  end

  args.enabled = {
    type = "toggle",
    name = "Enabled",
    order = 1,
    width = "half",
    get = function()
      local placement = GetSpellPlacement(addon, class, specID, spellID)
      return placement ~= "HIDDEN"
    end,
    set = function(_, value)
      local placement, _, placementLists = GetSpellPlacement(addon, class, specID, spellID)
      placementLists = placementLists or EnsurePlacementLists(addon, class, specID)
      state.spellPlacementMemory = state.spellPlacementMemory or {}
      placementMemory = state.spellPlacementMemory

      if not value then
        if placement and placement ~= "HIDDEN" then
          placementMemory[spellKey] = placement
        elseif not placementMemory[spellKey] then
          placementMemory[spellKey] = placementKey
        end
        SetSpellPlacement(addon, class, specID, spellID, "HIDDEN")
      else
        local restore = placementMemory[spellKey]
        if restore == nil or restore == "" or restore == "HIDDEN" then
          if placementKey and placementLists[placementKey] then
            restore = placementKey
          elseif placementLists.TOP then
            restore = "TOP"
          else
            restore = nil
          end
        end

        RemoveSpellFromLists(placementLists, spellID)
        if restore and restore ~= "UTILITY" and placementLists[restore] then
          table.insert(placementLists[restore], spellID)
        end
      end

      addon:BuildFramesForSpec()
      rebuild()
      NotifyOptionsChanged()
    end,
  }

  args.placement = {
    type = "select",
    name = "Placement",
    order = 1.5,
    width = "half",
    values = PLACEMENTS,
    get = function()
      local placement = GetSpellPlacement(addon, class, specID, spellID)
      return placement or "HIDDEN"
    end,
    set = function(_, value)
      if value == "HIDDEN" then
        SetSpellPlacement(addon, class, specID, spellID, "HIDDEN")
      else
        SetSpellPlacement(addon, class, specID, spellID, value)
      end
      state.spellPlacementMemory = state.spellPlacementMemory or {}
      state.spellPlacementMemory[spellKey] = value
      addon:BuildFramesForSpec()
      rebuild()
      NotifyOptionsChanged()
    end,
  }

  args.moveUp = {
    type = "execute",
    name = "↑",
    order = 1.8,
    width = "half",
    disabled = function()
      return not CanMove(-1)
    end,
    func = function()
      Move(-1)
    end,
  }

  args.moveDown = {
    type = "execute",
    name = "↓",
    order = 1.9,
    width = "half",
    disabled = function()
      return not CanMove(1)
    end,
    func = function()
      Move(1)
    end,
  }

  args.order = {
    type = "range",
    name = "Order",
    order = 2,
    min = 1,
    max = 50,
    step = 1,
    get = function()
      local placement, index = GetSpellPlacement(addon, class, specID, spellID)
      return index or 1
    end,
    set = function(_, value)
      SetSpellOrder(addon, class, specID, spellID, value)
      addon:BuildFramesForSpec()
      rebuild()
      NotifyOptionsChanged()
    end,
    disabled = function()
      local placement = GetSpellPlacement(addon, class, specID, spellID)
      return placement == nil or placement == "HIDDEN"
    end,
  }

  if placementKey == "TOP" then
    args.trackOnTarget = {
      type = "toggle",
      name = "Track on Target",
      order = 2.2,
      width = "full",
      desc =
        "When enabled, this spell will track its DoT/debuff on your current target. Uses the debuff state machine (cooldown, active, pandemic). If no target or the debuff is missing, the icon is shown greyed out.",
      get = function()
        local numericID = tonumber(spellID) or spellID
        local flagsRoot = addon:GetProfileTable(false, "layout", "topBar", "flags", class, specID)
        local perSpell = flagsRoot and numericID and flagsRoot[numericID]
        return perSpell and perSpell.trackOnTarget == true
      end,
      set = function(_, value)
        local numericID = tonumber(spellID) or spellID
        local flagsRoot = EnsureTopBarFlags(addon, class, specID)
        if value then
          flagsRoot[numericID] = flagsRoot[numericID] or {}
          flagsRoot[numericID].trackOnTarget = true
        else
          local perSpell = flagsRoot[numericID]
          if perSpell then
            perSpell.trackOnTarget = nil
            if next(perSpell) == nil then
              flagsRoot[numericID] = nil
            end
          end
          if next(flagsRoot) == nil then
            local topFlags = addon.db.profile.layout.topBar.flags
            local classFlags = topFlags and topFlags[class]
            if classFlags then
              classFlags[specID] = nil
              if next(classFlags) == nil then
                topFlags[class] = nil
              end
            end
          end
        end
        addon:BuildFramesForSpec()
        NotifyOptionsChanged()
      end,
    }
  end

  local linkedArgs = {}
  local linkedOrder = 1
  if linkTable and spellID then
    local normalizedSpellID = tonumber(spellID) or spellID
    local buffIDs = {}
    for buffID, spellSet in pairs(linkTable) do
      if normalizedSpellID then
        if type(spellSet) == "table" then
          if spellSet[normalizedSpellID] then
            buffIDs[#buffIDs + 1] = buffID
          end
        else
          local resolved = tonumber(spellSet) or spellSet
          if resolved == normalizedSpellID then
            buffIDs[#buffIDs + 1] = buffID
          end
        end
      end
    end
    table.sort(buffIDs, function(a, b)
      return (tonumber(a) or a) < (tonumber(b) or b)
    end)

    for _, buffID in ipairs(buffIDs) do
      local buffInfo = GetSpellInfoSafe(buffID)
      local buffIcon = buffInfo and buffInfo.iconID and ("|T" .. buffInfo.iconID .. ":16|t ") or ""
      local buffName = (buffInfo and buffInfo.name) or GetSpellDisplayName(buffID)
      linkedArgs["buff" .. buffID] = {
        type = "execute",
        name = string.format("%s%s (%s)", buffIcon, buffName, tostring(buffID)),
        desc = "Click to remove this link",
        order = linkedOrder,
        func = function()
          local set = linkTable[buffID]
          if type(set) == "table" then
            set[normalizedSpellID] = nil
            if not next(set) then
              linkTable[buffID] = nil
            end
          end
          addon:BuildFramesForSpec()
          rebuild()
          NotifyOptionsChanged()
        end,
      }
      linkedOrder = linkedOrder + 1
    end
  end

  if linkedOrder == 1 then
    linkedArgs.none = {
      type = "description",
      name = "No linked buffs yet.",
      order = linkedOrder,
    }
  end

  args.addBuff = {
    type = "input",
    name = "Add Buff ID",
    order = 2.4,
    width = "half",
    get = function()
      return ""
    end,
    set = function(_, value)
      local buffID = tonumber(value)
      if not buffID then return end
      local normalized = tonumber(spellID) or spellID
      if not normalized then return end
      local set = linkTable[buffID]
      if type(set) ~= "table" then
        local previous = tonumber(set) or set
        set = {}
        if previous then
          set[previous] = true
        end
        linkTable[buffID] = set
      end
      set[normalized] = true
      addon:BuildFramesForSpec()
      rebuild()
      NotifyOptionsChanged()
    end,
  }

  args.linked = {
    type = "group",
    name = "Linked Buffs",
    order = 2.6,
    inline = true,
    args = linkedArgs,
  }

  args.sounds = {
    type = "group",
    name = "Sound Alerts",
    order = 3,
    inline = true,
    args = {
      ready = {
        type = "select",
        name = "Ready",
        order = 1,
        width = "full",
        dialogControl = "LSM30_Sound",
        values = soundValues,
        get = function()
          local conf = EnsureSoundConfig(addon, class, specID)
          local per = conf[spellID]
          return (per and per.onReady) or SOUND_NONE
        end,
        set = function(_, value)
          local conf = EnsureSoundConfig(addon, class, specID)
          conf[spellID] = conf[spellID] or {}
          if value == SOUND_NONE then
            conf[spellID].onReady = nil
          else
            conf[spellID].onReady = value
          end
          addon:UpdateAllSpellFrames()
          NotifyOptionsChanged()
        end,
      },
      applied = {
        type = "select",
        name = "Applied",
        order = 2,
        width = "full",
        dialogControl = "LSM30_Sound",
        values = soundValues,
        get = function()
          local conf = EnsureSoundConfig(addon, class, specID)
          local per = conf[spellID]
          return (per and per.onApplied) or SOUND_NONE
        end,
        set = function(_, value)
          local conf = EnsureSoundConfig(addon, class, specID)
          conf[spellID] = conf[spellID] or {}
          if value == SOUND_NONE then
            conf[spellID].onApplied = nil
          else
            conf[spellID].onApplied = value
          end
          addon:UpdateAllSpellFrames()
          NotifyOptionsChanged()
        end,
      },
      removed = {
        type = "select",
        name = "Removed",
        order = 3,
        width = "full",
        dialogControl = "LSM30_Sound",
        values = soundValues,
        get = function()
          local conf = EnsureSoundConfig(addon, class, specID)
          local per = conf[spellID]
          return (per and per.onRemoved) or SOUND_NONE
        end,
        set = function(_, value)
          local conf = EnsureSoundConfig(addon, class, specID)
          conf[spellID] = conf[spellID] or {}
          if value == SOUND_NONE then
            conf[spellID].onRemoved = nil
          else
            conf[spellID].onRemoved = value
          end
          addon:UpdateAllSpellFrames()
          NotifyOptionsChanged()
        end,
      },
    },
  }

  args.removeSpell = {
    type = "execute",
    name = "Remove Spell",
    confirm = true,
    order = 99,
    func = function()
      local placementLists = EnsurePlacementLists(addon, class, specID)
      RemoveSpellFromLists(placementLists, spellID)
      local hidden = placementLists.HIDDEN
      if type(hidden) == "table" then
        hidden[#hidden + 1] = spellID
      end
      for buffID, linkedSpellID in pairs(linkTable) do
        if type(linkedSpellID) == "table" then
          linkedSpellID[spellID] = nil
          if not next(linkedSpellID) then
            linkTable[buffID] = nil
          end
        else
          local resolved = tonumber(linkedSpellID) or linkedSpellID
          if resolved == spellID then
            linkTable[buffID] = nil
          end
        end
      end
      addon:BuildFramesForSpec()
      rebuild()
      NotifyOptionsChanged()
    end,
  }

  return group
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

local function PopulatePlacementSpellGroups(addon, container, state, placementKey, refreshFn)
  for key in pairs(container) do
    container[key] = nil
  end

  state.hasSpells = state.hasSpells or {}
  state.hasSpells[placementKey] = false

  local class, specID = addon:GetPlayerClassSpec()
  local snapshot = addon:GetSnapshotForSpec(class, specID, false)
  local lists = EnsurePlacementLists(addon, class, specID)
  local _, linkTable = EnsureBuffTracking(addon, class, specID)
  local soundValues = BuildSoundDropdownValues()

  local added = {}
  local order = 1

  local function addSpell(spellID)
    local normalized = tonumber(spellID) or spellID
    if not normalized then return end
    local key = tostring(normalized)
    if added[key] then return end

    local group = CreateSpellOptionGroup(addon, state, class, specID, normalized, placementKey, snapshot, lists,
      linkTable, soundValues, refreshFn)
    group.order = order
    container["spell" .. key] = group
    added[key] = true
    order = order + 1
    state.hasSpells[placementKey] = true
  end

  local placementList = lists[placementKey]
  if type(placementList) == "table" then
    for _, spellID in ipairs(placementList) do
      addSpell(spellID)
    end
  end

  if placementKey == "TOP" and snapshot then
    local sorted = SortEntries(snapshot, "essential")
    for _, info in ipairs(sorted) do
      addSpell(info.spellID)
    end
  end
end

local function PopulateUtilitySpellGroups(addon, container, state, refreshFn)
  for key in pairs(container) do
    container[key] = nil
  end

  state.hasSpells = state.hasSpells or {}
  state.hasSpells.UTILITY = false

  local class, specID = addon:GetPlayerClassSpec()
  local snapshot = addon:GetSnapshotForSpec(class, specID, false)
  local lists = EnsurePlacementLists(addon, class, specID)
  local _, linkTable = EnsureBuffTracking(addon, class, specID)
  local soundValues = BuildSoundDropdownValues()

  local added = {}
  local order = 1

  local function addSpell(spellID)
    local normalized = tonumber(spellID) or spellID
    if not normalized then return end
    local key = tostring(normalized)
    if added[key] then return end

    local group = CreateSpellOptionGroup(addon, state, class, specID, normalized, "UTILITY", snapshot, lists, linkTable,
      soundValues, refreshFn)
    group.order = order
    container["spell" .. key] = group
    added[key] = true
    order = order + 1
    state.hasSpells.UTILITY = true
  end

  local utilityRoot = addon.db.profile.layout and addon.db.profile.layout.utility
  local utilityList = utilityRoot and utilityRoot.spells and utilityRoot.spells[class] and utilityRoot.spells[class][specID]

  if type(utilityList) == "table" then
    for _, spellID in ipairs(utilityList) do
      addSpell(spellID)
    end
  end

  local hiddenList = lists.HIDDEN
  if type(hiddenList) == "table" then
    for _, spellID in ipairs(hiddenList) do
      addSpell(spellID)
    end
  end

  if snapshot then
    local sorted = SortEntries(snapshot, "utility")
    for _, info in ipairs(sorted) do
      addSpell(info.spellID)
    end
  end
end

local function PopulateTrackedBuffGroups(addon, container, state, refreshFn)
  for key in pairs(container) do
    container[key] = nil
  end

  state.hasSpells = state.hasSpells or {}
  state.hasSpells.TRACKED = false

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
        local sortOrder = math.huge
        if hasBuff and hasBuff.order then sortOrder = math.min(sortOrder, hasBuff.order) end
        if hasBar and hasBar.order then sortOrder = math.min(sortOrder, hasBar.order) end

        local info = GetSpellInfoSafe(spellID)
        entries[spellID] = {
          buffID = spellID,
          icon = entry.iconID or (info and info.iconID),
          name = entry.name or (info and info.name) or GetSpellDisplayName(spellID),
          order = sortOrder,
        }
      end
    end
  end

  for buffID in pairs(tracked) do
    if not entries[buffID] then
      local info = GetSpellInfoSafe(buffID)
      entries[buffID] = {
        buffID = buffID,
        icon = info and info.iconID,
        name = info and info.name or GetSpellDisplayName(buffID),
        order = math.huge,
      }
    end
  end

  for _, buffID in ipairs(orderList) do
    if not entries[buffID] then
      local info = GetSpellInfoSafe(buffID)
      entries[buffID] = {
        buffID = buffID,
        icon = info and info.iconID,
        name = info and info.name or GetSpellDisplayName(buffID),
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
        return (a.name or "") < (b.name or "")
      end
      return a.order < b.order
    end
    return ao < bo
  end)

  local order = 1
  for _, data in ipairs(list) do
    local buffID = data.buffID
    local icon = data.icon and ("|T" .. data.icon .. ":16|t ") or ""
    local header = string.format("%s%s (%s)", icon, data.name or ("Spell " .. tostring(buffID)), tostring(buffID))

    container["buff" .. buffID] = {
      type = "group",
      name = header,
      order = order,
      args = {
        track = {
          type = "toggle",
          name = "Track Buff",
          order = 1,
          get = function()
            local cfg = addon:GetTrackedEntryConfig(class, specID, buffID, false)
            return cfg and cfg.showIcon or false
          end,
          set = function(_, value)
            local cfg = addon:GetTrackedEntryConfig(class, specID, buffID, true)
            cfg.showIcon = not not value
            addon:BuildTrackedBuffFrames()
            if type(refreshFn) == "function" then refreshFn() end
            NotifyOptionsChanged()
          end,
        },
        orderControl = {
          type = "range",
          name = "Order",
          order = 2,
          min = 1,
          max = 50,
          step = 1,
          get = function()
            local index = GetTrackedBuffOrder(addon, class, specID, buffID)
            return index or 1
          end,
          set = function(_, value)
            local index = math.floor((tonumber(value) or 1) + 0.5)
            SetTrackedBuffOrder(addon, class, specID, buffID, index)
            addon:BuildTrackedBuffFrames()
            if type(refreshFn) == "function" then refreshFn() end
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
            if type(refreshFn) == "function" then refreshFn() end
            NotifyOptionsChanged()
          end,
        },
      },
    }

    order = order + 1
    state.hasSpells.TRACKED = true
  end
end

local function BuildSummonSpellArgs(addon, classConfig)
  local args = {}
  for index, spellID in ipairs(classConfig.spells) do
    local info = GetSpellInfoSafe(spellID)
    local name = (info and info.name) or GetSpellDisplayName(spellID)
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

local function BuildClassBarSpecialOptions(addon, container)
  wipe(container)

  local class, specID = addon:GetPlayerClassSpec()
  local layout = addon.db and addon.db.profile and addon.db.profile.layout or {}
  layout.classbars = layout.classbars or {}

  if class == "DRUID" then
    if specID == 102 then
      container.eclipse = {
        type = "toggle",
        name = "Enable Eclipse Bar",
        order = 1,
        get = function()
          local classbars = layout.classbars.DRUID
          local spec = classbars and classbars[102]
          if spec and spec.eclipse ~= nil then
            return spec.eclipse
          end
          return true
        end,
        set = function(_, val)
          layout.classbars.DRUID = layout.classbars.DRUID or {}
          layout.classbars.DRUID[102] = layout.classbars.DRUID[102] or {}
          layout.classbars.DRUID[102].eclipse = val
          addon:FullUpdate()
        end,
      }
      container.balanceCombo = {
        type = "toggle",
        name = "Enable Combo Points (Balance)",
        order = 2,
        get = function()
          local classbars = layout.classbars.DRUID
          local spec = classbars and classbars[102]
          if spec and spec.combo ~= nil then
            return spec.combo
          end
          return true
        end,
        set = function(_, val)
          layout.classbars.DRUID = layout.classbars.DRUID or {}
          layout.classbars.DRUID[102] = layout.classbars.DRUID[102] or {}
          layout.classbars.DRUID[102].combo = val
          addon:FullUpdate()
        end,
      }
    elseif specID == 103 then
      container.feralCombo = {
        type = "toggle",
        name = "Enable Combo Points (Feral)",
        order = 1,
        get = function()
          local classbars = layout.classbars.DRUID
          local spec = classbars and classbars[103]
          if spec and spec.combo ~= nil then
            return spec.combo
          end
          return true
        end,
        set = function(_, val)
          layout.classbars.DRUID = layout.classbars.DRUID or {}
          layout.classbars.DRUID[103] = layout.classbars.DRUID[103] or {}
          layout.classbars.DRUID[103].combo = val
          addon:FullUpdate()
        end,
      }
    elseif specID == 104 then
      container.guardianCombo = {
        type = "toggle",
        name = "Enable Combo Points (Guardian)",
        order = 1,
        get = function()
          local classbars = layout.classbars.DRUID
          local spec = classbars and classbars[104]
          if spec and spec.combo ~= nil then
            return spec.combo
          end
          return true
        end,
        set = function(_, val)
          layout.classbars.DRUID = layout.classbars.DRUID or {}
          layout.classbars.DRUID[104] = layout.classbars.DRUID[104] or {}
          layout.classbars.DRUID[104].combo = val
          addon:FullUpdate()
        end,
      }
    elseif specID == 105 then
      container.restoCombo = {
        type = "toggle",
        name = "Enable Combo Points (Restoration)",
        order = 1,
        get = function()
          local classbars = layout.classbars.DRUID
          local spec = classbars and classbars[105]
          return spec and spec.combo or false
        end,
        set = function(_, val)
          layout.classbars.DRUID = layout.classbars.DRUID or {}
          layout.classbars.DRUID[105] = layout.classbars.DRUID[105] or {}
          layout.classbars.DRUID[105].combo = val
          addon:FullUpdate()
        end,
      }
    end
  end

  if not next(container) then
    container.none = {
      type = "description",
      name = "No class-specific options available.",
      order = 1,
    }
  end
end

local function BuildSummonGroups(addon, container)
  wipe(container)

  local class = select(1, addon:GetPlayerClassSpec())
  if not class or class == "" then
    container.none = {
      type = "description",
      name = "No summon tracking options available.",
      order = 1,
    }
    return
  end

  local order = 1
  for _, classConfig in ipairs(SUMMON_CLASS_CONFIG) do
    if classConfig.class == class then
      container["summons_" .. classConfig.class .. "_" .. order] = {
        type = "group",
        name = classConfig.label,
        order = order,
        inline = false,
        args = BuildSummonSpellArgs(addon, classConfig),
      }
      order = order + 1
    end
  end

  if order == 1 then
    container.none = {
      type = "description",
      name = "No summon tracking options available.",
      order = 1,
    }
  end
end

local function NotifyOptionsChanged()
  if ACR then ACR:NotifyChange("ClassHUD") end
end

-- Bygger Top Bar Spells-editoren inline (uten å lage ny venstremeny-node)
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
  for buffKey, spellSet in pairs(links) do
    if type(spellSet) ~= "table" then
      local resolved = tonumber(spellSet) or spellSet
      if resolved then
        spellSet = { [resolved] = true }
      else
        spellSet = {}
      end
      links[buffKey] = spellSet
    end

    if type(spellSet) == "table" then
      local spells = {}
      for spellID, enabled in pairs(spellSet) do
        if enabled then
          spells[#spells + 1] = tonumber(spellID) or spellID
        end
      end
      if #spells > 0 then
        table.sort(spells, function(a, b)
          return (tonumber(a) or a) < (tonumber(b) or b)
        end)
        sorted[#sorted + 1] = {
          buffID = tonumber(buffKey) or buffKey,
          spells = spells,
        }
      else
        links[buffKey] = nil
      end
    end
  end

  table.sort(sorted, function(a, b)
    return (tonumber(a.buffID) or a.buffID) < (tonumber(b.buffID) or b.buffID)
  end)

  for _, map in ipairs(sorted) do
    local buffID = map.buffID
    local buffInfo = GetSpellInfoSafe(buffID)
    local buffName = (buffInfo and buffInfo.name) or GetSpellDisplayName(buffID)
    local buffIcon = buffInfo and buffInfo.iconID or 134400

    local name = string.format("|T%d:16|t %s (%s)", buffIcon, buffName, tostring(buffID))

    local args = {}

    args.buff = {
      type = "input",
      name = "Buff ID",
      width = "half",
      order = 1,
      get = function() return tostring(buffID) end,
      set = function(_, value)
        local newID = tonumber(value)
        if newID and newID ~= buffID then
          local current = links[buffID]
          links[buffID] = nil

          local target = links[newID]
          if type(target) ~= "table" then
            local resolved = tonumber(target) or target
            target = {}
            if resolved then
              target[resolved] = true
            end
          end

          if type(current) == "table" then
            target = target or {}
            for spellKey, enabled in pairs(current) do
              if enabled then
                local normalizedSpell = tonumber(spellKey) or spellKey
                if normalizedSpell then
                  target[normalizedSpell] = true
                end
              end
            end
          end

          if target and next(target) then
            links[newID] = target
          else
            links[newID] = nil
          end

          addon:BuildFramesForSpec()
          BuildBuffLinkArgs(addon, container)
          NotifyOptionsChanged()
        end
      end,
    }

    args.addSpell = {
      type = "input",
      name = "Add Spell ID",
      width = "half",
      order = 2,
      get = function() return "" end,
      set = function(_, value)
        local newID = tonumber(value)
        if newID then
          local set = links[buffID]
          if type(set) ~= "table" then
            set = {}
            links[buffID] = set
          end
          set[newID] = true
          addon:BuildFramesForSpec()
          BuildBuffLinkArgs(addon, container)
          NotifyOptionsChanged()
        end
      end,
    }

    local spellOrder = 10
    for _, spellID in ipairs(map.spells) do
      local info = GetSpellInfoSafe(spellID)
      local icon = info and info.iconID or 134400
      local spellName = info and info.name or GetSpellDisplayName(spellID)
      local displayID = tostring(spellID)

      args["spell" .. displayID] = {
        type = "execute",
        name = string.format("|T%d:16|t %s (%s)", icon, spellName, displayID),
        desc = "Click to remove this link",
        order = spellOrder,
        func = function()
          local set = links[buffID]
          if type(set) == "table" then
            local normalized = tonumber(spellID) or spellID
            set[normalized] = nil
            if not next(set) then
              links[buffID] = nil
            end
          end
          addon:BuildFramesForSpec()
          BuildBuffLinkArgs(addon, container)
          NotifyOptionsChanged()
        end,
      }
      spellOrder = spellOrder + 1
    end

    args.remove = {
      type = "execute",
      name = "Remove",
      confirm = true,
      order = 99,
      func = function()
        links[buffID] = nil
        addon:BuildFramesForSpec()
        BuildBuffLinkArgs(addon, container)
        NotifyOptionsChanged()
      end,
    }

    container["link" .. buffID] = {
      type = "group",
      name = name,
      inline = true,
      order = order,
      args = args,
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
  profile.fontSize = profile.fontSize or profile.spellFontSize or profile.buffFontSize or 12
  profile.spellFontSize = nil
  profile.buffFontSize = nil

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

  layout.classbars = layout.classbars or {}

  layout.topBar = layout.topBar or {}
  layout.topBar.perRow = layout.topBar.perRow or 8
  layout.topBar.spacingX = layout.topBar.spacingX or 4
  layout.topBar.spacingY = layout.topBar.spacingY or 4
  layout.topBar.yOffset = layout.topBar.yOffset or 0
  layout.topBar.grow = layout.topBar.grow or "UP"
  if layout.topBar.pandemicHighlight == nil then
    layout.topBar.pandemicHighlight = true
  end
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

  profile.soundAlerts = profile.soundAlerts or { enabled = false }
  if profile.soundAlerts.enabled == nil then
    profile.soundAlerts.enabled = false
  end

  local placementContainers = {
    TOP = {},
    BOTTOM = {},
    LEFT = {},
    RIGHT = {},
  }
  local placementGroupArgs = {
    TOP = {},
    BOTTOM = {},
    LEFT = {},
    RIGHT = {},
  }

  addon._optionsState = addon._optionsState or {}
  local optionsState = addon._optionsState
  optionsState.spellPlacementMemory = optionsState.spellPlacementMemory or {}
  optionsState.hasSpells = optionsState.hasSpells or {}

  local RefreshSpellEditors

  local placementStaticArgs = {
    TOP = {
      description = {
        type = "description",
        name = "Manage spells assigned to the Top Bar and configure linked buffs and sounds.",
        order = 1,
      },
      addSpell = {
        type = "input",
        name = "Add Spell ID",
        order = 2,
        width = "half",
        get = function()
          return ""
        end,
        set = function(_, value)
          local spellID = tonumber(value)
          if not spellID then return end
          local class, specID = addon:GetPlayerClassSpec()
          local lists = EnsurePlacementLists(addon, class, specID)
          SetSpellPlacement(addon, class, specID, spellID, "TOP", #lists.TOP + 1)
          addon:BuildFramesForSpec()
          RefreshSpellEditors()
          NotifyOptionsChanged()
        end,
      },
      empty = {
        type = "description",
        name = "No spells assigned to the Top Bar yet.",
        order = 3,
        hidden = function()
          return optionsState.hasSpells and optionsState.hasSpells.TOP
        end,
      },
    },
    BOTTOM = {
      description = {
        type = "description",
        name = "Spells ordered on the Bottom Bar.",
        order = 1,
      },
      empty = {
        type = "description",
        name = "No spells assigned to the Bottom Bar.",
        order = 2,
        hidden = function()
          return optionsState.hasSpells and optionsState.hasSpells.BOTTOM
        end,
      },
    },
    LEFT = {
      description = {
        type = "description",
        name = "Manage spells shown on the left sidebar.",
        order = 1,
      },
      empty = {
        type = "description",
        name = "No spells assigned to the left sidebar.",
        order = 2,
        hidden = function()
          return optionsState.hasSpells and optionsState.hasSpells.LEFT
        end,
      },
    },
    RIGHT = {
      description = {
        type = "description",
        name = "Manage spells shown on the right sidebar.",
        order = 1,
      },
      empty = {
        type = "description",
        name = "No spells assigned to the right sidebar.",
        order = 2,
        hidden = function()
          return optionsState.hasSpells and optionsState.hasSpells.RIGHT
        end,
      },
    },
  }

  local utilityContainer = {}
  local utilityGroupArgs = {}
  local utilityStaticArgs = {
    description = {
      type = "description",
      name = "Utility spells detected for this specialization. Assign them to bars or keep them hidden.",
      order = 1,
    },
    addSpell = {
      type = "input",
      name = "Add Spell ID",
      order = 2,
      width = "half",
      get = function()
        return ""
      end,
      set = function(_, value)
        local spellID = tonumber(value)
        if not spellID then return end
        local class, specID = addon:GetPlayerClassSpec()
        local lists = EnsurePlacementLists(addon, class, specID)
        SetSpellPlacement(addon, class, specID, spellID, "HIDDEN", #lists.HIDDEN + 1)
        addon:BuildFramesForSpec()
        RefreshSpellEditors()
        NotifyOptionsChanged()
      end,
    },
    empty = {
      type = "description",
      name = "No utility spells recorded for this specialization.",
      order = 3,
      hidden = function()
        return optionsState.hasSpells and optionsState.hasSpells.UTILITY
      end,
    },
  }

  local trackedContainer = {}
  local trackedGroupArgs = {}
  local trackedStaticArgs = {
    description = {
      type = "description",
      name = "Configure the buffs that appear in the tracked buff bar.",
      order = 1,
    },
    addBuff = {
      type = "input",
      name = "Add Buff ID",
      order = 2,
      width = "half",
      get = function()
        return ""
      end,
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
        RefreshSpellEditors()
        NotifyOptionsChanged()
      end,
    },
    empty = {
      type = "description",
      name = "No tracked buffs configured for this specialization.",
      order = 3,
      hidden = function()
        return optionsState.hasSpells and optionsState.hasSpells.TRACKED
      end,
    },
  }

  local barOrderContainer = {}
  local classBarSpecialContainer = {}
  local summonGroupContainer = {}
  optionsState.profileCopySource = optionsState.profileCopySource or ""
  optionsState.profileDeleteTarget = optionsState.profileDeleteTarget or ""
  optionsState.profileImportInput = optionsState.profileImportInput or ""

  local function RefreshSpellEditors()
    PopulatePlacementSpellGroups(addon, placementContainers.TOP, optionsState, "TOP", RefreshSpellEditors)
    PopulatePlacementSpellGroups(addon, placementContainers.BOTTOM, optionsState, "BOTTOM", RefreshSpellEditors)
    PopulatePlacementSpellGroups(addon, placementContainers.LEFT, optionsState, "LEFT", RefreshSpellEditors)
    PopulatePlacementSpellGroups(addon, placementContainers.RIGHT, optionsState, "RIGHT", RefreshSpellEditors)
    PopulateUtilitySpellGroups(addon, utilityContainer, optionsState, RefreshSpellEditors)
    PopulateTrackedBuffGroups(addon, trackedContainer, optionsState, RefreshSpellEditors)

    MergeArgs(placementGroupArgs.TOP, placementStaticArgs.TOP, placementContainers.TOP)
    MergeArgs(placementGroupArgs.BOTTOM, placementStaticArgs.BOTTOM, placementContainers.BOTTOM)
    MergeArgs(placementGroupArgs.LEFT, placementStaticArgs.LEFT, placementContainers.LEFT)
    MergeArgs(placementGroupArgs.RIGHT, placementStaticArgs.RIGHT, placementContainers.RIGHT)
    MergeArgs(utilityGroupArgs, utilityStaticArgs, utilityContainer)
    MergeArgs(trackedGroupArgs, trackedStaticArgs, trackedContainer)
  end

  local function RefreshDynamicOptionEditors()
    RefreshSpellEditors()
    BuildBarOrderEditor(addon, barOrderContainer)
    BuildClassBarSpecialOptions(addon, classBarSpecialContainer)
    BuildSummonGroups(addon, summonGroupContainer)
  end

  local function GetAvailableProfiles()
    local values = {}
    if addon.db and addon.db.GetProfiles then
      local profiles = {}
      addon.db:GetProfiles(profiles)
      for _, name in ipairs(profiles) do
        values[name] = name
      end
    end

    if addon.db and addon.db.GetCurrentProfile then
      local current = addon.db:GetCurrentProfile()
      if current and current ~= "" then
        values[current] = current
      end
    end

    return values
  end

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
          frameLayout = {
            type = "group",
            name = "Frame & Layout",
            order = 1,
            inline = true,
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
            },
          },
          appearance = {
            type = "group",
            name = "Appearance",
            order = 2,
            inline = true,
            args = {
              texture = {
                type = "select",
                name = "Bar Texture",
                dialogControl = "LSM30_Statusbar",
                order = 1,
                values = LSM and LSM:HashTable("statusbar") or {},
                get = function() return db.profile.textures.bar end,
                set = function(_, value)
                  db.profile.textures.bar = value
                  addon:ApplyBarSkins()
                  NotifyOptionsChanged()
                end,
              },
              font = {
                type = "select",
                name = "Font",
                dialogControl = "LSM30_Font",
                order = 2,
                values = LSM and LSM:HashTable("font") or {},
                get = function() return db.profile.textures.font end,
                set = function(_, value)
                  db.profile.textures.font = value
                  addon:ApplyBarSkins()
                  addon:UpdateAllSpellFrames()
                  addon:BuildTrackedBuffFrames()
                  NotifyOptionsChanged()
                end,
              },
              fontSize = {
                type = "range",
                name = "Global Font Size",
                order = 3,
                min = 8,
                max = 32,
                step = 1,
                get = function() return db.profile.fontSize or 12 end,
                set = function(_, value)
                  db.profile.fontSize = value
                  addon:ApplyBarSkins()
                  if addon.UpdateAllSpellFrames then addon:UpdateAllSpellFrames() end
                  if addon.BuildTrackedBuffFrames then addon:BuildTrackedBuffFrames() end
                  NotifyOptionsChanged()
                end,
              },
              soundAlerts = {
                type = "toggle",
                name = "Enable Sound Alerts",
                order = 4,
                width = "full",
                get = function()
                  return db.profile.soundAlerts and db.profile.soundAlerts.enabled
                end,
                set = function(_, value)
                  db.profile.soundAlerts = db.profile.soundAlerts or { enabled = false }
                  db.profile.soundAlerts.enabled = value and true or false
                  addon:UpdateAllSpellFrames()
                  NotifyOptionsChanged()
                end,
              },
              borderColor = {
                type = "color",
                name = "Bar Border Color",
                order = 5,
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
            },
          },
          barOrder = {
            type = "group",
            name = "Bar Order",
            order = 3,
            inline = true,
            args = barOrderContainer,
          },
        },
      },
      bars = {
        type = "group",
        name = "Bars",
        order = 2,
        inline = false,
        args = {
          castBar = {
            type = "group",
            name = "Cast Bar",
            order = 1,
            inline = true,
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
              heightCast = {
                type = "range",
                name = "Cast Height",
                order = 2,
                min = 8,
                max = 40,
                step = 1,
                get = function() return layout.height.cast end,
                set = function(_, value)
                  layout.height.cast = value
                  addon:FullUpdate()
                end,
                disabled = function()
                  return not layout.show.cast
                end,
              },
            },
          },
          healthBar = {
            type = "group",
            name = "Health Bar",
            order = 2,
            inline = true,
            args = {
              showHP = {
                type = "toggle",
                name = "Show Health Bar",
                order = 1,
                get = function() return layout.show.hp end,
                set = function(_, value)
                  layout.show.hp = value
                  addon:FullUpdate()
                end,
              },
              heightHP = {
                type = "range",
                name = "Health Height",
                order = 2,
                min = 8,
                max = 40,
                step = 1,
                get = function() return layout.height.hp end,
                set = function(_, value)
                  layout.height.hp = value
                  addon:FullUpdate()
                end,
                disabled = function()
                  return not layout.show.hp
                end,
              },
            },
          },
          resourceBar = {
            type = "group",
            name = "Resource Bar",
            order = 3,
            inline = true,
            args = {
              showResource = {
                type = "toggle",
                name = "Show Primary Resource",
                order = 1,
                get = function() return layout.show.resource end,
                set = function(_, value)
                  layout.show.resource = value
                  addon:FullUpdate()
                end,
              },
              heightResource = {
                type = "range",
                name = "Resource Height",
                order = 2,
                min = 8,
                max = 40,
                step = 1,
                get = function() return layout.height.resource end,
                set = function(_, value)
                  layout.height.resource = value
                  addon:FullUpdate()
                end,
                disabled = function()
                  return not layout.show.resource
                end,
              },
            },
          },
          buffsBar = {
            type = "group",
            name = "Tracked Buff Bar",
            order = 4,
            inline = true,
            args = {
              showBuffs = {
                type = "toggle",
                name = "Show Tracked Buff Bar",
                order = 1,
                get = function() return layout.show.buffs end,
                set = function(_, value)
                  layout.show.buffs = value
                  addon:BuildTrackedBuffFrames()
                end,
              },
            },
          },
          topLayout = {
            type = "group",
            name = "Top Bar Layout",
            order = 10,
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
              pandemicHighlight = {
                type = "toggle",
                name = "Enable Pandemic Highlight",
                order = 5,
                width = "full",
                get = function()
                  return layout.topBar.pandemicHighlight ~= false
                end,
                set = function(_, value)
                  layout.topBar.pandemicHighlight = value and true or false
                  addon:UpdateAllSpellFrames()
                end,
              },
              grow = {
                type = "select",
                name = "Growth Direction",
                order = 6,
                values = {
                  UP = "Up",
                  DOWN = "Down",
                },
                get = function()
                  return layout.topBar.grow or "UP"
                end,
                set = function(_, value)
                  layout.topBar.grow = value
                  addon:BuildFramesForSpec()
                end,
              },
            },
          },
          bottomLayout = {
            type = "group",
            name = "Bottom Bar Layout",
            order = 11,
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
            order = 12,
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
        hidden = function()
          return not PlayerHasClassbar(addon)
        end,
        args = {
          general = {
            type = "group",
            name = "General",
            inline = true,
            order = 1,
            disabled = function()
              return not SpecSupportsClassbar(addon)
            end,
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
                disabled = function()
                  return not SpecSupportsClassbar(addon)
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
                disabled = function()
                  return not layout.show.power or not SpecSupportsClassbar(addon)
                end,
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
                disabled = function()
                  return not layout.show.power or not SpecSupportsClassbar(addon)
                end,
              },
            },
          },
          colors = {
            type = "group",
            name = "Colors",
            inline = true,
            order = 2,
            disabled = function()
              return not SpecSupportsClassbar(addon)
            end,
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
                disabled = function()
                  return not layout.show.power or not SpecSupportsClassbar(addon)
                end,
              },
            },
          },
          special = {
            type = "group",
            name = "Class Options",
            order = 3,
            inline = true,
            disabled = function()
              return not SpecSupportsClassbar(addon)
            end,
            args = classBarSpecialContainer,
          },
        },
      },
      spells = {
        type = "group",
        name = "Spells & Buffs",
        order = 4,
        childGroups = "tree",
        args = {
          topBar = {
            type = "group",
            name = "Top Bar",
            order = 1,
            args = placementGroupArgs.TOP,
          },
          bottomBar = {
            type = "group",
            name = "Bottom Bar",
            order = 2,
            args = placementGroupArgs.BOTTOM,
          },
          leftBar = {
            type = "group",
            name = "Left Side",
            order = 3,
            args = placementGroupArgs.LEFT,
          },
          rightBar = {
            type = "group",
            name = "Right Side",
            order = 4,
            args = placementGroupArgs.RIGHT,
          },
          utility = {
            type = "group",
            name = "Utility",
            order = 5,
            args = utilityGroupArgs,
          },
          trackedBuffs = {
            type = "group",
            name = "Tracked Buffs",
            order = 6,
            args = trackedGroupArgs,
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
          summonGroups = {
            type = "group",
            name = "Summon Tracking",
            order = 10,
            inline = false,
            hidden = function()
              return tracking.summons.enabled == false
            end,
            args = summonGroupContainer,
          },
        },
      },
      profiles = {
        type = "group",
        name = "Profiles",
        order = 6,
        args = {
          activeProfile = {
            type = "select",
            name = "Active Profile",
            order = 1,
            width = "full",
            values = GetAvailableProfiles,
            get = function()
              if addon.db and addon.db.GetCurrentProfile then
                return addon.db:GetCurrentProfile()
              end
              return "Default"
            end,
            set = function(_, value)
              if not (addon.db and addon.db.SetProfile) then return end
              addon.db:SetProfile(value)
              RefreshDynamicOptionEditors()
              if addon.ApplyAnchorPosition then addon:ApplyAnchorPosition() end
              if addon.FullUpdate then addon:FullUpdate() end
              if addon.BuildFramesForSpec then addon:BuildFramesForSpec() end
              NotifyOptionsChanged()
            end,
          },
          actions = {
            type = "group",
            name = "Profile Actions",
            order = 2,
            inline = true,
            args = {
              copyFrom = {
                type = "select",
                name = "Copy From",
                order = 1,
                width = "double",
                values = GetAvailableProfiles,
                get = function()
                  local values = GetAvailableProfiles()
                  if optionsState.profileCopySource ~= "" and not values[optionsState.profileCopySource] then
                    optionsState.profileCopySource = ""
                  end
                  return optionsState.profileCopySource ~= "" and optionsState.profileCopySource or nil
                end,
                set = function(_, value)
                  optionsState.profileCopySource = value or ""
                end,
              },
              copyButton = {
                type = "execute",
                name = "Copy From Profile",
                order = 2,
                func = function()
                  local source = optionsState.profileCopySource
                  if not source or source == "" then return end
                  if addon.db and addon.db.CopyProfile then
                    addon.db:CopyProfile(source)
                    RefreshDynamicOptionEditors()
                    if addon.ApplyAnchorPosition then addon:ApplyAnchorPosition() end
                    if addon.FullUpdate then addon:FullUpdate() end
                    if addon.BuildFramesForSpec then addon:BuildFramesForSpec() end
                    NotifyOptionsChanged()
                  end
                end,
                disabled = function()
                  local source = optionsState.profileCopySource
                  if not source or source == "" then return true end
                  if addon.db and addon.db.GetCurrentProfile then
                    return addon.db:GetCurrentProfile() == source
                  end
                  return false
                end,
              },
              resetButton = {
                type = "execute",
                name = "Reset Profile",
                order = 3,
                func = function()
                  if addon.db and addon.db.ResetProfile then
                    addon.db:ResetProfile()
                    RefreshDynamicOptionEditors()
                    if addon.ApplyAnchorPosition then addon:ApplyAnchorPosition() end
                    if addon.FullUpdate then addon:FullUpdate() end
                    if addon.BuildFramesForSpec then addon:BuildFramesForSpec() end
                    NotifyOptionsChanged()
                  end
                end,
              },
              deleteTarget = {
                type = "select",
                name = "Delete",
                order = 4,
                width = "double",
                values = GetAvailableProfiles,
                get = function()
                  local values = GetAvailableProfiles()
                  if optionsState.profileDeleteTarget ~= "" and not values[optionsState.profileDeleteTarget] then
                    optionsState.profileDeleteTarget = ""
                  end
                  return optionsState.profileDeleteTarget ~= "" and optionsState.profileDeleteTarget or nil
                end,
                set = function(_, value)
                  optionsState.profileDeleteTarget = value or ""
                end,
              },
              deleteButton = {
                type = "execute",
                name = "Delete Profile",
                order = 5,
                func = function()
                  local target = optionsState.profileDeleteTarget
                  if not target or target == "" then return end
                  if addon.db and addon.db.DeleteProfile then
                    local current = addon.db.GetCurrentProfile and addon.db:GetCurrentProfile()
                    if current ~= target then
                      addon.db:DeleteProfile(target, true)
                      optionsState.profileDeleteTarget = ""
                      RefreshDynamicOptionEditors()
                      NotifyOptionsChanged()
                    end
                  end
                end,
                disabled = function()
                  local target = optionsState.profileDeleteTarget
                  if not target or target == "" then return true end
                  if addon.db and addon.db.GetCurrentProfile then
                    return addon.db:GetCurrentProfile() == target
                  end
                  return false
                end,
              },
            },
          },
          exportHeader = {
            type = "description",
            name = "Export your current profile to share or back up settings.",
            order = 5,
          },
          exportProfile = {
            type = "input",
            name = "Export Current Profile",
            order = 6,
            width = "full",
            multiline = true,
            get = function()
              local serialized, err = addon:SerializeCurrentProfile()
              if not serialized then
                return err and ("Error: " .. err) or ""
              end
              return serialized
            end,
            set = function() end,
          },
          importProfile = {
            type = "input",
            name = "Import Profile String",
            order = 7,
            width = "full",
            multiline = true,
            get = function()
              return optionsState.profileImportInput or ""
            end,
            set = function(_, value)
              value = TrimString(value)
              optionsState.profileImportInput = value
              if value == "" then return end
              local ok, err = addon:DeserializeProfileString(value)
              if not ok then
                print("|cff00ff88ClassHUD|r Import failed:", err)
                return
              end
              optionsState.profileImportInput = ""
              RefreshDynamicOptionEditors()
              if addon.ApplyAnchorPosition then addon:ApplyAnchorPosition() end
              if addon.FullUpdate then addon:FullUpdate() end
              if addon.BuildFramesForSpec then addon:BuildFramesForSpec() end
            end,
          },
          rescanSnapshot = {
            type = "execute",
            name = "Rescan from Cooldown Manager",
            order = 20,
            width = "full",
            desc = "Import newly available spells from Blizzard's Cooldown Manager snapshot without altering your existing layout.",
            func = function()
              if not (addon and addon.RescanFromCDM) then return end
              local ok, result = pcall(addon.RescanFromCDM, addon)
              if not ok then
                print("|cff00ff88ClassHUD|r Rescan failed:", result)
              elseif not result then
                -- RescanFromCDM prints its own feedback when no changes occur
              end
              RefreshDynamicOptionEditors()
              NotifyOptionsChanged()
            end,
            disabled = function()
              return not (addon and addon.IsCooldownViewerAvailable and addon:IsCooldownViewerAvailable())
            end,
          },
        },
      },
    },
  }

  RefreshDynamicOptionEditors()

  return opts
end

function ClassHUD:GetUtilityOptions()
  local state = {
    spellPlacementMemory = self._optionsState and self._optionsState.spellPlacementMemory or {},
    hasSpells = {},
  }

  local dynamic = {}
  local merged = {}

  local function refresh()
    PopulateUtilitySpellGroups(self, dynamic, state, refresh)
    MergeArgs(merged, {
      description = {
        type = "description",
        name = "Utility spells detected for this specialization.",
        order = 1,
      },
      addSpell = {
        type = "input",
        name = "Add Spell ID",
        order = 2,
        width = "half",
        get = function()
          return ""
        end,
        set = function(_, value)
          local spellID = tonumber(value)
          if not spellID then return end
          local class, specID = self:GetPlayerClassSpec()
          local lists = EnsurePlacementLists(self, class, specID)
          SetSpellPlacement(self, class, specID, spellID, "HIDDEN", #lists.HIDDEN + 1)
          if self.BuildFramesForSpec then self:BuildFramesForSpec() end
          refresh()
          NotifyOptionsChanged()
        end,
      },
      empty = {
        type = "description",
        name = "No utility spells recorded for this specialization.",
        order = 3,
        hidden = function()
          return state.hasSpells and state.hasSpells.UTILITY
        end,
      },
    }, dynamic)
  end

  refresh()

  return {
    type = "group",
    name = "Utility Cooldowns",
    args = merged,
  }
end
