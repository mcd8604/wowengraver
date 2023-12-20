local _, Addon = ...
local EngraverDisplayModes = Addon.EngraverDisplayModes 

EngraverOptions = {}

EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", function(ownerID, addonName, ...)
	if addonName == "Engraver" then
		local EngraverAddOnCategory, layout = Settings.RegisterVerticalLayoutCategory("Engraver");
		Settings.RegisterAddOnCategory(EngraverAddOnCategory);
		if EngraverOptions == nil then
			EngraverOptions = {}
		end

		-- DisplayMode
		local DefaultDisplayMode = 1
		if not EngraverOptions.DisplayMode then
			EngraverOptions.DisplayMode = DefaultDisplayMode
		end
		do 
			local variable, name, tooltip = "EngraverDisplayMode", "Rune Display Mode", "Rune Display Mode";
			local function GetOptions()
				local container = Settings.CreateControlTextContainer();
				for i, displayMode in ipairs(EngraverDisplayModes) do
					container:Add(i-1, displayMode.text);
				end
				return container:GetData();
			end
			local setting = Settings.RegisterAddOnSetting(EngraverAddOnCategory, name, variable, Settings.VarType.Number, DefaultDisplayMode);
			setting:SetValue(EngraverOptions.DisplayMode)
			Settings.CreateDropDown(EngraverAddOnCategory, setting, GetOptions, tooltip);
			Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, ...) EngraverOptions.DisplayMode = newValue; end)
		end
		-- DisplayMode

		-- UIScale
		local DefaultUIScale = 1.0
		if not EngraverOptions.UIScale then
			EngraverOptions.UIScale = DefaultUIScale
		end
		do 
			local variable, name, tooltip = "UIScale", "UI Scale", "Adjusts the scale of the Engraver's user interface frame.";
			local options = Settings.CreateSliderOptions(0.01, 2.5, 0.00) -- minValue, maxValue, step 
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
			local setting = Settings.RegisterAddOnSetting(EngraverAddOnCategory, name, variable, Settings.VarType.Number, DefaultUIScale);
			setting:SetValue(EngraverOptions.UIScale)
			Settings.CreateSlider(EngraverAddOnCategory, setting, options, tooltip);
			Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, ...) EngraverOptions.UIScale = newValue; end, EngraverOptions)
		end
		-- UIScale
	end
end)