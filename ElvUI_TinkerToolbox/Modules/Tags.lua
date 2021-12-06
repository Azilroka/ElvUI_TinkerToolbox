local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local oUF = E.oUF

local CT = TT:NewModule('CustomTags')
local D = E:GetModule('Distributor')

local wipe = wipe
local pcall = pcall
local tinsert = tinsert
local format = format
local tonumber = tonumber
local loadstring = loadstring
local gmatch = gmatch
local strtrim = strtrim
local rawset = rawset
local next = next
local concat = table.concat
local CopyTable = CopyTable
local tostring = tostring
local strlower = strlower

local badEvents = {}
local newTagInfo = { category = '', description = '', name = '', events = '', vars = '', func = '' }
local newVarInfo = { name = '', value = '' }
local copyTagInfo = { fromTag = '', toTag = ''}

local formattedText = { CURRENT = 'current', CURRENT_PERCENT = 'current-percent', PERCENT = 'percent' }
local validator = CreateFrame('Frame')

local ACH, SharedTagOptions, SharedVarOptions, EncodedTagInfo, DecodedTagInfo
local optionsPath

-- oUF Defines
E.oUF.Tags.Vars.E = E
E.oUF.Tags.Vars.L = L
E.oUF.Tags.Vars.TF = E.TagFunctions

G.CustomTags = {
	["classcolor:player"] = {
		func = "function() return Hex(_COLORS.class[select(2, UnitClass('player')]) end"
	},
	["deficit:name:colors"] = {
		func = "function(unit)\n    local missinghp = _TAGS['missinghp'](unit)\n    local String\n\n    if missinghp then\n        local healthcolor = _TAGS['healthcolor'](unit)\n        String = format(\"%s-%s|r\", healthcolor, missinghp)\n    else\n        local name = _TAGS['name'](unit)\n        local namecolor = _TAGS['namecolor'](unit)\n        String = format(\"%s%s|r\", namecolor, name)\n    end\n\n    return String\nend",
		events = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_NAME_UPDATE",
	},
	["name:custom:length"] = {
		events = "UNIT_NAME_UPDATE",
		func = "function(unit)\n    local name = UnitName(unit)\n    return name and _VARS.E:ShortenString(name,_VARS['name:custom:length'])\nend",
		vars = 5,
	},
	["name:custom:abbreviate"] = {
		events = "UNIT_NAME_UPDATE",
		func = "function(unit)\n    local name = UnitName(unit)\n\n    if name and string.len(name) > _VARS['name:custom:abbreviate'] then\n        name = gsub(name, '(%S+) ', function(t) return string.utf8sub(t,1,1)..'. ' end)\n    end\n\n    return name\nend",
		vars = 16,
	},
	["num:targeting"] = {
		events = "UNIT_TARGET PLAYER_TARGET_CHANGED GROUP_ROSTER_UPDATE",
		func = "function(unit)\n    if not IsInGroup() then return nil end\n    local targetedByNum = 0\n\n    for i = 1, GetNumGroupMembers() do\n        local groupUnit = (IsInRaid() and 'raid'..i or 'party'..i);\n        if (UnitIsUnit(groupUnit..'target', unit) and not UnitIsUnit(groupUnit, 'player')) then\n            targetedByNum = targetedByNum + 1\n        end\n    end\n\n    if UnitIsUnit(\"playertarget\", unit) then\n        targetedByNum = targetedByNum + 1\n    end\n\n    return (targetedByNum > 0 and targetedByNum or nil)\nend",
	},
	["name:lower"] = {
		events = "UNIT_NAME_UPDATE",
		func = "function(unit)\n    local name = UnitName(unit)\n    return name ~= nil and strlower(name) or ''\nend",
	},
	["name:caps"] = {
		events = "UNIT_NAME_UPDATE",
		func = "function(unit)\n    local name = UnitName(unit)\n    return name ~= nil and strupper(name) or ''\nend",
	},
}

-- Class Colors
for CLASS in next, _G.RAID_CLASS_COLORS do
	G.CustomTags[format("classcolor:%s", strlower(CLASS))] = { func = format("function() return Hex(_COLORS.class['%s']) end", CLASS) }
end

for textFormatStyle, textFormat in next, formattedText do
	G.CustomTags[format("health:%s:hidefull", textFormat)] = {
		events = "UNIT_HEALTH UNIT_MAXHEALTH",
		func = format("function(unit)\n    local min, max = UnitHealth(unit), UnitHealthMax(unit)\n    local deficit = max - min\n    local String\n\n    if not (deficit <= 0) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true)\n    end\n\n    return String\nend", textFormatStyle)
	}
	G.CustomTags[format("health:%s:hidedead", textFormat)] = {
		events = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION",
		func = format("function(unit)\n    local min, max = UnitHealth(unit), UnitHealthMax(unit)\n    local String\n\n    if not ((min == 0) or (UnitIsGhost(unit))) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true)\n    end\n\n    return String\nend", textFormatStyle)
	}
	G.CustomTags[format("health:%s:hidefull:hidedead", textFormat)] = {
		events = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION",
		func = format("function(unit)\n    local min, max = UnitHealth(unit), UnitHealthMax(unit)\n    local deficit = max - min\n    local String\n\n    if not ((deficit <= 0) or (min == 0) or (UnitIsGhost(unit))) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
	G.CustomTags[format("power:%s:hidefull:hidezero", textFormat)] = {
		events = "UNIT_DISPLAYPOWER UNIT_POWER_FREQUENT UNIT_MAXPOWER",
		func = format("function(unit)\n    local pType = UnitPowerType(unit)\n    local min, max = UnitPower(unit, pType), UnitPowerMax(unit, pType)\n    local deficit = max - min\n    local String\n\n    if not (deficit <= 0 or min <= 0) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
	G.CustomTags[format("power:%s:hidedead", textFormat)] = {
		events = "UNIT_DISPLAYPOWER UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_HEALTH",
		func = format("function(unit)\n    local pType = UnitPowerType(unit)\n    local min, max = UnitPower(unit, pType), UnitPowerMax(unit, pType)\n    local String\n\n    if not ((min == 0) or (UnitIsGhost(unit) or UnitIsDead(unit))) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
	G.CustomTags[format("power:%s:hidefull", textFormat)] = {
		events = "UNIT_DISPLAYPOWER UNIT_POWER_FREQUENT UNIT_MAXPOWER",
		func = format("function(unit)\n    local pType = UnitPowerType(unit)\n    local min, max = UnitPower(unit, pType), UnitPowerMax(unit, pType)\n    local deficit = max - min\n    local String\n\n    if not (deficit <= 0) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
	G.CustomTags[format("health:%s:shortvalue:hidefull", textFormat)] = {
		events = "UNIT_HEALTH UNIT_MAXHEALTH",
		func = format("function(unit)\n    local min, max = UnitHealth(unit), UnitHealthMax(unit)\n    local deficit = max - min\n    local String\n\n    if not (deficit <= 0) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true, true)\n    end\n\n    return String\nend", textFormatStyle)
	}
	G.CustomTags[format("health:%s:shortvalue:hidedead", textFormat)] = {
		events = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION",
		func = format("function(unit)\n    local min, max = UnitHealth(unit), UnitHealthMax(unit)\n    local String\n\n    if not ((min == 0) or (UnitIsGhost(unit))) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true, true)\n    end\n\n    return String\nend", textFormatStyle)
	}
	G.CustomTags[format("health:%s:shortvalue:hidefull:hidedead", textFormat)] = {
		events = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION",
		func = format("function(unit)\n    local min, max = UnitHealth(unit), UnitHealthMax(unit)\n    local deficit = max - min\n    local String\n\n    if not ((deficit <= 0) or (min == 0) or (UnitIsGhost(unit))) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
	G.CustomTags[format("power:%s:shortvalue:hidefull:hidezero", textFormat)] = {
		events = "UNIT_DISPLAYPOWER UNIT_POWER_FREQUENT UNIT_MAXPOWER",
		func = format("function(unit)\n    local pType = UnitPowerType(unit)\n    local min, max = UnitPower(unit, pType), UnitPowerMax(unit, pType)\n    local deficit = max - min\n    local String\n\n    if not (deficit <= 0 or min <= 0) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
	G.CustomTags[format("power:%s:shortvalue:hidedead", textFormat)] = {
		events = "UNIT_DISPLAYPOWER UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_HEALTH",
		func = format("function(unit)\n    local pType = UnitPowerType(unit)\n    local min, max = UnitPower(unit, pType), UnitPowerMax(unit, pType)\n    local String\n\n    if not ((min == 0) or (UnitIsGhost(unit) or UnitIsDead(unit))) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
	G.CustomTags[format("power:%s:shortvalue:hidefull", textFormat)] = {
		events = "UNIT_DISPLAYPOWER UNIT_POWER_FREQUENT UNIT_MAXPOWER",
		func = format("function(unit)\n    local pType = UnitPowerType(unit)\n    local min, max = UnitPower(unit, pType), UnitPowerMax(unit, pType)\n    local deficit = max - min\n    local String\n\n    if not (deficit <= 0) then\n        String = _VARS.E:GetFormattedText('%s', min, max, true, true)\n    end\n\n    return String\nend", textFormatStyle),
	}
end

G.CustomVars = {}

-- Set Distributor to Export
D.GeneratedKeys.global.CustomTags = true
D.GeneratedKeys.global.CustomVars = true

function CT:ImportTag(dataString)
	local name, data = TT:ImportData(dataString)

	if name then
		CT:oUF_CreateTag(name, data)
		CT:CreateTagGroup(name, data)
		E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'TinkerToolbox','customtags', 'tagGroup', name)

		EncodedTagInfo, DecodedTagInfo = nil, nil
	end
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

local function isDefaultTag(info)
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

local function IsVarStringValid(_, varString)
	if tonumber(varString) then
		return true
	elseif type(varString) == 'function' then
		return IsFuncStringValid(_, varString)
	else
		return true
	end
end

function CT:oUF_CreateTag(tagName, tagTable)
	E:AddTagInfo(tagName, tagTable.category ~= '' and tagTable.category or 'Custom Tags', tagTable.description or '')

	if not oUF.Tags.Methods[tagName] then
		oUF.Tags.Methods[tagName] = tagTable.func
	end

	if tagTable.vars then
		oUF.Tags.Vars[tagName] = tagTable.vars
	end

	if tagTable.events then
		oUF.Tags.Events[tagName] = tagTable.events
	end

	oUF.Tags:RefreshMethods(tagName)
	oUF.Tags:RefreshEvents(tagName)
end

function CT:oUF_BuildTag(tagName, tagTable)
	E:AddTagInfo(tagName, tagTable.category ~= '' and tagTable.category or 'Custom Tags', tagTable.description or '')

	if not oUF.Tags.Methods[tagName] then
		oUF.Tags.Methods[tagName] = tagTable.func
	end

	if tagTable.vars then
		oUF.Tags.Vars[tagName] = tagTable.vars
	end

	if tagTable.events then
		oUF.Tags.Events[tagName] = tagTable.events
	end
end

function CT:oUF_DeleteTag(tag)
	rawset(oUF.Tags.Events, tag, nil)
	rawset(oUF.Tags.Vars, tag, nil)
	rawset(oUF.Tags.Methods, tag, nil)

	oUF.Tags:RefreshEvents(tag)
	oUF.Tags:RefreshMethods(tag)
end

function CT:oUF_CreateVar(var, varValue)
	oUF.Tags.Vars[var] = varValue
end

function CT:oUF_DeleteVar(var)
	rawset(oUF.Tags.Vars, var, nil)
end

function CT:DeleteTagGroup(tag)
	optionsPath.customtags.args.tagGroup.args[tag] = nil
end

function CT:CreateTagGroup(tag)
	local option = ACH:Group(tag, nil, nil, nil, function(info) local db = E.global.CustomTags[info[#info - 1]] or G.CustomTags[info[#info - 1]] return tostring(db and db[info[#info]] or '') end)
	option.args = CopyTable(SharedTagOptions)

	option.args.name.disabled = isDefaultTag
	option.args.name.get = function(info) return info[#info - 1] end
	option.args.name.set = function(info, value)
		if value ~= '' and value ~= info[#info - 1] then
			if not E.global.CustomTags[value] then
				E.global.CustomTags[value] = CopyTable(E.global.CustomTags[info[#info - 1]])

				CT:oUF_CreateTag(value, E.global.CustomTags[value])
				CT:CreateTagGroup(value, E.global.CustomTags[value])

				E.global.CustomTags[info[#info - 1]] = nil
				CT:oUF_DeleteTag(info[#info - 1])
				CT:DeleteTagGroup(info[#info - 1])

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

	option.args.vars.set = function(info, value)
		value = tonumber(value) or strtrim(value)
		if E.global.CustomTags[info[#info - 1]][info[#info]] ~= value then
			rawset(oUF.Tags.Vars, info[#info - 1], nil)

			if value ~= '' then
				E.global.CustomTags[info[#info - 1]][info[#info]] = value
				oUF.Tags.Vars[info[#info - 1]] = value
			else
				E.global.CustomTags[info[#info - 1]][info[#info]] = nil
			end

			oUF.Tags:RefreshMethods(info[#info - 1])
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

	option.args.delete = ACH:Execute(L['Delete'], nil, 7, function(info) E.global.CustomTags[info[#info - 1]] = nil CT:oUF_DeleteTag(info[#info - 1]) CT:DeleteTagGroup(info[#info - 1]) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup') end, nil, format('Delete - %s?', tag), 'full', nil, nil, nil, isDefaultTag)
	option.args.reset = ACH:Execute(L['Defaults'], nil, 8, function(info) E.global.CustomTags[info[#info - 1]] = CopyTable(G.CustomTags[info[#info - 1]]) CT:oUF_DeleteTag(info[#info - 1]) CT:oUF_CreateTag(E.global.CustomTags[info[#info - 1]]) end, nil, format('Reset to Default - %s?', tag), 'full', nil, nil, nil, function(info) return (not isDefaultTag(info)) or (isDefaultTag(info) and AreTableEquals(E.global.CustomTags[info[#info - 1]], G.CustomTags[info[#info - 1]])) end)
	option.args.export = ACH:Input(L['Export Data'], nil, 9, 8, 'full', function(info) return TT:ExportData(info[#info - 1], TT:JoinDBKey('CustomTags')) end)

	optionsPath.customtags.args.tagGroup.args[tag] = option
end

function CT:DeleteVarGroup(var)
	optionsPath.customtags.args.varGroup.args[var] = nil
end

function CT:CreateVarGroup(var)
	local option = ACH:Group(var)
	option.args = CopyTable(SharedVarOptions)
	option.args.name.get = function(info) return info[#info - 1] end
	option.args.name.set = function(info, value)
		value = strtrim(value)
		if value ~= '' and value ~= info[#info - 1] then
			if not E.global.CustomVars[value] then
				E.global.CustomVars[value] = E.global.CustomVars[info[#info - 1]]
				E.global.CustomVars[info[#info - 1]] = nil

				CT:oUF_CreateVar(value)
				CT:oUF_DeleteVar(info[#info - 1])

				CT:CreateVarGroup(value)
				CT:DeleteVarGroup(info[#info - 1])

				E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'varGroup', value)
			end
		end
	end

	option.args.value.get = function(info) return tostring(E.global.CustomVars[info[#info - 1]]) end
	option.args.value.set = function(info, value)
		value = tonumber(value) or strtrim(value)
		if E.global.CustomVars[info[#info - 1]] ~= value then
			rawset(oUF.Tags.Vars, info[#info - 1], nil)

			if value ~= '' then
				E.global.CustomVars[info[#info - 1]] = value
				oUF.Tags.Vars[info[#info - 1]] = value
			else
				E.global.CustomVars[info[#info - 1]] = nil
			end
		end
	end

	option.args.delete = ACH:Execute(L['Delete'], nil, 3, function(info) E.global.CustomVars[info[#info - 1]] = nil rawset(oUF.Tags.Vars, info[#info - 1], nil) CT:DeleteVarGroup(info[#info - 1]) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'varGroup') end, nil, format('Delete - %s?', var), 'full')

	optionsPath.customtags.args.varGroup.args[var] = option
end

function CT:GetOptions()
	ACH = E.Libs.ACH
	optionsPath = E.Options.args.TinkerToolbox.args

	SharedTagOptions = {
		name = ACH:Input(L['Name'], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return oUF.Tags.Methods[value] and L['Name Taken'] or true end),
		category = ACH:Input(L['Category'], nil, 2, nil, 'full'),
		description = ACH:Input(L['Description'], nil, 3, nil, 'full'),
		events = ACH:Input(L['Events'], nil, 4, nil, 'full', nil, nil, nil, nil, IsEventStringValid),
		vars = ACH:Input(L['Variables'], nil, 5, 3, 'full', nil, nil, nil, nil, IsVarStringValid),
		func = ACH:Input(L['Function'], nil, 6, 10, 'full', nil, nil, nil, nil, IsFuncStringValid)
	}

	SharedTagOptions.name.validatePopup = true
	SharedTagOptions.events.validatePopup = true
	SharedTagOptions.vars.validatePopup = true
	SharedTagOptions.func.validatePopup = true
	SharedTagOptions.func.luaHighlighting = true

	SharedVarOptions = {
		name = ACH:Input(L['Name'], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) return oUF.Tags.Vars[strtrim(value)] and L['Name Taken'] or true end),
		value = ACH:Input(L['Value'], nil, 2, 16, 'full', nil, nil, nil, nil, IsVarStringValid),
	}

	optionsPath.customtags = ACH:Group(L["Custom Tags"], nil, 1, 'tab')
	optionsPath.customtags.args.tagGroup = ACH:Group(L['Tags'], nil, 1)
	optionsPath.customtags.args.tagGroup.args.newTag = ACH:Group(L['New'], nil, 0, nil, function(info) return tostring(newTagInfo[info[#info]] or '') end, function(info, value) newTagInfo[info[#info]] = strtrim(value) end)

	optionsPath.customtags.args.tagGroup.args.newTag.args = CopyTable(SharedTagOptions)
	optionsPath.customtags.args.tagGroup.args.newTag.args.vars.set = function(_, value) newTagInfo.vars = tonumber(value) or strtrim(value) end
	optionsPath.customtags.args.tagGroup.args.newTag.args.add = ACH:Execute(L['Add'], nil, 0, function() E.global.CustomTags[newTagInfo.name] = CopyTable(newTagInfo) E.global.CustomTags[newTagInfo.name].name = nil CT:oUF_CreateTag(newTagInfo.name, newTagInfo) CT:CreateTagGroup(newTagInfo.name, newTagInfo) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', newTagInfo.name) newTagInfo.name, newTagInfo.events, newTagInfo.vars, newTagInfo.func, newTagInfo.category, newTagInfo.description = '', '', '', '', '', '' end, nil, nil, 'full', nil, nil, function() return not (newTagInfo.name ~= '' and newTagInfo.func ~= '') end)

	optionsPath.customtags.args.tagGroup.args.copyTag = ACH:Group(L['Copy'], nil, 1, nil, function(info) return tostring(copyTagInfo[info[#info]]) end, function(info, value) copyTagInfo[info[#info]] = strtrim(value) end)
	optionsPath.customtags.args.tagGroup.args.copyTag.args.fromTag = ACH:Input(L['From'], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return (value ~= '' and not oUF.Tags.Methods[value] and L['Name Not Found']) or true end)
	optionsPath.customtags.args.tagGroup.args.copyTag.args.fromTag.validatePopup = true

	optionsPath.customtags.args.tagGroup.args.copyTag.args.toTag = ACH:Input(L['To'], nil, 2, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return (value ~= '' and not oUF.Tags.Methods[value] and L['Name Taken']) or true end)
	optionsPath.customtags.args.tagGroup.args.copyTag.args.toTag.validatePopup = true

	optionsPath.customtags.args.tagGroup.args.copyTag.args.add = ACH:Execute(L['Copy'], nil, 5, function() E.global.CustomTags[copyTagInfo.toTag] = CopyTable(E.global.CustomTags[copyTagInfo.fromTag]) CT:oUF_CreateTag(copyTagInfo.toTag, E.global.CustomTags[copyTagInfo.toTag]) CT:CreateTagGroup(copyTagInfo.toTag, E.global.CustomTags[copyTagInfo.toTag]) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', copyTagInfo.toTag) copyTagInfo.fromTag, copyTagInfo.toTag = '', '' end, nil, nil, 'full', nil, nil, function() return not (copyTagInfo.fromTag ~= '' and copyTagInfo.toTag ~= '') end)

	optionsPath.customtags.args.tagGroup.args.importTag = ACH:Group(L['Import'], nil, 3)
	optionsPath.customtags.args.tagGroup.args.importTag.args.codeInput = ACH:Input(L['Code'], nil, 1, 8, 'full', function() return EncodedTagInfo or '' end, function(_, value) EncodedTagInfo = value DecodedTagInfo = { TT:DecodeData(value) } end)

	optionsPath.customtags.args.tagGroup.args.importTag.args.previewTag = ACH:Group(L['Preview'])
	optionsPath.customtags.args.tagGroup.args.importTag.args.previewTag.inline = true
	optionsPath.customtags.args.tagGroup.args.importTag.args.previewTag.args = CopyTable(SharedTagOptions)
	optionsPath.customtags.args.tagGroup.args.importTag.args.previewTag.args.import = ACH:Execute(L['Import'], nil, 0, function() CT:ImportTag(EncodedTagInfo) end, nil, nil, 'full', nil, nil, function() return not EncodedTagInfo end)
	optionsPath.customtags.args.tagGroup.args.importTag.args.previewTag.args.name.get = function() return DecodedTagInfo and DecodedTagInfo[1] or '' end

	for option in next, SharedTagOptions do
		if option ~= 'name' then
			optionsPath.customtags.args.tagGroup.args.importTag.args.previewTag.args[option].get = function(info) return DecodedTagInfo and DecodedTagInfo[2][info[#info]] or '' end
		end
	end

	optionsPath.customtags.args.varGroup = ACH:Group(L['Variables'], nil, 1)
	optionsPath.customtags.args.varGroup.args.newVar = ACH:Group(L['New Variable'], nil, 0, nil, function(info) return tostring(newVarInfo[info[#info]]) end)
	optionsPath.customtags.args.varGroup.args.newVar.args = CopyTable(SharedVarOptions)

	optionsPath.customtags.args.varGroup.args.newVar.args.add = ACH:Execute(L['Add'], nil, 0, function() E.global.CustomVars[newVarInfo.name] = newVarInfo.value oUF.Tags.Vars[newVarInfo.name] = newVarInfo.value CT:CreateVarGroup(newVarInfo.name, newVarInfo.value) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'varGroup', newVarInfo.name) newVarInfo.name, newVarInfo.value = '', '' end, nil, nil, 'full', nil, nil, function() return not (newVarInfo.name ~= '' and newVarInfo.value ~= '') end)
	optionsPath.customtags.args.varGroup.args.newVar.args.name.set = function(_, value) newVarInfo.name = strtrim(value) end
	optionsPath.customtags.args.varGroup.args.newVar.args.value.set = function(_, value) newVarInfo.value = tonumber(value) or strtrim(value) end

	-- Default Custom Tags
	for Tag in next, G.CustomTags do
		CT:CreateTagGroup(Tag)
	end

	-- Saved Custom Tags
	for Tag in next, E.global.CustomTags do
		CT:CreateTagGroup(Tag)
	end

	-- Default Custom Variables
	for Var in next, G.CustomVars do
		CT:CreateVarGroup(Var)
	end

	-- Saved Custom Variables
	for Var in next, E.global.CustomVars do
		CT:CreateVarGroup(Var)
	end
end

function CT:Initialize()
	-- Build Default Custom Variables
	for VarName, VarValue in next, G.CustomVars do
		pcall(CT.oUF_CreateVar, CT, VarName, VarValue)
	end

	-- Build Default Custom Tags
	for TagName, TagTable in next, G.CustomTags do
		pcall(CT.oUF_BuildTag, CT, TagName, TagTable)
	end

	-- Build Saved Custom Variables
	for VarName, VarValue in next, E.global.CustomVars do
		pcall(CT.oUF_CreateVar, CT, VarName, VarValue)
	end

	-- Build Saved Tags
	for TagName, TagTable in next, E.global.CustomTags do
		pcall(CT.oUF_BuildTag, CT, TagName, TagTable)
	end

	-- Refresh Every Tag
	for tagName in pairs(oUF.Tags.Methods) do
		oUF.Tags:RefreshMethods(tagName)
		oUF.Tags:RefreshEvents(tagName)
	end
end
