// The "Give money" card on a player's page (admins): cash or bank, an amount and a reason, then a review step.
// The server checks everything again and city_economy caps it per character per hour.

import { el, L, money } from './ui.js';
import { app, can } from './main.js';

const QUICK = [1000, 10000, 100000];

export function moneyCard(player, act) {
    if (!can('giveMoney')) return null;

    const max = app.maxGiveMoney || 0;
    const card = el('div', { class: 'card form' });
    let state = { account: 'bank', amount: 0, reason: '', review: false };

    const valid = () => Number.isInteger(state.amount) && state.amount >= 1 && state.amount <= max && state.reason.trim().length >= 3;

    const draw = () => {
        if (state.review) {
            card.replaceChildren(
                el('strong', { text: L('ui_give_money') }),
                el('div', { class: 'change-summary' },
                    el('strong', { class: 'to', text: `+${money(state.amount)}` }),
                    el('span', { text: L(`ui_to_${state.account}`) }),
                    el('span', { class: 'muted', text: `· ${state.reason.trim()}` })),
                el('div', { class: 'editor-buttons' },
                    el('button', { class: 'kit-btn', text: L('ui_back'), onclick: () => {
                        state.review = false;
                        draw();
                    } }),
                    el('span', { class: 'spacer' }),
                    el('button', { class: 'kit-btn accent', text: L('ui_confirm'), onclick: act('giveMoney', {
                        account: state.account, amount: state.amount, reason: state.reason.trim(),
                    }, L('ui_money_given')) })),
            );
            return;
        }

        const amount = el('input', { class: 'field', type: 'number', min: '1', max: String(max), step: '1', value: state.amount ? String(state.amount) : '', placeholder: L('ui_amount'), 'aria-label': L('ui_amount') });
        const reason = el('input', { class: 'field', type: 'text', maxlength: '100', value: state.reason, placeholder: L('ui_reason'), 'aria-label': L('ui_reason') });
        const review = el('button', { class: 'kit-btn accent', text: L('ui_review'), disabled: !valid(), onclick: () => {
            state.review = true;
            draw();
        } });

        const update = () => {
            const n = Number(amount.value);
            state.amount = Number.isInteger(n) ? n : 0;
            state.reason = reason.value;
            review.disabled = !valid();
        };
        amount.addEventListener('input', update);
        reason.addEventListener('input', update);

        const accountChip = (account) => el('button', { class: `grade${state.account === account ? ' on' : ''}`, onclick: () => {
            state.account = account;
            draw();
        } }, `${L(`ui_${account}`)} · ${money(player[account])}`);

        card.replaceChildren(
            el('strong', { text: L('ui_give_money') }),
            el('div', { class: 'chips' }, accountChip('bank'), accountChip('cash')),
            amount,
            el('div', { class: 'chips' }, QUICK.filter((n) => n <= max).map((n) => el('button', { class: 'grade', onclick: () => {
                amount.value = String(Math.min(max, (state.amount || 0) + n));
                update();
            } }, `+${money(n)}`))),
            reason,
            el('div', { class: 'editor-buttons' }, el('span', { class: 'spacer' }), review),
        );
    };

    draw();

    return card;
}
