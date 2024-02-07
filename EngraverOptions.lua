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

local EngraverDisplayModes = {
	{ text = "Show All", mixin = EngraverCategoryFrameShowAllMixin },
	{ text = "Pop-up Menu", mixin = EngraverCategoryFramePopUpMenuMixin }
}
Addon.EngraverDisplayModes = EngraverDisplayModes
Addon.GetCurrentDisplayMode = function() return EngraverDisplayModes[EngraverOptions.DisplayMode+1] end

local ENGRAVER_SHOW_HIDE = "Show/Hide Engraver" -- TODO localization
_G.BINDING_NAME_ENGRAVER_SHOW_HIDE = ENGRAVER_SHOW_HIDE

Addon.EngraverVisibilityModes = {
	["ShowAlways"] = { text = "Show Always", tooltip = "Engraver will always be visible." },
	["HideInCombat"] = { text = "Hide in Combat", tooltip = "Show/Hide when combat ends/starts." },
	["SyncCharacterPane"] = { text = "Sync with Character Pane", tooltip = "Show/Hide when you open/close your Character Pane." },
	["ToggleKeybind"] = { text = "Toggle Keybind", tooltip = string.format("Toggles visibility when you press the %q keybind.", ENGRAVER_SHOW_HIDE) },
	["HoldKeybind"] = { text = "Hold Keybind", tooltip = string.format("Shows only when you press and hold the %q keybind.", ENGRAVER_SHOW_HIDE) },
}

local DefaultEngraverOptions = {
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
	CurrentFilter = 0
}

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
end

function EngraverOptionsFrameMixin:InitSettingsList()
	self.settingsList.Header.Title:SetText(localAddonName);	
	self.settingsList.Header.DefaultsButton.Text:SetText(SETTINGS_DEFAULTS);
	self.settingsList.Header.DefaultsButton:SetScript("OnClick", function(button, buttonName, down)
		ShowAppropriateDialog("GAME_SETTINGS_APPLY_DEFAULTS");
	end);
	self.settingsList.Header.KeybindsButton = CreateFrame("Button", nil, self.settingsList.Header, "EngraverKeybindsButtonTemplate")
	self.settingsList.ScrollBox:SetScript("OnMouseWheel", function(scrollBox, delta)
		if not KeybindListener:OnForwardMouseWheel(delta) then
			ScrollControllerMixin.OnMouseWheel(scrollBox, delta);
		end
	end);
	self.settingsList:Show();
end

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
		if initializer.GetName then
			initializer:AddSearchTags(initializer:GetName():gmatch("%S+"))
		end
	end
end

function EngraverOptionsFrameMixin:CreateSettingsInitializers()
	self.engraverOptionsSettings = {}
	self.initializers = {}
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
		AddInitializer(self, Settings.CreateDropDownInitializer(setting, options, tooltip))
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
		AddInitializer(self, Settings.CreateDropDownInitializer(setting, options, tooltip))
	end -- LayoutDirection
	do -- VisibilityMode
		local variable, name, tooltip = "VisibilityMode", "Visibility Mode", "Choose how and when to show/hide the Engraver.";
		local setting = AddEngraverOptionsSetting(self, variable, name, Settings.VarType.Number)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for name, mode in pairs(Addon.EngraverVisibilityModes) do
				container:Add(name, mode.text, mode.tooltip);
			end
			return container:GetData();
		end
		AddInitializer(self, Settings.CreateDropDownInitializer(setting, options, tooltip))
	end -- VisibilityMode
	do -- HideUndiscoveredRunes
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "HideUndiscoveredRunes", "Hide Undiscovered Runes", Settings.VarType.Boolean), nil, "Spoiler safety - hides any runes that have not been discovered yet. They will still be hidden even if they pass the active filter."))
	end -- HideUndiscoveredRunes
	do -- HideTooltip
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "HideTooltip", "Hide Tooltip", Settings.VarType.Boolean), nil, "Hides the tooltip when hovering over a rune button."))
	end -- HideTooltip
	do -- HideDragTab
		local dragTabSetting = AddEngraverOptionsSetting(self, "HideDragTab", "Hide Drag Tab", Settings.VarType.Boolean)
		local dragTabInitializer = Settings.CreateCheckBoxInitializer(dragTabSetting, nil, "The drag tab allows you to move the Engraver frame via mouse drag.")
		AddInitializer(self, dragTabInitializer)
		do -- ShowFilterSelector
			local setting = AddEngraverOptionsSetting(self, "ShowFilterSelector", "Show Filter Selector", Settings.VarType.Boolean)
			local initializer = Settings.CreateCheckBoxInitializer(setting, nil, "When enabled, the drag tab will display the active filter.\nArrow buttons are added to the drag tab for you to change the filter.")
			initializer:SetParentInitializer(dragTabInitializer, function() return not dragTabSetting:GetValue() end)
			initializer.IsParentInitializerInCurrentSettingsCategory = function() return true; end -- forces indent and small font
			AddInitializer(self, initializer)
		end -- ShowFilterSelector
	end -- HideDragTab
	do -- HideSlotLabels
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "HideSlotLabels", "Hide Slot Labels", Settings.VarType.Boolean)))
	end -- HideSlotLabels
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
		local initializer = CreateFromMixins(SettingsListElementInitializer);
		initializer:Init("EngraverOptionsFilterEditorTemplate", { settings = {} } );
		table.insert(self.initializers, initializer);
	end -- FilterEditor
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