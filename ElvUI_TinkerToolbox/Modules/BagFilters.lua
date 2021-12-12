local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)

local CBF = TT:NewModule('CustomBagFilters', 'AceEvent-3.0')
local B = E.Bags

local ACH, SharedOptions
local optionsPath

local next = next
local ipairs = ipairs
local strmatch = strmatch
local strtrim = strtrim
local format = format
local tinsert = tinsert

local CopyTable = CopyTable

local GetContainerItemInfo = GetContainerItemInfo
local GetItemInfo = GetItemInfo

local C_Item_DoesItemExist = C_Item and C_Item.DoesItemExist
local C_Item_GetCurrentItemLevel = C_Item and C_Item.GetCurrentItemLevel
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo

local CreateFrame = CreateFrame
local ToggleFrame = ToggleFrame
local GameTooltip_Hide = GameTooltip_Hide
local GameTooltip = GameTooltip

local bagIDs = { 0, 1, 2, 3, 4 }
local bankIDs = { -1, 5, 6, 7, 8, 9, 10 }

local newInfo = { name = '', func = '' }
local premade = ''
local EncodedInfo, DecodedInfo

if not E.Retail then
	tinsert(bagIDs, KEYRING_CONTAINER)
end

if not E.Classic then
	tinsert(bankIDs, 11)
end

local DefaultFilters = {
	Equipment = { name = L["BAG_FILTER_EQUIPMENT"], icon = 132626, func = "function(cache) return cache.classID == LE_ITEM_CLASS_ARMOR or cache.classID == LE_ITEM_CLASS_WEAPON end" },
	Consumable = { name = L["BAG_FILTER_CONSUMABLES"], icon = 134873, func = "function(cache) return cache.classID == LE_ITEM_CLASS_CONSUMABLE end" },
	QuestItems = { name = L["ITEM_BIND_QUEST"], icon = 136797, func = "function(cache) return cache.classID == LE_ITEM_CLASS_QUESTITEM end" },
	TradeGoods = { name = L["BAG_FILTER_TRADE_GOODS"], icon = 132906, func = "function(cache) return cache.classID == LE_ITEM_CLASS_TRADEGOODS or cache.classID == LE_ITEM_CLASS_RECIPE or cache.classID == LE_ITEM_CLASS_GEM or cache.classID == LE_ITEM_CLASS_ITEM_ENHANCEMENT or cache.classID == LE_ITEM_CLASS_GLYPH end" },
	BattlePets = { name = L["Battle Pets"], icon = 643856, func = "function(cache) return cache.classID == LE_ITEM_CLASS_BATTLEPET or (cache.classID == LE_ITEM_CLASS_MISCELLANEOUS and cache.subclassID == 2) end" },
	Miscellaneous = { name = L["Miscellaneous"], icon = 134414, func = "function(cache) return cache.classID == LE_ITEM_CLASS_MISCELLANEOUS or cache.classID == LE_ITEM_CLASS_CONTAINER end" },
	NewItems = { name = L["New Items"], icon = 255351, func = "function(cache) return cache.itemLocation and C_NewItems.IsNewItem(cache.itemLocation.bagID, cache.itemLocation.slotIndex) end" }
}

G.CustomBagFilters = {}

CBF.ItemCache = {}
CBF.BagCache = {}
CBF.RefreshBag = {}
CBF.FilterFunctions = {}

local emptyTable = {}

local function buildFunction(str)
	local func = loadstring('return '..str)
	return func and func()
end

local function IsFuncStringValid(_, funcString)
	local _, err = loadstring('return ' .. funcString)
	return err or true
end

function CBF:CacheBagItems(bagID)
	for slotID = 1, 36 do
		local cache, _ = {}

		cache.itemLocation = { bagID = bagID, slotIndex = slotID }
		_, cache.itemCount, _, cache.quality,  cache.readable, cache.lootable, cache.itemLink, _, cache.noValue, cache.itemID, cache.isBound = GetContainerItemInfo(bagID, slotID)

		if cache.itemLink then
			cache.battlepet = strmatch(cache.itemLink, "battlepet") and true
			cache.itemString = strmatch(cache.itemLink, cache.battlepet and "battlepet[%-?%d:]+" or "item[%-?%d:]+")
			cache.itemName, _, _, cache.baseItemLevel, cache.itemMinLevel, cache.itemType, cache.itemSubType, _, cache.itemEquipLoc, _, cache.sellPrice, cache.classID, cache.subclassID, cache.bindType, cache.expacID, cache.setID, cache.isCraftingReagent = GetItemInfo(cache.battlepet and cache.itemID or cache.itemLink)

			if GetDetailedItemLevelInfo then
				cache.unscaledItemLevel = GetDetailedItemLevelInfo(cache.itemLink)
			end

			if _G.C_Item then
				cache.itemLevel = C_Item_DoesItemExist(cache.itemLocation) and C_Item_GetCurrentItemLevel(cache.itemLocation)
			end

			CBF.ItemCache[cache.itemString] = cache
			CBF.BagCache[bagID][slotID] = cache
		end
	end
end

function CBF:SetFilter(filter, isBank)
	CBF.ActiveFilter = self.filter or filter

	local f = B:GetContainerFrame(self.isBank or isBank)
	local hideOverlay = true

	for _, bagID in next, f.BagIDs do
		for slotID = 1, f.Bags[bagID].numSlots do
			if CBF.ActiveFilter then
				hideOverlay = CBF.FilterFunctions[CBF.ActiveFilter](CBF.BagCache[bagID] and CBF.BagCache[bagID][slotID] or emptyTable)
			end

			f.Bags[bagID][slotID].searchOverlay:SetShown(not hideOverlay)
		end
	end
end

function CBF:ResetFilter()
	local f = B:GetContainerFrame(self.isBank)
	if f.FilterHolder.active ~= nil then
		CBF:SetFilter(nil, true)
	end
end

function CBF:Tooltip_Show()
	GameTooltip:SetOwner(self)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(self.ttText)

	if self.ttText2 then
		if self.ttText2desc then
			GameTooltip:AddLine(' ')
			GameTooltip:AddDoubleLine(self.ttText2, self.ttText2desc, .8, .8, .8, .8, .8, .8)
		else
			GameTooltip:AddLine(self.ttText2)
		end
	end

	GameTooltip:Show()
end

function CBF:AddFilterButtons(isBank)
	local f = B:GetContainerFrame(isBank)

	local numButtons, buttonSize, buttonSpacing = 1, f.isBank and B.db.bankSize or B.db.bagSize, E.Border * 2
	local lastContainerButton
	local holder = f.FilterHolder


	for i in ipairs(holder) do
		f.FilterHolder[i]:Hide()
	end

	for name, filterInfo in next, E.global.CustomBagFilters do
		local button = f.FilterHolder[numButtons]

		if not button then
			button = CreateFrame('Button', nil, holder)
			button:RegisterForClicks('LeftButtonDown', 'RightButtonDown')
			button:Size(buttonSize)
			button:SetTemplate()
			button:StyleButton(nil, true)
			button:SetScript('OnEnter', CBF.Tooltip_Show)
			button:SetScript('OnLeave', GameTooltip_Hide)
			button:SetScript('OnClick', function(s, btn) CBF:SetFilter(btn ~= 'RightButton' and s.filter) end)
			button:SetScript('OnHide', CBF.ResetFilter)
			button:SetMotionScriptsWhileDisabled(true)
			button:SetID(numButtons)

			f.FilterHolder[numButtons] = button
		end

		button.ttText = filterInfo.name
		button.ttText2 = L["Left Click to enable."]
		button.ttText2desc = L["Right Click to disable."]
		button.isBank = f.isBank
		button.filter = name

		B:SetButtonTexture(button, filterInfo.icon)

		button:Show()
		button:ClearAllPoints()

		if numButtons == 1 then
			button:SetPoint('BOTTOMLEFT', holder, 'BOTTOMLEFT', buttonSpacing, buttonSpacing)
		else
			button:SetPoint('LEFT', lastContainerButton, 'RIGHT', buttonSpacing, 0)
		end

		numButtons = numButtons + 1
		lastContainerButton = button
	end

	holder:Size(((buttonSize + buttonSpacing) * (numButtons - 1)) + buttonSpacing, buttonSize + (buttonSpacing * 2))
	holder:SetShown((numButtons - 1) ~= 0)
end

function CBF:AddMenuButton(isBank)
	local f = B:GetContainerFrame(isBank)

	local Holder = CreateFrame('Button', nil, f)
	Holder:Point('BOTTOMLEFT', f, 'TOPLEFT', 0, 1)
	Holder:SetTemplate('Transparent')
	Holder:Hide()

	f.FilterHolder = Holder

	local button = CreateFrame('Button', nil, f.holderFrame)
	button:Size(18)
	button:Point("RIGHT", f.sortButton, "LEFT", -5, 0)
	button:SetTemplate()
	button:StyleButton(nil, true)
	B:SetButtonTexture(button, 413571)
	button.ttText = L.Filter
	button:SetScript('OnEnter', B.Tooltip_Show)
	button:SetScript('OnLeave', GameTooltip_Hide)
	button:SetScript('OnClick', function() f.ContainerHolder:Hide() ToggleFrame(Holder) end)
	f.bagsButton:HookScript('OnClick', function() Holder:Hide() end)

	f.filterButton = button

	f.bagsButton:ClearAllPoints()
	f.bagsButton:Point('RIGHT', button, 'LEFT', -5, 0)

	CBF:AddFilterButtons(isBank)
end

function CBF:RefreshButtons()
	CBF:AddFilterButtons()
	CBF:AddFilterButtons(true)
end

function CBF:CreateFilter(name, filterInfo)
	E.global.CustomBagFilters[name] = CopyTable(filterInfo)

	CBF.FilterFunctions[name] = buildFunction(filterInfo.func)

	CBF:RefreshButtons()
end

function CBF:DeleteFilter(name)
	CBF.FilterFunctions[name] = nil
	E.global.CustomBagFilters[name] = nil

	CBF:RefreshButtons()
end

function CBF:DeleteGroup(name)
	optionsPath.CustomBagFilters.args[name] = nil
end

function CBF:CreateGroup(name)
	local option = ACH:Group(E.global.CustomBagFilters[name].name, nil, nil, nil, function(info) local db = E.global.CustomBagFilters[info[#info - 1]] return tostring(db and db[info[#info]] or '') end)
	option.args = CopyTable(SharedOptions)

	option.args.name.set = function(info, value)
		if value ~= '' and value ~= info[#info - 1] then
			if not E.global.CustomBagFilters[value] then
				E:CopyTable(E.global.CustomBagFilters[value], E.global.CustomBagFilters[info[#info - 1]])

				CBF:CreateFilter(value, E.global.CustomBagFilters[value])
				CBF:DeleteFilter(info[#info - 1])

				CBF:CreateGroup(value)
				CBF:DeleteGroup(info[#info - 1])

				CBF:SelectGroup(value)
			end
		end
	end

	option.args.description.set = function(info, value) E.global.CustomBagFilters[info[#info - 1]][info[#info]] = strtrim(value) end
	option.args.icon.set = function(info, value) E.global.CustomBagFilters[info[#info - 1]][info[#info]] = strtrim(value) CBF:RefreshButtons() end
	option.args.func.set = function(info, value)
		value = strtrim(value)
		if E.global.CustomBagFilters[info[#info - 1]][info[#info]] ~= value then
			E.global.CustomBagFilters[info[#info - 1]][info[#info]] = value

			CBF:CreateFilter(name, E.global.CustomBagFilters[info[#info - 1]])
		end
	end

	option.args.delete = ACH:Execute(L['Delete'], nil, 0, function(info) CBF:DeleteFilter(info[#info - 1]) CBF:DeleteGroup(info[#info - 1]) CBF:SelectGroup() end, nil, format('Delete - %s?', name), 'full')
	option.args.export = ACH:Input(L['Export Data'], nil, -1, 8, 'full', function(info) return TT:ExportData(info[#info - 1], TT:JoinDBKey('CustomBagFilters')) end)

	optionsPath.CustomBagFilters.args[name] = option
end

function CBF:SelectGroup(name)
	if name then
		E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'TinkerToolbox', 'CustomBagFilters', name)
	else
		E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'TinkerToolbox', 'CustomBagFilters')
	end
end

function CBF:GetOptions()
	ACH = E.Libs.ACH
	optionsPath = E.Options.args.TinkerToolbox.args

	SharedOptions = {
		name = ACH:Input(L['Name'], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return DefaultFilters[value] and L['Name Taken'] or true end),
		icon = ACH:Input(L['Icon ID or File Path'], nil, 2, nil, 'full'),
		description = ACH:Input(L['Description'], nil, 3, nil, 'full'),
		func = ACH:Input(L['Function'], nil, 4, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
	}

	optionsPath.CustomBagFilters = ACH:Group(L["Custom Bag Filters"], nil, 4)

	optionsPath.CustomBagFilters.args.new = ACH:Group(L['New'], nil, 0, nil, function(info) return tostring(newInfo[info[#info]] or '') end, function(info, value) newInfo[info[#info]] = strtrim(value) end)
	optionsPath.CustomBagFilters.args.new.args = CopyTable(SharedOptions)
	optionsPath.CustomBagFilters.args.new.args.add = ACH:Execute(L['Add'], nil, 0, function() CBF:CreateFilter(newInfo.name, newInfo) CBF:CreateGroup(newInfo.name) CBF:SelectGroup(newInfo.name) end, nil, nil, 'full', nil, nil, function() return not (newInfo.name ~= '' and newInfo.func ~= '') end)

	optionsPath.CustomBagFilters.args.premade = ACH:Group(L['Add Premade Filter'], nil, 2)
	optionsPath.CustomBagFilters.args.premade.args.selectPremade = ACH:Select(L['Filter'], nil, 0, function() local tbl = {} for name, tblInfo in next, DefaultFilters do tbl[name] = tblInfo.name end return tbl end, nil, nil, function() return premade end, function(_, value) premade = value end)
	optionsPath.CustomBagFilters.args.premade.args.add = ACH:Execute(L['Add'], nil, 1, function() CBF:CreateFilter(premade, DefaultFilters[premade]) CBF:CreateGroup(premade) CBF:SelectGroup(premade) end, nil, nil, 'full')
	optionsPath.CustomBagFilters.args.premade.args.preview = ACH:Group(L['Preview'], nil, 2, nil, function(info) return premade ~= '' and tostring(DefaultFilters[premade][info[#info]] or '') end)
	optionsPath.CustomBagFilters.args.premade.args.preview.inline = true
	optionsPath.CustomBagFilters.args.premade.args.preview.args = CopyTable(SharedOptions)

	optionsPath.CustomBagFilters.args.import = ACH:Group(L['Import'], nil, 3)
	optionsPath.CustomBagFilters.args.import.args.codeInput = ACH:Input(L['Code'], nil, 1, 8, 'full', function() return EncodedInfo or '' end, function(_, value) EncodedInfo = value DecodedInfo = { TT:DecodeData(value) } end)

	optionsPath.CustomBagFilters.args.import.args.preview = ACH:Group(L['Preview'])
	optionsPath.CustomBagFilters.args.import.args.preview.inline = true
	optionsPath.CustomBagFilters.args.import.args.preview.args = CopyTable(SharedOptions)
	optionsPath.CustomBagFilters.args.import.args.preview.args.import = ACH:Execute(L['Import'], nil, 0, function() TT:DecodeData(EncodedInfo) end, nil, nil, 'full', nil, nil, function() return not EncodedInfo end)
	optionsPath.CustomBagFilters.args.import.args.preview.args.name.get = function() return DecodedInfo and DecodedInfo[1] or '' end

	optionsPath.CustomBagFilters.args.help = ACH:Group(L['Help'], nil, 4)

	optionsPath.CustomBagFilters.args.spacer = ACH:Group(' ', nil, 5, nil, nil, nil, true)

	for name in next, E.global.CustomBagFilters do
		CBF:CreateGroup(name)
	end
end

function CBF:BAG_UPDATE(_, bagID)
	CBF.RefreshBag[bagID] = true
end

function CBF:BAG_UPDATE_DELAYED()
	for bagID in next, CBF.RefreshBag do
		CBF:CacheBagItems(bagID)
		CBF.RefreshBag[bagID] = nil
	end
end

function CBF:BANKFRAME_OPENED()
	for _, bagID in next, bankIDs do
		if not CBF.BagCache[bagID] then
			CBF.BagCache[bagID] = { isBank = true }
		end

		CBF:CacheBagItems(bagID)
	end
end

function CBF:BANKFRAME_CLOSED()
	CBF.SetFilter(B.BankFrame, nil, true)
end

function CBF:Initialize()
	if not E.private.bags.enable then return end

	for _, bagID in next, bagIDs do
		CBF.BagCache[bagID] = {}
		CBF:CacheBagItems(bagID)
	end

	for _, bagID in next, bankIDs do
		CBF.BagCache[bagID] = { isBank = true }
	end

	CBF:AddMenuButton()
	CBF:AddMenuButton(true)

	for name, filterInfo in next, E.global.CustomBagFilters do
		CBF:CreateFilter(name, filterInfo)
	end

	CBF:RegisterEvent('BAG_UPDATE')
	CBF:RegisterEvent('BAG_UPDATE_DELAYED')
	CBF:RegisterEvent('BANKFRAME_OPENED')
	CBF:RegisterEvent('BANKFRAME_CLOSED')

	hooksecurefunc(B, 'UpdateSlot', function(_, frame, bagID, slotID) CBF:SetFilter(CBF.ActiveFilter) end)
end
