local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)

local CDT = TT:NewModule('CustomDataTexts')
local D = E:GetModule('Distributor')
local DT = E:GetModule('DataTexts')

local wipe = wipe
local pcall = pcall
local tinsert = tinsert
local format = format
local loadstring = loadstring
local gmatch = gmatch
local strtrim = strtrim
local next = next
local concat = table.concat
local CopyTable = CopyTable
local tostring = tostring

local badEvents = {}

local validator = CreateFrame('Frame')

local ACH, SharedOptions = E.Libs.ACH
local optionsPath

local newInfo = { name = '', eventFunc = '', updateFunc = ''}
local EncodedInfo, DecodedInfo

G.CustomDataTexts = {}
CDT.CustomDT = {}

-- Set Distributor to Export
D.GeneratedKeys.global.CustomDataTexts = true

function CDT:SelectGroup(...)
	E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'TinkerToolbox', 'CustomDataTexts', ...)
end

local function buildFunction(str)
	local func = loadstring('return '..str)
	return func and func()
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

function CDT:ImportDT(dataString)
	local name, data = TT:ImportData(dataString)

	if name then
		E.global.CustomDataTexts[name] = E:CopyTable({}, data)
		E.global.CustomDataTexts[name].name = nil

		CDT:CreateDT(name, data)
		CDT:CreateGroup(name)

		EncodedInfo, DecodedInfo = nil, nil
	end
end

function CDT:CreateDT(name, data)
	CDT.CustomDT[name] = true

	local category = data.category
	local events = data.events
	local eventFunc = data.eventFunc and buildFunction(data.eventFunc)
	local updateFunc = data.updateFunc and buildFunction(data.updateFunc)
	local clickFunc = data.clickFunc and buildFunction(data.clickFunc)
	local onEnterFunc = data.onEnterFunc and buildFunction(data.onEnterFunc)
	local onLeaveFunc = data.onLeaveFunc and buildFunction(data.onLeaveFunc)
	local applySettings = data.applySettings and buildFunction(data.applySettings)

	DT:RegisterDatatext(name, category, events, eventFunc, updateFunc, clickFunc, onEnterFunc, onLeaveFunc, nil, nil, applySettings)
	DT:UpdateHyperDT()
end

function CDT:DeleteDT(name)
	DT.RegisteredDataTexts[name] = nil
	DT.DataTextList[name] = nil
	CDT.CustomDT[name] = nil
	E.global.CustomDataTexts[name] = nil

	DT:LoadDataTexts() -- This will clear it
end

function CDT:DeleteGroup(name)
	optionsPath.CustomDataTexts.args[name] = nil
end

function CDT:CreateGroup(name)
	local option = ACH:Group(name, nil, nil, nil, function(info) local db = E.global.CustomDataTexts[info[#info - 1]] return tostring(db and db[info[#info]] or '') end)
	option.args = CopyTable(SharedOptions)

	option.args.name.get = function(info) return info[#info - 1] end
	option.args.name.set = function(info, value)
		if value ~= '' and value ~= info[#info - 1] then
			if not E.global.CustomDataTexts[value] then
				E:CopyTable(E.global.CustomDataTexts[value], E.global.CustomDataTexts[info[#info - 1]])

				CDT:CreateDT(value, E.global.CustomDataTexts[value])
				CDT:DeleteDT(info[#info - 1])

				CDT:CreateGroup(value)
				CDT:DeleteGroup(info[#info - 1])

				CDT:SelectGroup('dtGroup', value)

				DT:LoadDataTexts()
			end
		end
	end

	option.args.category.set = function(info, value) E.global.CustomDataTexts[info[#info - 1]][info[#info]] = strtrim(value) end
	option.args.description.set = function(info, value) E.global.CustomDataTexts[info[#info - 1]][info[#info]] = strtrim(value) end
	option.args.events.set = function(info, value)
		value = strtrim(value)
		if E.global.CustomDataTexts[info[#info - 1]][info[#info]] ~= value then
			E.global.CustomDataTexts[info[#info - 1]][info[#info]] = value ~= '' and value or nil

			CDT:CreateDT(name, E.global.CustomDataTexts[info[#info - 1]])
			DT:LoadDataTexts()
		end
	end

	for opt, optTable in next, SharedOptions do
		if not optTable.set then
			option.args[opt].set = function(info, value)
				value = strtrim(value)
				if E.global.CustomDataTexts[info[#info - 1]][info[#info]] ~= value then
					E.global.CustomDataTexts[info[#info - 1]][info[#info]] = value

					CDT:CreateDT(name, E.global.CustomDataTexts[info[#info - 1]])
					DT:LoadDataTexts()
				end
			end
		end
	end

	option.args.delete = ACH:Execute(L['Delete'], nil, 0, function(info) E.global.CustomDataTexts[info[#info - 1]] = nil CDT:DeleteGroup(info[#info - 1]) CDT:SelectGroup('dtGroup') end, nil, format('Delete - %s?', name), 'full')
	option.args.export = ACH:Input(L['Export Data'], nil, -1, 8, 'full', function(info) return TT:ExportData(info[#info - 1], TT:JoinDBKey('CustomDataTexts')) end)

	optionsPath.CustomDataTexts.args[name] = option
end

function CDT:GetOptions()
	optionsPath = E.Options.args.TinkerToolbox.args

	SharedOptions = {
		name = ACH:Input(L['Name'], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return not CDT.CustomDT[value] and DT.RegisteredDataTexts[value] and L['Name Taken'] or true end),
		category = ACH:Input(L['Category'], nil, 2, nil, 'full'),
		description = ACH:Input(L['Description'], nil, 3, nil, 'full'),
		events = ACH:Input(L['Events'], nil, 4, nil, 'full', nil, nil, nil, nil, IsEventStringValid),
		eventFunc = ACH:Input(L['OnEvent Script'], nil, 5, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
		updateFunc = ACH:Input(L['OnUpdate Script'], nil, 6, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
		onClick = ACH:Input(L['OnClick Script'], nil, 7, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
		onEnter = ACH:Input(L['OnEnter Script'], nil, 8, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
		onLeave = ACH:Input(L['OnLeave Script'], nil, 9, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
		applySettings = ACH:Input(L['Apply Settings Function'], nil, 10, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
	}

	for _, optTable in next, SharedOptions do
		if optTable.validate then
			optTable.validatePopup = true
		end
	end

	SharedOptions.eventFunc.luaSyntax = true
	SharedOptions.updateFunc.luaSyntax = true
	SharedOptions.onClick.luaSyntax = true
	SharedOptions.onEnter.luaSyntax = true
	SharedOptions.onLeave.luaSyntax = true
	SharedOptions.applySettings.luaSyntax = true

	optionsPath.CustomDataTexts = ACH:Group(L["Custom DataTexts"], nil, 3)

	optionsPath.CustomDataTexts.args.new = ACH:Group(L['New'], nil, 0, nil, function(info) return tostring(newInfo[info[#info]] or '') end, function(info, value) newInfo[info[#info]] = strtrim(value) end)
	optionsPath.CustomDataTexts.args.new.args = CopyTable(SharedOptions)
	optionsPath.CustomDataTexts.args.new.args.add = ACH:Execute(L['Add'], nil, 0, function() E.global.CustomDataTexts[newInfo.name] = CopyTable(newInfo) E.global.CustomDataTexts[newInfo.name].name = nil CDT:CreateDT(newInfo.name, newInfo) CDT:CreateGroup(newInfo.name, newInfo) CDT:SelectGroup('dtGroup', newInfo.name) end, nil, nil, 'full', nil, nil, function() return not (newInfo.name ~= '' and (newInfo.eventFunc ~= '' or newInfo.updateFunc ~= '')) end)

	optionsPath.CustomDataTexts.args.import = ACH:Group(L['Import'], nil, 3)
	optionsPath.CustomDataTexts.args.import.args.codeInput = ACH:Input(L['Code'], nil, 1, 8, 'full', function() return EncodedInfo or '' end, function(_, value) EncodedInfo = value DecodedInfo = { TT:DecodeData(value) } end)
	optionsPath.CustomDataTexts.args.import.args.codeImport = ACH:Execute(L['Import'], nil, 2, function() CDT:ImportDT(EncodedInfo) end, nil, nil, 'full', nil, nil, function() return not EncodedInfo end)

	optionsPath.CustomDataTexts.args.import.args.preview = ACH:Group(L['Preview'])
	optionsPath.CustomDataTexts.args.import.args.preview.inline = true
	optionsPath.CustomDataTexts.args.import.args.preview.args = CopyTable(SharedOptions)
	optionsPath.CustomDataTexts.args.import.args.preview.args.name.get = function() return DecodedInfo and DecodedInfo[1] or '' end

	optionsPath.CustomDataTexts.args.spacer = ACH:Group(' ', nil, 4, nil, nil, nil, true)

	for option in next, SharedOptions do
		if option ~= 'name' then
			optionsPath.CustomDataTexts.args.import.args.preview.args[option].get = function(info) return DecodedInfo and DecodedInfo[2][info[#info]] or '' end
		end
	end

	for name in next, E.global.CustomDataTexts do
		CDT:CreateGroup(name)
	end
end

function CDT:Initialize()
	for name, data in next, E.global.CustomDataTexts do
		CDT:CreateDT(name, data)
	end
end
