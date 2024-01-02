local _, Addon = ...

EngraverFilters = {} -- SavedVariable

local playerClassName, _, _ = UnitClass("player")

local FiltersMixin = {}

function FiltersMixin:GetFiltersForPlayerClass()
	EngraverFilters = EngraverFilters or {}
	if EngraverFilters[playerClassName] == nil then
		EngraverFilters[playerClassName] = {}
	end
	if #EngraverFilters[playerClassName] == 0 then
		EngraverFilters[playerClassName][1] = { Name = "Default", RuneIDs = {} }
	end
	return EngraverFilters[playerClassName]
end

function FiltersMixin:GetFilter(index)
	local filter = self:GetFiltersForPlayerClass()[index]
	if filter then
		filter.Name = filter.Name or "Default"
		filter.RuneIDs = filter.RuneIDs or {}
	end
	return filter
end

function FiltersMixin:GetCurrentFilter()
	local index = 1 -- TODO refactor for multiple filters, save current filter index in EngraverOptions
	return self:GetFilter(index)
end

function FiltersMixin:AnyRunePassesFilter(runes, optionalFilter)
	if runes == nil or #runes == 0 then
		return false
	end
	local filter = optionalFilter or self:GetCurrentFilter()
	if filter == nil or filter.RuneIDs == nil then
		return true
	end
	for r, rune in ipairs(runes) do
		if self:RunePassesFilter(rune, filter) then
			return true
		end
	end
	return false
end

function FiltersMixin:RunePassesFilter(rune, optionalFilter)
	if rune == nil or rune.skillLineAbilityID == nil then
		return false
	end
	local filter = optionalFilter or self:GetCurrentFilter()
	return filter == nil or filter.RuneIDs == nil or filter.RuneIDs[rune.skillLineAbilityID] == nil
end

function FiltersMixin:GetFilteredRunes(runes, optionalFilter)
	local filteredRunes = {}
	if runes == nil or #runes == 0 then
		return filteredRunes
	end
	local filter = optionalFilter or self:GetCurrentFilter()
	for r, rune in ipairs(runes) do
		if self:RunePassesFilter(rune, filter) then
			table.insert(filteredRunes, rune)
		end
	end
	return filteredRunes
end

function FiltersMixin:GetFilteredRunesForCategory(category, ownedOnly) 
	return self:GetFilteredRunes(C_Engraving.GetRunesForCategory(category, ownedOnly))
end

function FiltersMixin:ToggleRune(filterIndex, runeID, toggleState)
	if runeID ~= nil then
		local filter = self:GetFilter(filterIndex)
		if filter then
			if toggleState then
				filter.RuneIDs[runeID] = nil
			else
				filter.RuneIDs[runeID] = false
			end
			EngraverOptionsCallbackRegistry:TriggerEvent("FilterChanged", filterIndex)
		end
	end
end

Addon.Filters = CreateFromMixins(FiltersMixin)

EngraverFilter = Addon.Filters