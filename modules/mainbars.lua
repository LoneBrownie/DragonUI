local addon = select(2,...);
local config = addon.config;
local event = addon.package;
local do_action = addon.functions;
local select = select;
local pairs = pairs;
local ipairs = ipairs;
local format = string.format;
local UIParent = UIParent;
local hooksecurefunc = hooksecurefunc;
local UnitFactionGroup = UnitFactionGroup;
local _G = getfenv(0);

-- constants
local faction = UnitFactionGroup('player');
local old = (config.style.xpbar == 'old');
local new = (config.style.xpbar == 'new');
local MainMenuBarMixin = {};
local pUiMainBar = CreateFrame(
	'Frame',
	'pUiMainBar',
	UIParent,
	'MainMenuBarUiTemplate'
);

local pUiMainBarArt = CreateFrame(
	'Frame',
	'pUiMainBarArt',
	pUiMainBar
);
pUiMainBar:SetScale(config.mainbars.scale_actionbar);
pUiMainBarArt:SetFrameStrata('HIGH');
pUiMainBarArt:SetFrameLevel(pUiMainBar:GetFrameLevel() + 4);
pUiMainBarArt:SetAllPoints(pUiMainBar);

local function UpdateGryphonStyle()
    -- ensure gryphon elements exist before modification
    if not MainMenuBarLeftEndCap or not MainMenuBarRightEndCap then return end
    
    -- get current style settings
    local db_style = addon.db and addon.db.profile and addon.db.profile.style
    if not db_style then db_style = config.style end

    local faction = UnitFactionGroup('player')

    if db_style.gryphons == 'old' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -85, -22)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 84, -22)
        MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-left', true)
        MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-right', true)
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    elseif db_style.gryphons == 'new' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -95, -23)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 95, -23)
        if faction == 'Alliance' then
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-right', true)
        else
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-right', true)
        end
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    elseif db_style.gryphons == 'flying' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -80, -21)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 80, -21)
        MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-left', true)
        MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-right', true)
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    else
        MainMenuBarLeftEndCap:Hide()
        MainMenuBarRightEndCap:Hide()
    end
end

function MainMenuBarMixin:actionbutton_setup()
	for _,obj in ipairs({MainMenuBar:GetChildren(),MainMenuBarArtFrame:GetChildren()}) do
		obj:SetParent(pUiMainBar)
	end
	
	for index=1, NUM_ACTIONBAR_BUTTONS do
		pUiMainBar:SetFrameRef('ActionButton'..index, _G['ActionButton'..index])
	end
	
	for index=1, NUM_ACTIONBAR_BUTTONS -1 do
		local ActionButtons = _G['ActionButton'..index]
		do_action.SetThreeSlice(ActionButtons);
	end
	
	for index=2, NUM_ACTIONBAR_BUTTONS do
		local ActionButtons = _G['ActionButton'..index]
		ActionButtons:SetParent(pUiMainBar)
		ActionButtons:SetClearPoint('LEFT', _G['ActionButton'..(index-1)], 'RIGHT', 7, 0)
		
		local BottomLeftButtons = _G['MultiBarBottomLeftButton'..index]
		BottomLeftButtons:SetClearPoint('LEFT', _G['MultiBarBottomLeftButton'..(index-1)], 'RIGHT', 7, 0)
		
		local BottomRightButtons = _G['MultiBarBottomRightButton'..index]
		BottomRightButtons:SetClearPoint('LEFT', _G['MultiBarBottomRightButton'..(index-1)], 'RIGHT', 7, 0)
		
		local BonusActionButtons = _G['BonusActionButton'..index]
		BonusActionButtons:SetClearPoint('LEFT', _G['BonusActionButton'..(index-1)], 'RIGHT', 7, 0)
	end
end

function MainMenuBarMixin:actionbar_art_setup()
    -- setup art frames
    MainMenuBarArtFrame:SetParent(pUiMainBar)
    for _,art in pairs({MainMenuBarLeftEndCap, MainMenuBarRightEndCap}) do
        art:SetParent(pUiMainBarArt)
        art:SetDrawLayer('ARTWORK')
    end
    
    -- apply background settings
    self:update_main_bar_background()
    
    -- apply gryphon styling
    UpdateGryphonStyle()
end

function MainMenuBarMixin:update_main_bar_background()
    local alpha = (addon.db and addon.db.profile and addon.db.profile.buttons and addon.db.profile.buttons.hide_main_bar_background) and 0 or 1
    
    -- handle button background textures
    for i = 1, NUM_ACTIONBAR_BUTTONS do
        local button = _G["ActionButton" .. i]
        if button then
            if button.NormalTexture then button.NormalTexture:SetAlpha(alpha) end
            for j = 1, button:GetNumRegions() do
                local region = select(j, button:GetRegions())
                if region and region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" and region ~= button:GetNormalTexture() then
                    region:SetAlpha(alpha)
                end
            end
        end
    end
    
    
    if pUiMainBar then
        -- hide loose textures within pUiMainBar
        for i = 1, pUiMainBar:GetNumRegions() do
            local region = select(i, pUiMainBar:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                local texPath = region:GetTexture()
                if texPath and not string.find(texPath, "ICON") then
                    region:SetAlpha(alpha)
                end
            end
        end

        -- hide child frame textures with protection for UI elements
        for i = 1, pUiMainBar:GetNumChildren() do
            local child = select(i, pUiMainBar:GetChildren())
            local name = child and child:GetName()
            
            -- protect important UI elements from being hidden
            if child and name ~= "pUiMainBarArt" 
                    and not string.find(name or "", "ActionButton")
                    and name ~= "MainMenuExpBar" 
                    and name ~= "ReputationWatchBar"
                    and name ~= "MultiBarBottomLeft"
                    and name ~= "MultiBarBottomRight"
                    and name ~= "MicroButtonAndBagsBar"
                    and not string.find(name or "", "MicroButton")
                    and not string.find(name or "", "Bag")
                    and name ~= "CharacterMicroButton"
                    and name ~= "SpellbookMicroButton"
                    and name ~= "TalentMicroButton"
                    and name ~= "AchievementMicroButton"
                    and name ~= "bagsFrame"
                    and name ~= "MainMenuBarBackpackButton"
                    and name ~= "QuestLogMicroButton"
                    and name ~= "SocialsMicroButton"
                    and name ~= "PVPMicroButton"
                    and name ~= "LFGMicroButton"
                    and name ~= "MainMenuMicroButton"
                    and name ~= "HelpMicroButton" then
                
                for j = 1, child:GetNumRegions() do
                    local region = select(j, child:GetRegions())
                    if region and region:GetObjectType() == "Texture" then
                        region:SetAlpha(alpha)
                    end
                end
            end
        end
    end
end


function MainMenuBarMixin:actionbar_setup()
	ActionButton1:SetParent(pUiMainBar)
	ActionButton1:SetClearPoint('BOTTOMLEFT', pUiMainBar, 2, 2)
	
	
	if config.buttons.pages.show then
		do_action.SetNumPagesButton(ActionBarUpButton, pUiMainBarArt, 'pageuparrow', 8)
		do_action.SetNumPagesButton(ActionBarDownButton, pUiMainBarArt, 'pagedownarrow', -14)
		
		MainMenuBarPageNumber:SetParent(pUiMainBarArt)
		MainMenuBarPageNumber:SetClearPoint('CENTER', ActionBarDownButton, -1, 12)
		local pagesFont = config.buttons.pages.font
		MainMenuBarPageNumber:SetFont(pagesFont[1], pagesFont[2], pagesFont[3])
		MainMenuBarPageNumber:SetShadowColor(0, 0, 0, 1)
		MainMenuBarPageNumber:SetShadowOffset(1.2, -1.2)
		MainMenuBarPageNumber:SetDrawLayer('OVERLAY', 7)
	else
		ActionBarUpButton:Hide();
		ActionBarDownButton:Hide();
		MainMenuBarPageNumber:Hide();
	end
	-- ✅ REMOVED: Bottom bars no longer parented to mainbar for independent positioning
	-- MultiBarBottomLeft:SetParent(pUiMainBar)
	-- MultiBarBottomRight:SetParent(pUiMainBar)
	MultiBarBottomRight:EnableMouse(false)
	-- ✅ REMOVED: Bottom bars positioning handled by centralized system
	-- MultiBarBottomRight:SetClearPoint('BOTTOMLEFT', MultiBarBottomLeftButton1, 'TOPLEFT', 0, 8)
	-- MultiBarRight:SetClearPoint('TOPRIGHT', UIParent, 'RIGHT', -6, (Minimap:GetHeight() * 1.3))
	MultiBarRight:SetScale(config.mainbars.scale_rightbar)
	MultiBarLeft:SetScale(config.mainbars.scale_leftbar)
    if MultiBarBottomLeft then MultiBarBottomLeft:SetScale(config.mainbars.scale_bottomleft or 0.9) end
    if MultiBarBottomRight then MultiBarBottomRight:SetScale(config.mainbars.scale_bottomright or 0.9) end

	-- MultiBarLeft:SetParent(UIParent)
	-- MultiBarLeft:SetClearPoint('TOPRIGHT', MultiBarRight, 'TOPLEFT', -7, 0)
end

function addon.PositionActionBars()
    if InCombatLockdown() then return end
    
    local db = addon.db and addon.db.profile and addon.db.profile.mainbars
    if not db then return end

    -- ✅ ONLY HANDLE ORIENTATION - POSITION IS HANDLED BY CENTRALIZED SYSTEM
    
    -- Configure MultiBarRight orientation
    if MultiBarRight then
        if db.right.horizontal then
            -- Horizontal mode: buttons go from left to right
            for i = 2, 12 do
                local button = _G["MultiBarRightButton" .. i]
                if button then
                    button:ClearAllPoints()
                    button:SetPoint("LEFT", _G["MultiBarRightButton" .. (i-1)], "RIGHT", 7, 0)
                end
            end
        else
            -- Vertical mode: buttons go from top to bottom (default)
            for i = 2, 12 do
                local button = _G["MultiBarRightButton" .. i]
                if button then
                    button:ClearAllPoints()
                    button:SetPoint("TOP", _G["MultiBarRightButton" .. (i-1)], "BOTTOM", 0, -7)
                end
            end
        end
    end

    -- Configure MultiBarLeft orientation
    if MultiBarLeft then
        if db.left.horizontal then
            -- Horizontal mode: buttons go from left to right
            for i = 2, 12 do
                local button = _G["MultiBarLeftButton" .. i]
                if button then
                    button:ClearAllPoints()
                    button:SetPoint("LEFT", _G["MultiBarLeftButton" .. (i-1)], "RIGHT", 7, 0)
                end
            end
        else
            -- Vertical mode: buttons go from top to bottom (default)
            for i = 2, 12 do
                local button = _G["MultiBarLeftButton" .. i]
                if button then
                    button:ClearAllPoints()
                    button:SetPoint("TOP", _G["MultiBarLeftButton" .. (i-1)], "BOTTOM", 0, -7)
                end
            end
        end
    end
end


function MainMenuBarMixin:statusbar_setup()
	for _,bar in pairs({MainMenuExpBar,ReputationWatchStatusBar}) do
		bar:GetStatusBarTexture():SetDrawLayer('BORDER')
		bar.status = bar:CreateTexture(nil, 'ARTWORK')
		if old then
			bar:SetSize(545, 10)
			bar.status:SetPoint('CENTER', 0, -1)
			bar.status:SetSize(545, 14)
			bar.status:set_atlas('ui-hud-experiencebar')
		elseif new then
			bar:SetSize(537, 10)
			bar.status:SetPoint('CENTER', 0, -2)
			bar.status:set_atlas('ui-hud-experiencebar-round', true)
			ReputationWatchStatusBar:SetStatusBarTexture(addon._dir..'statusbarfill.tga')
			ReputationWatchStatusBarBackground:set_atlas('ui-hud-experiencebar-background', true)
			ExhaustionTick:GetNormalTexture():set_atlas('ui-hud-experiencebar-frame-pip')
			ExhaustionTick:GetHighlightTexture():set_atlas('ui-hud-experiencebar-frame-pip-mouseover')
			ExhaustionTick:GetHighlightTexture():SetBlendMode('ADD')
		else
			bar.status:Hide()
		end
	end
	
	-- ✅ REMOVED: Position now handled by RetailUI container system
	-- MainMenuExpBar:SetClearPoint('BOTTOM', UIParent, 0, 6)
	MainMenuExpBar:SetFrameLevel(10)
	ReputationWatchBar:SetParent(pUiMainBar)
	ReputationWatchBar:SetFrameLevel(10)
	ReputationWatchBar:SetWidth(ReputationWatchStatusBar:GetWidth())
	ReputationWatchBar:SetHeight(ReputationWatchStatusBar:GetHeight())
	
	MainMenuBarExpText:SetParent(MainMenuExpBar)
	MainMenuBarExpText:SetClearPoint('CENTER', MainMenuExpBar, 'CENTER', 0, old and 0 or 1)
	
	if new then
		for _,obj in pairs{MainMenuExpBar:GetRegions()} do 
			if obj:GetObjectType() == 'Texture' and obj:GetDrawLayer() == 'BACKGROUND' then
				obj:set_atlas('ui-hud-experiencebar-background', true)
			end
		end
	end
end

event:RegisterEvents(function(self)
	self:UnregisterEvent('PLAYER_ENTERING_WORLD');
	local exhaustionStateID = GetRestState();
	ExhaustionTick:SetParent(pUiMainBar);
	ExhaustionTick:SetFrameLevel(MainMenuExpBar:GetFrameLevel() +2);
	if new then
		ExhaustionLevelFillBar:SetHeight(MainMenuExpBar:GetHeight());
		ExhaustionLevelFillBar:set_atlas('ui-hud-experiencebar-fill-prediction');
		ExhaustionTick:SetSize(10, 14);
		ExhaustionTick:SetClearPoint('CENTER', ExhaustionLevelFillBar, 'RIGHT', 0, 2);

		MainMenuExpBar:SetStatusBarTexture(addon._dir..'uiexperiencebar');
		MainMenuExpBar:SetStatusBarColor(1, 1, 1, 1);
		if exhaustionStateID == 1 then
			ExhaustionTick:Show();
			MainMenuExpBar:GetStatusBarTexture():SetTexCoord(574/2048, 1137/2048, 34/64, 43/64);
			ExhaustionLevelFillBar:SetVertexColor(0.0, 0, 1, 0.45);
		elseif exhaustionStateID == 2 then
			MainMenuExpBar:GetStatusBarTexture():SetTexCoord(1/2048, 570/2048, 42/64, 51/64);
			ExhaustionLevelFillBar:SetVertexColor(0.58, 0.0, 0.55, 0.45);
		end
	else
		if exhaustionStateID == 1 then
			ExhaustionTick:Show();
		end
	end
end,
	'PLAYER_ENTERING_WORLD',
	'UPDATE_EXHAUSTION'
);



hooksecurefunc('ReputationWatchBar_Update',function()
	local name = GetWatchedFactionInfo();
	if name then
		local abovexp = config.xprepbar.repbar_abovexp_offset;
		local default = config.xprepbar.repbar_offset;
		ReputationWatchBar:SetClearPoint('BOTTOM', UIParent, 0, MainMenuExpBar:IsShown() and abovexp or default);
		ReputationWatchBarOverlayFrame:SetClearPoint('BOTTOM', UIParent, 0, MainMenuExpBar:IsShown() and abovexp or default);
		ReputationWatchStatusBar:SetHeight(10)
		ReputationWatchStatusBar:SetClearPoint('TOPLEFT', ReputationWatchBar, 0, 3)
		ReputationWatchStatusBarText:SetClearPoint('CENTER', ReputationWatchStatusBar, 'CENTER', 0, old and 0 or 1);
		ReputationWatchStatusBarBackground:SetAllPoints(ReputationWatchStatusBar)
	end
end)






local MainMenuExpBar = _G["MainMenuExpBar"]
local ReputationWatchBar = _G["ReputationWatchBar"]

for _,bar in pairs({MainMenuExpBar, ReputationWatchBar}) do
    if bar then
        bar:HookScript('OnShow',function()
            if not InCombatLockdown() and not (addon.EditorMode and addon.EditorMode:IsActive()) then
                addon.PositionActionBars() -- ✅ Usar la nueva función
            end
        end);
        bar:HookScript('OnHide',function()
            if not InCombatLockdown() and not (addon.EditorMode and addon.EditorMode:IsActive()) then
                addon.PositionActionBars() -- ✅ Usar la nueva función
            end
        end);
    end
end;



function addon.RefreshRepBarPosition()
	if ReputationWatchBar_Update then
		ReputationWatchBar_Update()
	end
end

-- update position for secondary action bars - LEGACY FUNCTION
-- ✅ NOTE: This function is kept for compatibility but bottom bars are now handled by centralized system
function addon.RefreshUpperActionBarsPosition()
    if not MultiBarBottomLeftButton1 or not MultiBarBottomRight then return end

    -- calculate offset based on background visibility
    local yOffset1, yOffset2
    if addon.db and addon.db.profile.buttons.hide_main_bar_background then
        -- values when background is hidden
        yOffset1 = 45
        yOffset2 = 8
    else
        -- default values when background is visible
        yOffset1 = 48
        yOffset2 = 8
    end

    -- ✅ REMOVED: Bottom bars positioning now handled by centralized system
    -- MultiBarBottomLeftButton1:SetClearPoint('BOTTOMLEFT', ActionButton1, 'BOTTOMLEFT', 0, yOffset1)
    -- MultiBarBottomRight:SetClearPoint('BOTTOMLEFT', MultiBarBottomLeftButton1, 'TOPLEFT', 0, yOffset2)
    
    -- ✅ REMOVED: Bottom bars are now completely independent from mainbar
    -- MultiBarBottomLeftButton1:SetClearPoint('BOTTOMLEFT', ActionButton1, 'BOTTOMLEFT', 0, yOffset1)
end

function MainMenuBarMixin:initialize()
	self:actionbutton_setup();
	self:actionbar_setup();
	self:actionbar_art_setup();
	self:statusbar_setup();
end
addon.pUiMainBar = pUiMainBar;
MainMenuBarMixin:initialize();

-- ACTION BAR SYSTEM - Based on RetailUI Pattern
-- Simple and clean approach for action bar management

-- Store action bar container frames
addon.ActionBarFrames = {
    mainbar = nil,
    rightbar = nil,
    leftbar = nil,
    bottombarleft = nil,
    bottombarright = nil,
    xpbar = nil
}

-- Create action bar container frames
local function CreateActionBarFrames()
    -- Main bar - create a NEW container frame instead of using pUiMainBar directly
    addon.ActionBarFrames.mainbar = addon.CreateUIFrame(pUiMainBar:GetWidth(), pUiMainBar:GetHeight(), "MainBar")
    
    -- Create other action bar containers
    addon.ActionBarFrames.rightbar = addon.CreateUIFrame(40, 490, "RightBar")
    addon.ActionBarFrames.leftbar = addon.CreateUIFrame(40, 490, "LeftBar")
    addon.ActionBarFrames.bottombarleft = addon.CreateUIFrame(490, 40, "BottomBarLeft")
    addon.ActionBarFrames.bottombarright = addon.CreateUIFrame(490, 40, "BottomBarRight")
    
    -- Create experience bar container
    addon.ActionBarFrames.xpbar = addon.CreateUIFrame(545, 20, "XPBar")
end

-- Position action bars to their container frames (initialization only - safe during addon load)
local function PositionActionBarsToContainers_Initial()
    -- This function is ONLY called during ADDON_LOADED
    -- It's safe to position Blizzard frames during initial load, even in combat
    
    -- Position main bar - anchor pUiMainBar to its container
    if pUiMainBar and addon.ActionBarFrames.mainbar then
        pUiMainBar:SetParent(UIParent)
        pUiMainBar:ClearAllPoints()
        pUiMainBar:SetPoint("CENTER", addon.ActionBarFrames.mainbar, "CENTER")
    end
    
    -- Position right bar
    if MultiBarRight and addon.ActionBarFrames.rightbar then
        MultiBarRight:SetParent(UIParent)
        MultiBarRight:ClearAllPoints()
        MultiBarRight:SetPoint("CENTER", addon.ActionBarFrames.rightbar, "CENTER")
    end
    
    -- Position left bar
    if MultiBarLeft and addon.ActionBarFrames.leftbar then
        MultiBarLeft:SetParent(UIParent)
        MultiBarLeft:ClearAllPoints()
        MultiBarLeft:SetPoint("CENTER", addon.ActionBarFrames.leftbar, "CENTER")
    end
    
    -- Position bottom left bar
    if MultiBarBottomLeft and addon.ActionBarFrames.bottombarleft then
        MultiBarBottomLeft:SetParent(UIParent)
        MultiBarBottomLeft:ClearAllPoints()
        MultiBarBottomLeft:SetPoint("CENTER", addon.ActionBarFrames.bottombarleft, "CENTER")
    end
    
    -- Position bottom right bar
    if MultiBarBottomRight and addon.ActionBarFrames.bottombarright then
        MultiBarBottomRight:SetParent(UIParent)
        MultiBarBottomRight:ClearAllPoints()
        MultiBarBottomRight:SetPoint("CENTER", addon.ActionBarFrames.bottombarright, "CENTER")
    end
    
    -- Position experience bar
    if MainMenuExpBar and addon.ActionBarFrames.xpbar then
        MainMenuExpBar:SetParent(UIParent)
        MainMenuExpBar:ClearAllPoints()
        MainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.xpbar, "CENTER")
    end
end

-- Position action bars to their container frames
local function PositionActionBarsToContainers()
    -- Only proceed if not in combat to avoid taint
    if InCombatLockdown() then return end
    
    -- Use the initial function for runtime positioning
    PositionActionBarsToContainers_Initial()
end

-- Apply saved positions from database
local function ApplyActionBarPositions()
    -- Safe containers can be positioned anytime - no combat check needed
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then return end
    
    local widgets = addon.db.profile.widgets
    
    -- Apply mainbar container position (safe to do anytime)
    if widgets.mainbar and addon.ActionBarFrames.mainbar then
        local config = widgets.mainbar
        if config.anchor then
            addon.ActionBarFrames.mainbar:ClearAllPoints()
            addon.ActionBarFrames.mainbar:SetPoint(config.anchor, UIParent, config.anchor, config.posX or 0, config.posY or 75)
        end
    end
    
    -- Apply other bar positions
    local barConfigs = {
        {frame = addon.ActionBarFrames.rightbar, config = widgets.rightbar, default = {"RIGHT", -10, -70}},
        {frame = addon.ActionBarFrames.leftbar, config = widgets.leftbar, default = {"RIGHT", -45, -70}},
        {frame = addon.ActionBarFrames.bottombarleft, config = widgets.bottombarleft, default = {"BOTTOM", 0, 120}},
        {frame = addon.ActionBarFrames.bottombarright, config = widgets.bottombarright, default = {"BOTTOM", 0, 160}},
        {frame = addon.ActionBarFrames.xpbar, config = widgets.xpbar, default = {"BOTTOM", 0, 6}}
    }
    
    for _, barData in ipairs(barConfigs) do
        if barData.frame and barData.config then
            local config = barData.config
            local anchor = config.anchor or barData.default[1]
            local posX = config.posX or barData.default[2]
            local posY = config.posY or barData.default[3]
            
            barData.frame:ClearAllPoints()
            barData.frame:SetPoint(anchor, UIParent, anchor, posX, posY)
        elseif barData.frame then
            -- Apply default position
            local default = barData.default
            barData.frame:ClearAllPoints()
            barData.frame:SetPoint(default[1], UIParent, default[1], default[2], default[3])
        end
    end
end

-- Register action bar frames with the centralized system
local function RegisterActionBarFrames()
    -- Register all action bar frames
    local frameRegistrations = {
        {name = "mainbar", frame = addon.ActionBarFrames.mainbar, blizzardFrame = MainMenuBar, configPath = {"widgets", "mainbar"}},
        {name = "rightbar", frame = addon.ActionBarFrames.rightbar, blizzardFrame = MultiBarRight, configPath = {"widgets", "rightbar"}},
        {name = "leftbar", frame = addon.ActionBarFrames.leftbar, blizzardFrame = MultiBarLeft, configPath = {"widgets", "leftbar"}},
        {name = "bottombarleft", frame = addon.ActionBarFrames.bottombarleft, blizzardFrame = MultiBarBottomLeft, configPath = {"widgets", "bottombarleft"}},
        {name = "bottombarright", frame = addon.ActionBarFrames.bottombarright, blizzardFrame = MultiBarBottomRight, configPath = {"widgets", "bottombarright"}},
        {name = "xpbar", frame = addon.ActionBarFrames.xpbar, blizzardFrame = MainMenuExpBar, configPath = {"widgets", "xpbar"}}
    }
    
    for _, registration in ipairs(frameRegistrations) do
        if registration.frame then
            addon:RegisterEditableFrame({
                name = registration.name,
                frame = registration.frame,
                blizzardFrame = registration.blizzardFrame,
                configPath = registration.configPath,
                module = addon.MainBars
            })
        end
    end
end

-- Hook drag events to ensure action bars follow their containers
local function SetupActionBarDragHandlers()
    -- Add drag end handlers to reposition action bars
    for name, frame in pairs(addon.ActionBarFrames) do
        if frame and name ~= "mainbar" then
            frame:HookScript("OnDragStop", function(self)
                addon.core:ScheduleTimer(function() 
                    -- RetailUI Pattern: Only reposition if not in combat
                    PositionActionBarsToContainers()
                end, 0.1)
            end)
        end
    end
end

-- Initialize action bar system
local function InitializeActionBarSystem()
    CreateActionBarFrames()
    ApplyActionBarPositions()
    RegisterActionBarFrames()
    
    -- ALWAYS position action bars immediately during addon load (RetailUI pattern)
    -- This is safe during ADDON_LOADED event, even in combat
    PositionActionBarsToContainers_Initial()
    
    if InCombatLockdown() then
        print("|cff00ff00DragonUI:|r Action bars positioned during combat reload")
    end
    
    -- Set up drag handlers after a short delay
    addon.core:ScheduleTimer(function() SetupActionBarDragHandlers() end, 0.2)
end
-- Update action bar positions from database (similar to RetailUI:UpdateWidgets)
function addon.UpdateActionBarWidgets()
    -- Safe containers can be positioned anytime - no combat check needed
    ApplyActionBarPositions()
    
    -- Only position Blizzard frames if not in combat
    if not InCombatLockdown() then
        PositionActionBarsToContainers()
    end
end

-- Event handler for addon initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- When combat ends
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Initialize action bar system immediately (RetailUI pattern)
        -- This ensures frames are positioned correctly even during combat reload
        InitializeActionBarSystem()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Reposition Blizzard frames when combat ends (for runtime changes)
        addon.core:ScheduleTimer(function() 
            ApplyActionBarPositions() -- Ensure containers are in correct position
            PositionActionBarsToContainers() -- Position Blizzard frames to containers
            print("|cff00ff00DragonUI:|r Action bars repositioned after combat")
        end, 0.1)
    end
end)

-- configuration refresh function
function addon.RefreshMainbars()
    if not pUiMainBar then return end
    
    local db = addon.db and addon.db.profile
    if not db then return end
    
    local db_mainbars = db.mainbars
    local db_style = db.style
    local db_buttons = db.buttons
    
    -- Update scales
    pUiMainBar:SetScale(db_mainbars.scale_actionbar);
    if MultiBarLeft then MultiBarLeft:SetScale(db_mainbars.scale_leftbar); end
    if MultiBarRight then MultiBarRight:SetScale(db_mainbars.scale_rightbar); end
    if MultiBarBottomLeft then MultiBarBottomLeft:SetScale(db_mainbars.scale_bottomleft or 0.9); end     
    if MultiBarBottomRight then MultiBarBottomRight:SetScale(db_mainbars.scale_bottomright or 0.9); end 
    if VehicleMenuBar then VehicleMenuBar:SetScale(db_mainbars.scale_vehicle); end
    
    -- Update orientation (only - position handled by centralized system)
    addon.PositionActionBars()
    
    -- Update page buttons
    if db_buttons.pages.show then
        ActionBarUpButton:Show()
        ActionBarDownButton:Show()
        MainMenuBarPageNumber:Show()
    else
        ActionBarUpButton:Hide()
        ActionBarDownButton:Hide()
        MainMenuBarPageNumber:Hide()
    end
    
    -- Update backgrounds
    MainMenuBarMixin:update_main_bar_background()
    addon.RefreshUpperActionBarsPosition()
    
    -- Update grids and gryphons
    if addon.actionbuttons_grid then
        addon.actionbuttons_grid()
    end
    UpdateGryphonStyle()
    
    -- Update XP bar textures
    if MainMenuExpBar then 
        MainMenuExpBar:SetStatusBarTexture(db_style.xpbar == 'old' and "Interface\\MainMenuBar\\UI-XP-Bar" or "Interface\\MainMenuBar\\UI-ExperienceBar")
    end
    if ReputationWatchStatusBar then 
        ReputationWatchStatusBar:SetStatusBarTexture(db_style.xpbar == 'old' and "Interface\\MainMenuBar\\UI-XP-Bar" or "Interface\\MainMenuBar\\UI-ExperienceBar")
    end
    
    -- Update action bar positions
    addon.UpdateActionBarWidgets()
end

local function OnProfileChange()
    -- This function is called whenever the profile changes, resets, or is copied
    if addon.RefreshMainbars then
        addon.RefreshMainbars()
    end
end

local initializationFrame = CreateFrame("Frame")
initializationFrame:RegisterEvent("PLAYER_LOGIN")
initializationFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Ensure database is ready
        if not addon.db then return end

        -- Register profile change callbacks
        addon.db.RegisterCallback(addon, "OnProfileChanged", OnProfileChange)
        addon.db.RegisterCallback(addon, "OnProfileCopied", OnProfileChange)
        addon.db.RegisterCallback(addon, "OnProfileReset", OnProfileChange)
        
        -- Initial refresh
        OnProfileChange()

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Simple function to refresh mainbar position from database
function addon.RefreshMainbarPosition()
    -- Safe containers can be positioned anytime - no combat check needed
    if not addon.ActionBarFrames.mainbar or not addon.db or not addon.db.profile then return end
    
    local mainbarConfig = addon.db.profile.widgets.mainbar
    if mainbarConfig and mainbarConfig.anchor then
        addon.ActionBarFrames.mainbar:ClearAllPoints()
        addon.ActionBarFrames.mainbar:SetPoint(mainbarConfig.anchor or "BOTTOM", UIParent, mainbarConfig.anchor or "BOTTOM", mainbarConfig.posX or 0, mainbarConfig.posY or 75)
        
        -- Reposition Blizzard frame only if not in combat
        if not InCombatLockdown() and pUiMainBar then
            pUiMainBar:ClearAllPoints()
            pUiMainBar:SetPoint("CENTER", addon.ActionBarFrames.mainbar, "CENTER")
        end
    end
end

-- Simple function to refresh XP bar position from database
function addon.RefreshXpBarPosition()
    -- Safe containers can be positioned anytime - no combat check needed
    if not addon.ActionBarFrames.xpbar or not addon.db or not addon.db.profile then return end
    
    local xpbarConfig = addon.db.profile.widgets.xpbar
    if xpbarConfig and xpbarConfig.anchor then
        addon.ActionBarFrames.xpbar:ClearAllPoints()
        addon.ActionBarFrames.xpbar:SetPoint(xpbarConfig.anchor or "BOTTOM", UIParent, xpbarConfig.anchor or "BOTTOM", xpbarConfig.posX or 0, xpbarConfig.posY or 6)
        
        -- Reposition Blizzard frame only if not in combat
        if not InCombatLockdown() and MainMenuExpBar then
            MainMenuExpBar:ClearAllPoints()
            MainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.xpbar, "CENTER")
        end
    end
end

-- Force profile refresh
function addon.ForceProfileRefresh()
    OnProfileChange()
end

