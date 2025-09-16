-- ClassHUD_ImpTracker.lua
-- Tracks active Wild Imps for Demonology Warlocks, including passive spawns and implosion resets

local imps = {}
local MAX_CASTS = 6
local WILD_IMP_SPELLID = 104317  -- SPELL_SUMMON
local WILD_IMP_CASTID = 104318   -- Fel Firebolt
local IMPLOSION_SPELLID = 196277 -- Implosion
local WILD_IMP_NAME = "Wild Imp"

local function ScanNameplates()
    for i = 1, 40 do
        local unit = ("nameplate%d"):format(i)
        if UnitExists(unit) then
            local name = UnitName(unit)
            local guid = UnitGUID(unit)
            if name == WILD_IMP_NAME and guid and not imps[guid] then
                imps[guid] = { createdAt = GetTime(), casts = 0, passive = true }
            end
        end
    end
end

local function ClearAllImps()
    wipe(imps)
end

local function OnEvent(_, event)
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")

    if sourceGUID == playerGUID then
        if subEvent == "SPELL_SUMMON" and spellId == WILD_IMP_SPELLID then
            imps[destGUID] = { createdAt = GetTime(), casts = 0 }
        elseif subEvent == "SPELL_CAST_SUCCESS" and spellId == IMPLOSION_SPELLID then
            -- Implosion cast → clear all imps instantly
            ClearAllImps()
        end
    end

    if subEvent == "SPELL_CAST_SUCCESS" and spellId == WILD_IMP_CASTID then
        if imps[sourceGUID] then
            imps[sourceGUID].casts = imps[sourceGUID].casts + 1
            if imps[sourceGUID].casts >= MAX_CASTS then
                imps[sourceGUID] = nil
            end
        end
    elseif subEvent == "UNIT_DIED" and imps[destGUID] then
        imps[destGUID] = nil
    end
end

-- Frame and event binding
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", OnEvent)

-- Periodic scan for passive-spawned imps (Inner Demons)
C_Timer.NewTicker(1, ScanNameplates)

-- Public API
ClassHUD_WildImpTracker = {
    Count = function()
        local count = 0
        for _, data in pairs(imps) do
            count = count + 1
        end
        return count
    end
}

-- Debug command
SLASH_CLASSHUDIMPS1 = "/imps"
SlashCmdList.CLASSHUDIMPS = function()
    print("Active Wild Imps:", ClassHUD_WildImpTracker.Count())
end
