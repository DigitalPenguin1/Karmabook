-- Karmabook - Sharing with the guild
-- Nothing goes out unless you press Share with guild on a page, and only that
-- page's newest note is sent. What arrives waits in the Guild tab and can't
-- raise an alert until you add it to your own book.
--
-- Everything received was typed by another player, so every field is cleaned
-- and checked before it's kept or shown.

local GB = Karmabook
local Readable = GB.Readable

local Share = {}
GB.Share = Share

local PREFIX = "Karmabook"
local PROTOCOL = "1"
local SEP = "~"

local CHUNK_SIZE = 220
local MAX_PARTS = 4
local MAX_STORED = 200
local ZONE_MAX = 60
local IDENTITY_MAX = 24

-- Seconds before the same page can be shared again
local SHARE_COOLDOWN = 60

-- Seconds to wait for the rest of a page that arrived in pieces
local ASSEMBLY_TIMEOUT = 30

local partial = {}
local lastShared = {}
local nextMessageID = 0

----------------------------------------------------------------------
-- Sending
----------------------------------------------------------------------

local function SendGuild(text)
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false, "The game is blocking addon messages here."
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "GUILD")
    if not ok then
        return false, "The message couldn't be sent."
    end
    if result == nil or result == true then
        return true
    end
    if Enum.SendAddonMessageResult and result == Enum.SendAddonMessageResult.Success then
        return true
    end
    return false, "The game refused the message. Try again in a moment."
end

local function Field(value)
    return (tostring(value or ""):gsub(SEP, "-"))
end

-- Cuts text into pieces without splitting a multi-byte character
local function SplitChunks(text)
    local chunks = {}
    local start = 1
    while start <= #text do
        local stop = math.min(start + CHUNK_SIZE - 1, #text)
        while stop < #text and text:byte(stop + 1) >= 128 and text:byte(stop + 1) < 192 do
            stop = stop - 1
        end
        chunks[#chunks + 1] = text:sub(start, stop)
        start = stop + 1
    end
    return chunks
end

local function IsGuildmate(name)
    local wanted = GB.NormalizeName(name):lower()
    for index = 1, GetNumGuildMembers() do
        local ok, memberName = pcall(GetGuildRosterInfo, index)
        memberName = ok and Readable(memberName) or nil
        local normalized = memberName and GB.NormalizeName(memberName)
        if normalized and normalized:lower() == wanted then
            return true
        end
    end
    return false
end

-- Returns true, or false and a reason to show the player
function Share:SharePage(record)
    if not IsInGuild() then
        return false, "You aren't in a guild."
    end
    local latest = GB.LatestNote(record)
    if not latest then
        return false, "Write a note on this page first."
    end
    if IsGuildmate(record.name) then
        return false, record.name .. " is in your guild, so this page wasn't shared."
    end
    local now = GetTime()
    if lastShared[record.name] and now - lastShared[record.name] < SHARE_COOLDOWN then
        return false, "You just shared this page. Give it a minute."
    end

    local payload = table.concat({
        Field(record.name), Field(record.label), Field(record.race), Field(record.class),
        Field(latest.t), Field(latest.zone), Field(latest.text),
    }, SEP)
    local chunks = SplitChunks(payload)
    if #chunks > MAX_PARTS then
        return false, "That note is too long to share."
    end

    nextMessageID = nextMessageID % 9999 + 1
    for part, chunk in ipairs(chunks) do
        local sent, reason = SendGuild(table.concat({ PROTOCOL, "P", nextMessageID, part, #chunks, chunk }, SEP))
        if not sent then
            return false, reason
        end
    end
    lastShared[record.name] = now
    record.shared = true
    GB:Refresh()
    return true
end

function Share:Unshare(record)
    local sent, reason = SendGuild(table.concat({ PROTOCOL, "U", Field(record.name) }, SEP))
    if not sent then
        return false, reason
    end
    record.shared = nil
    GB:Refresh()
    return true
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------

local function SplitFields(text)
    local fields = {}
    local start = 1
    while true do
        local stop = text:find(SEP, start, true)
        if not stop then
            fields[#fields + 1] = text:sub(start)
            return fields
        end
        fields[#fields + 1] = text:sub(start, stop - 1)
        start = stop + 1
    end
end

local function OrNil(text)
    return text ~= "" and text or nil
end

local function EntryKey(name, sender)
    return (name .. "@" .. sender):lower()
end

local function TrimStored()
    local count, oldestKey, oldestTime = 0, nil, nil
    for key, entry in pairs(GB.db.shared) do
        count = count + 1
        if not oldestTime or entry.received < oldestTime then
            oldestKey, oldestTime = key, entry.received
        end
    end
    if count > MAX_STORED then
        GB.db.shared[oldestKey] = nil
    end
end

local function AlreadyInBook(name, sender, stamp)
    local record = GB.db.players[name:lower()]
    if record then
        for _, note in ipairs(record.notes) do
            if note.from == sender and note.t == stamp then
                return true
            end
        end
    end
    return false
end

local function OnPage(sender, payload)
    local fields = SplitFields(payload)
    local name = GB.NormalizeName(fields[1])
    local text = GB.CleanText(fields[7], GB.NOTE_MAX)
    if not name or text == "" or GB:IsSelf(name) then
        return
    end

    -- A note can't claim to be from the future
    local stamp = tonumber(fields[5])
    if not stamp or stamp > time() then
        stamp = time()
    end
    if AlreadyInBook(name, sender, stamp) then
        return
    end

    local key = EntryKey(name, sender)
    local isNew = GB.db.shared[key] == nil
    GB.db.shared[key] = {
        key = key,
        name = name,
        from = sender,
        received = time(),
        label = GB.LABELS[fields[2]] and fields[2] or GB.DEFAULT_LABEL,
        race = OrNil(GB.CleanText(fields[3], IDENTITY_MAX)),
        class = OrNil(GB.CleanText(fields[4], IDENTITY_MAX)),
        notes = { {
            t = stamp,
            text = text,
            zone = OrNil(GB.CleanText(fields[6], ZONE_MAX)),
            from = sender,
        } },
    }
    TrimStored()
    if isNew then
        GB:Print(sender .. " shared a page on " .. name .. ". It's in the Guild tab of /karmabook.")
    end
    GB:Refresh()
end

local function OnPart(sender, id, part, total, chunk)
    part, total = tonumber(part), tonumber(total)
    if not part or not total or total < 1 or total > MAX_PARTS or part < 1 or part > total
        or #chunk > CHUNK_SIZE then
        return
    end

    local now = GetTime()
    for key, pending in pairs(partial) do
        if now - pending.started > ASSEMBLY_TIMEOUT then
            partial[key] = nil
        end
    end

    local key = sender .. ":" .. id
    local pending = partial[key]
    if not pending or pending.total ~= total then
        pending = { total = total, parts = {}, count = 0, started = now }
        partial[key] = pending
    end
    if not pending.parts[part] then
        pending.count = pending.count + 1
    end
    pending.parts[part] = chunk

    if pending.count == total then
        partial[key] = nil
        OnPage(sender, table.concat(pending.parts))
    end
end

-- The game vouches for who sent a guild addon message, so only the person who
-- shared a page can take it back
local function OnUnshare(sender, nameField)
    local name = GB.NormalizeName(nameField)
    if name and GB.db.shared[EntryKey(name, sender)] then
        GB.db.shared[EntryKey(name, sender)] = nil
        GB:Refresh()
    end
end

function Share:OnAddonMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or not GB.db.receiveShared then
        return
    end
    text, sender = Readable(text), Readable(sender)
    sender = sender and GB.NormalizeName(sender)
    if not text or not sender or GB:IsSelf(sender) then
        return
    end

    local id, part, total, chunk = text:match("^" .. PROTOCOL .. "~P~(%d+)~(%d+)~(%d+)~(.*)$")
    if id then
        OnPart(sender, id, part, total, chunk)
        return
    end
    local nameField = text:match("^" .. PROTOCOL .. "~U~(.*)$")
    if nameField then
        OnUnshare(sender, nameField)
    end
end

----------------------------------------------------------------------
-- The Guild tab
----------------------------------------------------------------------

function Share:GetEntries(search)
    local list = {}
    search = search and search ~= "" and search:lower() or nil
    for _, entry in pairs(GB.db.shared) do
        local haystack = (entry.name .. " " .. entry.notes[1].text .. " " .. entry.from):lower()
        if not search or haystack:find(search, 1, true) then
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b)
        if a.received ~= b.received then
            return a.received > b.received
        end
        return a.key < b.key
    end)
    return list
end

function Share:Count()
    local count = 0
    for _ in pairs(GB.db.shared) do
        count = count + 1
    end
    return count
end

function Share:Dismiss(entry)
    GB.db.shared[entry.key] = nil
    GB:Refresh()
end

-- Copies a shared page into your own book, where it can start alerting. If
-- you already have a page on them, it's added as a note and your label stays.
function Share:AddToBook(entry)
    local existing = GB.db.players[entry.name:lower()]
    local record, reason = GB:AddNote(entry.name, "", not existing and entry.label or nil)
    if not record then
        return nil, reason
    end
    GB:InsertDatedNote(record, entry.notes[1])
    record.race = record.race or entry.race
    record.class = record.class or entry.class
    GB.db.shared[entry.key] = nil
    GB:Refresh()
    return record
end

function Share:Start()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, ...)
        Share:OnAddonMessage(...)
    end)
    -- The roster check needs this loaded before the first share
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
end
