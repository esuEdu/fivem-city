// Vault: the organization's money (anyone deposits from their bank, the leader withdraws) and a read-only list of
// the stash's items; moving items happens at the QG vault itself.
import { app, state } from './main.js';

const { el, L, run, heading, pill, icon, money, searchField, confirmButton } = window.WorkApp;

let filter = '';

function amountInput() {
    return el('input', { class: 'field', type: 'number', min: '1', placeholder: L('ui_amount_placeholder'), 'aria-label': L('ui_amount_placeholder') });
}

function moneyCard(balance) {
    const input = amountInput();

    const send = async (action, doneKey) => {
        const amount = Number(input.value);
        if (!Number.isInteger(amount) || amount < 1) return;

        if (await run(action, { amount }, L(doneKey, money(amount)))) app.go('vault');
    };

    return el('div', { class: 'card money-card' },
        el('span', { class: 'tile-icon gold' }, icon('money', 18, 2)),
        el('div', { class: 'who' }, el('strong', { text: L('ui_money') }), el('small', { class: 'muted', text: state.faction })),
        el('span', { class: 'balance', text: money(balance) }),
        el('div', { class: 'form-row' },
            input,
            el('button', { class: 'kit-btn tint', onclick: () => send('deposit', 'ui_deposited') }, L('ui_deposit')),
            state.boss
                ? confirmButton(L('ui_withdraw'), () => send('withdraw', 'ui_withdrawn'), 'kit-btn')
                : el('small', { class: 'muted', text: L('ui_withdraw_leader') })),
    );
}

export async function renderVault() {
    const response = await run('vault');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;
    const shown = filter ? data.items.filter((item) => item.label.toLowerCase().includes(filter)) : data.items;

    return el('div', { class: 'stack' },
        heading(L('ui_tab_vault'), pill(`${Math.round(data.weight / 1000)} / ${Math.round(data.maxWeight / 1000)} kg`),
            el('span', { class: 'spacer' }),
            searchField(L('ui_search_items'), (value) => {
                filter = value;
                app.go('vault');
            }, filter)),
        moneyCard(data.balance),
        el('div', { class: 'banner' }, icon('vault', 18, 2), el('span', { text: L('ui_vault_hint') })),
        el('div', { class: 'card flush' },
            el('div', { class: 'table-head item-cols' }, el('span'), el('span', { text: L('ui_item') }), el('span', { text: L('ui_count') })),
            shown.length ? shown.map((item) => el('div', { class: 'table-row item-cols' },
                el('img', { class: 'item-img', src: `https://cfx-nui-city_inventory/web/images/${item.image}`, alt: '' }),
                el('strong', { text: item.label }),
                el('strong', { class: 'value', text: `x${item.count}` }),
            )) : el('div', { class: 'table-row muted', text: filter ? L('ui_no_match') : L('ui_no_items') })),
    );
}
