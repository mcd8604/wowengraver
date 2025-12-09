local localAddonName, Addon = ...
local EngraverDisplayModes = Addon.EngraverDisplayModes 

EngraverOptions = {} -- SavedVariable
EngraverSharedOptions = {} -- SavedVariable
EngraverOptionsCallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
EngraverOptionsCallbackRegistry:OnLoad()
EngraverOptionsCallbackRegistry:SetUndefinedEventsAllowed(true)

local EngraverDisplayModes = {
	{ text = "Show All", mixin = EngraverCategoryFrameShowAllMixin },
	{ text = "Pop-up Menu", mixin = EngraverCategoryFramePopUpMenuMixin }
}
Addon.EngraverDisplayModes = EngraverDisplayModes
Addon.GetCurrentDisplayMode = function() return EngraverDisplayModes[Addon:GetOptions().DisplayMode+1] end

local ENGRAVER_SHOW_HIDE = "Show/Hide Engraver" -- TODO localization
local ENGRAVER_NEXT_FILTER = "Activate Next Filter" -- TODO localization
local ENGRAVER_PREV_FILTER = "Activate Previous Filter" -- TODO localization
_G.BINDING_NAME_ENGRAVER_SHOW_HIDE = ENGRAVER_SHOW_HIDE
_G.BINDING_NAME_ENGRAVER_NEXT_FILTER = ENGRAVER_NEXT_FILTER
_G.BINDING_NAME_ENGRAVER_PREV_FILTER = ENGRAVER_PREV_FILTER

Addon.EngraverVisibilityModes = {
	["ShowAlways"] = { text = "Show Always", tooltip = "Engraver will always be visible." },
	["HideInCombat"] = { text = "Hide in Combat", tooltip = "Show/Hide when combat ends/starts." },
	["SyncCharacterPane"] = { text = "Sync with Character Pane", tooltip = "Show/Hide when you open/close your Character Pane." },
	["ToggleKeybind"] = { text = "Toggle Keybind", tooltip = string.format("Toggles visibility when you press the %q keybind.", ENGRAVER_SHOW_HIDE) },
	["HoldKeybind"] = { text = "Hold Keybind", tooltip = string.format("Shows only when you press and hold the %q keybind.", ENGRAVER_SHOW_HIDE) },
	["ShowOnMouseOver"] = { text = "Show On MouseOver", tooltip = "Hides the Engraver and only shows when you hold the cursor over it." },
}

local DefaultEngraverOptions = {
	CurrentFilter = 0,
	UseCharacterSpecificSettings = false
}

local DefaultSettings = {
	DisplayMode = 1,
	LayoutDirection = 0,
	VisibilityMode = "ShowAlways",
	HideUndiscoveredRunes = false,
	HideTooltip = false,
	HideDragTab = false,
	ShowFilterSelector = false,
	HideSlotLabels = false,
	EnableRightClickDrag = false,
	UIScale = 1.0,
	PreventSpellPlacement = false
}

function Addon:GetOptions()
	return EngraverOptions.UseCharacterSpecificSettings and EngraverOptions or EngraverSharedOptions
end

------------------
-- OptionsFrame --
------------------

EngraverOptionsFrameMixin = {}

function EngraverOptionsFrameMixin:OnLoad()
	if C_Engraving:IsEngravingEnabled() then
		self.isSettingDefaults = false
		self:RegisterEvent("ADDON_LOADED")
		self.name = localAddonName
		self.category, self.layout = Settings.RegisterCanvasLayoutCategory(self, localAddonName, localAddonName);
		self.category.ID = localAddonName
		Settings.RegisterAddOnCategory(self.category);
		self:InitSettingsList()
		self:CreateSettingsInitializers()
		self.settingsList:Display(self.initializers);
	end
end

StaticPopupDialogs["ENGRAVER_SETTINGS_APPLY_DEFAULTS"] = {
	text = "\Your %s settings will be reset.\nThis cannot be undone.\nThis does not affect filters.",
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(self)
		self.data.optionsFrame:ChangeMultipleSettings(function()
			SettingsPanel:SetCurrentCategorySettingsToDefaults();
		end)
	end,
	exclusive = 1,
	whileDead = 1,
	showAlert = 1,
	hideOnEscape = 1
};

function EngraverOptionsFrameMixin:InitSettingsList()
	self.settingsList.Header.Title:SetText(localAddonName);	
	self.settingsList.Header.DefaultsButton.Text:SetText(SETTINGS_DEFAULTS);
	self.settingsList.Header.DefaultsButton:SetScript("OnClick", function(button, buttonName, down)
		StaticPopup_Show("ENGRAVER_SETTINGS_APPLY_DEFAULTS", EngraverOptions.UseCharacterSpecificSettings and "character's" or "shared", nil, { optionsFrame = self } )
	end);
	self.settingsList.Header.KeybindsButton = CreateFrame("Button", nil, self.settingsList.Header, "EngraverKeybindsButtonTemplate")
	self.settingsList.ScrollBox:SetScript("OnMouseWheel", function(scrollBox, delta)
		if not KeybindListener:OnForwardMouseWheel(delta) then
			ScrollControllerMixin.OnMouseWheel(scrollBox, delta);
		end
	end);
	self.settingsList:Show();
end

function EngraverOptionsFrameMixin:ChangeMultipleSettings(changeFunction)
	self.isChangingMultipleSettings = true
	if changeFunction then 
		changeFunction()
	end
	self.isChangingMultipleSettings = false
	EngraverOptionsCallbackRegistry:TriggerEvent("OnMultipleSettingsChanged")
end

local function AddEngraverOptionsSetting(self, variable, name, varType)
	local setting = Settings.RegisterAddOnSetting(self.category, variable, variable, EngraverSharedOptions, varType, name, DefaultSettings[variable]);
	self.engraverOptionsSettings[variable] = setting
	Settings.SetOnValueChangedCallback(variable, function (engraverOptionsFrame, setting, newValue, ...)
		Addon:GetOptions()[variable] = newValue;
		if not self.isChangingMultipleSettings then
			EngraverOptionsCallbackRegistry:TriggerEvent(variable, newValue)
		end
	end, self)
	return setting
end

local function AddInitializer(self, initializer)
	if initializer then	
		table.insert(self.initializers, initializer);
		if initializer.GetName then
			local name = initializer:GetName()
			if name then
				initializer:AddSearchTags(name:gmatch("%S+"))
			end
		end
	end
end

local function CreateInitializer(self, frameTemplate, data)
	local initializer = CreateFromMixins(SettingsListElementInitializer);
	initializer:Init(frameTemplate, data);
	AddInitializer(self, initializer)
end

function EngraverOptionsFrameMixin:CreateSettingsInitializers()
	self.engraverOptionsSettings = {}
	self.initializers = {}
	do -- UseCharacterSpecificSettings
		local variable, name, varType = "UseCharacterSpecificSettings", "Character Specific Settings", Settings.VarType.Boolean;
		local tooltip = "If checked, settings specific to this character are used.\nIf unchecked, shared settings are used.\n(Changing this does not delete any settings)."
		self.characterSpecificSettingsSetting = Settings.RegisterAddOnSetting(self.category, variable, variable, EngraverSharedOptions, varType, name, DefaultEngraverOptions.UseCharacterSpecificSettings);
		AddInitializer(self, Settings.CreateControlInitializer("EngraverCharacterSpecificControlTemplate", self.characterSpecificSettingsSetting, { optionsFrame = self }, tooltip))
		Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, ...)
			EngraverOptions[variable] = newValue;
			self:ChangeMultipleSettings(function()
				for variable, setting in pairs(self.engraverOptionsSettings) do
					if setting.SetValue then
						setting:SetValue(Addon:GetOptions()[variable])
					end
				end
			end)
		end, self)
	end -- UseCharacterSpecificSettings
	do -- SettingsHeader
		AddInitializer(self, CreateSettingsListSectionHeaderInitializer("Settings"));
	end -- SettingsHeader
	do -- DisplayMode
		local variable, name, tooltip = "DisplayMode", "Rune Display Mode", "How runes buttons are displayed.";
		local tooltips = { "All runes are always shown.", "Show only one button for each engravable equipment slot. Move your cursor over any button to see the available runes." }
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for i, displayMode in ipairs(Addon.EngraverDisplayModes) do
				container:Add(i-1, displayMode.text, tooltips[i]);
			end
			return container:GetData();
		end
		AddInitializer(self, Settings.CreateDropdownInitializer(setting, options, tooltip))
	end -- DisplayMode
	do -- LayoutDirection
		local variable, name, tooltip = "LayoutDirection", "Layout Direction", "Which direction the runes buttons are layed out.";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for i, direction in ipairs(Addon.EngraverLayoutDirections) do
				container:Add(i-1, direction.text);
			end
			return container:GetData();
		end
		AddInitializer(self, Settings.CreateDropdownInitializer(setting, options, tooltip))
	end -- LayoutDirection
	do -- VisibilityMode
		local variable, name, tooltip = "VisibilityMode", "Visibility Mode", "Choose how and when to show/hide the Engraver.";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.String)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for name, mode in pairs(Addon.EngraverVisibilityModes) do
				container:Add(name, mode.text, mode.tooltip);
			end
			return container:GetData();
		end
		AddInitializer(self, Settings.CreateDropdownInitializer(setting, options, tooltip))
	end -- VisibilityMode
	do -- HideUndiscoveredRunes
		AddInitializer(self, Settings.CreateCheckboxInitializer(AddEngraverOptionsSetting(self, "HideUndiscoveredRunes", "Hide Undiscovered Runes", Settings.VarType.Boolean), nil, "Spoiler safety - hides any runes that have not been discovered yet. They will still be hidden even if they pass the active filter."))
	end -- HideUndiscoveredRunes
	do -- HideTooltip
		AddInitializer(self, Settings.CreateCheckboxInitializer(AddEngraverOptionsSetting(self, "HideTooltip", "Hide Tooltip", Settings.VarType.Boolean), nil, "Hides the tooltip when hovering over a rune button."))
	end -- HideTooltip
	do -- HideDragTab
		local dragTabSetting = AddEngraverOptionsSetting(self, "HideDragTab", "Hide Drag Tab", Settings.VarType.Boolean)
		local dragTabInitializer = Settings.CreateCheckboxInitializer(dragTabSetting, nil, "The drag tab allows you to move the Engraver frame via mouse drag.")
		AddInitializer(self, dragTabInitializer)
		do -- ShowFilterSelector
			local setting = AddEngraverOptionsSetting(self, "ShowFilterSelector", "Show Filter Selector", Settings.VarType.Boolean)
			local initializer = Settings.CreateCheckboxInitializer(setting, nil, "When enabled, the drag tab will display the active filter.\nArrow buttons are added to the drag tab for you to change the filter.")
			initializer:SetParentInitializer(dragTabInitializer, function() return not dragTabSetting:GetValue() end)
			initializer.IsParentInitializerInLayout = function() return true; end -- forces indent and small font
			AddInitializer(self, initializer)
		end -- ShowFilterSelector
	end -- HideDragTab
	do -- HideSlotLabels
		AddInitializer(self, Settings.CreateCheckboxInitializer(AddEngraverOptionsSetting(self, "HideSlotLabels", "Hide Slot Labels", Settings.VarType.Boolean)))
	end -- HideSlotLabels
	do -- EnableRightClickDrag
		AddInitializer(self, Settings.CreateCheckboxInitializer(AddEngraverOptionsSetting(self, "EnableRightClickDrag", "Enable Right Click Drag", Settings.VarType.Boolean), nil, "Enables dragging the frame by right-clicking and holding any rune button."))
	end -- EnableRightClickDrag
	do -- UIScale
		local variable, name, tooltip = "UIScale", "UI Scale", "Adjusts the scale of the Engraver's user interface frame.";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		local options = Settings.CreateSliderOptions(0.01, 2.5, 0.01) -- minValue, maxValue, step 
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
		AddInitializer(self, Settings.CreateSliderInitializer(setting, options, tooltip))
	end	-- UIScale
	do -- PreventSpellPlacement
		AddInitializer(self, Settings.CreateCheckboxInitializer(AddEngraverOptionsSetting(self, "PreventSpellPlacement", "Prevent Spell Placement", Settings.VarType.Boolean), nil, "This will prevent spells from automatically animating and flying-in to a slot on your action bars."))
	end -- PreventSpellPlacement
	do -- FiltersHeader
		local filtersHeaderData = { 
			name = "Filters", 
			tooltipSections = {
				{ 
					header = "Creating a Filter", 
					lines = {
						"Create a new filter and give it an appropriate name.",
						"Select runes that you want to see when the filter is active, the rest will be hidden."
					}
				},
				{ 
					header = "Activating a Filter", 
					lines = {
						"Only one filter (or none) can be active at a time.",
						"The active filter is indicated by a green marker in the list below.",
						"Right-click a filter in the list below to activate or deactivate it.",
						"You can also use the Filter Selector (the arrow buttons on the drag tab) to change the active one. "
					}
				}
			}
		}
		AddInitializer(self, Settings.CreateElementInitializer("SettingsListSectionHeaderWithInfoTemplate", filtersHeaderData));
	end -- FiltersHeader
	do -- FilterEditor
		CreateInitializer(self, "EngraverOptionsFilterEditorTemplate", { settings = {} } );
	end -- FilterEditor
	do -- InformationHeader
		AddInitializer(self, CreateSettingsListSectionHeaderInitializer("Information"));
	end -- InformationHeader
	do -- Discord
		CreateInitializer(self, "SettingsSelectableTextTemplate", 
		{
			name = "Community Discord",
			tooltip = "If you have any questions, suggestions, or comments please post in the Community Discord.",
			text = "https://discord.gg/xwkZnnKfsC"
		})
	end -- Discord
	do -- Github
		CreateInitializer(self, "SettingsSelectableTextTemplate", 
		{
			name = "Github",
			tooltip = "If encounter a bug please check if your issue is already posted. If it isn't then go ahead and open a new issue.",
			text = "https://github.com/mcd8604/wowengraver/issues?q="
		})
	end -- Github
end

function EngraverOptionsFrameMixin:OnEvent(event, ...)
	if event == "ADDON_LOADED" then
		self:HandleAddonLoaded(...)
	end
end

local function SetMissingOptionsToDefault(options, defaults)
	for k, v in pairs(defaults) do
		if options[k] == nil then
			options[k] = v
		end
	end
end

-- removes extraneous/deprecated data
local function SanitizeOptionsData(options, predicate)
	local keysToDelete = {}
	for k, v in pairs(options) do
		if predicate(k) then
			table.insert(keysToDelete, k)
		end
	end
	for i, k in ipairs(keysToDelete) do
		options[k] = nil
	end
end

function EngraverOptionsFrameMixin:HandleAddonLoaded(addonName)
	if addonName == localAddonName then
		-- If UseCharacterSpecificSettings isn't set and character settings exist but shared settings do not, then auto-copy to the shared.
		-- This is for users updating from a version that didn't have shared settings implemented (so it doesn't appear that all their settings were wiped, even though they weren't).
		if EngraverOptions.UseCharacterSpecificSettings == nil and not TableIsEmpty(EngraverOptions) then
			if TableIsEmpty(EngraverSharedOptions) then
				MergeTable(EngraverSharedOptions, EngraverOptions) -- auto-copy to the shared settings
			end
		end
		-- Ensure any missing settings are set with default values
		SetMissingOptionsToDefault(EngraverOptions, DefaultEngraverOptions)
		SetMissingOptionsToDefault(EngraverOptions, DefaultSettings)
		SetMissingOptionsToDefault(EngraverSharedOptions, DefaultSettings)
		-- Sanitize
		SanitizeOptionsData(EngraverOptions, function(k) return DefaultEngraverOptions[k] == nil and DefaultSettings[k] == nil; end)
		SanitizeOptionsData(EngraverSharedOptions, function(k) return DefaultSettings[k] == nil; end)
		-- Init characterSpecificSettingsSetting manually instead of via a default value (it purposely has no default because it should never be changed when setting defaults).
		self.characterSpecificSettingsSetting:SetValue(EngraverOptions.UseCharacterSpecificSettings)
	end
end

---------------------------------------
-- SettingsListSectionHeaderWithInfo --
---------------------------------------

SettingsListSectionHeaderWithInfoMixin = CreateFromMixins(SettingsListSectionHeaderMixin)

function SettingsListSectionHeaderWithInfoMixin:Init(initializer)
	SettingsListSectionHeaderMixin.Init(self, initializer)
	self.TooltipSections = initializer:GetData().tooltipSections
end

function SettingsListSectionHeaderInfoButton_OnEnter(self)
	SettingsTooltip:SetOwner(self, "ANCHOR_RIGHT",-22,-22);
	local sections = self:GetParent().TooltipSections
	for i, section in ipairs(sections) do
		GameTooltip_AddHighlightLine(SettingsTooltip, section.header);
		for _, line in ipairs(section.lines) do
			GameTooltip_AddNormalLine(SettingsTooltip, line);
		end
		if i < #sections then
			GameTooltip_AddBlankLinesToTooltip(SettingsTooltip, 1)
		end
	end
	SettingsTooltip:Show();
end

----------------------------
-- SettingsSelectableText --
----------------------------

SettingsSelectableTextMixin = CreateFromMixins(SettingsListElementMixin)

function SettingsSelectableTextMixin:Init(initializer)
	SettingsListElementMixin.Init(self, initializer)
	local text = initializer:GetData().text;
	self.editBox:SetText(text)
	self.editBox:SetScript("OnTextChanged", function(_, userInput)
		if userInput then
			self.editBox:SetText(text)
			self.editBox:HighlightText()
		end
	end)
end

function SettingsSelectableTextMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)
	self.editBox:SetPoint("LEFT", self, "CENTER", -80, 0);
end

------------------------------
-- CharacterSpecificControl --
------------------------------

EngraverCharacterSpecificControlMixin = CreateFromMixins(SettingsCheckboxControlMixin)

function EngraverCharacterSpecificControlMixin:OnLoad()
	SettingsCheckboxControlMixin.OnLoad(self)
	self.copyText:SetPoint("LEFT", self.CheckBox, "RIGHT", 40, 0)
	self.copyCharacterButton:SetPoint("BOTTOMLEFT", self.copyText, "RIGHT")
	self.copyCharacterButton:SetScript("OnClick", function() 
		StaticPopup_Show("ENGRAVER_COPY_CHARACTER_SETTINGS", nil, nil, { optionsFrame = self.optionsFrame } )
	end)
	self.copySharedButton:SetPoint("TOPLEFT", self.copyText, "RIGHT")
	self.copySharedButton:SetScript("OnClick", function() 
		StaticPopup_Show("ENGRAVER_COPY_SHARED_SETTINGS", nil , nil, { optionsFrame = self.optionsFrame } )
	end)
end

function EngraverCharacterSpecificControlMixin:Init(initializer)
	SettingsCheckboxControlMixin.Init(self, initializer)
	self.optionsFrame = initializer:GetData().options.optionsFrame
end

StaticPopupDialogs["ENGRAVER_COPY_CHARACTER_SETTINGS"] = {
	text = "The shared settings will be overwritten.\nThis cannot be undone.\nThis does not affect filters.",
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(self)
		self.data.optionsFrame:ChangeMultipleSettings(function()
			for k, _ in pairs(DefaultSettings) do
				local value = EngraverOptions[k]
				EngraverSharedOptions[k] = value
				self.data.optionsFrame.engraverOptionsSettings[k]:SetValue(value)
			end
		end)
	end,
	exclusive = 1,
	whileDead = 1,
	showAlert = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["ENGRAVER_COPY_SHARED_SETTINGS"] = {
	text = "Overwrite this character's settings?\nThis cannot be undone.\nThis does not affect filters.",
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(self)
		self.data.optionsFrame:ChangeMultipleSettings(function()
			for k, _ in pairs(DefaultSettings) do
				local value = EngraverSharedOptions[k]
				EngraverOptions[k] = value
				self.data.optionsFrame.engraverOptionsSettings[k]:SetValue(value)
			end
		end)
	end,
	exclusive = 1,
	whileDead = 1,
	showAlert = 1,
	hideOnEscape = 1
};
