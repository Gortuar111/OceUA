-- OceQuestUA for Turtle / Oce WoW (1.12)
-- Підміна тексту квестів у вікні NPC на українську
--
-- /oqua title  — точна англ. назва з гри (скопіюй в en)
-- /oqua debug  — увімкнути діагностику в чат
-- /oqua count  — скільки квестів / без en

--[[============================================================================
    НАЛАШТУВАННЯ
============================================================================]]

local CONFIG = {
    idFormat        = "#%d",        -- як показувати ID на кнопці (#12345)

    -- ===== позиція кнопки ID (QuestFrame) =====
    -- SetPoint(idPoint, QuestFrame, idRelativePoint, idOffsetX, idOffsetY)
    idPoint         = "TOPRIGHT",   -- точка на кнопці ID
    idRelativePoint = "TOPRIGHT",   -- точка на вікні квесту
    idOffsetX       = -30,          -- ліво ↔ право: мінус = лівіше, плюс = правіше
    idOffsetY       = -45,          -- низ ↔ верх:  плюс = вище, мінус = нижче
    idWidth         = 56,           -- ширина кнопки ID
    idHeight        = 18,           -- висота кнопки ID
    idColor         = {1.0, 0.82, 0.0},  -- колір тексту ID (R, G, B)

    dbUrl           = "https://octowow.st/db/?quest=",  -- посилання на БД при кліку

    -- затримка перед підміною (сек) — якщо інший аддон перезаписує текст
    translateDelay  = 0.12,
}

--[[============================================================================
    КОД
============================================================================]]

local DB = OceQuestUA_DB or {}
local showUA = true
local currentQuestId = nil
local debugMode = false

local function Debug(msg)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[OQUA]|r " .. tostring(msg))
    end
end


OceQuestUA_Settings = OceQuestUA_Settings or {}

-- byTitleList[title] = { data1, data2, ... }  — кілька квестів з однаковою назвою
local byTitleList = {}
local byTitleLowerList = {}
local byTitleSoftList = {}

local function NormalizeTitle(s)
    if not s then return "" end
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    -- strip wow color codes
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")

    -- unify quotes/apostrophes (UTF-8 as decimal escapes)
    s = string.gsub(s, "\226\128\152", "'")
    s = string.gsub(s, "\226\128\153", "'")
    s = string.gsub(s, "\226\128\154", "'")
    s = string.gsub(s, "\226\128\155", "'")
    s = string.gsub(s, "\226\128\156", "\"")
    s = string.gsub(s, "\226\128\157", "\"")
    s = string.gsub(s, "\226\128\158", "\"")
    s = string.gsub(s, "\226\128\159", "\"")
    s = string.gsub(s, "\202\188", "'")
    s = string.gsub(s, "\202\185", "'")
    s = string.gsub(s, "`", "'")
    s = string.gsub(s, "\194\180", "'")

    -- unwrap surrounding quotes
    local inner = string.gsub(s, "^\"(.*)\"$", "%1")
    if inner ~= s then s = inner end
    inner = string.gsub(s, "^'(.*)'$", "%1")
    if inner ~= s then s = inner end

    s = string.gsub(s, "%s+", " ")
    return s
end

-- Реальний quest ID (SuperWoW / кадр / журнал)
local function NormalizeQuestId(id)
    id = tonumber(id)
    if id and id > 0 then return id end
    return nil
end

local function GetCurrentQuestID()
    -- 1) SuperWoW / Oce API
    if type(GetQuestID) == "function" then
        local ok, id = pcall(GetQuestID)
        if ok then
            id = NormalizeQuestId(id)
            if id then return id end
        end
    end

    -- 2) Поля на QuestFrame (інші аддони / клієнт)
    if QuestFrame then
        local id = NormalizeQuestId(
            QuestFrame.questID or QuestFrame.questId or QuestFrame.QID
            or QuestFrame.questid or QuestFrame.QuestID
        )
        if id then return id end
    end

    -- 3) Вибраний рядок у журналі квестів
    if GetQuestLogSelection and GetQuestLogTitle then
        local sel = GetQuestLogSelection()
        if sel and sel > 0 then
            local qt, level, tag, isHeader, isCollapsed, isComplete, freq, qid = GetQuestLogTitle(sel)
            if not isHeader then
                qid = NormalizeQuestId(qid)
                if qid then return qid end
                if type(GetQuestLink) == "function" then
                    local link = GetQuestLink(sel)
                    if link then
                        local _, _, sid = string.find(link, "quest:(%d+)")
                        qid = NormalizeQuestId(sid)
                        if qid then return qid end
                    end
                end
            end
        end
    end

    return nil
end

-- ID з журналу: спочатку вибраний рядок, інакше єдиний збіг за назвою
local function GetQuestIDFromLog(title)
    if not title or not GetNumQuestLogEntries or not GetQuestLogTitle then return nil end
    local want = NormalizeTitle(title)
    if want == "" then return nil end

    -- вибраний у журналі з тією ж назвою — найнадійніше
    if GetQuestLogSelection then
        local sel = GetQuestLogSelection()
        if sel and sel > 0 then
            local qt, level, tag, isHeader, isCollapsed, isComplete, freq, qid = GetQuestLogTitle(sel)
            if not isHeader and qt and NormalizeTitle(qt) == want then
                qid = NormalizeQuestId(qid)
                if qid then return qid end
                if type(GetQuestLink) == "function" then
                    local link = GetQuestLink(sel)
                    if link then
                        local _, _, sid = string.find(link, "quest:(%d+)")
                        qid = NormalizeQuestId(sid)
                        if qid then return qid end
                    end
                end
            end
        end
    end

    local matches = {}
    local n = GetNumQuestLogEntries()
    local i
    for i = 1, n do
        local qt, level, tag, isHeader, isCollapsed, isComplete, freq, qid = GetQuestLogTitle(i)
        if not isHeader and qt and NormalizeTitle(qt) == want then
            qid = NormalizeQuestId(qid)
            if not qid and type(GetQuestLink) == "function" then
                local link = GetQuestLink(i)
                if link then
                    local _, _, sid = string.find(link, "quest:(%d+)")
                    qid = NormalizeQuestId(sid)
                end
            end
            if qid then
                matches[table.getn(matches) + 1] = qid
            end
        end
    end
    if table.getn(matches) == 1 then
        return matches[1]
    end
    return nil
end

-- які ID з списку зараз є в журналі квестів
local function QuestIdsInLog()
    local set = {}
    if not GetNumQuestLogEntries or not GetQuestLogTitle then return set end
    local i
    for i = 1, GetNumQuestLogEntries() do
        local qt, level, tag, isHeader, isCollapsed, isComplete, freq, qid = GetQuestLogTitle(i)
        if not isHeader then
            qid = NormalizeQuestId(qid)
            if not qid and type(GetQuestLink) == "function" then
                local link = GetQuestLink(i)
                if link then
                    local _, _, sid = string.find(link, "quest:(%d+)")
                    qid = NormalizeQuestId(sid)
                end
            end
            if qid then set[qid] = true end
        end
    end
    return set
end

local function AddToList(map, key, data)
    if not key or key == "" then return end
    local list = map[key]
    if not list then
        list = {}
        map[key] = list
    end
    -- не дублювати той самий id
    local i
    for i = 1, table.getn(list) do
        if list[i].id == data.id then return end
    end
    list[table.getn(list) + 1] = data
end


local function SoftKey(s)
    if not s then return "" end
    s = string.lower(s)
    s = string.gsub(s, "[%.,:;!%?'\"-]", "")
    s = string.gsub(s, "%s+", " ")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

local function RebuildIndex()
    byTitleList = {}
    byTitleLowerList = {}
    byTitleSoftList = {}
    local count, skipped, multi = 0, 0, 0
    for id, data in pairs(DB) do
        if type(data) == "table" then
            data.id = id
            local en = data.en and NormalizeTitle(data.en) or ""
            if en ~= "" then
                AddToList(byTitleList, en, data)
                AddToList(byTitleLowerList, string.lower(en), data)
                do
                    local sk = SoftKey(en)
                    if sk ~= "" then AddToList(byTitleSoftList, sk, data) end
                end
                local bare = string.gsub(en, "^%[%*%]%s*", "")
                if bare ~= en and bare ~= "" then
                    AddToList(byTitleList, bare, data)
                    AddToList(byTitleLowerList, string.lower(bare), data)
                end
                if not string.find(en, "^%[%*%]") then
                    AddToList(byTitleList, "[*] " .. en, data)
                    AddToList(byTitleLowerList, string.lower("[*] " .. en), data)
                end
                count = count + 1
            else
                skipped = skipped + 1
            end
        end
    end
    for _, list in pairs(byTitleList) do
        if table.getn(list) > 1 then multi = multi + 1 end
    end
    return count, skipped, multi
end

local indexCount, indexSkipped, indexMulti = RebuildIndex()

local function NormCmp(s)
    if not s then return "" end
    s = string.lower(s)
    s = string.gsub(s, "%s+", " ")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

-- збіг англ. тексту з клієнта (GetQuestText/GetObjectiveText) і знімка pfQuest
local function ScoreByEnglishBody(id)
    local en = OceUA_PfQuest_EN and OceUA_PfQuest_EN[id]
    if not en then return 0 end
    local score = 0
    local qt = GetQuestText and GetQuestText() or ""
    local ot = GetObjectiveText and GetObjectiveText() or ""
    local pt = GetProgressText and GetProgressText() or ""
    qt, ot, pt = NormCmp(qt), NormCmp(ot), NormCmp(pt)
    local ed = NormCmp(en.D)
    local eo = NormCmp(en.O)
    if ed ~= "" and qt ~= "" then
        if ed == qt then
            score = score + 200
        elseif string.len(qt) > 30 and string.find(ed, string.sub(qt, 1, 40), 1, true) then
            score = score + 80
        elseif string.len(ed) > 30 and string.find(qt, string.sub(ed, 1, 40), 1, true) then
            score = score + 80
        end
    end
    if eo ~= "" and ot ~= "" then
        if eo == ot then
            score = score + 200
        elseif string.len(ot) > 20 and string.find(eo, string.sub(ot, 1, 30), 1, true) then
            score = score + 80
        elseif string.len(eo) > 20 and string.find(ot, string.sub(eo, 1, 30), 1, true) then
            score = score + 80
        end
    end
    -- progress text інколи збігається з D/O
    if pt ~= "" and ed ~= "" and (pt == ed or string.find(ed, string.sub(pt, 1, math.min(30, string.len(pt))), 1, true)) then
        score = score + 40
    end
    return score
end

local function PickFromList(list, preferredId)
    if not list or table.getn(list) == 0 then return nil end
    if table.getn(list) == 1 then return list[1] end

    preferredId = NormalizeQuestId(preferredId)
    if preferredId then
        local i
        for i = 1, table.getn(list) do
            if NormalizeQuestId(list[i].id) == preferredId then
                Debug("PickFromList: exact id " .. tostring(preferredId))
                return list[i]
            end
        end
    end

    -- серед дублікатів назви: який саме квест у журналі
    local inLog = QuestIdsInLog()
    local logHits = {}
    local i
    for i = 1, table.getn(list) do
        local id = NormalizeQuestId(list[i].id)
        if id and inLog[id] then
            logHits[table.getn(logHits) + 1] = list[i]
        end
    end
    if table.getn(logHits) == 1 then
        Debug("PickFromList: single in-log match id=" .. tostring(logHits[1].id))
        return logHits[1]
    end
    if table.getn(logHits) > 1 and GetQuestLogSelection then
        local sel = GetQuestLogSelection()
        if sel and sel > 0 then
            local qt, level, tag, isHeader, isCollapsed, isComplete, freq, qid = GetQuestLogTitle(sel)
            qid = NormalizeQuestId(qid)
            if qid then
                for i = 1, table.getn(logHits) do
                    if NormalizeQuestId(logHits[i].id) == qid then
                        Debug("PickFromList: log selection id=" .. tostring(qid))
                        return logHits[i]
                    end
                end
            end
        end
    end

    -- головне для однакових назв: збіг англ. опису/цілей із клієнта
    local best, bestScore = nil, 0
    for i = 1, table.getn(list) do
        local id = NormalizeQuestId(list[i].id)
        if id then
            local sc = ScoreByEnglishBody(id)
            if sc > bestScore then
                bestScore = sc
                best = list[i]
            end
        end
    end
    if best and bestScore > 0 then
        Debug("PickFromList: EN-body match id=" .. tostring(best.id) .. " score=" .. tostring(bestScore))
        return best
    end

    Debug("PickFromList: ambiguous, fallback first of " .. tostring(table.getn(list)))
    return list[1]
end

local function FindTranslation(englishTitle)
    -- 1) Пріоритет: реальний ID з вікна квесту / логу
    local qid = GetCurrentQuestID()
    if not qid then
        qid = GetQuestIDFromLog(englishTitle)
    end
    if qid then
        local row = DB[qid] or DB[tostring(qid)]
        if type(row) == "table" then
            row.id = qid
            Debug("FOUND by id=" .. tostring(qid))
            return row
        end
        Debug("id=" .. tostring(qid) .. " not in DB, fallback title")
    end

    if not englishTitle or englishTitle == "" then return nil end
    local t = NormalizeTitle(englishTitle)

    local list = byTitleList[t]
    if list then
        Debug("FOUND by exact title")
        return PickFromList(list, qid)
    end

    list = byTitleLowerList[string.lower(t)]
    if list then
        Debug("FOUND by lower title")
        return PickFromList(list, qid)
    end

    local bare = string.gsub(t, "^%[%*%]%s*", "")
    if bare ~= t then
        list = byTitleList[bare] or byTitleLowerList[string.lower(bare)]
        if list then return PickFromList(list, qid) end
    end

    list = byTitleList["[*] " .. t] or byTitleLowerList[string.lower("[*] " .. t)]
    if list then return PickFromList(list, qid) end

    -- 2) М'який збіг через індекс (O(1), без повного pairs)
    local soft = SoftKey(t)
    if soft ~= "" then
        local lst = byTitleSoftList[soft]
        if lst then
            Debug("FOUND by soft title")
            return PickFromList(lst, qid)
        end
    end

    Debug("NOT FOUND title=[" .. t .. "] qid=" .. tostring(qid))
    return nil
end

local function FormatQuestText(text)
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
        fs:SetText(FormatQuestText(text))
    end
end

local function TranslateDetail()
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return end
    local title = GetTitleText and GetTitleText() or nil
    Debug("DETAIL title=[" .. tostring(title) .. "]")
    if not title then return end
    if not showUA then
        if QuestTitleText then QuestTitleText:SetText(title) end
        if QuestDescription and GetQuestText then QuestDescription:SetText(GetQuestText()) end
        if QuestObjectiveText and GetObjectiveText then QuestObjectiveText:SetText(GetObjectiveText()) end
        return
    end
    local tr = FindTranslation(title)
    if not tr then
        Debug("не знайдено en для: [" .. tostring(title) .. "]")
        return
    end
    Debug("знайдено ID " .. tostring(tr.id) .. " T=" .. tostring(tr.T))
    if tr.T then SafeSetText(QuestTitleText, tr.T) end
    if tr.D then SafeSetText(QuestDescription, tr.D) end
    if tr.O then SafeSetText(QuestObjectiveText, tr.O) end
end

local function TranslateProgress()
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return end
    local title = GetTitleText and GetTitleText() or nil
    Debug("PROGRESS title=[" .. tostring(title) .. "]")
    if not title then return end
    if not showUA then
        if QuestProgressTitleText then QuestProgressTitleText:SetText(title) end
        if QuestProgressText and GetProgressText then QuestProgressText:SetText(GetProgressText()) end
        return
    end
    local tr = FindTranslation(title)
    if not tr then return end
    if tr.T then SafeSetText(QuestProgressTitleText, tr.T) end
    if tr.P then SafeSetText(QuestProgressText, tr.P) end
end

local function TranslateReward()
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return end
    local title = GetTitleText and GetTitleText() or nil
    Debug("REWARD title=[" .. tostring(title) .. "]")
    if not title then return end
    if not showUA then
        if QuestRewardTitleText then QuestRewardTitleText:SetText(title) end
        if QuestRewardText and GetRewardText then QuestRewardText:SetText(GetRewardText()) end
        return
    end
    local tr = FindTranslation(title)
    if not tr then return end
    if tr.T then SafeSetText(QuestRewardTitleText, tr.T) end
    if tr.C then SafeSetText(QuestRewardText, tr.C) end
end

local function RefreshCurrent()
    if QuestFrameDetailPanel and QuestFrameDetailPanel:IsVisible() then
        if QuestTitleText and GetTitleText then QuestTitleText:SetText(GetTitleText()) end
        if QuestDescription and GetQuestText then QuestDescription:SetText(GetQuestText()) end
        if QuestObjectiveText and GetObjectiveText then QuestObjectiveText:SetText(GetObjectiveText()) end
        if showUA then TranslateDetail() end
    elseif QuestFrameProgressPanel and QuestFrameProgressPanel:IsVisible() then
        if QuestProgressTitleText and GetTitleText then QuestProgressTitleText:SetText(GetTitleText()) end
        if QuestProgressText and GetProgressText then QuestProgressText:SetText(GetProgressText()) end
        if showUA then TranslateProgress() end
    elseif QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() then
        if QuestRewardTitleText and GetTitleText then QuestRewardTitleText:SetText(GetTitleText()) end
        if QuestRewardText and GetRewardText then QuestRewardText:SetText(GetRewardText()) end
        if showUA then TranslateReward() end
    end
end

-- ========== Кнопка UA/EN ==========
local btn = CreateFrame("Button", "OceQuestUA_Toggle", QuestFrame, "UIPanelButtonTemplate")
btn:SetWidth(36)
btn:SetHeight(20)
-- кнопка UA/EN: TOPRIGHT вікна квесту, X=-55 (лівіше), Y=-20 (нижче від верху)
btn:SetPoint("TOPRIGHT", QuestFrame, "TOPRIGHT", -55, -20)
btn:SetFrameLevel(QuestFrame:GetFrameLevel() + 10)
btn:SetText("UA")

btn:SetScript("OnClick", function()
    showUA = not showUA
    this:SetText(showUA and "UA" or "EN")
    RefreshCurrent()
end)

btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    if showUA then
        GameTooltip:AddLine("OceQuestUA: українська", 1, 1, 0)
        GameTooltip:AddLine("Клік — оригінал (EN)", 1, 1, 1)
    else
        GameTooltip:AddLine("OceQuestUA: English", 1, 1, 0)
        GameTooltip:AddLine("Клік — переклад (UA)", 1, 1, 1)
    end
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ========== Кнопка ID ==========
local idBtn = CreateFrame("Button", "OceQuestUA_IDBtn", QuestFrame)
idBtn:SetWidth(CONFIG.idWidth)
idBtn:SetHeight(CONFIG.idHeight)
idBtn:SetFrameLevel(QuestFrame:GetFrameLevel() + 10)
idBtn:EnableMouse(true)
idBtn:SetMovable(true)
idBtn:RegisterForDrag("LeftButton")
idBtn:RegisterForClicks("LeftButtonUp")

idBtn:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
idBtn:SetBackdropColor(0.1, 0.1, 0.15, 0.85)
idBtn:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)

local idText = idBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
idText:SetAllPoints()
idText:SetJustifyH("CENTER")
idText:SetTextColor(CONFIG.idColor[1], CONFIG.idColor[2], CONFIG.idColor[3])
idText:SetText("")

local function PlaceIdButton()
    idBtn:ClearAllPoints()
    local s = OceQuestUA_Settings
    if s and s.idX and s.idY then
        idBtn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.idX, s.idY)
    else
        idBtn:SetPoint(CONFIG.idPoint, QuestFrame, CONFIG.idRelativePoint,
            CONFIG.idOffsetX, CONFIG.idOffsetY)
    end
end

idBtn:SetScript("OnDragStart", function()
    if IsShiftKeyDown() then
        this:StartMoving()
        this.isMoving = true
    end
end)

idBtn:SetScript("OnDragStop", function()
    if this.isMoving then
        this:StopMovingOrSizing()
        this.isMoving = false
        local x, y = this:GetLeft(), this:GetBottom()
        OceQuestUA_Settings = OceQuestUA_Settings or {}
        OceQuestUA_Settings.idX = x
        OceQuestUA_Settings.idY = y
    end
end)

idBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    if currentQuestId then
        GameTooltip:AddLine("Quest ID: " .. tostring(currentQuestId), 1, 0.82, 0)
        GameTooltip:AddLine("Клік — посилання на octowow.st", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine("Shift+перетягнути — рухати", 0.5, 0.8, 0.5)
    GameTooltip:Show()
end)
idBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local linkFrame = CreateFrame("Frame", "OceQuestUA_LinkFrame", UIParent)
linkFrame:SetWidth(400)
linkFrame:SetHeight(90)
linkFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
linkFrame:SetFrameStrata("DIALOG")
linkFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
linkFrame:Hide()
linkFrame:EnableMouse(true)
linkFrame:SetMovable(true)
linkFrame:RegisterForDrag("LeftButton")
linkFrame:SetScript("OnDragStart", function() this:StartMoving() end)
linkFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

local linkTitle = linkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
linkTitle:SetPoint("TOP", linkFrame, "TOP", 0, -14)
linkTitle:SetText("OceQuestUA — посилання")

local linkEdit = CreateFrame("EditBox", "OceQuestUA_LinkEdit", linkFrame)
linkEdit:SetWidth(360)
linkEdit:SetHeight(20)
linkEdit:SetPoint("TOP", linkTitle, "BOTTOM", 0, -10)
linkEdit:SetFontObject(GameFontHighlight)
linkEdit:SetAutoFocus(false)
linkEdit:SetScript("OnEscapePressed", function() this:ClearFocus(); linkFrame:Hide() end)
linkEdit:SetScript("OnEditFocusGained", function() this:HighlightText() end)

local linkClose = CreateFrame("Button", nil, linkFrame, "UIPanelButtonTemplate")
linkClose:SetWidth(80)
linkClose:SetHeight(22)
linkClose:SetPoint("BOTTOM", linkFrame, "BOTTOM", 0, 12)
linkClose:SetText("Закрити")
linkClose:SetScript("OnClick", function() linkFrame:Hide() end)

local function ShowQuestLink(qid)
    if not qid then return end
    local url = CONFIG.dbUrl .. tostring(qid)
    linkEdit:SetText(url)
    linkFrame:Show()
    linkEdit:SetFocus()
    linkEdit:HighlightText()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rQuestUA " .. url)
end

idBtn:SetScript("OnClick", function()
    if this.isMoving then return end
    if currentQuestId then
        ShowQuestLink(currentQuestId)
    end
end)

local function UpdateQuestId()
    currentQuestId = nil
    local title = GetTitleText and GetTitleText() or nil
    -- спочатку реальний ID з клієнта
    local qid = GetCurrentQuestID() or (title and GetQuestIDFromLog(title)) or nil
    if qid and type(DB[qid]) == "table" then
        currentQuestId = qid
    elseif title then
        local tr = FindTranslation(title)
        if tr and tr.id then
            currentQuestId = tr.id
        end
    end
    if currentQuestId then
        idText:SetText(string.format(CONFIG.idFormat, currentQuestId))
        idBtn:Show()
    else
        idText:SetText("")
        idBtn:Hide()
    end
end

local function UpdateButton()
    if QuestFrame and QuestFrame:IsVisible() then
        btn:Show()
        btn:SetText(showUA and "UA" or "EN")
        UpdateQuestId()
    else
        btn:Hide()
        idBtn:Hide()
    end
end

local function HookPanel(panelName, translateFunc)
    local panel = getglobal(panelName)
    if not panel then return end
    local oldOnShow = panel:GetScript("OnShow")
    panel:SetScript("OnShow", function()
        if oldOnShow then oldOnShow() end
        this._oq_timer = CONFIG.translateDelay
        UpdateButton()
    end)
    if not panel._oq_hooked then
        panel._oq_hooked = true
        local oldUpdate = panel:GetScript("OnUpdate")
        panel:SetScript("OnUpdate", function()
            if oldUpdate then oldUpdate() end
            if this._oq_timer then
                this._oq_timer = this._oq_timer - arg1
                if this._oq_timer <= 0 then
                    this._oq_timer = nil
                    translateFunc()
                    UpdateQuestId()
                end
            end
        end)
    end
end


-- ========== Quest Log (журнал квестів) ==========
local function GetSelectedLogTitle()
    if not GetQuestLogSelection or not GetQuestLogTitle then return nil, nil end
    local sel = GetQuestLogSelection()
    if not sel or sel < 1 then return nil, nil end
    local qt, level = GetQuestLogTitle(sel)
    if not qt then return nil, nil end
    qt = string.gsub(qt, "%s*%-%s*%([^%)]+%)%s*$", "")
    qt = string.gsub(qt, "%s*%([^%)]+%)%s*$", "")
    return qt, level
end

local LOG_TAGS = {
    ["(Complete)"] = "(Виконано)",
    ["(Failed)"] = "(Провалено)",
    ["(Dungeon)"] = "(Підземелля)",
    ["(Elite)"] = "(Елітний)",
    ["(Raid)"] = "(Рейд)",
    ["(PvP)"] = "(PvP)",
    ["(Group)"] = "(Група)",
    ["(Daily)"] = "(Щоденний)",
    ["(Heroic)"] = "(Героїчний)",
}

local function TranslateLogTag(s)
    if not s then return s end
    if LOG_TAGS[s] then return LOG_TAGS[s] end
    s = string.gsub(s, "%(Complete%)", "(Виконано)")
    s = string.gsub(s, "%(Failed%)", "(Провалено)")
    s = string.gsub(s, "%(Dungeon%)", "(Підземелля)")
    s = string.gsub(s, "%(Elite%)", "(Елітний)")
    s = string.gsub(s, "%(Raid%)", "(Рейд)")
    s = string.gsub(s, "%(PvP%)", "(PvP)")
    s = string.gsub(s, "%(Group%)", "(Група)")
    return s
end

-- пошук UA для фрагмента (моб / предмет / NPC / об'єкт)
local function LookupWorldName(en)
    if not en or en == "" then return nil end
    en = string.gsub(en, "^%s+", "")
    en = string.gsub(en, "%s+$", "")
    local d
    d = OceUA_Item_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    d = OceUA_Mobs_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    d = OceUA_NPC_Names_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    d = OceUA_Objects_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    d = OceUA_Signs_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    -- часткова заміна відомих назв у довгих цілях (Go to the top of X)
    if string.len(en) > 24 then
        local best, bestLen, bestUA = nil, 0, nil
        local dicts = { OceUA_Objects_Dictionary, OceUA_Mobs_Dictionary, OceUA_Item_Dictionary, OceUA_NPC_Names_Dictionary }
        local di
        for di = 1, table.getn(dicts) do
            local dict = dicts[di]
            if dict then
                local k, v
                for k, v in pairs(dict) do
                    if type(k) == "string" and type(v) == "string" and v ~= "" and string.len(k) >= 5 then
                        if string.len(k) > bestLen and string.find(en, k, 1, true) then
                            best, bestLen, bestUA = k, string.len(k), v
                        end
                    end
                end
            end
        end
        if best and bestUA then
            local out = string.gsub(en, best, bestUA, 1)
            -- типові дієслова цілей
            out = string.gsub(out, "^Go to the top of the ", "Піднімись на вершину ")
            out = string.gsub(out, "^Go to the ", "Йди до ")
            out = string.gsub(out, "^Travel to ", "Відправляйся до ")
            out = string.gsub(out, " in ", " у ")
            out = string.gsub(out, "%.$", ".")
            return out
        end
    end
    return nil
end

-- у рядку цілі замінити відомі EN-назви (довші першими не сортуємо масово —
-- простий прохід: якщо весь рядок без лічильника збігається; або "Name: 0/10")
local function TranslateObjectiveLine(text)
    if not text or text == "" then return text end
    if string.find(text, "[А-Яа-яІіЇїЄєҐґ]") then return text end

    local original = text
    local lead = ""
    -- "- Name: 0/1" з трекера
    local _, _, dash, rest0 = string.find(text, "^(%s*%-%s*)(.*)$")
    if dash and rest0 then
        lead = dash
        text = rest0
    end

    local prefix = ""
    local _, _, cnt, rest = string.find(text, "^(%d+/%d+)%s+(.+)$")
    if cnt and rest then
        prefix = cnt .. " "
        text = rest
    end

    -- "Name: 0/5"
    local _, _, nm, cnt2 = string.find(text, "^(.+):%s*(%d+/%d+)%s*$")
    if nm and cnt2 then
        nm = string.gsub(nm, "^%s+", "")
        nm = string.gsub(nm, "%s+$", "")
        nm = string.gsub(nm, "^%-%s*", "")
        local ua = LookupWorldName(nm)
        if not ua then
            -- варіант без апострофа / з `
            local alt = string.gsub(nm, "'", "")
            alt = string.gsub(alt, "`", "")
            ua = LookupWorldName(alt)
        end
        if not ua then
            local base = string.gsub(nm, "%s+slain%s*$", "")
            base = string.gsub(base, "%s+killed%s*$", "")
            ua = LookupWorldName(base)
        end
        if ua then return lead .. ua .. ": " .. cnt2 end
        return original
    end

    local verbUA = nil
    local base = text
    if string.find(base, "%s+slain%s*$") then
        base = string.gsub(base, "%s+slain%s*$", "")
        verbUA = "убито"
    elseif string.find(base, "%s+killed%s*$") then
        base = string.gsub(base, "%s+killed%s*$", "")
        verbUA = "убито"
    elseif string.find(base, "%s+destroyed%s*$") then
        base = string.gsub(base, "%s+destroyed%s*$", "")
        verbUA = "знищено"
    elseif string.find(base, "%s+collected%s*$") then
        base = string.gsub(base, "%s+collected%s*$", "")
        verbUA = "зібрано"
    end
    base = string.gsub(base, "%s+$", "")
    base = string.gsub(base, "^%s+", "")

    local ua = LookupWorldName(base)
    if ua then
        if verbUA then
            return lead .. prefix .. ua .. " (" .. verbUA .. ")"
        end
        return lead .. prefix .. ua
    end
    ua = LookupWorldName(original)
    if ua then return ua end
    return original
end

local function TranslateQuestLogDetails()
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return end
    if not showUA then return end
    if not QuestLogFrame or not QuestLogFrame:IsVisible() then return end

    local title, qlevel = GetSelectedLogTitle()
    if not title or title == "" then return end

    local tr = FindTranslation(title)

    -- заголовок + рівень завжди (навіть без повного перекладу — рівень з клієнта)
    if QuestLogQuestTitle then
        local display
        if tr and tr.T then
            display = FormatQuestText(tr.T)
        else
            display = title
        end
        if qlevel and tonumber(qlevel) and tonumber(qlevel) > 0 then
            display = display .. " [" .. tostring(qlevel) .. "]"
        end
        if IsCurrentQuestFailed and IsCurrentQuestFailed() then
            display = display .. " - (Провалено)"
        end
        QuestLogQuestTitle:SetText(display)
    end

    if tr then
        if tr.O and QuestLogObjectivesText then
            SafeSetText(QuestLogObjectivesText, tr.O)
        end
        if tr.D and QuestLogQuestDescription then
            SafeSetText(QuestLogQuestDescription, tr.D)
        end
    end

    -- рядки прогресу цілей (моб/предмет якщо є в базі)
    if GetNumQuestLeaderBoards then
        local nobj = GetNumQuestLeaderBoards() or 0
        local i
        for i = 1, nobj do
            local fs = getglobal("QuestLogObjective" .. i)
            if fs then
                local text, otype, finished = GetQuestLogLeaderBoard(i)
                if text then
                    local ua = TranslateObjectiveLine(text)
                    if ua then fs:SetText(ua) end
                end
            end
        end
    end

    -- нагороди: назви предметів на кнопках
    local ri
    for ri = 1, 10 do
        local btn = getglobal("QuestLogItem" .. ri)
        if btn then
            local nameFS = getglobal("QuestLogItem" .. ri .. "Name")
            if not nameFS and btn.Name then nameFS = btn.Name end
            if nameFS then
                local iname = nameFS:GetText()
                if iname and not string.find(iname, "[А-Яа-яІіЇїЄєҐґ]") then
                    local ua = LookupWorldName(iname)
                    if ua then nameFS:SetText(ua) end
                end
            end
        end
    end

    if QuestLogDescriptionTitle then
        QuestLogDescriptionTitle:SetText("Опис")
    end
    if QuestLogRewardTitleText then
        QuestLogRewardTitleText:SetText("Нагороди")
    end
    if QuestLogItemChooseText then
        local tx = QuestLogItemChooseText:GetText()
        if tx and string.find(tx, "Choose") then
            QuestLogItemChooseText:SetText("Оберіть нагороду:")
        end
    end
    if QuestLogItemReceiveText then
        local tx = QuestLogItemReceiveText:GetText()
        if tx and (string.find(tx, "receive") or string.find(tx, "Receive") or string.find(tx, "Rewards") or string.find(tx, "will receive")) then
            QuestLogItemReceiveText:SetText("Ви отримаєте:")
        end
    end
    if QuestLogTitleText then
        QuestLogTitleText:SetText("Журнал квестів")
    end
end

local function TranslateQuestLogList()
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return end
    if not showUA then return end
    if not GetNumQuestLogEntries or not GetQuestLogTitle then return end

    local n = GetNumQuestLogEntries()
    local i
    for i = 1, n do
        local qt, level, tag, isHeader = GetQuestLogTitle(i)
        if qt and not isHeader then
            local clean = string.gsub(qt, "%s*%-%s*%([^%)]+%)%s*$", "")
            clean = string.gsub(clean, "%s*%([^%)]+%)%s*$", "")
            local tr = FindTranslation(clean)
            local btn = getglobal("QuestLogTitle" .. i)
            if not btn then btn = getglobal("QuestLogTitleButton" .. i) end
            if btn then
                local label = clean
                if tr and tr.T then
                    label = FormatQuestText(tr.T)
                end
                -- рівень біля назви в списку
                if level and tonumber(level) and tonumber(level) > 0 then
                    label = "[" .. tostring(level) .. "] " .. label
                end
                local nt = getglobal((btn:GetName() or "") .. "NormalText")
                if nt then
                    nt:SetText(label)
                elseif btn.SetText then
                    btn:SetText(label)
                end
            end
            local tagFS = getglobal("QuestLogTitle" .. i .. "Tag")
            if not tagFS then tagFS = getglobal("QuestLogTitleButton" .. i .. "Tag") end
            if tagFS then
                local tg = tagFS:GetText()
                if tg then
                    local ua = TranslateLogTag(tg)
                    if ua and ua ~= tg then tagFS:SetText(ua) end
                end
            end
        end
    end
end

local function TranslateQuestLog()
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return end
    TranslateQuestLogList()
    TranslateQuestLogDetails()
end

-- без затримки = без блимання EN→UA; клієнт уже намалював кадр — одразу перебиваємо
local function ScheduleQuestLogTranslate()
    if not QuestLogFrame or not QuestLogFrame:IsVisible() then return end
    pcall(TranslateQuestLog)
end

if QuestLogFrame then
    local oldQLShow = QuestLogFrame:GetScript("OnShow")
    QuestLogFrame:SetScript("OnShow", function()
        if oldQLShow then oldQLShow() end
        ScheduleQuestLogTranslate()
    end)
end

if type(QuestLog_UpdateQuestDetails) == "function" then
    local _oldDetails = QuestLog_UpdateQuestDetails
    QuestLog_UpdateQuestDetails = function(a1, a2, a3, a4)
        _oldDetails(a1, a2, a3, a4)
        ScheduleQuestLogTranslate()
    end
end
if type(QuestLog_Update) == "function" then
    local _oldQLU = QuestLog_Update
    QuestLog_Update = function(a1, a2, a3, a4)
        _oldQLU(a1, a2, a3, a4)
        ScheduleQuestLogTranslate()
    end
end

HookPanel("QuestFrameDetailPanel", TranslateDetail)
HookPanel("QuestFrameProgressPanel", TranslateProgress)
HookPanel("QuestFrameRewardPanel", TranslateReward)

local f = CreateFrame("Frame")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_FINISHED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "OceUA" then
        OceQuestUA_Settings = OceQuestUA_Settings or {}
        PlaceIdButton()
        return
    end
    if event == "PLAYER_LOGIN" then
        PlaceIdButton()
        return
    end
    if event == "QUEST_FINISHED" then
        btn:Hide()
        idBtn:Hide()
        return
    end
    if event == "QUEST_LOG_UPDATE" then
        ScheduleQuestLogTranslate()
        return
    end
    if event == "QUEST_DETAIL" then
        f.timer = CONFIG.translateDelay
        f.mode = "detail"
    elseif event == "QUEST_PROGRESS" then
        f.timer = CONFIG.translateDelay
        f.mode = "progress"
    elseif event == "QUEST_COMPLETE" then
        f.timer = CONFIG.translateDelay
        f.mode = "reward"
    end
    UpdateButton()
end)

f:SetScript("OnUpdate", function()
    if this.timer then
        this.timer = this.timer - arg1
        if this.timer <= 0 then
            this.timer = nil
            if this.mode == "detail" then
                TranslateDetail()
            elseif this.mode == "progress" then
                TranslateProgress()
            elseif this.mode == "reward" then
                TranslateReward()
            end
            this.mode = nil
            UpdateQuestId()
        end
    end
end)

if QuestFrame then
    local oldShow = QuestFrame:GetScript("OnShow")
    QuestFrame:SetScript("OnShow", function()
        if oldShow then oldShow() end
        UpdateButton()
    end)
    local oldHide = QuestFrame:GetScript("OnHide")
    QuestFrame:SetScript("OnHide", function()
        if oldHide then oldHide() end
        btn:Hide()
        idBtn:Hide()
    end)
end

SLASH_OCEQUESTUA1 = "/oqua"
SLASH_OCEQUESTUA2 = "/ocequest"
SlashCmdList["OCEQUESTUA"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "count" then
        local n, skip = 0, 0
        for id, data in pairs(DB) do
            if type(data) == "table" then
                n = n + 1
                if not data.en or NormalizeTitle(data.en) == "" then
                    skip = skip + 1
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rQuestUA квестів: " .. n .. " | індекс: " .. indexCount)
        if indexMulti and indexMulti > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900  назв з кількома ID: " .. indexMulti .. "|r")
        end
        if skip > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900  без en: " .. skip .. "|r")
        end
        DEFAULT_CHAT_FRAME:AddMessage("  GetQuestID API: " .. (type(GetQuestID) == "function" and "є" or "немає"))
    elseif msg == "title" then
        local t = GetTitleText and GetTitleText() or nil
        local qid = GetCurrentQuestID()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rQuestUA GetTitleText:")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffffff[" .. tostring(t) .. "]|r")
        if t then
            DEFAULT_CHAT_FRAME:AddMessage("  довжина: " .. string.len(t))
        end
        DEFAULT_CHAT_FRAME:AddMessage("  GetQuestID: " .. tostring(qid or "nil"))
        local tr = FindTranslation(t)
        if tr then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00  → ID " .. tostring(tr.id) .. " | " .. tostring(tr.T) .. "|r")
            local list = t and byTitleList[NormalizeTitle(t)]
            if list and table.getn(list) > 1 then
                local ids = ""
                local i
                for i = 1, table.getn(list) do
                    if i > 1 then ids = ids .. ", " end
                    ids = ids .. tostring(list[i].id)
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cffff9900  дублікати en: " .. ids .. "|r")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900  → НЕ знайдено в базі|r")
            DEFAULT_CHAT_FRAME:AddMessage("  Скопіюй рядок у дужках [...] в поле en = \"...\"")
        end
    elseif msg == "debug" then
        debugMode = not debugMode
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rQuestUA debug: " .. (debugMode and "ON" or "OFF"))
    elseif msg == "toggle" then
        showUA = not showUA
        btn:SetText(showUA and "UA" or "EN")
        RefreshCurrent()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rQuestUA режим: " .. (showUA and "UA" or "EN"))
    elseif msg == "resetid" then
        OceQuestUA_Settings.idX = nil
        OceQuestUA_Settings.idY = nil
        PlaceIdButton()
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rQuestUA позицію ID скинуто")
    elseif string.find(msg, "^find ") then
        local q = string.sub(msg, 6)
        local tr = FindTranslation(q)
        if tr then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00  → ID " .. tostring(tr.id) .. " | " .. tostring(tr.T))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900  → не знайдено: [" .. q .. "]")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rQuestUA команди:")
        DEFAULT_CHAT_FRAME:AddMessage("  /oqua title   — англ. назва поточного квесту")
        DEFAULT_CHAT_FRAME:AddMessage("  /oqua count   — статистика бази")
        DEFAULT_CHAT_FRAME:AddMessage("  /oqua debug   — діагностика ON/OFF")
        DEFAULT_CHAT_FRAME:AddMessage("  /oqua toggle  — UA ↔ EN")
        DEFAULT_CHAT_FRAME:AddMessage("  /oqua resetid — скинути позицію ID")
    end
end

btn:Hide()
idBtn:Hide()
-- load message moved to OceUA (SkillUA)





-- ============================================================
-- OceUA Quest Tracker — компактний, біля правих екшн-барів
-- ============================================================
local function HasCyrQ(s)
    if not s then return false end
    return string.find(s, "[\208\209][\128-\191]") ~= nil
end

local function FormatTrackObjective(text)
    if not text or text == "" then return text end
    local s = string.gsub(text, "^%s*%-%s*", "")
    if not HasCyrQ(s) and TranslateObjectiveLine then
        s = TranslateObjectiveLine(s) or s
    end
    s = string.gsub(s, "^%s*%-%s*", "")
    s = string.gsub(s, "^%s*•%s*", "")
    s = string.gsub(s, "^%s*○%s*", "")
    s = string.gsub(s, "^%s*●%s*", "")
    -- прибрати зайві пробіли / подвійні пробіли
    s = string.gsub(s, "%s+", " ")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

local function SplitObjectiveNameCount(text)
    if not text then return text, nil end
    local _, _, name, cnt = string.find(text, "^(.-):%s*(%d+/%d+)%s*$")
    if name and cnt then
        name = string.gsub(name, "^%s+", "")
        name = string.gsub(name, "%s+$", "")
        return name, cnt
    end
    _, _, name, cnt = string.find(text, "^(.-)%s+(%d+/%d+)%s*$")
    if name and cnt and not string.find(name, "%d") then
        return name, cnt
    end
    return text, nil
end

-- UTF-8: string.len/sub у 1.12 рахують байти → кирилиця ламалась навпіл
-- рахуємо «графічні» символи; color-коди |cXXXXXXXX / |r не враховуємо в ширину
local function Utf8Next(s, i)
    local c = string.byte(s, i)
    if not c then return nil, i end
    if c < 128 then return i, i + 1 end
    if c < 224 then return i, i + 2 end
    if c < 240 then return i, i + 3 end
    return i, i + 4
end

local function WrapByWords(text, maxChars)
    if not text or text == "" then return text, 1 end
    if not maxChars or maxChars < 8 then maxChars = 40 end

    -- швидкий шлях: короткі ASCII-рядки
    local blen = string.len(text)
    if blen <= maxChars and not string.find(text, "[\208\209]") then
        return text, 1
    end

    local lines = {}
    local lineStart = 1
    local i = 1
    local col = 0
    local lastSpace = nil  -- byte index of last space candidate
    local lastSpaceCol = 0

    while i <= blen do
        -- пропуск wow color codes
        if string.sub(text, i, i) == "|" then
            local nx = string.sub(text, i + 1, i + 1)
            if nx == "c" or nx == "C" then
                i = i + 10  -- |cAARRGGBB
            elseif nx == "r" or nx == "R" then
                i = i + 2
            else
                local _, n = Utf8Next(text, i)
                i = n
                col = col + 1
            end
        else
            local ch = string.sub(text, i, i)
            local _, n = Utf8Next(text, i)
            if ch == " " or ch == "\n" then
                lastSpace = i
                lastSpaceCol = col
                if ch == "\n" then
                    local piece = string.sub(text, lineStart, i - 1)
                    piece = string.gsub(piece, "%s+$", "")
                    table.insert(lines, piece)
                    lineStart = n
                    col = 0
                    lastSpace = nil
                    i = n
                else
                    i = n
                    col = col + 1
                end
            else
                i = n
                col = col + 1
            end
        end

        if col >= maxChars then
            local breakAt
            if lastSpace and lastSpace >= lineStart then
                breakAt = lastSpace
            else
                -- немає пробілу — ріжемо тут (не розриваємо UTF-8)
                breakAt = i
            end
            local piece = string.sub(text, lineStart, breakAt - 1)
            piece = string.gsub(piece, "%s+$", "")
            if piece ~= "" then table.insert(lines, piece) end
            -- пропустити пробіли після розриву
            lineStart = breakAt
            while lineStart <= blen and string.sub(text, lineStart, lineStart) == " " do
                lineStart = lineStart + 1
            end
            i = lineStart
            col = 0
            lastSpace = nil
        end
    end

    if lineStart <= blen then
        local piece = string.gsub(string.sub(text, lineStart), "%s+$", "")
        if piece ~= "" then table.insert(lines, piece) end
    end

    if table.getn(lines) == 0 then return text, 1 end
    local out = lines[1]
    local li
    for li = 2, table.getn(lines) do
        out = out .. "\n" .. lines[li]
    end
    return out, table.getn(lines)
end

local TRK_MAX = 55
local TRK_LINE_H = 14
local TRK_WIDTH = 220  -- база; гравець може змінити (trkW / trkH)

local function GetTrkWidth()
    OceQuestUA_Settings = OceQuestUA_Settings or {}
    local w = OceQuestUA_Settings.trkW or TRK_WIDTH
    if w < 160 then w = 160 end
    if w > 420 then w = 420 end
    return w
end

local function GetTrkUserMaxH()
    -- висота більше не зберігається користувачем через resize;
    -- завжди рахується від мінімапи до action bars + позиція Shift-drag
    return nil
end


local function QuestDiffColor(level)
    local pl = UnitLevel("player") or 1
    level = tonumber(level) or pl
    local diff = level - pl
    local green = 8
    if GetQuestGreenRange then green = GetQuestGreenRange() or 8 end
    if diff >= 5 then return 1.0, 0.15, 0.15
    elseif diff >= 3 then return 1.0, 0.5, 0.25
    elseif diff >= -2 then return 1.0, 0.82, 0.0
    elseif diff >= -green then return 0.25, 0.75, 0.25
    end
    return 0.55, 0.55, 0.55
end

local function NormZone(s)
    if not s then return "" end
    s = string.lower(s)
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    -- прибрати типові префікси/суфікси, щоб "the barrens" ~= "barrens"
    s = string.gsub(s, "^the%s+", "")
    s = string.gsub(s, "%s+city$", "")
    s = string.gsub(s, "%s+forest$", "")
    s = string.gsub(s, "%s+woods$", "")
    s = string.gsub(s, "%s+", " ")
    return s
end

-- короткі аліаси зон (EN header ↔ те, що може повертати GetRealZoneText / UA)
-- Групи зон + субзон: усі назви в одній групі вважаються «однією локацією» для трекера.
-- Ключ — канонічна група; значення — список можливих назв (EN/UA, зони і субзони).
local ZONE_GROUPS = {
    ["elwynn"] = {
        "elwynn", "elwynn forest", "елвіннський ліс", "елвінн",
        "northshire", "northshire valley", "долина північного ширу", "північний шир",
        "goldshire", "голдшир", "золотошир'я",
        "eastvale", "eastvale logging camp", "східнодольний лісовий табір",
        "crystal lake", "кришталеве озеро",
        "stone cairn lake", "озеро кам'яних насипів",
        "jerod's landing", "висадка джерода",
        "brackwell pumpkin patch", "гарбузова плантація брекуелла",
        "forest's edge", "окраїна лісу",
        "tower of azora", "вежа азори",
        "mirror lake", "дзеркальне озеро",
        "stormwind", "stormwind city", "штормовій", "stormwind gate", "брама штормовію",
    },
    ["westfall"] = {
        "westfall", "західний край", "westfall lighthouse", "маяк західного краю",
        "moonbrook", "мунбрук", "sentinel hill", "пагорб вартових",
        "jangolode mine", "шахта джанголод", "the dead acre", "мертва нива",
        "furlbrow's pumpkin farm", "гарбузова ферма фарлброу",
        "alexston farmstead", "хутір алекстона", "saldean's farm", "ферма сальдена",
        "the molsen farm", "ферма мольсена", "demont's place", "місце демонта",
        "gold coast quarry", "кар'єр золотого узбережжя",
        "longshore", "довгий берег", "garrison armory", "збройова гарнізону",
    },
    ["redridge"] = {
        "redridge", "redridge mountains", "червоногор'я", "червоні гори",
        "lakeshire", "лейкшир", "lake everstill", "озеро безкрайньої тиші",
        "stonewatch", "каменезор", "stonewatch keep", "фортеця каменезору",
        "render's valley", "долина рендера", "render's camp", "табір рендера",
        "alther's mill", "млин альтера", "three corners", "три кути",
        "lakeview", "озерний краєвид",
    },
    ["duskwood"] = {
        "duskwood", "сутінколісся", "сутінковий ліс",
        "darkshire", "даркшир", "темний шир",
        "raven hill", "воронячий пагорб", "raven hill cemetery", "цвинтар воронячого пагорба",
        "the rotten orchard", "гнилий сад", "brightwood grove", "галявина світлого лісу",
        "the yorgen farmstead", "хутір йоргена", "addle's steading", "садиба аддла",
        "vul'gol ogre mound", "пагорб огрів вул'гол", "the darkened bank", "затемнений берег",
        "tranquil gardens cemetery", "цвинтар тихих садів",
    },
    ["lochmodan"] = {
        "loch modan", "лох модан", "thelsamar", "телсамар",
        "stonesplinter valley", "долина каменедробів", "ironband's excavation site", "розкопки залізокутих",
        "mo'grosh stronghold", "твердиня мо'грош", "the farstrider lodge", "садиба далекоходців",
        "north gate pass", "перевал північних воріт", "south gate pass", "перевал південних воріт",
        "algaz station", "станція алгаз", "valley of kings", "долина королів",
        "grubyridge", "грибовий хребет",
    },
    ["dunmorogh"] = {
        "dun morogh", "дун морог", "anvilmar", "ковадломар",
        "coldridge valley", "долина холодної гряди", "coldridge pass", "перевал холодної гряди",
        "kharanos", "харанос", "brewnall village", "селище броварні",
        "gomer's run", "пробіг гомера", "ironforge airfield", "аеродром залізогір'я",
        "misty pine refuge", "притулок туманної сосни", "the tundrid hills", "тундрові пагорби",
        "chill breeze valley", "долина холодного вітру", "shimmer ridge", "блискучий хребет",
        "gol'bolar quarry", "кар'єр гол'болар", "helms bed lake", "озеро ложа шолома",
        "ironforge", "залізогір'я", "ironforge gates",
    },
    ["wetlands"] = {
        "wetlands", "заболоття", "menethil harbor", "гавань менетил",
        "dun modr", "дун модр", "direforge hill", "пагорб зловісного кузня",
        "angerfang encampment", "табір лютого ікла", "whelgar's excavation site", "розкопки вельгара",
        "the green belt", "зелений пояс", "mosshide fen", "мохошкрябне болото",
        "raptor ridge", "хребет рапторів", "black channel marsh", "болото чорного каналу",
        "sundown marsh", "болото заходу сонця", "bluegill marsh", "болото синьозябрових",
        "salamander cove", "бухта саламандр", "ironbeard's tomb", "гробниця залізобородого",
    },
    ["teldrassil"] = {
        "teldrassil", "телдрассил", "shadowglen", "тіньова ущелина",
        "dolanaar", "доланаар", "starbreeze village", "селище зоряного вітру",
        "the oracle glade", "галявина оракула", "wellspring lake", "озеро джерела",
        "wellspring river", "річка джерела", "gnarlpine hold", "твердиня кривососнових",
        "ban'ethil barrow den", "курган бан'етіл", "lake al'ameth", "озеро ал'амет",
        "pools of arlithrien", "ставки арлітрієна", "rut'theran village", "селище рут'теран",
        "darnassus", "дарнасс",
    },
    ["darkshore"] = {
        "darkshore", "темний берег", "auberdine", "аубердін",
        "cliffspring river", "річка скелястого джерела", "bashal'aran", "башал'аран",
        "grove of the ancients", "гай древніх", "the master's glaive", "главій майстра",
        "remtravel's excavation", "розкопки ремтравеля", "tower of althalaxx", "вежа алталакса",
        "wildbend river", "річка дикого вигину", "amethalx",
    },
    ["ashenvale"] = {
        "ashenvale", "ясенева діброва", "ясеневий ліс",
        "astranaar", "астранаар", "maelstrom", "маелстром",
        "mystral lake", "озеро містраль", "raynewood retreat", "притулок рейнвуд",
        "the ruins of stardust", "руїни зоряного пилу", "fire scar shrine", "святилище вогняного шраму",
        "warsong lumber camp", "лісопильня пісні війни", "splintertree post", "застава розколотого дерева",
        "zoram'gar outpost", "форпост зорам'гар", "lake falathim", "озеро фалатім",
        "thistlefur village", "селище будякових", "fallenroot satyr", "сатири палого кореня",
        "the howling vale", "виюча долина", "iris lake", "озеро ірис",
        "night run", "нічний пробіг", "satyrnaar", "сатірнаар", "xavian", "ксавіан",
        "forest song", "лісова пісня", "silverwing grove", "гай сріблястих крил",
        "silverwing outpost", "форпост сріблястих крил",
    },
    ["durotar"] = {
        "durotar", "дуротар", "valley of trials", "долина випробувань",
        "sen'jin village", "селище сен'джин", "razor hill", "гострозубий пагорб",
        "tiragarde keep", "фортеця тірагард", "scorched ledge", "випалений виступ",
        "kolkar crag", "скеля колкар", "echo isles", "острови відлуння",
        "skull rock", "скеля черепа", "drygulch ravine", "яр сухого яру",
        "thunder ridge", "громовий хребет", "orgrimmar", "оргріммар",
    },
    ["mulgore"] = {
        "mulgore", "мулгор", "red cloud mesa", "плато червоної хмари",
        "bloodhoof village", "селище кривавого копита", "palemane rock", "скеля блідогривих",
        "winterhoof water well", "криниця зимового копита", "thunderhorn water well", "криниця громового рогу",
        "wildmane water well", "криниця дикої гриви", "bael'dun digsite", "розкопки баель'дун",
        "the rolling plains", "хвилясті рівнини", "the venture co. mine", "шахта торговельної компанії",
        "ravaged caravan", "розграбований караван", "thunder bluff", "громовий бескид",
    },
    ["barrens"] = {
        "barrens", "the barrens", "степи", "the crossroads", "перехрестя",
        "ratchet", "тріскотня", "camp taurajo", "табір таурахо",
        "bael modan", "баель модан", "boulder lode mine", "шахта валунної жили",
        "the forgotten pools", "забуті ставки", "lushwater oasis", "оазис пишної води",
        "the stagnant oasis", "застійний оазис", "dreadmist peak", "пік зловісного туману",
        "thorn hill", "терновий пагорб", "northwatch hold", "твердиня північної варти",
        "the merchant coast", "торговельне узбережжя", "fray island", "острів сутички",
        "razorfen downs", "пагорби гострої щетини", "razorfen kraul", "лабіринт гострої щетини",
        "field of giants", "поле велетнів", "blackthorn ridge", "хребет чорного терну",
        "honor's stand", "стоянка честі", "mor'shan base camp", "базовий табір мор'шан",
        "the dry hills", "сухі пагорби", "sludge fen", "мулкий болото",
    },
    ["tirisfal"] = {
        "tirisfal", "tirisfal glades", "тірісфальські нетрі", "тірісфаль",
        "deathknell", "дзвін смерті", "brill", "брілл",
        "cold hearth manor", "маєток холодного вогнища", "nightmare vale", "долина кошмарів",
        "agaman's mill", "млин агаманда", "garren's haunt", "притулок гаррена",
        "brightwater lake", "озеро ясної води", "gunther's retreat", "притулок гюнтера",
        "scarlet monastery", "монастир багряного ордена", "the bulwark", "бастіон",
        "undercity", "підмістя",
    },
    ["silverpine"] = {
        "silverpine", "silverpine forest", "срібнолісся",
        "the sepulcher", "склеп", "olsen's lot", "ділянка ольсена",
        "the decaying orchard", "гнилий сад", "fenris isle", "острів фенріса",
        "fenris keep", "фортеця фенріса", "shadowfang keep", "фортеця тіньового ікла",
        "the skittering dark", "метушлива темрява", "north tide's hollow", "улоговина північного припливу",
        "the greymane wall", "стіна сірогривих", "beren's perch", "сідало берена",
        "ambermill", "бурштиновий млин", "pyrewood village", "селище піровуд",
        "deep elem mine", "глибока шахта елем",
    },
    ["hillsbrad"] = {
        "hillsbrad", "hillsbrad foothills", "передгір'я гілсбраду", "гілсбрад",
        "southshore", "південний берег", "tarren mill", "млин тарен",
        "dun garok", "дун гарок", "nethander steading", "хутір нетандера",
        "dazalaran's tower", "вежа дазаларана", "eastern strand", "східне узбережжя",
        "western strand", "західне узбережжя", "azurelode mine", "шахта блакитної жили",
        "southpoint tower", "південна вежа", "purgation isle", "острів очищення",
        "dazalaran", "дазаларан",
    },
    ["arathi"] = {
        "arathi", "arathi highlands", "нагір'я аратхі", "аратхі",
        "refuge pointe", "точка притулку", "hammerfall", "молотопад",
        "witherbark village", "селище зів'ялої кори", "boulderfist hall", "зал валунного кулака",
        "stromgarde keep", "фортеця стромгард", "faldir's cove", "бухта фальдіра",
        "circle of inner binding", "коло внутрішнього зв'язування",
        "circle of outer binding", "коло зовнішнього зв'язування",
        "circle of west binding", "коло західного зв'язування",
        "circle of east binding", "коло східного зв'язування",
        "dabyrie's farmstead", "хутір дабірі", "go'shek farm", "ферма го'шек",
        "northfold manor", "маєток північної складки", "thoradin's wall", "стіна торадіна",
    },
    ["stranglethorn"] = {
        "stranglethorn", "stranglethorn vale", "терниста долина", "долина тернистої долини",
        "booty bay", "піратська бухта", "grom'gol", "grom'gol base camp", "базовий табір гром'гол",
        "nesingwary's expedition", "експедиція несінґварі", "rebel camp", "табір повстанців",
        "kurzen's compound", "табір курцена", "the stockpile", "склад",
        "mizjah ruins", "руїни міз'я", "tkashi ruins", "руїни ткаші",
        "balai ruins", "руїни балаї", "ziata'jai ruins", "руїни зіата'джай",
        "ruins of zul'kunda", "руїни зул'кунда", "ruins of zul'mamwe", "руїни зул'мамве",
        "the vile reef", "мерзенний риф", "wild shore", "дикий берег",
        "bloodsail compound", "табір кривавого вітрила", "crystalvein mine", "шахта кришталевої жили",
        "jura'thal", "джура'таль", "mistvale valley", "долина туманної долини",
        "the cape of stranglethorn", "мис тернистої долини",
    },
    ["swampsorrows"] = {
        "swamp of sorrows", "болото скорботи", "stonard", "стонард",
        "fallow sanctuary", "святилище парового", "the harbor", "гавань",
        "pool of tears", "ставок сліз", "the shifting mire", "мінливе багно",
        "misty valley", "туманна долина", "itharius's cave", "печера ітарія",
        "splinterspear junction", "перехрестя розколотого списа",
        "sorrowmurk", "скорботний морок", "misty reed strand", "берег туманного очерету",
    },
    ["blastedlands"] = {
        "blasted lands", "спустошені землі", "nethergarde keep", "фортеця нетерґард",
        "dreadmaul hold", "твердиня зловісного молота", "dreadmaul post", "застава зловісного молота",
        "the dark portal", "темний портал", "serpent's coil", "зміїний виток",
        "rise of the defiler", "піднесення осквернителя", "altar of storms", "вівтар бур",
    },
    ["badlands"] = {
        "badlands", "безплідні землі", "kargath", "каргат",
        "hammertoe's digsite", "розкопки молотоногого", "dustbelch grotto", "грот пилового ригання",
        "angor fortress", "фортеця ангор", "lethlor ravine", "яр летлор",
        "the dustbowl", "пилова чаша", "mirage flats", "рівнини марева",
        "camp boff", "табір бофф", "camp cagg", "табір кагг", "camp kosh", "табір кош",
        "valley of fangs", "долина ікл", "agmond's end", "кінець агмонда",
    },
    ["searinggorge"] = {
        "searing gorge", "палаюча ущелина", "thorium point", "торієва точка",
        "grimesilt dig site", "розкопки брудного мулу", "the cauldron", "казан",
        "firewatch ridge", "хребет вогневої варти", "the sea of cinders", "море попелу",
        "blackchar cave", "печера чорного вугілля", "dustfire valley", "долина пилового вогню",
    },
    ["burningsteppes"] = {
        "burning steppes", "палаючі степи", "morgan's vigil", "чування моргана",
        "flame crest", "вогняний гребінь", "blackrock stronghold", "твердиня чорної скелі",
        "dreadmaul rock", "скеля зловісного молота", "pillar of ash", "стовп попелу",
        "altar of storms", "вівтар бур", "blackrock mountain", "гора чорної скелі",
        "blackrock pass", "перевал чорної скелі",
    },
    ["thousandneedles"] = {
        "thousand needles", "тисяча голок", "freewind post", "застава вільного вітру",
        "camp e'thok", "табір е'ток", "highperch", "високе сідало",
        "the great lift", "великий підйомник", "splithoof crag", "скеля розколотого копита",
        "darkcloud pinnacle", "шпиль темної хмари", "the screeching canyon", "каньйон вереску",
        "roguefeather den", "лігво пташиного пера", "windbreak canyon", "каньйон вітрозахисту",
        "the shimmering flats", "блискучі рівнини", "mirage raceway", "траса марева",
        "weena's table", "стіл віни", "tahonda ruins", "руїни тахонди",
    },
    ["desolace"] = {
        "desolace", "спустошення", "nijel's point", "точка найджела",
        "shadowprey village", "селище тіньової здобичі", "thunder axe fortress", "фортеця громової сокири",
        "kolkar village", "селище колкар", "magram village", "селище маграм",
        "gelkis village", "селище гелкіс", "mannoroc coven", "шабаш маннорока",
        "sarcronar", "сакронар", "valley of spears", "долина списів",
        "kormek's hut", "хатина кормека", "ghost walker post", "застава примарного ходителя",
        " Ethel Rethor", "етель ретор", "ranazjar isle", "острів раназжар",
        "tethris aran", "тетріс аран", "shadowbreak ravine", "яр тіньового розлому",
    },
    ["feralas"] = {
        "feralas", "фералас", "feathermoon stronghold", "твердиня місячного пера",
        "camp mojache", "табір мохаче", "dire maul", "зловісний молот",
        "ruines of isildien", "руїни ісілдієна", "lariss pavilion", "павільйон ларісса",
        "the high wilderness", "висока пустеля", "lower wilds", "нижні дикі землі",
        "grimtotem compound", "табір зловісного тотема", "woodpaw dens", "лігва вудпоу",
        "gordunni outpost", "форпост гордунні", "shady rest inn", "заїзд тінистого відпочинку",
        "oneiros", "онейрос", "dream breeze's ridge", "хребет мрійного вітру",
        "ruins of ravenwind", "руїни воронячого вітру", "the twin colossals", "подвійні колоси",
        "sardor isle", "острів сардор", "isle of dread", "острів жаху",
    },
    ["dustwallow"] = {
        "dustwallow", "dustwallow marsh", "пиловолотські болота", "пиловий вир",
        "theramore", "theramore isle", "острів терамор",
        "brackenwall village", "селище бритвостін", "alcaz island", "острів алкац",
        "witch hill", "відьомський пагорб", "the quagmire", "трясовина",
        "the den of flame", "лігво полум'я", "stonemaul ruins", "руїни кам'яного молота",
        "lost point", "втрачена точка", "shady rest inn", "заїзд тінистого відпочинку",
        "sentry point", "точка вартових", "north point tower", "північна вежа",
        "swamplight manor", "маєток болотного світла", "bluefen", "синє болото",
        "darkmist cavern", "печера темного туману",
    },
    ["tanaris"] = {
        "tanaris", "танаріс", "gadgetzan", "гаджетзан",
        "steamwheedle port", "порт стімвідл", "lost rift valley", "долина втраченого розлому",
        "the noxious lier", "отруйна лігва", "dunemaul compound", "табір дюнового молота",
        "eastmoon ruins", "руїни східного місяця", "southmoon ruins", "руїни південного місяця",
        "lands end beach", "пляж краю земель", "the gaping chasm", "зяюча прірва",
        "caverns of time", "печери часу", "zalashji's den", "лігво залашжі",
        "waterspring field", "поле водяного джерела", "abyssal sands", "безодні піски",
        "broken pillar", "зламаний стовп", "noonshade ruins", "руїни полуденної тіні",
        "sandsorrow watch", "варта піщаної скорботи", "thistleshrub valley", "долина будякового чагарнику",
        "uldum", "ульдум", "valley of the watchers", "долина вартових",
    },
    ["ungoro"] = {
        "ungoro", "un'goro crater", "кратер ун'горо", "ун'горо",
        "marshal's refuge", "притулок маршала", "fire plume ridge", "хребет вогняного султана",
        "lakkari tar pits", "смоляні ями лаккарі", "the marshlands", "болотисті землі",
        "terror run", "пробіг жаху", "the sliding rocks", "ковзкі скелі",
        "golakka hot springs", "гарячі джерела голакка", "fungal rock", "грибна скеля",
        "ironstone plateau", "плато залізного каменю",
    },
    ["silithus"] = {
        "silithus", "силітус", "cenarion hold", "цінаріонська твердиня",
        "valor's rest", "відпочинок доблесті", "hive'ashi", "вулик аші",
        "hive'zora", "вулик зора", "hive'regal", "вулик регал",
        "the crystal vale", "кришталева долина", "southwind village", "селище південного вітру",
        "twilight base camp", "базовий табір сутінків", "twilight outpost", "форпост сутінків",
        "twilight post", "застава сутінків", "bones of grakkarond", "кістки граккаронда",
    },
    ["winterspring"] = {
        "winterspring", "зимова весна", "зимове джерело",
        "everlook", "довгогляд", "frostfire hot springs", "гарячі джерела морозного вогню",
        "timbermaw post", "застава дерев'яної пащі", "mazthoril", "мазторіл",
        "starfall village", "селище зорепаду", "frostsaber rock", "скеля морозного шаблезуба",
        "owlwing thicket", "гущавина совиних крил", "ice thistle hills", "пагорби крижаного будяка",
        "winterfall village", "селище зимопаду", "the hidden grove", "прихований гай",
        "lake kel'theril", "озеро кель'теріл", "darkwhisper gorge", "ущелина темного шепоту",
        "frostwhisper gorge", "ущелина морозного шепоту",
    },
    ["felwood"] = {
        "felwood", "осквернений ліс", "сквернелісся",
        "bloodvenom post", "застава кривавої отрути", "jaedenar", "джеденар",
        "ruins of constellas", "руїни констелласа", "jadefire glen", "ущелина нефритового вогню",
        "jadefire run", "пробіг нефритового вогню", "shatter scar vale", "долина шрамів розколу",
        "bloodvenom falls", "водоспад кривавої отрути", "deadwood village", "селище мертвого дерева",
        "felpaw village", "селище сквернолапих", "emerald sanctum", "смарагдовий святилище",
        "talonbranch glade", "галявина кігтевої гілки", "irontree woods", "залізне дерево",
        "morlos'aran", "морлос'аран",
    },
    ["moonglade"] = {
        "moonglade", "місячна галявина", "nighthaven", "нічна гавань",
        "shrine of remulos", "святилище ремулоса", "stormrage barrow dens", "кургани люті бурі",
        "lake elune'ara", "озеро елуне'ара",
    },
    ["azshara"] = {
        "azshara", "азшара", "valormok", "валормок",
        "talrendis point", "точка талрендіс", "ursolan", "урсолан",
        "legash encampment", "табір легаш", "thalassian base camp", "базовий табір таласіян",
        "huln's rise", "піднесення хулна", "ravenrock", "вороняча скеля",
        "the shattered strand", "розколоте узбережжя", "southridge beach", "пляж південного хребта",
        "ruins of eldarath", "руїни ельдарата", "temple of zin-malor", "храм зін-малор",
        "tower of eldara", "вежа ельдари", "bay of storms", "бухта бур",
        "huldar", "хулдар", "jagged reef", "зубчастий риф",
        "scalebeard's cave", "печера лускатого борода", "shadowsong shrine", "святилище тіньової пісні",
    },
    ["stonetalon"] = {
        "stonetalon", "stonetalon mountains", "кам'яні пазурі", "каменепазурі",
        "sun rock retreat", "притулок сонячної скелі", "malaka'jin", "малака'джин",
        "webwinder path", "шлях павутиного звивача", "windshear crag", "скеля вітрорізу",
        "windshear mine", "шахта вітрорізу", "the charcoal ridge", "вугільний хребет",
        "miral woods", "ліс мірал", "camp aparaje", "табір апараже",
        "grimtotem post", "застава зловісного тотема", "stendel's post", "застава стендела",
        "the talon den", "лігво кігтя", "boulderslide ravine", "яр валунного зсуву",
        "sishir canyon", "каньйон сішир", "blackwolf river", "річка чорного вовка",
    },
    ["alterac"] = {
        "alterac", "alterac mountains", "гори альтераку", "альтерак",
        "crushridge hold", "твердиня розчавлюючого хребта", "gallows' corner", "кут шибениці",
        "growless cave", "печера без росту", "ruins of alterac", "руїни альтераку",
        "sofera's naze", "мис софери", "strahnbrad", "странбрад",
        "the headland", "мис", "the uplifted land", "піднята земля",
        "corrahn's dagger", "кинджал коррана", "dalaran", "даларан",
        "lordamere lake", "озеро лордамер",
    },
    ["epl"] = {
        "eastern plaguelands", "східні чумові землі",
        "lights hope chapel", "каплиця надії світла", "tyr's hand", "рука тіра",
        "crown guard tower", "вежа коронної варти", "eastwall tower", "східна стінова вежа",
        "northpass tower", "вежа північного перевалу", "plaguewood", "чумний ліс",
        "plaguewood tower", "вежа чумного лісу", "quel'lithien lodge", "садиба квель'літієн",
        "the fungal vale", "грибна долина", "the marris steading", "хутір марріса",
        "the nondescript ridge", "непримітний хребет", "the pestilent scar", "чумний шрам",
        "the undercroft", "підземелля", "thondroril river", "річка тондроріл",
        "terrordale", "долина жаху", "blackwood lake", "озеро чорного лісу",
        "darrowshire", "дарроушир", "corin's crossing", "перехрестя коріна",
        "the infected scar", "заражений шрам", "zul'mashar", "зул'машар",
        "mazra'alor", "мазра'алор", "northdale", "північна долина",
        "the nocuous glade", "отруйна галявина",
    },
    ["wpl"] = {
        "western plaguelands", "західні чумові землі",
        "andorhal", "андорал", "harrowdale", "гарровдейл",
        "the bulwark", "бастіон", "felstone field", "поле скверного каменю",
        "dalson's tears", "сльози дальсона", "the writhing haunt", "звиваючий притулок",
        "gahrron's withering", "в'янення гаррона", "the weeping cave", "плачуча печера",
        "caereleon keep", "фортеця керелеон", "sorrow hill", "пагорб скорботи",
        "uthers tomb", "гробниця утера", "darrowmere lake", "озеро дарроумер",
        "chillwind camp", "табір холодного вітру", "chillwind point", "точка холодного вітру",
        "mardenholde keep", "фортеця марденхольд",
    },
    ["hinterlands"] = {
        "hinterlands", "the hinterlands", "внутрішні землі",
        "aerie peak", "орлиний пік", "wildhammer keep", "фортеця дикого молота",
        "quel'danil lodge", "садиба квель'даніл", "shadra'alor", "шадра'алор",
        "jintha'alor", "джінта'алор", "the altar of zul", "вівтар зул",
        "seraadane", "сераадане", "skulk rock", "скеля нишпорення",
        "shaol'watha", "шаол'вата", "agola'watha", "агола'вата",
        "valorwind lake", "озеро доблесного вітру", "the creaking field", "скрипне поле",
        "plaguemist ravine", "яр чумного туману", "the overlook cliffs", "скелі огляду",
        "revantusk village", "селище ревантуск",
    },
    ["searing"] = {  -- alias already above
    },
}

-- побудова зворотного індексу: "назва" → "група"
local ZONE_NAME_TO_GROUP = {}
for group, names in pairs(ZONE_GROUPS) do
    local ni
    for ni = 1, table.getn(names) do
        local n = string.lower(names[ni])
        n = string.gsub(n, "^%s+", "")
        n = string.gsub(n, "%s+$", "")
        ZONE_NAME_TO_GROUP[n] = group
    end
end

local function NormZone(s)
    if not s then return "" end
    s = string.lower(s)
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    s = string.gsub(s, "^the%s+", "")
    s = string.gsub(s, "%s+", " ")
    return s
end

local function ZoneKey(s)
    local n = NormZone(s)
    if n == "" then return "" end
    if ZONE_NAME_TO_GROUP[n] then return ZONE_NAME_TO_GROUP[n] end
    -- частковий збіг
    for k, g in pairs(ZONE_NAME_TO_GROUP) do
        if string.find(n, k, 1, true) or string.find(k, n, 1, true) then
            return g
        end
    end
    return n
end

local function CurrentZoneName()
    local z = GetRealZoneText and GetRealZoneText() or nil
    if not z or z == "" then z = GetZoneText and GetZoneText() or "" end
    return z
end

local function CurrentSubZoneName()
    if GetSubZoneText then
        local s = GetSubZoneText()
        if s and s ~= "" then return s end
    end
    return ""
end

local function ZoneFilterOn()
    return true
end

local function BuildQuestList()
    local list = {}
    if not GetNumQuestLogEntries or not GetQuestLogTitle then return list end
    local header = ""
    local n = GetNumQuestLogEntries()
    local i
    for i = 1, n do
        local qt, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        if isHeader then
            header = qt or ""
        elseif qt then
            local clean = string.gsub(qt, "%s*%-%s*%([^%)]+%)%s*$", "")
            clean = string.gsub(clean, "%s*%([^%)]+%)%s*$", "")
            local qid = nil
            if type(GetQuestLink) == "function" then
                local link = GetQuestLink(i)
                if link then
                    local _, _, id = string.find(link, "quest:(%d+)")
                    if id then qid = tonumber(id) end
                end
            end
            local tr = FindTranslation(clean)
            if not tr and qid and DB then
                local row = DB[qid] or DB[tostring(qid)]
                if type(row) == "table" then tr = row; tr.id = qid end
            end
            local watched = false
            if IsQuestWatched and IsQuestWatched(i) then watched = true end
            table.insert(list, {
                logIndex = i, en = clean, level = level, header = header,
                tr = tr, qid = qid, watched = watched, isComplete = isComplete, tag = tag,
            })
        end
    end
    return list
end

local function QuestInCurrentZone(entry, zoneNorm)
    if not ZoneFilterOn() then return true end
    local h = entry.header or ""
    if h == "" then return true end

    local zoneKey = ZoneKey(zoneNorm or "")
    local headerKey = ZoneKey(h)
    local sub = CurrentSubZoneName and CurrentSubZoneName() or ""
    local subKey = ZoneKey(sub)

    -- 1) одна група (зона + субзони)
    if zoneKey ~= "" and headerKey ~= "" and zoneKey == headerKey then
        return true
    end
    if subKey ~= "" and headerKey ~= "" and subKey == headerKey then
        return true
    end

    -- 2) прямий/частковий збіг рядків
    local hNorm = NormZone(h)
    local zNorm = NormZone(zoneNorm or "")
    local sNorm = NormZone(sub)
    if hNorm ~= "" then
        if zNorm ~= "" and (hNorm == zNorm or string.find(hNorm, zNorm, 1, true) or string.find(zNorm, hNorm, 1, true)) then
            return true
        end
        if sNorm ~= "" and (hNorm == sNorm or string.find(hNorm, sNorm, 1, true) or string.find(sNorm, hNorm, 1, true)) then
            return true
        end
    end
    return false
end

-- ===== UI =====
local TRK = {}  -- один upvalue замість 32+ (ліміт Lua 5.0)
local PlaceTracker  -- forward decl
local LayoutTracker -- forward decl (швидка перестановка без перебудови даних)

local trk = CreateFrame("Frame", "OceUA_QuestTracker", UIParent)
trk:SetWidth(TRK_WIDTH + 16)
trk:SetClampedToScreen(true)
trk:SetMovable(false)
trk:EnableMouse(true)
trk:SetFrameStrata("MEDIUM")
trk:Hide()

-- рамка (fade при hover)
local trkBorder = CreateFrame("Frame", "OceUA_QuestTrackerBorder", trk)
trkBorder:SetAllPoints(trk)
trkBorder:SetFrameLevel(trk:GetFrameLevel())
trkBorder:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
trkBorder:SetBackdropColor(0.05, 0.05, 0.08, 0.35)
trkBorder:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.55)
trkBorder:SetAlpha(0)
trkBorder:EnableMouse(false)

local FADE_SPEED = 8.0  -- швидке поява
local borderAlpha = 0
local borderTarget = 0
local borderFader = CreateFrame("Frame")
borderFader:Hide()
borderFader:SetScript("OnUpdate", function()
    local dt = arg1
    if borderAlpha < borderTarget then
        borderAlpha = borderAlpha + FADE_SPEED * dt
        if borderAlpha > borderTarget then borderAlpha = borderTarget end
    elseif borderAlpha > borderTarget then
        -- зникнення миттєве
        borderAlpha = borderTarget
    end
    trkBorder:SetAlpha(borderAlpha)
    if borderAlpha == borderTarget then this:Hide() end
end)
local function BorderFadeTo(a)
    if a == 0 then
        -- одразу ховаємо затемнення при знятті курсору
        borderTarget = 0
        borderAlpha = 0
        trkBorder:SetAlpha(0)
        borderFader:Hide()
        return
    end
    borderTarget = a
    if borderAlpha ~= borderTarget then borderFader:Show() end
end
trk:SetScript("OnEnter", function() BorderFadeTo(1) end)
trk:SetScript("OnLeave", function()
    if MouseIsOver and MouseIsOver(trk) then return end
    BorderFadeTo(0)
end)

-- заголовок
local trkHeaderBg = trk:CreateTexture(nil, "ARTWORK")
trkHeaderBg:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
trkHeaderBg:SetVertexColor(0.55, 0.35, 0.85, 0.55)
trkHeaderBg:SetHeight(18)
trkHeaderBg:SetPoint("TOPLEFT", trk, "TOPLEFT", 4, -4)
trkHeaderBg:SetPoint("TOPRIGHT", trk, "TOPRIGHT", -4, -4)

local trkHeaderIcon = trk:CreateTexture(nil, "OVERLAY")
trkHeaderIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
trkHeaderIcon:SetWidth(14)
trkHeaderIcon:SetHeight(14)
trkHeaderIcon:SetPoint("LEFT", trkHeaderBg, "LEFT", 2, 0)

local trkHeader = trk:CreateFontString(nil, "OVERLAY", "GameFontNormal")
trkHeader:SetPoint("LEFT", trkHeaderIcon, "RIGHT", 4, 0)
trkHeader:SetTextColor(1, 0.82, 0)
trkHeader:SetJustifyH("LEFT")
trkHeader:SetText("Квести")

-- Shift+ЛКМ drag лише по Y
local trkDrag = CreateFrame("Button", "OceUA_TrkDrag", trk)
trkDrag:SetPoint("TOPLEFT", trk, "TOPLEFT", 4, -4)
trkDrag:SetPoint("TOPRIGHT", trk, "TOPRIGHT", -44, -4)
trkDrag:SetHeight(18)
trkDrag:EnableMouse(true)
trkDrag:RegisterForDrag("LeftButton")
trkDrag:SetFrameLevel(trk:GetFrameLevel() + 6)

local dragStartY, dragStartOfs
trkDrag:SetScript("OnDragStart", function()
    if not (IsShiftKeyDown and IsShiftKeyDown()) then return end
    OceQuestUA_Settings = OceQuestUA_Settings or {}
    dragStartY = nil
    if GetCursorPosition then
        local _, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        dragStartY = cy / scale
        dragStartOfs = OceQuestUA_Settings.trkYOfs or 0
    end
    this.dragging = true
    this:SetScript("OnUpdate", function()
        if not this.dragging or not dragStartY then
            this:SetScript("OnUpdate", nil)
            return
        end
        if not (IsShiftKeyDown and IsShiftKeyDown()) then
            this.dragging = false
            dragStartY = nil
            this:SetScript("OnUpdate", nil)
            return
        end
        local _, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        local delta = (cy / scale) - dragStartY
        OceQuestUA_Settings = OceQuestUA_Settings or {}
        local newOfs = (dragStartOfs or 0) + delta
        if newOfs > 30 then newOfs = 30 end
        if newOfs < -500 then newOfs = -500 end
        OceQuestUA_Settings.trkYOfs = newOfs
        if PlaceTracker then PlaceTracker() end
    end)
end)
trkDrag:SetScript("OnDragStop", function()
    this.dragging = false
    dragStartY = nil
    this:SetScript("OnUpdate", nil)
end)
trkDrag:SetScript("OnEnter", function()
    BorderFadeTo(1)
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("Квести", 1, 0.82, 0)
    GameTooltip:AddLine("Shift+ЛКМ — тягнути вгору/вниз (висота від мінімапи до панелей)", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Ctrl+ЛКМ за лівий кут — лише ширина", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Коліщатко — прокрутка списку", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
trkDrag:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if not (MouseIsOver and MouseIsOver(trk)) then BorderFadeTo(0) end
end)

-- Ctrl+ЛКМ: розтягнути. Точка зліва знизу
local trkResize = CreateFrame("Button", "OceUA_TrkResize", trk)
trkResize:SetWidth(12)
trkResize:SetHeight(12)
trkResize:SetPoint("BOTTOMLEFT", trk, "BOTTOMLEFT", 3, 3)
trkResize:EnableMouse(true)
trkResize:RegisterForDrag("LeftButton")
trkResize:SetFrameLevel(trk:GetFrameLevel() + 25)
trkResize:SetHitRectInsets(-6, -6, -6, -6)

local rz1 = trkResize:CreateTexture(nil, "OVERLAY")
rz1:SetTexture("Interface\\Buttons\\WHITE8X8")
rz1:SetVertexColor(0.85, 0.75, 0.45, 0.55)
rz1:SetWidth(8)
rz1:SetHeight(1)
rz1:SetPoint("BOTTOMLEFT", trkResize, "BOTTOMLEFT", 1, 2)
local rz2 = trkResize:CreateTexture(nil, "OVERLAY")
rz2:SetTexture("Interface\\Buttons\\WHITE8X8")
rz2:SetVertexColor(0.85, 0.75, 0.45, 0.55)
rz2:SetWidth(1)
rz2:SetHeight(8)
rz2:SetPoint("BOTTOMLEFT", trkResize, "BOTTOMLEFT", 2, 1)
local rz3 = trkResize:CreateTexture(nil, "OVERLAY")
rz3:SetTexture("Interface\\Buttons\\WHITE8X8")
rz3:SetVertexColor(0.85, 0.75, 0.45, 0.35)
rz3:SetWidth(5)
rz3:SetHeight(1)
rz3:SetPoint("BOTTOMLEFT", trkResize, "BOTTOMLEFT", 1, 5)
local rz4 = trkResize:CreateTexture(nil, "OVERLAY")
rz4:SetTexture("Interface\\Buttons\\WHITE8X8")
rz4:SetVertexColor(0.85, 0.75, 0.45, 0.35)
rz4:SetWidth(1)
rz4:SetHeight(5)
rz4:SetPoint("BOTTOMLEFT", trkResize, "BOTTOMLEFT", 5, 1)
trkResize.lines = { rz1, rz2, rz3, rz4 }

local function TrkResizeSetAlpha(a)
    local i
    for i = 1, 4 do
        local tex = trkResize.lines[i]
        if tex then tex:SetVertexColor(0.85, 0.75, 0.45, a) end
    end
end

local rzStartX, rzStartW
trkResize:SetScript("OnDragStart", function()
    if not (IsControlKeyDown and IsControlKeyDown()) then return end
    OceQuestUA_Settings = OceQuestUA_Settings or {}
    local scale = UIParent:GetEffectiveScale() or 1
    local cx = GetCursorPosition()
    rzStartX = cx / scale
    rzStartW = GetTrkWidth()
    this.resizing = true
    this:SetScript("OnUpdate", function()
        if not this.resizing then
            this:SetScript("OnUpdate", nil)
            return
        end
        if not (IsControlKeyDown and IsControlKeyDown()) then
            this.resizing = false
            this:SetScript("OnUpdate", nil)
            if OceUA_RefreshQuestTracker then OceUA_RefreshQuestTracker() end
            return
        end
        local cx2 = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale() or 1
        local dx = rzStartX - (cx2 / sc)
        local nw = rzStartW + dx
        if nw < 160 then nw = 160 end
        if nw > 420 then nw = 420 end
        OceQuestUA_Settings.trkW = nw
        -- висота більше не регулюється тут — лише ширина (Ctrl)
        -- висота фіксується від мінімапи до action bars (або Shift+тягнути вікно)
        trk:SetWidth(nw + 16)
        if TRK then TRK.TRK_WIDTH = nw end
        if PlaceTracker then PlaceTracker() end
        if OceUA_RefreshQuestTracker then OceUA_RefreshQuestTracker() end
    end)
end)
trkResize:SetScript("OnDragStop", function()
    this.resizing = false
    this:SetScript("OnUpdate", nil)
    if TRK then TRK.busy = false end
    if OceUA_RefreshQuestTracker then OceUA_RefreshQuestTracker() end
end)
trkResize:SetScript("OnEnter", function()
    BorderFadeTo(1)
    TrkResizeSetAlpha(0.9)
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Ширина вікна", 1, 0.82, 0)
    GameTooltip:AddLine("Ctrl+ЛКМ — тільки ширина", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift+ЛКМ по заголовку — вгору/вниз", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
trkResize:SetScript("OnLeave", function()
    TrkResizeSetAlpha(0.4)
    GameTooltip:Hide()
    if not (MouseIsOver and MouseIsOver(trk)) then BorderFadeTo(0) end
end)
TrkResizeSetAlpha(0.4)

local trkSub = trk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
trkSub:SetPoint("TOPLEFT", trkHeaderBg, "BOTTOMLEFT", 2, -2)
trkSub:SetTextColor(0.6, 0.6, 0.65)
trkSub:SetJustifyH("LEFT")
trkSub:SetText("")

local trkFilterBtn = CreateFrame("Button", "OceUA_TrkFilterBtn", trk)
trkFilterBtn:SetWidth(40)
trkFilterBtn:SetHeight(14)
trkFilterBtn:EnableMouse(false)
trkFilterBtn:Hide()  -- повний список / перемикач зони прибрано
trkFilterBtn.fs = trkFilterBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
trkFilterBtn.fs:SetAllPoints()
trkFilterBtn.fs:SetJustifyH("RIGHT")
trkFilterBtn.fs:SetText("|cff66cc66зона|r")

-- ===== ScrollFrame: контент жорстко всередині рамки, без лагів на скролі =====
local PAD = 6
local trkScroll = 0
local trkContentH = 0
local trkViewH = 0
local trkHeaderH = 26

local trkClip = CreateFrame("ScrollFrame", "OceUA_TrkClip", trk)
trkClip:EnableMouse(false)
trkClip:EnableMouseWheel(true)

local trkBody = CreateFrame("Frame", "OceUA_TrkBody", trkClip)
trkBody:SetWidth(TRK_WIDTH)
trkBody:SetHeight(1)
trkClip:SetScrollChild(trkBody)

trk.lines = {}
local li
for li = 1, TRK_MAX do
    local fs = trkBody:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetWidth(TRK_WIDTH - 4)
    fs:SetJustifyH("LEFT")
    fs:SetText("")
    fs:Hide()
    local hit = CreateFrame("Button", "OceUA_TrkHit" .. li, trkBody)
    hit:SetHeight(TRK_LINE_H)
    hit:SetWidth(TRK_WIDTH - 4)
    hit:EnableMouse(false)
    hit:EnableMouseWheel(true)
    hit:Hide()
    hit.fs = fs
    hit.idx = li
    hit.isObj = false
    hit.isTitle = false
    hit:SetScript("OnEnter", function()
        BorderFadeTo(1)
        if not this.isObj then return end
        local e = this.entry
        if not e then return end
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        local title = e.tr and e.tr.T and FormatQuestText(e.tr.T) or e.en
        local lv = e.level
        if lv and tonumber(lv) and tonumber(lv) > 0 then
            title = "[" .. tostring(lv) .. "] " .. title
        end
        local r, g, b = QuestDiffColor(lv)
        GameTooltip:AddLine(title, r, g, b)
        if e.tr and e.tr.D and e.tr.D ~= "" then
            local desc = FormatQuestText(e.tr.D)
            if string.len(desc) > 400 then desc = string.sub(desc, 1, 400) .. "..." end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(desc, 0.9, 0.9, 0.9, 1)
        end
        if e.tr and e.tr.O and e.tr.O ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(FormatQuestText(e.tr.O), 1, 0.82, 0, 1)
        end
        if e.objText and e.objText ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(e.objText, 0.55, 0.85, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("ПКМ — відкрити в журналі", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if not (MouseIsOver and MouseIsOver(trk)) then BorderFadeTo(0) end
    end)
    hit:SetScript("OnMouseUp", function()
        if not this.isObj then return end
        if not this.entry or not this.entry.logIndex then return end
        if arg1 == "RightButton" then
            local logIndex = this.entry.logIndex
            if SelectQuestLogEntry then SelectQuestLogEntry(logIndex) end
            if QuestLogFrame and not QuestLogFrame:IsVisible() then
                if ShowUIPanel then ShowUIPanel(QuestLogFrame) else QuestLogFrame:Show() end
            end
            if QuestLog_Update then QuestLog_Update() end
            if QuestLog_UpdateQuestDetails then QuestLog_UpdateQuestDetails() end
        end
    end)
    trk.lines[li] = hit
end

local function ApplyScroll()
    local ch = TRK.contentH or trkContentH or 0
    local vh = TRK.viewH or trkViewH or 0
    local maxScroll = ch - vh
    if maxScroll < 0 then maxScroll = 0 end
    local sc = TRK.scroll or trkScroll or 0
    if sc < 0 then sc = 0 end
    if sc > maxScroll then sc = maxScroll end
    TRK.scroll = sc
    trkScroll = sc

    -- 1.12: ScrollFrame + UpdateScrollChildRect
    if trkClip then
        if trkClip.UpdateScrollChildRect then
            trkClip:UpdateScrollChildRect()
        end
        if trkClip.SetVerticalScroll then
            trkClip:SetVerticalScroll(sc)
        end
    end

    -- запасний варіант: зсув body вручну (якщо SetVerticalScroll не спрацьовує)
    if trkBody and maxScroll > 0 then
        -- ScrollChild керує позицією; додатково не чіпаємо, щоб не зламати
    end
end

local function OnWheel()
    local delta = arg1 or 0
    if delta == 0 then return end
    local ch = TRK.contentH or trkContentH or 0
    local vh = TRK.viewH or trkViewH or 0
    if ch <= vh + 1 then return end  -- нічого гортати
    TRK.scroll = (TRK.scroll or trkScroll or 0) - delta * 30
    trkScroll = TRK.scroll
    ApplyScroll()
end
trk:EnableMouse(true)
trk:EnableMouseWheel(true)
trk:SetScript("OnMouseWheel", OnWheel)
trkClip:EnableMouse(true)
trkClip:EnableMouseWheel(true)
trkClip:SetScript("OnMouseWheel", OnWheel)
trkBody:EnableMouseWheel(true)
trkBody:SetScript("OnMouseWheel", OnWheel)

local _wi
for _wi = 1, TRK_MAX do
    if trk.lines[_wi] then
        trk.lines[_wi]:EnableMouseWheel(true)
        trk.lines[_wi]:SetScript("OnMouseWheel", OnWheel)
    end
end

local function GetBottomBarTop()
    local best = 0
    local function consider(f)
        if f and f.IsShown and f:IsShown() and f.GetTop then
            local t = f:GetTop()
            if t and t > best then best = t end
        end
    end
    consider(MainMenuBar)
    consider(MultiBarBottomLeft)
    consider(MultiBarBottomRight)
    consider(PetActionBarFrame)
    consider(ShapeshiftBarFrame)
    if best > 0 then return best + 10 end
    return 48
end

local lastRightBars = -1
PlaceTracker = function()
    local rightBars = 0
    local barW = 36
    if MultiBarRight and MultiBarRight.IsShown and MultiBarRight:IsShown() then
        rightBars = rightBars + 1
        if MultiBarRight.GetWidth then barW = MultiBarRight:GetWidth() or 36 end
    end
    if MultiBarLeft and MultiBarLeft.IsShown and MultiBarLeft:IsShown() then
        rightBars = rightBars + 1
    end

    local gap = 10
    local xOfs = -14
    if rightBars >= 1 then xOfs = xOfs - (barW + gap) end
    if rightBars >= 2 then xOfs = xOfs - (barW + gap) end

    local baseY = -180
    if MinimapCluster and MinimapCluster.GetBottom and MinimapCluster:IsVisible() then
        local uiTop = UIParent:GetTop()
        local clusterBottom = MinimapCluster:GetBottom()
        if uiTop and clusterBottom then
            baseY = -(uiTop - clusterBottom) - 14
        end
    end

    OceQuestUA_Settings = OceQuestUA_Settings or {}
    local userY = OceQuestUA_Settings.trkYOfs or 0
    if userY > 30 then userY = 30 end
    if userY < -500 then userY = -500 end
    OceQuestUA_Settings.trkYOfs = userY

    local tw = GetTrkWidth and GetTrkWidth() or TRK_WIDTH
    trk:SetWidth(tw + 16)
    trk:ClearAllPoints()
    trk:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOfs, baseY + userY)

    trkFilterBtn:ClearAllPoints()
    trkFilterBtn:SetPoint("TOPRIGHT", trkHeaderBg, "TOPRIGHT", -2, 0)
    trkFilterBtn:SetFrameStrata("HIGH")
    lastRightBars = rightBars
end


-- миттєве прилипання до Right Action Bars (як оригінальний QuestWatch)
local function CountRightBars()
    local n = 0
    if MultiBarRight and MultiBarRight.IsShown and MultiBarRight:IsShown() then n = n + 1 end
    if MultiBarLeft and MultiBarLeft.IsShown and MultiBarLeft:IsShown() then n = n + 1 end
    return n
end

local function HookRightBar(bar)
    if not bar or bar._oceua_trk_hooked then return end
    bar._oceua_trk_hooked = true
    local oldShow = bar:GetScript("OnShow")
    bar:SetScript("OnShow", function()
        if oldShow then oldShow() end
        if PlaceTracker then PlaceTracker() end
    end)
    local oldHide = bar:GetScript("OnHide")
    bar:SetScript("OnHide", function()
        if oldHide then oldHide() end
        if PlaceTracker then PlaceTracker() end
    end)
end

local function HookAllRightBars()
    HookRightBar(MultiBarRight)
    HookRightBar(MultiBarLeft)
end
HookAllRightBars()

-- легкий poll: якщо бари змінили стан без OnShow/OnHide — підхопити
local barPoll = CreateFrame("Frame")
barPoll.acc = 0
barPoll:SetScript("OnUpdate", function()
    this.acc = this.acc + arg1
    if this.acc < 0.75 then return end
    this.acc = 0
    HookAllRightBars()
    local n = CountRightBars()
    if n ~= lastRightBars then
        lastRightBars = n
        if PlaceTracker then PlaceTracker() end
    end
end)

local function GetTrackerMaxHeight()
    local userH = GetTrkUserMaxH and GetTrkUserMaxH() or nil
    local top = trk:GetTop()
    if not top then
        if userH then return userH end
        return 360
    end
    local maxH = top - GetBottomBarTop()
    if maxH < 100 then maxH = 100 end
    if maxH > 620 then maxH = 620 end
    if userH then
        if userH < maxH then return userH end
        return maxH
    end
    return maxH
end

-- шрифти трекера (тільки вікно «Квести»)
local TRK_TITLE_SIZE = 12
local TRK_OBJ_SIZE = 11
local function TrkFontPath()
    local f = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
    if f then return f end
    return "Fonts\\FRIZQT__.TTF"
end
local function SetTrkTitleFont(fs)
    if not fs or not fs.SetFont then return end
    fs:SetFont(TrkFontPath(), TRK_TITLE_SIZE, "")
end
local function SetTrkObjFont(fs)
    if not fs or not fs.SetFont then return end
    fs:SetFont(TrkFontPath(), TRK_OBJ_SIZE, "")
end

-- зелений (0) → червоний (повністю); лише для лічильника N/M
local function CountColorCode(cur, maxv)
    cur = tonumber(cur) or 0
    maxv = tonumber(maxv) or 1
    if maxv < 1 then maxv = 1 end
    local t = cur / maxv
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    local r = 0.25 + t * 0.75
    local g = 0.85 - t * 0.70
    local b = 0.25 - t * 0.15
    if b < 0 then b = 0 end
    return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function FormatObjWithCountColor(body)
    -- "Name: 3/10" → "Name: |cff..3/10|r"
    if not body then return body end
    local _, _, name, cur, maxv = string.find(body, "^(.-):%s*(%d+)/(%d+)%s*$")
    if name and cur and maxv then
        return "|cffffffff" .. name .. ":|r " .. CountColorCode(cur, maxv) .. cur .. "/" .. maxv .. "|r"
    end
    _, _, cur, maxv = string.find(body, "(%d+)/(%d+)")
    if cur and maxv then
        local colored = CountColorCode(cur, maxv) .. cur .. "/" .. maxv .. "|r"
        return string.gsub(body, cur .. "/" .. maxv, colored, 1)
    end
    return body
end

local function QuestProgressScore(entry)
    if not entry or not entry.logIndex then return 0 end
    if entry.isComplete == 1 then return 0 end
    if entry.isComplete == -1 then return -1 end
    local score = 0
    local has = false
    if not GetNumQuestLeaderBoards then return 0 end
    local n = GetNumQuestLeaderBoards(entry.logIndex)
    if not n then return 0 end
    local i
    for i = 1, n do
        local desc, otype, done = GetQuestLogLeaderBoard(i, entry.logIndex)
        if desc and not done then
            local _, _, cur, maxv = string.find(desc, "(%d+)/(%d+)")
            cur = tonumber(cur)
            maxv = tonumber(maxv)
            if cur and maxv and cur > 0 then
                has = true
                score = score + cur
            end
        end
    end
    if has then return 1000 + score end
    return 0
end

local function GetObjectiveLinesForLogIndex(logIndex)

    local out = {}
    if not GetNumQuestLeaderBoards then return out end
    local n = GetNumQuestLeaderBoards(logIndex)
    if not n or n == 0 then return out end
    local i
    for i = 1, n do
        local desc, otype, done = GetQuestLogLeaderBoard(i, logIndex)
        if desc then
            local line = desc
            if not HasCyrQ(line) and TranslateObjectiveLine then
                line = TranslateObjectiveLine(line) or line
            end
            line = string.gsub(line, "%s+", " ")
            table.insert(out, { text = line, done = done })
        end
    end
    return out
end

-- ширина тексту строго всередині рамки (враховуємо insets + pad)
local function TextWidth()
    return GetTrkWidth() - 4   -- body width already TRK_WIDTH; small inner pad
end


-- пакуємо посилання: Refresh тримає лише upvalue TRK
TRK.trk = trk
TRK.trkBody = trkBody
TRK.trkClip = trkClip
TRK.lines = trk.lines
TRK.trkHeader = trkHeader
TRK.trkSub = trkSub
TRK.trkFilterBtn = trkFilterBtn
TRK.trkHeaderBg = trkHeaderBg
TRK.PlaceTracker = function()
    PlaceTracker()
end
TRK.ApplyScroll = ApplyScroll
TRK.GetTrackerMaxHeight = GetTrackerMaxHeight
TRK.GetObjectiveLinesForLogIndex = GetObjectiveLinesForLogIndex
TRK.SetTrkTitleFont = SetTrkTitleFont
TRK.SetTrkObjFont = SetTrkObjFont
TRK.FormatObjWithCountColor = FormatObjWithCountColor
TRK.QuestProgressScore = QuestProgressScore
TRK.TextWidth = TextWidth
TRK.PAD = PAD
TRK.TRK_WIDTH = TRK_WIDTH
TRK.TRK_MAX = TRK_MAX
TRK.TRK_LINE_H = TRK_LINE_H
TRK.busy = false
TRK.headerH = 26
TRK.contentH = 0
TRK.viewH = 0
TRK.scroll = 0
TRK.FormatQuestText = FormatQuestText
TRK.QuestDiffColor = QuestDiffColor
TRK.WrapByWords = WrapByWords
TRK.FormatTrackObjective = FormatTrackObjective
TRK.SplitObjectiveNameCount = SplitObjectiveNameCount
TRK.BuildQuestList = BuildQuestList
TRK.QuestInCurrentZone = QuestInCurrentZone
TRK.ZoneFilterOn = ZoneFilterOn
TRK.CurrentZoneName = CurrentZoneName
TRK.NormZone = NormZone
TRK.GetShowUA = function() return showUA end

-- selection state (forward, used in Refresh)
local trkLastSel = 0
local trkSelFromClick = false
local trkLogGraceUntil = 0

function OceUA_RefreshQuestTracker()
    local U = TRK
    if not U or not U.trk then return end
    if U.busy then return end
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then U.trk:Hide() return end
    if U.GetShowUA and not U.GetShowUA() then U.trk:Hide() return end
    if QuestWatchFrame and QuestWatchFrame.Hide then QuestWatchFrame:Hide() end
    U.busy = true
    local trk = U.trk
    local trkBody = U.trkBody
    local trkClip = U.trkClip
    local trkHeader = U.trkHeader
    local trkSub = U.trkSub
    local trkFilterBtn = U.trkFilterBtn
    local lines = U.lines
    local PlaceTracker = U.PlaceTracker
    local ApplyScroll = U.ApplyScroll
    local GetTrackerMaxHeight = U.GetTrackerMaxHeight
    local GetObjectiveLinesForLogIndex = U.GetObjectiveLinesForLogIndex
    local SetTrkTitleFont = U.SetTrkTitleFont
    local SetTrkObjFont = U.SetTrkObjFont
    local FormatObjWithCountColor = U.FormatObjWithCountColor
    local QuestProgressScore = U.QuestProgressScore
    local TextWidth = U.TextWidth
    local PAD = U.PAD
    local TRK_WIDTH = GetTrkWidth()
    U.TRK_WIDTH = TRK_WIDTH
    trk:SetWidth(TRK_WIDTH + 16)
    local TRK_MAX = U.TRK_MAX
    local TRK_LINE_H = U.TRK_LINE_H
    local trkHeaderH, trkContentH, trkViewH
    local FormatQuestText = U.FormatQuestText
    local QuestDiffColor = U.QuestDiffColor
    local WrapByWords = U.WrapByWords
    local FormatTrackObjective = U.FormatTrackObjective
    local SplitObjectiveNameCount = U.SplitObjectiveNameCount
    local BuildQuestList = U.BuildQuestList
    local QuestInCurrentZone = U.QuestInCurrentZone
    local ZoneFilterOn = U.ZoneFilterOn
    local showUA = U.GetShowUA and U.GetShowUA() or true

    if not BuildQuestList or not QuestInCurrentZone then
        U.busy = false
        return
    end

    local zone = (U.CurrentZoneName and U.CurrentZoneName()) or ""
    local zoneNorm = zone
    local all = BuildQuestList() or {}
    local shown = {}
    local i

    -- 1) спочатку watched у зоні
    for i = 1, table.getn(all) do
        local e = all[i]
        if QuestInCurrentZone(e, zoneNorm) and e.watched then
            table.insert(shown, e)
        end
    end
    -- 2) якщо немає watched — усі квести зони
    if table.getn(shown) == 0 then
        for i = 1, table.getn(all) do
            if QuestInCurrentZone(all[i], zoneNorm) then
                table.insert(shown, all[i])
            end
        end
    end

    -- активні зверху; завершені (галочка) — внизу
    if table.sort and table.getn(shown) > 1 then
        local scores = {}
        local si
        for si = 1, table.getn(shown) do
            local e = shown[si]
            local sc = QuestProgressScore(e)
            if e.isComplete == 1 then
                sc = -10000  -- самий низ
            elseif e.isComplete == -1 then
                sc = -5000
            end
            scores[e] = sc
        end
        table.sort(shown, function(a, b)
            local sa = scores[a] or 0
            local sb = scores[b] or 0
            if sa ~= sb then return sa > sb end
            return (a.logIndex or 0) < (b.logIndex or 0)
        end)
    end

    PlaceTracker()
    trkHeader:SetText("Квести")
    trkFilterBtn.fs:SetText("|cff66cc66зона|r")
    trkSub:SetText(zone ~= "" and zone or "")

    trkHeaderH = 26
    if trkSub:GetText() and trkSub:GetText() ~= "" then
        trkHeaderH = 38
    end

    local maxH = GetTrackerMaxHeight()
    local frameH = maxH
    -- якщо контенту мало — зменшимо рамку під нього нижче

    local tw = TextWidth()
    local wrapChars = math.floor(tw / 5.4)
    if wrapChars < 28 then wrapChars = 28 end
    if wrapChars > 70 then wrapChars = 70 end

    local y = 0   -- у body: TOP = 0, вниз від'ємний... SetPoint TOPLEFT y від'ємний
    local lineNo = 0
    local questNum = 0

    -- порожній список: повідомлення по центру
    if table.getn(shown) == 0 then
        lineNo = 1
        local hit = lines[1]
        if hit.divBg then hit.divBg:Hide() end
        if hit.readyIcon then hit.readyIcon:Hide() end
        if hit.selBar then hit.selBar:Hide() end
        hit.fs:ClearAllPoints()
        hit.fs:SetPoint("TOP", trkBody, "TOP", 0, -28)
        hit.fs:SetWidth(tw - 8)
        hit.fs:SetJustifyH("CENTER")
        SetTrkTitleFont(hit.fs)
        hit.fs:SetTextColor(0.65, 0.65, 0.70)
        local msg = "У цій зоні немає квестів"
        if zone and zone ~= "" then
            msg = "У зоні «" .. zone .. "»\nнемає активних квестів"
        end
        hit.fs:SetText(msg)
        hit.fs:Show()
        hit:EnableMouse(false)
        hit:Hide()
        hit.isObj = false
        hit.isTitle = false
        hit.entry = nil
        y = -70
        local j
        for j = 2, TRK_MAX do
            lines[j]:Hide()
            lines[j].fs:Hide()
            lines[j].entry = nil
            lines[j].isObj = false
            lines[j].isTitle = false
            if lines[j].selBar then lines[j].selBar:Hide() end
            if lines[j].readyIcon then lines[j].readyIcon:Hide() end
            if lines[j].divBg then lines[j].divBg:Hide() end
        end
        -- skip normal loop by jumping to content height calc below
        -- (we set lineNo and y, then fall through after a fake end)
    end

    local doneSection = false
    for i = 1, table.getn(shown) do
        if lineNo >= TRK_MAX - 2 then break end
        local e = shown[i]

        -- розділювач «Завершені» перед першим готовим до здачі
        if (not doneSection) and e.isComplete == 1 then
            doneSection = true
            if lineNo < TRK_MAX then
                y = y - 8
                lineNo = lineNo + 1
                local div = lines[lineNo]
                if not div.divBg then
                    div.divBg = trkBody:CreateTexture(nil, "ARTWORK")
                    div.divBg:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
                    div.divBg:SetVertexColor(0.35, 0.55, 0.35, 0.45)
                    div.divBg:SetHeight(14)
                end
                div.divBg:ClearAllPoints()
                div.divBg:SetPoint("TOPLEFT", trkBody, "TOPLEFT", 0, y)
                div.divBg:SetPoint("TOPRIGHT", trkBody, "TOPRIGHT", 0, y)
                div.divBg:Show()
                div.fs:ClearAllPoints()
                div.fs:SetPoint("LEFT", div.divBg, "LEFT", 4, 0)
                div.fs:SetWidth(tw - 4)
                SetTrkObjFont(div.fs)
                div.fs:SetTextColor(0.55, 0.9, 0.55)
                div.fs:SetText("Завершені")
                div.fs:Show()
                div:EnableMouse(false)
                div:Hide()
                div.isObj = false
                div.isTitle = false
                div.entry = nil
                if div.selBar then div.selBar:Hide() end
                if div.readyIcon then div.readyIcon:Hide() end
                y = y - 16
            end
        end

        local title = e.en
        if e.tr and e.tr.T then title = FormatQuestText(e.tr.T) end
        title = string.gsub(title, "%s+", " ")
        local lv = e.level
        local r, g, b = QuestDiffColor(lv)

        local statusSuffix = ""
        local statusR, statusG, statusB = 1, 0.82, 0
        local isReady = false
        if e.isComplete == 1 then
            isReady = true
            statusSuffix = ""
        elseif e.isComplete == -1 then
            statusSuffix = "Провалено"
            statusR, statusG, statusB = 1.0, 0.25, 0.25
        end

        -- рівний відступ між квестами
        if i > 1 then y = y - 6 end
        questNum = questNum + 1

        local selectedIdx = trkLastSel or 0
        local isSelected = trkSelFromClick and selectedIdx > 0 and (e.logIndex == selectedIdx)

        -- назва (без миші); вибраний у журналі — підсвітка зліва
        lineNo = lineNo + 1
        local hit = lines[lineNo]
        -- скинути «сміття» з розділювача / галочки з попереднього refresh
        if hit.divBg then hit.divBg:Hide() end
        if hit.readyIcon then hit.readyIcon:Hide() end
        if hit.selBar then hit.selBar:Hide() end
        local numStr = "|cffc9a227" .. tostring(questNum) .. "|r  "
        local tWrapped, tLines = WrapByWords(title, wrapChars - 4)
        local titleH = 16 * (tLines or 1)
        if titleH < 16 then titleH = 16 end
        hit.fs:ClearAllPoints()
        hit.fs:SetPoint("TOPLEFT", trkBody, "TOPLEFT", isSelected and 8 or 2, y)
        hit.fs:SetWidth(tw - (isSelected and 8 or 2))
        hit.fs:SetJustifyH("LEFT")
        SetTrkTitleFont(hit.fs)
        if isSelected then
            hit.fs:SetTextColor(math.min(r + 0.15, 1), math.min(g + 0.15, 1), math.min(b + 0.15, 1))
            hit.fs:SetText("|cffffffff>|r " .. numStr .. tWrapped)
        else
            hit.fs:SetTextColor(r, g, b)
            hit.fs:SetText(numStr .. tWrapped)
        end
        hit.fs:Show()
        hit:EnableMouse(false)
        hit:Hide()
        hit.isObj = false
        hit.isTitle = true
        hit.entry = nil

        -- смужка підсвітки зліва для вибраного
        if not hit.selBar then
            hit.selBar = trkBody:CreateTexture(nil, "ARTWORK")
            hit.selBar:SetWidth(2)
            hit.selBar:SetTexture("Interface\\Buttons\\WHITE8X8")
            hit.selBar:SetVertexColor(1, 0.82, 0, 0.85)
        end
        if isSelected then
            hit.selBar:ClearAllPoints()
            hit.selBar:SetPoint("TOPLEFT", trkBody, "TOPLEFT", 1, y)
            hit.selBar:SetHeight(titleH + 2)
            hit.selBar:Show()
        else
            hit.selBar:Hide()
        end

        -- галочка «готово здати» (окрема текстура, не в тексті)
        if not hit.readyIcon then
            hit.readyIcon = trkBody:CreateTexture(nil, "OVERLAY")
            hit.readyIcon:SetWidth(12)
            hit.readyIcon:SetHeight(12)
            hit.readyIcon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            hit.readyIcon:SetVertexColor(0.15, 1.0, 0.2)
        end
        if isReady then
            local baseX = isSelected and 8 or 2
            hit.readyIcon:ClearAllPoints()
            hit.readyIcon:SetPoint("TOPLEFT", trkBody, "TOPLEFT", baseX, y)
            hit.fs:ClearAllPoints()
            hit.fs:SetPoint("TOPLEFT", trkBody, "TOPLEFT", baseX + 14, y)
            hit.fs:SetWidth(tw - (baseX + 14))
            hit.readyIcon:Show()
        else
            hit.readyIcon:Hide()
        end

        y = y - titleH - 1

        if statusSuffix ~= "" and lineNo < TRK_MAX then
            lineNo = lineNo + 1
            local sh = lines[lineNo]
            if sh.divBg then sh.divBg:Hide() end
            if sh.readyIcon then sh.readyIcon:Hide() end
            if sh.selBar then sh.selBar:Hide() end
            sh.fs:ClearAllPoints()
            sh.fs:SetPoint("TOPLEFT", trkBody, "TOPLEFT", isSelected and 16 or 12, y)
            sh.fs:SetWidth(tw - 12)
            SetTrkObjFont(sh.fs)
            sh.fs:SetTextColor(statusR, statusG, statusB)
            sh.fs:SetText(statusSuffix)
            sh.fs:Show()
            sh:EnableMouse(false)
            sh:Hide()
            sh.isObj = false
            sh.entry = nil
            if sh.selBar then sh.selBar:Hide() end
            y = y - 12
        end

        local objs = GetObjectiveLinesForLogIndex(e.logIndex)
        local objCombined = ""
        local oi
        for oi = 1, table.getn(objs) do
            if lineNo >= TRK_MAX then break end
            lineNo = lineNo + 1
            local od = objs[oi]
            local formatted = FormatTrackObjective(od.text)
            local name, cnt = SplitObjectiveNameCount(formatted)
            local done = od.done
            local plainBody
            if name and cnt then
                plainBody = name .. ": " .. cnt
            else
                plainBody = formatted
            end
            -- коли зібрано — назва легкого зеленого, лічильник лишається червоним
            local body
            if done and name and cnt then
                local _, _, cur, maxv = string.find(cnt, "(%d+)/(%d+)")
                local cntColored = CountColorCode(tonumber(cur) or 1, tonumber(maxv) or 1) .. cnt .. "|r"
                body = "|cff8ce68c" .. name .. ":|r " .. cntColored
            else
                body = FormatObjWithCountColor(plainBody)
            end
            objCombined = objCombined .. (objCombined ~= "" and "\n" or "") .. plainBody

            local wrapped, nlines = WrapByWords("- " .. body, wrapChars - 2)
            local h = 14 * (nlines or 1)
            if h < 14 then h = 14 end

            local oh = lines[lineNo]
            if oh.divBg then oh.divBg:Hide() end
            if oh.readyIcon then oh.readyIcon:Hide() end
            if oh.selBar then oh.selBar:Hide() end
            oh.fs:ClearAllPoints()
            oh.fs:SetPoint("TOPLEFT", trkBody, "TOPLEFT", 12, y)
            oh.fs:SetWidth(tw - 12)
            SetTrkObjFont(oh.fs)
            -- колір базового тексту: білий для незавершених, легкий зелений для готових
            if done then
                oh.fs:SetTextColor(0.55, 0.9, 0.55)
            else
                oh.fs:SetTextColor(0.88, 0.88, 0.90)
            end
            oh.fs:SetText(wrapped)
            oh.fs:Show()
            oh:ClearAllPoints()
            oh:SetPoint("TOPLEFT", trkBody, "TOPLEFT", 2, y)
            oh:SetHeight(h + 1)
            oh:SetWidth(tw)
            oh:EnableMouse(true)
            oh:Show()
            oh.entry = e
            oh.isObj = true
            oh.isTitle = false
            e.objText = objCombined
            y = y - h - 2
        end

        if table.getn(objs) == 0 and e.tr and e.tr.O and lineNo < TRK_MAX then
            lineNo = lineNo + 1
            local oh = lines[lineNo]
            if oh.divBg then oh.divBg:Hide() end
            if oh.readyIcon then oh.readyIcon:Hide() end
            if oh.selBar then oh.selBar:Hide() end
            local ot = FormatQuestText(e.tr.O)
            ot = string.gsub(ot, "%s+", " ")
            e.objText = ot
            local wrapped, nlines = WrapByWords("- " .. ot, wrapChars - 2)
            local h = TRK_LINE_H * (nlines or 1)
            if nlines > 3 then
                local short = string.sub(ot, 1, 110)
                wrapped, nlines = WrapByWords("- " .. short, wrapChars - 2)
                h = TRK_LINE_H * (nlines or 1)
            end
            oh.fs:ClearAllPoints()
            oh.fs:SetPoint("TOPLEFT", trkBody, "TOPLEFT", 12, y)
            oh.fs:SetWidth(tw - 12)
            SetTrkObjFont(oh.fs)
            oh.fs:SetTextColor(0.88, 0.88, 0.90)
            oh.fs:SetText(wrapped)
            oh.fs:Show()
            oh:ClearAllPoints()
            oh:SetPoint("TOPLEFT", trkBody, "TOPLEFT", 2, y)
            oh:SetHeight(h + 1)
            oh:SetWidth(tw)
            oh:EnableMouse(true)
            oh:Show()
            oh.entry = e
            oh.isObj = true
            oh.isTitle = false
            y = y - h - 2
        end
    end

    local j
    for j = lineNo + 1, TRK_MAX do
        lines[j]:Hide()
        lines[j].fs:Hide()
        lines[j].entry = nil
        lines[j].isObj = false
        lines[j].isTitle = false
        if lines[j].selBar then lines[j].selBar:Hide() end
        if lines[j].readyIcon then lines[j].readyIcon:Hide() end
        if lines[j].divBg then lines[j].divBg:Hide() end
    end

    -- TranslatePfQuestFrames винесено з трекера (тяжкий обхід дерев фреймів)

    trkContentH = -y + 4
    if trkContentH < 20 then trkContentH = 20 end
    trkBody:SetHeight(trkContentH)
    trkBody:SetWidth(TRK_WIDTH)

    -- висота вікна: header + min(content, available) — жорсткий ліміт для скролу
    trkViewH = maxH - trkHeaderH - PAD
    if trkViewH < 80 then trkViewH = 80 end
    if trkViewH > 420 then trkViewH = 420 end
    local bodyVisible = trkContentH
    if bodyVisible > trkViewH then bodyVisible = trkViewH end
    local height = trkHeaderH + bodyVisible + PAD
    if height > maxH then height = maxH end
    if height < 40 then height = 40 end
    trk:SetHeight(height)

    -- clip: явний розмір (1.12 надійніше ніж лише anchors)
    local clipH = height - trkHeaderH - PAD
    if clipH < 20 then clipH = 20 end
    trkViewH = clipH
    trkClip:ClearAllPoints()
    trkClip:SetPoint("TOPLEFT", trk, "TOPLEFT", PAD, -trkHeaderH)
    trkClip:SetWidth(TRK_WIDTH - PAD * 2)
    trkClip:SetHeight(clipH)

    trkBody:SetWidth(TRK_WIDTH - PAD * 2)
    trkBody:SetHeight(trkContentH)

    TRK.contentH = trkContentH
    TRK.viewH = trkViewH
    TRK.headerH = trkHeaderH
    if TRK.scroll and TRK.scroll > 0 and trkContentH <= trkViewH then
        TRK.scroll = 0
        trkScroll = 0
    end
    ApplyScroll()
    trk:Show()
    U.busy = false
end


local function TranslateQuestWatch()
    OceUA_RefreshQuestTracker()
end

local function SaveWatchedQuests()
    if not GetNumQuestLogEntries or not IsQuestWatched then return end
    OceQuestUA_Settings = OceQuestUA_Settings or {}
    local watched = {}
    local n = GetNumQuestLogEntries()
    local i
    for i = 1, n do
        local qt, level, tag, isHeader = GetQuestLogTitle(i)
        if qt and not isHeader and IsQuestWatched(i) then
            local clean = string.gsub(qt, "%s*%-%s*%([^%)]+%)%s*$", "")
            clean = string.gsub(clean, "%s*%([^%)]+%)%s*$", "")
            local qid = nil
            if type(GetQuestLink) == "function" then
                local link = GetQuestLink(i)
                if link then
                    local _, _, id = string.find(link, "quest:(%d+)")
                    if id then qid = tonumber(id) end
                end
            end
            table.insert(watched, { en = clean, id = qid })
        end
    end
    OceQuestUA_Settings.watched = watched
end

local function RestoreWatchedQuests()
    if not OceQuestUA_Settings or not OceQuestUA_Settings.watched then return end
    if not AddQuestWatch or not IsQuestWatched then return end
    local watched = OceQuestUA_Settings.watched
    local n = GetNumQuestLogEntries()
    local wi
    for wi = 1, table.getn(watched) do
        local w = watched[wi]
        if w then
            local i
            for i = 1, n do
                local qt, level, tag, isHeader = GetQuestLogTitle(i)
                if qt and not isHeader then
                    local clean = string.gsub(qt, "%s*%-%s*%([^%)]+%)%s*$", "")
                    clean = string.gsub(clean, "%s*%([^%)]+%)%s*$", "")
                    local match = false
                    if w.id and type(GetQuestLink) == "function" then
                        local link = GetQuestLink(i)
                        if link and string.find(link, "quest:" .. tostring(w.id)) then match = true end
                    end
                    if not match and w.en and clean == w.en then match = true end
                    if match and not IsQuestWatched(i) then AddQuestWatch(i) end
                end
            end
        end
    end
end

-- throttle: не частіше ніж раз на 0.3с; коалесинг під час логіну
local trkPending = false
local trkLastRefresh = 0
local trkSuppress = false  -- під час RestoreWatchedQuests

local trkThrottle = CreateFrame("Frame")
trkThrottle:Hide()
trkThrottle:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 0.6 then return end
    this.t = 0
    this:Hide()
    if trkPending and not trkSuppress then
        trkPending = false
        if OceUA_RefreshQuestTracker then OceUA_RefreshQuestTracker() end
    end
end)

local function RequestTrackerRefresh()
    if trkSuppress then return end
    trkPending = true
    trkThrottle.t = trkThrottle.t or 0
    trkThrottle:Show()
end

local trkEvents = CreateFrame("Frame")
trkEvents:RegisterEvent("QUEST_LOG_UPDATE")
trkEvents:RegisterEvent("QUEST_WATCH_UPDATE")
trkEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
trkEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
trkEvents:RegisterEvent("ZONE_CHANGED")
trkEvents:RegisterEvent("ZONE_CHANGED_INDOORS")
trkEvents:RegisterEvent("VARIABLES_LOADED")
trkEvents:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        trkSuppress = true  -- глушимо оновлення на старті
        this.t = 0
        this:SetScript("OnUpdate", function()
            this.t = this.t + arg1
            if this.t < 3.5 then return end
            this:SetScript("OnUpdate", nil)
            RestoreWatchedQuests()
            PlaceTracker()
            trkSuppress = false
            if OceUA_RefreshQuestTracker then OceUA_RefreshQuestTracker() end
        end)
    elseif event == "QUEST_WATCH_UPDATE" or event == "QUEST_LOG_UPDATE" then
        if not trkSuppress then
            SaveWatchedQuests()
            RequestTrackerRefresh()
        end
    else
        RequestTrackerRefresh()
    end
end)

-- без постійного OnUpdate-тіка — лише при зміні барів через події вище

if QuestWatch_Update then
    local oldQW = QuestWatch_Update
    QuestWatch_Update = function(a1, a2, a3, a4)
        oldQW(a1, a2, a3, a4)
        if QuestWatchFrame then QuestWatchFrame:Hide() end
        RequestTrackerRefresh()
    end
end

-- підсвітка вибраного квесту: оновлення одразу при кліку в журналі
local trkSelCooldown = 0
-- trkLastSel / trkSelFromClick / trkLogGraceUntil — оголошені вище
-- ВАЖЛИВО: підсвітка ТІЛЬКИ від кліку по рядку журналу.
-- SelectQuestLogEntry гра викликає сама (і часто «стрибає» на завершений) — ігноруємо.

local function ClearTrackerSelection()
    if trkLastSel == 0 and not trkSelFromClick then return end
    trkLastSel = 0
    trkSelFromClick = false
    if RequestTrackerRefresh then RequestTrackerRefresh() end
end

local function SetTrackerSelectionFromClick()
    if not (QuestLogFrame and QuestLogFrame.IsVisible and QuestLogFrame:IsVisible()) then
        ClearTrackerSelection()
        return
    end
    local sel = 0
    if GetQuestLogSelection then sel = GetQuestLogSelection() or 0 end
    -- якщо клікнули заголовок зони — selection може бути 0
    if not sel or sel < 1 then
        ClearTrackerSelection()
        return
    end
    if trkSelFromClick and sel == trkLastSel then return end
    trkSelFromClick = true
    trkLastSel = sel
    if trkSuppress then return end
    local now = GetTime and GetTime() or 0
    if now > 0 and trkSelCooldown > 0 and (now - trkSelCooldown) < 0.25 then
        return
    end
    trkSelCooldown = now
    if TRK then TRK.busy = false end
    if OceUA_RefreshQuestTracker then
        OceUA_RefreshQuestTracker()
    end
end

-- НЕ хукаємо SelectQuestLogEntry / QuestLog_SetSelection — гра смикає їх сама
if type(QuestLogTitleButton_OnClick) == "function" then
    local _oldTB = QuestLogTitleButton_OnClick
    QuestLogTitleButton_OnClick = function(a1, a2, a3, a4)
        _oldTB(a1, a2, a3, a4)
        SetTrackerSelectionFromClick()
    end
end
-- QuestLog_UpdateQuestDetails: без Notify (блимання підсвітки)


if QuestLogFrame then
    local _oldQLShow = QuestLogFrame:GetScript("OnShow")
    QuestLogFrame:SetScript("OnShow", function()
        if _oldQLShow then _oldQLShow() end
        trkSelFromClick = false
        trkLastSel = 0
        trkLogGraceUntil = (GetTime and GetTime() or 0) + 0.8
        -- при відкритті без стрілки, поки гравець сам не клікне рядок
    end)
    local _oldQLHide = QuestLogFrame:GetScript("OnHide")
    QuestLogFrame:SetScript("OnHide", function()
        if _oldQLHide then _oldQLHide() end
        ClearTrackerSelection()
    end)
end

-- backup poll: лише після кліку гравця
-- selPoll прибрано: більше не читаємо GetQuestLogSelection у циклі

local function CollectPfRoots()
    local roots = {}
    local function add(f)
        if f then table.insert(roots, f) end
    end
    if pfQuest then
        add(pfQuest.tracker)
        add(pfQuest.frame)
        add(pfQuest.questlist)
        add(pfQuest.root)
    end
    local names = {
        "pfQuestMap", "pfQuestTracker", "pfQuestTrackerPanel", "pfQuestFrame",
        "pfQuest_Tracker", "pfQuestTrackerBody", "pfQuestList", "pfQuest",
        "pfMap", "pfQuestMinimap", "ShaguQuest", "ShaguQuestFrame"
    }
    local ni
    for ni = 1, table.getn(names) do
        add(getglobal(names[ni]))
    end
    -- скан дітей UIParent за ім'ям
    if UIParent and UIParent.GetChildren then
        local kids = { UIParent:GetChildren() }
        local ci
        for ci = 1, table.getn(kids) do
            local k = kids[ci]
            if k and k.GetName then
                local n = k:GetName()
                if n and (string.find(n, "pfQuest") or string.find(n, "pfquest") or string.find(n, "ShaguQuest")) then
                    add(k)
                end
            end
        end
    end
    return roots
end

local function TranslatePfQuestFrames()
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return end
    if not showUA then return end

    local roots = CollectPfRoots()
    if table.getn(roots) == 0 then return end

    local function walk(frame, depth)
        if not frame or depth > 8 then return end
        if frame.GetRegions then
            local regs = { frame:GetRegions() }
            local ri
            for ri = 1, table.getn(regs) do
                local r = regs[ri]
                if r and r.GetObjectType and r:GetObjectType() == "FontString" and r.GetText and r.SetText then
                    local tx = r:GetText()
                    if tx and tx ~= "" and not HasCyrQ(tx) and string.len(tx) > 2 then
                        local clean = string.gsub(tx, "^%s*%[%d+%]%s*", "")
                        clean = string.gsub(clean, "^%s*%-%s*", "")
                        if not string.find(tx, "%d+/%d+") then
                            local tr = FindTranslation(clean)
                            if tr and tr.T then
                                local label = FormatQuestText(tr.T)
                                local _, _, br = string.find(tx, "^%s*(%[%d+%])")
                                if br then label = br .. " " .. label end
                                r:SetText(label)
                            end
                        else
                            local neu = TranslateObjectiveLine(tx)
                            if neu ~= tx then r:SetText(neu) end
                        end
                    end
                end
            end
        end
        if frame.GetChildren then
            local kids = { frame:GetChildren() }
            local ci
            for ci = 1, table.getn(kids) do
                walk(kids[ci], depth + 1)
            end
        end
    end

    local ri
    for ri = 1, table.getn(roots) do
        walk(roots[ri], 0)
    end
end

--[[============================================================================
    OceUA Quest Tooltip Overlay (Turtle / OctoWoW 1.12)
    Перехоплює GameTooltip:AddLine — переклад БЕЗ блимання.
    Формат pfQuest (map.lua ShowTooltip).
============================================================================]]

local oceTipLastQuestEN = nil  -- остання назва квесту з [!]/[?] у цьому тултіпі

local function OceTip_Strip(s)
    if not s then return "" end
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|T.-|t", "")
    return s
end

local function OceTip_HasMarker(plain)
    if not plain then return false end
    if string.find(plain, "%[!%]") then return true end
    if string.find(plain, "%[%?%]") then return true end
    return false
end

local function OceTip_GetMarker(plain)
    if string.find(plain, "%[!%]") then return "!" end
    if string.find(plain, "%[%?%]") then return "?" end
    return "!"
end

local function OceTip_TitleFromMarker(plain)
    local s = string.gsub(plain, "^%s*", "")
    s = string.gsub(s, "%[!%]", "")
    s = string.gsub(s, "%[%?%]", "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

local function OceTip_IsLevelLine(plain)
    if not plain then return false end
    if string.find(plain, "^%s*%-?%s*[Рр]івень") then return true end
    if string.find(string.lower(plain), "^%s*%-?%s*level") then return true end
    if string.find(plain, "Обов") then return true end
    if string.find(string.lower(plain), "required") then return true end
    return false
end

local function OceTip_IsObjCounter(plain)
    if not plain then return false end
    if OceTip_IsLevelLine(plain) then return false end
    if string.find(plain, "%d+%s*/%s*%d+") then return true end
    if string.find(plain, "^%s*%-") then return true end
    return false
end

local function OceTip_TranslateTitle(en)
    if not en or en == "" then return en end
    if HasCyrQ and HasCyrQ(en) then return en end
    if FindTranslation then
        local tr = FindTranslation(en)
        if tr and tr.T then
            if FormatQuestText then return FormatQuestText(tr.T) end
            return tr.T
        end
    end
    return en
end

local function OceTip_TranslateObj(en)
    if not en or en == "" then return en end
    if HasCyrQ and HasCyrQ(en) then return en end
    if TranslateObjectiveLine then
        local t = TranslateObjectiveLine(en)
        if t and t ~= en then return t end
    end
    return en
end

local function OceTip_TranslateQuestBody(en)
    -- опис / objectives text (O / D) з бази OceUA
    if not en or en == "" then return en end
    if HasCyrQ and HasCyrQ(en) then return en end
    local tr = nil
    if oceTipLastQuestEN and FindTranslation then
        tr = FindTranslation(oceTipLastQuestEN)
    end
    if tr then
        if tr.O and tr.O ~= "" then
            local o = FormatQuestText and FormatQuestText(tr.O) or tr.O
            -- якщо англ. рядок схожий на objectives — підставляємо O
            local enLow = string.lower(OceTip_Strip(en))
            local oLow = string.lower(OceTip_Strip(o))
            if string.len(en) > 15 then
                return o
            end
        end
        if tr.D and tr.D ~= "" and string.len(en) > 40 then
            local d = FormatQuestText and FormatQuestText(tr.D) or tr.D
            return d
        end
    end
    -- fallback: спроба як objective line
    return OceTip_TranslateObj(en)
end

local function OceTip_FindQuestMeta(enTitle)
    local level, complete = nil, nil
    if not GetNumQuestLogEntries or not GetQuestLogTitle then return nil, nil end
    local want = string.lower(enTitle or "")
    if want == "" then return nil, nil end
    local i
    for i = 1, GetNumQuestLogEntries() do
        local qt, lv, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        if not isHeader and qt then
            local clean = string.gsub(qt, "%s*%-%s*%([^%)]+%)%s*$", "")
            clean = string.gsub(clean, "%s*%([^%)]+%)%s*$", "")
            local cl = string.lower(clean)
            if cl == want or string.find(cl, want, 1, true) or string.find(want, cl, 1, true) then
                return lv, isComplete
            end
        end
    end
    return nil, nil
end

-- перенос довгих рядків у тултіпі (вужча рамка)
local OCE_TIP_WRAP = 52  -- «графічних» символів на рядок

local function OceTip_WrapText(text, maxChars)
    if not text or text == "" then return text end
    maxChars = maxChars or OCE_TIP_WRAP
    -- швидкий шлях: короткі рядки без кирилиці
    local plain = text
    -- рахуємо приблизну довжину без color-кодів
    local stripped = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    stripped = string.gsub(stripped, "|r", "")
    if string.len(stripped) <= maxChars + 10 and not string.find(stripped, "[\208\209]") then
        return text
    end
    -- якщо є WrapByWords (з трекера) — використати
    if WrapByWords then
        local wrapped = WrapByWords(text, maxChars)
        return wrapped
    end
    -- простий запасний перенос по пробілах (байти; для UA може різати, але краще ніж нічого)
    local out = ""
    local line = ""
    local i = 1
    local len = string.len(text)
    while i <= len do
        if string.sub(text, i, i) == "|" then
            local nx = string.sub(text, i + 1, i + 1)
            if nx == "c" or nx == "C" then
                line = line .. string.sub(text, i, i + 9)
                i = i + 10
            elseif nx == "r" or nx == "R" then
                line = line .. "|r"
                i = i + 2
            else
                line = line .. string.sub(text, i, i)
                i = i + 1
            end
        else
            local c = string.byte(text, i)
            local n = 1
            if c and c >= 240 then n = 4
            elseif c and c >= 224 then n = 3
            elseif c and c >= 192 then n = 2
            end
            local ch = string.sub(text, i, i + n - 1)
            line = line .. ch
            i = i + n
            -- приблизна ширина: кирилиця = 1 символ
            local vis = string.gsub(line, "|c%x%x%x%x%x%x%x%x", "")
            vis = string.gsub(vis, "|r", "")
            -- рахуємо utf8 символи грубо
            local vlen = 0
            local vi = 1
            local vlen_max = string.len(vis)
            while vi <= vlen_max do
                local b = string.byte(vis, vi)
                if not b then break end
                if b >= 240 then vi = vi + 4
                elseif b >= 224 then vi = vi + 3
                elseif b >= 192 then vi = vi + 2
                else vi = vi + 1 end
                vlen = vlen + 1
            end
            if vlen >= maxChars and ch == " " then
                out = out .. (out ~= "" and "\n" or "") .. string.gsub(line, "%s+$", "")
                line = ""
            elseif vlen >= maxChars + 8 then
                out = out .. (out ~= "" and "\n" or "") .. line
                line = ""
            end
        end
    end
    if line ~= "" then
        out = out .. (out ~= "" and "\n" or "") .. line
    end
    if out == "" then return text end
    return out
end

local function OceTip_StyleMarker(text)
    local plain = OceTip_Strip(text)
    local marker = OceTip_GetMarker(plain)
    local enTitle = OceTip_TitleFromMarker(plain)
    oceTipLastQuestEN = enTitle
    local ua = OceTip_TranslateTitle(enTitle)
    local level, isComplete = OceTip_FindQuestMeta(enTitle)
    local r, g, b = 1.0, 0.82, 0.0
    if level and QuestDiffColor then
        r, g, b = QuestDiffColor(level)
    end
    local col = string.format("|cff%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
    local check = ""
    if isComplete == 1 then
        check = "|cff26ff33✓|r "
    end
    ua = OceTip_WrapText(ua, OCE_TIP_WRAP - 4)
    return check .. "|cffffd100[" .. marker .. "]|r " .. col .. ua .. "|r"
end

local function OceTip_StyleCounter(text)
    local plain = OceTip_Strip(text)
    plain = string.gsub(plain, "^%s+", "")
    plain = string.gsub(plain, "^%- %s*", "")
    plain = string.gsub(plain, "^%-", "")
    plain = string.gsub(plain, "^%s+", "")
    plain = string.gsub(plain, "%s*%[%d+%%%]%s*$", "")
    plain = string.gsub(plain, "%s+$", "")

    local ua = OceTip_TranslateObj(plain)
    local name, cur, maxv
    local _, _, n, c, m = string.find(ua, "^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
    if n and c and m then
        name, cur, maxv = n, tonumber(c), tonumber(m)
    else
        _, _, n, c, m = string.find(ua, "^(.-)%s+(%d+)%s*/%s*(%d+)%s*$")
        if n and c and m and not string.find(n, "%d") then
            name, cur, maxv = n, tonumber(c), tonumber(m)
        end
    end

    if name and cur and maxv then
        name = string.gsub(name, "^%s+", "")
        name = string.gsub(name, "%s+$", "")
        local cntCol = "|cffff2020"
        if CountColorCode then
            cntCol = CountColorCode(cur, maxv)
        end
        if maxv > 0 and cur >= maxv then
            return "|cffaaaaaa- |r|cff8ce68c" .. name .. ":|r " .. cntCol .. cur .. "/" .. maxv .. "|r"
        else
            return "|cffaaaaaa- |r|cffffffff" .. name .. ":|r " .. cntCol .. cur .. "/" .. maxv .. "|r"
        end
    end

    -- без лічильника: " - SpawnName" або " - Придбати: item"
    local body = OceTip_TranslateObj(plain)
    return "|cffaaaaaa- |r|cffd0d0d0" .. body .. "|r"
end

local function OceTip_StyleBody(text)
    local plain = OceTip_Strip(text)
    if plain == "" then return text end
    if OceTip_IsLevelLine(plain) then return text end  -- рівень лишаємо як є (вже UA від pfQuest)
    local ua = OceTip_TranslateQuestBody(plain)
    if ua and ua ~= plain and (HasCyrQ and HasCyrQ(ua)) then
        ua = OceTip_WrapText(ua, OCE_TIP_WRAP)
        return "|cffcccccc" .. ua .. "|r"
    end
    -- навіть без перекладу — перенос дуже довгих рядків
    if string.len(plain) > OCE_TIP_WRAP + 15 then
        return OceTip_WrapText(text, OCE_TIP_WRAP)
    end
    return text
end

-- головний: перекласти рядок ДО показу
local function OceTip_ConvertLine(text)
    if not text or text == "" then return text end
    if OceUA_IsEnabled and not OceUA_IsEnabled("quest") then return text end
    if showUA == false then return text end

    local plain = OceTip_Strip(text)
    if plain == "" then return text end

    if OceTip_HasMarker(plain) then
        return OceTip_StyleMarker(text)
    end
    if OceTip_IsObjCounter(plain) then
        return OceTip_StyleCounter(text)
    end
    -- довгий англ. текст (O/D опис квесту на NPC)
    if not (HasCyrQ and HasCyrQ(plain)) and string.len(plain) > 18 then
        if not OceTip_IsLevelLine(plain) then
            return OceTip_StyleBody(text)
        end
    end
    return text
end

local function OceTip_RescanLines(tip)
    -- тихий допис: якщо щось все ж потрапило англійською (SetText тощо)
    if not tip or not tip.NumLines or not tip.GetName then return end
    if tip._oceua_scanning then return end
    tip._oceua_scanning = true
    local tname = tip:GetName()
    local n = tip:NumLines() or 0
    local i
    for i = 1, n do
        local fs = getglobal(tname .. "TextLeft" .. i)
        if fs and fs.GetText and fs.SetText then
            local tx = fs:GetText()
            if tx and tx ~= "" then
                local neu = OceTip_ConvertLine(tx)
                if neu and neu ~= tx then
                    fs:SetText(neu)
                end
            end
        end
    end
    tip._oceua_scanning = nil
end

local function OceTip_HookTooltip(tip)
    if not tip or tip._oceua_addline_hooked then return end
    tip._oceua_addline_hooked = true

    local oldAddLine = tip.AddLine
    if oldAddLine then
        -- 1.12: AddLine(text, r, g, b, wrapText)
        tip.AddLine = function(self, text, r, g, b, wrap)
            if self._oceua_scanning then
                return oldAddLine(self, text, r, g, b, wrap)
            end
            local neu = OceTip_ConvertLine(text)
            -- довгі описи квестів — обов'язково з переносом, щоб рамка не роз'їжджалась
            local plain = neu and string.gsub(string.gsub(neu, "|c%x%x%x%x%x%x%x%x", ""), "|r", "") or ""
            if plain and string.len(plain) > 45 then
                wrap = 1
            end
            return oldAddLine(self, neu, r, g, b, wrap)
        end
    end

    local oldAddDouble = tip.AddDoubleLine
    if oldAddDouble then
        tip.AddDoubleLine = function(self, t1, t2, r1, g1, b1, r2, g2, b2)
            if not self._oceua_scanning then
                t1 = OceTip_ConvertLine(t1)
                t2 = OceTip_ConvertLine(t2)
            end
            return oldAddDouble(self, t1, t2, r1, g1, b1, r2, g2, b2)
        end
    end

    -- Show: один тихий rescan після того, як pfQuest дописав рядки
    -- без затримки OnUpdate → менше миготіння рамки
    local oldShow = tip.Show
    if oldShow then
        tip.Show = function(self)
            if not self._oceua_scanning then
                OceTip_RescanLines(self)
            end
            return oldShow(self)
        end
    end

    local oldOnShow = tip:GetScript("OnShow")
    tip:SetScript("OnShow", function()
        oceTipLastQuestEN = nil
        if oldOnShow then oldOnShow() end
    end)
    local oldOnHide = tip:GetScript("OnHide")
    tip:SetScript("OnHide", function()
        oceTipLastQuestEN = nil
        if oldOnHide then oldOnHide() end
    end)
end

local function OceTip_HookAll()
    OceTip_HookTooltip(GameTooltip)
    if WorldMapTooltip then OceTip_HookTooltip(WorldMapTooltip) end
    if ItemRefTooltip then OceTip_HookTooltip(ItemRefTooltip) end
end

local oceTipInit = CreateFrame("Frame")
oceTipInit:RegisterEvent("PLAYER_ENTERING_WORLD")
oceTipInit:SetScript("OnEvent", function()
    OceTip_HookAll()
end)
OceTip_HookAll()
