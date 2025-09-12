--[[
    Original code by Dmitriy (RetailUI) - Licensed under MIT License
    Adapted for DragonUI
]]

local addon = select(2, ...);

-- ✅ CREAR MÓDULO USANDO EL SISTEMA DE DRAGONUI
local BuffFrameModule = {}
addon.BuffFrameModule = BuffFrameModule

-- ✅ VARIABLES LOCALES
local buffFrame = nil
local toggleButton = nil
local dragonUIBuffFrame = nil  -- ✅ NUESTRO FRAME CUSTOM COMO RETAILUI

-- ✅ FUNCIÓN PARA CREAR EL FRAME CUSTOM Y TOGGLE BUTTON
local function CreateDragonUIBuffFrame()
    if dragonUIBuffFrame then return end
    
    -- ✅ CREAR NUESTRO FRAME CUSTOM COMO EN RETAILUI
    dragonUIBuffFrame = CreateFrame('Frame', "DragonUI_BuffFrame", UIParent)
    dragonUIBuffFrame:SetSize(BuffFrame:GetWidth(), BuffFrame:GetHeight())
    
    -- ✅ CREAR EL TOGGLE BUTTON COMO EN RETAILUI
    toggleButton = CreateFrame('Button', "DragonUI_BuffToggle", UIParent)
    toggleButton.toggle = true
    toggleButton:SetPoint("RIGHT", dragonUIBuffFrame, "RIGHT", 0, -3)  -- ✅ RELATIVO A NUESTRO FRAME
    toggleButton:SetSize(9, 17)
    toggleButton:SetHitRectInsets(0, 0, 0, 0)

    -- ✅ TEXTURAS USANDO ATLAS TEXTURES COMO EN RETAILUI
    local normalTexture = toggleButton:GetNormalTexture() or toggleButton:CreateTexture(nil, "BORDER")
    normalTexture:SetAllPoints(toggleButton)
    SetAtlasTexture(normalTexture, 'CollapseButton-Right')
    toggleButton:SetNormalTexture(normalTexture)

    local highlightTexture = toggleButton:GetHighlightTexture() or toggleButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints(toggleButton)
    SetAtlasTexture(highlightTexture, 'CollapseButton-Right')
    toggleButton:SetHighlightTexture(highlightTexture)

    -- ✅ FUNCIONALIDAD DEL BOTÓN
    toggleButton:SetScript("OnClick", function(self)
        if self.toggle then
            -- Ocultar buffs
            for index = 1, BUFF_ACTUAL_DISPLAY do
                local button = _G['BuffButton' .. index]
                if button then
                    button:Hide()
                end
            end
            -- Cambiar textura a "mostrar" (CollapseButton-Left)
            local normalTexture = self:GetNormalTexture()
            SetAtlasTexture(normalTexture, 'CollapseButton-Left')
            local highlightTexture = self:GetHighlightTexture()
            SetAtlasTexture(highlightTexture, 'CollapseButton-Left')
        else
            -- Mostrar buffs
            for index = 1, BUFF_ACTUAL_DISPLAY do
                local button = _G['BuffButton' .. index]
                if button then
                    button:Show()
                end
            end
            -- Cambiar textura a "ocultar" (CollapseButton-Right)
            local normalTexture = self:GetNormalTexture()
            SetAtlasTexture(normalTexture, 'CollapseButton-Right')
            local highlightTexture = self:GetHighlightTexture()
            SetAtlasTexture(highlightTexture, 'CollapseButton-Right')
        end
        
        self.toggle = not self.toggle
    end)
    
    -- ✅ POSICIONAR CONSOLIDATED BUFFS COMO EN RETAILUI
    if ConsolidatedBuffs then
        ConsolidatedBuffs:SetMovable(true)
        ConsolidatedBuffs:SetUserPlaced(true)
        ConsolidatedBuffs:ClearAllPoints()
        ConsolidatedBuffs:SetPoint("RIGHT", toggleButton, "LEFT", -6, 0)
    end

    return dragonUIBuffFrame
end

-- ✅ FUNCIÓN PARA MOSTRAR/OCULTAR EL BOTÓN SEGÚN BUFFS
local function UpdateToggleButtonVisibility()
    if not toggleButton then return end
    
    local buffCount = 0
    for index = 1, 16 do
        local name = UnitBuff("player", index)
        if name then
            buffCount = buffCount + 1
        end
    end
    
    -- ✅ VERIFICAR TAMBIÉN BUFFS DE VEHÍCULO
    if UnitHasVehicleUI("player") then
        for index = 1, 16 do
            local name = UnitBuff("vehicle", index)
            if name then
                buffCount = buffCount + 1
            end
        end
    end
    
    if buffCount > 0 then
        toggleButton:Show()
    else
        toggleButton:Hide()
    end
end

-- ✅ FUNCIÓN PARA POSICIONAR EL BUFF FRAME COMO EN RETAILUI
function BuffFrameModule:UpdatePosition()
    if not addon.db or not addon.db.profile or not addon.db.profile.buffs then
        return
    end
    
    local settings = addon.db.profile.buffs
    
    -- ✅ POSICIONAR NUESTRO FRAME CUSTOM (NO EL BUFFFRAME NATIVO)
    if dragonUIBuffFrame then
        dragonUIBuffFrame:ClearAllPoints()
        dragonUIBuffFrame:SetPoint(settings.anchor, UIParent, settings.posX, settings.posY)
    end
    
    -- ✅ EL TOGGLE BUTTON YA ESTÁ POSICIONADO RELATIVO AL dragonUIBuffFrame
    -- ✅ EL CONSOLIDATED BUFFS YA ESTÁ POSICIONADO RELATIVO AL TOGGLE BUTTON
    -- ✅ NO NECESITAMOS TOCAR EL BUFFFRAME NATIVO DE BLIZZARD
end

-- ✅ FUNCIÓN PARA HABILITAR/DESHABILITAR EL MÓDULO
function BuffFrameModule:Toggle(enabled)
    if not addon.db or not addon.db.profile then return end
    
    addon.db.profile.buffs.enabled = enabled
    
    if enabled then
        self:Enable()
    else
        self:Disable()
    end
end

-- ✅ FUNCIÓN PARA HABILITAR EL MÓDULO
function BuffFrameModule:Enable()
    if not addon.db.profile.buffs.enabled then return end
    
    -- Crear nuestro frame custom y toggle button
    CreateDragonUIBuffFrame()
    
    -- Configurar eventos
    if not buffFrame then
        buffFrame = CreateFrame("Frame")
        buffFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        buffFrame:RegisterEvent("UNIT_AURA")
        buffFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
        buffFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
        
        buffFrame:SetScript("OnEvent", function(self, event, unit)
            if event == "PLAYER_ENTERING_WORLD" then
                BuffFrameModule:UpdatePosition()
                UpdateToggleButtonVisibility()
            elseif event == "UNIT_AURA" then
                if unit == "player" or unit == "vehicle" then
                    UpdateToggleButtonVisibility()
                end
            elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
                if unit == "player" then
                    UpdateToggleButtonVisibility()
                end
            end
        end)
    end
    
    print("|cff00FF00[DragonUI]|r BuffFrame module enabled")
end

-- ✅ FUNCIÓN PARA DESHABILITAR EL MÓDULO
function BuffFrameModule:Disable()
    if buffFrame then
        buffFrame:UnregisterAllEvents()
        buffFrame:SetScript("OnEvent", nil)
        buffFrame = nil
    end
    
    if toggleButton then
        toggleButton:Hide()
        toggleButton:SetParent(nil)
        toggleButton = nil
    end
    
    if dragonUIBuffFrame then
        dragonUIBuffFrame:Hide()
        dragonUIBuffFrame:SetParent(nil)
        dragonUIBuffFrame = nil
    end
    
    -- ✅ RESTAURAR BUFFS A VISIBLES
    for index = 1, BUFF_ACTUAL_DISPLAY do
        local button = _G['BuffButton' .. index]
        if button then
            button:Show()
        end
    end
    
    print("|cff00FF00[DragonUI]|r BuffFrame module disabled")
end

-- ✅ INICIALIZACIÓN AUTOMÁTICA
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Inicializar el módulo si está habilitado
        if addon.db and addon.db.profile and addon.db.profile.buffs and addon.db.profile.buffs.enabled then
            BuffFrameModule:Enable()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ✅ FUNCIÓN PARA SER LLAMADA DESDE OPTIONS.LUA
function addon:RefreshBuffFrame()
    if BuffFrameModule and addon.db.profile.buffs.enabled then
        BuffFrameModule:UpdatePosition()
    end
end