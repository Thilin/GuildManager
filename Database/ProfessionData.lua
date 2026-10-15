---@class ProfessionData
--- Catálogo de receitas e dados das 6 profissões primárias de fabricação de WoW Classic / Forever:
--- Alquimia (Alchemy), Alfaiataria (Tailoring), Couraria (Leatherworking),
--- Encantamento (Enchanting), Ferraria (Blacksmithing) e Engenharia (Engineering).
ProfessionData = {}
ProfessionData.__index = ProfessionData

--- Definição das 6 profissões primárias
ProfessionData.PROFESSIONS = {
    ALCHEMY = {
        key = "ALCHEMY",
        name = "Alquimia",
        nameEn = "Alchemy",
        icon = "Interface\\Icons\\Trade_Alchemy",
        spellId = 2259,
        maxSkill = 300,
        description = "Criação de poções, elixires, frascos e transmutações poderosas.",
        descriptionEn = "Crafting potions, elixirs, flasks, and powerful transmutations.",
    },
    TAILORING = {
        key = "TAILORING",
        name = "Alfaiataria",
        nameEn = "Tailoring",
        icon = "Interface\\Icons\\Trade_Tailoring",
        spellId = 3908,
        maxSkill = 300,
        description = "Confecção de armaduras de tecido, bolsas e vestimentas arcanas.",
        descriptionEn = "Crafting cloth armor, bags, and arcane garments.",
    },
    LEATHERWORKING = {
        key = "LEATHERWORKING",
        name = "Couraria",
        nameEn = "Leatherworking",
        icon = "Interface\\Icons\\Trade_Leatherworking",
        spellId = 2108,
        maxSkill = 300,
        description = "Produção de armaduras de couro, malha de dragão, aljavas e kits de armadura.",
        descriptionEn = "Producing leather and dragonscale armor, quivers, and armor kits.",
    },
    ENCHANTING = {
        key = "ENCHANTING",
        name = "Encantamento",
        nameEn = "Enchanting",
        icon = "Interface\\Icons\\Trade_Engraving",
        spellId = 7411,
        maxSkill = 300,
        description = "Encantamento de armas e armaduras, criação de óleos e varinhas mágicas.",
        descriptionEn = "Enchanting weapons and armor, crafting wizard oils, and wands.",
    },
    BLACKSMITHING = {
        key = "BLACKSMITHING",
        name = "Ferraria",
        nameEn = "Blacksmithing",
        icon = "Interface\\Icons\\Trade_BlackSmithing",
        spellId = 2018,
        maxSkill = 300,
        description = "Forja de armas, armaduras de placas e malha, pedras de amolar e chaves.",
        descriptionEn = "Forging weapons, plate and mail armor, sharpening stones, and skeleton keys.",
    },
    ENGINEERING = {
        key = "ENGINEERING",
        name = "Engenharia",
        nameEn = "Engineering",
        icon = "Interface\\Icons\\Trade_Engineering",
        spellId = 4036,
        maxSkill = 300,
        description = "Invenção de bombas, engenhocas gnômicas e goblins, óculos e robôs utilitários.",
        descriptionEn = "Inventing explosives, gnomish and goblin gadgets, goggles, and utility bots.",
    },
}

--- Ordem de exibição das profissões
ProfessionData.ORDER = {
    "ALCHEMY",
    "TAILORING",
    "LEATHERWORKING",
    "ENCHANTING",
    "BLACKSMITHING",
    "ENGINEERING",
}

--- Normaliza nomes de profissões (em português ou inglês) para a chave padrão
---@param name string
---@return string|nil
function ProfessionData.getProfessionKey(name)
    if not name or name == "" then return nil end
    local lower = name:lower():gsub("%s+", "")
    if lower:find("alquim") or lower:find("alchem") then return "ALCHEMY" end
    if lower:find("alfaiat") or lower:find("tailor") or lower:find("sastr") then return "TAILORING" end
    if lower:find("couro") or lower:find("courar") or lower:find("leather") or lower:find("cuir") or lower:find("leder") then return "LEATHERWORKING" end
    if lower:find("encant") or lower:find("enchant") or lower:find("verzaub") then return "ENCHANTING" end
    if lower:find("ferrar") or lower:find("blacksmith") or lower:find("forja") or lower:find("herrer") or lower:find("schmied") then return "BLACKSMITHING" end
    if lower:find("engenhar") or lower:find("engineer") or lower:find("ingeni") then return "ENGINEERING" end
    return nil
end

--- Catálogo de receitas conhecidas do World of Warcraft Classic / Forever
--- Cada receita possui: id, name, namePT, prof, skill, category, categoryPT, quality (1=White, 2=Green, 3=Blue, 4=Purple), icon, reagents, source
local RECIPES = {
    -- =========================================================================
    -- 1. ALQUIMIA (ALCHEMY)
    -- =========================================================================
    -- Poções de Cura e Mana
    { id = 2329,  name = "Elixir of Lion's Strength", namePT = "Elixir de Força do Leão", prof = "ALCHEMY", skill = 1, category = "Elixirs", categoryPT = "Elixires", quality = 1, icon = "Interface\\Icons\\INV_Potion_89", reagents = {{name = "Peacebloom", count = 1}, {name = "Silverleaf", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 2330,  name = "Minor Healing Potion", namePT = "Poção Menor de Cura", prof = "ALCHEMY", skill = 1, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_51", reagents = {{name = "Peacebloom", count = 1}, {name = "Silverleaf", count = 1}, {name = "Empty Vial", count = 1}} },
    { id = 7183,  name = "Elixir of Minor Agility", namePT = "Elixir Menor de Agilidade", prof = "ALCHEMY", skill = 50, category = "Elixirs", categoryPT = "Elixires", quality = 1, icon = "Interface\\Icons\\INV_Potion_93", reagents = {{name = "Swiftthistle", count = 1}, {name = "Briarthorn", count = 1}, {name = "Empty Vial", count = 1}} },
    { id = 2331,  name = "Lesser Healing Potion", namePT = "Poção Inferior de Cura", prof = "ALCHEMY", skill = 55, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_52", reagents = {{name = "Minor Healing Potion", count = 1}, {name = "Briarthorn", count = 1}} },
    { id = 2332,  name = "Elixir of Minor Fortitude", namePT = "Elixir Menor de Fortitude", prof = "ALCHEMY", skill = 50, category = "Elixirs", categoryPT = "Elixires", quality = 1, icon = "Interface\\Icons\\INV_Potion_43", reagents = {{name = "Earthroot", count = 2}, {name = "Peacebloom", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 3170,  name = "Swiftness Potion", namePT = "Poção de Rapidez", prof = "ALCHEMY", skill = 60, category = "Potions", categoryPT = "Poções", quality = 2, icon = "Interface\\Icons\\INV_Potion_19", reagents = {{name = "Swiftthistle", count = 1}, {name = "Briarthorn", count = 1}, {name = "Empty Vial", count = 1}} },
    { id = 2334,  name = "Elixir of Poison Resistance", namePT = "Elixir de Resistência a Veneno", prof = "ALCHEMY", skill = 120, category = "Elixirs", categoryPT = "Elixires", quality = 2, icon = "Interface\\Icons\\INV_Potion_14", reagents = {{name = "Large Venom Sac", count = 1}, {name = "Bruiseweed", count = 1}, {name = "Leaded Vial", count = 1}} },
    { id = 2337,  name = "Lesser Mana Potion", namePT = "Poção Inferior de Mana", prof = "ALCHEMY", skill = 120, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_75", reagents = {{name = "Mageroyal", count = 1}, {name = "Briarthorn", count = 1}, {name = "Empty Vial", count = 1}} },
    { id = 3173,  name = "Healing Potion", namePT = "Poção de Cura", prof = "ALCHEMY", skill = 110, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_53", reagents = {{name = "Bruiseweed", count = 1}, {name = "Briarthorn", count = 1}, {name = "Leaded Vial", count = 1}} },
    { id = 3176,  name = "Mana Potion", namePT = "Poção de Mana", prof = "ALCHEMY", skill = 160, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_76", reagents = {{name = "Kingsblood", count = 1}, {name = "Wild Steelbloom", count = 1}, {name = "Leaded Vial", count = 1}} },
    { id = 3177,  name = "Greater Healing Potion", namePT = "Poção Maior de Cura", prof = "ALCHEMY", skill = 155, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_54", reagents = {{name = "Liferoot", count = 1}, {name = "Kingsblood", count = 1}, {name = "Leaded Vial", count = 1}} },
    { id = 11450, name = "Elixir of Greater Agility", namePT = "Elixir Maior de Agilidade", prof = "ALCHEMY", skill = 240, category = "Elixirs", categoryPT = "Elixires", quality = 1, icon = "Interface\\Icons\\INV_Potion_94", reagents = {{name = "Sungrass", count = 1}, {name = "Goldthorn", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 11451, name = "Elixir of Giants", namePT = "Elixir dos Gigantes", prof = "ALCHEMY", skill = 245, category = "Elixirs", categoryPT = "Elixires", quality = 2, icon = "Interface\\Icons\\INV_Potion_61", reagents = {{name = "Sungrass", count = 1}, {name = "Gromsblood", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 11457, name = "Superior Healing Potion", namePT = "Poção Superior de Cura", prof = "ALCHEMY", skill = 215, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_55", reagents = {{name = "Sungrass", count = 1}, {name = "Khagdar's Whisker", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 11458, name = "Greater Mana Potion", namePT = "Poção Maior de Mana", prof = "ALCHEMY", skill = 205, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_77", reagents = {{name = "Goldthorn", count = 1}, {name = "Khagdar's Whisker", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17551, name = "Major Healing Potion", namePT = "Poção Potente de Cura", prof = "ALCHEMY", skill = 275, category = "Potions", categoryPT = "Poções", quality = 1, icon = "Interface\\Icons\\INV_Potion_56", reagents = {{name = "Golden Sansam", count = 2}, {name = "Mountain Silversage", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17552, name = "Major Mana Potion", namePT = "Poção Potente de Mana", prof = "ALCHEMY", skill = 295, category = "Potions", categoryPT = "Poções", quality = 2, icon = "Interface\\Icons\\INV_Potion_78", reagents = {{name = "Dreamfoil", count = 3}, {name = "Icecap", count = 2}, {name = "Crystal Vial", count = 1}} },
    { id = 17556, name = "Elixir of the Mongoose", namePT = "Elixir do Mangusto", prof = "ALCHEMY", skill = 280, category = "Elixirs", categoryPT = "Elixires", quality = 2, icon = "Interface\\Icons\\INV_Potion_32", reagents = {{name = "Mountain Silversage", count = 2}, {name = "Plaguebloom", count = 2}, {name = "Crystal Vial", count = 1}} },
    { id = 17554, name = "Greater Arcane Elixir", namePT = "Elixir Arcano Maior", prof = "ALCHEMY", skill = 285, category = "Elixirs", categoryPT = "Elixires", quality = 2, icon = "Interface\\Icons\\INV_Potion_25", reagents = {{name = "Dreamfoil", count = 3}, {name = "Mountain Silversage", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17555, name = "Elixir of Superior Defense", namePT = "Elixir de Defesa Superior", prof = "ALCHEMY", skill = 265, category = "Elixirs", categoryPT = "Elixires", quality = 1, icon = "Interface\\Icons\\INV_Potion_66", reagents = {{name = "Stonescale Oil", count = 2}, {name = "Sungrass", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17557, name = "Elixir of Brute Force", namePT = "Elixir de Força Bruta", prof = "ALCHEMY", skill = 275, category = "Elixirs", categoryPT = "Elixires", quality = 2, icon = "Interface\\Icons\\INV_Potion_62", reagents = {{name = "Gromsblood", count = 2}, {name = "Golden Sansam", count = 2}, {name = "Crystal Vial", count = 1}} },
    { id = 17574, name = "Free Action Potion", namePT = "Poção de Ação Livre", prof = "ALCHEMY", skill = 150, category = "Potions", categoryPT = "Poções", quality = 2, icon = "Interface\\Icons\\INV_Potion_04", reagents = {{name = "Blackmouth Oil", count = 2}, {name = "Stranglekelp", count = 1}, {name = "Leaded Vial", count = 1}} },
    { id = 17575, name = "Living Action Potion", namePT = "Poção de Ação Viva", prof = "ALCHEMY", skill = 285, category = "Potions", categoryPT = "Poções", quality = 2, icon = "Interface\\Icons\\INV_Potion_07", reagents = {{name = "Icecap", count = 2}, {name = "Mountain Silversage", count = 2}, {name = "Heart of the Wild", count = 2}, {name = "Crystal Vial", count = 1}} },
    { id = 17576, name = "Invisibility Potion", namePT = "Poção de Invisibilidade", prof = "ALCHEMY", skill = 175, category = "Potions", categoryPT = "Poções", quality = 2, icon = "Interface\\Icons\\INV_Potion_18", reagents = {{name = "Ghost Mushroom", count = 1}, {name = "Sungrass", count = 1}, {name = "Leaded Vial", count = 1}} },
    { id = 17577, name = "Restorative Potion", namePT = "Poção Restauradora", prof = "ALCHEMY", skill = 210, category = "Potions", categoryPT = "Poções", quality = 2, icon = "Interface\\Icons\\INV_Potion_01", reagents = {{name = "Elemental Earth", count = 1}, {name = "Goldthorn", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17578, name = "Mageblood Potion", namePT = "Poção de Sangue de Mago", prof = "ALCHEMY", skill = 275, category = "Potions", categoryPT = "Poções", quality = 2, icon = "Interface\\Icons\\INV_Potion_45", reagents = {{name = "Dreamfoil", count = 1}, {name = "Plaguebloom", count = 2}, {name = "Crystal Vial", count = 1}} },
    -- Poções de Proteção
    { id = 17559, name = "Greater Fire Protection Potion", namePT = "Poção Maior de Proteção contra o Fogo", prof = "ALCHEMY", skill = 290, category = "Protection", categoryPT = "Proteção", quality = 2, icon = "Interface\\Icons\\INV_Potion_24", reagents = {{name = "Elemental Fire", count = 1}, {name = "Dreamfoil", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17560, name = "Greater Frost Protection Potion", namePT = "Poção Maior de Proteção contra o Gelo", prof = "ALCHEMY", skill = 290, category = "Protection", categoryPT = "Proteção", quality = 2, icon = "Interface\\Icons\\INV_Potion_20", reagents = {{name = "Elemental Water", count = 1}, {name = "Dreamfoil", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17561, name = "Greater Nature Protection Potion", namePT = "Poção Maior de Proteção contra a Natureza", prof = "ALCHEMY", skill = 290, category = "Protection", categoryPT = "Proteção", quality = 2, icon = "Interface\\Icons\\INV_Potion_22", reagents = {{name = "Elemental Earth", count = 1}, {name = "Dreamfoil", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17562, name = "Greater Shadow Protection Potion", namePT = "Poção Maior de Proteção contra a Sombra", prof = "ALCHEMY", skill = 290, category = "Protection", categoryPT = "Proteção", quality = 2, icon = "Interface\\Icons\\INV_Potion_23", reagents = {{name = "Shadow Oil", count = 1}, {name = "Dreamfoil", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17563, name = "Greater Arcane Protection Potion", namePT = "Poção Maior de Proteção Arcana", prof = "ALCHEMY", skill = 290, category = "Protection", categoryPT = "Proteção", quality = 2, icon = "Interface\\Icons\\INV_Potion_83", reagents = {{name = "Dream Dust", count = 1}, {name = "Dreamfoil", count = 1}, {name = "Crystal Vial", count = 1}} },
    -- Frascos (Flasks)
    { id = 17626, name = "Flask of the Titans", namePT = "Frasco dos Titãs", prof = "ALCHEMY", skill = 300, category = "Flasks", categoryPT = "Frascos", quality = 3, icon = "Interface\\Icons\\INV_Potion_62", reagents = {{name = "Gromsblood", count = 30}, {name = "Stonescale Oil", count = 10}, {name = "Black Lotus", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17627, name = "Flask of Distilled Wisdom", namePT = "Frasco de Sabedoria Destilada", prof = "ALCHEMY", skill = 300, category = "Flasks", categoryPT = "Frascos", quality = 3, icon = "Interface\\Icons\\INV_Potion_41", reagents = {{name = "Dreamfoil", count = 30}, {name = "Icecap", count = 10}, {name = "Black Lotus", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17628, name = "Flask of Supreme Power", namePT = "Frasco de Poder Supremo", prof = "ALCHEMY", skill = 300, category = "Flasks", categoryPT = "Frascos", quality = 3, icon = "Interface\\Icons\\INV_Potion_41", reagents = {{name = "Dreamfoil", count = 30}, {name = "Mountain Silversage", count = 10}, {name = "Black Lotus", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17629, name = "Flask of Chromatic Resistance", namePT = "Frasco de Resistência Cromática", prof = "ALCHEMY", skill = 300, category = "Flasks", categoryPT = "Frascos", quality = 3, icon = "Interface\\Icons\\INV_Potion_63", reagents = {{name = "Icecap", count = 30}, {name = "Mountain Silversage", count = 10}, {name = "Black Lotus", count = 1}, {name = "Crystal Vial", count = 1}} },
    { id = 17630, name = "Flask of Petrification", namePT = "Frasco de Petrificação", prof = "ALCHEMY", skill = 300, category = "Flasks", categoryPT = "Frascos", quality = 3, icon = "Interface\\Icons\\INV_Potion_26", reagents = {{name = "Stonescale Oil", count = 30}, {name = "Mountain Silversage", count = 10}, {name = "Black Lotus", count = 1}, {name = "Crystal Vial", count = 1}} },
    -- Transmutações (Transmutes)
    { id = 17187, name = "Transmute: Arcanite", namePT = "Transmutar: Arcanita", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\INV_Misc_Stone_02", reagents = {{name = "Thorium Bar", count = 1}, {name = "Arcane Crystal", count = 1}} },
    { id = 17186, name = "Transmute: Iron to Gold", namePT = "Transmutar: Ferro em Ouro", prof = "ALCHEMY", skill = 225, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\INV_Ingot_03", reagents = {{name = "Iron Bar", count = 1}} },
    { id = 17564, name = "Transmute: Air to Fire", namePT = "Transmutar: Ar em Fogo", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Fire_FlameBlades", reagents = {{name = "Essence of Air", count = 1}} },
    { id = 17565, name = "Transmute: Fire to Earth", namePT = "Transmutar: Fogo em Terra", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Earthquake", reagents = {{name = "Essence of Fire", count = 1}} },
    { id = 17566, name = "Transmute: Earth to Water", namePT = "Transmutar: Terra em Água", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental", reagents = {{name = "Essence of Earth", count = 1}} },
    { id = 17567, name = "Transmute: Water to Air", namePT = "Transmutar: Água em Ar", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Cyclone", reagents = {{name = "Essence of Water", count = 1}} },
    { id = 17568, name = "Transmute: Undeath to Water", namePT = "Transmutar: Morte-viva em Água", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Shadow_DeathScream", reagents = {{name = "Essence of Undeath", count = 1}} },
    { id = 17569, name = "Transmute: Water to Undeath", namePT = "Transmutar: Água em Morte-viva", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Shadow_DeathScream", reagents = {{name = "Essence of Water", count = 1}} },
    { id = 17570, name = "Transmute: Life to Earth", namePT = "Transmutar: Vida em Terra", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow", reagents = {{name = "Living Essence", count = 1}} },
    { id = 17571, name = "Transmute: Earth to Life", namePT = "Transmutar: Terra em Vida", prof = "ALCHEMY", skill = 275, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow", reagents = {{name = "Essence of Earth", count = 1}} },
    { id = 17572, name = "Transmute: Elemental Fire", namePT = "Transmutar: Fogo Elemental", prof = "ALCHEMY", skill = 300, category = "Transmutes", categoryPT = "Transmutações", quality = 2, icon = "Interface\\Icons\\Spell_Fire_Fire", reagents = {{name = "Heart of Fire", count = 1}} },
    -- Itens Especiais
    { id = 11479, name = "Philosopher's Stone", namePT = "Pedra Filosofal", prof = "ALCHEMY", skill = 225, category = "Special", categoryPT = "Especial", quality = 2, icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01", reagents = {{name = "Iron Bar", count = 4}, {name = "Black Vitriol", count = 1}, {name = "Purple Lotus", count = 4}, {name = "Firebloom", count = 4}} },

    -- =========================================================================
    -- 2. ALFAIATARIA (TAILORING)
    -- =========================================================================
    -- Bolsas (Bags)
    { id = 2963,  name = "Linen Bag", namePT = "Bolsa de Linho (6)", prof = "TAILORING", skill = 45, category = "Bags", categoryPT = "Bolsas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Bag_08", reagents = {{name = "Bolt of Linen Cloth", count = 3}, {name = "Coarse Thread", count = 3}} },
    { id = 2964,  name = "Woolen Bag", namePT = "Bolsa de Lã (8)", prof = "TAILORING", skill = 80, category = "Bags", categoryPT = "Bolsas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Bag_10_Green", reagents = {{name = "Bolt of Woolen Cloth", count = 3}, {name = "Fine Thread", count = 1}} },
    { id = 3914,  name = "Small Silk Pack", namePT = "Mochila Pequena de Seda (10)", prof = "TAILORING", skill = 150, category = "Bags", categoryPT = "Bolsas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Bag_10_Red", reagents = {{name = "Bolt of Silk Cloth", count = 4}, {name = "Heavy Silken Thread", count = 2}} },
    { id = 12044, name = "Mageweave Bag", namePT = "Bolsa de Magitrama (12)", prof = "TAILORING", skill = 225, category = "Bags", categoryPT = "Bolsas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Bag_11", reagents = {{name = "Bolt of Mageweave", count = 4}, {name = "Silken Thread", count = 2}} },
    { id = 18401, name = "Runecloth Bag", namePT = "Bolsa de Runatrama (14)", prof = "TAILORING", skill = 260, category = "Bags", categoryPT = "Bolsas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Bag_19", reagents = {{name = "Bolt of Runecloth", count = 5}, {name = "Rugged Leather", count = 2}, {name = "Rune Thread", count = 1}} },
    { id = 18402, name = "Mooncloth Bag", namePT = "Bolsa de Lunatrama (16)", prof = "TAILORING", skill = 300, category = "Bags", categoryPT = "Bolsas", quality = 2, icon = "Interface\\Icons\\INV_Misc_Bag_14", reagents = {{name = "Mooncloth", count = 1}, {name = "Bolt of Runecloth", count = 4}, {name = "Rune Thread", count = 1}} },
    { id = 18403, name = "Bottomless Bag", namePT = "Bolsa sem Fundo (18)", prof = "TAILORING", skill = 300, category = "Bags", categoryPT = "Bolsas", quality = 3, icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue", reagents = {{name = "Mooncloth", count = 8}, {name = "Bolt of Runecloth", count = 12}, {name = "Core of Earth", count = 2}, {name = "Rune Thread", count = 2}} },
    { id = 26085, name = "Core Felcloth Bag", namePT = "Bolsa de Ignitrama do Núcleo (28)", prof = "TAILORING", skill = 300, category = "Bags", categoryPT = "Bolsas", quality = 4, icon = "Interface\\Icons\\INV_Misc_Bag_CoreFelclothBag", reagents = {{name = "Core of Earth", count = 4}, {name = "Felcloth", count = 20}, {name = "Mooncloth", count = 4}, {name = "Rune Thread", count = 4}} },
    -- Itens de Raid / Épicos
    { id = 18413, name = "Robe of the Archmage", namePT = "Robe do Arquimago", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Chest_Cloth_23", reagents = {{name = "Bolt of Runecloth", count = 12}, {name = "Mooncloth", count = 10}, {name = "Essence of Fire", count = 10}, {name = "Essence of Water", count = 10}, {name = "Essence of Air", count = 10}, {name = "Rune Thread", count = 2}} },
    { id = 18414, name = "Robe of the Void", namePT = "Robe do Vazio", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Chest_Cloth_24", reagents = {{name = "Felcloth", count = 40}, {name = "Mooncloth", count = 12}, {name = "Essence of Undeath", count = 20}, {name = "Demonic Rune", count = 20}, {name = "Rune Thread", count = 4}} },
    { id = 18415, name = "Truefaith Vestments", namePT = "Vestimenta da Fé Verdadeira", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Chest_Cloth_21", reagents = {{name = "Mooncloth", count = 10}, {name = "Bolt of Runecloth", count = 14}, {name = "Righteous Orb", count = 4}, {name = "Golden Pearl", count = 4}, {name = "Illusion Dust", count = 10}, {name = "Rune Thread", count = 2}} },
    { id = 24268, name = "Bloodvine Vest", namePT = "Colete da Vinha Sangrenta", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Chest_Cloth_14", reagents = {{name = "Bloodvine", count = 3}, {name = "Mooncloth", count = 3}, {name = "Bolt of Runecloth", count = 4}, {name = "Ironweb Spider Silk", count = 4}, {name = "Rune Thread", count = 2}} },
    { id = 24269, name = "Bloodvine Leggings", namePT = "Perneiras da Vinha Sangrenta", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Pants_Cloth_14", reagents = {{name = "Bloodvine", count = 4}, {name = "Mooncloth", count = 4}, {name = "Bolt of Runecloth", count = 4}, {name = "Ironweb Spider Silk", count = 4}, {name = "Rune Thread", count = 2}} },
    { id = 24270, name = "Bloodvine Boots", namePT = "Botas da Vinha Sangrenta", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Boots_Cloth_05", reagents = {{name = "Bloodvine", count = 3}, {name = "Mooncloth", count = 3}, {name = "Bolt of Runecloth", count = 3}, {name = "Ironweb Spider Silk", count = 4}, {name = "Rune Thread", count = 2}} },
    { id = 23971, name = "Flarecore Robe", namePT = "Robe Núcleo de Fogo", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Chest_Cloth_17", reagents = {{name = "Fiery Core", count = 5}, {name = "Lava Core", count = 2}, {name = "Felcloth", count = 16}, {name = "Bolt of Runecloth", count = 8}, {name = "Rune Thread", count = 3}} },
    { id = 23972, name = "Flarecore Leggings", namePT = "Perneiras Núcleo de Fogo", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Pants_Cloth_17", reagents = {{name = "Fiery Core", count = 6}, {name = "Lava Core", count = 2}, {name = "Felcloth", count = 16}, {name = "Bolt of Runecloth", count = 6}, {name = "Rune Thread", count = 3}} },
    { id = 18408, name = "Mooncloth Robe", namePT = "Robe de Lunatrama", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Chest_Cloth_04", reagents = {{name = "Mooncloth", count = 6}, {name = "Bolt of Runecloth", count = 6}, {name = "Golden Pearl", count = 2}, {name = "Rune Thread", count = 2}} },
    { id = 18410, name = "Felcloth Robe", namePT = "Robe de Ignitrama", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Chest_Cloth_09", reagents = {{name = "Felcloth", count = 6}, {name = "Bolt of Runecloth", count = 4}, {name = "Demonic Rune", count = 2}, {name = "Rune Thread", count = 2}} },
    { id = 18411, name = "Ghostweave Vest", namePT = "Colete de Espectrotrama", prof = "TAILORING", skill = 290, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Chest_Cloth_15", reagents = {{name = "Bolt of Runecloth", count = 6}, {name = "Ghost Dye", count = 2}, {name = "Rune Thread", count = 1}} },
    { id = 18412, name = "Belt of the Archmage", namePT = "Cinto do Arquimago", prof = "TAILORING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Belt_03", reagents = {{name = "Bolt of Runecloth", count = 16}, {name = "Mooncloth", count = 10}, {name = "Essence of Fire", count = 10}, {name = "Essence of Water", count = 10}, {name = "Essence of Earth", count = 10}, {name = "Rune Thread", count = 2}} },
    { id = 18407, name = "Mooncloth", namePT = "Lunatrama", prof = "TAILORING", skill = 250, category = "Special", categoryPT = "Especial", quality = 2, icon = "Interface\\Icons\\INV_Fabric_Mooncloth_01", reagents = {{name = "Felcloth", count = 2}} },

    -- =========================================================================
    -- 3. COURARIA (LEATHERWORKING)
    -- =========================================================================
    -- Receitas de Nível 1 a 150 (Leveling & Custom)
    { id = 90001, name = "Camp Tent", namePT = "Barraca de Acampamento", prof = "LEATHERWORKING", skill = 1, category = "Camping", categoryPT = "Acampamento", quality = 1, icon = "Interface\\Icons\\INV_Misc_Toy_07", reagents = {{name = "Light Leather", count = 5}} },
    { id = 2159,  name = "Light Armor Kit", namePT = "Kit de Armadura Leve (+8)", prof = "LEATHERWORKING", skill = 1, category = "Kits", categoryPT = "Kits de Reforço", quality = 1, icon = "Interface\\Icons\\INV_Misc_ArmorKit_01", reagents = {{name = "Light Leather", count = 1}} },
    { id = 2149,  name = "Handstitched Leather Boots", namePT = "Botas de Couro Costuradas à Mão", prof = "LEATHERWORKING", skill = 1, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Boots_07", reagents = {{name = "Light Leather", count = 3}, {name = "Coarse Thread", count = 1}} },
    { id = 2152,  name = "Handstitched Leather Pants", namePT = "Calças de Couro Costuradas à Mão", prof = "LEATHERWORKING", skill = 1, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Pants_02", reagents = {{name = "Light Leather", count = 4}, {name = "Coarse Thread", count = 1}} },
    { id = 2153,  name = "Handstitched Leather Vest", namePT = "Colete de Couro Costurado à Mão", prof = "LEATHERWORKING", skill = 1, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Chest_Leather_06", reagents = {{name = "Light Leather", count = 3}, {name = "Coarse Thread", count = 1}} },
    { id = 2154,  name = "Handstitched Leather Cloak", namePT = "Capa de Couro Costurada à Mão", prof = "LEATHERWORKING", skill = 1, category = "Cloaks", categoryPT = "Capas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Cape_11", reagents = {{name = "Light Leather", count = 2}, {name = "Coarse Thread", count = 1}} },
    { id = 2155,  name = "Handstitched Leather Bracers", namePT = "Braçadeiras de Couro Costuradas à Mão", prof = "LEATHERWORKING", skill = 1, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Bracer_07", reagents = {{name = "Light Leather", count = 2}, {name = "Coarse Thread", count = 1}} },
    { id = 2158,  name = "Handstitched Leather Belt", namePT = "Cinto de Couro Costurado à Mão", prof = "LEATHERWORKING", skill = 1, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Belt_03", reagents = {{name = "Light Leather", count = 6}, {name = "Coarse Thread", count = 1}} },
    { id = 2150,  name = "Light Leather", namePT = "Couro Leve", prof = "LEATHERWORKING", skill = 1, category = "Reagents", categoryPT = "Reagentes", quality = 1, icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03", reagents = {{name = "Ruined Leather Scraps", count = 3}} },
    { id = 2160,  name = "Cured Light Hide", namePT = "Pele Leve Curada", prof = "LEATHERWORKING", skill = 35, category = "Reagents", categoryPT = "Reagentes", quality = 1, icon = "Interface\\Icons\\INV_Misc_Pelt_Boar_01", reagents = {{name = "Light Hide", count = 1}, {name = "Salt", count = 1}} },
    { id = 7365,  name = "Light Leather Quiver", namePT = "Aljava de Couro Leve", prof = "LEATHERWORKING", skill = 30, category = "Quivers", categoryPT = "Aljavas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Quiver_01", reagents = {{name = "Light Leather", count = 4}, {name = "Coarse Thread", count = 2}} },
    { id = 7366,  name = "Small Leather Ammo Pouch", namePT = "Bolsa de Munição Pequena de Couro", prof = "LEATHERWORKING", skill = 30, category = "Ammo Pouches", categoryPT = "Bolsas de Munição", quality = 1, icon = "Interface\\Icons\\INV_Misc_AmmoPouch_01", reagents = {{name = "Light Leather", count = 3}, {name = "Coarse Thread", count = 4}} },
    { id = 2163,  name = "Embossed Leather Vest", namePT = "Colete de Couro em Relevo", prof = "LEATHERWORKING", skill = 55, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Chest_Leather_06", reagents = {{name = "Light Leather", count = 8}, {name = "Coarse Thread", count = 2}} },
    { id = 2164,  name = "Embossed Leather Boots", namePT = "Botas de Couro em Relevo", prof = "LEATHERWORKING", skill = 55, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Boots_07", reagents = {{name = "Light Leather", count = 8}, {name = "Coarse Thread", count = 2}} },
    { id = 2165,  name = "Embossed Leather Cloak", namePT = "Capa de Couro em Relevo", prof = "LEATHERWORKING", skill = 60, category = "Cloaks", categoryPT = "Capas", quality = 1, icon = "Interface\\Icons\\INV_Misc_Cape_17", reagents = {{name = "Light Leather", count = 5}, {name = "Coarse Thread", count = 2}} },
    { id = 2166,  name = "Embossed Leather Gloves", namePT = "Luvas de Couro em Relevo", prof = "LEATHERWORKING", skill = 60, category = "Armor", categoryPT = "Armadura", quality = 1, icon = "Interface\\Icons\\INV_Gauntlets_19", reagents = {{name = "Light Leather", count = 8}, {name = "Coarse Thread", count = 2}} },
    { id = 7138,  name = "Hillman's Leather Vest", namePT = "Colete de Couro de Homem das Colinas", prof = "LEATHERWORKING", skill = 80, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Chest_Leather_08", reagents = {{name = "Medium Leather", count = 7}, {name = "Fine Thread", count = 2}} },
    { id = 7139,  name = "Hillman's Belt", namePT = "Cinto de Homem das Colinas", prof = "LEATHERWORKING", skill = 80, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Belt_03", reagents = {{name = "Medium Leather", count = 5}, {name = "Fine Thread", count = 1}} },
    { id = 7126,  name = "Medium Leather", namePT = "Couro Médio", prof = "LEATHERWORKING", skill = 100, category = "Reagents", categoryPT = "Reagentes", quality = 1, icon = "Interface\\Icons\\INV_Misc_LeatherScrap_05", reagents = {{name = "Light Leather", count = 4}} },
    { id = 7127,  name = "Cured Medium Hide", namePT = "Pele Média Curada", prof = "LEATHERWORKING", skill = 100, category = "Reagents", categoryPT = "Reagentes", quality = 1, icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", reagents = {{name = "Medium Hide", count = 1}, {name = "Salt", count = 1}} },
    { id = 7128,  name = "Medium Armor Kit", namePT = "Kit de Armadura Média (+16)", prof = "LEATHERWORKING", skill = 100, category = "Kits", categoryPT = "Kits de Reforço", quality = 1, icon = "Interface\\Icons\\INV_Misc_ArmorKit_02", reagents = {{name = "Medium Leather", count = 1}} },
    { id = 2161,  name = "Dark Leather Boots", namePT = "Botas de Couro Escuro", prof = "LEATHERWORKING", skill = 100, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Boots_05", reagents = {{name = "Medium Leather", count = 4}, {name = "Fine Thread", count = 2}, {name = "Gray Dye", count = 1}} },
    { id = 2162,  name = "Dark Leather Cloak", namePT = "Capa de Couro Escuro", prof = "LEATHERWORKING", skill = 100, category = "Cloaks", categoryPT = "Capas", quality = 2, icon = "Interface\\Icons\\INV_Misc_Cape_19", reagents = {{name = "Medium Leather", count = 8}, {name = "Fine Thread", count = 1}, {name = "Gray Dye", count = 1}} },
    { id = 2881,  name = "Dark Leather Belt", namePT = "Cinto de Couro Escuro", prof = "LEATHERWORKING", skill = 100, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Belt_03", reagents = {{name = "Medium Leather", count = 6}, {name = "Fine Thread", count = 1}, {name = "Gray Dye", count = 1}} },
    { id = 2882,  name = "Dark Leather Pants", namePT = "Calças de Couro Escuro", prof = "LEATHERWORKING", skill = 115, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Pants_02", reagents = {{name = "Medium Leather", count = 12}, {name = "Fine Thread", count = 2}, {name = "Gray Dye", count = 1}} },
    { id = 2883,  name = "Dark Leather Tunic", namePT = "Túnica de Couro Escuro", prof = "LEATHERWORKING", skill = 115, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Chest_Leather_06", reagents = {{name = "Medium Leather", count = 7}, {name = "Fine Thread", count = 1}, {name = "Gray Dye", count = 1}} },
    { id = 2884,  name = "Dark Leather Shoulders", namePT = "Omoplatas de Couro Escuro", prof = "LEATHERWORKING", skill = 120, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Shoulder_08", reagents = {{name = "Medium Leather", count = 8}, {name = "Fine Thread", count = 1}, {name = "Gray Dye", count = 1}} },
    { id = 2885,  name = "Dark Leather Gloves", namePT = "Luvas de Couro Escuro", prof = "LEATHERWORKING", skill = 120, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Gauntlets_19", reagents = {{name = "Medium Leather", count = 4}, {name = "Fine Thread", count = 2}, {name = "Gray Dye", count = 1}} },
    { id = 7133,  name = "Heavy Armor Kit", namePT = "Kit de Armadura Pesada (+24)", prof = "LEATHERWORKING", skill = 150, category = "Kits", categoryPT = "Kits de Reforço", quality = 1, icon = "Interface\\Icons\\INV_Misc_ArmorKit_03", reagents = {{name = "Heavy Leather", count = 5}, {name = "Fine Thread", count = 1}} },
    { id = 7135,  name = "Cured Heavy Hide", namePT = "Pele Pesada Curada", prof = "LEATHERWORKING", skill = 150, category = "Reagents", categoryPT = "Reagentes", quality = 1, icon = "Interface\\Icons\\INV_Misc_Pelt_Bear_01", reagents = {{name = "Heavy Hide", count = 1}, {name = "Salt", count = 3}} },
    { id = 7136,  name = "Heavy Leather", namePT = "Couro Pesado", prof = "LEATHERWORKING", skill = 150, category = "Reagents", categoryPT = "Reagentes", quality = 1, icon = "Interface\\Icons\\INV_Misc_LeatherScrap_07", reagents = {{name = "Medium Leather", count = 5}} },
    -- Devilsaur & Épicos
    { id = 19047, name = "Devilsaur Gauntlets", namePT = "Manoplas de Demossauro", prof = "LEATHERWORKING", skill = 290, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Gauntlets_26", reagents = {{name = "Devilsaur Leather", count = 28}, {name = "Rugged Hide", count = 1}, {name = "Rune Thread", count = 2}} },
    { id = 19048, name = "Devilsaur Leggings", namePT = "Perneiras de Demossauro", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Pants_06", reagents = {{name = "Devilsaur Leather", count = 30}, {name = "Rugged Hide", count = 1}, {name = "Rune Thread", count = 2}} },
    { id = 22756, name = "Hide of the Wild", namePT = "Pele do Ermo", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Misc_Cape_19", reagents = {{name = "Cured Rugged Hide", count = 12}, {name = "Living Essence", count = 10}, {name = "Wildvine", count = 12}, {name = "Larval Acid", count = 2}, {name = "Rune Thread", count = 4}} },
    { id = 22757, name = "Shifting Cloak", namePT = "Capa Oscilante", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Misc_Cape_18", reagents = {{name = "Cured Rugged Hide", count = 8}, {name = "Essence of Air", count = 12}, {name = "Skin of Shadow", count = 4}, {name = "Guardian Stone", count = 8}, {name = "Rune Thread", count = 4}} },
    { id = 21161, name = "Corehound Boots", namePT = "Botas de Cão Magma", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 4, icon = "Interface\\Icons\\INV_Boots_08", reagents = {{name = "Corehound Leather", count = 20}, {name = "Fiery Core", count = 4}, {name = "Lava Core", count = 2}, {name = "Cured Rugged Hide", count = 8}, {name = "Rune Thread", count = 4}} },
    { id = 19050, name = "Warbear Harness", namePT = "Arnês de Urso de Guerra", prof = "LEATHERWORKING", skill = 275, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Chest_Leather_06", reagents = {{name = "Warbear Leather", count = 28}, {name = "Rugged Leather", count = 12}, {name = "Rune Thread", count = 1}} },
    { id = 19051, name = "Warbear Woolies", namePT = "Lanzudas de Urso de Guerra", prof = "LEATHERWORKING", skill = 285, category = "Armor", categoryPT = "Armadura", quality = 2, icon = "Interface\\Icons\\INV_Pants_02", reagents = {{name = "Warbear Leather", count = 24}, {name = "Rugged Leather", count = 14}, {name = "Rune Thread", count = 1}} },
    { id = 19052, name = "Stormshroud Armor", namePT = "Armadura Manto da Tempestade", prof = "LEATHERWORKING", skill = 285, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Chest_Leather_01", reagents = {{name = "Chimera Leather", count = 20}, {name = "Essence of Air", count = 4}, {name = "Rugged Leather", count = 16}, {name = "Rune Thread", count = 2}} },
    { id = 19053, name = "Stormshroud Pants", namePT = "Calças Manto da Tempestade", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Pants_04", reagents = {{name = "Chimera Leather", count = 24}, {name = "Essence of Air", count = 4}, {name = "Rugged Leather", count = 14}, {name = "Rune Thread", count = 2}} },
    { id = 19054, name = "Stormshroud Shoulders", namePT = "Omoplatas Manto da Tempestade", prof = "LEATHERWORKING", skill = 295, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Shoulder_08", reagents = {{name = "Chimera Leather", count = 16}, {name = "Essence of Air", count = 2}, {name = "Rugged Leather", count = 12}, {name = "Rune Thread", count = 1}} },
    { id = 19055, name = "Volcanic Breastplate", namePT = "Peitoral Vulcânico", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Chest_Chain_06", reagents = {{name = "Cured Rugged Hide", count = 6}, {name = "Heart of Fire", count = 4}, {name = "Elemental Fire", count = 4}, {name = "Rune Thread", count = 2}} },
    { id = 19058, name = "Black Dragonscale Breastplate", namePT = "Peitoral de Escama de Dragão Negro", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Chest_Chain_10", reagents = {{name = "Black Dragonscale", count = 40}, {name = "Cured Rugged Hide", count = 4}, {name = "Dark Iron Bar", count = 4}, {name = "Rune Thread", count = 2}} },
    { id = 19059, name = "Black Dragonscale Shoulders", namePT = "Omoplatas de Escama de Dragão Negro", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Shoulder_14", reagents = {{name = "Black Dragonscale", count = 30}, {name = "Cured Rugged Hide", count = 3}, {name = "Dark Iron Bar", count = 4}, {name = "Rune Thread", count = 2}} },
    { id = 19060, name = "Black Dragonscale Leggings", namePT = "Perneiras de Escama de Dragão Negro", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Pants_03", reagents = {{name = "Black Dragonscale", count = 40}, {name = "Cured Rugged Hide", count = 4}, {name = "Dark Iron Bar", count = 6}, {name = "Rune Thread", count = 2}} },
    { id = 19061, name = "Black Dragonscale Boots", namePT = "Botas de Escama de Dragão Negro", prof = "LEATHERWORKING", skill = 300, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Boots_Plate_01", reagents = {{name = "Black Dragonscale", count = 30}, {name = "Cured Rugged Hide", count = 3}, {name = "Dark Iron Bar", count = 4}, {name = "Rune Thread", count = 2}} },
    { id = 19062, name = "Blue Dragonscale Breastplate", namePT = "Peitoral de Escama de Dragão Azul", prof = "LEATHERWORKING", skill = 295, category = "Armor", categoryPT = "Armadura", quality = 3, icon = "Interface\\Icons\\INV_Chest_Chain_12", reagents = {{name = "Blue Dragonscale", count = 36}, {name = "Cured Rugged Hide", count = 4}, {name = "Rune Thread", count = 2}} },
    -- Kits de Armadura
    { id = 19063, name = "Rugged Armor Kit", namePT = "Kit de Armadura Robusta (+40 Armadura)", prof = "LEATHERWORKING", skill = 250, category = "Kits", categoryPT = "Kits de Reforço", quality = 1, icon = "Interface\\Icons\\INV_Misc_ArmorKit_01", reagents = {{name = "Rugged Leather", count = 5}} },
    { id = 19064, name = "Thick Armor Kit", namePT = "Kit de Armadura Grossa (+32 Armadura)", prof = "LEATHERWORKING", skill = 200, category = "Kits", categoryPT = "Kits de Reforço", quality = 1, icon = "Interface\\Icons\\INV_Misc_ArmorKit_02", reagents = {{name = "Thick Leather", count = 5}, {name = "Silken Thread", count = 1}} },
    { id = 22758, name = "Core Armor Kit", namePT = "Kit de Armadura do Núcleo (+3 Defesa)", prof = "LEATHERWORKING", skill = 300, category = "Kits", categoryPT = "Kits de Reforço", quality = 2, icon = "Interface\\Icons\\INV_Misc_ArmorKit_03", reagents = {{name = "Corehound Leather", count = 3}} },
    -- Aljavas & Coldres
    { id = 19065, name = "Quickdraw Quiver", namePT = "Aljava do Saque Rápido (18 slots, +15% Vel)", prof = "LEATHERWORKING", skill = 275, category = "Bags", categoryPT = "Aljavas", quality = 2, icon = "Interface\\Icons\\INV_Misc_Quiver_02", reagents = {{name = "Rugged Leather", count = 16}, {name = "Cured Rugged Hide", count = 2}, {name = "Rune Thread", count = 2}} },
    { id = 19066, name = "Heavy Leather Ammo Pouch", namePT = "Bolsa de Munição de Couro Pesado (16)", prof = "LEATHERWORKING", skill = 275, category = "Bags", categoryPT = "Aljavas", quality = 2, icon = "Interface\\Icons\\INV_Misc_AmmoPouch_01", reagents = {{name = "Rugged Leather", count = 16}, {name = "Cured Rugged Hide", count = 2}, {name = "Rune Thread", count = 2}} },

    -- =========================================================================
    -- 4. ENCANTAMENTO (ENCHANTING)
    -- =========================================================================
    -- Armas (Weapon)
    { id = 20034, name = "Enchant Weapon - Crusader", namePT = "Encantamento de Arma - Cruzado", prof = "ENCHANTING", skill = 300, category = "Weapon", categoryPT = "Armas", quality = 3, icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength", reagents = {{name = "Large Brilliant Shard", count = 4}, {name = "Righteous Orb", count = 2}, {name = "Illusion Dust", count = 10}} },
    { id = 22749, name = "Enchant Weapon - Healing Power", namePT = "Encantamento de Arma - Poder de Cura (+55)", prof = "ENCHANTING", skill = 300, category = "Weapon", categoryPT = "Armas", quality = 3, icon = "Interface\\Icons\\Spell_Holy_GreaterHeal", reagents = {{name = "Large Brilliant Shard", count = 4}, {name = "Greater Eternal Essence", count = 8}, {name = "Living Essence", count = 6}, {name = "Righteous Orb", count = 1}} },
    { id = 22750, name = "Enchant Weapon - Spell Power", namePT = "Encantamento de Arma - Poder Mágico (+30)", prof = "ENCHANTING", skill = 300, category = "Weapon", categoryPT = "Armas", quality = 3, icon = "Interface\\Icons\\Spell_Holy_Dizzy", reagents = {{name = "Large Brilliant Shard", count = 4}, {name = "Greater Eternal Essence", count = 12}, {name = "Essence of Fire", count = 4}, {name = "Essence of Water", count = 4}, {name = "Essence of Air", count = 4}, {name = "Golden Pearl", count = 2}} },
    { id = 23801, name = "Enchant Weapon - Agility", namePT = "Encantamento de Arma - Agilidade (+15)", prof = "ENCHANTING", skill = 290, category = "Weapon", categoryPT = "Armas", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Large Brilliant Shard", count = 6}, {name = "Greater Eternal Essence", count = 6}, {name = "Illusion Dust", count = 4}, {name = "Essence of Air", count = 2}} },
    { id = 23802, name = "Enchant 2H Weapon - Agility", namePT = "Encantamento de Arma de 2M - Agilidade (+25)", prof = "ENCHANTING", skill = 290, category = "Weapon", categoryPT = "Armas", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Large Brilliant Shard", count = 10}, {name = "Greater Eternal Essence", count = 6}, {name = "Illusion Dust", count = 14}, {name = "Essence of Air", count = 4}} },
    { id = 20032, name = "Enchant Weapon - Lifestealing", namePT = "Encantamento de Arma - Roubo de Vida", prof = "ENCHANTING", skill = 300, category = "Weapon", categoryPT = "Armas", quality = 3, icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02", reagents = {{name = "Large Brilliant Shard", count = 6}, {name = "Essence of Undeath", count = 6}, {name = "Living Essence", count = 6}} },
    { id = 20033, name = "Enchant Weapon - Unholy Weapon", namePT = "Encantamento de Arma - Arma Profana", prof = "ENCHANTING", skill = 295, category = "Weapon", categoryPT = "Armas", quality = 2, icon = "Interface\\Icons\\Spell_Shadow_Requiem", reagents = {{name = "Large Brilliant Shard", count = 4}, {name = "Essence of Undeath", count = 4}} },
    { id = 13890, name = "Enchant Weapon - Fiery Weapon", namePT = "Encantamento de Arma - Arma Flamejante", prof = "ENCHANTING", skill = 265, category = "Weapon", categoryPT = "Armas", quality = 2, icon = "Interface\\Icons\\Spell_Fire_Immolation", reagents = {{name = "Small Radiant Shard", count = 4}, {name = "Essence of Fire", count = 1}} },
    { id = 20029, name = "Enchant Weapon - Superior Striking", namePT = "Encantamento de Arma - Ataque Superior (+5 Dano)", prof = "ENCHANTING", skill = 295, category = "Weapon", categoryPT = "Armas", quality = 1, icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingOfKings", reagents = {{name = "Large Brilliant Shard", count = 2}, {name = "Greater Eternal Essence", count = 10}} },
    { id = 20030, name = "Enchant 2H Weapon - Superior Impact", namePT = "Encantamento de 2M - Impacto Superior (+9 Dano)", prof = "ENCHANTING", skill = 295, category = "Weapon", categoryPT = "Armas", quality = 1, icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingOfKings", reagents = {{name = "Large Brilliant Shard", count = 4}, {name = "Illusion Dust", count = 10}} },
    -- Peitoral (Chest)
    { id = 20025, name = "Enchant Chest - Greater Stats", namePT = "Encantamento de Peitoral - Atributos Maiores (+4)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", reagents = {{name = "Large Brilliant Shard", count = 4}, {name = "Greater Eternal Essence", count = 10}, {name = "Illusion Dust", count = 15}} },
    { id = 20026, name = "Enchant Chest - Major Health", namePT = "Encantamento de Peitoral - Vida Potente (+100)", prof = "ENCHANTING", skill = 275, category = "Armor", categoryPT = "Armaduras", quality = 1, icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", reagents = {{name = "Illusion Dust", count = 6}, {name = "Small Brilliant Shard", count = 1}} },
    { id = 20028, name = "Enchant Chest - Major Mana", namePT = "Encantamento de Peitoral - Mana Potente (+100)", prof = "ENCHANTING", skill = 290, category = "Armor", categoryPT = "Armaduras", quality = 1, icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", reagents = {{name = "Greater Eternal Essence", count = 3}, {name = "Small Brilliant Shard", count = 1}} },
    -- Braçadeiras (Bracer)
    { id = 20010, name = "Enchant Bracer - Superior Stamina", namePT = "Encantamento de Braçadeira - Vigor Superior (+9)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", reagents = {{name = "Illusion Dust", count = 15}} },
    { id = 20011, name = "Enchant Bracer - Superior Strength", namePT = "Encantamento de Braçadeira - Força Superior (+9)", prof = "ENCHANTING", skill = 295, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", reagents = {{name = "Illusion Dust", count = 6}, {name = "Greater Eternal Essence", count = 6}} },
    { id = 20012, name = "Enchant Bracer - Greater Intellect", namePT = "Encantamento de Braçadeira - Intelecto Maior (+7)", prof = "ENCHANTING", skill = 270, category = "Armor", categoryPT = "Armaduras", quality = 1, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", reagents = {{name = "Lesser Eternal Essence", count = 3}} },
    { id = 23803, name = "Enchant Bracer - Healing Power", namePT = "Encantamento de Braçadeira - Poder de Cura (+24)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Holy_GreaterHeal", reagents = {{name = "Large Brilliant Shard", count = 2}, {name = "Greater Eternal Essence", count = 4}, {name = "Illusion Dust", count = 20}, {name = "Living Essence", count = 6}} },
    { id = 23804, name = "Enchant Bracer - Mana Regeneration", namePT = "Encantamento de Braçadeira - Regeneração de Mana (+4)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", reagents = {{name = "Illusion Dust", count = 16}, {name = "Greater Eternal Essence", count = 4}, {name = "Essence of Water", count = 2}} },
    -- Botas (Boots)
    { id = 20023, name = "Enchant Boots - Greater Agility", namePT = "Encantamento de Botas - Agilidade Maior (+7)", prof = "ENCHANTING", skill = 295, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Greater Eternal Essence", count = 2}, {name = "Illusion Dust", count = 2}} },
    { id = 20024, name = "Enchant Boots - Greater Stamina", namePT = "Encantamento de Botas - Vigor Maior (+7)", prof = "ENCHANTING", skill = 260, category = "Armor", categoryPT = "Armaduras", quality = 1, icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", reagents = {{name = "Dream Dust", count = 10}} },
    { id = 13890, name = "Enchant Boots - Minor Speed", namePT = "Encantamento de Botas - Aumento de Velocidade (+8%)", prof = "ENCHANTING", skill = 225, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Small Radiant Shard", count = 1}, {name = "Aquamarine", count = 1}, {name = "Lesser Nether Essence", count = 1}} },
    -- Luvas (Gloves)
    { id = 20017, name = "Enchant Gloves - Greater Agility", namePT = "Encantamento de Luvas - Agilidade Maior (+7)", prof = "ENCHANTING", skill = 270, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Lesser Eternal Essence", count = 3}, {name = "Illusion Dust", count = 3}} },
    { id = 20018, name = "Enchant Gloves - Greater Strength", namePT = "Encantamento de Luvas - Força Maior (+7)", prof = "ENCHANTING", skill = 295, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", reagents = {{name = "Greater Eternal Essence", count = 4}, {name = "Illusion Dust", count = 4}} },
    { id = 25072, name = "Enchant Gloves - Threat", namePT = "Encantamento de Luvas - Ameaça (+Ameaça)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Shadow_ShadowPact", reagents = {{name = "Nexus Crystal", count = 4}, {name = "Large Brilliant Shard", count = 6}, {name = "Larval Acid", count = 8}} },
    { id = 25073, name = "Enchant Gloves - Shadow Power", namePT = "Encantamento de Luvas - Poder de Sombra (+20)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt", reagents = {{name = "Nexus Crystal", count = 3}, {name = "Large Brilliant Shard", count = 10}, {name = "Essence of Undeath", count = 6}} },
    { id = 25074, name = "Enchant Gloves - Frost Power", namePT = "Encantamento de Luvas - Poder de Gelo (+20)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", reagents = {{name = "Nexus Crystal", count = 3}, {name = "Large Brilliant Shard", count = 10}, {name = "Essence of Water", count = 4}} },
    { id = 25075, name = "Enchant Gloves - Fire Power", namePT = "Encantamento de Luvas - Poder de Fogo (+20)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Fire_Fireball02", reagents = {{name = "Nexus Crystal", count = 3}, {name = "Large Brilliant Shard", count = 10}, {name = "Essence of Fire", count = 4}} },
    { id = 25078, name = "Enchant Gloves - Healing Power", namePT = "Encantamento de Luvas - Poder de Cura (+30)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Holy_GreaterHeal", reagents = {{name = "Nexus Crystal", count = 3}, {name = "Large Brilliant Shard", count = 8}, {name = "Living Essence", count = 4}} },
    { id = 25080, name = "Enchant Gloves - Superior Agility", namePT = "Encantamento de Luvas - Agilidade Superior (+15)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Nexus Crystal", count = 3}, {name = "Large Brilliant Shard", count = 8}, {name = "Essence of Air", count = 4}} },
    { id = 13890, name = "Enchant Gloves - Riding Skill", namePT = "Encantamento de Luvas - Perícia de Montaria", prof = "ENCHANTING", skill = 225, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Ability_Mount_Raptor", reagents = {{name = "Large Radiant Shard", count = 2}, {name = "Dream Dust", count = 3}} },
    -- Capa (Cloak)
    { id = 20014, name = "Enchant Cloak - Greater Resistance", namePT = "Encantamento de Capa - Resistência Maior (+5)", prof = "ENCHANTING", skill = 265, category = "Armor", categoryPT = "Armaduras", quality = 1, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", reagents = {{name = "Lesser Eternal Essence", count = 2}, {name = "Heart of Fire", count = 1}, {name = "Core of Earth", count = 1}, {name = "Globe of Water", count = 1}, {name = "Breath of Wind", count = 1}} },
    { id = 20015, name = "Enchant Cloak - Superior Defense", namePT = "Encantamento de Capa - Defesa Superior (+70)", prof = "ENCHANTING", skill = 285, category = "Armor", categoryPT = "Armaduras", quality = 1, icon = "Interface\\Icons\\Spell_Holy_DevotionAura", reagents = {{name = "Illusion Dust", count = 8}} },
    { id = 25081, name = "Enchant Cloak - Subtlety", namePT = "Encantamento de Capa - Sutileza (-2% Ameaça)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", reagents = {{name = "Nexus Crystal", count = 4}, {name = "Large Brilliant Shard", count = 6}, {name = "Black Lotus", count = 2}} },
    { id = 25082, name = "Enchant Cloak - Dodge", namePT = "Encantamento de Capa - Esquiva (+1%)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Nexus Crystal", count = 3}, {name = "Large Brilliant Shard", count = 8}, {name = "Guardian Stone", count = 8}} },
    { id = 25083, name = "Enchant Cloak - Stealth", namePT = "Encantamento de Capa - Furtividade (+5)", prof = "ENCHANTING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\Ability_Stealth", reagents = {{name = "Nexus Crystal", count = 3}, {name = "Large Brilliant Shard", count = 8}, {name = "Black Lotus", count = 2}} },
    -- Óleos (Oils)
    { id = 25129, name = "Brilliant Wizard Oil", namePT = "Óleo Brilhante de Mago (+36 Dano, +1% Crítico)", prof = "ENCHANTING", skill = 300, category = "Oils", categoryPT = "Óleos", quality = 2, icon = "Interface\\Icons\\INV_Potion_105", reagents = {{name = "Large Brilliant Shard", count = 2}, {name = "Firebloom", count = 3}, {name = "Crystal Vial", count = 1}} },
    { id = 25130, name = "Brilliant Mana Oil", namePT = "Óleo Brilhante de Mana (+12 Mana/5s, +25 Cura)", prof = "ENCHANTING", skill = 300, category = "Oils", categoryPT = "Óleos", quality = 2, icon = "Interface\\Icons\\INV_Potion_100", reagents = {{name = "Large Brilliant Shard", count = 2}, {name = "Purple Lotus", count = 3}, {name = "Crystal Vial", count = 1}} },

    -- =========================================================================
    -- 5. FERRARIA (BLACKSMITHING)
    -- =========================================================================
    -- Peças Épicas Lendárias
    { id = 16983, name = "Lionheart Helm", namePT = "Elmo Coração de Leão", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 4, icon = "Interface\\Icons\\INV_Helmet_09", reagents = {{name = "Arcanite Bar", count = 80}, {name = "Azurite", count = 12}, {name = "Blue Sapphire", count = 4}, {name = "Azerothian Diamond", count = 4}} },
    { id = 26735, name = "Titanic Leggings", namePT = "Perneiras Titânicas", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 4, icon = "Interface\\Icons\\INV_Pants_Plate_07", reagents = {{name = "Arcanite Bar", count = 16}, {name = "Flask of the Titans", count = 1}, {name = "Enchanted Leather", count = 10}, {name = "Core of Earth", count = 2}} },
    { id = 16984, name = "Stronghold Gauntlets", namePT = "Manoplas da Fortaleza", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 4, icon = "Interface\\Icons\\INV_Gauntlets_10", reagents = {{name = "Arcanite Bar", count = 15}, {name = "Enchanted Thorium Bar", count = 12}, {name = "Huge Emerald", count = 4}, {name = "Azerothian Diamond", count = 4}} },
    { id = 16985, name = "Invulnerable Mail", namePT = "Cota Invulnerável", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 4, icon = "Interface\\Icons\\INV_Chest_Plate05", reagents = {{name = "Arcanite Bar", count = 20}, {name = "Enchanted Thorium Bar", count = 12}, {name = "Huge Emerald", count = 2}, {name = "Azerothian Diamond", count = 2}} },
    -- Armas Épicas & Raras
    { id = 23629, name = "Nightfall", namePT = "Cai a Noite (Machado 2M)", prof = "BLACKSMITHING", skill = 300, category = "Weapons", categoryPT = "Armas", quality = 4, icon = "Interface\\Icons\\INV_Axe_04", reagents = {{name = "Arcanite Bar", count = 12}, {name = "Dark Iron Bar", count = 10}, {name = "Fiery Core", count = 4}, {name = "Lava Core", count = 2}, {name = "Core of Earth", count = 2}} },
    { id = 16963, name = "Arcanite Reaper", namePT = "Ceifador de Arcanita", prof = "BLACKSMITHING", skill = 275, category = "Weapons", categoryPT = "Armas", quality = 3, icon = "Interface\\Icons\\INV_Axe_09", reagents = {{name = "Arcanite Bar", count = 20}, {name = "Dense Stone", count = 6}, {name = "Enchanted Leather", count = 2}} },
    { id = 16964, name = "Annihilator", namePT = "Aniquilador", prof = "BLACKSMITHING", skill = 300, category = "Weapons", categoryPT = "Armas", quality = 3, icon = "Interface\\Icons\\INV_Axe_02", reagents = {{name = "Arcanite Bar", count = 12}, {name = "Dense Stone", count = 6}, {name = "Enchanted Leather", count = 2}} },
    { id = 21162, name = "Sulfuron Hammer", namePT = "Martelo de Sulfuron", prof = "BLACKSMITHING", skill = 300, category = "Weapons", categoryPT = "Armas", quality = 4, icon = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras", reagents = {{name = "Sulfuron Ingot", count = 8}, {name = "Dark Iron Bar", count = 20}, {name = "Arcanite Bar", count = 50}, {name = "Essence of Fire", count = 25}, {name = "Blood of the Mountain", count = 10}, {name = "Lava Core", count = 10}, {name = "Fiery Core", count = 10}} },
    { id = 19163, name = "Dark Iron Pulverizer", namePT = "Pulverizador de Ferro Negro", prof = "BLACKSMITHING", skill = 300, category = "Weapons", categoryPT = "Armas", quality = 3, icon = "Interface\\Icons\\INV_Hammer_17", reagents = {{name = "Dark Iron Bar", count = 18}, {name = "Heart of Fire", count = 4}, {name = "Blood of the Mountain", count = 4}} },
    { id = 19164, name = "Dark Iron Plate", namePT = "Placa de Ferro Negro", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 3, icon = "Interface\\Icons\\INV_Chest_Plate03", reagents = {{name = "Dark Iron Bar", count = 20}, {name = "Fiery Core", count = 4}, {name = "Lava Core", count = 2}} },
    { id = 19165, name = "Dark Iron Leggings", namePT = "Perneiras de Ferro Negro", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 3, icon = "Interface\\Icons\\INV_Pants_Plate_05", reagents = {{name = "Dark Iron Bar", count = 16}, {name = "Fiery Core", count = 4}, {name = "Lava Core", count = 2}} },
    { id = 19166, name = "Dark Iron Helm", namePT = "Elmo de Ferro Negro", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 3, icon = "Interface\\Icons\\INV_Helmet_05", reagents = {{name = "Dark Iron Bar", count = 18}, {name = "Fiery Core", count = 4}, {name = "Blood of the Mountain", count = 2}} },
    { id = 19167, name = "Dark Iron Boots", namePT = "Botas de Ferro Negro", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 3, icon = "Interface\\Icons\\INV_Boots_Plate_03", reagents = {{name = "Dark Iron Bar", count = 14}, {name = "Fiery Core", count = 3}, {name = "Lava Core", count = 2}} },
    { id = 19168, name = "Dark Iron Gauntlets", namePT = "Manoplas de Ferro Negro", prof = "BLACKSMITHING", skill = 300, category = "Armor", categoryPT = "Armaduras", quality = 3, icon = "Interface\\Icons\\INV_Gauntlets_10", reagents = {{name = "Dark Iron Bar", count = 16}, {name = "Fiery Core", count = 4}, {name = "Lava Core", count = 2}} },
    -- Conjunto Imperial Plate
    { id = 16970, name = "Imperial Plate Chest", namePT = "Peitoral de Placas Imperial", prof = "BLACKSMITHING", skill = 265, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\INV_Chest_Plate07", reagents = {{name = "Thorium Bar", count = 20}, {name = "Star Ruby", count = 1}} },
    { id = 16971, name = "Imperial Plate Helm", namePT = "Elmo de Placas Imperial", prof = "BLACKSMITHING", skill = 270, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\INV_Helmet_04", reagents = {{name = "Thorium Bar", count = 16}, {name = "Star Ruby", count = 1}} },
    { id = 16972, name = "Imperial Plate Boots", namePT = "Botas de Placas Imperial", prof = "BLACKSMITHING", skill = 265, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\INV_Boots_Plate_01", reagents = {{name = "Thorium Bar", count = 18}, {name = "Aquamarine", count = 1}} },
    { id = 16973, name = "Imperial Plate Leggings", namePT = "Perneiras de Placas Imperial", prof = "BLACKSMITHING", skill = 275, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\INV_Pants_Plate_05", reagents = {{name = "Thorium Bar", count = 20}, {name = "Star Ruby", count = 1}} },
    { id = 16974, name = "Imperial Plate Shoulders", namePT = "Omoplatas de Placas Imperial", prof = "BLACKSMITHING", skill = 265, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\INV_Shoulder_01", reagents = {{name = "Thorium Bar", count = 14}, {name = "Citrine", count = 2}} },
    -- Pedras de Amolar e Utilidades
    { id = 16975, name = "Dense Sharpening Stone", namePT = "Pedra de Amolar Densa (+8 Dano)", prof = "BLACKSMITHING", skill = 250, category = "Consumables", categoryPT = "Consumíveis", quality = 1, icon = "Interface\\Icons\\INV_Stone_SharpeningStone_05", reagents = {{name = "Dense Stone", count = 1}} },
    { id = 16976, name = "Dense Weightstone", namePT = "Pedra de Peso Densa (+8 Dano)", prof = "BLACKSMITHING", skill = 250, category = "Consumables", categoryPT = "Consumíveis", quality = 1, icon = "Interface\\Icons\\INV_Stone_WeightStone_05", reagents = {{name = "Dense Stone", count = 1}, {name = "Runecloth", count = 1}} },
    { id = 22759, name = "Elemental Sharpening Stone", namePT = "Pedra de Amolar Elemental (+2% Crítico)", prof = "BLACKSMITHING", skill = 300, category = "Consumables", categoryPT = "Consumíveis", quality = 2, icon = "Interface\\Icons\\INV_Stone_SharpeningStone_06", reagents = {{name = "Elemental Earth", count = 2}, {name = "Dense Stone", count = 3}} },
    { id = 19169, name = "Arcanite Skeleton Key", namePT = "Chave-mestra de Arcanita", prof = "BLACKSMITHING", skill = 275, category = "Keys", categoryPT = "Chaves", quality = 2, icon = "Interface\\Icons\\INV_Misc_Key_13", reagents = {{name = "Arcanite Bar", count = 1}, {name = "Dense Stone", count = 1}} },
    { id = 19170, name = "Mithril Spurs", namePT = "Esporas de Mitril (+Velocidade de Montaria)", prof = "BLACKSMITHING", skill = 215, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\INV_Gizmo_07", reagents = {{name = "Mithril Bar", count = 4}, {name = "Dense Stone", count = 3}} },
    { id = 19171, name = "Thorium Shield Spike", namePT = "Ponta de Escudo de Tório", prof = "BLACKSMITHING", skill = 275, category = "Armor", categoryPT = "Armaduras", quality = 1, icon = "Interface\\Icons\\INV_Misc_Spike_01", reagents = {{name = "Thorium Bar", count = 4}, {name = "Dense Stone", count = 4}, {name = "Essence of Earth", count = 2}} },

    -- =========================================================================
    -- 6. ENGENHARIA (ENGINEERING)
    -- =========================================================================
    -- Explosivos
    { id = 13240, name = "Goblin Sapper Charge", namePT = "Carga de Sapador Goblin", prof = "ENGINEERING", skill = 205, category = "Explosives", categoryPT = "Explosivos", quality = 1, icon = "Interface\\Icons\\Spell_Fire_SelfDestruct", reagents = {{name = "Mithril Casing", count = 1}, {name = "Solid Blasting Powder", count = 10}, {name = "Mageweave Cloth", count = 1}, {name = "Unstable Trigger", count = 1}} },
    { id = 12903, name = "Iron Grenade", namePT = "Granada de Ferro", prof = "ENGINEERING", skill = 175, category = "Explosives", categoryPT = "Explosivos", quality = 1, icon = "Interface\\Icons\\Spell_Fire_SelfDestruct", reagents = {{name = "Iron Bar", count = 1}, {name = "Heavy Blasting Powder", count = 1}, {name = "Silk Cloth", count = 1}} },
    { id = 19790, name = "Thorium Grenade", namePT = "Granada de Tório", prof = "ENGINEERING", skill = 260, category = "Explosives", categoryPT = "Explosivos", quality = 1, icon = "Interface\\Icons\\Spell_Fire_SelfDestruct", reagents = {{name = "Thorium Widget", count = 1}, {name = "Dense Blasting Powder", count = 3}, {name = "Thorium Bar", count = 3}, {name = "Runecloth", count = 3}} },
    { id = 19791, name = "Dense Dynamite", namePT = "Dinamite Densa", prof = "ENGINEERING", skill = 250, category = "Explosives", categoryPT = "Explosivos", quality = 1, icon = "Interface\\Icons\\Spell_Fire_SelfDestruct", reagents = {{name = "Dense Blasting Powder", count = 2}, {name = "Runecloth", count = 3}} },
    { id = 19792, name = "Dark Iron Bomb", namePT = "Bomba de Ferro Negro", prof = "ENGINEERING", skill = 285, category = "Explosives", categoryPT = "Explosivos", quality = 1, icon = "Interface\\Icons\\Spell_Fire_SelfDestruct", reagents = {{name = "Dark Iron Bar", count = 2}, {name = "Dense Blasting Powder", count = 4}} },
    -- Engenhocas & Dispositivos
    { id = 22760, name = "Field Repair Bot 74A", namePT = "Robô Reparador de Campo 74A", prof = "ENGINEERING", skill = 300, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Misc_MonsterClaw_04", reagents = {{name = "Thorium Bar", count = 16}, {name = "Fused Wiring", count = 2}, {name = "Heart of Fire", count = 1}, {name = "Elemental Earth", count = 1}, {name = "Ironweb Spider Silk", count = 1}} },
    { id = 12908, name = "Gnomish Death Ray", namePT = "Raio da Morte Gnômico", prof = "ENGINEERING", skill = 240, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\Spell_Shadow_FingerOfDeath", reagents = {{name = "Mithril Tube", count = 1}, {name = "Inlaid Mithril Cylinder", count = 1}, {name = "Gold Power Core", count = 1}, {name = "Bronze Framework", count = 1}} },
    { id = 12909, name = "Gnomish Battle Chicken", namePT = "Galinha de Batalha Gnômica", prof = "ENGINEERING", skill = 230, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\Spell_Magic_PolymorphChicken", reagents = {{name = "Mithril Casing", count = 1}, {name = "Gold Power Core", count = 1}, {name = "Truesilver Bar", count = 2}, {name = "Mithril Bar", count = 6}} },
    { id = 13241, name = "Goblin Rocket Helmet", namePT = "Capacete de Foguete Goblin", prof = "ENGINEERING", skill = 245, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Helmet_49", reagents = {{name = "Goblin Rocket Fuel", count = 4}, {name = "Mithril Bar", count = 8}, {name = "Truesilver Bar", count = 4}} },
    { id = 13242, name = "Goblin Rocket Boots", namePT = "Botas de Foguete Goblin", prof = "ENGINEERING", skill = 225, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Boots_02", reagents = {{name = "Goblin Rocket Fuel", count = 2}, {name = "Mithril Bar", count = 4}, {name = "Truesilver Bar", count = 2}} },
    { id = 12910, name = "Gnomish Rocket Boots", namePT = "Botas de Foguete Gnômicas", prof = "ENGINEERING", skill = 225, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Boots_02", reagents = {{name = "Mithril Tube", count = 2}, {name = "Heavy Leather", count = 4}, {name = "Gold Power Core", count = 2}} },
    { id = 12911, name = "Gnomish Net-o-Matic Projector", namePT = "Projetor Enredomatic Gnômico", prof = "ENGINEERING", skill = 210, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Misc_Net_01", reagents = {{name = "Mithril Tube", count = 1}, {name = "Shadow Silk", count = 2}, {name = "Thick Spider's Silk", count = 4}} },
    { id = 12912, name = "Gnomish Mind Control Cap", namePT = "Touca de Controle Mental Gnômica", prof = "ENGINEERING", skill = 215, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Helmet_48", reagents = {{name = "Mithril Bar", count = 10}, {name = "Gold Power Core", count = 1}, {name = "Star Ruby", count = 1}} },
    { id = 13243, name = "Goblin Jumper Cables XL", namePT = "Cabos de Chupeta Goblin XL", prof = "ENGINEERING", skill = 265, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Misc_MonsterClaw_04", reagents = {{name = "Thorium Widget", count = 2}, {name = "Truesilver Bar", count = 2}, {name = "Fused Wiring", count = 2}, {name = "Ironweb Spider Silk", count = 2}} },
    { id = 13244, name = "Goblin Jumper Cables", namePT = "Cabos de Chupeta Goblin", prof = "ENGINEERING", skill = 165, category = "Devices", categoryPT = "Dispositivos", quality = 1, icon = "Interface\\Icons\\INV_Misc_MonsterClaw_04", reagents = {{name = "Iron Bar", count = 6}, {name = "Fused Wiring", count = 1}, {name = "Shadowgem", count = 2}} },
    { id = 12913, name = "Gnomish Cloaking Device", namePT = "Dispositivo de Ocultamento Gnômico", prof = "ENGINEERING", skill = 200, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", reagents = {{name = "Mithril Bar", count = 4}, {name = "Fused Wiring", count = 1}, {name = "Star Ruby", count = 1}} },
    -- Refletores (Reflectors)
    { id = 22761, name = "Hyper-Radiant Flame Reflector", namePT = "Refletor de Chamas Hiper-radiante", prof = "ENGINEERING", skill = 290, category = "Trinkets", categoryPT = "Berloques", quality = 3, icon = "Interface\\Icons\\Spell_Fire_SealOfFire", reagents = {{name = "Dark Iron Bar", count = 4}, {name = "Truesilver Bar", count = 3}, {name = "Essence of Fire", count = 2}, {name = "Star Ruby", count = 2}} },
    { id = 22762, name = "Gyrofreeze Ice Reflector", namePT = "Refletor de Gelo Girocongelante", prof = "ENGINEERING", skill = 260, category = "Trinkets", categoryPT = "Berloques", quality = 3, icon = "Interface\\Icons\\Spell_Frost_FrostWard", reagents = {{name = "Thorium Widget", count = 2}, {name = "Truesilver Bar", count = 2}, {name = "Essence of Water", count = 2}, {name = "Aquamarine", count = 2}} },
    { id = 22763, name = "Ultra-Flash Shadow Reflector", namePT = "Refletor de Sombra Ultra-lampejante", prof = "ENGINEERING", skill = 300, category = "Trinkets", categoryPT = "Berloques", quality = 3, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", reagents = {{name = "Dark Iron Bar", count = 8}, {name = "Truesilver Bar", count = 4}, {name = "Essence of Undeath", count = 4}, {name = "Living Essence", count = 2}} },
    -- Óculos (Goggles)
    { id = 12914, name = "Spellpower Goggles Xtreme", namePT = "Óculos de Poder Mágico Extremo", prof = "ENGINEERING", skill = 270, category = "Goggles", categoryPT = "Óculos", quality = 2, icon = "Interface\\Icons\\INV_Helmet_15", reagents = {{name = "Thorium Bar", count = 4}, {name = "Star Ruby", count = 2}, {name = "Heavy Leather", count = 4}} },
    { id = 12915, name = "Master Engineer's Goggles", namePT = "Óculos do Mestre Engenheiro", prof = "ENGINEERING", skill = 290, category = "Goggles", categoryPT = "Óculos", quality = 2, icon = "Interface\\Icons\\INV_Helmet_16", reagents = {{name = "Thorium Bar", count = 6}, {name = "Azerothian Diamond", count = 1}, {name = "Blue Sapphire", count = 1}} },
    { id = 12916, name = "Catseye Ultra Goggles", namePT = "Ultra-óculos Olho de Gato", prof = "ENGINEERING", skill = 220, category = "Goggles", categoryPT = "Óculos", quality = 2, icon = "Interface\\Icons\\INV_Helmet_15", reagents = {{name = "Mithril Bar", count = 4}, {name = "Aquamarine", count = 2}, {name = "Thick Leather", count = 2}} },
    -- Munições & Utilidades
    { id = 19793, name = "Thorium Shells", namePT = "Balas de Tório (Dano 17.5)", prof = "ENGINEERING", skill = 285, category = "Ammunition", categoryPT = "Munição", quality = 2, icon = "Interface\\Icons\\INV_Ammo_Bullet_03", reagents = {{name = "Thorium Bar", count = 2}, {name = "Dense Blasting Powder", count = 1}} },
    { id = 19794, name = "Sniper Scope", namePT = "Mira de Franco-atirador (+7 Dano)", prof = "ENGINEERING", skill = 240, category = "Scopes", categoryPT = "Miras", quality = 2, icon = "Interface\\Icons\\INV_Misc_Spyglass_02", reagents = {{name = "Mithril Tube", count = 1}, {name = "Truesilver Bar", count = 1}, {name = "Star Ruby", count = 1}} },
    { id = 19795, name = "Target Dummy", namePT = "Boneco de Alvo", prof = "ENGINEERING", skill = 85, category = "Devices", categoryPT = "Dispositivos", quality = 1, icon = "Interface\\Icons\\INV_Misc_MonsterHead_01", reagents = {{name = "Copper Bar", count = 3}, {name = "Bronze Framework", count = 1}, {name = "Linen Cloth", count = 1}} },
    { id = 19796, name = "Advanced Target Dummy", namePT = "Boneco de Alvo Avançado", prof = "ENGINEERING", skill = 185, category = "Devices", categoryPT = "Dispositivos", quality = 1, icon = "Interface\\Icons\\INV_Misc_MonsterHead_01", reagents = {{name = "Iron Bar", count = 3}, {name = "Heavy Leather", count = 1}, {name = "Bronze Framework", count = 1}} },
    { id = 19797, name = "Masterwork Target Dummy", namePT = "Boneco de Alvo Obra-prima", prof = "ENGINEERING", skill = 275, category = "Devices", categoryPT = "Dispositivos", quality = 2, icon = "Interface\\Icons\\INV_Misc_MonsterHead_01", reagents = {{name = "Thorium Widget", count = 1}, {name = "Thorium Bar", count = 2}, {name = "Rugged Leather", count = 2}, {name = "Fused Wiring", count = 1}} },
    { id = 19798, name = "Parachute Cloak", namePT = "Capa de Paraquedas", prof = "ENGINEERING", skill = 225, category = "Armor", categoryPT = "Armaduras", quality = 2, icon = "Interface\\Icons\\INV_Misc_Cape_11", reagents = {{name = "Bolt of Mageweave", count = 4}, {name = "Unstable Trigger", count = 1}, {name = "Solid Blasting Powder", count = 2}} },
}

--- Metadados enriquecidos para itens de receitas (ItemId, Raridade, Origem e Status detalhados)
local ITEM_METADATA = {
    -- LEATHERWORKING
    [90001] = { itemId = 90001, quality = 1, source = "trainer", stats = { slot = "Acampamento / Utilidade", effects = "|cff00ff00Uso: Monta uma barraca de acampamento para descanso acelerado e abrigo.|r", flavor = "Ideal para aventureiros descansarem nas noites frias de Azeroth." } },
    [2159]  = { itemId = 2308, quality = 1, source = "trainer", stats = { slot = "Reforço de Armadura", effects = "|cff00ff00Uso: Aumenta permanentemente a armadura de peitoral, pernas, luvas ou botas em 8.|r" } },
    [2149]  = { itemId = 2302, quality = 1, source = "trainer", stats = { slot = "Pés (Couro)", armor = 20, itemLevel = 4, reqLevel = 1 } },
    [2152]  = { itemId = 2303, quality = 1, source = "trainer", stats = { slot = "Pernas (Couro)", armor = 29, itemLevel = 5, reqLevel = 1 } },
    [2153]  = { itemId = 2304, quality = 1, source = "trainer", stats = { slot = "Torso (Couro)", armor = 33, itemLevel = 6, reqLevel = 1 } },
    [2154]  = { itemId = 2307, quality = 1, source = "trainer", stats = { slot = "Costas", armor = 14, itemLevel = 6, reqLevel = 1 } },
    [2155]  = { itemId = 2305, quality = 1, source = "trainer", stats = { slot = "Pulsos (Couro)", armor = 14, itemLevel = 3, reqLevel = 1 } },
    [2158]  = { itemId = 2306, quality = 1, source = "trainer", stats = { slot = "Cintura (Couro)", armor = 17, itemLevel = 4, reqLevel = 1 } },
    [2150]  = { itemId = 2318, quality = 1, source = "trainer", stats = { slot = "Reagente de Couro", flavor = "Couro leve básico para confecção." } },
    [2160]  = { itemId = 2319, quality = 1, source = "trainer", stats = { slot = "Reagente de Couro", flavor = "Pele leve curada com sal." } },
    [7365]  = { itemId = 7371, quality = 1, source = "trainer", stats = { slot = "Aljava (10 slots)", effects = "|cff00ff00Equip: Aumenta a velocidade de ataque à distância em 10%.|r" } },
    [7366]  = { itemId = 7372, quality = 1, source = "trainer", stats = { slot = "Bolsa de Munição (10 slots)", effects = "|cff00ff00Equip: Aumenta a velocidade de ataque à distância em 10%.|r" } },
    [2163]  = { itemId = 2309, quality = 1, source = "trainer", stats = { slot = "Torso (Couro)", armor = 54, itemLevel = 14, reqLevel = 9 } },
    [2164]  = { itemId = 2310, quality = 1, source = "trainer", stats = { slot = "Pés (Couro)", armor = 33, itemLevel = 14, reqLevel = 9 } },
    [2165]  = { itemId = 2311, quality = 1, source = "trainer", stats = { slot = "Costas", armor = 20, itemLevel = 15, reqLevel = 10 } },
    [2166]  = { itemId = 2312, quality = 1, source = "trainer", stats = { slot = "Mãos (Couro)", armor = 28, itemLevel = 15, reqLevel = 10 } },
    [7138]  = { itemId = 4243, quality = 2, source = "trainer", stats = { slot = "Torso (Couro)", armor = 78, itemLevel = 18, reqLevel = 13, attrs = "+4 Agilidade, +3 Estamina" } },
    [7139]  = { itemId = 4244, quality = 2, source = "trainer", stats = { slot = "Cintura (Couro)", armor = 46, itemLevel = 19, reqLevel = 14, attrs = "+3 Força, +2 Estamina" } },
    [7126]  = { itemId = 4304, quality = 1, source = "trainer", stats = { slot = "Reagente de Couro", flavor = "Pedaço de couro médio resistente." } },
    [7127]  = { itemId = 4234, quality = 1, source = "trainer", stats = { slot = "Reagente de Couro", flavor = "Pele média tratada com sal." } },
    [7128]  = { itemId = 4265, quality = 1, source = "trainer", stats = { slot = "Reforço de Armadura", effects = "|cff00ff00Uso: Aumenta permanentemente a armadura de uma peça em 16.|r" } },
    [2161]  = { itemId = 2314, quality = 2, source = "trainer", stats = { slot = "Pés (Couro)", armor = 49, itemLevel = 22, reqLevel = 17, attrs = "+4 Agilidade, +3 Estamina" } },
    [2162]  = { itemId = 2313, quality = 2, source = "trainer", stats = { slot = "Costas", armor = 24, itemLevel = 20, reqLevel = 15, attrs = "+3 Agilidade" } },
    [2881]  = { itemId = 2315, quality = 2, source = "trainer", stats = { slot = "Cintura (Couro)", armor = 44, itemLevel = 21, reqLevel = 16, attrs = "+4 Agilidade, +3 Estamina" } },
    [2882]  = { itemId = 2316, quality = 2, source = "trainer", stats = { slot = "Pernas (Couro)", armor = 64, itemLevel = 24, reqLevel = 19, attrs = "+5 Agilidade, +4 Estamina" } },
    [2883]  = { itemId = 2317, quality = 2, source = "trainer", stats = { slot = "Torso (Couro)", armor = 74, itemLevel = 26, reqLevel = 21, attrs = "+6 Agilidade, +5 Estamina" } },
    [2884]  = { itemId = 2318, quality = 2, source = "trainer", stats = { slot = "Ombros (Couro)", armor = 54, itemLevel = 25, reqLevel = 20, attrs = "+4 Agilidade, +3 Estamina" } },
    [2885]  = { itemId = 2319, quality = 2, source = "trainer", stats = { slot = "Mãos (Couro)", armor = 44, itemLevel = 23, reqLevel = 18, attrs = "+4 Agilidade, +3 Força" } },
    [7133]  = { itemId = 4304, quality = 1, source = "trainer", stats = { slot = "Reforço de Armadura", effects = "|cff00ff00Uso: Aumenta permanentemente a armadura de uma peça em 24.|r" } },
    [7135]  = { itemId = 4235, quality = 1, source = "trainer", stats = { slot = "Reagente de Couro" } },
    [7136]  = { itemId = 4234, quality = 1, source = "trainer", stats = { slot = "Reagente de Couro" } },
    [19047] = { itemId = 15062, quality = 3, source = "drop", stats = { slot = "Mãos (Couro)", armor = 103, itemLevel = 58, reqLevel = 53, attrs = "+28 Poder de Ataque", effects = "|cff00ff00Equip: Aumenta em 1% a chance de acerto crítico.|r" } },
    [19048] = { itemId = 15063, quality = 3, source = "drop", stats = { slot = "Pernas (Couro)", armor = 148, itemLevel = 60, reqLevel = 55, attrs = "+46 Poder de Ataque, +12 Estamina", effects = "|cff00ff00Equip: Aumenta em 1% a chance de acerto crítico.|r" } },
    [22756] = { itemId = 18510, quality = 4, source = "drop", stats = { slot = "Costas", armor = 52, itemLevel = 62, reqLevel = 57, attrs = "+10 Intelecto, +8 Estamina", effects = "|cff00ff00Equip: Aumenta a cura de feitiços em até 42.|r" } },
    [22757] = { itemId = 18511, quality = 4, source = "drop", stats = { slot = "Costas", armor = 48, itemLevel = 62, reqLevel = 57, attrs = "+17 Agilidade, +8 Estamina", effects = "|cff00ff00Equip: Aumenta a chance de esquiva em 1%.|r" } },
    [21161] = { itemId = 16982, quality = 4, source = "drop", stats = { slot = "Pés (Couro)", armor = 126, itemLevel = 65, reqLevel = 60, attrs = "+13 Agilidade, +10 Estamina", effects = "|cff00ff00Equip: Aumenta o dano de fogo em até 15.|r" } },
    [19050] = { itemId = 15064, quality = 2, source = "reputation", stats = { slot = "Torso (Couro)", armor = 120, itemLevel = 55, reqLevel = 50, attrs = "+11 Força, +27 Estamina" } },
    [19051] = { itemId = 15065, quality = 2, source = "reputation", stats = { slot = "Pernas (Couro)", armor = 107, itemLevel = 57, reqLevel = 52, attrs = "+16 Força, +24 Estamina" } },
    [19052] = { itemId = 15056, quality = 3, source = "drop", stats = { slot = "Torso (Couro)", armor = 132, itemLevel = 55, reqLevel = 50, attrs = "+16 Agilidade, +14 Estamina", effects = "|cff00ff00Equip: Chance de infligir dano de raio ao ser atingido.|r" } },
    [19053] = { itemId = 15057, quality = 3, source = "drop", stats = { slot = "Pernas (Couro)", armor = 119, itemLevel = 57, reqLevel = 52, attrs = "+14 Agilidade, +18 Estamina", effects = "|cff00ff00Equip: Aumenta em 1% a chance de acerto crítico.|r" } },
    [19054] = { itemId = 15058, quality = 3, source = "drop", stats = { slot = "Ombros (Couro)", armor = 106, itemLevel = 56, reqLevel = 51, attrs = "+12 Agilidade, +12 Estamina", effects = "|cff00ff00Equip: Aumenta em 1% a chance de esquiva.|r" } },
    [19055] = { itemId = 15052, quality = 3, source = "drop", stats = { slot = "Torso (Malha)", armor = 286, itemLevel = 58, reqLevel = 53, attrs = "+20 Resistência a Fogo", effects = "|cff00ff00Equip: Chance de lançar bola de fogo no atacante.|r" } },
    [19058] = { itemId = 15050, quality = 3, source = "reputation", stats = { slot = "Torso (Malha)", armor = 344, itemLevel = 58, reqLevel = 53, attrs = "+8 Estamina, +50 Poder de Ataque, +12 Resistência a Fogo" } },
    [19059] = { itemId = 15051, quality = 3, source = "reputation", stats = { slot = "Ombros (Malha)", armor = 266, itemLevel = 58, reqLevel = 53, attrs = "+9 Estamina, +40 Poder de Ataque, +6 Resistência a Fogo" } },
    [19060] = { itemId = 15052, quality = 3, source = "reputation", stats = { slot = "Pernas (Malha)", armor = 320, itemLevel = 60, reqLevel = 55, attrs = "+8 Estamina, +54 Poder de Ataque, +13 Resistência a Fogo" } },
    [19061] = { itemId = 16984, quality = 3, source = "reputation", stats = { slot = "Pés (Malha)", armor = 211, itemLevel = 59, reqLevel = 54, attrs = "+10 Estamina, +28 Poder de Ataque, +12 Resistência a Fogo" } },
    [19062] = { itemId = 15048, quality = 3, source = "drop", stats = { slot = "Torso (Malha)", armor = 338, itemLevel = 57, reqLevel = 52, attrs = "+24 Intelecto, +11 Espírito, +15 Resistência Arcano" } },
    [19063] = { itemId = 15564, quality = 1, source = "trainer", stats = { slot = "Reforço de Armadura", effects = "|cff00ff00Uso: Aumenta permanentemente a armadura de uma peça em 40.|r" } },
    [19064] = { itemId = 8173, quality = 1, source = "trainer", stats = { slot = "Reforço de Armadura", effects = "|cff00ff00Uso: Aumenta permanentemente a armadura de uma peça em 32.|r" } },
    [22758] = { itemId = 18251, quality = 2, source = "reputation", stats = { slot = "Reforço de Armadura", effects = "|cff00ff00Uso: Aumenta permanentemente a Defesa de uma peça em +3.|r" } },
    [19065] = { itemId = 8217, quality = 2, source = "trainer", stats = { slot = "Aljava (18 slots)", effects = "|cff00ff00Equip: Aumenta a velocidade de ataque à distância em 15%.|r" } },
    [19066] = { itemId = 8218, quality = 2, source = "trainer", stats = { slot = "Bolsa de Munição (16 slots)", effects = "|cff00ff00Equip: Aumenta a velocidade de ataque à distância em 14%.|r" } },

    -- ALCHEMY
    [2329]  = { itemId = 2454, quality = 1, source = "trainer", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta a Força em 4 por 1h.|r", reqLevel = 1 } },
    [2330]  = { itemId = 118, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 70 a 90 de Vida.|r", reqLevel = 1 } },
    [7183]  = { itemId = 2457, quality = 1, source = "trainer", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta a Agilidade em 4 por 1h.|r", reqLevel = 2 } },
    [2331]  = { itemId = 858, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 140 a 180 de Vida.|r", reqLevel = 3 } },
    [2332]  = { itemId = 2458, quality = 1, source = "trainer", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta a Vida máxima em 27 por 1h.|r", reqLevel = 2 } },
    [3170]  = { itemId = 2459, quality = 2, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Aumenta a velocidade de movimento em 50% por 15s.|r", reqLevel = 5 } },
    [2334]  = { itemId = 3386, quality = 2, source = "trainer", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Cura até 4 venenos ativos.|r", reqLevel = 14 } },
    [2337]  = { itemId = 3385, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 140 a 180 de Mana.|r", reqLevel = 14 } },
    [3173]  = { itemId = 929, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 280 a 360 de Vida.|r", reqLevel = 12 } },
    [3176]  = { itemId = 3827, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 280 a 360 de Mana.|r", reqLevel = 22 } },
    [3177]  = { itemId = 1710, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 455 a 585 de Vida.|r", reqLevel = 21 } },
    [11450] = { itemId = 9187, quality = 1, source = "trainer", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta a Agilidade em 25 por 1h.|r", reqLevel = 38 } },
    [11451] = { itemId = 9206, quality = 2, source = "trainer", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta a Força em 25 por 1h.|r", reqLevel = 38 } },
    [11457] = { itemId = 3928, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 700 a 900 de Vida.|r", reqLevel = 35 } },
    [11458] = { itemId = 6149, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 700 a 900 de Mana.|r", reqLevel = 31 } },
    [17551] = { itemId = 13446, quality = 1, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 1050 a 1750 de Vida.|r", reqLevel = 45 } },
    [17552] = { itemId = 13444, quality = 2, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Restaura 1350 a 2250 de Mana.|r", reqLevel = 49 } },
    [17556] = { itemId = 13452, quality = 2, source = "drop", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta Agilidade em 25 e Crítico em 2% por 1h.|r", reqLevel = 46 } },
    [17554] = { itemId = 13454, quality = 2, source = "drop", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta o dano mágico em até 35 por 1h.|r", reqLevel = 47 } },
    [17555] = { itemId = 13445, quality = 1, source = "trainer", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta a armadura em 450 por 1h.|r", reqLevel = 43 } },
    [17557] = { itemId = 13453, quality = 2, source = "drop", stats = { slot = "Elixir", effects = "|cff00ff00Uso: Aumenta Força e Estamina em 18 por 1h.|r", reqLevel = 45 } },
    [17574] = { itemId = 5634, quality = 2, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Imunidade a atordoamentos e lentidão por 30s.|r", reqLevel = 20 } },
    [17575] = { itemId = 20008, quality = 2, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Remove atordoamentos e reduz desaceleração por 5s.|r", reqLevel = 47 } },
    [17576] = { itemId = 9172, quality = 2, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Concede invisibilidade por 18s.|r", reqLevel = 37 } },
    [17577] = { itemId = 9030, quality = 2, source = "trainer", stats = { slot = "Poção", effects = "|cff00ff00Uso: Remove 1 efeito nocivo a cada 5s por 30s.|r", reqLevel = 32 } },
    [17578] = { itemId = 20007, quality = 2, source = "reputation", stats = { slot = "Poção", effects = "|cff00ff00Uso: Regenera 12 de Mana a cada 5s por 1h.|r", reqLevel = 40 } },
    [17559] = { itemId = 13457, quality = 2, source = "drop", stats = { slot = "Poção de Proteção", effects = "|cff00ff00Uso: Absorve 1950 a 3250 de dano de Fogo por 1h.|r", reqLevel = 48 } },
    [17560] = { itemId = 13456, quality = 2, source = "drop", stats = { slot = "Poção de Proteção", effects = "|cff00ff00Uso: Absorve 1950 a 3250 de dano de Gelo por 1h.|r", reqLevel = 48 } },
    [17561] = { itemId = 13458, quality = 2, source = "drop", stats = { slot = "Poção de Proteção", effects = "|cff00ff00Uso: Absorve 1950 a 3250 de dano de Natureza por 1h.|r", reqLevel = 48 } },
    [17562] = { itemId = 13459, quality = 2, source = "drop", stats = { slot = "Poção de Proteção", effects = "|cff00ff00Uso: Absorve 1950 a 3250 de dano de Sombra por 1h.|r", reqLevel = 48 } },
    [17563] = { itemId = 13461, quality = 2, source = "drop", stats = { slot = "Poção de Proteção", effects = "|cff00ff00Uso: Absorve 1950 a 3250 de dano Arcano por 1h.|r", reqLevel = 48 } },
    [17626] = { itemId = 13510, quality = 3, source = "drop", stats = { slot = "Frasco", effects = "|cff00ff00Uso: +1200 de Vida máxima por 2h. Persiste na morte.|r", reqLevel = 50 } },
    [17627] = { itemId = 13511, quality = 3, source = "drop", stats = { slot = "Frasco", effects = "|cff00ff00Uso: +2000 de Mana máxima por 2h. Persiste na morte.|r", reqLevel = 50 } },
    [17628] = { itemId = 13512, quality = 3, source = "drop", stats = { slot = "Frasco", effects = "|cff00ff00Uso: +150 Dano de Feitiço por 2h. Persiste na morte.|r", reqLevel = 50 } },
    [17629] = { itemId = 13513, quality = 3, source = "drop", stats = { slot = "Frasco", effects = "|cff00ff00Uso: +25 a todas as Resistências por 2h. Persiste na morte.|r", reqLevel = 50 } },
    [17630] = { itemId = 13506, quality = 3, source = "drop", stats = { slot = "Frasco", effects = "|cff00ff00Uso: Imunidade total por 1 min (imóvel). Persiste na morte.|r", reqLevel = 50 } },
    [17187] = { itemId = 12360, quality = 2, source = "trainer", stats = { slot = "Reagente", flavor = "Barra de Arcanita necessária para as armas e armaduras mais nobres." } },
    [17186] = { itemId = 3577, quality = 2, source = "trainer", stats = { slot = "Reagente", flavor = "Barra de Ouro puro refinada por alquimia." } },
    [17564] = { itemId = 7078, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência de Fogo elementar." } },
    [17565] = { itemId = 7076, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência de Terra elementar." } },
    [17566] = { itemId = 7080, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência de Água pura." } },
    [17567] = { itemId = 7082, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência de Ar veloz." } },
    [17568] = { itemId = 7080, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência de Água purificada da Morte-viva." } },
    [17569] = { itemId = 12808, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência de Morte-viva sombria." } },
    [17570] = { itemId = 7076, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência de Terra fértil." } },
    [17571] = { itemId = 12803, quality = 2, source = "trainer", stats = { slot = "Essência", flavor = "Essência Viva da natureza." } },
    [17572] = { itemId = 7078, quality = 2, source = "trainer", stats = { slot = "Reagente", flavor = "Fogo Elemental para forjas lendárias." } },
    [11479] = { itemId = 9149, quality = 2, source = "trainer", stats = { slot = "Berloque", reqLevel = 35, flavor = "Artefato alquímico supremo requerido para transmutações." } },

    -- TAILORING
    [2963]  = { itemId = 4238, quality = 1, source = "trainer", stats = { slot = "Bolsa", desc = "Bolsa de 6 compartimentos." } },
    [2964]  = { itemId = 4240, quality = 1, source = "trainer", stats = { slot = "Bolsa", desc = "Bolsa de 8 compartimentos." } },
    [3914]  = { itemId = 4241, quality = 1, source = "trainer", stats = { slot = "Bolsa", desc = "Mochila de 10 compartimentos." } },
    [12044] = { itemId = 4245, quality = 1, source = "trainer", stats = { slot = "Bolsa", desc = "Bolsa de 12 compartimentos." } },
    [18401] = { itemId = 14046, quality = 1, source = "trainer", stats = { slot = "Bolsa", desc = "Bolsa de 14 compartimentos." } },
    [18402] = { itemId = 14155, quality = 2, source = "trainer", stats = { slot = "Bolsa", desc = "Bolsa de 16 compartimentos." } },
    [18403] = { itemId = 14156, quality = 3, source = "drop", stats = { slot = "Bolsa", desc = "Bolsa de 18 compartimentos.", reqLevel = 50 } },
    [26085] = { itemId = 21358, quality = 4, source = "drop", stats = { slot = "Bolsa de Almas", desc = "Bolsa de 28 compartimentos para fragmentos de alma." } },
    [18413] = { itemId = 14152, quality = 4, source = "drop", stats = { slot = "Torso (Tecido)", armor = 81, itemLevel = 62, reqLevel = 57, attrs = "+12 Intelecto", effects = "|cff00ff00Equip: +40 Dano Mágico, +1% Crítico. Uso: Restaura 375 a 625 Mana.|r" } },
    [18414] = { itemId = 14153, quality = 4, source = "drop", stats = { slot = "Torso (Tecido)", armor = 81, itemLevel = 62, reqLevel = 57, attrs = "+14 Estamina", effects = "|cff00ff00Equip: +46 Dano Sombra. Uso: Cura 1200 de vida de demônio evocado.|r" } },
    [18415] = { itemId = 14154, quality = 4, source = "drop", stats = { slot = "Torso (Tecido)", armor = 81, itemLevel = 62, reqLevel = 57, attrs = "+14 Estamina", effects = "|cff00ff00Equip: +73 Cura, +6 Mana/5s. Uso: Imune a Medo por 30s.|r" } },
    [24268] = { itemId = 19682, quality = 3, source = "reputation", stats = { slot = "Torso (Tecido)", armor = 75, itemLevel = 65, reqLevel = 60, attrs = "+13 Intelecto", effects = "|cff00ff00Equip: +27 Dano Mágico, +2% Acerto Mágico.|r" } },
    [24269] = { itemId = 19683, quality = 3, source = "reputation", stats = { slot = "Pernas (Tecido)", armor = 68, itemLevel = 65, reqLevel = 60, attrs = "+6 Intelecto", effects = "|cff00ff00Equip: +37 Dano Mágico, +1% Acerto Mágico.|r" } },
    [24270] = { itemId = 19684, quality = 3, source = "reputation", stats = { slot = "Pés (Tecido)", armor = 55, itemLevel = 65, reqLevel = 60, effects = "|cff00ff00Equip: +19 Dano Mágico, +1% Acerto Mágico.|r" } },
    [23971] = { itemId = 19156, quality = 4, source = "reputation", stats = { slot = "Torso (Tecido)", armor = 88, itemLevel = 65, reqLevel = 60, attrs = "+35 Resistência a Fogo", effects = "|cff00ff00Equip: +23 Dano de Fogo.|r" } },
    [23972] = { itemId = 19165, quality = 4, source = "reputation", stats = { slot = "Pernas (Tecido)", armor = 77, itemLevel = 65, reqLevel = 60, attrs = "+16 Estamina, +16 Resistência a Fogo", effects = "|cff00ff00Equip: +43 Dano de Fogo.|r" } },
    [18408] = { itemId = 18486, quality = 3, source = "trainer", stats = { slot = "Torso (Tecido)", armor = 70, itemLevel = 57, reqLevel = 52, attrs = "+25 Espírito, +12 Intelecto", effects = "|cff00ff00Equip: +19 Poder de Cura.|r" } },
    [18410] = { itemId = 14151, quality = 2, source = "trainer", stats = { slot = "Torso (Tecido)", armor = 64, itemLevel = 52, reqLevel = 47, attrs = "+10 Estamina", effects = "|cff00ff00Equip: +27 Dano de Sombra.|r" } },
    [18411] = { itemId = 14138, quality = 2, source = "trainer", stats = { slot = "Torso (Tecido)", armor = 62, itemLevel = 48, reqLevel = 43, attrs = "+14 Intelecto, +9 Espírito" } },
    [18412] = { itemId = 18405, quality = 4, source = "drop", stats = { slot = "Cintura (Tecido)", armor = 54, itemLevel = 62, reqLevel = 57, attrs = "+16 Intelecto, +10 Estamina", effects = "|cff00ff00Equip: +25 Dano Mágico, +1% Crítico.|r" } },
    [18407] = { itemId = 14342, quality = 2, source = "trainer", stats = { slot = "Reagente", flavor = "Tecido abençoado em Poços da Lua." } },

    -- ENCHANTING
    [20034] = { itemId = 16252, quality = 3, source = "drop", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Frequentemente cura 100 de Vida e concede +100 Força por 15s ao golpear.|r" } },
    [22749] = { itemId = 18259, quality = 3, source = "reputation", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Aumenta permanentemente o poder de cura em até 55.|r" } },
    [22750] = { itemId = 18260, quality = 3, source = "drop", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Aumenta permanentemente o dano de feitiços em até 30.|r" } },
    [23801] = { itemId = 19448, quality = 2, source = "reputation", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Aumenta permanentemente a Agilidade em 15.|r" } },
    [23802] = { itemId = 19449, quality = 2, source = "reputation", stats = { slot = "Encantamento de 2M", effects = "|cff00ff00Aumenta permanentemente a Agilidade em 25.|r" } },
    [20032] = { itemId = 16253, quality = 3, source = "drop", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Frequentemente rouba 30 de vida do alvo para curar o portador.|r" } },
    [20033] = { itemId = 16254, quality = 2, source = "drop", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Frequentemente amaldiçoa o alvo, reduzindo dano em 15 e infligindo dano de sombra.|r" } },
    [13890] = { itemId = 11207, quality = 2, source = "drop", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Frequentemente incendeia o alvo causando 40 de dano de Fogo.|r" } },
    [20029] = { itemId = 16246, quality = 1, source = "trainer", stats = { slot = "Encantamento de Arma", effects = "|cff00ff00Aumenta o dano da arma em +5.|r" } },
    [20030] = { itemId = 16247, quality = 1, source = "trainer", stats = { slot = "Encantamento de 2M", effects = "|cff00ff00Aumenta o dano da arma de duas mãos em +9.|r" } },
    [20025] = { itemId = 16245, quality = 2, source = "drop", stats = { slot = "Encantamento de Torso", effects = "|cff00ff00Aumenta todos os atributos em +4.|r" } },
    [20026] = { itemId = 16244, quality = 1, source = "trainer", stats = { slot = "Encantamento de Torso", effects = "|cff00ff00Aumenta a Vida máxima em 100.|r" } },
    [20028] = { itemId = 16243, quality = 1, source = "trainer", stats = { slot = "Encantamento de Torso", effects = "|cff00ff00Aumenta a Mana máxima em 100.|r" } },
    [20010] = { itemId = 16223, quality = 2, source = "drop", stats = { slot = "Encantamento de Braçadeiras", effects = "|cff00ff00Aumenta o Vigor em +9.|r" } },
    [20011] = { itemId = 16224, quality = 2, source = "drop", stats = { slot = "Encantamento de Braçadeiras", effects = "|cff00ff00Aumenta a Força em +9.|r" } },
    [20012] = { itemId = 16221, quality = 1, source = "trainer", stats = { slot = "Encantamento de Braçadeiras", effects = "|cff00ff00Aumenta o Intelecto em +7.|r" } },
    [23803] = { itemId = 19445, quality = 2, source = "reputation", stats = { slot = "Encantamento de Braçadeiras", effects = "|cff00ff00Aumenta o Poder de Cura em até 24.|r" } },
    [23804] = { itemId = 19444, quality = 2, source = "reputation", stats = { slot = "Encantamento de Braçadeiras", effects = "|cff00ff00Regenera 4 de Mana a cada 5s.|r" } },
    [20023] = { itemId = 16242, quality = 2, source = "drop", stats = { slot = "Encantamento de Botas", effects = "|cff00ff00Aumenta a Agilidade em +7.|r" } },
    [20024] = { itemId = 16241, quality = 1, source = "trainer", stats = { slot = "Encantamento de Botas", effects = "|cff00ff00Aumenta o Vigor em +7.|r" } },
    [20017] = { itemId = 16220, quality = 2, source = "drop", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta a Agilidade em +7.|r" } },
    [20018] = { itemId = 16219, quality = 2, source = "drop", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta a Força em +7.|r" } },
    [25072] = { itemId = 20727, quality = 2, source = "reputation", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta a geração de Ameaça.|r" } },
    [25073] = { itemId = 20728, quality = 2, source = "reputation", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta o Dano de Sombra em até 20.|r" } },
    [25074] = { itemId = 20729, quality = 2, source = "reputation", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta o Dano de Gelo em até 20.|r" } },
    [25075] = { itemId = 20730, quality = 2, source = "reputation", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta o Dano de Fogo em até 20.|r" } },
    [25078] = { itemId = 20731, quality = 2, source = "reputation", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta o Poder de Cura em até 30.|r" } },
    [25080] = { itemId = 20732, quality = 2, source = "reputation", stats = { slot = "Encantamento de Luvas", effects = "|cff00ff00Aumenta a Agilidade em +15.|r" } },
    [20014] = { itemId = 16217, quality = 1, source = "trainer", stats = { slot = "Encantamento de Capa", effects = "|cff00ff00Aumenta todas as Resistências em +5.|r" } },
    [20015] = { itemId = 16216, quality = 1, source = "trainer", stats = { slot = "Encantamento de Capa", effects = "|cff00ff00Aumenta a Armadura em +70.|r" } },
    [25081] = { itemId = 20734, quality = 2, source = "reputation", stats = { slot = "Encantamento de Capa", effects = "|cff00ff00Reduz a geração de Ameaça em 2%.|r" } },
    [25082] = { itemId = 20735, quality = 2, source = "reputation", stats = { slot = "Encantamento de Capa", effects = "|cff00ff00Aumenta a chance de Esquiva em 1%.|r" } },
    [25083] = { itemId = 20736, quality = 2, source = "reputation", stats = { slot = "Encantamento de Capa", effects = "|cff00ff00Aumenta a eficácia de Furtividade em +5.|r" } },
    [25129] = { itemId = 20749, quality = 2, source = "reputation", stats = { slot = "Óleo de Arma", effects = "|cff00ff00Uso: +36 Dano de Feitiço e +1% Crítico por 30 min.|r" } },
    [25130] = { itemId = 20748, quality = 2, source = "reputation", stats = { slot = "Óleo de Arma", effects = "|cff00ff00Uso: +12 Mana/5s e +25 Cura por 30 min.|r" } },

    -- BLACKSMITHING
    [16983] = { itemId = 12640, quality = 4, source = "drop", stats = { slot = "Cabeça (Placas)", armor = 565, itemLevel = 61, reqLevel = 56, effects = "|cff00ff00Equip: +2% Acerto, +2% Acerto Crítico.|r" } },
    [26735] = { itemId = 22385, quality = 4, source = "drop", stats = { slot = "Pernas (Placas)", armor = 620, itemLevel = 65, reqLevel = 60, attrs = "+30 Força", effects = "|cff00ff00Equip: +1% Crítico, +2% Acerto.|r" } },
    [16984] = { itemId = 12639, quality = 4, source = "drop", stats = { slot = "Mãos (Placas)", armor = 468, itemLevel = 62, reqLevel = 57, attrs = "+12 Estamina", effects = "|cff00ff00Equip: +1% Crítico, +1% Esquiva, imunidade a desarmar.|r" } },
    [16985] = { itemId = 12641, quality = 4, source = "drop", stats = { slot = "Torso (Malha)", armor = 458, itemLevel = 62, reqLevel = 57, attrs = "+13 Força, +15 Estamina", effects = "|cff00ff00Uso: Imune a ataques físicos por 5s.|r" } },
    [23629] = { itemId = 19169, quality = 4, source = "reputation", stats = { slot = "Machado de 2 Mãos", armor = 0, itemLevel = 65, reqLevel = 60, effects = "|cff00ff00Chance ao golpear: Aumenta o dano mágico recebido pelo alvo em 15% por 5s.|r" } },
    [16963] = { itemId = 12784, quality = 3, source = "drop", stats = { slot = "Machado de 2 Mãos", armor = 0, itemLevel = 63, reqLevel = 58, attrs = "+62 Poder de Ataque, +13 Estamina" } },
    [16964] = { itemId = 12798, quality = 3, source = "drop", stats = { slot = "Machado de 1 Mão", armor = 0, itemLevel = 63, reqLevel = 58, effects = "|cff00ff00Chance ao golpear: Reduz a armadura do alvo em 200 (acumula até 3x).|r" } },
    [21162] = { itemId = 17193, quality = 4, source = "reputation", stats = { slot = "Maça de 2 Mãos", armor = 0, itemLevel = 70, reqLevel = 60, attrs = "+12 Força, +12 Estamina, +30 Resistência a Fogo", effects = "|cff00ff00Chance de lançar bola de fogo de 273 a 333 de dano.|r" } },
    [19163] = { itemId = 17013, quality = 3, source = "reputation", stats = { slot = "Maça de 2 Mãos", armor = 0, itemLevel = 60, reqLevel = 55, attrs = "+18 Resistência a Fogo", effects = "|cff00ff00Chance de atordoar o alvo por 8s.|r" } },
    [19164] = { itemId = 17014, quality = 3, source = "reputation", stats = { slot = "Torso (Placas)", armor = 826, itemLevel = 60, reqLevel = 55, attrs = "+19 Resistência a Fogo", effects = "|cff00ff00Equip: Reflete 15 de dano de Fogo nos atacantes.|r" } },
    [19165] = { itemId = 17015, quality = 3, source = "reputation", stats = { slot = "Pernas (Placas)", armor = 734, itemLevel = 60, reqLevel = 55, attrs = "+14 Estamina, +30 Resistência a Fogo" } },
    [19166] = { itemId = 17016, quality = 3, source = "reputation", stats = { slot = "Cabeça (Placas)", armor = 642, itemLevel = 60, reqLevel = 55, attrs = "+20 Estamina, +35 Resistência a Fogo" } },
    [19167] = { itemId = 17017, quality = 3, source = "reputation", stats = { slot = "Pés (Placas)", armor = 550, itemLevel = 60, reqLevel = 55, attrs = "+12 Estamina, +28 Resistência a Fogo" } },
    [19168] = { itemId = 17018, quality = 3, source = "reputation", stats = { slot = "Mãos (Placas)", armor = 459, itemLevel = 60, reqLevel = 55, attrs = "+16 Estamina, +28 Resistência a Fogo" } },
    [16970] = { itemId = 12422, quality = 2, source = "trainer", stats = { slot = "Torso (Placas)", armor = 624, itemLevel = 54, reqLevel = 49, attrs = "+21 Força, +10 Estamina" } },
    [16971] = { itemId = 12424, quality = 2, source = "trainer", stats = { slot = "Cabeça (Placas)", armor = 485, itemLevel = 52, reqLevel = 47, attrs = "+18 Força, +9 Estamina" } },
    [16972] = { itemId = 12426, quality = 2, source = "trainer", stats = { slot = "Pés (Placas)", armor = 416, itemLevel = 52, reqLevel = 47, attrs = "+13 Força, +12 Estamina" } },
    [16973] = { itemId = 12427, quality = 2, source = "trainer", stats = { slot = "Pernas (Placas)", armor = 554, itemLevel = 53, reqLevel = 48, attrs = "+16 Força, +14 Estamina" } },
    [16974] = { itemId = 12428, quality = 2, source = "trainer", stats = { slot = "Ombros (Placas)", armor = 416, itemLevel = 52, reqLevel = 47, attrs = "+12 Força, +12 Estamina" } },
    [16975] = { itemId = 12404, quality = 1, source = "trainer", stats = { slot = "Consumível", effects = "|cff00ff00Uso: Aumenta o dano de arma cortante em +8 por 30 min.|r" } },
    [16976] = { itemId = 12643, quality = 1, source = "trainer", stats = { slot = "Consumível", effects = "|cff00ff00Uso: Aumenta o dano de arma contundente em +8 por 30 min.|r" } },
    [22759] = { itemId = 18262, quality = 2, source = "reputation", stats = { slot = "Consumível", effects = "|cff00ff00Uso: Aumenta o Crítico da arma em +2% por 30 min.|r" } },
    [19169] = { itemId = 15869, quality = 2, source = "trainer", stats = { slot = "Chave", effects = "|cff00ff00Uso: Abre fechaduras trancadas até perícia 300.|r" } },
    [19170] = { itemId = 7969, quality = 2, source = "trainer", stats = { slot = "Reforço", effects = "|cff00ff00Uso: Aumenta permanentemente a velocidade de montaria nas botas.|r" } },
    [19171] = { itemId = 12645, quality = 1, source = "trainer", stats = { slot = "Reforço de Escudo", effects = "|cff00ff00Uso: Causa 26 a 38 de dano ao atacante ao bloquear.|r" } },

    -- ENGINEERING
    [13240] = { itemId = 10646, quality = 1, source = "trainer", stats = { slot = "Explosivo", effects = "|cff00ff00Uso: Inflige 450 a 750 de dano de Fogo a inimigos próximos e causa dano a você.|r" } },
    [12903] = { itemId = 4390, quality = 1, source = "trainer", stats = { slot = "Explosivo", effects = "|cff00ff00Uso: Inflige 132 a 218 de dano de Fogo e atordoa por 3s em 5m.|r" } },
    [19790] = { itemId = 15993, quality = 1, source = "trainer", stats = { slot = "Explosivo", effects = "|cff00ff00Uso: Inflige 219 a 381 de dano de Fogo e atordoa por 3s em 3m.|r" } },
    [19791] = { itemId = 18641, quality = 1, source = "trainer", stats = { slot = "Explosivo", effects = "|cff00ff00Uso: Inflige 260 a 440 de dano de Fogo em 5m.|r" } },
    [19792] = { itemId = 16005, quality = 1, source = "trainer", stats = { slot = "Explosivo", effects = "|cff00ff00Uso: Inflige 470 a 830 de dano de Fogo e atordoa por 5s em 5m.|r" } },
    [22760] = { itemId = 18232, quality = 2, source = "drop", stats = { slot = "Dispositivo", effects = "|cff00ff00Uso: Invoca um robô de campo que compra e repara equipamentos por 10 min.|r" } },
    [12908] = { itemId = 10725, quality = 2, source = "trainer", stats = { slot = "Berloque", effects = "|cff00ff00Uso: Canaliza um raio da morte massivo contra o alvo.|r", reqLevel = 40 } },
    [12909] = { itemId = 10726, quality = 2, source = "trainer", stats = { slot = "Berloque", effects = "|cff00ff00Uso: Invoca uma Galinha de Combate que luta e concede +5% velocidade de ataque ao grupo.|r", reqLevel = 40 } },
    [13241] = { itemId = 10545, quality = 2, source = "trainer", stats = { slot = "Cabeça (Tecido)", armor = 50, itemLevel = 45, reqLevel = 40, effects = "|cff00ff00Uso: Investe violentamente contra o alvo atordoando-o por 30s.|r" } },
    [13242] = { itemId = 7189, quality = 2, source = "trainer", stats = { slot = "Pés (Tecido)", armor = 41, itemLevel = 40, reqLevel = 35, effects = "|cff00ff00Uso: Aumenta muito a velocidade de corrida por 20s. (Pode explodir!)|r" } },
    [12910] = { itemId = 10724, quality = 2, source = "trainer", stats = { slot = "Pés (Tecido)", armor = 41, itemLevel = 40, reqLevel = 35, effects = "|cff00ff00Uso: Aumenta a velocidade de corrida por 20s.|r" } },
    [12911] = { itemId = 10720, quality = 2, source = "trainer", stats = { slot = "Berloque", effects = "|cff00ff00Uso: Lança uma rede no alvo, imobilizando-o por 10s.|r", reqLevel = 35 } },
    [12912] = { itemId = 10726, quality = 2, source = "trainer", stats = { slot = "Cabeça (Tecido)", armor = 50, itemLevel = 45, reqLevel = 40, effects = "|cff00ff00Uso: Assume o controle mental do alvo humanoide por 20s.|r" } },
    [13243] = { itemId = 18587, quality = 2, source = "trainer", stats = { slot = "Dispositivo", effects = "|cff00ff00Uso: Tenta ressuscitar um aliado caído com choque elétrico.|r" } },
    [13244] = { itemId = 7148, quality = 1, source = "trainer", stats = { slot = "Dispositivo", effects = "|cff00ff00Uso: Tenta ressuscitar um aliado caído.|r" } },
    [12913] = { itemId = 10792, quality = 2, source = "trainer", stats = { slot = "Berloque", effects = "|cff00ff00Uso: Concede invisibilidade por 10s.|r", reqLevel = 35 } },
    [22761] = { itemId = 18638, quality = 3, source = "trainer", stats = { slot = "Berloque", effects = "|cff00ff00Uso: Reflete feitiços de Fogo de volta para o conjurador por 5s. +18 Resistência a Fogo.|r", reqLevel = 54 } },
    [22762] = { itemId = 18634, quality = 3, source = "trainer", stats = { slot = "Berloque", effects = "|cff00ff00Uso: Reflete feitiços de Gelo de volta para o conjurador por 5s. +15 Resistência a Gelo.|r", reqLevel = 47 } },
    [22763] = { itemId = 18639, quality = 3, source = "trainer", stats = { slot = "Berloque", effects = "|cff00ff00Uso: Reflete feitiços de Sombra de volta para o conjurador por 5s. +18 Resistência a Sombra.|r", reqLevel = 54 } },
    [12914] = { itemId = 10503, quality = 2, source = "trainer", stats = { slot = "Cabeça (Tecido)", armor = 55, itemLevel = 55, reqLevel = 50, effects = "|cff00ff00Equip: +45 Dano Mágico.|r" } },
    [12915] = { itemId = 10504, quality = 2, source = "trainer", stats = { slot = "Cabeça (Tecido)", armor = 55, itemLevel = 57, reqLevel = 52, attrs = "+15 Estamina", effects = "|cff00ff00Equip: Permite enxergar unidades furtivas e aumenta perícia de engenharia em +5.|r" } },
    [12916] = { itemId = 10501, quality = 2, source = "trainer", stats = { slot = "Cabeça (Tecido)", armor = 45, itemLevel = 45, reqLevel = 40, effects = "|cff00ff00Equip: Aumenta a detecção de furtividade.|r" } },
    [19793] = { itemId = 15997, quality = 2, source = "trainer", stats = { slot = "Munição", effects = "|cff00ff00Adiciona 17.5 de dano por segundo aos disparos.|r", reqLevel = 52 } },
    [19794] = { itemId = 10593, quality = 2, source = "trainer", stats = { slot = "Mira de Arma", effects = "|cff00ff00Uso: Aumenta permanentemente o dano de uma arma de longo alcance em +7.|r" } },
    [19795] = { itemId = 4366, quality = 1, source = "trainer", stats = { slot = "Dispositivo", effects = "|cff00ff00Uso: Posiciona um boneco de treino que atrai a atenção de monstros próximos.|r" } },
    [19796] = { itemId = 4398, quality = 1, source = "trainer", stats = { slot = "Dispositivo", effects = "|cff00ff00Uso: Posiciona um boneco de treino avançado para monstros mais fortes.|r" } },
    [19797] = { itemId = 16023, quality = 2, source = "trainer", stats = { slot = "Dispositivo", effects = "|cff00ff00Uso: Posiciona um boneco de treino resistente capaz de suportar grandes danos.|r" } },
    [19798] = { itemId = 10518, quality = 2, source = "trainer", stats = { slot = "Costas", armor = 25, itemLevel = 45, reqLevel = 40, effects = "|cff00ff00Uso: Queda lenta por 10s.|r" } },
}

--- Mapa indexado por ID de receita: [recipeId] = recipeData
local RECIPES_BY_ID = {}
--- Mapa indexado por ID de item gerado: [itemId] = recipeData
local RECIPES_BY_ITEM_ID = {}
--- Mapa indexado por Profissão: [profKey] = { recipe1, recipe2, ... }
local RECIPES_BY_PROF = {}
--- Mapa indexado por nome normalizado: [normName] = recipeData
local RECIPES_BY_NAME = {}
--- Mapa dinâmico de receitas adicionadas em tempo de execução via scan: [profKey] = { [recipeId] = recipeData }
local DYNAMIC_RECIPES = {}

for _, profKey in ipairs(ProfessionData.ORDER) do
    RECIPES_BY_PROF[profKey] = {}
    DYNAMIC_RECIPES[profKey] = {}
end

--- Normaliza textos removendo acentos e pontuação para busca resiliente no WoW Classic
---@param txt string|nil
---@return string
function ProfessionData.normalizeText(txt)
    if not txt or type(txt) ~= "string" then return "" end
    local s = txt:lower()
    s = s:gsub("á", "a"):gsub("à", "a"):gsub("ã", "a"):gsub("â", "a"):gsub("ä", "a")
    s = s:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
    s = s:gsub("í", "i"):gsub("ì", "i"):gsub("î", "i"):gsub("ï", "i")
    s = s:gsub("ó", "o"):gsub("ò", "o"):gsub("õ", "o"):gsub("ô", "o"):gsub("ö", "o")
    s = s:gsub("ú", "u"):gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
    s = s:gsub("ç", "c"):gsub("ñ", "n")
    s = s:gsub("[^%w%s]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

for _, r in ipairs(RECIPES) do
    -- Mescla metadados enriquecidos
    local meta = ITEM_METADATA[r.id]
    if meta then
        r.itemId = meta.itemId
        if meta.quality then r.quality = meta.quality end
        if meta.source then r.source = meta.source end
        if meta.stats then r.stats = meta.stats end
    end

    RECIPES_BY_ID[r.id] = r
    if r.itemId then
        RECIPES_BY_ITEM_ID[r.itemId] = r
    end
    if RECIPES_BY_PROF[r.prof] then
        table.insert(RECIPES_BY_PROF[r.prof], r)
    end
    if r.name then
        local n1 = ProfessionData.normalizeText(r.name)
        if n1 ~= "" then RECIPES_BY_NAME[n1] = r end
    end
    if r.namePT then
        local n2 = ProfessionData.normalizeText(r.namePT)
        if n2 ~= "" then RECIPES_BY_NAME[n2] = r end
    end
end

--- Retorna a lista de todas as receitas de uma profissão com deduplicação estrita
---@param profKey string
---@return table[]
function ProfessionData.getRecipesForProfession(profKey)
    local list = {}
    local seenId = {}
    local seenName = {}

    local function addRecipe(r)
        if not r or not r.id then return false end
        local canonId = r.id
        local numId = tonumber(canonId)
        local n1 = r.name and ProfessionData.normalizeText(r.name) or ""
        local n2 = r.namePT and ProfessionData.normalizeText(r.namePT) or ""

        if seenId[canonId] or (numId and seenId[numId]) or (numId and seenId[tostring(numId)]) then
            return false
        end
        if n1 ~= "" and seenName[n1] then
            return false
        end
        if n2 ~= "" and seenName[n2] then
            return false
        end

        seenId[canonId] = true
        if numId then
            seenId[numId] = true
            seenId[tostring(numId)] = true
        end
        if n1 ~= "" then seenName[n1] = true end
        if n2 ~= "" then seenName[n2] = true end
        table.insert(list, r)
        return true
    end

    -- 1. Catálogo canônico da profissão
    local staticList = RECIPES_BY_PROF[profKey] or {}
    for _, r in ipairs(staticList) do
        addRecipe(r)
    end

    -- 2. Receitas descobertas dinamicamente nesta sessão
    if DYNAMIC_RECIPES[profKey] then
        local toRemoveDyn = nil
        for dynId, r in pairs(DYNAMIC_RECIPES[profKey]) do
            local added = addRecipe(r)
            if not added then
                toRemoveDyn = toRemoveDyn or {}
                table.insert(toRemoveDyn, dynId)
            end
        end
        if toRemoveDyn then
            for _, dId in ipairs(toRemoveDyn) do
                DYNAMIC_RECIPES[profKey][dId] = nil
            end
        end
    end

    -- 3. Receitas persistidas no SavedVariables (GM_DB) - sanitiza duplicatas acumuladas
    if _G.GM_DB and _G.GM_DB.dynamicRecipes and _G.GM_DB.dynamicRecipes[profKey] then
        local toRemoveDb = nil
        for dbKey, r in pairs(_G.GM_DB.dynamicRecipes[profKey]) do
            local added = addRecipe(r)
            if not added then
                toRemoveDb = toRemoveDb or {}
                table.insert(toRemoveDb, dbKey)
            end
        end
        if toRemoveDb then
            for _, dbKey in ipairs(toRemoveDb) do
                _G.GM_DB.dynamicRecipes[profKey][dbKey] = nil
            end
        end
    end

    -- Ordena por skill requerida crescente e depois por nome
    table.sort(list, function(a, b)
        if (a.skill or 0) ~= (b.skill or 0) then
            return (a.skill or 0) < (b.skill or 0)
        end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

--- Retorna uma receita pelo seu identificador único (ID de feitiço, itemId ou nome)
---@param recipeId number|string
---@param profKey string|nil
---@return table|nil
function ProfessionData.getRecipeById(recipeId, profKey)
    if not recipeId then return nil end
    local numId = tonumber(recipeId)

    -- 1. Busca por Spell ID no catálogo padrão
    if numId and RECIPES_BY_ID[numId] then
        return RECIPES_BY_ID[numId]
    end
    if RECIPES_BY_ID[recipeId] then
        return RECIPES_BY_ID[recipeId]
    end

    -- 2. Busca por Item ID gerado no catálogo padrão
    if numId and RECIPES_BY_ITEM_ID[numId] then
        return RECIPES_BY_ITEM_ID[numId]
    end
    if RECIPES_BY_ITEM_ID[recipeId] then
        return RECIPES_BY_ITEM_ID[recipeId]
    end

    -- 3. Busca nas receitas dinâmicas
    if profKey and DYNAMIC_RECIPES[profKey] and DYNAMIC_RECIPES[profKey][recipeId] then
        return DYNAMIC_RECIPES[profKey][recipeId]
    end
    if _G.GM_DB and _G.GM_DB.dynamicRecipes then
        if profKey and _G.GM_DB.dynamicRecipes[profKey] and _G.GM_DB.dynamicRecipes[profKey][recipeId] then
            return _G.GM_DB.dynamicRecipes[profKey][recipeId]
        end
        for _, pKey in ipairs(ProfessionData.ORDER) do
            if _G.GM_DB.dynamicRecipes[pKey] and _G.GM_DB.dynamicRecipes[pKey][recipeId] then
                return _G.GM_DB.dynamicRecipes[pKey][recipeId]
            end
        end
    end
    for _, pKey in ipairs(ProfessionData.ORDER) do
        if DYNAMIC_RECIPES[pKey] and DYNAMIC_RECIPES[pKey][recipeId] then
            return DYNAMIC_RECIPES[pKey][recipeId]
        end
    end

    -- 4. Fallback: Busca pelo nome da receita (em inglês ou português normalizado)
    if type(recipeId) == "string" then
        local rawLower = recipeId:lower()
        local normInput = ProfessionData.normalizeText(recipeId)
        local staticList = profKey and RECIPES_BY_PROF[profKey] or RECIPES
        for _, r in ipairs(staticList) do
            if (r.name and r.name:lower() == rawLower) or (r.namePT and r.namePT:lower() == rawLower) then
                return r
            end
            if normInput ~= "" then
                if r.name and ProfessionData.normalizeText(r.name) == normInput then return r end
                if r.namePT and ProfessionData.normalizeText(r.namePT) == normInput then return r end
            end
        end
    end

    return nil
end

--- Retorna uma receita pelo ID do item gerado
---@param itemId number|string
---@return table|nil
function ProfessionData.getRecipeByItemId(itemId)
    if not itemId then return nil end
    local num = tonumber(itemId)
    if num and RECIPES_BY_ITEM_ID[num] then return RECIPES_BY_ITEM_ID[num] end
    return RECIPES_BY_ITEM_ID[itemId]
end

--- Registra dinamicamente uma receita aprendida que não esteja no catálogo padrão
---@param profKey string
---@param recipeData table
function ProfessionData.registerDynamicRecipe(profKey, recipeData)
    if not profKey or not recipeData or not recipeData.id then return end

    -- Não registra se já existe no catálogo padrão (por ID, ItemID ou Nome)
    local numId = tonumber(recipeData.id)
    if (numId and RECIPES_BY_ID[numId]) or RECIPES_BY_ID[recipeData.id] then return end
    if (numId and RECIPES_BY_ITEM_ID[numId]) or RECIPES_BY_ITEM_ID[recipeData.id] then return end
    if recipeData.name then
        local n1 = ProfessionData.normalizeText(recipeData.name)
        if n1 ~= "" and RECIPES_BY_NAME[n1] then return end
    end
    if recipeData.namePT then
        local n2 = ProfessionData.normalizeText(recipeData.namePT)
        if n2 ~= "" and RECIPES_BY_NAME[n2] then return end
    end

    if not DYNAMIC_RECIPES[profKey] then
        DYNAMIC_RECIPES[profKey] = {}
    end
    if not DYNAMIC_RECIPES[profKey][recipeData.id] then
        DYNAMIC_RECIPES[profKey][recipeData.id] = recipeData
    end
    if _G.GM_DB then
        _G.GM_DB.dynamicRecipes = _G.GM_DB.dynamicRecipes or {}
        _G.GM_DB.dynamicRecipes[profKey] = _G.GM_DB.dynamicRecipes[profKey] or {}
        _G.GM_DB.dynamicRecipes[profKey][recipeData.id] = recipeData
    end
end

--- Retorna o nome da receita de acordo com o idioma ativo
---@param recipe table
---@return string
function ProfessionData.getRecipeDisplayName(recipe)
    if not recipe then return "" end
    local isPt = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "ptBR")
    if isPt and recipe.namePT and recipe.namePT ~= "" then
        return recipe.namePT
    end
    return recipe.name or tostring(recipe.id)
end

--- Retorna o nome da categoria da receita de acordo com o idioma ativo
---@param recipe table
---@return string
function ProfessionData.getRecipeCategoryName(recipe)
    if not recipe then return "Geral" end
    local isPt = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "ptBR")
    if isPt and recipe.categoryPT and recipe.categoryPT ~= "" then
        return recipe.categoryPT
    end
    return recipe.category or "General"
end

--- Retorna a cor hexadecimal baseada na qualidade do item
---@param quality number
---@return string
function ProfessionData.getQualityColor(quality)
    if quality == 4 then return "|cffa335ee" end -- Epic (Roxo)
    if quality == 3 then return "|cff0070dd" end -- Rare (Azul)
    if quality == 2 then return "|cff1eff00" end -- Uncommon (Verde)
    if quality == 1 then return "|cffffffff" end -- Common (Branco)
    if quality == 0 then return "|cff9d9d9d" end -- Poor (Cinza)
    return "|cffffffff"
end

--- Retorna os valores RGB normalizados (0-1) baseados na qualidade do item
---@param quality number
---@return number, number, number
function ProfessionData.getQualityRGB(quality)
    if quality == 4 then return 0.64, 0.21, 0.93 end -- Epic (Roxo)
    if quality == 3 then return 0.00, 0.44, 0.87 end -- Rare (Azul)
    if quality == 2 then return 0.12, 1.00, 0.00 end -- Uncommon (Verde)
    if quality == 1 then return 1.00, 1.00, 1.00 end -- Common (Branco)
    if quality == 0 then return 0.62, 0.62, 0.62 end -- Poor (Cinza)
    return 1.00, 1.00, 1.00
end

--- Retorna o nome amigável da qualidade/raridade conforme o idioma ativo
---@param quality number
---@return string
function ProfessionData.getQualityName(quality)
    local isPt = (_G.GM and _G.GM.GetLocale and _G.GM.GetLocale() == "ptBR")
    if quality == 4 then return isPt and "Épico" or "Epic" end
    if quality == 3 then return isPt and "Raro" or "Rare" end
    if quality == 2 then return isPt and "Incomum" or "Uncommon" end
    if quality == 0 then return isPt and "Pobre" or "Poor" end
    return isPt and "Comum" or "Common"
end

--- Cache em memória para dados de itens mesclados (estáticos + GetItemInfo)
local _itemDataCache = {}

--- Limpa o cache de dados de itens (chamado no evento GET_ITEM_INFO_RECEIVED)
function ProfessionData.clearItemCache()
    _itemDataCache = {}
end

--- Retorna a estrutura consolidada de dados do item produzido pela receita
--- Mescla dados estáticos detalhados com informações em tempo real da WoW API (GetItemInfo)
---@param recipe table
---@return table
function ProfessionData.getItemData(recipe)
    if not recipe then return nil end
    local cacheKey = recipe.itemId or recipe.id
    if _itemDataCache[cacheKey] then
        return _itemDataCache[cacheKey]
    end

    local quality = recipe.quality or 1
    local icon = recipe.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local name = ProfessionData.getRecipeDisplayName(recipe)
    local itemLevel = recipe.stats and recipe.stats.itemLevel
    local reqLevel = recipe.stats and recipe.stats.reqLevel
    local itemSlot = recipe.stats and recipe.stats.slot
    local itemDesc = recipe.stats and recipe.stats.desc

    -- Consulta a WoW API se houver itemId disponível e a função existir
    if recipe.itemId and _G.GetItemInfo then
        local iName, iLink, iQuality, iLevel, iReqLevel, iClass, iSubClass, iMaxStack, iEquipLoc, iTexture = _G.GetItemInfo(recipe.itemId)
        if iName then
            name = iName
            if iQuality and iQuality > 0 then quality = iQuality end
            if iLevel and iLevel > 0 then itemLevel = iLevel end
            if iReqLevel and iReqLevel > 0 then reqLevel = iReqLevel end
            if iTexture and iTexture ~= "" then icon = iTexture end
            if iEquipLoc and iEquipLoc ~= "" and _G[iEquipLoc] then
                itemSlot = _G[iEquipLoc]
            end
        end
    end

    local r, g, b = ProfessionData.getQualityRGB(quality)
    local colorHex = ProfessionData.getQualityColor(quality)
    local qualityName = ProfessionData.getQualityName(quality)

    local res = {
        name = name,
        quality = quality,
        qualityColor = colorHex,
        qualityName = qualityName,
        r = r, g = g, b = b,
        icon = icon,
        itemLevel = itemLevel,
        reqLevel = reqLevel,
        slot = itemSlot,
        armor = recipe.stats and recipe.stats.armor,
        attrs = recipe.stats and recipe.stats.attrs,
        effects = recipe.stats and recipe.stats.effects,
        desc = itemDesc,
        flavor = recipe.stats and recipe.stats.flavor,
        source = recipe.source or (recipe.stats and recipe.stats.source) or "trainer",
    }

    _itemDataCache[cacheKey] = res
    return res
end
