NexaAnticheatServer = {
    tokenTtlSeconds = 120,
    auditBufferLimit = 250,
    maxPayloadKeys = 32,
    maxStringLength = 512,
    maxPayloadBytes = 4096,
    maxPayloadDepth = 4,
    rateLimits = {
        default = {
            count = 6,
            windowSeconds = 10
        },
        ['anticheat.validateEvent'] = {
            count = 12,
            windowSeconds = 10
        },
        ['anticheat.issueToken'] = {
            count = 8,
            windowSeconds = 10
        },
        ['anticheat.verifyToken'] = {
            count = 12,
            windowSeconds = 10
        },
        ['anticheat.noclip.validateMovement'] = {
            count = 20,
            windowSeconds = 10
        },
        ['anticheat.godmode.validateState'] = {
            count = 20,
            windowSeconds = 10
        },
        ['anticheat.godmode.recordDamage'] = {
            count = 20,
            windowSeconds = 10
        },
        ['anticheat.executor.validateSignal'] = {
            count = 18,
            windowSeconds = 10
        },
        ['anticheat.evidence.request'] = {
            count = 3,
            windowSeconds = 60
        },
        ['anticheat.evidence.prepare'] = {
            count = 10,
            windowSeconds = 60
        },
        ['anticheat.ban.manual'] = {
            count = 4,
            windowSeconds = 60
        },
        ['anticheat.ban.check'] = {
            count = 30,
            windowSeconds = 60
        },
        ['anticheat.ban.history'] = {
            count = 10,
            windowSeconds = 60
        }
    },
    replayProtection = {
        windowSeconds = 120,
        maxEntries = 1000
    },
    eventAllowlist = {
        ['nexa:anticheat:server:validateEvent'] = true
    },
    eventDenylist = {
        giveMoney = true,
        addItem = true,
        setJob = true,
        setGrade = true,
        rewardPlayer = true,
        adminAction = true,
        debugEvent = true
    },
    allowedPayloadTypes = {
        string = true,
        number = true,
        boolean = true,
        table = true,
        ['nil'] = true
    },
    secureInternalEvents = {
        ['nexa:anticheat:internal:violation'] = true,
        ['nexa:anticheat:internal:validated'] = true
    },
    secureEvents = {
        ['nexa:anticheat:server:validateEvent'] = {
            critical = true,
            requireToken = true,
            consumeToken = true,
            requireReplayProtection = true,
            allowedResources = {
                nexa_anticheat = true,
                nexa_api = true
            },
            payload = {
                eventName = { type = 'string', required = true, maxLength = 128 },
                requestId = { type = 'string', required = true, maxLength = 64 }
            }
        }
    },
    expectedResources = {
        nexa_config = 'started',
        oxmysql = 'started',
        nexa_featureflags = 'started',
        nexa_security = 'started',
        nexa_audit = 'started',
        nexa_logs = 'started',
        nexa_anticheat = 'started'
    },
    moneyProtection = {
        maxAccountBalance = 9223372036854775807,
        maxTransactionAmount = 100000000,
        duplicateWindowSeconds = 300,
        payoutCooldownSeconds = 60,
        reportLimit = 50,
        payoutCategories = {
            payout = true,
            salary = true,
            reward = true,
            moneywash = true,
            criminal_payout = true
        },
        authorizedLedgerResources = {
            nexa_api = true,
            nexa_jobs_core = true,
            nexa_business = true,
            nexa_vehicledealer = true,
            nexa_fuel = true,
            nexa_impound = true,
            nexa_housing = true,
            nexa_moneywash = true,
            nexa_blackmarket = true,
            nexa_chopshop = true
        }
    },
    inventoryProtection = {
        maxItemAmount = 1000,
        duplicateWindowSeconds = 300,
        movementWindowSeconds = 60,
        maxMovementsPerWindow = 50,
        reportLimit = 50,
        highRiskItems = {
            weapon_pistol = true,
            weapon_smg = true,
            weapon_rifle = true,
            dirty_money = true,
            marked_bills = true,
            lockpick = true,
            radio_scrambler = true,
            blank_card = true
        },
        movementActions = {
            add = true,
            remove = true,
            move = true,
            transfer = true,
            inventory_add = true,
            inventory_remove = true,
            ['inventory.addItem'] = true,
            ['inventory.removeItem'] = true
        },
        stashMetadataKeys = {
            stashName = true,
            sourceInventory = true,
            targetInventory = true,
            inventory = true
        },
        authorizedItemResources = {
            nexa_api = true,
            nexa_lspd = true,
            nexa_ems = true,
            nexa_government = true,
            nexa_weazel = true,
            nexa_housing = true,
            nexa_furniture = true,
            nexa_illegal_core = true,
            nexa_blackmarket = true,
            nexa_drugs = true,
            nexa_moneywash = true,
            nexa_chopshop = true,
            nexa_evidence = true
        }
    },
    vehicleProtection = {
        maxFuelLevel = 100,
        minFuelLevel = 0,
        maxFuelDelta = 100,
        maxActiveKeysPerVehicle = 12,
        reportLimit = 50,
        historyWindowSeconds = 300,
        lockWindowSeconds = 60,
        maxLockEventsPerWindow = 20,
        expectedVehicleStatuses = {
            active = true,
            stored = true,
            impounded = true,
            seized = true,
            deleted = true
        },
        expectedGarageStates = {
            stored = true,
            out = true,
            impounded = true,
            seized = true
        },
        authorizedHistoryEvents = {
            ['garage.store'] = true,
            ['garage.retrieve'] = true,
            ['vehicle.garage.reconcileRestart'] = true,
            ['vehicle.key.grant'] = true,
            ['vehicle.key.revoke'] = true,
            ['vehicle.key.cleanupExpired'] = true,
            ['vehicle.lock'] = true,
            ['vehicle.unlock'] = true,
            ['vehicle.dealer.purchase'] = true,
            ['vehicle.fuel.purchase'] = true,
            ['vehicle.fuel.consume'] = true,
            ['vehicle.impound'] = true,
            ['vehicle.impound.release'] = true
        },
        authorizedSpawnEvents = {
            ['vehicle.dealer.purchase'] = true,
            ['garage.retrieve'] = true,
            ['vehicle.impound.release'] = true
        },
        keyAbuseTypes = {
            owner = true,
            shared = true,
            temporary = true,
            job = true,
            faction = true
        }
    },
    teleportDetection = {
        maxDistanceDelta = 120.0,
        maxSpeedMetersPerSecond = 85.0,
        minDeltaSeconds = 0.25,
        snapshotTtlSeconds = 60,
        whitelistTtlSeconds = 12,
        reportLimit = 50,
        whitelistedContexts = {
            spawn = true,
            garage = true,
            interior = true,
            housing = true,
            admin_teleport = true,
            admin_utility = true
        },
        adminPermissions = {
            ['admin.utility.goto'] = true,
            ['admin.utility.bring'] = true,
            ['admin.utility.return'] = true,
            ['admin.utility.coords'] = true,
            ['admin.teleport'] = true
        }
    },
    noclipDetection = {
        maxHorizontalMetersPerSecond = 38.0,
        maxVerticalMetersPerSecond = 24.0,
        maxHeightAboveGround = 8.0,
        minAirborneDistance = 8.0,
        minFallDelta = 3.0,
        maxFallHorizontalMetersPerSecond = 45.0,
        maxParachuteHorizontalMetersPerSecond = 32.0,
        minDeltaSeconds = 0.25,
        snapshotTtlSeconds = 45,
        exceptionTtlSeconds = 12,
        suspiciousConsecutiveLimit = 2,
        reportLimit = 50,
        transitionContexts = {
            interior = true,
            housing = true,
            garage = true,
            spawn = true,
            admin_noclip = true
        },
        adminPermissions = {
            ['admin.utility.noclip'] = true,
            ['admin.noclip'] = true,
            ['devtools.noclip'] = true
        }
    },
    godmodeDetection = {
        maxHealth = 200,
        maxArmor = 100,
        minDamageAmount = 1,
        damageGraceSeconds = 4,
        exceptionTtlSeconds = 12,
        spawnProtectionSeconds = 20,
        suspiciousConsecutiveLimit = 2,
        reportLimit = 50,
        exceptionContexts = {
            heal = true,
            revive = true,
            admin_heal = true,
            admin_revive = true,
            ems_treatment = true,
            spawn_protection = true
        },
        adminPermissions = {
            ['admin.utility.heal.prepare'] = true,
            ['admin.utility.revive.prepare'] = true,
            ['admin.heal'] = true,
            ['admin.revive'] = true
        },
        emsPermissions = {
            ['ems.treatments.create'] = true
        }
    },
    executorDetection = {
        suspicionThreshold = 35,
        reportLimit = 50,
        maxPayloadKeys = 24,
        maxPayloadDepth = 5,
        maxStringLength = 768,
        clientSignalWeight = 5,
        eventPatternWeight = 20,
        resourcePatternWeight = 20,
        payloadPatternWeight = 15,
        exploitSignatureWeight = 35,
        eventPatterns = {
            'giveMoney',
            'addItem',
            'setJob',
            'rewardPlayer',
            'TriggerServerEvent',
            'RegisterNetEvent',
            '__cfx_internal',
            'esx:',
            'qb%-admin',
            'adminmenu'
        },
        resourcePatterns = {
            'executor',
            'inject',
            'redengine',
            'eulen',
            'lynx',
            'menu',
            'cheat'
        },
        payloadPatterns = {
            'load%(',
            'loadstring',
            'PerformHttpRequest',
            'RunString',
            'Citizen%.InvokeNative',
            'SetEntityCoords',
            'GiveWeaponToPed',
            'AddMoney',
            'AddItem'
        },
        exploitSignatures = {
            'redengine',
            'eulen',
            'lynxmenu',
            'hammafia',
            'dopamine',
            'fallout',
            'desudo',
            'brutan',
            'absolute',
            'tzx'
        },
        trustedSignalResources = {
            nexa_anticheat = true,
            nexa_api = true,
            nexa_security = true,
            nexa_logs = true,
            nexa_admin = true
        }
    },
    evidenceCapture = {
        reportLimit = 50,
        requestTtlSeconds = 300,
        maxReasonLength = 240,
        maxMetadataKeys = 16,
        maxMetadataStringLength = 160,
        externalUploadEnabled = false,
        externalUploadProvider = nil,
        dispatchClientCapture = false,
        transparencyNotice = 'Screenshot/Evidence Capture darf nur manuell mit Permission, auditierbar und zweckgebunden angefordert werden.',
        retentionHint = 'Evidence-Metadaten werden nur als Audit-/Logging-Kontext vorbereitet; Speicherung und Upload muessen vor Aktivierung separat konfiguriert werden.',
        manualPermissions = {
            ['admin.evidence.capture'] = true,
            ['admin.screenshot.request'] = true,
            ['anticheat.evidence.request'] = true
        },
        anticheatTrustedResources = {
            nexa_anticheat = true,
            nexa_api = true,
            nexa_security = true
        },
        allowedReasons = {
            manual_admin_review = true,
            report_review = true,
            anticheat_followup = true,
            moderation_case = true
        }
    },
    banSystem = {
        historyLimit = 50,
        maxReasonLength = 255,
        minTempBanMinutes = 1,
        maxTempBanDays = 365,
        joinMessage = 'Du bist von Nexa Roleplay ausgeschlossen. Grund: %s',
        permanentLabel = 'permanent',
        allowedIdentifierTypes = {
            license = true,
            license2 = true,
            steam = true,
            discord = true,
            fivem = true,
            xbl = true,
            live = true
        },
        manualPermissions = {
            ['admin.ban'] = true,
            ['admin.ban.permanent'] = true,
            ['admin.ban.temporary'] = true,
            ['anticheat.ban.manual'] = true
        },
        historyPermissions = {
            ['admin.ban.history'] = true,
            ['admin.ban'] = true,
            ['security.review'] = true
        },
        reviewStatuses = {
            not_requested = true,
            requested = true,
            under_review = true,
            upheld = true,
            lifted = true
        },
        defaultReviewStatus = 'not_requested'
    }
}
