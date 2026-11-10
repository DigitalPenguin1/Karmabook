-- Karmabook - Hooks into the default UI
-- The note in unit tooltips, a marker on listed names in chat, and an item in
-- the right-click menu on players.

local GB = Karmabook
local Readable = GB.Readable

local Hooks = {}
GB.Hooks = Hooks

local TOOLTIP_NOTE_LENGTH = 120

local MENU_TAGS = {
    "MENU_UNIT_PLAYER",
    "MENU_UNIT_ENEMY_PLAYER",
    "MENU_UNIT_FRIEND",
    "MENU_UNIT_FRIEND_OFFLINE",
    "MENU_UNIT_PARTY",
    "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_TARGET",
    "MENU_UNIT_GUILD",
    "MENU_UNIT_GUILD_OFFLINE",
    "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
    "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
    "MENU_UNIT_CHAT_ROSTER",
}

local function OnTooltip(tooltip)
    if tooltip ~= GameTooltip or not GB.db.tooltip then
        return
    end
    pcall(function()
        local _, unit = tooltip:GetUnit()
        unit = Readable(unit)
        if not unit or not Readable(UnitIsPlayer(unit)) then
            return
        end
        local name = GB:UnitFullName(unit)
        local record = name and GB:Find(name, Readable(UnitGUID(unit)))
        if not record then
            return
        end
        tooltip:AddLine("Karmabook: " .. GB.FormatLabel(record), 1, 0.82, 0)
        local latest = GB.LatestNote(record)
        if latest then
            tooltip:AddLine(GB.Shorten(latest.text, TOOLTIP_NOTE_LENGTH), 1, 1, 1, true)
            tooltip:AddLine(GB.FormatNoteStamp(latest), 0.67, 0.67, 0.67, true)
        end
    end)
end

-- Marks the sender's name with a "!" in their label's color. Returning nil
-- leaves the name alone. After the event and name, Blizzard passes the chat
-- event's arguments, so sender is arg2 and the GUID is arg12.
local function MarkSenderName(_, decoratedName, _, sender, ...)
    if not GB.db or not GB.db.chatMarker then
        return nil
    end
    sender = Readable(sender)
    if not sender then
        return nil
    end
    local record = GB:Find(sender, Readable((select(10, ...))))
    if not record then
        return nil
    end
    local label = GB.LABELS[record.label] or GB.LABELS[GB.DEFAULT_LABEL]
    return label.color .. "!|r" .. decoratedName
end

-- The player a right-click menu is for, as a full name, plus their GUID
local function ContextPlayer(contextData)
    local guid = Readable(contextData.guid)
    local unit = Readable(contextData.unit)
    if unit then
        return GB:UnitFullName(unit), guid or Readable(UnitGUID(unit))
    end
    local name = Readable(contextData.name)
    local surname = Readable(contextData.surname)
    if name and surname and surname ~= "" and not name:find(" ", 1, true) then
        name = name .. " " .. surname
    end
    return name and GB.NormalizeName(name), guid
end

local function OnMenu(_, rootDescription, contextData)
    local ok, name, guid = pcall(ContextPlayer, contextData)
    if not ok or not name or GB:IsSelf(name) then
        return
    end
    local record = GB:Find(name, guid)
    rootDescription:CreateDivider()
    rootDescription:CreateTitle("Karmabook")
    rootDescription:CreateButton(record and "Add a note" or "Add to Karmabook", function()
        GB.Dialog:Open(name, guid)
    end)
end

function Hooks:Install()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltip)
    end
    if ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter then
        ChatFrameUtil.AddSenderNameFilter(MarkSenderName)
    end
    if Menu and Menu.ModifyMenu then
        for _, tag in ipairs(MENU_TAGS) do
            Menu.ModifyMenu(tag, OnMenu)
        end
    end
end
