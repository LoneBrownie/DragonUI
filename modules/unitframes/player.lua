local addon = select(2, ...)

print("|cFF00FF00[DragonUI]|r Player.lua LOADING")

-- ====================================================================
-- PLAYER FRAME MODULE - Versión reescrita y mejorada
-- ====================================================================

local Module = {}
Module.playerFrame = nil
Module.textSystem = nil
Module.initialized = false

-- Localizar globales para acceso rápido en OnUpdate
local PlayerRestIcon = _G.PlayerRestIcon

-- Variables para control de glows
local glowHideTimer = nil

-- ✅ FUNCIÓN: Crear frame auxiliar
local function CreateUIFrame(width, height, name)
    local frame = CreateFrame("Frame", "DragonUI_" .. name .. "_Anchor", UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50)
    frame:SetFrameStrata("LOW")
    return frame
end

-- ✅ FUNCIÓN: Ocultar glows de Blizzard (CRÍTICA)
local function HideBlizzardGlows()
    if PlayerStatusGlow then
        PlayerStatusGlow:Hide()
        PlayerStatusGlow:SetAlpha(0)
    end

    if PlayerRestGlow then
        PlayerRestGlow:Hide()
        PlayerRestGlow:SetAlpha(0)
    end
end

local function RemoveBlizzardFrames()
    local toKill = {"PlayerAttackIcon", "PlayerFrameBackground", "PlayerAttackBackground", "PlayerFrameRoleIcon",
                    "PlayerGuideIcon", "PlayerFrameGroupIndicatorLeft", "PlayerFrameGroupIndicatorRight"}
    for _, name in ipairs(toKill) do
        local obj = _G[name]
        if obj then
            obj:Hide()
            obj:SetAlpha(0)
            -- Evitar que vuelva a mostrarse
            if not obj.__DragonUIHooked then
                obj.__DragonUIHooked = true
                if obj.HookScript then
                    obj:HookScript("OnShow", function(f)
                        f:Hide();
                        f:SetAlpha(0)
                    end)
                end
            end
            -- Si es textura verdadera, vaciarla
            if obj.GetObjectType and obj:GetObjectType() == "Texture" and obj.SetTexture then
                obj:SetTexture(nil)
            end
        end
    end
end

-- ✅ FUNCIÓN: AnimateTexCoords (para rest icon)
local function AnimateTexCoords(texture, textureWidth, textureHeight, frameWidth, frameHeight, numFrames, elapsed,
    throttle)
    if not texture or not texture:IsVisible() then
        return
    end

    texture.animationTimer = (texture.animationTimer or 0) + elapsed
    if texture.animationTimer >= throttle then
        texture.animationFrame = ((texture.animationFrame or 0) + 1) % numFrames
        local col = texture.animationFrame % (textureWidth / frameWidth)
        local row = math.floor(texture.animationFrame / (textureWidth / frameWidth))
        local left = col * frameWidth / textureWidth
        local right = (col + 1) * frameWidth / textureWidth
        local top = row * frameHeight / textureHeight
        local bottom = (row + 1) * frameHeight / textureHeight
        texture:SetTexCoord(left, right, top, bottom)
        texture.animationTimer = 0
    end
end

-- ✅ FUNCIÓN: PlayerFrame_OnUpdate
local function PlayerFrame_OnUpdate(self, elapsed)
    -- Animación del rest icon
    -- Ahora usa la variable local, que es ligeramente más rápida.
    if PlayerRestIcon and PlayerRestIcon:IsVisible() then
        AnimateTexCoords(PlayerRestIcon, 512, 512, 64, 64, 42, elapsed, 0.09)
    end
end

-- ✅ FUNCIÓN: Hook para PlayerFrame_UpdateStatus de Blizzard
local function PlayerFrame_UpdateStatus()
    -- Ocultar el glow de amenaza inmediatamente (CRÍTICO)
    if PlayerStatusGlow then
        PlayerStatusGlow:Hide()
        PlayerStatusGlow:SetAlpha(0)
    end

    -- También ocultar otros glows
    HideBlizzardGlows()
end

-- ✅ FUNCIÓN: UpdateRune (Death Knights)
local function UpdateRune(button)
    if not button then
        return
    end

    local rune = button:GetID()
    local runeType = GetRuneType and GetRuneType(rune)

    if runeType then
        local runeTexture = _G[button:GetName() .. "Rune"]
        if runeTexture then
            runeTexture:SetTexture('Interface\\AddOns\\DragonUI\\Textures\\PlayerFrame\\ClassOverlayDeathKnightRunes')
            if runeType == 1 then -- Blood
                runeTexture:SetTexCoord(0 / 128, 34 / 128, 0 / 128, 34 / 128)
            elseif runeType == 2 then -- Unholy
                runeTexture:SetTexCoord(0 / 128, 34 / 128, 68 / 128, 102 / 128)
            elseif runeType == 3 then -- Frost
                runeTexture:SetTexCoord(34 / 128, 68 / 128, 0 / 128, 34 / 128)
            elseif runeType == 4 then -- Death
                runeTexture:SetTexCoord(68 / 128, 102 / 128, 0 / 128, 34 / 128)
            end
        end
    end
end

-- ✅ FUNCIÓN: SetupRuneFrame
local function SetupRuneFrame()
    if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then
        return
    end

    for index = 1, 6 do
        local button = _G['RuneButtonIndividual' .. index]
        if button then
            button:ClearAllPoints()
            if index > 1 then
                button:SetPoint('LEFT', _G['RuneButtonIndividual' .. (index - 1)], 'RIGHT', 4, 0)
            else
                button:SetPoint('CENTER', PlayerFrame, 'BOTTOM', -20, 0)
            end
            UpdateRune(button)
        end
    end
end

-- ✅ FUNCIÓN: UpdateGroupIndicator
local function UpdateGroupIndicator()
    local groupIndicatorFrame = _G[PlayerFrame:GetName() .. 'GroupIndicator']
    local groupText = _G[PlayerFrame:GetName() .. 'GroupIndicatorText']

    if not groupIndicatorFrame or not groupText then
        return
    end

    groupIndicatorFrame:Hide()

    if GetNumRaidMembers() == 0 then
        return
    end

    local numRaidMembers = GetNumRaidMembers()
    for i = 1, MAX_RAID_MEMBERS do
        if i <= numRaidMembers then
            local name, rank, subgroup = GetRaidRosterInfo(i)
            if name == UnitName("player") then
                groupText:SetText("GROUP " .. subgroup)
                groupIndicatorFrame:Show()
                break
            end
        end
    end
end

-- ✅ FUNCIÓN: UpdatePlayerRoleIcon (Versión con Atlas Personalizado)
local function UpdatePlayerRoleIcon()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.PlayerRoleIcon then
        return
    end

    local iconTexture = dragonFrame.PlayerRoleIcon
    local role = UnitGroupRolesAssigned("player")

    -- Definimos la ruta de nuestra textura y sus dimensiones
    local LFG_ICON_PATH = "Interface\\AddOns\\DragonUI\\Textures\\PlayerFrame\\LFGRoleIcons"
    local LFG_ICON_WIDTH = 256
    local LFG_ICON_HEIGHT = 256

    -- Aplicamos la textura a nuestro icono personalizado
    iconTexture:SetTexture(LFG_ICON_PATH)

    if role == "TANK" then
        -- Coordenadas de atlas.lua para 'LFGRole-Tank': { 35, 53, 0, 17 }
        iconTexture:SetTexCoord(35 / LFG_ICON_WIDTH, 53 / LFG_ICON_WIDTH, 0 / LFG_ICON_HEIGHT, 17 / LFG_ICON_HEIGHT)
        iconTexture:Show()
    elseif role == "HEALER" then
        -- Coordenadas de atlas.lua para 'LFGRole-Healer': { 18, 35, 0, 18 }
        iconTexture:SetTexCoord(18 / LFG_ICON_WIDTH, 35 / LFG_ICON_WIDTH, 0 / LFG_ICON_HEIGHT, 18 / LFG_ICON_HEIGHT)
        iconTexture:Show()
    elseif role == "DAMAGER" then
        -- Coordenadas de atlas.lua para 'LFGRole-Damage': { 0, 17, 0, 17 }
        iconTexture:SetTexCoord(0 / LFG_ICON_WIDTH, 17 / LFG_ICON_WIDTH, 0 / LFG_ICON_HEIGHT, 17 / LFG_ICON_HEIGHT)
        iconTexture:Show()
    else
        iconTexture:Hide()
    end
end

-- ✅ FUNCIÓN: Actualizar color de la barra de vida 
local function UpdateHealthBarColor(statusBar, unit)
    -- Si 'unit' no se pasa (como en el hook OnValueChanged), lo asignamos a "player".
    if not unit then
        unit = "player"
    end

    -- Solo actuar si la barra es la del jugador
    if statusBar ~= PlayerFrameHealthBar or unit ~= "player" then
        return
    end

    -- Obtener la textura de la barra para poder modificarla
    local healthBarTexture = statusBar:GetStatusBarTexture()
    if not healthBarTexture then
        return
    end

    -- Si el jugador está desconectado, la barra se queda gris (comportamiento por defecto)
    if not UnitIsConnected(unit) then
        -- Dejamos que Blizzard maneje el color gris de desconexión
        return
    end

    local hasVehicleUI = UnitHasVehicleUI("player")

    -- Si la opción de color de clase está activa y no estamos en un vehículo...
    if addon:GetConfigValue("unitframe", "player", "classcolor") and not hasVehicleUI then
        -- 1. Cambiamos la textura a una blanca y plana que se pueda colorear.
        healthBarTexture:SetTexture(
            "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status")
        -- 2. Aplicamos el color de la clase.
        local _, englishClass = UnitClass(unit)
        local color = RAID_CLASS_COLORS[englishClass]
        if color then
            statusBar:SetStatusBarColor(color.r, color.g, color.b)
        else
            -- Si falla, aplicar blanco por seguridad.
            statusBar:SetStatusBarColor(1, 1, 1)
        end
    else
        -- Si la opción está desactivada o estamos en un vehículo...
        -- 1. Restauramos la textura original del addon.
        healthBarTexture:SetTexture(
            'Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health')

        -- 2. Forzamos el color a blanco para que la textura original se vea correctamente.
        statusBar:SetStatusBarColor(1, 1, 1)
    end
end

--  FUNCIÓN: Actualizar color de la barra de maná
local function UpdateManaBarColor(statusBar)
    -- Nos aseguramos de que solo afectamos a la barra del jugador
    if statusBar ~= PlayerFrameManaBar then
        return
    end
    -- Forzamos siempre el color blanco para que la textura se vea pura
    statusBar:SetStatusBarColor(1, 1, 1)
end

--   CreatePlayerFrameTextures (MEJORADA)
local function CreatePlayerFrameTextures()
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'

    -- Crear DragonFrame si no existe
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        dragonFrame = CreateFrame('FRAME', 'DragonUIUnitframeFrame', UIParent)
        print("|cFF00FF00[DragonUI]|r Created DragonUIUnitframeFrame")
    end

    -- Ocultar glows inmediatamente
    HideBlizzardGlows()

    --  Crear DragonUI Combat Glow personalizado
    if not dragonFrame.DragonUICombatGlow then
        local combatGlow = PlayerFrame:CreateTexture('DragonUICombatGlow')
        combatGlow:SetDrawLayer('BACKGROUND', 1)
        combatGlow:SetTexture(base)
        combatGlow:SetTexCoord(0.1943359375, 0.3818359375, 0.169921875, 0.30859375)
        combatGlow:SetSize(192, 71)
        combatGlow:SetVertexColor(1.0, 0.0, 0.0, 1.0)
        combatGlow:SetBlendMode('ADD')
        combatGlow:Hide() -- Inicialmente oculto

        -- Posicionar relativo al border frame
        combatGlow:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', -67, -28.5)

        dragonFrame.DragonUICombatGlow = combatGlow
        print("|cFF00FF00[DragonUI]|r Created DragonUICombatGlow")
    end

    -- Background texture (código existente)
    if not dragonFrame.PlayerFrameBackground then
        local background = PlayerFrame:CreateTexture('DragonUIPlayerFrameBackground')
        background:SetDrawLayer('BACKGROUND', 2)
        background:SetTexture(base)
        background:SetTexCoord(0.7890625, 0.982421875, 0.001953125, 0.140625)
        background:SetSize(198, 71)
        background:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, 0)
        dragonFrame.PlayerFrameBackground = background
    end

    -- Border texture
    if not dragonFrame.PlayerFrameBorder then
        local border = PlayerFrameHealthBar:CreateTexture('DragonUIPlayerFrameBorder')
        border:SetDrawLayer('OVERLAY', 5)
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-Player-PortraitOn-BORDER')
        border:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, -28.5)
        dragonFrame.PlayerFrameBorder = border
    end

    -- Decoration texture
    if not dragonFrame.PlayerFrameDeco then
        local textureSmall = PlayerFrame:CreateTexture('DragonUIPlayerFrameDeco')
        textureSmall:SetDrawLayer('OVERLAY', 5)
        textureSmall:SetTexture(base)
        textureSmall:SetTexCoord(0.953125, 0.9755859375, 0.259765625, 0.3046875)
        textureSmall:SetPoint('CENTER', PlayerPortrait, 'CENTER', 15, -17)
        textureSmall:SetSize(23, 23)
        dragonFrame.PlayerFrameDeco = textureSmall
    end

    -- Rest Icon mejorado
    if not dragonFrame.PlayerRestIconOverride then
        PlayerRestIcon:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\PlayerFrame\\PlayerRestFlipbook")
        PlayerRestIcon:ClearAllPoints()
        PlayerRestIcon:SetPoint("TOPLEFT", PlayerPortrait, "TOPLEFT", 40, 15)
        PlayerRestIcon:SetSize(28, 28)

        -- Establecemos las coordenadas del primer fotograma para evitar el parpadeo inicial.
        -- Basado en tu función AnimateTexCoords, el primer fotograma (frame 0) está en la esquina superior izquierda.
        local frameWidth = 64
        local textureWidth = 512
        local left = 0
        local right = frameWidth / textureWidth -- 64 / 512 = 0.125
        local top = 0
        local bottom = frameWidth / textureWidth -- 64 / 512 = 0.125
        PlayerRestIcon:SetTexCoord(left, right, top, bottom)

        dragonFrame.PlayerRestIconOverride = true
    end

    -- Group Indicator
    if not dragonFrame.PlayerGroupIndicator then
        local groupIndicator = CreateFrame("Frame", "DragonUIPlayerGroupIndicator", PlayerFrame)
        groupIndicator:SetSize(64, 16)
        groupIndicator:SetPoint("BOTTOMLEFT", PlayerFrame, "TOP", 20, -2)

        local bgTexture = groupIndicator:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetAllPoints()
        bgTexture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bgTexture:SetTexCoord(0, 1, 0, 0.25)

        local text = groupIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetTextColor(1, 1, 1)

        groupIndicator.text = text
        groupIndicator:Hide()

        _G[PlayerFrame:GetName() .. 'GroupIndicator'] = groupIndicator
        _G[PlayerFrame:GetName() .. 'GroupIndicatorText'] = text

        dragonFrame.PlayerGroupIndicator = groupIndicator
    end

    -- Create text elements
    if not dragonFrame.PlayerFrameHealthBarTextLeft then
        local healthTextLeft = PlayerFrameHealthBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        local font, originalSize, flags = healthTextLeft:GetFont()
        if font and originalSize then
            healthTextLeft:SetFont(font, originalSize + 1, flags)
        end
        healthTextLeft:SetPoint("LEFT", PlayerFrameHealthBar, "LEFT", 6, 0)
        healthTextLeft:SetJustifyH("LEFT")
        dragonFrame.PlayerFrameHealthBarTextLeft = healthTextLeft
    end

    if not dragonFrame.PlayerFrameHealthBarTextRight then
        local healthTextRight = PlayerFrameHealthBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        local font, originalSize, flags = healthTextRight:GetFont()
        if font and originalSize then
            healthTextRight:SetFont(font, originalSize + 1, flags)
        end
        healthTextRight:SetPoint("RIGHT", PlayerFrameHealthBar, "RIGHT", -6, 0)
        healthTextRight:SetJustifyH("RIGHT")
        dragonFrame.PlayerFrameHealthBarTextRight = healthTextRight
    end

    if not dragonFrame.PlayerFrameManaBarTextLeft then
        local manaTextLeft = PlayerFrameManaBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextLeft:SetPoint("LEFT", PlayerFrameManaBar, "LEFT", 6, 0)
        manaTextLeft:SetJustifyH("LEFT")
        dragonFrame.PlayerFrameManaBarTextLeft = manaTextLeft
    end

    if not dragonFrame.PlayerFrameManaBarTextRight then
        local manaTextRight = PlayerFrameManaBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextRight:SetPoint("RIGHT", PlayerFrameManaBar, "RIGHT", -6, 0)
        dragonFrame.PlayerFrameManaBarTextRight = manaTextRight
    end
end

local function HideBlizzardElements()
    local elements = {PlayerFrameTexture, PlayerFrameBackground, PlayerFrameVehicleTexture}
    for _, element in ipairs(elements) do
        if element then
            element:SetAlpha(0)
        end
    end
end

-- ✅ FUNCIÓN: ChangePlayerframe (PRINCIPAL)
local function ChangePlayerframe()
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'
    local hasVehicleUI = UnitHasVehicleUI("player")

    -- Crear texturas primero
    CreatePlayerFrameTextures()

    -- Ocultar elementos de Blizzard
    HideBlizzardElements()

    -- Forzar ocultación de glows
    HideBlizzardGlows()

    -- Configurar portrait
    PlayerPortrait:ClearAllPoints()
    PlayerPortrait:SetDrawLayer('ARTWORK', 5)
    if hasVehicleUI then
        -- Posición y tamaño para vehículo
        PlayerPortrait:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 42, -15) -- Ajustar si es necesario
        PlayerPortrait:SetSize(62, 62) -- Más grande para vehículo
    else
        -- Posición y tamaño normal
        PlayerPortrait:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 42, -15)
        PlayerPortrait:SetSize(56, 56)
    end

    -- Posicionar nombre y nivel
    PlayerName:ClearAllPoints()
    PlayerName:SetPoint('BOTTOMLEFT', PlayerFrameHealthBar, 'TOPLEFT', 0, 1)

    PlayerLevelText:ClearAllPoints()
    PlayerLevelText:SetPoint('BOTTOMRIGHT', PlayerFrameHealthBar, 'TOPRIGHT', -5, 1)

    -- Configurar barra de salud
    PlayerFrameHealthBar:ClearAllPoints()
    if hasVehicleUI then
        PlayerFrameHealthBar:SetSize(117, 20) -- Tamaño para vehículo
        PlayerFrameHealthBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, 0) -- Ajustar si es necesario
    else
        PlayerFrameHealthBar:SetSize(125, 20) -- Tamaño normal
        PlayerFrameHealthBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, 0)
    end

    -- Configurar barra de mana
    PlayerFrameManaBar:ClearAllPoints()
    if hasVehicleUI then
        PlayerFrameManaBar:SetSize(117, 9) -- Tamaño para vehículo
        PlayerFrameManaBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, -16.5) -- Ajustar si es necesario
    else
        PlayerFrameManaBar:SetSize(125, 8) -- Tamaño normal 
        PlayerFrameManaBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, -16.5)
    end

    local powerType, powerTypeString = UnitPowerType('player')

    if powerTypeString == 'MANA' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana')
    elseif powerTypeString == 'RAGE' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage')
    elseif powerTypeString == 'FOCUS' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus')
    elseif powerTypeString == 'ENERGY' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy')
    elseif powerTypeString == 'RUNIC_POWER' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower')
    end

    -- Status Texture ( glow personalizado)
    PlayerStatusTexture:SetTexture(base)
    PlayerStatusTexture:SetSize(192, 71)
    PlayerStatusTexture:SetTexCoord(0.1943359375, 0.3818359375, 0.169921875, 0.30859375)
    PlayerStatusTexture:ClearAllPoints()

    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and dragonFrame.PlayerFrameBorder then
        PlayerStatusTexture:SetPoint('TOPLEFT', dragonFrame.PlayerFrameBorder, 'TOPLEFT', 1, 1)
    end
    -- Ajustar el flash de combate (Método simplificado)
    if PlayerFrameFlash then
        -- 1. Configurar la apariencia del flash
        PlayerFrameFlash:SetTexture(base)
        PlayerFrameFlash:SetTexCoord(0.1943359375, 0.3818359375, 0.169921875, 0.30859375)

        -- 2. Posicionarlo exactamente sobre nuestra textura de estado
        PlayerFrameFlash:ClearAllPoints()
        PlayerFrameFlash:SetAllPoints(PlayerStatusTexture)

        -- 3. Asegurarse de que esté en una capa superior y con el modo de mezcla correcto
        PlayerFrameFlash:SetDrawLayer("OVERLAY", 9)
        PlayerFrameFlash:SetBlendMode("ADD")

        -- 4. NO TOCAR PlayerFrameFlash.anim. Dejamos que la animación por defecto de Blizzard funcione.
    end
    -- Configurar elementos específicos por clase
    RemoveBlizzardFrames()
    SetupRuneFrame()
    UpdatePlayerRoleIcon()
    UpdateGroupIndicator()
    UpdateHealthBarColor(PlayerFrameHealthBar, "player")
    UpdateManaBarColor(PlayerFrameManaBar)

    print("|cFF00FF00[DragonUI]|r PlayerFrame configured successfully")
end

-- ✅ FUNCIÓN: MovePlayerFrame
local function MovePlayerFrame(point, relativeTo, relativePoint, xOfs, yOfs)
    PlayerFrame:ClearAllPoints()

    local originalClamped = PlayerFrame:IsClampedToScreen()
    PlayerFrame:SetClampedToScreen(false)

    local finalRelativePoint = relativePoint or "TOPLEFT"
    local finalPoint = point or "TOPLEFT"
    local finalFrame = _G[relativeTo or "UIParent"] or UIParent
    local finalX = xOfs or -19
    local finalY = yOfs or -4

    PlayerFrame:SetPoint(finalPoint, finalFrame, finalRelativePoint, finalX, finalY)
    PlayerFrame:SetClampedToScreen(originalClamped)

    print("|cFF00FF00[DragonUI]|r PlayerFrame positioned:", finalPoint, "to", finalRelativePoint, finalX, finalY)
end

-- ✅ FUNCIÓN: ApplyPlayerConfig
local function ApplyPlayerConfig()
    local config = addon:GetConfigValue("unitframe", "player") or {}

    local scale = config.scale or 1.0
    local override = config.override or false
    local x = config.x or -19
    local y = config.y or -4
    local anchor = config.anchor or "TOPLEFT"
    local anchorParent = config.anchorParent or "TOPLEFT"

    print("|cFF00FF00[DragonUI]|r PlayerFrame config - Override:", override, "Scale:", scale)

    PlayerFrame:SetScale(scale)

    if override then
        local screenWidth = GetScreenWidth()
        local screenHeight = GetScreenHeight()

        local minX = -500
        local maxX = screenWidth + 500
        local minY = -500
        local maxY = screenHeight + 500

        if x < minX or x > maxX or y < minY or y > maxY then
            print("|cFFFF0000[DragonUI]|r PlayerFrame coordinates out of bounds! Resetting...")
            x, y = -19, -4
            anchor, anchorParent = "TOPLEFT", "TOPLEFT"
            override = false

            addon:SetConfigValue("unitframe", "player", "x", x)
            addon:SetConfigValue("unitframe", "player", "y", y)
            addon:SetConfigValue("unitframe", "player", "anchor", anchor)
            addon:SetConfigValue("unitframe", "player", "anchorParent", anchorParent)
            addon:SetConfigValue("unitframe", "player", "override", override)
        end

        PlayerFrame:SetUserPlaced(true)
        MovePlayerFrame(anchor, "UIParent", anchorParent, x, y)
    else
        PlayerFrame:SetUserPlaced(false)
        MovePlayerFrame("TOPLEFT", "UIParent", "TOPLEFT", -19, -4)
    end

    -- Configurar sistema de texto
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and addon.TextSystem then
        if not Module.textSystem then
            Module.textSystem = addon.TextSystem.SetupFrameTextSystem("player", "player", dragonFrame,
                PlayerFrameHealthBar, PlayerFrameManaBar, "PlayerFrame")
            print("|cFF00FF00[DragonUI]|r PlayerFrame TextSystem configured")
        end

        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

-- ✅ FUNCIÓN: ResetPlayerFrame
local function ResetPlayerFrame()
    local defaults = {
        scale = 1.0,
        override = false,
        x = -19,
        y = -4,
        anchor = "TOPLEFT",
        anchorParent = "TOPLEFT"
    }

    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "player", key, value)
    end

    ApplyPlayerConfig()
    print("|cFF00FF00[DragonUI]|r PlayerFrame reset to defaults")
end

-- ✅ FUNCIÓN: Refresh
local function RefreshPlayerFrame()
    ApplyPlayerConfig()
    if Module.textSystem then
        Module.textSystem.update()
    end
    print("|cFF00FF00[DragonUI]|r PlayerFrame refreshed")
end

local function InitializePlayerFrame()
    if Module.initialized then
        return
    end

    -- Ocultamos los frames de Blizzard una sola vez al inicializar.
    RemoveBlizzardFrames()

    -- Crear frame auxiliar
    Module.playerFrame = CreateUIFrame(198, 71, "PlayerFrame")

    -- Configurar hooks SEGUROS
    if PlayerFrame and PlayerFrame.HookScript then
        PlayerFrame:HookScript('OnUpdate', PlayerFrame_OnUpdate)
        print("|cFF00FF00[DragonUI]|r PlayerFrame OnUpdate hook applied")
    end

    -- Hook para PlayerFrame_UpdateStatus de Blizzard
    if _G.PlayerFrame_UpdateStatus then
        hooksecurefunc('PlayerFrame_UpdateStatus', PlayerFrame_UpdateStatus)
        print("|cFF00FF00[DragonUI]|r PlayerFrame_UpdateStatus hook applied")
    end

    -- Hooks para mantener el color persistente
    -- Este es el método definitivo y más eficiente.
    if PlayerFrameHealthBar and PlayerFrameHealthBar.HookScript then
        PlayerFrameHealthBar:HookScript('OnValueChanged', function(self)
            UpdateHealthBarColor(self, "player")
        end)

        -- ✨ AGREGAR ESTOS HOOKS ADICIONALES:
        PlayerFrameHealthBar:HookScript('OnShow', function(self)
            UpdateHealthBarColor(self, "player")
        end)

        PlayerFrameHealthBar:HookScript('OnUpdate', function(self)
            UpdateHealthBarColor(self, "player")
        end)
    end

    if PlayerFrameManaBar and PlayerFrameManaBar.HookScript then
        PlayerFrameManaBar:HookScript('OnValueChanged', function(self)
            -- Simplemente llamamos a la función que ya tenemos.
            UpdateManaBarColor(self)
        end)
    end

    -- Hooks para glows
    if PlayerStatusGlow and PlayerStatusGlow.HookScript then
        PlayerStatusGlow:HookScript('OnShow', function(self)
            self:Hide()
            self:SetAlpha(0)
        end)
    end

    if PlayerRestGlow and PlayerRestGlow.HookScript then
        PlayerRestGlow:HookScript('OnShow', function(self)
            self:Hide()
            self:SetAlpha(0)
        end)
    end

    -- [[ NUEVO ]] Hook para detectar cambios de arte (Vehículos)
    if PlayerFrame and PlayerFrame.HookScript then
        hooksecurefunc("PlayerFrame_UpdateArt", function()
            -- Cuando Blizzard actualiza el arte, nosotros también.
            ChangePlayerframe()
        end)
    end

    Module.initialized = true
    print("|cFF00FF00[DragonUI]|r PlayerFrame module initialized")
end

-- ✅ EVENT FRAME (SIMPLIFICADO)
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("RUNE_TYPE_UPDATE")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ROLE_CHANGED_INFORM")


eventFrame:SetScript("OnEvent", function(self, event, addonName, ...)
    local unit = ...

    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        InitializePlayerFrame()

    elseif event == "PLAYER_ENTERING_WORLD" then
        ChangePlayerframe()
        ApplyPlayerConfig()
        print("|cFF00FF00[DragonUI]|r PlayerFrame fully configured")

    elseif event == "RUNE_TYPE_UPDATE" then
        local runeIndex = ...
        if runeIndex then
            UpdateRune(_G['RuneButtonIndividual' .. runeIndex])
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        UpdateGroupIndicator()

    elseif event == "ROLE_CHANGED_INFORM" then
        UpdatePlayerRoleIcon()
    elseif event == "UNIT_HEALTH_FREQUENT" and arg1 == "target" then
    UpdateHealthBarColor(TargetFrameHealthBar, "target")
    
elseif event == "UNIT_PORTRAIT_UPDATE" and arg1 == "target" then
    UpdateHealthBarColor(TargetFrameHealthBar, "target")
    UpdatePowerBarColor(TargetFrameManaBar, "target")
    
elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    if UnitExists("target") then
        UpdateHealthBarColor(TargetFrameHealthBar, "target")
    end
    
elseif event == "UNIT_FACTION" and arg1 == "target" then
    UpdateHealthBarColor(TargetFrameHealthBar, "target")
    end
    
end)

-- ✅ EXPONER FUNCIONES
addon.PlayerFrame = {
    Refresh = RefreshPlayerFrame,
    RefreshPlayerFrame = RefreshPlayerFrame,
    Reset = ResetPlayerFrame,
    anchor = function()
        return Module.playerFrame
    end,
    ChangePlayerframe = ChangePlayerframe,
    CreatePlayerFrameTextures = CreatePlayerFrameTextures
}

print("|cFF00FF00[DragonUI]|r Player.lua LOADED")
