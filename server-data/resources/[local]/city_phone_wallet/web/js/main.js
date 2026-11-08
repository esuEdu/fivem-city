// The Wallet page: Home (accounts + statement), Pix and Cards, plus the question when a card purchase needs the owner's
// approval. Runs inside city_phone; everything goes to city_bank through our client.
import { cards, reloadCards } from './cards.js';
import { home, loadHistory } from './home.js';
import {
    state, bank, local, loadTexts, setLanguage, t, h, button, icon, money, toast, openSheet, closeSheet, applyContext,
} from './lib.js';
import { pix } from './pix.js';

const TABS = [['home', 'wallet', home], ['pix', 'send', pix], ['cards', 'card', cards]];

function render() {
    const view = TABS.find(([id]) => id === state.tab)[2];
    document.getElementById('content').replaceChildren(...view(render).flat().filter(Boolean));
    document.getElementById('tabbar').replaceChildren(...TABS.map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        state.tab = id;
        closeSheet();
        render();
        if (id === 'cards') reloadCards(render);
    }, icon(iconName), h('span', '', t(`tabs.${id}`)))));
}

async function refresh() {
    const reply = await bank('accounts');
    if (reply.ok) {
        state.accounts = reply.accounts || [];
        state.account = state.accounts.find((a) => a.id === state.account?.id) || state.accounts[0] || null;
    } else if (reply.error === 'no_phone') {
        toast(t('error.no_phone'));
    }

    render();
    loadHistory(render);
}

let countdown = null;

// "Purchase of $X at Y with card 1234: approve?" with the seconds left
function approval(request) {
    if (!request) return;

    let left = Math.max(0, Number(request.seconds) || 60);
    const timer = h('div', 'approval__timer', t('approval.left', left));

    const answer = async (accept) => {
        clearInterval(countdown);
        closeSheet();
        const reply = await bank('approve', request.id, accept);
        toast(reply.ok ? t(accept ? 'approval.approved' : 'approval.declined') : t('approval.expired'));
        refresh();
    };

    openSheet(
        h('div', 'approval', null,
            h('div', 'approval__icon', null, icon('card')),
            h('h1', 'approval__title', t('approval.title')),
            h('div', 'approval__amount', money(request.amount)),
            h('div', 'approval__merchant', t('approval.at', request.merchant || '?', request.last4 || '????')),
            h('p', 'muted small', t('approval.hint')),
            timer,
            button('k-button', t('approval.approve'), () => answer(true)),
            button('k-button danger-button', t('approval.decline'), () => answer(false)),
        ),
    );

    clearInterval(countdown);
    countdown = setInterval(() => {
        left -= 1;
        timer.textContent = t('approval.left', Math.max(0, left));
        if (left <= 0) {
            clearInterval(countdown);
            closeSheet();
            toast(t('approval.expired'));
        }
    }, 1000);
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        setLanguage(message.language);
        render();
    }

    if (message.type === 'city_phone:message' && message.data?.action === 'approval') approval(message.data.request);
});

document.addEventListener('wallet:refresh', refresh);

async function start() {
    await loadTexts();
    render();
    await refresh();

    const pending = await local('pending');
    if (pending.ok && pending.result) approval(pending.result);
}

start();
