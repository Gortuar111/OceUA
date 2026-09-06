-- OceGossipUA for Turtle / Oce WoW (1.12)
-- Словник: ["English text"] = "Український переклад"
--
-- /ogua text   — поточний англ. текст (ключ)
-- /ogua dump   — експорт неперекладених
-- /ogua clear  — очистити список
-- /ogua count  — статистика
-- /ogua toggle — UA ↔ EN
-- /ogua debug  — діагностика

local CONFIG = {
    translateDelay  = 0,

    idPoint         = "TOPRIGHT",
    idRelativePoint = "TOPRIGHT",
    idOffsetX       = -40,
    idOffsetY       = -55,
    idWidth         = 72,
    idHeight        = 18,
}

local DB = OceGossipUA_DB or {}
local showUA = true
local debugMode = false
local currentEnText = nil
local currentKey = nil

OceGossipUA_Pending = OceGossipUA_Pending or {}
OceGossipUA_Settings = OceGossipUA_Settings or {}

local function Normalize(s)
    if not s then return "" end
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "\r\n", "$B")
    s = string.gsub(s, "\n", "$B")
    s = string.gsub(s, "\r", "$B")
    s = string.gsub(s, "\\n", "$B")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    s = string.gsub(s, "%$[Nn]", "$N")
    s = string.gsub(s, "%$[Cc]", "$C")
    s = string.gsub(s, "%$[Rr]", "$R")
    s = string.gsub(s, "%$[Bb]", "$B")
    s = string.gsub(s, "%$B%$B%$B+", "$B$B")
    return s
end

local function RestoreTokens(text)
    if not text or text == "" then return text end
    local name  = UnitName("player") or ""
    local class = UnitClass("player") or ""
    local race  = UnitRace("player") or ""
    if class ~= "" then
        text = string.gsub(text, class, "$C")
        text = string.gsub(text, string.lower(class), "$C")
    end
    if race ~= "" then
        text = string.gsub(text, race, "$R")
        text = string.gsub(text, string.lower(race), "$R")
    end
    if name ~= "" then
        text = string.gsub(text, name, "$N")
    end
    return text
end

local function Lookup(key)
    if not key or key == "" then return nil end
    local ua = DB[key]
    if type(ua) == "string" and ua ~= "" then return ua end
    local alt = string.gsub(key, "%$B", "\n")
    ua = DB[alt]
    if type(ua) == "string" and ua ~= "" then return ua end
    alt = string.gsub(key, "%$B", "\\n")
    ua = DB[alt]
    if type(ua) == "string" and ua ~= "" then return ua end
    return nil
end

local function CountTranslations()
    local n = 0
    for k, v in pairs(DB) do
        if type(k) == "string" and type(v) == "string" and v ~= "" then
            n = n + 1
        end
    end
    return n
end

local indexCount = 0

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
    text = string.gsub(text, "%$[Nn]", name)
    text = string.gsub(text, "%$[Cc]", string.lower(class))
    text = string.gsub(text, "%$[Rr]", string.lower(race))
    text = string.gsub(text, "%$[Bb]", "\n")
    text = string.gsub(text, "%$[Gg]%(([^;]+);([^%)]+)%)", function(m, f)
        if sex == 3 then return f else return m end
    end)
    text = string.gsub(text, "%$[Gg]%s*%(([^;]+);([^%)]+)%)", function(m, f)
        if sex == 3 then return f else return m end
    end)
    return text
end

local function SafeSetText(fs, text)
    if fs and text and text ~= "" then
        fs:SetText(FormatText(text))
    end
end

local function IsInPending(key)
    local i
    for i = 1, table.getn(OceGossipUA_Pending) do
        local v = OceGossipUA_Pending[i]
        if type(v) == "table" and (v.key == key or Normalize(v.en or "") == key) then
            return true
        end
    end
    return false
end

local function AddToPending(key, en)
    if not key or key == "" then return end
    if Lookup(key) then return end
    if IsInPending(key) then return end
    table.insert(OceGossipUA_Pending, { key = key, en = en or key })
end

local function TranslateGreeting()
    local text = nil
    if GetGossipText then text = GetGossipText() end
    if (not text or text == "") and GossipGreetingText then
        text = GossipGreetingText:GetText()
    end
    if not text or text == "" then
        currentEnText = nil
        currentKey = nil
        return
    end
    local key = Normalize(RestoreTokens(text))
    currentEnText = key
    currentKey = key
    Debug("greet=[" .. string.sub(key, 1, 70) .. "]")
    if not showUA then
        if GossipGreetingText and GetGossipText then
            GossipGreetingText:SetText(GetGossipText())
        end
        return
    end
    local tr = Lookup(key)
    if tr and GossipGreetingText then
        SafeSetText(GossipGreetingText, tr)
        Debug("greet OK")
    else
        Debug("greet MISS")
    end
end

local function TranslateOptions()
    if not showUA then return end
    local i
    for i = 1, 32 do
        local b = getglobal("GossipTitleButton" .. i)
        if b and b:IsVisible() then
            local en = nil
            if b.GetText then en = b:GetText() end
            if en and en ~= "" then
                local clean = string.gsub(en, "^|T.-|t%s*", "")
                local key = Normalize(RestoreTokens(clean))
                local tr = Lookup(key)
                if tr then
                    local _, _, prefix = string.find(en, "^(|T.-|t%s*)")
                    local out = FormatText(tr)
                    if prefix then out = prefix .. out end
                    b:SetText(out)
                    Debug("opt" .. i .. " OK")
                end
            end
        end
    end
end

local function TranslateGossip()
    if OceUA_IsEnabled and not OceUA_IsEnabled("gossip") then return end
    TranslateGreeting()
    TranslateOptions()
end

local btn = CreateFrame("Button", "OceGossipUA_Toggle", GossipFrame, "UIPanelButtonTemplate")
btn:SetWidth(36)
btn:SetHeight(20)
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

local idBtn = CreateFrame("Button", "OceGossipUA_IDBtn", GossipFrame)
idBtn:SetWidth(CONFIG.idWidth)
idBtn:SetHeight(CONFIG.idHeight)
idBtn:SetFrameLevel((GossipFrame and GossipFrame:GetFrameLevel() or 0) + 10)
idBtn:EnableMouse(true)
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

function UpdateIdButton()
    if not (GossipFrame and GossipFrame:IsVisible()) then
        idBtn:Hide()
        return
    end
    idBtn:Show()
    if Lookup(currentKey) then
        idText:SetText("|cff50ff50UA|r")
        idBtn:SetBackdropColor(0.05, 0.25, 0.08, 0.9)
    else
        idText:SetText("|cffff5050EN|r")
        idBtn:SetBackdropColor(0.25, 0.05, 0.05, 0.9)
    end
end

idBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    if currentKey and currentKey ~= "" then
        local short = currentKey
        if string.len(short) > 90 then short = string.sub(short, 1, 87) .. "..." end
        GameTooltip:AddLine(short, 1, 0.82, 0, 1)
    end
    if Lookup(currentKey) then
        GameTooltip:AddLine("Є переклад (зелена)", 0.5, 1, 0.5)
    else
        GameTooltip:AddLine("Немає перекладу (червона)", 1, 0.4, 0.4)
        if IsInPending(currentKey) then
            GameTooltip:AddLine("У списку", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("ЛКМ — додати", 0.5, 1, 0.5)
        end
    end
    GameTooltip:AddLine("ПКМ — dump", 0.5, 0.8, 1)
    GameTooltip:Show()
end)
idBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

idBtn:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        ShowDumpAll()
        return
    end
    if Lookup(currentKey) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA — є переклад")
    else
        AddToPending(currentKey, currentEnText)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA додано. ПКМ — dump")
    end
end)

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
dumpTitle:SetText("OceGossipUA — неперекладені")

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

function ShowDumpAll()
    local lines = {}
    local n = 0
    local i
    for i = 1, table.getn(OceGossipUA_Pending) do
        local v = OceGossipUA_Pending[i]
        local en = type(v) == "table" and (v.en or v.key) or nil
        if en and en ~= "" then
            local esc = string.gsub(en, "\\", "\\\\")
            esc = string.gsub(esc, "\"", "\\\"")
            esc = string.gsub(esc, "\n", "$B")
            esc = string.gsub(esc, "\r", "")
            table.insert(lines, "[\"" .. esc .. "\"] = \"\",")
            n = n + 1
        end
    end
    if n == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA список порожній")
        return
    end
    dumpEdit:SetText(table.concat(lines, "\n"))
    dumpFrame:Show()
    dumpEdit:SetFocus()
    dumpEdit:HighlightText()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA " .. n .. " шт.")
end

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
        DB = OceGossipUA_DB or DB
        indexCount = CountTranslations()
        PlaceIdButton()
    elseif event == "PLAYER_LOGIN" then
        DB = OceGossipUA_DB or DB
        indexCount = CountTranslations()
        PlaceIdButton()
    elseif event == "GOSSIP_CLOSED" then
        btn:Hide()
        idBtn:Hide()
        currentEnText = nil
        currentKey = nil
    elseif event == "GOSSIP_SHOW" then
        -- моментально
        TranslateGossip()
        UpdateButton()
        -- один кадр пізніше лише для кнопок опцій (якщо клієнт ще не встиг їх заповнити)
        f.retry = 1
    end
end)

f:SetScript("OnUpdate", function()
    if this.retry then
        this.retry = nil
        TranslateGossip()
        UpdateButton()
    end
end)

if GossipFrame then
    local oldShow = GossipFrame:GetScript("OnShow")
    GossipFrame:SetScript("OnShow", function()
        if oldShow then oldShow() end
        TranslateGossip()
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
        indexCount = CountTranslations()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA перекладів: " .. indexCount)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA у списку: " .. table.getn(OceGossipUA_Pending))
    elseif msg == "text" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA ключ:")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffffff[" .. tostring(currentKey) .. "]|r")
        if Lookup(currentKey) then
            DEFAULT_CHAT_FRAME:AddMessage("|cff50ff50знайдено|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5050НЕ знайдено|r")
        end
    elseif msg == "dump" then
        ShowDumpAll()
    elseif msg == "clear" then
        OceGossipUA_Pending = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA очищено")
    elseif msg == "toggle" then
        showUA = not showUA
        btn:SetText(showUA and "UA" or "EN")
        TranslateGossip()
        UpdateIdButton()
    elseif msg == "debug" then
        debugMode = not debugMode
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA debug: " .. (debugMode and "ON" or "OFF"))
    elseif msg == "resetid" then
        PlaceIdButton()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rGossipUA: text | dump | clear | count | toggle | debug")
    end
end

btn:Hide()
idBtn:Hide()
