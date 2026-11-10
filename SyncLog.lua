-- Karmabook - Sync log
-- A record of guild sharing for the Sync page in settings: pages you shared
-- or took back, pages guildmates sent you, and anything that was ignored and
-- why. Check guild asks which online guildmates run Karmabook, so you can
-- tell whether a share has anyone to reach.

local GB = Karmabook

local SyncLog = {}
GB.SyncLog = SyncLog

local MAX_ENTRIES = 100

-- Check guild can be pressed once this often, and answers are collected for
-- this long before the total is written
local CHECK_COOLDOWN = 30
local CHECK_WAIT = 10

local WHITE = "|cffffffff"

function SyncLog.Who(name)
    return WHITE .. tostring(name) .. "|r"
end

local function FormatEntry(entry)
    return GB.COLORS.INFO .. date("%m/%d %H:%M", entry.time) .. "|r  " .. entry.text
end

function SyncLog:Add(text)
    local log = GB.db.syncLog
    log[#log + 1] = { time = time(), text = text }
    while #log > MAX_ENTRIES do
        table.remove(log, 1)
    end
    if self.messages then
        self.messages:AddMessage(FormatEntry(log[#log]))
    end
    self:UpdateSummary()
end

function SyncLog:Clear()
    wipe(GB.db.syncLog)
    if self.messages then
        self.messages:Clear()
    end
end

----------------------------------------------------------------------
-- Who has Karmabook
----------------------------------------------------------------------

function SyncLog:CheckGuild()
    if not IsInGuild() then
        self:Add("You aren't in a guild, so there's no one to check.")
        return
    end
    local now = GetTime()
    if self.checkStarted and now - self.checkStarted < CHECK_COOLDOWN then
        self:Add("Already checking. Give guildmates a few seconds to answer.")
        return
    end
    local sent, reason = GB.Share:SendHello()
    if not sent then
        self:Add("Couldn't ask the guild: " .. reason)
        return
    end
    self.checkStarted = now
    self.answers = {}
    self:Add("Asked online guildmates who has Karmabook...")
    C_Timer.After(CHECK_WAIT, function()
        SyncLog:FinishCheck()
    end)
end

-- Answers only count while a check is running
function SyncLog:OnAnswer(sender, version, receiving)
    if not self.answers or self.answers[sender] then
        return
    end
    self.answers[sender] = true
    local text = SyncLog.Who(sender) .. " has Karmabook " .. version
    if not receiving then
        text = text .. ", but has Receive shared pages turned off"
    end
    self:Add(text)
end

function SyncLog:FinishCheck()
    if not self.answers then
        return
    end
    local count = 0
    for _ in pairs(self.answers) do
        count = count + 1
    end
    self.answers = nil
    if count == 0 then
        self:Add("Nobody answered. No one else online has this version of Karmabook, " ..
            "so pages you share won't reach anyone yet.")
    else
        self:Add(count .. (count == 1 and " guildmate" or " guildmates") ..
            " online can get the pages you share.")
    end
end

----------------------------------------------------------------------
-- Settings page
----------------------------------------------------------------------

local function TimeAgo(stamp)
    if not stamp then
        return "never"
    end
    local seconds = math.max(0, time() - stamp)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m ago"
    elseif seconds < 86400 then
        return math.floor(seconds / 3600) .. "h ago"
    end
    return math.floor(seconds / 86400) .. "d ago"
end

function SyncLog:SummaryText()
    local sharedByYou = 0
    for _, record in pairs(GB.db.players) do
        if record.shared then
            sharedByYou = sharedByYou + 1
        end
    end
    return "Pages you've shared: " .. WHITE .. sharedByYou .. "|r     Waiting in your Guild tab: " ..
        WHITE .. GB.Share:Count() .. "|r\n" ..
        "Last page you shared: " .. WHITE .. TimeAgo(GB.db.lastShareSent) .. "|r     " ..
        "Last page you got: " .. WHITE .. TimeAgo(GB.db.lastShareReceived) .. "|r\n" ..
        "Receive shared pages: " .. WHITE .. (GB.db.receiveShared and "on" or "off") .. "|r"
end

function SyncLog:UpdateSummary()
    if self.summary then
        self.summary:SetText(self:SummaryText())
    end
end

local function Button(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

function SyncLog:CreatePage()
    local frame = CreateFrame("Frame")
    local Theme = GB.Theme

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Sync")
    title:SetTextColor(Theme.Color(Theme.GOLD_LIGHT))

    local about = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    about:SetWidth(560)
    about:SetJustifyH("LEFT")
    about:SetText("Everything sent or received through guild sharing is listed here, with anything that was " ..
        "ignored and why. Shared pages only reach guildmates who are online and running Karmabook. " ..
        "Check guild shows who that is right now.")

    self.summary = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.summary:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -14)
    self.summary:SetJustifyH("LEFT")
    self.summary:SetSpacing(4)

    local check = Button(frame, "Check guild", 120, function()
        SyncLog:CheckGuild()
    end)
    check:SetPoint("TOPLEFT", self.summary, "BOTTOMLEFT", 0, -14)

    local clear = Button(frame, "Clear log", 100, function()
        SyncLog:Clear()
    end)
    clear:SetPoint("LEFT", check, "RIGHT", 8, 0)

    local box = CreateFrame("Frame", nil, frame)
    box:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -12)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    local shade = box:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.45)

    local messages = CreateFrame("ScrollingMessageFrame", nil, box)
    messages:SetPoint("TOPLEFT", 10, -10)
    -- Extra room at the bottom so the newest line isn't cut off
    messages:SetPoint("BOTTOMRIGHT", -10, 16)
    messages:SetFontObject("GameFontHighlightSmall")
    messages:SetJustifyH("LEFT")
    messages:SetFading(false)
    messages:SetMaxLines(MAX_ENTRIES)
    messages:SetInsertMode("BOTTOM")
    messages:EnableMouseWheel(true)
    messages:SetScript("OnMouseWheel", function(f, delta)
        if delta > 0 then
            f:ScrollUp()
        else
            f:ScrollDown()
        end
    end)
    self.messages = messages

    frame:SetScript("OnShow", function()
        messages:Clear()
        for _, entry in ipairs(GB.db.syncLog) do
            messages:AddMessage(FormatEntry(entry))
        end
        if #GB.db.syncLog == 0 then
            messages:AddMessage(GB.COLORS.INFO .. "Nothing yet. Share a page or press Check guild.|r")
        end
        SyncLog:UpdateSummary()
    end)

    return frame
end
