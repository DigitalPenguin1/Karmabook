-- Karmabook - Sharing with the guild, or out loud in Say
-- Nothing goes out unless you pick Share on a page, and only that page's
-- newest note is sent. What arrives waits in the Guild tab and can't
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

-- The game's limit on one chat line
local SAY_MAX = 255

-- Seconds between answers to "who has Karmabook?"
local ANSWER_COOLDOWN = 30
local VERSION_MAX = 16

local partial = {}
local lastShared = {}
local lastSaid = {}
local nextMessageID = 0
local lastAnswered
local ignoredFrom = {}

local function Log(text)
    GB.SyncLog:Add(text)
end
local Who = function(name) return GB.SyncLog.Who(name) end

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
local function SharePage(record)
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
    GB.db.lastShareSent = time()
    GB:Refresh()
    return true
end

function Share:SharePage(record)
    local shared, reason = SharePage(record)
    if shared then
        Log("Shared your page on " .. Who(record.name) .. " with the guild")
    else
        Log("Didn't share " .. Who(record.name) .. ": " .. reason)
    end
    return shared, reason
end

-- The line Say would post: name, race and class if known, and the newest note
function Share:SayLine(record)
    local latest = GB.LatestNote(record)
    if not latest then
        return nil
    end
    local who = record.name
    local identity = GB.FormatIdentity(record)
    if identity then
        who = who .. " (" .. identity .. ")"
    end
    local line = who .. ": " .. latest.text:gsub("%s+", " ")
    if #line > SAY_MAX then
        line = GB.CleanText(line, SAY_MAX - 3) .. "..."
    end
    return line
end

-- Says the page out loud, for everyone nearby to read. Returns true, or false
-- and a reason to show the player.
function Share:SayPage(record)
    local line = self:SayLine(record)
    if not line then
        return false, "Write a note on this page first."
    end
    local now = GetTime()
    if lastSaid[record.name] and now - lastSaid[record.name] < SHARE_COOLDOWN then
        return false, "You just said this page. Give it a minute."
    end
    if not pcall(SendChatMessage, line, "SAY") then
        return false, "The game wouldn't let the addon talk here."
    end
    lastSaid[record.name] = now
    return true
end

-- Asks online guildmates with Karmabook to say so
function Share:SendHello()
    if not IsInGuild() then
        return false, "You aren't in a guild."
    end
    return SendGuild(table.concat({ PROTOCOL, "H" }, SEP))
end

function Share:Unshare(record)
    local sent, reason = SendGuild(table.concat({ PROTOCOL, "U", Field(record.name) }, SEP))
    if not sent then
        Log("Couldn't unshare " .. Who(record.name) .. ": " .. reason)
        return false, reason
    end
    Log("Unshared your page on " .. Who(record.name))
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
    if not name or text == "" then
        Log("Ignored a page from " .. Who(sender) .. " that couldn't be read")
        return
    end
    -- Pages about you are dropped without a word, the same as before
    if GB:IsSelf(name) then
        return
    end

    -- A note can't claim to be from the future
    local stamp = tonumber(fields[5])
    if not stamp or stamp > time() then
        stamp = time()
    end
    if AlreadyInBook(name, sender, stamp) then
        Log(Who(sender) .. " shared " .. Who(name) .. " again. That note is already in your book.")
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
    GB.db.lastShareReceived = time()
    Log((isNew and "Got a page on " or "Got an updated page on ") .. Who(name) .. " from " .. Who(sender))
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
            Log("A page from " .. Who(pending.sender) .. " arrived in pieces and some never came, so it was dropped")
        end
    end

    local key = sender .. ":" .. id
    local pending = partial[key]
    if not pending or pending.total ~= total then
        pending = { total = total, parts = {}, count = 0, started = now, sender = sender }
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
        Log(Who(sender) .. " took back their page on " .. Who(name))
        GB:Refresh()
    end
end

local function Answer()
    local now = GetTime()
    if lastAnswered and now - lastAnswered < ANSWER_COOLDOWN then
        return
    end
    lastAnswered = now
    -- A short random wait so a whole guild doesn't answer in the same instant
    C_Timer.After(math.random() * 3, function()
        SendGuild(table.concat({ PROTOCOL, "V", Field(GB.VERSION), GB.db.receiveShared and "on" or "off" }, SEP))
    end)
end

function Share:OnAddonMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" then
        return
    end
    text, sender = Readable(text), Readable(sender)
    sender = sender and GB.NormalizeName(sender)
    if not text or not sender or GB:IsSelf(sender) then
        return
    end

    if text == PROTOCOL .. "~H" then
        Answer()
        return
    end
    local version, receiving = text:match("^" .. PROTOCOL .. "~V~([^~]*)~(%a+)$")
    if version then
        version = GB.CleanText(version, VERSION_MAX)
        GB.SyncLog:OnAnswer(sender, version ~= "" and version or "?", receiving == "on")
        return
    end

    if not GB.db.receiveShared then
        -- One line per guildmate per session, not one per message
        if text:match("^" .. PROTOCOL .. "~P~") and not ignoredFrom[sender] then
            ignoredFrom[sender] = true
            Log("Ignored a page from " .. Who(sender) .. " because Receive shared pages is off")
        end
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
    Log("Dismissed " .. Who(entry.from) .. "'s page on " .. Who(entry.name))
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
    Log("Added " .. Who(entry.from) .. "'s page on " .. Who(entry.name) .. " to your book")
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
