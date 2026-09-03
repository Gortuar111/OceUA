--[[
  OceUA — tooltip_extras
  Короткі рядки тултіпа (повний точний збіг ключа = рядок з гри).

  Логіка:
    1) У грі весь рядок, напр. Classes: Warrior
    2) Ключ = ВЕСЬ рядок як є
    3) ["Classes: Warrior"] = "Класи: Воїн"
    → повна заміна рядка

  НЕ сюди:
    +12 Stamina          → item_tooltip.lua / OceUA_ITEM_STAT
    Sharpened +2 (25 min)→ item_tooltip.lua / OceUA_ITEM_TEMP
    довгі описи скілів   → Data/Skill_Dictionary.lua

  Секції нижче: -- stats / -- classes / -- requires / …
  Дописуй у відповідну секцію. Після правок: /reload
]]

OceUA_tooltip_extras = {
  -- stats — підписи статів / комбо (+N Stamina, Crit…)
  ["+4 Stamina, +20 Armor"] = "+4 до витривалості, +20 до броні",
  ["+5 Strength, +10 Nature Resist"] = "+5 до сили, +10 до опору природі",
  ["Agility"] = "Спритність",
  ["Arcane Resistance"] = "Опір тайній магії",
  ["Armor"] = "Броня",
  ["Armor Penetration"] = "Пробивання броні",
  ["Attack Power"] = "Сила атаки",
  ["Attack Speed"] = "Швидкість атаки",
  ["Block"] = "Блокування",
  ["Block Value"] = "Значення блокування",
  ["Critical Strike"] = "Критичний удар",
  ["Damage"] = "Шкода",
  ["Dodge"] = "Ухилення",
  ["Durability"] = "Міцність",
  ["Energy"] = "Енергія",
  ["Fire Resistance"] = "Опір вогню",
  ["Frost Resistance"] = "Опір льоду",
  ["Healing Power"] = "Сила зцілення",
  ["Health"] = "Здоров'я",
  ["Health Regeneration"] = "Відновлення здоров'я",
  ["Hit"] = "Влучність",
  ["Intellect"] = "Інтелект",
  ["Item Level"] = "Рівень предмета",
  ["Mana"] = "Мана",
  ["Mana per 5 sec"] = "Мана кожні 5 сек",
  ["Mana Regeneration"] = "Відновлення мани",
  ["Nature Resistance"] = "Опір природі",
  ["Parry"] = "Парирування",
  ["Ranged Attack Power"] = "Сила атаки на відстані",
  ["Shadow Resistance"] = "Опір темряві",
  ["Speed"] = "Швидкість",
  ["Spell Critical Strike"] = "Критичний удар заклинань",
  ["Spell Hit"] = "Влучність заклинань",
  ["Spell Power"] = "Сила заклинань",
  ["Spirit"] = "Дух",
  ["Stamina"] = "Витривалість",
  ["Strength"] = "Сила",
  ["Weapon Damage"] = "Шкода зброї",
  ["Weapon Skill"] = "Навичка зброї",

  -- slots_types — слоти й типи предметів (дубль item_tooltip, для словника)
  ["Axe"] = "Сокира",
  ["Cloth"] = "Тканина",
  ["Dagger"] = "Кинджал",
  ["Finger"] = "Палець",
  ["Held In Off-hand"] = "Тримається в лівій руці",
  ["Leather"] = "Шкіра",
  ["Mail"] = "Кольчуга",
  ["Main Hand"] = "Основна рука",
  ["Off Hand"] = "Додаткова рука",
  ["One-Hand"] = "Одноручна зброя",
  ["Plate"] = "Лати",
  ["Projectile"] = "Снаряд",
  ["Relic"] = "Реліквія",
  ["Sword"] = "Меч",
  ["Trinket"] = "Аксесуар",
  ["Two-Hand"] = "Дворучна зброя",

  -- item_flags — прив'язка, квест-предмет…
  ["Binds when equipped"] = "Прив'язується при надяганні",
  ["Binds when picked up"] = "Прив'язується при отриманні",
  ["Soulbound"] = "Прив'язано до душі",
  ["This Item Begins a Quest"] = "Цей предмет розпочинає квест",

  -- requires — шаблони з $s1 (рівень професії); повні рядки → item_tooltip ITEM_REQUIRE
  ["Requires Alchemy ($s1)"] = "Потрібна алхімія ($s1)",
  ["Requires Blacksmithing ($s1)"] = "Потрібне ковальство ($s1)",
  ["Requires Cooking ($s1)"] = "Потрібна кулінарія ($s1)",
  ["Requires Enchanting ($s1)"] = "Потрібне зачарування ($s1)",
  ["Requires Engineering ($s1)"] = "Потрібна інженерія ($s1)",
  ["Requires First Aid ($s1)"] = "Потрібна перша допомога ($s1)",
  ["Requires Fishing ($s1)"] = "Потрібна риболовля ($s1)",
  ["Requires Herbalism ($s1)"] = "Потрібне травництво ($s1)",
  ["Requires Jewelcrafting ($s1)"] = "Потрібна ювелірна справа ($s1)",
  ["Requires Leatherworking ($s1)"] = "Потрібне шкіряництво ($s1)",
  ["Requires Mining ($s1)"] = "Потрібне гірництво ($s1)",
  ["Requires Skinning ($s1)"] = "Потрібне зняття шкур ($s1)",
  ["Requires Survival ($s1)"] = "Потрібне виживання ($s1)",
  ["Requires Tailoring ($s1)"] = "Потрібне кравецтво ($s1)",

  -- classes — Classes: Warrior…
  ["Classes: Druid"] = "Класи: Друїд",
  ["Classes: Hunter"] = "Класи: Мисливець",
  ["Classes: Mage"] = "Класи: Маг",
  ["Classes: Paladin"] = "Класи: Паладин",
  ["Classes: Priest"] = "Класи: Жрець",
  ["Classes: Rogue"] = "Класи: Розбійник",
  ["Classes: Shaman"] = "Класи: Шаман",
  ["Classes: Warlock"] = "Класи: Чорнокнижник",
  ["Classes: Warrior"] = "Класи: Воїн",

  -- consumable — описи напоїв тощо
  ["A fairly weak alcoholic beverage."] = "Досить слабкий алкогольний напій.",
  ["A strangely glowing alcoholic beverage."] = "Алкогольний напій, що дивно світиться.",
  ["A strong alcoholic beverage."] = "Міцний алкогольний напій.",
  ["A typical alcoholic beverage."] = "Типовий алкогольний напій.",
  ["An extremely potent alcoholic beverage."] = "Надзвичайно міцний алкогольний напій.",

  -- ui — Cooldown remaining…
  ["Cooldown remaining: $s1"] = "Час відновлення: $s1",
  
  -- other
  ["A little something from Speedy to keep you steady on your journey."] = "Невеличкий подарунок від Спіді, щоб ви почувалися впевнено у своїй подорожі.",
  ["You are here"] = "Ти зараз тут",

  -- flavor — жартівливі/особливі описи
  ["Old, grumpy, and possibly retired twice. Goes forward when bribed. Sometimes sideways."] = "Старий, буркотливий і, можливо, двічі вийшов на пенсію. Рухається вперед, якщо йому дати хабар. Іноді — вбік.",
  ["Old, grumpy, and possibly retired twice. Goes forward when bribed. Sometimes sideways.\\n\\nYour speed is increased by 40%."] = "Старий, буркотливий і, можливо, двічі вийшов на пенсію. Рухається вперед, якщо йому дати хабар. Іноді — вбік.\\n\\nВаша швидкість збільшується на 40%.",

  -- misc — інше коротке
  ["10 mana per second.\\nIncreases movement speed by $s1%."] = "10 мани на секунду.\\nЗбільшує швидкість руху на $s1%.",
  ["10% damage and stunned."] = "10% шкоди та оглушення.",
  ["100 Health"] = "100 здоров’я",
  ["100 Mana"] = "100 мани",
  ["457 Damage."] = "457 одиниць шкоди.",
  ["500 Health"] = "500 «Здоров’я»",
  ["Back"] = "Спина",
  ["Bow"] = "Лук",
  ["Chest"] = "Груди",
  ["Crossbow"] = "Арбалет",
  ["Equip:"] = "Носити:",
  ["Feet"] = "Ступні",
  ["Fist Weapon"] = "Кистьова зброя",
  ["Gun"] = "Рушниця",
  ["Hands"] = "Руки",
  ["Head"] = "Голова",
  ["Instant"] = "Миттєво",
  ["Legs"] = "Ноги",
  ["Libram"] = "Фоліант",
  ["Neck"] = "Шия",
  ["Next melee"] = "Наступна атака",
  ["Passive:"] = "Пасивний ефект:",
  ["Pengu"] = "Пінгвін",
  ["Polearm"] = "Древкова зброя",
  ["Quest Item"] = "Квестовий предмет",
  ["Ranged"] = "Далекий бій",
  ["Ring"] = "Перстень",
  ["Shield"] = "Щит",
  ["Shirt"] = "Сорочка",
  ["Shoulder"] = "Плечі",
  ["Staff"] = "Посох",
  ["Tabard"] = "Гербова накидка",
  ["Thrown"] = "Метальна зброя",
  ["Unique-Equipped"] = "Унікальний при екіпіруванні",
  ["Use:"] = "Використання:",
  ["Waist"] = "Пояс",
  ["Wand"] = "Жезл",
  ["Wrist"] = "Зап'ястя",

}
