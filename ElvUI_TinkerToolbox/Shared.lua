local _, Engine = ...
local E, L, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local TT = _G.LibStub('AceAddon-3.0'):NewAddon('TinkerToolbox', 'AceEvent-3.0', 'AceHook-3.0', 'AceTimer-3.0', 'AceSerializer-3.0')

Engine[1] = TT

_G.ElvUI_TinkerToolbox = Engine

local unpack = unpack
local type = type
local next = next
local strsplit = strsplit
local strsplittable = strsplittable
local tonumber = tonumber
local format = format
local strjoin = strjoin

local LibCompress = E.Libs.Compress
local LibBase64 = E.Libs.Base64

function TT:JoinDBKey(...)
	local tbl = ...
	if type(tbl) ~= 'table' then tbl = { ... } end

	return (#tbl > 1 and strjoin('\a', unpack(tbl))) or ...
end

function TT:DecodeData(dataString)
	if not dataString then return end

	local decodedData = LibBase64:Decode(dataString)
	local decompressedData = LibCompress:Decompress(decodedData)
	if not decompressedData then return end

	local serializedData, nameKey = E:SplitString(decompressedData, '^^;;') -- '^^' indicates the end of the AceSerializer string
	serializedData = format('%s%s', serializedData, '^^') --Add back the AceSerializer terminator

	local success, data = TT:Deserialize(serializedData)
	if not success then return end

	local name, dbKey = strsplit('\a', nameKey, 2)
	return name, data, dbKey
end

function TT:ImportData(dataString)
	local name, data, dbKey = TT:DecodeData(dataString)
	if not data then return end

	local db = E.global

	if dbKey then
		for _, v in next, strsplittable('\a', dbKey) do
			db = db[tonumber(v) or v]
			if not db then db = {} end
		end
	end

	db[name] = type(data) == 'table' and E:CopyTable(db[name], data) or data

	return name, data, dbKey
end

function TT:ExportData(name, dbKey)
	if not name or type(name) ~= 'string' then
		return
	end

	local db = E.global

	if dbKey then
		for _, v in next, strsplittable('\a', dbKey) do
			db = db[tonumber(v) or v]
		end
	end

	local data = db and (type(db[name]) == 'table' and E:CopyTable({}, db[name]) or db[name])
	if not data then return end

	local serialData = TT:Serialize(data)
	local exportString = format(dbKey and '%s;;%s\a%s' or '%s;;%s', serialData, name, dbKey)
	local compressedData = LibCompress:Compress(exportString)
	local encodedData = LibBase64:Encode(compressedData)

	return encodedData
end

function TT:CallModuleFunction(module, func)
	local pass, err = pcall(func, module)
	if not pass and TT.Debug then
		print(err)
	end
end

function TT:GetOptions()
	local ACH = E.Libs.ACH

	E.Options.args.TinkerToolbox = ACH:Group(L["Tinker Toolbox"], nil, 6, 'tab')

	for _, module in TT:IterateModules() do
		if module.GetOptions then
			TT:CallModuleFunction(module, module.GetOptions)
		end
	end
end

function TT:PLAYER_LOGIN()
	for _, module in TT:IterateModules() do
		if module.Initialize then
			TT:CallModuleFunction(module, module.Initialize)
		end
	end

	E.Libs.EP:RegisterPlugin('TinkerToolbox', TT.GetOptions)
end

TT:RegisterEvent('PLAYER_LOGIN')
