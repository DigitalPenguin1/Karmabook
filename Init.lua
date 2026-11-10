-- Karmabook - Startup
-- Loaded last, once every module has defined itself.

local GB = Karmabook
local addonName = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        GB:InitDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        GB.MinimapButton:Create()
        GB.Options:Register()
        GB.Hooks:Install()
        GB.Watch:Start()
        GB.Share:Start()
    end
end)
