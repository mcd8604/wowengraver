local _, Addon = ...

local selectionBehavior; -- Initialized in EngraverOptionsFilterListMixin:OnLoad

local function GetSelectedFilterIndex()
	local selectedElementData = selectionBehavior:GetFirstSelectedElementData()
	if selectedElementData and selectedElementData.data then
		return selectedElementData.data.filterIndex
	end
end

local filterListDataProvider; -- Initialized in EngraverOptionsFilterListMixin:LoadFilterData

local function FilterListDataProvider_SelectIndex(filterIndex)
	local elementData = filterListDataProvider and filterListDataProvider:Find(filterIndex)
	if elementData then
		selectionBehavior:SelectElementData(elementData)
	end
end

-----------------------------
-- OptionsFilterRuneButton --
-----------------------------

EngraverOptionsFilterRuneButtonMixin = CreateFromMixins(EngraverRuneButtonMixin)

function EngraverOptionsFilterRuneButtonMixin:OnClick(button, down)
	if self.skillLineAbilityID then
		local filterIndex = GetSelectedFilterIndex()
		Addon.Filters:ToggleRune(filterIndex, self.skillLineAbilityID, self:GetChecked())
		FilterListDataProvider_SelectIndex(filterIndex)
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
	EngraverOptionsCallbackRegistry:RegisterCallback("FilterDeleted", self.OnFilterDeleted, self)
	EngraverOptionsCallbackRegistry:RegisterCallback("HideSlotLabels", self.OnHideSlotLabelsChanged, self)
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
		frame.slotLabel:SetCategory(category)
		frame:SetRunes(runes, runes)
		frame:SetDisplayMode(EngraverCategoryFrameShowAllMixin)
		frame:UpdateCategoryLayout(Addon.EngraverLayoutDirections[1])
		for r, runeButton in ipairs(frame.runeButtons) do
			runeButton:SetBlinking(false)
			runeButton:SetEnabled(false)
			runeButton.Border:SetShown(false)
			runeButton.icon:SetDesaturated(true)
			runeButton.icon:SetVertexColor(1.0, 1.0, 1.0)
			runeButton.NormalTexture:SetVertexColor(1.0, 1.0, 1.0);
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
				runeButton.icon:SetDesaturated(not passes)
			else
				runeButton:SetChecked(false)
				runeButton:SetEnabled(false)
				runeButton.icon:SetDesaturated(true)
			end
		end
	end
end

function EngraverOptionsFilterEquipmentSlotsMixin:OnFilterDeleted(filterIndex)
	-- disable rune buttons if no filter is selected
	if selectionBehavior:HasSelection() then
		self:SetupCategoryFrames()
	end 
end

function EngraverOptionsFilterEquipmentSlotsMixin:OnHideSlotLabelsChanged()
	self:SetupCategoryFrames()
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
		if elementData then
			StaticPopup_Show("ENGRAVER_FILTER_DELETION", elementData.data.filter.Name, nil, elementData);
		end
	end);
end

function EngraverOptionsFilterEditorMixin:OnSelectedFilterChanged(elementData, selected)
	if selected then
		self.equipmentSlotsFrame:SetFilter(elementData.data.filter)
	end
end

do
	local function createNewFilter(dialog)
		local newFilterName = strtrim(dialog.editBox:GetText());
		local index = Addon.Filters:CreateFilter(newFilterName)
		FilterListDataProvider_SelectIndex(index)
		dialog:Hide();
	end

	StaticPopupDialogs["ENGRAVER_FILTER_NEW"] = {
		text = "Create a New Filter",
		button1 = CREATE,
		button2 = CANCEL,
		OnAccept = function(self)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
			createNewFilter(self)
		end,
		EditBoxOnTextChanged = function(self)
			if ( strtrim(self:GetText()) == "" ) then
				self:GetParent().button1:Disable();
			else
				self:GetParent().button1:Enable();
			end
		end,
		EditBoxOnEnterPressed = function(self)
			createNewFilter(self:GetParent())
		end,
		exclusive = 1,
		whileDead = 1,
		hideOnEscape = 1,
		hasEditBox = 1,
		maxLetters = 31
	};
end

do 
	local function renameFilter(dialog)
		if dialog.data.data.filterIndex > 0 then
			local newFilterName = strtrim(dialog.editBox:GetText());
			Addon.Filters:RenameFilter(dialog.data.data.filterIndex, newFilterName) 
			FilterListDataProvider_SelectIndex(dialog.data.data.filterIndex)
			dialog:Hide();
		end
		dialog:Hide();
	end

	StaticPopupDialogs["ENGRAVER_FILTER_RENAME"] = {
		text = "Renaming: %s";
		button1 = OKAY,
		button2 = CANCEL,
		OnShow = function(self)
			self.editBox:SetText(self.data.data.filter.Name)
		end,
		OnAccept = function(self)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
			renameFilter(self)
		end,
		EditBoxOnTextChanged = function(self)
			if ( strtrim(self:GetText()) == "" ) then
				self:GetParent().button1:Disable();
			else
				self:GetParent().button1:Enable();
			end
		end,
		EditBoxOnEnterPressed = function(self)
			renameFilter(self:GetParent())
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
		if self.data.data.filterIndex > 0 then
			Addon.Filters:DeleteFilter(self.data.data.filterIndex)
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

	local pad = 10;
	local spacing = 2;
	local view = CreateScrollBoxListLinearView(pad, pad, pad, pad, spacing);
	view:SetElementFactory(Factory);
	self.ScrollBar:ClearPointsOffset()
	self.ScrollBox.enableDefaultDrag = true
	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view);
	self.ScrollBox.dragBehavior:SetReorderable(true)

	local scrollBoxAnchorsWithBar = 
	{
		CreateAnchor("TOPLEFT", 0, -10),
		CreateAnchor("BOTTOMRIGHT", -20, 10);
	};
	local scrollBoxAnchorsWithoutBar = 
	{
		CreateAnchor("TOPLEFT", 0, -10),
		CreateAnchor("BOTTOMRIGHT", 0, 10);
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

	self:LoadFilterData()
	EngraverOptionsCallbackRegistry:RegisterCallback("FiltersChanged", self.OnFiltersChanged, self)
	EngraverOptionsCallbackRegistry:RegisterCallback("CurrentFilter", self.OnCurrentFilterChanged, self)
	EngraverOptionsCallbackRegistry:RegisterCallback("FilterDeleted", self.OnFilterDeleted, self)
end

function EngraverOptionsFilterListMixin:LoadFilterData()
	local elementList = {};
	for i, filter in ipairs(Addon.Filters:GetFiltersForPlayerClass()) do
		local initializer = CreateFromMixins(ScrollBoxFactoryInitializerMixin);
		initializer:Init("EngraverOptionsFilterListButtonTemplate");
		initializer.data = { filterIndex = i, filter = filter };
		table.insert(elementList, initializer);
	end
	filterListDataProvider = CreateDataProvider(elementList);
	function dataProviderOnMove(_, _, indexFrom, indexTo)
		Addon.Filters:ReorderFilter(indexFrom, indexTo);
		FilterListDataProvider_SelectIndex(indexTo);
	end
	filterListDataProvider:RegisterCallback(DataProviderMixin.Event.OnMove, dataProviderOnMove, self)
	self.ScrollBox:SetDataProvider(filterListDataProvider, ScrollBoxConstants.RetainScrollPosition);
	selectionBehavior:SelectFirstElementData(function(data) return true; end);
end

function EngraverOptionsFilterListMixin:OnFiltersChanged()
	self:LoadFilterData()
end

function EngraverOptionsFilterListMixin:OnCurrentFilterChanged()
	local filterIndex = GetSelectedFilterIndex()
	self:LoadFilterData()
	FilterListDataProvider_SelectIndex(filterIndex)
end

function EngraverOptionsFilterListMixin:OnFilterDeleted(filterIndex)
	local elementData = filterListDataProvider:Find(filterIndex) or filterListDataProvider:Find(filterIndex-1);
	if elementData then
		selectionBehavior:SelectElementData(elementData)
	end
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
	self.GetElementData = function() return initializer; end
	local filter = initializer.data.filter;
	self.Label:SetText(filter.Name);
	self.status:SetShown(EngraverOptions.CurrentFilter == initializer.data.filterIndex)
	self:UpdateStateInternal(selectionBehavior:IsSelected(self));
end

function EngraverOptionsFilterListButtonMixin:OnEnter(buttonName, down)
	ButtonStateBehaviorMixin.OnEnter(self, buttonName, down)
	SettingsTooltip:SetOwner(self);
	Settings.InitTooltip("Drag-and-drop to re-order filters.", "Right click for more actions.") 
	SettingsTooltip:Show();
end

function EngraverOptionsFilterListButtonMixin:OnLeave(...)
	ButtonStateBehaviorMixin.OnLeave(self, ...)
	SettingsTooltip:Hide();
end

function EngraverOptionsFilterListButtonMixin:OnMouseDown(...)
	ButtonStateBehaviorMixin.OnMouseDown(self, ...)
	selectionBehavior:Select(self);
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end

function EngraverOptionsFilterListButtonMixin:OnMouseUp(button, isUp)
	ButtonStateBehaviorMixin.OnMouseUp(self, button, isUp)
	if button == "RightButton" then
		local elementData = self:GetElementData()
		local name = elementData.data.filter.Name
		local isActive = elementData.data.filterIndex == EngraverOptions.CurrentFilter
		local menu = {
			{ notCheckable = true, text = name, isTitle = true, },
			isActive 
				and { notCheckable = true, text = "Deactivate", func = function() Addon.Filters:SetCurrentFilter(0); end }
				or { notCheckable = true, text = "Activate", func = function() Addon.Filters:SetCurrentFilter(elementData.data.filterIndex); end },
			{ notCheckable = true, text = "Rename", func = function() StaticPopup_Show("ENGRAVER_FILTER_RENAME", name, nil, elementData ); end },
			{ notCheckable = true, text = "Delete", func = function() StaticPopup_Show("ENGRAVER_FILTER_DELETION", name, nil, elementData ) end }, 
			{ notCheckable = true, text = "Cancel" },
		}
		EasyMenu(menu, EngraverFilterListDropDownMenu, "cursor", nil, nil, "MENU");
	end
end