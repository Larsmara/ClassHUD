-- ClassHUD_Spells.lua (CDM-liste -> egen visningslogikk)
---@type ClassHUD
local ClassHUD = _G.ClassHUD or LibStub("AceAddon-3.0"):GetAddon("ClassHUD")
local UI = ClassHUD.UI

ClassHUD.spellFrames = ClassHUD.spellFrames or {}
ClassHUD.trackedBuffFrames = ClassHUD.trackedBuffFrames or {}
ClassHUD._trackedBuffFramePool = ClassHUD._trackedBuffFramePool or {}

local activeFrames = {}
local trackedBuffPool = ClassHUD._trackedBuffFramePool

local bit_band = bit and bit.band or (bit32 and bit32.band)
local AFFILIATION_MINE = _G.COMBATLOG_OBJECT_AFFILIATION_MINE or 0

local SUMMON_SPELLS = {
  -- Priest
  [34433]  = { fallbackDuration = 15, class = "PRIEST" },   -- Shadowfiend
  [123040] = { fallbackDuration = 12, class = "PRIEST" },   -- Mindbender
  [200174] = { fallbackDuration = 18, class = "PRIEST" },   -- Mindbender

  -- Warlock
  [193332] = { duration = 12, fallbackDuration = 12, class = "WARLOCK", name = "Dreadstalkers", npcID = 98035, displaySpellID = 104316, demon = true },              -- Call Dreadstalkers
  [264119] = { duration = 15, fallbackDuration = 15, class = "WARLOCK", name = "Vilefiend", npcID = 135816, demon = true },                                          -- Summon Vilefiend
  [455465] = { duration = 15, fallbackDuration = 15, class = "WARLOCK", name = "Gloomhound", npcID = 226268, demon = true },                                         -- Summon Gloomhound (Mark of Shatug)
  [455476] = { duration = 15, fallbackDuration = 15, class = "WARLOCK", name = "Charhound", npcID = 226269, demon = true },                                          -- Summon Charhound (Mark of F’harg)
  [111898] = { duration = 17, fallbackDuration = 17, class = "WARLOCK", name = "Grimoire: Felguard", npcID = 17252, demon = true },                                  -- Grimoire: Felguard
  [265187] = { duration = 15, fallbackDuration = 15, class = "WARLOCK", name = "Demonic Tyrant", npcID = 135002, demon = true, tyrant = true, extendDuration = 15 }, -- Summon Demonic Tyrant
  [205180] = { duration = 20, fallbackDuration = 20, class = "WARLOCK", name = "Darkglare", npcID = 103673, demon = true },                                          -- Summon Darkglare

  -- Death Knight
  [42650]  = { fallbackDuration = 30, class = "DEATHKNIGHT" },                                                             -- Army of the Dead (classic ID)
  [275430] = { fallbackDuration = 30, class = "DEATHKNIGHT" },                                                             -- Army of the Dead (alt ID)
  [49206]  = { fallbackDuration = 25, class = "DEATHKNIGHT" },                                                             -- Summon Gargoyle
  [317776] = { duration = 15, fallbackDuration = 15, class = "DEATHKNIGHT", name = "Army of the Damned", npcID = 163366 }, -- Magus of the Dead
  [455395] = { duration = 15, fallbackDuration = 15, class = "DEATHKNIGHT", name = "Abomination", npcID = 149555 },        -- Raise Abomination

  -- Druid
  [205636] = { fallbackDuration = 10, class = "DRUID" }, -- Force of Nature

  -- Monk
  [115313] = { fallbackDuration = 15, class = "MONK" }, -- Jade Serpent Statue
}

local WILD_IMP_SUMMON_IDS = {
  [104317] = true, -- Wild Imp (Hand of Gul'dan)
  [279910] = true, -- Wild Imp (Inner Demons / Nether Portal)
}

local WILD_IMP_NPC_IDS = {
  [55659] = true,  -- Hand of Gul'dan / Nether Portal
  [143622] = true, -- Inner Demons / Nether Portal
}

ClassHUD.SUMMON_SPELLS = SUMMON_SPELLS
ClassHUD.WILD_IMP_SUMMON_IDS = WILD_IMP_SUMMON_IDS
ClassHUD.WILD_IMP_NPC_IDS = WILD_IMP_NPC_IDS

local INACTIVE_BAR_COLOR = { r = 0.25, g = 0.25, b = 0.25, a = 0.6 }
local HARMFUL_GLOW_THRESHOLD = 5
local HARMFUL_GLOW_AURA_CHECK_INTERVAL = 0.1
local HARMFUL_GLOW_UNITS = { "target", "focus" }
local TRACKED_UNITS = { "player", "pet" }
local SPELL_AURA_UNITS_DEFAULT = TRACKED_UNITS
local SPELL_AURA_UNITS_HARMFUL = { "target", "focus" }

local function CopyCandidates(list)
  if type(list) ~= "table" then return nil end
  local copy = {}
  for i = 1, #list do
    copy[i] = list[i]
  end
  return copy
end

local function ExtractAuraSpellID(payload)
  if type(payload) == "number" then
    return payload
  end
  if type(payload) == "table" then
    local spellID = payload.spellId or payload.spellID or payload.spell or payload.id
    if type(spellID) == "number" then
      return spellID
    end
  end
  return nil
end

local function Contains(list, value)
  if type(list) ~= "table" then return false end
  for i = 1, #list do
    if list[i] == value then
      return true
    end
  end
  return false
end

local function IsMine(sourceGUID, sourceFlags)
  local playerGUID = UnitGUID and UnitGUID("player")
  if playerGUID and sourceGUID == playerGUID then
    return true
  end
  if bit_band and sourceFlags and bit_band(sourceFlags, AFFILIATION_MINE) ~= 0 then
    return true
  end
  local petGUID = UnitGUID and UnitGUID("pet")
  if petGUID and sourceGUID == petGUID then
    return true
  end
  return false
end

local function ClearFrameAuraWatchers(frame)
  if not frame then return end

  local spellBuckets = ClassHUD._auraWatchersBySpellID
  local registered = frame._registeredAuraSpellIDs
  if registered and spellBuckets then
    for i = #registered, 1, -1 do
      local spellID = registered[i]
      local bucket = spellBuckets[spellID]
      if bucket then
        bucket[frame] = nil
        if not next(bucket) then
          spellBuckets[spellID] = nil
        end
      end
      registered[i] = nil
    end
  elseif registered then
    wipe(registered)
  end

  local unitBuckets = ClassHUD._auraWatchersByUnit
  local registeredUnits = frame._registeredAuraUnits
  if registeredUnits and unitBuckets then
    for unit in pairs(registeredUnits) do
      local bucket = unitBuckets[unit]
      if bucket then
        bucket[frame] = nil
      end
      registeredUnits[unit] = nil
    end
  elseif registeredUnits then
    wipe(registeredUnits)
  end
end

local function RegisterFrameAuraWatchers(frame, candidates, units)
  if not frame then return end

  ClearFrameAuraWatchers(frame)

  local spellBuckets = ClassHUD._auraWatchersBySpellID
  local unitBuckets = ClassHUD._auraWatchersByUnit

  if type(candidates) == "table" and spellBuckets then
    frame._registeredAuraSpellIDs = frame._registeredAuraSpellIDs or {}
    local registered = frame._registeredAuraSpellIDs
    for i = 1, #candidates do
      local spellID = candidates[i]
      if type(spellID) == "number" and spellID > 0 then
        local bucket = spellBuckets[spellID]
        if not bucket then
          bucket = {}
          spellBuckets[spellID] = bucket
        end
        bucket[frame] = true
        registered[#registered + 1] = spellID
      end
    end
  end

  if type(units) == "table" and unitBuckets then
    frame._registeredAuraUnits = frame._registeredAuraUnits or {}
    local registeredUnits = frame._registeredAuraUnits
    for i = 1, #units do
      local unit = units[i]
      if unitBuckets[unit] then
        unitBuckets[unit][frame] = true
        registeredUnits[unit] = true
      end
    end
  end
end

ClassHUD.ClearFrameAuraWatchers = ClearFrameAuraWatchers
ClassHUD.RegisterFrameAuraWatchers = RegisterFrameAuraWatchers

local function MarkFrameForAuraUpdate(frame)
  if not frame then return end

  local dirty = ClassHUD._pendingAuraFrames
  if not dirty then
    dirty = {}
    ClassHUD._pendingAuraFrames = dirty
  end

  dirty[frame] = true

  if not ClassHUD._auraFlushTimer then
    ClassHUD._auraFlushTimer = ClassHUD:ScheduleTimer("FlushAuraChanges", 0)
  end
end

local concernScratch = {}

local function EnsureConcernBuckets()
  local buckets = ClassHUD._framesByConcern
  if not buckets then
    buckets = {
      cooldown = {},
      range = {},
      resource = {},
      aura = {},
    }
    ClassHUD._framesByConcern = buckets
  else
    buckets.cooldown = buckets.cooldown or {}
    buckets.range = buckets.range or {}
    buckets.resource = buckets.resource or {}
    buckets.aura = buckets.aura or {}
  end
  return buckets
end

local function AddFrameConcern(frame, concern)
  if not frame or not concern then return end
  local buckets = EnsureConcernBuckets()
  local bucket = buckets[concern]
  if not bucket then
    bucket = {}
    buckets[concern] = bucket
  end
  if not bucket[frame] then
    bucket[frame] = true
  end
  frame._concerns = frame._concerns or {}
  frame._concerns[concern] = true
end

local function RemoveFrameConcern(frame, concern)
  if not frame or not concern then return end
  local buckets = ClassHUD._framesByConcern
  if buckets then
    local bucket = buckets[concern]
    if bucket then
      bucket[frame] = nil
    end
  end
  if frame._concerns then
    frame._concerns[concern] = nil
    if not next(frame._concerns) then
      wipe(frame._concerns)
    end
  end
end

local function ClearFrameConcerns(frame)
  if not frame or not frame._concerns then return end
  local buckets = ClassHUD._framesByConcern
  if buckets then
    for concern in pairs(frame._concerns) do
      local bucket = buckets[concern]
      if bucket then
        bucket[frame] = nil
      end
    end
  end
  wipe(frame._concerns)
end

local function ShouldTrackRange(spellID)
  if not spellID then return false end
  if C_Spell and C_Spell.IsSpellHarmful then
    local ok, result = pcall(C_Spell.IsSpellHarmful, spellID)
    if ok and result ~= nil then
      return result
    end
  end
  if IsHarmfulSpell then
    local ok, result = pcall(IsHarmfulSpell, spellID)
    if ok and result ~= nil then
      return result
    end
  end
  return false
end

local function SpellUsesResource(spellID)
  if not spellID then return false end
  local costs = (C_Spell and C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(spellID))
      or (GetSpellPowerCost and GetSpellPowerCost(spellID))
  if type(costs) ~= "table" then return false end

  for _, costInfo in ipairs(costs) do
    local cost = costInfo.cost or costInfo.minCost or 0
    if cost and cost > 0 then
      return true
    end
  end

  return false
end

function ClassHUD:ClearFrameConcerns(frame)
  ClearFrameConcerns(frame)
end

function ClassHUD:RefreshFrameConcerns(frame)
  if not frame then return end
  ClearFrameConcerns(frame)
  AddFrameConcern(frame, "cooldown")
  if ShouldTrackRange(frame.spellID) then
    AddFrameConcern(frame, "range")
  end
  if SpellUsesResource(frame.spellID) then
    AddFrameConcern(frame, "resource")
  end
end

function ClassHUD:AddFrameToConcern(frame, concern)
  AddFrameConcern(frame, concern)
end

function ClassHUD:RemoveFrameFromConcern(frame, concern)
  RemoveFrameConcern(frame, concern)
end

local function EnsureAttachment(name)
  if not UI.anchor then return nil end
  UI.attachments = UI.attachments or {}
  if not UI.attachments[name] then
    local f = CreateFrame("Frame", "ClassHUDAttach" .. name, UI.anchor)
    UI.attachments[name] = f
    f._height = 0

    local baseLvl = UI.anchor:GetFrameLevel() or 0
    if name == "TRACKED_ICONS" then
      f:SetFrameStrata("HIGH")
      f:SetFrameLevel(baseLvl + 40)
    elseif name == "TRACKED_BARS" then
      f:SetFrameStrata("MEDIUM")
      f:SetFrameLevel(baseLvl + 30)
    else
      f:SetFrameStrata("LOW")
      f:SetFrameLevel(baseLvl + 10)
    end
  end
  return UI.attachments[name]
end


local function ShouldShowCooldownNumbers()
  local db = ClassHUD.db
  if not db or not db.profile then
    return true
  end

  local settings = db.profile.cooldowns
  if settings and settings.showText ~= nil then
    return settings.showText
  end

  return true
end

ClassHUD.ShouldShowCooldownNumbers = ShouldShowCooldownNumbers

local function CollectAuraSpellIDs(entry, primaryID)
  return ClassHUD:GetAuraCandidatesForEntry(entry, primaryID)
end

local function FindAuraFromCandidates(candidates)
  return ClassHUD:FindAuraFromCandidates(candidates, TRACKED_UNITS)
end

-- ==================================================
-- Helpers
-- ==================================================

---Refreshes the in-memory snapshot cache used by spell frames.
function ClassHUD:RefreshSnapshotCache()
  self.cdmSpells = {}

  local snapshot = self:GetSnapshotForSpec(nil, nil, false)
  if not snapshot then return end

  for spellID, entry in pairs(snapshot) do
    if entry.categories then
      self.cdmSpells[spellID] = entry.categories
    end
  end
end

-- Erstatt hele UpdateGlow med denne:
local function SetFrameGlow(frame, shouldGlow)
  if shouldGlow and not frame.isGlowing then
    ActionButtonSpellAlertManager:ShowAlert(frame)
    frame.isGlowing = true
  elseif not shouldGlow and frame.isGlowing then
    ActionButtonSpellAlertManager:HideAlert(frame)
    frame.isGlowing = false
  end
end

ClassHUD.SetFrameGlow = SetFrameGlow

local function UpdateGlow(frame, aura, sid, data)
  -- 1) Samme semantikk som original: aura tilstede → glow
  local shouldGlow = (aura ~= nil)
  local allowExtraGlowLogic = true

  local isHarmfulSpell = C_Spell and C_Spell.IsSpellHarmful and C_Spell.IsSpellHarmful(sid)

  if isHarmfulSpell then
    allowExtraGlowLogic = false

    if aura and aura.expirationTime and aura.expirationTime > 0 then
      frame._harmfulGlowExpiration = aura.expirationTime
      frame._harmfulGlowWatching = true
      frame._harmfulGlowAuraSpellID = aura.spellId or sid
      frame._harmfulGlowNextAuraCheck = nil

      local remain = aura.expirationTime - GetTime()
      if remain and remain > 0 and remain <= HARMFUL_GLOW_THRESHOLD then
        shouldGlow = true
      else
        shouldGlow = false
      end
    else
      frame._harmfulGlowExpiration = nil
      frame._harmfulGlowWatching = false
      frame._harmfulGlowAuraSpellID = nil
      frame._harmfulGlowNextAuraCheck = nil
      shouldGlow = false
    end
  else
    frame._harmfulGlowExpiration = nil
    frame._harmfulGlowWatching = false
    frame._harmfulGlowAuraSpellID = nil
    frame._harmfulGlowNextAuraCheck = nil
  end

  -- 2) Manuelle buffLinks kan holde glow (som originalt "keepGlow")
  if allowExtraGlowLogic and not shouldGlow then
    local class, specID = ClassHUD:GetPlayerClassSpec()
    local tracking = ClassHUD.db.profile.tracking or {}
    local buffLinks = tracking.buffs and tracking.buffs.links or {}
    local links = (buffLinks[class] and buffLinks[class][specID]) or {}
    -- links: [buffID] = linkedSpellID
    for buffID, linkedSpellID in pairs(links) do
      if linkedSpellID == sid and ClassHUD:GetAuraForSpell(buffID) then
        shouldGlow = true
        break
      end
    end
  end

  -- 3) Auto-mapping fallback (som i originalens "keepGlow")
  if allowExtraGlowLogic and not shouldGlow and ClassHUD.trackedBuffToSpell then
    for buffID, mappedSpellID in pairs(ClassHUD.trackedBuffToSpell) do
      if mappedSpellID == sid and ClassHUD:GetAuraForSpell(buffID) then
        shouldGlow = true
        break
      end
    end
  end

  return shouldGlow
end


-- ==================================================
-- Frame factory
-- ==================================================
local function CreateSpellFrame(spellID)
  if ClassHUD.spellFrames[spellID] then
    return ClassHUD.spellFrames[spellID]
  end

  local frame = CreateFrame("Frame", "ClassHUDSpell" .. spellID, UI.anchor)
  frame:SetSize(40, 40)

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetAllPoints(frame)

  -- Cooldown
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame.icon)
  frame.cooldown:SetHideCountdownNumbers(true)
  frame.cooldown:SetDrawBling(false)
  frame.cooldown:SetDrawEdge(false)
  frame.cooldown.noCooldownCount = true

  frame.cooldown2 = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown2:SetAllPoints(frame.icon)
  frame.cooldown2:SetHideCountdownNumbers(true)
  frame.cooldown2:SetDrawBling(false)
  frame.cooldown2:SetDrawEdge(false)
  frame.cooldown2.noCooldownCount = true
  frame.cooldown2:SetFrameLevel(frame.cooldown:GetFrameLevel() + 1)
  frame.cooldown2:Hide()

  -- Overlay-frame (alltid over cooldown)
  frame.overlay = CreateFrame("Frame", nil, frame)
  frame.overlay:SetAllPoints(frame)
  frame.overlay:SetFrameLevel(frame.cooldown2:GetFrameLevel() + 1)

  -- Flytt tekstene til overlay
  frame.count = frame.overlay:CreateFontString(nil, "OVERLAY")
  frame.count:ClearAllPoints()
  frame.count:SetPoint("TOP", frame, "TOP", 0, -2)
  local fontPath, fontSize = ClassHUD:FetchFont(ClassHUD.db.profile.spellFontSize or 12)
  frame.count:SetFont(fontPath, fontSize, "OUTLINE")
  frame.count:Hide()

  frame.cooldownText = frame.overlay:CreateFontString(nil, "OVERLAY")
  frame.cooldownText:ClearAllPoints()
  frame.cooldownText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
  local cooldownFontPath, cooldownFontSize = ClassHUD:FetchFont(12)
  frame.cooldownText:SetFont(cooldownFontPath, cooldownFontSize, "OUTLINE")
  frame.cooldownText:SetJustifyH("CENTER")
  frame.cooldownText:SetJustifyV("MIDDLE")
  frame.cooldownText:Hide()


  frame._harmfulGlowExpiration = nil
  frame._harmfulGlowWatching = false
  frame._harmfulGlowThreshold = HARMFUL_GLOW_THRESHOLD
  frame._harmfulGlowAuraSpellID = nil
  frame._harmfulGlowNextAuraCheck = nil
  frame._harmfulGlowCheckUnits = HARMFUL_GLOW_UNITS
  frame.spellID = spellID
  frame.isGlowing = false
  frame._last = frame._last or {}
  frame._updateKind = "spell"

  ClassHUD.spellFrames[spellID] = frame

  frame:SetScript("OnUpdate", function(selfFrame)
    if not selfFrame._harmfulGlowWatching then
      return
    end

    local now = GetTime()
    local expiration = selfFrame._harmfulGlowExpiration
    local threshold = selfFrame._harmfulGlowThreshold or HARMFUL_GLOW_THRESHOLD
    local auraSpellID = selfFrame._harmfulGlowAuraSpellID or selfFrame.spellID
    local auraStillPresent = true

    local nextCheck = selfFrame._harmfulGlowNextAuraCheck
    if not nextCheck or now >= nextCheck then
      local units = selfFrame._harmfulGlowCheckUnits or HARMFUL_GLOW_UNITS
      local auraCheck = auraSpellID and ClassHUD:GetAuraForSpell(auraSpellID, units) or nil
      if not auraCheck then
        auraCheck = ClassHUD:FindAuraByName(selfFrame.spellID, units)
      end
      if not auraCheck then
        auraStillPresent = false
      end
      selfFrame._harmfulGlowNextAuraCheck = now + HARMFUL_GLOW_AURA_CHECK_INTERVAL
    end

    if not auraStillPresent then
      selfFrame._harmfulGlowWatching = false
      selfFrame._harmfulGlowExpiration = nil
      selfFrame._harmfulGlowAuraSpellID = nil
      selfFrame._harmfulGlowNextAuraCheck = nil
      SetFrameGlow(selfFrame, false)
    elseif expiration and expiration > 0 then
      local remain = expiration - now
      if remain > 0 then
        SetFrameGlow(selfFrame, remain <= threshold)
      else
        selfFrame._harmfulGlowWatching = false
        selfFrame._harmfulGlowExpiration = nil
        selfFrame._harmfulGlowAuraSpellID = nil
        selfFrame._harmfulGlowNextAuraCheck = nil
        SetFrameGlow(selfFrame, false)
      end
    else
      selfFrame._harmfulGlowWatching = false
      selfFrame._harmfulGlowExpiration = nil
      selfFrame._harmfulGlowAuraSpellID = nil
      selfFrame._harmfulGlowNextAuraCheck = nil
      SetFrameGlow(selfFrame, false)
    end
  end)

  return frame
end

-- ==================================================
-- Layout helpers (bruker dine UI.attachments)
-- ==================================================

-- ==========================================================
-- Tracked Buffs Bar (over TopBar, dynamisk)
-- ==========================================================

local function CreateBuffFrame(buffID)
  if trackedBuffPool[buffID] then
    return trackedBuffPool[buffID]
  end

  local parent = (UI.attachments and UI.attachments.TRACKED_ICONS) or UI.anchor
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(32, 32)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(true)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cooldown:SetAllPoints(true)
  f.cooldown:SetHideCountdownNumbers(true) -- vi viser vår egen tekst
  f.cooldown:SetDrawBling(false)
  f.cooldown:SetDrawEdge(false)
  f.cooldown.noCooldownCount = true

  -- overlay så tekst havner over cooldown swipe/edge
  f.overlay = CreateFrame("Frame", nil, f)
  f.overlay:SetAllPoints(true)
  f.overlay:SetFrameLevel(f.cooldown:GetFrameLevel() + 1)

  local fontPath, fontSize = ClassHUD:FetchFont(ClassHUD.db.profile.spellFontSize or 12)

  -- CHARGES / STACKS: øverst (samme som spells)
  f.count = f.overlay:CreateFontString(nil, "OVERLAY")
  f.count:ClearAllPoints()
  f.count:SetPoint("TOP", f, "TOP", 0, -2)
  f.count:SetFont(fontPath, fontSize, "OUTLINE")
  f.count:SetJustifyH("CENTER")
  f.count:SetText("")
  f.stacks = f.count

  -- COOLDOWN-TEKST: nederst (samme som spells)
  f.cooldownText = f.overlay:CreateFontString(nil, "OVERLAY")
  f.cooldownText:ClearAllPoints()
  f.cooldownText:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)
  local cooldownFontPath, cooldownFontSize = ClassHUD:FetchFont(12)
  f.cooldownText:SetFont(cooldownFontPath, cooldownFontSize, "OUTLINE")
  f.cooldownText:SetJustifyH("CENTER")
  f.cooldownText:SetJustifyV("MIDDLE")
  f.cooldownText:Hide()

  f.buffID = buffID
  f._updateKind = "trackedIcon"
  f._auraUnitList = TRACKED_UNITS
  f._layoutActive = false
  f._last = f._last or {}

  trackedBuffPool[buffID] = f
  return f
end
ClassHUD.CreateBuffFrame = CreateBuffFrame

local function LayoutTrackedIcons(iconFrames, opts)
  local container = EnsureAttachment("TRACKED_ICONS")
  if not container then return end

  local db       = ClassHUD.db.profile
  local settings = db.trackedBuffBar or {}
  local width    = db.width or 250
  local perRow   = math.max(settings.perRow or 8, 1)
  local spacingX = settings.spacingX or 4
  local spacingY = settings.spacingY or 4
  local align    = settings.align or "CENTER"

  container:SetWidth(width)

  local size = (width - (perRow - 1) * spacingX) / perRow
  if size < 1 then size = 1 end

  -- alltid minst én rad høyde
  local rowsUsed = math.max(1, math.ceil(#iconFrames / perRow))
  local totalHeight = rowsUsed * size + (rowsUsed - 1) * spacingY

  for index, frame in ipairs(iconFrames) do
    frame:SetParent(container)
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local row       = math.floor((index - 1) / perRow)
    local col       = (index - 1) % perRow

    local remaining = #iconFrames - row * perRow
    local rowCount  = math.max(1, math.min(perRow, remaining))
    local rowWidth  = rowCount * size + math.max(0, rowCount - 1) * spacingX

    local startX
    if align == "LEFT" then
      startX = 0
    elseif align == "RIGHT" then
      startX = width - rowWidth
    else
      startX = (width - rowWidth) / 2 -- sentrert
    end

    frame:SetPoint("TOPLEFT", container, "TOPLEFT",
      startX + col * (size + spacingX),
      -(row * (size + spacingY)))
  end

  container:SetHeight(totalHeight)
  container._height   = totalHeight
  container._afterGap = db.spacing or 2
  container:Show()
end

function ClassHUD:UpdateTrackedLayoutSnapshot()
  local snapshot = self._trackedLayoutSnapshot
  if not snapshot then
    snapshot = {}
    self._trackedLayoutSnapshot = snapshot
  end

  local iconsContainer = EnsureAttachment("TRACKED_ICONS")

  local iconsHeight    = iconsContainer and iconsContainer._height or 0
  local iconsGap       = iconsContainer and iconsContainer._afterGap or nil

  local changed        = snapshot.iconsHeight ~= iconsHeight
      or snapshot.iconsGap ~= iconsGap
      or snapshot.barsHeight ~= barsHeight
      or snapshot.barsGap ~= barsGap

  snapshot.iconsHeight = iconsHeight
  snapshot.iconsGap    = iconsGap
  snapshot.barsHeight  = barsHeight
  snapshot.barsGap     = barsGap

  if changed and self.Layout then
    self:Layout()
  end
end

function ClassHUD:ApplyTrackedBuffLayout()
  local registry = self._trackedBuffRegistry or {}
  local orderList = self._trackedBuffOrder or {}

  local iconFrames = {}
  local barFrames = {}

  for i = 1, #orderList do
    local buffID = orderList[i]
    local def = registry[buffID]
    if def then
      local iconFrame = def.iconFrame
      if iconFrame and iconFrame._layoutActive then
        iconFrames[#iconFrames + 1] = iconFrame
      end
      local barFrame = def.barFrame
      if barFrame and barFrame._layoutActive then
        barFrames[#barFrames + 1] = barFrame
      end
    end
  end

  local layout = self.db.profile.layout or {}
  local settings = layout.trackedBuffBar or {}
  local yOffset = settings.yOffset or 0
  local barTopPadding = (#barFrames > 0) and yOffset or 0
  local iconTopPadding = (#barFrames == 0 and #iconFrames > 0) and yOffset or 0

  LayoutTrackedIcons(iconFrames, { topPadding = iconTopPadding })
  self:UpdateTrackedLayoutSnapshot()
end

local function LayoutTopBar(frames)
  local container = EnsureAttachment("TOP")
  if not container then return end

  local profile  = ClassHUD.db.profile
  local layout   = profile.layout or {}
  local topBar   = layout.topBar or {}
  local width    = profile.width or 250
  local perRow   = math.max(topBar.perRow or 8, 1)
  local spacingX = topBar.spacingX or 4
  local spacingY = topBar.spacingY or 4
  local yOffset  = topBar.yOffset or 0
  local grow     = topBar.grow or "UP"

  container:SetWidth(width)

  if #frames == 0 then
    container._height = 0
    container:SetHeight(0)
    container._afterGap = nil
    container:Show()
    return
  end

  local size     = (width - (perRow - 1) * spacingX) / perRow
  local count    = #frames
  local rowsUsed = math.ceil(count / perRow)

  for index, frame in ipairs(frames) do
    frame:SetParent(container)
    frame:SetSize(size, size)
    frame:ClearAllPoints()

    local row = math.floor((index - 1) / perRow)
    local col = (index - 1) % perRow

    local remaining = count - row * perRow
    local rowCount = math.min(perRow, remaining)
    local rowWidth = rowCount * size + math.max(0, rowCount - 1) * spacingX
    local startX = (width - rowWidth) / 2

    local x = startX + col * (size + spacingX)
    local y = yOffset + row * (size + spacingY)

    if grow == "UP" then
      frame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x, y)
    else
      frame:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
    end

    frame:Show()
  end

  local totalHeight = yOffset + rowsUsed * size + math.max(0, rowsUsed - 1) * spacingY
  totalHeight = math.max(totalHeight, 0)

  container._height = totalHeight
  container:SetHeight(totalHeight)
  container._afterGap = profile.spacing or 0 -- 👈 vertical spacing option
  container:Show()
end

local function LayoutSideBar(frames, side)
  if not UI.attachments or not UI.attachments[side] then return end
  local layout  = ClassHUD.db.profile.layout or {}
  local sideCfg = layout.sideBars or {}
  local size    = sideCfg.size or 36
  local spacing = sideCfg.spacing or 4
  local offset  = sideCfg.offset or 6
  local yOffset = sideCfg.yOffset or 0
  for i, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:ClearAllPoints()
    local y = yOffset - (i - 1) * (size + spacing)
    if side == "LEFT" then
      frame:SetPoint("TOPRIGHT", UI.attachments.LEFT, "TOPLEFT", -offset, y)
    elseif side == "RIGHT" then
      frame:SetPoint("TOPLEFT", UI.attachments.RIGHT, "TOPRIGHT", offset, y)
    end
  end
end

local function LayoutBottomBar(frames)
  local container = EnsureAttachment("BOTTOM")
  if not container then return end

  local profile  = ClassHUD.db.profile
  local bottom   = profile.layout and profile.layout.bottomBar or {}
  local width    = profile.width or 250
  local perRow   = math.max(bottom.perRow or 8, 1)
  local spacingX = bottom.spacingX or 4
  local spacingY = bottom.spacingY or 4
  local yOffset  = bottom.yOffset or 0

  container:SetWidth(width)

  if #frames == 0 then
    container._height = 0
    container:SetHeight(0)
    container._afterGap = nil
    container:Show()
    return
  end

  local size       = (width - (perRow - 1) * spacingX) / perRow
  local count      = #frames
  local rowsUsed   = math.ceil(count / perRow)
  local topPadding = spacingY + yOffset

  for index, frame in ipairs(frames) do
    frame:SetSize(size, size)
    frame:SetParent(container)
    frame:ClearAllPoints()

    local row       = math.floor((index - 1) / perRow)
    local col       = (index - 1) % perRow
    local remaining = count - row * perRow
    local rowCount  = math.min(perRow, remaining)
    local rowWidth  = rowCount * size + math.max(0, rowCount - 1) * spacingX
    local startX    = (width - rowWidth) / 2

    frame:SetPoint("TOPLEFT", container, "TOPLEFT",
      startX + col * (size + spacingX),
      -(topPadding + row * (size + spacingY)))
    frame:Show()
  end

  local totalHeight = topPadding + rowsUsed * size + math.max(0, rowsUsed - 1) * spacingY
  totalHeight = math.max(totalHeight, 0)
  container._height = totalHeight
  container:SetHeight(totalHeight)
  container._afterGap = ClassHUD.db.profile.spacing or 0 -- 👈 vertical spacing option
  container:Show()
end

local function PopulateBuffIconFrame(frame, buffID, aura, entry)
  frame:SetParent(EnsureAttachment("TRACKED_ICONS") or UI.anchor)

  local cache = frame._last
  if not cache then
    cache = {}
    frame._last = cache
  end

  local iconID = entry and entry.iconID
  if not iconID then
    local info = C_Spell.GetSpellInfo(buffID)
    iconID = info and info.iconID
  end
  frame.icon:SetTexture(iconID or C_Spell.GetSpellTexture(buffID) or 134400)

  if aura and aura.expirationTime and aura.duration and aura.duration > 0 then
    frame.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration, aura.modRate or 1)
    frame.cooldown:Show()

    cache.cooldownStart = aura.expirationTime - aura.duration
    cache.cooldownDuration = aura.duration
    cache.cooldownModRate = aura.modRate or 1
    cache.cooldownEnd = aura.expirationTime
    cache.hasCooldown = true
    cache.hasChargeCooldown = false

    -- sørg for at overlay er over cooldown
    if frame.overlay and frame.cooldown then
      local need = frame.cooldown:GetFrameLevel() + 1
      if frame.overlay:GetFrameLevel() <= need then
        frame.overlay:SetFrameLevel(need)
      end
    end
  else
    CooldownFrame_Clear(frame.cooldown)
    frame.cooldown:Hide()

    cache.cooldownStart = nil
    cache.cooldownDuration = nil
    cache.cooldownModRate = nil
    cache.cooldownEnd = nil
    cache.hasCooldown = false
    cache.hasChargeCooldown = false
  end

  local stacks = aura and (aura.applications or aura.stackCount or aura.charges)
  if stacks and stacks > 1 then
    frame.count:SetText(stacks)
    frame.count:Show()
  else
    frame.count:SetText("")
    frame.count:Hide()
  end

  local showNumbers = ShouldShowCooldownNumbers()
  local remaining = nil
  if showNumbers and cache.hasCooldown and cache.cooldownEnd then
    remaining = cache.cooldownEnd - GetTime()
    if remaining and remaining <= 0 then
      remaining = nil
    end
  end
  ClassHUD:ApplyCooldownText(frame, showNumbers, remaining)

  frame:Show()
end

ClassHUD.PopulateBuffIconFrame = PopulateBuffIconFrame


function ClassHUD:GetManualCountForSpell(spellID)
  local implosionSpellID = ClassHUD.IMPLOSION_SPELL_ID or 196277
  if spellID == implosionSpellID then
    if not self:IsWildImpTrackingEnabled() then
      return 0
    end
    if self:GetWildImpTrackingMode() ~= "implosion" then
      return nil
    end
    return self._wildImpCount or 0
  end
  return nil
end

local function UpdateTrackedIconFrame(frame)
  if not frame then return false end

  local cache = frame._last
  if not cache then
    cache = {}
    frame._last = cache
  end

  if frame._manualSummon then
    return frame._layoutActive or false
  end

  local buffID = frame.buffID
  if not buffID then
    frame:Hide()
    frame._layoutActive = false
    return false
  end

  local entry = frame._trackedEntry
  local candidates = frame._trackedAuraCandidates
  if not candidates then
    candidates = CollectAuraSpellIDs(entry, buffID)
    candidates = CopyCandidates(candidates) or { buffID }
    frame._trackedAuraCandidates = candidates
    RegisterFrameAuraWatchers(frame, candidates, frame._auraUnitList or TRACKED_UNITS)
  end

  local units = frame._auraUnitList or TRACKED_UNITS
  local aura = nil
  if candidates then
    aura = select(1, FindAuraFromCandidates(candidates, units))
  end

  if aura then
    local iconID = entry and entry.iconID
    if not iconID then
      local info = C_Spell.GetSpellInfo(buffID)
      iconID = info and info.iconID
    end
    iconID = iconID or C_Spell.GetSpellTexture(buffID) or 134400
    if cache.iconID ~= iconID then
      frame.icon:SetTexture(iconID)
      cache.iconID = iconID
    end

    if aura.expirationTime and aura.duration and aura.duration > 0 then
      frame.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration, aura.modRate or 1)
      frame.cooldown:Show()
      if frame.overlay and frame.cooldown then
        local need = frame.cooldown:GetFrameLevel() + 1
        if frame.overlay:GetFrameLevel() <= need then
          frame.overlay:SetFrameLevel(need)
        end
      end

      cache.cooldownStart = aura.expirationTime - aura.duration
      cache.cooldownDuration = aura.duration
      cache.cooldownModRate = aura.modRate or 1
      cache.cooldownEnd = aura.expirationTime
      cache.hasCooldown = true
      cache.hasChargeCooldown = false
    else
      CooldownFrame_Clear(frame.cooldown)
      frame.cooldown:Hide()

      cache.cooldownStart = nil
      cache.cooldownDuration = nil
      cache.cooldownModRate = nil
      cache.cooldownEnd = nil
      cache.hasCooldown = false
      cache.hasChargeCooldown = false
    end

    local stacks = aura.applications or aura.stackCount or aura.charges
    if stacks and stacks > 1 then
      frame.count:SetText(stacks)
      frame.count:Show()
    else
      frame.count:SetText("")
      frame.count:Hide()
    end

    local showNumbers = ShouldShowCooldownNumbers()
    local remaining = nil
    if showNumbers and cache.hasCooldown and cache.cooldownEnd then
      remaining = cache.cooldownEnd - GetTime()
      if remaining and remaining <= 0 then
        remaining = nil
      end
    end
    ClassHUD:ApplyCooldownText(frame, showNumbers, remaining)

    frame:Show()
    frame._layoutActive = true
    return true
  end

  CooldownFrame_Clear(frame.cooldown)
  frame.cooldown:Hide()
  frame.count:SetText("")
  frame.count:Hide()
  cache.cooldownStart = nil
  cache.cooldownDuration = nil
  cache.cooldownModRate = nil
  cache.cooldownEnd = nil
  cache.hasCooldown = false
  cache.hasChargeCooldown = false
  ClassHUD:ApplyCooldownText(frame, ShouldShowCooldownNumbers(), nil)
  frame:Hide()
  frame._layoutActive = false
  return false
end

function ClassHUD:BuildTrackedBuffFrames()
  local trackedIDs = self._trackedAuraIDs
  if not trackedIDs then
    trackedIDs = {}
    self._trackedAuraIDs = trackedIDs
  else
    wipe(trackedIDs)
  end

  local registry = self._trackedBuffRegistry
  if not registry then
    registry = {}
    self._trackedBuffRegistry = registry
  else
    wipe(registry)
  end

  local orderList = self._trackedBuffOrder
  if not orderList then
    orderList = {}
    self._trackedBuffOrder = orderList
  else
    wipe(orderList)
  end

  -- Skjul gamle frames
  if self.trackedBuffFrames then
    for _, frame in ipairs(self.trackedBuffFrames) do
      self:ClearFrameAuraWatchers(frame)
      frame:Hide()
      frame._layoutActive = false
      if frame.cooldown then
        CooldownFrame_Clear(frame.cooldown)
        frame.cooldown:Hide()
      end
    end
  end

  wipe(self.trackedBuffFrames)

  -- Sørg for containere
  EnsureAttachment("TRACKED_ICONS")

  local function resetLayouts()
    LayoutTrackedIcons({}, nil)
    self:UpdateTrackedLayoutSnapshot()
  end

  if not (self.db.profile.layout and self.db.profile.layout.show and self.db.profile.layout.show.buffs) then
    resetLayouts()
    return
  end

  local class, specID = self:GetPlayerClassSpec()
  if not specID or specID == 0 then
    resetLayouts()
    return
  end

  local tracked = self:GetProfileTable(false, "tracking", "buffs", "tracked", class, specID)
  if not tracked then
    resetLayouts()
    return
  end

  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  local orderArray = self:GetProfileTable(true, "layout", "trackedBuffBar", "buffs", class, specID)
  local orderLookup = {}

  local function IsTracked(buffID)
    return tracked[buffID] or tracked[tostring(buffID)]
  end

  if type(orderArray) == "table" then
    for idx = #orderArray, 1, -1 do
      local value = orderArray[idx]
      local buffID = tonumber(value) or value
      if buffID and IsTracked(buffID) then
        orderArray[idx] = buffID
        orderLookup[buffID] = idx
      else
        table.remove(orderArray, idx)
      end
    end
  else
    orderArray = {}
    orderLookup = {}
  end

  local ordered = {}

  for key, _ in pairs(tracked) do
    local buffID = tonumber(key) or key
    local config = self:GetTrackedEntryConfig(class, specID, buffID, false)
    if config then
      local entry = snapshot and snapshot[buffID]
      local order = math.huge
      if entry and entry.categories then
        if entry.categories.bar and entry.categories.bar.order then
          order = math.min(order, entry.categories.bar.order)
        end
        if entry.categories.buff and entry.categories.buff.order then
          order = math.min(order, entry.categories.buff.order)
        end
      end
      local name = entry and entry.name or C_Spell.GetSpellName(buffID) or ("Spell " .. buffID)
      local manualIndex = orderLookup[buffID]
      if not manualIndex then
        orderArray[#orderArray + 1] = buffID
        manualIndex = #orderArray
        orderLookup[buffID] = manualIndex
      end
      table.insert(ordered, {
        buffID = buffID,
        config = config,
        entry  = entry,
        order  = order,
        name   = name,
        index  = manualIndex,
      })
    end
  end

  table.sort(ordered, function(a, b)
    local ia = a.index or math.huge
    local ib = b.index or math.huge
    if ia == ib then
      if a.order == b.order then
        return a.name < b.name
      end
      return a.order < b.order
    end
    return ia < ib
  end)

  local iconFrames = {}

  for _, info in ipairs(ordered) do
    local buffID         = info.buffID
    local entry          = info.entry
    local auraCandidates = CollectAuraSpellIDs(entry, buffID)
    local aura           = FindAuraFromCandidates(auraCandidates)

    trackedIDs[buffID]   = true
    if auraCandidates then
      for _, candidateID in ipairs(auraCandidates) do
        if type(candidateID) == "number" then
          trackedIDs[candidateID] = true
        end
      end
    end

    local iconFrame = CreateBuffFrame(buffID)
    PopulateBuffIconFrame(iconFrame, buffID, aura, entry)
    iconFrame._trackedEntry = entry
    iconFrame._auraUnitList = TRACKED_UNITS
    iconFrame._last = iconFrame._last or {}
    iconFrame._updateKind = "trackedIcon"
    local iconCandidates = CopyCandidates(auraCandidates) or { buffID }
    iconFrame._trackedAuraCandidates = iconCandidates
    RegisterFrameAuraWatchers(iconFrame, iconCandidates, TRACKED_UNITS)
    iconFrame._layoutActive = aura and true or false
    if iconFrame._layoutActive then
      iconFrame:Show()
      table.insert(iconFrames, iconFrame)
    else
      iconFrame:Hide()
    end

    registry[buffID] = registry[buffID] or {}
    registry[buffID].iconFrame = iconFrame
    registry[buffID].entry = entry
    registry[buffID].iconCandidates = iconCandidates
    orderList[#orderList + 1] = buffID
  end

  self.trackedBuffFrames = iconFrames

  self:RefreshTemporaryBuffs(true)
  self:ApplyTrackedBuffLayout()
end

-- ==================================================
-- UpdateSpellFrame
-- ==================================================
local function UpdateSpellFrame(frame)
  local sid = frame.spellID
  if not sid then return end

  local cache = frame._last
  if not cache then
    cache = {}
    frame._last = cache
  end

  local data              = ClassHUD.cdmSpells and ClassHUD.cdmSpells[sid]
  local entry             = ClassHUD:GetSnapshotEntry(sid)
  local auraCandidates    = ClassHUD:GetAuraCandidatesForEntry(entry, sid)
  frame._auraCandidates   = auraCandidates

  local harmfulTracksAura = false
  if ClassHUD.IsHarmfulAuraSpell then
    harmfulTracksAura = select(1, ClassHUD:IsHarmfulAuraSpell(sid, entry))
  end

  local auraUnits = harmfulTracksAura and SPELL_AURA_UNITS_HARMFUL or SPELL_AURA_UNITS_DEFAULT
  frame._auraUnitList = auraUnits
  RegisterFrameAuraWatchers(frame, auraCandidates, auraUnits)

  local iconID = entry and entry.iconID
  if not iconID then
    local info = C_Spell.GetSpellInfo(sid)
    iconID = info and info.iconID
  end
  iconID = iconID or 134400
  if cache.iconID ~= iconID then
    frame.icon:SetTexture(iconID)
    cache.iconID = iconID
  end

  local aura, auraSpellID, auraUnit = nil, nil, nil
  if auraCandidates then
    aura, auraSpellID, auraUnit = ClassHUD:FindAuraFromCandidates(auraCandidates, auraUnits)
  end
  if not aura then
    aura, auraUnit = ClassHUD:GetAuraForSpell(sid, auraUnits)
    auraSpellID = sid
  end
  if not aura and harmfulTracksAura then
    aura = ClassHUD:FindAuraByName(sid, SPELL_AURA_UNITS_HARMFUL)
    auraSpellID = sid
  end
  frame._lastAuraUnit = auraUnit
  frame._lastAuraSpellID = auraSpellID

  local chargesInfo = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(sid)
  local chargesShown = false
  local chargesValue, maxCharges
  local countText, countShown = nil, false
  local cdStart, cdDuration, cdModRate = nil, nil, nil
  local cooldownEnd = nil
  local cooldownSource = nil
  local shouldDesaturate = false
  local chargeStart, chargeDuration, chargeModRate = nil, nil, nil

  if chargesInfo and chargesInfo.maxCharges and chargesInfo.maxCharges > 1 then
    chargesValue = chargesInfo.currentCharges or 0
    maxCharges = chargesInfo.maxCharges
    chargesShown = true
    countText = tostring(chargesValue)
    countShown = true

    if chargesValue < maxCharges and chargesInfo.cooldownDuration and chargesInfo.cooldownDuration > 0 then
      chargeStart = chargesInfo.cooldownStartTime
      chargeDuration = chargesInfo.cooldownDuration
      chargeModRate = chargesInfo.cooldownModRate or 1

      if chargesValue <= 0 then
        cdStart = chargeStart
        cdDuration = chargeDuration
        cdModRate = chargeModRate
        cooldownEnd = chargeStart + chargeDuration
        cooldownSource = "charges"
      end
    end
  end

  local baseCooldown = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(sid)
  if baseCooldown and baseCooldown.startTime and baseCooldown.duration and baseCooldown.duration > 1.5 then
    local baseEnd = baseCooldown.startTime + baseCooldown.duration
    if not cooldownEnd or baseEnd > cooldownEnd then
      cdStart = baseCooldown.startTime
      cdDuration = baseCooldown.duration
      cdModRate = baseCooldown.modRate or 1
      cooldownEnd = baseEnd
      cooldownSource = "spell"
    end
  end

  local gcd = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(61304)
  if gcd and gcd.startTime and gcd.duration and gcd.duration > 0 then
    local gcdEnd = gcd.startTime + gcd.duration
    if not cooldownEnd or gcdEnd > cooldownEnd then
      cdStart = gcd.startTime
      cdDuration = gcd.duration
      cdModRate = gcd.modRate or 1
      cooldownEnd = gcdEnd
      cooldownSource = "gcd"
    end
  end

  local swipeR, swipeG, swipeB, swipeA = 0, 0, 0, 0.25
  if aura then
    local stacks = aura.applications or aura.stackCount or aura.charges or 0
    if aura.duration and aura.duration > 0 and aura.expirationTime then
      swipeR, swipeG, swipeB, swipeA = 1, 0.85, 0.1, 0.9
      cdStart = aura.expirationTime - aura.duration
      cdDuration = aura.duration
      cdModRate = aura.modRate or cdModRate or 1
      cooldownEnd = aura.expirationTime
      cooldownSource = "aura"
    end
    if stacks > 1 and not chargesShown then
      countText = tostring(stacks)
      countShown = true
    elseif not chargesShown then
      countText = nil
      countShown = false
    end
  end

  if not chargesShown then
    local manualCount = ClassHUD.GetManualCountForSpell and ClassHUD:GetManualCountForSpell(sid)
    if manualCount ~= nil then
      if manualCount > 0 then
        countText = tostring(manualCount)
        countShown = true
      else
        countText = nil
        countShown = false
      end
    end
  end

  if cooldownSource == "gcd" then
    swipeR, swipeG, swipeB, swipeA = 0, 0, 0, 0.15
  end

  local hasCooldown = cdStart and cdDuration and cdDuration > 0
  local modRate = cdModRate or 1
  if hasCooldown then
    local changed = not cache.hasCooldown
        or cache.cooldownStart ~= cdStart
        or cache.cooldownDuration ~= cdDuration
        or cache.cooldownModRate ~= modRate
    if changed then
      frame.cooldown:SetCooldown(cdStart, cdDuration, modRate)
      frame.cooldown:Show()
    end
    cache.cooldownStart = cdStart
    cache.cooldownDuration = cdDuration
    cache.cooldownModRate = modRate
    cache.hasCooldown = true
  else
    if cache.hasCooldown then
      CooldownFrame_Clear(frame.cooldown)
      frame.cooldown:Hide()
    end
    cache.cooldownStart = nil
    cache.cooldownDuration = nil
    cache.cooldownModRate = nil
    cache.hasCooldown = false
  end

  local hasChargeCooldown = chargeStart and chargeDuration and chargeDuration > 0
      and maxCharges and maxCharges > 0
      and chargesValue ~= nil and chargesValue < maxCharges
  local chargeRate = chargeModRate or 1
  if hasChargeCooldown then
    local changed = not cache.hasChargeCooldown
        or cache.chargeCooldownStart ~= chargeStart
        or cache.chargeCooldownDuration ~= chargeDuration
        or cache.chargeCooldownModRate ~= chargeRate
    if changed then
      frame.cooldown2:SetCooldown(chargeStart, chargeDuration, chargeRate)
      frame.cooldown2:Show()
    end
    cache.chargeCooldownStart = chargeStart
    cache.chargeCooldownDuration = chargeDuration
    cache.chargeCooldownModRate = chargeRate
    cache.hasChargeCooldown = true
  else
    if cache.hasChargeCooldown then
      CooldownFrame_Clear(frame.cooldown2)
      frame.cooldown2:Hide()
    end
    cache.chargeCooldownStart = nil
    cache.chargeCooldownDuration = nil
    cache.chargeCooldownModRate = nil
    cache.hasChargeCooldown = false
  end

  if cache.swipeR ~= swipeR or cache.swipeG ~= swipeG or cache.swipeB ~= swipeB or cache.swipeA ~= swipeA then
    frame.cooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)
    cache.swipeR, cache.swipeG, cache.swipeB, cache.swipeA = swipeR, swipeG, swipeB, swipeA
  end

  if countShown then
    if cache.countText ~= countText then
      frame.count:SetText(countText or "")
      cache.countText = countText
    end
    if not cache.countShown then
      frame.count:Show()
      cache.countShown = true
    end
  else
    if cache.countShown then
      frame.count:Hide()
      cache.countShown = false
    end
    if cache.countText then
      frame.count:SetText("")
      cache.countText = nil
    end
  end

  if chargesShown then
    cache.charges = chargesValue
    cache.maxCharges = maxCharges
  else
    cache.charges = nil
    cache.maxCharges = nil
  end

  local usable, noMana = C_Spell and C_Spell.IsSpellUsable and C_Spell.IsSpellUsable(sid)
  local resourceLimited = false
  if usable == false and noMana then
    resourceLimited = true
  end

  local lacksResources = ClassHUD:LacksResources(sid)
  cache.lacksResources = lacksResources
  if lacksResources then
    resourceLimited = true
  end

  local cooldownEndTime = cooldownEnd or (cdStart and cdDuration and (cdStart + cdDuration)) or nil
  if hasCooldown then
    cache.cooldownEnd = cooldownEndTime
  else
    cache.cooldownEnd = nil
  end

  if hasChargeCooldown and chargeStart and chargeDuration then
    cache.chargeCooldownEnd = chargeStart + chargeDuration
  else
    cache.chargeCooldownEnd = nil
  end

  local now = GetTime()
  local chargesDepleted = chargesShown and (chargesValue or 0) <= 0
  local onCooldown = false
  if hasCooldown and cooldownEndTime then
    onCooldown = (cooldownEndTime - now) > 0
  end

  local isGCDCooldown = cooldownSource == "gcd"

  local showNumbers = ShouldShowCooldownNumbers()
  local cooldownTextRemaining = nil
  if showNumbers and hasCooldown and cooldownEndTime then
    local remaining = cooldownEndTime - now
    if remaining > 0 then
      cooldownTextRemaining = remaining
    end
  end

  local totemOverride = false
  if ClassHUD.IsTotemDurationTextEnabled and ClassHUD:IsTotemDurationTextEnabled() then
    local totemState = frame._activeTotemState
    if not totemState then
      totemState = ClassHUD:GetActiveTotemStateForSpell(sid)
      frame._activeTotemState = totemState
    end

    if ClassHUD:HasTotemDuration(totemState) then
      totemOverride = true
      if ClassHUD.MarkTotemFrameForUpdate then
        ClassHUD:MarkTotemFrameForUpdate(frame)
      end
    else
      if ClassHUD.UnmarkTotemFrame then
        ClassHUD:UnmarkTotemFrame(frame)
      end
    end
  else
    if ClassHUD.UnmarkTotemFrame then
      ClassHUD:UnmarkTotemFrame(frame)
    end
  end

  if not totemOverride then
    ClassHUD:ApplyCooldownText(frame, showNumbers, cooldownTextRemaining)
  end

  shouldDesaturate = false
  if onCooldown and not isGCDCooldown and (not chargesShown or chargesDepleted) then
    shouldDesaturate = true
  end
  if resourceLimited then
    shouldDesaturate = true
  end

  local tracksAura = harmfulTracksAura or (auraCandidates and #auraCandidates > 0)
  if tracksAura then
    ClassHUD:AddFrameToConcern(frame, "aura")
  else
    ClassHUD:RemoveFrameFromConcern(frame, "aura")
  end

  local vertexR, vertexG, vertexB = 1, 1, 1
  if aura and aura.duration and aura.duration > 0 and aura.expirationTime then
    vertexR, vertexG, vertexB = 1, 1, 0.3
  end

  local finalDesaturate = shouldDesaturate

  local inRange = nil
  if UnitExists("target") and not UnitIsDead("target") then
    inRange = C_Spell and C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(sid, "target")
    if inRange == false then
      vertexR, vertexG, vertexB = 1, 0, 0
    end
  end
  cache.inRange = inRange

  finalDesaturate = not not finalDesaturate
  if cache.desaturated ~= finalDesaturate then
    frame.icon:SetDesaturated(finalDesaturate)
    cache.desaturated = finalDesaturate
  end

  if cache.vertexR ~= vertexR or cache.vertexG ~= vertexG or cache.vertexB ~= vertexB then
    frame.icon:SetVertexColor(vertexR, vertexG, vertexB)
    cache.vertexR, cache.vertexG, cache.vertexB = vertexR, vertexG, vertexB
  end

  local shouldGlow = UpdateGlow(frame, aura, sid, data) or false
  if frame._totemGlowActive then
    shouldGlow = true
  end
  if cache.glow ~= shouldGlow then
    SetFrameGlow(frame, shouldGlow)
    cache.glow = shouldGlow
  else
    cache.glow = shouldGlow
  end
end

-- ==================================================
-- Public API (kalles fra ClassHUD.lua events)
-- ==================================================

function ClassHUD:UpdateCooldown(spellID)
  if not self.spellFrames then return end

  if spellID then
    local frame = self.spellFrames[spellID]
    if frame then
      UpdateSpellFrame(frame)
      return
    end
  end

  for _, frame in ipairs(activeFrames) do
    UpdateSpellFrame(frame)
  end
end

function ClassHUD:HandleUnitAuraUpdate(unit, updateInfo)
  local unitWatchers = self._auraWatchersByUnit and self._auraWatchersByUnit[unit]
  if not unitWatchers or not next(unitWatchers) then
    return
  end

  local spellWatchers = self._auraWatchersBySpellID
  local any = false

  local function markAllForUnit()
    for frame in pairs(unitWatchers) do
      MarkFrameForAuraUpdate(frame)
    end
    any = true
  end

  local function queueFromList(list)
    if type(list) ~= "table" then return end
    local iterated = false
    for _, payload in ipairs(list) do
      iterated = true
      local spellID = ExtractAuraSpellID(payload)
      if spellID then
        local frames = spellWatchers and spellWatchers[spellID]
        if frames then
          for frame in pairs(frames) do
            if unitWatchers[frame] then
              MarkFrameForAuraUpdate(frame)
              any = true
            end
          end
        end
      end
    end
    if iterated then
      return
    end
    for _, payload in pairs(list) do
      local spellID = ExtractAuraSpellID(payload)
      if spellID then
        local frames = spellWatchers and spellWatchers[spellID]
        if frames then
          for frame in pairs(frames) do
            if unitWatchers[frame] then
              MarkFrameForAuraUpdate(frame)
              any = true
            end
          end
        end
      end
    end
  end

  local function handleInstanceList(list)
    if type(list) ~= "table" then return end
    if next(list) ~= nil then
      markAllForUnit()
    end
  end

  if type(updateInfo) == "table" and not updateInfo.isFullUpdate then
    queueFromList(updateInfo.addedAuras)
    queueFromList(updateInfo.updatedAuras)
    queueFromList(updateInfo.removedAuras)
    queueFromList(updateInfo.addedAuraSpellIDs)
    queueFromList(updateInfo.updatedAuraSpellIDs)
    queueFromList(updateInfo.removedAuraSpellIDs)
    queueFromList(updateInfo.removedSpellIDs)
    handleInstanceList(updateInfo.removedAuraInstanceIDs)
    handleInstanceList(updateInfo.updatedAuraInstanceIDs)
    if not any then
      markAllForUnit()
    end
  else
    markAllForUnit()
  end
end

function ClassHUD:FlushAuraChanges()
  local handle = self._auraFlushTimer
  self._auraFlushTimer = nil
  if handle then
    self:CancelTimer(handle)
  end

  local dirty = self._pendingAuraFrames
  if not dirty or not next(dirty) then
    return
  end

  local layoutDirty = false
  for frame in pairs(dirty) do
    dirty[frame] = nil
    if frame and frame._updateKind == "spell" then
      UpdateSpellFrame(frame)
    elseif frame and frame._updateKind == "trackedIcon" then
      local previous = frame._layoutActive
      local active = UpdateTrackedIconFrame(frame)
      if active ~= previous then
        layoutDirty = true
      end
    end
  end

  if layoutDirty then
    self:ApplyTrackedBuffLayout()
  end
end

local function UpdateFramesFromBucket(bucket, seen)
  if not bucket then return end
  wipe(concernScratch)
  for frame in pairs(bucket) do
    concernScratch[#concernScratch + 1] = frame
  end
  for i = 1, #concernScratch do
    local frame = concernScratch[i]
    concernScratch[i] = nil
    if frame and (not seen or not seen[frame]) then
      UpdateSpellFrame(frame)
      if seen then
        seen[frame] = true
      end
    end
  end
end

function ClassHUD:UpdateAllSpellFrames(concern)
  self:RefreshSnapshotCache()

  if concern then
    local buckets = EnsureConcernBuckets()
    if type(concern) == "string" then
      UpdateFramesFromBucket(buckets[concern])
      return
    elseif type(concern) == "table" then
      local seen = {}
      for _, key in ipairs(concern) do
        UpdateFramesFromBucket(buckets[key], seen)
      end
      return
    end
  end

  for _, f in ipairs(activeFrames) do
    UpdateSpellFrame(f)
  end
end

function ClassHUD:RebuildTrackedBuffFrames()
  if self.BuildTrackedBuffFrames then
    self:BuildTrackedBuffFrames()
  end

  -- Før auto-map, håndter manuelle buffLinks fra DB
  local class, specID = self:GetPlayerClassSpec()
  if not specID or specID == 0 then
    return
  end

  local tracking = ClassHUD.db.profile.tracking or {}
  local linkRoot = tracking.buffs and tracking.buffs.links or {}
  local links = (linkRoot[class] and linkRoot[class][specID]) or {}

  for buffID, spellID in pairs(links) do
    local aura = C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(buffID)
    if not aura and UnitExists("pet") and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
      aura = C_UnitAuras.GetAuraDataBySpellID("pet", buffID)
    end
  end
end

function ClassHUD:UpdateAllFrames()
  if self.UpdateAllSpellFrames then
    self:UpdateAllSpellFrames()
  end

  if self.RebuildTrackedBuffFrames then
    self:RebuildTrackedBuffFrames()
  end
end

function ClassHUD:BuildFramesForSpec()
  for _, f in ipairs(activeFrames) do
    self:ClearFrameConcerns(f)
    self:ClearFrameAuraWatchers(f)
    f:Hide()
  end
  wipe(activeFrames)

  if self.ResetTotemTracking then
    self:ResetTotemTracking()
  end

  if self.spellFrames then
    for _, frame in pairs(self.spellFrames) do
      frame.snapshotEntry = nil
    end
  end

  self.trackedBuffToSpell = {}

  local class, specID = self:GetPlayerClassSpec()
  if not specID or specID == 0 then
    return
  end

  local snapshot = self:GetSnapshotForSpec(class, specID, false)
  if not snapshot or next(snapshot) == nil then
    self.cdmSpells = {}
    return
  end

  self:RefreshSnapshotCache()

  local built = {}

  local function acquire(spellID)
    local frame = CreateSpellFrame(spellID)
    frame:Show()
    frame.snapshotEntry = snapshot[spellID]
    if not built[spellID] then
      table.insert(activeFrames, frame)
      built[spellID] = true
    end
    self:RefreshFrameConcerns(frame)
    return frame
  end

  local class, specID = self:GetPlayerClassSpec()
  self.db.profile.layout = self.db.profile.layout or {}
  local layout = self.db.profile.layout
  layout.topBar = layout.topBar or {}
  layout.bottomBar = layout.bottomBar or {}
  layout.sideBars = layout.sideBars or {}
  layout.sideBars.spells = layout.sideBars.spells or {}
  layout.hiddenSpells = layout.hiddenSpells or {}

  local topList = self:GetProfileTable(true, "layout", "topBar", "spells", class, specID)
  local bottomList = self:GetProfileTable(true, "layout", "bottomBar", "spells", class, specID)
  local sideSpec = self:GetProfileTable(true, "layout", "sideBars", "spells", class, specID)
  sideSpec.left = sideSpec.left or {}
  sideSpec.right = sideSpec.right or {}
  local hiddenList = self:GetProfileTable(true, "layout", "hiddenSpells", class, specID)

  local topFrames, bottomFrames = {}, {}
  local sideFrames = { LEFT = {}, RIGHT = {} }
  local hiddenSet = {}

  if type(hiddenList) == "table" then
    for i = #hiddenList, 1, -1 do
      local spellID = tonumber(hiddenList[i]) or hiddenList[i]
      if spellID then
        hiddenSet[spellID] = true
        built[spellID] = true
      else
        table.remove(hiddenList, i)
      end
    end
  end

  local function placeFromArray(array, target, placement)
    if type(array) ~= "table" then return end
    for index = 1, #array do
      local spellID = tonumber(array[index]) or array[index]
      if spellID and not built[spellID] and not hiddenSet[spellID] then
        local frame = acquire(spellID)
        frame._customOrder = index
        frame._customPlacement = placement
        table.insert(target, frame)
        built[spellID] = true
      end
    end
  end

  placeFromArray(topList, topFrames, "TOP")
  placeFromArray(bottomList, bottomFrames, "BOTTOM")
  placeFromArray(sideSpec.left, sideFrames.LEFT, "LEFT")
  placeFromArray(sideSpec.right, sideFrames.RIGHT, "RIGHT")

  local function collectSnapshot(category)
    local list = {}
    self:ForEachSnapshotEntry(category, function(spellID, entry, categoryData)
      table.insert(list, {
        spellID = spellID,
        entry = entry,
        data = categoryData,
        order = categoryData.order or math.huge,
      })
    end)
    table.sort(list, function(a, b)
      if a.order == b.order then
        return (a.entry.name or "") < (b.entry.name or "")
      end
      return a.order < b.order
    end)
    return list
  end

  for _, item in ipairs(collectSnapshot("essential")) do
    local spellID = item.spellID
    if not built[spellID] and not hiddenSet[spellID] then
      local frame = acquire(spellID)
      frame._customOrder = nil
      table.insert(topFrames, frame)
      built[spellID] = true
    end
  end

  for _, item in ipairs(collectSnapshot("utility")) do
    local spellID = item.spellID
    if spellID and not built[spellID] then
      hiddenSet[spellID] = true
      built[spellID] = true
    end
  end

  for _, item in ipairs(collectSnapshot("bar")) do
    local spellID = item.spellID
    if not built[spellID] and not hiddenSet[spellID] then
      local frame = acquire(spellID)
      frame._customOrder = nil
      table.insert(bottomFrames, frame)
      built[spellID] = true
    end
  end

  local function sortFrames(list)
    table.sort(list, function(a, b)
      local ao = a._customOrder or (a.snapshotEntry and a.snapshotEntry.categories and
        ((a.snapshotEntry.categories.essential and a.snapshotEntry.categories.essential.order)
          or (a.snapshotEntry.categories.buff and a.snapshotEntry.categories.buff.order)
          or (a.snapshotEntry.categories.bar and a.snapshotEntry.categories.bar.order)
          or (a.snapshotEntry.categories.utility and a.snapshotEntry.categories.utility.order))) or math.huge

      local bo = b._customOrder or (b.snapshotEntry and b.snapshotEntry.categories and
        ((b.snapshotEntry.categories.essential and b.snapshotEntry.categories.essential.order)
          or (b.snapshotEntry.categories.buff and b.snapshotEntry.categories.buff.order)
          or (b.snapshotEntry.categories.bar and b.snapshotEntry.categories.bar.order)
          or (b.snapshotEntry.categories.utility and b.snapshotEntry.categories.utility.order))) or math.huge

      if ao == bo then
        local na = a.snapshotEntry and a.snapshotEntry.name or C_Spell.GetSpellName(a.spellID) or ""
        local nb = b.snapshotEntry and b.snapshotEntry.name or C_Spell.GetSpellName(b.spellID) or ""
        return na < nb
      end
      return ao < bo
    end)
  end

  -- sorter og layout
  sortFrames(topFrames)
  sortFrames(bottomFrames)
  sortFrames(sideFrames.LEFT)
  sortFrames(sideFrames.RIGHT)

  LayoutTopBar(topFrames)
  LayoutBottomBar(bottomFrames)
  if #sideFrames.LEFT > 0 then LayoutSideBar(sideFrames.LEFT, "LEFT") end
  if #sideFrames.RIGHT > 0 then LayoutSideBar(sideFrames.RIGHT, "RIGHT") end


  -- Auto-map tracked buffs to spells using snapshot descriptions
  self.db.profile.tracking = self.db.profile.tracking or {}
  self.db.profile.tracking.buffs = self.db.profile.tracking.buffs or {}
  self.db.profile.tracking.buffs.links = self.db.profile.tracking.buffs.links or {}
  self.db.profile.tracking.buffs.links[class] = self.db.profile.tracking.buffs.links[class] or {}
  self.db.profile.tracking.buffs.links[class][specID] = self.db.profile.tracking.buffs.links[class][specID] or {}

  for buffID, entry in pairs(snapshot) do
    if entry.categories and entry.categories.buff then
      local desc = entry.desc or C_Spell.GetSpellDescription(buffID)
      if desc then
        for spellID, frame in pairs(self.spellFrames) do
          if frame and frame.snapshotEntry then
            local spellName = C_Spell.GetSpellName(spellID)
            if spellName and string.find(desc, spellName, 1, true) then
              self.trackedBuffToSpell[buffID] = spellID

              local links = self.db.profile.tracking.buffs.links[class][specID]
              if not links[buffID] then
                links[buffID] = spellID
              end
              break
            end
          end
        end
      end
    end
  end

  self:UpdateAllFrames()

  if self.Layout then
    self:Layout()
  end

  if self.RefreshAllTotems then
    self:RefreshAllTotems()
  end
end
