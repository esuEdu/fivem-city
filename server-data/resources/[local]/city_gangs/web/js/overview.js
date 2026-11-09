// The Dashboard: how the gang is doing over the chosen period (money, sales, production, who is pulling their weight),
// day by day, per drug, and a ranking of every member. Tapping a member opens their performance page.

import { el, L, run, tile, money, initials, drugLabel, heading, pill, list, chart, periodPicker } from './ui.js';
import { app, go, setOnline } from './main.js';

export async function renderOverview() {
    const response = await run('overview', { days: app.period });
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;
    const drugs = list(data.drugs);
    const ranking = list(data.ranking);
    setOnline(data.online, data.members);

    const pick = (days) => {
        app.period = days;
        go('overview');
    };

    const mostEarned = Math.max(1, ...drugs.map((drug) => drug.earned));
    const best = Math.max(1, ...ranking.map((member) => member.earned));

    return el('div', { class: 'stack' },
        heading(app.gang, pill(app.gradeName, 'accent'), el('span', { class: 'spacer' }), periodPicker(app.periods, data.days, pick)),
        el('div', { class: 'tiles' },
            tile('money', 'green', L('ui_earned'), money(data.earned), L('ui_average_sale', money(data.average))),
            tile('cart', 'gold', L('ui_sales'), String(data.sales), L('ui_in_period')),
            tile('flask', 'purple', L('ui_made'), String(data.made), L('ui_units')),
            tile('members', 'blue', L('ui_active'), `${data.active} / ${data.members}`, L('ui_online_count', data.online, data.members)),
        ),
        chart(L('ui_last_days', data.chart.days.length || 0), data.chart),
        el('div', { class: 'two-cols' },
            el('div', { class: 'card' },
                el('strong', { class: 'card-title', text: L('ui_by_drug') }),
                drugs.length ? drugs.map((drug) => el('div', { class: 'spread' },
                    el('span', { class: 'spread-label', text: drugLabel(drug.drug) }),
                    el('span', { class: 'meter' }, el('span', { class: 'fill', style: `width: ${Math.round((drug.earned / mostEarned) * 100)}%` })),
                    el('span', { class: 'muted count', text: money(drug.earned) }),
                    el('span', { class: 'muted count small', text: `${drug.made} ${L('ui_units')}` }))) : el('small', { class: 'muted', text: L('ui_nothing_yet') }),
            ),
            el('div', { class: 'card flush' },
                el('div', { class: 'card-head padded' }, el('strong', { class: 'card-title', text: L('ui_ranking') })),
                ranking.length ? ranking.map((member, index) => el('button', { class: 'rank-line', onclick: () => go('members', { citizenid: member.citizenid }) },
                    el('span', { class: 'place', text: String(index + 1) }),
                    el('span', { class: 'avatar' }, initials(member.name), el('i', { class: `presence${member.online ? ' on' : ''}` })),
                    el('span', { class: 'who grow' },
                        el('strong', { text: member.name }),
                        el('small', { text: `${member.gradeName} · ${L('ui_sales_n', member.sales)} · ${member.made} ${L('ui_units')}` }),
                        el('span', { class: 'meter thin' }, el('span', { class: 'fill', style: `width: ${Math.round((member.earned / best) * 100)}%` }))),
                    el('strong', { class: member.earned ? 'good' : 'muted', text: money(member.earned) }))) : el('div', { class: 'list-empty', text: L('ui_no_members') }),
            ),
        ),
    );
}
