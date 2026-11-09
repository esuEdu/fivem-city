import { state, post, applyTheme, label, h, icon, iconButton } from './util.js';
import { setupIdentity, resetIdentity } from './identity.js';
import { openAtm } from './atm.js';
import { openPos } from './pos.js';
import dashboard from './tabs/dashboard.js';
import accounts from './tabs/accounts.js';
import cards from './tabs/cards.js';
import transfers from './tabs/transfers.js';
import loans from './tabs/loans.js';
import billing from './tabs/billing.js';
import history from './tabs/history.js';
import staff from './tabs/staff.js';

const TABS = [
    { id: 'dashboard', render: dashboard },
    { id: 'accounts', render: accounts },
    { id: 'cards', render: cards },
    { id: 'transfers', render: transfers },
    { id: 'loans', render: loans, feature: 'loans' },
    { id: 'billing', render: billing },
    { id: 'history', render: history },
    { id: 'staff', render: staff, staffOnly: true },
];

const $ = (id) => document.getElementById(id);

const bank = { data: null, tab: 'dashboard', staff: false, admin: false };
let renderId = 0;

function applyLabels() {
    for (const node of document.querySelectorAll('[data-label]')) node.textContent = label(node.dataset.label);
}

function show(view) {
    for (const id of ['identity', 'bank', 'atm', 'pos']) $(id).classList.toggle('hidden', id !== view);
    if (!view) $('modal').classList.add('hidden');
}

function renderNav() {
    const shown = (tab) => (!tab.staffOnly || bank.staff) && (!tab.feature || state.features[tab.feature] !== false);

    $('nav').replaceChildren(...TABS.filter(shown).map((tab) => h('button', {
        className: `side__item ${tab.id === bank.tab ? 'is-active' : ''}`,
        type: 'button',
        title: label(`nav_${tab.id}`),
        onClick: () => openTab(tab.id),
    }, icon(tab.id), h('span', { text: label(`nav_${tab.id}`) }))));
}

// Renders a tab; tabs call ctx.refresh() after an action to reload themselves
export async function openTab(id) {
    const tab = TABS.find((entry) => entry.id === id) || TABS[0];
    const container = $('tab');
    const mine = ++renderId;

    bank.tab = tab.id;
    renderNav();
    $('title').textContent = label(`nav_${tab.id}`);
    $('subtitle').textContent = label(`subtitle_${tab.id}`);
    $('topbar-tools').replaceChildren(iconButton('history', label('refresh'), () => openTab(tab.id)));

    if (!container.firstChild) container.append(h('p', { className: 'empty', text: label('loading') }));

    const page = h('div', { className: 'page__inner' });

    // Tabs append optional parts (`cond ? node : null`); skip the empty ones instead of printing "null"
    page.append = (...nodes) => Element.prototype.append.apply(page, nodes.flat(Infinity).filter((node) => node !== null && node !== undefined && node !== false));

    const ctx = {
        bank,
        refresh: () => openTab(tab.id),
        openTab,
        openTeller: async () => {
            const reply = await post('openTeller');
            if (reply && reply.ok) openAtm({ cards: reply.cards, teller: true }, () => show('atm'), () => { show('bank'); openTab(bank.tab); });
        },
    };

    await tab.render(page, ctx);

    // A slower, older render must not replace a newer tab
    if (mine === renderId) container.replaceChildren(page);
}

export function showBank(data) {
    bank.data = data;
    bank.staff = Boolean(data.staff);
    bank.admin = Boolean(data.admin);
    bank.tab = 'dashboard';
    $('tab').replaceChildren();
    show('bank');
    openTab('dashboard');
}

setupIdentity({ onDone: (data) => showBank(data), onClose: () => post('close') });

$('brand-icon').append(icon('bank'));
$('bank-close').append(icon('close'));
$('bank-close').addEventListener('click', () => post('close'));

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (!$('modal').classList.contains('hidden')) return;
    post('close');
});

window.addEventListener('message', ({ data: message }) => {
    switch (message.action) {
        case 'setup':
            applyTheme(message.theme);
            state.labels = message.labels || {};
            state.currency = message.currency || '$';
            state.features = message.features || {};
            applyLabels();
            break;

        case 'open':
            if (message.view === 'bank') {
                $('branch').textContent = message.branch || '';

                if (message.data.fingerprint) {
                    showBank(message.data);
                } else {
                    resetIdentity();
                    show('identity');
                }
            } else if (message.view === 'atm') {
                openAtm(message, () => show('atm'));
            } else if (message.view === 'pos') {
                openPos(message, () => show('pos'));
            }
            break;

        case 'close':
            show(null);
            bank.data = null;
            break;
    }
});

post('ready');
