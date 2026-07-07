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

    function showPanel(payload) {
        locale = payload.locale || locale;
        panelTitle.textContent = text(payload.panel && payload.panel.title, locale.panelTitle || 'NEXA');
        clearPanel();
        app.hidden = false;
    }

    function hidePanel() {
        app.hidden = true;
        clearPanel();
    }

    function renderConfirm(payload) {
        panelTitle.textContent = text(payload.title, locale.confirmTitle || 'Bestaetigung');
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
        app.hidden = false;
    }

    function renderMenu(payload) {
        panelTitle.textContent = text(payload.title, locale.menuTitle || 'Auswahl');
        clearPanel();

        const list = document.createElement('ul');
        list.className = 'nexa-menu';

        (payload.items || []).forEach((item) => {
            const entry = document.createElement('li');
            const button = document.createElement('button');
            button.className = 'nexa-menu__item';
            button.type = 'button';
            button.disabled = item.disabled === true;
            button.addEventListener('click', () => post('nexaUiMenuSelect', {
                id: item.id
            }));

            const label = document.createElement('span');
            label.className = 'nexa-menu__label';
            label.textContent = text(item.label, locale.menuTitle || 'Auswahl');

            const description = document.createElement('span');
            description.className = 'nexa-menu__description';
            description.textContent = text(item.description, '');

            button.append(label, description);
            entry.append(button);
            list.append(entry);
        });

        panelContent.append(list);
        app.hidden = false;
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

        if (message.type === 'closePanel') {
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
