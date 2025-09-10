local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI TARGET OF TARGET FRAME MODULE - WoW 3.3.5a
-- ============================================================================

local Module = {
    totFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil
}

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

-- Cache Blizzard frames
local TargetFrameToT = _G.TargetFrameToT
local TargetFrameToTHealthBar = _G.TargetFrameToTHealthBar
local TargetFrameToTManaBar = _G.TargetFrameToTManaBar
local TargetFrameToTPortrait = _G.TargetFrameToTPortrait
local TargetFrameToTTextureFrameName = _G.TargetFrameToTTextureFrameName

-- Texture paths (ToT específicas)
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-",
    BOSS = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x"
}

-- Boss classifications (coordenadas ToT más pequeñas)
local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 60, 59, 3, 1},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125, 60, 59, 3, 1},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 74, 61, 10, 1}
}

-- Power types
local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- Frame elements storage
local frameElements = {
    background = nil,
    border = nil,
    elite = nil
}

-- Update throttling
local updateCache = {
    lastHealthUpdate = 0,
    lastPowerUpdate = 0
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "tot") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.tot or {}
    return setmetatable(config, {
        __index = defaults
    })
end

-- ============================================================================
-- BAR MANAGEMENT (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function SetupBarHooks()
    -- Health bar hooks (igual que tu target.lua)
    if not TargetFrameToTHealthBar.DragonUI_Setup then
        local healthTexture = TargetFrameToTHealthBar:GetStatusBarTexture()
        if healthTexture then
            healthTexture:SetDrawLayer("ARTWORK", 1)
        end

        hooksecurefunc(TargetFrameToTHealthBar, "SetValue", function(self)
            if not UnitExists("targettarget") then
                return
            end

            local now = GetTime()
            if now - updateCache.lastHealthUpdate < 0.05 then
                return
            end
            updateCache.lastHealthUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            -- Update texture path
            local texturePath = TEXTURES.BAR_PREFIX .. "Health"
            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1)
            end

            -- Update coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end

            -- Update color
            local config = GetConfig()
            if config.classcolor and UnitIsPlayer("targettarget") then
                local _, class = UnitClass("targettarget")
                local color = RAID_CLASS_COLORS[class]
                if color then
                    texture:SetVertexColor(color.r, color.g, color.b)
                else
                    texture:SetVertexColor(1, 1, 1)
                end
            else
                texture:SetVertexColor(1, 1, 1)
            end
        end)

        TargetFrameToTHealthBar.DragonUI_Setup = true
    end

    -- Power bar hooks (igual que tu target.lua)
    if not TargetFrameToTManaBar.DragonUI_Setup then
        local powerTexture = TargetFrameToTManaBar:GetStatusBarTexture()
        if powerTexture then
            powerTexture:SetDrawLayer("ARTWORK", 1)
        end

        hooksecurefunc(TargetFrameToTManaBar, "SetValue", function(self)
            if not UnitExists("targettarget") then
                return
            end

            local now = GetTime()
            if now - updateCache.lastPowerUpdate < 0.05 then
                return
            end
            updateCache.lastPowerUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            -- Update texture based on power type
            local powerType = UnitPowerType("targettarget")
            local powerName = POWER_MAP[powerType] or "Mana"
            local texturePath = TEXTURES.BAR_PREFIX .. powerName

            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1)
            end

            -- Update coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end

            -- Force white color
            texture:SetVertexColor(1, 1, 1)
        end)

        TargetFrameToTManaBar.DragonUI_Setup = true
    end
end

-- ============================================================================
-- CLASSIFICATION SYSTEM (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("targettarget") or not frameElements.elite then
        if frameElements.elite then frameElements.elite:Hide() end
        return
    end
    
    local classification = UnitClassification("targettarget")
    local coords = nil
    
    -- Check vehicle first
    if UnitVehicleSeatCount and UnitVehicleSeatCount("targettarget") > 0 then
        frameElements.elite:Hide()
        return
    end
    
    -- Determine classification
    if classification == "worldboss" or classification == "elite" then
        coords = BOSS_COORDS.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDS.rare
    else
        local name = UnitName("targettarget")
        if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
            coords = BOSS_COORDS.elite
        end
    end
    
    if coords then
        frameElements.elite:SetTexture(TEXTURES.BOSS) -- ✅ AÑADIDO: SetTexture
        
        -- ✅ APLICAR FLIP HORIZONTAL A TODAS LAS DECORACIONES
        local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
        frameElements.elite:SetTexCoord(right, left, top, bottom) -- ✅ FLIPPED: right, left en lugar de left, right
        
        -- ✅ USAR VALORES CORREGIDOS DEL DEBUG
        frameElements.elite:SetSize(50, 49) -- En lugar de coords[5], coords[6]
        frameElements.elite:SetPoint("CENTER", TargetFrameToTPortrait, "CENTER", -4, -3) -- En lugar de coords[7], coords[8]
        frameElements.elite:SetDrawLayer("OVERLAY", 11) -- ✅ FORZAR DRAW LAYER
        frameElements.elite:Show()
        frameElements.elite:SetAlpha(1) -- ✅ ASEGURAR VISIBILIDAD
    else
        frameElements.elite:Hide()
    end
end

-- ============================================================================
-- NAME TEXT OPTIMIZATION (De tu unitframe.lua)
-- ============================================================================

local function UpdateNameText()
    if TargetFrameToTTextureFrameName and UnitExists('targettarget') then
        local name = UnitName('targettarget')
        if name then
            -- Truncado optimizado para ToT (más corto)
            local function TruncateToTText(textFrame, name, maxWidth)
                if not textFrame or not name or name == "" then
                    if textFrame then
                        textFrame:SetText("")
                    end
                    return ""
                end

                textFrame:SetText(name)
                local currentWidth = textFrame:GetStringWidth()

                if currentWidth <= maxWidth then
                    return name
                end

                -- Binary search para truncado óptimo
                local left, right = 1, string.len(name)
                local bestTruncated = name

                while left <= right do
                    local mid = math.floor((left + right) / 2)
                    local testText = string.sub(name, 1, mid) .. "..."
                    textFrame:SetText(testText)
                    local testWidth = textFrame:GetStringWidth()

                    if testWidth <= maxWidth then
                        bestTruncated = testText
                        left = mid + 1
                    else
                        right = mid - 1
                    end
                end

                return bestTruncated
            end

            local finalText = TruncateToTText(TargetFrameToTTextureFrameName, name, 50)
            TargetFrameToTTextureFrameName:SetText(finalText)
        else
            TargetFrameToTTextureFrameName:SetText("")
        end
    elseif TargetFrameToTTextureFrameName then
        TargetFrameToTTextureFrameName:SetText("")
    end
end

-- ============================================================================
-- FRAME INITIALIZATION (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function InitializeFrame()
    if Module.configured then
        return
    end

    -- Verificar que ToT existe
    if not TargetFrameToT then
        print("|cFFFF0000[DragonUI]|r TargetFrameToT not available")
        return
    end

    -- Get configuration
    local config = GetConfig()
    local scale = config.scale or 1.0
    local anchorFrame = config.anchorFrame or 'TargetFrame'
    local anchor = config.anchor or 'BOTTOMRIGHT'
    local anchorParent = config.anchorParent or 'BOTTOMRIGHT'
    local x = config.x or (-35 + 27)
    local y = config.y or -15

    -- Position and scale
    TargetFrameToT:ClearAllPoints()
    TargetFrameToT:SetPoint(anchor, _G[anchorFrame] or TargetFrame, anchorParent, x, y)
    TargetFrameToT:SetScale(scale)
    TargetFrameToT:SetSize(93 + 27, 45)

    -- Hide Blizzard elements
    local toHide = {TargetFrameToTTextureFrameTexture, TargetFrameToTBackground}

    for _, element in ipairs(toHide) do
        if element then
            element:SetAlpha(0)
            element:Hide()
        end
    end

    -- Create background texture
    if not frameElements.background then
        frameElements.background = TargetFrameToT:CreateTexture("DragonUI_ToTBG", "BACKGROUND", nil, 0)
        frameElements.background:SetTexture(TEXTURES.BACKGROUND)
        frameElements.background:SetPoint('LEFT', TargetFrameToTPortrait, 'CENTER', -25 + 1, -10)
    end

    -- Create border texture
    if not frameElements.border then
        frameElements.border = TargetFrameToTHealthBar:CreateTexture("DragonUI_ToTBorder", "OVERLAY", nil, 1)
        frameElements.border:SetTexture(TEXTURES.BORDER)
        frameElements.border:SetPoint('LEFT', TargetFrameToTPortrait, 'CENTER', -25 + 1, -10)
        frameElements.border:Show()
        frameElements.border:SetAlpha(1)
    end

    -- Create elite decoration
if not frameElements.elite then
    local eliteFrame = CreateFrame("Frame", "DragonUI_ToTEliteFrame", TargetFrameToT)
    eliteFrame:SetFrameStrata("MEDIUM") 
    eliteFrame:SetAllPoints(TargetFrameToTPortrait)
    
    frameElements.elite = eliteFrame:CreateTexture("DragonUI_ToTElite", "OVERLAY", nil, 1)
    frameElements.elite:SetTexture(TEXTURES.BOSS)
    frameElements.elite:Hide()
end
    -- Configure health bar
    TargetFrameToTHealthBar:Hide()
    TargetFrameToTHealthBar:ClearAllPoints()
    TargetFrameToTHealthBar:SetParent(TargetFrameToT)
    TargetFrameToTHealthBar:SetFrameStrata("LOW")
    TargetFrameToTHealthBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(TEXTURES.BAR_PREFIX .. "Health")
    TargetFrameToTHealthBar.SetStatusBarColor = function()
    end -- noop
    TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    TargetFrameToTHealthBar:SetSize(70.5, 10)
    TargetFrameToTHealthBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 + 1, 0)
    TargetFrameToTHealthBar:Show()

    -- Configure power bar
    TargetFrameToTManaBar:Hide()
    TargetFrameToTManaBar:ClearAllPoints()
    TargetFrameToTManaBar:SetParent(TargetFrameToT)
    TargetFrameToTManaBar:SetFrameStrata("LOW")
    TargetFrameToTManaBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    TargetFrameToTManaBar:GetStatusBarTexture():SetTexture(TEXTURES.BAR_PREFIX .. "Mana")
    TargetFrameToTManaBar.SetStatusBarColor = function()
    end -- noop
    TargetFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    TargetFrameToTManaBar:SetSize(74, 7.5)
    TargetFrameToTManaBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 - 2 - 1.5 + 1, 2 - 10 - 1)
    TargetFrameToTManaBar:Show()

    -- Configure name text
    if TargetFrameToTTextureFrameName then
        TargetFrameToTTextureFrameName:ClearAllPoints()
        TargetFrameToTTextureFrameName:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 3, 13)
        TargetFrameToTTextureFrameName:SetParent(TargetFrameToT)
        TargetFrameToTTextureFrameName:Show()
        local font, size, flags = TargetFrameToTTextureFrameName:GetFont()
        if font and size then
            TargetFrameToTTextureFrameName:SetFont(font, math.max(size, 10), flags)
        end
        TargetFrameToTTextureFrameName:SetTextColor(1.0, 0.82, 0.0, 1.0) -- WoW standard yellow
        TargetFrameToTTextureFrameName:SetDrawLayer("BORDER", 1)
    end

    -- Setup bar hooks
    SetupBarHooks()

    -- ✅ SETUP TEXT SYSTEM (IGUAL QUE TARGET/FOCUS)
    if addon.TextSystem and not Module.textSystem then
        Module.textSystem = addon.TextSystem.SetupFrameTextSystem("tot", "targettarget", TargetFrameToT,
            TargetFrameToTHealthBar, TargetFrameToTManaBar, "TargetFrameToT")
    end

    if not Module.threatHooked and TargetFrame_CheckClassification then
    hooksecurefunc("TargetFrame_CheckClassification", function()
        -- Force update ToT classification when target changes
        if UnitExists("targettarget") then
            UpdateClassification()
        end
    end)
    Module.threatHooked = true
end

    Module.configured = true
    print("|cFF00FF00[DragonUI]|r TargetOfTarget configured successfully")
end

-- ============================================================================
-- EVENT HANDLING (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.totFrame = CreateFrame("Frame", "DragonUI_ToT_Anchor", UIParent)
            Module.totFrame:SetSize(120, 47)
            Module.totFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 370, -80)
            Module.initialized = true
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        if UnitExists("targettarget") then
            UpdateNameText()
            UpdateClassification()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Target cambió, forzar update del ToT
        UpdateNameText()
        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end

    elseif event == "UNIT_TARGET" then
        local unit = ...
        if unit == "target" then -- El target del target cambió
            UpdateNameText()
            UpdateClassification()
            if Module.textSystem then
                Module.textSystem.update()
            end
        end

    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        local unit = ...
        if unit == "targettarget" then
            UpdateClassification()
        end

    elseif event == "UNIT_FACTION" then
        local unit = ...
        if unit == "targettarget" then
            -- No tenemos name background como target, pero podrías agregarlo
        end
    end
end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_TARGET") -- Crucial para ToT
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_FACTION")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API (IGUAL QUE TARGET/FOCUS)
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end

    if UnitExists("targettarget") then
        UpdateNameText()
        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

local function ResetFrame()
    local defaults = addon.defaults and addon.defaults.profile.unitframe.tot or {}
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "tot", key, value)
    end

    local config = GetConfig()
    TargetFrameToT:ClearAllPoints()
    TargetFrameToT:SetScale(config.scale or 1)
    TargetFrameToT:SetPoint("BOTTOMRIGHT", TargetFrame, "BOTTOMRIGHT", defaults.x or (-35 + 27), defaults.y or -15)
end

-- Export API (igual que target/focus)
addon.TargetOfTarget = {
    Refresh = RefreshFrame,
    RefreshToTFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function()
        return Module.totFrame
    end,
    ChangeToTFrame = RefreshFrame
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeToT = RefreshFrame
addon.unitframe.ReApplyToTFrame = RefreshFrame
addon.unitframe.StyleToTFrame = InitializeFrame

function addon:RefreshToTFrame()
    RefreshFrame()
end

print("|cFF00FF00[DragonUI]|r Target of Target module loaded and optimized v1.0")
