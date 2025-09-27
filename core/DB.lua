local AceDB = LibStub("AceDB-3.0")

---@type ClassHUD
local ClassHUD = _G.ClassHUD

local defaults = {
  profile = {
    debug = false,
    width = 250,
    powerSpacing = 2,
    layout = {
      height = {
        cast = 18,
        hp = 14,
        resource = 14,
        power = 14,
      },
      show = {
        cast = true,
        hp = true,
        resource = true,
        power = true,
        buffs = true,
      },
    },
  },
}

function ClassHUD:InitializeDatabase()
  if self.db then
    return
  end

  self.db = AceDB:New("ClassHUDDB2", defaults, true)
end

function ClassHUD:GetDatabaseDefaults()
  return defaults
end
