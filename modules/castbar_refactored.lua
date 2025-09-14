local addon = select(2, ...);

-- #################################################################
-- ##                    DragonUI Castbar Module                    ##
-- ##      (Refactorizado para eficiencia WotLK 3.3.5a)             ##
-- #################################################################

-- =================================================================
-- CONSTANTES Y CONFIGURACIONES CONSOLIDADAS
-- =================================================================

-- Rutas de texturas optimizadas
local TEXTURE_PATH = "Interface\\AddOns\\DragonUI\\Textures\\CastbarOriginal\\";
local TEXTURES = {
    atlas = TEXTURE_PATH .. "uicastingbar2x",
    atlasSmall = TEXTURE_PATH .. "uicastingbar",
    standard = TEXTURE_PATH .. "CastingBarStandard2",
    channel = TEXTURE_PATH .. "CastingBarChannel",
    interrupted = TEXTURE_PATH .. "CastingBarInterrupted2",
    spark = TEXTURE_PATH .. "CastingBarSpark"
};

-- Coordenadas UV unificadas
local UV_COORDS = {
    background = {0.0009765625, 0.4130859375, 0.3671875, 0.41796875},
    border = {0.412109375, 0.828125, 0.001953125, 0.060546875},
    flash = {0.0009765625, 0.4169921875, 0.2421875, 0.30078125},
    spark = {0.076171875, 0.0859375, 0.796875, 0.9140625},
    borderShield = {0.000976562, 0.0742188, 0.796875, 0.970703},
    textBorder = {0.001953125, 0.412109375, 0.00390625, 0.11328125}
};

-- Configuración de canal ticks
local CHANNEL_TICKS = {
    -- Warlock
    ["Drain Soul"] = 5,
    ["Drain Life"] = 5,
    ["Drain Mana"] = 5,
    ["Rain of Fire"] = 4,
    ["Hellfire"] = 15,
    ["Ritual of Summoning"] = 5,
    -- Priest
    ["Mind Flay"] = 3,
    ["Mind Control"] = 8,
    ["Penance"] = 2,
    -- Mage
    ["Blizzard"] = 8,
    ["Evocation"] = 4,
    ["Arcane Missiles"] = 5,
    -- Otros
    ["Tranquility"] = 4,
    ["Hurricane"] = 10,
    ["First Aid"] = 8
};

-- Configuración de escudo simplificado
local SHIELD_CONFIG = {
    texture = TEXTURES.atlas,
    texCoords = UV_COORDS.borderShield,
    baseIconSize = 20,
    shieldWidthRatio = 1.8, -- 36/20
    shieldHeightRatio = 2.0, -- 40/20
    borderRatio = 1.7, -- 34/20
    position = {
        x = 0,
        y = -4
    },
    alpha = 1.0,
    color = {
        r = 1,
        g = 1,
        b = 1
    }
};

-- Configuración de auras simplificada
local AURA_CONFIG = {
    auraSize = 22,
    rowSpacing = 2,
    baseOffset = 0,
    minRowsToAdjust = 2,
    updateInterval = 0.05
};

-- Constantes adicionales
local GRACE_PERIOD_AFTER_SUCCESS = 0.15;

-- =================================================================
-- VARIABLES DE ESTADO UNIFICADAS
-- =================================================================
addon.castbarStates = {
    player = {
        castingEx = false,
        channelingEx = false,
        startTime = 0,
        endTime = 0,
        holdTime = 0,
        currentSpellName = "",
        castSucceeded = false,
        graceTime = 0,
        selfInterrupt = false,
        unitGUID = nil,    
        fadeOutEx = false   
    },
    target = {
        castingEx = false,
        channelingEx = false,
        startTime = 0,
        endTime = 0,
        holdTime = 0,
        currentSpellName = "",
        selfInterrupt = false,
        unitGUID = nil,    
        fadeOutEx = false   
    },
    focus = {
        castingEx = false,
        channelingEx = false,
        startTime = 0,
        endTime = 0,
        holdTime = 0,
        currentSpellName = "",
        selfInterrupt = false,
        unitGUID = nil,     
        fadeOutEx = false   
    }
};


-- Frames consolidados
local frames = {
    player = {},
    target = {},
    focus = {}
};

-- Control de refreshes para evitar múltiples refreshes rápidos
local lastRefreshTime = {
    player = 0,
    target = 0,
    focus = 0
};


-- =================================================================
-- FUNCIONES AUXILIARES OPTIMIZADAS
-- =================================================================

local RefreshCastbar;
-- Forward declarations for functions used before definition
local HandleCastStop;

-- Función para forzar la capa correcta de StatusBar texture
local function ForceStatusBarTextureLayer(statusBar)
    if not statusBar then
        return
    end
    local texture = statusBar:GetStatusBarTexture();
    if texture and texture.SetDrawLayer then
        texture:SetDrawLayer('BORDER', 0);
    end
end

-- Función unificada para aplicar color de vértice
local function ApplyVertexColor(statusBar)
    if not statusBar or not statusBar.SetStatusBarColor then
        return
    end

    if not statusBar._originalSetStatusBarColor then
        statusBar._originalSetStatusBarColor = statusBar.SetStatusBarColor;
        statusBar.SetStatusBarColor = function(self, r, g, b, a)
            statusBar._originalSetStatusBarColor(self, r, g, b, a or 1);
            local texture = self:GetStatusBarTexture();
            if texture then
                texture:SetVertexColor(1, 1, 1, 1)
            end
        end;
    end

    local texture = statusBar:GetStatusBarTexture();
    if texture then
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

-- Función mejorada de detección de iconos (4 métodos)
local function GetSpellIconImproved(spellName, texture, castID)
    if texture and texture ~= "" then
        return texture
    end
    if spellName then
        local spellTexture = GetSpellTexture(spellName);
        if spellTexture then
            return spellTexture
        end
        -- Búsqueda en spellbook
        for i = 1, 1024 do
            local name, _, icon = GetSpellInfo(i, BOOKTYPE_SPELL);
            if not name then
                break
            end
            if name == spellName and icon then
                return icon
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark";
end

-- Función unificada para parsing de tiempos de cast
local function ParseCastTimes(startTime, endTime)
    local start = tonumber(startTime) or 0;
    local finish = tonumber(endTime) or 0;
    local startSeconds = start / 1000;
    local endSeconds = finish / 1000;
    return startSeconds, endSeconds, endSeconds - startSeconds;
end

-- =================================================================
-- SISTEMA DE TICKS DE CANAL OPTIMIZADO
-- =================================================================

-- Crear ticks de canal (función consolidada)
local function CreateChannelTicks(parentFrame, ticksTable, maxTicks)
    maxTicks = maxTicks or 15;
    for i = 1, maxTicks do
        local tick = parentFrame:CreateTexture('Tick' .. i, 'ARTWORK', nil, 1);
        tick:SetTexture('Interface\\ChatFrame\\ChatFrameBackground');
        tick:SetVertexColor(0, 0, 0);
        tick:SetAlpha(0.75);
        tick:SetSize(3, math.max(parentFrame:GetHeight() - 2, 10));
        tick:SetPoint('CENTER', parentFrame, 'LEFT', parentFrame:GetWidth() / 2, 0);
        tick:Hide();
        ticksTable[i] = tick;
    end
end

-- Actualizar posiciones de ticks
local function UpdateChannelTicks(parentFrame, ticksTable, spellName, maxTicks)
    maxTicks = maxTicks or 15;

    -- Ocultar todos los ticks primero
    for i = 1, maxTicks do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end

    local tickCount = CHANNEL_TICKS[spellName];
    if not tickCount or tickCount <= 1 then
        return
    end

    local castbarWidth = parentFrame:GetWidth();
    local castbarHeight = parentFrame:GetHeight();
    local tickDelta = castbarWidth / tickCount;

    -- Mostrar y posicionar los ticks necesarios
    for i = 1, math.min(tickCount - 1, maxTicks) do
        if ticksTable[i] then
            ticksTable[i]:SetSize(3, math.max(castbarHeight - 2, 10));
            ticksTable[i]:SetPoint('CENTER', parentFrame, 'LEFT', i * tickDelta, 0);
            ticksTable[i]:Show();
        end
    end
end

-- Ocultar todos los ticks
local function HideAllChannelTicks(ticksTable, maxTicks)
    maxTicks = maxTicks or 15;
    for i = 1, maxTicks do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end
end

-- =================================================================
-- SISTEMA DE ESCUDO SIMPLIFICADO
-- =================================================================

-- Crear escudo simplificado (reemplaza sistema de 4 piezas)
local function CreateSimplifiedShield(parentFrame, iconTexture, frameName, iconSize)
    if not parentFrame or not iconTexture then
        return nil
    end

    local shieldWidth = iconSize * SHIELD_CONFIG.shieldWidthRatio;
    local shieldHeight = iconSize * SHIELD_CONFIG.shieldHeightRatio;

    local shield = CreateFrame("Frame", frameName .. "Shield", parentFrame);
    shield:SetFrameLevel(parentFrame:GetFrameLevel() - 1);

    local texture = shield:CreateTexture(nil, "ARTWORK", nil, 3);
    texture:SetAllPoints(shield);
    texture:SetTexture(SHIELD_CONFIG.texture);
    texture:SetTexCoord(unpack(SHIELD_CONFIG.texCoords));
    texture:SetVertexColor(SHIELD_CONFIG.color.r, SHIELD_CONFIG.color.g, SHIELD_CONFIG.color.b, SHIELD_CONFIG.alpha);

    shield:SetSize(shieldWidth, shieldHeight);
    shield:ClearAllPoints();
    shield:SetPoint("CENTER", iconTexture, "CENTER", SHIELD_CONFIG.position.x, SHIELD_CONFIG.position.y);

    shield.iconTexture = iconTexture;
    shield.texture = texture;
    shield:Hide();

    return shield;
end

-- Actualizar tamaños proporcionales de escudo y borde
local function UpdateProportionalSizes(castbarType, iconSize)
    if not iconSize then
        return
    end

    local frameData = frames[castbarType];
    if not frameData then
        return
    end

    -- Actualizar escudo si existe
    if frameData.shield then
        local shieldWidth = iconSize * SHIELD_CONFIG.shieldWidthRatio;
        local shieldHeight = iconSize * SHIELD_CONFIG.shieldHeightRatio;
        frameData.shield:SetSize(shieldWidth, shieldHeight);
    end

    -- Actualizar borde del icono si existe
    if frameData.icon and frameData.icon.Border then
        local borderSize = iconSize * SHIELD_CONFIG.borderRatio;
        frameData.icon.Border:SetSize(borderSize, borderSize);
    end
end

-- =================================================================
-- SISTEMA DE OFFSET DE AURAS OPTIMIZADO
-- =================================================================

local function GetTargetAuraOffsetRetailUI()
    if not addon.db or not addon.db.profile.castbar or not addon.db.profile.castbar.target or
        not addon.db.profile.castbar.target.autoAdjust then
        return 0;
    end

    -- ✅ USAR SISTEMA NATIVO como RetailUI
    local parentFrame = TargetFrame;
    if not parentFrame then
        return 0;
    end

    -- ✅ LEER DIRECTAMENTE del sistema de Blizzard (sin caché, sin polling)
    local auraRows = parentFrame.auraRows or 0;
    local offset = 0;

    -- ✅ LÓGICA SIMPLIFICADA: Si hay más de 1 fila, calcular offset
    if auraRows > 1 then
        -- Usar spellbarAnchor si existe (como RetailUI)
        if parentFrame.spellbarAnchor then
            -- ✅ EL ANCHOR YA TIENE EL OFFSET calculado por Blizzard
            local _, _, _, _, anchorY = parentFrame.spellbarAnchor:GetPoint(1);
            local _, _, _, _, frameY = parentFrame:GetPoint(1);
            offset = math.abs((anchorY or 0) - (frameY or 0));
        else
            -- Fallback: cálculo manual SOLO si no hay anchor
            offset = (auraRows - 1) * (AURA_CONFIG.auraSize + AURA_CONFIG.rowSpacing);
        end
    end

    return offset;
end

local function ApplyRetailUIAuraOffsetToTargetCastbar()
    if not frames.target.castbar or not frames.target.castbar:IsVisible() then
        return
    end

    local cfg = addon.db.profile.castbar.target;
    if not cfg.enabled or not cfg.autoAdjust then
        return
    end

    -- ✅ OBTENER OFFSET DIRECTO (sin caché)
    local offset = GetTargetAuraOffsetRetailUI();
    local anchorFrame = _G[cfg.anchorFrame] or TargetFrame or UIParent;

    -- ✅ APLICAR INMEDIATAMENTE
    frames.target.castbar:ClearAllPoints();
    frames.target.castbar:SetPoint(cfg.anchor, anchorFrame, cfg.anchorParent, cfg.x_position, cfg.y_position - offset);
end


-- =================================================================
-- FUNCIONES DE VISIBILIDAD Y MODO DE TEXTO OPTIMIZADAS
-- =================================================================

-- Función unificada para establecer visibilidad de iconos
local function SetIconVisibility(castbarType, bShown)
    local frameData = frames[castbarType];
    if not frameData or not frameData.icon then
        return
    end

    if bShown then
        frameData.icon:Show();
    else
        frameData.icon:Hide();
    end

    if frameData.icon.Border then
        if bShown then
            frameData.icon.Border:Show();
        else
            frameData.icon.Border:Hide();
        end
    end
end

-- Función unificada para establecer layout compacto
local function SetCompactLayout(castbarType, bCompact)
    local frameData = frames[castbarType];
    if not frameData or not frameData.castText or not frameData.castTextCompact then
        return
    end

    if bCompact then
        frameData.castText:Hide();
        frameData.castTextCompact:Show();
        if frameData.castTimeText then
            frameData.castTimeText:Hide()
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:Show()
        end
    else
        frameData.castText:Show();
        frameData.castTextCompact:Hide();
        if frameData.castTimeText then
            frameData.castTimeText:Show()
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:Hide()
        end
    end
end

-- Función unificada para establecer modo de texto
local function SetTextMode(castbarType, mode)
    local frameData = frames[castbarType];
    if not frameData then
        return
    end

    if mode == "simple" then
        -- Mostrar solo nombre de hechizo centrado
        if frameData.castText then
            frameData.castText:Hide()
        end
        if frameData.castTextCompact then
            frameData.castTextCompact:Hide()
        end
        if frameData.castTimeText then
            frameData.castTimeText:Hide()
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:Hide()
        end
        if frameData.castTextCentered then
            frameData.castTextCentered:Show()
        end
    else
        -- Mostrar modo detallado (nombre + tiempo)
        if frameData.castTextCentered then
            frameData.castTextCentered:Hide()
        end

        local cfg = addon.db and addon.db.profile and addon.db.profile.castbar;
        if castbarType ~= "player" then
            cfg = cfg and cfg[castbarType];
        end
        local compactLayout = cfg and cfg.compactLayout;

        if compactLayout then
            if frameData.castText then
                frameData.castText:Hide()
            end
            if frameData.castTextCompact then
                frameData.castTextCompact:Show()
            end
            if frameData.castTimeText then
                frameData.castTimeText:Hide()
            end
            if frameData.castTimeTextCompact then
                frameData.castTimeTextCompact:Show()
            end
        else
            if frameData.castText then
                frameData.castText:Show()
            end
            if frameData.castTextCompact then
                frameData.castTextCompact:Hide()
            end
            if frameData.castTimeText then
                frameData.castTimeText:Show()
            end
            if frameData.castTimeTextCompact then
                frameData.castTimeTextCompact:Hide()
            end
        end
    end
end

-- Función auxiliar para establecer texto del castbar
local function SetCastText(castbarType, text)
    if not addon.db or not addon.db.profile or not addon.db.profile.castbar then
        return
    end

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then
            return
        end
    end

    local textMode = cfg.text_mode or "simple";
    SetTextMode(castbarType, textMode);

    local frameData = frames[castbarType];
    if not frameData then
        return
    end

    if textMode == "simple" then
        if frameData.castTextCentered then
            frameData.castTextCentered:SetText(text);
        end
    else
        if frameData.castText then
            frameData.castText:SetText(text)
        end
        if frameData.castTextCompact then
            frameData.castTextCompact:SetText(text)
        end
    end
end

-- =================================================================
-- SISTEMA DE MANEJO DE BLIZZARD CASTBARS
-- =================================================================

-- Función unificada para ocultar castbars de Blizzard
local function HideBlizzardCastbar(castbarType)
    local blizzardFrames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    };

    local frame = blizzardFrames[castbarType];
    if not frame then
        return
    end

    -- ✅ CRÍTICO: DESREGISTRAR EVENTOS como RetailUI
    if frame.UnregisterAllEvents then
        frame:UnregisterAllEvents();
    end

    if castbarType == "target" or castbarType == "player" then
        -- CORRECCIÓN: Tratar al player igual que al target para permitir la sincronización.
        -- No usar Hide() - necesitamos las actualizaciones para sincronización.
        frame:SetAlpha(0);
        frame:ClearAllPoints();
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, -2000);
        -- Adicionalmente, nos aseguramos de que no tenga script OnShow que la oculte.
        if frame.SetScript then
            frame:SetScript("OnShow", nil);
        end
    else
        -- Para focus: ocultar completamente ya que no hay sincronización para él.
        frame:Hide();
        frame:SetAlpha(0);
        if frame.SetScript then
            frame:SetScript("OnShow", function(self)
                self:Hide()
            end);
        end
    end
end

-- Función unificada para mostrar castbars de Blizzard
local function ShowBlizzardCastbar(castbarType)
    local blizzardFrames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    };

    local frame = blizzardFrames[castbarType];
    if not frame then
        return
    end

    -- ✅ CRÍTICO: RESTAURAR EVENTOS como RetailUI
    if castbarType == "player" and frame.RegisterEvent then
        -- Restaurar eventos del player castbar
        frame:RegisterEvent("UNIT_SPELLCAST_START");
        frame:RegisterEvent("UNIT_SPELLCAST_STOP");
        frame:RegisterEvent("UNIT_SPELLCAST_FAILED");
        frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
        frame:RegisterEvent("UNIT_SPELLCAST_DELAYED");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE");
        frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
    elseif castbarType == "target" and frame.RegisterEvent then
        -- Restaurar eventos del target castbar
        frame:RegisterEvent("UNIT_SPELLCAST_START");
        frame:RegisterEvent("UNIT_SPELLCAST_STOP");
        frame:RegisterEvent("UNIT_SPELLCAST_FAILED");
        frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
        frame:RegisterEvent("UNIT_SPELLCAST_DELAYED");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE");
        frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE");
        frame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE");
    elseif castbarType == "focus" and frame.RegisterEvent then
        -- Restaurar eventos del focus castbar
        frame:RegisterEvent("UNIT_SPELLCAST_START");
        frame:RegisterEvent("UNIT_SPELLCAST_STOP");
        frame:RegisterEvent("UNIT_SPELLCAST_FAILED");
        frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
        frame:RegisterEvent("UNIT_SPELLCAST_DELAYED");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE");
        frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE");
        frame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE");
    end

    frame:SetAlpha(1);
    if frame.SetScript then
        frame:SetScript("OnShow", nil);
    end
    if castbarType == "target" then
        -- Restaurar posición original del target castbar
        frame:ClearAllPoints();
        frame:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 25, -5);
    elseif castbarType == "player" then
        -- Restaurar posición original del player castbar
        frame:ClearAllPoints();
        -- La posición por defecto de la barra de casteo del jugador es manejada por Blizzard,
        -- pero podemos anclarla a UIParent si es necesario.
        -- Dejar que Blizzard la maneje al mostrarla suele ser suficiente.
    end
end





-- =================================================================
-- FUNCIÓN DE FINALIZACIÓN UNIFICADA
-- =================================================================

-- Actualizar función de finalización
local function FinishSpell(castbarType)
    local frameData = frames[castbarType];
    local state = addon.castbarStates[castbarType];
    local cfg = addon.db.profile.castbar;

    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then return end
    end

    -- Establecer valor final
    frameData.castbar:SetValue(1.0);
    if frameData.castbar.UpdateTextureClipping then
        frameData.castbar:UpdateTextureClipping(1.0, state.channelingEx);
    end

    -- Ocultar elementos
    if frameData.spark then frameData.spark:Hide() end
    if frameData.shield then frameData.shield:Hide() end
    HideAllChannelTicks(frameData.ticks, 15);

    -- Mostrar flash
    if frameData.flash then frameData.flash:Show() end

    -- Resetear estado
    state.castingEx = false;
    state.channelingEx = false;
    state.holdTime = cfg.holdTime or 0.3;
end


-- =================================================================
-- FUNCIONES UPDATE UNIFICADAS
-- =================================================================
-- Función de actualización de tiempo como RetailUI
local function UpdateCastTimeTextRetailUI(castbarType, remainingTime, totalTime)
    local frameData = frames[castbarType];
    local cfg = addon.db.profile.castbar;
    
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then return end
    end

    local state = addon.castbarStates[castbarType];
    local seconds = math.max(0, remainingTime);
    local secondsMax = totalTime;

    -- Formatear texto de tiempo
    local timeText = string.format('%.' .. (cfg.precision_time or 1) .. 'f', seconds);
    local fullText;

    if cfg.precision_max and cfg.precision_max > 0 then
        local maxText = string.format('%.' .. cfg.precision_max .. 'f', secondsMax);
        fullText = timeText .. ' / ' .. maxText;
    else
        fullText = timeText .. 's';
    end

    -- Aplicar texto
    if castbarType == "player" then
        local textMode = cfg.text_mode or "simple";
        if textMode ~= "simple" and frameData.timeValue and frameData.timeMax then
            frameData.timeValue:SetText(timeText);
            frameData.timeMax:SetText(' / ' .. string.format('%.' .. (cfg.precision_max or 1) .. 'f', secondsMax));
        end
    else
        if frameData.castTimeText then
            frameData.castTimeText:SetText(fullText)
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:SetText(fullText)
        end
    end
end

-- Función unificada para manejar parada/interrupción COMO RETAILUI
local function HandleCastStop(castbarType, event, forceInterrupted)
    local state = addon.castbarStates[castbarType];
    local frameData = frames[castbarType];

    if not state.castingEx and not state.channelingEx then
        return
    end

    state.castingEx = false;
    state.channelingEx = false;

    if forceInterrupted then
        -- Mostrar interrupción visualmente
        frameData.castbar:SetStatusBarTexture(TEXTURES.interrupted);
        frameData.castbar:SetStatusBarColor(1, 0, 0, 1);
        SetCastText(castbarType, "Interrupted");
    end

    -- ✅ USAR UIFrameFadeOut como RetailUI (más eficiente)
    state.fadeOutEx = true;
    UIFrameFadeOut(frameData.castbar, 1.0, 1.0, 0.0);
end


-- Función de actualización principal unificada
local function UpdateCastbar(castbarType, self, elapsed)
    local state = addon.castbarStates[castbarType];
    local frameData = frames[castbarType];
    
    -- ✅ MANEJAR fadeOut como RetailUI - PERO SIN BLOQUEAR NUEVOS CASTS
    if state.fadeOutEx then
        if self:GetAlpha() <= 0.0 then
            self:Hide();
            if frameData.background then frameData.background:Hide() end
            if frameData.textBackground then frameData.textBackground:Hide() end
            state.fadeOutEx = false; -- ✅ IMPORTANTE: Resetear para permitir nuevos casts
        end
        return;
    end
    
    local cfg = addon.db.profile.castbar;

    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg or not cfg.enabled then
            return
        end

        -- Check if target/focus still exists
        local unit = castbarType;
        if not UnitExists(unit) then
            if state.castingEx or state.channelingEx then
                self:Hide();
                if frameData.background then frameData.background:Hide() end
                if frameData.textBackground then frameData.textBackground:Hide() end
                if frameData.flash then frameData.flash:Hide() end
                if frameData.spark then frameData.spark:Hide() end
                if frameData.shield then frameData.shield:Hide() end
                if frameData.icon then frameData.icon:Hide() end

                -- Reset state
                state.castingEx = false;
                state.channelingEx = false;
                state.holdTime = 0;
                state.startTime = 0;
                state.endTime = 0;
                state.fadeOutEx = false; -- ✅ RESETEAR también aquí
            end
            return;
        end
    elseif not cfg or not cfg.enabled then
        return;
    end

    -- ✅ CORREGIR: Lógica principal como RetailUI
    local currentTime = GetTime();
    local value, remainingTime = 0, 0;
    
    if state.channelingEx or state.castingEx then
        if state.castingEx and not state.channelingEx then
            -- ✅ COMO RETAILUI: Para casting normal
            remainingTime = math.min(currentTime, state.endTime) - state.startTime;
            value = remainingTime / (state.endTime - state.startTime);
        elseif state.channelingEx then
            -- ✅ COMO RETAILUI: Para channeling
            remainingTime = state.endTime - currentTime;
            value = remainingTime / (state.endTime - state.startTime);
        end
        
        value = math.max(0, math.min(1, value));
        self:SetValue(value);
        
        if self.UpdateTextureClipping then
            self:UpdateTextureClipping(value, state.channelingEx);
        end

        -- Actualizar texto de tiempo
        UpdateCastTimeTextRetailUI(castbarType, math.abs(remainingTime), state.endTime - state.startTime);

        -- Actualizar posición del spark
        if frameData.spark and frameData.spark:IsShown() then
            local actualWidth = self:GetWidth() * value;
            frameData.spark:ClearAllPoints();
            frameData.spark:SetPoint('CENTER', self, 'LEFT', actualWidth, 0);
        end

        -- ✅ COMO RETAILUI: Verificar si terminó
        if currentTime >= state.endTime then
            state.castingEx = false;
            state.channelingEx = false;
            -- ✅ NO poner fadeOutEx aquí para el player - usar periodo de gracia
            if castbarType == "player" then
                state.castSucceeded = true;
                state.graceTime = 0;
            else
                state.fadeOutEx = true;
                UIFrameFadeOut(frameData.castbar, 0.5, 1.0, 0.0);
            end
        end

        -- Ocultar flash durante casting/channeling
        if frameData.flash then
            frameData.flash:Hide()
        end
    end

    -- Manejar período de gracia para casts exitosos (solo player)
    if castbarType == "player" and state.castSucceeded and not state.castingEx and not state.channelingEx then
        state.graceTime = state.graceTime + elapsed;
        if state.graceTime >= GRACE_PERIOD_AFTER_SUCCESS then
            FinishSpell(castbarType);
            state.castSucceeded = false;
            state.graceTime = 0;
        end
        return;
    end

    -- Manejar tiempo de hold
    if state.holdTime > 0 then
        state.holdTime = state.holdTime - elapsed;
        if state.holdTime <= 0 then
            self:Hide();
            if frameData.background then frameData.background:Hide() end
            if frameData.textBackground then frameData.textBackground:Hide() end
            if frameData.flash then frameData.flash:Hide() end
            if frameData.spark then frameData.spark:Hide() end
            if frameData.shield then frameData.shield:Hide() end

            -- Resetear estados
            state.castingEx = false;
            state.channelingEx = false;
            state.fadeOutEx = false; -- ✅ RESETEAR también aquí
            if castbarType == "player" then
                state.castSucceeded = false;
                state.graceTime = 0;
            end
        end
        return;
    end
end

-- Crear funciones de OnUpdate específicas para cada tipo
local function CreateUpdateFunction(castbarType)
    return function(self, elapsed)
        UpdateCastbar(castbarType, self, elapsed);
    end
end

-- =================================================================
-- SISTEMA DE MANEJO DE EVENTOS UNIFICADO
-- =================================================================

-- Función para manejar eventos de UNIT_AURA
local function HandleUnitAura(unit)
    if unit == 'target' then
        local cfg = addon.db.profile.castbar.target;
        if cfg and cfg.enabled and cfg.autoAdjust then
            -- ✅ CORREGIR: Usar la nueva función RetailUI
            ApplyRetailUIAuraOffsetToTargetCastbar();
        end
    end
end

-- =================================================================
-- SISTEMA DE MANEJO DE EVENTOS DE CASTING UNIFICADO (DECLARADO TEMPRANO)
-- =================================================================

-- Función unificada para manejar inicio de cast
local function HandleCastStart(castbarType, unit)
    local name, subText, text, iconTex, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit);
    if not name then
        return
    end

    RefreshCastbar(castbarType)

    local state = addon.castbarStates[castbarType];
    local frameData = frames[castbarType];

    -- ✅ CRÍTICO: Resetear fadeOut y mostrar barra inmediatamente
    state.fadeOutEx = false;
    frameData.castbar:SetAlpha(1.0);
    
    -- ✅ CRÍTICO: Cancelar cualquier fade en progreso
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(frameData.castbar);
    end

    -- ✅ CRÍTICO: Establecer GUID ANTES de otros flags
    state.unitGUID = UnitGUID(unit);
    state.castingEx = true;
    state.channelingEx = false;
    state.holdTime = 0;
    state.currentSpellName = name;
    state.selfInterrupt = false;

    -- ✅ AÑADIR: Timestamp del cast para evitar eventos obsoletos
    state.castStartTime = GetTime();

    -- Reset estado de éxito (solo player)
    if castbarType == "player" then
        state.castSucceeded = false;
        state.graceTime = 0;
    end

    -- ✅ COMO RETAILUI: Tiempos correctos
    state.startTime = startTime / 1000;
    state.endTime = endTime / 1000;

    -- Configurar barra
    frameData.castbar:SetMinMaxValues(0, 1);
    frameData.castbar:SetValue(0);

    -- ✅ CRÍTICO: Mostrar elementos DESPUÉS de resetear fade
    frameData.castbar:Show();
    if frameData.background and frameData.background ~= frameData.textBackground then
        frameData.background:Show();
    end
    frameData.spark:Show();
    frameData.flash:Hide();


    -- Ocultar ticks de canal de hechizos anteriores
    HideAllChannelTicks(frameData.ticks, 15);

    -- Configurar texturas y colores
    frameData.castbar:SetStatusBarTexture(TEXTURES.standard);
    frameData.castbar:SetStatusBarColor(1, 0.7, 0, 1);
    ForceStatusBarTextureLayer(frameData.castbar);
    frameData.castbar:UpdateTextureClipping(0.0, false);

    -- Configurar texto e icono
    SetCastText(castbarType, name);

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
    end

    if frameData.icon and cfg.showIcon then
        frameData.icon:SetTexture(nil);
        local improvedIcon = GetSpellIconImproved(name, iconTex, castID);
        frameData.icon:SetTexture(improvedIcon);
        SetIconVisibility(castbarType, true);
    else
        SetIconVisibility(castbarType, false);
    end

    if frameData.textBackground then
        frameData.textBackground:Show();
        frameData.textBackground:ClearAllPoints();
        frameData.textBackground:SetSize(frameData.castbar:GetWidth(), castbarType == "player" and 22 or 20);
        frameData.textBackground:SetPoint("TOP", frameData.castbar, "BOTTOM", 0, castbarType == "player" and 6 or 8);
    end

    -- Manejar escudo para hechizos no interrumpibles
    if castbarType ~= "player" and frameData.shield and cfg.showIcon then
        if notInterruptible == true and not (isTradeSkill == true or isTradeSkill == 1) then
            frameData.shield:Show();
        else
            frameData.shield:Hide();
        end
    end
end

-- Función unificada para manejar inicio de channel COMO RETAILUI
local function HandleChannelStart(castbarType, unit)
    local name, subText, text, iconTex, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(unit);
    if not name then
        return
    end

    RefreshCastbar(castbarType)

    local state = addon.castbarStates[castbarType];
    local frameData = frames[castbarType];

    -- ✅ CRÍTICO: Resetear fadeOut y mostrar barra inmediatamente
    state.fadeOutEx = false;
    frameData.castbar:SetAlpha(1.0);
    
    -- ✅ CRÍTICO: Cancelar cualquier fade en progreso
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(frameData.castbar);
    end

    -- ✅ CRÍTICO: Establecer GUID ANTES de otros flags
    state.unitGUID = UnitGUID(unit);
    state.castingEx = true;
    state.channelingEx = true;
    state.holdTime = 0;
    state.currentSpellName = name;


    -- ✅ AÑADIR: Timestamp del cast para evitar eventos obsoletos
    state.castStartTime = GetTime();

    -- Reset estado de éxito (solo player)
    if castbarType == "player" then
        state.castSucceeded = false;
        state.graceTime = 0;
    end

    -- ✅ COMO RETAILUI: Usar GetTime() y establecer tiempos absolutos
    local currentTime = GetTime();
    local startTimeSeconds, endTimeSeconds, spellDuration = ParseCastTimes(startTime, endTime);
    
    state.startTime = currentTime;
    state.endTime = currentTime + spellDuration;

    -- Configurar barra para valor 0-1
    frameData.castbar:SetMinMaxValues(0, 1);
    frameData.castbar:SetValue(1); -- Channeling empieza lleno

    -- ✅ CRÍTICO: Mostrar castbar DESPUÉS de resetear fade
    frameData.castbar:Show();
    if frameData.background and frameData.background ~= frameData.textBackground then
        frameData.background:Show();
    end
    frameData.spark:Show();
    frameData.flash:Hide();

    -- Configurar texturas y colores para channeling
    frameData.castbar:SetStatusBarTexture(TEXTURES.channel);
    ForceStatusBarTextureLayer(frameData.castbar);

    if castbarType == "player" then
        frameData.castbar:SetStatusBarColor(0, 1, 0, 1);
    else
        frameData.castbar:SetStatusBarColor(1, 1, 1, 1);
    end
    frameData.castbar:UpdateTextureClipping(1.0, true);

    -- Configurar texto e icono
    SetCastText(castbarType, name);

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
    end

    if frameData.icon and cfg.showIcon then
        frameData.icon:SetTexture(nil);
        local _, _, _, texture = UnitChannelInfo(unit);
        local improvedIcon = GetSpellIconImproved(name, texture, nil);
        frameData.icon:SetTexture(improvedIcon);
        SetIconVisibility(castbarType, true);
    else
        SetIconVisibility(castbarType, false);
    end

    if frameData.textBackground then
        frameData.textBackground:Show();
        frameData.textBackground:ClearAllPoints();
        frameData.textBackground:SetSize(frameData.castbar:GetWidth(), castbarType == "player" and 22 or 20);
        frameData.textBackground:SetPoint("TOP", frameData.castbar, "BOTTOM", 0, castbarType == "player" and 6 or 8);
    end

    -- Mostrar ticks de canal
    UpdateChannelTicks(frameData.castbar, frameData.ticks, name, 15);

    -- Manejar escudo para channels no interrumpibles
    if castbarType ~= "player" and frameData.shield and cfg.showIcon then
        if notInterruptible == true and not (isTradeSkill == true or isTradeSkill == 1) then
            frameData.shield:Show();
        else
            frameData.shield:Hide();
        end
    end
end

-- ✅ NUEVA FUNCIÓN: Verificar si el evento es válido para el cast actual
local function IsValidCastEvent(castbarType, unit)
    local state = addon.castbarStates[castbarType];
    
    if castbarType == "player" then
        -- ✅ CORREGIR: Para eventos START, SIEMPRE son válidos (nuevo cast)
        -- Para otros eventos, verificar coherencia pero sin ser demasiado restrictivo
        if not (state.castingEx or state.channelingEx) then
            return false;
        end
        
        -- ✅ SIMPLIFICAR: Solo verificar si hay un estado de cast activo
        -- No verificar nombres porque pueden cambiar entre el evento y nuestro estado
        return true;
    else
        -- Para target/focus: verificar GUID como RetailUI
        local currentGUID = UnitGUID(unit);
        return state.unitGUID == currentGUID and (state.castingEx or state.channelingEx);
    end
end

-- Función principal unificada para manejar eventos de casting
local function HandleCastingEvents(castbarType, event, unit, ...)
    local unitToCheck = castbarType == "player" and "player" or castbarType;
    if unit ~= unitToCheck then return end

    local state = addon.castbarStates[castbarType];

    -- ✅ CRÍTICO: START events SIEMPRE se procesan (para permitir nuevos casts)
    if event == 'UNIT_SPELLCAST_START' or event == 'UNIT_SPELLCAST_CHANNEL_START' then
        -- ✅ START events siempre reemplazan cualquier cast anterior
        -- NO hacer validaciones aquí
    else
        -- ✅ CRÍTICO: FILTRO GCD PRIMERO, antes que cualquier otra validación
        if event == 'UNIT_SPELLCAST_FAILED' then
            local failureReason = select(1, ...);
            if failureReason and (
                failureReason == "Spell is not ready yet" or
                failureReason:find("not ready") or
                failureReason:find("cooldown")
            ) then
                return; -- ✅ IGNORAR completamente - es solo GCD, no falla real
            end
        end

        -- ✅ VERIFICAR GUID para target/focus (como RetailUI)
        if castbarType ~= "player" then
            local currentGUID = UnitGUID(unit);
            if state.unitGUID ~= currentGUID then
                return; -- ✅ GUID no coincide - ignorar evento
            end
        end
        
        -- ✅ VERIFICAR que hay un cast activo
        if not (state.castingEx or state.channelingEx) then
            return; -- ✅ No hay cast activo - ignorar evento espurio
        end
        
        -- ✅ PARA FAILED/INTERRUPTED: Verificar que el nombre coincida
        if event == 'UNIT_SPELLCAST_FAILED' or event == 'UNIT_SPELLCAST_INTERRUPTED' then
            local currentSpellName;
            if state.castingEx and not state.channelingEx then
                currentSpellName = UnitCastingInfo(unit);
            elseif state.channelingEx then
                currentSpellName = UnitChannelInfo(unit);
            end
            
            -- ✅ Si el nombre no coincide, ignorar
            if currentSpellName and currentSpellName ~= state.currentSpellName then
                return; -- ✅ Evento de un hechizo diferente
            end
        end
    end

    -- ✅ UPDATES: Solo procesar si corresponde al cast actual
    if event == 'UNIT_SPELLCAST_DELAYED' or event == 'UNIT_SPELLCAST_CHANNEL_UPDATE' then
        local name, subText, text, iconTex, startTime, endTime;
        if state.castingEx and not state.channelingEx then
            name, subText, text, iconTex, startTime, endTime = UnitCastingInfo(unit);
        elseif state.channelingEx then
            name, subText, text, iconTex, startTime, endTime = UnitChannelInfo(unit);
        end
        
        -- ✅ Solo actualizar si el nombre coincide
        if name and name == state.currentSpellName then
            state.startTime = startTime / 1000;
            state.endTime = endTime / 1000;
        end
        return; -- ✅ RETURN temprano para UPDATES
    end

    -- ✅ SHIELD events
    if event == 'UNIT_SPELLCAST_INTERRUPTIBLE' then
        local frameData = frames[castbarType];
        if frameData.shield then
            frameData.shield:Hide();
        end
        return;
    elseif event == 'UNIT_SPELLCAST_NOT_INTERRUPTIBLE' then
        local frameData = frames[castbarType];
        if frameData.shield then
            frameData.shield:Show();
        end
        return;
    end

    -- Forzar ocultar castbar de Blizzard
    HideBlizzardCastbar(castbarType);

    -- ✅ MANEJAR EVENTOS PRINCIPALES como RetailUI
    if event == 'UNIT_SPELLCAST_START' then
        HandleCastStart(castbarType, unitToCheck);
    elseif event == 'UNIT_SPELLCAST_CHANNEL_START' then
        HandleChannelStart(castbarType, unitToCheck);
    elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
        -- ✅ Como RetailUI: procesar sin verificaciones extra
        if castbarType == "player" then
            state.castSucceeded = true;
        else
            FinishSpell(castbarType);
        end
    elseif event == 'UNIT_SPELLCAST_STOP' then
        -- ✅ COMO RETAILUI: Procesar directamente (GUID ya verificado arriba)
        HandleCastStop(castbarType, event, false);
    elseif event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
        -- ✅ COMO RETAILUI: Marcar selfInterrupt SOLO para channel stop
        state.selfInterrupt = true;
        HandleCastStop(castbarType, event, false);
    elseif event == 'UNIT_SPELLCAST_FAILED' then
        -- ✅ CRÍTICO: Solo aplicar cambios si NO es channeling
        if state.castingEx and not state.channelingEx then
            local frameData = frames[castbarType];
            frameData.castbar:SetStatusBarTexture(TEXTURES.standard); 
            frameData.castbar:SetStatusBarColor(1, 1, 1, 1);
            ForceStatusBarTextureLayer(frameData.castbar);
        end
    elseif event == 'UNIT_SPELLCAST_INTERRUPTED' then
        -- ✅ COMO RETAILUI: Usar selfInterrupt para determinar si mostrar "Interrupted"
        local showInterrupted = not state.selfInterrupt;
        
        -- ✅ CORREGIR: Para channeling, verificar si terminó naturalmente
        if state.channelingEx and not state.selfInterrupt then
            local currentTime = GetTime();
            local remainingTime = state.endTime - currentTime;
            local totalTime = state.endTime - state.startTime;
            local progressRemaining = remainingTime / totalTime;
            -- Si queda menos del 5% del tiempo, no es interrupción real
            if progressRemaining < 0.05 then
                showInterrupted = false;
            end
        end
        
        -- ✅ RESETEAR selfInterrupt después de usarlo
        state.selfInterrupt = false;
        
        HandleCastStop(castbarType, event, showInterrupted);
    end
end
local function HandleTargetChanged()
    -- Si el modo editor está activo, no hacer nada.
    if addon.EditorMode and addon.EditorMode:IsActive() then
        return;
    end

    -- Ocultar inmediatamente castbar de Blizzard target
    HideBlizzardCastbar("target");

    -- Reset completo del estado del castbar target
    local frameData = frames.target;
    local state = addon.castbarStates.target;

    if frameData.castbar then
        frameData.castbar:Hide();
        if frameData.background then
            frameData.background:Hide()
        end
        if frameData.textBackground then
            frameData.textBackground:Hide()
        end

        -- ✅ CORRECCIÓN: Usar variables del nuevo sistema
        state.castingEx = false;
        state.channelingEx = false;
        state.holdTime = 0;
        state.startTime = 0;
        state.endTime = 0;

        -- Limpiar elementos visuales
        if frameData.icon then frameData.icon:Hide() end
        if frameData.castTimeText then frameData.castTimeText:SetText("") end
        if frameData.castTimeTextCompact then frameData.castTimeTextCompact:SetText("") end
        if frameData.spark then frameData.spark:Hide() end
        if frameData.shield then frameData.shield:Hide() end

        -- Ocultar todos los ticks
        if frameData.ticks then
            for i = 1, #frameData.ticks do
                frameData.ticks[i]:Hide();
            end
        end
    end



    -- Verificar si el nuevo target ya está casteando
    if UnitExists("target") and addon.db.profile.castbar.target.enabled then
        addon.core:ScheduleTimer(function()
            local castName = UnitCastingInfo("target");
            local channelName = UnitChannelInfo("target");

            if castName then
                HandleCastingEvents("target", 'UNIT_SPELLCAST_START', "target");
            elseif channelName then
                HandleCastingEvents("target", 'UNIT_SPELLCAST_CHANNEL_START', "target");
            end

            -- ✅ USAR NUEVA FUNCIÓN
            ApplyRetailUIAuraOffsetToTargetCastbar();
        end, 0.05);
    end
end

-- Función para manejar cambios de focus
local function HandleFocusChanged()
    -- Ocultar inmediatamente castbar de Blizzard focus
    HideBlizzardCastbar("focus");

    -- Reset del estado del castbar focus
    local frameData = frames.focus;
    if frameData.castbar then
        FinishSpell("focus"); -- Usar función unificada
    end

    -- Aplicar posicionamiento del castbar focus después de pequeño delay
    if UnitExists("focus") and addon.db.profile.castbar.focus and addon.db.profile.castbar.focus.enabled then
        addon.core:ScheduleTimer(function()
            local cfg = addon.db.profile.castbar.focus;
            local anchorFrame = _G[cfg.anchorFrame] or FocusFrame or UIParent;
            if frameData.castbar then
                frameData.castbar:ClearAllPoints();
                frameData.castbar:SetPoint(cfg.anchor, anchorFrame, cfg.anchorParent, cfg.x_position, cfg.y_position);
            end
        end, 0.1);
    end
end

-- =================================================================
-- SISTEMA DE CREACIÓN DE CASTBARS UNIFICADO
-- =================================================================

-- Sistema de recorte dinámico  usando coordenadas UV
local function CreateTextureClippingSystem(statusBar)

    statusBar.UpdateTextureClipping = function(self, progress, isChanneling)
        local currentTexture = self:GetStatusBarTexture();
        if not currentTexture then
            return
        end

        -- Asegurar que la textura llene todo el frame
        currentTexture:ClearAllPoints();
        currentTexture:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, 0);
        currentTexture:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0);

        -- CRITICAL: Forzar que la StatusBar texture esté en la capa correcta
        -- En WoW 3.3.5a, algunas veces se reposiciona mal después de SetStatusBarTexture
        if currentTexture.SetDrawLayer then
            currentTexture:SetDrawLayer('BORDER', 0);
        end

        -- Aplicar recorte dinámico profesional usando coordenadas UV
        local clampedProgress = math.max(0.001, math.min(1, progress)); -- Evitar valores extremos

        if isChanneling then
            -- Para channeling: mostrar como barra que se vacía de derecha a izquierda
            -- progress va de 1.0 a 0.0, mostramos desde izquierda hasta esa posición
            currentTexture:SetTexCoord(0, clampedProgress, 0, 1);
        else
            -- Para casting: recorte de izquierda a derecha (empezar vacío, llenarse)
            currentTexture:SetTexCoord(0, clampedProgress, 0, 1);
        end
    end;
end

-- Función unificada para crear elementos de texto
local function CreateTextElements(parentFrame, castbarType, scale)
    local elements = {};
    local fontSize = castbarType == "player" and 'GameFontHighlight' or 'GameFontHighlightSmall';

    -- Texto principal (nombre del hechizo)
    elements.castText = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castText:SetPoint('BOTTOMLEFT', parentFrame, 'BOTTOMLEFT', castbarType == "player" and 8 or 6, 2);
    elements.castText:SetJustifyH("LEFT");
    elements.castText:SetWordWrap(false);

    -- Texto compacto (alternativa para espacios pequeños)
    elements.castTextCompact = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTextCompact:SetPoint('BOTTOMLEFT', parentFrame, 'BOTTOMLEFT', castbarType == "player" and 8 or 6, 2);
    elements.castTextCompact:SetJustifyH("LEFT");
    elements.castTextCompact:SetWordWrap(false);
    elements.castTextCompact:Hide();

    -- Texto de tiempo de cast
    elements.castTimeText = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTimeText:SetPoint('BOTTOMRIGHT', parentFrame, 'BOTTOMRIGHT', castbarType == "player" and -8 or -6, 2);
    elements.castTimeText:SetJustifyH("RIGHT");

    -- Texto compacto de tiempo de cast
    elements.castTimeTextCompact = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTimeTextCompact:SetPoint('BOTTOMRIGHT', parentFrame, 'BOTTOMRIGHT',
        castbarType == "player" and -8 or -6, 2);
    elements.castTimeTextCompact:SetJustifyH("RIGHT");
    elements.castTimeTextCompact:Hide();

    -- Texto centrado para modo simple (solo nombre de hechizo)
    elements.castTextCentered = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTextCentered:SetPoint('BOTTOM', parentFrame, 'BOTTOM', 0, 1);
    elements.castTextCentered:SetPoint('LEFT', parentFrame, 'LEFT', castbarType == "player" and 8 or 6, 0);
    elements.castTextCentered:SetPoint('RIGHT', parentFrame, 'RIGHT', castbarType == "player" and -8 or -6, 0);
    elements.castTextCentered:SetJustifyH("CENTER");
    elements.castTextCentered:SetJustifyV("BOTTOM");
    elements.castTextCentered:Hide();

    -- Para player castbar, elementos separados adicionales
    if castbarType == "player" then
        elements.timeValue = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
        elements.timeValue:SetPoint('BOTTOMRIGHT', parentFrame, 'BOTTOMRIGHT', -50, 2);
        elements.timeValue:SetJustifyH("RIGHT");

        elements.timeMax = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
        elements.timeMax:SetPoint('LEFT', elements.timeValue, 'RIGHT', 2, 0);
        elements.timeMax:SetJustifyH("LEFT");
    end

    return elements;
end

-- Función unificada para crear castbar
local function CreateCastbar(castbarType)
    if frames[castbarType].castbar then
        return
    end

    local frameName = 'DragonUI' .. castbarType:sub(1, 1):upper() .. castbarType:sub(2) .. 'Castbar';
    local frameData = frames[castbarType];

    -- ✅ OPTIMIZACIÓN: Frame más simple inicialmente
    frameData.castbar = CreateFrame('StatusBar', frameName, UIParent);
    frameData.castbar:SetFrameStrata("MEDIUM");
    frameData.castbar:SetFrameLevel(10);
    frameData.castbar:SetMinMaxValues(0, 1);
    frameData.castbar:SetValue(0);
    frameData.castbar:Hide();
    
    -- ✅ OPTIMIZACIÓN: Solo crear elementos si van a ser usados
    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
    end
    
    if not cfg then return end

    -- PASO 1: FONDO básico
    local bg = frameData.castbar:CreateTexture(nil, 'BACKGROUND');
    bg:SetTexture(TEXTURES.atlas);
    bg:SetTexCoord(unpack(UV_COORDS.background));
    bg:SetAllPoints();

    -- PASO 2: STATUSBAR TEXTURE
    frameData.castbar:SetStatusBarTexture(TEXTURES.standard);
    frameData.castbar:SetStatusBarColor(1, 0.7, 0, 1);
    ForceStatusBarTextureLayer(frameData.castbar);

    -- ✅ OPTIMIZACIÓN: Solo crear elementos necesarios según configuración
    if cfg.showBorder ~= false then
        local border = frameData.castbar:CreateTexture(nil, 'ARTWORK', nil, 0);
        border:SetTexture(TEXTURES.atlas);
        border:SetTexCoord(unpack(UV_COORDS.border));
        border:SetPoint("TOPLEFT", frameData.castbar, "TOPLEFT", -2, 2);
        border:SetPoint("BOTTOMRIGHT", frameData.castbar, "BOTTOMRIGHT", 2, -2);
    end

    -- ✅ OPTIMIZACIÓN: Ticks solo si pueden ser necesarios
    frameData.ticks = {};
    CreateChannelTicks(frameData.castbar, frameData.ticks, 15);

    -- SPARK (siempre necesario)
    frameData.spark = frameData.castbar:CreateTexture(nil, 'OVERLAY', nil, 1);
    frameData.spark:SetTexture(TEXTURES.spark);
    frameData.spark:SetBlendMode('ADD');
    frameData.spark:Hide();

    -- FLASH (siempre necesario)
    frameData.flash = frameData.castbar:CreateTexture(nil, 'OVERLAY');
    frameData.flash:SetTexture(TEXTURES.atlas);
    frameData.flash:SetTexCoord(unpack(UV_COORDS.flash));
    frameData.flash:SetBlendMode('ADD');
    frameData.flash:SetAllPoints();
    frameData.flash:Hide();

    -- ✅ OPTIMIZACIÓN: Solo crear icono si está habilitado
    if cfg.showIcon then
        frameData.icon = frameData.castbar:CreateTexture(frameName .. "Icon", 'ARTWORK');
        frameData.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
        frameData.icon:Hide();

        local iconBorder = frameData.castbar:CreateTexture(nil, 'ARTWORK');
        iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2");
        iconBorder:SetTexCoord(0.05, 0.95, 0.05, 0.95);
        iconBorder:SetVertexColor(0.8, 0.8, 0.8, 1);
        iconBorder:Hide();
        frameData.icon.Border = iconBorder;

        -- Escudo solo si hay icono
        if castbarType ~= "player" then
            frameData.shield = CreateSimplifiedShield(frameData.castbar, frameData.icon, frameName, SHIELD_CONFIG.baseIconSize);
        end
    end

    -- Aplicar sistemas
    ApplyVertexColor(frameData.castbar);
    CreateTextureClippingSystem(frameData.castbar);

    -- ✅ OPTIMIZACIÓN: Fondo de texto simplificado
    if cfg.text_mode ~= "none" then
        local textBgName = frameName .. 'TextBG';
        frameData.textBackground = CreateFrame('Frame', textBgName, UIParent);
        frameData.textBackground:SetFrameStrata("MEDIUM");
        frameData.textBackground:SetFrameLevel(9);
        frameData.textBackground:Hide();

        local textBg = frameData.textBackground:CreateTexture(nil, 'BACKGROUND');
        if castbarType == "player" then
            textBg:SetTexture(TEXTURES.atlas);
            textBg:SetTexCoord(0.001953125, 0.410109375, 0.00390625, 0.11328125);
        else
            textBg:SetTexture(TEXTURES.atlasSmall);
            textBg:SetTexCoord(unpack(UV_COORDS.textBorder));
        end
        textBg:SetAllPoints();

        -- Crear elementos de texto
        local textElements = CreateTextElements(frameData.textBackground, castbarType);
        for key, element in pairs(textElements) do
            frameData[key] = element;
        end
    end

    -- ✅ OPTIMIZACIÓN: Configurar OnUpdate handler
    frameData.castbar:SetScript('OnUpdate', CreateUpdateFunction(castbarType));
end
-- =================================================================
-- FUNCIONES DE REFRESH UNIFICADAS
-- =================================================================

-- Función unificada para refresh de castbars
RefreshCastbar = function(castbarType)
    -- CRITICAL: Protección contra refreshes muy frecuentes
    local currentTime = GetTime();
    local timeSinceLastRefresh = currentTime - (lastRefreshTime[castbarType] or 0);
    if timeSinceLastRefresh < 0.1 and (lastRefreshTime[castbarType] or 0) > 0 then
        return;
    end

    lastRefreshTime[castbarType] = currentTime;

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then return end
    end

    if not cfg then return end

    -- Manejar castbar de Blizzard primero
    if not cfg.enabled then
        ShowBlizzardCastbar(castbarType);
        -- Ocultar nuestro castbar y salir
        local frameData = frames[castbarType];
        if frameData.castbar then
            frameData.castbar:Hide();
            if frameData.background then frameData.background:Hide() end
            if frameData.textBackground then frameData.textBackground:Hide() end
            
            -- ✅ CORRECCIÓN: Usar variables del nuevo sistema
            local state = addon.castbarStates[castbarType];
            state.castingEx = false;
            state.channelingEx = false;
            state.holdTime = 0;
        end
        return;
    end

    -- Crear castbar si no existe
    if not frames[castbarType].castbar then
        CreateCastbar(castbarType);
    end

    local frameData = frames[castbarType];
    local frameName = 'DragonUI' .. castbarType:sub(1, 1):upper() .. castbarType:sub(2) .. 'Castbar';
    -- Calcular offset de auras para target
    local auraOffset = 0;
    if castbarType == "target" and cfg.autoAdjust then
        auraOffset = GetTargetAuraOffsetRetailUI();
    end

    -- Posicionar y dimensionar castbar principal
    frameData.castbar:ClearAllPoints();
    local scale = UIParent:GetEffectiveScale()

    if cfg.override then
        -- MODO MANUAL: Posición guardada por el usuario (Editor Mode)
        -- Convertimos las coordenadas absolutas guardadas a puntos de UI.
        local x = (cfg.x_position or 0) / scale
        local y = (cfg.y_position or 0) / scale
        frameData.castbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y);
    else
        -- MODO AUTOMÁTICO: Posicionamiento por defecto desde las opciones.
        local anchorFrame = UIParent;
        local anchorPoint = "CENTER";
        local relativePoint = "BOTTOM";
        local xPos = cfg.x_position or 0;
        local yPos = cfg.y_position or 200;

        if castbarType ~= "player" then
            anchorFrame = _G[cfg.anchorFrame] or (castbarType == "target" and TargetFrame or FocusFrame) or UIParent;
            anchorPoint = cfg.anchor or "CENTER";
            relativePoint = cfg.anchorParent or "BOTTOM";
        end
        frameData.castbar:SetPoint(anchorPoint, anchorFrame, relativePoint, xPos, yPos - auraOffset);
    end

    frameData.castbar:SetSize(cfg.sizeX or 200, cfg.sizeY or 16);
    frameData.castbar:SetScale(cfg.scale or 1);
    
    -- Posicionar frame de fondo de texto
    if frameData.textBackground then
        frameData.textBackground:ClearAllPoints();
        frameData.textBackground:SetPoint('TOP', frameData.castbar, 'BOTTOM', 0, castbarType == "player" and 6 or 8);
        frameData.textBackground:SetSize(cfg.sizeX or 200, castbarType == "player" and 22 or 20);
        frameData.textBackground:SetScale(cfg.scale or 1);
    end

     -- ✅ CORRECCIÓN REFORZADA: Forzar visibilidad de la barra y sus fondos en modo editor
    if addon.EditorMode and addon.EditorMode:IsActive() then
        if frameData.castbar then frameData.castbar:Show() end
        if frameData.background and frameData.background ~= frameData.textBackground then frameData.background:Show() end
        if frameData.textBackground then frameData.textBackground:Show() end
    end

    -- Posicionar frame de fondo adicional
    if frameData.background and frameData.background ~= frameData.textBackground then
        frameData.background:ClearAllPoints();
        frameData.background:SetAllPoints(frameData.castbar);
        frameData.background:SetScale(cfg.scale or 1);
    end

    -- Configurar icono
    if frameData.icon then
        local iconSize = cfg.sizeIcon or 20;
        frameData.icon:SetSize(iconSize, iconSize);
        frameData.icon:ClearAllPoints();

        if castbarType == "player" then
            -- Posicionar a la izquierda del castbar
            local offsetX = -(iconSize + 6);
            frameData.icon:SetPoint('TOPLEFT', frameData.castbar, 'TOPLEFT', offsetX, -1);
        else
            -- Posicionamiento exacto como ultimaversion
            local iconScale = iconSize / 16;
            frameData.icon:SetPoint('RIGHT', frameData.castbar, 'LEFT', -7 * iconScale, -4);
        end

        frameData.icon:SetAlpha(1);

        -- Actualizar tamaños proporcionales
        UpdateProportionalSizes(castbarType, iconSize);

        -- Configurar borde del icono
        if frameData.icon.Border then
            frameData.icon.Border:ClearAllPoints();
            frameData.icon.Border:SetPoint('CENTER', frameData.icon, 'CENTER', 0, 0);
            if cfg.showIcon then
                frameData.icon.Border:Show();
            else
                frameData.icon.Border:Hide();
            end
        end

        -- Configurar escudo (posicionado relativo al icono)
        if frameData.shield then
            if castbarType == "player" then
                frameData.shield:ClearAllPoints();
                frameData.shield:SetPoint('CENTER', frameData.icon, 'CENTER', 0, 0);
                frameData.shield:SetSize(iconSize * 0.8, iconSize * 0.8);
            else
                -- El escudo simplificado se posiciona automáticamente
            end
            frameData.shield:Hide();
        end

        -- Aplicar visibilidad del icono
        SetIconVisibility(castbarType, cfg.showIcon or false);
    end

    -- Actualizar tamaño del spark (proporcional a la altura del castbar)
    if frameData.spark then
        local sparkHeight = (cfg.sizeY or 16) * 2;
        local sparkWidth = sparkHeight / 2; -- Mantener la proporción
        frameData.spark:SetSize(sparkWidth, sparkHeight);
    end

    -- Actualizar tamaños de ticks
    if frameData.ticks then
        for i = 1, #frameData.ticks do
            frameData.ticks[i]:SetSize(3, (cfg.sizeY or 16) - 2);
        end
    end

    -- Configurar layout compacto para target y focus
    if castbarType ~= "player" then
        SetCompactLayout(castbarType, true);
    end

    -- Asegurar que los frames estén correctamente en capas
    frameData.castbar:SetFrameLevel(10);
    if frameData.background then
        frameData.background:SetFrameLevel(9)
    end
    if frameData.textBackground then
        frameData.textBackground:SetFrameLevel(9)
    end

    -- Forzar ocultar castbar de Blizzard nuevamente
    HideBlizzardCastbar(castbarType);

    -- Asegurar que el color de vértice se mantenga después del refresh
    ApplyVertexColor(frameData.castbar);

    -- CRITICAL: Forzar orden de capas después del refresh (doble seguridad)
    -- Esto garantiza que múltiples refreshes no alteren el sublevel del spark
    -- CORREGIDO: Usar la función helper para asegurar que se usa el sublevel correcto (5)

    -- Aplicar configuración de modo de texto
    if cfg.text_mode then
        SetTextMode(castbarType, cfg.text_mode);
    end

end

-- =================================================================
-- MANEJADOR PRINCIPAL DE EVENTOS
-- =================================================================

-- Función principal de manejo de eventos unificada
function OnCastbarEvent(self, event, unit, ...)
    -- Manejar PLAYER_FOCUS_CHANGED para castbar focus
    if event == 'PLAYER_FOCUS_CHANGED' then
        HandleFocusChanged();
        return;
    end

    -- Manejar PLAYER_TARGET_CHANGED para castbar target
    if event == 'PLAYER_TARGET_CHANGED' then
        HandleTargetChanged();
        return;
    end

    -- Manejar PLAYER_ENTERING_WORLD para inicialización
    if event == 'PLAYER_ENTERING_WORLD' then
        -- Ocultar inmediatamente castbars de Blizzard
        if addon.db.profile.castbar.enabled then
            HideBlizzardCastbar("player");
        end
        if addon.db.profile.castbar.target and addon.db.profile.castbar.target.enabled then
            HideBlizzardCastbar("target");
        end
        if addon.db.profile.castbar.focus and addon.db.profile.castbar.focus.enabled then
            HideBlizzardCastbar("focus");
        end

        -- Pequeño delay para asegurar que todos los frames de Blizzard estén cargados
        addon.core:ScheduleTimer(function()
            RefreshCastbar("player");
            RefreshCastbar("target");
            RefreshCastbar("focus");

            -- Verificación extra para ocultar castbars de Blizzard después de que todo se cargue
            addon.core:ScheduleTimer(function()
                if addon.db.profile.castbar.enabled then
                    HideBlizzardCastbar("player");
                end
                if addon.db.profile.castbar.target and addon.db.profile.castbar.target.enabled then
                    HideBlizzardCastbar("target");
                end
                if addon.db.profile.castbar.focus and addon.db.profile.castbar.focus.enabled then
                    HideBlizzardCastbar("focus");
                end
            end, 1.0);
        end, 0.5);
        return;
    end

    -- Determinar tipo de castbar basado en unit
    local castbarType;
    if unit == 'player' then
        castbarType = "player";
    elseif unit == 'target' then
        castbarType = "target";
    elseif unit == 'focus' then
        castbarType = "focus";
    else
        return; -- Unidad no soportada
    end

    -- Delegar a manejador de eventos de casting unificado
    HandleCastingEvents(castbarType, event, unit, ...);
end

-- =================================================================
-- FUNCIONES PÚBLICAS PARA EL ADDON
-- =================================================================

-- Función pública para refresh de castbar del player
function addon.RefreshCastbar()
    RefreshCastbar("player");
end

-- Función pública para refresh de castbar del target
function addon.RefreshTargetCastbar()
    RefreshCastbar("target");
end

-- Función pública para refresh de castbar del focus
function addon.RefreshFocusCastbar()
    RefreshCastbar("focus");
end

-- =================================================================
-- INICIALIZACIÓN DEL MÓDULO
-- =================================================================

-- Función de inicialización del módulo
local function InitializeCastbar()
    -- Crear frame de inicialización único para todos los eventos
    local initFrame = CreateFrame('Frame', 'DragonUICastbarEventHandler');

    -- ✅ CAMBIAR: Solo eventos esenciales como RetailUI
    local essentialEvents = {
        'PLAYER_ENTERING_WORLD', 
        'UNIT_SPELLCAST_START', 
        'UNIT_SPELLCAST_STOP', 
        'UNIT_SPELLCAST_FAILED',
        'UNIT_SPELLCAST_INTERRUPTED', 
        'UNIT_SPELLCAST_CHANNEL_START', 
        'UNIT_SPELLCAST_CHANNEL_STOP',
        'UNIT_SPELLCAST_SUCCEEDED',
        'UNIT_SPELLCAST_DELAYED',           
        'UNIT_SPELLCAST_CHANNEL_UPDATE',    
        'UNIT_SPELLCAST_INTERRUPTIBLE',     
        'UNIT_SPELLCAST_NOT_INTERRUPTIBLE', 
        'PLAYER_TARGET_CHANGED', 
        'PLAYER_FOCUS_CHANGED'
    };

    for _, event in ipairs(essentialEvents) do
        initFrame:RegisterEvent(event);
    end

    initFrame:SetScript('OnEvent', OnCastbarEvent);

    -- ✅ CRÍTICO: DESREGISTRAR EVENTOS DE BLIZZARD al inicializar como RetailUI
    if CastingBarFrame and CastingBarFrame.UnregisterAllEvents then
        CastingBarFrame:UnregisterAllEvents();
    end
    if TargetFrameSpellBar and TargetFrameSpellBar.UnregisterAllEvents then
        TargetFrameSpellBar:UnregisterAllEvents();
    end
    if FocusFrameSpellBar and FocusFrameSpellBar.UnregisterAllEvents then
        FocusFrameSpellBar:UnregisterAllEvents();
    end

    -- ✅ MANTENER: Hook solo si UNIT_AURA se va a usar
    if TargetFrameSpellBar then
        hooksecurefunc('Target_Spellbar_AdjustPosition', function(self)
            if addon.db and addon.db.profile.castbar and addon.db.profile.castbar.target and
                addon.db.profile.castbar.target.autoAdjust then
                addon.core:ScheduleTimer(function()
                    ApplyRetailUIAuraOffsetToTargetCastbar();
                end, 0.05);
            end
        end);
    end
end

-- Iniciar inicialización
InitializeCastbar();

