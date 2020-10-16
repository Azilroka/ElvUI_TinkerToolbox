local E, _, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local oUF = E.oUF

local wipe = wipe
local pcall = pcall
local tinsert = tinsert
local format = format
local tonumber = tonumber
local loadstring = loadstring
local gmatch = gmatch
local strtrim = strtrim
local gsub = gsub
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

local L = E.Libs.ACL:NewLocale("ElvUI", "enUS", true, true)

L['Custom Variables'] = true
L['Custom Tags'] = true

L['New Tag'] = true
L['Copy Tag'] = true
L['From Tag'] = true
L['To Tag'] = true

L['Name Taken'] = true
L['Name Not Found'] = true

L['New Variable'] = true

L['Name'] = true
L['Value'] = true
L['Variables'] = true
L['Add'] = true
L['Delete'] = true
L['Copy'] = true
L['Events'] = true
L['Defaults'] = true

L = E.Libs.ACL:GetLocale("ElvUI", "enUS")

-- oUF Defines
E.oUF.Tags.Vars.E = E
E.oUF.Tags.Vars.L = L

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
		func = "function(unit)\n    local name = UnitName(unit)\n\n    if name and string.len(name) > _VARS['name:custom:abbreviate'] then\n        name = name:gsub('(%S+) ', function(t) return t:sub(1,1)..'. ' end)\n    end\n\n    return name\nend",
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
for CLASS in next, RAID_CLASS_COLORS do
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
end

G.CustomVars = {}

local D = E:GetModule('Distributor')
-- Set Distributor to Export
D.GeneratedKeys.global.CustomTags = true
D.GeneratedKeys.global.CustomVars = true

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

local function IsVarStringValid(_, varString)
	if tonumber(varString) then
		return true
	else
		local _, err = loadstring('return ' .. varString)
		return err or true
	end
end

local function IsFuncStringValid(_, funcString)
	local _, err = loadstring('return ' .. funcString)
	return err or true
end

local function oUF_CreateTag(tagName, tagTable)
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

local function oUF_BuildTag(tagName, tagTable)
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

local function oUF_DeleteTag(tag)
	rawset(oUF.Tags.Events, tag, nil)
	rawset(oUF.Tags.Vars, tag, nil)
	rawset(oUF.Tags.Methods, tag, nil)

	oUF.Tags:RefreshEvents(tag)
	oUF.Tags:RefreshMethods(tag)
end

local function oUF_CreateVar(var, varValue)
	oUF.Tags.Vars[var] = varValue
end

local function oUF_DeleteVar(var)
	rawset(oUF.Tags.Vars, var, nil)
end

local function DeleteTagGroup(tag)
	E.Options.args.customtags.args.tagGroup.args[tag] = nil
end

local function CreateTagGroup(tag)
	E.Options.args.customtags.args.tagGroup.args[tag] = {
		type = 'group',
		name = tag,
		get = function(info)
			local db = E.global.CustomTags[info[#info - 1]] or G.CustomTags[info[#info - 1]]
			return gsub(tostring(db and db[info[#info]] or ''), "\124", "\124\124")
		end,
		args = {
			name = {
				order = 0,
				type = 'input',
				width = 'full',
				name = L['Name'],
				disabled = isDefaultTag,
				validate = function(info, value)
					value = gsub(strtrim(value), "\124\124+", "\124")
					return (value ~= info[#info - 1] and oUF.Tags.Methods[value]) and L['Name Taken'] or true
				end,
				get = function(info)
					return info[#info - 1]
				end,
				set = function(info, value)
					value = gsub(strtrim(value), "\124\124+", "\124")
					if value ~= '' and value ~= info[#info - 1] then
						if not E.global.CustomTags[value] then
							E.global.CustomTags[value] = CopyTable(E.global.CustomTags[info[#info - 1]])

							oUF_CreateTag(value, E.global.CustomTags[value])
							CreateTagGroup(value, E.global.CustomTags[value])

							E.global.CustomTags[info[#info - 1]] = nil
							oUF_DeleteTag(info[#info - 1])
							DeleteTagGroup(info[#info - 1])

							E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', value)
						end
					end
				end,
			},
			category = {
				order = 1,
				type = 'input',
				width = 'full',
				name = L['Category'],
				set = function(info, value)
					E.global.CustomTags[info[#info - 1]].category = gsub(strtrim(value), "\124\124+", "\124")
				end,
			},
			description = {
				order = 2,
				type = 'input',
				width = 'full',
				name = L['Description'],
				set = function(info, value)
					E.global.CustomTags[info[#info - 1]].description = gsub(strtrim(value), "\124\124+", "\124")
				end,
			},
			events = {
				order = 3,
				type = 'input',
				width = 'full',
				name = L['Events'],
				validate = IsEventStringValid,
				set = function(info, value)
					value = gsub(strtrim(value), "\124\124+", "\124")
					if E.global.CustomTags[info[#info - 1]].events ~= value then
						if value ~= '' then
							E.global.CustomTags[info[#info - 1]].events = value
							oUF.Tags.Events[info[#info - 1]] = value
						else
							E.global.CustomTags[info[#info - 1]].events = nil
							oUF.Tags.Events[info[#info - 1]] = nil
						end

						oUF.Tags:RefreshEvents(info[#info - 1])
					end
				end,
			},
			vars = {
				order = 4,
				type = 'input',
				width = 'full',
				name = L['Variables'],
				multiline = 6,
				validate = IsVarStringValid,
				set = function(info, value)
					value = tonumber(value) or gsub(strtrim(value), "\124\124+", "\124")
					if E.global.CustomTags[info[#info - 1]].vars ~= value then
						rawset(oUF.Tags.Vars, info[#info - 1], nil)

						if value ~= '' then
							E.global.CustomTags[info[#info - 1]].vars = value
							oUF.Tags.Vars[info[#info - 1]] = value
						else
							E.global.CustomTags[info[#info - 1]].vars = nil
						end

						oUF.Tags:RefreshMethods(info[#info - 1])
					end
				end,
			},
			func = {
				order = 5,
				type = 'input',
				width = 'full',
				name = L['Function'],
				multiline = 24,
				luaHighlighting = true,
				validate = IsFuncStringValid,
				set = function(info, value)
					value = gsub(strtrim(value), "\124\124+", "\124")
					if E.global.CustomTags[info[#info - 1]].func ~= value then
						E.global.CustomTags[info[#info - 1]].func = value

						rawset(oUF.Tags.Methods, info[#info - 1], nil)
						oUF.Tags.Methods[info[#info - 1]] = value

						oUF.Tags:RefreshMethods(info[#info - 1])
					end
				end,
			},
			delete = {
				order = 6,
				type = 'execute',
				name = L['Delete'],
				width = 'full',
				confirm = true,
				hidden = isDefaultTag,
				func = function(info)
					E.global.CustomTags[info[#info - 1]] = nil

					oUF_DeleteTag(info[#info - 1])

					DeleteTagGroup(info[#info - 1])

					E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup')
				end,
			},
			reset = {
				type = "execute",
				order = 7,
				name = L["Defaults"],
				width = "full",
				confirm = true,
				hidden = function(info)
					return (not isDefaultTag(info)) or (isDefaultTag(info) and AreTableEquals(E.global.CustomTags[info[#info - 1]], G.CustomTags[info[#info - 1]]))
				end,
				func = function(info)
					E.global.CustomTags[info[#info - 1]] = CopyTable(G.CustomTags[info[#info - 1]])

					oUF_DeleteTag(info[#info - 1])
					oUF_CreateTag(E.global.CustomTags[info[#info - 1]])
				end,
			},
		},
	}
end

local function DeleteVarGroup(var)
	E.Options.args.customtags.args.varGroup.args[var] = nil
end

local function CreateVarGroup(var)
	E.Options.args.customtags.args.varGroup.args[var] = {
		type = 'group',
		name = var,
		args = {
			name = {
				order = 1,
				type = 'input',
				width = 'full',
				name = L['Name'],
				validate = function(info, value)
					value = gsub(strtrim(value), "\124", "\124\124")
					return (value ~= info[#info - 1] and oUF.Tags.Vars[value]) and L['Name Taken'] or true
				end,
				get = function(info)
					return info[#info - 1]
				end,
				set = function(info, value)
					value = gsub(strtrim(value), "\124\124+", "\124")
					if value ~= '' and value ~= info[#info - 1] then
						if not E.global.CustomVars[value] then
							E.global.CustomVars[value] = E.global.CustomVars[info[#info - 1]]
							E.global.CustomVars[info[#info - 1]] = nil

							oUF_CreateVar(value)
							oUF_DeleteVar(info[#info - 1])

							CreateVarGroup(value)
							DeleteVarGroup(info[#info - 1])

							E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'varGroup', value)
						end
					end
				end,
			},
			value = {
				order = 2,
				type = 'input',
				width = 'full',
				name = L['Value'],
				multiline = 12,
				validate = IsVarStringValid,
				get = function(info)
					return gsub(tostring(E.global.CustomVars[info[#info - 1]]), "\124", "\124\124")
				end,
				set = function(info, value)
					value = tonumber(value) or gsub(strtrim(value), "\124\124+", "\124")
					if E.global.CustomVars[info[#info - 1]] ~= value then
						rawset(oUF.Tags.Vars, info[#info - 1], nil)

						if value ~= '' then
							E.global.CustomVars[info[#info - 1]] = value
							oUF.Tags.Vars[info[#info - 1]] = value
						else
							E.global.CustomVars[info[#info - 1]] = nil
						end
					end
				end,
			},
			delete = {
				order = 3,
				type = 'execute',
				name = L['Delete'],
				width = 'full',
				confirm = true,
				func = function(info)
					E.global.CustomVars[info[#info - 1]] = nil
					rawset(oUF.Tags.Vars, info[#info - 1], nil)

					DeleteVarGroup(info[#info - 1])

					E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'varGroup')
				end,
			},
		},
	}
end

local function GetOptions()
	E.Options.args.customtags = {
		type = 'group',
		name = 'CustomTags',
		order = 6,
		childGroups = 'tab',
		args = {
			tagGroup = {
				type = 'group',
				order = 1,
				name = L['Custom Tags'],
				args = {
					newTag = {
						order = 0,
						type = 'group',
						name = L['New Tag'],
						get = function(info)
							return gsub(tostring(newTagInfo[info[#info]] or ''), "\124", "\124\124")
						end,
						set = function(info, value)
							newTagInfo[info[#info]] = gsub(strtrim(value), "\124\124+", "\124")
						end,
						args = {
							name = {
								order = 0,
								type = 'input',
								width = 'full',
								name = L['Name'],
								validate = function(_, value)
									value = gsub(strtrim(value), "\124\124+", "\124")
									return oUF.Tags.Methods[value] and L['Name Taken'] or true
								end,
							},
							category = {
								order = 1,
								type = 'input',
								width = 'full',
								name = L['Category'],
							},
							description = {
								order = 2,
								type = 'input',
								width = 'full',
								name = L['Description'],
							},
							events = {
								order = 3,
								type = 'input',
								width = 'full',
								name = L['Events'],
								validate = IsEventStringValid,
							},
							vars = {
								order = 4,
								type = 'input',
								width = 'full',
								name = L['Variables'],
								multiline = 6,
								validate = IsVarStringValid,
								set = function(_, value)
									newTagInfo.vars = tonumber(value) or gsub(strtrim(value), "\124\124+", "\124")
								end,
							},
							func = {
								order = 5,
								type = 'input',
								width = 'full',
								name = L['Function'],
								multiline = 24,
								luaHighlighting = true,
								validate = IsFuncStringValid,
							},
							add = {
								order = 6,
								type = 'execute',
								name = L['Add'],
								width = 'full',
								hidden = function() return not (newTagInfo.name ~= '' and newTagInfo.func ~= '') end,
								func = function()
									E.global.CustomTags[newTagInfo.name] = CopyTable(newTagInfo)
									E.global.CustomTags[newTagInfo.name].name = nil

									oUF_CreateTag(newTagInfo.name, newTagInfo)

									CreateTagGroup(newTagInfo.name, newTagInfo)

									E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', newTagInfo.name)

									newTagInfo.name, newTagInfo.events, newTagInfo.vars, newTagInfo.func, newTagInfo.category, newTagInfo.description = '', '', '', '', '', ''
								end,
							},
						},
					},
					copyTag = {
						order = 1,
						type = 'group',
						name = L['Copy Tag'],
						get = function(info)
							return gsub(tostring(copyTagInfo[info[#info]]), "\124", "\124\124")
						end,
						set = function(info, value)
							copyTagInfo[info[#info]] = gsub(strtrim(value), "\124\124+", "\124")
						end,
						args = {
							fromTag = {
								order = 1,
								type = 'input',
								width = 'full',
								name = L['From Tag'],
								validate = function(_, value)
									value = gsub(strtrim(value), "\124\124+", "\124")
									return (value ~= '' and not oUF.Tags.Methods[value] and L['Name Not Found']) or true
								end,
								validatePopup = true,
							},
							toTag = {
								order = 2,
								type = 'input',
								width = 'full',
								name = L['To Tag'],
								validate = function(_, value)
									value = gsub(strtrim(value), "\124\124+", "\124")
									return oUF.Tags.Methods[value] and L['Name Taken'] or true
								end,
							},
							add = {
								order = 5,
								type = 'execute',
								name = L['Copy'],
								width = 'full',
								hidden = function() return not (copyTagInfo.fromTag ~= '' and copyTagInfo.toTag ~= '') end,
								func = function()
									E.global.CustomTags[copyTagInfo.toTag] = CopyTable(E.global.CustomTags[copyTagInfo.fromTag])

									oUF_CreateTag(copyTagInfo.toTag, E.global.CustomTags[copyTagInfo.toTag])
									CreateTagGroup(copyTagInfo.toTag, E.global.CustomTags[copyTagInfo.toTag])

									E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', copyTagInfo.toTag)

									copyTagInfo.fromTag, copyTagInfo.toTag = '', ''
								end,
							},
						},
					},
				},
			},
			varGroup = {
				type = 'group',
				order = 1,
				name = L['Custom Variables'],
				args = {
					newVar ={
						order = 0,
						type = 'group',
						name = L['New Variable'],
						get = function(info)
							return gsub(tostring(newVarInfo[info[#info]]), "\124", "\124\124")
						end,
						args = {
							name = {
								order = 1,
								type = 'input',
								width = 'full',
								name = L['Name'],
								validate = function(info, value)
									value = gsub(strtrim(value), "\124\124+", "\124")
									return oUF.Tags.Vars[value] and L['Name Taken'] or true
								end,
								set = function(_, value)
									newVarInfo.name = gsub(strtrim(value), "\124\124+", "\124")
								end,
							},
							value = {
								order = 2,
								type = 'input',
								width = 'full',
								name = L['Value'],
								multiline = 16,
								validate = IsVarStringValid,
								set = function(_, value)
									newVarInfo.value = tonumber(value) or gsub(strtrim(value), "\124\124+", "\124")
								end,
							},
							add = {
								order = 5,
								type = 'execute',
								name = L['Add'],
								width = 'full',
								hidden = function() return not (newVarInfo.name ~= '' and newVarInfo.value ~= '') end,
								func = function()
									E.global.CustomVars[newVarInfo.name] = newVarInfo.value
									oUF.Tags.Vars[newVarInfo.name] = newVarInfo.value

									CreateVarGroup(newVarInfo.name, newVarInfo.value)

									E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'varGroup', newVarInfo.name)

									newVarInfo.name, newVarInfo.value = '', ''
								end,
							},
						},
					},
				},
			},
		},
	}

	-- Default Custom Tags
	for Tag in next, G.CustomTags do
		CreateTagGroup(Tag)
	end

	-- Saved Custom Tags
	for Tag in next, E.global.CustomTags do
		CreateTagGroup(Tag)
	end

	-- Default Custom Variables
	for Var in next, G.CustomVars do
		CreateVarGroup(Var)
	end

	-- Saved Custom Variables
	for Var in next, E.global.CustomVars do
		CreateVarGroup(Var)
	end
end

local function Initialize()
	-- Build Default Custom Variables
	for VarName, VarValue in next, G.CustomVars do
		pcall(oUF_CreateVar, VarName, VarValue)
	end

	-- Build Default Custom Tags
	for TagName, TagTable in next, G.CustomTags do
		pcall(oUF_BuildTag, TagName, TagTable)
	end

	-- Build Saved Custom Variables
	for VarName, VarValue in next, E.global.CustomVars do
		pcall(oUF_CreateVar, VarName, VarValue)
	end

	-- Build Saved Tags
	for TagName, TagTable in next, E.global.CustomTags do
		pcall(oUF_BuildTag, TagName, TagTable)
	end

	-- Refresh Every Tag
	for tagName in pairs(oUF.Tags.Methods) do
		oUF.Tags:RefreshMethods(tagName)
		oUF.Tags:RefreshEvents(tagName)
	end

	E.Libs.EP:RegisterPlugin('ElvUI_CustomTags', GetOptions)
end

hooksecurefunc(E, 'LoadAPI', Initialize)