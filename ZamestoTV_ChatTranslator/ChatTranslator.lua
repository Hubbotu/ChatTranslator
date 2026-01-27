---------------------------------------------------------
-- ZamestoTV Chat Translator PRO
--  - Chat filters (no duplicates)
--  - Translation + language caches
--  - Settings menu (Retail + Classic fallback)
---------------------------------------------------------

---------------------------------------------------------
-- SavedVariables (DO NOT SET DEFAULTS HERE)
---------------------------------------------------------
TranslationStore = TranslationStore or {}
ConfigOptions    = ConfigOptions or {}

---------------------------------------------------------
-- Local caches (session-only)
---------------------------------------------------------
local TranslationCache = {}
local LangCache        = {}

-- Options UI state (to avoid duplicate categories on /reload)
local OPTIONS_BUILT = false
local SETTINGS_CATEGORY_ID = nil

---------------------------------------------------------
-- Flag icons
---------------------------------------------------------
local ICON_RUSSIAN    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\russian:16:32:0:0|t"
local ICON_FRENCH     = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\french:16:32:0:0|t"
local ICON_GERMAN     = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\german:16:32:0:0|t"
local ICON_PORTUGUESE = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\portuguese:16:32:0:0|t"
local ICON_SPANISH    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\spanish:16:32:0:0|t"
local ICON_ITALIAN    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\italian:16:32:0:0|t"
local ICON_ENGLISH    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\british:16:32:0:0|t"

---------------------------------------------------------
-- SavedVariables initialization (BLIZZARD SAFE)
---------------------------------------------------------
local function InitializeSavedVariables()
    if ConfigOptions.globalTranslation == nil then
        ConfigOptions.globalTranslation = true
    end
    if ConfigOptions.channelTranslation == nil then
        ConfigOptions.channelTranslation = true
    end
    if ConfigOptions.wordByWord == nil then
        ConfigOptions.wordByWord = true
    end

    -- PRO options
    if ConfigOptions.translateEnglish == nil then
        ConfigOptions.translateEnglish = false
    end
    if ConfigOptions.showLanguageTag == nil then
        ConfigOptions.showLanguageTag = true
    end
    if ConfigOptions.prefixStyle == nil then
        -- "short" => [DEU], "word" => [GERMAN], "none" => no prefix (unless translated)
        ConfigOptions.prefixStyle = "short"
    end
end

local function ClearCaches()
    wipe(TranslationCache)
    wipe(LangCache)
end

---------------------------------------------------------
-- Language detection (ORIGINAL LOGIC + cached)
---------------------------------------------------------
local WORDS = {
    german = {
        "aber","alle","als","auf","aus","bei","bin","bis","das","dass","dem","den",
        "der","die","doch","ein","eine","für","geht","gibt","haben","hat","ich",
        "ist","ja","kann","kein","mit","nicht","nur","oder","sich","sie","sind",
        "und","von","was","wenn","wer","wie","wir","zu","zum","über"
    },
    french = {
        "alors","avec","avoir","bonjour","bonsoir","dans","des","donc","elle",
        "est","être","faire","ici","mais","merci","nous","pas","pour","quoi",
        "sans","sur","tout","très","vous","ça"
    },
    spanish = {
        "hola","adios","ayer","bien","como","con","del","donde","entonces",
        "estoy","gracias","hacer","mañana","para","pero","porque","que",
        "quien","siempre","sobre","todo","una","usted","muy"
    },
    portuguese = {
        "agora","aqui","bem","bom","com","como","então","está","fazer",
        "hoje","mas","não","obrigado","para","porque","quando","sem",
        "também","você","muito"
    },
    italian = {
        "allora","anche","bene","buono","ciao","come","con","fare","grazie",
        "molto","non","oggi","perché","quando","qui","senza","sono",
        "tutto","una","voi"
    }
}

local function DetectLanguage(text)
    if not text or text == "" then
        return "english"
    end

    -- Cache by raw text (chat messages repeat a lot)
    local cached = LangCache[text]
    if cached then
        return cached
    end

    local lower = text:lower()

    for lang, list in pairs(WORDS) do
        for _, w in ipairs(list) do
            if lower == w then
                LangCache[text] = lang
                return lang
            end
        end
    end

    if lower:find("[äöüß]") then LangCache[text] = "german"; return "german" end
    if lower:find("ñ") then LangCache[text] = "spanish"; return "spanish" end
    if lower:find("[ãõ]") then LangCache[text] = "portuguese"; return "portuguese" end
    if lower:find("[œæç]") then LangCache[text] = "french"; return "french" end
    if lower:find("[àèìòù]") then LangCache[text] = "italian"; return "italian" end
    if lower:find("[А-Яа-яЁё]") then LangCache[text] = "russian"; return "russian" end

    for lang, list in pairs(WORDS) do
        local score = 0
        for _, w in ipairs(list) do
            if lower:find("%f[%a]" .. w .. "%f[%A]") then
                score = score + 1
            end
        end
        if score >= 2 then
            LangCache[text] = lang
            return lang
        end
    end

    LangCache[text] = "english"
    return "english"
end

---------------------------------------------------------
-- Language icon
---------------------------------------------------------
local function GetLanguageIcon(language)
    if language == "russian"    then return ICON_RUSSIAN end
    if language == "german"     then return ICON_GERMAN end
    if language == "french"     then return ICON_FRENCH end
    if language == "spanish"    then return ICON_SPANISH end
    if language == "portuguese" then return ICON_PORTUGUESE end
    if language == "italian"    then return ICON_ITALIAN end
    return ICON_ENGLISH
end

local function GetLanguageShort(language)
    return
        language == "english" and "ENG" or
        language == "german" and "DEU" or
        language == "french" and "FRA" or
        language == "spanish" and "ESP" or
        language == "portuguese" and "POR" or
        language == "italian" and "ITA" or
        language == "russian" and "РУС" or "???"
end

---------------------------------------------------------
-- Translation loading (ORIGINAL)
---------------------------------------------------------
local function InitializeTranslations()
    if not RussianTranslationChat or type(RussianTranslationChat) ~= "table" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Переводчик чата] Ошибка загрузки переводов|r")
        return
    end

    wipe(TranslationStore)

    local count = 0
    for src, dst in pairs(RussianTranslationChat) do
        if type(src) == "string" and type(dst) == "string" then
            TranslationStore[src:lower()] = dst
            count = count + 1
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата]|r Загружено " .. count .. " переводов")
end

---------------------------------------------------------
-- Helpers
---------------------------------------------------------
local function ExtractWords(input)
    local t = {}
    for w in input:gmatch("[%w']+") do
        table.insert(t, w:lower())
    end
    return t
end

local function NormalizeText(text)
    return text:gsub("^[%p%s]+", ""):gsub("[%p%s]+$", ""):lower()
end

---------------------------------------------------------
-- Translation search (CACHED)
---------------------------------------------------------
local function FindTranslation(input)
    if not input or input == "" or tonumber(input) then return nil end

    local normalized = NormalizeText(input)

    local cached = TranslationCache[normalized]
    if cached ~= nil then
        -- store nil as false sentinel
        return cached == false and nil or cached
    end

    if TranslationStore[normalized] then
        TranslationCache[normalized] = TranslationStore[normalized]
        return TranslationStore[normalized]
    end

    if ConfigOptions.wordByWord then
        local out = {}
        local found = false
        for _, w in ipairs(ExtractWords(normalized)) do
            if TranslationStore[w] then
                table.insert(out, TranslationStore[w])
                found = true
            else
                table.insert(out, w)
            end
        end
        if found then
            local res = table.concat(out, " ")
            TranslationCache[normalized] = res
            return res
        end
    end

    TranslationCache[normalized] = false
    return nil
end

---------------------------------------------------------
-- Prefix builder
---------------------------------------------------------
local function BuildPrefix(lang, hasTranslation)
    if hasTranslation then
        return ICON_RUSSIAN .. " |cFF00FF00[Перевод]|r "
    end

    if not ConfigOptions.showLanguageTag then
        return ""
    end

    local icon = GetLanguageIcon(lang)
    if ConfigOptions.prefixStyle == "none" then
        return ""
    elseif ConfigOptions.prefixStyle == "word" then
        return icon .. " |cFFFFD000[" .. lang:upper() .. "]|r "
    else
        return icon .. " |cFFFFD000[" .. GetLanguageShort(lang) .. "]|r "
    end
end

---------------------------------------------------------
-- Chat filter (NO DUPLICATES)
---------------------------------------------------------
local function ShouldTranslateEvent(event)
    if event == "CHAT_MSG_CHANNEL" then
        return ConfigOptions.channelTranslation
    end
    return ConfigOptions.globalTranslation
end

local function ChatFilter(self, event, message, sender, ...)
    if not message or message == "" then
        return false
    end

    if not ShouldTranslateEvent(event) then
        return false
    end

    local lang = DetectLanguage(message)
    if lang == "english" and not ConfigOptions.translateEnglish then
        -- still may want to show [ENG] tag; honor showLanguageTag
        if not ConfigOptions.showLanguageTag then
            return false
        end
        -- only prefix, no other changes
        local prefix = BuildPrefix(lang, false)
        if prefix == "" then return false end
        return false, prefix .. message, sender, ...
    end

    local translation = FindTranslation(message)
    local prefix = BuildPrefix(lang, translation ~= nil)

    -- If nothing to add/change, keep original
    if not translation and prefix == "" then
        return false
    end

    return false, prefix .. (translation or message), sender, ...
end

---------------------------------------------------------
-- Register / unregister chat filters
---------------------------------------------------------
local FILTER_EVENTS = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_RAID_WARNING",
}

local function RegisterFilters()
    for _, ev in ipairs(FILTER_EVENTS) do
        ChatFrame_AddMessageEventFilter(ev, ChatFilter)
    end
end

local function UnregisterFilters()
    for _, ev in ipairs(FILTER_EVENTS) do
        ChatFrame_RemoveMessageEventFilter(ev, ChatFilter)
    end
end

---------------------------------------------------------
-- Slash commands
---------------------------------------------------------
SLASH_ZCHAT_GLOBAL1 = "/achat"
SlashCmdList["ZCHAT_GLOBAL"] = function()
    ConfigOptions.globalTranslation = not ConfigOptions.globalTranslation
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cFF00FF00[Переводчик чата]|r Личные чаты " ..
        (ConfigOptions.globalTranslation and "включены" or "выключены")
    )
end

SLASH_ZCHAT_PUBLIC1 = "/gchat"
SlashCmdList["ZCHAT_PUBLIC"] = function()
    ConfigOptions.channelTranslation = not ConfigOptions.channelTranslation
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cFF00FF00[Переводчик чата]|r Публичные каналы " ..
        (ConfigOptions.channelTranslation and "включены" or "выключены")
    )
end

SLASH_ZCHAT_OPTIONS1 = "/zchat"
SlashCmdList["ZCHAT_OPTIONS"] = function()
    if Settings and Settings.OpenToCategory then
        if SETTINGS_CATEGORY_ID then
            Settings.OpenToCategory(SETTINGS_CATEGORY_ID)
        else
            -- Fallback: some clients accept the category name
            Settings.OpenToCategory("ZamestoTV Chat Translator")
        end
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("ZamestoTV Chat Translator")
        InterfaceOptionsFrame_OpenToCategory("ZamestoTV Chat Translator")
    end
end

SLASH_ZCHAT_CLEARCACHE1 = "/zchatcache"
SlashCmdList["ZCHAT_CLEARCACHE"] = function()
    ClearCaches()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата]|r Кеш очищен")
end

---------------------------------------------------------
-- Settings UI
---------------------------------------------------------
local function CreateCheckbox(parent, label, tooltip, getter, setter, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, y)

    cb.Text:SetText(label)
    if tooltip then
        cb.tooltipText = label
        cb.tooltipRequirement = tooltip
    end

    cb:SetScript("OnShow", function(self) self:SetChecked(getter()) end)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked()) end)
    cb:SetChecked(getter())
    return cb
end

local function CreateButton(parent, text, y, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("TOPLEFT", 16, y)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function BuildOptionsPanel()
    if OPTIONS_BUILT then return end
    OPTIONS_BUILT = true
    local panel = CreateFrame("Frame")
    panel.name = "ZamestoTV Chat Translator"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ZamestoTV Chat Translator")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("Команды: /achat, /gchat, /zchat, /zchatcache")

    local y = -60

    CreateCheckbox(panel,
        "Перевод личных чатов",
        "SAY / PARTY / RAID / WHISPER / INSTANCE / etc.",
        function() return ConfigOptions.globalTranslation end,
        function(v) ConfigOptions.globalTranslation = v end,
        y
    )
    y = y - 28

    CreateCheckbox(panel,
        "Перевод публичных каналов",
        "Торговля, общий, LFG и т.п. (CHAT_MSG_CHANNEL)",
        function() return ConfigOptions.channelTranslation end,
        function(v) ConfigOptions.channelTranslation = v end,
        y
    )
    y = y - 28

    CreateCheckbox(panel,
        "Перевод по словам (word-by-word)",
        "Если фраза не найдена — пробуем переводить каждое слово отдельно.",
        function() return ConfigOptions.wordByWord end,
        function(v) ConfigOptions.wordByWord = v; ClearCaches() end,
        y
    )
    y = y - 28

    CreateCheckbox(panel,
        "Показывать тег языка, если перевода нет",
        "Например: [DEU], [FRA]. Если выключить — сообщения без перевода будут без префикса.",
        function() return ConfigOptions.showLanguageTag end,
        function(v) ConfigOptions.showLanguageTag = v end,
        y
    )
    y = y - 28

    CreateCheckbox(panel,
        "Пытаться переводить английский тоже",
        "По умолчанию английский не трогаем (только тег, если включен).",
        function() return ConfigOptions.translateEnglish end,
        function(v) ConfigOptions.translateEnglish = v; ClearCaches() end,
        y
    )
    y = y - 36

    CreateButton(panel, "Очистить кеш", y, function()
        ClearCaches()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата]|r Кеш очищен")
    end)

    y = y - 30
    CreateButton(panel, "Перезагрузить переводы", y, function()
        InitializeTranslations()
        ClearCaches()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        if category then
            if category.GetID then
                SETTINGS_CATEGORY_ID = category:GetID()
            elseif category.ID then
                SETTINGS_CATEGORY_ID = category.ID
            end
        end
    else
        InterfaceOptions_AddCategory(panel)
    end
end

---------------------------------------------------------
-- Init
---------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    InitializeSavedVariables()
    InitializeTranslations()
    ClearCaches()
    UnregisterFilters()
    RegisterFilters()
    BuildOptionsPanel()
end)
