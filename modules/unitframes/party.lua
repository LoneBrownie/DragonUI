-- ===============================================================
-- DRAGONUI PARTY FRAMES MODULE
-- ===============================================================
local addon = select(2, ...)

-- ===============================================================
-- EARLY EXIT CHECK
-- ===============================================================
-- ✅ SIMPLIFICADO: Solo verificar que addon.db existe, no específicamente unitframe.party
if not addon or not addon.db then
    return -- Exit early if database not ready
end

-- ===============================================================
-- IMPORTS AND GLOBALS
-- ===============================================================

-- Cache globals and APIs
local _G = _G
local unpack = unpack
local select = select
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitName, UnitClass = UnitName, UnitClass
local UnitExists, UnitIsConnected = UnitExists, UnitIsConnected
local UnitInRange, UnitIsDeadOrGhost = UnitInRange, UnitIsDeadOrGhost
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS or 4

-- ===============================================================
-- MODULE NAMESPACE AND STORAGE
-- ===============================================================

-- Module namespace
local PartyFrames = {}
addon.PartyFrames = PartyFrames

PartyFrames.textElements = {}
PartyFrames.anchor = nil
PartyFrames.initialized = false

-- ===============================================================
-- CONSTANTS AND CONFIGURATION
-- ===============================================================

-- Texture paths for our custom party frames
local TEXTURES = {
    healthBarStatus = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status",
    frame = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\uipartyframe",
    border = "Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    healthBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health",
    manaBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana",
    focusBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Focus",
    rageBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Rage",
    energyBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Energy",
    runicPowerBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-RunicPower"
}

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Create auxiliary frame for anchoring (like target.lua)
local function CreatePartyAnchorFrame()
    if PartyFrames.anchor then
        return PartyFrames.anchor
    end

    local frame = CreateFrame("Frame", "DragonUI_Party_Anchor", UIParent)
    frame:SetSize(120, 200) -- Size to encompass all 4 party frames
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -200) -- Default position
    frame:SetFrameStrata("LOW")
    
    -- ✅ AÑADIR: Texturas de editor (como target.lua)
    local editorTexture = frame:CreateTexture(nil, "BACKGROUND")
    editorTexture:SetAllPoints(frame)
    editorTexture:SetTexture(0, 1, 0, 0.3) -- Verde semi-transparente para distinguir del target
    editorTexture:Hide() -- Oculto por defecto
    frame.editorTexture = editorTexture
    
    local editorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editorText:SetPoint("CENTER", frame, "CENTER")
    editorText:SetText("Party Frames")
    editorText:SetTextColor(1, 1, 1, 1)
    editorText:Hide() -- Oculto por defecto
    frame.editorText = editorText
    
    -- ✅ AÑADIR: Funcionalidad de arrastre
    frame:SetMovable(false) -- Deshabilitado por defecto
    frame:EnableMouse(false) -- Deshabilitado por defecto
    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:RegisterForDrag("LeftButton")
    
    PartyFrames.anchor = frame
    return frame
end

-- ✅ FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS (COMO target.lua)
local function ApplyWidgetPosition()
    if not PartyFrames.anchor then
        print("|cFFFF0000[DragonUI]|r Party frames: No anchor frame available")
        return
    end

    -- ✅ ASEGURAR QUE EXISTE LA CONFIGURACIÓN
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        print("|cFFFF0000[DragonUI]|r Party frames: No database available for positioning")
        return
    end
    
    local widgetConfig = addon.db.profile.widgets.party
    
    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        -- ✅ USAR EL ANCHOR GUARDADO, NO SIEMPRE TOPLEFT
        local anchor = widgetConfig.anchor or "TOPLEFT"
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
        print("|cFF00FF00[DragonUI]|r Party frames positioned via widgets:", anchor, widgetConfig.posX, widgetConfig.posY)
    else
        -- ✅ CREAR CONFIGURACIÓN POR DEFECTO SI NO EXISTE
        if not addon.db.profile.widgets.party then
            addon.db.profile.widgets.party = {
                anchor = "TOPLEFT",
                posX = 10,
                posY = -200
            }
        end
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -200)
        print("|cFF00FF00[DragonUI]|r Party frames positioned with defaults: TOPLEFT 10 -200")
    end
end

-- ✅ FUNCIONES REQUERIDAS POR EL SISTEMA CENTRALIZADO
function PartyFrames:LoadDefaultSettings()
    -- ✅ ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN WIDGETS
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    if not addon.db.profile.widgets.party then
        addon.db.profile.widgets.party = {
            anchor = "TOPLEFT",
            posX = 10,
            posY = -200
        }
        print("|cFF00FF00[DragonUI]|r Party frames: Created default widget settings")
    end
    
    -- ✅ ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN UNITFRAME
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end
    
    if not addon.db.profile.unitframe.party then
        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = false,
            showManaTextAlways = false,
            orientation = 'vertical',
            padding = 10,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = 10,
            y = -200
        }
        print("|cFF00FF00[DragonUI]|r Party frames: Created default unitframe settings")
    end
end

function PartyFrames:UpdateWidgets()
    ApplyWidgetPosition()
    -- ✅ REPOSICIONAR TODOS LOS PARTY FRAMES RELATIVOS AL ANCHOR ACTUALIZADO
    if not InCombatLockdown() then
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = _G['PartyMemberFrame' .. i]
            if frame and PartyFrames.anchor then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -50
                frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
            end
        end
    end
end

-- ✅ FUNCIÓN PARA VERIFICAR SI LOS PARTY FRAMES DEBEN ESTAR VISIBLES
local function ShouldPartyFramesBeVisible()
    return GetNumPartyMembers() > 0
end

-- ✅ FUNCIONES DE TESTEO PARA EL EDITOR
local function ShowPartyFramesTest()
    -- Mostrar los party frames aunque no haya grupo
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            frame:Show()
        end
    end
end

local function HidePartyFramesTest()
    -- Ocultar frames vacíos cuando no hay party
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame and not UnitExists("party" .. i) then
            frame:Hide()
        end
    end
end

-- ===============================================================
-- HELPER FUNCTIONS
-- ===============================================================

-- Get settings helper
local function GetSettings()
    -- ✅ VERIFICACIÓN ROBUSTA CON VALORES POR DEFECTO
    if not addon.db or not addon.db.profile then
        return {
            scale = 1.0,
            classcolor = false,
            breakUpLargeNumbers = true
        }
    end
    
    local settings = addon.db.profile.unitframe and addon.db.profile.unitframe.party
    
    -- ✅ SI NO EXISTE LA CONFIGURACIÓN, CREARLA CON DEFAULTS
    if not settings then
        if not addon.db.profile.unitframe then
            addon.db.profile.unitframe = {}
        end
        
        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = false,
            showManaTextAlways = false,
            orientation = 'vertical',
            padding = 10,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = 10,
            y = -200
        }
        settings = addon.db.profile.unitframe.party
    end
    
    return settings
end

-- Format numbers helper
local function FormatNumber(value)
    local settings = GetSettings()
    if not value or not settings then
        return "0"
    end

    if settings.breakUpLargeNumbers then
        if value >= 1000000 then
            return string.format("%.1fm", value / 1000000)
        elseif value >= 1000 then
            return string.format("%.1fk", value / 1000)
        end
    end
    return tostring(value)
end

-- Get class color helper
local function GetClassColor(unit)
    if not unit or not UnitExists(unit) then
        return 1, 1, 1
    end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end

    return 1, 1, 1
end

-- Get texture coordinates for party frame elements
local function GetPartyCoords(type)
    if type == "background" then
        return 0.480469, 0.949219, 0.222656, 0.414062
    elseif type == "flash" then
        return 0.480469, 0.925781, 0.453125, 0.636719
    elseif type == "status" then
        return 0.00390625, 0.472656, 0.453125, 0.644531
    end
    return 0, 1, 0, 1
end

-- ✅ NUEVA FUNCIÓN: Get power bar texture
local function GetPowerBarTexture(unit)
    if not unit or not UnitExists(unit) then
        return TEXTURES.manaBar
    end

    local powerType, powerTypeString = UnitPowerType(unit)

    -- En 3.3.5a los tipos son números, no strings
    if powerType == 0 then -- MANA
        return TEXTURES.manaBar
    elseif powerType == 1 then -- RAGE
        return TEXTURES.rageBar
    elseif powerType == 2 then -- FOCUS
        return TEXTURES.focusBar
    elseif powerType == 3 then -- ENERGY
        return TEXTURES.energyBar
    elseif powerType == 6 then -- RUNIC_POWER (si existe en 3.3.5a)
        return TEXTURES.runicPowerBar
    else
        return TEXTURES.manaBar -- Default
    end
end

-- ===============================================================
-- CLASS COLORS
-- ===============================================================

-- ✅ NUEVA FUNCIÓN: Get class color para party member
local function GetPartyClassColor(partyIndex)
    local unit = "party" .. partyIndex
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return 1, 1, 1 -- Blanco si no es jugador
    end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end

    return 1, 1, 1 -- Blanco por defecto
end

-- ✅ NUEVA FUNCIÓN: Update party health bar con class color
local function UpdatePartyHealthBarColor(partyIndex)
    if not partyIndex or partyIndex < 1 or partyIndex > 4 then
        return
    end

    local unit = "party" .. partyIndex
    if not UnitExists(unit) then
        return
    end

    local healthbar = _G['PartyMemberFrame' .. partyIndex .. 'HealthBar']
    if not healthbar then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    local texture = healthbar:GetStatusBarTexture()
    if not texture then
        return
    end

    if settings.classcolor and UnitIsPlayer(unit) then
        -- ✅ USAR CONSTANTE EN LUGAR DE STRING HARDCODED
        local statusTexturePath = TEXTURES.healthBarStatus
        if texture:GetTexture() ~= statusTexturePath then
            texture:SetTexture(statusTexturePath)
        end

        -- ✅ APLICAR COLOR DE CLASE
        local r, g, b = GetPartyClassColor(partyIndex)
        healthbar:SetStatusBarColor(r, g, b, 1)
    else
        -- ✅ USAR CONSTANTE EN LUGAR DE STRING HARDCODED
        local normalTexturePath = TEXTURES.healthBar
        if texture:GetTexture() ~= normalTexturePath then
            texture:SetTexture(normalTexturePath)
        end

        -- ✅ COLOR BLANCO (la textura ya tiene color)
        healthbar:SetStatusBarColor(1, 1, 1, 1)
    end
end
-- ===============================================================
-- SIMPLE BLIZZARD BUFF/DEBUFF REPOSITIONING
-- ===============================================================
local function RepositionBlizzardBuffs()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- ✅ MOVER BUFFS Y DEBUFFS JUNTOS
            for auraIndex = 1, 4 do
                local buff = _G['PartyMemberFrame' .. i .. 'Buff' .. auraIndex]
                local debuff = _G['PartyMemberFrame' .. i .. 'Debuff' .. auraIndex]

                if buff then
                    buff:ClearAllPoints()
                    buff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', -5 + (auraIndex - 1) * 18, -5)
                    buff:SetSize(16, 16)
                end

                if debuff then
                    debuff:ClearAllPoints()
                    debuff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', -5 + (auraIndex - 1) * 18, -22)
                    debuff:SetSize(16, 16)
                end
            end
        end
    end
end


-- ===============================================================
-- TEXT UPDATE SYSTEM (TAINT-FREE)
-- ===============================================================

-- Frame and variables for safe text updates
local updateFrame = CreateFrame("Frame")
local pendingUpdates = {}
local updateScheduled = false

-- Safe text update function
local function SafeUpdateTexts()
    for frameIndex, _ in pairs(pendingUpdates) do
        if PartyFrames.textElements[frameIndex] and PartyFrames.textElements[frameIndex].update then
            PartyFrames.textElements[frameIndex].update()
        end
    end

    -- Clear pending updates
    pendingUpdates = {}
    updateScheduled = false
    updateFrame:SetScript("OnUpdate", nil)
end

-- Schedule text update function (taint-free)
local function ScheduleTextUpdate(frameIndex)
    if not frameIndex then
        return
    end

    -- Mark frame for update
    pendingUpdates[frameIndex] = true

    -- If no update is scheduled, create one
    if not updateScheduled then
        updateScheduled = true
        -- ✅ USE OnUpdate with minimal delay (compatible with 3.3.5a)
        local elapsed = 0
        updateFrame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.01 then -- 10ms delay
                SafeUpdateTexts()
            end
        end)
    end
end
-- ===============================================================
-- DYNAMIC CLIPPING SYSTEM
-- ===============================================================

-- Setup dynamic texture clipping for health bars
local function SetupHealthBarClipping(frame)
    if not frame then
        return
    end

    local healthbar = _G[frame:GetName() .. 'HealthBar']
    if not healthbar or healthbar.DragonUI_ClippingSetup then
        return
    end

    -- Hook SetValue para clipping dinámico Y class color
    hooksecurefunc(healthbar, "SetValue", function(self, value)
        local frameIndex = frame:GetID()
        local unit = "party" .. frameIndex
        if not UnitExists(unit) then
            return
        end

        local texture = self:GetStatusBarTexture()
        if not texture then
            return
        end

        -- ✅ APLICAR CLASS COLOR PRIMERO
        UpdatePartyHealthBarColor(frameIndex)

        -- ✅ CLIPPING DINÁMICO: Solo mostrar la parte llena de la textura
        local min, max = self:GetMinMaxValues()
        local current = value or self:GetValue()

        if max > 0 and current then
            local percentage = current / max
            texture:SetTexCoord(0, percentage, 0, 1)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
    end)

    healthbar.DragonUI_ClippingSetup = true
end

-- Setup dynamic texture clipping for mana bars
local function SetupManaBarClipping(frame)
    if not frame then
        return
    end

    local manabar = _G[frame:GetName() .. 'ManaBar']
    if not manabar or manabar.DragonUI_ClippingSetup then
        return
    end

    -- Hook SetValue para clipping dinámico
    hooksecurefunc(manabar, "SetValue", function(self, value)
        local unit = "party" .. frame:GetID()
        if not UnitExists(unit) then
            return
        end

        local texture = self:GetStatusBarTexture()
        if not texture then
            return
        end

        local min, max = self:GetMinMaxValues()
        local current = value or self:GetValue()

        if max > 0 and current then
            -- ✅ CLIPPING DINÁMICO: Solo mostrar la parte llena de la textura
            local percentage = current / max
            texture:SetTexCoord(0, percentage, 0, 1)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end

        -- Actualizar textura según tipo de poder
        local powerTexture = GetPowerBarTexture(unit)
        texture:SetTexture(powerTexture)
        texture:SetVertexColor(1, 1, 1, 1)
    end)

    manabar.DragonUI_ClippingSetup = true
end
-- ===============================================================
-- FRAME STYLING FUNCTIONS
-- ===============================================================

-- Main styling function for party frames
local function StylePartyFrames()
    local settings = GetSettings()
    if not settings then
        return
    end

    -- ✅ CREAR ANCHOR FRAME SI NO EXISTE
    CreatePartyAnchorFrame()
    
    -- ✅ APLICAR POSICIÓN DEL WIDGET
    ApplyWidgetPosition()

    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- ✅ Scale and texture setup
            frame:SetScale(settings.scale or 1)

            -- ✅ POSICIONAMIENTO RELATIVO AL ANCHOR
            if not InCombatLockdown() then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -50 -- Stack vertical con 50px de separación
                frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
            end

            -- Hide background
            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- Hide default texture
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
            end

            -- Barra de vida
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            if healthbar and not InCombatLockdown() then
                healthbar:SetStatusBarTexture(TEXTURES.healthBar)
                healthbar:SetSize(71, 10)
                healthbar:ClearAllPoints()
                healthbar:SetPoint('TOPLEFT', 44, -19)
                healthbar:SetFrameLevel(frame:GetFrameLevel())
                healthbar:SetStatusBarColor(1, 1, 1, 1)

                -- ✅ CONFIGURAR CLIPPING DINÁMICO CON CLASS COLOR
                SetupHealthBarClipping(frame)

                -- ✅ APLICAR CLASS COLOR INICIAL
                UpdatePartyHealthBarColor(i)
            end

            -- ✅ REEMPLAZAR Mana bar setup (líneas 192-199)
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if manabar and not InCombatLockdown() then
                manabar:SetStatusBarTexture(TEXTURES.manaBar)
                manabar:SetSize(74, 6.5)
                manabar:ClearAllPoints()
                manabar:SetPoint('TOPLEFT', 41, -30.5)
                manabar:SetFrameLevel(frame:GetFrameLevel()) -- ✅ MISMO NIVEL QUE EL FRAME
                manabar:SetStatusBarColor(1, 1, 1, 1)

                -- ✅ CONFIGURAR CLIPPING DINÁMICO
                SetupManaBarClipping(frame)
            end

            -- ✅ Name styling
           local name = _G[frame:GetName() .. 'Name']
            if name then
                name:SetFont("Fonts\\FRIZQT__.TTF", 10)
                name:SetShadowOffset(1, -1)
                name:SetTextColor(1, 0.82, 0, 1) -- ✅ AMARILLO COMO EL RESTO

                if not InCombatLockdown() then
                    name:ClearAllPoints()
                    name:SetPoint('TOPLEFT', 46, -5)
                    name:SetSize(57, 12)
                end
            end

            -- LEADER ICON STYLING
            local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
            if leaderIcon then -- ✅ QUITAMOS and not InCombatLockdown()
                leaderIcon:ClearAllPoints()
                leaderIcon:SetPoint('TOPLEFT', 42, 9) -- ✅ Posición personalizada
                leaderIcon:SetSize(16, 16) -- ✅ Tamaño personalizado (opcional)
            end

            -- ✅ MASTER LOOTER ICON STYLING
            local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
            if masterLooterIcon then -- ✅ SIN RESTRICCIÓN DE COMBATE
                masterLooterIcon:ClearAllPoints()
                masterLooterIcon:SetPoint('TOPLEFT', 58, 20) -- ✅ Posición al lado del leader icon
                masterLooterIcon:SetSize(16, 16) -- ✅ Tamaño personalizado

            end

            -- ✅ Flash setup
            local flash = _G[frame:GetName() .. 'Flash']
            if flash then
                flash:SetSize(114, 47)
                flash:SetTexture(TEXTURES.frame)
                flash:SetTexCoord(GetPartyCoords("flash"))
                flash:SetPoint('TOPLEFT', 2, -2)
                flash:SetVertexColor(1, 0, 0, 1)
                flash:SetDrawLayer('ARTWORK', 5)
            end

            -- ✅ Create background and mark as styled 
            if not frame.DragonUIStyled then
                -- Background (por detrás)
                local background = frame:CreateTexture(nil, 'BACKGROUND', nil, 3)
                background:SetTexture(TEXTURES.frame)
                background:SetTexCoord(GetPartyCoords("background"))
                background:SetSize(120, 49)
                background:SetPoint('TOPLEFT', 1, -2)

                -- ✅ BORDER (por encima de todo) - CON FRAMELEVEL FORZADO
                local border = frame:CreateTexture(nil, 'ARTWORK', nil, 10)
                border:SetTexture(TEXTURES.border)
                border:SetTexCoord(GetPartyCoords("border"))
                border:SetSize(128, 64)
                border:SetPoint('TOPLEFT', 1, -2)
                border:SetVertexColor(1, 1, 1, 1)

                -- ✅ FORZAR QUE EL BORDER TENGA UN FRAMELEVEL MÁS ALTO
                local borderFrame = CreateFrame("Frame", nil, frame)
                borderFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
                borderFrame:SetAllPoints(frame)
                border:SetParent(borderFrame)

                -- ✅ MOVER TEXTOS AL FRAME DEL BORDER PARA QUE ESTÉN POR ENCIMA
                local name = _G[frame:GetName() .. 'Name']
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
                local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
                local pvpIcon = _G[frame:GetName() .. 'PVPIcon']
                local statusIcon = _G[frame:GetName() .. 'StatusIcon']
                local blizzardRoleIcon = _G[frame:GetName() .. 'RoleIcon']
                local guideIcon = _G[frame:GetName() .. 'GuideIcon']
                -- Mover textos sin crear taint (solo cambiar parent)
                if name then
                    name:SetParent(borderFrame)
                    name:SetDrawLayer('OVERLAY', 11) -- Por encima del border
                end
                if healthText then
                    healthText:SetParent(borderFrame)
                    healthText:SetDrawLayer('OVERLAY', 11)
                end
                if manaText then
                    manaText:SetParent(borderFrame)
                    manaText:SetDrawLayer('OVERLAY', 11)
                end
                if leaderIcon then
                    leaderIcon:SetParent(borderFrame)
                    leaderIcon:SetDrawLayer('OVERLAY', 11)
                end
                if masterLooterIcon then
                    masterLooterIcon:SetParent(borderFrame)
                    masterLooterIcon:SetDrawLayer('OVERLAY', 11)
                end
                if pvpIcon then
                    pvpIcon:SetParent(borderFrame)
                    pvpIcon:SetDrawLayer('OVERLAY', 11)
                end
                if statusIcon then 
                    statusIcon:SetParent(borderFrame)
                    statusIcon:SetDrawLayer('OVERLAY', 11)
                end
                if blizzardRoleIcon then
                    blizzardRoleIcon:SetParent(borderFrame)
                    blizzardRoleIcon:SetDrawLayer('OVERLAY', 11)
                end
                if guideIcon then
                    guideIcon:SetParent(borderFrame)
                    guideIcon:SetDrawLayer('OVERLAY', 11)
                end

                frame.DragonUIStyled = true
            end
            -- ✅ REPOSICIONAR TEXTOS DE HEALTH Y MANA
            if healthbar then
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                if healthText then
                    healthText:ClearAllPoints()
                    healthText:SetPoint("CENTER", healthbar, "CENTER", 0, 0) -- ✅ CENTRADO EN LA BARRA
                    healthText:SetDrawLayer("OVERLAY", 10) -- ✅ POR ENCIMA DEL BORDER
                    healthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                    healthText:SetTextColor(1, 1, 1, 1)
                end
            end

            if manabar then
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                if manaText then
                    manaText:ClearAllPoints()
                    manaText:SetPoint("CENTER", manabar, "CENTER", 0, 0) -- ✅ CENTRADO EN LA BARRA
                    manaText:SetDrawLayer("OVERLAY", 10) -- ✅ POR ENCIMA DEL BORDER
                    manaText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                    manaText:SetTextColor(1, 1, 1, 1)
                end
            end

            frame.DragonUIStyled = true
        end
    end
end

-- ===============================================================
-- DISCONNECTED PLAYERS
-- ===============================================================
local function UpdateDisconnectedState(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local isConnected = UnitIsConnected(unit)
    local healthbar = _G[frame:GetName() .. 'HealthBar']
    local manabar = _G[frame:GetName() .. 'ManaBar']
    local portrait = _G[frame:GetName() .. 'Portrait']
    local name = _G[frame:GetName() .. 'Name']

    if not isConnected then
        -- ✅ MIEMBRO DESCONECTADO - APLICAR EFECTOS GRISES
        if healthbar then
            healthbar:SetAlpha(0.3)
            healthbar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        end
        
        if manabar then
            manabar:SetAlpha(0.3)
            manabar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        end
        
        if portrait then
            portrait:SetVertexColor(0.5, 0.5, 0.5, 1)
        end
        
        if name then
            name:SetTextColor(0.6, 0.6, 0.6, 1)
        end

        -- Reposicionar iconos para que no se pierdan
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 20)
            masterLooterIcon:SetSize(16, 16)
        end
        
    else
        -- ✅ MIEMBRO CONECTADO - DESHACER EXACTAMENTE LO QUE SE HIZO AL DESCONECTAR
        
        -- ✅ RESTAURAR TRANSPARENCIAS (sin taint)
        if healthbar then
            healthbar:SetAlpha(1.0) -- ✅ Opacidad normal
            -- ✅ RESTAURAR COLOR CORRECTO (class color o blanco)
            local frameIndex = frame:GetID()
            UpdatePartyHealthBarColor(frameIndex) -- ✅ SOLO actualiza color, no recrea frame
        end
        
        if manabar then
            manabar:SetAlpha(1.0) -- ✅ Opacidad normal
            manabar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Blanco como debe ser
        end
        
        if portrait then
            portrait:SetVertexColor(1, 1, 1, 1) -- ✅ Color normal
        end
        
        if name then
            name:SetTextColor(1, 0.82, 0, 1) -- ✅ Amarillo normal
        end
        
        -- ✅ REPOSICIONAR ICONOS (sin recrear frames)
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 20)
            masterLooterIcon:SetSize(16, 16)
        end
    end
end
-- ===============================================================
-- TEXT AND COLOR UPDATE FUNCTIONS
-- ===============================================================

-- Health text update function (taint-free)
local function UpdateHealthText(statusBar, unit)
    if not unit and statusBar then
        local frameName = statusBar:GetParent():GetName()
        local frameIndex = frameName:match("PartyMemberFrame(%d+)")
        if frameIndex then
            -- ✅ ACTUALIZACIÓN DIRECTA CON LARGE NUMBERS
            local partyUnit = "party" .. frameIndex
            if UnitExists(partyUnit) then
                local current = UnitHealth(partyUnit)
                local max = UnitHealthMax(partyUnit)

                if current and max then
                    local healthText = _G[statusBar:GetParent():GetName() .. 'HealthBarText']
                    if healthText then
                        local formattedCurrent = FormatNumber(current)
                        local formattedMax = FormatNumber(max)
                        healthText:SetText(formattedCurrent .. "/" .. formattedMax)
                    end
                end
            end
        end
    end
end

-- Mana text update function (taint-free)
local function UpdateManaText(statusBar, unit)
    if not unit and statusBar then
        local frameName = statusBar:GetParent():GetName()
        local frameIndex = frameName:match("PartyMemberFrame(%d+)")
        if frameIndex then
            -- ✅ ACTUALIZACIÓN DIRECTA CON LARGE NUMBERS
            local partyUnit = "party" .. frameIndex
            if UnitExists(partyUnit) then
                local current = UnitPower(partyUnit)
                local max = UnitPowerMax(partyUnit)

                if current and max then
                    local manaText = _G[statusBar:GetParent():GetName() .. 'ManaBarText']
                    if manaText then
                        local formattedCurrent = FormatNumber(current)
                        local formattedMax = FormatNumber(max)
                        manaText:SetText(formattedCurrent .. "/" .. formattedMax)
                    end
                end
            end
        end
    end
end

-- Update party colors function
local function UpdatePartyColors(frame)
    if not frame then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local healthbar = _G[frame:GetName() .. 'HealthBar']
    if healthbar and settings.classcolor then
        local r, g, b = GetClassColor(unit)
        healthbar:SetStatusBarColor(r, g, b)
    end
end

-- ✅ NUEVA FUNCIÓN: Update mana bar texture
local function UpdateManaBarTexture(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local manabar = _G[frame:GetName() .. 'ManaBar']
    if manabar then
        local powerTexture = GetPowerBarTexture(unit)
        manabar:SetStatusBarTexture(powerTexture)
        manabar:SetStatusBarColor(1, 1, 1, 1) -- Mantener blanco
    end
end

-- ===============================================================
-- HOOK SETUP FUNCTION
-- ===============================================================

-- Setup all necessary hooks for party frames
local function SetupPartyHooks()
    -- Hook principal para mantener estilos (SIMPLIFIED)
    hooksecurefunc("PartyMemberFrame_UpdateMember", function(frame)
        if frame and frame:GetName():match("^PartyMemberFrame%d+$") then
            -- ✅ MANTENER POSICIONAMIENTO RELATIVO AL ANCHOR
            if PartyFrames.anchor and not InCombatLockdown() then
                local frameIndex = frame:GetID()
                if frameIndex and frameIndex >= 1 and frameIndex <= 4 then
                    frame:ClearAllPoints()
                    local yOffset = (frameIndex - 1) * -50
                    frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
                end
            end

            -- Re-hide textures (always needed)
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
            end

            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- ✅ MANTENER SOLO CONFIGURACIÓN DE CLIPPING (ACE3 maneja colors)
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']

            if healthbar then
                SetupHealthBarClipping(frame)
            end

            if manabar then
                manabar:SetStatusBarColor(1, 1, 1, 1)
                SetupManaBarClipping(frame)
            end

            -- Update power bar texture
            UpdateManaBarTexture(frame)
            -- Desconected state
            UpdateDisconnectedState(frame)
        end
    end)

    -- ✅ HOOK PRINCIPAL PARA CLASS COLOR (SIMPLIFIED)
    hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            -- ✅ SOLO MANTENER CLIPPING DINÁMICO - ACE3 SE ENCARGA DEL COLOR
            local texture = statusbar:GetStatusBarTexture()
            if texture then
                local min, max = statusbar:GetMinMaxValues()
                local current = statusbar:GetValue()
                if max > 0 and current then
                    local percentage = current / max
                    texture:SetTexCoord(0, percentage, 0, 1)
                end
            end
        end
    end)

    -- ✅ HOOK PARA MANA BAR (SIN TOCAR HEALTH)
    hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            statusbar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Solo mana en blanco

            local frameName = statusbar:GetParent():GetName()
            local frameIndex = frameName:match("PartyMemberFrame(%d+)")
            if frameIndex then
                local partyUnit = "party" .. frameIndex
                local powerTexture = GetPowerBarTexture(partyUnit)
                statusbar:SetStatusBarTexture(powerTexture)

                -- ✅ MANTENER CLIPPING DINÁMICO
                local texture = statusbar:GetStatusBarTexture()
                if texture then
                    local min, max = statusbar:GetMinMaxValues()
                    local current = statusbar:GetValue()
                    if max > 0 and current then
                        local percentage = current / max
                        texture:SetTexCoord(0, percentage, 0, 1)
                        texture:SetTexture(powerTexture)
                    end
                end
            end
        end
    end)
end

-- ===============================================================
-- MODULE INTERFACE FUNCTIONS (SIMPLIFIED FOR ACE3)
-- ===============================================================

-- ✅ FUNCIÓN SIMPLIFICADA COMPATIBLE CON ACE3
function PartyFrames:UpdateSettings()
    -- ✅ VERIFICAR CONFIGURACIÓN INICIAL
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets or not addon.db.profile.widgets.party then
        self:LoadDefaultSettings()
    end
    
    -- ✅ APLICAR POSICIÓN DEL WIDGET PRIMERO
    ApplyWidgetPosition()
    
    -- ✅ SOLO APLICAR ESTILOS BASE - ACE3 SE ENCARGA DEL CLASS COLOR
    StylePartyFrames()
    
    -- ✅ REPOSICIONAR BUFFS
    RepositionBlizzardBuffs()
    
    print("|cFF00FF00[DragonUI]|r Party frames updated via Ace3")
end

-- ===============================================================
-- EXPORTS FOR OPTIONS.LUA
-- ===============================================================

-- Export for options.lua refresh functions
addon.RefreshPartyFrames = function()
    if PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- ✅ NUEVA FUNCIÓN: Refresh que se llama desde core.lua
function addon:RefreshPartyFrames()
    if PartyFrames and PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- ===============================================================
-- CENTRALIZED SYSTEM REGISTRATION AND INITIALIZATION
-- ===============================================================

local function InitializePartyFramesForEditor()
    if PartyFrames.initialized then
        return
    end

    -- ✅ CREAR ANCHOR FRAME
    CreatePartyAnchorFrame()
    
    -- ✅ SIEMPRE ASEGURAR QUE EXISTE LA CONFIGURACIÓN
    PartyFrames:LoadDefaultSettings()
    
    -- ✅ APLICAR POSICIÓN INICIAL
    ApplyWidgetPosition()
    
    -- ✅ REGISTRAR CON EL SISTEMA CENTRALIZADO
    if addon and addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "party",
            frame = PartyFrames.anchor,
            configPath = {"widgets", "party"}, -- ✅ AÑADIR configPath requerido por core.lua
            showTest = ShowPartyFramesTest,
            hideTest = HidePartyFramesTest,
            hasTarget = ShouldPartyFramesBeVisible -- ✅ USAR hasTarget en lugar de shouldShow
        })
        print("|cFF00FF00[DragonUI]|r Party frames registered in centralized system")
    end

    PartyFrames.initialized = true
end

-- ===============================================================
-- INITIALIZATION
-- ===============================================================

-- ✅ Initialize everything in correct order
InitializePartyFramesForEditor() -- First: register with centralized system
StylePartyFrames() -- Second: visual properties and positioning
SetupPartyHooks() -- Third: safe hooks only

-- ✅ LISTENER PARA CUANDO EL ADDON ESTÉ COMPLETAMENTE CARGADO
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Aplicar posición después de que el addon esté completamente cargado
        if PartyFrames and PartyFrames.UpdateSettings then
            PartyFrames:UpdateSettings()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local connectionFrame = CreateFrame("Frame")
connectionFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
connectionFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
connectionFrame:SetScript("OnEvent", function(self, event)
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            UpdateDisconnectedState(frame)
        end
    end
end)


-- ===============================================================
-- MODULE LOADED CONFIRMATION
-- ===============================================================

print("|cFF00FF00[DragonUI]|r Party frames module loaded (taint-free) - CENTRALIZED SYSTEM")

