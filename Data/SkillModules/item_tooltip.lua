--[[
  OceUA — item_tooltip
  ============================================================================ки тултіпа ПРЕДМЕТА (не описи скілів).

  Таблиці:
    OceUA_ITEM_STAT  — "+12 Stamina" → ключ лише "Stamina"
    OceUA_ITEM_FIXED — точний весь рядок: "Unique", "Binds when picked up"
    OceUA_ITEM_TYPE  — тип: "Cloth", "Sword"
    OceUA_ITEM_EQUIP — слот: "Head", "Main Hand"
    OceUA_ITEM_TEMP  — початок рядка: "Sharpened" → "Sharpened +2 (25 min)"

  Логіка OceUA_ITEM_TEMP (як Sharpened):
    1) У грі: Sharpened +2 (25 min)
    2) Шукаємо ключ, з якого ПОЧИНАЄТЬСЯ рядок
    3) ["Sharpened"] = "Заточено" → міняється лише префікс
    4) Хвіст лишається, min → хв
    → Заточено +2 (25 хв)
    Достатньо одного слова; довші ключі (Instant Poison VI) мають пріоритет.

  Логіка OceUA_ITEM_STAT:
    1) У грі: +12 Stamina
    2) Ключ = текст ПІСЛЯ "+12 " → "Stamina"
    3) ["Stamina"] = "до витривалості"
    → +12 до витривалості

  НЕ сюди: довгі описи скілів → Data/Skill_Dictionary.lua
  Після правок: /reload
]]

-- "+12 Stamina" / "+5% Hit" → суфікс після числа
OceUA_ITEM_STAT = {
  -- основні
  ["Stamina"] = "до витривалості",
  ["Strength"] = "до сили",
  ["Agility"] = "до спритності",
  ["Intellect"] = "до інтелекту",
  ["Spirit"] = "до духу",
  ["All Stats"] = "до всіх характеристик",

  -- броня / захист
  ["Armor"] = "Броня",
  ["Block"] = "Блок",
  ["Defense"] = "до захисту",
  ["Dodge"] = "до ухилення",
  ["Parry"] = "до парирування",
  ["Shield Block"] = "до блоку щитом",
  ["Defense Rating"] = "до рейтингу захисту",
  ["Dodge Rating"] = "до рейтингу ухилення",
  ["Parry Rating"] = "до рейтингу парирування",
  ["Block Value"] = "до значення блоку",
  ["Armor Penetration"] = "до пробивання броні",

  -- влучність / крит
  ["Hit"] = "до влучності",
  ["Hit Rating"] = "до рейтингу влучності",
  ["Crit"] = "до критичного удару",
  ["Critical Strike"] = "до критичного удару",
  ["Critical Strike Rating"] = "до рейтингу крит. удару",
  ["Spell Hit"] = "до влучності заклинань",
  ["Spell Critical"] = "до критичного удару заклинаннями",
  ["Spell Critical Strike"] = "до критичного удару заклинаннями",

  -- сила атаки / заклинань
  ["Attack Power"] = "до сили атаки",
  ["Ranged Attack Power"] = "до сили далекої атаки",
  ["Spell Damage"] = "до шкоди заклинань",
  ["Spell Power"] = "до сили заклинань",
  ["Healing"] = "до зцілення",
  ["Healing Power"] = "до сили зцілення",
  ["Healing Spells"] = "до зцілення заклинань",
  ["Damage and Healing Spells"] = "до шкоди й зцілення заклинань",
  ["Damage to Spells"] = "до шкоди заклинань",
  ["Weapon Damage"] = "до шкоди зброї",
  ["Weapon Skill"] = "до навички зброї",
  ["Attack Speed"] = "до швидкості атаки",

  -- шкода за школами
  ["Fire Spell Damage"] = "до шкоди вогнем",
  ["Frost Spell Damage"] = "до шкоди кригою",
  ["Nature Spell Damage"] = "до шкоди природою",
  ["Shadow Spell Damage"] = "до шкоди тінню",
  ["Arcane Spell Damage"] = "до шкоди тайною магією",
  ["Holy Spell Damage"] = "до шкоди світлом",
  ["Fire Damage"] = "до шкоди вогнем",
  ["Frost Damage"] = "до шкоди кригою",
  ["Nature Damage"] = "до шкоди природою",
  ["Shadow Damage"] = "до шкоди тінню",
  ["Arcane Damage"] = "до шкоди тайною магією",
  ["Holy Damage"] = "до шкоди світлом",

  -- опори
  ["All Resistances"] = "до всіх опорів",
  ["Fire Resistance"] = "до опору вогню",
  ["Frost Resistance"] = "до опору кризі",
  ["Nature Resistance"] = "до опору природі",
  ["Shadow Resistance"] = "до опору тіні",
  ["Arcane Resistance"] = "до опору тайній магії",

  -- реген
  ["Mana every"] = "мани кожні",
  ["Health every"] = "здоров'я кожні",
  ["mana every 5 sec."] = "мани кожні 5 сек",
  ["health every 5 sec."] = "здоров'я кожні 5 сек",
  ["Mana every 5 sec."] = "мани кожні 5 сек",
  ["Health every 5 sec."] = "здоров'я кожні 5 сек",
  ["mana per 5 sec."] = "мани кожні 5 сек",
  ["health per 5 sec."] = "здоров'я кожні 5 сек",
  ["Mana per 5 sec."] = "мани кожні 5 сек",
  ["Health per 5 sec."] = "здоров'я кожні 5 сек",

  -- інше
  ["Speed"] = "до швидкості",
  ["Mount Speed"] = "до швидкості транспорту",
  ["Minor Speed Increase"] = "Незначне підвищення швидкості",
}

-- Точний весь рядок (без змінних чисел у ключі)
OceUA_ITEM_FIXED = {
  -- flags
  ["Soulbound"] = "Прив'язано",
  ["Quest Item"] = "Предмет для завдання",
  ["Unique"] = "Унікальний",
  ["Unique Equip"] = "Унікальний (екіпірування)",
  ["Unique-Equipped"] = "Унікальний (екіпірування)",
  ["Binds when picked up"] = "Прив'язується при отриманні",
  ["Binds when equipped"] = "Прив'язується при надяганні",
  ["Binds when used"] = "Прив'язується при використанні",
  ["This Item Begins a Quest"] = "Цей предмет починає завдання",
  ["Conjured Item"] = "Створений предмет",
  ["Already known"] = "Вже відомо",
  ["Already Known"] = "Вже відомо",
  ["Locked"] = "Замкнено",
  ["Broken"] = "Зламано",
  ["No sell price"] = "Немає ціни продажу",
  -- prompts
  ["<Right Click to Read>"] = "<Клацніть ПКМ, щоб прочитати>",
  ["<Right Click to Open>"] = "<Клацніть ПКМ, щоб відкрити>",
  ["Equip:"] = "Екіпірування:",
  ["Use:"] = "Використання:",
  ["Chance on hit:"] = "Шанс при ударі:",
  ["Chance on Hit:"] = "Шанс при ударі:",
  ["Proc Chance:"] = "Шанс спрацювання:",
  ["Requires Level"] = "Потрібен рівень",
  ["Requires"] = "Потрібно",
  ["Currently Equipped"] = "Зараз екіпіровано",
  ["CURRENTLY EQUIPPED"] = "Зараз екіпіровано",
  ["Next rank:"] = "Наступний ранг:",
  ["Next Rank:"] = "Наступний ранг:",
  ["yd range"] = "ярдів дальності",
  ["Sell Price:"] = "Ціна продажу:",
  ["Buy Price:"] = "Ціна купівлі:",
  ["Vendor sells for:"] = "Продавець продає за:",
  ["Duration:"] = "Тривалість:",
  ["Charges:"] = "Заряди:",
}

-- Тип предмета / матеріал / зброя (весь рядок)
OceUA_ITEM_TYPE = {
  -- armor
  ["Cloth"] = "Тканина",
  ["Leather"] = "Шкіра",
  ["Mail"] = "Кольчуга",
  ["Plate"] = "Лати",
  -- weapons
  ["Sword"] = "Меч",
  ["Axe"] = "Сокира",
  ["Mace"] = "Булава",
  ["Dagger"] = "Кинджал",
  ["Polearm"] = "Древкова зброя",
  ["Staff"] = "Посох",
  ["Fist Weapon"] = "Кулачна зброя",
  ["Bow"] = "Лук",
  ["Gun"] = "Рушниця",
  ["Crossbow"] = "Арбалет",
  ["Wand"] = "Жезл",
  ["Thrown"] = "Метальна",
  ["Shield"] = "Щит",
  -- relics
  ["Idol"] = "Ідол",
  ["Totem"] = "Тотем",
  ["Libram"] = "Лібрам",
  -- ammo / bags
  ["Arrow"] = "Стріла",
  ["Bullet"] = "Куля",
  ["Projectile"] = "Снаряд",
  ["Quiver"] = "Сагайдак",
  ["Container"] = "Контейнер",
  ["Bag"] = "Сумка",
  -- other
  ["Miscellaneous"] = "Різне",
  ["Junk"] = "Мотлох",
  ["Consumable"] = "Витратний",
  ["Trade Goods"] = "Господарські товари",
  ["Reagent"] = "Реагент",
  ["Recipe"] = "Рецепт",
  ["Key"] = "Ключ",
  ["Permanent"] = "Постійний",
}

-- Слот екіпіровки (весь рядок)
OceUA_ITEM_EQUIP = {
  ["Head"] = "Голова",
  ["Neck"] = "Шия",
  ["Shoulder"] = "Плечі",
  ["Back"] = "Спина",
  ["Chest"] = "Груди",
  ["Shirt"] = "Сорочка",
  ["Tabard"] = "Гербова накидка",
  ["Wrist"] = "Зап'ястя",
  ["Waist"] = "Пояс",
  ["Hands"] = "Руки",
  ["Legs"] = "Ноги",
  ["Feet"] = "Ступні",
  ["Finger"] = "Палець",
  ["Trinket"] = "Аксесуар",
  ["One-Hand"] = "Одноручна зброя",
  ["Two-Hand"] = "Дворучна зброя",
  ["Main Hand"] = "Основна рука",
  ["Off Hand"] = "Додаткова рука",
  ["Held In Off-hand"] = "Тримається в лівій руці",
  ["Ranged"] = "Далекий бій",
  ["Relic"] = "Реліквія",
  ["Gun"] = "Рушниця",
  ["Wand"] = "Жезл",
  ["Crossbow"] = "Арбалет",
  ["Thrown"] = "Метальна зброя",
  ["Shield"] = "Щит",
  ["Projectile"] = "Снаряд",
}

-- Тимчасові зачарування зброї (зелений рядок)
-- Ключ = ПОЧАТОК рядка з гри. "Sharpened" покриває "Sharpened +2 (25 min)".
OceUA_ITEM_TEMP = {
  -- точилки / камені
  ["Sharpened"] = "Заточено",
  ["Weighted"] = "Зважено",
  ["Consecrated"] = "Освячено",
  -- отрути
  ["Instant Poison"] = "Миттєва отрута",
  ["Instant Poison II"] = "Миттєва отрута II",
  ["Instant Poison III"] = "Миттєва отрута III",
  ["Instant Poison IV"] = "Миттєва отрута IV",
  ["Instant Poison V"] = "Миттєва отрута V",
  ["Instant Poison VI"] = "Миттєва отрута VI",
  ["Deadly Poison"] = "Смертельна отрута",
  ["Deadly Poison II"] = "Смертельна отрута II",
  ["Deadly Poison III"] = "Смертельна отрута III",
  ["Deadly Poison IV"] = "Смертельна отрута IV",
  ["Deadly Poison V"] = "Смертельна отрута V",
  ["Crippling Poison"] = "Калічача отрута",
  ["Crippling Poison II"] = "Калічача отрута II",
  ["Mind-numbing Poison"] = "Дурманяча отрута",
  ["Mind-numbing Poison II"] = "Дурманяча отрута II",
  ["Mind-numbing Poison III"] = "Дурманяча отрута III",
  ["Wound Poison"] = "Раняча отрута",
  ["Wound Poison II"] = "Раняча отрута II",
  ["Wound Poison III"] = "Раняча отрута III",
  ["Wound Poison IV"] = "Раняча отрута IV",
  -- олії
  ["Frost Oil"] = "Олія криги",
  ["Shadow Oil"] = "Тіньова олія",
  ["Wizard Oil"] = "Чародійська олія",
  ["Mana Oil"] = "Олія мани",
  ["Brilliant Wizard Oil"] = "Блискуча чародійська олія",
  ["Brilliant Mana Oil"] = "Блискуча олія мани",
  ["Lesser Wizard Oil"] = "Мала чародійська олія",
  ["Lesser Mana Oil"] = "Мала олія мани",
  ["Minor Wizard Oil"] = "Мінімальна чародійська олія",
  ["Minor Mana Oil"] = "Мінімальна олія мани",
  ["Oil of Immolation"] = "Олія спалення",
}

-- Імена класів (для "Classes: Warrior, Mage")
OceUA_ITEM_CLASS = {
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

-- Імена рас (якщо з'явиться "Races: …")
OceUA_ITEM_RACE = {
  ["Human"] = "Людина",
  ["Dwarf"] = "Дворф",
  ["Night Elf"] = "Нічний ельф",
  ["Gnome"] = "Гном",
  ["Orc"] = "Орк",
  ["Undead"] = "Нежить",
  ["Tauren"] = "Таурен",
  ["Troll"] = "Троль",
}

-- Назви професій (для "Requires Blacksmithing (150)")
OceUA_ITEM_PROF = {
  ["Blacksmithing"] = "Ковальство",
  ["Leatherworking"] = "Шкіряництво",
  ["Alchemy"] = "Алхімія",
  ["Herbalism"] = "Травництво",
  ["Mining"] = "Гірництво",
  ["Tailoring"] = "Кравецтво",
  ["Engineering"] = "Інженерія",
  ["Enchanting"] = "Зачарування",
  ["Fishing"] = "Риболовля",
  ["Cooking"] = "Кулінарія",
  ["First Aid"] = "Перша допомога",
  ["Skinning"] = "Зняття шкур",
  ["Jewelcrafting"] = "Ювелірна справа",
  ["Survival"] = "Виживання",
  ["Lockpicking"] = "Зламування замків",
  ["Poisons"] = "Отрути",
  ["Riding"] = "Верхова їзда",
}

-- Повні рядки Requires … (стійки, форми, зброя…)
OceUA_ITEM_REQUIRE = {
  -- стійки воїна
  ["Requires Defensive Stance"] = "Потрібна оборонна стійка",
  ["Requires Battle Stance"] = "Потрібна бойова стійка",
  ["Requires Berserker Stance"] = "Потрібна стійка берсерка",
  ["Requires Battle Stance, Defensive Stance"] = "Потрібна бойова або оборонна стійка",
  ["Requires Battle Stance, Berserker Stance"] = "Потрібна бойова стійка або стійка берсерка",
  ["Requires Defensive Stance, Berserker Stance"] = "Потрібна оборонна стійка або стійка берсерка",
  ["Requires Battle Stance, Defensive Stance, Berserker Stance"] = "Потрібна будь-яка стійка",

  -- зброя / щит (однина + множина, як у грі)
  ["Requires Melee Weapon"] = "Потрібна зброя ближнього бою",
  ["Requires Malee Weapon"] = "Потрібна зброя ближнього бою",
  ["Requires Ranged Weapon"] = "Потрібна зброя дальнього бою",
  ["Requires Shield"] = "Потрібен щит",
  ["Requires Shields"] = "Потрібні щити",

  ["Requires Wand"] = "Потрібен жезл",
  ["Requires Wands"] = "Потрібні жезли",
  ["Requires Bow"] = "Потрібен лук",
  ["Requires Bows"] = "Потрібні луки",
  ["Requires Gun"] = "Потрібна рушниця",
  ["Requires Guns"] = "Потрібні рушниці",
  ["Requires Crossbow"] = "Потрібен арбалет",
  ["Requires Crossbows"] = "Потрібні арбалети",
  ["Requires Thrown"] = "Потрібна метальна зброя",
  ["Requires Throwing Weapon"] = "Потрібна метальна зброя",
  ["Requires Throwing Weapons"] = "Потрібна метальна зброя",

  ["Requires Dagger"] = "Потрібен кинджал",
  ["Requires Daggers"] = "Потрібні кинджали",
  ["Requires Fist Weapon"] = "Потрібна кулачна зброя",
  ["Requires Fist Weapons"] = "Потрібна кулачна зброя",
  ["Requires Polearm"] = "Потрібна древкова зброя",
  ["Requires Polearms"] = "Потрібна древкова зброя",
  ["Requires Staff"] = "Потрібен посох",
  ["Requires Staves"] = "Потрібні посохи",
  ["Requires Staffs"] = "Потрібні посохи",

  ["Requires Sword"] = "Потрібен меч",
  ["Requires Swords"] = "Потрібні мечі",
  ["Requires Axe"] = "Потрібна сокира",
  ["Requires Axes"] = "Потрібні сокири",
  ["Requires Mace"] = "Потрібна булава",
  ["Requires Maces"] = "Потрібні булави",

  ["Requires One-Handed Axe"] = "Потрібна одноручна сокира",
  ["Requires One-Handed Axes"] = "Потрібні одноручні сокири",
  ["Requires One-Handed Mace"] = "Потрібна одноручна булава",
  ["Requires One-Handed Maces"] = "Потрібні одноручні булави",
  ["Requires One-Handed Sword"] = "Потрібен одноручний меч",
  ["Requires One-Handed Swords"] = "Потрібні одноручні мечі",
  ["Requires Two-Handed Axe"] = "Потрібна дворучна сокира",
  ["Requires Two-Handed Axes"] = "Потрібні дворучні сокири",
  ["Requires Two-Handed Mace"] = "Потрібна дворучна булава",
  ["Requires Two-Handed Maces"] = "Потрібні дворучні булави",
  ["Requires Two-Handed Sword"] = "Потрібен дворучний меч",
  ["Requires Two-Handed Swords"] = "Потрібні дворучні мечі",

  ["Requires Bows, Guns, Thrown, Crossbows"] = "Потрібні луки, рушниці, метальна зброя, арбалети",
  ["Requires Fishing Pole"] = "Потрібна вудка",
  ["Requires Fishing Poles"] = "Потрібна вудка",

  -- форми друїда
  ["Requires Cat Form"] = "Потрібна форма кішки",
  ["Requires Bear Form"] = "Потрібна форма ведмедя",
  ["Requires Dire Bear Form"] = "Потрібна форма жахливого ведмедя",
  ["Requires Bear Form, Dire Bear Form"] = "Потрібна форма ведмедя",
  ["Requires Aquatic Form"] = "Потрібна водна форма",
  ["Requires Travel Form"] = "Потрібна подорожня форма",
  ["Requires Moonkin Form"] = "Потрібна форма місячного совуха",
  ["Requires Tree of Life Form"] = "Потрібна форма дерева життя",

  -- інше
  ["Requires Stealth"] = "Потрібна непомітність",
  ["Requires Outdoors"] = "Лише просто неба",
  ["Requires No Weapons"] = "Без зброї",
  ["Must remain seated while eating."] = "Під час їжі потрібно сидіти.",
  ["Must remain seated while drinking."] = "Під час пиття потрібно сидіти.",

  -- Requires: з двокрапкою (професії / інструменти) — також парсяться в коді
  ["Requires: Cooking Fire"] = "Потрібно: Кухонне вогнище",
  ["Requires: Forge"] = "Потрібно: Горн",
  ["Requires: Anvil"] = "Потрібно: Ковадло",
  ["Requires: Blacksmith Hammer"] = "Потрібно: Ковальський молот",
  ["Requires: Blacksmith Hammer, Anvil"] = "Потрібно: Ковальський молот, Ковадло",
  ["Requires: Anvil, Blacksmith Hammer"] = "Потрібно: Ковадло, Ковальський молот",
  ["Requires: Skinning Knife"] = "Потрібно: Ніж для зняття шкур",
  ["Requires: Mining Pick"] = "Потрібно: Кирка",
  ["Requires: Arclight Spanner"] = "Потрібно: Арклайт-ключ",
  ["Requires: Gyromatic Micro-Adjustor"] = "Потрібно: Гіроматичний мікрорегулятор",
  ["Requires: Weak Flux"] = "Потрібно: Слабкий флюс",
  ["Requires: Strong Flux"] = "Потрібно: Сильний флюс",
  ["Requires: Runed Copper Rod"] = "Потрібно: Мідна рунічна паличка",
  ["Requires: Runed Silver Rod"] = "Потрібно: Срібна рунічна паличка",
  ["Requires: Runed Golden Rod"] = "Потрібно: Золота рунічна паличка",
  ["Requires: Runed Truesilver Rod"] = "Потрібно: Паличка з істинного срібла",
  ["Requires: Runed Arcanite Rod"] = "Потрібно: Арканітова рунічна паличка",
  ["Requires: Philosopher's Stone"] = "Потрібно: Філософський камінь",

  -- без двокрапки (варіанти з гри)
  ["Requires Cooking Fire"] = "Потрібне кухонне вогнище",
  ["Requires Forge"] = "Потрібен горн",
  ["Requires Anvil"] = "Потрібне ковадло",
  ["Requires Blacksmith Hammer"] = "Потрібен ковальський молот",
  ["Requires Skinning Knife"] = "Потрібен ніж для зняття шкур",
  ["Requires Mining Pick"] = "Потрібна кирка",
  ["Requires Shields"] = "Потрібні щити",
}

-- Інструменти / станції професій (для парсера "Requires: A, B")
OceUA_ITEM_TOOL = {
  ["Blacksmith Hammer"] = "Ковальський молот",
  ["Anvil"] = "Ковадло",
  ["Forge"] = "Горн",
  ["Cooking Fire"] = "Кухонне вогнище",
  ["Skinning Knife"] = "Ніж для зняття шкур",
  ["Mining Pick"] = "Кирка",
  ["Arclight Spanner"] = "Арклайт-ключ",
  ["Gyromatic Micro-Adjustor"] = "Гіроматичний мікрорегулятор",
  ["Gyromatic Micro Adjustor"] = "Гіроматичний мікрорегулятор",
  ["Weak Flux"] = "Слабкий флюс",
  ["Strong Flux"] = "Сильний флюс",
  ["Elemental Flux"] = "Стихійний флюс",
  ["Runed Copper Rod"] = "Мідна рунічна паличка",
  ["Runed Silver Rod"] = "Срібна рунічна паличка",
  ["Runed Golden Rod"] = "Золота рунічна паличка",
  ["Runed Truesilver Rod"] = "Паличка з істинного срібла",
  ["Runed Arcanite Rod"] = "Арканітова рунічна паличка",
  ["Philosopher's Stone"] = "Філософський камінь",
  ["Simple Wood"] = "Проста деревина",
  ["Flint and Tinder"] = "Кремінь і трут",
  ["Empty Vial"] = "Порожня колба",
  ["Leaded Vial"] = "Свинцева колба",
  ["Crystal Vial"] = "Кришталева колба",
  ["Imbued Vial"] = "Насичена колба",
  ["Thieves' Tools"] = "Злодійські інструменти",
  ["Salt"] = "Сіль",
  ["Soft Leather"] = "М'яка шкіра",
  -- стійки / форми (для комбінацій Requires A, B)
  ["Battle Stance"] = "бойова стійка",
  ["Defensive Stance"] = "оборонна стійка",
  ["Berserker Stance"] = "стійка берсерка",
  ["Cat Form"] = "форма кішки",
  ["Bear Form"] = "форма ведмедя",
  ["Dire Bear Form"] = "форма жахливого ведмедя",
  ["Aquatic Form"] = "водна форма",
  ["Travel Form"] = "подорожня форма",
  ["Moonkin Form"] = "форма місячного совуха",
  ["Tree of Life Form"] = "форма дерева життя",
  ["Stealth"] = "непомітність",
  ["Melee Weapon"] = "зброя ближнього бою",
  ["Ranged Weapon"] = "зброя дальнього бою",
  ["Shield"] = "щит",
  ["Shields"] = "щити",
  ["Outdoors"] = "просто неба",
  ["Wands"] = "жезли",
  ["Wand"] = "жезл",
  ["Bows"] = "луки",
  ["Guns"] = "рушниці",
  ["Crossbows"] = "арбалети",
  ["Daggers"] = "кинджали",
  ["Swords"] = "мечі",
  ["Axes"] = "сокири",
  ["Maces"] = "булави",
  ["Staves"] = "посохи",
  ["Polearms"] = "древкова зброя",
  ["Fist Weapons"] = "кулачна зброя",
  ["One-Handed Swords"] = "одноручні мечі",
  ["One-Handed Axes"] = "одноручні сокири",
  ["One-Handed Maces"] = "одноручні булави",
  ["Two-Handed Swords"] = "дворучні мечі",
  ["Two-Handed Axes"] = "дворучні сокири",
  ["Two-Handed Maces"] = "дворучні булави",
  ["Throwing Weapons"] = "метальна зброя",
  ["Fishing Pole"] = "вудка",
  ["Fishing Poles"] = "вудка",

  -- додаткові інструменти / фокуси
  ["Hammer"] = "Молот",
  ["Blacksmith's Hammer"] = "Ковальський молот",
  ["Smithing Hammer"] = "Ковальський молот",
  ["Virtuoso Inking Set"] = "Набір віртуозного письма",
  ["Jeweler's Kit"] = "Набір ювеліра",
  ["Simple Grinder"] = "Проста точилка",
  ["Mining Pick"] = "Кирка",
  ["Skinning Knife"] = "Ніж для зняття шкур",
  ["Fishing Pole"] = "Вудка",
  ["Bright Baubles"] = "Яскраві блешні",
  ["Aquadynamic Fish Attractor"] = "Аквадинамічний атрактор",
  ["Shiny Bauble"] = "Блискуча блешня",
  ["Nightcrawlers"] = "Дощові черв\'яки",
  ["Flesh Eating Worm"] = "М\'ясоїдний черв\'як",
}


