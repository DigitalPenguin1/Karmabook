-- Karmabook - The notebook
-- The left page lists players, filtered by the divider tabs on the right edge.
-- The right page is one player's history, or a plain note on the Notes tab.

local GB = Karmabook
local Theme = GB.Theme

local Window = {}
GB.Window = Window

local WIDTH, HEIGHT = 720, 490
local ROW_HEIGHT = 22

-- Left page
local LIST_LEFT = 44
local LIST_TOP = -90
local LIST_BOTTOM = 30
local LIST_WIDTH = 270
local LIST_ROWS = math.ceil((HEIGHT + LIST_TOP - LIST_BOTTOM) / ROW_HEIGHT) + 1

-- Right page
local PAGE_LEFT = 396
local PAGE_TOP = -24
local PAGE_RIGHT = -44
local PAGE_BOTTOM = 24
local HISTORY_TOP = -92
local HISTORY_BOTTOM = 66
local PAGE_WIDTH = WIDTH - PAGE_LEFT + PAGE_RIGHT
local HISTORY_WIDTH = PAGE_WIDTH - 22
local HISTORY_HEIGHT = HEIGHT + PAGE_TOP - PAGE_BOTTOM + HISTORY_TOP - HISTORY_BOTTOM
local LINE_SPACING = 6

local FADED = "|cff4a3418"

local EMPTY_HINT = "Pick a name from the left page, or start a new page.\n\n"
    .. "You can also right-click a name in chat or on a portrait to add them.\n\n"
    .. "Right-click a name in this book to edit it."
local GUILD_HINT = "Pages your guildmates share show up here.\n\n"
    .. "They never alert you until you add them to your book."
local MISC_HINT = "Plain notes that aren't about anyone. Press New page to start one.\n\n"
    .. "These never alert you and are never shared."

-- Where the writing area sits on a plain note
local MISC_TOP, MISC_BOTTOM = -66, 34
local MISC_VIEW_HEIGHT = HEIGHT + PAGE_TOP - PAGE_BOTTOM + MISC_TOP - MISC_BOTTOM

local HELP_TOP = -34
local HELP_BOTTOM = 32
local HELP_WIDTH = PAGE_WIDTH - 22
local HELP_HEIGHT = HEIGHT + PAGE_TOP - PAGE_BOTTOM + HELP_TOP - HELP_BOTTOM

local function HelpSection(title, body)
    return FADED .. title .. "|r\n" .. body
end

local HELP_TEXT = table.concat({
    HelpSection("Adding someone",
        "Right-click their name in chat or on a portrait, or press New page."),
    HelpSection("Editing a page",
        "Right-click a name in this book."),
    HelpSection("Alerts",
        "You get a sound and a banner with your note when a listed player talks or shows up nearby. "
        .. "Chat alerts can't fire in dungeons, raids, or PvP matches."),
    HelpSection("Dividers",
        "The tabs on the right show one label at a time."),
    HelpSection("Sharing",
        "Share on a page sends its newest note. Guild sends it quietly to guildmates who are online and have "
        .. "Karmabook. Pages they share wait in the Guild tab and never alert you until you add them to your book. "
        .. "Say posts it in plain chat, where anyone nearby can read it, including the player it's about."),
    HelpSection("Notes",
        "Plain notes that aren't about a player. They save when you leave the page, and never alert or get shared."),
    HelpSection("Commands",
        "/karmabook - open the notebook\n"
        .. "/karmabook add - add your target\n"
        .. "/karmabook add First Surname: note\n"
        .. "/karmabook find First Surname\n"
        .. "/karmabook options - open settings\n"
        .. "/karmabook status - can chat alerts work here?"),
}, "\n\n")

-- Index tabs down the right edge. The open tab sticks out further.
local TAB_WIDTH = 36
local TAB_ACTIVE_WIDTH = 46
local TAB_HEIGHT = 60
local TAB_TOP = -22
local TAB_GAP = 4

-- How far each tab starts underneath the cover
local TAB_TUCK = 6

-- Rotated text turns around a point that isn't its middle, so it needs this
-- nudge to land in the center of the tab
local TAB_TEXT_X, TAB_TEXT_Y = 7, -6

-- One divider per label, plus All. label is nil on All. The dye matches the
-- label's ink color, lightened so dark text reads on it.
local TABS = {
    { text = "All", dye = { 0.86, 0.76, 0.56 } },
    { text = "Grudges", label = "GRUDGE", dye = { 0.84, 0.58, 0.32 } },
    { text = "KOS", title = "Kill on Sight", label = "KOS", dye = { 0.80, 0.42, 0.34 } },
    { text = "Caution", label = "CAUTION", dye = { 0.86, 0.72, 0.34 } },
    { text = "Good", label = "GOOD", dye = { 0.58, 0.72, 0.44 } },
    { text = "Guild", title = "From your guild", guild = true, dye = { 0.62, 0.72, 0.86 } },
    { text = "Notes", title = "Notes", misc = true, dye = { 0.74, 0.68, 0.80 } },
}

----------------------------------------------------------------------
-- Pieces
----------------------------------------------------------------------

-- Saves whatever is on the open note. Called whenever you might be
-- leaving it, because buttons don't take keyboard focus from the text.
local function CommitMisc(frame)
    if frame.miscOpen then
        frame.miscNote = GB:SaveMiscNote(frame.miscNote, frame.miscTitle:GetText(), frame.miscBody:GetText())
    end
end

local function CloseMisc(frame)
    frame.miscOpen, frame.miscNote = nil, nil
    frame.miscTitle:ClearFocus()
    frame.miscBody:ClearFocus()
end

local function GetRow(frame, index)
    local row = frame.rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, frame.listContent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    row.selected = row:CreateTexture(nil, "BORDER")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(Theme.Color(Theme.GOLD, 0.3))

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(Theme.Color(Theme.INK, 0.1))

    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetFontObject(Theme.FONT_SMALL)
    row.count:SetPoint("RIGHT", -6, 0)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(Theme.FONT_BODY)
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, mouseButton)
        if self.isShared then
            Window:SelectShared(self.record)
            return
        end
        if self.isMisc then
            Window:OpenMisc(self.record)
            return
        end
        Window:Select(self.record)
        if mouseButton == "RightButton" then
            GB.Dialog:OpenEdit(self.record)
        end
    end)
    frame.rows[index] = row
    return row
end

-- The template only hides its bar when the scroll range changes, so a short
-- list would keep showing one from the moment it opens
local function UpdateScrollBar(scroll, contentHeight, viewHeight)
    if scroll.ScrollBar then
        scroll.ScrollBar:SetShown(contentHeight > viewHeight)
    end
end

-- A scroll area with no box around it, so the page shows through. The
-- scroll bar only appears when there's something to scroll.
local function CreatePageScroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll.scrollBarHideable = true
    if scroll.ScrollBar then
        scroll.ScrollBar:SetAlpha(0.75)
    end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    return scroll, content
end

-- A thin line along one edge of a tab, for light on top and shadow below
local function AddTabEdge(tab, point1, point2, horizontal, r, g, b, a)
    local edge = tab:CreateTexture(nil, "BORDER")
    edge:SetPoint(point1)
    edge:SetPoint(point2)
    if horizontal then
        edge:SetHeight(1)
    else
        edge:SetWidth(1)
    end
    edge:SetColorTexture(r, g, b, a)
end

-- The shadow the cover casts on the tab where it comes out
local function AddTabCoverShadow(tab)
    local shadow = tab:CreateTexture(nil, "BORDER")
    shadow:SetPoint("TOPLEFT", TAB_TUCK, 0)
    shadow:SetPoint("BOTTOMLEFT", TAB_TUCK, 0)
    shadow:SetWidth(12)
    shadow:SetColorTexture(1, 1, 1)
    shadow:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.5), CreateColor(0, 0, 0, 0))
end

local function CreateIndexTab(frame, info, index)
    local tab = CreateFrame("Button", nil, frame)
    tab.info = info
    tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", -TAB_TUCK, TAB_TOP - (index - 1) * (TAB_HEIGHT + TAB_GAP))

    -- Below the book, so the tab comes out from behind the cover
    tab:SetFrameLevel(frame:GetFrameLevel() - 1)

    Theme.AddDyedPaper(tab, info.dye)
    AddTabEdge(tab, "TOPLEFT", "TOPRIGHT", true, 1, 1, 1, 0.3)
    AddTabEdge(tab, "BOTTOMLEFT", "BOTTOMRIGHT", true, 0.1, 0.05, 0.02, 0.55)
    AddTabEdge(tab, "TOPRIGHT", "BOTTOMRIGHT", false, 0.1, 0.05, 0.02, 0.55)
    AddTabCoverShadow(tab)

    -- Closed tabs sit in the shade of the open one, in brown rather than
    -- black so the dye doesn't turn gray
    tab.shade = tab:CreateTexture(nil, "ARTWORK")
    tab.shade:SetAllPoints()
    tab.shade:SetColorTexture(Theme.Color(Theme.LEATHER, 0.3))

    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(Theme.Color(Theme.INK, 0.1))

    -- Reads top to bottom, like the label on a divider
    local label = tab:CreateFontString(nil, "OVERLAY")
    tab.label = label
    label:SetFontObject(Theme.FONT_TAB)
    label:SetPoint("CENTER", TAB_TEXT_X, TAB_TEXT_Y)
    label:SetText(info.text)
    label:SetRotation(-math.pi / 2)

    tab:SetScript("OnClick", function()
        CommitMisc(frame)
        CloseMisc(frame)
        frame.activeTab = tab
        frame.showHelp = false
        frame.sharedEntry = nil
        if info.guild or info.misc then
            frame.record = nil
        end
        Window:Refresh()
    end)
    return tab
end

local function NoteHistory(record)
    if #record.notes == 0 then
        return FADED .. "Nothing written yet.|r"
    end
    local lines = {}
    for index = #record.notes, 1, -1 do
        local note = record.notes[index]
        lines[#lines + 1] = FADED .. GB.FormatNoteStamp(note) .. "|r\n" .. note.text
    end
    return table.concat(lines, "\n\n")
end

local function AddNoteFromInput(frame)
    if not frame.record then
        return
    end
    local text = frame.noteInput:GetText()
    if GB.CleanText(text) == "" then
        return
    end
    GB:AddNote(frame.record.name, text)
    frame.noteInput:SetText("")
    frame.noteInput:ClearFocus()
end

local function CreateRightPage(frame)
    local details = CreateFrame("Frame", nil, frame)
    details:SetPoint("TOPLEFT", PAGE_LEFT, PAGE_TOP)
    details:SetPoint("BOTTOMRIGHT", PAGE_RIGHT, PAGE_BOTTOM)
    frame.details = details

    details.name = details:CreateFontString(nil, "OVERLAY")
    details.name:SetFontObject(Theme.FONT_HEADING)
    details.name:SetPoint("TOPLEFT")
    details.name:SetWidth(PAGE_WIDTH - 20)
    details.name:SetJustifyH("LEFT")

    -- Font strings can't be clicked, so this sits over the heading
    details.nameHit = CreateFrame("Button", nil, details)
    details.nameHit:SetPoint("TOPLEFT")
    details.nameHit:SetSize(PAGE_WIDTH - 20, 22)
    details.nameHit:RegisterForClicks("RightButtonUp")
    details.nameHit:SetScript("OnClick", function()
        GB.Dialog:OpenEdit(frame.record)
    end)

    details.identity = details:CreateFontString(nil, "OVERLAY")
    details.identity:SetFontObject(Theme.FONT_BODY)
    details.identity:SetPoint("TOPLEFT", details.name, "BOTTOMLEFT", 0, -4)
    details.identity:SetWidth(PAGE_WIDTH - 125)
    details.identity:SetJustifyH("LEFT")

    details.seen = details:CreateFontString(nil, "OVERLAY")
    details.seen:SetFontObject(Theme.FONT_SMALL)
    details.seen:SetPoint("TOPLEFT", details.identity, "BOTTOMLEFT", 0, -3)
    details.seen:SetWidth(PAGE_WIDTH)
    details.seen:SetJustifyH("LEFT")

    -- Guild goes only to guildmates with Karmabook. Say is plain chat that
    -- anyone nearby can read, the player you wrote about included.
    details.share = Theme.CreateButton(details, "Share", 120, function(self)
        local record = frame.record
        MenuUtil.CreateContextMenu(self, function(_, root)
            if record.shared then
                root:CreateButton("Unshare from guild", function()
                    local unshared, reason = GB.Share:Unshare(record)
                    if not unshared then
                        GB:Print(GB.COLORS.ERROR .. reason .. "|r")
                    end
                end)
            else
                root:CreateButton("Guild (Karmabook users)", function()
                    StaticPopup_Show("KARMABOOK_SHARE", record.name, nil, record)
                end)
            end
            root:CreateButton("Say (everyone nearby)", function()
                local line = GB.Share:SayLine(record)
                if line then
                    StaticPopup_Show("KARMABOOK_SAY", line, nil, record)
                else
                    GB:Print(GB.COLORS.ERROR .. "Write a note on this page first.|r")
                end
            end)
        end)
    end)
    details.share:SetPoint("TOPRIGHT", 0, -22)

    details.label = Theme.CreateButton(details, "", 130, function()
        GB:CycleLabel(frame.record)
    end)
    details.label:SetPoint("TOPLEFT", 0, -64)

    details.mute = Theme.CreateButton(details, "", 110, function()
        GB:SetMuted(frame.record, not frame.record.muted)
    end)
    details.mute:SetPoint("LEFT", details.label, "RIGHT", 8, 0)

    local scroll, content = CreatePageScroll(details)
    scroll:SetPoint("TOPLEFT", 0, HISTORY_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -22, HISTORY_BOTTOM)
    details.historyScroll = scroll
    details.historyContent = content
    content:SetWidth(HISTORY_WIDTH)

    details.history = content:CreateFontString(nil, "OVERLAY")
    details.history:SetFontObject(Theme.FONT_BODY)
    details.history:SetPoint("TOPLEFT", 2, -2)
    details.history:SetWidth(HISTORY_WIDTH - 6)
    details.history:SetJustifyH("LEFT")
    details.history:SetJustifyV("TOP")
    details.history:SetSpacing(LINE_SPACING)

    details.undo = Theme.CreateButton(details, "Scratch out last entry", 170, function()
        GB:RemoveLatestNote(frame.record)
    end)
    details.undo:SetPoint("BOTTOMLEFT")

    local tear = Theme.CreateButton(details, "Tear out page", 100, function()
        StaticPopup_Show("KARMABOOK_DELETE", frame.record.name, nil, frame.record)
    end)
    tear:SetPoint("BOTTOMRIGHT")

    frame.noteInput = Theme.CreateInput(details, 216, GB.NOTE_MAX)
    frame.noteInput:SetPoint("BOTTOMLEFT", 0, 30)
    frame.noteInput:SetScript("OnEnterPressed", function()
        AddNoteFromInput(frame)
    end)

    local write = Theme.CreateButton(details, "Write", 54, function()
        AddNoteFromInput(frame)
    end)
    write:SetPoint("BOTTOMRIGHT", 0, 30)
end

-- A page a guildmate shared, shown read-only until you decide what to do
local function CreateIncomingPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", PAGE_LEFT, PAGE_TOP)
    page:SetPoint("BOTTOMRIGHT", PAGE_RIGHT, PAGE_BOTTOM)
    page:Hide()
    frame.incoming = page

    local function AddLine(font, anchor, gap)
        local line = page:CreateFontString(nil, "OVERLAY")
        line:SetFontObject(font)
        line:SetWidth(PAGE_WIDTH)
        line:SetJustifyH("LEFT")
        if anchor then
            line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
        else
            line:SetPoint("TOPLEFT")
        end
        return line
    end

    page.name = AddLine(Theme.FONT_HEADING)
    page.identity = AddLine(Theme.FONT_BODY, page.name, 4)
    page.from = AddLine(Theme.FONT_SMALL, page.identity, 3)
    page.stamp = AddLine(Theme.FONT_SMALL, page.from, 18)
    page.note = AddLine(Theme.FONT_BODY, page.stamp, 6)

    local add = Theme.CreateButton(page, "Add to my book", 130, function()
        local record, reason = GB.Share:AddToBook(frame.sharedEntry)
        if record then
            GB:Print("Added " .. record.name .. " to your book.")
        else
            GB:Print(GB.COLORS.ERROR .. reason .. "|r")
        end
    end)
    add:SetPoint("BOTTOMLEFT")

    local dismiss = Theme.CreateButton(page, "Dismiss", 80, function()
        GB.Share:Dismiss(frame.sharedEntry)
    end)
    dismiss:SetPoint("BOTTOMRIGHT")
end

-- One plain note. The boxes are only filled when a note opens, because the
-- window redraws on outside events and mustn't wipe what you're typing.
local function CreateMiscPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", PAGE_LEFT, PAGE_TOP)
    page:SetPoint("BOTTOMRIGHT", PAGE_RIGHT, PAGE_BOTTOM)
    page:Hide()
    frame.miscPage = page

    local function Commit()
        CommitMisc(frame)
    end

    local titleLabel = page:CreateFontString(nil, "OVERLAY")
    titleLabel:SetFontObject(Theme.FONT_SMALL)
    titleLabel:SetPoint("TOPLEFT")
    titleLabel:SetText("Title")

    local title = Theme.CreateInput(page, PAGE_WIDTH, GB.MISC_TITLE_MAX)
    title:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -2)
    title:SetScript("OnEditFocusLost", Commit)
    frame.miscTitle = title

    page.stamp = page:CreateFontString(nil, "OVERLAY")
    page.stamp:SetFontObject(Theme.FONT_SMALL)
    page.stamp:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll.scrollBarHideable = true
    scroll:SetPoint("TOPLEFT", 0, MISC_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -22, MISC_BOTTOM)
    page.scroll = scroll

    local body = CreateFrame("EditBox", nil, scroll)
    body:SetMultiLine(true)
    body:SetWidth(PAGE_WIDTH - 22)
    body:SetFontObject(Theme.FONT_BODY)
    body:SetAutoFocus(false)
    body:SetMaxLetters(GB.MISC_TEXT_MAX)
    body:SetScript("OnEscapePressed", body.ClearFocus)
    body:SetScript("OnEditFocusLost", Commit)
    body:SetScript("OnTextChanged", function(self)
        UpdateScrollBar(scroll, self:GetHeight(), MISC_VIEW_HEIGHT)
    end)
    -- Keeps the line you're typing on in view
    body:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
        local line, top = -y, scroll:GetVerticalScroll()
        if line < top then
            scroll:SetVerticalScroll(line)
        elseif line + cursorHeight > top + MISC_VIEW_HEIGHT then
            scroll:SetVerticalScroll(line + cursorHeight - MISC_VIEW_HEIGHT)
        end
    end)
    scroll:SetScrollChild(body)
    frame.miscBody = body

    -- The box is only as tall as its text, so clicks below it need help
    scroll:SetScript("OnMouseDown", function()
        body:SetFocus()
    end)

    local function FocusBody()
        body:SetFocus()
    end
    title:SetScript("OnEnterPressed", FocusBody)
    title:SetScript("OnTabPressed", FocusBody)

    page.save = Theme.CreateButton(page, "Save", 70, Commit)
    page.save:SetPoint("BOTTOMLEFT")

    page.tear = Theme.CreateButton(page, "Tear out page", 100, function()
        if frame.miscNote then
            StaticPopup_Show("KARMABOOK_DELETE_MISC", frame.miscNote.title, nil, frame.miscNote)
        else
            CloseMisc(frame)
            Window:Refresh()
        end
    end)
    page.tear:SetPoint("BOTTOMRIGHT")
end

local function CreateHelpPage(frame)
    local help = CreateFrame("Frame", nil, frame)
    help:SetPoint("TOPLEFT", PAGE_LEFT, PAGE_TOP)
    help:SetPoint("BOTTOMRIGHT", PAGE_RIGHT, PAGE_BOTTOM)
    help:Hide()
    frame.help = help

    local title = help:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(Theme.FONT_HEADING)
    title:SetPoint("TOPLEFT")
    title:SetText("Help")

    local scroll, content = CreatePageScroll(help)
    scroll:SetPoint("TOPLEFT", 0, HELP_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -22, HELP_BOTTOM)
    content:SetWidth(HELP_WIDTH)
    help.scroll = scroll
    help.content = content

    help.text = content:CreateFontString(nil, "OVERLAY")
    help.text:SetFontObject(Theme.FONT_BODY)
    help.text:SetPoint("TOPLEFT", 2, -2)
    help.text:SetWidth(HELP_WIDTH - 6)
    help.text:SetJustifyH("LEFT")
    help.text:SetJustifyV("TOP")
    help.text:SetText(HELP_TEXT)

    local about = Theme.CreateButton(help, "About Karmabook", 140, function()
        GB.Options:OpenAbout()
    end)
    about:SetPoint("BOTTOMLEFT")
end

local function CreateFrames()
    local frame = Theme.CreateWindow("KarmabookWindow", WIDTH, HEIGHT, true)
    frame:SetFrameLevel(10)
    frame.title:SetPoint("TOP", frame, "TOPLEFT", (WIDTH / 2 + LIST_LEFT) / 2, -24)
    frame.rows = {}

    Theme.AddMargin(frame, LIST_LEFT - 6)
    Theme.AddMargin(frame, PAGE_LEFT - 6)

    frame.tabs = {}
    for index, info in ipairs(TABS) do
        frame.tabs[index] = CreateIndexTab(frame, info, index)
    end
    frame.activeTab = frame.tabs[1]

    local searchLabel = frame:CreateFontString(nil, "OVERLAY")
    searchLabel:SetFontObject(Theme.FONT_SMALL)
    searchLabel:SetPoint("TOPLEFT", LIST_LEFT, -66)
    searchLabel:SetText("Search")

    local search = Theme.CreateInput(frame, 130, 50)
    search:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    search:SetScript("OnTextChanged", function()
        Window:Refresh()
    end)
    frame.search = search

    local newPage = Theme.CreateButton(frame, "New page", 80, function()
        if frame.activeTab.info.misc then
            Window:OpenMisc(nil)
        else
            GB.Dialog:OpenForTarget()
        end
    end)
    newPage:SetPoint("LEFT", search, "RIGHT", 10, 0)
    frame.newPage = newPage

    local scroll, content = CreatePageScroll(frame)
    scroll:SetPoint("TOPLEFT", LIST_LEFT, LIST_TOP)
    scroll:SetPoint("BOTTOMLEFT", LIST_LEFT, LIST_BOTTOM)
    scroll:SetWidth(LIST_WIDTH)
    frame.listScroll = scroll
    frame.listContent = content
    content:SetWidth(LIST_WIDTH)

    frame.empty = frame:CreateFontString(nil, "OVERLAY")
    frame.empty:SetFontObject(Theme.FONT_FAINT)
    frame.empty:SetPoint("TOPLEFT", PAGE_LEFT, -40)
    frame.empty:SetWidth(PAGE_WIDTH)
    frame.empty:SetJustifyH("LEFT")

    CreateRightPage(frame)
    CreateHelpPage(frame)
    CreateIncomingPage(frame)
    CreateMiscPage(frame)

    -- Sits in the corner, left of the red margin
    local helpButton = Theme.CreateButton(frame, "?", 24, function()
        Window:ToggleHelp()
    end)
    helpButton:SetNormalFontObject(Theme.FONT_HEADING)
    helpButton:SetHighlightFontObject(Theme.FONT_HEADING)
    helpButton:SetPoint("BOTTOMLEFT", 13, 13)
    frame.helpButton = helpButton

    frame:SetScript("OnShow", function()
        Window:Refresh()
    end)
    frame:SetScript("OnHide", function()
        CommitMisc(frame)
    end)
    return frame
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------

local function RefreshRightPage(frame)
    local record = frame.record
    local details = frame.details
    local entry = not frame.showHelp and frame.sharedEntry or nil
    frame.help:SetShown(frame.showHelp == true)
    frame.incoming:SetShown(entry ~= nil)
    local miscOpen = frame.miscOpen and not frame.showHelp
    local tabInfo = frame.activeTab.info
    frame.miscPage:SetShown(miscOpen == true)
    details:SetShown(record ~= nil and not frame.showHelp and not entry and not miscOpen)
    frame.empty:SetShown(record == nil and not frame.showHelp and not entry and not miscOpen)
    frame.empty:SetText(tabInfo.guild and GUILD_HINT or tabInfo.misc and MISC_HINT or EMPTY_HINT)
    if miscOpen then
        local note = frame.miscNote
        frame.miscPage.stamp:SetText(note and ("Last changed " .. GB.Ago(note.updated)) or "Not saved yet")
        return
    end
    if entry then
        local incoming, note = frame.incoming, entry.notes[1]
        incoming.name:SetText(GB.InkColor(entry) .. entry.name .. "|r")
        incoming.identity:SetText(GB.FormatIdentity(entry) or (FADED .. "Race and class not known|r"))
        incoming.from:SetText("Shared by " .. entry.from .. ", " .. GB.Ago(entry.received))
        incoming.stamp:SetText(GB.FormatNoteStamp(note))
        incoming.note:SetText(note.text)
        return
    end
    if frame.showHelp then
        local height = frame.help.text:GetStringHeight() + 6
        frame.help.content:SetHeight(height)
        UpdateScrollBar(frame.help.scroll, height, HELP_HEIGHT)
        return
    end
    if not record then
        return
    end

    GB:LearnIdentity(record, record.guid)
    details.name:SetText(record.name)
    details.identity:SetText(GB.FormatIdentity(record) or (FADED .. "Race and class not seen yet|r"))
    details.seen:SetText(GB.FormatSeen(record))
    details.label:SetText(GB.FormatLabelInk(record))
    details.mute:SetText(record.muted and "Unmute alerts" or "Mute alerts")
    details.undo:SetEnabled(#record.notes > 0)

    local history, content = details.history, details.historyContent
    history:SetText(NoteHistory(record))
    local height, lines = history:GetStringHeight(), history:GetNumLines()
    content:SetHeight(height + 6)
    UpdateScrollBar(details.historyScroll, height + 6, HISTORY_HEIGHT)

    -- Measured so the rules sit under the text at any font size
    local pitch = (height + LINE_SPACING) / math.max(lines, 1)
    local count = math.max(lines, math.ceil(HISTORY_HEIGHT / pitch))
    Theme.DrawRules(content, pitch, count, 4 - LINE_SPACING)
end

local function RefreshTabs(frame)
    for _, tab in ipairs(frame.tabs) do
        local active = tab == frame.activeTab
        tab:SetWidth(active and TAB_ACTIVE_WIDTH or TAB_WIDTH)
        tab.shade:SetShown(not active)
        if tab.info.guild then
            local count = GB.Share:Count()
            tab.label:SetText(count > 0 and ("Guild " .. count) or "Guild")
        end
    end
end

function Window:Refresh()
    local frame = self.frame
    if not frame or not frame:IsShown() then
        return
    end

    local tabInfo = frame.activeTab.info
    frame.title:SetText(tabInfo.title or (tabInfo.label and tabInfo.text) or "Karmabook")
    RefreshTabs(frame)

    local searchText = frame.search:GetText()
    local list
    if tabInfo.guild then
        list = GB.Share:GetEntries(searchText)
    elseif tabInfo.misc then
        list = GB:GetMiscNotes(searchText)
    else
        list = GB:GetSorted(tabInfo.label, searchText)
    end
    for index, record in ipairs(list) do
        local row = GetRow(frame, index)
        row.record = record
        row.name:SetText(tabInfo.misc and record.title or (GB.InkColor(record) .. record.name .. "|r"))
        row.isShared = tabInfo.guild
        row.isMisc = tabInfo.misc
        row.count:SetText((tabInfo.guild or tabInfo.misc) and "" or #record.notes)
        row.selected:SetShown(record == frame.record or record == frame.sharedEntry or record == frame.miscNote)
        row:Show()
    end
    for index = #list + 1, #frame.rows do
        frame.rows[index]:Hide()
    end
    frame.listContent:SetHeight(math.max(1, #list * ROW_HEIGHT))
    UpdateScrollBar(frame.listScroll, #list * ROW_HEIGHT, HEIGHT + LIST_TOP - LIST_BOTTOM)
    Theme.DrawRules(frame.listContent, ROW_HEIGHT, math.max(#list, LIST_ROWS), 0)

    -- The selected player may just have been torn out
    if frame.record and not GB.db.players[frame.record.name:lower()] then
        frame.record = nil
    end
    if frame.sharedEntry and not GB.db.shared[frame.sharedEntry.key] then
        frame.sharedEntry = nil
    end
    RefreshRightPage(frame)
end

function Window:Show()
    if not self.frame then
        self.frame = CreateFrames()
    end
    self.frame:Show()
end

function Window:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Show()
    end
end

function Window:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Window:Select(record)
    self:Show()
    CommitMisc(self.frame)
    CloseMisc(self.frame)
    self.frame.showHelp = false
    self.frame.sharedEntry = nil
    self.frame.record = record
    self:Refresh()
end

-- Opens a saved plain note, or a blank page when note is nil
function Window:OpenMisc(note)
    self:Show()
    local frame = self.frame
    CommitMisc(frame)
    frame.showHelp = false
    frame.sharedEntry = nil
    frame.record = nil
    frame.miscOpen = true
    frame.miscNote = note
    frame.miscTitle:SetText(note and note.title or "")
    frame.miscBody:SetText(note and note.text or "")
    frame.miscPage.scroll:SetVerticalScroll(0)
    self:Refresh()
    if not note then
        frame.miscTitle:SetFocus()
    end
end

function Window:SelectShared(entry)
    self:Show()
    self.frame.showHelp = false
    self.frame.record = nil
    self.frame.sharedEntry = entry
    self:Refresh()
end

-- Click ? again, or pick a name, to go back to the player's page
function Window:ToggleHelp()
    self:Show()
    CommitMisc(self.frame)
    self.frame.showHelp = not self.frame.showHelp
    self:Refresh()
end

StaticPopupDialogs.KARMABOOK_SHARE = {
    text = "Share your newest note on %s with every online guildmate who has Karmabook?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, record)
        local shared, reason = GB.Share:SharePage(record)
        if shared then
            GB:Print("Shared " .. record.name .. " with your guild.")
        else
            GB:Print(GB.COLORS.ERROR .. reason .. "|r")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs.KARMABOOK_DELETE_MISC = {
    text = "Tear out the note \"%s\"? It will be gone.",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(_, note)
        CloseMisc(Window.frame)
        GB:DeleteMiscNote(note)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs.KARMABOOK_SAY = {
    text = "Say this out loud? Everyone nearby will see it, including them.\n\n%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, record)
        local said, reason = GB.Share:SayPage(record)
        if not said then
            GB:Print(GB.COLORS.ERROR .. reason .. "|r")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs.KARMABOOK_DELETE = {
    text = "Tear out the page for %s? All of your notes on them will be gone.",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(_, record)
        GB:DeletePlayer(record)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
