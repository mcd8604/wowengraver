if not C_Engraving:IsEngravingEnabled() then
	return
end

local localAddonName, Addon = ...

SLASH_ENGRAVER1, SLASH_ENGRAVER2, SLASH_ENGRAVER3, SLASH_ENGRAVER4, SLASH_ENGRAVER5, SLASH_ENGRAVER6 = "/en", "/eng", "/eg", "/re", "/engraver", "/engraving"
SlashCmdList.ENGRAVER = function(msg, editBox)
	Settings.OpenToCategory(localAddonName);
end

local function FindRune(nameOrID)
	C_Engraving:ClearAllCategoryFilters();
	C_Engraving.RefreshRunesList();
	local categories = C_Engraving.GetRuneCategories(false, false);
	if #categories > 0 then
		local parsedID = tonumber(nameOrID)
		for c, category in ipairs(categories) do
			for r, rune in ipairs(C_Engraving.GetRunesForCategory(category, false)) do
				if rune.name == nameOrID then
					return category, rune
				elseif parsedID ~= nil then
					if rune.skillLineAbilityID == parsedID then
						return category, rune
					else
						if rune.learnedAbilitySpellIDs and #rune.learnedAbilitySpellIDs > 0 and parsedID == rune.learnedAbilitySpellIDs[1] then
							return category, rune
						end
					end
				end
			end
		end
	end
end

SLASH_ENGRAVE1 = "/engrave"
SlashCmdList.ENGRAVE = function(msg, editBox)
	if msg == nil or strlen(msg) <= 0 then
		SendSystemMessage("(Engraver) Usage: /engrave runeName or /engrave spellID")
		return
	end
	local category, rune = FindRune(msg)
	if rune == nil then
		SendSystemMessage("(Engraver) Rune not found for: "..msg)
		return
	end
	Addon:TryEngrave(Addon.CategoryToSlotId[category][1], rune.skillLineAbilityID)
end

SLASH_ENGRAVESLOT1 = "/engraveslot"
SlashCmdList.ENGRAVESLOT = function(msg, editBox)
	local UsageMessage = "(Engraver) Usage: /engraveslot slotNumber rune"
	if msg == nil or strlen(msg) <= 0 then
		SendSystemMessage(UsageMessage)
		return
	end
	msg = string.gsub(msg, "%s+", " ")
	local i, j = string.find(msg, "%s")
	if i == nil then
		SendSystemMessage(UsageMessage)
		return
	end
	local slot = string.sub(msg, 1, i)
	local runeString = string.sub(msg, j+1)
	local category, rune = FindRune(runeString)
	if rune == nil then
		SendSystemMessage("(Engraver) Rune not found for: "..runeString)
		return
	end
	Addon:TryEngrave(slot, rune.skillLineAbilityID)
end

SLASH_ENGRAVER_RESET_POSITION1 = "/engraver_reset_position"
SlashCmdList.ENGRAVER_RESET_POSITION = function(msg, editBox)
	EngraverFrame:ClearAllPoints(); 
	EngraverFrame:SetPoint("CENTER", UIParent, "CENTER");
end

SLASH_ENGRAVER_FILTER1, SLASH_ENGRAVER_FILTER2 = "/engraver_filter", "/ef"
SlashCmdList.ENGRAVER_FILTER = function(msg, editBox)
	if msg == nil or strlen(msg) <= 0 then
		Addon.Filters:SetCurrentFilter(0)
	else
		local filterIndex = Addon.Filters:FindFilterIndex(msg)
		if filterIndex > 0 then
			Addon.Filters:SetCurrentFilter(filterIndex)
		else
			SendSystemMessage("(Engraver) Filter not found for: "..msg)
			return
		end
	end
end