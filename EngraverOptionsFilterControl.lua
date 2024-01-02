local _, Addon = ...

-----------------------------
-- OptionsFilterRuneButton --
-----------------------------

EngraverOptionsFilterRuneButtonMixin = CreateFromMixins(EngraverRuneButtonMixin)

function EngraverOptionsFilterRuneButtonMixin:OnClick(button, down)
	if self.skillLineAbilityID then
		local index = 1 -- TODO refactor for multiple filters
		Addon.Filters:ToggleRune(index, self.skillLineAbilityID, self:GetChecked())
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
	for category, frame in pairs(self.categoryFrames) do
		self:SetupCategoryFrame(category, frame)
	end
	self:RegisterEvent("RUNE_UPDATED");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("NEW_RECIPE_LEARNED");
	self:RegisterEvent("UPDATE_INVENTORY_ALERTS");
end

function EngraverOptionsFilterControlMixin:SetupCategoryFrame(category, frame)
	local runes = C_Engraving.GetRunesForCategory(category, false);
	if runes then
		frame.category = category
		frame:SetRunes(runes, runes)
		frame:SetDisplayMode(EngraverCategoryFrameShowAllMixin)
		frame:UpdateCategoryLayout(Addon.EngraverLayoutDirections[1])
		for r, runeButton in ipairs(frame.runeButtons) do
			local index = 1 -- TODO refactor for multiple filters
			local filter = Addon.Filters:GetFilter(index)
			local passes = Addon.Filters:RunePassesFilter(runeButton, filter)
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