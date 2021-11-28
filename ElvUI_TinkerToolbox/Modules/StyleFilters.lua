local TT = unpack(ElvUI_TinkerToolbox)
local E, L, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

local CSF = TT:NewModule('CustomStyleFilters')
local NP = E:GetModule('NamePlates')

local ACH, optionsPath

local strtrim = strtrim
local strlen = strlen
local format = format

G['customStyleFilters'] = {
	['customTriggers'] = {},
	['customActions'] = {}
}

local D = E:GetModule('Distributor')
D.GeneratedKeys.global.customStyleFilters = {}
D.GeneratedKeys.global.customStyleFilters.customTriggers = true
D.GeneratedKeys.global.customStyleFilters.customActions = true

local newTriggerInfo = { name = '', description = '', isNegated = false, func = '' }

local function ResetNewTriggerInfo()
	newTriggerInfo.name = ''
	newTriggerInfo.description = ''
	newTriggerInfo.isNegated = false
	newTriggerInfo.func = ''
end

local newActionInfo = { name = '', description = '', needsClear = true, applyFunc = '', clearFunc = '' }

local function ResetNewActionInfo()
	newActionInfo.name = ''
	newActionInfo.description = ''
	newActionInfo.applyFunc = ''
	newActionInfo.clearFunc = ''
	newActionInfo.needsClear = true
end

local EncodedTriggerInfo, DecodedTriggerInfo

function CSF:ImportTrigger(dataString)
	local name = TT:ImportData(dataString)

	if name then
		CSF:RegisterCustomTrigger(name, E.global.customStyleFilters.customTriggers[name])
		CSF:CreateTriggerGroup(name)
		E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customTriggers', name)
	end

	EncodedTriggerInfo, DecodedTriggerInfo = nil, nil
end

local EncodedActionInfo, DecodedActionInfo

function CSF:ImportAction(dataString)
	local name = TT:ImportData(dataString)

	if name then
		CSF:RegisterCustomAction(name, E.global.customStyleFilters.customActions[name])
		CSF:CreateActionGroup(name)
		E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customActions', name)
	end

	EncodedActionInfo, DecodedActionInfo = nil, nil
end

local function IsFuncStringValid(_, funcString)
	local _, err = loadstring('return ' .. funcString)
	return err or true
end

function CSF:RegisterCustomTrigger(name, db)
	if db.isNegated then
		E.StyleFilterDefaults.triggers['is' .. name] = false
		E.StyleFilterDefaults.triggers['isNot' .. name] = false
	else
		E.StyleFilterDefaults.triggers[name] = false
	end

	CSF.customTriggers[name] = { isNegated = db.isNegated, func = loadstring('return ' .. db.func)() }

	NP:StyleFilterConfigure()
	NP:ConfigureAll()
end

function CSF:RemoveCustomTrigger(name)
	if (CSF.customTriggers[name]) then
		if CSF.customTriggers[name].isNegated then
			E.StyleFilterDefaults.triggers['is' .. name] = nil
			E.StyleFilterDefaults.triggers['isNot' .. name] = nil
		else
			E.StyleFilterDefaults.triggers[name] = nil
		end

		CSF.customTriggers[name] = nil

		optionsPath.customStyleFilters.args.customTriggers.args[name] = nil

		NP:ConfigureAll()
	end
end

function CSF:RegisterCustomAction(name, db)
	E.StyleFilterDefaults.actions[name] = false

	for plate in pairs(NP.Plates) do
		if CSF:IsActionApplied(plate, name) then
			CSF:ClearActionFromFrame(plate, name)
		end
	end

	CSF.customActions[name] = {
		applyFunc = loadstring('return ' .. db.applyFunc)(),
		needsClear = db.needsClear,
		clearFunc = db.needsClear and loadstring('return ' .. db.clearFunc)()
	}

	NP:ConfigureAll()
end

function CSF:RemoveCustomAction(name)
	for plate in pairs(NP.Plates) do
		if CSF:IsActionApplied(plate, name) then
			CSF:ClearActionFromFrame(plate, name)
		end
	end
	E.StyleFilterDefaults.actions[name] = nil
	CSF.customActions[name] = nil
	optionsPath.customStyleFilters.args.customActions.args[name] = nil
	NP:ConfigureAll()
end

function CSF:InitializeTriggerHooks()
	hooksecurefunc(NP, 'StyleFilterConfigure', function() NP.StyleFilterTriggerEvents.FAKE_CustomStyleFiltersUpdate = 0 end)
	NP:StyleFilterConfigure()
end

function CSF:IsActionApplied(frame, actionName)
	if not frame.CSFActiveActions then
		return false
	end

	return frame.CSFActiveActions[actionName]
end

function CSF:ApplyActionToFrame(frame, actionName)
	local db = CSF.customActions[actionName]

	if not db then
		return
	end

	if CSF:IsActionApplied(frame, actionName) then
		CSF:ClearActionFromFrame(frame, actionName)
	end

	db.applyFunc(frame)

	if db.needsClear then
		frame.CSFActiveActions = frame.CSFActiveActions or {}
		frame.CSFActiveActions[actionName] = true
	end
end

function CSF:ClearActionFromFrame(frame, actionName)
	local db = CSF.customActions[actionName]
	if not db then
		return
	end

	db.clearFunc(frame)
	frame.CSFActiveActions[actionName] = nil
end

function CSF:ApplyCustomActions(frame, actions)
	for customAction in pairs(actions) do
		if customAction:sub(-3) == 'CSF' and actions[customAction] then
			local actionName = customAction:sub(1, strlen(customAction) - 3)
			CSF:ApplyActionToFrame(frame, actionName)
		end
	end
end

function CSF:ClearCustomActions(frame)
	if not frame.CSFActiveActions then
		return
	end
	for appliedAction in pairs(frame.CSFActiveActions) do
		CSF:ClearActionFromFrame(frame, appliedAction)
	end
end

function CSF:InitializeActionHooks()
	hooksecurefunc(NP, 'StyleFilterPass', function(_, frame, actions) CSF:ApplyCustomActions(frame, actions) end)
	hooksecurefunc(NP, 'StyleFilterClear', function(_, frame) CSF:ClearCustomActions(frame) end)
end

function CSF.StyleFilterCustomCheck(frame, _, trigger)
	local passed = nil
	for name, db in pairs(CSF.customTriggers) do
		if db.isNegated then
			if trigger['is' .. name] or trigger['isNot' .. name] then
				local res = db.func and db.func(frame)
				local shouldIs = trigger['is' .. name]
				local shouldIsNot = trigger['isNot' .. name]
				if (shouldIs and res == true) or (shouldIsNot and res == false) then
					passed = true
				else
					return false
				end
			end
		elseif trigger[name] then
			local res = db.func and db.func(frame)
			if res then
				passed = true
			else
				return false
			end
		end
	end
	return passed
end

local function CreateNegatedTriggerToggles(name, db)
	local t1 = ACH:Toggle('is' .. name, db.description)
	local t2 = ACH:Toggle('isNot' .. name, db.description)

	return t1, t2
end

local function CreateTriggerToggle(name, db)
	return ACH:Toggle(name, db.description)
end

function CSF:AddCustomTriggers()
	if not E.Options.args.nameplate.args.filters.args.triggers then
		E.Options.args.nameplate.args.filters.args.triggers = {}
		E.Options.args.nameplate.args.filters.args.triggers.args = {}
	end

	if not E.Options.args.nameplate.args.filters.args.triggers.args.custom then
		E.Options.args.nameplate.args.filters.args.triggers.args.custom = {
			type = 'group',
			name = 'Custom',
			order = 999,
			get = function(info)
				E.global.nameplate.filters[CSF.selectedNameplateFilter].triggers =
					E.global.nameplate.filters[CSF.selectedNameplateFilter].triggers or {}
				return E.global.nameplate.filters[CSF.selectedNameplateFilter].triggers[info[#info]]
			end,
			set = function(info, value)
				E.global.nameplate.filters[CSF.selectedNameplateFilter].triggers =
					E.global.nameplate.filters[CSF.selectedNameplateFilter].triggers or {}
				E.global.nameplate.filters[CSF.selectedNameplateFilter].triggers[info[#info]] = value
				NP:ConfigureAll()
			end,
			args = {}
		}
	end

	local tbl = E.Options.args.nameplate.args.filters.args.triggers.args.custom.args
	wipe(tbl)

	for name, db in pairs(CSF.customTriggers) do
		if db.isNegated then
			local t1, t2 = CreateNegatedTriggerToggles(name, db)
			tbl['is' .. name] = t1
			tbl['isNot' .. name] = t2
		else
			tbl[name] = CreateTriggerToggle(name, db)
		end
	end
end

local function CreateActionToggle(name, db)
	return ACH:Toggle(name, db.description)
end

function CSF:AddCustomActions()
	if not E.Options.args.nameplate.args.filters.args.actions.args.custom then
		E.Options.args.nameplate.args.filters.args.actions.args.custom = {
			type = 'group',
			name = 'Custom',
			order = 999,
			inline = true,
			get = function(info)
				E.global.nameplate.filters[CSF.selectedNameplateFilter].actions =
					E.global.nameplate.filters[CSF.selectedNameplateFilter].actions or {}
				return E.global.nameplate.filters[CSF.selectedNameplateFilter].actions[info[#info]]
			end,
			set = function(info, value)
				E.global.nameplate.filters[CSF.selectedNameplateFilter].actions =
					E.global.nameplate.filters[CSF.selectedNameplateFilter].actions or {}
				E.global.nameplate.filters[CSF.selectedNameplateFilter].actions[info[#info]] = value
				NP:ConfigureAll()
			end,
			args = {}
		}
	end

	local tbl = E.Options.args.nameplate.args.filters.args.actions.args.custom.args
	wipe(tbl)

	for name, db in pairs(CSF.customActions) do
		tbl[name] = CreateActionToggle(name, db)
	end
end

function CSF:HookNPOptions()
	local oldAddFilter = E.Options.args.nameplate.args.filters.args.addFilter.set
	E.Options.args.nameplate.args.filters.args.addFilter.set = function(info, value)
		CSF.selectedNameplateFilter = value
		oldAddFilter(info, value)
		CSF:AddCustomTriggers()
		CSF:AddCustomActions()
	end
	local oldFunc = E.Options.args.nameplate.args.filters.args.selectFilter.set
	E.Options.args.nameplate.args.filters.args.selectFilter.set = function(info, value)
		CSF.selectedNameplateFilter = value
		oldFunc(info, value)
		CSF:AddCustomTriggers()
		CSF:AddCustomActions()
	end
end

function CSF:CreateTriggerGroup(name)
	local options = ACH:Group(name, nil, nil, nil, function(info) local db = E.global.customStyleFilters.customTriggers[info[#info - 1]] return db[info[#info]] end)
	options.args = E:CopyTable({}, CSF.SharedTriggerOptions)

	options.args.name.get = function(info) return info[#info - 1] end
	options.args.name.set = function(info, value)
		if value ~= '' and value ~= info[#info - 1] then
			if not E.global.customStyleFilters.customTriggers[value] then
				E.global.customStyleFilters.customTriggers[value] =
					E:CopyTable({}, E.global.customStyleFilters.customTriggers[info[#info - 1]])

				CSF:RegisterCustomTrigger(value, E.global.customStyleFilters.customTriggers[value])
				CSF:CreateTriggerGroup(value)

				E.global.customStyleFilters.customTriggers[info[#info - 1]] = nil
				CSF:RemoveCustomTrigger(info[#info - 1])
				optionsPath.customStyleFilters.args.customTriggers.args[info[#info - 1]] = nil

				E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customTriggers', value)
			end
		end
	end

	options.args.isNegated.set = function(info, value) E.global.customStyleFilters.customTriggers[info[#info - 1]][info[#info]] = value CSF:RegisterCustomTrigger(info[#info - 1], E.global.customStyleFilters.customTriggers[info[#info - 1]]) CSF:AddCustomTriggers() end
	options.args.description.set = function(info, value) E.global.customStyleFilters.customTriggers[info[#info - 1]][info[#info]] = strtrim(value) CSF:RegisterCustomTrigger(info[#info - 1], E.global.customStyleFilters.customTriggers[info[#info - 1]]) end
	options.args.func.set = function(info, value) value = strtrim(value) if E.global.customStyleFilters.customTriggers[info[#info - 1]][info[#info]] ~= value then E.global.customStyleFilters.customTriggers[info[#info - 1]][info[#info]] = value CSF:RegisterCustomTrigger(info[#info - 1], E.global.customStyleFilters.customTriggers[info[#info - 1]]) end end

	options.args.delete = ACH:Execute(L["Delete"], nil, 7, function(info) E.global.customStyleFilters.customTriggers[info[#info - 1]] = nil CSF:RemoveCustomTrigger(info[#info - 1]) optionsPath.customStyleFilters.args.customTriggers.args[info[#info - 1]] = nil E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customTriggers') end, nil, format('Delete - %s?', name), 'full')
	options.args.reset = ACH:Execute(L["Defaults"], nil, 8, function(info) E.global.customStyleFilters.customTriggers[info[#info - 1]] = CopyTable({description = '', isNegated = false, func = ''}) CSF:RegisterCustomTrigger(info[#info-1], E.global.customStyleFilters.customTriggers[info[#info - 1]]) end, nil, format('Reset to Default - %s?', name), 'full')
	options.args.export = ACH:Input(L["Export Data"], nil, 9, 8, 'full', function(info) return TT:ExportData(info[#info - 1], TT:JoinDBKey('customStyleFilters', 'customTriggers')) end)

	optionsPath.customStyleFilters.args.customTriggers.args[name] = options
end

function CSF:CreateActionGroup(name)
	local options = ACH:Group(name, nil, nil, nil, function(info) local db = E.global.customStyleFilters.customActions[info[#info - 1]] return db[info[#info]] end)
	options.args = E:CopyTable({}, CSF.SharedActionOptions)
	options.args.name.get = function(info) return info[#info - 1] end
	options.args.name.set = function(info, value)
		if value ~= '' and value ~= info[#info - 1] then
			if not E.global.customStyleFilters.customActions[value] then
				E.global.customStyleFilters.customActions[value] = E:CopyTable({}, E.global.customStyleFilters.customActions[info[#info - 1]])

				CSF:RegisterCustomAction(value, E.global.customStyleFilters.customActions[value])
				CSF:CreateActionGroup(value)

				E.global.customStyleFilters.customActions[info[#info - 1]] = nil
				CSF:RemoveCustomAction(info[#info - 1])
				optionsPath.customStyleFilters.args.customActions.args[info[#info - 1]] = nil

				E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customActions', value)
			end
		end
	end
	options.args.description.set = function(info, value) E.global.customStyleFilters.customActions[info[#info - 1]][info[#info]] = strtrim(value) CSF:RegisterCustomAction(info[#info - 1], E.global.customStyleFilters.customActions[info[#info - 1]]) end
	options.args.needsClear.set = function(info, value) E.global.customStyleFilters.customActions[info[#info - 1]][info[#info]] = value CSF:RegisterCustomAction(info[#info - 1],E.global.customStyleFilters.customActions[info[#info - 1]]) end
	options.args.applyFunc.set = function(info, value) value = strtrim(value) if E.global.customStyleFilters.customActions[info[#info - 1]][info[#info]] ~= value then E.global.customStyleFilters.customActions[info[#info - 1]][info[#info]] = value CSF:RegisterCustomAction(info[#info - 1], E.global.customStyleFilters.customActions[info[#info - 1]]) end end
	options.args.clearFunc.set = function(info, value) value = strtrim(value) if E.global.customStyleFilters.customActions[info[#info - 1]][info[#info]] ~= value then E.global.customStyleFilters.customActions[info[#info - 1]][info[#info]] = value CSF:RegisterCustomAction(info[#info - 1], E.global.customStyleFilters.customActions[info[#info - 1]]) end end
	options.args.clearFunc.disabled = function() local db = E.global.customStyleFilters.customActions[name] return db and not db.needsClear end
	options.args.delete = ACH:Execute(L["Delete"], nil, 7, function(info) E.global.customStyleFilters.customActions[info[#info - 1]] = nil CSF:RemoveCustomTrigger(info[#info - 1]) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customActions') end, nil, format('Delete - %s?', name), 'full')
	options.args.reset = ACH:Execute(L["Defaults"], nil, 8, function(info) E.global.customStyleFilters.customActions[info[#info - 1]] = CopyTable({description = '', isExclusive = false, func = ''}) CSF:RegisterCustomTrigger(name) end, nil, format('Reset to Default - %s?', name), 'full')
	options.args.export = ACH:Input(L["Export Data"], nil, 9, 8, 'full', function(info) return TT:ExportData(info[#info - 1], TT:JoinDBKey('customStyleFilters', 'customActions')) end)

	optionsPath.customStyleFilters.args.customActions.args[name] = options
end

function CSF:GetOptions()
	ACH = E.Libs.ACH
	optionsPath = E.Options.args.TinkerToolbox.args

	local SharedTriggerOptions = {
		name = ACH:Input(L["Name"], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return E.global.customStyleFilters.customTriggers[value] and L["Name Taken"] or true end),
		description = ACH:Input(L["Description"], nil, 3, nil, 'full'),
		isNegated = ACH:Toggle(L["Is Negated Value (is/isNot)"], nil, 5),
		func = ACH:Input(L["Function"], nil, 6, 10, 'full', nil, nil, nil, nil, IsFuncStringValid)
	}

	SharedTriggerOptions.name.validatePopup = true
	SharedTriggerOptions.func.validatePopup = true
	SharedTriggerOptions.func.luaHighlighting = true

	CSF.SharedTriggerOptions = SharedTriggerOptions

	optionsPath.customStyleFilters = ACH:Group(L["Custom Style Filters"], nil, 2, 'tab')
	optionsPath.customStyleFilters.args.customTriggers = ACH:Group(L["Custom Triggers"], nil, 1)
	optionsPath.customStyleFilters.args.customTriggers.args.newTrigger = ACH:Group(L["New Trigger"], nil, 0, nil, function(info) local value = newTriggerInfo[info[#info]] if type(value) == 'boolean' then return value else return tostring(value) end end, function(info, value) newTriggerInfo[info[#info]] = type(value) == 'string' and strtrim(value) or value end)
	optionsPath.customStyleFilters.args.customTriggers.args.newTrigger.args = CopyTable(SharedTriggerOptions)
	optionsPath.customStyleFilters.args.customTriggers.args.newTrigger.args.add = ACH:Execute(L["Add"], nil, 0, function() E.global.customStyleFilters.customTriggers[newTriggerInfo.name] = E:CopyTable({}, newTriggerInfo) E.global.customStyleFilters.customTriggers[newTriggerInfo.name].name = nil CSF:RegisterCustomTrigger(newTriggerInfo.name, newTriggerInfo) CSF:CreateTriggerGroup(newTriggerInfo.name, newTriggerInfo) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customTriggers', newTriggerInfo.name) ResetNewTriggerInfo() end, nil, nil, 'full', nil, nil, function() return (newTriggerInfo.name == '' or newTriggerInfo.func == '') end)
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger = ACH:Group(L["Import Trigger"], nil, 1)
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.codeInput = ACH:Input(L["Code"], nil, 1, 8, 'full', function() return EncodedTriggerInfo or '' end, function(_, value) EncodedTriggerInfo = value DecodedTriggerInfo = { TT:DecodeData(value) } end)

	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger = ACH:Group(L["Preview"])
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger.inline = true
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger.args = CopyTable(SharedTriggerOptions)
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger.args.import = ACH:Execute(L["Import"], nil, 0, function() CSF:ImportTrigger(EncodedTriggerInfo) end, nil, nil, 'full', nil, nil, function() return not EncodedTriggerInfo end)
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger.args.name.get = function() return DecodedTriggerInfo and DecodedTriggerInfo[1] or '' end
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger.args.description.get = function() return DecodedTriggerInfo and DecodedTriggerInfo[2].description or '' end
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger.args.isNegated.get = function() return DecodedTriggerInfo and DecodedTriggerInfo[2].isNegated or false end
	optionsPath.customStyleFilters.args.customTriggers.args.importTrigger.args.previewTrigger.args.func.get = function() return DecodedTriggerInfo and DecodedTriggerInfo[2].func or '' end

	local SharedActionOptions = {
		name = ACH:Input(L["Name"], nil, 1, nil, 'full', nil, nil, nil, nil, function(_, value) value = strtrim(value) return E.global.customStyleFilters.customActions[value] and L['Name Taken'] or true end),
		description = ACH:Input(L["Description"], nil, 3, nil, 'full'),
		needsClear = ACH:Toggle(L["Needs Clear Function"], nil, 4),
		applyFunc = ACH:Input(L["Apply Function"], nil, 6, 10, 'full', nil, nil, nil, nil, IsFuncStringValid),
		clearFunc = ACH:Input(L["Clear Function"], nil, 7, 10, 'full', nil, nil, nil, nil, IsFuncStringValid)
	}

	SharedActionOptions.applyFunc.validatePopup = true
	SharedActionOptions.applyFunc.luaHighlighting = true
	SharedActionOptions.clearFunc.validatePopup = true
	SharedActionOptions.clearFunc.luaHighlighting = true

	CSF.SharedActionOptions = SharedActionOptions

	optionsPath.customStyleFilters.args.customActions = ACH:Group(L["Custom Actions"], nil, 2)
	optionsPath.customStyleFilters.args.customActions.args.newAction = ACH:Group(L["New Action"], nil, 0, nil, function(info) local value = newActionInfo[info[#info]] if type(value) == 'boolean' then return value else return tostring(value) end end, function(info, value) newActionInfo[info[#info]] = type(value) == 'string' and strtrim(value) or value end)
	optionsPath.customStyleFilters.args.customActions.args.newAction.args = E:CopyTable({}, SharedActionOptions)
	optionsPath.customStyleFilters.args.customActions.args.newAction.args.add = ACH:Execute(L["Add"], nil, 0, function() E.global.customStyleFilters.customActions[newActionInfo.name] = E:CopyTable({}, newActionInfo) E.global.customStyleFilters.customActions[newActionInfo.name].name = nil CSF:RegisterCustomAction(newActionInfo.name, newActionInfo) CSF:CreateActionGroup(newActionInfo.name) E.Libs.AceConfigDialog:SelectGroup('ElvUI', 'customStyleFilters', 'customActions', newActionInfo.name) ResetNewActionInfo() end, nil, nil, 'full', nil, nil, function() return (newActionInfo.name == '' or newActionInfo.applyFunc == '' or (newActionInfo.needsClear and newActionInfo.clearFunc == '')) end)
	optionsPath.customStyleFilters.args.customActions.args.newAction.args.clearFunc.disabled = function() return not newActionInfo.needsClear end

	optionsPath.customStyleFilters.args.customActions.args.importAction = ACH:Group(L["Import Action"], nil, 1)
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.codeInput = ACH:Input(L["Code"], nil, 1, 8, 'full', function() return EncodedActionInfo or '' end, function(_, value) EncodedActionInfo = value DecodedActionInfo = { TT:DecodeData(value) } end)

	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction = ACH:Group(L["Preview"])
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.inline = true
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args = CopyTable(SharedActionOptions)
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args.import = ACH:Execute(L["Import"], nil, 0, function() CSF:ImportAction(EncodedActionInfo) end, nil, nil, 'full', nil, nil, function() return not EncodedActionInfo end)

	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args.name.get = function() return DecodedActionInfo and DecodedActionInfo[1] or '' end
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args.description.get = function() return DecodedActionInfo and DecodedActionInfo[2].description or '' end
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args.needsClear.get = function() return DecodedActionInfo and DecodedActionInfo[2].needsClear or true end
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args.applyFunc.get = function() return DecodedActionInfo and DecodedActionInfo[2].applyFunc or '' end
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args.clearFunc.get = function() return DecodedActionInfo and DecodedActionInfo[2].clearFunc or '' end
	optionsPath.customStyleFilters.args.customActions.args.importAction.args.previewAction.args.clearFunc.disabled = function() return DecodedActionInfo and not DecodedActionInfo[2].needsClear end

	for name in next, E.global.customStyleFilters.customTriggers do
		CSF:CreateTriggerGroup(name)
	end

	for name in next, E.global.customStyleFilters.customActions do
		CSF:CreateActionGroup(name)
	end

	CSF:HookNPOptions()
end

function CSF:Initialize()
	CSF.customTriggers = {}
	CSF.customActions = {}

	CSF:InitializeTriggerHooks()
	CSF:InitializeActionHooks()

	for name, db in pairs(E.global.customStyleFilters.customTriggers) do
		CSF:RegisterCustomTrigger(name, db)
	end

	for name, db in pairs(E.global.customStyleFilters.customActions) do
		CSF:RegisterCustomAction(name, db)
	end

	E.Libs.EP:RegisterPlugin('ElvUI_CustomStyleFilters', CSF.GetOptions)
end
