EngraverFrameMixin = {};
EngraverCategoryFrameMixin = {};
EngraverRuneButtonMixin = {};

-------------------
-- EngraverFrame --
-------------------

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
		self:UpdateCategory(...)
	end
end

function EngraverFrameMixin:UpdateCategory(engravingData)
	local categoryFrame = self:GetCategoryFrame(engravingData)
	if categoryFrame then
		categoryFrame:ResetRuneFrames()
		categoryFrame:HighlightRuneFrame(engravingData)
	end
end

function EngraverFrameMixin:GetCategoryFrame(engravingData)
	if engravingData then
		if engravingData.equipmentSlot == 5 then
			return _G[self:GetName().."_CategoryFrame1"]
		elseif engravingData.equipmentSlot == 7 then
			return _G[self:GetName().."_CategoryFrame2"]
		elseif engravingData.equipmentSlot == 10 then
			return _G[self:GetName().."_CategoryFrame3"]
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

-------------------
-- CategoryFrame --
-------------------

function EngraverCategoryFrameMixin:LoadCategoryRunes(category)
	local runes = C_Engraving.GetRunesForCategory(category, false);
	local knownRunes = C_Engraving.GetRunesForCategory(category, true);
	if not self.runeFrames then
		self.runeFrames = {}
	end
	for r, rune in ipairs(runes) do
		local runeButton = _G[self:GetName().."_RuneButton"..r]
		if runeButton then
			local isKnown = self:IsRuneKnown(rune, knownRunes)
			runeButton:SetRune(rune, category, isKnown)
			runeButton:SetPoint("TOPLEFT", (r - 1) * 45, 0)
			self.runeFrames[r] = runeButton
		end
	end
end

function EngraverCategoryFrameMixin:IsRuneKnown(runeToCheck, knownRunes)
	for r, rune in ipairs(knownRunes) do
		if rune.skillLineAbilityID == runeToCheck.skillLineAbilityID then
			return true
		end
	end
end

function EngraverCategoryFrameMixin:ResetRuneFrames()
	for r, runeFrame in ipairs(self.runeFrames) do
		runeFrame:SetHighlighted(false)
	end
end

function EngraverCategoryFrameMixin:HighlightRuneFrame(engravingData)
	local runeFrame = self:GetRuneFrame(engravingData.skillLineAbilityID)
	if runeFrame then
		runeFrame:SetHighlighted(true)
	end
end

function EngraverCategoryFrameMixin:GetRuneFrame(skillLineAbilityID)
	for r, runeFrame in ipairs(self.runeFrames) do
		if runeFrame.skillLineAbilityID == skillLineAbilityID then
			return runeFrame
		end
	end
end

----------------
-- RuneButton --
----------------

function EngraverRuneButtonMixin:SetRune(rune, category, isKnown)
	self.category = category
	self.icon:SetTexture(rune.iconTexture);
	self.tooltipName = rune.name;
	self.skillLineAbilityID = rune.skillLineAbilityID;
	self:RegisterForClicks("LeftButtonUp", "RightButtonDown", "RightButtonUp")
	if self.icon then
		self.icon:SetAllPoints()
	end
	if isKnown then
		self.icon:SetVertexColor(1.0, 1.0, 1.0);
		self.NormalTexture:SetVertexColor(1.0, 1.0, 1.0);
	else
		self.icon:SetVertexColor(0.2, 0.0, 0.0);
		self.NormalTexture:SetVertexColor(0.2, 0.0, 0.0);
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

function EngraverRuneButtonMixin:SetHighlighted(isHighlighted)
	self.FlyoutBorder:SetShown(isHighlighted)
	self.FlyoutBorderShadow:SetShown(isHighlighted)
	self.SpellHighlightTexture:SetShown(isHighlighted)
end