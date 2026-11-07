// The Phone app page. It runs inside city_phone: the phone sends the context (theme, language, font) and our client
// sends updates (a call starting or ending); data comes from our resource's callbacks.
import { renderCall } from './callscreen.js';
import { contacts, closeSheet, setRefresh } from './contacts.js';
import { state, call, loadTexts, setLanguage, t } from './lib.js';
import { favorites, recents, keypad } from './tabs.js';

const TABS = { favorites, recents, contacts, keypad };
const search = document.createElement('input');
search.className = 'search';
search.addEventListener('input', () => render());

function render() {
    const view = TABS[state.tab];
    document.getElementById('content').replaceChildren(...view(render, search).flat().filter(Boolean));

    for (const tab of document.querySelectorAll('#tabbar button')) {
        tab.classList.toggle('tab--on', tab.dataset.tab === state.tab);
    }
}

function translate() {
    for (const node of document.querySelectorAll('[data-text]')) node.textContent = t(node.dataset.text);
    search.placeholder = t('contacts.search');
}

async function refresh() {
    const result = await call('data');
    if (!result.ok) return;

    const data = result.result;
    state.myNumber = data.number;
    state.contacts = data.contacts || [];
    state.recents = data.recents || [];
    state.blocked = data.blocked || [];
    state.call = data.call || null;

    render();
    renderCall();
}

function applyContext(context) {
    const root = document.documentElement;
    root.dataset.theme = context.theme === 'light' ? 'light' : 'dark';
    root.style.setProperty('--font', context.font || 'Inter');

    for (const [name, value] of Object.entries(context.colors || {})) {
        if (value) root.style.setProperty(`--${name}`, value);
    }

    setLanguage(context.language);
    translate();
    render();
    renderCall();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') applyContext(message);

    if (message.type === 'city_phone:message') {
        const data = message.data || {};

        if (data.action === 'call') {
            state.call = data.call || null;
            renderCall();
            // A call ended: the recents changed
            if (!state.call) refresh();
        }

        if (data.action === 'refresh') refresh();
    }
});

for (const tab of document.querySelectorAll('#tabbar button')) {
    tab.addEventListener('click', () => {
        state.tab = tab.dataset.tab;
        closeSheet();
        render();
        if (state.tab === 'recents') refresh();
    });
}

async function start() {
    await loadTexts();
    setRefresh(refresh);
    translate();
    render();
    await refresh();
}

start();
