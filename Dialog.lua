-- Karmabook - Entry form
-- The one way a player gets on the list from the UI: you fill it in and
-- press Save. The same form edits an existing page.

local GB = Karmabook
local Theme = GB.Theme

local Dialog = {}
GB.Dialog = Dialog

local function UpdateLabelButton(frame)
    frame.labelButton:SetText(GB.LABELS[frame.label].ink .. GB.LABELS[frame.label].name .. "|r")
end

local NOT_SET = "|cff4a3418Not set|r"

local function UpdatePicker(button, value)
    button:SetText(value or NOT_SET)
end

-- Loads the pickers from a player's page, or empties them for a new one
local function FillIdentity(frame, record)
    frame.race, frame.startRace = record and record.race, record and record.race
    frame.class, frame.startClass = record and record.class, record and record.class
    UpdatePicker(frame.raceButton, frame.race)
    UpdatePicker(frame.classButton, frame.class)
end

-- Only what you actually changed is saved. A rename clears race and class
-- because it's a different character, and untouched pickers still showing the
-- old values mustn't put them back.
local function ApplyIdentity(frame, record)
    if frame.race ~= frame.startRace then
        record.race = frame.race
    end
    if frame.class ~= frame.startClass then
        record.class = frame.class
    end
end

local function SaveEdit(frame)
    local record = frame.editing
    local renamed, reason = GB:RenamePlayer(record, frame.nameInput:GetText())
    if not renamed then
        GB:Print(GB.COLORS.ERROR .. reason .. "|r")
        return
    end
    record.label = frame.label
    ApplyIdentity(frame, record)
    GB:SetLatestNote(record, frame.noteInput:GetText(), frame.whereInput:GetText())
    GB:Print("Updated " .. record.name .. ".")
    frame:Hide()
    GB.Window:Select(record)
end

local function Save(frame)
    if frame.editing then
        SaveEdit(frame)
        return
    end
    local record, reason = GB:AddNote(frame.nameInput:GetText(), frame.noteInput:GetText(), frame.label, frame.guid,
        frame.whereInput:GetText())
    if not record then
        GB:Print(GB.COLORS.ERROR .. reason .. "|r")
        return
    end
    ApplyIdentity(frame, record)
    GB:Print("Saved " .. record.name .. ".")
    frame:Hide()
    GB.Window:Select(record)
end

local function AddField(frame, text, y, width, maxLetters)
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(Theme.FONT_SMALL)
    label:SetPoint("TOPLEFT", 26, y)
    label:SetText(text)

    local input = Theme.CreateInput(frame, width, maxLetters)
    input:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    input:SetScript("OnEnterPressed", function()
        Save(frame)
    end)
    return input
end

-- A line you click to pick from a list. field is the form value it sets.
local function AddPicker(frame, text, x, y, options, field)
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(Theme.FONT_SMALL)
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)

    local function Pick(button, value)
        frame[field] = value
        UpdatePicker(button, value)
    end

    local button = Theme.CreateButton(frame, "", 150, function(self)
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateButton("Not set", function()
                Pick(self, nil)
            end)
            for _, option in ipairs(options) do
                root:CreateButton(option, function()
                    Pick(self, option)
                end)
            end
        end)
    end)
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)

    local line = button:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT", 0, 1)
    line:SetPoint("BOTTOMRIGHT", 0, 1)
    line:SetHeight(1)
    line:SetColorTexture(Theme.Color(Theme.INK, 0.8))
    return button
end

local function GetFrame()
    if Dialog.frame then
        return Dialog.frame
    end
    local frame = Theme.CreateWindow("KarmabookAddDialog", 420, 330)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.title:SetPoint("TOPLEFT", 26, -22)
    Theme.AddMargin(frame, 20)

    frame.nameInput = AddField(frame, "First and surname", -62, 230, 50)
    frame.raceButton = AddPicker(frame, "Race", 26, -112, GB.RACES, "race")
    frame.classButton = AddPicker(frame, "Class", 196, -112, GB.CLASSES, "class")
    frame.whereInput = AddField(frame, "Where you saw them", -162, 366, GB.ZONE_MAX)
    frame.noteInput = AddField(frame, "What happened?", -212, 366, GB.NOTE_MAX)

    frame.labelButton = Theme.CreateButton(frame, "", 120, function()
        local order = GB.LABEL_ORDER
        for index, key in ipairs(order) do
            if key == frame.label then
                frame.label = order[index % #order + 1]
                break
            end
        end
        UpdateLabelButton(frame)
    end)
    frame.labelButton:SetPoint("LEFT", frame.nameInput, "RIGHT", 10, 0)

    local save = Theme.CreateButton(frame, "Save", 90, function()
        Save(frame)
    end)
    save:SetPoint("BOTTOMRIGHT", -24, 18)

    local cancel = Theme.CreateButton(frame, "Cancel", 90, function()
        frame:Hide()
    end)
    cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)

    Dialog.frame = frame
    return frame
end

function Dialog:Open(name, guid)
    local frame = GetFrame()
    local record = name and GB:Find(name, guid)
    frame.editing = nil
    frame.title:SetText("A new entry")
    frame.guid = guid
    frame.label = record and record.label or GB.DEFAULT_LABEL
    frame.nameInput:SetText(record and record.name or name or "")
    frame.noteInput:SetText("")
    frame.whereInput:SetText(GB:CurrentZone() or "")
    FillIdentity(frame, record)
    UpdateLabelButton(frame)
    frame:Show()
    if name then
        frame.noteInput:SetFocus()
    else
        frame.nameInput:SetFocus()
    end
end

-- The form filled in from a page, with the newest note ready to change
function Dialog:OpenEdit(record)
    local frame = GetFrame()
    local latest = GB.LatestNote(record)
    frame.editing = record
    frame.title:SetText("Edit entry")
    frame.guid = nil
    frame.label = record.label
    frame.nameInput:SetText(record.name)
    frame.noteInput:SetText(latest and latest.text or "")
    -- A note with no location stays that way unless you type one
    if latest then
        frame.whereInput:SetText(latest.zone or "")
    else
        frame.whereInput:SetText(GB:CurrentZone() or "")
    end
    FillIdentity(frame, record)
    UpdateLabelButton(frame)
    frame:Show()
    frame.noteInput:SetFocus()
end

function Dialog:OpenForTarget()
    local name
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        name = GB:UnitFullName("target")
    end
    self:Open(name, name and GB.Readable(UnitGUID("target")) or nil)
end
