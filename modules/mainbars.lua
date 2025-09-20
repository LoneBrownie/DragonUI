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
	
	MainMenuExpBar:SetClearPoint('BOTTOM', UIParent, 0, 6)
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

-- ✅ INTEGRATE ACTION BARS WITH CENTRALIZED UI SYSTEM
-- Create container frames for each action bar and register them
local function SetupActionBarContainers()
    -- Create MainBars module reference for consistency
    addon.MainBars = addon.MainBars or {}
    
    -- 1. Main bar - use existing pUiMainBar as container, add editor textures
    -- Create a separate overlay frame to ensure it's above action buttons
    if not pUiMainBar.overlayFrame then
        local overlayFrame = CreateFrame("Frame", nil, UIParent)
        overlayFrame:SetFrameStrata("FULLSCREEN_DIALOG")  -- Highest available strata to be above everything
        overlayFrame:SetFrameLevel(9999)
        overlayFrame:SetAllPoints(pUiMainBar)
        overlayFrame:EnableMouse(false)  -- ✅ FIXED: Don't block mouse by default - only when editor is active
        
        -- CRITICAL FIX: Allow dragging by forwarding drag events to the main frame
        overlayFrame:RegisterForDrag("LeftButton")
        overlayFrame:SetScript("OnDragStart", function(self)
            if pUiMainBar:IsMovable() then
                pUiMainBar:StartMoving()
            end
        end)
        overlayFrame:SetScript("OnDragStop", function(self)
            if pUiMainBar:IsMovable() then
                pUiMainBar:StopMovingOrSizing()
                -- ✅ CRITICAL FIX: Save mainbar position when moved via overlay
                if addon.EditorMode and addon.EditorMode:IsActive() then
                    SaveUIFramePosition(pUiMainBar, "widgets", "mainbar")
                    print("|cFFFFFF00[DragonUI Debug]|r Mainbar position saved via overlay drag")
                end
            end
        end)
        
        pUiMainBar.overlayFrame = overlayFrame
        
        local texture = overlayFrame:CreateTexture(nil, 'OVERLAY')
        texture:SetAllPoints(overlayFrame)
        texture:SetTexture(0, 1, 0, 0.3) -- Green more visible
        texture:SetDrawLayer('OVERLAY', 7) -- High layer within overlay frame
        texture:Hide()
        pUiMainBar.editorTexture = texture
        
        local fontString = overlayFrame:CreateFontString(nil, "OVERLAY", 'GameFontNormalLarge')
        fontString:SetPoint("CENTER", overlayFrame, "CENTER")
        fontString:SetText("MainBar")
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(2, -2)
        fontString:SetDrawLayer('OVERLAY', 8) -- Above the texture
        fontString:Hide()
        pUiMainBar.editorText = fontString
        
        -- Hook mainbar movement to update overlay position
        pUiMainBar:HookScript("OnUpdate", function(self)
            if overlayFrame then
                overlayFrame:SetAllPoints(self)
            end
        end)
    end
    
    -- Set proper frame strata and level for editor mode - CRITICAL for overlay visibility
    pUiMainBar.originalStrata = pUiMainBar:GetFrameStrata()
    pUiMainBar.originalLevel = pUiMainBar:GetFrameLevel()
    
    -- Ensure main bar has proper position from database or use default
    local mainbarConfig = addon.db.profile.widgets.mainbar
    if mainbarConfig and mainbarConfig.anchor then
        -- ✅ CRITICAL FIX: Always apply saved position, clear existing points first
        pUiMainBar:ClearAllPoints()
        pUiMainBar:SetPoint(mainbarConfig.anchor or "BOTTOM", UIParent, mainbarConfig.anchor or "BOTTOM", mainbarConfig.posX or 0, mainbarConfig.posY or 75)
        print("|cFF00FF00[DragonUI]|r Applied mainbar position from database: " .. (mainbarConfig.anchor or "BOTTOM") .. " (" .. (mainbarConfig.posX or 0) .. "," .. (mainbarConfig.posY or 75) .. ")")
    else
        -- Only set default if no saved position exists
        if not pUiMainBar:GetPoint() then
            pUiMainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 75)
            print("|cFF00FF00[DragonUI]|r Applied mainbar default position")
        end
    end
    pUiMainBar:SetMovable(true)
    pUiMainBar:EnableMouse(true)
    pUiMainBar:RegisterForDrag("LeftButton")
    pUiMainBar:SetScript("OnDragStart", function(self) self:StartMoving() end)
    pUiMainBar:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing()
        -- ✅ CRITICAL FIX: Save position automatically when moved in editor mode
        if addon.EditorMode and addon.EditorMode:IsActive() then
            SaveUIFramePosition(self, "widgets", "mainbar")
            print("|cFFFFFF00[DragonUI Debug]|r Mainbar position saved during drag")
        end
    end)
    
    addon:RegisterEditableFrame({
        name = "mainbar",
        frame = pUiMainBar,
        blizzardFrame = MainMenuBar,
        configPath = {"widgets", "mainbar"},
        module = addon.MainBars,
        onHide = function()
            -- ✅ EXTRA SAFETY: Force save mainbar position when editor closes
            SaveUIFramePosition(pUiMainBar, "widgets", "mainbar")
            print("|cFFFFFF00[DragonUI Debug]|r Mainbar position saved on editor close")
        end
    })
    print("|cFF00FF00[DragonUI]|r Registered mainbar frame")
    
    -- 2. Right bar container
    local rightBarFrame = addon.CreateUIFrame(40, 490, "RightBar")

    

    
    -- Use database position or default
    local rightbarConfig = addon.db.profile.widgets.rightbar
    if rightbarConfig and rightbarConfig.anchor then
        rightBarFrame:SetPoint(rightbarConfig.anchor or "RIGHT", UIParent, rightbarConfig.anchor or "RIGHT", rightbarConfig.posX or -10, rightbarConfig.posY or -70)
        print("|cFF00FF00[DragonUI]|r Applied rightbar position from database: " .. (rightbarConfig.anchor or "RIGHT") .. " (" .. (rightbarConfig.posX or -10) .. "," .. (rightbarConfig.posY or -70) .. ")")
    else
        rightBarFrame:SetPoint("RIGHT", UIParent, "RIGHT", -10, -70) -- Default position
        print("|cFF00FF00[DragonUI]|r Applied rightbar default position")
    end
    
    -- Ensure overlay is above action buttons
    if rightBarFrame.editorTexture then
        rightBarFrame.editorTexture:SetDrawLayer('OVERLAY', 25)
    end
    if rightBarFrame.editorText then
        rightBarFrame.editorText:SetDrawLayer('OVERLAY', 26)
    end
    
    -- Set proper strata for overlay visibility
    rightBarFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    rightBarFrame:SetFrameLevel(500)
    
    if MultiBarRight then
        MultiBarRight:SetParent(UIParent) -- Keep on UIParent to prevent strata issues
        MultiBarRight:ClearAllPoints()
        MultiBarRight:SetPoint("CENTER", rightBarFrame, "CENTER")
    end
    
    addon:RegisterEditableFrame({
        name = "rightbar",
        frame = rightBarFrame,
        blizzardFrame = MultiBarRight,
        configPath = {"widgets", "rightbar"},
        module = addon.MainBars
    })
    print("|cFF00FF00[DragonUI]|r Registered rightbar frame")
    
    -- 3. Left bar container
    local leftBarFrame = addon.CreateUIFrame(40, 490, "LeftBar")
    
    -- Use database position or default
    local leftbarConfig = addon.db.profile.widgets.leftbar
    if leftbarConfig and leftbarConfig.anchor then
        leftBarFrame:SetPoint(leftbarConfig.anchor or "RIGHT", UIParent, leftbarConfig.anchor or "RIGHT", leftbarConfig.posX or -45, leftbarConfig.posY or -70)
        print("|cFF00FF00[DragonUI]|r Applied leftbar position from database: " .. (leftbarConfig.anchor or "RIGHT") .. " (" .. (leftbarConfig.posX or -45) .. "," .. (leftbarConfig.posY or -70) .. ")")
    else
        leftBarFrame:SetPoint("RIGHT", UIParent, "RIGHT", -45, -70) -- Default position
        print("|cFF00FF00[DragonUI]|r Applied leftbar default position")
    end
    
    -- Ensure overlay is above action buttons
    if leftBarFrame.editorTexture then
        leftBarFrame.editorTexture:SetDrawLayer('OVERLAY', 25)
    end
    if leftBarFrame.editorText then
        leftBarFrame.editorText:SetDrawLayer('OVERLAY', 26)
    end
    
    -- Set proper strata for overlay visibility
    leftBarFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    leftBarFrame:SetFrameLevel(500)
    
    if MultiBarLeft then
        MultiBarLeft:SetParent(UIParent) -- Keep on UIParent to prevent strata issues
        MultiBarLeft:ClearAllPoints()
        MultiBarLeft:SetPoint("CENTER", leftBarFrame, "CENTER")
    end
    
    addon:RegisterEditableFrame({
        name = "leftbar",
        frame = leftBarFrame,
        blizzardFrame = MultiBarLeft,
        configPath = {"widgets", "leftbar"},
        module = addon.MainBars
    })
    print("|cFF00FF00[DragonUI]|r Registered leftbar frame")
    
    -- 4. Bottom left bar container - INDEPENDENT FROM MAINBAR
    local bottomLeftBarFrame = addon.CreateUIFrame(490, 40, "BottomBarLeft")
    
    -- Use database position or default
    local bottomleftConfig = addon.db.profile.widgets.bottombarleft
    if bottomleftConfig and bottomleftConfig.anchor then
        bottomLeftBarFrame:SetPoint(bottomleftConfig.anchor or "BOTTOM", UIParent, bottomleftConfig.anchor or "BOTTOM", bottomleftConfig.posX or 0, bottomleftConfig.posY or 120)
        print("|cFF00FF00[DragonUI]|r Applied bottombarleft position from database: " .. (bottomleftConfig.anchor or "BOTTOM") .. " (" .. (bottomleftConfig.posX or 0) .. "," .. (bottomleftConfig.posY or 120) .. ")")
    else
        bottomLeftBarFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120) -- Default position
        print("|cFF00FF00[DragonUI]|r Applied bottombarleft default position")
    end
    
    -- Make overlay more visible and ensure it's above action bars
    if bottomLeftBarFrame.editorTexture then
        bottomLeftBarFrame.editorTexture:SetTexture(0, 1, 0, 0.3) 
        bottomLeftBarFrame.editorTexture:SetDrawLayer('OVERLAY', 30) -- Very high layer
    end
    if bottomLeftBarFrame.editorText then

        bottomLeftBarFrame.editorText:SetShadowColor(0, 0, 0, 1)
        bottomLeftBarFrame.editorText:SetShadowOffset(2, -2)
        bottomLeftBarFrame.editorText:SetDrawLayer('OVERLAY', 31)
    end
    
    -- CRITICAL: Set frame strata higher to be above action bars AND mainbar
    bottomLeftBarFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    bottomLeftBarFrame:SetFrameLevel(1500)  -- Higher than mainbar
    
    -- Ensure overlay stays with frame during movement
    bottomLeftBarFrame:HookScript("OnUpdate", function(self)
        if self.editorTexture and self.editorText then
            -- Force overlay to stay aligned with frame
            self.editorTexture:SetAllPoints(self)
            self.editorText:SetPoint("CENTER", self, "CENTER")
        end
    end)
    
    if MultiBarBottomLeft then
        -- COMPLETELY DECOUPLE from mainbar
        MultiBarBottomLeft:SetParent(UIParent)
        MultiBarBottomLeft:ClearAllPoints()
        MultiBarBottomLeft:SetPoint("CENTER", bottomLeftBarFrame, "CENTER")
        MultiBarBottomLeft:SetMovable(true)
    end
    
    addon:RegisterEditableFrame({
        name = "bottombarleft",
        frame = bottomLeftBarFrame,
        blizzardFrame = MultiBarBottomLeft,
        configPath = {"widgets", "bottombarleft"},
        module = addon.MainBars
    })
    print("|cFF00FF00[DragonUI]|r Registered bottombarleft frame")
    
    -- 5. Bottom right bar container - INDEPENDENT FROM MAINBAR
    local bottomRightBarFrame = addon.CreateUIFrame(490, 40, "BottomBarRight")
    
    -- Use database position or default
    local bottomrightConfig = addon.db.profile.widgets.bottombarright
    if bottomrightConfig and bottomrightConfig.anchor then
        bottomRightBarFrame:SetPoint(bottomrightConfig.anchor or "BOTTOM", UIParent, bottomrightConfig.anchor or "BOTTOM", bottomrightConfig.posX or 0, bottomrightConfig.posY or 160)
        print("|cFF00FF00[DragonUI]|r Applied bottombarright position from database: " .. (bottomrightConfig.anchor or "BOTTOM") .. " (" .. (bottomrightConfig.posX or 0) .. "," .. (bottomrightConfig.posY or 160) .. ")")
    else
        bottomRightBarFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160) -- Default position
        print("|cFF00FF00[DragonUI]|r Applied bottombarright default position")
    end
    
    -- Make overlay more visible and ensure it's above action bars
    if bottomRightBarFrame.editorTexture then
        bottomRightBarFrame.editorTexture:SetTexture(0, 1, 0, 0.3) 
        bottomRightBarFrame.editorTexture:SetDrawLayer('OVERLAY', 30) -- Very high layer
    end
    if bottomRightBarFrame.editorText then
        bottomRightBarFrame.editorText:SetShadowColor(0, 0, 0, 1)
        bottomRightBarFrame.editorText:SetShadowOffset(2, -2)
        bottomRightBarFrame.editorText:SetDrawLayer('OVERLAY', 31)
    end
    
    -- CRITICAL: Set frame strata higher to be above action bars AND mainbar
    bottomRightBarFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    bottomRightBarFrame:SetFrameLevel(1500)  -- Higher than mainbar
    
    -- Ensure overlay stays with frame during movement
    bottomRightBarFrame:HookScript("OnUpdate", function(self)
        if self.editorTexture and self.editorText then
            -- Force overlay to stay aligned with frame
            self.editorTexture:SetAllPoints(self)
            self.editorText:SetPoint("CENTER", self, "CENTER")
        end
    end)
    
    if MultiBarBottomRight then
        -- COMPLETELY DECOUPLE from mainbar
        MultiBarBottomRight:SetParent(UIParent)
        MultiBarBottomRight:ClearAllPoints()
        MultiBarBottomRight:SetPoint("CENTER", bottomRightBarFrame, "CENTER")
        MultiBarBottomRight:SetMovable(true)
    end
    
    addon:RegisterEditableFrame({
        name = "bottombarright",
        frame = bottomRightBarFrame,
        blizzardFrame = MultiBarBottomRight,
        configPath = {"widgets", "bottombarright"},
        module = addon.MainBars
    })
    print("|cFF00FF00[DragonUI]|r Registered bottombarright frame")
    
    print("|cFF00FF00[DragonUI]|r Action bars integrated with centralized UI system")
end



-- ✅ NEW: Set up containers after database is initialized
local function InitializeActionBars()
    if addon.db and addon.db.profile and addon.db.profile.widgets then
        SetupActionBarContainers()
        print("|cFF00FF00[DragonUI]|r Action bars initialized with database positions")
        
        -- ✅ EXTRA SAFETY: Force apply mainbar position after a short delay
        addon.core:ScheduleTimer(function()
            if addon.RefreshMainbarPosition then
                addon.RefreshMainbarPosition()
            end
        end, 0.5)
    else
        print("|cFFFF0000[DragonUI]|r Database not ready, deferring action bar setup")
        -- Retry after a longer delay
        addon.core:ScheduleTimer(InitializeActionBars, 1.0)
    end
end

-- Hook into addon initialization to setup action bars at the right time
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Give OnInitialize time to run first
        addon.core:ScheduleTimer(InitializeActionBars, 0.1)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Function to ensure bottom bars follow their containers when moved
local function EnsureBottomBarsFollowContainers()
    addon.core:ScheduleTimer(function()
        if MultiBarBottomLeft then
            local frameInfo = addon:GetEditableFrameInfo("bottombarleft")
            if frameInfo and frameInfo.frame then
                MultiBarBottomLeft:ClearAllPoints()
                MultiBarBottomLeft:SetPoint("CENTER", frameInfo.frame, "CENTER")
            end
        end
        
        if MultiBarBottomRight then
            local frameInfo = addon:GetEditableFrameInfo("bottombarright")
            if frameInfo and frameInfo.frame then
                MultiBarBottomRight:ClearAllPoints()
                MultiBarBottomRight:SetPoint("CENTER", frameInfo.frame, "CENTER")
            end
        end
        
        -- Also ensure left and right bars follow their containers
        if MultiBarLeft then
            local frameInfo = addon:GetEditableFrameInfo("leftbar")
            if frameInfo and frameInfo.frame then
                MultiBarLeft:ClearAllPoints()
                MultiBarLeft:SetPoint("CENTER", frameInfo.frame, "CENTER")
            end
        end
        
        if MultiBarRight then
            local frameInfo = addon:GetEditableFrameInfo("rightbar")
            if frameInfo and frameInfo.frame then
                MultiBarRight:ClearAllPoints()
                MultiBarRight:SetPoint("CENTER", frameInfo.frame, "CENTER")
            end
        end
    end, 0.1)
end

-- ✅ REMOVED: Faulty hook that was causing IsMoving() errors
-- The centralized system should handle movement automatically

-- Add proper hooks for action bar following using drag events
local function SetupActionBarFollowing()
    -- Setup for all container frames to ensure action bars follow when moved
    -- NOTE: mainbar is excluded because it doesn't have a separate action bar that follows it
    local actionBarMappings = {
        leftbar = MultiBarLeft,
        rightbar = MultiBarRight,
        bottombarleft = MultiBarBottomLeft,
        bottombarright = MultiBarBottomRight
    }
    
    for containerName, actionBar in pairs(actionBarMappings) do
        if actionBar then
            local frameInfo = addon:GetEditableFrameInfo(containerName)
            if frameInfo and frameInfo.frame then
                -- Hook drag stop to ensure action bar follows
                frameInfo.frame:HookScript("OnDragStop", function(self)
                    actionBar:ClearAllPoints()
                    actionBar:SetPoint("CENTER", self, "CENTER")
                end)
                
                -- Also hook show/hide events
                frameInfo.frame:HookScript("OnShow", function(self)
                    actionBar:ClearAllPoints()
                    actionBar:SetPoint("CENTER", self, "CENTER")
                end)
            end
        end
    end
end

-- Setup the following system after containers are registered
addon.core:ScheduleTimer(SetupActionBarFollowing, 1)

-- ✅ REMOVED: ApplyActionBarPositions function no longer needed
-- Positions are now applied directly in SetupActionBarContainers using database values

-- configuration refresh function
function addon.RefreshMainbars()
    if not pUiMainBar then return end
    
    local db = addon.db and addon.db.profile
    if not db then return end
    
    local db_mainbars = db.mainbars
    local db_style = db.style
    local db_buttons = db.buttons
    
    -- ========================================
    -- ✅ ORIENTATION AND NON-POSITIONAL SETTINGS ONLY
    -- ========================================
    
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
end

local function OnProfileChange()
    -- Esta función se llamará cada vez que el perfil cambie, se resetee o se copie.
    -- Llama directamente a la función de refresco principal.
    if addon.RefreshMainbars then
        addon.RefreshMainbars()
    end
    
    -- ✅ CRITICAL FIX: Also refresh mainbar position specifically
    if addon.RefreshMainbarPosition then
        addon.RefreshMainbarPosition()
    end
end

local initializationFrame = CreateFrame("Frame")
initializationFrame:RegisterEvent("PLAYER_LOGIN")
initializationFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Nos aseguramos de que la base de datos (AceDB) esté lista.
        if not addon.db then return end

        -- Registramos nuestra función 'OnProfileChange' para que se ejecute automáticamente
        -- cuando AceDB detecte un cambio de perfil.
        addon.db.RegisterCallback(addon, "OnProfileChanged", OnProfileChange)
        addon.db.RegisterCallback(addon, "OnProfileCopied", OnProfileChange)
        addon.db.RegisterCallback(addon, "OnProfileReset", OnProfileChange)
        
        -- Forzamos un refresco inicial al entrar al juego para aplicar la configuración del perfil cargado.
        OnProfileChange()

        -- Ya no necesitamos escuchar este evento.
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- ✅ FUNCIONES PÚBLICAS PARA DEBUGGING/MANUAL (se mantienen)
function addon.TestProfileCallbacks()

    if addon.db then
   
        if addon.db.GetCurrentProfile then
       
        end
    end
end

-- ✅ NEW: Function to refresh mainbar position from database
function addon.RefreshMainbarPosition()
    if not pUiMainBar or not addon.db or not addon.db.profile then return end
    
    local mainbarConfig = addon.db.profile.widgets.mainbar
    if mainbarConfig and mainbarConfig.anchor then
        pUiMainBar:ClearAllPoints()
        pUiMainBar:SetPoint(mainbarConfig.anchor or "BOTTOM", UIParent, mainbarConfig.anchor or "BOTTOM", mainbarConfig.posX or 0, mainbarConfig.posY or 75)
        print("|cFF00FF00[DragonUI]|r Refreshed mainbar position from database: " .. (mainbarConfig.anchor or "BOTTOM") .. " (" .. (mainbarConfig.posX or 0) .. "," .. (mainbarConfig.posY or 75) .. ")")
    end
end

function addon.ForceProfileRefresh()
    OnProfileChange()
end

function addon.TestSecondaryBars()

    local config = addon.db.profile.mainbars
    if not config then
       
        return
    end
    
       
    if MultiBarLeft then
        local point, _, _, x, y = MultiBarLeft:GetPoint()
    
    end
    
    if MultiBarRight then
        local point, _, _, x, y = MultiBarRight:GetPoint()
      
    end
    
   
    addon.PositionActionBars()
end

-- ✅ FUNCIÓN PARA FORZAR SOLO BARRAS SECUNDARIAS
function addon.ForceSecondaryBarsPosition()
    addon.PositionActionBars()
end

-- ✅ FUNCTIONS TO ENABLE/DISABLE OVERLAY MOUSE BLOCKING FOR EDITOR MODE
function addon.EnableActionBarOverlays()
    -- Enable mouse blocking on all action bar overlays when editor mode is active
    if pUiMainBar and pUiMainBar.overlayFrame then
        pUiMainBar.overlayFrame:EnableMouse(true)
    end
    if MultiBarLeft and MultiBarLeft.overlayFrame then
        MultiBarLeft.overlayFrame:EnableMouse(true)
    end
    if MultiBarRight and MultiBarRight.overlayFrame then
        MultiBarRight.overlayFrame:EnableMouse(true)
    end
    if MultiBarBottomLeft and MultiBarBottomLeft.overlayFrame then
        MultiBarBottomLeft.overlayFrame:EnableMouse(true)
    end
    if MultiBarBottomRight and MultiBarBottomRight.overlayFrame then
        MultiBarBottomRight.overlayFrame:EnableMouse(true)
    end
end

function addon.DisableActionBarOverlays()
    -- Disable mouse blocking on all action bar overlays when editor mode is inactive
    if pUiMainBar and pUiMainBar.overlayFrame then
        pUiMainBar.overlayFrame:EnableMouse(false)
    end
    if MultiBarLeft and MultiBarLeft.overlayFrame then
        MultiBarLeft.overlayFrame:EnableMouse(false)
    end
    if MultiBarRight and MultiBarRight.overlayFrame then
        MultiBarRight.overlayFrame:EnableMouse(false)
    end
    if MultiBarBottomLeft and MultiBarBottomLeft.overlayFrame then
        MultiBarBottomLeft.overlayFrame:EnableMouse(false)
    end
    if MultiBarBottomRight and MultiBarBottomRight.overlayFrame then
        MultiBarBottomRight.overlayFrame:EnableMouse(false)
    end
end