local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)
local CPD = TT:NewModule('CustomProfileDistributor')
local D = E:GetModule('Distributor')

local ACH, optionsPath = E.Libs.ACH
local gsub, strupper, wipe = gsub, strupper, wipe

CPD.config = {
	profileType = 'profile',
	exportType = 'compare',
	exportFormat = 'luaPlugin',
	exportName = '',
	profileFrom = '',
	compareProfile = '',
	exportedData = '',
	custom = {},
	importCustom = {},
}

local pluginNames, hasPlugins = {}
local OriginalOptions = {}

local LibDeflate = E.Libs.Deflate
local ElvUIPrefix = '!E1!'

function CPD:GetLocaleName(str)
	if not next(pluginNames) then
		for name, optTable in next, E.Options.args do
			if not OriginalOptions[name] and type(optTable) == 'table' then
				pluginNames[name] = optTable.name
			end
		end
	end

	for name, locale in next, pluginNames do
		if str == name then
			return locale
		end
	end
end

function CPD.GetCustomExport(info)
	local option = info[#info]
	local tbl = {}

	for name, value in next, (CPD.config.profileType == 'profile' and P or CPD.config.profileType == 'private' and V or G) do
		local locale = OriginalOptions[name]
		if type(value) == 'table' and (option == 'customExport' and locale or option == 'customExportPlugin' and not locale) then
			tbl[name] = locale or CPD:GetLocaleName(name) or gsub(name, "^%l", strupper)
		end
	end

	return tbl
end

local customImportOptions, importNeedsRefresh = {}
function CPD.GetCustomImport()
	if importNeedsRefresh then
		wipe(customImportOptions)
		local _, _, profileData = D:Decode(CPD.config.importedData)

		for name, value in next, (profileData or {}) do
			if type(value) == 'table'  then
				customImportOptions[name] = OriginalOptions[name] or CPD:GetLocaleName(name) or gsub(name, "^%l", strupper)
			end
		end
		importNeedsRefresh = nil
	end

	return customImportOptions
end

function CPD:ImportTableCount(profileData, bypass)
	local count = 0
	for _, value in next, profileData do
		if bypass or type(value) == 'table' then
			count = count + 1
		end
	end

	return count
end

function CPD:ImportProfile(dataString)
	local profileType, _, profileData = D:Decode(dataString)

	if not profileData or type(profileData) ~= 'table' then
		return
	end

	local allCount, customCount = CPD:ImportTableCount(profileData), CPD:ImportTableCount(CPD.config.importCustom, true)

	if allCount ~= customCount and profileType then
		profileData = E:FilterTableFromBlacklist(profileData, D.blacklistedKeys[profileType])

		local defaults = profileType == 'profile' and P or profileType == 'private' and V or G
		local db = profileType == 'profile' and 'db' or (profileType == 'filters' or profileType == 'styleFilters') and 'global' or profileType

		for dataType, value in next, profileData do -- Clear unwanted data
			if type(value) == 'table' then
				if not CPD.config.importCustom[dataType] then
					profileData[dataType] = nil
				end
			end
		end

		for dataType, value in next, profileData do -- Set wanted data
			if type(value) == 'table' then
				local cleanTable = E:CopyTable({}, defaults[dataType]) -- Clean Table to not merge data into defaults.

				E[db][dataType] = E:CopyTable(cleanTable, profileData[dataType])
			end
		end

		if profileType == 'private' or profileType == 'global' then
			E:StaticPopup_Show('IMPORT_RL')
		else
			E:StaggeredUpdateAll()
		end
	else -- No or All Data Rerouted to ElvUI. Means they don't read.
		D:ImportProfile(dataString)
	end
end

function CPD:GetProfileData(profileType)
	if not profileType or type(profileType) ~= 'string' then
		return
	end

	local compare = CPD.config.exportType == 'compare' and (profileType == 'profile' and _G.ElvDB.profiles[CPD.config.compareProfile] or profileType == 'private' and _G.ElvPrivateDB.profiles[CPD.config.compareProfile])
	local db = profileType == 'profile' and _G.ElvDB.profiles[CPD.config.profileFrom] or profileType == 'global' and _G.ElvDB.global or _G.ElvPrivateDB.profiles[CPD.config.profileFrom]

	local defaults = profileType == 'profile' and P or profileType == 'private' and V or G
	local profileData = {}

	if CPD.config.exportType == 'compare' then
		profileData = E:CopyTable(profileData, db)
	else
		for dataType in next, CPD.config.custom do
			profileData[dataType] = E:CopyTable({}, db[dataType])
		end
	end

	profileData = E:RemoveTableDuplicates(profileData, defaults, D.GeneratedKeys[profileType])

	if CPD.config.exportType == 'compare' then
		profileData = E:RemoveTableDuplicates(profileData, compare, D.GeneratedKeys[profileType])
	end

	profileData = E:FilterTableFromBlacklist(profileData, D.blacklistedKeys[profileType])

	return profileData
end

function CPD:GetProfileExport(profileType)
	local profileData = CPD:GetProfileData(profileType)

	if not profileData or (profileData and type(profileData) ~= 'table') then
		return
	end

	local profileExport

	if CPD.config.exportFormat == 'text' then
		local serialData = D:Serialize(profileData)
		local exportString = D:CreateProfileExport(serialData, profileType, CPD.config.exportName ~= '' and CPD.config.exportName or CPD.config.profileFrom)
		local compressedData = LibDeflate:CompressDeflate(exportString, LibDeflate.compressLevel)
		local printableString = LibDeflate:EncodeForPrint(compressedData)
		profileExport = ElvUIPrefix..printableString
	else
		profileExport = E:ProfileTableToPluginFormat(profileData, profileType)
	end

	return profileExport
end

function CPD:GetOptions()
	optionsPath = E.Options.args.TinkerToolbox.args

	for _, name in next, E.OriginalOptions do
		OriginalOptions[name] = E.Options.args[name].name
	end

	for name, optTable in next, P do
		if type(optTable) == 'table' and not OriginalOptions[name] then
			hasPlugins = true
			break
		end
	end

	optionsPath.customprofiledistributor = ACH:Group(L["Custom Profile Tools"], nil, 5, 'tab')
	optionsPath.customprofiledistributor.args.cleanDB = ACH:Execute('Clean Profile')

	optionsPath.customprofiledistributor.args.exportTools = ACH:Group(L["Export Tools"], nil, 0)

	optionsPath.customprofiledistributor.args.exportTools.args.settings = ACH:Group(' ', nil, 0, nil, function(info) return CPD.config[info[#info]] end, function(info, value) CPD.config[info[#info]] = value CPD.config.exportedData = '' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.inline = true
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.profileType = ACH:Select(L["Profile Type"], nil, 0, { profile = L["Profile"], private = L["Private"], global = L["Global"] }, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.profileFrom = '' CPD.config.compareProfile = '' CPD.config.exportedData = '' CPD.config.exportType = value == 'global' and 'custom' or 'compare' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.exportFormat = ACH:Select(L["Export Format"], nil, 1, { luaPlugin = L["Plugin"], text = L["Text"] })
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.exportType = ACH:Select(L["Export Type"], nil, 2, { compare = L["Compare"], custom = L["Custom"] }, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.profileFrom = '' CPD.config.compareProfile = '' CPD.config.exportedData = '' end, nil, function() return CPD.config.profileType == 'global' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.compareProfile = ACH:Select(L["Profile to Compare To"], nil, 3, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end tbl[CPD.config.profileFrom] = nil return tbl end, nil, nil, nil, nil, function() return CPD.config.profileFrom == '' end, function() return CPD.config.profileType == 'global' or CPD.config.exportType ~= 'compare' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.profileFrom = ACH:Select(L["Profile to Export From"], nil, 4, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end return tbl end, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.compareProfile = '' CPD.config.exportedData = '' end, nil, function() return CPD.config.profileType == 'global' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.exportName = ACH:Input(L["Export Name"], nil, 5, nil, nil, nil, nil, nil, function() return CPD.config.exportFormat == 'luaPlugin' end)

	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.customExport = ACH:MultiSelect('', nil, -3, CPD.GetCustomExport, nil, nil, function(_, key) return CPD.config.custom[key] end, function(_, key, value) CPD.config.custom[key] = value or nil CPD.config.exportedData = '' end, nil, function() return CPD.config.exportType ~= 'custom' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.customExportPlugin = ACH:MultiSelect('', nil, -2, CPD.GetCustomExport, nil, nil, function(_, key) return CPD.config.custom[key] end, function(_, key, value) CPD.config.custom[key] = value or nil CPD.config.exportedData = '' end, nil, function() return (CPD.config.exportType == 'compare' or not hasPlugins) end)

	optionsPath.customprofiledistributor.args.exportTools.args.export = ACH:Group(' ', nil, -1)
	optionsPath.customprofiledistributor.args.exportTools.args.export.inline = true
	optionsPath.customprofiledistributor.args.exportTools.args.export.args.exec = ACH:Execute(L["Export"], nil, 1, function() CPD.config.exportedData = CPD:GetProfileExport(CPD.config.profileType) end, nil, nil, 'full', nil, nil, function() return CPD.config.profileType ~= 'global' and (CPD.config.profileFrom == '' or CPD.config.exportType == 'compare' and CPD.config.compareProfile == '') end)
	optionsPath.customprofiledistributor.args.exportTools.args.export.args.exportedData = ACH:Input('', nil, 2, 20, 'full', function() return CPD.config.exportedData end, nil, nil, function() return CPD.config.exportedData == '' end)

	optionsPath.customprofiledistributor.args.importTools = ACH:Group(L["Import Tools"], nil, 1)
	optionsPath.customprofiledistributor.args.importTools.args.importedData = ACH:Input('', nil, 1, 20, 'full', function() return CPD.config.importedData end, function(_, value) importNeedsRefresh = true CPD.config.importedData = value CPD.config.importName = select(2, D:Decode(value)) end)
	optionsPath.customprofiledistributor.args.importTools.args.importedDesc = ACH:Description(function() return CPD.config.importName or '' end, 2, 'medium', nil, nil, nil, nil, nil, function() return not CPD.config.importedData end)
	optionsPath.customprofiledistributor.args.importTools.args.customImport = ACH:MultiSelect('', nil, 4, CPD.GetCustomImport, nil, nil, function(_, key) return CPD.config.importCustom[key] end, function(_, key, value) CPD.config.importCustom[key] = value or nil end, nil, function() return not CPD.config.importedData end)

	optionsPath.customprofiledistributor.args.importTools.args.importExec = ACH:Execute(L["Import"], nil, 5, function() CPD:ImportProfile(CPD.config.importedData) end, nil, nil, 'full', nil, nil, function() return not CPD.config.importedData end)
end
