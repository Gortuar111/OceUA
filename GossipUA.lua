-- OceGossipUA for Turtle / Oce WoW (1.12)
--
-- /ogua text   — англ. текст + ID
-- /ogua dump   — експорт неперекладених
-- /ogua clear  — очистити список
-- /ogua count  — статистика
-- /ogua toggle — UA ↔ EN
-- /ogua debug  — діагностика
-- /ogua resetid

local CONFIG = {
    -- затримка перед підміною тексту діалогу (сек)
    translateDelay  = 0.10,

    -- ===== позиція кнопки ID (GossipFrame) =====
    -- SetPoint(idPoint, GossipFrame, idRelativePoint, idOffsetX, idOffsetY)
    idPoint         = "TOPRIGHT",   -- точка на кнопці ID
    idRelativePoint = "TOPRIGHT",   -- точка на вікні діалогу
    idOffsetX       = -40,          -- ліво ↔ право: мінус = лівіше, плюс = правіше
    idOffsetY       = -55,          -- низ ↔ верх:  плюс = вище, мінус = нижче
    idWidth         = 72,           -- ширина кнопки ID
    idHeight        = 18,           -- висота кнопки ID
}

local DB = OceGossipUA_DB or {}
local showUA = true
local debugMode = false
local currentEnText = nil
local currentId = nil

OceGossipUA_Pending = OceGossipUA_Pending or {}
OceGossipUA_Settings = OceGossipUA_Settings or {}

local function TextId(s)
    if not s or s == "" then return 0 end
    local h = 0
    for i = 1, string.len(s) do
        h = h * 31 + string.byte(s, i)
        h = mod(h, 1000000007)
    end
    if h < 0 then h = -h end
    if h == 0 then h = 1 end
    return h
end

local function Normalize(s)
    if not s then return "" end
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "\r\n", "\n")
    s = string.gsub(s, "\r", "\n")
    return s
end

local byId = {}
local function RebuildIndex()
    byId = {}
    local count = 0
    for id, val in pairs(DB) do
        if type(id) == "number" then
            local ua = nil
            if type(val) == "string" then
                ua = val
            elseif type(val) == "table" and val.text then
                ua = val.text
            end
            if ua and ua ~= "" then
                byId[id] = ua
                count = count + 1
            end
        end
    end
    return count
end
local indexCount = RebuildIndex()

local function FindTranslation(id)
    if not id then return nil end
    return byId[id]
end

local function Debug(msg)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[OGUA]|r " .. tostring(msg))
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
    text = string.gsub(text, "$[Gg]%(([^;]+);([^%)]+)%)", function(m, f)
        if sex == 3 then return f else return m end
    end)
    return text
end

local function SafeSetText(fs, text)
    if fs and text and text ~= "" then
        fs:SetText(FormatText(text))
    end
end

local function IsInPending(id)
    local i
    for i = 1, table.getn(OceGossipUA_Pending) do
        local v = OceGossipUA_Pending[i]
        if type(v) == "table" and v.id == id then
            return true
        end
    end
    return false
end

-- Зворотна підстановка: гра вже розкрила $N/$C/$R у GetGossipText()
local function RestoreTokens(text)
    if not text or text == "" then return text end
    local name  = UnitName("player") or ""
    local class = UnitClass("player") or ""
    local race  = UnitRace("player") or ""

    -- спочатку довші рядки, щоб не різати частини слів
    if class ~= "" then
        -- Class / class
        text = string.gsub(text, class, "$C")
        text = string.gsub(text, string.lower(class), "$c")
    end
    if race ~= "" then
        text = string.gsub(text, race, "$R")
        text = string.gsub(text, string.lower(race), "$r")
    end
    if name ~= "" then
        text = string.gsub(text, name, "$N")
    end
    -- переноси рядків → $B (у dump зручніше в один рядок)
    text = string.gsub(text, "\r\n", "$B")
    text = string.gsub(text, "\n", "$B")
    text = string.gsub(text, "\r", "$B")
    return text
end

local function AddToPending(id, en)
    if not id or not en or en == "" then return end
    if IsInPending(id) then return end
    en = RestoreTokens(en)
    table.insert(OceGossipUA_Pending, { id = id, en = en })
end

local function TranslateGossip()
    if OceUA_IsEnabled and not OceUA_IsEnabled("gossip") then return end
    local text = nil
    if GetGossipText then text = GetGossipText() end
    if (not text or text == "") and GossipGreetingText then
        text = GossipGreetingText:GetText()
    end
    -- відновлюємо $N/$C/$R ДО хешу, щоб ID був однаковий для всіх класів
    if text and text ~= "" then
        text = RestoreTokens(text)
    end
    currentEnText = text
    if text and text ~= "" then
        currentId = TextId(Normalize(text))
    else
        currentId = nil
    end

    Debug("id=" .. tostring(currentId))

    if not text or text == "" then return end

    if not showUA then
        if GossipGreetingText and GetGossipText then
            GossipGreetingText:SetText(GetGossipText())
        end
        return
    end

    local tr = FindTranslation(currentId)
    if tr and GossipGreetingText then
        SafeSetText(GossipGreetingText, tr)
    end
end

-- UA/EN
local btn = CreateFrame("Button", "OceGossipUA_Toggle", GossipFrame, "UIPanelButtonTemplate")
btn:SetWidth(36)
btn:SetHeight(20)
-- кнопка UA/EN: TOPRIGHT вікна діалогу, X=-54 (лівіше), Y=-20 (нижче від верху)
btn:SetPoint("TOPRIGHT", GossipFrame, "TOPRIGHT", -54, -20)
btn:SetFrameLevel((GossipFrame and GossipFrame:GetFrameLevel() or 0) + 10)
btn:SetText("UA")
btn:SetScript("OnClick", function()
    showUA = not showUA
    this:SetText(showUA and "UA" or "EN")
    TranslateGossip()
    UpdateIdButton()
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

-- ID
local idBtn = CreateFrame("Button", "OceGossipUA_IDBtn", GossipFrame)
idBtn:SetWidth(CONFIG.idWidth)
idBtn:SetHeight(CONFIG.idHeight)
idBtn:SetFrameLevel((GossipFrame and GossipFrame:GetFrameLevel() or 0) + 10)
idBtn:EnableMouse(true)
idBtn:SetMovable(false)
idBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
idBtn:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
idBtn:SetBackdropColor(0.1, 0.1, 0.15, 0.85)

local idText = idBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
idText:SetAllPoints()
idText:SetJustifyH("CENTER")
idText:SetText("")

local function PlaceIdButton()
    idBtn:ClearAllPoints()
    idBtn:SetPoint(CONFIG.idPoint, GossipFrame, CONFIG.idRelativePoint, CONFIG.idOffsetX, CONFIG.idOffsetY)
end




-- Dump frame
local dumpFrame = CreateFrame("Frame", "OceGossipUA_DumpFrame", UIParent)
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
dumpTitle:SetText("OceGossipUA — неперекладені (встав у Translations.lua)")

local dumpEdit = CreateFrame("EditBox", "OceGossipUA_DumpEdit", dumpFrame)
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
    local lines = {}
    local n = 0
    local i
    for i = 1, table.getn(OceGossipUA_Pending) do
        local v = OceGossipUA_Pending[i]
        if type(v) == "table" and v.id and v.en and v.en ~= "" then
            local esc = string.gsub(v.en, "\"", "\\\"")
            esc = string.gsub(esc, "\n", "$B")
            table.insert(lines, "[" .. tostring(v.id) .. "] = \"" .. esc .. "\",")
            n = n + 1
        end
    end
    if n == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA список порожній")
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  якщо була помилка раніше — /ogua clear|r")
        return
    end
    dumpEdit:SetText(table.concat(lines, "\n"))
    dumpFrame:Show()
    dumpEdit:SetFocus()
    dumpEdit:HighlightText()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA " .. n .. " шт. — переклади текст у лапках")
end

function UpdateIdButton()
    if not (GossipFrame and GossipFrame:IsVisible() and currentId) then
        idBtn:Hide()
        return
    end
    idText:SetText(tostring(currentId))
    if FindTranslation(currentId) then
        idBtn:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)
        idText:SetTextColor(1.0, 0.82, 0.0)
    else
        idBtn:SetBackdropBorderColor(1.0, 0.25, 0.2, 1)
        idText:SetTextColor(1.0, 0.4, 0.3)
    end
    idBtn:Show()
end

idBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("ID: " .. tostring(currentId), 1, 0.82, 0)
    if FindTranslation(currentId) then
        GameTooltip:AddLine("Є переклад (золота)", 0.5, 1, 0.5)
    else
        GameTooltip:AddLine("Немає перекладу (червона)", 1, 0.4, 0.4)
        if IsInPending(currentId) then
            GameTooltip:AddLine("У списку", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("ЛКМ — додати до списку", 0.5, 1, 0.5)
        end
    end
    GameTooltip:AddLine("ПКМ — відкрити dump", 0.5, 0.8, 1)
    GameTooltip:Show()
end)
idBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

idBtn:SetScript("OnClick", function()
    if this.isMoving then return end
    -- Правий клік → dump (експорт списку)
    if arg1 == "RightButton" then
        ShowDumpAll()
        return
    end
    -- Лівий клік → додати / показати статус
    if FindTranslation(currentId) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA ID " .. tostring(currentId) .. " — є переклад")
    else
        AddToPending(currentId, currentEnText)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA ID " .. tostring(currentId) .. " додано. ПКМ по ID — dump")
    end
end)

local function UpdateButton()
    if GossipFrame and GossipFrame:IsVisible() then
        btn:Show()
        btn:SetText(showUA and "UA" or "EN")
        UpdateIdButton()
    else
        btn:Hide()
        idBtn:Hide()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("GOSSIP_CLOSED")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "OceUA" then
        OceGossipUA_Settings = OceGossipUA_Settings or {}
        OceGossipUA_Pending = OceGossipUA_Pending or {}
        PlaceIdButton()
    elseif event == "PLAYER_LOGIN" then
        PlaceIdButton()
    elseif event == "GOSSIP_CLOSED" then
        btn:Hide()
        idBtn:Hide()
        currentEnText = nil
        currentId = nil
    elseif event == "GOSSIP_SHOW" then
        f.timer = CONFIG.translateDelay
        UpdateButton()
    end
end)
f:SetScript("OnUpdate", function()
    if this.timer then
        this.timer = this.timer - arg1
        if this.timer <= 0 then
            this.timer = nil
            TranslateGossip()
            UpdateButton()
        end
    end
end)

if GossipFrame then
    local oldShow = GossipFrame:GetScript("OnShow")
    GossipFrame:SetScript("OnShow", function()
        if oldShow then oldShow() end
        UpdateButton()
    end)
    local oldHide = GossipFrame:GetScript("OnHide")
    GossipFrame:SetScript("OnHide", function()
        if oldHide then oldHide() end
        btn:Hide()
        idBtn:Hide()
    end)
end

SLASH_OCEGOSSIPUA1 = "/ogua"
SLASH_OCEGOSSIPUA2 = "/ocegossip"
SlashCmdList["OCEGOSSIPUA"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "count" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA перекладів: " .. indexCount)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA у списку: " .. table.getn(OceGossipUA_Pending))
    elseif msg == "text" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA ID " .. tostring(currentId))
        DEFAULT_CHAT_FRAME:AddMessage("|cffffffff[" .. tostring(currentEnText) .. "]|r")
    elseif msg == "dump" then
        ShowDumpAll()
    elseif msg == "clear" then
        OceGossipUA_Pending = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA список очищено")
    elseif msg == "toggle" then
        showUA = not showUA
        btn:SetText(showUA and "UA" or "EN")
        TranslateGossip()
        UpdateIdButton()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA режим: " .. (showUA and "UA" or "EN"))
    elseif msg == "debug" then
        debugMode = not debugMode
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA debug: " .. (debugMode and "ON" or "OFF"))
    elseif msg == "resetid" then
        PlaceIdButton()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA позицію ID скинуто на CONFIG")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA команди:")
        DEFAULT_CHAT_FRAME:AddMessage("  /ogua text     — англ. текст + ID")
        DEFAULT_CHAT_FRAME:AddMessage("  /ogua dump     — експорт неперекладених")
        DEFAULT_CHAT_FRAME:AddMessage("  /ogua clear    — очистити список")
        DEFAULT_CHAT_FRAME:AddMessage("  /ogua count    — статистика")
        DEFAULT_CHAT_FRAME:AddMessage("  /ogua toggle   — UA ↔ EN")
        DEFAULT_CHAT_FRAME:AddMessage("  /ogua debug    — діагностика")
        DEFAULT_CHAT_FRAME:AddMessage("  /ogua resetid  — скинути позицію ID")
    end
end

btn:Hide()
idBtn:Hide()
-- load message moved to OceUA (SkillUA)
