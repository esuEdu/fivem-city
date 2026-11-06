import { call, h, label, money, dateTime, section, button, pill, field, input, select, whole, report, empty } from '../util.js';

// Same arithmetic as server/rules.lua loanPlan; the page only shows it, the server recomputes everything
function plan(amount, rate, weeks) {
    const total = amount + Math.ceil((amount * rate) / 100);
    const installment = Math.ceil(total / weeks);
    return { total, installment };
}

const STATUS_KIND = { requested: 'warning', active: 'success', paid: '', denied: 'danger' };

export default async function render(container, ctx) {
    const data = await call('loans');

    if (!report(data)) return;

    const amount = input({ type: 'range', min: data.min, max: data.max, step: 500, value: Math.min(data.auto, data.max) });
    const amountText = h('span', { className: 'mono slider__value' });
    const weeks = select(Array.from({ length: data.weeks }, (_, i) => ({ value: String(i + 1), label: label('weeks', i + 1) })), String(data.weeks));
    const reason = input({ placeholder: label('loan_reason'), maxLength: 120 });
    const summary = h('dl', { className: 'facts' });

    const update = () => {
        const value = Number(amount.value);
        const result = plan(value, data.rate, Number(weeks.value));

        amountText.textContent = money(value);
        summary.replaceChildren(
            h('div', {}, h('dt', { text: label('interest') }), h('dd', { text: `${data.rate}%` })),
            h('div', {}, h('dt', { text: label('installment') }), h('dd', { className: 'mono', text: `${money(result.installment)} × ${weeks.value}` })),
            h('div', {}, h('dt', { text: label('total_repay') }), h('dd', { className: 'mono', text: money(result.total) })),
            h('div', {}, h('dt', { text: label('approval') }),
                h('dd', {}, pill(label(value <= data.auto ? 'approval_auto' : 'approval_banker'), value <= data.auto ? 'success' : 'warning'))));
    };

    amount.addEventListener('input', update);
    weeks.addEventListener('change', update);
    update();

    const request = section(label('new_loan'),
        h('p', { className: 'muted', text: label('loan_terms', data.tier, data.score, money(data.auto)) }),
        field(label('amount'), h('div', { className: 'slider' }, amount, amountText)),
        h('div', { className: 'form-grid' }, field(label('installments'), weeks), field(label('loan_reason'), reason)),
        summary,
        data.canRequest ? null : h('p', { className: 'notice', text: label('loan_blocked') }),
        h('div', { className: 'row__actions' },
            button(label('request_loan'), async () => {
                const reply = await call('requestLoan', Number(amount.value), Number(weeks.value), reason.value.trim());
                if (report(reply, reply?.pending ? 'loan_pending' : 'loan_approved')) ctx.refresh();
            }, 'primary', !data.canRequest)));

    const list = data.loans.length ? h('ul', { className: 'list' }, data.loans.map((loan) => h('li', { className: 'row' },
        h('div', { className: 'row__main' },
            h('span', { className: 'row__title', text: `${money(loan.amount)} · ${label('weeks', loan.installments)}` }),
            h('span', { className: 'row__sub', text: label('loan_progress', loan.paid_count, loan.installments, money(loan.paid_total), money(loan.total)) }),
            loan.status === 'active' ? h('span', { className: 'row__sub', text: label('next_charge', dateTime(loan.next_due)) }) : null,
            loan.decision ? h('span', { className: 'row__sub', text: loan.decision }) : null),
        h('div', { className: 'row__actions' },
            pill(label(`loan_${loan.status}`), STATUS_KIND[loan.status]),
            loan.status === 'active' ? button(label('pay_installment'), async () => {
                if (report(await call('payInstallment', loan.id), 'done')) ctx.refresh();
            }, 'primary') : null),
    ))) : empty('no_loans');

    container.replaceChildren(h('div', { className: 'grid grid--two' }, request, section(label('your_loans'), list)));
}
