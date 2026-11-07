// Home: the accounts as cards to swipe through, the chosen account's balance and its statement
import { state, bank, t, h, button, icon, money, reasonText, when, navBar } from './lib.js';

const PAGE = 0;

export async function loadHistory(render) {
    if (!state.account) return;

    const reply = await bank('history', state.account.id, PAGE, null);
    state.history = reply.ok ? reply.entries || [] : [];
    render();
}

function accountCard(account, render) {
    const node = button(`account account--${account.type}${state.account?.id === account.id ? ' account--on' : ''}`, null, () => {
        state.account = account;
        render();
        loadHistory(render);
    },
        h('span', 'account__label', account.label || t(`type.${account.type}`)),
        h('span', 'account__balance', money(account.balance)),
        h('span', 'account__number', account.number),
        account.frozen ? h('span', 'account__frozen', t('frozen')) : null,
    );
    return node;
}

function entry(item) {
    const incoming = item.delta > 0;

    return h('div', 'k-row entry', null,
        h('span', `entry__icon${incoming ? ' entry__icon--in' : ''}`, null, icon(incoming ? 'send' : 'send')),
        h('span', 'entry__main', null, h('span', 'entry__reason', reasonText(item.reason)), h('span', 'entry__when', when(item.time))),
        h('span', `entry__amount${incoming ? ' entry__amount--in' : ''}`, `${incoming ? '+' : ''}${money(item.delta)}`),
    );
}

export function home(render) {
    if (!state.account && state.accounts.length) state.account = state.accounts[0];

    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('title')),
        state.accounts.length
            ? h('div', 'accounts', null, state.accounts.map((account) => accountCard(account, render)))
            : h('div', 'k-empty', null, icon('wallet'), h('span', '', t('noAccount'))),
        state.account ? h('div', 'k-group__label', t('statement')) : null,
        state.account
            ? (state.history.length ? h('div', 'k-group', null, state.history.map(entry)) : h('p', 'muted', t('noEntries')))
            : null,
    ];
}
