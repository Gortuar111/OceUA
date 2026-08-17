--[[
  OceUA / Skill module v1.4.4
  Переклад скілів / бафів / тренера / професій
  OctoWoW / TurtleWoW (1.12)

  /oceskill test | id | reload | toggle
  Спільні налаштування: /oceua

  1.1.4:  переклад після ShaguTweaks SetInventoryItem (кожен кадр)
  1.1.5:  окремий словник назв предметів (Items_Dictionary.lua)
  1.3.8:  Requires Wands/Swords/Axes… (множина)
  1.3.7:  фікс nil TranslateItemLine (Lua 5.0 forward declare)
  1.3.6:  TradeSkillRequirementText (правильний фрейм Requires)
  1.3.5:  Adds X dps; Requires: у TradeSkill; квести lookup
  1.3.4:  «13 minutes remaining» та подібні
  1.3.3:  Duration:/Requires: професії, інструменти, стійки (парсер)
  1.3.2:  % chance to parry/dodge; повний список коротких рядків
  1.3.1:  фікс «8-25 yd range» → «Дальність 8-25 м»
  1.3.0:  версії x.y.9→x.(y+1).0; ПОЗНАЧКИ.txt; yd range у доках
  1.2.9:  чітка документація Data/, README, позначки куди писати
  1.2.8:  challenges list for this realm only
  1.2.7:  challenges module; full ITEM_STAT; charges/reagents; sec cast
  1.2.6:  sec cast; talents point/points; SkillModules maps
  1.2.0:  OceUA_Settings (enabled / skillShowID через /oceua)
]]

local ADDON_NAME = "OceUA"
local VERSION = "1.6.6"

-- налаштування скілів
-- з 1.2.0 основне джерело — OceUA_Settings (/oceua);
-- OceSkillUA_Config лишається для сумісності зі старими командами /oceskill
OceSkillUA_Config = OceSkillUA_Config or {
  showID = false,
  enabled = true,
}

local Config = OceSkillUA_Config

local function SkillEnabled()
  if OceUA_IsEnabled then
    return OceUA_IsEnabled("skill")
  end
  return Config.enabled ~= false
end

local function SkillShowID()
  if OceUA_Get then
    return OceUA_Get("skillShowID", false) and true or false
  end
  return Config.showID and true or false
end

-- Показувати оригінальну EN-назву над перекладом (для АГ / пошуку)
local function SkillShowOriginal()
  if OceUA_Get then
    local v = OceUA_Get("showOriginal", true)
    if v == false then return false end
    return true
  end
  if Config.showOriginal == false then return false end
  return true
end

local COLOR_HAS = "|cffffd700"
local COLOR_NO  = "|cffff4040"
local COLOR_RST = "|r"

local currentSpellName = nil
local currentSpellRank = nil
local currentSpellID   = nil
local hasAnyTranslation = false
local lastProcessed = 0

-- ============================================================
-- Словник (шаблони з $s1 / цифри в тултіпі)
-- ============================================================
local sortedKeys = {}
local dictUA = {}
local dictMask = {}  -- norm → { [i]=true if token i is $placeholder }
local dictScore = {} -- norm → score (для вибору кращого шаблону при колізії)
local dictCount = 0
local exactUA = {}   -- soft-exact key (регістр/пробіли, АЛЕ числа лишаються) → ua
local exactCount = 0
local skeletonUA = {}  -- «скелет» без # і пробілів → {ua, mask, norm} (запасний матч)
local skeletonCount = 0
local wordIndex = {}   -- слово → { norm1, norm2, ... } інвертований індекс
local zoneTemplates = {}  -- { {pat=lua_pattern, ua=ua}, ... } для $z (назва зони з клієнта)
local zoneTemplateCount = 0

-- eng з $z → lua-pattern: $z ловить назву локації (будь-які символи до наступної фіксованої частини)
local function BuildZonePattern(eng)
  if not eng or not string.find(eng, "$z", 1, true) then return nil end
  -- екрануємо магію lua-pattern, але $z замінюємо на capture
  local parts = {}
  local pos = 1
  local len = string.len(eng)
  while pos <= len do
    local zs, ze = string.find(eng, "$z", pos, true)
    if not zs then
      local tail = string.sub(eng, pos)
      tail = string.gsub(tail, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
      tail = string.gsub(tail, "%s+", "%%s+")
      table.insert(parts, tail)
      break
    end
    if zs > pos then
      local chunk = string.sub(eng, pos, zs - 1)
      chunk = string.gsub(chunk, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
      chunk = string.gsub(chunk, "%s+", "%%s+")
      table.insert(parts, chunk)
    end
    table.insert(parts, "(.+)")
    pos = ze + 1
  end
  local pat = "^" .. table.concat(parts) .. "$"
  -- кінцева крапка опційна
  pat = string.gsub(pat, "%%%.%$", "%%.?$")
  return pat
end

local function MatchZoneTemplate(clean)
  if zoneTemplateCount == 0 or not clean then return nil end
  -- клієнт часто дає "Use: Returns you to ..."
  local variants = { clean }
  local stripped = string.gsub(clean, "^Use:%s*", "")
  if stripped ~= clean then table.insert(variants, stripped) end
  -- без кінцевої крапки
  local noDot = string.gsub(stripped, "%.$", "")
  if noDot ~= stripped then table.insert(variants, noDot) end

  local vi, i
  for vi = 1, table.getn(variants) do
    local text = variants[vi]
    for i = 1, zoneTemplateCount do
      local t = zoneTemplates[i]
      local _, _, capt = string.find(text, t.pat)
      if capt and capt ~= "" and capt ~= "$z" then
        capt = string.gsub(capt, "^%s+", "")
        capt = string.gsub(capt, "%s+$", "")
        capt = string.gsub(capt, "%.$", "")
        -- відкинути надто довгі «фейкові» capture (цілий абзац)
        if string.len(capt) <= 60 and not string.find(capt, "Speak to") then
          local ua = string.gsub(t.ua, "%$z", capt)
          -- якщо був префікс Use: — повернути «Використання:» за бажанням лишаємо без нього (опис у тултіпі)
          return ua
        end
      end
    end
  end
  -- жорсткий fallback для Hearthstone (якщо патерн з бази не зібрався)
  local _, _, loc = string.find(clean, "[Rr]eturns you to ([^%.]+)")
  if loc and not string.find(loc, "your home") and string.len(loc) <= 50 then
    loc = string.gsub(loc, "^%s+", ""); loc = string.gsub(loc, "%s+$", "")
    return "Повертає вас до " .. loc .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення."
  end
  _, _, loc = string.find(clean, "[Yy]our home is currently ([^%.]+)")
  if loc and string.len(loc) <= 50 then
    loc = string.gsub(loc, "^%s+", ""); loc = string.gsub(loc, "%s+$", "")
    return "Повертає вас додому. Наразі ваш дім: " .. loc .. "."
  end
  return nil
end
local STOPWORDS = {
  ["a"]=true, ["an"]=true, ["the"]=true, ["and"]=true, ["or"]=true, ["of"]=true,
  ["to"]=true, ["in"]=true, ["on"]=true, ["for"]=true, ["by"]=true, ["with"]=true,
  ["your"]=true, ["you"]=true, ["is"]=true, ["are"]=true, ["be"]=true,
  ["this"]=true, ["that"]=true, ["from"]=true, ["as"]=true, ["at"]=true,
  ["it"]=true, ["its"]=true, ["will"]=true, ["can"]=true, ["has"]=true,
  ["have"]=true, ["been"]=true, ["was"]=true, ["were"]=true, ["not"]=true, ["no"]=true,
  ["all"]=true, ["any"]=true, ["also"]=true, ["into"]=true, ["than"]=true, ["then"]=true,
  ["when"]=true, ["while"]=true, ["which"]=true, ["who"]=true, ["whom"]=true,
  ["their"]=true, ["them"]=true, ["they"]=true, ["his"]=true, ["her"]=true,
  ["per"]=true, ["each"]=true, ["every"]=true, ["more"]=true, ["less"]=true,
  ["over"]=true, ["under"]=true,
}

-- Прибрати # і пробіли з norm → порівняння «лише слова»
local function SkeletonKey(norm)
  if not norm then return "" end
  local t = string.gsub(norm, "#", "")
  t = string.gsub(t, "%s+", "")
  t = string.gsub(t, "[%.%,;:%-%']", "")
  return t
end

-- Значущі слова з нормалізованого тексту (для інвертованого індексу)
local function SignificantWords(norm)
  if not norm then return {} end
  local words, seen = {}, {}
  local iter = string.gmatch or string.gfind  -- 5.1 / 5.0
  if not iter then return words end
  local w
  for w in iter(norm, "%a%a%a%a+") do  -- ≥4 літери
    if not STOPWORDS[w] and not seen[w] then
      seen[w] = true
      table.insert(words, w)
    end
  end
  return words
end
local itemDictUA = {}      -- exact item name → ua (з Items_Dictionary)
local itemDictCount = 0
local translateCache = {}  -- clean_text -> { translated, ok }
local cacheCount = 0
local CACHE_MAX = 800      -- обмежуємо, щоб не рости нескінченно

-- М'яка нормалізація БЕЗ заміни чисел: для рангів на кшталт "Increased Hit Chance 5"
-- (після повної Normalize всі ранги зліпаються в один ключ — exact рятує)
local function SoftExactKey(text)
  if not text then return "" end
  local t = text
  t = string.gsub(t, "\\[nNrR]", " ")
  t = string.gsub(t, "[\r\n]+", " ")
  t = string.lower(t)
  t = string.gsub(t, "%s+", " ")
  t = string.gsub(t, "^%s+", "")
  t = string.gsub(t, "%s+$", "")
  t = string.gsub(t, "%s*([%.%,;:])%s*", "%1")
  t = string.gsub(t, "([%.%,;:])+", "%1")
  t = string.gsub(t, "%.$", "")  -- кінцева крапка опційна
  t = string.gsub(t, "seconds", "sec")
  t = string.gsub(t, "second", "sec")
  t = string.gsub(t, "secs", "sec")
  t = string.gsub(t, "minutes", "min")
  t = string.gsub(t, "minute", "min")
  t = string.gsub(t, "mins", "min")
  return t
end

-- Нормалізація: $s1/$d/$o1/$t1/... і звичайні числа -> §1, §2, ...
-- Повертає: normalized_text, list_of_tokens (числа/плейсхолдери в порядку)
local function NormalizeForMatch(text)
  if not text then return "", {} end
  local tokens = {}
  local idx = 0
  local function push(tok)
    idx = idx + 1
    tokens[idx] = tok
    return true
  end

  -- Ліворуч-праворуч: знайти найраніший (і найдовший) токен серед усіх типів.
  -- Покриває ВСІ форми з Dictionary.lua: $s1, $d, $20168s1, $7922d,
  -- $/77;10523m1, $*2;20572s1, $lpoint:points;, $ghis:her;, ${$m1*3}, $1% тощо.
  local patterns = {
    -- gender / plural forms
    "%$[lLgG][^%s;]*;?",              -- $lpoint:points;  $ghis:her;  $lRemote-Controlled
    -- balanced braces (rare calc)
    "%$%b{}",                         -- ${$m1*3}
    -- division / multiply refs: $/num;id  $*num;id  $num/num;id
    "%$[%*/]?[%d]+[;/][%w%%%./]+",     -- $/77;10523m1  $*2;20572s1  $25695/5;s1
    -- spell-id refs: $20168s1  $7922d  $3826%
    "%$%d+[a-zA-Z][%d%%]*",            -- $20168s1 $7922d $3826%
    -- plain $letter / $letterN / with %
    "%$[a-zA-Z][%d]*%%?",              -- $s1 $d $a1 $h $n $s1% $h%
    -- pure $number% (rare)
    "%$%d+%%",                         -- $1%
    -- catch-all remaining $... (any leftover form)
    "%$[%w:;%%/%.%*%{%}%-]+",          -- safety net
    -- клієнтські значення (те, що бачить гравець у тултіпі)
    "%d+%.%d+%s*[Mm][Ii][Nn]%.?",      -- 1.5 min
    "%d+%s*[Mm][Ii][Nn]%.?",           -- 2 min / 2 min.
    "%d+%.%d+%s*[Ss][Ee][Cc]%.?",      -- 1.50 sec
    "%d+%s*[Ss][Ee][Cc]%.?",           -- 30 sec
    "[Uu]ntil%s+[Cc]ancelled",         -- until cancelled
    -- діапазони шкоди «12 to 14» / «12-14» (ДО окремих чисел!)
    "%d+%.%d+%s+to%s+%d+%.%d+",        -- 1.5 to 2.5
    "%d+%s+to%s+%d+",                  -- 12 to 14
    "%d+%.%d+%s*%-%s*%d+%.%d+",        -- 1.5-2.5
    "%d+%s*%-%s*%d+",                  -- 12-14
    "%d+%.%d+%%",                      -- 12.5%
    "%d+%%",                           -- 25%
    "%d+%.%d+",                        -- 1.5
    "%d+",                             -- 20  35
  }

  local t = text
  -- уніфікувати переноси: реальний \n/\r і літеральний "\n"/"\r" (якщо словник
  -- був збережений з зайвим екрануванням) → пробіл, щоб ключі збігалися з грою
  t = string.gsub(t, "\\[nNrR]", " ")
  t = string.gsub(t, "[\r\n]+", " ")
  local out = {}
  local pos = 1
  local len = string.len(t)

  while pos <= len do
    local bestS, bestE, bestPat = nil, nil, nil
    local pi
    for pi = 1, table.getn(patterns) do
      local s, e = string.find(t, patterns[pi], pos)
      if s and (not bestS or s < bestS or (s == bestS and e > bestE)) then
        bestS, bestE, bestPat = s, e, patterns[pi]
      end
    end
    if not bestS then
      -- решта тексту без токенів
      table.insert(out, string.sub(t, pos))
      break
    end
    -- текст перед токеном
    if bestS > pos then
      table.insert(out, string.sub(t, pos, bestS - 1))
    end
    -- сам токен
    push(string.sub(t, bestS, bestE))
    table.insert(out, "#")
    pos = bestE + 1
  end

  t = table.concat(out)
  t = string.lower(t)
  t = string.gsub(t, "%s+", " ")
  t = string.gsub(t, "^%s+", "")
  t = string.gsub(t, "%s+$", "")
  -- крапки/коми навколо маркерів і дублі
  t = string.gsub(t, "%s*([%.%,;:])%s*", "%1")
  t = string.gsub(t, "([%.%,;:])+", "%1")
  -- прибрати крапку одразу після/перед # (з $s1. vs 35)
  t = string.gsub(t, "#%.", "#")
  t = string.gsub(t, "%.#", "#")
  t = string.gsub(t, "(%w)#", "%1 #")
  t = string.gsub(t, "#(%w)", "# %1")
  t = string.gsub(t, "%s+", " ")
  t = string.gsub(t, "^%s+", "")
  t = string.gsub(t, "%s+$", "")
  -- масово: sec/secs/seconds, min/mins/minutes → однакові токени
  t = string.gsub(t, "seconds", "sec")
  t = string.gsub(t, "second", "sec")
  t = string.gsub(t, "secs", "sec")
  t = string.gsub(t, "minutes", "min")
  t = string.gsub(t, "minute", "min")
  t = string.gsub(t, "mins", "min")
  t = string.gsub(t, "yards", "yd")
  t = string.gsub(t, "yard", "yd")
  t = string.gsub(t, "yds", "yd")
  -- "$d" у базі = "15 sec" у грі → після заміни чисел лишається "# sec"
  -- згортаємо одиниці часу/відстані після маркера в один токен
  t = string.gsub(t, "#%s*sec", "#")
  t = string.gsub(t, "#%s*min", "#")
  t = string.gsub(t, "#%s*yd", "#")
  -- знову прибрати крапку після # (після згортання "15 sec.")
  t = string.gsub(t, "#%.", "#")
  t = string.gsub(t, "%.#", "#")
  t = string.gsub(t, "%s+", " ")
  t = string.gsub(t, "^%s+", "")
  t = string.gsub(t, "%s+$", "")
  return t, tokens
end

-- Які токени в EN-шаблоні є справжніми $плейсхолдерами (true),
-- а які — літеральними числами на кшталт "10 seconds" (false).
-- Потрібно, щоб ApplyTokens не підставляв літерал "10" замість $s1.
local function BuildPlaceholderMask(eng)
  local _, toks = NormalizeForMatch(eng)
  local mask = {}
  local i
  for i = 1, table.getn(toks) do
    local t = toks[i]
    -- плейсхолдер, якщо починається з $
    if string.sub(t, 1, 1) == "$" then
      mask[i] = true
    else
      mask[i] = false
    end
  end
  return mask
end

local function FilterPlaceholderTokens(tokens, mask)
  if not tokens then return tokens end
  if not mask then return tokens end
  local out = {}
  local i
  for i = 1, table.getn(tokens) do
    -- якщо маски коротші за токени — зайві з кінця вважаємо плейсхолдерами
    if mask[i] == nil or mask[i] then
      table.insert(out, tokens[i])
    end
  end
  return out
end

local function BuildItemDict()
  itemDictUA = {}
  itemDictCount = 0
  if not OceUA_Item_Dictionary then return end
  for eng, ua in pairs(OceUA_Item_Dictionary) do
    if ua and ua ~= "" and ua ~= eng then
      itemDictUA[eng] = ua
      itemDictCount = itemDictCount + 1
    end
  end
end

-- Наскільки «хороший» шаблон при колізії нормалізації.
-- Пріоритет: eng з $плейсхолдерами > ua з $ > довший eng.
-- «Increases … by $s1» перемагає «Increases … by 3».
local function DictEntryScore(eng, ua)
  local score = 0
  if string.find(eng, "%$", 1, true) then score = score + 100 end
  if string.find(ua, "%$", 1, true) then score = score + 40 end
  local elen = string.len(eng)
  if elen > 80 then score = score + 30
  elseif elen > 40 then score = score + 15
  elseif elen > 20 then score = score + 5
  end
  return score
end

local function RegisterNormEntry(eng, ua, score)
  local norm = NormalizeForMatch(eng)
  if not norm or norm == "" then return end
  score = score or DictEntryScore(eng, ua)
  if not dictUA[norm] then
    dictUA[norm] = ua
    dictMask[norm] = BuildPlaceholderMask(eng)
    dictScore[norm] = score
    table.insert(sortedKeys, norm)
    dictCount = dictCount + 1
  else
    local oldScore = dictScore[norm] or 0
    if score > oldScore then
      dictUA[norm] = ua
      dictMask[norm] = BuildPlaceholderMask(eng)
      dictScore[norm] = score
    end
  end
end

local function AddDictTable(src)
  if not src then return end
  for eng, ua in pairs(src) do
    if ua and ua ~= "" and ua ~= eng then
      -- 0) шаблони з $z (назва зони з клієнта — не число)
      --    НЕ реєструємо в norm/exact: інакше $z зникає без підстановки
      if string.find(eng, "$z", 1, true) then
        local pat = BuildZonePattern(eng)
        if pat then
          table.insert(zoneTemplates, { pat = pat, ua = ua })
          zoneTemplateCount = zoneTemplateCount + 1
        end
        -- лише zoneTemplates; далі не йдемо для цього ключа
      else
      -- 1) soft-exact: зберігаємо ВСІ ранги окремо ("Hit Chance 5" ≠ "Hit Chance 3")
      local exact = SoftExactKey(eng)
      if exact ~= "" and not exactUA[exact] then
        exactUA[exact] = ua
        exactCount = exactCount + 1
      end

      -- 2) повна нормалізація
      local score = DictEntryScore(eng, ua)
      RegisterNormEntry(eng, ua, score)

      -- 3) МАСОВО: перше речення окремо (гра часто показує коротший опис)
      --    "Foo. Bar." → також індексуємо "Foo."
      local dotPos = string.find(eng, "%.%s")
      if dotPos and dotPos >= 30 then
        local first = string.sub(eng, 1, dotPos)
        if first ~= eng then
          RegisterNormEntry(first, ua, score - 5)
          local exactFirst = SoftExactKey(first)
          if exactFirst ~= "" and not exactUA[exactFirst] then
            exactUA[exactFirst] = ua
            exactCount = exactCount + 1
          end
        end
      end
      end -- else (не $z)
    end -- if ua
  end -- for
end

local function BuildDict()
  dictUA = {}
  dictMask = {}
  dictScore = {}
  sortedKeys = {}
  dictCount = 0
  exactUA = {}
  exactCount = 0
  skeletonUA = {}
  skeletonCount = 0
  zoneTemplates = {}
  zoneTemplateCount = 0
  translateCache = {}
  cacheCount = 0
  BuildItemDict()
  -- скіли (основне)
  AddDictTable(OceSkillUA_Dictionary)
  -- рецепти + репутація
  AddDictTable(OceUA_Recipes_Dictionary)
  AddDictTable(OceUA_Reputation_Dictionary)
  -- додаткові модулі з Data/SkillModules/
  AddDictTable(OceUA_tooltip_extras)
  AddDictTable(OceUA_holiday)
  AddDictTable(OceUA_profession_ranks)
  AddDictTable(OceUA_pet_teach)
  AddDictTable(OceUA_challenges)
  table.sort(sortedKeys, function(a, b) return string.len(a) > string.len(b) end)
  -- скелет-індекс: слова без чисел — запасний матч коли # розходяться
  local i
  for i = 1, table.getn(sortedKeys) do
    local norm = sortedKeys[i]
    local sk = SkeletonKey(norm)
    if sk ~= "" and string.len(sk) >= 20 and not skeletonUA[sk] then
      skeletonUA[sk] = { ua = dictUA[norm], mask = dictMask[norm], norm = norm }
      skeletonCount = skeletonCount + 1
    end
  end
  -- інвертований індекс слів → кандидати (масовий fuzzy)
  wordIndex = {}
  for i = 1, table.getn(sortedKeys) do
    local norm = sortedKeys[i]
    if string.len(norm) >= 30 then
      local words = SignificantWords(norm)
      local wi
      for wi = 1, table.getn(words) do
        local w = words[wi]
        if not wordIndex[w] then wordIndex[w] = {} end
        local list = wordIndex[w]
        if table.getn(list) < 40 then
          table.insert(list, norm)
        end
      end
    end
  end
end

-- Публічні хелпери для ConfigUA / команд
function OceUA_SkillClearCache()
  translateCache = {}
  cacheCount = 0
  return true
end

function OceUA_SkillReloadDict()
  BuildDict()
  return dictCount, exactCount, itemDictCount, cacheCount
end

function OceUA_SkillStatus()
  local hasSkill = OceSkillUA_Dictionary and true or false
  local hasRec = OceUA_Recipes_Dictionary and true or false
  local hasRep = OceUA_Reputation_Dictionary and true or false
  local hasItem = OceUA_Item_Dictionary and true or false
  local hasExtra = (OceUA_tooltip_extras or OceUA_pet_teach or OceUA_holiday or OceUA_profession_ranks) and true or false
  return {
    version = VERSION,
    enabled = SkillEnabled() and true or false,
    dictCount = dictCount or 0,
    exactCount = exactCount or 0,
    itemCount = itemDictCount or 0,
    cacheCount = cacheCount or 0,
    cacheMax = CACHE_MAX,
    hasSkillDict = hasSkill,
    hasRecipes = hasRec,
    hasReputation = hasRep,
    hasItems = hasItem,
    hasExtraModules = hasExtra,
  }
end

-- ============================================================
-- Переклад
-- ============================================================

-- Точний збіг у «категорійних» словниках (одна копія рядка на весь аддон).
-- Items / Names / Mobs / Objects / Signs / Profession_Names більше не дублюються в Skill_Dictionary.
local function LookupCategoryExact(ek, clean)
  if not ek or ek == "" then return nil end
  local function hit(dict)
    if not dict then return nil end
    local ua = dict[clean] or dict[ek]
    if ua and ua ~= "" and ua ~= clean then return ua end
    return nil
  end
  local ua
  ua = hit(OceUA_Item_Dictionary); if ua then return ua end
  ua = hit(OceUA_NPC_Names_Dictionary); if ua then return ua end
  ua = hit(OceUA_Mobs_Dictionary); if ua then return ua end
  ua = hit(OceUA_Objects_Dictionary); if ua then return ua end
  ua = hit(OceUA_Signs_Dictionary); if ua then return ua end
  ua = hit(OceUA_Profession_Names); if ua then return ua end
  return nil
end

local function StripCodes(text)
  if not text then return "" end
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "|H.-|h(.-)|h", "%1")
  text = string.gsub(text, "|T.-|t", "")
  return text
end

-- Підставити в UA-шаблон значення з тултіпа (по порядку появи плейсхолдерів).
-- Усі форми $... зникають — на їх місце стають реальні числа/час/% з тултіпа.
-- Якщо токенів не вистачило — плейсхолдер просто ховається (не показуємо $xxx).
local function ApplyTokens(ua, tokens)
  if not ua then return ua end
  if not tokens or table.getn(tokens) == 0 then
    -- немає токенів — просто прибрати всі $плейсхолдери
    local cleaned = ua
    cleaned = string.gsub(cleaned, "%$[lLgG][^%s;]*;?", "")
    cleaned = string.gsub(cleaned, "%$%b{}", "")
    cleaned = string.gsub(cleaned, "%$[%*/]?[%d]+[;/][%w%%%./]+", "")
    cleaned = string.gsub(cleaned, "%$%d+[a-zA-Z][%d%%]*", "")
    cleaned = string.gsub(cleaned, "%$[a-zA-Z][%d]*%%?", "")
    cleaned = string.gsub(cleaned, "%$%d+%%", "")
    cleaned = string.gsub(cleaned, "%$[%w:;%%/%.%*%{%}%-]+", "")
    return cleaned
  end

  local ph_patterns = {
    "%$[lLgG][^%s;]*;?",
    "%$%b{}",
    "%$[%*/]?[%d]+[;/][%w%%%./]+",
    "%$%d+[a-zA-Z][%d%%]*",
    "%$[a-zA-Z][%d]*%%?",
    "%$%d+%%",
    "%$[%w:;%%/%.%*%{%}%-]+",
  }

  local out = {}
  local pos = 1
  local len = string.len(ua)
  local ti = 1
  local ntok = table.getn(tokens)

  while pos <= len do
    local bestS, bestE = nil, nil
    local pi
    for pi = 1, table.getn(ph_patterns) do
      local s, e = string.find(ua, ph_patterns[pi], pos)
      if s and (not bestS or s < bestS or (s == bestS and e > bestE)) then
        bestS, bestE = s, e
      end
    end
    if not bestS then
      table.insert(out, string.sub(ua, pos))
      break
    end
    if bestS > pos then
      table.insert(out, string.sub(ua, pos, bestS - 1))
    end
    -- підставляємо значення або ховаємо плейсхолдер
    if ti <= ntok then
      table.insert(out, tokens[ti])
      ti = ti + 1
    end
    -- else: нічого не вставляємо → $xxx зникає
    pos = bestE + 1
  end
  return table.concat(out)
end


-- Фінальна чистка перекладу: залишкові EN одиниці, подвійні пробіли, "на ."
local function CleanupUA(s)
  if not s then return s end
  -- EN одиниці → UA (лише латиниця min/sec/yd, не чіпати вже «хв/сек»)
  s = string.gsub(s, "(%d+%.?%d*)%s*[Ss][Ee][Cc][Ss]?%.?", "%1 сек")
  s = string.gsub(s, "(%d+%.?%d*)%s*[Mm][Ii][Nn][Ss]?%.?", "%1 хв")
  s = string.gsub(s, "(%d+%.?%d*)%s*[Hh][Oo][Uu][Rr][Ss]?%.?", "%1 год")
  s = string.gsub(s, "(%d+%.?%d*)%s*[Yy][Dd][Ss]?%.?", "%1 м")
  -- анти-дубль: "25 хв хв" / "10 сек сек"
  s = string.gsub(s, "(%d+%.?%d*)%s*хв%s+хв", "%1 хв")
  s = string.gsub(s, "(%d+%.?%d*)%s*сек%s+сек", "%1 сек")
  s = string.gsub(s, "(%d+%.?%d*)%s*год%s+год", "%1 год")
  s = string.gsub(s, "(%d+%.?%d*)%s*м%s+м([^%w])", "%1 м%2")
  -- прибрати порожні "на ." / "на ," після зниклих плейсхолдерів
  s = string.gsub(s, "на%s*([%.,;:])", "%1")
  s = string.gsub(s, "%s+([%.,;:])", "%1")
  s = string.gsub(s, "%s+", " ")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

-- Чи вже українською / кирилицею.
-- ВАЖЛИВО: НЕ рахувати будь-який байт >127 — в англ. тексті часто є
-- UTF-8 лапки ('), тире, тощо; старий код через це ПРОПУСКАВ переклад.
-- Кирилиця в UTF-8: переважно префікси D0/D1 (і D2 для ґ).

-- Якщо в UA лишились $s1/$d/… — підставити числа з clean (інакше в грі видно "$d")
local function FinalizeUA(ua, clean)
  if not ua then return ua end
  if clean and string.find(ua, "%$", 1, true) then
    local norm, tokens = NormalizeForMatch(clean)
    local mask = norm and dictMask[norm] or nil
    ua = ApplyTokens(ua, FilterPlaceholderTokens(tokens, mask))
  end
  return CleanupUA(ua)
end

local function HasCyrillic(s)
  if not s then return false end
  -- швидкий пошук типових UTF-8 префіксів кирилиці
  if string.find(s, "\208") then return true end  -- D0: А–п та ін.
  if string.find(s, "\209") then return true end  -- D1: р–я, і, ї, є…
  if string.find(s, "\210") then return true end  -- D2: ґ тощо
  -- CP1251 (рідко, але на всяк випадок): кириличні байти в діапазоні C0–FF
  -- без UTF-8 continuation — лише якщо немає типових UTF-8 lead bytes вище
  return false
end

-- Типові рядки контейнерів (клієнт генерує "8 Slot Quiver" тощо)
-- їх часто не чіпають інші перекладачі → лишається мішанина EN/UA
-- Lua 5.0 (1.12): немає string.match → тільки string.find з captures
local function MatchNum(clean, pattern)
  local _, _, num = string.find(clean, pattern)
  return num
end

local function TranslateContainerLine(clean)
  local num = MatchNum(clean, "^(%d+) Slot Quiver$")
  if num then return "Сагайдак на " .. num .. " слотів", true end
  num = MatchNum(clean, "^(%d+) Slot Bag$")
  if num then return "Сумка на " .. num .. " слотів", true end
  num = MatchNum(clean, "^(%d+) Slot Ammo Pouch$")
  if num then return "Підсумок на " .. num .. " набоїв", true end
  num = MatchNum(clean, "^(%d+) Slot Soul Bag$")
  if num then return "Сумка душ на " .. num .. " слотів", true end
  num = MatchNum(clean, "^(%d+) Slot Herb Bag$")
  if num then return "Сумка для трав на " .. num .. " слотів", true end
  num = MatchNum(clean, "^(%d+) Slot Enchanting Bag$")
  if num then return "Сумка для накладання чар на " .. num .. " слотів", true end
  num = MatchNum(clean, "^(%d+) Slot Mining Bag$")
  if num then return "Сумка рудокопа на " .. num .. " слотів", true end
  num = MatchNum(clean, "^(%d+) Slot Gem Bag$")
  if num then return "Сумка для самоцвітів на " .. num .. " слотів", true end
  num = MatchNum(clean, "^(%d+) Slot Leatherworking Bag$")
  if num then return "Сумка шкірника на " .. num .. " слотів", true end
  -- без числа
  if clean == "Quiver" then return "Сагайдак", true end
  if clean == "Ammo Pouch" then return "Підсумок для набоїв", true end
  if clean == "Soul Bag" then return "Сумка душ", true end
  return nil, false
end

local function TranslateText(text)
  if not text or text == "" then return text, false end

  local clean = StripCodes(text)
  -- уже українською — не чіпаємо (анти-миготіння)
  if HasCyrillic(clean) then return text, false end

  -- кеш: однакові рядки (особливо в інвентарі/АГ) не рахуємо повторно
  local cached = translateCache[clean]
  if cached then
    return cached[1], cached[2]
  end

  -- $z = назва зони з клієнта (Hearthstone тощо) — ДО загального матчу
  local zoneHit = MatchZoneTemplate(clean)
  if zoneHit then
    if cacheCount < CACHE_MAX then
      translateCache[clean] = { zoneHit, true }
      cacheCount = cacheCount + 1
    end
    return zoneHit, true
  end

  -- спочатку прості рядки контейнерів (не залежать від словника скілів)
  local cont, contOk = TranslateContainerLine(clean)
  if contOk then
    if cacheCount < CACHE_MAX then
      translateCache[clean] = { cont, true }
      cacheCount = cacheCount + 1
    end
    return cont, true
  end

  -- точний збіг назви предмета (Items_Dictionary)
  if itemDictCount > 0 then
    local itemUa = itemDictUA[clean]
    if itemUa then
      if cacheCount < CACHE_MAX then
        translateCache[clean] = { itemUa, true }
        cacheCount = cacheCount + 1
      end
      return itemUa, true
    end
  end

  -- soft-exact: числа ЗБЕРІГАЮТЬСЯ → "Increased Hit Chance 5" ≠ "... 3"
  -- це рятує ранги, які після повної Normalize злипаються в один ключ
  if exactCount > 0 then
    local ek = SoftExactKey(clean)
    local exactHit = exactUA[ek]
    if not exactHit then
      exactHit = LookupCategoryExact(ek, clean)
    end
    if exactHit then
      local result = FinalizeUA(exactHit, clean)
      if cacheCount < CACHE_MAX then
        translateCache[clean] = { result, true }
        cacheCount = cacheCount + 1
      end
      return result, true
    end
  end

  if dictCount == 0 then return text, false end

  local norm, tokens = NormalizeForMatch(clean)

  -- 1) точний збіг цілого рядка (після заміни чисел/$ на #)
  local ua = dictUA[norm]
  if ua then
    local result = ApplyTokens(ua, FilterPlaceholderTokens(tokens, dictMask[norm]))
    if cacheCount < CACHE_MAX then
      translateCache[clean] = { result, true }
      cacheCount = cacheCount + 1
    end
    return CleanupUA(result), true
  end

  -- 1b) без кінцевої крапки
  local norm2 = string.gsub(norm, "%.$", "")
  ua = dictUA[norm2]
  local mask = dictMask[norm2]
  if not ua then
    ua = dictUA[norm2 .. "."]
    mask = dictMask[norm2 .. "."]
  end
  if ua then
    local result = ApplyTokens(ua, FilterPlaceholderTokens(tokens, mask))
    if cacheCount < CACHE_MAX then
      translateCache[clean] = { result, true }
      cacheCount = cacheCount + 1
    end
    return CleanupUA(result), true
  end

  -- 1c) скелет (лише слова, без #) — коли кількість/форма чисел трохи розходиться
  if skeletonCount > 0 then
    local sk = SkeletonKey(norm)
    local hit = sk ~= "" and skeletonUA[sk]
    if hit then
      local result = ApplyTokens(hit.ua, FilterPlaceholderTokens(tokens, hit.mask))
      if cacheCount < CACHE_MAX then
        translateCache[clean] = { result, true }
        cacheCount = cacheCount + 1
      end
      return CleanupUA(result), true
    end
    -- префікс скелета (коротший ігровий рядок)
    if string.len(sk) >= 25 then
      local bestSk, bestHit = "", nil
      local skName, skData
      for skName, skData in pairs(skeletonUA) do
        if string.len(skName) > string.len(sk) and string.sub(skName, 1, string.len(sk)) == sk then
          if string.len(skName) > string.len(bestSk) then
            bestSk = skName
            bestHit = skData
          end
        end
      end
      if bestHit then
        local result = ApplyTokens(bestHit.ua, FilterPlaceholderTokens(tokens, bestHit.mask))
        if cacheCount < CACHE_MAX then
          translateCache[clean] = { result, true }
          cacheCount = cacheCount + 1
        end
        return CleanupUA(result), true
      end
    end
  end

  -- 2) підрядок / префікс
  --   а) шаблон з бази є підрядком тексту з гри (≥65% довжини)
  --   б) текст з гри є ПРЕФІКСОМ довшого шаблону в базі
  local translated = clean
  local found = false
  local bestLen = 0
  local bestUa, bestMask = nil, nil
  local normLen = string.len(norm)
  local i
  for i = 1, table.getn(sortedKeys) do
    local engNorm = sortedKeys[i]
    ua = dictUA[engNorm]
    if ua and string.len(engNorm) >= 10 then
      local elen = string.len(engNorm)
      -- а) dict key inside game text
      local s = string.find(norm, engNorm, 1, true)
      if s and elen >= normLen * 0.65 and elen > bestLen then
        bestLen = elen
        bestUa = ua
        bestMask = dictMask[engNorm]
      end
      -- б) game text is prefix of dict key (мін. 25 символів)
      if not s and normLen >= 25 and elen > normLen then
        if string.sub(engNorm, 1, normLen) == norm and normLen > bestLen then
          bestLen = normLen
          bestUa = ua
          bestMask = dictMask[engNorm]
        end
      end
    end
  end
  if bestUa then
    translated = ApplyTokens(bestUa, FilterPlaceholderTokens(tokens, bestMask))
    found = true
  end

  -- 3) МАСОВИЙ fuzzy: голосування за словами (для довгих описів, що «трохи не ті»)
  if not found and normLen >= 35 then
    local gWords = SignificantWords(norm)
    local gCount = table.getn(gWords)
    if gCount >= 3 then
      local votes = {}
      local wi, ci
      for wi = 1, gCount do
        local list = wordIndex[gWords[wi]]
        if list then
          for ci = 1, table.getn(list) do
            local cand = list[ci]
            votes[cand] = (votes[cand] or 0) + 1
          end
        end
      end
      local bestCand, bestVotes = nil, 0
      local cand, vcount
      for cand, vcount in pairs(votes) do
        if vcount > bestVotes then
          -- покриття слів гри ≥ 55% і кандидат не в 3 рази довший
          -- жорсткіше: ≥70% слів гри + кандидат не довший за 1.6× і не коротший за 0.5×
          if vcount * 100 >= gCount * 70
              and string.len(cand) <= (normLen + normLen * 3 / 5)
              and string.len(cand) * 2 >= normLen then
            bestVotes = vcount
            bestCand = cand
          end
        end
      end
      if bestCand and dictUA[bestCand] then
        translated = ApplyTokens(dictUA[bestCand], FilterPlaceholderTokens(tokens, dictMask[bestCand]))
        found = true
      end
    end
  end

  if found and translated then
    translated = CleanupUA(translated)
  end
  -- кешуємо і промахи (щоб не ганяти Normalize знову)
  if cacheCount < CACHE_MAX then
    translateCache[clean] = { translated, found }
    cacheCount = cacheCount + 1
  end
  return translated, found
end

-- forward declare (Lua 5.0 / WoW 1.12: local видно лише після оголошення)
local TranslateItemLine

-- Перекласти FontString на місці
local function TranslateFontString(fs)
  if not fs then return end
  local t = fs:GetText()
  if not t or t == "" then return end
  if HasCyrillic(t) then return end  -- уже перекладено
  -- спочатку типові рядки предмета/професій (Requires:, Duration…), потім словник скілів
  local newT, ok = nil, false
  if TranslateItemLine then
    newT, ok = TranslateItemLine(t)
  end
  if not ok then newT, ok = TranslateText(t) end
  if ok and newT and newT ~= t then
    fs:SetText(newT)
  end
end

-- Рядки предмета: Data/SkillModules/item_tooltip.lua (OceUA_ITEM_*)
-- Дописувати статы/типи зручніше там, а не в цьому файлі.
local EQUIP_EN_TO_UA = OceUA_ITEM_EQUIP or {}
local ITEM_STAT_UA   = OceUA_ITEM_STAT or {}
local ITEM_FIXED_UA  = OceUA_ITEM_FIXED or {}
local ITEM_TYPE_UA   = OceUA_ITEM_TYPE or {}
local ITEM_TEMP_UA   = OceUA_ITEM_TEMP or {}
local ITEM_CLASS_UA  = OceUA_ITEM_CLASS or {}
local ITEM_RACE_UA   = OceUA_ITEM_RACE or {}
local ITEM_PROF_UA   = OceUA_ITEM_PROF or {}
local EQUIP_UA_TO_EN = {}
for en, ua in pairs(EQUIP_EN_TO_UA) do EQUIP_UA_TO_EN[ua] = en end

function OceUA_SyncEquipSlotLocale(tooltip, wantEnglish)
  if not tooltip then return end
  local name = tooltip:GetName() or ""
  local num = tooltip:NumLines() or 0
  local i
  for i = 1, num do
    local left = getglobal(name .. "TextLeft" .. i)
    if left then
      local t = left:GetText()
      if t then
        if wantEnglish then
          local en = EQUIP_UA_TO_EN[t]
          if en then left:SetText(en) end
        else
          local ua = EQUIP_EN_TO_UA[t]
          if ua then left:SetText(ua) end
        end
      end
    end
  end
end

TranslateItemLine = function(text)
  if not text or text == "" then return text, false end
  local clean = StripCodes(text)
  if clean == "" or HasCyrillic(clean) then return text, false end

  -- заголовок ShaguTweaks Equip Compare
  if CURRENTLY_EQUIPPED and clean == CURRENTLY_EQUIPPED then
    return "Зараз екіпіровано", true
  end

  -- точний фікс
  local fixed = ITEM_FIXED_UA[clean]
  if fixed then return fixed, true end
  local typ = ITEM_TYPE_UA[clean]
  if typ then return typ, true end
  local equip = EQUIP_EN_TO_UA[clean]
  if equip then return equip, true end

  -- Requires … / Instant / Passive — РАНІШЕ за SoftExact (щоб не перебивали неповні записи зі словників)
  do
    local rmap = OceUA_ITEM_REQUIRE
    if rmap and rmap[clean] then return rmap[clean], true end
    local sl = OceUA_SKILL_LINES
    if sl and sl[clean] then return sl[clean], true end
  end

  -- Duration: 23 hrs / 30 min / 15 sec / 2 days
  do
    local _, _, n, unit = string.find(clean, "^Duration:%s*(%d+%.?%d*)%s*(%a+)$")
    if n and unit then
      unit = string.lower(unit)
      local u = nil
      if unit == "hr" or unit == "hrs" or unit == "hour" or unit == "hours" then u = "год"
      elseif unit == "min" or unit == "mins" or unit == "minute" or unit == "minutes" then u = "хв"
      elseif unit == "sec" or unit == "secs" or unit == "second" or unit == "seconds" then u = "сек"
      elseif unit == "day" or unit == "days" then u = "дн"
      end
      if u then return "Тривалість: " .. n .. " " .. u, true end
    end
    -- "Duration 23 hrs" без двокрапки
    local _, _, n2, unit2 = string.find(clean, "^Duration%s+(%d+%.?%d*)%s*(%a+)$")
    if n2 and unit2 then
      unit2 = string.lower(unit2)
      local u = nil
      if unit2 == "hr" or unit2 == "hrs" or unit2 == "hour" or unit2 == "hours" then u = "год"
      elseif unit2 == "min" or unit2 == "mins" or unit2 == "minute" or unit2 == "minutes" then u = "хв"
      elseif unit2 == "sec" or unit2 == "secs" or unit2 == "second" or unit2 == "seconds" then u = "сек"
      elseif unit2 == "day" or unit2 == "days" then u = "дн"
      end
      if u then return "Тривалість: " .. n2 .. " " .. u, true end
    end
  end

  -- "13 minutes remaining" / "1 hour remaining" / "30 seconds remaining"
  do
    local _, _, n, unit = string.find(clean, "^(%d+%.?%d*)%s+(%a+)%s+remaining$")
    if n and unit then
      unit = string.lower(unit)
      local u = nil
      if unit == "second" or unit == "seconds" or unit == "sec" or unit == "secs" then u = "сек"
      elseif unit == "minute" or unit == "minutes" or unit == "min" or unit == "mins" then u = "хв"
      elseif unit == "hour" or unit == "hours" or unit == "hr" or unit == "hrs" then u = "год"
      elseif unit == "day" or unit == "days" then u = "дн"
      end
      if u then return "Залишилось " .. n .. " " .. u, true end
    end
    -- "Remaining: 13 minutes"
    local _, _, n2, unit2 = string.find(clean, "^Remaining:%s*(%d+%.?%d*)%s*(%a+)$")
    if n2 and unit2 then
      unit2 = string.lower(unit2)
      local u = nil
      if unit2 == "second" or unit2 == "seconds" or unit2 == "sec" or unit2 == "secs" then u = "сек"
      elseif unit2 == "minute" or unit2 == "minutes" or unit2 == "min" or unit2 == "mins" then u = "хв"
      elseif unit2 == "hour" or unit2 == "hours" or unit2 == "hr" or unit2 == "hrs" then u = "год"
      elseif unit2 == "day" or unit2 == "days" then u = "дн"
      end
      if u then return "Залишилось: " .. n2 .. " " .. u, true end
    end
    -- "Expires in 13 minutes" / "Expires in 1 hour"
    local _, _, n3, unit3 = string.find(clean, "^Expires in (%d+%.?%d*)%s*(%a+)$")
    if n3 and unit3 then
      unit3 = string.lower(unit3)
      local u = nil
      if unit3 == "second" or unit3 == "seconds" or unit3 == "sec" or unit3 == "secs" then u = "сек"
      elseif unit3 == "minute" or unit3 == "minutes" or unit3 == "min" or unit3 == "mins" then u = "хв"
      elseif unit3 == "hour" or unit3 == "hours" or unit3 == "hr" or unit3 == "hrs" then u = "год"
      elseif unit3 == "day" or unit3 == "days" then u = "дн"
      end
      if u then return "Закінчується через " .. n3 .. " " .. u, true end
    end
    -- "Time remaining: 13 min"
    local _, _, n4, unit4 = string.find(clean, "^Time remaining:%s*(%d+%.?%d*)%s*(%a+)$")
    if n4 and unit4 then
      unit4 = string.lower(unit4)
      local u = nil
      if unit4 == "second" or unit4 == "seconds" or unit4 == "sec" or unit4 == "secs" then u = "сек"
      elseif unit4 == "minute" or unit4 == "minutes" or unit4 == "min" or unit4 == "mins" then u = "хв"
      elseif unit4 == "hour" or unit4 == "hours" or unit4 == "hr" or unit4 == "hrs" then u = "год"
      elseif unit4 == "day" or unit4 == "days" then u = "дн"
      end
      if u then return "Залишилось часу: " .. n4 .. " " .. u, true end
    end
  end

  -- "Requires: Tool1, Tool2" / "Requires Tool1, Tool2" — парсимо частини
  do
    local tools = OceUA_ITEM_TOOL
    local body = nil
    local withColon = false
    local _, _, b1 = string.find(clean, "^Requires:%s*(.+)$")
    if b1 then body, withColon = b1, true end
    if not body then
      local _, _, b2 = string.find(clean, "^Requires%s+(.+)$")
      -- не чіпати "Requires Level N" / "Requires Profession (N)" / "Requires N points"
      if b2 and not string.find(b2, "^Level ") and not string.find(b2, "%(%d+%)$")
         and not string.find(b2, "^%d+ points?") then
        body = b2
      end
    end
    if body and tools then
      local iter = string.gmatch or string.gfind
      local parts = {}
      local allOk = true
      for part in iter(body, "[^,]+") do
        part = string.gsub(part, "^%s+", "")
        part = string.gsub(part, "%s+$", "")
        part = string.gsub(part, "%.$", "")
        local ua = tools[part]
        if ua then
          table.insert(parts, ua)
        else
          allOk = false
          table.insert(parts, part)
        end
      end
      if table.getn(parts) > 0 and (allOk or withColon) then
        local joined = table.concat(parts, ", ")
        if withColon then
          return "Потрібно: " .. joined, true
        else
          -- стійки/форми: "Потрібна X або Y"
          if table.getn(parts) == 1 then
            return "Потрібна " .. parts[1], true
          else
            return "Потрібна " .. table.concat(parts, " або "), true
          end
        end
      end
    end
  end

  -- ПОВНИЙ збіг зі словників (tooltip_extras / скіли) — ДО шаблонів.
  -- ОБОВ'ЯЗКОВО з токенами: інакше $d/$s1 лишаються або зникають порожньо.
  do
    local ek = SoftExactKey(clean)
    if ek and ek ~= "" and exactUA[ek] then
      return FinalizeUA(exactUA[ek], clean), true
    end
    do
      local cat = LookupCategoryExact(ek, clean)
      if cat then return FinalizeUA(cat, clean), true end
    end
    local norm, tokens = NormalizeForMatch(clean)
    if norm and dictUA[norm] then
      local result = ApplyTokens(dictUA[norm], FilterPlaceholderTokens(tokens, dictMask[norm]))
      return CleanupUA(result), true
    end
  end

  -- Тимчасові зачарування зброї (Sharpened / Poison / Oil…)
  -- Логіка: рядок ПОЧИНАЄТЬСЯ з ключа з OceUA_ITEM_TEMP → замінюємо лише префікс.
  -- ["Sharpened"] = "Заточено"  покриває "Sharpened +2 (25 min)" → "Заточено +2 (25 хв)"
  do
    local temps = OceUA_ITEM_TEMP or ITEM_TEMP_UA
    if temps then
      local bestEn, bestUa, bestLen = nil, nil, 0
      local en, ua
      for en, ua in pairs(temps) do
        local elen = string.len(en)
        if elen > bestLen and elen < string.len(clean) then
          -- префікс + пробіл/кінець/дужка/плюс
          if string.sub(clean, 1, elen) == en then
            local nextc = string.sub(clean, elen + 1, elen + 1)
            if nextc == "" or nextc == " " or nextc == "+" or nextc == "(" then
              bestEn, bestUa, bestLen = en, ua, elen
            end
          end
        elseif elen == string.len(clean) and clean == en then
          bestEn, bestUa, bestLen = en, ua, elen
        end
      end
      if bestUa then
        local rest = string.sub(clean, bestLen + 1)
        -- одиниці (min→хв) лише в CleanupUA — без подвійного «хв хв»
        return CleanupUA(bestUa .. rest), true
      end
    end
  end

  -- Камінь повернення / Hearthstone: зберегти назву локації ($z у базі)
  -- "Returns you to Stormwind City. Speak to an Innkeeper..."
  local _, _, loc = string.find(clean, "^Returns you to (.+)%. Speak to an Innkeeper in a different place to change your home location%.?$")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Повертає вас до " .. loc .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення.", true
  end
  -- варіант без крапки / з іншими пробілами
  _, _, loc = string.find(clean, "^Returns you to (.+)%.%s*Speak to an Innkeeper")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Повертає вас до " .. loc .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення.", true
  end
  _, _, loc = string.find(clean, "^Returns you to your home%.%s*Your home is currently (.+)%.?$")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Повертає вас додому. Наразі ваш дім: " .. loc .. ".", true
  end
  _, _, loc = string.find(clean, "^Yanks the caster through the twisting nether back to (.+)%.%s*Speak to an Innkeeper")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Переносить вас через Вируючу Порожнечу назад до " .. loc .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення.", true
  end

  -- +N Stat  /  +N% Something
  local _, _, sign, num, rest = string.find(clean, "^([%+%-])(%d+%.?%d*)%s+(.+)$")
  if sign and num and rest then
    local statUa = ITEM_STAT_UA[rest]
    if statUa then
      -- "+12 Stamina" → "+12 до витривалості"
      if string.find(statUa, "^до ") then
        return sign .. num .. " " .. statUa, true
      end
      return sign .. num .. " " .. statUa, true
    end
    -- "+12 All Stats" etc.
    if rest == "All Stats" then return sign .. num .. " до всіх характеристик", true end
    if rest == "All Resistances" then return sign .. num .. " до всіх опорів", true end
    if rest == "Defense Rating" then return sign .. num .. " до рейтингу захисту", true end
    if rest == "Dodge Rating" then return sign .. num .. " до рейтингу ухилення", true end
    if rest == "Parry Rating" then return sign .. num .. " до рейтингу парирування", true end
    if rest == "Hit Rating" then return sign .. num .. " до рейтингу влучності", true end
    if rest == "Critical Strike Rating" then return sign .. num .. " до рейтингу крит. удару", true end
  end

  -- N Armor
  local _, _, armor = string.find(clean, "^(%d+) Armor$")
  if armor then return armor .. " Броня", true end

  -- Block Value
  local _, _, blk = string.find(clean, "^(%d+) Block$")
  if blk then return blk .. " Блок", true end

  -- Durability N / M
  local _, _, d1, d2 = string.find(clean, "^Durability (%d+) / (%d+)$")
  if d1 then return "Міцність " .. d1 .. " / " .. d2, true end

  -- Charges
  local _, _, ch = string.find(clean, "^(%d+) Charges?$")
  if ch then
    local n = tonumber(ch) or 0
    local w = "зарядів"
    if n == 1 then w = "заряд" elseif n >= 2 and n <= 4 then w = "заряди" end
    return ch .. " " .. w, true
  end

  -- Reagents: X
  local _, _, reag = string.find(clean, "^Reagents?:%s*(.+)$")
  if reag then return "Реагенти: " .. reag, true end

  -- Unique (N)
  local _, _, uq = string.find(clean, "^Unique %((%d+)%)$")
  if uq then return "Унікальний (" .. uq .. ")", true end

  -- Requires Level N
  local _, _, lvl = string.find(clean, "^Requires [Ll]evel (%d+)%.?$")
  if lvl then return "Потрібен рівень " .. lvl, true end
  -- Level N (рідко на предметах)
  local _, _, lvl2 = string.find(clean, "^Level (%d+)$")
  if lvl2 then return "Рівень " .. lvl2, true end

  -- Armor N / N Armor
  local _, _, arm = string.find(clean, "^(%d+) Armor$")
  if arm then return arm .. " Броні", true end
  local _, _, arm2 = string.find(clean, "^Armor: (%d+)$")
  if arm2 then return "Броня: " .. arm2, true end

  -- Durability X / Y
  local _, _, d1, d2 = string.find(clean, "^Durability (%d+) / (%d+)$")
  if d1 then return "Міцність " .. d1 .. " / " .. d2, true end
  local _, _, d3, d4 = string.find(clean, "^Durability (%d+)/(%d+)$")
  if d3 then return "Міцність " .. d3 .. " / " .. d4, true end

  -- Speed X.XX (weapon)
  local _, _, spd = string.find(clean, "^Speed (%d+%.?%d*)$")
  if spd then return "Швидкість " .. spd, true end

  -- (X.X damage per second)
  local _, _, dps = string.find(clean, "^%((%d+%.?%d*) damage per second%)$")
  if dps then return "(" .. dps .. " шкоди на секунду)", true end
  -- Adds X damage per second (стріли / снаряди)
  local _, _, adds = string.find(clean, "^Adds (%d+%.?%d*) damage per second$")
  if adds then return "Додає " .. adds .. " шкоди на секунду", true end
  local _, _, adds2 = string.find(clean, "^Adds (%d+%.?%d*)%-*(%d*%.?%d*) damage per second$")
  if adds2 then
    local _, _, a, b = string.find(clean, "^Adds (%d+%.?%d*)%-(%d+%.?%d*) damage per second$")
    if a and b then return "Додає " .. a .. "-" .. b .. " шкоди на секунду", true end
  end
  -- X damage per second (без дужок / Adds)
  local _, _, dps2 = string.find(clean, "^(%d+%.?%d*) damage per second$")
  if dps2 then return dps2 .. " шкоди на секунду", true end
  -- +X damage / +X.X damage
  local _, _, pdmg = string.find(clean, "^%+(%d+%.?%d*) damage$")
  if pdmg then return "+" .. pdmg .. " шкоди", true end

  -- N - M Damage / N Damage
  local _, _, dmg1, dmg2 = string.find(clean, "^(%d+%.?%d*)%s*%-%s*(%d+%.?%d*) Damage$")
  if dmg1 then return dmg1 .. " - " .. dmg2 .. " Шкоди", true end
  local _, _, dmg = string.find(clean, "^(%d+%.?%d*) Damage$")
  if dmg then return dmg .. " Шкоди", true end

  -- N Charges / Stack of N / N sec / N min
  local _, _, ch = string.find(clean, "^(%d+) Charges?$")
  if ch then return ch .. " зарядів", true end
  local _, _, st = string.find(clean, "^Stack of (%d+)$")
  if st then return "Стек з " .. st, true end
  local _, _, secn = string.find(clean, "^(%d+%.?%d*) sec$")
  if secn then return secn .. " сек", true end
  local _, _, minn = string.find(clean, "^(%d+%.?%d*) min$")
  if minn then return minn .. " хв", true end

  -- Classes: A, B, C  / Races: …
  local _, _, classes = string.find(clean, "^Classes:%s*(.+)$")
  if classes then
    local cmap = OceUA_ITEM_CLASS or ITEM_CLASS_UA or {}
    local parts = {}
    local iter = string.gmatch or string.gfind
    for part in iter(classes, "[^,]+") do
      part = string.gsub(part, "^%s+", "")
      part = string.gsub(part, "%s+$", "")
      table.insert(parts, (cmap[part] or part))
    end
    return "Класи: " .. table.concat(parts, ", "), true
  end
  local _, _, races = string.find(clean, "^Races:%s*(.+)$")
  if races then
    local rmap = OceUA_ITEM_RACE or ITEM_RACE_UA or {}
    local parts = {}
    local iter = string.gmatch or string.gfind
    for part in iter(races, "[^,]+") do
      part = string.gsub(part, "^%s+", "")
      part = string.gsub(part, "%s+$", "")
      table.insert(parts, (rmap[part] or part))
    end
    return "Раси: " .. table.concat(parts, ", "), true
  end

  -- Requires … / Instant / Passive — з Data/SkillModules (item_tooltip, skill_lines)
  do
    local rmap = OceUA_ITEM_REQUIRE
    if rmap and rmap[clean] then return rmap[clean], true end
    local sl = OceUA_SKILL_LINES
    if sl and sl[clean] then return sl[clean], true end
  end

  -- Rank N/M (таланти) — масово
  local _, _, r1, r2 = string.find(clean, "^Rank (%d+)/(%d+)$")
  if r1 then return "Ранг " .. r1 .. "/" .. r2, true end
  local _, _, ronly = string.find(clean, "^Rank (%d+)$")
  if ronly then return "Ранг " .. ronly, true end

  -- Типові рядки ресурсу / кулдауну / дальності (масово)
  local _, _, rage = string.find(clean, "^(%d+) Rage$")
  if rage then return rage .. " Люті", true end
  local _, _, mana = string.find(clean, "^(%d+) Mana$")
  if mana then return mana .. " Мани", true end
  local _, _, energy = string.find(clean, "^(%d+) Energy$")
  if energy then return energy .. " Енергії", true end
  local _, _, focus = string.find(clean, "^(%d+) Focus$")
  if focus then return focus .. " Фокусу", true end
  -- час застосування: "2.5 sec cast" / "3 sec cast"
  local _, _, castsec = string.find(clean, "^(%d+%.?%d*)%s*[Ss][Ee][Cc]s?%s+[Cc]ast$")
  if castsec then return castsec .. " сек застосування", true end
  local _, _, castmin = string.find(clean, "^(%d+%.?%d*)%s*[Mm][Ii][Nn]s?%s+[Cc]ast$")
  if castmin then return castmin .. " хв застосування", true end

  local _, _, cdsec = string.find(clean, "^(%d+%.?%d*) sec cooldown$")
  if cdsec then return "Відновлення " .. cdsec .. " сек", true end
  local _, _, cdmin = string.find(clean, "^(%d+%.?%d*) min cooldown$")
  if cdmin then return "Відновлення " .. cdmin .. " хв", true end
  -- "4.80% chance to parry/dodge/block/hit/crit…"
  local _, _, pct, what = string.find(clean, "^(%d+%.?%d*)%% chance to (.+)$")
  if pct and what then
    local map = {
      ["parry"] = "парирувати",
      ["dodge"] = "ухилитися",
      ["block"] = "заблокувати",
      ["hit"] = "влучити",
      ["crit"] = "критичний удар",
      ["critical strike"] = "критичний удар",
      ["critical hit"] = "критичний удар",
      ["resist"] = "опір",
    }
    local w = map[string.lower(what)]
    if w then return pct .. "% шанс " .. w, true end
  end
  -- "+5% chance to …" (іноді з плюсом)
  local _, _, pct2, what2 = string.find(clean, "^%+(%d+%.?%d*)%% chance to (.+)$")
  if pct2 and what2 then
    local map = {
      ["parry"] = "парирувати",
      ["dodge"] = "ухилитися",
      ["block"] = "заблокувати",
      ["hit"] = "влучити",
      ["crit"] = "критичний удар",
      ["critical strike"] = "критичний удар",
      ["critical hit"] = "критичний удар",
      ["resist"] = "опір",
    }
    local w = map[string.lower(what2)]
    if w then return "+" .. pct2 .. "% шанс " .. w, true end
  end

  -- дальність: "30 yd range" / "8-25 yd range" / "8 - 25 yd range"
  local _, _, yd1, yd2 = string.find(clean, "^(%d+)%s*%-%s*(%d+) yd range$")
  if yd1 and yd2 then return "Дальність " .. yd1 .. "-" .. yd2 .. " м", true end
  local _, _, yd = string.find(clean, "^(%d+) yd range$")
  if yd then return "Дальність " .. yd .. " м", true end
  local _, _, yds1, yds2 = string.find(clean, "^(%d+)%s*%-%s*(%d+) yds$")
  if yds1 and yds2 then return yds1 .. "-" .. yds2 .. " м", true end
  local _, _, yds = string.find(clean, "^(%d+) yds$")
  if yds then return yds .. " м", true end
  -- "Melee Range" / "Melee range"
  if clean == "Melee Range" or clean == "Melee range" then
    return "Ближній бій", true
  end
  local _, _, rem = string.find(clean, "^Cooldown remaining: (%d+%.?%d*)%s*sec$")
  if rem then return "До відновлення: " .. rem .. " сек", true end
  local _, _, rem2 = string.find(clean, "^Cooldown remaining: (.+)$")
  if rem2 then
    return CleanupUA("До відновлення: " .. rem2), true
  end
          
  -- Requires N point(s) in X — шаблон у КОДІ; мапи: Data/SkillModules/talents.lua
  -- У словниках НЕ шукай "Потрібно N очок" — цього рядка там немає.
  local _, _, pts, tree = string.find(clean, "^Requires (%d+) points? in (.+)$")
  if pts and tree then
    tree = string.gsub(tree, "^%s+", "")
    tree = string.gsub(tree, "%s+$", "")
    tree = string.gsub(tree, "%.$", "")
    local TREE_UA = OceUA_ITEM_TALENT_TREE or {}
    local NAME_UA = OceUA_ITEM_TALENT_NAME or {}
    local tail = TREE_UA[tree]
    -- гра інколи дає "Arms" без "Talents"
    if not tail then tail = TREE_UA[tree .. " Talents"] end
    if not tail then
      local bare = string.gsub(tree, " Talents$", "")
      if TREE_UA[bare .. " Talents"] then
        tail = TREE_UA[bare .. " Talents"]
      elseif NAME_UA[tree] then
        tail = "таланті «" .. NAME_UA[tree] .. "»"
      elseif NAME_UA[bare] then
        tail = "таланті «" .. NAME_UA[bare] .. "»"
      else
        tail = "таланті «" .. bare .. "»"
      end
    end
    local n = tonumber(pts) or 0
    local word = "очок"
    if n == 1 then word = "очко"
    elseif n >= 2 and n <= 4 then word = "очки" end
    return "Потрібно " .. pts .. " " .. word .. " у " .. tail, true
  end

  -- Requires Profession (N)
  local _, _, prof, plvl = string.find(clean, "^Requires ([%w%s%'%-]+) %((%d+)%)$")
  if prof and plvl then
    local pmap = OceUA_ITEM_PROF or ITEM_PROF_UA
    local pUa = (pmap and pmap[prof]) or prof
    return "Потрібно: " .. pUa .. " (" .. plvl .. ")", true
  end

  -- Classes: Warrior, Mage  (перекладаємо КОЖЕН клас, не лише слово Classes)
  local _, _, classes = string.find(clean, "^Classes:%s*(.+)$")
  if classes then
    local cmap = OceUA_ITEM_CLASS or ITEM_CLASS_UA
    local out = {}
    -- розбити "Warrior, Mage" / "Warrior,Mage"
    local part = classes
    while part and part ~= "" do
      local piece, rest
      local cpos = string.find(part, ",")
      if cpos then
        piece = string.sub(part, 1, cpos - 1)
        rest = string.sub(part, cpos + 1)
      else
        piece = part
        rest = ""
      end
      piece = string.gsub(piece, "^%s+", "")
      piece = string.gsub(piece, "%s+$", "")
      if piece ~= "" then
        local tr = (cmap and cmap[piece]) or piece
        table.insert(out, tr)
      end
      part = rest
    end
    if table.getn(out) > 0 then
      return "Класи: " .. table.concat(out, ", "), true
    end
  end

  -- Races: Human, Orc
  local _, _, races = string.find(clean, "^Races:%s*(.+)$")
  if races then
    local rmap = OceUA_ITEM_RACE or ITEM_RACE_UA
    local out = {}
    local part = races
    while part and part ~= "" do
      local piece, rest
      local cpos = string.find(part, ",")
      if cpos then
        piece = string.sub(part, 1, cpos - 1)
        rest = string.sub(part, cpos + 1)
      else
        piece = part
        rest = ""
      end
      piece = string.gsub(piece, "^%s+", "")
      piece = string.gsub(piece, "%s+$", "")
      if piece ~= "" then
        table.insert(out, (rmap and rmap[piece]) or piece)
      end
      part = rest
    end
    if table.getn(out) > 0 then
      return "Раси: " .. table.concat(out, ", "), true
    end
  end

  -- Damage X - Y
  local _, _, dmg1, dmg2 = string.find(clean, "^(%d+)%s*%-%s*(%d+) Damage$")
  if dmg1 then return dmg1 .. " - " .. dmg2 .. " шкоди", true end

  -- Speed X.XX
  local _, _, spd = string.find(clean, "^Speed (%d+%.?%d*)$")
  if spd then return "Швидкість " .. spd, true end

  -- (X.X damage per second)
  local _, _, dps = string.find(clean, "^%((%d+%.?%d*) damage per second%)$")
  if dps then return "(" .. dps .. " шкоди на секунду)", true end
  local _, _, adds = string.find(clean, "^Adds (%d+%.?%d*) damage per second$")
  if adds then return "Додає " .. adds .. " шкоди на секунду", true end
  local _, _, dps2 = string.find(clean, "^(%d+%.?%d*) damage per second$")
  if dps2 then return dps2 .. " шкоди на секунду", true end

  -- Equip:/Use:/Chance on hit: prefix + rest (rest may be translated by dict later)
  local _, _, prefix, body = string.find(clean, "^(Equip:|Use:|Chance on hit:|Chance on Hit:)%s*(.*)$")
  if prefix then
    local pUa = ITEM_FIXED_UA[prefix] or prefix
    if body and body ~= "" then
      local bodyUa, ok = TranslateText(body)
      if ok then return pUa .. " " .. bodyUa, true end
      return pUa .. " " .. body, true  -- хоча б префікс
    end
    return pUa, true
  end

  return text, false
end

-- Переклад рядків ShoppingTooltip (порівняння при Shift) — після ShaguTweaks
local function ProcessShoppingTooltip(tooltip)
  if not SkillEnabled() then return end
  if not tooltip or not tooltip:IsVisible() then return end
  local name = tooltip:GetName() or ""
  local num = tooltip:NumLines() or 0
  if num == 0 then return end
  local changed = false
  local i
  for i = 1, num do
    local left  = getglobal(name .. "TextLeft" .. i)
    local right = getglobal(name .. "TextRight" .. i)
    if left then
      local t = left:GetText()
      if t and t ~= "" and not HasCyrillic(t) then
        -- 1) типові рядки предмета  2) словник скілів  3) слот екіпіровки
        local newT, ok = TranslateItemLine(t)
        if not ok then newT, ok = TranslateText(t) end
        if not ok then
          local ua = EQUIP_EN_TO_UA[StripCodes(t)]
          if ua then newT, ok = ua, true end
        end
        if ok and newT and newT ~= t then
          left:SetText(newT)
          changed = true
        end
      end
    end
    if right then
      local t = right:GetText()
      if t and t ~= "" and not HasCyrillic(t) then
        local newT, ok = TranslateItemLine(t)
        if not ok then newT, ok = TranslateText(t) end
        if ok and newT and newT ~= t then
          right:SetText(newT)
          changed = true
        end
      end
    end
  end
  if changed then
    tooltip:Show()
  end
end

-- ============================================================
-- GameTooltip (скіли, бафи, тренер-тултіпи, мерчант, професії)
-- ============================================================
local function TooltipSignature(tip)
  if not tip then return "" end
  local name = tip:GetName() or ""
  local parts = {}
  local i
  for i = 1, 4 do
    local fs = getglobal(name .. "TextLeft" .. i)
    if fs then table.insert(parts, fs:GetText() or "") end
  end
  return table.concat(parts, "|")
end

local function ProcessTooltip(tooltip)
  if not SkillEnabled() then return end
  if not tooltip or not tooltip:IsVisible() then return end
  -- ShoppingTooltip обробляється окремо (ProcessShoppingTooltip)
  local tipName = tooltip:GetName() or ""
  if tipName == "ShoppingTooltip1" or tipName == "ShoppingTooltip2" then
    return
  end
  if tooltip.oceDone then return end
  tooltip.oceDone = true

  hasAnyTranslation = false
  local num = tooltip:NumLines() or 0
  if num == 0 then return end

  for i = 1, num do
    local left  = getglobal(tooltip:GetName() .. "TextLeft" .. i)
    local right = getglobal(tooltip:GetName() .. "TextRight" .. i)
    if left then
      local t = left:GetText()
      if t and t ~= "" and not HasCyrillic(t) then
        local newT, ok = TranslateItemLine(t)
        if not ok then newT, ok = TranslateText(t) end
        if ok and newT and newT ~= t then
          hasAnyTranslation = true
          -- перший рядок = назва: UA зверху, сірий EN знизу (зручно для АГ)
          if i == 1 and SkillShowOriginal() then
            local eng = StripCodes(t)
            -- не дублювати, якщо вже однакове / дуже довгий опис
            if eng and eng ~= "" and string.len(eng) <= 60 and eng ~= StripCodes(newT) then
              newT = newT .. "\n|cff999999" .. eng .. "|r"
            end
          end
          left:SetText(newT)
        end
      end
    end
    if right then
      local t = right:GetText()
      if t and t ~= "" and not HasCyrillic(t) then
        local newT, ok = TranslateItemLine(t)
        if not ok then newT, ok = TranslateText(t) end
        if ok and newT and newT ~= t then
          hasAnyTranslation = true
          right:SetText(newT)
        end
      end
    end
  end

  if SkillShowID() then
    -- підхопити назву з тултіпа, якщо хук її не передав
    if (not currentSpellName or currentSpellName == "") then
      local left1 = getglobal(tooltip:GetName() .. "TextLeft1")
      if left1 then
        local raw = left1:GetText()
        if raw and raw ~= "" then
          currentSpellName = StripCodes(raw)
        end
      end
    end
    -- ID-рядок лише коли є хоч щось осмислене (скіл/баф), не на «порожніх» предметах
    local haveId = currentSpellID ~= nil
    local haveName = currentSpellName and currentSpellName ~= ""
    if haveId or haveName then
      local already = false
      for i = 1, (tooltip:NumLines() or 0) do
        local left = getglobal(tooltip:GetName() .. "TextLeft" .. i)
        if left then
          local lt = left:GetText() or ""
          if string.find(lt, "ID:", 1, true) then already = true; break end
        end
      end
      if not already then
        local col = hasAnyTranslation and COLOR_HAS or COLOR_NO
        local idText = col .. "ID: "
        if haveId then
          idText = idText .. tostring(currentSpellID)
        else
          idText = idText .. "н/д"
        end
        if haveName then
          idText = idText .. "  " .. currentSpellName
        end
        if currentSpellRank and currentSpellRank ~= "" then
          idText = idText .. " (" .. currentSpellRank .. ")"
        end
        idText = idText .. COLOR_RST
        tooltip:AddLine(idText, 0.85, 0.85, 0.85)
        tooltip:Show()
      end
    elseif hasAnyTranslation then
      tooltip:Show()
    end
  elseif hasAnyTranslation then
    tooltip:Show()
  end
  -- Після зміни GameTooltip не чіпаємо ShoppingTooltip —
  -- ShaguTweaks сам оновить порівняння на своєму OnUpdate при затиснутому Shift
end

local function MarkPending(tooltip)
  tooltip.ocePending = true
  tooltip.oceDone = nil   -- дозволити один новий прохід
end

-- ============================================================
-- Class Trainer detail panel (нижня частина вікна)
-- ============================================================
local function ProcessTrainerDetails()
  if not SkillEnabled() then return end
  if not ClassTrainerFrame or not ClassTrainerFrame:IsVisible() then return end

  TranslateFontString(ClassTrainerSkillName)
  TranslateFontString(ClassTrainerSkillRequirements)
  TranslateFontString(ClassTrainerSkillDescription)
  -- підпис Cost: теж можна
  if ClassTrainerCostLabel then
    TranslateFontString(ClassTrainerCostLabel)
  end
end

-- ============================================================
-- TradeSkill / Craft detail (професії)
-- ============================================================
-- Переклад списку інструментів "Blacksmith Hammer, Anvil" / з кольорами
local function TranslateToolsList(text)
  if not text or text == "" then return text, false end
  local clean = StripCodes(text)
  if clean == "" or HasCyrillic(clean) then return text, false end
  local tools = OceUA_ITEM_TOOL
  if not tools then return text, false end
  local iter = string.gmatch or string.gfind
  local parts = {}
  local any = false
  for part in iter(clean, "[^,]+") do
    part = string.gsub(part, "^%s+", "")
    part = string.gsub(part, "%s+$", "")
    part = string.gsub(part, "%.$", "")
    local ua = tools[part]
    if ua then
      table.insert(parts, ua)
      any = true
    else
      table.insert(parts, part)
    end
  end
  if any and table.getn(parts) > 0 then
    return table.concat(parts, ", "), true
  end
  return text, false
end

local function ProcessTradeSkillDetails()
  if not SkillEnabled() then return end

  if TradeSkillFrame and TradeSkillFrame:IsVisible() then
    TranslateFontString(TradeSkillSkillName)
    TranslateFontString(TradeSkillDescription)
    -- 1.12: правильні імена — RequirementLabel + RequirementText (НЕ SkillRequirement)
    if TradeSkillRequirementLabel then
      local t = TradeSkillRequirementLabel:GetText()
      if t and not HasCyrillic(t) then
        local low = string.lower(t)
        if low == "requires" or low == "requires:" or t == "Requires" or t == "Requires:" then
          TradeSkillRequirementLabel:SetText("Потрібно:")
        else
          TranslateFontString(TradeSkillRequirementLabel)
        end
      end
    end
    if TradeSkillRequirementText then
      local t = TradeSkillRequirementText:GetText()
      if t and t ~= "" and not HasCyrillic(t) then
        local newT, ok = TranslateToolsList(t)
        if not ok then newT, ok = TranslateItemLine(t) end
        if not ok then newT, ok = TranslateText(t) end
        if ok and newT and newT ~= t then
          TradeSkillRequirementText:SetText(newT)
        end
      end
    end
    -- старі/кастомні імена на всяк випадок
    if TradeSkillSkillRequirement then TranslateFontString(TradeSkillSkillRequirement) end
  end

  if CraftFrame and CraftFrame:IsVisible() then
    TranslateFontString(CraftName)
    TranslateFontString(CraftDescription)
    if CraftRequirements then
      local t = CraftRequirements:GetText()
      if t and t ~= "" and not HasCyrillic(t) then
        local newT, ok = TranslateItemLine(t)
        if not ok then newT, ok = TranslateToolsList(t) end
        if not ok then newT, ok = TranslateText(t) end
        if ok and newT and newT ~= t then CraftRequirements:SetText(newT) end
      end
    end
    if CraftRequirementLabel then
      local t = CraftRequirementLabel:GetText()
      if t and not HasCyrillic(t) then
        local low = string.lower(t or "")
        if low == "requires" or low == "requires:" then
          CraftRequirementLabel:SetText("Потрібно:")
        end
      end
    end
    if CraftRequirementText then
      local t = CraftRequirementText:GetText()
      if t and t ~= "" and not HasCyrillic(t) then
        local newT, ok = TranslateToolsList(t)
        if not ok then newT, ok = TranslateItemLine(t) end
        if ok and newT then CraftRequirementText:SetText(newT) end
      end
    end
  end
end

-- ============================================================
-- Хуки GameTooltip
-- ============================================================
local function HookTooltipMethods()
  local function wrap(oldFunc, extra)
    return function(self, a1, a2, a3, a4, a5)
      currentSpellName = nil
      currentSpellRank = nil
      currentSpellID   = nil
      if extra then extra(self, a1, a2, a3) end
      oldFunc(self, a1, a2, a3, a4, a5)
      MarkPending(self)
    end
  end

  -- Spellbook
  if GameTooltip.SetSpell then
    local old = GameTooltip.SetSpell
    GameTooltip.SetSpell = wrap(old, function(self, id, bookType)
      if id and bookType then
        local name, rank, sid = GetSpellName(id, bookType)
        currentSpellName = name
        currentSpellRank = rank
        -- 1.12: GetSpellName рідко дає реальний spellID; id = слот у книзі
        if type(sid) == "number" then
          currentSpellID = sid
        else
          currentSpellID = id
        end
      end
    end)
  end

  -- Action bars
  if GameTooltip.SetAction then
    local old = GameTooltip.SetAction
    GameTooltip.SetAction = wrap(old, function(self, slot)
      if GetActionText then
        local _, atype, aid = GetActionText(slot)
        if atype == "SPELL" and aid then currentSpellID = aid end
      end
      local left1 = getglobal("GameTooltipTextLeft1")
      if left1 then currentSpellName = StripCodes(left1:GetText() or "") end
    end)
  end

  -- Trainer service tooltip (наведення в списку)
  if GameTooltip.SetTrainerService then
    local old = GameTooltip.SetTrainerService
    GameTooltip.SetTrainerService = wrap(old, function(self, index)
      if index and GetTrainerServiceInfo then
        local name = GetTrainerServiceInfo(index)
        currentSpellName = name
      end
    end)
  end

  -- Merchant (рецепти / товари)
  if GameTooltip.SetMerchantItem then
    local old = GameTooltip.SetMerchantItem
    GameTooltip.SetMerchantItem = wrap(old, function(self, slot)
      local left1 = getglobal("GameTooltipTextLeft1")
      if left1 then currentSpellName = StripCodes(left1:GetText() or "") end
    end)
  end

  -- TradeSkill
  if GameTooltip.SetTradeSkillItem then
    local old = GameTooltip.SetTradeSkillItem
    GameTooltip.SetTradeSkillItem = wrap(old, function(self, index)
      if index and GetTradeSkillInfo then
        local name = GetTradeSkillInfo(index)
        currentSpellName = name
      end
    end)
  end

  -- Craft (Enchanting тощо)
  if GameTooltip.SetCraftSpell then
    local old = GameTooltip.SetCraftSpell
    GameTooltip.SetCraftSpell = wrap(old, nil)
  end
  if GameTooltip.SetCraftItem then
    local old = GameTooltip.SetCraftItem
    GameTooltip.SetCraftItem = wrap(old, nil)
  end

  -- Buffs / Debuffs
  if GameTooltip.SetUnitBuff then
    local old = GameTooltip.SetUnitBuff
    GameTooltip.SetUnitBuff = wrap(old, function(self, unit, index)
      local left1 = getglobal("GameTooltipTextLeft1")
      if left1 then currentSpellName = StripCodes(left1:GetText() or "") end
      if unit == "player" and GetPlayerBuffID then
        local id = GetPlayerBuffID(index)
        if id then currentSpellID = id end
      end
    end)
  end
  if GameTooltip.SetUnitDebuff then
    local old = GameTooltip.SetUnitDebuff
    GameTooltip.SetUnitDebuff = wrap(old, function(self, unit, index)
      local left1 = getglobal("GameTooltipTextLeft1")
      if left1 then currentSpellName = StripCodes(left1:GetText() or "") end
    end)
  end
  if GameTooltip.SetPlayerBuff then
    local old = GameTooltip.SetPlayerBuff
    GameTooltip.SetPlayerBuff = wrap(old, function(self, index)
      local left1 = getglobal("GameTooltipTextLeft1")
      if left1 then currentSpellName = StripCodes(left1:GetText() or "") end
      if GetPlayerBuffID then
        local id = GetPlayerBuffID(index)
        if id then currentSpellID = id end
      end
    end)
  end

  -- Talent
  if GameTooltip.SetTalent then
    local old = GameTooltip.SetTalent
    GameTooltip.SetTalent = wrap(old, function(self)
      local left1 = getglobal("GameTooltipTextLeft1")
      if left1 then currentSpellName = StripCodes(left1:GetText() or "") end
    end)
  end

  -- Предмети: сумка, екіп, лут, buyback, аукціон, пошта, трейд, квести
  -- 0.5.6f: знову вмикаємо MarkPending — кеш + TranslateContainerLine
  -- тримають навантаження низьким. Повертаємо переклад у звичайних сумках.
  -- 1) без зайвих nil  2) ОБОВ’ЯЗКОВО повертаємо результат oldFunc
  --    (PaperDoll дивиться return SetInventoryItem — інакше тултіп порожній)
  local function wrapItem2(oldFunc)
    return function(self, a1, a2)
      currentSpellName = nil
      currentSpellRank = nil
      currentSpellID   = nil
      local r1, r2, r3 = oldFunc(self, a1, a2)
      MarkPending(self)
      return r1, r2, r3
    end
  end
  local function wrapItem1(oldFunc)
    return function(self, a1)
      currentSpellName = nil
      currentSpellRank = nil
      currentSpellID   = nil
      local r1, r2, r3 = oldFunc(self, a1)
      MarkPending(self)
      return r1, r2, r3
    end
  end

  if GameTooltip.SetBagItem then
    local old = GameTooltip.SetBagItem
    GameTooltip.SetBagItem = wrapItem2(old)
  end
  if GameTooltip.SetInventoryItem then
    local old = GameTooltip.SetInventoryItem
    GameTooltip.SetInventoryItem = wrapItem2(old)
  end
  if GameTooltip.SetLootItem then
    local old = GameTooltip.SetLootItem
    GameTooltip.SetLootItem = wrapItem1(old)
  end
  if GameTooltip.SetLootRollItem then
    local old = GameTooltip.SetLootRollItem
    GameTooltip.SetLootRollItem = wrapItem1(old)
  end
  if GameTooltip.SetBuybackItem then
    local old = GameTooltip.SetBuybackItem
    GameTooltip.SetBuybackItem = wrapItem1(old)
  end
  if GameTooltip.SetAuctionItem then
    local old = GameTooltip.SetAuctionItem
    GameTooltip.SetAuctionItem = wrapItem2(old)
  end
  if GameTooltip.SetAuctionSellItem then
    local old = GameTooltip.SetAuctionSellItem
    GameTooltip.SetAuctionSellItem = function(self)
      currentSpellName = nil
      currentSpellRank = nil
      currentSpellID   = nil
      local r1, r2, r3 = old(self)
      MarkPending(self)
      return r1, r2, r3
    end
  end
  if GameTooltip.SetInboxItem then
    local old = GameTooltip.SetInboxItem
    GameTooltip.SetInboxItem = wrapItem2(old)
  end
  if GameTooltip.SetSendMailItem then
    local old = GameTooltip.SetSendMailItem
    GameTooltip.SetSendMailItem = wrapItem1(old)
  end
  if GameTooltip.SetTradePlayerItem then
    local old = GameTooltip.SetTradePlayerItem
    GameTooltip.SetTradePlayerItem = wrapItem1(old)
  end
  if GameTooltip.SetTradeTargetItem then
    local old = GameTooltip.SetTradeTargetItem
    GameTooltip.SetTradeTargetItem = wrapItem1(old)
  end
  if GameTooltip.SetQuestItem then
    local old = GameTooltip.SetQuestItem
    GameTooltip.SetQuestItem = wrapItem2(old)
  end
  if GameTooltip.SetQuestLogItem then
    local old = GameTooltip.SetQuestLogItem
    GameTooltip.SetQuestLogItem = wrapItem2(old)
  end
  if GameTooltip.SetHyperlink then
    local old = GameTooltip.SetHyperlink
    GameTooltip.SetHyperlink = function(self, a1)
      currentSpellName = nil
      currentSpellRank = nil
      currentSpellID   = nil
      local r1, r2, r3 = old(self, a1)
      MarkPending(self)
      return r1, r2, r3
    end
  end

  -- OnUpdate / OnHide
  -- Важливо: не покладаємось лише на MarkPending з SetSpell/SetAction —
  -- на деяких клієнтах (Turtle/кастом) ці методи можуть не хукатись.
  -- Якщо текст тултіпа змінився — перекладаємо знову.
  local oldOnUpdate = GameTooltip:GetScript("OnUpdate")
  GameTooltip:SetScript("OnUpdate", function()
    if oldOnUpdate then oldOnUpdate() end
    if not this:IsVisible() then return end

    local sig = TooltipSignature(this)
    if this.ocePending or (sig ~= "" and sig ~= this.oceLastSig) then
      this.ocePending = nil
      this.oceLastSig = sig
      this.oceDone = nil
      ProcessTooltip(this)
      -- після перекладу оновити сигнатуру (вже UA), щоб не ганяти кожен кадр
      this.oceLastSig = TooltipSignature(this)
    end

    -- При Shift: англ. назви слотів для ShaguTweaks; без Shift: українські
    if OceUA_SyncEquipSlotLocale then
      local shift = IsShiftKeyDown and IsShiftKeyDown()
      if shift ~= this.oceShiftEquip then
        this.oceShiftEquip = shift
        OceUA_SyncEquipSlotLocale(this, shift and true or false)
      end
      if shift then
        if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
          ProcessShoppingTooltip(ShoppingTooltip1)
        end
        if ShoppingTooltip2 and ShoppingTooltip2:IsVisible() then
          ProcessShoppingTooltip(ShoppingTooltip2)
        end
      end
    end
  end)

  local oldOnHide = GameTooltip:GetScript("OnHide")
  GameTooltip:SetScript("OnHide", function()
    this.ocePending = nil
    this.oceDone = nil
    this.oceLastSig = nil
    this.oceShiftEquip = nil
    if oldOnHide then oldOnHide() end
  end)

  -- ItemRefTooltip (лінки з чату) + ShoppingTooltip (порівняння)
  local function HookSimpleTooltip(tip)
    if not tip or tip.ocePendingHooked then return end
    tip.ocePendingHooked = true
    local oldUp = tip:GetScript("OnUpdate")
    tip:SetScript("OnUpdate", function()
      if oldUp then oldUp() end
      if not this:IsVisible() then return end
      local sig = TooltipSignature(this)
      if this.ocePending or (sig ~= "" and sig ~= this.oceLastSig) then
        this.ocePending = nil
        this.oceLastSig = sig
        this.oceDone = nil
        ProcessTooltip(this)
        this.oceLastSig = TooltipSignature(this)
      end
    end)
    local oldHide = tip:GetScript("OnHide")
    tip:SetScript("OnHide", function()
      this.ocePending = nil
      this.oceDone = nil
      this.oceLastSig = nil
      if oldHide then oldHide() end
    end)
    if tip.SetHyperlink then
      local old = tip.SetHyperlink
      tip.SetHyperlink = function(self, a1)
        currentSpellName = nil
        currentSpellRank = nil
        currentSpellID   = nil
        local r1, r2, r3 = old(self, a1)
        MarkPending(self)
        return r1, r2, r3
      end
    end
  end
  if ItemRefTooltip then HookSimpleTooltip(ItemRefTooltip) end

  -- ShoppingTooltip: ShaguTweaks кожен кадр робить SetInventoryItem (EN) →
  -- перекладаємо ПІСЛЯ SetInventoryItem / Show / OnUpdate
  local function HookShoppingTooltip(tip)
    if not tip or tip.oceShopHooked then return end
    tip.oceShopHooked = true

    if tip.SetInventoryItem then
      local oldSet = tip.SetInventoryItem
      tip.SetInventoryItem = function(self, unit, slot)
        local a, b, c = oldSet(self, unit, slot)
        -- Shagu одразу після цього ще AddHeader + Show — переклад у Show/OnUpdate
        self.oceShopDirty = true
        return a, b, c
      end
    end

    local oldShow = tip.Show
    if oldShow then
      tip.Show = function(self)
        oldShow(self)
        if Config.enabled then
          ProcessShoppingTooltip(self)
        end
      end
    end

    local oldUp = tip:GetScript("OnUpdate")
    tip:SetScript("OnUpdate", function()
      if oldUp then oldUp() end
      if this:IsVisible() and Config.enabled then
        ProcessShoppingTooltip(this)
      end
    end)
  end
  if ShoppingTooltip1 then HookShoppingTooltip(ShoppingTooltip1) end
  if ShoppingTooltip2 then HookShoppingTooltip(ShoppingTooltip2) end

  -- Окремий фрейм в кінці черги OnUpdate — добиває переклад після Shagu
  if not OceUA_ShopFixFrame then
    local shopFix = CreateFrame("Frame", "OceUA_ShopFixFrame")
    shopFix:SetScript("OnUpdate", function()
      if not SkillEnabled() then return end
      if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
        ProcessShoppingTooltip(ShoppingTooltip1)
      end
      if ShoppingTooltip2 and ShoppingTooltip2:IsVisible() then
        ProcessShoppingTooltip(ShoppingTooltip2)
      end
    end)
  end
end

-- ============================================================
-- Хуки тренера / професій (деталі внизу вікна)
-- ============================================================
local function HookFrames()
  -- Class Trainer: коли вибирають скіл
  if ClassTrainer_SetSelection then
    local old = ClassTrainer_SetSelection
    ClassTrainer_SetSelection = function(id)
      old(id)
      ProcessTrainerDetails()
    end
  end

  -- Також на OnShow / оновлення
  if ClassTrainerFrame then
    local oldShow = ClassTrainerFrame:GetScript("OnShow")
    ClassTrainerFrame:SetScript("OnShow", function()
      if oldShow then oldShow() end
      ProcessTrainerDetails()
    end)
  end

  -- TradeSkill
  if TradeSkillFrame_SetSelection then
    local old = TradeSkillFrame_SetSelection
    TradeSkillFrame_SetSelection = function(id)
      old(id)
      ProcessTradeSkillDetails()
      -- текст вимог інколи ставиться з затримкою — повторити
      if GetTime then
        local t0 = GetTime()
        local f = CreateFrame("Frame")
        f:SetScript("OnUpdate", function()
          if GetTime() - t0 >= 0.05 then
            ProcessTradeSkillDetails()
            f:SetScript("OnUpdate", nil)
          end
        end)
      end
    end
  end
  if TradeSkillFrame then
    local oldShow = TradeSkillFrame:GetScript("OnShow")
    TradeSkillFrame:SetScript("OnShow", function()
      if oldShow then oldShow() end
      ProcessTradeSkillDetails()
    end)
  end

  -- Craft
  if CraftFrame_SetSelection then
    local old = CraftFrame_SetSelection
    CraftFrame_SetSelection = function(id)
      old(id)
      ProcessTradeSkillDetails()
    end
  end
end

-- ============================================================
-- Події (на випадок, якщо хуки фреймів ще не існують при завантаженні)
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("TRAINER_SHOW")
eventFrame:RegisterEvent("TRAINER_UPDATE")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("CRAFT_SHOW")
eventFrame:RegisterEvent("CRAFT_UPDATE")

-- Окремий watcher: інші аддони можуть перезаписати GameTooltip OnUpdate —
-- цей фрейм живе сам і все одно перекладає видимий тултіп.
local tipWatcher = CreateFrame("Frame")
tipWatcher.elapsed = 0
tipWatcher:SetScript("OnUpdate", function()
  -- ~10 разів/сек достатньо, менше навантаження ніж кожен кадр
  tipWatcher.elapsed = (tipWatcher.elapsed or 0) + (arg1 or 0.03)
  if tipWatcher.elapsed < 0.08 then return end
  tipWatcher.elapsed = 0
  if not SkillEnabled() then return end
  if not GameTooltip or not GameTooltip:IsVisible() then
    if GameTooltip then
      GameTooltip.oceLastSig = nil
      GameTooltip.oceDone = nil
    end
    return
  end
  local sig = TooltipSignature(GameTooltip)
  if sig ~= "" and sig ~= GameTooltip.oceLastSig then
    GameTooltip.oceDone = nil
    GameTooltip.oceLastSig = sig
    ProcessTooltip(GameTooltip)
    GameTooltip.oceLastSig = TooltipSignature(GameTooltip)
  end
  -- ItemRefTooltip (лінки з чату)
  if ItemRefTooltip and ItemRefTooltip:IsVisible() then
    local isig = TooltipSignature(ItemRefTooltip)
    if isig ~= "" and isig ~= ItemRefTooltip.oceLastSig then
      ItemRefTooltip.oceDone = nil
      ItemRefTooltip.oceLastSig = isig
      ProcessTooltip(ItemRefTooltip)
      ItemRefTooltip.oceLastSig = TooltipSignature(ItemRefTooltip)
    end
  end
end)

eventFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    BuildDict()
    HookTooltipMethods()
    -- фрейми тренера/професій можуть вантажитись пізніше
    HookFrames()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA v" .. VERSION .. " — квести, діалоги, книги, скіли, предмети | /oceua")
  elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
    HookFrames()
    ProcessTrainerDetails()
  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE"
      or event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
    HookFrames()
    ProcessTradeSkillDetails()
  end
end)

-- ============================================================
-- Команди
-- ============================================================
SLASH_OCESKILLUA1 = "/oceskill"
SLASH_OCESKILLUA2 = "/oceskill"
SlashCmdList["OCESKILLUA"] = function(msg)
  msg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))

  if msg == "id" then
    local on = not SkillShowID()
    Config.showID = on
    if OceUA_Set then OceUA_Set("skillShowID", on) end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA: ID = " .. (on and "ON" or "OFF"))
  elseif msg == "original" or msg == "orig" or msg == "en" then
    local on = not SkillShowOriginal()
    Config.showOriginal = on
    if OceUA_Set then OceUA_Set("showOriginal", on) end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA: EN-назва над UA = " .. (on and "ON" or "OFF"))
  elseif msg == "reload" or msg == "dict" then
    OceUA_SkillClearCache()
    BuildDict()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA: словник перечитано | templates: " .. tostring(dictCount) .. " | exact: " .. tostring(exactCount) .. " | items: " .. tostring(itemDictCount))
  elseif msg == "test" then
    BuildDict()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA test v" .. VERSION .. " templates=" .. tostring(dictCount) .. " exact=" .. tostring(exactCount) .. " items=" .. tostring(itemDictCount))
    local samples = {
      "A strong attack that increases melee damage by 11 and causes a high amount of threat.",
      "Gives a chance to parry enemy melee attacks.",
      "Increases your Parry chance by 25%.",
      "Increased Hit Chance 5",
      "Increases your damage with Two-Handed Maces by 3.",
      "Heroic Strike",
      "Fireball",
      "Battle Shout",
    }
    local i
    for i = 1, table.getn(samples) do
      local result, ok = TranslateText(samples[i])
      DEFAULT_CHAT_FRAME:AddMessage("|cffffffffIN:|r  " .. samples[i])
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00OUT:|r " .. (result or "?"))
      DEFAULT_CHAT_FRAME:AddMessage("matched=" .. tostring(ok))
    end
  elseif msg == "dump" then
    -- Наведи курсор на скіл і зроби /oceskill dump — побачиш рядки тултіпа і чи знайдено переклад
    if not GameTooltip or not GameTooltip:IsVisible() then
      DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA dump: наведи курсор на скіл/баф і повтори команду")
      return
    end
    local n = GameTooltip:NumLines() or 0
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA dump lines=" .. tostring(n))
    local i
    for i = 1, n do
      local left = getglobal("GameTooltipTextLeft" .. i)
      if left then
        local t = left:GetText() or ""
        if t ~= "" then
          local newT, ok = TranslateText(t)
          local flag = ok and "|cff00ff00OK|r" or "|cffff4040NO|r"
          DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%d] %s %s", i, flag, string.sub(t, 1, 120)))
          if ok and newT and newT ~= t then
            DEFAULT_CHAT_FRAME:AddMessage("       → " .. string.sub(newT, 1, 120))
          end
        end
      end
    end
  elseif msg == "toggle" or msg == "on" or msg == "off" then
    local on
    if msg == "on" then on = true
    elseif msg == "off" then on = false
    else on = not SkillEnabled() end
    Config.enabled = on
    if OceUA_Set then OceUA_Set("skill", on) end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA: " .. (on and "УВІМК" or "ВИМК"))
  elseif msg == "cache" or msg == "clear" then
    OceUA_SkillClearCache()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA: кеш очищено")
  elseif msg == "status" then
    local st = OceUA_SkillStatus()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA status v" .. tostring(st.version))
    DEFAULT_CHAT_FRAME:AddMessage("  enabled=" .. tostring(st.enabled)
      .. "  templates=" .. tostring(st.dictCount)
      .. "  exact=" .. tostring(st.exactCount)
      .. "  items=" .. tostring(st.itemCount)
      .. "  cache=" .. tostring(st.cacheCount) .. "/" .. tostring(st.cacheMax))
    DEFAULT_CHAT_FRAME:AddMessage("  tables: skill=" .. tostring(st.hasSkillDict)
      .. " recipes=" .. tostring(st.hasRecipes)
      .. " rep=" .. tostring(st.hasReputation)
      .. " items=" .. tostring(st.hasItems)
      .. " extra=" .. tostring(st.hasExtraModules))
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rSkillUA v" .. VERSION .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /oceskill test | dump | id | original | reload | cache | status | toggle")
  end
end
