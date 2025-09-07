local addon = select(2, ...)

print("|cFF00FF00[DragonUI]|r Target.lua LOADING")

-- ====================================================================
-- DRAGONUI TARGET FRAME MODULE - Optimized for WoW 3.3.5a
-- ====================================================================

-- ============================================================================
-- MODULE VARIABLES & CONFIGURATION
-- ============================================================================

local Module = {}
Module.targetFrame = nil
Module.textSystem = nil
Module.initialized = false
Module.eventsFrame = nil


-- Cache frequently accessed globals for performance
local TargetFrame = _G.TargetFrame
local TargetFrameHealthBar = _G.TargetFrameHealthBar
local TargetFrameManaBar = _G.TargetFrameManaBar
local TargetFramePortrait = _G.TargetFramePortrait
local TargetFrameTextureFrameName = _G.TargetFrameTextureFrameName
local TargetFrameTextureFrameLevelText = _G.TargetFrameTextureFrameLevelText
local TargetFrameNameBackground = _G.TargetFrameNameBackground

-- Texture paths configuration
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-",
    NAME_BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\TargetFrame\\NameBackground"
}

-- Boss frame coordinates for uiunitframeboss2x 
local BOSS_COORDINATES = {
    -- Elite/WorldBoss (dragón dorado) - RetailUI combines these
    elite = {
        texCoord = {0.001953125, 0.314453125, 0.322265625, 0.630859375},
        size = {80, 79},
        offset = {4, 1}
    },

    -- Rare (dragón plateado)
    rare = {
        texCoord = {0.00390625, 0.31640625, 0.64453125, 0.953125},
        size = {80, 79},
        offset = {4, 1}
    },

    -- RareElite (dragón dorado grande)
    rareelite = {
        texCoord = {0.001953125, 0.388671875, 0.001953125, 0.31835937},
        size = {99, 81},
        offset = {13, 1}
    }
}

-- Power type mapping for textures
local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- Event lookup tables for O(1) performance
local HEALTH_EVENTS = {
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_HEALTH_FREQUENT = true
}

local POWER_EVENTS = {
    UNIT_MANA = true,
    UNIT_MAXMANA = true,
    UNIT_RAGE = true,
    UNIT_MAXRAGE = true,
    UNIT_ENERGY = true,
    UNIT_MAXENERGY = true,
    UNIT_FOCUS = true,
    UNIT_MAXFOCUS = true,
    UNIT_RUNIC_POWER = true,
    UNIT_MAXRUNIC_POWER = true,
    UNIT_DISPLAYPOWER = true
}

local BOTH_EVENTS = {
    UNIT_PORTRAIT_UPDATE = true,
    UNIT_AURA = true,
    UNIT_FACTION = true
}

-- Build state tracking
local isBuilt = false
local backgroundTexture, borderTexture


-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Create auxiliary frame for anchoring
local function CreateUIFrame(width, height, name)
    local frame = CreateFrame("Frame", "DragonUI_" .. name .. "_Anchor", UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -50)
    frame:SetFrameStrata("LOW")
    return frame
end

-- Get target configuration with fallback to defaults
local function GetTargetConfig()
    local config = addon:GetConfigValue("unitframe", "target") or {}
    -- Usar defaults directamente de database
    local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.target or {}

    -- Aplicar defaults de database para cualquier valor faltante
    for key, value in pairs(dbDefaults) do
        if config[key] == nil then
            config[key] = value
        end
    end
    return config
end

-- Validate and clamp coordinates to screen bounds
local function ValidateCoordinates(x, y)
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    local minX, maxX = -500, screenWidth + 500
    local minY, maxY = -500, screenHeight + 500

    if x < minX or x > maxX or y < minY or y > maxY then
        print("|cFFFF0000[DragonUI]|r TargetFrame coordinates out of bounds! Resetting...")
        local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
        return dbDefaults.x or 20, dbDefaults.y or -4, false
    end
    return x, y, true
end

-- ============================================================================
-- BLIZZARD FRAME MANAGEMENT
-- ============================================================================

-- Hide unwanted Blizzard target frame elements
local function HideBlizzardElements()
    local elementsToHide = {
        TargetFrameTextureFrameTexture, 
        TargetFrameBackground, 
        TargetFrameFlash,

        _G.TargetFrameNumericalThreat,
        TargetFrame.threatNumericIndicator,
        TargetFrame.threatIndicator
    }

    for _, element in ipairs(elementsToHide) do
        if element then
            element:SetAlpha(0)
        end
    end

    print("|cFF00FF00[DragonUI]|r Blizzard elements hidden (including threat)")
end

-- ============================================================================
-- BAR COLOR & TEXTURE MANAGEMENT
-- ============================================================================

-- Update health bar color and texture with dynamic clipping
local function UpdateHealthBarColor(statusBar, unit)
    if not unit then
        unit = "target"
    end
    if statusBar ~= TargetFrameHealthBar or unit ~= "target" then
        return
    end
    if not UnitExists("target") then
        return
    end

    local texture = statusBar:GetStatusBarTexture()
    if not texture then
        return
    end

    local config = GetTargetConfig()

    -- Set texture and layer
    texture:SetTexture(TEXTURES.BAR_PREFIX .. "Health")
    texture:SetDrawLayer("BORDER", 1)

    -- Dynamic texture clipping based on current value
    local _, maxValue = statusBar:GetMinMaxValues()
    local currentValue = statusBar:GetValue()
    if maxValue > 0 and currentValue then
        local percentage = currentValue / maxValue
        texture:SetTexCoord(0, percentage, 0, 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end

    -- Apply color based on configuration
    if config.classcolor and UnitIsPlayer("target") then
        local _, class = UnitClass("target")
        local color = RAID_CLASS_COLORS[class]
        if color then
            texture:SetVertexColor(color.r, color.g, color.b)
            return
        end
    end
    texture:SetVertexColor(1, 1, 1)
end

-- Update power bar color and texture with dynamic clipping
local function UpdatePowerBarColor(statusBar, unit)
    if not unit then
        unit = "target"
    end
    if statusBar ~= TargetFrameManaBar or unit ~= "target" then
        return
    end
    if not UnitExists("target") then
        return
    end

    local texture = statusBar:GetStatusBarTexture()
    if not texture then
        return
    end

    local powerType = UnitPowerType("target")
    local suffix = POWER_MAP[powerType] or "Mana"

    -- Set texture and layer
    texture:SetTexture(TEXTURES.BAR_PREFIX .. suffix)
    texture:SetDrawLayer("BORDER", 1)

    -- Dynamic texture clipping
    local _, maxValue = statusBar:GetMinMaxValues()
    local currentValue = statusBar:GetValue()
    if maxValue > 0 and currentValue then
        local percentage = currentValue / maxValue
        texture:SetTexCoord(0, percentage, 0, 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end

    -- Force white color for texture purity (prevents tinting)
    statusBar:SetStatusBarColor(1, 1, 1, 1)
    texture:SetVertexColor(1, 1, 1)
end

-- ============================================================================
-- SISTEMA DE THREAT 
-- ============================================================================

-- ✅ THREAT COLORS (sin gris - como acordamos)
local THREAT_COLORS = {
    [1] = {1.0, 1.0, 0.47}, -- Bajo (amarillo)
    [2] = {1.0, 0.6, 0.0}, -- Medio (naranja)  
    [3] = {1.0, 0.0, 0.0} -- Alto (rojo)
}

-- ✅ COORDENADAS PARA THREAT GLOW (mismas que player elite decoration pero sin invertir)
local THREAT_GLOW_COORDINATES = {
    texCoord = {0, 0.2061015625, 0.537109375, 0.712890625}, 
    size = {209, 90},
    texture = 'Interface\\Addons\\DragonUI\\Textures\\UI\\UnitFrame'
}

--  SISTEMA DE SWITCH COMO EN PLAYER
local threatGlowVisible = false
local threatNumericalVisible = false

--  CREAR THREAT GLOWS INDEPENDIENTES (como player)
local function CreateTargetThreatSystem()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- ✅ VERIFICAR SI YA EXISTEN ANTES DE CREAR
    if dragonFrame.TargetThreatGlow and dragonFrame.TargetNumericalThreat then
        return  -- Ya creados, salir
    end

    --  CREAR THREAT GLOW 
    if not dragonFrame.TargetThreatGlow then
        local threatFrame = CreateFrame("Frame", "DragonUITargetThreatGlow", UIParent) -- ✅ EN UIPARENT
        threatFrame:SetFrameStrata("MEDIUM")
        threatFrame:SetFrameLevel(0)
        threatFrame:SetSize(THREAT_GLOW_COORDINATES.size[1], THREAT_GLOW_COORDINATES.size[2])
        threatFrame:Hide()

        local threatTexture = threatFrame:CreateTexture(nil, "OVERLAY")
        threatTexture:SetTexture(THREAT_GLOW_COORDINATES.texture)
        threatTexture:SetTexCoord(unpack(THREAT_GLOW_COORDINATES.texCoord))
        threatTexture:SetAllPoints(threatFrame)
        threatTexture:SetBlendMode("ADD")
        threatTexture:SetVertexColor(1.0, 1.0, 0.47, 0.8) 

        -- POSICIONAR RELATIVO AL TARGETFRAME 
        threatFrame:SetPoint('TOPLEFT', TargetFrame, 'TOPLEFT', 0, 5)

        dragonFrame.TargetThreatGlow = threatFrame
        dragonFrame.TargetThreatTexture = threatTexture

        print("|cFF00FF00[DragonUI]|r Target Threat Glow created independently")
    end

    --  CREAR NUMERICAL THREAT 
    if not dragonFrame.TargetNumericalThreat then
        local numericalFrame = CreateFrame("Frame", "DragonUITargetNumericalThreat", UIParent) -- ✅ EN UIPARENT
        numericalFrame:SetFrameStrata("MEDIUM")
        numericalFrame:SetFrameLevel(999)
        numericalFrame:SetSize(71, 13)

        --  USAR MISMA TEXTURA QUE GROUPINDICATOR DEL PLAYER
        local bgTexture = numericalFrame:CreateTexture(nil, "ARTWORK")
        bgTexture:SetTexture('Interface\\Addons\\DragonUI\\Textures\\uiunitframe') -- Tu textura base
        bgTexture:SetTexCoord(0.927734375, 0.9970703125, 0.3125, 0.337890625) -- Coordenadas GroupIndicator
        bgTexture:SetAllPoints(numericalFrame)

        local threatText = numericalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        threatText:SetPoint("CENTER", numericalFrame, "CENTER", 0, 0)
        threatText:SetJustifyH("CENTER")
        threatText:SetTextColor(1, 1, 1, 1)
        threatText:SetFont("Fonts\\FRIZQT__.TTF", 10)
        threatText:SetShadowOffset(1, -1)
        threatText:SetShadowColor(0, 0, 0, 1)

        -- ✅ POSICIONAR ARRIBA DEL TARGET
        numericalFrame:SetPoint("BOTTOM", TargetFrame, "TOP", -45, -20)
        numericalFrame:Hide()

        numericalFrame.backgroundTexture = bgTexture
        numericalFrame.text = threatText

        dragonFrame.TargetNumericalThreat = numericalFrame

        print("|cFF00FF00[DragonUI]|r Target Numerical Threat created independently")
    end
end

-- ✅ CALCULAR THREAT LEVEL 
local function GetThreatLevel(unit)
    if not UnitExists(unit) then
        return 0
    end

    local status = UnitThreatSituation("player", unit)
    if not status then
        return 0
    end

    if status == 0 then
        return 0 -- Sin threat
    elseif status == 1 then
        return 1 -- Bajo  
    elseif status == 2 then
        return 2 -- Medio
    else
        return 3
    end -- Alto
end

-- ✅ CONTROL DE THREAT GLOW (como player)
local function SetThreatGlowVisible(visible, threatLevel)
    threatGlowVisible = visible

    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.TargetThreatGlow then
        return
    end

    if visible and threatLevel > 0 then
        local color = THREAT_COLORS[threatLevel]
        dragonFrame.TargetThreatTexture:SetVertexColor(color[1], color[2], color[3], 0.8)
        dragonFrame.TargetThreatGlow:Show()
    else
        dragonFrame.TargetThreatGlow:Hide()
    end
end

-- ✅ CONTROL DE NUMERICAL THREAT (como player)
local function SetNumericalThreatVisible(visible, threatLevel, threatPct)
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.TargetNumericalThreat then
        return
    end

    -- ✅ LÓGICA SIMPLE: Mostrar si hay porcentaje válido
    if threatPct and threatPct > 0 then
        local color = THREAT_COLORS[threatLevel] or {1, 1, 1} -- Blanco por defecto
        dragonFrame.TargetNumericalThreat.text:SetText(math.floor(threatPct) .. "%")
        dragonFrame.TargetNumericalThreat.text:SetTextColor(color[1], color[2], color[3], 1)
        dragonFrame.TargetNumericalThreat:Show()
    else
        dragonFrame.TargetNumericalThreat:Hide()
    end
end

-- ✅ FUNCIÓN PRINCIPAL DE UPDATE (simplificada)
local function UpdateThreatSystem()
    if not UnitExists("target") then
        SetThreatGlowVisible(false, 0)
        SetNumericalThreatVisible(false, 0, 0)
        return
    end

    local success, threatLevel = pcall(GetThreatLevel, "target")
    if not success then
        print("|cFFFF0000[DragonUI]|r Error getting threat level")
        return
    end
    
    local status, threatpct
    success, status = pcall(UnitThreatSituation, "player", "target")
    if success and status then
        success, _, _, threatpct = pcall(UnitDetailedThreatSituation, "player", "target")  -- ✅ PROTEGIDO
        if not success then
            threatpct = nil
        end
    end
    
    SetThreatGlowVisible(status and status > 0, threatLevel)
    SetNumericalThreatVisible(true, threatLevel, threatpct)
end

-- ============================================================================
-- FRAME CREATION & CONFIGURATION
-- ============================================================================



local function CreateTargetFrameTextures()
    if isBuilt or not TargetFrame then
        return
    end

    HideBlizzardElements()

    -- Create background texture
    if not backgroundTexture then
        backgroundTexture = TargetFrame:CreateTexture("DragonUI_TargetFrameBackground", "BACKGROUND", nil, 0)
        backgroundTexture:SetTexture(TEXTURES.BACKGROUND)
        backgroundTexture:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 0, -8)
    end

    -- Create border texture
    if not borderTexture then
        borderTexture = TargetFrame:CreateTexture("DragonUI_TargetFrameBorder", "OVERLAY", nil, 5)
        borderTexture:SetTexture(TEXTURES.BORDER)
        borderTexture:SetPoint("TOPLEFT", backgroundTexture, "TOPLEFT", 0, 0)
    end

    -- ✅ CREAR targetExtra CON FRAMELEVEL FIJO
    if not targetExtra then
        targetExtra = TargetFrame:CreateTexture("DragonUI_TargetFrameExtra", "OVERLAY", nil, 7) -- ✅ NIVEL 7 (MAYOR QUE BORDER)
        targetExtra:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x")
        targetExtra:Hide() -- Hide by default
        
        -- ✅ FORZAR DRAW ORDER DESPUÉS DE CREACIÓN
        targetExtra:SetDrawLayer("OVERLAY", 7)
        
        print("|cFF00FF00[DragonUI]|r Target Elite decoration created with proper layering")
    end

    -- ✅ CORREGIDO: Posicionamiento igual que RetailUI
    if TargetFrameNameBackground then
        TargetFrameNameBackground:ClearAllPoints()

        -- ✅ CLAVE: Usar el mismo posicionamiento que unitframe.lua
        TargetFrameNameBackground:SetPoint('BOTTOMLEFT', TargetFrameHealthBar, 'TOPLEFT', -2, -5)

        -- ✅ CLAVE: Tamaño fijo como en unitframe.lua
        TargetFrameNameBackground:SetSize(135, 18)

        -- ✅ Tu textura personalizada (mantener)
        TargetFrameNameBackground:SetTexture(TEXTURES.NAME_BACKGROUND)

        -- ✅ Configuración básica como unitframe.lua
        TargetFrameNameBackground:SetDrawLayer("BORDER")
        TargetFrameNameBackground:SetBlendMode("ADD")
        TargetFrameNameBackground:SetAlpha(0.9)

        -- ✅ IMPORTANTE: Mostrar inicialmente
        TargetFrameNameBackground:Show()
    end

    -- ✅ CREAR THREAT SYSTEM DESPUÉS DE targetExtra
    CreateTargetThreatSystem()

    isBuilt = true
    print("|cFF00FF00[DragonUI]|r Target textures created")
end

-- ✅ MEJORADO: Update name background con color de selección de unidad
local function UpdateNameBackground()
    if not UnitExists("target") or not TargetFrameNameBackground then
        return
    end

    -- ✅ SIMPLIFICADO: Como en unitframe.lua
    local r, g, b = UnitSelectionColor("target")

    if not r then
        r, g, b = 0.5, 0.5, 0.5
    end

    TargetFrameNameBackground:SetVertexColor(r, g, b, 0.8)
    TargetFrameNameBackground:Show()
end

-- Hide name background when no target
local function HideNameBackground()
    if TargetFrameNameBackground then
        TargetFrameNameBackground:Hide()
    end
end

local function UpdateTargetClassification()
    if not UnitExists("target") or not targetExtra then
        if targetExtra then
            targetExtra:Hide()
        end
        return
    end

    local classification = UnitClassification("target")
    local isVehicle = UnitVehicleSeatCount and UnitVehicleSeatCount("target") > 0
    local coords = nil

    -- ✅ DETECCIÓN DE VEHÍCULOS IGUAL QUE RETAILUI
    if isVehicle then
        -- Ajustar tamaños para vehículo (igual que RetailUI)
        TargetFrameHealthBar:SetSize(116, 20)
        TargetFrameManaBar:SetSize(123, 10)

        -- Ajustar posiciones de texto
        if TargetFrameTextureFrameName then
            TargetFrameTextureFrameName:ClearAllPoints()
            TargetFrameTextureFrameName:SetPoint("CENTER", -20, 26)
        end
        if TargetFrameTextureFrameLevelText then
            TargetFrameTextureFrameLevelText:ClearAllPoints()
            TargetFrameTextureFrameLevelText:SetPoint("CENTER", -80, 26)
        end

        targetExtra:Hide() -- Ocultar decoración de boss en vehículos
        return
    else
        -- ✅ RESTAURAR TAMAÑOS NORMALES
        TargetFrameHealthBar:SetSize(125, 20)
        TargetFrameManaBar:SetSize(132, 9)

        -- Restaurar posiciones normales
        if TargetFrameTextureFrameName then
            TargetFrameTextureFrameName:ClearAllPoints()
            TargetFrameTextureFrameName:SetPoint('BOTTOM', TargetFrameHealthBar, 'TOP', 10, 1)
        end
        if TargetFrameTextureFrameLevelText then
            TargetFrameTextureFrameLevelText:ClearAllPoints()
            TargetFrameTextureFrameLevelText:SetPoint('BOTTOMRIGHT', TargetFrameHealthBar, 'TOPLEFT', 16, 1)
        end
    end

    -- ✅ RESTO DE CLASIFICACIONES (como ya tienes)
    if classification == "worldboss" or classification == "elite" then
        coords = BOSS_COORDINATES.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDINATES.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDINATES.rare
    else
        local name = UnitName("target")
        if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
            coords = BOSS_COORDINATES.elite
        else
            targetExtra:Hide()
            return
        end
    end

    if coords then
        -- ✅ FORZAR LAYERING AL MOSTRAR
        targetExtra:SetDrawLayer("OVERLAY", 7)
        targetExtra:Show()
        targetExtra:SetSize(coords.size[1], coords.size[2])
        targetExtra:SetTexCoord(coords.texCoord[1], coords.texCoord[2], coords.texCoord[3], coords.texCoord[4])
        targetExtra:SetPoint('CENTER', TargetFramePortrait, 'CENTER', coords.offset[1], coords.offset[2])
    else
        targetExtra:Hide()
    end
end

-- Configure target frame elements positioning and hooks
local function ConfigureTargetElements()
    if not TargetFrame then
        return
    end

    -- Configure portrait
    TargetFramePortrait:ClearAllPoints()
    TargetFramePortrait:SetSize(56, 56)
    TargetFramePortrait:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -47, -15)
    TargetFramePortrait:SetDrawLayer("ARTWORK", 1)

    -- Configure health bar
    TargetFrameHealthBar:ClearAllPoints()
    TargetFrameHealthBar:SetSize(125, 20)
    TargetFrameHealthBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", -1, 0)

    local healthTexture = TargetFrameHealthBar:GetStatusBarTexture()
    healthTexture:SetTexture(TEXTURES.BAR_PREFIX .. "Health")
    healthTexture:SetDrawLayer("BORDER", 1)

    -- Setup health bar hooks for persistent color and clipping
    if not TargetFrameHealthBar.DragonUI_HealthBarHooked then
        TargetFrameHealthBar:HookScript("OnValueChanged", function(self)
            if UnitExists("target") then
                UpdateHealthBarColor(self, "target")
            end
        end)
        TargetFrameHealthBar.DragonUI_HealthBarHooked = true
    end

    -- Configure power bar
    TargetFrameManaBar:ClearAllPoints()
    TargetFrameManaBar:SetSize(132, 9)
    TargetFrameManaBar:SetPoint('RIGHT', TargetFramePortrait, 'LEFT', 6.5, -16.5)

    -- Setup power bar hooks for persistent color and clipping
    if not TargetFrameManaBar.DragonUI_PowerBarHooked then
        TargetFrameManaBar:HookScript("OnValueChanged", function(self)
            if UnitExists("target") then
                UpdatePowerBarColor(self, "target")
            end
        end)
        TargetFrameManaBar.DragonUI_PowerBarHooked = true
    end

    -- Configure name and level text positioning
    if TargetFrameTextureFrameName then
        TargetFrameTextureFrameName:ClearAllPoints()
        TargetFrameTextureFrameName:SetPoint('BOTTOM', TargetFrameHealthBar, 'TOP', 10, 1)
    end

    if TargetFrameTextureFrameLevelText then
        TargetFrameTextureFrameLevelText:ClearAllPoints()
        TargetFrameTextureFrameLevelText:SetPoint('BOTTOMRIGHT', TargetFrameHealthBar, 'TOPLEFT', 16, 1)
    end

    -- Initialize bars with current target values
    if UnitExists("target") then
        TargetFrameHealthBar:SetMinMaxValues(0, UnitHealthMax("target"))
        TargetFrameHealthBar:SetValue(UnitHealth("target"))
        TargetFrameManaBar:SetMinMaxValues(0, UnitPowerMax("target"))
        TargetFrameManaBar:SetValue(UnitPower("target"))
    end

    print("|cFF00FF00[DragonUI]|r Target elements configured with dynamic texture clipping")
end

-- Position TargetFrame
local function MoveTargetFrame(point, relativeTo, relativePoint, xOfs, yOfs)
    TargetFrame:ClearAllPoints()

    local originalClamped = TargetFrame:IsClampedToScreen()
    TargetFrame:SetClampedToScreen(false)

    local finalPoint = point or "TOPLEFT"
    local finalFrame = _G[relativeTo or "UIParent"] or UIParent
    local finalRelativePoint = relativePoint or "TOPLEFT"
    local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    local finalX = xOfs or (dbDefaults.x or 20)
    local finalY = yOfs or (dbDefaults.y or -4)

    TargetFrame:SetPoint(finalPoint, finalFrame, finalRelativePoint, finalX, finalY)
    TargetFrame:SetClampedToScreen(originalClamped)

    print("|cFF00FF00[DragonUI]|r TargetFrame positioned:", finalPoint, "to", finalRelativePoint, finalX, finalY)
end

-- Apply configuration settings
local function ApplyTargetConfig()
    if not isBuilt then
        return
    end

    local config = GetTargetConfig()
    local x, y, valid = ValidateCoordinates(config.x, config.y)

    if not valid then
        -- Reset invalid coordinates usando database defaults
        local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
        for key, value in pairs(dbDefaults) do
            addon:SetConfigValue("unitframe", "target", key, value)
        end
        config = dbDefaults
        x, y = dbDefaults.x or 20, dbDefaults.y or -4
    end

    TargetFrame:SetScale(config.scale)

    if config.override then
        MoveTargetFrame(config.anchor, "UIParent", config.anchorParent, x, y)
    else
        local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
        MoveTargetFrame("TOPLEFT", "UIParent", "TOPLEFT", dbDefaults.x or 20, dbDefaults.y or -4)
    end

    -- Setup text system
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and addon.TextSystem then
        if not Module.textSystem then
            Module.textSystem = addon.TextSystem.SetupFrameTextSystem("target", "target", dragonFrame,
                TargetFrameHealthBar, TargetFrameManaBar, "TargetFrame")
            print("|cFF00FF00[DragonUI]|r TargetFrame TextSystem configured")
        end

        if Module.textSystem then
            Module.textSystem.update()
        end
    end

    print("|cFF00FF00[DragonUI]|r Target config applied - Override:", config.override, "Scale:", config.scale)
end

-- Main frame configuration function
local function ChangeTargetFrame()
    CreateTargetFrameTextures()
    ConfigureTargetElements()
    ApplyTargetConfig()

    -- Initial color updates
    if UnitExists("target") then
        UpdateHealthBarColor(TargetFrameHealthBar, "target")
        UpdatePowerBarColor(TargetFrameManaBar, "target")
    end

    print("|cFF00FF00[DragonUI]|r TargetFrame configured successfully")
end

-- ============================================================================
-- PUBLIC API FUNCTIONS
-- ============================================================================

-- Reset frame to default configuration
local function ResetTargetFrame()
    -- Usar defaults de database en lugar de DEFAULTS locales
    local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    for key, value in pairs(dbDefaults) do
        addon:SetConfigValue("unitframe", "target", key, value)
    end
    ApplyTargetConfig()
    print("|cFF00FF00[DragonUI]|r TargetFrame reset to defaults")
end

-- Refresh frame configuration
local function RefreshTargetFrame()
    ChangeTargetFrame()
    if Module.textSystem then
        Module.textSystem.update()
    end
    print("|cFF00FF00[DragonUI]|r TargetFrame refreshed")
end

-- ============================================================================
-- HOOKS & HARDENING
-- ============================================================================

-- Harden power bar against Blizzard overrides
local function HardenPowerBar()
    if not TargetFrameManaBar or TargetFrameManaBar.DragonUI_Hardened then
        return
    end

    -- Hook OnShow to reapply colors
    TargetFrameManaBar:HookScript('OnShow', function(self)
        UpdatePowerBarColor(self, "target")
    end)

    -- Override SetStatusBarTexture to maintain our texture
    local originalSetTexture = TargetFrameManaBar.SetStatusBarTexture
    if originalSetTexture then
        TargetFrameManaBar.SetStatusBarTexture = function(self, texture)
            local result = originalSetTexture(self, texture)
            UpdatePowerBarColor(self, "target")
            return result
        end
    end

    -- Override SetMinMaxValues to maintain clipping
    local originalSetMinMax = TargetFrameManaBar.SetMinMaxValues
    if originalSetMinMax then
        TargetFrameManaBar.SetMinMaxValues = function(self, min, max)
            originalSetMinMax(self, min, max)
            UpdatePowerBarColor(self, "target")
        end
    end

    -- Override SetStatusBarColor to force white
    local originalSetColor = TargetFrameManaBar.SetStatusBarColor
    if originalSetColor then
        TargetFrameManaBar.SetStatusBarColor = function(self, r, g, b, a)
            originalSetColor(self, 1, 1, 1, a or 1)
            local texture = self:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(1, 1, 1)
            end
        end
    end

    TargetFrameManaBar.DragonUI_Hardened = true
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Initialize the TargetFrame module
local function InitializeTargetFrame()
    if Module.initialized then
        return
    end

    -- Create auxiliary frame
    Module.targetFrame = CreateUIFrame(192, 67, "TargetFrame")

    -- Setup hooks and hardening

    HardenPowerBar()
    

    -- Setup persistent color hooks for health bar
    if TargetFrameHealthBar and TargetFrameHealthBar.HookScript then
        TargetFrameHealthBar:HookScript('OnShow', function(self)
            UpdateHealthBarColor(self, "target")
        end)
        TargetFrameHealthBar:HookScript('OnUpdate', function(self)
            UpdateHealthBarColor(self, "target")
        end)
    end

    Module.initialized = true
    print("|cFF00FF00[DragonUI]|r TargetFrame module initialized")
end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

-- Combined update function for efficiency
local function UpdateBothBars()
    if UnitExists("target") then
        UpdateHealthBarColor(TargetFrameHealthBar, "target")
        UpdatePowerBarColor(TargetFrameManaBar, "target")
        UpdateNameBackground()
        UpdateTargetClassification()
    else
        HideNameBackground()
        if targetExtra then
            targetExtra:Hide()
        end
    end
end

-- Setup event handling system
local function SetupTargetEvents()
    if Module.eventsFrame then
        return
    end

    local f = CreateFrame("Frame")
    Module.eventsFrame = f

    -- Event handlers
    local handlers = {
        ADDON_LOADED = function(addonName)
            if addonName == "DragonUI" then
                InitializeTargetFrame()
            end
        end,

        PLAYER_ENTERING_WORLD = function()
            ChangeTargetFrame()
            print("|cFF00FF00[DragonUI]|r TargetFrame fully configured")
        end,

        PLAYER_TARGET_CHANGED = function()
            UpdateBothBars()
            UpdateThreatSystem()
            UpdateTargetClassification()
            UpdateNameBackground()

            if UnitExists("target") then
                UpdateNameBackground()
            else
                HideNameBackground()
                if targetExtra then
                    targetExtra:Hide()
                end
            end
        end,

        UNIT_CLASSIFICATION_CHANGED = function(unit)
            if unit == "target" then
                UpdateTargetClassification()
                UpdateNameBackground()
            end
        end,

        UNIT_THREAT_SITUATION_UPDATE = function(unit)
            if unit == "target" then
                UpdateThreatSystem()
            end
        end,

        UNIT_THREAT_LIST_UPDATE = function(unit)
            if unit == "target" then
                UpdateThreatSystem()
            end
        end,

        PLAYER_REGEN_DISABLED = function()
    -- ✅ PROTECCIÓN: Verificar que las APIs estén disponibles
    if not UnitExists or not UnitExists("player") then
        return -- APIs no disponibles durante transición
    end
    
    if UnitExists("target") then
        local success, error = pcall(UpdateBothBars)
        if not success then
            print("|cFFFF0000[DragonUI]|r Error in combat enter:", error)
        end
    end
end,

PLAYER_REGEN_ENABLED = function()
    -- ✅ PROTECCIÓN: Verificar que las APIs estén disponibles  
    if not UnitExists or not UnitExists("player") then
        return -- APIs no disponibles durante transición
    end
    
    if UnitExists("target") then
        local success, error = pcall(UpdateBothBars)
        if not success then
            print("|cFFFF0000[DragonUI]|r Error in combat exit:", error)
        end
    end
end,

        -- Eventos para actualizar el fondo del nombre
        UNIT_FACTION = function(unit)
            if unit == "target" then
                UpdateNameBackground()
            end
        end
    }

    -- Register all events
    for event in pairs(handlers) do
        f:RegisterEvent(event)
    end

    for event in pairs(HEALTH_EVENTS) do
        f:RegisterEvent(event)
    end

    for event in pairs(POWER_EVENTS) do
        f:RegisterEvent(event)
    end

    for event in pairs(BOTH_EVENTS) do
        f:RegisterEvent(event)
    end


    f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    f:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")

    -- Event dispatcher
    f:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then
            handler(...)
            return
        end

        local unit = ...
        if unit ~= "target" then
            return
        end

        if BOTH_EVENTS[event] then
            UpdateBothBars()
        elseif HEALTH_EVENTS[event] then
            UpdateHealthBarColor(TargetFrameHealthBar, "target")
        elseif POWER_EVENTS[event] then
            UpdatePowerBarColor(TargetFrameManaBar, "target")
        end
    end)

    print("|cFF00FF00[DragonUI Target]|r Optimized event system configured")
end

-- ============================================================================
-- MODULE STARTUP
-- ============================================================================

-- Initialize event system
SetupTargetEvents()

-- Expose public API
addon.TargetFrame = {
    Refresh = RefreshTargetFrame,
    RefreshTargetFrame = RefreshTargetFrame,
    Reset = ResetTargetFrame,
    anchor = function()
        return Module.targetFrame
    end,
    ChangeTargetFrame = ChangeTargetFrame,
    CreateTargetFrameTextures = CreateTargetFrameTextures
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeTargetFrame = ChangeTargetFrame
addon.unitframe.ReApplyTargetFrame = RefreshTargetFrame

-- Direct API access
function addon:RefreshTargetFrame()
    RefreshTargetFrame()
end

print("|cFF00FF00[DragonUI]|r Target.lua LOADED")
