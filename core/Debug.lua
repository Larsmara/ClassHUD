---@type ClassHUD
local ClassHUD = _G.ClassHUD

local PREFIX = "|cFF4DB5FFClassHUD:|r "

function ClassHUD:Msg(message)
  local text = tostring(message or "")
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. text)
  else
    print(PREFIX .. text)
  end
end

function ClassHUD:Debug(message)
  if not (self.db and self.db.profile and self.db.profile.debug) then
    return
  end

  self:Msg("[Debug] " .. tostring(message or ""))
end
