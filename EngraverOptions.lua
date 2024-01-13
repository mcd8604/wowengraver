local localAddonName, Addon = ...
local EngraverDisplayModes = Addon.EngraverDisplayModes 

-- Slash Commands
SLASH_ENGRAVER1, SLASH_ENGRAVER2, SLASH_ENGRAVER3, SLASH_ENGRAVER4, SLASH_ENGRAVER5, SLASH_ENGRAVER6, SLASH_ENGRAVER7 = "/en", "/eng", "/eg", "/re", "/engrave", "/engraver", "/engraving"
SlashCmdList.ENGRAVER = function(msg, editBox)
	Settings.OpenToCategory(localAddonName);
end

EngraverOptions = {} -- SavedVariable
EngraverOptionsCallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
EngraverOptionsCallbackRegistry:OnLoad()
EngraverOptionsCallbackRegistry:SetUndefinedEventsAllowed(true)

EngraverOptionsFrameMixin = {}

function EngraverOptionsFrameMixin:OnLoad()
	self:RegisterEvent("ADDON_LOADED")
	self.name = localAddonName
	self.category, self.layout = Settings.RegisterCanvasLayoutCategory(self, localAddonName, localAddonName);
	self.category.ID = localAddonName
	Settings.RegisterAddOnCategory(self.category);
	self:InitSettingsList()
	self:CreateSettingsInitializers()
	self.settingsList:Display(self.initializers);
	EngraverOptionsCallbackRegistry:RegisterCallback("CurrentFilter", self.OnCurrentFilterChanged, self)
end

function EngraverOptionsFrameMixin:InitSettingsList()
	self.settingsList.Header.Title:SetText(localAddonName);	
	self.settingsList.Header.DefaultsButton.Text:SetText(SETTINGS_DEFAULTS);
	self.settingsList.Header.DefaultsButton:SetScript("OnClick", function(button, buttonName, down)
		ShowAppropriateDialog("GAME_SETTINGS_APPLY_DEFAULTS");
	end);
	self.settingsList.ScrollBox:SetScript("OnMouseWheel", function(scrollBox, delta)
		if not KeybindListener:OnForwardMouseWheel(delta) then
			ScrollControllerMixin.OnMouseWheel(scrollBox, delta);
		end
	end);
	self.settingsList:Show();
end

local DefaultEngraverOptions = {
	DisplayMode = 1,
	LayoutDirection = 0,
	HideTooltip = false,
	HideDragTab = false,
	EnableRightClickDrag = false,
	UIScale = 1.0,
	ShowFilterSelector = false,
	CurrentFilter = 0
}

local function AddEngraverOptionsSetting(self, variable, name, varType)
	local setting = Settings.RegisterAddOnSetting(self.category, name, variable, varType, DefaultEngraverOptions[variable]);
	self.engraverOptionsSettings[variable] = setting
	Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, ...)
		EngraverOptions[variable] = newValue;
		EngraverOptionsCallbackRegistry:TriggerEvent(variable, newValue)
	end, self)
	return setting
end

local function AddInitializer(self, initializer)
	if initializer then	
		table.insert(self.initializers, initializer);
		initializer:AddSearchTags(initializer:GetName():gmatch("%S+"))
	end
end

function EngraverOptionsFrameMixin:CreateSettingsInitializers()
	self.engraverOptionsSettings = {}
	self.initializers = {}
	do -- DisplayMode
		local variable, name, tooltip = "DisplayMode", "Rune Display Mode", "Rune Display Mode";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for i, displayMode in ipairs(Addon.EngraverDisplayModes) do
				container:Add(i-1, displayMode.text);
			end
			return container:GetData();
		end
		AddInitializer(self, Settings.CreateDropDownInitializer(setting, options, tooltip))
	end -- DisplayMode
	do -- LayoutDirection
		local variable, name, tooltip = "LayoutDirection", "Layout Direction", "Layout Direction";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for i, direction in ipairs(Addon.EngraverLayoutDirections) do
				container:Add(i-1, direction.text);
			end
			return container:GetData();
		end
		AddInitializer(self, Settings.CreateDropDownInitializer(setting, options, tooltip))
	end -- LayoutDirection
	do -- HideTooltip
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "HideTooltip", "Hide Tooltip", Settings.VarType.Boolean), nil, "Hides the tooltip when hovering over a rune button."))
	end -- HideTooltip
	do -- HideDragTab
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "HideDragTab", "Hide Drag Tab", Settings.VarType.Boolean), nil, "Hides the drag tab of the Engraver frame."))
	end -- HideDragTab
	do -- EnableRightClickDrag
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "EnableRightClickDrag", "Enable Right Click Drag", Settings.VarType.Boolean), nil, "Enables dragging the frame by right-clicking and holding any rune button."))
	end -- EnableRightClickDrag
	do -- UIScale
		local variable, name, tooltip = "UIScale", "UI Scale", "Adjusts the scale of the Engraver's user interface frame.";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		local options = Settings.CreateSliderOptions(0.01, 2.5, 0.00) -- minValue, maxValue, step 
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
		AddInitializer(self, Settings.CreateSliderInitializer(setting, options, tooltip))
	end	-- UIScale
	AddInitializer(self, CreateSettingsListSectionHeaderInitializer("Filters"));
	do -- ShowFilterSelector
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "ShowFilterSelector", "Show Filter Selector", Settings.VarType.Boolean), nil, "Shows the filter selector."))
	end -- ShowFilterSelector
	do -- FilterDropDown
		local function GetOptions()
			local container = Settings.CreateControlTextContainer();
			container:Add(0, Addon.Filters.NO_FILTER_DISPLAY_STRING);
			for i, filter in ipairs(Addon.Filters:GetFiltersForPlayerClass()) do
				container:Add(i, filter.Name);
			end
			return container:GetData();
		end
		local variable, name, tooltip = "CurrentFilter", "Current Filter", "Changes the currently active filter.";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		AddInitializer(self, Settings.CreateControlInitializer("EngraverOptionsFilterDropDownTemplate", setting, GetOptions, tooltip))
	end -- FilterDropDown
	do -- FilterControl
		local variable, name, tooltip = "FilterData", "Selected Runes", "Selected runes are shown. Deselected runes are hidden.";
		local setting = Settings.RegisterAddOnSetting(self.category, name, variable, Settings.VarType.Boolean, false);
		local initializer = Settings.CreateControlInitializer("EngraverOptionsFilterControlTemplate", setting, nil, tooltip)
		initializer:AddShownPredicate(function() return Addon.Filters:IsCurrentFilterValid(); end);
		AddInitializer(self, initializer)
	end -- FilterControl
end

function EngraverOptionsFrameMixin:OnEvent(event, ...)
	if event == "ADDON_LOADED" then
		self:HandleAddonLoaded(...)
	end
end

function EngraverOptionsFrameMixin:HandleAddonLoaded(addonName)
	if addonName == localAddonName then
		self:SetOptionsToDefault(false)
	end
end

function EngraverOptionsFrameMixin:OnDefault()
	EngraverOptions = {}
	self:SetOptionsToDefault(true)
end

function EngraverOptionsFrameMixin:SetOptionsToDefault(force)
	EngraverOptions = EngraverOptions or {}
	for k, v in pairs(DefaultEngraverOptions) do
		if force or EngraverOptions[k] == nil then
			if type(v) == "table" then 
				-- TODO recursive deep copy?
			end
			EngraverOptions[k] = v
		end
	end
end

function EngraverOptionsFrameMixin:OnRefresh()
	if self.engraverOptionsSettings then
		for variable, setting in pairs(self.engraverOptionsSettings) do
			if setting.SetValue then
				setting:SetValue(EngraverOptions[variable])
			end
		end
	end
end

--function EngraverOptionsFrameMixin:OnCommit()
--	print("OnCommit")
--end

function EngraverOptionsFrameMixin:OnCurrentFilterChanged(_, newValue)
	if not InCombatLockdown() then
		-- RepairDisplay will help remove the FilterControl when there is no current filter and add it when there is
		self.settingsList:RepairDisplay(self.initializers)	
	end
end

--------------------
-- FilterDropDown --
--------------------

EngraverOptionsFilterDropDownMixin = CreateFromMixins(SettingsDropDownControlMixin)

function EngraverOptionsFilterDropDownMixin:OnLoad()
	SettingsDropDownControlMixin.OnLoad(self);

	self.NewButton:ClearAllPoints();
	self.NewButton:SetPoint("TOPRIGHT", self.DropDown.Button, "BOTTOM");

	self.DeleteButton:ClearAllPoints();
	self.DeleteButton:SetPoint("TOPLEFT", self.NewButton, "TOPRIGHT", -10);
end

function EngraverOptionsFilterDropDownMixin:Init(initializer)
	SettingsDropDownControlMixin.Init(self, initializer);

	self.NewButton:SetText("New Filter"); -- TODO localization
	self.NewButton:SetScript("OnClick", function()
		StaticPopup_Show("ENGRAVER_FILTER_NEW", nil, nil, { filterDropDown = self });
	end);

	self.DeleteButton:SetText(DELETE);
	self.DeleteButton:SetScript("OnClick", function()
		if EngraverOptions.CurrentFilter then
			StaticPopup_Show("ENGRAVER_FILTER_DELETION", Addon.Filters:GetCurrentFilterName(), nil, { filterDropDown = self } );
		end
	end);

	-- TODO rename filter
	-- TODO re-order up/down

	self:RefreshSelected();
	self:EvaluateButtonState();
	-- Update selected value when EngraverOption.CurrentFilter changes
	EngraverOptionsCallbackRegistry:RegisterCallback("CurrentFilter", function(_, newIndex)
		if not InCombatLockdown() then 
			self:SetValue(newIndex)
			self:EvaluateButtonState()
		end
	end, self)
end

do
	local function OnCreateNewFilter(dialog)
		local newFilterName = strtrim(dialog.editBox:GetText());
		local index = Addon.Filters:CreateFilter(newFilterName)
		dialog.data.filterDropDown:RefreshFilterList(index);
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
		Addon.Filters:DeleteCurrentFilter()
		-- NOTE if deleting is desired from multiple places in the future, then:
		--      define/trigger a FilterDeleted event somewhere, register in the dropdown, and call RefreshFilterList from the handler instead
		self.data.filterDropDown:RefreshFilterList(EngraverOptions.CurrentFilter)
	end,
	exclusive = 1,
	whileDead = 1,
	showAlert = 1,
	hideOnEscape = 1
};

function EngraverOptionsFilterDropDownMixin:RefreshFilterList(selectedIndex)
	self:InitDropDown();
	self:SetValue(selectedIndex);
	self:EvaluateButtonState();
end

function EngraverOptionsFilterDropDownMixin:RefreshSelected()
	self:SetValue(EngraverOptions.CurrentFilter or 0)
end

-- OnSettingValueChanged fires when the setting bound to control changes value (not EngraverOptions.CurrentFilter)
function EngraverOptionsFilterDropDownMixin:OnSettingValueChanged(setting, value)
	SettingsDropDownControlMixin.OnSettingValueChanged(self, setting, value);
	self:EvaluateButtonState()
end

function EngraverOptionsFilterDropDownMixin:EvaluateButtonState()
	self.DeleteButton:SetEnabled(Addon.Filters:IsCurrentFilterValid());
end