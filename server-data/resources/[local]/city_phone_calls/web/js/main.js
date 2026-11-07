// The Phone app page. It runs inside city_phone: the phone sends the context (theme, language, font) and our client
// sends updates (a call starting or ending); data comes from our resource's callbacks.
import { renderCall } from './callscreen.js';
import { contacts, closeSheet, setRefresh } from './contacts.js';
import { state, call, loadTexts, setLanguage, t, h, button, icon, applyContext } from './lib.js';
import { favorites, recents, keypad } from './tabs.js';

const TABS = [
    ['favorites', 'star', favorites],
    ['recents', 'clock', recents],
    ['contacts', 'person', contacts],
    ['keypad', 'keypad', keypad],
];

const search = document.createElement('input');
search.addEventListener('input', () => render());

function renderTabbar() {
    document.getElementById('tabbar').replaceChildren(...TABS.map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        state.tab = id;
        closeSheet();
        render();
        if (id === 'recents') refresh();
    }, icon(iconName), h('span', '', t(`tabs.${id}`)))));
}

function render() {
    const view = TABS.find(([id]) => id === state.tab)[2];
    search.placeholder = t('contacts.search');
    document.getElementById('content').replaceChildren(...view(render, search).flat().filter(Boolean));
    renderTabbar();
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

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        setLanguage(message.language);
        render();
        renderCall();
    }

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

async function start() {
    await loadTexts();
    setRefresh(refresh);
    render();
    await refresh();
}

start();
