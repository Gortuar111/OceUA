-- OceBookUA for Turtle / Oce WoW (1.12)
-- Підміна тексту книг / листів / табличок у ItemTextFrame
--
-- База Translations.lua:
--   [itemID] = {
--       en = "English item name",   -- обов'язково (ItemTextGetItem)
--       T  = "Українська назва",
--       pages = { [1] = "...", ... },
--   },
--
-- /obua title | page | count | debug | toggle | size N | dump | clear

local CONFIG = {
    translateDelay  = 0.10,
    sliderPoint     = "BOTTOM",
    sliderRelative  = "BOTTOM",
    sliderOffsetX   = -30,
    sliderOffsetY   = 85,
    defaultFontSize = 13,
    minFontSize     = 10,
    maxFontSize     = 20,
}

local DB = OceBookUA_DB or {}
local showUA = true
local debugMode = false
local currentTitle = nil
local currentPage = 1
local currentId = nil
local currentEnTitle = nil
local currentEnPage = nil

OceBookUA_Pending = OceBookUA_Pending or {}
OceBookUA_Settings = OceBookUA_Settings or {}

local byTitle = {}
local byTitleLower = {}

local function NormalizeTitle(s)
    if not s then return "" end
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    return s
end

local function RebuildIndex()
    byTitle = {}
    byTitleLower = {}
    local count, skipped = 0, 0
    for id, data in pairs(DB) do
        if type(data) == "table" then
            data.id = id
            local en = data.en and NormalizeTitle(data.en) or ""
            if en ~= "" then
                byTitle[en] = data
                byTitleLower[string.lower(en)] = data
                count = count + 1
            else
                skipped = skipped + 1
            end
        end
    end
    return count, skipped
end

local indexCount, indexSkipped = RebuildIndex()

local function FindTranslation(englishTitle)
    if not englishTitle or englishTitle == "" then return nil end
    local t = NormalizeTitle(englishTitle)
    return byTitle[t] or byTitleLower[string.lower(t)]
end

local function Debug(msg)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[OBUA]|r " .. tostring(msg))
    end
end

local function FormatText(text)
    if not text then return text end
    local name  = UnitName("player") or ""
    local class = UnitClass("player") or ""
    local race  = UnitRace("player") or ""
    local sex   = UnitSex("player") or 2
    text = string.gsub(text, "$[Nn]", name)
    text = string.gsub(text, "$[Cc]", string.lower(class))
    text = string.gsub(text, "$[Rr]", string.lower(race))
    text = string.gsub(text, "$[Bb]", "\n")
    text = string.gsub(text, "$[Gg]%(([^;]+);([^%)]+)%)", function(male, female)
        if sex == 3 then return female else return male end
    end)
    text = string.gsub(text, "$[Gg]([^:]+):([^;]+);", function(male, female)
        if sex == 3 then return female else return male end
    end)
    return text
end

local function SafeSetText(fs, text)
    if fs and text and text ~= "" then
        fs:SetText(FormatText(text))
    end
end

local sizeSlider, sizeLabel

local function ApplyFontSize()
    local size = CONFIG.defaultFontSize
    if OceUA_Get then
        size = OceUA_Get("bookFontSize", size)
    elseif OceBookUA_Settings and OceBookUA_Settings.fontSize then
        size = OceBookUA_Settings.fontSize
    end
    if ItemTextPageText then
        local font, _, flags = ItemTextPageText:GetFont()
        if font then
            ItemTextPageText:SetFont(font, size, flags)
        end
    end
    if sizeSlider and sizeSlider.SetValue then
        sizeSlider:SetValue(size)
    end
    if sizeLabel then
        sizeLabel:SetText(tostring(size))
    end
end

local function GetCurrentTitle()
    if ItemTextGetItem then return ItemTextGetItem() end
    if ItemTextTitleText then return ItemTextTitleText:GetText() end
    return nil
end

local function GetCurrentPageNum()
    if ItemTextGetPage then return ItemTextGetPage() or 1 end
    return 1
end

local function GetCurrentPageText()
    if ItemTextGetText then return ItemTextGetText() end
    return nil
end

local function TranslateBook()
    if OceUA_IsEnabled and not OceUA_IsEnabled("book") then return end
    local title = GetCurrentTitle()
    currentTitle = title
    currentPage = GetCurrentPageNum()
    currentId = nil
    currentEnTitle = title
    currentEnPage = GetCurrentPageText()

    Debug("BOOK title=[" .. tostring(title) .. "] page=" .. tostring(currentPage))
    if not title then return end
    ApplyFontSize()

    local tr = FindTranslation(title)
    if tr then currentId = tr.id end

    if not showUA then
        if ItemTextTitleText and title then
            ItemTextTitleText:SetText(title)
        end
        local orig = GetCurrentPageText()
        if ItemTextPageText and orig then
            local creator = ItemTextGetCreator and ItemTextGetCreator() or nil
            if creator then
                ItemTextPageText:SetText("\n" .. orig .. "\n\n" .. (ITEM_TEXT_FROM or "From") .. "\n" .. creator .. "\n\n")
            else
                ItemTextPageText:SetText("\n" .. orig .. "\n")
            end
        end
        return
    end

    if not tr then
        Debug("не знайдено")
        return
    end

    Debug("знайдено ID " .. tostring(tr.id))
    if tr.T and tr.T ~= "" and ItemTextTitleText then
        SafeSetText(ItemTextTitleText, tr.T)
    end

    local pageText = nil
    if tr.pages and type(tr.pages) == "table" then
        pageText = tr.pages[currentPage]
    elseif tr.text then
        pageText = tr.text
    end

    if pageText and ItemTextPageText then
        local creator = ItemTextGetCreator and ItemTextGetCreator() or nil
        if creator then
            SafeSetText(ItemTextPageText, "\n" .. pageText .. "\n\n" .. (ITEM_TEXT_FROM or "From") .. "\n" .. creator .. "\n\n")
        else
            SafeSetText(ItemTextPageText, "\n" .. pageText .. "\n")
        end
    end
end

-- ========== UA/EN ==========
local btn = CreateFrame("Button", "OceBookUA_Toggle", ItemTextFrame, "UIPanelButtonTemplate")
btn:SetWidth(36)
btn:SetHeight(20)
btn:SetPoint("TOPRIGHT", ItemTextFrame, "TOPRIGHT", -57, -15)
btn:SetFrameLevel((ItemTextFrame and ItemTextFrame:GetFrameLevel() or 0) + 10)
btn:SetText("UA")
btn:SetScript("OnClick", function()
    showUA = not showUA
    this:SetText(showUA and "UA" or "EN")
    TranslateBook()
end)
btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    if showUA then
        GameTooltip:AddLine("Українська", 1, 1, 0)
        GameTooltip:AddLine("Клік — оригінал (EN)", 1, 1, 1)
    else
        GameTooltip:AddLine("English", 1, 1, 0)
        GameTooltip:AddLine("Клік — переклад (UA)", 1, 1, 1)
    end
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ========== Slider ==========
sizeSlider = CreateFrame("Slider", "OceBookUA_SizeSlider", ItemTextFrame)
sizeSlider:SetWidth(100)
sizeSlider:SetHeight(16)
sizeSlider:SetPoint(CONFIG.sliderPoint, ItemTextFrame, CONFIG.sliderRelative,
    CONFIG.sliderOffsetX, CONFIG.sliderOffsetY)
sizeSlider:SetOrientation("HORIZONTAL")
sizeSlider:SetMinMaxValues(CONFIG.minFontSize, CONFIG.maxFontSize)
sizeSlider:SetValueStep(1)
sizeSlider:SetValue(CONFIG.defaultFontSize)
sizeSlider:SetFrameLevel((ItemTextFrame and ItemTextFrame:GetFrameLevel() or 0) + 10)
sizeSlider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
})
local thumb = sizeSlider:CreateTexture(nil, "OVERLAY")
thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
thumb:SetWidth(24)
thumb:SetHeight(24)
sizeSlider:SetThumbTexture(thumb)

sizeLabel = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sizeLabel:SetPoint("LEFT", sizeSlider, "RIGHT", 6, 0)
sizeLabel:SetText(tostring(CONFIG.defaultFontSize))

-- кнопки − / + прибрані за запитом; лишається лише слайдер
sizeSlider:SetScript("OnValueChanged", function()
    local v = math.floor(this:GetValue() + 0.5)
    OceBookUA_Settings.fontSize = v
    if OceUA_Set then OceUA_Set("bookFontSize", v) end
    ApplyFontSize()
end)
sizeSlider:Hide()

local function UpdateButton()
    if ItemTextFrame and ItemTextFrame:IsVisible() then
        btn:Show()
        btn:SetText(showUA and "UA" or "EN")
        sizeSlider:Show()
        ApplyFontSize()
    else
        btn:Hide()
        sizeSlider:Hide()
    end
end

-- ========== Events ==========
local f = CreateFrame("Frame")
f:RegisterEvent("ITEM_TEXT_BEGIN")
f:RegisterEvent("ITEM_TEXT_READY")
f:RegisterEvent("ITEM_TEXT_CLOSED")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "OceUA" then
        OceBookUA_Settings = OceBookUA_Settings or {}
        OceBookUA_Pending = OceBookUA_Pending or {}
        if OceUA_Get then
            OceBookUA_Settings.fontSize = OceUA_Get("bookFontSize", CONFIG.defaultFontSize)
        elseif not OceBookUA_Settings.fontSize then
            OceBookUA_Settings.fontSize = CONFIG.defaultFontSize
        end
        return
    end
    if event == "ITEM_TEXT_CLOSED" then
        btn:Hide()
        sizeSlider:Hide()
        currentTitle = nil
        currentId = nil
        currentEnTitle = nil
        currentEnPage = nil
        return
    end
    if event == "ITEM_TEXT_BEGIN" or event == "ITEM_TEXT_READY" then
        f.timer = CONFIG.translateDelay
        UpdateButton()
    end
end)

f:SetScript("OnUpdate", function()
    if this.timer then
        this.timer = this.timer - arg1
        if this.timer <= 0 then
            this.timer = nil
            TranslateBook()
            UpdateButton()
        end
    end
end)

if ItemTextFrame then
    local oldShow = ItemTextFrame:GetScript("OnShow")
    ItemTextFrame:SetScript("OnShow", function()
        if oldShow then oldShow() end
        UpdateButton()
    end)
    local oldHide = ItemTextFrame:GetScript("OnHide")
    ItemTextFrame:SetScript("OnHide", function()
        if oldHide then oldHide() end
        btn:Hide()
        sizeSlider:Hide()
    end)
end

-- ========== Dump ==========
local dumpFrame = CreateFrame("Frame", "OceBookUA_DumpFrame", UIParent)
dumpFrame:SetWidth(500)
dumpFrame:SetHeight(280)
dumpFrame:SetPoint("CENTER", 0, 40)
dumpFrame:SetFrameStrata("DIALOG")
dumpFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
dumpFrame:Hide()
dumpFrame:EnableMouse(true)
dumpFrame:SetMovable(true)
dumpFrame:RegisterForDrag("LeftButton")
dumpFrame:SetScript("OnDragStart", function() this:StartMoving() end)
dumpFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

local dumpTitle = dumpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dumpTitle:SetPoint("TOP", 0, -14)
dumpTitle:SetText("OceBookUA — шаблон (item id підстав вручну)")

local dumpEdit = CreateFrame("EditBox", "OceBookUA_DumpEdit", dumpFrame)
dumpEdit:SetWidth(460)
dumpEdit:SetHeight(190)
dumpEdit:SetPoint("TOP", dumpTitle, "BOTTOM", 0, -8)
dumpEdit:SetFontObject(GameFontHighlightSmall)
dumpEdit:SetMultiLine(true)
dumpEdit:SetAutoFocus(false)
dumpEdit:SetScript("OnEscapePressed", function() this:ClearFocus(); dumpFrame:Hide() end)
dumpEdit:SetScript("OnEditFocusGained", function() this:HighlightText() end)

local dumpClose = CreateFrame("Button", nil, dumpFrame, "UIPanelButtonTemplate")
dumpClose:SetWidth(80)
dumpClose:SetHeight(22)
dumpClose:SetPoint("BOTTOM", 0, 12)
dumpClose:SetText("Закрити")
dumpClose:SetScript("OnClick", function() dumpFrame:Hide() end)

local function ShowDumpAll()
    local title = currentEnTitle or GetCurrentTitle() or ""
    local page = currentEnPage or GetCurrentPageText() or ""
    local pageNum = currentPage or 1
    if title == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA відкрий книгу спочатку")
        return
    end
    local escTitle = string.gsub(title, "\"", "\\\"")
    local escPage = string.gsub(page, "\"", "\\\"")
    escPage = string.gsub(escPage, "\n", "$B")
    -- ID: якщо вже є в базі — той самий item id; інакше ITEM_ID
    local idStr = "ITEM_ID"
    if currentId then
        idStr = tostring(currentId)
    end
    local tpl = "[" .. idStr .. "] = {\n"
        .. "    en = \"" .. escTitle .. "\",\n"
        .. "    T  = \"\",\n"
        .. "    pages = {\n"
        .. "        [" .. pageNum .. "] = \"" .. escPage .. "\",\n"
        .. "    },\n"
        .. "},"
    dumpEdit:SetText(tpl)
    dumpFrame:Show()
    dumpEdit:SetFocus()
    dumpEdit:HighlightText()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA шаблон — підстав item id замість ITEM_ID (якщо треба)")
end

-- ========== Slash ==========
SLASH_OCEBOOKUA1 = "/obua"
SLASH_OCEBOOKUA2 = "/ocebook"
SlashCmdList["OCEBOOKUA"] = function(msg)
    msg = msg or ""
    local cmd, arg = "", ""
    local spacePos = string.find(msg, " ")
    if spacePos then
        cmd = string.lower(string.sub(msg, 1, spacePos - 1))
        arg = string.sub(msg, spacePos + 1)
    else
        cmd = string.lower(msg)
    end

    if cmd == "count" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA книг у базі: " .. indexCount)
        if indexSkipped > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA без en (пропущено): " .. indexSkipped)
        end
    elseif cmd == "title" then
        local t = GetCurrentTitle()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA title: |cffffffff[" .. tostring(t) .. "]|r")
        local tr = FindTranslation(t)
        if tr then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00  → item ID " .. tostring(tr.id) .. " | T=" .. tostring(tr.T) .. "|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900  → НЕ знайдено|r")
        end
    elseif cmd == "page" then
        local p = GetCurrentPageNum()
        local txt = GetCurrentPageText()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA сторінка " .. tostring(p) .. ":")
        if txt then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffffff[" .. string.sub(txt, 1, 200) .. (string.len(txt) > 200 and "..." or "") .. "]|r")
        end
    elseif cmd == "debug" then
        debugMode = not debugMode
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA debug: " .. (debugMode and "ON" or "OFF"))
    elseif cmd == "toggle" then
        showUA = not showUA
        btn:SetText(showUA and "UA" or "EN")
        TranslateBook()
    elseif cmd == "size" then
        local n = tonumber(arg)
        if n and n >= CONFIG.minFontSize and n <= CONFIG.maxFontSize then
            OceBookUA_Settings.fontSize = n
            if OceUA_Set then OceUA_Set("bookFontSize", n) end
            ApplyFontSize()
            DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA розмір: " .. n)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA поточний: " .. (OceBookUA_Settings.fontSize or CONFIG.defaultFontSize))
        end
    elseif cmd == "dump" then
        ShowDumpAll()
    elseif cmd == "clear" then
        OceBookUA_Pending = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA pending очищено")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rBookUA команди:")
        DEFAULT_CHAT_FRAME:AddMessage("  /obua title / page / count / debug / toggle")
        DEFAULT_CHAT_FRAME:AddMessage("  /obua size N")
        DEFAULT_CHAT_FRAME:AddMessage("  /obua dump")
        DEFAULT_CHAT_FRAME:AddMessage("  /obua clear")
    end
end

btn:Hide()
sizeSlider:Hide()
-- load message moved to OceUA (SkillUA)
