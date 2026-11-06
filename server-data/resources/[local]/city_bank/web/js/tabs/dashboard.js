import { call, h, label, money, dateTime, reasonLabel, section, button, pill, empty, report } from '../util.js';

function stat(key, value, kind = '') {
    return h('article', { className: `stat ${kind}` },
        h('p', { className: 'stat__label', text: label(key) }),
        h('p', { className: 'stat__value', text: value }));
}

export function activityList(history) {
    if (!history || history.length === 0) return empty('activity_empty');

    return h('ul', { className: 'list' }, history.map((entry) => h('li', { className: 'row' },
        h('div', { className: 'row__main' },
            h('span', { className: 'row__title', text: reasonLabel(entry.reason) }),
            h('span', { className: 'row__sub', text: dateTime(entry.time) })),
        h('div', { className: 'row__side' },
            h('span', { className: `amount ${entry.delta < 0 ? 'is-out' : 'is-in'}`, text: money(entry.delta, true) }),
            h('span', { className: 'row__sub mono', text: money(entry.balance_after) })),
    )));
}

export default async function render(container, ctx) {
    const data = await call('dashboard');

    if (!report(data)) return;

    ctx.bank.data = data;
    document.getElementById('title').textContent = label('greeting', data.firstname || '');

    container.replaceChildren(
        h('div', { className: 'stats' },
            stat('balance', money(data.balance), 'stat--accent'),
            stat('cash', money(data.cash)),
            stat('income', money(data.income), 'stat--in'),
            stat('expenses', money(data.expenses), 'stat--out')),

        h('div', { className: 'grid grid--side' },
            h('div', { className: 'stack' },
                section(label('account'),
                    h('dl', { className: 'facts' },
                        h('div', {}, h('dt', { text: label('account_number') }), h('dd', { className: 'mono', text: data.number })),
                        h('div', {}, h('dt', { text: label('status') }),
                            h('dd', {}, pill(label(data.frozen ? 'status_frozen' : 'status_active'), data.frozen ? 'danger' : 'success')))),
                    button(label('cash_desk'), ctx.openTeller, 'primary')),

                section(label('credit_profile'),
                    h('dl', { className: 'facts' },
                        h('div', {}, h('dt', { text: label('score') }), h('dd', { className: 'mono', text: String(data.score) })),
                        h('div', {}, h('dt', { text: label('tier') }), h('dd', { text: data.tier })),
                        h('div', {}, h('dt', { text: label('bills_open') }),
                            h('dd', { text: `${data.billsCount} · ${money(data.billsTotal)}` })),
                        h('div', {}, h('dt', { text: label('loan_left') }), h('dd', { text: money(data.loanLeft) }))))),

            section(label('activity'), activityList(data.history))),
    );
}
