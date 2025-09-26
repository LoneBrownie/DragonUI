local addon = select(2, ...)
local compatibility = {}
addon.compatibility = compatibility

--[[
* DragonUI Compatibility Manager
* 
* Modular system to detect specific addons and apply custom behaviors.
* Each addon can have its own detection and behavior logic.
]]

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CONFIG = {
    warningDelay = 0.5,
    scanDelay = 0.1
}

-- ============================================================================
-- OPTIMIZED SYSTEMS
-- ============================================================================

-- Shared timer system for memory efficiency
local delayedActions = {}
local sharedTimer = CreateFrame("Frame")
sharedTimer:SetScript("OnUpdate", function(self, elapsed)
    for i = #delayedActions, 1, -1 do
        local action = delayedActions[i]
        action.elapsed = action.elapsed + elapsed
        if action.elapsed >= action.delay then
            action.func()
            table.remove(delayedActions, i)
        end
    end
    if #delayedActions == 0 then
        self:SetScript("OnUpdate", nil)
    end
end)

local function DelayedCall(func, delay)
    table.insert(delayedActions, { func = func, delay = delay, elapsed = 0 })
    sharedTimer:SetScript("OnUpdate", sharedTimer:GetScript("OnUpdate"))
end

-- Cache system for addon loading checks
local addonLoadCache = {}
local function IsAddonLoadedCached(addonName)
    if addonLoadCache[addonName] == nil then
        addonLoadCache[addonName] = IsAddOnLoaded(addonName)
    end
    return addonLoadCache[addonName]
end

-- ============================================================================
-- BEHAVIOR SYSTEM
-- ============================================================================

local behaviors = {}

-- Behavior: Show conflict warning with disable option
behaviors.ConflictWarning = function(addonName, addonInfo)
    local popupName = "DRAGONUI_CONFLICT_" .. string.upper(addonName)
    
    StaticPopupDialogs[popupName] = {
        text = string.format(
            "|cFFFF0000DragonUI Conflict Warning|r\n\n" ..
            "The addon |cFFFFFF00%s|r conflicts with DragonUI.\n\n" ..
            "|cFFFF9999Reason:|r %s\n\n" ..
            "Disable the conflicting addon now?",
            addonInfo.name, addonInfo.reason
        ),
        button1 = "Disable ",
        button2 = "Keep Both",
        OnAccept = function()
            DisableAddOn(addonName)
            ReloadUI()
        end,
        OnCancel = function() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3
    }
    
    StaticPopup_Show(popupName)
end

-- Behavior: CompactRaidFrame taint mitigation
behaviors.CompactRaidFrameFix = function(addonName, addonInfo)
    print("|cFFFFFF00DragonUI COMPATIBILITY:|r CompactRaidFrame taint mitigation activated!")
    
    -- Simple state tracking
    local inCombat = false
    local needsRefresh = false
    local lastPartySize = GetNumPartyMembers()
    
    -- Complete party frame recreation system (simulates /reload for party frames)
    local function ForcePartyFrameReload()
        -- STEP 1: Complete cleanup and reset of all party frames
        for i = 1, 4 do
            local frameName = 'PartyMemberFrame' .. i
            local frame = _G[frameName]
            
            if frame then
                
                -- Hide and clear all events
                frame:Hide()
                frame:UnregisterAllEvents()
                
                -- Reset all frame properties to initial state
                frame:SetAlpha(1)
                frame:ClearAllPoints()
                
                -- Clear unit assignment
                frame.unit = nil
                frame.id = nil
                
                -- Reset health bar
                local healthBar = _G[frameName .. 'HealthBar']
                if healthBar then
                    healthBar:UnregisterAllEvents()
                    healthBar:SetMinMaxValues(0, 100)
                    healthBar:SetValue(0)
                    healthBar:SetStatusBarColor(1, 1, 1, 1)
                end
                
                -- Reset mana bar  
                local manaBar = _G[frameName .. 'ManaBar']
                if manaBar then
                    manaBar:UnregisterAllEvents()
                    manaBar:SetMinMaxValues(0, 100)
                    manaBar:SetValue(0)
                    manaBar:SetStatusBarColor(1, 1, 1, 1)
                end
                
                -- Clear portrait
                local portrait = _G[frameName .. 'Portrait']
                if portrait then
                    portrait:SetTexture(nil)
                end
                
                -- Reset name text
                local nameText = _G[frameName .. 'Name']
                if nameText then
                    nameText:SetText("")
                end
                
                -- Clear all DragonUI custom elements
                if frame.DragonUI_CustomTexts then
                    frame.DragonUI_CustomTexts = nil
                end
                if frame.DragonUI_HealthText then
                    frame.DragonUI_HealthText:Hide()
                    frame.DragonUI_HealthText = nil
                end
                if frame.DragonUI_ManaText then
                    frame.DragonUI_ManaText:Hide()
                    frame.DragonUI_ManaText = nil
                end
                if frame.DragonUI_TextFrame then
                    frame.DragonUI_TextFrame:Hide()
                    frame.DragonUI_TextFrame = nil
                end
            end
        end
        
        -- STEP 2: Wait a bit for cleanup, then completely reinitialize
        DelayedCall(function()
            -- Force complete party system reload
            if _G.PartyMemberFrame_UpdateParty then
                _G.PartyMemberFrame_UpdateParty()
            end
            
            -- Reinitialize each frame from scratch (like on first load)
            for i = 1, 4 do
                local frameName = 'PartyMemberFrame' .. i
                local frame = _G[frameName]
                
                if frame then
                    -- Simulate OnLoad event for complete reset
                    if _G.PartyMemberFrame_OnLoad then
                        _G.PartyMemberFrame_OnLoad(frame)
                    end
                    
                    -- Set proper unit and ID
                    frame.unit = 'party' .. i
                    frame.id = i
                    
                    -- Register all necessary events (like on first load)
                    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
                    frame:RegisterEvent("PARTY_LEADER_CHANGED")
                    frame:RegisterEvent("PARTY_MEMBER_ENABLE")
                    frame:RegisterEvent("PARTY_MEMBER_DISABLE")
                    frame:RegisterEvent("UNIT_HEALTH")
                    frame:RegisterEvent("UNIT_MAXHEALTH")
                    frame:RegisterEvent("UNIT_MANA")
                    frame:RegisterEvent("UNIT_MAXMANA")
                    frame:RegisterEvent("UNIT_RAGE")
                    frame:RegisterEvent("UNIT_ENERGY")
                    frame:RegisterEvent("UNIT_AURA")
                    frame:RegisterEvent("UNIT_PET")
                    frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
                    frame:RegisterEvent("PORTRAIT_UPDATE")
                end
            end
            
            -- STEP 3: Apply proper visibility based on current party state
            DelayedCall(function()
                local numMembers = GetNumPartyMembers()
                
                for i = 1, 4 do
                    local frame = _G['PartyMemberFrame' .. i]
                    if frame then
                        if i <= numMembers then
                            -- ALWAYS show frame if party member slot should exist
                            frame:Show()
                            
                            -- Check if unit actually exists
                            if UnitExists('party' .. i) then
                                -- Force complete member update for existing unit
                                if _G.PartyMemberFrame_UpdateMember then
                                    _G.PartyMemberFrame_UpdateMember(frame)
                                end
                                
                                -- Force health/mana updates
                                local healthBar = _G[frame:GetName() .. 'HealthBar']
                                if healthBar and _G.UnitFrameHealthBar_Update then
                                    _G.UnitFrameHealthBar_Update(healthBar, 'party' .. i)
                                end
                                
                                local manaBar = _G[frame:GetName() .. 'ManaBar']
                                if manaBar and _G.UnitFrameManaBar_Update then
                                    _G.UnitFrameManaBar_Update(manaBar, 'party' .. i)
                                end
                                
                            else
                                -- Show frame but with "Connecting..." or empty state
                                local nameText = _G[frame:GetName() .. 'Name']
                                if nameText then
                                    nameText:SetText("Connecting...")
                                end
                            end
                        else
                            -- Hide unused frames  
                            frame:Hide()
                        end
                    end
                end
                
                -- STEP 4: Apply DragonUI customizations on top
                DelayedCall(function()
                    if addon and addon.RefreshPartyFrames then
                        addon.RefreshPartyFrames()
                    end
                end, 0.2)
                
            end, 0.3)
            
        end, 0.2)
    end
    
    -- Create a frame for simple polling system (more reliable than events)
    local pollingFrame = CreateFrame("Frame")
    local checkInterval = 0
    
    pollingFrame:SetScript("OnUpdate", function(self, elapsed)
        checkInterval = checkInterval + elapsed
        
        if checkInterval >= 0.5 then -- Check every 0.5 seconds
            checkInterval = 0
            
            local currentlyInCombat = InCombatLockdown()
            local currentPartySize = GetNumPartyMembers()
            
            -- Detect combat state change
            if inCombat and not currentlyInCombat then
                -- Just exited combat
                
                if needsRefresh or (currentPartySize ~= lastPartySize) then
                    -- Execute auto-refresh after combat
                    ForcePartyFrameReload()
                    needsRefresh = false
                end
                
                lastPartySize = currentPartySize
            elseif not inCombat and currentlyInCombat then
                -- Just entered combat
                lastPartySize = currentPartySize
            end
            
            -- Detect party change during combat
            if currentlyInCombat and (currentPartySize ~= lastPartySize) then
                needsRefresh = true
                lastPartySize = currentPartySize
            end
            
            -- Update combat state
            inCombat = currentlyInCombat
        end
    end)
    
    -- Create a slash command for manual testing
    SLASH_DRAGONUI_PARTYFIX1 = "/duipartyfix"
    SlashCmdList["DRAGONUI_PARTYFIX"] = function(msg)
        if msg == "force" then
            ForcePartyFrameReload()
        else
            print("DragonUI Party Fix:")
            print("  /duipartyfix force - Force party frame reload")
        end
    end
    
    print("|cFFFFFF00DragonUI:|r CompactRaidFrame compatibility system ready!")
end


-- ============================================================================
-- ADDON REGISTRY
-- ============================================================================

local ADDON_REGISTRY = {
    ["unitframelayers"] = {
        name = "UnitFrameLayers",
        reason = "Conflicts with DragonUI's custom unit frame textures and power bar system.",
        behavior = behaviors.ConflictWarning,
        checkOnce = true
    },
    ["compactraidframe"] = {
        name = "CompactRaidFrame",
        reason = "Known taint issues when manipulating party frames during combat. DragonUI provides automatic fixes.",
        behavior = behaviors.CompactRaidFrameFix,
        checkOnce = true,
        listenToRaidEvents = true -- Enable raid event monitoring
    },
}

-- ============================================================================
-- STATE TRACKING
-- ============================================================================

local state = {
    processedAddons = {},
    activeAddons = {},
    initialized = false
}

-- ============================================================================
-- EVENT SYSTEM (ADDON SPECIFIC)
-- ============================================================================

local activeEventFrames = {}

local function RegisterEventsForAddon(addonName, addonInfo)
    if not addonInfo.listenToRaidEvents then
        return
    end
    
    local eventFrame = CreateFrame("Frame", "DragonUI_Events_" .. addonName)
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_CONVERTED_TO_RAID")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("GROUP_FORMED")
    eventFrame:RegisterEvent("GROUP_JOINED")
    eventFrame:RegisterEvent("GROUP_LEFT")
    
    eventFrame:SetScript("OnEvent", function(self, event)
        if compatibility.raidUpdateHandlers and compatibility.raidUpdateHandlers[addonName] then
            compatibility.raidUpdateHandlers[addonName]()
        end
    end)
    
    activeEventFrames[addonName] = eventFrame
end

local function UnregisterEventsForAddon(addonName)
    if activeEventFrames[addonName] then
        activeEventFrames[addonName]:UnregisterAllEvents()
        activeEventFrames[addonName] = nil
    end
end

-- ============================================================================
-- CORE DETECTION & EXECUTION
-- ============================================================================

local function ValidateRegistryEntry(addonName, addonInfo)
    if not addonInfo.name or not addonInfo.reason or not addonInfo.behavior then
        return false
    end
    return true
end

local function ProcessAddon(addonName, addonInfo)
    if not ValidateRegistryEntry(addonName, addonInfo) then
        return
    end

    if addonInfo.checkOnce and state.processedAddons[addonName] then
        return
    end

    if addonInfo.checkOnce then
        state.processedAddons[addonName] = true
    end

    state.activeAddons[addonName] = addonInfo

    if addonInfo.behavior then
        addonInfo.behavior(addonName, addonInfo)
    end
    
    if addonInfo.listenToRaidEvents then
        RegisterEventsForAddon(addonName, addonInfo)
    end
end

local function ScanForRegisteredAddons()
    local foundAddons = {}
    
    for addonName, addonInfo in pairs(ADDON_REGISTRY) do
        if IsAddonLoadedCached(addonName) then
            foundAddons[addonName] = addonInfo
        end
    end
    
    return foundAddons
end

-- ============================================================================
-- MAIN EVENT SYSTEM
-- ============================================================================

local function InitializeEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
        if event == "ADDON_LOADED" then
            if loadedAddonName then
                addonLoadCache[loadedAddonName] = true
            end

            if loadedAddonName == "DragonUI" then
                DelayedCall(function()
                    local foundAddons = ScanForRegisteredAddons()
                    for addonName, addonInfo in pairs(foundAddons) do
                        ProcessAddon(addonName, addonInfo)
                    end
                end, CONFIG.scanDelay)

            elseif ADDON_REGISTRY[loadedAddonName] then
                DelayedCall(function()
                    ProcessAddon(loadedAddonName, ADDON_REGISTRY[loadedAddonName])
                end, CONFIG.warningDelay)
            end

        elseif event == "PLAYER_LOGIN" then
            state.initialized = true
        end
    end)
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

local function InitializeCommands()
    SLASH_DRAGONUI_COMPAT1 = "/duicomp"
    
    SlashCmdList["DRAGONUI_COMPAT"] = function(msg)
        
        for i = 1, GetNumAddOns() do
            local name = select(1, GetAddOnInfo(i))
            local title = GetAddOnMetadata(i, "Title") or "Unknown"
            local loaded = IsAddOnLoaded(i)
            if loaded then
                print("  - " .. title .. " |cFFFFFF00(" .. name .. ")|r")
            end
        end
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function compatibility:RegisterAddon(addonName, addonInfo)
    if not ValidateRegistryEntry(addonName, addonInfo) then
        return false
    end
    
    ADDON_REGISTRY[addonName] = addonInfo
    
    if IsAddonLoadedCached(addonName) then
        ProcessAddon(addonName, addonInfo)
    end
    
    return true
end

function compatibility:UnregisterAddon(addonName)
    if ADDON_REGISTRY[addonName] then
        UnregisterEventsForAddon(addonName)
        state.activeAddons[addonName] = nil
        if compatibility.raidUpdateHandlers then
            compatibility.raidUpdateHandlers[addonName] = nil
        end
        
        ADDON_REGISTRY[addonName] = nil
        
        return true
    end
    return false
end

function compatibility:IsRegistered(addonName)
    return ADDON_REGISTRY[addonName] ~= nil
end

function compatibility:GetActiveAddons()
    return state.activeAddons
end

-- ============================================================================
-- CLEANUP FUNCTIONS
-- ============================================================================

local function Cleanup()
    for addonName, _ in pairs(activeEventFrames) do
        UnregisterEventsForAddon(addonName)
    end
    activeEventFrames = {}
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

InitializeEvents()
InitializeCommands()