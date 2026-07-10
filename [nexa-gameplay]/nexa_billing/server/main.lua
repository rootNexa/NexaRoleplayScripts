local migrated = false

Invoices = {}
InvoicePayments = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_BILLING_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeAmount(value) value = tonumber(value); if not value or value < 1 or value % 1 ~= 0 or value > NexaBillingConfig.maxAmount then return nil end; return math.floor(value) end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local normalized = value:gsub('^%s+', ''):gsub('%s+$', ''); if normalized == '' or (maxLength and #normalized > maxLength) then return nil end; return normalized end
local function correlationId(prefix) return ('%s:%s:%s:%s'):format(prefix or 'invoice', os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999)) end
local function invoiceNumber() return ('INV-%s-%s'):format(os.date('!%Y%m%d%H%M%S'), math.random(1000, 9999)) end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return good and core or nil
end

local function log(level, category, message, context)
    local core = getCore()
    if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end
    print(('[%s] [%s] %s %s'):format(NEXA_BILLING.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()
    if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_BILLING.resourceName }) end
end

local function actorContext(actor, action)
    actor = type(actor) == 'table' and actor or {}
    return { action = action, actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_BILLING.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or correlationId(action), idempotency_key = normalizeString(actor.idempotency_key, 128) }
end

local function audit(action, context, result, payload)
    payload = payload or {}
    NexaBillingDatabase.InsertAudit({ invoice_id = payload.invoice_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata })
end

local function calculateItems(items)
    if type(items) ~= 'table' or #items == 0 or #items > NexaBillingConfig.maxItems then return nil, fail(NEXA_BILLING_ERRORS.itemsInvalid, 'Invoice items are invalid.') end
    local normalized, total = {}, 0
    for index, item in ipairs(items) do
        local quantity = normalizeAmount(item.quantity or 1)
        local unit = normalizeAmount(item.unit_amount or item.price)
        local description = normalizeString(item.description, 255)
        if not quantity or not unit or not description then return nil, fail(NEXA_BILLING_ERRORS.itemsInvalid, 'Invoice item is invalid.') end
        local lineTotal = quantity * unit
        if lineTotal < 1 or lineTotal > NexaBillingConfig.maxAmount then return nil, fail(NEXA_BILLING_ERRORS.amountInvalid, 'Invoice item amount is invalid.') end
        total = total + lineTotal
        normalized[#normalized + 1] = { position = index, description = description, quantity = quantity, unit_amount = unit, total_amount = lineTotal, category = normalizeString(item.category, 64), reference_type = normalizeString(item.reference_type, 64), reference_id = normalizeString(item.reference_id, 64), metadata = item.metadata or {} }
    end
    if total < 1 or total > NexaBillingConfig.maxAmount then return nil, fail(NEXA_BILLING_ERRORS.amountInvalid, 'Invoice total is invalid.') end
    return { items = normalized, total_amount = total }, nil
end

function Invoices.Create(actorSource, definition, context)
    definition = type(definition) == 'table' and definition or {}
    context = actorContext(context, 'invoice.create')
    local items, invalid = calculateItems(definition.items)
    if invalid then return invalid end
    local issuerType = normalizeString(definition.issuer_type or 'organization', 32)
    local issuerId = normalizeString(tostring(definition.issuer_id or definition.organization_id or ''), 64)
    local recipientType = normalizeString(definition.recipient_type, 32)
    local recipientId = normalizeString(tostring(definition.recipient_id or ''), 64)
    if not issuerType or not issuerId then return fail(NEXA_BILLING_ERRORS.issuerInvalid, 'Issuer is invalid.') end
    if not recipientType or not recipientId then return fail(NEXA_BILLING_ERRORS.recipientInvalid, 'Recipient is invalid.') end
    if issuerType == recipientType and issuerId == recipientId then return fail(NEXA_BILLING_ERRORS.recipientInvalid, 'Issuer and recipient must differ.') end
    local description = normalizeString(definition.description, 255)
    if not description then return fail(NEXA_BILLING_ERRORS.reasonRequired, 'Description is required.') end
    local invoiceId, err = NexaBillingDatabase.InsertInvoice({ invoice_number = invoiceNumber(), invoice_type = normalizeString(definition.invoice_type or 'standard', 32), issuer_type = issuerType, issuer_id = issuerId, recipient_type = recipientType, recipient_id = recipientId, organization_id = normalizeId(definition.organization_id), currency = NexaBillingConfig.defaultCurrency, total_amount = items.total_amount, status = NEXA_INVOICE_STATUS.issued, description = description, due_at = definition.due_at or (os.time() + 604800), created_by_account_id = context.actor_account_id, created_by_character_id = context.actor_character_id, correlation_id = context.correlation_id, metadata = definition.metadata or {} })
    if err then return fail(NEXA_BILLING_ERRORS.databaseError, 'Invoice could not be created.', err) end
    for _, item in ipairs(items.items) do item.invoice_id = invoiceId; NexaBillingDatabase.InsertItem(item) end
    local result = ok({ invoice_id = invoiceId, total_amount = items.total_amount }, 'Invoice created.')
    audit('invoice.create', context, result, { invoice_id = invoiceId, after_state = definition })
    emit(NEXA_BILLING_EVENTS.invoiceCreated, result.data)
    return result
end

function Invoices.Get(invoiceId)
    local row, err = NexaBillingDatabase.GetInvoice(normalizeId(invoiceId))
    if err then return fail(NEXA_BILLING_ERRORS.databaseError, 'Invoice could not be loaded.', err) end
    if not row then return fail(NEXA_BILLING_ERRORS.notFound, 'Invoice not found.') end
    local items = NexaBillingDatabase.ListItems(row.id) or {}
    row.items = items
    return ok(row, 'Invoice loaded.')
end

function Invoices.List(filters) local rows, err = NexaBillingDatabase.ListInvoices(); return err and fail(NEXA_BILLING_ERRORS.databaseError, 'Invoices could not be listed.', err) or ok(rows or {}, 'Invoices listed.') end
function Invoices.ListForRecipient(recipient, filters) recipient = type(recipient) == 'table' and recipient or {}; local rows, err = NexaBillingDatabase.ListRecipientInvoices(recipient.type, tostring(recipient.id)); return err and fail(NEXA_BILLING_ERRORS.databaseError, 'Invoices could not be listed.', err) or ok(rows or {}, 'Recipient invoices listed.') end
function Invoices.ListForIssuer(issuer, filters) issuer = type(issuer) == 'table' and issuer or {}; local rows, err = NexaBillingDatabase.ListIssuerInvoices(issuer.type, tostring(issuer.id)); return err and fail(NEXA_BILLING_ERRORS.databaseError, 'Invoices could not be listed.', err) or ok(rows or {}, 'Issuer invoices listed.') end
function Invoices.MarkViewed(actorSource, invoiceId) NexaBillingDatabase.UpdateInvoiceStatus(normalizeId(invoiceId), NEXA_INVOICE_STATUS.viewed); emit(NEXA_BILLING_EVENTS.invoiceViewed, { invoiceId = invoiceId }); return ok({ invoice_id = invoiceId }, 'Invoice viewed.') end
function Invoices.Cancel(actor, invoiceId, reason) local context = actorContext(actor or { reason = reason }, 'invoice.cancel'); if not context.reason then return fail(NEXA_BILLING_ERRORS.reasonRequired, 'Reason is required.') end; local invoice = Invoices.Get(invoiceId); if not invoice.ok then return invoice end; if invoice.data.status == NEXA_INVOICE_STATUS.paid then return fail(NEXA_BILLING_ERRORS.cancelForbidden, 'Paid invoice cannot be cancelled.') end; NexaBillingDatabase.UpdateInvoiceStatus(invoice.data.id, NEXA_INVOICE_STATUS.cancelled); local result = ok({ invoice_id = invoice.data.id }, 'Invoice cancelled.'); audit('invoice.cancel', context, result, { invoice_id = invoice.data.id, before_state = invoice.data }); emit(NEXA_BILLING_EVENTS.invoiceCancelled, result.data); return result end
function Invoices.Dispute(actorSource, invoiceId, reason) if not reason then return fail(NEXA_BILLING_ERRORS.reasonRequired, 'Reason is required.') end; NexaBillingDatabase.UpdateInvoiceStatus(normalizeId(invoiceId), NEXA_INVOICE_STATUS.disputed); emit(NEXA_BILLING_EVENTS.invoiceDisputed, { invoiceId = invoiceId }); return ok({ invoice_id = invoiceId }, 'Invoice disputed.') end
function Invoices.CreateCredit(actor, invoiceId, amount, reason) local context = actorContext(actor or { reason = reason }, 'invoice.credit'); amount = normalizeAmount(amount); if not amount then return fail(NEXA_BILLING_ERRORS.creditInvalid, 'Credit amount is invalid.') end; local result = ok({ invoice_id = invoiceId, amount = amount }, 'Credit foundation recorded.'); audit('invoice.credit', context, result, { invoice_id = invoiceId, amount = amount }); emit(NEXA_BILLING_EVENTS.creditCreated, result.data); return result end
function Invoices.GetCredits(invoiceId) return ok({}, 'Credits listing is deferred in foundation.') end
function Invoices.MarkOverdue(now) local rows, err = NexaBillingDatabase.ListOverdue(now or os.time()); if err then return fail(NEXA_BILLING_ERRORS.databaseError, 'Overdue invoices could not be listed.', err) end; for _, invoice in ipairs(rows or {}) do NexaBillingDatabase.UpdateInvoiceStatus(invoice.id, NEXA_INVOICE_STATUS.overdue); emit(NEXA_BILLING_EVENTS.invoiceOverdue, { invoiceId = invoice.id }) end; return ok(rows or {}, 'Overdue invoices marked.') end
function Invoices.GetOverdue(filters) local rows, err = NexaBillingDatabase.ListOverdue(os.time()); return err and fail(NEXA_BILLING_ERRORS.databaseError, 'Overdue invoices could not be listed.', err) or ok(rows or {}, 'Overdue invoices listed.') end
function Invoices.GetDueSoon(window) return ok({}, 'Due soon listing is deferred in foundation.') end

local function resolveCharacterAccount(characterId)
    local account = exports.nexa_economy:GetCharacterBankAccount(characterId)
    return account and account.ok and account.data.id or nil
end

function InvoicePayments.Pay(actorSource, invoiceId, amount, context)
    context = actorContext(context, 'invoice.pay')
    local invoice = Invoices.Get(invoiceId); if not invoice.ok then return invoice end
    if invoice.data.status == NEXA_INVOICE_STATUS.paid then return fail(NEXA_BILLING_ERRORS.alreadyPaid, 'Invoice already paid.') end
    if invoice.data.status == NEXA_INVOICE_STATUS.cancelled then return fail(NEXA_BILLING_ERRORS.cancelled, 'Invoice is cancelled.') end
    amount = normalizeAmount(amount or (tonumber(invoice.data.total_amount) - tonumber(invoice.data.paid_amount or 0)))
    if not amount then return fail(NEXA_BILLING_ERRORS.amountInvalid, 'Payment amount is invalid.') end
    local outstanding = tonumber(invoice.data.total_amount) - tonumber(invoice.data.paid_amount or 0)
    if amount > outstanding then return fail(NEXA_BILLING_ERRORS.overpayment, 'Overpayment is not allowed.') end
    if not NexaBillingConfig.allowPartialPayments and amount ~= outstanding then return fail(NEXA_BILLING_ERRORS.amountInvalid, 'Partial payments are disabled.') end
    local payerCharacterId = normalizeId(context.actor_character_id or actorSource)
    local sourceAccountId = resolveCharacterAccount(payerCharacterId)
    local targetAccountId
    if invoice.data.issuer_type == 'character' then targetAccountId = resolveCharacterAccount(invoice.data.issuer_id) end
    if not targetAccountId and invoice.data.organization_id then
        local org = exports.nexa_organizations:GetOrganization(invoice.data.organization_id)
        targetAccountId = org and org.ok and org.data.economy_account_id or nil
    end
    if not sourceAccountId or not targetAccountId then return fail(NEXA_BILLING_ERRORS.paymentFailed, 'Payment accounts could not be resolved.') end
    local transfer = exports.nexa_economy:Transfer(sourceAccountId, targetAccountId, amount, { reason = 'Invoice payment', idempotency_key = context.idempotency_key, correlation_id = context.correlation_id, source_resource = NEXA_BILLING.resourceName })
    if not transfer or not transfer.ok then return fail(NEXA_BILLING_ERRORS.paymentFailed, 'Economy payment failed.', transfer) end
    local status = amount == outstanding and NEXA_INVOICE_STATUS.paid or NEXA_INVOICE_STATUS.partiallyPaid
    NexaBillingDatabase.InsertPayment({ invoice_id = invoice.data.id, amount = amount, payer_account_id = context.actor_account_id, payer_character_id = payerCharacterId, source_economy_account_id = sourceAccountId, target_economy_account_id = targetAccountId, economy_transaction_id = transfer.data.transaction_id, status = NEXA_INVOICE_PAYMENT_STATUS.completed, idempotency_key = context.idempotency_key, correlation_id = context.correlation_id, metadata = {} })
    NexaBillingDatabase.UpdateInvoicePaid(invoice.data.id, amount, status)
    local result = ok({ invoice_id = invoice.data.id, amount = amount, economy_transaction_id = transfer.data.transaction_id, status = status }, 'Invoice paid.')
    audit('invoice.pay', context, result, { invoice_id = invoice.data.id, amount = amount })
    emit(NEXA_BILLING_EVENTS.invoicePaid, result.data)
    return result
end

function InvoicePayments.Get(paymentId) local row, err = NexaBillingDatabase.GetPayment(normalizeId(paymentId)); return err and fail(NEXA_BILLING_ERRORS.databaseError, 'Payment could not be loaded.', err) or (row and ok(row, 'Payment loaded.') or fail(NEXA_BILLING_ERRORS.notFound, 'Payment not found.')) end
function InvoicePayments.List(invoiceId) local rows, err = NexaBillingDatabase.ListPayments(normalizeId(invoiceId)); return err and fail(NEXA_BILLING_ERRORS.databaseError, 'Payments could not be listed.', err) or ok(rows or {}, 'Payments listed.') end
function InvoicePayments.Retry(paymentId, context) return fail(NEXA_BILLING_ERRORS.paymentFailed, 'Payment retry is deferred in foundation.') end

function CreateInvoice(...) return Invoices.Create(...) end
function GetInvoice(...) return Invoices.Get(...) end
function ListInvoices(...) return Invoices.List(...) end
function ListRecipientInvoices(...) return Invoices.ListForRecipient(...) end
function ListIssuerInvoices(...) return Invoices.ListForIssuer(...) end
function PayInvoice(...) return InvoicePayments.Pay(...) end
function CancelInvoice(...) return Invoices.Cancel(...) end
function DisputeInvoice(...) return Invoices.Dispute(...) end
function CreateInvoiceCredit(...) return Invoices.CreateCredit(...) end
function GetInvoicePayments(...) return InvoicePayments.List(...) end
function GetOverdueInvoices(...) return Invoices.GetOverdue(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaBillingConfig.autoMigrate then migrated = NexaBillingDatabase.Migrate() == true end
    log('Info', 'billing.start', 'nexa_billing started.', { migrated = migrated })
end)

exports('CreateInvoice', CreateInvoice)
exports('GetInvoice', GetInvoice)
exports('ListInvoices', ListInvoices)
exports('ListRecipientInvoices', ListRecipientInvoices)
exports('ListIssuerInvoices', ListIssuerInvoices)
exports('PayInvoice', PayInvoice)
exports('CancelInvoice', CancelInvoice)
exports('DisputeInvoice', DisputeInvoice)
exports('CreateInvoiceCredit', CreateInvoiceCredit)
exports('GetInvoicePayments', GetInvoicePayments)
exports('GetOverdueInvoices', GetOverdueInvoices)
exports('getStatus', function() return { resourceName = NEXA_BILLING.resourceName, version = NEXA_BILLING.version, migrated = migrated } end)
exports('getSchema', NexaBillingDatabase.GetSchema)
