local addon = select(2, ...)

-- CASTBAR MODULE FOR DRAGONUI
-- Original code by Neticsoul
-- ============================================================================
-- CASTBAR MODULE - OPTIMIZED FOR WOW 3.3.5A
-- ============================================================================

local _G = _G
local pairs, ipairs = pairs, ipairs
local min, max, abs, floor, ceil = math.min, math.max, math.abs, math.floor, math.ceil
local format, gsub = string.format, string.gsub
local GetTime = GetTime
local UnitExists, UnitGUID = UnitExists, UnitGUID
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitAura, GetSpellTexture, GetSpellInfo = UnitAura, GetSpellTexture, GetSpellInfo

-- ============================================================================
-- MODULE CONSTANTS
-- ============================================================================

local TEXTURE_PATH = "Interface\\AddOns\\DragonUI\\Textures\\CastbarOriginal\\"
local TEXTURES = {
    atlas = TEXTURE_PATH .. "uicastingbar2x",
    atlasSmall = TEXTURE_PATH .. "uicastingbar",
    standard = TEXTURE_PATH .. "CastingBarStandard2",
    channel = TEXTURE_PATH .. "CastingBarChannel",
    interrupted = TEXTURE_PATH .. "CastingBarInterrupted2",
    spark = TEXTURE_PATH .. "CastingBarSpark"
}

local UV_COORDS = {
    background = {0.0009765625, 0.4130859375, 0.3671875, 0.41796875},
    border = {0.412109375, 0.828125, 0.001953125, 0.060546875},
    flash = {0.0009765625, 0.4169921875, 0.2421875, 0.30078125},
    spark = {0.076171875, 0.0859375, 0.796875, 0.9140625},
    borderShield = {0.000976562, 0.0742188, 0.796875, 0.970703},
    textBorder = {0.001953125, 0.412109375, 0.00390625, 0.11328125}
}

local CHANNEL_TICKS = {
    -- Warlock
    ["Drain Soul"] = 5, ["Drain Life"] = 5, ["Drain Mana"] = 5,
    ["Rain of Fire"] = 4, ["Hellfire"] = 15, ["Ritual of Summoning"] = 5,
    -- Priest
    ["Mind Flay"] = 3, ["Mind Control"] = 8, ["Penance"] = 2,
    -- Mage
    ["Blizzard"] = 8, ["Evocation"] = 4, ["Arcane Missiles"] = 5,
    -- Druid/Others
    ["Tranquility"] = 4, ["Hurricane"] = 10, ["First Aid"] = 8
}

local GRACE_PERIOD_AFTER_SUCCESS = 0.15
local REFRESH_THROTTLE = 0.1
local MAX_TICKS = 15
local AURA_UPDATE_INTERVAL = 0.05

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local CastbarModule = {
    states = {},
    frames = {},
    lastRefreshTime = {},
    auraCache = {
        target = {
            lastUpdate = 0,
            lastRows = 0,
            lastOffset = 0,
            lastGUID = nil
        }
    }
}

-- Initialize states for each castbar type
for _, unitType in ipairs({"player", "target", "focus"}) do
    CastbarModule.states[unitType] = {
        casting = false,
        isChanneling = false,
        currentValue = 0,
        maxValue = 0,
        spellName = "",
        holdTime = 0,
        castSucceeded = false,
        graceTime = 0,
        selfInterrupt = false,  --  Flag para interrupciones naturales
        unitGUID = nil,
        endTime = 0,
        startTime = 0,
        lastServerCheck = 0,
        delay = 0  -- Accumulated delay from knockbacks/pushbacks
    }
    CastbarModule.frames[unitType] = {}
    CastbarModule.lastRefreshTime[unitType] = 0
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig(unitType)
    local cfg = addon.db and addon.db.profile and addon.db.profile.castbar
    if not cfg then return nil end
    
    if unitType == "player" then
        return cfg
    end
    
    return cfg[unitType]
end

local function IsEnabled(unitType)
    local cfg = GetConfig(unitType)
    return cfg and cfg.enabled
end

local function GetSpellIcon(spellName, texture)
    if texture and texture ~= "" then
        return texture
    end
    
    if spellName then
        local icon = GetSpellTexture(spellName)
        if icon then return icon end
        
        -- Search in spellbook
        for i = 1, 1024 do
            local name, _, icon = GetSpellInfo(i, BOOKTYPE_SPELL)
            if not name then break end
            if name == spellName and icon then
                return icon
            end
        end
    end
    
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ParseCastTimes(startTime, endTime)
    local start = (startTime or 0) / 1000
    local finish = (endTime or 0) / 1000
    local duration = finish - start
    
    -- Sanity check for duration
    if duration > 3600 or duration < 0 then
        duration = 3.0
    end
    
    return start, finish, duration
end

-- ============================================================================
-- TEXTURE AND LAYER MANAGEMENT
-- ============================================================================

local function ForceStatusBarLayer(statusBar)
    if not statusBar then return end
    
    local texture = statusBar:GetStatusBarTexture()
    if texture and texture.SetDrawLayer then
        texture:SetDrawLayer('BORDER', 0)
    end
end

local function SetupVertexColor(statusBar)
    if not statusBar or not statusBar.SetStatusBarColor then return end
    
    if not statusBar._originalSetStatusBarColor then
        statusBar._originalSetStatusBarColor = statusBar.SetStatusBarColor
        statusBar.SetStatusBarColor = function(self, r, g, b, a)
            self:_originalSetStatusBarColor(r, g, b, a or 1)
            local texture = self:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(1, 1, 1, 1)
            end
        end
    end
end

local function CreateTextureClipping(statusBar)
    statusBar.UpdateTextureClipping = function(self, progress, isChanneling)
        local texture = self:GetStatusBarTexture()
        if not texture then return end
        
        texture:ClearAllPoints()
        texture:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, 0)
        texture:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0)
        
        ForceStatusBarLayer(self)
        
        local clampedProgress = max(0.001, min(1, progress))
        texture:SetTexCoord(0, clampedProgress, 0, 1)
    end
end

-- ============================================================================
-- BLIZZARD CASTBAR MANAGEMENT
-- ============================================================================

local function HideBlizzardCastbar(unitType)
    local frames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    }
    
    local frame = frames[unitType]
    if not frame then return end
    
    --  More aggressive hiding to prevent interference
    frame:Hide()
    frame:SetAlpha(0)
    
    if unitType == "target" then
        -- For target, we still want events but hide completely
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000)
        frame:SetSize(1, 1)  -- Minimize size
        
        --  Disable Blizzard's own show/hide logic
        if frame.SetScript then
            frame:SetScript("OnShow", function(self) 
                self:Hide() 
            end)
        end
    else
        if frame.SetScript then
            frame:SetScript("OnShow", function(self) 
                self:Hide() 
            end)
        end
    end
end

local function ShowBlizzardCastbar(unitType)
    local frames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    }
    
    local frame = frames[unitType]
    if not frame then return end
    
    frame:SetAlpha(1)
    if frame.SetScript then
        frame:SetScript("OnShow", nil)
    end
    
    if unitType == "target" then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 25, -5)
    end
end

-- ============================================================================
-- CHANNEL TICKS SYSTEM
-- ============================================================================

local function CreateChannelTicks(parent, ticksTable)
    for i = 1, MAX_TICKS do
        local tick = parent:CreateTexture('Tick' .. i, 'ARTWORK', nil, 1)
        tick:SetTexture('Interface\\ChatFrame\\ChatFrameBackground')
        tick:SetVertexColor(0, 0, 0, 0.75)
        tick:SetSize(3, max(parent:GetHeight() - 2, 10))
        tick:Hide()
        ticksTable[i] = tick
    end
end

local function UpdateChannelTicks(parent, ticksTable, spellName)
    -- Hide all ticks first
    for i = 1, MAX_TICKS do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end
    
    local tickCount = CHANNEL_TICKS[spellName]
    if not tickCount or tickCount <= 1 then return end
    
    local width = parent:GetWidth()
    local height = parent:GetHeight()
    local tickDelta = width / tickCount
    
    for i = 1, min(tickCount - 1, MAX_TICKS) do
        if ticksTable[i] then
            ticksTable[i]:SetSize(3, max(height - 2, 10))
            ticksTable[i]:ClearAllPoints()
            ticksTable[i]:SetPoint('CENTER', parent, 'LEFT', i * tickDelta, 0)
            ticksTable[i]:Show()
        end
    end
end

local function HideAllTicks(ticksTable)
    for i = 1, MAX_TICKS do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end
end

-- ============================================================================
-- SHIELD SYSTEM
-- ============================================================================

local function CreateShield(parent, icon, frameName, iconSize)
    if not parent or not icon then return nil end
    
    local shield = CreateFrame("Frame", frameName .. "Shield", parent)
    shield:SetFrameLevel(parent:GetFrameLevel() - 1)
    shield:SetSize(iconSize * 1.8, iconSize * 2.0)
    
    local texture = shield:CreateTexture(nil, "ARTWORK", nil, 3)
    texture:SetAllPoints(shield)
    texture:SetTexture(TEXTURES.atlas)
    texture:SetTexCoord(unpack(UV_COORDS.borderShield))
    texture:SetVertexColor(1, 1, 1, 1)
    
    shield:ClearAllPoints()
    shield:SetPoint("CENTER", icon, "CENTER", 0, -4)
    shield:Hide()
    
    return shield
end

-- ============================================================================
-- AURA OFFSET SYSTEM
-- ============================================================================

local function GetTargetAuraOffset()
    local cfg = GetConfig("target")
    if not cfg or not cfg.autoAdjust then return 0 end
    
    -- Simple approach: check if target has multiple aura rows
    if TargetFrame and TargetFrame.auraRows and TargetFrame.auraRows > 1 then
        local rows = TargetFrame.auraRows
        local offset = 0
        
        -- Sistema progresivo inverso: cada fila adicional empuja menos
        -- Fila 1: +24px, Fila 2: +18px, Fila 3: +14px, Fila 4: +12px, etc.
        for i = 2, rows do
            local rowOffset = math.max(4, 16 - (i * 2))  -- Decremento de 3px por fila, mínimo 8px
            offset = offset + rowOffset
        end
        
        return offset
    end
    
    return 0
end

local function ApplyTargetAuraOffset()
    local frames = CastbarModule.frames.target
    if not frames.castbar or not frames.castbar:IsVisible() then return end
    
    local cfg = GetConfig("target")
    if not cfg or not cfg.enabled or not cfg.autoAdjust then return end
    
    local offset = GetTargetAuraOffset()
    local anchorFrame = _G[cfg.anchorFrame] or TargetFrame or UIParent
    
    frames.castbar:ClearAllPoints()
    frames.castbar:SetPoint(cfg.anchor, anchorFrame, cfg.anchorParent, 
                           cfg.x_position, cfg.y_position - offset)
end

-- ============================================================================
-- TEXT MANAGEMENT
-- ============================================================================

local function SetTextMode(unitType, mode)
    local frames = CastbarModule.frames[unitType]
    if not frames then return end
    
    local elements = {
        frames.castText,
        frames.castTextCompact,
        frames.castTextCentered,
        frames.castTimeText,
        frames.castTimeTextCompact
    }
    
    -- Hide all text elements first
    for _, element in ipairs(elements) do
        if element then element:Hide() end
    end
    
    -- Show appropriate elements based on mode
    if mode == "simple" then
        if frames.castTextCentered then
            frames.castTextCentered:Show()
        end
    else
        local cfg = GetConfig(unitType)
        local isCompact = cfg and cfg.compactLayout
        
        if isCompact then
            if frames.castTextCompact then frames.castTextCompact:Show() end
            if frames.castTimeTextCompact then frames.castTimeTextCompact:Show() end
        else
            if frames.castText then frames.castText:Show() end
            if frames.castTimeText then frames.castTimeText:Show() end
        end
    end
end

local function SetCastText(unitType, text)
    local cfg = GetConfig(unitType)
    if not cfg then return end
    
    local textMode = cfg.text_mode or "simple"
    SetTextMode(unitType, textMode)
    
    local frames = CastbarModule.frames[unitType]
    if not frames then return end
    
    if textMode == "simple" then
        if frames.castTextCentered then
            frames.castTextCentered:SetText(text)
        end
    else
        if frames.castText then frames.castText:SetText(text) end
        if frames.castTextCompact then frames.castTextCompact:SetText(text) end
    end
end

local function UpdateTimeText(unitType)
    local frames = CastbarModule.frames[unitType]
    local state = CastbarModule.states[unitType]
    
    if unitType == "player" then
        if not frames.timeValue and not frames.timeMax then return end
    else
        if not frames.castTimeText and not frames.castTimeTextCompact then return end
    end
    
    local cfg = GetConfig(unitType)
    if not cfg then return end
    
    local seconds = 0
    local secondsMax = state.maxValue or 0
    
    if state.casting or state.isChanneling then
        if state.casting and not state.isChanneling then
            seconds = max(0, state.maxValue - state.currentValue)
        else
            seconds = max(0, state.currentValue)
        end
    end
    
    local timeText = format('%.' .. (cfg.precision_time or 1) .. 'f', seconds)
    local fullText
    
    if cfg.precision_max and cfg.precision_max > 0 then
        local maxText = format('%.' .. cfg.precision_max .. 'f', secondsMax)
        fullText = timeText .. ' / ' .. maxText
    else
        fullText = timeText .. 's'
    end
    
    if unitType == "player" then
        local textMode = cfg.text_mode or "simple"
        if textMode ~= "simple" and frames.timeValue and frames.timeMax then
            frames.timeValue:SetText(timeText)
            frames.timeMax:SetText(' / ' .. format('%.' .. (cfg.precision_max or 1) .. 'f', secondsMax))
        end
    else
        if frames.castTimeText then frames.castTimeText:SetText(fullText) end
        if frames.castTimeTextCompact then frames.castTimeTextCompact:SetText(fullText) end
    end
end

-- ============================================================================
-- CASTBAR CREATION
-- ============================================================================

local function CreateTextElements(parent, unitType)
    local fontSize = unitType == "player" and 'GameFontHighlight' or 'GameFontHighlightSmall'
    local elements = {}
    
    -- Main cast text
    elements.castText = parent:CreateFontString(nil, 'OVERLAY', fontSize)
    elements.castText:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', unitType == "player" and 8 or 6, 2)
    elements.castText:SetJustifyH("LEFT")
    
    -- Compact cast text
    elements.castTextCompact = parent:CreateFontString(nil, 'OVERLAY', fontSize)
    elements.castTextCompact:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', unitType == "player" and 8 or 6, 2)
    elements.castTextCompact:SetJustifyH("LEFT")
    elements.castTextCompact:Hide()
    
    -- Centered text for simple mode
    elements.castTextCentered = parent:CreateFontString(nil, 'OVERLAY', fontSize)
    elements.castTextCentered:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 1)
    elements.castTextCentered:SetPoint('LEFT', parent, 'LEFT', unitType == "player" and 8 or 6, 0)
    elements.castTextCentered:SetPoint('RIGHT', parent, 'RIGHT', unitType == "player" and -8 or -6, 0)
    elements.castTextCentered:SetJustifyH("CENTER")
    elements.castTextCentered:Hide()
    
    -- Time text
    elements.castTimeText = parent:CreateFontString(nil, 'OVERLAY', fontSize)
    elements.castTimeText:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', unitType == "player" and -8 or -6, 2)
    elements.castTimeText:SetJustifyH("RIGHT")
    
    -- Compact time text
    elements.castTimeTextCompact = parent:CreateFontString(nil, 'OVERLAY', fontSize)
    elements.castTimeTextCompact:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', unitType == "player" and -8 or -6, 2)
    elements.castTimeTextCompact:SetJustifyH("RIGHT")
    elements.castTimeTextCompact:Hide()
    
    -- Player-specific time elements
    if unitType == "player" then
        elements.timeValue = parent:CreateFontString(nil, 'OVERLAY', fontSize)
        elements.timeValue:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', -50, 2)
        elements.timeValue:SetJustifyH("RIGHT")
        
        elements.timeMax = parent:CreateFontString(nil, 'OVERLAY', fontSize)
        elements.timeMax:SetPoint('LEFT', elements.timeValue, 'RIGHT', 2, 0)
        elements.timeMax:SetJustifyH("LEFT")
    end
    
    return elements
end

local function CreateCastbar(unitType)
    if CastbarModule.frames[unitType].castbar then return end
    
    local frameName = 'DragonUI' .. unitType:sub(1,1):upper() .. unitType:sub(2) .. 'Castbar'
    local frames = CastbarModule.frames[unitType]
    
    -- Main StatusBar
    frames.castbar = CreateFrame('StatusBar', frameName, UIParent)
    frames.castbar:SetFrameStrata("MEDIUM")
    frames.castbar:SetFrameLevel(10)
    frames.castbar:SetMinMaxValues(0, 1)
    frames.castbar:SetValue(0)
    frames.castbar:Hide()
    
    -- Background
    local bg = frames.castbar:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(TEXTURES.atlas)
    bg:SetTexCoord(unpack(UV_COORDS.background))
    bg:SetAllPoints()
    
    -- StatusBar texture
    frames.castbar:SetStatusBarTexture(TEXTURES.standard)
    frames.castbar:SetStatusBarColor(1, 0.7, 0, 1)
    ForceStatusBarLayer(frames.castbar)
    
    -- Border
    local border = frames.castbar:CreateTexture(nil, 'ARTWORK', nil, 0)
    border:SetTexture(TEXTURES.atlas)
    border:SetTexCoord(unpack(UV_COORDS.border))
    border:SetPoint("TOPLEFT", frames.castbar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", frames.castbar, "BOTTOMRIGHT", 2, -2)
    
    -- Channel ticks
    frames.ticks = {}
    CreateChannelTicks(frames.castbar, frames.ticks)
    
    -- Flash
    frames.flash = frames.castbar:CreateTexture(nil, 'OVERLAY')
    frames.flash:SetTexture(TEXTURES.atlas)
    frames.flash:SetTexCoord(unpack(UV_COORDS.flash))
    frames.flash:SetBlendMode('ADD')
    frames.flash:SetAllPoints()
    frames.flash:Hide()
    
    -- Icon
    frames.icon = frames.castbar:CreateTexture(frameName .. "Icon", 'ARTWORK')
    frames.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frames.icon:Hide()
    
    -- Icon border
    local iconBorder = frames.castbar:CreateTexture(nil, 'ARTWORK')
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    iconBorder:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    iconBorder:SetVertexColor(0.8, 0.8, 0.8, 1)
    iconBorder:Hide()
    frames.icon.Border = iconBorder
    
    -- Shield (for target/focus)
    if unitType ~= "player" then
        frames.shield = CreateShield(frames.castbar, frames.icon, frameName, 20)
    end
    
    -- Apply systems
    SetupVertexColor(frames.castbar)
    CreateTextureClipping(frames.castbar)
    
    -- Text background frame
    frames.textBackground = CreateFrame('Frame', frameName .. 'TextBG', UIParent)
    frames.textBackground:SetFrameStrata("MEDIUM")
    frames.textBackground:SetFrameLevel(9)
    frames.textBackground:Hide()
    
    local textBg = frames.textBackground:CreateTexture(nil, 'BACKGROUND')
    if unitType == "player" then
        textBg:SetTexture(TEXTURES.atlas)
        textBg:SetTexCoord(0.001953125, 0.410109375, 0.00390625, 0.11328125)
    else
        textBg:SetTexture(TEXTURES.atlasSmall)
        textBg:SetTexCoord(unpack(UV_COORDS.textBorder))
    end
    textBg:SetAllPoints()
    
    -- Create text elements
    local textElements = CreateTextElements(frames.textBackground, unitType)
    for key, element in pairs(textElements) do
        frames[key] = element
    end
    
    -- Background frame
    if unitType ~= "player" then
        frames.background = CreateFrame('Frame', frameName .. 'Background', frames.castbar)
        frames.background:SetFrameLevel(frames.castbar:GetFrameLevel() - 1)
        frames.background:SetAllPoints(frames.castbar)
    else
        frames.background = frames.textBackground
    end
    
    -- OnUpdate handler
    frames.castbar:SetScript('OnUpdate', function(self, elapsed)
        CastbarModule:OnUpdate(unitType, self, elapsed)
    end)
end
-- ============================================================================
-- VISUAL UPDATES CONSOLIDATION (Anti-Flicker Solution)
-- ============================================================================

local function UpdateCastbarVisuals(unitType, progress)
    local frames = CastbarModule.frames[unitType]
    local state = CastbarModule.states[unitType]
    
    if not frames or not frames.castbar then return end
    
    -- Una sola actualización de textura para evitar conflictos
    if frames.castbar.UpdateTextureClipping then
        frames.castbar:UpdateTextureClipping(progress, state.isChanneling)
    end
    
    -- Una sola actualización de spark para evitar múltiples reposicionamientos
    if frames.spark and frames.spark:IsShown() then
        local actualWidth = frames.castbar:GetWidth() * progress
        frames.spark:ClearAllPoints()
        frames.spark:SetPoint('CENTER', frames.castbar, 'LEFT', actualWidth, 0)
    end
end
-- ============================================================================
-- CASTING EVENT HANDLERS
-- ============================================================================

function CastbarModule:HandleCastStart(unitType, unit)
    local name, _, _, iconTex, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    if not name then return end
    
    self:RefreshCastbar(unitType)
    
    local state = self.states[unitType]
    local frames = self.frames[unitType]
    
    --  Guardar GUID y tiempos del servidor
    if unitType ~= "player" then
        state.unitGUID = UnitGUID(unit)
    end
    
    state.casting = true
    state.isChanneling = false
    state.holdTime = 0
    state.spellName = name
    state.selfInterrupt = false
    state.delay = 0  -- Reset delay on new cast
    
    if unitType == "player" then
        state.castSucceeded = false
        state.graceTime = 0
    end
    
    local start, finish, duration = ParseCastTimes(startTime, endTime)
    state.maxValue = duration
    
    --  Guardar tiempos del servidor para validación (PARA TODOS)
    state.startTime = start
    state.endTime = finish
    state.lastServerCheck = GetTime()
    
    --  FIX: Calcular progreso actual basado en tiempo transcurrido
    local currentTime = GetTime()
    local elapsed = currentTime - start
    state.currentValue = max(0, min(elapsed, duration))
    
    frames.castbar:SetMinMaxValues(0, state.maxValue)
    frames.castbar:SetValue(state.currentValue)  --  Usar progreso calculado
    frames.castbar:Show()
    
    if frames.background and frames.background ~= frames.textBackground then
        frames.background:Show()
    end
    
    if frames.spark then frames.spark:Show() end
    if frames.flash then frames.flash:Hide() end
    
    HideAllTicks(frames.ticks)
    
    frames.castbar:SetStatusBarTexture(TEXTURES.standard)
    frames.castbar:SetStatusBarColor(1, 0.7, 0, 1)
    ForceStatusBarLayer(frames.castbar)
    
    --  FIX: Actualizar clipping con progreso real usando función consolidada
    local progress = state.currentValue / state.maxValue
    UpdateCastbarVisuals(unitType, progress)
    
    SetCastText(unitType, name)
    
    local cfg = GetConfig(unitType)
    if frames.icon and cfg and cfg.showIcon then
        frames.icon:SetTexture(GetSpellIcon(name, iconTex))
        frames.icon:Show()
        if frames.icon.Border then frames.icon.Border:Show() end
    else
        if frames.icon then frames.icon:Hide() end
        if frames.icon and frames.icon.Border then frames.icon.Border:Hide() end
    end
    
    if frames.textBackground then
        frames.textBackground:Show()
        frames.textBackground:ClearAllPoints()
        frames.textBackground:SetSize(frames.castbar:GetWidth(), unitType == "player" and 22 or 20)
        frames.textBackground:SetPoint("TOP", frames.castbar, "BOTTOM", 0, unitType == "player" and 6 or 8)
    end
    
    UpdateTimeText(unitType)
    
    --  FIX: Actualizar posición del spark con progreso real
    if frames.spark and frames.spark:IsShown() then
        local progress = state.currentValue / state.maxValue
        local actualWidth = frames.castbar:GetWidth() * progress
        frames.spark:ClearAllPoints()
        frames.spark:SetPoint('CENTER', frames.castbar, 'LEFT', actualWidth, 0)
    end
    
    if unitType ~= "player" and frames.shield and cfg and cfg.showIcon then
        if notInterruptible and not isTradeSkill then
            frames.shield:Show()
        else
            frames.shield:Hide()
        end
    end
end

function CastbarModule:HandleChannelStart(unitType, unit)
    local name, _, _, iconTex, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(unit)
    if not name then return end
    
    self:RefreshCastbar(unitType)
    
    local state = self.states[unitType]
    local frames = self.frames[unitType]
    
    -- Guardar GUID y tiempos del servidor
    if unitType ~= "player" then
        state.unitGUID = UnitGUID(unit)
    end
    
    state.casting = true
    state.isChanneling = true
    state.holdTime = 0
    state.spellName = name
    state.selfInterrupt = false
    state.delay = 0  -- Reset delay on new channel
    
    if unitType == "player" then
        state.castSucceeded = false
        state.graceTime = 0
    end
    
    local start, finish, duration = ParseCastTimes(startTime, endTime)
    state.maxValue = duration
    
    --  Guardar tiempos del servidor para validación (PARA TODOS)
    state.startTime = start
    state.endTime = finish
    state.lastServerCheck = GetTime()
    
    --  FIX: Calcular progreso actual para channels (restante)
    local currentTime = GetTime()
    local elapsed = currentTime - start
    state.currentValue = max(0, duration - elapsed)  -- Channels van hacia abajo
    
    frames.castbar:SetMinMaxValues(0, state.maxValue)
    frames.castbar:SetValue(state.currentValue)  --  Usar progreso calculado
    frames.castbar:Show()
    
    if frames.background and frames.background ~= frames.textBackground then
        frames.background:Show()
    end
    
    if frames.spark then frames.spark:Show() end
    if frames.flash then frames.flash:Hide() end
    
    frames.castbar:SetStatusBarTexture(TEXTURES.channel)
    ForceStatusBarLayer(frames.castbar)
    
    if unitType == "player" then
        frames.castbar:SetStatusBarColor(0, 1, 0, 1)
    else
        frames.castbar:SetStatusBarColor(1, 1, 1, 1)
    end
    
    --  FIX: Actualizar clipping con progreso real usando función consolidada
    local progress = state.currentValue / state.maxValue
    UpdateCastbarVisuals(unitType, progress)
    
    SetCastText(unitType, name)
    
    local cfg = GetConfig(unitType)
    if frames.icon and cfg and cfg.showIcon then
        frames.icon:SetTexture(GetSpellIcon(name, iconTex))
        frames.icon:Show()
        if frames.icon.Border then frames.icon.Border:Show() end
    else
        if frames.icon then frames.icon:Hide() end
        if frames.icon and frames.icon.Border then frames.icon.Border:Hide() end
    end
    
    if frames.textBackground then
        frames.textBackground:Show()
        frames.textBackground:ClearAllPoints()
        frames.textBackground:SetSize(frames.castbar:GetWidth(), unitType == "player" and 22 or 20)
        frames.textBackground:SetPoint("TOP", frames.castbar, "BOTTOM", 0, unitType == "player" and 6 or 8)
    end
    
    UpdateTimeText(unitType)
    UpdateChannelTicks(frames.castbar, frames.ticks, name)
    
    --  FIX: Actualizar posición del spark con progreso real para channels
    if frames.spark and frames.spark:IsShown() then
        local progress = state.currentValue / state.maxValue
        local actualWidth = frames.castbar:GetWidth() * progress
        frames.spark:ClearAllPoints()
        frames.spark:SetPoint('CENTER', frames.castbar, 'LEFT', actualWidth, 0)
    end
    
    if unitType ~= "player" and frames.shield and cfg and cfg.showIcon then
        if notInterruptible and not isTradeSkill then
            frames.shield:Show()
        else
            frames.shield:Hide()
        end
    end
end

function CastbarModule:HandleCastStop(unitType, isInterrupted)
    local state = self.states[unitType]
    local frames = self.frames[unitType]
    
    if not state.casting and not state.isChanneling then return end
    
    local cfg = GetConfig(unitType)
    if not cfg then return end
    
    --  MEJORADO: Lógica más robusta
    if isInterrupted and not state.selfInterrupt then
        -- Verdadera interrupción
        if frames.shield then frames.shield:Hide() end
        HideAllTicks(frames.ticks)
        
        frames.castbar:SetStatusBarTexture(TEXTURES.interrupted)
        frames.castbar:SetStatusBarColor(1, 0, 0, 1)
        ForceStatusBarLayer(frames.castbar)
        frames.castbar:SetValue(state.maxValue)
        
        if frames.castbar.UpdateTextureClipping then
            frames.castbar:UpdateTextureClipping(1, false)
        end
        
        SetCastText(unitType, "Interrupted")
        
        state.casting = false
        state.isChanneling = false
        state.holdTime = cfg.holdTimeInterrupt or 0.8
    else
        -- Completado naturalmente O selfInterrupt=true
        if unitType == "player" then
            state.castSucceeded = true
        else
            self:FinishSpell(unitType)
        end
    end
    
    --  NUEVO: Reset flag al final (siempre)
    state.selfInterrupt = false
end

function CastbarModule:FinishSpell(unitType)
    local frames = self.frames[unitType]
    local state = self.states[unitType]
    local cfg = GetConfig(unitType)
    
    if state.maxValue then
        frames.castbar:SetValue(state.maxValue)
        state.currentValue = state.maxValue
        
        if frames.castbar.UpdateTextureClipping then
            frames.castbar:UpdateTextureClipping(1, state.isChanneling)
        end
        
        UpdateTimeText(unitType)
    end
    
    if frames.spark then frames.spark:Hide() end
    if frames.shield then frames.shield:Hide() end
    if frames.flash then frames.flash:Show() end
    
    HideAllTicks(frames.ticks)
    
    state.casting = false
    state.isChanneling = false
    state.holdTime = cfg and cfg.holdTime or 0.3
end



-- ============================================================================
-- UPDATE HANDLER
-- ============================================================================

function CastbarModule:OnUpdate(unitType, castbar, elapsed)
    local state = self.states[unitType]
    local frames = self.frames[unitType]
    local cfg = GetConfig(unitType)
    
    if not cfg or not cfg.enabled then return end
    
    -- Para PLAYER, verificar si cast se interrumpió por pérdida de target o eventos de UI
    if unitType == "player" and (state.casting or state.isChanneling) then
        -- Verificación adicional: si player está casteando pero el servidor dice que no
        local now = GetTime()
        if (now - state.lastServerCheck) > 0.3 then  -- Reducido: cada 300ms para evitar micro-interrupciones
            state.lastServerCheck = now
            
            local serverName, serverTexture, serverStartTime, serverEndTime
            if state.casting and not state.isChanneling then
                serverName, _, _, serverTexture, serverStartTime, serverEndTime = UnitCastingInfo("player")
            elseif state.isChanneling then
                serverName, _, _, serverTexture, serverStartTime, serverEndTime = UnitChannelInfo("player")
            end
            
            -- Si no hay cast en servidor, el cast se interrumpió (target fuera de rango, mapa abierto, etc.)
            if not serverName then
                self:HideCastbar(unitType)
                return
            end
            
            -- NUEVO: Verificar si los tiempos del servidor cambiaron (pausa por mapa/UI)
            if serverName == state.spellName and serverStartTime and serverEndTime then
                local serverStart = serverStartTime / 1000
                local serverEnd = serverEndTime / 1000
                local serverDuration = serverEnd - serverStart
                
                -- Si la duración cambió significativamente, recalcular
                if math.abs(serverDuration - state.maxValue) > 0.1 then
                    state.maxValue = serverDuration
                    state.startTime = serverStart
                    state.endTime = serverEnd
                    
                    -- Recalcular progreso actual desde el servidor
                    if state.casting and not state.isChanneling then
                        local elapsed = now - serverStart
                        state.currentValue = max(0, min(elapsed, serverDuration))
                    else
                        local remaining = serverEnd - now
                        state.currentValue = max(0, min(remaining, serverDuration))
                    end
                    
                    frames.castbar:SetMinMaxValues(0, state.maxValue)
                    frames.castbar:SetValue(state.currentValue)
                end
            end
        end
    end

    -- Validación robusta para target/focus
    if unitType ~= "player" then
        if not UnitExists(unitType) then
            if state.casting or state.isChanneling then
                self:HideCastbar(unitType)
            end
            return
        end
        
        --  Verificar GUID mismatch (target switching)
        local currentGUID = UnitGUID(unitType)
        if state.unitGUID and state.unitGUID ~= currentGUID then
            if state.casting or state.isChanneling then
                self:HideCastbar(unitType)
            end
            return
        end
        
        --  Verificar si cast expiró por tiempo
        if (state.casting or state.isChanneling) and state.endTime > 0 then
            local now = GetTime()
            if now > state.endTime then
                self:HideCastbar(unitType)
                return
            end
        end
        
        --  Verificación periódica del servidor (throttled)
        if state.casting or state.isChanneling then
            local now = GetTime()
            if (now - state.lastServerCheck) > 0.2 then  -- Cada 200ms
                state.lastServerCheck = now
                
                local serverName
                if state.casting and not state.isChanneling then
                    serverName = UnitCastingInfo(unitType)
                elseif state.isChanneling then
                    serverName = UnitChannelInfo(unitType)
                end
                
                -- Si no hay cast en servidor, ocultar (target fuera de rango, etc.)
                if not serverName then
                    self:HideCastbar(unitType)
                    return
                end
            end
        end
    end
    
    -- Handle success grace period (player only)
    if unitType == "player" and state.castSucceeded and (state.casting or state.isChanneling) then
        state.currentValue = state.isChanneling and 0 or state.maxValue
        castbar:SetValue(state.maxValue)
        
        if castbar.UpdateTextureClipping then
            castbar:UpdateTextureClipping(1, state.isChanneling)
        end
        
        UpdateTimeText(unitType)
        
        if frames.spark and frames.spark:IsShown() then
            frames.spark:SetPoint('CENTER', castbar, 'LEFT', castbar:GetWidth(), 0)
        end
        
        state.graceTime = state.graceTime + elapsed
        if state.graceTime >= GRACE_PERIOD_AFTER_SUCCESS then
            self:FinishSpell(unitType)
            state.castSucceeded = false
            state.graceTime = 0
        end
        return
    end
    
    -- Handle hold time
    if state.holdTime > 0 then
        state.holdTime = state.holdTime - elapsed
        if state.holdTime <= 0 then
            self:HideCastbar(unitType)
        end
        return
    end
    
    -- Update casting/channeling
    if state.casting or state.isChanneling then
        -- MEJORADO: Calcular progreso basado en tiempo del servidor para mayor precisión
        local now = GetTime()
        local shouldUpdateFromTime = false
        
        -- Para player, usar tiempo del servidor cuando sea posible
        if unitType == "player" and state.startTime > 0 and state.endTime > 0 then
            if state.casting and not state.isChanneling then
                local elapsed = now - state.startTime
                local serverProgress = max(0, min(elapsed, state.maxValue))
                -- Solo actualizar si la diferencia es significativa (evita micro-actualizaciones)
                if math.abs(serverProgress - state.currentValue) > 0.01 then
                    state.currentValue = serverProgress
                    shouldUpdateFromTime = true
                end
            elseif state.isChanneling then
                local remaining = state.endTime - now
                local serverProgress = max(0, min(remaining, state.maxValue))
                if math.abs(serverProgress - state.currentValue) > 0.01 then
                    state.currentValue = serverProgress
                    shouldUpdateFromTime = true
                end
            end
        end
        
        -- Fallback: actualización incremental normal si no hay datos del servidor
        if not shouldUpdateFromTime then
            if state.casting and not state.isChanneling then
                state.currentValue = min(state.currentValue + elapsed, state.maxValue)
            elseif state.isChanneling then
                state.currentValue = max(state.currentValue - elapsed, 0)
            end
        end
        
        castbar:SetValue(state.currentValue)
        
        local progress = state.maxValue > 0 and (state.currentValue / state.maxValue) or 0
        
        -- Usar función consolidada para evitar parpadeo por múltiples actualizaciones
        UpdateCastbarVisuals(unitType, progress)
        
        UpdateTimeText(unitType)
        
        if frames.flash then
            frames.flash:Hide()
        end
    end
end

-- ============================================================================
-- CASTBAR REFRESH
-- ============================================================================

function CastbarModule:RefreshCastbar(unitType)
    -- Throttling eliminado para actualizaciones suaves sin saltos visuales
    -- local currentTime = GetTime()
    -- local timeSinceLastRefresh = currentTime - (self.lastRefreshTime[unitType] or 0)
    -- if timeSinceLastRefresh < REFRESH_THROTTLE and self.lastRefreshTime[unitType] > 0 then
    --     return
    -- end
    -- self.lastRefreshTime[unitType] = currentTime
    
    local cfg = GetConfig(unitType)
    if not cfg then return end
    
    if cfg.enabled then
        HideBlizzardCastbar(unitType)
    else
        ShowBlizzardCastbar(unitType)
        self:HideCastbar(unitType)
        return
    end
    
    if not self.frames[unitType].castbar then
        CreateCastbar(unitType)
    end
    
    local frames = self.frames[unitType]
    local frameName = 'DragonUI' .. unitType:sub(1,1):upper() .. unitType:sub(2) .. 'Castbar'
    
    -- Calculate aura offset for target
    local auraOffset = 0
    if unitType == "target" and cfg.autoAdjust then
        auraOffset = GetTargetAuraOffset()
    end
    
    -- Position and size castbar
    frames.castbar:ClearAllPoints()
    local anchorFrame = UIParent
    local anchorPoint = "CENTER"
    local relativePoint = "BOTTOM"
    local xPos = cfg.x_position or 0
    local yPos = cfg.y_position or 200
    
    if unitType == "player" then
        --  USAR ANCHOR FRAME PARA PLAYER CASTBAR (SISTEMA CENTRALIZADO)
        if self.anchor then
            anchorFrame = self.anchor
            anchorPoint = "CENTER"
            relativePoint = "CENTER"
            xPos = 0  -- Relativo al anchor, no offset adicional
            yPos = 0
        else
            -- Fallback si no hay anchor (modo legacy)
            anchorFrame = UIParent
            anchorPoint = "BOTTOM"
            relativePoint = "BOTTOM"
        end
    elseif unitType ~= "player" then
        anchorFrame = _G[cfg.anchorFrame] or (unitType == "target" and TargetFrame or FocusFrame) or UIParent
        anchorPoint = cfg.anchor or "CENTER"
        relativePoint = cfg.anchorParent or "BOTTOM"
    end
    
    frames.castbar:SetPoint(anchorPoint, anchorFrame, relativePoint, xPos, yPos - auraOffset)
    frames.castbar:SetSize(cfg.sizeX or 200, cfg.sizeY or 16)
    frames.castbar:SetScale(cfg.scale or 1)
    
    -- Create spark if needed
    if not frames.spark then
        frames.spark = CreateFrame("Frame", frameName .. "Spark", UIParent)
        frames.spark:SetFrameStrata("MEDIUM")
        frames.spark:SetFrameLevel(11)
        frames.spark:SetSize(16, 16)
        frames.spark:Hide()
        
        local sparkTexture = frames.spark:CreateTexture(nil, 'ARTWORK')
        sparkTexture:SetTexture(TEXTURES.spark)
        sparkTexture:SetAllPoints()
        sparkTexture:SetBlendMode('ADD')
    end
    
    -- Position text background
    if frames.textBackground then
        frames.textBackground:ClearAllPoints()
        frames.textBackground:SetPoint('TOP', frames.castbar, 'BOTTOM', 0, unitType == "player" and 6 or 8)
        frames.textBackground:SetSize(cfg.sizeX or 200, unitType == "player" and 22 or 20)
        frames.textBackground:SetScale(cfg.scale or 1)
    end
    
    -- Configure icon
    if frames.icon then
        local iconSize = cfg.sizeIcon or 20
        frames.icon:SetSize(iconSize, iconSize)
        frames.icon:ClearAllPoints()
        
        if unitType == "player" then
            frames.icon:SetPoint('TOPLEFT', frames.castbar, 'TOPLEFT', -(iconSize + 6), -1)
        else
            local iconScale = iconSize / 16
            frames.icon:SetPoint('RIGHT', frames.castbar, 'LEFT', -7 * iconScale, -4)
        end
        
        if frames.icon.Border then
            frames.icon.Border:ClearAllPoints()
            frames.icon.Border:SetPoint('CENTER', frames.icon, 'CENTER', 0, 0)
            frames.icon.Border:SetSize(iconSize * 1.7, iconSize * 1.7)
        end
        
        if frames.shield then
            if unitType == "player" then
                frames.shield:ClearAllPoints()
                frames.shield:SetPoint('CENTER', frames.icon, 'CENTER', 0, 0)
                frames.shield:SetSize(iconSize * 0.8, iconSize * 0.8)
            else
                frames.shield:SetSize(iconSize * 1.8, iconSize * 2.0)
            end
        end
    end
    
    -- Update spark size
    if frames.spark then
        local sparkSize = cfg.sizeY or 16
        frames.spark:SetSize(sparkSize, sparkSize * 2)
    end
    
    -- Update tick sizes
    if frames.ticks then
        for i = 1, MAX_TICKS do
            if frames.ticks[i] then
                frames.ticks[i]:SetSize(3, (cfg.sizeY or 16) - 2)
            end
        end
    end
    
    -- Set compact layout for target/focus
    if unitType ~= "player" then
        SetTextMode(unitType, cfg.text_mode or "simple")
    end
    
    -- Ensure proper frame levels
    frames.castbar:SetFrameLevel(10)
    if frames.background then frames.background:SetFrameLevel(9) end
    if frames.textBackground then frames.textBackground:SetFrameLevel(9) end
    
    HideBlizzardCastbar(unitType)
    SetupVertexColor(frames.castbar)
    
    if cfg.text_mode then
        SetTextMode(unitType, cfg.text_mode)
    end
end

function CastbarModule:HideCastbar(unitType)
    local frames = self.frames[unitType]
    local state = self.states[unitType]
    
    if frames.castbar then frames.castbar:Hide() end
    if frames.background then frames.background:Hide() end
    if frames.textBackground then frames.textBackground:Hide() end
    if frames.flash then frames.flash:Hide() end
    if frames.spark then frames.spark:Hide() end
    if frames.shield then frames.shield:Hide() end
    if frames.icon then frames.icon:Hide() end
    
    --  Limpiar completamente el estado
    state.casting = false
    state.isChanneling = false
    state.holdTime = 0
    state.maxValue = 0
    state.currentValue = 0
    state.selfInterrupt = false
    state.endTime = 0
    state.startTime = 0
    state.lastServerCheck = 0
    state.spellName = ""
    state.delay = 0  -- Reset delay
    
    if unitType == "player" then
        state.castSucceeded = false
        state.graceTime = 0
    else
        --  Para target/focus, limpiar GUID solo si no hay unidad
        if not UnitExists(unitType) then
            state.unitGUID = nil
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function CastbarModule:HandleCastingEvent(event, unit)
    local unitType
    if unit == "player" then
        unitType = "player"
    elseif unit == "target" then
        unitType = "target"
    elseif unit == "focus" then
        unitType = "focus"
    else
        return
    end
    
    if not IsEnabled(unitType) then 
        return 
    end
    
    -- ANTI-EVENTOS-CRUZADOS: Prevenir que target/focus procesen eventos del player
    if unitType ~= "player" then
        local playerGUID = UnitGUID("player")
        local unitGUID = UnitGUID(unit)
        
        -- Si target/focus son el mismo player, solo permitir eventos START para mostrar la barra
        -- Eventos STOP/FAILED serán manejados solo por player castbar
        if playerGUID and unitGUID and playerGUID == unitGUID then
            if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or 
               event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
                -- Ignorar eventos de finalización cuando target/focus = player
                return
            end
        end
    end
    
    HideBlizzardCastbar(unitType)
    
    --  Verificar GUID para todos los eventos (excepto player)
    if unitType ~= "player" then
        local state = self.states[unitType]
        local currentGUID = UnitGUID(unit)
        
        -- Si tenemos un cast activo pero el GUID cambió, ignorar el evento
        if (state.casting or state.isChanneling) and state.unitGUID and state.unitGUID ~= currentGUID then
            return
        end
        
        -- Actualizar GUID para futuras verificaciones
        if currentGUID then
            state.unitGUID = currentGUID
        end
    end
    
    if event == 'UNIT_SPELLCAST_START' then
        self:HandleCastStart(unitType, unit)
    elseif event == 'UNIT_SPELLCAST_SUCCEEDED' and unitType == "player" then
        local state = self.states[unitType]
        if state.casting or state.isChanneling then
            state.castSucceeded = true
        end
    elseif event == 'UNIT_SPELLCAST_CHANNEL_START' then
        self:HandleChannelStart(unitType, unit)
    elseif event == 'UNIT_SPELLCAST_STOP' or event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
        --   Verificar que el evento corresponde al cast actual
        local state = self.states[unitType]
        
        --  Verificar GUID para evitar eventos de units incorrectos
        if unitType ~= "player" then
            local currentGUID = UnitGUID(unit)
            if not currentGUID or state.unitGUID ~= currentGUID then
                return
            end
        end
        
        -- Para channels, marcar como terminado naturalmente
        if event == 'UNIT_SPELLCAST_CHANNEL_STOP' and state.isChanneling then
            state.selfInterrupt = true
        end
        
        self:HandleCastStop(unitType, false)  -- Siempre completado naturalmente
    elseif event == 'UNIT_SPELLCAST_FAILED' then
        --  NUEVO: Manejo de fallos 
        local state = self.states[unitType]
        if unitType == "player" then
            state.castSucceeded = false
        else
            self:FinishSpell(unitType)
        end
    elseif event == 'UNIT_SPELLCAST_INTERRUPTED' then
        self:HandleCastStop(unitType, true)
        -- NUEVO: Manejo de delays/pushbacks
    elseif event == 'UNIT_SPELLCAST_DELAYED' or event == 'UNIT_SPELLCAST_CHANNEL_UPDATE' then
        self:HandleCastDelayed(unitType, unit)
    end  -- Verdadera interrupción   
    
    -- NOTA: La protección anti-eventos-cruzados previene que target/focus procesen
    -- eventos STOP/FAILED cuando son el mismo player, evitando desapariciones erróneas
end

function CastbarModule:HandleTargetChanged()
    local state = self.states.target
    
    --  Guardar GUID anterior para comparación
    local oldGUID = state.unitGUID
    local newGUID = UnitExists("target") and UnitGUID("target") or nil
    
    --  Si cambió target, SIEMPRE ocultar inmediatamente
    if oldGUID ~= newGUID then
        self:HideCastbar("target")
        state.unitGUID = newGUID
    end
    
    HideBlizzardCastbar("target")
    
    -- Sistema de caché simplificado - eliminadas referencias complejas
    -- self.auraCache.target.lastUpdate = 0
    -- self.auraCache.target.lastGUID = newGUID
    
    --  Solo proceder si hay target válido
    if UnitExists("target") and IsEnabled("target") then
        --  Verificar que target no cambió durante el delay
        addon.core:ScheduleTimer(function()
            -- Double-check: asegurar que el target sigue siendo el mismo
            if UnitGUID("target") == newGUID then
                if UnitCastingInfo("target") then
                    state.unitGUID = newGUID  -- Establecer GUID antes del evento
                    self:HandleCastingEvent('UNIT_SPELLCAST_START', "target")
                elseif UnitChannelInfo("target") then
                    state.unitGUID = newGUID  -- Establecer GUID antes del evento
                    self:HandleCastingEvent('UNIT_SPELLCAST_CHANNEL_START', "target")
                end
                ApplyTargetAuraOffset()
            end
        end, 0.05)
    else
        --  Asegurar limpieza si no hay target
        state.unitGUID = nil
    end
end

function CastbarModule:HandleFocusChanged()
    local state = self.states.focus
    
    --  Guardar GUID anterior para comparación
    local oldGUID = state.unitGUID
    local newGUID = UnitExists("focus") and UnitGUID("focus") or nil
    
    --  Si cambió focus, SIEMPRE ocultar inmediatamente
    if oldGUID ~= newGUID then
        self:HideCastbar("focus")
        state.unitGUID = newGUID
    end
    
    HideBlizzardCastbar("focus")
    
    --  Solo proceder si hay focus válido
    if UnitExists("focus") and IsEnabled("focus") then
        --  Verificar que focus no cambió durante el delay
        addon.core:ScheduleTimer(function()
            -- Double-check: asegurar que el focus sigue siendo el mismo
            if UnitGUID("focus") == newGUID then
                if UnitCastingInfo("focus") then
                    state.unitGUID = newGUID  -- Establecer GUID antes del evento
                    self:HandleCastingEvent('UNIT_SPELLCAST_START', "focus")
                elseif UnitChannelInfo("focus") then
                    state.unitGUID = newGUID  -- Establecer GUID antes del evento
                    self:HandleCastingEvent('UNIT_SPELLCAST_CHANNEL_START', "focus")
                end
            end
        end, 0.05)
    else
        --  Asegurar limpieza si no hay focus
        state.unitGUID = nil
    end
end

-- ============================================================================
-- Función de manejo de delays (knockback/pushback)
-- ============================================================================

function CastbarModule:HandleCastDelayed(unitType, unit)
    local state = self.states[unitType]
    local frames = self.frames[unitType]
    
    -- Solo procesar si estamos casting/channeling
    if not state.casting and not state.isChanneling then return end
    
    local name, _, _, iconTex, startTime, endTime
    
    -- Obtener nueva información del servidor
    if state.casting and not state.isChanneling then
        name, _, _, iconTex, startTime, endTime = UnitCastingInfo(unit)
    elseif state.isChanneling then
        name, _, _, iconTex, startTime, endTime = UnitChannelInfo(unit)
    end
    
    -- Verificar que sigue siendo el mismo spell
    if not name or name ~= state.spellName then return end
    
    -- Parsear nuevos tiempos del servidor
    local start, finish, duration = ParseCastTimes(startTime, endTime)
    
    -- Calcular el delay (diferencia entre tiempo esperado y nuevo tiempo)
    local delta = 0
    if state.casting and not state.isChanneling then
        delta = start - state.startTime
    else
        -- Para channels, el delay afecta el endTime
        delta = finish - state.endTime
    end
    
    -- Prevenir deltas negativos (solo acumular delays positivos)
    if delta < 0 then
        delta = 0
    end
    
    -- Acumular el delay total
    state.delay = state.delay + delta
    
    -- Actualizar tiempos del estado
    state.startTime = start
    state.endTime = finish
    state.maxValue = duration
    state.lastServerCheck = GetTime()  -- Actualizar para evitar conflictos con OnUpdate
    
    -- Recalcular progreso actual basado en GetTime()
    local currentTime = GetTime()
    
    if state.casting and not state.isChanneling then
        -- Casting: progreso desde inicio
        local elapsed = currentTime - start
        state.currentValue = max(0, min(elapsed, duration))
    else
        -- Channeling: tiempo restante
        local remaining = finish - currentTime
        state.currentValue = max(0, min(remaining, duration))
    end
    
    -- Actualizar barra de progreso
    frames.castbar:SetMinMaxValues(0, state.maxValue)
    frames.castbar:SetValue(state.currentValue)
    
    -- Calcular progreso para elementos visuales
    local progress = state.maxValue > 0 and (state.currentValue / state.maxValue) or 0
    
    -- Actualizar clipping de textura
    UpdateCastbarVisuals(unitType, progress)
    
    -- Actualizar texto de tiempo
    UpdateTimeText(unitType)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function OnEvent(self, event, unit, ...)
    if event == 'UNIT_AURA' and unit == 'target' then
        local cfg = GetConfig("target")
        if cfg and cfg.enabled and cfg.autoAdjust then
            addon.core:ScheduleTimer(ApplyTargetAuraOffset, 0.05)
        end
    elseif event == 'PLAYER_TARGET_CHANGED' then
        CastbarModule:HandleTargetChanged()
    elseif event == 'PLAYER_FOCUS_CHANGED' then
        CastbarModule:HandleFocusChanged()
    elseif event == 'WORLD_MAP_UPDATE' or event == 'ADDON_LOADED' then
        -- NUEVO: Sincronizar castbars cuando se abren ventanas de UI que pueden pausar casting
        if IsEnabled("player") then
            local state = CastbarModule.states.player
            if state.casting or state.isChanneling then
                -- Forzar verificación del estado del servidor
                state.lastServerCheck = 0
            end
        end
    elseif event == 'PLAYER_ENTERING_WORLD' then
        addon.core:ScheduleTimer(function()
            CastbarModule:RefreshCastbar("player")
            CastbarModule:RefreshCastbar("target")
            CastbarModule:RefreshCastbar("focus")
            
            addon.core:ScheduleTimer(function()
                if IsEnabled("player") then HideBlizzardCastbar("player") end
                if IsEnabled("target") then HideBlizzardCastbar("target") end
                if IsEnabled("focus") then HideBlizzardCastbar("focus") end
            end, 1.0)
        end, 0.5)
    else
        CastbarModule:HandleCastingEvent(event, unit)
    end
end

-- Public API
function addon.RefreshCastbar()
    CastbarModule:RefreshCastbar("player")
end

function addon.RefreshTargetCastbar()
    CastbarModule:RefreshCastbar("target")
end

function addon.RefreshFocusCastbar()
    CastbarModule:RefreshCastbar("focus")
end

-- Initialize
local eventFrame = CreateFrame('Frame', 'DragonUICastbarEventHandler')
local events = {
    'PLAYER_ENTERING_WORLD',
    'UNIT_SPELLCAST_START',
    'UNIT_SPELLCAST_DELAYED',          
    'UNIT_SPELLCAST_STOP',
    'UNIT_SPELLCAST_FAILED',
    'UNIT_SPELLCAST_INTERRUPTED',
    'UNIT_SPELLCAST_CHANNEL_START',
    'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE',   
    'UNIT_SPELLCAST_SUCCEEDED',
    'UNIT_AURA',
    'PLAYER_TARGET_CHANGED',
    'PLAYER_FOCUS_CHANGED',
    'WORLD_MAP_UPDATE'
}

for _, event in ipairs(events) do
    eventFrame:RegisterEvent(event)
end

eventFrame:SetScript('OnEvent', OnEvent)

-- Hook native WoW aura positioning
if TargetFrameSpellBar then
    hooksecurefunc('Target_Spellbar_AdjustPosition', function()
        local cfg = GetConfig("target")
        if cfg and cfg.enabled and cfg.autoAdjust then
            addon.core:ScheduleTimer(ApplyTargetAuraOffset, 0.05)
        end
    end)
end

--  También necesitamos asegurar que el TargetFrameSpellBar no interfiera
if TargetFrameSpellBar then
    -- Disable Blizzard's own hiding logic that might interfere
    TargetFrameSpellBar:SetScript("OnHide", nil)
    TargetFrameSpellBar:SetScript("OnShow", function(self)
        local cfg = GetConfig("target")
        if cfg and cfg.enabled then
            self:Hide()
        end
    end)
end

-- SEGURO: Hook para detectar apertura del mapa mundial sin modificar funciones protegidas
if WorldMapFrame then
    -- Usar event handlers seguros en lugar de sobrescribir Show/Hide
    WorldMapFrame:HookScript("OnShow", function(self)
        -- Sincronizar castbar del player cuando se abre el mapa
        local state = CastbarModule.states.player
        if state and (state.casting or state.isChanneling) then
            state.lastServerCheck = 0  -- Forzar verificación inmediata
        end
    end)
    
    WorldMapFrame:HookScript("OnHide", function(self)
        -- Sincronizar castbar del player cuando se cierra el mapa
        local state = CastbarModule.states.player
        if state and (state.casting or state.isChanneling) then
            state.lastServerCheck = 0  -- Forzar verificación inmediata
        end
    end)
end

-- ============================================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ============================================================================

-- Variables para el sistema centralizado
CastbarModule.anchor = nil
CastbarModule.initialized = false

-- Create auxiliary frame for anchoring (como party.lua)
local function CreateCastbarAnchorFrame()
    if CastbarModule.anchor then
        return CastbarModule.anchor
    end

    --  USAR FUNCIÓN CENTRALIZADA DE CORE.LUA
    CastbarModule.anchor = addon.CreateUIFrame(256, 16, "PlayerCastbar")
    
    --  PERSONALIZAR TEXTO PARA CASTBAR
    if CastbarModule.anchor.editorText then
        CastbarModule.anchor.editorText:SetText("Player Castbar")
    end
    
    return CastbarModule.anchor
end

--  FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS (COMO party.lua)
local function ApplyWidgetPosition()
    if not CastbarModule.anchor then
        
        return
    end

    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        
        return
    end
    
    local widgetConfig = addon.db.profile.widgets.playerCastbar
    
    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        local anchor = widgetConfig.anchor or "BOTTOM"
        CastbarModule.anchor:ClearAllPoints()
        CastbarModule.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
        
    else
        --  POSICIÓN POR DEFECTO 
        CastbarModule.anchor:ClearAllPoints()
        CastbarModule.anchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 270)
        
    end
end

--  FUNCIONES REQUERIDAS POR EL SISTEMA CENTRALIZADO
function CastbarModule:LoadDefaultSettings()
    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN WIDGETS
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    if not addon.db.profile.widgets.playerCastbar then
        addon.db.profile.widgets.playerCastbar = {
            anchor = "BOTTOM",
            posX = 0,
            posY = 270
        }
        
    end
    
    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN CASTBAR
    if not addon.db.profile.castbar then
        addon.db.profile.castbar = {}
    end
    
    if not addon.db.profile.castbar.enabled then
        -- La configuración del castbar ya existe en database.lua
        -- Solo aseguramos que esté inicializada
        
    end
end

function CastbarModule:UpdateWidgets()
    ApplyWidgetPosition()
    --  REPOSICIONAR EL CASTBAR DEL PLAYER RELATIVO AL ANCHOR ACTUALIZADO
    if not InCombatLockdown() then
        -- El castbar del player debería seguir al anchor
        self:RefreshCastbar("player")
    end
end

--  FUNCIÓN PARA VERIFICAR SI EL CASTBAR DEBE ESTAR VISIBLE
local function ShouldPlayerCastbarBeVisible()
    local cfg = GetConfig("player")
    return cfg and cfg.enabled
end

--  FUNCIONES DE TESTEO PARA EL EDITOR
local function ShowPlayerCastbarTest()
    -- Mostrar el castbar aunque no haya casting
    local frames = CastbarModule.frames.player
    if frames.castbar then
        -- Simular un cast de prueba
        frames.castbar:SetMinMaxValues(0, 1)
        frames.castbar:SetValue(0.5)
        frames.castbar:Show()
        
        if frames.textBackground then
            frames.textBackground:Show()
        end
        
        -- Mostrar texto de prueba
        CastbarModule:ShowCastbar("player", "Fire ball", 0.5, 1, 1.5, false, false)
    end
end

local function HidePlayerCastbarTest()
    -- Ocultar el castbar de prueba
    CastbarModule:HideCastbar("player")
end

--  FUNCIÓN AUXILIAR PARA MOSTRAR CASTBAR (USADA EN TESTS)
function CastbarModule:ShowCastbar(unitType, spellName, currentValue, maxValue, duration, isChanneling, isInterrupted)
    local frames = self.frames[unitType]
    if not frames.castbar then
        self:RefreshCastbar(unitType)
        frames = self.frames[unitType]
    end
    
    if not frames.castbar then return end
    
    local state = self.states[unitType]
    state.casting = not isChanneling
    state.isChanneling = isChanneling
    state.spellName = spellName
    state.maxValue = maxValue
    state.currentValue = currentValue
    
    frames.castbar:SetMinMaxValues(0, maxValue)
    frames.castbar:SetValue(currentValue)
    frames.castbar:Show()
    
    if isInterrupted then
        frames.castbar:SetStatusBarTexture(TEXTURES.interrupted)
        frames.castbar:SetStatusBarColor(1, 0, 0, 1)
        SetCastText(unitType, "Interrupted")
    else
        if isChanneling then
            frames.castbar:SetStatusBarTexture(TEXTURES.channel)
            frames.castbar:SetStatusBarColor(0, 1, 0, 1)
        else
            frames.castbar:SetStatusBarTexture(TEXTURES.standard)
            frames.castbar:SetStatusBarColor(1, 0.7, 0, 1)
        end
        SetCastText(unitType, spellName)
    end
    
    if frames.textBackground then
        frames.textBackground:Show()
    end
    
    ForceStatusBarLayer(frames.castbar)
end

--  FUNCIÓN DE INICIALIZACIÓN DEL SISTEMA CENTRALIZADO
local function InitializeCastbarForEditor()
    -- Crear el anchor frame
    CreateCastbarAnchorFrame()
    
    --  REGISTRO COMPLETO CON TODAS LAS FUNCIONES (COMO party.lua)
    addon:RegisterEditableFrame({
        name = "PlayerCastbar",
        frame = CastbarModule.anchor,
        configPath = {"widgets", "playerCastbar"},  --  CORREGIDO: Array en lugar de string
        hasTarget = ShouldPlayerCastbarBeVisible,  --  Visibilidad condicional
        showTest = ShowPlayerCastbarTest,  --  CORREGIDO: Minúscula como party.lua
        hideTest = HidePlayerCastbarTest,  --  CORREGIDO: Minúscula como party.lua
        onHide = function() CastbarModule:UpdateWidgets() end,  --  AÑADIDO: Para aplicar cambios
        LoadDefaultSettings = function() CastbarModule:LoadDefaultSettings() end,
        UpdateWidgets = function() CastbarModule:UpdateWidgets() end
    })
    
    CastbarModule.initialized = true
    
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--  Initialize centralized system for editor
InitializeCastbarForEditor()

--  LISTENER PARA CUANDO EL ADDON ESTÉ COMPLETAMENTE CARGADO
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Aplicar posición del widget cuando el addon esté listo
        if CastbarModule.UpdateWidgets then
            CastbarModule:UpdateWidgets()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)