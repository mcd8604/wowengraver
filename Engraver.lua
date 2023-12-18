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
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterForDrag("RightButton")
end

function EngraverFrameMixin:OnEvent(event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:CheckToLoad()
	elseif (event == "RUNE_UPDATED") then
		self:CheckToLoad()
		self:UpdateCategory(...)
	elseif (event == "PLAYER_EQUIPMENT_CHANGED") then
		self:HandleEquipmentChanged(...)
	end
end

function EngraverFrameMixin:CheckToLoad()
	if not self:IsShown() then
		self:SetShown(true)
		self:LoadCategories()
	end
end

function EngraverFrameMixin:UpdateCategory(engravingData)
	if engravingData then
		local categoryFrame = self.equipmentSlotFrameMap[engravingData.equipmentSlot]
		if categoryFrame then
			categoryFrame:ResetRuneButtons()
			categoryFrame:HighlightRuneButton(engravingData)
		end
	end
end

function EngraverFrameMixin:HandleEquipmentChanged(equipmentSlot, hasCurrent)
	local categoryFrame = self.categoryFrames[equipmentSlot]
	if categoryFrame then
		categoryFrame:ResetRuneButtons()
		self:UpdateCategory(C_Engraving.GetRuneForEquipmentSlot(equipmentSlot))
	end
end

function EngraverFrameMixin:LoadCategories()
	self.categoryFrames = { self.categoryFrame1, self.categoryFrame2, self.categoryFrame3 }
	self.equipmentSlotFrameMap = { [5] = self.categoryFrame1, [7] = self.categoryFrame2, [10] = self.categoryFrame3 }
	C_Engraving.RefreshRunesList();
	local categories = C_Engraving.GetRuneCategories(true, true);
	if #categories > 0 then
		for c, category in ipairs(categories) do
			--local CategoryName = GetItemInventorySlotInfo(category)
			local categoryFrame = self.categoryFrames[c]
			if categoryFrame then
				if c == 1 then
					categoryFrame:SetPoint("TOPLEFT")
				elseif c > 1 then
					categoryFrame:SetPoint("TOPLEFT", self.categoryFrames[c-1], "BOTTOMLEFT")
				end
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
			if r == 1 then
				runeButton:SetAllPoints()
			else
				runeButton:SetPoint("TOPLEFT", self.runeButtons[r-1], "TOPRIGHT")
			end
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
	if engravingData then
		local runeButton = self:GetRuneButton(engravingData.skillLineAbilityID)
		if runeButton then
			runeButton:SetHighlighted(true)
		end
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
	--self.FlyoutBorder:SetShown(isHighlighted)
	--self.FlyoutBorderShadow:SetShown(isHighlighted)
	self.SpellHighlightTexture:SetShown(isHighlighted)
end

function EngraverRuneButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetEngravingRune(self.skillLineAbilityID);
	self.showingTooltip = true;
	GameTooltip:Show();
end

function EngraverRuneButtonMixin:OnLeave()
	GameTooltip_Hide();
	self.showingTooltip = false;
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