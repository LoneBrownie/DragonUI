-- ===============================================================
-- DRAGONUI PARTY FRAMES MODULE
-- ===============================================================
local addon = select(2, ...)

-- ===============================================================
-- EARLY EXIT CHECK
-- ===============================================================
if not addon.db or not addon.db.profile or not addon.db.profile.unitframe or not addon.db.profile.unitframe.party then
    return -- Exit early if database not ready
end

-- ===============================================================
-- IMPORTS AND GLOBALS
-- ===============================================================

-- ✅ IMPORTAR SISTEMA DE TEXTO
local TextSystem = addon.TextSystem

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

-- ✅ ALMACENAMIENTO PARA ELEMENTOS DE TEXTO
PartyFrames.textElements = {}

-- ===============================================================
-- CONSTANTS AND CONFIGURATION
-- ===============================================================

-- Texture paths for our custom party frames
local TEXTURES = {
    frame = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\uipartyframe",
    border = "Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    healthBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health",
    manaBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana",
    focusBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Focus",
    rageBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Rage",
    energyBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Energy",
    runicPowerBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-RunicPower",
}

-- ===============================================================
-- HELPER FUNCTIONS
-- ===============================================================

-- Get settings helper
local function GetSettings()
    return addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.party
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
-- BUFF MANAGEMENT SYSTEM (3.3.5a COMPATIBLE)
-- ===============================================================

-- Buff configuration
local BUFF_CONFIG = {
    maxBuffs = 8,           -- Maximum visible buffs per frame
    maxDebuffs = 4,         -- Maximum visible debuffs per frame
    buffSize = 16,          -- Size of buff icons
    debuffSize = 16,        -- Size of debuff icons
    iconSpacing = 2,        -- Space between icons
    offsetX = 43,            -- Horizontal offset from frame
    offsetY = -92,            -- Vertical offset above frame
}

-- Buff frame storage
local buffFrames = {}

-- Helper function to determine if aura is dispellable
local function IsDispellable(dispelType, unit)
    if not dispelType then return false end
    
    -- Get player's dispel abilities (3.3.5a compatible)
    local _, playerClass = UnitClass("player")
    local canDispel = false
    
    if dispelType == "Magic" then
        canDispel = (playerClass == "PRIEST" or playerClass == "SHAMAN" or 
                    playerClass == "MAGE" or playerClass == "WARLOCK")
    elseif dispelType == "Disease" then
        canDispel = (playerClass == "PRIEST" or playerClass == "SHAMAN" or 
                    playerClass == "PALADIN")
    elseif dispelType == "Poison" then
        canDispel = (playerClass == "SHAMAN" or playerClass == "DRUID" or 
                    playerClass == "PALADIN")
    elseif dispelType == "Curse" then
        canDispel = (playerClass == "MAGE" or playerClass == "DRUID")
    end
    
    return canDispel
end

-- Create buff icon
local function CreateBuffIcon(parent, index, isDebuff)
    local iconSize = isDebuff and BUFF_CONFIG.debuffSize or BUFF_CONFIG.buffSize
    local prefix = isDebuff and "Debuff" or "Buff"
    
    local button = CreateFrame("Button", parent:GetName() .. prefix .. index, parent)
    button:SetSize(iconSize, iconSize)
    
    -- Icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    button.icon = icon
    
    -- Border texture
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    border:SetAllPoints()
    border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    button.border = border
    
    -- Duration text
    local duration = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    duration:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
    duration:SetTextColor(1, 1, 1)
    button.duration = duration
    
    -- Stack count text
    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    count:SetTextColor(1, 1, 1)
    button.count = count
    
    -- Tooltip functionality
    button:SetScript("OnEnter", function(self)
        if self.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetSpellByID(self.spellId)
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    button:Hide()
    return button
end

-- Create buff container for a party frame
local function CreateBuffContainer(partyFrame, frameIndex)
    local container = CreateFrame("Frame", "DragonUIPartyBuffs" .. frameIndex, partyFrame)
    container:SetSize(200, 50) -- Adjust as needed
    container:SetPoint("BOTTOMLEFT", partyFrame, "TOPLEFT", BUFF_CONFIG.offsetX, BUFF_CONFIG.offsetY)
    
    -- Create buff icons
    container.buffs = {}
    for i = 1, BUFF_CONFIG.maxBuffs do
        container.buffs[i] = CreateBuffIcon(container, i, false)
    end
    
    -- Create debuff icons
    container.debuffs = {}
    for i = 1, BUFF_CONFIG.maxDebuffs do
        container.debuffs[i] = CreateBuffIcon(container, i, true)
    end
    
    -- Position buff icons (horizontal row)
    for i = 1, BUFF_CONFIG.maxBuffs do
        local icon = container.buffs[i]
        if i == 1 then
            icon:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        else
            icon:SetPoint("LEFT", container.buffs[i-1], "RIGHT", BUFF_CONFIG.iconSpacing, 0)
        end
    end
    
    -- Position debuff icons (below buffs)
    for i = 1, BUFF_CONFIG.maxDebuffs do
        local icon = container.debuffs[i]
        if i == 1 then
            icon:SetPoint("TOPLEFT", container.buffs[1], "BOTTOMLEFT", 0, -BUFF_CONFIG.iconSpacing)
        else
            icon:SetPoint("LEFT", container.debuffs[i-1], "RIGHT", BUFF_CONFIG.iconSpacing, 0)
        end
    end
    
    return container
end

-- Update buffs for a party frame
local function UpdatePartyBuffs(frameIndex)
    local frame = _G['PartyMemberFrame' .. frameIndex]
    if not frame or not buffFrames[frameIndex] then
        return
    end
    
    local unit = "party" .. frameIndex
    if not UnitExists(unit) then
        -- Hide all buff icons
        for i = 1, BUFF_CONFIG.maxBuffs do
            buffFrames[frameIndex].buffs[i]:Hide()
        end
        for i = 1, BUFF_CONFIG.maxDebuffs do
            buffFrames[frameIndex].debuffs[i]:Hide()
        end
        return
    end
    
    local container = buffFrames[frameIndex]
    local buffIndex = 1
    local debuffIndex = 1
    
    -- Hide all icons first
    for i = 1, BUFF_CONFIG.maxBuffs do
        container.buffs[i]:Hide()
    end
    for i = 1, BUFF_CONFIG.maxDebuffs do
        container.debuffs[i]:Hide()
    end
    
    -- ✅ BUFFS (beneficial auras) - 3.3.5a compatible
    for i = 1, 40 do -- Check up to 40 buff slots
        local name, rank, icon, count, dispelType, duration, expirationTime, unitCaster, 
              isStealable, shouldConsolidate, spellId = UnitBuff(unit, i)
        
        if not name then break end -- No more buffs
        
        if buffIndex <= BUFF_CONFIG.maxBuffs then
            local buffIcon = container.buffs[buffIndex]
            
            -- Set icon
            buffIcon.icon:SetTexture(icon)
            
            -- Set count
            if count and count > 1 then
                buffIcon.count:SetText(count)
                buffIcon.count:Show()
            else
                buffIcon.count:Hide()
            end
            
            -- Set duration
            if duration and duration > 0 and expirationTime then
                local timeLeft = expirationTime - GetTime()
                if timeLeft > 60 then
                    buffIcon.duration:SetText(math.floor(timeLeft / 60) .. "m")
                elseif timeLeft > 0 then
                    buffIcon.duration:SetText(math.floor(timeLeft))
                else
                    buffIcon.duration:SetText("")
                end
                buffIcon.duration:Show()
            else
                buffIcon.duration:Hide()
            end
            
            -- Set border (green for buffs)
            buffIcon.border:SetVertexColor(0, 1, 0, 1)
            
            -- Store spell info
            buffIcon.spellId = spellId
            buffIcon.name = name
            
            buffIcon:Show()
            buffIndex = buffIndex + 1
        end
    end
    
    -- ✅ DEBUFFS (harmful auras) - 3.3.5a compatible
    for i = 1, 40 do -- Check up to 40 debuff slots
        local name, rank, icon, count, dispelType, duration, expirationTime, unitCaster, 
              isStealable, shouldConsolidate, spellId = UnitDebuff(unit, i)
        
        if not name then break end -- No more debuffs
        
        if debuffIndex <= BUFF_CONFIG.maxDebuffs then
            local debuffIcon = container.debuffs[debuffIndex]
            
            -- Set icon
            debuffIcon.icon:SetTexture(icon)
            
            -- Set count
            if count and count > 1 then
                debuffIcon.count:SetText(count)
                debuffIcon.count:Show()
            else
                debuffIcon.count:Hide()
            end
            
            -- Set duration
            if duration and duration > 0 and expirationTime then
                local timeLeft = expirationTime - GetTime()
                if timeLeft > 60 then
                    debuffIcon.duration:SetText(math.floor(timeLeft / 60) .. "m")
                elseif timeLeft > 0 then
                    debuffIcon.duration:SetText(math.floor(timeLeft))
                else
                    debuffIcon.duration:SetText("")
                end
                debuffIcon.duration:Show()
            else
                debuffIcon.duration:Hide()
            end
            
            -- Set border color based on dispel type
            if IsDispellable(dispelType, unit) then
                -- Can dispel - bright border
                if dispelType == "Magic" then
                    debuffIcon.border:SetVertexColor(0.2, 0.6, 1, 1) -- Blue
                elseif dispelType == "Disease" then
                    debuffIcon.border:SetVertexColor(0.6, 0.4, 0, 1) -- Brown
                elseif dispelType == "Poison" then
                    debuffIcon.border:SetVertexColor(0, 0.6, 0, 1) -- Green
                elseif dispelType == "Curse" then
                    debuffIcon.border:SetVertexColor(0.6, 0, 1, 1) -- Purple
                else
                    debuffIcon.border:SetVertexColor(1, 0, 0, 1) -- Red
                end
            else
                -- Cannot dispel - red border
                debuffIcon.border:SetVertexColor(1, 0, 0, 1)
            end
            
            -- Store spell info
            debuffIcon.spellId = spellId
            debuffIcon.name = name
            
            debuffIcon:Show()
            debuffIndex = debuffIndex + 1
        end
    end
end

-- ===============================================================
-- BUFF UPDATE TIMER
-- ===============================================================

local buffUpdateFrame = CreateFrame("Frame")
local buffUpdateElapsed = 0
local BUFF_UPDATE_FREQUENCY = 0.5 -- Update every 0.5 seconds

buffUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
    buffUpdateElapsed = buffUpdateElapsed + elapsed
    if buffUpdateElapsed >= BUFF_UPDATE_FREQUENCY then
        buffUpdateElapsed = 0
        
        -- Update buffs for all party members
        for i = 1, MAX_PARTY_MEMBERS do
            UpdatePartyBuffs(i)
        end
    end
end)

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

    -- Hook SetValue para clipping dinámico
    hooksecurefunc(healthbar, "SetValue", function(self, value)
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

        -- Mantener textura y color
        texture:SetTexture(TEXTURES.healthBar)
        texture:SetVertexColor(1, 1, 1, 1)
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

    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- ✅ Scale and texture setup
            frame:SetScale(settings.scale or 1)

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
                healthbar:SetFrameLevel(frame:GetFrameLevel()) -- ✅ MISMO NIVEL QUE EL FRAME
                healthbar:SetStatusBarColor(1, 1, 1, 1)

                -- ✅ CONFIGURAR CLIPPING DINÁMICO
                SetupHealthBarClipping(frame)
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
                name:SetShadowColor(0, 0, 0, 1)
                name:SetShadowOffset(1, -1)

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

                -- ✅ CREAR BUFF CONTAINER
                buffFrames[i] = CreateBuffContainer(frame, i)

                -- ✅ MOVER TEXTOS AL FRAME DEL BORDER PARA QUE ESTÉN POR ENCIMA
                local name = _G[frame:GetName() .. 'Name']
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
                local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
                local pvpIcon = _G[frame:GetName() .. 'PVPIcon']
                local statusIcon = _G[frame:GetName() .. 'StatusIcon']
                local blizzardRoleIcon = _G[frame:GetName() .. 'RoleIcon'] -- ✅ AÑADIR

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
-- TEXT AND COLOR UPDATE FUNCTIONS
-- ===============================================================

-- Health text update function (taint-free)
local function UpdateHealthText(statusBar, unit)
    if not unit and statusBar then
        local frameName = statusBar:GetParent():GetName()
        local frameIndex = frameName:match("PartyMemberFrame(%d+)")
        if frameIndex then
            -- ✅ Schedule update instead of calling directly
            ScheduleTextUpdate(tonumber(frameIndex))
        end
    end
end

-- Mana text update function (taint-free)
local function UpdateManaText(statusBar, unit)
    if not unit and statusBar then
        local frameName = statusBar:GetParent():GetName()
        local frameIndex = frameName:match("PartyMemberFrame(%d+)")
        if frameIndex then
            -- ✅ Schedule update instead of calling directly
            ScheduleTextUpdate(tonumber(frameIndex))
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
    -- Hook to maintain hidden textures
    hooksecurefunc("PartyMemberFrame_UpdateMember", function(frame)
        if frame and frame:GetName():match("^PartyMemberFrame%d+$") then
            -- Re-hide textures
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture() -- Empty
                texture:Hide() -- Hide
            end

            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- ✅ Force white colors on each update
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']

            if healthbar then
                healthbar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Always white

                -- ✅ ASEGURAR CLIPPING DINÁMICO EN CADA UPDATE
                SetupHealthBarClipping(frame)

                -- ✅ FORZAR RECÁLCULO DE CLIPPING
                local current = healthbar:GetValue()
                if current then
                    healthbar:SetValue(current)
                end
            end
            if manabar then
                manabar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Always white

                -- ✅ ASEGURAR CLIPPING DINÁMICO EN CADA UPDATE
                SetupManaBarClipping(frame)

                -- ✅ FORZAR RECÁLCULO DE CLIPPING
                local current = manabar:GetValue()
                if current then
                    manabar:SetValue(current)
                end
            end

            -- ✅ Update power bar texture
            UpdateManaBarTexture(frame)

            -- ✅ REPOSICIONAR LEADER ICON TAMBIÉN AQUÍ
            local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
            if leaderIcon then -- ✅ QUITAMOS InCombatLockdown()
                leaderIcon:ClearAllPoints()
                leaderIcon:SetPoint('TOPLEFT', 42, 9) -- ✅ Posición personalizada
                leaderIcon:SetSize(16, 16)
                leaderIcon:SetDrawLayer('OVERLAY', 11) -- ✅ POR ENCIMA DEL BORDER
            end

            -- ✅ REPOSICIONAR MASTER LOOTER ICON TAMBIÉN AQUÍ
            local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
            if masterLooterIcon then -- ✅ SIN RESTRICCIÓN DE COMBATE
                masterLooterIcon:ClearAllPoints()
                masterLooterIcon:SetPoint('TOPLEFT', 58, 11) -- ✅ Posición al lado del leader
                masterLooterIcon:SetSize(16, 16)
                masterLooterIcon:SetDrawLayer('OVERLAY', 11) -- ✅ POR ENCIMA DEL BORDER
            end

            -- ✅ ASEGURAR QUE EL ROLE ICON DE BLIZZARD ESTÉ VISIBLE
            local blizzardRoleIcon = _G[frame:GetName() .. 'RoleIcon']
            if blizzardRoleIcon then
                blizzardRoleIcon:SetDrawLayer('OVERLAY', 11) -- ✅ POR ENCIMA DEL BORDER
            end
        end
    end)

    -- ✅ Additional hooks to intercept color changes
    hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            statusbar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white

            -- ✅ MANTENER CLIPPING DINÁMICO
            local texture = statusbar:GetStatusBarTexture()
            if texture then
                local min, max = statusbar:GetMinMaxValues()
                local current = statusbar:GetValue()
                if max > 0 and current then
                    local percentage = current / max
                    texture:SetTexCoord(0, percentage, 0, 1)
                    texture:SetTexture(TEXTURES.healthBar)
                end
            end
        end
    end)

    -- ✅ HOOK MEJORADO PARA POWER UPDATES
    hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            statusbar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white

            -- ✅ Update texture based on power type Y MANTENER CLIPPING
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

    -- ✅ AÑADIR ESTOS HOOKS ADICIONALES PARA HEALTH
    hooksecurefunc("HealthBar_OnValueChanged", function(self)
        if self:GetName() and self:GetName():find('PartyMemberFrame') then
            self:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white on value change

            -- ✅ MANTENER CLIPPING DINÁMICO EN VALUE CHANGE
            local texture = self:GetStatusBarTexture()
            if texture then
                local min, max = self:GetMinMaxValues()
                local current = self:GetValue()
                if max > 0 and current then
                    local percentage = current / max
                    texture:SetTexCoord(0, percentage, 0, 1)
                    texture:SetTexture(TEXTURES.healthBar)
                end
            end
        end
    end)

    hooksecurefunc("UnitFrameHealthBar_OnUpdate", function(self)
        if self:GetName() and self:GetName():find('PartyMemberFrame') then
            self:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white on update

            -- ✅ MANTENER CLIPPING DINÁMICO EN UPDATE
            local texture = self:GetStatusBarTexture()
            if texture then
                local min, max = self:GetMinMaxValues()
                local current = self:GetValue()
                if max > 0 and current then
                    local percentage = current / max
                    texture:SetTexCoord(0, percentage, 0, 1)
                    texture:SetTexture(TEXTURES.healthBar)
                end
            end
        end
    end)

    -- Text update hooks
    hooksecurefunc("TextStatusBar_UpdateTextString", function(statusBar)
        if statusBar:GetName():find('PartyMemberFrame') then
            if statusBar:GetName():find('HealthBar') then
                UpdateHealthText(statusBar)
            elseif statusBar:GetName():find('ManaBar') then
                UpdateManaText(statusBar)
            end
        end
    end)

    -- Portrait update hook for class colors
    hooksecurefunc("UnitFramePortrait_Update", function(frame)
        if frame:GetName() and frame:GetName():match("^PartyMemberFrame%d+$") then
            UpdatePartyColors(frame)
        end
    end)
    hooksecurefunc("PartyMemberFrame_UpdateLeader", function(frame)
        if frame and frame:GetName():match("^PartyMemberFrame%d+$") then
            local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
            if leaderIcon then
                leaderIcon:ClearAllPoints()
                leaderIcon:SetPoint('TOPLEFT', 42, 9) -- ✅ Reposicionar siempre
                leaderIcon:SetSize(16, 16)
                leaderIcon:SetDrawLayer('OVERLAY', 11) -- ✅ POR ENCIMA DEL BORDER
            end
        end
    end)

end

-- ===============================================================
-- MODULE INTERFACE FUNCTIONS
-- ===============================================================

-- Update function for settings changes
function PartyFrames:UpdateSettings()
    StylePartyFrames()
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

-- ===============================================================
-- INITIALIZATION
-- ===============================================================

-- ✅ Initialize everything in correct order
StylePartyFrames() -- First: visual properties only
SetupPartyHooks() -- Second: safe hooks only

-- ===============================================================
-- MODULE LOADED CONFIRMATION
-- ===============================================================

print("|cFF00FF00[DragonUI]|r Party frames module loaded (taint-free)")

