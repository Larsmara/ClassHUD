-- ClassHUD_Buffs.lua
-- Buff bar implementation using tracked spells and custom configuration.

---@type ClassHUDAddon
local ClassHUD = _G.ClassHUD

local BuffBar = {}
BuffBar.__index = BuffBar

local function GetFontPath()
  local cfg = ClassHUD:GetBarsConfig()
  return (cfg and cfg.font) or "Fonts\\FRIZQT__.TTF"
end

local function PrintMessage(msg)
  local text = "|cff00ff88ClassHUD|r " .. (msg or "")
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  else
    print(text)
  end
end

local function SpellName(spellID)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
  if info and info.name then
    return info.name
  end
  if GetSpellInfo then
    local name = GetSpellInfo(spellID)
    if name then
      return name
    end
  end
  return string.format("Spell %s", tostring(spellID or "?"))
end

function ClassHUD:Print(msg)
  PrintMessage(msg)
end

function ClassHUD:GetBuffSpellName(spellID)
  return SpellName(spellID)
end

local function EnsureBuffTables()
  local cfg = ClassHUD:GetBuffConfig()
  if type(cfg.customSpellIDs) ~= "table" then
    cfg.customSpellIDs = {}
  end
  if type(cfg.hiddenSpellIDs) ~= "table" then
    cfg.hiddenSpellIDs = {}
  end
  return cfg
end

function ClassHUD:AddCustomBuff(spellID)
  local id = tonumber(spellID)
  if not id then
    PrintMessage("Invalid spell ID.")
    return false, "Invalid spell ID"
  end
  local cfg = EnsureBuffTables()
  if cfg.customSpellIDs[id] then
    PrintMessage("Already tracking: " .. SpellName(id))
    return false, "Already tracking"
  end
  cfg.customSpellIDs[id] = true
  PrintMessage("Tracking custom buff: " .. SpellName(id))
  self:UpdateFromCooldownViewer()
  self:NotifyConfigChanged()
  return true
end

function ClassHUD:RemoveCustomBuff(spellID)
  local id = tonumber(spellID)
  if not id then
    PrintMessage("Invalid spell ID.")
    return false, "Invalid spell ID"
  end
  local cfg = EnsureBuffTables()
  if not cfg.customSpellIDs[id] then
    PrintMessage("Buff not tracked: " .. SpellName(id))
    return false, "Buff not tracked"
  end
  cfg.customSpellIDs[id] = nil
  PrintMessage("Removed custom buff: " .. SpellName(id))
  self:UpdateFromCooldownViewer()
  self:NotifyConfigChanged()
  return true
end

function ClassHUD:HideTrackedBuff(spellID)
  local id = tonumber(spellID)
  if not id then
    PrintMessage("Invalid spell ID.")
    return false, "Invalid spell ID"
  end
  local cfg = EnsureBuffTables()
  if cfg.hiddenSpellIDs[id] then
    PrintMessage("Spell already hidden: " .. SpellName(id))
    return false, "Already hidden"
  end
  cfg.hiddenSpellIDs[id] = true
  PrintMessage("Hidden Blizzard tracked spell: " .. SpellName(id))
  self:UpdateFromCooldownViewer()
  self:NotifyConfigChanged()
  return true
end

function ClassHUD:ShowTrackedBuff(spellID)
  local id = tonumber(spellID)
  if not id then
    PrintMessage("Invalid spell ID.")
    return false, "Invalid spell ID"
  end
  local cfg = EnsureBuffTables()
  if not cfg.hiddenSpellIDs[id] then
    PrintMessage("Spell not hidden: " .. SpellName(id))
    return false, "Spell not hidden"
  end
  cfg.hiddenSpellIDs[id] = nil
  PrintMessage("Restored Blizzard tracked spell: " .. SpellName(id))
  self:UpdateFromCooldownViewer()
  self:NotifyConfigChanged()
  return true
end

local function Clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

function ClassHUD:CreateBuffBar()
  if self.buffBar then
    return self.buffBar
  end

  local anchor = CreateFrame("Frame", "ClassHUDBuffAnchor", UIParent, "BackdropTemplate")
  anchor:SetSize(1, 1)

  local bar = setmetatable({
    owner = self,
    anchor = anchor,
    icons = {},
    entries = {},
    order = {},
    hidden = {},
  }, BuffBar)

  self.buffBar = bar
  bar:ApplyLayout()
  return bar
end

function BuffBar:IsEnabled()
  local cfg = self.owner:GetBuffConfig()
  return cfg.enabled ~= false
end

function BuffBar:SetEntries(entries, order, hidden)
  self.entries = entries or {}
  self.order = order or {}
  self.hidden = hidden or {}
end

local function EnsureIcon(bar, index)
  if bar.icons[index] then
    return bar.icons[index]
  end

  local iconSize = bar.owner:GetBuffConfig().iconSize or 32
  local frame = CreateFrame("Frame", nil, bar.anchor, "BackdropTemplate")
  frame:SetSize(iconSize, iconSize)

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetAllPoints()
  frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints()
  frame.cooldown:SetDrawEdge(false)
  frame.cooldown:SetDrawBling(false)
  frame.cooldown:SetSwipeColor(0, 0, 0, 0.8)
  if frame.cooldown.SetHideCountdownNumbers then
    frame.cooldown:SetHideCountdownNumbers(false)
  end

  frame.count = frame:CreateFontString(nil, "OVERLAY")
  frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.count:SetJustifyH("RIGHT")
  frame.count:SetTextColor(1, 1, 1)
  frame.count:SetFont(GetFontPath(), 11, "OUTLINE")

  bar.icons[index] = frame
  return frame
end

function BuffBar:ApplyLayout()
  local cfg = self.owner:GetBuffConfig()
  local rows = Clamp(cfg.rows or 1, 1, 6)
  local iconSize = Clamp(cfg.iconSize or 32, 8, 96)
  local spacing = Clamp(cfg.spacing or 4, 0, 30)
  local height = rows * iconSize + (rows - 1) * spacing
  self.anchor:SetHeight(height)
  for _, frame in ipairs(self.icons) do
    frame:SetSize(iconSize, iconSize)
  end
  if not self:IsEnabled() then
    self.anchor:Hide()
  else
    self.anchor:Show()
  end
end

local function NormalizeAura(spellID, aura)
  if not aura then return nil end
  local info = {}
  info.name = aura.name
  info.icon = aura.icon
  info.duration = aura.duration
  info.expirationTime = aura.expirationTime
  info.count = aura.applications or aura.stackCount or aura.charges or aura.count
  if not info.icon then
    local spell = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    if spell then
      info.icon = spell.iconID
      info.name = info.name or spell.name
    end
  end
  return info
end

local AURA_FILTERS = { "HELPFUL", nil }

local function FindAura(spellID)
  if not spellID then
    return nil
  end

  local units = { "player", "pet" }
  for _, unit in ipairs(units) do
    if C_UnitAuras then
      if C_UnitAuras.GetAuraDataBySpellID then
        for _, filter in ipairs(AURA_FILTERS) do
          local aura = C_UnitAuras.GetAuraDataBySpellID(unit, spellID, filter)
          if aura then
            return NormalizeAura(spellID, aura)
          end
        end
      end
      if unit == "player" and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then
          return NormalizeAura(spellID, aura)
        end
      end
    end

    if AuraUtil and AuraUtil.FindAuraBySpellID then
      for _, filter in ipairs(AURA_FILTERS) do
        local name, icon, count, _, duration, expirationTime = AuraUtil.FindAuraBySpellID(spellID, unit, filter)
        if name then
          return NormalizeAura(spellID, {
            name = name,
            icon = icon,
            applications = count,
            duration = duration,
            expirationTime = expirationTime,
          })
        end
      end
    end

    if UnitAura then
      for _, filter in ipairs(AURA_FILTERS) do
        local index = 1
        while true do
          local name, icon, count, _, duration, expirationTime, _, _, _, id = UnitAura(unit, index, filter)
          if not name then break end
          if id == spellID then
            return NormalizeAura(spellID, {
              name = name,
              icon = icon,
              applications = count,
              duration = duration,
              expirationTime = expirationTime,
            })
          end
          index = index + 1
        end
      end
    end
  end
end

local function ExtractFromCooldownInfo(spellID, data)
  local info = data and data.cooldownInfo
  if type(info) ~= "table" then
    return nil
  end

  local duration = info.activeCooldownDuration or info.cooldownDuration or info.duration or info.displayDuration
  local start = info.activeCooldownStartTime or info.cooldownStartTime or info.startTime or info.displayStartTime
  local remaining = info.remainingCooldownDuration or info.remainingDuration

  if not duration or duration <= 0 then
    return nil
  end

  if not start and remaining then
    start = GetTime() - (duration - remaining)
  end

  if not start or start <= 0 then
    return nil
  end

  local elapsed = GetTime() - start
  if remaining and remaining <= 0 then
    return nil
  end
  if elapsed >= duration then
    return nil
  end

  local icon = info.iconTextureFileID
  local name = info.name
  if not icon or not name then
    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    if spellInfo then
      icon = icon or spellInfo.iconID
      name = name or spellInfo.name
    end
  end

  return {
    spellID = spellID,
    name = name,
    icon = icon,
    startTime = start,
    duration = duration,
    count = info.activeStackCount or info.stackCount or info.charges or info.currentCharges,
  }
end

local function BuildTotemEntry(slot)
  if not GetTotemInfo then
    return nil
  end
  local haveTotem, name, startTime, duration, icon = GetTotemInfo(slot)
  if not haveTotem then
    return nil
  end
  local spellID
  if GetTotemSpell then
    spellID = GetTotemSpell(slot)
  end
  if duration and duration <= 0 then
    duration = nil
    startTime = nil
  end
  return {
    spellID = spellID,
    name = name,
    icon = icon,
    startTime = startTime,
    duration = duration,
    count = nil,
  }
end

local function FindActiveTotemForSpell(bar, spellID)
  if not spellID or not GetTotemInfo or not GetTotemSpell then
    return nil
  end
  local maxTotems = MAX_TOTEMS or 4
  for slot = 1, maxTotems do
    local entry = BuildTotemEntry(slot)
    if entry and entry.spellID == spellID then
      if bar.hidden[spellID] then
        return nil
      end
      return entry
    end
  end
end

local function BuildEntry(bar, data)
  if not data then return nil end

  if data.source == "totem" then
    local slot = data.totemSlot
    if not slot then return nil end
    local entry = BuildTotemEntry(slot)
    if not entry then
      return nil
    end
    if entry.spellID and bar.hidden[entry.spellID] then
      return nil
    end
    return entry
  end

  local spellID = data.spellID
  if not spellID or bar.hidden[spellID] then
    return nil
  end

  local totemEntry = FindActiveTotemForSpell(bar, spellID)
  if totemEntry then
    return totemEntry
  end

  local aura = FindAura(spellID)
  if aura then
    local entry = {
      spellID = spellID,
      name = aura.name,
      icon = aura.icon,
      duration = aura.duration,
      count = aura.count,
    }
    if aura.duration and aura.duration > 0 and aura.expirationTime then
      entry.startTime = aura.expirationTime - aura.duration
    end
    return entry
  end

  return ExtractFromCooldownInfo(spellID, data)
end

local function ApplyEntry(frame, entry)
  frame.icon:SetTexture(entry.icon or 136243)
  if entry.startTime and entry.duration and entry.duration > 0 then
    CooldownFrame_Set(frame.cooldown, entry.startTime, entry.duration, true)
    frame.cooldown:Show()
  else
    if CooldownFrame_Clear then
      CooldownFrame_Clear(frame.cooldown)
    else
      frame.cooldown:SetCooldown(0, 0)
    end
    frame.cooldown:Hide()
  end
  local count = entry.count
  if count and count > 1 then
    frame.count:SetText(count)
    frame.count:Show()
  else
    frame.count:SetText("")
  end
end

function BuffBar:LayoutIcons(count)
  local cfg = self.owner:GetBuffConfig()
  local perRow = Clamp(cfg.perRow or 10, 1, 20)
  local rows = Clamp(cfg.rows or 1, 1, 6)
  local iconSize = Clamp(cfg.iconSize or 32, 8, 96)
  local spacing = Clamp(cfg.spacing or 4, 0, 30)

  for i = 1, count do
    local row = math.floor((i - 1) / perRow) + 1
    if row > rows then
      if self.icons[i] then self.icons[i]:Hide() end
    else
      local indexInRow = (i - 1) % perRow
      local iconsInRow = math.min(perRow, count - (row - 1) * perRow)
      local rowWidth = iconsInRow * iconSize + (iconsInRow - 1) * spacing
      local x = -rowWidth / 2 + indexInRow * (iconSize + spacing) + iconSize / 2
      local y = - (row - 1) * (iconSize + spacing)
      local frame = EnsureIcon(self, i)
      frame:ClearAllPoints()
      frame:SetPoint("TOP", self.anchor, "TOP", x, y)
      frame:SetSize(iconSize, iconSize)
      frame.cooldown:Show()
      frame:Show()
    end
  end

  for i = count + 1, #self.icons do
    self.icons[i]:Hide()
  end
end

function BuffBar:UpdateBuffs()
  if not self:IsEnabled() then
    self.anchor:Hide()
    for _, frame in ipairs(self.icons) do
      frame:Hide()
    end
    return
  end

  self.anchor:Show()
  self:ApplyLayout()

  local cfg = self.owner:GetBuffConfig()
  local limit = Clamp((cfg.rows or 1) * (cfg.perRow or 10), 1, 120)
  local built = {}

  for _, key in ipairs(self.order) do
    local entry = BuildEntry(self, self.entries and self.entries[key])
    if entry then
      table.insert(built, entry)
      if #built >= limit then break end
    end
  end

  self:LayoutIcons(#built)

  for i = 1, #built do
    local frame = EnsureIcon(self, i)
    ApplyEntry(frame, built[i])
  end

  for i = #built + 1, #self.icons do
    self.icons[i]:Hide()
  end
end

-- ---------------------------------------------------------------------------
-- Slash options for buff configuration
-- ---------------------------------------------------------------------------
local function ParseNumber(token)
  local num = tonumber(token)
  if num then
    return math.floor(num + 0.5)
  end
end

function ClassHUD:HandleBuffCommand(msg)
  local cfg = EnsureBuffTables()
  local args = {}
  for token in string.gmatch(msg or "", "[^%s]+") do
    table.insert(args, token)
  end
  local sub = args[1] and args[1]:lower()

  if not sub or sub == "help" then
    PrintMessage("Buff options:")
    PrintMessage("  /classhud buffs on|off - enable or disable the buff bar")
    PrintMessage("  /classhud buffs size <number> - set icon size")
    PrintMessage("  /classhud buffs spacing <number> - set icon spacing")
    PrintMessage("  /classhud buffs rows <number> - set number of rows")
    PrintMessage("  /classhud buffs perrow <number> - icons per row")
    PrintMessage("  /classhud buffs add <spellID> - track a custom buff")
    PrintMessage("  /classhud buffs remove <spellID> - stop tracking a custom buff")
    PrintMessage("  /classhud buffs hide <spellID> - hide a Blizzard tracked spell")
    PrintMessage("  /classhud buffs show <spellID> - show a hidden Blizzard spell")
    PrintMessage("  /classhud options - open the configuration window")
    return
  end

  if sub == "options" then
    if self.OpenOptions then
      self:OpenOptions()
    end
    return
  end

  if sub ~= "buffs" then
    PrintMessage("Unknown command. Use /classhud help for options.")
    return
  end

  local action = args[2] and args[2]:lower()
  if action == "on" or action == "enable" then
    cfg.enabled = true
    PrintMessage("Buff bar enabled.")
    self:NotifyConfigChanged()
    return
  elseif action == "off" or action == "disable" then
    cfg.enabled = false
    PrintMessage("Buff bar disabled.")
    self:NotifyConfigChanged()
    return
  elseif action == "size" then
    local value = ParseNumber(args[3])
    if value then
      cfg.iconSize = Clamp(value, 8, 96)
      PrintMessage("Buff icon size set to " .. cfg.iconSize .. ".")
      self:NotifyConfigChanged()
    else
      PrintMessage("Usage: /classhud buffs size <number>")
    end
    return
  elseif action == "spacing" then
    local value = ParseNumber(args[3])
    if value then
      cfg.spacing = Clamp(value, 0, 30)
      PrintMessage("Buff icon spacing set to " .. cfg.spacing .. ".")
      self:NotifyConfigChanged()
    else
      PrintMessage("Usage: /classhud buffs spacing <number>")
    end
    return
  elseif action == "rows" then
    local value = ParseNumber(args[3])
    if value then
      cfg.rows = Clamp(value, 1, 6)
      PrintMessage("Buff rows set to " .. cfg.rows .. ".")
      self:NotifyConfigChanged()
    else
      PrintMessage("Usage: /classhud buffs rows <number>")
    end
    return
  elseif action == "perrow" then
    local value = ParseNumber(args[3])
    if value then
      cfg.perRow = Clamp(value, 1, 20)
      PrintMessage("Icons per row set to " .. cfg.perRow .. ".")
      self:NotifyConfigChanged()
    else
      PrintMessage("Usage: /classhud buffs perrow <number>")
    end
    return
  elseif action == "add" or action == "remove" or action == "hide" or action == "show" then
    local spellID = ParseNumber(args[3])
    if not spellID then
      PrintMessage("Usage: /classhud buffs " .. action .. " <spellID>")
      return
    end
    if action == "add" then
      self:AddCustomBuff(spellID)
    elseif action == "remove" then
      self:RemoveCustomBuff(spellID)
    elseif action == "hide" then
      self:HideTrackedBuff(spellID)
    elseif action == "show" then
      self:ShowTrackedBuff(spellID)
    end
    return
  end

  PrintMessage("Unknown buff command. Use /classhud help for usage.")
end

