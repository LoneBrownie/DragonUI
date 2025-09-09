local addon = select(2, ...);

-- Check if module should load
if not addon.db or not addon.db.profile or not addon.db.profile.unitframe or not addon.db.profile.unitframe.party then
    return -- Exit early if database not ready
end

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

-- Module namespace
local PartyFrames = {}
addon.PartyFrames = PartyFrames

-- Texture paths for our custom party frames
local TEXTURES = {
    frame = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\uipartyframe",
    healthBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health",
    manaBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana",
    focusBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Focus",
    rageBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Rage",
    energyBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Energy",
    runicPowerBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-RunicPower"
}

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

local function GetPartyCoords(type)
    if type == "border" then
        return 0.480469, 0.949219, 0.222656, 0.414062
    elseif type == "flash" then
        return 0.480469, 0.925781, 0.453125, 0.636719
    elseif type == "status" then
        return 0.00390625, 0.472656, 0.453125, 0.644531
    end
    return 0, 1, 0, 1
end

-- ✅ SIMPLIFIED STYLE FUNCTION (como ejemplos - SOLO propiedades simples)
-- ✅ FUNCIÓN MEJORADA USANDO EL MÉTODO DEL ADDON DE REFERENCIA
local function StylePartyFrames()
    local settings = GetSettings()
    if not settings then return end

    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- ✅ Scale
            frame:SetScale(settings.scale or 1)
            
            -- ✅ ESCONDER TEXTURAS BLIZZARD (como addon de referencia)
            -- Background
            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide() 
            end
            
            -- Texture principal
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture() 
                texture:Hide()       
            end

            -- ✅ Health bar
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            if healthbar and not InCombatLockdown() then
                healthbar:SetStatusBarTexture(TEXTURES.healthBar)
                healthbar:SetSize(71, 10)
                healthbar:ClearAllPoints()
                healthbar:SetPoint('TOPLEFT', 44, -19)
                healthbar:SetFrameLevel(frame:GetFrameLevel() + 2)
            end

            -- ✅ Mana bar
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if manabar and not InCombatLockdown() then
                manabar:SetStatusBarTexture(TEXTURES.manaBar)
                manabar:SetSize(74, 7)
                manabar:ClearAllPoints()
                manabar:SetPoint('TOPLEFT', 41, -30)
                manabar:SetFrameLevel(frame:GetFrameLevel() +1)
            end

            -- ✅ Name
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

            -- ✅ Flash (como addon de referencia - reposicionar en lugar de esconder)
            local flash = _G[frame:GetName() .. 'Flash']
            if flash then
                flash:SetSize(114, 47)
                flash:SetTexture(TEXTURES.frame)
                flash:SetTexCoord(GetPartyCoords("border"))
                flash:SetPoint('TOPLEFT', 1, -2)
                flash:SetVertexColor(1, 0, 0, 1)
                flash:SetDrawLayer('ARTWORK', 5)
            end

            -- ✅ CREAR BORDER (solo una vez)
            if not frame.DragonUIStyled then
                local border = frame:CreateTexture(nil, 'ARTWORK', nil, 3)
                border:SetTexture(TEXTURES.frame)
                border:SetTexCoord(GetPartyCoords("border"))
                border:SetSize(120, 49)
                border:SetPoint('TOPLEFT', 1, -2)
                
                frame.DragonUIStyled = true
            end
        end
    end
end

-- ✅ HOOK PARA REESCONDER TEXTURAS (como addon de referencia)
local function SetupPartyHooks()
    -- Hook para mantener texturas escondidas
    hooksecurefunc("PartyMemberFrame_UpdateMember", function(frame)
        if frame and frame:GetName():match("^PartyMemberFrame%d+$") then
            -- Reesconder texturas como en el addon de referencia
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture() -- Vaciar
                texture:Hide()       -- Esconder
            end
            
            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end
        end
    end)

    -- Hooks para texto (mantener los existentes)
    hooksecurefunc("TextStatusBar_UpdateTextString", function(statusBar)
        if statusBar:GetName():find('PartyMemberFrame') then
            if statusBar:GetName():find('HealthBar') then
                UpdateHealthText(statusBar)
            elseif statusBar:GetName():find('ManaBar') then
                UpdateManaText(statusBar)
            end
        end
    end)

    hooksecurefunc("UnitFramePortrait_Update", function(frame)
        if frame:GetName() and frame:GetName():match("^PartyMemberFrame%d+$") then
            UpdatePartyColors(frame)
        end
    end)
end


-- ✅ TEXT UPDATE functions (como ejemplo 2 con hooks)
local function UpdateHealthText(statusBar)
    if not statusBar or not statusBar.unit then
        return
    end

    local unit = statusBar.unit
    if not unit or not unit:match("^party%d+$") then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    -- ✅ USAR TextString existente (como ejemplo 2)
    local textString = statusBar.TextString
    if not textString then
        return
    end

    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)

    if settings.showHealthTextAlways and maxHealth > 0 then
        if settings.textFormat == "both" then
            local percent = math.ceil((health / maxHealth) * 100)
            textString:SetText(percent .. "%")
        else
            textString:SetText(FormatNumber(health))
        end
    else
        textString:SetText("")
    end
end

local function UpdateManaText(statusBar)
    if not statusBar or not statusBar.unit then
        return
    end

    local unit = statusBar.unit
    if not unit or not unit:match("^party%d+$") then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    -- ✅ USAR TextString existente (como ejemplo 2)
    local textString = statusBar.TextString
    if not textString then
        return
    end

    local power = UnitPower(unit)
    local maxPower = UnitPowerMax(unit)

    if settings.showManaTextAlways and maxPower > 0 then
        textString:SetText(FormatNumber(power))
    else
        textString:SetText("")
    end
end

-- ✅ UPDATE COLORS function (como ejemplo 1)
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

-- ✅ SETUP HOOKS (como ejemplos - SOLO hooks)
local function SetupPartyHooks()
    -- ✅ Hook como ejemplo 2
    hooksecurefunc("TextStatusBar_UpdateTextString", function(statusBar)
        if statusBar:GetName():find('PartyMemberFrame') then
            if statusBar:GetName():find('HealthBar') then
                UpdateHealthText(statusBar)
            elseif statusBar:GetName():find('ManaBar') then
                UpdateManaText(statusBar)
            end
        end
    end)

    -- ✅ Hook para colores
    hooksecurefunc("UnitFramePortrait_Update", function(frame)
        if frame:GetName() and frame:GetName():match("^PartyMemberFrame%d+$") then
            UpdatePartyColors(frame)
        end
    end)
end

-- Update function for settings changes
function PartyFrames:UpdateSettings()
    StylePartyFrames()
end

-- Export for options.lua refresh functions
addon.RefreshPartyFrames = function()
    if PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- ✅ INITIALIZE (como ejemplos)
StylePartyFrames() -- Solo propiedades simples una vez
SetupPartyHooks() -- Solo hooks seguros

print("|cFF00FF00[DragonUI]|r Party frames module loaded (taint-free)")
