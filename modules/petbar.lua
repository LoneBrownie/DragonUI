local addon = select(2,...);
local config = addon.config;
local event = addon.package;
local class = addon._class;
local pUiMainBar = addon.pUiMainBar;
local unpack = unpack;
local select = select;
local pairs = pairs;
local _G = getfenv(0);

-- const
local GetPetActionInfo = GetPetActionInfo;
local RegisterStateDriver = RegisterStateDriver;
local CreateFrame = CreateFrame;
local UIParent = UIParent;
local hooksecurefunc = hooksecurefunc;

-- ✅ MIGRACIÓN A SISTEMA DE WIDGETS - CreateUIFrame como RetailUI
local petbarFrame = CreateUIFrame(326, 30, "Petbar")


-- ✅ OBJETO EDITOR PARA INTEGRACIÓN CON SISTEMA CENTRALIZADO
local PetbarEditor = {
    ShowPetbarTest = function()
        -- ✅ EN EDITOR MODE: Siempre mostrar para permitir edición
        -- ✅ El sistema centralizado ya maneja la visibilidad con hasTarget
        HideUIFrame(petbarFrame, {})
        print("|cFF00FF00[DragonUI]|r Petbar editor mode activated")
    end,
    
    HidePetbarTest = function(refresh)
        -- ✅ EN EDITOR MODE: Siempre guardar posición 
        SaveUIFramePosition(petbarFrame, "widgets", "petbar") -- ✅ CORREGIDO: Usar formato de 2 parámetros
        ShowUIFrame(petbarFrame)
        
        if refresh and addon.RefreshPetbar then
            addon.RefreshPetbar()
        end
        print("|cFF00FF00[DragonUI]|r Petbar editor mode deactivated, position saved")
    end
}

-- ✅ APLICAR POSICIÓN DESDE WIDGETS AL INICIALIZAR
local function ApplyPetbarPosition()
    -- ✅ NO REPOSICIONAR SI ESTAMOS EN EDITOR MODE O DURANTE DRAG
    if addon.EditorMode and addon.EditorMode:IsActive() then
        return -- No aplicar posición durante editor mode
    end
    
    if addon.db and addon.db.profile.widgets and addon.db.profile.widgets.petbar then
        local config = addon.db.profile.widgets.petbar
        if config.anchor and config.posX and config.posY then
            petbarFrame:ClearAllPoints()
            petbarFrame:SetPoint(config.anchor, UIParent, config.anchor, config.posX, config.posY)
        end
    end
end

-- ✅ INICIALIZACIÓN USANDO SISTEMA DE WIDGETS
local function InitializePetbar()
    if config and config.additional then
        -- ✅ APLICAR POSICIÓN DESDE WIDGETS CONFIG
        --ApplyPetbarPosition()
        
        -- Show petbar frame
        if petbarFrame then
            petbarFrame:Show()
        end
    end
end

-- ✅ INICIALIZACIÓN SIMPLIFICADA
local function DelayedPetInit()
	local delayFrame = CreateFrame("Frame")
	local elapsed = 0
	local attempts = 0
	local maxAttempts = 10 -- Reducido a 5 segundos
	
	delayFrame:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed >= 0.5 then -- Cada 0.5 segundos
			elapsed = 0
			attempts = attempts + 1
			
			-- ✅ USAR NUEVA FUNCIÓN DE INICIALIZACIÓN
			InitializePetbar()
			
			-- Parar después del máximo de intentos
			if attempts >= maxAttempts then
				delayFrame:SetScript("OnUpdate", nil)
			end
		end
	end)
end

-- ✅ USAR NUEVA FUNCIÓN DE INICIALIZACIÓN
addon.core.RegisterMessage(addon, "DRAGONUI_READY", InitializePetbar)

-- ✅ ELIMINAMOS LOS HOOKS DEL SISTEMA LEGACY - YA NO NECESITAMOS POSICIONAMIENTO MANUAL
-- El sistema de widgets maneja la posición directamente

local petbar = CreateFrame('Frame', 'pUiPetBar', petbarFrame, 'SecureHandlerStateTemplate') -- ✅ CHILD del petbarFrame
petbar:SetAllPoints(petbarFrame) -- ✅ ANCHOR AL NUEVO FRAME DE WIDGETS
petbar:SetFrameStrata("MEDIUM") -- ✅ DEBAJO del overlay verde que está en FULLSCREEN

local function petbutton_updatestate(self, event)
	local petActionButton, petActionIcon, petAutoCastableTexture, petAutoCastShine
	for index=1, NUM_PET_ACTION_SLOTS, 1 do
		local buttonName = 'PetActionButton'..index
		petActionButton = _G[buttonName]
		petActionIcon = _G[buttonName..'Icon']
		petAutoCastableTexture = _G[buttonName..'AutoCastable']
		petAutoCastShine = _G[buttonName..'Shine']
		
		local name, subtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(index)
		if not isToken then
			petActionIcon:SetTexture(texture)
			petActionButton.tooltipName = name
		else
			petActionIcon:SetTexture(_G[texture])
			petActionButton.tooltipName = _G[name]
		end
		petActionButton.isToken = isToken
		petActionButton.tooltipSubtext = subtext
		if isActive and name ~= 'PET_ACTION_FOLLOW' then
			petActionButton:SetChecked(true)
			if IsPetAttackAction(index) then
				PetActionButton_StartFlash(petActionButton)
			end
		else
			petActionButton:SetChecked(false)
			if IsPetAttackAction(index) then
				PetActionButton_StopFlash(petActionButton)
			end
		end
		if autoCastAllowed then
			petAutoCastableTexture:Show()
		else
			petAutoCastableTexture:Hide()
		end
		if autoCastEnabled then
			AutoCastShine_AutoCastStart(petAutoCastShine)
		else
			AutoCastShine_AutoCastStop(petAutoCastShine)
		end
		if name then
			if not config.additional.pet.grid then
				petActionButton:SetAlpha(1)
			end
		else
			if not config.additional.pet.grid then
				petActionButton:SetAlpha(0)
			end
		end
		if texture then
			if GetPetActionSlotUsable(index) then
				SetDesaturation(petActionIcon, nil)
			else
				SetDesaturation(petActionIcon, 1)
			end
			petActionIcon:Show()
		else
			petActionIcon:Hide()
		end
		if not PetHasActionBar() and texture and name ~= 'PET_ACTION_FOLLOW' then
			PetActionButton_StopFlash(petActionButton)
			SetDesaturation(petActionIcon, 1)
			petActionButton:SetChecked(false)
		end
	end
end

local function petbutton_position()
	if InCombatLockdown() then return end
	
	-- ✅ USAR NUEVO FRAME DE WIDGETS
	if not pUiPetBar or not petbarFrame then
		print("DragonUI: Pet bar frame not available")
		return
	end
	
	-- Read config values dynamically
	local btnsize = config.additional.size;
	local space = config.additional.spacing;
	
	-- Initialize all pet action buttons
	local button
	for index=1, NUM_PET_ACTION_SLOTS do
		button = _G['PetActionButton'..index];
		if button then
			button:ClearAllPoints();
			button:SetParent(pUiPetBar);
			button:SetSize(btnsize, btnsize);
			if index == 1 then
				button:SetPoint('BOTTOMLEFT', 0, 0);
			else
				local prevButton = _G['PetActionButton'..(index-1)];
				if prevButton then
					button:SetPoint('LEFT', prevButton, 'RIGHT', space, 0);
				end
			end
			button:Show();
			petbar:SetAttribute('addchild', button);
		else
			print("DragonUI: PetActionButton"..index.." not found")
		end
	end
	
	-- Set up visibility driver
	RegisterStateDriver(petbar, 'visibility', '[pet,novehicleui,nobonusbar:5] show; hide');
	
	-- Hook the update function only once
	if not petbar.updateHooked then
		hooksecurefunc('PetActionBar_Update', petbutton_updatestate);
		petbar.updateHooked = true
	end
end

local function OnEvent(self,event,...)
	-- if not UnitIsVisible('pet') then return; end
	local arg1 = ...;
	if event == 'PLAYER_LOGIN' then
		if not petBarInitialized then
			petbutton_position();
			petBarInitialized = true
		end
		-- FIXED: Apply grid configuration after initial positioning
		if addon.RefreshPetbar then
			addon.RefreshPetbar();
		end
	elseif event == 'PET_BAR_UPDATE' then
		-- RetailUI-style petbar initialization on first PET_BAR_UPDATE
		if not petBarInitialized then
			if config and config.debug then
				print("DragonUI: Initializing petbar on PET_BAR_UPDATE")
			end
			petbutton_position();
			petBarInitialized = true
		end
		-- Always update button states when pet bar updates
		petbutton_updatestate();
	elseif event == 'UNIT_PET' and arg1 == 'player'
	or event == 'PLAYER_CONTROL_LOST'
	or event == 'PLAYER_CONTROL_GAINED'
	or event == 'PLAYER_FARSIGHT_FOCUS_CHANGED'
	or event == 'UNIT_FLAGS'
	or arg1 == 'pet' and event == 'UNIT_AURA' then
		petbutton_updatestate();
	elseif event == 'PET_BAR_UPDATE_COOLDOWN' then
		PetActionBar_UpdateCooldowns();
	else
		addon.petbuttons_template();
	end
end

petbar:RegisterEvent('PET_BAR_HIDE');
petbar:RegisterEvent('PET_BAR_UPDATE');
petbar:RegisterEvent('PET_BAR_UPDATE_COOLDOWN');
petbar:RegisterEvent('PET_BAR_UPDATE_USABLE');
petbar:RegisterEvent('PLAYER_CONTROL_GAINED');
petbar:RegisterEvent('PLAYER_CONTROL_LOST');
petbar:RegisterEvent('PLAYER_FARSIGHT_FOCUS_CHANGED');
petbar:RegisterEvent('PLAYER_LOGIN');
petbar:RegisterEvent('UNIT_AURA');
petbar:RegisterEvent('UNIT_FLAGS');
petbar:RegisterEvent('UNIT_PET');
petbar:SetScript('OnEvent',OnEvent);

-- Initialization tracking similar to RetailUI
local petBarInitialized = false

-- ✅ INICIALIZACIÓN TARDÍA USANDO NUEVO SISTEMA
event:RegisterEvents(function()
	-- Force initialization after a short delay when player enters world
	local initFrame = CreateFrame("Frame")
	local elapsed = 0
	initFrame:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed >= 1.0 then -- Wait 1 second after entering world
			self:SetScript("OnUpdate", nil)
			-- ✅ USAR NUEVO FRAME DE WIDGETS
			if petbarFrame and not petBarInitialized then
				petbutton_position()
				petBarInitialized = true
			end
			InitializePetbar() -- ✅ NUEVA FUNCIÓN
			DelayedPetInit() -- Start the delayed retry system
		end
	end)
end, 'PLAYER_ENTERING_WORLD');

-- ✅ REFRESH FUNCTION USANDO SISTEMA DE WIDGETS
function addon.RefreshPetbar()
	if InCombatLockdown() then return end
	if not pUiPetBar or not petbarFrame then return end
	
	-- ✅ APLICAR POSICIÓN DESDE WIDGETS (solo si no estamos en editor mode)
	ApplyPetbarPosition()
	
	-- Update button size and spacing
	local btnsize = config.additional.size;
	local space = config.additional.spacing;
	
	-- Reposition pet buttons
	for i = 1, NUM_PET_ACTION_SLOTS do
		local button = _G["PetActionButton"..i];
		if button then
			button:ClearAllPoints()
			button:SetSize(btnsize, btnsize);
			if i == 1 then
				button:SetPoint('BOTTOMLEFT', 0, 0);
			else
				local prevButton = _G["PetActionButton"..(i-1)]
				if prevButton then
					button:SetPoint('LEFT', prevButton, 'RIGHT', space, 0);
				end
			end
		end
	end
	
	-- Update grid visibility - FIXED: Proper empty slot handling
	local grid = config.additional.pet.grid;
	for i = 1, NUM_PET_ACTION_SLOTS do
		local button = _G["PetActionButton"..i];
		if button then
			local name, subtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i);
			
			if grid then
				-- Show all slots when grid is enabled
				button:Show();
				-- If slot is empty, show a background texture to indicate it's an empty slot
				if not name then
					-- Show empty slot appearance
					local icon = _G["PetActionButton"..i.."Icon"];
					if icon then
						icon:SetTexture("Interface\\Buttons\\UI-EmptySlot");
						icon:SetVertexColor(0.5, 0.5, 0.5, 0.5); -- Dimmed appearance
					end
					button:SetChecked(false);
				end
			else
				-- Hide empty slots when grid is disabled
				if not name then
					button:Hide();
				end
			end
		end
	end
end

-- Reset petbar initialization (for debugging or force re-init)
function addon.ResetPetbar()
	print("DragonUI: Resetting petbar initialization")
	petBarInitialized = false
	if not InCombatLockdown() and pUiPetBar then
		petbutton_position()
		petBarInitialized = true
		print("DragonUI: Petbar reinitialized successfully")
	else
		print("DragonUI: Cannot reset petbar - in combat or frame missing")
	end
end

-- Debug function to check petbar status
function addon.GetPetbarStatus()
	return {
		initialized = petBarInitialized,
		frameExists = pUiPetBar ~= nil,
		widgetFrameExists = petbarFrame ~= nil,
		inCombat = InCombatLockdown(),
		hasPet = UnitExists("pet"),
		updateHooked = petbar.updateHooked or false
	}
end

-- ✅ REGISTRO EN SISTEMA CENTRALIZADO - INTEGRACIÓN COMPLETA
local function RegisterPetbarEditor()
    if addon.RegisterEditableFrame and petbarFrame then
        addon:RegisterEditableFrame({
            name = "Petbar",
            frame = petbarFrame,
            configPath = {"widgets", "petbar"}, -- ✅ CORREGIDO: Array como otros frames
            showTest = PetbarEditor.ShowPetbarTest, 
            hideTest = PetbarEditor.HidePetbarTest  
        })
        print("|cFF00FF00[DragonUI]|r Petbar registered with centralized editor system")
    else
        print("|cFFFF0000[DragonUI]|r Failed to register Petbar - system not ready")
    end
end

-- ✅ REGISTRAR INMEDIATAMENTE COMO CASTBAR - NO ESPERAR EVENTOS
RegisterPetbarEditor()
