

local addonName, TimerBars = ...;

local L = {
    PROFILES = "Profiles",
    ABILITIES = "Abilities",
    OPTIONS = "Options",
    LOCK_TOGGLE_ON = "Lock",
    LOCK_TOGGLE_OFF = "Unlock",
}

local selectedProfile;

Mixin(TimerBars, CallbackRegistryMixin)
TimerBars:GenerateCallbackEvents({
    "Database_OnInitialised",

    "Profile_OnChanged",
    "Profile_OnActiveSpecChanged",

})
CallbackRegistryMixin.OnLoad(TimerBars);




local Database = {}
function Database:Init()
    
    if not TimerBarsAccount then
        TimerBarsAccount = {
            minimapButton = {},
            profiles = {
                {
                    name = "default",
                    abilities = {},
                    specID = false,
                },
            },
            config = {},
        }
    end

    TimerBars:TriggerEvent("Database_OnInitialised")
end

function Database:GetProfiles()
    return TimerBarsAccount.profiles;
end

function Database:NewProfile(profile)
    table.insert(TimerBarsAccount.profiles, profile)
end

function Database:RemoveProfile(key)
    table.remove(TimerBarsAccount.profiles, key)
end





TimerBarsIconMixin = {}
function TimerBarsIconMixin:SetIcon(icon)
    self.icon:SetTexture(icon)
end





TimerBarsAbilityListviewMixin = {}
function TimerBarsAbilityListviewMixin:OnLoad()

end
function TimerBarsAbilityListviewMixin:SetDataBinding(binding, height)

    self.data = binding;

    self:SetHeight(height)
    self.label:SetText(binding.label)
    self.highlightLeft:SetSize(26, height)
    self.highlightRight:SetRotation(3.14)
    self.highlightRight:SetSize(26, height)
    self.highlightCenter:SetHeight(height)

    self:SetScript("OnMouseDown", function()
        binding.onMouseDown()
        self:Update()
    end)

    self:SetScript("OnEnter", function()
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("RIGHT", self, "LEFT", 0, 0)
        GameTooltip:SetSpellByID(binding.spellID)
        GameTooltip:Show()
    end)
    self:SetScript("OnLeave", function()
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    end)

    self:Update()

end
function TimerBarsAbilityListviewMixin:ResetDataBinding()
    self.data = nil;
end
function TimerBarsAbilityListviewMixin:Update()
    if self.data.watching() then
        self.label:SetTextColor(1,1,0,1)
    else
        self.label:SetTextColor(0.5,0.5,0.5,1)
    end
end






TimerBarsMixin = {}
function TimerBarsMixin:OnLoad()

    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self.timerIcons = {}
    self.timerIconsPool = CreateFramePool("FRAME", TimerBarsUI, "TimerBarsIconTemplate")

    self.numTabs = #self.tabs;

    self.spellCache = {}
    self.specInfo = {}

    self.isMouseOver = self:IsMouseOver(2, -2, -2, 2)

    TimerBars:RegisterCallback("Profile_OnChanged", self.Profile_OnChanged, self)
    TimerBars:RegisterCallback("Profile_OnActiveSpecChanged", self.Profile_OnActiveSpecChanged, self)
    TimerBars:RegisterCallback("Database_OnInitialised", self.Database_OnInitialised, self)

    SLASH_TIMERBARS1 = '/timerbars'
    SLASH_TIMERBARS2 = '/tbars'
    SlashCmdList['TIMERBARS'] = function(msg)
        self:Show()
    end

    self:RegisterForDrag("LeftButton")
    self.resize:Init(self, 100, 20)

    self:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            self:TabManager("toggle")
        end
    end)

    self.tab1:SetText(L.PROFILES)
    self.tab2:SetText(L.ABILITIES)
    self.tab3:SetText(L.OPTIONS)

    PanelTemplates_SetNumTabs(self, self.numTabs);
    PanelTemplates_SetTab(self, 1);

    for i = 1, self.numTabs do
        self["tab"..i]:SetScript("OnEnter", function()
            self:TabManager("show")
            self:OnTabSelected(i)
        end)
        self["tab"..i]:SetScript("OnLeave", function()
            self:CloseMenus()
        end)
        self["tab"..i].anim:SetScript("OnFinished", function()
            self["tab"..i]:Hide()
        end)
    end

    self.abilities.listview:SetScript("OnLeave", function()
        self:CloseMenus()
    end)

    self.profiles.show:SetScript("OnFinished", function()
        self.profiles:SetSize(300, 300)
        self.profiles.view:Show()
    end)

    self.abilities.show:SetScript("OnFinished", function()
        self.abilities:SetSize(300, 300)
        self.abilities.listview:Show()
    end)

end

function TimerBarsMixin:Database_OnInitialised()

    self:UpdateProfileDropdown()

    self.profiles.view.newProfile:SetScript("OnClick", function()
        local profileName = self.profiles.view.profileNameInput:GetText();
        if (profileName ~= "") and (#profileName > 0) and (type(self.character) == "string") then
            Database:NewProfile({
                name = profileName,
                abilities = {},
                specID = false,
                id = time(),
                character = self.character,
            })
            self.profiles.view.profileNameInput:SetText("")
            self:UpdateProfileDropdown()
        end
    end)

    self.profiles.view.removeProfile:SetScript("OnClick", function()
        if type(self.selectedProfile) == "table" then
            local key;
            for k, profile in ipairs(Database:GetProfiles()) do
                if profile.id == self.selectedProfile.id then
                    key = k;
                end
            end
            if type(key) == "number" then
                Database:RemoveProfile(key)
                self.selectedProfile = nil;
            end
            self:UpdateProfileDropdown()
        end
    end)

end

function TimerBarsMixin:UpdateProfileDropdown()
    local profiles = {}
    for k, profile in ipairs(Database:GetProfiles()) do
        table.insert(profiles, {
            text = profile.name,
            func = function()
                TimerBars:TriggerEvent("Profile_OnChanged", profile)
            end
        })
    end
    self.profiles.view.profileDropdown:SetMenu(profiles)
end

function TimerBarsMixin:CloseMenus()

    self.isMouseOver = false

    if self:IsMouseOver(2, -2, -2, 2) then
        self.isMouseOver = true;
    end
    for k, flyout in ipairs(self.flyoutMenus) do
        if flyout:IsMouseOver(2, -2, -2, 2) then
            self.isMouseOver = true;
        end
    end
    for i = 1, self.numTabs do
        if self["tab"..i]:IsMouseOver(2, -2, -2, 2) then
            self.isMouseOver = true;
        end
    end
    C_Timer.After(0.5, function()
        if self.isMouseOver == false then
            self:TabManager("fade")
            self:FlyoutMenuManager("fade")
        end
    end)

end

function TimerBarsMixin:FlyoutMenuManager(task, menuID)

    for k, flyout in ipairs(self.flyoutMenus) do
        flyout.fade:Play()
        flyout:Hide()
        flyout:SetSize(1,1)
    end

    self.abilities.listview:Hide()
    self.profiles.view:Hide()

    if task == "show" and self.flyoutMenus[menuID] then
        self.flyoutMenus[menuID].fade:Stop()
        self.flyoutMenus[menuID]:Show()
        self.flyoutMenus[menuID].show:Play()
        return;
    end

    if task == "fade" then
        for k, flyout in ipairs(self.flyoutMenus) do
            flyout.fade:Play()
        end
        return;
    end
end

function TimerBarsMixin:TabManager(task)

    if task == "toggle" then
        for i = 1, self.numTabs do
            self["tab"..i]:SetShown(not self["tab"..i]:IsVisible())
        end
        return;
    end

    if task == "show" then
        for i = 1, self.numTabs do
            self["tab"..i].anim:Stop()
            self["tab"..i]:SetAlpha(1)
            self["tab"..i]:Show()
        end
        return;
    end

    if task == "hide" then
        for i = 1, self.numTabs do
            self["tab"..i]:Hide()
        end
        return;
    end

    if task == "fade" then
        for i = 1, self.numTabs do
            self["tab"..i].anim:Play()
        end
        return;
    end

end

function TimerBarsMixin:OnTabSelected(tabID)

    PanelTemplates_SetTab(self, tabID);

    self:FlyoutMenuManager("show", tabID)

end

function TimerBarsMixin:OnEnter()

    self:TabManager("show")
end

function TimerBarsMixin:OnLeave()

    self:CloseMenus()

end

function TimerBarsMixin:OnEvent(event, ...)

    if event == "ADDON_LOADED" and (...) == addonName then
        Database:Init()
        print(string.format("[%s] loaded", addonName))
    end


    if event == "PLAYER_ENTERING_WORLD" then
        local specMenu = {
            {
                text = NONE,
                func = function()
                    TimerBars:TriggerEvent("Profile_OnActiveSpecChanged", false)
                end
            }
        }
        for i = 1, GetNumSpecializations() do
            local id, name, description, icon, role, primaryStat = GetSpecializationInfo(i)
            table.insert(specMenu, {
                text = name,
                func = function()
                    TimerBars:TriggerEvent("Profile_OnActiveSpecChanged", id)
                end
            })

            self.specInfo[id] = {
                name = name,
                desc = description,
                icon = icon,
                role = role,
            }
        end
        self.profiles.view.specDropdown:SetMenu(specMenu)

        local name, realm = UnitFullName("player");
        if realm == nil or realm == "" then
            realm = GetNormalizedRealmName();
        end
        self.character = string.format("%s.%s", realm, name)

        local specID = GetSpecialization()
        local id, name, description, icon, role, primaryStat = GetSpecializationInfo(specID)
        for k, profile in ipairs(Database:GetProfiles()) do
            if (profile.character == self.character) and (profile.specID == id) then
                self:Profile_OnChanged(profile)
                print(string.format("[%s] loaded %s profile", addonName, profile.name))
            end
        end
    end
end

function TimerBarsMixin:Profile_OnActiveSpecChanged(specID)

    if self.selectedProfile then
        self.selectedProfile.specID = specID
    end

end

function TimerBarsMixin:Profile_OnChanged(profile)
    print(string.format("[%s]", addonName), profile.name)

    self.selectedProfile = profile;

    self.spellCache = {}

    self.profiles.view.profileDropdown:SetText(profile.name)
    if self.specInfo[profile.specID] then
        self.profiles.view.specDropdown:SetText(self.specInfo[profile.specID].name)
    else
        self.profiles.view.specDropdown:SetText("")
    end

    local abilities = {}
    for tab = 1, GetNumSpellTabs() do
        local tabName, tabTexture, tabOffset, numEntries = GetSpellTabInfo(tab)
        for i=tabOffset + 1, tabOffset + numEntries do
            local spellName, spellSubName, spellID = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            
            local name, rank, icon = GetSpellInfo(spellID)
            if spellID and name and icon then
                self.spellCache[spellID] = {
                    name = name,
                    icon = icon,
                }
            end

            table.insert(abilities, {
                label = spellName,
                spellID = spellID,
                watching = function()
                    return profile.abilities[spellID] and true or false;
                end,
                onMouseDown = function()
                    profile.abilities[spellID] = not profile.abilities[spellID]
                    if profile.abilities[spellID] == false then
                        profile.abilities[spellID] = nil;
                    end
                end
            })
        end
    end
    self.abilities.listview.DataProvider:Flush()
    self.abilities.listview.DataProvider:InsertTable(abilities)
end

function TimerBarsMixin:OnUpdate()

    if type(self.selectedProfile) == "table" then
        
        for spellID, _ in pairs(self.selectedProfile.abilities) do
            local start, duration, enabled, modRate = GetSpellCooldown(spellID)
            if duration > 0 then
                local remaining = (start + duration) - GetTime()

                if not self.timerIcons[spellID] then
                    local f = self.timerIconsPool:Acquire()
                    f:SetIcon(self.spellCache[spellID].icon)
                    local xy = self:GetHeight()
                    f:SetSize(xy, xy)
                    f:SetPoint("LEFT", 0, 0)
                    f:Show()

                    self.timerIcons[spellID] = f;
                else

                    --local pos = (remaining / duration) * self:GetWidth()
                    --local bar = self:GetWidth() - self:GetHeight()
                    local offset = (self:GetWidth() / duration) * remaining;
                    local pos = self:GetWidth() - offset;
                    
                    local xy = self:GetHeight()
                    self.timerIcons[spellID]:SetSize(xy, xy)
                    self.timerIcons[spellID]:ClearAllPoints()
                    self.timerIcons[spellID]:SetPoint("LEFT", pos, 0)
                end

            else
                if self.timerIcons[spellID] then
                    self.timerIcons[spellID]:Hide()
                    self.timerIconsPool:Release(self.timerIcons[spellID])
                    self.timerIcons[spellID] = nil;
                end
            end
        end
    else
        return;
    end
end