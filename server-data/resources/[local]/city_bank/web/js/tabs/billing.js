import { call, h, label, money, date, panel, kpi, table, chip, button, report, actions } from '../util.js';

const STATUS = { pending: 'warn', overdue: 'bad', paid: 'good', cancelled: '' };

export default async function render(container, ctx) {
    const data = await call('bills');

    if (!report(data)) return;

    const open = data.bills.filter((b) => b.status === 'pending' || b.status === 'overdue');
    const due = open.reduce((sum, b) => sum + b.remaining + b.fee, 0);
    const overdue = data.restrictions.overdueDays;

    container.append(
        h('div', { className: 'kpis' },
            kpi(label('total_due'), money(due), label('bills_count', open.length), 'accent'),
            kpi(label('overdue_days'), overdue !== undefined && overdue !== null ? String(overdue) : '0', label(overdue !== undefined && overdue !== null ? 'restricted' : 'all_good'), overdue !== undefined && overdue !== null ? 'out' : 'in'),
            kpi(label('credit_status'), label(data.restrictions.creditCard ? 'on' : 'off'), label('new_credit_is', label(data.restrictions.newCredit ? 'on' : 'off')))),

        overdue !== undefined && overdue !== null ? h('p', { className: 'notice notice--bad', text: label('overdue_banner', overdue) }) : null,

        panel(label('your_bills'), table([
            { title: label('col_description'), render: (b) => b.label, className: 'strong grow truncate' },
            { title: label('col_type'), render: (b) => chip(label(`bill_${b.kind}`)) },
            { title: label('col_issuer'), render: (b) => b.issuer, className: 'muted truncate' },
            { title: label('col_due'), render: (b) => date(b.due), className: 'muted nowrap' },
            { title: label('col_status'), render: (b) => chip(label(`bill_${b.status}`), STATUS[b.status]) },
            { title: label('late_fee_short'), render: (b) => (b.fee > 0 ? h('span', { className: 'num is-out', text: money(b.fee) }) : '-'), align: 'right' },
            { title: label('col_amount'), render: (b) => h('span', { className: 'num strong', text: money(b.remaining + b.fee) }), align: 'right' },
            {
                title: '', align: 'right',
                render: (b) => actions(
                    b.status === 'pending' || b.status === 'overdue' ? button(label('pay'), async () => {
                        if (report(await call('payBill', b.id, 'full'), 'bill_paid')) ctx.refresh();
                    }, 'primary') : null,
                    b.kind === 'card' && b.status === 'pending' && b.minimum > 0 ? button(label('pay_minimum', money(b.minimum)), async () => {
                        if (report(await call('payBill', b.id, 'minimum'), 'bill_paid')) ctx.refresh();
                    }) : null),
            },
        ], data.bills, 'no_bills')),
    );
}
