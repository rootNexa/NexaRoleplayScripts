(function () {
    const app = document.getElementById('app');
    const nav = document.getElementById('sectionNav');
    const title = document.getElementById('sectionTitle');
    const dashboard = document.getElementById('dashboard');
    const closeButton = document.getElementById('closeButton');
    const refreshButton = document.getElementById('refreshButton');
    let currentSection = 'overview';
    let sections = [];

    function post(name, payload) {
        fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        });
    }

    function label(value) {
        return String(value || 'overview').replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
    }

    function renderNav() {
        nav.replaceChildren();
        sections.forEach((section) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.textContent = label(section);
            button.dataset.active = section === currentSection ? 'true' : 'false';
            button.addEventListener('click', () => post('adminSection', { section }));
            nav.append(button);
        });
    }

    function responseData(response) {
        if (!response) {
            return null;
        }

        if (response.ok === true && response.data !== undefined) {
            return response.data;
        }

        if (response.success === true && response.data !== undefined) {
            return response.data;
        }

        return response;
    }

    function metricCard(titleText, value, description) {
        const card = document.createElement('article');
        card.className = 'nexa-admin-card';
        const heading = document.createElement('h3');
        heading.textContent = titleText;
        const metric = document.createElement('strong');
        metric.textContent = String(value);
        const text = document.createElement('p');
        text.textContent = description || '';
        card.append(heading, metric, text);
        return card;
    }

    function renderData(payload) {
        const readiness = responseData(payload.readiness) || {};
        const health = responseData(payload.health) || {};
        const creators = responseData(payload.creators) || {};
        const resources = Array.isArray(health.resources) ? health.resources : [];
        const creatorList = Array.isArray(creators.creators) ? creators.creators : [];

        dashboard.replaceChildren(
            metricCard('Readiness', readiness.stage || readiness.status || 'unknown', 'GP18 alpha and beta gate.'),
            metricCard('Resources', resources.length, 'Tracked runtime dependencies.'),
            metricCard('Creators', creatorList.length, 'Registered creator surfaces.'),
            metricCard('Section', label(currentSection), 'Current admin workspace.')
        );
    }

    window.addEventListener('message', (event) => {
        const message = event.data || {};
        const payload = message.payload || {};

        if (message.type === 'admin:open') {
            currentSection = payload.section || currentSection;
            sections = Array.isArray(payload.sections) ? payload.sections : sections;
            title.textContent = label(currentSection);
            renderNav();
            app.hidden = false;
        }

        if (message.type === 'admin:close') {
            app.hidden = true;
        }

        if (message.type === 'admin:data') {
            renderData(payload);
        }
    });

    closeButton.addEventListener('click', () => post('adminClose'));
    refreshButton.addEventListener('click', () => post('adminRefresh'));

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !app.hidden) {
            post('adminClose');
        }
    });
}());
