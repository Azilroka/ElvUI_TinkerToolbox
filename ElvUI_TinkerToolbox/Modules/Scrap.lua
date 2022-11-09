if not IsAddOnLoaded("Scrap") then return end
local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)
local TTS = TT:NewModule('TinkerToolboxScrap')
local B = E.Bags
local ACH = E.Libs.ACH

G["TinkerToolboxScrap"] = {}
G["TinkerToolboxScrap"]["Enable"] = true

local C_TransmogCollection_PlayerHasTransmogByItemInfo = C_TransmogCollection
    and C_TransmogCollection.PlayerHasTransmogByItemInfo
local IsCosmeticItem = IsCosmeticItem

--Update Icon on bag slot
function TTS.UpdateSlot(_, self, bagID, slotID)
    if not E.global.TinkerToolboxScrap.Enable then return end
    if
        (self.Bags[bagID] and self.Bags[bagID].numSlots ~= GetContainerNumSlots(bagID))
        or not self.Bags[bagID]
        or not self.Bags[bagID][slotID]
    then
        return
    end

    local slot = self.Bags[bagID][slotID]
    local link = GetContainerItemLink(bagID, slotID)
    local id
    if link then id = tonumber(strmatch(link, "item:(%d+)")) end

    if slot.JunkIcon then
        if id and Scrap:IsJunk(id, bagID, slotID) then
            slot.JunkIcon:SetShown(Scrap_Sets.icons)
        else
            slot.JunkIcon:Hide()
        end
    end
end
hooksecurefunc(B, "UpdateSlot", TTS.UpdateSlot)

do
    local origGetGrays = B.GetGrays

    function B:GetGrays(vendor)
        if not E.global.TinkerToolboxScrap.Enable then return origGetGrays(B, vendor) end
        local value = 0

        for bagID = 0, 4 do
            for slotID = 1, B:GetContainerNumSlots(bagID) do
                local info = B:GetContainerItemInfo(bagID, slotID)
                local itemLink = info and info.hyperlink
                if itemLink and not info.hasNoValue and not B.ExcludeGrays[info.itemID] then
                    local _, _, rarity, _, _, _, _, _, _, _, itemPrice, classID, _, bindType = GetItemInfo(itemLink)

                    if
                        Scrap:IsJunk(info.itemID, bagID, slotID) -- grays :o
                        and (classID ~= 12 or bindType ~= 4) -- Quest can be classID:12 or bindType:4
                        and (
                            not E.Retail
                            or not IsCosmeticItem(itemLink)
                            or C_TransmogCollection_PlayerHasTransmogByItemInfo(itemLink)
                        )
                    then -- skip transmogable items
                        local stackCount = info.stackCount or 1
                        local stackPrice = itemPrice * stackCount

                        if vendor then
                            tinsert(B.SellFrame.Info.itemList, { bagID, slotID, itemLink, stackCount, stackPrice })
                        elseif stackPrice > 0 then
                            value = value + stackPrice
                        end
                    end
                end
            end
        end

        return value
    end
end

-- Function we can call to update all bag slots
function TTS.UpdateBags() B:UpdateAllBagSlots() end

-- Set Hooks
function TTS.SetHooks()
    hooksecurefunc(Scrap, "ToggleJunk", UpdateBags)

    TTS.UpdateBags()

    Scrap.HasSpotlight = true
end

function TTS:Initialize()
    self.SetHooks()
end

function TTS:GetOptions()
    local optionsPath = E.Options.args.TinkerToolbox.args
    optionsPath.TinkerToolboxScrap = ACH:Group("Scrap Integration", nil, 5, nil, function(info) return E.global.TinkerToolboxScrap[info[#info]] end, function(info, value) E.global.TinkerToolboxScrap[info[#info]] = value end)
    optionsPath.TinkerToolboxScrap.args.Enable = ACH:Toggle(L["Enable"], nil, 6)
end
