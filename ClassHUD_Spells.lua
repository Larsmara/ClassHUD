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
local HARMFUL_GLOW_THRESHOLD = 5
local HARMFUL_GLOW_AURA_CHECK_INTERVAL = 0.1
local HARMFUL_GLOW_UNITS = { "target", "focus" }
local TRACKED_UNITS = { "player", "pet" }

local function EnsureAttachment(name)
  if not UI.anchor then return nil end
  UI.attachments = UI.attachments or {}
  if not UI.attachments[name] then
    local f = CreateFrame("Frame", "ClassHUDAttach" .. name, UI.anchor)
    UI.attachments[name] = f
    f._height = 0

    local baseLvl = UI.anchor:GetFrameLevel() or 0
    if name == "TRACKED_ICONS" then
      f:SetFrameStrata("HIGH")
      f:SetFrameLevel(baseLvl + 40)
    elseif name == "TRACKED_BARS" then
      f:SetFrameStrata("MEDIUM")
      f:SetFrameLevel(baseLvl + 30)
    else
      f:SetFrameStrata("LOW")
      f:SetFrameLevel(baseLvl + 10)
    end
  end
  return UI.attachments[name]
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

-- =====================
-- Helpers
-- =====================

local function UpdateSpellIcon(frame, sid, entry)
  local iconID = entry and entry.iconID
  if not iconID then
    local s = C_Spell.GetSpellInfo(sid)
    iconID = s and s.iconID
  end
  frame.icon:SetTexture(iconID or 134400)
end

local function UpdateCooldown(frame, sid, gcdActive)
  local cdStart, cdDuration
  local shouldDesaturate = false

  -- Charges
  local ch = C_Spell.GetSpellCharges(sid)
  local chargesShown = false
  if ch and ch.maxCharges and ch.maxCharges > 1 then
    local current = ch.currentCharges or 0
    frame.count:SetText(current)
    frame.count:Show()
    chargesShown = true

    if current < ch.maxCharges and ch.cooldownStartTime and ch.cooldownDuration and ch.cooldownDuration > 0 then
      cdStart = ch.cooldownStartTime
      cdDuration = ch.cooldownDuration
    end

    shouldDesaturate = (current <= 0)
  else
    frame.count:Hide()
    local cd = C_Spell.GetSpellCooldown(sid)
    if cd and cd.startTime and cd.duration and cd.duration > 1.5 then
      cdStart = cd.startTime
      cdDuration = cd.duration
      shouldDesaturate = true
    end
  end

  -- GCD overlay (spellID 61304)
  local gcd = C_Spell.GetSpellCooldown(61304)
  if gcd and gcd.startTime and gcd.duration and gcd.duration > 0 then
    if not cdStart or (gcd.startTime + gcd.duration) > (cdStart + cdDuration) then
      cdStart    = gcd.startTime
      cdDuration = gcd.duration
      gcdActive  = true
      -- Viktig: ikke sett frame._cooldownEnd for GCD, da vil teksten dukke opp
    end
  end

  if cdStart and cdDuration then
    CooldownFrame_Set(frame.cooldown, cdStart, cdDuration, true)

    if not gcdActive then
      frame._cooldownEnd = cdStart + cdDuration
    else
      frame._cooldownEnd = nil
    end
  else
    CooldownFrame_Clear(frame.cooldown)
    frame._cooldownEnd = nil
  end


  frame.icon:SetDesaturated(shouldDesaturate)
  return chargesShown, gcdActive
end

local function UpdateAuraOverlay(frame, aura, chargesShown)
  if aura then
    local stacks = aura.applications or aura.stackCount or aura.charges or 0
    if aura.duration and aura.duration > 0 and aura.expirationTime then
      frame.cooldown:SetSwipeColor(1, 0.85, 0.1, 0.9)
      CooldownFrame_Set(frame.cooldown, aura.expirationTime - aura.duration, aura.duration, true)
      frame._cooldownEnd = aura.expirationTime
      frame.icon:SetVertexColor(1, 1, 0.3)
    else
      frame.cooldown:SetSwipeColor(0, 0, 0, 0.25)
      frame.icon:SetVertexColor(1, 1, 1)
    end

    if stacks > 1 and not chargesShown then
      frame.count:SetText(stacks)
      frame.count:Show()
    end
  else
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.25)
    frame.icon:SetVertexColor(1, 1, 1)
  end
end

-- Erstatt hele UpdateGlow med denne:
local function SetFrameGlow(frame, shouldGlow)
  if shouldGlow and not frame.isGlowing then
    ActionButtonSpellAlertManager:ShowAlert(frame)
    frame.isGlowing = true
  elseif not shouldGlow and frame.isGlowing then
    ActionButtonSpellAlertManager:HideAlert(frame)
    frame.isGlowing = false
  end
end

local function UpdateGlow(frame, aura, sid, data)
  -- 1) Samme semantikk som original: aura tilstede → glow
  local shouldGlow = (aura ~= nil)
  local allowExtraGlowLogic = true

  local isHarmfulSpell = C_Spell and C_Spell.IsSpellHarmful and C_Spell.IsSpellHarmful(sid)

  if isHarmfulSpell then
    allowExtraGlowLogic = false

    if aura and aura.expirationTime and aura.expirationTime > 0 then
      frame._harmfulGlowExpiration = aura.expirationTime
      frame._harmfulGlowWatching = true
      frame._harmfulGlowAuraSpellID = aura.spellId or sid
      frame._harmfulGlowNextAuraCheck = nil

      local remain = aura.expirationTime - GetTime()
      if remain and remain > 0 and remain <= HARMFUL_GLOW_THRESHOLD then
        shouldGlow = true
      else
        shouldGlow = false
      end
    else
      frame._harmfulGlowExpiration = nil
      frame._harmfulGlowWatching = false
      frame._harmfulGlowAuraSpellID = nil
      frame._harmfulGlowNextAuraCheck = nil
      shouldGlow = false
    end
  else
    frame._harmfulGlowExpiration = nil
    frame._harmfulGlowWatching = false
    frame._harmfulGlowAuraSpellID = nil
    frame._harmfulGlowNextAuraCheck = nil
  end

  -- 2) Manuelle buffLinks kan holde glow (som originalt "keepGlow")
  if allowExtraGlowLogic and not shouldGlow then
    local class, specID = ClassHUD:GetPlayerClassSpec()
    local links = (ClassHUD.db.profile.buffLinks[class] and ClassHUD.db.profile.buffLinks[class][specID]) or {}
    -- links: [buffID] = linkedSpellID
    for buffID, linkedSpellID in pairs(links) do
      if linkedSpellID == sid and ClassHUD:GetAuraForSpell(buffID) then
        shouldGlow = true
        break
      end
    end
  end

  -- 3) Auto-mapping fallback (som i originalens "keepGlow")
  if allowExtraGlowLogic and not shouldGlow and ClassHUD.trackedBuffToSpell then
    for buffID, mappedSpellID in pairs(ClassHUD.trackedBuffToSpell) do
      if mappedSpellID == sid and ClassHUD:GetAuraForSpell(buffID) then
        shouldGlow = true
        break
      end
    end
  end

  -- 4) Idempotent toggle (ikke spam Show/Hide)
  SetFrameGlow(frame, shouldGlow)
end


local function UpdateCooldownText(frame, gcdActive)
  local hasCooldown = frame._cooldownEnd ~= nil

  frame._gcdActive = (gcdActive and not hasCooldown) or false

  if frame._gcdActive then
    if frame.cooldownText:IsShown() or frame._cooldownTextValue then
      frame.cooldownText:SetText("")
      frame.cooldownText:Hide()
      frame._cooldownTextValue = nil
    end
    return
  end

  if not hasCooldown then
    if frame.cooldownText:IsShown() or frame._cooldownTextValue then
      frame.cooldownText:SetText("")
      frame.cooldownText:Hide()
      frame._cooldownTextValue = nil
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

  -- Cooldown
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame)
  frame.cooldown:SetHideCountdownNumbers(true)
  frame.cooldown.noCooldownCount = true

  -- Overlay-frame (alltid over cooldown)
  frame.overlay = CreateFrame("Frame", nil, frame)
  frame.overlay:SetAllPoints(frame)
  frame.overlay:SetFrameLevel(frame.cooldown:GetFrameLevel() + 1)

  -- Flytt tekstene til overlay
  frame.count = frame.overlay:CreateFontString(nil, "OVERLAY")
  frame.count:ClearAllPoints()
  frame.count:SetPoint("TOP", frame, "TOP", 0, -2)
  local fontPath, fontSize = ClassHUD:FetchFont(ClassHUD.db.profile.spellFontSize or 12)
  frame.count:SetFont(fontPath, fontSize, "OUTLINE")
  frame.count:Hide()

  frame.cooldownText = frame.overlay:CreateFontString(nil, "OVERLAY")
  frame.cooldownText:ClearAllPoints()
  frame.cooldownText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
  local fontPath, fontSize = ClassHUD:FetchFont(ClassHUD.db.profile.spellFontSize or 12)
  frame.cooldownText:SetFont(fontPath, fontSize, "OUTLINE")
  frame.cooldownText:Hide()


  frame._cooldownEnd = nil
  frame._cooldownTextValue = nil
  frame._gcdActive = false
  frame._harmfulGlowExpiration = nil
  frame._harmfulGlowWatching = false
  frame._harmfulGlowThreshold = HARMFUL_GLOW_THRESHOLD
  frame._harmfulGlowAuraSpellID = nil
  frame._harmfulGlowNextAuraCheck = nil
  frame._harmfulGlowCheckUnits = HARMFUL_GLOW_UNITS
  frame.spellID = spellID
  frame.isGlowing = false

  ClassHUD.spellFrames[spellID] = frame

  frame:SetScript("OnUpdate", function(selfFrame)
    if not selfFrame._harmfulGlowWatching then
      return
    end

    local now = GetTime()
    local expiration = selfFrame._harmfulGlowExpiration
    local threshold = selfFrame._harmfulGlowThreshold or HARMFUL_GLOW_THRESHOLD
    local auraSpellID = selfFrame._harmfulGlowAuraSpellID or selfFrame.spellID
    local auraStillPresent = true

    local nextCheck = selfFrame._harmfulGlowNextAuraCheck
    if not nextCheck or now >= nextCheck then
      local units = selfFrame._harmfulGlowCheckUnits or HARMFUL_GLOW_UNITS
      local auraCheck = auraSpellID and ClassHUD:GetAuraForSpell(auraSpellID, units) or nil
      if not auraCheck then
        auraCheck = ClassHUD:FindAuraByName(selfFrame.spellID, units)
      end
      if not auraCheck then
        auraStillPresent = false
      end
      selfFrame._harmfulGlowNextAuraCheck = now + HARMFUL_GLOW_AURA_CHECK_INTERVAL
    end

    if not auraStillPresent then
      selfFrame._harmfulGlowWatching = false
      selfFrame._harmfulGlowExpiration = nil
      selfFrame._harmfulGlowAuraSpellID = nil
      selfFrame._harmfulGlowNextAuraCheck = nil
      SetFrameGlow(selfFrame, false)
    elseif expiration and expiration > 0 then
      local remain = expiration - now
      if remain > 0 then
        SetFrameGlow(selfFrame, remain <= threshold)
      else
        selfFrame._harmfulGlowWatching = false
        selfFrame._harmfulGlowExpiration = nil
        selfFrame._harmfulGlowAuraSpellID = nil
        selfFrame._harmfulGlowNextAuraCheck = nil
        SetFrameGlow(selfFrame, false)
      end
    else
      selfFrame._harmfulGlowWatching = false
      selfFrame._harmfulGlowExpiration = nil
      selfFrame._harmfulGlowAuraSpellID = nil
      selfFrame._harmfulGlowNextAuraCheck = nil
      SetFrameGlow(selfFrame, false)
    end
  end)

  ClassHUD:RegisterCooldownTextFrame(frame)



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
  f.cooldown:SetHideCountdownNumbers(true) -- vi viser vår egen tekst
  f.cooldown.noCooldownCount = true

  -- overlay så tekst havner over cooldown swipe/edge
  f.overlay = CreateFrame("Frame", nil, f)
  f.overlay:SetAllPoints(true)
  f.overlay:SetFrameLevel(f.cooldown:GetFrameLevel() + 1)

  local fontPath, fontSize = ClassHUD:FetchFont(ClassHUD.db.profile.spellFontSize or 12)

  -- CHARGES / STACKS: øverst (samme som spells)
  f.count = f.overlay:CreateFontString(nil, "OVERLAY")
  f.count:ClearAllPoints()
  f.count:SetPoint("TOP", f, "TOP", 0, -2)
  f.count:SetFont(fontPath, fontSize, "OUTLINE")
  f.count:SetJustifyH("CENTER")
  f.count:SetText("")
  f.stacks = f.count

  -- COOLDOWN-TEKST: nederst (samme som spells)
  f.cooldownText = f.overlay:CreateFontString(nil, "OVERLAY")
  f.cooldownText:ClearAllPoints()
  f.cooldownText:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)
  f.cooldownText:SetFont(fontPath, fontSize, "OUTLINE")
  f.cooldownText:SetJustifyH("CENTER")
  f.cooldownText:SetJustifyV("MIDDLE")
  f.cooldownText:Hide()

  f.buffID = buffID
  f._cooldownEnd = nil
  f._cooldownTextValue = nil
  f._gcdActive = false

  trackedBuffPool[buffID] = f
  return f
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
  bar._timerTextValue = nil

  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:SetScript("OnUpdate", nil)

  trackedBarPool[buffID] = bar
  return bar
end

local function LayoutTrackedBars(barFrames, opts)
  local container = EnsureAttachment("TRACKED_BARS")
  if not container then return end

  local settings   = ClassHUD.db.profile.trackedBuffBar or {}
  local width      = ClassHUD.db.profile.width or 250
  local spacingY   = settings.spacingY or 4
  local barHeight  = settings.height or 16
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

  local db       = ClassHUD.db.profile
  local settings = db.trackedBuffBar or {}
  local width    = db.width or 250
  local perRow   = math.max(settings.perRow or 8, 1)
  local spacingX = settings.spacingX or 4
  local spacingY = settings.spacingY or 4
  local align    = settings.align or "CENTER"

  container:SetWidth(width)

  local size = (width - (perRow - 1) * spacingX) / perRow
  if size < 1 then size = 1 end

  -- alltid minst én rad høyde
  local rowsUsed = math.max(1, math.ceil(#iconFrames / perRow))
  local totalHeight = rowsUsed * size + (rowsUsed - 1) * spacingY

  for index, frame in ipairs(iconFrames) do
    frame:SetParent(container)
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local row       = math.floor((index - 1) / perRow)
    local col       = (index - 1) % perRow

    local remaining = #iconFrames - row * perRow
    local rowCount  = math.max(1, math.min(perRow, remaining))
    local rowWidth  = rowCount * size + math.max(0, rowCount - 1) * spacingX

    local startX
    if align == "LEFT" then
      startX = 0
    elseif align == "RIGHT" then
      startX = width - rowWidth
    else
      startX = (width - rowWidth) / 2 -- sentrert
    end

    frame:SetPoint("TOPLEFT", container, "TOPLEFT",
      startX + col * (size + spacingX),
      -(row * (size + spacingY)))
  end

  container:SetHeight(totalHeight)
  container._height   = totalHeight
  container._afterGap = db.spacing or 2
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
  container._afterGap = ClassHUD.db.profile.spacing or 0 -- 👈 vertical spacing option
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

  local size       = (width - (perRow - 1) * spacingX) / perRow
  local count      = #frames
  local rowsUsed   = math.ceil(count / perRow)
  local topPadding = spacingY + yOffset

  for index, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:SetParent(container)
    frame:ClearAllPoints()

    local row       = math.floor((index - 1) / perRow)
    local col       = (index - 1) % perRow
    local remaining = count - row * perRow
    local rowCount  = math.min(perRow, remaining)
    local rowWidth  = rowCount * size + math.max(0, rowCount - 1) * spacingX
    local startX    = (width - rowWidth) / 2

    frame:SetPoint("TOPLEFT", container, "TOPLEFT",
      startX + col * (size + spacingX),
      -(topPadding + row * (size + spacingY)))
    frame:Show()
  end

  local totalHeight = topPadding + rowsUsed * size + math.max(0, rowsUsed - 1) * spacingY
  totalHeight = math.max(totalHeight, 0)
  container._height = totalHeight
  container:SetHeight(totalHeight)
  container._afterGap = ClassHUD.db.profile.spacing or 0 -- 👈 vertical spacing option
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

  if aura and aura.expirationTime and aura.duration and aura.duration > 0 then
    CooldownFrame_Set(frame.cooldown, aura.expirationTime - aura.duration, aura.duration, true)

    -- sørg for at overlay er over cooldown
    if frame.overlay and frame.cooldown then
      local need = frame.cooldown:GetFrameLevel() + 1
      if frame.overlay:GetFrameLevel() <= need then
        frame.overlay:SetFrameLevel(need)
      end
    end

    frame._cooldownEnd = aura.expirationTime
    ClassHUD:RegisterCooldownTextFrame(frame)
  else
    CooldownFrame_Clear(frame.cooldown)
    frame._cooldownEnd = nil
    ClassHUD:UnregisterCooldownTextFrame(frame)
  end

  local stacks = aura and (aura.applications or aura.stackCount or aura.charges)
  if stacks and stacks > 1 then
    frame.count:SetText(stacks)
    frame.count:Show()
  else
    frame.count:SetText("")
    frame.count:Hide()
  end

  frame:Show()
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
      frame._timerTextValue = nil
      if frame.timer then
        frame.timer:SetText("")
        frame.timer:Hide()
      end
      ClassHUD:RegisterTrackedBarFrame(frame)
    else
      frame._duration = nil
      frame._expiration = nil
      frame:SetMinMaxValues(0, 1)
      frame:SetValue(1)
      ClassHUD:UnregisterTrackedBarFrame(frame)
    end

    return true
  end

  frame._duration = nil
  frame._expiration = nil
  frame:SetMinMaxValues(0, 1)
  frame:SetValue(0)
  frame:SetStatusBarColor(frame._inactiveColor.r, frame._inactiveColor.g, frame._inactiveColor.b, frame._inactiveColor.a)
  ClassHUD:UnregisterTrackedBarFrame(frame)
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
  local trackedIDs = self._trackedAuraIDs
  if not trackedIDs then
    trackedIDs = {}
    self._trackedAuraIDs = trackedIDs
  else
    wipe(trackedIDs)
  end

  local layoutSnapshot = self._trackedLayoutSnapshot
  if not layoutSnapshot then
    layoutSnapshot = {}
    self._trackedLayoutSnapshot = layoutSnapshot
  end

  local function commitLayoutChanges()
    local iconsContainer = EnsureAttachment("TRACKED_ICONS")
    local barsContainer  = EnsureAttachment("TRACKED_BARS")

    local iconsHeight = iconsContainer and iconsContainer._height or 0
    local iconsGap    = iconsContainer and iconsContainer._afterGap or nil
    local barsHeight  = barsContainer and barsContainer._height or 0
    local barsGap     = barsContainer and barsContainer._afterGap or nil

    local changed = layoutSnapshot.iconsHeight ~= iconsHeight
        or layoutSnapshot.iconsGap ~= iconsGap
        or layoutSnapshot.barsHeight ~= barsHeight
        or layoutSnapshot.barsGap ~= barsGap

    layoutSnapshot.iconsHeight = iconsHeight
    layoutSnapshot.iconsGap = iconsGap
    layoutSnapshot.barsHeight = barsHeight
    layoutSnapshot.barsGap = barsGap

    if changed and self.Layout then
      self:Layout()
    end
  end

  -- Skjul gamle frames
  if self.trackedBuffFrames then
    for _, frame in ipairs(self.trackedBuffFrames) do
      frame:Hide()
      ClassHUD:UnregisterCooldownTextFrame(frame)
    end
  end
  if self.trackedBarFrames then
    for _, frame in ipairs(self.trackedBarFrames) do
      frame:Hide()
      ClassHUD:UnregisterTrackedBarFrame(frame)
    end
  end

  wipe(self.trackedBuffFrames)
  wipe(self.trackedBarFrames)

  -- Sørg for containere
  EnsureAttachment("TRACKED_ICONS")
  EnsureAttachment("TRACKED_BARS")

  local function resetLayouts()
    LayoutTrackedBars({}, nil)
    LayoutTrackedIcons({}, nil)
    commitLayoutChanges()
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
        entry  = entry,
        order  = order,
        name   = name,
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
  local barFrames  = {}

  for _, info in ipairs(ordered) do
    local buffID         = info.buffID
    local entry          = info.entry
    local auraCandidates = CollectAuraSpellIDs(entry, buffID)
    local aura           = FindAuraFromCandidates(auraCandidates)

    trackedIDs[buffID] = true
    if auraCandidates then
      for _, candidateID in ipairs(auraCandidates) do
        if type(candidateID) == "number" then
          trackedIDs[candidateID] = true
        end
      end
    end

    if info.config and info.config.showBar and self.ResolveTrackedBarDisplay then
      local _, _, _, barCandidates = self:ResolveTrackedBarDisplay(entry, buffID, auraCandidates)
      if barCandidates then
        for _, candidateID in ipairs(barCandidates) do
          if type(candidateID) == "number" then
            trackedIDs[candidateID] = true
          end
        end
      end
    end

    if aura then
      local iconFrame = CreateBuffFrame(buffID)
      PopulateBuffIconFrame(iconFrame, buffID, aura, entry)
      iconFrame:Show()
      table.insert(iconFrames, iconFrame)
    else
      -- hold frame oppdatert i poolen, men ikke reserver plass i layout
      local iconFrame = CreateBuffFrame(buffID)
      PopulateBuffIconFrame(iconFrame, buffID, aura, entry)
      iconFrame:Hide()
    end
  end

  self.trackedBuffFrames = iconFrames
  self.trackedBarFrames  = barFrames

  local settings         = self.db.profile.trackedBuffBar or {}
  local yOffset          = settings.yOffset or 0

  local barTopPadding    = (#barFrames > 0) and yOffset or 0
  local iconTopPadding   = (#barFrames == 0 and #iconFrames > 0) and yOffset or 0

  LayoutTrackedBars(barFrames, { topPadding = barTopPadding })
  LayoutTrackedIcons(iconFrames, { topPadding = iconTopPadding })
  commitLayoutChanges()
end

-- ==================================================
-- UpdateSpellFrame
-- ==================================================
local function UpdateSpellFrame(frame)
  local sid = frame.spellID
  if not sid then return end

  local data  = ClassHUD.cdmSpells and ClassHUD.cdmSpells[sid]
  local entry = ClassHUD:GetSnapshotEntry(sid)

  -- Ikon
  UpdateSpellIcon(frame, sid, entry)

  -- Aura lookup (target/focus først for harmful)
  local auraID
  if data and data.buff then
    auraID = data.buff.overrideSpellID
        or (data.buff.linkedSpellIDs and data.buff.linkedSpellIDs[1])
        or data.buff.spellID
  end
  auraID = auraID or sid

  local aura = ClassHUD:GetAuraForSpell(auraID)
  if not aura then
    aura = ClassHUD:FindAuraByName(sid, { "target", "focus" })
  end

  -- Cooldown & charges
  local chargesShown, gcdActive = UpdateCooldown(frame, sid, false)
  UpdateAuraOverlay(frame, aura, chargesShown)

  -- ---------------- FARGE / DESAT ----------------
  local tracksAura, auraActive = ClassHUD:IsHarmfulAuraSpell(sid, entry)

  if tracksAura then
    if auraActive then
      frame.icon:SetDesaturated(false)
      frame.icon:SetVertexColor(1, 1, 1)
    else
      frame.icon:SetDesaturated(true)
      frame.icon:SetVertexColor(0.5, 0.5, 0.5)
    end
  else
    -- Vanlig usability/desaturate-logikk
    local desaturate = false

    local charges = C_Spell.GetSpellCharges(sid)
    if charges and charges.maxCharges and charges.maxCharges > 0 then
      if (charges.currentCharges or 0) <= 0 then
        desaturate = true
      end
    else
      local cd = C_Spell.GetSpellCooldown(sid)
      if cd and cd.startTime and cd.duration and cd.duration > 1.5 then
        desaturate = true
      end
    end

    local usable, noMana = C_Spell.IsSpellUsable(sid)
    if not usable and not noMana then
      desaturate = true
    end

    if ClassHUD:LacksResources(sid) then
      desaturate = true
    end

    frame.icon:SetDesaturated(desaturate)
    frame.icon:SetVertexColor(1, 1, 1)
  end

  -- ===== Out-of-Range via vertexColor =====
  do
    if UnitExists("target") and not UnitIsDead("target") then
      local inRange = C_Spell and C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(sid, "target")
      if inRange == false then
        frame.icon:SetVertexColor(1, 0, 0)
      end
    end
  end
  -- ========================================

  -- Glow & tekst
  UpdateGlow(frame, aura, sid, data)
  UpdateCooldownText(frame, gcdActive)
  ClassHUD:RefreshCooldownTextFrame(frame)
end


-- ==================================================
-- Public API (kalles fra ClassHUD.lua events)
-- ==================================================
ClassHUD.UpdateTrackedBarFrame = UpdateTrackedBarFrame

function ClassHUD:UpdateAllSpellFrames()
  self:RefreshSnapshotCache()

  for _, f in ipairs(activeFrames) do
    UpdateSpellFrame(f)
  end
end

function ClassHUD:RebuildTrackedBuffFrames()
  if self.BuildTrackedBuffFrames then
    self:BuildTrackedBuffFrames()
  end

  -- Før auto-map, håndter manuelle buffLinks fra DB
  local class, specID = self:GetPlayerClassSpec()
  if not specID or specID == 0 then
    return
  end

  local links = (ClassHUD.db.profile.buffLinks[class] and ClassHUD.db.profile.buffLinks[class][specID]) or {}

  for buffID, spellID in pairs(links) do
    local aura = C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(buffID)
    if not aura and UnitExists("pet") and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
      aura = C_UnitAuras.GetAuraDataBySpellID("pet", buffID)
    end
  end
end

function ClassHUD:UpdateAllFrames()
  if self.UpdateAllSpellFrames then
    self:UpdateAllSpellFrames()
  end

  if self.RebuildTrackedBuffFrames then
    self:RebuildTrackedBuffFrames()
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
    local class, specID = self:GetPlayerClassSpec()
    self.db.profile.utilityPlacement[class] = self.db.profile.utilityPlacement[class] or {}
    self.db.profile.utilityPlacement[class][specID] = self.db.profile.utilityPlacement[class][specID] or {}
    local placements = self.db.profile.utilityPlacement[class][specID]

    local list = {}
    self:ForEachSnapshotEntry(category, function(spellID, entry, categoryData)
      local placementData = placements[spellID]
      local customOrder   = placementData and placementData.order
      local baseOrder     = categoryData.order or math.huge
      local finalOrder    = customOrder or baseOrder
      table.insert(list, { spellID = spellID, entry = entry, data = categoryData, order = finalOrder })
    end)
    table.sort(list, function(a, b)
      if a.order == b.order then
        return (a.entry.name or "") < (b.entry.name or "")
      end
      return a.order < b.order
    end)
    return list
  end


  local class, specID = self:GetPlayerClassSpec()
  self.db.profile.utilityPlacement[class] = self.db.profile.utilityPlacement[class] or {}
  self.db.profile.utilityPlacement[class][specID] = self.db.profile.utilityPlacement[class][specID] or {}

  local placements = self.db.profile.utilityPlacement[class][specID]
  local order = self.db.profile.barOrder or {}
  if order[1] ~= "TOP" then
    self.db.profile.topBar.grow = "DOWN"
  else
    self.db.profile.topBar.grow = "UP"
  end


  local topFrames, bottomFrames = {}, {}
  local sideFrames = { LEFT = {}, RIGHT = {} }

  local function placeSpell(spellID, defaultPlacement)
    if built[spellID] then return end

    local pData = placements[spellID]
    local placement, customOrder
    if type(pData) == "table" then
      placement = pData.placement
      customOrder = pData.order
    else
      placement = pData
    end
    placement = placement or defaultPlacement or "TOP"

    if placement == "HIDDEN" then
      built[spellID] = true
      return
    end

    local frame = acquire(spellID)
    frame._customOrder = customOrder -- 👈 lagres på frame
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

  -- for _, item in ipairs(collect("bar")) do
  --   placeSpell(item.spellID, "BOTTOM")
  -- end

  for spellID, placement in pairs(placements) do
    if not built[spellID] then
      placeSpell(spellID, placement)
    end
  end

  -- Auto-grow for Top-bar basert på plassering
  do
    local order = self.db.profile.barOrder or {}
    local topIndex
    for i, key in ipairs(order) do
      if key == "TOP" then
        topIndex = i
        break
      end
    end
    if topIndex and topIndex > 1 then
      self.db.profile.topBar.grow = "DOWN"
    else
      self.db.profile.topBar.grow = "UP"
    end
  end


  local function sortFrames(list)
    table.sort(list, function(a, b)
      local ao = a._customOrder or (a.snapshotEntry and a.snapshotEntry.categories and
        ((a.snapshotEntry.categories.essential and a.snapshotEntry.categories.essential.order)
          or (a.snapshotEntry.categories.buff and a.snapshotEntry.categories.buff.order)
          or (a.snapshotEntry.categories.bar and a.snapshotEntry.categories.bar.order)
          or (a.snapshotEntry.categories.utility and a.snapshotEntry.categories.utility.order))) or math.huge

      local bo = b._customOrder or (b.snapshotEntry and b.snapshotEntry.categories and
        ((b.snapshotEntry.categories.essential and b.snapshotEntry.categories.essential.order)
          or (b.snapshotEntry.categories.buff and b.snapshotEntry.categories.buff.order)
          or (b.snapshotEntry.categories.bar and b.snapshotEntry.categories.bar.order)
          or (b.snapshotEntry.categories.utility and b.snapshotEntry.categories.utility.order))) or math.huge

      if ao == bo then
        local na = a.snapshotEntry and a.snapshotEntry.name or C_Spell.GetSpellName(a.spellID) or ""
        local nb = b.snapshotEntry and b.snapshotEntry.name or C_Spell.GetSpellName(b.spellID) or ""
        return na < nb
      end
      return ao < bo
    end)
  end

  -- sorter og layout
  sortFrames(topFrames)
  sortFrames(bottomFrames)
  sortFrames(sideFrames.LEFT)
  sortFrames(sideFrames.RIGHT)

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
