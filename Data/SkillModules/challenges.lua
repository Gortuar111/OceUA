--[[
  OceUA — challenges (режими випробувань)
  Лише ті, що є у створенні персонажа на цьому сервері.

  Логіка: точний збіг рядка з гри.
  Дописуй нові сюди. Після правок: /reload
]]

OceUA_challenges = {

  -- ===== UI =====
  ["Active Challenges:"] = "Активні випробування:",
  ["Active Challenges"] = "Активні випробування",
  ["Challenges"] = "Випробування",
  ["Challenge Mode"] = "Режим випробування",
  ["No active challenges."] = "Немає активних випробувань.",
  ["No active challenges"] = "Немає активних випробувань",
  ["Challenge failed."] = "Випробування провалено.",
  ["Challenge complete!"] = "Випробування завершено!",
  ["Challenge completed!"] = "Випробування завершено!",
  ["You failed the challenge."] = "Ви провалили випробування.",
  ["You completed the challenge."] = "Ви завершили випробування.",

  -- ===== Назви (реальний список створення персонажа) =====
  ["War Mode"] = "Бойовий режим",
  ["Exhaustion"] = "Виснаження",
  ["Slow & Steady"] = "Повільно, але впевнено",
  ["Level One Lunatic"] = "Божевільний 1 рівня",
  ["Boaring Adventure"] = "Свиняча пригода",
  ["Path of the Brewmaster"] = "Шлях пивовара",
  ["Vagrant's Endeavor"] = "Подвиг мандрівника",
  ["Traveling Craftmaster"] = "Мандрівний майстер ремесел",
  ["Trial of Heroism"] = "Випробування героїзму",
  ["Way of the Samurai"] = "Шлях самурая",
  ["Together Forever"] = "Разом назавжди",

  -- ===== Enable =====
  ["Enable the War Mode challenge."] = "Увімкнути випробування «Бойовий режим».",
  ["Enable the Exhaustion challenge."] = "Увімкнути випробування «Виснаження».",
  ["Enable the Slow & Steady challenge."] = "Увімкнути випробування «Повільно, але впевнено».",
  ["Enable the Level One Lunatic challenge."] = "Увімкнути випробування «Божевільний 1 рівня».",
  ["Enable the Boaring Adventure challenge."] = "Увімкнути випробування «Свиняча пригода».",
  ["Enable the Path of the Brewmaster challenge."] = "Увімкнути випробування «Шлях пивовара».",
  ["Enable the Vagrant's Endeavor challenge."] = "Увімкнути випробування «Подвиг мандрівника».",
  ["Enables the Vagrant's Endeavor challenge."] = "Увімкнути випробування «Подвиг мандрівника».",
  ["Enable the Traveling Craftmaster challenge."] = "Увімкнути випробування «Мандрівний майстер ремесел».",
  ["Enable the Trial of Heroism challenge."] = "Увімкнути випробування «Випробування героїзму».",
  ["Enable the Way of the Samurai challenge."] = "Увімкнути випробування «Шлях самурая».",
  ["Enable the Together Forever challenge."] = "Увімкнути випробування «Разом назавжди».",
  ["Enables War Mode."] = "Увімкнути бойовий режим.",

  -- ===== Disable =====
  ["Disable the War Mode challenge."] = "Вимкнути випробування «Бойовий режим».",
  ["Disable the Exhaustion challenge."] = "Вимкнути випробування «Виснаження».",
  ["Disable the Slow & Steady challenge."] = "Вимкнути випробування «Повільно, але впевнено».",
  ["Disable War Mode."] = "Вимкнути бойовий режим.",

  -- ===== Аури =====
  ["[Aura] War Mode"] = "[Аура] Бойовий режим",
  ["[AURA] War Mode"] = "[Аура] Бойовий режим",
  ["[Aura] Exhaustion"] = "[Аура] Виснаження",
  ["[AURA] Exhaustion"] = "[Аура] Виснаження",
  ["[Aura] Slow & Steady"] = "[Аура] Повільно, але впевнено",
  ["[Aura] Level One Lunatic"] = "[Аура] Божевільний 1 рівня",
  ["[Aura] Boaring Adventure"] = "[Аура] Свиняча пригода",
  ["[Aura] Path of the Brewmaster"] = "[Аура] Шлях пивовара",
  ["[Aura] Vagrant's Endeavor"] = "[Аура] Подвиг мандрівника",
  ["[Aura] Traveling Craftmaster"] = "[Аура] Мандрівний майстер ремесел",
  ["[Aura] Trial of Heroism"] = "[Аура] Випробування героїзму",
  ["[Aura] Way of the Samurai"] = "[Аура] Шлях самурая",
  ["[Aura] Together Forever"] = "[Аура] Разом назавжди",
  
  -- ===== Описи =====
  ["PvP is enabled. You may disable it at any time, but doing so permanently removes War Mode for this character. While active: experience gain from all sources is increased by 15%, and killing players in the open world grants experience."] = "Бойовий режим увімкнено. Ви можете вимкнути його будь-коли, але після цього Бойовий режим буде назавжди видалено для цього персонажа. Поки він активний, отримання досвіду з усіх джерел збільшено на 15%, а за вбивство гравців у відкритому світі ви отримуєте досвід.",
  ["No longer gaining rested experience, but your weapon skill gain will be doubled."] = "Ви більше не отримуєте досвід відпочинку, але приріст навичок володіння зброєю буде подвоєно.",
  ["Gaining 50% fewer experience points from defeating enemies. Lose 5% of accumulated experience from current level upon being defeated by enemies."] = "Ви отримуєте на 50% менше досвіду за перемогу над ворогами. У разі загибелі від ворогів ви втрачаєте 5% накопиченого досвіду поточного рівня.",
  ["During this challenge, you will earn exclusive titles while staying at level one."] = "Під час цього випробування ви отримуватимете унікальні титули, залишаючись на першому рівні.",
  ["In this challenge, leveling up is a real pig deal. Experience comes exclusively from slaying boars!"] = "У цьому випробуванні підвищення рівня — справжня свиняча справа. Досвід можна отримувати виключно за вбивство кабанів!",
  ["From bar to the Barrens, your journey begins! You gain no experience unless you're completely smashed. For every ding, have a drink!"] = "Від бару до Степу починається ваша подорож! Ви не отримуєте досвіду, доки не нап'єтеся вщент. За кожен новий рівень — по чарці!",
  ["You can only use poor and common quality equipment. Enchanting items is not allowed."] = "Ви можете використовувати лише спорядження низької та звичайної якості. Зачаровувати предмети заборонено.",
  ["Equip only what you craft. True power comes from your own hands!"] = "Ви можете споряджатися лише тим, що створили власноруч. Справжня сила — у ваших власних руках!",
  ["Achieve level 58 by earning experience strictly from orange and red-tier monsters and quests."] = "Досягніть 58 рівня, отримуючи досвід виключно за вбивство помаранчевих і червоних монстрів та виконання помаранчевих і червоних завдань.",
  ["You may only wield katana-style swords. No other weapon (bows, guns, etc.) may be equipped. Available only to Warriors, Paladins, Hunters, and Rogues."] = "Ви можете використовувати лише мечі в стилі катани. Жодну іншу зброю (луки, рушниці тощо) не можна екіпірувати. Доступно лише Воїнам, Паладинам, Мисливцям і Розбійникам.",
  ["Bind your fate to up to four companions at level 1. You gain experience from kills only while your entire fellowship is with you. The bond is permanent."] = "Пов'яжіть свою долю максимум із чотирма супутниками на 1 рівні. Ви отримуєте досвід за вбивства лише тоді, коли всі учасники вашої групи перебувають поруч із вами. Цей зв'язок назавжди.",
}
