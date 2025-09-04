local addon = select(2, ...)

print("|cFF00FF00[DragonUI]|r Target.lua LOADING")

-- ====================================================================
-- TARGET FRAME MODULE - Versión reescrita y mejorada
-- ====================================================================

local Module = {}
Module.targetFrame = nil
Module.textSystem = nil
Module.initialized = false

-- Variables de control
local built = false
local bg, border

-- Defaults locales
local DEFAULTS = {
    scale = 1,
    override = false,
    anchor = "TOPLEFT",
    anchorParent = "TOPLEFT",
    x = 216,
    y = -4,
    classcolor = false
}

-- Rutas de texturas
local TEX_BG_FILE     = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND"
local TEX_BORDER_FILE = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER"
local TEX_BAR_PREFIX  = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-"

-- Mapa de tipos de poder
local powerMap = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- ✅ FUNCIÓN: Obtener configuración
local function GetConfig()
    local p = addon.db
              and addon.db.profile
              and addon.db.profile.unitframe
              and addon.db.profile.unitframe.target
    if not p then return DEFAULTS end
    for k,v in pairs(DEFAULTS) do
        if p[k] == nil then p[k] = v end
    end
    return p
end

-- ✅ FUNCIÓN: Crear frame auxiliar
local function CreateUIFrame(width, height, name)
    local frame = CreateFrame("Frame", "DragonUI_" .. name .. "_Anchor", UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -50)
    frame:SetFrameStrata("LOW")
    return frame
end

-- ✅ FUNCIÓN: Ocultar elementos originales de Blizzard
local function HideBlizzardElements()
    local elements = {
        TargetFrameTextureFrameTexture,
        TargetFrameBackground,
        TargetFrameFlash,
        TargetFrameNameBackground
    }
    
    for _, element in ipairs(elements) do
        if element then
            element:SetAlpha(0)
        end
    end
end

-- ✅ FUNCIÓN: Crear texturas personalizadas
local function CreateTargetFrameTextures()
    if built or not TargetFrame then return end

    -- Ocultar elementos originales
    HideBlizzardElements()

    -- Fondo personalizado
    if not bg then
        bg = TargetFrame:CreateTexture("DragonUI_TargetFrameBackground", "BACKGROUND", nil, 0)
        bg:SetTexture(TEX_BG_FILE)
        
        bg:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 0, -8)
    end
    
    -- Borde personalizado
    if not border then
        border = TargetFrame:CreateTexture("DragonUI_TargetFrameBorder", "OVERLAY", nil, 5)
        border:SetTexture(TEX_BORDER_FILE)
        
        border:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
    end

    built = true
    print("|cFF00FF00[DragonUI]|r Target textures created")
end

-- ✅ FUNCIÓN: Configurar elementos del frame
local function ConfigureTargetElements()
    if not TargetFrame then return end

    -- Retrato
    TargetFramePortrait:ClearAllPoints()
    TargetFramePortrait:SetSize(56,56)
    TargetFramePortrait:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -47, -15)
    TargetFramePortrait:SetDrawLayer("ARTWORK",1)

    -- Barra de vida
    TargetFrameHealthBar:ClearAllPoints()
    TargetFrameHealthBar:SetSize(125,20)
    TargetFrameHealthBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", -1, 0)
    local htex = TargetFrameHealthBar:GetStatusBarTexture()
    htex:SetTexture(TEX_BAR_PREFIX .. "Health")
    htex:SetDrawLayer("BORDER",1)

    -- Barra de poder
    TargetFrameManaBar:ClearAllPoints()
    TargetFrameManaBar:SetSize(132,9)
    TargetFrameManaBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", 7.5, -17.5)

    print("|cFF00FF00[DragonUI]|r Target elements configured")
end

-- ✅ FUNCIÓN: Actualizar textura de poder
local function UpdatePowerTexture()
    if not UnitExists("target") then return end
    local pType = UnitPowerType("target")
    local suffix = powerMap[pType] or "Mana"
    local tex = TargetFrameManaBar:GetStatusBarTexture()
    if tex then
        tex:SetTexture(TEX_BAR_PREFIX .. suffix)
        tex:SetVertexColor(1,1,1)
    end
end

-- ✅ FUNCIÓN: Actualizar color de barra de vida
local function UpdateHealthBarColor()
    if not UnitExists("target") then return end
    local cfg = GetConfig()
    local tex = TargetFrameHealthBar:GetStatusBarTexture()
    if not tex then return end
    
    if cfg.classcolor and UnitIsPlayer("target") then
        local _, class = UnitClass("target")
        local c = RAID_CLASS_COLORS[class]
        if c then
            tex:SetVertexColor(c.r, c.g, c.b)
            return
        end
    end
    tex:SetVertexColor(1,1,1)
end

-- ✅ FUNCIÓN: Mover TargetFrame (COMO PLAYER.LUA)
local function MoveTargetFrame(point, relativeTo, relativePoint, xOfs, yOfs)
    TargetFrame:ClearAllPoints()
    
    local originalClamped = TargetFrame:IsClampedToScreen()
    TargetFrame:SetClampedToScreen(false)
    
    local finalRelativePoint = relativePoint or "TOPLEFT"
    local finalPoint = point or "TOPLEFT"
    local finalFrame = _G[relativeTo or "UIParent"] or UIParent
    local finalX = xOfs or 216
    local finalY = yOfs or -4
    
    TargetFrame:SetPoint(finalPoint, finalFrame, finalRelativePoint, finalX, finalY)
    TargetFrame:SetClampedToScreen(originalClamped)
    
    print("|cFF00FF00[DragonUI]|r TargetFrame positioned:", finalPoint, "to", finalRelativePoint, finalX, finalY)
end

-- ✅ FUNCIÓN: Configurar posición y escala (COMO PLAYER.LUA)
local function ApplyTargetConfig()
    if not built then return end
    local cfg = GetConfig()
    
    local scale = cfg.scale or 1.0
    local override = cfg.override or false
    local x = cfg.x or 216
    local y = cfg.y or -4
    local anchor = cfg.anchor or "TOPLEFT"
    local anchorParent = cfg.anchorParent or "TOPLEFT"
    
    print("|cFF00FF00[DragonUI]|r Target config - Override:", override, "Scale:", scale)
    
    TargetFrame:SetScale(scale)
    
    if override then
        -- Validación de coordenadas (como player.lua)
        local screenWidth = GetScreenWidth()
        local screenHeight = GetScreenHeight()
        
        local minX = -500
        local maxX = screenWidth + 500
        local minY = -500
        local maxY = screenHeight + 500
        
        if x < minX or x > maxX or y < minY or y > maxY then
            print("|cFFFF0000[DragonUI]|r TargetFrame coordinates out of bounds! Resetting...")
            x, y = 216, -4
            anchor, anchorParent = "TOPLEFT", "TOPLEFT"
            override = false
            
            addon:SetConfigValue("unitframe", "target", "x", x)
            addon:SetConfigValue("unitframe", "target", "y", y)
            addon:SetConfigValue("unitframe", "target", "anchor", anchor)
            addon:SetConfigValue("unitframe", "target", "anchorParent", anchorParent)
            addon:SetConfigValue("unitframe", "target", "override", override)
        end
        
        MoveTargetFrame(anchor, "UIParent", anchorParent, x, y)
    else
        -- Posición por defecto de Blizzard para TargetFrame
        MoveTargetFrame("TOPLEFT", "UIParent", "TOPLEFT", 216, -4)
    end
end

-- ✅ FUNCIÓN: Cambiar frame del target (PRINCIPAL)
local function ChangeTargetFrame()
    CreateTargetFrameTextures()
    ConfigureTargetElements()
    ApplyTargetConfig()
    UpdateHealthBarColor()
    UpdatePowerTexture()
    
    print("|cFF00FF00[DragonUI]|r TargetFrame configured successfully")
end

-- ✅ FUNCIÓN: Resetear configuración
local function ResetTargetFrame()
    local defaults = {
        scale = 1.0,
        override = false,
        x = 216,
        y = -4,
        anchor = "TOPLEFT",
        anchorParent = "TOPLEFT",
        classcolor = false
    }
    
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "target", key, value)
    end
    
    ApplyTargetConfig()
    print("|cFF00FF00[DragonUI]|r TargetFrame reset to defaults")
end

-- ✅ FUNCIÓN: Refrescar
local function RefreshTargetFrame()
    ChangeTargetFrame()
    if Module.textSystem then
        Module.textSystem.update()
    end
    print("|cFF00FF00[DragonUI]|r TargetFrame refreshed")
end

-- ✅ FUNCIÓN: Hook para mantener fondo del nombre oculto
local function SetupTargetHooks()
    -- Hook para evitar que reaparezca el fondo del nombre
    hooksecurefunc("TargetFrame_CheckClassification", function(frame)
        if frame == TargetFrame and TargetFrameNameBackground then
            TargetFrameNameBackground:SetAlpha(0)
        end
    end)
    
    print("|cFF00FF00[DragonUI]|r Target hooks applied")
end

-- ✅ FUNCIÓN: Inicializar módulo
local function InitializeTargetFrame()
    if Module.initialized then return end

    -- Crear frame auxiliar
    Module.targetFrame = CreateUIFrame(192, 67, "TargetFrame")
    
    -- Configurar hooks
    SetupTargetHooks()
    
    Module.initialized = true
    print("|cFF00FF00[DragonUI]|r TargetFrame module initialized")
end

-- ✅ EVENT FRAME
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")

eventFrame:SetScript("OnEvent", function(self, event, addonName, arg1)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        InitializeTargetFrame()
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        ChangeTargetFrame()
        print("|cFF00FF00[DragonUI]|r TargetFrame fully configured")
        
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateHealthBarColor()
        UpdatePowerTexture()
        
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and arg1 == "target" then
        UpdateHealthBarColor()
        
    elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER") and arg1 == "target" then
        UpdatePowerTexture()
    end
end)

-- ✅ EXPONER FUNCIONES PÚBLICAS
addon.TargetFrame = {
    Refresh = RefreshTargetFrame,
    RefreshTargetFrame = RefreshTargetFrame,
    Reset = ResetTargetFrame,
    anchor = function() return Module.targetFrame end,
    ChangeTargetFrame = ChangeTargetFrame,
    CreateTargetFrameTextures = CreateTargetFrameTextures
}

-- Compatibilidad temporal con el sistema anterior
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeTargetFrame = ChangeTargetFrame
addon.unitframe.ReApplyTargetFrame = RefreshTargetFrame

-- API directa
function addon:RefreshTargetFrame()
    RefreshTargetFrame()
end