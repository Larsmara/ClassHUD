-- ClassHUD_Options.lua
function ClassHUD_BuildOptions(addon)
  local db  = addon.db
  local LSM = LibStub("LibSharedMedia-3.0", true)
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ClassHUD")
  local ACR = LibStub("AceConfigRegistry-3.0")
  local ACD = LibStub("AceConfigDialog-3.0")

  addon._opts = addon._opts -- behold om du allerede har satt den et annet sted

  local function ForceRefresh(barKey)
    if ACR then ACR:NotifyChange("ClassHUD") end
    if not ACD then return end

    local pathByKey = {
      top    = { "topBar", "spells" },
      bottom = { "bottomBar", "spells" },
      left   = { "sidebars", "leftBar", "spells" },  -- 👈 updated
      right  = { "sidebars", "rightBar", "spells" }, -- 👈 updated
    }
    local path = pathByKey[barKey]
    if not path then return end

    if ACD.OpenFrames and ACD.OpenFrames["ClassHUD"] then
      ACD:SelectGroup("ClassHUD", unpack(path))
    else
      ACD:Open("ClassHUD")
      ACD:SelectGroup("ClassHUD", unpack(path))
    end
  end

  -- ===== Ensure defaults exist (same spirit as your original) =====
  db.profile.textures        = db.profile.textures or { bar = "Blizzard", font = "Friz Quadrata TT" }
  db.profile.show            = db.profile.show or { cast = true, hp = true, resource = true, power = true }
  db.profile.height          = db.profile.height or { cast = 18, hp = 14, resource = 14, power = 14 }
  db.profile.colors          = db.profile.colors or {
    resource = { r = 0, g = 0.55, b = 1 },
    power = { r = 1, g = 0.85, b = 0.1 },
    resourceClass = true,
  }
  db.profile.icons           = db.profile.icons or { enabled = true, size = 36, spacing = 4 } -- (legacy, safe)
  db.profile.position        = db.profile.position or { x = 0, y = -150 }

  db.profile.topBar          = db.profile.topBar or {}
  db.profile.bottomBar       = db.profile.bottomBar or {}
  db.profile.sideBars        = db.profile.sideBars or {}
  db.profile.topBarSpells    = db.profile.topBarSpells or {}
  db.profile.bottomBarSpells = db.profile.bottomBarSpells or {}
  db.profile.leftBarSpells   = db.profile.leftBarSpells or {}
  db.profile.rightBarSpells  = db.profile.rightBarSpells or {}
  -- ICON TEXT defaults
  db.profile.iconText        = db.profile.iconText or {
    count = { size = 14, color = { r = 1, g = 1, b = 1 }, point = "BOTTOMRIGHT", ofsX = -2, ofsY = 2 },
    aura  = { enabled = false, size = 10, color = { r = 1, g = 0.8, b = 0.2 }, point = "TOPLEFT", ofsX = 2, ofsY = -2 },
  }


  local suggestedSpells = _G.ClassHUD_SpellSuggestions or {}

  --------------------------------------------------------------------
  -- Generic spell-tree rebuilder (works for top/bottom/left/right)
  --------------------------------------------------------------------
  local function GetSpellsContainer(opts, barKey)
    if barKey == "left" then return opts.args.sidebars.args.leftBar.args.spells.args end
    if barKey == "right" then return opts.args.sidebars.args.rightBar.args.spells.args end
    return opts.args[barKey .. "Bar"].args.spells.args
  end

  local function parseIDList(str)
    local out = {}
    if type(str) ~= "string" then return out end
    for num in str:gmatch("%d+") do
      local n = tonumber(num)
      if n then table.insert(out, n) end
    end
    return out
  end

  local function joinIDList(tbl)
    if type(tbl) ~= "table" then return "" end
    local t = {}
    for _, n in ipairs(tbl) do table.insert(t, tostring(n)) end
    return table.concat(t, ", ")
  end

  local function auraIconsString(list)
    local parts = {}
    if type(list) == "table" then
      for _, id in ipairs(list) do
        local info = C_Spell.GetSpellInfo(id)
        if info and info.iconID then
          table.insert(parts, ("|T%d:18|t"):format(info.iconID))
        end
      end
    end
    if #parts == 0 then return "|cff888888(no auras added)|r" end
    return table.concat(parts, "  ")
  end



  local function RebuildSpellTree(opts, db, addon, barKey)
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    local spellsKey = barKey .. "BarSpells"
    db.profile[spellsKey] = db.profile[spellsKey] or {}
    db.profile[spellsKey][specID] = db.profile[spellsKey][specID] or {}

    opts = opts or (addon and addon._opts)
    if not opts then return end

    local container = GetSpellsContainer(opts, barKey) -- 👈 viktig endring
    -- wipe gamle noder
    for k in pairs(container) do
      if type(k) == "string" and k:match("^spell_") then container[k] = nil end
    end

    local list = db.profile[spellsKey][specID]
    for i, data in ipairs(list) do
      local idx = i
      local info = C_Spell.GetSpellInfo(data.spellID)
      local displayName = info and ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, data.spellID)
          or ("Unknown (" .. tostring(data.spellID) .. ")")

      container["spell_" .. idx] = {
        type   = "group",
        name   = displayName,
        inline = true,
        order  = 100 + idx,
        args   = {
          -- Rekkeflytting
          rowHeader = { type = "header", name = "Row", order = 98 },
          moveUp = {
            type = "execute",
            name = "Move Up",
            order = 98.1,
            disabled = function() return idx == 1 end,
            func = function()
              if idx > 1 then
                list[idx], list[idx - 1] = list[idx - 1], list[idx]
                addon:BuildFramesForSpec()
                RebuildSpellTree(opts, db, addon, barKey)
                ACR:NotifyChange("ClassHUD")
              end
            end,
          },
          moveDown = {
            type = "execute",
            name = "Move Down",
            order = 98.2,
            disabled = function() return idx == #list end,
            func = function()
              if idx < #list then
                list[idx], list[idx + 1] = list[idx + 1], list[idx]
                addon:BuildFramesForSpec()
                RebuildSpellTree(opts, db, addon, barKey)
                ACR:NotifyChange("ClassHUD")
              end
            end,
          },
          trackCooldown = {
            type = "toggle",
            name = "Track Cooldown",
            order = 1,
            get = function() return not not data.trackCooldown end,
            set = function(_, v)
              data.trackCooldown = v; addon:BuildFramesForSpec()
            end,
          },
          glowHeader = { type = "header", name = "Glow & Icon", order = 3 },
          glowEnabled = {
            type = "toggle",
            name = "Enable Glow",
            desc = "Show spell alert glow when any aura in the list is active on you.",
            order = 3.1,
            get = function() return data.glowEnabled ~= false end,
            set = function(_, v)
              data.glowEnabled = v; addon:BuildFramesForSpec()
            end,
          },
          iconFromAura = {
            type = "toggle",
            name = "Use Aura Icon When Active",
            desc = "When glowing, replace the spell icon with the matching aura's icon.",
            order = 3.2,
            get = function() return not not data.iconFromAura end,
            set = function(_, v)
              data.iconFromAura = v; addon:BuildFramesForSpec()
            end,
          },
          countFromAura = {
            type = "input",
            name = "Aura SpellID for Stacks",
            order = 2,
            get = function() return data.countFromAura and tostring(data.countFromAura) or "" end,
            set = function(_, v)
              data.countFromAura = tonumber(v); addon:BuildFramesForSpec()
            end,
          },
          countFromAuraUnit = {
            type = "select",
            name = "Count Aura Unit",
            order = 2.1,
            values = { player = "Player", pet = "Pet", target = "Target", focus = "Focus" },
            get = function() return data.countFromAuraUnit or "player" end,
            set = function(_, v)
              data.countFromAuraUnit = v; addon:BuildFramesForSpec()
            end,
          },
          auraGlowSingle = {
            type = "input",
            name = "Glow Aura (single ID, legacy)",
            desc = "Optional legacy single-ID glow (kept for backward compatibility). Use the list below for multiple.",
            order = 3,
            get = function() return data.auraGlow and tostring(data.auraGlow) or "" end,
            set = function(_, v)
              data.auraGlow = tonumber(v)
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, barKey)
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
            end,
          },
          auraGlowList = {
            type = "input",
            name = "Glow Aura IDs (comma/space separated)",
            order = 3.1,
            width = "full",
            get = function() return joinIDList(data.auraGlowList) end,
            set = function(_, v)
              data.auraGlowList = parseIDList(v)
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, barKey)
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
            end,
          },
          auraGlowListIcons = {
            type = "description",
            name = function() return "Current:  " .. auraIconsString(data.auraGlowList) end,
            order = 3.5,
            fontSize = "medium",
          },
          clearGlowList = {
            type = "execute",
            name = "Clear Glow List",
            order = 3.6,
            func = function()
              data.auraGlowList = nil
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, barKey)
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
            end,
          },
          clearAuraGlow = {
            type = "execute",
            name = "Clear Aura Glow",
            order = 4,
            func = function()
              data.auraGlow = nil; addon:BuildFramesForSpec()
            end,
          },
          soundOnGlow = {
            type = "select",
            name = "Sound on Glow",
            order = 4.5,
            width = "normal",
            values = function()
              local t = { none = "(none)" }
              local LSM = LibStub("LibSharedMedia-3.0", true)
              if LSM then for k, _ in pairs(LSM:HashTable("sound")) do t[k] = k end end
              return t
            end,
            get = function() return data.soundOnGlow or "none" end,
            set = function(_, v) data.soundOnGlow = v end,
          },
          remove = {
            type = "execute",
            name = "Remove This Spell",
            order = 99,
            confirm = true,
            confirmText = "Remove this spell?",
            func = function()
              table.remove(list, idx)
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, barKey)
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
            end,
          },
        },
      }
    end
  end
  --------------------------------------------------------------------
  -- Options table
  --------------------------------------------------------------------
  local opts = {
    type = "group",
    name = "ClassHUD",
    childGroups = "tab",
    args = {
      ----------------------------------------------------------------
      -- Bars (global config) — FULL like your original
      ----------------------------------------------------------------
      bars = {
        type = "group",
        name = "Bars",
        order = 1,
        args = {
          locked = {
            type = "toggle",
            name = "Lock frame",
            order = 1,
            set = function(_, v) db.profile.locked = v end,
            get = function() return db.profile.locked end,
          },
          width = {
            type = "range",
            name = "Width",
            min = 240,
            max = 800,
            step = 1,
            order = 2,
            set = function(_, v)
              db.profile.width = v
              addon:FullUpdate()
              if addon.BuildFramesForSpec then addon:BuildFramesForSpec() end
            end,
            get = function() return db.profile.width end,
          },
          spacing = {
            type = "range",
            name = "Bar spacing",
            min = 0,
            max = 12,
            step = 1,
            order = 3,
            set = function(_, v)
              db.profile.spacing = v
              addon:FullUpdate()
              if addon.BuildFramesForSpec then addon:BuildFramesForSpec() end
            end,
            get = function() return db.profile.spacing end,
          },
          tex = {
            type = "select",
            dialogControl = "LSM30_Statusbar",
            order = 4,
            name = "Bar texture",
            values = (LSM and LSM:HashTable("statusbar")) or {},
            set = function(_, k)
              db.profile.textures.bar = k; addon:FullUpdate()
            end,
            get = function() return db.profile.textures.bar end,
          },
          font = {
            type = "select",
            dialogControl = "LSM30_Font",
            order = 5,
            name = "Font",
            values = (LSM and LSM:HashTable("font")) or {},
            set = function(_, k)
              db.profile.textures.font = k; addon:FullUpdate()
            end,
            get = function() return db.profile.textures.font end,
          },

          -- Position
          posX = {
            type = "range",
            name = "Position X",
            min = -500,
            max = 500,
            step = 1,
            order = 6,
            set = function(_, v)
              db.profile.position.x = v; addon:ApplyAnchorPosition()
            end,
            get = function() return db.profile.position.x or 0 end,
          },
          posY = {
            type = "range",
            name = "Position Y",
            min = -500,
            max = 500,
            step = 1,
            order = 7,
            set = function(_, v)
              db.profile.position.y = v; addon:ApplyAnchorPosition()
            end,
            get = function() return db.profile.position.y or 0 end,
          },

          -- Cast
          castShow = {
            type = "toggle",
            name = "Show Cast Bar",
            order = 10,
            set = function(_, v)
              db.profile.show.cast = v; addon:FullUpdate()
            end,
            get = function() return db.profile.show.cast end,
          },
          castH = {
            type = "range",
            name = "Cast Height",
            min = 10,
            max = 30,
            step = 1,
            order = 11,
            set = function(_, v)
              db.profile.height.cast = v; addon:FullUpdate()
            end,
            get = function() return db.profile.height.cast end,
          },

          -- HP
          hpShow = {
            type = "toggle",
            name = "Show HP Bar",
            order = 20,
            set = function(_, v)
              db.profile.show.hp = v; addon:FullUpdate()
            end,
            get = function() return db.profile.show.hp end,
          },
          hpH = {
            type = "range",
            name = "HP Height",
            min = 8,
            max = 30,
            step = 1,
            order = 21,
            set = function(_, v)
              db.profile.height.hp = v; addon:FullUpdate()
            end,
            get = function() return db.profile.height.hp end,
          },

          -- Primary Resource
          resShow = {
            type = "toggle",
            name = "Show Primary Resource Bar",
            order = 30,
            set = function(_, v)
              db.profile.show.resource = v; addon:FullUpdate()
            end,
            get = function() return db.profile.show.resource end,
          },
          resH = {
            type = "range",
            name = "Primary Height",
            min = 8,
            max = 30,
            step = 1,
            order = 31,
            set = function(_, v)
              db.profile.height.resource = v; addon:FullUpdate()
            end,
            get = function() return db.profile.height.resource end,
          },
          resClass = {
            type = "toggle",
            name = "Primary uses Class Color",
            order = 32,
            set = function(_, v)
              db.profile.colors.resourceClass = v; addon:FullUpdate()
            end,
            get = function() return db.profile.colors.resourceClass end,
          },
          resColor = {
            type = "color",
            name = "Primary Custom Color",
            hasAlpha = false,
            order = 33,
            set = function(_, r, g, b)
              db.profile.colors.resource = { r = r, g = g, b = b }; addon:FullUpdate()
            end,
            get = function()
              local c = db.profile.colors.resource; return c.r, c.g, c.b
            end,
          },

          -- Special Power
          powShow = {
            type = "toggle",
            name = "Show Special Power Bar",
            order = 40,
            set = function(_, v)
              db.profile.show.power = v; addon:FullUpdate()
            end,
            get = function() return db.profile.show.power end,
          },
          powH = {
            type = "range",
            name = "Special Height",
            min = 8,
            max = 30,
            step = 1,
            order = 41,
            set = function(_, v)
              db.profile.height.power = v; addon:FullUpdate()
            end,
            get = function() return db.profile.height.power end,
          },
          powS = {
            type = "range",
            name = "Special spacing",
            min = 0,
            max = 10,
            step = 1,
            order = 42,
            set = function(_, v)
              db.profile.powerSpacing = v; addon:FullUpdate()
            end,
            get = function() return db.profile.powerSpacing end,
          },
          powColor = {
            type = "color",
            name = "Special Segment Color",
            hasAlpha = false,
            order = 43,
            set = function(_, r, g, b)
              db.profile.colors.power = { r = r, g = g, b = b }; addon:FullUpdate()
            end,
            get = function()
              local c = db.profile.colors.power; return c.r, c.g, c.b
            end,
          },
          iconText = {
            type = "group",
            name = "Icon Text",
            inline = true,
            order = 50,
            args = {
              headerCount = { type = "header", name = "Charge Count", order = 1 },
              countSize = {
                type = "range",
                name = "Size",
                min = 8,
                max = 32,
                step = 1,
                order = 2,
                set = function(_, v)
                  db.profile.iconText.count.size = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.count.size end,
              },
              countColor = {
                type = "color",
                name = "Color",
                hasAlpha = false,
                order = 3,
                set = function(_, r, g, b)
                  db.profile.iconText.count.color = { r = r, g = g, b = b }; addon:BuildFramesForSpec()
                end,
                get = function()
                  local c = db.profile.iconText.count.color; return c.r, c.g, c.b
                end,
              },
              countPoint = {
                type = "select",
                name = "Position",
                order = 4,
                values = { TOPLEFT = "Top Left", TOPRIGHT = "Top Right", BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right", CENTER = "Center" },
                set = function(_, v)
                  db.profile.iconText.count.point = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.count.point end,
              },
              countOfsX = {
                type = "range",
                name = "Offset X",
                min = -20,
                max = 20,
                step = 1,
                order = 5,
                set = function(_, v)
                  db.profile.iconText.count.ofsX = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.count.ofsX end,
              },
              countOfsY = {
                type = "range",
                name = "Offset Y",
                min = -20,
                max = 20,
                step = 1,
                order = 6,
                set = function(_, v)
                  db.profile.iconText.count.ofsY = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.count.ofsY end,
              },

              spacer1 = { type = "description", name = " ", order = 9 },

              headerAura = { type = "header", name = "Aura ID Label", order = 10 },
              auraEnabled = {
                type = "toggle",
                name = "Show Aura ID",
                order = 11,
                set = function(_, v)
                  db.profile.iconText.aura.enabled = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.aura.enabled end,
              },
              auraSize = {
                type = "range",
                name = "Size",
                min = 8,
                max = 32,
                step = 1,
                order = 12,
                set = function(_, v)
                  db.profile.iconText.aura.size = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.aura.size end,
              },
              auraColor = {
                type = "color",
                name = "Color",
                hasAlpha = false,
                order = 13,
                set = function(_, r, g, b)
                  db.profile.iconText.aura.color = { r = r, g = g, b = b }; addon:BuildFramesForSpec()
                end,
                get = function()
                  local c = db.profile.iconText.aura.color; return c.r, c.g, c.b
                end,
              },
              auraPoint = {
                type = "select",
                name = "Position",
                order = 14,
                values = { TOPLEFT = "Top Left", TOPRIGHT = "Top Right", BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right", CENTER = "Center" },
                set = function(_, v)
                  db.profile.iconText.aura.point = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.aura.point end,
              },
              auraOfsX = {
                type = "range",
                name = "Offset X",
                min = -20,
                max = 20,
                step = 1,
                order = 15,
                set = function(_, v)
                  db.profile.iconText.aura.ofsX = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.aura.ofsX end,
              },
              auraOfsY = {
                type = "range",
                name = "Offset Y",
                min = -20,
                max = 20,
                step = 1,
                order = 16,
                set = function(_, v)
                  db.profile.iconText.aura.ofsY = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.iconText.aura.ofsY end,
              },
            },
          },

        },
      },
      ----------------------------------------------------------------
      -- Top Bar (tabs: Layout + Tracked Spells)
      ----------------------------------------------------------------
      topBar = {
        type = "group",
        name = "Top Bar",
        order = 3,
        childGroups = "tab",
        args = {
          layout = {
            type = "group",
            name = "Layout",
            order = 1,
            args = {
              perRow = {
                type = "range",
                name = "Icons per Row",
                min = 1,
                max = 20,
                step = 1,
                set = function(_, v)
                  db.profile.topBar.perRow = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.topBar.perRow or 8 end,
              },
              spacingX = {
                type = "range",
                name = "Horizontal Spacing",
                min = 0,
                max = 20,
                step = 1,
                set = function(_, v)
                  db.profile.topBar.spacingX = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.topBar.spacingX or 4 end,
              },
              spacingY = {
                type = "range",
                name = "Vertical Spacing",
                min = 0,
                max = 20,
                step = 1,
                set = function(_, v)
                  db.profile.topBar.spacingY = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.topBar.spacingY or 4 end,
              },
              yOffset = {
                type = "range",
                name = "Y Offset",
                min = -200,
                max = 200,
                step = 1,
                set = function(_, v)
                  db.profile.topBar.yOffset = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.topBar.yOffset or 0 end,
              },
            },
          },

          -- Tracked Spells
          addSpell = {
            type = "input",
            name = "Add Spell ID",
            order = 2,
            set = function(_, val)
              local id = tonumber(val)
              local info = id and C_Spell.GetSpellInfo(id)
              if not info then
                print("|cffff0000Invalid spell ID:|r", val)
                return
              end
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.topBarSpells[specID] = db.profile.topBarSpells[specID] or {}
              table.insert(db.profile.topBarSpells[specID],
                { spellID = id, trackCooldown = true, glowEnabled = true, iconFromAura = true }
              )
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, "top")
              ForceRefresh("top")
            end,
            get = function() return "" end,
          },
          addFromList = {
            type = "select",
            name = "Add From List",
            order = 3,
            values = function()
              local _, class    = UnitClass("player")
              local specID      = GetSpecializationInfo(GetSpecialization() or 0)
              local out         = {}
              local classTable  = suggestedSpells[class] or {}
              local specList    = classTable[specID] or {}
              local utilityList = classTable.UTILITY or {}
              for _, spell in ipairs(specList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then out[spell.id] = ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, spell.id) end
              end
              for _, spell in ipairs(utilityList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then out[spell.id] = ("|T%d:16|t %s (%d) [Utility]"):format(info.iconID, info.name, spell.id) end
              end
              return out
            end,
            set = function(_, val)
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.topBarSpells[specID] = db.profile.topBarSpells[specID] or {}
              table.insert(db.profile.topBarSpells[specID], { spellID = val, trackCooldown = true })
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, "top")
              ForceRefresh("top")
            end,
            get = function() return nil end,
          },
          spells = { type = "group", name = "Tracked Spells", order = 4, args = {} },
        },
      },

      ----------------------------------------------------------------
      -- Bottom Bar (tabs: Layout + Tracked Spells)
      ----------------------------------------------------------------
      bottomBar = {
        type = "group",
        name = "Bottom Bar",
        order = 4,
        childGroups = "tab",
        args = {
          layout = {
            type = "group",
            name = "Layout",
            order = 1,
            args = {
              perRow = {
                type = "range",
                name = "Icons per Row",
                min = 1,
                max = 20,
                step = 1,
                set = function(_, v)
                  db.profile.bottomBar.perRow = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.bottomBar.perRow or 8 end,
              },
              spacingX = {
                type = "range",
                name = "Horizontal Spacing",
                min = 0,
                max = 20,
                step = 1,
                set = function(_, v)
                  db.profile.bottomBar.spacingX = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.bottomBar.spacingX or 4 end,
              },
              spacingY = {
                type = "range",
                name = "Vertical Spacing",
                min = 0,
                max = 20,
                step = 1,
                set = function(_, v)
                  db.profile.bottomBar.spacingY = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.bottomBar.spacingY or 4 end,
              },
              yOffset = {
                type = "range",
                name = "Y Offset",
                min = -200,
                max = 200,
                step = 1,
                set = function(_, v)
                  db.profile.bottomBar.yOffset = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.bottomBar.yOffset or 0 end,
              },
            },
          },

          -- Tracked Spells
          addSpell = {
            type = "input",
            name = "Add Spell ID",
            order = 2,
            set = function(_, val)
              local id = tonumber(val)
              local info = id and C_Spell.GetSpellInfo(id)
              if not info then
                print("|cffff0000Invalid spell ID:|r", val)
                return
              end
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.bottomBarSpells[specID] = db.profile.bottomBarSpells[specID] or {}
              table.insert(db.profile.bottomBarSpells[specID],
                { spellID = id, trackCooldown = true, glowEnabled = true, iconFromAura = true }
              )
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, "bottom")
              ForceRefresh("bottom")
            end,
            get = function() return "" end,
          },
          addFromList = {
            type = "select",
            name = "Add From List",
            order = 3,
            values = function()
              local _, class    = UnitClass("player")
              local specID      = GetSpecializationInfo(GetSpecialization() or 0)
              local out         = {}
              local classTable  = suggestedSpells[class] or {}
              local specList    = classTable[specID] or {}
              local utilityList = classTable.UTILITY or {}
              for _, spell in ipairs(specList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then out[spell.id] = ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, spell.id) end
              end
              for _, spell in ipairs(utilityList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then out[spell.id] = ("|T%d:16|t %s (%d) [Utility]"):format(info.iconID, info.name, spell.id) end
              end
              return out
            end,
            set = function(_, val)
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.bottomBarSpells[specID] = db.profile.bottomBarSpells[specID] or {}
              table.insert(db.profile.bottomBarSpells[specID], { spellID = val, trackCooldown = true })
              addon:BuildFramesForSpec()
              RebuildSpellTree(opts, db, addon, "bottom")
              ForceRefresh("bottom")
            end,
            get = function() return nil end,
          },
          spells = { type = "group", name = "Tracked Spells", order = 4, args = {} },
        },
      },
      sidebars = {
        type = "group",
        name = "Sidebars",
        order = 5,
        childGroups = "tab",
        args = {
          -- Felles layout for venstre/høyre
          layout = {
            type = "group",
            name = "Layout",
            order = 1,
            args = {
              iconSize = {
                type = "range",
                name = "Icon Size",
                min = 16,
                max = 64,
                step = 1,
                set = function(_, v)
                  db.profile.sideBars.size = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.sideBars.size or 36 end,
              },
              spacing = {
                type = "range",
                name = "Icon Spacing",
                min = 0,
                max = 20,
                step = 1,
                set = function(_, v)
                  db.profile.sideBars.spacing = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.sideBars.spacing or 4 end,
              },
              offset = {
                type = "range",
                name = "Spacing from HUD",
                min = 0,
                max = 100,
                step = 1,
                set = function(_, v)
                  db.profile.sideBars.offset = v; addon:BuildFramesForSpec()
                end,
                get = function() return db.profile.sideBars.offset or 6 end,
              },
            },
          },

          -- Venstre sidebar (spells)
          leftBar = {
            type = "group",
            name = "Left Bar",
            order = 2,
            args = {
              addSpell = {
                type = "input",
                name = "Add Spell ID",
                order = 1,
                set = function(_, val)
                  local id = tonumber(val)
                  local info = id and C_Spell.GetSpellInfo(id)
                  if not info then
                    print("|cffff0000Invalid spell ID:|r", val); return
                  end
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  db.profile.leftBarSpells[specID] = db.profile.leftBarSpells[specID] or {}
                  table.insert(db.profile.leftBarSpells[specID],
                    { spellID = id, trackCooldown = true, glowEnabled = true, iconFromAura = true }
                  )
                  addon:BuildFramesForSpec()
                  RebuildSpellTree(opts, db, addon, "left")
                  ForceRefresh("left")
                end,
                get = function() return "" end,
              },
              addFromList = {
                type = "select",
                name = "Add From List",
                order = 2,
                values = function()
                  local _, class    = UnitClass("player")
                  local specID      = GetSpecializationInfo(GetSpecialization() or 0)
                  local out         = {}
                  local classTable  = (_G.ClassHUD_SpellSuggestions or {})[class] or {}
                  local specList    = classTable[specID] or {}
                  local utilityList = classTable.UTILITY or {}
                  for _, s in ipairs(specList) do
                    local i = C_Spell.GetSpellInfo(s.id)
                    if i then out[s.id] = ("|T%d:16|t %s (%d)"):format(i.iconID, i.name, s.id) end
                  end
                  for _, s in ipairs(utilityList) do
                    local i = C_Spell.GetSpellInfo(s.id)
                    if i then out[s.id] = ("|T%d:16|t %s (%d) [Utility]"):format(i.iconID, i.name, s.id) end
                  end
                  return out
                end,
                set = function(_, val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  db.profile.leftBarSpells[specID] = db.profile.leftBarSpells[specID] or {}
                  table.insert(db.profile.leftBarSpells[specID], { spellID = val, trackCooldown = true })
                  addon:BuildFramesForSpec()
                  RebuildSpellTree(opts, db, addon, "left")
                  ForceRefresh("left")
                end,
                get = function() return nil end,
              },
              spells = { type = "group", name = "Tracked Spells", order = 3, args = {} },
            },
          },

          -- Høyre sidebar (spells)
          rightBar = {
            type = "group",
            name = "Right Bar",
            order = 3,
            args = {
              addSpell = {
                type = "input",
                name = "Add Spell ID",
                order = 1,
                set = function(_, val)
                  local id = tonumber(val)
                  local info = id and C_Spell.GetSpellInfo(id)
                  if not info then
                    print("|cffff0000Invalid spell ID:|r", val); return
                  end
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  db.profile.rightBarSpells[specID] = db.profile.rightBarSpells[specID] or {}
                  table.insert(db.profile.rightBarSpells[specID],
                    { spellID = id, trackCooldown = true, glowEnabled = true, iconFromAura = true }
                  )
                  addon:BuildFramesForSpec()
                  RebuildSpellTree(opts, db, addon, "right")
                  ForceRefresh("right")
                end,
                get = function() return "" end,
              },
              addFromList = {
                type = "select",
                name = "Add From List",
                order = 2,
                values = function()
                  local _, class    = UnitClass("player")
                  local specID      = GetSpecializationInfo(GetSpecialization() or 0)
                  local out         = {}
                  local classTable  = (_G.ClassHUD_SpellSuggestions or {})[class] or {}
                  local specList    = classTable[specID] or {}
                  local utilityList = classTable.UTILITY or {}
                  for _, s in ipairs(specList) do
                    local i = C_Spell.GetSpellInfo(s.id)
                    if i then out[s.id] = ("|T%d:16|t %s (%d)"):format(i.iconID, i.name, s.id) end
                  end
                  for _, s in ipairs(utilityList) do
                    local i = C_Spell.GetSpellInfo(s.id)
                    if i then out[s.id] = ("|T%d:16|t %s (%d) [Utility]"):format(i.iconID, i.name, s.id) end
                  end
                  return out
                end,
                set = function(_, val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  db.profile.rightBarSpells[specID] = db.profile.rightBarSpells[specID] or {}
                  table.insert(db.profile.rightBarSpells[specID], { spellID = val, trackCooldown = true })
                  addon:BuildFramesForSpec()
                  RebuildSpellTree(opts, db, addon, "right")
                  ForceRefresh("right")
                end,
                get = function() return nil end,
              },
              spells = { type = "group", name = "Tracked Spells", order = 3, args = {} },
            },
          },
        },
      }

    },
  }

  -- Build dynamic spell groups for all bars on open
  RebuildSpellTree(opts, db, addon, "top")
  RebuildSpellTree(opts, db, addon, "bottom")
  RebuildSpellTree(opts, db, addon, "left")
  RebuildSpellTree(opts, db, addon, "right")
  addon._opts = opts -- keep a stable reference for later calls
  return opts
end
