-- ClassHUD_Spells.lua (CDM-liste -> egen visningslogikk)
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

ClassHUD.spellFrames = ClassHUD.spellFrames or {}
local activeFrames = {}

-- ==================================================
-- Helpers
-- ==================================================
function ClassHUD:CollectCDMSpells()
  self.cdmSpells = {}

  local function collect(category, key)
    local ids = C_CooldownViewer.GetCooldownViewerCategorySet(category)
    if type(ids) ~= "table" then return end

    for _, cooldownID in ipairs(ids) do
      local raw = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
      if raw and raw.spellID then
        local sid = raw.spellID or raw.overrideSpellID
        self.cdmSpells[sid] = self.cdmSpells[sid] or {}
        self.cdmSpells[sid][key] = raw
      end
    end
  end

  collect(Enum.CooldownViewerCategory.Essential, "essential")
  collect(Enum.CooldownViewerCategory.Utility, "utility")
  collect(Enum.CooldownViewerCategory.TrackedBuff, "buff")
  collect(Enum.CooldownViewerCategory.TrackedBar, "bar")
end

local function FormatSeconds(s)
  if s >= 60 then
    return string.format("%dm", math.ceil(s / 60))
  elseif s >= 10 then
    return tostring(math.floor(s + 0.5))
  else
    return string.format("%.1f", s)
  end
end

-- Finn en aura for gitt buffID
local function FindAuraForBuff(buffID)
  if not C_UnitAuras then return nil end

  -- 1) raskeste: alltid sjekk player først
  if C_UnitAuras.GetPlayerAuraBySpellID then
    local a = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
    if a then return a, "player" end
  end

  -- 2) ellers: bruk generisk oppslag
  if C_UnitAuras.GetAuraDataBySpellID then
    local units = { "player", "pet", "target", "focus", "mouseover" }
    for _, unit in ipairs(units) do
      if UnitExists(unit) then
        local a = C_UnitAuras.GetAuraDataBySpellID(unit, buffID)
        if a and (a.isFromPlayer or a.sourceUnit == "player" or a.sourceUnit == "pet") then
          return a, unit
        end
      end
    end
  end

  return nil
end



-- ==================================================
-- Frame factory
-- ==================================================
local function CreateSpellFrame(spellID, index)
  local frame = CreateFrame("Frame", "ClassHUDSpell" .. index, UIParent)
  frame:SetSize(40, 40)

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetAllPoints(frame)

  frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.count:SetFont(GameFontNormalLarge:GetFont(), 14, "OUTLINE")
  frame.count:Hide()

  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame)
  frame.cooldown:SetHideCountdownNumbers(true)
  frame.cooldown.noCooldownCount = true

  frame.cooldownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  frame.cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.cooldownText:SetFont(GameFontHighlightLarge:GetFont(), 16, "OUTLINE")
  frame.cooldownText:Hide()

  frame._cooldownEnd = nil
  frame.spellID = spellID
  frame.isGlowing = false

  ClassHUD.spellFrames[spellID] = frame

  frame:SetScript("OnUpdate", function(self)
    if self._cooldownEnd then
      local remain = self._cooldownEnd - GetTime()
      if remain <= 0 then
        self._cooldownEnd = nil
        self.cooldownText:Hide()
        self.icon:SetDesaturated(false)
      else
        self.cooldownText:SetText(FormatSeconds(remain))
        self.cooldownText:Show()
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
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(32, 32)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(true)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cooldown:SetAllPoints(true)

  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  f.count:SetPoint("BOTTOMRIGHT", -2, 2)
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

  local _, class         = UnitClass("player")
  local specID           = GetSpecializationInfo(GetSpecialization() or 0)

  local tracked          = self.db.profile.trackedBuffs[class]
      and self.db.profile.trackedBuffs[class][specID]
  if not tracked then return end

  for buffID, enabled in pairs(tracked) do
    if enabled then
      local aura = FindAuraForBuff(buffID)
      if aura then
        local frame = CreateBuffFrame(buffID)
        frame.icon:SetTexture(C_Spell.GetSpellTexture(buffID) or 134400)

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
  local s = C_Spell.GetSpellInfo(sid)
  frame.icon:SetTexture((s and s.iconID) or 134400)

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

  local aura = (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) and C_UnitAuras.GetPlayerAuraBySpellID(auraID)
  if not aura and UnitExists("pet") and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
    aura = C_UnitAuras.GetAuraDataBySpellID("pet", auraID)
  end

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
            local auraCheck = C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(buffID)
            if not auraCheck and UnitExists("pet") and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
              auraCheck = C_UnitAuras.GetAuraDataBySpellID("pet", buffID)
            end
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
      local aura = C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(buffID)
      if not aura and UnitExists("pet") and C_UnitAuras.GetAuraDataBySpellID then
        aura = C_UnitAuras.GetAuraDataBySpellID("pet", buffID)
      end
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

  local enum = Enum and Enum.CooldownViewerCategory
  if not enum then return end

  local built = {}
  self.trackedBuffToSpell = {} -- reset buff → spell map

  -- ============= Essential -> TOP =============
  local topFrames = {}
  local essentialIDs = C_CooldownViewer.GetCooldownViewerCategorySet(enum.Essential)
  if type(essentialIDs) == "table" then
    for _, cooldownID in ipairs(essentialIDs) do
      local raw = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
      local sid = raw and (raw.spellID or raw.overrideSpellID or (raw.linkedSpellIDs and raw.linkedSpellIDs[1]))
      if sid and not built[sid] then
        local frame = CreateSpellFrame(sid, #activeFrames + 1)
        frame.spellID = sid
        frame.raw = raw
        table.insert(activeFrames, frame)
        table.insert(topFrames, frame)
        built[sid] = true
      end
    end
    if #topFrames > 0 then LayoutTopBar(topFrames) end
  end

  -- ============= Utility -> per-spell plassering =============
  local utilLeft, utilRight, utilBottom, utilTop = {}, {}, {}, {}
  local utilityIDs = C_CooldownViewer.GetCooldownViewerCategorySet(enum.Utility)
  if type(utilityIDs) == "table" then
    for _, cooldownID in ipairs(utilityIDs) do
      local raw = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
      local sid = raw and (raw.spellID or raw.overrideSpellID or (raw.linkedSpellIDs and raw.linkedSpellIDs[1]))
      if sid and not built[sid] then
        local placement = (ClassHUD.db.profile.utilityPlacement and ClassHUD.db.profile.utilityPlacement[sid]) or
            "HIDDEN"
        if placement ~= "HIDDEN" then
          local frame = CreateSpellFrame(sid, #activeFrames + 1)
          frame.spellID = sid
          frame.raw = raw
          table.insert(activeFrames, frame)
          built[sid] = true

          if placement == "LEFT" then
            table.insert(utilLeft, frame)
          elseif placement == "RIGHT" then
            table.insert(utilRight, frame)
          elseif placement == "TOP" then
            table.insert(utilTop, frame)
          else
            table.insert(utilBottom, frame)
          end
        end
      end
    end

    if #utilLeft > 0 then LayoutSideBar(utilLeft, "LEFT") end
    if #utilRight > 0 then LayoutSideBar(utilRight, "RIGHT") end
    if #utilBottom > 0 then LayoutBottomBar(utilBottom) end
    if #utilTop > 0 then LayoutTopBar(utilTop) end
  end

  -- ============= Auto-map tracked buffs til spells via description =============
  local _, class                           = UnitClass("player")
  local specID                             = GetSpecializationInfo(GetSpecialization() or 0)

  -- sørg for at trestrukturen finnes
  self.db.profile.buffLinks                = self.db.profile.buffLinks or {}
  self.db.profile.buffLinks[class]         = self.db.profile.buffLinks[class] or {}
  self.db.profile.buffLinks[class][specID] = self.db.profile.buffLinks[class][specID] or {}

  -- hent snapshot (lagres i UpdateCDMSnapshot)
  local snapshot                           = self.db.profile.cdmSnapshot
      and self.db.profile.cdmSnapshot[class]
      and self.db.profile.cdmSnapshot[class][specID]

  if snapshot then
    for buffID, data in pairs(snapshot) do
      if data.category == "buff" and data.spellID then
        local desc = data.desc or C_Spell.GetSpellDescription(buffID)
        if desc and self.spellFrames then
          for spellID, frame in pairs(self.spellFrames) do
            local spellName = C_Spell.GetSpellName(spellID)
            if spellName and string.find(desc, spellName, 1, true) then
              -- runtime mapping
              -- bruk snapshot buffLinks om de finnes
              local snapshot = self.db.profile.cdmSnapshot[class] and self.db.profile.cdmSnapshot[class][specID]
              if snapshot and snapshot.buffLinks and snapshot.buffLinks[buffID] then
                self.trackedBuffToSpell[buffID] = snapshot.buffLinks[buffID]
              end


              -- persist mapping (class+spec-scopet)
              local links = self.db.profile.buffLinks[class][specID]
              if not links[buffID] then
                links[buffID] = spellID
                print(
                  "|cff00ff88ClassHUD|r Lagret auto-link:",
                  buffID, "(", C_Spell.GetSpellName(buffID) or "?", ") →",
                  spellID, "(", spellName, ")"
                )
              end

              break -- stopper ved første match
            end
          end
        end
      end
    end
  end


  self:UpdateAllFrames()
end
