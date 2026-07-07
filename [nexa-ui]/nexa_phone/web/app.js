const state = {
    visible: false,
    activeApp: 'contacts',
    locale: {},
    snapshot: {
        contacts: [],
        messages: [],
        calls: [],
        notes: [],
        mails: []
    }
};

const root = document.getElementById('phone');
const navRoot = document.getElementById('phoneNav');
const contentRoot = document.getElementById('phoneContent');
const noticeRoot = document.getElementById('phoneNotice');
const closeButton = document.getElementById('phoneClose');
const refreshButton = document.getElementById('phoneRefresh');

function postNui(name, payload = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(payload)
    }).catch(() => null);
}

function t(key, fallback = '') {
    return state.locale[key] || fallback;
}

function applyLocale(locale) {
    state.locale = locale || {};

    document.querySelectorAll('[data-i18n]').forEach((element) => {
        const key = element.getAttribute('data-i18n');
        element.textContent = t(key, element.textContent);
    });
}

function card(title, body, detail = '') {
    const element = document.createElement('article');
    element.className = 'phone-card';

    const heading = document.createElement('h2');
    heading.textContent = title;
    element.append(heading);

    if (body) {
        const text = document.createElement('p');
        text.textContent = body;
        element.append(text);
    }

    if (detail) {
        const small = document.createElement('small');
        small.textContent = detail;
        element.append(small);
    }

    return element;
}

function emptyCard() {
    return card(t('empty', 'Keine Eintraege vorhanden.'), '');
}

function renderList(items, mapItem) {
    const list = Array.isArray(items) ? items : [];

    if (list.length === 0) {
        contentRoot.append(emptyCard());
        return;
    }

    list.forEach((item) => contentRoot.append(mapItem(item)));
}

function renderNoteForm() {
    const form = document.createElement('form');
    form.className = 'phone-form';
    form.innerHTML = `
        <input name="title" maxlength="48" placeholder="${t('noteTitle', 'Titel')}">
        <textarea name="body" maxlength="280" placeholder="${t('noteBody', 'Notiz')}"></textarea>
        <button type="submit">${t('saveNote', 'Notiz speichern')}</button>
    `;
    form.addEventListener('submit', (event) => {
        event.preventDefault();
        postNui('nexaPhoneSaveNote', {
            title: form.title.value,
            body: form.body.value
        });
        form.reset();
    });
    contentRoot.append(form);
}

function renderMessageForm() {
    const form = document.createElement('form');
    form.className = 'phone-form';
    form.innerHTML = `
        <input name="recipient" maxlength="48" placeholder="${t('messageRecipient', 'Empfaenger')}">
        <textarea name="body" maxlength="180" placeholder="${t('messageBody', 'Nachricht')}"></textarea>
        <button type="submit">${t('sendMessage', 'Nachricht senden')}</button>
    `;
    form.addEventListener('submit', (event) => {
        event.preventDefault();
        postNui('nexaPhoneSendMessage', {
            recipient: form.recipient.value,
            body: form.body.value
        });
        form.reset();
    });
    contentRoot.append(form);
}

function render() {
    contentRoot.innerHTML = '';
    const data = state.snapshot || {};

    if (state.activeApp === 'contacts') {
        renderList(data.contacts, (item) => card(item.name, item.number, item.note));
    }

    if (state.activeApp === 'messages') {
        renderMessageForm();
        renderList(data.messages, (item) => card(item.recipient, item.body, `${item.direction} - ${item.createdAt}`));
    }

    if (state.activeApp === 'calls') {
        contentRoot.append(card(t('appCalls', 'Anrufe'), t('callHistoryInfo', 'Anrufhistorie ist nur Anzeige. Es gibt kein Telefonsystem.')));
        renderList(data.calls, (item) => card(item.label, item.number, `${item.direction} - ${item.time}`));
    }

    if (state.activeApp === 'notes') {
        renderNoteForm();
        renderList(data.notes, (item) => card(item.title, item.body, item.createdAt));
    }

    if (state.activeApp === 'mail') {
        contentRoot.append(card(t('appMail', 'Postfach'), t('mailInfo', 'Mail ist vorbereitet. Versand und Postfachregeln folgen spaeter.')));
        renderList(data.mails, (item) => card(item.subject, item.preview, item.sender));
    }

    if (state.activeApp === 'apps') {
        ['appContacts', 'appMessages', 'appCalls', 'appNotes', 'appMail'].forEach((key) => {
            contentRoot.append(card(t(key, key), t('subtitle', 'Basisdienste')));
        });
    }
}

function setVisible(visible) {
    state.visible = visible === true;
    root.classList.toggle('is-hidden', !state.visible);
}

navRoot.addEventListener('click', (event) => {
    const button = event.target.closest('button[data-app]');

    if (!button) {
        return;
    }

    state.activeApp = button.dataset.app;
    navRoot.querySelectorAll('button').forEach((item) => item.classList.toggle('is-active', item === button));
    render();
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    const payload = message.payload || {};

    if (message.type === 'phone:init') {
        applyLocale(payload.phoneLocale || {});
        noticeRoot.textContent = t('loading', 'Telefon wird geladen.');
    }

    if (message.type === 'phone:visibility') {
        setVisible(payload.visible);
    }

    if (message.type === 'phone:snapshot') {
        state.snapshot = payload || state.snapshot;
        noticeRoot.textContent = t('refresh', 'Aktualisieren');
        render();
    }

    if (message.type === 'phone:notice') {
        noticeRoot.textContent = payload.text || '';
    }
});

closeButton.addEventListener('click', () => postNui('nexaPhoneClose'));
refreshButton.addEventListener('click', () => postNui('nexaPhoneRefresh'));

postNui('nexaPhoneReady');
