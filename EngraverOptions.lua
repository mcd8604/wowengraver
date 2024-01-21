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
		if initializer.GetName then
			initializer:AddSearchTags(initializer:GetName():gmatch("%S+"))
		end
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
	do -- ShowFilterSelector
		AddInitializer(self, Settings.CreateCheckBoxInitializer(AddEngraverOptionsSetting(self, "ShowFilterSelector", "Show Filter Selector", Settings.VarType.Boolean), nil, "Shows the filter selector."))
	end -- ShowFilterSelector
	AddInitializer(self, CreateSettingsListSectionHeaderInitializer("Filters"));
	do -- FilterEditor
		table.insert(self.initializers, Settings.CreateElementInitializer("EngraverOptionsFilterEditorTemplate", { settings = {} } ));
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