--[[
  OceUA — Combat_Feedback.lua
  ============================================================
  База бойових / екранних коротких текстів (DODGE, PARRY, …).

  Формат:
    ["ENGLISH"] = "Українською",

  Можна додавати будь-які рядки, які бачиш на екрані в бою
  або при натисканні скіла (Interrupted, Out of range, …).

  УСІ ключі з цієї таблиці підміняються автоматично (UnitUA):
  - floating combat (DODGE/MISS/…)
  - UIErrorsFrame
  - CombatText_AddMessage (якщо є)

  Новий рядок → додай сюди → /reload → без правок коду.

  Після правок: /reload
]]

OceUA_Combat_Feedback = {
  -- === голі слова на портреті / floating feedback ===
  ["DODGE"] = "УХИЛЕННЯ",
  ["Dodge"] = "Ухилення",
  ["PARRY"] = "ПАРИРУВАННЯ",
  ["Parry"] = "Парирування",
  ["BLOCK"] = "БЛОК",
  ["Block"] = "Блок",
  ["MISS"] = "ПРОМАХ",
  ["Miss"] = "Промах",
  ["ABSORB"] = "ПОГЛИНАННЯ",
  ["Absorb"] = "Поглинання",
  ["RESIST"] = "ОПІР",
  ["Resist"] = "Опір",
  ["IMMUNE"] = "ІМУНІТЕТ",
  ["Immune"] = "Імунітет",
  ["EVADE"] = "УНИКНЕННЯ",
  ["Evade"] = "Уникнення",
  ["INTERRUPT"] = "ПЕРЕРИВАННЯ",
  ["Interrupt"] = "Переривання",
  ["INTERRUPTED"] = "ПЕРЕРВАНО",
  ["Interrupted"] = "Перервано",
  ["CRITICAL"] = "КРИТ",
  ["Critical"] = "Крит",
  ["CRIT"] = "КРИТ",
  ["Crit"] = "Крит",
  ["CRUSHING"] = "ЗНИЩУВАЛЬНИЙ",
  ["Crushing"] = "Знищувальний",
  ["GLANCING"] = "КОВЗНИЙ",
  ["Glancing"] = "Ковзний",
  ["REFLECT"] = "ВІДБИТТЯ",
  ["Reflect"] = "Відбиття",
  ["DEFLECT"] = "ВІДХИЛЕННЯ",
  ["Deflect"] = "Відхилення",
  ["BLOCKED"] = "ЗАБЛОКОВАНО",
  ["Blocked"] = "Заблоковано",
  ["ABSORBED"] = "ПОГЛИНУТО",
  ["Absorbed"] = "Поглинуто",
  ["RESISTED"] = "ОПІР",
  ["Resisted"] = "Опір",
  ["COUNTER"] = "КОНТРАТАКА",
  ["Counter"] = "Контратака",
  ["WOUND"] = "РАНА",
  ["HEAL"] = "ЛІКУВАННЯ",

  -- === фрази UI / скіли ===
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
  ["Target is immune"] = "Ціль має імунітет",
  ["Out of range."] = "Поза зоною досяжності.",
  ["You are too far away."] = "Занадто далеко.",
  ["Not enough mana."] = "Недостатньо мани.",
  ["Not enough energy."] = "Недостатньо енергії.",
  ["Not enough rage."] = "Недостатньо люті.",
  ["Ability is not ready yet."] = "Здібність ще не готова.",
  ["Spell is not ready yet."] = "Заклинання ще не готове.",
  ["Item is not ready yet."] = "Предмет ще не готовий.",
  ["Another action is in progress"] = "Виконується інша дія",
  ["Can't do that while moving"] = "Неможливо під час руху",
  ["You are dead"] = "Ви мертві",
  ["You are stunned"] = "Вас оглушено",
  ["You are silenced"] = "Вас знемовлено",
  ["Invalid target"] = "Недійсна ціль",
  ["You have no target."] = "Немає цілі.",
  ["Target is dead"] = "Ціль мертва",
  ["Line of sight"] = "Немає прямої видимості",
  ["Inventory is full."] = "Інвентар заповнений.",
  ["You cannot attack that target."] = "Ви не можете атакувати цю ціль.",
  ["You are too far away!"] = "Ти занадто далеко!",
  ["You are mounted"] = "Ви перебуваєте в сідлі",
  ["Entering Combat"] = "Вступ у бій",
  ["Leaving Combat"] = "Вихід з бою",
  ["No target"] = "Ціль відсутня",
  [""] = "",
  [""] = "",
  [""] = "",
  [""] = "",
  [""] = "",
  [""] = "",
  [""] = "",
  [""] = "",
  [""] = "",
  [""] = "",
}
