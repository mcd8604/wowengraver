local _, Addon = ...

-----------------------------
-- OptionsFilterRuneButton --
-----------------------------

EngraverOptionsFilterRuneButtonMixin = CreateFromMixins(EngraverRuneButtonMixin)

function EngraverOptionsFilterRuneButtonMixin:OnClick(button, down)
	if self.skillLineAbilityID then
		Addon.Filters:ToggleRune(EngraverOptions.CurrentFilter, self.skillLineAbilityID, self:GetChecked())
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

--------------------------
-- OptionsFilterControl --
--------------------------

EngraverOptionsFilterControlMixin = CreateFromMixins(SettingsListElementMixin);

local playerClassName, _, _ = UnitClass("player")
local ClassesRuneData = {}

function EngraverOptionsFilterControlMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)
	self.categoryFrames = {
		[INVSLOT_CHEST]	=	self.chestFrame,
		[INVSLOT_LEGS]	=	self.legsFrame,
		[INVSLOT_HAND]	=	self.handsFrame
	}
	self:SetupCategoryFrames()
	self:RegisterEvent("RUNE_UPDATED");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("NEW_RECIPE_LEARNED");
	self:RegisterEvent("UPDATE_INVENTORY_ALERTS");
	-- Update selected runes when EngraverOptions.CurrentFilter changes
	EngraverOptionsCallbackRegistry:RegisterCallback("CurrentFilter", function() 
		if not InCombatLockdown() then 
			self:SetupCategoryFrames()
		end
	end, self)
end

function EngraverOptionsFilterControlMixin:SetupCategoryFrames()
	for category, frame in pairs(self.categoryFrames) do
		self:SetupCategoryFrame(category, frame)
	end
end

function EngraverOptionsFilterControlMixin:SetupCategoryFrame(category, frame)
	local runes = C_Engraving.GetRunesForCategory(category, false);
	if runes then
		frame.category = category
		frame:SetRunes(runes, runes)
		frame:SetDisplayMode(EngraverCategoryFrameShowAllMixin)
		frame:UpdateCategoryLayout(Addon.EngraverLayoutDirections[1])
		for r, runeButton in ipairs(frame.runeButtons) do
			local passes = Addon.Filters:RunePassesFilter(runeButton)
			runeButton:SetChecked(passes)
			runeButton:SetBlinking(false)
		end
	end
end

function EngraverOptionsFilterControlMixin:OnEvent(event, ...)
	for category, frame in pairs(self.categoryFrames) do
		frame:UpdateCategoryLayout(Addon.EngraverLayoutDirections[1])
	end
end