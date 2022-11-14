local _, Engine = ...
local E, L, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local TT = E:NewModule('TinkerToolbox', 'AceEvent-3.0', 'AceHook-3.0', 'AceTimer-3.0', 'AceSerializer-3.0')
local ACH = E.Libs.ACH

Engine[1] = TT

_G.ElvUI_TinkerToolbox = Engine

local unpack = unpack
local type = type
local next = next
local strsplit = strsplit
local strfind = strfind
local gsub = gsub
local tonumber = tonumber
local format = format
local strjoin = strjoin

local LibDeflate = E.Libs.Deflate
local ElvUIPrefix = '^!E1!'

E.Options.args.TinkerToolbox = ACH:Group(L["Tinker Toolbox"], nil, 6, 'tab')

function TT:JoinDBKey(...)
	local tbl = ...
	if type(tbl) ~= 'table' then tbl = { ... } end

	return (#tbl > 1 and strjoin('\a', unpack(tbl))) or ...
end

function TT:DecodeData(dataString)
	if not dataString then return end

	if strfind(dataString, ElvUIPrefix) then
		dataString = gsub(dataString, ElvUIPrefix, '', 1) -- break the ElvUI Prefix off
	end

	local decodedData = LibDeflate:DecodeForPrint(dataString)
	if not decodedData then return end
	local decompressed = LibDeflate:DecompressDeflate(decodedData)
	if not decompressed then return end

	local serializedData, nameKey = E:SplitString(decompressed, '^^;;') -- '^^' indicates the end of the AceSerializer string

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
		for _, v in next, { strsplit('\a', dbKey) } do
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
		for _, v in next, { strsplit('\a', dbKey) }  do
			db = db[tonumber(v) or v]
		end
	end

	local data = db and (type(db[name]) == 'table' and E:CopyTable({}, db[name]) or db[name])
	if not data then return end

	local serialData = TT:Serialize(data)
	local exportString = format(dbKey and '%s;;%s\a%s' or '%s;;%s', serialData, name, dbKey)
	local compressedData = LibDeflate:CompressDeflate(exportString, LibDeflate.compressLevel)
	local printableString = LibDeflate:EncodeForPrint(compressedData)

	return printableString
end

function TT:CallModuleFunction(module, func)
	local pass, err = pcall(func, module)
	if not pass and TT.Debug then
		print(err)
	end
end

function TT:GetOptions()
	E.Libs.AceGUI.luaSyntax = E.Libs.luaSyntax

	for _, module in TT:IterateModules() do
		if module.GetOptions then
			TT:CallModuleFunction(module, module.GetOptions)
		end
	end
end

function TT:Initialize()
	for _, module in TT:IterateModules() do
		if module.Initialize then
			TT:CallModuleFunction(module, module.Initialize)
		end
	end

	E.Libs.EP:RegisterPlugin('ElvUI_TinkerToolbox', TT.GetOptions)
end

E:RegisterModule(TT:GetName())
