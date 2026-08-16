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
    local d, ua
    d = OceUA_Item_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    d = OceUA_Mobs_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    d = OceUA_NPC_Names_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    d = OceUA_Objects_Dictionary
    if d and d[en] and d[en] ~= "" then return d[en] end
    return nil
end

-- у рядку цілі замінити відомі EN-назви (довші першими не сортуємо масово —
-- простий прохід: якщо весь рядок без лічильника збігається; або "Name: 0/10")
local function TranslateObjectiveLine(text)
    if not text or text == "" then return text end
    if string.find(text, "[А-Яа-яІіЇїЄєҐґ]") then return text end

    -- "Something: 3/10" або "Something slain: 0/5"
    local _, _, name, rest = string.find(text, "^(.+):%s*(%d+/%d+)%s*$")
    if name and rest then
        local ua = LookupWorldName(name)
        if ua then return ua .. ": " .. rest end
        -- інколи "Name slain"
        local _, _, base = string.find(name, "^(.+) slain$")
        if base then
            ua = LookupWorldName(base)
            if ua then return ua .. " (убито): " .. rest end
        end
        return text
    end

    -- повний збіг
    local ua = LookupWorldName(text)
    if ua then return ua end
    return text
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
