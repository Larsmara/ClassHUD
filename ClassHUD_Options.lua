-- ClassHUD_Options.lua
function ClassHUD_BuildOptions(addon)
  local db              = addon.db
  local LSM             = LibStub("LibSharedMedia-3.0", true)

  -- Ensure defaults exist
  db.profile.textures   = db.profile.textures or { bar = "Blizzard", font = "Friz Quadrata TT" }
  db.profile.show       = db.profile.show or { cast = true, hp = true, resource = true, power = true }
  db.profile.height     = db.profile.height or { cast = 18, hp = 14, resource = 14, power = 14 }
  db.profile.colors     = db.profile.colors or {
    resource = { r = 0, g = 0.55, b = 1 },
    power = { r = 1, g = 0.85, b = 0.1 },
    resourceClass = true,
  }
  db.profile.icons      = db.profile.icons or { enabled = true, size = 36, spacing = 4 }
  db.profile.position   = db.profile.position or { x = 0, y = -150 }

  -- Suggested spells per class/spec
  local suggestedSpells = _G.ClassHUD_SpellSuggestions or {}

  local opts            = {
    type = "group",
    name = "ClassHUD",
    childGroups = "tab",
    args = {
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

          -- Special
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
        },
      },
      sidebarConfig = {
        type = "group",
        name = "Sidebar config",
        order = 2,
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
      topBar = {
        type = "group",
        name = "Top Bar",
        order = 2,
        childGroups = "tab", -- tabs inside Top Bar
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

          spells = {
            type = "group",
            name = "Tracked Spells",
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
                    print("|cffff0000Invalid spell ID:|r", val)
                    return
                  end
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  db.profile.topBarSpells[specID] = db.profile.topBarSpells[specID] or {}
                  table.insert(db.profile.topBarSpells[specID], { spellID = id, trackCooldown = true })
                  addon._selectedTopSpellIndex = #db.profile.topBarSpells[specID]
                  addon:BuildFramesForSpec()
                  LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
                end,
                get = function() return "" end,
              },

              addFromList = {
                type = "select",
                name = "Add From List",
                order = 2,
                values = function()
                  local _, class = UnitClass("player")
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local out, specList, utilityList = {}, suggestedSpells[class][specID] or {},
                      suggestedSpells[class].UTILITY or {}
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
                  LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
                end,
                get = function() return nil end,
              },

              list = {
                type = "select",
                name = "Tracked Spells",
                order = 3,
                width = "full",
                values = function()
                  local specID, out = GetSpecializationInfo(GetSpecialization() or 0), {}
                  local spells = db.profile.topBarSpells[specID] or {}
                  for i, data in ipairs(spells) do
                    local info = C_Spell.GetSpellInfo(data.spellID)
                    out[i] = info and ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, data.spellID)
                        or "Unknown (" .. data.spellID .. ")"
                  end
                  return out
                end,
                set = function(_, key) addon._selectedTopSpellIndex = key end,
                get = function() return addon._selectedTopSpellIndex end,
              },

              trackCooldown = {
                type = "toggle",
                name = "Track Cooldown",
                order = 4,
                disabled = function() return not addon._selectedTopSpellIndex end,
                set = function(_, v)
                  local specID, idx = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex
                  if idx then
                    db.profile.topBarSpells[specID][idx].trackCooldown = v; addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID, idx = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex
                  return idx and db.profile.topBarSpells[specID][idx].trackCooldown
                end,
              },

              countFromAura = {
                type = "input",
                name = "Aura SpellID for Stacks",
                order = 5,
                disabled = function() return not addon._selectedTopSpellIndex end,
                set = function(_, val)
                  local specID, idx, id = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex,
                      tonumber(val)
                  if idx then
                    db.profile.topBarSpells[specID][idx].countFromAura = id; addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID, idx = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex
                  return idx and (db.profile.topBarSpells[specID][idx].countFromAura or "")
                end,
              },

              auraGlow = {
                type = "input",
                name = "Aura SpellID for Glow",
                order = 6,
                disabled = function() return not addon._selectedTopSpellIndex end,
                set = function(_, val)
                  local specID, idx, id = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex,
                      tonumber(val)
                  if idx then
                    db.profile.topBarSpells[specID][idx].auraGlow = id; addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID, idx = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex
                  return idx and (db.profile.topBarSpells[specID][idx].auraGlow or "")
                end,
              },

              clearAuraGlow = {
                type = "execute",
                name = "Clear Aura Glow",
                order = 7,
                disabled = function() return not addon._selectedTopSpellIndex end,
                func = function()
                  local specID, idx = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex
                  if idx then
                    db.profile.topBarSpells[specID][idx].auraGlow = nil
                    addon:BuildFramesForSpec()
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
                  end
                end,
              },

              remove = {
                type = "execute",
                name = "Remove This Spell",
                order = 99,
                confirm = true,
                confirmText = "Remove this spell?",
                disabled = function() return not addon._selectedTopSpellIndex end,
                func = function()
                  local specID, idx = GetSpecializationInfo(GetSpecialization() or 0), addon._selectedTopSpellIndex
                  if idx and db.profile.topBarSpells[specID][idx] then
                    table.remove(db.profile.topBarSpells[specID], idx)
                    addon._selectedTopSpellIndex = nil
                    addon:BuildFramesForSpec()
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
                  end
                end,
              },
            },
          },
        },
      },

      bottomBar = {
        type = "group",
        name = "Bottom Bar",
        order = 4,
        args = {
          layout = {
            type = "group",
            name = "Layout",
            inline = true,
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
                get = function() return (db.profile.bottomBar and db.profile.bottomBar.spacingX) or 4 end,
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
                get = function() return (db.profile.bottomBar and db.profile.bottomBar.spacingY) or 4 end,
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
              table.insert(db.profile.bottomBarSpells[specID], {
                spellID = id,
                trackCooldown = true,
              })
              addon:BuildFramesForSpec()
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
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

              local specList    = suggestedSpells[class][specID] or {}
              local utilityList = suggestedSpells[class].UTILITY or {}

              -- Merge spec + utility
              for _, spell in ipairs(specList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then
                  out[spell.id] = ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, spell.id)
                end
              end

              for _, spell in ipairs(utilityList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then
                  out[spell.id] = ("|T%d:16|t %s (%d) [Utility]"):format(info.iconID, info.name, spell.id)
                end
              end

              return out
            end,
            set = function(_, val)
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.bottomBarSpells[specID] = db.profile.bottomBarSpells[specID] or {}
              table.insert(db.profile.bottomBarSpells[specID], {
                spellID = val,
                trackCooldown = true,
              })
              addon:BuildFramesForSpec()
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
            end,
            get = function() return nil end,
          },
          addedSpells = {
            type = "group",
            name = "Tracked Spells",
            inline = true,
            order = 3,
            args = {
              list = {
                type = "select",
                name = "Tracked Spells",
                desc = "Select a spell to configure or remove.",
                order = 1,
                values = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local out = {}
                  local spells = db.profile.bottomBarSpells[specID] or {}
                  for i, data in ipairs(spells) do
                    local info = C_Spell.GetSpellInfo(data.spellID)
                    out[i] = info and ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, data.spellID)
                        or "Unknown (" .. data.spellID .. ")"
                  end
                  return out
                end,
                set = function(_, key)
                  addon._selectedBottomSpellIndex = key
                end,
                get = function()
                  return addon._selectedBottomSpellIndex or nil
                end,
              },
              removeSpell = {
                type = "execute",
                name = "Remove Selected Spell",
                order = 2,
                func = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedBottomSpellIndex
                  if idx and db.profile.bottomBarSpells[specID] and db.profile.bottomBarSpells[specID][idx] then
                    table.remove(db.profile.bottomBarSpells[specID], idx)
                    addon._selectedBottomSpellIndex = nil
                    addon:BuildFramesForSpec()
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
                  end
                end,
              },
              trackCooldown = {
                type = "toggle",
                name = "Track Cooldown",
                order = 3,
                set = function(_, val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedBottomSpellIndex
                  if idx and db.profile.bottomBarSpells[specID] and db.profile.bottomBarSpells[specID][idx] then
                    db.profile.bottomBarSpells[specID][idx].trackCooldown = val
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedBottomSpellIndex
                  if idx and db.profile.bottomBarSpells[specID] and db.profile.bottomBarSpells[specID][idx] then
                    return db.profile.bottomBarSpells[specID][idx].trackCooldown or false
                  end
                  return false
                end,
              },
              countFromAura = {
                type = "input",
                name = "Aura Count (SpellID)",
                order = 4,
                set = function(_, val)
                  local id = tonumber(val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedBottomSpellIndex
                  if idx and db.profile.bottomBarSpells[specID] and db.profile.bottomBarSpells[specID][idx] then
                    db.profile.bottomBarSpells[specID][idx].countFromAura = id
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedBottomSpellIndex
                  if idx and db.profile.bottomBarSpells[specID] and db.profile.bottomBarSpells[specID][idx] then
                    return tostring(db.profile.bottomBarSpells[specID][idx].countFromAura or "")
                  end
                  return ""
                end,
              },
              auraGlow = {
                type = "input",
                name = "Aura Glow (SpellID)",
                order = 5,
                set = function(_, val)
                  local id = tonumber(val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedBottomSpellIndex
                  if idx and db.profile.bottomBarSpells[specID] and db.profile.bottomBarSpells[specID][idx] then
                    db.profile.bottomBarSpells[specID][idx].auraGlow = id
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedBottomSpellIndex
                  if idx and db.profile.bottomBarSpells[specID] and db.profile.bottomBarSpells[specID][idx] then
                    return tostring(db.profile.bottomBarSpells[specID][idx].auraGlow or "")
                  end
                  return ""
                end,
              },
            }
          },
        },
      },
      leftBar = {
        type = "group",
        name = "Left Bar",
        order = 4,
        args = {
          addSpell = {
            type = "input",
            name = "Add Spell ID",
            order = 1,
            set = function(_, val)
              local id = tonumber(val)
              local info = id and C_Spell.GetSpellInfo(id)
              if not info then
                print("|cffff0000Invalid spell ID:|r", val)
                return
              end
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.leftBarSpells[specID] = db.profile.leftBarSpells[specID] or {}
              table.insert(db.profile.leftBarSpells[specID], {
                spellID = id,
                trackCooldown = true,
              })
              addon:BuildFramesForSpec()
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
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

              local specList    = suggestedSpells[class][specID] or {}
              local utilityList = suggestedSpells[class].UTILITY or {}

              -- Merge spec + utility
              for _, spell in ipairs(specList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then
                  out[spell.id] = ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, spell.id)
                end
              end

              for _, spell in ipairs(utilityList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then
                  out[spell.id] = ("|T%d:16|t %s (%d) [Utility]"):format(info.iconID, info.name, spell.id)
                end
              end

              return out
            end,
            set = function(_, val)
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.leftBarSpells[specID] = db.profile.leftBarSpells[specID] or {}
              table.insert(db.profile.leftBarSpells[specID], {
                spellID = val,
                trackCooldown = true,
              })
              addon:BuildFramesForSpec()
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
            end,
            get = function() return nil end,
          },
          addedSpells = {
            type = "group",
            name = "Tracked Spells",
            inline = true,
            order = 3,
            args = {
              list = {
                type = "select",
                name = "Tracked Spells",
                desc = "Select a spell to configure or remove.",
                order = 1,
                values = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local out = {}
                  local spells = db.profile.leftBarSpells[specID] or {}
                  for i, data in ipairs(spells) do
                    local info = C_Spell.GetSpellInfo(data.spellID)
                    out[i] = info and ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, data.spellID)
                        or "Unknown (" .. data.spellID .. ")"
                  end
                  return out
                end,
                set = function(_, key)
                  addon._selectedLeftSpellIndex = key
                end,
                get = function()
                  return addon._selectedLeftSpellIndex or nil
                end,
              },
              removeSpell = {
                type = "execute",
                name = "Remove Selected Spell",
                order = 2,
                func = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedLeftSpellIndex
                  if idx and db.profile.leftBarSpells[specID] and db.profile.leftBarSpells[specID][idx] then
                    table.remove(db.profile.leftBarSpells[specID], idx)
                    addon._selectedLeftSpellIndex = nil
                    addon:BuildFramesForSpec()
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
                  end
                end,
              },
              trackCooldown = {
                type = "toggle",
                name = "Track Cooldown",
                order = 3,
                set = function(_, val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedLeftSpellIndex
                  if idx and db.profile.leftBarSpells[specID] and db.profile.leftBarSpells[specID][idx] then
                    db.profile.leftBarSpells[specID][idx].trackCooldown = val
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedLeftSpellIndex
                  if idx and db.profile.leftBarSpells[specID] and db.profile.leftBarSpells[specID][idx] then
                    return db.profile.leftBarSpells[specID][idx].trackCooldown or false
                  end
                  return false
                end,
              },
              countFromAura = {
                type = "input",
                name = "Aura Count (SpellID)",
                order = 4,
                set = function(_, val)
                  local id = tonumber(val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedLeftSpellIndex
                  if idx and db.profile.leftBarSpells[specID] and db.profile.leftBarSpells[specID][idx] then
                    db.profile.leftBarSpells[specID][idx].countFromAura = id
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedLeftSpellIndex
                  if idx and db.profile.leftBarSpells[specID] and db.profile.leftBarSpells[specID][idx] then
                    return tostring(db.profile.leftBarSpells[specID][idx].countFromAura or "")
                  end
                  return ""
                end,
              },
              auraGlow = {
                type = "input",
                name = "Aura Glow (SpellID)",
                order = 5,
                set = function(_, val)
                  local id = tonumber(val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedLeftSpellIndex
                  if idx and db.profile.leftBarSpells[specID] and db.profile.leftBarSpells[specID][idx] then
                    db.profile.leftBarSpells[specID][idx].auraGlow = id
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedLeftSpellIndex
                  if idx and db.profile.leftBarSpells[specID] and db.profile.leftBarSpells[specID][idx] then
                    return tostring(db.profile.leftBarSpells[specID][idx].auraGlow or "")
                  end
                  return ""
                end,
              },
            }
          },
        },
      },
      rightBarBar = {
        type = "group",
        name = "Right Bar",
        order = 4,
        args = {
          addSpell = {
            type = "input",
            name = "Add Spell ID",
            order = 1,
            set = function(_, val)
              local id = tonumber(val)
              local info = id and C_Spell.GetSpellInfo(id)
              if not info then
                print("|cffff0000Invalid spell ID:|r", val)
                return
              end
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.rightBarSpells[specID] = db.profile.rightBarSpells[specID] or {}
              table.insert(db.profile.rightBarSpells[specID], {
                spellID = id,
                trackCooldown = true,
              })
              addon:BuildFramesForSpec()
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
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

              local specList    = suggestedSpells[class][specID] or {}
              local utilityList = suggestedSpells[class].UTILITY or {}

              -- Merge spec + utility
              for _, spell in ipairs(specList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then
                  out[spell.id] = ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, spell.id)
                end
              end

              for _, spell in ipairs(utilityList) do
                local info = C_Spell.GetSpellInfo(spell.id)
                if info then
                  out[spell.id] = ("|T%d:16|t %s (%d) [Utility]"):format(info.iconID, info.name, spell.id)
                end
              end

              return out
            end,
            set = function(_, val)
              local specID = GetSpecializationInfo(GetSpecialization() or 0)
              db.profile.rightBarSpells[specID] = db.profile.rightBarSpells[specID] or {}
              table.insert(db.profile.rightBarSpells[specID], {
                spellID = val,
                trackCooldown = true,
              })
              addon:BuildFramesForSpec()
              LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
            end,
            get = function() return nil end,
          },
          addedSpells = {
            type = "group",
            name = "Tracked Spells",
            inline = true,
            order = 3,
            args = {
              list = {
                type = "select",
                name = "Tracked Spells",
                desc = "Select a spell to configure or remove.",
                order = 1,
                values = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local out = {}
                  local spells = db.profile.rightBarSpells[specID] or {}
                  for i, data in ipairs(spells) do
                    local info = C_Spell.GetSpellInfo(data.spellID)
                    out[i] = info and ("|T%d:16|t %s (%d)"):format(info.iconID, info.name, data.spellID)
                        or "Unknown (" .. data.spellID .. ")"
                  end
                  return out
                end,
                set = function(_, key)
                  addon._selectedRightSpellIndex = key
                end,
                get = function()
                  return addon._selectedRightSpellIndex or nil
                end,
              },
              removeSpell = {
                type = "execute",
                name = "Remove Selected Spell",
                order = 2,
                func = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedRightSpellIndex
                  if idx and db.profile.rightBarSpells[specID] and db.profile.rightBarSpells[specID][idx] then
                    table.remove(db.profile.rightBarSpells[specID], idx)
                    addon._selectedRightSpellIndex = nil
                    addon:BuildFramesForSpec()
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("ClassHUD")
                  end
                end,
              },
              trackCooldown = {
                type = "toggle",
                name = "Track Cooldown",
                order = 3,
                set = function(_, val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedRightSpellIndex
                  if idx and db.profile.rightBarSpells[specID] and db.profile.rightBarSpells[specID][idx] then
                    db.profile.rightBarSpells[specID][idx].trackCooldown = val
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedRightSpellIndex
                  if idx and db.profile.rightBarSpells[specID] and db.profile.rightBarSpells[specID][idx] then
                    return db.profile.rightBarSpells[specID][idx].trackCooldown or false
                  end
                  return false
                end,
              },
              countFromAura = {
                type = "input",
                name = "Aura Count (SpellID)",
                order = 4,
                set = function(_, val)
                  local id = tonumber(val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedRightSpellIndex
                  if idx and db.profile.rightBarSpells[specID] and db.profile.rightBarSpells[specID][idx] then
                    db.profile.rightBarSpells[specID][idx].countFromAura = id
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedRightSpellIndex
                  if idx and db.profile.rightBarSpells[specID] and db.profile.rightBarSpells[specID][idx] then
                    return tostring(db.profile.rightBarSpells[specID][idx].countFromAura or "")
                  end
                  return ""
                end,
              },
              auraGlow = {
                type = "input",
                name = "Aura Glow (SpellID)",
                order = 5,
                set = function(_, val)
                  local id = tonumber(val)
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedRightSpellIndex
                  if idx and db.profile.rightBarSpells[specID] and db.profile.rightBarSpells[specID][idx] then
                    db.profile.rightBarSpells[specID][idx].auraGlow = id
                    addon:BuildFramesForSpec()
                  end
                end,
                get = function()
                  local specID = GetSpecializationInfo(GetSpecialization() or 0)
                  local idx = addon._selectedRightSpellIndex
                  if idx and db.profile.rightBarSpells[specID] and db.profile.rightBarSpells[specID][idx] then
                    return tostring(db.profile.rightBarSpells[specID][idx].auraGlow or "")
                  end
                  return ""
                end,
              },
            }
          },
        },
      },
    },
  }


  return opts
end
