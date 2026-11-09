import { call, h, label, money, dateTime, reasonLabel, panel, kpi, table, amountCell, chip, button, report, state } from '../util.js';
import { lastDays, cashFlow, balanceLine } from '../charts.js';

// Movements as a compact table (used by the dashboard, history and staff client file)
export function activityTable(history, emptyKey = 'activity_empty') {
    return table([
        { title: label('col_date'), render: (e) => dateTime(e.time), className: 'muted nowrap' },
        { title: label('col_description'), render: (e) => reasonLabel(e.reason), className: 'grow' },
        { title: label('col_amount'), render: (e) => amountCell(e.delta), align: 'right' },
        { title: label('col_balance'), render: (e) => h('span', { className: 'num muted', text: money(e.balance_after) }), align: 'right' },
    ], history, emptyKey);
}

function fact(key, value) {
    return h('div', { className: 'fact' }, h('span', { className: 'fact__key', text: label(key) }), h('span', { className: 'fact__value' }, value));
}

export default async function render(container, ctx) {
    const data = await call('dashboard');

    if (!report(data)) return;

    ctx.bank.data = data;
    document.getElementById('title').textContent = label('greeting', data.firstname || '');

    const days = lastDays(data.trend, 7);

    container.append(
        h('div', { className: 'kpis' },
            kpi(label('balance'), money(data.balance), data.number, 'accent'),
            kpi(label('cash'), money(data.cash), label('cash_hint')),
            kpi(label('income'), money(data.income), label('last_24h'), 'in'),
            kpi(label('expenses'), money(data.expenses), label('last_24h'), 'out'),
            kpi(label('score'), String(data.score), data.tier)),

        h('div', { className: 'grid grid--charts' },
            panel(label('chart_cashflow'), cashFlow(days)),
            panel(label('chart_balance'), balanceLine(days, data.balance))),

        h('div', { className: 'grid grid--main' },
            panel(label('activity'), activityTable(data.history), button(label('nav_history'), () => ctx.openTab('history'), 'link')),
            panel(label('account'), h('div', { className: 'facts' },
                fact('account_number', h('span', { className: 'num', text: data.number })),
                fact('status', chip(label(data.frozen ? 'status_frozen' : 'status_active'), data.frozen ? 'bad' : 'good')),
                fact('tier', data.tier),
                fact('bills_open', `${data.billsCount} · ${money(data.billsTotal)}`),
                state.features.loans !== false ? fact('loan_left', money(data.loanLeft)) : null,
                h('div', { className: 'facts__actions' }, button(label('cash_desk'), ctx.openTeller, 'primary', false, 'cash'))))),
    );
}
