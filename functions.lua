local bdlc, l, f = select(2, ...):unpack()
local libc = LibStub:GetLibrary("LibCompress")

-- tooltip scanning
local tts = CreateFrame('GameTooltip', 'BDLC:TooltipScan', UIParent, 'GameTooltipTemplate')
tts:SetOwner(UIParent, 'ANCHOR_NONE')

-- return item ID(s) for gear comparison
function bdlc:fetchUserGear(unit, itemLink)
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
	local isRelic = bdlc:IsRelic(itemLink)
	local isTier = bdlc:IsTier(itemLink)
	
	if (isTier) then
		if (strfind(name:lower(), l["tierHelm"]:lower())) then
			equipSlot = "INVTYPE_HEAD"
		elseif (strfind(name:lower(), l["tierShoulders"]:lower())) then
			equipSlot = "INVTYPE_SHOULDER"
		elseif (strfind(name:lower(), l["tierLegs"]:lower())) then
			equipSlot = "INVTYPE_LEGS"
		elseif (strfind(name:lower(), l["tierCloak"]:lower())) then
			equipSlot = "INVTYPE_BACK"
		elseif (strfind(name:lower(), l["tierChest"]:lower())) then
			equipSlot = "INVTYPE_CHEST"
		elseif (strfind(name:lower(), l["tierGloves"]:lower())) then
			equipSlot = "INVTYPE_HAND"
		end
	end
	
	local slotID = 0;
	if (equipSlot == "INVTYPE_HEAD") then slotID = 1 end
	if (equipSlot == "INVTYPE_NECK") then slotID = 2 end
	if (equipSlot == "INVTYPE_SHOULDER") then slotID = 3 end
	if (equipSlot == "INVTYPE_BODY") then slotID = 4 end
	if (equipSlot == "INVTYPE_CHEST" or equipSlot == "INVTYPE_ROBE") then slotID = 5 end
	if (equipSlot == "INVTYPE_WAIST") then slotID = 6 end
	if (equipSlot == "INVTYPE_LEGS") then slotID = 7 end
	if (equipSlot == "INVTYPE_FEET") then slotID = 8 end
	if (equipSlot == "INVTYPE_WRIST") then slotID = 9 end
	if (equipSlot == "INVTYPE_HAND") then slotID = 10 end
	if (equipSlot == "INVTYPE_BACK") then slotID = 15 end
	if (equipSlot == "INVTYPE_CLOAK") then slotID = 15 end
	if (equipSlot == "INVTYPE_OFFHAND") then slotID = 17 end
	if (equipSlot == "INVTYPE_RANGED") then slotID = 18 end
	
	
	local itemLink1 = GetInventoryItemLink(unit, slotID)
	local itemLink2 = 0

	if (equipSlot == "INVTYPE_FINGER") then 
		itemLink1 = GetInventoryItemLink(unit, 11)
		itemLink2 = GetInventoryItemLink(unit, 12)
		slotID = 11
	end
	if (equipSlot == "INVTYPE_TRINKET") then
		itemLink1 = GetInventoryItemLink(unit, 13)
		itemLink2 = GetInventoryItemLink(unit, 14)
		slotID = 13
	end
	if (equipSlot == "INVTYPE_WEAPON" or equipSlot == "INVTYPE_2HWEAPON" or equipSlot == "INVTYPE_SHIELD" or equipSlot == "INVTYPE_HOLDABLE" or equipSlot == "INVTYPE_RANGEDRIGHT" or equipSlot == "INVTYPE_RANGED" or equipSlot == "INVTYPE_WEAPONMAINHAND") then
		itemLink1 = GetInventoryItemLink(unit, 16)
		itemLink2 = GetInventoryItemLink(unit, 17)
		slotID = 16
	end
	if (isRelic) then
		local relicType = bdlc:GetRelicType(itemLink)
		local relic1, relic2 = bdlc:GetRelics(relicType)
		
		if (relic1) then
			itemLink1 = relic1
		end
		if (relic2) then
			itemLink2 = relic2
		end
	end
	if (not itemLink1) then
		itemLink1 = 0
	end
	if (not itemLink2) then
		itemLink2 = 0
	end
	
	if (slotID == 0 and not isRelic) then
		print("bdlc can't find compare for slot: "..equipSlot..". Let the developer know");
	end
	
	return itemLink1, itemLink2
end

-- returns name-server for any valid unitID
function FetchUnitName(name)
	local name, server = strsplit("-", name)
	
	local name_server = GetUnitName(name, true)
	if (name_server) then
		name = name_server
	end
	name, server = strsplit("-", name)
	if (not server) then
		server = GetRealmName()
	end
	
	if (not name) then return end

	return name.."-"..server
end

-- send compressed addon message with paramaters automatically deliminated
function bdlc:sendAction(action, ...)
	print("predata:", ...)
	local delim = "<>"
	local paramString = strjoin(delim, ...)
	print("postdata:",paramString)

	-- allow the user to whisper through this function
	local channel = "WHISPER"
	local sender = UnitName("player")
	if (IsInRaid() or IsInGroup() or UnitInRaid("player")) then channel = "RAID" end
	if (bdlc.overrideChannel) then channel = bdlc.overrideChannel end
	if (bdlc.overrideSender) then sender = bdlc.overrideSender end

	-- compress then send
	local data = libc:Compress(action..delim..paramString)
	print("data:",data)
	SendAddonMessage(bdlc.message_prefix, data, channel, sender);

	-- unset these, probably shouldn't have them in the first place but it works
	bdlc.overrideChannel = nil
	bdlc.overrideSender = nil
end

local function searchArray(arr, val)
	for k, v in pairs(arr) do
		if (v == val) then 
			return true
		end
	end
	return false
end

function bdlc:itemEquippable(itemUID)
	return true
end
function bdlc:itemEquippable2(itemUID)
	-- this feature isn't localized
	if (GetLocale() ~= "enUS" and GetLocale() ~= "enGB") then return true end

	local itemLink = bdlc.itemUID_Map[itemUID]
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
	local playerClass = select(2, UnitClass("player"))
	local armorType = nil
	local classes = {}
	
	classes["WARRIOR"] = {}
	classes["WARRIOR"].armor = "Plate"
	classes["WARRIOR"].tier = l["tierProtector"]
	classes["WARRIOR"].relics = {"Iron", "Blood", "Shadow", "Fire", "Storm"}
	
	classes["PALADIN"] = {}
	classes["PALADIN"].armor = "Plate"
	classes["PALADIN"].tier = l["tierConqueror"]
	classes["PALADIN"].relics = {"Life", "Holy", "Iron", "Fire", "Arcane"}
	
	classes["HUNTER"] = {}
	classes["HUNTER"].armor = "Mail"
	classes["HUNTER"].tier = l["tierProtector"]
	classes["HUNTER"].relics = {"Storm", "Arcane", "Blood", "Iron", "Life"}
	
	classes["ROGUE"] = {}
	classes["ROGUE"].armor = "Leather"
	classes["ROGUE"].tier = l["tierVanquisher"]
	classes["ROGUE"].relics = {"Shadow", "Blood", "Fel", "Iron", "Storm", "Fel"}
	
	classes["PRIEST"] = {}
	classes["PRIEST"].armor = "Cloth"
	classes["PRIEST"].tier =l["tierConqueror"]
	classes["PRIEST"].relics = {"Holy", "Shadow", "Blood", "Life"}
	
	classes["DEATHKNIGHT"] = {}
	classes["DEATHKNIGHT"].armor = "Plate"
	classes["DEATHKNIGHT"].tier = l["tierVanquisher"]
	classes["DEATHKNIGHT"].relics = {"Blood", "Frost", "Fire", "Shadow", "Iron"}
	
	classes["SHAMAN"] = {}
	classes["SHAMAN"].armor = "Mail"
	classes["SHAMAN"].tier = l["tierProtector"]
	classes["SHAMAN"].relics = {"Storm", "Fire", "Life", "Frost", "Iron"}
	
	classes["MAGE"] = {}
	classes["MAGE"].armor = "Cloth"
	classes["MAGE"].tier = l["tierVanquisher"]
	classes["MAGE"].relics = {"Arcane", "Fire", "Frost"}
	
	classes["WARLOCK"] = {}
	classes["WARLOCK"].armor = "Cloth"
	classes["WARLOCK"].tier = l["tierConqueror"]
	classes["WARLOCK"].relics = {"Shadow", "Fel", "Blood", "Fire"}
	
	classes["MONK"] = {}
	classes["MONK"].armor = "Leather"
	classes["MONK"].tier = l["tierProtector"]
	classes["MONK"].relics = {"Life", "Frost", "Storm", "Iron"}
	
	classes["DRUID"] = {}
	classes["DRUID"].armor = "Leather"
	classes["DRUID"].tier = l["tierVanquisher"]
	classes["DRUID"].relics = {"Arcane", "Frost", "Fire", "Life", "Blood"}
	
	classes["DEMONHUNTER"] = {}
	classes["DEMONHUNTER"].armor = "Leather"
	classes["DEMONHUNTER"].tier = l["tierConqueror"]
	classes["DEMONHUNTER"].relics = {"Fel", "Iron", "Shadow", "Arcane"}
	
	local myClass = classes[playerClass]
	
	if (class == "Armor" and subclass ~= "Miscellaneous" and subclass ~= "Cosmetic" and equipSlot ~= "INVTYPE_CLOAK") then
		armorType = subclass
	elseif (bdlc:IsRelic(itemLink)) then
		local relicType = bdlc:GetRelicType(itemLink)
		
		if (searchArray(myClass.relics, relicType)) then
			bdlc:debug("This item is "..relicType..". I am a "..playerClass.." I can use this!")
			return true
		else
			return false
		end
	elseif (bdlc:IsTier(itemLink)) then
			bdlc:debug("This item is tier. I am tier "..myClass.tier.." I can use this!")
		if (string.find(itemLink, myClass.tier)) then
			return true
		else
			return false
		end
	else
		bdlc:debug("This is not armor")
		return true
	end
	
	if (armorType ~= myClass.armor) then
		bdlc:debug("This item is "..armorType..". I am a "..playerClass.." I can't use this!!")
		return false
	end
	
	bdlc:debug("This item is "..armorType..". I am a "..playerClass.." I can totally use this!!")
	return true
end

function bdlc:IsTier(itemLink)
	local tier_names = {
		[l["tierProtector"]] = true,
		[l["tierConqueror"]] = true,
		[l["tierVanquisher"]] = true
	}

	tts:SetOwner(UIParent, 'ANCHOR_NONE')
	tts:SetHyperlink(itemLink)
	local name = select(1, GetItemInfo(itemLink))
	
	local isTier = false
	for k, v in pairs(tier_names) do
		if (strfind(name:lower(), k:lower())) then isTier = true end
	end
	
	return isTier
end

function bdlc:GetItemValue(itemLink)
	tts:SetOwner(UIParent, 'ANCHOR_NONE')
	tts:SetHyperlink(itemLink)
	local itemString = string.match(itemLink, "item[%-?%d:]+")

	local gem1 = select(4, string.split(":", itemString))
	local ilvl = select(4, GetItemInfo(itemLink))
	local wf_tf = false;
	local socket = tonumber(gem1) and true or false
	local infostr = "";
	
	-- Get Wf/TF
	for i = 1, 4 do
		local text = _G['BDLC:TooltipScanTextLeft'..i] and _G['BDLC:TooltipScanTextLeft'..i]:GetText() and _G['BDLC:TooltipScanTextLeft'..i]:GetText():lower() or nil;
		if text then
			wf_tf = wf_tf or text:find(l["itemWarforged"]:lower()) and true or false
			wf_tf = wf_tf or text:find(l["itemTitanforged"]:lower()) and true or false			
		end
	end
	tts:Hide()
	
	if (wf_tf) then
		infostr = "|cff00FF00+"..ilvl.."|r"
	else
		infostr = ilvl;
	end
	if (socket) then
		infostr = infostr.." |cff55AAFFS|r"
	end
	return ilvl, wf_tf, socket, infostr
end

-- this used to return a parsed itemstring with only necessary info, but we'll just compress the raw itemLink instead
function bdlc:GetItemUID(itemLink)
	return libc:Compress(itemLink)

	--[[local itemString = string.match(itemLink, "item[%-?%d:]+")
	if (not itemString) then return false end
	local itemType, itemID, enchant, gem1, gem2, gem3, gem4, suffixID, uniqueID, level, upgradeId, instanceDifficultyID, numBonusIDs, bonusID1, bonusID2, upgradeValue, wf_tf  = string.split(":", itemString)
	
	gem1 = string.len(gem1) > 0 and gem1 or 0
	bonusID1 = string.len(bonusID1) > 0 and bonusID1 or 0
	bonusID2 = string.len(bonusID2) > 0 and bonusID2 or 0
	upgradeValue = string.len(upgradeValue) > 0 and upgradeValue or 0
	
	return itemID..":"..gem1..":"..bonusID1..":"..bonusID2..":"..upgradeValue--]]
end

-- case insensitive search
function bdlc:SmartSearch(str,ss)
	local search = {strsplit(" ",ss)} or {ss}
	local found = true
	str = str:lower()
	ss = ss:lower()
	for s = 1, #search do
		if (string.find(str,search[s])) then
			found = true
			break
		end
	end
	return found
end

-- cast insensitive strip
function bdlc:SmartStrip(str,ss)
	local search = {strsplit(" ",ss)} or {ss}
	str = str:lower()
	orig = str:lower()
	ss = ss:lower()
	for s = 1, #search do
		str = str:gsub(search[s],"")
	end
	str = str:gsub(" ","")

	return str
end

-- determines if given string is a relic string
function bdlc:RelicString(str)
	local ss = string.format(RELIC_TOOLTIP_TYPE, "")
	ss = ss:gsub("%W", " ")
	ss = ss:lower()
	str = str:lower()
	
	local search = {strsplit(" ",ss)} or {ss}
	local nummatch = #search
	local matched = 0
	local isrelic = false
	for s = 1, #search do
		if (str:find(search[s])) then
			matched = matched + 1
		end
	end
	if (nummatch == matched) then
		return true
	else
		return false
	end
end

function bdlc:IsRelic(relicLink)
	local isRelic = false
	tts:SetOwner(UIParent, 'ANCHOR_NONE')
	tts:SetHyperlink(relicLink)
	
	local subclass = select(7, GetItemInfo(relicLink))
	if (subclass and bdlc:RelicString(subclass)) then
		isRelic = true
	end
	
	for i = 2, 6 do
		local text = _G['BDLC:TooltipScanTextLeft'..i] and _G['BDLC:TooltipScanTextLeft'..i]:GetText() or nil;
		if (text and bdlc:RelicString(text)) then
			isRelic = true
			break
		end
	end
	
	tts:Hide()

	return isRelic
end

-- return relic type (life, iron, blood, etc)
function bdlc:GetRelicType(relicLink)
	local relicType
	local ss = EJ_LOOT_SLOT_FILTER_ARTIFACT_RELIC:lower()
	
	tts:SetOwner(UIParent, 'ANCHOR_NONE')
	tts:SetHyperlink(relicLink)
	for i = 2, 6 do
		local text = _G['BDLC:TooltipScanTextLeft'..i] and _G['BDLC:TooltipScanTextLeft'..i]:GetText() or nil;
		--[[if (text and string.match(text,l["relicType"]) and not relicType) then
			relicType = string.gsub(text,l["relicType"], "%1")
		end--]]
		--if (not relicType) then -- the regex failed, lets search with localization
		if (text and bdlc:RelicString(text)) then
			local search = {strsplit(" ",ss)} or {ss}
			local str = text:lower()
			for s = 1, #search do
				str = str:gsub(search[s],"")
			end
			str = str:gsub(" ","")
			
			if (strlen(str) > 0) then 
				relicType = str
				break
			end
		end
		--end
	end
	tts:Hide()
		
	return relicType
end

function bdlc:GetRelics(rt)
	SocketInventoryItem(17)
	SocketInventoryItem(16)
	LoadAddOn("Blizzard_ArtifactUI")
	
	local relic1, relic2

	for relicSlotIndex = 1, C_ArtifactUI.GetNumRelicSlots() do
		local lockedReason, relicName, relicIcon, relicLink = C_ArtifactUI.GetRelicInfo(relicSlotIndex);
		
		if (relicLink) then
			local relicType = bdlc:GetRelicType(relicLink)
		
			if (relicType:lower() == rt:lower()) then
				if (not relic1) then
					relic1 = relicLink
				else
					relic2 = relicLink
				end
			end
		end
	end

	HideUIPanel(ArtifactFrame)

	return relic1, relic2
end

function bdlc:inLC()
	return bdlc.loot_council[FetchUnitName("player")] or IsMasterLooter() or not IsInRaid()
end

function IsRaidLeader()
	return UnitLeadsAnyGroup("player")
end

function bdlc:debug(msg)
	if (bdlc.config.debug) then print("|cff3399FFBCLC:|r "..msg) end
end

function bdlc:skinBackdrop(frame, ...)
	if (frame.background) then return false end
	
	local border = {0,0,0,1}
	local color = {...}
	if (not ... ) then
		color = {.11,.15,.18, 1}
		border = {.06, .08, .09, 1}
	end

	frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    frame:SetBackdropColor(unpack(color))
    frame:SetBackdropBorderColor(unpack(border))
	
	return true
end

function bdlc:skinButton(f,small,color)
	local colors = {.1,.1,.1,1}
	local hovercolors = {0,0.55,.85,1}
	if (color == "red") then
		colors = {.6,.1,.1,0.6}
		hovercolors = {.6,.1,.1,1}
	elseif (color == "blue") then
		colors = {0,0.55,.85,0.6}
		hovercolors = {0,0.55,.85,1}
	elseif (color == "dark") then
		colors = {.1,.1,.1,1}
		hovercolors = {.1,.1,.1,1}
	end
	f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = {left=1,top=1,right=1,bottom=1}})
	f:SetBackdropColor(unpack(colors)) 
    f:SetBackdropBorderColor(0,0,0,1)
    f:SetNormalFontObject("bdlc_button")
	f:SetHighlightFontObject("bdlc_button")
	f:SetPushedTextOffset(0,-1)
	
	f:SetSize(f:GetTextWidth()+16,24)
	
	--if (f:GetWidth() < 24) then
	if (small and f:GetWidth() <= 24 ) then
		f:SetWidth(20)
	end
	
	if (small) then
		f:SetHeight(18)
	end
	
	f:HookScript("OnEnter", function(f) 
		f:SetBackdropColor(unpack(hovercolors)) 
	end)
	f:HookScript("OnLeave", function(f) 
		f:SetBackdropColor(unpack(colors)) 
	end)
	
	return true
end

function bdlc:split(str, del)
	local t = {}
	local index = 0;
	while (string.find(str, del)) do
		local s, e = string.find(str, del)
		t[index] = string.sub(str, 1, s-1)
		str = string.sub(str, s+#del)
		index = index + 1;
	end
	table.insert(t, str)
	return t;
end
