-- Karmabook - Minimap button and addon compartment
-- Left-click opens the list, right-click opens settings, drag moves it.

local GB = Karmabook

local MinimapButton = {}
GB.MinimapButton = MinimapButton

-- The Karmabook heart, round with see-through corners
local ICON = "Interface\\AddOns\\Karmabook\\Media\\Icon"
local DEFAULT_ANGLE = 160

local function PlaceAtAngle(button, degrees)
    local angle = math.rad(degrees)
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor(button)
    local mouseX, mouseY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    local degrees = math.deg(math.atan2(mouseY / scale - centerY, mouseX / scale - centerX))
    GB.db.minimapAngle = degrees
    PlaceAtAngle(button, degrees)
end

local function OnClick(mouseButton)
    if mouseButton == "RightButton" then
        GB.Options:Open()
    else
        GB.Window:Toggle()
    end
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("Karmabook", GB.Theme.Color(GB.Theme.GOLD_LIGHT))
    GameTooltip:AddLine("Left-click: open your list", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function MinimapButton:Create()
    if self.button then
        return
    end
    local button = CreateFrame("Button", "KarmabookMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, mouseButton)
        OnClick(mouseButton)
    end)
    button:SetScript("OnDragStart", function(b)
        b:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(b)
        b:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)

    PlaceAtAngle(button, GB.db.minimapAngle or DEFAULT_ANGLE)
    button:SetShown(GB.db.showMinimap)
    self.button = button
end

function MinimapButton:SetShown(shown)
    GB.db.showMinimap = shown
    self:Create()
    self.button:SetShown(shown)
end

-- The TOC points the addon compartment at these globals
function Karmabook_OnAddonCompartmentClick(_, mouseButton)
    OnClick(mouseButton)
end

function Karmabook_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowTooltip(menuButtonFrame)
end

function Karmabook_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
