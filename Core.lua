local E, _, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local L = E.Libs.ACL:GetLocale('ElvUI', E.global.general.locale or 'enUS')
local CT = E:NewModule('CustomTags');
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

local badEvents = {}
local newTagInfo = { name = '', events = '', vars = '', func = '' }
local newVarInfo = { name = '', value = '' }

local validator = CreateFrame('Frame')

G.CustomTags = {
	["classcolor:hunter"] = {
		["func"] = "function() return Hex(_COLORS.class['HUNTER']) end",
	},
	["classcolor:warrior"] = {
		["func"] = "function() return Hex(_COLORS.class['WARRIOR']) end"
	},
	["classcolor:paladin"] = {
		["func"] = "function() return Hex(_COLORS.class['PALADIN']) end"
	},
	["classcolor:mage"] = {
		["func"] = "function() return Hex(_COLORS.class['MAGE']) end"
	},
	["classcolor:priest"] = {
		["func"] = "function() return Hex(_COLORS.class['PRIEST']) end"
	},
	["classcolor:warlock"] = {
		["func"] = "function() return Hex(_COLORS.class['WARLOCK']) end"
	},
	["classcolor:shaman"] = {
		["func"] = "function() return Hex(_COLORS.class['SHAMAN']) end"
	},
	["classcolor:deathknight"] = {
		["func"] = "function() return Hex(_COLORS.class['DEATHKNIGHT']) end"
	},
	["classcolor:druid"] = {
		["func"] = "function() return Hex(_COLORS.class['DRUID']) end"
	},
	["classcolor:monk"] = {
		["func"] = "function() return Hex(_COLORS.class['MONK']) end"
	},
	["classcolor:rogue"] = {
		["func"] = "function() return Hex(_COLORS.class['ROGUE']) end"
	},
	["classcolor:demonhunter"] = {
		["func"] = "function() return Hex(_COLORS.class['DEMONHUNTER']) end"
	},
}

for TagName, Table in next, G.CustomTags do
	for key in next, newTagInfo do
		if not Table[key] then Table[key] = key == 'name' and TagName or '' end
	end
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

local function oUF_CreateVar(varTable)
	oUF.Tags.Vars[varTable.name] = varTable.value
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
		args = {
			nameField = {
				order = 1,
				type = 'input',
				width = 'full',
				name = 'Name',
				disabled = isDefaultTag,
				validate = function(info, value)
					value = gsub(strtrim(value), '\124\124+', '\124')
					return (value ~= info[#info - 1] and oUF.Tags.Methods[value]) and 'oUF: Name Taken' or true
				end,
				get = function(info)
					return info[#info - 1]
				end,
				set = function(info, value)
					value = strtrim(value):gsub('\124\124+', '\124')
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
			eventField = {
				order = 2,
				type = 'input',
				width = 'full',
				name = 'Events',
				get = function(info) return E.global.CustomTags[info[#info - 1]].events end,
				validate = IsEventStringValid,
				set = function(info, value)
					value = strtrim(value):gsub('\124\124+', '\124')
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
			varField = {
				order = 3,
				type = 'input',
				width = 'full',
				name = 'Varibles',
				multiline = 6,
				validate = IsVarStringValid,
				get = function(info) return E.global.CustomTags[info[#info - 1]].vars end,
				set = function(info, value)
					value = tonumber(value) or strtrim(value):gsub('\124\124+', '\124')
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
			funcField = {
				order = 4,
				type = 'input',
				width = 'full',
				name = 'Function',
				multiline = 12,
				validate = IsFuncStringValid,
				get = function(info) return E.global.CustomTags[info[#info - 1]].func end,
				set = function(info, value)
					value = strtrim(value):gsub('\124\124+', '\124')
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
				func = function(info)
					E.global.CustomTags[info[#info - 1]] = nil

					oUF_DeleteTag(info[#info - 1])

					DeleteTagGroup(info[#info - 1])

					E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customtags', 'tagGroup')
				end,
			},
		},
	}
end

local function DeleteVarGroup(var)
	E.Options.args.customtags.args.varGroup.args[var] = nil
end

local function CreateVarGroup(var)
	E.Options.args.customtags.args.varGroup.args[var.name] = {
		type = 'group',
		name = var.name,
		args = {
			name = {
				order = 1,
				type = 'input',
				width = 'full',
				name = L['Name'],
				validate = function(info, value)
					value = strtrim(value):gsub('\124\124+', '\124')
					return (value ~= info[#info - 1] and oUF.Tags.Vars[value]) and L['Name Taken'] or true
				end,
				get = function(info)
					return info[#info - 1]
				end,
				set = function(info, value)
					value = strtrim(value):gsub('\124\124+', '\124')
					if value ~= '' and value ~= info[#info - 1] then
						if not E.global.CustomVars[value] then
							E.global.CustomVars[value] = E.global.CustomVars[info[#info - 1]]
							E.global.CustomVars[value].name = value
							E.global.CustomVars[info[#info - 1]] = nil

							oUF_CreateVar(E.global.CustomVars[value])
							oUF_DeleteVar(info[#info - 1])

							CreateVarGroup(E.global.CustomVars[value])
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
					return tostring(E.global.CustomVars[info[#info - 1]].value):gsub('\124', '\124\124')
				end,
				set = function(info, value)
					value = tonumber(value) or strtrim(value):gsub('\124\124+', '\124')
					if E.global.CustomVars[info[#info - 1]].value ~= value then
						oUF.Tags.Vars[info[#info - 1]].value = nil

						if value ~= '' then
							E.global.CustomVars[info[#info - 1]].value = value
							oUF.Tags.Vars[info[#info - 1].name] = value
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
							return tostring(newTagInfo[info[#info]]):gsub('\124', '\124\124')
						end,
						set = function(info, value)
							newTagInfo[info[#info]] = strtrim(value):gsub('\124\124+', '\124')
						end,
						args = {
							name = {
								order = 1,
								type = 'input',
								width = 'full',
								name = 'Name',
								validate = function(_, value)
									value = strtrim(value):gsub('\124\124+', '\124')
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
									newTagInfo.vars = tonumber(value) or strtrim(value):gsub('\124\124+', '\124')
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
								func = function()
									if newTagInfo.name ~= '' and newTagInfo.func ~= '' then
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
									end
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
							return tostring(newVarInfo[info[#info]]):gsub('\124', '\124\124')
						end,
						args = {
							name = {
								order = 1,
								type = 'input',
								width = 'full',
								name = L['Name'],
								validate = function(info, value)
									value = strtrim(value):gsub('\124\124+', '\124')
									return oUF.Tags.Vars[value] and L['Name Taken'] or true
								end,
								set = function(_, value)
									newVarInfo.name = strtrim(value):gsub('\124\124+', '\124')
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
									newVarInfo.value = tonumber(value) or strtrim(value):gsub('\124\124+', '\124')
								end,
							},
							add = {
								order = 5,
								type = 'execute',
								name = L['Add'],
								width = 'full',
								func = function()
									if newVarInfo.name ~= '' then
										E.global.CustomVars[newVarInfo.name] = {
											name = newVarInfo.name,
											value = newVarInfo.value
										}

										oUF.Tags.Vars[newVarInfo.name] = newVarInfo.value

										CreateVarGroup(newVarInfo)

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
	for _, VarTable in next, G.CustomVars do
		CreateVarGroup(VarTable)
	end

	-- Saved Custom Variables
	for _, VarTable in next, E.global.CustomVars do
		CreateVarGroup(VarTable)
	end
end

local function Initialize()
	-- Build Default Custom Tags
	for _, TagTable in next, G.CustomTags do
		oUF_CreateTag(TagTable)
	end

	-- Build Saved Tags
	for _, TagTable in next, E.global.CustomTags do
		oUF_CreateTag(TagTable)
	end

	-- Build Default Saved Variables
	for _, VarTable in next, G.CustomVars do
		oUF_CreateVar(VarTable)
	end

	-- Build Saved Variables
	for _, VarTable in next, E.global.CustomVars do
		oUF_CreateVar(VarTable)
	end

	E.Libs.EP:RegisterPlugin('ElvUI_CustomTags', GetOptions)
end

E:RegisterModule(CT:GetName(), Initialize)
