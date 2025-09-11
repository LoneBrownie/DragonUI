-- ===============================================================
-- DRAGONUI PET FRAME MODULE (Como unitframe.lua)
-- ===============================================================
local addon = select(2, ...)

-- Module namespace siguiendo patrón unitframe.lua
local PetFrameModule = {}
addon.PetFrameModule = PetFrameModule

-- Module frame object to store custom UI elements (como unitframe.lua)
local frame = {}

-- ===============================================================
-- IMPORTS AND GLOBALS
-- ===============================================================
local _G = _G
local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitExists = UnitExists
local UnitPowerType = UnitPowerType

-- Empty function to disable Blizzard functionality (como unitframe.lua)
local function noop()
end

-- ===============================================================
-- CONSTANTS
-- ===============================================================
local PET_FRAME_WIDTH = 120
local PET_FRAME_HEIGHT = 47

-- ===============================================================
-- MODULE VARIABLES (Como unitframe.lua)
-- ===============================================================
-- No need for petFrame variable, work directly with PetFrame

-- ===============================================================
-- HELPER FUNCTIONS
-- ===============================================================

-- Función para actualizar textura de power bar según tipo de poder (como unitframe.lua)
local function UpdatePetPowerBarTexture()
    if not UnitExists("pet") then return end
    
    local powerType, powerTypeString = UnitPowerType('pet')
    
    if powerTypeString == 'MANA' then
        PetFrameManaBar:GetStatusBarTexture():SetTexture('Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana')
    elseif powerTypeString == 'FOCUS' then
        PetFrameManaBar:GetStatusBarTexture():SetTexture('Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus')
    elseif powerTypeString == 'RAGE' then
        PetFrameManaBar:GetStatusBarTexture():SetTexture('Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage')
    elseif powerTypeString == 'ENERGY' then
        PetFrameManaBar:GetStatusBarTexture():SetTexture('Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy')
    elseif powerTypeString == 'RUNIC_POWER' then
        PetFrameManaBar:GetStatusBarTexture():SetTexture('Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-RunicPower')
    end
    
    PetFrameManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
end

-- ===============================================================
-- MAIN REPLACEMENT FUNCTION (Como unitframe.lua)
-- ===============================================================

local function ReplaceBlizzardPetFrame()
    local petFrame = PetFrame
    if not petFrame then return end
    
    -- Usar la variable frame global como unitframe.lua
    if not frame then
        frame = {}
    end

    -- Portrait setup (como unitframe.lua)
    local portraitTexture = PetPortrait
    if portraitTexture then
        portraitTexture:ClearAllPoints()
        portraitTexture:SetPoint("LEFT", 6, 0)
        portraitTexture:SetSize(34, 34)
        portraitTexture:SetDrawLayer('BACKGROUND')
    end

    -- Ocultar textura original de Blizzard (como unitframe.lua)
    PetFrameTexture:SetTexture('')
    PetFrameTexture:Hide()

    -- Crear background DragonUI (como unitframe.lua)
    if not frame.PetFrameBackground then
        local background = petFrame:CreateTexture('DragonUIPetFrameBackground')
        background:SetDrawLayer('BACKGROUND', 1)
        background:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND')
        background:SetPoint('LEFT', portraitTexture, 'CENTER', -25 + 1, -10)
        frame.PetFrameBackground = background
    end

    -- Crear border DragonUI (como unitframe.lua)
    if not frame.PetFrameBorder then
        local border = PetFrameHealthBar:CreateTexture('DragonUIPetFrameBorder')
        border:SetDrawLayer('OVERLAY', 2)
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER')
        border:SetPoint('LEFT', portraitTexture, 'CENTER', -25 + 1, -10)
        frame.PetFrameBorder = border
    end

    -- Health Bar setup (como unitframe.lua - usando PetFrameHealthBar directamente)
    local healthBar = PetFrameHealthBar
    if healthBar then
        healthBar:ClearAllPoints()
        healthBar:SetPoint('LEFT', portraitTexture, 'RIGHT', 1 + 1 - 2 + 0.5, 0)
        healthBar:SetSize(70.5, 10)
        healthBar:GetStatusBarTexture():SetTexture('Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
        healthBar:SetStatusBarColor(1, 1, 1, 1)
        healthBar.SetStatusBarColor = noop
    end

    -- Mana Bar setup (como unitframe.lua - usando PetFrameManaBar directamente)
    local manaBar = PetFrameManaBar
    if manaBar then
        manaBar:ClearAllPoints()
        manaBar:SetPoint('LEFT', portraitTexture, 'RIGHT', 1 - 2 - 1.5 + 1 - 2 + 0.5, 2 - 10 - 1)
        manaBar:SetSize(74, 7.5)
        -- Aplicar textura según tipo de poder
        UpdatePetPowerBarTexture()
    end

    -- Flash texture - NO MODIFICAR (Como unitframe.lua - dejar que Blizzard lo maneje)
    -- En unitframe.lua se maneja solo la función Show/Hide, no las coordenadas
    -- El flash texture de amenaza se mantiene como está por defecto
    
    -- ELIMINAR completamente la configuración de Attack Mode texture
    -- unitframe.lua NO maneja PetAttackModeTexture, solo PetFrameFlash

    -- Ocultar textos originales de Blizzard al final (como unitframe.lua)
    if PetFrameHealthBarText then
        PetFrameHealthBarText:Hide()
        PetFrameHealthBarText.Show = noop
        PetFrameHealthBarText.SetText = noop
    end
    if PetFrameManaBarText then
        PetFrameManaBarText:Hide()
        PetFrameManaBarText.Show = noop
        PetFrameManaBarText.SetText = noop
    end

    -- Name text (exacto como RetailUI)
    local nameText = PetName
    if nameText then
        nameText:ClearAllPoints()
        nameText:SetPoint("CENTER", 16, 16)
        nameText:SetJustifyH("LEFT")
        nameText:SetDrawLayer("OVERLAY")
        nameText:SetWidth(65)
    end

    -- Health text - RetailUI reposiciona, nosotros ocultamos (como unitframe.lua)
    local healthText = _G[petFrame:GetName() .. 'HealthBarText']
    if healthText then
        -- RetailUI hace: healthText:SetPoint("CENTER", 19, 4)
        -- Nosotros ocultamos como unitframe.lua
        healthText:Hide()
        healthText.Show = noop
        healthText.SetText = noop
    end

    -- Mana text - RetailUI reposiciona, nosotros ocultamos (como unitframe.lua)
    local manaText = _G[petFrame:GetName() .. 'ManaBarText']
    if manaText then
        -- RetailUI hace: manaText:SetPoint("CENTER", 19, -7)
        -- Nosotros ocultamos como unitframe.lua
        manaText:Hide()
        manaText.Show = noop
        manaText.SetText = noop
    end

    -- Happiness texture (exacto como RetailUI)
    local happinessTexture = _G[petFrame:GetName() .. 'Happiness']
    if happinessTexture then
        happinessTexture:ClearAllPoints()
        happinessTexture:SetPoint("LEFT", petFrame, "RIGHT", 1, -2)
    end
end

-- ===============================================================
-- PET FRAME UPDATE (Como unitframe.lua)
-- ===============================================================

local function PetFrame_Update(self)
    -- Aplicar texturas DragonUI cuando se actualiza el frame (como unitframe.lua)
    if frame.PetFrameBackground then
        frame.PetFrameBackground:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND')
    end
    if frame.PetFrameBorder then
        frame.PetFrameBorder:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER')
    end
    
    -- Actualizar textura de power bar (como unitframe.lua)
    UpdatePetPowerBarTexture()
end

-- ===============================================================
-- MODULE FUNCTIONS (Como RetailUI)
-- ===============================================================

function PetFrameModule:OnEnable()
    -- Hook del PetFrame_Update (como unitframe.lua)
    if not self.petFrameUpdateHooked then
        hooksecurefunc('PetFrame_Update', PetFrame_Update)
        self.petFrameUpdateHooked = true
    end
end

function PetFrameModule:OnDisable()
    -- No need to hide frame in unitframe.lua style
end

function PetFrameModule:PLAYER_ENTERING_WORLD()
    -- Aplicar el reemplazo del Pet Frame (como unitframe.lua)
    ReplaceBlizzardPetFrame()
end

-- ===============================================================
-- INICIALIZACIÓN DEL MÓDULO
-- ===============================================================

-- Event frame para inicialización
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        PetFrameModule:OnEnable()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PetFrameModule:PLAYER_ENTERING_WORLD()
    end
end)

-- ===============================================================
-- MODULE LOADED CONFIRMATION
-- ===============================================================

print("|cFF00FF00[DragonUI]|r Pet Frame module loaded successfully (unitframe.lua style)")