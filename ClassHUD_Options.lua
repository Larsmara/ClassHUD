-- ClassHUD_Options.lua
-- Settings UI and slash commands for configuring ClassHUD.

---@type ClassHUDAddon
local ClassHUD = _G.ClassHUD

local function Trim(str)
  if type(str) ~= "string" then
    return ""
  end
  local trimmed = str:match("^%s*(.-)%s*$")
  return trimmed or ""
end

local function Round(value)
  return math.floor((value or 0) + 0.5)
end

local function EnsureBarBlock(name)
  local cfg = ClassHUD:GetBarsConfig()
  if type(cfg[name]) ~= "table" then
    cfg[name] = {}
  end
  return cfg[name]
end

local function CreateCheckbox(parent, label, tooltip, onClick)
  local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  check.Text:SetText(label)
  if tooltip then
    check.tooltipText = label
    check.tooltipRequirement = tooltip
  end
  check:SetScript("OnClick", onClick)
  return check
end

local function CreateSlider(parent, label, minValue, maxValue, step, onValueChanged)
  local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider.Text:SetText(label)
  slider.Low:SetText(tostring(minValue))
  slider.High:SetText(tostring(maxValue))
  slider.valueLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  slider.valueLabel:SetPoint("TOP", slider, "BOTTOM", 0, -2)
  slider.valueLabel:SetText("0")
  slider:SetScript("OnValueChanged", function(self, value)
    local rounded = Round(value)
    self.valueLabel:SetText(rounded)
    if ClassHUD._optionsRefreshing then
      return
    end
    onValueChanged(self, rounded)
  end)
  return slider
end

local function GetSpellLabel(spellID)
  local name = ClassHUD:GetBuffSpellName(spellID)
  if not name then
    return tostring(spellID)
  end
  local numeric = tonumber(spellID)
  if numeric then
    return string.format("%s (%d)", name, numeric)
  end
  return string.format("%s (%s)", name, tostring(spellID))
end

function ClassHUD:RefreshOptionsPanel()
  if not self.optionsControls then
    return
  end

  self._optionsRefreshing = true

  local cfg = self:GetBarsConfig()
  local buffCfg = self:GetBuffConfig()
  local controls = self.optionsControls

  if controls.castCheck then
    local castBlock = cfg.cast or {}
    controls.castCheck:SetChecked(castBlock.enabled ~= false)
  end
  if controls.resourceCheck then
    local block = cfg.resource or {}
    controls.resourceCheck:SetChecked(block.enabled ~= false)
  end
  if controls.classCheck then
    local block = cfg.class or {}
    controls.classCheck:SetChecked(block.enabled ~= false)
  end
  if controls.healthCheck then
    local block = cfg.health or {}
    controls.healthCheck:SetChecked(block.enabled ~= false)
  end

  if controls.spacingSlider then
    controls.spacingSlider:SetValue(cfg.spacing or 0)
  end
  if controls.offsetSlider then
    controls.offsetSlider:SetValue(cfg.offsetY or 0)
  end
  if controls.buffOffsetSlider then
    controls.buffOffsetSlider:SetValue(buffCfg.offsetY or 0)
  end

  if controls.customList then
    local items = {}
    for spellID, enabled in pairs(buffCfg.customSpellIDs or {}) do
      if enabled then
        local numeric = tonumber(spellID) or spellID
        table.insert(items, {
          id = numeric,
          label = GetSpellLabel(numeric),
        })
      end
    end
    table.sort(items, function(a, b)
      if type(a.id) == "number" and type(b.id) == "number" then
        return a.id < b.id
      end
      return tostring(a.label) < tostring(b.label)
    end)

    if #items == 0 then
      controls.customList:SetText("No custom buffs added.")
    else
      local lines = {}
      for _, info in ipairs(items) do
        table.insert(lines, info.label)
      end
      controls.customList:SetText(table.concat(lines, "\n"))
    end
  end

  self._optionsRefreshing = false
end

function ClassHUD:OpenOptions()
  if not self.optionsInitialized then
    self:InitializeOptions()
  end

  if Settings and Settings.OpenToCategory and self.optionsCategoryID then
    Settings.OpenToCategory(self.optionsCategoryID)
  elseif InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
  end
end

function ClassHUD:InitializeOptions()
  if self.optionsInitialized then
    return
  end

  local panel = CreateFrame("Frame", "ClassHUDOptionsPanel", UIParent)
  panel.name = "ClassHUD"
  panel:Hide()

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ClassHUD")

  local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetWidth(540)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetText("Configure the ClassHUD bars and buff icons. Use the controls below to adjust layout and tracked spells.")

  local castCheck = CreateCheckbox(panel, "Show Cast Bar", nil, function(button)
    if self._optionsRefreshing then return end
    local block = EnsureBarBlock("cast")
    block.enabled = button:GetChecked() and true or false
    self:NotifyConfigChanged()
  end)
  castCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)

  local resourceCheck = CreateCheckbox(panel, "Show Resource Bar", nil, function(button)
    if self._optionsRefreshing then return end
    local block = EnsureBarBlock("resource")
    block.enabled = button:GetChecked() and true or false
    self:NotifyConfigChanged()
  end)
  resourceCheck:SetPoint("TOPLEFT", castCheck, "BOTTOMLEFT", 0, -8)

  local classCheck = CreateCheckbox(panel, "Show Class Bar", nil, function(button)
    if self._optionsRefreshing then return end
    local block = EnsureBarBlock("class")
    block.enabled = button:GetChecked() and true or false
    self:NotifyConfigChanged()
  end)
  classCheck:SetPoint("TOPLEFT", resourceCheck, "BOTTOMLEFT", 0, -8)

  local healthCheck = CreateCheckbox(panel, "Show Health Bar", nil, function(button)
    if self._optionsRefreshing then return end
    local block = EnsureBarBlock("health")
    block.enabled = button:GetChecked() and true or false
    self:NotifyConfigChanged()
  end)
  healthCheck:SetPoint("TOPLEFT", classCheck, "BOTTOMLEFT", 0, -8)

  local spacingSlider = CreateSlider(panel, "Bar Padding", 0, 40, 1, function(_, value)
    local cfg = self:GetBarsConfig()
    cfg.spacing = value
    self:NotifyConfigChanged()
  end)
  spacingSlider:SetPoint("TOPLEFT", healthCheck, "BOTTOMLEFT", 0, -32)
  spacingSlider:SetPoint("RIGHT", panel, "RIGHT", -40, 0)

  local offsetSlider = CreateSlider(panel, "Bars Vertical Offset", -200, 200, 1, function(_, value)
    local cfg = self:GetBarsConfig()
    cfg.offsetY = value
    self:NotifyConfigChanged()
  end)
  offsetSlider:SetPoint("TOPLEFT", spacingSlider, "BOTTOMLEFT", 0, -36)
  offsetSlider:SetPoint("RIGHT", spacingSlider, "RIGHT", 0, 0)

  local buffOffsetSlider = CreateSlider(panel, "Buff Bar Offset", -200, 200, 1, function(_, value)
    local cfg = self:GetBuffConfig()
    cfg.offsetY = value
    self:NotifyConfigChanged()
  end)
  buffOffsetSlider:SetPoint("TOPLEFT", offsetSlider, "BOTTOMLEFT", 0, -36)
  buffOffsetSlider:SetPoint("RIGHT", offsetSlider, "RIGHT", 0, 0)

  local customLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  customLabel:SetPoint("TOPLEFT", buffOffsetSlider, "BOTTOMLEFT", 0, -24)
  customLabel:SetText("Custom Buffs")

  local customHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  customHelp:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -4)
  customHelp:SetWidth(520)
  customHelp:SetJustifyH("LEFT")
  customHelp:SetText("Add spell IDs to always track as buffs. Remove entries to stop tracking them.")

  local input = CreateFrame("EditBox", nil, panel, "InputBoxInstructionsTemplate")
  input:SetAutoFocus(false)
  input:SetSize(120, 28)
  input:SetPoint("TOPLEFT", customHelp, "BOTTOMLEFT", 0, -10)
  input.Instructions:SetText("Spell ID")
  input:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    local filtered = text:gsub("[^0-9]", "")
    if text ~= filtered then
      self:SetText(filtered)
    end
  end)

  local addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  addButton:SetSize(80, 24)
  addButton:SetText("Add")
  addButton:SetPoint("LEFT", input, "RIGHT", 8, 0)
  addButton:SetScript("OnClick", function()
    local id = tonumber(input:GetText())
    if not id then
      ClassHUD:Print("Enter a spell ID to add.")
      return
    end
    ClassHUD:AddCustomBuff(id)
    input:SetText("")
    ClassHUD:RefreshOptionsPanel()
  end)

  local removeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  removeButton:SetSize(80, 24)
  removeButton:SetText("Remove")
  removeButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
  removeButton:SetScript("OnClick", function()
    local id = tonumber(input:GetText())
    if not id then
      ClassHUD:Print("Enter a spell ID to remove.")
      return
    end
    ClassHUD:RemoveCustomBuff(id)
    input:SetText("")
    ClassHUD:RefreshOptionsPanel()
  end)

  local customListFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  customListFrame:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -12)
  customListFrame:SetPoint("RIGHT", panel, "RIGHT", -40, 0)
  customListFrame:SetHeight(140)
  if customListFrame.SetBackdrop then
    customListFrame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    customListFrame:SetBackdropColor(0, 0, 0, 0.5)
  end

  local customListText = customListFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  customListText:SetPoint("TOPLEFT", customListFrame, "TOPLEFT", 8, -8)
  customListText:SetPoint("BOTTOMRIGHT", customListFrame, "BOTTOMRIGHT", -8, 8)
  customListText:SetJustifyH("LEFT")
  customListText:SetJustifyV("TOP")
  customListText:SetWordWrap(true)
  customListText:SetText("No custom buffs added.")

  panel:SetScript("OnShow", function()
    ClassHUD:RefreshOptionsPanel()
  end)

  self.optionsPanel = panel
  self.optionsControls = {
    castCheck = castCheck,
    resourceCheck = resourceCheck,
    classCheck = classCheck,
    healthCheck = healthCheck,
    spacingSlider = spacingSlider,
    offsetSlider = offsetSlider,
    buffOffsetSlider = buffOffsetSlider,
    customList = customListText,
    inputBox = input,
  }

  if Settings and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "ClassHUD")
    self.optionsCategoryID = category.ID
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end

  if not self._optionsSlashRegistered then
    SLASH_CLASSHUD1 = "/classhud"
    SLASH_CLASSHUD2 = "/chud"
    SlashCmdList.CLASSHUD = function(msg)
      local trimmed = Trim(msg)
      if trimmed == "" then
        ClassHUD:OpenOptions()
      else
        ClassHUD:HandleBuffCommand(trimmed)
      end
    end
    self._optionsSlashRegistered = true
  end

  self.optionsInitialized = true
  self:RefreshOptionsPanel()
end

