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

    function createInputPreview(field) {
        if (field.type === 'textarea') {
            const textarea = document.createElement('textarea');
            textarea.rows = 4;
            textarea.disabled = true;
            textarea.value = field.default || '';
            return textarea;
        }

        if (field.type === 'checkbox') {
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.disabled = true;
            checkbox.checked = field.default === true;
            return checkbox;
        }

        if (field.type === 'select') {
            const select = document.createElement('select');
            select.disabled = true;

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
        input.disabled = true;
        input.value = field.default !== undefined ? field.default : '';

        return input;
    }

    function renderInputDialog(payload) {
        locale = payload.locale || locale;
        showShell(payload.title || locale.panelTitle || 'NEXA');
        clearPanel();

        const form = document.createElement('div');
        form.className = 'nexa-input-dialog';

        (payload.fields || []).forEach((rawField) => {
            const field = typeof rawField === 'object' && rawField !== null ? rawField : {};
            const row = document.createElement('label');
            row.className = 'nexa-field';

            const label = document.createElement('span');
            label.className = 'nexa-field__label';
            label.textContent = text(field.label || field.title, 'Feld');

            const control = createInputPreview(field);
            control.className = 'nexa-field__control';

            const description = document.createElement('span');
            description.className = 'nexa-field__description';
            description.textContent = text(field.description, '');

            row.append(label, control, description);
            form.append(row);
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
