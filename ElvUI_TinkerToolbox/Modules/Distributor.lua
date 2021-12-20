local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)
local CPD = TT:NewModule('CustomProfileDistributor')
local D = E:GetModule('Distributor')
local LibCompress = E.Libs.Compress
local LibBase64 = E.Libs.Base64

local ACH, optionsPath
local gsub, strupper = gsub, strupper

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

	for name, value in next, (CPD.config.profileType == 'profile' and P or V) do
		local locale = OriginalOptions[name]
		if type(value) == 'table' and (option == 'customExport' and locale or option == 'customExportPlugin' and not locale) then
			tbl[name] = locale or CPD:GetLocaleName(name) or gsub(name, "^%l", strupper)
		end
	end

	return tbl
end

function CPD.GetCustomImport()
	local _, _, profileData = D:Decode(CPD.config.importedData)
	local tbl = {}

	for name, value in next, (profileData or {}) do
		if type(value) == 'table'  then
			tbl[name] = OriginalOptions[name] or CPD:GetLocaleName(name) or gsub(name, "^%l", strupper)
		end
	end

	return tbl
end

function CPD:ImportProfile(dataString)
	local profileType, profileKey, profileData = D:Decode(dataString)

	if not profileData or type(profileData) ~= 'table' then
		return
	end

	local hasData = next(CPD.config.importCustom)

	if hasData then
		if profileType and ((profileType == 'profile' and profileKey) or profileType ~= 'profile') then
			profileData = E:FilterTableFromBlacklist(profileData, D.blacklistedKeys[profileType])

			local defaults = profileType == 'profile' and P or profileType == 'private' and V or G
			local db = profileType == 'profile' and 'db' or profileType

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
		end
	else -- All Data Reroute to ElvUI.
		D:ImportProfile(dataString)
	end
end

function CPD:GetProfileData(profileType)
	if not profileType or type(profileType) ~= 'string' then
		return
	end

	local db = profileType == 'profile' and 'ElvDB' or 'ElvPrivateDB'
	local defaults = profileType == 'profile' and P or V
	local profileData = {}

	if CPD.config.exportType == 'compare' then
		profileData = E:CopyTable(profileData, _G[db].profiles[CPD.config.profileFrom])
	else
		for dataType in next, CPD.config.custom do
			profileData[dataType] = E:CopyTable({}, _G[db].profiles[CPD.config.profileFrom][dataType])
		end
	end

	profileData = E:RemoveTableDuplicates(profileData, defaults, D.GeneratedKeys[profileType])

	if CPD.config.exportType == 'compare' then
		profileData = E:RemoveTableDuplicates(profileData, _G[db].profiles[CPD.config.compareProfile], D.GeneratedKeys[profileType])
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
		local compressedData = LibCompress:Compress(exportString)
		local encodedData = LibBase64:Encode(compressedData)
		profileExport = encodedData
	else
		profileExport = E:ProfileTableToPluginFormat(profileData, profileType)
	end

	return profileExport
end

function CPD:GetOptions()
	ACH = E.Libs.ACH
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

	optionsPath.customprofiledistributor.args.exportTools = ACH:Group(L["Export Tools"], nil, 0)

	optionsPath.customprofiledistributor.args.exportTools.args.settings = ACH:Group(' ', nil, 0, nil, function(info) return CPD.config[info[#info]] end, function(info, value) CPD.config[info[#info]] = value CPD.config.exportedData = '' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.inline = true
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.profileType = ACH:Select(L["Profile Type"], nil, 0, { profile = L["Profile"], private = L["Private"] }, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.profileFrom = '' CPD.config.compareProfile = '' CPD.config.exportedData = '' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.exportType = ACH:Select(L["Export Type"], nil, 1, { compare = L["Compare"], custom = L["Custom"] }, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.profileFrom = '' CPD.config.compareProfile = '' CPD.config.exportedData = '' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.exportFormat = ACH:Select(L["Export Format"], nil, 2, { luaPlugin = L["Plugin"], text = L["Text"] })
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.profileFrom = ACH:Select(L["Profile to Export From"], nil, 3, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end return tbl end, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.compareProfile = '' CPD.config.exportedData = '' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.compareProfile = ACH:Select(L["Profile to Compare"], nil, 4, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end tbl[CPD.config.profileFrom] = nil return tbl end, nil, nil, nil, nil, function() return CPD.config.profileFrom == '' end, function() return CPD.config.exportType ~= 'compare' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.exportName = ACH:Input(L["Export Name"], nil, 5, nil, nil, nil, nil, nil, function() return CPD.config.exportFormat == 'luaPlugin' end)

	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.customExport = ACH:MultiSelect('', nil, -3, CPD.GetCustomExport, nil, nil, function(_, key) return CPD.config.custom[key] end, function(_, key, value) CPD.config.custom[key] = value or nil CPD.config.exportedData = '' end, nil, function() return CPD.config.exportType ~= 'custom' end)
	optionsPath.customprofiledistributor.args.exportTools.args.settings.args.customExportPlugin = ACH:MultiSelect('', nil, -2, CPD.GetCustomExport, nil, nil, function(_, key) return CPD.config.custom[key] end, function(_, key, value) CPD.config.custom[key] = value or nil CPD.config.exportedData = '' end, nil, function() return (CPD.config.exportType == 'compare' or not hasPlugins) end)

	optionsPath.customprofiledistributor.args.exportTools.args.export = ACH:Group(' ', nil, -1)
	optionsPath.customprofiledistributor.args.exportTools.args.export.inline = true
	optionsPath.customprofiledistributor.args.exportTools.args.export.args.exec = ACH:Execute(L["Export"], nil, 1, function() CPD.config.exportedData = CPD:GetProfileExport(CPD.config.profileType) end, nil, nil, 'full', nil, nil, function() return (CPD.config.profileType == '' or CPD.config.profileFrom == '' or CPD.config.exportType == 'compare' and CPD.config.compareProfile == '') end)
	optionsPath.customprofiledistributor.args.exportTools.args.export.args.exportedData = ACH:Input('', nil, 2, 40, 'full', function() return CPD.config.exportedData end, nil, nil, function() return CPD.config.exportedData == '' end)

	optionsPath.customprofiledistributor.args.importTools = ACH:Group(L["Import Tools"], nil, 1)
	optionsPath.customprofiledistributor.args.importTools.args.importedData = ACH:Input('', nil, 1, 40, 'full', function() return CPD.config.importedData end, function(_, value) CPD.config.importedData = value end)
	optionsPath.customprofiledistributor.args.importTools.args.importedDesc = ACH:Description(function() if CPD.config.importedData then local _, name = D:Decode(CPD.config.importedData) return name end end, 2, 'medium', nil, nil, nil, nil, nil, function() return not CPD.config.importedData end)
	optionsPath.customprofiledistributor.args.importTools.args.customImport = ACH:MultiSelect('', nil, 4, CPD.GetCustomImport, nil, nil, function(_, key) return CPD.config.importCustom[key] end, function(_, key, value) CPD.config.importCustom[key] = value or nil end, nil, function() return not CPD.config.importedData end)

	optionsPath.customprofiledistributor.args.importTools.args.importExec = ACH:Execute(L["Import"], nil, 5, function() CPD:ImportProfile(CPD.config.importedData) end, nil, nil, 'full', nil, nil, function() return not CPD.config.importedData end)
end
