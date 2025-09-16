local addon = select(2, ...);

local EditorMode = {};
addon.EditorMode = EditorMode;

local gridOverlay = nil;
local exitEditorButton = nil;

-- ✅ BOTÓN DE SALIDA DEL MODO EDITOR
local function createExitButton()
    if exitEditorButton then return; end

    -- Crear el botón
    exitEditorButton = CreateFrame("Button", "DragonUIExitEditorButton", UIParent, "UIPanelButtonTemplate");
    exitEditorButton:SetText("Exit Edit Mode");
    exitEditorButton:SetSize(100, 24);
    exitEditorButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200); -- Posición flotante centrada
    exitEditorButton:SetFrameStrata("DIALOG"); -- Asegura que esté por encima de otros elementos
    exitEditorButton:SetFrameLevel(100);

    -- Asignar la acción de salida
    exitEditorButton:SetScript("OnClick", function()
        EditorMode:Toggle();
    end);

    exitEditorButton:Hide(); -- Oculto por defecto
end

-- ✅ TU GRID MEJORADO - AHORA CUADRADOS SIMÉTRICOS
local function createGridOverlay()
    if gridOverlay then return; end

    -- ✅ CAMBIO: Hacer cuadrados SIMÉTRICOS con línea central EXACTA
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    -- ✅ ALGORITMO SIMÉTRICO: Partir desde el centro hacia afuera
    local cellSize = 32  -- Tamaño base de celda
    
    -- Calcular cuántas celdas completas caben desde el centro hacia cada lado
    local halfCellsHorizontal = math.floor((screenWidth / 2) / cellSize)
    local halfCellsVertical = math.floor((screenHeight / 2) / cellSize)
    
    -- Total de celdas (siempre par para que el centro sea exacto)
    local totalHorizontalCells = halfCellsHorizontal * 2
    local totalVerticalCells = halfCellsVertical * 2
    
    -- Recalcular el tamaño real de celda para que sea perfectamente simétrico
    local actualCellWidth = screenWidth / totalHorizontalCells
    local actualCellHeight = screenHeight / totalVerticalCells
    
    -- Posición exacta del centro
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    gridOverlay = CreateFrame('Frame', "DragonUIGridOverlay", UIParent)
    gridOverlay:SetAllPoints(UIParent)
    gridOverlay:SetFrameStrata("BACKGROUND")
    gridOverlay:SetFrameLevel(0)

    -- ✅ AÑADIR CAPA DE FONDO OSCURA SEMI-TRANSPARENTE
    local background = gridOverlay:CreateTexture("DragonUIGridBackground", 'BACKGROUND')
    background:SetAllPoints(gridOverlay)
    background:SetTexture(0, 0, 0, 0.3)  -- Negro semi-transparente
    background:SetDrawLayer('BACKGROUND', -1)  -- Detrás de todo

    local lineThickness = 1

    -- === LÍNEAS VERTICALES SIMÉTRICAS ===
    for i = 0, totalHorizontalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridV"..i, 'BACKGROUND')
        
        -- La línea central es exactamente en halfCellsHorizontal
        if i == halfCellsHorizontal then
            line:SetTexture(1, 0, 0, 0.8)  -- Línea central roja EXACTA
        else
            line:SetTexture(1, 1, 1, 0.3)  -- Líneas blancas simétricas
        end
        
        local x = i * actualCellWidth
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", x - (lineThickness / 2), 0)
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'BOTTOMLEFT', x + (lineThickness / 2), 0)
    end

    -- === LÍNEAS HORIZONTALES SIMÉTRICAS ===
    for i = 0, totalVerticalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridH"..i, 'BACKGROUND')
        
        -- La línea central es exactamente en halfCellsVertical
        if i == halfCellsVertical then
            line:SetTexture(1, 0, 0, 0.8)  -- Línea central roja EXACTA
        else
            line:SetTexture(1, 1, 1, 0.3)  -- Líneas blancas simétricas
        end
        
        local y = i * actualCellHeight
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", 0, -y + (lineThickness / 2))
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'TOPRIGHT', 0, -y - (lineThickness / 2))
    end
    
    -- ✅ DEBUG: Mostrar información de simetría
    print("|cFFFFFF00[DragonUI Grid]|r Horizontal: " .. halfCellsHorizontal .. " celdas por lado (" .. totalHorizontalCells .. " total)")
    print("|cFFFFFF00[DragonUI Grid]|r Vertical: " .. halfCellsVertical .. " celdas por lado (" .. totalVerticalCells .. " total)")
    print("|cFFFFFF00[DragonUI Grid]|r Tamaño real: " .. string.format("%.1f", actualCellWidth) .. "x" .. string.format("%.1f", actualCellHeight))
    
    gridOverlay:Hide()
end

function EditorMode:Show()
    if InCombatLockdown() then
        print("Cannot open editor mode while in combat")
        return
    end

    createGridOverlay()
    createExitButton()
    gridOverlay:Show()
    exitEditorButton:Show()

    -- ✅ NUEVO: USAR SISTEMA CENTRALIZADO - UNA SOLA LÍNEA
    addon:ShowAllEditableFrames()
    
    print("|cFF00FF00[DragonUI]|r Editor mode activated")
end


function EditorMode:Hide()
    if gridOverlay then gridOverlay:Hide() end
    if exitEditorButton then exitEditorButton:Hide() end

    -- ✅ NUEVO: USAR SISTEMA CENTRALIZADO - UNA SOLA LÍNEA
    addon:HideAllEditableFrames(true) -- true = refresh and save positions
    
    print("|cFF00FF00[DragonUI]|r Editor mode deactivated")
end

function EditorMode:Toggle()
    if self:IsActive() then 
        self:Hide() 
    else 
        self:Show() 
    end
end

function EditorMode:IsActive()
    return gridOverlay and gridOverlay:IsShown()
end

-- ✅ COMANDO SLASH
SLASH_DRAGONUI_EDITOR1 = "/duiedit"
SlashCmdList["DRAGONUI_EDITOR"] = function()
    EditorMode:Toggle()
end