import { call, h, label, money, dateTime, section, button, pill, field, input, whole, modal, report, empty } from '../util.js';
import { activityList } from './dashboard.js';

const LIMITS = ['debitDay', 'creditDay', 'atmDay', 'contactlessTx', 'contactlessDay'];

async function decide(loan, approve, ctx) {
    const note = input({ placeholder: label('decision_note'), maxLength: 120 });

    await modal(label(approve ? 'approve_loan' : 'deny_loan'), [
        h('p', { text: label('loan_summary', loan.name, money(loan.amount), loan.installments) }),
        field(label('decision_note'), note),
    ], [{
        text: label(approve ? 'approve' : 'deny'), kind: approve ? 'primary' : 'danger',
        onClick: async (close) => { if (report(await call('staffDecide', loan.id, approve, note.value.trim()), 'done')) { close(); ctx.refresh(); } },
    }]);
}

async function ceilingsDialog(card, reload) {
    const inputs = {};
    const rows = LIMITS.map((key) => {
        inputs[key] = input({ type: 'number', min: 0, value: card.ceilings[key] });
        return field(label(`limit_${key}`), inputs[key]);
    });

    await modal(label('ceilings_title', card.last4), [h('p', { className: 'muted', text: label('ceilings_hint') }), rows], [
        { text: label('reset'), kind: 'ghost', onClick: async (close) => { if (report(await call('staffCeilings', card.id, false), 'done')) { close(); reload(); } } },
        {
            text: label('save'),
            onClick: async (close) => {
                const values = Object.fromEntries(LIMITS.map((key) => [key, whole(inputs[key]) ?? 0]));
                if (report(await call('staffCeilings', card.id, values), 'done')) { close(); reload(); }
            },
        },
    ]);
}

function clientFile(client, reload) {
    return h('div', { className: 'stack' },
        h('dl', { className: 'facts' },
            h('div', {}, h('dt', { text: label('client') }), h('dd', { text: client.name })),
            h('div', {}, h('dt', { text: label('score') }), h('dd', { className: 'mono', text: `${client.score} · ${client.tier}` })),
            h('div', {}, h('dt', { text: label('overdue_days') }), h('dd', { text: String(client.overdueDays) }))),

        section(label('nav_accounts'), h('ul', { className: 'list' }, client.accounts.filter((a) => a.type !== 'cash').map((a) => h('li', { className: 'row' },
            h('div', { className: 'row__main' },
                h('span', { className: 'row__title', text: `${a.label} · ${a.display || ''}` }),
                h('span', { className: 'row__sub mono', text: money(a.balance) })),
            h('div', { className: 'row__actions' },
                a.frozen ? pill(label(`frozen_${a.frozen}`), 'danger') : null,
                a.frozen
                    ? button(label('unfreeze'), async () => { if (report(await call('staffFreeze', a.id, false), 'done')) reload(); })
                    : button(label('freeze_fraud'), async () => { if (report(await call('staffFreeze', a.id, 'fraud'), 'done')) reload(); }, 'danger')))))),

        section(label('nav_cards'), client.cards.length ? h('ul', { className: 'list' }, client.cards.map((card) => h('li', { className: 'row' },
            h('div', { className: 'row__main' },
                h('span', { className: 'row__title', text: `•••• ${card.last4}` }),
                h('span', { className: 'row__sub', text: `${label(`card_${card.status}`)}${card.custom ? ` · ${label('custom_ceilings')}` : ''}` })),
            button(label('ceilings'), () => ceilingsDialog(card, reload))))) : empty('no_cards')),

        section(label('your_bills'), client.bills.length ? h('ul', { className: 'list' }, client.bills.map((b) => h('li', { className: 'row' },
            h('span', { className: 'row__title', text: b.label }),
            h('span', { className: 'mono', text: money(b.amount - b.paid) }),
            pill(label(`bill_${b.status}`), b.status === 'overdue' ? 'danger' : 'warning')))) : empty('no_bills')),

        section(label('activity'), activityList(client.history)));
}

export default async function render(container, ctx) {
    const queue = await call('staffQueue');

    if (!report(queue)) return;

    const number = input({ placeholder: 'LS 0000 0000', maxLength: 14 });
    const fileBox = h('div');
    const loadClient = async () => {
        const reply = await call('staffClient', number.value.trim());
        if (report(reply)) fileBox.replaceChildren(clientFile(reply.client, loadClient));
    };

    const queueList = queue.queue.length ? h('ul', { className: 'list' }, queue.queue.map((loan) => h('li', { className: 'row' },
        h('div', { className: 'row__main' },
            h('span', { className: 'row__title', text: `${loan.name} · ${money(loan.amount)}` }),
            h('span', { className: 'row__sub', text: label('queue_line', loan.score, loan.tier, loan.installments, loan.overdueDays) }),
            loan.reason ? h('span', { className: 'row__sub', text: loan.reason } ) : null,
            h('span', { className: 'row__sub', text: dateTime(loan.created_at) })),
        h('div', { className: 'row__actions' },
            button(label('approve'), () => decide(loan, true, ctx), 'primary'),
            button(label('deny'), () => decide(loan, false, ctx), 'danger')),
    ))) : empty('queue_empty');

    const parts = [
        section(label('loan_queue'), queueList),
        section(label('client_lookup'), h('div', { className: 'inline' }, number, button(label('search'), loadClient, 'primary')), fileBox),
    ];

    if (ctx.bank.admin) {
        const bankers = await call('staffBankers');
        const id = input({ type: 'number', placeholder: label('server_id') });

        parts.push(section(label('bankers'),
            bankers.ok && bankers.bankers.length ? h('ul', { className: 'list' }, bankers.bankers.map((b) => h('li', { className: 'row' },
                h('div', { className: 'row__main' },
                    h('span', { className: 'row__title', text: b.name }),
                    h('span', { className: 'row__sub', text: label('added_by', b.added_by) })),
                button(label('remove'), async () => { if (report(await call('staffSetBanker', b.citizenid, false), 'done')) ctx.refresh(); }, 'danger')))) : empty('no_bankers'),
            h('div', { className: 'inline' }, id,
                button(label('add_banker'), async () => { if (report(await call('staffSetBanker', whole(id), true), 'done')) ctx.refresh(); }, 'primary'))));
    }

    container.replaceChildren(h('div', { className: 'stack' }, parts));
}
