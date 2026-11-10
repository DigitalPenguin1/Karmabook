-- Karmabook - Settings page under ESC > Options > AddOns

local GB = Karmabook

local Options = {}
GB.Options = Options

local function AddHeader(layout, text)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function AddCheckbox(category, id, name, tooltip, getValue, setValue)
    local setting = Settings.RegisterProxySetting(category, "Karmabook_" .. id,
        Settings.VarType.Boolean, name, true, getValue, setValue)
    Settings.CreateCheckbox(category, setting, tooltip)
end

-- A row with a label on the left and a button on the right
local function AddButton(layout, label, buttonText, tooltip, onClick)
    if CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true))
    end
end

local function AddDBCheckbox(category, key, name, tooltip)
    AddCheckbox(category, key, name, tooltip,
        function() return GB.db[key] end,
        function(value) GB.db[key] = value end)
end

local function AddWatchCheckbox(category, key, name)
    AddCheckbox(category, "watch_" .. key, name, "Alert when a listed player talks here.",
        function() return GB.db.watch[key] end,
        function(value) GB.db.watch[key] = value end)
end

function Options:Register()
    if self.category or not (Settings and Settings.RegisterVerticalLayoutCategory) then
        return
    end
    local category, layout = Settings.RegisterVerticalLayoutCategory("Karmabook")

    AddButton(layout, "Karmabook " .. GB.VERSION, "About",
        "Who made Karmabook, how to support it, and where to report bugs.",
        function() Options:OpenAbout() end)

    AddHeader(layout, "Alerts")
    AddDBCheckbox(category, "alerts", "Enable alerts", "Master switch for every alert.")
    AddDBCheckbox(category, "banner", "Show the banner", "Show the player's name and your note on screen.")
    AddDBCheckbox(category, "sound", "Play a sound", "Play a sound with each alert.")
    AddDBCheckbox(category, "quietInCombat", "Quiet in combat",
        "While you're in combat, alerts appear only in chat.")
    AddDBCheckbox(category, "nearby", "Alert when nearby",
        "Alert when a listed player's nameplate appears, or you target or mouse over them. "
        .. "Same-faction players only have a nameplate if friendly nameplates are on.")
    AddDBCheckbox(category, "groupWarnings", "Warn about groups",
        "Alert when a listed player invites you or joins your group.")

    AddHeader(layout, "Chat to watch")
    AddWatchCheckbox(category, "guild", "Guild and officer")
    AddWatchCheckbox(category, "whisper", "Whispers")
    AddWatchCheckbox(category, "say", "Say and yell")
    AddWatchCheckbox(category, "emote", "Emotes")
    AddWatchCheckbox(category, "group", "Party, raid, and instance")
    AddWatchCheckbox(category, "channel", "Channels (General, Trade, LookingForGroup)")

    AddHeader(layout, "Guild sharing")
    AddDBCheckbox(category, "receiveShared", "Receive shared pages",
        "Collect pages guildmates share in the Guild tab. They never alert you until you add them to your book.")
    AddButton(layout, "Sharing history", "Sync log",
        "See every page you shared or got, anything ignored, and which guildmates have Karmabook.",
        function() Options:OpenSync() end)

    AddHeader(layout, "Display")
    AddDBCheckbox(category, "tooltip", "Show notes in tooltips", "Add your latest note to a listed player's tooltip.")
    AddDBCheckbox(category, "chatMarker", "Mark names in chat", "Put a colored ! on listed players' names in chat.")
    AddCheckbox(category, "showMinimap", "Minimap button", "Show the Karmabook button on the minimap.",
        function() return GB.db.showMinimap end,
        function(value) GB.MinimapButton:SetShown(value) end)

    Settings.RegisterAddOnCategory(category)
    self.category = category
    self:RegisterAbout(category)
    if Settings.RegisterCanvasLayoutSubcategory then
        self.syncCategory = Settings.RegisterCanvasLayoutSubcategory(category, GB.SyncLog:CreatePage(), "Sync")
    end
end

----------------------------------------------------------------------
-- About page
----------------------------------------------------------------------

local SUPPORT_URL = "https://buymeacoffee.com/relyk22"
local GITHUB_URL = "https://github.com/DigitalPenguin1/Karmabook"

-- WoW can't open links, so show them in a box the player can copy from.
-- Typing into it just puts the URL back.
local function CreateLinkBox(parent, url)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(320, 20)
    box:SetAutoFocus(false)
    box:SetText(url)
    box:SetCursorPosition(0)
    box:SetScript("OnTextChanged", function(b, userInput)
        if userInput then
            b:SetText(url)
            b:HighlightText()
        end
    end)
    box:SetScript("OnEditFocusGained", function(b)
        b:HighlightText()
    end)
    box:SetScript("OnEditFocusLost", function(b)
        b:HighlightText(0, 0)
    end)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box
end

local function AddText(parent, anchor, text, font, gap, r, g, b)
    local line = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 8))
    line:SetWidth(560)
    line:SetJustifyH("LEFT")
    line:SetText(text)
    if r then
        line:SetTextColor(r, g, b)
    end
    return line
end

function Options:RegisterAbout(category)
    if not Settings.RegisterCanvasLayoutSubcategory then
        return
    end

    local frame = CreateFrame("Frame")
    local Theme = GB.Theme

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Karmabook")
    title:SetTextColor(Theme.Color(Theme.GOLD_LIGHT))

    local version = AddText(frame, title, "Version: |cffffd100" .. GB.VERSION .. "|r", "GameFontHighlight", 12)
    local author = AddText(frame, version, "Developed by: |cff00ccffRelyk Rageroot|r", "GameFontHighlight", 4)

    local thanks = AddText(frame, author, "Thank you for using Karmabook!", "GameFontNormalLarge", 20)
    local about = AddText(frame, thanks,
        "A private notebook on the players you meet in WoW: Forever. Write down what someone did, and the next " ..
        "time they talk in chat or show up nearby, you get an alert with your note. Nothing is sent to anyone unless " ..
        "you pick Share on a page. " ..
        "Type /karmabook help in chat for every command.", "GameFontHighlight", 8)

    local support = AddText(frame, about, "If you enjoy this addon and want to support development:", "GameFontNormal", 20)
    local coffee = AddText(frame, support, "Buy me a coffee at:", "GameFontHighlight", 8, 0, 1, 0)
    local coffeeBox = CreateLinkBox(frame, SUPPORT_URL)
    coffeeBox:SetPoint("TOPLEFT", coffee, "BOTTOMLEFT", 6, -4)

    local bugs = AddText(frame, coffeeBox, "Found a bug or have an idea? Open an issue on GitHub:", "GameFontHighlight", 16)
    bugs:SetPoint("TOPLEFT", coffeeBox, "BOTTOMLEFT", -6, -16)
    local githubBox = CreateLinkBox(frame, GITHUB_URL)
    githubBox:SetPoint("TOPLEFT", bugs, "BOTTOMLEFT", 6, -4)

    AddText(frame, githubBox, "Click a link and press Ctrl+C to copy it.", "GameFontDisableSmall", 8)
        :SetPoint("TOPLEFT", githubBox, "BOTTOMLEFT", -6, -8)

    self.aboutCategory = Settings.RegisterCanvasLayoutSubcategory(category, frame, "About")
end

-- The notebook draws above the settings panel, so it closes first
local function OpenTo(category)
    if not category then
        return
    end
    if InCombatLockdown() then
        GB:Print(GB.COLORS.ERROR .. "Settings can't open in combat.|r")
        return
    end
    GB.Window:Hide()
    Settings.OpenToCategory(category:GetID())
end

function Options:Open()
    OpenTo(self.category)
end

function Options:OpenAbout()
    OpenTo(self.aboutCategory or self.category)
end

function Options:OpenSync()
    OpenTo(self.syncCategory or self.category)
end
