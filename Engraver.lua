EngraverFrameMixin = {};
EngraverCategoryFrameMixin = {};
EngraverRuneButtonMixin = {};

function EngraverFrameMixin:OnLoad()
	self:RegisterEvent("RUNE_UPDATED");
	self:RegisterForDrag("RightButton")
end

function EngraverFrameMixin:OnEvent(event, ...)
	if (event == "RUNE_UPDATED") then
		if not self:IsShown() then
			self:SetShown(true)
			self:LoadCategories()
		end
	end
end

function EngraverFrameMixin:LoadCategories()
	C_Engraving.RefreshRunesList();
	local categories = C_Engraving.GetRuneCategories(true, true);
	for c, category in ipairs(categories) do
		--local CategoryName = GetItemInventorySlotInfo(category)
		local categoryFrame = _G[self:GetName().."_CategoryFrame"..c]
		if categoryFrame then
			categoryFrame:SetPoint("BOTTOMLEFT", 0, (c - 1) * 45)
			categoryFrame:LoadCategoryRunes(category)
		end
	end
end

function EngraverCategoryFrameMixin:LoadCategoryRunes(category)
	local runes = C_Engraving.GetRunesForCategory(category, true);
	for r, rune in ipairs(runes) do
		local runeButton = _G[self:GetName().."_RuneButton"..r]
		if runeButton then
			runeButton:SetRune(rune, category)
			runeButton:SetPoint("TOPLEFT", (r - 1) * 45, 0)
		end
	end
end

function EngraverRuneButtonMixin:SetRune(rune, category)
	self.category = category
	self.icon:SetTexture(rune.iconTexture);
	self.tooltipName = rune.name;
	self.skillLineAbilityID = rune.skillLineAbilityID;
	self:RegisterForClicks("LeftButtonUp", "RightButtonDown", "RightButtonUp")
	if self.icon then
		self.icon:SetAllPoints()
	end
	self:Show();
end

function EngraverRuneButtonMixin:OnClick()
	local buttonClicked = GetMouseButtonClicked();
	if buttonClicked == "LeftButton" then
		self:TryEngrave()
	elseif buttonClicked  == "RightButton" then
		if IsKeyDown(buttonClicked) then
			EngraverFrame:StartMoving()
		else
			EngraverFrame:StopMovingOrSizing()
		end
	end
end

function EngraverRuneButtonMixin:TryEngrave()
	if self.category and self.skillLineAbilityID then
		C_Engraving.CastRune(self.skillLineAbilityID);
		if self.category == 5 then
			CharacterChestSlot:Click(); 
		elseif self.category == 7 then
			CharacterLegsSlot:Click(); 
		elseif self.category == 10 then
			CharacterHandsSlot:Click(); 
		end
		StaticPopup1Button1:Click(); -- will it always be StaticPopup1?
	end
end