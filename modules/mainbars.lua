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
--  REMOVED: old and new xpbar constants will be handled by RetailUI pattern
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
                    and name ~= "HelpMicroButton"
                    and name ~= "MainMenuExpBar"
                    and name ~= "ReputationWatchBar" then
                
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
	--  REMOVED: Bottom bars no longer parented to mainbar for independent positioning
	-- MultiBarBottomLeft:SetParent(pUiMainBar)
	-- MultiBarBottomRight:SetParent(pUiMainBar)
	MultiBarBottomRight:EnableMouse(false)
	--  REMOVED: Bottom bars positioning handled by centralized system
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

    --  ONLY HANDLE ORIENTATION - POSITION IS HANDLED BY CENTRALIZED SYSTEM
    
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
    --  REMOVED: XP and Reputation bar setup will be handled by RetailUI pattern
    -- This function now only handles other status bars if needed
    
    -- Setup pet bar initial configuration
    if PetActionBarFrame then
        -- Ensure pet bar uses correct scale from config
        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if db and db.scale_petbar then
            PetActionBarFrame:SetScale(db.scale_petbar)
        elseif config.mainbars.scale_petbar then
            PetActionBarFrame:SetScale(config.mainbars.scale_petbar)
        end
        
        -- Enable mouse interaction
        PetActionBarFrame:EnableMouse(true)
    end
end

-- RetailUI Pattern: XP/Rep Bar Implementation (EXACT COPY)
local function ReplaceBlizzardRepExpBarFrame(frameBar)
    -- Experience Bar (RetailUI pattern - EXACT implementation)
    local mainMenuExpBar = MainMenuExpBar
    mainMenuExpBar:SetFrameStrata("LOW") -- RetailUI uses default/low strata
    mainMenuExpBar:ClearAllPoints()
    mainMenuExpBar:SetWidth(frameBar:GetWidth())
    --  CRITICAL: RetailUI does NOT set height OR scale here, only width

    -- Ensure the experience status bar matches the parent dimensions
    local expStatusBar = _G[mainMenuExpBar:GetName() .. "StatusBar"]
    if expStatusBar and expStatusBar ~= mainMenuExpBar then
        expStatusBar:SetParent(mainMenuExpBar)
        expStatusBar:SetAllPoints(mainMenuExpBar)
        expStatusBar:SetWidth(frameBar:GetWidth())
        --  CRITICAL: Also don't set height for status bar here
    end

    -- Process background regions (RetailUI pattern)
    for _, region in pairs { mainMenuExpBar:GetRegions() } do
        if region:GetObjectType() == 'Texture' and region:GetDrawLayer() == 'BACKGROUND' then
            SetAtlasTexture(region, 'ExperienceBar-Background')
        end
    end

    -- Exhaustion Level Bar
    local exhaustionLevelBar = ExhaustionLevelFillBar
    if exhaustionLevelBar then
        exhaustionLevelBar:SetHeight(frameBar:GetHeight())
        exhaustionLevelBar:SetWidth(frameBar:GetWidth()) -- Ensure width matches too
    end

    -- Experience Bar Border Texture (RetailUI pattern - EXACT)
    local borderTexture = MainMenuXPBarTexture0
    borderTexture:SetAllPoints(mainMenuExpBar)
    borderTexture:SetPoint("TOPLEFT", mainMenuExpBar, "TOPLEFT", -3, 3)
    borderTexture:SetPoint("BOTTOMRIGHT", mainMenuExpBar, "BOTTOMRIGHT", 3, -6)
    SetAtlasTexture(borderTexture, 'ExperienceBar-Border')

    -- Experience Bar Text
    local expText = MainMenuBarExpText
    expText:SetParent(mainMenuExpBar)
    expText:SetPoint("CENTER", mainMenuExpBar, "CENTER", 0, 2)
    expText:SetDrawLayer("OVERLAY", 7)
    expText:Show() -- Ensure text is visible

    -- Reputation Watch Bar (RetailUI pattern - EXACT)
    local repWatchBar = ReputationWatchBar
    if repWatchBar then
        --  CRITICAL FIX: Set parent to container and proper layering like RetailUI
        repWatchBar:SetParent(frameBar)
        repWatchBar:SetFrameStrata("LOW") -- RetailUI uses default/low strata
        repWatchBar:ClearAllPoints()
        repWatchBar:SetWidth(frameBar:GetWidth())
        repWatchBar:SetScale(0.9) --  CRITICAL: Apply same scale as experience bar

        local repStatusBar = ReputationWatchStatusBar
        if repStatusBar then
            repStatusBar:SetAllPoints(repWatchBar)
            repStatusBar:SetWidth(repWatchBar:GetWidth())
            --  CRITICAL: RetailUI does NOT call SetParent for repStatusBar
        end

        -- Reputation Background Texture (RetailUI pattern - EXACT)
        local backgroundTexture = _G[repStatusBar:GetName() .. "Background"]
        if backgroundTexture then
            backgroundTexture:SetAllPoints(repStatusBar)
            SetAtlasTexture(backgroundTexture, 'ExperienceBar-Background')
        end

        -- Reputation Border Textures (RetailUI pattern - EXACT)
        borderTexture = ReputationXPBarTexture0
        if borderTexture then
            borderTexture:SetAllPoints(repStatusBar)
            borderTexture:SetPoint("TOPLEFT", repStatusBar, "TOPLEFT", -3, 2)
            borderTexture:SetPoint("BOTTOMRIGHT", repStatusBar, "BOTTOMRIGHT", 3, -7)
            SetAtlasTexture(borderTexture, 'ExperienceBar-Border')
        end

        borderTexture = ReputationWatchBarTexture0
        if borderTexture then
            borderTexture:SetAllPoints(repStatusBar)
            borderTexture:SetPoint("TOPLEFT", repStatusBar, "TOPLEFT", -3, 2)
            borderTexture:SetPoint("BOTTOMRIGHT", repStatusBar, "BOTTOMRIGHT", 3, -7)
            SetAtlasTexture(borderTexture, 'ExperienceBar-Border')
        end
        
        -- Reputation Watch Bar Text (if exists)
        local repText = ReputationWatchBarText
        if repText then
            repText:SetParent(repWatchBar)
            repText:SetFrameLevel(repWatchBar:GetFrameLevel() + 10) -- Higher than bar
            repText:SetPoint("CENTER", repWatchBar, "CENTER", 0, 2)
            repText:SetDrawLayer("OVERLAY", 7)
            repText:Show() -- Ensure text is visible
        end
    end
end

-- RetailUI Pattern: Remove Blizzard Frames (EXACT COPY)
local function RemoveBlizzardFrames()
    local blizzFrames = {
        MainMenuBarPerformanceBar,
        MainMenuBarTexture0,
        MainMenuBarTexture1,
        MainMenuBarTexture2,
        MainMenuBarTexture3,
        MainMenuBarMaxLevelBar,
        ReputationXPBarTexture1,
        ReputationXPBarTexture2,
        ReputationXPBarTexture3,
        ReputationWatchBarTexture1,
        ReputationWatchBarTexture2,
        ReputationWatchBarTexture3,
        MainMenuXPBarTexture1,
        MainMenuXPBarTexture2,
        MainMenuXPBarTexture3,
        SlidingActionBarTexture0,
        SlidingActionBarTexture1,
        BonusActionBarTexture0,
        BonusActionBarTexture1,
        ShapeshiftBarLeft,
        ShapeshiftBarMiddle,
        ShapeshiftBarRight,
        PossessBackground1,
        PossessBackground2
    }

    for _, frame in pairs(blizzFrames) do
        if frame then
            frame:SetAlpha(0)
        end
    end

    if MainMenuBar then MainMenuBar:EnableMouse(false) end
    if ShapeshiftBarFrame then ShapeshiftBarFrame:EnableMouse(false) end
    if PossessBarFrame then PossessBarFrame:EnableMouse(false) end
    if PetActionBarFrame then PetActionBarFrame:EnableMouse(false) end
    if MultiCastActionBarFrame then MultiCastActionBarFrame:EnableMouse(false) end
end

-- RetailUI Pattern: XP Bar Update Hook (EXACT COPY)
local function MainMenuExpBar_Update()
    if not addon.ActionBarFrames.repexpbar then return end
    
    local mainMenuExpBar = MainMenuExpBar
    mainMenuExpBar:ClearAllPoints()
    mainMenuExpBar:SetWidth(addon.ActionBarFrames.repexpbar:GetWidth())
    mainMenuExpBar:SetHeight(addon.ActionBarFrames.repexpbar:GetHeight()) --  CRITICAL: Always set height like RetailUI
    mainMenuExpBar:SetPoint("LEFT", addon.ActionBarFrames.repexpbar, "LEFT", 0, 0)

    local repWatchBar = ReputationWatchBar
    if repWatchBar:IsShown() then
        -- RetailUI pattern: XP bar anchors DIRECTLY to RepWatchBar when visible
        mainMenuExpBar:SetPoint("LEFT", repWatchBar, "LEFT", 0, -22)
    else
        -- When no reputation bar, position relative to container
        mainMenuExpBar:SetPoint("LEFT", addon.ActionBarFrames.repexpbar, "LEFT", 0, 0)
    end
end

-- RetailUI Pattern: Reputation Bar Update Hook (EXACT COPY)
local function ReputationWatchBar_Update()
    if not addon.ActionBarFrames.repexpbar then 
        return 
    end
    
    local factionInfo = GetWatchedFactionInfo()
    if factionInfo then
        local repWatchBar = ReputationWatchBar
        if repWatchBar then
            --  CRITICAL FIX: Set parent to container and proper layering like RetailUI
            repWatchBar:SetParent(addon.ActionBarFrames.repexpbar)
            repWatchBar:SetFrameStrata("LOW") -- RetailUI uses default/low strata
            repWatchBar:ClearAllPoints()
            repWatchBar:SetHeight(addon.ActionBarFrames.repexpbar:GetHeight())
            repWatchBar:SetScale(0.9) --  CRITICAL: Apply same scale as experience bar
            repWatchBar:SetPoint("LEFT", addon.ActionBarFrames.repexpbar, "LEFT", 0, 0)
            
            --  CRITICAL: Fix the real text inside ReputationWatchStatusBar
            local repStatusBar = ReputationWatchStatusBar
            if repStatusBar then
                -- Force ReputationWatchStatusBar to have a lower FrameLevel than its text
                repStatusBar:SetFrameLevel(repWatchBar:GetFrameLevel() - 1)
                
                -- Find and fix the actual text inside the status bar
                for i = 1, repStatusBar:GetNumRegions() do
                    local region = select(i, repStatusBar:GetRegions())
                    if region and region:GetObjectType() == "FontString" then
                        -- This is the real reputation text!
                        region:SetDrawLayer("OVERLAY", 7)
                        region:Show()
                        break
                    end
                end
            end
        end
    end
end



-- update position for secondary action bars - LEGACY FUNCTION
--  NOTE: This function is kept for compatibility but bottom bars are now handled by centralized system
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

-- Store action bar container frames (RetailUI pattern)
addon.ActionBarFrames = {
    mainbar = nil,
    rightbar = nil,
    leftbar = nil,
    bottombarleft = nil,
    bottombarright = nil,
    repexpbar = nil  -- RetailUI pattern: XP/Rep bar frame container
}

-- Create action bar container frames (RetailUI pattern)
local function CreateActionBarFrames()
    -- Main bar - create a NEW container frame instead of using pUiMainBar directly
    addon.ActionBarFrames.mainbar = addon.CreateUIFrame(pUiMainBar:GetWidth(), pUiMainBar:GetHeight(), "MainBar")
    
    -- Create other action bar containers
    addon.ActionBarFrames.rightbar = addon.CreateUIFrame(40, 490, "RightBar")
    addon.ActionBarFrames.leftbar = addon.CreateUIFrame(40, 490, "LeftBar")
    addon.ActionBarFrames.bottombarleft = addon.CreateUIFrame(490, 40, "BottomBarLeft")
    addon.ActionBarFrames.bottombarright = addon.CreateUIFrame(490, 40, "BottomBarRight")
    
    -- RepExp bar container (RetailUI pattern)
    addon.ActionBarFrames.repexpbar = addon.CreateUIFrame(addon.ActionBarFrames.mainbar:GetWidth(), 10, "RepExpBar")
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
    

end

-- Position action bars to their container frames
local function PositionActionBarsToContainers()
    -- Only proceed if not in combat to avoid taint
    if InCombatLockdown() then return end
    
    -- Use the initial function for runtime positioning
    PositionActionBarsToContainers_Initial()
end

-- Apply saved positions from database (RetailUI pattern)
local function ApplyActionBarPositions()
    -- Safe containers can be positioned anytime - no combat check needed
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then return end
    
    local widgets = addon.db.profile.widgets
    
    -- Apply mainbar container position (safe to do anytime)
    if widgets.mainbar and addon.ActionBarFrames.mainbar then
        local config = widgets.mainbar
        if config.anchor then
            addon.ActionBarFrames.mainbar:ClearAllPoints()
            addon.ActionBarFrames.mainbar:SetPoint(config.anchor, config.posX, config.posY)
        end
    end
    
    -- Apply other bar positions
    local barConfigs = {
        {frame = addon.ActionBarFrames.rightbar, config = widgets.rightbar, default = {"RIGHT", -10, -70}},
        {frame = addon.ActionBarFrames.leftbar, config = widgets.leftbar, default = {"RIGHT", -45, -70}},
        {frame = addon.ActionBarFrames.bottombarleft, config = widgets.bottombarleft, default = {"BOTTOM", 0, 120}},
        {frame = addon.ActionBarFrames.bottombarright, config = widgets.bottombarright, default = {"BOTTOM", 0, 160}},
        -- RetailUI pattern: RepExp bar positioning
        {frame = addon.ActionBarFrames.repexpbar, config = widgets.repexpbar, default = {"BOTTOM", 0, 35}}
    }
    
    for _, barData in ipairs(barConfigs) do
        if barData.frame and barData.config and barData.config.anchor then
            local config = barData.config
            barData.frame:ClearAllPoints()
            barData.frame:SetPoint(config.anchor, config.posX, config.posY)
        elseif barData.frame then
            -- Apply default position
            local default = barData.default
            barData.frame:ClearAllPoints()
            barData.frame:SetPoint(default[1], UIParent, default[1], default[2], default[3])
        end
    end
end

-- Register action bar frames with the centralized system (RetailUI pattern)
local function RegisterActionBarFrames()
    -- Register all action bar frames
    local frameRegistrations = {
        {name = "mainbar", frame = addon.ActionBarFrames.mainbar, blizzardFrame = MainMenuBar, configPath = {"widgets", "mainbar"}},
        {name = "rightbar", frame = addon.ActionBarFrames.rightbar, blizzardFrame = MultiBarRight, configPath = {"widgets", "rightbar"}},
        {name = "leftbar", frame = addon.ActionBarFrames.leftbar, blizzardFrame = MultiBarLeft, configPath = {"widgets", "leftbar"}},
        {name = "bottombarleft", frame = addon.ActionBarFrames.bottombarleft, blizzardFrame = MultiBarBottomLeft, configPath = {"widgets", "bottombarleft"}},
        {name = "bottombarright", frame = addon.ActionBarFrames.bottombarright, blizzardFrame = MultiBarBottomRight, configPath = {"widgets", "bottombarright"}},
        -- RetailUI pattern: RepExp bar registration
        {name = "repexpbar", frame = addon.ActionBarFrames.repexpbar, blizzardFrame = nil, configPath = {"widgets", "repexpbar"}}
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
        -- Exclude bars that don't need repositioning after drag
        if frame and name ~= "mainbar" then
            frame:HookScript("OnDragStop", function(self)
                addon.core:ScheduleTimer(function() 
                    -- RetailUI Pattern: Only reposition if not in combat
                    PositionActionBarsToContainers()
                end, 0.1)
            end)
        end
    end
    
    --  REMOVED: XP and Rep bar drag handlers will be handled by RetailUI pattern
end
--  REMOVED: Rep bar event handling will be replaced with RetailUI pattern
--  REMOVED: Rep bar text setup will be replaced with RetailUI pattern
-- configuration refresh function (RetailUI pattern)
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
    if PetActionBarFrame then PetActionBarFrame:SetScale(db_mainbars.scale_petbar or 1.0); end
    
    -- RetailUI pattern: XP/Rep bar scaling
    if addon.ActionBarFrames.repexpbar then
        addon.ActionBarFrames.repexpbar:SetScale(db_mainbars.scale_repexpbar or 1.0)
    end
    
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
    
    -- Update action bar positions
    addon.UpdateActionBarWidgets()
    
    -- Update pet bar visibility and configuration
    addon.core:ScheduleTimer(function()
        addon.UpdatePetBarVisibility()
    end, 0.1)
end

--  REMOVED: Diagnostic functions will be replaced with RetailUI pattern
-- RetailUI Pattern: Initialize action bar system with XP/Rep bars
local function InitializeActionBarSystem()
    CreateActionBarFrames()
    ApplyActionBarPositions()
    RegisterActionBarFrames()
    
    -- Set up RetailUI pattern hooks for XP/Rep bars
    hooksecurefunc('MainMenuExpBar_Update', MainMenuExpBar_Update)
    hooksecurefunc('ReputationWatchBar_Update', ReputationWatchBar_Update)
    
    -- Hook the function that sets watched faction
    if SetWatchedFactionIndex then
        hooksecurefunc('SetWatchedFactionIndex', function(factionIndex)
            addon.core:ScheduleTimer(function()
                if ReputationWatchBar_Update then ReputationWatchBar_Update() end
            end, 0.1)
        end)
    end
    
    -- Additional hooks for reputation bar show/hide events
    if ReputationWatchBar then
        ReputationWatchBar:HookScript("OnShow", function() 
            addon.core:ScheduleTimer(function()
                if MainMenuExpBar_Update then MainMenuExpBar_Update() end
            end, 0.1)
        end)
        ReputationWatchBar:HookScript("OnHide", function() 
            addon.core:ScheduleTimer(function()
                if MainMenuExpBar_Update then MainMenuExpBar_Update() end
            end, 0.1)
        end)
    end
    
    -- ALWAYS position action bars immediately during addon load (RetailUI pattern)
    -- This is safe during ADDON_LOADED event, even in combat
    PositionActionBarsToContainers_Initial()
    
    if InCombatLockdown() then
        print("|cff00ff00DragonUI:|r Action bars positioned during combat reload")
    end
    
    -- Set up drag handlers after a short delay
    addon.core:ScheduleTimer(function() SetupActionBarDragHandlers() end, 0.2)
end
-- Update action bar positions from database (RetailUI:UpdateWidgets pattern)
function addon.UpdateActionBarWidgets()
    -- Safe containers can be positioned anytime - no combat check needed
    ApplyActionBarPositions()
    
    -- RetailUI pattern: Update repExpBar position specifically
    if addon.ActionBarFrames.repexpbar and addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.repexpbar then
        local widgetOptions = addon.db.profile.widgets.repexpbar
        addon.ActionBarFrames.repexpbar:ClearAllPoints()
        addon.ActionBarFrames.repexpbar:SetPoint(widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY)
    end
    
    -- Only position Blizzard frames if not in combat
    if not InCombatLockdown() then
        PositionActionBarsToContainers()
    end
end

-- Event handler for addon initialization (RetailUI pattern)
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD") -- RetailUI pattern: XP/Rep bars setup
initFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- When combat ends
initFrame:RegisterEvent("UPDATE_FACTION") -- When reputation changes
-- Pet bar events
initFrame:RegisterEvent("PET_BAR_UPDATE") -- When pet bar changes
initFrame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN") -- Pet cooldowns
initFrame:RegisterEvent("UNIT_PET") -- When pet changes
initFrame:RegisterEvent("UNIT_EXITED_VEHICLE") -- Vehicle exit
initFrame:RegisterEvent("UNIT_ENTERED_VEHICLE") -- Vehicle enter
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Initialize action bar system immediately (RetailUI pattern)
        -- This ensures frames are positioned correctly even during combat reload
        InitializeActionBarSystem()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- RetailUI pattern: Remove interfering Blizzard textures FIRST
        RemoveBlizzardFrames()
        
        -- RetailUI pattern: Apply XP/Rep bars styling after removing frames
        if addon.ActionBarFrames.repexpbar then
            ReplaceBlizzardRepExpBarFrame(addon.ActionBarFrames.repexpbar)
        end
        
        -- Force initial update of reputation and experience bars
        addon.core:ScheduleTimer(function()
            if ReputationWatchBar_Update then ReputationWatchBar_Update() end
            if MainMenuExpBar_Update then MainMenuExpBar_Update() end
            
            --  CRITICAL: Let WoW handle visibility naturally - don't force Show()
            
            -- Note: Scale is handled by individual update hooks, not here to avoid double scaling
        end, 0.5)
        
        -- Initialize pet bar visibility after a longer delay to ensure pet data is loaded
        addon.core:ScheduleTimer(function()
            addon.UpdatePetBarVisibility()
        end, 1.0)
        
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Reposition Blizzard frames when combat ends (for runtime changes)
        addon.core:ScheduleTimer(function() 
            ApplyActionBarPositions() -- Ensure containers are in correct position
            PositionActionBarsToContainers() -- Position Blizzard frames to containers
            print("|cff00ff00DragonUI:|r Action bars repositioned after combat")
        end, 0.1)
    elseif event == "UPDATE_FACTION" then
        -- Update reputation bar when watched faction changes
        addon.core:ScheduleTimer(function()
            if ReputationWatchBar_Update then ReputationWatchBar_Update() end
            
            --  CRITICAL: Let WoW handle visibility naturally - don't force Show()
        end, 0.1)
    elseif event == "PET_BAR_UPDATE" or event == "PET_BAR_UPDATE_COOLDOWN" or event == "UNIT_PET" then
        -- Handle pet bar visibility and updates
        if arg1 == "player" or not arg1 then
            addon.core:ScheduleTimer(function()
                addon.UpdatePetBarVisibility()
            end, 0.1)
        end
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        -- Handle vehicle events that affect pet bar
        if arg1 == "player" then
            addon.core:ScheduleTimer(function()
                addon.UpdatePetBarVisibility()
            end, 0.2)
        end
    end
end)

--  REMOVED: Duplicate RefreshMainbars function eliminated

local function OnProfileChange()
    -- This function is called whenever the profile changes, resets, or is copied
    if addon.RefreshMainbars then
        addon.RefreshMainbars()
    end
    
    -- Update pet bar after profile change
    addon.core:ScheduleTimer(function()
        addon.UpdatePetBarVisibility()
    end, 0.2)
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

--  REMOVED: XP and Rep bar refresh functions will be handled by RetailUI pattern
--  REMOVED: UpdateExhaustionTick will be handled by RetailUI pattern

-- Force profile refresh
function addon.ForceProfileRefresh()
    OnProfileChange()
end

-- Update pet bar visibility and positioning
function addon.UpdatePetBarVisibility()
    if InCombatLockdown() then return end
    
    local petBar = PetActionBarFrame
    if not petBar then return end
    
    -- Check if player has a pet or is in a vehicle
    local hasPet = UnitExists("pet") and UnitIsVisible("pet")
    local inVehicle = UnitInVehicle("player")
    local hasVehicleActionBar = HasVehicleActionBar and HasVehicleActionBar()
    
    -- Show pet bar if player has a pet or relevant vehicle controls
    if hasPet or (inVehicle and hasVehicleActionBar) then
        if not petBar:IsShown() then
            petBar:Show()
        end
        
        -- Ensure proper positioning and scaling
        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if db and db.scale_petbar then
            petBar:SetScale(db.scale_petbar)
        end
        
        -- Update pet action buttons
        for i = 1, NUM_PET_ACTION_SLOTS do
            local button = _G["PetActionButton" .. i]
            if button then
                button:Show()
            end
        end
    else
        -- Hide pet bar when no pet and not in vehicle
        if petBar:IsShown() then
            petBar:Hide()
        end
    end
end



-- RetailUI Pattern: Editor mode functions for XP/Rep bar
function addon.ShowRepExpBarEditor()
    if addon.ActionBarFrames.repexpbar and addon.HideUIFrame then
        addon.HideUIFrame(addon.ActionBarFrames.repexpbar)
    end
end

function addon.HideRepExpBarEditor(refresh)
    if addon.ActionBarFrames.repexpbar and addon.ShowUIFrame then
        addon.ShowUIFrame(addon.ActionBarFrames.repexpbar)
        if addon.SaveUIFramePosition then
            addon.SaveUIFramePosition(addon.ActionBarFrames.repexpbar, 'repexpbar')
        end
        
        if refresh and addon.UpdateActionBarWidgets then
            addon.UpdateActionBarWidgets()
        end
        
        --  CRITICAL: Fix reputation bar layering after editor mode
        addon.core:ScheduleTimer(function()
            local repWatchBar = ReputationWatchBar
            if repWatchBar and repWatchBar:IsVisible() then
                -- Restore the original FrameLevel that editor mode changed
                repWatchBar:SetFrameLevel(101) -- Back to original level
                repWatchBar:SetFrameStrata("LOW")
                
                -- Fix the real text inside ReputationWatchStatusBar
                local repStatusBar = ReputationWatchStatusBar
                if repStatusBar then
                    -- Force ReputationWatchStatusBar to have a lower FrameLevel
                    repStatusBar:SetFrameLevel(100) -- Just below repWatchBar
                    
                    -- Find and fix the actual text inside the status bar
                    for i = 1, repStatusBar:GetNumRegions() do
                        local region = select(i, repStatusBar:GetRegions())
                        if region and region:GetObjectType() == "FontString" then
                            -- This is the real reputation text!
                            region:SetDrawLayer("OVERLAY", 7)
                            region:Show()
                            break
                        end
                    end
                end
            end
        end, 0.1)
    end
end

