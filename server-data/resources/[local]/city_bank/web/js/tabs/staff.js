import { call, h, label, money, dateTime, panel, kpi, table, chip, button, iconButton, field, input, whole, modal, report, actions, empty } from '../util.js';
import { activityTable } from './dashboard.js';

const LIMITS = ['debitDay', 'creditDay', 'atmDay', 'contactlessTx', 'contactlessDay'];

async function decide(loan, approve, ctx) {
    const note = input({ placeholder: label('decision_note'), maxLength: 120 });

    await modal(label(approve ? 'approve_loan' : 'deny_loan'), h('div', { className: 'form' },
        h('p', { text: label('loan_summary', loan.name, money(loan.amount), loan.installments) }),
        field(label('decision_note'), note)), [{
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

    await modal(label('ceilings_title', card.last4), h('div', { className: 'form' },
        h('p', { className: 'muted', text: label('ceilings_hint') }),
        h('div', { className: 'form__grid' }, rows)), [
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
        h('div', { className: 'kpis' },
            kpi(label('client'), client.name, client.citizenid, 'accent'),
            kpi(label('score'), String(client.score), client.tier),
            kpi(label('overdue_days'), String(client.overdueDays), label('bills_count', client.bills.length), client.overdueDays > 0 ? 'out' : '')),

        h('div', { className: 'grid grid--two' },
            panel(label('nav_accounts'), table([
                { title: label('col_name'), render: (a) => a.label, className: 'strong grow' },
                { title: label('account_number'), render: (a) => h('span', { className: 'num muted', text: a.display || '-' }) },
                { title: label('col_status'), render: (a) => (a.frozen ? chip(label(`frozen_${a.frozen}`), 'bad') : chip(label('status_active'), 'good')) },
                { title: label('col_balance'), render: (a) => h('span', { className: 'num', text: money(a.balance) }), align: 'right' },
                {
                    title: '', align: 'right',
                    render: (a) => (a.frozen
                        ? iconButton('unlock', label('unfreeze'), async () => { if (report(await call('staffFreeze', a.id, false), 'done')) reload(); }, 'good')
                        : iconButton('lock', label('freeze_fraud'), async () => { if (report(await call('staffFreeze', a.id, 'fraud'), 'done')) reload(); }, 'bad')),
                },
            ], client.accounts.filter((a) => a.type !== 'cash'))),

            panel(label('nav_cards'), table([
                { title: label('col_card'), render: (c) => h('span', { className: 'num', text: `•••• ${c.last4}` }) },
                { title: label('col_status'), render: (c) => [chip(label(`card_${c.status}`)), c.custom ? chip(label('custom_ceilings'), 'warn') : null] },
                { title: label('limit_debitDay'), render: (c) => h('span', { className: 'num', text: money(c.ceilings.debitDay) }), align: 'right' },
                { title: '', render: (c) => iconButton('sliders', label('ceilings'), () => ceilingsDialog(c, reload)), align: 'right' },
            ], client.cards, 'no_cards'))),

        h('div', { className: 'grid grid--two' },
            panel(label('your_bills'), table([
                { title: label('col_description'), render: (b) => b.label, className: 'grow truncate' },
                { title: label('col_status'), render: (b) => chip(label(`bill_${b.status}`), b.status === 'overdue' ? 'bad' : 'warn') },
                { title: label('col_amount'), render: (b) => h('span', { className: 'num', text: money(b.amount - b.paid) }), align: 'right' },
            ], client.bills, 'no_bills')),
            panel(label('activity'), activityTable(client.history))));
}

export default async function render(container, ctx) {
    const queue = await call('staffQueue');

    if (!report(queue)) return;

    const number = input({ placeholder: 'LS 0000 0000', maxLength: 14 });
    const fileBox = h('div', { className: 'stack' }, empty('client_hint'));
    const loadClient = async () => {
        const reply = await call('staffClient', number.value.trim());
        if (report(reply)) fileBox.replaceChildren(clientFile(reply.client, loadClient));
    };

    number.addEventListener('keydown', (event) => { if (event.key === 'Enter') loadClient(); });

    container.append(
        panel(label('loan_queue'), table([
            { title: label('col_client'), render: (l) => l.name, className: 'strong' },
            { title: label('col_amount'), render: (l) => h('span', { className: 'num strong', text: money(l.amount) }), align: 'right' },
            { title: label('installments'), render: (l) => label('weeks', l.installments) },
            { title: label('score'), render: (l) => `${l.score} · ${l.tier}` },
            { title: label('overdue_days'), render: (l) => (l.overdueDays > 0 ? chip(String(l.overdueDays), 'bad') : chip('0', 'good')) },
            { title: label('loan_reason'), render: (l) => l.reason || '-', className: 'muted truncate grow' },
            { title: label('col_date'), render: (l) => dateTime(l.created_at), className: 'muted nowrap' },
            {
                title: '', align: 'right',
                render: (l) => actions(
                    iconButton('check', label('approve'), () => decide(l, true, ctx), 'good'),
                    iconButton('close', label('deny'), () => decide(l, false, ctx), 'bad')),
            },
        ], queue.queue, 'queue_empty')),

        panel(label('client_lookup'), fileBox, [number, button(label('search'), loadClient, 'primary', false, 'search')]),
    );

    if (ctx.bank.admin) {
        const bankers = await call('staffBankers');
        const id = input({ type: 'number', placeholder: label('server_id') });

        container.append(panel(label('bankers'), table([
            { title: label('col_name'), render: (b) => b.name, className: 'strong grow' },
            { title: label('added_by_col'), render: (b) => b.added_by, className: 'muted' },
            { title: '', render: (b) => iconButton('trash', label('remove'), async () => { if (report(await call('staffSetBanker', b.citizenid, false), 'done')) ctx.refresh(); }, 'bad'), align: 'right' },
        ], bankers.ok ? bankers.bankers : [], 'no_bankers'), [id,
            button(label('add_banker'), async () => { if (report(await call('staffSetBanker', whole(id), true), 'done')) ctx.refresh(); }, 'primary', false, 'plus')]));
    }
}
