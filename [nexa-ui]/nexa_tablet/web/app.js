const state = {
    visible: false,
    apps: [],
    locale: {}
};

const root = document.getElementById('tablet');
const appsRoot = document.getElementById('tabletApps');
const emptyRoot = document.getElementById('tabletEmpty');
const noticeRoot = document.getElementById('tabletNotice');
const closeButton = document.getElementById('tabletClose');
const refreshButton = document.getElementById('tabletRefresh');

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

function renderApps() {
    appsRoot.innerHTML = '';
    emptyRoot.classList.toggle('is-visible', state.apps.length === 0);

    state.apps.forEach((app) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'tablet-app';
        button.disabled = true;
        button.dataset.appId = app.id;

        const title = document.createElement('h2');
        title.textContent = app.title;

        const description = document.createElement('p');
        description.textContent = app.description;

        const badge = document.createElement('span');
        badge.className = 'tablet-badge';
        badge.textContent = t('placeholderBadge', 'Platzhalter');

        button.append(title, description, badge);
        button.addEventListener('click', () => postNui('nexaTabletOpenApp', { appId: app.id }));
        appsRoot.append(button);
    });
}

function setVisible(visible) {
    state.visible = visible === true;
    root.classList.toggle('is-hidden', !state.visible);
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    const payload = message.payload || {};

    if (message.type === 'tablet:init') {
        applyLocale(payload.tabletLocale || {});
        noticeRoot.textContent = t('loading', 'Tablet wird geladen.');
    }

    if (message.type === 'tablet:visibility') {
        setVisible(payload.visible);
    }

    if (message.type === 'tablet:apps') {
        state.apps = Array.isArray(payload.apps) ? payload.apps : [];
        noticeRoot.textContent = t('refreshed', 'Tablet wurde aktualisiert.');
        renderApps();
    }

    if (message.type === 'tablet:notice') {
        noticeRoot.textContent = payload.text || t('unavailableText', 'Diese App ist vorgemerkt, aber noch nicht freigeschaltet.');
    }
});

closeButton.addEventListener('click', () => postNui('nexaTabletClose'));
refreshButton.addEventListener('click', () => postNui('nexaTabletRefresh'));

postNui('nexaTabletReady');
