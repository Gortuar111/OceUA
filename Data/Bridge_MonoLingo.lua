--[[
  OceUA — Bridge MonoLingo → OceUA table names
  Вантажити ПІСЛЯ всіх Data/* і ПЕРЕД SkillUA.
  Зливає нові таблиці Mono в імена, які читає SkillUA 1.3.8/1.4.4.
]]

local function mergeInto(dst, src)
  -- FILL-ONLY: ніколи не перетирає вже наявний ключ у dst.
  -- Інакше правки/видалення в основному файлі відкатувались
  -- зі «вторинних» таблиць (ProfessionMisc, ItemTooltipModules тощо).
  if type(dst) ~= "table" then return end
  if type(src) ~= "table" then return end
  local k, v
  for k, v in pairs(src) do
    if v ~= nil and v ~= "" then
      local cur = dst[k]
      if cur == nil or cur == "" then
        dst[k] = v
      end
    end
  end
end

local function ensure(t)
  if type(t) == "table" then return t end
  return {}
end

-- Item tooltip (Mono names → OceUA_ITEM_*)
OceUA_ITEM_STAT  = ensure(OceUA_ITEM_STAT)
OceUA_ITEM_EQUIP = ensure(OceUA_ITEM_EQUIP)
OceUA_ITEM_TYPE  = ensure(OceUA_ITEM_TYPE)
OceUA_ITEM_FIXED = ensure(OceUA_ITEM_FIXED)
OceUA_ITEM_TEMP  = ensure(OceUA_ITEM_TEMP)
OceUA_ITEM_TOOL  = ensure(OceUA_ITEM_TOOL)
OceUA_ITEM_CLASS = ensure(OceUA_ITEM_CLASS)
OceUA_ITEM_RACE  = ensure(OceUA_ITEM_RACE)
OceUA_ITEM_PROF  = ensure(OceUA_ITEM_PROF)

mergeInto(OceUA_ITEM_STAT,  OceUA_Item_Stats)
mergeInto(OceUA_ITEM_EQUIP, OceUA_Item_Equip_Slots)
mergeInto(OceUA_ITEM_TYPE,  OceUA_Item_Types)
mergeInto(OceUA_ITEM_FIXED, OceUA_Item_Fixed_Labels)
mergeInto(OceUA_ITEM_TEMP,  OceUA_Item_Enchants_Temp)
mergeInto(OceUA_ITEM_TOOL,  OceUA_Tool_Names)

mergeInto(OceUA_ITEM_FIXED, OceUA_Item_Stance_Requirements)
mergeInto(OceUA_ITEM_FIXED, OceUA_Consumable_Descriptions)
mergeInto(OceUA_ITEM_FIXED, OceUA_Flavor_Text)
mergeInto(OceUA_ITEM_FIXED, OceUA_Misc_Tooltip_Lines)
mergeInto(OceUA_ITEM_FIXED, OceUA_Tooltip_UI_Strings)
mergeInto(OceUA_ITEM_FIXED, OceUA_Junk_Test_Entries)

mergeInto(OceUA_ITEM_CLASS, OceUA_Class_Names)
mergeInto(OceUA_ITEM_RACE,  OceUA_Race_Names)

OceUA_tooltip_extras = ensure(OceUA_tooltip_extras)
mergeInto(OceUA_tooltip_extras, OceUA_Class_Labels_Full)
mergeInto(OceUA_tooltip_extras, OceUA_Profession_Names)
mergeInto(OceUA_tooltip_extras, OceUA_Profession_Level_Requirements)
mergeInto(OceUA_tooltip_extras, OceUA_SKILL_LINES)
mergeInto(OceUA_tooltip_extras, OceUA_Unsorted_Dictionary)

OceUA_ITEM_TALENT_TREE = ensure(OceUA_ITEM_TALENT_TREE)
OceUA_ITEM_TALENT_NAME = ensure(OceUA_ITEM_TALENT_NAME)
mergeInto(OceUA_ITEM_TALENT_TREE, OceUA_Talent_Trees)
mergeInto(OceUA_ITEM_TALENT_NAME, OceUA_Talent_Names)

OceUA_profession_ranks = ensure(OceUA_profession_ranks)
OceUA_pet_teach        = ensure(OceUA_pet_teach)
OceUA_holiday          = ensure(OceUA_holiday)
OceUA_challenges       = ensure(OceUA_challenges)

-- Profession_Ranks / Pet_Skills навмисно порожні (див. ProfessionMisc/*.lua).
-- Раніше mergeInto перетирав правки з SkillModules/professions.lua —
-- видалені/змінені ключі знову з'являлися зі старих таблиць.
-- Тепер єдине джерело: Data/SkillModules/professions.lua
mergeInto(OceUA_profession_ranks, OceUA_Profession_Ranks)
mergeInto(OceUA_pet_teach,        OceUA_Pet_Skills)
mergeInto(OceUA_holiday,          OceUA_holiday)
mergeInto(OceUA_challenges,       OceUA_challenges)
mergeInto(OceUA_ITEM_PROF,        OceUA_Profession_Names)


-- ============================================================
-- Alias: сучасні дані = OceUA_Items_Dictionary, код 3.0.0 = OceUA_Item_Dictionary
-- без цього назви предметів/рецептів у тултіпах і журналі квестів не підхоплюються
-- ============================================================
if type(OceUA_Items_Dictionary) == "table" and type(OceUA_Item_Dictionary) ~= "table" then
  OceUA_Item_Dictionary = OceUA_Items_Dictionary
elseif type(OceUA_Item_Dictionary) == "table" and type(OceUA_Items_Dictionary) ~= "table" then
  OceUA_Items_Dictionary = OceUA_Item_Dictionary
elseif type(OceUA_Items_Dictionary) == "table" and type(OceUA_Item_Dictionary) == "table" then
  -- обидві є: злити fill-only в Item_Dictionary (основна для SkillUA)
  for k, v in pairs(OceUA_Items_Dictionary) do
    if OceUA_Item_Dictionary[k] == nil then
      OceUA_Item_Dictionary[k] = v
    end
  end
end

