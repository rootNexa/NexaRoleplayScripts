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
            list.append(makeMenuButton(option, () => {
                if (option.disabled === true) {
                    return;
                }

                post('nexaUiContextSelect', {
                    contextId: context.id,
                    index: option.index
                });
            }));
        });

        panelContent.append(list);
    }

    function createInput(field) {
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

            (field.options || []).forEach((option) => {
                const element = document.createElement('option');
                element.value = option.value;
                element.textContent = text(option.label, option.value);
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

        if (field.min !== undefined && field.type === 'number') {
            input.min = field.min;
        }

        if (field.max !== undefined && field.type === 'number') {
            input.max = field.max;
        }

        return input;
    }

    function readInput(control, field) {
        if (field.type === 'checkbox') {
            return control.checked;
        }

        if (field.type === 'number') {
            return control.value === '' ? null : Number(control.value);
        }

        return control.value;
    }

    function validateInput(value, field) {
        if (field.required === true && (value === null || value === '' || value === false)) {
            return false;
        }

        if (field.type === 'number' && value !== null) {
            if (!Number.isFinite(value)) {
                return false;
            }

            if (field.min !== undefined && value < Number(field.min)) {
                return false;
            }

            if (field.max !== undefined && value > Number(field.max)) {
                return false;
            }
        }

        return true;
    }

    function renderInputDialog(payload) {
        const dialog = payload.dialog || {};
        locale = payload.locale || locale;
        showShell(dialog.title || locale.panelTitle || 'NEXA');
        clearPanel();

        const form = document.createElement('form');
        form.className = 'nexa-form';
        const controls = [];

        (dialog.fields || []).forEach((field) => {
            const row = document.createElement('label');
            row.className = 'nexa-field';

            const label = document.createElement('span');
            label.className = 'nexa-field__label';
            label.textContent = text(field.label, 'Feld');

            const control = createInput(field);
            control.className = 'nexa-field__control';

            const description = document.createElement('span');
            description.className = 'nexa-field__description';
            description.textContent = text(field.description, '');

            row.append(label, control, description);
            form.append(row);
            controls.push({ field, control, row });
        });

        const actions = document.createElement('div');
        actions.className = 'nexa-actions';

        const cancel = document.createElement('button');
        cancel.className = 'nexa-button';
        cancel.type = 'button';
        cancel.textContent = text(dialog.cancelLabel, locale.cancel || 'Abbrechen');
        cancel.addEventListener('click', () => post('nexaUiInputCancel', {
            id: dialog.id
        }));

        const submit = document.createElement('button');
        submit.className = 'nexa-button nexa-button--primary';
        submit.type = 'submit';
        submit.textContent = text(dialog.submitLabel, locale.inputSubmit || 'Absenden');

        actions.append(cancel, submit);
        form.append(actions);

        form.addEventListener('submit', (event) => {
            event.preventDefault();
            const values = [];

            for (const item of controls) {
                const value = readInput(item.control, item.field);

                item.row.dataset.invalid = validateInput(value, item.field) ? 'false' : 'true';

                if (item.row.dataset.invalid === 'true') {
                    return;
                }

                values[item.field.index - 1] = value;
            }

            post('nexaUiInputSubmit', {
                id: dialog.id,
                values
            });
        });

        panelContent.append(form);
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
