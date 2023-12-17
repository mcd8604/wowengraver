EngraverOptions = {}

EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", function(ownerID, addonName, ...)
	if addonName == "Engraver" then
		local EngraverAddOnCategory, layout = Settings.RegisterVerticalLayoutCategory("Engraver");
		Settings.RegisterAddOnCategory(EngraverAddOnCategory);
		if EngraverOptions == nil then
			EngraverOptions = {}
		end

		-- UIScale
		if not EngraverOptions.UIScale then
			EngraverOptions.UIScale = 1.0
		end
		if EngraverFrame then
			EngraverFrame:SetScale(EngraverOptions.UIScale)
		end
		do 
			local variable, name, tooltip = "UIScale", "UI Scale", "Adjusts the scale of the Engraver's user interface frame.";
			local options = Settings.CreateSliderOptions(0.01, 2.5, 0.00) -- minValue, maxValue, step 
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage);
			local setting = Settings.RegisterAddOnSetting(EngraverAddOnCategory, name, variable, Settings.VarType.Number, 1.0);
			setting:SetValue(EngraverOptions.UIScale)
			local slider = Settings.CreateSlider(EngraverAddOnCategory, setting, options, tooltip);
			Settings.SetOnValueChangedCallback(variable, function (_, _, newValue, oldValue, ...)
				EngraverOptions.UIScale = newValue
				if EngraverFrame then
					local point, relativeTo, relativePoint, offsetX, offsetY = EngraverFrame:GetPoint()
					if newValue > 0 then
						EngraverFrame:SetPoint(point, relativeTo, relativePoint, (offsetX or 0) * oldValue / newValue, (offsetY or 0) * oldValue / newValue) 
					end
					EngraverFrame:SetScale(EngraverOptions.UIScale)
				end
			end)
		end
		-- UIScale
	end
end)