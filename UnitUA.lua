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
  if string.find(text, "[А-Яа-яІіЇїЄєҐґ]") or string.find(text, "[89]") then return nil end

  if FIXED[text] then return FIXED[text] end

  local pet = TranslatePetOwnerLine(text)
  if pet then return pet end

  local t = text
  t = string.gsub(t, "%(Player%)", "(Гравець)")

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
  -- якщо це тултіп pfQuest ([!]/[?]) — лише OceTip
  local fs1 = getglobal(tipName .. "TextLeft1")
  if fs1 then
    local t1 = fs1:GetText() or ""
    if string.find(t1, "%[!%]") or string.find(t1, "%[%?%]") then return end
  end

  local i
  for i = 1, 12 do
    local fs = getglobal(tipName .. "TextLeft" .. i)
    if fs then
      local text = fs:GetText()
      if text and text ~= "" then
        -- квестові рядки pfQuest — тільки OceTip (без другого проходу = без блимання)
        if string.find(text, "%[!%]") or string.find(text, "%[%?%]") then
          -- skip
        elseif string.find(text, "%[%d+%.?%d*%%%]") then
          -- прибрати [37%] якщо раптом лишилось
          local cleaned = string.gsub(text, "%s*%[%s*%d+%.?%d*%s*%%%s*%]", "")
          if cleaned ~= text then fs:SetText(cleaned); tip._OceUA_NeedResize = true end
        elseif string.find(text, "[А-Яа-яІіЇїЄєҐґ]") or string.find(text, "[89]") then
          -- вже UA
        else
          local pet = TranslatePetOwnerLine(text)
          local ua = pet or TranslateLevelish(text)
          if not ua then
            ua = FIXED[text] or LookupName(text)
          end
          if ua and ua ~= text then
            fs:SetText(ua)
            tip._OceUA_NeedResize = true
          end
        end
      end
    end
  end
end

local function TranslateTip(tip)
  if not tip then return end
  TranslateTipName(tip)
  TranslateTipLines(tip)
  -- після довших рядків (UA + EN) — один Show, щоб рамка підлаштувалась
  if tip._OceUA_NeedResize then
    tip._OceUA_NeedResize = nil
    if tip.Show and not tip._OceUA_InShow then
      tip._OceUA_InShow = true
      pcall(function() tip:Show() end)
      tip._OceUA_InShow = nil
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
    local pass = this._OceUA_PetPass or 0
    if pass >= 5 then return end
    this._OceUA_PetPass = pass + 1
    local isItem = false
    if this.GetItem then
      local ok, name = pcall(function() return this:GetItem() end)
      if ok and name then isItem = true end
    end
    if isItem then return end
    -- ще раз лише якщо Level досі англійською (текст інколи з’являється пізніше)
    local stillEN = false
    local tn = this:GetName()
    if tn then
      local i
      for i = 1, 4 do
        local fs = getglobal(tn .. "TextLeft" .. i)
        local tx = fs and fs:GetText() or ""
        tx = string.gsub(tx, "|c%x%x%x%x%x%x%x%x", "")
        tx = string.gsub(tx, "|r", "")
        if string.sub(tx, 1, 6) == "Level " or string.sub(tx, 1, 8) == "Level ??" then
          stillEN = true
          break
        end
      end
    end
    if pass > 0 and not stillEN then
      this._OceUA_PetPass = 99
      return
    end
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
local function ZoneLookup(en)
  if not en or en == "" then return nil end
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
  -- Signs_Zone: лише якщо цієї EN-назви НЕМАЄ в Zones (уникаємо дублікатів)
  if not (OceUA_Zones_Dictionary and (OceUA_Zones_Dictionary[en] or (stripped ~= en and OceUA_Zones_Dictionary[stripped]))) then
    ua = hit(OceUA_Signs_Dictionary, en)
    if ua then return ua end
    if stripped ~= en then
      ua = hit(OceUA_Signs_Dictionary, stripped)
      if ua then return ua end
    end
  end
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
  -- великий текст при вході в зону / субзону
  TranslateZoneFS(getglobal("ZoneTextString"))
  TranslateZoneFS(getglobal("SubZoneTextString"))
  TranslateZoneFS(getglobal("PVPinfoTextString"))
  -- постійний рядок під мінімапою
  TranslateZoneFS(getglobal("MinimapZoneText"))
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

-- коли клієнт показує ZoneTextFrame — перебити EN одразу в тому ж кадрі
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

-- Minimap_Update скидає MinimapZoneText на EN
if type(Minimap_Update) == "function" and not OceUA_MinimapUpdateHooked then
  OceUA_MinimapUpdateHooked = true
  local oldMU = Minimap_Update
  Minimap_Update = function(a1, a2, a3, a4)
    oldMU(a1, a2, a3, a4)
    TranslateZoneFS(getglobal("MinimapZoneText"))
  end
end

local zoneBoot = CreateFrame("Frame")
zoneBoot:RegisterEvent("PLAYER_LOGIN")
zoneBoot:SetScript("OnEvent", function()
  HookZoneTextFrame("ZoneTextFrame")
  HookZoneTextFrame("SubZoneTextFrame")
  ScheduleZoneScreenText()
end)

-- експорт для інших модулів
OceUA_ApplyZoneScreenText = ApplyZoneScreenText
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
  fr.AddMessage = function(self, msg, r, g, b, a, ...)
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
  HookAddMessageFrame(getglobal("CombatText"))
  HookAddMessageFrame(getglobal("FloatingCombatText"))
end)





-- ============================================================
-- Combat feedback: ВЛАСНИЙ анімований текст (не клієнтський)
-- База: Data/Combat_Feedback.lua → OceUA_Combat_Feedback
-- ============================================================

local function CombatLookup(text)
  if not text or text == "" then return nil end
  local db = OceUA_Combat_Feedback
  if not db then return nil end
  if db[text] then return db[text] end
  local up = string.upper(text)
  if db[up] then return db[up] end
  local _, _, head, rest = string.find(text, "^([%a]+)%s*(.*)$")
  if head then
    local ua = db[head] or db[string.upper(head)]
    if ua then
      rest = string.gsub(rest or "", "^%s+", "")
      if rest ~= "" then return ua .. " " .. rest end
      return ua
    end
  end
  return nil
end

-- пул рухомих написів
local OCE_FB_MAX = 8
local oceFbPool = {}
local oceFbIdx = 0

local function OceFbAcquire()
  local i
  for i = 1, OCE_FB_MAX do
    local f = oceFbPool[i]
    if f and not f.active then return f end
  end
  oceFbIdx = oceFbIdx + 1
  if oceFbIdx > OCE_FB_MAX then oceFbIdx = 1 end
  local f = oceFbPool[oceFbIdx]
  if not f then
    f = CreateFrame("Frame", "OceUA_CombatFB" .. oceFbIdx, UIParent)
    f:SetWidth(200)
    f:SetHeight(24)
    f:SetFrameStrata("HIGH")
    f.fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.fs:SetPoint("CENTER", f, "CENTER")
    f.fs:SetJustifyH("CENTER")
    f:SetScript("OnUpdate", function()
      if not this.active then return end
      local dt = arg1 or 0
      this.t = (this.t or 0) + dt
      local y = (this.baseY or 0) + this.t * 40
      this:SetPoint("CENTER", UIParent, "CENTER", this.baseX or 0, y)
      local a = 1
      if this.t > 0.9 then
        a = 1 - (this.t - 0.9) / 0.5
        if a < 0 then a = 0 end
      end
      this:SetAlpha(a)
      if this.t >= 1.4 then
        this.active = false
        this:Hide()
      end
    end)
    oceFbPool[oceFbIdx] = f
  end
  return f
end

local function OceFbShow(text, r, g, b, anchorFrame)
  if not text or text == "" then return end
  local f = OceFbAcquire()
  if not f then return end
  f.active = true
  f.t = 0
  f.fs:SetText(text)
  f.fs:SetTextColor(r or 1, g or 0.82, b or 0)
  -- позиція біля unit frame або центр
  local ax, ay = 0, 80
  if anchorFrame and anchorFrame.GetCenter then
    local ok, x, y = pcall(function() return anchorFrame:GetCenter() end)
    if ok and x and y then
      local ux, uy = UIParent:GetCenter()
      ax = x - (ux or 0)
      ay = y - (uy or 0) + 20
    end
  end
  f.baseX = ax
  f.baseY = ay
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", ax, ay)
  f:SetAlpha(1)
  f:Show()
end

local function HideBlizzardFeedback(frame)
  if not frame then return end
  if frame.feedbackText then
    frame.feedbackText:SetText("")
    if frame.feedbackText.SetAlpha then frame.feedbackText:SetAlpha(0) end
  end
end

local function HideHitIndicators()
  local names = { "PlayerHitIndicator", "PetHitIndicator", "TargetHitIndicator" }
  local i
  for i = 1, 3 do
    local fs = getglobal(names[i])
    if fs then
      if fs.SetText then fs:SetText("") end
      if fs.SetAlpha then fs:SetAlpha(0) end
    end
  end
end

-- колір за типом події
local function CombatColor(ev)
  ev = string.upper(tostring(ev or ""))
  if ev == "HEAL" or ev == "ENERGIZE" then return 0.1, 1, 0.1 end
  if ev == "MISS" or ev == "DODGE" or ev == "PARRY" or ev == "BLOCK" or ev == "EVADE" then
    return 1, 1, 1
  end
  if ev == "IMMUNE" or ev == "RESIST" or ev == "ABSORB" or ev == "DEFLECT" or ev == "REFLECT" then
    return 0.7, 0.7, 1
  end
  if ev == "INTERRUPT" then return 1, 0.5, 0 end
  return 1, 0.2, 0.2
end

local function EventToUA(event, flags, amount)
  local db = OceUA_Combat_Feedback
  local parts = {}
  local function add(en)
    if not en or en == "" then return end
    local ua = CombatLookup(en) or (db and (db[en] or db[string.upper(en)])) or en
    parts[table.getn(parts) + 1] = ua
  end
  event = tostring(event or "")
  flags = tostring(flags or "")
  -- слово події (MISS/DODGE/…)
  if event ~= "" and event ~= "WOUND" and event ~= "HEAL" and event ~= "ENERGIZE" then
    add(event)
  end
  -- CRITICAL / CRUSHING / GLANCING / ABSORB на WOUND
  if flags ~= "" and flags ~= "nil" then
    add(flags)
  end
  -- число шкоди (якщо є) — лишаємо як є
  local num = tonumber(amount)
  if num and num > 0 then
    parts[table.getn(parts) + 1] = tostring(num)
  end
  if table.getn(parts) == 0 then
    if event ~= "" then add(event) end
  end
  if table.getn(parts) == 0 then return nil end
  local out = parts[1]
  local i
  for i = 2, table.getn(parts) do
    out = out .. " " .. parts[i]
  end
  return out
end

local function ShowFromCombatEvent(event, flags, amount, unit)
  local text = EventToUA(event, flags, amount)
  if not text then return end
  -- якщо вийшов лише чистий EN без перекладу і це не число — все одно показати (з бази або EN)
  local r, g, b = CombatColor(event)
  if flags and string.upper(tostring(flags)) == "CRITICAL" then
    r, g, b = 1, 1, 0.2
  end
  local anchor = nil
  unit = unit or "player"
  if unit == "player" then anchor = getglobal("PlayerFrame")
  elseif unit == "target" then anchor = getglobal("TargetFrame")
  elseif unit == "pet" then anchor = getglobal("PetFrame")
  end
  OceFbShow(text, r, g, b, anchor)
  HideBlizzardFeedback(anchor)
  HideHitIndicators()
end

local function HookCombatFeedback()
  if type(CombatFeedback_OnCombatEvent) == "function" and not OceUA_CombatFbHooked then
    OceUA_CombatFbHooked = true
    local old = CombatFeedback_OnCombatEvent
    CombatFeedback_OnCombatEvent = function(event, flags, amount, school)
      -- сховаємо бліizzard-текст і покажемо свій
      local unit = "player"
      if this and this.GetName then
        local n = this:GetName() or ""
        if string.find(n, "Target") then unit = "target"
        elseif string.find(n, "Pet") then unit = "pet"
        end
      end
      ShowFromCombatEvent(event, flags, amount, unit)
      -- оригінал теж викличемо, але одразу зітремо текст
      old(event, flags, amount, school)
      if type(this) == "table" then HideBlizzardFeedback(this) end
      HideHitIndicators()
    end
  end
end

local combatEv = CreateFrame("Frame")
combatEv:RegisterEvent("PLAYER_LOGIN")
combatEv:RegisterEvent("PLAYER_ENTERING_WORLD")
combatEv:RegisterEvent("UNIT_COMBAT")
combatEv:SetScript("OnEvent", function()
  if event == "UNIT_COMBAT" then
    -- arg1=unit, arg2=action, arg3=descriptor, arg4=damage, arg5=damageSchool
    local unit = arg1
    local action = arg2
    local desc = arg3
    local dmg = arg4
    if unit == "player" or unit == "target" or unit == "pet" then
      ShowFromCombatEvent(action, desc, dmg, unit)
    end
  else
    HookCombatFeedback()
  end
end)
HookCombatFeedback()
