-- ClassHUD_Spells.lua (CDM-liste -> egen visningslogikk)
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

ClassHUD.spellFrames = ClassHUD.spellFrames or {}
local activeFrames = {}

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
  local f = CreateFrame("Frame", nil, UI.anchor)
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

  return f
end

local function LayoutTrackedBuffBar(frames)
  local topBarAnchor = ClassHUD.UI.attachments and ClassHUD.UI.attachments.TOPBAR
  if not topBarAnchor then return end

  local width    = ClassHUD.db.profile.width or 250
  local perRow   = ClassHUD.db.profile.trackedBuffBar.perRow or 8
  local spacingX = ClassHUD.db.profile.trackedBuffBar.spacingX or 4
  local spacingY = ClassHUD.db.profile.trackedBuffBar.spacingY or 4
  local yOffset  = ClassHUD.db.profile.trackedBuffBar.yOffset or 4
  local size     = (width - (perRow - 1) * spacingX) / perRow
  local align    = ClassHUD.db.profile.trackedBuffBar.align or "CENTER"

  local row, col = 0, 0
  for _, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local rowCount = math.min(perRow, #frames - row * perRow)
    local rowWidth = rowCount * size + (rowCount - 1) * spacingX

    local startX
    if align == "LEFT" then
      startX = 0
    elseif align == "RIGHT" then
      startX = width - rowWidth
    else
      startX = (width - rowWidth) / 2
    end
    startX = math.floor(startX + 0.5)

    frame:SetPoint("BOTTOMLEFT", topBarAnchor, "TOPLEFT",
      startX + col * (size + spacingX),
      row * (size + spacingY) + yOffset)

    col = col + 1
    if col >= perRow then col, row = 0, row + 1 end
    frame:Show()
  end
end


local function LayoutTopBar(frames)
  if not UI.attachments or not UI.attachments.TOP then return end

  local width    = ClassHUD.db.profile.width or 250
  local perRow   = ClassHUD.db.profile.topBar.perRow or 8
  local spacingX = ClassHUD.db.profile.topBar.spacingX or 4
  local spacingY = ClassHUD.db.profile.topBar.spacingY or 4
  local yOffset  = ClassHUD.db.profile.topBar.yOffset or 0
  local size     = (width - (perRow - 1) * spacingX) / perRow
  local grow     = ClassHUD.db.profile.topBar.grow or "DOWN"

  local row, col = 0, 0
  local maxRow   = 0
  for _, frame in ipairs(frames) do
    frame:SetParent(UI.anchor) -- 👈 sørg for at de er synlige
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local rowCount = math.min(perRow, #frames - row * perRow)
    local rowWidth = rowCount * size + (rowCount - 1) * spacingX
    local startX   = (width - rowWidth) / 2

    local yLocal
    if grow == "UP" then
      yLocal = -(row * (size + spacingY) + yOffset)
    else
      yLocal = row * (size + spacingY) + yOffset
    end

    frame:SetPoint("BOTTOMLEFT", UI.attachments.TOP, "TOPLEFT",
      startX + col * (size + spacingX),
      yLocal)

    col = col + 1
    if col >= perRow then col, row = 0, row + 1 end
    maxRow = math.max(maxRow, row)
    frame:Show()
  end

  -- lag container for høyde
  if not UI.topBarFrame then
    UI.topBarFrame = CreateFrame("Frame", "ClassHUDTopBarFrame", UI.anchor)
  end
  UI.topBarFrame:ClearAllPoints()
  UI.topBarFrame:SetPoint("BOTTOMLEFT", UI.attachments.TOP, "TOPLEFT", 0, 0)
  UI.topBarFrame:SetPoint("BOTTOMRIGHT", UI.attachments.TOP, "TOPRIGHT", 0, 0)
  local totalHeight = (maxRow + 1) * (size + spacingY) + yOffset
  UI.topBarFrame:SetHeight(totalHeight)

  -- lag/oppdater TOPBAR-anker
  if not UI.attachments.TOPBAR then
    UI.attachments.TOPBAR = CreateFrame("Frame", "ClassHUDAttachTOPBAR", UI.topBarFrame)
  end
  UI.attachments.TOPBAR:ClearAllPoints()
  UI.attachments.TOPBAR:SetPoint("TOPLEFT", UI.topBarFrame, "TOPLEFT", 0, 0)
  UI.attachments.TOPBAR:SetPoint("TOPRIGHT", UI.topBarFrame, "TOPRIGHT", 0, 0)
  UI.attachments.TOPBAR:SetHeight(1)
end


local function LayoutSideBar(frames, side)
  if not UI.attachments or not UI.attachments[side] then return end
  local size    = ClassHUD.db.profile.sideBars.size or 36
  local spacing = ClassHUD.db.profile.sideBars.spacing or 4
  local offset  = ClassHUD.db.profile.sideBars.offset or 6
  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()
    if side == "LEFT" then
      frame:SetPoint("TOPRIGHT", UI.attachments.LEFT, "TOPLEFT", -offset, -(i - 1) * (size + spacing))
    elseif side == "RIGHT" then
      frame:SetPoint("TOPLEFT", UI.attachments.RIGHT, "TOPRIGHT", offset, -(i - 1) * (size + spacing))
    end
  end
end

local function LayoutBottomBar(frames)
  if not UI.attachments or not UI.attachments.BOTTOM then return end
  local width    = ClassHUD.db.profile.width or 250
  local perRow   = ClassHUD.db.profile.bottomBar.perRow or 8
  local spacingX = ClassHUD.db.profile.bottomBar.spacingX or 4
  local spacingY = ClassHUD.db.profile.bottomBar.spacingY or 4
  local yOffset  = ClassHUD.db.profile.bottomBar.yOffset or 0
  local size     = (width - (perRow - 1) * spacingX) / perRow

  local row, col = 0, 0
  for _, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()
    local rowCount = math.min(perRow, #frames - row * perRow)
    local rowWidth = rowCount * size + (rowCount - 1) * spacingX
    local startX   = (width - rowWidth) / 2
    frame:SetPoint("TOPLEFT", UI.attachments.BOTTOM, "BOTTOMLEFT",
      startX + col * (size + spacingX),
      -(row * (size + spacingY) + spacingY + yOffset))
    col = col + 1
    if col >= perRow then col, row = 0, row + 1 end
  end
end

function ClassHUD:BuildTrackedBuffFrames()
  -- skjul gamle
  if self.trackedBuffFrames then
    for _, f in ipairs(self.trackedBuffFrames) do f:Hide() end
  end
  self.trackedBuffFrames = {}

  if not self.db.profile.show.buffs then return end

  local _, class         = UnitClass("player")
  local specID           = GetSpecializationInfo(GetSpecialization() or 0)

  local tracked          = self.db.profile.trackedBuffs[class]
      and self.db.profile.trackedBuffs[class][specID]
  if not tracked then return end

  for buffID, enabled in pairs(tracked) do
    if enabled then
      local aura = self:GetAuraForSpell(buffID)
      if aura then
        local frame = CreateBuffFrame(buffID)
        local entry = self:GetSnapshotEntry(buffID)
        local iconID = entry and entry.iconID or select(3, C_Spell.GetSpellInfo(buffID))
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

        table.insert(self.trackedBuffFrames, frame)
      end
    end
  end

  if #self.trackedBuffFrames > 0 then
    LayoutTrackedBuffBar(self.trackedBuffFrames)
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
  local cd = C_Spell.GetSpellCooldown(sid)
  if cd and cd.startTime and cd.duration and cd.duration > 0 then
    CooldownFrame_Set(frame.cooldown, cd.startTime, cd.duration, true)
    frame._cooldownEnd = cd.startTime + cd.duration
    frame.icon:SetDesaturated(true)
  else
    CooldownFrame_Clear(frame.cooldown)
    frame._cooldownEnd = nil
    frame.icon:SetDesaturated(false)
  end

  -- =====================
  -- Charges
  -- =====================
  local ch = C_Spell.GetSpellCharges(sid)
  local chargesShown = false
  if ch and ch.maxCharges and ch.maxCharges > 1 then
    frame.count:SetText(ch.currentCharges or 0)
    frame.count:Show()
    chargesShown = true
    if ch.cooldownStartTime and ch.cooldownDuration and ch.cooldownDuration > 0 then
      CooldownFrame_Set(frame.cooldown, ch.cooldownStartTime, ch.cooldownDuration, true)
      frame._cooldownEnd = ch.cooldownStartTime + ch.cooldownDuration
    end
  else
    frame.count:Hide()
  end

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
function ClassHUD:UpdateAllFrames()
  self:RefreshSnapshotCache()
  for _, f in ipairs(activeFrames) do
    UpdateSpellFrame(f)
  end

  if self.BuildTrackedBuffFrames then
    self:BuildTrackedBuffFrames()
  end

  -- Før auto-map, håndter manuelle buffLinks fra DB
  local _, class = UnitClass("player")
  local specID   = GetSpecializationInfo(GetSpecialization() or 0)

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
          print("|cff00ff88ClassHUD|r Buff", buffID, "active → glowing", spellID, "(",
            C_Spell.GetSpellName(spellID) or "?", ")")
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

  self:RefreshSnapshotCache()

  local snapshot = self:GetSnapshotForSpec(nil, nil, false)
  if not snapshot then return end

  local built = {}
  self.trackedBuffToSpell = {}

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

  -- Essential spells → Top bar
  local topFrames = {}
  for _, item in ipairs(collect("essential")) do
    if not built[item.spellID] then
      table.insert(topFrames, acquire(item.spellID))
    end
  end

  -- Utility placements
  local utilFrames = { LEFT = {}, RIGHT = {}, TOP = {}, BOTTOM = {} }
  for _, item in ipairs(collect("utility")) do
    if not built[item.spellID] then
      local placement = (self.db.profile.utilityPlacement and self.db.profile.utilityPlacement[item.spellID])
          or "HIDDEN"
      if placement ~= "HIDDEN" and utilFrames[placement] then
        table.insert(utilFrames[placement], acquire(item.spellID))
      end
    end
  end

  -- Optional extra top/bottom frames
  for _, frame in ipairs(utilFrames.TOP) do table.insert(topFrames, frame) end
  local bottomFrames = utilFrames.BOTTOM

  -- Tracked bar entries (Blizzard "bar" category) → bottom by default
  for _, item in ipairs(collect("bar")) do
    if not built[item.spellID] then
      table.insert(bottomFrames, acquire(item.spellID))
    end
  end

  if #topFrames > 0 then LayoutTopBar(topFrames) end
  if #bottomFrames > 0 then LayoutBottomBar(bottomFrames) end
  if #utilFrames.LEFT > 0 then LayoutSideBar(utilFrames.LEFT, "LEFT") end
  if #utilFrames.RIGHT > 0 then LayoutSideBar(utilFrames.RIGHT, "RIGHT") end

  -- Auto-map tracked buffs to spells using snapshot descriptions
  local class, specID = self:GetPlayerClassSpec()

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
                print(string.format("|cff00ff88ClassHUD|r Lagret auto-link: %d → %d (%s)",
                  buffID, spellID, spellName))
              end
              break
            end
          end
        end
      end
    end
  end

  self:UpdateAllFrames()
end
