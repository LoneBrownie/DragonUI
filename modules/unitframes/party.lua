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
    runicPowerBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-RunicPower"
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

            local healthbar = _G[frame:GetName() .. 'HealthBar']
            if healthbar and not InCombatLockdown() then
                healthbar:SetStatusBarTexture(TEXTURES.healthBar)
                healthbar:SetSize(71, 10)
                healthbar:ClearAllPoints()
                healthbar:SetPoint('TOPLEFT', 44, -19)
                healthbar:SetFrameLevel(frame:GetFrameLevel()) -- ✅ MISMO NIVEL QUE EL FRAME
                healthbar:SetStatusBarColor(1, 1, 1, 1)
            end

            -- ✅ REEMPLAZAR Mana bar setup (líneas 192-199)
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if manabar and not InCombatLockdown() then
                manabar:SetStatusBarTexture(TEXTURES.manaBar)
                manabar:SetSize(74, 7)
                manabar:ClearAllPoints()
                manabar:SetPoint('TOPLEFT', 41, -30)
                manabar:SetFrameLevel(frame:GetFrameLevel()) -- ✅ MISMO NIVEL QUE EL FRAME
                manabar:SetStatusBarColor(1, 1, 1, 1)
            end

            -- ✅ Name styling
            local name = _G[frame:GetName() .. 'Name']
            if name then
                name:SetFont("Fonts\\FRIZQT__.TTF", 10)
                name:SetShadowColor(0, 0, 0, 1)
                name:SetShadowOffset(1, -1)

                if not InCombatLockdown() then
                    name:ClearAllPoints()
                    name:SetPoint('TOPLEFT', 46, -6)
                    name:SetSize(57, 12)
                end
            end

            -- LEADER ICON STYLING
            local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
            if leaderIcon and not InCombatLockdown() then
                leaderIcon:ClearAllPoints()
                leaderIcon:SetPoint('TOPLEFT', 42, 8) -- ✅ Posición personalizada
                leaderIcon:SetSize(16, 16) -- ✅ Tamaño personalizado (opcional)
            end

            -- ✅ Flash setup
            local flash = _G[frame:GetName() .. 'Flash']
            if flash then
                flash:SetSize(114, 47)
                flash:SetTexture(TEXTURES.frame)
                flash:SetTexCoord(GetPartyCoords("background"))
                flash:SetPoint('TOPLEFT', 1, -2)
                flash:SetVertexColor(1, 0, 0, 1)
                flash:SetDrawLayer('ARTWORK', 5)
            end

            -- ✅ Create background and mark as styled (no TextSystem here to avoid taint)
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

                frame.DragonUIStyled = true
            end
            -- ✅ REPOSICIONAR TEXTOS DE HEALTH Y MANA
            if healthbar then
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                if healthText then
                    healthText:ClearAllPoints()
                    healthText:SetPoint("CENTER", healthbar, "CENTER", 0, 0) -- ✅ CENTRADO EN LA BARRA
                    healthText:SetDrawLayer("OVERLAY", 7) -- ✅ POR ENCIMA DE TODO
                    healthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                    healthText:SetTextColor(1, 1, 1, 1)
                end
            end

            if manabar then
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                if manaText then
                    manaText:ClearAllPoints()
                    manaText:SetPoint("CENTER", manabar, "CENTER", 0, 0) -- ✅ CENTRADO EN LA BARRA
                    manaText:SetDrawLayer("OVERLAY", 7) -- ✅ POR ENCIMA DE TODO
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
            end
            if manabar then
                manabar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Always white
            end
        end
    end)

    -- ✅ Additional hooks to intercept color changes
    hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            statusbar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white
        end
    end)

    hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            statusbar:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white
        end
    end)

    -- ✅ AÑADIR ESTOS HOOKS ADICIONALES PARA HEALTH
    hooksecurefunc("HealthBar_OnValueChanged", function(self)
        if self:GetName() and self:GetName():find('PartyMemberFrame') then
            self:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white on value change
        end
    end)

    hooksecurefunc("UnitFrameHealthBar_OnUpdate", function(self)
        if self:GetName() and self:GetName():find('PartyMemberFrame') then
            self:SetStatusBarColor(1, 1, 1, 1) -- ✅ Force white on update
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
