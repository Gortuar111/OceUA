--[[
  OceUA — спільні налаштування
  /oceua  |  /oceua toggle  |  /oceua status  |  /oceua on|off
  Кнопка біля мінікарти (ЛКМ — налаштування, ПКМ — увімк/вимк)

  Вкладки: Основне | Сервіс
  Lua 5.0 / WoW 1.12 — без string.match / table.pack тощо.
]]

local VERSION = "3.2.1"

OceUA_Settings = OceUA_Settings or {
    enabled      = true,
    quest        = true,
    gossip       = true,
    book         = true,
    skill        = true,
    skillShowID  = false,
    showOriginal = true,
    nameplates   = true,
    bookFontSize = 13,
    minimapPos   = 220,
}

local S = OceUA_Settings

local function MigrateOldSettings()
    if OceBookUA_Settings and OceBookUA_Settings.fontSize and not S._migratedBook then
        S.bookFontSize = OceBookUA_Settings.fontSize
        S._migratedBook = true
    end
    if OceSkillUA_Config then
        if OceSkillUA_Config.showID ~= nil and not S._migratedSkill then
            S.skillShowID = OceSkillUA_Config.showID and true or false
            S._migratedSkill = true
        end
        if OceSkillUA_Config.enabled == false then
            S.skill = false
        end
    end
end

function OceUA_IsEnabled(module)
    if not S.enabled then return false end
    if module == "quest"  then return S.quest ~= false end
    if module == "gossip" then return S.gossip ~= false end
    if module == "book"   then return S.book ~= false end
    if module == "skill"  then return S.skill ~= false end
    if module == "nameplates" then return S.nameplates == true end
    if module == "world"  then return true end
    return true
end

function OceUA_Get(key, default)
    if S[key] ~= nil then return S[key] end
    return default
end

function OceUA_Set(key, value)
    S[key] = value
end

function OceUA_GetVersion()
    return VERSION
end

-- cat: 1=історії, 2=рецепти, 3=класи/раси, 4=UA
local TIPS = {
    -- історії
    {1, "Найкращий танк інколи — це просто хтось, хто не втік."},
    {1, "Легенди кажуть: хтось якось прочитав увесь квест-текст. Легенди мовчать, чи вижив."},
    {1, "День, коли сумки порожні, а золото є — рідкісний дроп IRL."},
    {1, "Не всі дракони злі. Деякі просто погано виспались."},
    {1, "Якщо NPC киває — це ще не згода. Це анімація."},
    {1, "Чим довше AFK, тим цікавіші новини в гільдійному чаті."},
    {1, "Світло багаття гріє сильніше, коли поруч хтось є."},
    {1, "Не кожен «елітний» моб елітний. Деякі просто вперто жирні."},
    {1, "План «ударимо і розберемось» працює рівно до першого еліта."},
    {1, "Десь у Азероті досі хтось б’є тренувального манекена. Повага."},
    {1, "Перемога смакує краще, коли до неї йшли пішки, а не на таксі."},
    {1, "Якщо заблукав — це не поразка. Це платний тур без гіда."},
    {1, "«Тільки одну катку» — найдовший вечір у календарі."},
    {1, "У рейд-чат написали «тільки швидкий забіг». Через годину ніхто вже не пам’ятав, навіщо зайшли."},
    {1, "«За мною, я знаю дорогу» — класичний спосіб познайомити групу з респом."},
    {1, "Найкоротший шлях до багатства: не купувати «вигідне» на емоціях о другій ночі."},
    {1, "Воїн розігнався в героїк… з обриву. Слава була короткою, політ — довгим."},
    {1, "«AFK 2 хв» у рейді — жанр художньої літератури."},
    {1, "Хтось годинами ловив рибу. Потім згадав, навіщо зайшов у гру."},
    {1, "Легендарний дроп у групі мовчить усім чатом. Потім 10 секунд чистого хаосу."},
    {1, "«Останній бос, потім точно розхід» — і ось ви вже на наступному крилі."},
    {1, "Гільдія обіцяла «сімейну атмосферу». Сім’я виявилась галасливою."},
    {1, "Найчесніший гайд: «біжи вперед, якщо вмер — біжи знову»."},
    {1, "Друг сказав «я майже 60». Це було на 47-му. Минуло три тижні."},
    {1, "Коли лут роллять /random — віра в справедливість перевіряється на міцність."},
    -- рецепти (жовтий)
    {2, "Яєчня: яйце, сіль, масло. Сковорада гаряча — і ти вже герой ранку."},
    {2, "Паста: вода кипить, сіль як море, 8–10 хв. Сир зверху — обов’язково."},
    {2, "Тост з авокадо: розім’яти вилкою, сіль, лимон. Виглядає дорожче, ніж є."},
    {2, "Чай з лимоном: не окріп у лист, а лист у гарячу воду. Інакше гірко."},
    {2, "Картопля в мундирі: помив, запік, сіль. Мінімум рухів — максимум ефекту."},
    -- класи / раси (бірюзовий)
    {3, "Маг каже «я контрол». Через 10 секунд контрол має вся кімната — у вигляді крику."},
    {3, "Воїн без сорочки біжить першим. Це не тактика. Це характер."},
    {3, "Жрець шепоче «я не танк». Потім танчить. Потім згадує про ману."},
    {3, "Нічний ельф зник у стелсі… і в чаті. Класика гілки."},
    {3, "Гном інженер: «це безпечно». Дим, вибух, всі живі. Майже успіх."},
    -- UA (м’ятний)
    {4, "Якщо раптом знову англійською — не паніка. Інколи світ просто передумав."},
    {4, "Українською моб злиться так само. Просто зрозуміліше, на що саме."},
    {4, "Переклад не битиме за тебе мобів. Але хоча б буде зрозуміло, навіщо ти тут."},
    {4, "Дивна фраза в діалозі? Можливо, це стиль. Можливо, втомлений перекладач."},
    {4, "Азерот українською — той самий хаос, лише з ріднішими підписами."},
}

local TIP_COLOR = {
    [1] = {0.82, 0.72, 0.98}, -- історії — бузковий
    [2] = {1.00, 0.88, 0.35}, -- рецепти — жовтий
    [3] = {0.45, 0.90, 0.85}, -- класи/раси — бірюзовий
    [4] = {0.55, 0.92, 0.65}, -- UA — м’ятний
}

local tipFS
local lastTipIndex = 0
local tipSeeded = false
-- Lua 5.0 / 1.12: лише math.random() або math.random(n) → [1..n], НЕ math.random(a,b)
local function ShowRandomTip()
    if not tipFS then
        return
    end
    local n = table.getn(TIPS)
    if not n or n < 1 then
        tipFS:SetText(" ")
        return
    end
    if not tipSeeded then
        tipSeeded = true
        local t = GetTime and GetTime() or 0
        local seed = math.floor(t * 1000)
        if seed < 1 then seed = 1 end
        math.randomseed(seed)
        math.random()
        math.random()
    end
    local idx = math.random(n)
    if n > 1 then
        local guard = 0
        while idx == lastTipIndex and guard < 8 do
            idx = math.random(n)
            guard = guard + 1
        end
    end
    lastTipIndex = idx
    local entry = TIPS[idx]
    if not entry then return end
    local cat = entry[1]
    local text = entry[2]
    if not text then return end
    local c = TIP_COLOR[cat] or TIP_COLOR[1]
    tipFS:SetTextColor(c[1], c[2], c[3])
    tipFS:SetText(text)
end


-- ========== Frame (фіолетова шапка як у v3.2.1) ==========
local PAD, ROW = 14, 26
local COL = {
    title = {0.95, 0.92, 1.00},
    muted = {0.75, 0.70, 0.85},
    tabOn = {0.95, 0.88, 1.00},
    tabOff = {0.55, 0.50, 0.65},
    gold = {1.00, 0.82, 0.20},
    cmd = {0.82, 0.70, 1.00},
    btnFace = {0.22, 0.12, 0.32},
    btnBorder = {0.72, 0.42, 1.00},
    btnHover = {0.35, 0.20, 0.50},
}

local frame = CreateFrame("Frame", "OceUA_ConfigFrame", UIParent)
frame:SetWidth(340)
frame:SetHeight(370)
frame:SetPoint("CENTER", 0, 40)
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
frame:SetBackdropColor(0.06, 0.05, 0.10, 0.78)
frame:SetBackdropBorderColor(0.55, 0.32, 0.80, 0.85)
frame:Hide()

-- суцільна фіолетова шапка (як раніше)
local headerBg = frame:CreateTexture(nil, "ARTWORK")
headerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
headerBg:SetVertexColor(0.42, 0.22, 0.62, 0.92)
headerBg:SetPoint("TOPLEFT", 2, -2)
headerBg:SetPoint("TOPRIGHT", -2, -2)
headerBg:SetHeight(44)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", headerBg, "TOP", 0, -8)
title:SetTextColor(COL.title[1], COL.title[2], COL.title[3])
title:SetText("|cffb266ffOce|rUA  v" .. VERSION)

local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
subtitle:SetTextColor(COL.muted[1], COL.muted[2], COL.muted[3])
subtitle:SetText("українські переклади · OctoWoW")

-- ========== Tabs ==========
local tabBar = CreateFrame("Frame", nil, frame)
tabBar:SetPoint("TOPLEFT", PAD, -52)
tabBar:SetPoint("TOPRIGHT", -PAD, -52)
tabBar:SetHeight(22)

local function StyleTab(btn, active)
    if active then
        btn.fs:SetTextColor(COL.tabOn[1], COL.tabOn[2], COL.tabOn[3])
        btn.line:SetVertexColor(0.72, 0.42, 1.00, 1)
        btn.line:Show()
    else
        btn.fs:SetTextColor(COL.tabOff[1], COL.tabOff[2], COL.tabOff[3])
        btn.line:Hide()
    end
end

local function MakeTab(text, x)
    local b = CreateFrame("Button", nil, tabBar)
    b:SetWidth(90)
    b:SetHeight(20)
    b:SetPoint("TOPLEFT", x, 0)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(text)
    b.fs = fs
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT", 4, 0)
    line:SetPoint("BOTTOMRIGHT", -4, 0)
    b.line = line
    b:SetScript("OnEnter", function()
        if not this.active then
            this.fs:SetTextColor(0.85, 0.78, 0.95)
        end
    end)
    b:SetScript("OnLeave", function()
        StyleTab(this, this.active)
    end)
    StyleTab(b, false)
    return b
end

-- вкладки по центру вікна
local TAB_W, TAB_GAP = 88, 10
local tabsTotal = TAB_W * 3 + TAB_GAP * 2
local tabLeft = math.floor((frame:GetWidth() - 2 * PAD - tabsTotal) / 2)
local tabMain = MakeTab("Основне", tabLeft)
local tabTracker = MakeTab("Трекер", tabLeft + TAB_W + TAB_GAP)
local tabTools = MakeTab("Сервіс", tabLeft + (TAB_W + TAB_GAP) * 2)

local panelMain = CreateFrame("Frame", nil, frame)
panelMain:SetPoint("TOPLEFT", PAD, -78)
panelMain:SetPoint("BOTTOMRIGHT", -PAD, 72)

local panelTracker = CreateFrame("Frame", nil, frame)
panelTracker:SetPoint("TOPLEFT", PAD, -78)
panelTracker:SetPoint("BOTTOMRIGHT", -PAD, 72)
panelTracker:Hide()

local panelTools = CreateFrame("Frame", nil, frame)
panelTools:SetPoint("TOPLEFT", PAD, -78)
panelTools:SetPoint("BOTTOMRIGHT", -PAD, 72)
panelTools:Hide()

local function ShowTab(which)
    panelMain:Hide()
    panelTracker:Hide()
    panelTools:Hide()
    tabMain.active = false
    tabTracker.active = false
    tabTools.active = false
    StyleTab(tabMain, false)
    StyleTab(tabTracker, false)
    StyleTab(tabTools, false)
    if which == "main" then
        panelMain:Show()
        tabMain.active = true
        StyleTab(tabMain, true)
        frame:SetHeight(370)
    elseif which == "tracker" then
        panelTracker:Show()
        tabTracker.active = true
        StyleTab(tabTracker, true)
        frame:SetHeight(360)
    else
        panelTools:Show()
        tabTools.active = true
        StyleTab(tabTools, true)
        frame:SetHeight(400)
    end
    if tipFS then ShowRandomTip() end
end

tabMain:SetScript("OnClick", function() ShowTab("main") end)
tabTracker:SetScript("OnClick", function() ShowTab("tracker") end)
tabTools:SetScript("OnClick", function() ShowTab("tools") end)

-- Кнопка в стилі вкладок: текст + кольорова риска (не «важкий» бокс)
local function MakeStyledButton(parent, text, x, y, w, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w or 96)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", x, y)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER", 0, 1)
    fs:SetText(text)
    fs:SetTextColor(0.88, 0.82, 0.98)
    b.fs = fs

    -- риска під текстом (інший колір, ніж у вкладок)
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT", 6, 1)
    line:SetPoint("BOTTOMRIGHT", -6, 1)
    line:SetVertexColor(0.95, 0.72, 0.25, 0.95) -- бурштинова, не фіолетова
    b.line = line

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetVertexColor(0.55, 0.35, 0.85, 0.18)
    hl:SetAllPoints(b)

    b:SetScript("OnEnter", function()
        this.fs:SetTextColor(1, 1, 1)
        this.line:SetVertexColor(1.00, 0.85, 0.40, 1)
        if tip then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, nil, nil, nil, nil, 1)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        this.fs:SetTextColor(0.88, 0.82, 0.98)
        this.line:SetVertexColor(0.95, 0.72, 0.25, 0.95)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    return b
end


-- ========== Panel: Основне ==========
local checks = {}
local checkLabels = {}

local function SetLabelColor(key, on)
    local t = checkLabels[key]
    if not t then return end
    if on then
        t:SetTextColor(0.88, 0.95, 0.88)
    else
        t:SetTextColor(0.50, 0.50, 0.55)
    end
end

local function MakeCheck(parent, key, label, index)
    local y = -(index * ROW)
    local cb = CreateFrame("CheckButton", "OceUA_CB_" .. key, parent, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", 4, y)
    cb:SetChecked(S[key] and true or false)

    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    t:SetJustifyH("LEFT")
    t:SetText(label)
    checkLabels[key] = t
    SetLabelColor(key, S[key])

    cb:SetScript("OnClick", function()
        local on = this:GetChecked() and true or false
        S[key] = on
        if key == "showOriginal" and OceSkillUA_Config then
            OceSkillUA_Config.showOriginal = on
        end
        if key == "skill" and OceSkillUA_Config then
            OceSkillUA_Config.enabled = on
        end
        SetLabelColor(key, on)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: " .. label .. " = " .. (on and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    end)
    checks[key] = cb
    return cb
end

MakeCheck(panelMain, "enabled",      "Увімкнено (все)",           0)
MakeCheck(panelMain, "quest",        "Квести",                    1)
MakeCheck(panelMain, "gossip",       "Діалоги NPC",               2)
MakeCheck(panelMain, "book",         "Книги / листи",             3)
MakeCheck(panelMain, "skill",        "Скіли / предмети",          4)
MakeCheck(panelMain, "showOriginal", "EN-назва під UA у тултіпі", 5)
MakeCheck(panelMain, "nameplates",   "Підписи UA над мобами (неймплейти)", 6)

-- ========== Panel: Трекер (вікно квестів під мінімапою) ==========
local function ApplyTrackerCfg()
    if OceUA_ApplyQuestTrackerSettings then
        OceUA_ApplyQuestTrackerSettings()
    end
end
local function ApplyTrackerBorderOnly()
    if OceUA_ApplyQuestTrackerBorderOnly then
        OceUA_ApplyQuestTrackerBorderOnly()
    elseif OceUA_ApplyQuestTrackerSettings then
        OceUA_ApplyQuestTrackerSettings()
    end
end

local function MakeTrackerCheck(key, label, index, tip)
    local y = -(index * ROW)
    local cb = CreateFrame("CheckButton", "OceUA_CB_" .. key, panelTracker, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", 4, y)
    local on = true
    if S[key] == false then on = false end
    cb:SetChecked(on)

    local t = panelTracker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    t:SetJustifyH("LEFT")
    t:SetText(label)
    if on then t:SetTextColor(0.88, 0.95, 0.88) else t:SetTextColor(0.50, 0.50, 0.55) end

    cb:SetScript("OnClick", function()
        local v = this:GetChecked() and true or false
        S[key] = v
        if v then t:SetTextColor(0.88, 0.95, 0.88) else t:SetTextColor(0.50, 0.50, 0.55) end
        if key == "questTracker" then
            ApplyTrackerCfg()
        else
            ApplyTrackerBorderOnly()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: " .. label .. " = " .. (v and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    end)
    if tip then
        cb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, nil, nil, nil, nil, 1)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return cb
end

MakeTrackerCheck("questTracker", "Вікно квестів під мінімапою", 0,
    "Показати/сховати трекер активних квестів")
MakeTrackerCheck("questTrackerBorder", "Рамка / затемнене віконце", 1,
    "Темна підкладка навколо списку квестів")
MakeTrackerCheck("questTrackerBorderFade", "Приховувати рамку без курсора", 2,
    "Якщо увімкнено — рамка зникає, коли курсор не над трекером")

-- повзунок непрозорості (OptionsSliderTemplate — видимий на 1.12 / Turtle)
local a0 = S.questTrackerBorderAlpha or 1.0
if type(a0) ~= "number" then a0 = 1.0 end
if a0 < 0.15 then a0 = 0.15 end
if a0 > 1 then a0 = 1 end

local slider = CreateFrame("Slider", "OceUA_TrackerAlphaSlider", panelTracker, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", 16, -(3 * ROW) - 12)
slider:SetWidth(260)
slider:SetMinMaxValues(15, 100)
slider:SetValueStep(5)
slider:SetValue(math.floor(a0 * 100 + 0.5))

local slName = slider:GetName()
local slText = getglobal(slName .. "Text")
local slLow  = getglobal(slName .. "Low")
local slHigh = getglobal(slName .. "High")
if slText then
    slText:SetText("Непрозорість рамки: " .. tostring(math.floor(a0 * 100 + 0.5)) .. "%")
    slText:SetTextColor(0.88, 0.82, 0.98)
end
if slLow then slLow:SetText("15%") end
if slHigh then slHigh:SetText("100%") end

slider:SetScript("OnValueChanged", function()
    local pct = this:GetValue()
    pct = math.floor(pct / 5 + 0.5) * 5
    if pct < 15 then pct = 15 end
    if pct > 100 then pct = 100 end
    local newA = pct / 100
    if S.questTrackerBorderAlpha == newA then
        local t = getglobal(this:GetName() .. "Text")
        if t then t:SetText("Непрозорість рамки: " .. tostring(pct) .. "%") end
        return
    end
    S.questTrackerBorderAlpha = newA
    local t = getglobal(this:GetName() .. "Text")
    if t then t:SetText("Непрозорість рамки: " .. tostring(pct) .. "%") end
    -- лише альфа рамки, без Refresh трекера
    ApplyTrackerBorderOnly()
end)

local alphaHint = panelTracker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
alphaHint:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -10)
alphaHint:SetWidth(280)
alphaHint:SetJustifyH("LEFT")
alphaHint:SetTextColor(0.55, 0.55, 0.60)
alphaHint:SetText("Працює, коли рамка увімкнена. При приховуванні — максимум під час наведення.")

local sepMain = panelMain:CreateTexture(nil, "ARTWORK")
sepMain:SetTexture("Interface\\Buttons\\WHITE8X8")
sepMain:SetVertexColor(0.55, 0.35, 0.80, 0.40)
sepMain:SetPoint("TOPLEFT", 0, -7 * ROW - 6)
sepMain:SetPoint("TOPRIGHT", 0, -7 * ROW - 6)
sepMain:SetHeight(1)

-- підказка спільна для всіх вкладок (над кнопкою Закрити)
tipFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tipFS:SetPoint("BOTTOMLEFT", PAD, 38)
tipFS:SetPoint("BOTTOMRIGHT", -PAD, 38)
tipFS:SetHeight(42)
tipFS:SetJustifyH("CENTER")
tipFS:SetJustifyV("MIDDLE")
tipFS:SetNonSpaceWrap(true)
tipFS:SetTextColor(0.82, 0.72, 0.98)
tipFS:SetText("")
tipFS:Show()

-- ========== Panel: Сервіс ==========

-- ширина контенту ≈ frame - 2*PAD; кнопки в межах рамки
local CONTENT_W = 300 - 2 * PAD
local B1, B2, B3 = 100, 90, 62
local gap = math.floor((CONTENT_W - (B1 + B2 + B3)) / 2)
if gap < 4 then gap = 4 end
local x1, x2, x3 = 0, B1 + gap, B1 + gap + B2 + gap

MakeStyledButton(panelTools, "Reload словників", x1, -8, B1, function()
    if OceUA_SkillClearCache then OceUA_SkillClearCache() end
    if OceUA_SkillReloadDict then
        local d, e, i = OceUA_SkillReloadDict()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: словник перечитано — tpl="
            .. tostring(d) .. " exact=" .. tostring(e) .. " items=" .. tostring(i))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: SkillUA ще не завантажено")
    end
end, "Перечитати словники скілів без /reload клієнта")

MakeStyledButton(panelTools, "Очистити кеш", x2, -8, B2, function()
    if OceUA_SkillClearCache then
        OceUA_SkillClearCache()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: кеш перекладів скілів очищено")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: SkillUA ще не завантажено")
    end
end, "Скинути кеш перекладів скілів")

MakeStyledButton(panelTools, "Статус", x3, -8, B3, function()
    if OceUA_SkillStatus then
        local st = OceUA_SkillStatus()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA Skill: tpl=" .. tostring(st.dictCount)
            .. " exact=" .. tostring(st.exactCount) .. " items=" .. tostring(st.itemCount)
            .. " cache=" .. tostring(st.cacheCount))
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: "
        .. (S.enabled and "|cff00ff00ON|r" or "|cffff4040OFF|r")
        .. "  quest=" .. tostring(S.quest ~= false)
        .. " gossip=" .. tostring(S.gossip ~= false)
        .. " book=" .. tostring(S.book ~= false)
        .. " skill=" .. tostring(S.skill ~= false))
end, "Статус модулів у чат")

MakeStyledButton(panelTools, "/reload UI", x1, -34, 90, function()
    ReloadUI()
end, "Повний ReloadUI() клієнта")

local sepTools = panelTools:CreateTexture(nil, "ARTWORK")
sepTools:SetTexture("Interface\\Buttons\\WHITE8X8")
sepTools:SetVertexColor(0.55, 0.35, 0.80, 0.40)
sepTools:SetPoint("TOPLEFT", 0, -62)
sepTools:SetPoint("TOPRIGHT", 0, -62)
sepTools:SetHeight(1)


-- Lua 5.0: NO string.match
local function RunChatCommand(cmd)
    if not cmd or cmd == "" then return end
    local s = cmd
    if string.sub(s, 1, 1) == "/" then
        s = string.sub(s, 2)
    end
    local sp = string.find(s, " ")
    local name, rest
    if sp then
        name = string.sub(s, 1, sp - 1)
        rest = string.sub(s, sp + 1)
    else
        name = s
        rest = ""
    end
    name = string.lower(name or "")
    local map = {
        oceua = "OCEUA",
        oua = "OCEUA",
        oceskill = "OCESKILLUA",
        oqua = "OCEQUESTUA",
        ocequest = "OCEQUESTUA",
        ogua = "OCEGOSSIPUA",
        ocegossip = "OCEGOSSIPUA",
        obua = "OCEBOOKUA",
        ocebook = "OCEBOOKUA",
    }
    local key = map[name]
    if key and SlashCmdList[key] then
        SlashCmdList[key](rest)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: невідома команда /" .. tostring(name))
    end
end

-- clickable=true → ЛКМ виконує; false → лише підказка, ПКМ вставляє в чат (копія)
local COMMANDS = {
    { "/oceua",             "Відкрити вікно налаштувань", true },
    { "/oceua toggle",      "Увімк/вимк увесь аддон (є на вкладці Основне)", false },
    { "/oceua status",      "Статус модулів у чат", true },
    { "/oceua on",          "Увімкнути глобально (є на Основному)", false },
    { "/oceua off",         "Вимкнути глобально (є на Основному)", false },
    { "/oceskill reload",   "Перечитати словники скілів", true },
    { "/oceskill cache",    "Очистити кеш скілів", true },
    { "/oceskill status",   "Статус SkillUA", true },
    { "/oceskill toggle",   "Увімк/вимк скіли (є на Основному)", false },
    { "/oceskill id",       "Показ ID на скілах", true },
    { "/oceskill original", "EN-назва над UA (є на Основному)", false },
    { "/oqua toggle",       "Квести: UA ↔ EN", true },
    { "/oqua count",        "Квести: статистика бази", true },
    { "/ogua toggle",       "Діалоги: UA ↔ EN", true },
    { "/ogua count",        "Діалоги: статистика", true },
    { "/ocebook",           "Книги: довідка / статус", true },
}

local COL_W = 130
local ROW_H = 16
local nCmd = table.getn(COMMANDS)
local half = math.ceil(nCmd / 2)

local function InsertCmdToChat(cmd)
    local edit = ChatFrameEditBox
    if edit then
        edit:Show()
        edit:SetText(cmd)
        edit:SetFocus()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: команду вставлено в рядок чату — Ctrl+C щоб скопіювати")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: " .. cmd)
    end
end

for i = 1, nCmd do
    local entry = COMMANDS[i]
    local cmd = entry[1]
    local desc = entry[2]
    local clickable = entry[3]
    local col, row
    if i <= half then
        col = 0
        row = i - 1
    else
        col = 1
        row = i - half - 1
    end
    local b = CreateFrame("Button", nil, panelTools)
    b:SetWidth(COL_W)
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", 2 + col * (COL_W + 6), -84 - row * ROW_H)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetVertexColor(0.55, 0.35, 0.85, 0.18)
    hl:SetAllPoints(b)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 2, 0)
    fs:SetJustifyH("LEFT")
    if clickable then
        fs:SetTextColor(COL.cmd[1], COL.cmd[2], COL.cmd[3])
        fs:SetText(cmd)
    else
        fs:SetTextColor(0.50, 0.48, 0.55)
        fs:SetText(cmd)
    end
    b.fs = fs
    b.cmd = cmd
    b.desc = desc
    b.clickable = clickable
    b:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            InsertCmdToChat(this.cmd)
            return
        end
        if this.clickable then
            DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA → " .. this.cmd)
            RunChatCommand(this.cmd)
        else
            -- дубль Основного: не виконуємо, підказка скопіювати
            InsertCmdToChat(this.cmd)
        end
    end)
    b:SetScript("OnEnter", function()
        if this.clickable then
            this.fs:SetTextColor(1, 1, 1)
        else
            this.fs:SetTextColor(0.70, 0.68, 0.75)
        end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.cmd, 0.85, 0.70, 1.00)
        GameTooltip:AddLine(this.desc, 0.85, 0.85, 0.85, 1)
        if this.clickable then
            GameTooltip:AddLine("ЛКМ — виконати", 0.55, 0.85, 0.55, 1)
            GameTooltip:AddLine("ПКМ — вставити в чат", 0.65, 0.65, 0.70, 1)
        else
            GameTooltip:AddLine("Є на вкладці «Основне»", 0.90, 0.75, 0.40, 1)
            GameTooltip:AddLine("Клік / ПКМ — вставити в чат для копіювання", 0.65, 0.65, 0.70, 1)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        if this.clickable then
            this.fs:SetTextColor(COL.cmd[1], COL.cmd[2], COL.cmd[3])
        else
            this.fs:SetTextColor(0.50, 0.48, 0.55)
        end
        GameTooltip:Hide()
    end)
end

-- ========== Close ==========
local close = MakeStyledButton(frame, "Закрити", 0, 0, 100, function() frame:Hide() end, nil)
close:ClearAllPoints()
close:SetPoint("BOTTOM", 0, 12)

local function RefreshChecks()
    for key, cb in pairs(checks) do
        if cb and cb.SetChecked then
            local on = S[key] and true or false
            cb:SetChecked(on)
            SetLabelColor(key, on)
        end
    end
end

local function OpenConfig()
    RefreshChecks()
    ShowTab("main")
    frame:Show()
    ShowRandomTip()
end

function OceUA_OpenConfig()
    OpenConfig()
end

local function ShowStatus()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA v" .. VERSION .. " статус:")
    DEFAULT_CHAT_FRAME:AddMessage("  глобально: " .. (S.enabled and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    DEFAULT_CHAT_FRAME:AddMessage("  квести:    " .. (S.quest  and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    DEFAULT_CHAT_FRAME:AddMessage("  діалоги:   " .. (S.gossip and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    DEFAULT_CHAT_FRAME:AddMessage("  книги:     " .. (S.book   and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    DEFAULT_CHAT_FRAME:AddMessage("  скіли:     " .. (S.skill  and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    DEFAULT_CHAT_FRAME:AddMessage("  EN-назва:  " .. ((S.showOriginal ~= false) and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    if OceUA_SkillStatus then
        local st = OceUA_SkillStatus()
        DEFAULT_CHAT_FRAME:AddMessage("  templates=" .. tostring(st.dictCount)
            .. " exact=" .. tostring(st.exactCount or 0)
            .. " items=" .. tostring(st.itemCount)
            .. " cache=" .. tostring(st.cacheCount))
    end
end

table.insert(UISpecialFrames, "OceUA_ConfigFrame")

-- ========== Minimap ==========
local mini = CreateFrame("Button", "OceUA_MinimapButton", Minimap)
mini:SetWidth(32)
mini:SetHeight(32)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(8)
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mini:RegisterForDrag("LeftButton")

local miniIcon = mini:CreateTexture(nil, "BACKGROUND")
miniIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
miniIcon:SetWidth(20)
miniIcon:SetHeight(20)
miniIcon:SetPoint("CENTER", 0, 0)

local miniBorder = mini:CreateTexture(nil, "OVERLAY")
miniBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
miniBorder:SetWidth(54)
miniBorder:SetHeight(54)
miniBorder:SetPoint("TOPLEFT", 0, 0)

local function UpdateMiniPos()
    local angle = math.rad(S.minimapPos or 220)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    mini:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

mini:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        S.minimapPos = angle
        UpdateMiniPos()
    end)
end)
mini:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
end)

mini:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        S.enabled = not S.enabled
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: " .. (S.enabled and "|cff00ff00УВІМК|r" or "|cffff4040ВИМК|r"))
    else
        if frame:IsVisible() then
            frame:Hide()
        else
            OpenConfig()
        end
    end
end)

mini:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffb266ffOce|rUA", 1, 1, 1)
    GameTooltip:AddLine("ЛКМ — налаштування", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("ПКМ — увімк/вимк усе", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Тягни — пересунути кнопку", 0.55, 0.55, 0.55)
    local st = S.enabled and "|cff00ff00увімкнено|r" or "|cffff4040вимкнено|r"
    GameTooltip:AddLine("Зараз: " .. st, 0.7, 0.7, 0.9)
    GameTooltip:Show()
end)
mini:SetScript("OnLeave", function() GameTooltip:Hide() end)

SLASH_OCEUA1 = "/oceua"
SLASH_OCEUA2 = "/oua"
SlashCmdList["OCEUA"] = function(msg)
    msg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))

    if msg == "" or msg == "config" or msg == "options" or msg == "opt" then
        OpenConfig()
        return
    end

    if msg == "toggle" then
        S.enabled = not S.enabled
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: " .. (S.enabled and "|cff00ff00УВІМК|r" or "|cffff4040ВИМК|r"))
        return
    end

    if msg == "status" or msg == "stat" then
        ShowStatus()
        return
    end

    if msg == "on" then
        S.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: |cff00ff00УВІМК|r")
        return
    end

    if msg == "off" then
        S.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA: |cffff4040ВИМК|r")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA v" .. VERSION .. " команди:")
    DEFAULT_CHAT_FRAME:AddMessage("  /oceua          — вікно налаштувань")
    DEFAULT_CHAT_FRAME:AddMessage("  /oceua toggle   — увімк/вимк усе")
    DEFAULT_CHAT_FRAME:AddMessage("  /oceua status   — статус модулів")
    DEFAULT_CHAT_FRAME:AddMessage("  /oceua on|off   — глобально")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "OceUA" then
        OceUA_Settings = OceUA_Settings or S
        S = OceUA_Settings
        if S.enabled == nil then S.enabled = true end
        if S.quest == nil then S.quest = true end
        if S.gossip == nil then S.gossip = true end
        if S.book == nil then S.book = true end
        if S.skill == nil then S.skill = true end
        if S.skillShowID == nil then S.skillShowID = false end
        if S.showOriginal == nil then S.showOriginal = true end
        if S.nameplates == nil then S.nameplates = true end
        if S.bookFontSize == nil then S.bookFontSize = 13 end
        if S.minimapPos == nil then S.minimapPos = 220 end
        MigrateOldSettings()
    elseif event == "PLAYER_LOGIN" then
        UpdateMiniPos()
        mini:Show()
    end
end)
