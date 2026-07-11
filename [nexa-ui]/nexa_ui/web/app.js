(function () {
    const app = document.getElementById('app');
    const panelTitle = document.getElementById('panelTitle');
    const panelContent = document.getElementById('panelContent');
    const toastRegion = document.getElementById('toastRegion');
    let locale = {};

    function post(name, data) {
        fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify(data || {})
        });
    }

    function text(value, fallback) {
        return typeof value === 'string' && value.trim() !== '' ? value : fallback;
    }

    function clearPanel() {
        panelContent.replaceChildren();
    }

    function showShell(title) {
        panelTitle.textContent = text(title, locale.panelTitle || 'NEXA');
        app.hidden = false;
    }

    function showPanel(payload) {
        locale = payload.locale || locale;
        showShell(payload.panel && payload.panel.title);
        clearPanel();
    }

    function hidePanel() {
        app.hidden = true;
        clearPanel();
    }

    function renderConfirm(payload) {
        showShell(payload.title || locale.confirmTitle || 'Bestaetigung');
        clearPanel();

        const message = document.createElement('p');
        message.className = 'nexa-dialog-text';
        message.textContent = text(payload.message, locale.invalidPayload || 'Die Anzeige konnte nicht geoeffnet werden.');

        const actions = document.createElement('div');
        actions.className = 'nexa-actions';

        const cancel = document.createElement('button');
        cancel.className = 'nexa-button';
        cancel.type = 'button';
        cancel.textContent = text(payload.cancelLabel, locale.cancel || 'Abbrechen');
        cancel.addEventListener('click', () => post('nexaUiConfirmResult', {
            id: payload.id,
            confirmed: false
        }));

        const confirm = document.createElement('button');
        confirm.className = 'nexa-button nexa-button--primary';
        confirm.type = 'button';
        confirm.textContent = text(payload.confirmLabel, locale.confirm || 'Bestaetigen');
        confirm.addEventListener('click', () => post('nexaUiConfirmResult', {
            id: payload.id,
            confirmed: true
        }));

        actions.append(cancel, confirm);
        panelContent.append(message, actions);
    }

    function makeMenuButton(item, onClick) {
        const entry = document.createElement('li');
        const button = document.createElement('button');
        button.className = 'nexa-menu__item';
        button.type = 'button';
        button.disabled = item.disabled === true;
        button.addEventListener('click', onClick);

        const label = document.createElement('span');
        label.className = 'nexa-menu__label';
        label.textContent = text(item.label || item.title, locale.menuTitle || 'Auswahl');

        const description = document.createElement('span');
        description.className = 'nexa-menu__description';
        description.textContent = text(item.description, '');

        button.append(label, description);
        entry.append(button);
        return entry;
    }

    function renderMenu(payload) {
        showShell(payload.title || locale.menuTitle || 'Auswahl');
        clearPanel();

        const list = document.createElement('ul');
        list.className = 'nexa-menu';

        (payload.items || []).forEach((item) => {
            list.append(makeMenuButton(item, () => post('nexaUiMenuSelect', {
                id: item.id
            })));
        });

        panelContent.append(list);
    }

    function renderContext(payload) {
        const context = payload.context || {};
        locale = payload.locale || locale;
        showShell(context.title || locale.menuTitle || 'Auswahl');
        clearPanel();

        const list = document.createElement('ul');
        list.className = 'nexa-menu';

        (context.options || []).forEach((option) => {
            const entry = document.createElement('li');
            const item = document.createElement('button');
            item.className = 'nexa-menu__item';
            item.type = 'button';
            item.disabled = option.disabled === true;
            item.addEventListener('click', () => post('contextSelect', {
                contextId: context.id,
                optionIndex: option.optionIndex
            }));

            const label = document.createElement('span');
            label.className = 'nexa-menu__label';
            label.textContent = text(option.title || option.label, locale.menuTitle || 'Auswahl');

            const description = document.createElement('span');
            description.className = 'nexa-menu__description';
            description.textContent = text(option.description, '');

            item.append(label, description);
            entry.append(item);
            list.append(entry);
        });

        panelContent.append(list);
    }

    function createInputControl(field) {
        if (field.type === 'textarea') {
            const textarea = document.createElement('textarea');
            textarea.rows = 4;
            textarea.value = field.default || '';
            return textarea;
        }

        if (field.type === 'checkbox') {
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.checked = field.default === true;
            return checkbox;
        }

        if (field.type === 'select') {
            const select = document.createElement('select');

            (field.options || []).forEach((rawOption) => {
                const option = typeof rawOption === 'object' && rawOption !== null ? rawOption : {
                    label: String(rawOption || ''),
                    value: rawOption
                };
                const element = document.createElement('option');
                element.value = option.value;
                element.textContent = text(option.label, String(option.value || ''));
                select.append(element);
            });

            if (field.default !== undefined) {
                select.value = field.default;
            }

            return select;
        }

        const input = document.createElement('input');
        input.type = field.type === 'number' ? 'number' : 'text';
        input.value = field.default !== undefined ? field.default : '';

        return input;
    }

    function readInputValue(control, field) {
        if (field.type === 'checkbox') {
            return control.checked;
        }

        if (field.type === 'number') {
            const numberValue = Number(control.value);
            return Number.isFinite(numberValue) && control.value !== '' ? numberValue : control.value;
        }

        return control.value;
    }

    function validateInputValue(value, field) {
        if (field.required === true) {
            if (field.type === 'checkbox' && value !== true) {
                return 'Dieses Feld ist erforderlich.';
            }

            if (field.type === 'select' && (value === '' || value === undefined || value === null)) {
                return 'Bitte waehle einen Wert aus.';
            }

            if (field.type !== 'checkbox' && field.type !== 'select' && String(value || '').trim() === '') {
                return 'Dieses Feld ist erforderlich.';
            }
        }

        if (field.type === 'number' && value !== '') {
            if (typeof value !== 'number' || !Number.isFinite(value)) {
                return 'Bitte gib eine Zahl ein.';
            }

            if (field.min !== undefined && value < Number(field.min)) {
                return `Minimum ist ${field.min}.`;
            }

            if (field.max !== undefined && value > Number(field.max)) {
                return `Maximum ist ${field.max}.`;
            }
        }

        if ((field.type === 'input' || field.type === 'textarea' || field.type === undefined) && typeof value === 'string' && value !== '') {
            if (field.minLength !== undefined && value.length < Number(field.minLength)) {
                return `Mindestens ${field.minLength} Zeichen.`;
            }

            if (field.maxLength !== undefined && value.length > Number(field.maxLength)) {
                return `Maximal ${field.maxLength} Zeichen.`;
            }
        }

        return '';
    }

    function renderInputDialog(payload) {
        locale = payload.locale || locale;
        showShell(payload.title || locale.panelTitle || 'NEXA');
        clearPanel();

        const form = document.createElement('form');
        form.className = 'nexa-input-dialog';
        const controls = [];

        (payload.fields || []).forEach((rawField, index) => {
            const field = typeof rawField === 'object' && rawField !== null ? rawField : {};
            const row = document.createElement('label');
            row.className = 'nexa-field';

            const label = document.createElement('span');
            label.className = 'nexa-field__label';
            label.textContent = text(field.label || field.title, 'Feld');

            const control = createInputControl(field);
            control.className = 'nexa-field__control';

            const description = document.createElement('span');
            description.className = 'nexa-field__description';
            description.textContent = text(field.description, '');

            const error = document.createElement('span');
            error.className = 'nexa-field__error';

            row.append(label, control, description, error);
            form.append(row);
            controls.push({ control, error, field, index, row });
        });

        const actions = document.createElement('div');
        actions.className = 'nexa-actions';

        const cancel = document.createElement('button');
        cancel.className = 'nexa-button';
        cancel.type = 'button';
        cancel.textContent = text(payload.options && payload.options.cancelLabel, locale.cancel || 'Abbrechen');
        cancel.addEventListener('click', () => post('inputCancel', {
            id: payload.id
        }));

        const submit = document.createElement('button');
        submit.className = 'nexa-button nexa-button--primary';
        submit.type = 'submit';
        submit.textContent = text(payload.options && payload.options.submitLabel, locale.confirm || 'Bestaetigen');

        actions.append(cancel, submit);
        form.append(actions);

        form.addEventListener('submit', (event) => {
            event.preventDefault();
            const values = [];
            let hasError = false;

            controls.forEach((item) => {
                const value = readInputValue(item.control, item.field);
                const error = validateInputValue(value, item.field);

                item.row.dataset.invalid = error !== '' ? 'true' : 'false';
                item.error.textContent = error;
                values[item.index] = value;

                if (error !== '') {
                    hasError = true;
                }
            });

            if (hasError) {
                return;
            }

            post('inputSubmit', {
                id: payload.id,
                values
            });
        });

        panelContent.append(form);
    }

    function getOverlayRoot(id, className) {
        let root = document.getElementById(id);

        if (!root) {
            root = document.createElement('section');
            root.id = id;
            root.className = className;
            root.hidden = true;
            document.body.append(root);
        }

        return root;
    }

    function hideOverlay(id) {
        const root = document.getElementById(id);

        if (!root) {
            return;
        }

        root.hidden = true;
        root.replaceChildren();
    }

    function renderLoading(payload) {
        const root = getOverlayRoot('nexaLoadingOverlay', 'nexa-loading-overlay');
        const box = document.createElement('div');
        box.className = 'nexa-loading-overlay__box';

        const spinner = document.createElement('div');
        spinner.className = 'nexa-loading-overlay__spinner';

        const label = document.createElement('p');
        label.className = 'nexa-loading-overlay__label';
        label.textContent = text(payload.label || payload.message, 'Laedt...');

        box.append(spinner, label);
        root.replaceChildren(box);
        root.hidden = false;
    }

    function renderError(payload) {
        const root = getOverlayRoot('nexaErrorOverlay', 'nexa-error-overlay');
        const box = document.createElement('article');
        box.className = 'nexa-error-overlay__box';

        const title = document.createElement('h2');
        title.textContent = text(payload.title, 'Fehler');

        const message = document.createElement('p');
        message.textContent = text(payload.message, 'Der Vorgang konnte nicht abgeschlossen werden.');

        const code = document.createElement('span');
        code.className = 'nexa-error-overlay__code';
        code.textContent = text(payload.code, '');

        box.append(title, message);

        if (code.textContent !== '') {
            box.append(code);
        }

        root.replaceChildren(box);
        root.hidden = false;
    }

    function renderWindow(payload) {
        const definition = payload.window || {};
        const windowPayload = payload.payload || {};
        const root = getOverlayRoot('nexaWindowLayer', 'nexa-window-layer');
        const id = text(definition.id, `window-${Date.now()}`);
        let windowElement = root.querySelector(`[data-window-id="${id}"]`);

        if (!windowElement) {
            windowElement = document.createElement('article');
            windowElement.className = 'nexa-window';
            windowElement.dataset.windowId = id;
            root.append(windowElement);
        }

        windowElement.dataset.size = text(definition.size, 'standard');
        windowElement.replaceChildren();

        const header = document.createElement('header');
        header.className = 'nexa-window__header';

        const titleGroup = document.createElement('div');
        const title = document.createElement('h2');
        title.textContent = text(windowPayload.title || definition.title, id);
        const subtitle = document.createElement('p');
        subtitle.textContent = text(windowPayload.subtitle || definition.subtitle, '');
        titleGroup.append(title, subtitle);
        header.append(titleGroup);

        if (definition.closable !== false) {
            const close = document.createElement('button');
            close.className = 'nexa-icon-button';
            close.type = 'button';
            close.textContent = 'x';
            close.addEventListener('click', () => post('nexaUiClose'));
            header.append(close);
        }

        const body = document.createElement('div');
        body.className = 'nexa-window__body';

        const sections = Array.isArray(windowPayload.sections) ? windowPayload.sections : definition.sections || [];

        if (sections.length === 0) {
            const empty = document.createElement('p');
            empty.className = 'nexa-window__empty';
            empty.textContent = text(windowPayload.emptyLabel, 'Keine Daten verfuegbar.');
            body.append(empty);
        }

        sections.forEach((section) => {
            const card = document.createElement('section');
            card.className = 'nexa-window__section';

            const sectionTitle = document.createElement('h3');
            sectionTitle.textContent = text(section.title, 'Bereich');
            const sectionText = document.createElement('p');
            sectionText.textContent = text(section.description || section.value, '');

            card.append(sectionTitle, sectionText);
            body.append(card);
        });

        windowElement.append(header, body);
        root.hidden = false;
    }

    function closeWindow(payload) {
        const id = payload.id;
        const root = document.getElementById('nexaWindowLayer');

        if (!root || typeof id !== 'string') {
            return;
        }

        const windowElement = root.querySelector(`[data-window-id="${id}"]`);

        if (windowElement) {
            windowElement.remove();
        }

        root.hidden = root.children.length === 0;
    }

    function notify(payload) {
        const toast = document.createElement('article');
        toast.className = 'nexa-toast';
        toast.dataset.type = payload.type || 'info';

        const title = document.createElement('p');
        title.className = 'nexa-toast__title';
        title.textContent = text(payload.title, locale.defaultNotificationTitle || 'Nexa');

        const message = document.createElement('p');
        message.className = 'nexa-toast__message';
        message.textContent = text(payload.message, '');

        toast.append(title, message);
        toastRegion.append(toast);

        window.setTimeout(() => toast.remove(), Number(payload.duration) || 4500);
    }

    window.addEventListener('message', (event) => {
        const message = event.data || {};
        const payload = message.payload || {};

        if (message.type === 'openPanel') {
            showPanel(payload);
        }

        if (message.type === 'closePanel' || message.type === 'context_close' || message.type === 'input_close') {
            hidePanel();
        }

        if (message.type === 'notify') {
            notify(payload);
        }

        if (message.type === 'confirm') {
            renderConfirm(payload);
        }

        if (message.type === 'menu') {
            renderMenu(payload);
        }

        if (message.type === 'context_open') {
            renderContext(payload);
        }

        if (message.type === 'input_open') {
            renderInputDialog(payload);
        }

        if (message.type === 'ui:loadingOpen') {
            renderLoading(payload);
        }

        if (message.type === 'ui:loadingClose') {
            hideOverlay('nexaLoadingOverlay');
        }

        if (message.type === 'ui:errorOpen') {
            renderError(payload);
        }

        if (message.type === 'ui:errorClose') {
            hideOverlay('nexaErrorOverlay');
        }

        if (message.type === 'ui:windowOpen') {
            renderWindow(payload);
        }

        if (message.type === 'ui:windowClose') {
            closeWindow(payload);
        }
    });

    document.addEventListener('click', (event) => {
        if (event.target && event.target.dataset.action === 'close') {
            post('nexaUiClose');
        }
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !app.hidden) {
            post('nexaUiClose');
        }
    });
}());
