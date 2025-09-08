local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI TARGET FRAME MODULE - Optimized for WoW 3.3.5a
-- ============================================================================

-- Module namespace
local Module = {
    targetFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
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
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- Threat colors
local THREAT_COLORS = {{1.0, 1.0, 0.47}, -- Low
{1.0, 0.6, 0.0}, -- Medium
{1.0, 0.0, 0.0} -- High
}

-- Frame elements storage
local frameElements = {
    background = nil,
    border = nil,
    elite = nil,
    threatNumeric = nil
}

-- Cache for update throttling
local updateCache = {
    lastHealthUpdate = 0,
    lastPowerUpdate = 0
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "target") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    return setmetatable(config, {
        __index = defaults
    })
end

local function SafeCall(func, ...)
    if not func then
        return
    end
    local success, result = pcall(func, ...)
    if not success then
        print("|cFFFF0000[DragonUI]|r Error:", result)
    end
    return success, result
end

-- ============================================================================
-- BAR MANAGEMENT (Optimized)
-- ============================================================================

local function SetupBarHooks()
    -- Setup health bar hooks ONCE
    if not TargetFrameHealthBar.DragonUI_Setup then
        local healthTexture = TargetFrameHealthBar:GetStatusBarTexture()
        if healthTexture then
            healthTexture:SetDrawLayer("ARTWORK", 1) -- Cambiado de "BORDER", 1
        end

        hooksecurefunc(TargetFrameHealthBar, "SetValue", function(self)
            if not UnitExists("target") then
                return
            end

            local now = GetTime()
            if now - updateCache.lastHealthUpdate < 0.05 then
                return
            end
            updateCache.lastHealthUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            -- Update texture path if needed
            local texturePath = TEXTURES.BAR_PREFIX .. "Health"
            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1) -- Asegurar layer correcto
            end

            -- Update texture coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end

            -- Update color
            local config = GetConfig()
            if config.classcolor and UnitIsPlayer("target") then
                local _, class = UnitClass("target")
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

        TargetFrameHealthBar.DragonUI_Setup = true
    end

    -- Setup power bar hooks ONCE
    if not TargetFrameManaBar.DragonUI_Setup then
        local powerTexture = TargetFrameManaBar:GetStatusBarTexture()
        if powerTexture then
            powerTexture:SetDrawLayer("ARTWORK", 1) -- Cambiado de "BORDER", 1
        end

        hooksecurefunc(TargetFrameManaBar, "SetValue", function(self)
            if not UnitExists("target") then
                return
            end

            local now = GetTime()
            if now - updateCache.lastPowerUpdate < 0.05 then
                return
            end
            updateCache.lastPowerUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            -- Update texture path based on power type
            local powerType = UnitPowerType("target")
            local powerName = POWER_MAP[powerType] or "Mana"
            local texturePath = TEXTURES.BAR_PREFIX .. powerName

            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1) -- Asegurar layer correcto
            end

            -- Update texture coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end

            -- Force white color
            texture:SetVertexColor(1, 1, 1)
        end)

        -- Override SetStatusBarColor to prevent color changes
        local origSetColor = TargetFrameManaBar.SetStatusBarColor
        TargetFrameManaBar.SetStatusBarColor = function(self, r, g, b, a)
            origSetColor(self, 1, 1, 1, 1)
        end

        TargetFrameManaBar.DragonUI_Setup = true
    end
end

-- ============================================================================
-- THREAT SYSTEM (Optimized)
-- ============================================================================

local function UpdateThreat()
    if not UnitExists("target") then
        if frameElements.threatNumeric then
            frameElements.threatNumeric:Hide()
        end
        return
    end

    local status = UnitThreatSituation("player", "target")
    local level = status and math.min(status, 3) or 0

    if level > 0 then
        -- Solo numerical threat
        local _, _, _, pct = UnitDetailedThreatSituation("player", "target")

        if frameElements.threatNumeric and pct and pct > 0 then
            local displayPct = math.floor(math.min(100, math.max(0, pct)))
            frameElements.threatNumeric.text:SetText(displayPct .. "%")
            -- Color fijo o basado en level
            if level == 1 then
                frameElements.threatNumeric.text:SetTextColor(1.0, 1.0, 0.47) -- Amarillo
            elseif level == 2 then
                frameElements.threatNumeric.text:SetTextColor(1.0, 0.6, 0.0) -- Naranja
            else
                frameElements.threatNumeric.text:SetTextColor(1.0, 0.0, 0.0) -- Rojo
            end
            frameElements.threatNumeric:Show()
        else
            if frameElements.threatNumeric then
                frameElements.threatNumeric:Hide()
            end
        end
    else
        -- Ocultar numeric
        if frameElements.threatNumeric then
            frameElements.threatNumeric:Hide()
        end
    end
end

-- ============================================================================
-- CLASSIFICATION SYSTEM (Optimized)
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("target") or not frameElements.elite then
        if frameElements.elite then
            frameElements.elite:Hide()
        end
        return
    end

    local classification = UnitClassification("target")
    local coords = nil

    -- Check vehicle first
    if UnitVehicleSeatCount and UnitVehicleSeatCount("target") > 0 then
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
-- NAME BACKGROUND (Optimized)
-- ============================================================================

local function UpdateNameBackground()
    if not TargetFrameNameBackground then
        return
    end

    if not UnitExists("target") then
        TargetFrameNameBackground:Hide()
        return
    end

    local r, g, b = UnitSelectionColor("target")
    TargetFrameNameBackground:SetVertexColor(r or 0.5, g or 0.5, b or 0.5, 0.8)
    TargetFrameNameBackground:Show()
end

-- ============================================================================
-- ONE-TIME INITIALIZATION
-- ============================================================================
local threatPulseAnimation = nil
local function TargetFrame_CheckClassification_Hook(self, forceNormalTexture)
    -- INTERCEPTAR INMEDIATAMENTE - antes que Blizzard
    local threatFlash = _G.TargetFrameFlash
    if threatFlash then
        -- PARAR cualquier animación de Blizzard
        if threatFlash.animOut then threatFlash.animOut:Stop() end
        if threatFlash.animIn then threatFlash.animIn:Stop() end
        
        -- APLICAR NUESTRAS CONFIGURACIONES INMEDIATAMENTE
        threatFlash:SetTexture(TEXTURES.THREAT)
        threatFlash:SetTexCoord(211/1024, 421/1024, 0/512, 89/512)
        threatFlash:SetBlendMode("ADD")
        threatFlash:SetAlpha(0.6)
        
        -- FORZAR tamaño y posición ANTES de que Blizzard haga cambios
        threatFlash:ClearAllPoints()
        threatFlash:SetPoint("BOTTOMLEFT", TargetFrame, "BOTTOMLEFT", -3, 14.5)
        threatFlash:SetSize(214, 91)
        
        -- CREAR NUESTRO EFECTO PULSANTE (solo una vez)
        if not threatFlash.dragonPulseGroup then
            threatFlash.dragonPulseGroup = threatFlash:CreateAnimationGroup()
            threatFlash.dragonPulseGroup:SetLooping("BOUNCE")
            
            local scaleAnim = threatFlash.dragonPulseGroup:CreateAnimation("Scale")
            scaleAnim:SetOrigin("CENTER", 0, 0)
            scaleAnim:SetScale(1.05, 1.05)  -- Escala MUY pequeña
            scaleAnim:SetDuration(1.2)      -- Más lento
            scaleAnim:SetSmoothing("IN_OUT")
            
            local alphaAnim = threatFlash.dragonPulseGroup:CreateAnimation("Alpha")
            alphaAnim:SetChange(-0.1)       -- Cambio muy muy sutil
            alphaAnim:SetDuration(1.2)
            alphaAnim:SetSmoothing("IN_OUT")
        end
        
        -- Control de nuestra animación
        local hasThreat = UnitThreatSituation("player", "target") and UnitThreatSituation("player", "target") > 0
        
        if hasThreat then
            if not threatFlash.dragonPulseGroup:IsPlaying() then
                threatFlash:SetAlpha(0.6)
                threatFlash.dragonPulseGroup:Play()
            end
        else
            if threatFlash.dragonPulseGroup:IsPlaying() then
                threatFlash.dragonPulseGroup:Stop()
                threatFlash:SetAlpha(0.6)
            end
        end
    end
end
local function InitializeFrame()
    if Module.configured then
        return
    end

    -- Hide Blizzard elements ONCE
    local toHide =
        {TargetFrameTextureFrameTexture, TargetFrameBackground, _G.TargetFrameNumericalThreat 
        }

    for _, element in ipairs(toHide) do
        if element then
            element:SetAlpha(0)
            element:Hide()
        end
    end

    -- Hook la función que resetea el threat indicator
    if not Module.threatHooked then
        hooksecurefunc("TargetFrame_CheckClassification", TargetFrame_CheckClassification_Hook)
        Module.threatHooked = true
    end

    -- Create background texture ONCE
    if not frameElements.background then
        frameElements.background = TargetFrame:CreateTexture("DragonUI_TargetBG", "BACKGROUND", nil, -7)
        frameElements.background:SetTexture(TEXTURES.BACKGROUND)
        frameElements.background:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 0, -8)

    end

    -- Create border texture ONCE
    if not frameElements.border then
        frameElements.border = TargetFrame:CreateTexture("DragonUI_TargetBorder", "OVERLAY", nil, 5)
        frameElements.border:SetTexture(TEXTURES.BORDER)
        frameElements.border:SetPoint("TOPLEFT", frameElements.background, "TOPLEFT", 0, 0)
    end

    -- Create elite decoration ONCE
    if not frameElements.elite then
        frameElements.elite = TargetFrame:CreateTexture("DragonUI_TargetElite", "OVERLAY", nil, 7)
        frameElements.elite:SetTexture(TEXTURES.BOSS)
        frameElements.elite:Hide()
    end

    -- Configure name background ONCE
    if TargetFrameNameBackground then
        TargetFrameNameBackground:ClearAllPoints()
        TargetFrameNameBackground:SetPoint("BOTTOMLEFT", TargetFrameHealthBar, "TOPLEFT", -2, -5)
        TargetFrameNameBackground:SetSize(135, 18)
        TargetFrameNameBackground:SetTexture(TEXTURES.NAME_BACKGROUND)
        TargetFrameNameBackground:SetDrawLayer("BORDER", 1)
        TargetFrameNameBackground:SetBlendMode("ADD")
        TargetFrameNameBackground:SetAlpha(0.9)
    end

    -- Configure portrait ONCE
    TargetFramePortrait:ClearAllPoints()
    TargetFramePortrait:SetSize(56, 56)
    TargetFramePortrait:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -47, -15)
    TargetFramePortrait:SetDrawLayer("ARTWORK", 1)

    -- Configure health bar ONCE
    TargetFrameHealthBar:ClearAllPoints()
    TargetFrameHealthBar:SetSize(125, 20)
    TargetFrameHealthBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", -1, 0)
    TargetFrameHealthBar:SetFrameLevel(TargetFrame:GetFrameLevel())

    -- Configure power bar ONCE
    TargetFrameManaBar:ClearAllPoints()
    TargetFrameManaBar:SetSize(132, 9)
    TargetFrameManaBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", 6.5, -16.5)
    TargetFrameManaBar:SetFrameLevel(TargetFrame:GetFrameLevel())

    -- Configure text elements ONCE
    if TargetFrameTextureFrameName then
        TargetFrameTextureFrameName:ClearAllPoints()
        TargetFrameTextureFrameName:SetPoint("BOTTOM", TargetFrameHealthBar, "TOP", 10, 1)
        TargetFrameTextureFrameName:SetDrawLayer("OVERLAY", 2)
    end

    if TargetFrameTextureFrameLevelText then
        TargetFrameTextureFrameLevelText:ClearAllPoints()
        TargetFrameTextureFrameLevelText:SetPoint("BOTTOMRIGHT", TargetFrameHealthBar, "TOPLEFT", 16, 1)
        TargetFrameTextureFrameLevelText:SetDrawLayer("OVERLAY", 2)
    end

    -- Setup bar hooks ONCE
    SetupBarHooks()

    if not frameElements.threatNumeric then
        local numeric = CreateFrame("Frame", "DragonUITargetNumericalThreat", TargetFrame)
        numeric:SetFrameStrata("HIGH")
        numeric:SetFrameLevel(TargetFrame:GetFrameLevel() + 10)
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
    end

    -- Apply configuration
    local config = GetConfig()

    TargetFrame:ClearAllPoints()
    TargetFrame:SetClampedToScreen(false)
    TargetFrame:SetScale(config.scale or 1)

    if config.override then
        TargetFrame:SetPoint(config.anchor or "TOPLEFT", UIParent, config.anchorParent or "TOPLEFT", config.x or 20,
            config.y or -4)
    else
        local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
        TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", defaults.x or 20, defaults.y or -4)
    end

    -- Setup text system ONCE
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and addon.TextSystem and not Module.textSystem then
        Module.textSystem = addon.TextSystem.SetupFrameTextSystem("target", "target", dragonFrame, TargetFrameHealthBar,
            TargetFrameManaBar, "TargetFrame")
    end

    Module.configured = true
end

-- ============================================================================
-- EVENT HANDLING (Simplified)
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.targetFrame = CreateFrame("Frame", "DragonUI_TargetFrame_Anchor", UIParent)
            Module.targetFrame:SetSize(192, 67)
            Module.targetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -50)
            Module.initialized = true
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        if UnitExists("target") then
            UpdateNameBackground()
            UpdateClassification()
            UpdateThreat()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateNameBackground()
        UpdateClassification()
        UpdateThreat()
        if Module.textSystem then
            Module.textSystem.update()
        end

    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        local unit = ...
        if unit == "target" then
            UpdateClassification()
        end

    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        UpdateThreat()

    elseif event == "UNIT_FACTION" then
        local unit = ...
        if unit == "target" then
            UpdateNameBackground()
        end
    end
end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_FACTION")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API (Simplified)
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end

    -- Only update dynamic content
    if UnitExists("target") then
        UpdateNameBackground()
        UpdateClassification()
        UpdateThreat()
        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

local function ResetFrame()
    local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "target", key, value)
    end

    -- Re-apply position only
    local config = GetConfig()
    TargetFrame:ClearAllPoints()
    TargetFrame:SetScale(config.scale or 1)
    TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", defaults.x or 20, defaults.y or -4)
end

-- Export API
addon.TargetFrame = {
    Refresh = RefreshFrame,
    RefreshTargetFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function()
        return Module.targetFrame
    end,
    ChangeTargetFrame = RefreshFrame
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeTargetFrame = RefreshFrame
addon.unitframe.ReApplyTargetFrame = RefreshFrame

function addon:RefreshTargetFrame()
    RefreshFrame()
end

print("|cFF00FF00[DragonUI]|r Target module loaded and optimized v2.0")
