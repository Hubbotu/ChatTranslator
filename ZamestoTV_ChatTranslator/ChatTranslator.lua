TranslationStore = TranslationStore or {}
ConfigOptions = ConfigOptions or {
    globalTranslation = true,
    channelTranslation = true,
    wordByWord = true
}

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
-- Language detection (STRICT & SYMMETRIC)
---------------------------------------------------------
local function DetectLanguage(text)
    if not text or text == "" then
        return "english"
    end

    local lower = text:lower()

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

    for lang, list in pairs(WORDS) do
        for _, w in ipairs(list) do
            if lower == w then
                return lang
            end
        end
    end

    if lower:find("[äöüß]") then return "german" end
    if lower:find("ñ") then return "spanish" end
    if lower:find("[ãõ]") then return "portuguese" end
    if lower:find("[œæç]") then return "french" end
    if lower:find("[àèìòù]") then return "italian" end
    if lower:find("[А-Яа-яЁё]") then return "russian" end

    for lang, list in pairs(WORDS) do
        local score = 0
        for _, w in ipairs(list) do
            if lower:find("%f[%a]" .. w .. "%f[%A]") then
                score = score + 1
            end
        end
        if score >= 2 then
            return lang
        end
    end

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

---------------------------------------------------------
-- Translation loading
---------------------------------------------------------
local function InitializeTranslations()
    if not RussianTranslationChat or type(RussianTranslationChat) ~= "table" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Переводчик чата] Ошибка загрузки переводов|r")
        return
    end

    local count = 0
    for src, dst in pairs(RussianTranslationChat) do
        if type(src) == "string" and type(dst) == "string" then
            TranslationStore[src:lower()] = dst
            count = count + 1
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата] Загружено " .. count .. " переводов|r")
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

local function IsPublicChannel(...)
    local channelInfo = select(4, ...)
    return channelInfo and channelInfo:match("^%d+%.%s") ~= nil
end

---------------------------------------------------------
-- Translation search
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
-- Main handler (ORIGINAL LOGIC)
---------------------------------------------------------
local function HandleMessage(_, event, message, sender, ...)
    if not message or message == "" then return end

    local shouldTranslate
    if event == "CHAT_MSG_CHANNEL" then
        shouldTranslate = IsPublicChannel(...) and ConfigOptions.channelTranslation or ConfigOptions.globalTranslation
    else
        shouldTranslate = ConfigOptions.globalTranslation
    end
    if not shouldTranslate then return end

    local player = sender and Ambiguate(sender, "short") or "?"
    local translation = FindTranslation(message)
    local lang = DetectLanguage(message)
    local icon = GetLanguageIcon(lang)

    local short =
        lang == "english" and "ENG" or
        lang == "german" and "DEU" or
        lang == "french" and "FRA" or
        lang == "spanish" and "ESP" or
        lang == "portuguese" and "POR" or
        lang == "italian" and "ITA" or
        lang == "russian" and "РУС" or "???"

    local label = translation
        and ICON_RUSSIAN .. " |cFF00FF00[Перевод]|r"
        or icon .. " |cFFFFD000[" .. short .. "]|r"

    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("%s |cFFFFFF00%s|r: %s", label, player, translation or message)
    )
end

---------------------------------------------------------
-- Chat event processor (GLOBAL, CONTROLLABLE)
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
messageProcessor:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
messageProcessor:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
messageProcessor:RegisterEvent("CHAT_MSG_RAID_WARNING")

messageProcessor:SetScript("OnEvent", function(self, event, ...)
    local text = select(1, ...)
    local sender = select(2, ...)
    HandleMessage(self, event, text, sender, ...)
end)

---------------------------------------------------------
-- Slash commands (REAL /gchat FIX)
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
init:SetScript("OnEvent", InitializeTranslations)
