local E, _, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local L = E.Libs.ACL:GetLocale('ElvUI', E.global.general.locale or 'enUS')
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
local newTagInfo = { name = '', events = '', vars = '', func = '' }
local newVarInfo = { name = '', value = '' }
local copyTagInfo = { fromTag = '', toTag = ''}

local validator = CreateFrame('Frame')

G.CustomTags = {
	["classcolor:player"] = {
		func = "function() return Hex(_COLORS.class[_VARS.E.myclass or 'PRIEST']) end"
	},
}

-- Class Colors
for CLASS in next, RAID_CLASS_COLORS do
	G.CustomTags[format("classcolor:%s", strlower(CLASS))] = { func = format("function() return Hex(_COLORS.class['%s']) end", CLASS) }
end

-- Complete Table
for TagName, Table in next, G.CustomTags do
	if not Table['name'] then Table.name = TagName end
	if not Table['func'] then Table.func = "function() end" end
	if not Table['events'] then Table.events = '' end
	if not Table['vars'] then Table.vars = '' end
end

G.CustomVars = {}

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

local function oUF_CreateTag(tagTable)
	if oUF.Tags.Methods[tagTable.name] then return end

	oUF.Tags.Methods[tagTable.name] = tagTable.func
	oUF.Tags:RefreshMethods(tagTable.name)

	if tagTable.events then
		oUF.Tags.Events[tagTable.name] = tagTable.events
		oUF.Tags:RefreshEvents(tagTable.name)
	end

	if tagTable.vars then
		oUF.Tags.Vars[tagTable.name] = tagTable.vars
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
	E.Options.args.customtags.args.tagGroup.args[tag.name] = {
		type = 'group',
		name = tag.name,
		get = function(info)
			return tostring(E.global.CustomTags[info[#info - 1]] and E.global.CustomTags[info[#info - 1]][info[#info]] or G.CustomTags[info[#info - 1]][info[#info]]):gsub("\124", "\124\124")
		end,
		args = {
			name = {
				order = 1,
				type = 'input',
				width = 'full',
				name = 'Name',
				disabled = isDefaultTag,
				validate = function(info, value)
					value = strtrim(value):gsub("\124\124+", "\124")
					return (value ~= info[#info - 1] and oUF.Tags.Methods[value]) and 'oUF: Name Taken' or true
				end,
				get = function(info)
					return info[#info - 1]
				end,
				set = function(info, value)
					value = strtrim(value):gsub("\124\124+", "\124")
					if value ~= '' and value ~= info[#info - 1] then
						if not E.global.CustomTags[value] then
							E.global.CustomTags[value] = CopyTable(E.global.CustomTags[info[#info - 1]])
							E.global.CustomTags[value].name = value

							oUF_CreateTag(E.global.CustomTags[value])
							CreateTagGroup(E.global.CustomTags[value])

							E.global.CustomTags[info[#info - 1]] = nil
							oUF_DeleteTag(info[#info - 1])
							DeleteTagGroup(info[#info - 1])

							E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', value)
						end
					end
				end,
			},
			events = {
				order = 2,
				type = 'input',
				width = 'full',
				name = 'Events',
				validate = IsEventStringValid,
				set = function(info, value)
					value = strtrim(value):gsub("\124\124+", "\124")
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
				order = 3,
				type = 'input',
				width = 'full',
				name = 'Varibles',
				multiline = 6,
				validate = IsVarStringValid,
				set = function(info, value)
					value = tonumber(value) or strtrim(value):gsub("\124\124+", "\124")
					if E.global.CustomTags[info[#info - 1]].vars ~= value then
						rawset(oUF.Tags.Vars, info[#info - 1], nil)

						if value ~= '' then
							E.global.CustomTags[info[#info - 1]].vars = value
							oUF.Tags.Vars[info[#info - 1]] = value
						else
							E.global.CustomTags[info[#info - 1]].vars = nil
						end
					end
				end,
			},
			func = {
				order = 4,
				type = 'input',
				width = 'full',
				name = 'Function',
				multiline = 12,
				validate = IsFuncStringValid,
				set = function(info, value)
					value = strtrim(value):gsub("\124\124+", "\124")
					if E.global.CustomTags[info[#info - 1]].func ~= value then
						E.global.CustomTags[info[#info - 1]].func = value

						rawset(oUF.Tags.Methods, info[#info - 1], nil)
						oUF.Tags.Methods[info[#info - 1]] = value

						oUF.Tags:RefreshMethods(info[#info - 1])
					end
				end,
			},
			delete = {
				order = 5,
				type = 'execute',
				name = 'Delete',
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
				order = 6,
				name = L["Defaults"],
				width = "full",
				confirm = true,
				hidden = function(info)
					return not isDefaultTag(info)
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
					value = strtrim(value):gsub("\124", "\124\124")
					return (value ~= info[#info - 1] and oUF.Tags.Vars[value]) and L['Name Taken'] or true
				end,
				get = function(info)
					return info[#info - 1]
				end,
				set = function(info, value)
					value = strtrim(value):gsub("\124\124+", "\124")
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
					return tostring(E.global.CustomVars[info[#info - 1]]):gsub("\124", "\124\124")
				end,
				set = function(info, value)
					value = tonumber(value) or strtrim(value):gsub("\124\124+", "\124")
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
		name = 'oUF Controls',
		order = -10,
		childGroups = 'tab',
		args = {
			header = {
				order = 0,
				type = 'header',
				name = 'Custom Tags',
			},
			tagGroup = {
				type = 'group',
				order = 1,
				name = 'Custom Tags',
				args = {
					newTag = {
						order = 0,
						type = 'group',
						name = 'New Tag',
						get = function(info)
							return tostring(newTagInfo[info[#info]]):gsub("\124", "\124\124")
						end,
						set = function(info, value)
							newTagInfo[info[#info]] = strtrim(value):gsub("\124\124+", "\124")
						end,
						args = {
							name = {
								order = 1,
								type = 'input',
								width = 'full',
								name = 'Name',
								validate = function(_, value)
									value = strtrim(value):gsub("\124\124+", "\124")
									return oUF.Tags.Methods[value] and 'oUF: Name Taken - '..value or true
								end,
							},
							events = {
								order = 2,
								type = 'input',
								width = 'full',
								name = 'Events',
								validate = IsEventStringValid,
							},
							vars = {
								order = 3,
								type = 'input',
								width = 'full',
								name = 'Varibles',
								multiline = 6,
								validate = IsVarStringValid,
								set = function(_, value)
									newTagInfo.vars = tonumber(value) or strtrim(value):gsub("\124\124+", "\124")
								end,
							},
							func = {
								order = 4,
								type = 'input',
								width = 'full',
								name = 'Function',
								multiline = 12,
								validate = IsFuncStringValid,
							},
							add = {
								order = 5,
								type = 'execute',
								name = 'Add',
								width = 'full',
								hidden = function() return (newTagInfo.name == '' and newTagInfo.func == '') end,
								func = function()
									E.global.CustomTags[newTagInfo.name] = {
										name = newTagInfo.name,
										events = newTagInfo.events,
										vars = newTagInfo.vars,
										func = newTagInfo.func
									}

									oUF_CreateTag(newTagInfo)

									CreateTagGroup(newTagInfo)

									E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup', newTagInfo.name)

									newTagInfo.name, newTagInfo.events, newTagInfo.vars, newTagInfo.func = '', '', '', ''
								end,
							},
						},
					},
					copyTag = {
						order = 1,
						type = 'group',
						name = 'Copy Tag',
						get = function(info)
							return tostring(copyTagInfo[info[#info]]):gsub("\124", "\124\124")
						end,
						set = function(info, value)
							copyTagInfo[info[#info]] = strtrim(value):gsub("\124\124+", "\124")
						end,
						args = {
							fromTag = {
								order = 1,
								type = 'input',
								width = 'full',
								name = 'From Tag',
								validate = function(_, value)
									value = strtrim(value):gsub("\124\124+", "\124")
									return (value ~= '' and not oUF.Tags.Methods[value] and 'oUF: Tag Not Found : '..value) or true
								end,
								validatePopup = true,
							},
							toTag = {
								order = 2,
								type = 'input',
								width = 'full',
								name = 'To Tag',
								validate = function(_, value)
									value = strtrim(value):gsub("\124\124+", "\124")
									return oUF.Tags.Methods[value] and 'oUF: Name Taken : '..value or true
								end,
							},
							add = {
								order = 5,
								type = 'execute',
								name = 'Copy',
								width = 'full',
								hidden = function() return (copyTagInfo.fromTag == '' and copyTagInfo.toTag == '') end,
								func = function()
									E.global.CustomTags[copyTagInfo.toTag] = CopyTable(E.global.CustomTags[copyTagInfo.fromTag])
									E.global.CustomTags[copyTagInfo.toTag].name = copyTagInfo.toTag

									oUF_CreateTag(E.global.CustomTags[copyTagInfo.toTag])
									CreateTagGroup(E.global.CustomTags[copyTagInfo.toTag])

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
				name = 'Custom Variables',
				args = {
					newVar ={
						order = 0,
						type = 'group',
						name = 'New Variable',
						get = function(info)
							return tostring(newVarInfo[info[#info]]):gsub("\124", "\124\124")
						end,
						args = {
							name = {
								order = 1,
								type = 'input',
								width = 'full',
								name = L['Name'],
								validate = function(info, value)
									value = strtrim(value):gsub("\124\124+", "\124")
									return oUF.Tags.Vars[value] and L['Name Taken'] or true
								end,
								set = function(_, value)
									newVarInfo.name = strtrim(value):gsub("\124\124+", "\124")
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
									newVarInfo.value = tonumber(value) or strtrim(value):gsub("\124\124+", "\124")
								end,
							},
							add = {
								order = 5,
								type = 'execute',
								name = L['Add'],
								width = 'full',
								func = function()
									if newVarInfo.name ~= '' then
										E.global.CustomVars[newVarInfo.name] = newVarInfo.value
										oUF.Tags.Vars[newVarInfo.name] = newVarInfo.value

										CreateVarGroup(newVarInfo.name, newVarInfo.value)

										E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'varGroup', newVarInfo.name)

										newVarInfo.name, newVarInfo.value = '', ''
									end
								end,
							},
						},
					},
				},
			},
		},
	}

	-- Default Custom Tags
	for _, TagTable in next, G.CustomTags do
		CreateTagGroup(TagTable)
	end

	-- Saved Custom Tags
	for _, TagTable in next, E.global.CustomTags do
		CreateTagGroup(TagTable)
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
	for Var, VarValue in next, G.CustomVars do
		pcall(oUF_CreateVar, Var, VarValue)
	end

	-- Build Saved Custom Variables
	for Var, VarValue in next, E.global.CustomVars do
		pcall(oUF_CreateVar, Var, VarValue)
	end

	-- Build Default Custom Tags
	for _, TagTable in next, G.CustomTags do
		pcall(oUF_CreateTag, TagTable)
	end

	-- Build Saved Tags
	for _, TagTable in next, E.global.CustomTags do
		pcall(oUF_CreateTag, TagTable)
	end

	E.Libs.EP:RegisterPlugin('ElvUI_CustomTags', GetOptions)
end

hooksecurefunc(E, 'Initialize', Initialize)
