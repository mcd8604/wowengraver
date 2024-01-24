local _, Addon = ...

EngraverFilters = {} -- SavedVariable

local playerClassName, _, _ = UnitClass("player")

local FiltersMixin = {}

function FiltersMixin:GetFiltersForPlayerClass()
	EngraverFilters = EngraverFilters or {}
	if EngraverFilters[playerClassName] == nil then
		EngraverFilters[playerClassName] = {}
	end
	return EngraverFilters[playerClassName]
end

function FiltersMixin:CreateFilter(filterName)
	local filters = self:GetFiltersForPlayerClass()	
	table.insert(filters, { Name = filterName, RuneIDs = {} })
	EngraverOptionsCallbackRegistry:TriggerEvent("FiltersChanged")
	return #filters
end

function FiltersMixin:GetFilter(index)
	if index then
		return self:GetFiltersForPlayerClass()[index]
	end
end

function FiltersMixin:GetCurrentFilter()
	if EngraverOptions.CurrentFilter > 0 then
		return self:GetFilter(EngraverOptions.CurrentFilter)
	end
end

function FiltersMixin:GetCurrentFilterName()
	local filter = self:GetCurrentFilter()
	if filter ~= nil then
		return filter.Name
	end
end

function FiltersMixin:IsCurrentFilterValid()
	return EngraverOptions.CurrentFilter ~= nil and EngraverOptions.CurrentFilter > 0
end

function FiltersMixin:SetCurrentFilter(index, force)
	if EngraverOptions.CurrentFilter ~= index or force == true then
		local safeIndex = index % (#self:GetFiltersForPlayerClass()+1)
		local filter = self:GetFilter(safeIndex)
		if safeIndex == 0 or filter ~= nil then
			EngraverOptions.CurrentFilter = safeIndex 
			EngraverOptionsCallbackRegistry:TriggerEvent("CurrentFilter", EngraverOptions.CurrentFilter)
		end
	end
end

function FiltersMixin:SetCurrentFilterNext()
	self:SetCurrentFilter((EngraverOptions.CurrentFilter+1), false)
end

function FiltersMixin:SetCurrentFilterPrev()
	self:SetCurrentFilter((EngraverOptions.CurrentFilter-1), false)
end

function FiltersMixin:DeleteCurrentFilter()
	return self:DeleteFilter(EngraverOptions.CurrentFilter)
end

function FiltersMixin:DeleteFilter(index)
	if index then
		local filters = self:GetFiltersForPlayerClass()
		if filters[index] then
			local filter =  table.remove(filters, index)
			EngraverOptionsCallbackRegistry:TriggerEvent("FiltersChanged")
			EngraverOptionsCallbackRegistry:TriggerEvent("FilterDeleted", index)
			self:SetCurrentFilter(index, true)
			return filter
		end
	end
end

function FiltersMixin:ReorderFilter(fromIndex, toIndex)
	if fromIndex > 0 then
		local filters = self:GetFiltersForPlayerClass()
		if toIndex <= #filters then
			table.insert(filters, toIndex, table.remove(filters, fromIndex))
			EngraverOptionsCallbackRegistry:TriggerEvent("FiltersChanged")
			-- Always keep the CurrentFilter the same after a re-order
			if EngraverOptions.CurrentFilter > 0 then
				if EngraverOptions.CurrentFilter == toIndex then
					self:SetCurrentFilter(fromIndex)
				elseif EngraverOptions.CurrentFilter == fromIndex then
					self:SetCurrentFilter(toIndex)
				end
			end
		end
	end
end

function FiltersMixin:RenameFilter(filterIndex, newName)
	local filter = self:GetFilter(filterIndex)
	if filter then
		filter.Name = newName
		EngraverOptionsCallbackRegistry:TriggerEvent("FiltersChanged")
	end
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
			EngraverOptionsCallbackRegistry:TriggerEvent("FiltersChanged")
		end
	end
end

Addon.Filters = CreateFromMixins(FiltersMixin)
Addon.Filters.NO_FILTER_DISPLAY_STRING = "(No Filter)"