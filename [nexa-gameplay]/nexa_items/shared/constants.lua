NEXA_ITEMS = {
    resourceName = 'nexa_items',
    version = '0.2.0'
}

NEXA_ITEMS_TABLES = {
    definitions = 'nexa_item_definitions',
    versions = 'nexa_item_definition_versions',
    actions = 'nexa_item_actions',
    assets = 'nexa_item_assets',
    audit = 'nexa_item_audit'
}

NEXA_ITEM_STATUS = {
    draft = 'draft',
    published = 'published',
    disabled = 'disabled',
    deprecated = 'deprecated',
    deleted = 'deleted'
}

NEXA_ITEMS_ERRORS = {
    definitionNotFound = 'ITEM_DEFINITION_NOT_FOUND',
    alreadyExists = 'ITEM_DEFINITION_ALREADY_EXISTS',
    nameInvalid = 'ITEM_NAME_INVALID',
    labelInvalid = 'ITEM_LABEL_INVALID',
    typeInvalid = 'ITEM_TYPE_INVALID',
    weightInvalid = 'ITEM_WEIGHT_INVALID',
    stackInvalid = 'ITEM_STACK_INVALID',
    statusInvalid = 'ITEM_STATUS_INVALID',
    metadataSchemaInvalid = 'ITEM_METADATA_SCHEMA_INVALID',
    metadataInvalid = 'ITEM_METADATA_INVALID',
    actionInvalid = 'ITEM_ACTION_INVALID',
    handlerNotFound = 'ITEM_HANDLER_NOT_FOUND',
    handlerForbidden = 'ITEM_HANDLER_FORBIDDEN',
    actionCooldown = 'ITEM_ACTION_COOLDOWN',
    notUsable = 'ITEM_NOT_USABLE',
    notQuickslotAllowed = 'ITEM_NOT_QUICKSLOT_ALLOWED',
    notDroppable = 'ITEM_NOT_DROPPABLE',
    notTradeable = 'ITEM_NOT_TRADEABLE',
    durabilityInvalid = 'ITEM_DURABILITY_INVALID',
    broken = 'ITEM_BROKEN',
    expired = 'ITEM_EXPIRED',
    versionConflict = 'ITEM_VERSION_CONFLICT',
    publishForbidden = 'ITEM_PUBLISH_FORBIDDEN',
    reasonRequired = 'ITEM_REASON_REQUIRED',
    assetInvalid = 'ITEM_ASSET_INVALID',
    assetDownloadFailed = 'ITEM_ASSET_DOWNLOAD_FAILED',
    assetSsrfRejected = 'ITEM_ASSET_SSRF_REJECTED',
    registryNotReady = 'ITEM_REGISTRY_NOT_READY',
    reloadFailed = 'ITEM_REGISTRY_RELOAD_FAILED',
    invalidInput = 'ITEM_INVALID_INPUT',
    databaseError = 'ITEM_DATABASE_ERROR',
    forbidden = 'ITEM_FORBIDDEN'
}

NEXA_ITEMS_CALLBACKS = {
    createItem = 'nexa:items:cb:createItem',
    getItem = 'nexa:items:cb:getItem',
    listItems = 'nexa:items:cb:listItems',
    updateItem = 'nexa:items:cb:updateItem',
    setItemEnabled = 'nexa:items:cb:setItemEnabled',
    deleteItem = 'nexa:items:cb:deleteItem',
    publishItem = 'nexa:items:cb:publishItem',
    validateDefinition = 'nexa:items:cb:validateDefinition',
    getClientCatalog = 'nexa:items:cb:getClientCatalog'
}
