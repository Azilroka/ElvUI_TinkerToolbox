local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

local CPD = TT:NewModule('CustomProfileDistributor')

local D = E:GetModule('Distributor')

local ACH, optionsPath

CPD.config = {
	profileType = 'profile',
	profileFrom = '',
	compareProfile = '',
	exportedData = ''
}

function CPD:GetProfileData(profileType)
	if not profileType or type(profileType) ~= 'string' then
		E:Print('Bad argument #1 to "GetProfileData" (string expected)')
		return
	end

	local profileData = {}
	if profileType == 'profile' then
		--Copy current profile data
		profileData = E:CopyTable(profileData, ElvDB.profiles[CPD.config.profileFrom])
		--This table will also hold all default values, not just the changed settings.
		--This makes the table huge, and will cause the WoW client to lock up for several seconds.
		--We compare against the default table and remove all duplicates from our table. The table is now much smaller.
		profileData = E:RemoveTableDuplicates(profileData, P, D.GeneratedKeys.profile)
		profileData = E:RemoveTableDuplicates(profileData, ElvDB.profiles[CPD.config.compareProfile], D.GeneratedKeys.profile)
		profileData = E:FilterTableFromBlacklist(profileData, D.blacklistedKeys.profile)
	elseif profileType == 'private' then
		profileData = E:CopyTable(profileData, ElvPrivateDB.profiles[CPD.config.profileFrom])
		profileData = E:RemoveTableDuplicates(profileData, V, D.GeneratedKeys.private)
		profileData = E:RemoveTableDuplicates(profileData, ElvPrivateDB.profiles[CPD.config.compareProfile], D.GeneratedKeys.private)
		profileData = E:FilterTableFromBlacklist(profileData, D.blacklistedKeys.private)
	end

	return profileData
end

function CPD:GetProfileExport(profileType)
	local profileData = CPD:GetProfileData(profileType)

	if not profileData or (profileData and type(profileData) ~= 'table') then
		return
	end

	local profileExport = E:ProfileTableToPluginFormat(profileData, profileType)

	return profileExport
end

function CPD:GetOptions()
	ACH = E.Libs.ACH
	optionsPath = E.Options.args.TinkerToolbox.args

	optionsPath.customprofiledistributor = ACH:Group(L["Custom Profile Exporter"], nil, 5, 'tab')

	optionsPath.customprofiledistributor.args.settings = ACH:Group(' ', nil, 0, nil, function(info) return CPD.config[info[#info]] end, function(info, value) CPD.config[info[#info]] = value end)
	optionsPath.customprofiledistributor.args.settings.inline = true
	optionsPath.customprofiledistributor.args.settings.args.profileType = ACH:Select(L["Profile Type"], nil, 0, { profile = L["Profile"], private = L["Private"] }, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.profileFrom = '' CPD.config.compareProfile = '' end)
	optionsPath.customprofiledistributor.args.settings.args.profileFrom = ACH:Select(L["Profile to Export From"], nil, 1, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end return tbl end, nil, nil, nil, function(info, value) CPD.config[info[#info]] = value CPD.config.compareProfile = '' end)
	optionsPath.customprofiledistributor.args.settings.args.compareProfile = ACH:Select(L["Profile to Compare"], nil, 2, function() local tbl = {} for _, name in pairs(E[CPD.config.profileType == 'profile' and 'data' or 'charSettings']:GetProfiles()) do tbl[name] = name end tbl[CPD.config.profileFrom] = nil return tbl end, nil, nil, nil, nil, function() return CPD.config.profileFrom == '' end)

	optionsPath.customprofiledistributor.args.export = ACH:Group(' ', nil, 1)
	optionsPath.customprofiledistributor.args.export.inline = true
	optionsPath.customprofiledistributor.args.export.args.exec = ACH:Execute(L["Export"], nil, 1, function() CPD.config.exportedData = CPD:GetProfileExport(CPD.config.profileType) end, nil, nil, 'full', nil, nil, function() return (CPD.config.profileType == '' or CPD.config.profileFrom == '' or CPD.config.compareProfile == '') end)
	optionsPath.customprofiledistributor.args.export.args.exportedData = ACH:Input('', nil, 2, 40, 'full', function() return CPD.config.exportedData end, nil, nil, function() return CPD.config.exportedData == '' end)
end
