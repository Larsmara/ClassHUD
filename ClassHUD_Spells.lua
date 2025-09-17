-- ClassHUD_Spells.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

-- ===================================
-- Spell Tracking Module for ClassHUD
-- ===================================

local activeFrames = {}

-- Helpers
local function GetSpellIcon(spellID)
  local info = C_Spell.GetSpellInfo(spellID)
  return info and info.iconID or 134400
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

local function FindAuraOnUnitBySpellID(unit, sid)
  if not sid or not unit then return nil end
  if AuraUtil and AuraUtil.FindAuraBySpellID then
    return AuraUtil.FindAuraBySpellID(sid, unit, "HELPFUL|HARMFUL")
  elseif C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
    return C_UnitAuras.GetAuraDataBySpellID(unit, sid)
  elseif unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    return C_UnitAuras.GetPlayerAuraBySpellID(sid)
  end
end


local function CreateSpellFrame(data, index)
  local frame = CreateFrame("Frame", "ClassHUDSpell" .. "Spell" .. index, UIParent)
  frame:SetSize(40, 40)
  frame:SetPoint("CENTER", UIParent, "CENTER") -- layout overrides

  -- Icon
  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetAllPoints(frame)

  -- Stack count
  frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.count:SetFont(GameFontNormalLarge:GetFont(), 14, "OUTLINE")
  frame.count:SetDrawLayer("OVERLAY", 7)
  frame.count:Hide()

  -- Secondary label: Aura ID (optional)
  frame.auraIdText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.auraIdText:SetDrawLayer("OVERLAY", 8)
  frame.auraIdText:SetText("") -- fylles i UpdateSpellFrame
  frame.auraIdText:Hide()

  -- Spiral
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame)
  frame.cooldown:SetHideCountdownNumbers(true)
  frame.cooldown.noCooldownCount = true
  frame.cooldown:SetDrawEdge(false)
  local lvl = frame:GetFrameLevel()
  frame.cooldown:SetFrameLevel(lvl + 1)

  -- Numeric cooldown
  frame.cooldownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  frame.cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.cooldownText:SetFont(GameFontHighlightLarge:GetFont(), 16, "OUTLINE")
  frame.cooldownText:SetDrawLayer("OVERLAY", 8)
  frame.cooldownText:Hide()

  -- State
  frame._cooldownEnd = nil
  frame.isGlowing = false
  frame.data = data

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

local function ApplyIconTextStyle(frame)
  local cfg = ClassHUD.db.profile.iconText
  -- Count
  if frame.count and cfg and cfg.count then
    local f = cfg.count
    frame.count:ClearAllPoints()
    frame.count:SetPoint(f.point or "BOTTOMRIGHT", frame, f.point or "BOTTOMRIGHT", f.ofsX or -2, f.ofsY or 2)
    local font, _, flags = GameFontNormalLarge:GetFont()
    frame.count:SetFont(font, f.size or 14, flags or "OUTLINE")
    local c = f.color or { r = 1, g = 1, b = 1 }
    frame.count:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
  end

  -- Aura ID label
  if frame.auraIdText and cfg and cfg.aura then
    local f = cfg.aura
    frame.auraIdText:ClearAllPoints()
    frame.auraIdText:SetPoint(f.point or "TOPLEFT", frame, f.point or "TOPLEFT", f.ofsX or 2, f.ofsY or -2)
    local font, _, flags = GameFontHighlightSmall:GetFont()
    frame.auraIdText:SetFont(font, f.size or 10, flags or "OUTLINE")
    local c = f.color or { r = 1, g = 0.8, b = 0.2 }
    frame.auraIdText:SetTextColor(c.r or 1, c.g or 0.8, c.b or 0.2)
    frame.auraIdText:SetShown(f.enabled and true or false)
  end
end


-- Layout helpers
local function LayoutTopBarSpells(frames)
  if not UI.attachments or not UI.attachments.TOP then return end

  local width    = (ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.width) or 250
  local perRow   = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.perRow) or 8
  local spacingX = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.spacingX) or 4
  local spacingY = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.spacingY) or 4
  local yOffset  = (ClassHUD.db.profile.topBar and ClassHUD.db.profile.topBar.yOffset) or 0

  local size     = (width - (perRow - 1) * spacingX) / perRow

  local row, col = 0, 0
  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local rowCount = math.min(perRow, #frames - row * perRow)
    local rowWidth = rowCount * size + (rowCount - 1) * spacingX
    local startX   = (width - rowWidth) / 2

    frame:SetPoint("BOTTOMLEFT",
      UI.attachments.TOP, "TOPLEFT",
      startX + col * (size + spacingX),
      row * (size + spacingY) + spacingY + yOffset)

    col = col + 1
    if col >= perRow then
      col = 0
      row = row + 1
    end
  end
end

local function LayoutSideBarSpells(frames, side)
  if not UI.attachments or not UI.attachments[side] then return end

  local size    = (ClassHUD.db.profile.sideBars and ClassHUD.db.profile.sideBars.size) or 36
  local spacing = (ClassHUD.db.profile.sideBars and ClassHUD.db.profile.sideBars.spacing) or 4
  local offset  = (ClassHUD.db.profile.sideBars and ClassHUD.db.profile.sideBars.offset) or 6

  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    if side == "LEFT" then
      frame:SetPoint("TOPRIGHT",
        UI.attachments.LEFT, "TOPLEFT",
        -offset, -(i - 1) * (size + spacing))
    elseif side == "RIGHT" then
      frame:SetPoint("TOPLEFT",
        UI.attachments.RIGHT, "TOPRIGHT",
        offset, -(i - 1) * (size + spacing))
    end
  end
end

local function LayoutBottomBarSpells(frames)
  if not UI.attachments or not UI.attachments.BOTTOM then return end

  local width    = (ClassHUD.db and ClassHUD.db.profile and ClassHUD.db.profile.width) or 250
  local perRow   = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.perRow) or 8
  local spacingX = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.spacingX) or 4
  local spacingY = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.spacingY) or 4
  local yOffset  = (ClassHUD.db.profile.bottomBar and ClassHUD.db.profile.bottomBar.yOffset) or 0

  local size     = (width - (perRow - 1) * spacingX) / perRow

  local row, col = 0, 0
  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local rowCount = math.min(perRow, #frames - row * perRow)
    local rowWidth = rowCount * size + (rowCount - 1) * spacingX
    local startX   = (width - rowWidth) / 2

    frame:SetPoint("TOPLEFT",
      UI.attachments.BOTTOM, "BOTTOMLEFT",
      startX + col * (size + spacingX),
      -(row * (size + spacingY) + spacingY + yOffset))

    col = col + 1
    if col >= perRow then
      col = 0
      row = row + 1
    end
  end
end

-- Return start, duration, enabled(1/0), modRate for a spellID.
local function ReadCooldown(spellID)
  if not spellID or not C_Spell then return 0, 0, 0, 1, nil end

  local start, duration, enabled, modRate, charges

  -- Primary cooldown info
  local cd = C_Spell.GetSpellCooldown(spellID)
  if type(cd) == "table" then
    start    = cd.startTime or 0
    duration = cd.duration or 0
    enabled  = cd.isEnabled and 1 or 0
    modRate  = cd.modRate or 1
  end

  -- Charges override
  if C_Spell.GetSpellCharges then
    local ch = C_Spell.GetSpellCharges(spellID)
    if type(ch) == "table" and ch.maxCharges and ch.currentCharges then
      charges = ch
      if ch.currentCharges < ch.maxCharges then
        start    = ch.cooldownStartTime or start
        duration = ch.cooldownDuration or duration
        enabled  = 1
        modRate  = ch.chargeModRate or modRate or 1
      end
    end
  end

  return start or 0, duration or 0, enabled or 0, modRate or 1, charges
end

local function UpdateSpellFrame(frame)
  local data = frame.data
  if not data or not data.spellID then
    -- rydd opp og bail
    if frame.isGlowing then
      ActionButtonSpellAlertManager:HideAlert(frame)
      frame.isGlowing = false
    end
    if frame.cooldown then frame.cooldown:Hide() end
    if frame.cooldownText then frame.cooldownText:Hide() end
    if frame.icon then frame.icon:SetTexture(134400) end -- fallback-ikon
    return
  end

  -- ICON
  local iconID = GetSpellIcon(data.spellID)
  frame.icon:SetTexture(iconID)
  frame.icon:SetDesaturated(false)

  -- Safe guards
  if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end

  -- COOLDOWN
  if data.trackCooldown then
    local start, duration, enabled, modRate = ReadCooldown(data.spellID)
    if enabled == 1 and start > 0 and duration > 1.45 then
      CooldownFrame_Set(frame.cooldown, start, duration, true)
      frame._cooldownEnd = start + (duration / (modRate or 1))
      frame.cooldownText:Show()
      frame.icon:SetDesaturated(true)
    else
      CooldownFrame_Clear(frame.cooldown)
      frame._cooldownEnd = nil
      frame.cooldownText:Hide()
      frame.icon:SetDesaturated(false)
    end
  else
    CooldownFrame_Clear(frame.cooldown)
    frame._cooldownEnd = nil
    frame.cooldownText:Hide()
    frame.icon:SetDesaturated(false)
  end

  -- STACK COUNT OR CHARGES
  frame.count:SetText("")
  frame.count:Hide()

  local countShown = false

  -- 1) Stacks from aura (on selected unit)
  if data.countFromAura then
    local unit = data.countFromAuraUnit or "player"
    local aura = FindAuraOnUnitBySpellID(unit, data.countFromAura)

    -- convenience: if unit=player and we have a pet, also try pet once (BM Frenzy)
    if not aura and unit == "player" and UnitExists("pet") then
      aura = FindAuraOnUnitBySpellID("pet", data.countFromAura)
    end

    local stacks = aura and (aura.applications or aura.charges or aura.stackCount) or 0
    if stacks > 0 then
      frame.count:SetText(stacks)
      frame.count:Show()
      countShown = true
    end
  end

  -- 2) Fallback to charges when no aura stacks shown
  if not countShown and data.trackCooldown then
    local _, _, _, _, charges = ReadCooldown(data.spellID)
    if charges and charges.currentCharges then
      local showWhenSingle = data.countIncludeSingleCharge
      if (charges.maxCharges and charges.maxCharges > 1) or showWhenSingle then
        frame.count:SetText(charges.currentCharges)
        frame.count:Show()
        countShown = true
      end
    end
  end

  -- Re-apply icon text styling (in case user changed size/pos in options)
  ApplyIconTextStyle(frame)

  -- Aura ID label content
  do
    local showAuraId = ClassHUD.db.profile.iconText and ClassHUD.db.profile.iconText.aura and
        ClassHUD.db.profile.iconText.aura.enabled
    if showAuraId then
      -- Vis primært data.countFromAura; hvis ikke satt, vis første i glow-listen (hvis finnes)
      local label = nil
      if data.countFromAura then
        label = tostring(data.countFromAura)
      elseif data.auraGlowList and #data.auraGlowList > 0 then
        label = tostring(data.auraGlowList[1])
      elseif data.auraGlow then
        label = tostring(data.auraGlow)
      end
      frame.auraIdText:SetText(label or "")
      frame.auraIdText:SetShown(label ~= nil)
    else
      frame.auraIdText:Hide()
    end
  end



  -- AURA GLOW & ICON OVERRIDE (robust, støtter liste + single)
  do
    local baseIcon = GetSpellIcon(data.spellID)

    -- bygg prioritert liste
    local glowIDs = {}
    if type(data.auraGlowList) == "table" then
      for _, id in ipairs(data.auraGlowList) do
        local n = tonumber(id); if n then table.insert(glowIDs, n) end
      end
    end
    if data.auraGlow then
      local n = tonumber(data.auraGlow); if n then table.insert(glowIDs, n) end
    end

    -- finn første AKTIVE aura i lista
    local activeAuraIcon = nil
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and #glowIDs > 0 then
      for _, sid in ipairs(glowIDs) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(sid)
        if aura then
          activeAuraIcon = aura.icon; break
        end
      end
    end

    -- glow
    local wantGlow = (data.glowEnabled ~= false) and (activeAuraIcon ~= nil)
    if wantGlow then
      if not frame.isGlowing then
        ActionButtonSpellAlertManager:ShowAlert(frame)
        frame.isGlowing = true
        -- spill lyd én gang
        if data.soundOnGlow and data.soundOnGlow ~= "none" then
          local LSM = LibStub("LibSharedMedia-3.0", true)
          local file = LSM and LSM:Fetch("sound", data.soundOnGlow)
          if file then PlaySoundFile(file, "SFX") end
        end
      end
    else
      if frame.isGlowing then
        ActionButtonSpellAlertManager:HideAlert(frame)
        frame.isGlowing = false
      end
    end

    -- ikon override
    if data.iconFromAura and activeAuraIcon then
      frame.icon:SetTexture(activeAuraIcon)
    else
      frame.icon:SetTexture(baseIcon)
    end
  end





  -- Wild imps tracking for testing på demo lock
  if data.spellID == 196277 and ClassHUD_TrackerEngine then
    local count = 0
    for _, unit in ipairs(ClassHUD_TrackerEngine.GetActiveUnits()) do
      if unit.name == "Wild Imp" then
        count = count + 1
      end
    end
    frame.count:SetText(count > 0 and count or "")
    frame.count:SetShown(count > 0)
  end
end

function ClassHUD:UpdateAllFrames()
  for _, f in ipairs(activeFrames) do UpdateSpellFrame(f) end
end

function ClassHUD:BuildFramesForSpec()
  if not self.db or not self.db.profile then return end

  for _, f in ipairs(activeFrames) do f:Hide() end
  wipe(activeFrames)

  local specIndex                         = GetSpecialization()
  local specID                            = specIndex and GetSpecializationInfo(specIndex) or 0
  -- Sørg for at tabellene finnes for denne specen
  self.db.profile.topBarSpells            = self.db.profile.topBarSpells or {}
  self.db.profile.leftBarSpells           = self.db.profile.leftBarSpells or {}
  self.db.profile.rightBarSpells          = self.db.profile.rightBarSpells or {}
  self.db.profile.bottomBarSpells         = self.db.profile.bottomBarSpells or {}

  self.db.profile.topBarSpells[specID]    = self.db.profile.topBarSpells[specID] or {}
  self.db.profile.leftBarSpells[specID]   = self.db.profile.leftBarSpells[specID] or {}
  self.db.profile.rightBarSpells[specID]  = self.db.profile.rightBarSpells[specID] or {}
  self.db.profile.bottomBarSpells[specID] = self.db.profile.bottomBarSpells[specID] or {}

  local function build(list, layoutFn, sideArg)
    if not list then return end
    local frames = {}
    for i, data in ipairs(list) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    if #frames > 0 then
      if sideArg then layoutFn(frames, sideArg) else layoutFn(frames) end
    end
  end

  build(self.db.profile.topBarSpells[specID], LayoutTopBarSpells)
  build(self.db.profile.leftBarSpells[specID], LayoutSideBarSpells, "LEFT")
  build(self.db.profile.rightBarSpells[specID], LayoutSideBarSpells, "RIGHT")
  build(self.db.profile.bottomBarSpells[specID], LayoutBottomBarSpells)

  self:UpdateAllFrames()
end
