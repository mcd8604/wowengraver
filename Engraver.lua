local addonName, Addon = ...

function Addon:TryEngrave(equipmentSlot, skillLineAbilityID)
	if equipmentSlot and skillLineAbilityID then
		local equippedRune = C_Engraving.GetRuneForEquipmentSlot(equipmentSlot)
		if (not equippedRune or equippedRune.skillLineAbilityID ~= skillLineAbilityID) then
			local itemId, _ = GetInventoryItemID("player", category)
			if itemId then
				ClearCursor()
				C_Engraving.CastRune(skillLineAbilityID);
				UseInventoryItem(equipmentSlot);
				if StaticPopup1.which == "REPLACE_ENCHANT" then
					ReplaceEnchant()
					StaticPopup_Hide("REPLACE_ENCHANT")
				end
				ClearCursor()
				return true
			else
				UIErrorsFrame:AddExternalErrorMessage("Cannot engrave rune, equipment slot is empty!")
			end
		end
	end
	return false
end

local EngraverLayoutDirections = {
	{ 
		text 					= "Left to Right",
		categoryPoint			= "TOPLEFT",
		categoryRelativePoint	= "BOTTOMLEFT",
		runePoint				= "LEFT",
		runeRelativePoint		= "RIGHT",
		textRotation			= 90,
		slotLabelOffset			= CreateVector2D(-8, 0),
		textOffset				= CreateVector2D(-7, -5),
		filterButtonOffset		= CreateVector2D(-3, 0),
		offset					= CreateVector2D(10, 0),
		point					= "RIGHT", 
		relativePoint			= "LEFT",
		swapTabDimensions		= true	
	},
	{ 
		text					= "Top to Bottom",
		categoryPoint			= "TOPLEFT",
		categoryRelativePoint	= "TOPRIGHT",
		runePoint				= "TOP",
		runeRelativePoint		= "BOTTOM",
		textRotation			= 0,
		slotLabelOffset			= CreateVector2D(0, 8),
		textOffset				= CreateVector2D(0, 2),
		filterButtonOffset		= CreateVector2D(0, 2),
		offset					= CreateVector2D(0, -10),
		point					= "BOTTOM", 
		relativePoint			= "TOP",
		swapTabDimensions		= false
	},
	{ 
		text					= "Right to Left",
		categoryPoint			= "TOPLEFT",
		categoryRelativePoint	= "BOTTOMLEFT",
		runePoint				= "RIGHT",
		runeRelativePoint		= "LEFT",
		textRotation			= 270,
		slotLabelOffset			= CreateVector2D(8, 0),
		textOffset				= CreateVector2D(7, -5),
		filterButtonOffset		= CreateVector2D(2, 0),
		offset					= CreateVector2D(-10, 0),
		point					= "LEFT",
		relativePoint			= "RIGHT",
		swapTabDimensions		= true
	},
	{ 
		text					= "Bottom to Top",
		categoryPoint			= "TOPLEFT", 
		categoryRelativePoint	= "TOPRIGHT",
		runePoint				= "BOTTOM",
		runeRelativePoint		= "TOP",
		textRotation			= 0,
		slotLabelOffset			= CreateVector2D(0, -8),
		textOffset				= CreateVector2D(0, -2),
		filterButtonOffset		= CreateVector2D(0, -3),
		offset					= CreateVector2D(0, 10),
		point					= "TOP",
		relativePoint			= "BOTTOM",
		swapTabDimensions		= false
	}
}
local EngraverLayout = {
	LeftToRight = 0,
	TopToBottom = 1,
	RightToLeft = 2,
	BottomToTop = 3,
}
Addon.EngraverLayoutDirections = EngraverLayoutDirections
Addon.GetCurrentLayoutDirection = function() return EngraverLayoutDirections[Addon:GetOptions().LayoutDirection+1] end

-------------------
-- EngraverFrame --
-------------------

EngraverFrameMixin = {};

function EngraverFrameMixin:OnLoad()
	self:LoadCategoryPool()
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("RUNE_UPDATED");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("UPDATE_INVENTORY_ALERTS");
	self:RegisterEvent("NEW_RECIPE_LEARNED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterForDrag("RightButton")
end

local function HookMouseOver_UpdateVisibilityModeAlpha(mouseOverFrame, engraverFrame)
	mouseOverFrame:HookScript("OnEnter", function() engraverFrame:UpdateVisibilityModeAlpha() end)
	mouseOverFrame:HookScript("OnLeave", function() engraverFrame:UpdateVisibilityModeAlpha() end)
end

function EngraverFrameMixin:LoadCategoryPool()
	self.categoryFramePool = CreateFramePool("Frame", self, "EngraverCategoryFrameTemplate", nil, false, function(categoryFrame) 
		-- categoryFrame frameInitFunc - drive updates for ShowOnMouseOver VisibilityMode
		for i, child in ipairs({categoryFrame:GetChildren()}) do
			HookMouseOver_UpdateVisibilityModeAlpha(child, self)
		end
		categoryFrame.runeButtonPool = CreateFramePool("Button", categoryFrame, "EngraverRuneButtonTemplate",  nil, false, function(runeButton)
			-- runeButton frameInitFunc - drive updates for ShowOnMouseOver VisibilityMode
			HookMouseOver_UpdateVisibilityModeAlpha(runeButton, self)
		end)
	end);
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
	for i, child in ipairs({self:GetChildren()}) do
		HookMouseOver_UpdateVisibilityModeAlpha(child, self)
	end
	self:LoadCategories()
end

function EngraverFrameMixin:RegisterOptionChangedCallbacks()
	function register(optionName, callback)
		EngraverOptionsCallbackRegistry:RegisterCallback(optionName, function(_, newValue) callback(self, newValue) end , self)
	end
	register("UIScale", self.SetScaleAdjustLocation)
	register("DisplayMode", self.UpdateLayout)
	register("LayoutDirection", self.UpdateLayout)
	register("VisibilityMode", self.UpdateVisibilityMode)
	register("HideDragTab", self.UpdateLayout)
	register("ShowFilterSelector", self.UpdateLayout)
	register("HideSlotLabels", self.UpdateLayout)
	register("HideUndiscoveredRunes", self.LoadCategories)
	register("CurrentFilter", self.LoadCategories) -- index stored in EngraverOptions.CurrentFilter changed
	register("FiltersChanged", self.LoadCategories) -- data inside EngraverFilters changed
	register("OnMultipleSettingsChanged", function() 
		self:SetScaleAdjustLocation(Addon:GetOptions().UIScale or 1.0)
		self:LoadCategories() 
	end)
end

-- NOTE hardcoded map of inventory type (category) to slot ids
Addon.CategoryToSlotId = {
	{1},
	{2},
	{3},
	{4},
	{5},
	{6},
	{7},
	{8},
	{9},
	{10},
	{11, 12},
	{13, 14},
	{16, 17},
	{17},
	{16},
	{15}
}
	
function EngraverFrameMixin:LoadCategories()
	self:ResetCategories()
	C_Engraving:ClearAllCategoryFilters();
	C_Engraving.RefreshRunesList();
	self.categories = C_Engraving.GetRuneCategories(false, Addon:GetOptions().HideUndiscoveredRunes or false);
	self.slots = {}
	if #self.categories > 0 then
		for c, category in ipairs(self.categories) do
			local runes = Addon.Filters:GetFilteredRunesForCategory(category, Addon:GetOptions().HideUndiscoveredRunes or false)
			if #runes > 0 then
				for _, slot in ipairs(Addon.CategoryToSlotId[category]) do
					table.insert(self.slots, slot)
					local categoryFrame = self.categoryFramePool:Acquire()
					categoryFrame:Show()
					self.equipmentSlotFrameMap[slot] = categoryFrame
					local knownRunes = C_Engraving.GetRunesForCategory(category, true);
					categoryFrame:SetCategory(category, runes, knownRunes, slot)
					categoryFrame:SetDisplayMode(Addon.GetCurrentDisplayMode().mixin)
				end
			end
		end
	end
	self:UpdateLayout()
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

function EngraverFrameMixin:GetNumVisibleCategories()
	local numCategories = 0
	for category, categoryFrame in pairs(self.equipmentSlotFrameMap) do
		if #categoryFrame.runeButtons > 0 then
			numCategories = numCategories + 1
		end
	end
	return numCategories
end

function EngraverFrameMixin:UpdateLayout(...)
	EngraverFrame:StopMovingOrSizing()
	self:UpdateVisibilityMode()
	if self.categories ~= nil then
		local layoutDirection = Addon.GetCurrentLayoutDirection()
		self:SetScale(Addon:GetOptions().UIScale or 1.0)
		if self.equipmentSlotFrameMap then
			local displayMode = Addon.GetCurrentDisplayMode()
			local prevCategoryFrame = nil
			for c, slot in ipairs(self.slots) do
				local categoryFrame = self.equipmentSlotFrameMap[slot]
				if categoryFrame then
					categoryFrame:ClearAllPoints()
					categoryFrame:SetDisplayMode(displayMode.mixin)
					if prevCategoryFrame == nil then
						categoryFrame:SetPoint("CENTER")
						local numVisibleCategories = max(1, self:GetNumVisibleCategories())
						local halfSpanDistance = 40 * (numVisibleCategories - 1) / 2
						if layoutDirection.swapTabDimensions then
							categoryFrame:AdjustPointsOffset(0, halfSpanDistance)
						else
							categoryFrame:AdjustPointsOffset(-halfSpanDistance, 0)
						end
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
		self:UpdateDragTabLayout(layoutDirection)
	end
end

function EngraverFrameMixin:UpdateDragTabLayout(layoutData)
	if self.dragTab then
		-- dragTab
		self.dragTab:SetShown(not Addon:GetOptions().HideDragTab);
		self.dragTab:ClearAllPoints()
		self.dragTab:UpdateSizeForLayout(layoutData)
		self.dragTab:SetPoint(layoutData.point, self, layoutData.relativePoint, layoutData.offset:GetXY())
		self:UpdateDragTabText(layoutData)
		self:UpdateFilterButtonsLayout(layoutData)
	end
end

function EngraverFrameMixin:UpdateFilterButtonsLayout(layoutData)
	-- visibility
	local show = not Addon:GetOptions().HideDragTab and Addon:GetOptions().ShowFilterSelector
	if layoutData.swapTabDimensions then
		self.filterRightButton:SetShown(false)
		self.filterLeftButton:SetShown(false)
		self.filterUpButton:SetShown(show)
		self.filterDownButton:SetShown(show)
	else
		self.filterRightButton:SetShown(show)
		self.filterLeftButton:SetShown(show)
		self.filterUpButton:SetShown(false)
		self.filterDownButton:SetShown(false)
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
		if Addon:GetOptions().ShowFilterSelector then
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

do
	local function isMouseOverAnyChildren(frame)
		for i, child in ipairs({frame:GetChildren()}) do
			if child:IsMouseMotionFocus() or isMouseOverAnyChildren(child) then
				return true
			end
		end
	end

	function EngraverFrameMixin:UpdateVisibilityModeAlpha()
		if Addon:GetOptions().VisibilityMode == "ShowOnMouseOver" then
			local alpha = isMouseOverAnyChildren(self) and 1.0 or 0.0
			self:SetAlpha(alpha)
		else
			self:SetAlpha(1.0)
		end
		-- Hide all the rune button cooldown frames if EngraverFrame is pseudo-hidden from VisibilityMode.ShowOnMouseOver (otherwise, bling animation will still show)
		if self.equipmentSlotFrameMap then
			for c, categoryFrame in pairs(self.equipmentSlotFrameMap) do
				for r, runeButton in ipairs(categoryFrame.runeButtons) do
					runeButton:UpdateCooldownShown()
				end
			end
		end
	end

	local function HandleSyncCharacterPane()
		if Addon:GetOptions().VisibilityMode == "SyncCharacterPane" then
			EngraverFrame:SetShown(CharacterFrame:IsShown() and PaperDollFrame:IsShown()) 
		end 
	end

	PaperDollFrame:HookScript("OnShow", HandleSyncCharacterPane)
	PaperDollFrame:HookScript("OnHide", HandleSyncCharacterPane)

	function EngraverFrameMixin:UpdateVisibilityMode()
		if not InCombatLockdown() then
			UnregisterStateDriver(self, "visibility")  
			if Addon:GetOptions().VisibilityMode == "ShowAlways" then
				self:Show()
			elseif Addon:GetOptions().VisibilityMode == "HideInCombat" then
				RegisterStateDriver(self, "visibility", "[combat]hide;show")
			elseif Addon:GetOptions().VisibilityMode == "HoldKeybind" then
				self:Hide()
			end
			HandleSyncCharacterPane()
			self:UpdateVisibilityModeAlpha()
		end
	end
end

function EngraverFrameMixin:FindRuneButton(nameOrID)
	if nameOrID ~= nil and strlen(nameOrID) > 0 then
		for category, categoryFrame in pairs(EngraverFrame.equipmentSlotFrameMap) do
			for r, runeButton in ipairs(categoryFrame.runeButtons) do
				if runeButton.tooltipName == nameOrID then
					return runeButton
				else 
					local parsedID = tonumber(nameOrID)
					if runeButton.spellID == parsedID or runeButton.skillLineAbilityID == parsedID then
						return runeButton
					end
				end
			end
		end
	end
	return nil
end

-----------------------
-- CategoryFrameBase --
-----------------------

EngraverCategoryFrameBaseMixin = {};

function EngraverCategoryFrameBaseMixin:OnLoad()
	self.runeButtonPool = CreateFramePool("Button", self, "EngraverRuneButtonTemplate")
	self.runeButtons = {}
end

function EngraverCategoryFrameBaseMixin:SetCategory(category, runes, knownRunes, slot)
	self.category = category
	self.slotId = slot
	self.slotLabel:SetCategory(category)
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
		runeButton:SetRune(rune, self.category, isKnown, self.slotId)
	end
end

do
	-- TODO figure out how to get slotName from slotId using API or maybe a constant somewhere
	local slotNames = {
		"HEADSLOT",
		"NECKSLOT",
		"SHOULDERSLOT",
		"SHIRTSLOT",
		"CHESTSLOT",
		"WAISTSLOT",
		"LEGSSLOT",
		"FEETSLOT",
		"WRISTSLOT",
		"HANDSSLOT",
		"FINGER0SLOT",
		"FINGER1SLOT",
		"TRINKET0SLOT",
		"TRINKET1SLOT",
		"BACKSLOT",
		"MAINHANDSLOT",
		"SECONDARYHANDSLOT",
		"RANGEDSLOT",
		"TABARDSLOT"
	}
	function EngraverCategoryFrameBaseMixin:LoadEmptyRuneButton()
		if self.emptyRuneButton then
			if self.category then
				local slotName = slotNames[self.category]
				if slotName then
					local id, textureName, checkRelic = GetInventorySlotInfo(slotName);
					self:SetID(id);
					self.emptyRuneButton.icon:SetTexture(textureName);
				end
			end
			self.emptyRuneButton:RegisterForClicks("AnyUp", "AnyDown")
		end
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
	self.slotLabel:UpdateLayout(layoutDirection);
	self:DetermineActiveAndInactiveButtons()
	if self.activeButton then
		local isBroken = GetInventoryItemBroken("player", self.category)
		self.activeButton:SetBlinking(isBroken, 1.0, 0.0, 0.0)
	end
end

function EngraverCategoryFrameBaseMixin:DetermineActiveAndInactiveButtons()
	self.activeButton = nil
	self.inactiveButtons = {}
	if self.runeButtons then
		local equippedRune = nil
		if (self.slotId) then
			equippedRune = C_Engraving.GetRuneForEquipmentSlot(self.slotId)
		end
		for r, runeButton in ipairs(self.runeButtons) do
			if (equippedRune and equippedRune.skillLineAbilityID == runeButton.skillLineAbilityID) then
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

function EngraverCategoryFrameBaseMixin:IsMouseOverAnyButtons()
	if self.emptyRuneButton and self.emptyRuneButton:IsShown() and self.emptyRuneButton:IsMouseMotionFocus() then
		return true
	end
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if runeButton:IsMouseMotionFocus() then
				return true
			end
		end
	end
	return false
end

--------------------------
-- CategoryFrameShowAll --
--------------------------

EngraverCategoryFrameShowAllMixin = {}

function EngraverCategoryFrameShowAllMixin:UpdateCategoryLayout(layoutDirection)
	EngraverCategoryFrameBaseMixin.UpdateCategoryLayout(self, layoutDirection)
	-- update position of each button and highlight the active one
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:ClearAllPoints()
		end
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:SetShown(true)
			runeButton:SetHighlighted(false)
			if r == 1 then
				if Addon:GetOptions().HideSlotLabels then
					runeButton:SetAllPoints()
				else
					runeButton:SetPoint(layoutDirection.runePoint, self.slotLabel, layoutDirection.runeRelativePoint, layoutDirection.slotLabelOffset:GetXY())
				end
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

EngraverCategoryFramePopUpMenuMixin = {}

function EngraverCategoryFramePopUpMenuMixin:AreAnyRunesKnown()
	for r, runeButton in ipairs(self.runeButtons) do
		if runeButton.isKnown then
			return true
		end
	end
	return false
end

function EngraverCategoryFramePopUpMenuMixin:UpdateCategoryLayout(layoutDirection)
	EngraverCategoryFrameBaseMixin.UpdateCategoryLayout(self, layoutDirection)
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
			self.activeButton:ClearAllPoints()
			if Addon:GetOptions().HideSlotLabels then
				self.activeButton:SetAllPoints()
			else
				self.activeButton:SetPoint(layoutDirection.runePoint, self.slotLabel, layoutDirection.runeRelativePoint, layoutDirection.slotLabelOffset:GetXY())
			end
			if self.inactiveButtons then
				local prevButton = self.activeButton
				for r, runeButton in ipairs(self.inactiveButtons) do
					runeButton:SetShown(showInactives)
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
		end
	end
end

function EngraverCategoryFramePopUpMenuMixin:OnRuneButtonPostEnter()
	self:SetInactiveButtonsShown(true) 
end

function EngraverCategoryFramePopUpMenuMixin:OnRuneButtonPostLeave()
	self:SetInactiveButtonsShown(self:IsMouseOverAnyButtons())
end

function EngraverCategoryFramePopUpMenuMixin:SetInactiveButtonsShown(isShown)
	for r, runeButton in ipairs(self.inactiveButtons) do
		runeButton:SetShown(isShown)
	end
end

---------------
-- SlotLabel --
---------------

EngraverSlotLabelMixin = {}

function EngraverSlotLabelMixin:SetCategory(category)
	self.slotName:SetText(GetItemInventorySlotInfo(category))
end

function EngraverSlotLabelMixin:UpdateLayout(layoutDirection)
	self:SetShown(not Addon:GetOptions().HideSlotLabels)
	if not self.originalSize then
		self.originalSize = CreateVector2D(self:GetSize())
	end
	if layoutDirection.swapTabDimensions then
		self:SetSize(self.originalSize.y, self.originalSize.x)
	else
		self:SetSize(self.originalSize.x, self.originalSize.y)
	end
	self:ClearAllPoints()
	self:SetPoint(layoutDirection.runePoint, self:GetParent(), layoutDirection.runePoint)
	self.slotName:ClearAllPoints()
	local rotation = rad(layoutDirection.textRotation)
	self.slotName:SetRotation(rotation)
	self.slotName:SetPoint("CENTER", self, "CENTER", layoutDirection.textOffset:GetXY())
end

----------------
-- RuneButton --
----------------

EngraverRuneButtonMixin = {}

function EngraverRuneButtonMixin:OnLoad()
	self.Border:SetVertexColor(0.0, 1.0, 0.0);
	Mixin(self, CallbackRegistryMixin);
	self:SetUndefinedEventsAllowed(true)
	self:OnLoad() -- NOTE not an infinite loop because mixing in CallbackRegistryMixin redefines OnLoad
end

function EngraverRuneButtonMixin:OnEvent(event, ...)	
	if ( event == "ACTIONBAR_UPDATE_COOLDOWN" ) then
		self:UpdateCooldownShown()
		local start, duration, enable, modRate = GetSpellCooldown(self.spellID);
		if duration > 1.5 then
			ActionButton_UpdateCooldown(self);
		end
	end
end

function EngraverRuneButtonMixin:SetRune(rune, category, isKnown, slot)
	self.category = category
	self.icon:SetTexture(rune.iconTexture);
	self.tooltipName = rune.name;
	self.skillLineAbilityID = rune.skillLineAbilityID;
	self.spellID = 1
	if rune.learnedAbilitySpellIDs and #rune.learnedAbilitySpellIDs > 0 then
		self.spellID = rune.learnedAbilitySpellIDs[1]
	end
	if self.spellID then
		self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN");
	else
		self:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN");
	end
	self:UpdateCooldownShown()
	self.isKnown = isKnown;
	self:RegisterForClicks("AnyUp", "AnyDown")
	if self.icon then
		self.icon:SetAllPoints()
	end
	self:ResetColors()
	self.slotId = slot
end

function EngraverRuneButtonMixin:UpdateCooldownShown()
	-- Hide the cooldown frame if EngraverFrame is pseudo-hidden from VisibilityMode.ShowOnMouseOver (otherwise, bling animation will still show)
	self.cooldown:SetShown(EngraverFrame:GetAlpha() > 0)
end

function EngraverRuneButtonMixin:ResetColors()
	self.SpellHighlightTexture:SetVertexColor(1.0, 1.0, 1.0);
	if self.isKnown then
		self.icon:SetVertexColor(1.0, 1.0, 1.0);
		self.icon:SetDesaturated(false)
		self.NormalTexture:SetVertexColor(1.0, 1.0, 1.0);
	else
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(0.2, 0.2, 0.2);
		self.NormalTexture:SetVertexColor(0.2, 0.2, 0.2);
	end
end

function EngraverRuneButtonMixin:OnClick()
	local buttonClicked = GetMouseButtonClicked();
	if IsKeyDown(buttonClicked) then
		if buttonClicked == "LeftButton"  then
			Addon:TryEngrave(self.slotId, self.skillLineAbilityID)
		elseif buttonClicked  == "RightButton" and Addon:GetOptions().EnableRightClickDrag then
			EngraverFrame:StartMoving()
		end
	else
		EngraverFrame:StopMovingOrSizing()
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
	if self.skillLineAbilityID and Addon:GetOptions().HideTooltip ~= true then
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
	if button == "RightButton" then
		Settings.OpenToCategory(addonName);
	elseif button == "LeftButton" then
		local parent = self:GetParent()
		if parent and parent.StartMoving then
			parent:StartMoving();
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
	if self.direction > 0 then
		Addon.Filters:SetCurrentFilterNext()
	else
		Addon.Filters:SetCurrentFilterPrev()
	end
end