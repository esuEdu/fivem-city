import { call, h, label, money, dateTime, section, button, pill, field, input, select, whole, modal, report, empty } from '../util.js';

const LIMITS = ['debitDay', 'creditDay', 'atmDay', 'contactlessTx', 'contactlessDay'];

function pinInput(placeholder) {
    return input({ type: 'password', inputMode: 'numeric', maxLength: 4, placeholder });
}

async function limitsDialog(card, ctx) {
    const inputs = {};
    const rows = LIMITS.map((key) => {
        inputs[key] = input({ type: 'number', min: 0, max: card.ceilings[key], value: card.limits[key] });
        return field(label('limit_with_max', label(`limit_${key}`), money(card.ceilings[key])), inputs[key]);
    });

    await modal(label('limits_title', card.last4), [h('p', { className: 'muted', text: label('limits_delay') }), rows], [{
        text: label('save'),
        onClick: async (close) => {
            const values = Object.fromEntries(LIMITS.map((key) => [key, whole(inputs[key]) ?? 0]));
            if (report(await call('cardLimits', card.id, values), 'limits_saved')) { close(); ctx.refresh(); }
        },
    }]);
}

async function pinDialog(card) {
    const pin = pinInput('••••');
    const again = pinInput('••••');

    await modal(label('change_pin'), [field(label('new_pin'), pin), field(label('confirm_pin'), again)], [{
        text: label('save'),
        onClick: async (close) => {
            if (pin.value !== again.value) return report({ ok: false, error: 'pin_mismatch' });
            if (report(await call('cardPin', card.id, pin.value), 'done')) close();
        },
    }]);
}

function cardTile(card, ctx) {
    const statusKind = { active: 'success', locked: 'warning', blocked: 'danger' }[card.status];
    const actions = [];

    if (card.status === 'active') {
        actions.push(button(label('limits'), () => limitsDialog(card, ctx)));
        actions.push(button(label(card.contactless ? 'contactless_off' : 'contactless_on'), async () => {
            if (report(await call('cardContactless', card.id, !card.contactless), 'done')) ctx.refresh();
        }));
    }

    if (card.mine && card.status !== 'blocked') actions.push(button(label('change_pin'), () => pinDialog(card)));
    if (card.mine && card.status === 'locked') {
        actions.push(button(label('unlock'), async () => { if (report(await call('unlockCard', card.id), 'done')) ctx.refresh(); }, 'primary'));
    }
    if (card.status !== 'blocked') {
        actions.push(button(label('report_stolen'), async () => {
            await modal(label('report_stolen'), h('p', { text: label('report_stolen_text', card.last4) }), [{
                text: label('report_stolen'), kind: 'danger',
                onClick: async (close) => { if (report(await call('blockCard', card.id), 'done')) { close(); ctx.refresh(); } },
            }]);
        }, 'danger'));
    }

    return h('article', { className: `bank-card bank-card--${card.status}` },
        h('div', { className: 'bank-card__face' },
            h('span', { className: 'bank-card__chip' }),
            h('span', { className: 'bank-card__number mono', text: `•••• •••• •••• ${card.last4}` }),
            h('div', { className: 'bank-card__foot' },
                h('span', { text: card.holder }),
                h('span', { className: 'bank-card__account', text: card.account }))),
        h('div', { className: 'pills' },
            pill(label(`card_${card.status}`), statusKind),
            card.contactless ? pill(label('contactless')) : null,
            card.mine ? null : pill(label('member_card'))),
        h('dl', { className: 'facts facts--small' }, LIMITS.map((key) => h('div', {},
            h('dt', { text: label(`limit_${key}`) }),
            h('dd', { className: 'mono', text: `${money(card.limits[key])} / ${money(card.ceilings[key])}` })))),
        card.pending ? h('p', { className: 'notice', text: label('limits_pending', dateTime(card.pendingAt)) }) : null,
        h('div', { className: 'row__actions' }, actions));
}

export default async function render(container, ctx) {
    const data = await call('cards');

    if (!report(data)) return;

    const issue = [];

    if (data.issuable.length) {
        const account = select(data.issuable.map((a) => ({ value: a.id, label: `${a.label} · ${a.number}` })), data.issuable[0].id);
        const pin = pinInput(label('pin'));
        const again = pinInput(label('confirm_pin'));

        issue.push(section(label('new_card'),
            h('p', { className: 'muted', text: label('card_fee', money(data.fees.first), money(data.fees.replace)) }),
            h('div', { className: 'toolbar' },
                field(label('card_account'), account), field(label('pin'), pin), field(label('confirm_pin'), again),
                button(label('issue_card'), async () => {
                    if (pin.value !== again.value) return report({ ok: false, error: 'pin_mismatch' });
                    const reply = await call('issueCard', Number(account.value), pin.value);
                    if (report(reply, 'card_issued')) ctx.refresh();
                }, 'primary'))));
    }

    container.replaceChildren(
        h('p', { className: 'muted', text: label('cards_tier', data.tier, data.score) }),
        ...issue,
        data.cards.length ? h('div', { className: 'cards-grid' }, data.cards.map((card) => cardTile(card, ctx))) : empty('no_cards'),
    );
}
