local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI FOCUS FRAME MODULE - WoW 3.3.5a
-- ============================================================================

local Module = {
    focusFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil
}

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

-- Cache Blizzard frames
local FocusFrame = _G.FocusFrame
local FocusFrameHealthBar = _G.FocusFrameHealthBar
local FocusFrameManaBar = _G.FocusFrameManaBar
local FocusFramePortrait = _G.FocusFramePortrait
local FocusFrameTextureFrameName = _G.FocusFrameTextureFrameName
local FocusFrameTextureFrameLevelText = _G.FocusFrameTextureFrameLevelText
local FocusFrameNameBackground = _G.FocusFrameNameBackground

-- Texture paths (reutilizar del target)
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-",
    NAME_BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\TargetFrame\\NameBackground",
    BOSS = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x"
}

-- Boss classifications (mismas que target)
local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 80, 79, 4, 1},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125, 80, 79, 4, 1},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 99, 81, 13, 1}
}

-- Power types
local POWER_MAP = {
    [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy", [6] = "RunicPower"
}

-- Frame elements storage
local frameElements = {
    background = nil,
    border = nil,
    elite = nil
}

-- Update throttling
local updateCache = {
    lastHealthUpdate = 0,
    lastPowerUpdate = 0
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "focus") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.focus or {}
    return setmetatable(config, {__index = defaults})
end

-- ============================================================================
-- BAR MANAGEMENT
-- ============================================================================

local function SetupBarHooks()
    -- Health bar hooks
    if not FocusFrameHealthBar.DragonUI_Setup then
        local healthTexture = FocusFrameHealthBar:GetStatusBarTexture()
        if healthTexture then
            healthTexture:SetDrawLayer("ARTWORK", 1)
        end
        
        hooksecurefunc(FocusFrameHealthBar, "SetValue", function(self)
            if not UnitExists("focus") then return end
            
            local now = GetTime()
            if now - updateCache.lastHealthUpdate < 0.05 then return end
            updateCache.lastHealthUpdate = now
            
            local texture = self:GetStatusBarTexture()
            if not texture then return end
            
            -- Update texture
            local texturePath = TEXTURES.BAR_PREFIX .. "Health"
            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1)
            end
            
            -- Update coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current/max, 0, 1)
            end
            
            -- Update color
            local config = GetConfig()
            if config.classcolor and UnitIsPlayer("focus") then
                local _, class = UnitClass("focus")
                local color = RAID_CLASS_COLORS[class]
                if color then
                    texture:SetVertexColor(color.r, color.g, color.b)
                else
                    texture:SetVertexColor(1, 1, 1)
                end
            else
                texture:SetVertexColor(1, 1, 1)
            end
        end)
        
        FocusFrameHealthBar.DragonUI_Setup = true
    end
    
    -- Power bar hooks
    if not FocusFrameManaBar.DragonUI_Setup then
        local powerTexture = FocusFrameManaBar:GetStatusBarTexture()
        if powerTexture then
            powerTexture:SetDrawLayer("ARTWORK", 1)
        end
        
        hooksecurefunc(FocusFrameManaBar, "SetValue", function(self)
            if not UnitExists("focus") then return end
            
            local now = GetTime()
            if now - updateCache.lastPowerUpdate < 0.05 then return end
            updateCache.lastPowerUpdate = now
            
            local texture = self:GetStatusBarTexture()
            if not texture then return end
            
            -- Update texture based on power type
            local powerType = UnitPowerType("focus")
            local powerName = POWER_MAP[powerType] or "Mana"
            local texturePath = TEXTURES.BAR_PREFIX .. powerName
            
            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1)
            end
            
            -- Update coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current/max, 0, 1)
            end
            
            -- Force white color
            texture:SetVertexColor(1, 1, 1)
        end)
        
        FocusFrameManaBar.DragonUI_Setup = true
    end
end

-- ============================================================================
-- CLASSIFICATION SYSTEM
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("focus") or not frameElements.elite then
        if frameElements.elite then frameElements.elite:Hide() end
        return
    end
    
    local classification = UnitClassification("focus")
    local coords = nil
    
    -- Check vehicle first
    if UnitVehicleSeatCount and UnitVehicleSeatCount("focus") > 0 then
        frameElements.elite:Hide()
        return
    end
    
    -- Determine classification
    if classification == "worldboss" or classification == "elite" then
        coords = BOSS_COORDS.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDS.rare
    else
        local name = UnitName("focus")
        if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
            coords = BOSS_COORDS.elite
        end
    end
    
    if coords then
        frameElements.elite:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        frameElements.elite:SetSize(coords[5], coords[6])
        frameElements.elite:SetPoint("CENTER", FocusFramePortrait, "CENTER", coords[7], coords[8])
        frameElements.elite:Show()
    else
        frameElements.elite:Hide()
    end
end

-- ============================================================================
-- NAME BACKGROUND
-- ============================================================================

local function UpdateNameBackground()
    if not FocusFrameNameBackground then return end
    
    if not UnitExists("focus") then
        FocusFrameNameBackground:Hide()
        return
    end
    
    local r, g, b = UnitSelectionColor("focus")
    FocusFrameNameBackground:SetVertexColor(r or 0.5, g or 0.5, b or 0.5, 0.8)
    FocusFrameNameBackground:Show()
end

-- ============================================================================
-- FRAME INITIALIZATION
-- ============================================================================

local function InitializeFrame()
    if Module.configured then return end
    
    -- ✅ VERIFICAR QUE FOCUSFRAME EXISTE (solo en Wrath)
    if not FocusFrame then
        print("|cFFFF0000[DragonUI]|r FocusFrame not available in this WoW version")
        return
    end
    
    -- Hide Blizzard elements
    local toHide = {
        FocusFrameTextureFrameTexture,
        FocusFrameBackground,
        FocusFrameFlash
    }
    
    for _, element in ipairs(toHide) do
        if element then 
            element:SetAlpha(0)
            element:Hide()
        end
    end
    
    -- Create background texture
    if not frameElements.background then
        frameElements.background = FocusFrame:CreateTexture("DragonUI_FocusBG", "BACKGROUND", nil, -7)
        frameElements.background:SetTexture(TEXTURES.BACKGROUND)
        frameElements.background:SetPoint("TOPLEFT", FocusFrame, "TOPLEFT", 0, -8)
    end
    
    -- Create border texture
    if not frameElements.border then
        frameElements.border = FocusFrame:CreateTexture("DragonUI_FocusBorder", "OVERLAY", nil, 5)
        frameElements.border:SetTexture(TEXTURES.BORDER)
        frameElements.border:SetPoint("TOPLEFT", frameElements.background, "TOPLEFT", 0, 0)
    end
    
    -- Create elite decoration
    if not frameElements.elite then
        frameElements.elite = FocusFrame:CreateTexture("DragonUI_FocusElite", "OVERLAY", nil, 7)
        frameElements.elite:SetTexture(TEXTURES.BOSS)
        frameElements.elite:Hide()
    end
    
    -- Configure name background
    if FocusFrameNameBackground then
        FocusFrameNameBackground:ClearAllPoints()
        FocusFrameNameBackground:SetPoint("BOTTOMLEFT", FocusFrameHealthBar, "TOPLEFT", -2, -5)
        FocusFrameNameBackground:SetSize(135, 18)
        FocusFrameNameBackground:SetTexture(TEXTURES.NAME_BACKGROUND)
        FocusFrameNameBackground:SetDrawLayer("BORDER", 1)
        FocusFrameNameBackground:SetBlendMode("ADD")
        FocusFrameNameBackground:SetAlpha(0.9)
    end
    
    -- Configure portrait
    FocusFramePortrait:ClearAllPoints()
    FocusFramePortrait:SetSize(56, 56)
    FocusFramePortrait:SetPoint("TOPRIGHT", FocusFrame, "TOPRIGHT", -47, -15)
    FocusFramePortrait:SetDrawLayer("ARTWORK", 1)
    
    -- Configure health bar
    FocusFrameHealthBar:ClearAllPoints()
    FocusFrameHealthBar:SetSize(125, 20)
    FocusFrameHealthBar:SetPoint("RIGHT", FocusFramePortrait, "LEFT", -1, 0)
    FocusFrameHealthBar:SetFrameLevel(FocusFrame:GetFrameLevel())
    
    -- Configure power bar
    FocusFrameManaBar:ClearAllPoints()
    FocusFrameManaBar:SetSize(132, 9)
    FocusFrameManaBar:SetPoint("RIGHT", FocusFramePortrait, "LEFT", 6.5, -16.5)
    FocusFrameManaBar:SetFrameLevel(FocusFrame:GetFrameLevel())
    
    -- Configure text elements
    if FocusFrameTextureFrameName then
        FocusFrameTextureFrameName:ClearAllPoints()
        FocusFrameTextureFrameName:SetPoint("BOTTOM", FocusFrameHealthBar, "TOP", 10, 1)
        FocusFrameTextureFrameName:SetDrawLayer("OVERLAY", 2)
    end
    
    if FocusFrameTextureFrameLevelText then
        FocusFrameTextureFrameLevelText:ClearAllPoints()
        FocusFrameTextureFrameLevelText:SetPoint("BOTTOMRIGHT", FocusFrameHealthBar, "TOPLEFT", 16, 1)
        FocusFrameTextureFrameLevelText:SetDrawLayer("OVERLAY", 2)
    end
    
    -- Setup bar hooks
    SetupBarHooks()
    
    -- Apply configuration
    local config = GetConfig()
    
    FocusFrame:ClearAllPoints()
    FocusFrame:SetClampedToScreen(false)
    FocusFrame:SetScale(config.scale or 1)
    
    if config.override then
        FocusFrame:SetPoint(config.anchor or "TOPLEFT", UIParent, 
                           config.anchorParent or "TOPLEFT", config.x or 400, config.y or -250)
    else
        local defaults = addon.defaults and addon.defaults.profile.unitframe.focus or {}
        FocusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 
                           defaults.x or 400, defaults.y or -250)
    end
    
    -- Setup text system
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and addon.TextSystem and not Module.textSystem then
        Module.textSystem = addon.TextSystem.SetupFrameTextSystem(
            "focus", "focus", dragonFrame,
            FocusFrameHealthBar, FocusFrameManaBar, "FocusFrame"
        )
    end
    
    Module.configured = true
    print("|cFF00FF00[DragonUI]|r FocusFrame configured successfully")
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.focusFrame = CreateFrame("Frame", "DragonUI_FocusFrame_Anchor", UIParent)
            Module.focusFrame:SetSize(192, 67)
            Module.focusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -250)
            Module.initialized = true
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        if UnitExists("focus") then
            UpdateNameBackground()
            UpdateClassification()
        end
        
    elseif event == "PLAYER_FOCUS_CHANGED" then
        UpdateNameBackground()
        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end
        
    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        local unit = ...
        if unit == "focus" then
            UpdateClassification()
        end
        
    elseif event == "UNIT_FACTION" then
        local unit = ...
        if unit == "focus" then
            UpdateNameBackground()
        end
    end
end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_FACTION")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end
    
    if UnitExists("focus") then
        UpdateNameBackground()
        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

local function ResetFrame()
    local defaults = addon.defaults and addon.defaults.profile.unitframe.focus or {}
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "focus", key, value)
    end
    
    local config = GetConfig()
    FocusFrame:ClearAllPoints()
    FocusFrame:SetScale(config.scale or 1)
    FocusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 
                       defaults.x or 400, defaults.y or -250)
end

-- Export API
addon.FocusFrame = {
    Refresh = RefreshFrame,
    RefreshFocusFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function() return Module.focusFrame end,
    ChangeFocusFrame = RefreshFrame
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeFocusFrame = RefreshFrame
addon.unitframe.ReApplyFocusFrame = RefreshFrame

function addon:RefreshFocusFrame()
    RefreshFrame()
end

print("|cFF00FF00[DragonUI]|r Focus module loaded and optimized v1.0")