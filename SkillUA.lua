--[[
  OceUA / Skill module v3.2.1
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
local VERSION = "3.2.1"

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


local function TranslateZoneName(en)
  if not en or en == "" then return en end
  if OceUA_TranslateZoneName then
    local z = OceUA_TranslateZoneName(en)
    if z then return z end
  end
  local function lookup(dict, key)
    if not dict or not key then return nil end
    local ua = dict[key]
    if ua and ua ~= "" and ua ~= key then return ua end
    return nil
  end
  local ua = lookup(OceUA_Zones_Dictionary, en)
  if ua then return ua end
  local stripped = string.gsub(en, "^[Tt]he%s+", "")
  if stripped ~= en then
    ua = lookup(OceUA_Zones_Dictionary, stripped)
    if ua then return ua end
  end
  -- Signs лише якщо ключа немає в Zones (без дублікатів)
  if not (OceUA_Zones_Dictionary and OceUA_Zones_Dictionary[en]) then
    ua = lookup(OceUA_Signs_Dictionary, en)
    if ua then return ua end
  end
  if stripped ~= en and not (OceUA_Zones_Dictionary and OceUA_Zones_Dictionary[stripped]) then
    ua = lookup(OceUA_Signs_Dictionary, stripped)
    if ua then return ua end
  end
  return en
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
          if TranslateZoneName then capt = TranslateZoneName(capt) end
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
    return "Повертає вас до " .. TranslateZoneName(loc) .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення."
  end
  _, _, loc = string.find(clean, "[Yy]our home is currently ([^%.]+)")
  if loc and string.len(loc) <= 50 then
    loc = string.gsub(loc, "^%s+", ""); loc = string.gsub(loc, "%s+$", "")
    return "Повертає вас додому. Наразі ваш дім: " .. TranslateZoneName(loc) .. "."
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
-- Items_Dictionary.lua у старих збірках мав назву таблиці OceUA_Items_Dictionary,
-- а SkillUA історично очікує OceUA_Item_Dictionary.
-- Тримаємо обидва імені, щоб назви предметів реально працювали в усіх шляхах UI.
if not OceUA_Item_Dictionary and OceUA_Items_Dictionary then
  OceUA_Item_Dictionary = OceUA_Items_Dictionary
elseif not OceUA_Items_Dictionary and OceUA_Item_Dictionary then
  OceUA_Items_Dictionary = OceUA_Item_Dictionary
end

local itemDictUA = {}      -- exact item name → ua (з Items_Dictionary)
local itemDictLowerUA = {} -- case-insensitive exact item name → ua
local professionDictLowerUA = {} -- case-insensitive profession name → ua
local itemDictCount = 0
local translateCache = {}  -- clean_text -> { translated, ok }
local cacheCount = 0
local CACHE_MAX = 4000      -- обмежуємо, щоб не рости нескінченно

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

-- М'який ключ: усі числа → # (масовий матч описів з підставленими рангами)
local softNormUA = {}
local softNormCount = 0

local CHALLENGE_UA_FIX = {
  ["Подорож Вагранта"] = "Подвиг мандрівника",
  ["Похід Варганта"] = "Подвиг мандрівника",
  ["Пригода з бурінням"] = "Свиняча пригода",
  ["Пригода на борту"] = "Свиняча пригода",
  ["Божевільний першого рівня"] = "Божевільний 1 рівня",
  ["Шлях майстра пивоваріння"] = "Шлях пивовара",
  ["Мандрівний майстер-ремісник"] = "Мандрівний майстер ремесел",
}


local function SoftNormKey(text)
  if not text then return "" end
  local t = SoftExactKey(text)
  -- $плейсхолдери теж у #
  t = string.gsub(t, "%$[lLgG][^%s;]*;?", "#")
  t = string.gsub(t, "%$%b{}", "#")
  t = string.gsub(t, "%$[%*/]?[%d]+[;/][%w%%%./]+", "#")
  t = string.gsub(t, "%$%d+[a-zA-Z][%d%%]*", "#")
  t = string.gsub(t, "%$[a-zA-Z][%d]*%%?", "#")
  t = string.gsub(t, "%$%d+%%", "#")
  t = string.gsub(t, "%$[%w:;%%/%.%*%{%}%-]+", "#")
  t = string.gsub(t, "%d+%.%d+%%", "#")
  t = string.gsub(t, "%d+%%", "#")
  t = string.gsub(t, "%d+%.%d+", "#")
  t = string.gsub(t, "%d+", "#")
  t = string.gsub(t, "#%%", "#")
  t = string.gsub(t, "#%s*sec", "#")
  t = string.gsub(t, "#%s*min", "#")
  t = string.gsub(t, "#%s*yd", "#")
  t = string.gsub(t, "seconds", "sec")
  t = string.gsub(t, "second", "sec")
  t = string.gsub(t, "secs", "sec")
  t = string.gsub(t, "minutes", "min")
  t = string.gsub(t, "minute", "min")
  t = string.gsub(t, "#+", "#")
  -- слова від $l (attack/attacks) після числа — зводимо
  t = string.gsub(t, "#%s*attacks", "#")
  t = string.gsub(t, "#%s*attack", "#")
  t = string.gsub(t, "#%s*points", "#")
  t = string.gsub(t, "#%s*point", "#")
  t = string.gsub(t, "#%s*charges", "#")
  t = string.gsub(t, "#%s*charge", "#")
  t = string.gsub(t, "#%s*sec", "#")
  t = string.gsub(t, "#%s*min", "#")
  -- $n + $l → два # підряд
  t = string.gsub(t, "#%s*#", "#")
  t = string.gsub(t, "%s+", " ")
  t = string.gsub(t, "^%s+", "")
  t = string.gsub(t, "%s+$", "")
  t = string.gsub(t, "%.$", "")
  t = string.gsub(t, ", ", ",")
  t = string.gsub(t, ",", ", ")
  t = string.gsub(t, "%s+", " ")
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
  itemDictLowerUA = {}
  professionDictLowerUA = {}
  itemDictCount = 0

  -- Compatibility: source file currently exports plural name.
  if not OceUA_Item_Dictionary and OceUA_Items_Dictionary then
    OceUA_Item_Dictionary = OceUA_Items_Dictionary
  end

  if OceUA_Item_Dictionary then
    for eng, ua in pairs(OceUA_Item_Dictionary) do
      if type(eng) == "string" and type(ua) == "string" and ua ~= "" and ua ~= eng then
        itemDictUA[eng] = ua
        itemDictLowerUA[string.lower(eng)] = ua
        itemDictCount = itemDictCount + 1
      end
    end
  end

  if OceUA_Profession_Names then
    for eng, ua in pairs(OceUA_Profession_Names) do
      if type(eng) == "string" and type(ua) == "string" and ua ~= "" and ua ~= eng then
        professionDictLowerUA[string.lower(eng)] = ua
      end
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

-- Розгорнути $lword:words; / $ghis:her; у літеральні варіанти для індексу
local function ExpandGrammarVariants(eng)
  if not eng or not string.find(eng, "%$", 1, true) then
    return { eng }
  end
  local variants = { eng }
  local i
  -- повторюємо кілька разів (кілька $l у одному рядку)
  for i = 1, 6 do
    local nextv = {}
    local any = false
    local vi
    for vi = 1, table.getn(variants) do
      local s = variants[vi]
      local a, b, w1, w2 = string.find(s, "%$[lL]([^:;]+):([^;]+);")
      if a then
        any = true
        local pre = string.sub(s, 1, a - 1)
        local post = string.sub(s, b + 1)
        table.insert(nextv, pre .. w1 .. post)
        table.insert(nextv, pre .. w2 .. post)
      else
        local c, d, g1, g2 = string.find(s, "%$[gG]([^:;]+):([^;]+);")
        if c then
          any = true
          local pre = string.sub(s, 1, c - 1)
          local post = string.sub(s, d + 1)
          table.insert(nextv, pre .. g1 .. post)
          table.insert(nextv, pre .. g2 .. post)
        else
          table.insert(nextv, s)
        end
      end
    end
    variants = nextv
    if not any then break end
  end
  return variants
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
      -- soft-norm: "75% for 5 sec" ↔ "$s1% for $d"
      local sn = SoftNormKey(eng)
      if sn ~= "" and string.len(sn) >= 20 and not softNormUA[sn] then
        softNormUA[sn] = ua
        softNormCount = softNormCount + 1
      end
      -- варіанти $l / $g як у клієнті (attack vs attacks)
      local gvars = ExpandGrammarVariants(eng)
      local gi
      for gi = 1, table.getn(gvars) do
        if gvars[gi] ~= eng then
          RegisterNormEntry(gvars[gi], ua, score - 1)
          local exg = SoftExactKey(gvars[gi])
          if exg ~= "" and not exactUA[exg] then
            exactUA[exg] = ua
            exactCount = exactCount + 1
          end
          local sng = SoftNormKey(gvars[gi])
          if sng ~= "" and string.len(sng) >= 20 and not softNormUA[sng] then
            softNormUA[sng] = ua
            softNormCount = softNormCount + 1
          end
        end
      end

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
  softNormUA = {}
  softNormCount = 0
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
  AddDictTable(OceUA_Aura_Descriptions)
  -- рецепти + репутація
  AddDictTable(OceUA_Recipes_Dictionary)
  AddDictTable(OceUA_Reputation_Dictionary)
  -- додаткові модулі з Data/SkillModules/
  AddDictTable(OceUA_tooltip_extras)
  AddDictTable(OceUA_holiday)
  AddDictTable(OceUA_profession_ranks)
  AddDictTable(OceUA_pet_teach)
  AddDictTable(OceUA_challenges)
  -- challenges: soft-exact має перебивати старі рядки з Skill_Dictionary
  if OceUA_challenges then
    for eng, ua in pairs(OceUA_challenges) do
      if ua and ua ~= "" and eng ~= "Challenge" then
        local exact = SoftExactKey(eng)
        if exact ~= "" then
          exactUA[exact] = ua
        end
        local sn = SoftNormKey(eng)
        if sn ~= "" and string.len(sn) >= 12 then
          softNormUA[sn] = ua
        end
        -- прямий exact без soft key
        exactUA[string.lower(eng)] = ua
      end
    end
  end
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
  local hasItem = (OceUA_Item_Dictionary or OceUA_Items_Dictionary) and true or false
  local hasExtra = (OceUA_tooltip_extras or OceUA_pet_teach or OceUA_holiday or OceUA_profession_ranks) and true or false
  return {
    version = VERSION,
    enabled = SkillEnabled() and true or false,
    dictCount = dictCount or 0,
    exactCount = exactCount or 0,
    softNormCount = softNormCount or 0,
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

  -- 1) Items: найважливіша швидка гілка. Підтримуємо обидві назви таблиці.
  local itemDict = OceUA_Item_Dictionary or OceUA_Items_Dictionary
  if itemDict then
    local ua = itemDict[clean] or itemDict[ek]
    if ua and ua ~= "" and ua ~= clean then return ua end
    if itemDictLowerUA then
      ua = itemDictLowerUA[string.lower(clean)] or itemDictLowerUA[string.lower(ek)]
      if ua and ua ~= "" then return ua end
    end
  end

  local function hit(dict)
    if not dict then return nil end
    local ua = dict[clean] or dict[ek]
    if ua and ua ~= "" and ua ~= clean then return ua end
    local lk = string.lower(clean)
    for k, v in pairs(dict) do
      if type(k) == "string" and type(v) == "string" and string.lower(k) == lk and v ~= "" and v ~= clean then
        return v
      end
    end
    return nil
  end

  local ua
  ua = hit(OceUA_NPC_Names_Dictionary); if ua then return ua end
  ua = hit(OceUA_Mobs_Dictionary); if ua then return ua end
  ua = hit(OceUA_Objects_Dictionary); if ua then return ua end
  ua = hit(OceUA_Signs_Dictionary); if ua then return ua end

  -- Професії використовуються окремо в тренері, TradeSkill і Character UI.
  if professionDictLowerUA then
    ua = professionDictLowerUA[string.lower(clean)] or professionDictLowerUA[string.lower(ek)]
    if ua and ua ~= "" then return ua end
  end
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
  -- залишки $lword:words; / $g (якщо токенів не вистачило)
  s = string.gsub(s, "%$[lL]([^:]+):([^;]+);", "%1")
  s = string.gsub(s, "%$[gG]([^:]+):([^;]+);", "%1")
  -- EN одиниці → UA: ЛИШЕ з пробілом перед одиницею (слово sec/min/…)
  s = string.gsub(s, "(%d+%.?%d*)%s+[Ss][Ee][Cc][Oo][Nn][Dd][Ss]%.?", "%1 сек")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Ss][Ee][Cc][Ss]%.?", "%1 сек")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Ss][Ee][Cc]%.?", "%1 сек")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Mm][Ii][Nn][Uu][Tt][Ee][Ss]%.?", "%1 хв")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Mm][Ii][Nn][Ss]%.?", "%1 хв")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Mm][Ii][Nn]%.?", "%1 хв")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Hh][Oo][Uu][Rr][Ss]%.?", "%1 год")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Hh][Oo][Uu][Rr]%.?", "%1 год")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Yy][Aa][Rr][Dd][Ss]%.?", "%1 м")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Yy][Dd][Ss]%.?", "%1 м")
  s = string.gsub(s, "(%d+%.?%d*)%s+[Yy][Dd]%.?", "%1 м")
  -- діапазон шкоди ніколи не «сек»
  s = string.gsub(s, "(%d+%s*%-%s*%d+%.?%d*)%s+сек", "%1")
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
  -- виправлення старих UA-назв випробувань (навіть якщо вже кирилиця)
  if CHALLENGE_UA_FIX and CHALLENGE_UA_FIX[clean] then
    return CHALLENGE_UA_FIX[clean], true
  end
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

  -- прямий ключ у Skill_Dictionary (без soft) — довгі описи 1:1
  if OceSkillUA_Dictionary and OceSkillUA_Dictionary[clean] then
    local dua = OceSkillUA_Dictionary[clean]
    if dua and dua ~= "" and dua ~= clean then
      local result = FinalizeUA(dua, clean)
      if cacheCount < CACHE_MAX then
        translateCache[clean] = { result, true }
        cacheCount = cacheCount + 1
      end
      return result, true
    end
  end
  if OceUA_Skill_Dictionary and OceUA_Skill_Dictionary[clean] then
    local dua = OceUA_Skill_Dictionary[clean]
    if dua and dua ~= "" and dua ~= clean then
      local result = FinalizeUA(dua, clean)
      if cacheCount < CACHE_MAX then
        translateCache[clean] = { result, true }
        cacheCount = cacheCount + 1
      end
      return result, true
    end
  end

  -- пріоритет: challenges.lua (назви випробувань)
  if OceUA_challenges and OceUA_challenges[clean] then
    local cua = OceUA_challenges[clean]
    if cua and cua ~= "" then
      if cacheCount < CACHE_MAX then
        translateCache[clean] = { cua, true }
        cacheCount = cacheCount + 1
      end
      return cua, true
    end
  end

  -- soft-exact: числа ЗБЕРІГАЮТЬСЯ → "Increased Hit Chance 5" ≠ "... 3"
  -- це рятує ранги, які після повної Normalize злипаються в один ключ
  if exactCount > 0 then
    local ek = SoftExactKey(clean)
    local exactHit = exactUA[ek]
    if not exactHit then
      -- варіанти крапки / пробілів
      exactHit = exactUA[ek .. "."] or exactUA[string.gsub(ek, "%.$", "")]
    end
    if not exactHit then
      exactHit = LookupCategoryExact(ek, clean)
    end
    if not exactHit then
      -- оригінальний clean без lower (деякі ключі в словнику з іншим регістром уже в SoftExactKey)
      local ek2 = SoftExactKey(string.gsub(clean, "%s+$", ""))
      exactHit = exactUA[ek2]
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

  -- soft-norm: описи з підставленими числами (тренер / тултіп)
  if softNormCount and softNormCount > 0 then
    local sn = SoftNormKey(clean)
    local snUA = softNormUA[sn]
    if snUA then
      local _, tokens = NormalizeForMatch(clean)
      local result = ApplyTokens(snUA, tokens)
      result = CleanupUA(result)
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
  -- короткий рядок: substring-скан по всьому словнику дуже дорогий (FPS)
  local i
  if normLen >= 16 then
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
  end -- normLen >= 16
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
  if clean == "" then return text, false end
  if HasCyrillic(clean) then
    if string.find(clean, "^[%d%.%s%-]+%s*сек%s*$") then
      local fixed = string.gsub(clean, "%s*сек%s*$", "")
      return string.gsub(fixed, "%s+$", ""), true
    end
    return text, false
  end
  if string.find(clean, "^[%d%s%-%./+:]+$") then return text, false end

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
  -- optional "Use: " prefix (клієнт часто дає з префіксом)
  local hs = string.gsub(clean, "^Use:%s*", "")
  local _, _, loc = string.find(hs, "^Returns you to (.+)%. Speak to an Innkeeper in a different place to change your home location%.?$")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Використання: Повертає вас до " .. TranslateZoneName(loc) .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення.", true
  end
  _, _, loc = string.find(hs, "^Returns you to (.+)%.%s*Speak to an Innkeeper")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Використання: Повертає вас до " .. TranslateZoneName(loc) .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення.", true
  end
  _, _, loc = string.find(hs, "^Returns you to your home%.%s*Your home is currently (.+)%.?$")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Використання: Повертає вас додому. Наразі ваш дім: " .. TranslateZoneName(loc) .. ".", true
  end
  _, _, loc = string.find(hs, "^Yanks the caster through the twisting nether back to (.+)%.%s*Speak to an Innkeeper")
  if loc and loc ~= "" and loc ~= "$z" then
    return "Використання: Переносить вас через Вируючу Порожнечу назад до " .. TranslateZoneName(loc) .. ". Поговоріть з господарем таверни в іншому місці, щоб змінити точку повернення.", true
  end

  -- +N Stat  /  +N% Something
  local _, _, sign, num, rest = string.find(clean, "^([%+%-])(%d+%.?%d*)%s+(.+)$")
  if sign and num and rest then
    rest = string.gsub(rest, "[%.%:%,%;]+$", "")
    rest = string.gsub(rest, "%s+$", "")
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
  local _, _, d1, d2 = string.find(clean, "^Durability:?%s*(%d+)%s*/%s*(%d+)$")
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
  if arm then return arm .. " Броня", true end
  local _, _, arm2 = string.find(clean, "^Armor: (%d+)$")
  if arm2 then return "Броня: " .. arm2, true end

  -- Durability X / Y
  local _, _, d1, d2 = string.find(clean, "^Durability:?%s*(%d+)%s*/%s*(%d+)$")
  if d1 then return "Міцність " .. d1 .. " / " .. d2, true end
  local _, _, d3, d4 = string.find(clean, "^Durability:?%s*(%d+)%s*/%s*(%d+)$")
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

  -- Equip:/Use:/Chance on hit: prefix + rest
  local _, _, prefix, body = string.find(clean, "^(Equip:|Use:|Chance on hit:|Chance on Hit:)%s*(.*)$")
  if prefix then
    local pUa = ITEM_FIXED_UA[prefix] or prefix
    if body and body ~= "" then
      body = string.gsub(body, "%s+$", "")
      body = string.gsub(body, "[%.]+$", "")
      -- +N Stat (Equip: +6 Attack Power)
      local _, _, sign, num, rest = string.find(body, "^([%+%-])(%d+%.?%d*)%s+(.+)$")
      if sign and num and rest then
        rest = string.gsub(rest, "[%.%:%,%;]+$", "")
        rest = string.gsub(rest, "%s+$", "")
        local statUa = ITEM_STAT_UA[rest]
        if statUa then
          if string.find(statUa, "^до ") then
            return pUa .. " " .. sign .. num .. " " .. statUa, true
          end
          return pUa .. " " .. sign .. num .. " " .. statUa, true
        end
      end
      local bodyUa, ok = TranslateText(body)
      if ok then return pUa .. " " .. bodyUa, true end
      return pUa .. " " .. body, true
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
          if i == 1 and SkillShowOriginal() then
            local eng = StripCodes(t)
            if eng and eng ~= "" and string.len(eng) <= 80 and eng ~= StripCodes(newT) then
              if not string.find(newT, eng, 1, true) then
                newT = newT .. "\n|cff999999" .. eng .. "|r"
              end
            end
          end
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


-- Чи тултіп ще англійською (перший рядок без кирилиці)?
local function TooltipNeedsUA(tooltip)
  if not tooltip or not tooltip.GetName then return false end
  if tooltip.oceua_light then return false end
  local fs = getglobal(tooltip:GetName() .. "TextLeft1")
  if not fs or not fs.GetText then return false end
  local tx = fs:GetText()
  if not tx or tx == "" then return false end
  if HasCyrillic(tx) then return false end
  -- pfQuest / квестові маркери — OceTip, не SkillUA (уникнути подвійної роботи)
  if string.find(tx, "%[!%]") or string.find(tx, "%[%?%]") then return false end
  return true
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
  -- Назва (рядок 1) може вже бути UA, а описи нижче — ще EN.
  -- Тому НЕ виходимо лише через HasCyrillic на 1-му рядку:
  -- проходимо всі рядки; HasCyrillic на кожному рядку сам пропустить готове.
  if not TooltipNeedsUA(tooltip) then
    -- перевірити, чи лишились EN-рядки
    local hasEN = false
    local tn = tooltip:GetName() or ""
    local li
    for li = 1, (tooltip.NumLines and tooltip:NumLines()) or 20 do
      local fs = getglobal(tn .. "TextLeft" .. li)
      if fs and fs.GetText then
        local tx = fs:GetText() or ""
        if tx ~= "" and not HasCyrillic(tx) and string.find(tx, "[A-Za-z]") then
          hasEN = true
          break
        end
      end
    end
    if not hasEN then
      tooltip.oceDone = true
      return
    end
    -- є EN-описи → не ставимо oceDone, обробляємо нижче
  end
  -- юніт-тултіп (NPC/моб): Level N у рядку 2/3 — хай UnitUA, не SkillUA
  if not tooltip.oceItemTip and not tooltip.oceNoDual then
    local tn = tooltip:GetName()
    local l2 = getglobal(tn .. "TextLeft2")
    local l3 = getglobal(tn .. "TextLeft3")
    local function isLevelLine(fs)
      if not fs or not fs.GetText then return false end
      local x = fs:GetText() or ""
      if string.sub(x, 1, 6) == "Level " then return true end
      if string.sub(x, 1, 7) == "Рівень " then return true end
      return false
    end
    if isLevelLine(l2) or isLevelLine(l3) then
      tooltip.oceDone = true
      return
    end
  end
  local now = GetTime and GetTime() or 0
  local gap = tooltip.oceItemTip and 0.03 or 0.12
  if tooltip.oceLastProc and (now - tooltip.oceLastProc) < gap then
    return
  end
  tooltip.oceLastProc = now
  -- oceDone ставимо ПІСЛЯ проходу рядків (описи інколи довантажуються)

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
          -- перший рядок = назва: UA зверху, сірий EN знизу (скіли, предмети, шмот, усе)
          -- oceNoDual лишається для бафів (там dual не потрібен)
          if i == 1 and SkillShowOriginal() and not tooltip.oceNoDual then
            local eng = StripCodes(t)
            local maxLen = tooltip.oceItemTip and 80 or 60
            if eng and eng ~= "" and string.len(eng) <= maxLen and eng ~= StripCodes(newT) then
              if not string.find(newT, eng, 1, true) then
                newT = newT .. "\n|cff999999" .. eng .. "|r"
              end
            end
          end
          left:SetText(newT)
        end
      end
    end
    if right then
      local t = right:GetText()
      if t and t ~= "" then
        local plain = StripCodes(t)
        -- значення колонок: числа / діапазони — не перекладати; зняти помилкове «сек»
        if string.find(plain, "^[%d%.%s%-]+%s*сек%s*$") then
          local fixed = string.gsub(plain, "%s*сек%s*$", "")
          fixed = string.gsub(fixed, "%s+$", "")
          right:SetText(fixed)
          hasAnyTranslation = true
        elseif HasCyrillic(plain) then
          -- ok
        elseif string.find(plain, "^[%d%s%-%./+:]+$") then
          -- голе число — лишити
        else
          local newT, ok = TranslateItemLine(t)
          if not ok then newT, ok = TranslateText(t) end
          if ok and newT and newT ~= t then
            hasAnyTranslation = true
            right:SetText(newT)
          end
        end
      end
    end
  end

  -- якщо ще є EN-рядки — дозволити ще один прохід OnUpdate
  do
    local stillEN = false
    local tn = tooltip:GetName() or ""
    local li
    for li = 1, num do
      local fs = getglobal(tn .. "TextLeft" .. li)
      if fs and fs.GetText then
        local tx = fs:GetText() or ""
        if tx ~= "" and not HasCyrillic(tx) and string.find(tx, "[A-Za-z]") then
          -- пропустити голі числа / DPS
          if not string.find(tx, "^[%d%s%-%./+:]+$") then
            stillEN = true
            break
          end
        end
      end
    end
    if not stillEN then
      tooltip.oceDone = true
    else
      tooltip.oceDone = nil  -- ще раз
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
local function TranslateRequiresLevelText(text)
  if not text or text == "" then return text, false end
  if HasCyrillic and HasCyrillic(text) then
    -- частковий: "Потрібно: Level 16"
    local n = text
    n = string.gsub(n, "Level%s*(%d+)", "рівень %1")
    n = string.gsub(n, "Requires%s+", "Потрібно: ")
    if n ~= text then return n, true end
    return text, false
  end
  local n = text
  n = string.gsub(n, "^Requires Level%s*(%d+)", "Потрібно: рівень %1")
  n = string.gsub(n, "^Requires%s+", "Потрібно: ")
  n = string.gsub(n, "Level%s*(%d+)", "рівень %1")
  if n ~= text then return n, true end
  return text, false
end

local function FixRankText(s)
  if not s or s == "" then return s end
  if not string.find(s, "[Rr][Aa][Nn][Kk]") then return s end
  local n = s
  n = string.gsub(n, "|c%x%x%x%x%x%x%x%x[Rr]ank|r%s*(%d+)", "Ранг %1")
  n = string.gsub(n, "|c%x%x%x%x%x%x%x%x[Rr]ANK|r%s*(%d+)", "Ранг %1")
  n = string.gsub(n, "%([Rr][Aa][Nn][Kk]%s*(%d+)%)", "(Ранг %1)")
  n = string.gsub(n, "([%s%|%(%[%{])[Rr][Aa][Nn][Kk]%s*(%d+)", "%1Ранг %2")
  n = string.gsub(n, "^[Rr][Aa][Nn][Kk]%s*(%d+)", "Ранг %1")
  n = string.gsub(n, "([%s])[Rr][Aa][Nn][Kk]%s*(%d+)", "%1Ранг %2")
  n = string.gsub(n, "%s+[Rr][Aa][Nn][Kk]%s+(%d+)", " (Ранг %1)")
  n = string.gsub(n, "[Rr][Aa][Nn][Kk]%s*:%s*(%d+)", "Ранг: %1")
  n = string.gsub(n, "[Rr][Aa][Nn][Kk]:", "Ранг:")
  n = string.gsub(n, "%([Rr][Aa][Nn][Kk]%)", "(Ранг)")
  return n
end

local function FixRankInFrame(frame, depth)
  if not frame or (depth and depth > 6) then return end
  depth = depth or 0
  if frame.GetRegions then
    local regs = { frame:GetRegions() }
    local i
    for i = 1, table.getn(regs) do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "FontString" and r.GetText and r.SetText then
        local tx = r:GetText()
        if tx and string.find(tx, "[Rr][Aa][Nn][Kk]") then
          local nx = FixRankText(tx)
          if nx ~= tx then r:SetText(nx) end
        end
      end
    end
  end
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      FixRankInFrame(kids[i], depth + 1)
    end
  end
end

local function TranslateTrainerLine(text)
  if not text or text == "" then return text end
  local t0 = text
  -- уже повністю UA без Rank
  if HasCyrillic(text) and not string.find(text, "[Rr]ank") then
    return text
  end
  local base = string.gsub(text, "%s*%(.*%)%s*$", "")
  base = string.gsub(base, "%s+[Rr]ank%s+%d+%s*$", "")
  base = string.gsub(base, "%s+$", "")
  local ua = nil
  if OceUA_Skill_Dictionary and OceUA_Skill_Dictionary[base] then
    ua = OceUA_Skill_Dictionary[base]
  end
  if not ua then
    local nt, ok = TranslateText(base)
    if ok then ua = nt end
  end
  local _, _, rankNum = string.find(text, "[Rr]ank%s*(%d+)")
  if ua then
    if rankNum then
      return ua .. " (Ранг " .. rankNum .. ")"
    end
    return ua
  end
  -- хоча б Rank
  return FixRankText(text)
end

local function ProcessTrainerList()
  if not ClassTrainerFrame or not ClassTrainerFrame:IsVisible() then return end
  local max = 11
  if CLASS_TRAINER_SKILLS_DISPLAYED then max = CLASS_TRAINER_SKILLS_DISPLAYED end
  local i
  for i = 1, max do
    local btn = getglobal("ClassTrainerSkill" .. i)
    if btn and btn.IsVisible and btn:IsVisible() then
      local fs = getglobal("ClassTrainerSkill" .. i .. "Text")
      if fs and fs.GetText then
        local tx = fs:GetText()
        if tx and tx ~= "" then
          local neu = TranslateTrainerLine(tx)
          if neu and neu ~= tx then fs:SetText(neu) end
        end
      elseif btn.GetText and btn.SetText then
        local tx = btn:GetText()
        if tx and tx ~= "" then
          local neu = TranslateTrainerLine(tx)
          if neu and neu ~= tx then btn:SetText(neu) end
        end
      end
    end
  end
  -- заголовки гілок
  for i = 1, max do
    local btn = getglobal("ClassTrainerSkill" .. i)
    if btn and btn.GetText then
      local tx = btn:GetText()
      if tx and OceUA_Skill_Dictionary and OceUA_Skill_Dictionary[tx] then
        btn:SetText(OceUA_Skill_Dictionary[tx])
      end
    end
  end
  if ClassTrainerFrame then FixRankInFrame(ClassTrainerFrame, 0) end
end

local function ProcessTrainerDetails()
  if not SkillEnabled() then return end
  if not ClassTrainerFrame or not ClassTrainerFrame:IsVisible() then return end

  ProcessTrainerList()

  if ClassTrainerSkillName then
    local sn = ClassTrainerSkillName:GetText()
    if sn and sn ~= "" then
      local neu = TranslateTrainerLine(sn)
      if neu and neu ~= sn then ClassTrainerSkillName:SetText(neu) end
      neu = FixRankText(ClassTrainerSkillName:GetText() or "")
      if neu ~= (ClassTrainerSkillName:GetText() or "") then
        ClassTrainerSkillName:SetText(neu)
      end
    end
  end
  if ClassTrainerSkillRequirements then
    local rt = ClassTrainerSkillRequirements:GetText()
    if rt then
      local n, ok = TranslateRequiresLevelText(rt)
      if ok then ClassTrainerSkillRequirements:SetText(n)
      else TranslateFontString(ClassTrainerSkillRequirements) end
    end
  end
  TranslateFontString(ClassTrainerSkillDescription)
  local descFS = ClassTrainerSkillDescription
  if not descFS then descFS = getglobal("ClassTrainerDetailScrollChildFrame") end
  if descFS and descFS.GetRegions then
    local regs = { descFS:GetRegions() }
    local ri
    for ri = 1, table.getn(regs) do
      local r = regs[ri]
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
        TranslateFontString(r)
      end
    end
  end
  if ClassTrainerCostLabel then
    TranslateFontString(ClassTrainerCostLabel)
    local ct = ClassTrainerCostLabel:GetText()
    if ct and (ct == "Cost:" or ct == "Cost") then
      ClassTrainerCostLabel:SetText("Вартість:")
    end
  end
  if ClassTrainerFrame then FixRankInFrame(ClassTrainerFrame, 0) end
end

-- Перехоплення SetText: клієнт пише EN → одразу UA (без кадру миготіння)
local trainerButtonsHooked = false

local function HookOneFontString(fs)
  if not fs or not fs.SetText or fs.oceOceHooked then return end
  fs.oceOceHooked = true
  local oldSet = fs.SetText
  fs.SetText = function(self, text)
    if SkillEnabled() and text and text ~= "" then
      if string.find(text, "[A-Za-z]") or string.find(text, "[Rr][Aa][Nn][Kk]") then
        text = TranslateTrainerLine(text)
        text = FixRankText(text)
      end
    end
    oldSet(self, text)
  end
  if fs.SetFormattedText then
    local oldFmt = fs.SetFormattedText
    fs.SetFormattedText = function(self, fmt, a1, a2, a3, a4, a5, a6)
      if SkillEnabled() and type(fmt) == "string" and string.find(fmt, "[Rr][Aa][Nn][Kk]") then
        fmt = string.gsub(fmt, "[Rr][Aa][Nn][Kk]", "Ранг")
      end
      return oldFmt(self, fmt, a1, a2, a3, a4, a5, a6)
    end
  end
end

local function HookFontStringsDeep(frame, depth)
  if not frame or depth > 8 then return end
  if frame.GetRegions then
    local regs = { frame:GetRegions() }
    local i
    for i = 1, table.getn(regs) do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
        HookOneFontString(r)
      end
    end
  end
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      HookFontStringsDeep(kids[i], depth + 1)
    end
  end
end

local function HookTrainerSkillButtons()
  if not ClassTrainerFrame then return end
  HookFontStringsDeep(ClassTrainerFrame, 0)
  local max = 11
  if CLASS_TRAINER_SKILLS_DISPLAYED then max = CLASS_TRAINER_SKILLS_DISPLAYED end
  local i
  for i = 1, max do
    local fs = getglobal("ClassTrainerSkill" .. i .. "Text")
    if fs then HookOneFontString(fs) end
    local btn = getglobal("ClassTrainerSkill" .. i)
    if btn then
      HookFontStringsDeep(btn, 0)
      if btn.SetText and not btn.oceOceHookedBtn then
        btn.oceOceHookedBtn = true
        local oldSet = btn.SetText
        btn.SetText = function(self, text)
          if SkillEnabled() and text and text ~= "" then
            text = TranslateTrainerLine(text)
            text = FixRankText(text)
          end
          oldSet(self, text)
        end
      end
    end
  end
  if ClassTrainerSkillName then HookOneFontString(ClassTrainerSkillName) end
  if ClassTrainerSkillDescription then HookOneFontString(ClassTrainerSkillDescription) end
  if type(RANK) == "string" and (RANK == "Rank" or RANK == "RANK") then RANK = "Ранг" end
  if type(RANK_COLON) == "string" and string.find(tostring(RANK_COLON), "[Rr]ank") then
    RANK_COLON = "Ранг:"
  end
  if type(TOOLTIP_TALENT_RANK) == "string" and string.find(TOOLTIP_TALENT_RANK, "[Rr]ank") then
    TOOLTIP_TALENT_RANK = string.gsub(TOOLTIP_TALENT_RANK, "[Rr]ank", "Ранг")
  end
  trainerButtonsHooked = true
end

local trainerWatch = CreateFrame("Frame")
trainerWatch.acc = 0
trainerWatch:Hide()
trainerWatch:SetScript("OnUpdate", function()
  if not SkillEnabled() or not ClassTrainerFrame or not ClassTrainerFrame:IsVisible() then
    this:Hide()
    return
  end
  this.hookAcc = (this.hookAcc or 0) + arg1
  if this.hookAcc >= 1.0 then
    this.hookAcc = 0
    HookTrainerSkillButtons()
  end
  -- без періодичного ProcessTrainerList/FixRankInFrame — хуки SetText гасять Rank без миготіння
end)

local function ScheduleTrainerTranslate()
  HookTrainerSkillButtons()
  trainerWatch.acc = 0
  trainerWatch:Show()
  ProcessTrainerDetails()
end


-- ============================================================
-- Spellbook (книга заклинань гравця)
-- ============================================================
local function LookupSpellBookName(base)
  if not base or base == "" then return nil end
  local function hit(d)
    if d and d[base] and d[base] ~= "" and d[base] ~= base then return d[base] end
    return nil
  end
  local ua = hit(OceUA_Skill_Dictionary)
  if ua then return ua end
  ua = hit(OceSkillUA_Dictionary)
  if ua then return ua end
  ua = hit(OceUA_challenges)
  if ua then return ua end
  ua = hit(OceUA_Talent_Names)
  if ua then return ua end
  ua = hit(OceUA_Class_Names)
  if ua then return ua end
  -- soft from main TranslateText pipeline
  if TranslateText then
    local t2, ok = TranslateText(base)
    if ok and t2 and t2 ~= base then return t2 end
  end
  return nil
end

local function TranslateSpellBookButton(i)
  local btn = getglobal("SpellButton" .. i)
  if not btn or not btn:IsVisible() then return end
  local candidates = {
    getglobal("SpellButton" .. i .. "SpellName"),
    getglobal("SpellButton" .. i .. "Title"),
    getglobal("SpellButton" .. i .. "Name"),
  }
  local ci
  for ci = 1, table.getn(candidates) do
    local fs = candidates[ci]
    if fs and fs.GetText then
      local tx = fs:GetText()
      if tx and tx ~= "" and not HasCyrillic(tx) then
        local base = string.gsub(tx, "%s*%(.*%)%s*$", "")
        base = string.gsub(base, "%s+$", "")
        local ua = LookupSpellBookName(base)
        if ua then
          local _, _, rank = string.find(tx, "(%(.*%))%s*$")
          if rank then
            rank = string.gsub(rank, "[Rr]ank%s*", "Ранг ")
            fs:SetText(ua .. " " .. rank)
          else
            fs:SetText(ua)
          end
        else
          TranslateFontString(fs)
        end
      end
    end
  end
  local sub = getglobal("SpellButton" .. i .. "SubText")
  if sub then
    local st = sub:GetText()
    if st and st ~= "" and not HasCyrillic(st) then
      local nst = string.gsub(st, "^[Rr]ank%s*(%d+)", "Ранг %1")
      nst = string.gsub(nst, "^Passive", "Пасивно")
      if nst ~= st then
        sub:SetText(nst)
      else
        local ua = LookupSpellBookName(st)
        if ua then sub:SetText(ua) else TranslateFontString(sub) end
      end
    end
  end
  if btn.GetRegions then
    local regs = { btn:GetRegions() }
    local ri
    for ri = 1, table.getn(regs) do
      local r = regs[ri]
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
        local tx = r:GetText()
        if tx and tx ~= "" and not HasCyrillic(tx) then
          if not string.find(tx, "^%d+$") then
            local base = string.gsub(tx, "%s*%(.*%)%s*$", "")
            base = string.gsub(base, "%s+$", "")
            local ua = LookupSpellBookName(base)
            if ua then
              local _, _, rank = string.find(tx, "(%(.*%))%s*$")
              if rank then
                rank = string.gsub(rank, "[Rr]ank%s*", "Ранг ")
                r:SetText(ua .. " " .. rank)
              else
                r:SetText(ua)
              end
            else
              TranslateFontString(r)
            end
          end
        end
      end
    end
  end
end

local function ProcessSpellBook()
  if not SkillEnabled() then return end
  if not SpellBookFrame or not SpellBookFrame:IsVisible() then return end
  local max = 12
  if SPELLS_PER_PAGE then max = SPELLS_PER_PAGE end
  local i
  for i = 1, max do
    TranslateSpellBookButton(i)
  end
  -- вкладки ліній скілів (General, etc. — імена з GetSpellTabInfo)
  local ti
  for ti = 1, 8 do
    local tab = getglobal("SpellBookSkillLineTab" .. ti)
    -- іконки без тексту; заголовок книги:
  end
  if SpellBookFrameTitleText then
    TranslateFontString(SpellBookFrameTitleText)
  end
  -- підпис сторінки / skill line
  if SpellBookFrameTabButton1 then
    local tb
    for tb = 1, 3 do
      local b = getglobal("SpellBookFrameTabButton" .. tb)
      if b and b.GetText and b:GetText() then
        local tx = b:GetText()
        if tx == "Spellbook" then b:SetText("Заклинання")
        elseif tx == "Pet" then b:SetText("Улюбленець")
        elseif tx and not HasCyrillic(tx) then
          local ua = OceUA_Skill_Dictionary and OceUA_Skill_Dictionary[tx]
          if ua then b:SetText(ua) end
        end
      end
    end
  end
end

local spellBookWatch = CreateFrame("Frame")
spellBookWatch.acc = 0
spellBookWatch:Hide()
spellBookWatch:SetScript("OnUpdate", function()
  if not SkillEnabled() or not SpellBookFrame or not SpellBookFrame:IsVisible() then
    this:Hide()
    return
  end
  this.acc = this.acc + arg1
  if this.acc < 0.08 then return end
  this.acc = 0
  ProcessSpellBook()
end)

local function ScheduleSpellBookTranslate()
  spellBookWatch.acc = 0
  spellBookWatch:Show()
  ProcessSpellBook()
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

local PROF_UI_UA = {
  ["Reagents:"] = "Реагенти:",
  ["Reagents"] = "Реагенти",
  ["Requires:"] = "Потрібно:",
  ["Requires"] = "Потрібно",
  ["Create"] = "Створити",
  ["Create All"] = "Створити всі",
  ["Exit"] = "Вийти",
  ["Cancel"] = "Скасувати",
  ["Close"] = "Закрити",
  ["Have materials"] = "Є матеріали",
  ["Have Materials"] = "Є матеріали",
  ["Improves skill"] = "Підвищує навик",
  ["Improves Skill"] = "Підвищує навик",
  ["All"] = "Усі",
  ["All Subclasses"] = "Усі підкласи",
  ["All subclasses"] = "Усі підкласи",
  ["All Slots"] = "Усі слоти",
  ["All slots"] = "Усі слоти",
  ["Search"] = "Пошук",
  ["Available"] = "Доступні",
  ["Unavailable"] = "Недоступні",
  ["Previous"] = "Назад",
  ["Next"] = "Далі",
  -- категорії / типи
  ["Consumable"] = "Витратне",
  ["Consumables"] = "Витратне",
  ["Cloth"] = "Тканина",
  ["Leather"] = "Шкіра",
  ["Mail"] = "Кольчуга",
  ["Plate"] = "Лати",
  ["Trade Goods"] = "Господарські товари",
  ["Miscellaneous"] = "Різне",
  ["Weapon"] = "Зброя",
  ["Weapons"] = "Зброя",
  ["Armor"] = "Броня",
  ["Bag"] = "Сумка",
  ["Bags"] = "Сумки",
  ["Device"] = "Пристрій",
  ["Devices"] = "Пристрої",
  ["Explosive"] = "Вибухівка",
  ["Explosives"] = "Вибухівка",
  ["Part"] = "Деталь",
  ["Parts"] = "Деталі",
  ["Elemental"] = "Стихія",
  ["Enchanting"] = "Накладання чар",
  ["Potion"] = "Зілля",
  ["Elixir"] = "Еліксир",
  ["Flask"] = "Настій",
  ["Bandage"] = "Бинт",
  ["Food"] = "Їжа",
  ["Drink"] = "Напій",
  ["Material"] = "Матеріал",
  ["Materials"] = "Матеріали",
  ["Other"] = "Інше",
  ["Quest"] = "Квест",
  ["Recipe"] = "Рецепт",
  ["Recipes"] = "Рецепти",
  ["Scope"] = "Приціл",
  ["Shield"] = "Щит",
  ["Staff"] = "Посох",
  ["Wand"] = "Жезл",
  ["Gun"] = "Рушниця",
  ["Bow"] = "Лук",
  ["Crossbow"] = "Арбалет",
  ["Thrown"] = "Метальна",
  ["Fist Weapon"] = "Кулачна зброя",
  ["Dagger"] = "Кинджал",
  ["Sword"] = "Меч",
  ["Axe"] = "Сокира",
  ["Mace"] = "Булава",
  ["Polearm"] = "Дібрівна",
  ["One-Hand"] = "Одноручне",
  ["Two-Hand"] = "Дворучне",
  ["Main Hand"] = "Права рука",
  ["Off Hand"] = "Ліва рука",
  ["Held In Off-hand"] = "В лівій руці",
  ["Head"] = "Голова",
  ["Neck"] = "Шия",
  ["Shoulder"] = "Плечі",
  ["Back"] = "Спина",
  ["Chest"] = "Груди",
  ["Wrist"] = "Зап'ястя",
  ["Hands"] = "Руки",
  ["Waist"] = "Пояс",
  ["Legs"] = "Ноги",
  ["Feet"] = "Ступні",
  ["Finger"] = "Палець",
  ["Trinket"] = "Аксесуар",
  ["Ranged"] = "Дальній бій",
  ["Projectile"] = "Снаряд",
  ["Quiver"] = "Колчан",
  ["Ammo Pouch"] = "Підсумок",
}

local function LookupProfItemName(en)
  if not en or en == "" then return nil end
  en = string.gsub(en, "|c%x%x%x%x%x%x%x%x", "")
  en = string.gsub(en, "|r", "")
  en = string.gsub(en, "^%s+", "")
  en = string.gsub(en, "%s+$", "")
  if en == "" or HasCyrillic(en) then return nil end

  -- UI fixed
  if PROF_UI_UA[en] then return PROF_UI_UA[en] end

  -- "Name [4]" / "Name (4)" / "Name x4"
  local base, suffix = en, ""
  local _, _, b1, s1 = string.find(en, "^(.-)%s*(%[%d+%])%s*$")
  if b1 then base, suffix = b1, " " .. s1 end
  if not b1 then
    local _, _, b2, s2 = string.find(en, "^(.-)%s*(%(%d+%))%s*$")
    if b2 then base, suffix = b2, " " .. s2 end
  end
  base = string.gsub(base, "%s+$", "")

  local dict = OceUA_Item_Dictionary
  local rec = OceUA_Recipes_Dictionary
  local ua = nil
  if dict then ua = dict[base] or dict[en] end
  if (not ua or ua == "") and rec then ua = rec[base] or rec[en] end
  if (not ua or ua == "") and LookupCategoryExact then
    ua = LookupCategoryExact(string.lower(base), base)
  end
  if ua and ua ~= "" and ua ~= base and ua ~= en then
    return ua .. suffix
  end

  -- "Profession N/M"  e.g. Leatherworking 1/75
  local _, _, pname, cur, maxv = string.find(en, "^([%a%s%'%-]+)%s+(%d+)%s*/%s*(%d+)$")
  if pname and cur and maxv then
    pname = string.gsub(pname, "%s+$", "")
    local pua = PROF_UI_UA[pname]
    if not pua and OceUA_Profession_Names then pua = OceUA_Profession_Names[pname] end
    if not pua and dict then pua = dict[pname] end
    if pua then return pua .. " " .. cur .. "/" .. maxv end
  end

  return nil
end

local function SetFSTextUA(fs)
  if not fs or not fs.GetText or not fs.SetText then return end
  if fs.IsVisible and not fs:IsVisible() then return end
  local tx = fs:GetText()
  if not tx or tx == "" then return end
  local plain = StripCodes(tx)
  if plain == "" or HasCyrillic(plain) then return end
  local ua = LookupProfItemName(plain)
  if not ua then
    -- TranslateFontString / dict fallback
    local newT, ok = TranslateItemLine(plain)
    if ok and newT then ua = newT end
  end
  if not ua then
    local newT, ok = TranslateText(plain)
    if ok and newT then ua = newT end
  end
  if ua and ua ~= plain then
    local _, _, pref = string.find(tx, "^(|c%x%x%x%x%x%x%x%x)")
    if pref then
      fs:SetText(pref .. ua .. "|r")
    else
      fs:SetText(ua)
    end
  end
end

local function WalkFrameFonts(frame, depth)
  if not frame or depth > 10 then return end
  if frame.GetRegions then
    local regs = { frame:GetRegions() }
    local i
    for i = 1, table.getn(regs) do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
        SetFSTextUA(r)
      end
    end
  end
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      WalkFrameFonts(kids[i], depth + 1)
    end
  end
end

local function ProcessTradeSkillList()
  if not TradeSkillFrame or not TradeSkillFrame:IsVisible() then return end
  local i
  for i = 1, 50 do
    SetFSTextUA(getglobal("TradeSkillSkill" .. i))
    SetFSTextUA(getglobal("TradeSkillSkill" .. i .. "Text"))
    local btn = getglobal("TradeSkillSkill" .. i)
    if btn and btn.GetRegions then
      local regs = { btn:GetRegions() }
      local ri
      for ri = 1, table.getn(regs) do
        local r = regs[ri]
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then
          SetFSTextUA(r)
        end
      end
    end
  end
  SetFSTextUA(TradeSkillFrameTitleText)
  SetFSTextUA(TradeSkillRankFrameSkillName)
  SetFSTextUA(TradeSkillRankFrameTitleText)
end

local function ProcessCraftList()
  if not CraftFrame or not CraftFrame:IsVisible() then return end
  local i
  for i = 1, 50 do
    SetFSTextUA(getglobal("Craft" .. i))
    SetFSTextUA(getglobal("Craft" .. i .. "Text"))
  end
end

-- Деталі + список + реагенти БЕЗ повного WalkFrameFonts (швидко, для кліку по рецепту)
local function ProcessTradeSkillDetailsCore()
  if not SkillEnabled() then return end

  if TradeSkillFrame and TradeSkillFrame:IsVisible() then
    ProcessTradeSkillList()
    SetFSTextUA(TradeSkillSkillName)
    SetFSTextUA(TradeSkillDescription)
    SetFSTextUA(TradeSkillRequirementLabel)
    SetFSTextUA(TradeSkillRequirementText)
    SetFSTextUA(TradeSkillSkillRequirement)
    SetFSTextUA(TradeSkillReagentLabel)
    SetFSTextUA(TradeSkillCreateButton)
    SetFSTextUA(TradeSkillCreateAllButton)
    SetFSTextUA(TradeSkillCancelButton)
    SetFSTextUA(TradeSkillExitButton)
    local ri
    for ri = 1, 8 do
      SetFSTextUA(getglobal("TradeSkillReagent" .. ri .. "Name"))
      SetFSTextUA(getglobal("TradeSkillReagent" .. ri .. "Count"))
    end
  end

  if CraftFrame and CraftFrame:IsVisible() then
    ProcessCraftList()
    SetFSTextUA(CraftName)
    SetFSTextUA(CraftDescription)
    SetFSTextUA(CraftRequirements)
    SetFSTextUA(CraftRequirementLabel)
    SetFSTextUA(CraftRequirementText)
    SetFSTextUA(CraftCreateButton)
    SetFSTextUA(CraftCancelButton)
    local ri
    for ri = 1, 8 do
      SetFSTextUA(getglobal("CraftReagent" .. ri .. "Name"))
      SetFSTextUA(getglobal("CraftReagent" .. ri .. "Count"))
    end
  end
end

-- лише лічильники реагентів (під час крафту)
local function ProcessTradeSkillDetailsLight()
  if not SkillEnabled() then return end
  if TradeSkillFrame and TradeSkillFrame:IsVisible() then
    local ri
    for ri = 1, 8 do
      SetFSTextUA(getglobal("TradeSkillReagent" .. ri .. "Name"))
      SetFSTextUA(getglobal("TradeSkillReagent" .. ri .. "Count"))
    end
  end
  if CraftFrame and CraftFrame:IsVisible() then
    local ri
    for ri = 1, 8 do
      SetFSTextUA(getglobal("CraftReagent" .. ri .. "Name"))
      SetFSTextUA(getglobal("CraftReagent" .. ri .. "Count"))
    end
  end
end

-- mode: "core" | "light" | "full"
local tsPend, tsMode = false, "core"
local tsTh = CreateFrame("Frame")
tsTh:Hide()
tsTh:SetScript("OnUpdate", function()
  this.t = (this.t or 0) + (arg1 or 0)
  local need = 0.05
  if tsMode == "light" then need = 0.12 end
  if this.t < need then return end
  this.t = 0
  this:Hide()
  if not tsPend then return end
  tsPend = false
  local mode = tsMode
  tsMode = "core"
  if mode == "full" then
    pcall(ProcessTradeSkillDetails)
  elseif mode == "light" then
    pcall(ProcessTradeSkillDetailsLight)
  else
    pcall(ProcessTradeSkillDetailsCore)
  end
end)

local function ScheduleTradeSkillTranslate(mode)
  if not SkillEnabled() then return end
  mode = mode or "core"
  -- пріоритет: full > core > light
  if tsPend then
    if tsMode == "full" then
      -- лишаємо full
    elseif mode == "full" then
      tsMode = "full"
    elseif tsMode == "light" and mode == "core" then
      tsMode = "core"
    end
  else
    tsMode = mode
  end
  tsPend = true
  tsTh.t = 0
  tsTh:Show()
end

local function ProcessTradeSkillDetails()
  if not SkillEnabled() then return end

  if TradeSkillFrame and TradeSkillFrame:IsVisible() then
    WalkFrameFonts(TradeSkillFrame, 0)
    ProcessTradeSkillDetailsCore()
    if TradeSkillRankFrame and TradeSkillRankFrame.GetRegions then
      WalkFrameFonts(TradeSkillRankFrame, 0)
    end
  end

  if CraftFrame and CraftFrame:IsVisible() then
    WalkFrameFonts(CraftFrame, 0)
    ProcessTradeSkillDetailsCore()
  end
end


-- ============================================================
-- Character Info (вкладки Character / Reputation / Skills / PvP)
-- ============================================================
local CHAR_UI_UA = {
  -- вкладки
  ["Character"] = "Персонаж",
  ["Reputation"] = "Репутація",
  ["Skills"] = "Навички",
  ["PvP"] = "PvP",
  -- Character
  ["Strength:"] = "Сила:",
  ["Strength"] = "Сила",
  ["Agility:"] = "Спритність:",
  ["Agility"] = "Спритність",
  ["Stamina:"] = "Витривалість:",
  ["Stamina"] = "Витривалість",
  ["Intellect:"] = "Інтелект:",
  ["Intellect"] = "Інтелект",
  ["Spirit:"] = "Дух:",
  ["Spirit"] = "Дух",
  ["Armor:"] = "Броня:",
  ["Melee Attack"] = "Ближній бій",
  ["Ranged Attack"] = "Дальній бій",
  ["Power:"] = "Потужність:",
  ["Power"] = "Потужність",
  ["Damage:"] = "Шкода:",
  ["Damage"] = "Шкода",
  ["Attack Power"] = "Сила атаки",
  ["Attack Power:"] = "Сила атаки:",
  ["Defense:"] = "Захист:",
  ["Defense"] = "Захист",
  ["Resists"] = "Опір",
  ["Resistance"] = "Опір",
  ["Health"] = "Здоров'я",
  ["Mana"] = "Мана",
  ["Rage"] = "Лють",
  ["Energy"] = "Енергія",
  ["Focus"] = "Концентрація",
  -- Reputation
  ["Faction"] = "Фракція",
  ["Standing"] = "Статус",
  ["Alliance"] = "Альянс",
  ["Horde"] = "Орда",
  ["Hated"] = "Ненависть",
  ["Hostile"] = "Ворожість",
  ["Unfriendly"] = "Неприязнь",
  ["Neutral"] = "Байдужість",
  ["Friendly"] = "Дружба",
  ["Honored"] = "Повага",
  ["Revered"] = "Шанування",
  ["Exalted"] = "Піднесення",
  -- Skills headers
  ["Class Skills"] = "Класові навички",
  ["Professions"] = "Професії",
  ["Secondary Skills"] = "Додаткові навички",
  ["Weapon Skills"] = "Навички зброї",
  ["Armor Skills"] = "Навички броні",
  ["Languages"] = "Мови",
  -- Weapon / skill names
  ["Axes"] = "Сокири",
  ["Swords"] = "Мечі",
  ["Maces"] = "Булави",
  ["Daggers"] = "Кинджали",
  ["Bows"] = "Луки",
  ["Crossbows"] = "Арбалети",
  ["Guns"] = "Рушниці",
  ["Staves"] = "Посохи",
  ["Polearms"] = "Дібрівна",
  ["Fist Weapons"] = "Кулачна зброя",
  ["Wands"] = "Жезли",
  ["Unarmed"] = "Без зброї",
  ["Beast Mastery"] = "Влада над звірами",
  ["Marksmanship"] = "Стрільба",
  ["Survival"] = "Виживання",
  ["Arms"] = "Зброя",
  ["Fury"] = "Лють",
  ["Protection"] = "Захист",
  ["Holy"] = "Світло",
  ["Discipline"] = "Дисципліна",
  ["Shadow"] = "Тінь",
  ["Enhancement"] = "Вдосконалення",
  ["Restoration"] = "Відновлення",
  ["Affliction"] = "Страждання",
  ["Demonology"] = "Демонологія",
  ["Destruction"] = "Руйнування",
  ["Arcane"] = "Таємна магія",
  ["Fire"] = "Вогонь",
  ["Frost"] = "Крига",
  ["Balance"] = "Баланс",
  ["Feral Combat"] = "Сила звіра",
  ["Retribution"] = "Відплата",
  ["Subtlety"] = "Тонкість",
  ["Assassination"] = "Вбивство",
  ["Combat"] = "Бій",
  -- Secondary
  ["Cooking"] = "Кулінарія",
  ["First Aid"] = "Перша допомога",
  ["Fishing"] = "Риболовля",
  ["Riding"] = "Верхова їзда",
  -- PvP
  ["Honor"] = "Честь",
  ["Arena"] = "Арена",
  ["Today"] = "Сьогодні",
  ["Yesterday"] = "Вчора",
  ["This Week"] = "Цього тижня",
  ["Last Week"] = "Минулого тижня",
  ["Lifetime"] = "За весь час",
  ["Honorable Kills"] = "Почесні вбивства",
  ["Dishonorable Kills"] = "Безчесні вбивства",
  ["Highest Rank"] = "Найвищий ранг",
  ["None"] = "Немає",
  ["Rank"] = "Ранг",
  -- races / classes short (для "Level N Race Class")
  ["Human"] = "Людина",
  ["Dwarf"] = "Дворф",
  ["Night Elf"] = "Нічний ельф",
  ["Gnome"] = "Гном",
  ["Orc"] = "Орк",
  ["Undead"] = "Нежить",
  ["Tauren"] = "Таурен",
  ["Troll"] = "Троль",
  ["High Elf"] = "Вищий ельф",
  ["Goblin"] = "Гоблін",
  ["Warrior"] = "Воїн",
  ["Paladin"] = "Паладин",
  ["Hunter"] = "Мисливець",
  ["Rogue"] = "Розбійник",
  ["Priest"] = "Жрець",
  ["Shaman"] = "Шаман",
  ["Mage"] = "Маг",
  ["Warlock"] = "Чорнокнижник",
  ["Druid"] = "Друїд",
}

CHAR_UI_UA["Beast Mastery"] = "Влада над звірами"

local function LookupCharUI(en)
  if not en or en == "" then return nil end
  en = string.gsub(en, "|c%x%x%x%x%x%x%x%x", "")
  en = string.gsub(en, "|r", "")
  en = string.gsub(en, "^%s+", "")
  en = string.gsub(en, "%s+$", "")
  if en == "" or HasCyrillic(en) then return nil end

  if CHAR_UI_UA[en] then return CHAR_UI_UA[en] end

  -- "Level 5 Human Hunter"
  local _, _, lvl, rest = string.find(en, "^Level (%d+)%s+(.+)$")
  if lvl and rest then
    local parts = {}
    local iter = string.gmatch or string.gfind
    for w in iter(rest, "%S+") do
      table.insert(parts, CHAR_UI_UA[w] or w)
    end
    -- multi-word race "Night Elf"
    local r2 = rest
    for eng, ua in pairs(CHAR_UI_UA) do
      if string.find(eng, " ") and string.find(r2, eng, 1, true) then
        r2 = string.gsub(r2, eng, ua, 1)
      end
    end
    if r2 ~= rest then
      return "Рівень " .. lvl .. " " .. r2
    end
    local out = "Рівень " .. lvl
    local i
    for i = 1, table.getn(parts) do
      out = out .. " " .. parts[i]
    end
    return out
  end

  -- "None (Rank 0)"
  local _, _, rank = string.find(en, "^None %(Rank (%d+)%)$")
  if rank then return "Немає (Ранг " .. rank .. ")" end
  local _, _, rank2 = string.find(en, "^None %(Rank (%d+)%)$")

  -- "SkillName  7/75" or "SkillName 7/75"
  local _, _, sname, cur, maxv = string.find(en, "^([%a%s%'%-]+)%s+(%d+)%s*/%s*(%d+)$")
  if sname and cur and maxv then
    sname = string.gsub(sname, "%s+$", "")
    local sua = CHAR_UI_UA[sname]
    if not sua and OceUA_Profession_Names then sua = OceUA_Profession_Names[sname] end
    if not sua and LookupCategoryExact then
      sua = LookupCategoryExact(string.lower(sname), sname)
    end
    if sua then return sua .. " " .. cur .. "/" .. maxv end
  end

  -- faction / skill exact from dicts
  if OceUA_Profession_Names and OceUA_Profession_Names[en] then
    return OceUA_Profession_Names[en]
  end
  if LookupCategoryExact then
    local ua = LookupCategoryExact(string.lower(en), en)
    if ua then return ua end
  end
  -- faction names often in Signs or NPC names - try Reputation is just standings
  return nil
end

local function SetCharFS(fs)
  if not fs or not fs.GetText or not fs.SetText then return end
  local tx = fs:GetText()
  if not tx or tx == "" then return end
  local plain = StripCodes(tx)
  if plain == "" then return end
  -- прибрати вже наліплене помилкове «сек» після чисел
  if string.find(plain, "^[%d%s%-%./]+%s*сек%s*$") then
    local cleaned = string.gsub(plain, "%s*сек%s*$", "")
    cleaned = string.gsub(cleaned, "%s+$", "")
    if cleaned ~= plain then fs:SetText(cleaned) end
    return
  end
  if HasCyrillic(plain) then return end
  -- числа / діапазони шкоди ("22", "6 - 9", "14 - 18") — НЕ чіпати
  if string.find(plain, "^[%d%s%-%./+:]+$") then return end
  local ua = LookupCharUI(plain)
  -- TranslateText на коротких значеннях небезпечний — лише словник UI
  if ua and ua ~= plain then
    local _, _, pref = string.find(tx, "^(|c%x%x%x%x%x%x%x%x)")
    if pref then fs:SetText(pref .. ua .. "|r")
    else fs:SetText(ua) end
  end
end

local function WalkCharFonts(frame, depth)
  if not frame or (depth and depth > 12) then return end
  depth = depth or 0
  if frame.GetRegions then
    local regs = { frame:GetRegions() }
    local i
    for i = 1, table.getn(regs) do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
        SetCharFS(r)
      end
    end
  end
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      WalkCharFonts(kids[i], depth + 1)
    end
  end
end

local function ProcessCharacterFrame()
  if not SkillEnabled() then return end
  if not CharacterFrame or not CharacterFrame:IsVisible() then return end

  WalkCharFonts(CharacterFrame, 0)

  -- відомі підфрейми 1.12
  if PaperDollFrame then WalkCharFonts(PaperDollFrame, 0) end
  if ReputationFrame then WalkCharFonts(ReputationFrame, 0) end
  if SkillFrame then WalkCharFonts(SkillFrame, 0) end
  if PVPFrame then WalkCharFonts(PVPFrame, 0) end
  if HonorFrame then WalkCharFonts(HonorFrame, 0) end
  if CharacterAttributesFrame then WalkCharFonts(CharacterAttributesFrame, 0) end
  if CharacterResistanceFrame then WalkCharFonts(CharacterResistanceFrame, 0) end

  -- рівень / ім'я
  SetCharFS(CharacterNameText)
  SetCharFS(CharacterLevelText)
  SetCharFS(CharacterTitleText)

  -- вкладки внизу
  local i
  for i = 1, 5 do
    SetCharFS(getglobal("CharacterFrameTab" .. i .. "Text"))
    local tab = getglobal("CharacterFrameTab" .. i)
    if tab then WalkCharFonts(tab, 0) end
  end

  -- Skill list buttons
  for i = 1, 20 do
    SetCharFS(getglobal("SkillTypeLabel" .. i))
    SetCharFS(getglobal("SkillRankFrame" .. i .. "SkillName"))
    SetCharFS(getglobal("SkillRankFrame" .. i .. "SkillRank"))
    local sk = getglobal("SkillRankFrame" .. i)
    if sk then WalkCharFonts(sk, 0) end
  end

  -- Reputation bars
  for i = 1, 15 do
    SetCharFS(getglobal("ReputationBar" .. i .. "FactionName"))
    SetCharFS(getglobal("ReputationBar" .. i .. "FactionStanding"))
    local rb = getglobal("ReputationBar" .. i)
    if rb then WalkCharFonts(rb, 0) end
  end
end

local charHooked = false
local function HookCharacterFrame()
  if charHooked then return end
  if not CharacterFrame then return end
  charHooked = true
  local oldShow = CharacterFrame:GetScript("OnShow")
  CharacterFrame:SetScript("OnShow", function()
    if oldShow then oldShow() end
    ProcessCharacterFrame()
  end)
  -- оновлення вкладок
  if CharacterFrame_ShowSubFrame then
    local old = CharacterFrame_ShowSubFrame
    CharacterFrame_ShowSubFrame = function(a1, a2, a3, a4)
      old(a1, a2, a3, a4)
      ProcessCharacterFrame()
    end
  end
  if PaperDollFrame_OnShow then
    local old = PaperDollFrame_OnShow
    PaperDollFrame_OnShow = function(a1, a2, a3, a4)
      old(a1, a2, a3, a4)
      ProcessCharacterFrame()
    end
  end
  if ReputationFrame_Update then
    local old = ReputationFrame_Update
    ReputationFrame_Update = function(a1, a2, a3, a4)
      old(a1, a2, a3, a4)
      ProcessCharacterFrame()
    end
  end
  if SkillFrame_UpdateSkills then
    local old = SkillFrame_UpdateSkills
    SkillFrame_UpdateSkills = function(a1, a2, a3, a4)
      old(a1, a2, a3, a4)
      ProcessCharacterFrame()
    end
  end
  if SkillFrame_Update then
    local old = SkillFrame_Update
    SkillFrame_Update = function(a1, a2, a3, a4)
      old(a1, a2, a3, a4)
      ProcessCharacterFrame()
    end
  end
end

local charEvents = CreateFrame("Frame")
charEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
charEvents:RegisterEvent("UNIT_LEVEL")
charEvents:RegisterEvent("CHARACTER_POINTS_CHANGED")
charEvents:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
charEvents:RegisterEvent("PLAYER_PVP_RANK_CHANGED")
charEvents:SetScript("OnEvent", function()
  HookCharacterFrame()
  if CharacterFrame and CharacterFrame:IsVisible() then
    ProcessCharacterFrame()
  end
end)
HookCharacterFrame()

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
  local function wrapBuff(oldFunc, extra)
    return function(self, a1, a2, a3, a4, a5)
      currentSpellName = nil
      currentSpellRank = nil
      currentSpellID = nil
      if extra then extra(self, a1, a2, a3) end
      -- сховати на час підміни — без кадру EN→UA
      local oldA = self.GetAlpha and self:GetAlpha() or 1
      if self.SetAlpha then self:SetAlpha(0) end
      oldFunc(self, a1, a2, a3, a4, a5)
      self.oceNoDual = true
      self.oceDone = nil
      self.oceLastProc = nil
      ProcessTooltip(self)
      -- другий прохід: клієнт інколи дописує рядки після першого Show
      ProcessTooltip(self)
      self.ocePending = nil
      if self.SetAlpha then self:SetAlpha(oldA > 0 and oldA or 1) end
    end
  end

  if GameTooltip.SetUnitBuff then
    local old = GameTooltip.SetUnitBuff
    GameTooltip.SetUnitBuff = wrapBuff(old, function(self, unit, index)
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
    GameTooltip.SetUnitDebuff = wrapBuff(old, function(self, unit, index)
      local left1 = getglobal("GameTooltipTextLeft1")
      if left1 then currentSpellName = StripCodes(left1:GetText() or "") end
    end)
  end
  if GameTooltip.SetPlayerBuff then
    local old = GameTooltip.SetPlayerBuff
    GameTooltip.SetPlayerBuff = wrapBuff(old, function(self, index)
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
      self.oceItemTip = true
      local key = tostring(a1) .. ":" .. tostring(a2)
      if self.oceInvKey ~= key then
        self.oceInvKey = key
        self.oceDone = nil
        self.oceLastProc = nil
      end
      self.oceDone = nil
      ProcessTooltip(self)
      self.ocePending = nil
      return r1, r2, r3
    end
  end
  local function wrapItem1(oldFunc)
    return function(self, a1)
      currentSpellName = nil
      currentSpellRank = nil
      currentSpellID   = nil
      local r1, r2, r3 = oldFunc(self, a1)
      self.oceItemTip = true
      local key = "1:" .. tostring(a1)
      if self.oceInvKey ~= key then
        self.oceInvKey = key
        self.oceDone = nil
        self.oceLastProc = nil
      end
      self.oceDone = nil
      ProcessTooltip(self)
      self.ocePending = nil
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

    if this.oceItemTip or this.oceNoDual then
      -- екіп / бафи: лише якщо знову з'явився EN (без циклу)
      if (not this.oceDone) and TooltipNeedsUA(this) then
        ProcessTooltip(this)
      end
    elseif this.ocePending then
      this.ocePending = nil
      ProcessTooltip(this)
      this.oceLastSig = TooltipSignature(this)
    elseif (not this.oceDone) and TooltipNeedsUA(this) then
      -- один прохід, не кожен кадр
      ProcessTooltip(this)
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
    this.oceItemTip = nil
    this.oceNoDual = nil
    this.oceBuffLinesDone = nil
    this.oceInvKey = nil
    this.oceLastProc = nil
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
      if this.ocePending or TooltipNeedsUA(this) then
        this.ocePending = nil
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
    shopFix.acc = 0
    shopFix:SetScript("OnUpdate", function()
      if not SkillEnabled() then return end
      this.acc = (this.acc or 0) + (arg1 or 0.03)
      if this.acc < 0.10 then return end
      this.acc = 0
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
  -- Class Trainer (один раз)
  if not OceUA_SkillTrainerHooked then
    if ClassTrainer_Update then
      local oldUpd = ClassTrainer_Update
      ClassTrainer_Update = function(a1, a2, a3, a4)
        oldUpd(a1, a2, a3, a4)
        if SkillEnabled() then
          ProcessTrainerDetails()
          ScheduleTrainerTranslate()
        end
      end
    end
    if ClassTrainer_SetSelection then
      local old = ClassTrainer_SetSelection
      ClassTrainer_SetSelection = function(id)
        old(id)
        ProcessTrainerDetails()
        ScheduleTrainerTranslate()
      end
    end
    if ClassTrainerFrame then
      local oldShow = ClassTrainerFrame:GetScript("OnShow")
      ClassTrainerFrame:SetScript("OnShow", function()
        if oldShow then oldShow() end
        ProcessTrainerDetails()
        ScheduleTrainerTranslate()
      end)
      OceUA_SkillTrainerHooked = true
    end
  end

  -- Spellbook (один раз, коли фрейм є)
  if not OceUA_SkillSpellbookHooked and SpellBookFrame then
    local oldSBShow = SpellBookFrame:GetScript("OnShow")
    SpellBookFrame:SetScript("OnShow", function()
      if oldSBShow then oldSBShow() end
      ScheduleSpellBookTranslate()
    end)
    if SpellBookFrame_Update then
      local oldSBU = SpellBookFrame_Update
      SpellBookFrame_Update = function(a1, a2, a3, a4)
        oldSBU(a1, a2, a3, a4)
        if SkillEnabled() then ScheduleSpellBookTranslate() end
      end
    end
    if SpellButton_UpdateButton then
      local oldSBtn = SpellButton_UpdateButton
      SpellButton_UpdateButton = function(a1, a2, a3, a4)
        oldSBtn(a1, a2, a3, a4)
        if SkillEnabled() and SpellBookFrame and SpellBookFrame:IsVisible() then
          ProcessSpellBook()
        end
      end
    end
    OceUA_SkillSpellbookHooked = true
  end

  -- TradeSkill (один раз, коли API/фрейм з'явились)
  if not OceUA_SkillTradeHooked and (TradeSkillFrame_SetSelection or TradeSkillFrame) then
    if TradeSkillFrame_SetSelection then
      local old = TradeSkillFrame_SetSelection
      TradeSkillFrame_SetSelection = function(id)
        old(id)
        -- миттєво в тому ж кадрі після EN від клієнта (без delay = без блимання)
        pcall(ProcessTradeSkillDetailsCore)
      end
    end
    if TradeSkillFrame_Update then
      local oldU = TradeSkillFrame_Update
      TradeSkillFrame_Update = function(a1, a2, a3, a4)
        oldU(a1, a2, a3, a4)
        pcall(ProcessTradeSkillDetailsCore)
      end
    end
    if TradeSkillFrame then
      local oldShow = TradeSkillFrame:GetScript("OnShow")
      TradeSkillFrame:SetScript("OnShow", function()
        if oldShow then oldShow() end
        pcall(ProcessTradeSkillDetails)
      end)
    end
    OceUA_SkillTradeHooked = true
  end

  -- Craft / Enchant (один раз)
  if not OceUA_SkillCraftHooked and (CraftFrame_SetSelection or CraftFrame) then
    if CraftFrame_SetSelection then
      local old = CraftFrame_SetSelection
      CraftFrame_SetSelection = function(id)
        old(id)
        pcall(ProcessTradeSkillDetailsCore)
      end
    end
    if CraftFrame_Update then
      local oldCU = CraftFrame_Update
      CraftFrame_Update = function(a1, a2, a3, a4)
        oldCU(a1, a2, a3, a4)
        pcall(ProcessTradeSkillDetailsCore)
      end
    end
    if CraftFrame then
      local oldCS = CraftFrame:GetScript("OnShow")
      CraftFrame:SetScript("OnShow", function()
        if oldCS then oldCS() end
        pcall(ProcessTradeSkillDetails)
      end)
    end
    OceUA_SkillCraftHooked = true
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
  if tipWatcher.elapsed < 0.40 then return end
  tipWatcher.elapsed = 0
  if not SkillEnabled() then return end
  -- у бою рідше чіпати тултіп (FPS)
  if UnitAffectingCombat and UnitAffectingCombat("player") then return end
  if not GameTooltip or not GameTooltip:IsVisible() then
    if GameTooltip then
      GameTooltip.oceLastSig = nil
      GameTooltip.oceDone = nil
    end
    return
  end
  local charOpen = CharacterFrame and CharacterFrame:IsVisible()
  if not charOpen then
    if GameTooltip.ocePending or TooltipNeedsUA(GameTooltip) then
      GameTooltip.ocePending = nil
      GameTooltip.oceDone = nil
      ProcessTooltip(GameTooltip)
      GameTooltip.oceLastSig = TooltipSignature(GameTooltip)
    end
  end
  if ItemRefTooltip and ItemRefTooltip:IsVisible() then
    if ItemRefTooltip.ocePending or TooltipNeedsUA(ItemRefTooltip) then
      ItemRefTooltip.ocePending = nil
      ItemRefTooltip.oceDone = nil
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
    if HookCharacterFrame then HookCharacterFrame() end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA v" .. VERSION .. " — квести, діалоги, книги, скіли, предмети | /oceua")
  elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
    HookFrames()
    ProcessTrainerDetails()
  elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
    HookFrames()
    ProcessTradeSkillDetails()
  elseif event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" then
    -- крафт start/finish: лише лічильники
    ScheduleTradeSkillTranslate("light")
  end
end)


-- ============================================================
-- Лут (LootFrame / GroupLoot) — назви предметів з Items_Dictionary
-- ============================================================
local function LookupItemUA(en)
  if not en or en == "" then return nil end
  en = string.gsub(en, "|c%x%x%x%x%x%x%x%x", "")
  en = string.gsub(en, "|r", "")
  en = string.gsub(en, "|T.-|t", "")
  en = string.gsub(en, "^%s+", "")
  en = string.gsub(en, "%s+$", "")
  if en == "" then return nil end
  if HasCyrillic(en) then return nil end
  local dict = OceUA_Item_Dictionary or OceUA_Items_Dictionary
  if not dict then return nil end
  local ua = dict[en]
  if (not ua or ua == "") and itemDictLowerUA then
    ua = itemDictLowerUA[string.lower(en)]
  end
  if ua and ua ~= "" and ua ~= en then return ua end
  -- без суфіксу кількості "x2" / "(2)"
  local base = string.gsub(en, "%s*[xX×]%s*%d+%s*$", "")
  base = string.gsub(base, "%s*%(%d+%)%s*$", "")
  if base ~= en then
    ua = dict[base]
    if (not ua or ua == "") and itemDictLowerUA then
      ua = itemDictLowerUA[string.lower(base)]
    end
    if ua and ua ~= "" then return ua end
  end
  return nil
end

local function TranslateItemFontString(fs)
  if not fs or not fs.GetText or not fs.SetText then return end
  local tx = fs:GetText()
  if not tx or tx == "" then return end
  local plain = StripCodes(tx)
  if HasCyrillic(plain) then return end
  local ua = LookupItemUA(plain)
  if ua then
    -- зберегти колір-коди префіксу, якщо були
    local _, _, pref = string.find(tx, "^(|c%x%x%x%x%x%x%x%x)")
    if pref then
      fs:SetText(pref .. ua .. "|r")
    else
      fs:SetText(ua)
    end
  end
end

local function ProcessLootFrame()
  if not SkillEnabled() then return end
  -- стандартний LootFrame 1.12
  if LootFrame and LootFrame:IsVisible() then
    if LootFrameTitleText then
      local tt = LootFrameTitleText:GetText()
      if tt and not HasCyrillic(tt) then
        if string.lower(tt) == "items" or tt == "Items" then
          LootFrameTitleText:SetText("Предмети")
        else
          TranslateFontString(LootFrameTitleText)
        end
      end
    end
    local i
    for i = 1, 8 do
      TranslateItemFontString(getglobal("LootButton" .. i .. "Text"))
      TranslateItemFontString(getglobal("LootButton" .. i .. "Name"))
      local btn = getglobal("LootButton" .. i)
      if btn then
        -- іноді текст прямо на кнопці
        if btn.GetText and btn.SetText then
          local tx = btn:GetText()
          if tx and not HasCyrillic(tx) then
            local ua = LookupItemUA(StripCodes(tx))
            if ua then btn:SetText(ua) end
          end
        end
        -- обхід дітей-FontString
        if btn.GetRegions then
          local regs = { btn:GetRegions() }
          local ri
          for ri = 1, table.getn(regs) do
            local r = regs[ri]
            if r and r.GetObjectType and r:GetObjectType() == "FontString" then
              TranslateItemFontString(r)
            end
          end
        end
      end
    end
  end
  -- Need/Greed
  local g
  for g = 1, 4 do
    TranslateItemFontString(getglobal("GroupLootFrame" .. g .. "Name"))
    TranslateItemFontString(getglobal("GroupLootFrame" .. g .. "SlotLabel"))
  end
end

local lootHooked = false
local function HookLootFrame()
  if lootHooked then return end
  if not LootFrame then return end
  lootHooked = true
  local oldShow = LootFrame:GetScript("OnShow")
  LootFrame:SetScript("OnShow", function()
    if oldShow then oldShow() end
    ProcessLootFrame()
    -- один кадр пізніше (клієнт інколи ставить назви після OnShow)
    local f = CreateFrame("Frame")
    f.t = 0
    f:SetScript("OnUpdate", function()
      this.t = this.t + arg1
      if this.t < 0.02 then return end
      this:SetScript("OnUpdate", nil)
      ProcessLootFrame()
    end)
  end)
  -- хук оновлення слота
  if LootFrame_Update then
    local oldU = LootFrame_Update
    LootFrame_Update = function(a1, a2, a3, a4)
      oldU(a1, a2, a3, a4)
      ProcessLootFrame()
    end
  end
  local g
  for g = 1, 4 do
    local gf = getglobal("GroupLootFrame" .. g)
    if gf and not gf._oceua_loot then
      gf._oceua_loot = true
      local oldG = gf:GetScript("OnShow")
      gf:SetScript("OnShow", function()
        if oldG then oldG() end
        ProcessLootFrame()
      end)
    end
  end
end

-- UIErrorsFrame: skill-up / learn messages (без миготіння — переклад у момент AddMessage)
local function TranslateErrorMessage(msg)
  if not msg or msg == "" or HasCyrillic(msg) then return msg end

  local function nameUA(en)
    if not en or en == "" then return en end
    en = string.gsub(en, "^%s+", "")
    en = string.gsub(en, "%s+$", "")
    if LookupItemUA then
      local u = LookupItemUA(en)
      if u and u ~= en then return u end
    end
    if OceUA_ITEM_DICT and OceUA_ITEM_DICT[en] then return OceUA_ITEM_DICT[en] end
    if OceUA_World_Names and OceUA_World_Names[en] then return OceUA_World_Names[en] end
    if OceUA_NPC_Names and OceUA_NPC_Names[en] then return OceUA_NPC_Names[en] end
    if OceUA_Skill_Dictionary and OceUA_Skill_Dictionary[en] then return OceUA_Skill_Dictionary[en] end
    if OceUA_Profession_Names and OceUA_Profession_Names[en] then return OceUA_Profession_Names[en] end
    if TranslateObjectiveLine then
      local u = TranslateObjectiveLine(en)
      if u and u ~= en then return u end
    end
    return en
  end

  -- Your skill in X has increased to Y.
  local _, _, skill, rank = string.find(msg, "^Your skill in (.+) has increased to (%d+)%.?$")
  if skill and rank then
    local sk = LookupCategoryExact and LookupCategoryExact(string.lower(skill), skill) or nil
    if not sk and OceUA_Profession_Names then sk = OceUA_Profession_Names[skill] end
    if not sk and OceUA_Skill_Dictionary then sk = OceUA_Skill_Dictionary[skill] end
    return "Ваш навик «" .. (sk or skill) .. "» підвищено до " .. rank .. "."
  end
  -- You have gained the X skill.
  _, _, skill = string.find(msg, "^You have gained the (.+) skill%.?$")
  if skill then
    local sk = OceUA_Profession_Names and OceUA_Profession_Names[skill] or skill
    return "Ви здобули навик «" .. sk .. "»."
  end
  -- You have learned a new recipe: X  / You have learned how to create: X
  local _, _, recipe = string.find(msg, "^You have learned .-:%s*(.+)$")
  if recipe then
    local ua = LookupItemUA(recipe) or recipe
    return "Ви вивчили: " .. ua
  end

  -- Quest progress / kill / loot style messages on screen
  -- "Name slain: 3/10" / "Name: 3/10"
  local _, _, nm, cur, maxv = string.find(msg, "^(.+)%s+slain:%s*(%d+)%s*/%s*(%d+)%s*$")
  if nm and cur and maxv then
    return nameUA(nm) .. " убито: " .. cur .. "/" .. maxv
  end
  _, _, nm, cur, maxv = string.find(msg, "^(.+):%s*(%d+)%s*/%s*(%d+)%s*$")
  if nm and cur and maxv then
    return nameUA(nm) .. ": " .. cur .. "/" .. maxv
  end
  -- "Quest accepted: X" / "Quest completed: X"
  local _, _, qn = string.find(msg, "^Quest accepted:%s*(.+)$")
  if qn then return "Квест прийнято: " .. (nameUA(qn) or qn) end
  _, _, qn = string.find(msg, "^Quest completed:%s*(.+)$")
  if qn then return "Квест виконано: " .. (nameUA(qn) or qn) end
  _, _, qn = string.find(msg, "^Received item:%s*(.+)$")
  if qn then return "Отримано: " .. nameUA(qn) end
  -- "Requires X" / "You need X"
  local _, _, req = string.find(msg, "^Requires%s+(.+)$")
  if req then return "Потрібно: " .. nameUA(req) end
  -- Combat feedback lines on UIErrorsFrame
  local combatErr = {
    ["You dodge"] = "Ви ухилились",
    ["You parry"] = "Ви парирували",
    ["You block"] = "Ви заблокували",
    ["You resist"] = "Ви чините опір",
    ["You absorb"] = "Ви поглинаєте",
    ["You evade"] = "Ви уникаєте",
    ["Enemy dodges"] = "Ворог ухиляється",
    ["Enemy parries"] = "Ворог парирує",
    ["Enemy blocks"] = "Ворог блокує",
    ["Enemy resists"] = "Ворог чинить опір",
    ["Enemy absorbs"] = "Ворог поглинає",
    ["Enemy evades"] = "Ворог уникає",
    ["Missed"] = "Промах",
    ["Interrupted"] = "Перервано",
    ["Target is immune"] = "Ціль має імунітет",
    ["Immune"] = "Імунітет",
    ["Dodged"] = "Ухилення",
    ["Parried"] = "Парирування",
    ["Blocked"] = "Блок",
    ["Absorbed"] = "Поглинуто",
    ["Resisted"] = "Опір",
    ["Evaded"] = "Уникнення",
    ["Deflected"] = "Відхилено",
    ["Reflected"] = "Відбито",
    ["Can't attack while dead."] = "Не можна атакувати, будучи мертвим.",
    ["You can't do that yet."] = "Ви ще не можете цього зробити.",
    ["You are too far away."] = "Занадто далеко.",
    ["Out of range."] = "Поза зоною досяжності.",
    ["Target needs to be in front of you."] = "Ціль має бути перед вами.",
    ["You are facing the wrong way!"] = "Ви дивитесь не в той бік!",
    ["You must be behind your target."] = "Потрібно бути позаду цілі.",
    ["Not enough mana."] = "Недостатньо мани.",
    ["Not enough energy."] = "Недостатньо енергії.",
    ["Not enough rage."] = "Недостатньо люті.",
    ["Not enough health."] = "Недостатньо здоров'я.",
    ["Item is not ready yet."] = "Предмет ще не готовий.",
    ["Ability is not ready yet."] = "Здібність ще не готова.",
    ["Spell is not ready yet."] = "Заклинання ще не готове.",
    ["Another action is in progress"] = "Виконується інша дія",
    ["Can't do that while moving"] = "Неможливо під час руху",
    ["You are dead"] = "Ви мертві",
    ["You are stunned"] = "Вас оглушено",
    ["You are silenced"] = "Вас знемовлено",
    ["You are pacified"] = "Вас заспокоено",
    ["Target is dead"] = "Ціль мертва",
    ["Invalid target"] = "Недійсна ціль",
    ["You have no target."] = "Немає цілі.",
    ["Line of sight"] = "Немає прямої видимості",
  }
  if combatErr[msg] then return combatErr[msg] end
  -- часткові збіги
  local low = string.lower(msg)
  if string.find(low, "dodge") then return string.gsub(msg, "[Dd]odge[sd]?", "ухилення") end
  if string.find(low, "parry") then return string.gsub(msg, "[Pp]arr[yi]e?d?", "парирування") end
  if string.find(low, "block") then return string.gsub(msg, "[Bb]locke?d?", "блок") end
  if string.find(low, "resist") then return string.gsub(msg, "[Rr]esiste?d?", "опір") end
  if string.find(low, "miss") then return string.gsub(msg, "[Mm]isse?d?", "промах") end
  if string.find(low, "immune") then return string.gsub(msg, "[Ii]mmune", "імунітет") end
  if string.find(low, "interrupt") then return string.gsub(msg, "[Ii]nterrupted?", "перервано") end
  if string.find(low, "absorb") then return string.gsub(msg, "[Aa]bsorbe?d?", "поглинання") end
  if string.find(low, "critical") then return string.gsub(msg, "[Cc]ritical", "крит") end
  -- голі слова з екрану/скілів
  local single = {
    ["DODGE"]="УХИЛЕННЯ",["PARRY"]="ПАРИРУВАННЯ",["BLOCK"]="БЛОК",["MISS"]="ПРОМАХ",
    ["ABSORB"]="ПОГЛИНАННЯ",["RESIST"]="ОПІР",["IMMUNE"]="ІМУНІТЕТ",["EVADE"]="УНИКНЕННЯ",
    ["INTERRUPT"]="ПЕРЕРИВАННЯ",["INTERRUPTED"]="ПЕРЕРВАНО",["CRIT"]="КРИТ",["CRITICAL"]="КРИТ",
    ["CRUSHING"]="ЗНИЩУВАЛЬНИЙ",["GLANCING"]="КОВЗНИЙ",["REFLECT"]="ВІДБИТТЯ",["DEFLECT"]="ВІДХИЛЕННЯ",
  }
  if single[msg] then return single[msg] end
  if single[string.upper(msg)] then return single[string.upper(msg)] end
  -- Generic: try whole message as known name
  local whole = nameUA(msg)
  if whole ~= msg then return whole end
  return msg
end

local function HookUIErrors()
  if not UIErrorsFrame or UIErrorsFrame._oceua_hooked then return end
  UIErrorsFrame._oceua_hooked = true
  local oldAdd = UIErrorsFrame.AddMessage
  if oldAdd then
    UIErrorsFrame.AddMessage = function(self, msg, r, g, b, a)
      if type(msg) == "string" then
        -- спам клієнта при зміні зони / втраті mouseover
        local low = string.lower(msg)
        if string.find(low, "unknown unit", 1, true) then
          return
        end
        local allow = true
        if OceUA_IsEnabled then
          allow = OceUA_IsEnabled("skill") or OceUA_IsEnabled("quest") or OceUA_IsEnabled("world") or OceUA_IsEnabled("item")
        end
        if allow then
          msg = TranslateErrorMessage(msg)
        end
      end
      return oldAdd(self, msg, r, g, b, a)
    end
  end
end

local lootEvents = CreateFrame("Frame")
lootEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
lootEvents:RegisterEvent("LOOT_OPENED")
lootEvents:RegisterEvent("LOOT_SLOT_CLEARED")
lootEvents:RegisterEvent("ADDON_LOADED")
lootEvents:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
    HookLootFrame()
    HookUIErrors()
  elseif event == "LOOT_OPENED" or event == "LOOT_SLOT_CLEARED" then
    HookLootFrame()
    ProcessLootFrame()
  end
end)
HookLootFrame()
HookUIErrors()

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


-- ============================================================
-- Merchant / Auction / Bank UI (назви в списках, не лише тултіп)
-- ============================================================
local function LookupItemName(en)
  if not en or en == "" then return nil end
  local dict = OceUA_Item_Dictionary or OceUA_Items_Dictionary
  if dict and dict[en] then return dict[en] end
  if itemDictUA and itemDictUA[en] then return itemDictUA[en] end
  if itemDictLowerUA then return itemDictLowerUA[string.lower(en)] end
  return nil
end

local function TranslateMerchantFrame()
  if not SkillEnabled() then return end
  if not MerchantFrame or not MerchantFrame:IsVisible() then return end
  local i
  for i = 1, 12 do
    local nameFS = getglobal("MerchantItem" .. i .. "Name")
    if nameFS and nameFS.GetText then
      local tx = nameFS:GetText()
      if tx and tx ~= "" and not HasCyrillic(tx) then
        local ua = LookupItemName(tx)
        if not ua then
          local nt, ok = TranslateText(tx)
          if ok then ua = nt end
        end
        if ua then nameFS:SetText(ua) end
      end
    end
  end
  if MerchantNameText then TranslateFontString(MerchantNameText) end
end

local function TranslateAuctionFrame()
  if not SkillEnabled() then return end
  if not AuctionFrame or not AuctionFrame:IsVisible() then return end
  local i
  for i = 1, 8 do
    local nameFS = getglobal("BrowseButton" .. i .. "Name")
    if nameFS and nameFS.GetText then
      local tx = nameFS:GetText()
      if tx and tx ~= "" and not HasCyrillic(tx) then
        local ua = LookupItemName(tx)
        if not ua then
          local nt, ok = TranslateText(tx)
          if ok then ua = nt end
        end
        if ua then nameFS:SetText(ua) end
      end
    end
  end
  for i = 1, 9 do
    local nameFS = getglobal("BidButton" .. i .. "Name")
    if nameFS and nameFS.GetText then
      local tx = nameFS:GetText()
      if tx and tx ~= "" and not HasCyrillic(tx) then
        local ua = LookupItemName(tx)
        if ua then nameFS:SetText(ua) end
      end
    end
    nameFS = getglobal("AuctionsButton" .. i .. "Name")
    if nameFS and nameFS.GetText then
      local tx = nameFS:GetText()
      if tx and tx ~= "" and not HasCyrillic(tx) then
        local ua = LookupItemName(tx)
        if ua then nameFS:SetText(ua) end
      end
    end
  end
end

local function HookShopFontString(fs)
  if not fs or not fs.SetText or fs.oceShopHooked then return end
  fs.oceShopHooked = true
  local oldSet = fs.SetText
  fs.SetText = function(self, text)
    if SkillEnabled() and text and text ~= "" and not HasCyrillic(text) then
      local ua = LookupItemName(text)
      if not ua then
        local nt, ok = TranslateText(text)
        if ok then ua = nt end
      end
      if ua then text = ua end
    end
    oldSet(self, text)
  end
end

local shopHooked = false
local function HookMerchantAuctionButtons()
  local i
  for i = 1, 12 do
    HookShopFontString(getglobal("MerchantItem" .. i .. "Name"))
  end
  for i = 1, 8 do
    HookShopFontString(getglobal("BrowseButton" .. i .. "Name"))
  end
  for i = 1, 9 do
    HookShopFontString(getglobal("BidButton" .. i .. "Name"))
    HookShopFontString(getglobal("AuctionsButton" .. i .. "Name"))
  end
  HookShopFontString(MerchantNameText)
  shopHooked = true
end

local shopWatch = CreateFrame("Frame")
shopWatch.acc = 0
shopWatch:SetScript("OnUpdate", function()
  this.acc = this.acc + arg1
  if this.acc < 0.5 then return end
  this.acc = 0
  if not SkillEnabled() then return end
  -- хуки раз + коли вікно відкрите (кнопки з’являються пізно)
  if (MerchantFrame and MerchantFrame:IsVisible()) or (AuctionFrame and AuctionFrame:IsVisible()) then
    HookMerchantAuctionButtons()
  end
end)

if MerchantFrame then
  local oldM = MerchantFrame:GetScript("OnShow")
  MerchantFrame:SetScript("OnShow", function()
    if oldM then oldM() end
    HookMerchantAuctionButtons()
    TranslateMerchantFrame()
  end)
end
