local addon = ClassHUD
local UI = addon.UI
local ADDON_NAME = addon.ADDON_NAME

local activeFrames = {}

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

local function CreateSpellFrame(data, index)
  local frame = CreateFrame("Frame", ADDON_NAME .. "Spell" .. index, UIParent)

  frame:SetSize(40, 40)
  frame:SetPoint("CENTER", UIParent, "CENTER")

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetAllPoints(frame)

  frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.count:SetFont(GameFontNormalLarge:GetFont(), 14, "OUTLINE")
  frame.count:SetDrawLayer("OVERLAY", 7)
  frame.count:Hide()

  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame)
  frame.cooldown:SetHideCountdownNumbers(true)
  frame.cooldown.noCooldownCount = true
  frame.cooldown:SetDrawEdge(false)

  local lvl = frame:GetFrameLevel()
  frame.cooldown:SetFrameLevel(lvl + 1)

  frame.cooldownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  frame.cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.cooldownText:SetFont(GameFontHighlightLarge:GetFont(), 16, "OUTLINE")
  frame.cooldownText:SetDrawLayer("OVERLAY", 8)
  frame.cooldownText:Hide()

  frame._cooldownEnd = nil
  frame.isGlowing = false
  frame.data = data

  frame:SetScript("OnUpdate", function(selfFrame)
    if selfFrame._cooldownEnd then
      local remain = selfFrame._cooldownEnd - GetTime()
      if remain <= 0 then
        selfFrame._cooldownEnd = nil
        selfFrame.cooldownText:Hide()
        selfFrame.icon:SetDesaturated(false)
      else
        selfFrame.cooldownText:SetText(FormatSeconds(remain))
        selfFrame.cooldownText:Show()
      end
    end
  end)

  return frame
end

local function LayoutTopBarSpells(frames)
  if not UI.attachments or not UI.attachments.TOP then return end

  local width    = addon.db.profile.width
  local perRow   = (addon.db.profile.topBar and addon.db.profile.topBar.perRow) or 8
  local spacingX = (addon.db.profile.topBar and addon.db.profile.topBar.spacingX) or 4
  local spacingY = (addon.db.profile.topBar and addon.db.profile.topBar.spacingY) or 4
  local yOffset  = (addon.db.profile.topBar and addon.db.profile.topBar.yOffset) or 0

  local size     = (width - (perRow - 1) * spacingX) / perRow

  local row, col = 0, 0
  for _, frame in ipairs(frames) do
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

  local size    = (addon.db.profile.sideBars and addon.db.profile.sideBars.size) or 36
  local spacing = (addon.db.profile.sideBars and addon.db.profile.sideBars.spacing) or 4
  local offset  = (addon.db.profile.sideBars and addon.db.profile.sideBars.offset) or 6

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

  local width    = addon.db.profile.width
  local perRow   = (addon.db.profile.bottomBar and addon.db.profile.bottomBar.perRow) or 8
  local spacingX = (addon.db.profile.bottomBar and addon.db.profile.bottomBar.spacingX) or 4
  local spacingY = (addon.db.profile.bottomBar and addon.db.profile.bottomBar.spacingY) or 4
  local yOffset  = (addon.db.profile.bottomBar and addon.db.profile.bottomBar.yOffset) or 0

  local size     = (width - (perRow - 1) * spacingX) / perRow

  local row, col = 0, 0
  for _, frame in ipairs(frames) do
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

local function ReadCooldown(spellID)
  if not spellID or not C_Spell then return 0, 0, 0, 1, nil end

  local start, duration, enabled, modRate, charges

  local cd = C_Spell.GetSpellCooldown(spellID)
  if type(cd) == "table" then
    start    = cd.startTime or 0
    duration = cd.duration or 0
    enabled  = cd.isEnabled and 1 or 0
    modRate  = cd.modRate or 1
  end

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
  if not data or not data.spellID then return end

  local iconID = GetSpellIcon(data.spellID)
  frame.icon:SetTexture(iconID)
  frame.icon:SetDesaturated(false)

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

  if data.countFromAura and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(data.countFromAura)
    local stacks = (aura and aura.applications) or 0
    if stacks > 0 then
      frame.count:SetText(stacks)
      frame.count:Show()
    else
      frame.count:SetText("")
      frame.count:Hide()
    end
  else
    frame.count:SetText("")
    frame.count:Hide()
  end

  if data.auraGlow and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(data.auraGlow)
    if aura then
      ActionButtonSpellAlertManager:ShowAlert(frame)
      frame.isGlowing = true
      if aura.icon then
        frame.icon:SetTexture(aura.icon)
      end
    elseif frame.isGlowing then
      ActionButtonSpellAlertManager:HideAlert(frame)
      frame.isGlowing = false
      frame.icon:SetTexture(GetSpellIcon(data.spellID))
    end
  end
end

function addon:UpdateAllFrames()
  for _, f in ipairs(activeFrames) do UpdateSpellFrame(f) end
end

function addon:BuildFramesForSpec()
  for _, f in ipairs(activeFrames) do f:Hide() end
  wipe(activeFrames)

  local specIndex = GetSpecialization()
  local specID = specIndex and GetSpecializationInfo(specIndex) or 0

  local top = self.db.profile.topBarSpells[specID]
  if top then
    local frames = {}
    for _, data in ipairs(top) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutTopBarSpells(frames)
  end

  local left = self.db.profile.leftBarSpells[specID]
  if left then
    local frames = {}
    for _, data in ipairs(left) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutSideBarSpells(frames, "LEFT")
  end

  local right = self.db.profile.rightBarSpells[specID]
  if right then
    local frames = {}
    for _, data in ipairs(right) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutSideBarSpells(frames, "RIGHT")
  end

  local bottom = self.db.profile.bottomBarSpells[specID]
  if bottom then
    local frames = {}
    for _, data in ipairs(bottom) do
      if C_SpellBook.IsSpellKnown(data.spellID) or C_SpellBook.IsSpellInSpellBook(data.spellID) then
        local frame = CreateSpellFrame(data, #activeFrames + 1)
        table.insert(frames, frame)
        table.insert(activeFrames, frame)
      end
    end
    LayoutBottomBarSpells(frames)
  end

  self:UpdateAllFrames()
end
