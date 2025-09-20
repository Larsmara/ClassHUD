local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

local TRACKED_UNITS = { "player", "pet" }

ClassHUD.trackedBuffFrames = ClassHUD.trackedBuffFrames or {}
ClassHUD._trackedBuffFramePool = ClassHUD._trackedBuffFramePool or {}

local activeFrames = ClassHUD.trackedBuffFrames
local framePool = ClassHUD._trackedBuffFramePool

local function EnsureBuffContainer()
  if not UI.buffContainer then
    UI.buffContainer = CreateFrame("Frame", "ClassHUDTrackedBuffContainer", UI.anchor)
    UI.buffContainer:SetSize(1, 1)
  end
  UI.buffContainer:SetParent(UI.anchor)
  return UI.buffContainer
end

local function AcquireBuffFrame(buffID)
  local frame = framePool[buffID]
  if not frame then
    local container = EnsureBuffContainer()
    frame = CreateFrame("Frame", nil, container)
    frame:SetSize(32, 32)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(true)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(true)
    frame.cooldown:SetHideCountdownNumbers(true)

    frame.count = frame:CreateFontString(nil, "OVERLAY")
    frame.count:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.count:SetText("")
    frame.count:Hide()

    frame.buffID = buffID
    framePool[buffID] = frame
  end

  frame.count:SetFont(ClassHUD:FetchFont(ClassHUD.db.profile.buffFontSize or 12))
  frame:SetSize(32, 32)

  return frame
end

local function ResetFrame(frame)
  frame.icon:SetVertexColor(1, 1, 1, 1)
  frame.icon:SetDesaturated(false)
  frame.count:SetText("")
  frame.count:Hide()
  CooldownFrame_Clear(frame.cooldown)
  frame:Hide()
end

local function ExtractCooldown(info, spellID)
  local start, duration, charges, iconID

  if type(info) == "table" then
    if info.startTimeMS then start = info.startTimeMS / 1000 end
    if info.cooldownStartTimeMS then start = info.cooldownStartTimeMS / 1000 end
    if info.startTime then start = info.startTime end
    if info.cooldownStartTime then start = info.cooldownStartTime end

    if info.durationMS then duration = info.durationMS / 1000 end
    if info.cooldownDurationMS then duration = info.cooldownDurationMS / 1000 end
    if info.duration then duration = info.duration end
    if info.cooldownDuration then duration = info.cooldownDuration end

    charges = info.applications or info.charges or info.currentCharges or info.maxCharges
    iconID = info.iconTexture or info.iconID
  end

  if not start or not duration then
    if C_Spell and C_Spell.GetSpellCooldown and spellID then
      local cd = C_Spell.GetSpellCooldown(spellID)
      if cd and cd.startTime and cd.duration and cd.duration > 0 then
        start = cd.startTime
        duration = cd.duration
      end
    end
  end

  if not charges and C_Spell and C_Spell.GetSpellCharges and spellID then
    local ch = C_Spell.GetSpellCharges(spellID)
    if ch and ch.maxCharges and ch.maxCharges > 1 then
      charges = ch.currentCharges or ch.maxCharges
    end
  end

  return start, duration, charges, iconID
end

local function ApplyAuraVisuals(frame, aura, auraSpellID)
  local icon = aura and (aura.icon or (auraSpellID and C_Spell.GetSpellTexture(auraSpellID)))
  if icon then
    frame.icon:SetTexture(icon)
  end

  if aura and aura.duration and aura.duration > 0 and aura.expirationTime then
    CooldownFrame_Set(frame.cooldown, aura.expirationTime - aura.duration, aura.duration, true)
  else
    CooldownFrame_Clear(frame.cooldown)
  end

  local stacks = aura and (aura.applications or aura.stackCount or aura.charges)
  if stacks and stacks > 1 then
    frame.count:SetText(stacks)
    frame.count:Show()
  else
    frame.count:SetText("")
    frame.count:Hide()
  end

  if aura then
    frame.icon:SetDesaturated(false)
    frame.icon:SetVertexColor(1, 1, 1, 1)
  else
    frame.icon:SetDesaturated(true)
    frame.icon:SetVertexColor(0.7, 0.7, 0.7, 1)
  end
end

local function ApplyCooldownVisuals(frame, entry, info)
  local spellID = entry.spellID or entry.buffID
  local start, duration, charges, iconID = ExtractCooldown(info, spellID)

  if iconID then
    frame.icon:SetTexture(iconID)
  elseif spellID then
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if tex then frame.icon:SetTexture(tex) end
  end

  if start and duration and duration > 0 then
    CooldownFrame_Set(frame.cooldown, start, duration, true)
  else
    CooldownFrame_Clear(frame.cooldown)
  end

  if charges and charges > 1 then
    frame.count:SetText(charges)
    frame.count:Show()
  else
    frame.count:SetText("")
    frame.count:Hide()
  end

  frame.icon:SetDesaturated(duration and duration > 0)
  frame.icon:SetVertexColor(1, 1, 1, 1)
end

local function UpdateBuffFrame(entry)
  local buffID = entry.buffID
  if not buffID then return nil end

  local frame = AcquireBuffFrame(buffID)
  frame.buffID = buffID
  frame.entry = entry

  local aura, auraSpellID
  if entry.auraCandidates == nil then
    local snapshot = entry.snapshot
    if not snapshot then
      snapshot = ClassHUD:GetSnapshotEntry(entry.snapshotSpellID or buffID)
    end
    entry.auraCandidates = ClassHUD:GetAuraCandidatesForEntry(snapshot, buffID)
  end

  if entry.auraCandidates and #entry.auraCandidates > 0 then
    aura, auraSpellID = ClassHUD:FindAuraFromCandidates(entry.auraCandidates, TRACKED_UNITS)
  end

  if not aura then
    aura, auraSpellID = ClassHUD:GetAuraForSpell(buffID, TRACKED_UNITS)
  end

  if aura then
    ApplyAuraVisuals(frame, aura, auraSpellID)
  elseif entry.isTrackedBar then
    local info
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo and entry.cooldownID then
      info = C_CooldownViewer.GetCooldownViewerCooldownInfo(entry.cooldownID)
    end
    ApplyCooldownVisuals(frame, entry, info)
  else
    frame.icon:SetTexture(entry.iconID or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(buffID)) or 134400)
    ApplyAuraVisuals(frame, nil, nil)
  end

  frame:Show()
  return frame
end

local function SortEntries(entries)
  table.sort(entries, function(a, b)
    if a.order and b.order and a.order ~= b.order then
      return a.order < b.order
    end
    return (a.name or "") < (b.name or "")
  end)
end

function ClassHUD:BuildTrackedBuffsFromBlizzard()
  local results = {}

  if not (C_CooldownViewer and Enum and Enum.CooldownViewerCategory) then
    return results
  end

  local class, specID = self:GetPlayerClassSpec()
  local snapshot = self:GetSnapshotForSpec(class, specID, false)

  local category = Enum.CooldownViewerCategory.TrackedBuffs
  local ids = C_CooldownViewer.GetCooldownViewerCategorySet and C_CooldownViewer.GetCooldownViewerCategorySet(category)
  if type(ids) ~= "table" then
    return results
  end

  for index, cooldownID in ipairs(ids) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    if info then
      local spellID = info.spellID or info.overrideSpellID
      if not spellID and type(info.linkedSpellIDs) == "table" then
        spellID = info.linkedSpellIDs[1]
      end

      if spellID then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        table.insert(results, {
          buffID = spellID,
          spellID = spellID,
          cooldownID = cooldownID,
          iconID = spellInfo and spellInfo.iconID,
          name = spellInfo and spellInfo.name,
          order = index,
          source = "trackedBuff",
          snapshot = snapshot and snapshot[spellID] or nil,
          snapshotSpellID = spellID,
        })
      end
    end
  end

  return results
end

function ClassHUD:BuildTrackedBarsAsBuffs()
  local results = {}

  if not (C_CooldownViewer and Enum and Enum.CooldownViewerCategory) then
    return results
  end

  local class, specID = self:GetPlayerClassSpec()
  local snapshot = self:GetSnapshotForSpec(class, specID, false)

  local category = Enum.CooldownViewerCategory.TrackedBars
  local ids = C_CooldownViewer.GetCooldownViewerCategorySet and C_CooldownViewer.GetCooldownViewerCategorySet(category)
  if type(ids) ~= "table" then
    return results
  end

  for index, cooldownID in ipairs(ids) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    if info then
      local spellID = info.spellID or info.overrideSpellID
      if not spellID and type(info.linkedSpellIDs) == "table" then
        spellID = info.linkedSpellIDs[1]
      end

      if spellID then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        table.insert(results, {
          buffID = spellID,
          spellID = spellID,
          cooldownID = cooldownID,
          iconID = spellInfo and spellInfo.iconID,
          name = spellInfo and spellInfo.name,
          order = 1000 + index,
          source = "trackedBar",
          snapshot = snapshot and snapshot[spellID] or nil,
          snapshotSpellID = spellID,
          isTrackedBar = true,
        })
      end
    end
  end

  return results
end

local function CollectCustomEntries(addon)
  local results = {}
  local class, specID = addon:GetPlayerClassSpec()
  local custom = addon:GetCustomTrackedBuffs(class, specID, false)
  if not custom then return results end

  for spellID in pairs(custom) do
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    table.insert(results, {
      buffID = spellID,
      spellID = spellID,
      iconID = spellInfo and spellInfo.iconID,
      name = spellInfo and spellInfo.name,
      order = 2000 + spellID,
      source = "custom",
      snapshot = nil,
      snapshotSpellID = spellID,
    })
  end

  return results
end

local function CollectVisibleEntries(addon)
  local class, specID = addon:GetPlayerClassSpec()
  local hidden = addon:GetHiddenTrackedBuffs(class, specID, false) or {}

  local byID, ordered = {}, {}

  for _, entry in ipairs(addon:BuildTrackedBuffsFromBlizzard()) do
    if not hidden[entry.buffID] then
      byID[entry.buffID] = entry
      table.insert(ordered, entry)
    end
  end

  for _, entry in ipairs(addon:BuildTrackedBarsAsBuffs()) do
    if not hidden[entry.buffID] then
      local existing = byID[entry.buffID]
      if existing then
        existing.isTrackedBar = true
        existing.cooldownID = existing.cooldownID or entry.cooldownID
        existing.iconID = existing.iconID or entry.iconID
      else
        byID[entry.buffID] = entry
        table.insert(ordered, entry)
      end
    end
  end

  for _, entry in ipairs(CollectCustomEntries(addon)) do
    if not hidden[entry.buffID] and not byID[entry.buffID] then
      byID[entry.buffID] = entry
      table.insert(ordered, entry)
    end
  end

  SortEntries(ordered)
  return ordered
end

local function LayoutTrackedIcons(frames)
  local container = EnsureBuffContainer()
  local settings = ClassHUD.db.profile.trackedBuffBar or {}
  local width = ClassHUD.db.profile.width or 250
  local perRow = math.max(settings.perRow or 8, 1)
  local spacingX = settings.spacingX or 4
  local spacingY = settings.spacingY or 4
  local offsetX = settings.offsetX or 0
  local offsetY = settings.offsetY or 8
  local align = settings.align or "CENTER"

  container:ClearAllPoints()
  local anchor = (UI.attachments and UI.attachments.CAST) or UI.anchor
  container:SetPoint("BOTTOM", anchor, "TOP", offsetX, offsetY)
  container:SetWidth(width)

  if #frames == 0 then
    container:SetHeight(1)
    container:Hide()
    return
  end

  local size = math.floor((width - (perRow - 1) * spacingX) / perRow + 0.5)
  if size < 16 then size = 16 end

  local rows = math.ceil(#frames / perRow)

  for index, frame in ipairs(frames) do
    frame:SetParent(container)
    frame:ClearAllPoints()
    frame:SetSize(size, size)

    local row = math.floor((index - 1) / perRow)
    local col = (index - 1) % perRow
    local iconsInRow = math.min(perRow, #frames - row * perRow)
    local rowWidth = iconsInRow * size + math.max(0, iconsInRow - 1) * spacingX

    local x
    if align == "LEFT" then
      x = col * (size + spacingX)
    elseif align == "RIGHT" then
      x = (width - rowWidth) + col * (size + spacingX)
    else
      local start = (width - rowWidth) / 2
      x = start + col * (size + spacingX)
    end

    frame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x, row * (size + spacingY))
  end

  local totalHeight = rows * size + math.max(0, rows - 1) * spacingY
  container:SetHeight(totalHeight)
  container:Show()
end

function ClassHUD:BuildTrackedBuffFrames()
  local container = EnsureBuffContainer()

  for _, frame in ipairs(activeFrames) do
    ResetFrame(frame)
  end
  wipe(activeFrames)

  if not (self.db and self.db.profile and self.db.profile.show and self.db.profile.show.buffs) then
    container:Hide()
    return
  end

  local entries = CollectVisibleEntries(self)
  if #entries == 0 then
    container:Hide()
    return
  end

  for _, entry in ipairs(entries) do
    local frame = UpdateBuffFrame(entry)
    if frame then
      table.insert(activeFrames, frame)
    end
  end

  LayoutTrackedIcons(activeFrames)
end

function ClassHUD:UpdateAllFrames()
  self:BuildTrackedBuffFrames()
end

function ClassHUD:BuildFramesForSpec()
  self:BuildTrackedBuffFrames()
end
