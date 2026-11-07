// The Team tab (admins): every staff member's numbers for the period, and a page per person with their chart, what
// they did, their ratings and their latest actions.

import { el, L, run, icon, pill, segmented, stepper, initials, shortName, duration, ago, formatTime } from './ui.js';
import { go, can } from './main.js';
import { ratingCard } from './dashboard.js';
import { ACTION_LOOK } from './records.js';

let period = 'week';
let selected = null;
let editingGoals = false;

export async function renderTeam(args) {
    if (args && args.license) selected = args.license;

    const response = await run('team', { period });
    const members = response ? response.data.members : [];
    const goal = response ? response.data.goals[period] : 0;
    if (!members.some((member) => member.license === selected)) selected = members.length ? members[0].license : null;

    const pick = (value) => {
        period = value;
        go('team');
    };

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_team') }), pill(L('ui_staff_count', members.length)), el('span', { class: 'spacer' }),
                can('goals') ? el('button', { class: `kit-btn${editingGoals ? ' accent' : ''}`, text: L('ui_goals'), onclick: () => {
                    editingGoals = !editingGoals;
                    go('team');
                } }) : null),
            editingGoals && response ? goalsEditor(response.data.goals) : null,
            segmented([['today', L('ui_today')], ['week', L('ui_week')], ['month', L('ui_month')]], period, pick),
            el('div', { class: 'list' }, members.length ? members.map((member) => el('button', { class: `list-row${member.license === selected ? ' on' : ''}`, onclick: () => go('team', { license: member.license }) },
                el('span', { class: 'avatar' }, initials(member.name), el('i', { class: `presence${member.online ? ' on' : ''}` })),
                el('span', { class: 'who' }, el('strong', { text: shortName(member.name) }),
                    el('small', { text: [member.level ? L(`level_${member.level}`) : null, member.online ? L('ui_online_now') : member.lastActive ? ago(member.lastActive) : null, member.rating ? `${member.rating} ★` : null].filter(Boolean).join(' · ') }),
                    el('span', { class: 'meter goal' }, el('span', { class: member.closed >= goal ? 'ok' : 'gold-fill', style: `width: ${goal ? Math.min(100, Math.round((member.closed / goal) * 100)) : 0}%` }))),
                el('span', { class: 'team-nums' }, el('strong', { text: String(member.closed) }), el('small', { text: L('ui_of_goal_short', goal) })),
            )) : el('div', { class: 'list-empty', text: L('ui_no_staff_activity') })),
        ),
        el('div', { class: 'split-detail' }, selected ? await memberPage(selected) : el('div', { class: 'empty', text: L('ui_no_staff_activity') })),
    );
}

// Admins set how many reports staff should close per day, week and month
function goalsEditor(goals) {
    const inputs = {};
    const field = (key) => {
        inputs[key] = el('input', { class: 'field', type: 'number', min: '1', max: '10000', value: String(goals[key]), id: `goal-${key}`, 'aria-label': L(`ui_goal_${key}`) });
        return el('div', { class: 'goal-field' }, el('label', { for: `goal-${key}`, text: L(`ui_goal_${key}`) }), stepper(inputs[key]));
    };

    const save = async () => {
        const values = Object.fromEntries(Object.entries(inputs).map(([key, input]) => [key, Number(input.value)]));
        if (await run('setGoals', values, L('ui_goals_saved'))) {
            editingGoals = false;
            go('team');
        }
    };

    return el('div', { class: 'card form goals' },
        el('strong', { text: L('ui_goals_title') }),
        el('small', { class: 'muted', text: L('ui_goals_help') }),
        el('div', { class: 'goal-fields' }, field('today'), field('week'), field('month')),
        el('div', { class: 'editor-buttons' },
            el('button', { class: 'kit-btn', text: L('ui_cancel'), onclick: () => {
                editingGoals = false;
                go('team');
            } }),
            el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', text: L('ui_save'), onclick: save })),
    );
}

function tile(iconName, kind, label, value, sub) {
    return el('div', { class: 'card tile' },
        el('div', { class: 'tile-head' }, el('span', { class: `tile-icon ${kind}` }, icon(iconName, 18, 2)), el('span', { text: label })),
        el('strong', { class: 'tile-value', text: value }),
        sub ? el('small', { class: 'tile-sub', text: sub }) : null,
    );
}

function chart(days) {
    const max = Math.max(1, ...days.map((day) => Math.max(day.sent, day.closed)));
    const height = (n) => `height: ${Math.round((n / max) * 120)}px`;

    return el('div', { class: 'card' },
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_last_14_days') }), el('span', { class: 'spacer' }),
            el('span', { class: 'legend' }, el('i', { class: 'sent' }), L('ui_chart_answered')),
            el('span', { class: 'legend' }, el('i', { class: 'closed' }), L('ui_chart_closed'))),
        el('div', { class: 'bars wide' }, days.map((day) => el('div', { class: 'bar-day' },
            el('div', { class: 'bar-pair short' },
                el('span', { class: 'bar sent thin', style: height(day.sent), title: L('ui_chart_answered_n', day.sent) }),
                el('span', { class: 'bar closed thin', style: height(day.closed), title: L('ui_chart_closed_n', day.closed) })),
            el('small', { text: day.day })))),
    );
}

async function memberPage(license) {
    const response = await run('teamMember', { license, period });
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;
    const member = data.member;
    const most = Math.max(1, ...data.breakdown.map((row) => row.n));
    const mostStars = Math.max(1, ...data.stars);

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('span', { class: 'avatar big' }, initials(member.name), el('i', { class: `presence${member.online ? ' on' : ''}` })),
            el('div', { class: 'who' }, el('h2', { text: shortName(member.name) }),
                el('small', { text: member.online ? L('ui_online_now') : member.lastActive ? L('ui_last_active', ago(member.lastActive)) : L('ui_not_active') }),
                member.level ? el('div', { class: 'pills' }, pill(L(`level_${member.level}`), 'accent')) : null),
        ),
        el('div', { class: 'tiles' },
            tile('check', 'green', L('ui_closed'), String(member.closed), `${L(`ui_period_${data.period}`)} · ${L('ui_of_goal', data.goal)}`),
            tile('star', 'gold', L('ui_rating'), member.rating ? `${member.rating} ★` : '—', L('ui_ratings_count', member.ratings)),
            tile('clock', 'blue', L('ui_first_reply'), duration(member.response), L('ui_average')),
            tile('log', 'grey', L('ui_actions'), String(member.actions), L('ui_sanctions_n', member.sanctions)),
        ),
        chart(data.chart),
        el('div', { class: 'two-cols even' },
            el('div', { class: 'card' },
                el('strong', { class: 'card-title', text: L('ui_what_they_did') }),
                data.breakdown.length ? data.breakdown.map((row) => {
                    const [iconName, kind] = ACTION_LOOK[row.action] || ['tools', 'grey'];
                    return el('div', { class: 'spread' },
                        el('span', { class: `tile-icon small ${kind}` }, icon(iconName, 14, 2)),
                        el('span', { class: 'spread-label', text: L(`label_${row.action}`) }),
                        el('span', { class: 'meter' }, el('span', { class: 'gold-fill', style: `width: ${Math.round((row.n / most) * 100)}%` })),
                        el('span', { class: 'muted count', text: String(row.n) }));
                }) : el('small', { class: 'muted', text: L('ui_nothing_this_period') }),
            ),
            el('div', { class: 'card' },
                el('strong', { class: 'card-title', text: L('ui_their_ratings') }),
                [5, 4, 3, 2, 1].map((n) => el('div', { class: 'spread' },
                    el('span', { class: 'muted', text: `${n} ★` }),
                    el('span', { class: 'meter' }, el('span', { class: 'gold-fill', style: `width: ${Math.round((data.stars[n - 1] / mostStars) * 100)}%` })),
                    el('span', { class: 'muted count', text: String(data.stars[n - 1]) }))),
            ),
        ),
        data.ratings.length ? el('div', { class: 'stack small' }, el('strong', { class: 'card-title', text: L('ui_latest_ratings') }), el('div', { class: 'rating-grid' }, data.ratings.map(ratingCard))) : null,
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_latest_actions') })),
            data.recent.length ? data.recent.map((entry) => {
                const [iconName, kind] = ACTION_LOOK[entry.action] || ['tools', 'grey'];
                return el('div', { class: 'info-row tall' },
                    el('small', { class: 'time', text: formatTime(entry.time) }),
                    el('span', { class: `tile-icon ${kind}` }, icon(iconName, 16, 2)),
                    el('span', { class: 'grow' }, `${L(`action_${entry.action}`)} `, entry.target_name ? el('strong', { text: shortName(entry.target_name) }) : null),
                    el('small', { class: 'muted', text: entry.details || '' }));
            }) : el('div', { class: 'list-empty', text: L('ui_no_log') }),
        ),
    );
}
