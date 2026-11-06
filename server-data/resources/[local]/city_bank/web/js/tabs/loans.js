import { call, h, label, money, dateTime, panel, kpi, table, chip, button, field, input, select, report, progress } from '../util.js';

// Same arithmetic as server/rules.lua loanPlan; the page only shows it, the server recomputes everything
function plan(amount, rate, weeks) {
    const total = amount + Math.ceil((amount * rate) / 100);
    const installment = Math.ceil(total / weeks);
    return { total, installment };
}

const STATUS = { requested: 'warn', active: 'good', paid: '', denied: 'bad' };

export default async function render(container, ctx) {
    const data = await call('loans');

    if (!report(data)) return;

    const amount = input({ type: 'range', min: data.min, max: data.max, step: 500, value: Math.min(data.auto, data.max), className: 'range' });
    const amountText = h('span', { className: 'num strong range__value' });
    const weeks = select(Array.from({ length: data.weeks }, (_, i) => ({ value: String(i + 1), label: label('weeks', i + 1) })), String(data.weeks));
    const reason = input({ placeholder: label('loan_reason'), maxLength: 120 });
    const summary = h('div', { className: 'summary' });

    const update = () => {
        const value = Number(amount.value);
        const result = plan(value, data.rate, Number(weeks.value));
        const auto = value <= data.auto;

        amountText.textContent = money(value);
        summary.replaceChildren(
            h('div', {}, h('span', { text: label('interest') }), h('strong', { text: `${data.rate}%` })),
            h('div', {}, h('span', { text: label('installment') }), h('strong', { className: 'num', text: `${money(result.installment)} × ${weeks.value}` })),
            h('div', {}, h('span', { text: label('total_repay') }), h('strong', { className: 'num', text: money(result.total) })),
            h('div', {}, h('span', { text: label('approval') }), chip(label(auto ? 'approval_auto' : 'approval_banker'), auto ? 'good' : 'warn')));
    };

    amount.addEventListener('input', update);
    weeks.addEventListener('change', update);
    update();

    const active = data.loans.find((l) => l.status === 'active');

    container.append(
        h('div', { className: 'kpis' },
            kpi(label('score'), String(data.score), data.tier, 'accent'),
            kpi(label('auto_limit'), money(data.auto), label('max_with_banker', money(data.max))),
            kpi(label('interest'), `${data.rate}%`, label('up_to_weeks', data.weeks)),
            kpi(label('loan_left'), active ? money(active.total - active.paid_total) : money(0), active ? label('next_charge', dateTime(active.next_due)) : label('no_active_loan'))),

        h('div', { className: 'grid grid--loans' },
            panel(label('your_loans'), table([
                { title: '#', render: (l) => `#${l.id}`, className: 'muted' },
                { title: label('col_amount'), render: (l) => h('span', { className: 'num strong', text: money(l.amount) }) },
                { title: label('col_progress'), render: (l) => progress(l.paid_total / Math.max(1, l.total), `${l.paid_count}/${l.installments}`), className: 'grow' },
                { title: label('col_status'), render: (l) => chip(label(`loan_${l.status}`), STATUS[l.status]) },
                { title: label('col_note'), render: (l) => l.decision || l.reason || '-', className: 'muted truncate' },
                {
                    title: '', align: 'right',
                    render: (l) => (l.status === 'active' ? button(label('pay_installment'), async () => {
                        if (report(await call('payInstallment', l.id), 'done')) ctx.refresh();
                    }, 'primary') : null),
                },
            ], data.loans, 'no_loans')),

            panel(label('new_loan'), h('div', { className: 'form' },
                h('p', { className: 'muted', text: label('loan_terms', data.tier, data.score, money(data.auto)) }),
                field(label('amount'), h('div', { className: 'range-row' }, amount, amountText)),
                h('div', { className: 'form__grid' }, field(label('installments'), weeks), field(label('loan_reason'), reason)),
                summary,
                data.canRequest ? null : h('p', { className: 'notice', text: label('loan_blocked') }),
                h('div', { className: 'form__actions' },
                    button(label('request_loan'), async () => {
                        const reply = await call('requestLoan', Number(amount.value), Number(weeks.value), reason.value.trim());
                        if (report(reply, reply?.pending ? 'loan_pending' : 'loan_approved')) ctx.refresh();
                    }, 'primary', !data.canRequest, 'send'))))),
    );
}
