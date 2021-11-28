local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)

local CBF = TT:NewModule('CustomBagFilters')
local B = E.Bags

local ACH
local optionsPath

local next = next
local ipairs = ipairs

local GetContainerItemInfo = GetContainerItemInfo
local GetItemInfo = GetItemInfo
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo

local CreateFrame = CreateFrame
local ToggleFrame = ToggleFrame
local GameTooltip_Hide = GameTooltip_Hide

local DefaultFilters = {
	All = { name = L["ALL"], icon = 133875, func = function(location, link, type, subType) return true end },
	Equipment = { name = L["BAG_FILTER_EQUIPMENT"], icon = 132626, func = function(location, link, type, subType) return type == LE_ITEM_CLASS_ARMOR or type == LE_ITEM_CLASS_WEAPON end },
	Consumable = { name = L["BAG_FILTER_CONSUMABLES"], icon = 134873, func = function(location, link, type, subType) return type == LE_ITEM_CLASS_CONSUMABLE end },
	QuestItems = { name = L["ITEM_BIND_QUEST"], icon = 136797, func = function(location, link, type, subType) return type == LE_ITEM_CLASS_QUESTITEM end },
	TradeGoods = { name = L["BAG_FILTER_TRADE_GOODS"], icon = 132906, func = function(location, link, type, subType) return type == LE_ITEM_CLASS_TRADEGOODS or type == LE_ITEM_CLASS_RECIPE or type == LE_ITEM_CLASS_GEM or type == LE_ITEM_CLASS_ITEM_ENHANCEMENT or type == LE_ITEM_CLASS_GLYPH end },
	BattlePets = { name = L["Battle Pets"], icon = 643856, func = function(location, link, type, subType) return type == LE_ITEM_CLASS_BATTLEPET or (type == LE_ITEM_CLASS_MISCELLANEOUS and subType == 2) end },
	Miscellaneous = { name = L["Miscellaneous"], icon = 134414, func = function(location, link, type, subType) return type == LE_ITEM_CLASS_MISCELLANEOUS or type == LE_ITEM_CLASS_CONTAINER end },
	NewItems = { name = L["New Items"], icon = 255351, func = function(location, link, type, subType) return C_NewItems.IsNewItem(location.bagID, location.slotIndex) end }
}

function CBF:SetSlotFilter(f, bagID, slotID)
	local hideOverlay = true

	if f.FilterHolder.active then
		local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID, isBound = GetContainerItemInfo(bagID, slotID)
		local itemName, itemLevel, itemMinLevel, itemType, itemSubType, itemEquipLoc, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent, _

		if itemLink then
			itemName, _, _, itemLevel, itemMinLevel, itemType, itemSubType, _, itemEquipLoc, _, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(itemLink)
		end

		local location = { bagID = bagID, slotIndex = slotID }

		if itemLink then
			hideOverlay = f.FilterHolder[f.FilterHolder.active].filter(location, itemLink, classID, subclassID)
		end
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

	optionsPath.custombagfilters = ACH:Group(L["Custom Bag Filters"], nil, 4, 'tab')
end

function CBF:Initialize()
	if not E.private.bags.enable then return end

	CBF:AddMenuButton()
	CBF:AddMenuButton(true)

	hooksecurefunc(B, 'UpdateSlot', function(_, frame, bagID, slotID) CBF:SetSlotFilter(frame, bagID, slotID) end)
end
