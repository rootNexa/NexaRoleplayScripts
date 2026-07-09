const state = {
    visible: false,
    activeTab: 'overview',
    locale: {},
    modules: [],
    snapshot: {},
    searchResult: []
};

const root = document.getElementById('mdt');
const navRoot = document.getElementById('mdtNav');
const panelRoot = document.getElementById('mdtPanel');
const noticeRoot = document.getElementById('mdtNotice');
const closeButton = document.getElementById('mdtClose');
const refreshButton = document.getElementById('mdtRefresh');
const searchForm = document.getElementById('mdtSearch');

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

    document.querySelectorAll('[data-i18n-placeholder]').forEach((element) => {
        const key = element.getAttribute('data-i18n-placeholder');
        element.setAttribute('placeholder', t(key, element.getAttribute('placeholder') || ''));
    });
}

function card(title, body, detail = '') {
    const element = document.createElement('article');
    element.className = 'mdt-card';

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

function renderList(items, mapItem) {
    const list = Array.isArray(items) ? items : [];

    if (list.length === 0) {
        panelRoot.append(card(t('empty', 'Keine Eintraege vorhanden.'), ''));
        return;
    }

    list.forEach((item) => panelRoot.append(mapItem(item)));
}

function renderOverview(data) {
    const typeLabel = data.mdtType ? data.mdtType.toUpperCase() : 'MDT';
    panelRoot.append(card(typeLabel, `${state.modules.length} Module`, t('tabOverview', 'Uebersicht')));

    state.modules.filter((module) => module.id !== 'overview').forEach((module) => {
        const items = data[module.id];
        panelRoot.append(card(module.label, String(Array.isArray(items) ? items.length : 0), module.id));
    });
}

function renderNav(modules) {
    const nextModules = Array.isArray(modules) && modules.length > 0 ? modules : [
        {
            id: 'overview',
            label: t('tabOverview', 'Uebersicht')
        }
    ];

    state.modules = nextModules;
    navRoot.replaceChildren();

    if (!state.modules.some((module) => module.id === state.activeTab)) {
        state.activeTab = 'overview';
    }

    state.modules.forEach((module) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.dataset.tab = module.id;
        button.textContent = module.label || module.id;
        button.classList.toggle('is-active', module.id === state.activeTab);
        navRoot.append(button);
    });
}

function render() {
    const data = state.snapshot || {};
    panelRoot.innerHTML = '';
    searchForm.classList.toggle('is-hidden', state.activeTab !== 'persons');

    if (state.activeTab === 'overview') {
        renderOverview(data);
    }

    if (state.activeTab === 'persons') {
        renderList(state.searchResult.length > 0 ? state.searchResult : data.persons, (item) => card(item.name, item.note, item.id));
    }

    if (state.activeTab === 'vehicles') {
        panelRoot.append(card(t('tabVehicles', 'Fahrzeuge'), t('readOnlyVehicle', 'Fahrzeuganzeige ist vorbereitet und read-only. Es gibt keine Fahrzeuglogik.')));
        renderList(data.vehicles, (item) => card(item.plate, item.model, item.status));
    }

    if (state.activeTab === 'records') {
        renderList(data.records, (item) => card(item.title, item.summary, item.status));
    }

    if (state.activeTab === 'warrants') {
        renderList(data.warrants, (item) => card(item.title, item.subject, item.status));
    }

    if (state.activeTab === 'fines') {
        renderList(data.fines, (item) => card(item.title, item.status, item.amount));
    }

    if (state.activeTab === 'reports') {
        renderList(data.reports, (item) => card(item.title, item.summary, item.status));
    }

    if (state.activeTab === 'evidence') {
        panelRoot.append(card(t('tabEvidence', 'Beweise'), t('readOnlyEvidence', 'Beweisuebersicht ist vorbereitet und read-only. Es gibt kein Evidence-System.')));
        renderList(data.evidence, (item) => card(item.title, item.summary, item.status));
    }

    if (state.activeTab === 'dispatch') {
        panelRoot.append(card(t('tabDispatch', 'Einsaetze'), t('dispatchReadOnly', 'Dispatch-Daten werden nur ueber die bestehende API angezeigt.')));
        renderList(data.dispatch, (item) => card(item.call_number || item.id, item.description || item.category, item.status));
    }

    if (![
        'overview',
        'persons',
        'vehicles',
        'records',
        'warrants',
        'fines',
        'reports',
        'evidence',
        'dispatch'
    ].includes(state.activeTab)) {
        const module = state.modules.find((item) => item.id === state.activeTab) || {
            id: state.activeTab,
            label: state.activeTab
        };

        renderList(data[module.id], (item) => card(item.title || item.name || module.label, item.summary || item.description || '', item.status || ''));
    }
}

function setVisible(visible) {
    state.visible = visible === true;
    root.classList.toggle('is-hidden', !state.visible);
}

navRoot.addEventListener('click', (event) => {
    const button = event.target.closest('button[data-tab]');

    if (!button) {
        return;
    }

    state.activeTab = button.dataset.tab;
    navRoot.querySelectorAll('button').forEach((item) => item.classList.toggle('is-active', item === button));
    render();
});

searchForm.addEventListener('submit', (event) => {
    event.preventDefault();
    postNui('nexaMdtSearchPerson', {
        query: searchForm.query.value
    });
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    const payload = message.payload || {};

    if (message.type === 'mdt:init') {
        applyLocale(payload.mdtLocale || {});
        noticeRoot.textContent = t('loading', 'MDT wird geladen.');
    }

    if (message.type === 'mdt:visibility') {
        setVisible(payload.visible);
    }

    if (message.type === 'mdt:snapshot') {
        state.snapshot = payload || {};
        renderNav(state.snapshot.modules);
        state.searchResult = [];
        noticeRoot.textContent = t('refresh', 'Aktualisieren');
        render();
    }

    if (message.type === 'mdt:searchResult') {
        state.searchResult = Array.isArray(payload.persons) ? payload.persons : [];
        state.activeTab = 'persons';
        render();
    }

    if (message.type === 'mdt:notice') {
        noticeRoot.textContent = payload.text || '';
    }
});

closeButton.addEventListener('click', () => postNui('nexaMdtClose'));
refreshButton.addEventListener('click', () => postNui('nexaMdtRefresh'));

postNui('nexaMdtReady');
