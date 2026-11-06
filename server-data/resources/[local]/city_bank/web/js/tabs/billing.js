import { call, h, label, money, date, section, button, pill, report, empty } from '../util.js';

const STATUS_KIND = { pending: 'warning', overdue: 'danger', paid: 'success', cancelled: '' };

export default async function render(container, ctx) {
    const data = await call('bills');

    if (!report(data)) return;

    const banner = data.restrictions.overdueDays !== null && data.restrictions.overdueDays !== undefined
        ? h('p', { className: 'notice notice--danger', text: label('overdue_banner', data.restrictions.overdueDays) })
        : null;

    const rows = data.bills.map((bill) => h('li', { className: 'row' },
        h('div', { className: 'row__main' },
            h('span', { className: 'row__title', text: bill.label }),
            h('span', { className: 'row__sub', text: `${label(`bill_${bill.kind}`)} · ${bill.issuer}` }),
            h('span', { className: 'row__sub', text: label('bill_due', date(bill.due)) })),
        h('div', { className: 'row__side' },
            h('span', { className: 'amount mono', text: money(bill.remaining + bill.fee) }),
            bill.fee > 0 ? h('span', { className: 'row__sub', text: label('late_fee', money(bill.fee)) }) : null,
            bill.paid > 0 ? h('span', { className: 'row__sub', text: label('already_paid', money(bill.paid)) }) : null),
        h('div', { className: 'row__actions' },
            pill(label(`bill_${bill.status}`), STATUS_KIND[bill.status]),
            bill.status === 'pending' || bill.status === 'overdue' ? button(label('pay'), async () => {
                if (report(await call('payBill', bill.id, 'full'), 'bill_paid')) ctx.refresh();
            }, 'primary') : null,
            bill.kind === 'card' && bill.status === 'pending' && bill.minimum > 0 ? button(label('pay_minimum', money(bill.minimum)), async () => {
                if (report(await call('payBill', bill.id, 'minimum'), 'bill_paid')) ctx.refresh();
            }) : null),
    ));

    container.replaceChildren(h('div', { className: 'stack' },
        banner,
        section(label('your_bills'), rows.length ? h('ul', { className: 'list' }, rows) : empty('no_bills')),
    ));
}
