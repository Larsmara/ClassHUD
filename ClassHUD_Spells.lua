-- ClassHUD_Spells.lua (CDM-liste -> egen visningslogikk)
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

ClassHUD.spellFrames = ClassHUD.spellFrames or {}
ClassHUD.trackedBuffFrames = ClassHUD.trackedBuffFrames or {}
ClassHUD.trackedBarFrames = ClassHUD.trackedBarFrames or {}
ClassHUD._trackedBuffFramePool = ClassHUD._trackedBuffFramePool or {}
ClassHUD._trackedBarFramePool = ClassHUD._trackedBarFramePool or {}

local activeFrames = {}
local trackedBuffPool = ClassHUD._trackedBuffFramePool
local trackedBarPool = ClassHUD._trackedBarFramePool

local INACTIVE_BAR_COLOR = { r = 0.25, g = 0.25, b = 0.25, a = 0.6 }
local TRACKED_UNITS = { "player", "pet" }

local function EnsureAttachment(name)
  if not UI.anchor then return nil end
  UI.attachments = UI.attachments or {}
  if not UI.attachments[name] then
    UI.attachments[name] = CreateFrame("Frame", "ClassHUDAttach" .. name, UI.anchor)
    UI.attachments[name]._height = 0
  end
  return UI.attachments[name]
end

local function CopyColor(tbl)
  if type(tbl) ~= "table" then return nil end
  return {
    r = tbl.r or 1,
    g = tbl.g or 1,
    b = tbl.b or 1,
    a = tbl.a or 1,
  }
end

local function CollectAuraSpellIDs(entry, primaryID)
  return ClassHUD:GetAuraCandidatesForEntry(entry, primaryID)
end

local function FindAuraFromCandidates(candidates)
  return ClassHUD:FindAuraFromCandidates(candidates, TRACKED_UNITS)
end

-- ==================================================
-- Helpers
-- ==================================================

---Refreshes the in-memory snapshot cache used by spell frames.
function ClassHUD:RefreshSnapshotCache()
  self.cdmSpells = {}

  local snapshot = self:GetSnapshotForSpec(nil, nil, false)
  if not snapshot then return end

  for spellID, entry in pairs(snapshot) do
    if entry.categories then
      self.cdmSpells[spellID] = entry.categories
    end
  end
end

-- ==================================================
-- Frame factory
-- ==================================================
local function CreateSpellFrame(spellID)
  if ClassHUD.spellFrames[spellID] then
    return ClassHUD.spellFrames[spellID]
  end

  local frame = CreateFrame("Frame", "ClassHUDSpell" .. spellID, UI.anchor)
  frame:SetSize(40, 40)

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetAllPoints(frame)

  frame.count = frame:CreateFontString(nil, "OVERLAY")
  frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.count:SetFont(ClassHUD:FetchFont(14))
  frame.count:Hide()

  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame)
  frame.cooldown:SetHideCountdownNumbers(true)
  frame.cooldown.noCooldownCount = true

  frame.cooldownText = frame:CreateFontString(nil, "OVERLAY")
  frame.cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.cooldownText:SetFont(ClassHUD:FetchFont(16))
  frame.cooldownText:Hide()

  frame._cooldownEnd = nil
  frame.spellID = spellID
  frame.isGlowing = false

  ClassHUD.spellFrames[spellID] = frame

  frame:SetScript("OnUpdate", function(selfFrame)
    if selfFrame._cooldownEnd then
      local remain = selfFrame._cooldownEnd - GetTime()
      if remain <= 0 then
        selfFrame._cooldownEnd = nil
        selfFrame.cooldownText:Hide()
        selfFrame.icon:SetDesaturated(false)
      else
        selfFrame.cooldownText:SetText(ClassHUD.FormatSeconds(remain))
        selfFrame.cooldownText:Show()
      end
    end
  end)

  return frame
end

-- ==================================================
-- Layout helpers (bruker dine UI.attachments)
-- ==================================================

-- ==========================================================
-- Tracked Buffs Bar (over TopBar, dynamisk)
-- ==========================================================

local function CreateBuffFrame(buffID)
  if trackedBuffPool[buffID] then
    return trackedBuffPool[buffID]
  end

  local parent = (UI.attachments and UI.attachments.TRACKED_ICONS) or UI.anchor
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(32, 32)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(true)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cooldown:SetAllPoints(true)

  f.count = f:CreateFontString(nil, "OVERLAY")
  f.count:SetPoint("BOTTOMRIGHT", -2, 2)
  f.count:SetFont(ClassHUD:FetchFont(12))
  f.count:SetText("")

  f.buffID = buffID
  trackedBuffPool[buffID] = f

  return f
end

local function OnTrackedBarUpdate(self)
  if not self._duration or not self._expiration then
    self:SetScript("OnUpdate", nil)
    return
  end

  local remaining = self._expiration - GetTime()
  if remaining < 0 then remaining = 0 end

  self:SetValue(remaining)

  if self._showTimer and self.timer then
    self.timer:SetText(ClassHUD.FormatSeconds(remaining))
    self.timer:Show()
  elseif self.timer then
    self.timer:Hide()
  end

  if remaining <= 0 then
    self:SetScript("OnUpdate", nil)
    ClassHUD:UpdateTrackedBarFrame(self)
  end
end

local function CreateTrackedBarFrame(buffID)
  if trackedBarPool[buffID] then
    return trackedBarPool[buffID]
  end

  local parent = (UI.attachments and UI.attachments.TRACKED_BARS) or UI.anchor
  local height = ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.trackedBuffBar
      and ClassHUD.db.profile.trackedBuffBar.height or 16

  local bar = ClassHUD:CreateStatusBar(parent, height)
  bar.buffID = buffID
  bar.auraSpellIDs = { buffID }
  bar.text:Hide()
  bar.icon = bar:CreateTexture(nil, "ARTWORK")
  bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  bar.icon:Hide()

  bar.label = bar:CreateFontString(nil, "OVERLAY")
  bar.label:SetFont(ClassHUD:FetchFont(12))
  bar.label:SetJustifyH("LEFT")
  bar.label:SetPoint("LEFT", bar, "LEFT", 4, 0)

  bar.timer = bar:CreateFontString(nil, "OVERLAY")
  bar.timer:SetFont(ClassHUD:FetchFont(12))
  bar.timer:SetJustifyH("RIGHT")
  bar.timer:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -4, -2)
  bar.timer:Hide()

  bar.stacks = bar:CreateFontString(nil, "OVERLAY")
  bar.stacks:SetFont(ClassHUD:FetchFont(12))
  bar.stacks:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -4, 2)
  bar.stacks:SetJustifyH("RIGHT")
  bar.stacks:Hide()

  bar._duration = nil
  bar._expiration = nil
  bar._showTimer = true
  bar._activeColor = CopyColor(ClassHUD:GetDefaultTrackedBarColor())
  bar._inactiveColor = CopyColor(INACTIVE_BAR_COLOR)
  bar.cooldownSpellID = buffID

  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:SetScript("OnUpdate", nil)

  trackedBarPool[buffID] = bar
  return bar
end

local function LayoutTrackedBars(barFrames, opts)
  local container = EnsureAttachment("TRACKED_BARS")
  if not container then return end

  local settings = ClassHUD.db.profile.trackedBuffBar or {}
  local width    = ClassHUD.db.profile.width or 250
  local spacingY = settings.spacingY or 4
  local barHeight = settings.height or 16
  local topPadding = 0

  if #barFrames > 0 then
    topPadding = (opts and opts.topPadding) or 0
  end

  container:SetWidth(width)

  local currentY = topPadding
  local totalHeight = (#barFrames > 0) and topPadding or 0

  for index, frame in ipairs(barFrames) do
    frame:SetParent(container)
    frame:ClearAllPoints()
    frame:SetHeight(barHeight)
    frame:SetWidth(width)
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -currentY)
    frame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -currentY)
    frame:Show()

    currentY = currentY + barHeight
    totalHeight = currentY

    if index < #barFrames then
      currentY = currentY + spacingY
      totalHeight = currentY
    end
  end

  if #barFrames == 0 then
    container._height = 0
    container:SetHeight(0)
    container._afterGap = nil
  else
    totalHeight = math.max(totalHeight, 0)
    container._height = totalHeight
    container:SetHeight(totalHeight)
    container._afterGap = nil
  end

  container:Show()
end

local function LayoutTrackedIcons(iconFrames, opts)
  local container = EnsureAttachment("TRACKED_ICONS")
  if not container then return end

  local settings = ClassHUD.db.profile.trackedBuffBar or {}
  local width    = ClassHUD.db.profile.width or 250
  local perRow   = math.max(settings.perRow or 8, 1)
  local spacingX = settings.spacingX or 4
  local spacingY = settings.spacingY or 4
  local align    = settings.align or "CENTER"
  local topPadding = 0

  if #iconFrames > 0 then
    topPadding = (opts and opts.topPadding) or 0
  end

  container:SetWidth(width)

  local totalHeight = 0

  if #iconFrames > 0 then
    local size = (width - (perRow - 1) * spacingX) / perRow
    if size < 1 then size = 1 end

    local count = #iconFrames
    local rowsUsed = math.ceil(count / perRow)

    for index, frame in ipairs(iconFrames) do
      frame:SetParent(container)
      frame:SetSize(size, size)
      frame:ClearAllPoints()

      local row = math.floor((index - 1) / perRow)
      local col = (index - 1) % perRow

      local remaining = count - row * perRow
      local rowCount = math.min(perRow, remaining)
      local rowWidth = rowCount * size + math.max(0, rowCount - 1) * spacingX

      local startX
      if align == "LEFT" then
        startX = 0
      elseif align == "RIGHT" then
        startX = width - rowWidth
      else
        startX = (width - rowWidth) / 2
      end

      frame:SetPoint("TOPLEFT", container, "TOPLEFT",
        startX + col * (size + spacingX),
        -(topPadding + row * (size + spacingY)))
      frame:Show()
    end

    local iconsHeight = rowsUsed * size + math.max(0, rowsUsed - 1) * spacingY
    totalHeight = topPadding + iconsHeight
  else
    totalHeight = 0
  end

  totalHeight = math.max(totalHeight, 0)
  container._height = totalHeight
  container:SetHeight(totalHeight)
  container._afterGap = nil
  container:Show()
end


local function LayoutTopBar(frames)
  local container = EnsureAttachment("TOP")
  if not container then return end

  local width    = ClassHUD.db.profile.width or 250
  local perRow   = math.max(ClassHUD.db.profile.topBar.perRow or 8, 1)
  local spacingX = ClassHUD.db.profile.topBar.spacingX or 4
  local spacingY = ClassHUD.db.profile.topBar.spacingY or 4
  local yOffset  = ClassHUD.db.profile.topBar.yOffset or 0
  local grow     = ClassHUD.db.profile.topBar.grow or "DOWN"

  container:SetWidth(width)

  if #frames == 0 then
    container._height = 0
    container:SetHeight(0)
    container._afterGap = nil
    container:Show()
    return
  end

  local size     = (width - (perRow - 1) * spacingX) / perRow
  local count    = #frames
  local rowsUsed = math.ceil(count / perRow)

  for index, frame in ipairs(frames) do
    frame:SetParent(container)
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local row = math.floor((index - 1) / perRow)
    local col = (index - 1) % perRow

    local remaining = count - row * perRow
    local rowCount = math.min(perRow, remaining)
    local rowWidth = rowCount * size + math.max(0, rowCount - 1) * spacingX
    local startX = (width - rowWidth) / 2

    local x = startX + col * (size + spacingX)
    local y = yOffset + row * (size + spacingY)

    if grow == "UP" then
      frame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x, y)
    else
      frame:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
    end

    frame:Show()
  end

  local totalHeight = yOffset + rowsUsed * size + math.max(0, rowsUsed - 1) * spacingY
  totalHeight = math.max(totalHeight, 0)

  container._height = totalHeight
  container:SetHeight(totalHeight)
  container._afterGap = nil
  container:Show()
end


local function LayoutSideBar(frames, side)
  if not UI.attachments or not UI.attachments[side] then return end
  local size    = ClassHUD.db.profile.sideBars.size or 36
  local spacing = ClassHUD.db.profile.sideBars.spacing or 4
  local offset  = ClassHUD.db.profile.sideBars.offset or 6
  local yOffset = ClassHUD.db.profile.sideBars.yOffset or 0
  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()
    local y = yOffset - (i - 1) * (size + spacing)
    if side == "LEFT" then
      frame:SetPoint("TOPRIGHT", UI.attachments.LEFT, "TOPLEFT", -offset, y)
    elseif side == "RIGHT" then
      frame:SetPoint("TOPLEFT", UI.attachments.RIGHT, "TOPRIGHT", offset, y)
    end
  end
end

local function LayoutBottomBar(frames)
  local container = EnsureAttachment("BOTTOM")
  if not container then return end

  local width    = ClassHUD.db.profile.width or 250
  local perRow   = math.max(ClassHUD.db.profile.bottomBar.perRow or 8, 1)
  local spacingX = ClassHUD.db.profile.bottomBar.spacingX or 4
  local spacingY = ClassHUD.db.profile.bottomBar.spacingY or 4
  local yOffset  = ClassHUD.db.profile.bottomBar.yOffset or 0

  container:SetWidth(width)

  if #frames == 0 then
    container._height = 0
    container:SetHeight(0)
    container._afterGap = nil
    container:Show()
    return
  end

  local size     = (width - (perRow - 1) * spacingX) / perRow
  local count    = #frames
  local rowsUsed = math.ceil(count / perRow)
  local topPadding = spacingY + yOffset

  for index, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:SetParent(container)
    frame:ClearAllPoints()

    local row = math.floor((index - 1) / perRow)
    local col = (index - 1) % perRow
    local remaining = count - row * perRow
    local rowCount = math.min(perRow, remaining)
    local rowWidth = rowCount * size + math.max(0, rowCount - 1) * spacingX
    local startX   = (width - rowWidth) / 2

    frame:SetPoint("TOPLEFT", container, "TOPLEFT",
      startX + col * (size + spacingX),
      -(topPadding + row * (size + spacingY)))
    frame:Show()
  end

  local totalHeight = topPadding + rowsUsed * size + math.max(0, rowsUsed - 1) * spacingY
  totalHeight = math.max(totalHeight, 0)
  container._height = totalHeight
  container:SetHeight(totalHeight)
  container._afterGap = nil
  container:Show()
end

local function PopulateBuffIconFrame(frame, buffID, aura, entry)
  frame:SetParent(EnsureAttachment("TRACKED_ICONS") or UI.anchor)

  local iconID = entry and entry.iconID
  if not iconID then
    local info = C_Spell.GetSpellInfo(buffID)
    iconID = info and info.iconID
  end

  frame.icon:SetTexture(iconID or C_Spell.GetSpellTexture(buffID) or 134400)

  if aura.expirationTime and aura.duration and aura.duration > 0 then
    CooldownFrame_Set(frame.cooldown, aura.expirationTime - aura.duration, aura.duration, true)
  else
    CooldownFrame_Clear(frame.cooldown)
  end

  local stacks = aura.applications or aura.stackCount or aura.charges
  if stacks and stacks > 1 then
    frame.count:SetText(stacks)
    frame.count:Show()
  else
    frame.count:Hide()
  end

  frame:Show()
end

local function ConfigureTrackedBarFrame(frame, entry, config)
  frame:SetParent(EnsureAttachment("TRACKED_BARS") or UI.anchor)

  frame.snapshotEntry = entry
  frame.config = config

  local candidates = CollectAuraSpellIDs(entry, frame.buffID)
  local displaySpellID, displayName, displayIcon = ClassHUD:ResolveTrackedBarDisplay(entry, frame.buffID, candidates)

  frame.auraSpellIDs = candidates
  frame.displaySpellID = displaySpellID
  frame.cooldownSpellID = (entry and entry.spellID) or frame.buffID

  local color = CopyColor(config.barColor) or CopyColor(ClassHUD:GetDefaultTrackedBarColor())
  frame._activeColor = color
  frame._inactiveColor = frame._inactiveColor or CopyColor(INACTIVE_BAR_COLOR)

  frame:SetStatusBarColor(color.r, color.g, color.b, color.a)

  frame.label:SetFont(ClassHUD:FetchFont(12))
  frame.timer:SetFont(ClassHUD:FetchFont(12))
  if frame.stacks then
    frame.stacks:SetFont(ClassHUD:FetchFont(12))
    frame.stacks:Hide()
  end

  frame.defaultLabel = displayName
  frame.label:SetText(displayName)

  local iconID = displayIcon or (displaySpellID and C_Spell.GetSpellTexture(displaySpellID))
  if not iconID then
    iconID = entry and entry.iconID
  end
  if not iconID and frame.buffID then
    iconID = C_Spell.GetSpellTexture(frame.buffID)
  end

  local height = ClassHUD.db.profile.trackedBuffBar.height or 16

  if config.barShowIcon ~= false then
    frame.icon:SetTexture(iconID or 134400)
    frame.icon:SetSize(height, height)
    frame.icon:Show()
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.label:ClearAllPoints()
    frame.label:SetPoint("LEFT", frame.icon, "RIGHT", 4, 0)
  else
    frame.icon:Hide()
    frame.label:ClearAllPoints()
    frame.label:SetPoint("LEFT", frame, "LEFT", 4, 0)
  end

  frame._showTimer = config.barShowTimer ~= false
  if not frame._showTimer and frame.timer then
    frame.timer:Hide()
  end
  if frame.timer then
    frame.timer:ClearAllPoints()
    frame.timer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -2)
  end
end

local function UpdateTrackedBarFrame(frame)
  local buffID = frame.buffID
  if not buffID then return false end

  local aura, auraSpellID = FindAuraFromCandidates(frame.auraSpellIDs)
  if aura then
    frame:Show()

    local texture = aura.icon or (auraSpellID and C_Spell.GetSpellTexture(auraSpellID))
    if frame.icon and frame.icon:IsShown() and texture then
      frame.icon:SetTexture(texture)
    end

    local displayName = aura.name or (auraSpellID and C_Spell.GetSpellName(auraSpellID)) or frame.defaultLabel
    if displayName then
      frame.label:SetText(displayName)
    end

    local stacks = aura.applications or aura.stackCount or aura.charges
    stacks = tonumber(stacks)
    if frame.stacks then
      if stacks and stacks > 1 then
        frame.stacks:SetText(tostring(stacks))
        frame.stacks:Show()
      else
        frame.stacks:SetText("")
        frame.stacks:Hide()
      end
    end

    frame:SetStatusBarColor(frame._activeColor.r, frame._activeColor.g, frame._activeColor.b, frame._activeColor.a)

    if aura.duration and aura.duration > 0 and aura.expirationTime then
      frame._duration = aura.duration
      frame._expiration = aura.expirationTime
      frame:SetMinMaxValues(0, aura.duration)
      frame:SetValue(math.max(0, aura.expirationTime - GetTime()))
      frame:SetScript("OnUpdate", OnTrackedBarUpdate)
      OnTrackedBarUpdate(frame)
    else
      frame._duration = nil
      frame._expiration = nil
      frame:SetMinMaxValues(0, 1)
      frame:SetValue(1)
      frame:SetScript("OnUpdate", nil)
      if frame.timer then
        frame.timer:SetText("")
        frame.timer:Hide()
      end
    end

    return true
  end

  frame._duration = nil
  frame._expiration = nil
  frame:SetMinMaxValues(0, 1)
  frame:SetValue(0)
  frame:SetStatusBarColor(frame._inactiveColor.r, frame._inactiveColor.g, frame._inactiveColor.b, frame._inactiveColor.a)
  frame:SetScript("OnUpdate", nil)

  if frame.timer then
    frame.timer:SetText("")
    frame.timer:Hide()
  end
  if frame.stacks then
    frame.stacks:SetText("")
    frame.stacks:Hide()
  end

  if frame.defaultLabel then
    frame.label:SetText(frame.defaultLabel)
  end

  frame:Hide()
  return false
end

function ClassHUD:BuildTrackedBuffFrames()
  if self.trackedBuffFrames then
    for _, frame in ipairs(self.trackedBuffFrames) do
      frame:Hide()
    end
  end
  if self.trackedBarFrames then
    for _, frame in ipairs(self.trackedBarFrames) do
      frame:Hide()
      frame:SetScript("OnUpdate", nil)
    end
  end

  wipe(self.trackedBuffFrames)
  wipe(self.trackedBarFrames)

  EnsureAttachment("TRACKED_ICONS")
  EnsureAttachment("TRACKED_BARS")

  local function resetLayouts()
    LayoutTrackedBars({}, nil)
    LayoutTrackedIcons({}, nil)
    if self.Layout then self:Layout() end
  end

  if not self.db.profile.show.buffs then
    resetLayouts()
    return
  end

  local class, specID = self:GetPlayerClassSpec()
  if not specID or specID == 0 then
    resetLayouts()
    return
  end

  local tracked = self:GetProfileTable(false, "trackedBuffs", class, specID)
  if not tracked then
    resetLayouts()
    return
  end

  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  local ordered = {}

  for buffID, _ in pairs(tracked) do
    local config = self:GetTrackedEntryConfig(class, specID, buffID, false)
    if config then
      local entry = snapshot and snapshot[buffID]
      local order = math.huge
      if entry and entry.categories then
        if entry.categories.bar and entry.categories.bar.order then
          order = math.min(order, entry.categories.bar.order)
        end
        if entry.categories.buff and entry.categories.buff.order then
          order = math.min(order, entry.categories.buff.order)
        end
      end
      local name = entry and entry.name or C_Spell.GetSpellName(buffID) or ("Spell " .. buffID)
      table.insert(ordered, {
        buffID = buffID,
        config = config,
        entry = entry,
        order = order,
        name = name,
      })
    end
  end

  table.sort(ordered, function(a, b)
    if a.order == b.order then
      return a.name < b.name
    end
    return a.order < b.order
  end)

  local iconFrames = {}
  local barFrames = {}

  for _, info in ipairs(ordered) do
    local buffID = info.buffID
    local config = info.config
    local entry = info.entry
    local auraCandidates = CollectAuraSpellIDs(entry, buffID)

    local hasBar = entry and entry.categories and entry.categories.bar
    if config.showBar and not hasBar then
      config.showBar = false
    end
    if config.showBar and hasBar then
      local bar = CreateTrackedBarFrame(buffID)
      ConfigureTrackedBarFrame(bar, entry, config)
      if UpdateTrackedBarFrame(bar) then
        table.insert(barFrames, bar)
      else
        bar:Hide()
      end
    end

    if config.showIcon then
      local aura = FindAuraFromCandidates(auraCandidates)
      if aura then
        local iconFrame = CreateBuffFrame(buffID)
        PopulateBuffIconFrame(iconFrame, buffID, aura, entry)
        table.insert(iconFrames, iconFrame)
      end
    end
  end

  self.trackedBuffFrames = iconFrames
  self.trackedBarFrames = barFrames
  local settings = self.db.profile.trackedBuffBar or {}
  local yOffset = settings.yOffset or 0

  local barTopPadding = (#barFrames > 0) and yOffset or 0
  local iconTopPadding = (#barFrames == 0 and #iconFrames > 0) and yOffset or 0
  LayoutTrackedBars(barFrames, { topPadding = barTopPadding })
  LayoutTrackedIcons(iconFrames, { topPadding = iconTopPadding })

  if self.Layout then
    self:Layout()
  end
end

-- ==================================================
-- UpdateSpellFrame
-- ==================================================
local function UpdateSpellFrame(frame)
  local sid = frame.spellID
  if not sid then return end

  -- Slå opp i vår motor
  local data = ClassHUD.cdmSpells and ClassHUD.cdmSpells[sid]

  -- =====================
  -- Ikon
  -- =====================
  local entry = ClassHUD:GetSnapshotEntry(sid)
  local iconID = entry and entry.iconID
  if not iconID then
    local s = C_Spell.GetSpellInfo(sid)
    iconID = s and s.iconID
  end
  frame.icon:SetTexture(iconID or 134400)

  -- =====================
  -- Cooldown
  -- =====================
  local cdStart, cdDuration
  local shouldDesaturate = false

  -- =====================
  -- Charges
  -- =====================
  local ch = C_Spell.GetSpellCharges(sid)
  local chargesShown = false
  if ch and ch.maxCharges and ch.maxCharges > 1 then
    local current = ch.currentCharges or 0
    frame.count:SetText(current)
    frame.count:Show()
    chargesShown = true

    if current <= 0 and ch.cooldownStartTime and ch.cooldownDuration and ch.cooldownDuration > 0 then
      cdStart = ch.cooldownStartTime
      cdDuration = ch.cooldownDuration
      shouldDesaturate = true
    end
  else
    frame.count:Hide()
    local cd = C_Spell.GetSpellCooldown(sid)
    if cd and cd.startTime and cd.duration and cd.duration > 0 then
      cdStart = cd.startTime
      cdDuration = cd.duration
      shouldDesaturate = true
    end
  end

  if cdStart and cdDuration then
    CooldownFrame_Set(frame.cooldown, cdStart, cdDuration, true)
    frame._cooldownEnd = cdStart + cdDuration
  else
    CooldownFrame_Clear(frame.cooldown)
    frame._cooldownEnd = nil
  end

  frame.icon:SetDesaturated(shouldDesaturate)

  -- =====================
  -- Aura overlay + glow
  -- =====================
  local auraID = nil
  if data then
    -- Bruk override/linked fra buff/bar hvis de finnes
    if data.buff then
      auraID = data.buff.overrideSpellID or (data.buff.linkedSpellIDs and data.buff.linkedSpellIDs[1]) or
          data.buff.spellID
    elseif data.bar then
      auraID = data.bar.overrideSpellID or (data.bar.linkedSpellIDs and data.bar.linkedSpellIDs[1]) or data.bar.spellID
    end
  end
  auraID = auraID or sid

  local aura = ClassHUD:GetAuraForSpell(auraID)

  if aura then
    local remain = (aura.expirationTime or 0) - GetTime()
    local stacks = aura.applications or aura.stackCount or aura.charges or 0

    -- Glow alltid når aura er aktiv
    if not frame.isGlowing then
      ActionButtonSpellAlertManager:ShowAlert(frame)
      frame.isGlowing = true
    end

    -- Overlay gul cooldown hvis aura har timer
    if aura.duration and aura.duration > 0 and aura.expirationTime then
      frame.cooldown:SetSwipeColor(1, 0.85, 0.1, 0.9)
      CooldownFrame_Set(frame.cooldown, aura.expirationTime - aura.duration, aura.duration, true)
      frame._cooldownEnd = aura.expirationTime
      frame.icon:SetVertexColor(1, 1, 0.3)
    end

    -- Hvis aura har stacks og vi ikke viser charges, vis stacks
    if stacks > 1 and not chargesShown then
      frame.count:SetText(stacks)
      frame.count:Show()
    end
  else
    -- Ingen aura aktiv
    if frame.isGlowing then
      -- Bare slå av glow hvis ikke en tracked buff holder den på
      local keepGlow = false
      local map = ClassHUD.trackedBuffToSpell
      if map then
        for buffID, mappedSpellID in pairs(map) do
          if mappedSpellID == frame.spellID then
            local auraCheck = ClassHUD:GetAuraForSpell(buffID)
            if auraCheck then
              keepGlow = true
              break
            end
          end
        end
      end
      if not keepGlow then
        ActionButtonSpellAlertManager:HideAlert(frame)
        frame.isGlowing = false
      end
    end
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.8)
    frame.icon:SetVertexColor(1, 1, 1)
  end
end

-- ==================================================
-- Public API (kalles fra ClassHUD.lua events)
-- ==================================================
ClassHUD.UpdateTrackedBarFrame = UpdateTrackedBarFrame

function ClassHUD:UpdateAllFrames()
  self:RefreshSnapshotCache()
  for _, f in ipairs(activeFrames) do
    UpdateSpellFrame(f)
  end

  if self.BuildTrackedBuffFrames then
    self:BuildTrackedBuffFrames()
  end

  -- Før auto-map, håndter manuelle buffLinks fra DB
  local class, specID = self:GetPlayerClassSpec()
  if not specID or specID == 0 then
    return
  end

  local links    = (ClassHUD.db.profile.buffLinks[class] and ClassHUD.db.profile.buffLinks[class][specID]) or {}

  for buffID, spellID in pairs(links) do
    local aura = C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(buffID)
    if not aura and UnitExists("pet") and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
      aura = C_UnitAuras.GetAuraDataBySpellID("pet", buffID)
    end
    if aura then
      local frame = self.spellFrames[spellID]
      if frame and not frame.isGlowing then
        ActionButtonSpellAlertManager:ShowAlert(frame)
        frame.isGlowing = true
      end
    end
  end

  -- Glow spells basert på tracked buff matches
  if self.trackedBuffToSpell then
    for buffID, spellID in pairs(self.trackedBuffToSpell) do
      local aura = self:GetAuraForSpell(buffID)
      if aura then
        local frame = self.spellFrames[spellID]
        if frame and not frame.isGlowing then
          ActionButtonSpellAlertManager:ShowAlert(frame)
          frame.isGlowing = true
        end
      end
    end
  end
end

function ClassHUD:BuildFramesForSpec()
  for _, f in ipairs(activeFrames) do f:Hide() end
  wipe(activeFrames)

  if self.spellFrames then
    for _, frame in pairs(self.spellFrames) do
      frame.snapshotEntry = nil
    end
  end

  self.trackedBuffToSpell = {}

  local class, specID = self:GetPlayerClassSpec()
  if not specID or specID == 0 then
    return
  end

  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  if not snapshot or next(snapshot) == nil then
    self.cdmSpells = {}
    return
  end

  self:RefreshSnapshotCache()

  local built = {}

  local function acquire(spellID)
    local frame = CreateSpellFrame(spellID)
    frame:Show()
    frame.snapshotEntry = snapshot[spellID]
    if not built[spellID] then
      table.insert(activeFrames, frame)
      built[spellID] = true
    end
    return frame
  end

  local function collect(category)
    local list = {}
    self:ForEachSnapshotEntry(category, function(spellID, entry, categoryData)
      table.insert(list, { spellID = spellID, entry = entry, data = categoryData })
    end)
    table.sort(list, function(a, b)
      local ao = (a.data and a.data.order) or math.huge
      local bo = (b.data and b.data.order) or math.huge
      if ao == bo then
        return (a.entry.name or "") < (b.entry.name or "")
      end
      return ao < bo
    end)
    return list
  end

  local placements = self.db.profile.utilityPlacement or {}

  local topFrames, bottomFrames = {}, {}
  local sideFrames = { LEFT = {}, RIGHT = {} }

  local function placeSpell(spellID, defaultPlacement)
    if built[spellID] then return end

    local placement = placements[spellID] or defaultPlacement or "TOP"
    if placement == "HIDDEN" then
      built[spellID] = true
      return
    end

    local frame = acquire(spellID)
    if placement == "TOP" then
      table.insert(topFrames, frame)
    elseif placement == "BOTTOM" then
      table.insert(bottomFrames, frame)
    elseif placement == "LEFT" or placement == "RIGHT" then
      table.insert(sideFrames[placement], frame)
    else
      table.insert(topFrames, frame)
    end
  end

  for _, item in ipairs(collect("essential")) do
    placeSpell(item.spellID, "TOP")
  end

  for _, item in ipairs(collect("utility")) do
    placeSpell(item.spellID, "HIDDEN")
  end

  for _, item in ipairs(collect("bar")) do
    placeSpell(item.spellID, "BOTTOM")
  end

  LayoutTopBar(topFrames)
  LayoutBottomBar(bottomFrames)
  if #sideFrames.LEFT > 0 then LayoutSideBar(sideFrames.LEFT, "LEFT") end
  if #sideFrames.RIGHT > 0 then LayoutSideBar(sideFrames.RIGHT, "RIGHT") end

  -- Auto-map tracked buffs to spells using snapshot descriptions
  self.db.profile.buffLinks = self.db.profile.buffLinks or {}
  self.db.profile.buffLinks[class] = self.db.profile.buffLinks[class] or {}
  self.db.profile.buffLinks[class][specID] = self.db.profile.buffLinks[class][specID] or {}

  for buffID, entry in pairs(snapshot) do
    if entry.categories and entry.categories.buff then
      local desc = entry.desc or C_Spell.GetSpellDescription(buffID)
      if desc then
        for spellID, frame in pairs(self.spellFrames) do
          if frame and frame.snapshotEntry then
            local spellName = C_Spell.GetSpellName(spellID)
            if spellName and string.find(desc, spellName, 1, true) then
              self.trackedBuffToSpell[buffID] = spellID

              local links = self.db.profile.buffLinks[class][specID]
              if not links[buffID] then
                links[buffID] = spellID
              end
              break
            end
          end
        end
      end
    end
  end

  self:UpdateAllFrames()

  if self.Layout then
    self:Layout()
  end
end
