-- Karmabook - Core
-- Saved data, name matching, and the slash command. Nothing is sent to other
-- players unless you pick Share on a page, and nobody gets on your list
-- unless you add them.

Karmabook = {}
local GB = Karmabook

GB.VERSION = "0.1.0"

GB.COLORS = {
    BRAND = "|cffffd100",
    ERROR = "|cffff4040",
    INFO = "|cffaaaaaa",
    DEBUG = "|cffff8800",
}

-- color is for chat and the banner, ink is the darker shade that reads on paper
GB.LABELS = {
    GRUDGE = { name = "Grudge", color = "|cffff8000", ink = "|cff7a3300", sound = SOUNDKIT.RAID_WARNING },
    KOS = { name = "Kill on Sight", color = "|cffff2020", ink = "|cff8a0000", sound = SOUNDKIT.RAID_WARNING },
    CAUTION = { name = "Caution", color = "|cffffff00", ink = "|cff5f4500", sound = SOUNDKIT.READY_CHECK },
    GOOD = { name = "Good Player", color = "|cff40ff40", ink = "|cff145214", sound = SOUNDKIT.TELL_MESSAGE },
}
GB.LABEL_ORDER = { "GRUDGE", "KOS", "CAUTION", "GOOD" }
GB.DEFAULT_LABEL = "GRUDGE"

-- What the entry form offers. Skyborne plays on both factions.
GB.RACES = {
    "Dwarf", "Gnome", "Human", "Night Elf", "Orc", "Skyborne", "Tauren", "Troll", "Undead",
}
GB.CLASSES = {
    "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior",
}

local DEFAULTS = {
    players = {},
    -- Pages guildmates shared, waiting in the Guild tab
    shared = {},
    receiveShared = true,
    -- Guild sharing history for the Sync page in settings
    syncLog = {},
    -- Plain notes in the Notes tab, not about any player
    misc = {},
    alerts = true,
    sound = true,
    banner = true,
    tooltip = true,
    chatMarker = true,
    showMinimap = true,
    quietInCombat = false,
    nearby = true,
    groupWarnings = true,
    -- Which kinds of chat raise an alert
    watch = {
        say = true,
        emote = true,
        whisper = true,
        guild = true,
        group = true,
        channel = true,
    },
}

local NAME_MAX = 50
GB.NOTE_MAX = 300
GB.ZONE_MAX = 60
GB.MISC_TITLE_MAX = 50
GB.MISC_TEXT_MAX = 2000
local NOTES_PER_PLAYER = 50

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

function GB:Print(msg)
    print(GB.COLORS.BRAND .. "[Karmabook]|r " .. msg)
end

-- Forever runs the Midnight API, where chat and unit data can come back as
-- "secret" values that can't be compared or joined. Those read as unknown.
function GB.Readable(value)
    if value == nil or (issecretvalue ~= nil and issecretvalue(value)) then
        return nil
    end
    return value
end

-- Drops a multi-byte character that a byte-length cut left half finished
local function TrimPartialUTF8(text)
    local i = #text
    while i > 0 and text:byte(i) >= 128 and text:byte(i) < 192 do
        i = i - 1
    end
    if i > 0 and text:byte(i) >= 192 then
        local lead = text:byte(i)
        local length = lead >= 240 and 4 or lead >= 224 and 3 or 2
        if #text - i + 1 < length then
            return text:sub(1, i - 1)
        end
    end
    return text
end

-- Removes the pipe character, which would start a chat escape code
function GB.CleanText(text, maxLen)
    if type(text) ~= "string" then
        return ""
    end
    text = text:gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if maxLen and #text > maxLen then
        text = TrimPartialUTF8(text:sub(1, maxLen))
    end
    return text
end

function GB.Shorten(text, maxLen)
    if #text <= maxLen then
        return text
    end
    return TrimPartialUTF8(text:sub(1, maxLen)) .. "..."
end

-- Forever names are "First Surname". Hyphens are treated as the separator in
-- case a name arrives as "First-Surname", and anything past the second word
-- is dropped. Only the first letter of each word is capitalized, so typed and
-- real names line up without flattening a name like "McDonald".
function GB.NormalizeName(name)
    name = GB.CleanText(name, NAME_MAX):gsub("%-", " ")
    local first, surname = name:match("^(%S+)%s*(%S*)")
    if not first then
        return nil
    end
    local function Capitalize(word)
        local head = word:sub(1, 1)
        return head:byte() < 128 and (head:upper() .. word:sub(2)) or word
    end
    if surname == "" then
        return Capitalize(first)
    end
    return Capitalize(first) .. " " .. Capitalize(surname)
end

local function KeyOf(displayName)
    return displayName:lower()
end

function GB:UnitFullName(unit)
    local name, surname = UnitName(unit)
    name, surname = GB.Readable(name), GB.Readable(surname)
    if not name or name == "" then
        return nil
    end
    if surname and surname ~= "" then
        name = name .. " " .. surname
    end
    return GB.NormalizeName(name)
end

function GB:PlayerFullName()
    if not self.fullName then
        self.fullName = self:UnitFullName("player")
    end
    return self.fullName
end

function GB:IsSelf(name)
    local mine = self:PlayerFullName()
    local normalized = GB.NormalizeName(name)
    return mine ~= nil and normalized ~= nil and KeyOf(mine) == KeyOf(normalized)
end

function GB.Ago(when)
    local elapsed = time() - when
    if elapsed < 60 then
        return "just now"
    elseif elapsed < 3600 then
        return math.floor(elapsed / 60) .. "m ago"
    elseif elapsed < 86400 then
        return math.floor(elapsed / 3600) .. "h ago"
    end
    return date("%b %d", when)
end

-- "Subzone, Zone" where you're standing, or just the zone
function GB:CurrentZone()
    local zone = GB.Readable(GetZoneText())
    local subzone = GB.Readable(GetSubZoneText())
    if zone == "" then
        zone = nil
    end
    if subzone and subzone ~= "" and subzone ~= zone then
        return zone and (subzone .. ", " .. zone) or subzone
    end
    return zone
end

-- When and where a note was written: "Nov 09, 2026 03:42 PM, Felwood"
function GB.FormatNoteStamp(note)
    local stamp = date("%b %d, %Y %I:%M %p", note.t)
    if note.zone then
        stamp = stamp .. ", " .. note.zone
    end
    if note.from then
        stamp = stamp .. " (from " .. note.from .. ")"
    end
    return stamp
end

----------------------------------------------------------------------
-- The list
----------------------------------------------------------------------

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function GB:InitDB()
    KarmabookDB = KarmabookDB or {}
    ApplyDefaults(KarmabookDB, DEFAULTS)
    self.db = KarmabookDB
    self.guidIndex = {}
    for key, record in pairs(self.db.players) do
        if record.guid then
            self.guidIndex[record.guid] = key
        end
    end
end

local function RememberGUID(self, key, record, guid)
    if guid and guid ~= "" and record.guid ~= guid then
        record.guid = guid
        self.guidIndex[guid] = key
    end
end

local function StoreIdentity(record, race, class)
    race, class = GB.Readable(race), GB.Readable(class)
    if race and race ~= "" then
        record.race = race
    end
    if class and class ~= "" then
        record.class = class
    end
end

-- Fills in race and class from a GUID. The game only knows these once the
-- client has seen that player, so it can take a few tries.
function GB:LearnIdentity(record, guid)
    if (record.race and record.class) or not guid or guid == "" then
        return
    end
    local ok, class, _, race = pcall(GetPlayerInfoByGUID, guid)
    if ok then
        StoreIdentity(record, race, class)
    end
end

-- For when you can see the player but their GUID is hidden
function GB:LearnIdentityFromUnit(record, unit)
    if record.race and record.class then
        return
    end
    local classOk, class = pcall(UnitClass, unit)
    local raceOk, race = pcall(UnitRace, unit)
    StoreIdentity(record, raceOk and race or nil, classOk and class or nil)
end

-- "Undead Rogue", or nil if neither is known yet
function GB.FormatIdentity(record)
    if record.race and record.class then
        return record.race .. " " .. record.class
    end
    return record.race or record.class
end

-- Returns the record for a player, and true as the second value when only
-- the first name matched: an entry you saved without a surname matches
-- anyone with that first name.
function GB:Find(name, guid)
    if guid and self.guidIndex[guid] then
        local record = self.db.players[self.guidIndex[guid]]
        if record then
            self:LearnIdentity(record, guid)
            return record, false
        end
    end
    local display = GB.NormalizeName(name)
    if not display then
        return nil
    end
    local key = KeyOf(display)
    local record = self.db.players[key]
    if record then
        RememberGUID(self, key, record, guid)
        self:LearnIdentity(record, guid)
        return record, false
    end
    local firstName = key:match("^(%S+) %S")
    if firstName and self.db.players[firstName] then
        return self.db.players[firstName], true
    end
    return nil
end

-- Saves a plain note from the Notes tab, creating it when note is nil. An untitled note takes its
-- title from its first words. Blank title and text change nothing. Returns the
-- note, or nil if nothing was created.
function GB:SaveMiscNote(note, title, text)
    title = GB.CleanText(title, GB.MISC_TITLE_MAX)
    text = GB.CleanText(text, GB.MISC_TEXT_MAX)
    if title == "" and text == "" then
        return note
    end
    if title == "" then
        title = GB.CleanText((text:gsub("%s+", " ")), 40)
    end
    if note and note.title == title and note.text == text then
        return note
    end
    if not note then
        note = { added = time() }
        table.insert(self.db.misc, note)
    end
    note.title, note.text, note.updated = title, text, time()
    self:Refresh()
    return note
end

function GB:DeleteMiscNote(note)
    for index, candidate in ipairs(self.db.misc) do
        if candidate == note then
            table.remove(self.db.misc, index)
            break
        end
    end
    self:Refresh()
end

-- Newest changes first
function GB:GetMiscNotes(search)
    local list = {}
    search = search and search ~= "" and search:lower() or nil
    for _, note in ipairs(self.db.misc) do
        if not search or (note.title .. " " .. note.text):lower():find(search, 1, true) then
            list[#list + 1] = note
        end
    end
    table.sort(list, function(a, b)
        if a.updated ~= b.updated then
            return a.updated > b.updated
        end
        return a.title < b.title
    end)
    return list
end

-- Files a note by its own date, so an older one can't pass for the newest
function GB:InsertDatedNote(record, note)
    local position = #record.notes + 1
    while position > 1 and record.notes[position - 1].t > note.t do
        position = position - 1
    end
    table.insert(record.notes, position, note)
    while #record.notes > NOTES_PER_PLAYER do
        table.remove(record.notes, 1)
    end
end

-- A typed location, cleaned. Blank means no location at all.
local function CleanZone(zone)
    zone = GB.CleanText(zone, GB.ZONE_MAX)
    return zone ~= "" and zone or nil
end

-- Adds a player, or adds a dated note to one already on the list. The note is
-- placed where you're standing unless zone says otherwise. Returns the
-- record, or nil and a reason.
function GB:AddNote(name, text, labelKey, guid, zone)
    local display = GB.NormalizeName(name)
    if not display then
        return nil, "Enter a player name."
    end
    if self:IsSelf(display) then
        return nil, "That's you."
    end

    local key = KeyOf(display)
    local record = self.db.players[key]
    if not record then
        record = {
            name = display,
            label = GB.DEFAULT_LABEL,
            added = time(),
            notes = {},
        }
        self.db.players[key] = record
    end
    if labelKey and GB.LABELS[labelKey] then
        record.label = labelKey
    end
    RememberGUID(self, key, record, guid)
    self:LearnIdentity(record, guid)

    text = GB.CleanText(text, GB.NOTE_MAX)
    if text ~= "" then
        local place = zone == nil and self:CurrentZone() or CleanZone(zone)
        table.insert(record.notes, { t = time(), text = text, zone = place })
        while #record.notes > NOTES_PER_PLAYER do
            table.remove(record.notes, 1)
        end
    end
    self:Refresh()
    return record
end

-- Corrects the name on a page and keeps its notes. A different name means a
-- different character, so what was learned from the old name is forgotten and
-- picked up again when the new name is seen. Returns nil and a reason if it
-- can't be done.
function GB:RenamePlayer(record, newName)
    local display = GB.NormalizeName(newName)
    if not display then
        return nil, "Enter a player name."
    end
    if self:IsSelf(display) then
        return nil, "That's you."
    end

    local oldKey, newKey = KeyOf(record.name), KeyOf(display)
    if newKey ~= oldKey then
        if self.db.players[newKey] then
            return nil, "There's already a page for " .. self.db.players[newKey].name .. "."
        end
        if record.guid then
            self.guidIndex[record.guid] = nil
        end
        record.guid, record.race, record.class, record.seen, record.shared = nil, nil, nil, nil, nil
        self.db.players[oldKey] = nil
        self.db.players[newKey] = record
    end
    record.name = display
    self:Refresh()
    return record
end

-- Rewrites the newest note, keeping its original date. Clearing the text
-- removes that note. A player with no notes gets a new one. zone replaces the
-- note's location when given.
function GB:SetLatestNote(record, text, zone)
    text = GB.CleanText(text, GB.NOTE_MAX)
    local latest = GB.LatestNote(record)
    if not latest then
        if text ~= "" then
            local place = zone == nil and self:CurrentZone() or CleanZone(zone)
            table.insert(record.notes, { t = time(), text = text, zone = place })
        end
    elseif text == "" then
        table.remove(record.notes)
    else
        latest.text = text
        if zone ~= nil then
            latest.zone = CleanZone(zone)
        end
    end
    self:Refresh()
end

function GB:RemoveLatestNote(record)
    table.remove(record.notes)
    self:Refresh()
end

function GB:DeletePlayer(record)
    local key = KeyOf(record.name)
    if record.guid then
        self.guidIndex[record.guid] = nil
    end
    self.db.players[key] = nil
    self:Refresh()
end

function GB:CycleLabel(record)
    for index, key in ipairs(GB.LABEL_ORDER) do
        if key == record.label then
            record.label = GB.LABEL_ORDER[index % #GB.LABEL_ORDER + 1]
            break
        end
    end
    self:Refresh()
end

function GB:SetMuted(record, muted)
    record.muted = muted or nil
    self:Refresh()
end

-- Sightings know your zone. Chat doesn't: a guildmate can be anywhere, so
-- those pass a nil zone and only record where you heard them.
function GB:MarkSeen(record, how, zone)
    record.seen = { t = time(), how = how, zone = zone }
end

function GB.LatestNote(record)
    return record.notes[#record.notes]
end

function GB.FormatLabel(record)
    local label = GB.LABELS[record.label] or GB.LABELS[GB.DEFAULT_LABEL]
    return label.color .. label.name .. "|r"
end

function GB.InkColor(record)
    return (GB.LABELS[record.label] or GB.LABELS[GB.DEFAULT_LABEL]).ink
end

function GB.FormatLabelInk(record)
    local label = GB.LABELS[record.label] or GB.LABELS[GB.DEFAULT_LABEL]
    return label.ink .. label.name .. "|r"
end

function GB.FormatSeen(record)
    local seen = record.seen
    if not seen then
        return "Not seen yet"
    end
    local text = seen.how
    if seen.zone then
        text = text .. " in " .. seen.zone
    end
    return text .. ", " .. GB.Ago(seen.t)
end

-- Players newest activity first, limited to one label when given one
function GB:GetSorted(labelKey, search)
    local list = {}
    search = search and search ~= "" and search:lower() or nil
    for _, record in pairs(self.db.players) do
        local include = not labelKey or record.label == labelKey
        if include and search then
            local found = record.name:lower():find(search, 1, true) ~= nil
            for _, note in ipairs(record.notes) do
                found = found or note.text:lower():find(search, 1, true) ~= nil
            end
            include = found
        end
        if include then
            list[#list + 1] = record
        end
    end

    local function LastActivity(record)
        local latest = GB.LatestNote(record)
        return latest and latest.t or record.added
    end
    table.sort(list, function(a, b)
        local timeA, timeB = LastActivity(a), LastActivity(b)
        if timeA ~= timeB then
            return timeA > timeB
        end
        return a.name < b.name
    end)
    return list
end

-- Redraws any open UI. Window.lua fills this in.
function GB:Refresh()
    if self.Window then
        self.Window:Refresh()
    end
end

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------

-- "<First Surname>: <note>", or without the colon, "<First Surname> <note>".
-- A first name on its own needs the colon, since otherwise the first word of
-- the note would be read as the surname.
function GB.SplitNameAndNote(text)
    text = text or ""
    local name, note = text:match("^%s*([^:]-)%s*:%s*(.-)%s*$")
    if name and name ~= "" then
        return name, note
    end
    name, note = text:match("^%s*(%S+%s+%S+)%s*(.-)%s*$")
    if name then
        return name, note
    end
    name = text:match("^%s*(%S+)%s*$")
    return name, ""
end

local function PrintRecord(record)
    local identity = GB.FormatIdentity(record)
    GB:Print(record.name .. (identity and (", " .. identity) or "") .. " (" .. GB.FormatLabel(record) .. "). "
        .. GB.FormatSeen(record) .. ".")
    if #record.notes == 0 then
        print("  " .. GB.COLORS.INFO .. "No notes.|r")
    end
    for _, note in ipairs(record.notes) do
        print("  " .. GB.COLORS.INFO .. GB.FormatNoteStamp(note) .. "|r " .. note.text)
    end
end

local function PrintHelp()
    GB:Print("Commands:")
    print("  /karmabook: open the notebook")
    print("  /karmabook add: add your target, or type a name in the form")
    print("  /karmabook add First Surname: note")
    print("  /karmabook find First Surname")
    print("  /karmabook options")
    print("  /karmabook sync: see what guild sharing sent and received")
    print("  /karmabook status: show whether chat is hidden from addons right now")
    print("  /karmabook debug: print the raw name of every chat sender (for testing)")
end

local function PrintStatus()
    local locked = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    if GB.Readable(locked) then
        GB:Print("Chat is hidden from addons here, so chat alerts can't fire.")
    else
        GB:Print("Chat is readable here. Chat alerts are working.")
    end
end

local function OnSlash(input)
    input = input or ""
    local command, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    if command == "" then
        GB.Window:Toggle()
    elseif command == "add" then
        if rest == "" then
            GB.Dialog:OpenForTarget()
            return
        end
        local name, note = GB.SplitNameAndNote(rest)
        local record, reason = GB:AddNote(name, note)
        if record then
            GB:Print("Saved " .. record.name .. ".")
        else
            GB:Print(GB.COLORS.ERROR .. reason .. "|r")
        end
    elseif command == "find" then
        local record = GB:Find(rest)
        if record then
            PrintRecord(record)
        else
            GB:Print(GB.COLORS.INFO .. "Nobody by that name on your list.|r")
        end
    elseif command == "options" then
        GB.Options:Open()
    elseif command == "sync" then
        GB.Options:OpenSync()
    elseif command == "status" then
        PrintStatus()
    elseif command == "debug" then
        GB.debug = not GB.debug
        GB:Print("Chat sender debug " .. (GB.debug and "on." or "off."))
    else
        PrintHelp()
    end
end

SLASH_KARMABOOK1 = "/karmabook"
SLASH_KARMABOOK2 = "/kbook"
SlashCmdList.KARMABOOK = OnSlash
