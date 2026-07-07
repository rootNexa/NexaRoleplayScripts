NexaSecurityServer = {
    defaultLimit = {
        count = 10,
        windowSeconds = 10
    },
    maxBuckets = 1000,
    limits = {
        ['core.audit'] = {
            count = 30,
            windowSeconds = 10
        },
        ['core.permission'] = {
            count = 60,
            windowSeconds = 10
        },
        ['nexa:banking:cb:getAccounts'] = {
            count = 10,
            windowSeconds = 10
        },
        ['nexa:banking:cb:getTransactions'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:banking:cb:requestTransfer'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:banking:server:requestTransfer'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:banking:cb:payInvoice'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:banking:server:requestPayInvoice'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:jobs_core:cb:listJobs'] = {
            count = 10,
            windowSeconds = 10
        },
        ['nexa:jobs_core:cb:getCurrentJob'] = {
            count = 10,
            windowSeconds = 10
        },
        ['nexa:jobs_core:cb:assignJob'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:jobs_core:cb:startDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:jobs_core:cb:endDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:jobs_core:cb:requestSalary'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:jobs_core:server:requestToggleDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:jobs_core:server:requestSalary'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:business:cb:listBusinesses'] = {
            count = 10,
            windowSeconds = 10
        },
        ['nexa:business:cb:createBusiness'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:business:cb:addMember'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:business:cb:removeMember'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:business:cb:listAccounts'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:business:cb:requestTransfer'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:business:cb:listTransactions'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:business:server:requestCreate'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:business:server:requestAddMember'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:business:server:requestRemoveMember'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:business:server:requestTransfer'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:dispatch:cb:createCall'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:dispatch:cb:listCalls'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:dispatch:cb:assignCall'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:dispatch:cb:updateStatus'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:dispatch:cb:setPriority'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:dispatch:server:requestCreateCall'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:dispatch:server:requestAssign'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:dispatch:server:requestStatus'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:dispatch:server:requestPriority'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:hud:cb:getSnapshot'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:tablet:cb:getApps'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:phone:cb:getSnapshot'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:phone:cb:saveNote'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:phone:cb:sendMessage'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:mdt:cb:getSnapshot'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:mdt:cb:searchPerson'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:garage:cb:listVehicles'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:garage:cb:storeVehicle'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:garage:cb:retrieveVehicle'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:vehiclekeys:cb:hasKey'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:vehiclekeys:cb:grantKey'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:vehiclekeys:cb:grantTemporaryKey'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:vehiclekeys:cb:revokeKey'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:vehiclekeys:cb:toggleLock'] = {
            count = 5,
            windowSeconds = 10
        },
        ['nexa:vehicledealer:cb:getCatalog'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:vehicledealer:cb:purchaseVehicle'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:vehicledealer:cb:prepareSale'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:fuel:cb:getStations'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:fuel:cb:getFuel'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:fuel:cb:purchaseFuel'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:fuel:cb:reportConsumption'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:impound:cb:getStatus'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:impound:cb:impoundVehicle'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:impound:cb:releaseVehicle'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:housing:cb:getProperties'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:housing:cb:getAccessibleProperties'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:housing:cb:getStatus'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:housing:cb:hasAccess'] = {
            count = 10,
            windowSeconds = 10
        },
        ['nexa:housing:cb:purchaseProperty'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:housing:cb:rentProperty'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:housing:cb:grantAccess'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:housing:cb:listAccess'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:housing:cb:revokeAccess'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:housing:cb:ensureStorage'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:housing:cb:openStorage'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:factions_core:cb:getOverview'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:factions_core:cb:listMembers'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:factions_core:cb:listAccounts'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:factions_core:cb:setCallsign'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:factions_core:cb:assignMember'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:factions_core:cb:transferFunds'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:factions_core:server:requestToggleDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:factions_core:server:requestSetCallsign'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:factions_core:server:requestAssignMember'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:factions_core:server:requestTransferFunds'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:lspd:cb:getStatus'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:lspd:cb:listMembers'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:lspd:cb:listDispatch'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:lspd:cb:getRecordsStatus'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:lspd:server:requestToggleDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:lspd:server:requestSetCallsign'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:ems:cb:getStatus'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:ems:cb:listMembers'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:ems:cb:listRecords'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:ems:cb:createRecord'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:ems:cb:addTreatment'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:ems:cb:createInvoice'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:ems:server:requestToggleDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:ems:server:requestSetCallsign'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:ems:server:requestCreateRecord'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:ems:server:requestAddTreatment'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:ems:server:requestCreateInvoice'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:cb:getStatus'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:government:cb:listMembers'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:government:cb:listDocumentTypes'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:government:cb:listLicenseTypes'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:government:cb:issueDocument'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:cb:revokeDocument'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:cb:issueLicense'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:cb:revokeLicense'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:cb:createInvoice'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:server:requestToggleDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:government:server:requestSetCallsign'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:government:server:requestIssueDocument'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:server:requestRevokeDocument'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:server:requestIssueLicense'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:server:requestRevokeLicense'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:government:server:requestCreateInvoice'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:weazel:cb:getStatus'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:weazel:cb:listMembers'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:weazel:cb:issuePressPass'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:weazel:cb:createAnnouncement'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:weazel:server:requestToggleDuty'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:weazel:server:requestSetCallsign'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:weazel:server:requestIssuePressPass'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:weazel:server:requestCreateAnnouncement'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:illegal_core:cb:getSnapshot'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:illegal_core:cb:adjustReputation'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:illegal_core:cb:checkCooldown'] = {
            count = 8,
            windowSeconds = 10
        },
        ['nexa:illegal_core:server:requestSnapshot'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:illegal_core:server:requestContact'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:blackmarket:cb:getCatalog'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:blackmarket:cb:buy'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:blackmarket:cb:sell'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:blackmarket:server:requestBuy'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:blackmarket:server:requestSell'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:drugs:cb:plant'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:drugs:cb:harvest'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:drugs:cb:process'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:drugs:cb:sell'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:drugs:server:requestPlant'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:drugs:server:requestHarvest'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:drugs:server:requestProcess'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:drugs:server:requestSell'] = {
            count = 2,
            windowSeconds = 30
        },
        ['nexa:moneywash:cb:wash'] = {
            count = 2,
            windowSeconds = 60
        },
        ['nexa:moneywash:server:requestWash'] = {
            count = 2,
            windowSeconds = 60
        },
        ['nexa:chopshop:cb:dismantle'] = {
            count = 1,
            windowSeconds = 60
        },
        ['nexa:chopshop:cb:sell'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:chopshop:server:requestDismantle'] = {
            count = 1,
            windowSeconds = 60
        },
        ['nexa:chopshop:server:requestSell'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:evidence:cb:collect'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:evidence:cb:list'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:evidence:cb:updateStatus'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:evidence:server:requestCollect'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:evidence:server:requestStatus'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:worldstates:cb:get'] = {
            count = 10,
            windowSeconds = 10
        },
        ['nexa:worldstates:cb:list'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:worldstates:cb:set'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:worldstates:cb:clear'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:worldstates:cb:resources'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:worldstates:server:requestSet'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:worldstates:server:requestClear'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:blips:cb:getAvailable'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:zones:cb:getAvailable'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:zones:cb:validateCriticalAction'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:zones:server:entered'] = {
            count = 12,
            windowSeconds = 10
        },
        ['nexa:zones:server:left'] = {
            count = 12,
            windowSeconds = 10
        },
        ['nexa:interiors:cb:getAvailable'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:interiors:cb:validateAccess'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:maps:cb:list'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:maps:cb:get'] = {
            count = 10,
            windowSeconds = 10
        },
        ['nexa:npcs:cb:getAvailable'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:npcs:cb:validateInteraction'] = {
            count = 6,
            windowSeconds = 20
        },
        ['nexa:admin:cb:getMenu'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:admin:cb:listPlayers'] = {
            count = 3,
            windowSeconds = 10
        },
        ['nexa:admin:cb:validateAction'] = {
            count = 3,
            windowSeconds = 20
        },
        ['nexa:admin:cb:createReport'] = {
            count = 2,
            windowSeconds = 60
        },
        ['nexa:admin:cb:listOwnReports'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:admin:cb:listReports'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:admin:cb:getReportHistory'] = {
            count = 6,
            windowSeconds = 10
        },
        ['nexa:admin:cb:acceptReport'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:admin:cb:closeReport'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:admin:cb:createTicket'] = {
            count = 2,
            windowSeconds = 60
        },
        ['nexa:admin:cb:listTickets'] = {
            count = 4,
            windowSeconds = 10
        },
        ['nexa:admin:cb:assignTicket'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:admin:cb:closeTicket'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:admin:cb:listModerationActions'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:admin:cb:warnPlayer'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:admin:cb:kickPlayer'] = {
            count = 3,
            windowSeconds = 60
        },
        ['nexa:admin:cb:prepareTempban'] = {
            count = 3,
            windowSeconds = 60
        },
        ['nexa:admin:cb:setPlayerFrozen'] = {
            count = 6,
            windowSeconds = 30
        },
        ['nexa:admin:cb:prepareSpectate'] = {
            count = 6,
            windowSeconds = 30
        },
        ['nexa:admin:cb:addAdminNote'] = {
            count = 4,
            windowSeconds = 60
        },
        ['nexa:admin:cb:listAdminNotes'] = {
            count = 6,
            windowSeconds = 30
        },
        ['nexa:admin:cb:listUtilityActions'] = {
            count = 4,
            windowSeconds = 20
        },
        ['nexa:admin:cb:bringPlayer'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:admin:cb:gotoPlayer'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:admin:cb:returnPlayer'] = {
            count = 4,
            windowSeconds = 30
        },
        ['nexa:admin:cb:teleportToCoords'] = {
            count = 3,
            windowSeconds = 30
        },
        ['nexa:admin:cb:prepareAdminHeal'] = {
            count = 3,
            windowSeconds = 60
        },
        ['nexa:admin:cb:prepareAdminRevive'] = {
            count = 3,
            windowSeconds = 60
        }
    }
}
