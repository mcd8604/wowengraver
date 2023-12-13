EngraverFrameMixin = {};
EngraverCategoryFrameMixin = {};
EngraverRuneButtonMixin = {};
EngraverNoRunesFrameMixin = {};

-------------------
-- EngraverFrame --
-------------------

function EngraverFrameMixin:OnLoad()
	self:RegisterEvent("RUNE_UPDATED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterForDrag("RightButton")
end

function EngraverFrameMixin:OnEvent(event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:CheckToLoad()
	elseif (event == "RUNE_UPDATED") then
		self:CheckToLoad()
		self:UpdateCategory(...)
	end
end

function EngraverFrameMixin:CheckToLoad()
	if not self:IsShown() then
		self:SetShown(true)
		self:LoadCategories()
	end
end

function EngraverFrameMixin:UpdateCategory(engravingData)
	local categoryFrame = self:GetCategoryFrame(engravingData)
	if categoryFrame then
		categoryFrame:ResetRuneButtons()
		categoryFrame:HighlightRuneButton(engravingData)
	end
end

function EngraverFrameMixin:GetCategoryFrame(engravingData)
	if engravingData then
		if engravingData.equipmentSlot == 5 then
			return self.categoryFrame1;
		elseif engravingData.equipmentSlot == 7 then
			return self.categoryFrame2;
		elseif engravingData.equipmentSlot == 10 then
			return self.categoryFrame3;
		end
	end
end

function EngraverFrameMixin:LoadCategories()
	C_Engraving.RefreshRunesList();
	local categories = C_Engraving.GetRuneCategories(true, true);
	if #categories > 0 then
		for c, category in ipairs(categories) do
			--local CategoryName = GetItemInventorySlotInfo(category)
			local categoryFrame = self["categoryFrame"..c]
			if categoryFrame then
				categoryFrame:SetPoint("BOTTOMLEFT", 0, - (c - 1) * 45)
				categoryFrame:LoadCategoryRunes(category)
			end
		end
		self.noRunesFrame:Hide();
	else
		self.noRunesFrame:Show();
	end
end

-------------------
-- CategoryFrame --
-------------------

function EngraverCategoryFrameMixin:LoadCategoryRunes(category)
	local runes = C_Engraving.GetRunesForCategory(category, false);
	local knownRunes = C_Engraving.GetRunesForCategory(category, true);
	if not self.runeButtons then
		self.runeButtons = {}
	end
	for r, rune in ipairs(runes) do
		local runeButton = self.runeButtons[r]
		if not runeButton then
			runeButton = CreateFrame("Button", nil, self, "EngraverRuneButtonTemplate")
			self.runeButtons[r] = runeButton
		end
		if runeButton then
			local isKnown = self:IsRuneKnown(rune, knownRunes)
			runeButton:SetRune(rune, category, isKnown)
			runeButton:SetPoint("TOPLEFT", (r - 1) * 45, 0)
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

function EngraverCategoryFrameMixin:ResetRuneButtons()
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:SetHighlighted(false)
		end
	end
end

function EngraverCategoryFrameMixin:HighlightRuneButton(engravingData)
	local runeButton = self:GetRuneButton(engravingData.skillLineAbilityID)
	if runeButton then
		runeButton:SetHighlighted(true)
	end
end

function EngraverCategoryFrameMixin:GetRuneButton(skillLineAbilityID)
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if runeButton.skillLineAbilityID == skillLineAbilityID then
				return runeButton
			end
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
	if C_Engraving.IsRuneEquipped(self.skillLineAbilityID) then
		self:SetHighlighted(true)
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
		ClearCursor()
		C_Engraving.CastRune(self.skillLineAbilityID);
		if self.category == 5 then
			CharacterChestSlot:Click(); 
		elseif self.category == 7 then
			CharacterLegsSlot:Click(); 
		elseif self.category == 10 then
			CharacterHandsSlot:Click(); 
		end
		StaticPopup1Button1:Click(); -- will it always be StaticPopup1?
		ClearCursor()
	end
end

function EngraverRuneButtonMixin:SetHighlighted(isHighlighted)
	self.FlyoutBorder:SetShown(isHighlighted)
	self.FlyoutBorderShadow:SetShown(isHighlighted)
	self.SpellHighlightTexture:SetShown(isHighlighted)
end


-------------------------------
-- EngraverNoRunesFrameMixin --
-------------------------------

function EngraverNoRunesFrameMixin:OnMouseDown(button)
	if button == "RightButton" then
		local parent = self:GetParent()
		if parent and parent.StartMoving then
			parent:StartMoving();
		end
	end
end

function EngraverNoRunesFrameMixin:OnMouseUp(button)
	if button == "RightButton" then
		local parent = self:GetParent()
		if parent and parent.StopMovingOrSizing then
			parent:StopMovingOrSizing();
		end
	end
end