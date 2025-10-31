Config = {}

Config.EnableHorrorSystem = true
Config.DebugMode = false
Config.EnableBlindness = false       -- No va bien
Config.FrameWork = "auto"            -- auto, qb, esx (for perms)
Config.AllowedGroups = {
    qb = { "admin", "god" },         -- QBCore roles
    esx = { "admin", "superadmin" }, -- ESX groups
    ace = { "horrorsystem" }         -- ACE permissions
}

Config.OnlyAtNight = true
Config.NightHours = {
    start = 20, -- 20:00 (8 PM)
    finish = 6  -- 6:00 (6 AM)
}

Config.IntensityProgression = {
    enabled = true,
    timeToMaxIntensity = 300000, -- 5 minutos
    multipliers = {
        low = 0.5,
        medium = 1.0,
        high = 1.5
    }
}

-- Another possibilities: "MP_death_grade_blend01"
Config.HorrorZonesTimeCycleModifier = "MP_Arena_theme_storm"
Config.HorrorZones = {
    {
        name = "Cementerio",
        type = "poly",
        points = {
            vector2(-1715.53, -293.18),
            vector2(-1722.35, -268.94),
            vector2(-1693.18, -243.56),
            vector2(-1685.23, -228.03),
            vector2(-1668.94, -235.61),
            vector2(-1657.58, -202.65),
            vector2(-1651.89, -195.45),
            vector2(-1640.15, -192.05),
            vector2(-1624.24, -187.88),
            vector2(-1613.64, -183.33),
            vector2(-1640.53, -137.50),
            vector2(-1672.73, -133.71),
            vector2(-1701.14, -136.74),
            vector2(-1711.74, -164.39),
            vector2(-1742.80, -173.86),
            vector2(-1747.73, -185.61),
            vector2(-1776.89, -194.32),
            vector2(-1804.17, -215.91),
            vector2(-1812.12, -245.83),
            vector2(-1763.26, -298.86),
            vector2(-1741.67, -316.67)
        },
        minZ = 50.0,
        maxZ = 69.0,
        intensity = "high",
        enableGhosts = true
    },
    {
        name = "Bosque Maldito",
        type = "poly",
        points = {
            vector2(-1725.00, 4694.32),
            vector2(-1540.91, 4900.38),
            vector2(-1411.36, 4956.06),
            vector2(-1337.88, 4839.39),
            vector2(-1306.06, 4784.85),
            vector2(-1245.45, 4704.55),
            vector2(-1193.94, 4646.97),
            vector2(-1183.33, 4568.18),
            vector2(-1215.15, 4462.12),
            vector2(-1266.67, 4380.30),
            vector2(-1356.06, 4365.15),
            vector2(-1498.48, 4362.12),
            vector2(-1645.45, 4471.21),
            vector2(-1730.30, 4580.30)
        },
        minZ = 20.0,
        maxZ = 190.0,
        intensity = "medium",
        enableGhosts = true
    },
    {
        name = "Casa Abandonada",
        type = "box",
        center = vector3(2443.4963, 4975.9824, 46.8105),
        length = 95.0,
        width = 75.0,
        heading = 45.0,
        minZ = 20.0,
        maxZ = 80.0,
        intensity = "high",
        enableGhosts = true
    },
    {
        name = "Túnel Oscuro",
        type = "poly",
        points = {
            vector2(-650.76, -1638.26),
            vector2(-615.91, -1666.29),
            vector2(-577.65, -1668.94),
            vector2(-537.88, -1639.39),
            vector2(-528.41, -1604.17),
            vector2(-564.39, -1581.44),
            vector2(-619.32, -1578.03),
            vector2(-662.12, -1615.91)
        },
        minZ = 5.0,
        maxZ = 45.0,
        intensity = "medium",
        enableGhosts = false
    }
}

Config.Events = {
    jumpscares = {
        enabled = true,
        baseChance = 8,
        cooldown = 180000,
        minTimeInZone = 30000,
        types = {
            { id = "ghost",  weight = 30 },
            { id = "demon",  weight = 20 },
            { id = "zombie", weight = 25 },
            { id = "shadow", weight = 15 },
            { id = "clown",  weight = 10 }
        }
    },

    whispers = {
        enabled = true,
        baseChance = 25,
        cooldown = 60000,
        minTimeInZone = 15000,
        sounds = {
            { id = "whisper1",  weight = 30 },
            { id = "whisper2",  weight = 30 },
            { id = "laugh",     weight = 15 },
            { id = "scream",    weight = 10 },
            { id = "breathing", weight = 15 }
        }
    },

    visualDistortion = {
        enabled = true,
        baseChance = 15,
        cooldown = 45000,
        duration = 5000,
        minTimeInZone = 20000,
        types = {
            { id = "static",    weight = 25 },
            { id = "blur",      weight = 20 },
            { id = "chromatic", weight = 30 },
            { id = "darkness",  weight = 25 }
        }
    },

    ghostAppearance = {
        enabled = true,
        baseChance = 5,
        cooldown = 240000,
        minTimeInZone = 60000,
        duration = 15000,
        distance = 20.0,
        chaseSpeed = 2.5,
        maxChaseDistance = 50.0,
        models = {
            `s_m_m_movalien_01`,
            `u_m_y_zombie_01`,
            `ig_orleans`
        }
    },

    environmental = {
        enabled = true,
        baseChance = 20,
        cooldown = 90000,
        minTimeInZone = 10000,
        effects = {
            { id = "fog",       weight = 15 },
            { id = "thunder",   weight = 20 },
            { id = "footsteps", weight = 25 },
            { id = "laugh",     weight = 15 },
            { id = "heartbeat", weight = 20 },
            { id = "door",      weight = 5 }
        }
    },

    paranormalObjects = {
        enabled = true,
        baseChance = 12,
        cooldown = 120000,
        minTimeInZone = 45000,
        types = {
            "floating_objects",
            "shadow_figures",
            "bloody_messages"
        }
    }
}

Config.Sound3D = {
    enabled = true,
    maxDistance = 50.0,
    volumeFalloff = true,
    occlusionEnabled = true
}

Config.NUI = {
    showNotifications = false,
    showZoneName = true,
    enableScreenEffects = true,
    showIntensityMeter = true,
    enableJumpscareWarning = false
}

Config.CameraEffects = {
    enabled = true,
    shakeOnJumpscare = true,
    shakeIntensity = 0.8,
    slowMotionOnGhost = true,
    fovChanges = true
}

Config.SanitySystem = {
    enabled = false,
    startingSanity = 100,
    drainRate = 0.5,
    effectsAtLowSanity = true,
    recoveryRate = 1.0
}

Config.Texts = {
    enterZone = "Has entrado en una zona perturbadora...",
    leaveZone = "Te sientes más seguro ahora",
    sanityWarning = "Tu mente se está debilitando...",
    ghostWarning = "Sientes una presencia cercana...",
    nightOnly = "⚠️ Los horrores solo aparecen de noche...",
    zoneNames = {
        ["Cementerio"] = "⚰️ Cementerio Maldito",
        ["Bosque Maldito"] = "🌲 Bosque de las Almas Perdidas",
        ["Casa Abandonada"] = "🏚️ Casa Embrujada",
        ["Túnel Oscuro"] = "🕳️ Túnel del Terror"
    }
}

Config.GlobalEvents = true
Config.SyncEvents = true

Config.AdminCommands = {
    enabled = true,
    toggleCommand = "horror",
    testCommand = "testhorror",
    intensityCommand = "horrorintensity"
}

Config.EnableLogging = false
Config.SaveStats = false -- No implementado

Config.Performance = {
    updateInterval = 5000,
    maxActiveGhosts = 2,
    cleanupInterval = 300000,
    disableInVehicle = true
}

Config.WhiteList = {
    enabled = true,
    players = {
        "license:1234567890abcdef",
        "steam:110000104abcd12",
    }
}

Config.RandomPlayerJumpscares = {
    enabled = true,
    minTimeBetween = 120000, -- 2 mins
    maxTimeBetween = 600000, -- 10 mins
    onlyAtNight = false,
    excludeAdmins = false,
    excludeImmune = false,
    excludeInVehicle = false,

    jumpscareTypes = {
        { id = "ghost", weight = 30 },
        { id = "demon", weight = 20 },
        { id = "zombie", weight = 25 },
        { id = "shadow", weight = 15 },
        { id = "clown", weight = 10 }
    },
}

Config.PumpkinHunt = {
    enabled = true,
    
    eventStartDate = "2025-10-20",
    eventEndDate = "2025-11-05",
    checkDateOnCollection = false,
    
    menuCommand = "pumpkins",
    menuKey = "F7",
    
    spawnInterval = 300000, -- 5 minutes
    maxActivePumpkins = 30, -- Total on map
    despawnTime = 600000, -- 10 minutes
    
    interactionDistance = 2.5,
    showDistance = 15.0,
    warningNotificationDistance = 30.0,
    notificationResetDistance = 500.0,

    notifications = {
        collected = "🎃 ¡Has encontrado una calabaza! (%d/%d)",
        alreadyCollected = "Esta calabaza ya fue recogida",
        rewardUnlocked = "🏆 ¡Has desbloqueado una recompensa!",
        eventNotActive = "El evento de Halloween no está activo",
        menuOpened = "Menú de calabazas abierto",
    },
    
    models = {
        "prop_veg_crop_03_pump",
        "m23_1_prop_m31_stack_pk_01a",
        "m23_1_prop_m31_stack_pk_01b",
    },
    
    collectEffects = {
        particle = true,
        particleDict = "core",
        particleName = "ent_dst_elec_fire_sp",
        particleDuration = 2000,
        
        sound = true,
        soundName = "PICK_UP",
        soundSet = "HUD_FRONTEND_DEFAULT_SOUNDSET",
        
        screenEffect = true,
        screenEffectName = "HeistCelebPass",
        screenEffectDuration = 1000,
    },
    
    spawnZones = {
        {
            name = "Centro de Los Santos",
            center = vector3(200.0, -800.0, 31.0),
            radius = 300.0,
            maxPumpkins = 10,
        },
        {
            name = "Grove Street",
            center = vector3(100.0, -1900.0, 21.0),
            radius = 300.0,
            maxPumpkins = 5,
        },
        {
            name = "Playa de Vespucci",
            center = vector3(-1500.0, -1000.0, 5.0),
            radius = 400.0,
            maxPumpkins = 8,
        },
        {
            name = "Vinewood Hills",
            center = vector3(750.0, 1200.0, 300.0),
            radius = 600.0,
            maxPumpkins = 7,
        },
        {
            name = "Sandy Shores",
            center = vector3(1850.0, 3700.0, 34.0),
            radius = 500.0,
            maxPumpkins = 6,
        },
        {
            name = "Paleto Bay",
            center = vector3(-300.0, 6300.0, 32.0),
            radius = 400.0,
            maxPumpkins = 5,
        },
    },
    
    rewards = {
        {
            pumpkinsRequired = 5,
            name = "Cazador Novato",
            description = "Encuentra 5 calabazas",
            icon = "🎃",
            rewards = {
                { type = "money", amount = 5000 },
                { type = "item", name = "water", amount = 5 },
            }
        },
        {
            pumpkinsRequired = 15,
            name = "Cazador Experimentado",
            description = "Encuentra 15 calabazas",
            icon = "🎃🎃",
            rewards = {
                { type = "money", amount = 15000 },
                { type = "item", name = "bread", amount = 10 },
                { type = "item", name = "bandage", amount = 3 },
            }
        },
        {
            pumpkinsRequired = 30,
            name = "Maestro de Halloween",
            description = "Encuentra 30 calabazas",
            icon = "🎃🎃🎃",
            rewards = {
                { type = "money", amount = 30000 },
                { type = "item", name = "lockpick", amount = 5 },
                { type = "weapon", name = "WEAPON_KNIFE", ammo = 0 },
            }
        },
        {
            pumpkinsRequired = 50,
            name = "Leyenda de las Calabazas",
            description = "Encuentra 50 calabazas",
            icon = "👑🎃",
            rewards = {
                { type = "money", amount = 50000 },
                { type = "black_money", amount = 10000 },
                { type = "item", name = "radio", amount = 1 },
            }
        },
        {
            pumpkinsRequired = 100,
            name = "Rey de Halloween",
            description = "Encuentra 100 calabazas - ¡Completado!",
            icon = "🏆👑🎃",
            rewards = {
                { type = "money", amount = 100000 },
                { type = "black_money", amount = 50000 },
                { type = "item", name = "halloween_mask", amount = 1 },
                { type = "weapon", name = "WEAPON_MACHETE", ammo = 0 },
            }
        },
    },
    
    marker = {
        type = 2,
        scale = vector3(0.5, 0.5, 0.5),
        color = { r = 255, g = 140, b = 0, a = 200 },
        bobUpAndDown = true,
        faceCamera = true,
        rotate = true,
        drawOnEnts = false,
    },
    
    text3D = {
        enabled = true,
        distance = 5.0,
        text = "~g~[E]~w~ Recoger calabaza",
        scale = 0.35,
    },
    
    leaderboard = {
        enabled = true,
        showInMenu = true,
        topPlayersCount = 10,
        updateInterval = 60000,
    },
    
    statistics = {
        trackCollectionTime = true,
        trackCollectionLocation = true,
        showPersonalStats = true,
    },
    
    framework = {
        esx = {
            moneyAccount = "money",
            blackMoneyAccount = "black_money", 
        },
        qb = {
            moneyType = "cash",
            blackMoneyType = "black_money",
        },
    },
    
    database = {
        tableName = "pumpkin_hunt_data",
        autoCreateTable = true,
        saveInterval = 30000,
    },
    
    animations = {
        collect = {
            dict = "pickup_object",
            anim = "pickup_low",
            duration = 1000,
            flag = 1,
        },
    },
}