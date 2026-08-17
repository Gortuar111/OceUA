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
  local d
  -- спочатку Mobs (бойові), потім NPC — один канонічний переклад
  d = OceUA_Mobs_Dictionary
  if d and d[en] and d[en] ~= "" then return d[en] end
  d = OceUA_NPC_Names_Dictionary
  if d and d[en] and d[en] ~= "" then return d[en] end
  d = OceUA_Objects_Dictionary
  if d and d[en] and d[en] ~= "" then return d[en] end
  d = OceUA_Signs_Dictionary
  if d and d[en] and d[en] ~= "" then return d[en] end
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
  if string.find(text, "[А-Яа-яІіЇїЄєҐґ]") then return nil end

  if FIXED[text] then return FIXED[text] end

  local pet = TranslatePetOwnerLine(text)
  if pet then return pet end

  local t = NormApos(text)
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

  local pet = TranslatePetOwnerLine(en)
  if pet then
    fs:SetText(pet)
    tip:Show()
    return
  end

  if string.find(en, "[А-Яа-яІіЇїЄєҐґ]") then return end
  local ua = LookupName(en)
  if ua then
    fs:SetText(FormatName(ua, en))
    tip:Show()
  end
end

local function TranslateTipLines(tip)
  if not Enabled() then return end
  if not tip or not tip.GetName then return end
  local tipName = tip:GetName()
  if not tipName then return end

  local changed = false
  local i
  for i = 1, 20 do
    local fs = getglobal(tipName .. "TextLeft" .. i)
    if fs then
      local text = fs:GetText()
      if text and text ~= "" then
        -- pet/minion може бути не лише в рядку 1
        local pet = TranslatePetOwnerLine(text)
        local ua = pet or TranslateLevelish(text)
        if ua and ua ~= text then
          fs:SetText(ua)
          changed = true
        end
      end
    end
  end
  if changed then tip:Show() end
end

local function TranslateTip(tip)
  TranslateTipName(tip)
  TranslateTipLines(tip)
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
    this._OceUA_PetPass = 0
    local isItem = false
    if tip.GetItem then
      local ok, name = pcall(function() return tip:GetItem() end)
      if ok and name then isItem = true end
    end
    if not isItem then
      pcall(TranslateTip, tip)
    end
  end)
  local oldUp = tip:GetScript("OnUpdate")
  tip:SetScript("OnUpdate", function()
    if oldUp then oldUp() end
    if not this:IsVisible() then return end
    local pass = this._OceUA_PetPass or 0
    if pass >= 5 then return end
    this._OceUA_PetPass = pass + 1
    local isItem = false
    if this.GetItem then
      local ok, name = pcall(function() return this:GetItem() end)
      if ok and name then isItem = true end
    end
    if not isItem then
      pcall(TranslateTip, this)
    end
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
