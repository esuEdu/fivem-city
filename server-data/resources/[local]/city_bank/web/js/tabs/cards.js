import { call, h, label, money, dateTime, panel, kpi, table, chip, button, iconButton, field, input, select, whole, modal, report, actions } from '../util.js';

const LIMITS = ['debitDay', 'creditDay', 'atmDay', 'contactlessTx', 'contactlessDay'];
const STATUS = { active: 'good', locked: 'warn', blocked: 'bad' };

function pinInput(placeholder) {
    return input({ type: 'password', inputMode: 'numeric', maxLength: 4, placeholder, className: 'input input--pin' });
}

async function limitsDialog(card, ctx) {
    const inputs = {};
    const rows = LIMITS.map((key) => {
        inputs[key] = input({ type: 'number', min: 0, max: card.ceilings[key], value: card.limits[key] });
        return field(label('limit_with_max', label(`limit_${key}`), money(card.ceilings[key])), inputs[key]);
    });

    await modal(label('limits_title', card.last4), h('div', { className: 'form' },
        h('p', { className: 'muted', text: label('limits_delay') }),
        h('div', { className: 'form__grid' }, rows)), [{
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

    await modal(label('change_pin'), h('div', { className: 'form form--row' }, field(label('new_pin'), pin), field(label('confirm_pin'), again)), [{
        text: label('save'),
        onClick: async (close) => {
            if (pin.value !== again.value) return report({ ok: false, error: 'pin_mismatch' });
            if (report(await call('cardPin', card.id, pin.value), 'done')) close();
        },
    }]);
}

async function stolenDialog(card, ctx) {
    await modal(label('report_stolen'), h('p', { text: label('report_stolen_text', card.last4) }), [{
        text: label('report_stolen'), kind: 'danger',
        onClick: async (close) => { if (report(await call('blockCard', card.id), 'done')) { close(); ctx.refresh(); } },
    }]);
}

async function issueDialog(data, ctx) {
    const account = select(data.issuable.map((a) => ({ value: a.id, label: `${a.label} · ${a.number}` })), data.issuable[0].id);
    const pin = pinInput(label('pin'));
    const again = pinInput(label('confirm_pin'));

    await modal(label('new_card'), h('div', { className: 'form' },
        h('p', { className: 'muted', text: label('card_fee', money(data.fees.first), money(data.fees.replace)) }),
        field(label('card_account'), account),
        h('div', { className: 'form form--row' }, field(label('pin'), pin), field(label('confirm_pin'), again))), [{
        text: label('issue_card'),
        onClick: async (close) => {
            if (pin.value !== again.value) return report({ ok: false, error: 'pin_mismatch' });
            if (report(await call('issueCard', Number(account.value), pin.value), 'card_issued')) { close(); ctx.refresh(); }
        },
    }]);
}

function cardName(card) {
    return h('span', { className: 'cardname' }, h('i', { className: 'cardname__chip' }), h('span', { className: 'num', text: `•••• ${card.last4}` }));
}

function limitCell(card, key) {
    return h('span', { className: 'num', title: label('limit_with_max', label(`limit_${key}`), money(card.ceilings[key])), text: money(card.limits[key]) });
}

export default async function render(container, ctx) {
    const data = await call('cards');

    if (!report(data)) return;

    const active = data.cards.filter((c) => c.status === 'active').length;

    container.append(
        h('div', { className: 'kpis' },
            kpi(label('tier'), data.tier, label('score_is', data.score), 'accent'),
            kpi(label('cards_active'), String(active), label('cards_total', data.cards.length)),
            kpi(label('fee_first'), money(data.fees.first), label('fee_replace', money(data.fees.replace)))),

        panel(label('nav_cards'), table([
            { title: label('col_card'), render: cardName },
            { title: label('col_holder'), render: (c) => c.holder, className: 'grow' },
            { title: label('card_account'), render: (c) => c.account, className: 'muted' },
            { title: label('col_status'), render: (c) => [chip(label(`card_${c.status}`), STATUS[c.status]), c.pending ? chip(label('limits_pending_short'), 'warn') : null] },
            { title: label('contactless'), render: (c) => (c.contactless ? chip(label('on'), 'good') : chip(label('off'))) },
            { title: label('limit_debitDay'), render: (c) => limitCell(c, 'debitDay'), align: 'right' },
            { title: label('limit_atmDay'), render: (c) => limitCell(c, 'atmDay'), align: 'right' },
            { title: label('limit_creditDay'), render: (c) => limitCell(c, 'creditDay'), align: 'right' },
            {
                title: '', align: 'right',
                render: (c) => actions(
                    c.status === 'active' ? iconButton('sliders', label('limits'), () => limitsDialog(c, ctx)) : null,
                    c.status === 'active' ? iconButton('wifi', label(c.contactless ? 'contactless_off' : 'contactless_on'), async () => {
                        if (report(await call('cardContactless', c.id, !c.contactless), 'done')) ctx.refresh();
                    }) : null,
                    c.mine && c.status !== 'blocked' ? iconButton('key', label('change_pin'), () => pinDialog(c)) : null,
                    c.mine && c.status === 'locked' ? iconButton('unlock', label('unlock'), async () => {
                        if (report(await call('unlockCard', c.id), 'done')) ctx.refresh();
                    }, 'good') : null,
                    c.status !== 'blocked' ? iconButton('block', label('report_stolen'), () => stolenDialog(c, ctx), 'bad') : null),
            },
        ], data.cards, 'no_cards'), data.issuable.length ? button(label('new_card'), () => issueDialog(data, ctx), 'primary', false, 'plus') : null),

        data.cards.some((c) => c.pending) ? h('p', { className: 'notice', text: label('limits_pending', dateTime(Math.max(...data.cards.map((c) => c.pendingAt || 0)))) }) : null,
    );
}
