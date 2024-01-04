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
	UIScale = 1.0
}

function EngraverOptionsFrameMixin:CreateSettingsInitializers()
	self.settings = {}
	self.initializers = {}
	local function addSetting(variable, name, varType)
		local setting = Settings.RegisterAddOnSetting(self.category, name, variable, varType, DefaultEngraverOptions[variable]);
		self.settings[variable] = setting
		Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, ...)
			EngraverOptions[variable] = newValue;
			EngraverOptionsCallbackRegistry:TriggerEvent(variable, newValue)
		end, self)
		return setting
	end
	local function addInitializer(initializer)
		if initializer then	
			table.insert(self.initializers, initializer);
			initializer:AddSearchTags(initializer:GetName():gmatch("%S+"))
		end
	end
	do -- DisplayMode
		local variable, name, tooltip = "DisplayMode", "Rune Display Mode", "Rune Display Mode";
		local setting = addSetting(variable, name, Settings.VarType.Number)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for i, displayMode in ipairs(Addon.EngraverDisplayModes) do
				container:Add(i-1, displayMode.text);
			end
			return container:GetData();
		end
		addInitializer(Settings.CreateDropDownInitializer(setting, options, tooltip))
	end -- DisplayMode
	do -- LayoutDirection
		local variable, name, tooltip = "LayoutDirection", "Layout Direction", "Layout Direction";
		local setting = addSetting(variable, name, Settings.VarType.Number)
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for i, direction in ipairs(Addon.EngraverLayoutDirections) do
				container:Add(i-1, direction.text);
			end
			return container:GetData();
		end
		addInitializer(Settings.CreateDropDownInitializer(setting, options, tooltip))
	end -- LayoutDirection
	do -- HideTooltip
		addInitializer(Settings.CreateCheckBoxInitializer(addSetting("HideTooltip", "Hide Tooltip", Settings.VarType.Boolean), nil, "Hides the tooltip when hovering over a rune button."))
	end -- HideTooltip
	do -- HideDragTab
		addInitializer(Settings.CreateCheckBoxInitializer(addSetting("HideDragTab", "Hide Drag Tab", Settings.VarType.Boolean), nil, "Hides the drag tab of the Engraver frame."))
	end -- HideDragTab
	do -- EnableRightClickDrag
		addInitializer(Settings.CreateCheckBoxInitializer(addSetting("EnableRightClickDrag", "Enable Right Click Drag", Settings.VarType.Boolean), nil, "Enables dragging the frame by right-clicking and holding any rune button."))
	end -- EnableRightClickDrag
	do -- UIScale
		local variable, name, tooltip = "UIScale", "UI Scale", "Adjusts the scale of the Engraver's user interface frame.";
		local setting = addSetting(variable, name, Settings.VarType.Number)
		local options = Settings.CreateSliderOptions(0.01, 2.5, 0.00) -- minValue, maxValue, step 
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
		addInitializer(Settings.CreateSliderInitializer(setting, options, tooltip))
	end	-- UIScale
	do -- filters
		local variable, name, tooltip = "filters", "Filters", "Selected runes are shown. Deselected runes are hidden.";
		local setting = Settings.RegisterAddOnSetting(self.category, name, variable, varType, DefaultEngraverOptions[variable]);
		self.settings[variable] = setting
		addInitializer(Settings.CreateControlInitializer("EngraverOptionsFilterControlTemplate", setting, options, tooltip));
	end -- filters
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
	if self.settings then
		for variable, setting in pairs(self.settings) do
			setting:SetValue(EngraverOptions[variable])
		end
	end
end

--function EngraverOptionsFrameMixin:OnCommit()
--	print("OnCommit")
--end