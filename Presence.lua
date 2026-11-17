-- Karmabook - Who's online
-- Works out whether a player in the book is online, for the dot by their
-- name. Guild roster, friends list, group, and recent sightings update by
-- themselves. Everyone else needs a /who, and the game only lets an addon
-- send one straight after a click, so selecting a name runs one quietly.

local GB = Karmabook
local Readable = GB.Readable

local Presence = {}
GB.Presence = Presence

-- Heard in chat or seen nearby this recently counts as online
local SEEN_ONLINE = 5 * 60
-- How long a /who answer stays on the dot before it goes back to unknown
local WHO_KEEP = 10 * 60
-- Don't ask again about someone checked this recently
local WHO_RECHECK = 2 * 60
-- The server drops /who searches sent closer together than this
local WHO_GAP = 6
-- Give up on an answer that hasn't come back by then. A throttled search
-- never answers at all.
local WHO_WAIT = 6
local ROSTER_EVERY = 60

-- name key -> true/false, rebuilt on each roster update
local guild, friends, group = {}, {}, {}
-- name key -> { online = bool, t = time() }
local whoResults = {}
local pending -- { key, record, t } for the /who we're waiting on
local lastWhoSent = 0
-- name key -> time() of the last /who sent for them, answered or not, so
-- Check online moves down the list even when the server stays quiet
local lastTried = {}
local hideWhoChatUntil = 0

local function KeyOf(name)
    local normalized = name and GB.NormalizeName(name)
    return normalized and normalized:lower()
end

-- Names from the game can come with or without a surname, so this matches
-- the same way chat alerts do
local function Matches(foundName, record)
    local key, wanted = KeyOf(foundName), KeyOf(record.name)
    if not key or not wanted then
        return false
    end
    return key == wanted
        or key:match("^(%S+) %S") == wanted
        or wanted:match("^(%S+) %S") == key
end

-- Returns "online", "offline", "other" for the other faction (which /who
-- can't see), or nil for unknown, and where that came from
function Presence:Get(record)
    local key = KeyOf(record.name)
    if not key then
        return nil
    end
    if guild[key] or friends[key] or group[key] then
        return "online", guild[key] and "guild" or friends[key] and "friends" or "group"
    end
    local seen = record.seen
    if seen and time() - seen.t < SEEN_ONLINE then
        return "online", "seen"
    end
    if GB:IsOtherFaction(record) then
        return "other", "faction"
    end
    local who = whoResults[key]
    if who and time() - who.t < WHO_KEEP then
        return who.online and "online" or "offline", "who"
    end
    if guild[key] == false then
        return "offline", "guild"
    end
    if friends[key] == false then
        return "offline", "friends"
    end
    if group[key] == false then
        return "offline", "group"
    end
    return nil
end

local SOURCE_TEXT = {
    guild = "guild roster",
    friends = "friends list",
    group = "your group",
    seen = "seen just now",
    who = "/who",
}

function Presence:Describe(record)
    local status, source = self:Get(record)
    if not status then
        return "|cff6b5a3eOnline status unknown|r"
    end
    if status == "other" then
        return "|cff6b5a3e" .. GB.FactionOf(record) .. ", so /who can't see them|r"
    end
    if status == "offline" and source == "who" and not GB.FactionOf(record) then
        return "|cffa52a1aNot found by /who|r (offline, or on the other faction)"
    end
    local text = status == "online" and "|cff2e7d32Online|r" or "|cffa52a1aOffline|r"
    return text .. " (" .. SOURCE_TEXT[source] .. ")"
end

local function ScanGuild()
    wipe(guild)
    if not IsInGuild() then
        return
    end
    for index = 1, GetNumGuildMembers() do
        local ok, name, _, _, level, _, _, _, _, online = pcall(GetGuildRosterInfo, index)
        name = ok and Readable(name) or nil
        local key = KeyOf(name)
        if key then
            guild[key] = Readable(online) and true or false
            local record = GB.db.players[key]
            GB:LearnSameFaction(record)
            GB:SetLevel(record, level)
        end
    end
end

local function ScanFriends()
    wipe(friends)
    if not (C_FriendList and C_FriendList.GetNumFriends) then
        return
    end
    for index = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(index)
        local key = info and KeyOf(Readable(info.name))
        if key then
            friends[key] = Readable(info.connected) and true or false
            GB:LearnSameFaction(GB.db.players[key])
        end
    end
end

local function ScanGroup()
    wipe(group)
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end
    for index = 1, count do
        local unit = prefix .. index
        local ok, name, connected = pcall(function()
            return GB:UnitFullName(unit), Readable(UnitIsConnected(unit))
        end)
        local key = ok and KeyOf(name)
        if key then
            group[key] = connected and true or false
        end
    end
end

local function RequestRosters()
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
    if C_FriendList and C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end
end

----------------------------------------------------------------------
-- /who after a click
----------------------------------------------------------------------

-- First name only: the status line under the list has room for one short line
local function Short(record)
    return record.name:match("^(%S+)") or record.name
end

-- Sends one /who for record. Only call this from a click handler: from
-- anywhere else the game blocks SendWho and blames Karmabook. force skips
-- the "checked a minute ago" rule, for when you asked about this one name.
-- Returns true, or false and a reason to show.
function Presence:Check(record, force)
    if not record or not record.name or GB:IsSelf(record.name) then
        return false, "That's you"
    end
    local key = KeyOf(record.name)
    local status = key and self:Get(record)
    if not key then
        return false, "Can't search that name"
    end
    if status == "other" then
        return false, "Other faction, /who can't see"
    end
    if status == "online" and not force then
        return false, Short(record) .. ": already online"
    end
    local who = whoResults[key]
    if not force and who and time() - who.t < WHO_RECHECK then
        return false, Short(record) .. ": checked just now"
    end
    if pending then
        return false, "Still waiting..."
    end
    local wait = math.ceil(WHO_GAP - (GetTime() - lastWhoSent))
    if wait > 0 then
        return false, "Wait " .. wait .. "s"
    end
    if not (C_FriendList and C_FriendList.SendWho) then
        return false, "/who isn't available"
    end

    -- Search by first name: it finds the player whether or not /who shows
    -- surnames, and Matches sorts out who's who
    local firstName = record.name:match("^(%S+)")
    if not pcall(C_FriendList.SendWho, 'n-"' .. firstName .. '"') then
        return false, "Blocked by the game"
    end
    local now = GetTime()
    lastWhoSent = now
    hideWhoChatUntil = now + WHO_WAIT
    pending = { key = key, record = record, t = now }
    lastTried[key] = time()
    self.checking = record
    C_Timer.After(WHO_WAIT, function()
        if pending and pending.t == now then
            pending = nil
            Presence.checking = nil
            Presence.lastNote = Short(record) .. ": no answer, try again"
            GB:Refresh()
        end
    end)
    return true
end

-- Quiet version for selecting a row: no complaints if it can't go
function Presence:CheckOnClick(record)
    self:Check(record, false)
end

-- The same-faction player who most needs a /who: never checked first, then
-- the longest ago. Skips anyone a roster or sighting already accounts for.
local function NextToCheck(records)
    local best, bestTime, left = nil, nil, 0
    local now = time()
    for _, record in ipairs(records) do
        local key = KeyOf(record.name)
        local status, source = Presence:Get(record)
        local who = key and whoResults[key]
        -- Online by guild, friends, group, or a sighting needs no /who
        local accountedFor = status == "online" and source ~= "who"
        local checkedAt = math.max(who and who.t or 0, key and lastTried[key] or 0)
        local due = key and not GB:IsSelf(record.name) and status ~= "other" and not accountedFor
            and now - checkedAt >= WHO_RECHECK
        if due then
            left = left + 1
            if not best or checkedAt < bestTime then
                best, bestTime = record, checkedAt
            end
        end
    end
    return best, left
end

-- One press of the Check online button. Returns true, or false and a reason.
function Presence:CheckNext(records)
    local record, left = NextToCheck(records)
    if not record then
        return false, "Everyone's checked"
    end
    local sent, reason = self:Check(record, false)
    if not sent then
        return false, reason
    end
    self.lastNote = "Checking " .. Short(record) .. "... " .. (left - 1) .. " left"
    return true
end

local function Finish(online)
    local record, key, found = pending.record, pending.key, pending.foundInfo
    pending = nil
    if online then
        GB:LearnSameFaction(record)
        if found then
            GB:LearnFromWho(record, found.level, found.race, found.class)
        end
    end
    whoResults[key] = { online = online, t = time() }
    Presence.checking = nil
    Presence.lastNote = Short(record) .. (online and ": online" or ": not found")
    -- The chat lines can trail the event a little
    hideWhoChatUntil = GetTime() + 1
    GB:Refresh()
end

-- When the results go to the Who window, this event carries them
local function OnWhoResults()
    if not pending then
        return
    end
    local online = pending.found or false
    for index = 1, C_FriendList.GetNumWhoResults() do
        local info = C_FriendList.GetWhoInfo(index)
        if info and Matches(Readable(info.fullName), pending.record) then
            online = true
            pending.foundInfo = {
                level = info.level,
                race = Readable(info.raceStr),
                class = Readable(info.classStr),
            }
            break
        end
    end
    Finish(online)
end

-- The game prints small /who results in chat. Ours are background checks,
-- so hide those lines, and only while one of ours is out.
local whoCountPattern
local function WhoCountPattern()
    if not whoCountPattern and WHO_NUM_RESULTS then
        whoCountPattern = "^" .. WHO_NUM_RESULTS
            :gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
            :gsub("|4[^;]*;", ".-")
            :gsub("%%d", "%%d+")
            .. "$"
    end
    return whoCountPattern
end

local function HideWhoChat(_, _, message)
    if GetTime() > hideWhoChatUntil then
        return false
    end
    message = Readable(message)
    if not message then
        return false
    end
    -- Small results come as chat lines, and some clients send no event
    -- with them, so read the answer from the lines themselves: one line per
    -- player found, then the "N players total" line
    if message:find("^|Hplayer:") then
        if pending then
            local linkName = message:match("^|Hplayer:([^|:]+)")
            local shownName = message:match("|h%[(.-)%]|h")
            if Matches(linkName, pending.record) or Matches(shownName, pending.record) then
                pending.found = true
                -- "[Name]: Level 42 Orc Warrior - Zone": the first number
                -- after the name is the level. Race and class are left to
                -- the event, since their wording changes by language.
                pending.foundInfo = pending.foundInfo
                    or { level = tonumber(message:match("|h.-(%d+)")) }
            end
        end
        return true
    end
    local pattern = WhoCountPattern()
    if pattern and message:find(pattern) then
        if pending then
            Finish(pending.found or false)
        end
        return true
    end
    return false
end

function Presence:Start()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:RegisterEvent("FRIENDLIST_UPDATE")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("UNIT_CONNECTION")
    frame:RegisterEvent("WHO_LIST_UPDATE")
    frame:SetScript("OnEvent", function(_, event)
        if event == "GUILD_ROSTER_UPDATE" then
            ScanGuild()
        elseif event == "FRIENDLIST_UPDATE" then
            ScanFriends()
        elseif event == "WHO_LIST_UPDATE" then
            OnWhoResults()
            return
        else
            ScanGroup()
        end
        GB:Refresh()
    end)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", HideWhoChat)

    ScanGuild()
    ScanFriends()
    ScanGroup()
    RequestRosters()
    C_Timer.NewTicker(ROSTER_EVERY, RequestRosters)
    -- Sightings and /who answers age out, so the dots need redrawing
    -- even when nothing new comes in
    C_Timer.NewTicker(30, function()
        GB:Refresh()
    end)
end
