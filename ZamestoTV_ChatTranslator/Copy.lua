-------------------------------------------------------------
-- Full version with copy icon support --
-------------------------------------------------------------

local upper = string.upper
local TheFrame

local Clear, NoReset, Show = 1, 2, 3

-------------------------------------------------------------
-- Main Copy Display Window
-------------------------------------------------------------
local function DisplayText(text, arg1)
    if not TheFrame then
        local backdrop = {
            bgFile = "Interface/BUTTONS/WHITE8X8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            edgeSize = 7,
            tileSize = 7,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        }

        local f = CreateFrame("Frame", "CopyChatFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        TheFrame = f
        f:SetBackdrop(backdrop)
        f:SetBackdropColor(0, 0, 0, 1)
        f:SetPoint("CENTER")
        f:SetSize(600, 400)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetClampedToScreen(true)

        f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.Close:SetPoint("TOPRIGHT", -5, -5)
        f.Close:SetScript("OnClick", function() f:Hide() end)

        f.Scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.Scroll:SetPoint("TOPLEFT", f, 10, -30)
        f.Scroll:SetPoint("BOTTOMRIGHT", f, -30, 10)

        f.EditBox = CreateFrame("EditBox", nil, f)
        f.EditBox:SetMultiLine(true)
        f.EditBox:SetFontObject(ChatFontNormal)
        f.EditBox:SetWidth(f:GetWidth())
        f.EditBox:SetAutoFocus(false)
        f.EditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        f.Scroll:SetScrollChild(f.EditBox)
    end

    if not TheFrame:IsShown() then
        TheFrame:Show()
    end

    if arg1 == Show then return end
    if arg1 == NoReset then
        TheFrame.EditBox:SetText(TheFrame.EditBox:GetText() .. "\n" .. text)
    elseif arg1 == Clear then
        TheFrame.EditBox:SetText("")
    else
        TheFrame.EditBox:SetText(text)
    end

    TheFrame.EditBox:ClearFocus()
end

-------------------------------------------------------------
-- Slash Command
-------------------------------------------------------------
SLASH_COPYCHAT1 = "/copy"
SlashCmdList["COPYCHAT"] = function(msg)
    local param
    if upper(msg) == "ADD" then
        param = NoReset
    elseif upper(msg) == "CLEAR" then
        param = Clear
    elseif upper(msg) == "SHOW" then
        param = Show
        DisplayText("", param)
        return
    end

    local text = ""
    for i = #ChatFrame1.visibleLines, 1, -1 do
        local line = ChatFrame1.visibleLines[i]
        if line and line.messageInfo and line.messageInfo.message then
            text = text .. line.messageInfo.message .. "\n"
        end
    end

    DisplayText(text, param)
end

-------------------------------------------------------------
-- Copy Icon
-------------------------------------------------------------
local function CreateCopyIcon(i)
    local frame = _G["ChatFrame"..i]
    if not frame or frame.copyIconAdded then
        return
    end

    -- Create the button
    local btn = CreateFrame("Button", "CopyChatMiniButton"..i, frame)
    btn:SetSize(18, 18)
    btn:SetPoint("BOTTOMRIGHT", -2, -3)
    btn:Hide()

    -- Add the icon texture
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\copy")
    btn.texture = tex

    -- Click = run the /copy command
    btn:SetScript("OnClick", function()
        SlashCmdList["COPYCHAT"]("")
    end)

    ---------------------------------------------------------
    -- Tooltip
    ---------------------------------------------------------
    btn.tooltip = CreateFrame("Frame", nil, btn, "TooltipBorderedFrameTemplate")
    btn.tooltip:SetPoint("TOP", 0, 25)

    btn.tooltip.fs = btn.tooltip:CreateFontString(nil, "OVERLAY", "NumberFont_Shadow_Med")
    btn.tooltip.fs:SetText("Copy")
    btn.tooltip.fs:SetPoint("CENTER")

    btn.tooltip:SetWidth(btn.tooltip.fs:GetStringWidth() + 12)
    btn.tooltip:SetHeight(btn.tooltip.fs:GetStringHeight() + 8)
    btn.tooltip:SetFrameStrata("TOOLTIP")
    btn.tooltip:Hide()

    ---------------------------------------------------------
    -- Hover Behavior
    ---------------------------------------------------------
    btn:SetScript("OnEnter", function()
        btn:Show()
        btn.tooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        btn.tooltip:Hide()
        btn:Hide()
    end)

    frame:HookScript("OnEnter", function()
        btn:Show()
    end)

    frame:HookScript("OnLeave", function()
        btn.tooltip:Hide()
        btn:Hide()
    end)

    frame.copyIconAdded = true
end

-------------------------------------------------------------
-- Load Icons for All Chat Frames on Login
-------------------------------------------------------------
local iconLoader = CreateFrame("Frame")
iconLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
iconLoader:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        for i = 1, NUM_CHAT_WINDOWS do
            CreateCopyIcon(i)
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

-------------------------------------------------------------
-- Support for dynamically created chat frames (updated for modern patches)
-------------------------------------------------------------
local function AddCopyIconToFrame(frame)
    if frame and frame.GetName then
        local name = frame:GetName()
        local num = name and string.match(name, "ChatFrame(%d+)")
        if num then
            CreateCopyIcon(tonumber(num))
        end
    end
end

-- Hook when a new chat window is opened
if FCF_OpenNewWindow then
    hooksecurefunc("FCF_OpenNewWindow", function()
        C_Timer.After(0.1, function()
            for i = 1, NUM_CHAT_WINDOWS do
                local frame = _G["ChatFrame" .. i]
                if frame and not frame.copyIconAdded then
                    AddCopyIconToFrame(frame)
                end
            end
        end)
    end)
end

-- Periodic fallback checker in case any frames are created outside the normal flow
local checker = CreateFrame("Frame")
checker.timer = 0
checker:SetScript("OnUpdate", function(self, elapsed)
    self.timer = self.timer + elapsed
    if self.timer >= 5 then  -- Check every 5 seconds
        for i = 1, NUM_CHAT_WINDOWS do
            local frame = _G["ChatFrame" .. i]
            if frame and not frame.copyIconAdded then
                AddCopyIconToFrame(frame)
            end
        end
        self.timer = 0
    end
end)