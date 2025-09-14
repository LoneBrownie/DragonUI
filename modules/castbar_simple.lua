local addon = select(2, ...);

-- Castbar Module for DragonUI
-- Based on RetailUI's CastingBar module, adapted for WoW 3.3.5a compatibility

-- ===================================================================
-- CORE UTILITY FUNCTIONS (adapted from RetailUI Core.lua)
-- ===================================================================

-- Create a configurable UI frame with editor support
local function CreateUIFrame(width, height, frameName)
    local frame = CreateFrame("Frame", 'DragonUI_' .. frameName, UIParent)
    frame:SetSize(width, height)
    
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    
    frame:SetFrameLevel(100)
    frame:SetFrameStrata('FULLSCREEN')
    
    -- Editor texture (for edit mode)
    do
        local texture = frame:CreateTexture(nil, 'BACKGROUND')
        texture:SetAllPoints(frame)
        texture:SetTexture("Interface\\AddOns\\DragonUI\\assets\\uiactionbar.blp")
        texture:SetTexCoord(0, 1, 0, 1)
        texture:Hide()
        frame.editorTexture = texture
    end
    
    -- Editor text label
    do
        local fontString = frame:CreateFontString(nil, "BORDER", 'GameFontNormal')
        fontString:SetAllPoints(frame)
        fontString:SetText(frameName)
        fontString:Hide()
        frame.editorText = fontString
    end
    
    return frame
end

-- Editor mode helper functions
local dragonUIFrames = {}

local function ShowUIFrame(frame)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    
    frame.editorTexture:Hide()
    frame.editorText:Hide()
    
    if dragonUIFrames[frame] then
        for _, target in pairs(dragonUIFrames[frame]) do
            target:SetAlpha(1)
        end
        dragonUIFrames[frame] = nil
    end
end

local function HideUIFrame(frame, exclude)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    
    frame.editorTexture:Show()
    frame.editorText:Show()
    
    dragonUIFrames[frame] = {}
    exclude = exclude or {}
    
    for _, target in pairs(exclude) do
        target:SetAlpha(0)
        table.insert(dragonUIFrames[frame], target)
    end
end

-- Save frame position to addon database
local function SaveUIFramePosition(frame, widgetName)
    local _, _, relativePoint, posX, posY = frame:GetPoint('CENTER')
    
    -- Ensure castbar config exists
    if not addon.db.profile.castbar then
        addon.db.profile.castbar = {}
    end
    if not addon.db.profile.castbar.widgets then
        addon.db.profile.castbar.widgets = {}
    end
    if not addon.db.profile.castbar.widgets[widgetName] then
        addon.db.profile.castbar.widgets[widgetName] = {}
    end
    
    addon.db.profile.castbar.widgets[widgetName].anchor = relativePoint
    addon.db.profile.castbar.widgets[widgetName].posX = posX
    addon.db.profile.castbar.widgets[widgetName].posY = posY
end

-- Check if settings exist and load defaults if not
local function CheckSettingsExists(moduleInstance, widgets)
    for _, widget in pairs(widgets) do
        if not addon.db.profile.castbar or 
           not addon.db.profile.castbar.widgets or 
           not addon.db.profile.castbar.widgets[widget] then
            moduleInstance:LoadDefaultSettings()
            break
        end
    end
    moduleInstance:UpdateWidgets()
end

-- ===================================================================
-- CASTBAR MODULE (Keeping original architecture intact)
-- ===================================================================

-- Module instance tracking
local CastbarModule = {}
CastbarModule.playerCastingBar = nil

-- Replace Blizzard casting bar frame with our custom styling
local function ReplaceBlizzardCastingBarFrame(castingBarFrame, attachTo)
    local statusBar = castingBarFrame
    statusBar:SetMovable(true)
    statusBar:SetUserPlaced(true)
    statusBar:ClearAllPoints()
    statusBar:SetMinMaxValues(0.0, 1.0)
    statusBar:SetFrameLevel(statusBar:GetParent():GetFrameLevel() + 1)

    statusBar.selfInterrupt = false

    attachTo = attachTo or nil
    if attachTo then
        statusBar:SetPoint("LEFT", attachTo, "LEFT", 0, 0)
        statusBar:SetSize(attachTo:GetWidth() - 3, attachTo:GetHeight() - 3)
    end

    local statusBarTexture = statusBar:GetStatusBarTexture()
    statusBarTexture:SetAllPoints(statusBar)
    statusBarTexture:SetDrawLayer('BORDER')

    local borderTexture = _G[statusBar:GetName() .. "Border"]
    borderTexture:SetAllPoints(statusBar)
    borderTexture:SetPoint("TOPLEFT", -3, 2)
    borderTexture:SetPoint("BOTTOMRIGHT", 3, -2)
    SetAtlasTexture(borderTexture, 'CastingBar-Border')

    for _, region in pairs { statusBar:GetRegions() } do
        if region:GetObjectType() == 'Texture' and region:GetDrawLayer() == 'BACKGROUND' then
            region:SetAllPoints(borderTexture)
            SetAtlasTexture(region, 'CastingBar-Background')
        end
    end

    local sparkTexture = _G[statusBar:GetName() .. "Spark"]
    SetAtlasTexture(sparkTexture, 'CastingBar-Spark')
    sparkTexture:SetSize(4, statusBar:GetHeight() * 1.25)

    local castingNameText = _G[statusBar:GetName() .. "Text"]
    castingNameText:ClearAllPoints()
    castingNameText:SetPoint("BOTTOMLEFT", 5, -16)
    castingNameText:SetJustifyH("LEFT")
    castingNameText:SetWidth(statusBar:GetWidth() * 0.6)

    statusBar.backgroundInfo = statusBar.backgroundInfo or CreateFrame("Frame", nil, statusBar)
    statusBar.backgroundInfo.background = statusBar.backgroundInfo.background or
        statusBar:CreateTexture(nil, "BACKGROUND")
    local backgroundTexture = statusBar.backgroundInfo.background
    backgroundTexture:SetAllPoints(statusBar)
    backgroundTexture:SetPoint("BOTTOMRIGHT", 1, -16)
    SetAtlasTexture(backgroundTexture, 'CastingBar-MainBackground')

    local iconTexture = _G[statusBar:GetName() .. "Icon"]
    iconTexture:ClearAllPoints()
    iconTexture:SetPoint("RIGHT", backgroundTexture, "LEFT", -5, 0)
    iconTexture:SetSize(24, 24)

    statusBar.castingTime = statusBar.castingTime or statusBar:CreateFontString(nil, "BORDER", 'GameFontHighlightSmall')
    local castTimeText = statusBar.castingTime
    castTimeText:SetPoint("BOTTOMRIGHT", -4, -14)
    castTimeText:SetJustifyH("RIGHT")

    local flashTexture = _G[statusBar:GetName() .. "Flash"]
    flashTexture:SetAlpha(0)

    local borderShieldTexture = _G[statusBar:GetName() .. 'BorderShield']
    borderShieldTexture:ClearAllPoints()
    borderShieldTexture:SetPoint("CENTER", _G[statusBar:GetName() .. 'Icon'], "CENTER", 0, 0)
    SetAtlasTexture(borderShieldTexture, 'CastingBar-BorderShield')
    borderShieldTexture:SetDrawLayer("BACKGROUND")
    borderShieldTexture:SetSize(borderShieldTexture:GetWidth() / 2.5, borderShieldTexture:GetHeight() / 2.5)

    statusBar.ShowTest = function(self)
        SetAtlasTexture(self:GetStatusBarTexture(), 'CastingBar-StatusBar-Casting')
        self:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        self:SetValue(0.5)

        local castingNameText = _G[self:GetName() .. "Text"]
        castingNameText:SetText("Healing Wave")
        self.castingTime:SetText(string.format('%.1f/%.2f', 0.5, 1.0))

        self:SetAlpha(1.0)
        self:Show()
    end

    statusBar.HideTest = function(self)
        self:Hide()
    end
end

-- Custom OnUpdate handler for casting bars
local function CastingBarFrame_OnUpdate(self, elapsed)
    local currentTime, value, remainingTime = GetTime(), 0, 0
    if self.channelingEx or self.castingEx then
        if self.castingEx then
            remainingTime = min(currentTime, self.endTime) - self.startTime
            value = remainingTime / (self.endTime - self.startTime)
        elseif self.channelingEx then
            remainingTime = self.endTime - currentTime
            value = remainingTime / (self.endTime - self.startTime)
        end

        self:SetValue(value)

        self.castingTime:SetText(string.format('%.1f/%.2f', abs(remainingTime),
            self.endTime - self.startTime))

        local sparkTexture = _G[self:GetName() .. "Spark"]
        sparkTexture:ClearAllPoints()
        sparkTexture:SetPoint("CENTER", self, "LEFT", value * self:GetWidth(), 0)

        if currentTime > self.endTime then
            self.castingEx, self.channelingEx = nil, nil
            self.fadeOutEx = true
        end
    elseif self.fadeOutEx then
        local sparkTexture = _G[self:GetName() .. "Spark"]
        if sparkTexture then
            sparkTexture:Hide()
        end

        if self:GetAlpha() <= 0.0 then
            self:Hide()
        end
    end
end

-- Target spellbar position adjustment
local function Target_Spellbar_AdjustPosition(self)
    self.SetPoint = UIParent.SetPoint
    local parentFrame = self:GetParent()
    self:ClearAllPoints()
    
    if parentFrame.haveToT then
        if (parentFrame.auraRows <= 1) then
            self:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -40)
        else
            self:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -20)
        end
    elseif parentFrame.haveElite then
        if parentFrame.auraRows <= 1 then
            self:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -10)
        else
            self:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -10)
        end
    else
        -- FIX: Use consistent positioning to avoid visual jumps
        -- Always use parentFrame as reference for stable positioning
        if parentFrame.auraRows <= 1 then
            -- 0 or 1 aura row - use same position to prevent jumps
            self:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -10)
        else
            -- Multiple aura rows - need more space, use spellbarAnchor
            self:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -10)
        end
    end
    self.SetPoint = function() end
end

-- ===================================================================
-- MODULE FUNCTIONS (Keeping original event architecture intact)
-- ===================================================================

function CastbarModule:OnEnable()
    -- Register all spell casting events
    addon.core:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:PLAYER_ENTERING_WORLD() end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit) self:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_STOP", function(_, unit) self:UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_STOP", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_FAILED", function(_, unit) self:UNIT_SPELLCAST_FAILED("UNIT_SPELLCAST_FAILED", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", function(_, unit) self:UNIT_SPELLCAST_INTERRUPTED("UNIT_SPELLCAST_INTERRUPTED", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_DELAYED", function(_, unit) self:UNIT_SPELLCAST_DELAYED("UNIT_SPELLCAST_DELAYED", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unit) self:UNIT_SPELLCAST_START("UNIT_SPELLCAST_CHANNEL_START", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit) self:UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_CHANNEL_STOP", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", function(_, unit) self:UNIT_SPELLCAST_INTERRUPTED("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", function(_, unit) self:UNIT_SPELLCAST_DELAYED("UNIT_SPELLCAST_CHANNEL_UPDATE", unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE", function(_, unit) self:UNIT_SPELLCAST_INTERRUPTIBLE(unit) end)
    addon.core:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", function(_, unit) self:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(unit) end)
    addon.core:RegisterEvent("PLAYER_TARGET_CHANGED", function() self:PLAYER_TARGET_CHANGED() end)
    addon.core:RegisterEvent("PLAYER_FOCUS_CHANGED", function() self:PLAYER_FOCUS_CHANGED() end)

    -- Unregister Blizzard casting bar events
    CastingBarFrame:UnregisterAllEvents()
    if FocusFrameSpellBar then FocusFrameSpellBar:UnregisterAllEvents() end
    if TargetFrameSpellBar then TargetFrameSpellBar:UnregisterAllEvents() end
    if PetCastingBarFrame then PetCastingBarFrame:UnregisterAllEvents() end

    -- Hook our custom OnUpdate handlers
    CastingBarFrame:HookScript("OnUpdate", CastingBarFrame_OnUpdate)
    if TargetFrameSpellBar then TargetFrameSpellBar:HookScript("OnUpdate", CastingBarFrame_OnUpdate) end
    if FocusFrameSpellBar then FocusFrameSpellBar:HookScript("OnUpdate", CastingBarFrame_OnUpdate) end
    if PetCastingBarFrame then PetCastingBarFrame:HookScript("OnUpdate", CastingBarFrame_OnUpdate) end

    -- Hook target spellbar positioning
    if Target_Spellbar_AdjustPosition then
        hooksecurefunc('Target_Spellbar_AdjustPosition', Target_Spellbar_AdjustPosition)
    end

    -- Create configurable player casting bar frame
    self.playerCastingBar = CreateUIFrame(228, 18, "CastingBarFrame")
end

function CastbarModule:OnDisable()
    -- Unregister all events (cleanup)
    -- Note: In DragonUI, events are managed by core, so we don't need explicit unregistration
end

function CastbarModule:PLAYER_ENTERING_WORLD()
    -- Initialize all casting bar frames
    ReplaceBlizzardCastingBarFrame(CastingBarFrame, self.playerCastingBar)
    if TargetFrameSpellBar then ReplaceBlizzardCastingBarFrame(TargetFrameSpellBar) end
    if FocusFrameSpellBar then ReplaceBlizzardCastingBarFrame(FocusFrameSpellBar) end
    if PetCastingBarFrame then ReplaceBlizzardCastingBarFrame(PetCastingBarFrame) end

    -- Check and load settings
    CheckSettingsExists(self, { 'playerCastingBar' })
end

function CastbarModule:PLAYER_TARGET_CHANGED()
    local statusBar = TargetFrameSpellBar
    if not statusBar then return end

    if UnitExists("target") and statusBar.unit == UnitGUID("target") then
        if GetTime() > statusBar.endTime then
            statusBar:Hide()
        else
            statusBar:Show()
        end
    else
        statusBar:Hide()
    end
end

function CastbarModule:PLAYER_FOCUS_CHANGED()
    local statusBar = FocusFrameSpellBar
    if not statusBar then return end

    if UnitExists("focus") and statusBar.unit == UnitGUID("focus") then
        if GetTime() > statusBar.endTime then
            statusBar:Hide()
        else
            statusBar:Show()
        end
    else
        statusBar:Hide()
    end
end

function CastbarModule:UNIT_SPELLCAST_START(eventName, unit)
    local statusBar
    if unit == 'player' then
        statusBar = CastingBarFrame
    elseif unit == 'target' then
        statusBar = TargetFrameSpellBar
        if statusBar then statusBar.unit = UnitGUID("target") end
    elseif unit == 'focus' then
        statusBar = FocusFrameSpellBar
        if statusBar then statusBar.unit = UnitGUID("focus") end
    elseif unit == 'pet' then
        statusBar = PetCastingBarFrame
    else
        return
    end

    if not statusBar then return end

    local castingNameText = _G[statusBar:GetName() .. "Text"]

    local spell, rank, displayName, icon, startTime, endTime
    if eventName == 'UNIT_SPELLCAST_START' then
        spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
        statusBar.castingEx = true
        SetAtlasTexture(statusBar:GetStatusBarTexture(), 'CastingBar-StatusBar-Casting')
    else
        spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
        statusBar.channelingEx = true
        SetAtlasTexture(statusBar:GetStatusBarTexture(), 'CastingBar-StatusBar-Channeling')
    end

    local iconTexture = _G[statusBar:GetName() .. 'Icon']
    if unit ~= 'player' then
        iconTexture:SetTexture(icon)
        iconTexture:Show()
    else
        iconTexture:Hide()
    end

    castingNameText:SetText(displayName)
    statusBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

    statusBar.startTime = startTime / 1000
    statusBar.endTime = endTime / 1000

    UIFrameFadeRemoveFrame(statusBar)

    local sparkTexture = _G[statusBar:GetName() .. "Spark"]
    sparkTexture:Show()

    statusBar:SetAlpha(1.0)
    statusBar:Show()
end

function CastbarModule:UNIT_SPELLCAST_STOP(eventName, unit)
    local statusBar
    if unit == 'player' then
        statusBar = CastingBarFrame
    elseif unit == 'target' then
        statusBar = TargetFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('target') then return end
    elseif unit == 'focus' then
        statusBar = FocusFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('focus') then return end
    elseif unit == 'pet' then
        statusBar = PetCastingBarFrame
    else
        return
    end

    if not statusBar then return end

    if statusBar.castingEx then
        SetAtlasTexture(statusBar:GetStatusBarTexture(), 'CastingBar-StatusBar-Casting')
    elseif statusBar.channelingEx then
        SetAtlasTexture(statusBar:GetStatusBarTexture(), 'CastingBar-StatusBar-Channeling')
        statusBar.selfInterrupt = true
    end

    statusBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

    statusBar.castingEx, statusBar.channelingEx = false, false
    statusBar.fadeOutEx = true

    UIFrameFadeOut(statusBar, 1, 1.0, 0.0)
end

function CastbarModule:UNIT_SPELLCAST_FAILED(eventName, unit)
    local statusBar
    if unit == 'player' then
        statusBar = CastingBarFrame
    elseif unit == 'target' then
        statusBar = TargetFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('target') then return end
    elseif unit == 'focus' then
        statusBar = FocusFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('focus') then return end
    elseif unit == 'pet' then
        statusBar = PetCastingBarFrame
    else
        return
    end

    if not statusBar then return end

    if statusBar.castingEx then
        SetAtlasTexture(statusBar:GetStatusBarTexture(), 'CastingBar-StatusBar-Casting')
    elseif statusBar.channelingEx then
        SetAtlasTexture(statusBar:GetStatusBarTexture(), 'CastingBar-StatusBar-Channeling')
    end

    statusBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
end

function CastbarModule:UNIT_SPELLCAST_INTERRUPTED(eventName, unit)
    local statusBar
    if unit == 'player' then
        statusBar = CastingBarFrame
    elseif unit == 'target' then
        statusBar = TargetFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('target') then return end
    elseif unit == 'focus' then
        statusBar = FocusFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('focus') then return end
    elseif unit == 'pet' then
        statusBar = PetCastingBarFrame
    else
        return
    end

    if not statusBar then return end

    if not statusBar.selfInterrupt then
        statusBar:SetValue(1.0)
        SetAtlasTexture(statusBar:GetStatusBarTexture(), 'CastingBar-StatusBar-Failed')
        statusBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

        local castingNameText = _G[statusBar:GetName() .. "Text"]
        castingNameText:SetText("Interrupted")
    else
        statusBar.selfInterrupt = false
    end

    statusBar.castingEx, statusBar.channelingEx = false, false
    statusBar.fadeOutEx = true

    UIFrameFadeOut(statusBar, 1, 1.0, 0.0)
end

function CastbarModule:UNIT_SPELLCAST_DELAYED(eventName, unit)
    local statusBar
    if unit == 'player' then
        statusBar = CastingBarFrame
    elseif unit == 'target' then
        statusBar = TargetFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('target') then return end
    elseif unit == 'focus' then
        statusBar = FocusFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('focus') then return end
    elseif unit == 'pet' then
        statusBar = PetCastingBarFrame
    else
        return
    end

    if not statusBar then return end

    local spell, rank, displayName, icon, startTime, endTime
    if statusBar.castingEx then
        spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
    elseif statusBar.channelingEx then
        spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
    end

    if not spell then
        statusBar:Hide()
        return
    end

    statusBar.startTime = startTime / 1000
    statusBar.endTime = endTime / 1000
end

function CastbarModule:UNIT_SPELLCAST_INTERRUPTIBLE(unit)
    local statusBar
    if unit == 'target' then
        statusBar = TargetFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('target') then return end
    elseif unit == 'focus' then
        statusBar = FocusFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('focus') then return end
    elseif unit == 'pet' then
        statusBar = PetCastingBarFrame
    else
        return
    end

    if not statusBar then return end

    local borderShieldTexture = _G[statusBar:GetName() .. 'BorderShield']
    borderShieldTexture:Show()
end

function CastbarModule:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(unit)
    local statusBar
    if unit == 'target' then
        statusBar = TargetFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('target') then return end
    elseif unit == 'focus' then
        statusBar = FocusFrameSpellBar
        if statusBar and statusBar.unit ~= UnitGUID('focus') then return end
    elseif unit == 'pet' then
        statusBar = PetCastingBarFrame
    else
        return
    end

    if not statusBar then return end

    local borderShieldTexture = _G[statusBar:GetName() .. 'BorderShield']
    borderShieldTexture:Hide()
end

function CastbarModule:LoadDefaultSettings()
    -- Ensure castbar config section exists
    if not addon.db.profile.castbar then
        addon.db.profile.castbar = {}
    end
    if not addon.db.profile.castbar.widgets then
        addon.db.profile.castbar.widgets = {}
    end
    
    -- Load default position for player casting bar
    addon.db.profile.castbar.widgets.playerCastingBar = { 
        anchor = "BOTTOM", 
        posX = 0, 
        posY = 270 
    }
end

function CastbarModule:UpdateWidgets()
    if not addon.db.profile.castbar or 
       not addon.db.profile.castbar.widgets or 
       not addon.db.profile.castbar.widgets.playerCastingBar then
        return
    end
    
    local widgetOptions = addon.db.profile.castbar.widgets.playerCastingBar
    self.playerCastingBar:SetPoint(widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY)
end

function CastbarModule:ShowEditorTest()
    HideUIFrame(self.playerCastingBar)
    CastingBarFrame:ShowTest()
end

function CastbarModule:HideEditorTest(refresh)
    ShowUIFrame(self.playerCastingBar)
    SaveUIFramePosition(self.playerCastingBar, 'playerCastingBar')
    CastingBarFrame:HideTest()

    if refresh then
        self:UpdateWidgets()
    end
end

-- ===================================================================
-- INTEGRATION WITH DRAGONUI
-- ===================================================================

-- Create refresh function for DragonUI's RefreshConfig system
function addon.RefreshCastbar()
    if CastbarModule.UpdateWidgets then
        CastbarModule:UpdateWidgets()
    end
end

-- Initialize the module
addon.core:RegisterMessage("DRAGONUI_READY", function()
    CastbarModule:OnEnable()
end)

-- Store module reference for access from other parts of the addon
addon.CastbarModule = CastbarModule