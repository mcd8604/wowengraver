local addonName, Addon = ...

EngraverFrameMixin = {};
EngraverCategoryFrameBaseMixin = {};
EngraverCategoryFrameShowAllMixin = {}
EngraverCategoryFramePopUpMenuMixin = {}
EngraverRuneButtonMixin = {}
EngraverNoRunesFrameMixin = {};

local EngraverDisplayModes = {
	{ text = "Show All", mixin = EngraverCategoryFrameShowAllMixin },
	{ text = "Pop-up Menu", mixin = EngraverCategoryFramePopUpMenuMixin }
}
Addon.EngraverDisplayModes = EngraverDisplayModes

-------------------
-- EngraverFrame --
-------------------

function EngraverFrameMixin:OnLoad()
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("RUNE_UPDATED");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterForDrag("RightButton")
end

function EngraverFrameMixin:OnEvent(event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:Initialize()
	elseif (event == "RUNE_UPDATED") then
		local engravingData = select(1, ...)
		if engravingData then
			self:UpdateCategory(engravingData.equipmentSlot)
		end
	elseif (event == "PLAYER_EQUIPMENT_CHANGED") then
		self:UpdateCategory(...)
	end
end

function EngraverFrameMixin:Initialize()
	self.categoryFrames = { self.categoryFrame1, self.categoryFrame2, self.categoryFrame3 }
	self.equipmentSlotFrameMap = { [5] = self.categoryFrame1, [7] = self.categoryFrame2, [10] = self.categoryFrame3 }
	self:LoadCategories()
	self:InitFromOptions()
	self:UpdateLayout()
end
	
function EngraverFrameMixin:LoadCategories()
	C_Engraving.RefreshRunesList();
	local categories = C_Engraving.GetRuneCategories(true, true);
	if #categories > 0 then
		for c, category in ipairs(categories) do
			local categoryFrame = self.categoryFrames[c]
			if categoryFrame then
				categoryFrame:LoadCategoryRunes(category)
			end
		end
		self.noRunesFrame:Hide();
	else
		self.noRunesFrame:Show();
	end
end

function EngraverFrameMixin:InitFromOptions()
	self:UpdateScale(EngraverOptions.UIScale)
	Settings.SetOnValueChangedCallback("UIScale", function (_, _, newValue, ...) 
		self:UpdateScale(newValue) 
	end, self)

	self:SetDisplayMode(EngraverDisplayModes[EngraverOptions.DisplayMode+1].mixin)
	Settings.SetOnValueChangedCallback("EngraverDisplayMode", function (_, _, newValue, ...) 
		self:SetDisplayMode(EngraverDisplayModes[newValue+1].mixin) 
		self:UpdateLayout()
	end, self)
end

function EngraverFrameMixin:UpdateCategory(equipmentSlot)
	if self.equipmentSlotFrameMap then
		local categoryFrame = self.equipmentSlotFrameMap[equipmentSlot]
		if categoryFrame and categoryFrame.UpdateCategoryLayout then
			categoryFrame:UpdateCategoryLayout()
		end
	end
end

function EngraverFrameMixin:SetDisplayMode(displayModeMixin)
	if self.categoryFrames and displayModeMixin and type(displayModeMixin) == "table" then
		for c, categoryFrame in ipairs(self.categoryFrames) do
			if categoryFrame then
				if categoryFrame.TearDownDisplayMode then
					categoryFrame:TearDownDisplayMode()
				end
				Mixin(categoryFrame, displayModeMixin)
				if categoryFrame.SetUpDisplayMode then
					categoryFrame:SetUpDisplayMode()
				end
			end
		end
	end
end

function EngraverFrameMixin:UpdateScale(newScale)
	self:SetScale(newScale)
end

function EngraverFrameMixin:UpdateLayout()
	if self.categoryFrames then
		for c, categoryFrame in ipairs(self.categoryFrames) do
			if categoryFrame then
				if c == 1 then
					categoryFrame:SetPoint("TOPLEFT")
				elseif c > 1 then
					categoryFrame:SetPoint("TOPLEFT", self.categoryFrames[c-1], "BOTTOMLEFT")
				end
				if categoryFrame.UpdateCategoryLayout then
					categoryFrame:UpdateCategoryLayout()
				end
			end
		end
	end
end

-----------------------
-- CategoryFrameBase --
-----------------------

function EngraverCategoryFrameBaseMixin:LoadCategoryRunes(category)
	self:LoadEmptyRuneButton(category)
	local runes = C_Engraving.GetRunesForCategory(category, false);
	local knownRunes = C_Engraving.GetRunesForCategory(category, true);
	if not self.runeButtons then
		self.runeButtons = {}
	end
	for r, rune in ipairs(runes) do
		local runeButton = self.runeButtons[r]
		if not runeButton then
			runeButton = CreateFrame("Button", nil, self, "EngraverRuneButtonTemplate")
			Mixin(runeButton, CallbackRegistryMixin);
			runeButton:SetUndefinedEventsAllowed(true)
			runeButton:OnLoad()
			self.runeButtons[r] = runeButton
		end
		if runeButton then
			local isKnown = self:IsRuneKnown(rune, knownRunes)
			runeButton:SetRune(rune, category, isKnown)
		end
	end
end

function EngraverCategoryFrameBaseMixin:LoadEmptyRuneButton(slotId)
	if self.emptyRuneButton then
		Mixin(self.emptyRuneButton, CallbackRegistryMixin);
		self.emptyRuneButton:SetUndefinedEventsAllowed(true)
		self.emptyRuneButton:OnLoad()
		-- TODO figure out how to get slotName from slotId using API or maybe a constant somewhere
		local tempSlotsMap = {
			[5] = "CHESTSLOT",
			[7] = "LEGSSLOT",
			[10] = "HANDSSLOT"
		}
		local slotName = tempSlotsMap[slotId]
		local id, textureName, checkRelic = GetInventorySlotInfo(slotName);
		self:SetID(id);
		self.emptyRuneButton.icon:SetTexture(textureName);
	end
end

function EngraverCategoryFrameBaseMixin:IsRuneKnown(runeToCheck, knownRunes)
	for r, rune in ipairs(knownRunes) do
		if rune.skillLineAbilityID == runeToCheck.skillLineAbilityID then
			return true
		end
	end
end

function EngraverCategoryFrameBaseMixin:GetRuneButton(skillLineAbilityID)
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if runeButton.skillLineAbilityID == skillLineAbilityID then
				return runeButton
			end
		end
	end
end

function EngraverCategoryFrameBaseMixin:UpdateCategoryLayout()
	self:DetermineActiveAndInactiveButtons()
	if self.UpdateCategoryLayoutImpl then
		self:UpdateCategoryLayoutImpl() -- implemented by "subclasses"/mixins
	end
end

function EngraverCategoryFrameBaseMixin:DetermineActiveAndInactiveButtons()
	self.activeButton = nil
	self.inactiveButtons = {}
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if C_Engraving.IsRuneEquipped(runeButton.skillLineAbilityID) then
				self.activeButton = runeButton
			else
				table.insert(self.inactiveButtons, runeButton)
			end
		end
	end
end

--------------------------
-- CategoryFrameShowAll --
--------------------------

function EngraverCategoryFrameShowAllMixin:UpdateCategoryLayoutImpl()
	-- update position of each button and highlight the active one
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if runeButton then
				runeButton:SetShown(true)
				if r == 1 then
					runeButton:SetAllPoints()
				else
					runeButton:ClearAllPoints()
					runeButton:SetPoint("TOPLEFT", self.runeButtons[r-1], "TOPRIGHT")
				end
				runeButton:SetHighlighted(C_Engraving.IsRuneEquipped(runeButton.skillLineAbilityID))
			end
		end
	end
end

function EngraverCategoryFrameShowAllMixin:SetUpDisplayMode()
	-- do nothing for now
end

function EngraverCategoryFrameShowAllMixin:TearDownDisplayMode()
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:SetHighlighted(false)
		end
	end
end

----------------------------
-- CategoryFramePopUpMenu --
----------------------------

function EngraverCategoryFramePopUpMenuMixin:UpdateCategoryLayoutImpl()
	-- update visibility and position of each button
	if self.emptyRuneButton then
		self.emptyRuneButton:Hide()
	end
	if self.runeButtons then
		local showInactives = self:IsMouseOverAnyButtons()
		self.activeButton = self.activeButton or self.emptyRuneButton
		if self.activeButton then
			self.activeButton:SetShown(true)
			self.activeButton:SetAllPoints()
			if self.inactiveButtons then
				local prevButton = self.activeButton
				for r, runeButton in ipairs(self.inactiveButtons) do
					runeButton:SetShown(showInactives)
					runeButton:ClearAllPoints()
					runeButton:SetPoint("TOPLEFT", prevButton, "TOPRIGHT")
					prevButton = runeButton
				end
			end
		end
	end
end

function EngraverCategoryFramePopUpMenuMixin:SetUpDisplayMode()
	if self.emptyRuneButton then
		self.emptyRuneButton:RegisterCallback("PostOnEnter", self.OnRuneButtonPostEnter, self)
		self.emptyRuneButton:RegisterCallback("PostOnLeave", self.OnRuneButtonPostLeave, self)
	end
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:RegisterCallback("PostOnEnter", self.OnRuneButtonPostEnter, self)
			runeButton:RegisterCallback("PostOnLeave", self.OnRuneButtonPostLeave, self)
		end
	end
end

function EngraverCategoryFramePopUpMenuMixin:TearDownDisplayMode()
	if self.emptyRuneButton_PostOnEnterHandle then
		self.emptyRuneButton:UnregisterCallback("PostOnEnter", self)
		self.emptyRuneButton:UnregisterCallback("PostOnLeave", self)
		self.emptyRuneButton:Hide()
	end
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			runeButton:UnregisterCallback("PostOnEnter", self)
			runeButton:UnregisterCallback("PostOnLeave", self)
		end
	end
end

function EngraverCategoryFramePopUpMenuMixin:OnRuneButtonPostEnter()
	self:SetInactiveButtonsShown(true) 
end

function EngraverCategoryFramePopUpMenuMixin:OnRuneButtonPostLeave()
	self:SetInactiveButtonsShown(self:IsMouseOverAnyButtons())
end

function EngraverCategoryFramePopUpMenuMixin:IsMouseOverAnyButtons()
	if self.emptyRuneButton and self.emptyRuneButton:IsMouseOver() then
		return true
	end
	if self.runeButtons then
		for r, runeButton in ipairs(self.runeButtons) do
			if runeButton:IsMouseOver() then
				return true
			end
		end
	end
	return false
end

function EngraverCategoryFramePopUpMenuMixin:SetInactiveButtonsShown(isShown)
	for r, runeButton in ipairs(self.inactiveButtons) do
		runeButton:SetShown(isShown)
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
	if self.skillLineAbilityID then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetEngravingRune(self.skillLineAbilityID);
		self.showingTooltip = true;
		GameTooltip:Show();
	end
	self:TriggerEvent("PostOnEnter")
end

function EngraverRuneButtonMixin:OnLeave()
	GameTooltip_Hide();
	self.showingTooltip = false;
	self:TriggerEvent("PostOnLeave")
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