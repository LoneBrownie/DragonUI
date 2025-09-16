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
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "focus") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.focus or {}
    return setmetatable(config, {__index = defaults})
end


-- ============================================================================
-- UTILITY FUNCTIONS FOR CENTRALIZED SYSTEM
-- ============================================================================

-- Create auxiliary frame for anchoring (like player.lua/target.lua)
local function CreateUIFrame(width, height, name)
    local frame = CreateFrame("Frame", "DragonUI_" .. name .. "_Anchor", UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -170)
    frame:SetFrameStrata("FULLSCREEN") -- ✅ CAMBIO: Strata más alto para editor
    frame:SetFrameLevel(100) -- ✅ CAMBIO: Level muy alto para estar por encima
    
    -- ✅ AÑADIR: Texturas de editor (como player.lua)
    local editorTexture = frame:CreateTexture(nil, "BACKGROUND")
    editorTexture:SetAllPoints(frame)
    editorTexture:SetTexture(0, 1, 0, 0.3) -- Verde semi-transparente
    editorTexture:Hide() -- Oculto por defecto
    frame.editorTexture = editorTexture
    
    local editorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editorText:SetPoint("CENTER", frame, "CENTER")
    editorText:SetText("Focus Frame")
    editorText:SetTextColor(1, 1, 1, 1)
    editorText:Hide() -- Oculto por defecto
    frame.editorText = editorText
    
    -- ✅ AÑADIR: Funcionalidad de arrastre
    frame:SetMovable(false) -- Deshabilitado por defecto
    frame:EnableMouse(false) -- Deshabilitado por defecto
    frame:SetScript("OnDragStart", function(self)
        if self:IsMovable() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:RegisterForDrag("LeftButton")
    
    return frame
end

-- ✅ FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS (COMO PLAYER.LUA)
local function ApplyWidgetPosition()
    if not Module.focusFrame then
        return
    end

    local widgetConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.focus
    
    if widgetConfig then
        Module.focusFrame:ClearAllPoints()
        Module.focusFrame:SetPoint(widgetConfig.anchor or "TOPLEFT", UIParent, widgetConfig.anchor or "TOPLEFT", 
                                   widgetConfig.posX or 250, widgetConfig.posY or -170)
        
        -- También aplicar al frame de Blizzard
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint("CENTER", Module.focusFrame, "CENTER", 20, -7)
        
        print("|cFF00FF00[DragonUI]|r Focus frame positioned via widgets:", widgetConfig.posX, widgetConfig.posY)
    else
        -- Fallback a posición por defecto
        Module.focusFrame:ClearAllPoints()
        Module.focusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -170)
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint("CENTER", Module.focusFrame, "CENTER", 0, 0)
        print("|cFF00FF00[DragonUI]|r Focus frame positioned with defaults")
    end
end

-- ✅ FUNCIÓN PARA VERIFICAR SI EL FOCUS FRAME DEBE ESTAR VISIBLE
local function ShouldFocusFrameBeVisible()
    return UnitExists("focus")
end

-- ✅ FUNCIONES DE TESTEO SIMPLIFICADAS (estilo RetailUI)
local function ShowFocusFrameTest()
    -- ✅ SISTEMA SIMPLE: Solo llamar al método ShowTest del frame
    if FocusFrame and FocusFrame.ShowTest then
        FocusFrame:ShowTest()
    end
end

local function HideFocusFrameTest()
    -- ✅ SISTEMA SIMPLE: Solo llamar al método HideTest del frame
    if FocusFrame and FocusFrame.HideTest then
        FocusFrame:HideTest()
    end
end

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
    
    -- ✅ CREAR OVERLAY FRAME PARA EL SISTEMA CENTRALIZADO
    if not Module.focusFrame then
        Module.focusFrame = CreateUIFrame(180, 70, "FocusFrame")
        
        -- ✅ REGISTRO AUTOMÁTICO EN EL SISTEMA CENTRALIZADO
        addon:RegisterEditableFrame({
            name = "focus",
            frame = Module.focusFrame,
            blizzardFrame = FocusFrame,
            configPath = {"widgets", "focus"},
            hasTarget = ShouldFocusFrameBeVisible, -- Solo visible cuando hay focus
            showTest = ShowFocusFrameTest,         -- ✅ NUEVO: Mostrar frame fake
            hideTest = HideFocusFrameTest,         -- ✅ NUEVO: Ocultar frame fake
            onHide = function()
                ApplyWidgetPosition() -- Aplicar nueva configuración al salir del editor
            end,
            module = Module
        })
        
        print("|cFF00FF00[DragonUI]|r Focus frame registered in centralized system")
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
    
    -- ✅ APLICAR POSICIÓN DESDE WIDGETS SIEMPRE
    ApplyWidgetPosition()
    
    Module.configured = true
    
    -- ✅ HOOK CRÍTICO: Proteger contra resets de Blizzard
    if not Module.scaleHooked then
        -- Proteger contra cualquier reset de escala que pueda hacer Blizzard
        local originalSetScale = FocusFrame.SetScale
        FocusFrame.SetScale = function(self, scale)
            local config = GetConfig()
            local correctScale = config.scale or 1
            originalSetScale(self, correctScale)
        end
        Module.scaleHooked = true
        print("|cFF00FF00[DragonUI]|r Focus frame scale protection enabled")
    end
    
    -- ✅ MÉTODOS ShowTest Y HideTest EXACTAMENTE COMO RETAILUI (adaptado para Focus)
    if not FocusFrame.ShowTest then
        FocusFrame.ShowTest = function(self)
            -- ✅ MOSTRAR FRAME CON DATOS DEL PLAYER Y NUESTRAS TEXTURAS PERSONALIZADAS
            self:Show()
            
            -- ✅ ASEGURAR QUE EL FOCUSFRAME ESTÉ EN STRATA BAJO PARA QUE EL EDITOR ESTÉ ENCIMA
            self:SetFrameStrata("MEDIUM")
            self:SetFrameLevel(10) -- Nivel bajo para que el frame verde esté encima
            
            -- ✅ ASEGURAR QUE NUESTRAS TEXTURAS PERSONALIZADAS ESTÉN VISIBLES
            if frameElements.background then
                frameElements.background:Show()
            end
            if frameElements.border then
                frameElements.border:Show()
            end
            
            -- ✅ PORTRAIT DEL PLAYER (como RetailUI)
            if FocusFramePortrait then
                SetPortraitTexture(FocusFramePortrait, "player")
            end
            
            -- ✅ BACKGROUND CON COLOR DEL PLAYER Y NUESTRA TEXTURA
            if FocusFrameNameBackground then
                local r, g, b = UnitSelectionColor("player")
                FocusFrameNameBackground:SetVertexColor(r, g, b, 0.8)
                FocusFrameNameBackground:Show()
            end
            
            -- ✅ NOMBRE Y NIVEL DEL PLAYER (conservar color original)
            local nameText = FocusFrameTextureFrameName
            if nameText then
                -- ✅ GUARDAR COLOR ORIGINAL ANTES DE CAMBIAR
                if not nameText.originalColor then
                    local r, g, b, a = nameText:GetTextColor()
                    nameText.originalColor = {r, g, b, a}
                end
                nameText:SetText(UnitName("player"))
                -- ✅ NO CAMBIAR COLOR - mantener el original
            end
            
            local levelText = FocusFrameTextureFrameLevelText  
            if levelText then
                -- ✅ GUARDAR COLOR ORIGINAL ANTES DE CAMBIAR
                if not levelText.originalColor then
                    local r, g, b, a = levelText:GetTextColor()
                    levelText.originalColor = {r, g, b, a}
                end
                levelText:SetText(UnitLevel("player"))
                -- ✅ NO CAMBIAR COLOR - mantener el original
            end
            
            -- ✅ HEALTH BAR CON NUESTRO SISTEMA DE CLASS COLOR
            local healthBar = FocusFrameHealthBar
            if healthBar then
                local curHealth = UnitHealth("player")
                local maxHealth = UnitHealthMax("player")
                healthBar:SetMinMaxValues(0, maxHealth)
                healthBar:SetValue(curHealth)
                
                -- ✅ APLICAR NUESTRO SISTEMA DE CLASS COLOR
                local texture = healthBar:GetStatusBarTexture()
                if texture then
                    local config = GetConfig()
                    if config.classcolor then
                        -- ✅ USAR TEXTURA STATUS PARA CLASS COLOR
                        local statusTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status"
                        texture:SetTexture(statusTexturePath)
                        
                        -- ✅ APLICAR COLOR DE CLASE DEL PLAYER
                        local _, class = UnitClass("player")
                        local color = RAID_CLASS_COLORS[class]
                        if color then
                            texture:SetVertexColor(color.r, color.g, color.b, 1)
                        else
                            texture:SetVertexColor(1, 1, 1, 1)
                        end
                    else
                        -- ✅ USAR TEXTURA NORMAL SIN CLASS COLOR
                        local normalTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
                        texture:SetTexture(normalTexturePath)
                        texture:SetVertexColor(1, 1, 1, 1)
                    end
                    
                    -- ✅ APLICAR COORDS DE TEXTURA
                    texture:SetTexCoord(0, curHealth / maxHealth, 0, 1)
                end
                
                healthBar:Show()
            end
            
            -- ✅ MANA BAR CON NUESTRO SISTEMA DE TEXTURAS DE PODER
            local manaBar = FocusFrameManaBar
            if manaBar then
                local powerType = UnitPowerType("player")
                local curMana = UnitPower("player", powerType)
                local maxMana = UnitPowerMax("player", powerType)
                manaBar:SetMinMaxValues(0, maxMana)
                manaBar:SetValue(curMana)
                
                -- ✅ APLICAR NUESTRA TEXTURA DE PODER PERSONALIZADA
                local texture = manaBar:GetStatusBarTexture()
                if texture then
                    local powerName = POWER_MAP[powerType] or "Mana"
                    local texturePath = TEXTURES.BAR_PREFIX .. powerName
                    texture:SetTexture(texturePath)
                    texture:SetDrawLayer("ARTWORK", 1)
                    texture:SetVertexColor(1, 1, 1, 1)
                    
                    -- ✅ APLICAR COORDS DE TEXTURA
                    if maxMana > 0 then
                        texture:SetTexCoord(0, curMana / maxMana, 0, 1)
                    end
                end
                
                manaBar:Show()
            end
            
            -- ✅ MOSTRAR DECORACIÓN ELITE SI EL PLAYER ES ESPECIAL (Focus no tiene famous NPCs, pero sí clasificación)
            if frameElements.elite then
                local classification = UnitClassification("player")
                local coords = nil
                
                -- ✅ VERIFICAR SI EL PLAYER TIENE CLASIFICACIÓN ESPECIAL
                if classification and classification ~= "normal" then
                    coords = BOSS_COORDS[classification] or BOSS_COORDS.elite
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
        end
        
        FocusFrame.HideTest = function(self)
            -- ✅ RESTAURAR STRATA ORIGINAL DEL FOCUSFRAME
            self:SetFrameStrata("LOW")
            self:SetFrameLevel(1) -- Nivel normal
            
            -- ✅ RESTAURAR COLORES ORIGINALES DE LOS TEXTOS
            local nameText = FocusFrameTextureFrameName
            if nameText and nameText.originalColor then
                nameText:SetVertexColor(nameText.originalColor[1], nameText.originalColor[2], 
                                       nameText.originalColor[3], nameText.originalColor[4])
            end
            
            local levelText = FocusFrameTextureFrameLevelText
            if levelText and levelText.originalColor then
                levelText:SetVertexColor(levelText.originalColor[1], levelText.originalColor[2], 
                                        levelText.originalColor[3], levelText.originalColor[4])
            end
            
            -- ✅ SIMPLE: Solo ocultar si no hay focus real
            if not UnitExists("focus") then
                self:Hide()
            end
        end
        
        print("|cFF00FF00[DragonUI]|r Focus frame test methods added (RetailUI style)")
    end
    
    print("|cFF00FF00[DragonUI]|r FocusFrame configured successfully")
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.initialized = true
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        
        -- ✅ CONFIGURAR TEXT SYSTEM AQUÍ PARA ASEGURAR QUE ESTÉ DISPONIBLE
        if addon.TextSystem and not Module.textSystem and FocusFrame then
            Module.textSystem = addon.TextSystem.SetupFrameTextSystem("focus", "focus", FocusFrame, FocusFrameHealthBar,
                FocusFrameManaBar, "FocusFrame")
            print("|cFF00FF00[DragonUI]|r Focus text system configured after world enter")
        end
        
        if UnitExists("focus") then
            UpdateNameBackground()
            UpdateClassification()
            if Module.textSystem then
                Module.textSystem.update()
            end
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
    
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        local unit = ...
        if unit == "focus" and UnitExists("focus") and Module.textSystem then
            Module.textSystem.update()
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
    -- ✅ EVENTOS CRÍTICOS PARA EL TEXT SYSTEM
    Module.eventsFrame:RegisterEvent("UNIT_HEALTH")
    Module.eventsFrame:RegisterEvent("UNIT_MAXHEALTH") 
    Module.eventsFrame:RegisterEvent("UNIT_POWER_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_MAXPOWER")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end
    
    -- ✅ APLICAR CONFIGURACIÓN INMEDIATAMENTE (incluyendo scale)
    local config = GetConfig()
    
    -- ✅ APLICAR SCALE INMEDIATAMENTE
    FocusFrame:SetScale(config.scale or 1)
    
    -- ✅ APLICAR POSICIÓN DESDE WIDGETS INMEDIATAMENTE
    ApplyWidgetPosition()
    
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
    
    -- ✅ RESETEAR WIDGETS TAMBIÉN
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.focus = {
        anchor = "TOPLEFT",
        posX = 250,
        posY = -170
    }
    
    -- Re-apply position using widgets system
    local config = GetConfig()
    FocusFrame:ClearAllPoints()
    FocusFrame:SetScale(config.scale or 1)
    ApplyWidgetPosition()
    
    print("|cFF00FF00[DragonUI]|r Focus frame reset to defaults with widgets")
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

-- ============================================================================
-- CENTRALIZED SYSTEM SUPPORT FUNCTIONS (like player.lua/target.lua)
-- ============================================================================

-- ✅ FUNCIONES REQUERIDAS POR EL SISTEMA CENTRALIZADO
function Module:LoadDefaultSettings()
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.focus = { 
        anchor = "TOPLEFT", 
        posX = 250, 
        posY = -170 
    }
end

function Module:UpdateWidgets()
    if not addon.db or not addon.db.profile.widgets or not addon.db.profile.widgets.focus then
        print("[DragonUI] Focus widgets config not found, loading defaults")
        self:LoadDefaultSettings()
        return
    end
    
    ApplyWidgetPosition()
    
    local widgetOptions = addon.db.profile.widgets.focus
    print(string.format("[DragonUI] Focus positioned at: %s (%d, %d)", 
          widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY))
end

print("|cFF00FF00[DragonUI]|r Focus module loaded and optimized v1.0 - CENTRALIZED SYSTEM")