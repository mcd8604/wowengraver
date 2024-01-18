local addonName, Addon = ...

local MasqueAdapter = {}

local function OnRuneButtonsGroupCallback(Group, Option, Value)
	if Option == "Disabled" then
		if Value then
			EngraverFrame:LoadCategories()
		end
	end
end

local function OnDragTabGroupCallback(Group, Option, Value)
	if Option == "Disabled" and EngraverFrame.dragTab.NineSlice:CanChangeProtectedState() then
		EngraverFrame.dragTab.NineSlice:SetShown(Value)
	end
end

local originalLoadCategories = EngraverFrameMixin.LoadCategories
EngraverFrameMixin.LoadCategories = function(...)
	originalLoadCategories(...)
	if Addon.MasqueGroups and Addon.MasqueGroups.RuneButtons then
		for _, categoryFrame in pairs(EngraverFrame.equipmentSlotFrameMap) do
			for _, runeButton in ipairs(categoryFrame.runeButtons) do
				Addon.MasqueGroups.RuneButtons:AddButton(runeButton)
				Addon.MasqueGroups.RuneButtons:ReSkin(runeButton)
			end
		end
	end
end

local originalUpdateDragTabLayout = EngraverFrameMixin.UpdateDragTabLayout
EngraverFrameMixin.UpdateDragTabLayout = function(...)
	originalUpdateDragTabLayout(...)
	if Addon.MasqueGroups and Addon.MasqueGroups.DragTab then
		Addon.MasqueGroups.DragTab:ReSkin(EngraverFrame.dragTab)
	end
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_LOGIN", function(event, addonName)
	if LibStub then
		local Masque = LibStub("Masque", true)
		if Masque then
			Addon.MasqueGroups = {}
			Addon.MasqueGroups.RuneButtons = Masque:Group("Engraver", "Rune Buttons")
			Addon.MasqueGroups.RuneButtons:RegisterCallback(OnRuneButtonsGroupCallback, "Disabled")
			Addon.MasqueGroups.DragTab = Masque:Group("Engraver", "Drag Tab")
			Addon.MasqueGroups.DragTab:RegisterCallback(OnDragTabGroupCallback, "Disabled")
			Addon.MasqueGroups.DragTab:AddButton(EngraverFrame.dragTab)
			EngraverFrame.dragTab.NineSlice:SetShown(Addon.MasqueGroups.DragTab.db.Disabled)
			--Addon.MasqueGroups.FilterSelector = Masque:Group("Engraver", "Filter Selector")
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterRightButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterLeftButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterUpButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterDownButton)
		end
	end
end, nil)

Addon.MasqueAdapter = MasqueAdapter