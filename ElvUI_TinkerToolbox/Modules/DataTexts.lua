local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)

local CDT = TT:NewModule('CustomDataTexts')

local oUF = E.oUF
local LibCompress = E.Libs.Compress
local LibBase64 = E.Libs.Base64

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
local newInfo = { category = '', description = '', name = '', events = '', vars = '', func = '' }
local copyInfo = { fromTag = '', toTag = ''}

local validator = CreateFrame('Frame')

local ACH, SharedOptions, EncodedInfo, DecodedInfo
local optionsPath

G.CustomDataTexts = {}

local D = E:GetModule('Distributor')
local DT = E:GetModule('DataTexts')

-- Set Distributor to Export
D.GeneratedKeys.global.CustomDataTexts = true

-- Set function Locals
local CreateDT, DeleteDT
local Decode, Export, Import, CreateGroup, DeleteGroup

function Decode(dataString)
	if not dataString then
		return
	end

	local name, data

	local decodedData = LibBase64:Decode(dataString)
	local decompressedData, decompressedMessage = LibCompress:Decompress(decodedData)

	if not decompressedData then
		E:Print('Error decompressing data:', decompressedMessage)
		return
	end

	local serializedData, success
	serializedData, name = E:SplitString(decompressedData, '^^::') -- '^^' indicates the end of the AceSerializer string
	serializedData = format('%s%s', serializedData, '^^') --Add back the AceSerializer terminator
	success, data = D:Deserialize(serializedData)

	if not success then
		E:Print('Error deserializing:', data)
		return
	end

	return name, data
end

function Export(name)
	if not name or type(name) ~= 'string' then
		return
	end

	local data = E:CopyTable({}, E.global.CustomDataTexts[name])

	if not data or (data and type(data) ~= 'table') then
		return
	end

	local serialData = D:Serialize(data)
	local exportString = format('%s::%s', serialData, name)
	local compressedData = LibCompress:Compress(exportString)
	local encodedData = LibBase64:Encode(compressedData)

	return encodedData
end

function Import(dataString)
	local name, data = Decode(dataString)

	if not data or type(data) ~= 'table' then
		return
	end

	E.global.CustomDataTexts[name] = E:CopyTable({}, data)

	CreateDT(name, data)
	CreateGroup(name, data)
	E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customdatatexts', 'dtGroup', name)

	EncodedInfo, DecodedInfo = nil, nil
end

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

function CreateDT(name, data)
end

function DeleteDT(name)
	DT.RegisteredDataTexts[name] = nil
end

function DeleteGroup(name)
	optionsPath.customdatatexts.args.dtGroup.args[name] = nil
end

function CreateGroup(tag)
	local option = ACH:Group(tag, nil, nil, nil, function(info) local db = E.global.CustomTags[info[#info - 1]] or G.CustomTags[info[#info - 1]] return tostring(db and db[info[#info]] or '') end)
	option.args = CopyTable(SharedOptions)

	option.args.name.disabled = isDefaultTag
	option.args.name.get = function(info) return info[#info - 1] end
	option.args.name.set = function(info, value)
		if value ~= '' and value ~= info[#info - 1] then
			if not E.global.CustomTags[value] then
				E.global.CustomTags[value] = CopyTable(E.global.CustomTags[info[#info - 1]])

				oUF_CreateTag(value, E.global.CustomTags[value])
				CreateGroup(value, E.global.CustomTags[value])

				E.global.CustomTags[info[#info - 1]] = nil
				oUF_DeleteTag(info[#info - 1])
				DeleteGroup(info[#info - 1])

				E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', value)
			end
		end
	end

	option.args.category.set = function(info, value) E.global.CustomTags[info[#info - 1]][info[#info]] = strtrim(value) end
	option.args.description.set = function(info, value) E.global.CustomTags[info[#info - 1]][info[#info]] = strtrim(value) end
	option.args.events.set = function(info, value)
		value = strtrim(value)
		if E.global.CustomTags[info[#info - 1]][info[#info]] ~= value then
			if value ~= '' then
				E.global.CustomTags[info[#info - 1]][info[#info]] = value
				oUF.Tags.Events[info[#info - 1]] = value
			else
				E.global.CustomTags[info[#info - 1]][info[#info]] = nil
				oUF.Tags.Events[info[#info - 1]] = nil
			end

			oUF.Tags:RefreshEvents(info[#info - 1])
		end
	end

	option.args.func.set = function(info, value)
		value = strtrim(value)
		if E.global.CustomTags[info[#info - 1]][info[#info]] ~= value then
			E.global.CustomTags[info[#info - 1]][info[#info]] = value

			rawset(oUF.Tags.Methods, info[#info - 1], nil)
			oUF.Tags.Methods[info[#info - 1]] = value

			oUF.Tags:RefreshMethods(info[#info - 1])
		end
	end

	option.args.delete = ACH:Execute(L['Delete'], nil, 7, function(info) E.global.CustomTags[info[#info - 1]] = nil DeleteDT(info[#info - 1]) DeleteGroup(info[#info - 1]) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup') end, nil, format('Delete - %s?', tag), 'full', nil, nil, nil, isDefault)
	option.args.reset = ACH:Execute(L['Defaults'], nil, 8, function(info) E.global.CustomTags[info[#info - 1]] = CopyTable(G.CustomTags[info[#info - 1]]) DeleteDT(info[#info - 1]) CreateDT(E.global.CustomTags[info[#info - 1]]) end, nil, format('Reset to Default - %s?', tag), 'full', nil, nil, nil, function(info) return (not isDefault(info)) or (isDefault(info) and AreTableEquals(E.global.CustomTags[info[#info - 1]], G.CustomTags[info[#info - 1]])) end)

	option.args.export = ACH:Input(L['Export Data'], nil, 9, 8, 'full', function(info) return Export(info[#info - 1]) end)

	optionsPath.customdatatexts.args.tagGroup.args[tag] = option
end

function CDT:GetOptions()
	ACH = E.Libs.ACH
	optionsPath = E.Options.args.TinkerToolbox.args

	SharedOptions = {
		name = ACH:Input(L['Name'], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return oUF.Tags.Methods[value] and L['Name Taken'] or true end),
		category = ACH:Input(L['Category'], nil, 2, nil, 'full'),
		events = ACH:Input(L['Events'], nil, 4, nil, 'full', nil, nil, nil, nil, IsEventStringValid),
		func = ACH:Input(L['Function'], nil, 6, 10, 'full', nil, nil, nil, nil, IsFuncStringValid)
	}

	SharedOptions.name.validatePopup = true
	SharedOptions.events.validatePopup = true
	SharedOptions.func.validatePopup = true
	SharedOptions.func.luaHighlighting = true

	optionsPath.customdatatexts = ACH:Group(L["Custom DataTexts"], nil, 3, 'tab')
	optionsPath.customdatatexts.args.dtGroup = ACH:Group(L['DataTexts'], nil, 1)
	optionsPath.customdatatexts.args.dtGroup.args.new = ACH:Group(L['New'], nil, 0, nil, function(info) return tostring(newInfo[info[#info]] or '') end, function(info, value) newInfo[info[#info]] = strtrim(value) end)

	optionsPath.customdatatexts.args.dtGroup.args.new.args = CopyTable(SharedOptions)
	optionsPath.customdatatexts.args.dtGroup.args.new.args.add = ACH:Execute(L['Add'], nil, 0, function() E.global.CustomTags[newInfo.name] = CopyTable(newInfo) E.global.CustomTags[newInfo.name].name = nil CreateDT(newInfo.name, newInfo) CreateGroup(newInfo.name, newInfo) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customdatatexts', 'dtGroup', newInfo.name) newInfo.name, newInfo.events, newInfo.vars, newInfo.func, newInfo.category, newInfo.description = '', '', '', '', '', '' end, nil, nil, 'full', nil, nil, function() return not (newInfo.name ~= '' and newInfo.func ~= '') end)

	optionsPath.customdatatexts.args.dtGroup.args.copy = ACH:Group(L['Copy'], nil, 1, nil, function(info) return tostring(copyInfo[info[#info]]) end, function(info, value) copyInfo[info[#info]] = strtrim(value) end)
	optionsPath.customdatatexts.args.dtGroup.args.copy.args.from = ACH:Input(L['From'], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return (value ~= '' and not oUF.Tags.Methods[value] and L['Name Not Found']) or true end)
	optionsPath.customdatatexts.args.dtGroup.args.copy.args.from.validatePopup = true

	optionsPath.customdatatexts.args.dtGroup.args.copy.args.to = ACH:Input(L['To'], nil, 2, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return (value ~= '' and not oUF.Tags.Methods[value] and L['Name Taken']) or true end)
	optionsPath.customdatatexts.args.dtGroup.args.copy.args.to.validatePopup = true

	optionsPath.customdatatexts.args.dtGroup.args.copy.args.add = ACH:Execute(L['Copy'], nil, 5, function() E.global.CustomTags[copyInfo.toTag] = CopyTable(E.global.CustomTags[copyInfo.fromTag]) CreateDT(copyInfo.toTag, E.global.CustomTags[copyInfo.toTag]) CreateGroup(copyInfo.toTag, E.global.CustomTags[copyInfo.toTag]) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customdatatexts', 'dtGroup', copyInfo.to) copyInfo.from, copyInfo.to = '', '' end, nil, nil, 'full', nil, nil, function() return not (copyInfo.from ~= '' and copyInfo.to ~= '') end)

	optionsPath.customdatatexts.args.dtGroup.args.import = ACH:Group(L['Import'], nil, 3)
	optionsPath.customdatatexts.args.dtGroup.args.import.args.codeInput = ACH:Input(L['Code'], nil, 1, 8, 'full', function() return EncodedInfo or '' end, function(_, value) EncodedInfo = value DecodedInfo = { Decode(value) } end)

	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview = ACH:Group(L['Preview'])
	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview.inline = true
	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview.args = CopyTable(SharedOptions)
	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview.args.string = ACH:Execute(L['Import'], nil, 0, function() Import(EncodedInfo) end, nil, nil, 'full', nil, nil, function() return not EncodedInfo end)
	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview.args.name.get = function() return DecodedInfo and DecodedInfo[1] or '' end
	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview.args.category.get = function() return DecodedInfo and DecodedInfo[2].category or '' end
	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview.args.events.get = function() return DecodedInfo and DecodedInfo[2].events or '' end
	optionsPath.customdatatexts.args.dtGroup.args.import.args.preview.args.func.get = function() return DecodedInfo and DecodedInfo[2].func or '' end

	-- Default Custom Tags
	for dt in next, G.CustomDataTexts do
		CreateGroup(dt)
	end

	-- Saved Custom Tags
	for dt in next, E.global.CustomDataTexts do
		CreateGroup(dt)
	end
end

function CDT:Initialize()
	-- Build Default Custom Tags
	for dtName, dtData in next, G.CustomDataTexts do
		pcall(CreateDT, dtName, dtData)
	end

	-- Build Saved Tags
	for dtName, dtData in next, E.global.CustomDataTexts do
		pcall(CreateDT, dtName, dtData)
	end
end
