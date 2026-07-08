const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nexa-identity';

const app = document.getElementById('app');
const subtitle = document.getElementById('subtitle');
const errorBox = document.getElementById('error');
const charactersView = document.getElementById('charactersView');
const createView = document.getElementById('createView');
const charactersContainer = document.getElementById('characters');
const createForm = document.getElementById('createForm');
const createButton = document.getElementById('createButton');
const closeButton = document.getElementById('closeButton');
const loading = document.getElementById('loading');

let busy = false;

async function post(name, data = {}) {
    const response = await fetch(`https://${resourceName}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    });

    const text = await response.text();

    if (!text) {
        return {
            ok: response.ok,
            status: response.status
        };
    }

    try {
        return JSON.parse(text);
    } catch (error) {
        console.error('[nexa-identity] failed to parse NUI response', {
            name,
            text,
            error
        });
        return {
            ok: false,
            status: response.status,
            error: {
                code: 'INVALID_NUI_RESPONSE',
                message: text
            }
        };
    }
}
}

function setBusy(value) {
    busy = value === true;
    loading.classList.toggle('hidden', !busy);
    createButton.disabled = busy;
    document.querySelectorAll('.select-button').forEach((button) => {
        button.disabled = busy;
    });
}

function formatError(payload) {
    if (!payload) {
        return 'UNKNOWN_ERROR: Action failed.';
    }

    const parts = [];

    if (payload.code) {
        parts.push(payload.code);
    }

    if (payload.message) {
        parts.push(payload.message);
    }

    if (payload.details) {
        parts.push(JSON.stringify(payload.details));
    }

    return parts.length > 0 ? parts.join(' - ') : 'UNKNOWN_ERROR: Action failed.';
}

function showError(payload) {
    console.error('[nexa-identity] error', payload);
    errorBox.textContent = formatError(payload);
    errorBox.classList.remove('hidden');
    setBusy(false);
}

function clearError() {
    errorBox.textContent = '';
    errorBox.classList.add('hidden');
}

function renderCharacters(characters) {
    charactersContainer.innerHTML = '';

    characters.forEach((character) => {
        const row = document.createElement('article');
        row.className = 'character';

        const detail = document.createElement('div');
        const name = document.createElement('strong');
        name.textContent = `${character.firstName || 'Unknown'} ${character.lastName || ''}`.trim();

        const meta = document.createElement('span');
        meta.textContent = [character.birthdate, character.gender].filter(Boolean).join(' - ');

        const button = document.createElement('button');
        button.className = 'select-button';
        button.type = 'button';
        button.textContent = 'Select';
        button.addEventListener('click', () => {
            if (busy) {
                return;
            }

            clearError();
            setBusy(true);
            post('nexa_identity:selectCharacter', {
                id: character.id
            }).then((response) => {
                console.log('[nexa-identity] selectCharacter NUI response', response);
                if (response && response.ok === false) {
                    showError(response.error || response);
                }
            }).catch((error) => {
                showError({
                    code: 'NUI_FETCH_FAILED',
                    message: error.message
                });
            });
        });

        detail.append(name, meta);
        row.append(detail, button);
        charactersContainer.append(row);
    });
}

function open(payload) {
    clearError();
    setBusy(false);
    app.classList.remove('hidden');

    const characters = Array.isArray(payload.characters) ? payload.characters : [];
    const hasCharacters = characters.length > 0;

    subtitle.textContent = hasCharacters ? 'Choose your character' : 'Create your first character';
    charactersView.classList.toggle('hidden', !hasCharacters);
    createView.classList.toggle('hidden', hasCharacters);
    renderCharacters(characters);
}

function close() {
    app.classList.add('hidden');
    clearError();
    setBusy(false);
}

createForm.addEventListener('submit', (event) => {
    event.preventDefault();

    if (busy) {
        return;
    }

    const formData = new FormData(createForm);

    clearError();
    setBusy(true);
    post('nexa_identity:createCharacter', {
        firstName: formData.get('firstName'),
        lastName: formData.get('lastName'),
        birthdate: formData.get('birthdate'),
        gender: formData.get('gender') || 'unknown'
    }).then((response) => {
        console.log('[nexa-identity] createCharacter NUI response', response);
        if (response && response.ok === false) {
            showError(response.error || response);
        }
    }).catch((error) => {
        showError({
            code: 'NUI_FETCH_FAILED',
            message: error.message
        });
    });
});

closeButton.addEventListener('click', () => {
    post('nexa_identity:close');
});

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'open') {
        open(message.payload || {});
        return;
    }

    if (message.type === 'close') {
        close();
        return;
    }

    if (message.type === 'error') {
        showError(message.payload);
    }
});
