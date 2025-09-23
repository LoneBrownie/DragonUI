local addon = select(2,...);
local config = addon.config;
local event = addon.package;
local class = addon._class;
local pUiMainBar = addon.pUiMainBar;
local unpack = unpack;
local select = select;
local pairs = pairs;
local _G = getfenv(0);

-- ============================================================================
-- STANCE MODULE FOR DRAGONUI
-- ============================================================================

-- Module state tracking
local StanceModule = {
    initialized = false,
    applied = false,
    originalStates = {},     -- Store original states for restoration
    registeredEvents = {},   -- Track registered events
    hooks = {},             -- Track hooked functions
    stateDrivers = {},      -- Track state drivers
    frames = {}             -- Track created frames
}

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.stance
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

-- ============================================================================
-- CONSTANTS AND VARIABLES
-- ============================================================================

-- const
local InCombatLockdown = InCombatLockdown;
local GetNumShapeshiftForms = GetNumShapeshiftForms;
local GetShapeshiftFormInfo = GetShapeshiftFormInfo;
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown;
local CreateFrame = CreateFrame;
local UIParent = UIParent;
local hooksecurefunc = hooksecurefunc;
local UnitAffectingCombat = UnitAffectingCombat;

-- WOTLK 3.3.5a Constants
local NUM_SHAPESHIFT_SLOTS = 10; -- Fixed value for 3.3.5a compatibility

local stance = {
	['DEATHKNIGHT'] = 'show',
	['DRUID'] = 'show',
	['PALADIN'] = 'show',
	['PRIEST'] = 'show',
	['ROGUE'] = 'show',
	['WARLOCK'] = 'show',
	['WARRIOR'] = 'show'
};

-- Module frames (created only when enabled)
local anchor, stancebar

-- Initialize MultiBar references
local MultiBarBottomLeft = _G["MultiBarBottomLeft"]
local MultiBarBottomRight = _G["MultiBarBottomRight"]

-- Initialization tracking (like RetailUI's petBarInitialized)
local stanceBarInitialized = false;
local initializationAttempts = 0;
local maxInitializationAttempts = 5;

-- Queue system to prevent multiple simultaneous updates
local updateQueue = {};
local isUpdating = false;

-- method update position using relative anchoring
local function stancebar_update()
    if not IsModuleEnabled() or not anchor then return end
    
	if not InCombatLockdown() and not UnitAffectingCombat('player') then
		-- Validate config exists before proceeding
		if not config or not config.additional or not config.additional.stance then
			-- Schedule retry if config isn't ready yet
			local retryFrame = CreateFrame("Frame");
			retryFrame:SetScript("OnUpdate", function(self)
				local elapsed = (self.elapsed or 0) + arg1;
				self.elapsed = elapsed;
				if elapsed > 1 then -- Wait 1 second before retry
					self:SetScript("OnUpdate", nil);
					if config and config.additional and config.additional.stance then
						QueueUpdate("config_retry");
					end
				end
			end);
			return;
		end
		
		-- Read config values dynamically each time
		local offsetX = config.additional.stance.x_position;
		local offsetY = config.additional.stance.y_offset or 0;  -- Additional Y offset for fine-tuning
		
		-- Validate frame still exists and is properly set up
		if not anchor or not anchor.SetPoint then
			return;
		end
		
		-- Check if Pet Bar exists and is visible first (stance should be above pet bar)
		local petBarHolder = _G["pUiPetBarHolder"];
		if petBarHolder and petBarHolder:IsShown() then
			-- Anchor above Pet Bar
			anchor:ClearAllPoints();
			anchor:SetPoint('BOTTOM', petBarHolder, 'TOP', offsetX, 5 + offsetY);
		else
			-- No Pet Bar, check if pretty_actionbar addon is loaded
			if IsAddOnLoaded('pretty_actionbar') and _G.pUiMainBar then
				-- Use pretty_actionbar's exact logic (same as pet bar)
				local mainBar = _G.pUiMainBar;
				
				-- Get fresh references to ensure they exist
				local leftBarFrame = _G["MultiBarBottomLeft"] or MultiBarBottomLeft;
				local rightBarFrame = _G["MultiBarBottomRight"] or MultiBarBottomRight;
				
				local leftbar = leftBarFrame and leftBarFrame:IsShown();
				local rightbar = rightBarFrame and rightBarFrame:IsShown();
				
				-- Values from configuration (compatible with pretty_actionbar)
				local nobar = 52;          -- Hardcoded optimal position for pretty_actionbar compatibility
				local leftbarOffset = config.additional.leftbar_offset or 90;  -- Offset when bottom left is shown  
				local rightbarOffset = config.additional.rightbar_offset or 40; -- Offset when bottom right is shown
				local leftOffset = nobar + leftbarOffset;   -- 142
				local rightOffset = nobar + rightbarOffset; -- 92
				
				anchor:ClearAllPoints();
				
				if leftbar and rightbar then
					-- Both bars shown, use leftOffset (positions above bottom right which is highest)
					anchor:SetPoint('TOPLEFT', mainBar, 'TOPLEFT', offsetX, leftOffset + offsetY);
				elseif leftbar then
					-- Only left bar shown, use rightOffset (lower position)
					anchor:SetPoint('TOPLEFT', mainBar, 'TOPLEFT', offsetX, rightOffset + offsetY);
				elseif rightbar then
					-- Only right bar shown, use leftOffset (higher position)
					anchor:SetPoint('TOPLEFT', mainBar, 'TOPLEFT', offsetX, leftOffset + offsetY);
				else
					-- No extra bars, use default position
					anchor:SetPoint('TOPLEFT', mainBar, 'TOPLEFT', offsetX, nobar + offsetY);
				end
			else
				-- Fallback to standard Blizzard frames (relative anchoring)
				local leftBarFrame = _G["MultiBarBottomLeft"] or MultiBarBottomLeft;
				local rightBarFrame = _G["MultiBarBottomRight"] or MultiBarBottomRight;
				
				local leftbar = leftBarFrame and leftBarFrame:IsShown();
				local rightbar = rightBarFrame and rightBarFrame:IsShown();
				local anchorFrame, anchorPoint, relativePoint, yOffset;
				
				if leftbar or rightbar then
					-- If extra bars are shown, anchor above the highest one
					if leftbar and rightbar then
						-- Both bars shown, bottom right is higher, so anchor to it
						anchorFrame = rightBarFrame;
					elseif leftbar then
						anchorFrame = leftBarFrame;
					else
						anchorFrame = rightBarFrame;
					end
					anchorPoint = 'TOP';
					relativePoint = 'BOTTOM';
					yOffset = 5;
				else
					-- No extra bars, anchor above main bar
					anchorFrame = pUiMainBar or MainMenuBar;
					anchorPoint = 'TOP';
					relativePoint = 'BOTTOM';
					yOffset = 5;
				end
				
				anchor:ClearAllPoints();
				anchor:SetPoint(relativePoint, anchorFrame, anchorPoint, offsetX, yOffset + offsetY);
			end
		end
	end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function ProcessUpdateQueue()
    if not IsModuleEnabled() then return end
    
	if isUpdating or InCombatLockdown() or UnitAffectingCombat('player') then
		return;
	end
	
	if #updateQueue > 0 then
		isUpdating = true;
		-- Clear queue first
		updateQueue = {};
		
		-- Safe update execution with additional protection
		if anchor and anchor.stancebar_update and not InCombatLockdown() then
			stancebar_update();
		end
		
		isUpdating = false;
	end
end

-- Queue an update request
local function QueueUpdate(reason)
    if not IsModuleEnabled() then return end
    
	table.insert(updateQueue, reason or "unknown");
	-- Process queue after a brief delay to batch updates
	local frame = CreateFrame("Frame");
	frame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil);
		ProcessUpdateQueue();
	end);
end

-- ============================================================================
-- POSITIONING FUNCTIONS
-- ============================================================================


-- ============================================================================
-- FRAME CREATION FUNCTIONS
-- ============================================================================

local function CreateStanceFrames()
    if StanceModule.frames.anchor or not IsModuleEnabled() then return end
    
    anchor = CreateFrame('Frame', 'pUiStanceHolder', pUiMainBar)
    -- Set initial position - will be updated by stancebar_update when config is ready
    anchor:SetPoint('TOPLEFT', UIParent, 'BOTTOM', 0, 105) -- Fallback position slightly above pet bar
    anchor:SetSize(37, 37)
    
    -- Assign the update method to the anchor frame
    anchor.stancebar_update = stancebar_update
    
    StanceModule.frames.anchor = anchor
    
    stancebar = CreateFrame('Frame', 'pUiStanceBar', anchor, 'SecureHandlerStateTemplate')
    stancebar:SetAllPoints(anchor)
    StanceModule.frames.stancebar = stancebar
    
    -- Expose globally for compatibility
    _G.pUiStanceBar = stancebar
    
    -- Apply initial positioning
    if config and config.additional and config.additional.stance then
        stancebar_update()
    end
end

-- ============================================================================
-- POSITIONING FUNCTIONS
-- ============================================================================

--



-- ============================================================================
-- STANCE BUTTON FUNCTIONS
-- ============================================================================

local function stancebutton_update()
    if not IsModuleEnabled() or not anchor then return end
    
	if not InCombatLockdown() then
		_G.ShapeshiftButton1:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
	end
end

local function stancebutton_position()
    if not IsModuleEnabled() or not stancebar or not anchor then return end
    
	-- Read config values dynamically
	local btnsize = config.additional.size;
	local space = config.additional.spacing;
	
	for index=1, NUM_SHAPESHIFT_SLOTS do
		local button = _G['ShapeshiftButton'..index]
		button:ClearAllPoints()
		button:SetParent(stancebar)
		button:SetSize(btnsize, btnsize)
		if index == 1 then
			button:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
		else
			local previous = _G['ShapeshiftButton'..index-1]
			button:SetPoint('LEFT', previous, 'RIGHT', space, 0)
		end
		local _,name = GetShapeshiftFormInfo(index)
		if name then
			button:Show()
		else
			button:Hide()
		end
	end
	
	-- Track state driver for cleanup
	StanceModule.stateDrivers.visibility = {frame = stancebar, state = 'visibility', condition = stance[class] or 'hide'}
	RegisterStateDriver(stancebar, 'visibility', stance[class] or 'hide')
	
	-- Track hook for cleanup
	if not StanceModule.hooks.ShapeshiftBar_Update then
	    StanceModule.hooks.ShapeshiftBar_Update = true
	    hooksecurefunc('ShapeshiftBar_Update', function()
		    if IsModuleEnabled() and not InCombatLockdown() and not UnitAffectingCombat('player') then
			    stancebutton_update()
		    end
	    end)
	end
end

local function stancebutton_updatestate()
    if not IsModuleEnabled() then return end
    
	local numForms = GetNumShapeshiftForms()
	local texture, name, isActive, isCastable;
	local button, icon, cooldown;
	local start, duration, enable;
	for index=1, NUM_SHAPESHIFT_SLOTS do
		button = _G['ShapeshiftButton'..index]
		icon = _G['ShapeshiftButton'..index..'Icon']
		if index <= numForms then
			texture, name, isActive, isCastable = GetShapeshiftFormInfo(index)
			icon:SetTexture(texture)
			cooldown = _G['ShapeshiftButton'..index..'Cooldown']
			if texture then
				cooldown:SetAlpha(1)
			else
				cooldown:SetAlpha(0)
			end
			start, duration, enable = GetShapeshiftFormCooldown(index)
			CooldownFrame_SetTimer(cooldown, start, duration, enable)
			if isActive then
				ShapeshiftBarFrame.lastSelected = button:GetID()
				button:SetChecked(1)
			else
				button:SetChecked(0)
			end
			if isCastable then
				icon:SetVertexColor(255/255, 255/255, 255/255)
			else
				icon:SetVertexColor(102/255, 102/255, 102/255)
			end
		end
	end
end

local function stancebutton_setup()
    if not IsModuleEnabled() then return end
    
	if InCombatLockdown() then return end
	for index=1, NUM_SHAPESHIFT_SLOTS do
		local button = _G['ShapeshiftButton'..index]
		local _, name = GetShapeshiftFormInfo(index)
		if name then
			button:Show()
		else
			button:Hide()
		end
	end
	stancebutton_updatestate();
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function OnEvent(self,event,...)
    if not IsModuleEnabled() then return end
    
	if GetNumShapeshiftForms() < 1 then return; end
	if event == 'PLAYER_LOGIN' then
		stancebutton_position();
	elseif event == 'UPDATE_SHAPESHIFT_FORMS' then
		stancebutton_setup();
	elseif event == 'PLAYER_ENTERING_WORLD' then
		self:UnregisterEvent('PLAYER_ENTERING_WORLD');
		if addon.stancebuttons_template then
		    addon.stancebuttons_template();
		end
	else
		stancebutton_updatestate();
	end
end

-- ============================================================================
-- INITIALIZATION FUNCTIONS
-- ============================================================================

-- Force stance bar initialization with single controlled initialization
local function ForceStanceBarInitialization()
    if not IsModuleEnabled() then return end
    
	if not InCombatLockdown() and not UnitAffectingCombat('player') then
		initializationAttempts = initializationAttempts + 1;
		
		if initializationAttempts > maxInitializationAttempts then
			return; -- Prevent infinite loops
		end
		
		if config and config.additional then
			-- Force button positioning
			if stancebutton_position then
				stancebutton_position()
			end
			-- Force anchor update
			if anchor and anchor.stancebar_update then
				stancebar_update()
			end
			-- Show the stance bar frame
			if stancebar then
				stancebar:Show()
			end
		end
	end
end

-- ============================================================================
-- APPLY/RESTORE FUNCTIONS
-- ============================================================================

local function ApplyStanceSystem()
    if StanceModule.applied or not IsModuleEnabled() then return end
    
    -- Create frames
    CreateStanceFrames()
    
    if not anchor or not stancebar then return end
    
    -- Register events
    local events = {
        'PLAYER_LOGIN',
        'PLAYER_ENTERING_WORLD',
        'UPDATE_SHAPESHIFT_FORMS',
        'UPDATE_SHAPESHIFT_USABLE',
        'UPDATE_SHAPESHIFT_COOLDOWN',
        'UPDATE_SHAPESHIFT_FORM',
        'ACTIONBAR_PAGE_CHANGED'
    }
    
    for _, eventName in ipairs(events) do
        stancebar:RegisterEvent(eventName)
        StanceModule.registeredEvents[eventName] = stancebar
    end
    stancebar:SetScript('OnEvent', OnEvent);
    
    -- Register update events through addon event system
    if event then
        event:RegisterEvents(function()
            QueueUpdate("initial_load");
        end, 'PLAYER_LOGIN','ADDON_LOADED');
        
        event:RegisterEvents(function()
            if not stanceBarInitialized then
                QueueUpdate("shapeshift_update");
                stanceBarInitialized = true;
            else
                QueueUpdate("shapeshift_change");
            end
        end, 'UPDATE_SHAPESHIFT_FORMS', 'UPDATE_SHAPESHIFT_FORM', 'PLAYER_ENTERING_WORLD');
        
        event:RegisterEvents(function()
            -- Force initialization after a short delay when player enters world
            local initFrame = CreateFrame("Frame")
            local elapsed = 0
            initFrame:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed >= 1.0 then -- Wait 1 second after entering world
                    self:SetScript("OnUpdate", nil)
                    -- Force initialization only once
                    ForceStanceBarInitialization()
                end
            end)
        end, 'PLAYER_ENTERING_WORLD');
    end
    
    -- Hook MultiBar show/hide events
    local leftBarFrame = _G["MultiBarBottomLeft"];
    local rightBarFrame = _G["MultiBarBottomRight"];
    
    for _,bar in pairs({leftBarFrame, rightBarFrame}) do
	    if bar then
		    bar:HookScript('OnShow',function()
			    if IsModuleEnabled() and not InCombatLockdown() and not UnitAffectingCombat('player') then
				    QueueUpdate("bar_show");
			    end
		    end);
		    bar:HookScript('OnHide',function()
			    if IsModuleEnabled() and not InCombatLockdown() and not UnitAffectingCombat('player') then
				    QueueUpdate("bar_hide");
			    end
		    end);
	    end
    end;
    
    -- Hook Blizzard functions
    if ShapeshiftBar_Update and not StanceModule.hooks.ShapeshiftBar_Update_main then
        StanceModule.hooks.ShapeshiftBar_Update_main = true
        hooksecurefunc('ShapeshiftBar_Update', function()
            if IsModuleEnabled() and not InCombatLockdown() and not UnitAffectingCombat('player') then
                QueueUpdate("shapeshift_bar_update");
            end
        end);
    end
    
    if ActionBar_UpdateState and not StanceModule.hooks.ActionBar_UpdateState then
        StanceModule.hooks.ActionBar_UpdateState = true
        hooksecurefunc('ActionBar_UpdateState', function()
            if IsModuleEnabled() and not InCombatLockdown() and not UnitAffectingCombat('player') then
                QueueUpdate("actionbar_state_update");
            end
        end);
    end
    
    -- Register with addon core if available
    if addon.core and addon.core.RegisterMessage then
        addon.core.RegisterMessage(addon, "DRAGONUI_READY", ForceStanceBarInitialization);
    end
    
    StanceModule.applied = true
end

local function RestoreStanceSystem()
    if not StanceModule.applied then return end
    
    -- Unregister all events
    for eventName, frame in pairs(StanceModule.registeredEvents) do
        if frame and frame.UnregisterEvent then
            frame:UnregisterEvent(eventName)
        end
    end
    StanceModule.registeredEvents = {}
    
    -- Unregister all state drivers
    for name, data in pairs(StanceModule.stateDrivers) do
        if data.frame then
            UnregisterStateDriver(data.frame, data.state)
        end
    end
    StanceModule.stateDrivers = {}
    
    -- Hide custom frames
    if anchor then anchor:Hide() end
    if stancebar then stancebar:Hide() end
    
    -- Reset stance button parents to default
    for index=1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton'..index]
        if button then
            button:SetParent(ShapeshiftBarFrame or UIParent)
            button:ClearAllPoints()
            -- Don't reset positions here - let Blizzard handle it
        end
    end
    
    -- Clear global reference
    _G.pUiStanceBar = nil
    
    -- Reset variables
    stanceBarInitialized = false
    initializationAttempts = 0
    updateQueue = {}
    isUpdating = false
    
    StanceModule.applied = false
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Enhanced refresh function with module control
function addon.RefreshStanceSystem()
    if IsModuleEnabled() then
        ApplyStanceSystem()
        -- Call original refresh for settings
        if addon.RefreshStance then
            addon.RefreshStance()
        end
    else
        RestoreStanceSystem()
    end
end

-- Original refresh function for configuration changes
function addon.RefreshStance()
    if not IsModuleEnabled() then return end
    
	if InCombatLockdown() or UnitAffectingCombat('player') then 
		return 
	end
	
	-- Ensure frames exist
	if not anchor or not stancebar then
	    return
	end
	
	-- Update button size and spacing
	local btnsize = config.additional.size;
	local space = config.additional.spacing;
	
	-- Reposition stance buttons
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		local button = _G["ShapeshiftButton"..i];
		if button then
			button:SetSize(btnsize, btnsize);
			-- Clear all points first
			button:ClearAllPoints();
			if i == 1 then
				button:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0);
			else
				local prevButton = _G["ShapeshiftButton"..(i-1)];
				if prevButton then
					button:SetPoint('LEFT', prevButton, 'RIGHT', space, 0);
				end
			end
		end
	end
	
	-- Update position using the positioning function
	stancebar_update();
end

-- Debug function for troubleshooting stance bar issues
function addon.DebugStanceBar()
    if not IsModuleEnabled() then
        
        return {enabled = false}
    end
    
	local info = {
		stanceBarInitialized = stanceBarInitialized,
		initializationAttempts = initializationAttempts,
		updateQueueLength = #updateQueue,
		isUpdating = isUpdating,
		inCombat = InCombatLockdown(),
		unitInCombat = UnitAffectingCombat('player'),
		configExists = (config and config.additional and config.additional.stance) and true or false,
		anchorExists = anchor and true or false,
		stanceBarExists = _G.pUiStanceBar and true or false,
		numShapeshiftForms = GetNumShapeshiftForms(),
		petBarVisible = _G.pUiPetBarHolder and _G.pUiPetBarHolder:IsShown() or false,
		leftBarVisible = (_G["MultiBarBottomLeft"] or MultiBarBottomLeft) and (_G["MultiBarBottomLeft"] or MultiBarBottomLeft):IsShown() or false,
		rightBarVisible = (_G["MultiBarBottomRight"] or MultiBarBottomRight) and (_G["MultiBarBottomRight"] or MultiBarBottomRight):IsShown() or false
	};
	
	
	for k, v in pairs(info) do
	
	end
	
	if anchor then
		local point, relativeTo, relativePoint, x, y = anchor:GetPoint();
	
	end
	
	return info;
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function Initialize()
    if StanceModule.initialized then return end
    
    -- Only apply if module is enabled
    if IsModuleEnabled() then
        ApplyStanceSystem()
    end
    
    StanceModule.initialized = true
end

-- Auto-initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Just mark as loaded, don't initialize yet
        self.addonLoaded = true
    elseif event == "PLAYER_LOGIN" and self.addonLoaded then
        -- Initialize after both addon is loaded and player is logged in
        Initialize()
        self:UnregisterAllEvents()
    end
end)