local addon = select(2, ...);

-- #################################################################
-- ##              DragonUI Editor Mode Integrado                  ##
-- ##          Sincroniza con sliders X/Y de options.lua          ##
-- #################################################################

local EditorMode = {};
addon.EditorMode = EditorMode;

-- =================================================================
-- VARIABLES Y CONFIGURACIÓN
-- =================================================================

local isEditorActive = false;
local editableFrames = {};
local gridOverlay = nil; -- ✅ Variable para nuestra rejilla
local exitEditorButton = nil;


-- =================================================================
-- ✅ BOTÓN DE SALIDA DEL MODO EDITOR
-- =================================================================
local function createExitButton()
    if exitEditorButton then return; end

    -- Crear el botón
    exitEditorButton = CreateFrame("Button", "DragonUIExitEditorButton", UIParent, "UIPanelButtonTemplate");
    exitEditorButton:SetText("Exit Edit Mode");
    exitEditorButton:SetSize(160, 32);
    exitEditorButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200); -- Posición flotante
    exitEditorButton:SetFrameStrata("DIALOG"); -- Asegura que esté por encima de otros elementos
    exitEditorButton:SetFrameLevel(100);

    -- Asignar la acción de salida
    exitEditorButton:SetScript("OnClick", function()
        EditorMode:Toggle();
    end);

    exitEditorButton:Hide(); -- Oculto por defecto
end


-- =================================================================
-- ✅ SISTEMA DE REJILLA DE FONDO (GRID) - CORRECCIÓN DE COMPATIBILIDAD 3.3.5a
-- =================================================================
local function createGridOverlay()
    -- Optimización: No recrear el grid si ya existe.
    if gridOverlay then return; end

    local boxSize = 32 -- Número de celdas de la rejilla.
    
    -- Frame principal que contendrá todas las líneas.
    gridOverlay = CreateFrame('Frame', "DragonUIGridOverlayFrame", UIParent) 
    gridOverlay:SetAllPoints(UIParent)
    gridOverlay:SetFrameStrata("BACKGROUND");
    gridOverlay:SetFrameLevel(0);

    local lineThickness = 1 
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()

    -- === DIBUJAR LÍNEAS VERTICALES ===
    local wStep = screenWidth / boxSize
    for i = 0, boxSize do 
        -- Usamos nombres únicos para máxima seguridad
        local line = gridOverlay:CreateTexture("DragonUIGridLineV"..i, 'BACKGROUND') 
        
        if i == boxSize / 2 then 
            -- ✅ CORRECCIÓN: Usar SetTexture, que es más compatible con 3.3.5a
            line:SetTexture(1, 0, 0, 0.5) 
        else 
            line:SetTexture(0, 0, 0, 0.5) 
        end 
        
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", (i * wStep) - (lineThickness / 2), 0) 
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'BOTTOMLEFT', (i * wStep) + (lineThickness / 2), 0) 
    end 

    -- === DIBUJAR LÍNEAS HORIZONTALES ===
    local hStep = screenHeight / boxSize
    for i = 0, boxSize do
        -- Usamos nombres únicos para máxima seguridad
        local line = gridOverlay:CreateTexture("DragonUIGridLineH"..i, 'BACKGROUND')
        
        if i == boxSize / 2 then
            -- ✅ CORRECCIÓN: Usar SetTexture, que es más compatible con 3.3.5a
            line:SetTexture(1, 0, 0, 0.5)
        else
            line:SetTexture(0, 0, 0, 0.5)
        end
        
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", 0, -(i * hStep) + (lineThickness / 2))
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'TOPRIGHT', 0, -(i * hStep) - (lineThickness / 2))
    end
    
    gridOverlay:Hide() -- Oculta por defecto
end


-- =================================================================
-- UTILIDADES DE COORDENADAS
-- =================================================================

-- Obtener valor de la base de datos usando path
local function getDbValue(dbPath, key)
    local current = addon.db.profile;
    for _, pathPart in ipairs(dbPath) do
        if not current or not current[pathPart] then return nil; end
        current = current[pathPart];
    end
    return current[key];
end

-- Establecer valor en la base de datos usando path
local function setDbValue(dbPath, key, value)
    local current = addon.db.profile;
    for i, pathPart in ipairs(dbPath) do
        if not current[pathPart] then current[pathPart] = {}; end
        if i == #dbPath then
            current[pathPart][key] = value;
        else
            current = current[pathPart];
        end
    end
end

-- Convertir posición del frame a coordenadas BOTTOMLEFT de UIParent
local function getBottomLeftCoordinates(frame)
    local scale = UIParent:GetEffectiveScale()
    local frameLeft = frame:GetLeft() * scale;
    local frameBottom = frame:GetBottom() * scale;
    return frameLeft, frameBottom
end

-- Función especial para obtener el frame correcto de action bars
local function getActionBarFrame(frameName)
    if frameName == "pUiMainBar" then
        return addon.pUiMainBar or _G["pUiMainBar"];
    else
        return _G[frameName];
    end
end

-- =================================================================
-- MAPEO DE CONFIGURACIÓN
-- =================================================================

-- Mapeo de módulos a sus configuraciones en la base de datos
local moduleConfig = {
    -- Castbars
    ["DragonUIPlayerCastbar"] = { dbPath = {"castbar"}, xKey = "x_position", yKey = "y_position", refreshFunc = "RefreshCastbar", displayName = "Player Castbar", castbar = true },
    ["DragonUITargetCastbar"] = { dbPath = {"castbar", "target"}, xKey = "x_position", yKey = "y_position", refreshFunc = "RefreshTargetCastbar", displayName = "Target Castbar", castbar = true },
    ["DragonUIFocusCastbar"] = { dbPath = {"castbar", "focus"}, xKey = "x_position", yKey = "y_position", refreshFunc = "RefreshFocusCastbar", displayName = "Focus Castbar", castbar = true },

    -- Unit Frames
    ["PlayerFrame"] = { dbPath = {"unitframe", "player"}, xKey = "x", yKey = "y", refreshFunc = "RefreshUnitFrames", displayName = "Player Frame", unitframe = true },
    ["TargetFrame"] = { dbPath = {"unitframe", "target"}, xKey = "x", yKey = "y", refreshFunc = "RefreshUnitFrames", displayName = "Target Frame", unitframe = true },
    ["FocusFrame"] = { dbPath = {"unitframe", "focus"}, xKey = "x", yKey = "y", refreshFunc = "RefreshUnitFrames", displayName = "Focus Frame", unitframe = true },
    ["PetFrame"] = { dbPath = {"unitframe", "pet"}, xKey = "x", yKey = "y", refreshFunc = "RefreshUnitFrames", displayName = "Pet Frame", unitframe = true },

    -- =========================================================================
    -- ✅ ACTION BARS - CONFIGURACIÓN ACTUALIZADA
    -- =========================================================================
    ["pUiMainBar"] = {
        dbPath = {"mainbars", "player"}, -- Ruta a la config de la barra principal
        xKey = "x",
        yKey = "y",
        refreshFunc = "PositionActionBars",
        displayName = "Main Action Bar",
        actionbar = true
    },
    ["MultiBarLeft"] = {
        dbPath = {"mainbars", "left"}, -- Ruta a la config de la barra izquierda
        xKey = "x",
        yKey = "y",
        refreshFunc = "PositionActionBars",
        displayName = "Left Action Bar",
        actionbar = true
    },
    ["MultiBarRight"] = {
        dbPath = {"mainbars", "right"}, -- Ruta a la config de la barra derecha
        xKey = "x",
        yKey = "y",
        refreshFunc = "PositionActionBars",
        displayName = "Right Action Bar",
        actionbar = true
    },

     ["DragonUIPartyMoveFrame"] = {
        dbPath = {"unitframe", "party"},
        xKey = "x",
        yKey = "y",
        refreshFunc = "RefreshUnitFrames",
        displayName = "Party Frames",
        partyframe = true -- Flag para lógica especial
    },

    -- Stance Bar, Pet Bar, etc. (sin cambios)
    ["StanceBarFrame"] = { dbPath = {"additional", "stance"}, xKey = "x_position", yKey = "y_position", refreshFunc = "RefreshStance", displayName = "Stance Bar" },
    ["PetActionBarFrame"] = { dbPath = {"additional", "pet"}, xKey = "x_position", yKey = "y_position", refreshFunc = "RefreshPetbar", displayName = "Pet Bar" },
    ["MicroButtonAndBagsBar"] = { dbPath = {"micromenu"}, xKey = "x_position", yKey = "y_position", refreshFunc = "RefreshMicromenu", displayName = "Micro Menu" },
    ["ChatFrame1"] = { dbPath = {"chat"}, xKey = "x_position", yKey = "y_position", refreshFunc = "RefreshChat", displayName = "Chat Frame" }
};

-- =================================================================
-- SISTEMA DE OVERLAY VISUAL
-- =================================================================

local function createOverlay(frame, config)
    local overlay = CreateFrame("Frame", nil, frame);
    overlay:SetAllPoints(frame);
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10);
    overlay:SetFrameStrata("DIALOG");
    overlay:EnableMouse(true);
    overlay:SetMovable(true);

    local bg = overlay:CreateTexture(nil, "BACKGROUND");
    bg:SetAllPoints();
    bg:SetTexture(0, 0.5, 1, 0.2);

    local border = overlay:CreateTexture(nil, "BORDER");
    border:SetAllPoints();
    border:SetTexture(1, 1, 1, 0.6);

    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    text:SetPoint("CENTER");
    text:SetText(config.displayName);
    text:SetTextColor(1, 1, 1, 0.9);
    text:SetShadowOffset(1, -1);
    text:SetShadowColor(0, 0, 0, 1);

    overlay:Hide();
    return overlay;
end

-- =================================================================
-- SISTEMA DE ARRASTRAR Y SOLTAR (LÓGICA CENTRAL)
-- =================================================================

local function makeFrameMovable(frame, config)
    if editableFrames[frame] then return; end

    frame:SetMovable(true);
    frame:EnableMouse(true);
    
    -- ✅ DESACTIVAR SNAPPING AUTOMÁTICO
    frame:SetClampedToScreen(false);  -- ✅ Permite que salga de pantalla
    if frame.SetDontSavePosition then
        frame:SetDontSavePosition(true);  -- ✅ Evita que WoW guarde posición automáticamente
    end

    local overlay = createOverlay(frame, config);
    overlay:EnableMouse(true);
    overlay:RegisterForDrag("LeftButton");

    -- ✅ VARIABLES PARA TRACKING PRECISO
    local isDragging = false;
    local startX, startY;

    overlay:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        
        -- ✅ GUARDAR POSICIÓN INICIAL EXACTA
        startX, startY = frame:GetLeft(), frame:GetBottom();
        isDragging = true;
        
        -- ✅ CONFIGURAR FRAME PARA MOVIMIENTO PRECISO
        frame:SetUserPlaced(false);  -- ✅ CLAVE: Evita que WoW interfiera
        frame:StartMoving();
    end);

    overlay:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        
        frame:StopMovingOrSizing();
        isDragging = false;
        
        -- ✅ OBTENER POSICIÓN FINAL EXACTA INMEDIATAMENTE
        local finalX, finalY = frame:GetLeft(), frame:GetBottom();

        -- ✅ =================================================================
        -- ✅ LÓGICA DE GUARDADO DE POSICIONES (CORREGIDA)
        -- ✅ =================================================================

        if config.actionbar then
            -- === LÓGICA ESPECÍFICA PARA BARRAS DE ACCIÓN ===
            setDbValue(config.dbPath, "override", true)
            setDbValue(config.dbPath, config.xKey, finalX)
            setDbValue(config.dbPath, config.yKey, finalY)
           
            if addon[config.refreshFunc] then
                addon[config.refreshFunc]()
            end
        
        elseif config.castbar then
            -- === LÓGICA ESPECÍFICA PARA CASTBARS ===
            setDbValue(config.dbPath, "override", true)
            setDbValue(config.dbPath, config.xKey, finalX)
            setDbValue(config.dbPath, config.yKey, finalY)
            
            if addon[config.refreshFunc] then
                addon[config.refreshFunc]()
            end

       elseif config.partyframe then
           -- === LÓGICA ESPECÍFICA PARA PARTY FRAMES ===
            setDbValue(config.dbPath, "override", true)
            setDbValue(config.dbPath, "anchor", "BOTTOMLEFT")
            setDbValue(config.dbPath, "anchorParent", "UIParent")
            setDbValue(config.dbPath, "anchorPoint", "BOTTOMLEFT")
            setDbValue(config.dbPath, config.xKey, finalX)
            setDbValue(config.dbPath, config.yKey, finalY)
            
            if addon.RefreshUnitFrames then
                addon:RefreshUnitFrames()
            end

         else
            if config.unitframe then
                -- ✅ LÓGICA ESPECÍFICA PARA UNITFRAMES (CORREGIDA)
                if frame == PlayerFrame then
                    -- ✅ USAR COORDENADAS TOPLEFT PARA CONSISTENCIA
                    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
                    
                    setDbValue(config.dbPath, "override", true)
                    setDbValue(config.dbPath, "anchor", point or "TOPLEFT")  -- ✅ Usar el punto actual
                    setDbValue(config.dbPath, "anchorParent", relativePoint or "TOPLEFT") 
                    setDbValue(config.dbPath, config.xKey, xOfs or finalX)  -- ✅ Usar offset o coordenada absoluta
                    setDbValue(config.dbPath, config.yKey, yOfs or finalY)
                    
                    print("|cFF00FF00[DragonUI]|r PlayerFrame moved to position:", point, xOfs, yOfs)
                    
                    -- ✅ REFRESH INMEDIATO SIN DELAY - EVITA DOUBLE REFRESH
                    if addon.PlayerFrame and addon.PlayerFrame.Refresh then
                        addon.PlayerFrame.Refresh()
                    end
                    
                else
                    -- Para otros UnitFrames
                    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
                    setDbValue(config.dbPath, "override", true)
                    setDbValue(config.dbPath, "anchor", point or "TOPLEFT")
                    setDbValue(config.dbPath, "anchorParent", relativePoint or "TOPLEFT")
                    setDbValue(config.dbPath, config.xKey, xOfs or finalX)
                    setDbValue(config.dbPath, config.yKey, yOfs or finalY)
                    
                    if addon.RefreshUnitFrames then
                        addon.RefreshUnitFrames()
                    end
                end
            else
                -- Para el resto (Stance, Pet, etc.)
                local _, _, _, xOfs, yOfs = frame:GetPoint()
                setDbValue(config.dbPath, config.xKey, xOfs)
                setDbValue(config.dbPath, config.yKey, yOfs)
            end
        end

        -- ✅ NOTIFICAR CAMBIOS A ACECONFIG
        if LibStub and LibStub("AceConfigRegistry", true) then
            LibStub("AceConfigRegistry"):NotifyChange("DragonUI");
        end
    end);

    -- ✅ SCRIPT ADICIONAL: Prevenir snapping durante el drag
    overlay:SetScript("OnUpdate", function(self)
        if isDragging and frame then
            -- ✅ Mantener el frame "libre" durante el arrastre
            frame:SetUserPlaced(false);
        end
    end);

    editableFrames[frame] = {
        overlay = overlay,
        config = config,
        originalMovable = frame:IsMovable(),
        originalMouseEnabled = frame:IsMouseEnabled(),
        originalClamped = frame:IsClampedToScreen()  -- ✅ Guardar estado original
    };
end

-- =================================================================
-- FUNCIONES PÚBLICAS (Show, Hide, Toggle)
-- =================================================================
function EditorMode:Show()
    if InCombatLockdown() then print("[DragonUI] Cannot enter editor mode while in combat!"); return; end
    isEditorActive = true;
    local frameCount = 0;

    -- ✅ Mostrar la rejilla y el botón de salida
    createGridOverlay();
    createExitButton(); -- Asegura que el botón exista
    if gridOverlay then gridOverlay:Show(); end
    if exitEditorButton then exitEditorButton:Show(); end

    -- Forzar mostrar frames para edición
    if TargetFrame then TargetFrame:Show(); end
    if FocusFrame then FocusFrame:Show(); end
    if PetFrame then PetFrame:Show(); end
    if StanceBarFrame then StanceBarFrame:Show(); end
    if PetActionBarFrame then PetActionBarFrame:Show(); end
    if addon.pUiMainBar then addon.pUiMainBar:Show(); end
    if MultiBarLeft then MultiBarLeft:Show(); end
    if MultiBarRight then MultiBarRight:Show(); end
-- ✅ CORRECCIÓN: Forzar la visibilidad de TODOS los componentes de las castbars.
    -- Esto asegura que se muestren correctamente incluso si fueron ocultadas por el ciclo de vida normal del addon.
    if _G["DragonUIPlayerCastbar"] then _G["DragonUIPlayerCastbar"]:Show() end
    if _G["DragonUIPlayerCastbarTextBG"] then _G["DragonUIPlayerCastbarTextBG"]:Show() end

    if _G["DragonUITargetCastbar"] then _G["DragonUITargetCastbar"]:Show() end
    if _G["DragonUITargetCastbarTextBG"] then _G["DragonUITargetCastbarTextBG"]:Show() end
    if _G["DragonUITargetCastbarBackground"] then _G["DragonUITargetCastbarBackground"]:Show() end

    if _G["DragonUIFocusCastbar"] then _G["DragonUIFocusCastbar"]:Show() end
    if _G["DragonUIFocusCastbarTextBG"] then _G["DragonUIFocusCastbarTextBG"]:Show() end
    if _G["DragonUIFocusCastbarBackground"] then _G["DragonUIFocusCastbarBackground"]:Show() end

    -- ✅ CORRECCIÓN 2: Forzar un refresco de las barras DESPUÉS de mostrarlas.
    -- Esto recalcula su posición y estado en el contexto del modo editor.
    if addon.RefreshCastbar then addon.RefreshCastbar() end
    if addon.RefreshTargetCastbar then addon.RefreshTargetCastbar() end
    if addon.RefreshFocusCastbar then addon.RefreshFocusCastbar() end

    -- ✅ Lógica para los Party Frames (CORREGIDO)
    if GetNumPartyMembers() == 0 then
        -- No estamos en grupo, mostrar frames falsos
        if addon.unitframe and addon.unitframe.ForceInitPartyFrames then
            addon.unitframe.ForceInitPartyFrames()
        end
        if _G["DragonUIPartyMoveFrame"] then
            _G["DragonUIPartyMoveFrame"]:Show()
            for i = 1, 4 do
                if _G["PartyMemberFrame"..i] then _G["PartyMemberFrame"..i]:Show() end
            end
        end
    end

     -- Configurar todos los frames disponibles
    for frameName, config in pairs(moduleConfig) do
        local frame
        if config.actionbar then
            frame = getActionBarFrame(frameName)
        elseif config.partyframe then
            frame = _G[frameName] or (addon.unitframe and addon.unitframe.PartyMoveFrame)
        elseif config.castbar then
            frame = _G[frameName]
        else
            frame = _G[frameName]
        end
        
        if frame then
            makeFrameMovable(frame, config);
            if editableFrames[frame] then
                editableFrames[frame].overlay:Show();
                frameCount = frameCount + 1;
            end
        end
    end


end
function EditorMode:Hide()
    isEditorActive = false;
    
    if gridOverlay then gridOverlay:Hide(); end
    if exitEditorButton then exitEditorButton:Hide(); end
    
    -- ✅ RESTAURAR CONFIGURACIONES ORIGINALES
    for frame, data in pairs(editableFrames) do
        data.overlay:Hide();
        frame:SetMovable(data.originalMovable);
        frame:EnableMouse(data.originalMouseEnabled);
        frame:SetClampedToScreen(data.originalClamped);  -- ✅ Restaurar clamping original
        
        -- ✅ RESTAURAR SetDontSavePosition si existe
        if frame.SetDontSavePosition then
            frame:SetDontSavePosition(false);
        end
    end
    
    -- ✅ Resto del código sin cambios...
    
    -- ✅ Restaurar visibilidad normal de TODOS los frames
    if TargetFrame and not UnitExists("target") then TargetFrame:Hide(); end
    if FocusFrame and not UnitExists("focus") then FocusFrame:Hide(); end
    if PetFrame and not UnitExists("pet") then PetFrame:Hide(); end
    if StanceBarFrame and not GetNumShapeshiftForms() > 0 then StanceBarFrame:Hide(); end
    if PetActionBarFrame and not HasPetUI() then PetActionBarFrame:Hide(); end
     -- Ocultar castbars si no se está casteando nada (usando el estado interno)
     -- ✅ CORRECCIÓN DEFINITIVA: Ocultar todas las partes de las castbars si no están en uso.
    -- Esto asegura una limpieza completa al salir del modo editor.
    if addon.castbarStates then
        -- Player
        if addon.castbarStates.player and not addon.castbarStates.player.casting then
            if _G["DragonUIPlayerCastbar"] then _G["DragonUIPlayerCastbar"]:Hide() end
            if _G["DragonUIPlayerCastbarTextBG"] then _G["DragonUIPlayerCastbarTextBG"]:Hide() end
        end
        -- Target
        if addon.castbarStates.target and not addon.castbarStates.target.casting then
            if _G["DragonUITargetCastbar"] then _G["DragonUITargetCastbar"]:Hide() end
            if _G["DragonUITargetCastbarTextBG"] then _G["DragonUITargetCastbarTextBG"]:Hide() end
            if _G["DragonUITargetCastbarBackground"] then _G["DragonUITargetCastbarBackground"]:Hide() end
        end
        -- Focus
        if addon.castbarStates.focus and not addon.castbarStates.focus.casting then
            if _G["DragonUIFocusCastbar"] then _G["DragonUIFocusCastbar"]:Hide() end
            if _G["DragonUIFocusCastbarTextBG"] then _G["DragonUIFocusCastbarTextBG"]:Hide() end
            if _G["DragonUIFocusCastbarBackground"] then _G["DragonUIFocusCastbarBackground"]:Hide() end
        end
    end

    -- ✅ CORRECCIÓN DEFINITIVA: Solo ocultar si la opción existe y está explícitamente en 'false'.
    if MultiBarLeft and addon.db.profile.actionbars and addon.db.profile.actionbars.multibar_left_enabled == false then MultiBarLeft:Hide(); end
    if MultiBarRight and addon.db.profile.actionbars and addon.db.profile.actionbars.multibar_right_enabled == false then MultiBarRight:Hide(); end

    -- ✅ Ocultar los party frames si no estamos en grupo
    if GetNumPartyMembers() == 0 then
        if _G["DragonUIPartyMoveFrame"] then
            _G["DragonUIPartyMoveFrame"]:Hide()
        end
    end

   
end

function EditorMode:Toggle()
    if isEditorActive then self:Hide(); else self:Show(); end
end

function EditorMode:IsActive()
    return isEditorActive;
end

-- =================================================================
-- COMANDOS SLASH
-- =================================================================

SLASH_DRAGONUI_EDITOR1 = "/duiedit";
SlashCmdList["DRAGONUI_EDITOR"] = function()
    EditorMode:Toggle();
end;