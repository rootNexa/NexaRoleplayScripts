(function () {
    const hud = document.getElementById('hud');
    const fields = {
        health: document.getElementById('health'),
        armor: document.getElementById('armor'),
        voice: document.getElementById('voice'),
        job: document.getElementById('job'),
        business: document.getElementById('business'),
        money: document.getElementById('money'),
        speed: document.getElementById('speed')
    };
    const vehiclePanel = document.getElementById('vehiclePanel');
    let locale = {};

    function postReady() {
        fetch(`https://${GetParentResourceName()}/nexaHudReady`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify({})
        });
    }

    function text(value, fallback) {
        return typeof value === 'string' && value.trim() !== '' ? value : fallback;
    }

    function percent(value) {
        const number = Number(value);

        if (!Number.isFinite(number)) {
            return '0%';
        }

        return `${Math.max(0, Math.min(100, Math.round(number)))}%`;
    }

    function money(account) {
        if (!account) {
            return '-';
        }

        const amount = Number(account.balance || 0);
        const formatted = new Intl.NumberFormat('de-DE', {
            maximumFractionDigits: 0
        }).format(amount);

        return `${formatted} ${account.currency || 'USD'}`;
    }

    function applyLocale(payload) {
        locale = payload.hudLocale || locale;
        document.querySelectorAll('[data-i18n]').forEach((element) => {
            const key = element.dataset.i18n;
            element.textContent = text(locale[key], element.textContent);
        });
    }

    function applyVisibility(payload) {
        hud.hidden = payload.visible !== true;
    }

    function applySnapshot(payload) {
        const job = payload.job || {};
        const business = payload.business || {};

        fields.job.textContent = `${text(job.label, locale.noJob || 'Zivilist')} - ${text(job.grade, locale.noGrade || 'Ohne Rang')}`;
        fields.business.textContent = `${text(business.label, locale.noBusiness || 'Keine Firma')} - ${text(business.role, locale.noGrade || 'Ohne Rang')}`;
        fields.money.textContent = money(payload.account);
    }

    function applyStatus(payload) {
        fields.health.textContent = percent(payload.health);
        fields.armor.textContent = percent(payload.armor);
    }

    function applyVehicle(payload) {
        vehiclePanel.hidden = payload.inVehicle !== true;
        fields.speed.textContent = `${Math.max(0, Number(payload.speed || 0))} km/h`;
    }

    function applyVoice(payload) {
        const mode = text(payload.mode, 'Normal');
        const radio = payload.radio === true ? text(payload.radioLabel, locale.radio || 'Funk') : text(locale.radioUnavailable, 'Kein Funk');
        fields.voice.textContent = `${mode} / ${radio}`;
    }

    window.addEventListener('message', (event) => {
        const message = event.data || {};
        const payload = message.payload || {};

        if (message.type === 'hud:init') {
            applyLocale(payload);
        }

        if (message.type === 'hud:visibility') {
            applyVisibility(payload);
        }

        if (message.type === 'hud:snapshot') {
            applySnapshot(payload);
        }

        if (message.type === 'hud:status') {
            applyStatus(payload);
        }

        if (message.type === 'hud:vehicle') {
            applyVehicle(payload);
        }

        if (message.type === 'hud:voice') {
            applyVoice(payload);
        }
    });

    postReady();
}());
