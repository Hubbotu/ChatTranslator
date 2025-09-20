-- Global storage and settings
TranslationStore = TranslationStore or {}
ConfigOptions = ConfigOptions or {
    globalTranslation = true,  
    channelTranslation = true, 
    wordByWord = true 
}

---------------------------------------------------------
-- Load translation data
---------------------------------------------------------
local function InitializeTranslations()
    if not CustomTranslationTable or type(CustomTranslationTable) ~= "table" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Переводчик чата] Ошибка: Файл переводов отсутствует или поврежден!|r")
        return
    end

    local loadedCount = 0
    for source, target in pairs(CustomTranslationTable) do
        if type(source) == "string" and type(target) == "string" then
            TranslationStore[source:lower()] = target
            loadedCount = loadedCount + 1
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата] Успешно загружено " .. loadedCount .. " переводов.|r")
end

---------------------------------------------------------
-- Utility functions
---------------------------------------------------------
local function ExtractWords(input)
    local wordList = {}
    for word in string.gmatch(input, "[%w']+") do
        table.insert(wordList, word:lower())
    end
    return wordList
end

local function NormalizeText(text)
    return text:gsub("^[%p%s]+", ""):gsub("[%p%s]+$", ""):lower()
end

local function IsPublicChannel(...)
    local channelInfo = select(4, ...)
    if not channelInfo then
        return false
    end
    local isPublic = channelInfo:match("^%d+%.%s") ~= nil
    return isPublic
end

---------------------------------------------------------
-- Translation processing
---------------------------------------------------------
local function FindTranslation(input)
    if not input or input == "" or tonumber(input) then return nil end

    local normalized = NormalizeText(input)
    if TranslationStore[normalized] then
        return TranslationStore[normalized]
    end

    if ConfigOptions.wordByWord then
        local translatedWords = {}
        local hasTranslation = false
        local words = ExtractWords(normalized)

        for _, word in ipairs(words) do
            if TranslationStore[word] then
                table.insert(translatedWords, TranslationStore[word])
                hasTranslation = true
            else
                table.insert(translatedWords, word)
            end
        end

        if hasTranslation then
            return table.concat(translatedWords, " ")
        end
    end

    return nil
end

---------------------------------------------------------
-- Process chat messages
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

    if not shouldTranslate then
        return
    end

    local player = sender and Ambiguate(sender, "short") or "Неизвестный"
    local translation = FindTranslation(message)

    local label = translation and "|cFF00FF00[Переведено]|r" or "|cFFFF0000[Без перевода]|r"
    local senderText = string.format("|cFFFFFF00%s|r", player)
    local output = translation or message
    local formattedMessage = string.format("%s %s: %s", label, senderText, output)

    if event == "CHAT_MSG_RAID_WARNING" then
        RaidNotice_AddMessage(RaidWarningFrame,
            string.format("%s от %s: %s", label:match("%[(.-)%]"), player, output),
            ChatTypeInfo["RAID_WARNING"])
    else
        DEFAULT_CHAT_FRAME:AddMessage(formattedMessage)
    end
end

---------------------------------------------------------
-- Register chat event listeners
---------------------------------------------------------
local messageProcessor = CreateFrame("Frame", "MessageProcessor")
messageProcessor:RegisterEvent("CHAT_MSG_CHANNEL")
messageProcessor:RegisterEvent("CHAT_MSG_SAY")
messageProcessor:RegisterEvent("CHAT_MSG_YELL")
messageProcessor:RegisterEvent("CHAT_MSG_PARTY")
messageProcessor:RegisterEvent("CHAT_MSG_PARTY_LEADER")
messageProcessor:RegisterEvent("CHAT_MSG_RAID")
messageProcessor:RegisterEvent("CHAT_MSG_RAID_LEADER")
messageProcessor:RegisterEvent("CHAT_MSG_WHISPER")
messageProcessor:RegisterEvent("CHAT_MSG_RAID_WARNING")

messageProcessor:SetScript("OnEvent", function(self, event, ...)
    local text, player = ...
    HandleMessage(self, event, text, player, ...)
end)

---------------------------------------------------------
-- Slash commands
---------------------------------------------------------
SLASH_ZCHAT_GLOBAL1 = "/achat"
SlashCmdList["ZCHAT_GLOBAL"] = function()
    ConfigOptions.globalTranslation = not ConfigOptions.globalTranslation
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата]|r Переводы для личных чатов " .. (ConfigOptions.globalTranslation and "активированы" or "деактивированы"))
end

SLASH_ZCHAT_PUBLIC1 = "/gchat"
SlashCmdList["ZCHAT_PUBLIC"] = function()
    ConfigOptions.channelTranslation = not ConfigOptions.channelTranslation
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата]|r Переводы для публичных каналов (1,2,3...) " .. (ConfigOptions.channelTranslation and "активированы" or "деактивированы"))
end

---------------------------------------------------------
-- Addon initialization
---------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    InitializeTranslations()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Переводчик чата] Модуль успешно инициализирован.|r")
end)