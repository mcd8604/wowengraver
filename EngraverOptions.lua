local localAddonName, Addon = ...
local EngraverDisplayModes = Addon.EngraverDisplayModes 

-- Slash Commands
SLASH_ENGRAVER1, SLASH_ENGRAVER2, SLASH_ENGRAVER3, SLASH_ENGRAVER4, SLASH_ENGRAVER5 = "/en", "/eng", "/engrave", "/engraver", "/engraving"
SlashCmdList.ENGRAVER = function(msg, editBox)
	Settings.OpenToCategory(localAddonName);
end

EngraverOptions = {} -- SavedVariable
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
	UIScale = 1.0
}

function EngraverOptionsFrameMixin:CreateSettingsInitializers()
	self.settings = {}
	self.initializers = {}
	local function addInitializer(initializer)
		if initializer then	
			table.insert(self.initializers, initializer);
			initializer:AddSearchTags(initializer:GetName():gmatch("%S+"))
		end
	end
	do -- DisplayMode
		local variable, name, tooltip = "DisplayMode", "Rune Display Mode", "Rune Display Mode";
		self.settings.DisplayMode = Settings.RegisterAddOnSetting(self.category, name, variable, Settings.VarType.Number, DefaultEngraverOptions.DisplayMode);
		local options = function()
			local container = Settings.CreateControlTextContainer();
			for i, displayMode in ipairs(EngraverDisplayModes) do
				container:Add(i-1, displayMode.text);
			end
			return container:GetData();
		end
		addInitializer(Settings.CreateDropDownInitializer(self.settings.DisplayMode, options, tooltip))
		Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, ...) EngraverOptions.DisplayMode = newValue; end, self)
	end -- DisplayMode	
	do -- UIScale
		local variable, name, tooltip = "UIScale", "UI Scale", "Adjusts the scale of the Engraver's user interface frame.";
		local options = Settings.CreateSliderOptions(0.01, 2.5, 0.00) -- minValue, maxValue, step 
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
		self.settings.UIScale = Settings.RegisterAddOnSetting(self.category, name, variable, Settings.VarType.Number, DefaultEngraverOptions.UIScale);
		addInitializer(Settings.CreateSliderInitializer(self.settings.UIScale, options, tooltip))
		Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, ...) EngraverOptions.UIScale = newValue; end, self)
	end	-- UIScale
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