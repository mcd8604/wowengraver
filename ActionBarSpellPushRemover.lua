local addonName, Addon = ...

local ActionBarSpellPushRemover = {
	lastPushedSpell = nil,
	lastPushedSlot = nil
}

function ActionBarSpellPushRemover:OnSpellPushedToActionBar(spellId, slot, page)
	self.lastPushedSpell = spellId
	self.lastPushedSlot = slot
end

function ActionBarSpellPushRemover:SetActive(isActive)
	if isActive then
		IconIntroTracker:UnregisterEvent("SPELL_PUSHED_TO_ACTIONBAR");
	else
		IconIntroTracker:RegisterEvent("SPELL_PUSHED_TO_ACTIONBAR");
	end
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD", function(event, ...)
	EngraverOptionsCallbackRegistry:RegisterCallback("PreventSpellPlacement", function(_, newValue) ActionBarSpellPushRemover:SetActive(newValue) end)
	ActionBarSpellPushRemover:SetActive(EngraverOptions.PreventSpellPlacement)
end)