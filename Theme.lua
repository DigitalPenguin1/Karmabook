-- Karmabook - Notebook look
-- Leather cover, spellbook pages, ruled lines, and ink. All of it is built
-- from Blizzard's own art and fonts, so there are no libraries or image files
-- to ship. A plain paper color sits under each page in case a texture is ever
-- removed from the game.

local GB = Karmabook

local Theme = {}
GB.Theme = Theme

Theme.GOLD = { 0.66, 0.50, 0.19, 1 }
Theme.GOLD_LIGHT = { 0.82, 0.66, 0.31, 1 }
Theme.LEATHER = { 0.24, 0.13, 0.07 }
Theme.PAPER = { 0.88, 0.80, 0.62 }
Theme.PAPER_WASH = { 0.97, 0.92, 0.80, 0.5 }
Theme.INK = { 0.07, 0.04, 0.02 }
Theme.INK_FAINT = { 0.24, 0.17, 0.09 }
Theme.RULE = { 0.16, 0.24, 0.42, 0.5 }
Theme.MARGIN = { 0.66, 0.10, 0.08, 0.7 }

-- Spellbook-Page-2 is a sprite sheet that smears when stretched, so both
-- pages use Page-1, with the right one mirrored. The crop removes its teal
-- ribbon on the outer edge and the dark rim along the top and bottom.
local PAGE_ART = "Interface\\Spellbook\\Spellbook-Page-1"
local CROP_OUTER, CROP_TOP, CROP_BOTTOM = 0.12, 0.03, 0.945

-- How far the pages sit inside the leather cover
local COVER = 10
Theme.COVER = COVER

local COVER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function Theme.Color(color, alpha)
    return color[1], color[2], color[3], alpha or color[4] or 1
end

----------------------------------------------------------------------
-- Fonts
----------------------------------------------------------------------

local function MakeFont(name, base, size, color)
    local font = CreateFont(name)
    font:CopyFontObject(base)
    if size then
        local path, _, flags = font:GetFont()
        font:SetFont(path, size, flags or "")
    end
    font:SetTextColor(Theme.Color(color or Theme.INK))
    font:SetShadowOffset(0, 0)
    return font
end

-- The game's own fonts, so other client languages still have their letters
local BODY_BASE = QuestFont or GameFontHighlight
local FANCY_BASE = Fancy22Font or GameFontNormalHuge

Theme.FONT_BODY = MakeFont("KarmabookInk", BODY_BASE, 14)
Theme.FONT_TAB = MakeFont("KarmabookInkTab", BODY_BASE, 13)
Theme.FONT_SMALL = MakeFont("KarmabookInkSmall", BODY_BASE, 12, Theme.INK_FAINT)
Theme.FONT_FAINT = MakeFont("KarmabookInkFaint", BODY_BASE, 14, Theme.INK_FAINT)
Theme.FONT_TITLE = MakeFont("KarmabookInkTitle", FANCY_BASE)
Theme.FONT_HEADING = MakeFont("KarmabookInkHeading", FANCY_BASE, 18)

----------------------------------------------------------------------
-- Pages
----------------------------------------------------------------------

local function AddPage(frame, left, right, mirrored)
    local paper = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    paper:SetPoint("TOPLEFT", left, -COVER)
    paper:SetPoint("BOTTOMRIGHT", right, COVER)
    paper:SetColorTexture(Theme.Color(Theme.PAPER))

    local page = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    page:SetAllPoints(paper)
    page:SetTexture(PAGE_ART)
    if mirrored then
        page:SetTexCoord(1, CROP_OUTER, CROP_TOP, CROP_BOTTOM)
    else
        page:SetTexCoord(CROP_OUTER, 1, CROP_TOP, CROP_BOTTOM)
    end

    -- The art is dark and mottled, so a cream wash keeps the ink readable
    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    wash:SetAllPoints(paper)
    wash:SetColorTexture(Theme.Color(Theme.PAPER_WASH))
end

-- Fills a small region with paper dyed one color. It takes a plain patch from
-- the middle of the page art, so the grain shows and no corner flourishes
-- squash into it.
function Theme.AddDyedPaper(region, dye)
    local paper = region:CreateTexture(nil, "BACKGROUND", nil, 0)
    paper:SetAllPoints()
    paper:SetColorTexture(Theme.Color(dye, 1))

    local art = region:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetAllPoints()
    art:SetTexture(PAGE_ART)
    art:SetTexCoord(0.40, 0.55, 0.30, 0.60)

    local tint = region:CreateTexture(nil, "BACKGROUND", nil, 2)
    tint:SetAllPoints()
    tint:SetColorTexture(Theme.Color(dye, 0.6))
end

-- Darkens both sides of the fold where the pages meet
local function AddSpine(frame)
    local clear, shadow = CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.4)
    local center = frame:GetWidth() / 2

    local left = frame:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", center - 26, -COVER)
    left:SetPoint("BOTTOMLEFT", center - 26, COVER)
    left:SetWidth(26)
    left:SetColorTexture(1, 1, 1)
    left:SetGradient("HORIZONTAL", clear, shadow)

    local right = frame:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPLEFT", center, -COVER)
    right:SetPoint("BOTTOMLEFT", center, COVER)
    right:SetWidth(26)
    right:SetColorTexture(1, 1, 1)
    right:SetGradient("HORIZONTAL", shadow, clear)
end

-- The red line down the left of a notebook page
function Theme.AddMargin(frame, x)
    local line = frame:CreateTexture(nil, "BORDER", nil, 1)
    line:SetPoint("TOPLEFT", x, -COVER)
    line:SetPoint("BOTTOMLEFT", x, COVER)
    line:SetWidth(1)
    line:SetColorTexture(Theme.Color(Theme.MARGIN))
end

-- A cover with paper inside. With two pages it opens like a book. Drags,
-- closes with Escape, and starts hidden.
function Theme.CreateWindow(name, width, height, twoPages)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop(COVER_BACKDROP)
    frame:SetBackdropColor(Theme.Color(Theme.LEATHER, 1))
    frame:SetBackdropBorderColor(Theme.Color(Theme.GOLD))
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    table.insert(UISpecialFrames, name)

    if twoPages then
        local center = width / 2
        AddPage(frame, COVER, -center, false)
        AddPage(frame, center, -COVER, true)
        AddSpine(frame)
    else
        AddPage(frame, COVER, -COVER, false)
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject(Theme.FONT_TITLE)

    Theme.CreateCloseButton(frame)
    return frame
end

-- Keeps one horizontal line per step on content, adding or hiding lines as
-- the count changes. offset moves them all down.
function Theme.DrawRules(content, pitch, count, offset)
    content.rules = content.rules or {}
    for index = 1, count do
        local rule = content.rules[index]
        if not rule then
            rule = content:CreateTexture(nil, "BACKGROUND")
            rule:SetHeight(1)
            rule:SetColorTexture(Theme.Color(Theme.RULE))
            content.rules[index] = rule
        end
        rule:ClearAllPoints()
        rule:SetPoint("TOPLEFT", 0, -(offset + index * pitch))
        rule:SetPoint("TOPRIGHT", 0, -(offset + index * pitch))
        rule:Show()
    end
    for index = count + 1, #content.rules do
        content.rules[index]:Hide()
    end
end

----------------------------------------------------------------------
-- Controls
----------------------------------------------------------------------

-- Plain inked text that underlines when you point at it
function Theme.CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 22)
    button:SetNormalFontObject(Theme.FONT_BODY)
    button:SetHighlightFontObject(Theme.FONT_BODY)
    button:SetDisabledFontObject(Theme.FONT_FAINT)
    button:SetText(text)

    local underline = button:CreateTexture(nil, "HIGHLIGHT")
    underline:SetPoint("BOTTOMLEFT", 4, 1)
    underline:SetPoint("BOTTOMRIGHT", -4, 1)
    underline:SetHeight(1)
    underline:SetColorTexture(Theme.Color(Theme.INK, 0.7))

    button:SetScript("OnClick", onClick)
    return button
end

function Theme.CreateCloseButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(18, 18)
    button:SetPoint("TOPRIGHT", -16, -16)

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(Theme.FONT_BODY)
    label:SetPoint("CENTER")
    label:SetText("X")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(Theme.Color(Theme.INK, 0.15))

    button:SetScript("OnClick", function()
        parent:Hide()
    end)
    return button
end

-- A line to write on, instead of a boxed text field
function Theme.CreateInput(parent, width, maxLetters)
    local input = CreateFrame("EditBox", nil, parent)
    input:SetSize(width, 22)
    input:SetFontObject(Theme.FONT_BODY)
    input:SetAutoFocus(false)
    input:SetMaxLetters(maxLetters)
    input:SetTextInsets(2, 2, 0, 0)
    input:SetScript("OnEscapePressed", input.ClearFocus)

    local line = input:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT", 0, 1)
    line:SetPoint("BOTTOMRIGHT", 0, 1)
    line:SetHeight(1)
    line:SetColorTexture(Theme.Color(Theme.INK, 0.8))
    return input
end
