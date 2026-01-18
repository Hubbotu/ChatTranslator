TranslationStore = TranslationStore or {}
ConfigOptions = ConfigOptions or {
    globalTranslation = true,
    channelTranslation = true,
    wordByWord = true
}

---------------------------------------------------------
-- Flag icons (16x32)
---------------------------------------------------------
local ICON_RUSSIAN    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\russian:16:32:0:0|t"
local ICON_FRENCH     = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\french:16:32:0:0|t"
local ICON_GERMAN     = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\german:16:32:0:0|t"
local ICON_PORTUGUESE = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\portuguese:16:32:0:0|t"
local ICON_SPANISH    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\spanish:16:32:0:0|t"
local ICON_ITALIAN    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\italian:16:32:0:0|t"
local ICON_ENGLISH    = "|TInterface\\AddOns\\ZamestoTV_ChatTranslator\\Icons\\british:16:32:0:0|t"

---------------------------------------------------------
-- STRICT language detection (NON-DESTRUCTIVE)
---------------------------------------------------------
local function DetectLanguage(text)
    if not text or text == "" then
        return "english"
    end

    local lower = text:lower()

    -----------------------------------------------------
    -- Single-word priority
    -----------------------------------------------------
    local singleWords = {
        german = {
            "und","das","ich","nicht","zu","mit","auf","für","ist","aber","bin","von","wir","sie","er"
        },
        french = {
            "oui","non","merci","bonjour","salut","avec","pour","est","pas","vous","nous","ça"
        },
        spanish = {
            "hola","gracias","mañana","pero","porque","usted","bien","muy","como","donde"
        },
        portuguese = {
            "não","sim","obrigado","você","muito","bem","agora","porque","então","como"
        },
        italian = {
            "ciao","grazie","bene","molto","oggi","perché","come","quando","senza","tutto"
        }
    }

    for lang, list in pairs(singleWords) do
        for _, w in ipairs(list) do
            if lower == w then
                return lang
            end
        end
    end

    -----------------------------------------------------
    -- Unique characters (absolute)
    -----------------------------------------------------
    if lower:find("[äöüß]") then return "german" end
    if lower:find("ñ") then return "spanish" end
    if lower:find("[ãõ]") then return "portuguese" end
    if lower:find("[œæ]") or (lower:find("ç") and lower:find("[àèéêëîïôùûü]")) then
        return "french"
    end
    if lower:find("[àèìòù]") then return "italian" end
    if lower:find("[А-Яа-яЁё]") then return "russian" end

    -----------------------------------------------------
    -- Keyword scoring (safe fallback)
    -----------------------------------------------------
    local function score(words)
        local s = 0
        for _, w in ipairs(words) do
            if lower:find("%f[%a]" .. w .. "%f[%A]") then
                s = s + 1
            end
        end
        return s
    end

    if score(singleWords.german) >= 2 then return "german" end
    if score(singleWords.french) >= 2 then return "french" end
    if score(singleWords.spanish) >= 2 then return "spanish" end
    if score(singleWords.portuguese) >= 2 then return "portuguese" end
    if score(singleWords.italian) >= 2 then return "italian" end

    return "english"
end

local function GetLanguageIcon(language)
    if language == "french"     then return ICON_FRENCH
    elseif language == "german" then return ICON_GERMAN
    elseif language == "portuguese" then return ICON_PORTUGUESE
    elseif language == "spanish" then return ICON_SPANISH
    elseif language == "italian" then return ICON_ITALIAN
    elseif language == "russian" then return ICON_RUSSIAN
    else return ICON_ENGLISH end
end

---------------------------------------------------------
-- Load translations
---------------------------------------------------------
local function InitializeTranslations()
    if not RussianTranslationChat or type(RussianTranslationChat) ~= "table" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Переводчик чата] Ошибка загрузки переводов|r")
        return
    end

    local count = 0
    for k, v in pairs(RussianTranslationChat) do
        if type(k) == "string" and type(v) == "string" then
            TranslationStore[k:lower()] = v
            count = count + 1
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата] Загружено " .. count .. " переводов|r")
end

---------------------------------------------------------
-- Utilities
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

local function IsPublicChannel(...)
    local channelInfo = select(4, ...)
    if not channelInfo then return false end
    return channelInfo:match("^%d+%.%s") ~= nil
end

---------------------------------------------------------
-- Translation lookup
---------------------------------------------------------
local function FindTranslation(input)
    if not input or input == "" or tonumber(input) then return nil end

    local normalized = NormalizeText(input)
    if TranslationStore[normalized] then
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
            return table.concat(out, " ")
        end
    end

    return nil
end

---------------------------------------------------------
-- Message handler (ORIGINAL LOGIC PRESERVED)
---------------------------------------------------------
local function HandleMessage(frame, event, message, sender, ...)
    if not message or message == "" or tonumber(message) then return end

    local shouldTranslate = false

    if event == "CHAT_MSG_CHANNEL" then
        if IsPublicChannel(...) then
            shouldTranslate = ConfigOptions.channelTranslation
        else
            shouldTranslate = ConfigOptions.globalTranslation
        end
    else
        shouldTranslate = ConfigOptions.globalTranslation
    end

    if not shouldTranslate then return end

    local player = sender and Ambiguate(sender, "short") or "?"
    local translation = FindTranslation(message)

    local lang = DetectLanguage(message)
    local icon = GetLanguageIcon(lang)

    local label = translation
        and ICON_RUSSIAN .. " |cFF00FF00[Перевод]|r"
        or icon .. " |cFFFFD000[" .. string.upper(lang) .. "]|r"

    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("%s |cFFFFFF00%s|r: %s", label, player, translation or message)
    )
end

---------------------------------------------------------
-- Chat event processor (GLOBAL FRAME)
---------------------------------------------------------

messageProcessor = CreateFrame("Frame", "MessageProcessor")

messageProcessor:RegisterEvent("CHAT_MSG_CHANNEL")
messageProcessor:RegisterEvent("CHAT_MSG_SAY")
messageProcessor:RegisterEvent("CHAT_MSG_YELL")
messageProcessor:RegisterEvent("CHAT_MSG_PARTY")
messageProcessor:RegisterEvent("CHAT_MSG_PARTY_LEADER")
messageProcessor:RegisterEvent("CHAT_MSG_RAID")
messageProcessor:RegisterEvent("CHAT_MSG_RAID_LEADER")
messageProcessor:RegisterEvent("CHAT_MSG_WHISPER")
messageProcessor:RegisterEvent("CHAT_MSG_RAID_WARNING")
messageProcessor:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
messageProcessor:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")

messageProcessor:SetScript("OnEvent", function(self, event, ...)
    local text = select(1, ...)
    local sender = select(2, ...)
    HandleMessage(self, event, text, sender, ...)
end)

---------------------------------------------------------
-- Slash commands (REAL WORKING VERSION)
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

    if ConfigOptions.channelTranslation then
        messageProcessor:RegisterEvent("CHAT_MSG_CHANNEL")
    else
        messageProcessor:UnregisterEvent("CHAT_MSG_CHANNEL")
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cFF00FF00[Переводчик чата]|r Публичные каналы " ..
        (ConfigOptions.channelTranslation and "включены" or "выключены")
    )
end


---------------------------------------------------------
-- Init
---------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    InitializeTranslations()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата] Аддон успешно загружен.|r")
end)
