local addonName, Addon = ...

local MasqueAdapter = {}

local function OnRuneButtonsGroupCallback(Group, Option, Value)
	if Option == "Disabled" then
		if Value then
			EngraverFrame:LoadCategories()
		end
	end
end

local originalDragTabOffsets = {}
local originalDragTabFilterButtonOffsets = {}
local originalDragTabTextOffsets = {}

local function CacheDragTabLayoutData()
	for i, layout in pairs(Addon.DragTabLayoutData) do
		originalDragTabOffsets[i] = layout.offset:Clone()
		originalDragTabFilterButtonOffsets[i] = layout.filterButtonOffset:Clone()
		originalDragTabTextOffsets[i] = layout.textOffset:Clone()
	end
	local originalDragTabSize = nil
end

local deltaTextOffsets = {
	CreateVector2D(2,0),
	CreateVector2D(0,-2),
	CreateVector2D(-2,0),
	CreateVector2D(0,2)
}

local function UpdateDragTabOffset(isDisabled)
	if not originalDragTabSize then
		if not EngraverFrame.dragTab.originalSize then
			EngraverFrame.dragTab.originalSize = CreateVector2D(EngraverFrame.dragTab:GetSize())
		end
		originalDragTabSize = EngraverFrame.dragTab.originalSize:Clone()
	end
	EngraverFrame.dragTab.originalSize = isDisabled and originalDragTabSize or CreateVector2D(76, 22)
	for i, layout in ipairs(Addon.DragTabLayoutData) do
		layout.offset = isDisabled and originalDragTabOffsets[i] or CreateVector2D(0,0)
		layout.filterButtonOffset = isDisabled and originalDragTabFilterButtonOffsets[i] or CreateVector2D(0,0)
		layout.textOffset = isDisabled and CreateVector2D(0,0) or deltaTextOffsets[i]:Clone()
		layout.textOffset:Add(originalDragTabTextOffsets[i])
	end
	EngraverFrame:UpdateDragTabLayout()
end

local function OnDragTabGroupCallback(Group, Option, Value)
	if Option == "Disabled" and EngraverFrame.dragTab.NineSlice:CanChangeProtectedState() then
		EngraverFrame.dragTab.NineSlice:SetShown(Value)
		UpdateDragTabOffset(Value)
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
			
			CacheDragTabLayoutData()
			Addon.MasqueGroups.DragTab = Masque:Group("Engraver", "Drag Tab")
			Addon.MasqueGroups.DragTab:RegisterCallback(OnDragTabGroupCallback, "Disabled")
			Addon.MasqueGroups.DragTab:AddButton(EngraverFrame.dragTab)
			EngraverFrame.dragTab.NineSlice:SetShown(Addon.MasqueGroups.DragTab.db.Disabled)
			UpdateDragTabOffset(Addon.MasqueGroups.DragTab.db.Disabled)

			--Addon.MasqueGroups.FilterSelector = Masque:Group("Engraver", "Filter Selector")
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterRightButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterLeftButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterUpButton)
			--Addon.MasqueGroups.FilterSelector:AddButton(EngraverFrame.filterDownButton)
		end
	end
end, nil)

Addon.MasqueAdapter = MasqueAdapter