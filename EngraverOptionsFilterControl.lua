local _, Addon = ...

local selectionBehavior; -- Initialized in EngraverOptionsFilterListMixin:OnLoad

local function GetSelectedFilterIndex()
	local selectedElementData = selectionBehavior:GetFirstSelectedElementData()
	if selectedElementData and selectedElementData.data then
		return selectedElementData.data.filterIndex
	end
end

-----------------------------
-- OptionsFilterRuneButton --
-----------------------------

EngraverOptionsFilterRuneButtonMixin = CreateFromMixins(EngraverRuneButtonMixin)

function EngraverOptionsFilterRuneButtonMixin:OnClick(button, down)
	if self.skillLineAbilityID then
		Addon.Filters:ToggleRune(GetSelectedFilterIndex(), self.skillLineAbilityID, self:GetChecked())
	end
end

--------------------------------
-- OptionsFilterCategoryFrame --
--------------------------------

EngraverOptionsFilterCategoryFrameMixin = CreateFromMixins(EngraverCategoryFrameBaseMixin, EngraverCategoryFrameShowAllMixin)

function EngraverOptionsFilterCategoryFrameMixin:OnLoad()
	self.runeButtonPool = CreateFramePool("CheckButton", self, "EngraverOptionsFilterRuneButtonTemplate")
	self.runeButtons = {}
end

--------------------
-- EquipmentSlots --
--------------------

EngraverOptionsFilterEquipmentSlotsMixin = {}

function EngraverOptionsFilterEquipmentSlotsMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)
	self.categoryFrames = {
		[INVSLOT_CHEST]	=	self.chestFrame,
		[INVSLOT_LEGS]	=	self.legsFrame,
		[INVSLOT_HAND]	=	self.handsFrame
	}
	self:SetupCategoryFrames()
end

function EngraverOptionsFilterEquipmentSlotsMixin:SetupCategoryFrames()
	for category, frame in pairs(self.categoryFrames) do
		self:SetupCategoryFrame(category, frame)
	end
	self:SetFilter(Addon.Filters:GetFilter(GetSelectedFilterIndex()))
end

function EngraverOptionsFilterEquipmentSlotsMixin:SetupCategoryFrame(category, frame)
	local runes = C_Engraving.GetRunesForCategory(category, false);
	if runes then
		frame.category = category
		frame:SetRunes(runes, runes)
		frame:SetDisplayMode(EngraverCategoryFrameShowAllMixin)
		frame:UpdateCategoryLayout(Addon.EngraverLayoutDirections[1])
		for r, runeButton in ipairs(frame.runeButtons) do
			runeButton:SetBlinking(false)
			runeButton:SetEnabled(false)
			runeButton.Border:SetShown(false)
			runeButton.icon:SetDesaturated(true)
		end
	end
end

function EngraverOptionsFilterEquipmentSlotsMixin:SetFilter(filter)
	for category, frame in pairs(self.categoryFrames) do
		for r, runeButton in ipairs(frame.runeButtons) do
			if filter then
				local passes = Addon.Filters:RunePassesFilter(runeButton, filter)
				runeButton:SetChecked(passes)
				runeButton:SetEnabled(true)
				runeButton.icon:SetDesaturated(false)
			else
				runeButton:SetChecked(false)
				runeButton:SetEnabled(false)
				runeButton.icon:SetDesaturated(true)
			end
		end
	end
end

------------------
-- FilterEditor --
------------------

EngraverOptionsFilterEditorMixin = CreateFromMixins(SettingsListElementMixin);

function EngraverOptionsFilterEditorMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)
	selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, self.OnSelectedFilterChanged, self);
	self.Tooltip:SetShown(false)
	self.NewButton:SetScript("OnClick", function()
		StaticPopup_Show("ENGRAVER_FILTER_NEW", nil, nil, { filterList = self.filterList });
	end);
	self.DeleteButton:SetScript("OnClick", function()
		local elementData = selectionBehavior:GetFirstSelectedElementData()
		if elementData and elementData.data and elementData.data.filter and elementData.data.filter.Name then
			StaticPopup_Show("ENGRAVER_FILTER_DELETION", elementData.data.filter.Name, nil, { filterList = self.filterList });
		end
	end);
end

function EngraverOptionsFilterEditorMixin:OnSelectedFilterChanged(elementData, selected)
	if not InCombatLockdown() then 
		if selected then
			self.equipmentSlotsFrame:SetFilter(elementData.data.filter)
		end
	end
end

do
	local function OnCreateNewFilter(dialog)
		local newFilterName = strtrim(dialog.editBox:GetText());
		local index = Addon.Filters:CreateFilter(newFilterName)
		dialog.data.filterList:LoadFilterData();
		local elements = dialog.data.filterList.elementList
		selectionBehavior:SelectElementData(elements[index])
		dialog:Hide();
	end

	StaticPopupDialogs["ENGRAVER_FILTER_NEW"] = {
		text = "Create a New Filter",
		button1 = CREATE,
		button2 = CANCEL,
		OnAccept = function(self)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
			OnCreateNewFilter(self)
		end,
		EditBoxOnTextChanged = function(self)
			if ( strtrim(self:GetText()) == "" ) then
				self:GetParent().button1:Disable();
			else
				self:GetParent().button1:Enable();
			end
		end,
		EditBoxOnEnterPressed = function(self)
			OnCreateNewFilter(self:GetParent())
		end,
		exclusive = 1,
		whileDead = 1,
		hideOnEscape = 1,
		hasEditBox = 1,
		maxLetters = 31
	};
end

StaticPopupDialogs["ENGRAVER_FILTER_DELETION"] = {
	text = CONFIRM_COMPACT_UNIT_FRAME_PROFILE_DELETION,
	button1 = DELETE,
	button2 = CANCEL,
	OnAccept = function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		local filterIndex = GetSelectedFilterIndex()
		if filterIndex > 0 then
			Addon.Filters:DeleteFilter(filterIndex)
			-- NOTE if deleting is desired from multiple places in the future, then:
			--      define/trigger a FilterDeleted event in Filters, register in the editor, and move the code below to the handler
			self.data.filterList:LoadFilterData();
			local dataProvider = self.data.filterList.dataProvider
			if dataProvider then
				local elementData = dataProvider:Find(filterIndex) or dataProvider:Find(filterIndex-1);
				if elementData then
					selectionBehavior:SelectElementData(elementData)
				end
			end
		end
	end,
	exclusive = 1,
	whileDead = 1,
	showAlert = 1,
	hideOnEscape = 1
};

----------------
-- FilterList --
----------------

EngraverOptionsFilterListMixin = {} 

function EngraverOptionsFilterListMixin:OnLoad()
	self.backgroundTexture:SetTextureSliceMargins(20,20,20,20)

	local function Factory(factory, elementData)
		local function Initializer(button, elementData)
			elementData:InitFrame(button);
		end
		elementData:Factory(factory, Initializer);
	end

	local pad = 0;
	local spacing = 2;
	local view = CreateScrollBoxListLinearView(pad, pad, pad, pad, spacing);
	view:SetElementFactory(Factory);
	self.ScrollBar:ClearPointsOffset()
	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view);

	local scrollBoxAnchorsWithBar = 
	{
		CreateAnchor("TOPLEFT", 0, 0),
		CreateAnchor("BOTTOMRIGHT", -20, 0);
	};
	local scrollBoxAnchorsWithoutBar = 
	{
		scrollBoxAnchorsWithBar[1],
		CreateAnchor("BOTTOMRIGHT", 0, 0);
	};
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar, scrollBoxAnchorsWithBar, scrollBoxAnchorsWithoutBar);
	
	local function OnSelectionChanged(o, elementData, selected)
		local button = self.ScrollBox:FindFrame(elementData);
		if button then
			button:UpdateStateInternal(selected);
		end
		if selected then
			self.ScrollBox:ScrollToElementData(elementData, ScrollBoxConstants.AlignNearest);
		end
	end;
	selectionBehavior = ScrollUtil.AddSelectionBehavior(self.ScrollBox);
	selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, OnSelectionChanged)
	
	-- TODO ScrollBoxDragBehavior:SetReorderable(reorderable)
	
	self:LoadFilterData()
end

function EngraverOptionsFilterListMixin:LoadFilterData()
	self.elementList = {};
	for i, filter in ipairs(Addon.Filters:GetFiltersForPlayerClass()) do
		local initializer = CreateFromMixins(ScrollBoxFactoryInitializerMixin);
		initializer:Init("EngraverOptionsFilterListButtonTemplate");
		initializer.data = { filterIndex = i, filter = filter };
		table.insert(self.elementList, initializer);
	end
	self.dataProvider = CreateDataProvider(self.elementList);
	self.ScrollBox:SetDataProvider(self.dataProvider, ScrollBoxConstants.RetainScrollPosition);
	selectionBehavior:SelectFirstElementData(function(data) return true; end);
end

----------------------
-- FilterListButton --
----------------------

EngraverOptionsFilterListButtonMixin = CreateFromMixins(ButtonStateBehaviorMixin);

function EngraverOptionsFilterListButtonMixin:UpdateStateInternal(selected)
	if selected then
		self.Label:SetFontObject("GameFontHighlight");
		self.Texture:SetAtlas("Options_List_Active", TextureKitConstants.UseAtlasSize);
		self.Texture:Show();
	else
		local initializer = self:GetElementData();
		self.Label:SetFontObject("GameFontNormal");
		if self.over then
			self.Texture:SetAtlas("Options_List_Hover", TextureKitConstants.UseAtlasSize);
			self.Texture:Show();
		else
			self.Texture:Hide();
		end
	end
end

function EngraverOptionsFilterListButtonMixin:OnButtonStateChanged()
	self:UpdateStateInternal(selectionBehavior:IsSelected(self));
end

function EngraverOptionsFilterListButtonMixin:Init(initializer)
	local filter = initializer.data.filter;
	self.Label:SetText(filter.Name);
	self:UpdateStateInternal(selectionBehavior:IsSelected(self));
end

function EngraverOptionsFilterListButtonMixin:OnClick(buttonName, down)
	selectionBehavior:Select(self);
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end