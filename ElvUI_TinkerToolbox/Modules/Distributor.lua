local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI)
local CPD = TT:NewModule('CustomProfileDistributor')
local D = E:GetModule('Distributor')
local LibCompress = E.Libs.Compress
local LibBase64 = E.Libs.Base64

local ACH, optionsPath

CPD.config = {
	profileType = 'profile',
	exportType = 'compare',
	exportFormat = 'luaPlugin',
	exportName = '',
	profileFrom = '',
	compareProfile = '',
	exportedData = '',
	custom = {},
}

function CPD:GetCustomExport()
	local tbl = {}

	for name in next, (CPD.config.profileType == 'profile' and P or V) do
		tbl[name] = name:gsub("^%l", strupper)
	end

	return tbl
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
		local exportString = D:CreateProfileExport(serialData, profileType, CPD.config.exportName)
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

	optionsPath.customprofiledistributor = ACH:Group(L["Custom Profile Exporter"], nil, 5, 'tab')

	optionsPath.customprofiledistributor.args.settings = ACH:Group(' ', nil, 0, nil, function(info) return CPD.config[info[#info]] end, function(info, value) CPD.config[info[#info]] = value end)
	optionsPath.customprofiledistributor.args.settings.inline = true
	optionsPath.customprofiledistributor.args.settings.args.profileType = ACH:Select(L["Profile Type"], nil, 0, { profile = L["Profile"], private = L["Private"] }, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.profileFrom = '' CPD.config.compareProfile = '' end)
	optionsPath.customprofiledistributor.args.settings.args.exportType = ACH:Select(L["Export Type"], nil, 1, { compare = L["Compare"], custom = L["Custom"] }, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.profileFrom = '' CPD.config.compareProfile = '' end)
	optionsPath.customprofiledistributor.args.settings.args.exportFormat = ACH:Select(L["Export Format"], nil, 2, { luaPlugin = L["Plugin"], text = L["Text"] })
	optionsPath.customprofiledistributor.args.settings.args.profileFrom = ACH:Select(L["Profile to Export From"], nil, 3, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end return tbl end, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.compareProfile = '' end)
	optionsPath.customprofiledistributor.args.settings.args.compareProfile = ACH:Select(L["Profile to Compare"], nil, 4, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end tbl[CPD.config.profileFrom] = nil return tbl end, nil, nil, nil, nil, function() return CPD.config.profileFrom == '' end, function() return CPD.config.exportType ~= 'compare' end)
	optionsPath.customprofiledistributor.args.settings.args.exportName = ACH:Input(L["Export Name"], nil, 5)

	optionsPath.customprofiledistributor.args.settings.args.customExport = ACH:MultiSelect('', nil, -2, CPD.GetCustomExport, nil, nil, function(_, key) return CPD.config.custom[key] end, function(_, key, value) CPD.config.custom[key] = value end, nil, function() return CPD.config.exportType ~= 'custom' end)

	optionsPath.customprofiledistributor.args.export = ACH:Group(' ', nil, -1)
	optionsPath.customprofiledistributor.args.export.inline = true
	optionsPath.customprofiledistributor.args.export.args.exec = ACH:Execute(L["Export"], nil, 1, function() CPD.config.exportedData = CPD:GetProfileExport(CPD.config.profileType) end, nil, nil, 'full', nil, nil, function() return (CPD.config.profileType == '' or CPD.config.profileFrom == '' or CPD.config.exportType == 'compare' and CPD.config.compareProfile == '') end)
	optionsPath.customprofiledistributor.args.export.args.exportedData = ACH:Input('', nil, 2, 40, 'full', function() return CPD.config.exportedData end, nil, nil, function() return CPD.config.exportedData == '' end)
end
