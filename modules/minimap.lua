--[[
    DragonUI Minimap Module - Adaptado de RetailUI
    Código base por Dmitriy (RetailUI) adaptado para DragonUI
]] local addon = select(2, ...);

-- ✅ Import DragonUI atlas function for tracking icons
local atlas = addon.minimap_SetAtlas;

-- ✅ Ensure _noop function exists
if not addon._noop then
    addon._noop = function() return end
end

-- #################################################################
-- ##                    DragonUI Minimap Module                  ##
-- ##              Unified minimap system (1 file)               ##
-- ##        Based on RetailUI pattern but with DragonUI assets  ##
-- #################################################################

local MinimapModule = {};
addon.MinimapModule = MinimapModule;

MinimapModule.minimapFrame = nil
MinimapModule.borderFrame = nil

local DEFAULT_MINIMAP_WIDTH = Minimap:GetWidth() * 1.36
local DEFAULT_MINIMAP_HEIGHT = Minimap:GetHeight() * 1.36
local blipScale = 1.12
local BORDER_SIZE = 71 * 2 * 2 ^ 0.5

local MINIMAP_TEXTURES = {
    BORDER = "Interface\\AddOns\\DragonUI\\assets\\uiminimapborder"
}

-- ✅ VERIFICAR FUNCIÓN ATLAS AL INICIO
local function GetAtlasFunction()
    -- Verificar múltiples posibles ubicaciones de la función atlas
    if addon.minimap_SetAtlas then
        return addon.minimap_SetAtlas
    elseif addon.SetAtlas then
        return addon.SetAtlas
    elseif SetAtlasTexture then
        return SetAtlasTexture
    else
        print("[DragonUI] ERROR: No atlas function found!")
        return nil
    end
end

local function UpdateCalendarDate()
    local _, _, day = CalendarGetDate()

    local gameTimeFrame = GameTimeFrame

    local normalTexture = gameTimeFrame:GetNormalTexture()
    normalTexture:SetAllPoints(gameTimeFrame)
    SetAtlasTexture(normalTexture, 'Minimap-Calendar-' .. day .. '-Normal')

    local highlightTexture = gameTimeFrame:GetHighlightTexture()
    highlightTexture:SetAllPoints(gameTimeFrame)
    SetAtlasTexture(highlightTexture, 'Minimap-Calendar-' .. day .. '-Highlight')

    local pushedTexture = gameTimeFrame:GetPushedTexture()
    pushedTexture:SetAllPoints(gameTimeFrame)
    SetAtlasTexture(pushedTexture, 'Minimap-Calendar-' .. day .. '-Pushed')
end

local function ReplaceBlizzardFrame(frame)
    local minimapCluster = MinimapCluster
    minimapCluster:ClearAllPoints()
    minimapCluster:SetPoint("CENTER", frame, "CENTER", 0, 0)

    local minimapBorderTop = MinimapBorderTop
    minimapBorderTop:ClearAllPoints()
    minimapBorderTop:SetPoint("TOP", 0, 5)
    SetAtlasTexture(minimapBorderTop, 'Minimap-Border-Top')
    minimapBorderTop:SetSize(156, 20)

    local minimapZoneButton = MinimapZoneTextButton
    minimapZoneButton:ClearAllPoints()
    minimapZoneButton:SetPoint("LEFT", minimapBorderTop, "LEFT", 7, 1)
    minimapZoneButton:SetWidth(108)

    minimapZoneButton:EnableMouse(true)
    minimapZoneButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if WorldMapFrame:IsShown() then
                HideUIPanel(WorldMapFrame)
            else
                ShowUIPanel(WorldMapFrame)
            end
        end
    end)

    local minimapZoneText = MinimapZoneText
    minimapZoneText:SetAllPoints(minimapZoneButton)
    minimapZoneText:SetJustifyH("LEFT")

    local timeClockButton = TimeManagerClockButton
    timeClockButton:GetRegions():Hide()
    timeClockButton:ClearAllPoints()
    timeClockButton:SetPoint("RIGHT", minimapBorderTop, "RIGHT", -5, 0)
    timeClockButton:SetWidth(30)

    local gameTimeFrame = GameTimeFrame
    gameTimeFrame:ClearAllPoints()
    gameTimeFrame:SetPoint("LEFT", minimapBorderTop, "RIGHT", 3, -1)
    gameTimeFrame:SetSize(26, 24)
    gameTimeFrame:SetHitRectInsets(0, 0, 0, 0)
    gameTimeFrame:GetFontString():Hide()

    UpdateCalendarDate()

    local minimapBattlefieldFrame = MiniMapBattlefieldFrame
    minimapBattlefieldFrame:ClearAllPoints()
    minimapBattlefieldFrame:SetPoint("BOTTOMLEFT", 8, 2)

    local minimapInstanceFrame = MiniMapInstanceDifficulty
    minimapInstanceFrame:ClearAllPoints()
    minimapInstanceFrame:SetPoint("TOP", minimapBorderTop, 'BOTTOMRIGHT', -18, 9)

    local minimapTracking = MiniMapTracking
    minimapTracking:ClearAllPoints()
    minimapTracking:SetPoint("RIGHT", minimapBorderTop, "LEFT", -3, 0)
    minimapTracking:SetSize(26, 24)

    local minimapMailFrame = MiniMapMailFrame
    minimapMailFrame:ClearAllPoints()
    minimapMailFrame:SetPoint("TOP", minimapTracking, "BOTTOM", 0, -3)
    minimapMailFrame:SetSize(24, 18)
    minimapMailFrame:SetHitRectInsets(0, 0, 0, 0)

    local minimapMailIconTexture = MiniMapMailIcon
    minimapMailIconTexture:SetAllPoints(minimapMailFrame)
    SetAtlasTexture(minimapMailIconTexture, 'Minimap-Mail-Normal')

    local backgroundTexture = _G[minimapTracking:GetName() .. "Background"]
    backgroundTexture:SetAllPoints(minimapTracking)
    SetAtlasTexture(backgroundTexture, 'Minimap-Tracking-Background')

    local minimapTrackingButton = _G[minimapTracking:GetName() .. 'Button']
    minimapTrackingButton:ClearAllPoints()
    minimapTrackingButton:SetPoint("CENTER", 0, 0)

    minimapTrackingButton:SetSize(17, 15)
    minimapTrackingButton:SetHitRectInsets(0, 0, 0, 0)

    -- ✅ Enable right-click functionality
    minimapTrackingButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local shineTexture = _G[minimapTrackingButton:GetName() .. "Shine"]
    shineTexture:SetTexture(nil)

    local normalTexture = minimapTrackingButton:GetNormalTexture() or minimapTrackingButton:CreateTexture(nil, "BORDER")
    normalTexture:SetAllPoints(minimapTrackingButton)
    SetAtlasTexture(normalTexture, 'Minimap-Tracking-Normal')

    minimapTrackingButton:SetNormalTexture(normalTexture)

    local highlightTexture = minimapTrackingButton:GetHighlightTexture()
    highlightTexture:SetAllPoints(minimapTrackingButton)
    SetAtlasTexture(highlightTexture, 'Minimap-Tracking-Highlight')

    local pushedTexture = minimapTrackingButton:GetPushedTexture() or minimapTrackingButton:CreateTexture(nil, "BORDER")
    pushedTexture:SetAllPoints(minimapTrackingButton)
    SetAtlasTexture(pushedTexture, 'Minimap-Tracking-Pushed')

    minimapTrackingButton:SetPushedTexture(pushedTexture)

    local minimapFrame = Minimap
    minimapFrame:ClearAllPoints()
    minimapFrame:SetPoint("CENTER", minimapCluster, "CENTER", 0, -30)
    minimapFrame:SetWidth(DEFAULT_MINIMAP_WIDTH / blipScale)
    minimapFrame:SetHeight(DEFAULT_MINIMAP_HEIGHT / blipScale)
    minimapFrame:SetScale(blipScale)
    minimapFrame:SetMaskTexture("Interface\\AddOns\\DragonUI\\assets\\uiminimapmask.tga")

    -- POI (Point of Interest) Custom Textures
    minimapFrame:SetStaticPOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-static")
    minimapFrame:SetCorpsePOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-corpse")
    minimapFrame:SetPOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-guard")
    minimapFrame:SetPlayerTexture("Interface\\AddOns\\DragonUI\\assets\\poi-player")

    -- Player arrow size (configurable)
    local playerArrowSize = addon.db and addon.db.profile and addon.db.profile.minimap and
                                addon.db.profile.minimap.player_arrow_size or 16
    minimapFrame:SetPlayerTextureHeight(playerArrowSize)
    minimapFrame:SetPlayerTextureWidth(playerArrowSize)

    -- Blip texture (always use DragonUI modern icons)
    minimapFrame:SetBlipTexture("Interface\\AddOns\\DragonUI\\assets\\objecticons")
    local MINIMAP_POINTS = {}
    for i = 1, Minimap:GetNumPoints() do
        MINIMAP_POINTS[i] = {Minimap:GetPoint(i)}
    end

    for _, regions in ipairs {Minimap:GetChildren()} do
        if regions ~= WatchFrame and regions ~= _G.WatchFrame then
            regions:SetScale(1 / blipScale)
        end
    end

    for _, points in ipairs(MINIMAP_POINTS) do
        Minimap:SetPoint(points[1], points[2], points[3], points[4] / blipScale, points[5] / blipScale)
    end
    function GetMinimapShape()
        return "ROUND"
    end

    -- Enable mouse wheel zooming on minimap
    minimapFrame:EnableMouseWheel(true)
    minimapFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            -- Scroll up = Zoom in
            Minimap_ZoomIn()
        else
            -- Scroll down = Zoom out
            Minimap_ZoomOut()
        end
    end)

    local minimapBackdropTexture = MinimapBackdrop
    minimapBackdropTexture:ClearAllPoints()
    minimapBackdropTexture:SetPoint("CENTER", minimapFrame, "CENTER", 0, 3)

    local minimapBorderTexture = MinimapBorder
    minimapBorderTexture:Hide()
    if not Minimap.Circle then
        Minimap.Circle = MinimapBackdrop:CreateTexture(nil, 'ARTWORK')

        Minimap.Circle:SetSize(BORDER_SIZE, BORDER_SIZE)
        Minimap.Circle:SetPoint('CENTER', Minimap, 'CENTER')
        Minimap.Circle:SetTexture("Interface\\AddOns\\DragonUI\\assets\\uiminimapborder.tga")
    end

    local zoomInButton = MinimapZoomIn
    zoomInButton:ClearAllPoints()
    zoomInButton:SetPoint("BOTTOMRIGHT", 0, 15)

    zoomInButton:SetSize(25, 24)
    zoomInButton:SetHitRectInsets(0, 0, 0, 0)

    normalTexture = zoomInButton:GetNormalTexture()
    normalTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(normalTexture, 'Minimap-ZoomIn-Normal')

    highlightTexture = zoomInButton:GetHighlightTexture()
    highlightTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(highlightTexture, 'Minimap-ZoomIn-Highlight')

    pushedTexture = zoomInButton:GetPushedTexture()
    pushedTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(pushedTexture, 'Minimap-ZoomIn-Pushed')

    local disabledTexture = zoomInButton:GetDisabledTexture()
    disabledTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(disabledTexture, 'Minimap-ZoomIn-Pushed')

    local zoomOutButton = MinimapZoomOut
    zoomOutButton:ClearAllPoints()
    zoomOutButton:SetPoint("BOTTOMRIGHT", -22, 0)

    zoomOutButton:SetSize(20, 12)
    zoomOutButton:SetHitRectInsets(0, 0, 0, 0)

    normalTexture = zoomOutButton:GetNormalTexture()
    normalTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(normalTexture, 'Minimap-ZoomOut-Normal')

    highlightTexture = zoomOutButton:GetHighlightTexture()
    highlightTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(highlightTexture, 'Minimap-ZoomOut-Highlight')

    pushedTexture = zoomOutButton:GetPushedTexture()
    pushedTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(pushedTexture, 'Minimap-ZoomOut-Pushed')

    disabledTexture = zoomOutButton:GetDisabledTexture()
    disabledTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(disabledTexture, 'Minimap-ZoomOut-Pushed')

    -- ✅ Add right-click functionality to clear tracking
    minimapTrackingButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Set tracking to none
            SetTracking()
            -- Update the tracking display
            MinimapModule:UpdateTrackingIcon()
            print("|cFF00FF00[DragonUI]|r Tracking cleared")
        else
            -- Left click - use default behavior
            ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "MiniMapTrackingButton")
        end
    end)

    -- ✅ CONTROLAR MANUALMENTE EL MOVIMIENTO DEL BOTÓN
    minimapTrackingButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            -- Mover el icono/botón manualmente - TÚ CONTROLAS CUÁNTO
            if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
                -- Mover icono OLD STYLE: 1 pixel abajo-derecha (sutil)
                MiniMapTrackingIcon:ClearAllPoints()
                MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 2, -2)
            end
        end
    end)

    minimapTrackingButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            -- Restaurar posición original cuando sueltas
            if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
                MiniMapTrackingIcon:ClearAllPoints()
                MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)
            end
        end
    end)

    -- ✅ HOOK PARA RESETEAR POSICIÓN DEL ICONO DESPUÉS DE CLICKS
    local function ResetTrackingIconPosition()
        if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
            MiniMapTrackingIcon:ClearAllPoints()
            MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)
        end
    end

    -- Hook al cierre del dropdown
    hooksecurefunc("CloseDropDownMenus", ResetTrackingIconPosition)
end

local function CreateMinimapBorderFrame(width, height)
    local minimapBorderFrame = CreateFrame('Frame', UIParent)
    minimapBorderFrame:SetSize(width, height)
    minimapBorderFrame:SetScript("OnUpdate", function(self)
        local angle = GetPlayerFacing()
        self.border:SetRotation(angle)
    end)

    do
        local texture = minimapBorderFrame:CreateTexture(nil, "BORDER")
        texture:SetAllPoints(minimapBorderFrame)
        texture:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\Minimap\\MinimapBorder.blp")

        minimapBorderFrame.border = texture
    end

    minimapBorderFrame:Hide()
    return minimapBorderFrame
end

-- ✅ ADDON ICON SKINNING: Aplicar borders personalizados a iconos de addons (del minimap_core.lua)
local WHITE_LIST = {
    'MiniMapBattlefieldFrame','MiniMapTrackingButton','MiniMapMailFrame','HelpOpenTicketButton',
    'GatherMatePin','HandyNotesPin','TimeManagerClockButton','Archy','GatherNote','MinimMap',
    'Spy_MapNoteList_mini','ZGVMarker','poiWorldMapPOIFrame','WorldMapPOIFrame','QuestMapPOI',
    'GameTimeFrame'
}

local function IsFrameWhitelisted(frameName)
    if not frameName then return false end
    
    for _, whitelistName in pairs(WHITE_LIST) do
        if frameName:match(whitelistName) then
            return true
        end
    end
    return false
end

-- Funciones de fade para hover effect
local function fadein(self) 
    UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1.0) 
end

local function fadeout(self) 
    UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0.2) 
end

-- Función para aplicar skin personalizado a iconos de addons (COPIA EXACTA del oldminimapcore.lua)
local function ApplyAddonIconSkin(button)
    if not button or button:GetObjectType() ~= 'Button' then
        return
    end
    
    local frameName = button:GetName()
    if IsFrameWhitelisted(frameName) then
        return
    end
    
    -- Procesar texturas EXACTO como oldminimapcore.lua
    for index = 1, button:GetNumRegions() do
        local region = select(index, button:GetRegions())
        if region:GetObjectType() == 'Texture' then
            local name = region:GetTexture()
            if name and (name:find('Border') or name:find('Background') or name:find('AlphaMask')) then
                region:SetTexture(nil)
            else
                region:ClearAllPoints()
                region:SetPoint('TOPLEFT', button, 'TOPLEFT', 2, -2)
                region:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 2)
                region:SetTexCoord(0.1, 0.9, 0.1, 0.9)
                region:SetDrawLayer('ARTWORK')
                if frameName == 'PS_MinimapButton' then
                    region.SetPoint = addon._noop
                end
            end
        end
    end
    
    -- Limpiar texturas del botón EXACTO como oldminimapcore.lua
    button:SetPushedTexture(nil)
    button:SetHighlightTexture(nil)
    button:SetDisabledTexture(nil)
    button:SetSize(22, 22)
    
    -- Aplicar border EXACTO como oldminimapcore.lua
    button.circle = button:CreateTexture(nil, 'OVERLAY')
    button.circle:SetSize(22, 22)
    button.circle:SetPoint('CENTER', button)
    button.circle:SetTexture("Interface\\AddOns\\DragonUI\\assets\\border_buttons.tga")
    
    -- Sistema de fade EXACTO como oldminimapcore.lua
    local fadeEnabled = addon.db and addon.db.profile and addon.db.profile.minimap and 
                       addon.db.profile.minimap.addon_button_fade
    
    if fadeEnabled then
        button:SetAlpha(0.2)
        button:HookScript('OnEnter', fadein)
        button:HookScript('OnLeave', fadeout)
    else
        button:SetAlpha(1)
    end
end

-- ✅ BORDER REMOVAL: Aplicar skin a iconos (SIMPLE como oldminimapcore.lua)
local function RemoveAllMinimapIconBorders()
    
    -- PVP/Battlefield borders
    if MiniMapBattlefieldIcon then 
        MiniMapBattlefieldIcon:Hide() 
    end
    if MiniMapBattlefieldBorder then 
        MiniMapBattlefieldBorder:Hide() 
    end
    
    -- LFG border
    if MiniMapLFGFrameBorder then
        MiniMapLFGFrameBorder:SetTexture(nil)
    end
    
    -- ✅ APLICAR SKIN SIMPLE A TODOS LOS BOTONES
    local function ApplySkinsToAllButtons()
        -- Verificar si el skinning está habilitado
        local skinEnabled = addon.db and addon.db.profile and addon.db.profile.minimap and 
                           addon.db.profile.minimap.addon_button_skin
        
        if not skinEnabled then
            return
        end
        
        for i = 1, Minimap:GetNumChildren() do
            local child = select(i, Minimap:GetChildren())
            if child and child:GetObjectType() == "Button" then
                ApplyAddonIconSkin(child)
            end
        end
    end
    
    -- Aplicar inmediatamente
    ApplySkinsToAllButtons()
end

-- ✅ PVP STYLING: Estilizar frame PVP con faction detection (del minimapa_old.lua)
local function StylePVPBattlefieldFrame()
    if not MiniMapBattlefieldFrame then return end
    
    -- Configurar el frame PVP como en minimapa_old.lua
    MiniMapBattlefieldFrame:SetSize(44, 44)
    MiniMapBattlefieldFrame:ClearAllPoints()
    MiniMapBattlefieldFrame:SetPoint('BOTTOMLEFT', Minimap, 0, 18)
    MiniMapBattlefieldFrame:SetNormalTexture('')
    MiniMapBattlefieldFrame:SetPushedTexture('')

    -- Detectar facción del jugador y aplicar texturas apropiadas
    local faction = string.lower(UnitFactionGroup('player'))
    
    -- Aplicar texturas usando SetAtlasTexture
    if MiniMapBattlefieldFrame:GetNormalTexture() then
        SetAtlasTexture(MiniMapBattlefieldFrame:GetNormalTexture(), 'Minimap-PVP-' .. faction .. '-Normal')
    end
    if MiniMapBattlefieldFrame:GetPushedTexture() then
        SetAtlasTexture(MiniMapBattlefieldFrame:GetPushedTexture(), 'Minimap-PVP-' .. faction .. '-Pushed')
    end

    -- Configurar script de click como en minimapa_old.lua
    MiniMapBattlefieldFrame:SetScript('OnClick', function(self, button)
        GameTooltip:Hide()
        if MiniMapBattlefieldFrame.status == "active" then
            if button == "RightButton" then
                ToggleDropDownMenu(1, nil, MiniMapBattlefieldDropDown, "MiniMapBattlefieldFrame", 0, -5)
            elseif IsShiftKeyDown() then
                ToggleBattlefieldMinimap()
            else
                ToggleWorldStateScoreFrame()
            end
        elseif button == "RightButton" then
            ToggleDropDownMenu(1, nil, MiniMapBattlefieldDropDown, "MiniMapBattlefieldFrame", 0, -5)
        end
    end)
end

local function RemoveBlizzardFrames()
    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:Hide()
        MiniMapWorldMapButton:UnregisterAllEvents()
        MiniMapWorldMapButton:SetScript("OnClick", nil)
        MiniMapWorldMapButton:SetScript("OnEnter", nil)
        MiniMapWorldMapButton:SetScript("OnLeave", nil)
    end

    local blizzFrames =
        {MiniMapTrackingIcon, MiniMapTrackingIconOverlay, MiniMapMailBorder, MiniMapTrackingButtonBorder}

    for _, frame in pairs(blizzFrames) do
        frame:SetAlpha(0)
    end
    
    -- ✅ LLAMAR A LAS NUEVAS FUNCIONES
    RemoveAllMinimapIconBorders()
    StylePVPBattlefieldFrame()
end

local function Minimap_UpdateRotationSetting()
    local minimapBorder = MinimapBorder
    if GetCVar("rotateMinimap") == "1" then
        if MinimapModule.borderFrame then
            MinimapModule.borderFrame:Show()
        end
        minimapBorder:Hide()
    else
        if MinimapModule.borderFrame then
            MinimapModule.borderFrame:Hide()
        end
        minimapBorder:Show()
    end

    MinimapNorthTag:Hide()
    MinimapCompassTexture:Hide()
end

local selectedRaidDifficulty
local allowedRaidDifficulty

-- ✅ TRACKING UPDATE FUNCTION - Using exact logic from minimap_map.lua with atlas textures
function MinimapModule:UpdateTrackingIcon()
    local texture = GetTrackingTexture()

    local useOldStyle = addon.db and addon.db.profile and addon.db.profile.minimap and
                            addon.db.profile.minimap.tracking_icons

    -- ✅ VERIFICACIÓN DE SEGURIDAD
    if not addon or not addon.db then
        return
    end

    if useOldStyle == nil then
        useOldStyle = false
    end

    -- ✅ VERIFICACIÓN ADICIONAL: Asegurar que los frames existen
    if not MiniMapTrackingIcon or not MiniMapTrackingButton then
        return
    end

    print("  - FINAL MODE:", useOldStyle and "OLD STYLE" or "MODERN STYLE")

    if useOldStyle then
        print("  - Using OLD STYLE tracking")
        if texture == 'Interface\\Minimap\\Tracking\\None' then
            print("    - No tracking: showing default magnifying glass")
            -- OLD STYLE + No tracking = Mostrar icono de lupa por defecto
            MiniMapTrackingIcon:SetTexture('')
            MiniMapTrackingIcon:SetAlpha(0)

            -- Mostrar el botón moderno como "icono de lupa" por defecto
            local normalTexture = MiniMapTrackingButton:GetNormalTexture()
            if normalTexture then
                SetAtlasTexture(normalTexture, 'Minimap-Tracking-Normal')
            end

            local pushedTexture = MiniMapTrackingButton:GetPushedTexture()
            if pushedTexture then
                SetAtlasTexture(pushedTexture, 'Minimap-Tracking-Pushed')
            end

            local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
            if highlightTexture then
                SetAtlasTexture(highlightTexture, 'Minimap-Tracking-Highlight')
            end
        else
            print("    - Tracking active: showing classic icon", texture)
            -- OLD STYLE + Tracking active = Mostrar el icono específico del tracking
            MiniMapTrackingIcon:SetTexture(texture)
            MiniMapTrackingIcon:SetTexCoord(0, 1, 0, 1)
            MiniMapTrackingIcon:SetSize(20, 20)
            MiniMapTrackingIcon:SetAlpha(1)
            MiniMapTrackingIcon:ClearAllPoints()
            MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)

            -- Limpiar texturas del botón para que no interfieran con el icono específico
            MiniMapTrackingButton:SetNormalTexture('')
            MiniMapTrackingButton:SetPushedTexture('')
            local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
            if highlightTexture then
                highlightTexture:SetTexture('')
            end
        end
    else
        print("  - Using MODERN STYLE tracking")
        -- ✅ MODERN STYLE: Siempre mostrar botón moderno (RetailUI style)

        -- Limpiar el icono clásico para que no interfiera
        MiniMapTrackingIcon:SetTexture('')
        MiniMapTrackingIcon:SetAlpha(0)

        -- Usar las texturas de RetailUI que ya funcionan (las que están en ReplaceBlizzardFrame)
        local normalTexture = MiniMapTrackingButton:GetNormalTexture()
        if normalTexture then
            SetAtlasTexture(normalTexture, 'Minimap-Tracking-Normal')
        end

        local pushedTexture = MiniMapTrackingButton:GetPushedTexture()
        if pushedTexture then
            SetAtlasTexture(pushedTexture, 'Minimap-Tracking-Pushed')
        end

        local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
        if highlightTexture then
            SetAtlasTexture(highlightTexture, 'Minimap-Tracking-Highlight')
        end

        print("    - Modern binoculars button applied")
    end

    -- Siempre ocultar overlay
    if MiniMapTrackingIconOverlay then
        MiniMapTrackingIconOverlay:SetAlpha(0)
    end
end

local function MiniMapInstanceDifficulty_OnEvent(self)
    local _, instanceType, difficulty, _, maxPlayers, playerDifficulty, isDynamicInstance = GetInstanceInfo()
    if (instanceType == "party" or instanceType == "raid") and not (difficulty == 1 and maxPlayers == 5) then
        local isHeroic = false
        if instanceType == "party" and difficulty == 2 then
            isHeroic = true
        elseif instanceType == "raid" then
            if isDynamicInstance then
                selectedRaidDifficulty = difficulty
                if playerDifficulty == 1 then
                    if selectedRaidDifficulty <= 2 then
                        selectedRaidDifficulty = selectedRaidDifficulty + 2
                    end
                    isHeroic = true
                end
                -- if modified difficulty is normal then you are allowed to select heroic, and vice-versa
                if selectedRaidDifficulty == 1 then
                    allowedRaidDifficulty = 3
                elseif selectedRaidDifficulty == 2 then
                    allowedRaidDifficulty = 4
                elseif selectedRaidDifficulty == 3 then
                    allowedRaidDifficulty = 1
                elseif selectedRaidDifficulty == 4 then
                    allowedRaidDifficulty = 2
                end
                allowedRaidDifficulty = "RAID_DIFFICULTY" .. allowedRaidDifficulty
            elseif difficulty > 2 then
                isHeroic = true
            end
        end

        MiniMapInstanceDifficultyText:SetText(maxPlayers)
        -- the 1 looks a little off when text is centered
        local xOffset = 0
        if maxPlayers >= 10 and maxPlayers <= 19 then
            xOffset = -1
        end

        local minimapInstanceTexture = MiniMapInstanceDifficultyTexture

        if isHeroic then
            SetAtlasTexture(minimapInstanceTexture, 'Minimap-GuildBanner-Heroic')
            MiniMapInstanceDifficultyText:SetPoint("CENTER", xOffset, -6)
        else
            SetAtlasTexture(minimapInstanceTexture, 'Minimap-GuildBanner-Normal')
            MiniMapInstanceDifficultyText:SetPoint("CENTER", xOffset, 2)
        end
        minimapInstanceTexture:SetSize(minimapInstanceTexture:GetWidth() * 0.45,
            minimapInstanceTexture:GetHeight() * 0.45)
        self:Show()
    else
        self:Hide()
    end
end

function MinimapModule:Initialize()
    -- Load TimeManager addon if not loaded
    if not IsAddOnLoaded('Blizzard_TimeManager') then
        LoadAddOn('Blizzard_TimeManager')
    end

    -- Create a simple frame instead of CreateUIFrame
    self.minimapFrame = CreateFrame('Frame', 'DragonUIMinimapFrame', UIParent)
    self.minimapFrame:SetSize(230, 230)

    -- ✅ USAR COORDENADAS DE LA DATABASE POR DEFECTO
    local x = addon.db and addon.db.profile and addon.db.profile.minimap and addon.db.profile.minimap.x or -7
    local y = addon.db and addon.db.profile and addon.db.profile.minimap and addon.db.profile.minimap.y or 0
    self.minimapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)

    self.borderFrame = CreateMinimapBorderFrame(232, 232)
    self.borderFrame:SetPoint("CENTER", MinimapBorder, "CENTER", 0, -2)

    RemoveBlizzardFrames()
    ReplaceBlizzardFrame(self.minimapFrame)

    -- ✅ AÑADIR ESTA LÍNEA PARA APLICAR TODAS LAS CONFIGURACIONES AL INICIO
    self:UpdateSettings()

    -- Hook tracking changes to update icon automatically
    MiniMapTrackingButton:HookScript("OnEvent", function()
        self:UpdateTrackingIcon()
    end)

    -- Initial tracking icon update
    self:UpdateTrackingIcon()

    print("|cFF00FF00[DragonUI]|r Minimap module initialized")
end

-- Eliminar las funciones que no existen más y convertir en funciones DragonUI
function MinimapModule:UpdateSettings()
    -- Función para actualizar configuraciones si es necesario
    if self.minimapFrame then
        local x = addon.db and addon.db.profile and addon.db.profile.minimap and addon.db.profile.minimap.x or -7
        local y = addon.db and addon.db.profile and addon.db.profile.minimap and addon.db.profile.minimap.y or 0
        local scale = addon.db and addon.db.profile and addon.db.profile.minimap and addon.db.profile.minimap.scale or
                          1.0

        self.minimapFrame:ClearAllPoints()
        self.minimapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)

        -- ✅ ESCALAR ELEMENTOS INDIVIDUALES EN LUGAR DEL FRAME PADRE

        -- Escalar el MinimapCluster completo
        if MinimapCluster then
            MinimapCluster:SetScale(scale)
        end

        -- ✅ TAMBIÉN ESCALAR EL BORDER FRAME
        if self.borderFrame then
            self.borderFrame:SetScale(scale)
        end

        -- ✅ APLICAR CONFIGURACIONES ADICIONALES
        self:ApplyAllSettings()
    end

    -- Update blip texture (always use DragonUI modern icons)
    Minimap:SetBlipTexture("Interface\\AddOns\\DragonUI\\assets\\objecticons")

    -- Update player arrow size
    local playerArrowSize = addon.db.profile.minimap.player_arrow_size
    if playerArrowSize then
        Minimap:SetPlayerTextureHeight(playerArrowSize)
        Minimap:SetPlayerTextureWidth(playerArrowSize)
    end

    -- ✅ ACTUALIZAR TRACKING ICON TAMBIÉN
    self:UpdateTrackingIcon()
end

local function GetClockTextFrame()
    if not TimeManagerClockButton then
        return nil
    end

    -- Intentar múltiples métodos para encontrar el texto del reloj
    local clockText = TimeManagerClockButton.text
    if clockText then
        return clockText
    end

    clockText = TimeManagerClockButton:GetFontString()
    if clockText then
        return clockText
    end

    -- Buscar en los children
    for i = 1, TimeManagerClockButton:GetNumChildren() do
        local child = select(i, TimeManagerClockButton:GetChildren())
        if child and child.GetFont then
            return child
        end
    end

    -- Buscar en las regiones
    for i = 1, TimeManagerClockButton:GetNumRegions() do
        local region = select(i, TimeManagerClockButton:GetRegions())
        if region and region.GetFont then
            return region
        end
    end

    return nil
end

-- ✅ NUEVA FUNCIÓN PARA APLICAR TODAS LAS CONFIGURACIONES
function MinimapModule:ApplyAllSettings()
    if not addon.db or not addon.db.profile or not addon.db.profile.minimap then
        return
    end

    local settings = addon.db.profile.minimap

    -- ✅ APLICAR BORDER ALPHA
    if MinimapBorderTop and settings.border_alpha then
        MinimapBorderTop:SetAlpha(settings.border_alpha)
    end

    -- ✅ APLICAR ZOOM BUTTONS VISIBILITY
    if settings.zoom_buttons ~= nil then
        if MinimapZoomIn and MinimapZoomOut then
            if settings.zoom_buttons then
                MinimapZoomIn:Show()
                MinimapZoomOut:Show()
            else
                MinimapZoomIn:Hide()
                MinimapZoomOut:Hide()
            end
        end
    end

    -- ✅ APLICAR CALENDAR VISIBILITY
    if settings.calendar ~= nil then
        if GameTimeFrame then
            if settings.calendar then
                GameTimeFrame:Show()
            else
                GameTimeFrame:Hide()
            end
        end
    end

    -- ✅ APLICAR CLOCK VISIBILITY
    if settings.clock ~= nil then
        if TimeManagerClockButton then
            if settings.clock then
                TimeManagerClockButton:Show()
            else
                TimeManagerClockButton:Hide()
            end
        end
    end

    -- ✅ APLICAR CLOCK FONT SIZE (MEJORADO)
    if settings.clock_font_size and TimeManagerClockButton then
        local clockText = GetClockTextFrame()
        if clockText then
            local font, _, flags = clockText:GetFont()
            clockText:SetFont(font, settings.clock_font_size, flags)
            print("|cff00FF00[DragonUI]|r Clock font size applied:", settings.clock_font_size)
        else
            print("|cffFF6600[DragonUI]|r Warning: Clock text frame not found for font size")
        end
    end

    -- ✅ APLICAR ZONE TEXT FONT SIZE
    if settings.zonetext_font_size and MinimapZoneText then
        local font, _, flags = MinimapZoneText:GetFont()
        MinimapZoneText:SetFont(font, settings.zonetext_font_size, flags)
    end
end
-- ✅ PATRÓN RETAILUI: Editor Mode Functions
function MinimapModule:ShowEditorTest()
    -- Hacer minimap draggable
    if self.minimapFrame then
        self.minimapFrame:SetMovable(true)
        self.minimapFrame:EnableMouse(true)
        self.minimapFrame:RegisterForDrag("LeftButton")

        self.minimapFrame:SetScript("OnDragStart", function(frame)
            frame:StartMoving()
        end)

        self.minimapFrame:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            -- Guardar posición
            local point, _, relativePoint, x, y = frame:GetPoint()
            if addon.db and addon.db.profile and addon.db.profile.minimap then
                addon.db.profile.minimap.point = point
                addon.db.profile.minimap.relativePoint = relativePoint
                addon.db.profile.minimap.x = x
                addon.db.profile.minimap.y = y
            end
        end)

        print("|cFF00FF00[DragonUI]|r Minimap now draggable")
    end
end

function MinimapModule:HideEditorTest(savePosition)
    -- Deshabilitar drag
    if self.minimapFrame then
        self.minimapFrame:SetMovable(false)
        self.minimapFrame:EnableMouse(false)
        self.minimapFrame:SetScript("OnDragStart", nil)
        self.minimapFrame:SetScript("OnDragStop", nil)

        if savePosition then
            self:UpdateSettings()
            print("|cFF00FF00[DragonUI]|r Minimap position saved")
        end
    end
end

-- Función de refresh para ser llamada desde options.lua
function addon:RefreshMinimap()
    MinimapModule:UpdateSettings()
    -- Also update tracking icon when settings change
    MinimapModule:UpdateTrackingIcon()
    -- ✅ NUEVO: Refrescar skinning de iconos de addons
    RemoveAllMinimapIconBorders()
end

-- ✅ NUEVA FUNCIÓN: Limpiar skinning de todos los botones
local function CleanAllMinimapButtons()
    for i = 1, Minimap:GetNumChildren() do
        local child = select(i, Minimap:GetChildren())
        if child and child:GetObjectType() == "Button" and child.circle then
            -- Limpiar el border del oldminimapcore.lua style
            child.circle:Hide()
            child.circle = nil
        end
    end
end

-- ✅ FUNCIÓN PARA DEBUGGING
function addon:DebugMinimapButtons()
    print("|cFFFFFF00[DragonUI Debug]|r Minimap buttons:")
    for i = 1, Minimap:GetNumChildren() do
        local child = select(i, Minimap:GetChildren())
        if child and child:GetObjectType() == "Button" then
            local name = child:GetName() or "Unnamed"
            local hasBorder = child.circle and "YES" or "NO"
            local width, height = child:GetSize()
            print(string.format("  - %s: %dx%d, Border: %s", name, width, height, hasBorder))
        end
    end
end

-- =================================================================
-- INICIALIZACIÓN
-- =================================================================

-- Inicializar cuando el addon esté listo
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Esperar a que todo esté cargado
    elseif event == "PLAYER_ENTERING_WORLD" then
        MinimapModule:Initialize()
        self:UnregisterAllEvents()
    end
end)
