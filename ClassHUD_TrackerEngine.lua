-- ClassHUD_TrackerEngine.lua v2.1
-- Robust hybrid tracker for summoned units with visible unit scanning fallback

local TrackerEngine = {}
local trackedUnits = {}
local summonSpells = {
    [104317] = { name = "Wild Imp", npcID = 55659, duration = 20 },
    [98035]  = { name = "Dreadstalker", npcID = 99706, duration = 12 },
}

local function GetNPCIDFromGUID(guid)
    local parts = { strsplit("-", guid or "") }
    return tonumber(parts[6])
end

local function AddOrRefresh(guid, data)
    trackedUnits[guid] = {
        spellId = data.spellId,
        npcID = data.npcID,
        name = data.name,
        spawned = data.spawned or GetTime(),
        expires = data.expires or (GetTime() + data.duration),
        source = data.source or "log",
    }
end

-- Combat log
local function OnCLEU()
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    if sourceGUID == UnitGUID("player") then
        if subEvent == "SPELL_SUMMON" and summonSpells[spellId] then
            local info = summonSpells[spellId]
            AddOrRefresh(destGUID, {
                spellId = spellId,
                npcID = info.npcID,
                name = info.name,
                duration = info.duration,
                source = "log"
            })
        elseif subEvent == "SPELL_CAST_SUCCESS" and spellId == 196277 then -- Implosion
            for guid, data in pairs(trackedUnits) do
                if data.name == "Wild Imp" then
                    trackedUnits[guid] = nil
                end
            end
        end
    end

    if subEvent == "UNIT_DIED" and trackedUnits[destGUID] then
        trackedUnits[destGUID] = nil
    end
end

-- Totem support
local function RefreshTotems()
    for i = 1, 4 do
        local haveTotem, name, start, duration, icon = GetTotemInfo(i)
        if haveTotem and start > 0 and duration > 0 then
            local guid = "totem-slot-" .. i
            trackedUnits[guid] = {
                name = name,
                spawned = start,
                expires = start + duration,
                icon = icon,
                totemSlot = i,
                source = "totem"
            }
        else
            trackedUnits["totem-slot-" .. i] = nil
        end
    end
end

-- Visible unit scanning fallback
local function ScanVisibleUnits()
    for unit in EnumerateVisibleUnits() do
        local name = UnitName(unit)
        local guid = UnitGUID(unit)
        if name == "Wild Imp" and guid and not trackedUnits[guid] then
            AddOrRefresh(guid, {
                name = "Wild Imp",
                npcID = 55659,
                spellId = 104317,
                duration = 20,
                source = "visible"
            })
        end
    end
end

-- Event setup
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_TOTEM_UPDATE")
frame:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCLEU()
    elseif event == "PLAYER_TOTEM_UPDATE" then
        RefreshTotems()
    end
end)

C_Timer.NewTicker(1, ScanVisibleUnits)

-- Public API
TrackerEngine.GetActiveUnits = function()
    local now = GetTime()
    local active = {}
    for guid, data in pairs(trackedUnits) do
        if not data.expires or data.expires > now then
            table.insert(active, data)
        else
            trackedUnits[guid] = nil
        end
    end
    return active
end

-- Debug command
SLASH_TRACKERENGINE1 = "/summons"
SlashCmdList.TRACKERENGINE = function()
    print("Active tracked units:")
    for _, data in ipairs(TrackerEngine.GetActiveUnits()) do
        print(("- %s (%s, expires in %.1fs)"):format(
            data.name or "?", data.source or "?", data.expires - GetTime()))
    end
end

_G.ClassHUD_TrackerEngine = TrackerEngine
