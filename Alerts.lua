-- Karmabook - Alerts
-- One chat line, one banner, and one sound, showing your own latest note.
-- Alerts only ever appear on your screen.

local GB = Karmabook

-- Seconds before the same player can alert again for the same reason. A
-- talkative player in Trade shouldn't fire on every line, but a whisper is
-- aimed at you and is worth hearing about sooner.
local COOLDOWNS = {
    chat = 600,
    whisper = 30,
    nearby = 300,
}

-- Seconds between any two alerts for one player, so someone talking in /say
-- next to you doesn't alert once for the chat and again for the nameplate
local MIN_GAP = 30

local BANNER_NOTE_LENGTH = 160
local BANNER_OFFSET = -300
local BANNER_HOLD = 6
local BANNER_FADE = 1.5

local lastByReason = {}
local lastAny = {}

local banner

local function GetBanner()
    if banner then
        return banner
    end
    banner = CreateFrame("Frame", "KarmabookBanner", UIParent)
    banner:SetSize(900, 70)
    banner:SetPoint("TOP", UIParent, "TOP", 0, BANNER_OFFSET)
    banner:SetFrameStrata("HIGH")
    banner:Hide()

    banner.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    banner.title:SetPoint("TOP")
    banner.title:SetWidth(900)
    banner.title:SetShadowOffset(2, -2)

    banner.note = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    banner.note:SetPoint("TOP", banner.title, "BOTTOM", 0, -6)
    banner.note:SetWidth(760)
    banner.note:SetShadowOffset(2, -2)

    banner.fade = banner:CreateAnimationGroup()
    local alpha = banner.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetStartDelay(BANNER_HOLD)
    alpha:SetDuration(BANNER_FADE)
    banner.fade:SetScript("OnFinished", function()
        banner:Hide()
    end)
    return banner
end

local function ShowBanner(title, note)
    local frame = GetBanner()
    frame.fade:Stop()
    frame.title:SetText(title)
    frame.note:SetText(note)
    frame:SetAlpha(1)
    frame:Show()
    frame.fade:Play()
end

local function CoolingDown(record, reason, now)
    local reasonKey = record.name .. ":" .. reason
    local cooldown = COOLDOWNS[reason]
    if cooldown then
        if lastByReason[reasonKey] and now - lastByReason[reasonKey] < cooldown then
            return true
        end
        if lastAny[record.name] and now - lastAny[record.name] < MIN_GAP then
            return true
        end
    end
    lastByReason[reasonKey] = now
    lastAny[record.name] = now
    return false
end

-- reason is chat, whisper, nearby, group, or invite. Group and invite have no
-- cooldown because the caller only sends them once per event. where finishes
-- the sentence "<name> <where>", such as "in Guild" or "is nearby".
function GB:Alert(record, reason, where, firstNameOnly)
    if not self.db.alerts or record.muted then
        return
    end
    if CoolingDown(record, reason, GetTime()) then
        return
    end

    local label = GB.LABELS[record.label] or GB.LABELS[GB.DEFAULT_LABEL]
    local name = record.name
    local identity = GB.FormatIdentity(record)
    if identity then
        name = name .. " (" .. identity .. ")"
    end
    if firstNameOnly then
        name = name .. " (first name match)"
    end
    local latest = GB.LatestNote(record)
    local noteText = latest and latest.text or "No note saved."
    local heading = label.color .. name .. "|r " .. where
    local stamp = latest and (GB.COLORS.INFO .. GB.FormatNoteStamp(latest) .. "|r") or nil

    self:Print(heading .. " (" .. GB.FormatLabel(record) .. "): " .. noteText .. (stamp and (" " .. stamp) or ""))

    -- Quiet in combat keeps the chat line and skips the rest
    if self.db.quietInCombat and InCombatLockdown() then
        return
    end
    if self.db.banner then
        ShowBanner(heading, GB.Shorten(noteText, BANNER_NOTE_LENGTH) .. (stamp and ("\n" .. stamp) or ""))
    end
    if self.db.sound and label.sound then
        PlaySound(label.sound, "Master")
    end
end
