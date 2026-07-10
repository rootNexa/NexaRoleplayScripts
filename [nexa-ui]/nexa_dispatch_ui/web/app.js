const app = document.getElementById('app');
const content = document.getElementById('content');
const title = document.getElementById('title');
let tab = 'calls';
let snapshot = { calls: [], units: [], history: [] };
const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).then(r => r.json()).catch(() => null);
function render() {
  title.textContent = tab === 'calls' ? 'Live Calls' : tab === 'units' ? 'Einheitenstatus' : 'Historie';
  const rows = snapshot[tab] || [];
  content.innerHTML = rows.length ? rows.map(call => `<article><strong>${call.call_type || call.unit_key || 'Eintrag'}</strong><span>${call.status || ''}</span><p>${call.description || call.label || ''}</p></article>`).join('') : '<p class="empty">Keine Daten.</p>';
}
window.addEventListener('message', event => { const { type, payload } = event.data || {}; if (type === 'dispatch:visibility') app.classList.toggle('hidden', !payload.visible); if (type === 'dispatch:snapshot') { snapshot = payload || snapshot; render(); } });
document.querySelectorAll('[data-tab]').forEach(button => button.addEventListener('click', () => { tab = button.dataset.tab; render(); }));
document.getElementById('close').addEventListener('click', () => post('dispatchClose'));
document.getElementById('refresh').addEventListener('click', async () => { const result = await post('dispatchRefresh'); if (result && result.data) snapshot = result.data; render(); });
