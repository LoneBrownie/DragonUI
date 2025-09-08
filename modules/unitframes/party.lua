local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI PARTY FRAMES MODULE - WoW 3.3.5a
-- ============================================================================

local Module = {
    partyFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil,
    partyUpdateQueue = {}
}

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

-- Cache Party frames (dynamic)
local PartyFrames = {}
for i = 1, 4 do
    PartyFrames[i] = {
        frame = _G['PartyMemberFrame' .. i],
        healthBar = _G['PartyMemberFrame' .. i .. 'HealthBar'],
        manaBar = _G['PartyMemberFrame' .. i .. 'ManaBar'],
        portrait = _G['PartyMemberFrame' .. i .. 'Portrait'],
        name = _G['PartyMemberFrame' .. i .. 'Name'],
        background = _G['PartyMemberFrame' .. i .. 'Background'],
        texture = _G['PartyMemberFrame' .. i .. 'Texture'],
        flash = _G['PartyMemberFrame' .. i .. 'Flash'],
        status = _G['PartyMemberFrame' .. i .. 'Status']
    }
end

-- Texture paths (party específicas)
local TEXTURES = {
    PARTY_FRAME = "Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe",
    HEALTH_BAR = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health",
    HEALTH_BAR_STATUS = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status"
}

-- Party frame coordinates from uipartyframe.blp (copiado de tu unitframe.lua)
local PARTY_COORDS = {
    border = {0.480469, 0.949219, 0.222656, 0.414062},
    flash = {0.480469, 0.925781, 0.453125, 0.636719},
    status = {0.00390625, 0.472656, 0.453125, 0.644531},
    health = {0.0, 0.28125, 0.6484375, 0.6953125},
    -- Mana bars por tipo de poder
    mana = {0.0, 0.296875, 0.7421875, 0.77734375},
    rage = {0.59375, 0.890625, 0.7421875, 0.77734375},
    focus = {0.56640625, 0.86328125, 0.6953125, 0.73046875},
    energy = {0.26953125, 0.56640625, 0.6953125, 0.73046875},
    runicpower = {0.0, 0.296875, 0.77734375, 0.8125}
}

-- Power type mapping
local POWER_MAP = {
    [0] = "mana", [1] = "rage", [2] = "focus", [3] = "energy", [6] = "runicpower"
}

-- Power colors (como en tu unitframe.lua)
local POWER_COLORS = {
    mana = {0.8, 0.9, 1.0, 0.8},
    rage = {1.0, 0.3, 0.3, 1},
    focus = {1.0, 0.6, 0.2, 1},
    energy = {1.0, 1.0, 0.3, 1},
    runicpower = {0.3, 0.8, 1.0, 1}
}

-- Frame elements storage
local frameElements = {}

-- Update throttling (como en target/focus)
local updateCache = {
    lastUpdate = {},
    throttleTime = 0.05
}

-- Combat update queue (como en tu unitframe.lua)
local combatEndFrame = nil

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "party") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.party or {}
    return setmetatable(config, {__index = defaults})
end

-- Helper function to check if mouse is over a frame (compatible con 3.3.5a)
local function IsMouseOverFrame(frame)
    if not frame or not frame:IsVisible() then
        return false
    end
    local success, isOver = pcall(function()
        return frame:IsMouseOver()
    end)
    return success and isOver
end

-- ============================================================================
-- FRAME STRUCTURE SETUP (Basado en ConfigurePartyFrameStructure)
-- ============================================================================

local function ConfigurePartyFrameStructure(i)
    local pf = PartyFrames[i].frame
    if not pf then return end
    
    pf:SetParent(Module.partyFrame)
    pf:SetSize(120, 53)
    pf:SetHitRectInsets(0, 0, 0, 12)

    -- Hide original elements (como en tu unitframe.lua)
    if PartyFrames[i].background then
        PartyFrames[i].background:Hide()
    end
    if PartyFrames[i].texture then
        PartyFrames[i].texture:SetTexture()
        PartyFrames[i].texture:Hide()
    end

    -- Reposition name (como en tu unitframe.lua)
    if PartyFrames[i].name then
        PartyFrames[i].name:ClearAllPoints()
        PartyFrames[i].name:SetSize(57, 12)
        PartyFrames[i].name:SetPoint('TOPLEFT', 46, -6)
    end

    -- Position debuffs (como en tu unitframe.lua)
    for debuffIndex = 1, 16 do
        local debuff = _G['PartyMemberFrame' .. i .. 'Debuff' .. debuffIndex]
        if debuff then
            debuff:ClearAllPoints()
            local xOffset = 120 + ((debuffIndex - 1) % 8) * 17
            local yOffset = -20 - (math.floor((debuffIndex - 1) / 8) * 17)
            debuff:SetPoint('TOPLEFT', pf, 'TOPLEFT', xOffset, yOffset)
        end
    end
end

-- ============================================================================
-- TEXTURE SETUP (Basado en SetupPartyFrameTextures)
-- ============================================================================

local function SetupPartyFrameTextures(i)
    local pf = PartyFrames[i].frame
    if not pf then return end

    -- Setup flash texture (como en tu unitframe.lua)
    if PartyFrames[i].flash then
        PartyFrames[i].flash:SetSize(114, 47)
        PartyFrames[i].flash:SetTexture(TEXTURES.PARTY_FRAME)
        PartyFrames[i].flash:SetTexCoord(unpack(PARTY_COORDS.flash))
        PartyFrames[i].flash:SetPoint('TOPLEFT', 1 + 1, -2)
        PartyFrames[i].flash:SetVertexColor(1, 0, 0, 1)
        PartyFrames[i].flash:SetDrawLayer('ARTWORK', 5)
    end

    -- Create border texture (como en tu unitframe.lua)
    if not frameElements['PartyFrameBorder' .. i] then
        local border = pf:CreateTexture('DragonUIPartyFrameBorder' .. i)
        border:SetDrawLayer('BORDER', 1)
        border:SetSize(120, 49)
        border:SetTexture(TEXTURES.PARTY_FRAME)
        border:SetTexCoord(unpack(PARTY_COORDS.border))
        border:SetPoint('TOPLEFT', 1, -2)
        frameElements['PartyFrameBorder' .. i] = border
    end

    -- Setup status texture (como en tu unitframe.lua)
    if PartyFrames[i].status then
        PartyFrames[i].status:SetSize(114, 47)
        PartyFrames[i].status:SetTexture(TEXTURES.PARTY_FRAME)
        PartyFrames[i].status:SetTexCoord(unpack(PARTY_COORDS.status))
        PartyFrames[i].status:SetPoint('TOPLEFT', 1, -2)
        PartyFrames[i].status:SetDrawLayer('BORDER', 1)
    end
end

-- ============================================================================
-- BAR SETUP (Basado en SetupPartyHealthBar/SetupPartyManaBar)
-- ============================================================================

local function SetupPartyHealthBar(i)
    local healthbar = PartyFrames[i].healthBar
    if not healthbar then return end

    healthbar:SetSize(70 + 1, 10)
    healthbar:ClearAllPoints()
    healthbar:SetPoint('TOPLEFT', 45 - 1, -19)
    healthbar:SetFrameLevel(3)

    -- Use individual texture files (como en tu unitframe.lua)
    healthbar:SetStatusBarTexture(TEXTURES.HEALTH_BAR)
    healthbar:SetStatusBarColor(1, 1, 1, 1)

    -- Disable original text system (como en tu unitframe.lua)
    if healthbar.TextString then
        healthbar.TextString:Hide()
        healthbar.TextString:SetText("")
        healthbar.TextString.Show = function() end
        healthbar.TextString.SetText = function() end
    end
    healthbar.cvar = nil
    healthbar.textLockable = 0
    healthbar.lockShow = 0

    -- Create custom text elements (como en tu target/focus)
    if not frameElements['PartyHealthText' .. i] then
        frameElements['PartyHealthText' .. i] = healthbar:CreateFontString(nil, 'OVERLAY', 'TextStatusBarText')
        frameElements['PartyHealthText' .. i]:SetPoint('CENTER', healthbar, 'CENTER', 0, 0)
        frameElements['PartyHealthText' .. i]:Hide()
    end

    if not frameElements['PartyHealthTextLeft' .. i] then
        frameElements['PartyHealthTextLeft' .. i] = healthbar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        frameElements['PartyHealthTextLeft' .. i]:SetPoint("LEFT", healthbar, "LEFT", 2, 0)
        frameElements['PartyHealthTextLeft' .. i]:SetJustifyH("LEFT")
        frameElements['PartyHealthTextLeft' .. i]:Hide()
    end

    if not frameElements['PartyHealthTextRight' .. i] then
        frameElements['PartyHealthTextRight' .. i] = healthbar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        frameElements['PartyHealthTextRight' .. i]:SetPoint("RIGHT", healthbar, "RIGHT", -2, 0)
        frameElements['PartyHealthTextRight' .. i]:SetJustifyH("RIGHT")
        frameElements['PartyHealthTextRight' .. i]:Hide()
    end
end

local function SetupPartyManaBar(i)
    local manabar = PartyFrames[i].manaBar
    if not manabar then return end

    manabar:SetSize(74, 7)
    manabar:ClearAllPoints()
    manabar:SetPoint('TOPLEFT', 41, -30)
    manabar:SetFrameLevel(3)

    -- Use uipartyframe.blp (como en tu unitframe.lua)
    manabar:SetStatusBarTexture(TEXTURES.PARTY_FRAME)
    manabar:SetStatusBarColor(1, 1, 1, 1)

    -- Disable original text system (como en tu unitframe.lua)
    if manabar.TextString then
        manabar.TextString:Hide()
        manabar.TextString:SetText("")
        manabar.TextString.Show = function() end
        manabar.TextString.SetText = function() end
    end
    manabar.cvar = nil
    manabar.textLockable = 0
    manabar.lockShow = 0

    -- Create custom text elements (como en tu target/focus)
    if not frameElements['PartyManaText' .. i] then
        frameElements['PartyManaText' .. i] = manabar:CreateFontString(nil, 'OVERLAY', 'TextStatusBarText')
        frameElements['PartyManaText' .. i]:SetPoint('CENTER', manabar, 'CENTER', 1.5, 0)
        frameElements['PartyManaText' .. i]:Hide()
    end

    if not frameElements['PartyManaTextLeft' .. i] then
        frameElements['PartyManaTextLeft' .. i] = manabar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        frameElements['PartyManaTextLeft' .. i]:SetPoint("LEFT", manabar, "LEFT", 3, 0)
        frameElements['PartyManaTextLeft' .. i]:SetJustifyH("LEFT")
        frameElements['PartyManaTextLeft' .. i]:Hide()
    end

    if not frameElements['PartyManaTextRight' .. i] then
        frameElements['PartyManaTextRight' .. i] = manabar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        frameElements['PartyManaTextRight' .. i]:SetPoint("RIGHT", manabar, "RIGHT", 0, 0)
        frameElements['PartyManaTextRight' .. i]:SetJustifyH("RIGHT")
        frameElements['PartyManaTextRight' .. i]:Hide()
    end
end

-- ============================================================================
-- BAR MANAGEMENT (Basado en tu UpdatePartyHPBar/UpdatePartyManaBar)
-- ============================================================================

local function SetupBarHooks(i)
    local healthbar = PartyFrames[i].healthBar
    local manabar = PartyFrames[i].manaBar

    -- Health bar hooks (como en target/focus)
    if healthbar and not healthbar.DragonUI_Setup then
        hooksecurefunc(healthbar, "SetValue", function(self, value)
            if not UnitExists('party' .. i) then return end
            
            local now = GetTime()
            if not updateCache.lastUpdate[i] then updateCache.lastUpdate[i] = {} end
            if now - (updateCache.lastUpdate[i].health or 0) < updateCache.throttleTime then return end
            updateCache.lastUpdate[i].health = now
            
            -- Update health bar textures and colors (como en tu unitframe.lua)
            UpdatePartyHealthBar(i)
        end)
        
        healthbar.DragonUI_Setup = true
    end
    
    -- Mana bar hooks (como en target/focus)
    if manabar and not manabar.DragonUI_Setup then
        hooksecurefunc(manabar, "SetValue", function(self, value)
            if not UnitExists('party' .. i) then return end
            
            local now = GetTime()
            if not updateCache.lastUpdate[i] then updateCache.lastUpdate[i] = {} end
            if now - (updateCache.lastUpdate[i].mana or 0) < updateCache.throttleTime then return end
            updateCache.lastUpdate[i].mana = now
            
            -- Update mana bar textures and coordinates (como en tu unitframe.lua)
            UpdatePartyManaBar(i)
        end)
        
        manabar.DragonUI_Setup = true
    end
end

-- ============================================================================
-- BAR UPDATE FUNCTIONS (Basado en tu UpdatePartyHPBar/UpdatePartyManaBar)
-- ============================================================================

function UpdatePartyHealthBar(i)
    local healthbar = PartyFrames[i].healthBar
    if not healthbar or not UnitExists('party' .. i) then return end

    local config = GetConfig()
    local health = UnitHealth('party' .. i)
    local maxHealth = UnitHealthMax('party' .. i)

    if not health or not maxHealth or maxHealth == 0 then
        healthbar:Hide()
        return
    end

    healthbar:Show()

    -- Apply class colors if enabled (como en tu unitframe.lua)
    if config.classcolor then
        local _, class = UnitClass('party' .. i)
        if class and RAID_CLASS_COLORS[class] then
            -- Use -Status texture for class colors
            healthbar:SetStatusBarTexture(TEXTURES.HEALTH_BAR_STATUS)
            local color = RAID_CLASS_COLORS[class]
            healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
        else
            healthbar:SetStatusBarTexture(TEXTURES.HEALTH_BAR)
            healthbar:SetStatusBarColor(1, 1, 1, 1)
        end
    else
        -- Use coordinate-based system (como en tu unitframe.lua)
        healthbar:SetStatusBarTexture(TEXTURES.PARTY_FRAME)
        healthbar:SetStatusBarColor(1, 1, 1, 1)
        SetPartyHealthBarCoords(healthbar)
    end
end

function UpdatePartyManaBar(i)
    local manabar = PartyFrames[i].manaBar
    if not manabar or not UnitExists('party' .. i) then return end

    local power = UnitMana('party' .. i) or 0
    local maxPower = UnitManaMax('party' .. i) or 0
    local powerType = UnitPowerType('party' .. i) or 0

    if maxPower > 0 then
        manabar:Show()
        manabar:SetMinMaxValues(0, maxPower)
        SetPartyManaBarCoords(manabar, powerType, power, maxPower)
        
        -- Apply power color (como en tu unitframe.lua)
        local powerName = POWER_MAP[powerType] or "mana"
        local color = POWER_COLORS[powerName] or POWER_COLORS.mana
        manabar:SetStatusBarColor(color[1], color[2], color[3], color[4])
    else
        manabar:Hide()
    end
end

-- ============================================================================
-- COORDINATE SYSTEM (Basado en tu SetPartyHealthBarCoords/SetPartyManaBarCoords)
-- ============================================================================

function SetPartyHealthBarCoords(healthbar)
    if not healthbar then return end

    local coords = PARTY_COORDS.health
    local texture = healthbar:GetStatusBarTexture()
    if not texture then return end

    -- Dynamic clipping (como en tu unitframe.lua)
    local currentValue = healthbar:GetValue()
    local maxValue = select(2, healthbar:GetMinMaxValues())
    local percentage = maxValue > 0 and (currentValue / maxValue) or 1

    local adjustedCoords = {coords[1], coords[2], coords[3], coords[4]}
    local textureWidth = coords[2] - coords[1]
    local newWidth = textureWidth * percentage
    adjustedCoords[2] = coords[1] + newWidth

    texture:SetTexCoord(adjustedCoords[1], adjustedCoords[2], adjustedCoords[3], adjustedCoords[4])
    texture:SetTexture(TEXTURES.PARTY_FRAME)
end

function SetPartyManaBarCoords(manabar, powerType, currentPower, maxPower)
    if not manabar then return end

    local powerName = POWER_MAP[powerType] or "mana"
    local baseCoords = PARTY_COORDS[powerName] or PARTY_COORDS.mana

    -- Dynamic clipping (Pac-Man effect como en tu unitframe.lua)
    local percentage = 1.0
    if maxPower and maxPower > 0 and currentPower then
        percentage = currentPower / maxPower
    end

    local texture = manabar:GetStatusBarTexture()
    if texture then
        local left = baseCoords[1]
        local right = baseCoords[1] + (baseCoords[2] - baseCoords[1]) * percentage
        local top = baseCoords[3]
        local bottom = baseCoords[4]

        texture:SetTexCoord(left, right, top, bottom)
        texture:SetTexture(TEXTURES.PARTY_FRAME)
    end
end

-- ============================================================================
-- TEXT SYSTEM (Basado en tu UpdatePartyFrameText)
-- ============================================================================
local function ClearPartyFrameTexts(i)
    if frameElements['PartyHealthText' .. i] then frameElements['PartyHealthText' .. i]:Hide() end
    if frameElements['PartyHealthTextLeft' .. i] then frameElements['PartyHealthTextLeft' .. i]:Hide() end
    if frameElements['PartyHealthTextRight' .. i] then frameElements['PartyHealthTextRight' .. i]:Hide() end
    if frameElements['PartyManaText' .. i] then frameElements['PartyManaText' .. i]:Hide() end
    if frameElements['PartyManaTextLeft' .. i] then frameElements['PartyManaTextLeft' .. i]:Hide() end
    if frameElements['PartyManaTextRight' .. i] then frameElements['PartyManaTextRight' .. i]:Hide() end
end
local function UpdatePartyFrameText(i)
    if not i or type(i) ~= "number" or i < 1 or i > 4 then return end

    -- Clear if unit doesn't exist or is dead (como en target/focus)
    if not UnitExists('party' .. i) or UnitIsDeadOrGhost('party' .. i) then
        ClearPartyFrameTexts(i)
        return
    end

    if UnitIsPlayer('party' .. i) and UnitIsConnected and not UnitIsConnected('party' .. i) then
        ClearPartyFrameTexts(i)
        return
    end

    local config = GetConfig()
    local showHealthAlways = config.showHealthTextAlways or false
    local showManaAlways = config.showManaTextAlways or false
    local textFormat = config.textFormat or "both"
    local useBreakup = config.breakUpLargeNumbers or false

    local healthbar = PartyFrames[i].healthBar
    local manabar = PartyFrames[i].manaBar

    if not healthbar or not manabar then return end

    -- Health text logic (como en tu target/focus)
    local showHealthText = showHealthAlways or IsMouseOverFrame(healthbar)
    if showHealthText then
        local health = UnitHealth('party' .. i)
        local maxHealth = UnitHealthMax('party' .. i)

        if health and maxHealth and maxHealth > 0 then
            local healthText = addon.FormatStatusText(health, maxHealth, textFormat, useBreakup)

            if textFormat == 'both' and type(healthText) == 'table' then
                frameElements['PartyHealthText' .. i]:Hide()
                frameElements['PartyHealthTextLeft' .. i]:SetText(healthText.percentage)
                frameElements['PartyHealthTextRight' .. i]:SetText(healthText.current)
                frameElements['PartyHealthTextLeft' .. i]:Show()
                frameElements['PartyHealthTextRight' .. i]:Show()
            else
                local displayText = type(healthText) == "table" and healthText.combined or healthText
                frameElements['PartyHealthText' .. i]:SetText(displayText)
                frameElements['PartyHealthText' .. i]:Show()
                frameElements['PartyHealthTextLeft' .. i]:Hide()
                frameElements['PartyHealthTextRight' .. i]:Hide()
            end
        end
    else
        -- Hide all health texts
        frameElements['PartyHealthText' .. i]:Hide()
        frameElements['PartyHealthTextLeft' .. i]:Hide()
        frameElements['PartyHealthTextRight' .. i]:Hide()
    end

    -- Mana text logic (como en tu target/focus)
    local showManaText = showManaAlways or IsMouseOverFrame(manabar)
    if showManaText then
        local power = UnitPower('party' .. i)
        local maxPower = UnitPowerMax('party' .. i)

        if power and maxPower and maxPower > 0 then
            local powerText = addon.FormatStatusText(power, maxPower, textFormat, useBreakup)

            if textFormat == 'both' and type(powerText) == 'table' then
                frameElements['PartyManaText' .. i]:Hide()
                frameElements['PartyManaTextLeft' .. i]:SetText(powerText.percentage)
                frameElements['PartyManaTextRight' .. i]:SetText(powerText.current)
                frameElements['PartyManaTextLeft' .. i]:Show()
                frameElements['PartyManaTextRight' .. i]:Show()
            else
                local displayText = type(powerText) == "table" and powerText.combined or powerText
                frameElements['PartyManaText' .. i]:SetText(displayText)
                frameElements['PartyManaText' .. i]:Show()
                frameElements['PartyManaTextLeft' .. i]:Hide()
                frameElements['PartyManaTextRight' .. i]:Hide()
            end
        end
    else
        -- Hide all mana texts
        frameElements['PartyManaText' .. i]:Hide()
        frameElements['PartyManaTextLeft' .. i]:Hide()
        frameElements['PartyManaTextRight' .. i]:Hide()
    end
end



-- ============================================================================
-- ICONS AND RANGE (Basado en SetupPartyFrameIcons/SetupPartyFrameRange)
-- ============================================================================

local function SetupPartyFrameIcons(i)
    local pf = PartyFrames[i].frame
    if not pf then return end

    local function updateSmallIcons()
        local leaderIcon = _G['PartyMemberFrame' .. i .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('BOTTOM', pf, 'TOP', -10, -6)
            leaderIcon:SetSize(16, 16)
        end

        local masterIcon = _G['PartyMemberFrame' .. i .. 'MasterIcon']
        if masterIcon then
            masterIcon:ClearAllPoints()
            masterIcon:SetPoint('BOTTOM', pf, 'TOP', -10 + 16, -6)
        end

        local guideIcon = _G['PartyMemberFrame' .. i .. 'GuideIcon']
        if guideIcon then
            guideIcon:ClearAllPoints()
            guideIcon:SetPoint('BOTTOM', pf, 'TOP', -10, -6)
        end

        local pvpIcon = _G['PartyMemberFrame' .. i .. 'PVPIcon']
        if pvpIcon then
            pvpIcon:ClearAllPoints()
            pvpIcon:SetPoint('CENTER', pf, 'TOPLEFT', 7, -24)
        end

        local readyCheck = _G['PartyMemberFrame' .. i .. 'ReadyCheck']
        if readyCheck then
            readyCheck:ClearAllPoints()
            readyCheck:SetPoint('CENTER', PartyFrames[i].portrait, 'CENTER', 0, -2)
        end

        local notPresentIcon = _G['PartyMemberFrame' .. i .. 'NotPresentIcon']
        if notPresentIcon then
            notPresentIcon:ClearAllPoints()
            notPresentIcon:SetPoint('LEFT', pf, 'RIGHT', 2, -2)
        end
    end
    
    updateSmallIcons()
    pf.updateSmallIcons = updateSmallIcons
end

local function SetupPartyFrameRange(i)
    local pf = PartyFrames[i].frame
    if not pf then return end

    local function updateRange()
        if UnitInRange then
            local inRange, checkedRange = UnitInRange('party' .. i)
            if checkedRange and not inRange then
                pf:SetAlpha(0.55)
            else
                pf:SetAlpha(1)
            end
        else
            pf:SetAlpha(1)
        end
    end

    pf:HookScript('OnUpdate', updateRange)
    pf.updateRange = updateRange
end

-- ============================================================================
-- COMBAT QUEUE SYSTEM (Basado en tu QueuePartyUpdate)
-- ============================================================================

local function QueuePartyUpdate(index, updateType)
    if not Module.partyUpdateQueue[index] then
        Module.partyUpdateQueue[index] = {}
    end
    Module.partyUpdateQueue[index][updateType] = true

    if not combatEndFrame then
        combatEndFrame = CreateFrame("Frame")
        combatEndFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatEndFrame:SetScript("OnEvent", function()
            ProcessPartyUpdateQueue()
        end)
    end
end

local function ProcessPartyUpdateQueue()
    if InCombatLockdown() or UnitAffectingCombat('player') then return end

    for index, updates in pairs(Module.partyUpdateQueue) do
        if updates.health then
            UpdatePartyHealthBar(index)
        end
        if updates.mana then
            UpdatePartyManaBar(index)
        end
        if updates.text then
            UpdatePartyFrameText(index)
        end
    end

    Module.partyUpdateQueue = {}
end

-- ============================================================================
-- PARTY CONTAINER SETUP (Basado en CreatePartyContainer)
-- ============================================================================

local function CreatePartyContainer()
    if Module.partyFrame then return end

    -- Create main container frame (como en tu unitframe.lua)
    local PartyMoveFrame = CreateFrame('Frame', 'DragonUIPartyMoveFrame', UIParent)
    PartyMoveFrame:SetFrameStrata('BACKGROUND')
    PartyMoveFrame:SetFrameLevel(1)
    PartyMoveFrame:Show()
    Module.partyFrame = PartyMoveFrame

    -- Reparent original frames (como en tu unitframe.lua)
    for i = 1, 4 do
        local originalFrame = PartyFrames[i].frame
        if originalFrame then
            originalFrame:SetMovable(true)
            originalFrame:ClearAllPoints()
            originalFrame:SetParent(PartyMoveFrame)
            originalFrame:SetMovable(false)
        end
    end

    -- Calculate container size and position first frame (como en tu unitframe.lua)
    local sizeX, sizeY = PartyFrames[1].frame:GetSize()
    local gap = 10
    PartyMoveFrame:SetSize(sizeX, sizeY * 4 + 3 * gap)

    -- Position first party frame
    PartyFrames[1].frame:ClearAllPoints()
    PartyFrames[1].frame:SetPoint('TOPLEFT', PartyMoveFrame, 'TOPLEFT', 0, 0)
end

-- ============================================================================
-- MAIN INITIALIZATION (Basado en tu ChangePartyFrame)
-- ============================================================================

local function InitializeFrame()
    if Module.configured then return end

    -- Check if party members exist
    local hasPartyMembers = false
    for i = 1, 4 do
        if UnitExists('party' .. i) then
            hasPartyMembers = true
            break
        end
    end

    -- Create container
    CreatePartyContainer()

    -- Setup each party frame
    for i = 1, 4 do
        ConfigurePartyFrameStructure(i)
        SetupPartyFrameTextures(i)
        SetupPartyHealthBar(i)
        SetupPartyManaBar(i)
        SetupBarHooks(i)
        SetupPartyFrameIcons(i)
        SetupPartyFrameRange(i)
        
        -- Initialize bars if member exists
        if UnitExists('party' .. i) then
            UpdatePartyHealthBar(i)
            UpdatePartyManaBar(i)
        end
    end

    -- Apply configuration
    local config = GetConfig()
    UpdatePartyState(config)

    -- Setup text system (como target/focus)
    if addon.TextSystem and not Module.textSystem then
        Module.textSystem = addon.TextSystem.SetupFrameTextSystem(
            "party", "party", Module.partyFrame,
            nil, nil, "PartyFrame"
        )
    end

    Module.configured = true
    print("|cFF00FF00[DragonUI]|r Party frames configured successfully")
end

-- ============================================================================
-- PARTY STATE UPDATE (Basado en tu UpdatePartyState)
-- ============================================================================

function UpdatePartyState(config)
    if not Module.partyFrame then return end

    -- Positioning logic (como en tu unitframe.lua)
    local anchor, parent, anchorPoint, x, y
    if config.override then
        anchor = config.anchor or "BOTTOMLEFT"
        parent = _G[config.anchorParent or "UIParent"] or UIParent
        anchorPoint = config.anchorPoint or "BOTTOMLEFT"
        x = config.x or 0
        y = config.y or 0
    else
        anchor = "TOPLEFT"
        parent = UIParent
        anchorPoint = "TOPLEFT"
        x = 20
        y = -120
    end

    local scale = config.scale or 1.0
    local padding = config.padding or 10
    local orientation = config.orientation or 'vertical'

    -- Apply positioning and scale
    Module.partyFrame:ClearAllPoints()
    Module.partyFrame:SetPoint(anchor, parent, anchorPoint, x, y)
    Module.partyFrame:SetScale(scale)

    -- Update orientation (como en tu unitframe.lua)
    local sizeX, sizeY = PartyFrames[1].frame:GetSize()

    if orientation == 'vertical' then
        Module.partyFrame:SetSize(sizeX, sizeY * 4 + 3 * padding)
    else
        Module.partyFrame:SetSize(sizeX * 4 + 3 * padding, sizeY)
    end

    for i = 2, 4 do
        local pf = PartyFrames[i].frame
        if orientation == 'vertical' then
            pf:ClearAllPoints()
            pf:SetPoint('TOPLEFT', PartyFrames[i-1].frame, 'BOTTOMLEFT', 0, -padding)
        else
            pf:ClearAllPoints()
            pf:SetPoint('TOPLEFT', PartyFrames[i-1].frame, 'TOPRIGHT', padding, 0)
        end
    end

    -- Update bars for existing members
    for i = 1, 4 do
        if UnitExists("party" .. i) then
            UpdatePartyHealthBar(i)
            UpdatePartyManaBar(i)
            UpdatePartyFrameText(i)
        end
    end
end

-- ============================================================================
-- EVENT HANDLING (Basado en tu RegisterPartyEvents)
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.initialized = true
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "PARTY_MEMBER_ENABLE" or event == "PARTY_MEMBER_DISABLE" then
        -- Check if we have party members
        local hasPartyMembers = false
        for i = 1, 4 do
            if UnitExists('party' .. i) then
                hasPartyMembers = true
                break
            end
        end

        if not hasPartyMembers then return end

        -- Update after delay (como en tu unitframe.lua)
        local updateFrame = CreateFrame("Frame")
        local updateTime = 0
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            updateTime = updateTime + elapsed
            if updateTime >= 0.1 then
                for i = 1, 4 do
                    if not InCombatLockdown() and not UnitAffectingCombat('player') then
                        UpdatePartyHealthBar(i)
                        UpdatePartyManaBar(i)
                        UpdatePartyFrameText(i)
                        
                        local pf = PartyFrames[i].frame
                        if pf and pf.updateSmallIcons then
                            pf.updateSmallIcons()
                        end
                    else
                        QueuePartyUpdate(i, 'health')
                        QueuePartyUpdate(i, 'mana')
                        QueuePartyUpdate(i, 'text')
                    end
                end
                updateFrame:SetScript("OnUpdate", nil)
            end
        end)
        
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_CONVERTED_TO_RAID" then
        -- Hide party frames in raid mode (como en tu unitframe.lua)
        if GetNumRaidMembers() > 0 then
            if Module.partyFrame then
                Module.partyFrame:Hide()
            end
        else
            if Module.partyFrame then
                Module.partyFrame:Show()
            end
        end
        
    elseif event == "UNIT_HEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXHEALTH" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        local unit = ...
        local partyIndex = unit and string.match(unit, "^party([1-4])$")
        if partyIndex then
            local i = tonumber(partyIndex)
            if i then
                if not InCombatLockdown() and not UnitAffectingCombat('player') then
                    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
                        UpdatePartyHealthBar(i)
                    else
                        UpdatePartyManaBar(i)
                    end
                    UpdatePartyFrameText(i)
                else
                    QueuePartyUpdate(i, event == "UNIT_HEALTH" and 'health' or 'mana')
                    QueuePartyUpdate(i, 'text')
                end
            end
        end
    end
end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    Module.eventsFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
    Module.eventsFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
    Module.eventsFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    Module.eventsFrame:RegisterEvent("PARTY_CONVERTED_TO_RAID")
    Module.eventsFrame:RegisterEvent("UNIT_HEALTH")
    Module.eventsFrame:RegisterEvent("UNIT_POWER_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_MAXHEALTH")
    Module.eventsFrame:RegisterEvent("UNIT_MAXPOWER")
    Module.eventsFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API (Como en target/focus)
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end
    
    local config = GetConfig()
    UpdatePartyState(config)
    
    for i = 1, 4 do
        if UnitExists('party' .. i) then
            UpdatePartyHealthBar(i)
            UpdatePartyManaBar(i)
            UpdatePartyFrameText(i)
        end
    end
end

local function ResetFrame()
    local defaults = addon.defaults and addon.defaults.profile.unitframe.party or {}
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "party", key, value)
    end
    
    local config = GetConfig()
    UpdatePartyState(config)
end

-- Export API (como target/focus)
addon.PartyFrames = {
    Refresh = RefreshFrame,
    RefreshPartyFrames = RefreshFrame,
    Reset = ResetFrame,
    anchor = function() return Module.partyFrame end,
    ChangePartyFrames = RefreshFrame,
    UpdatePartyState = UpdatePartyState
}

-- Legacy compatibility (como en tu unitframe.lua)
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangePartyFrame = RefreshFrame
addon.unitframe.RefreshAllPartyFrames = RefreshFrame

-- Global functions for compatibility
_G.UpdatePartyHealthBar = UpdatePartyHealthBar
_G.UpdatePartyManaBar = UpdatePartyManaBar
_G.UpdatePartyFrameText = UpdatePartyFrameText
_G.SetPartyHealthBarCoords = SetPartyHealthBarCoords
_G.SetPartyManaBarCoords = SetPartyManaBarCoords

function addon:RefreshPartyFrames()
    RefreshFrame()
end

print("|cFF00FF00[DragonUI]|r Party frames module loaded and optimized v1.0")