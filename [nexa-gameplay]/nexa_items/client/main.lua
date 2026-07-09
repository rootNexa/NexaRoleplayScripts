local CONTEXT = {
    sidebar = 'nexa_items:studio:sidebar',
    dashboard = 'nexa_items:studio:dashboard',
    items = 'nexa_items:studio:items',
    toolbar = 'nexa_items:studio:toolbar',
    categories = 'nexa_items:studio:categories',
    editor = 'nexa_items:studio:editor',
    tabGeneral = 'nexa_items:studio:editor:general',
    tabType = 'nexa_items:studio:editor:type',
    tabMetadata = 'nexa_items:studio:editor:metadata',
    tabUseConfig = 'nexa_items:studio:editor:use_config',
    preview = 'nexa_items:studio:preview',
    rights = 'nexa_items:studio:rights',
    import = 'nexa_items:studio:import',
    export = 'nexa_items:studio:export',
    settings = 'nexa_items:studio:settings',
    delete = 'nexa_items:studio:delete'
}

local sampleItems = {
    {
        name = 'sandwich',
        label = 'Sandwich',
        item_type = 'food',
        category = 'Food',
        enabled = true,
        usable = true,
        weight = 250,
        stackable = true,
        max_stack = 10,
        rarity = 'common',
        description = 'Ein einfaches Beispiel-Item fuer Essen.',
        image_url = 'nui://nexa_items/web/images/sandwich.png',
        metadata = 'hunger=18, category=snack',
        use_config = 'animation=eat, progress=4500'
    },
    {
        name = 'water_bottle',
        label = 'Wasserflasche',
        item_type = 'drink',
        category = 'Drink',
        enabled = true,
        usable = true,
        weight = 500,
        stackable = true,
        max_stack = 12,
        rarity = 'common',
        description = 'Eine kleine Vorschau fuer ein Trink-Item.',
        image_url = 'nui://nexa_items/web/images/water_bottle.png',
        metadata = 'thirst=22, container=plastic',
        use_config = 'animation=drink, progress=3500'
    },
    {
        name = 'weapon_pistol',
        label = 'Pistole',
        item_type = 'weapon',
        category = 'Weapon',
        enabled = false,
        usable = false,
        weight = 1200,
        stackable = false,
        max_stack = 1,
        rarity = 'rare',
        description = 'Waffenlogik ist noch nicht Teil dieser UI-Phase.',
        image_url = 'nui://nexa_items/web/images/weapon_pistol.png',
        metadata = 'caliber=9mm, serial=true',
        use_config = 'handler=weapon'
    },
    {
        name = 'light_armor',
        label = 'Leichte Schutzweste',
        item_type = 'armor',
        category = 'Armor',
        enabled = true,
        usable = true,
        weight = 2200,
        stackable = false,
        max_stack = 1,
        rarity = 'uncommon',
        description = 'Preview fuer spaetere Armor-Konfiguration.',
        image_url = 'nui://nexa_items/web/images/light_armor.png',
        metadata = 'armor=35, durability=100',
        use_config = 'progress=6000, armor=35'
    },
    {
        name = 'event_token',
        label = 'Event Token',
        item_type = 'custom',
        category = 'Custom',
        enabled = true,
        usable = false,
        weight = 0,
        stackable = true,
        max_stack = 99,
        rarity = 'special',
        description = 'Custom Item fuer servereigene Events.',
        image_url = 'nui://nexa_items/web/images/event_token.png',
        metadata = 'event=summer, trade=false',
        use_config = 'none'
    }
}

local categories = {
    'All',
    'Food',
    'Drink',
    'Weapon',
    'Armor',
    'Medical',
    'Tool',
    'Document',
    'License',
    'Key',
    'Drug',
    'Material',
    'Container',
    'Custom'
}

local permissions = {
    'items.view',
    'items.create',
    'items.update',
    'items.delete',
    'items.enable',
    'items.disable',
    'items.import',
    'items.export'
}

local selectedItemIndex = 1
local activeCategory = 'All'
local searchText = ''
local contextsRegistered = false
local registerItemStudioContexts

local function boolLabel(value)
    return value and 'Ja' or 'Nein'
end

local function getSelectedItem()
    return sampleItems[selectedItemIndex] or sampleItems[1]
end

local function uiNotify(title, message, notificationType)
    exports.nexa_ui:notify({
        title = title or 'Item Studio',
        message = message or '',
        type = notificationType or 'info'
    })
end

local function registerContext(context)
    if type(context) == 'table' and type(context.options) == 'table' then
        for _, option in ipairs(context.options) do
            if type(option) == 'table' and type(option.onSelect) == 'function' and option.keepOpen == nil then
                option.keepOpen = true
            end
        end
    end

    exports.nexa_ui:registerContext(context)
end

local function showContext(contextId)
    registerItemStudioContexts()
    exports.nexa_ui:showContext(contextId)
end

local function uiOnlyNotice(action)
    uiNotify('Item Studio', action .. ' ist in dieser Phase nur UI und speichert noch nichts.', 'info')
end

local function itemMatchesFilter(item)
    if activeCategory ~= 'All' and item.category ~= activeCategory then
        return false
    end

    if searchText == '' then
        return true
    end

    local needle = searchText:lower()

    return item.name:lower():find(needle, 1, true) ~= nil
        or item.label:lower():find(needle, 1, true) ~= nil
        or item.item_type:lower():find(needle, 1, true) ~= nil
        or item.category:lower():find(needle, 1, true) ~= nil
end

local function openInputSearch()
    local result = exports.nexa_ui:inputDialog('Item Suche', {
        {
            type = 'input',
            label = 'Suchtext',
            placeholder = 'Name, Label, Typ oder Kategorie',
            default = searchText
        }
    }, {})

    if result == nil then
        return
    end

    searchText = tostring(result[1] or '')
    uiNotify('Item Studio', searchText == '' and 'Suche zurueckgesetzt.' or ('Suche: ' .. searchText), 'success')
    showContext(CONTEXT.items)
end

local function openNewItemDraft()
    local result = exports.nexa_ui:inputDialog('Neues Item', {
        {
            type = 'input',
            label = 'Name',
            placeholder = 'item_slug'
        },
        {
            type = 'input',
            label = 'Label',
            placeholder = 'Anzeigename'
        },
        {
            type = 'select',
            label = 'Typ',
            options = {
                { label = 'food', value = 'food' },
                { label = 'drink', value = 'drink' },
                { label = 'weapon', value = 'weapon' },
                { label = 'armor', value = 'armor' },
                { label = 'medical', value = 'medical' },
                { label = 'custom', value = 'custom' }
            }
        },
        {
            type = 'input',
            label = 'Kategorie',
            placeholder = 'Custom'
        }
    }, {})

    if result ~= nil then
        uiOnlyNotice('Neues Item')
    end
end

local function openGeneralDraft()
    local item = getSelectedItem()

    local result = exports.nexa_ui:inputDialog('Allgemein bearbeiten', {
        {
            type = 'input',
            label = 'Label',
            default = item.label
        },
        {
            type = 'textarea',
            label = 'Beschreibung',
            default = item.description
        },
        {
            type = 'number',
            label = 'Gewicht',
            default = item.weight
        }
    }, {})

    if result ~= nil then
        uiOnlyNotice('Allgemein bearbeiten')
    end
end

local function openImportDraft()
    local result = exports.nexa_ui:inputDialog('Import vorbereiten', {
        {
            type = 'textarea',
            label = 'Import JSON',
            placeholder = 'Hier spaeter Item JSON einfuegen'
        }
    }, {})

    if result ~= nil then
        uiOnlyNotice('Import')
    end
end

local function openExportDraft()
    local item = getSelectedItem()
    uiNotify('Item Studio', 'Export Preview fuer ' .. item.name .. ' vorbereitet. Noch kein Datei-Export.', 'info')
end

local function selectItem(index)
    selectedItemIndex = index
    local item = getSelectedItem()

    uiNotify('Item Studio', item.label .. ' ausgewaehlt.', 'success')
    showContext(CONTEXT.editor)
end

local function buildItemOptions()
    local options = {
        {
            title = 'Suche',
            description = searchText == '' and 'Itemliste durchsuchen' or ('Aktiv: ' .. searchText),
            onSelect = openInputSearch
        },
        {
            title = 'Kategoriebaum',
            description = 'Aktive Kategorie: ' .. activeCategory,
            onSelect = function()
                showContext(CONTEXT.categories)
            end
        },
        {
            title = 'Toolbar',
            description = 'Neu, Bearbeiten, Duplizieren, Aktivieren, Loeschen, Import, Export',
            onSelect = function()
                showContext(CONTEXT.toolbar)
            end
        }
    }

    local foundItems = 0

    for index, item in ipairs(sampleItems) do
        if itemMatchesFilter(item) then
            foundItems = foundItems + 1
            options[#options + 1] = {
                title = item.label,
                description = ('%s | %s | %s | Aktiv: %s | Benutzbar: %s | Gewicht: %sg'):format(
                    item.name,
                    item.item_type,
                    item.category,
                    boolLabel(item.enabled),
                    boolLabel(item.usable),
                    tostring(item.weight)
                ),
                onSelect = function()
                    selectItem(index)
                end
            }
        end
    end

    if foundItems == 0 then
        options[#options + 1] = {
            title = 'Keine Treffer',
            description = 'Suche oder Kategorie anpassen.',
            disabled = true
        }
    end

    options[#options + 1] = {
        title = 'Zurueck',
        description = 'Zur Sidebar',
        onSelect = function()
            showContext(CONTEXT.sidebar)
        end
    }

    return options
end

local function buildCategoryOptions()
    local options = {}

    for _, category in ipairs(categories) do
        options[#options + 1] = {
            title = category,
            description = category == activeCategory and 'Aktiver Filter' or 'Kategorie anzeigen',
            disabled = category == activeCategory,
            onSelect = function()
                activeCategory = category
                uiNotify('Item Studio', 'Kategorie: ' .. activeCategory, 'success')
                showContext(CONTEXT.items)
            end
        }
    end

    options[#options + 1] = {
        title = 'Zurueck',
        description = 'Zur Itemliste',
        onSelect = function()
            showContext(CONTEXT.items)
        end
    }

    return options
end

local function buildPreviewOptions()
    local item = getSelectedItem()

    return {
        {
            title = 'Bild',
            description = item.image_url,
            disabled = true
        },
        {
            title = 'Name',
            description = item.name,
            disabled = true
        },
        {
            title = 'Beschreibung',
            description = item.description,
            disabled = true
        },
        {
            title = 'Stack',
            description = boolLabel(item.stackable) .. ' | Max: ' .. tostring(item.max_stack),
            disabled = true
        },
        {
            title = 'Gewicht',
            description = tostring(item.weight) .. 'g',
            disabled = true
        },
        {
            title = 'Seltenheit',
            description = item.rarity,
            disabled = true
        },
        {
            title = 'Zurueck',
            description = 'Zum Editor',
            onSelect = function()
                showContext(CONTEXT.editor)
            end
        }
    }
end

local function buildPermissionOptions()
    local options = {}

    for _, permission in ipairs(permissions) do
        options[#options + 1] = {
            title = permission,
            description = 'Vorbereitet fuer spaetere Admin-Rechte.',
            disabled = true
        }
    end

    options[#options + 1] = {
        title = 'Zurueck',
        description = 'Zum Editor',
        onSelect = function()
            showContext(CONTEXT.editor)
        end
    }

    return options
end

function registerItemStudioContexts()
    contextsRegistered = true

    registerContext({
        id = CONTEXT.sidebar,
        title = 'Nexa Item Studio',
        options = {
            {
                title = 'Dashboard',
                description = 'Uebersicht, Status und Schnellzugriffe',
                onSelect = function()
                    showContext(CONTEXT.dashboard)
                end
            },
            {
                title = 'Items',
                description = 'Liste, Neues Item, Bearbeiten und Loeschen',
                onSelect = function()
                    showContext(CONTEXT.items)
                end
            },
            {
                title = 'Kategorien',
                description = 'Kategoriebaum und Filter',
                onSelect = function()
                    showContext(CONTEXT.categories)
                end
            },
            {
                title = 'Import',
                description = 'Import-Workflow vorbereiten',
                onSelect = function()
                    showContext(CONTEXT.import)
                end
            },
            {
                title = 'Export',
                description = 'Export-Workflow vorbereiten',
                onSelect = function()
                    showContext(CONTEXT.export)
                end
            },
            {
                title = 'Settings',
                description = 'Studio-Einstellungen vorbereiten',
                onSelect = function()
                    showContext(CONTEXT.settings)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.dashboard,
        title = 'Item Studio Dashboard',
        options = {
            {
                title = 'Items',
                description = tostring(#sampleItems) .. ' UI-Beispiele geladen',
                onSelect = function()
                    showContext(CONTEXT.items)
                end
            },
            {
                title = 'Preview',
                description = 'Aktuelles Item anzeigen',
                onSelect = function()
                    showContext(CONTEXT.preview)
                end
            },
            {
                title = 'Rechte Editor',
                description = 'Permission-Struktur ansehen',
                onSelect = function()
                    showContext(CONTEXT.rights)
                end
            },
            {
                title = 'Zurueck',
                description = 'Zur Sidebar',
                onSelect = function()
                    showContext(CONTEXT.sidebar)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.items,
        title = 'Items',
        options = buildItemOptions()
    })

    registerContext({
        id = CONTEXT.toolbar,
        title = 'Toolbar',
        options = {
            {
                title = 'Neu',
                description = 'Item-Entwurf oeffnen',
                onSelect = openNewItemDraft
            },
            {
                title = 'Bearbeiten',
                description = 'Ausgewaehltes Item im Editor oeffnen',
                onSelect = function()
                    showContext(CONTEXT.editor)
                end
            },
            {
                title = 'Duplizieren',
                description = 'UI-only Entwurf aus aktuellem Item',
                onSelect = function()
                    uiOnlyNotice('Duplizieren')
                end
            },
            {
                title = 'Aktivieren',
                description = 'Spaeter Item aktivieren',
                onSelect = function()
                    uiOnlyNotice('Aktivieren')
                end
            },
            {
                title = 'Deaktivieren',
                description = 'Spaeter Item deaktivieren',
                onSelect = function()
                    uiOnlyNotice('Deaktivieren')
                end
            },
            {
                title = 'Loeschen',
                description = 'Loeschansicht oeffnen',
                onSelect = function()
                    showContext(CONTEXT.delete)
                end
            },
            {
                title = 'Import',
                description = 'Import Dialog oeffnen',
                onSelect = function()
                    showContext(CONTEXT.import)
                end
            },
            {
                title = 'Export',
                description = 'Export vorbereiten',
                onSelect = function()
                    showContext(CONTEXT.export)
                end
            },
            {
                title = 'Zurueck',
                description = 'Zur Itemliste',
                onSelect = function()
                    showContext(CONTEXT.items)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.editor,
        title = 'Item Editor',
        options = {
            {
                title = 'Allgemein',
                description = 'Name, Label, Beschreibung, Gewicht',
                onSelect = function()
                    showContext(CONTEXT.tabGeneral)
                end
            },
            {
                title = 'Typ',
                description = 'Typ, Kategorie, Stack, Nutzbarkeit',
                onSelect = function()
                    showContext(CONTEXT.tabType)
                end
            },
            {
                title = 'Metadata',
                description = 'Tags und Item-Metadaten',
                onSelect = function()
                    showContext(CONTEXT.tabMetadata)
                end
            },
            {
                title = 'Use Config',
                description = 'Benutzungsregeln vorbereiten',
                onSelect = function()
                    showContext(CONTEXT.tabUseConfig)
                end
            },
            {
                title = 'Preview',
                description = 'Vorschau des Items',
                onSelect = function()
                    showContext(CONTEXT.preview)
                end
            },
            {
                title = 'Rechte',
                description = 'Berechtigungen fuer Item Studio',
                onSelect = function()
                    showContext(CONTEXT.rights)
                end
            },
            {
                title = 'Zurueck',
                description = 'Zur Itemliste',
                onSelect = function()
                    showContext(CONTEXT.items)
                end
            }
        }
    })

    local item = getSelectedItem()

    registerContext({
        id = CONTEXT.tabGeneral,
        title = 'Allgemein',
        options = {
            { title = 'Name', description = item.name, disabled = true },
            { title = 'Label', description = item.label, disabled = true },
            { title = 'Beschreibung', description = item.description, disabled = true },
            { title = 'Gewicht', description = tostring(item.weight) .. 'g', disabled = true },
            {
                title = 'Bearbeiten',
                description = 'Oeffnet Input, speichert aber noch nicht',
                onSelect = openGeneralDraft
            },
            {
                title = 'Zurueck',
                description = 'Zum Editor',
                onSelect = function()
                    showContext(CONTEXT.editor)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.tabType,
        title = 'Typ',
        options = {
            { title = 'Typ', description = item.item_type, disabled = true },
            { title = 'Kategorie', description = item.category, disabled = true },
            { title = 'Aktiv', description = boolLabel(item.enabled), disabled = true },
            { title = 'Benutzbar', description = boolLabel(item.usable), disabled = true },
            { title = 'Stackable', description = boolLabel(item.stackable), disabled = true },
            { title = 'Max Stack', description = tostring(item.max_stack), disabled = true },
            {
                title = 'Zurueck',
                description = 'Zum Editor',
                onSelect = function()
                    showContext(CONTEXT.editor)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.tabMetadata,
        title = 'Metadata',
        options = {
            { title = 'Kategorie', description = item.category, disabled = true },
            { title = 'Seltenheit', description = item.rarity, disabled = true },
            { title = 'Tags', description = item.metadata, disabled = true },
            {
                title = 'Zurueck',
                description = 'Zum Editor',
                onSelect = function()
                    showContext(CONTEXT.editor)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.tabUseConfig,
        title = 'Use Config',
        options = {
            { title = 'Konfiguration', description = item.use_config, disabled = true },
            { title = 'Animation', description = 'Vorbereitet, noch keine Ausfuehrung', disabled = true },
            { title = 'Effekte', description = 'Vorbereitet, noch keine Ausfuehrung', disabled = true },
            {
                title = 'Zurueck',
                description = 'Zum Editor',
                onSelect = function()
                    showContext(CONTEXT.editor)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.preview,
        title = 'Preview',
        options = buildPreviewOptions()
    })

    registerContext({
        id = CONTEXT.rights,
        title = 'Rechte Editor',
        options = buildPermissionOptions()
    })

    registerContext({
        id = CONTEXT.categories,
        title = 'Kategoriebaum',
        options = buildCategoryOptions()
    })

    registerContext({
        id = CONTEXT.import,
        title = 'Import',
        options = {
            {
                title = 'Import vorbereiten',
                description = 'Oeffnet Input, ohne Daten zu speichern',
                onSelect = openImportDraft
            },
            {
                title = 'Zurueck',
                description = 'Zur Sidebar',
                onSelect = function()
                    showContext(CONTEXT.sidebar)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.export,
        title = 'Export',
        options = {
            {
                title = 'Aktuelles Item exportieren',
                description = getSelectedItem().name,
                onSelect = openExportDraft
            },
            {
                title = 'Zurueck',
                description = 'Zur Sidebar',
                onSelect = function()
                    showContext(CONTEXT.sidebar)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.settings,
        title = 'Settings',
        options = {
            { title = 'Theme', description = 'NexaUI Standard', disabled = true },
            { title = 'Autosave', description = 'Aus, keine Speicherung in Phase 1', disabled = true },
            {
                title = 'Zurueck',
                description = 'Zur Sidebar',
                onSelect = function()
                    showContext(CONTEXT.sidebar)
                end
            }
        }
    })

    registerContext({
        id = CONTEXT.delete,
        title = 'Loeschen',
        options = {
            {
                title = 'Loeschen vorbereiten',
                description = getSelectedItem().name .. ' wird nicht geloescht.',
                onSelect = function()
                    uiOnlyNotice('Loeschen')
                end
            },
            {
                title = 'Zurueck',
                description = 'Zur Toolbar',
                onSelect = function()
                    showContext(CONTEXT.toolbar)
                end
            }
        }
    })
end

local function openItemStudio()
    if contextsRegistered ~= true then
        registerItemStudioContexts()
    end

    exports.nexa_ui:showContext(CONTEXT.sidebar)
end

RegisterCommand('itemstudio', function()
    openItemStudio()
end, false)

RegisterCommand('nexaitems', function()
    openItemStudio()
end, false)

CreateThread(function()
    Wait(500)
    registerItemStudioContexts()
end)
