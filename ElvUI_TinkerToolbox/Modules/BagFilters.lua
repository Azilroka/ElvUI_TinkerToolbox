local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)

local CBF = TT:NewModule('CustomBagFilters', 'AceEvent-3.0')
local B = E.Bags

local ACH
local optionsPath

local next = next
local ipairs = ipairs
local strmatch = strmatch

local GetContainerItemInfo = GetContainerItemInfo
local GetItemInfo = GetItemInfo

local C_Item_DoesItemExist = C_Item and C_Item.DoesItemExist
local C_Item_GetCurrentItemLevel = C_Item and C_Item.GetCurrentItemLevel
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo

local CreateFrame = CreateFrame
local ToggleFrame = ToggleFrame
local GameTooltip_Hide = GameTooltip_Hide

local bagIDs = { 0, 1, 2, 3, 4 }
local bankIDs = { -1, 5, 6, 7, 8, 9, 10 }

if not E.Retail then
	tinsert(bagIDs, KEYRING_CONTAINER)
end

if not E.Classic then
	tinsert(bankIDs, 11)
end

local DefaultFilters = {
	Equipment = { name = L["BAG_FILTER_EQUIPMENT"], icon = 132626, func = function(cache) return cache.classID == LE_ITEM_CLASS_ARMOR or cache.classID == LE_ITEM_CLASS_WEAPON end },
	Consumable = { name = L["BAG_FILTER_CONSUMABLES"], icon = 134873, func = function(cache) return cache.classID == LE_ITEM_CLASS_CONSUMABLE end },
	QuestItems = { name = L["ITEM_BIND_QUEST"], icon = 136797, func = function(cache) return cache.classID == LE_ITEM_CLASS_QUESTITEM end },
	TradeGoods = { name = L["BAG_FILTER_TRADE_GOODS"], icon = 132906, func = function(cache) return cache.classID == LE_ITEM_CLASS_TRADEGOODS or cache.classID == LE_ITEM_CLASS_RECIPE or cache.classID == LE_ITEM_CLASS_GEM or cache.classID == LE_ITEM_CLASS_ITEM_ENHANCEMENT or cache.classID == LE_ITEM_CLASS_GLYPH end },
	BattlePets = { name = L["Battle Pets"], icon = 643856, func = function(cache) return cache.classID == LE_ITEM_CLASS_BATTLEPET or (cache.classID == LE_ITEM_CLASS_MISCELLANEOUS and cache.subclassID == 2) end },
	Miscellaneous = { name = L["Miscellaneous"], icon = 134414, func = function(cache) return cache.classID == LE_ITEM_CLASS_MISCELLANEOUS or cache.classID == LE_ITEM_CLASS_CONTAINER end },
	NewItems = { name = L["New Items"], icon = 255351, func = function(cache) return C_NewItems.IsNewItem(cache.itemLocation.bagID, cache.itemLocation.slotIndex) end }
}

G.CustomBagFilters = {}

CBF.ItemCache = {}
CBF.BagCache = {}
CBF.RefreshBag = {}

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
		end

		CBF.BagCache[bagID][slotID] = cache
	end
end

function CBF:SetSlotFilter(frame, bagID, slotID)
	local f = B:GetContainerFrame(frame.isBank)
	if not (f.Bags[bagID] and f.Bags[bagID][slotID]) then return end

	local hideOverlay = true

	if f.FilterHolder.active then
		hideOverlay = f.FilterHolder[f.FilterHolder.active].filter(CBF.BagCache[bagID][slotID])
	end

	f.Bags[bagID][slotID].searchOverlay:SetShown(not hideOverlay)
end

function CBF:SetFilter()
	local f = B:GetContainerFrame(self.isBank)

	for i, button in ipairs(f.FilterHolder) do
		if f.FilterHolder.active then
			button:SetEnabled(true)
		else
			button:SetEnabled(i == self:GetID())
		end
	end

	f.FilterHolder.active = not f.FilterHolder.active and self:GetID()

	for _, bagID in next, f.BagIDs do
		if f.Bags[bagID] then
			for slotID = 1, f.Bags[bagID].numSlots do
				CBF:SetSlotFilter(f, bagID, slotID)
			end
		end
	end
end

function CBF:ResetFilter()
	local f = B:GetContainerFrame(self.isBank)
	if f.FilterHolder.active then
		CBF:SetFilter()
	end
end

function CBF:AddFilterButtons(f, isBank)
	local numButtons, buttonSize, buttonSpacing = 1, isBank and B.db.bankSize or B.db.bagSize, E.Border * 2
	local lastContainerButton
	local holder = f.FilterHolder

	for _, filterInfo in next, DefaultFilters do
		local button = f.FilterHolder[numButtons]

		if not button then
			button = CreateFrame('Button', nil, holder)
			button:Size(buttonSize)
			button:SetTemplate()
			button:StyleButton(nil, true)
			button:SetScript('OnEnter', B.Tooltip_Show)
			button:SetScript('OnLeave', GameTooltip_Hide)
			button:SetScript('OnClick', CBF.SetFilter)
			button:SetScript('OnHide', CBF.ResetFilter)
			button:SetMotionScriptsWhileDisabled(true)
			button:SetID(numButtons)

			f.FilterHolder[numButtons] = button
		end

		button.ttText = filterInfo.name
		button.filter = filterInfo.func
		button.isBank = isBank

		B:SetButtonTexture(button, filterInfo.icon)

		button:ClearAllPoints()

		if numButtons == 1 then
			button:SetPoint('BOTTOMLEFT', holder, 'BOTTOMLEFT', buttonSpacing, buttonSpacing)
		else
			button:SetPoint('LEFT', lastContainerButton, 'RIGHT', buttonSpacing, 0)
		end

		numButtons = numButtons + 1
		lastContainerButton = button
	end

	holder:Size(((buttonSize + buttonSpacing) * (numButtons - 1)) + buttonSpacing, buttonSize + (buttonSpacing * 2));
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

	CBF:AddFilterButtons(f, isBank)
end

function CBF:GetOptions()
	ACH = E.Libs.ACH
	optionsPath = E.Options.args.TinkerToolbox.args

	optionsPath.CustomBagFilters = ACH:Group(L["Custom Bag Filters"], nil, 4, 'tab')
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
	for bagID in next, bankIDs do
		CBF.BagCache[bagID] = { isBank = true }
		CBF:CacheBagItems(bagID)
	end
end

function CBF:Initialize()
	if not E.private.bags.enable then return end

	for _, bagID in next, bagIDs do
		CBF.BagCache[bagID] = {}
		CBF:CacheBagItems(bagID)
	end

	B:RegisterEvent('BANKFRAME_OPENED')

	CBF:AddMenuButton()
	CBF:AddMenuButton(true)

	CBF:RegisterEvent('BAG_UPDATE')
	CBF:RegisterEvent('BAG_UPDATE_DELAYED')

	hooksecurefunc(B, 'UpdateSlot', function(_, frame, bagID, slotID) CBF:SetSlotFilter(frame, bagID, slotID) end)
end
