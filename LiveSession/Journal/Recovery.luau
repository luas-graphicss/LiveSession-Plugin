local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Parent.Core.Constants)
local JournalStore = require(script.Parent.JournalStore)

local Recovery = {}

local TEXTS = Constants.TEXTS
local UI = Constants.UI

function Recovery.detect(store)
	local pluginFolder = ServerStorage:FindFirstChild(Constants.PLUGIN_FOLDER_NAME)
	local lock = store:readLock()
	local settingsJournal, settingsError = store:readSettings()
	local mirrorJournal, mirrorError = JournalStore.readMirror(pluginFolder)
	local journal = nil
	local source = nil
	if settingsJournal and not settingsJournal.closed then
		journal = settingsJournal
		source = TEXTS.SOURCE_SETTINGS
	elseif mirrorJournal and not mirrorJournal.closed then
		journal = mirrorJournal
		source = TEXTS.SOURCE_MIRROR
	end
	if settingsJournal and mirrorJournal and not settingsJournal.closed and not mirrorJournal.closed
		and mirrorJournal.sessionId == settingsJournal.sessionId and mirrorJournal:count() > settingsJournal:count() then
		journal = mirrorJournal
		source = TEXTS.SOURCE_MIRROR
	end
	if not journal and not pluginFolder then
		return nil
	end
	return {
		journal = journal,
		source = source,
		lock = lock,
		pluginFolder = pluginFolder,
		savedMidSession = pluginFolder ~= nil and pluginFolder:FindFirstChild(Constants.SNAPSHOT_FOLDER_NAME) ~= nil,
		errors = { settings = settingsError, mirror = mirrorError },
	}
end

function Recovery.describe(detection, report)
	local journal = detection.journal
	local lines = {}
	if detection.ownerText then
		table.insert(lines, detection.ownerText)
	end
	if not journal then
		table.insert(lines, TEXTS.RECOVERY_NO_JOURNAL)
	end
	table.insert(lines, string.format(
		TEXTS.RECOVERY_REPORT,
		journal and journal.sessionId or UI.EMPTY_VALUE,
		detection.source or UI.EMPTY_VALUE,
		journal and journal:count() or 0,
		report and report.applied or 0,
		report and report.rebuilt or 0,
		report and report.skipped or 0,
		report and #report.failed or 0,
		report and #report.unresolved or 0
	))
	return table.concat(lines, UI.LINE_SEPARATOR)
end

return Recovery
