local addonName, Addon = ...

local ActionBarSpellPushRemover = {
	lastPushedSpell = nil,
	lastPushedSlot = nil
}

function ActionBarSpellPushRemover:OnSpellPushedToActionBar(spellId, slot, page)
	self.lastPushedSpell = spellId
	self.lastPushedSlot = slot
end

function ActionBarSpellPushRemover:OnActionBarSlotChanged(slot)
	if self.lastPushedSpell ~= nil and self.lastPushedSlot == slot then
		self.lastPushedSpell = nil
		self.lastPushedSlot = nil
		PickupAction(slot)
		ClearCursor()
	end
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD", function(event, ...)
	EngraverOptionsCallbackRegistry:RegisterCallback("AutoSpellBarRemoval", function(_, newValue)
		if newValue then
			EventRegistry:RegisterFrameEventAndCallback("SPELL_PUSHED_TO_ACTIONBAR", ActionBarSpellPushRemover.OnSpellPushedToActionBar, ActionBarSpellPushRemover);
			EventRegistry:RegisterFrameEventAndCallback("ACTIONBAR_SLOT_CHANGED", ActionBarSpellPushRemover.OnActionBarSlotChanged, ActionBarSpellPushRemover);
		else
			EventRegistry:UnregisterFrameEventAndCallback("SPELL_PUSHED_TO_ACTIONBAR", ActionBarSpellPushRemover);
			EventRegistry:UnregisterFrameEventAndCallback("ACTIONBAR_SLOT_CHANGED", ActionBarSpellPushRemover);
		end
	end)
end)