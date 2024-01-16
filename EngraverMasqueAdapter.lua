local addonName, Addon = ...

local MasqueAdapter = {}

EventRegistry:RegisterFrameEventAndCallback("PLAYER_LOGIN", function(event, addonName)
	if LibStub then
		local Masque = LibStub("Masque", true)
		if Masque then
			Addon.MasqueGroups = {}
			Addon.MasqueGroups.RuneButtons = Masque:Group("Engraver", "Rune Buttons")
			--Addon.MasqueGroups.DragTab = Masque:Group("Engraver", "Drag Tab")
			--Addon.MasqueGroups.DragTab:AddButton(EngraverFrame.dragTab)
			--Addon.MasqueGroups.FilterSelector = Masque:Group("Engraver", "Filter Selector")
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterRightButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterLeftButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterUpButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterDownButton)
		end
	end
end, nil)

function MasqueAdapter:TryAddRuneButton(runeButton)
	if Addon.MasqueGroups and Addon.MasqueGroups.RuneButtons then
		Addon.MasqueGroups.RuneButtons:AddButton(runeButton)
	end
end

Addon.MasqueAdapter = MasqueAdapter