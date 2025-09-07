local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI TARGET FRAME MODULE - Optimized for WoW 3.3.5a
-- ============================================================================

-- Module namespace
local Module = {
    targetFrame = nil,
    textSystem = nil,
    initialized = false,
    eventsFrame = nil
}

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

-- Cache frequently accessed globals
local TargetFrame = _G.TargetFrame
local TargetFrameHealthBar = _G.TargetFrameHealthBar
local TargetFrameManaBar = _G.TargetFrameManaBar
local TargetFramePortrait = _G.TargetFramePortrait
local TargetFrameTextureFrameName = _G.TargetFrameTextureFrameName
local TargetFrameTextureFrameLevelText = _G.TargetFrameTextureFrameLevelText
local TargetFrameNameBackground = _G.TargetFrameNameBackground

-- Texture paths
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-",
    NAME_BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\TargetFrame\\NameBackground",
    BOSS = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x",
    THREAT = "Interface\\Addons\\DragonUI\\Textures\\UI\\UnitFrame",
    THREAT_NUMERIC = "Interface\\Addons\\DragonUI\\Textures\\uiunitframe"
}

-- Boss classifications
local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 80, 79, 4, 1},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125, 80, 79, 4, 1},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 99, 81, 13, 1}
}

-- Power types
local POWER_MAP = {
    [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy", [6] = "RunicPower"
}

-- Threat colors
local THREAT_COLORS = {
    {1.0, 1.0, 0.47}, -- Low
    {1.0, 0.6, 0.0},  -- Medium
    {1.0, 0.0, 0.0}   -- High
}

-- Event categories
local EVENT_CATEGORIES = {
    health = {"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEALTH_FREQUENT"},
    power = {"UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE", "UNIT_MAXRAGE", 
             "UNIT_ENERGY", "UNIT_MAXENERGY", "UNIT_FOCUS", "UNIT_MAXFOCUS",
             "UNIT_RUNIC_POWER", "UNIT_MAXRUNIC_POWER", "UNIT_DISPLAYPOWER"},
    both = {"UNIT_PORTRAIT_UPDATE", "UNIT_AURA", "UNIT_FACTION"}
}

-- Frame elements storage
local frameElements = {
    background = nil,
    border = nil,
    elite = nil,
    threatGlow = nil,
    threatNumeric = nil
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "target") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    return setmetatable(config, {__index = defaults})
end

local function SafeCall(func, ...)
    if not func then return end
    local success, result = pcall(func, ...)
    if not success then
        print("|cFFFF0000[DragonUI]|r Error:", result)
    end
    return success, result
end

local function IsInTransition()
    return not UnitExists or not UnitExists("player")
end

-- ============================================================================
-- BAR MANAGEMENT
-- ============================================================================

local function UpdateBar(bar, barType, unit)
    if not bar or not UnitExists(unit) then return end
    
    local texture = bar:GetStatusBarTexture()
    if not texture then return end
    
    -- Set appropriate texture
    local texturePath = TEXTURES.BAR_PREFIX .. (barType == "health" and "Health" or 
                        (POWER_MAP[UnitPowerType(unit)] or "Mana"))
    texture:SetTexture(texturePath)
    texture:SetDrawLayer("BORDER", 1)
    
    -- Dynamic texture clipping
    local min, max = bar:GetMinMaxValues()
    local current = bar:GetValue()
    if max > 0 and current then
        texture:SetTexCoord(0, current/max, 0, 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
    
    -- Color handling
    if barType == "health" then
        local config = GetConfig()
        if config.classcolor and UnitIsPlayer(unit) then
            local _, class = UnitClass(unit)
            local color = RAID_CLASS_COLORS[class]
            if color then
                texture:SetVertexColor(color.r, color.g, color.b)
                return
            end
        end
    else
        bar:SetStatusBarColor(1, 1, 1, 1)
    end
    texture:SetVertexColor(1, 1, 1)
end

-- ============================================================================
-- THREAT SYSTEM
-- ============================================================================

local function GetThreatLevel(unit)
    if not UnitExists(unit) then return 0 end
    local status = UnitThreatSituation("player", unit)
    return status and math.min(status, 3) or 0
end

local function UpdateThreat()
    if not UnitExists("target") then
        if frameElements.threatGlow then frameElements.threatGlow:Hide() end
        if frameElements.threatNumeric then frameElements.threatNumeric:Hide() end
        return
    end
    
    local success, level = SafeCall(GetThreatLevel, "target")
    if not success then return end
    
    local _, _, _, pct = UnitDetailedThreatSituation("player", "target")
    
    -- Update glow
    if frameElements.threatGlow and level > 0 then
        local color = THREAT_COLORS[level]
        frameElements.threatGlow.texture:SetVertexColor(color[1], color[2], color[3], 0.8)
        frameElements.threatGlow:Show()
    elseif frameElements.threatGlow then
        frameElements.threatGlow:Hide()
    end
    
    -- Update numeric with proper bounds checking
    if frameElements.threatNumeric and pct and pct > 0 then
        local color = THREAT_COLORS[level] or {1, 1, 1}
        -- ✅ Asegurar que el valor esté en rango 0-100
        local displayPct = math.max(0, math.min(100, math.floor(pct)))
        frameElements.threatNumeric.text:SetText(displayPct .. "%")
        frameElements.threatNumeric.text:SetTextColor(color[1], color[2], color[3])
        frameElements.threatNumeric:Show()
    elseif frameElements.threatNumeric then
        frameElements.threatNumeric:Hide()
    end
end

-- ============================================================================
-- CLASSIFICATION SYSTEM
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("target") or not frameElements.elite then
        if frameElements.elite then frameElements.elite:Hide() end
        return
    end
    
    -- Handle vehicles
    if UnitVehicleSeatCount and UnitVehicleSeatCount("target") > 0 then
        TargetFrameHealthBar:SetSize(116, 20)
        TargetFrameManaBar:SetSize(123, 10)
        if TargetFrameTextureFrameName then
            TargetFrameTextureFrameName:SetPoint("CENTER", -20, 26)
        end
        if TargetFrameTextureFrameLevelText then
            TargetFrameTextureFrameLevelText:SetPoint("CENTER", -80, 26)
        end
        frameElements.elite:Hide()
        return
    end
    
    -- Restore normal sizes
    TargetFrameHealthBar:SetSize(125, 20)
    TargetFrameManaBar:SetSize(132, 9)
    if TargetFrameTextureFrameName then
        TargetFrameTextureFrameName:SetPoint("BOTTOM", TargetFrameHealthBar, "TOP", 10, 1)
    end
    if TargetFrameTextureFrameLevelText then
        TargetFrameTextureFrameLevelText:SetPoint("BOTTOMRIGHT", TargetFrameHealthBar, "TOPLEFT", 16, 1)
    end
    
    -- Determine classification
    local classification = UnitClassification("target")
    local coords = nil
    
    if classification == "worldboss" or classification == "elite" then
        coords = BOSS_COORDS.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDS.rare
    else
        local name = UnitName("target")
        if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
            coords = BOSS_COORDS.elite
        end
    end
    
    if coords then
        frameElements.elite:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        frameElements.elite:SetSize(coords[5], coords[6])
        frameElements.elite:SetPoint("CENTER", TargetFramePortrait, "CENTER", coords[7], coords[8])
        frameElements.elite:Show()
    else
        frameElements.elite:Hide()
    end
end

-- ============================================================================
-- NAME BACKGROUND
-- ============================================================================

local function UpdateNameBackground()
    if not UnitExists("target") or not TargetFrameNameBackground then
        if TargetFrameNameBackground then TargetFrameNameBackground:Hide() end
        return
    end
    
    local r, g, b = UnitSelectionColor("target")
    TargetFrameNameBackground:SetVertexColor(r or 0.5, g or 0.5, b or 0.5, 0.8)
    TargetFrameNameBackground:Show()
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

local function CreateFrameElements()
    if frameElements.background then return end
    
    -- Hide Blizzard elements
    local toHide = {TargetFrameTextureFrameTexture, TargetFrameBackground, TargetFrameFlash,
                    _G.TargetFrameNumericalThreat, TargetFrame.threatNumericIndicator,
                    TargetFrame.threatIndicator}
    for _, element in ipairs(toHide) do
        if element then element:SetAlpha(0) end
    end
    
    -- Background
    frameElements.background = TargetFrame:CreateTexture("DragonUI_TargetBG", "BACKGROUND", nil, 0)
    frameElements.background:SetTexture(TEXTURES.BACKGROUND)
    frameElements.background:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 0, -8)
    
    -- Border
    frameElements.border = TargetFrame:CreateTexture("DragonUI_TargetBorder", "OVERLAY", nil, 5)
    frameElements.border:SetTexture(TEXTURES.BORDER)
    frameElements.border:SetPoint("TOPLEFT", frameElements.background, "TOPLEFT", 0, 0)
    
    -- Elite decoration
    frameElements.elite = TargetFrame:CreateTexture("DragonUI_TargetElite", "OVERLAY", nil, 7)
    frameElements.elite:SetTexture(TEXTURES.BOSS)
    frameElements.elite:SetDrawLayer("OVERLAY", 7)
    frameElements.elite:Hide()
    
    -- Name background setup
    if TargetFrameNameBackground then
        TargetFrameNameBackground:ClearAllPoints()
        TargetFrameNameBackground:SetPoint("BOTTOMLEFT", TargetFrameHealthBar, "TOPLEFT", -2, -5)
        TargetFrameNameBackground:SetSize(135, 18)
        TargetFrameNameBackground:SetTexture(TEXTURES.NAME_BACKGROUND)
        TargetFrameNameBackground:SetDrawLayer("BORDER")
        TargetFrameNameBackground:SetBlendMode("ADD")
        TargetFrameNameBackground:SetAlpha(0.9)
    end
    
    -- Create threat system
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and not dragonFrame.TargetThreatGlow then
        -- Threat glow
        local glow = CreateFrame("Frame", "DragonUITargetThreatGlow", UIParent)
        glow:SetFrameStrata("MEDIUM")
        glow:SetSize(209, 90)
        glow:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 0, 5)
        glow:Hide()
        
        glow.texture = glow:CreateTexture(nil, "OVERLAY")
        glow.texture:SetTexture(TEXTURES.THREAT)
        glow.texture:SetTexCoord(0, 0.2061015625, 0.537109375, 0.712890625)
        glow.texture:SetAllPoints()
        glow.texture:SetBlendMode("ADD")
        
        frameElements.threatGlow = glow
        dragonFrame.TargetThreatGlow = glow
        
        -- Threat numeric
        local numeric = CreateFrame("Frame", "DragonUITargetNumericalThreat", UIParent)
        numeric:SetFrameStrata("MEDIUM")
        numeric:SetFrameLevel(999)
        numeric:SetSize(71, 13)
        numeric:SetPoint("BOTTOM", TargetFrame, "TOP", -45, -20)
        numeric:Hide()
        
        local bg = numeric:CreateTexture(nil, "ARTWORK")
        bg:SetTexture(TEXTURES.THREAT_NUMERIC)
        bg:SetTexCoord(0.927734375, 0.9970703125, 0.3125, 0.337890625)
        bg:SetAllPoints()
        
        numeric.text = numeric:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        numeric.text:SetPoint("CENTER")
        numeric.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
        numeric.text:SetShadowOffset(1, -1)
        
        frameElements.threatNumeric = numeric
        dragonFrame.TargetNumericalThreat = numeric
    end
end

local function ConfigureFrame()
    if not TargetFrame then return end
    
    -- Portrait
    TargetFramePortrait:ClearAllPoints()
    TargetFramePortrait:SetSize(56, 56)
    TargetFramePortrait:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -47, -15)
    TargetFramePortrait:SetDrawLayer("ARTWORK", 1)
    
    -- Health bar
    TargetFrameHealthBar:ClearAllPoints()
    TargetFrameHealthBar:SetSize(125, 20)
    TargetFrameHealthBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", -1, 0)
    
    if not TargetFrameHealthBar.DragonUI_Hooked then
        TargetFrameHealthBar:HookScript("OnValueChanged", function(self)
            if UnitExists("target") then
                UpdateBar(self, "health", "target")
            end
        end)
        TargetFrameHealthBar:HookScript("OnShow", function(self)
            UpdateBar(self, "health", "target")
        end)
        TargetFrameHealthBar:HookScript("OnUpdate", function(self)
            UpdateBar(self, "health", "target")
        end)
        TargetFrameHealthBar.DragonUI_Hooked = true
    end
    
    -- Power bar
    TargetFrameManaBar:ClearAllPoints()
    TargetFrameManaBar:SetSize(132, 9)
    TargetFrameManaBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", 6.5, -16.5)
    
    if not TargetFrameManaBar.DragonUI_Hooked then
        TargetFrameManaBar:HookScript("OnValueChanged", function(self)
            if UnitExists("target") then
                UpdateBar(self, "power", "target")
            end
        end)
        TargetFrameManaBar:HookScript("OnShow", function(self)
            UpdateBar(self, "power", "target")
        end)
        
        -- Harden power bar
        local origSetTexture = TargetFrameManaBar.SetStatusBarTexture
        if origSetTexture then
            TargetFrameManaBar.SetStatusBarTexture = function(self, tex)
                origSetTexture(self, tex)
                UpdateBar(self, "power", "target")
            end
        end
        
        local origSetColor = TargetFrameManaBar.SetStatusBarColor
        if origSetColor then
            TargetFrameManaBar.SetStatusBarColor = function(self, r, g, b, a)
                origSetColor(self, 1, 1, 1, a or 1)
                local texture = self:GetStatusBarTexture()
                if texture then texture:SetVertexColor(1, 1, 1) end
            end
        end
        
        TargetFrameManaBar.DragonUI_Hooked = true
    end
    
    -- Text positioning
    if TargetFrameTextureFrameName then
        TargetFrameTextureFrameName:ClearAllPoints()
        TargetFrameTextureFrameName:SetPoint("BOTTOM", TargetFrameHealthBar, "TOP", 10, 1)
    end
    
    if TargetFrameTextureFrameLevelText then
        TargetFrameTextureFrameLevelText:ClearAllPoints()
        TargetFrameTextureFrameLevelText:SetPoint("BOTTOMRIGHT", TargetFrameHealthBar, "TOPLEFT", 16, 1)
    end
end

local function ApplyConfig()
    local config = GetConfig()
    
    TargetFrame:ClearAllPoints()
    TargetFrame:SetClampedToScreen(false)
    TargetFrame:SetScale(config.scale or 1)
    
    if config.override then
        TargetFrame:SetPoint(config.anchor or "TOPLEFT", UIParent, 
                            config.anchorParent or "TOPLEFT", config.x or 20, config.y or -4)
    else
        local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
        TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 
                            defaults.x or 20, defaults.y or -4)
    end
    
    -- Setup text system
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and addon.TextSystem and not Module.textSystem then
        Module.textSystem = addon.TextSystem.SetupFrameTextSystem(
            "target", "target", dragonFrame,
            TargetFrameHealthBar, TargetFrameManaBar, "TargetFrame"
        )
    end
    
    if Module.textSystem then
        Module.textSystem.update()
    end
end

-- ============================================================================
-- UPDATE FUNCTIONS
-- ============================================================================

local function UpdateAll()
    if not UnitExists("target") then
        UpdateNameBackground()
        if frameElements.elite then frameElements.elite:Hide() end
        return
    end
    
    UpdateBar(TargetFrameHealthBar, "health", "target")
    UpdateBar(TargetFrameManaBar, "power", "target")
    UpdateNameBackground()
    UpdateClassification()
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function InitializeEvents()
    if Module.eventsFrame then return end
    
    local f = CreateFrame("Frame")
    Module.eventsFrame = f
    
    local handlers = {
        ADDON_LOADED = function(name)
            if name == "DragonUI" and not Module.initialized then
                Module.targetFrame = CreateFrame("Frame", "DragonUI_TargetFrame_Anchor", UIParent)
                Module.targetFrame:SetSize(192, 67)
                Module.targetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -50)
                Module.initialized = true
            end
        end,
        
        PLAYER_ENTERING_WORLD = function()
            CreateFrameElements()
            ConfigureFrame()
            ApplyConfig()
            if UnitExists("target") then UpdateAll() end
        end,
        
        PLAYER_TARGET_CHANGED = function()
            if IsInTransition() then return end
            SafeCall(function()
                UpdateAll()
                UpdateThreat()
            end)
        end,
        
        UNIT_CLASSIFICATION_CHANGED = function(unit)
            if unit == "target" then
                UpdateClassification()
                UpdateNameBackground()
            end
        end,
        
        UNIT_THREAT_SITUATION_UPDATE = function(unit)
            if unit == "target" and not IsInTransition() then
                SafeCall(UpdateThreat)
            end
        end,
        
        UNIT_THREAT_LIST_UPDATE = function(unit)
            if unit == "target" and not IsInTransition() then
                SafeCall(UpdateThreat)
            end
        end,
        
        PLAYER_REGEN_DISABLED = function()
            if not IsInTransition() and UnitExists("target") then
                SafeCall(UpdateAll)
            end
        end,
        
        PLAYER_REGEN_ENABLED = function()
            if not IsInTransition() and UnitExists("target") then
                SafeCall(UpdateAll)
            end
        end,
        
        UNIT_FACTION = function(unit)
            if unit == "target" then UpdateNameBackground() end
        end
    }
    
    -- Register events
    for event in pairs(handlers) do
        f:RegisterEvent(event)
    end
    
    for _, category in pairs(EVENT_CATEGORIES) do
        for _, event in ipairs(category) do
            f:RegisterEvent(event)
        end
    end
    
    f:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    
    -- Event dispatcher
    f:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then
            handler(...)
            return
        end
        
        local unit = ...
        if unit ~= "target" then return end
        
        -- Check event categories
        for _, evt in ipairs(EVENT_CATEGORIES.health) do
            if event == evt then
                UpdateBar(TargetFrameHealthBar, "health", "target")
                return
            end
        end
        
        for _, evt in ipairs(EVENT_CATEGORIES.power) do
            if event == evt then
                UpdateBar(TargetFrameManaBar, "power", "target")
                return
            end
        end
        
        for _, evt in ipairs(EVENT_CATEGORIES.both) do
            if event == evt then
                UpdateAll()
                return
            end
        end
    end)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local function RefreshFrame()
    CreateFrameElements()
    ConfigureFrame()
    ApplyConfig()
    if Module.textSystem then Module.textSystem.update() end
end

local function ResetFrame()
    local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "target", key, value)
    end
    ApplyConfig()
end

-- Initialize
InitializeEvents()

-- Export API
addon.TargetFrame = {
    Refresh = RefreshFrame,
    RefreshTargetFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function() return Module.targetFrame end,
    ChangeTargetFrame = RefreshFrame,
    CreateTargetFrameTextures = CreateFrameElements
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeTargetFrame = RefreshFrame
addon.unitframe.ReApplyTargetFrame = RefreshFrame

function addon:RefreshTargetFrame()
    RefreshFrame()
end

print("|cFF00FF00[DragonUI]|r Target module loaded and optimized")