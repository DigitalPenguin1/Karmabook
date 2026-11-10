-- Karmabook - Watching for listed players
-- Chat alerts use a plain event frame, not a chat filter. Filters only run for
-- chat tabs that show the channel and are skipped entirely when data is
-- secret, so a guild line in a hidden tab would be missed.

local GB = Karmabook
local Readable = GB.Readable

local Watch = {}
GB.Watch = Watch

-- group is the on/off switch in settings, label is how the alert names it
local CHAT_EVENTS = {
    CHAT_MSG_SAY = { group = "say", label = "Say" },
    CHAT_MSG_YELL = { group = "say", label = "Yell" },
    CHAT_MSG_EMOTE = { group = "emote", label = "Emote" },
    CHAT_MSG_TEXT_EMOTE = { group = "emote", label = "Emote" },
    CHAT_MSG_WHISPER = { group = "whisper", label = "Whisper" },
    CHAT_MSG_GUILD = { group = "guild", label = "Guild" },
    CHAT_MSG_OFFICER = { group = "guild", label = "Officer" },
    CHAT_MSG_PARTY = { group = "group", label = "Party" },
    CHAT_MSG_PARTY_LEADER = { group = "group", label = "Party" },
    CHAT_MSG_RAID = { group = "group", label = "Raid" },
    CHAT_MSG_RAID_LEADER = { group = "group", label = "Raid" },
    CHAT_MSG_RAID_WARNING = { group = "group", label = "Raid" },
    CHAT_MSG_INSTANCE_CHAT = { group = "group", label = "Instance" },
    CHAT_MSG_INSTANCE_CHAT_LEADER = { group = "group", label = "Instance" },
    CHAT_MSG_CHANNEL = { group = "channel", label = "Channel" },
}

-- Who's in the group right now, so joining alerts once and not on every
-- roster update
local groupMembers = {}

-- Prints what the game really sends for a sender, for checking name formats
-- on Forever. Runs only while /karmabook debug is on.
local function DebugSender(event, sender, sender2, guid)
    local function Show(value)
        if value == nil then
            return "nil"
        end
        return Readable(value) and tostring(value) or "<secret>"
    end
    local ambiguated = "<secret>"
    if Readable(sender) then
        ambiguated = Ambiguate(sender, "none")
    end
    local infoName, infoSecond = "nil", "nil"
    if Readable(guid) then
        local ok, _, _, _, _, _, name, second = pcall(GetPlayerInfoByGUID, guid)
        if ok then
            infoName, infoSecond = Show(name), Show(second)
        end
    end
    print(GB.COLORS.DEBUG .. event:sub(10) .. "|r arg2=[" .. Show(sender) .. "] arg5=[" .. Show(sender2)
        .. "] ambiguate=[" .. ambiguated .. "] guidInfo=[" .. infoName .. " / " .. infoSecond .. "]")
end

function Watch:OnChat(event, sender, sender2, channelBaseName, guid)
    if GB.debug then
        DebugSender(event, sender, sender2, guid)
    end

    -- During chat lockdown (dungeons, raids, PvP matches) the sender is
    -- secret, and there's nothing to match against
    sender = Readable(sender)
    if not sender then
        return
    end

    local record, firstNameOnly = GB:Find(sender, Readable(guid))
    if not record then
        return
    end

    local info = CHAT_EVENTS[event]
    local how = info.label
    if event == "CHAT_MSG_CHANNEL" then
        how = Readable(channelBaseName) or how
    end
    GB:MarkSeen(record, "Heard in " .. how, nil)
    GB:Refresh()

    if GB.db.watch[info.group] then
        GB:Alert(record, info.group == "whisper" and "whisper" or "chat", "in " .. how, firstNameOnly)
    end
end

-- The record for a unit if it's a listed player. Any of these unit queries
-- can come back secret, which reads as "not a listed player".
local function RecordForUnit(unit)
    local ok, record, firstNameOnly = pcall(function()
        local exists = UnitExists(unit)
        local isPlayer = UnitIsPlayer(unit)
        if not Readable(exists) or not Readable(isPlayer) then
            return nil
        end
        local name = GB:UnitFullName(unit)
        if not name then
            return nil
        end
        return GB:Find(name, Readable(UnitGUID(unit)))
    end)
    if ok then
        -- A first-name match could be someone else, so it teaches nothing
        if record and not firstNameOnly then
            GB:LearnIdentityFromUnit(record, unit)
        end
        return record, firstNameOnly
    end
    return nil
end

function Watch:CheckNearby(unit)
    local record, firstNameOnly = RecordForUnit(unit)
    if not record then
        return
    end
    GB:MarkSeen(record, "Seen", GB:CurrentZone())
    GB:Refresh()
    if GB.db.nearby then
        GB:Alert(record, "nearby", "is nearby", firstNameOnly)
    end
end

function Watch:CheckGroup()
    local current = {}
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end
    for i = 1, count do
        local record, firstNameOnly = RecordForUnit(prefix .. i)
        if record then
            current[record.name] = true
            if not groupMembers[record.name] then
                GB:MarkSeen(record, "In your group", GB:CurrentZone())
                GB:Refresh()
                if GB.db.groupWarnings then
                    GB:Alert(record, "group", "is in your group", firstNameOnly)
                end
            end
        end
    end
    groupMembers = current
end

-- Only warns. The invite stays on screen for you to accept or decline.
function Watch:OnInvite(name, guid)
    name = Readable(name)
    if not name or not GB.db.groupWarnings then
        return
    end
    local record, firstNameOnly = GB:Find(name, Readable(guid))
    if record then
        GB:Alert(record, "invite", "invited you to a group", firstNameOnly)
    end
end

function Watch:Start()
    local frame = CreateFrame("Frame")
    for event in pairs(CHAT_EVENTS) do
        frame:RegisterEvent(event)
    end
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PARTY_INVITE_REQUEST")

    frame:SetScript("OnEvent", function(_, event, ...)
        if CHAT_EVENTS[event] then
            local _, sender, _, _, sender2, _, _, _, channelBaseName, _, _, guid = ...
            Watch:OnChat(event, sender, sender2, channelBaseName, guid)
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            Watch:CheckNearby((...))
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            Watch:CheckNearby("mouseover")
        elseif event == "PLAYER_TARGET_CHANGED" then
            Watch:CheckNearby("target")
        elseif event == "GROUP_ROSTER_UPDATE" then
            Watch:CheckGroup()
        elseif event == "PARTY_INVITE_REQUEST" then
            local name, _, _, _, _, _, guid = ...
            Watch:OnInvite(name, guid)
        end
    end)
    self:CheckGroup()
end
