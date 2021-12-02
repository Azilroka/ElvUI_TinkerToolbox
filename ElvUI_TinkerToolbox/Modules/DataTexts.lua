local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)

local CDT = TT:NewModule('CustomDataTexts')

local wipe = wipe
local pcall = pcall
local tinsert = tinsert
local format = format
local loadstring = loadstring
local gmatch = gmatch
local strtrim = strtrim
local rawset = rawset
local next = next
local concat = table.concat
local CopyTable = CopyTable
local tostring = tostring

local badEvents = {}

local validator = CreateFrame('Frame')

local ACH, SharedOptions
local optionsPath

G.CustomDataTexts = {}

local function AreTableEquals(currentTable, defaultTable)
	for option, value in pairs(defaultTable) do
		if type(value) == 'table' then
			value = AreTableEquals(currentTable[option], value)
		end

		if currentTable[option] ~= value then
			return false
		end
	end

	return true
end

local function isDefault(info)
	return G.CustomTags[info[#info - 1]]
end

local function IsEventStringValid(_, eventString)
	wipe(badEvents)

	for event in gmatch(eventString, '%S+') do
		if not pcall(validator.RegisterEvent, validator, event) then
			tinsert(badEvents, '|cffffffff' .. event .. '|r')
		end
	end

	return #badEvents > 0 and 'Bad Events: '..concat(badEvents, ', ') or true
end

local function IsFuncStringValid(_, funcString)
	local _, err = loadstring('return ' .. funcString)
	return err or true
end

function CDT:GetOptions()
	ACH = E.Libs.ACH
	optionsPath = E.Options.args.TinkerToolbox.args

	optionsPath.customdatatexts = ACH:Group(L["Custom DataTexts"], nil, 3, 'tab')
end

function CDT:Initialize()
end
