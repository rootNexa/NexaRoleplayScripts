const app = document.getElementById('app');
const content = document.getElementById('content');
const title = document.getElementById('title');
let snapshot = { accounts: [], transactions: [], invoices: [] };
let tab = 'accounts';

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).then(r => r.json()).catch(() => null);
const money = account => `${account.account_number || account.id} · ${account.balance || 0} ${account.currency || 'USD'}`;

function render() {
    title.textContent = tab === 'accounts' ? 'Konten' : tab === 'invoices' ? 'Rechnungen' : 'Verlauf';
    const rows = snapshot[tab] || [];
    content.innerHTML = rows.length ? `<table><tbody>${rows.map(row => `<tr><td>${row.label || row.title || row.reason || money(row)}</td><td>${row.status || row.account_type || ''}</td></tr>`).join('')}</tbody></table>` : '<p class="empty">Keine Eintraege.</p>';
}

window.addEventListener('message', event => {
    const { type, payload } = event.data || {};
    if (type === 'banking:visibility') app.classList.toggle('hidden', !payload.visible);
    if (type === 'banking:snapshot') { snapshot = payload || snapshot; render(); }
});

document.querySelectorAll('[data-tab]').forEach(button => button.addEventListener('click', () => { tab = button.dataset.tab; render(); }));
document.getElementById('close').addEventListener('click', () => post('bankingClose'));
document.getElementById('refresh').addEventListener('click', async () => { const result = await post('bankingRefresh'); if (result && result.data) snapshot = result.data; render(); });
