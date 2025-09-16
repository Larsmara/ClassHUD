-- ClassHUD_SpellSuggestions.lua
-- Prefilled list of common spells per class/spec

ClassHUD_SpellSuggestions = {
    DEATHKNIGHT = {
        [250] = {}, -- Blood
        [251] = {}, -- Frost
        [252] = {}, -- Unholy
        UTILITY = {}
    },
    DEMONHUNTER = {
        [577] = {}, -- Havoc
        [581] = {}, -- Vengeance
        UTILITY = {}
    },
    DRUID = {
        [102] = { -- Balance
            { id = 194223, name = "Celestial Alignment" },
            { id = 102560, name = "Incarnation: Chosen of Elune" },
            { id = 78674,  name = "Starsurge" },
            { id = 191034, name = "Starfall" },
            { id = 202770, name = "Fury of Elune" },
            { id = 24858,  name = "Moonkin Form" },
        },

        [103] = { -- Feral
            { id = 106951, name = "Berserk" },
            { id = 102543, name = "Incarnation: King of the Jungle" },
            { id = 22568,  name = "Ferocious Bite" },
            { id = 1079,   name = "Rip" },
            { id = 1822,   name = "Rake" },
            { id = 52610,  name = "Savage Roar" },
            { id = 5217,   name = "Tiger's Fury" },
        },

        [104] = { -- Guardian
            { id = 22812,  name = "Barkskin" },
            { id = 61336,  name = "Survival Instincts" },
            { id = 192081, name = "Ironfur" },
            { id = 22842,  name = "Frenzied Regeneration" },
            { id = 200851, name = "Rage of the Sleeper" },
            { id = 99,     name = "Incapacitating Roar" },
            { id = 203953, name = "Brambles" },
        },

        [105] = { -- Restoration
            { id = 740,    name = "Tranquility" },
            { id = 18562,  name = "Swiftmend" },
            { id = 48438,  name = "Wild Growth" },
            { id = 774,    name = "Rejuvenation" },
            { id = 33763,  name = "Lifebloom" },
            { id = 8936,   name = "Regrowth" },
            { id = 102342, name = "Ironbark" },
            { id = 207385, name = "Spring Blossoms" },
        },

        -- Shared / Utility (any spec can use, you may choose to merge under each)
        ["UTILITY"] = {
            { id = 106898, name = "Stampeding Roar" },
            { id = 132158, name = "Nature's Swiftness" },
            { id = 29166,  name = "Innervate" },
            { id = 2782,   name = "Remove Corruption" },
            { id = 22812,  name = "Barkskin" }, -- baseline too
            { id = 99,     name = "Incapacitating Roar" },
            { id = 5211,   name = "Mighty Bash" },
            { id = 33786,  name = "Cyclone" },
            { id = 102359, name = "Mass Entanglement" },
        }
    },
    EVOKER = {
        [1467] = {}, -- Devastation
        [1468] = {}, -- Preservation
        [1473] = {}, -- Augmentation
        UTILITY = {}
    },
    HUNTER = {
        [253] = {}, -- Beast Mastery
        [254] = {}, -- Marksmanship
        [255] = {}, -- Survival
        UTILITY = {}
    },
    MAGE = {
        [62] = { { id = 12042, name = "Arcane Power" } }, -- Arcane
        [63] = {},                                        -- Fire
        [64] = {},                                        -- Frost
        UTILITY = {}
    },
    MONK = {
        [268] = {}, -- Brewmaster
        [269] = {}, -- Windwalker
        [270] = {}, -- Mistweaver
        UTILITY = {}
    },
    PALADIN = {
        [65] = {}, -- Holy
        [66] = {}, -- Protection
        [70] = {}, -- Retribution
        UTILITY = {}
    },
    PRIEST = {
        [256] = {}, -- Discipline
        [257] = {}, -- Holy
        [258] = {}, -- Shadow
        UTILITY = {}
    },
    ROGUE = {
        [259] = {}, -- Assassination
        [260] = {}, -- Outlaw
        [261] = {}, -- Subtlety
        UTILITY = {}
    },
    SHAMAN = {
        [262] = {}, -- Elemental
        [263] = {}, -- Enhancement
        [264] = {}, -- Restoration
        UTILITY = {}
    },
    WARLOCK = {
        [265] = { -- Affliction
            { id = 172,    name = "Corruption" },
            { id = 980,    name = "Agony" },
            { id = 30108,  name = "Unstable Affliction" },
            { id = 48181,  name = "Haunt" },
            { id = 63106,  name = "Siphon Life" },
            { id = 198590, name = "Drain Soul" },
            { id = 205179, name = "Phantom Singularity" },
            { id = 278350, name = "Vile Taint" },
            { id = 205180, name = "Summon Darkglare" },
        },

        [266] = { -- Demonology
            { id = 686,    name = "Shadow Bolt" },
            { id = 104316, name = "Call Dreadstalkers" },
            { id = 105174, name = "Hand of Gul'dan" },
            { id = 264178, name = "Demonbolt" },
            { id = 111898, name = "Grimoire: Felguard" },
            { id = 264119, name = "Summon Vilefiend" },
            { id = 267211, name = "Bilescourge Bombers" },
            { id = 265187, name = "Summon Demonic Tyrant" },
            { id = 30146,  name = "Summon Felguard" },
        },

        [267] = { -- Destruction
            { id = 348,    name = "Immolate" },
            { id = 29722,  name = "Incinerate" },
            { id = 17962,  name = "Conflagrate" },
            { id = 116858, name = "Chaos Bolt" },
            { id = 5740,   name = "Rain of Fire" },
            { id = 80240,  name = "Havoc" },
            { id = 196447, name = "Channel Demonfire" },
            { id = 152108, name = "Cataclysm" },
            { id = 1122,   name = "Summon Infernal" },
        },

        ["UTILITY"] = {
            -- General utility
            { id = 698,    name = "Ritual of Summoning" },
            { id = 6201,   name = "Create Healthstone" },
            { id = 5697,   name = "Unending Breath" },
            { id = 1098,   name = "Subjugate Demon" },
            { id = 5782,   name = "Fear" },
            { id = 30283,  name = "Shadowfury" },
            { id = 5484,   name = "Howl of Terror" },
            { id = 710,    name = "Banish" },
            { id = 111771, name = "Demonic Gateway" },
            { id = 104773, name = "Unending Resolve" },
            { id = 108416, name = "Dark Pact" },
        }
    },
    WARRIOR = {
        [71] = {}, -- Arms
        [72] = {}, -- Fury
        [73] = {}, -- Protection
        UTILITY = {}
    },
}
