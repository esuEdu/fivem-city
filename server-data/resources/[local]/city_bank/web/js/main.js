import { state, post, applyTheme, label, h } from './util.js';
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
    { id: 'loans', render: loans },
    { id: 'billing', render: billing },
    { id: 'history', render: history },
    { id: 'staff', render: staff, staffOnly: true },
];

const $ = (id) => document.getElementById(id);

const bank = { data: null, tab: 'dashboard', staff: false, admin: false };

function applyLabels() {
    for (const node of document.querySelectorAll('[data-label]')) node.textContent = label(node.dataset.label);
}

function show(view) {
    for (const id of ['identity', 'bank', 'atm', 'pos']) $(id).classList.toggle('hidden', id !== view);
    if (!view) $('modal').classList.add('hidden');
}

function renderNav() {
    const nav = $('nav');
    nav.replaceChildren();

    for (const tab of TABS) {
        if (tab.staffOnly && !bank.staff) continue;

        nav.append(h('button', {
            className: `nav__item ${tab.id === bank.tab ? 'nav__item--active' : ''}`,
            type: 'button',
            text: label(`nav_${tab.id}`),
            onClick: () => openTab(tab.id),
        }));
    }
}

// Renders a tab; tabs call ctx.refresh() after an action to reload themselves
export async function openTab(id) {
    const tab = TABS.find((entry) => entry.id === id) || TABS[0];
    const container = $('tab');

    bank.tab = tab.id;
    renderNav();
    $('title').textContent = label(`nav_${tab.id}`);
    $('subtitle').textContent = label(`subtitle_${tab.id}`);
    container.replaceChildren(h('p', { className: 'muted', text: label('loading') }));

    const ctx = {
        bank,
        refresh: () => openTab(tab.id),
        openTab,
        openTeller: async () => {
            const reply = await post('openTeller');
            if (reply && reply.ok) openAtm({ cards: reply.cards, teller: true }, () => show('atm'), () => { show('bank'); openTab(bank.tab); });
        },
    };

    await tab.render(container, ctx);
}

export function showBank(data) {
    bank.data = data;
    bank.staff = Boolean(data.staff);
    bank.admin = Boolean(data.admin);
    bank.tab = 'dashboard';
    show('bank');
    openTab('dashboard');
}

setupIdentity({ onDone: (data) => showBank(data), onClose: () => post('close') });

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
