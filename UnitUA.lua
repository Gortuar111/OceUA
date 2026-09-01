--[[
  OceUA — імена NPC / мобів / об'єктів / вивісок + рядки юніт-тултіпа
  (рівень, раса, клас, Player, Pet, Elite…)

  ВАЖЛИВО: заміна раси/класу лише в рядках Level … (цілі слова),
  щоб не чіпати Mageroyal, Mageweave тощо.
]]

local function Enabled()
  if OceUA_IsEnabled then
    return OceUA_IsEnabled("world")
  end
  return true
end

local function ShowOriginal()
  if OceUA_Get then
    local v = OceUA_Get("showOriginal", true)
    if v == false then return false end
    return true
  end
  return true
end

local function LookupName(en)
  if not en or en == "" then return nil end
  local function hit(d)
    if not d then return nil end
    local ua = d[en]
    if ua and ua ~= "" and ua ~= en then return ua end
    return nil
  end
  local ua
  -- імена
  ua = hit(OceUA_Mobs_Dictionary); if ua then return ua end
  ua = hit(OceUA_NPC_Names_Dictionary); if ua then return ua end
  ua = hit(OceUA_Objects_Dictionary); if ua then return ua end
  -- зони ПЕРЕД Signs: один переклад з Zones (екран / мінімапа / тултіп)
  ua = hit(OceUA_Zones_Dictionary); if ua then return ua end
  do
    local stripped = string.gsub(en, "^[Tt]he%s+", "")
    if stripped ~= en and OceUA_Zones_Dictionary and OceUA_Zones_Dictionary[stripped] and OceUA_Zones_Dictionary[stripped] ~= "" then
      return OceUA_Zones_Dictionary[stripped]
    end
  end
  -- вивіски / таблички (не зони з zones)
  ua = hit(OceUA_Signs_Dictionary); if ua then return ua end
  ua = hit(OceUA_Unsorted_Dictionary); if ua then return ua end
  -- випробування (Active Challenges / War Mode …)
  ua = hit(OceUA_challenges); if ua then return ua end
  -- професії / титули тренерів (база professions.lua + Profession_Names)
  ua = hit(OceUA_profession_ranks); if ua then return ua end
  ua = hit(OceUA_Profession_Names); if ua then return ua end
  ua = hit(OceUA_professions); if ua then return ua end
  ua = hit(OceUA_pet_teach); if ua then return ua end
  ua = hit(OceUA_tooltip_extras); if ua then return ua end
  -- фракції / репутація (короткі ярлики теж)
  ua = hit(OceUA_Reputation_Dictionary); if ua then return ua end
  -- класи / раси
  ua = hit(OceUA_Class_Names); if ua then return ua end
  ua = hit(OceUA_Race_Names); if ua then return ua end
  -- аури (рідко в unit tip)
  ua = hit(OceUA_Aura_Descriptions); if ua then return ua end
  return nil
end

local function FormatName(ua, en)
  if not ua then return en end
  if ShowOriginal() and en and en ~= ua then
    return ua .. "\n|cffaaaaaa" .. en .. "|r"
  end
  return ua
end

local FIXED = {
  ["Paladin Trainer"] = "Учитель паладинів",
  ["Warrior Trainer"] = "Учитель воїнів",
  ["Hunter Trainer"] = "Учитель мисливців",
  ["Rogue Trainer"] = "Учитель розбійників",
  ["Priest Trainer"] = "Учитель жерців",
  ["Mage Trainer"] = "Учитель магів",
  ["Warlock Trainer"] = "Учитель чорнокнижників",
  ["Druid Trainer"] = "Учитель друїдів",
  ["Shaman Trainer"] = "Учитель шаманів",
  ["Weapon Master"] = "Майстер зброї",
  ["Portal Trainer"] = "Учитель порталів",
  ["Riding Trainer"] = "Учитель верхової їзди",
  ["Stable Master"] = "Господар стійл",
  ["Innkeeper"] = "Шинкар",
  ["Flight Master"] = "Диспетчер польотів",
  ["Battlemaster"] = "Воєначальник",
  ["Banker"] = "Банкір",
  ["Guild Master"] = "Майстер гільдії",
  ["Alliance"] = "Альянс",
  ["Horde"] = "Орда",
  ["Vendor"] = "Торговець",
  ["Repair"] = "Ремонт",
  ["Merchant"] = "Купець",
  ["Quest Giver"] = "Видає завдання",
  ["Trainer"] = "Учитель",
  ["Elite"] = "Елітний",
  ["Rare"] = "Рідкісний",
  ["Rare Elite"] = "Рідкісний елітний",
  ["Boss"] = "Бос",
  ["Civilian"] = "Цивільний",
  ["Skinnable"] = "Можна зняти шкіру",
  ["Corpse"] = "Труп",
  ["PvP"] = "PvP",
  ["Player"] = "Гравець",
  ["(Player)"] = "(Гравець)",
  ["Active Challenges:"] = "Активні випробування:",
  ["Active Challenges"] = "Активні випробування",
  ["Pet"] = "Улюбленець",
  ["Minion"] = "Прислужник",
  ["Guardian"] = "Охоронець",
  ["Target"] = "Ціль",
  ["Tapped"] = "Зайнятий",
  ["Combat"] = "Бій",
  ["Dead"] = "Мертвий",
  ["Ghost"] = "Привид",
  ["Humanoid"] = "Гуманоїд",
  ["Beast"] = "Звір",
  ["Critter"] = "Тваринка",
  ["Dragonkin"] = "Драконід",
  ["Elemental"] = "Елементаль",
  ["Demon"] = "Демон",
  ["Giant"] = "Велетень",
  ["Undead"] = "Нежить",
  ["Mechanical"] = "Механізм",
  ["Not specified"] = "Не вказано",
}

local RACE_ORDER = {
  "Night Elf", "Blood Elf", "High Elf", "Undead", "Tauren",
  "Human", "Dwarf", "Gnome", "Orc", "Troll", "Goblin",
}
local CLASS_ORDER = {
  "Death Knight", "Warlock", "Warrior", "Paladin", "Hunter",
  "Shaman", "Priest", "Druid", "Rogue", "Mage",
}

local function RaceUA(en)
  local d = OceUA_Race_Names
  if d and d[en] then return d[en] end
  return nil
end

local function ClassUA(en)
  local d = OceUA_Class_Names
  if d and d[en] then return d[en] end
  return nil
end

-- ціле слово: не чіпає Mageroyal / Mageweave / Blacksmithing
local function ReplaceWhole(text, en, ua)
  if not text or not en or not ua then return text end
  if string.find(en, " ") then
    -- багатослівні (Night Elf): простий gsub безпечніший
    return string.gsub(text, en, ua)
  end
  local i = 1
  local n = string.len(text)
  local enLen = string.len(en)
  local out = ""
  while i <= n do
    local found = string.find(text, en, i, true)
    if not found then
      out = out .. string.sub(text, i)
      break
    end
    local before = string.sub(text, i, found - 1)
    local afterPos = found + enLen
    local chBefore = found > 1 and string.sub(text, found - 1, found - 1) or ""
    local chAfter = afterPos <= n and string.sub(text, afterPos, afterPos) or ""
    local okBefore = (found == 1) or not string.find(chBefore, "[%w]")
    local okAfter = (afterPos > n) or not string.find(chAfter, "[%w]")
    if okBefore and okAfter then
      out = out .. before .. ua
      i = afterPos
    else
      out = out .. before .. en
      i = afterPos
    end
  end
  return out
end

local function SubRaceClass(text)
  if not text then return text end
  local i
  for i = 1, table.getn(RACE_ORDER) do
    local en = RACE_ORDER[i]
    local ua = RaceUA(en)
    if ua then text = ReplaceWhole(text, en, ua) end
  end
  for i = 1, table.getn(CLASS_ORDER) do
    local en = CLASS_ORDER[i]
    local ua = ClassUA(en)
    if ua then text = ReplaceWhole(text, en, ua) end
  end
  return text
end

local function StripCodes(s)
  if not s then return s end
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, "|H.-|h(.-)|h", "%1")
  s = string.gsub(s, "|T.-|t", "")
  return s
end

local function NormApos(s)
  if not s then return s end
  s = string.gsub(s, "\226\128\153", "'")
  s = string.gsub(s, "\226\128\152", "'")
  s = string.gsub(s, "\226\128\154", "'")
  s = string.gsub(s, "`", "'")
  s = string.gsub(s, "\194\180", "'")
  return s
end

local KIND_UA = {
  Pet = "Улюбленець",
  Minion = "Прислужник",
  Guardian = "Охоронець",
  Ward = "Охорона",
  Companion = "Супутник",
}

local function TranslatePetOwnerLine(text)
  if not text or text == "" then return nil end
  text = StripCodes(text)
  text = NormApos(text)
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")

  -- Lua 5.0: НЕМАЄ | в pattern — перевіряємо кожен kind окремо
  local kinds = { "Pet", "Minion", "Guardian", "Ward", "Companion" }
  local ki
  for ki = 1, table.getn(kinds) do
    local kind = kinds[ki]
    local pat = "(.+)'s " .. kind .. "%s*$"
    local _, _, owner = string.find(text, pat)
    if owner and KIND_UA[kind] then
      owner = string.gsub(owner, "^%s+", "")
      owner = string.gsub(owner, "%s+$", "")
      if string.len(owner) >= 1 and string.len(owner) < 48 then
        return KIND_UA[kind] .. " " .. owner
      end
    end
    -- "Pet of Owner"
    local pat2 = "^" .. kind .. " of (.+)$"
    local _, _, owner2 = string.find(text, pat2)
    if owner2 and KIND_UA[kind] then
      return KIND_UA[kind] .. " " .. owner2
    end
  end

  if text == "Pet" then return "Улюбленець" end
  if text == "Minion" then return "Прислужник" end
  return nil
end

local function StripEliteFlags(tail)
  local elite, rare, boss = false, false, false
  if not tail then return "", false, false, false end
  -- Rare Elite / (Rare Elite)
  if string.find(tail, "Rare%s+Elite") or string.find(tail, "%(%s*Rare%s+Elite%s*%)") then
    rare = true
    elite = true
    tail = string.gsub(tail, "%(?%s*Rare%s+Elite%s*%)?", "")
  end
  if string.find(tail, "Elite") then
    elite = true
    tail = string.gsub(tail, "%(?%s*Elite%s*%)?", "")
  end
  if string.find(tail, "Rare") then
    rare = true
    tail = string.gsub(tail, "%(?%s*Rare%s*%)?", "")
  end
  if string.find(tail, "Boss") then
    boss = true
    tail = string.gsub(tail, "%(?%s*Boss%s*%)?", "")
  end
  tail = string.gsub(tail, "%(%s*%)", "") -- порожні ()
  tail = string.gsub(tail, "%s+", " ")
  tail = string.gsub(tail, "^%s+", "")
  tail = string.gsub(tail, "%s+$", "")
  return tail, elite, rare, boss
end

local function AppendFlags(out, elite, rare, boss)
  if rare and elite then
    out = out .. " (рідкісний елітний)"
  elseif elite then
    out = out .. " (елітний)"
  elseif rare then
    out = out .. " (рідкісний)"
  end
  if boss then out = out .. " (бос)" end
  return out
end

local function TranslateLevelish(text)
  if not text or text == "" then return nil end
  -- color-коди ламають перевірку "Level " → спочатку зняти
  text = StripCodes(text)
  text = NormApos(text)
  -- якщо вже повністю UA (є "Рівень") — не чіпати
  if string.find(text, "Рівень") then return nil end
  -- інші рядки з кирилицею (не Level) — не чіпати
  local isLevelLine = string.find(string.lower(text), "^%s*level%s")
  if not isLevelLine then
    if string.find(text, "[А-Яа-яІіЇїЄєҐґ]") or string.find(text, "[89]") then return nil end
  end

  if FIXED[text] then return FIXED[text] end

  local pet = TranslatePetOwnerLine(text)
  if pet then return pet end

  local t = text
  t = string.gsub(t, "%(Player%)", "(Гравець)")

  t = string.gsub(t, "^%s+", "")
  if string.sub(string.lower(t), 1, 8) == "level ??" then
    t = "Level ??" .. string.sub(t, 9)
  elseif string.sub(string.lower(t), 1, 6) == "level " then
    t = "Level " .. string.sub(t, 7)
  end

  -- Level ?? …
  if string.sub(t, 1, 8) == "Level ??" then
    local tail = string.sub(t, 9)
    tail = string.gsub(tail, "^%s+", "")
    local elite, rare, boss
    tail, elite, rare, boss = StripEliteFlags(tail)
    if FIXED[tail] then
      return AppendFlags("Рівень ?? (" .. FIXED[tail] .. ")", elite, rare, boss)
    end
    if tail ~= "" then
      tail = SubRaceClass(tail)
      tail = string.gsub(tail, "%s+", " ")
      tail = string.gsub(tail, "^%s+", "")
      tail = string.gsub(tail, "%s+$", "")
    end
    local out = "Рівень ??"
    if tail ~= "" then out = out .. " " .. tail end
    return AppendFlags(out, elite, rare, boss)
  end

  -- Level N …
  if string.sub(t, 1, 6) == "Level " then
    local rest = string.sub(t, 7)
    local _, _, num, tail = string.find(rest, "^(%d+)(.*)$")
    if num then
      tail = string.gsub(tail or "", "^%s+", "")
      local elite, rare, boss
      tail, elite, rare, boss = StripEliteFlags(tail)
      if FIXED[tail] then
        return AppendFlags("Рівень " .. num .. " (" .. FIXED[tail] .. ")", elite, rare, boss)
      end
      if tail ~= "" then
        tail = SubRaceClass(tail)
        tail = string.gsub(tail, "%s+", " ")
        tail = string.gsub(tail, "^%s+", "")
        tail = string.gsub(tail, "%s+$", "")
      end
      local out = "Рівень " .. num
      if tail ~= "" then out = out .. " " .. tail end
      return AppendFlags(out, elite, rare, boss)
    end
  end

  -- НЕ застосовуємо SubRaceClass до довільних рядків (Mageroyal тощо)
  return nil
end

local function TranslateTipName(tip)
  if not Enabled() then return end
  if not tip or not tip.GetName then return end
  local tipName = tip:GetName()
  if not tipName then return end
  local fs = getglobal(tipName .. "TextLeft1")
  if not fs then return end
  local en = fs:GetText()
  if not en or en == "" then return end
  -- pfQuest / квестові тултіпи з [!]/[?] — їх обробляє OceTip, не чіпаємо тут
  if string.find(en, "%[!%]") or string.find(en, "%[%?%]") then return end

  local pet = TranslatePetOwnerLine(en)
  if pet then
    fs:SetText(pet)
    tip._OceUA_NeedResize = true
    return
  end

  if string.find(en, "[А-Яа-яІіЇїЄєҐґ]") or string.find(en, "[89]") then return end
  local ua = LookupName(en)
  if ua then
    fs:SetText(FormatName(ua, en))
    tip._OceUA_NeedResize = true
  end
end

local function TranslateTipLines(tip)
  if not Enabled() then return end
  if not tip or not tip.GetName then return end
  local tipName = tip:GetName()
  if not tipName then return end

  local i
  for i = 1, 30 do
    local fs = getglobal(tipName .. "TextLeft" .. i)
    if fs then
      local text = fs:GetText()
      if text and text ~= "" then
        local stripped = StripCodes(text)
        stripped = NormApos(stripped)
        -- 1) pet
        local ua = TranslatePetOwnerLine(stripped)
        -- 2) Level / раса / клас
        if not ua then ua = TranslateLevelish(stripped) end
        -- 3) FIXED (Player, Active Challenges:, тощо)
        if not ua then ua = FIXED[stripped] end
        -- 4) challenges + імена
        if not ua then ua = LookupName(stripped) end
        -- 5) challenges exact (на випадок іншого регістру)
        if not ua and OceUA_challenges then
          ua = OceUA_challenges[stripped] or OceUA_challenges[text]
        end
        if ua and ua ~= text and ua ~= stripped then
          fs:SetText(ua)
          tip._OceUA_NeedResize = true
        end
      end
    end
  end
end

local function StylePlayerTipColors(tip)
  if not tip or not tip.GetName then return end
  local tipName = tip:GetName()
  if not tipName then return end
  local isPlayer = false
  local i
  for i = 1, 10 do
    local fs = getglobal(tipName .. "TextLeft" .. i)
    if fs then
      local t = fs:GetText() or ""
      if string.find(t, "%(Гравець%)") or string.find(t, "%(Player%)")
          or t == "Гравець" or t == "Player"
          or string.find(t, "Рівень .*Гравець") or string.find(t, "Level .*Player") then
        isPlayer = true
      end
    end
  end
  if not isPlayer then return end
  -- нік завжди білий
  local fs1 = getglobal(tipName .. "TextLeft1")
  if fs1 and fs1.SetTextColor then
    fs1:SetTextColor(1, 1, 1)
  end
  -- PvP — помаранчевий
  for i = 1, 10 do
    local fs = getglobal(tipName .. "TextLeft" .. i)
    if fs then
      local t = fs:GetText() or ""
      if t == "PvP" or t == "PVP" then
        fs:SetTextColor(1.0, 0.55, 0.15)
      end
    end
  end
end

local function TranslateTip(tip)
  if not tip then return end
  TranslateTipName(tip)
  TranslateTipLines(tip)
  if StylePlayerTipColors then StylePlayerTipColors(tip) end
  -- розтяг рамки під довший UA-текст
  if tip._OceUA_NeedResize then
    tip._OceUA_NeedResize = nil
    if tip.Show and not tip._OceUA_InShow then
      tip._OceUA_InShow = true
      pcall(function() tip:Show() end)
      tip._OceUA_InShow = nil
      -- Show інколи скидає рядки на EN → одразу ще раз перекласти
      TranslateTipName(tip)
      TranslateTipLines(tip)
      if StylePlayerTipColors then StylePlayerTipColors(tip) end
      tip._OceUA_PetPass = 0
    end
  end
end

local function HookMeta(tbl, method, after)
  if not tbl or type(tbl[method]) ~= "function" then return end
  local orig = tbl[method]
  tbl[method] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    local r1, r2, r3, r4 = orig(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    pcall(after, a1)
    return r1, r2, r3, r4
  end
end

local function HookOnShow(tip)
  if not tip or tip._OceUA_UnitHooked then return end
  tip._OceUA_UnitHooked = true
  local old = tip:GetScript("OnShow")
  tip:SetScript("OnShow", function()
    if old then old() end
    if this._OceUA_InShow then return end
    this._OceUA_PetPass = 0
    local isItem = false
    if tip.GetItem then
      local ok, name = pcall(function() return tip:GetItem() end)
      if ok and name then isItem = true end
    end
    if not isItem then
      this._OceUA_Translating = true
      pcall(TranslateTip, tip)
      this._OceUA_Translating = nil
    end
  end)
  local oldUp = tip:GetScript("OnUpdate")
  tip:SetScript("OnUpdate", function()
    if oldUp then oldUp() end
    if not this:IsVisible() then return end
    if this._OceUA_Translating then return end
    local isItem = false
    if this.GetItem then
      local ok, name = pcall(function() return this:GetItem() end)
      if ok and name then isItem = true end
    end
    if isItem then return end

    -- поки є англ. Level / Active Challenges / challenge-імена — перекладаємо щокадру
    local stillEN = false
    local tn = this:GetName()
    if tn then
      local i
      for i = 1, 12 do
        local fs = getglobal(tn .. "TextLeft" .. i)
        local tx = fs and fs:GetText() or ""
        tx = string.gsub(tx, "|c%x%x%x%x%x%x%x%x", "")
        tx = string.gsub(tx, "|r", "")
        if string.sub(tx, 1, 6) == "Level " or string.sub(tx, 1, 8) == "Level ??" then
          stillEN = true
        end
        if tx == "Active Challenges:" or tx == "Active Challenges" then
          stillEN = true
        end
        if OceUA_challenges and OceUA_challenges[tx] then
          -- ключ ще EN (значення UA) → треба підмінити
          if OceUA_challenges[tx] ~= tx then stillEN = true end
        end
      end
    end

    local pass = this._OceUA_PetPass or 0
    -- якщо все вже UA — кілька кадрів «дотиску» і стоп
    if not stillEN then
      if pass >= 8 then return end
    else
      -- EN ще є — крутимо довше
      if pass >= 40 then return end
    end
    this._OceUA_PetPass = pass + 1
    this._OceUA_Translating = true
    pcall(TranslateTip, this)
    this._OceUA_Translating = nil
  end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  if GameTooltip then
    HookMeta(GameTooltip, "SetUnit", function(self)
      pcall(TranslateTip, self)
    end)
    HookOnShow(GameTooltip)
  end
  if ItemRefTooltip then
    HookOnShow(ItemRefTooltip)
  end
end)


-- ============================================================
-- Назви зон / субзон на екрані (ZoneTextFrame) + під мінімапою
-- Легко: лише кілька FontString, без обходу UI
-- ============================================================
-- Єдине джерело назв зон: спочатку Zones_Dictionary, Signs — лише якщо немає в Zones
-- UI-рядки самої рамки мапи (не зони)
local MAP_UI_UA = {
  ["Continent"] = "Континент",
  ["World Zone"] = "Зона світу",
  ["Zoom Out"] = "Віддалити",
  ["Right Click On Map To Zoom Out"] = "ПКМ по мапі, щоб віддалити",
  ["Eastern Kingdoms"] = "Східні королівства",
  ["Kalimdor"] = "Калімдор",
}

-- lower→UA кеш (для ELWYNN FOREST / Gold Coast Quarry з іншим регістром)
local zoneLowerUA = nil
local function BuildZoneLowerCache()
  zoneLowerUA = {}
  local function add(d)
    if not d then return end
    local k, v
    for k, v in pairs(d) do
      if type(k) == "string" and type(v) == "string" and v ~= "" and v ~= k then
        zoneLowerUA[string.lower(k)] = v
      end
    end
  end
  add(OceUA_Zones_Dictionary)
  add(OceUA_Signs_Dictionary)
end

local function ZoneLookup(en)
  if not en or en == "" then return nil end
  if MAP_UI_UA[en] then return MAP_UI_UA[en] end

  local function hit(d, k)
    if not d or not k then return nil end
    local ua = d[k]
    if ua and ua ~= "" and ua ~= k then return ua end
    return nil
  end
  local ua = hit(OceUA_Zones_Dictionary, en)
  if ua then return ua end
  local stripped = string.gsub(en, "^[Tt]he%s+", "")
  if stripped ~= en then
    ua = hit(OceUA_Zones_Dictionary, stripped)
    if ua then return ua end
  end
  if not (OceUA_Zones_Dictionary and (OceUA_Zones_Dictionary[en] or (stripped ~= en and OceUA_Zones_Dictionary[stripped]))) then
    ua = hit(OceUA_Signs_Dictionary, en)
    if ua then return ua end
    if stripped ~= en then
      ua = hit(OceUA_Signs_Dictionary, stripped)
      if ua then return ua end
    end
  end
  -- case-insensitive (ELWYNN FOREST, gold coast quarry)
  if not zoneLowerUA then BuildZoneLowerCache() end
  local low = string.lower(en)
  if zoneLowerUA[low] then return zoneLowerUA[low] end
  local low2 = string.lower(stripped)
  if low2 ~= low and zoneLowerUA[low2] then return zoneLowerUA[low2] end
  return nil
end

local function ZoneFSAlreadyUA(s)
  if not s then return true end
  -- кирилиця (UTF-8 / legacy)
  if string.find(s, "[\208\209]") then return true end
  if string.find(s, "[А-Яа-яІіЇїЄєҐґ]") then return true end
  return false
end

local function TranslateZoneFS(fs)
  if not fs or not fs.GetText or not fs.SetText then return end
  local t = fs:GetText()
  if not t or t == "" then return end
  if ZoneFSAlreadyUA(t) then return end
  local ua = ZoneLookup(t)
  if ua and ua ~= t then
    fs:SetText(ua)
  end
end

local function ApplyZoneScreenText()
  if OceUA_IsEnabled and not OceUA_IsEnabled("world") then return end
  TranslateZoneFS(getglobal("ZoneTextString"))
  TranslateZoneFS(getglobal("SubZoneTextString"))
  TranslateZoneFS(getglobal("PVPinfoTextString"))
  TranslateZoneFS(getglobal("MinimapZoneText"))
end

-- рекурсивний обхід FontString (обмежена глибина) — для WorldMap / Cartographer
local function WalkTranslateZoneFonts(frame, depth)
  if not frame or depth > 6 then return end
  if frame.GetRegions then
    local ok, regs = pcall(function() return { frame:GetRegions() } end)
    if ok and regs then
      local i
      for i = 1, table.getn(regs) do
        local r = regs[i]
        if r and r.GetObjectType then
          local ot = r:GetObjectType()
          if ot == "FontString" then
            TranslateZoneFS(r)
          end
        end
      end
    end
  end
  if frame.GetChildren then
    local ok, kids = pcall(function() return { frame:GetChildren() } end)
    if ok and kids then
      local i
      for i = 1, table.getn(kids) do
        WalkTranslateZoneFonts(kids[i], depth + 1)
      end
    end
  end
end

-- SetText-хук на AreaLabel: клієнт щокадру пише EN → одразу UA
local function HookMapAreaLabelFS(fs)
  if not fs or not fs.SetText or fs._OceUA_MapLabelHook then return end
  fs._OceUA_MapLabelHook = true
  local old = fs.SetText
  fs.SetText = function(self, text)
    if type(text) == "string" and text ~= "" then
      if not ZoneFSAlreadyUA(text) then
        local ua = ZoneLookup(text)
        if ua then text = ua end
      end
    end
    return old(self, text)
  end
end

local function ApplyWorldMapZoneText()
  if OceUA_IsEnabled and not OceUA_IsEnabled("world") then return end
  local names = {
    "WorldMapFrameAreaLabel",
    "WorldMapFrameAreaDescription",
    "WorldMapFrameTitle",
    "WorldMapFrameTitleText",
    "WorldMapZoneDropDownText",
    "WorldMapContinentDropDownText",
    "WorldMapZoneMinimapDropDownText",
    "WorldMapMagnifyingGlassInfo",
  }
  -- підчепити AreaLabel / Description назавжди
  HookMapAreaLabelFS(getglobal("WorldMapFrameAreaLabel"))
  HookMapAreaLabelFS(getglobal("WorldMapFrameAreaDescription"))
  local i
  for i = 1, table.getn(names) do
    TranslateZoneFS(getglobal(names[i]))
  end
  -- dropdown кнопки зон (1.12)
  for i = 1, 30 do
    local btn = getglobal("DropDownList1Button" .. i)
    if btn and btn.GetText then
      local t = btn:GetText()
      if t and t ~= "" and not ZoneFSAlreadyUA(t) then
        local ua = ZoneLookup(t)
        if ua then btn:SetText(ua) end
      end
    end
    btn = getglobal("DropDownList2Button" .. i)
    if btn and btn.GetText then
      local t = btn:GetText()
      if t and t ~= "" and not ZoneFSAlreadyUA(t) then
        local ua = ZoneLookup(t)
        if ua then btn:SetText(ua) end
      end
    end
  end
  -- повний обхід WorldMapFrame
  local wmf = getglobal("WorldMapFrame")
  if wmf and wmf.IsVisible and wmf:IsVisible() then
    WalkTranslateZoneFonts(wmf, 0)
    -- знайти і захукати «великий» підпис зони під курсором (AreaLabel)
    if wmf.GetRegions then
      local regs = { wmf:GetRegions() }
      local ri
      for ri = 1, table.getn(regs) do
        local r = regs[ri]
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then
          HookMapAreaLabelFS(r)
          TranslateZoneFS(r)
        end
      end
    end
  end
  -- Cartographer (Ace2/Ace3) — типові корені
  local cartNames = {
    "CartographerFrame", "Cartographer", "CartographerMap",
    "CartographerNotes", "CartographerLookNFeel", "CartographerCoordinates",
    "Cartographer_LookNFeel", "Cartographer_Coordinates", "Cartographer_Notes",
    "CartographerGoTo_Panel",
  }
  for i = 1, table.getn(cartNames) do
    local fr = getglobal(cartNames[i])
    if fr then WalkTranslateZoneFonts(fr, 0) end
  end
  -- окремі відомі FS
  TranslateZoneFS(getglobal("CartographerLookNFeelOverlayLocationText"))
  TranslateZoneFS(getglobal("CartographerCoordinatesText"))
  TranslateZoneFS(getglobal("Cartographer_CoordinatesText"))
  TranslateZoneFS(getglobal("CartographerLocationText"))
end

-- throttle: ZONE_CHANGED інколи летить пачкою
local zonePend = false
local zoneTh = CreateFrame("Frame")
zoneTh:Hide()
zoneTh:SetScript("OnUpdate", function()
  this.t = (this.t or 0) + (arg1 or 0)
  if this.t < 0.05 then return end
  this.t = 0
  this:Hide()
  if zonePend then
    zonePend = false
    pcall(ApplyZoneScreenText)
    pcall(ApplyWorldMapZoneText)
  end
end)

local function ScheduleZoneScreenText()
  zonePend = true
  zoneTh.t = 0
  zoneTh:Show()
end

local zoneEv = CreateFrame("Frame")
zoneEv:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneEv:RegisterEvent("ZONE_CHANGED")
zoneEv:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneEv:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneEv:SetScript("OnEvent", function()
  ScheduleZoneScreenText()
end)

local function HookZoneTextFrame(name)
  local fr = getglobal(name)
  if not fr or fr._OceUA_ZoneHooked then return end
  fr._OceUA_ZoneHooked = true
  local old = fr:GetScript("OnShow")
  fr:SetScript("OnShow", function()
    if old then old() end
    pcall(ApplyZoneScreenText)
  end)
end

if type(Minimap_Update) == "function" and not OceUA_MinimapUpdateHooked then
  OceUA_MinimapUpdateHooked = true
  local oldMU = Minimap_Update
  Minimap_Update = function(a1, a2, a3, a4)
    oldMU(a1, a2, a3, a4)
    TranslateZoneFS(getglobal("MinimapZoneText"))
  end
end

-- поки відкрита мапа — періодично підставляти UA (Cartographer часто пише EN знову)
local mapWatch = CreateFrame("Frame")
mapWatch:Hide()
mapWatch.acc = 0
mapWatch:SetScript("OnUpdate", function()
  local wmf = getglobal("WorldMapFrame")
  if not wmf or not wmf.IsVisible or not wmf:IsVisible() then
    this:Hide()
    this.acc = 0
    return
  end
  this.acc = this.acc + (arg1 or 0)
  if this.acc < 0.08 then return end
  this.acc = 0
  pcall(ApplyWorldMapZoneText)
end)

local function HookWorldMapZones()
  if OceUA_WorldMapZoneHooked then return end
  OceUA_WorldMapZoneHooked = true
  local wmf = getglobal("WorldMapFrame")
  if wmf then
    local old = wmf:GetScript("OnShow")
    wmf:SetScript("OnShow", function()
      if old then old() end
      ScheduleZoneScreenText()
      mapWatch.acc = 0
      mapWatch:Show()
      pcall(ApplyWorldMapZoneText)
    end)
    local oldHide = wmf:GetScript("OnHide")
    wmf:SetScript("OnHide", function()
      if oldHide then oldHide() end
      mapWatch:Hide()
    end)
  end
  -- ванільні оновлення
  local hooks = {
    "WorldMapFrame_Update",
    "WorldMapFrame_UpdateZones",
    "WorldMapContinents_Update",
    "WorldMapFrame_SetMapName",
    "WorldMapZoneDropDown_Update",
    "WorldMapContinentDropDown_Update",
  }
  local hi
  for hi = 1, table.getn(hooks) do
    local fname = hooks[hi]
    if type(getglobal(fname)) == "function" then
      local key = "_OceUA_" .. fname
      if not getglobal(key) then
        setglobal(key, true)
        local oldF = getglobal(fname)
        setglobal(fname, function(a1, a2, a3, a4, a5, a6)
          oldF(a1, a2, a3, a4, a5, a6)
          pcall(ApplyWorldMapZoneText)
        end)
      end
    end
  end
end

local zoneBoot = CreateFrame("Frame")
zoneBoot:RegisterEvent("PLAYER_LOGIN")
zoneBoot:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneBoot:RegisterEvent("WORLD_MAP_UPDATE")
zoneBoot:SetScript("OnEvent", function()
  HookZoneTextFrame("ZoneTextFrame")
  HookZoneTextFrame("SubZoneTextFrame")
  HookWorldMapZones()
  ScheduleZoneScreenText()
  local wmf = getglobal("WorldMapFrame")
  if wmf and wmf.IsVisible and wmf:IsVisible() then
    mapWatch:Show()
    pcall(ApplyWorldMapZoneText)
  end
end)

OceUA_ApplyZoneScreenText = ApplyZoneScreenText
OceUA_ApplyWorldMapZoneText = ApplyWorldMapZoneText
OceUA_TranslateZoneName = function(en)
  local ua = ZoneLookup(en)
  if ua then return ua end
  return en
end

-- ============================================================
-- TaxiFrame: назви точок з OceUA_Zones_Dictionary
-- ============================================================
local function LookupZoneUA(en)
  if not en or en == "" then return nil end
  en = string.gsub(en, "^%s+", "")
  en = string.gsub(en, "%s+$", "")
  local function one(key)
    if not key or key == "" then return nil end
    if OceUA_Zones_Dictionary and OceUA_Zones_Dictionary[key] and OceUA_Zones_Dictionary[key] ~= "" and OceUA_Zones_Dictionary[key] ~= key then
      return OceUA_Zones_Dictionary[key]
    end
    if OceUA_Signs_Dictionary and OceUA_Signs_Dictionary[key] and OceUA_Signs_Dictionary[key] ~= "" and OceUA_Signs_Dictionary[key] ~= key then
      return OceUA_Signs_Dictionary[key]
    end
    if OceUA_TranslateZoneName then
      local z = OceUA_TranslateZoneName(key)
      if z and z ~= key then return z end
    end
    return nil
  end
  local ua = one(en)
  if ua then return ua end
  local stripped = string.gsub(en, "^[Tt]he%s+", "")
  if stripped ~= en then
    ua = one(stripped)
    if ua then return ua end
  end
  -- "Sentinel Hill, Westfall" / "Stormwind City, Elwynn Forest"
  local _, _, a, b = string.find(en, "^(.+),%s*(.+)$")
  if a and b then
    local ua1 = one(a) or a
    local ua2 = one(b) or b
    if ua1 ~= a or ua2 ~= b then
      return ua1 .. ", " .. ua2
    end
  end
  return nil
end

local function TranslateTaxiTip()
  if not GameTooltip or not GameTooltip:IsVisible() then return end
  local tn = GameTooltip:GetName()
  if not tn then return end
  local changed = false
  local i
  for i = 1, 6 do
    local fs = getglobal(tn .. "TextLeft" .. i)
    if fs then
      local tx = fs:GetText()
      if tx and tx ~= "" then
        local plain = string.gsub(tx, "|c%x%x%x%x%x%x%x%x", "")
        plain = string.gsub(plain, "|r", "")
        plain = string.gsub(plain, "^%s+", "")
        plain = string.gsub(plain, "%s+$", "")
        -- не чіпати вартість / вже UA
        local low = string.lower(plain)
        if string.find(low, "^cost") or string.find(low, "^estimated") then
          -- skip
        elseif string.find(plain, "[\208\209]") or string.find(plain, "[А-Яа-яІіЇїЄєҐґ]") then
          -- already UA
        else
          local ua = LookupZoneUA(plain)
          if ua then
            fs:SetText(ua)
            changed = true
          end
        end
      end
    end
  end
  if changed then GameTooltip:Show() end
end

local function HookTaxiButton(btn)
  if not btn or btn._OceUA_TaxiEnter then return end
  btn._OceUA_TaxiEnter = true
  local old = btn:GetScript("OnEnter")
  btn:SetScript("OnEnter", function()
    if old then old() end
    -- після стандартного тултіпа
    pcall(TranslateTaxiTip)
  end)
end

local function HookAllTaxiButtons()
  local n = 0
  if NumTaxiNodes then n = NumTaxiNodes() or 0 end
  if n < 1 then n = 40 end
  local i
  for i = 1, n do
    HookTaxiButton(getglobal("TaxiButton" .. i))
  end
end

local function HookTaxiNodeEnter()
  if type(TaxiNodeOnButtonEnter) == "function" and not OceUA_TaxiNodeFnHooked then
    OceUA_TaxiNodeFnHooked = true
    local old = TaxiNodeOnButtonEnter
    TaxiNodeOnButtonEnter = function(button)
      old(button)
      -- напряму з API клієнта (надійніше, ніж лише читати тултіп)
      local id = button and button.GetID and button:GetID() or nil
      local name = (id and TaxiNodeName) and TaxiNodeName(id) or nil
      if name and name ~= "" then
        local ua = LookupZoneUA(name)
        if ua then
          local fs = getglobal("GameTooltipTextLeft1")
          if fs and fs.SetText then
            fs:SetText(ua)
            if GameTooltip and GameTooltip.Show then GameTooltip:Show() end
          end
        end
      else
        pcall(TranslateTaxiTip)
      end
    end
  end
end

-- поки відкрита карта польотів — підстрахувати тултіп
local taxiWatch = CreateFrame("Frame")
taxiWatch:Hide()
taxiWatch.t = 0
taxiWatch:SetScript("OnUpdate", function()
  this.t = this.t + (arg1 or 0)
  if this.t < 0.15 then return end
  this.t = 0
  if not (TaxiFrame and TaxiFrame:IsVisible()) then
    this:Hide()
    return
  end
  if GameTooltip and GameTooltip:IsVisible() then
    pcall(TranslateTaxiTip)
  end
end)

local taxiBoot = CreateFrame("Frame")
taxiBoot:RegisterEvent("PLAYER_LOGIN")
taxiBoot:RegisterEvent("TAXIMAP_OPENED")
taxiBoot:RegisterEvent("TAXIMAP_CLOSED")
taxiBoot:SetScript("OnEvent", function()
  if event == "TAXIMAP_CLOSED" then
    taxiWatch:Hide()
    return
  end
  HookTaxiNodeEnter()
  HookAllTaxiButtons()
  if event == "TAXIMAP_OPENED" then
    taxiWatch.t = 0
    taxiWatch:Show()
  end
end)

-- експорт для OceTip (AddLine під час таксі)
OceUA_LookupZoneUA = LookupZoneUA
OceUA_TranslateTaxiTip = TranslateTaxiTip


-- ============================================================
-- Екранні повідомлення (RaidWarning тощо) — ті ж словники
-- ============================================================
local function TranslateScreenMsg(msg)
  if not msg or msg == "" then return msg end
  if string.find(msg, "[\208\209]") or string.find(msg, "[А-Яа-яІіЇїЄєҐґ]") then return msg end
  -- не чіпати чисті числа / шкоду
  if string.find(msg, "^[%d%s%+%-%.]+$") then return msg end
  if OceUA_LookupZoneUA then
    local z = OceUA_LookupZoneUA(msg)
    if z then return z end
  end
  if ZoneLookup then
    local z = ZoneLookup(msg)
    if z and z ~= msg then return z end
  end
  if OceUA_World_Names and OceUA_World_Names[msg] then return OceUA_World_Names[msg] end
  if OceUA_NPC_Names and OceUA_NPC_Names[msg] then return OceUA_NPC_Names[msg] end
  if OceUA_ITEM_DICT and OceUA_ITEM_DICT[msg] then return OceUA_ITEM_DICT[msg] end
  if OceUA_Skill_Dictionary and OceUA_Skill_Dictionary[msg] then return OceUA_Skill_Dictionary[msg] end
  return msg
end

local function HookAddMessageFrame(fr)
  if not fr or fr._OceUA_MsgHooked or not fr.AddMessage then return end
  fr._OceUA_MsgHooked = true
  local old = fr.AddMessage
  fr.AddMessage = function(self, msg, r, g, b, a)
    if type(msg) == "string" then
      msg = TranslateScreenMsg(msg)
    end
    if old then
      return old(self, msg, r, g, b, a)
    end
  end
end

local screenBoot = CreateFrame("Frame")
screenBoot:RegisterEvent("PLAYER_LOGIN")
screenBoot:SetScript("OnEvent", function()
  HookAddMessageFrame(getglobal("RaidWarningFrame"))
  HookAddMessageFrame(getglobal("RaidBossEmoteFrame"))
end)
