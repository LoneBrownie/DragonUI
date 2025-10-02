local addon = select(2,...);
local config = addon.config;
local action = addon.functions;
local unpack = unpack;
local select = select;
local format = string.format;
local match = string.match;
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS;
local NUM_SHAPESHIFT_SLOTS = NUM_SHAPESHIFT_SLOTS;
local NUM_POSSESS_SLOTS = NUM_POSSESS_SLOTS;
local VEHICLE_MAX_ACTIONBUTTONS = VEHICLE_MAX_ACTIONBUTTONS;
local hooksecurefunc = hooksecurefunc;
local GetName = GetName;
local _G = getfenv(0);

-- ============================================================================
-- BUTTONS MODULE FOR DRAGONUI
-- ============================================================================

-- RANGE_INDICATOR = "•";

local actionbars = {
	'ActionButton',
	'MultiBarBottomLeftButton',
	'MultiBarBottomRightButton',
	'MultiBarRightButton',
	'MultiBarLeftButton',
};

-- Module state tracking
local ButtonsModule = {
    initialized = false,
    applied = false,
    originalValues = {},  -- Store original button states for restoration
    hooked = false,
    pendingRefresh = false  -- Flag to indicate pending refresh after combat
}

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.buttons
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

local function GetButtonsConfig()
    return addon.db and addon.db.profile and addon.db.profile.buttons
end

-- ============================================================================
-- BUTTON ITERATOR
-- ============================================================================

addon.buttons_iterator = function()
	local index = 0
	local barIndex = 1
	return function()
		index = index + 1
		if index > 12 then
			index = 1
			barIndex = barIndex + 1
		end
		if actionbars[barIndex] then
			return _G[actionbars[barIndex]..index]
		end
	end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- helper function to handle action button grid logic
local function handleActionButton(button, wowAlwaysShow)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Avoid taint during combat by not modifying protected frames
    if InCombatLockdown() then return end
    
    if wowAlwaysShow then
        button:SetAttribute('showgrid', 1)
        ActionButton_ShowGrid(button)
    else
        if HasAction(button.action) then
            ActionButton_ShowGrid(button)
        else
            ActionButton_HideGrid(button)
        end
    end
end

-- Get configured button count for main action bar
local function GetMainActionBarButtonCount()
    local db = addon.db and addon.db.profile and addon.db.profile.mainbars and addon.db.profile.mainbars.buttons
    if not db then
        return 12 -- Default fallback
    end
    return db.main or 12
end

function addon.actionbuttons_grid()
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't modify action buttons during combat to avoid taint
    if InCombatLockdown() then 
        ButtonsModule.pendingRefresh = true
        return 
    end
    
    local wowAlwaysShow = GetCVar("alwaysShowActionBars") == "1"
    local db = GetButtonsConfig()
    local hideMainBg = db and db.hide_main_bar_background
    
    -- Only process visible main action bar buttons
    local visibleButtons = GetMainActionBarButtonCount()
    for index = 1, math.min(visibleButtons, 12) do
        local button = _G[format('ActionButton%d', index)]
        if button then
            handleActionButton(button, wowAlwaysShow)
        end
    end
end

local function is_petaction(self, name)
	local spec = self:GetName():match(name)
	if (spec) then return true else return false end
end

local function fix_texture(self, texture)
    if not IsModuleEnabled() then return end
    
	if texture and texture ~= config.assets.normal then
		self:SetNormalTexture(config.assets.normal)
	end
end

local function setup_background(button, anchor, shadow)
    if not IsModuleEnabled() then return nil end
    
	if not button or button.shadow then return; end
	if shadow and not button.shadow then
		local shadow = button:CreateTexture(nil, 'ARTWORK', nil, 1)
		shadow:SetPoint('TOPRIGHT', anchor, 3.8, 3.8)
		shadow:SetPoint('BOTTOMLEFT', anchor, -3.8, -3.8)
		shadow:set_atlas('ui-hud-actionbar-iconframe-flyoutbordershadow', true)
		button.shadow = shadow;
	end

	local background = button:CreateTexture(nil, 'BACKGROUND');
	background:SetAllPoints(anchor);
	background:set_atlas('ui-hud-actionbar-iconframe-slot');
	background:Show();
	
	return background;
end

-- ============================================================================
-- BUTTON STYLING FUNCTIONS
-- ============================================================================

local function actionbuttons_hotkey(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't modify hotkeys during keybinding mode
    if addon.KeyBindingModule and addon.KeyBindingModule.enabled and LibStub and LibStub("LibKeyBound-1.0") then
        local LibKeyBound = LibStub("LibKeyBound-1.0")
        if LibKeyBound:IsShown() then
            return -- Let LibKeyBound handle hotkey display
        end
    end
    
	if not button then return; end
	local buttonName = button:GetName();
	if not buttonName then return; end
	
	local hotkey = _G[buttonName..'HotKey'];
	if not hotkey then return; end
	
	local text = hotkey:GetText();
	if not text then return; end
	
	local db = GetButtonsConfig()
	if not db or not db.hotkey then return end
	
	if RANGE_INDICATOR and text == RANGE_INDICATOR then
		if db.hotkey.range then
			hotkey:SetText(RANGE_INDICATOR);
		else
			hotkey:SetText'';
		end
	else
		hotkey:SetAlpha(db.hotkey.show and 1 or 0)
		
		if addon.GetKeyText then
			hotkey:SetText(addon.GetKeyText(text));
		else
			hotkey:SetText(text);
		end
		
		if db.hotkey.font then
			hotkey:SetFont(unpack(db.hotkey.font));
		end
		
		hotkey:SetShadowOffset(-1.3, -1.1);
		
		if db.hotkey.shadow then
			hotkey:SetShadowColor(unpack(db.hotkey.shadow));
		end
	end
end

local function StoreOriginalButtonState(button)
    if not button or ButtonsModule.originalValues[button] then return end
    
    local name = button:GetName()
    if not name then return end
    
    local normal = _G[name..'NormalTexture'] or button:GetNormalTexture()
    
    ButtonsModule.originalValues[button] = {
        normalTexture = normal and normal:GetTexture(),
        normalPoints = {},
        normalVertexColor = normal and {normal:GetVertexColor()},
        normalDrawLayer = normal and normal:GetDrawLayer(),
        size = {button:GetSize()},
        checkedTexture = button:GetCheckedTexture() and button:GetCheckedTexture():GetTexture(),
        pushedTexture = button:GetPushedTexture() and button:GetPushedTexture():GetTexture(),
        highlightTexture = button:GetHighlightTexture() and button:GetHighlightTexture():GetTexture(),
    }
    
    -- Store normal texture points
    if normal then
        for i = 1, normal:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = normal:GetPoint(i)
            table.insert(ButtonsModule.originalValues[button].normalPoints, {point, relativeTo, relativePoint, xOfs, yOfs})
        end
    end
end

local function main_buttons(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't style buttons during combat to avoid taint
    if InCombatLockdown() then return end
    
	if not button or button.__styled then return; end

    -- Store original state before styling
    StoreOriginalButtonState(button)

	local name = button:GetName();
	local normal = _G[name..'NormalTexture'] or button:GetNormalTexture();
	local icon = _G[name..'Icon']
	local flash = _G[name..'Flash']
	local cooldown = _G[name..'Cooldown']
	local border = _G[name..'Border']
	
	normal:ClearAllPoints()
	normal:SetPoint('TOPRIGHT', button, 2.2, 2.3)
	normal:SetPoint('BOTTOMLEFT', button, -2.2, -2.2)
	normal:SetVertexColor(1, 1, 1, 1)
	normal:SetDrawLayer('OVERLAY')

	if flash then
		flash:set_atlas('ui-hud-actionbar-iconframe-flash')
	end

	if icon then
		icon:SetTexCoord(.05, .95, .05, .95)
		icon:SetDrawLayer('BORDER')
	end

	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
		cooldown:SetFrameLevel(button:GetParent():GetFrameLevel() +1)
	end
	
	if border then
		border:set_atlas('_ui-hud-actionbar-iconborder-checked')
		border:SetAllPoints(normal)
	end
	
	-- apply button textures
	button:GetCheckedTexture():set_atlas('_ui-hud-actionbar-iconborder-checked')
	button:GetPushedTexture():set_atlas('_ui-hud-actionbar-iconborder-pushed')
	button:SetHighlightTexture(config.assets.highlight)
	button:GetCheckedTexture():SetAllPoints(normal)
	button:GetPushedTexture():SetAllPoints(normal)
	button:GetHighlightTexture():SetAllPoints(normal)
	button:GetCheckedTexture():SetDrawLayer('OVERLAY')
	button:GetPushedTexture():SetDrawLayer('OVERLAY')

	button.background = setup_background(button, normal, true)
	
	button.__styled = true
end

local function additional_buttons(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't style buttons during combat to avoid taint
    if InCombatLockdown() then return end
    
	if not button then return; end
	
    -- Store original state before styling
    StoreOriginalButtonState(button)
    
	button:SetNormalTexture(config.assets.normal)
	if button.background then return; end

	local name = button:GetName();
	local icon = _G[name..'Icon']
	local flash = _G[name..'Flash']
	local normal = _G[name..'NormalTexture2'] or _G[name..'NormalTexture']
	local cooldown = _G[name..'Cooldown']
	local castable = _G[name..'AutoCastable']

	normal:ClearAllPoints()
	normal:SetPoint('TOPRIGHT', button, 2.2, 2.3)
	normal:SetPoint('BOTTOMLEFT', button, -2.2, -2.2)

	-- apply button textures
	button:GetCheckedTexture():set_atlas('_ui-hud-actionbar-iconborder-checked')
	button:GetPushedTexture():set_atlas('_ui-hud-actionbar-iconborder-pushed')
	button:SetHighlightTexture(config.assets.highlight)
	button:GetCheckedTexture():SetAllPoints(normal)
	button:GetPushedTexture():SetAllPoints(normal)
	button:GetHighlightTexture():SetAllPoints(normal)

	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
		cooldown:SetFrameLevel(button:GetParent():GetFrameLevel() +1)
	end

	if icon then
		icon:SetTexCoord(.05, .95, .05, .95)
		icon:SetPoint('TOPRIGHT', button, 1, 1)
		icon:SetPoint('BOTTOMLEFT', button, -1, -1)
		icon:SetDrawLayer('BORDER')
	end

	if flash then
		flash:set_atlas('ui-hud-actionbar-iconframe-flash')
	end
	
	if castable then
		castable:ClearAllPoints()
		castable:SetPoint('TOP', 0, 14)
		castable:SetPoint('BOTTOM', 0, -15)
	end

	if is_petaction(button, 'PetActionButton') then
		hooksecurefunc(button, "SetNormalTexture", fix_texture)
	end
	button.background = setup_background(button, normal, false)
end

-- ============================================================================
-- RESTORATION FUNCTIONS
-- ============================================================================

local function RestoreButtonToOriginal(button)
    if not button or not ButtonsModule.originalValues[button] then return end
    
    local original = ButtonsModule.originalValues[button]
    local name = button:GetName()
    if not name then return end
    
    local normal = _G[name..'NormalTexture'] or button:GetNormalTexture()
    
    -- Restore normal texture
    if normal and original.normalTexture then
        normal:SetTexture(original.normalTexture)
        
        -- Restore points
        normal:ClearAllPoints()
        for _, point in ipairs(original.normalPoints) do
            normal:SetPoint(unpack(point))
        end
        
        -- Restore vertex color
        if original.normalVertexColor then
            normal:SetVertexColor(unpack(original.normalVertexColor))
        end
        
        -- Restore draw layer
        if original.normalDrawLayer then
            normal:SetDrawLayer(original.normalDrawLayer)
        end
    end
    
    -- Restore size
    if original.size then
        button:SetSize(unpack(original.size))
    end
    
    -- Remove custom backgrounds and shadows
    if button.background then
        button.background:Hide()
        button.background = nil
    end
    
    if button.shadow then
        button.shadow:Hide()
        button.shadow = nil
    end
    
    -- Reset styled flag
    button.__styled = nil
    
    -- Clear original values
    ButtonsModule.originalValues[button] = nil
end

local function RestoreAllButtons()
    -- Restore main action buttons
    for button in addon.buttons_iterator() do
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore vehicle buttons
    for index=1, VEHICLE_MAX_ACTIONBUTTONS do
        local button = _G['VehicleMenuBarActionButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore possess buttons
    for index=1, NUM_POSSESS_SLOTS do
        local button = _G['PossessButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore pet buttons
    for index=1, NUM_PET_ACTION_SLOTS do
        local button = _G['PetActionButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore stance buttons
    for index=1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    ButtonsModule.applied = false
end

-- ============================================================================
-- APPLY STYLING
-- ============================================================================

local function ApplyButtonStyling()
    if ButtonsModule.applied then return end
    
    -- Setup main action buttons
    for button in addon.buttons_iterator() do
        if button then
            main_buttons(button)
            button:SetSize(37, 37)
        end
    end
    
    ButtonsModule.applied = true
end

-- ============================================================================
-- UPDATE HANDLERS
-- ============================================================================

local function actionbuttons_update(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't interfere with LibKeyBound during keybind mode
    if addon.KeyBindingModule and addon.KeyBindingModule.enabled and LibStub and LibStub("LibKeyBound-1.0") then
        local LibKeyBound = LibStub("LibKeyBound-1.0")
        if LibKeyBound:IsShown() then
            return -- Skip updates during keybinding mode
        end
    end
    
	if not button then return; end
	local name = button:GetName();
	if name:find('MultiCast') then return; end
	button:SetNormalTexture(config.assets.normal);
end

function addon.RefreshButtons()
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't refresh buttons during combat to avoid taint
    if InCombatLockdown() then 
        ButtonsModule.pendingRefresh = true
        return 
    end
    
    local db = GetButtonsConfig()
    if not db then return end

    for button in addon.buttons_iterator() do
        if button and button.background then
            local buttonName = button:GetName()
            if buttonName then
                local isMainActionButton = buttonName:match("^ActionButton%d+$")

                -- show/hide action backgrounds
                if db.only_actionbackground and not isMainActionButton then
                    button.background:Hide()
                else
                    button.background:Show()
                end

                -- update hotkeys and range indicators
                pcall(actionbuttons_hotkey, button)

                -- handle macro text
                local macros = _G[buttonName .. 'Name']
                if macros and db.macros then
                    if db.macros.show then
                        macros:Show()
                    else
                        macros:Hide()
                    end
                    if db.macros.color then macros:SetVertexColor(unpack(db.macros.color)) end
                    if db.macros.font then macros:SetFont(unpack(db.macros.font)) end
                end

                -- handle count text
                local count = _G[buttonName .. 'Count']
                if count and db.count then
                    count:SetAlpha(db.count.show and 1 or 0)
                end

                -- handle border styling and equipped state
                local border = _G[buttonName .. 'Border']
                if border then
                    if db.border_color then
                        border:SetVertexColor(unpack(db.border_color))
                    end
                    border:SetAlpha(IsEquippedAction(button.action) and 1 or 0)
                end

                ActionButton_Update(button)
            end
        end
    end
end

-- ============================================================================
-- TEMPLATE FUNCTIONS
-- ============================================================================

-- setup vehicle action buttons
function addon.vehiclebuttons_template()
    if not IsModuleEnabled() then return end
    
	if UnitHasVehicleUI('player') then
		for index=1, VEHICLE_MAX_ACTIONBUTTONS do
			main_buttons(_G['VehicleMenuBarActionButton'..index])
		end
	end
end

-- setup possess buttons
function addon.possessbuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_POSSESS_SLOTS do
		additional_buttons(_G['PossessButton'..index])
	end
end

-- setup pet action buttons
function addon.petbuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_PET_ACTION_SLOTS do
		additional_buttons(_G['PetActionButton'..index])
	end
end

-- setup stance/shapeshift buttons
function addon.stancebuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_SHAPESHIFT_SLOTS do
		additional_buttons(_G['ShapeshiftButton'..index])
	end
end

-- ============================================================================
-- HOOKS MANAGEMENT
-- ============================================================================

local function SetupHooks()
    if ButtonsModule.hooked or not IsModuleEnabled() then return end
    
    hooksecurefunc('ActionButton_Update', actionbuttons_update)

    -- cache border color to avoid repeated config access
    local cachedBorderColor = nil

    hooksecurefunc('ActionButton_ShowGrid', function(button)
        if not IsModuleEnabled() then return end
        
        -- CRITICAL: Don't interfere with LibKeyBound during keybind mode
        if addon.KeyBindingModule and addon.KeyBindingModule.enabled and LibStub and LibStub("LibKeyBound-1.0") then
            local LibKeyBound = LibStub("LibKeyBound-1.0")
            if LibKeyBound:IsShown() then
                return -- Skip updates during keybinding mode
            end
        end
        
        if not button then return end
        
        local buttonName = button:GetName()
        if not buttonName then return end
        
        local db = GetButtonsConfig()
        
        -- cache border color on first access
        if not cachedBorderColor then
            cachedBorderColor = config.buttons.border_color
        end
        
        local normalTexture = _G[buttonName..'NormalTexture']
        if not normalTexture then return end
        
        if db and db.hide_main_bar_background then
            local wowAlwaysShow = GetCVar("alwaysShowActionBars") == "1"
            
            if buttonName:match("^ActionButton%d+$") then
                if wowAlwaysShow or HasAction(button.action) then
                    normalTexture:SetVertexColor(cachedBorderColor[1], cachedBorderColor[2], cachedBorderColor[3], cachedBorderColor[4])
                end
            else
                normalTexture:SetVertexColor(cachedBorderColor[1], cachedBorderColor[2], cachedBorderColor[3], cachedBorderColor[4])
            end
        else
            normalTexture:SetVertexColor(cachedBorderColor[1], cachedBorderColor[2], cachedBorderColor[3], cachedBorderColor[4])
        end
    end)
    
    ButtonsModule.hooked = true
end

-- ============================================================================
-- MODULE CONTROL FUNCTIONS
-- ============================================================================

function addon.RefreshButtonStyling()
    if IsModuleEnabled() then
        -- Apply styling
        SetupHooks()
        ApplyButtonStyling()
        
        -- Refresh all templates
        addon.vehiclebuttons_template()
        addon.possessbuttons_template()
        addon.petbuttons_template()
        addon.stancebuttons_template()
        
        -- Refresh button states
        addon.RefreshButtons()
    else
        -- Restore original buttons
        RestoreAllButtons()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function Initialize()
    if ButtonsModule.initialized then return end
    
    -- Only apply styling if module is enabled
    if IsModuleEnabled() then
        ApplyButtonStyling()
        SetupHooks()
    end
    
    ButtonsModule.initialized = true
end

-- Register initialization events
addon.package:RegisterEvents(function()
    if IsModuleEnabled() then
        addon.actionbuttons_grid(); 
        addon.RefreshButtons();
    end
    collectgarbage();
end,
    'PLAYER_LOGIN'
);

-- Auto-initialize when addon loads and handle post-combat refresh
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Execute pending refreshes after combat ends
        if IsModuleEnabled() and ButtonsModule.pendingRefresh then
            ButtonsModule.pendingRefresh = false
            addon.actionbuttons_grid()
            addon.RefreshButtons()
        end
    end
end)

-- Monitor alwaysShowActionBars CVar changes with proper event (no more constant timer)
local cvarFrame = CreateFrame("Frame")
cvarFrame:RegisterEvent("CVAR_UPDATE")
cvarFrame:SetScript("OnEvent", function(self, event, cvarName)
    if not IsModuleEnabled() then return end
    
    -- Only react to the specific CVar we care about
    if event == "CVAR_UPDATE" and cvarName == "alwaysShowActionBars" then
        -- Execute immediately - no timer needed
        addon.actionbuttons_grid()
        
        -- Refresh main bar background
        if MainMenuBarMixin and MainMenuBarMixin.update_main_bar_background then
            MainMenuBarMixin:update_main_bar_background()
        end
    end
end)