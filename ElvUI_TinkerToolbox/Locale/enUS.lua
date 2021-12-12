local L = ElvUI[1].Libs.ACL:NewLocale("ElvUI", "enUS", true, true)

L['Variables'] = true
L['Tags'] = true

L['New Tag'] = true
L['Copy Tag'] = true
L['From Tag'] = true
L['To Tag'] = true

L['Name Taken'] = true
L['Name Not Found'] = true

L['New Variable'] = true

L['Name'] = true
L['Value'] = true
L['Add'] = true
L['Delete'] = true
L['Copy'] = true
L['Events'] = true
L['Defaults'] = true

L["BAG_FILTER_CONSUMABLES"] = "Consumables"
L["BAG_FILTER_EQUIPMENT"] = "Equipment"
L["BAG_FILTER_TRADE_GOODS"] = "Trade Goods"
L["ITEM_BIND_QUEST"] = "Quest Item"
L["Miscellaneous"] = true
L["Battle Pets"] = true
L["New Items"] = true

-- Cache for Bag Filters
L["cache.itemCount"] = "The number of items in the specified bag slot"
L["cache.quality"] = "The Quality of the item."
L["cache.readable"] = "True if the item can be 'read' (as in a book), false otherwise."
L["cache.lootable"] = "True if the item is a temporary container containing items that can be looted, false otherwise."
L["cache.itemLink"] = "The itemLink of the item in the specified bag slot."
L["cache.noValue"] = "True if the item has no gold value, false otherwise."
L["cache.itemID"] = "The unique ID for the item in the specified bag slot."
L["cache.isBound"] = "True if the item is bound to the current character, false otherwise."
L["cache.itemName"] = "The localized name of the item."
L["cache.baseItemLevel"] = "The base item level, not including upgrades."
L["cache.itemLevel"] = "The item level including upgrades (scaled)"
L["cache.unscaledItemLevel"] = "The item level including upgrades (not scaled)"
L["cache.itemMinLevel"] = "The minimum level required to use the item, or 0 if there is no level requirement."
L["cache.itemType"] = "The localized type name of the item: Armor, Weapon, Quest, etc."
L["cache.itemSubType"] = "The localized sub-type name of the item: Bows, Guns, Staves, etc."
L["cache.itemEquipLoc"] = "The inventory equipment location in which the item may be equipped e.g. 'INVTYPE_HEAD', or an empty string if it cannot be equipped."
L["cache.sellPrice"] = "The vendor price in copper, or 0 for items that cannot be sold."
L["cache.classID"] = "The numeric ID of itemType"
L["cache.subclassID"] = "The numeric ID of itemSubType"
L["cache.bindType"] = "When the item becomes soulbound, e.g. 1 for Bind on Pickup items."
L["cache.expacID"] = "The related Expansion, e.g. 8 for Shadowlands."
L["cache.setID"] = "For example 761 for  [Red Winter Hat]."
L["cache.isCraftingReagent"] = "Whether the item can be used as a crafting reagent."
