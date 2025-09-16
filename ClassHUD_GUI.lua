-- ClassHUD_GUI.lua
---@type ClassHUD
local ClassHUD = _G.ClassHUD
local AceGUI = LibStub("AceGUI-3.0")

-- Hold reference so we don’t create multiple windows
local guiFrame

local function BuildLayoutTab(container)
    local db = ClassHUD.db.profile.topBar

    -- Icons per Row
    local perRow = AceGUI:Create("Slider")
    perRow:SetLabel("Icons per Row")
    perRow:SetSliderValues(1, 20, 1)
    perRow:SetValue(db.perRow)
    perRow:SetCallback("OnValueChanged", function(_, _, val)
        db.perRow = val
        ClassHUD:BuildFramesForSpec()
    end)
    container:AddChild(perRow)

    -- Horizontal spacing
    local spacingX = AceGUI:Create("Slider")
    spacingX:SetLabel("Horizontal Spacing")
    spacingX:SetSliderValues(0, 20, 1)
    spacingX:SetValue(db.spacingX)
    spacingX:SetCallback("OnValueChanged", function(_, _, val)
        db.spacingX = val
        ClassHUD:BuildFramesForSpec()
    end)
    container:AddChild(spacingX)

    -- Vertical spacing
    local spacingY = AceGUI:Create("Slider")
    spacingY:SetLabel("Vertical Spacing")
    spacingY:SetSliderValues(0, 20, 1)
    spacingY:SetValue(db.spacingY)
    spacingY:SetCallback("OnValueChanged", function(_, _, val)
        db.spacingY = val
        ClassHUD:BuildFramesForSpec()
    end)
    container:AddChild(spacingY)

    -- Y Offset
    local yOffset = AceGUI:Create("Slider")
    yOffset:SetLabel("Y Offset")
    yOffset:SetSliderValues(-200, 200, 1)
    yOffset:SetValue(db.yOffset)
    yOffset:SetCallback("OnValueChanged", function(_, _, val)
        db.yOffset = val
        ClassHUD:BuildFramesForSpec()
    end)
    container:AddChild(yOffset)
end

local function BuildTrackedSpellsTab(container)
    local db = ClassHUD.db.profile
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    db.topBarSpells[specID] = db.topBarSpells[specID] or {}

    container:ReleaseChildren()

    -- Input for spell ID
    local addBox = AceGUI:Create("EditBox")
    addBox:SetLabel("Add Spell ID")
    addBox:SetCallback("OnEnterPressed", function(_, _, val)
        local id = tonumber(val)
        if id then
            table.insert(db.topBarSpells[specID], { spellID = id, trackCooldown = true })
            ClassHUD:BuildFramesForSpec()
            container:ReleaseChildren()
            BuildTrackedSpellsTab(container)
        end
    end)
    container:AddChild(addBox)

    -- Two-column layout
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    group:SetLayout("Flow")
    container:AddChild(group)

    -- Left column: spell list
    local leftCol = AceGUI:Create("InlineGroup")
    leftCol:SetTitle("Spells")
    leftCol:SetWidth(250)
    leftCol:SetFullHeight(true)
    leftCol:SetLayout("List")
    group:AddChild(leftCol)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    leftCol:AddChild(scroll)

    -- Right column: options for selected spell
    rightCol = AceGUI:Create("InlineGroup")
    rightCol:SetTitle("Options")
    rightCol:SetRelativeWidth(0.65) -- fill the rest
    rightCol:SetFullHeight(true)
    rightCol:SetLayout("List")
    group:AddChild(rightCol)

    local function ShowSpellOptions(data, index)
        rightCol:ReleaseChildren()

        -- Track Cooldown
        local chkCooldown = AceGUI:Create("CheckBox")
        chkCooldown:SetLabel("Track Cooldown")
        chkCooldown:SetValue(data.trackCooldown)
        chkCooldown:SetCallback("OnValueChanged", function(_, _, v)
            data.trackCooldown = v
            ClassHUD:UpdateAllFrames()
        end)
        rightCol:AddChild(chkCooldown)

        -- Aura stacks
        local auraStacks = AceGUI:Create("EditBox")
        auraStacks:SetLabel("Aura SpellID for Stacks")
        auraStacks:SetText(tostrBuildTrackedSpellsTabing(data.countFromAura or ""))
        auraStacks:SetCallback("OnEnterPressed", function(_, _, val)
            data.countFromAura = tonumber(val) or nil
            ClassHUD:UpdateAllFrames()
        end)
        rightCol:AddChild(auraStacks)

        -- Aura glow
        local auraGlow = AceGUI:Create("EditBox")
        auraGlow:SetLabel("Aura SpellID for Glow")
        auraGlow:SetText(tostring(data.auraGlow or ""))
        auraGlow:SetCallback("OnEnterPressed", function(_, _, val)
            data.auraGlow = tonumber(val) or nil
            ClassHUD:UpdateAllFrames()
        end)
        rightCol:AddChild(auraGlow)

        -- Remove button
        local btnRemove = AceGUI:Create("Button")
        btnRemove:SetText("Remove")
        btnRemove:SetCallback("OnClick", function()
            table.remove(db.topBarSpells[specID], index)
            ClassHUD:BuildFramesForSpec()
            container:ReleaseChildren()
            BuildTrackedSpellsTab(container)
        end)
        rightCol:AddChild(btnRemove)
    end

    -- Populate spell list
    for i, data in ipairs(db.topBarSpells[specID]) do
        local info = C_Spell.GetSpellInfo(data.spellID)
        local name = info and info.name or ("Unknown #%d"):format(data.spellID)
        local icon = info and info.iconID or 134400

        local btn = AceGUI:Create("Button")
        btn:SetText(("|T%d:16|t %s (%d)"):format(icon, name, data.spellID))
        btn:SetCallback("OnClick", function() ShowSpellOptions(data, i) end)
        scroll:AddChild(btn)
    end
end


local function BuildBarsTab(container)
    local db = ClassHUD.db.profile

    -- Lock frame
    local chkLock = AceGUI:Create("CheckBox")
    chkLock:SetLabel("Lock frame")
    chkLock:SetValue(db.locked)
    chkLock:SetCallback("OnValueChanged", function(_, _, v)
        db.locked = v
    end)
    container:AddChild(chkLock)

    -- Width
    local width = AceGUI:Create("Slider")
    width:SetLabel("Width")
    width:SetSliderValues(240, 800, 1)
    width:SetValue(db.width)
    width:SetCallback("OnValueChanged", function(_, _, v)
        db.width = v
        ClassHUD:FullUpdate()
    end)
    container:AddChild(width)

    -- Bar spacing
    local spacing = AceGUI:Create("Slider")
    spacing:SetLabel("Bar Spacing")
    spacing:SetSliderValues(0, 20, 1)
    spacing:SetValue(db.spacing)
    spacing:SetCallback("OnValueChanged", function(_, _, v)
        db.spacing = v
        ClassHUD:FullUpdate()
    end)
    container:AddChild(spacing)

    -- Power spacing
    local powerSpacing = AceGUI:Create("Slider")
    powerSpacing:SetLabel("Power Segment Spacing")
    powerSpacing:SetSliderValues(0, 10, 1)
    powerSpacing:SetValue(db.powerSpacing)
    powerSpacing:SetCallback("OnValueChanged", function(_, _, v)
        db.powerSpacing = v
        ClassHUD:FullUpdate()
    end)
    container:AddChild(powerSpacing)

    -- Position X
    local posX = AceGUI:Create("Slider")
    posX:SetLabel("Position X")
    posX:SetSliderValues(-1000, 1000, 1)
    posX:SetValue(db.position.x)
    posX:SetCallback("OnValueChanged", function(_, _, v)
        db.position.x = v
        ClassHUD:ApplyAnchorPosition()
    end)
    container:AddChild(posX)

    -- Position Y
    local posY = AceGUI:Create("Slider")
    posY:SetLabel("Position Y")
    posY:SetSliderValues(-1000, 1000, 1)
    posY:SetValue(db.position.y)
    posY:SetCallback("OnValueChanged", function(_, _, v)
        db.position.y = v
        ClassHUD:ApplyAnchorPosition()
    end)
    container:AddChild(posY)

    -- TODO: fonts + textures can be added later with LibSharedMedia dropdowns
    -- Bar texture (LSM dropdown)
    local texDropdown = AceGUI:Create("Dropdown")
    texDropdown:SetLabel("Bar Texture")
    local textures = {}
    for _, name in ipairs(ClassHUD.LSM:List("statusbar")) do
        textures[name] = name
    end
    texDropdown:SetList(textures)
    texDropdown:SetValue(db.textures.bar)
    texDropdown:SetCallback("OnValueChanged", function(_, _, v)
        db.textures.bar = v
        ClassHUD:FullUpdate()
    end)
    container:AddChild(texDropdown)

    -- Font (LSM dropdown)
    local fontDropdown = AceGUI:Create("Dropdown")
    fontDropdown:SetLabel("Font")
    local fonts = {}
    for _, name in ipairs(ClassHUD.LSM:List("font")) do
        fonts[name] = name
    end
    fontDropdown:SetList(fonts)
    fontDropdown:SetValue(db.textures.font)
    fontDropdown:SetCallback("OnValueChanged", function(_, _, v)
        db.textures.font = v
        ClassHUD:FullUpdate()
    end)
    container:AddChild(fontDropdown)

    -- HP Bar Color
    local hpColor = AceGUI:Create("ColorPicker")
    hpColor:SetLabel("HP Bar Color")
    hpColor:SetColor(db.colors.hp.r, db.colors.hp.g, db.colors.hp.b)
    hpColor:SetCallback("OnValueConfirmed", function(_, _, r, g, b)
        db.colors.hp.r, db.colors.hp.g, db.colors.hp.b = r, g, b
        ClassHUD:FullUpdate()
    end)
    container:AddChild(hpColor)

    -- Use class color for resource
    local resClassChk = AceGUI:Create("CheckBox")
    resClassChk:SetLabel("Use Class Color for Resource Bar")
    resClassChk:SetValue(db.colors.resourceClass)
    resClassChk:SetCallback("OnValueChanged", function(_, _, v)
        db.colors.resourceClass = v
        ClassHUD:FullUpdate()
    end)
    container:AddChild(resClassChk)

    -- Resource Bar Color (only matters if above is false)
    local resColor = AceGUI:Create("ColorPicker")
    resColor:SetLabel("Resource Bar Color")
    resColor:SetColor(db.colors.resource.r, db.colors.resource.g, db.colors.resource.b)
    resColor:SetCallback("OnValueConfirmed", function(_, _, r, g, b)
        db.colors.resource.r, db.colors.resource.g, db.colors.resource.b = r, g, b
        ClassHUD:FullUpdate()
    end)
    container:AddChild(resColor)

    -- Power Bar Color (fallback for special bars)
    local powerColor = AceGUI:Create("ColorPicker")
    powerColor:SetLabel("Special Power Color")
    powerColor:SetColor(db.colors.power.r, db.colors.power.g, db.colors.power.b)
    powerColor:SetCallback("OnValueConfirmed", function(_, _, r, g, b)
        db.colors.power.r, db.colors.power.g, db.colors.power.b = r, g, b
        ClassHUD:FullUpdate()
    end)
    container:AddChild(powerColor)
end

local function BuildBarLayoutTab(container, barKey, label)
    local db = ClassHUD.db.profile[barKey]

    -- Per Row (for top/bottom), Size (for sidebars)
    if db.perRow then
        local perRow = AceGUI:Create("Slider")
        perRow:SetLabel("Icons per Row")
        perRow:SetSliderValues(1, 20, 1)
        perRow:SetValue(db.perRow)
        perRow:SetCallback("OnValueChanged", function(_, _, v)
            db.perRow = v
            ClassHUD:BuildFramesForSpec()
        end)
        container:AddChild(perRow)
    else
        local size = AceGUI:Create("Slider")
        size:SetLabel("Icon Size")
        size:SetSliderValues(16, 80, 1)
        size:SetValue(db.size)
        size:SetCallback("OnValueChanged", function(_, _, v)
            db.size = v
            ClassHUD:BuildFramesForSpec()
        end)
        container:AddChild(size)
    end

    -- Spacing
    local spacing = AceGUI:Create("Slider")
    spacing:SetLabel("Spacing")
    spacing:SetSliderValues(0, 20, 1)
    spacing:SetValue(db.spacing or db.spacingX)
    spacing:SetCallback("OnValueChanged", function(_, _, v)
        if db.spacing then db.spacing = v else db.spacingX = v end
        ClassHUD:BuildFramesForSpec()
    end)
    container:AddChild(spacing)

    -- Extra: vertical spacing (for rows)
    if db.spacingY then
        local spacingY = AceGUI:Create("Slider")
        spacingY:SetLabel("Vertical Spacing")
        spacingY:SetSliderValues(0, 20, 1)
        spacingY:SetValue(db.spacingY)
        spacingY:SetCallback("OnValueChanged", function(_, _, v)
            db.spacingY = v
            ClassHUD:BuildFramesForSpec()
        end)
        container:AddChild(spacingY)
    end

    -- Offset
    if db.offset then
        local offset = AceGUI:Create("Slider")
        offset:SetLabel("Offset")
        offset:SetSliderValues(0, 100, 1)
        offset:SetValue(db.offset)
        offset:SetCallback("OnValueChanged", function(_, _, v)
            db.offset = v
            ClassHUD:BuildFramesForSpec()
        end)
        container:AddChild(offset)
    end

    if db.yOffset then
        local yOffset = AceGUI:Create("Slider")
        yOffset:SetLabel("Y Offset")
        yOffset:SetSliderValues(-200, 200, 1)
        yOffset:SetValue(db.yOffset)
        yOffset:SetCallback("OnValueChanged", function(_, _, v)
            db.yOffset = v
            ClassHUD:BuildFramesForSpec()
        end)
        container:AddChild(yOffset)
    end
end

local function BuildBarSpellsTab(container, barKey)
    local db = ClassHUD.db.profile
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    db[barKey .. "Spells"][specID] = db[barKey .. "Spells"][specID] or {}

    -- Add spell box
    local addBox = AceGUI:Create("EditBox")
    addBox:SetLabel("Add Spell ID")
    addBox:SetCallback("OnEnterPressed", function(_, _, val)
        local id = tonumber(val)
        if id then
            table.insert(db[barKey .. "Spells"][specID], { spellID = id, trackCooldown = true })
            ClassHUD:BuildFramesForSpec()
            ClassHUD:OpenOptionsGUI() -- rebuild window
        end
    end)
    container:AddChild(addBox)

    container:AddSpace(2)

    -- List left + detail right
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    container:AddChild(group)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetWidth(250)
    scroll:SetFullHeight(true)
    group:AddChild(scroll)

    local detail = AceGUI:Create("InlineGroup")
    detail:SetTitle("Options")
    detail:SetFullWidth(true)
    detail:SetFullHeight(true)
    group:AddChild(detail)

    local function ShowSpellOptions(data, index)
        detail:ReleaseChildren()
        -- same controls as Top Bar (trackCooldown, aura stack, aura glow, remove)
        local chkCooldown = AceGUI:Create("CheckBox")
        chkCooldown:SetLabel("Track Cooldown")
        chkCooldown:SetValue(data.trackCooldown)
        chkCooldown:SetCallback("OnValueChanged", function(_, _, v)
            data.trackCooldown = v
            ClassHUD:UpdateAllFrames()
        end)
        detail:AddChild(chkCooldown)

        local auraStacks = AceGUI:Create("EditBox")
        auraStacks:SetLabel("Aura SpellID for Stacks")
        auraStacks:SetText(tostring(data.countFromAura or ""))
        auraStacks:SetCallback("OnEnterPressed", function(_, _, val)
            data.countFromAura = tonumber(val) or nil
            ClassHUD:UpdateAllFrames()
        end)
        detail:AddChild(auraStacks)

        local auraGlow = AceGUI:Create("EditBox")
        auraGlow:SetLabel("Aura SpellID for Glow")
        auraGlow:SetText(tostring(data.auraGlow or ""))
        auraGlow:SetCallback("OnEnterPressed", function(_, _, val)
            data.auraGlow = tonumber(val) or nil
            ClassHUD:UpdateAllFrames()
        end)
        detail:AddChild(auraGlow)

        local btnRemove = AceGUI:Create("Button")
        btnRemove:SetText("Remove")
        btnRemove:SetCallback("OnClick", function()
            table.remove(db[barKey .. "Spells"][specID], index)
            ClassHUD:BuildFramesForSpec()
            ClassHUD:OpenOptionsGUI()
        end)
        detail:AddChild(btnRemove)
    end

    for i, data in ipairs(db[barKey .. "Spells"][specID]) do
        local info = C_Spell.GetSpellInfo(data.spellID)
        local name = info and info.name or ("Unknown #%d"):format(data.spellID)
        local icon = info and info.iconID or 134400
        local btn = AceGUI:Create("Button")
        btn:SetText(("|T%d:16|t %s (%d)"):format(icon, name, data.spellID))
        btn:SetCallback("OnClick", function() ShowSpellOptions(data, i) end)
        scroll:AddChild(btn)
    end
end

local function BuildTopBarTab(container)
    local rightCol
    local db = ClassHUD.db.profile
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    db.topBarSpells[specID] = db.topBarSpells[specID] or {}

    container:ReleaseChildren()

    -- === Layout controls ===
    local layoutGroup = AceGUI:Create("InlineGroup")
    layoutGroup:SetTitle("Layout")
    layoutGroup:SetFullWidth(true)
    layoutGroup:SetLayout("Flow")
    container:AddChild(layoutGroup)

    local perRow = AceGUI:Create("Slider")
    perRow:SetLabel("Icons per Row")
    perRow:SetSliderValues(1, 20, 1)
    perRow:SetValue(db.topBar.perRow)
    perRow:SetCallback("OnValueChanged", function(_, _, v)
        db.topBar.perRow = v
        ClassHUD:BuildFramesForSpec()
    end)
    layoutGroup:AddChild(perRow)

    local spacingX = AceGUI:Create("Slider")
    spacingX:SetLabel("Horizontal Spacing")
    spacingX:SetSliderValues(0, 20, 1)
    spacingX:SetValue(db.topBar.spacingX)
    spacingX:SetCallback("OnValueChanged", function(_, _, v)
        db.topBar.spacingX = v
        ClassHUD:BuildFramesForSpec()
    end)
    layoutGroup:AddChild(spacingX)

    local spacingY = AceGUI:Create("Slider")
    spacingY:SetLabel("Vertical Spacing")
    spacingY:SetSliderValues(0, 20, 1)
    spacingY:SetValue(db.topBar.spacingY)
    spacingY:SetCallback("OnValueChanged", function(_, _, v)
        db.topBar.spacingY = v
        ClassHUD:BuildFramesForSpec()
    end)
    layoutGroup:AddChild(spacingY)

    local yOffset = AceGUI:Create("Slider")
    yOffset:SetLabel("Y Offset")
    yOffset:SetSliderValues(-200, 200, 1)
    yOffset:SetValue(db.topBar.yOffset)
    yOffset:SetCallback("OnValueChanged", function(_, _, v)
        db.topBar.yOffset = v
        ClassHUD:BuildFramesForSpec()
    end)
    layoutGroup:AddChild(yOffset)

    -- === Add Spell input ===
    local addBox = AceGUI:Create("EditBox")
    addBox:SetLabel("Add Spell ID")
    addBox:SetCallback("OnEnterPressed", function(_, _, val)
        local id = tonumber(val)
        if id then
            table.insert(db.topBarSpells[specID], { spellID = id, trackCooldown = true })
            ClassHUD:BuildFramesForSpec()
            BuildTopBarTab(container) -- rebuild this tab only
        end
    end)
    container:AddChild(addBox)

    -- === Double-column layout ===
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetFullHeight(true)
    container:AddChild(row)

    -- LEFT column (spell list)
    local leftCol = AceGUI:Create("InlineGroup")
    leftCol:SetTitle("Tracked Spells")
    leftCol:SetLayout("List")
    leftCol:SetRelativeWidth(0.35)
    leftCol:SetFullHeight(true)
    row:AddChild(leftCol)

    -- RIGHT column (options for selected spell)
    rightCol = AceGUI:Create("InlineGroup")
    rightCol:SetTitle("Selected Spell Options")
    rightCol:SetLayout("List")
    rightCol:SetRelativeWidth(0.65)
    rightCol:SetFullHeight(true)
    row:AddChild(rightCol)

    local function ShowSpellOptions(data, index)
        rightCol:ReleaseChildren()

        local chkCooldown = AceGUI:Create("CheckBox")
        chkCooldown:SetLabel("Track Cooldown")
        chkCooldown:SetValue(data.trackCooldown)
        chkCooldown:SetCallback("OnValueChanged", function(_, _, v)
            data.trackCooldown = v
            ClassHUD:UpdateAllFrames()
        end)
        rightCol:AddChild(chkCooldown)

        local auraStacks = AceGUI:Create("EditBox")
        auraStacks:SetLabel("Aura SpellID for Stacks")
        auraStacks:SetText(tostring(data.countFromAura or ""))
        auraStacks:SetCallback("OnEnterPressed", function(_, _, val)
            data.countFromAura = tonumber(val) or nil
            ClassHUD:UpdateAllFrames()
        end)
        rightCol:AddChild(auraStacks)

        local auraGlow = AceGUI:Create("EditBox")
        auraGlow:SetLabel("Aura SpellID for Glow")
        auraGlow:SetText(tostring(data.auraGlow or ""))
        auraGlow:SetCallback("OnEnterPressed", function(_, _, val)
            data.auraGlow = tonumber(val) or nil
            ClassHUD:UpdateAllFrames()
        end)
        rightCol:AddChild(auraGlow)

        local btnRemove = AceGUI:Create("Button")
        btnRemove:SetText("Remove")
        btnRemove:SetCallback("OnClick", function()
            table.remove(db.topBarSpells[specID], index)
            ClassHUD:BuildFramesForSpec()
            BuildTopBarTab(container) -- rebuild the whole tab
        end)
        rightCol:AddChild(btnRemove)
    end

    -- Populate spell list buttons
    for i, data in ipairs(db.topBarSpells[specID]) do
        local info = C_Spell.GetSpellInfo(data.spellID)
        local name = info and info.name or ("Unknown #%d"):format(data.spellID)
        local icon = info and info.iconID or 134400

        local btn = AceGUI:Create("Button")
        btn:SetText(("|T%d:16|t %s (%d)"):format(icon, name, data.spellID))
        btn:SetCallback("OnClick", function() ShowSpellOptions(data, i) end)
        leftCol:AddChild(btn)
    end
end


-- Public: open our GUI
function ClassHUD:OpenOptionsGUI()
    if guiFrame then
        guiFrame:Hide()
        guiFrame = nil
    end

    local f = AceGUI:Create("Frame")
    f:SetTitle("ClassHUD - Top Bar Options")
    f:SetStatusText("Configure layout and tracked spells")
    f:SetLayout("Fill")
    f:SetWidth(600)
    f:SetHeight(400)
    guiFrame = f

    -- Tabs
    local tabs = AceGUI:Create("TabGroup")
    tabs:SetTabs({
        { text = "Bars",       value = "bars" },
        { text = "Top Bar",    value = "topbar" },
        { text = "Bottom Bar", value = "bottombar" },
        { text = "Left Bar",   value = "leftbar" },
        { text = "Right Bar",  value = "rightbar" },
    })
    tabs:SetCallback("OnGroupSelected", function(_, _, val)
        tabs:ReleaseChildren()
        if val == "bars" then
            BuildBarsTab(tabs)
        elseif val == "topbar" then
            BuildTopBarTab(tabs)
        elseif val == "bottombar" then
            local inner = AceGUI:Create("TabGroup")
            inner:SetTabs({ { text = "Layout", value = "layout" }, { text = "Tracked Spells", value = "spells" } })
            inner:SetCallback("OnGroupSelected", function(_, _, sub)
                inner:ReleaseChildren()
                if sub == "layout" then
                    BuildBarLayoutTab(inner, "bottomBar", "Bottom Bar")
                elseif sub == "spells" then
                    BuildBarSpellsTab(inner, "bottomBar")
                end
            end)
            inner:SelectTab("layout")
            tabs:AddChild(inner)
        elseif val == "leftbar" then
            local inner = AceGUI:Create("TabGroup")
            inner:SetTabs({ { text = "Layout", value = "layout" }, { text = "Tracked Spells", value = "spells" } })
            inner:SetCallback("OnGroupSelected", function(_, _, sub)
                inner:ReleaseChildren()
                if sub == "layout" then
                    BuildBarLayoutTab(inner, "sideBars", "Left Bar")
                elseif sub == "spells" then
                    BuildBarSpellsTab(inner, "leftBar")
                end
            end)
            inner:SelectTab("layout")
            tabs:AddChild(inner)
        elseif val == "rightbar" then
            local inner = AceGUI:Create("TabGroup")
            inner:SetTabs({ { text = "Layout", value = "layout" }, { text = "Tracked Spells", value = "spells" } })
            inner:SetCallback("OnGroupSelected", function(_, _, sub)
                inner:ReleaseChildren()
                if sub == "layout" then
                    BuildBarLayoutTab(inner, "sideBars", "Right Bar")
                elseif sub == "spells" then
                    BuildBarSpellsTab(inner, "rightBar")
                end
            end)
            inner:SelectTab("layout")
            tabs:AddChild(inner)
        end
    end)

    tabs:SelectTab("bars")

    f:AddChild(tabs)
end

-- Optional: slash command to open directly
SLASH_CLASSHUDGUI1 = "/chudgui"
SlashCmdList["CLASSHUDGUI"] = function()
    ClassHUD:OpenOptionsGUI()
end
