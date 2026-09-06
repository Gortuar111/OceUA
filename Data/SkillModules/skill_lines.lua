--[[
  OceUA — skill_lines
  ============================================================
  Короткі рядки тултіпа скіла (повний точний збіг).

  СЮДИ: Instant, Passive, Next melee, Reagents… — БЕЗ цифр.
  З цифрами (30 yd range, 4.80% chance to parry, Rank 3/5)
  уже в КОДІ SkillUA.lua — не дублюй.

  Після правок: /reload
]]

OceUA_SKILL_LINES = {
  -- час / тип застосування
  ["Instant"] = "Миттєво",
  ["Instant cast"] = "Миттєве",
  ["Next melee"] = "Наступна атака ближнього бою",
  ["Next Melee"] = "Наступна атака ближнього бою",
  ["Channeled"] = "Потокове",
  ["Channelled"] = "Потокове",
  ["Passive"] = "Пасивно",
  ["Until cancelled"] = "Поки не скасовано",
  ["Until Canceled"] = "Поки не скасовано",
  ["Self only"] = "Лише на себе",
  ["Self Only"] = "Лише на себе",

  -- дальність (фіксована, без цифр)
  ["Unlimited range"] = "Необмежена дальність",
  ["Melee Range"] = "Ближній бій",
  ["Melee range"] = "Ближній бій",
  ["Melee"] = "Ближній бій",

  -- реагенти / інструменти
  ["Reagents:"] = "Реагенти:",
  ["Reagent:"] = "Реагент:",
  ["Tools:"] = "Інструменти:",
  ["Tool:"] = "Інструмент:",

  -- рівень / відновлення
  ["Requires Level"] = "Потрібен рівень",
  ["Requires"] = "Потрібно",
  ["Requires:"] = "Потрібно:",
  ["Cooldown remaining:"] = "До відновлення:",
  ["Cooldown Remaining:"] = "До відновлення:",

  -- екіп
  ["Currently Equipped"] = "Зараз екіпіровано",
  ["CURRENTLY EQUIPPED"] = "Зараз екіпіровано",
  ["Already known"] = "Вже відомо",
  ["Already Known"] = "Вже відомо",

  -- інші короткі
  ["Locked"] = "Замкнено",
  ["Unlocked"] = "Відімкнено",
  ["Broken"] = "Зламано",
  ["No sell price"] = "Немає ціни продажу",
  ["Cannot be sold"] = "Не можна продати",
  ["Quest Item"] = "Предмет для завдання",
  ["Conjured Item"] = "Створений предмет",
  ["Soulbound"] = "Прив\'язано",
  ["Not Bound"] = "Не прив\'язано",
  ["Magic"] = "Магічне",
  ["Racial"] = "Расове",

  -- зброя / щит (короткі підписи)
  ["One-Hand"] = "Одноручна",
  ["Two-Hand"] = "Дворучна",
  ["Main Hand"] = "Основна рука",
  ["Off Hand"] = "Додаткова рука",
  ["Held In Off-hand"] = "У лівій руці",
  ["Held In Offhand"] = "У лівій руці",
  ["Relic"] = "Реліквія",

  -- промпти
  ["<Right Click to Read>"] = "<Клацніть ПКМ, щоб прочитати>",
  ["<Right Click to Open>"] = "<Клацніть ПКМ, щоб відкрити>",
  ["<Shift Right Click to Socket>"] = "<Shift+ПКМ — вставити камінь>",
  ["Click to learn"] = "Клацніть, щоб вивчити",
  ["Right click to open"] = "ПКМ, щоб відкрити",
}
