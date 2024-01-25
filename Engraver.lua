local addonName, Addon = ...

EngraverFrameMixin = {};
EngraverCategoryFrameBaseMixin = {};
EngraverCategoryFrameShowAllMixin = {}
EngraverCategoryFramePopUpMenuMixin = {}
EngraverRuneButtonMixin = {}
EngraverNoRunesFrameMixin = {};

local EngraverDisplayModes = {
	{ text = "Show All", mixin = EngraverCategoryFrameShowAllMixin },
	{ text = "Pop-up Menu", mixin = EngraverCategoryFramePopUpMenuMixin }
}
Addon.EngraverDisplayModes = EngraverDisplayModes
Addon.GetCurrentDisplayMode = function() return EngraverDisplayModes[EngraverOptions.DisplayMode+1] end

local EngraverLayoutDirections = {
	{ text = "Left to Right", categoryPoint = "TOPLEFT", categoryRelativePoint = "BOTTOMLEFT",	runePoint = "LEFT",		runeRelativePoint = "RIGHT"		},
	{ text = "Top to Bottom", categoryPoint = "TOPLEFT", categoryRelativePoint = "TOPRIGHT",	runePoint = "TOP",		runeRelativePoint = "BOTTOM"	},
	{ text = "Right to Left", categoryPoint = "TOPLEFT", categoryRelativePoint = "BOTTOMLEFT",	runePoint = "RIGHT",	runeRelativePoint = "LEFT"		},
	{ text = "Bottom to Top", categoryPoint = "TOPLEFT", categoryRelativePoint = "TOPRIGHT",	runePoint = "BOTTOM",	runeRelativePoint = "TOP"		}
}
local EngraverLayout = {
	LeftToRight = 0,
	TopToBottom = 1,
	RightToLeft = 2,
	BottomToTop = 3,
}
Addon.EngraverLayoutDirections = EngraverLayoutDirections
Addon.GetCurrentLayoutDirection = function() return EngraverLayoutDirections[EngraverOptions.LayoutDirection+1] end

-------------------
-- EngraverFrame --
-------------------

function EngraverFrameMixin:OnLoad()
	self.categoryFramePool = CreateFramePool("Frame", self, "EngraverCategoryFrameTemplate",  function(framePool, frame)
		FramePool_HideAndClearAnchors(framePool, frame);
	end);
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("RUNE_UPDATED");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("UPDATE_INVENTORY_ALERTS");
	self:RegisterEvent("NEW_RECIPE_LEARNED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterForDrag("RightButton")
end

function EngraverFrameMixin:OnEvent(event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:Initialize()
	elseif (event == "RUNE_UPDATED") then
		self:UpdateLayout()
	elseif (event == "NEW_RECIPE_LEARNED") then
		self:LoadCategories()
	elseif (event == "PLAYER_EQUIPMENT_CHANGED") then
		self:UpdateLayout()
	elseif (event == "UPDATE_INVENTORY_ALERTS") then
		self:UpdateLayout()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		-- Update after leaving combat lockdown in case settings changed during combat
		self:UpdateLayout()
	end
end

function EngraverFrameMixin:Initialize()
	self.equipmentSlotFrameMap = {}
	self:RegisterOptionChangedCallbacks()
	self:LoadCategories()
end

function EngraverFrameMixin:RegisterOptionChangedCallbacks()
	function register(optionName, callback)
		EngraverOptionsCallbackRegistry:RegisterCallback(optionName, function(_, newValue) if not InCombatLockdown() then callback(self, newValue) end end, self)
	end
	register("UIScale", self.SetScaleAdjustLocation)
	register("DisplayMode", self.UpdateLayout)
	register("LayoutDirection", self.UpdateLayout)
	register("HideDragTab", self.UpdateLayout)
	register("ShowFilterSelector", self.UpdateLayout)
	register("CurrentFilter", self.LoadCategories) -- index stored in EngraverOptions.CurrentFilter changed
	register("FiltersChanged", self.LoadCategories) -- data inside EngraverFilters changed
end
	
function EngraverFrameMixin:LoadCategories()
	if not InCombatLockdown() then
		self:ResetCategories()
		C_Engraving:ClearAllCategoryFilters();
		C_Engraving.RefreshRunesList();
		self.categories = C_Engraving.GetRuneCategories(false, false);
		if #self.categories > 0 then
			for c, category in ipairs(self.categories) do
				local runes = Addon.Filters:GetFilteredRunesForCategory(category, false)
				if #runes > 0 then
					local categoryFrame = self.categoryFramePool:Acquire()
					categoryFrame:Show()
					self.equipmentSlotFrameMap[category] = categoryFrame
					local knownRunes = C_Engraving.GetRunesForCategory(category, true);	
					categoryFrame:SetCategory(category, runes, knownRunes)
					categoryFrame:SetDisplayMode(Addon.GetCurrentDisplayMode().mixin)
				end
			end
		end
		self:UpdateLayout()
	end
end

function EngraverFrameMixin:ResetCategories()
	self.categories = nil
	self.equipmentSlotFrameMap = {}
	for categoryFrame in self.categoryFramePool:EnumerateActive() do
		if categoryFrame.TearDownDisplayMode then
			categoryFrame:TearDownDisplayMode()
		end
	end
	self.categoryFramePool:ReleaseAll()
end

function EngraverFrameMixin:UpdateCategory(equipmentSlot)
	if self.equipmentSlotFrameMap then
		local categoryFrame = self.equipmentSlotFrameMap[equipmentSlot]
		if categoryFrame and categoryFrame.UpdateCategoryLayout then
			categoryFrame:UpdateCategoryLayout()
		end
	end
end

function EngraverFrameMixin:UpdateLayout(...)
	if not InCombatLockdown() and self.categories ~= nil then
		if EngraverOptions.LayoutDirection == EngraverLayout.LeftToRight or EngraverOptions.LayoutDirection == EngraverLayout.RightToLeft then
			self:SetSize(40, 40 * #self.categories)
		else
			self:SetSize(40 * #self.categories, 40)
		end
		self:SetScale(EngraverOptions.UIScale or 1.0)
		local layoutDirection = Addon.GetCurrentLayoutDirection()
		if self.equipmentSlotFrameMap then
			local displayMode = Addon.GetCurrentDisplayMode()
			local prevCategoryFrame = nil
			for category, categoryFrame in pairs(self.equipmentSlotFrameMap) do
				if categoryFrame then
					categoryFrame:SetDisplayMode(displayMode.mixin)
					if prevCategoryFrame == nil then
						categoryFrame:SetPoint(layoutDirection.categoryPoint)
					else
						categoryFrame:SetPoint(layoutDirection.categoryPoint, prevCategoryFrame, layoutDirection.categoryRelativePoint)
					end
					if categoryFrame.UpdateCategoryLayout then
						categoryFrame:UpdateCategoryLayout(layoutDirection)
					end
					prevCategoryFrame = categoryFrame
				end
			end
		end
		self:UpdateDragTabLayout()
	end
end

Addon.DragTabLayoutData = {
	{-- Left to Right
		textRotation		= 90,
		textOffset			= CreateVector2D(-7, -5),
		filterButtonOffset	= CreateVector2D(-3, 0),
		offset				= CreateVector2D(10, 0),
		point				= "RIGHT", 
		relativePoint		= "LEFT",
		swapTabDimensions	= true
	},
	{-- Top to Bottom
		textRotation		= 0,
		textOffset			= CreateVector2D(0, 2),
		filterButtonOffset	= CreateVector2D(0, 2),
		offset				= CreateVector2D(0, -10),
		point				= "BOTTOM", 
		relativePoint		= "TOP",
		swapTabDimensions	= false
	},		
	{-- Right to Left
		textRotation		= 270,
		textOffset			= CreateVector2D(7, -5),
		filterButtonOffset	= CreateVector2D(2, 0),
		offset				= CreateVector2D(-10, 0),
		point				= "LEFT", 
		relativePoint		= "RIGHT",
		swapTabDimensions	= true
	},	
	{-- Bottom to Top
		textRotation		= 0,
		textOffset			= CreateVector2D(0, -2),
		filterButtonOffset	= CreateVector2D(0, -3),
		offset				= CreateVector2D(0, 10),
		point				= "TOP", 
		relativePoint		= "BOTTOM",
		swapTabDimensions	= false
	}	
}

function EngraverFrameMixin:UpdateDragTabLayout()
	if self.dragTab then
		local layoutIndex = EngraverOptions.LayoutDirection+1
		local layoutData = Addon.DragTabLayoutData[layoutIndex]
		-- dragTab
		self.dragTab:SetShown(not EngraverOptions.HideDragTab);
		self.dragTab:ClearAllPoints()
		self.dragTab:UpdateSizeForLayout(layoutData)
		self.dragTab:SetPoint(layoutData.point, self, layoutData.relativePoint, layoutData.offset:GetXY())
		self:UpdateDragTabText(layoutData)
		self:UpdateFilterButtonsLayout(layoutData)
	end
end

function EngraverFrameMixin:UpdateFilterButtonsLayout(layoutData)
	-- visibility
	UnregisterStateDriver(self.filterRightButton, "visibility")
	UnregisterStateDriver(self.filterLeftButton, "visibility")
	UnregisterStateDriver(self.filterUpButton, "visibility")
	UnregisterStateDriver(self.filterDownButton, "visibility")
	local show = not EngraverOptions.HideDragTab and EngraverOptions.ShowFilterSelector
	if layoutData.swapTabDimensions then
		self.filterRightButton:SetShown(false)
		self.filterLeftButton:SetShown(false)
		self.filterUpButton:SetShown(show)
		self.filterDownButton:SetShown(show)
		if show then
			RegisterStateDriver(self.filterUpButton, "visibility", "[combat]hide;show")
			RegisterStateDriver(self.filterDownButton, "visibility", "[combat]hide;show")
		end
	else
		self.filterRightButton:SetShown(show)
		self.filterLeftButton:SetShown(show)
		self.filterUpButton:SetShown(false)
		self.filterDownButton:SetShown(false)
		if show then
			RegisterStateDriver(self.filterRightButton, "visibility", "[combat]hide;show")
			RegisterStateDriver(self.filterLeftButton, "visibility", "[combat]hide;show")
		end
	end
	-- anchors
	local filterButtonOffsetX, filterButtonOffsetY = layoutData.filterButtonOffset:GetXY()
	function updatefilterButtonOffset(filterButton)
		local point, relativeTo, relativePoint, filterX, filterY = filterButton:GetPoint()
		filterButton:SetPoint(point, relativeTo, relativePoint, filterButtonOffsetX, filterButtonOffsetY)
	end
	updatefilterButtonOffset(self.filterRightButton)
	updatefilterButtonOffset(self.filterLeftButton)
	updatefilterButtonOffset(self.filterUpButton)
	updatefilterButtonOffset(self.filterDownButton)
end

function EngraverFrameMixin:UpdateDragTabText(layoutData)
	if self.dragTab and self.dragTab.Text then
		self.dragTab.Text:ClearAllPoints()
		local rotation = rad(layoutData.textRotation)
		self.dragTab.Text:SetRotation(rotation)
		local tabText = "Engraver"
		if EngraverOptions.ShowFilterSelector then
			local filter = Addon.Filters:GetCurrentFilter()
			if filter then
				tabText = filter.Name
			else 
				tabText = Addon.Filters.NO_FILTER_DISPLAY_STRING
			end	
		end
		self.dragTab.Text:SetPoint("CENTER", self.dragTab, "CENTER", layoutData.textOffset:GetXY())
		self.dragTab.Text:SetText(tabText)
	end
end

function EngraverFrameMixin:SetScaleAdjustLocation(scale)
	local div = self:GetScale() / scale
	local x, y = self:GetLeft() * div, self:GetTop() * div
	self:ClearAllPoints()
	self:SetScale(scale)
	self:SetPoint("TopLeft", self:GetParent(), "BottomLeft", x, y)
end

-----------------------
-- CategoryFrameBase --
-----------------------

function EngraverCategoryFrameBaseMixin:OnLoad()
	self.runeButtonPool = CreateFramePool("Button", self, "EngraverRuneButtonTemplate")
	self.runeButtons = {}
end

function EngraverCategoryFrameBaseMixin:SetCategory(category, runes, knownRunes)
	self.category = category
	self:SetRunes(runes, knownRunes)
	self:LoadEmptyRuneButton()
end

function EngraverCategoryFrameBaseMixin:SetRunes(runes, knownRunes)
	self.runeButtonPool:ReleaseAll()
	self.runeButtons = {}
	for r, rune in ipairs(runes) do
		local runeButton = self.runeButtonPool:Acquire()
		self.runeButtons[r] = runeButton
		local isKnown = self:IsRuneKnown(rune, knownRunes)
		runeButton:SetRune(rune, self.category, isKnown)
	end
end

function EngraverCategoryFrameBaseMixin:LoadEmptyRuneButton()
	if self.emptyRuneButton then
		-- TODO figure out how to get slotName from slotId using API or maybe a constant somewhere
		local tempSlotsMap = {
			[INVSLOT_CHEST] = "CHESTSLOT",
			[INVSLOT_LEGS] = "LEGSSLOT",
			[INVSLOT_HAND] = "HANDSSLOT"
		}
		if self.category then
			local slotName = tempSlotsMap[self.category]
			if slotName then
				local id, textureName, checkRelic = GetInventorySlotInfo(slotName);
				self:SetID(id);
				self.emptyRuneButton.icon:SetTexture(textureName);
			end
		end
		self.emptyRuneButton:RegisterForClicks("LeftButtonUp", "RightButtonDown", "RightButtonUp")
	end
end

function EngraverCategoryFrameBaseMixin:IsRuneKnown(runeToCheck, knownRunes)
	for r, rune in ipairs(knownRunes) do
		if rune.skillLineAbilityID == runeToCheck.skillLineAbilityID then
			return true
		end
	end
end

function EngraverCategoryFrameBaseMixin:GetRuneButton(skillLineAbilityID)
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if runeButton.skillLineAbilityID == skillLineAbilityID then
				return runeButton
			end
		end
	end
end

function EngraverCategoryFrameBaseMixin:UpdateCategoryLayout(layoutDirection)
	self:DetermineActiveAndInactiveButtons()
	if self.activeButton then
		local isBroken = GetInventoryItemBroken("player", self.category)
		self.activeButton:SetBlinking(isBroken, 1.0, 0.0, 0.0)
	end
	if self.UpdateCategoryLayoutImpl then
		self:UpdateCategoryLayoutImpl(layoutDirection) -- implemented by "subclasses"/mixins
	end
end

function EngraverCategoryFrameBaseMixin:DetermineActiveAndInactiveButtons()
	self.activeButton = nil
	self.inactiveButtons = {}
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if C_Engraving.IsRuneEquipped(runeButton.skillLineAbilityID) then
				self.activeButton = runeButton
			else
				table.insert(self.inactiveButtons, runeButton)
			end
		end
	end
end

function EngraverCategoryFrameBaseMixin:SetDisplayMode(displayModeMixin)
	if self.TearDownDisplayMode then
		self:TearDownDisplayMode()
	end
	Mixin(self, displayModeMixin)
	if self.SetUpDisplayMode then
		self:SetUpDisplayMode()
	end
end

--------------------------
-- CategoryFrameShowAll --
--------------------------

function EngraverCategoryFrameShowAllMixin:UpdateCategoryLayoutImpl(layoutDirection)
	-- update position of each button and highlight the active one
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:ClearAllPoints()
		end
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:SetShown(true)
			runeButton:SetHighlighted(false)
			if r == 1 then
				runeButton:SetAllPoints()
			else
				runeButton:SetPoint(layoutDirection.runePoint, self.runeButtons[r-1], layoutDirection.runeRelativePoint)
			end
			if self.activeButton == nil then
				runeButton:SetBlinking(runeButton.isKnown)
			end
		end
		if self.activeButton and not self.activeButton.isBlinking then
			self.activeButton:SetHighlighted(true)
		end
	end
end

function EngraverCategoryFrameShowAllMixin:SetUpDisplayMode()
	-- do nothing for now
end

function EngraverCategoryFrameShowAllMixin:TearDownDisplayMode()
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:SetHighlighted(false)
			runeButton:ResetColors();
			runeButton:SetBlinking(false)
		end
	end
end

----------------------------
-- CategoryFramePopUpMenu --
----------------------------

function EngraverCategoryFramePopUpMenuMixin:AreAnyRunesKnown()
	for r, runeButton in ipairs(self.runeButtons) do
		if runeButton.isKnown then
			return true
		end
	end
	return false
end

function EngraverCategoryFramePopUpMenuMixin:UpdateCategoryLayoutImpl(layoutDirection)
	-- update visibility and position of each button
	if self.emptyRuneButton then
		self.emptyRuneButton:Hide()
	end
	if self.runeButtons then
		local showInactives = self:IsMouseOverAnyButtons()
		self.activeButton = self.activeButton or self.emptyRuneButton
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:ClearAllPoints()
		end
		if self.activeButton then
			self.activeButton:SetShown(true)
			self.activeButton:SetAllPoints()
			if self.inactiveButtons then
				local prevButton = self.activeButton
				for r, runeButton in ipairs(self.inactiveButtons) do
					runeButton:SetShown(showInactives)
					RegisterStateDriver(runeButton, "visibility", "[combat]hide")
					runeButton:ClearAllPoints()
					runeButton:SetPoint(layoutDirection.runePoint, prevButton, layoutDirection.runeRelativePoint)
					prevButton = runeButton
				end
			end
			if self.activeButton == self.emptyRuneButton then
				self.emptyRuneButton:SetBlinking(self:AreAnyRunesKnown())
			end
		end
	end
end

function EngraverCategoryFramePopUpMenuMixin:SetUpDisplayMode()
	if self.emptyRuneButton then
		self.emptyRuneButton:RegisterCallback("PostOnEnter", self.OnRuneButtonPostEnter, self)
		self.emptyRuneButton:RegisterCallback("PostOnLeave", self.OnRuneButtonPostLeave, self)
	end
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:RegisterCallback("PostOnEnter", self.OnRuneButtonPostEnter, self)
			runeButton:RegisterCallback("PostOnLeave", self.OnRuneButtonPostLeave, self)
		end
	end
end

function EngraverCategoryFramePopUpMenuMixin:TearDownDisplayMode()
	if self.emptyRuneButton then
		self.emptyRuneButton:UnregisterCallback("PostOnEnter", self)
		self.emptyRuneButton:UnregisterCallback("PostOnLeave", self)
		self.emptyRuneButton:Hide()
	end
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:UnregisterCallback("PostOnEnter", self)
			runeButton:UnregisterCallback("PostOnLeave", self)
			UnregisterStateDriver(runeButton, "visibility")
		end
	end
end

function EngraverCategoryFramePopUpMenuMixin:OnRuneButtonPostEnter()
	self:SetInactiveButtonsShown(true) 
end

function EngraverCategoryFramePopUpMenuMixin:OnRuneButtonPostLeave()
	self:SetInactiveButtonsShown(self:IsMouseOverAnyButtons())
end

function EngraverCategoryFramePopUpMenuMixin:IsMouseOverAnyButtons()
	if self.emptyRuneButton and self.emptyRuneButton:IsMouseOver() then
		return true
	end
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if runeButton:IsMouseOver() then
				return true
			end
		end
	end
	return false
end

function EngraverCategoryFramePopUpMenuMixin:SetInactiveButtonsShown(isShown)
	if not InCombatLockdown() then
		for r, runeButton in ipairs(self.inactiveButtons) do
			runeButton:SetShown(isShown)
		end
	end
end

----------------
-- RuneButton --
----------------

function EngraverRuneButtonMixin:OnLoad()
	self.Border:SetVertexColor(0.0, 1.0, 0.0);
	Mixin(self, CallbackRegistryMixin);
	self:SetUndefinedEventsAllowed(true)
	self:OnLoad() -- NOTE not an infinite loop because mixing in CallbackRegistryMixin redefines OnLoad
end

function EngraverRuneButtonMixin:SetRune(rune, category, isKnown)
	self.category = category
	self.icon:SetTexture(rune.iconTexture);
	self.tooltipName = rune.name;
	self.skillLineAbilityID = rune.skillLineAbilityID;
	self.isKnown = isKnown;
	self:RegisterForClicks("LeftButtonUp", "RightButtonDown", "RightButtonUp")
	if self.icon then
		self.icon:SetAllPoints()
	end
	self:ResetColors()
end

function EngraverRuneButtonMixin:ResetColors()
	self.SpellHighlightTexture:SetVertexColor(1.0, 1.0, 1.0);
	if self.isKnown then
		self.icon:SetVertexColor(1.0, 1.0, 1.0);
		self.NormalTexture:SetVertexColor(1.0, 1.0, 1.0);
	else
		self.icon:SetVertexColor(0.2, 0.0, 0.0);
		self.NormalTexture:SetVertexColor(0.2, 0.0, 0.0);
	end
end

function EngraverRuneButtonMixin:OnClick()
	local buttonClicked = GetMouseButtonClicked();
	if buttonClicked == "LeftButton" then
		self:TryEngrave()
	elseif buttonClicked  == "RightButton" and EngraverOptions.EnableRightClickDrag then
		if IsKeyDown(buttonClicked) then
			EngraverFrame:StartMoving()
		else
			EngraverFrame:StopMovingOrSizing()
		end
	end
end

function EngraverRuneButtonMixin:TryEngrave()
	if self.category and self.skillLineAbilityID and not InCombatLockdown() then
		if not C_Engraving.IsRuneEquipped(self.skillLineAbilityID) then
			local itemId, unknown = GetInventoryItemID("player", self.category)
			if itemId then
				ClearCursor()
				C_Engraving.CastRune(self.skillLineAbilityID);
				UseInventoryItem(self.category);
				if StaticPopup1.which == "REPLACE_ENCHANT" then
					ReplaceEnchant()
					StaticPopup_Hide("REPLACE_ENCHANT")
				end
				ClearCursor()
			else
				UIErrorsFrame:AddExternalErrorMessage("Cannot engrave rune, equipment slot is empty!")
			end
		end
	end
end

function EngraverRuneButtonMixin:SetHighlighted(isHighlighted)
	if self.isKnown then
		if ( isHighlighted ) then
			self.Border:SetShown(true)
			self.icon:SetVertexColor(1.0, 1.0, 1.0)
			self.NormalTexture:SetVertexColor(1.0, 1.0, 1.0);
		else
			self.Border:SetShown(false)
			self.icon:SetVertexColor(0.5, 0.5, 0.5)
			self.NormalTexture:SetVertexColor(0.5, 0.5, 0.5);
		end
	end
end

function EngraverRuneButtonMixin:SetBlinking(isBlinking, r, g, b)
	self.isBlinking = isBlinking
	self.SpellHighlightTexture:SetVertexColor(r or 1.0, g or 1.0, b or 1.0)
	SharedActionButton_RefreshSpellHighlight(self, isBlinking)
end

function EngraverRuneButtonMixin:OnEnter()
	if self.skillLineAbilityID and EngraverOptions.HideTooltip ~= true then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetEngravingRune(self.skillLineAbilityID);
		self.showingTooltip = true;
		GameTooltip:Show();
	end
	self:TriggerEvent("PostOnEnter")
end

function EngraverRuneButtonMixin:OnLeave()
	GameTooltip_Hide();
	self.showingTooltip = false;
	self:TriggerEvent("PostOnLeave")
end

-------------
-- DragTab --
-------------

EngraverDragTabMixin = {}

function EngraverDragTabMixin:OnMouseDown(button)
	if not InCombatLockdown() then
		if button == "RightButton" then
			Settings.OpenToCategory(addonName);
		elseif button == "LeftButton" then
			local parent = self:GetParent()
			if parent and parent.StartMoving then
				parent:StartMoving();
			end
		end
	end
end

function EngraverDragTabMixin:OnMouseUp(button)
	local parent = self:GetParent()
	if parent and parent.StopMovingOrSizing then
		parent:StopMovingOrSizing();
	end
end

function EngraverDragTabMixin:UpdateSizeForLayout(layoutData)
	if not self.originalSize then
		self.originalSize = CreateVector2D(self:GetSize())
	end
	if layoutData.swapTabDimensions then
		self:SetSize(self.originalSize.y, self.originalSize.x)
	else
		self:SetSize(self.originalSize.x, self.originalSize.y)
	end
end

------------------
-- FilterButton --
------------------

EngraverFilterButtonMixin = CreateFromMixins(MinimalScrollBarStepperScriptsMixin)

function EngraverFilterButtonMixin:OnButtonStateChanged()
	MinimalScrollBarStepperScriptsMixin.OnButtonStateChanged(self)
	if self.HighlightTexture then
		self.HighlightTexture:SetShown(self.over)
	end
end

function EngraverFilterButtonMixin:OnClick()
	if not InCombatLockdown() then
		if self.direction > 0 then
			Addon.Filters:SetCurrentFilterNext()
		else
			Addon.Filters:SetCurrentFilterPrev()
		end
	end
end